--[[
    Pls Donate Farm Script v9.0 (Полная версия)
    Поиск стенда: по надписи "unclaimed"
    Автор: AI Agent
    Горячая клавиша: Правый Ctrl
]]

-- Конфигурация
local config = {
    telegramToken = "8104787078:AAHiRuOS4gaTxaVRlYU7BV9L8flN_VXGV68",
    telegramChatID = "1981885077",
    begMessage = "please donate to me as much as you don't mind, I'm raising money for my favorite set",
    thankYouMessage = "thank you god who came down from heaven",
    jumpThanksMessage = "Thanks you god for this challenge im complete",
    jumpRobuxMessage = "5robux = 20 jump",
    delayBetweenPlayers = 3,
    jumpDelay = 0.8,
    maxServerTime = 30 * 60,
}

-- Сервисы
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local VirtualUser = game:GetService("VirtualUser")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

-- Переменные
local StandPosition = nil
local currentMode = nil
local isRunning = false
local serverTime = 0
local gui = nil
local guiVisible = true
local antiAfkEnabled = false

-- Уведомления
local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 3
        })
    end)
    print("["..title.."] "..text)
end

-- Анти-AFK
local function antiAfk()
    if not antiAfkEnabled then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end

-- === НОВЫЙ ПОИСК СТЕНДА ПО НАДПИСИ "unclaimed" ===
local function findUnclaimedStand()
    for _, obj in ipairs(workspace:GetDescendants()) do
        -- Ищем BillboardGui с текстом "unclaimed"
        if obj:IsA("BillboardGui") and obj.Parent then
            local textLabel = obj:FindFirstChildOfClass("TextLabel")
            if textLabel and textLabel.Text and textLabel.Text:lower():find("unclaimed") then
                -- Возвращаем родителя (сам стенд)
                return obj.Parent
            end
        end
    end
    return nil
end

-- Занятие стенда
local function claimStand()
    notify("Стенд", "Поиск свободного стенда...", 2)
    local stand = findUnclaimedStand()
    if not stand then
        notify("Ошибка", "Свободный стенд не найден", 3)
        return false
    end

    -- Телепорт к стенду
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root then
        root.CFrame = stand:GetPivot().Position * CFrame.new(0, 0, 2)
    end
    wait(1)

    -- Эмуляция клавиши E для захвата
    notify("Стенд", "Захватываю...", 2)
    pcall(function() VirtualUser:KeyDown(Enum.KeyCode.E) end)
    wait(2)
    pcall(function() VirtualUser:KeyUp(Enum.KeyCode.E) end)

    StandPosition = stand:GetPivot().Position
    notify("Успех", "Стенд занят", 2)
    return true
end

-- Телепорт к игроку
local function teleportToPlayer(player)
    local targetRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot or not myRoot then return false end
    myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, -3)
    return true
end

-- Телепорт к стенду
local function teleportToStand()
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if StandPosition and myRoot then
        myRoot.CFrame = CFrame.new(StandPosition) * CFrame.new(0, 0, 2)
        return true
    end
    return false
end

-- Отправка сообщения в чат
local function sendChat(msg)
    pcall(function()
        if TextChatService and TextChatService.TextChannels:FindFirstChild("RBXGeneral") then
            TextChatService.TextChannels.RBXGeneral:SendAsync(msg)
        else
            LocalPlayer:Chat(msg)
        end
    end)
end

-- Прыжки
local function performJumps(count)
    local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
    if not humanoid then return end
    for i = 1, count do
        if not isRunning then break end
        humanoid.Jump = true
        wait(config.jumpDelay)
    end
    notify("Прыжки", "Выполнено " .. count .. " прыжков", 2)
end

-- Telegram
local function sendTelegram(message)
    if config.telegramToken == "YOUR_BOT_TOKEN" then
        return
    end
    local url = string.format("https://api.telegram.org/bot%s/sendMessage?chat_id=%s&text=%s",
        config.telegramToken, config.telegramChatID, HttpService:UrlEncode(message))
    pcall(function() HttpService:GetAsync(url) end)
end

-- Обработка доната
local function handleDonation(amount, donor)
    local intAmount = math.floor(amount)
    local after = intAmount * 0.7
    sendTelegram(string.format("%s получил %d Robux (чистыми %d). От: %s",
        LocalPlayer.Name, intAmount, after, donor))

    if currentMode == "Jump" then
        serverTime = 0
        sendChat("OMG thanks you for donat")
        wait(1)
        performJumps(intAmount * 4)
        sendChat(config.jumpThanksMessage)
    elseif currentMode == "Beg" then
        sendChat(config.thankYouMessage)
    end
end

-- Слушатель донатов
local function setupDonationListener()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        local raised = leaderstats:FindFirstChild("Raised")
        if raised then
            local last = raised.Value
            raised:GetPropertyChangedSignal("Value"):Connect(function()
                if raised.Value > last then
                    handleDonation(raised.Value - last, "System")
                    last = raised.Value
                end
            end)
        end
    end
    if TextChatService then
        TextChatService.MessageReceived:Connect(function(m)
            if m.Text and m.Text:find(LocalPlayer.Name) and m.Text:find("donated") then
                local amount = m.Text:match("donated (%d+) Robux")
                if amount then
                    handleDonation(tonumber(amount), m.FromPlayer and m.FromPlayer.Name or "unknown")
                end
            end
        end)
    end
end

-- Перезаход на другой сервер
local function rejoinServer()
    notify("Переход", "Ищу новый сервер...", 2)
    isRunning = false
    wait(1)
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end

-- Режим попрошайничества
local function startBegMode()
    notify("Режим", "Запуск попрошайничества", 2)
    currentMode = "Beg"
    isRunning = true

    if not claimStand() then
        isRunning = false
        return
    end

    while isRunning do
        local players = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                table.insert(players, p)
            end
        end

        if #players == 0 then
            rejoinServer()
            break
        end

        for _, p in ipairs(players) do
            if not isRunning then break end
            if teleportToPlayer(p) then
                wait(1)
                sendChat(config.begMessage)
                wait(10)
                teleportToStand()
                wait(1)
            end
            if antiAfkEnabled then antiAfk() end
        end

        rejoinServer()
        break
    end
    isRunning = false
end

-- Режим Jump-Robux
local function startJumpMode()
    notify("Режим", "Запуск Jump-Robux", 2)
    currentMode = "Jump"
    isRunning = true
    serverTime = 0

    if not claimStand() then
        isRunning = false
        return
    end

    while isRunning do
        wait(1)
        serverTime = serverTime + 1
        if antiAfkEnabled and serverTime % 30 == 0 then
            antiAfk()
        end
        if serverTime >= config.maxServerTime then
            rejoinServer()
            break
        end
    end
    isRunning = false
end

-- Тест Fake Donate
local function fakeDonate()
    handleDonation(5, "TEST")
end

-- Остановка режима
local function stopMode()
    isRunning = false
    currentMode = nil
end

-- GUI
local function createGUI()
    local screen = Instance.new("ScreenGui")
    screen.Name = "PlsDonateFarm"
    screen.ResetOnSpawn = false
    screen.Parent = LocalPlayer:WaitForChild("PlayerGui")
    gui = screen

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 500, 0, 700)
    main.Position = UDim2.new(0.5, -250, 0.5, -350)
    main.BackgroundColor3 = Color3.fromRGB(20,20,30)
    main.Active = true
    main.Draggable = true
    main.Parent = screen
    Instance.new("UICorner", main).CornerRadius = UDim.new(0,10)

    -- Крестик
    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0,30,0,30)
    close.Position = UDim2.new(1,-35,0,5)
    close.BackgroundColor3 = Color3.fromRGB(200,50,50)
    close.Text = "X"
    close.TextColor3 = Color3.new(1,1,1)
    close.Parent = main
    close.MouseButton1Click:Connect(function() screen:Destroy() end)

    -- Заголовок
    local title = Instance.new("TextLabel", main)
    title.Size = UDim2.new(1,-40,0,40)
    title.Position = UDim2.new(0,10,0,0)
    title.BackgroundTransparency = 1
    title.Text = "Pls Donate Farm v9.0"
    title.TextColor3 = Color3.new(1,1,1)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold

    -- Вкладки
    local tabs = Instance.new("Frame", main)
    tabs.Size = UDim2.new(1,-20,0,40)
    tabs.Position = UDim2.new(0,10,0,50)
    tabs.BackgroundTransparency = 1

    local begTab = Instance.new("TextButton", tabs)
    begTab.Size = UDim2.new(0.5,-5,1,0)
    begTab.Position = UDim2.new(0,0,0,0)
    begTab.BackgroundColor3 = Color3.fromRGB(40,40,50)
    begTab.Text = "💰 Попрошайничество"
    begTab.TextColor3 = Color3.fromRGB(200,200,200)
    begTab.Font = Enum.Font.Gotham
    begTab.TextScaled = true

    local jumpTab = Instance.new("TextButton", tabs)
    jumpTab.Size = UDim2.new(0.5,-5,1,0)
    jumpTab.Position = UDim2.new(0.5,5,0,0)
    jumpTab.BackgroundColor3 = Color3.fromRGB(40,40,50)
    jumpTab.Text = "🦘 Jump-Robux"
    jumpTab.TextColor3 = Color3.fromRGB(200,200,200)
    jumpTab.Font = Enum.Font.Gotham
    jumpTab.TextScaled = true

    -- Контейнеры
    local begCont = Instance.new("ScrollingFrame", main)
    begCont.Size = UDim2.new(1,-20,0,550)
    begCont.Position = UDim2.new(0,10,0,100)
    begCont.BackgroundTransparency = 1
    begCont.ScrollBarThickness = 5
    begCont.CanvasSize = UDim2.new(0,0,0,600)
    begCont.Visible = true

    local jumpCont = Instance.new("ScrollingFrame", main)
    jumpCont.Size = UDim2.new(1,-20,0,550)
    jumpCont.Position = UDim2.new(0,10,0,100)
    jumpCont.BackgroundTransparency = 1
    jumpCont.ScrollBarThickness = 5
    jumpCont.CanvasSize = UDim2.new(0,0,0,600)
    jumpCont.Visible = false

    -- === Вкладка Попрошайничество ===
    local y = 10
    local descBeg = Instance.new("TextLabel", begCont)
    descBeg.Size = UDim2.new(1,-10,0,80)
    descBeg.Position = UDim2.new(0,5,0,y)
    descBeg.BackgroundTransparency = 0.5
    descBeg.BackgroundColor3 = Color3.fromRGB(30,30,40)
    descBeg.Text = "📢 Режим попрошайничества:\n• Поиск стенда по надписи 'unclaimed'\n• Обход всех игроков\n• Возврат к стенду\n• Авто-переход между серверами"
    descBeg.TextColor3 = Color3.fromRGB(200,200,255)
    descBeg.TextWrapped = true
    descBeg.TextXAlignment = Enum.TextXAlignment.Left
    descBeg.Font = Enum.Font.Gotham
    descBeg.TextSize = 14
    y = y + 90

    local begStart = Instance.new("TextButton", begCont)
    begStart.Size = UDim2.new(0.5,-5,0,40)
    begStart.Position = UDim2.new(0,5,0,y)
    begStart.BackgroundColor3 = Color3.fromRGB(0,150,0)
    begStart.Text = "Старт"
    begStart.TextColor3 = Color3.new(1,1,1)
    begStart.Font = Enum.Font.Gotham
    begStart.TextScaled = true

    local begStop = Instance.new("TextButton", begCont)
    begStop.Size = UDim2.new(0.5,-5,0,40)
    begStop.Position = UDim2.new(0.5,0,0,y)
    begStop.BackgroundColor3 = Color3.fromRGB(150,0,0)
    begStop.Text = "Стоп"
    begStop.TextColor3 = Color3.new(1,1,1)
    begStop.Font = Enum.Font.Gotham
    begStop.TextScaled = true
    y = y + 50

    local begStatus = Instance.new("TextLabel", begCont)
    begStatus.Size = UDim2.new(1,-10,0,40)
    begStatus.Position = UDim2.new(0,5,0,y)
    begStatus.BackgroundTransparency = 0.5
    begStatus.BackgroundColor3 = Color3.fromRGB(30,30,40)
    begStatus.Text = "Статус: Остановлен"
    begStatus.TextColor3 = Color3.new(1,1,1)
    begStatus.TextWrapped = true
    begStatus.Font = Enum.Font.Gotham
    begStatus.TextScaled = true
    y = y + 60

    -- Чекбокс анти-AFK
    local afkCheckbox = Instance.new("TextButton", begCont)
    afkCheckbox.Size = UDim2.new(1,-10,0,40)
    afkCheckbox.Position = UDim2.new(0,5,0,y)
    afkCheckbox.BackgroundColor3 = antiAfkEnabled and Color3.fromRGB(0,150,0) or Color3.fromRGB(80,80,80)
    afkCheckbox.Text = antiAfkEnabled and "⏱ Анти-AFK: ВКЛ" or "⏱ Анти-AFK: ВЫКЛ"
    afkCheckbox.TextColor3 = Color3.new(1,1,1)
    afkCheckbox.Font = Enum.Font.Gotham
    afkCheckbox.TextScaled = true
    afkCheckbox.MouseButton1Click:Connect(function()
        antiAfkEnabled = not antiAfkEnabled
        afkCheckbox.BackgroundColor3 = antiAfkEnabled and Color3.fromRGB(0,150,0) or Color3.fromRGB(80,80,80)
        afkCheckbox.Text = antiAfkEnabled and "⏱ Анти-AFK: ВКЛ" or "⏱ Анти-AFK: ВЫКЛ"
    end)
    y = y + 50

    begCont.CanvasSize = UDim2.new(0,0,0,y)

    -- === Вкладка Jump-Robux ===
    y = 10
    local descJump = Instance.new("TextLabel", jumpCont)
    descJump.Size = UDim2.new(1,-10,0,90)
    descJump.Position = UDim2.new(0,5,0,y)
    descJump.BackgroundTransparency = 0.5
    descJump.BackgroundColor3 = Color3.fromRGB(30,30,40)
    descJump.Text = "🦘 Режим Jump-Robux:\n• 1 Robux = 4 прыжка\n• Таймер 30 мин, сброс при донате\n• Авто-переход между серверами"
    descJump.TextColor3 = Color3.fromRGB(200,255,200)
    descJump.TextWrapped = true
    descJump.TextXAlignment = Enum.TextXAlignment.Left
    descJump.Font = Enum.Font.Gotham
    descJump.TextSize = 14
    y = y + 100

    local jumpStart = Instance.new("TextButton", jumpCont)
    jumpStart.Size = UDim2.new(0.5,-5,0,40)
    jumpStart.Position = UDim2.new(0,5,0,y)
    jumpStart.BackgroundColor3 = Color3.fromRGB(0,150,0)
    jumpStart.Text = "Старт"
    jumpStart.TextColor3 = Color3.new(1,1,1)
    jumpStart.Font = Enum.Font.Gotham
    jumpStart.TextScaled = true

    local jumpStop = Instance.new("TextButton", jumpCont)
    jumpStop.Size = UDim2.new(0.5,-5,0,40)
    jumpStop.Position = UDim2.new(0.5,0,0,y)
    jumpStop.BackgroundColor3 = Color3.fromRGB(150,0,0)
    jumpStop.Text = "Стоп"
    jumpStop.TextColor3 = Color3.new(1,1,1)
    jumpStop.Font = Enum.Font.Gotham
    jumpStop.TextScaled = true
    y = y + 50

    local jumpStatus = Instance.new("TextLabel", jumpCont)
    jumpStatus.Size = UDim2.new(1,-10,0,40)
    jumpStatus.Position = UDim2.new(0,5,0,y)
    jumpStatus.BackgroundTransparency = 0.5
    jumpStatus.BackgroundColor3 = Color3.fromRGB(30,30,40)
    jumpStatus.Text = "Статус: Остановлен"
    jumpStatus.TextColor3 = Color3.new(1,1,1)
    jumpStatus.TextWrapped = true
    jumpStatus.Font = Enum.Font.Gotham
    jumpStatus.TextScaled = true
    y = y + 60

    -- Fake donate
    local fakeBtn = Instance.new("TextButton", jumpCont)
    fakeBtn.Size = UDim2.new(1,-10,0,40)
    fakeBtn.Position = UDim2.new(0,5,0,y)
    fakeBtn.BackgroundColor3 = Color3.fromRGB(255,165,0)
    fakeBtn.Text = "🪙 Тест: Fake Donate (5 Robux)"
    fakeBtn.TextColor3 = Color3.new(0,0,0)
    fakeBtn.Font = Enum.Font.Gotham
    fakeBtn.TextScaled = true
    fakeBtn.MouseButton1Click:Connect(fakeDonate)
    y = y + 50

    jumpCont.CanvasSize = UDim2.new(0,0,0,y)

    -- Переключение вкладок
    begTab.MouseButton1Click:Connect(function()
        begCont.Visible = true
        jumpCont.Visible = false
    end)
    jumpTab.MouseButton1Click:Connect(function()
        begCont.Visible = false
        jumpCont.Visible = true
    end)

    -- Кнопки режимов
    begStart.MouseButton1Click:Connect(function()
        stopMode()
        begStatus.Text = "Статус: Работает"
        coroutine.wrap(startBegMode)()
    end)
    begStop.MouseButton1Click:Connect(function()
        stopMode()
        begStatus.Text = "Статус: Остановлен"
    end)
    jumpStart.MouseButton1Click:Connect(function()
        stopMode()
        jumpStatus.Text = "Статус: Работает"
        coroutine.wrap(startJumpMode)()
    end)
    jumpStop.MouseButton1Click:Connect(function()
        stopMode()
        jumpStatus.Text = "Статус: Остановлен"
    end)

    -- Горячая клавиша
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.RightControl then
            guiVisible = not guiVisible
            screen.Enabled = guiVisible
        end
    end)

    notify("Готово", "GUI загружен. Нажми Правый Ctrl", 3)
end

-- Запуск
setupDonationListener()
local success, err = pcall(createGUI)
if not success then
    print("Ошибка создания GUI:", err)
    notify("Ошибка", "GUI не создан: " .. tostring(err), 5)
else
    print(">>> Скрипт успешно загружен")
end

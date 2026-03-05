--[[
    Pls Donate Farm Script v6.0 (ФИНАЛЬНАЯ)
    Автор: AI Agent
    Горячая клавиша: Правый Ctrl
]]

-- === КОНФИГУРАЦИЯ ===
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
    extraTimePerDonation = 10 * 60,
}

-- === СЕРВИСЫ ===
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- === ПЕРЕМЕННЫЕ ===
local StandPosition = nil
local currentMode = nil
local isRunning = false
local serverTime = 0
local gui = nil
local guiVisible = true
local antiAfkEnabled = false  -- флаг для анти-AFK

-- === ОТЛАДКА ===
local function debugPrint(...) print("[PlsDonateFarm]", ...) end
local function debugWarn(...) warn("[PlsDonateFarm]", ...) end

-- === ПОЛУЧЕНИЕ ЧАСТЕЙ ПЕРСОНАЖА ===
local function getCharacter()
    return LocalPlayer.Character
end
local function getRootPart()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end
local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChild("Humanoid")
end

-- === TELEGRAM ===
local function sendTelegram(message)
    if config.telegramToken == "YOUR_BOT_TOKEN" then
        debugWarn("Telegram token not set")
        return
    end
    local url = string.format("https://api.telegram.org/bot%s/sendMessage?chat_id=%s&text=%s",
        config.telegramToken, config.telegramChatID, HttpService:UrlEncode(message))
    pcall(function() HttpService:GetAsync(url) end)
    debugPrint("Telegram sent: " .. message)
end

-- === АНТИ-AFK (вызывается только если включён) ===
local function antiAfk()
    if not antiAfkEnabled then return end
    local root = getRootPart()
    if not root then return end
    root.CFrame = root.CFrame * CFrame.new(1,0,0)
    wait(0.1)
    root.CFrame = root.CFrame * CFrame.new(-1,0,0)
    pcall(function()
        VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        wait(0.1)
        VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end)
    debugPrint("Anti-AFK executed")
end

-- === ПОИСК СТЕНДА (теперь по имени "Booth") ===
local function findStand()
    -- Ищем объекты, содержащие "Booth" в имени
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name:find("Booth") then
            return obj
        end
    end
    -- Если не нашли, ищем старые названия
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "Stand" or obj.Name == "DonationStand" then
            return obj
        end
    end
    return nil
end

-- === ЗАНЯТИЕ СТЕНДА ===
local function claimStand()
    local stand = findStand()
    if not stand then
        debugWarn("No stand found")
        return false
    end

    local root = getRootPart()
    if root then
        root.CFrame = stand:GetPivot().Position * CFrame.new(0,0,2)
    end
    wait(1)

    debugPrint("Holding E...")
    pcall(function() VirtualUser:KeyDown(Enum.KeyCode.E) end)
    wait(2)
    pcall(function() VirtualUser:KeyUp(Enum.KeyCode.E) end)

    StandPosition = stand:GetPivot().Position
    debugPrint("Stand claimed at", StandPosition)
    return true
end

-- === ОБНОВЛЕНИЕ ТЕКСТА НА СТЕНДЕ ===
local function updateStandText(mode)
    local stand = findStand()
    if not stand then return end
    local billboard = stand:FindFirstChildOfClass("BillboardGui")
    if billboard then
        local text = billboard:FindFirstChildOfClass("TextLabel")
        if text then
            text.Text = (mode == "Beg") and "💰 Please Donate!" or config.jumpRobuxMessage
        end
    end
end

-- === ТЕЛЕПОРТ К ИГРОКУ ===
local function teleportToPlayer(player)
    local targetRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local myRoot = getRootPart()
    if not targetRoot or not myRoot then return false end
    myRoot.CFrame = targetRoot.CFrame * CFrame.new(0,0,-3)
    return true
end

-- === ТЕЛЕПОРТ К СТЕНДУ ===
local function teleportToStand()
    local myRoot = getRootPart()
    if StandPosition and myRoot then
        myRoot.CFrame = CFrame.new(StandPosition) * CFrame.new(0,0,2)
        return true
    end
    return false
end

-- === ОТПРАВКА СООБЩЕНИЯ В ЧАТ ===
local function sendChat(msg)
    pcall(function()
        if TextChatService and TextChatService.TextChannels:FindFirstChild("RBXGeneral") then
            TextChatService.TextChannels.RBXGeneral:SendAsync(msg)
        else
            LocalPlayer:Chat(msg)
        end
    end)
end

-- === ПРЫЖКИ ===
local function performJumps(count)
    local humanoid = getHumanoid()
    if not humanoid then return end
    for i = 1, count do
        if not isRunning then break end
        humanoid.Jump = true
        wait(config.jumpDelay)
    end
    debugPrint("Performed", count, "jumps")
end

-- === ОБРАБОТКА ДОНАТА ===
local function handleDonation(amount, donor)
    local intAmount = math.floor(amount)
    local after = intAmount * 0.7
    sendTelegram(string.format("%s получил %d Robux (чистыми %d). От: %s", LocalPlayer.Name, intAmount, after, donor))

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

-- === СЛУШАТЕЛЬ ДОНАТОВ ===
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

-- === ПЕРЕЗАХОД ===
local function rejoinServer()
    debugPrint("Rejoining server...")
    isRunning = false
    wait(1)
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end

-- === РЕЖИМ 1: Попрошайничество (проверенный рабочий код) ===
local function startBegMode()
    debugPrint("Starting Beg Mode")
    currentMode = "Beg"
    isRunning = true

    if not claimStand() then
        debugWarn("Failed to claim stand")
        isRunning = false
        return
    end
    updateStandText("Beg")

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
                wait(10)  -- ждём 10 секунд
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

-- === РЕЖИМ 2: Jump-Robux ===
local function startJumpMode()
    debugPrint("Starting Jump Mode")
    currentMode = "Jump"
    isRunning = true
    serverTime = 0

    if not claimStand() then
        isRunning = false
        return
    end
    updateStandText("Jump")

    while isRunning do
        wait(1)
        serverTime = serverTime + 1
        if antiAfkEnabled then antiAfk() end
        if serverTime >= config.maxServerTime then
            rejoinServer()
            break
        end
    end
    isRunning = false
end

-- === ОСТАНОВКА РЕЖИМА ===
local function stopMode()
    isRunning = false
    currentMode = nil
end

-- === ТЕСТ FAKE DONATE ===
local function fakeDonate()
    debugPrint("Fake donate 5 Robux")
    handleDonation(5, "TEST")
end

-- === ЗАВЕРШЕНИЕ СКРИПТА ===
local function shutdown()
    stopMode()
    if gui then gui:Destroy() end
    debugPrint("Script terminated")
end

-- === СОЗДАНИЕ GUI ===
local function createGUI()
    -- Пытаемся поместить GUI в CoreGui, чтобы он сохранялся после телепорта
    local parent = CoreGui or LocalPlayer:WaitForChild("PlayerGui")
    local screen = Instance.new("ScreenGui")
    screen.Name = "PlsDonateFarm"
    screen.ResetOnSpawn = false
    screen.Parent = parent
    gui = screen

    -- Основной фрейм
    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 500, 0, 750)  -- чуть выше, чтобы вместить кнопки
    main.Position = UDim2.new(0.5, -250, 0.5, -375)
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
    close.MouseButton1Click:Connect(shutdown)

    -- Заголовок
    local title = Instance.new("TextLabel", main)
    title.Size = UDim2.new(1,-40,0,40)
    title.Position = UDim2.new(0,10,0,0)
    title.BackgroundTransparency = 1
    title.Text = "Pls Donate Farm v6.0"
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

    -- Контейнеры для контента
    local begCont = Instance.new("ScrollingFrame", main)
    begCont.Size = UDim2.new(1,-20,0,600)
    begCont.Position = UDim2.new(0,10,0,100)
    begCont.BackgroundTransparency = 1
    begCont.ScrollBarThickness = 5
    begCont.CanvasSize = UDim2.new(0,0,0,700)
    begCont.Visible = true

    local jumpCont = Instance.new("ScrollingFrame", main)
    jumpCont.Size = UDim2.new(1,-20,0,600)
    jumpCont.Position = UDim2.new(0,10,0,100)
    jumpCont.BackgroundTransparency = 1
    jumpCont.ScrollBarThickness = 5
    jumpCont.CanvasSize = UDim2.new(0,0,0,700)
    jumpCont.Visible = false

    -- === ВКЛАДКА "Попрошайничество" ===
    local y = 10
    local descBeg = Instance.new("TextLabel", begCont)
    descBeg.Size = UDim2.new(1,-10,0,90)
    descBeg.Position = UDim2.new(0,5,0,y)
    descBeg.BackgroundTransparency = 0.5
    descBeg.BackgroundColor3 = Color3.fromRGB(30,30,40)
    descBeg.Text = "📢 Режим попрошайничества:\n• Захват стенда (кнопка ниже)\n• Обход всех игроков по очереди\n• Возврат к стенду, перезаход после цикла"
    descBeg.TextColor3 = Color3.fromRGB(200,200,255)
    descBeg.TextWrapped = true
    descBeg.TextXAlignment = Enum.TextXAlignment.Left
    descBeg.Font = Enum.Font.Gotham
    descBeg.TextSize = 14
    y = y + 100

    -- Кнопка ручного захвата стенда
    local claimBtn = Instance.new("TextButton", begCont)
    claimBtn.Size = UDim2.new(1,-10,0,40)
    claimBtn.Position = UDim2.new(0,5,0,y)
    claimBtn.BackgroundColor3 = Color3.fromRGB(255,140,0)
    claimBtn.Text = "🛠 Занять стенд (вручную)"
    claimBtn.TextColor3 = Color3.new(1,1,1)
    claimBtn.Font = Enum.Font.Gotham
    claimBtn.TextScaled = true
    claimBtn.MouseButton1Click:Connect(function()
        claimStand()
    end)
    y = y + 50

    -- Старт/Стоп
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

    -- Кнопка перезахода
    local rejoinBtn = Instance.new("TextButton", begCont)
    rejoinBtn.Size = UDim2.new(1,-10,0,40)
    rejoinBtn.Position = UDim2.new(0,5,0,y)
    rejoinBtn.BackgroundColor3 = Color3.fromRGB(100,100,255)
    rejoinBtn.Text = "🔄 Перезайти на другой сервер"
    rejoinBtn.TextColor3 = Color3.new(1,1,1)
    rejoinBtn.Font = Enum.Font.Gotham
    rejoinBtn.TextScaled = true
    rejoinBtn.MouseButton1Click:Connect(rejoinServer)
    y = y + 50

    -- Чекбокс анти-AFK
    local afkCheckbox = Instance.new("TextButton", begCont)
    afkCheckbox.Size = UDim2.new(1,-10,0,40)
    afkCheckbox.Position = UDim2.new(0,5,0,y)
    afkCheckbox.BackgroundColor3 = Color3.fromRGB(80,80,80)
    afkCheckbox.Text = "⏱ Анти-AFK: ВЫКЛ"
    afkCheckbox.TextColor3 = Color3.new(1,1,1)
    afkCheckbox.Font = Enum.Font.Gotham
    afkCheckbox.TextScaled = true
    afkCheckbox.MouseButton1Click:Connect(function()
        antiAfkEnabled = not antiAfkEnabled
        afkCheckbox.BackgroundColor3 = antiAfkEnabled and Color3.fromRGB(0,150,0) or Color3.fromRGB(80,80,80)
        afkCheckbox.Text = antiAfkEnabled and "⏱ Анти-AFK: ВКЛ" or "⏱ Анти-AFK: ВЫКЛ"
    end)
    y = y + 50

    -- Telegram info
    local tLabel1 = Instance.new("TextLabel", begCont)
    tLabel1.Size = UDim2.new(1,-10,0,30)
    tLabel1.Position = UDim2.new(0,5,0,y)
    tLabel1.BackgroundTransparency = 1
    tLabel1.Text = "Telegram Token (из конфига):"
    tLabel1.TextColor3 = Color3.fromRGB(200,200,200)
    tLabel1.TextXAlignment = Enum.TextXAlignment.Left
    tLabel1.Font = Enum.Font.Gotham
    tLabel1.TextScaled = true
    y = y + 35

    local tToken = Instance.new("TextLabel", begCont)
    tToken.Size = UDim2.new(1,-10,0,30)
    tToken.Position = UDim2.new(0,5,0,y)
    tToken.BackgroundColor3 = Color3.fromRGB(50,50,60)
    tToken.Text = string.sub(config.telegramToken,1,20).."..."
    tToken.TextColor3 = Color3.new(1,1,1)
    tToken.TextWrapped = true
    tToken.Font = Enum.Font.Gotham
    tToken.TextScaled = true
    y = y + 40

    local tLabel2 = Instance.new("TextLabel", begCont)
    tLabel2.Size = UDim2.new(1,-10,0,30)
    tLabel2.Position = UDim2.new(0,5,0,y)
    tLabel2.BackgroundTransparency = 1
    tLabel2.Text = "Chat ID:"
    tLabel2.TextColor3 = Color3.fromRGB(200,200,200)
    tLabel2.TextXAlignment = Enum.TextXAlignment.Left
    tLabel2.Font = Enum.Font.Gotham
    tLabel2.TextScaled = true
    y = y + 35

    local tChat = Instance.new("TextLabel", begCont)
    tChat.Size = UDim2.new(1,-10,0,30)
    tChat.Position = UDim2.new(0,5,0,y)
    tChat.BackgroundColor3 = Color3.fromRGB(50,50,60)
    tChat.Text = config.telegramChatID
    tChat.TextColor3 = Color3.new(1,1,1)
    tChat.TextWrapped = true
    tChat.Font = Enum.Font.Gotham
    tChat.TextScaled = true
    y = y + 50

    begCont.CanvasSize = UDim2.new(0,0,0,y)

    -- === ВКЛАДКА "Jump-Robux" ===
    y = 10
    local descJump = Instance.new("TextLabel", jumpCont)
    descJump.Size = UDim2.new(1,-10,0,100)
    descJump.Position = UDim2.new(0,5,0,y)
    descJump.BackgroundTransparency = 0.5
    descJump.BackgroundColor3 = Color3.fromRGB(30,30,40)
    descJump.Text = "🦘 Режим Jump-Robux:\n• Захват стенда (кнопка ниже)\n• Стоим у стенда, ждём донаты\n• 1 Robux = 4 прыжка (сумма округляется)\n• Таймер 30 мин, сброс при донате"
    descJump.TextColor3 = Color3.fromRGB(200,255,200)
    descJump.TextWrapped = true
    descJump.TextXAlignment = Enum.TextXAlignment.Left
    descJump.Font = Enum.Font.Gotham
    descJump.TextSize = 14
    y = y + 110

    -- Кнопка ручного захвата стенда
    local claimBtn2 = Instance.new("TextButton", jumpCont)
    claimBtn2.Size = UDim2.new(1,-10,0,40)
    claimBtn2.Position = UDim2.new(0,5,0,y)
    claimBtn2.BackgroundColor3 = Color3.fromRGB(255,140,0)
    claimBtn2.Text = "🛠 Занять стенд (вручную)"
    claimBtn2.TextColor3 = Color3.new(1,1,1)
    claimBtn2.Font = Enum.Font.Gotham
    claimBtn2.TextScaled = true
    claimBtn2.MouseButton1Click:Connect(claimStand)
    y = y + 50

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

    -- Кнопка перезахода
    local rejoinBtn2 = Instance.new("TextButton", jumpCont)
    rejoinBtn2.Size = UDim2.new(1,-10,0,40)
    rejoinBtn2.Position = UDim2.new(0,5,0,y)
    rejoinBtn2.BackgroundColor3 = Color3.fromRGB(100,100,255)
    rejoinBtn2.Text = "🔄 Перезайти на другой сервер"
    rejoinBtn2.TextColor3 = Color3.new(1,1,1)
    rejoinBtn2.Font = Enum.Font.Gotham
    rejoinBtn2.TextScaled = true
    rejoinBtn2.MouseButton1Click:Connect(rejoinServer)
    y = y + 50

    -- Чекбокс анти-AFK (для удобства и здесь)
    local afkCheckbox2 = Instance.new("TextButton", jumpCont)
    afkCheckbox2.Size = UDim2.new(1,-10,0,40)
    afkCheckbox2.Position = UDim2.new(0,5,0,y)
    afkCheckbox2.BackgroundColor3 = antiAfkEnabled and Color3.fromRGB(0,150,0) or Color3.fromRGB(80,80,80)
    afkCheckbox2.Text = antiAfkEnabled and "⏱ Анти-AFK: ВКЛ" or "⏱ Анти-AFK: ВЫКЛ"
    afkCheckbox2.TextColor3 = Color3.new(1,1,1)
    afkCheckbox2.Font = Enum.Font.Gotham
    afkCheckbox2.TextScaled = true
    afkCheckbox2.MouseButton1Click:Connect(function()
        antiAfkEnabled = not antiAfkEnabled
        afkCheckbox2.BackgroundColor3 = antiAfkEnabled and Color3.fromRGB(0,150,0) or Color3.fromRGB(80,80,80)
        afkCheckbox2.Text = antiAfkEnabled and "⏱ Анти-AFK: ВКЛ" or "⏱ Анти-AFK: ВЫКЛ"
        -- синхронизируем с первым чекбоксом, если он существует
        if afkCheckbox then
            afkCheckbox.BackgroundColor3 = afkCheckbox2.BackgroundColor3
            afkCheckbox.Text = afkCheckbox2.Text
        end
    end)
    y = y + 50

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

    -- Кнопки управления режимами
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

    debugPrint("GUI created")
end

-- === МЕХАНИЗМ АВТО-ВОССТАНОВЛЕНИЯ ПОСЛЕ ТЕЛЕПОРТА ===
-- Помещаем скрипт в CoreGui, чтобы он сохранялся
local function autoReinit()
    -- Если скрипт уже запущен в CoreGui, не создаём новый GUI
    if not gui then
        createGUI()
    end
    -- При респавне персонажа переинициализируем некоторые функции
    LocalPlayer.CharacterAdded:Connect(function()
        debugPrint("Character respawned, re-initializing...")
        -- Здесь можно восстановить состояние, если нужно
    end)
end

-- Запуск
setupDonationListener()
local success, err = pcall(autoReinit)
if not success then
    warn("[PlsDonateFarm] Error:", err)
else
    debugPrint("Script loaded. Press Right Ctrl to hide/show.")
end

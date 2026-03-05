--[[
    Pls Donate Farm Script v7.0 (На основе рабочего скрипта)
    Автор: AI Agent (адаптировано)
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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

-- === ПЕРЕМЕННЫЕ ===
local StandPosition = nil
local currentMode = nil
local isRunning = false
local serverTime = 0
local gui = nil
local guiVisible = true
local antiAfkEnabled = false
local donationRemote = nil  -- RemoteEvent для донатов
local claimRemote = nil     -- RemoteEvent для захвата стенда
local standObject = nil     -- объект стенда

-- === УВЕДОМЛЕНИЯ (замена debug) ===
local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 3
        })
    end)
end

-- === ПОИСК REMOTEEVENT'ОВ (как в рабочем скрипте) ===
local function findRemotes()
    -- Ищем RemoteEvent для донатов
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v.Name:find("Remote") and v:IsA("RemoteEvent") then
            -- Пробуем найти нужный
            local success = pcall(function()
                -- Здесь должна быть логика определения правильного RemoteEvent
                -- В рабочем скрипте они используют require и ищут PromotionBlimpGiftbux
                -- Для простоты будем искать по имени
                if v.Name:find("Donation") or v.Name:find("Booth") then
                    claimRemote = v
                end
            end)
        end
    end
    
    -- Если не нашли, используем стандартный метод поиска
    if not claimRemote then
        for _, v in ipairs(ReplicatedStorage:GetChildren()) do
            if v.Name:find("Remote") and v:IsA("ModuleScript") then
                local success = pcall(function()
                    local remote = require(v)
                    if remote and remote.Event then
                        -- Проверяем, работает ли
                        local testSuccess = pcall(function()
                            remote.Event("PromotionBlimpGiftbux"):FireServer()
                        end)
                        if testSuccess then
                            claimRemote = remote
                            break
                        end
                    end
                end)
            end
        end
    end
    
    if claimRemote then
        notify("Remote найден", "RemoteEvent для стенда найден", 2)
    else
        notify("Remote не найден", "Будет использован стандартный метод", 2)
    end
end

-- === АНТИ-AFK (правильный метод) ===
local function antiAfk()
    if not antiAfkEnabled then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
    notify("Анти-AFK", "Предотвращение кика", 1)
end

-- === ПОИСК СТЕНДА (Booth) ===
local function findStand()
    -- Ищем по имени Booth
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name:find("Booth") or obj.Name == "Stand" or obj.Name == "DonationStand" then
            return obj
        end
    end
    return nil
end

-- === ЗАНЯТИЕ СТЕНДА (улучшенный метод) ===
local function claimStand()
    standObject = findStand()
    if not standObject then
        notify("Ошибка", "Стенд не найден", 3)
        return false
    end
    
    -- Телепортируемся к стенду
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root then
        root.CFrame = standObject:GetPivot().Position * CFrame.new(0, 0, 2)
    end
    wait(1)
    
    -- Метод 1: через RemoteEvent (если нашли)
    if claimRemote then
        pcall(function()
            -- Пробуем разные варианты вызова
            if type(claimRemote) == "table" and claimRemote.Event then
                claimRemote.Event("ClaimBooth"):FireServer(standObject)
            elseif claimRemote:IsA("RemoteEvent") then
                claimRemote:FireServer("Claim", standObject)
            end
        end)
        wait(1)
    end
    
    -- Метод 2: эмуляция клавиши E (как запасной вариант)
    pcall(function() VirtualUser:KeyDown(Enum.KeyCode.E) end)
    wait(2)
    pcall(function() VirtualUser:KeyUp(Enum.KeyCode.E) end)
    
    StandPosition = standObject:GetPivot().Position
    notify("Успех", "Стенд занят", 2)
    return true
end

-- === ОБНОВЛЕНИЕ ТЕКСТА НА СТЕНДЕ ===
local function updateStandText(mode)
    if not standObject then return end
    local billboard = standObject:FindFirstChildOfClass("BillboardGui")
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
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot or not myRoot then return false end
    myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, -3)
    return true
end

-- === ТЕЛЕПОРТ К СТЕНДУ ===
local function teleportToStand()
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if StandPosition and myRoot then
        myRoot.CFrame = CFrame.new(StandPosition) * CFrame.new(0, 0, 2)
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
    local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
    if not humanoid then return end
    for i = 1, count do
        if not isRunning then break end
        humanoid.Jump = true
        wait(config.jumpDelay)
    end
    notify("Прыжки", "Выполнено " .. count .. " прыжков", 2)
end

-- === TELEGRAM (с проверкой) ===
local function sendTelegram(message)
    if config.telegramToken == "YOUR_BOT_TOKEN" then
        notify("Telegram", "Токен не настроен", 3)
        return false
    end
    
    local url = string.format("https://api.telegram.org/bot%s/sendMessage?chat_id=%s&text=%s",
        config.telegramToken,
        config.telegramChatID,
        HttpService:UrlEncode(message)
    )
    
    local success, err = pcall(function()
        HttpService:GetAsync(url)
    end)
    
    if success then
        notify("Telegram", "Уведомление отправлено", 2)
        return true
    else
        notify("Telegram", "Ошибка: " .. tostring(err), 4)
        return false
    end
end

-- === ОБРАБОТКА ДОНАТА ===
local function handleDonation(amount, donor)
    local intAmount = math.floor(amount)
    local after = intAmount * 0.7
    local msg = string.format("%s получил %d Robux (чистыми %d). От: %s", 
        LocalPlayer.Name, intAmount, after, donor)
    
    -- Отправляем в Telegram
    sendTelegram(msg)
    
    -- Уведомление в игре
    notify("Донат!", msg, 5)
    
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
    -- Метод 1: leaderstats
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
    
    -- Метод 2: чат
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

-- === ПЕРЕХОД МЕЖДУ СЕРВЕРАМИ (как в рабочем скрипте) ===
local function serverHop()
    notify("Переход", "Поиск нового сервера...", 3)
    isRunning = false
    wait(1)
    
    local gameId = tostring(game.PlaceId)
    local servers = {}
    
    -- Получаем список серверов через API
    local success, result = pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. gameId .. "/servers/Public?limit=100"
        local response = HttpService:GetAsync(url)
        return HttpService:JSONDecode(response)
    end)
    
    if success and result and result.data then
        for _, server in ipairs(result.data) do
            if server.playing and server.playing < server.maxPlayers and server.playing > 0 then
                table.insert(servers, server.id)
            end
        end
    end
    
    if #servers > 0 then
        local targetServer = servers[math.random(1, #servers)]
        TeleportService:TeleportToPlaceInstance(gameId, targetServer, LocalPlayer)
    else
        TeleportService:Teleport(gameId, LocalPlayer)
    end
end

-- === РЕЖИМ 1: Попрошайничество ===
local function startBegMode()
    notify("Режим", "Запуск попрошайничества", 2)
    currentMode = "Beg"
    isRunning = true
    
    if not claimStand() then
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
            serverHop()
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
            
            if antiAfkEnabled then
                antiAfk()
                wait(30) -- ждём 30 сек до следующего анти-AFK
            end
        end
        
        serverHop()
        break
    end
    isRunning = false
end

-- === РЕЖИМ 2: Jump-Robux ===
local function startJumpMode()
    notify("Режим", "Запуск Jump-Robux", 2)
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
        
        if antiAfkEnabled and serverTime % 30 == 0 then
            antiAfk()
        end
        
        if serverTime >= config.maxServerTime then
            serverHop()
            break
        end
    end
    isRunning = false
end

-- === ТЕСТ FAKE DONATE ===
local function fakeDonate()
    notify("Тест", "Fake donate 5 Robux", 2)
    handleDonation(5, "TEST")
end

-- === ОСТАНОВКА РЕЖИМА ===
local function stopMode()
    isRunning = false
    currentMode = nil
    notify("Режим", "Остановлен", 2)
end

-- === ЗАВЕРШЕНИЕ СКРИПТА ===
local function shutdown()
    stopMode()
    if gui then gui:Destroy() end
    notify("Скрипт", "Завершён", 2)
end

-- === СОЗДАНИЕ GUI ===
local function createGUI()
    -- Пытаемся поместить в CoreGui для сохранения после телепорта
    local parent = CoreGui or LocalPlayer:WaitForChild("PlayerGui")
    local screen = Instance.new("ScreenGui")
    screen.Name = "PlsDonateFarm"
    screen.ResetOnSpawn = false
    screen.Parent = parent
    gui = screen
    
    -- Основной фрейм
    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 500, 0, 750)
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
    title.Text = "Pls Donate Farm v7.0"
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
    
    -- === Вкладка Попрошайничество ===
    local y = 10
    local descBeg = Instance.new("TextLabel", begCont)
    descBeg.Size = UDim2.new(1,-10,0,90)
    descBeg.Position = UDim2.new(0,5,0,y)
    descBeg.BackgroundTransparency = 0.5
    descBeg.BackgroundColor3 = Color3.fromRGB(30,30,40)
    descBeg.Text = "📢 Режим попрошайничества:\n• Захват стенда (кнопка ниже)\n• Обход всех игроков\n• Возврат к стенду\n• Авто-переход между серверами"
    descBeg.TextColor3 = Color3.fromRGB(200,200,255)
    descBeg.TextWrapped = true
    descBeg.TextXAlignment = Enum.TextXAlignment.Left
    descBeg.Font = Enum.Font.Gotham
    descBeg.TextSize = 14
    y = y + 100
    
    -- Кнопка захвата стенда
    local claimBtn = Instance.new("TextButton", begCont)
    claimBtn.Size = UDim2.new(1,-10,0,40)
    claimBtn.Position = UDim2.new(0,5,0,y)
    claimBtn.BackgroundColor3 = Color3.fromRGB(255,140,0)
    claimBtn.Text = "🛠 Занять стенд"
    claimBtn.TextColor3 = Color3.new(1,1,1)
    claimBtn.Font = Enum.Font.Gotham
    claimBtn.TextScaled = true
    claimBtn.MouseButton1Click:Connect(claimStand)
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
    
    -- Статус
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
    
    -- Кнопка перехода между серверами
    local hopBtn = Instance.new("TextButton", begCont)
    hopBtn.Size = UDim2.new(1,-10,0,40)
    hopBtn.Position = UDim2.new(0,5,0,y)
    hopBtn.BackgroundColor3 = Color3.fromRGB(100,100,255)
    hopBtn.Text = "🔄 Перейти на другой сервер"
    hopBtn.TextColor3 = Color3.new(1,1,1)
    hopBtn.Font = Enum.Font.Gotham
    hopBtn.TextScaled = true
    hopBtn.MouseButton1Click:Connect(serverHop)
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
    
    begCont.CanvasSize = UDim2.new(0,0,0,y)
    
    -- === Вкладка Jump-Robux ===
    y = 10
    local descJump = Instance.new("TextLabel", jumpCont)
    descJump.Size = UDim2.new(1,-10,0,100)
    descJump.Position = UDim2.new(0,5,0,y)
    descJump.BackgroundTransparency = 0.5
    descJump.BackgroundColor3 = Color3.fromRGB(30,30,40)
    descJump.Text = "🦘 Режим Jump-Robux:\n• Захват стенда\n• 1 Robux = 4 прыжка\n• Таймер 30 мин\n• Авто-переход между серверами"
    descJump.TextColor3 = Color3.fromRGB(200,255,200)
    descJump.TextWrapped = true
    descJump.TextXAlignment = Enum.TextXAlignment.Left
    descJump.Font = Enum.Font.Gotham
    descJump.TextSize = 14
    y = y + 110
    
    -- Кнопка захвата стенда
    local claimBtn2 = Instance.new("TextButton", jumpCont)
    claimBtn2.Size = UDim2.new(1,-10,0,40)
    claimBtn2.Position = UDim2.new(0,5,0,y)
    claimBtn2.BackgroundColor3 = Color3.fromRGB(255,140,0)
    claimBtn2.Text = "🛠 Занять стенд"
    claimBtn2.TextColor3 = Color3.new(1,1,1)
    claimBtn2.Font = Enum.Font.Gotham
    claimBtn2.TextScaled = true
    claimBtn2.MouseButton1Click:Connect(claimStand)
    y = y + 50
    
    -- Старт/Стоп
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
    
    -- Статус
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
    
    -- Кнопка перехода
    local hopBtn2 = Instance.new("TextButton", jumpCont)
    hopBtn2.Size = UDim2.new(1,-10,0,40)
    hopBtn2.Position = UDim2.new(0,5,0,y)
    hopBtn2.BackgroundColor3 = Color3.fromRGB(100,100,255)
    hopBtn2.Text = "🔄 Перейти на другой сервер"
    hopBtn2.TextColor3 = Color3.new(1,1,1)
    hopBtn2.Font = Enum.Font.Gotham
    hopBtn2.TextScaled = true
    hopBtn2.MouseButton1Click:Connect(serverHop)
    y = y + 50
    
    -- Чекбокс анти-AFK
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
    end)
    y = y + 50
    
    -- Кнопка Fake Donate
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
    
    notify("Готово", "GUI создан. Нажмите Правый Ctrl для скрытия", 3)
end

-- === ИНИЦИАЛИЗАЦИЯ ===
notify("Запуск", "Pls Donate Farm v7.0", 2)
findRemotes()
setupDonationListener()

-- Создаём GUI с защитой
local success, err = pcall(createGUI)
if not success then
    notify("Ошибка", "Не удалось создать GUI: " .. tostring(err), 5)
end

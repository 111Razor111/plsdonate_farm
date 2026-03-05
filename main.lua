--[[
    Pls Donate Farm Script v3.3 (Финальная рабочая версия)
    Инжектор: Xeno
    Горячая клавиша: Правый Ctrl (скрыть/показать меню)
    Закрытие: Крестик в GUI
]]

-- === КОНФИГУРАЦИЯ (ЗАПОЛНИТЕ СВОИ ДАННЫЕ) ===
local config = {
    telegramToken = "8104787078:AAHiRuOS4gaTxaVRlYU7BV9L8flN_VXGV68",  -- Ваш токен
    telegramChatID = "1981885077",                                     -- Ваш Chat ID
    begMessage = "please donate to me as much as you don't mind, I'm raising money for my favorite set",
    thankYouMessage = "thank you god who came down from heaven",
    jumpThanksMessage = "Thanks you god for this challenge im complete",
    jumpRobuxMessage = "5robux = 20 jump", -- Сообщение на стенде в режиме Jump
    delayBetweenPlayers = 3,
    jumpDelay = 0.4,
    maxServerTime = 30 * 60,       -- 30 минут
    extraTimePerDonation = 10 * 60, -- +10 минут при донате
}
-- ============================================

-- Функция для создания GUI и всего функционала
local function createScript()
    -- Сервисы
    local Players = game:GetService("Players")
    local TeleportService = game:GetService("TeleportService")
    local HttpService = game:GetService("HttpService")
    local UserInputService = game:GetService("UserInputService")
    local TextChatService = game:GetService("TextChatService")
    local VirtualUser = game:GetService("VirtualUser")
    local LocalPlayer = Players.LocalPlayer

    -- Переменные
    local StandPosition = nil          -- Позиция нашего стенда
    local currentMode = nil             -- "Beg" или "Jump"
    local isRunning = false             -- Флаг работы режима
    local serverTime = 0                -- Таймер на сервере (для Jump)
    local gui                            -- Основной GUI элемент
    local guiEnabled = true              -- Флаг видимости GUI

    -- Для отладки (вывод в консоль F9)
    local function debugPrint(...)
        print("[PlsDonateFarm]", ...)
    end
    local function debugWarn(...)
        warn("[PlsDonateFarm]", ...)
    end

    -- Функции для безопасного получения частей персонажа
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

    -- Подписка на респавн персонажа
    LocalPlayer.CharacterAdded:Connect(function()
        debugPrint("Character respawned")
    end)

    -- === Telegram ===
    local function sendTelegramNotification(message)
        if config.telegramToken == "YOUR_BOT_TOKEN" or config.telegramChatID == "YOUR_CHAT_ID" then
            debugWarn("Telegram not configured: set token and chat ID in config")
            return
        end
        local url = string.format("https://api.telegram.org/bot%s/sendMessage?chat_id=%s&text=%s",
            config.telegramToken,
            config.telegramChatID,
            HttpService:UrlEncode(message))
        local success, err = pcall(function()
            HttpService:GetAsync(url)
        end)
        if success then
            debugPrint("Telegram sent: " .. message)
        else
            debugWarn("Telegram send failed:", err)
        end
    end

    -- === Анти-AFK ===
    local function antiAfk()
        local root = getRootPart()
        if not root then return end
        -- Небольшое движение
        root.CFrame = root.CFrame * CFrame.new(1, 0, 0)
        wait(0.1)
        root.CFrame = root.CFrame * CFrame.new(-1, 0, 0)
        -- Имитация нажатия кнопки
        pcall(function()
            VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            wait(0.1)
            VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        end)
        debugPrint("Anti-AFK executed")
    end

    -- === Работа со стендом ===
    local function findStand()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name == "Stand" or obj.Name == "DonationStand" then
                return obj
            end
        end
        local standsFolder = workspace:FindFirstChild("Stands")
        if standsFolder then
            for _, child in ipairs(standsFolder:GetChildren()) do
                if child:IsA("Model") then
                    return child
                end
            end
        end
        return nil
    end

    local function claimStand()
        local stand = findStand()
        if stand then
            StandPosition = stand:GetPivot().Position
            debugPrint("✅ Stand found and claimed at", StandPosition)
            return true
        else
            debugWarn("❌ No stand found")
            return false
        end
    end

    -- Функция для смены текста на стенде
    local function updateStandText(mode)
        local stand = findStand()
        if not stand then return end
        -- Ищем BillboardGui с текстом
        local billboard = stand:FindFirstChildOfClass("BillboardGui")
        if billboard then
            local textLabel = billboard:FindFirstChildOfClass("TextLabel")
            if textLabel then
                if mode == "Beg" then
                    textLabel.Text = "💰 Please Donate!"
                elseif mode == "Jump" then
                    textLabel.Text = config.jumpRobuxMessage
                end
                debugPrint("Stand text updated for mode:", mode)
            end
        end
    end

    -- === Телепортация ===
    local function teleportToPlayer(player)
        local targetChar = player.Character
        local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
        local myRoot = getRootPart()
        if not targetRoot or not myRoot then
            debugWarn("Cannot teleport to", player.Name, "- missing root part")
            return false
        end
        -- Встаем перед игроком
        myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, -3)
        debugPrint("Teleported to", player.Name)
        return true
    end

    local function teleportToStand()
        local myRoot = getRootPart()
        if StandPosition and myRoot then
            myRoot.CFrame = CFrame.new(StandPosition) * CFrame.new(0, 0, 2)
            debugPrint("Returned to stand")
            return true
        end
        debugWarn("Cannot return to stand")
        return false
    end

    -- === Чат ===
    local function sendChatMessage(message)
        pcall(function()
            if TextChatService and TextChatService.TextChannels:FindFirstChild("RBXGeneral") then
                TextChatService.TextChannels.RBXGeneral:SendAsync(message)
            else
                LocalPlayer:Chat(message)
            end
        end)
        debugPrint("Chat sent:", message)
    end

    -- === Обработка донатов ===
    local lastRaisedValue = 0
    local function setupDonationListener()
        -- 1. Отслеживание leaderstats
        local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
        if leaderstats then
            local raised = leaderstats:FindFirstChild("Raised")
            if raised then
                lastRaisedValue = raised.Value
                raised:GetPropertyChangedSignal("Value"):Connect(function()
                    local newValue = raised.Value
                    if newValue > lastRaisedValue then
                        local gained = newValue - lastRaisedValue
                        debugPrint("💰 Donation detected via leaderstats:", gained)
                        handleDonation(gained, "System")
                        lastRaisedValue = newValue
                    end
                end)
                debugPrint("Donation listener (leaderstats) active")
            else
                debugWarn("'Raised' not found in leaderstats")
            end
        else
            debugWarn("leaderstats not found")
        end

        -- 2. Резервный метод: чат
        if TextChatService then
            TextChatService.MessageReceived:Connect(function(message)
                if message.Text and message.Text:find(LocalPlayer.Name) and message.Text:find("donated") then
                    local amount = message.Text:match("donated (%d+) Robux")
                    if amount then
                        amount = tonumber(amount)
                        if amount then
                            debugPrint("Donation detected via chat:", amount)
                            handleDonation(amount, message.FromPlayer and message.FromPlayer.Name or "unknown")
                        end
                    end
                end
            end)
            debugPrint("Donation listener (chat) active")
        end
    end

    -- Функция, вызываемая при донате
    local function handleDonation(amount, donorName)
        local afterCommission = amount * 0.7
        sendChatMessage(config.thankYouMessage)

        -- Telegram
        sendTelegramNotification(string.format("[%s] получил %d Robux (чистыми %d). От: %s",
            LocalPlayer.Name, amount, afterCommission, donorName))

        if currentMode == "Jump" then
            -- В режиме Jump: сбрасываем таймер и выполняем прыжки
            serverTime = 0
            local jumpCount = amount * 4  -- 1 Robux = 4 прыжка
            debugPrint("Jump mode: performing", jumpCount, "jumps")
            performJumps(jumpCount)
            sendChatMessage(config.jumpThanksMessage)
        elseif currentMode == "Beg" then
            -- В режиме Beg просто благодарим (уже сделано выше)
        end
    end

    -- === Прыжки ===
    local function performJumps(count)
        local humanoid = getHumanoid()
        if not humanoid then
            debugWarn("No humanoid to jump")
            return
        end
        for i = 1, count do
            if not isRunning then break end
            humanoid.Jump = true
            wait(config.jumpDelay)
        end
        debugPrint("Performed", count, "jumps")
    end

    -- === Перезаход на другой сервер ===
    local function rejoinServer()
        debugPrint("Rejoining server...")
        isRunning = false
        wait(1)
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end

    -- === РЕЖИМ 1: Попрошайничество (ИСПРАВЛЕН) ===
    local function startBegMode()
        debugPrint("🚀 Starting Beg Mode")
        currentMode = "Beg"
        isRunning = true

        -- 1. Занять стенд
        if not claimStand() then
            debugWarn("Failed to claim stand, retrying...")
            wait(5)
            if not claimStand() then
                debugWarn("No stand found, rejoining...")
                rejoinServer()
                return
            end
        end
        updateStandText("Beg")

        -- 2. Основной цикл обхода игроков
        while isRunning do
            -- Собираем список игроков
            local playerList = {}
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    table.insert(playerList, player)
                end
            end

            debugPrint("Found", #playerList, "players to beg")

            if #playerList == 0 then
                debugPrint("No players, rejoining...")
                rejoinServer()
                break
            end

            -- Обходим каждого
            for _, player in ipairs(playerList) do
                if not isRunning then break end

                -- Шаг 1: Телепорт к игроку
                if teleportToPlayer(player) then
                    wait(1)
                    -- Шаг 2: Отправить сообщение
                    sendChatMessage(config.begMessage)
                    wait(config.delayBetweenPlayers)
                    -- Шаг 3: Вернуться к стенду
                    teleportToStand()
                    wait(1)
                end
                antiAfk()  -- Анти-AFK после каждого игрока
            end

            -- После обхода всех перезаходим
            debugPrint("All players visited, rejoining...")
            rejoinServer()
            break
        end
    end

    -- === РЕЖИМ 2: Jump-Robux ===
    local function startJumpMode()
        debugPrint("🚀 Starting Jump Mode")
        currentMode = "Jump"
        isRunning = true
        serverTime = 0

        -- 1. Занять стенд
        if not claimStand() then
            wait(5)
            if not claimStand() then
                debugWarn("No stand found, rejoining...")
                rejoinServer()
                return
            end
        end
        updateStandText("Jump")

        -- 2. Цикл ожидания
        while isRunning do
            wait(1)
            serverTime = serverTime + 1
            antiAfk()

            -- Проверка таймера
            if serverTime >= config.maxServerTime then
                debugPrint("Max server time reached, rejoining...")
                rejoinServer()
                break
            end
        end
    end

    -- === Тестовая функция Fake Donate ===
    local function fakeDonate()
        debugPrint("🪙 Fake donate triggered (5 Robux)")
        -- Имитируем донат в 5 Robux
        handleDonation(5, "TEST")
    end

    -- === Остановка режима ===
    local function stopMode()
        if isRunning then
            debugPrint("Stopping current mode")
            isRunning = false
            currentMode = nil
        end
    end

    -- === Полное завершение скрипта ===
    local function shutdownScript()
        debugPrint("Shutting down script...")
        stopMode()
        if gui then
            gui:Destroy()
        end
        -- Не уничтожаем сам скрипт, чтобы избежать ошибок
    end

    -- === СОЗДАНИЕ GUI ===
    local function createGUI()
        debugPrint("Creating GUI...")
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "PlsDonateFarm"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        gui = screenGui

        -- Основной фрейм
        local mainFrame = Instance.new("Frame")
        mainFrame.Size = UDim2.new(0, 500, 0, 650)
        mainFrame.Position = UDim2.new(0.5, -250, 0.5, -325)
        mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
        mainFrame.BackgroundTransparency = 0.1
        mainFrame.BorderSizePixel = 0
        mainFrame.Active = true
        mainFrame.Draggable = true
        mainFrame.Parent = screenGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = mainFrame

        -- Кнопка закрытия (крестик)
        local closeButton = Instance.new("TextButton")
        closeButton.Size = UDim2.new(0, 30, 0, 30)
        closeButton.Position = UDim2.new(1, -35, 0, 5)
        closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        closeButton.Text = "X"
        closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeButton.TextScaled = true
        closeButton.Font = Enum.Font.GothamBold
        closeButton.Parent = mainFrame

        local closeCorner = Instance.new("UICorner")
        closeCorner.CornerRadius = UDim.new(0, 5)
        closeCorner.Parent = closeButton

        closeButton.MouseButton1Click:Connect(shutdownScript)

        -- Заголовок
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -40, 0, 40)
        title.Position = UDim2.new(0, 10, 0, 0)
        title.BackgroundTransparency = 1
        title.Text = "Pls Donate Farm v3.3"
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextScaled = true
        title.Font = Enum.Font.GothamBold
        title.Parent = mainFrame

        -- Вкладки
        local tabFrame = Instance.new("Frame")
        tabFrame.Size = UDim2.new(1, -20, 0, 40)
        tabFrame.Position = UDim2.new(0, 10, 0, 50)
        tabFrame.BackgroundTransparency = 1
        tabFrame.Parent = mainFrame

        local begTab = Instance.new("TextButton")
        begTab.Size = UDim2.new(0.5, -5, 1, 0)
        begTab.Position = UDim2.new(0, 0, 0, 0)
        begTab.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        begTab.Text = "💰 Попрошайничество"
        begTab.TextColor3 = Color3.fromRGB(200, 200, 200)
        begTab.Font = Enum.Font.Gotham
        begTab.TextScaled = true
        begTab.Parent = tabFrame

        local jumpTab = Instance.new("TextButton")
        jumpTab.Size = UDim2.new(0.5, -5, 1, 0)
        jumpTab.Position = UDim2.new(0.5, 5, 0, 0)
        jumpTab.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        jumpTab.Text = "🦘 Jump-Robux"
        jumpTab.TextColor3 = Color3.fromRGB(200, 200, 200)
        jumpTab.Font = Enum.Font.Gotham
        jumpTab.TextScaled = true
        jumpTab.Parent = tabFrame

        -- Контейнеры для контента
        local begContent = Instance.new("ScrollingFrame")
        begContent.Size = UDim2.new(1, -20, 0, 500)
        begContent.Position = UDim2.new(0, 10, 0, 100)
        begContent.BackgroundTransparency = 1
        begContent.ScrollBarThickness = 5
        begContent.CanvasSize = UDim2.new(0, 0, 0, 650)
        begContent.Visible = true
        begContent.Parent = mainFrame

        local jumpContent = Instance.new("ScrollingFrame")
        jumpContent.Size = UDim2.new(1, -20, 0, 500)
        jumpContent.Position = UDim2.new(0, 10, 0, 100)
        jumpContent.BackgroundTransparency = 1
        jumpContent.ScrollBarThickness = 5
        jumpContent.CanvasSize = UDim2.new(0, 0, 0, 550)
        jumpContent.Visible = false
        jumpContent.Parent = mainFrame

        -- === НАПОЛНЕНИЕ ВКЛАДКИ "Попрошайничество" ===
        local yPos = 10

        local begDesc = Instance.new("TextLabel")
        begDesc.Size = UDim2.new(1, -10, 0, 80)
        begDesc.Position = UDim2.new(0, 5, 0, yPos)
        begDesc.BackgroundTransparency = 0.5
        begDesc.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        begDesc.Text = "📢 Режим попрошайничества:\n• Автоматический обход всех игроков (подходит спереди)\n• После каждого игрока возвращается к стенду\n• По окончании цикла — перезаход"
        begDesc.TextColor3 = Color3.fromRGB(200, 200, 255)
        begDesc.TextWrapped = true
        begDesc.TextXAlignment = Enum.TextXAlignment.Left
        begDesc.Font = Enum.Font.Gotham
        begDesc.TextSize = 14
        begDesc.Parent = begContent
        yPos = yPos + 90

        local begStart = Instance.new("TextButton")
        begStart.Size = UDim2.new(0.5, -5, 0, 40)
        begStart.Position = UDim2.new(0, 5, 0, yPos)
        begStart.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
        begStart.Text = "▶ Старт"
        begStart.TextColor3 = Color3.fromRGB(255, 255, 255)
        begStart.Font = Enum.Font.Gotham
        begStart.TextScaled = true
        begStart.Parent = begContent

        local begStop = Instance.new("TextButton")
        begStop.Size = UDim2.new(0.5, -5, 0, 40)
        begStop.Position = UDim2.new(0.5, 0, 0, yPos)
        begStop.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
        begStop.Text = "⏹ Стоп"
        begStop.TextColor3 = Color3.fromRGB(255, 255, 255)
        begStop.Font = Enum.Font.Gotham
        begStop.TextScaled = true
        begStop.Parent = begContent
        yPos = yPos + 50

        local begStatus = Instance.new("TextLabel")
        begStatus.Size = UDim2.new(1, -10, 0, 40)
        begStatus.Position = UDim2.new(0, 5, 0, yPos)
        begStatus.BackgroundTransparency = 0.5
        begStatus.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        begStatus.Text = "Статус: Остановлен"
        begStatus.TextColor3 = Color3.fromRGB(255, 255, 255)
        begStatus.TextWrapped = true
        begStatus.Font = Enum.Font.Gotham
        begStatus.TextScaled = true
        begStatus.Parent = begContent
        yPos = yPos + 50

        -- Настройки (только чтение из конфига)
        local begMsgLabel = Instance.new("TextLabel")
        begMsgLabel.Size = UDim2.new(1, -10, 0, 30)
        begMsgLabel.Position = UDim2.new(0, 5, 0, yPos)
        begMsgLabel.BackgroundTransparency = 1
        begMsgLabel.Text = "Сообщение (из конфига):"
        begMsgLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        begMsgLabel.TextXAlignment = Enum.TextXAlignment.Left
        begMsgLabel.Font = Enum.Font.Gotham
        begMsgLabel.TextScaled = true
        begMsgLabel.Parent = begContent
        yPos = yPos + 35

        local begMsgDisplay = Instance.new("TextLabel")
        begMsgDisplay.Size = UDim2.new(1, -10, 0, 40)
        begMsgDisplay.Position = UDim2.new(0, 5, 0, yPos)
        begMsgDisplay.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        begMsgDisplay.Text = config.begMessage
        begMsgDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
        begMsgDisplay.TextWrapped = true
        begMsgDisplay.Font = Enum.Font.Gotham
        begMsgDisplay.TextScaled = true
        begMsgDisplay.Parent = begContent
        yPos = yPos + 50

        -- Telegram (только для чтения)
        local tLabel1 = Instance.new("TextLabel")
        tLabel1.Size = UDim2.new(1, -10, 0, 30)
        tLabel1.Position = UDim2.new(0, 5, 0, yPos)
        tLabel1.BackgroundTransparency = 1
        tLabel1.Text = "Telegram Token (из конфига):"
        tLabel1.TextColor3 = Color3.fromRGB(200, 200, 200)
        tLabel1.TextXAlignment = Enum.TextXAlignment.Left
        tLabel1.Font = Enum.Font.Gotham
        tLabel1.TextScaled = true
        tLabel1.Parent = begContent
        yPos = yPos + 35

        local tTokenDisplay = Instance.new("TextLabel")
        tTokenDisplay.Size = UDim2.new(1, -10, 0, 30)
        tTokenDisplay.Position = UDim2.new(0, 5, 0, yPos)
        tTokenDisplay.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        tTokenDisplay.Text = string.sub(config.telegramToken, 1, 20) .. "..."
        tTokenDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
        tTokenDisplay.TextWrapped = true
        tTokenDisplay.Font = Enum.Font.Gotham
        tTokenDisplay.TextScaled = true
        tTokenDisplay.Parent = begContent
        yPos = yPos + 40

        local tLabel2 = Instance.new("TextLabel")
        tLabel2.Size = UDim2.new(1, -10, 0, 30)
        tLabel2.Position = UDim2.new(0, 5, 0, yPos)
        tLabel2.BackgroundTransparency = 1
        tLabel2.Text = "Chat ID (из конфига):"
        tLabel2.TextColor3 = Color3.fromRGB(200, 200, 200)
        tLabel2.TextXAlignment = Enum.TextXAlignment.Left
        tLabel2.Font = Enum.Font.Gotham
        tLabel2.TextScaled = true
        tLabel2.Parent = begContent
        yPos = yPos + 35

        local tChatDisplay = Instance.new("TextLabel")
        tChatDisplay.Size = UDim2.new(1, -10, 0, 30)
        tChatDisplay.Position = UDim2.new(0, 5, 0, yPos)
        tChatDisplay.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        tChatDisplay.Text = config.telegramChatID
        tChatDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
        tChatDisplay.TextWrapped = true
        tChatDisplay.Font = Enum.Font.Gotham
        tChatDisplay.TextScaled = true
        tChatDisplay.Parent = begContent
        yPos = yPos + 50

        begContent.CanvasSize = UDim2.new(0, 0, 0, yPos + 20)

        -- === НАПОЛНЕНИЕ ВКЛАДКИ "Jump-Robux" ===
        yPos = 10

        local jumpDesc = Instance.new("TextLabel")
        jumpDesc.Size = UDim2.new(1, -10, 0, 90)
        jumpDesc.Position = UDim2.new(0, 5, 0, yPos)
        jumpDesc.BackgroundTransparency = 0.5
        jumpDesc.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        jumpDesc.Text = "🦘 Режим Jump-Robux:\n• Стоим у стенда, ждём донаты\n• 1 Robux = 4 прыжка\n• Если доната нет 30 мин – перезаход\n• Каждый донат сбрасывает таймер"
        jumpDesc.TextColor3 = Color3.fromRGB(200, 255, 200)
        jumpDesc.TextWrapped = true
        jumpDesc.TextXAlignment = Enum.TextXAlignment.Left
        jumpDesc.Font = Enum.Font.Gotham
        jumpDesc.TextSize = 14
        jumpDesc.Parent = jumpContent
        yPos = yPos + 100

        local jumpStart = Instance.new("TextButton")
        jumpStart.Size = UDim2.new(0.5, -5, 0, 40)
        jumpStart.Position = UDim2.new(0, 5, 0, yPos)
        jumpStart.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
        jumpStart.Text = "▶ Старт"
        jumpStart.TextColor3 = Color3.fromRGB(255, 255, 255)
        jumpStart.Font = Enum.Font.Gotham
        jumpStart.TextScaled = true
        jumpStart.Parent = jumpContent

        local jumpStop = Instance.new("TextButton")
        jumpStop.Size = UDim2.new(0.5, -5, 0, 40)
        jumpStop.Position = UDim2.new(0.5, 0, 0, yPos)
        jumpStop.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
        jumpStop.Text = "⏹ Стоп"
        jumpStop.TextColor3 = Color3.fromRGB(255, 255, 255)
        jumpStop.Font = Enum.Font.Gotham
        jumpStop.TextScaled = true
        jumpStop.Parent = jumpContent
        yPos = yPos + 50

        local jumpStatus = Instance.new("TextLabel")
        jumpStatus.Size = UDim2.new(1, -10, 0, 40)
        jumpStatus.Position = UDim2.new(0, 5, 0, yPos)
        jumpStatus.BackgroundTransparency = 0.5
        jumpStatus.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        jumpStatus.Text = "Статус: Остановлен"
        jumpStatus.TextColor3 = Color3.fromRGB(255, 255, 255)
        jumpStatus.TextWrapped = true
        jumpStatus.Font = Enum.Font.Gotham
        jumpStatus.TextScaled = true
        jumpStatus.Parent = jumpContent
        yPos = yPos + 50

        -- Тестовая кнопка Fake Donate
        local fakeDonateBtn = Instance.new("TextButton")
        fakeDonateBtn.Size = UDim2.new(1, -10, 0, 40)
        fakeDonateBtn.Position = UDim2.new(0, 5, 0, yPos)
        fakeDonateBtn.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
        fakeDonateBtn.Text = "🪙 Тест: Fake Donate (5 Robux)"
        fakeDonateBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
        fakeDonateBtn.Font = Enum.Font.Gotham
        fakeDonateBtn.TextScaled = true
        fakeDonateBtn.Parent = jumpContent

        fakeDonateBtn.MouseButton1Click:Connect(fakeDonate)
        yPos = yPos + 50

        -- Настройки (только чтение из конфига)
        local jumpMsgLabel = Instance.new("TextLabel")
        jumpMsgLabel.Size = UDim2.new(1, -10, 0, 30)
        jumpMsgLabel.Position = UDim2.new(0, 5, 0, yPos)
        jumpMsgLabel.BackgroundTransparency = 1
        jumpMsgLabel.Text = "Текст на стенде (из конфига):"
        jumpMsgLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        jumpMsgLabel.TextXAlignment = Enum.TextXAlignment.Left
        jumpMsgLabel.Font = Enum.Font.Gotham
        jumpMsgLabel.TextScaled = true
        jumpMsgLabel.Parent = jumpContent
        yPos = yPos + 35

        local jumpMsgDisplay = Instance.new("TextLabel")
        jumpMsgDisplay.Size = UDim2.new(1, -10, 0, 40)
        jumpMsgDisplay.Position = UDim2.new(0, 5, 0, yPos)
        jumpMsgDisplay.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        jumpMsgDisplay.Text = config.jumpRobuxMessage
        jumpMsgDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
        jumpMsgDisplay.TextWrapped = true
        jumpMsgDisplay.Font = Enum.Font.Gotham
        jumpMsgDisplay.TextScaled = true
        jumpMsgDisplay.Parent = jumpContent
        yPos = yPos + 50

        jumpContent.CanvasSize = UDim2.new(0, 0, 0, yPos + 20)

        -- === Обработчики переключения вкладок ===
        begTab.MouseButton1Click:Connect(function()
            begContent.Visible = true
            jumpContent.Visible = false
        end)

        jumpTab.MouseButton1Click:Connect(function()
            begContent.Visible = false
            jumpContent.Visible = true
        end)

        -- === Обработчики кнопок Старт/Стоп ===
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

        -- === Горячая клавиша (Правый Ctrl) ===
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.KeyCode == Enum.KeyCode.RightControl then
                guiEnabled = not guiEnabled
                screenGui.Enabled = guiEnabled
                debugPrint("GUI toggled:", guiEnabled)
            end
        end)

        debugPrint("GUI created successfully")
        return screenGui
    end

    -- === Инициализация ===
    local function initialize()
        debugPrint("=":rep(50))
        debugPrint("Script initializing...")
        debugPrint("Telegram configured:", config.telegramToken ~= "YOUR_BOT_TOKEN")
        setupDonationListener()

        local success, err = pcall(createGUI)
        if not success then
            debugWarn("GUI creation failed:", err)
        else
            debugPrint("✅ GUI created. Press Right Ctrl to hide/show. Close with X.")
        end
        debugPrint("=":rep(50))
    end

    initialize()
end

-- Запуск скрипта с защитой
local success, err = pcall(createScript)
if not success then
    warn("[PlsDonateFarm] ❌ FATAL ERROR:", err)
else
    print("[PlsDonateFarm] ✅ Script loaded successfully")
end

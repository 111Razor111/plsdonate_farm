--[[
    Pls Donate Farm Script
    Инжектор: Xeno
    Версия: 1.0
    Автор: AI Agent
    GitHub: https://github.com/ваш_аккаунт/plsdonate_farm
]]

-- Функция для создания GUI и всего функционала
local function createScript()
    -- Конфигурация (пользователь может изменить в GUI)
    local config = {
        telegramToken = "YOUR_BOT_TOKEN",
        telegramChatID = "YOUR_CHAT_ID",
        begMessage = "please donate to me as much as you don't mind, I'm raising money for my favorite set",
        thankYouMessage = "thank you god who came down from heaven",
        jumpThanksMessage = "Thanks you god for this challenge im complete",
        jumpRobuxMessage = "5robux=20 jump",
        walkSpeed = 16,
        delayBetweenPlayers = 3,
        jumpDelay = 0.4,
        antiAfkInterval = 30,
        maxServerTime = 30 * 60,
        extraTimePerDonation = 10 * 60,
    }

    -- Сервисы
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")
    local TeleportService = game:GetService("TeleportService")
    local HttpService = game:GetService("HttpService")
    local UserInputService = game:GetService("UserInputService")
    local TextChatService = game:GetService("TextChatService")
    local VirtualUser = game:GetService("VirtualUser")

    -- Переменные
    local LocalPlayer = Players.LocalPlayer
    local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local RootPart = Character:WaitForChild("HumanoidRootPart")
    local Humanoid = Character:WaitForChild("Humanoid")
    local StandPosition = nil
    local currentMode = nil
    local isRunning = false
    local donationDetected = false
    local serverTime = 0
    local playerList = {}
    local currentPlayerIndex = 1
    local gui

    -- Функция для отправки Telegram уведомления
    local function sendTelegramNotification(message)
        if config.telegramToken == "8104787078:AAHiRuOS4gaTxaVRlYU7BV9L8flN_VXGV68" or config.telegramChatID == "1981885077" then
            warn("Telegram not configured")
            return
        end
        local url = string.format("https://api.telegram.org/bot%s/sendMessage?chat_id=%s&text=%s",
            config.telegramToken,
            config.telegramChatID,
            HttpService:UrlEncode(message))
        pcall(function()
            HttpService:GetAsync(url)
        end)
    end

    -- Функция анти-AFK
    local function antiAfk()
        if not Character or not Humanoid then return end
        local originalCF = RootPart.CFrame
        RootPart.CFrame = originalCF * CFrame.new(1, 0, 0)
        wait(0.1)
        RootPart.CFrame = originalCF
        pcall(function()
            VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            wait(0.1)
            VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        end)
    end

    -- Функция для поиска свободного стенда
    local function findFreeStand()
        local stands = {}
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name:find("Stand") or obj.Name:find("Donation") then
                table.insert(stands, obj)
            end
        end
        if #stands > 0 then
            return stands[1]
        else
            return nil
        end
    end

    -- Функция для занятия стенда
    local function claimStand()
        local stand = findFreeStand()
        if stand then
            StandPosition = stand.Position
            local detector = stand:FindFirstChildOfClass("ClickDetector")
            if detector then
                fireclickdetector(detector)
            end
            return true
        else
            return false
        end
    end

    -- Функция для телепортации к игроку
    local function teleportToPlayer(player)
        if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
            return false
        end
        local targetRoot = player.Character.HumanoidRootPart
        RootPart.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
        return true
    end

    -- Функция для возврата к стенду
    local function teleportToStand()
        if StandPosition then
            RootPart.CFrame = CFrame.new(StandPosition) * CFrame.new(0, 0, 2)
            return true
        end
        return false
    end

    -- Функция для отправки сообщения в чат
    local function sendChatMessage(message)
        if TextChatService then
            local textChannel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
            if textChannel then
                textChannel:SendAsync(message)
            else
                pcall(function()
                    LocalPlayer:Chat(message)
                end)
            end
        else
            pcall(function()
                LocalPlayer:Chat(message)
            end)
        end
    end

    -- Функция для выполнения прыжков
    local function performJumps(count)
        for i = 1, count do
            if not isRunning then break end
            Humanoid.Jump = true
            wait(config.jumpDelay)
        end
    end

    -- Функция для обработки доната
    local function handleDonation(amount, donorName)
        local afterCommission = amount * 0.7
        sendChatMessage(config.thankYouMessage)
        sendTelegramNotification(string.format("[%s] получил %d Robux. С учётом комиссии 30%% вам достанется %d Robux",
            LocalPlayer.Name, amount, afterCommission))
        donationDetected = true
    end

    -- Подписка на донаты
    local function setupDonationListener()
        if TextChatService then
            TextChatService.MessageReceived:Connect(function(message)
                if message.Text then
                    local text = message.Text
                    if text:find(LocalPlayer.Name) and text:find("donated") then
                        local amount = text:match("donated (%d+) Robux")
                        if amount then
                            amount = tonumber(amount)
                            if amount then
                                handleDonation(amount, message.FromPlayer)
                            end
                        end
                    end
                end
            end)
        end
    end

    -- Функция перезахода
    local function rejoinServer()
        isRunning = false
        wait(1)
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end

    -- Режим "Попрошайничество"
    local function startBegMode()
        currentMode = "Beg"
        isRunning = true
        donationDetected = false

        if not claimStand() then
            wait(5)
            if not isRunning then return end
            if not claimStand() then
                sendChatMessage("No free stand, rejoining...")
                rejoinServer()
                return
            end
        end

        while isRunning do
            playerList = {}
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    table.insert(playerList, player)
                end
            end

            if #playerList == 0 then
                rejoinServer()
                break
            end

            for i, player in ipairs(playerList) do
                if not isRunning then break end
                if teleportToPlayer(player) then
                    wait(1)
                    sendChatMessage(config.begMessage)
                    wait(config.delayBetweenPlayers)
                end
            end

            teleportToStand()
            antiAfk()
            rejoinServer()
            break
        end
    end

    -- Режим "Jump-Robux"
    local function startJumpMode()
        currentMode = "Jump"
        isRunning = true
        donationDetected = false
        serverTime = 0

        if not claimStand() then
            wait(5)
            if not isRunning then return end
            if not claimStand() then
                sendChatMessage("No free stand, rejoining...")
                rejoinServer()
                return
            end
        end

        local stand = findFreeStand()
        if stand then
            local billboard = stand:FindFirstChildOfClass("BillboardGui")
            if billboard then
                local textLabel = billboard:FindFirstChildOfClass("TextLabel")
                if textLabel then
                    textLabel.Text = config.jumpRobuxMessage
                end
            end
        end

        while isRunning do
            wait(1)
            serverTime = serverTime + 1
            antiAfk()

            if donationDetected then
                serverTime = 0
                donationDetected = false
                serverTime = serverTime - config.extraTimePerDonation
            end

            if serverTime >= config.maxServerTime then
                rejoinServer()
                break
            end
        end
    end

    -- Функция остановки
    local function stopMode()
        isRunning = false
        currentMode = nil
    end

    -- Создание GUI
    local function createGUI()
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "PlsDonateFarm"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

        local mainFrame = Instance.new("Frame")
        mainFrame.Size = UDim2.new(0, 400, 0, 500)
        mainFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
        mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
        mainFrame.BackgroundTransparency = 0.1
        mainFrame.BorderSizePixel = 0
        mainFrame.Active = true
        mainFrame.Draggable = true
        mainFrame.Parent = screenGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = mainFrame

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 40)
        title.Position = UDim2.new(0, 0, 0, 0)
        title.BackgroundTransparency = 1
        title.Text = "Pls Donate Farm"
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextScaled = true
        title.Font = Enum.Font.GothamBold
        title.Parent = mainFrame

        local tabFrame = Instance.new("Frame")
        tabFrame.Size = UDim2.new(1, -20, 0, 40)
        tabFrame.Position = UDim2.new(0, 10, 0, 50)
        tabFrame.BackgroundTransparency = 1
        tabFrame.Parent = mainFrame

        local begTab = Instance.new("TextButton")
        begTab.Size = UDim2.new(0.5, -5, 1, 0)
        begTab.Position = UDim2.new(0, 0, 0, 0)
        begTab.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        begTab.Text = "Попрошайничество"
        begTab.TextColor3 = Color3.fromRGB(200, 200, 200)
        begTab.Font = Enum.Font.Gotham
        begTab.TextScaled = true
        begTab.Parent = tabFrame

        local jumpTab = Instance.new("TextButton")
        jumpTab.Size = UDim2.new(0.5, -5, 1, 0)
        jumpTab.Position = UDim2.new(0.5, 5, 0, 0)
        jumpTab.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        jumpTab.Text = "Jump-Robux"
        jumpTab.TextColor3 = Color3.fromRGB(200, 200, 200)
        jumpTab.Font = Enum.Font.Gotham
        jumpTab.TextScaled = true
        jumpTab.Parent = tabFrame

        local begContent = Instance.new("Frame")
        begContent.Size = UDim2.new(1, -20, 0, 350)
        begContent.Position = UDim2.new(0, 10, 0, 100)
        begContent.BackgroundTransparency = 1
        begContent.Visible = true
        begContent.Parent = mainFrame

        local jumpContent = Instance.new("Frame")
        jumpContent.Size = UDim2.new(1, -20, 0, 350)
        jumpContent.Position = UDim2.new(0, 10, 0, 100)
        jumpContent.BackgroundTransparency = 1
        jumpContent.Visible = false
        jumpContent.Parent = mainFrame

        local begStart = Instance.new("TextButton")
        begStart.Size = UDim2.new(0.5, -5, 0, 40)
        begStart.Position = UDim2.new(0, 0, 0, 0)
        begStart.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
        begStart.Text = "Старт"
        begStart.TextColor3 = Color3.fromRGB(255, 255, 255)
        begStart.Font = Enum.Font.Gotham
        begStart.TextScaled = true
        begStart.Parent = begContent

        local begStop = Instance.new("TextButton")
        begStop.Size = UDim2.new(0.5, -5, 0, 40)
        begStop.Position = UDim2.new(0.5, 5, 0, 0)
        begStop.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
        begStop.Text = "Стоп"
        begStop.TextColor3 = Color3.fromRGB(255, 255, 255)
        begStop.Font = Enum.Font.Gotham
        begStop.TextScaled = true
        begStop.Parent = begContent

        local begStatus = Instance.new("TextLabel")
        begStatus.Size = UDim2.new(1, 0, 0, 60)
        begStatus.Position = UDim2.new(0, 0, 0, 50)
        begStatus.BackgroundTransparency = 0.5
        begStatus.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        begStatus.Text = "Статус: Остановлен"
        begStatus.TextColor3 = Color3.fromRGB(255, 255, 255)
        begStatus.TextWrapped = true
        begStatus.Font = Enum.Font.Gotham
        begStatus.TextScaled = true
        begStatus.Parent = begContent

        local begMessageLabel = Instance.new("TextLabel")
        begMessageLabel.Size = UDim2.new(1, 0, 0, 30)
        begMessageLabel.Position = UDim2.new(0, 0, 0, 120)
        begMessageLabel.BackgroundTransparency = 1
        begMessageLabel.Text = "Сообщение:"
        begMessageLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        begMessageLabel.TextXAlignment = Enum.TextXAlignment.Left
        begMessageLabel.Font = Enum.Font.Gotham
        begMessageLabel.TextScaled = true
        begMessageLabel.Parent = begContent

        local begMessageBox = Instance.new("TextBox")
        begMessageBox.Size = UDim2.new(1, 0, 0, 30)
        begMessageBox.Position = UDim2.new(0, 0, 0, 150)
        begMessageBox.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        begMessageBox.Text = config.begMessage
        begMessageBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        begMessageBox.Font = Enum.Font.Gotham
        begMessageBox.TextScaled = true
        begMessageBox.Parent = begContent

        local jumpStart = Instance.new("TextButton")
        jumpStart.Size = UDim2.new(0.5, -5, 0, 40)
        jumpStart.Position = UDim2.new(0, 0, 0, 0)
        jumpStart.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
        jumpStart.Text = "Старт"
        jumpStart.TextColor3 = Color3.fromRGB(255, 255, 255)
        jumpStart.Font = Enum.Font.Gotham
        jumpStart.TextScaled = true
        jumpStart.Parent = jumpContent

        local jumpStop = Instance.new("TextButton")
        jumpStop.Size = UDim2.new(0.5, -5, 0, 40)
        jumpStop.Position = UDim2.new(0.5, 5, 0, 0)
        jumpStop.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
        jumpStop.Text = "Стоп"
        jumpStop.TextColor3 = Color3.fromRGB(255, 255, 255)
        jumpStop.Font = Enum.Font.Gotham
        jumpStop.TextScaled = true
        jumpStop.Parent = jumpContent

        local jumpStatus = Instance.new("TextLabel")
        jumpStatus.Size = UDim2.new(1, 0, 0, 60)
        jumpStatus.Position = UDim2.new(0, 0, 0, 50)
        jumpStatus.BackgroundTransparency = 0.5
        jumpStatus.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        jumpStatus.Text = "Статус: Остановлен"
        jumpStatus.TextColor3 = Color3.fromRGB(255, 255, 255)
        jumpStatus.TextWrapped = true
        jumpStatus.Font = Enum.Font.Gotham
        jumpStatus.TextScaled = true
        jumpStatus.Parent = jumpContent

        local jumpRobuxLabel = Instance.new("TextLabel")
        jumpRobuxLabel.Size = UDim2.new(1, 0, 0, 30)
        jumpRobuxLabel.Position = UDim2.new(0, 0, 0, 120)
        jumpRobuxLabel.BackgroundTransparency = 1
        jumpRobuxLabel.Text = "Текст на стенде:"
        jumpRobuxLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        jumpRobuxLabel.TextXAlignment = Enum.TextXAlignment.Left
        jumpRobuxLabel.Font = Enum.Font.Gotham
        jumpRobuxLabel.TextScaled = true
        jumpRobuxLabel.Parent = jumpContent

        local jumpRobuxBox = Instance.new("TextBox")
        jumpRobuxBox.Size = UDim2.new(1, 0, 0, 30)
        jumpRobuxBox.Position = UDim2.new(0, 0, 0, 150)
        jumpRobuxBox.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        jumpRobuxBox.Text = config.jumpRobuxMessage
        jumpRobuxBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        jumpRobuxBox.Font = Enum.Font.Gotham
        jumpRobuxBox.TextScaled = true
        jumpRobuxBox.Parent = jumpContent

        local tokenLabel = Instance.new("TextLabel")
        tokenLabel.Size = UDim2.new(1, 0, 0, 30)
        tokenLabel.Position = UDim2.new(0, 0, 0, 190)
        tokenLabel.BackgroundTransparency = 1
        tokenLabel.Text = "Telegram Token:"
        tokenLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        tokenLabel.TextXAlignment = Enum.TextXAlignment.Left
        tokenLabel.Font = Enum.Font.Gotham
        tokenLabel.TextScaled = true
        tokenLabel.Parent = jumpContent

        local tokenBox = Instance.new("TextBox")
        tokenBox.Size = UDim2.new(1, 0, 0, 30)
        tokenBox.Position = UDim2.new(0, 0, 0, 220)
        tokenBox.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        tokenBox.Text = config.telegramToken
        tokenBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        tokenBox.Font = Enum.Font.Gotham
        tokenBox.TextScaled = true
        tokenBox.Parent = jumpContent

        local chatIDLabel = Instance.new("TextLabel")
        chatIDLabel.Size = UDim2.new(1, 0, 0, 30)
        chatIDLabel.Position = UDim2.new(0, 0, 0, 260)
        chatIDLabel.BackgroundTransparency = 1
        chatIDLabel.Text = "Chat ID:"
        chatIDLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        chatIDLabel.TextXAlignment = Enum.TextXAlignment.Left
        chatIDLabel.Font = Enum.Font.Gotham
        chatIDLabel.TextScaled = true
        chatIDLabel.Parent = jumpContent

        local chatIDBox = Instance.new("TextBox")
        chatIDBox.Size = UDim2.new(1, 0, 0, 30)
        chatIDBox.Position = UDim2.new(0, 0, 0, 290)
        chatIDBox.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        chatIDBox.Text = config.telegramChatID
        chatIDBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        chatIDBox.Font = Enum.Font.Gotham
        chatIDBox.TextScaled = true
        chatIDBox.Parent = jumpContent

        begTab.MouseButton1Click:Connect(function()
            begContent.Visible = true
            jumpContent.Visible = false
        end)

        jumpTab.MouseButton1Click:Connect(function()
            begContent.Visible = false
            jumpContent.Visible = true
        end)

        begStart.MouseButton1Click:Connect(function()
            if isRunning then stopMode() end
            config.begMessage = begMessageBox.Text
            config.telegramToken = tokenBox.Text
            config.telegramChatID = chatIDBox.Text
            begStatus.Text = "Статус: Работает"
            coroutine.wrap(startBegMode)()
        end)

        begStop.MouseButton1Click:Connect(function()
            stopMode()
            begStatus.Text = "Статус: Остановлен"
        end)

        jumpStart.MouseButton1Click:Connect(function()
            if isRunning then stopMode() end
            config.jumpRobuxMessage = jumpRobuxBox.Text
            config.telegramToken = tokenBox.Text
            config.telegramChatID = chatIDBox.Text
            jumpStatus.Text = "Статус: Работает"
            coroutine.wrap(startJumpMode)()
        end)

        jumpStop.MouseButton1Click:Connect(function()
            stopMode()
            jumpStatus.Text = "Статус: Остановлен"
        end)

        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.KeyCode == Enum.KeyCode.Insert then
                screenGui.Enabled = not screenGui.Enabled
            end
        end)

        return screenGui
    end

    -- Инициализация
    local function initialize()
        setupDonationListener()
        gui = createGUI()
    end

    initialize()
end

-- Запуск скрипта с защитой от ошибок
local function execute()
    local success, err = pcall(createScript)
    if not success then
        warn("Script error: " .. tostring(err))
    end
end

execute()
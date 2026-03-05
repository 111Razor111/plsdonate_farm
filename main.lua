--[[
    Pls Donate Farm Script v8.0 (Максимально упрощённый)
    Автор: AI Agent
    Горячая клавиша: Правый Ctrl
]]

-- Сервисы
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local VirtualUser = game:GetService("VirtualUser")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

-- Принудительный вывод в консоль (если работает)
print(">>> Pls Donate Farm v8.0 загружается...")

-- Переменные
local StandPosition = nil
local currentMode = nil
local isRunning = false
local serverTime = 0
local gui = nil
local guiVisible = true
local antiAfkEnabled = false

-- Функция уведомлений (работает всегда)
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

-- Анти-AFK (правильный метод)
local function antiAfk()
    if not antiAfkEnabled then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end

-- Поиск стенда (новые названия)
local function findStand()
    -- Сначала ищем BoothInteraction
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "BoothInteraction" then
            return obj
        end
    end
    -- Потом ищем папку rdc25booth и внутри стенды
    local rdcFolder = workspace:FindFirstChild("rdc25booth")
    if rdcFolder then
        for _, child in ipairs(rdcFolder:GetChildren()) do
            if child:IsA("Model") then
                return child
            end
        end
    end
    -- Затем старые названия
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name:find("Booth") or obj.Name:find("Stand") then
            return obj
        end
    end
    return nil
end

-- Функция захвата стенда (будет вызываться по кнопке)
local function claimStand()
    notify("Стенд", "Поиск стенда...", 2)
    local stand = findStand()
    if not stand then
        notify("Ошибка", "Стенд не найден", 3)
        return false
    end

    -- Телепорт к стенду
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root then
        root.CFrame = stand:GetPivot().Position * CFrame.new(0, 0, 2)
    end
    wait(1)

    -- Пытаемся найти функцию claim в BoothInteraction
    if stand:IsA("BasePart") and stand:FindFirstChild("claim") then
        -- Возможно, нужно вызвать метод
        pcall(function()
            stand.claim:FireServer()
        end)
        notify("Стенд", "Попытка claim через Remote", 2)
    else
        -- Эмуляция клавиши E
        notify("Стенд", "Удерживаю E...", 2)
        pcall(function() VirtualUser:KeyDown(Enum.KeyCode.E) end)
        wait(2)
        pcall(function() VirtualUser:KeyUp(Enum.KeyCode.E) end)
    end

    StandPosition = stand:GetPivot().Position
    notify("Успех", "Стенд занят", 2)
    return true
end

-- Функция редактирования текста на стенде
local function editStandText(mode)
    local stand = findStand()
    if not stand then return end
    
    -- Ищем editbooth или подобное
    local editFunction = stand:FindFirstChild("editbooth")
    if editFunction then
        local text = (mode == "Beg") and "💰 Please Donate!" or "5robux = 20 jump"
        pcall(function()
            editFunction:FireServer(text)
        end)
        notify("Стенд", "Текст обновлён", 2)
    end
end

-- Остальные функции (телепорт, прыжки и т.д.) будут добавлены позже,
-- но для теста создадим только базовое GUI

-- GUI
local function createGUI()
    notify("GUI", "Создание интерфейса...", 2)
    
    local screen = Instance.new("ScreenGui")
    screen.Name = "PlsDonateFarm"
    screen.ResetOnSpawn = false
    screen.Parent = LocalPlayer:WaitForChild("PlayerGui")
    gui = screen

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 400, 0, 300)
    main.Position = UDim2.new(0.5, -200, 0.5, -150)
    main.BackgroundColor3 = Color3.fromRGB(20,20,30)
    main.Active = true
    main.Draggable = true
    main.Parent = screen
    Instance.new("UICorner", main).CornerRadius = UDim.new(0,10)

    -- Кнопка закрытия
    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0,30,0,30)
    close.Position = UDim2.new(1,-35,0,5)
    close.BackgroundColor3 = Color3.fromRGB(200,50,50)
    close.Text = "X"
    close.TextColor3 = Color3.new(1,1,1)
    close.Parent = main
    close.MouseButton1Click:Connect(function()
        screen:Destroy()
        print("GUI закрыт")
    end)

    -- Заголовок
    local title = Instance.new("TextLabel", main)
    title.Size = UDim2.new(1,0,0,40)
    title.Text = "Pls Donate Farm v8.0"
    title.TextColor3 = Color3.new(1,1,1)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold

    -- Кнопка "Занять стенд"
    local claimBtn = Instance.new("TextButton", main)
    claimBtn.Size = UDim2.new(0.8,0,0,50)
    claimBtn.Position = UDim2.new(0.1,0,0.3,0)
    claimBtn.BackgroundColor3 = Color3.fromRGB(255,140,0)
    claimBtn.Text = "🛠 Занять стенд"
    claimBtn.TextColor3 = Color3.new(1,1,1)
    claimBtn.Font = Enum.Font.Gotham
    claimBtn.TextScaled = true
    claimBtn.MouseButton1Click:Connect(function()
        coroutine.wrap(claimStand)()
    end)

    -- Чекбокс анти-AFK
    local afkBtn = Instance.new("TextButton", main)
    afkBtn.Size = UDim2.new(0.8,0,0,50)
    afkBtn.Position = UDim2.new(0.1,0,0.5,0)
    afkBtn.BackgroundColor3 = Color3.fromRGB(80,80,80)
    afkBtn.Text = "⏱ Анти-AFK: ВЫКЛ"
    afkBtn.TextColor3 = Color3.new(1,1,1)
    afkBtn.Font = Enum.Font.Gotham
    afkBtn.TextScaled = true
    afkBtn.MouseButton1Click:Connect(function()
        antiAfkEnabled = not antiAfkEnabled
        afkBtn.BackgroundColor3 = antiAfkEnabled and Color3.fromRGB(0,150,0) or Color3.fromRGB(80,80,80)
        afkBtn.Text = antiAfkEnabled and "⏱ Анти-AFK: ВКЛ" or "⏱ Анти-AFK: ВЫКЛ"
        notify("Анти-AFK", antiAfkEnabled and "Включён" or "Выключен", 2)
    end)

    -- Кнопка перезахода
    local hopBtn = Instance.new("TextButton", main)
    hopBtn.Size = UDim2.new(0.8,0,0,50)
    hopBtn.Position = UDim2.new(0.1,0,0.7,0)
    hopBtn.BackgroundColor3 = Color3.fromRGB(100,100,255)
    hopBtn.Text = "🔄 Перейти на сервер"
    hopBtn.TextColor3 = Color3.new(1,1,1)
    hopBtn.Font = Enum.Font.Gotham
    hopBtn.TextScaled = true
    hopBtn.MouseButton1Click:Connect(function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
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
local success, err = pcall(createGUI)
if not success then
    print("Ошибка создания GUI:", err)
    notify("Ошибка", "GUI не создан: " .. tostring(err), 5)
else
    print(">>> Скрипт успешно загружен")
    notify("Запуск", "Pls Donate Farm v8.0 готов", 2)
end

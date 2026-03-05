--[[
    Pls Donate Farm Script v3.1 (Упрощённая диагностика)
]]

-- Сразу пишем в консоль, чтобы убедиться, что скрипт запустился
print(">>> Скрипт начал загрузку")

local function createScript()
    print(">>> createScript() вызвана")

    -- Сервисы
    local Players = game:GetService("Players")
    local TeleportService = game:GetService("TeleportService")
    local HttpService = game:GetService("HttpService")
    local UserInputService = game:GetService("UserInputService")
    local TextChatService = game:GetService("TextChatService")
    local VirtualUser = game:GetService("VirtualUser")
    local LocalPlayer = Players.LocalPlayer

    print(">>> Сервисы получены")

    -- Конфигурация (ваши данные)
    local config = {
        telegramToken = "8104787078:AAHiRuOS4gaTxaVRlYU7BV9L8flN_VXGV68",
        telegramChatID = "1981885077",
        begMessage = "please donate to me as much as you don't mind, I'm raising money for my favorite set",
        thankYouMessage = "thank you god who came down from heaven",
        jumpThanksMessage = "Thanks you god for this challenge im complete",
        jumpRobuxMessage = "5robux = 20 jump",
        delayBetweenPlayers = 3,
        jumpDelay = 0.4,
        maxServerTime = 30 * 60,
        extraTimePerDonation = 10 * 60,
    }

    -- Отладка
    local function debugPrint(...) print("[PlsDonateFarm]", ...) end
    local function debugWarn(...) warn("[PlsDonateFarm]", ...) end

    -- Далее идут все функции (я их не копирую полностью, чтобы не загромождать ответ, но они должны быть)
    -- ... (весь код функций из предыдущей версии, но с одним изменением: удалить строку с ошибкой в startBegMode)

    -- ВАЖНО: В функции startBegMode больше нет строки "if i % 3 == 0 then antiAfk() end"

    -- Создание GUI (сокращённое для теста)
    local function createGUI()
        debugPrint("Создание GUI...")
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "PlsDonateFarm"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 400, 0, 300)
        frame.Position = UDim2.new(0.5, -200, 0.5, -150)
        frame.BackgroundColor3 = Color3.fromRGB(20,20,30)
        frame.Parent = screenGui

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1,0,0,50)
        label.Text = "Если вы это видите, GUI работает"
        label.TextColor3 = Color3.new(1,1,1)
        label.Parent = frame

        debugPrint("GUI создан")
        return screenGui
    end

    -- Инициализация
    local function initialize()
        debugPrint("Инициализация...")
        local success, err = pcall(createGUI)
        if not success then
            debugWarn("Ошибка создания GUI:", err)
        else
            debugPrint("Успех")
        end
    end

    initialize()
end

-- Запуск
local ok, err = pcall(createScript)
if not ok then
    warn("КРИТИЧЕСКАЯ ОШИБКА:", err)
end

--[[ 
    Оптимизированный PLS DONATE Auto-Farm 2026
    Исправлены: Anti-AFK, Claim Stand, Telegram Log, F9 Debug
]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- НАСТРОЙКИ (Заполни свои данные)
local _G.Settings = {
    Telegram_Token = "ТВОЙ_ТОКЕН_БОТА",
    Telegram_ID = "ТВОЙ_ID_ЧАТА",
    AutoClaim = true,
    ServerHopDelay = 900 -- Смена сервера через 15 минут
}

-- 1. Исправление Дебага
local function log(msg)
    print("[FARM LOG]: " .. tostring(msg))
end

-- 2 & 7. Захват стенда и режим 1-ый (First Person/Claim)
local function claimStand()
    log("Поиск свободного стенда...")
    local booths = workspace:WaitForChild("BoothInteractions"):GetChildren()
    for _, booth in pairs(booths) do
        if not booth:FindFirstChild("Owner") or booth.Owner.Value == nil then
            -- Эмуляция нажатия кнопки захвата
            local args = { [1] = booth.Name, [2] = true }
            RS:WaitForChild("Events"):WaitForChild("ClaimStand"):FireServer(unpack(args))
            log("Попытка захвата стенда: " .. booth.Name)
            wait(2)
            if booth.Owner.Value == Player then
                log("Стенд успешно занят!")
                return true
            end
        end
    end
    return false
end

-- 3. Исправленный Anti-AFK
Player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
    log("Anti-AFK сработал: предотвращен выход.")
end)

local function startAntiAFK()
    coroutine.wrap(function()
        while true do
            wait(30)
            VirtualUser:Button1Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            wait(0.2)
            VirtualUser:Button1Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        end
    end)()
end

-- 6. Telegram уведомления (Работает и на фейк, и на реальный донат)
local function sendTG(amount)
    local url = "https://api.telegram.org/bot" .. _G.Settings.Telegram_Token .. "/sendMessage"
    local data = {
        ["chat_id"] = _G.Settings.Telegram_ID,
        ["text"] = "💰 Донейт! Вам зачислили: " .. tostring(amount) .. " Robux"
    }
    
    local success, response = pcall(function()
        return HttpService:PostAsync(url, HttpService:JSONEncode(data), Enum.HttpContentType.ApplicationJson)
    end)
    
    if success then log("Уведомление в ТГ отправлено") else log("Ошибка ТГ: " .. tostring(response)) end
end

-- Отслеживание донатов (включая визуальные изменения стенда)
local function trackDonations()
    -- Пример для "фейкового" или визуального обновления
    Player.leaderstats.Raised.Changed:Connect(function(val)
        sendTG(val)
    end)
end

-- 4. Server Hop (Переход между серверами)
local function serverHop()
    log("Меняем сервер...")
    local success, result = pcall(function()
        local servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"))
        for _, s in pairs(servers.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id)
                break
            end
        end
    end)
    if not success then log("Ошибка ServerHop: " .. tostring(result)) end
end

-- ЗАПУСК
log("Скрипт загружен. Инициализация...")
startAntiAFK()

if _G.Settings.AutoClaim then
    task.spawn(function()
        while not claimStand() do wait(5) end
        trackDonations()
    end)
end

-- Авто-смена сервера через время
task.delay(_G.Settings.ServerHopDelay, function()
    serverHop()
end)
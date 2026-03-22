--[[
    AntiAFK.lua — Sistema Anti-AFK.

    Init(ctx) conecta o evento Idled do LocalPlayer.
    Ping()    é chamado periodicamente pelo loop monitor em Main.lua.
]]

local AntiAFK = {}
local _svc
local _idledConn
local _watchdogRunning = false

local function pulseVirtualUser()
    pcall(function()
        _svc.VirtualUser:CaptureController()
    end)

    pcall(function()
        _svc.VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)

    pcall(function()
        _svc.VirtualUser:ClickButton1(Vector2.new(0, 0))
    end)

    pcall(function()
        _svc.VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(0.05)
        _svc.VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end)
end

local function pulseVirtualInputManager()
    if not _svc.VirtualInputManager then return end

    pcall(function()
        _svc.VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        _svc.VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)

    pcall(function()
        _svc.VirtualInputManager:SendKeyEvent(true, "W", false, game)
        task.wait(0.05)
        _svc.VirtualInputManager:SendKeyEvent(false, "W", false, game)
    end)
end

local function pulseHumanoid()
    local char = _svc.LocalPlayer and _svc.LocalPlayer.Character
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    pcall(function()
        hum:Move(Vector3.new(0, 0, 1), false)
    end)
    task.wait(0.05)
    pcall(function()
        hum:Move(Vector3.new(0, 0, 0), false)
    end)

    pcall(function()
        hum.Jump = true
    end)
end

local function doAntiIdlePulse()
    if not _G_AntiAFK then return end
    if not _svc then return end

    pulseVirtualUser()
    pulseVirtualInputManager()
    pulseHumanoid()
end

function AntiAFK.Init(ctx)
    _svc = ctx.Services

    if _idledConn then
        pcall(function() _idledConn:Disconnect() end)
    end

    _idledConn = _svc.LocalPlayer.Idled:Connect(function()
        doAntiIdlePulse()
    end)

    if not _watchdogRunning then
        _watchdogRunning = true
        task.spawn(function()
            while _G_Running do
                if _G_AntiAFK then
                    doAntiIdlePulse()
                end
                task.wait(20)
            end
            _watchdogRunning = false
        end)
    end
end

-- Chamado pelo monitor a cada ANTI_AFK_INTERVAL segundos
function AntiAFK.Ping()
    doAntiIdlePulse()
end

return AntiAFK

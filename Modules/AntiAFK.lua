--[[
    AntiAFK.lua — Sistema Anti-AFK.

    Init(ctx) conecta o evento Idled do LocalPlayer.
    Ping()    é chamado periodicamente pelo loop monitor em Main.lua.
]]

local AntiAFK = {}
local _svc

function AntiAFK.Init(ctx)
    _svc = ctx.Services

    _svc.LocalPlayer.Idled:Connect(function()
        if not _G_AntiAFK then return end
        pcall(function()
            _svc.VirtualUser:CaptureController()
            _svc.VirtualUser:ClickButton2(Vector2.new())
        end)
    end)
end

-- Chamado pelo monitor a cada ANTI_AFK_INTERVAL segundos
function AntiAFK.Ping()
    if not _G_AntiAFK then return end
    pcall(function()
        _svc.VirtualUser:CaptureController()
        _svc.VirtualUser:ClickButton2(Vector2.new(0, 0))
        _svc.VirtualUser:ClickButton1(Vector2.new(0, 0))
        local char = _svc.LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
            end
        end
    end)
end

return AntiAFK

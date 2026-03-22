--[[
    GUI/Toggles.lua — Cria os toggles (switches) da interface.

    Build(Main, ctx) adiciona os 6 toggles ao frame Main.
    Cada toggle utliza TweenService para animar o knob e a cor de fundo,
    e chama um callback que altera o respectivo flag _G_*.
]]

local Toggles = {}

local function createToggle(parent, label, pos, cfg, svc, callback)
    local Container                    = Instance.new("Frame", parent)
    Container.Size                     = UDim2.new(0.9, 0, 0, 25)
    Container.Position                 = pos
    Container.BackgroundTransparency   = 1

    local Label                        = Instance.new("TextLabel", Container)
    Label.Size                         = UDim2.new(0.6, 0, 1, 0)
    Label.Text                         = label
    Label.Font                         = Enum.Font.GothamBold
    Label.TextColor3                   = cfg.Colors.LightGray
    Label.TextSize                     = 10
    Label.TextXAlignment               = Enum.TextXAlignment.Left
    Label.BackgroundTransparency       = 1

    local SwitchBG                     = Instance.new("TextButton", Container)
    SwitchBG.Size                      = UDim2.new(0, 35, 0, 16)
    SwitchBG.Position                  = UDim2.new(0.7, 0, 0.2, 0)
    SwitchBG.BackgroundColor3          = cfg.Colors.Red
    SwitchBG.Text                      = ""
    Instance.new("UICorner", SwitchBG).CornerRadius = UDim.new(1, 0)

    local Knob                         = Instance.new("Frame", SwitchBG)
    Knob.Size                          = UDim2.new(0, 12, 0, 12)
    Knob.Position                      = UDim2.new(0, 2, 0.5, -6)
    Knob.BackgroundColor3              = cfg.Colors.White
    Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

    local state = false
    SwitchBG.MouseButton1Click:Connect(function()
        state = not state
        local targetPos   = state and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
        local targetColor = state and Color3.fromRGB(0, 150, 80)  or cfg.Colors.Red
        svc.TweenService:Create(Knob,     TweenInfo.new(0.2), {Position        = targetPos  }):Play()
        svc.TweenService:Create(SwitchBG, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
        callback(state)
    end)
end

function Toggles.Build(Main, ctx)
    local cfg = ctx.Config
    local svc = ctx.Services

    -- Posições absolutas em pixels (Y) para evitar sobreposição com botões
    local defs = {
        {"MAGNET STEALTH",      UDim2.new(0.05, 0, 0,  35), function(v) _G_AutoCollect = v end},
        {"AUTO-BUILD REMOTE",   UDim2.new(0.05, 0, 0,  63), function(v) _G_AutoBuild   = v end},
        {"AUTO-GIFTS (GUI)",    UDim2.new(0.05, 0, 0,  91), function(v) _G_AutoGifts   = v end},
        {"JUMP INFINITY",       UDim2.new(0.05, 0, 0, 119), function(v) _G_InfJump     = v end},
        {"MAX RANGE ESP (RGB)", UDim2.new(0.05, 0, 0, 147), function(v) _G_ESP         = v end},
        {"ANTI-AFK MARINES",   UDim2.new(0.05, 0, 0, 175), function(v) _G_AntiAFK     = v end},
    }

    for _, def in ipairs(defs) do
        createToggle(Main, def[1], def[2], cfg, svc, def[3])
    end
end

return Toggles

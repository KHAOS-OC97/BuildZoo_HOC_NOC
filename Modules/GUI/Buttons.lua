--[[
    GUI/Buttons.lua — Botões de ação: WalkSpeed, Loja de Frutas, Server Hop e TP.

    Build(Main, ctx) cria os 4 botões com borda RGB e conecta os callbacks
    aos módulos Movement, ServerHop e Teleport já inicializados em ctx.
]]

local Buttons = {}

local BASE_Y = 0.52
local STEP   = 0.06

local function makeBtn(parent, text, pos, cfg)
    local btn                    = Instance.new("TextButton", parent)
    btn.Size                     = UDim2.new(0.9, 0, 0, 25)
    btn.Position                 = pos
    btn.BackgroundColor3         = cfg.Colors.Dark
    btn.BackgroundTransparency   = 0.3
    btn.Text                     = text
    btn.TextColor3               = cfg.Colors.White
    btn.Font                     = Enum.Font.GothamBold
    btn.TextSize                 = 10

    local stroke                 = Instance.new("UIStroke", btn)
    stroke.Thickness             = 1.5
    stroke.ApplyStrokeMode       = Enum.ApplyStrokeMode.Border

    return btn, stroke
end

function Buttons.Build(Main, ctx)
    local cfg       = ctx.Config
    local svc       = ctx.Services
    local state     = ctx.State
    local stored    = state.Stored
    local Movement  = ctx.Movement
    local ServerHop = ctx.ServerHop
    local Teleport  = ctx.Teleport

    local strokes = {}   -- rastreia strokes para o loop RGB

    local function addBtn(text, pos)
        local btn, stroke = makeBtn(Main, text, pos, cfg)
        table.insert(strokes, stroke)
        return btn
    end

    -- ── WalkSpeed ─────────────────────────────────────────────────────────────
    local SpeedBtn = addBtn(
        "WALKSPEED: " .. tostring(_G_WalkSpeed),
        UDim2.new(0.05, 0, BASE_Y, 0)
    )
    stored.SpeedBtn = SpeedBtn
    SpeedBtn.MouseButton1Click:Connect(function()
        local newSpeed = Movement.CycleSpeed(cfg.WALK_SPEED_CYCLE)
        SpeedBtn.Text  = "WALKSPEED: " .. tostring(newSpeed)
    end)

    -- ── Loja de Frutas ────────────────────────────────────────────────────────
    local FruitBtn = addBtn(
        "OPEN FRUIT SHOP",
        UDim2.new(0.05, 0, BASE_Y + STEP * 1.5, 0)
    )
    stored.FruitBtn = FruitBtn
    FruitBtn.MouseButton1Click:Connect(function()
        pcall(function()
            local pg = svc.LocalPlayer.PlayerGui
            for _, v in pairs(pg:GetDescendants()) do
                if v:IsA("Frame") or v:IsA("CanvasGroup") or v:IsA("ScrollingFrame") then
                    local n = v.Name:lower()
                    for _, kw in pairs(cfg.FRUIT_SHOP_KEYWORDS) do
                        if n:find(kw) then
                            v.Visible = not v.Visible
                            if v.Parent:IsA("Frame") or v.Parent:IsA("CanvasGroup") then
                                v.Parent.Visible = true
                            end
                        end
                    end
                elseif v:IsA("ScreenGui") then
                    local n = v.Name:lower()
                    for _, kw in pairs(cfg.FRUIT_SHOP_KEYWORDS) do
                        if n:find(kw) then v.Enabled = not v.Enabled end
                    end
                end
            end
        end)
    end)

    -- ── Server Hop ────────────────────────────────────────────────────────────
    local HopBtn = addBtn(
        "SERVER HOP (EXTRAÇÃO)",
        UDim2.new(0.05, 0, BASE_Y + STEP * 3, 0)
    )
    stored.HopBtn = HopBtn
    HopBtn.MouseButton1Click:Connect(function()
        ServerHop.Hop()
    end)

    -- ── TP para Aliado ────────────────────────────────────────────────────────
    -- Posição com offset de pixel para ocupar a lacuna entre HopBtn e DropdownBtn
    local TPBtn = addBtn(
        "🚀 EXTRAÇÃO TP",
        UDim2.new(0.05, 0, BASE_Y + STEP * 3.5, -125)
    )
    stored.TPBtn = TPBtn
    TPBtn.MouseButton1Click:Connect(function()
        Teleport.ToAlly()
    end)

    -- ── Loop RGB dos strokes ──────────────────────────────────────────────────
    task.spawn(function()
        while _G_Running do
            local anyAlive = false
            pcall(function()
                for _, s in ipairs(strokes) do
                    s.Color = state.GlobalColor
                    anyAlive = true
                end
            end)
            if not anyAlive then break end
            task.wait(0.02)
        end
    end)
end

return Buttons

--[[
    GUI/Buttons.lua — Botões de ação do painel principal.

    Build(Main, ctx) cria os botões de WalkSpeed, Loja de Frutas, TP,
    Big Pets, Server Hop e EMOTE com borda RGB e conecta os callbacks
    aos módulos já inicializados em ctx.
]]

local Buttons = {}

local BTN_START = 207
local BTN_STEP  = 34
local BTN_HEIGHT = 25
local LEFT_X = 0.05
local RIGHT_X = 0.525
local HALF_W = 0.425

local function makeBtn(parent, text, pos, size, cfg)
    local btn                    = Instance.new("TextButton", parent)
    btn.Size                     = size or UDim2.new(0.9, 0, 0, BTN_HEIGHT)
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
    local Fly       = ctx.Fly
    local BigPetFeed = ctx.BigPetFeed
    local ServerHop = ctx.ServerHop

    local strokes = {}   -- rastreia strokes para o loop RGB

    local function addBtn(text, xScale, yPixel, widthScale)
        local btn, stroke = makeBtn(
            Main,
            text,
            UDim2.new(xScale or LEFT_X, 0, 0, yPixel),
            UDim2.new(widthScale or 0.9, 0, 0, BTN_HEIGHT),
            cfg
        )
        table.insert(strokes, stroke)
        return btn
    end

    -- ── Linha 1: WalkSpeed | Server Hop ──────────────────────────────────────
    local SpeedBtn = addBtn("WALKSPEED: " .. tostring(_G_WalkSpeed), LEFT_X, BTN_START, HALF_W)
    stored.SpeedBtn = SpeedBtn
    SpeedBtn.MouseButton1Click:Connect(function()
        local newSpeed = Movement.CycleSpeed(cfg.WALK_SPEED_CYCLE)
        SpeedBtn.Text  = "WALKSPEED: " .. tostring(newSpeed)
    end)

    local HopBtn = addBtn("SERVER HOP", RIGHT_X, BTN_START, HALF_W)
    stored.HopBtn = HopBtn
    HopBtn.MouseButton1Click:Connect(function()
        ServerHop.Hop()
    end)

    -- ── Linha 2: Emote | Fly ─────────────────────────────────────────────────
    local Emotes = ctx.Emotes
    local EmoteBtn = addBtn("EMOTE", LEFT_X, BTN_START + BTN_STEP, HALF_W)
    stored.EmoteBtn = EmoteBtn
    EmoteBtn.MouseButton1Click:Connect(function()
        if Emotes and type(Emotes.Toggle) == "function" then
            Emotes.Toggle()
            EmoteBtn.Text = Emotes.IsOpen() and "EMOTE: ON" or "EMOTE"
        end
    end)

    local FlyBtn = addBtn(_G_Fly and "FLY: ON" or "FLY: OFF", RIGHT_X, BTN_START + BTN_STEP, HALF_W)
    stored.FlyBtn = FlyBtn
    FlyBtn.MouseButton1Click:Connect(function()
        if Fly and type(Fly.Toggle) == "function" then
            local enabled = Fly.Toggle()
            FlyBtn.Text = enabled and "FLY: ON" or "FLY: OFF"
        end
    end)

    -- ── Linha 3: Fruit Shop | Food BP ───────────────────────────────────────
    local FruitBtn = addBtn("OPEN FRUIT SHOP", LEFT_X, BTN_START + BTN_STEP * 2, HALF_W)
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

    local BigPetsFeedBtn = addBtn(_G_BigPetsFeed and "FOOD BP: ON" or "FOOD BP: OFF", RIGHT_X, BTN_START + BTN_STEP * 2, HALF_W)
    BigPetsFeedBtn.TextSize = 9
    stored.BigPetsFeedBtn = BigPetsFeedBtn
    BigPetsFeedBtn.MouseButton1Click:Connect(function()
        _G_BigPetsFeed = not _G_BigPetsFeed
        BigPetsFeedBtn.Text = _G_BigPetsFeed and "FOOD BP: ON" or "FOOD BP: OFF"
        if _G_BigPetsFeed and BigPetFeed and type(BigPetFeed.Pulse) == "function" then
            task.spawn(function()
                pcall(function() BigPetFeed.Pulse() end)
            end)
        end
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

--[[
        GUI/FruitMenu.lua — Linha de ações do AutoBuy e botões auxiliares.

        Build(Main, ctx) cria:
            · AUTO BUY + SCAN no padrão visual RGB
            · BASE + PRISMATIC como placeholders visuais
            · COLLECT COIN ocupando a linha inteira
            · Painel diagnóstico do AutoBuy
]]

local FruitMenu = {}

local AUTOBUY_Y   = 311
local EXTRA_ROW_Y = 345
local COLLECT_Y   = 379
local LEFT_X      = 0.05
local RIGHT_X     = 0.525
local HALF_W      = 0.425
local FULL_W      = 0.9
local BTN_H       = 25
local AUTOBUY_W   = 0.58
local SCAN_X      = 0.67
local SCAN_W      = 0.28

function FruitMenu.Build(Main, ctx)
    local cfg    = ctx.Config
    local state  = ctx.State
    local stored = state.Stored
    local AutoBuy = ctx.AutoBuy
    local Teleport = ctx.Teleport

    local function attachRGBStroke(target, thickness, transparency)
        local stroke = Instance.new("UIStroke")
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Thickness = thickness or 1.2
        stroke.Transparency = transparency or 0.15
        stroke.Color = state.GlobalColor
        stroke.Parent = target

        task.spawn(function()
            while _G_Running and stroke.Parent and target.Parent do
                stroke.Color = state.GlobalColor
                task.wait(0.05)
            end
        end)

        return stroke
    end

    local function addPanelGradient(target)
        local gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(38, 38, 38)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 18, 18)),
        })
        gradient.Rotation = 90
        gradient.Parent = target
        return gradient
    end

    local function setDiagVisible(visible)
        state.AutoBuyDiagVisible = visible == true
        if stored.AutoBuyDiagPanel then
            stored.AutoBuyDiagPanel.Visible = state.AutoBuyDiagVisible
        end
        if stored.AutoBuyScanBtn then
            stored.AutoBuyScanBtn.Text = state.AutoBuyDiagVisible and "CLOSE" or "SCAN"
        end
    end

    local function makeRGBButton(text, xScale, yPixel, widthScale)
        local button                 = Instance.new("TextButton", Main)
        button.Size                  = UDim2.new(widthScale, 0, 0, BTN_H)
        button.Position              = UDim2.new(xScale, 0, 0, yPixel)
        button.BackgroundColor3      = cfg.Colors.Dark
        button.BackgroundTransparency = 0.3
        button.Text                  = text
        button.TextColor3            = cfg.Colors.White
        button.Font                  = Enum.Font.GothamBold
        button.TextSize              = 10
        attachRGBStroke(button, 1.4, 0.05)
        return button
    end

    -- ── AUTO BUY ──────────────────────────────────────────────────────────────
    local AutoBuyBtn                   = makeRGBButton(_G_AutoBuy and "AUTO BUY: ON" or "AUTO BUY: OFF", LEFT_X, AUTOBUY_Y, AUTOBUY_W)
    AutoBuyBtn.TextSize                = 11
    stored.AutoBuyBtn = AutoBuyBtn

    AutoBuyBtn.MouseButton1Click:Connect(function()
        _G_AutoBuy = not _G_AutoBuy
        AutoBuyBtn.Text             = _G_AutoBuy and "AUTO BUY: ON" or "AUTO BUY: OFF"

        if _G_AutoBuy and AutoBuy and type(AutoBuy.RunNow) == "function" then
            task.spawn(function()
                AutoBuy.RunNow("Toggle AUTO BUY")
            end)
        end
    end)

    local ScanBtn                   = makeRGBButton("SCAN", SCAN_X, AUTOBUY_Y, SCAN_W)
    stored.AutoBuyScanBtn = ScanBtn

    ScanBtn.MouseButton1Click:Connect(function()
        setDiagVisible(not state.AutoBuyDiagVisible)
    end)

    local BaseBtn                   = makeRGBButton("BASE", LEFT_X, EXTRA_ROW_Y, HALF_W)
    stored.BaseBtn = BaseBtn
    BaseBtn.MouseButton1Click:Connect(function()
        if Teleport and type(Teleport.ToNamedPoint) == "function" then
            Teleport.ToNamedPoint("BASE")
        end
    end)

    local PrismaticBtn              = makeRGBButton("PRISMATIC", RIGHT_X, EXTRA_ROW_Y, HALF_W)
    PrismaticBtn.TextSize           = 9
    stored.PrismaticBtn = PrismaticBtn
    PrismaticBtn.MouseButton1Click:Connect(function()
        if Teleport and type(Teleport.ToNamedPoint) == "function" then
            Teleport.ToNamedPoint("PRISMATIC")
        end
    end)

    local CollectCoin = nil
    pcall(function() CollectCoin = require(script.Parent.Parent.CollectCoin) end)
    local CollectCoinBtn            = makeRGBButton("COLLECT COIN: OFF", LEFT_X, COLLECT_Y, FULL_W)
    CollectCoinBtn.TextSize         = 11
    stored.CollectCoinBtn = CollectCoinBtn
    local autoCollectActive = _G_AutoCollect or false
    local autoCollectThread = nil
    local function setCollectBtnState(active)
        CollectCoinBtn.Text = active and "COLLECT COIN: ON" or "COLLECT COIN: OFF"
        CollectCoinBtn.BackgroundColor3 = active and Color3.fromRGB(0, 100, 0) or cfg.Colors.Dark
    end
    setCollectBtnState(autoCollectActive)
    CollectCoinBtn.MouseButton1Click:Connect(function()
        autoCollectActive = not autoCollectActive
        _G_AutoCollect = autoCollectActive
        setCollectBtnState(autoCollectActive)
        if autoCollectActive then
            if CollectCoin and type(CollectCoin.CollectAll) == "function" then
                autoCollectThread = task.spawn(function()
                    while autoCollectActive and _G_Running do
                        CollectCoin.CollectAll()
                        task.wait(1)
                    end
                end)
            end
        else
            -- Thread será interrompida naturalmente pelo flag
        end
    end)

    local DiagPanel                  = Instance.new("Frame", Main.Parent)
    DiagPanel.Size                   = UDim2.new(0, 320, 0, 300)
    DiagPanel.Position               = UDim2.new(Main.Position.X.Scale, Main.Position.X.Offset - 350, Main.Position.Y.Scale, Main.Position.Y.Offset + 20)
    DiagPanel.BackgroundColor3       = cfg.Colors.DarkMid
    DiagPanel.BackgroundTransparency = 0.04
    DiagPanel.BorderSizePixel        = 0
    DiagPanel.Visible                = state.AutoBuyDiagVisible == true
    DiagPanel.Active                 = true
    DiagPanel.Draggable              = true
    Instance.new("UICorner", DiagPanel).CornerRadius = UDim.new(0, 6)
    stored.AutoBuyDiagPanel = DiagPanel
    addPanelGradient(DiagPanel)
    attachRGBStroke(DiagPanel, 1.6, 0.05)

    local DiagTitle                  = Instance.new("TextLabel", DiagPanel)
    DiagTitle.Size                   = UDim2.new(0.48, 0, 0, 18)
    DiagTitle.Position               = UDim2.new(0, 5, 0, 3)
    DiagTitle.BackgroundTransparency = 1
    DiagTitle.Text                   = "AUTO BUY DIAGNOSTIC"
    DiagTitle.TextColor3             = cfg.Colors.White
    DiagTitle.Font                   = Enum.Font.GothamBold
    DiagTitle.TextSize               = 10
    DiagTitle.TextXAlignment         = Enum.TextXAlignment.Left

    local DiagClose                  = Instance.new("TextButton", DiagPanel)
    DiagClose.Size                   = UDim2.new(0, 20, 0, 18)
    DiagClose.Position               = UDim2.new(1, -24, 0, 3)
    DiagClose.BackgroundTransparency = 1
    DiagClose.Text                   = "×"
    DiagClose.TextColor3             = cfg.Colors.White
    DiagClose.TextStrokeTransparency = 0.75
    DiagClose.Font                   = Enum.Font.GothamBold
    DiagClose.TextSize               = 14

    local DiagMetaFrame                  = Instance.new("Frame", DiagPanel)
    DiagMetaFrame.Size                   = UDim2.new(0.5, -6, 0, 18)
    DiagMetaFrame.Position               = UDim2.new(0.5, 0, 0, 3)
    DiagMetaFrame.BackgroundTransparency = 1

    local DiagMetaLayout                 = Instance.new("UIListLayout", DiagMetaFrame)
    DiagMetaLayout.FillDirection         = Enum.FillDirection.Horizontal
    DiagMetaLayout.HorizontalAlignment   = Enum.HorizontalAlignment.Right
    DiagMetaLayout.Padding               = UDim.new(0, 8)

    local DiagCountLabel                 = Instance.new("TextLabel", DiagMetaFrame)
    DiagCountLabel.Size                  = UDim2.new(0, 58, 1, 0)
    DiagCountLabel.BackgroundTransparency = 1
    DiagCountLabel.Text                  = "LINES: 0"
    DiagCountLabel.TextColor3            = cfg.Colors.LightGray
    DiagCountLabel.Font                  = Enum.Font.Code
    DiagCountLabel.TextSize              = 9
    stored.AutoBuyDiagCountLabel = DiagCountLabel

    local DiagTimeLabel                  = Instance.new("TextLabel", DiagMetaFrame)
    DiagTimeLabel.Size                   = UDim2.new(0, 108, 1, 0)
    DiagTimeLabel.BackgroundTransparency = 1
    DiagTimeLabel.Text                   = "UPDATED: --:--:--"
    DiagTimeLabel.TextColor3             = cfg.Colors.LightGray
    DiagTimeLabel.Font                   = Enum.Font.Code
    DiagTimeLabel.TextSize               = 9
    stored.AutoBuyDiagTimeLabel = DiagTimeLabel

    local DiagActions                = Instance.new("Frame", DiagPanel)
    DiagActions.Size                 = UDim2.new(1, -10, 0, 26)
    DiagActions.Position             = UDim2.new(0, 5, 0, 24)
    DiagActions.BackgroundTransparency = 1

    local DiagActionsLayout          = Instance.new("UIListLayout", DiagActions)
    DiagActionsLayout.FillDirection  = Enum.FillDirection.Horizontal
    DiagActionsLayout.Padding        = UDim.new(0, 6)
    DiagActionsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left

    local function makeDiagBtn(parent, text, color)
        local button                 = Instance.new("TextButton", parent)
        button.Size                  = UDim2.new(0, 76, 1, 0)
        button.BackgroundColor3      = color
        button.BackgroundTransparency = 0.08
        button.Text                  = text
        button.TextColor3            = cfg.Colors.White
        button.TextStrokeTransparency = 0.75
        button.Font                  = Enum.Font.GothamBold
        button.TextSize              = 11
        button.AutoButtonColor       = true
        Instance.new("UICorner", button).CornerRadius = UDim.new(0, 6)
        return button
    end

    local DiagScanBtn = makeDiagBtn(DiagActions, "SCAN", cfg.Colors.Gray)
    local DiagCopyBtn = makeDiagBtn(DiagActions, "COPY LOG", cfg.Colors.Green)
    local DiagClearBtn = makeDiagBtn(DiagActions, "CLEAR LOG", cfg.Colors.DarkRed)
    DiagCopyBtn.Size = UDim2.new(0, 88, 1, 0)
    DiagClearBtn.Size = UDim2.new(0, 94, 1, 0)
    attachRGBStroke(DiagScanBtn, 1.2, 0.08)
    attachRGBStroke(DiagCopyBtn, 1.2, 0.08)
    attachRGBStroke(DiagClearBtn, 1.2, 0.08)

    local DiagScroll                  = Instance.new("ScrollingFrame", DiagPanel)
    DiagScroll.Size                   = UDim2.new(1, -10, 1, -58)
    DiagScroll.Position               = UDim2.new(0, 5, 0, 50)
    DiagScroll.BackgroundColor3       = cfg.Colors.Dark
    DiagScroll.BackgroundTransparency = 0.2
    DiagScroll.BorderSizePixel        = 0
    DiagScroll.ScrollBarThickness     = 6
    DiagScroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
    DiagScroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
    Instance.new("UICorner", DiagScroll).CornerRadius = UDim.new(0, 6)
    addPanelGradient(DiagScroll)
    attachRGBStroke(DiagScroll, 1.1, 0.18)

    local DiagLogLabel                   = Instance.new("TextLabel", DiagScroll)
    DiagLogLabel.Size                    = UDim2.new(1, -10, 0, 0)
    DiagLogLabel.Position                = UDim2.new(0, 5, 0, 5)
    DiagLogLabel.BackgroundTransparency  = 1
    DiagLogLabel.AutomaticSize           = Enum.AutomaticSize.Y
    DiagLogLabel.Text                    = state.AutoBuyDiagLogText or "AUTO BUY DIAGNOSTIC LOG\nPronto para scan."
    DiagLogLabel.TextColor3              = cfg.Colors.LightGray
    DiagLogLabel.Font                    = Enum.Font.Code
    DiagLogLabel.TextSize                = 10
    DiagLogLabel.RichText                = true
    DiagLogLabel.TextWrapped             = false
    DiagLogLabel.TextXAlignment          = Enum.TextXAlignment.Left
    DiagLogLabel.TextYAlignment          = Enum.TextYAlignment.Top
    stored.AutoBuyDiagLogLabel = DiagLogLabel

    DiagClose.MouseButton1Click:Connect(function()
        setDiagVisible(false)
    end)

    DiagScanBtn.MouseButton1Click:Connect(function()
        if AutoBuy and type(AutoBuy.DebugScan) == "function" then
            task.spawn(function()
                AutoBuy.DebugScan("Painel diagnostico")
            end)
        end
    end)

    DiagCopyBtn.MouseButton1Click:Connect(function()
        if AutoBuy and type(AutoBuy.CopyDiagnosticLog) == "function" then
            task.spawn(function()
                AutoBuy.CopyDiagnosticLog()
            end)
        end
    end)

    DiagClearBtn.MouseButton1Click:Connect(function()
        if AutoBuy and type(AutoBuy.ClearDiagnosticLog) == "function" then
            task.spawn(function()
                AutoBuy.ClearDiagnosticLog()
            end)
        end
    end)

    setDiagVisible(state.AutoBuyDiagVisible == true)
end

return FruitMenu

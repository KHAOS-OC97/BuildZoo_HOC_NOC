--[[
    GUI/FruitMenu.lua — Dropdown de seleção de frutas, botões AUTO BUY e Amount.

    Build(Main, ctx) cria:
      · DropdownBtn  — abre/fecha o painel de frutas com tween
      · Menu + ScrollingFrame — lista de frutas clicáveis
      · Select All / Clear / Close — ações em lote
    · AutoBuyBtn   — ativa/desativa _G_AutoBuy
]]

local FruitMenu = {}

-- Botões de ação terminam em ~335px (207 + 32*4 = 335)
local DROPDOWN_Y  = 367
local AUTOBUY_Y   = 395

function FruitMenu.Build(Main, ctx)
    local cfg    = ctx.Config
    local svc    = ctx.Services
    local state  = ctx.State
    local stored = state.Stored
    local AutoBuy = ctx.AutoBuy

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

    -- Inicializa SelectedFruits para frutas ainda não registradas
    for _, f in ipairs(cfg.FRUITS) do
        if state.SelectedFruits[f.name] == nil then
            state.SelectedFruits[f.name] = false
        end
    end

    -- ── Botão dropdown ────────────────────────────────────────────────────────
    local DropdownBtn                  = Instance.new("TextButton", Main)
    DropdownBtn.Size                   = UDim2.new(0.9, 0, 0, 25)
    DropdownBtn.Position               = UDim2.new(0.05, 0, 0, DROPDOWN_Y)
    DropdownBtn.BackgroundColor3       = cfg.Colors.Dark
    DropdownBtn.BackgroundTransparency = 0.3
    DropdownBtn.Text                   = "▼ Select Fruits (0)"
    DropdownBtn.TextColor3             = cfg.Colors.White
    DropdownBtn.Font                   = Enum.Font.GothamBold
    DropdownBtn.TextSize               = 10
    stored.DropdownBtn = DropdownBtn

    -- ── AUTO BUY ──────────────────────────────────────────────────────────────
    local AutoBuyBtn                   = Instance.new("TextButton", Main)
    AutoBuyBtn.Size                    = UDim2.new(0.58, 0, 0, 22)
    AutoBuyBtn.Position                = UDim2.new(0.05, 0, 0, AUTOBUY_Y)
    AutoBuyBtn.BackgroundColor3        = _G_AutoBuy and cfg.Colors.Green or cfg.Colors.DarkRed
    AutoBuyBtn.Text                    = _G_AutoBuy and "AUTO BUY: ON" or "AUTO BUY: OFF"
    AutoBuyBtn.TextColor3              = cfg.Colors.White
    AutoBuyBtn.Font                    = Enum.Font.GothamBold
    AutoBuyBtn.TextSize                = 11
    Instance.new("UICorner", AutoBuyBtn).CornerRadius = UDim.new(0, 6)
    stored.AutoBuyBtn = AutoBuyBtn

    AutoBuyBtn.MouseButton1Click:Connect(function()
        _G_AutoBuy = not _G_AutoBuy
        AutoBuyBtn.Text             = _G_AutoBuy and "AUTO BUY: ON"           or "AUTO BUY: OFF"
        AutoBuyBtn.BackgroundColor3 = _G_AutoBuy and cfg.Colors.Green or cfg.Colors.DarkRed

        if _G_AutoBuy and AutoBuy and type(AutoBuy.RunNow) == "function" then
            task.spawn(function()
                AutoBuy.RunNow("Toggle AUTO BUY")
            end)
        end
    end)

    local ScanBtn                   = Instance.new("TextButton", Main)
    ScanBtn.Size                    = UDim2.new(0.28, 0, 0, 20)
    ScanBtn.Position                = UDim2.new(0.67, 0, 0, AUTOBUY_Y + 1)
    ScanBtn.BackgroundColor3        = cfg.Colors.Dark
    ScanBtn.BackgroundTransparency  = 0.15
    ScanBtn.Text                    = "SCAN"
    ScanBtn.TextColor3              = cfg.Colors.White
    ScanBtn.TextStrokeTransparency  = 0.75
    ScanBtn.Font                    = Enum.Font.GothamBold
    ScanBtn.TextSize                = 10
    Instance.new("UICorner", ScanBtn).CornerRadius = UDim.new(0, 6)
    stored.AutoBuyScanBtn = ScanBtn
    attachRGBStroke(ScanBtn, 1.4, 0.05)

    ScanBtn.MouseButton1Click:Connect(function()
        setDiagVisible(not state.AutoBuyDiagVisible)
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

    -- ── Frame do menu (expande/colapsa com tween) ─────────────────────────────
    local Menu                  = Instance.new("Frame", Main)
    Menu.Size                   = UDim2.new(0.9, 0, 0, 0)
    Menu.Position               = UDim2.new(0.05, 0, 0, DROPDOWN_Y + 28)
    Menu.BackgroundColor3       = cfg.Colors.DarkMid
    Menu.BorderSizePixel        = 0
    Menu.Visible                = false
    Instance.new("UICorner", Menu).CornerRadius = UDim.new(0, 6)
    stored.Menu = Menu

    local MenuScroll                    = Instance.new("ScrollingFrame", Menu)
    MenuScroll.Size                     = UDim2.new(1, 0, 1, 0)
    MenuScroll.BackgroundTransparency   = 1
    MenuScroll.BorderSizePixel          = 0
    MenuScroll.ScrollBarThickness       = 6
    MenuScroll.CanvasSize               = UDim2.new(0, 0, 0, #cfg.FRUITS * 32)
    MenuScroll.AutomaticCanvasSize      = Enum.AutomaticSize.Y
    stored.MenuScroll = MenuScroll

    local MenuLayout                    = Instance.new("UIListLayout", MenuScroll)
    MenuLayout.Padding                  = UDim.new(0, 4)
    MenuLayout.HorizontalAlignment      = Enum.HorizontalAlignment.Left
    MenuLayout.SortOrder                = Enum.SortOrder.LayoutOrder

    -- ── Helper: atualiza texto do dropdown ────────────────────────────────────
    local function updateDropdownText()
        local count = 0
        for _, v in pairs(state.SelectedFruits) do if v then count = count + 1 end end
        DropdownBtn.Text = (Menu.Visible and "▲ " or "▼ ") .. "Select Fruits (" .. count .. ")"
    end

    -- ── Itens de fruta ────────────────────────────────────────────────────────
    local itemButtons = {}
    stored.itemButtons = itemButtons

    for _, fruit in ipairs(cfg.FRUITS) do
        local btn                  = Instance.new("TextButton")
        btn.Size                   = UDim2.new(1, -8, 0, 28)
        btn.BackgroundColor3       = cfg.Colors.DarkItem
        btn.TextColor3             = cfg.Colors.LightGray
        btn.Font                   = Enum.Font.Gotham
        btn.TextSize               = 12
        btn.TextXAlignment         = Enum.TextXAlignment.Left
        btn.AutoButtonColor        = false
        btn.Text                   = "  [ ] " .. fruit.name .. "  (" .. fruit.price .. ")"
        btn.Parent                 = MenuScroll

        btn.MouseButton1Click:Connect(function()
            state.SelectedFruits[fruit.name] = not state.SelectedFruits[fruit.name]
            if state.SelectedFruits[fruit.name] then
                btn.BackgroundColor3 = cfg.Colors.DarkGreen
                btn.TextColor3       = cfg.Colors.White
                btn.Text             = "  [✔] " .. fruit.name .. "  (" .. fruit.price .. ")"
            else
                btn.BackgroundColor3 = cfg.Colors.DarkItem
                btn.TextColor3       = cfg.Colors.LightGray
                btn.Text             = "  [ ] " .. fruit.name .. "  (" .. fruit.price .. ")"
            end
            updateDropdownText()
        end)

        table.insert(itemButtons, {name = fruit.name, price = fruit.price, button = btn})
    end

    -- ── Linha de ações (Select All / Clear / Close) ───────────────────────────
    local actionsFrame                  = Instance.new("Frame")
    actionsFrame.Size                   = UDim2.new(1, 0, 0, 30)
    actionsFrame.BackgroundTransparency = 1
    actionsFrame.Parent                 = MenuScroll

    local actionsLayout                 = Instance.new("UIListLayout", actionsFrame)
    actionsLayout.FillDirection         = Enum.FillDirection.Horizontal
    actionsLayout.HorizontalAlignment   = Enum.HorizontalAlignment.Center
    actionsLayout.Padding               = UDim.new(0, 6)

    local function makeMenuBtn(parent, text, size, color)
        local b                 = Instance.new("TextButton", parent)
        b.Size                  = size
        b.BackgroundColor3      = color
        b.Text                  = text
        b.TextColor3            = cfg.Colors.White
        b.Font                  = Enum.Font.GothamBold
        b.TextSize              = 12
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        return b
    end

    local SelectAllBtn = makeMenuBtn(actionsFrame, "Select All", UDim2.new(0, 70, 1, 0), cfg.Colors.Green)
    local ClearBtn     = makeMenuBtn(actionsFrame, "Clear",      UDim2.new(0, 40, 1, 0), cfg.Colors.Gray)
    local CloseMenuBtn = makeMenuBtn(actionsFrame, "Close",      UDim2.new(0, 60, 1, 0), Color3.fromRGB(180, 50, 50))
    CloseMenuBtn.Font  = Enum.Font.Gotham

    -- ── Lógica open/close com tween ───────────────────────────────────────────
    local function closeMenu()
        if not Menu.Visible then return end
        svc.TweenService:Create(Menu, TweenInfo.new(0.18, Enum.EasingStyle.Quad),
            {Size = UDim2.new(0.9, 0, 0, 0)}):Play()
        task.wait(0.18)
        Menu.Visible = false
        updateDropdownText()
    end

    local function openMenu()
        if Menu.Visible then return end
        Menu.Visible = true
        Menu.Size    = UDim2.new(0.9, 0, 0, 0)
        local expandedH = math.min(32 * #cfg.FRUITS + 44, 240)
        svc.TweenService:Create(Menu, TweenInfo.new(0.18, Enum.EasingStyle.Quad),
            {Size = UDim2.new(0.9, 0, 0, expandedH)}):Play()
        updateDropdownText()
    end

    -- ── Callbacks dos botões de ação ──────────────────────────────────────────
    SelectAllBtn.MouseButton1Click:Connect(function()
        for _, entry in ipairs(itemButtons) do
            state.SelectedFruits[entry.name]  = true
            entry.button.BackgroundColor3     = cfg.Colors.DarkGreen
            entry.button.TextColor3           = cfg.Colors.White
            entry.button.Text                 = "  [✔] " .. entry.name .. "  (" .. entry.price .. ")"
        end
        updateDropdownText()
    end)

    ClearBtn.MouseButton1Click:Connect(function()
        for _, entry in ipairs(itemButtons) do
            state.SelectedFruits[entry.name]  = false
            entry.button.BackgroundColor3     = cfg.Colors.DarkItem
            entry.button.TextColor3           = cfg.Colors.LightGray
            entry.button.Text                 = "  [ ] " .. entry.name .. "  (" .. entry.price .. ")"
        end
        updateDropdownText()
    end)

    CloseMenuBtn.MouseButton1Click:Connect(closeMenu)
    DropdownBtn.MouseButton1Click:Connect(function()
        if Menu.Visible then closeMenu() else openMenu() end
    end)
end

return FruitMenu

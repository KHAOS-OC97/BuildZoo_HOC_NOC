--[[
    GUI/FruitMenu.lua — Dropdown de seleção de frutas, botões AUTO BUY e Amount.

    Build(Main, ctx) cria:
      · DropdownBtn  — abre/fecha o painel de frutas com tween
      · Menu + ScrollingFrame — lista de frutas clicáveis
      · Select All / Clear / Close — ações em lote
      · AutoBuyBtn   — ativa/desativa _G_AutoBuy
      · AmountSmallBtn — cicla o valor de _G_BuyAmount
]]

local FruitMenu = {}

-- Botões de ação terminam em ~335px (207 + 32*4 = 335)
local DROPDOWN_Y  = 367
local AUTOBUY_Y   = 395
local DEBUG_Y     = 423

function FruitMenu.Build(Main, ctx)
    local cfg    = ctx.Config
    local svc    = ctx.Services
    local state  = ctx.State
    local stored = state.Stored
    local AutoBuy = ctx.AutoBuy

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
    AutoBuyBtn.Size                    = UDim2.new(0.28, 0, 0, 22)
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

    -- ── Amount ────────────────────────────────────────────────────────────────
    local AmountSmallBtn                   = Instance.new("TextButton", Main)
    AmountSmallBtn.Size                    = UDim2.new(0.28, 0, 0, 20)
    AmountSmallBtn.Position                = UDim2.new(0.36, 0, 0, AUTOBUY_Y)
    AmountSmallBtn.BackgroundColor3        = Color3.fromRGB(10, 10, 10)
    AmountSmallBtn.BackgroundTransparency  = 0.2
    AmountSmallBtn.Text                    = "Amt: " .. tostring(_G_BuyAmount)
    AmountSmallBtn.TextColor3              = cfg.Colors.White
    AmountSmallBtn.Font                    = Enum.Font.Gotham
    AmountSmallBtn.TextSize                = 10
    Instance.new("UICorner", AmountSmallBtn).CornerRadius = UDim.new(0, 6)
    stored.AmountSmallBtn = AmountSmallBtn

    AmountSmallBtn.MouseButton1Click:Connect(function()
        if     _G_BuyAmount < 5  then _G_BuyAmount = _G_BuyAmount + 1
        elseif _G_BuyAmount < 20 then _G_BuyAmount = 20
        else                          _G_BuyAmount = 1 end
        AmountSmallBtn.Text = "Amt: " .. tostring(_G_BuyAmount)
    end)

    local ScanBtn                   = Instance.new("TextButton", Main)
    ScanBtn.Size                    = UDim2.new(0.28, 0, 0, 20)
    ScanBtn.Position                = UDim2.new(0.67, 0, 0, AUTOBUY_Y)
    ScanBtn.BackgroundColor3        = cfg.Colors.Gray
    ScanBtn.BackgroundTransparency  = 0.15
    ScanBtn.Text                    = "SCAN"
    ScanBtn.TextColor3              = cfg.Colors.White
    ScanBtn.Font                    = Enum.Font.GothamBold
    ScanBtn.TextSize                = 10
    Instance.new("UICorner", ScanBtn).CornerRadius = UDim.new(0, 6)
    stored.AutoBuyScanBtn = ScanBtn

    ScanBtn.MouseButton1Click:Connect(function()
        if AutoBuy and type(AutoBuy.DebugScan) == "function" then
            task.spawn(function()
                AutoBuy.DebugScan("Botao SCAN")
            end)
        end
    end)

    -- ── Debug AutoBuy ────────────────────────────────────────────────────────
    local DebugFrame                   = Instance.new("Frame", Main)
    DebugFrame.Size                    = UDim2.new(0.9, 0, 0, 86)
    DebugFrame.Position                = UDim2.new(0.05, 0, 0, DEBUG_Y)
    DebugFrame.BackgroundColor3        = cfg.Colors.DarkMid
    DebugFrame.BackgroundTransparency  = 0.15
    DebugFrame.BorderSizePixel         = 0
    Instance.new("UICorner", DebugFrame).CornerRadius = UDim.new(0, 6)
    stored.AutoBuyDebugFrame = DebugFrame

    local DebugTitle                   = Instance.new("TextLabel", DebugFrame)
    DebugTitle.Size                    = UDim2.new(1, -10, 0, 18)
    DebugTitle.Position                = UDim2.new(0, 5, 0, 2)
    DebugTitle.BackgroundTransparency  = 1
    DebugTitle.Text                    = "AUTO BUY DEBUG"
    DebugTitle.TextColor3              = cfg.Colors.White
    DebugTitle.Font                    = Enum.Font.GothamBold
    DebugTitle.TextSize                = 10
    DebugTitle.TextXAlignment          = Enum.TextXAlignment.Left

    local DebugLabel                   = Instance.new("TextLabel", DebugFrame)
    DebugLabel.Size                    = UDim2.new(1, -10, 1, -22)
    DebugLabel.Position                = UDim2.new(0, 5, 0, 20)
    DebugLabel.BackgroundTransparency  = 1
    DebugLabel.Text                    = state.AutoBuyDebugText or "AUTO BUY DEBUG\nAguardando varredura..."
    DebugLabel.TextColor3              = cfg.Colors.LightGray
    DebugLabel.Font                    = Enum.Font.Code
    DebugLabel.TextSize                = 10
    DebugLabel.TextWrapped             = true
    DebugLabel.TextXAlignment          = Enum.TextXAlignment.Left
    DebugLabel.TextYAlignment          = Enum.TextYAlignment.Top
    stored.AutoBuyDebugLabel = DebugLabel

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

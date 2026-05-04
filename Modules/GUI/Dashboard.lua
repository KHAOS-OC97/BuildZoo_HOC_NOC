--[[
    GUI/Dashboard.lua — Janela de estatísticas, temas e atalhos.
    Mostra coins de entrada, coins atuais, delta e permite salvar/restore.
]]

local Dashboard = {}

local function formatNumber(value)
    if type(value) ~= "number" then
        return tostring(value or "0")
    end
    local absValue = math.abs(value)
    if absValue >= 1e9 then
        return string.format("%.2fB", value / 1e9)
    elseif absValue >= 1e6 then
        return string.format("%.2fM", value / 1e6)
    elseif absValue >= 1e3 then
        return string.format("%.1fK", value / 1e3)
    end
    return string.format("%d", math.floor(value + 0.5))
end

local function createLabel(parent, text, pos, size, cfg)
    local label = Instance.new("TextLabel", parent)
    label.Size = size or UDim2.new(1, 0, 0, 18)
    label.Position = pos or UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = cfg.Colors.White
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    return label
end

local function createButton(parent, text, pos, cfg)
    local button = Instance.new("TextButton", parent)
    button.Size = UDim2.new(0, 130, 0, 24)
    button.Position = pos
    button.BackgroundColor3 = cfg.Colors.Dark
    button.BackgroundTransparency = 0.2
    button.Text = text
    button.TextColor3 = cfg.Colors.White
    button.Font = Enum.Font.GothamBold
    button.TextSize = 11
    button.AutoButtonColor = true
    local corner = Instance.new("UICorner", button)
    corner.CornerRadius = UDim.new(0, 8)
    return button
end

local function updateHotkeyButtons(cfg, state)
    for _, row in ipairs(state.HotkeyRows or {}) do
        local keyName = row.Action and row.KeyButton and row.KeyButton.Text
        if row.Action and row.KeyButton then
            row.KeyButton.Text = state.SavedPrefs.GetHotkey(row.Action)
        end
    end
end

local function getDashboardTarget(parent)
    local gui = parent
    while gui and not gui:IsA("ScreenGui") do
        gui = gui.Parent
    end
    return gui
end

function Dashboard.Build(Main, ctx)
    local cfg = ctx.Config
    local state = ctx.State
    local stored = state.Stored
    state.SavedPrefs = state.SavedPrefs or {}
    local prefs = ctx.SavedPreferences
    local toast = ctx.Toast
    local svc = ctx.Services

    local screenGui = Main.Parent
    local dashboard = stored.DashboardFrame
    if dashboard and dashboard.Parent then
        return
    end

    if dashboard and dashboard.Parent == nil then
        dashboard:Destroy()
        stored.DashboardFrame = nil
        dashboard = nil
    end

    dashboard = Instance.new("Frame")
    dashboard.Name = "HOC_NOC_Dashboard"
    dashboard.Size = UDim2.new(0, 300, 0, 420)
    dashboard.Position = UDim2.new(0, 20, 0, 80)
    dashboard.BackgroundColor3 = cfg.Colors.DarkMid
    dashboard.BorderSizePixel = 0
    dashboard.Active = true
    dashboard.Draggable = true
    dashboard.Parent = screenGui
    stored.DashboardFrame = dashboard
    Instance.new("UICorner", dashboard).CornerRadius = UDim.new(0, 14)

    local title = createLabel(dashboard, "SESSION DASHBOARD", UDim2.new(0, 0, 0, 8), UDim2.new(1, -16, 0, 18), cfg)
    title.Position = UDim2.new(0, 8, 0, 8)

    local subtitle = createLabel(dashboard, "Monitora coins, tema e atalhos.", UDim2.new(0, 8, 0, 26), UDim2.new(1, -16, 0, 16), cfg)
    subtitle.TextSize = 10
    subtitle.TextColor3 = cfg.Colors.LightGray

    local baselineLabel = createLabel(dashboard, "Coins na entrada:", UDim2.new(0, 8, 0, 54), nil, cfg)
    local baselineValue = createLabel(dashboard, formatNumber(prefs:GetBaseline()), UDim2.new(0, 8, 0, 74), nil, cfg)
    baselineValue.TextColor3 = cfg.Colors.Green
    local currentLabel = createLabel(dashboard, "Coins agora:", UDim2.new(0, 8, 0, 98), nil, cfg)
    local currentValue = createLabel(dashboard, "0", UDim2.new(0, 8, 0, 118), nil, cfg)
    currentValue.TextColor3 = cfg.Colors.Green
    local deltaLabel = createLabel(dashboard, "Delta:", UDim2.new(0, 8, 0, 142), nil, cfg)
    local deltaValue = createLabel(dashboard, "0", UDim2.new(0, 8, 0, 162), nil, cfg)
    deltaValue.TextColor3 = cfg.Colors.LightGray

    local function refreshStats()
        local current = prefs:GetCurrentCurrency()
        local baseline = prefs:GetBaseline()
        baselineValue.Text = formatNumber(baseline)
        currentValue.Text = formatNumber(current)
        local delta = current - baseline
        deltaValue.Text = (delta >= 0 and "+" or "") .. formatNumber(delta)
        deltaValue.TextColor3 = delta >= 0 and cfg.Colors.Green or cfg.Colors.Red
    end

    refreshStats()
    task.spawn(function()
        while _G_Running and dashboard.Parent do
            refreshStats()
            task.wait(2)
        end
    end)

    local themeLabel = createLabel(dashboard, "Tema atual:", UDim2.new(0, 8, 0, 190), nil, cfg)
    themeLabel.TextSize = 11
    themeLabel.TextColor3 = cfg.Colors.LightGray

    local themeX = 8
    local themeY = 212
    local themeButtons = {}
    for themeName, _ in pairs(cfg.ThemePresets or {}) do
        local button = createButton(dashboard, themeName, UDim2.new(0, themeX, 0, themeY), cfg)
        button.TextSize = 10
        button.MouseButton1Click:Connect(function()
            if prefs:SetTheme(themeName) then
                if ctx.Config then
                    ctx.SavedPreferences.ApplyTheme(ctx.Config)
                end
                if stored.ScreenGui and stored.ScreenGui.Parent then
                    pcall(function()
                        stored.ScreenGui:Destroy()
                    end)
                    state.ClearStored()
                    ctx.GUI.Core.Build(ctx)
                end
                if toast then
                    toast.Show(ctx, "Tema salvo: " .. themeName, 3)
                end
            end
        end)
        themeX = themeX + 96
        table.insert(themeButtons, button)
    end

    local hotkeyHeader = createLabel(dashboard, "Atalhos customizáveis:", UDim2.new(0, 8, 0, 254), nil, cfg)
    hotkeyHeader.TextSize = 11
    hotkeyHeader.TextColor3 = cfg.Colors.LightGray

    local hotkeyActions = {
        { id = "ToggleGui", label = "Toggle GUI" },
        { id = "ToggleDashboard", label = "Toggle Dashboard" },
        { id = "ToggleFly", label = "Toggle Fly" },
        { id = "ToggleAutoBuy", label = "Toggle AutoBuy" },
    }

    state.HotkeyRows = {}
    local rowY = 276
    for _, action in ipairs(hotkeyActions) do
        local label = createLabel(dashboard, action.label, UDim2.new(0, 8, 0, rowY), UDim2.new(0.52, 0, 0, 18), cfg)
        local keyButton = createButton(dashboard, prefs:GetHotkey(action.id), UDim2.new(0, 156, 0, rowY), cfg)
        keyButton.TextSize = 11
        keyButton.MouseButton1Click:Connect(function()
            keyButton.Text = "Pressione tecla..."
            local conn
            conn = svc.UserInputService.InputBegan:Connect(function(input, processed)
                if processed then return end
                local newKey = input.KeyCode and tostring(input.KeyCode.Name)
                if newKey and newKey ~= "Unknown" then
                    prefs:SetHotkey(action.id, newKey)
                    keyButton.Text = newKey
                    if toast then
                        toast.Show(ctx, action.label .. " agora é " .. newKey, 3)
                    end
                    conn:Disconnect()
                end
            end)
        end)
        table.insert(state.HotkeyRows, { Action = action.id, KeyButton = keyButton })
        rowY = rowY + 28
    end

    local backupBtn = createButton(dashboard, "Backup prefs", UDim2.new(0, 8, 0, 388), cfg)
    local restoreBtn = createButton(dashboard, "Restaurar backup", UDim2.new(0, 156, 0, 388), cfg)
    backupBtn.MouseButton1Click:Connect(function()
        if prefs:Backup() then
            if toast then toast.Show(ctx, "Backup de preferências criado.", 2) end
        else
            if toast then toast.Show(ctx, "Falha ao criar backup.", 2) end
        end
    end)
    restoreBtn.MouseButton1Click:Connect(function()
        if prefs:RestoreBackup() then
            if toast then toast.Show(ctx, "Preferências restauradas do backup.", 3) end
            if stored.ScreenGui and stored.ScreenGui.Parent then
                pcall(function() stored.ScreenGui:Destroy() end)
                state.ClearStored()
                ctx.GUI.Core.Build(ctx)
            end
        else
            if toast then toast.Show(ctx, "Nenhum backup válido encontrado.", 3) end
        end
    end)

    if not stored.DashboardToggleButton then
        local statsToggle = createButton(Main, "STATS", UDim2.new(1, -105, 0, 5), cfg)
        statsToggle.Size = UDim2.new(0, 70, 0, 20)
        statsToggle.TextSize = 10
        statsToggle.BackgroundTransparency = 0.3
        statsToggle.MouseButton1Click:Connect(function()
            dashboard.Visible = not dashboard.Visible
        end)
        stored.DashboardToggleButton = statsToggle
    end
end

return Dashboard

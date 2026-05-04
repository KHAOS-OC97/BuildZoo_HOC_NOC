--[[]]
    SavedPreferences.lua — Persistência e preferências do usuário.
    Salva temas, atalhos e informações de sessão em arquivo local.
    Também cria backup automático antes de sobrescrever e permite restaurar.
]]

local SavedPreferences = {}

local SAVE_FILE   = "HOC_NOC_Prefs.json"
local BACKUP_FILE = "HOC_NOC_Prefs_Backup.json"

local DEFAULTS = {
    Theme = "Default",
    Hotkeys = {
        ToggleGui       = "LeftControl",
        ToggleDashboard = "K",
        ToggleFly       = "F",
        ToggleAutoBuy   = "B",
    },
    LastUsedMode = "default",
}

local prefs = {
    Theme = DEFAULTS.Theme,
    Hotkeys = DEFAULTS.Hotkeys,
    LastUsedMode = DEFAULTS.LastUsedMode,
    Stats = {
        Baseline = 0,
    },
}

local ctx = nil
local HttpService = nil
local inputConnection = nil

local function isFileAvailable()
    return type(readfile) == "function" and type(isfile) == "function" and type(writefile) == "function"
end

local function safeReadFile(path)
    if not isFileAvailable() then return nil end
    local ok, result = pcall(function()
        if isfile(path) then
            return readfile(path)
        end
    end)
    return ok and result or nil
end

local function safeWriteFile(path, content)
    if not isFileAvailable() then return false end
    local ok = pcall(function()
        writefile(path, content)
    end)
    return ok
end

local function loadSavedPreferences()
    if not HttpService then return {} end
    local raw = safeReadFile(SAVE_FILE)
    if not raw or raw == "" then
        return {}
    end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    return ok and type(data) == "table" and data or {}
end

local function persistPreferences()
    if not HttpService then return false end
    local ok = pcall(function()
        writefile(SAVE_FILE, HttpService:JSONEncode(prefs))
    end)
    return ok
end

local function backupCurrentPreferences()
    if not HttpService or not isFileAvailable() then return false end
    local raw = safeReadFile(SAVE_FILE)
    if not raw then return false end
    return safeWriteFile(BACKUP_FILE, raw)
end

local function applyThemeToConfig(cfg)
    if not cfg or type(cfg.ThemePresets) ~= "table" then
        return
    end
    local theme = cfg.ThemePresets[prefs.Theme] or cfg.ThemePresets[DEFAULTS.Theme]
    if type(theme) ~= "table" then
        return
    end
    for key, value in pairs(theme) do
        cfg.Colors[key] = value
    end
end

local function getKeyName(input)
    if not input or not input.KeyCode then
        return nil
    end
    return tostring(input.KeyCode.Name)
end

local function resolveCurrencyValue()
    local player = ctx and ctx.Services and ctx.Services.LocalPlayer
    if not player then
        return 0
    end

    local function parseValue(child)
        if not child then return nil end
        local value = child.Value
        if type(value) == "number" then
            return value
        elseif type(value) == "string" then
            return tonumber(value:gsub("[^%d\.]+", ""))
        end
        return nil
    end

    local bestValue = 0
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        for _, valueNode in ipairs(leaderstats:GetChildren()) do
            local numeric = parseValue(valueNode)
            if numeric and numeric > bestValue then
                bestValue = numeric
            end
        end
    end

    if bestValue > 0 then
        return bestValue
    end

    for _, gui in ipairs(player:GetDescendants()) do
        if gui:IsA("TextLabel") or gui:IsA("TextButton") then
            local numeric = tonumber(tostring(gui.Text):gsub("[^%d]+", ""))
            if numeric and numeric > bestValue then
                bestValue = numeric
            end
        end
    end

    return bestValue
end

function SavedPreferences.Init(context)
    ctx = context or {}
    HttpService = ctx.Services and ctx.Services.HttpService

    local saved = loadSavedPreferences()
    if type(saved.Theme) == "string" then
        prefs.Theme = saved.Theme
    end

    if type(saved.Hotkeys) == "table" then
        for action, key in pairs(DEFAULTS.Hotkeys) do
            prefs.Hotkeys[action] = type(saved.Hotkeys[action]) == "string" and saved.Hotkeys[action] or key
        end
    end

    if type(saved.LastUsedMode) == "string" then
        prefs.LastUsedMode = saved.LastUsedMode
    end

    prefs.Stats.Baseline = resolveCurrencyValue() or 0

    if HttpService then
        backupCurrentPreferences()
        persistPreferences()
    end

    if ctx.Config then
        applyThemeToConfig(ctx.Config)
    end

    if ctx.Services and ctx.Services.UserInputService and not inputConnection then
        inputConnection = ctx.Services.UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            local keyName = getKeyName(input)
            if not keyName then return end

            if keyName == prefs.Hotkeys.ToggleGui then
                local main = ctx.State and ctx.State.Stored and ctx.State.Stored.Main
                if main then
                    main.Visible = not main.Visible
                    if ctx.Toast then
                        ctx.Toast.Show(ctx, "GUI " .. (main.Visible and "ativada" or "ocultada"), 2)
                    end
                end
                return
            end

            if keyName == prefs.Hotkeys.ToggleDashboard then
                local dash = ctx.State and ctx.State.Stored and ctx.State.Stored.DashboardFrame
                if dash then
                    dash.Visible = not dash.Visible
                    if ctx.Toast then
                        ctx.Toast.Show(ctx, "Dashboard " .. (dash.Visible and "aberto" or "fechado"), 2)
                    end
                end
                return
            end

            if keyName == prefs.Hotkeys.ToggleFly then
                if ctx.Fly and type(ctx.Fly.Toggle) == "function" then
                    local enabled = ctx.Fly.Toggle()
                    if ctx.State and ctx.State.Stored and ctx.State.Stored.FlyBtn then
                        ctx.State.Stored.FlyBtn.Text = enabled and "FLY: ON" or "FLY: OFF"
                    end
                    if ctx.Toast then
                        ctx.Toast.Show(ctx, "Fly " .. (enabled and "ativado" or "desativado"), 2)
                    end
                end
                return
            end

            if keyName == prefs.Hotkeys.ToggleAutoBuy then
                _G_AutoBuy = not _G_AutoBuy
                if ctx.State and ctx.State.Stored and ctx.State.Stored.AutoBuyBtn then
                    ctx.State.Stored.AutoBuyBtn.Text = _G_AutoBuy and "AUTO BUY: ON" or "AUTO BUY: OFF"
                end
                if _G_AutoBuy and ctx.AutoBuy and type(ctx.AutoBuy.RunNow) == "function" then
                    task.spawn(function()
                        ctx.AutoBuy.RunNow("Hotkey AutoBuy")
                    end)
                end
                if ctx.Toast then
                    ctx.Toast.Show(ctx, "Auto Buy " .. (_G_AutoBuy and "ativado" or "desativado"), 2)
                end
                return
            end
        end)
    end
end

function SavedPreferences.GetTheme()
    return prefs.Theme
end

function SavedPreferences.GetHotkey(action)
    return prefs.Hotkeys and prefs.Hotkeys[action] or DEFAULTS.Hotkeys[action]
end

function SavedPreferences.GetAllHotkeys()
    return prefs.Hotkeys
end

function SavedPreferences.SetHotkey(action, keyName)
    if type(action) ~= "string" or type(keyName) ~= "string" then
        return false
    end
    prefs.Hotkeys = prefs.Hotkeys or {}
    prefs.Hotkeys[action] = keyName
    if HttpService then
        backupCurrentPreferences()
        persistPreferences()
    end
    return true
end

function SavedPreferences.SetTheme(themeName)
    if type(themeName) ~= "string" then
        return false
    end
    prefs.Theme = themeName
    if HttpService then
        backupCurrentPreferences()
        persistPreferences()
    end
    if ctx.Config then
        applyThemeToConfig(ctx.Config)
    end
    return true
end

function SavedPreferences.ApplyTheme(cfg)
    if not cfg then
        return false
    end
    applyThemeToConfig(cfg)
    return true
end

function SavedPreferences.SetBaseline(value)
    if type(value) ~= "number" then
        return false
    end
    prefs.Stats = prefs.Stats or {}
    prefs.Stats.Baseline = value
    if HttpService then
        persistPreferences()
    end
    return true
end

function SavedPreferences.GetBaseline()
    return prefs.Stats and prefs.Stats.Baseline or 0
end

function SavedPreferences.Backup()
    return backupCurrentPreferences()
end

function SavedPreferences.RestoreBackup()
    if not HttpService then return false end
    local raw = safeReadFile(BACKUP_FILE)
    if not raw then
        return false
    end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not ok or type(data) ~= "table" then
        return false
    end
    prefs = data
    if HttpService then
        persistPreferences()
    end
    if ctx.Config then
        applyThemeToConfig(ctx.Config)
    end
    return true
end

function SavedPreferences.GetCurrentCurrency()
    return resolveCurrencyValue() or 0
end

return SavedPreferences

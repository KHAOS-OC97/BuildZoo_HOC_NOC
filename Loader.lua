--[[
    Loader.lua — Carregador remoto para o Xeno (e demais executores).

    Cole APENAS este bloco no executor e execute.
    Nenhum arquivo local é necessário — tudo é baixado do GitHub.

    IMPORTANTE: o repositório precisa estar público no GitHub.
    Substitua GITHUB_RAW_BASE pela URL raw do seu repo caso mude de branch.
]]

local GITHUB_RAW_BASE =
    "https://raw.githubusercontent.com/KHAOS-OC97/BuildZoo_HOC_NOC/main/"

local CACHE_BUSTER = tostring(os.time())

-- ── Whitelist Security Check ──────────────────────────────────────────────────
do
    local ALLOWED_USERS = { ["KChaos97"] = true, ["CKhaos79"] = true }
    local Players = game:GetService("Players")
    local player  = Players.LocalPlayer
    local name    = player and player.Name or ""

    -- Build notification GUI
    local function showAccessNotification(granted)
        local sg = Instance.new("ScreenGui")
        sg.Name = "HOC_NOC_Access"
        sg.ResetOnSpawn = false
        sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        pcall(function() sg.Parent = game:GetService("CoreGui") end)
        if not sg.Parent then sg.Parent = player:WaitForChild("PlayerGui") end

        local frame = Instance.new("Frame", sg)
        frame.AnchorPoint = Vector2.new(0.5, 0)
        frame.Position = UDim2.new(0.5, 0, 0.05, 0)
        frame.Size = UDim2.new(0, 480, 0, 60)
        frame.BackgroundColor3 = granted and Color3.fromRGB(30, 30, 30) or Color3.fromRGB(40, 10, 10)
        frame.BackgroundTransparency = 0.15
        frame.BorderSizePixel = 0
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

        local stroke = Instance.new("UIStroke", frame)
        stroke.Color = Color3.fromRGB(255, 0, 0)
        stroke.Thickness = 2

        -- RGB cycling border
        local rgbRunning = true
        task.spawn(function()
            local t = 0
            while rgbRunning do
                t = t + task.wait()
                local r = math.floor(math.sin(t * 2) * 127 + 128)
                local g = math.floor(math.sin(t * 2 + 2.094) * 127 + 128)
                local b = math.floor(math.sin(t * 2 + 4.189) * 127 + 128)
                stroke.Color = Color3.fromRGB(r, g, b)
            end
        end)

        local lbl = Instance.new("TextLabel", frame)
        lbl.Size = UDim2.new(1, -40, 1, 0)
        lbl.Position = UDim2.new(0, 20, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 18
        lbl.TextColor3 = granted and Color3.fromRGB(0, 220, 90) or Color3.fromRGB(255, 60, 60)
        lbl.Text = granted
            and ("[HOC NOC] Access GRANTED — Welcome, " .. name)
            or  ("[HOC NOC] Access DENIED — Unauthorized user: " .. name)
        lbl.TextXAlignment = Enum.TextXAlignment.Center

        -- Fade out after a few seconds
        task.delay(granted and 4 or 6, function()
            rgbRunning = false
            pcall(function()
                local tw = game:GetService("TweenService")
                local ti = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                tw:Create(frame, ti, {BackgroundTransparency = 1}):Play()
                tw:Create(lbl,   ti, {TextTransparency = 1}):Play()
                tw:Create(stroke, ti, {Transparency = 1}):Play()
                task.wait(1.1)
                sg:Destroy()
            end)
        end)
    end

    if not ALLOWED_USERS[name] then
        showAccessNotification(false)
        return  -- abort script execution
    end

    showAccessNotification(true)
end

-- Baixa e executa um módulo remoto; devolve a tabela retornada pelo módulo
local function loadModule(relPath)
    local sep = relPath:find("?", 1, true) and "&" or "?"
    local url = GITHUB_RAW_BASE .. relPath .. sep .. "v=" .. CACHE_BUSTER
    local src, compileErr, result

    local ok = pcall(function()
        src = game:HttpGet(url, true)
    end)

    if not ok or not src or src == "" then
        error("[HOC NOC] HttpGet falhou para: " .. url, 2)
    end

    -- Detecta resposta HTML (repo privado / URL errada)
    if src:sub(1, 1) == "<" then
        error("[HOC NOC] GitHub retornou HTML (repo privado ou URL inválida?): " .. url, 2)
    end

    local fn
    fn, compileErr = loadstring(src, "@" .. relPath)
    if not fn then
        error("[HOC NOC] Erro de compilação em '" .. relPath .. "': " .. tostring(compileErr), 2)
    end

    local execOk
    execOk, result = pcall(fn)
    if not execOk then
        error("[HOC NOC] Erro de execução em '" .. relPath .. "': " .. tostring(result), 2)
    end

    return result or {}
end

local function safeInvoke(label, fn)
    if type(fn) ~= "function" then
        warn("[HOC NOC] Etapa ausente: " .. tostring(label))
        return false
    end

    local ok, err = pcall(fn)
    if not ok then
        warn("[HOC NOC] Falha em " .. tostring(label) .. ": " .. tostring(err))
        return false
    end

    return true
end

-- ── Módulos base ──────────────────────────────────────────────────────────────
local ctx = {}
ctx.Config   = loadModule("Modules/Config.lua")
ctx.State    = loadModule("Modules/State.lua")
ctx.Services = loadModule("Modules/Services.lua")

-- ── Módulos de feature ────────────────────────────────────────────────────────
ctx.AntiAFK   = loadModule("Modules/AntiAFK.lua")
ctx.ESP       = loadModule("Modules/ESP.lua")
ctx.Movement  = loadModule("Modules/Movement.lua")
ctx.Fly       = loadModule("Modules/Fly.lua")
ctx.AutoBuy   = loadModule("Modules/AutoBuy.lua")
ctx.BigPetFeed = loadModule("Modules/BigPetFeed.lua")
ctx.ServerHop = loadModule("Modules/ServerHop.lua")
ctx.Teleport  = loadModule("Modules/Teleport.lua")
ctx.Emotes    = loadModule("Modules/Emotes.lua")

-- ── Módulos de GUI ────────────────────────────────────────────────────────────
ctx.GUI = {
    Toggles   = loadModule("Modules/GUI/Toggles.lua"),
    Buttons   = loadModule("Modules/GUI/Buttons.lua"),
    FruitMenu = loadModule("Modules/GUI/FruitMenu.lua"),
    Core      = loadModule("Modules/GUI/Core.lua"),
}

-- ── Inicialização das features ────────────────────────────────────────────────
safeInvoke("AntiAFK.Init", function() ctx.AntiAFK.Init(ctx) end)
safeInvoke("ESP.Init", function() ctx.ESP.Init(ctx) end)
safeInvoke("Movement.Init", function() ctx.Movement.Init(ctx) end)
safeInvoke("Fly.Init", function() ctx.Fly.Init(ctx) end)
safeInvoke("AutoBuy.Init", function() ctx.AutoBuy.Init(ctx) end)
safeInvoke("BigPetFeed.Init", function() ctx.BigPetFeed.Init(ctx) end)
safeInvoke("ServerHop.Init", function() ctx.ServerHop.Init(ctx) end)
safeInvoke("Teleport.Init", function() ctx.Teleport.Init(ctx) end)
safeInvoke("Emotes.Init",   function() ctx.Emotes.Init(ctx) end)

-- ── GUI ───────────────────────────────────────────────────────────────────────
safeInvoke("GUI.Core.Build", function() ctx.GUI.Core.Build(ctx) end)

-- ── Monitor: reconstrói GUI se removida + Anti-AFK periódico ─────────────────
task.spawn(function()
    while _G_Running do
        local stored = ctx.State.Stored
        if not (stored.ScreenGui and stored.ScreenGui.Parent) then
            safeInvoke("GUI.Core.Build (monitor)", function() ctx.GUI.Core.Build(ctx) end)
        end
        safeInvoke("AntiAFK.Ping", function() ctx.AntiAFK.Ping() end)
        task.wait(ctx.Config.ANTI_AFK_INTERVAL)
    end
end)

-- ── CharacterAdded ────────────────────────────────────────────────────────────
local LocalPlayer = ctx.Services.LocalPlayer
LocalPlayer.CharacterAdded:Connect(function(char)
    safeInvoke("Movement.ApplyToCharacter(CharacterAdded)", function()
        ctx.Movement.ApplyToCharacter(char)
    end)
end)
if LocalPlayer.Character then
    safeInvoke("Movement.ApplyToCharacter(Current)", function()
        ctx.Movement.ApplyToCharacter(LocalPlayer.Character)
    end)
end

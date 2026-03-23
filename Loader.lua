--[[
    Loader.lua — Carregador remoto para o Xeno (e demais executores).

    Cole APENAS este bloco no executor e execute.
    Nenhum arquivo local é necessário — tudo é baixado do GitHub.

    IMPORTANTE: o repositório precisa estar público no GitHub.
    Substitua GITHUB_RAW_BASE pela URL raw do seu repo caso mude de branch.
]]

local GITHUB_RAW_BASE =
    "https://raw.githubusercontent.com/KHAOS-OC97/BuildZoo_HOC_NOC/main/"

-- Baixa e executa um módulo remoto; devolve a tabela retornada pelo módulo
local function loadModule(relPath)
    local url = GITHUB_RAW_BASE .. relPath
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
ctx.AutoBuy   = loadModule("Modules/AutoBuy.lua")
ctx.BigPetFeed = loadModule("Modules/BigPetFeed.lua")
ctx.ServerHop = loadModule("Modules/ServerHop.lua")
ctx.Teleport  = loadModule("Modules/Teleport.lua")

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
safeInvoke("AutoBuy.Init", function() ctx.AutoBuy.Init(ctx) end)
safeInvoke("BigPetFeed.Init", function() ctx.BigPetFeed.Init(ctx) end)
safeInvoke("ServerHop.Init", function() ctx.ServerHop.Init(ctx) end)
safeInvoke("Teleport.Init", function() ctx.Teleport.Init(ctx) end)

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

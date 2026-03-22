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
ctx.AntiAFK.Init(ctx)
ctx.ESP.Init(ctx)
ctx.Movement.Init(ctx)
ctx.AutoBuy.Init(ctx)
ctx.ServerHop.Init(ctx)
ctx.Teleport.Init(ctx)

-- ── GUI ───────────────────────────────────────────────────────────────────────
pcall(function() ctx.GUI.Core.Build(ctx) end)

-- ── Monitor: reconstrói GUI se removida + Anti-AFK periódico ─────────────────
task.spawn(function()
    while _G_Running do
        local stored = ctx.State.Stored
        if not (stored.ScreenGui and stored.ScreenGui.Parent) then
            pcall(function() ctx.GUI.Core.Build(ctx) end)
        end
        ctx.AntiAFK.Ping()
        task.wait(ctx.Config.ANTI_AFK_INTERVAL)
    end
end)

-- ── CharacterAdded ────────────────────────────────────────────────────────────
local LocalPlayer = ctx.Services.LocalPlayer
LocalPlayer.CharacterAdded:Connect(function(char)
    ctx.Movement.ApplyToCharacter(char)
end)
if LocalPlayer.Character then
    pcall(function() ctx.Movement.ApplyToCharacter(LocalPlayer.Character) end)
end

--[[
    HOC NOC Zoo — v1.0.3 | Modular Edition
    Main.lua — Ponto de entrada. Carrega todos os módulos, inicializa as
               features, constrói a GUI e mantém o loop monitor.

    ─ Requisitos de executor ────────────────────────────────────────────────────
    • O executor deve suportar readfile() para carregar os arquivos locais.
    • Estrutura de pastas esperada (relativa ao script loader do executor):

        HOC_NOC_Zoo/
        ├── Main.lua
        └── Modules/
            ├── Config.lua
            ├── State.lua
            ├── Services.lua
            ├── AntiAFK.lua
            ├── ESP.lua
            ├── Movement.lua
            ├── AutoBuy.lua
            ├── ServerHop.lua
            ├── Teleport.lua
            └── GUI/
                ├── Core.lua
                ├── Toggles.lua
                ├── Buttons.lua
                └── FruitMenu.lua

    ─ Persistência após teleporte cross-place ───────────────────────────────────
    Use queue_on_teleport do executor para recarregar após teleportes:
        queue_on_teleport([[loadstring(readfile("HOC_NOC_Zoo/Main.lua"))()]])
    ou, se o script estiver hospedado online:
        queue_on_teleport([[loadstring(game:HttpGet("SUA_URL_RAW"))()]])
]]

-- ── Loader de módulos ─────────────────────────────────────────────────────────
local BASE = "HOC_NOC_Zoo/"

local function loadModule(relPath)
    local ok, result = pcall(function()
        return loadstring(readfile(BASE .. relPath))()
    end)
    if not ok then
        warn("[HOC NOC] Erro ao carregar módulo '" .. relPath .. "': " .. tostring(result))
        return {}
    end
    return result
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

-- ── Módulos base (ordem importa) ──────────────────────────────────────────────
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
    Toggles  = loadModule("Modules/GUI/Toggles.lua"),
    Buttons  = loadModule("Modules/GUI/Buttons.lua"),
    FruitMenu = loadModule("Modules/GUI/FruitMenu.lua"),
    Core     = loadModule("Modules/GUI/Core.lua"),
}

-- ── Inicialização das features (conecta eventos, inicia loops) ────────────────
safeInvoke("AntiAFK.Init", function() ctx.AntiAFK.Init(ctx) end)
safeInvoke("ESP.Init", function() ctx.ESP.Init(ctx) end)
safeInvoke("Movement.Init", function() ctx.Movement.Init(ctx) end)
safeInvoke("AutoBuy.Init", function() ctx.AutoBuy.Init(ctx) end)
safeInvoke("ServerHop.Init", function() ctx.ServerHop.Init(ctx) end)
safeInvoke("Teleport.Init", function() ctx.Teleport.Init(ctx) end)

-- ── Construção inicial da GUI ─────────────────────────────────────────────────
safeInvoke("GUI.Core.Build", function() ctx.GUI.Core.Build(ctx) end)

-- ── Loop monitor ──────────────────────────────────────────────────────────────
-- Reconstrói a GUI caso seja removida externamente e envia pings Anti-AFK
-- periódicos enquanto _G_Running for true.
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

-- ── Eventos de personagem ─────────────────────────────────────────────────────
local LocalPlayer = ctx.Services.LocalPlayer

LocalPlayer.CharacterAdded:Connect(function(char)
    safeInvoke("Movement.ApplyToCharacter(CharacterAdded)", function()
        ctx.Movement.ApplyToCharacter(char)
    end)
end)

-- Aplica ao personagem já existente (caso o script rode após o spawn)
if LocalPlayer.Character then
    safeInvoke("Movement.ApplyToCharacter(Current)", function()
        ctx.Movement.ApplyToCharacter(LocalPlayer.Character)
    end)
end

-- Fim de Main.lua

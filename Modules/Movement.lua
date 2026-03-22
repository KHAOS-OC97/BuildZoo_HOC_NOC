--[[
    Movement.lua — Controla WalkSpeed e Pulo Infinito.

    Init(ctx)             conecta Stepped e JumpRequest uma única vez.
    CycleSpeed(presets)   avança para o próximo preset de velocidade.
    ApplyToCharacter(char) aplica _G_WalkSpeed ao humanoid (usado no respawn).
]]

local Movement = {}
local _svc
local _runtime

local function applyWalkSpeed(hum)
    if not hum then return end
    if not _G_Running then return end
    pcall(function() hum.WalkSpeed = _G_WalkSpeed end)
end

-- Conecta o GetPropertyChangedSignal do Humanoid para re-aplicar o WalkSpeed
-- sempre que o jogo tentar resetar (anti-cheat do servidor)
local function hookHumanoid(hum)
    if not hum then return end
    applyWalkSpeed(hum)

    if _runtime.HumConns[hum] then
        pcall(function() _runtime.HumConns[hum]:Disconnect() end)
        _runtime.HumConns[hum] = nil
    end

    _runtime.HumConns[hum] = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if not _G_Running then return end
        if hum.WalkSpeed ~= _G_WalkSpeed then
            applyWalkSpeed(hum)
        end
    end)
end

local function hookCharacter(char)
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hookHumanoid(hum)
    else
        -- Aguarda o Humanoid aparecer (primeiros frames do spawn)
        char.ChildAdded:Connect(function(child)
            if child:IsA("Humanoid") then hookHumanoid(child) end
        end)
    end
end

function Movement.Init(ctx)
    _svc = ctx.Services

    _G.__HOC_RUNTIME = _G.__HOC_RUNTIME or {}
    _G.__HOC_RUNTIME.Movement = _G.__HOC_RUNTIME.Movement or {
        SteppedConn = nil,
        JumpConn = nil,
        CharConn = nil,
        HumConns = {},
    }
    _runtime = _G.__HOC_RUNTIME.Movement

    if _runtime.SteppedConn then pcall(function() _runtime.SteppedConn:Disconnect() end) end
    if _runtime.JumpConn then pcall(function() _runtime.JumpConn:Disconnect() end) end
    if _runtime.CharConn then pcall(function() _runtime.CharConn:Disconnect() end) end
    for hum, conn in pairs(_runtime.HumConns) do
        pcall(function() conn:Disconnect() end)
        _runtime.HumConns[hum] = nil
    end

    -- Aplica ao personagem atual
    hookCharacter(_svc.LocalPlayer.Character)

    -- Aplicação contínua em frame (comportamento legado estável)
    _runtime.SteppedConn = _svc.RunService.Stepped:Connect(function()
        if not _G_Running then return end
        local char = _svc.LocalPlayer and _svc.LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            applyWalkSpeed(hum)
        end
    end)

    -- Aplica em cada respawn
    _runtime.CharConn = _svc.LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait()   -- aguarda 1 frame para o Humanoid existir
        hookCharacter(char)
    end)

    -- Pulo infinito
    _runtime.JumpConn = _svc.UserInputService.JumpRequest:Connect(function()
        if not _G_InfJump then return end
        local char = _svc.LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
        end
    end)
end

-- Avança para o próximo valor no ciclo de velocidades, aplica imediatamente e retorna
function Movement.CycleSpeed(presets)
    local nextIdx = 1
    for i, v in ipairs(presets) do
        if v == _G_WalkSpeed then
            nextIdx = (i % #presets) + 1
            break
        end
    end
    _G_WalkSpeed = presets[nextIdx]
    -- Aplica imediatamente sem esperar o próximo Stepped
    if _svc then
        local char = _svc.LocalPlayer and _svc.LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                applyWalkSpeed(hum)
            end
        end
    end
    return _G_WalkSpeed
end

-- Aplica WalkSpeed ao personagem (útil no CharacterAdded)
function Movement.ApplyToCharacter(char)
    pcall(function()
        local hum = char:WaitForChild("Humanoid", 5)
        if hum then
            applyWalkSpeed(hum)
            hookHumanoid(hum)
        end
    end)
end

return Movement

--[[
    Movement.lua — Controla WalkSpeed e Pulo Infinito.

    Init(ctx)             conecta Stepped e JumpRequest uma única vez.
    CycleSpeed(presets)   avança para o próximo preset de velocidade.
    ApplyToCharacter(char) aplica _G_WalkSpeed ao humanoid (usado no respawn).
]]

local Movement = {}
local _svc

function Movement.Init(ctx)
    _svc = ctx.Services

    -- Mantém o WalkSpeed aplicado a cada frame de física
    _svc.RunService.Stepped:Connect(function()
        if not _G_Running then return end
        local char = _svc.LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            pcall(function() hum.WalkSpeed = _G_WalkSpeed end)
        end
    end)

    -- Pulo infinito
    _svc.UserInputService.JumpRequest:Connect(function()
        if not _G_InfJump then return end
        local char = _svc.LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
        end
    end)
end

-- Avança para o próximo valor no ciclo de velocidades e retorna o novo valor
function Movement.CycleSpeed(presets)
    local nextIdx = 1
    for i, v in ipairs(presets) do
        if v == _G_WalkSpeed then
            nextIdx = (i % #presets) + 1
            break
        end
    end
    _G_WalkSpeed = presets[nextIdx]
    return _G_WalkSpeed
end

-- Aplica WalkSpeed ao personagem (útil no CharacterAdded)
function Movement.ApplyToCharacter(char)
    pcall(function()
        local hum = char:WaitForChild("Humanoid", 5)
        if hum then hum.WalkSpeed = _G_WalkSpeed end
    end)
end

return Movement

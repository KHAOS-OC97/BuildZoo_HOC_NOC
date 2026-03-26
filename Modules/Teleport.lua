--[[
    Teleport.lua — Teleporte até um aliado (TARGET_USERS).

    Init(ctx) armazena dependências.
    ToAlly()  itera sobre os jogadores e teleporta o LocalPlayer para o aliado.
]]

local Teleport = {}
local _svc, _cfg

function Teleport.Init(ctx)
    _svc = ctx.Services
    _cfg = ctx.Config
end

function Teleport.ToPosition(position)
    local lChar = _svc.LocalPlayer.Character
    if not lChar then return false end

    local root = lChar:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    local target = typeof(position) == "Vector3" and position or nil
    if not target then return false end

    pcall(function()
        lChar:PivotTo(CFrame.new(target))
    end)

    return true
end

function Teleport.ToNamedPoint(name)
    local points = _cfg and _cfg.TELEPORT_POINTS or nil
    local target = points and points[name] or nil
    if not target then
        print("[HOC NOC] PONTO NÃO CONFIGURADO: " .. tostring(name))
        return false
    end

    return Teleport.ToPosition(target)
end

local followState = {
    Active = false,
    Target = nil,
    Connection = nil,
}

local function findTargetAlly()
    for _, p in pairs(_svc.Players:GetPlayers()) do
        if p ~= _svc.LocalPlayer and table.find(_cfg.TARGET_USERS, p.Name) then
            local pChar = p.Character
            if pChar and pChar:FindFirstChild("HumanoidRootPart") then
                return p
            end
        end
    end
    return nil
end

function Teleport.ToAlly()
    local ally = findTargetAlly()
    if not ally then
        warn("[HOC NOC] ALIADO NÃO ENCONTRADO")
        return false
    end

    local pChar = ally.Character
    local lChar = _svc.LocalPlayer.Character
    if not pChar or not pChar:FindFirstChild("HumanoidRootPart")
    or not lChar or not lChar:FindFirstChild("HumanoidRootPart") then
        warn("[HOC NOC] ALIADO ou jogador local sem HumanoidRootPart")
        return false
    end

    pcall(function()
        lChar.HumanoidRootPart.CFrame = pChar.HumanoidRootPart.CFrame * CFrame.new(0, 2, -3)
    end)

    return true
end

function Teleport.FollowAllyStart()
    if followState.Active then
        return true
    end

    local ally = findTargetAlly()
    if not ally then
        warn("[HOC NOC] FOLLOW: aliado não encontrado")
        return false
    end

    followState.Target = ally
    followState.Active = true

    followState.Connection = _svc.RunService.Heartbeat:Connect(function()
        if not followState.Active then
            return
        end

        if not followState.Target or not followState.Target.Character then
            Teleport.FollowAllyStop()
            return
        end

        local targetHRP = followState.Target.Character:FindFirstChild("HumanoidRootPart")
        local localChar = _svc.LocalPlayer.Character
        local localHRP = localChar and localChar:FindFirstChild("HumanoidRootPart")

        if not targetHRP or not localHRP then
            Teleport.FollowAllyStop()
            return
        end

        local followCFrame = targetHRP.CFrame * CFrame.new(0, 0, 4)
        pcall(function()
            localHRP.CFrame = followCFrame
        end)
    end)

    return true
end

function Teleport.FollowAllyStop()
    followState.Active = false
    followState.Target = nil
    if followState.Connection then
        followState.Connection:Disconnect()
        followState.Connection = nil
    end
    return false
end

function Teleport.FollowAllyToggle()
    if followState.Active then
        return Teleport.FollowAllyStop()
    else
        return Teleport.FollowAllyStart()
    end
end

return Teleport

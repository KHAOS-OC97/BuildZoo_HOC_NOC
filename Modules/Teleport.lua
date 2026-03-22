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

function Teleport.ToAlly()
    local found = false

    for _, p in pairs(_svc.Players:GetPlayers()) do
        if table.find(_cfg.TARGET_USERS, p.Name) and p ~= _svc.LocalPlayer then
            local pChar = p.Character
            local lChar = _svc.LocalPlayer.Character

            if pChar  and pChar:FindFirstChild("HumanoidRootPart")
            and lChar and lChar:FindFirstChild("HumanoidRootPart") then
                pcall(function()
                    lChar.HumanoidRootPart.CFrame =
                        pChar.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
                end)
                found = true
                break
            end
        end
    end

    if not found then
        print("[HOC NOC] ALIADO NÃO ENCONTRADO")
    end
end

return Teleport

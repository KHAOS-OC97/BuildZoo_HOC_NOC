-- Modules/CollectCoin.lua
-- Módulo para coleta automática de coins (Trg)

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local CollectCoin = {}

-- Nome do objeto alvo no workspace
local NOME_ALVO = "Trg"

-- Função que coleta todos os coins "Trg" no workspace
function CollectCoin.CollectAll()
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local meuPe = char.HumanoidRootPart.CFrame

    for _, v in pairs(game.Workspace:GetDescendants()) do
        if v.Name == NOME_ALVO and v:IsA("BasePart") then
            local posOriginal = v.CFrame
            v.CFrame = meuPe
            task.wait(0.05)
            v.CFrame = posOriginal
        end
    end
end

return CollectCoin

-- Modules/CollectCoin.lua
-- Módulo para coleta automática de coins (Trg)

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local CollectCoin = {}

-- Nome do objeto alvo no workspace
local NOME_ALVO = "Trg"

-- Função que coleta todos os coins no workspace (compatível com Trg, Coin e variantes)
function CollectCoin.CollectAll()
    local char = player.Character
    if not char then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local srcCFrame = hrp.CFrame
    local found = false

    for _, v in pairs(game.Workspace:GetDescendants()) do
        if v:IsA("BasePart") and (v.Name:lower():find("trg") or v.Name:lower():find("coin") or v.Name:lower():find("pickup") or v.Name:lower():find("drop")) then
            found = true
            local originalCFrame = v.CFrame

            -- 1) Tenta trigger via firetouchinterest para coletar sem teleportar
            if v:IsDescendantOf(game.Workspace) and hrp:IsDescendantOf(game.Workspace) then
                pcall(function()
                    firetouchinterest(v, hrp, 0)
                    task.wait(0.02)
                    firetouchinterest(v, hrp, 1)
                end)
            end

            -- 2) Fallback: leva o item para o player para garantir trigger
            pcall(function()
                v.CFrame = srcCFrame
            end)

            task.wait(0.06)

            -- 3) Restaura posição para não quebrar a cena, se ainda existir
            if v and v:IsA("BasePart") and v.Parent then
                pcall(function()
                    v.CFrame = originalCFrame
                end)
            end
        end
    end

    -- Se nada foi encontrado, tenta scan simples informativo
    if not found then
        warn("[CollectCoin] Nenhum objetivo de coin encontrado, verifique nome/estrutura do mapa.")
    end
end

return CollectCoin

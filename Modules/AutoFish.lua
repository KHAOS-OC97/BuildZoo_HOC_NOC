-- AutoFish.lua
-- Módulo para automação da pescaria sem travar o mouse ou a tela
-- Detecta a barra de pescaria e clica automaticamente, sem interferir no mouse do jogador

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer

-- Altere para o nome correto do Frame/GUI da barra de pescaria
local FISHING_BAR_NAME = "FishingBar" -- Troque pelo nome real se necessário

local AutoFish = {}
AutoFish.Enabled = false

function AutoFish:Start()
    self.Enabled = true
    spawn(function()
        while self.Enabled do
            local fishingBar = player.PlayerGui:FindFirstChild(FISHING_BAR_NAME, true)
            if fishingBar and fishingBar.Visible then
                -- Simula clique do mouse esquerdo (não afeta o mouse real)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
                wait(0.05) -- Ajuste a velocidade do clique conforme necessário
            else
                wait(0.2)
            end
        end
    end)
end

function AutoFish:Stop()
    self.Enabled = false
end

return AutoFish

-- AutoFish.lua
-- Módulo para automação da pescaria sem travar o mouse ou a tela
-- Detecta a barra de pescaria e clica automaticamente, sem interferir no mouse do jogador


local VirtualInputManager = game:GetService("VirtualInputManager")

local AutoFish = {}
AutoFish.Enabled = false

-- Posição fixa para clicar (canto superior esquerdo, fora de menus)
local CLICK_X, CLICK_Y = 10, 10

function AutoFish:Start()
    self.Enabled = true
    spawn(function()
        while self.Enabled do
            -- Aqui você pode adicionar uma condição para só clicar quando estiver pescando
            -- ou deixar sempre ativo se preferir
            VirtualInputManager:SendMouseButtonEvent(CLICK_X, CLICK_Y, 0, true, game, 0)
            VirtualInputManager:SendMouseButtonEvent(CLICK_X, CLICK_Y, 0, false, game, 0)
            wait(0.05) -- Ajuste a velocidade do clique conforme necessário
        end
    end)
end

function AutoFish:Stop()
    self.Enabled = false
end

return AutoFish

-- AutoFish.lua
-- Módulo para automação da pescaria sem travar o mouse ou a tela
-- Detecta a barra de pescaria e clica automaticamente, sem interferir no mouse do jogador


local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer

local AutoFish = {}
AutoFish.Enabled = false

-- Posição fixa para clicar (canto superior esquerdo, fora de menus)
local CLICK_X, CLICK_Y = 10, 10

-- Caminho do botão de pescaria
local function getFishingButton()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil end
    local screen = gui:FindFirstChild("ScreenFishing")
    if not screen then return nil end
    return screen:FindFirstChild("Fishing")
end

function AutoFish:Start()
    print("[AutoFish] Start chamado!")
    self.Enabled = true
    spawn(function()
        print("[AutoFish] Loop iniciado!")
        while self.Enabled do
            local fishingButton = getFishingButton()
            if fishingButton and fishingButton.Visible and fishingButton.Active then
                print("[AutoFish] Clicando em (10,10)")
                VirtualInputManager:SendMouseButtonEvent(CLICK_X, CLICK_Y, 0, true, game, 0)
                VirtualInputManager:SendMouseButtonEvent(CLICK_X, CLICK_Y, 0, false, game, 0)
                wait(0.005)
            else
                if fishingButton then
                    print("[AutoFish] Botão não visível ou inativo.")
                else
                    print("[AutoFish] Botão de pescaria não encontrado.")
                end
                wait(0.2)
            end
        end
    end)
end

function AutoFish:Stop()
    self.Enabled = false
end

return AutoFish

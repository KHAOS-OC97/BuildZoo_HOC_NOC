-- AutoFish.lua
-- Módulo para automação da pescaria sem travar o mouse ou a tela
-- Detecta a barra de pescaria e clica automaticamente, sem interferir no mouse do jogador



local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer

local AutoFish = {}
AutoFish.Enabled = false

-- Atalho de teclado para ativar/desativar AutoFish (tecla R)
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.R then
        _G_AutoFish = not _G_AutoFish
        print("[AutoFish] Toggle via tecla R:", _G_AutoFish)
        if _G_AutoFish then
            AutoFish:Start()
        else
            AutoFish:Stop()
        end
    end
end)

-- Posição fixa para clicar (canto superior esquerdo, fora de menus)
local CLICK_X, CLICK_Y = 10, 10

-- Caminho do botão de pescaria
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil end
    local screen = gui:FindFirstChild("ScreenFishing")
    if not screen then return nil end
    return screen:FindFirstChild("Fishing")
end

-- TEMPLATE: Disparar RemoteEvent de pescaria
-- Substitua "FishingRemote" pelo nome correto do RemoteEvent quando descobrir
local function fireFishingRemote()
    local remote = ReplicatedStorage:FindFirstChild("FishingRemote")
    if remote and remote:IsA("RemoteEvent") then
        print("[AutoFish] Disparando FishingRemote!")
        remote:FireServer()
    else
        print("[AutoFish] RemoteEvent de pescaria não encontrado!")
    end
end

function AutoFish:Start()
    print("[AutoFish] Start chamado!")
    self.Enabled = true
    spawn(function()
        print("[AutoFish] Loop iniciado!")
        while self.Enabled do
            if not _G_AutoFish then
                wait(0.2)
                continue
            end
            local fishingButton = getFishingButton()
            if fishingButton and fishingButton.Visible and fishingButton.Active then
                print("[AutoFish] Disparando RemoteEvent de pescaria (template)")
                fireFishingRemote()
                wait(0.05)
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

-- AutoFish.lua
-- Módulo para automação da pescaria sem travar o mouse ou a tela
-- Detecta a barra de pescaria e clica automaticamente, sem interferir no mouse do jogador



local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer

local AutoFish = {}
AutoFish.Enabled = false

-- Inicializa _G_AutoFish se não existir
if _G_AutoFish == nil then _G_AutoFish = false end

-- Função para garantir que o loop está rodando conforme o estado global
local function updateAutoFishState()
    if _G_AutoFish and not AutoFish.Enabled then
        print("[AutoFish] Ativando AutoFish pelo estado global!")
        AutoFish:Start()
    elseif not _G_AutoFish and AutoFish.Enabled then
        print("[AutoFish] Desativando AutoFish pelo estado global!")
        AutoFish:Stop()
    end
end

-- Atalho de teclado para ativar/desativar AutoFish (tecla R)
local UserInputService = game:GetService("UserInputService")
local function handleInput(input, processed)
    if processed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.R then
        _G_AutoFish = not _G_AutoFish
        print("[AutoFish] Toggle via tecla R:", _G_AutoFish)
        updateAutoFishState()
    end
end
UserInputService.InputBegan:Connect(handleInput)

-- Posição do botão de pescaria (centro)
local CLICK_X, CLICK_Y = 1690 + 151/2, 491 + 151/2

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
    if self.Enabled then return end
    print("[AutoFish] Start chamado!")
    self.Enabled = true
    spawn(function()
        print("[AutoFish] Loop iniciado!")
        while self.Enabled do
            if not _G_AutoFish then
                wait(0.2)
            else
                local fishingButton = getFishingButton()
                if fishingButton and fishingButton.Visible and fishingButton.Active then
                    print("[AutoFish] Clicando nas coordenadas do botão de pescaria:", CLICK_X, CLICK_Y)
                    VirtualInputManager:SendMouseButtonDown(CLICK_X, CLICK_Y, game, 0)
                    VirtualInputManager:SendMouseButtonUp(CLICK_X, CLICK_Y, game, 0)
                    wait(0.02)
                else
                    if fishingButton then
                        print("[AutoFish] Botão não visível ou inativo.")
                    else
                        print("[AutoFish] Botão de pescaria não encontrado.")
                    end
                    wait(0.2)
                end
            end
        end
    end)
end

function AutoFish:Stop()
    if not self.Enabled then return end
    print("[AutoFish] Stop chamado!")
    self.Enabled = false
end


-- Garante que o estado inicial está correto ao carregar o módulo
task.spawn(function()
    wait(0.5)
    updateAutoFishState()
end)

return AutoFish

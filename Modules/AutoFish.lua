-- AutoFish.lua
-- Módulo para automação da pescaria sem travar o mouse ou a tela
-- Detecta a barra de pescaria e clica automaticamente, sem interferir no mouse do jogador



local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local StarterGui = game:GetService("StarterGui")
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


local UserInputService = game:GetService("UserInputService")

local function notifyAutoFish(isEnabled)
    local statusText = isEnabled and "enabled" or "disabled"
    local message = "AutoFish is now " .. statusText .. "."

    local ok = pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "AutoFish",
            Text = message,
            Duration = 2,
        })
    end)

    if not ok then
        print("[AutoFish] " .. message)
    end
end

    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return end
    local gui = playerGui:FindFirstChild("HOC_NOC_ELITE_V6_4")
    if not gui then return end
    local main = gui:FindFirstChild("Main")
    if not main then return end
    for _, frame in ipairs(main:GetChildren()) do
        if frame:IsA("Frame") and frame:FindFirstChild("TextLabel") and frame.TextLabel.Text == "AUTOFISH" then
            local switch = frame:FindFirstChildWhichIsA("TextButton")
            if switch then
                -- Checa o estado visual do toggle
                local isOn = (switch.BackgroundColor3.g > 0.3)
                if isOn ~= state then
                    switch:Activate()
                end
            end
        end
    end
end

local function handleInput(input, processed)
    if processed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.R then
        _G_AutoFish = not _G_AutoFish
        notifyAutoFish(_G_AutoFish)
        setGuiToggleAutoFish(_G_AutoFish)
        updateAutoFishState()
    end
end
UserInputService.InputBegan:Connect(handleInput)

-- Posição do botão de pescaria (centro)
-- Clique em qualquer lugar da tela (exemplo: 100,100)
local CLICK_X, CLICK_Y = 100, 100

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
                print("[AutoFish] Tentando clicar na tela em:", CLICK_X, CLICK_Y)
                local ok1, err1 = pcall(function()
                    VirtualInputManager:SendMouseButtonDown(CLICK_X, CLICK_Y, game, 0)
                end)
                local ok2, err2 = pcall(function()
                    VirtualInputManager:SendMouseButtonUp(CLICK_X, CLICK_Y, game, 0)
                end)
                if not ok1 or not ok2 then
                    print("[AutoFish] Erro ao clicar:", err1 or err2)
                end
                wait(0.005)
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

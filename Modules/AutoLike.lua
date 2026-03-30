-- Modules/AutoLike.lua
-- Módulo: AutoLike
-- Curtidas automáticas entre Kchaos97 e CKhaos79

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local ALLOWED = {
    Kchaos97 = "CKhaos79",
    CKhaos79 = "Kchaos97"
}

local function getLikeButton()
    -- Caminho identificado pelo usuário
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    if not gui then return nil end
    local frame = gui:FindFirstChild("ScreenPlayerInfo")
    if not frame then return nil end
    local likeBtn = frame:FindFirstChild("Frame")
    if not likeBtn then return nil end
    return likeBtn:FindFirstChild("LikeBtn")
end

local function canLike()
    local target = ALLOWED[LocalPlayer.Name]
    if not target then return false end
    -- Só curte se o outro permitido estiver na partida
    return Players:FindFirstChild(target) ~= nil
end

local function tryLike()
    if not canLike() then return end
    local btn = getLikeButton()
    if btn and btn:IsA("ImageButton") then
        -- Simula clique
        pcall(function()
            btn.MouseButton1Click:Fire()
        end)
    end
end

local function Init()
    -- Tenta curtir ao entrar e periodicamente
    tryLike()
    Players.PlayerAdded:Connect(function()
        task.wait(2)
        tryLike()
    end)
    -- Tenta curtir a cada 30 segundos
    task.spawn(function()
        while true do
            task.wait(30)
            tryLike()
        end
    end)
end

return {
    Init = Init
}
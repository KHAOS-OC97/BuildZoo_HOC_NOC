-- Modules/AutoLike.lua
-- Módulo: AutoLike
-- Curtidas automáticas entre Kchaos97 e CKhaos79

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local ALLOWED = {
    Kchaos97 = "CKhaos79",
    CKhaos79 = "Kchaos97"
}

local function waitForLikeButton(timeout)
    timeout = timeout or 10
    local gui = LocalPlayer:WaitForChild("PlayerGui", timeout)
    if not gui then return nil end
    local frame = gui:WaitForChild("ScreenPlayerInfo", timeout)
    if not frame then return nil end
    local sub = frame:WaitForChild("Frame", timeout)
    if not sub then return nil end
    return sub:WaitForChild("LikeBtn", timeout)
end

local function canLike()
    local target = ALLOWED[LocalPlayer.Name]
    if not target then return false end
    -- Só curte se o outro permitido estiver na partida
    return Players:FindFirstChild(target) ~= nil
end

local function tryLike()
    if not canLike() then
        print("[AutoLike] Não permitido ou alvo ausente.")
        return
    end
    local btn = waitForLikeButton(10)
    if btn and btn:IsA("ImageButton") then
        print("[AutoLike] Botão LikeBtn encontrado, tentando acionar eventos...")
        pcall(function()
            btn.MouseButton1Click:Fire()
            btn.MouseButton1Down:Fire()
            btn.MouseButton1Up:Fire()
        end)
    else
        print("[AutoLike] Botão LikeBtn não encontrado!")
    end
end

local function Init()
    print("[AutoLike] Inicializando...")
    -- Tenta curtir ao entrar e periodicamente
    task.spawn(function()
        task.wait(3)
        tryLike()
    end)
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
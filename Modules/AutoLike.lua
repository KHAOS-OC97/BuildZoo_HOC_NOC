-- Modules/AutoLike.lua
-- Módulo: AutoLike
-- Curtidas automáticas entre Kchaos97 e CKhaos79

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local ALLOWED = {
    kchaos97 = "ckhaos79",
    ckhaos79 = "kchaos97"
}

local function normalizeName(value)
    return string.lower(tostring(value or ""))
end

local function findPlayerByLowerName(lowerName)
    for _, player in ipairs(Players:GetPlayers()) do
        if normalizeName(player.Name) == lowerName then
            return player
        end
    end
    return nil
end

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
    local target = ALLOWED[normalizeName(LocalPlayer.Name)]
    if not target then return false end
    -- Só curte se o outro permitido estiver na partida
    return findPlayerByLowerName(target) ~= nil
end

local function tryLike()
    if not canLike() then return end
    local btn = waitForLikeButton(10)
    if btn and btn:IsA("ImageButton") then
        pcall(function()
            btn.MouseButton1Click:Fire()
            btn.MouseButton1Down:Fire()
            btn.MouseButton1Up:Fire()
        end)
    end
end

local function Init()
    task.spawn(function()
        task.wait(3)
        tryLike()
    end)
    Players.PlayerAdded:Connect(function()
        task.wait(2)
        tryLike()
    end)
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
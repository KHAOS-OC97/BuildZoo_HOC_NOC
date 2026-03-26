--[[
    ServerHop.lua — Troca de servidor (extração).

    Init(ctx) armazena dependências.
    Hop()     busca um servidor público disponível e teleporta o jogador.
]]

local ServerHop = {}
local _svc

function ServerHop.Init(ctx)
    _svc = ctx.Services
end

function ServerHop.Hop()
    pcall(function()
        local url = "https://games.roblox.com/v1/games/"
                 .. game.PlaceId
                 .. "/servers/Public?sortOrder=Desc&limit=100"

        local raw = game:HttpGet(url)
        if not raw or raw == "" then return end

        local data = _svc.HttpService:JSONDecode(raw)
        if not (data and data.data) then return end

        for _, v in pairs(data.data) do
            if v.playing < v.maxPlayers and v.id ~= game.JobId then
                _svc.TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id)
                break
            end
        end
    end)
end

function ServerHop.HopToFriend(friendName)
    if type(friendName) ~= "string" or friendName == "" then
        warn("[HOC NOC] HopToFriend: nome de amigo inválido")
        return false
    end

    local players = _svc.Players
    local currentJob = game.JobId
    local placeId = game.PlaceId

    -- se amigo estiver no server atual, nada a fazer
    local friendInServer = players:FindFirstChild(friendName)
    if friendInServer then
        warn("[HOC NOC] HopToFriend: amigo já no mesmo servidor")
        return true
    end

    local userId
    local success, err = pcall(function()
        userId = players:GetUserIdFromNameAsync(friendName)
    end)

    if not success or not userId then
        warn("[HOC NOC] HopToFriend: não foi possível recuperar userId (" .. tostring(friendName) .. ")")
        return false
    end

    -- GetPlayerPlaceInstanceAsync pode retornar JobId do servidor onde está o amigo
    local friendInstance
    if _svc.TeleportService.GetPlayerPlaceInstanceAsync then
        local ok, result = pcall(function()
            return _svc.TeleportService:GetPlayerPlaceInstanceAsync(userId)
        end)

        if ok and result and result.PlaceId and result.JobId then
            friendInstance = result
        end
    end

    if not friendInstance then
        warn("[HOC NOC] HopToFriend: não foi possível localizar servidor do amigo, executando Hop genérico")
        ServerHop.Hop()
        return false
    end

    if friendInstance.PlaceId ~= placeId then
        warn("[HOC NOC] HopToFriend: amigo em outro placeId (" .. tostring(friendInstance.PlaceId) .. "), não suportado")
        return false
    end

    if friendInstance.JobId == currentJob then
        warn("[HOC NOC] HopToFriend: amigo já no mesmo worker (mesmo JobId)")
        return true
    end

    pcall(function()
        _svc.TeleportService:TeleportToPlaceInstance(placeId, friendInstance.JobId)
    end)

    return true
end

return ServerHop

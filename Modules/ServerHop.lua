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

return ServerHop

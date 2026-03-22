--[[
    Services.lua — Referências centralizadas aos serviços do Roblox.
    Importado uma única vez no Main.lua e injetado via ctx em todos os módulos.
]]

local S = {}

S.Players          = game:GetService("Players")
S.TweenService     = game:GetService("TweenService")
S.UserInputService = game:GetService("UserInputService")
S.TeleportService  = game:GetService("TeleportService")
S.VirtualUser      = game:GetService("VirtualUser")
S.RunService       = game:GetService("RunService")
S.CoreGui          = game:GetService("CoreGui")
S.HttpService      = game:GetService("HttpService")

S.LocalPlayer = S.Players.LocalPlayer

return S

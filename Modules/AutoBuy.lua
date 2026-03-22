--[[
    AutoBuy.lua — Loop de compra automática de frutas.

    Init(ctx) inicia o loop em background.
    Verifica _G_AutoBuy e State.SelectedFruits a cada iteração.
]]

local AutoBuy = {}
local _svc, _state

function AutoBuy.Init(ctx)
    _svc  = ctx.Services
    _state = ctx.State

    task.spawn(function()
        while _G_Running do
            if _G_AutoBuy then
                pcall(function()
                    local playerGui = _svc.LocalPlayer:FindFirstChild("PlayerGui")
                    if not playerGui then return end

                    -- Monta lista de frutas selecionadas
                    local targets = {}
                    for name, active in pairs(_state.SelectedFruits) do
                        if active then table.insert(targets, name) end
                    end

                    if #targets == 0 then return end

                    for _, v in pairs(playerGui:GetDescendants()) do
                        if v:IsA("TextLabel") and v.Visible then
                            for _, tname in ipairs(targets) do
                                if v.Text:find(tname) then
                                    local parent = v.Parent
                                    local buyBtn = parent:FindFirstChildOfClass("TextButton")
                                               or parent:FindFirstChild("Buy")
                                    if buyBtn then
                                        for _ = 1, _G_BuyAmount do
                                            pcall(function() buyBtn.MouseButton1Click:Fire() end)
                                        end
                                        task.wait(0.18)
                                    end
                                end
                            end
                        end
                    end
                end)
            end
            task.wait(1.2)
        end
    end)
end

return AutoBuy

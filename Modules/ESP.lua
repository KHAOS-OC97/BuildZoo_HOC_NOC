--[[
    ESP.lua — Sistema de ESP (BillboardGui acima de cada jogador).

    Init(ctx) conecta RenderStepped uma única vez.
    Tags são criadas/removidas dinamicamente com base em _G_ESP.
    A cor do texto segue State.GlobalColor (RGB sincronizado).
]]

local ESP = {}
local _svc, _state

function ESP.Init(ctx)
    _svc  = ctx.Services
    _state = ctx.State

    _svc.RunService.RenderStepped:Connect(function()
        if not _G_Running then return end

        if _G_ESP then
            for _, p in pairs(_svc.Players:GetPlayers()) do
                if p ~= _svc.LocalPlayer and p.Character then
                    local head = p.Character:FindFirstChild("Head")
                    if not head then continue end

                    local tag = head:FindFirstChild("HOC_ELITE_TAG")
                    if not tag then
                        tag                = Instance.new("BillboardGui", head)
                        tag.Name           = "HOC_ELITE_TAG"
                        tag.Size           = UDim2.new(0, 300, 0, 70)
                        tag.AlwaysOnTop    = true
                        tag.MaxDistance    = 10000000
                        tag.StudsOffset    = Vector3.new(0, 4, 0)

                        local lbl                    = Instance.new("TextLabel", tag)
                        lbl.Name                     = "DisplayNameText"
                        lbl.Size                     = UDim2.new(1, 0, 1, 0)
                        lbl.BackgroundTransparency   = 1
                        lbl.Text                     = p.DisplayName
                        lbl.Font                     = Enum.Font.GothamBold
                        lbl.TextSize                 = 18
                        lbl.TextStrokeTransparency   = 0
                    end

                    local lbl = tag:FindFirstChild("DisplayNameText")
                    if lbl then
                        lbl.TextColor3 = _state.GlobalColor
                    end
                end
            end
        else
            -- Remove tags quando ESP desativado
            for _, p in pairs(_svc.Players:GetPlayers()) do
                if p.Character then
                    local head = p.Character:FindFirstChild("Head")
                    if head then
                        local tag = head:FindFirstChild("HOC_ELITE_TAG")
                        if tag then tag:Destroy() end
                    end
                end
            end
        end
    end)
end

return ESP

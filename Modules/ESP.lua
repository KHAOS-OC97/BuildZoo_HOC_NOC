--[[
    ESP.lua — Sistema de ESP (BillboardGui acima de cada jogador).

    Init(ctx) roda um loop leve (0.05s) que cria/atualiza/remove as tags.
    A cor do texto segue State.GlobalColor (RGB sincronizado).
]]

local ESP = {}
local _svc, _state
local _runtime

local TAG_NAME = "HOC_ELITE_TAG"

local function createTag(head, displayName)
    local tag = Instance.new("BillboardGui")
    tag.Name             = TAG_NAME
    tag.Size             = UDim2.new(0, 300, 0, 70)
    tag.AlwaysOnTop      = true
    tag.MaxDistance      = 10000000
    tag.StudsOffset      = Vector3.new(0, 4, 0)
    tag.LightInfluence   = 0

    local lbl                  = Instance.new("TextLabel", tag)
    lbl.Name                   = "DisplayNameText"
    lbl.Size                   = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = displayName
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 18
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3       = Color3.new(0, 0, 0)
    lbl.TextColor3             = Color3.new(1, 1, 1)

    -- Parent por último para evitar erro de acesso negado
    local ok = pcall(function() tag.Parent = head end)
    if not ok then
        -- Fallback: tenta via workspace
        pcall(function()
            tag.Parent = workspace
            tag.Adornee = head
        end)
    end
    return tag
end

local function removeAllTags()
    for _, p in pairs(_svc.Players:GetPlayers()) do
        if p ~= _svc.LocalPlayer and p.Character then
            local head = p.Character:FindFirstChild("Head")
            if head then
                local tag = head:FindFirstChild(TAG_NAME)
                if tag then pcall(function() tag:Destroy() end) end
            end
        end
    end
    -- Limpa também tags órfãs no workspace
    for _, v in pairs(workspace:GetDescendants()) do
        if v.Name == TAG_NAME then
            pcall(function() v:Destroy() end)
        end
    end
end

function ESP.Init(ctx)
    _svc   = ctx.Services
    _state = ctx.State

    _G.__HOC_RUNTIME = _G.__HOC_RUNTIME or {}
    _G.__HOC_RUNTIME.ESP = _G.__HOC_RUNTIME.ESP or {
        RenderConn = nil,
    }
    _runtime = _G.__HOC_RUNTIME.ESP

    if _runtime.RenderConn then
        pcall(function() _runtime.RenderConn:Disconnect() end)
        _runtime.RenderConn = nil
    end

    -- RenderStepped replica o comportamento antigo e mantém atualização visual constante.
    _runtime.RenderConn = _svc.RunService.RenderStepped:Connect(function()
        if not _G_Running then return end

        if _G_ESP then
            for _, p in pairs(_svc.Players:GetPlayers()) do
                if p ~= _svc.LocalPlayer and p.Character then
                    local head = p.Character:FindFirstChild("Head")
                    if head then
                        local tag = head:FindFirstChild(TAG_NAME)
                        if not tag then
                            tag = createTag(head, p.DisplayName)
                        end

                        if tag then
                            local lbl = tag:FindFirstChild("DisplayNameText")
                            if lbl then
                                pcall(function() lbl.TextColor3 = _state.GlobalColor end)
                            end
                        end
                    end
                end
            end
        else
            removeAllTags()
        end
    end)
end

return ESP

--[[
    State.lua — Estado global de runtime.

    _G_Running é sempre resetado para true ao executar o script.
    Os demais flags são preservados entre re-execuções (comportamento persistente).
    Stored guarda referências à GUI atual para que o monitor possa recriá-la.
]]

-- Sempre reinicia o script como "ativo"
_G_Running = true

-- Preserva toggles do usuário entre re-execuções
_G_AutoCollect = (_G_AutoCollect == nil) and false or _G_AutoCollect
_G_AutoBuild   = (_G_AutoBuild   == nil) and false or _G_AutoBuild
_G_AutoGifts   = (_G_AutoGifts   == nil) and false or _G_AutoGifts
_G_InfJump     = (_G_InfJump     == nil) and false or _G_InfJump
_G_ESP         = (_G_ESP         == nil) and false or _G_ESP
_G_AntiAFK     = (_G_AntiAFK     == nil) and false or _G_AntiAFK
_G_WalkSpeed   = (_G_WalkSpeed   == nil) and 16    or _G_WalkSpeed
_G_AutoBuy     = (_G_AutoBuy     == nil) and false or _G_AutoBuy
_G_BuyAmount   = (_G_BuyAmount   == nil) and 1     or _G_BuyAmount
_G_BigPetsFeed = (_G_BigPetsFeed == nil) and false or _G_BigPetsFeed

local State = {
    -- Cor RGB global — atualizada pelo loop de cor da GUI, consumida por todos os strokes
    GlobalColor = Color3.new(1, 1, 1),

    -- Mapa de seleção de frutas (populado pelo FruitMenu a partir de Config.FRUITS)
    SelectedFruits = {},

    -- Referências aos elementos da GUI atual
    Stored = {
        ScreenGui      = nil,
        Main           = nil,
        SpeedBtn       = nil,
        FruitBtn       = nil,
        BigPetsFeedBtn = nil,
        HopBtn         = nil,
        TPBtn          = nil,
        DropdownBtn    = nil,
        AutoBuyBtn     = nil,
        AmountSmallBtn = nil,
        Menu           = nil,
        MenuScroll     = nil,
        itemButtons    = {},
        -- Conexão do atalho CTRL (deve ser desconectada ao recriar a GUI)
        CtrlConn       = nil,
    },
}

-- Limpa referências da GUI anterior e desconecta eventos rastreados
function State.ClearStored()
    if State.Stored.CtrlConn then
        pcall(function() State.Stored.CtrlConn:Disconnect() end)
    end
    State.Stored = {
        ScreenGui      = nil,
        Main           = nil,
        SpeedBtn       = nil,
        FruitBtn       = nil,
        BigPetsFeedBtn = nil,
        HopBtn         = nil,
        TPBtn          = nil,
        DropdownBtn    = nil,
        AutoBuyBtn     = nil,
        AmountSmallBtn = nil,
        Menu           = nil,
        MenuScroll     = nil,
        itemButtons    = {},
        CtrlConn       = nil,
    }
end

return State

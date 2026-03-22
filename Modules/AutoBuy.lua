--[[
    AutoBuy.lua — Loop de compra automática de frutas.

    Init(ctx) inicia o loop em background.
    O módulo usa cache leve da GUI da loja para evitar travamentos e tenta
    múltiplas formas de acionar o botão de compra.
]]

local AutoBuy = {}
local _svc, _state
local _cachedEntries = {}
local _lastScanAt = 0
local _lastPurchaseAt = {}

local SCAN_INTERVAL = 2.5
local PURCHASE_COOLDOWN = 0.9

local function normalize(text)
    return tostring(text or ""):lower():gsub("%s+", "")
end

local function isGuiVisible(guiObject)
    local current = guiObject
    while current do
        if current:IsA("GuiObject") and not current.Visible then
            return false
        end
        if current:IsA("LayerCollector") and current.Enabled == false then
            return false
        end
        current = current.Parent
    end
    return true
end

local function getSelectedTargets()
    local targets = {}
    for name, active in pairs(_state.SelectedFruits) do
        if active then
            targets[name] = normalize(name)
        end
    end
    return targets
end

local function findBuyButton(container)
    local current = container
    for _ = 1, 3 do
        if not current then break end

        for _, descendant in ipairs(current:GetDescendants()) do
            if descendant:IsA("TextButton") then
                local buttonText = normalize(descendant.Text)
                local buttonName = normalize(descendant.Name)
                if buttonText:find("buy", 1, true) or buttonName:find("buy", 1, true) then
                    return descendant
                end
            end
        end

        current = current.Parent
    end

    return nil
end

local function scanShopEntries(playerGui, targets)
    local found = {}

    for _, guiObject in ipairs(playerGui:GetDescendants()) do
        if guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") then
            local rawText = guiObject.Text
            local normalizedText = normalize(rawText)

            if normalizedText ~= "" and isGuiVisible(guiObject) then
                local bestFruitName
                local bestNeedleLength = 0

                for fruitName, needle in pairs(targets) do
                    if normalizedText:find(needle, 1, true) and #needle > bestNeedleLength then
                        bestFruitName = fruitName
                        bestNeedleLength = #needle
                    end
                end

                if bestFruitName then
                    local buyButton = findBuyButton(guiObject.Parent)
                    if buyButton and isGuiVisible(buyButton) then
                        found[bestFruitName] = {
                            label = guiObject,
                            button = buyButton,
                        }
                    end
                end
            end
        end
    end

    _cachedEntries = found
    _lastScanAt = os.clock()
    return found
end

local function refreshCacheIfNeeded(playerGui, targets)
    if next(_cachedEntries) == nil then
        return scanShopEntries(playerGui, targets)
    end

    if os.clock() - _lastScanAt >= SCAN_INTERVAL then
        return scanShopEntries(playerGui, targets)
    end

    for fruitName, entry in pairs(_cachedEntries) do
        if not targets[fruitName]
        or not entry.label
        or not entry.label.Parent
        or not entry.button
        or not entry.button.Parent
        or not isGuiVisible(entry.label)
        or not isGuiVisible(entry.button) then
            return scanShopEntries(playerGui, targets)
        end
    end

    return _cachedEntries
end

local function fireButton(button)
    if not button then return false end

    local clicked = false

    if typeof(firesignal) == "function" then
        pcall(function()
            firesignal(button.MouseButton1Click)
            clicked = true
        end)
    end

    if not clicked then
        pcall(function()
            button:Activate()
            clicked = true
        end)
    end

    if not clicked and _svc.VirtualInputManager then
        local absPos = button.AbsolutePosition
        local absSize = button.AbsoluteSize
        local centerX = absPos.X + math.floor(absSize.X / 2)
        local centerY = absPos.Y + math.floor(absSize.Y / 2)

        pcall(function()
            _svc.VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 0)
            _svc.VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 0)
            clicked = true
        end)
    end

    return clicked
end

function AutoBuy.Init(ctx)
    _svc = ctx.Services
    _state = ctx.State

    task.spawn(function()
        while _G_Running do
            if _G_AutoBuy then
                pcall(function()
                    local playerGui = _svc.LocalPlayer:FindFirstChild("PlayerGui")
                    if not playerGui then return end

                    local targets = getSelectedTargets()
                    if next(targets) == nil then return end

                    local entries = refreshCacheIfNeeded(playerGui, targets)

                    for fruitName in pairs(targets) do
                        local entry = entries[fruitName]
                        if entry and entry.button and entry.button.Parent then
                            local lastPurchase = _lastPurchaseAt[fruitName] or 0
                            if os.clock() - lastPurchase >= PURCHASE_COOLDOWN then
                                for _ = 1, _G_BuyAmount do
                                    if not fireButton(entry.button) then
                                        break
                                    end
                                    task.wait(0.12)
                                end
                                _lastPurchaseAt[fruitName] = os.clock()
                            end
                        end
                    end
                end)
            end

            task.wait(0.2)
        end
    end)
end

return AutoBuy

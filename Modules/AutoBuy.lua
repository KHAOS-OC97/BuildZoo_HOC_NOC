--[[
    AutoBuy.lua — Loop de compra automática de frutas (leve e sem travamento).

    Usa cache agressivo e evita varrer a GUI frequentemente.
    O objetivo é manter a compra fluida sem impacto visível no jogo.
]]

local AutoBuy = {}
local _svc, _state
local _cachedShop = {}
local _lastFullScan = 0
local _lastPurchaseAttempt = {}
local _shopStateHash = nil

local SCAN_INTERVAL = 8.0
local PURCHASE_INTERVAL = 2.5
local PLAYER_GUI_CACHE_TIME = 0.5

local function normalize(text)
    return tostring(text or ""):lower():gsub("%s+", "")
end

local function isElementVisible(element)
    if not element or not element.Parent then return false end
    
    local current = element
    while current do
        if current:IsA("GuiObject") and not current.Visible then
            return false
        end
        if current:IsA("ScreenGui") and not current.Enabled then
            return false
        end
        current = current.Parent
    end
    return true
end

local function computeShopStateHash(playerGui)
    if not playerGui then return 0 end
    
    local hash = 0
    local count = 0
    
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Text ~= "" then
            hash = hash + #obj.Text
            count = count + 1
        end
    end
    
    return hash * 1000 + count
end

local function hasShopReset(playerGui)
    local currentHash = computeShopStateHash(playerGui)
    
    if _shopStateHash == nil then
        _shopStateHash = currentHash
        return false
    end
    
    if currentHash ~= _shopStateHash then
        _shopStateHash = currentHash
        return true
    end
    
    return false
end

local function activateButton(button)
    if not button then return false end

    local success = false

    if typeof(firesignal) == "function" then
        pcall(function()
            firesignal(button.MouseButton1Click)
            success = true
        end)
        if success then return true end
    end

    pcall(function()
        button:Activate()
        success = true
    end)
    if success then return true end

    if _svc.VirtualInputManager then
        local absPos = button.AbsolutePosition
        local absSize = button.AbsoluteSize
        local px = math.floor(absPos.X + absSize.X / 2)
        local py = math.floor(absPos.Y + absSize.Y / 2)

        pcall(function()
            _svc.VirtualInputManager:SendMouseButtonEvent(px, py, 0, true, game, 0)
            _svc.VirtualInputManager:SendMouseButtonEvent(px, py, 0, false, game, 0)
            success = true
        end)
    end

    return success
end

local function findBuyButtonFast(parent)
    if not parent then return nil end

    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("TextButton") then
            local txt = normalize(child.Text)
            local nm = normalize(child.Name)
            if txt:find("buy", 1, true) or nm:find("buy", 1, true) then
                return child
            end
        end
    end

    return nil
end

local function performFullScan(playerGui, targets)
    local found = {}

    if not playerGui then return found end

    local textElements = {}
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Text ~= "" then
            table.insert(textElements, obj)
        end
    end

    for _, element in ipairs(textElements) do
        if not isElementVisible(element) then continue end

        local normText = normalize(element.Text)
        local bestMatch
        local bestLen = 0

        for fruitName, needle in pairs(targets) do
            if normText:find(needle, 1, true) and #needle > bestLen then
                bestMatch = fruitName
                bestLen = #needle
            end
        end

        if bestMatch then
            local buyBtn = findBuyButtonFast(element.Parent)
            if buyBtn and isElementVisible(buyBtn) then
                found[bestMatch] = {
                    label = element,
                    button = buyBtn,
                }
            end
        end
    end

    _cachedShop = found
    _lastFullScan = os.clock()
    return found
end

local function refreshShop(playerGui, targets)
    local now = os.clock()

    if hasShopReset(playerGui) then
        _cachedShop = {}
        _lastFullScan = 0
    end

    if next(_cachedShop) == nil then
        return performFullScan(playerGui, targets)
    end

    if now - _lastFullScan >= SCAN_INTERVAL then
        return performFullScan(playerGui, targets)
    end

    local stillValid = true
    for fruitName, entry in pairs(_cachedShop) do
        if not targets[fruitName]
        or not entry.label or not entry.label.Parent
        or not entry.button or not entry.button.Parent
        or not isElementVisible(entry.label)
        or not isElementVisible(entry.button) then
            stillValid = false
            break
        end
    end

    if not stillValid then
        return performFullScan(playerGui, targets)
    end

    return _cachedShop
end

function AutoBuy.Init(ctx)
    _svc = ctx.Services
    _state = ctx.State

    task.spawn(function()
        while _G_Running do
            if _G_AutoBuy then
                local playerGui = _svc.LocalPlayer:FindFirstChild("PlayerGui")
                
                if playerGui then
                    pcall(function()
                        local targets = {}
                        for name, active in pairs(_state.SelectedFruits) do
                            if active then
                                targets[name] = normalize(name)
                            end
                        end

                        if next(targets) ~= nil then
                            local shop = refreshShop(playerGui, targets)
                            local now = os.clock()

                            for fruitName in pairs(targets) do
                                local entry = shop[fruitName]
                                if entry and entry.button and entry.button.Parent then
                                    local lastAttempt = _lastPurchaseAttempt[fruitName] or 0
                                    if now - lastAttempt >= PURCHASE_INTERVAL then
                                        for _ = 1, _G_BuyAmount do
                                            if not activateButton(entry.button) then break end
                                            task.wait(0.08)
                                        end
                                        _lastPurchaseAttempt[fruitName] = now
                                    end
                                end
                            end
                        end
                    end)
                end
            end

            task.wait(1.5)
        end
    end)
end

return AutoBuy

--[[
    AutoBuy.lua — Compra automática com prioridade para compra silenciosa.

    Modo principal: dispara RemoteEvent/RemoteFunction sem depender da GUI.
    Fallback opcional: clique em botão da loja (desligado por padrão).
]]

local AutoBuy = {}
local _svc, _state, _cfg
local _runtime

local _cachedShop = {}
local _lastFullScan = 0
local _remoteCandidates = {}
local _lastRemoteScan = 0

local function normalize(text)
    return tostring(text or ""):lower():gsub("%s+", "")
end

local function collectTargets()
    local t = {}
    for name, active in pairs(_state.SelectedFruits) do
        if active then
            t[name] = true
        end
    end
    return t
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
            if txt:find("buy", 1, true)
                or txt:find("purchase", 1, true)
                or nm:find("buy", 1, true)
                or nm:find("purchase", 1, true)
            then
                return child
            end
        end
    end

    return nil
end

local function refreshShop(playerGui, selected)
    local now = os.clock()
    local scanInterval = _cfg.AUTO_BUY_GUI_SCAN_INTERVAL or 8.0

    if next(_cachedShop) ~= nil and (now - _lastFullScan) < scanInterval then
        local stillValid = true
        for fruitName, entry in pairs(_cachedShop) do
            if not selected[fruitName]
                or not entry.label or not entry.label.Parent
                or not entry.button or not entry.button.Parent
                or not isElementVisible(entry.label)
                or not isElementVisible(entry.button)
            then
                stillValid = false
                break
            end
        end
        if stillValid then
            return _cachedShop
        end
    end

    local found = {}
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Text ~= "" and isElementVisible(obj) then
            local normText = normalize(obj.Text)
            for fruitName in pairs(selected) do
                if normText:find(normalize(fruitName), 1, true) then
                    local btn = findBuyButtonFast(obj.Parent)
                    if btn and isElementVisible(btn) then
                        found[fruitName] = {label = obj, button = btn}
                    end
                end
            end
        end
    end

    _cachedShop = found
    _lastFullScan = now
    return found
end

local function refreshRemoteCandidates()
    local now = os.clock()
    local scanInterval = _cfg.AUTO_BUY_REMOTE_SCAN_INTERVAL or 30
    if (now - _lastRemoteScan) < scanInterval and next(_remoteCandidates) ~= nil then
        return _remoteCandidates
    end

    local keywords = {
        "fruit", "shop", "buy", "purchase", "merchant", "stock", "restock", "item",
    }

    local candidates = {}
    local containers = {
        game:GetService("ReplicatedStorage"),
    }

    for _, root in ipairs(containers) do
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                local sig = normalize(obj:GetFullName() .. " " .. obj.Name)
                for _, kw in ipairs(keywords) do
                    if sig:find(kw, 1, true) then
                        table.insert(candidates, obj)
                        break
                    end
                end
            end
        end
    end

    _remoteCandidates = candidates
    _lastRemoteScan = now
    return _remoteCandidates
end

local function invokeRemote(remote, args)
    local ok = false
    pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(unpack(args))
            ok = true
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(unpack(args))
            ok = true
        end
    end)
    return ok
end

local function buildArgVariants(fruitName, amount)
    return {
        {fruitName},
        {fruitName, amount},
        {"Buy", fruitName},
        {"Buy", fruitName, amount},
        {"Purchase", fruitName},
        {"Purchase", fruitName, amount},
        {"Fruit", fruitName},
        {"Fruit", fruitName, amount},
    }
end

local function trySilentBuy(targets)
    local remotes = refreshRemoteCandidates()
    if #remotes == 0 then return false end

    local now = os.clock()
    local anyAttempt = false
    local fruitCooldown = _cfg.AUTO_BUY_FRUIT_COOLDOWN or 20
    local amount = math.max(1, tonumber(_G_BuyAmount) or 1)

    for fruitName in pairs(targets) do
        local last = _runtime.LastPurchaseAttempt[fruitName] or 0
        if (now - last) >= fruitCooldown then
            local variants = buildArgVariants(fruitName, amount)
            local sent = false

            for _, remote in ipairs(remotes) do
                for _, args in ipairs(variants) do
                    if invokeRemote(remote, args) then
                        sent = true
                        anyAttempt = true
                        break
                    end
                end
                if sent then break end
            end

            if sent then
                _runtime.LastPurchaseAttempt[fruitName] = now
                task.wait(_cfg.AUTO_BUY_REQUEST_SPACING or 0.08)
            end
        end
    end

    return anyAttempt
end

local function tryGuiFallback(targets)
    if not (_cfg.AUTO_BUY_ALLOW_GUI_FALLBACK == true) then
        return false
    end

    local pg = _svc.LocalPlayer and _svc.LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return false end

    local shop = refreshShop(pg, targets)
    local any = false
    local now = os.clock()
    local fruitCooldown = _cfg.AUTO_BUY_FRUIT_COOLDOWN or 20
    local amount = math.max(1, tonumber(_G_BuyAmount) or 1)

    for fruitName in pairs(targets) do
        local entry = shop[fruitName]
        if entry and entry.button and entry.button.Parent then
            local last = _runtime.LastPurchaseAttempt[fruitName] or 0
            if (now - last) >= fruitCooldown then
                for _ = 1, amount do
                    if not activateButton(entry.button) then break end
                    task.wait(_cfg.AUTO_BUY_REQUEST_SPACING or 0.08)
                end
                _runtime.LastPurchaseAttempt[fruitName] = now
                any = true
            end
        end
    end

    return any
end

function AutoBuy.Init(ctx)
    _svc = ctx.Services
    _state = ctx.State
    _cfg = ctx.Config

    _G.__HOC_RUNTIME = _G.__HOC_RUNTIME or {}
    _G.__HOC_RUNTIME.AutoBuy = _G.__HOC_RUNTIME.AutoBuy or {
        LoopStarted = false,
        LastSweep = 0,
        LastPurchaseAttempt = {},
    }
    _runtime = _G.__HOC_RUNTIME.AutoBuy

    if _runtime.LoopStarted then return end
    _runtime.LoopStarted = true

    task.spawn(function()
        while _G_Running do
            if _G_AutoBuy then
                pcall(function()
                    local targets = collectTargets()
                    if next(targets) ~= nil then
                        local now = os.clock()
                        local sweep = _cfg.AUTO_BUY_SILENT_SWEEP or 15
                        if (now - _runtime.LastSweep) >= sweep then
                            _runtime.LastSweep = now

                            local okSilent = trySilentBuy(targets)
                            if not okSilent then
                                tryGuiFallback(targets)
                            end
                        end
                    end
                end)
            end

            task.wait(_cfg.AUTO_BUY_LOOP_INTERVAL or 1.0)
        end
        _runtime.LoopStarted = false
    end)
end

return AutoBuy

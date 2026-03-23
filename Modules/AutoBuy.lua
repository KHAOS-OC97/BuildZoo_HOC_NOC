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
local isRobuxButton
local buttonIsSafeCoinTarget
local dismissRobuxModal

local function normalize(text)
    return tostring(text or ""):lower():gsub("%s+", "")
end

local function getGuiText(obj)
    if not obj then return "" end
    local ok, value = pcall(function()
        return obj.Text
    end)
    if ok and type(value) == "string" and value ~= "" then
        return value
    end

    if obj.GetDescendants then
        for _, child in ipairs(obj:GetDescendants()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") then
                local childOk, childValue = pcall(function()
                    return child.Text
                end)
                if childOk and type(childValue) == "string" and childValue ~= "" then
                    return childValue
                end
            end
        end
    end

    return ""
end

local function isGuiButton(obj)
    return obj and (obj:IsA("TextButton") or obj:IsA("ImageButton"))
end

local function isRobuxLike(text)
    local s = normalize(text)
    return s:find("robux", 1, true)
        or s:find("r$", 1, true)
        or s:find("gamepass", 1, true)
        or s:find("devproduct", 1, true)
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

local function matchesFruitShopKeyword(name)
    local sig = normalize(name)
    for _, kw in ipairs(_cfg.FRUIT_SHOP_KEYWORDS or {}) do
        if sig:find(normalize(kw), 1, true) then
            return true
        end
    end
    return false
end

local function collectFruitShopRoots(playerGui)
    local roots = {}
    local seen = {}

    local function add(root)
        if root and not seen[root] then
            seen[root] = true
            table.insert(roots, root)
        end
    end

    for _, obj in ipairs(playerGui:GetDescendants()) do
        if matchesFruitShopKeyword(obj.Name) then
            add(obj)
        elseif isGuiButton(obj) and normalize(obj.Name) == "buybutton" then
            local parent = obj.Parent
            if parent then
                add(parent)
                add(parent.Parent)
            end
        end
    end

    if #roots == 0 then
        add(playerGui)
    end

    return roots
end

local function collectFruitNamesForMatch(fruitName)
    local out = {}
    local seen = {}

    local function add(v)
        local s = tostring(v or "")
        if s ~= "" and not seen[s] then
            seen[s] = true
            table.insert(out, s)
        end
    end

    add(fruitName)

    local info = _cfg and _cfg.FRUIT_CANONICAL and _cfg.FRUIT_CANONICAL[fruitName]
    if info then
        add(info.path)
        add(info.resId)
        for _, a in ipairs(info.aliases or {}) do
            add(a)
        end
    end

    return out
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
    if not isElementVisible(button) then return false end

    -- Modo estrito: nunca interage com botao que nao seja BuyButton (coin).
    if (_cfg and _cfg.AUTO_BUY_STRICT_COIN_ONLY == true) then
        local nameSig = normalize(button.Name)
        local textSig = normalize(getGuiText(button))
        local isCoin = (nameSig == "buybutton")
            or textSig == "buy"
            or textSig == "purchase"
        if (not isCoin) or isRobuxLike(nameSig) or isRobuxLike(textSig) then
            return false
        end
    end

    if isRobuxButton(button) then
        return false
    end

    if not buttonIsSafeCoinTarget(button) then
        return false
    end

    if typeof(firesignal) == "function" then
        pcall(function()
            firesignal(button.MouseButton1Click)
        end)
    end

    if _svc.VirtualInputManager then
        local absPos = button.AbsolutePosition
        local absSize = button.AbsoluteSize
        if absSize.X > 0 and absSize.Y > 0 then
            local px = math.floor(absPos.X + absSize.X / 2)
            local py = math.floor(absPos.Y + absSize.Y / 2)

            local clicked = false
            pcall(function()
                _svc.VirtualInputManager:SendMouseButtonEvent(px, py, 0, true, game, 0)
                _svc.VirtualInputManager:SendMouseButtonEvent(px, py, 0, false, game, 0)
                clicked = true
            end)

            dismissRobuxModal()
            if clicked then
                return true
            end
        end
    end

    local success = false
    pcall(function()
        button:Activate()
        success = true
    end)

    dismissRobuxModal()

    return success
end

function isRobuxButton(button)
    if not button then return false end

    local nameSig = normalize(button.Name)
    local textSig = normalize(getGuiText(button))
    if isRobuxLike(nameSig) or isRobuxLike(textSig) then
        return true
    end

    return false
end

local function scoreBuyButton(button)
    local score = 0
    local nameSig = normalize(button.Name)
    local textSig = normalize(getGuiText(button))

    if nameSig == "buybutton" then score = score + 30 end
    if nameSig:find("buybutton", 1, true) then score = score + 12 end
    if textSig == "buy" or textSig == "purchase" then score = score + 6 end
    if nameSig:find("buy", 1, true) then score = score + 3 end

    if isRobuxButton(button) then
        score = score - 100
    end

    return score
end

local function collectLocalTexts(root)
    local texts = {}
    if not root then return texts end

    for _, obj in ipairs(root:GetDescendants()) do
        if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Text and obj.Text ~= "" then
            table.insert(texts, normalize(obj.Text))
        end
    end

    return texts
end

local function textSetHasAnyAlias(texts, aliases)
    if #texts == 0 or #aliases == 0 then return false end

    for _, t in ipairs(texts) do
        for _, a in ipairs(aliases) do
            local an = normalize(a)
            if an ~= "" and (t:find(an, 1, true) or an:find(t, 1, true)) then
                return true
            end
        end
    end

    return false
end

local function isOutOfStockText(text)
    local sig = normalize(text)
    return sig:find("nostock", 1, true) or sig:find("soldout", 1, true)
end

local function isRobuxModalText(text)
    local sig = normalize(text)
    return sig:find("buyrobuxanditem", 1, true)
        or sig:find("yourpaymentmethodwillbecharged", 1, true)
        or sig:find("termsofuse", 1, true)
end

dismissRobuxModal = function()
    local pg = _svc.LocalPlayer and _svc.LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return false end

    local modalRoot = nil

    for _, obj in ipairs(pg:GetDescendants()) do
        if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Text and obj.Text ~= "" and isElementVisible(obj) then
            if isRobuxModalText(obj.Text) then
                local current = obj
                while current and current ~= pg do
                    if current:IsA("Frame") or current:IsA("ScreenGui") then
                        modalRoot = current
                        break
                    end
                    current = current.Parent
                end
                if modalRoot then break end
            end
        end
    end

    if not modalRoot then return false end

    for _, obj in ipairs(modalRoot:GetDescendants()) do
        if isGuiButton(obj) and isElementVisible(obj) then
            local nameSig = normalize(obj.Name)
            local textSig = normalize(getGuiText(obj))
            if nameSig:find("close", 1, true)
                or textSig == "x"
                or textSig == "close"
                or nameSig == "x"
            then
                pcall(function()
                    if obj:IsA("TextButton") and typeof(firesignal) == "function" then
                        firesignal(obj.MouseButton1Click)
                    else
                        obj:Activate()
                    end
                end)
                return true
            end
        end
    end

    return false
end

local function cardLooksOutOfStock(root)
    if not root then return false end

    for _, obj in ipairs(root:GetDescendants()) do
        if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Text and obj.Text ~= "" then
            if isOutOfStockText(obj.Text) then
                return true
            end
        end
    end

    return false
end

local function collectCandidateContainers(button)
    local containers = {}
    local seen = {}

    local function add(node)
        if node and not seen[node] then
            seen[node] = true
            table.insert(containers, node)
        end
    end

    add(button and button.Parent)

    return containers
end

local function buttonHasLocalNoStock(button)
    if not button or not button.Parent then return false end

    local card = button.Parent
    for _, obj in ipairs(card:GetDescendants()) do
        if obj ~= button then
            if normalize(obj.Name) == "nostockbutton" then
                return true
            end

            if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Text and obj.Text ~= "" then
                if isOutOfStockText(obj.Text) then
                    return true
                end
            end
        end
    end

    return false
end

buttonIsSafeCoinTarget = function(button)
    if not button or isRobuxButton(button) then
        return false
    end

    local nameSig = normalize(button.Name)
    local textSig = normalize(getGuiText(button))
    if _cfg and _cfg.AUTO_BUY_STRICT_COIN_ONLY == true then
        if nameSig ~= "buybutton" and textSig ~= "buy" and textSig ~= "purchase" then
            return false
        end
    end

    if buttonHasLocalNoStock(button) then
        return false
    end

    for _, container in ipairs(collectCandidateContainers(button)) do
        if container and cardLooksOutOfStock(container) then
            return false
        end
    end

    return true
end

local function findBuyButtonFast(parent)
    if not parent then return nil end

    local strictCoinOnly = (_cfg and _cfg.AUTO_BUY_STRICT_COIN_ONLY == true)

    local best, bestScore = nil, -9999

    for _, child in ipairs(parent:GetDescendants()) do
        if isGuiButton(child) then
            local childName = normalize(child.Name)
            local childText = normalize(getGuiText(child))

            if childName == "buybutton" and buttonIsSafeCoinTarget(child) then
                return child
            end

            if strictCoinOnly then
                if (childText == "buy" or childText == "purchase") and buttonIsSafeCoinTarget(child) then
                    local s = scoreBuyButton(child)
                    if s > bestScore then
                        bestScore = s
                        best = child
                    end
                end
                continue
            end

            local txt = childText
            local nm = childName
            if txt:find("buy", 1, true)
                or txt:find("purchase", 1, true)
                or nm:find("buy", 1, true)
                or nm:find("purchase", 1, true)
            then
                local s = scoreBuyButton(child)
                if s > bestScore then
                    bestScore = s
                    best = child
                end
            end
        end
    end

    if best and bestScore > 0 then
        return best
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
                or isRobuxButton(entry.button)
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
    local roots = collectFruitShopRoots(playerGui)

    -- Mapa de aliases por fruta para match rapido.
    local aliasesByFruit = {}
    for fruitName in pairs(selected) do
        aliasesByFruit[fruitName] = collectFruitNamesForMatch(fruitName)
    end

    -- Escaneia cards reais da loja: botao BuyButton + textos locais do mesmo container.
    for _, root in ipairs(roots) do
        for _, obj in ipairs(root:GetDescendants()) do
            if isGuiButton(obj) and normalize(obj.Name) == "buybutton" and buttonIsSafeCoinTarget(obj) then
                local card = obj.Parent
                local textPool = collectLocalTexts(card)
                local scanRoot = card

                -- fallback: alguns layouts colocam nome/preco um nivel acima
                if #textPool == 0 and card and card.Parent then
                    textPool = collectLocalTexts(card.Parent)
                    scanRoot = card.Parent
                end

                if not cardLooksOutOfStock(scanRoot) and buttonIsSafeCoinTarget(obj) then
                    for fruitName in pairs(selected) do
                        if not found[fruitName] and textSetHasAnyAlias(textPool, aliasesByFruit[fruitName] or {}) then
                            found[fruitName] = {
                                label = obj,
                                button = obj,
                            }
                        end
                    end
                end
            end
        end
    end

    -- Fallback legado para layouts fora do padrao BuyButton.
    if next(found) == nil then
        for _, root in ipairs(roots) do
            for _, obj in ipairs(root:GetDescendants()) do
                if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Text ~= "" then
                    local normText = normalize(obj.Text)
                    for fruitName in pairs(selected) do
                        local matched = false
                        for _, alias in ipairs(aliasesByFruit[fruitName] or {}) do
                            if normText:find(normalize(alias), 1, true) then
                                matched = true
                                break
                            end
                        end

                        if matched then
                            local btn = findBuyButtonFast(obj.Parent)
                            if not btn and obj.Parent and obj.Parent.Parent then
                                btn = findBuyButtonFast(obj.Parent.Parent)
                            end
                            if btn and buttonIsSafeCoinTarget(btn) then
                                found[fruitName] = {label = obj, button = btn}
                            end
                        end
                    end
                end
            end
        end
    end

    _cachedShop = found
    _lastFullScan = now
    return found
end

local function collectSilentEligibleTargets(targets)
    local pg = _svc.LocalPlayer and _svc.LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then
        return targets
    end

    local shop = refreshShop(pg, targets)
    if next(shop) == nil then
        return targets
    end

    local eligible = {}
    for fruitName, entry in pairs(shop) do
        if targets[fruitName] and entry and entry.button and buttonIsSafeCoinTarget(entry.button) then
            eligible[fruitName] = true
        end
    end

    if next(eligible) == nil then
        return targets
    end

    return eligible
end

local function refreshRemoteCandidates()
    local now = os.clock()
    local scanInterval = _cfg.AUTO_BUY_REMOTE_SCAN_INTERVAL or 30
    if (now - _lastRemoteScan) < scanInterval and next(_remoteCandidates) ~= nil then
        return _remoteCandidates
    end

    local keywords = {
        "fruit", "food", "petfood", "shop", "buy", "purchase", "merchant", "stock", "restock", "item",
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
    local kind = "unknown"
    local result = nil
    pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(unpack(args))
            ok = true
            kind = "event"
        elseif remote:IsA("RemoteFunction") then
            result = remote:InvokeServer(unpack(args))
            ok = true
            kind = "function"
        end
    end)
    return ok, kind, result
end

local function buildArgVariants(fruitName, amount)
    local names = {}
    local seen = {}
    local function addName(n)
        local s = tostring(n or "")
        if s ~= "" and not seen[s] then
            seen[s] = true
            table.insert(names, s)
        end
    end

    for _, alias in ipairs(collectFruitNamesForMatch(fruitName)) do
        local noSpace = alias:gsub("%s+", "")
        local under = alias:gsub("%s+", "_")
        local dash = alias:gsub("%s+", "-")

        addName(alias)
        addName(noSpace)
        addName(under)
        addName(dash)
        addName(alias:lower())
        addName(noSpace:lower())
    end

    local variants = {}
    local function addArgs(...)
        table.insert(variants, {...})
    end

    for _, n in ipairs(names) do
        addArgs(n)
        addArgs(n, amount)
        addArgs("Buy", n)
        addArgs("Buy", n, amount)
        addArgs("Purchase", n)
        addArgs("Purchase", n, amount)
        addArgs("Fruit", n)
        addArgs("Fruit", n, amount)
    end

    return variants
end

local function trySilentBuy(targets)
    targets = collectSilentEligibleTargets(targets)
    if next(targets) == nil then return false, false end

    local remotes = refreshRemoteCandidates()
    if #remotes == 0 then return false, false end

    local now = os.clock()
    local anyAttempt = false
    local anyReliableSuccess = false
    local fruitCooldown = _cfg.AUTO_BUY_FRUIT_COOLDOWN or 20
    local amount = math.max(1, tonumber(_G_BuyAmount) or 1)

    for fruitName in pairs(targets) do
        local last = _runtime.LastPurchaseAttempt[fruitName] or 0
        if (now - last) >= fruitCooldown then
            local variants = buildArgVariants(fruitName, amount)
            local sent = false

            for _, remote in ipairs(remotes) do
                for _, args in ipairs(variants) do
                    local ok, kind, result = invokeRemote(remote, args)
                    dismissRobuxModal()
                    if ok then
                        anyAttempt = true

                        if kind == "function" and result ~= false and result ~= nil then
                            anyReliableSuccess = true
                            sent = true
                            break
                        end
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

    return anyReliableSuccess, anyAttempt
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
            local strictCoinOnly = (_cfg.AUTO_BUY_STRICT_COIN_ONLY == true)
            if not buttonIsSafeCoinTarget(entry.button) then
                continue
            end
            if strictCoinOnly then
                local nm = normalize(entry.button.Name)
                            local tx = normalize(getGuiText(entry.button))
                if nm ~= "buybutton" and tx ~= "buy" and tx ~= "purchase" then
                    continue
                end
            end
            if strictCoinOnly and isRobuxButton(entry.button) then
                continue
            end
            local last = _runtime.LastPurchaseAttempt[fruitName] or 0
            if (now - last) >= fruitCooldown then
                local clicked = false
                for _ = 1, amount do
                    if not activateButton(entry.button) then break end
                    clicked = true
                    task.wait(_cfg.AUTO_BUY_REQUEST_SPACING or 0.08)
                end
                if clicked then
                    _runtime.LastPurchaseAttempt[fruitName] = now
                    any = true
                end
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
                    dismissRobuxModal()
                    local targets = collectTargets()
                    if next(targets) ~= nil then
                        local now = os.clock()
                        local sweep = _cfg.AUTO_BUY_SILENT_SWEEP or 15
                        local guiOnly = (_cfg.AUTO_BUY_GUI_ONLY == true)

                        if guiOnly then
                            tryGuiFallback(targets)
                        else
                            local allowForcedGuiFallback = (_cfg.AUTO_BUY_FORCE_GUI_FALLBACK_AFTER_SILENT == true)

                            if (now - _runtime.LastSweep) >= sweep then
                                _runtime.LastSweep = now

                                local reliableSilent, anySilentAttempt = trySilentBuy(targets)
                                if not reliableSilent and ((not anySilentAttempt) or allowForcedGuiFallback) then
                                    tryGuiFallback(targets)
                                end
                            elseif allowForcedGuiFallback then
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

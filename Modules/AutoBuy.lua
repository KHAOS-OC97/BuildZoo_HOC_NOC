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
local isElementVisible

local ROBUX_MODAL_SCAN_INTERVAL = 0.75
local ROBUX_GUARD_COOLDOWN = 20

local function normalizeCompact(text)
    return tostring(text or ""):lower():gsub("[^%w]+", "")
end

local function getFruitConfig(fruitName)
    for _, fruit in ipairs(_cfg and _cfg.FRUITS or {}) do
        if fruit.name == fruitName then
            return fruit
        end
    end
    return nil
end

local function collectExpectedPriceTokens(fruitName)
    local out = {}
    local seen = {}
    local fruit = getFruitConfig(fruitName)
    if not fruit or not fruit.price then
        return out
    end

    local function add(value)
        local token = normalizeCompact(value)
        if token ~= "" and not seen[token] then
            seen[token] = true
            table.insert(out, token)
        end
    end

    local raw = tostring(fruit.price)
    add(raw)
    add(raw:gsub(",", ""))
    add(raw:gsub("%.", ""))
    add(raw:gsub(",", ""):gsub("%.", ""))

    return out
end

local function textSetHasAnyPrice(texts, fruitName)
    local priceTokens = collectExpectedPriceTokens(fruitName)
    if #priceTokens == 0 then
        return true
    end

    for _, text in ipairs(texts) do
        local compactText = normalizeCompact(text)
        for _, token in ipairs(priceTokens) do
            if compactText:find(token, 1, true) then
                return true
            end
        end
    end

    return false
end

local function setRobuxGuard(reason)
    _runtime.RobuxGuardUntil = os.clock() + ROBUX_GUARD_COOLDOWN
    _cachedShop = {}
    _lastFullScan = 0
    if reason then
        _runtime.LastRobuxGuardReason = reason
    end
end

local function robuxGuardActive()
    return (tonumber(_runtime and _runtime.RobuxGuardUntil) or 0) > os.clock()
end

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

local function isExplicitRobuxButtonName(name)
    local sig = normalize(name)
    return sig == "robuxbuybutton"
        or sig:find("robuxbuybutton", 1, true)
        or sig:find("robuxbuy", 1, true)
end

local function isRobuxLike(text)
    local s = normalize(text)
    return isExplicitRobuxButtonName(s)
        or s:find("robux", 1, true)
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

local function updateDebugText(lines)
    local text = "AUTO BUY DEBUG"
    if lines and #lines > 0 then
        text = text .. "\n" .. table.concat(lines, "\n")
    else
        text = text .. "\nAguardando varredura..."
    end

    _state.AutoBuyDebugText = text

    local label = _state.Stored and _state.Stored.AutoBuyDebugLabel
    if label and label.Parent then
        label.Text = text
    end
end

local function buildSelectedDebugLines(selected, found)
    local names = {}
    for fruitName in pairs(selected) do
        table.insert(names, fruitName)
    end
    table.sort(names)

    local lines = {}
    for _, fruitName in ipairs(names) do
        if found and found[fruitName] and found[fruitName].button and found[fruitName].button.Parent then
            table.insert(lines, "[OK] " .. fruitName .. " -> BuyButton encontrado")
        else
            table.insert(lines, "[NO] " .. fruitName .. " -> BuyButton nao encontrado")
        end
    end

    return lines
end

local function buildSilentDebugLines(selected, statusByFruit, extraLine)
    local names = {}
    for fruitName in pairs(selected) do
        table.insert(names, fruitName)
    end
    table.sort(names)

    local lines = {}
    if extraLine and extraLine ~= "" then
        table.insert(lines, extraLine)
    end

    for _, fruitName in ipairs(names) do
        local status = statusByFruit and statusByFruit[fruitName] or nil
        if status and status ~= "" then
            table.insert(lines, status)
        else
            table.insert(lines, "[WAIT] " .. fruitName .. " -> sem tentativa silenciosa ainda")
        end
    end

    return lines
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

local function scoreRemoteCandidate(remote)
    local score = 0
    local sig = normalize(remote:GetFullName() .. " " .. remote.Name)

    if remote:IsA("RemoteFunction") then score = score + 30 end
    if sig:find("buy", 1, true) then score = score + 16 end
    if sig:find("purchase", 1, true) then score = score + 14 end
    if sig:find("fruit", 1, true) then score = score + 10 end
    if sig:find("petfood", 1, true) then score = score + 10 end
    if sig:find("food", 1, true) then score = score + 6 end
    if sig:find("shop", 1, true) then score = score + 5 end
    if sig:find("merchant", 1, true) then score = score + 3 end
    if sig:find("stock", 1, true) then score = score - 4 end
    if sig:find("restock", 1, true) then score = score - 6 end

    return score
end

local function collectTargetBatch(targets)
    local names = {}
    for fruitName in pairs(targets) do
        table.insert(names, fruitName)
    end

    table.sort(names)

    local batchSize = math.max(1, tonumber(_cfg.AUTO_BUY_MAX_FRUITS_PER_PULSE) or #names)
    if #names <= batchSize then
        _runtime.NextTargetCursor = 1
        return names
    end

    local out = {}
    local cursor = tonumber(_runtime.NextTargetCursor) or 1
    if cursor < 1 or cursor > #names then
        cursor = 1
    end

    for offset = 0, batchSize - 1 do
        local idx = ((cursor + offset - 1) % #names) + 1
        table.insert(out, names[idx])
    end

    _runtime.NextTargetCursor = ((cursor + batchSize - 1) % #names) + 1
    return out
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
            if isElementVisible(obj) then
                add(obj)
            end
        elseif isGuiButton(obj) and normalize(obj.Name) == "buybutton" then
            local parent = obj.Parent
            if parent then
                if isElementVisible(obj) then
                    add(parent)
                    add(parent.Parent)
                end
            end
        end
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

    local compact = tostring(fruitName or ""):gsub("%s+", "")
    local under = tostring(fruitName or ""):gsub("%s+", "_")
    local dash = tostring(fruitName or ""):gsub("%s+", "-")
    add(compact)
    add(under)
    add(dash)
    if compact ~= "" then
        add("PetFood/" .. compact)
        add("PetFood/" .. under)
        add("PetFood/" .. dash)
    end

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

isElementVisible = function(element)
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
    if robuxGuardActive() then return false end

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

    local success = false
    dismissRobuxModal(true)

    if typeof(firesignal) == "function" then
        pcall(function()
            firesignal(button.MouseButton1Click)
            success = true
        end)
    else
        pcall(function()
            button:Activate()
            success = true
        end)
    end

    if dismissRobuxModal(true) then
        success = false
    end

    return success
end

function isRobuxButton(button)
    if not button then return false end

    local nameSig = normalize(button.Name)
    local textSig = normalize(getGuiText(button))
    local fullNameSig = ""
    pcall(function()
        fullNameSig = normalize(button:GetFullName())
    end)

    if isExplicitRobuxButtonName(nameSig)
        or isExplicitRobuxButtonName(fullNameSig)
        or isRobuxLike(nameSig)
        or isRobuxLike(textSig)
        or isRobuxLike(fullNameSig)
    then
        return true
    end

    return false
end

local function scoreBuyButton(button)
    local score = 0
    local nameSig = normalize(button.Name)
    local textSig = normalize(getGuiText(button))

    if isExplicitRobuxButtonName(nameSig) then
        return -1000
    end

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

dismissRobuxModal = function(force)
    local pg = _svc.LocalPlayer and _svc.LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return false end

    local now = os.clock()
    local lastScan = tonumber(_runtime and _runtime.LastRobuxModalScan) or 0
    if not force and (now - lastScan) < ROBUX_MODAL_SCAN_INTERVAL then
        return false
    end
    _runtime.LastRobuxModalScan = now

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

    setRobuxGuard("robux-modal")

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

local function containerHasRobuxSignals(root)
    if not root then return false end

    for _, obj in ipairs(root:GetDescendants()) do
        local nameSig = normalize(obj.Name)
        if isRobuxLike(nameSig) then
            return true
        end

        if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Text and obj.Text ~= "" then
            local textSig = normalize(obj.Text)
            if isRobuxLike(textSig) or isRobuxModalText(textSig) then
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
    add(button and button.Parent and button.Parent.Parent)
    add(button and button.Parent and button.Parent.Parent and button.Parent.Parent.Parent)

    return containers
end

local function isGuiContainer(obj)
    return obj and (obj:IsA("Frame") or obj:IsA("CanvasGroup") or obj:IsA("ScrollingFrame"))
end

local function findFruitCardRootFromButton(button, fruitName, aliases)
    local current = button and button.Parent
    local steps = 0

    while current and steps < 6 do
        if isGuiContainer(current) and isElementVisible(current) then
            local texts = collectLocalTexts(current)
            if textSetHasAnyAlias(texts, aliases or {}) and textSetHasAnyPrice(texts, fruitName) then
                return current, texts
            end
        end

        current = current.Parent
        steps = steps + 1
    end

    return nil, nil
end

local function isLeftPurchaseSlot(button)
    if not button or not button.Parent then return false end

    local buttonPos = button.AbsolutePosition
    local buttonSize = button.AbsoluteSize
    local parent = button.Parent
    local parentPos = parent.AbsolutePosition
    local parentSize = parent.AbsoluteSize

    if not buttonPos or not buttonSize or not parentPos or not parentSize then
        return false
    end

    local buttonCenterX = buttonPos.X + (buttonSize.X * 0.5)
    local buttonCenterY = buttonPos.Y + (buttonSize.Y * 0.5)
    local parentCenterX = parentPos.X + (parentSize.X * 0.5)
    local parentCenterY = parentPos.Y + (parentSize.Y * 0.5)

    return buttonCenterX < parentCenterX and buttonCenterY >= parentCenterY
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
    if robuxGuardActive() then
        return false
    end

    local nameSig = normalize(button.Name)
    local textSig = normalize(getGuiText(button))
    if _cfg and _cfg.AUTO_BUY_STRICT_COIN_ONLY == true then
        if nameSig ~= "buybutton" and textSig ~= "buy" and textSig ~= "purchase" then
            return false
        end
    end

    if not isLeftPurchaseSlot(button) then
        return false
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

            if isExplicitRobuxButtonName(childName) or isRobuxLike(childText) then
                continue
            end

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

local function findFruitCardEntries(root, selected, aliasesByFruit)
    local found = {}

    for _, obj in ipairs(root:GetDescendants()) do
        if isGuiButton(obj)
            and normalize(obj.Name) == "buybutton"
            and isElementVisible(obj)
            and buttonIsSafeCoinTarget(obj)
        then
            for fruitName in pairs(selected) do
                if not found[fruitName] then
                    local cardRoot = findFruitCardRootFromButton(obj, fruitName, aliasesByFruit[fruitName])
                    if cardRoot and not cardLooksOutOfStock(cardRoot) then
                        found[fruitName] = {
                            label = cardRoot,
                            button = obj,
                        }
                    end
                end
            end
        end
    end

    return found
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
            updateDebugText(buildSelectedDebugLines(selected, _cachedShop))
            return _cachedShop
        end
    end

    local found = {}
    local roots = collectFruitShopRoots(playerGui)
    if #roots == 0 then
        roots = {playerGui}
    end

    -- Mapa de aliases por fruta para match rapido.
    local aliasesByFruit = {}
    for fruitName in pairs(selected) do
        aliasesByFruit[fruitName] = collectFruitNamesForMatch(fruitName)
    end

    for _, root in ipairs(roots) do
        local entries = findFruitCardEntries(root, selected, aliasesByFruit)
        for fruitName, entry in pairs(entries) do
            if not found[fruitName] then
                found[fruitName] = entry
            end
        end
    end

    if next(found) == nil then
        _cachedShop = {}
        _lastFullScan = now
        updateDebugText(buildSelectedDebugLines(selected, _cachedShop))
        return _cachedShop
    end

    _cachedShop = found
    _lastFullScan = now
    updateDebugText(buildSelectedDebugLines(selected, _cachedShop))
    return found
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

    table.sort(candidates, function(a, b)
        return scoreRemoteCandidate(a) > scoreRemoteCandidate(b)
    end)

    local maxCandidates = math.max(1, tonumber(_cfg.AUTO_BUY_MAX_REMOTE_CANDIDATES) or #candidates)
    while #candidates > maxCandidates do
        table.remove(candidates)
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
    local maxVariants = math.max(1, tonumber(_cfg.AUTO_BUY_MAX_ARG_VARIANTS) or 24)

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
    local variantSeen = {}
    local function addArgs(...)
        if #variants >= maxVariants then return end

        local args = {...}
        local keyParts = {}
        for i = 1, #args do
            keyParts[i] = tostring(args[i])
        end
        local key = table.concat(keyParts, "|")
        if variantSeen[key] then return end

        variantSeen[key] = true
        table.insert(variants, args)
    end

    for _, n in ipairs(names) do
        addArgs(n)
        addArgs(n, amount)
        addArgs("Buy", n, amount)
        addArgs("Buy", n)
        addArgs("Purchase", n, amount)
        addArgs("Purchase", n)
        addArgs("Fruit", n)
        addArgs("Fruit", n, amount)

        if #variants >= maxVariants then
            break
        end
    end

    return variants
end

local function trySilentBuy(targets)
    if next(targets) == nil then return false, false end
    if robuxGuardActive() then return false, false end

    local remotes = refreshRemoteCandidates()
    if #remotes == 0 then
        updateDebugText(buildSilentDebugLines(targets, nil, "[NO] Nenhum remote de compra encontrado"))
        return false, false
    end

    local now = os.clock()
    local anyAttempt = false
    local anyReliableSuccess = false
    local statusByFruit = {}
    local fruitCooldown = _cfg.AUTO_BUY_FRUIT_COOLDOWN or 20
    local probeCooldown = _cfg.AUTO_BUY_PROBE_COOLDOWN or 6
    local amount = math.max(1, tonumber(_G_BuyAmount) or 1)
    local probeBudget = math.max(1, tonumber(_cfg.AUTO_BUY_MAX_PROBES_PER_FRUIT) or 6)
    local yieldEvery = math.max(1, tonumber(_cfg.AUTO_BUY_INVOKE_YIELD_EVERY) or 8)
    local targetBatch = collectTargetBatch(targets)

    for _, fruitName in ipairs(targetBatch) do
        local lastSuccess = _runtime.LastPurchaseAttempt[fruitName] or 0
        local lastProbe = _runtime.LastSilentProbe[fruitName] or 0
        local waitWindow = ((now - lastSuccess) < fruitCooldown) and fruitCooldown or probeCooldown
        local lastActivity = math.max(lastSuccess, lastProbe)

        if (now - lastActivity) >= waitWindow then
            local variants = buildArgVariants(fruitName, amount)
            local totalCombos = #remotes * #variants
            statusByFruit[fruitName] = "[TRY] " .. fruitName .. " -> " .. tostring(#remotes) .. " remotes / " .. tostring(#variants) .. " variantes"

            if totalCombos > 0 then
                local probeIndex = tonumber(_runtime.ProbeIndexByFruit[fruitName]) or 1
                if probeIndex < 1 or probeIndex > totalCombos then
                    probeIndex = 1
                end

                local sent = false
                local fruitHadAttempt = false
                local fruitProbes = math.min(probeBudget, totalCombos)

                for _ = 1, fruitProbes do
                    local zeroIdx = probeIndex - 1
                    local remoteIdx = math.floor(zeroIdx / #variants) + 1
                    local variantIdx = (zeroIdx % #variants) + 1
                    local remote = remotes[remoteIdx]
                    local args = variants[variantIdx]

                    local ok, kind, result = invokeRemote(remote, args)
                    dismissRobuxModal(false)

                    probeIndex = probeIndex + 1
                    if probeIndex > totalCombos then
                        probeIndex = 1
                    end

                    if ok then
                        anyAttempt = true
                        fruitHadAttempt = true

                        if kind == "function" and result ~= false and result ~= nil then
                            anyReliableSuccess = true
                            sent = true
                            _runtime.PreferredRemoteByFruit[fruitName] = remote:GetFullName()
                            statusByFruit[fruitName] = "[OK] " .. fruitName .. " -> remote confirmado"
                            break
                        end

                        if kind == "event" then
                            statusByFruit[fruitName] = "[EVENT] " .. fruitName .. " -> evento disparado, aguardando confirmacao"
                            break
                        end
                    end

                    if (_ % yieldEvery) == 0 then
                        task.wait()
                    end
                end

                _runtime.ProbeIndexByFruit[fruitName] = probeIndex

                if sent then
                    _runtime.LastPurchaseAttempt[fruitName] = now
                    _runtime.LastSilentProbe[fruitName] = now
                    task.wait(_cfg.AUTO_BUY_REQUEST_SPACING or 0.08)
                elseif fruitHadAttempt then
                    _runtime.LastSilentProbe[fruitName] = now
                    if not statusByFruit[fruitName] or statusByFruit[fruitName] == "" or statusByFruit[fruitName]:find("%[TRY%]", 1, false) then
                        statusByFruit[fruitName] = "[NO] " .. fruitName .. " -> remote nao confirmou compra"
                    end
                end
            else
                statusByFruit[fruitName] = "[NO] " .. fruitName .. " -> nenhuma variante de argumento"
            end
        else
            statusByFruit[fruitName] = "[COOLDOWN] " .. fruitName .. " -> aguardando proxima tentativa"
        end
    end

    updateDebugText(buildSilentDebugLines(targets, statusByFruit, "[HIDDEN] Modo oculto por remote"))

    return anyReliableSuccess, anyAttempt
end

local function tryGuiFallback(targets)
    if not (_cfg.AUTO_BUY_ALLOW_GUI_FALLBACK == true) then
        return false
    end
    if robuxGuardActive() then
        return false
    end

    local pg = _svc.LocalPlayer and _svc.LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return false end

    local shop = refreshShop(pg, targets)
    local any = false
    local now = os.clock()
    local fruitCooldown = _cfg.AUTO_BUY_FRUIT_COOLDOWN or 20
    local maxClicksPerStock = math.max(1, tonumber(_cfg.AUTO_BUY_MAX_CLICKS_PER_STOCK) or 25)

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
                for _ = 1, maxClicksPerStock do
                    if buttonHasLocalNoStock(entry.button) then break end
                    if cardLooksOutOfStock(entry.button.Parent) then break end
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

function AutoBuy.Pulse()
    dismissRobuxModal(false)

    local targets = collectTargets()
    if next(targets) == nil then
        updateDebugText({"Nenhuma fruta selecionada."})
        return false
    end

    local guiOnly = (_cfg.AUTO_BUY_GUI_ONLY == true)
    if guiOnly then
        return tryGuiFallback(targets)
    end

    local okSilent = trySilentBuy(targets)
    if okSilent then
        return true
    end

    return tryGuiFallback(targets)
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
        LastSilentProbe = {},
        LastRobuxModalScan = 0,
        RobuxGuardUntil = 0,
        LastRobuxGuardReason = nil,
        ProbeIndexByFruit = {},
        PreferredRemoteByFruit = {},
        NextTargetCursor = 1,
    }
    _runtime = _G.__HOC_RUNTIME.AutoBuy

    if _runtime.LoopStarted then return end
    _runtime.LoopStarted = true

    task.spawn(function()
        while _G_Running do
            if _G_AutoBuy then
                pcall(function()
                    local now = os.clock()
                    local sweep = _cfg.AUTO_BUY_SILENT_SWEEP or 15

                    if (now - _runtime.LastSweep) >= sweep then
                        _runtime.LastSweep = now
                        AutoBuy.Pulse()
                    elseif (_cfg.AUTO_BUY_FORCE_GUI_FALLBACK_AFTER_SILENT == true) then
                        local targets = collectTargets()
                        if next(targets) ~= nil then
                            tryGuiFallback(targets)
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

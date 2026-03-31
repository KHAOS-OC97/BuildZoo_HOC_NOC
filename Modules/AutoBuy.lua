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
local scoreRemoteCandidate
local collectFruitShopRoots
local collectFruitNamesForMatch
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
        or sig == "robuxbuybutton" -- reforço explícito
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

    if next(t) == nil then
        for _, fruit in ipairs(_cfg and _cfg.FRUITS or {}) do
            t[fruit.name] = true
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
end

local function refreshDiagnosticLogLabel()
    local rawText = _state.AutoBuyDiagLogText or "AUTO BUY DIAGNOSTIC LOG\nPronto para scan."

    local function escapeRichText(text)
        return tostring(text or "")
            :gsub("&", "&amp;")
            :gsub("<", "&lt;")
            :gsub(">", "&gt;")
    end

    local function getLevelColor(line)
        local upper = tostring(line or "")
        if upper:find("%[ERR%]", 1) then return "#FF6B6B" end
        if upper:find("%[WARN%]", 1) then return "#FFC857" end
        if upper:find("%[NO%]", 1) then return "#FF9F5A" end
        if upper:find("%[OK%]", 1) then return "#66D17A" end
        if upper:find("%[EVENT%]", 1) then return "#7BDFF2" end
        if upper:find("%[SCAN%-ERR%]", 1) then return "#FF6B6B" end
        if upper:find("%[SCAN%]", 1) or upper:find("%[REMOTE", 1, true) or upper:find("%[ROOT", 1, true) or upper:find("%[BTN", 1, true) then
            return "#8BD3FF"
        end
        if upper:find("%[INFO%]", 1) or upper:find("%[HIDDEN%]", 1) or upper:find("%[SAFE%]", 1) then
            return "#C9D1D9"
        end
        return "#D7DBE0"
    end

    local richLines = {}
    for line in tostring(rawText):gmatch("([^\n]*)\n?") do
        if line ~= "" then
            table.insert(richLines, string.format(
                '<font color="%s">%s</font>',
                getLevelColor(line),
                escapeRichText(line)
            ))
        end
    end

    local label = _state.Stored and _state.Stored.AutoBuyDiagLogLabel
    if label and label.Parent then
        label.RichText = true
        label.Text = table.concat(richLines, "\n")
    end

    local lineCount = 0
    for _ in tostring(rawText):gmatch("[^\n]+") do
        lineCount = lineCount + 1
    end

    local countLabel = _state.Stored and _state.Stored.AutoBuyDiagCountLabel
    if countLabel and countLabel.Parent then
        countLabel.Text = "LINES: " .. tostring(lineCount)
    end

    local timeLabel = _state.Stored and _state.Stored.AutoBuyDiagTimeLabel
    if timeLabel and timeLabel.Parent then
        timeLabel.Text = "UPDATED: " .. tostring(_state.AutoBuyDiagLastStamp or "--:--:--")
    end
end

local function getLogTimestamp()
    local ok, value = pcall(function()
        return os.date("%H:%M:%S")
    end)
    if ok and type(value) == "string" and value ~= "" then
        return value
    end
    return string.format("%06.2f", os.clock())
end

local function setDiagnosticLogText(text)
    _state.AutoBuyDiagLogText = tostring(text or "")
    _state.AutoBuyDiagLastStamp = getLogTimestamp()
    refreshDiagnosticLogLabel()
end

local function appendDiagnosticLogLines(lines)
    local current = tostring(_state.AutoBuyDiagLogText or "AUTO BUY DIAGNOSTIC LOG\nPronto para scan.")
    local rawLines = {}
    if type(lines) == "table" then
        for _, line in ipairs(lines) do
            table.insert(rawLines, tostring(line or ""))
        end
    else
        table.insert(rawLines, tostring(lines or ""))
    end

    local stamped = {}
    local stamp = getLogTimestamp()
    for _, line in ipairs(rawLines) do
        if line ~= "" then
            table.insert(stamped, string.format("[%s] %s", stamp, line))
        end
    end

    local extra = table.concat(stamped, "\n")
    if extra == "" then
        refreshDiagnosticLogLabel()
        return
    end
    if current ~= "" then
        current = current .. "\n\n" .. extra
    else
        current = extra
    end
    setDiagnosticLogText(current)
end

local function tryCopyToClipboard(text)
    if type(setclipboard) == "function" then
        return pcall(setclipboard, text)
    end
    if type(toclipboard) == "function" then
        return pcall(toclipboard, text)
    end
    if type(clipboard) == "function" then
        return pcall(clipboard, text)
    end
    return false
end

local function reportRuntimeError(stage, err)
    local message = tostring(err or "erro desconhecido")
    local compact = message:gsub("%s+", " ")
    _runtime.LastError = compact
    appendDiagnosticLogLines({
        "[ERR] " .. tostring(stage or "AutoBuy"),
        compact,
    })
    updateDebugText({
        "[ERR] " .. tostring(stage or "AutoBuy") .. " -> falha interna",
        compact:sub(1, 220),
    })
    warn("[AutoBuy] " .. tostring(stage or "AutoBuy") .. " -> " .. message)
end

local function runProtected(stage, fn)
    local ok, result = xpcall(fn, function(err)
        return debug.traceback(tostring(err), 2)
    end)

    if not ok then
        reportRuntimeError(stage, result)
        return false, nil
    end

    return true, result
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

local function summarizeRemoteCandidates(remotes)
    if not remotes or #remotes == 0 then
        return "[NO] Nenhum remote candidato"
    end

    local parts = {}
    local limit = math.min(#remotes, 3)
    for i = 1, limit do
        local label = remotes[i] and remotes[i].Name or "?"
        table.insert(parts, tostring(label))
    end

    return "[REMOTES] " .. tostring(#remotes) .. " -> " .. table.concat(parts, ", ")
end

local function pushDebugLines(header, lines)
    local out = {}
    if header and header ~= "" then
        table.insert(out, header)
    end
    for _, line in ipairs(lines or {}) do
        table.insert(out, line)
    end
    updateDebugText(out)
end

local function getRemoteFullName(remote)
    local fullName = ""
    pcall(function()
        fullName = remote:GetFullName()
    end)
    return tostring(fullName or "")
end

local function collectObservedRemoteCandidates(forceRefresh)
    local now = os.clock()
    local scanInterval = _cfg.AUTO_BUY_REMOTE_SCAN_INTERVAL or 30
    if not forceRefresh and (now - _lastRemoteScan) < scanInterval and next(_remoteCandidates) ~= nil then
        return _remoteCandidates
    end

    local keywords = {
        "fruit", "food", "petfood", "shop", "buy", "purchase", "merchant", "stock", "restock", "item",
    }

    local candidates = {}
    local seen = {}
    local containers = {
        game:GetService("ReplicatedStorage"),
        game:GetService("ReplicatedFirst"),
        game:GetService("Workspace"),
    }

    local localPlayer = _svc and _svc.LocalPlayer or nil
    if localPlayer then
        table.insert(containers, localPlayer)
        local playerGui = localPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            table.insert(containers, playerGui)
        end
        local playerScripts = localPlayer:FindFirstChild("PlayerScripts")
        if playerScripts then
            table.insert(containers, playerScripts)
        end
    end

    for _, root in ipairs(containers) do
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                local fullName = getRemoteFullName(obj)
                local sig = normalize(fullName .. " " .. obj.Name)
                for _, kw in ipairs(keywords) do
                    if sig:find(kw, 1, true) then
                        if not seen[fullName] then
                            seen[fullName] = true
                            table.insert(candidates, obj)
                        end
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

local function getObjectLabel(obj)
    if not obj then
        return "?"
    end
    local fullName = getRemoteFullName(obj)
    if fullName ~= "" then
        return fullName
    end
    return tostring(obj.Name or "?")
end

local function buildScannerLines()
    local lines = {}
    local remotes = {}
    -- Limita frequência do scanner pesado
    if (_runtime.LastScan and (os.clock() - _runtime.LastScan) < 2) then
        table.insert(lines, "[SCAN] Aguarde antes de nova varredura pesada.")
        return lines
    end
    _runtime.LastScan = os.clock()

    local remotesOk, remotesResult = pcall(function()
        return collectObservedRemoteCandidates(true)
    end)
    if remotesOk and type(remotesResult) == "table" then
        remotes = remotesResult
    else
        table.insert(lines, "[SCAN-ERR] remotes scanner falhou: " .. tostring(remotesResult))
    end
    table.insert(lines, "[SCAN] remotes candidatos: " .. tostring(#remotes))

    local remoteLimit = math.min(#remotes, 6)
    for i = 1, remoteLimit do
        local remote = remotes[i]
        table.insert(lines, string.format(
            "[REMOTE %02d] %s | %s | score=%s",
            i,
            tostring(remote.ClassName),
            getObjectLabel(remote),
            tostring(scoreRemoteCandidate and scoreRemoteCandidate(remote) or "?")
        ))
    end

    -- Scanner de GUI leve: só conta roots e botões, sem varrer tudo
    local pg = _svc and _svc.LocalPlayer and _svc.LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then
        table.insert(lines, "[GUI] PlayerGui nao encontrado")
        return lines
    end

    local roots = {}
    local seenRoots = {}
    for _, obj in ipairs(pg:GetChildren()) do
        local sig = normalize(obj.Name)
        for _, kw in ipairs(_cfg.FRUIT_SHOP_KEYWORDS or {}) do
            if sig:find(normalize(kw), 1, true) then
                if not seenRoots[obj] then
                    seenRoots[obj] = true
                    table.insert(roots, obj)
                end
                break
            end
        end
    end
    table.insert(lines, "[SCAN] roots da loja (leve): " .. tostring(#roots))
    return lines
end

function AutoBuy.DebugScan(reason)
    return runProtected(reason or "Scanner AutoBuy", function()
        local lines = buildScannerLines()
        local heading = "===== AUTO BUY SCANNER START ====="
        local footer = "===== AUTO BUY SCANNER END ====="
        appendDiagnosticLogLines({heading, unpack(lines), footer})
        pushDebugLines("[SCAN] Resultado no console", {
            lines[1] or "[SCAN] sem dados",
            lines[math.min(2, #lines)] or "",
            lines[math.min(3, #lines)] or "",
        })

        print(heading)
        for _, line in ipairs(lines) do
            print(line)
        end
        print(footer)

        return lines
    end)
end

function AutoBuy.ClearDiagnosticLog()
    return runProtected("Clear diagnostic log", function()
        setDiagnosticLogText("AUTO BUY DIAGNOSTIC LOG\n[INFO] Log limpo.")
        pushDebugLines("[DIAG] Log limpo", {
            "[INFO] Painel de diagnostico resetado",
        })
        return true
    end)
end

function AutoBuy.CopyDiagnosticLog()
    return runProtected("Copy diagnostic log", function()
        local text = tostring(_state.AutoBuyDiagLogText or "")
        local ok = tryCopyToClipboard(text)
        if ok then
            pushDebugLines("[DIAG] Log copiado", {
                "[OK] Conteudo enviado para a area de transferencia",
            })
        else
            pushDebugLines("[DIAG] Copia indisponivel", {
                "[NO] Executor nao expoe setclipboard/toclipboard",
            })
        end
        return ok
    end)
end

local function summarizeObservedRemotePaths(remotes)
    if not remotes or #remotes == 0 then
        return "[DISCOVERY] nenhum candidato observado"
    end

    local parts = {}
    local limit = math.min(#remotes, 2)
    for i = 1, limit do
        local fullName = getRemoteFullName(remotes[i])
        if fullName == "" then
            fullName = remotes[i].Name or "?"
        end
        table.insert(parts, fullName)
    end

    return "[DISCOVERY] " .. table.concat(parts, " | ")
end

local function getApprovedRemoteSpecs()
    return (_cfg and _cfg.AUTO_BUY_REMOTE_ALLOWLIST) or {}
end

local function normalizeClassName(value)
    return tostring(value or ""):gsub("%s+", "")
end

local function remoteMatchesAllowlistSpec(remote, spec)
    if not remote or not spec then return false end

    local fullName = getRemoteFullName(remote)
    local className = remote.ClassName
    if spec.fullName and spec.fullName ~= fullName then
        return false
    end
    if spec.name and tostring(spec.name) ~= tostring(remote.Name) then
        return false
    end
    if spec.className and normalizeClassName(spec.className) ~= normalizeClassName(className) then
        return false
    end

    return fullName ~= ""
end

local function collectApprovedRemotes()
    local specs = getApprovedRemoteSpecs()
    if #specs == 0 then
        _remoteCandidates = {}
        return {}, {}
    end

    local observed = collectObservedRemoteCandidates()

    local approved = {}
    for _, remote in ipairs(observed) do
        for _, spec in ipairs(specs) do
            if remoteMatchesAllowlistSpec(remote, spec) then
                table.insert(approved, {
                    remote = remote,
                    spec = spec,
                })
                break
            end
        end
    end

    return approved, observed
end

local function buildFruitIdentifiers(fruitName)
    local identifiers = {
        display = {},
        path = {},
        compact = {},
        resId = {},
    }

    local seen = {}
    local function add(kind, value)
        local key = kind .. ":" .. tostring(value or "")
        local asString = tostring(value or "")
        if asString ~= "" and not seen[key] then
            seen[key] = true
            table.insert(identifiers[kind], value)
        end
    end

    add("display", fruitName)

    for _, alias in ipairs(collectFruitNamesForMatch(fruitName)) do
        local aliasText = tostring(alias)
        add("path", aliasText)
        add("compact", aliasText:gsub("%s+", ""))
        add("compact", aliasText:gsub("%s+", "_") )
        add("compact", aliasText:gsub("%s+", "-") )
    end

    local info = _cfg and _cfg.FRUIT_CANONICAL and _cfg.FRUIT_CANONICAL[fruitName]
    if info and info.resId ~= nil then
        add("resId", info.resId)
        add("resId", tostring(info.resId))
    end

    return identifiers
end

local function buildArgVariantsForSpec(fruitName, amount, spec)
    local identifiers = buildFruitIdentifiers(fruitName)
    local identifierKinds = spec.identifiers or {"display", "path", "compact", "resId"}
    local layouts = spec.layouts or {"name", "name_amount"}
    local verbs = spec.verbs or {"Buy", "Purchase"}
    local category = spec.category or "Fruit"
    local variants = {}
    local seen = {}

    local function addArgs(...)
        local args = {...}
        local parts = {}
        for i = 1, #args do
            parts[i] = tostring(args[i])
        end
        local key = table.concat(parts, "|")
        if not seen[key] then
            seen[key] = true
            table.insert(variants, args)
        end
    end

    for _, kind in ipairs(identifierKinds) do
        for _, value in ipairs(identifiers[kind] or {}) do
            for _, layout in ipairs(layouts) do
                if layout == "name" then
                    addArgs(value)
                elseif layout == "name_amount" then
                    addArgs(value, amount)
                elseif layout == "verb_name" then
                    for _, verb in ipairs(verbs) do
                        addArgs(verb, value)
                    end
                elseif layout == "verb_name_amount" then
                    for _, verb in ipairs(verbs) do
                        addArgs(verb, value, amount)
                    end
                elseif layout == "category_name" then
                    addArgs(category, value)
                elseif layout == "category_name_amount" then
                    addArgs(category, value, amount)
                end
            end
        end
    end

    return variants
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

scoreRemoteCandidate = function(remote)
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

collectFruitShopRoots = function(playerGui)
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

collectFruitNamesForMatch = function(fruitName)
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

    -- Bloqueio explícito para RobuxBuyButton
    if nameSig == "robuxbuybutton" or fullNameSig == "robuxbuybutton" then
        return true
    end

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
    -- Aceita 'buybutton' e 'buybotton' (erro comum de digitação)
    local isBuyButton = (nameSig == "buybutton" or nameSig == "buybotton")
    -- Reforço: só aceita botões explicitamente de coin
    if _cfg and _cfg.AUTO_BUY_STRICT_COIN_ONLY == true then
        if not isBuyButton then
            return false
        end
        if textSig ~= "buy" and textSig ~= "purchase" then
            return false
        end
    end

    -- Nunca aceita botões que tenham qualquer menção a robux
    if isRobuxLike(nameSig) or isRobuxLike(textSig) then
        return false
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
        -- Reforço: nunca aceita container com sinais de robux
        if containerHasRobuxSignals(container) then
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

local function invokeRemote(remote, args)
    local ok = false
    local kind = "unknown"
    local result = nil
    -- Proteção: aborta se argumentos sugerirem compra por robux
    for _, v in ipairs(args) do
        if type(v) == "string" and (v:lower():find("robux") or v:lower():find("gamepass") or v:lower():find("devproduct")) then
            setRobuxGuard("tentativa remota suspeita")
            appendDiagnosticLogLines({"[ERR] Argumento bloqueado: ", tostring(v), "Args:", table.concat(args, ", ")})
            return false, "robux-blocked", nil
        end
    end
    appendDiagnosticLogLines({"[DEBUG] Enviando remote:", remote and remote:GetFullName() or "?", "Args:", table.concat(args, ", ")})
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

local function trySilentBuy(targets)
    if next(targets) == nil then return false, false end
    if robuxGuardActive() then return false, false end

    local allowlistSpecs = getApprovedRemoteSpecs()
    if #allowlistSpecs == 0 then
        updateDebugText(buildSilentDebugLines(
            targets,
            nil,
            "[SAFE] Allowlist vazia | [GUI] Hidden mode desativado"
        ))
        return false, false
    end

    local approvedRemotes, observedRemotes = collectApprovedRemotes()
    if #approvedRemotes == 0 then
        updateDebugText(buildSilentDebugLines(
            targets,
            nil,
            "[SAFE] Nenhum remote aprovado | " .. summarizeObservedRemotePaths(observedRemotes)
        ))
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
    local yieldCount = 0
    local targetBatch = collectTargetBatch(targets)
    updateDebugText(buildSilentDebugLines(targets, statusByFruit, "[HIDDEN] Allowlist ativa | " .. summarizeRemoteCandidates(observedRemotes)))

    for _, fruitName in ipairs(targetBatch) do
        local lastSuccess = _runtime.LastPurchaseAttempt[fruitName] or 0
        local lastProbe = _runtime.LastSilentProbe[fruitName] or 0
        local waitWindow = ((now - lastSuccess) < fruitCooldown) and fruitCooldown or probeCooldown
        local lastActivity = math.max(lastSuccess, lastProbe)

        if (now - lastActivity) >= waitWindow then
            local totalCombos = 0
            local variantsByRemote = {}
            for _, entry in ipairs(approvedRemotes) do
                local variants = buildArgVariantsForSpec(fruitName, amount, entry.spec)
                variantsByRemote[#variantsByRemote + 1] = {
                    remote = entry.remote,
                    spec = entry.spec,
                    variants = variants,
                }
                totalCombos = totalCombos + #variants
            end
            statusByFruit[fruitName] = "[TRY] " .. fruitName .. " -> " .. tostring(#approvedRemotes) .. " remotes aprovados / " .. tostring(totalCombos) .. " variantes"

            if totalCombos > 0 then
                local probeIndex = tonumber(_runtime.ProbeIndexByFruit[fruitName]) or 1
                if probeIndex < 1 or probeIndex > totalCombos then
                    probeIndex = 1
                end

                local sent = false
                local fruitHadAttempt = false
                local fruitProbes = math.min(probeBudget, totalCombos)

                for _ = 1, fruitProbes do
                    local cursor = probeIndex
                    local remote = nil
                    local args = nil
                    local spec = nil

                    for _, item in ipairs(variantsByRemote) do
                        if cursor <= #item.variants then
                            remote = item.remote
                            spec = item.spec
                            args = item.variants[cursor]
                            break
                        end
                        cursor = cursor - #item.variants
                    end

                    if not remote or not args then
                        probeIndex = 1
                        break
                    end

                    local ok, kind, result = invokeRemote(remote, args)
                    dismissRobuxModal(false)

                    probeIndex = probeIndex + 1
                    if probeIndex > totalCombos then
                        probeIndex = 1
                    end

                    if kind == "robux-blocked" then
                        statusByFruit[fruitName] = "[ERR] " .. fruitName .. " -> tentativa de compra por robux bloqueada"
                        setRobuxGuard("tentativa remota suspeita")
                        break
                    end

                    if ok then
                        anyAttempt = true
                        fruitHadAttempt = true

                        if kind == "function" and result ~= false and result ~= nil then
                            anyReliableSuccess = true
                            sent = true
                            _runtime.PreferredRemoteByFruit[fruitName] = remote:GetFullName()
                            statusByFruit[fruitName] = "[OK] " .. fruitName .. " -> aprovado: " .. (spec.fullName or remote.Name)
                            break
                        end

                        if kind == "event" then
                            statusByFruit[fruitName] = "[EVENT] " .. fruitName .. " -> aprovado: " .. (spec.fullName or remote.Name)
                            break
                        end
                    end

                    yieldCount = yieldCount + 1
                    if yieldCount % yieldEvery == 0 then
                        task.wait(0.01)
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
                        statusByFruit[fruitName] = "[NO] " .. fruitName .. " -> allowlist nao confirmou compra"
                    end
                end
            else
                statusByFruit[fruitName] = "[NO] " .. fruitName .. " -> nenhuma variante aprovada"
            end
        else
            statusByFruit[fruitName] = "[COOLDOWN] " .. fruitName .. " -> aguardando proxima tentativa"
        end
    end

    updateDebugText(buildSilentDebugLines(targets, statusByFruit, "[HIDDEN] Modo oculto por allowlist"))

    return anyReliableSuccess, anyAttempt
end

local function tryGuiFallback(targets)
    if not (_cfg.AUTO_BUY_ALLOW_GUI_FALLBACK == true) then
        return false
    end
    if robuxGuardActive() then
        updateDebugText({"[ERR] RobuxGuard ativo, fallback GUI bloqueado"})
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
                    task.wait(0.01)
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
        updateDebugText({"Nenhuma fruta disponivel para AutoBuy."})
        return false
    end

    local guiOnly = (_cfg.AUTO_BUY_GUI_ONLY == true)
    if guiOnly then
        updateDebugText({
            "[SAFE] Remote bloqueado",
            "[GUI] Modo coin-only pela esquerda",
        })
        return tryGuiFallback(targets)
    end

    -- Só tenta modo remoto (silent), nunca GUI
    local okSilent = false
    if _cfg.AUTO_BUY_ALLOW_REMOTE == true then
        okSilent = trySilentBuy(targets)
        if okSilent then
            return true
        end
    end

    return false
end

function AutoBuy.RunNow(reason)
    return runProtected(reason or "Pulse manual", function()
        return AutoBuy.Pulse()
    end)
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
        LastError = nil,
        ProbeIndexByFruit = {},
        PreferredRemoteByFruit = {},
        NextTargetCursor = 1,
    }
    _runtime = _G.__HOC_RUNTIME.AutoBuy
    _G.HOC_AutoBuyScanner = function()
        return AutoBuy.DebugScan("Scanner global")
    end

    if type(_state.AutoBuyDiagLogText) ~= "string" or _state.AutoBuyDiagLogText == "" then
        _state.AutoBuyDiagLogText = "AUTO BUY DIAGNOSTIC LOG\nPronto para scan."
    end
    if type(_state.AutoBuyDiagLastStamp) ~= "string" or _state.AutoBuyDiagLastStamp == "" then
        _state.AutoBuyDiagLastStamp = getLogTimestamp()
    end

    updateDebugText({
        "[INIT] AutoBuy carregado",
        "[INFO] Aguardando ativacao",
    })
    refreshDiagnosticLogLabel()

    if _runtime.LoopStarted then return end
    _runtime.LoopStarted = true

    task.spawn(function()
        while _G_Running do
            if _G_AutoBuy then
                runProtected("Loop AutoBuy", function()
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

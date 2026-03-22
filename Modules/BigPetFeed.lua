--[[
    BigPetFeed.lua — Alimentação automática de Big Pets de forma silenciosa.

    Modo principal: tenta invocar remotes relevantes sem depender de clique em GUI.
    Fallback opcional: ativa ferramenta de comida equipada (desligado por padrão).
]]

local BigPetFeed = {}

local _svc, _state, _cfg
local _runtime

local _remoteCandidates = {}
local _lastRemoteScan = 0

local function normalize(text)
    return tostring(text or ""):lower():gsub("%s+", "")
end

local function collectSelectedTargets()
    local selected = {}
    for name, active in pairs(_state.SelectedFruits) do
        if active then
            selected[name] = true
        end
    end
    return selected
end

local function collectPetTargets()
    local petsFolder = workspace:FindFirstChild("Pets")
    if not petsFolder then return {} end

    local targets = {}
    local seen = {}

    local function pushIfAny(pet)
        if pet and not seen[pet] then
            seen[pet] = true
            table.insert(targets, pet)
        end
    end

    for _, id in ipairs(_cfg.BIG_PET_IDS or {}) do
        pushIfAny(petsFolder:FindFirstChild(id))
        pushIfAny(petsFolder:FindFirstChild(id, true))
    end

    if #targets == 0 then
        for _, obj in ipairs(petsFolder:GetDescendants()) do
            if obj:IsA("Model") then
                local sig = normalize(obj.Name)
                if sig:find("big", 1, true) and sig:find("pet", 1, true) then
                    pushIfAny(obj)
                end
            end
        end
    end

    return targets
end

local function getPetPivotCFrame(pet)
    if not pet then return nil end

    if pet:IsA("Model") then
        local ok, cf = pcall(function() return pet:GetPivot() end)
        if ok and cf then
            return cf
        end

        local pp = pet.PrimaryPart
        if pp then
            return pp.CFrame
        end

        for _, obj in ipairs(pet:GetDescendants()) do
            if obj:IsA("BasePart") then
                return obj.CFrame
            end
        end
    elseif pet:IsA("BasePart") then
        return pet.CFrame
    end

    return nil
end

local function toolMatchesSelection(toolName, selected)
    if next(selected) == nil then
        return true
    end

    local toolNorm = normalize(toolName)
    for fruitName in pairs(selected) do
        local fruitNorm = normalize(fruitName)
        if toolNorm:find(fruitNorm, 1, true) or fruitNorm:find(toolNorm, 1, true) then
            return true
        end
    end

    return false
end

local function collectInventoryFood(selected)
    local lp = _svc.LocalPlayer
    if not lp then return {} end

    local list = {}
    local seen = {}
    local containers = {
        lp:FindFirstChild("Backpack"),
        lp.Character,
    }

    for _, container in ipairs(containers) do
        if container then
            for _, obj in ipairs(container:GetChildren()) do
                if obj:IsA("Tool") and toolMatchesSelection(obj.Name, selected) and not seen[obj] then
                    seen[obj] = true
                    table.insert(list, obj)
                end
            end
        end
    end

    return list
end

local function findCanonicalByName(name)
    local target = normalize(name)
    local canonical = _cfg and _cfg.FRUIT_CANONICAL or nil
    if not canonical then return nil end

    for key, info in pairs(canonical) do
        if normalize(key) == target then
            return info
        end
        if info.aliases then
            for _, a in ipairs(info.aliases) do
                if normalize(a) == target then
                    return info
                end
            end
        end
    end

    return nil
end

local function collectFoodNames(selected, foods)
    local names = {}
    local seen = {}

    local function addName(n)
        local v = tostring(n or "")
        if v ~= "" and not seen[v] then
            seen[v] = true
            table.insert(names, v)
        end
    end

    for fruitName in pairs(selected) do
        addName(fruitName)

        local info = findCanonicalByName(fruitName)
        if info then
            addName(info.path)
            addName(info.resId)
            for _, a in ipairs(info.aliases or {}) do
                addName(a)
            end
        end
    end

    for _, tool in ipairs(foods or {}) do
        addName(tool.Name)

        local info = findCanonicalByName(tool.Name)
        if info then
            addName(info.path)
            addName(info.resId)
            for _, a in ipairs(info.aliases or {}) do
                addName(a)
            end
        end
    end

    return names
end

local function refreshRemoteCandidates()
    local now = os.clock()
    local scanInterval = _cfg.BIG_PET_FEED_REMOTE_SCAN_INTERVAL or 30

    if (now - _lastRemoteScan) < scanInterval and next(_remoteCandidates) ~= nil then
        return _remoteCandidates
    end

    local keywords = _cfg.BIG_PET_FEED_KEYWORDS or {
        "pet", "big", "feed", "food", "eat", "hunger", "consume", "fruit", "use",
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
                    if sig:find(normalize(kw), 1, true) then
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
    local result = nil
    local kind = "unknown"

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

local function buildArgVariants(pet, tool, itemNameOverride)
    local petId = tostring(pet and pet.Name or "")
    local itemName = tostring(itemNameOverride or (tool and tool.Name) or "")

    local itemNames = {}
    local seen = {}
    local function addItemName(v)
        local s = tostring(v or "")
        if s ~= "" and not seen[s] then
            seen[s] = true
            table.insert(itemNames, s)
        end
    end

    addItemName(itemName)
    local noSpace = itemName:gsub("%s+", "")
    addItemName(noSpace)
    addItemName(itemName:lower())
    addItemName(noSpace:lower())

    local info = findCanonicalByName(itemName)
    if info then
        addItemName(info.path)
        addItemName(info.resId)
        for _, a in ipairs(info.aliases or {}) do
            addItemName(a)
        end
    end

    local variants = {}
    local function addArgs(...)
        table.insert(variants, {...})
    end

    addArgs(pet, tool)
    addArgs(petId, tool)

    for _, iname in ipairs(itemNames) do
        addArgs(petId, iname)
        addArgs(pet, iname)

        addArgs("Feed", pet, iname)
        addArgs("Feed", petId, iname)
        addArgs("FeedPet", pet, iname)
        addArgs("FeedPet", petId, iname)

        addArgs("Use", iname, pet)
        addArgs("Use", iname, petId)
        addArgs("Consume", iname, pet)
        addArgs("Consume", iname, petId)

        addArgs("Pet", "Feed", pet, iname)
        addArgs("Pet", "Feed", petId, iname)
        addArgs("BigPet", "Feed", pet, iname)
        addArgs("BigPet", "Feed", petId, iname)
    end

    return variants
end

local function trySilentFeed()
    local pets = collectPetTargets()
    if #pets == 0 then return false end

    local selected = collectSelectedTargets()
    local foods = collectInventoryFood(selected)
    local foodNames = collectFoodNames(selected, foods)
    if #foods == 0 and #foodNames == 0 then return false end

    local remotes = refreshRemoteCandidates()
    if #remotes == 0 then return false end

    local now = os.clock()
    local cooldown = _cfg.BIG_PET_FEED_PET_COOLDOWN or 6
    local spacing = _cfg.BIG_PET_FEED_REQUEST_SPACING or 0.08
    local anyAttempt = false
    local anyReliableSuccess = false

    for _, pet in ipairs(pets) do
        local key = tostring(pet:GetFullName())
        local last = _runtime.LastFeedAttempt[key] or 0

        if (now - last) >= cooldown then
            local sent = false

            local didLoop = false

            for _, tool in ipairs(foods) do
                for _, itemName in ipairs(foodNames) do
                    local variants = buildArgVariants(pet, tool, itemName)
                    didLoop = true

                    for _, remote in ipairs(remotes) do
                        for _, args in ipairs(variants) do
                            local ok, kind, result = invokeRemote(remote, args)
                            if ok then
                                anyAttempt = true

                                -- RemoteFunction permite inferir sucesso de forma mais confiavel.
                                if kind == "function" and result ~= false and result ~= nil then
                                    anyReliableSuccess = true
                                    sent = true
                                    break
                                end
                            end
                        end
                        if sent then break end
                    end
                    if sent then break end
                end
                if sent then break end
            end

            if (not didLoop) and #foodNames > 0 then
                for _, itemName in ipairs(foodNames) do
                    local variants = buildArgVariants(pet, nil, itemName)

                    for _, remote in ipairs(remotes) do
                        for _, args in ipairs(variants) do
                            local ok, kind, result = invokeRemote(remote, args)
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
                    if sent then break end
                end
            end

            if sent then
                _runtime.LastFeedAttempt[key] = now
                task.wait(spacing)
            elseif anyAttempt then
                _runtime.LastFeedAttempt[key] = now
            end
        end
    end

    return anyReliableSuccess, anyAttempt
end

local function findPetPrompt(pet)
    if not pet then return nil end

    local best = nil
    local bestScore = -999

    for _, obj in ipairs(pet:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local sig = normalize(obj.Name .. " " .. tostring(obj.ActionText) .. " " .. tostring(obj.ObjectText))
            local score = 0
            if sig:find("feed", 1, true) then score = score + 8 end
            if sig:find("food", 1, true) then score = score + 6 end
            if sig:find("pet", 1, true) then score = score + 3 end
            if sig:find("eat", 1, true) then score = score + 3 end
            if score > bestScore then
                best = obj
                bestScore = score
            end
        end
    end

    return best
end

local function findPromptNearPet(pet)
    local petCf = getPetPivotCFrame(pet)
    if not petCf then return nil end

    local best = nil
    local bestDist = math.huge

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local parent = obj.Parent
            local part = parent and parent:IsA("BasePart") and parent or nil
            if part then
                local d = (part.Position - petCf.Position).Magnitude
                if d < bestDist and d <= (_cfg.BIG_PET_FEED_PROMPT_RADIUS or 20) then
                    local sig = normalize(obj.Name .. " " .. tostring(obj.ActionText) .. " " .. tostring(obj.ObjectText))
                    if sig:find("feed", 1, true)
                        or sig:find("food", 1, true)
                        or sig:find("pet", 1, true)
                        or sig:find("eat", 1, true)
                    then
                        best = obj
                        bestDist = d
                    end
                end
            end
        end
    end

    return best
end

local function moveNearPet(pet)
    local lp = _svc.LocalPlayer
    local char = lp and lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local petCf = getPetPivotCFrame(pet)
    if not hrp or not petCf then return false end

    local offset = CFrame.new(0, 0, -(_cfg.BIG_PET_FEED_INTERACT_DISTANCE or 4))
    local target = petCf * offset

    local ok = pcall(function()
        hrp.CFrame = target
    end)

    if ok then
        task.wait(_cfg.BIG_PET_FEED_REQUEST_SPACING or 0.08)
    end

    return ok
end

local function tryPromptFallback(foods)
    if _cfg.BIG_PET_FEED_ALLOW_PROMPT_FALLBACK ~= true then
        return false
    end

    if type(fireproximityprompt) ~= "function" then
        return false
    end

    local lp = _svc.LocalPlayer
    local char = lp and lp.Character
    if not lp or not char then return false end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end

    local pets = collectPetTargets()
    if #pets == 0 then return false end

    local ok = false
    pcall(function()
        for _, pet in ipairs(pets) do
            moveNearPet(pet)

            local food = foods and foods[1]
            if food then
                humanoid:EquipTool(food)
                task.wait(_cfg.BIG_PET_FEED_REQUEST_SPACING or 0.08)
            end

            for _ = 1, (_cfg.BIG_PET_FEED_PROMPT_RETRY or 3) do
                local prompt = findPetPrompt(pet) or findPromptNearPet(pet)
                if prompt then
                    fireproximityprompt(prompt)
                    ok = true
                    task.wait(_cfg.BIG_PET_FEED_REQUEST_SPACING or 0.08)
                end
            end
        end
    end)

    return ok
end

local function tryToolActivateFallback()
    if _cfg.BIG_PET_FEED_ALLOW_TOOL_ACTIVATE_FALLBACK ~= true then
        return false
    end

    local lp = _svc.LocalPlayer
    local char = lp and lp.Character
    if not lp or not char then return false end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end

    local selected = collectSelectedTargets()
    local foods = collectInventoryFood(selected)
    if #foods == 0 then return false end

    local ok = false

    pcall(function()
        for _, tool in ipairs(foods) do
            humanoid:EquipTool(tool)
            task.wait(_cfg.BIG_PET_FEED_REQUEST_SPACING or 0.08)
            tool:Activate()
            ok = true
            task.wait(_cfg.BIG_PET_FEED_REQUEST_SPACING or 0.08)
        end
    end)

    if tryPromptFallback(foods) then
        ok = true
    end

    return ok
end

function BigPetFeed.Pulse()
    local okSilent, hadAttempt = trySilentFeed()
    local forceFallback = (_cfg.BIG_PET_FEED_FORCE_FALLBACK_AFTER_SILENT == true)

    if (not okSilent) and ((not hadAttempt) or forceFallback) then
        tryToolActivateFallback()
    end
end

function BigPetFeed.Init(ctx)
    _svc = ctx.Services
    _state = ctx.State
    _cfg = ctx.Config

    _G.__HOC_RUNTIME = _G.__HOC_RUNTIME or {}
    _G.__HOC_RUNTIME.BigPetFeed = _G.__HOC_RUNTIME.BigPetFeed or {
        LoopStarted = false,
        LastSweep = 0,
        LastFeedAttempt = {},
    }
    _runtime = _G.__HOC_RUNTIME.BigPetFeed

    if _runtime.LoopStarted then return end
    _runtime.LoopStarted = true

    task.spawn(function()
        while _G_Running do
            if _G_BigPetsFeed then
                pcall(function()
                    local now = os.clock()
                    local sweep = _cfg.BIG_PET_FEED_SWEEP or 8
                    if (now - _runtime.LastSweep) >= sweep then
                        _runtime.LastSweep = now
                        BigPetFeed.Pulse()
                    end
                end)
            end

            task.wait(_cfg.BIG_PET_FEED_LOOP_INTERVAL or 1.0)
        end

        _runtime.LoopStarted = false
    end)
end

return BigPetFeed

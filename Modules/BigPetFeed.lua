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
    for _, id in ipairs(_cfg.BIG_PET_IDS or {}) do
        local pet = petsFolder:FindFirstChild(id)
        if pet then
            table.insert(targets, pet)
        end
    end

    return targets
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

local function buildArgVariants(pet, tool)
    local petId = tostring(pet and pet.Name or "")
    local itemName = tostring(tool and tool.Name or "")

    local variants = {
        {pet, tool},
        {petId, itemName},
        {pet, itemName},
        {petId, tool},

        {"Feed", pet, tool},
        {"Feed", petId, itemName},
        {"FeedPet", pet, tool},
        {"FeedPet", petId, itemName},

        {"Use", tool, pet},
        {"Use", itemName, petId},
        {"Consume", tool, pet},
        {"Consume", itemName, petId},

        {"Pet", "Feed", pet, tool},
        {"Pet", "Feed", petId, itemName},
        {"BigPet", "Feed", pet, tool},
        {"BigPet", "Feed", petId, itemName},
    }

    return variants
end

local function trySilentFeed()
    local pets = collectPetTargets()
    if #pets == 0 then return false end

    local selected = collectSelectedTargets()
    local foods = collectInventoryFood(selected)
    if #foods == 0 then return false end

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

            for _, tool in ipairs(foods) do
                local variants = buildArgVariants(pet, tool)

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

    for _, obj in ipairs(pet:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            return obj
        end
    end

    return nil
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

    local food = foods and foods[1]
    if not food then return false end

    local ok = false
    pcall(function()
        humanoid:EquipTool(food)
        task.wait(_cfg.BIG_PET_FEED_REQUEST_SPACING or 0.08)

        for _, pet in ipairs(pets) do
            local prompt = findPetPrompt(pet)
            if prompt then
                fireproximityprompt(prompt)
                ok = true
                task.wait(_cfg.BIG_PET_FEED_REQUEST_SPACING or 0.08)
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

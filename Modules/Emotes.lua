--[[
    Emotes.lua — HOC NOC Zoo Emote Catalog v1.0

    A GUI é criada na Init(ctx) mas **desabilitada** por padrão.
    O botão "EMOTE" na GUI principal chama Emotes.Toggle() para mostrar/esconder.
    Visual unificado com a identidade HOC NOC (fundo escuro, borda RGB, paleta Config).
]]

local Emotes = {}

local emoteGui           -- ScreenGui (criado em Init)
local initialized = false

-- ── Toggle público ────────────────────────────────────────────────────────────
function Emotes.Toggle()
    if emoteGui then
        emoteGui.Enabled = not emoteGui.Enabled
    end
end

function Emotes.IsOpen()
    return emoteGui and emoteGui.Enabled or false
end

-- ── Init ──────────────────────────────────────────────────────────────────────
function Emotes.Init(ctx)
    if initialized then return end
    initialized = true

    local cfg = ctx.Config
    local C   = cfg.Colors  -- paleta centralizada

    -- Serviços
    local Players              = ctx.Services.Players
    local RunService           = ctx.Services.RunService
    local UserInputService     = ctx.Services.UserInputService
    local TweenService         = ctx.Services.TweenService
    local HttpService          = ctx.Services.HttpService
    local CoreGui              = ctx.Services.CoreGui

    local AvatarEditorService  = game:GetService("AvatarEditorService")

    local player    = Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid  = character:WaitForChild("Humanoid")
    local lastPosition = character.PrimaryPart and character.PrimaryPart.Position or Vector3.new()

    player.CharacterAdded:Connect(function(newCharacter)
        character    = newCharacter
        humanoid     = newCharacter:WaitForChild("Humanoid")
        lastPosition = character.PrimaryPart and character.PrimaryPart.Position or Vector3.new()
    end)

    -- ── Screen helper ─────────────────────────────────────────────────────────
    local Screen = workspace.CurrentCamera.ViewportSize

    local function scale(axis, value)
        local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
        local baseWidth, baseHeight = 1920, 1080
        local scaleFactor = isMobile and 2 or 1.5
        if axis == "X" then
            return value * (Screen.X / baseWidth) * scaleFactor
        elseif axis == "Y" then
            return value * (Screen.Y / baseHeight) * scaleFactor
        end
    end

    -- ── Settings ──────────────────────────────────────────────────────────────
    local Settings = {}
    Settings["Stop Emote When Moving"]       = true
    Settings["Fade In"]                      = 0.1
    Settings["Fade Out"]                     = 0.1
    Settings["Weight"]                       = 1
    Settings["Speed"]                        = 1
    Settings["Allow Noclip"]                 = true
    Settings["Time Position"]                = 0
    Settings["Freeze On Finish"]             = false
    Settings["Looped"]                       = true
    Settings["Stop Other Animations On Play"] = true

    -- ── Saved emotes persistence ──────────────────────────────────────────────
    local savedEmotes = {}
    local SAVE_FILE   = "HOC_NOC_Emotes_Saved.json"

    local function loadSavedEmotes()
        local success, data = pcall(function()
            if readfile and isfile and isfile(SAVE_FILE) then
                return HttpService:JSONDecode(readfile(SAVE_FILE))
            end
            return {}
        end)
        if success and type(data) == "table" then
            savedEmotes = data
        else
            savedEmotes = {}
        end
        for _, v in ipairs(savedEmotes) do
            if not v.AnimationId then
                if v.AssetId then
                    v.AnimationId = "rbxassetid://" .. tostring(v.AssetId)
                else
                    v.AnimationId = "rbxassetid://" .. tostring(v.Id)
                end
            end
            if v.Favorite == nil then
                v.Favorite = false
            end
        end
    end

    local function saveEmotesToData()
        pcall(function()
            if writefile then
                writefile(SAVE_FILE, HttpService:JSONEncode(savedEmotes))
            end
        end)
    end

    loadSavedEmotes()

    -- ── Animation loader ──────────────────────────────────────────────────────
    local CurrentTrack = nil

    local function LoadTrack(id)
        if CurrentTrack then
            CurrentTrack:Stop(Settings["Fade Out"])
        end
        local animId
        local ok, result = pcall(function()
            return game:GetObjects("rbxassetid://" .. tostring(id))
        end)
        if ok and result and #result > 0 then
            local anim = result[1]
            if anim:IsA("Animation") then
                animId = anim.AnimationId
            else
                animId = "rbxassetid://" .. tostring(id)
            end
        else
            animId = "rbxassetid://" .. tostring(id)
        end
        local newAnim = Instance.new("Animation")
        newAnim.AnimationId = animId
        local newTrack = humanoid:LoadAnimation(newAnim)
        newTrack.Priority = Enum.AnimationPriority.Action4
        local weight = Settings["Weight"]
        if weight == 0 then weight = 0.001 end
        if Settings["Stop Other Animations On Play"] then
            for _, t in pairs(humanoid.Animator:GetPlayingAnimationTracks()) do
                if t.Priority ~= Enum.AnimationPriority.Action4 then
                    t:Stop()
                end
            end
        end
        newTrack:Play(Settings["Fade In"], weight, Settings["Speed"])
        CurrentTrack = newTrack
        CurrentTrack.TimePosition = math.clamp(Settings["Time Position"], 0, 1) * (CurrentTrack.Length or 1)
        CurrentTrack.Priority = Enum.AnimationPriority.Action4
        CurrentTrack.Looped = Settings["Looped"]
        return newTrack
    end

    -- ── Movement stop ─────────────────────────────────────────────────────────
    RunService.RenderStepped:Connect(function()
        if Settings["Looped"] and CurrentTrack and CurrentTrack.IsPlaying then
            CurrentTrack.Looped = Settings["Looped"]
        end
        if character:FindFirstChild("HumanoidRootPart") then
            local root = character.HumanoidRootPart
            if Settings["Stop Emote When Moving"] and CurrentTrack and CurrentTrack.IsPlaying then
                local moved  = (root.Position - lastPosition).Magnitude > 0.1
                local jumped = humanoid and humanoid:GetState() == Enum.HumanoidStateType.Jumping
                if moved or jumped then
                    CurrentTrack:Stop(Settings["Fade Out"])
                    CurrentTrack = nil
                end
            end
            lastPosition = root.Position
        end
    end)

    -- ── GUI principal ─────────────────────────────────────────────────────────
    local gui = Instance.new("ScreenGui")
    gui.Name = "HOC_NOC_Emotes"
    gui.Parent = CoreGui
    gui.Enabled = false          -- só abre via botão "EMOTE"
    gui.DisplayOrder = 999
    emoteGui = gui

    local function createCorner(parent, cornerRadius)
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, cornerRadius)
        corner.Parent = parent
        return corner
    end

    -- ── Container principal ───────────────────────────────────────────────────
    local mainContainer = Instance.new("Frame")
    mainContainer.Size = UDim2.new(0, scale("X", 600), 0, scale("Y", 400))
    mainContainer.Position = UDim2.new(0.5, -scale("X", 400), 0.5, -scale("Y", 250))
    mainContainer.BackgroundColor3 = C.Dark
    mainContainer.BackgroundTransparency = 0.15
    mainContainer.Active = true
    mainContainer.Draggable = true
    mainContainer.BorderSizePixel = 0
    mainContainer.Parent = gui
    createCorner(mainContainer, 8)

    -- Borda RGB animada (igual o frame principal do HOC NOC)
    local mainStroke = Instance.new("UIStroke", mainContainer)
    mainStroke.Thickness = 2
    mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    task.spawn(function()
        local h = 0
        while _G_Running do
            h = (h + 0.01) % 1
            local ok = pcall(function() mainStroke.Color = Color3.fromHSV(h, 0.8, 1) end)
            if not ok then break end
            task.wait(0.02)
        end
    end)

    -- ── Título ────────────────────────────────────────────────────────────────
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, scale("Y", 36))
    title.BackgroundColor3 = C.DarkMid
    title.BackgroundTransparency = 0.3
    title.Text = "🎭 HOC NOC Emotes 🎭"
    title.TextColor3 = C.White
    title.Font = Enum.Font.GothamBold
    title.TextScaled = true
    title.Parent = mainContainer
    createCorner(title, 8)

    -- Botão fechar no canto
    local closeBtn = Instance.new("TextButton", mainContainer)
    closeBtn.Size = UDim2.new(0, scale("X", 28), 0, scale("Y", 28))
    closeBtn.Position = UDim2.new(1, -scale("X", 32), 0, scale("Y", 4))
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "×"
    closeBtn.TextColor3 = C.White
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextScaled = true
    closeBtn.MouseButton1Click:Connect(function()
        gui.Enabled = false
    end)

    -- ── Tabs ──────────────────────────────────────────────────────────────────
    local catalogTabBtn = Instance.new("TextButton")
    catalogTabBtn.Size = UDim2.new(0.3, 0, 0, scale("Y", 24))
    catalogTabBtn.Position = UDim2.new(0.05, 0, 0, scale("Y", 40))
    catalogTabBtn.BackgroundColor3 = C.Green
    catalogTabBtn.Text = "Catalog"
    catalogTabBtn.TextColor3 = C.White
    catalogTabBtn.Font = Enum.Font.GothamBold
    catalogTabBtn.TextScaled = true
    catalogTabBtn.Parent = mainContainer
    createCorner(catalogTabBtn, 6)

    local savedTabBtn = Instance.new("TextButton")
    savedTabBtn.Size = UDim2.new(0.3, 0, 0, scale("Y", 24))
    savedTabBtn.Position = UDim2.new(0.35, 0, 0, scale("Y", 40))
    savedTabBtn.BackgroundColor3 = C.Gray
    savedTabBtn.Text = "Saved"
    savedTabBtn.TextColor3 = C.White
    savedTabBtn.Font = Enum.Font.GothamBold
    savedTabBtn.TextScaled = true
    savedTabBtn.Parent = mainContainer
    createCorner(savedTabBtn, 6)

    -- ── Divider ───────────────────────────────────────────────────────────────
    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(0, scale("X", 2), 1, -scale("Y", 70))
    divider.Position = UDim2.new(0.6, -scale("X", 1), 0, scale("Y", 70))
    divider.BackgroundColor3 = C.Gray
    divider.Parent = mainContainer
    createCorner(divider, 1)

    -- ── Catalog frame ─────────────────────────────────────────────────────────
    local catalogFrame = Instance.new("Frame")
    catalogFrame.Size = UDim2.new(0.6, -scale("X", 10), 1, -scale("Y", 70))
    catalogFrame.Position = UDim2.new(0, scale("X", 5), 0, scale("Y", 70))
    catalogFrame.BackgroundTransparency = 1
    catalogFrame.Visible = true
    catalogFrame.Parent = mainContainer

    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(0.6, -scale("X", 8), 0, scale("Y", 28))
    searchBox.Position = UDim2.new(0, scale("X", 8), 0, 0)
    searchBox.PlaceholderText = "Search emotes..."
    searchBox.BackgroundColor3 = C.DarkMid
    searchBox.TextColor3 = C.White
    searchBox.PlaceholderColor3 = C.LightGray
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextScaled = true
    searchBox.ClearTextOnFocus = false
    searchBox.Text = ""
    searchBox.Parent = catalogFrame
    createCorner(searchBox, 6)

    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Size = UDim2.new(0.2, -scale("X", 4), 0, scale("Y", 28))
    refreshBtn.Position = UDim2.new(0.6, scale("X", 4), 0, 0)
    refreshBtn.BackgroundColor3 = C.Green
    refreshBtn.Text = "Refresh"
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextScaled = true
    refreshBtn.TextColor3 = C.White
    refreshBtn.Parent = catalogFrame
    createCorner(refreshBtn, 6)

    local sortBtn = Instance.new("TextButton")
    sortBtn.Size = UDim2.new(0.2, -scale("X", 8), 0, scale("Y", 28))
    sortBtn.Position = UDim2.new(0.8, scale("X", 4), 0, 0)
    sortBtn.BackgroundColor3 = C.DarkItem
    sortBtn.Text = "Sort: Relevance"
    sortBtn.Font = Enum.Font.GothamBold
    sortBtn.TextScaled = true
    sortBtn.TextColor3 = C.White
    sortBtn.Parent = catalogFrame
    createCorner(sortBtn, 6)

    -- ── Saved frame ───────────────────────────────────────────────────────────
    local savedFrame = Instance.new("Frame")
    savedFrame.Size = UDim2.new(0.6, -scale("X", 10), 1, -scale("Y", 70))
    savedFrame.Position = UDim2.new(0, scale("X", 5), 0, scale("Y", 70))
    savedFrame.BackgroundTransparency = 1
    savedFrame.Visible = false
    savedFrame.Parent = mainContainer

    local savedSearch = Instance.new("TextBox")
    savedSearch.Size = UDim2.new(1, -scale("X", 16), 0, scale("Y", 28))
    savedSearch.Position = UDim2.new(0, scale("X", 8), 0, 0)
    savedSearch.PlaceholderText = "Search saved..."
    savedSearch.BackgroundColor3 = C.DarkMid
    savedSearch.TextColor3 = C.White
    savedSearch.PlaceholderColor3 = C.LightGray
    savedSearch.Font = Enum.Font.Gotham
    savedSearch.TextScaled = true
    savedSearch.ClearTextOnFocus = false
    savedSearch.Text = ""
    savedSearch.Parent = savedFrame
    createCorner(savedSearch, 6)

    local savedScroll = Instance.new("ScrollingFrame")
    savedScroll.Size = UDim2.new(1, -scale("X", 16), 1, -scale("Y", 40))
    savedScroll.Position = UDim2.new(0, scale("X", 8), 0, scale("Y", 36))
    savedScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    savedScroll.ScrollBarThickness = 4
    savedScroll.ScrollBarImageColor3 = C.Gray
    savedScroll.BackgroundTransparency = 1
    savedScroll.Parent = savedFrame

    local savedEmptyLabel = Instance.new("TextLabel")
    savedEmptyLabel.Size = UDim2.new(1, 0, 0, scale("Y", 36))
    savedEmptyLabel.Position = UDim2.new(0, 0, 0.5, -scale("Y", 18))
    savedEmptyLabel.BackgroundTransparency = 1
    savedEmptyLabel.Text = "No saved emotes yet"
    savedEmptyLabel.TextColor3 = C.LightGray
    savedEmptyLabel.Font = Enum.Font.GothamBold
    savedEmptyLabel.TextScaled = true
    savedEmptyLabel.Visible = false
    savedEmptyLabel.Parent = savedScroll = Instance.new("UIGridLayout")
    savedLayout.CellSize = UDim2.new(0, scale("X", 120), 0, scale("Y", 200))
    savedLayout.CellPadding = UDim2.new(0, scale("X", 8), 0, scale("Y", 8))
    savedLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    savedLayout.Parent = savedScroll

    -- ── Settings panel (right side) ───────────────────────────────────────────
    local settingsFrame = Instance.new("Frame")
    settingsFrame.Size = UDim2.new(0.4, -scale("X", 10), 1, -scale("Y", 70))
    settingsFrame.Position = UDim2.new(0.6, scale("X", 5), 0, scale("Y", 70))
    settingsFrame.BackgroundTransparency = 1
    settingsFrame.Parent = mainContainer

    local settingsTitle = Instance.new("TextLabel")
    settingsTitle.Size = UDim2.new(1, 0, 0, scale("Y", 28))
    settingsTitle.BackgroundTransparency = 1
    settingsTitle.Text = "Settings"
    settingsTitle.TextColor3 = C.White
    settingsTitle.Font = Enum.Font.GothamBold
    settingsTitle.TextScaled = true
    settingsTitle.Parent = settingsFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -scale("X", 20), 1, -scale("Y", 40))
    scrollFrame.Position = UDim2.new(0, scale("X", 10), 0, scale("Y", 30))
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.ScrollBarImageColor3 = C.Gray
    scrollFrame.Parent = settingsFrame

    local function lockX()
        scrollFrame.CanvasPosition = Vector2.new(0, scrollFrame.CanvasPosition.Y)
    end
    scrollFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(lockX)

    local listLayout = Instance.new("UIListLayout", scrollFrame)
    listLayout.Padding = UDim.new(0, 6)
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder

    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
    end)

    local function GetReal(id)
        local ok, obj = pcall(function()
            return game:GetObjects("rbxassetid://" .. tostring(id))
        end)
        if ok and obj and #obj > 0 then
            local anim = obj[1]
            if anim:IsA("Animation") and anim.AnimationId ~= "" then
                return tonumber(anim.AnimationId:match("%d+"))
            end
        end
    end

    Settings._sliders = {}
    Settings._toggles = {}

    -- ── Slider creator ────────────────────────────────────────────────────────
    local function createSlider(name, min, max, default)
        Settings[name] = default or min
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, 0, 0, scale("Y", 65))
        container.BackgroundTransparency = 1
        container.Parent = scrollFrame

        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = C.DarkMid
        bg.Parent = container
        Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.5, -scale("X", 10), 0, scale("Y", 20))
        label.Position = UDim2.new(0, 10, 0, 5)
        label.BackgroundTransparency = 1
        label.Text = string.format("%s: %.2f", name, Settings[name])
        label.TextColor3 = C.White
        label.Font = Enum.Font.Gotham
        label.TextScaled = true
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = bg

        local textBox = Instance.new("TextBox")
        textBox.Size = UDim2.new(0.5, -scale("X", 20), 0, scale("Y", 20))
        textBox.Position = UDim2.new(0.5, scale("X", 10), 0, scale("Y", 5))
        textBox.BackgroundColor3 = C.DarkItem
        textBox.Text = tostring(Settings[name])
        textBox.TextColor3 = C.White
        textBox.Font = Enum.Font.Gotham
        textBox.TextScaled = true
        textBox.ClearTextOnFocus = false
        textBox.Parent = bg
        Instance.new("UICorner", textBox).CornerRadius = UDim.new(0, 6)

        local sliderBar = Instance.new("Frame")
        sliderBar.Size = UDim2.new(1, -scale("X", 40), 0, scale("Y", 12))
        sliderBar.Position = UDim2.new(0, scale("X", 20), 0, scale("Y", 35))
        sliderBar.BackgroundColor3 = C.Gray
        sliderBar.Parent = bg
        Instance.new("UICorner", sliderBar).CornerRadius = UDim.new(0, 6)

        local sliderFill = Instance.new("Frame")
        sliderFill.Size = UDim2.new(0, 0, 1, 0)
        sliderFill.BackgroundColor3 = C.Green
        sliderFill.Parent = sliderBar
        Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(0, 6)

        local thumb = Instance.new("Frame")
        thumb.Size = UDim2.new(0, scale("X", 20), 0, scale("Y", 20))
        thumb.AnchorPoint = Vector2.new(0.5, 0.5)
        thumb.Position = UDim2.new(0, 0, 0.5, 0)
        thumb.BackgroundColor3 = C.White
        thumb.Parent = sliderBar
        Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)

        local function tweenVisual(rel)
            local visualRel = math.clamp(rel, 0, 1)
            TweenService:Create(sliderFill, TweenInfo.new(0.15), {Size = UDim2.new(visualRel, 0, 1, 0)}):Play()
            TweenService:Create(thumb, TweenInfo.new(0.15), {Position = UDim2.new(visualRel, 0, 0.5, 0)}):Play()
        end

        local function applyValue(value)
            Settings[name] = math.clamp(value, min, max)
            label.Text = string.format("%s: %.2f", name, Settings[name])
            textBox.Text = tostring(Settings[name])
            local rel = (Settings[name] - min) / (max - min)
            tweenVisual(rel)
            if CurrentTrack and CurrentTrack.IsPlaying then
                if name == "Speed" then
                    CurrentTrack:AdjustSpeed(Settings["Speed"])
                elseif name == "Weight" then
                    local w = Settings["Weight"]
                    if w == 0 then w = 0.001 end
                    CurrentTrack:AdjustWeight(w)
                elseif name == "Time Position" then
                    if CurrentTrack.Length > 0 then
                        CurrentTrack.TimePosition = math.clamp(value, 0, 1) * CurrentTrack.Length
                    end
                end
            end
        end

        local dragging = false
        local function updateFromInput(input)
            local relX = math.clamp((input.Position.X - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X, 0, 1)
            local value = math.floor((min + (max - min) * relX) * 100) / 100
            applyValue(value)
        end

        sliderBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                updateFromInput(input)
            end
        end)

        thumb.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                updateFromInput(input)
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                updateFromInput(input)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                dragging = false
            end
        end)

        textBox.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                local num = tonumber(textBox.Text)
                if num then
                    applyValue(num)
                else
                    textBox.Text = tostring(Settings[name])
                end
            end
        end)

        Settings._sliders[name] = applyValue
        applyValue(Settings[name])
    end

    -- ── Toggle creator ────────────────────────────────────────────────────────
    local function createToggle(name)
        Settings[name] = Settings[name] or false
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, 0, 0, scale("Y", 40))
        container.BackgroundColor3 = C.DarkMid
        container.Parent = scrollFrame
        Instance.new("UICorner", container).CornerRadius = UDim.new(0, 6)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.7, -scale("X", 10), 1, 0)
        label.Position = UDim2.new(0, scale("X", 10), 0, 0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = C.White
        label.Font = Enum.Font.Gotham
        label.TextScaled = true
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = container

        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Size = UDim2.new(0, scale("X", 60), 0, scale("Y", 24))
        toggleBtn.Position = UDim2.new(1, -scale("X", 70), 0.5, -scale("Y", 12))
        toggleBtn.TextColor3 = C.White
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.TextScaled = true
        toggleBtn.Parent = container
        Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)

        local function applyVisual(state)
            toggleBtn.Text = state and "ON" or "OFF"
            toggleBtn.BackgroundColor3 = state and C.Green or C.Red
        end

        toggleBtn.MouseButton1Click:Connect(function()
            Settings[name] = not Settings[name]
            applyVisual(Settings[name])
        end)

        applyVisual(Settings[name])
        Settings._toggles[name] = applyVisual
    end

    function Settings:EditSlider(targetName, newValue)
        local apply = self._sliders[targetName]
        if apply then apply(newValue) end
    end

    function Settings:EditToggle(targetName, newValue)
        local apply = self._toggles[targetName]
        if apply then
            Settings[targetName] = newValue
            apply(newValue)
        end
    end

    local function createButton(name, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, 0, 0, scale("Y", 45))
        container.BackgroundColor3 = C.DarkItem
        container.Parent = scrollFrame
        Instance.new("UICorner", container).CornerRadius = UDim.new(0, 6)

        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, -scale("X", 20), 1, -scale("Y", 10))
        button.Position = UDim2.new(0, scale("X", 10), 0, scale("Y", 5))
        button.BackgroundColor3 = C.Green
        button.Text = name
        button.TextColor3 = C.White
        button.Font = Enum.Font.GothamBold
        button.TextScaled = true
        button.Parent = container
        Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)

        button.MouseButton1Click:Connect(function()
            if typeof(callback) == "function" then callback() end
        end)

        return button
    end

    -- ── Build settings controls ───────────────────────────────────────────────
    local resetButton = createButton("Reset Settings", function() end)
    createToggle("Stop Emote When Moving")
    createToggle("Looped")
    createSlider("Speed", 0, 5, Settings["Speed"])
    createSlider("Time Position", 0, 1, Settings["Time Position"])
    createSlider("Weight", 0, 1, Settings["Weight"])
    createSlider("Fade In", 0, 2, Settings["Fade In"])
    createSlider("Fade Out", 0, 2, Settings["Fade Out"])
    createToggle("Allow Noclip")
    createToggle("Stop Other Animations On Play")

    resetButton.MouseButton1Click:Connect(function()
        Settings:EditToggle("Stop Emote When Moving", true)
        Settings:EditToggle("Stop Other Animations On Play", true)
        Settings:EditSlider("Fade In", 0.1)
        Settings:EditSlider("Fade Out", 0.1)
        Settings:EditSlider("Weight", 1)
        Settings:EditSlider("Speed", 1)
        Settings:EditToggle("Allow Noclip", true)
        Settings:EditSlider("Time Position", 0)
        Settings:EditToggle("Freeze On Finish", false)
        Settings:EditToggle("Looped", true)
    end)

    -- ── Collision fix ─────────────────────────────────────────────────────────
    local originalCollisionStates = {}
    local lastFixClipState = Settings["Allow Noclip"]

    local function saveCollisionStates()
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part ~= character.PrimaryPart then
                originalCollisionStates[part] = part.CanCollide
            end
        end
    end

    local function disableCollisionsExceptRootPart()
        if not Settings["Allow Noclip"] then return end
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part ~= character.PrimaryPart then
                part.CanCollide = false
            end
        end
    end

    local function restoreCollisionStates()
        for part, canCollide in pairs(originalCollisionStates) do
            if part and part.Parent then
                part.CanCollide = canCollide
            end
        end
        originalCollisionStates = {}
    end

    saveCollisionStates()

    local connection
    connection = RunService.Stepped:Connect(function()
        if character and character.Parent then
            local currentFixClip = Settings["Allow Noclip"]
            if lastFixClipState ~= currentFixClip then
                if currentFixClip then
                    saveCollisionStates()
                    disableCollisionsExceptRootPart()
                else
                    restoreCollisionStates()
                end
                lastFixClipState = currentFixClip
            elseif currentFixClip then
                disableCollisionsExceptRootPart()
            end
        else
            restoreCollisionStates()
            if connection then connection:Disconnect() end
        end
    end)

    player.CharacterAdded:Connect(function(newCharacter)
        restoreCollisionStates()
        character = newCharacter
        humanoid = newCharacter:WaitForChild("Humanoid")
        saveCollisionStates()
        lastFixClipState = Settings["Allow Noclip"]
        if connection then connection:Disconnect() end
        connection = RunService.Stepped:Connect(function()
            if character and character.Parent then
                local currentFixClip = Settings["Allow Noclip"]
                if lastFixClipState ~= currentFixClip then
                    if currentFixClip then
                        saveCollisionStates()
                        disableCollisionsExceptRootPart()
                    else
                        restoreCollisionStates()
                    end
                    lastFixClipState = currentFixClip
                elseif currentFixClip then
                    disableCollisionsExceptRootPart()
                end
            else
                restoreCollisionStates()
                if connection then connection:Disconnect() end
            end
        end)
    end)

    -- ── Catalog search ────────────────────────────────────────────────────────
    local sortModes = {
        {Enum.CatalogSortType.Relevance, "Relevance"},
        {Enum.CatalogSortType.PriceHighToLow, "Price High→Low"},
        {Enum.CatalogSortType.PriceLowToHigh, "Price Low→High"},
        {Enum.CatalogSortType.MostFavorited, "Most Favorited"},
        {Enum.CatalogSortType.RecentlyCreated, "Recently Created"},
        {Enum.CatalogSortType.Bestselling, "Bestselling"},
    }
    local currentSortIndex  = 1
    local currentKeyword    = ""
    local currentPages      = nil
    local currentPageNumber = 1

    local function getPages(keyword)
        local params = CatalogSearchParams.new()
        params.SearchKeyword = keyword or ""
        params.CategoryFilter = Enum.CatalogCategoryFilter.None
        params.SalesTypeFilter = Enum.SalesTypeFilter.All
        params.AssetTypes = { Enum.AvatarAssetType.EmoteAnimation }
        params.IncludeOffSale = true
        params.SortType = sortModes[currentSortIndex][1]
        params.Limit = 10
        local ok, pages = pcall(function()
            return AvatarEditorService:SearchCatalog(params)
        end)
        if not ok then return nil end
        return pages
    end

    -- ── Catalog card ──────────────────────────────────────────────────────────
    local scroll -- forward declaration

    local function createCard(item)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(0, scale("X", 120), 0, scale("Y", 180))
        card.BackgroundColor3 = C.DarkItem
        createCorner(card, 8)

        local thumbId = item.AssetId or item.Id

        local img = Instance.new("ImageLabel")
        img.Size = UDim2.new(1, -scale("X", 10), 0, scale("Y", 90))
        img.Position = UDim2.new(0, scale("X", 5), 0, scale("Y", 5))
        img.BackgroundTransparency = 1
        img.ScaleType = Enum.ScaleType.Fit
        pcall(function()
            img.Image = "rbxthumb://type=Asset&id=" .. tonumber(thumbId) .. "&w=150&h=150"
        end)
        img.Parent = card
        createCorner(img, 6)

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -scale("X", 10), 0, scale("Y", 28))
        nameLabel.Position = UDim2.new(0, scale("X", 5), 0, scale("Y", 100))
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = item.Name or "Unknown"
        nameLabel.TextScaled = true
        nameLabel.TextWrapped = true
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextColor3 = C.White
        nameLabel.Parent = card

        local url = "https://www.roblox.com/catalog/" .. tonumber(item.Id)
        local copyLinkButton = Instance.new("TextButton")
        copyLinkButton.Parent = card
        copyLinkButton.Size = UDim2.new(0, scale("X", 36), 0, scale("Y", 36))
        copyLinkButton.Position = UDim2.new(1, -scale("X", 42), 0, scale("Y", 5))
        copyLinkButton.BackgroundColor3 = C.DarkMid
        copyLinkButton.Text = "🛒🔗"
        copyLinkButton.Font = Enum.Font.GothamBold
        copyLinkButton.TextScaled = true
        copyLinkButton.TextColor3 = C.White
        copyLinkButton.AutoButtonColor = false
        createCorner(copyLinkButton, 8)

        copyLinkButton.MouseButton1Click:Connect(function()
            pcall(function() setclipboard(url) end)
            copyLinkButton.Text = "✅"
            copyLinkButton.BackgroundColor3 = C.Green
            task.wait(0.7)
            copyLinkButton.Text = "🛒🔗"
            copyLinkButton.BackgroundColor3 = C.DarkMid
        end)

        local playBtn = Instance.new("TextButton")
        playBtn.Size = UDim2.new(0.45, -scale("X", 5), 0, scale("Y", 24))
        playBtn.Position = UDim2.new(0, scale("X", 5), 1, -scale("Y", 29))
        playBtn.BackgroundColor3 = C.Green
        playBtn.Text = "Play"
        playBtn.Font = Enum.Font.GothamBold
        playBtn.TextScaled = true
        playBtn.TextColor3 = C.White
        playBtn.Parent = card
        createCorner(playBtn, 6)
        playBtn.MouseButton1Click:Connect(function() LoadTrack(thumbId) end)

        local saveBtn = Instance.new("TextButton")
        saveBtn.Size = UDim2.new(0.45, -scale("X", 5), 0, scale("Y", 24))
        saveBtn.Position = UDim2.new(0.55, 0, 1, -scale("Y", 29))
        saveBtn.BackgroundColor3 = C.DarkGreen
        saveBtn.Text = "Save"
        saveBtn.Font = Enum.Font.GothamBold
        saveBtn.TextScaled = true
        saveBtn.TextColor3 = C.White
        saveBtn.Parent = card
        createCorner(saveBtn, 6)

        saveBtn.MouseButton1Click:Connect(function()
            local alreadySaved = false
            for _, saved in ipairs(savedEmotes) do
                if saved.Id == item.Id then
                    alreadySaved = true
                    break
                end
            end
            if not alreadySaved then
                local realId = GetReal(thumbId)
                table.insert(savedEmotes, {
                    Id = item.Id,
                    AssetId = thumbId,
                    Name = item.Name or "Unknown",
                    AnimationId = "rbxassetid://" .. tostring(realId or thumbId),
                    Favorite = false
                })
                saveEmotesToData()
                saveBtn.Text = "Saved!"
                saveBtn.BackgroundColor3 = C.Green
                task.wait(1)
                saveBtn.Text = "Save"
                saveBtn.BackgroundColor3 = C.DarkGreen
            else
                saveBtn.Text = "Already"
                task.wait(0.7)
                saveBtn.Text = "Save"
            end
        end)

        return card
    end

    -- ── Catalog scroll ────────────────────────────────────────────────────────
    scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -scale("X", 16), 1, -scale("Y", 100))
    scroll.Position = UDim2.new(0, scale("X", 8), 0, scale("Y", 36))
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = C.Gray
    scroll.BackgroundTransparency = 1
    scroll.Parent = catalogFrame

    local layout = Instance.new("UIGridLayout", scroll)
    layout.CellSize = UDim2.new(0, scale("X", 120), 0, scale("Y", 180))
    layout.CellPadding = UDim2.new(0, scale("X", 8), 0, scale("Y", 8))

    local emptyLabel = Instance.new("TextLabel", scroll)
    emptyLabel.Size = UDim2.new(1, 0, 0, scale("Y", 36))
    emptyLabel.Position = UDim2.new(0, 0, 0.5, -scale("Y", 18))
    emptyLabel.BackgroundTransparency = 1
    emptyLabel.Text = "Nothing here yet — try searching!"
    emptyLabel.TextColor3 = C.LightGray
    emptyLabel.Font = Enum.Font.GothamBold
    emptyLabel.TextScaled = true
    emptyLabel.Visible = false

    -- ── Pagination ────────────────────────────────────────────────────────────
    local prevBtn = Instance.new("TextButton", catalogFrame)
    prevBtn.Size = UDim2.new(0.4, -scale("X", 6), 0, scale("Y", 32))
    prevBtn.Position = UDim2.new(0, scale("X", 4), 1, -scale("Y", 36))
    prevBtn.BackgroundColor3 = C.Gray
    prevBtn.Text = "< Prev"
    prevBtn.Font = Enum.Font.GothamBold
    prevBtn.TextScaled = true
    prevBtn.TextColor3 = C.White
    createCorner(prevBtn, 6)

    local nextBtn = Instance.new("TextButton", catalogFrame)
    nextBtn.Size = UDim2.new(0.4, -scale("X", 6), 0, scale("Y", 32))
    nextBtn.Position = UDim2.new(0.6, scale("X", 2), 1, -scale("Y", 36))
    nextBtn.BackgroundColor3 = C.Gray
    nextBtn.Text = "Next >"
    nextBtn.Font = Enum.Font.GothamBold
    nextBtn.TextScaled = true
    nextBtn.TextColor3 = C.White
    createCorner(nextBtn, 6)

    local pageBox = Instance.new("TextBox", catalogFrame)
    pageBox.Size = UDim2.new(0.2, 0, 0, scale("Y", 32))
    pageBox.Position = UDim2.new(0.4, scale("X", 2), 1, -scale("Y", 36))
    pageBox.BackgroundTransparency = 1
    pageBox.Font = Enum.Font.Gotham
    pageBox.TextScaled = true
    pageBox.TextColor3 = C.White
    pageBox.Text = "1 / Enter page"

    local pageNotif = Instance.new("TextLabel", catalogFrame)
    pageNotif.Size = UDim2.new(0.3, 0, 0, scale("Y", 24))
    pageNotif.Position = UDim2.new(0.35, 0, 1, -scale("Y", 68))
    pageNotif.BackgroundTransparency = 1
    pageNotif.TextColor3 = C.Red
    pageNotif.Font = Enum.Font.Gotham
    pageNotif.TextScaled = true
    pageNotif.Text = ""
    pageNotif.Visible = false

    local function updateNavVisibility()
        prevBtn.Visible = (currentPageNumber > 1)
        if currentPages and typeof(currentPages.IsFinished) == "boolean" then
            nextBtn.Visible = not currentPages.IsFinished
        else
            nextBtn.Visible = true
        end
    end

    local isLoading = false

    local function showPage(pages)
        if isLoading then return end
        isLoading = true
        pageBox.Text = "Loading..."
        RunService.RenderStepped:Wait()

        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end

        local currentList = nil
        local ok, got = pcall(function() return pages:GetCurrentPage() end)
        if ok then
            currentList = got
        else
            pageBox.Text = "ERROR"
            isLoading = false
            return
        end

        if currentList and #currentList > 0 then
            emptyLabel.Visible = false
            for _, item in ipairs(currentList) do
                createCard(item).Parent = scroll
                RunService.RenderStepped:Wait()
            end
        else
            emptyLabel.Visible = true
        end

        scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
        pageBox.Text = tostring(currentPageNumber) .. " / Enter page"
        updateNavVisibility()
        isLoading = false
    end

    local function fetchPagesTo(targetPage)
        local pages = getPages(currentKeyword)
        if not pages then return nil end
        for i = 2, targetPage do
            if pages.IsFinished then break end
            local ok = pcall(function() pages:AdvanceToNextPageAsync() end)
            if not ok then break end
        end
        return pages
    end

    local function doNewSearch(keyword)
        currentKeyword = keyword or ""
        currentPageNumber = 1
        pageBox.Text = "Loading..."
        currentPages = getPages(currentKeyword)
        if currentPages then showPage(currentPages) end
    end

    refreshBtn.MouseButton1Click:Connect(function() doNewSearch(searchBox.Text) end)

    searchBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then doNewSearch(searchBox.Text) end
    end)

    sortBtn.MouseButton1Click:Connect(function()
        currentSortIndex = currentSortIndex % #sortModes + 1
        sortBtn.Text = "Sort: " .. sortModes[currentSortIndex][2]
        doNewSearch(currentKeyword)
    end)

    local function goNextPage()
        if not currentPages or currentPages.IsFinished then return end
        local ok = pcall(function() currentPages:AdvanceToNextPageAsync() end)
        if ok then
            currentPageNumber = currentPageNumber + 1
            showPage(currentPages)
        else
            local targetPage = currentPageNumber + 1
            local fresh = fetchPagesTo(targetPage)
            if fresh then
                currentPages = fresh
                currentPageNumber = math.min(targetPage, currentPageNumber + 1)
                showPage(currentPages)
            end
        end
    end

    local function goPrevPage()
        if not currentPages or currentPageNumber <= 1 then return end
        local ok = pcall(function() currentPages:AdvanceToPreviousPageAsync() end)
        if ok then
            currentPageNumber = math.max(1, currentPageNumber - 1)
            showPage(currentPages)
        else
            local targetPage = math.max(1, currentPageNumber - 1)
            local fresh = fetchPagesTo(targetPage)
            if fresh then
                currentPages = fresh
                currentPageNumber = targetPage
                showPage(currentPages)
            end
        end
    end

    nextBtn.MouseButton1Click:Connect(goNextPage)
    prevBtn.MouseButton1Click:Connect(goPrevPage)

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.Right then
            goNextPage()
        elseif input.KeyCode == Enum.KeyCode.Left then
            goPrevPage()
        end
    end)

    pageBox.FocusLost:Connect(function(enterPressed)
        if not enterPressed then return end
        local text = pageBox.Text:gsub("%s+", "")
        local num = tonumber(text:match("%d+"))
        if not num or num < 1 then
            pageNotif.Text = "Invalid page number"
            pageNotif.Visible = true
            task.delay(2, function() if pageNotif then pageNotif.Visible = false end end)
            pageBox.Text = "Page " .. tostring(currentPageNumber)
            return
        end
        local targetPage = math.floor(num)
        if targetPage == currentPageNumber then
            pageBox.Text = "Page " .. tostring(currentPageNumber)
            return
        end
        pageBox.Text = "Loading..."
        local ok, pages = pcall(function() return fetchPagesTo(targetPage) end)
        if not ok or not pages then
            pageNotif.Text = "Unable to fetch page"
            pageNotif.Visible = true
            task.delay(2, function() if pageNotif then pageNotif.Visible = false end end)
            pageBox.Text = "Page " .. tostring(currentPageNumber)
            return
        end
        currentPages = pages
        currentPageNumber = math.max(1, targetPage)
        showPage(currentPages)
    end)

    -- ── Tab switching ─────────────────────────────────────────────────────────
    catalogTabBtn.MouseButton1Click:Connect(function()
        catalogFrame.Visible = true
        savedFrame.Visible = false
        catalogTabBtn.BackgroundColor3 = C.Green
        savedTabBtn.BackgroundColor3 = C.Gray
    end)

    -- ── Saved card ────────────────────────────────────────────────────────────
    local refreshSavedTab  -- forward decl

    local function createSavedCard(item)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(0, scale("X", 120), 0, scale("Y", 200))
        card.BackgroundColor3 = C.DarkItem
        createCorner(card, 8)

        local img = Instance.new("ImageLabel")
        img.Size = UDim2.new(1, -scale("X", 10), 0, scale("Y", 90))
        img.Position = UDim2.new(0, scale("X", 5), 0, scale("Y", 5))
        img.BackgroundTransparency = 1
        img.ScaleType = Enum.ScaleType.Fit
        pcall(function()
            img.Image = "rbxthumb://type=Asset&id=" .. tonumber(item.AssetId or item.Id) .. "&w=150&h=150"
        end)
        img.Parent = card
        createCorner(img, 6)

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -scale("X", 10), 0, scale("Y", 28))
        nameLabel.Position = UDim2.new(0, scale("X", 5), 0, scale("Y", 100))
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = item.Name or "Unknown"
        nameLabel.TextScaled = true
        nameLabel.TextWrapped = true
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextColor3 = C.White
        nameLabel.Parent = card

        local playBtn2 = Instance.new("TextButton")
        playBtn2.Size = UDim2.new(0.45, -scale("X", 5), 0, scale("Y", 24))
        playBtn2.Position = UDim2.new(0, scale("X", 5), 1, -scale("Y", 29))
        playBtn2.BackgroundColor3 = C.Green
        playBtn2.Text = "Play"
        playBtn2.Font = Enum.Font.GothamBold
        playBtn2.TextScaled = true
        playBtn2.TextColor3 = C.White
        playBtn2.Parent = card
        createCorner(playBtn2, 6)
        playBtn2.MouseButton1Click:Connect(function() LoadTrack(item.Id) end)

        local removeBtn = Instance.new("TextButton")
        removeBtn.Size = UDim2.new(0.45, -scale("X", 5), 0, scale("Y", 24))
        removeBtn.Position = UDim2.new(0.55, 0, 1, -scale("Y", 29))
        removeBtn.BackgroundColor3 = C.Red
        removeBtn.Text = "Remove"
        removeBtn.Font = Enum.Font.GothamBold
        removeBtn.TextScaled = true
        removeBtn.TextColor3 = C.White
        removeBtn.Parent = card
        createCorner(removeBtn, 6)

        local copyBtn = Instance.new("TextButton")
        copyBtn.Size = UDim2.new(0, scale("X", 40), 0, scale("Y", 24))
        copyBtn.Position = UDim2.new(0.5, -scale("X", 20), 0, scale("Y", 5))
        copyBtn.BackgroundColor3 = C.DarkMid
        copyBtn.Text = "Copy AnimId"
        copyBtn.Font = Enum.Font.GothamBold
        copyBtn.TextScaled = true
        copyBtn.TextColor3 = C.White
        copyBtn.Parent = card
        createCorner(copyBtn, 6)

        copyBtn.MouseButton1Click:Connect(function()
            pcall(function()
                if setclipboard then
                    setclipboard(item.AnimationId:gsub("rbxassetid://", ""))
                end
            end)
            copyBtn.Text = "Copied!"
            task.wait(0.7)
            copyBtn.Text = "Copy AnimId"
        end)

        local favBtn = Instance.new("TextButton")
        favBtn.Size = UDim2.new(0, scale("X", 24), 0, scale("Y", 24))
        favBtn.Position = UDim2.new(1, -scale("X", 30), 0, scale("Y", 5))
        favBtn.Text = item.Favorite and "★" or "☆"
        favBtn.Font = Enum.Font.GothamBold
        favBtn.TextScaled = true
        favBtn.TextColor3 = Color3.fromRGB(255, 200, 0)
        favBtn.BackgroundTransparency = 1
        favBtn.Parent = card
        favBtn.MouseButton1Click:Connect(function()
            item.Favorite = not item.Favorite
            favBtn.Text = item.Favorite and "★" or "☆"
            saveEmotesToData()
        end)

        removeBtn.MouseButton1Click:Connect(function()
            for i, saved in ipairs(savedEmotes) do
                if saved.Id == item.Id then
                    table.remove(savedEmotes, i)
                    saveEmotesToData()
                    refreshSavedTab()
                    break
                end
            end
        end)

        return card
    end

    refreshSavedTab = function()
        for _, child in ipairs(savedScroll:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        local text = (savedSearch.Text or ""):lower()
        local results = {}
        for _, item in ipairs(savedEmotes) do
            if text == "" or (item.Name and item.Name:lower():find(text)) then
                table.insert(results, item)
            end
        end
        table.sort(results, function(a, b)
            if a.Favorite ~= b.Favorite then return a.Favorite end
            return false
        end)
        if #results > 0 then
            savedEmptyLabel.Visible = false
            for _, item in ipairs(results) do
                createSavedCard(item).Parent = savedScroll
            end
        else
            savedEmptyLabel.Visible = true
        end
        savedScroll.CanvasSize = UDim2.new(0, 0, 0, savedLayout.AbsoluteContentSize.Y + 8)
    end

    savedSearch:GetPropertyChangedSignal("Text"):Connect(refreshSavedTab)

    savedTabBtn.MouseButton1Click:Connect(function()
        catalogFrame.Visible = false
        savedFrame.Visible = true
        catalogTabBtn.BackgroundColor3 = C.Gray
        savedTabBtn.BackgroundColor3 = C.Green
        refreshSavedTab()
    end)

    -- ── Initial catalog load ──────────────────────────────────────────────────
    doNewSearch("")
    refreshSavedTab()
end -- fim de Init

return Emotes

--[[
    MusicPlayer.lua — Player de música local no canto inferior direito.
    Reproduz uma track em loop e oferece botão play/pause.
]]

local MusicPlayer = {}

local DEFAULT_SOUND_ID = "rbxassetid://118831562153998"
local FALLBACK_SOUND_ID = "rbxassetid://184491970"
local TRACK_NAME = "HOC Startup Track"

local function safeParent(gui, svc)
    if not gui or not svc then
        return
    end

    local parent = svc.CoreGui
    local ok = pcall(function()
        gui.Parent = parent
    end)

    if not ok or not gui.Parent then
        local playerGui = svc.LocalPlayer and svc.LocalPlayer:FindFirstChild("PlayerGui")
        if not playerGui and svc.LocalPlayer then
            playerGui = svc.LocalPlayer:WaitForChild("PlayerGui", 5)
        end
        if playerGui then
            pcall(function()
                gui.Parent = playerGui
            end)
        end
    end
end

local function normalizeSoundId(value)
    if type(value) ~= "string" then
        return nil
    end
    local trimmed = value:match("^%s*(.-)%s*$")
    if trimmed == "" then
        return nil
    end
    local id = trimmed:match("^rbxassetid://(%d+)$") or trimmed:match("^(%d+)$")
    if id then
        return "rbxassetid://" .. id
    end
    return nil
end

local function createPlayerGui(svc)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HOC_MusicPlayer"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 10000
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local frame = Instance.new("Frame")
    frame.Name = "MusicPlayerFrame"
    frame.Size = UDim2.new(0, 280, 0, 132)
    frame.Position = UDim2.new(1, -290, 1, -150)
    frame.AnchorPoint = Vector2.new(0, 0)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = screenGui

    local bg = Instance.new("UIStroke")
    bg.Name = "BorderStroke"
    bg.Thickness = 2
    bg.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    bg.Color = Color3.fromRGB(255, 255, 255)
    bg.Transparency = 0.6
    bg.Parent = frame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 18)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Name = "MusicTitle"
    title.Size = UDim2.new(1, -48, 0, 22)
    title.Position = UDim2.new(0, 16, 0, 10)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "HOC Music Player"
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 26, 0, 26)
    closeBtn.Position = UDim2.new(1, -36, 0, 10)
    closeBtn.AnchorPoint = Vector2.new(0, 0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Text = "×"
    closeBtn.Parent = frame

    local track = Instance.new("TextLabel")
    track.Name = "TrackName"
    track.Size = UDim2.new(1, -32, 0, 20)
    track.Position = UDim2.new(0, 16, 0, 36)
    track.BackgroundTransparency = 1
    track.Font = Enum.Font.Gotham
    track.TextSize = 13
    track.TextColor3 = Color3.fromRGB(190, 190, 190)
    track.Text = "Track: " .. TRACK_NAME
    track.TextXAlignment = Enum.TextXAlignment.Left
    track.Parent = frame

    local idInput = Instance.new("TextBox")
    idInput.Name = "SoundIdInput"
    idInput.Size = UDim2.new(1, -100, 0, 28)
    idInput.Position = UDim2.new(0, 16, 0, 64)
    idInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    idInput.BorderSizePixel = 0
    idInput.TextColor3 = Color3.fromRGB(230, 230, 230)
    idInput.Font = Enum.Font.Gotham
    idInput.TextSize = 13
    idInput.PlaceholderText = "Digite o ID do som (1234567)"
    idInput.Text = ""
    idInput.ClearTextOnFocus = false
    idInput.Parent = frame

    local loadButton = Instance.new("TextButton")
    loadButton.Name = "LoadButton"
    loadButton.Size = UDim2.new(0, 72, 0, 28)
    loadButton.Position = UDim2.new(1, -80, 0, 64)
    loadButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    loadButton.BorderSizePixel = 0
    loadButton.Font = Enum.Font.GothamBold
    loadButton.TextSize = 13
    loadButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    loadButton.Text = "Carregar"
    loadButton.Parent = frame

    local button = Instance.new("TextButton")
    button.Name = "ToggleButton"
    button.Size = UDim2.new(0, 80, 0, 28)
    button.Position = UDim2.new(0, 16, 1, -38)
    button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.TextSize = 14
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Text = "Pause"
    button.Parent = frame

    local status = Instance.new("TextLabel")
    status.Name = "StatusLabel"
    status.Size = UDim2.new(0, 120, 0, 22)
    status.Position = UDim2.new(0, 108, 1, -38)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.Gotham
    status.TextSize = 13
    status.TextColor3 = Color3.fromRGB(180, 180, 180)
    status.Text = "Tocando"
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = frame

    safeParent(screenGui, svc)
    return {
        ScreenGui = screenGui,
        Frame = frame,
        ToggleButton = button,
        CloseButton = closeBtn,
        LoadButton = loadButton,
        IdInput = idInput,
        TrackName = track,
        StatusLabel = status,
    }
end

function MusicPlayer.Init(ctx)
    local svc = ctx and ctx.Services
    if not svc then
        return
    end

    local gui = createPlayerGui(svc)
    local soundService = game:GetService("SoundService")
    local sound = Instance.new("Sound")
    sound.Name = "HOC_MusicPlayerSound"
    sound.SoundId = DEFAULT_SOUND_ID
    sound.Volume = 1
    sound.Looped = true
    sound.Parent = soundService

    local playing = false
    local currentId = DEFAULT_SOUND_ID

    local function updateStatus(text, color)
        gui.StatusLabel.Text = text or (playing and "Tocando" or "Pausado")
        if color then
            gui.StatusLabel.TextColor3 = color
        else
            gui.StatusLabel.TextColor3 = playing and Color3.fromRGB(180, 255, 180) or Color3.fromRGB(180, 180, 180)
        end
        gui.ToggleButton.Text = playing and "Pause" or "Play"
    end

    local function resolveId(input)
        local id = normalizeSoundId(input)
        if not id then
            return nil
        end
        return id
    end

    local function applySoundId(soundId)
        if not sound or not sound.Parent or type(soundId) ~= "string" then
            return false
        end
        sound.SoundId = soundId
        gui.TrackName.Text = "Track: " .. tostring(soundId:gsub("rbxassetid://", ""))
        currentId = soundId
        return true
    end

    local function tryPlay(id)
        if not applySoundId(id) then
            return false
        end
        local ok, err = pcall(function()
            sound:Play()
        end)
        if ok then
            return true
        end
        local errStr = tostring(err):lower()
        if errStr:find("not authorized") or errStr:find("not accessible") or errStr:find("invalid asset") or errStr:find("not owned") then
            if id ~= FALLBACK_SOUND_ID then
                sound.SoundId = FALLBACK_SOUND_ID
                gui.TrackName.Text = "Track: fallback"
                pcall(function() sound:Play() end)
                return true
            end
        end
        return false
    end

    local function startSound()
        if not sound or not sound.Parent then
            return
        end
        if tryPlay(currentId) then
            playing = true
            updateStatus("Tocando", Color3.fromRGB(180, 255, 180))
        else
            playing = false
            updateStatus("Falha ao tocar", Color3.fromRGB(255, 120, 120))
        end
    end

    local function stopSound()
        if sound and sound.Parent then
            pcall(function()
                sound:Pause()
            end)
            playing = false
            updateStatus(nil)
        end
    end

    gui.ToggleButton.MouseButton1Click:Connect(function()
        if playing then
            stopSound()
        else
            startSound()
        end
    end)

    gui.CloseButton.MouseButton1Click:Connect(function()
        pcall(function()
            if gui.ScreenGui and gui.ScreenGui.Parent then
                gui.ScreenGui:Destroy()
            end
        end)
        if sound and sound.Parent then
            pcall(function() sound:Destroy() end)
        end
    end)

    gui.LoadButton.MouseButton1Click:Connect(function()
        local soundId = resolveId(gui.IdInput.Text)
        if not soundId then
            updateStatus("ID inválido", Color3.fromRGB(255, 120, 120))
            return
        end
        if tryPlay(soundId) then
            playing = true
            updateStatus("Tocando", Color3.fromRGB(180, 255, 180))
        else
            updateStatus("Falha ao carregar", Color3.fromRGB(255, 120, 120))
        end
    end)

    if sound.IsLoaded then
        startSound()
    else
        sound.Loaded:Connect(function()
            if not playing then
                startSound()
            end
        end)
    end

    return {
        Gui = gui,
        Sound = sound,
        Playing = playing,
    }
end

return MusicPlayer

--[[
    MusicPlayer.lua — Player de música local no canto inferior direito.
    Reproduz uma track em loop e oferece botão play/pause.
]]

local MusicPlayer = {}

local DEFAULT_SOUND_ID = "rbxassetid://118831562153998"
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

local function createPlayerGui(svc)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HOC_MusicPlayer"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 10000
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local frame = Instance.new("Frame")
    frame.Name = "MusicPlayerFrame"
    frame.Size = UDim2.new(0, 240, 0, 96)
    frame.Position = UDim2.new(1, -250, 1, -110)
    frame.AnchorPoint = Vector2.new(0, 0)
    frame.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    frame.BackgroundTransparency = 0.05
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 18)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 2
    stroke.Transparency = 0.6
    stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Name = "MusicTitle"
    title.Size = UDim2.new(1, -20, 0, 22)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "HOC Music Player"
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local track = Instance.new("TextLabel")
    track.Name = "TrackName"
    track.Size = UDim2.new(1, -20, 0, 20)
    track.Position = UDim2.new(0, 10, 0, 34)
    track.BackgroundTransparency = 1
    track.Font = Enum.Font.Gotham
    track.TextSize = 13
    track.TextColor3 = Color3.fromRGB(190, 190, 190)
    track.Text = "Track: " .. TRACK_NAME
    track.TextXAlignment = Enum.TextXAlignment.Left
    track.Parent = frame

    local button = Instance.new("TextButton")
    button.Name = "ToggleButton"
    button.Size = UDim2.new(0, 80, 0, 28)
    button.Position = UDim2.new(0, 10, 1, -38)
    button.AnchorPoint = Vector2.new(0, 0)
    button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.TextSize = 14
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Text = "Pause"
    button.Parent = frame

    local label = Instance.new("TextLabel")
    label.Name = "StatusLabel"
    label.Size = UDim2.new(0, 120, 0, 22)
    label.Position = UDim2.new(0, 102, 1, -38)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(180, 180, 180)
    label.Text = "Tocando"
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    safeParent(screenGui, svc)
    return {
        ScreenGui = screenGui,
        Frame = frame,
        ToggleButton = button,
        StatusLabel = label,
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
    local function updateStatus()
        if playing then
            gui.StatusLabel.Text = "Tocando"
            gui.ToggleButton.Text = "Pause"
        else
            gui.StatusLabel.Text = "Pausado"
            gui.ToggleButton.Text = "Play"
        end
    end

    local function startSound()
        if sound and sound.Parent then
            pcall(function()
                sound:Play()
            end)
            playing = true
            updateStatus()
        end
    end

    local function stopSound()
        if sound and sound.Parent then
            pcall(function()
                sound:Pause()
            end)
            playing = false
            updateStatus()
        end
    end

    gui.ToggleButton.MouseButton1Click:Connect(function()
        if playing then
            stopSound()
        else
            startSound()
        end
    end)

    if sound.IsLoaded then
        startSound()
    else
        sound.Loaded:Connect(startSound)
    end

    return {
        Gui = gui,
        Sound = sound,
        Playing = playing,
    }
end

return MusicPlayer

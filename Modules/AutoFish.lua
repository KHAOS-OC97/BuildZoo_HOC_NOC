-- AutoFish.lua
-- Handles keybind toggle (R), notification, GUI sync and auto click on fishing UI.

local AutoFish = {}
AutoFish.Enabled = false

local DEFAULT_GUI_NAME = "HOC_NOC_ELITE_V6_4"
local CLICK_INTERVAL = 0.006

local _cfg
local _svc
local _runtime

local function getServices()
    local players = game:GetService("Players")
    local userInputService = game:GetService("UserInputService")
    local runService = game:GetService("RunService")
    local starterGui = game:GetService("StarterGui")

    local vim = nil
    pcall(function()
        vim = game:GetService("VirtualInputManager")
    end)

    return {
        Players = players,
        LocalPlayer = players.LocalPlayer,
        UserInputService = userInputService,
        RunService = runService,
        StarterGui = starterGui,
        VirtualInputManager = vim,
    }
end

local function notifyAutoFish(isEnabled)
    local player = _svc.LocalPlayer
    if not player then
        print("[AutoFish] " .. (isEnabled and "AutoFish enabled (R)." or "AutoFish disabled (R)."))
        return
    end

    local guiName = "HOC_NOC_AutoFish_Notify"
    local oldGui = nil

    pcall(function()
        oldGui = game:GetService("CoreGui"):FindFirstChild(guiName)
    end)
    if not oldGui then
        local pg = player:FindFirstChild("PlayerGui")
        if pg then
            oldGui = pg:FindFirstChild(guiName)
        end
    end
    if oldGui then
        pcall(function() oldGui:Destroy() end)
    end

    local sg = Instance.new("ScreenGui")
    sg.Name = guiName
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    pcall(function() sg.Parent = game:GetService("CoreGui") end)
    if not sg.Parent then
        local playerGui = player:FindFirstChild("PlayerGui")
        if playerGui then
            sg.Parent = playerGui
        end
    end

    if not sg.Parent then
        print("[AutoFish] " .. (isEnabled and "AutoFish enabled (R)." or "AutoFish disabled (R)."))
        return
    end

    local frame = Instance.new("Frame", sg)
    frame.AnchorPoint = Vector2.new(0.5, 0)
    frame.Position = UDim2.new(0.5, 0, 0.12, 0)
    frame.Size = UDim2.new(0, 420, 0, 52)
    frame.BackgroundColor3 = isEnabled and Color3.fromRGB(30, 30, 30) or Color3.fromRGB(40, 10, 10)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(255, 0, 0)
    stroke.Thickness = 2

    local rgbRunning = true
    task.spawn(function()
        local t = 0
        while rgbRunning and frame.Parent do
            t = t + task.wait()
            local r = math.floor(math.sin(t * 2) * 127 + 128)
            local g = math.floor(math.sin(t * 2 + 2.094) * 127 + 128)
            local b = math.floor(math.sin(t * 2 + 4.189) * 127 + 128)
            stroke.Color = Color3.fromRGB(r, g, b)
        end
    end)

    local lbl = Instance.new("TextLabel", frame)
    lbl.Size = UDim2.new(1, -30, 1, 0)
    lbl.Position = UDim2.new(0, 15, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 16
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.TextColor3 = isEnabled and Color3.fromRGB(0, 220, 90) or Color3.fromRGB(255, 60, 60)
    lbl.Text = isEnabled and "[AutoFish] ENABLED (R)" or "[AutoFish] DISABLED (R)"

    task.delay(2.6, function()
        rgbRunning = false
        pcall(function()
            local tw = _svc.TweenService or game:GetService("TweenService")
            local ti = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            tw:Create(frame, ti, {BackgroundTransparency = 1}):Play()
            tw:Create(lbl, ti, {TextTransparency = 1}):Play()
            tw:Create(stroke, ti, {Transparency = 1}):Play()
            task.wait(0.7)
            sg:Destroy()
        end)
    end)
end

local function setGuiToggleAutoFish(state)
    local player = _svc.LocalPlayer
    if not player then return end

    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return end

    local guiName = (_cfg and _cfg.GUI_NAME) or DEFAULT_GUI_NAME
    local gui = playerGui:FindFirstChild(guiName)
    if not gui then return end

    local main = gui:FindFirstChild("Main")
    if not main then return end

    for _, frame in ipairs(main:GetChildren()) do
        if frame:IsA("Frame") then
            local label = frame:FindFirstChild("TextLabel")
            if label and label:IsA("TextLabel") and label.Text == "AUTOFISH" then
                local switch = frame:FindFirstChildWhichIsA("TextButton")
                if switch then
                    local isOn = switch.BackgroundColor3.G > 0.3
                    if isOn ~= state then
                        switch:Activate()
                    end
                end
                return
            end
        end
    end
end

local function getFishingButton()
    local player = _svc.LocalPlayer
    if not player then return nil end

    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return nil end

    local screen = playerGui:FindFirstChild("ScreenFishing")
    if not screen then return nil end

    local button = screen:FindFirstChild("Fishing")
    if not button then return nil end
    if button:IsA("GuiObject") and not button.Visible then return nil end

    return button
end

local function clickFishingButton(button)
    local vim = _svc.VirtualInputManager
    if not vim then
        pcall(function() button:Activate() end)
        return
    end

    local center = button.AbsolutePosition + (button.AbsoluteSize / 2)
    local x = math.floor(center.X)
    local y = math.floor(center.Y)

    local ok = pcall(function()
        if vim.SendMouseButtonEvent then
            vim:SendMouseButtonEvent(x, y, 0, true, game, 0)
            vim:SendMouseButtonEvent(x, y, 0, false, game, 0)
        else
            vim:SendMouseButtonDown(x, y, game, 0)
            vim:SendMouseButtonUp(x, y, game, 0)
        end
    end)

    if not ok then
        pcall(function() button:Activate() end)
    end
end

local function updateAutoFishState()
    if _G_AutoFish and not AutoFish.Enabled then
        AutoFish:Start()
    elseif (not _G_AutoFish) and AutoFish.Enabled then
        AutoFish:Stop()
    end
end

local function heartbeatStep()
    if not _G_Running then
        _G_AutoFish = false
        updateAutoFishState()
        return
    end

    updateAutoFishState()
    if not AutoFish.Enabled then return end

    local now = os.clock()
    if (now - _runtime.LastClickAt) < CLICK_INTERVAL then return end
    _runtime.LastClickAt = now

    local button = getFishingButton()
    if not button then return end

    clickFishingButton(button)
end

local function handleInput(input, processed)
    if processed then return end
    if _svc.UserInputService:GetFocusedTextBox() then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode ~= Enum.KeyCode.R then return end

    _G_AutoFish = not _G_AutoFish
    notifyAutoFish(_G_AutoFish)
    setGuiToggleAutoFish(_G_AutoFish)
    updateAutoFishState()
end

function AutoFish:Start()
    if self.Enabled then return end
    self.Enabled = true
    print("[AutoFish] Enabled")
end

function AutoFish:Stop()
    if not self.Enabled then return end
    self.Enabled = false
    print("[AutoFish] Disabled")
end

function AutoFish.Init(ctx)
    _cfg = ctx and ctx.Config or nil
    _svc = (ctx and ctx.Services) or getServices()

    _G.__HOC_RUNTIME = _G.__HOC_RUNTIME or {}
    _G.__HOC_RUNTIME.AutoFish = _G.__HOC_RUNTIME.AutoFish or {
        InputConn = nil,
        HeartbeatConn = nil,
        LastClickAt = 0,
    }
    _runtime = _G.__HOC_RUNTIME.AutoFish

    if _runtime.InputConn then pcall(function() _runtime.InputConn:Disconnect() end) end
    if _runtime.HeartbeatConn then pcall(function() _runtime.HeartbeatConn:Disconnect() end) end

    if _G_AutoFish == nil then _G_AutoFish = false end
    AutoFish.Enabled = false
    _runtime.LastClickAt = 0

    _runtime.InputConn = _svc.UserInputService.InputBegan:Connect(handleInput)
    _runtime.HeartbeatConn = _svc.RunService.Heartbeat:Connect(heartbeatStep)

    updateAutoFishState()
end

return AutoFish

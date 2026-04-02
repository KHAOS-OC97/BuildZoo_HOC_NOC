-- AutoFish.lua
-- Handles keybind toggle (R), notification, GUI sync and auto click on fishing UI.

local AutoFish = {}
AutoFish.Enabled = false

local DEFAULT_GUI_NAME = "HOC_NOC_ELITE_V6_4"
local CLICK_INTERVAL = 0.06

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
    local message = isEnabled and "AutoFish enabled (R)." or "AutoFish disabled (R)."
    local ok = pcall(function()
        _svc.StarterGui:SetCore("SendNotification", {
            Title = "AutoFish",
            Text = message,
            Duration = 2,
        })
    end)

    if not ok then
        print("[AutoFish] " .. message)
    end
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

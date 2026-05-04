--[[
    Toast.lua — Notificações leves na tela.
    Ideal para avisar salvamento, restauração, troca de tema e atalhos.
]]

local Toast = {}

local function safeParent(gui, svc)
    if not gui then return end
    if not svc then return end
    local parent = svc.CoreGui
    local ok = pcall(function() gui.Parent = parent end)
    if not ok or not gui.Parent then
        local playerGui = svc.LocalPlayer and svc.LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            pcall(function() gui.Parent = playerGui end)
        end
    end
end

function Toast.Show(ctx, message, duration)
    duration = tonumber(duration) or 3
    local svc = ctx and ctx.Services
    local cfg = ctx and ctx.Config
    if not svc or not cfg then return end

    local gui = Instance.new("ScreenGui")
    gui.Name = "HOC_NOC_Toast"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 340, 0, 40)
    frame.Position = UDim2.new(0.5, -170, 0.12, 0)
    frame.AnchorPoint = Vector2.new(0, 0)
    frame.BackgroundColor3 = cfg.Colors.DarkMid
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -16, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = tostring(message or "")
    label.TextColor3 = cfg.Colors.White
    label.TextScaled = false
    label.TextSize = 14
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = frame

    safeParent(gui, svc)

    local function fadeOutAndDestroy()
        local tween = svc.TweenService
        local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local goal = {BackgroundTransparency = 1}
        local ok1, _ = pcall(function() tween:Create(frame, info, goal):Play() end)
        local ok2, _ = pcall(function() tween:Create(label, info, {TextTransparency = 1}):Play() end)
        task.wait(0.45)
        pcall(function() gui:Destroy() end)
    end

    task.spawn(function()
        task.wait(duration)
        fadeOutAndDestroy()
    end)

    return gui
end

return Toast

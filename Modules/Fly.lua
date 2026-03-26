--[[
    Fly.lua — Controle de voo livre do jogador.

    Init(ctx)       conecta inputs e o loop de atualização uma única vez.
    Toggle()        ativa/desativa o voo e retorna o estado final.
    IsFlying()      informa se o voo está ativo no momento.
]]

local Fly = {}

local _cfg
local _svc
local _runtime

local ZERO = Vector3.new(0, 0, 0)
local UP = Vector3.new(0, 1, 0)

local function getCharacterParts()
    local player = _svc and _svc.LocalPlayer
    local char = player and player.Character
    if not char then return nil end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return nil end

    return char, hum, root
end

local function clearBodyMovers()
    if not _runtime then return end

    if _runtime.BodyVelocity then
        pcall(function() _runtime.BodyVelocity:Destroy() end)
        _runtime.BodyVelocity = nil
    end

    if _runtime.BodyGyro then
        pcall(function() _runtime.BodyGyro:Destroy() end)
        _runtime.BodyGyro = nil
    end
end

local function setFlightState(hum, enabled)
    if not hum then return end

    pcall(function()
        hum.AutoRotate = not enabled
        hum.PlatformStand = enabled
        hum:ChangeState(enabled and Enum.HumanoidStateType.Physics or Enum.HumanoidStateType.GettingUp)
    end)
end

local function detachFlight()
    local _, hum, root = getCharacterParts()
    clearBodyMovers()

    setFlightState(hum, false)

    if root then
        pcall(function() root.AssemblyLinearVelocity = ZERO end)
    end
end

local function attachFlight(root)
    clearBodyMovers()

    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = "HOCNOC_FlyVelocity"
    bodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bodyVelocity.P = 10000
    bodyVelocity.Velocity = ZERO
    bodyVelocity.Parent = root

    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Name = "HOCNOC_FlyGyro"
    bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    bodyGyro.P = 9000
    bodyGyro.D = 500
    bodyGyro.CFrame = root.CFrame
    bodyGyro.Parent = root

    _runtime.BodyVelocity = bodyVelocity
    _runtime.BodyGyro = bodyGyro
end

local function updateFlight()
    if not _G_Fly then return end

    local _, hum, root = getCharacterParts()
    if not hum or not root then return end

    if not _runtime.BodyVelocity or _runtime.BodyVelocity.Parent ~= root then
        attachFlight(root)
    end

    local camera = workspace.CurrentCamera
    local cameraCFrame = camera and camera.CFrame or root.CFrame

    local flatLook = Vector3.new(cameraCFrame.LookVector.X, 0, cameraCFrame.LookVector.Z)
    local flatRight = Vector3.new(cameraCFrame.RightVector.X, 0, cameraCFrame.RightVector.Z)

    if flatLook.Magnitude > 0 then
        flatLook = flatLook.Unit
    end
    if flatRight.Magnitude > 0 then
        flatRight = flatRight.Unit
    end

    local direction = ZERO

    if _runtime.Keys[Enum.KeyCode.W] then direction = direction + flatLook end
    if _runtime.Keys[Enum.KeyCode.S] then direction = direction - flatLook end
    if _runtime.Keys[Enum.KeyCode.D] then direction = direction + flatRight end
    if _runtime.Keys[Enum.KeyCode.A] then direction = direction - flatRight end
    if _runtime.Keys[Enum.KeyCode.Space] then direction = direction + UP end
    if _runtime.Keys[Enum.KeyCode.LeftShift] then
        direction = direction - UP
    end

    if direction.Magnitude > 0 then
        direction = direction.Unit * (_cfg.FLY_SPEED or 70)
    end

    _runtime.BodyVelocity.Velocity = direction
    _runtime.BodyGyro.CFrame = CFrame.lookAt(root.Position, root.Position + cameraCFrame.LookVector)

    setFlightState(hum, true)
end

function Fly.Init(ctx)
    _cfg = ctx.Config
    _svc = ctx.Services

    _G.__HOC_RUNTIME = _G.__HOC_RUNTIME or {}
    _G.__HOC_RUNTIME.Fly = _G.__HOC_RUNTIME.Fly or {
        HeartbeatConn = nil,
        InputBeganConn = nil,
        InputEndedConn = nil,
        CharConn = nil,
        BodyVelocity = nil,
        BodyGyro = nil,
        Keys = {},
    }
    _runtime = _G.__HOC_RUNTIME.Fly

    if _runtime.HeartbeatConn then pcall(function() _runtime.HeartbeatConn:Disconnect() end) end
    if _runtime.InputBeganConn then pcall(function() _runtime.InputBeganConn:Disconnect() end) end
    if _runtime.InputEndedConn then pcall(function() _runtime.InputEndedConn:Disconnect() end) end
    if _runtime.CharConn then pcall(function() _runtime.CharConn:Disconnect() end) end

    clearBodyMovers()
    _runtime.Keys = {}

    _runtime.InputBeganConn = _svc.UserInputService.InputBegan:Connect(function(input, processed)
        if processed or _svc.UserInputService:GetFocusedTextBox() then return end
        _runtime.Keys[input.KeyCode] = true
    end)

    _runtime.InputEndedConn = _svc.UserInputService.InputEnded:Connect(function(input)
        _runtime.Keys[input.KeyCode] = nil
    end)

    _runtime.HeartbeatConn = _svc.RunService.Heartbeat:Connect(function()
        if not _G_Running then
            if _G_Fly then
                _G_Fly = false
                _runtime.Keys = {}
                detachFlight()
            end
            return
        end

        if _G_Fly then
            updateFlight()
        elseif _runtime.BodyVelocity or _runtime.BodyGyro then
            detachFlight()
        end
    end)

    _runtime.CharConn = _svc.LocalPlayer.CharacterAdded:Connect(function()
        clearBodyMovers()
        _runtime.Keys = {}

        if _G_Fly then
            task.delay(0.15, function()
                if _G_Fly and _G_Running then
                    updateFlight()
                end
            end)
        end
    end)

    if _G_Fly then
        task.defer(updateFlight)
    end
end

function Fly.Toggle()
    _G_Fly = not _G_Fly
    _runtime.Keys = {}

    if _G_Fly then
        updateFlight()
    else
        detachFlight()
    end

    return _G_Fly
end

function Fly.IsFlying()
    return _G_Fly == true
end

return Fly
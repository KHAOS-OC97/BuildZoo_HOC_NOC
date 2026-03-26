--[[
    Fly.lua — Controle de voo livre do jogador.

    Init(ctx)       conecta inputs e o loop de atualização uma única vez.
    Toggle()        ativa/desativa o voo e retorna o estado final.
    IsFlying()      informa se o voo está ativo no momento.
]]

local Fly = {}

local _cfg
local _svc
local _state
local _runtime
local _contextActionService

local ZERO = Vector3.new(0, 0, 0)
local UP = Vector3.new(0, 1, 0)
local TOGGLE_ACTION = "HOCNOC_ToggleFly"

local function syncFlyButton()
    if not _state or not _state.Stored or not _state.Stored.FlyBtn then return end
    _state.Stored.FlyBtn.Text = _G_Fly and "FLY: ON" or "FLY: OFF"
end

local function getCharacterParts()
    local player = _svc and _svc.LocalPlayer
    local char = player and player.Character
    if not char then return nil end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return nil end

    return char, hum, root
end

local function setFlightState(hum, enabled)
    if not hum then return end

    pcall(function()
        hum.AutoRotate = not enabled
        hum.PlatformStand = enabled
        hum:ChangeState(enabled and Enum.HumanoidStateType.Physics or Enum.HumanoidStateType.GettingUp)
    end)
end

local function clearFlightState()
    if not _runtime then return end
    _runtime.Keys = {}
end

local function getVerticalInput()
    local vertical = 0
    if _runtime.Keys[Enum.KeyCode.Space] then vertical = vertical + 1 end
    if _runtime.Keys[Enum.KeyCode.LeftShift] then vertical = vertical - 1 end
    return vertical
end

local function getFlightSpeed()
    local walkSpeed = tonumber(_G_WalkSpeed)
    if walkSpeed and walkSpeed > 0 then
        return walkSpeed * 2
    end

    return _cfg.FLY_SPEED or 70
end

local function getMoveDirection(cameraCFrame)
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

    if direction.Magnitude > 0 then
        direction = direction.Unit
    end

    return direction
end

local function detachFlight()
    local _, hum, root = getCharacterParts()
    setFlightState(hum, false)
    _runtime.Active = false
    _runtime.TargetPosition = nil
    _runtime.HoldY = nil

    if root then
        pcall(function()
            root.AssemblyLinearVelocity = ZERO
            root.AssemblyAngularVelocity = ZERO
        end)
    end
end

local function updateFlight(dt)
    if not _G_Fly then return end

    local char, hum, root = getCharacterParts()
    if not char or not hum or not root then return end

    local camera = workspace.CurrentCamera
    local cameraCFrame = camera and camera.CFrame or root.CFrame

    local horizontalDirection = getMoveDirection(cameraCFrame)
    local verticalInput = getVerticalInput()
    local speed = getFlightSpeed() * math.max(dt or 0.016, 0.016)
    local targetPosition = _runtime.TargetPosition or root.Position
    local holdY = _runtime.HoldY or root.Position.Y
    local nextPosition = targetPosition + (horizontalDirection * speed)
    local facing = Vector3.new(cameraCFrame.LookVector.X, 0, cameraCFrame.LookVector.Z)

    if verticalInput ~= 0 then
        holdY = holdY + (verticalInput * speed)
    end

    nextPosition = Vector3.new(nextPosition.X, holdY, nextPosition.Z)

    if facing.Magnitude <= 0 then
        facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
    end
    if facing.Magnitude <= 0 then
        facing = Vector3.new(0, 0, -1)
    else
        facing = facing.Unit
    end

    setFlightState(hum, true)
    _runtime.Active = true
    _runtime.TargetPosition = nextPosition
    _runtime.HoldY = holdY

    pcall(function()
        root.AssemblyLinearVelocity = ZERO
        root.AssemblyAngularVelocity = ZERO
        char:PivotTo(CFrame.lookAt(nextPosition, nextPosition + facing, UP))
    end)
end

function Fly.Init(ctx)
    _cfg = ctx.Config
    _svc = ctx.Services
    _state = ctx.State
    _contextActionService = game:GetService("ContextActionService")

    _G.__HOC_RUNTIME = _G.__HOC_RUNTIME or {}
    _G.__HOC_RUNTIME.Fly = _G.__HOC_RUNTIME.Fly or {
        HeartbeatConn = nil,
        InputBeganConn = nil,
        InputEndedConn = nil,
        CharConn = nil,
        ToggleBound = false,
        Keys = {},
        Active = false,
        TargetPosition = nil,
        HoldY = nil,
    }
    _runtime = _G.__HOC_RUNTIME.Fly

    if _runtime.HeartbeatConn then pcall(function() _runtime.HeartbeatConn:Disconnect() end) end
    if _runtime.InputBeganConn then pcall(function() _runtime.InputBeganConn:Disconnect() end) end
    if _runtime.InputEndedConn then pcall(function() _runtime.InputEndedConn:Disconnect() end) end
    if _runtime.CharConn then pcall(function() _runtime.CharConn:Disconnect() end) end
    if _runtime.ToggleBound and _contextActionService then
        pcall(function() _contextActionService:UnbindAction(TOGGLE_ACTION) end)
        _runtime.ToggleBound = false
    end

    clearFlightState()
    syncFlyButton()

    if _contextActionService then
        pcall(function()
            _contextActionService:BindActionAtPriority(
                TOGGLE_ACTION,
                function(_, inputState)
                    if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
                    if _svc.UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
                    Fly.Toggle()
                    return Enum.ContextActionResult.Sink
                end,
                false,
                Enum.ContextActionPriority.High.Value,
                Enum.KeyCode.F
            )
            _runtime.ToggleBound = true
        end)
    end

    _runtime.InputBeganConn = _svc.UserInputService.InputBegan:Connect(function(input, processed)
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.F then
            return
        end

        if processed or _svc.UserInputService:GetFocusedTextBox() then return end

        _runtime.Keys[input.KeyCode] = true
    end)

    _runtime.InputEndedConn = _svc.UserInputService.InputEnded:Connect(function(input)
        _runtime.Keys[input.KeyCode] = nil
    end)

    _runtime.HeartbeatConn = _svc.RunService.Heartbeat:Connect(function(dt)
        if not _G_Running then
            if _G_Fly then
                _G_Fly = false
                clearFlightState()
                detachFlight()
                syncFlyButton()
            end
            return
        end

        if _G_Fly then
            updateFlight(dt)
        elseif _runtime.Active then
            detachFlight()
        end
    end)

    _runtime.CharConn = _svc.LocalPlayer.CharacterAdded:Connect(function()
        _runtime.Active = false
        _runtime.TargetPosition = nil
        _runtime.HoldY = nil
        clearFlightState()

        if _G_Fly then
            task.delay(0.15, function()
                if _G_Fly and _G_Running then
                    updateFlight(0.016)
                end
            end)
        end
    end)

    if _G_Fly then
        task.defer(function()
            updateFlight(0.016)
        end)
    end
end

function Fly.Toggle()
    _G_Fly = not _G_Fly
    clearFlightState()
    syncFlyButton()

    if _G_Fly then
        local _, _, root = getCharacterParts()
        _runtime.TargetPosition = root and root.Position or nil
        _runtime.HoldY = root and root.Position.Y or nil
        updateFlight(0.016)
    else
        detachFlight()
    end

    return _G_Fly
end

function Fly.IsFlying()
    return _G_Fly == true
end

return Fly
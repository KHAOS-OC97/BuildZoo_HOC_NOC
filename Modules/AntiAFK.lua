--[[
    AntiAFK.lua — Sistema Anti-AFK com Caixa de Contenção.

    Init(ctx) conecta o evento Idled do LocalPlayer.
    Ping()    é chamado periodicamente pelo loop monitor em Main.lua.
]]

local AntiAFK = {}
local _svc
local _runtime

local function ensureRuntime()
    _G.__HOC_RUNTIME = _G.__HOC_RUNTIME or {}
    _G.__HOC_RUNTIME.AntiAFK = _G.__HOC_RUNTIME.AntiAFK or {
        IdledConn = nil,
        HeartbeatConn = nil,
        WatchdogRunning = false,
        LastPulseAt = 0,
        LastToggleState = false, -- Usado para saber quando criar/destruir a caixa
    }
    _runtime = _G.__HOC_RUNTIME.AntiAFK
end

-- ==========================================
-- SISTEMA DA CAIXA ANTI-AFK
-- ==========================================
local function manageAFKBox(shouldBeActive)
    local boxName = "HOC_AntiAFK_Box"
    local boxFolder = workspace:FindFirstChild(boxName)

    -- Se o Anti-AFK desligou, destruímos a caixa
    if not shouldBeActive then
        if boxFolder then boxFolder:Destroy() end
        return
    end

    -- Se já existe uma caixa, não cria outra
    if boxFolder then return end

    local char = _svc.LocalPlayer and _svc.LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- Criamos a pasta para organizar as paredes
    boxFolder = Instance.new("Folder")
    boxFolder.Name = boxName
    boxFolder.Parent = workspace

    -- Função auxiliar para criar cada parede
    local function createWall(size, offset)
        local part = Instance.new("Part")
        part.Size = size
        part.CFrame = root.CFrame * offset
        part.Anchored = true
        part.CanCollide = true
        part.Transparency = 0.5
        part.Material = Enum.Material.ForceField -- Visual estiloso de campo de força
        part.Color = Color3.fromRGB(0, 255, 255) -- Cor Ciano
        part.CanQuery = false
        part.Parent = boxFolder
    end

    local w, h, t = 5, 7, 1 -- Largura, Altura, Espessura

    createWall(Vector3.new(w, t, w), CFrame.new(0, -h/2, 0)) -- Chão
    createWall(Vector3.new(w, t, w), CFrame.new(0, h/2, 0))  -- Teto
    createWall(Vector3.new(w, h, t), CFrame.new(0, 0, -w/2)) -- Frente
    createWall(Vector3.new(w, h, t), CFrame.new(0, 0, w/2))  -- Trás
    createWall(Vector3.new(t, h, w), CFrame.new(-w/2, 0, 0)) -- Esquerda
    createWall(Vector3.new(t, h, w), CFrame.new(w/2, 0, 0))  -- Direita
end
-- ==========================================

local function now()
    local ok, value = pcall(function()
        return os.clock()
    end)
    return ok and value or 0
end

local function pulseVirtualUser()
    if not _svc.VirtualUser then return end

    pcall(function()
        _svc.VirtualUser:CaptureController()
    end)

    pcall(function()
        _svc.VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)

    pcall(function()
        _svc.VirtualUser:ClickButton1(Vector2.new(0, 0))
    end)

    pcall(function()
        _svc.VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(0.05)
        _svc.VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end)
end

local function pulseVirtualInputManager()
    if not _svc.VirtualInputManager then return end

    pcall(function()
        _svc.VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        _svc.VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)

    pcall(function()
        _svc.VirtualInputManager:SendKeyEvent(true, "W", false, game)
        task.wait(0.05)
        _svc.VirtualInputManager:SendKeyEvent(false, "W", false, game)
    end)
end

local function pulseHumanoid()
    local char = _svc.LocalPlayer and _svc.LocalPlayer.Character
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    pcall(function()
        hum:Move(Vector3.new(0, 0, 1), false)
    end)
    task.wait(0.05)
    pcall(function()
        hum:Move(Vector3.new(0, 0, 0), false)
    end)

    pcall(function()
        hum.Jump = true
    end)

    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        pcall(function()
            root.CFrame = root.CFrame * CFrame.new(0, 0, -0.05)
        end)
    end
end

local function doAntiIdlePulse()
    if not _G_AntiAFK then return end
    if not _svc then return end

    pulseVirtualUser()
    pulseVirtualInputManager()
    pulseHumanoid()

    if _runtime then
        _runtime.LastPulseAt = now()
    end
end

local function bindCurrentCharacter()
    if not _svc or not _svc.LocalPlayer then return end

    local character = _svc.LocalPlayer.Character
    if character then
        task.spawn(function()
            pcall(function()
                character:WaitForChild("Humanoid", 5)
            end)
            if _G_AntiAFK then
                doAntiIdlePulse()
            end
        end)
    end
end

local function ensureHeartbeat()
    if not _svc.RunService then return end

    if _runtime.HeartbeatConn then
        pcall(function() _runtime.HeartbeatConn:Disconnect() end)
    end

    _runtime.HeartbeatConn = _svc.RunService.Heartbeat:Connect(function()
        if not _G_Running or not _G_AntiAFK then return end

        local current = now()
        if current - (_runtime.LastPulseAt or 0) >= 15 then
            doAntiIdlePulse()
        end
    end)
end

function AntiAFK.Init(ctx)
    _svc = ctx.Services
    ensureRuntime()

    if _runtime.IdledConn then
        pcall(function() _runtime.IdledConn:Disconnect() end)
    end

    _runtime.IdledConn = _svc.LocalPlayer.Idled:Connect(function()
        doAntiIdlePulse()
    end)

    -- Heartbeat agora também gerencia a caixa
    if _runtime.HeartbeatConn then
        pcall(function() _runtime.HeartbeatConn:Disconnect() end)
    end
    _runtime.HeartbeatConn = _svc.RunService.Heartbeat:Connect(function()
        if not _G_Running then return end
        -- Verifica se o estado do Anti-AFK mudou para criar/destruir a caixa
        if _runtime.LastToggleState ~= _G_AntiAFK then
            _runtime.LastToggleState = _G_AntiAFK
            manageAFKBox(_G_AntiAFK)
        end
        if not _G_AntiAFK then return end
        local current = now()
        if current - (_runtime.LastPulseAt or 0) >= 15 then
            doAntiIdlePulse()
        end
    end)

    bindCurrentCharacter()

    if not _runtime.WatchdogRunning then
        _runtime.WatchdogRunning = true
        task.spawn(function()
            while _G_Running do
                if _G_AntiAFK then
                    doAntiIdlePulse()
                end
                task.wait(20)
            end
            -- Limpeza quando parar de rodar
            manageAFKBox(false)
            if _runtime and _runtime.HeartbeatConn then
                pcall(function() _runtime.HeartbeatConn:Disconnect() end)
                _runtime.HeartbeatConn = nil
            end
            if _runtime and _runtime.IdledConn then
                pcall(function() _runtime.IdledConn:Disconnect() end)
                _runtime.IdledConn = nil
            end
            _runtime.WatchdogRunning = false
        end)
    end

    if _G_AntiAFK then
        _runtime.LastToggleState = true
        manageAFKBox(true)
        doAntiIdlePulse()
    end
end

-- Chamado pelo monitor a cada ANTI_AFK_INTERVAL segundos
function AntiAFK.Ping()
    doAntiIdlePulse()
end

return AntiAFK

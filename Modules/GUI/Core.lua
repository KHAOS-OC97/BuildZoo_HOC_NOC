--[[
    GUI/Core.lua — Núcleo da interface gráfica.

    Build(ctx) cria o ScreenGui, o frame principal, o título, o botão fechar,
    o atalho CTRL e o loop de cor RGB. Em seguida delega a construção das
    seções internas aos sub-módulos (Toggles, Buttons, FruitMenu) e faz
    o parent/protect final do ScreenGui.

    É seguro chamar Build(ctx) várias vezes: a função detecta se a GUI ainda
    está válida e ignora chamadas redundantes. Ao recriar, limpa referências
    antigas via State.ClearStored().
]]

local GUICore = {}

local function safeParentAndProtect(gui, svc)
    local target = svc.CoreGui
    if type(gethui) == "function" then
        pcall(function() target = gethui() end)
    end

    local parented = pcall(function() gui.Parent = target end)

    -- Alguns executores bloqueiam CoreGui/gethui; fallback para PlayerGui.
    if (not parented) or (not gui.Parent) then
        local playerGui = svc.LocalPlayer and svc.LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            pcall(function() gui.Parent = playerGui end)
        end
    end

    if type(syn) == "table" and type(syn.protect_gui) == "function" then
        pcall(function() syn.protect_gui(gui) end)
    elseif type(protect_gui) == "function" then
        pcall(function() protect_gui(gui) end)
    end
end

function GUICore.Build(ctx)
    local cfg    = ctx.Config
    local state  = ctx.State
    local svc    = ctx.Services
    local stored = state.Stored

    -- Limpa GUI anterior se foi destruída externamente
    if stored.ScreenGui and not stored.ScreenGui.Parent then
        pcall(function() stored.ScreenGui:Destroy() end)
        state.ClearStored()
        stored = state.Stored
    end

    -- Já presente e válida: nada a fazer
    if stored.ScreenGui and stored.ScreenGui.Parent then return end

    -- ── ScreenGui ────────────────────────────────────────────────────────────
    local ScreenGui          = Instance.new("ScreenGui")
    ScreenGui.Name           = cfg.GUI_NAME
    ScreenGui.ResetOnSpawn   = false

    -- ── Frame principal ───────────────────────────────────────────────────────
    local Main                     = Instance.new("Frame")
    Main.Size                      = UDim2.new(0, 230, 0, 526)
    Main.Position                  = UDim2.new(1, -570, 0, 18)
    Main.BackgroundColor3          = cfg.Colors.Dark
    Main.BackgroundTransparency    = 0.4
    Main.BorderSizePixel           = 0
    Main.Active                    = true
    Main.Draggable                 = true
    Main.Parent                    = ScreenGui

    -- Borda RGB do frame principal
    local MainRGB               = Instance.new("UIStroke")
    MainRGB.Thickness           = 2
    MainRGB.ApplyStrokeMode     = Enum.ApplyStrokeMode.Border
    MainRGB.Parent              = Main

    -- Loop de cor RGB — sai automaticamente quando a GUI é destruída
    task.spawn(function()
        local h = 0
        while _G_Running do
            h = (h + 0.01) % 1
            state.GlobalColor = Color3.fromHSV(h, 0.8, 1)
            local ok = pcall(function() MainRGB.Color = state.GlobalColor end)
            if not ok then break end   -- MainRGB destruído: encerra o loop
            task.wait(0.02)
        end
    end)

    -- ── Título ────────────────────────────────────────────────────────────────
    local Title                    = Instance.new("TextLabel", Main)
    Title.Size                     = UDim2.new(1, 0, 0, 30)
    Title.Text                     = cfg.TITLE
    Title.Font                     = Enum.Font.GothamBold
    Title.TextColor3               = cfg.Colors.White
    Title.TextSize                 = 14
    Title.BackgroundTransparency   = 1

    -- ── Botão fechar ──────────────────────────────────────────────────────────
    local Close                    = Instance.new("TextButton", Main)
    Close.Size                     = UDim2.new(0, 20, 0, 20)
    Close.Position                 = UDim2.new(1, -25, 0, 5)
    Close.Text                     = "×"
    Close.TextColor3               = cfg.Colors.White
    Close.BackgroundTransparency   = 1
    Close.Font                     = Enum.Font.GothamBold
    Close.TextSize                 = 16
    Close.MouseButton1Click:Connect(function()
        _G_Running = false
        pcall(function() ScreenGui:Destroy() end)
    end)

    -- ── CTRL → minimizar/restaurar ───────────────────────────────────────────
    -- Armazena a conexão para desconectar ao recriar a GUI
    local ctrlConn = svc.UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.LeftControl then
            Main.Visible = not Main.Visible
        end
    end)
    stored.CtrlConn = ctrlConn

    -- ── Seções internas ───────────────────────────────────────────────────────
    ctx.GUI.Toggles.Build(Main, ctx)
    ctx.GUI.Buttons.Build(Main, ctx)
    ctx.GUI.FruitMenu.Build(Main, ctx)

    -- ── Armazena referências ──────────────────────────────────────────────────
    stored.ScreenGui = ScreenGui
    stored.Main      = Main

    -- ── Parent & protect ──────────────────────────────────────────────────────
    safeParentAndProtect(ScreenGui, svc)

    print("[HOC NOC Zoo] v" .. cfg.VERSION .. " carregado! Eu te amo Lil Girl!!!")
end

return GUICore

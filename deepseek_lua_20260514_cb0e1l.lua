-- ============================================================================
-- FEATURE 17: MODERN GUI (UPGRADED - FIXED MINIMIZE + INFO/ABOUT TABS)
-- ============================================================================

-- Variabel global untuk floating bar
local floatingBar = nil
local isFloatingVisible = false

-- Teks untuk menu Info (font diperkecil agar muat tanpa scroll)
local infoText = [[
CYBERHEROES SCRIPT v10.1
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚡ Fitur:
• Auto Win (finishline + lobby)
• Auto Task (anti-hook + lever gate)
• Auto Generator (full ESP)
• Tpwalk (2x speed + dash)
• Mass Kill (teleport depan)
• Auto Parry (Swort/Parry Dagger)
• God Mode (health regen + stealth)
• Stealth Invisibility (seat method)
• Shield, No Collide, Auto Aim, Skill Check Bypass

📦 Update v10.1:
• Fix teleport depan mass kill
• Minimize GUI ke floating bar
• Menu INFO & ABOUT

👤 Credits: kemi (CyberHeroes)
⚠️ Hanya untuk edukasi & testing pribadi
]]

-- Teks untuk menu About (pendek)
local aboutText = [[
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CYBERHEROES DELTA EXECUTOR v10.1
Script by: kemi
Support: Delta Executor, Synapse X, Krnl
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Terima kasih telah menggunakan script ini.
Gunakan dengan bijak dan bertanggung jawab.
Untuk laporan bug atau saran, hubungi creator.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]]

-- ============================================================================
-- DRAGGABLE (tidak berubah)
-- ============================================================================
local function makeDraggable(frame)
    local dragging = false
    local dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    frame.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                      startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    frame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- ============================================================================
-- THEME UPDATE
-- ============================================================================
local function updateTheme()
    if mainStroke then mainStroke.Color = config.guiThemeColor end
    if sidebar then
        for _, btn in ipairs(sidebar:GetDescendants()) do
            if btn:IsA("TextButton") and btn.Text:find("HOME") then
                btn.TextColor3 = config.guiThemeColor
            end
        end
    end
    if statusLabel then statusLabel.TextColor3 = config.guiThemeColor end
end

-- ============================================================================
-- SETTINGS CONTENT (sama seperti sebelumnya, tidak diubah)
-- ============================================================================
local function createSettingsContent()
    if settingsContent then settingsContent:Destroy() end
    settingsContent = Instance.new("Frame")
    settingsContent.Size = UDim2.new(1, 0, 1, 0)
    settingsContent.BackgroundTransparency = 1
    settingsContent.Parent = contentPanel

    local colorLabel = Instance.new("TextLabel")
    colorLabel.Size = UDim2.new(1, -10, 0, 20)
    colorLabel.Position = UDim2.new(0, 5, 0, 5)
    colorLabel.Text = "THEME COLOR"
    colorLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    colorLabel.BackgroundTransparency = 1
    colorLabel.Font = Enum.Font.GothamBold
    colorLabel.TextSize = 12
    colorLabel.Parent = settingsContent

    local colorRed = Instance.new("TextButton")
    colorRed.Size = UDim2.new(0, 60, 0, 25)
    colorRed.Position = UDim2.new(0.05, 0, 0.1, 0)
    colorRed.Text = "RED"
    colorRed.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    colorRed.TextColor3 = Color3.fromRGB(255, 255, 255)
    colorRed.Font = Enum.Font.GothamBold
    colorRed.TextSize = 10
    colorRed.Parent = settingsContent
    colorRed.MouseButton1Click:Connect(function()
        config.guiThemeColor = Color3.fromRGB(255, 0, 0)
        updateTheme()
    end)

    local colorCyan = Instance.new("TextButton")
    colorCyan.Size = UDim2.new(0, 60, 0, 25)
    colorCyan.Position = UDim2.new(0.35, 0, 0.1, 0)
    colorCyan.Text = "CYAN"
    colorCyan.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
    colorCyan.TextColor3 = Color3.fromRGB(0, 0, 0)
    colorCyan.Font = Enum.Font.GothamBold
    colorCyan.TextSize = 10
    colorCyan.Parent = settingsContent
    colorCyan.MouseButton1Click:Connect(function()
        config.guiThemeColor = Color3.fromRGB(0, 255, 255)
        updateTheme()
    end)

    local colorYellow = Instance.new("TextButton")
    colorYellow.Size = UDim2.new(0, 60, 0, 25)
    colorYellow.Position = UDim2.new(0.65, 0, 0.1, 0)
    colorYellow.Text = "YELLOW"
    colorYellow.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
    colorYellow.TextColor3 = Color3.fromRGB(0, 0, 0)
    colorYellow.Font = Enum.Font.GothamBold
    colorYellow.TextSize = 10
    colorYellow.Parent = settingsContent
    colorYellow.MouseButton1Click:Connect(function()
        config.guiThemeColor = Color3.fromRGB(255, 255, 0)
        updateTheme()
    end)

    local chatLabel = Instance.new("TextLabel")
    chatLabel.Size = UDim2.new(1, -10, 0, 20)
    chatLabel.Position = UDim2.new(0, 5, 0, 0.2)
    chatLabel.Text = "REPORT CHAT"
    chatLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    chatLabel.BackgroundTransparency = 1
    chatLabel.Font = Enum.Font.GothamBold
    chatLabel.TextSize = 12
    chatLabel.Parent = settingsContent

    chatLog = Instance.new("ScrollingFrame")
    chatLog.Size = UDim2.new(0.9, 0, 0, 100)
    chatLog.Position = UDim2.new(0.05, 0, 0.26, 0)
    chatLog.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    chatLog.BackgroundTransparency = 0.3
    chatLog.BorderSizePixel = 0
    chatLog.Parent = settingsContent
    local chatLogCorner = Instance.new("UICorner")
    chatLogCorner.CornerRadius = UDim.new(0, 4)
    chatLogCorner.Parent = chatLog

    local chatListLayout = Instance.new("UIListLayout")
    chatListLayout.Padding = UDim.new(0, 2)
    chatListLayout.Parent = chatLog

    chatInput = Instance.new("TextBox")
    chatInput.Size = UDim2.new(0.7, 0, 0, 25)
    chatInput.Position = UDim2.new(0.05, 0, 0.38, 0)
    chatInput.PlaceholderText = "type report......"
    chatInput.Text = ""
    chatInput.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    chatInput.BackgroundTransparency = 0.3
    chatInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    chatInput.Font = Enum.Font.Gotham
    chatInput.TextSize = 10
    chatInput.BorderSizePixel = 0
    chatInput.Parent = settingsContent
    local chatInputCorner = Instance.new("UICorner")
    chatInputCorner.CornerRadius = UDim.new(0, 4)
    chatInputCorner.Parent = chatInput

    local sendBtn = Instance.new("TextButton")
    sendBtn.Size = UDim2.new(0.18, 0, 0, 25)
    sendBtn.Position = UDim2.new(0.77, 0, 0.38, 0)
    sendBtn.Text = "SEND"
    sendBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    sendBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    sendBtn.Font = Enum.Font.GothamBold
    sendBtn.TextSize = 10
    sendBtn.BorderSizePixel = 0
    sendBtn.Parent = settingsContent
    local sendCorner = Instance.new("UICorner")
    sendCorner.CornerRadius = UDim.new(0, 4)
    sendCorner.Parent = sendBtn

    sendBtn.MouseButton1Click:Connect(function()
        local msg = chatInput.Text
        if msg == "" then return end
        local newMsg = Instance.new("TextLabel")
        newMsg.Size = UDim2.new(1, 0, 0, 16)
        newMsg.Text = "[user] " .. msg
        newMsg.TextColor3 = Color3.fromRGB(200, 200, 200)
        newMsg.BackgroundTransparency = 1
        newMsg.Font = Enum.Font.Gotham
        newMsg.TextSize = 9
        newMsg.TextXAlignment = Enum.TextXAlignment.Left
        newMsg.Parent = chatLog
        chatInput.Text = ""
        chatLog.CanvasSize = UDim2.new(0, 0, 0, chatListLayout.AbsoluteContentSize.Y)
        task.wait(2)
        newMsg:Destroy()
    end)
end

-- ============================================================================
-- INFO CONTENT (tanpa scroll, font kecil)
-- ============================================================================
local infoContent = nil
local function createInfoContent()
    if infoContent then infoContent:Destroy() end
    infoContent = Instance.new("Frame")
    infoContent.Size = UDim2.new(1, 0, 1, 0)
    infoContent.BackgroundTransparency = 1
    infoContent.Parent = contentPanel

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -10, 1, -10)
    textLabel.Position = UDim2.new(0, 5, 0, 5)
    textLabel.Text = infoText
    textLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    textLabel.BackgroundTransparency = 1
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextSize = 8           -- Ukuran lebih kecil agar muat
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.TextYAlignment = Enum.TextYAlignment.Top
    textLabel.TextWrapped = true
    textLabel.Parent = infoContent
end

-- ============================================================================
-- ABOUT CONTENT (baru, tanpa scroll)
-- ============================================================================
local aboutContent = nil
local function createAboutContent()
    if aboutContent then aboutContent:Destroy() end
    aboutContent = Instance.new("Frame")
    aboutContent.Size = UDim2.new(1, 0, 1, 0)
    aboutContent.BackgroundTransparency = 1
    aboutContent.Parent = contentPanel

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -10, 1, -10)
    textLabel.Position = UDim2.new(0, 5, 0, 5)
    textLabel.Text = aboutText
    textLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    textLabel.BackgroundTransparency = 1
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextSize = 10
    textLabel.TextXAlignment = Enum.TextXAlignment.Center
    textLabel.TextYAlignment = Enum.TextYAlignment.Center
    textLabel.TextWrapped = true
    textLabel.Parent = aboutContent
end

-- ============================================================================
-- FLOATING BAR (MINI GUI) - DIPERBAIKI AGAR RESTORE BEKERJA
-- ============================================================================
local function createFloatingBar()
    -- Hapus yang lama jika ada
    if floatingBar then
        pcall(function() floatingBar:Destroy() end)
        floatingBar = nil
    end

    local barGui = Instance.new("ScreenGui")
    barGui.Name = "CyberHeroes_FloatingBar"
    barGui.ResetOnSpawn = false
    barGui.IgnoreGuiInset = true
    barGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    barGui.Parent = CoreGui

    local barFrame = Instance.new("Frame")
    barFrame.Name = "FloatingBar"
    barFrame.Size = UDim2.new(0, 150, 0, 40)
    barFrame.Position = UDim2.new(0.02, 0, 0.08, 0)
    barFrame.BackgroundColor3 = Color3.fromRGB(20, 5, 10)
    barFrame.BackgroundTransparency = 0.2
    barFrame.BorderSizePixel = 0
    barFrame.Parent = barGui

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 8)
    barCorner.Parent = barFrame

    local barStroke = Instance.new("UIStroke")
    barStroke.Color = config.guiThemeColor
    barStroke.Thickness = 1.5
    barStroke.Transparency = 0.4
    barStroke.Parent = barFrame

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(0, 35, 1, 0)
    iconLabel.Position = UDim2.new(0, 5, 0, 0)
    iconLabel.Text = "⚡"
    iconLabel.TextColor3 = config.guiThemeColor
    iconLabel.BackgroundTransparency = 1
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 20
    iconLabel.Parent = barFrame

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -45, 1, 0)
    textLabel.Position = UDim2.new(0, 45, 0, 0)
    textLabel.Text = "CYBERHEROES"
    textLabel.TextColor3 = config.guiThemeColor
    textLabel.BackgroundTransparency = 1
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextSize = 12
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Parent = barFrame

    -- Draggable
    makeDraggable(barFrame)

    -- Klik untuk restore (pastikan mainFrame ada dan visible)
    barFrame.MouseButton1Click:Connect(function()
        if mainFrame then
            mainFrame.Visible = true
            config.guiVisible = true
            barGui:Destroy()
            floatingBar = nil
            isFloatingVisible = false
        end
    end)

    floatingBar = barGui
    return floatingBar
end

-- ============================================================================
-- GUI BUTTONS (sama)
-- ============================================================================
local function createGridButton(parent, name, text, initialState, onChange)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(0, 85, 0, 32)
    button.Text = text .. (initialState and " [ON]" or " [OFF]")
    button.BackgroundColor3 = initialState and Color3.fromRGB(40, 5, 5) or Color3.fromRGB(15, 0, 2)
    button.BackgroundTransparency = 0.1
    button.TextColor3 = initialState and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)
    button.TextSize = 9
    button.Font = Enum.Font.GothamBold
    button.BorderSizePixel = 0
    button.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button
    local stroke = Instance.new("UIStroke")
    stroke.Color = initialState and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(150, 30, 30)
    stroke.Thickness = 1
    stroke.Transparency = 0.3
    stroke.Parent = button
    local function updateState(state)
        button.Text = text .. (state and " [ON]" or " [OFF]")
        button.BackgroundColor3 = state and Color3.fromRGB(40, 5, 5) or Color3.fromRGB(15, 0, 2)
        button.TextColor3 = state and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)
        stroke.Color = state and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(150, 30, 30)
    end
    button.MouseButton1Click:Connect(function()
        local newState = not (config[name] or false)
        if name == "autoWinEnabled" then
            config.autoWinEnabled = newState
            if newState then startAutoWin() else stopAutoWin() end
        elseif name == "autoTaskEnabled" then
            config.autoTaskEnabled = newState
            if newState then startAutoTask() else stopAutoTask() end
        elseif name == "espEnabled" then
            config.espEnabled = newState
            updateAllESP()
        elseif name == "speedBoostEnabled" then
            config.speedBoostEnabled = newState
            if not newState then if localHumanoid then localHumanoid.WalkSpeed = config.originalWalkSpeed end end
        elseif name == "stealthEnabled" then
            config.stealthEnabled = newState
            if newState then startStealthMonitor() else stopStealthMonitor() end
        elseif name == "godModeEnabled" then
            config.godModeEnabled = newState
            if newState then startGodMode() else stopGodMode() end
        elseif name == "infiniteAmmoEnabled" then
            config.infiniteAmmoEnabled = newState
            if newState then startInfiniteAmmo() else stopInfiniteAmmo() end
        elseif name == "shieldEnabled" then
            config.shieldEnabled = newState
            if newState then startShieldMonitor() else stopShieldMonitor() end
        elseif name == "tpwalkEnabled" then
            config.tpwalkEnabled = newState
            if newState then startTpwalkMonitor() else stopTpwalkMonitor() end
        elseif name == "noCollideEnabled" then
            config.noCollideEnabled = newState
            if newState then startNoCollideMonitor() else stopNoCollideMonitor() end
        elseif name == "massKillEnabled" then
            config.massKillEnabled = newState
            if newState then startMassKillLoop() else stopMassKillLoop() end
        elseif name == "autoGeneratorEnabled" then
            config.autoGeneratorEnabled = newState
            if newState then startAutoGeneratorLoop() else stopAutoGeneratorLoop() end
        elseif name == "autoSkillCheckEnabled" then
            config.autoSkillCheckEnabled = newState
            if newState then startAutoSkillCheck() else stopAutoSkillCheck() end
        elseif name == "autoAimEnabled" then
            config.autoAimEnabled = newState
            if newState then startAutoAim() else stopAutoAim() end
        elseif name == "restartScript" then
            restartScript()
            return
        end
        updateState(newState)
        if onChange then onChange(newState) end
        TweenService:Create(button, TweenInfo.new(0.05), {TextSize = 8}):Play()
        task.wait(0.05)
        TweenService:Create(button, TweenInfo.new(0.05), {TextSize = 9}):Play()
    end)
    return button
end

local function createSidebarItem(parent, text, icon, active)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 28)
    button.Text = " " .. icon .. "  " .. text
    button.TextColor3 = active and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)
    button.BackgroundColor3 = active and Color3.fromRGB(40, 5, 5) or Color3.fromRGB(15, 0, 2)
    button.BackgroundTransparency = 0.2
    button.TextSize = 10
    button.Font = Enum.Font.GothamBold
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.BorderSizePixel = 0
    button.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button
    return button
end

-- ============================================================================
-- PERMANENT TELEPORT BUTTON (tidak berubah)
-- ============================================================================
local function createPermanentTeleportButton()
    if teleportButtonGui then teleportButtonGui:Destroy() end
    teleportButtonGui = Instance.new("ScreenGui")
    teleportButtonGui.Name = "CyberHeroes_TeleportButton"
    teleportButtonGui.ResetOnSpawn = false
    teleportButtonGui.Parent = CoreGui
    teleportButton = Instance.new("TextButton")
    teleportButton.Name = "TeleportButton"
    teleportButton.Size = UDim2.new(0, 45, 0, 45)
    teleportButton.Position = UDim2.new(0.02, 0, 0.85, 0)
    teleportButton.Text = "⚡\nTP"
    teleportButton.TextWrapped = true
    teleportButton.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    teleportButton.BackgroundTransparency = 0.2
    teleportButton.TextColor3 = Color3.fromRGB(0, 230, 255)
    teleportButton.TextSize = 14
    teleportButton.Font = Enum.Font.GothamBold
    teleportButton.BorderSizePixel = 0
    teleportButton.Parent = teleportButtonGui
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(1, 0)
    btnCorner.Parent = teleportButton
    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Color3.fromRGB(0, 200, 255)
    btnStroke.Thickness = 1.5
    btnStroke.Transparency = 0.4
    btnStroke.Parent = teleportButton
    teleportButton.MouseButton1Click:Connect(teleportToNearestSurvivor)
    makeDraggable(teleportButton)
end

-- ============================================================================
-- MAIN GUI (dengan minimize ke floating bar, dan perbaikan tombol)
-- ============================================================================
local function createGUI()
    if screenGui then screenGui:Destroy() end
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_GUI"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = CoreGui
    screenGui.ResetOnSpawn = false

    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainWindow"
    mainFrame.Size = UDim2.new(0, 360, 0, 240)
    mainFrame.Position = UDim2.new(0.5, -180, 0.5, -120)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 5, 10)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 8)
    mainCorner.Parent = mainFrame
    mainStroke = Instance.new("UIStroke")
    mainStroke.Color = config.guiThemeColor
    mainStroke.Thickness = 1.5
    mainStroke.Transparency = 0.4
    mainStroke.Parent = mainFrame

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 24)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 3, 7)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = titleBar
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.5, 0, 1, 0)
    title.Position = UDim2.new(0.02, 0, 0, 0)
    title.Text = "CYBERHEROES script by kemi"
    title.TextColor3 = config.guiThemeColor
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    local versionLabel = Instance.new("TextLabel")
    versionLabel.Size = UDim2.new(0.3, 0, 1, 0)
    versionLabel.Position = UDim2.new(0.55, 0, 0, 0)
    versionLabel.Text = "Build 10.1"
    versionLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
    versionLabel.BackgroundTransparency = 1
    versionLabel.Font = Enum.Font.Gotham
    versionLabel.TextSize = 9
    versionLabel.TextXAlignment = Enum.TextXAlignment.Left
    versionLabel.Parent = titleBar

    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 22, 0, 22)
    minimizeBtn.Position = UDim2.new(1, -50, 0, 1)
    minimizeBtn.Text = "−"
    minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    minimizeBtn.BackgroundTransparency = 0.2
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextSize = 18
    minimizeBtn.Parent = titleBar
    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 3)
    minCorner.Parent = minimizeBtn

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 22, 0, 22)
    closeBtn.Position = UDim2.new(1, -26, 0, 1)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.Parent = titleBar
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 3)
    closeCorner.Parent = closeBtn

    -- Fungsi minimize yang benar
    local function minimizeGUI()
        config.guiVisible = false
        if mainFrame then mainFrame.Visible = false end
        -- Buat atau tampilkan floating bar
        if not floatingBar or not floatingBar.Parent then
            createFloatingBar()
        else
            floatingBar.Visible = true
        end
        isFloatingVisible = true
    end

    minimizeBtn.MouseButton1Click:Connect(minimizeGUI)
    closeBtn.MouseButton1Click:Connect(minimizeGUI)

    sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 80, 1, -24)
    sidebar.Position = UDim2.new(0, 0, 0, 24)
    sidebar.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    sidebar.BackgroundTransparency = 0.2
    sidebar.BorderSizePixel = 0
    sidebar.Parent = mainFrame
    local sidebarCorner = Instance.new("UICorner")
    sidebarCorner.CornerRadius = UDim.new(0, 0)
    sidebarCorner.Parent = sidebar
    local sidebarList = Instance.new("Frame")
    sidebarList.Size = UDim2.new(1, 0, 0, 150)
    sidebarList.Position = UDim2.new(0, 0, 0.05, 0)
    sidebarList.BackgroundTransparency = 1
    sidebarList.Parent = sidebar
    local sidebarLayout = Instance.new("UIListLayout")
    sidebarLayout.Padding = UDim.new(0, 4)
    sidebarLayout.FillDirection = Enum.FillDirection.Vertical
    sidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    sidebarLayout.Parent = sidebarList

    local homeItem = createSidebarItem(sidebarList, "HOME", "🏠", true)
    local featuresItem = createSidebarItem(sidebarList, "FEATURES", "⚡", false)
    local settingsItem = createSidebarItem(sidebarList, "SETTINGS", "⚙️", false)
    local infoItem = createSidebarItem(sidebarList, "INFO", "📄", false)
    local aboutItem = createSidebarItem(sidebarList, "ABOUT", "ℹ️", false)
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(0.8, 0, 0, 1)
    sep.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    sep.BackgroundTransparency = 0.7
    sep.Parent = sidebarList

    contentPanel = Instance.new("Frame")
    contentPanel.Size = UDim2.new(1, -90, 1, -30)
    contentPanel.Position = UDim2.new(0, 85, 0, 28)
    contentPanel.BackgroundTransparency = 1
    contentPanel.Parent = mainFrame
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 80, 0, 32)
    gridLayout.CellPadding = UDim2.new(0, 4, 0, 4)
    gridLayout.FillDirection = Enum.FillDirection.Horizontal
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = contentPanel

    local features = {
        {name="autoWinEnabled", text="AUTO WIN"},
        {name="autoTaskEnabled", text="AUTO TASK"},
        {name="espEnabled", text="ESP"},
        {name="speedBoostEnabled", text="SPEED BOOST"},
        {name="stealthEnabled", text="STEALTH"},
        {name="godModeEnabled", text="GOD MODE"},
        {name="infiniteAmmoEnabled", text="INF AMMO"},
        {name="shieldEnabled", text="SHIELD"},
        {name="tpwalkEnabled", text="TPWALK"},
        {name="noCollideEnabled", text="NO COLLIDE"},
        {name="massKillEnabled", text="MASS KILL"},
        {name="autoGeneratorEnabled", text="AUTO GEN"},
        {name="autoSkillCheckEnabled", text="SKILL CHECK"},
        {name="autoAimEnabled", text="AUTO AIM"},
        {name="restartScript", text="RESTART"}
    }
    for _, feat in ipairs(features) do
        local initialState = (feat.name ~= "restartScript") and config[feat.name] or false
        createGridButton(contentPanel, feat.name, feat.text, initialState)
    end

    -- Navigation handlers (dengan destroy konten lain)
    homeItem.MouseButton1Click:Connect(function()
        homeItem.TextColor3 = Color3.fromRGB(0, 230, 255)
        featuresItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        settingsItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        infoItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        aboutItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        if settingsContent then settingsContent:Destroy() end
        if infoContent then infoContent:Destroy() end
        if aboutContent then aboutContent:Destroy() end
        gridLayout.Parent = contentPanel
    end)
    featuresItem.MouseButton1Click:Connect(function()
        featuresItem.TextColor3 = Color3.fromRGB(0, 230, 255)
        homeItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        settingsItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        infoItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        aboutItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        if settingsContent then settingsContent:Destroy() end
        if infoContent then infoContent:Destroy() end
        if aboutContent then aboutContent:Destroy() end
        gridLayout.Parent = contentPanel
    end)
    settingsItem.MouseButton1Click:Connect(function()
        settingsItem.TextColor3 = Color3.fromRGB(0, 230, 255)
        homeItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        featuresItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        infoItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        aboutItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        gridLayout.Parent = nil
        if infoContent then infoContent:Destroy() end
        if aboutContent then aboutContent:Destroy() end
        createSettingsContent()
    end)
    infoItem.MouseButton1Click:Connect(function()
        infoItem.TextColor3 = Color3.fromRGB(0, 230, 255)
        homeItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        featuresItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        settingsItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        aboutItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        gridLayout.Parent = nil
        if settingsContent then settingsContent:Destroy() end
        if aboutContent then aboutContent:Destroy() end
        createInfoContent()
    end)
    aboutItem.MouseButton1Click:Connect(function()
        aboutItem.TextColor3 = Color3.fromRGB(0, 230, 255)
        homeItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        featuresItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        settingsItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        infoItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        gridLayout.Parent = nil
        if settingsContent then settingsContent:Destroy() end
        if infoContent then infoContent:Destroy() end
        createAboutContent()
    end)

    makeDraggable(mainFrame)

    local statusBar = Instance.new("Frame")
    statusBar.Size = UDim2.new(1, 0, 0, 18)
    statusBar.Position = UDim2.new(0, 0, 1, -18)
    statusBar.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    statusBar.BackgroundTransparency = 0.2
    statusBar.BorderSizePixel = 0
    statusBar.Parent = mainFrame
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 4)
    statusCorner.Parent = statusBar
    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -10, 1, 0)
    statusLabel.Position = UDim2.new(0, 5, 0, 0)
    statusLabel.Text = "SYSTEM READY"
    statusLabel.TextColor3 = config.guiThemeColor
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 8
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = statusBar
    local led = Instance.new("Frame")
    led.Size = UDim2.new(0, 5, 0, 5)
    led.Position = UDim2.new(1, -10, 0.5, -2.5)
    led.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    led.BackgroundTransparency = 0.2
    led.BorderSizePixel = 0
    led.Parent = statusBar
    local ledCorner = Instance.new("UICorner")
    ledCorner.CornerRadius = UDim.new(1, 0)
    ledCorner.Parent = led

    task.spawn(function()
        while screenGui and screenGui.Parent do
            local activeCount = (config.autoWinEnabled and 1 or 0) + (config.autoTaskEnabled and 1 or 0) + (config.espEnabled and 1 or 0) +
                                (config.speedBoostEnabled and 1 or 0) + (config.stealthEnabled and 1 or 0) + (config.godModeEnabled and 1 or 0) +
                                (config.infiniteAmmoEnabled and 1 or 0) + (config.shieldEnabled and 1 or 0) + (config.tpwalkEnabled and 1 or 0) +
                                (config.noCollideEnabled and 1 or 0) + (config.massKillEnabled and 1 or 0) + (config.autoGeneratorEnabled and 1 or 0) +
                                (config.autoSkillCheckEnabled and 1 or 0) + (config.autoAimEnabled and 1 or 0)
            if activeCount > 0 then
                statusLabel.Text = "ACTIVE: " .. activeCount .. " modules"
                statusLabel.TextColor3 = config.guiThemeColor
                led.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            else
                statusLabel.Text = "STANDBY"
                statusLabel.TextColor3 = Color3.fromRGB(150, 50, 50)
                led.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            end
            task.wait(1)
        end
    end)

    mainFrame.BackgroundTransparency = 0.3
    TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.1}):Play()
end
-- ============================================================================
-- FEATURE 17: MODERN GUI (PROFESSIONAL UPGRADE)
-- ============================================================================

-- ============================================================================
-- GLOBAL VARIABLES & SERVICES
-- ============================================================================
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Floating bar
local floatingBar = nil
local isFloatingVisible = false

-- Info text (unchanged)
local infoText = [[
CYBERHEROES SCRIPT v10.1
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚡ Fitur:
• Auto Win (teleport ke finishline + lobby)
• Auto Task (anti-hook + lever gate + escape)
• Auto Generator (ESP lengkap generator, survivor, killer, hook)
• Tpwalk (2x speed + dash)
• Mass Kill (teleport depan + remote event)
• Auto Parry (deteksi Swort/Parrying Dagger)
• God Mode (health regen + stealth jarak)
• Stealth Invisibility (seat method + pre-teleport)
• Shield, No Collide, Auto Aim, Skill Check Bypass

📦 Update Terbaru v10.1:
• Fix teleport depan untuk mass kill (lebih cepat)
• Minimize GUI ke floating bar (drag & restore)
• Tambah menu INFO dengan scroll text
• Optimasi performa keseluruhan

👤 Credits:
Script by kemi (CyberHeroes)
Support: Delta Executor, Synapse X, Krnl

⚠️ Warning:
Gunakan hanya untuk edukasi dan testing di server pribadi.
Jangan digunakan untuk mengganggu pengalaman pemain lain.
]]

-- ============================================================================
-- DRAGGABLE (improved with better touch/mouse handling)
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
    if statusLabel then statusLabel.TextColor3 = config.guiThemeColor end
    -- Update sidebar active item stroke (if any)
    for _, btn in pairs(sidebar:GetDescendants()) do
        if btn:IsA("TextButton") and btn:GetAttribute("Active") then
            local stroke = btn:FindFirstChild("ActiveStroke")
            if stroke then stroke.Color = config.guiThemeColor end
        end
    end
end

-- ============================================================================
-- UTILITY: Create a styled panel (for HOME dashboard)
-- ============================================================================
local function createStyledPanel(parent, title, value, color)
    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 160, 0, 80)
    panel.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    panel.BackgroundTransparency = 0.3
    panel.BorderSizePixel = 0
    panel.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = panel
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or config.guiThemeColor
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = panel
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 24)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 10
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    titleLabel.Parent = panel
    
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(1, 0, 1, -24)
    valueLabel.Position = UDim2.new(0, 0, 0, 24)
    valueLabel.Text = value
    valueLabel.TextColor3 = color or config.guiThemeColor
    valueLabel.BackgroundTransparency = 1
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 20
    valueLabel.TextXAlignment = Enum.TextXAlignment.Center
    valueLabel.Parent = panel
    
    return {panel = panel, valueLabel = valueLabel}
end

-- ============================================================================
-- HOME CONTENT (modern dashboard)
-- ============================================================================
local homeContent = nil
local homeStats = {} -- store value labels for updates
local function createHomeContent()
    if homeContent then homeContent:Destroy() end
    homeContent = Instance.new("Frame")
    homeContent.Size = UDim2.new(1, 0, 1, 0)
    homeContent.BackgroundTransparency = 1
    homeContent.Parent = contentPanel
    
    -- Top row: Player & Game info
    local infoFrame = Instance.new("Frame")
    infoFrame.Size = UDim2.new(1, -20, 0, 40)
    infoFrame.Position = UDim2.new(0, 10, 0, 10)
    infoFrame.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    infoFrame.BackgroundTransparency = 0.2
    infoFrame.BorderSizePixel = 0
    infoFrame.Parent = homeContent
    local infoCorner = Instance.new("UICorner")
    infoCorner.CornerRadius = UDim.new(0, 6)
    infoCorner.Parent = infoFrame
    
    local playerName = Instance.new("TextLabel")
    playerName.Size = UDim2.new(0.5, -5, 1, 0)
    playerName.Position = UDim2.new(0, 5, 0, 0)
    playerName.Text = "👤 " .. localPlayer.Name
    playerName.TextColor3 = Color3.fromRGB(200, 200, 200)
    playerName.BackgroundTransparency = 1
    playerName.Font = Enum.Font.GothamBold
    playerName.TextSize = 12
    playerName.TextXAlignment = Enum.TextXAlignment.Left
    playerName.Parent = infoFrame
    
    local gameName = Instance.new("TextLabel")
    gameName.Size = UDim2.new(0.5, -5, 1, 0)
    gameName.Position = UDim2.new(0.5, 0, 0, 0)
    gameName.Text = "🎮 " .. game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
    gameName.TextColor3 = Color3.fromRGB(200, 200, 200)
    gameName.BackgroundTransparency = 1
    gameName.Font = Enum.Font.Gotham
    gameName.TextSize = 10
    gameName.TextXAlignment = Enum.TextXAlignment.Right
    gameName.Parent = infoFrame
    pcall(function() gameName.Text = "🎮 " .. game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name end)
    
    -- Dashboard panels (2x2 grid)
    local panelGrid = Instance.new("Frame")
    panelGrid.Size = UDim2.new(1, -20, 0, 180)
    panelGrid.Position = UDim2.new(0, 10, 0, 60)
    panelGrid.BackgroundTransparency = 1
    panelGrid.Parent = homeContent
    
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 160, 0, 80)
    gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
    gridLayout.FillDirection = Enum.FillDirection.Horizontal
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    gridLayout.Parent = panelGrid
    
    -- Panel 1: Active Modules
    local activePanel = createStyledPanel(panelGrid, "ACTIVE MODULES", "0", config.guiThemeColor)
    homeStats.activeModules = activePanel.valueLabel
    
    -- Panel 2: Script Version
    local versionPanel = createStyledPanel(panelGrid, "VERSION", "v10.1", config.guiThemeColor)
    
    -- Panel 3: Executor
    local executorName = "Unknown"
    if syn then executorName = "Synapse X"
    elseif Krnl then executorName = "Krnl"
    elseif getexecutorname then executorName = getexecutorname()
    elseif isfile and isfolder then executorName = "Delta"
    end
    local execPanel = createStyledPanel(panelGrid, "EXECUTOR", executorName, Color3.fromRGB(100, 200, 255))
    
    -- Panel 4: Security Status
    local securityPanel = createStyledPanel(panelGrid, "SECURITY", "ACTIVE", Color3.fromRGB(0, 255, 0))
    
    -- Bottom: FPS + Ping
    local statsFrame = Instance.new("Frame")
    statsFrame.Size = UDim2.new(1, -20, 0, 30)
    statsFrame.Position = UDim2.new(0, 10, 1, -40)
    statsFrame.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    statsFrame.BackgroundTransparency = 0.2
    statsFrame.BorderSizePixel = 0
    statsFrame.Parent = homeContent
    local statsCorner = Instance.new("UICorner")
    statsCorner.CornerRadius = UDim.new(0, 6)
    statsCorner.Parent = statsFrame
    
    local fpsLabel = Instance.new("TextLabel")
    fpsLabel.Size = UDim2.new(0.5, -5, 1, 0)
    fpsLabel.Position = UDim2.new(0, 5, 0, 0)
    fpsLabel.Text = "FPS: --"
    fpsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    fpsLabel.BackgroundTransparency = 1
    fpsLabel.Font = Enum.Font.Gotham
    fpsLabel.TextSize = 10
    fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
    fpsLabel.Parent = statsFrame
    
    local pingLabel = Instance.new("TextLabel")
    pingLabel.Size = UDim2.new(0.5, -5, 1, 0)
    pingLabel.Position = UDim2.new(0.5, 0, 0, 0)
    pingLabel.Text = "PING: -- ms"
    pingLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    pingLabel.BackgroundTransparency = 1
    pingLabel.Font = Enum.Font.Gotham
    pingLabel.TextSize = 10
    pingLabel.TextXAlignment = Enum.TextXAlignment.Right
    pingLabel.Parent = statsFrame
    
    -- Update FPS and Ping
    local lastTime = tick()
    local frameCount = 0
    task.spawn(function()
        while homeContent and homeContent.Parent do
            frameCount = frameCount + 1
            local now = tick()
            if now - lastTime >= 1 then
                local fps = frameCount
                fpsLabel.Text = "FPS: " .. fps
                local ping = Stats:FindFirstChild("Network") and Stats.Network:FindFirstChild("Ping") and math.floor(Stats.Network.Ping.Value) or 0
                pingLabel.Text = "PING: " .. ping .. " ms"
                frameCount = 0
                lastTime = now
            end
            task.wait()
        end
    end)
    
    -- Update active modules count every second
    task.spawn(function()
        while homeContent and homeContent.Parent do
            local count = 0
            if config.autoWinEnabled then count = count + 1 end
            if config.autoTaskEnabled then count = count + 1 end
            if config.espEnabled then count = count + 1 end
            if config.speedBoostEnabled then count = count + 1 end
            if config.stealthEnabled then count = count + 1 end
            if config.godModeEnabled then count = count + 1 end
            if config.infiniteAmmoEnabled then count = count + 1 end
            if config.shieldEnabled then count = count + 1 end
            if config.tpwalkEnabled then count = count + 1 end
            if config.noCollideEnabled then count = count + 1 end
            if config.massKillEnabled then count = count + 1 end
            if config.autoGeneratorEnabled then count = count + 1 end
            if config.autoSkillCheckEnabled then count = count + 1 end
            if config.autoAimEnabled then count = count + 1 end
            homeStats.activeModules.Text = tostring(count)
            task.wait(1)
        end
    end)
end

-- ============================================================================
-- ABOUT CONTENT (scrolling with sections)
-- ============================================================================
local aboutContent = nil
local function createAboutContent()
    if aboutContent then aboutContent:Destroy() end
    aboutContent = Instance.new("Frame")
    aboutContent.Size = UDim2.new(1, 0, 1, 0)
    aboutContent.BackgroundTransparency = 1
    aboutContent.Parent = contentPanel
    
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -10, 1, -10)
    scroll.Position = UDim2.new(0, 5, 0, 5)
    scroll.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    scroll.BackgroundTransparency = 0.2
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 6
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.Parent = aboutContent
    local scrollCorner = Instance.new("UICorner")
    scrollCorner.CornerRadius = UDim.new(0, 6)
    scrollCorner.Parent = scroll
    
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 0)
    container.BackgroundTransparency = 1
    container.AutomaticSize = Enum.AutomaticSize.Y
    container.Parent = scroll
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 12)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = container
    
    local function addSection(title, content, order)
        local section = Instance.new("Frame")
        section.Size = UDim2.new(1, -10, 0, 0)
        section.BackgroundTransparency = 1
    section.AutomaticSize = Enum.AutomaticSize.Y
    section.Parent = container
    section.LayoutOrder = order
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 24)
    titleLabel.Text = title
    titleLabel.TextColor3 = config.guiThemeColor
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 12
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = section
    
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(1, 0, 0, 1)
    sep.Position = UDim2.new(0, 0, 0, 24)
    sep.BackgroundColor3 = config.guiThemeColor
    sep.BackgroundTransparency = 0.5
    sep.Parent = section
    
    local contentLabel = Instance.new("TextLabel")
    contentLabel.Size = UDim2.new(1, 0, 0, 0)
    contentLabel.Position = UDim2.new(0, 0, 0, 30)
    contentLabel.Text = content
    contentLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    contentLabel.BackgroundTransparency = 1
    contentLabel.Font = Enum.Font.Gotham
    contentLabel.TextSize = 10
    contentLabel.TextWrapped = true
    contentLabel.TextXAlignment = Enum.TextXAlignment.Left
    contentLabel.TextYAlignment = Enum.TextYAlignment.Top
    contentLabel.AutomaticSize = Enum.AutomaticSize.Y
    contentLabel.Parent = section
    
    section.Size = UDim2.new(1, -10, 0, contentLabel.AbsoluteSize.Y + 30)
    end
    
    addSection("👤 CREATOR", "Script by kemi (CyberHeroes)\nFull-stack exploit developer specialized in Roblox security research.", 1)
    addSection("💎 CREDITS", "Special thanks to:\n• Delta Executor Team\n• Synapse X Community\n• Krnl Developers\n• All beta testers", 2)
    addSection("⚙️ SUPPORTED EXECUTORS", "• Delta Executor (recommended)\n• Synapse X\n• Krnl\n• ScriptWare\n• Other Luau-compatible executors", 3)
    addSection("📦 CHANGELOG (v10.1)", "• Fixed front teleport for Mass Kill (faster execution)\n• Added minimize to floating bar with drag & restore\n• Added INFO tab with scrollable text\n• Optimized overall performance and memory usage\n• Improved ESP system with event-based updates\n• Upgraded GUI with modern dashboard and ABOUT page", 4)
    addSection("🎯 PURPOSE", "This script is created for educational purposes and private server testing only.\nIt demonstrates various Roblox engine mechanics and exploit techniques.", 5)
    addSection("⚠️ DISCLAIMER", "Using this script in public servers may violate Roblox Terms of Service.\nThe author is not responsible for any bans or consequences.\nUse at your own risk and only in servers you own or have permission to test.", 6)
    addSection("🔗 CONTACT / SOCIAL", "Discord: kemi#1234 (placeholder)\nGitHub: /CyberHeroes\nNo support will be given for misuse.", 7)
end

-- ============================================================================
-- SETTINGS CONTENT (improved layout)
-- ============================================================================
local function createSettingsContent()
    if settingsContent then settingsContent:Destroy() end
    settingsContent = Instance.new("Frame")
    settingsContent.Size = UDim2.new(1, 0, 1, 0)
    settingsContent.BackgroundTransparency = 1
    settingsContent.Parent = contentPanel
    
    -- Theme color row
    local colorLabel = Instance.new("TextLabel")
    colorLabel.Size = UDim2.new(1, -20, 0, 24)
    colorLabel.Position = UDim2.new(0, 10, 0, 10)
    colorLabel.Text = "THEME COLOR"
    colorLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    colorLabel.BackgroundTransparency = 1
    colorLabel.Font = Enum.Font.GothamBold
    colorLabel.TextSize = 12
    colorLabel.TextXAlignment = Enum.TextXAlignment.Left
    colorLabel.Parent = settingsContent
    
    local btnContainer = Instance.new("Frame")
    btnContainer.Size = UDim2.new(1, -20, 0, 30)
    btnContainer.Position = UDim2.new(0, 10, 0, 40)
    btnContainer.BackgroundTransparency = 1
    btnContainer.Parent = settingsContent
    
    local function colorButton(text, color, xPos)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 70, 0, 26)
        btn.Position = UDim2.new(xPos, 0, 0, 0)
        btn.Text = text
        btn.BackgroundColor3 = color
        btn.TextColor3 = (text == "YELLOW") and Color3.fromRGB(0,0,0) or Color3.fromRGB(255,255,255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
        btn.BorderSizePixel = 0
        btn.Parent = btnContainer
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = btn
        btn.MouseButton1Click:Connect(function()
            config.guiThemeColor = color
            updateTheme()
        end)
        return btn
    end
    
    colorButton("RED", Color3.fromRGB(255,0,0), 0)
    colorButton("CYAN", Color3.fromRGB(0,255,255), 0.33)
    colorButton("YELLOW", Color3.fromRGB(255,255,0), 0.66)
    
    -- Chat system (improved layout)
    local chatLabel = Instance.new("TextLabel")
    chatLabel.Size = UDim2.new(1, -20, 0, 20)
    chatLabel.Position = UDim2.new(0, 10, 0, 85)
    chatLabel.Text = "CHAT SYSTEM"
    chatLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    chatLabel.BackgroundTransparency = 1
    chatLabel.Font = Enum.Font.GothamBold
    chatLabel.TextSize = 12
    chatLabel.TextXAlignment = Enum.TextXAlignment.Left
    chatLabel.Parent = settingsContent
    
    chatLog = Instance.new("ScrollingFrame")
    chatLog.Size = UDim2.new(1, -20, 0, 120)
    chatLog.Position = UDim2.new(0, 10, 0, 110)
    chatLog.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    chatLog.BackgroundTransparency = 0.3
    chatLog.BorderSizePixel = 0
    chatLog.ScrollBarThickness = 6
    chatLog.Parent = settingsContent
    local chatLogCorner = Instance.new("UICorner")
    chatLogCorner.CornerRadius = UDim.new(0, 6)
    chatLogCorner.Parent = chatLog
    
    local chatListLayout = Instance.new("UIListLayout")
    chatListLayout.Padding = UDim.new(0, 2)
    chatListLayout.Parent = chatLog
    
    chatInput = Instance.new("TextBox")
    chatInput.Size = UDim2.new(0.7, -10, 0, 28)
    chatInput.Position = UDim2.new(0, 10, 0, 240)
    chatInput.PlaceholderText = "Type report..."
    chatInput.Text = ""
    chatInput.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    chatInput.BackgroundTransparency = 0.3
    chatInput.TextColor3 = Color3.fromRGB(255,255,255)
    chatInput.Font = Enum.Font.Gotham
    chatInput.TextSize = 10
    chatInput.BorderSizePixel = 0
    chatInput.Parent = settingsContent
    local chatInputCorner = Instance.new("UICorner")
    chatInputCorner.CornerRadius = UDim.new(0, 6)
    chatInputCorner.Parent = chatInput
    
    local sendBtn = Instance.new("TextButton")
    sendBtn.Size = UDim2.new(0.25, -10, 0, 28)
    sendBtn.Position = UDim2.new(0.75, 0, 0, 240)
    sendBtn.Text = "SEND"
    sendBtn.BackgroundColor3 = Color3.fromRGB(40,5,5)
    sendBtn.TextColor3 = Color3.fromRGB(200,200,200)
    sendBtn.Font = Enum.Font.GothamBold
    sendBtn.TextSize = 10
    sendBtn.BorderSizePixel = 0
    sendBtn.Parent = settingsContent
    local sendCorner = Instance.new("UICorner")
    sendCorner.CornerRadius = UDim.new(0, 6)
    sendCorner.Parent = sendBtn
    
    sendBtn.MouseButton1Click:Connect(function()
        local msg = chatInput.Text
        if msg == "" then return end
        local newMsg = Instance.new("TextLabel")
        newMsg.Size = UDim2.new(1, 0, 0, 16)
        newMsg.Text = "[user] " .. msg
        newMsg.TextColor3 = Color3.fromRGB(200,200,200)
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
-- INFO CONTENT (fixed scrolling with proper text sizing)
-- ============================================================================
local infoContent = nil
local function createInfoContent()
    if infoContent then infoContent:Destroy() end
    infoContent = Instance.new("Frame")
    infoContent.Size = UDim2.new(1, 0, 1, 0)
    infoContent.BackgroundTransparency = 1
    infoContent.Parent = contentPanel
    
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -10, 1, -10)
    scroll.Position = UDim2.new(0, 5, 0, 5)
    scroll.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    scroll.BackgroundTransparency = 0.2
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 6
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.Parent = infoContent
    local scrollCorner = Instance.new("UICorner")
    scrollCorner.CornerRadius = UDim.new(0, 6)
    scrollCorner.Parent = scroll
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -16, 0, 0)
    textLabel.Position = UDim2.new(0, 8, 0, 8)
    textLabel.Text = infoText
    textLabel.TextColor3 = Color3.fromRGB(200,200,200)
    textLabel.BackgroundTransparency = 1
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextSize = 10
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.TextYAlignment = Enum.TextYAlignment.Top
    textLabel.TextWrapped = true
    textLabel.AutomaticSize = Enum.AutomaticSize.Y
    textLabel.Parent = scroll
end

-- ============================================================================
-- FLOATING BAR (fixed drag vs click detection)
-- ============================================================================
local function createFloatingBar()
    if floatingBar and floatingBar.Parent then
        floatingBar.Visible = true
        return floatingBar
    end
    if floatingBar then floatingBar:Destroy() end
    
    local barGui = Instance.new("ScreenGui")
    barGui.Name = "CyberHeroes_FloatingBar"
    barGui.ResetOnSpawn = false
    barGui.IgnoreGuiInset = true
    barGui.Parent = CoreGui
    
    local barFrame = Instance.new("Frame")
    barFrame.Size = UDim2.new(0, 150, 0, 40)
    barFrame.Position = UDim2.new(0.5, -75, 0.05, 0)
    barFrame.BackgroundColor3 = Color3.fromRGB(20,5,10)
    barFrame.BackgroundTransparency = 0.2
    barFrame.BorderSizePixel = 0
    barFrame.Parent = barGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = barFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = config.guiThemeColor
    stroke.Thickness = 1.5
    stroke.Transparency = 0.4
    stroke.Parent = barFrame
    
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, 35, 1, 0)
    icon.Position = UDim2.new(0, 5, 0, 0)
    icon.Text = "⚡"
    icon.TextColor3 = config.guiThemeColor
    icon.BackgroundTransparency = 1
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 20
    icon.Parent = barFrame
    
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, -45, 1, 0)
    text.Position = UDim2.new(0, 45, 0, 0)
    text.Text = "CYBERHEROES"
    text.TextColor3 = config.guiThemeColor
    text.BackgroundTransparency = 1
    text.Font = Enum.Font.GothamBold
    text.TextSize = 11
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Parent = barFrame
    
    -- Drag with threshold to avoid accidental click
    local dragStart = nil
    local dragThreshold = 5
    local hasMoved = false
    
    barFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragStart = input.Position
            hasMoved = false
        end
    end)
    
    barFrame.InputChanged:Connect(function(input)
        if dragStart and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = (input.Position - dragStart).Magnitude
            if delta > dragThreshold then
                hasMoved = true
                local newPos = barFrame.Position.Offset + (input.Position - dragStart)
                barFrame.Position = UDim2.new(barFrame.Position.X.Scale, newPos.X, barFrame.Position.Y.Scale, newPos.Y)
                dragStart = input.Position
            end
        end
    end)
    
    barFrame.InputEnded:Connect(function(input)
        if dragStart and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            if not hasMoved then
                if mainFrame then
                    mainFrame.Visible = true
                    config.guiVisible = true
                    barGui:Destroy()
                    floatingBar = nil
                    isFloatingVisible = false
                end
            end
            dragStart = nil
        end
    end)
    
    -- Hover effect
    barFrame.MouseEnter:Connect(function()
        TweenService:Create(barFrame, TweenInfo.new(0.15), {BackgroundTransparency = 0.05}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.15), {Transparency = 0.1, Thickness = 2}):Play()
    end)
    barFrame.MouseLeave:Connect(function()
        TweenService:Create(barFrame, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.15), {Transparency = 0.4, Thickness = 1.5}):Play()
    end)
    
    floatingBar = barGui
    return floatingBar
end

-- ============================================================================
-- GUI BUTTONS (improved grid spacing)
-- ============================================================================
local function createGridButton(parent, name, text, initialState, onChange)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 85, 0, 32)
    button.Text = text .. (initialState and " [ON]" or " [OFF]")
    button.BackgroundColor3 = initialState and Color3.fromRGB(40,5,5) or Color3.fromRGB(15,0,2)
    button.BackgroundTransparency = 0.1
    button.TextColor3 = initialState and Color3.fromRGB(0,230,255) or Color3.fromRGB(200,200,200)
    button.TextSize = 9
    button.Font = Enum.Font.GothamBold
    button.BorderSizePixel = 0
    button.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button
    local stroke = Instance.new("UIStroke")
    stroke.Color = initialState and Color3.fromRGB(0,200,255) or Color3.fromRGB(150,30,30)
    stroke.Thickness = 1
    stroke.Transparency = 0.3
    stroke.Parent = button
    
    local function updateState(state)
        button.Text = text .. (state and " [ON]" or " [OFF]")
        button.BackgroundColor3 = state and Color3.fromRGB(40,5,5) or Color3.fromRGB(15,0,2)
        button.TextColor3 = state and Color3.fromRGB(0,230,255) or Color3.fromRGB(200,200,200)
        stroke.Color = state and Color3.fromRGB(0,200,255) or Color3.fromRGB(150,30,30)
    end
    
    button.MouseButton1Click:Connect(function()
        local newState = not (config[name] or false)
        -- All original feature toggles preserved
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

-- ============================================================================
-- SIDEBAR ITEM (with active state and hover)
-- ============================================================================
local function createSidebarItem(parent, text, icon, active)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 32)
    button.Text = " " .. icon .. "  " .. text
    button.TextColor3 = active and Color3.fromRGB(0,230,255) or Color3.fromRGB(200,200,200)
    button.BackgroundColor3 = active and Color3.fromRGB(40,5,5) or Color3.fromRGB(15,0,2)
    button.BackgroundTransparency = 0.2
    button.TextSize = 10
    button.Font = Enum.Font.GothamBold
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.BorderSizePixel = 0
    button.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    
    -- Active stroke for better visibility
    local activeStroke = Instance.new("UIStroke")
    activeStroke.Color = config.guiThemeColor
    activeStroke.Thickness = 1
    activeStroke.Transparency = active and 0.2 or 1
    activeStroke.Parent = button
    button:SetAttribute("Active", active)
    
    -- Hover effect
    button.MouseEnter:Connect(function()
        if not button:GetAttribute("Active") then
            TweenService:Create(button, TweenInfo.new(0.1), {BackgroundTransparency = 0.1, TextColor3 = Color3.fromRGB(220,220,220)}):Play()
        end
    end)
    button.MouseLeave:Connect(function()
        if not button:GetAttribute("Active") then
            TweenService:Create(button, TweenInfo.new(0.1), {BackgroundTransparency = 0.2, TextColor3 = Color3.fromRGB(200,200,200)}):Play()
        end
    end)
    
    -- Function to set active state
    function button:SetActive(state)
        self:SetAttribute("Active", state)
        self.TextColor3 = state and Color3.fromRGB(0,230,255) or Color3.fromRGB(200,200,200)
        self.BackgroundColor3 = state and Color3.fromRGB(40,5,5) or Color3.fromRGB(15,0,2)
        activeStroke.Transparency = state and 0.2 or 1
        if state then
            activeStroke.Color = config.guiThemeColor
        end
    end
    
    return button
end

-- ============================================================================
-- PERMANENT TELEPORT BUTTON (unchanged)
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
    teleportButton.Position = UDim2.new(0.02, 0, 0.85, -30)
    teleportButton.Text = "⚡\nTP"
    teleportButton.TextWrapped = true
    teleportButton.BackgroundColor3 = Color3.fromRGB(40,5,5)
    teleportButton.BackgroundTransparency = 0.2
    teleportButton.TextColor3 = Color3.fromRGB(0,230,255)
    teleportButton.TextSize = 14
    teleportButton.Font = Enum.Font.GothamBold
    teleportButton.BorderSizePixel = 0
    teleportButton.Parent = teleportButtonGui
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(1, 0)
    btnCorner.Parent = teleportButton
    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Color3.fromRGB(0,200,255)
    btnStroke.Thickness = 1.5
    btnStroke.Transparency = 0.4
    btnStroke.Parent = teleportButton
    teleportButton.MouseButton1Click:Connect(teleportToNearestSurvivor)
    makeDraggable(teleportButton)
end

-- ============================================================================
-- MAIN GUI (enlarged and with improved layout)
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
    mainFrame.Size = UDim2.new(0, 420, 0, 360)
    mainFrame.Position = UDim2.new(0.5, -210, 0.5, -180)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20,5,10)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = mainFrame
    mainStroke = Instance.new("UIStroke")
    mainStroke.Color = config.guiThemeColor
    mainStroke.Thickness = 1.5
    mainStroke.Transparency = 0.4
    mainStroke.Parent = mainFrame
    
    -- Title bar (modern)
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 28)
    titleBar.BackgroundColor3 = Color3.fromRGB(25,3,7)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.6, 0, 1, 0)
    title.Position = UDim2.new(0.02, 0, 0, 0)
    title.Text = "CYBERHEROES v10.1"
    title.TextColor3 = config.guiThemeColor
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    local versionLabel = Instance.new("TextLabel")
    versionLabel.Size = UDim2.new(0.3, 0, 1, 0)
    versionLabel.Position = UDim2.new(0.6, 0, 0, 0)
    versionLabel.Text = "Build 10.1"
    versionLabel.TextColor3 = Color3.fromRGB(150,150,200)
    versionLabel.BackgroundTransparency = 1
    versionLabel.Font = Enum.Font.Gotham
    versionLabel.TextSize = 9
    versionLabel.TextXAlignment = Enum.TextXAlignment.Left
    versionLabel.Parent = titleBar
    
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 24, 0, 24)
    minimizeBtn.Position = UDim2.new(1, -52, 0, 2)
    minimizeBtn.Text = "−"
    minimizeBtn.TextColor3 = Color3.fromRGB(200,200,200)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(40,5,5)
    minimizeBtn.BackgroundTransparency = 0.2
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextSize = 18
    minimizeBtn.Parent = titleBar
    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 4)
    minCorner.Parent = minimizeBtn
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 24, 0, 24)
    closeBtn.Position = UDim2.new(1, -26, 0, 2)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255,100,100)
    closeBtn.BackgroundColor3 = Color3.fromRGB(40,5,5)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.Parent = titleBar
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeBtn
    
    local function minimizeGUI()
        config.guiVisible = false
        if mainFrame then mainFrame.Visible = false end
        if floatingBar then pcall(function() floatingBar:Destroy() end) floatingBar = nil end
        createFloatingBar()
        isFloatingVisible = true
    end
    
    minimizeBtn.MouseButton1Click:Connect(minimizeGUI)
    closeBtn.MouseButton1Click:Connect(minimizeGUI)
    
    -- Sidebar
    sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 100, 1, -28)
    sidebar.Position = UDim2.new(0, 0, 0, 28)
    sidebar.BackgroundColor3 = Color3.fromRGB(15,0,2)
    sidebar.BackgroundTransparency = 0.2
    sidebar.BorderSizePixel = 0
    sidebar.Parent = mainFrame
    local sidebarCorner = Instance.new("UICorner")
    sidebarCorner.CornerRadius = UDim.new(0, 0)
    sidebarCorner.Parent = sidebar
    
    local sidebarList = Instance.new("Frame")
    sidebarList.Size = UDim2.new(1, 0, 0, 200)
    sidebarList.Position = UDim2.new(0, 0, 0.05, 0)
    sidebarList.BackgroundTransparency = 1
    sidebarList.Parent = sidebar
    local sidebarLayout = Instance.new("UIListLayout")
    sidebarLayout.Padding = UDim.new(0, 6)
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
    sep.BackgroundColor3 = Color3.fromRGB(0,200,255)
    sep.BackgroundTransparency = 0.7
    sep.Parent = sidebarList
    
    contentPanel = Instance.new("Frame")
    contentPanel.Size = UDim2.new(1, -110, 1, -34)
    contentPanel.Position = UDim2.new(0, 105, 0, 32)
    contentPanel.BackgroundTransparency = 1
    contentPanel.Parent = mainFrame
    
    -- Feature grid (improved padding and wrapping)
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 90, 0, 34)
    gridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
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
    
    -- Navigation handlers with active state management
    local function setActiveSidebar(activeItem)
        for _, item in ipairs({homeItem, featuresItem, settingsItem, infoItem, aboutItem}) do
            item:SetActive(item == activeItem)
        end
    end
    
    homeItem.MouseButton1Click:Connect(function()
        setActiveSidebar(homeItem)
        if settingsContent then settingsContent:Destroy() end
        if infoContent then infoContent:Destroy() end
        if aboutContent then aboutContent:Destroy() end
        gridLayout.Parent = contentPanel
        createHomeContent()
    end)
    featuresItem.MouseButton1Click:Connect(function()
        setActiveSidebar(featuresItem)
        if settingsContent then settingsContent:Destroy() end
        if infoContent then infoContent:Destroy() end
        if aboutContent then aboutContent:Destroy() end
        gridLayout.Parent = contentPanel
    end)
    settingsItem.MouseButton1Click:Connect(function()
        setActiveSidebar(settingsItem)
        gridLayout.Parent = nil
        if infoContent then infoContent:Destroy() end
        if aboutContent then aboutContent:Destroy() end
        createSettingsContent()
    end)
    infoItem.MouseButton1Click:Connect(function()
        setActiveSidebar(infoItem)
        gridLayout.Parent = nil
        if settingsContent then settingsContent:Destroy() end
        if aboutContent then aboutContent:Destroy() end
        createInfoContent()
    end)
    aboutItem.MouseButton1Click:Connect(function()
        setActiveSidebar(aboutItem)
        gridLayout.Parent = nil
        if settingsContent then settingsContent:Destroy() end
        if infoContent then infoContent:Destroy() end
        createAboutContent()
    end)
    
    makeDraggable(mainFrame)
    
    -- Status bar
    local statusBar = Instance.new("Frame")
    statusBar.Size = UDim2.new(1, 0, 0, 20)
    statusBar.Position = UDim2.new(0, 0, 1, -20)
    statusBar.BackgroundColor3 = Color3.fromRGB(15,0,2)
    statusBar.BackgroundTransparency = 0.2
    statusBar.BorderSizePixel = 0
    statusBar.Parent = mainFrame
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 6)
    statusCorner.Parent = statusBar
    
    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -10, 1, 0)
    statusLabel.Position = UDim2.new(0, 5, 0, 0)
    statusLabel.Text = "SYSTEM READY"
    statusLabel.TextColor3 = config.guiThemeColor
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 9
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = statusBar
    
    local led = Instance.new("Frame")
    led.Size = UDim2.new(0, 6, 0, 6)
    led.Position = UDim2.new(1, -12, 0.5, -3)
    led.BackgroundColor3 = Color3.fromRGB(0,255,0)
    led.BackgroundTransparency = 0.2
    led.BorderSizePixel = 0
    led.Parent = statusBar
    local ledCorner = Instance.new("UICorner")
    ledCorner.CornerRadius = UDim.new(1, 0)
    ledCorner.Parent = led
    
    -- Status updater
    task.spawn(function()
        while screenGui and screenGui.Parent do
            local activeCount = 0
            for _, feat in ipairs(features) do
                if feat.name ~= "restartScript" and config[feat.name] then
                    activeCount = activeCount + 1
                end
            end
            if activeCount > 0 then
                statusLabel.Text = "ACTIVE: " .. activeCount .. " modules"
                statusLabel.TextColor3 = config.guiThemeColor
                led.BackgroundColor3 = Color3.fromRGB(0,255,0)
            else
                statusLabel.Text = "STANDBY"
                statusLabel.TextColor3 = Color3.fromRGB(150,50,50)
                led.BackgroundColor3 = Color3.fromRGB(255,0,0)
            end
            task.wait(1)
        end
    end)
    
    -- Initial home content
    createHomeContent()
    
    mainFrame.BackgroundTransparency = 0.3
    TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.1}):Play()
end

-- Note: The rest of the script (auto-win, auto-task, etc.) remains exactly the same.
-- Only the GUI creation part has been replaced with the upgraded version above.
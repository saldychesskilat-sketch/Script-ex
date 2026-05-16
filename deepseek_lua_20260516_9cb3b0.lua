-- ============================================================================
-- MODERN GUI (FULLY FIXED - COMPATIBLE WITH ORIGINAL SCRIPT)
-- ============================================================================

-- ============================================================================
-- DRAGGABLE (tidak berubah, aman)
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
-- THEME UPDATE (aman)
-- ============================================================================
local function updateTheme()
    if mainStroke then mainStroke.Color = config.guiThemeColor end
    if statusLabel then statusLabel.TextColor3 = config.guiThemeColor end
    if floatingBar and floatingBar.Parent then
        local barStroke = floatingBar:FindFirstChild("FloatingBar") and floatingBar.FloatingBar:FindFirstChildWhichIsA("UIStroke")
        if barStroke then barStroke.Color = config.guiThemeColor end
    end
end

-- ============================================================================
-- SETTINGS CONTENT (FIXED LAYOUT)
-- ============================================================================
local function createSettingsContent()
    if settingsContent then settingsContent:Destroy() end
    settingsContent = Instance.new("ScrollingFrame")
    settingsContent.Name = "SettingsContent"
    settingsContent.Size = UDim2.new(1, 0, 1, 0)
    settingsContent.BackgroundTransparency = 1
    settingsContent.ScrollBarThickness = 6
    settingsContent.Parent = contentPanel

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.Parent = settingsContent

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 12)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = settingsContent

    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 25)
    titleLabel.Text = "⚙️ SETTINGS"
    titleLabel.TextColor3 = config.guiThemeColor
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 14
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = settingsContent

    -- Theme Color Section
    local colorSection = Instance.new("Frame")
    colorSection.Size = UDim2.new(1, 0, 0, 50)
    colorSection.BackgroundTransparency = 1
    colorSection.Parent = settingsContent

    local colorLabel = Instance.new("TextLabel")
    colorLabel.Size = UDim2.new(0, 100, 0, 20)
    colorLabel.Position = UDim2.new(0, 0, 0, 0)
    colorLabel.Text = "Theme Color"
    colorLabel.TextColor3 = Color3.fromRGB(200,200,200)
    colorLabel.BackgroundTransparency = 1
    colorLabel.Font = Enum.Font.GothamBold
    colorLabel.TextSize = 12
    colorLabel.TextXAlignment = Enum.TextXAlignment.Left
    colorLabel.Parent = colorSection

    local btnFrame = Instance.new("Frame")
    btnFrame.Size = UDim2.new(1, 0, 0, 28)
    btnFrame.Position = UDim2.new(0, 0, 0, 22)
    btnFrame.BackgroundTransparency = 1
    btnFrame.Parent = colorSection

    local function makeColorBtn(parent, text, color, posX)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 70, 0, 25)
        btn.Position = UDim2.new(posX, 0, 0, 0)
        btn.Text = text
        btn.BackgroundColor3 = color
        btn.TextColor3 = (text == "YELLOW" or text == "CYAN") and Color3.fromRGB(0,0,0) or Color3.fromRGB(255,255,255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
        btn.BorderSizePixel = 0
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = btn
        btn.Parent = parent
        btn.MouseButton1Click:Connect(function()
            config.guiThemeColor = color
            updateTheme()
        end)
        return btn
    end

    makeColorBtn(btnFrame, "RED", Color3.fromRGB(255,0,0), 0)
    makeColorBtn(btnFrame, "CYAN", Color3.fromRGB(0,255,255), 0.15)
    makeColorBtn(btnFrame, "YELLOW", Color3.fromRGB(255,255,0), 0.30)

    -- Separator
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(1, 0, 0, 1)
    sep.BackgroundColor3 = Color3.fromRGB(60,60,70)
    sep.BackgroundTransparency = 0.5
    sep.Parent = settingsContent

    -- Chat Section
    local chatSection = Instance.new("Frame")
    chatSection.Size = UDim2.new(1, 0, 0, 180)
    chatSection.BackgroundTransparency = 1
    chatSection.Parent = settingsContent

    local chatTitle = Instance.new("TextLabel")
    chatTitle.Size = UDim2.new(1, 0, 0, 20)
    chatTitle.Text = "Chat Report"
    chatTitle.TextColor3 = Color3.fromRGB(200,200,200)
    chatTitle.BackgroundTransparency = 1
    chatTitle.Font = Enum.Font.GothamBold
    chatTitle.TextSize = 12
    chatTitle.TextXAlignment = Enum.TextXAlignment.Left
    chatTitle.Parent = chatSection

    chatLog = Instance.new("ScrollingFrame")
    chatLog.Size = UDim2.new(1, 0, 0, 100)
    chatLog.Position = UDim2.new(0, 0, 0, 25)
    chatLog.BackgroundColor3 = Color3.fromRGB(15,0,2)
    chatLog.BackgroundTransparency = 0.2
    chatLog.BorderSizePixel = 0
    chatLog.ScrollBarThickness = 4
    chatLog.Parent = chatSection
    local chatLogCorner = Instance.new("UICorner")
    chatLogCorner.CornerRadius = UDim.new(0, 4)
    chatLogCorner.Parent = chatLog

    local chatListLayout = Instance.new("UIListLayout")
    chatListLayout.Padding = UDim.new(0, 2)
    chatListLayout.Parent = chatLog

    chatInput = Instance.new("TextBox")
    chatInput.Size = UDim2.new(0.7, -5, 0, 28)
    chatInput.Position = UDim2.new(0, 0, 0, 130)
    chatInput.PlaceholderText = "Type message..."
    chatInput.Text = ""
    chatInput.BackgroundColor3 = Color3.fromRGB(15,0,2)
    chatInput.BackgroundTransparency = 0.2
    chatInput.TextColor3 = Color3.fromRGB(255,255,255)
    chatInput.Font = Enum.Font.Gotham
    chatInput.TextSize = 11
    chatInput.BorderSizePixel = 0
    chatInput.Parent = chatSection
    local chatInputCorner = Instance.new("UICorner")
    chatInputCorner.CornerRadius = UDim.new(0, 4)
    chatInputCorner.Parent = chatInput

    local sendBtn = Instance.new("TextButton")
    sendBtn.Size = UDim2.new(0.25, 0, 0, 28)
    sendBtn.Position = UDim2.new(0.73, 0, 0, 130)
    sendBtn.Text = "SEND"
    sendBtn.BackgroundColor3 = Color3.fromRGB(40,5,5)
    sendBtn.TextColor3 = Color3.fromRGB(200,200,200)
    sendBtn.Font = Enum.Font.GothamBold
    sendBtn.TextSize = 10
    sendBtn.BorderSizePixel = 0
    sendBtn.Parent = chatSection
    local sendCorner = Instance.new("UICorner")
    sendCorner.CornerRadius = UDim.new(0, 4)
    sendCorner.Parent = sendBtn

    sendBtn.MouseButton1Click:Connect(function()
        local msg = chatInput.Text
        if msg == "" then return end
        local newMsg = Instance.new("TextLabel")
        newMsg.Size = UDim2.new(1, 0, 0, 18)
        newMsg.Text = "[user] " .. msg
        newMsg.TextColor3 = Color3.fromRGB(200,200,200)
        newMsg.BackgroundTransparency = 1
        newMsg.Font = Enum.Font.Gotham
        newMsg.TextSize = 10
        newMsg.TextXAlignment = Enum.TextXAlignment.Left
        newMsg.Parent = chatLog
        chatInput.Text = ""
        chatLog.CanvasSize = UDim2.new(0, 0, 0, chatListLayout.AbsoluteContentSize.Y)
        task.wait(2)
        newMsg:Destroy()
    end)

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        settingsContent.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end)
end

-- ============================================================================
-- INFO CONTENT (FIXED WITH AUTOMATIC SIZE)
-- ============================================================================
local infoContent = nil
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

local function createInfoContent()
    if infoContent then infoContent:Destroy() end
    infoContent = Instance.new("ScrollingFrame")
    infoContent.Name = "InfoContent"
    infoContent.Size = UDim2.new(1, 0, 1, 0)
    infoContent.BackgroundTransparency = 1
    infoContent.ScrollBarThickness = 6
    infoContent.Parent = contentPanel

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 12)
    padding.PaddingRight = UDim.new(0, 12)
    padding.PaddingTop = UDim.new(0, 12)
    padding.PaddingBottom = UDim.new(0, 12)
    padding.Parent = infoContent

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 0, 0)
    textLabel.Text = infoText
    textLabel.TextColor3 = Color3.fromRGB(210,210,210)
    textLabel.BackgroundTransparency = 1
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextSize = 11
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.TextYAlignment = Enum.TextYAlignment.Top
    textLabel.TextWrapped = true
    textLabel.AutomaticSize = Enum.AutomaticSize.Y
    textLabel.Parent = infoContent

    textLabel:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        infoContent.CanvasSize = UDim2.new(0, 0, 0, textLabel.AbsoluteSize.Y + 20)
    end)
    task.wait()
    infoContent.CanvasSize = UDim2.new(0, 0, 0, textLabel.AbsoluteSize.Y + 20)
end

-- ============================================================================
-- HOME CONTENT (DASHBOARD)
-- ============================================================================
local homeContent = nil
local function createHomeContent()
    if homeContent then homeContent:Destroy() end
    homeContent = Instance.new("ScrollingFrame")
    homeContent.Name = "HomeContent"
    homeContent.Size = UDim2.new(1, 0, 1, 0)
    homeContent.BackgroundTransparency = 1
    homeContent.ScrollBarThickness = 0
    homeContent.Parent = contentPanel

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.Parent = homeContent

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = homeContent

    local function createCard(title, value, icon, color)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 60)
        card.BackgroundColor3 = Color3.fromRGB(25,5,12)
        card.BackgroundTransparency = 0.2
        card.BorderSizePixel = 0
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = card
        local stroke = Instance.new("UIStroke")
        stroke.Color = color or config.guiThemeColor
        stroke.Thickness = 1
        stroke.Transparency = 0.5
        stroke.Parent = card
        card.Parent = homeContent

        local iconLbl = Instance.new("TextLabel")
        iconLbl.Size = UDim2.new(0, 40, 1, 0)
        iconLbl.Text = icon
        iconLbl.TextColor3 = color or config.guiThemeColor
        iconLbl.BackgroundTransparency = 1
        iconLbl.Font = Enum.Font.GothamBold
        iconLbl.TextSize = 24
        iconLbl.Parent = card

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Size = UDim2.new(1, -50, 0, 20)
        titleLbl.Position = UDim2.new(0, 45, 0, 8)
        titleLbl.Text = title
        titleLbl.TextColor3 = Color3.fromRGB(180,180,180)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.Gotham
        titleLbl.TextSize = 10
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.Parent = card

        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.new(1, -50, 0, 25)
        valLbl.Position = UDim2.new(0, 45, 0, 28)
        valLbl.Text = value
        valLbl.TextColor3 = color or config.guiThemeColor
        valLbl.BackgroundTransparency = 1
        valLbl.Font = Enum.Font.GothamBold
        valLbl.TextSize = 18
        valLbl.TextXAlignment = Enum.TextXAlignment.Left
        valLbl.Parent = card
        return card
    end

    local function updateDashboard()
        if not homeContent then return end
        for _, child in ipairs(homeContent:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        local activeCount = 0
        for k, v in pairs(config) do
            if type(v) == "boolean" and v and k ~= "guiVisible" and k ~= "auto1xModeEnabled" then
                activeCount = activeCount + 1
            end
        end
        local executor = "Unknown"
        if syn then executor = "Synapse X"
        elseif krnl then executor = "Krnl"
        elseif getexecutorname then executor = getexecutorname()
        elseif isfile and readfile then executor = "Delta"
        else executor = "Script Hub" end

        local fps = math.floor(Stats:FindFirstChild("PerformanceStats"):GetValue("FPS") or 60)
        local ping = game:GetService("Stats").Network:GetValue("Ping") or 0
        local gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name or game.Name

        createCard("SYSTEM STATUS", activeCount > 0 and "ACTIVE" or "STANDBY", "⚡", activeCount > 0 and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,50,50))
        createCard("ACTIVE MODULES", tostring(activeCount) .. " / 14", "📦", config.guiThemeColor)
        createCard("EXECUTOR", executor, "💻", Color3.fromRGB(150,150,255))
        createCard("PLAYER", localPlayer.Name, "👤", Color3.fromRGB(100,200,100))
        createCard("GAME", gameName, "🎮", Color3.fromRGB(255,200,100))
        createCard("PERFORMANCE", fps .. " FPS  |  " .. ping .. " ms", "📊", Color3.fromRGB(100,200,255))
        createCard("SECURITY", "PROTECTED", "🔒", Color3.fromRGB(0,230,0))

        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            homeContent.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
        end)
        homeContent.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end

    updateDashboard()
    task.spawn(function()
        while homeContent and homeContent.Parent do
            task.wait(2)
            updateDashboard()
        end
    end)
end

-- ============================================================================
-- ABOUT CONTENT
-- ============================================================================
local aboutContent = nil
local function createAboutContent()
    if aboutContent then aboutContent:Destroy() end
    aboutContent = Instance.new("ScrollingFrame")
    aboutContent.Name = "AboutContent"
    aboutContent.Size = UDim2.new(1, 0, 1, 0)
    aboutContent.BackgroundTransparency = 1
    aboutContent.ScrollBarThickness = 6
    aboutContent.Parent = contentPanel

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 12)
    padding.PaddingRight = UDim.new(0, 12)
    padding.PaddingTop = UDim.new(0, 12)
    padding.PaddingBottom = UDim.new(0, 12)
    padding.Parent = aboutContent

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 15)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = aboutContent

    local function addSection(title, contentText, icon)
        local section = Instance.new("Frame")
        section.Size = UDim2.new(1, 0, 0, 0)
        section.BackgroundTransparency = 1
        section.AutomaticSize = Enum.AutomaticSize.Y
        section.Parent = aboutContent

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Size = UDim2.new(1, 0, 0, 25)
        titleLbl.Text = icon .. " " .. title
        titleLbl.TextColor3 = config.guiThemeColor
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.TextSize = 14
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.Parent = section

        local contentLbl = Instance.new("TextLabel")
        contentLbl.Size = UDim2.new(1, 0, 0, 0)
        contentLbl.Text = contentText
        contentLbl.TextColor3 = Color3.fromRGB(200,200,200)
        contentLbl.BackgroundTransparency = 1
        contentLbl.Font = Enum.Font.Gotham
        contentLbl.TextSize = 11
        contentLbl.TextXAlignment = Enum.TextXAlignment.Left
        contentLbl.TextWrapped = true
        contentLbl.AutomaticSize = Enum.AutomaticSize.Y
        contentLbl.Parent = section

        local sep = Instance.new("Frame")
        sep.Size = UDim2.new(1, 0, 0, 1)
        sep.BackgroundColor3 = Color3.fromRGB(60,60,70)
        sep.BackgroundTransparency = 0.5
        sep.Parent = section
    end

    addSection("CREATOR", "Script by kemi (CyberHeroes)\nRoblox exploit community contributor", "👑")
    addSection("CREDITS", "Special thanks to:\n• Delta Executor Team\n• Synapse X Community\n• Krnl Users\n• All testers", "🙏")
    addSection("SUPPORTED EXECUTORS", "• Delta Executor\n• Synapse X\n• Krnl\n• Script Hub", "⚙️")
    addSection("CHANGELOG (v10.1)", "• Fixed front teleport for Mass Kill (faster execution)\n• Minimize GUI to floating bar with drag & restore\n• Added INFO tab with scrollable text\n• Optimized ESP performance (event-based, progress tracking)\n• Improved layout and dashboard", "📋")
    addSection("PURPOSE", "Educational and testing purposes only.\nDemonstrates Roblox Lua scripting capabilities,\npathfinding, remote event handling, and GUI design.", "🎯")
    addSection("DISCLAIMER", "⚠️ WARNING: Use only in private servers.\nDo not disrupt other players' experience.\nThe creator is not responsible for any account penalties.", "⚠️")
    addSection("CONTACT", "Discord: kemi#1234 (placeholder)\nGitHub: /CyberHeroes", "📧")

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        aboutContent.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 30)
    end)
    task.wait()
    aboutContent.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 30)
end

-- ============================================================================
-- FLOATING BAR (MINI GUI) - FIXED
-- ============================================================================
local floatingBar = nil
local isFloatingVisible = false

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
    barFrame.Name = "FloatingBar"
    barFrame.Size = UDim2.new(0, 150, 0, 40)
    barFrame.Position = UDim2.new(0.5, -75, 0.05, 0)
    barFrame.BackgroundColor3 = Color3.fromRGB(20,5,10)
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

    -- Drag
    local dragging = false
    local dragStart, startPos
    barFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = barFrame.Position
        end
    end)
    barFrame.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            barFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                          startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    barFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- Restore on click (without drag)
    local isDrag = false
    barFrame.InputBegan:Connect(function()
        isDrag = false
    end)
    barFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            isDrag = true
        end
    end)
    barFrame.InputEnded:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not isDrag then
            if mainFrame then
                mainFrame.Visible = true
                config.guiVisible = true
                barGui:Destroy()
                floatingBar = nil
                isFloatingVisible = false
            end
        end
    end)

    floatingBar = barGui
    return floatingBar
end

-- ============================================================================
-- GUI BUTTONS (FEATURE TOGGLES)
-- ============================================================================
local function createGridButton(parent, name, text, initialState)
    local button = Instance.new("TextButton")
    button.Name = name
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
        local newState = not config[name]
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
            if not newState and localHumanoid then localHumanoid.WalkSpeed = config.originalWalkSpeed end
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
        TweenService:Create(button, TweenInfo.new(0.05), {TextSize = 8}):Play()
        task.wait(0.05)
        TweenService:Create(button, TweenInfo.new(0.05), {TextSize = 9}):Play()
    end)

    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.1), {BackgroundTransparency = 0.05}):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.1), {BackgroundTransparency = 0.1}):Play()
    end)

    return button
end

local function createSidebarItem(parent, text, icon, active)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.Text = " " .. icon .. "  " .. text
    btn.TextColor3 = active and config.guiThemeColor or Color3.fromRGB(180,180,180)
    btn.BackgroundColor3 = active and Color3.fromRGB(40,5,5) or Color3.fromRGB(15,0,2)
    btn.BackgroundTransparency = 0.2
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.BorderSizePixel = 0
    btn.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = active and config.guiThemeColor or Color3.fromRGB(100,100,100)
    stroke.Thickness = 0.5
    stroke.Transparency = 0.6
    stroke.Parent = btn

    btn.MouseEnter:Connect(function()
        if not active then
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 0.05, TextColor3 = config.guiThemeColor}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if not active then
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 0.2, TextColor3 = Color3.fromRGB(180,180,180)}):Play()
        end
    end)
    return btn
end

local currentSidebarItem = nil
local function setActiveSidebarItem(btn)
    if currentSidebarItem then
        currentSidebarItem.BackgroundTransparency = 0.2
        currentSidebarItem.TextColor3 = Color3.fromRGB(180,180,180)
        local stroke = currentSidebarItem:FindFirstChildWhichIsA("UIStroke")
        if stroke then stroke.Color = Color3.fromRGB(100,100,100) end
    end
    currentSidebarItem = btn
    btn.BackgroundTransparency = 0.05
    btn.TextColor3 = config.guiThemeColor
    local stroke = btn:FindFirstChildWhichIsA("UIStroke")
    if stroke then stroke.Color = config.guiThemeColor end
end

-- ============================================================================
-- PERMANENT TELEPORT BUTTON (tidak diubah)
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
-- MAIN GUI (FULLY FIXED)
-- ============================================================================
local function createGUI()
    if screenGui then screenGui:Destroy() end
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_GUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = CoreGui

    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainWindow"
    mainFrame.Size = UDim2.new(0, 420, 0, 320)
    mainFrame.Position = UDim2.new(0.5, -210, 0.5, -160)
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
    mainStroke.Transparency = 0.3
    mainStroke.Parent = mainFrame

    -- Title Bar
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
    title.Text = "CYBERHEROES script by kemi"
    title.TextColor3 = config.guiThemeColor
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    local version = Instance.new("TextLabel")
    version.Size = UDim2.new(0.3, 0, 1, 0)
    version.Position = UDim2.new(0.6, 0, 0, 0)
    version.Text = "Build 10.1"
    version.TextColor3 = Color3.fromRGB(150,150,200)
    version.BackgroundTransparency = 1
    version.Font = Enum.Font.Gotham
    version.TextSize = 9
    version.TextXAlignment = Enum.TextXAlignment.Left
    version.Parent = titleBar

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
        if floatingBar then pcall(function() floatingBar:Destroy() end); floatingBar = nil end
        createFloatingBar()
        isFloatingVisible = true
    end
    minimizeBtn.MouseButton1Click:Connect(minimizeGUI)
    closeBtn.MouseButton1Click:Connect(minimizeGUI)

    -- Sidebar
    sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 90, 1, -28)
    sidebar.Position = UDim2.new(0, 0, 0, 28)
    sidebar.BackgroundColor3 = Color3.fromRGB(15,0,2)
    sidebar.BackgroundTransparency = 0.2
    sidebar.BorderSizePixel = 0
    sidebar.Parent = mainFrame

    local sidebarList = Instance.new("Frame")
    sidebarList.Size = UDim2.new(1, 0, 0, 180)
    sidebarList.Position = UDim2.new(0, 0, 0.05, 0)
    sidebarList.BackgroundTransparency = 1
    sidebarList.Parent = sidebar

    local sidebarLayout = Instance.new("UIListLayout")
    sidebarLayout.Padding = UDim.new(0, 5)
    sidebarLayout.FillDirection = Enum.FillDirection.Vertical
    sidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    sidebarLayout.Parent = sidebarList

    local homeItem = createSidebarItem(sidebarList, "HOME", "🏠", true)
    local featuresItem = createSidebarItem(sidebarList, "FEATURES", "⚡", false)
    local settingsItem = createSidebarItem(sidebarList, "SETTINGS", "⚙️", false)
    local infoItem = createSidebarItem(sidebarList, "INFO", "📄", false)
    local aboutItem = createSidebarItem(sidebarList, "ABOUT", "ℹ️", false)
    setActiveSidebarItem(homeItem)

    -- Content Panel
    contentPanel = Instance.new("Frame")
    contentPanel.Size = UDim2.new(1, -100, 1, -34)
    contentPanel.Position = UDim2.new(0, 95, 0, 32)
    contentPanel.BackgroundTransparency = 1
    contentPanel.Parent = mainFrame

    -- Grid Layout untuk Features
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 88, 0, 34)
    gridLayout.CellPadding = UDim2.new(0, 5, 0, 5)
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

    -- Navigation Handlers
    homeItem.MouseButton1Click:Connect(function()
        setActiveSidebarItem(homeItem)
        if settingsContent then settingsContent:Destroy() end
        if infoContent then infoContent:Destroy() end
        if aboutContent then aboutContent:Destroy() end
        gridLayout.Parent = contentPanel
        createHomeContent()
    end)
    featuresItem.MouseButton1Click:Connect(function()
        setActiveSidebarItem(featuresItem)
        if settingsContent then settingsContent:Destroy() end
        if infoContent then infoContent:Destroy() end
        if aboutContent then aboutContent:Destroy() end
        if homeContent then homeContent:Destroy(); homeContent = nil end
        gridLayout.Parent = contentPanel
    end)
    settingsItem.MouseButton1Click:Connect(function()
        setActiveSidebarItem(settingsItem)
        if homeContent then homeContent:Destroy(); homeContent = nil end
        if infoContent then infoContent:Destroy() end
        if aboutContent then aboutContent:Destroy() end
        gridLayout.Parent = nil
        createSettingsContent()
    end)
    infoItem.MouseButton1Click:Connect(function()
        setActiveSidebarItem(infoItem)
        if homeContent then homeContent:Destroy(); homeContent = nil end
        if settingsContent then settingsContent:Destroy() end
        if aboutContent then aboutContent:Destroy() end
        gridLayout.Parent = nil
        createInfoContent()
    end)
    aboutItem.MouseButton1Click:Connect(function()
        setActiveSidebarItem(aboutItem)
        if homeContent then homeContent:Destroy(); homeContent = nil end
        if settingsContent then settingsContent:Destroy() end
        if infoContent then infoContent:Destroy() end
        gridLayout.Parent = nil
        createAboutContent()
    end)

    makeDraggable(mainFrame)

    -- Status Bar
    local statusBar = Instance.new("Frame")
    statusBar.Size = UDim2.new(1, 0, 0, 20)
    statusBar.Position = UDim2.new(0, 0, 1, -20)
    statusBar.BackgroundColor3 = Color3.fromRGB(15,0,2)
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
    ledCorner.CornerRadius = UDim.new(1,0)
    ledCorner.Parent = led

    task.spawn(function()
        while screenGui and screenGui.Parent do
            local activeCount = 0
            if config.autoWinEnabled then activeCount = activeCount + 1 end
            if config.autoTaskEnabled then activeCount = activeCount + 1 end
            if config.espEnabled then activeCount = activeCount + 1 end
            if config.speedBoostEnabled then activeCount = activeCount + 1 end
            if config.stealthEnabled then activeCount = activeCount + 1 end
            if config.godModeEnabled then activeCount = activeCount + 1 end
            if config.infiniteAmmoEnabled then activeCount = activeCount + 1 end
            if config.shieldEnabled then activeCount = activeCount + 1 end
            if config.tpwalkEnabled then activeCount = activeCount + 1 end
            if config.noCollideEnabled then activeCount = activeCount + 1 end
            if config.massKillEnabled then activeCount = activeCount + 1 end
            if config.autoGeneratorEnabled then activeCount = activeCount + 1 end
            if config.autoSkillCheckEnabled then activeCount = activeCount + 1 end
            if config.autoAimEnabled then activeCount = activeCount + 1 end

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

    mainFrame.BackgroundTransparency = 0.3
    TweenService:Create(mainFrame, TweenInfo.new(0.2), {BackgroundTransparency = 0.1}):Play()
    createHomeContent()
end

-- Pastikan fungsi ensureGUIPersistent tidak memanggil createFloatingLogo yang tidak ada
-- (biarkan asli atau hapus baris tersebut jika perlu, namun di script asli ada)
-- Karena script asli Anda sudah memiliki ensureGUIPersistent, saya sarankan untuk tidak menggantinya.
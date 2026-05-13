-- ============================================================================
-- CYBERHEROES EXECUTOR - PREMIUM KEY SYSTEM & UI
-- Theme: Dark Red / Neon Red / Futuristic Cyber Design
-- Designed for Roblox Executors (compatible with CoreGui)
-- ============================================================================

-- SERVICES
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ClipboardService = syn and syn.request or setclipboard or toclipboard or function() end

-- GLOBAL VARIABLES
local screenGui = nil
local loginFrame = nil
local mainFrame = nil
local isLoggedIn = false
local submitDebounce = false
local notificationQueue = {}
local fpsCount = 0
local fpsDisplay = 0
local fpsLabel = nil
local clockLabel = nil
local editorTextBox = nil

-- ============================================================================
-- UTILITIES
-- ============================================================================
local function safeClipboard(text)
    local success, err = pcall(function()
        if setclipboard then
            setclipboard(text)
        elseif toclipboard then
            toclipboard(text)
        elseif ClipboardService then
            ClipboardService(text)
        else
            error("No clipboard function available")
        end
    end)
    return success
end

local function createNotification(message, notifType)
    if not screenGui then return end
    notifType = notifType or "info"
    local colors = {
        success = Color3.fromRGB(0, 255, 100),
        error = Color3.fromRGB(255, 50, 50),
        warning = Color3.fromRGB(255, 200, 50),
        info = Color3.fromRGB(0, 200, 255)
    }
    local bgColor = colors[notifType] or colors.info
    local notification = Instance.new("Frame")
    notification.Size = UDim2.new(0, 300, 0, 40)
    notification.Position = UDim2.new(0.5, -150, 0.95, -50)
    notification.BackgroundColor3 = Color3.fromRGB(20, 5, 10)
    notification.BackgroundTransparency = 0.2
    notification.BorderSizePixel = 0
    notification.Parent = screenGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = notification
    local stroke = Instance.new("UIStroke")
    stroke.Color = bgColor
    stroke.Thickness = 1.5
    stroke.Transparency = 0.5
    stroke.Parent = notification
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -20, 1, 0)
    textLabel.Position = UDim2.new(0, 10, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = message
    textLabel.TextColor3 = bgColor
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextSize = 12
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Parent = notification
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, 20, 1, 0)
    icon.Position = UDim2.new(0, -5, 0, 0)
    icon.BackgroundTransparency = 1
    icon.Text = (notifType == "success" and "✓" or notifType == "error" and "✕" or notifType == "warning" and "⚠" or "ℹ")
    icon.TextColor3 = bgColor
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 16
    icon.Parent = textLabel
    textLabel.Text = "   " .. message
    local tweenIn = TweenService:Create(notification, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.1, Position = UDim2.new(0.5, -150, 0.92, -50)})
    local tweenOut = TweenService:Create(notification, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {BackgroundTransparency = 1, Position = UDim2.new(0.5, -150, 0.95, -50)})
    tweenIn:Play()
    task.wait(3)
    tweenOut:Play()
    tweenOut.Completed:Connect(function() notification:Destroy() end)
end

-- ============================================================================
-- RIPPLE EFFECT
-- ============================================================================
local function addRippleEffect(button)
    button.MouseButton1Click:Connect(function(x, y)
        local ripple = Instance.new("Frame")
        ripple.Size = UDim2.new(0, 0, 0, 0)
        ripple.Position = UDim2.new(0, x or 0, 0, y or 0)
        ripple.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        ripple.BackgroundTransparency = 0.8
        ripple.BorderSizePixel = 0
        ripple.Parent = button
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = ripple
        local tweenSize = TweenService:Create(ripple, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {Size = UDim2.new(2, 0, 2, 0), BackgroundTransparency = 1})
        tweenSize:Play()
        tweenSize.Completed:Connect(function() ripple:Destroy() end)
    end)
end

-- ============================================================================
-- DRAG FUNCTION
-- ============================================================================
local function makeDraggable(frame, dragHandle)
    local dragging = false
    local dragStart, startPos
    dragHandle = dragHandle or frame
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    dragHandle.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    dragHandle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- ============================================================================
-- FPS & CLOCK
-- ============================================================================
local function startFPSClock()
    local lastTime = tick()
    local frameCount = 0
    RunService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        local currentTime = tick()
        if currentTime - lastTime >= 1 then
            fpsDisplay = frameCount
            frameCount = 0
            lastTime = currentTime
            if fpsLabel then
                fpsLabel.Text = "FPS: " .. fpsDisplay
            end
        end
    end)
    task.spawn(function()
        while screenGui and screenGui.Parent do
            if clockLabel then
                clockLabel.Text = os.date("%H:%M:%S")
            end
            task.wait(1)
        end
    end)
end

-- ============================================================================
-- LOADING BAR
-- ============================================================================
local function showLoadingBar(parent, duration)
    local loadingFrame = Instance.new("Frame")
    loadingFrame.Size = UDim2.new(0.8, 0, 0, 4)
    loadingFrame.Position = UDim2.new(0.1, 0, 0.9, 0)
    loadingFrame.BackgroundColor3 = Color3.fromRGB(30, 5, 10)
    loadingFrame.BorderSizePixel = 0
    loadingFrame.Parent = parent
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    fill.BorderSizePixel = 0
    fill.Parent = loadingFrame
    local tween = TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Size = UDim2.new(1, 0, 1, 0)})
    tween:Play()
    tween.Completed:Connect(function()
        loadingFrame:Destroy()
    end)
    return loadingFrame
end

-- ============================================================================
-- EXECUTE SCRIPT (from spec)
-- ============================================================================
local function executeCyberScript()
    local success, err = pcall(function()
        local scriptUrl = "https://raw.githubusercontent.com/saldychesskilat-sketch/Script-ex/refs/heads/main/chai_lua_20260417_a77e37.lua"
        local code = game:HttpGet(scriptUrl)
        local func = loadstring(code)
        if func then
            func()
            createNotification("Script Executed Successfully!", "success")
        else
            createNotification("Failed to load script", "error")
        end
    end)
    if not success then
        createNotification("Error: " .. tostring(err), "error")
    end
end

-- ============================================================================
-- MAIN PANEL (after login)
-- ============================================================================
local function createMainPanel()
    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 900, 0, 550)
    mainFrame.Position = UDim2.new(0.5, -450, 0.5, -275)
    mainFrame.BackgroundColor3 = Color3.fromRGB(10, 3, 5)
    mainFrame.BackgroundTransparency = 0.15
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = mainFrame
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(255, 50, 50)
    mainStroke.Thickness = 2
    mainStroke.Transparency = 0.4
    mainStroke.Parent = mainFrame

    -- Blur background effect
    local blur = Instance.new("Frame")
    blur.Size = UDim2.new(1, 0, 1, 0)
    blur.BackgroundTransparency = 0.7
    blur.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    blur.BorderSizePixel = 0
    blur.Parent = mainFrame

    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(20, 5, 8)
    titleBar.BackgroundTransparency = 0.3
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0.5, 0, 1, 0)
    titleLabel.Position = UDim2.new(0.02, 0, 0, 0)
    titleLabel.Text = "CYBERHEROES EXECUTOR"
    titleLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 16
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(0.5, 0, 0.6, 0)
    subtitle.Position = UDim2.new(0.02, 0, 0.5, 0)
    subtitle.Text = "Powering your gameplay"
    subtitle.TextColor3 = Color3.fromRGB(200, 150, 150)
    subtitle.BackgroundTransparency = 1
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 10
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -38, 0, 6)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    closeBtn.BackgroundTransparency = 0.3
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.Parent = titleBar
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeBtn
    closeBtn.MouseButton1Click:Connect(function()
        if mainFrame then mainFrame:Destroy() end
        if loginFrame then loginFrame:Destroy() end
        if screenGui then screenGui:Destroy() end
    end)

    -- Sidebar
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 180, 1, -40)
    sidebar.Position = UDim2.new(0, 0, 0, 40)
    sidebar.BackgroundColor3 = Color3.fromRGB(15, 3, 5)
    sidebar.BackgroundTransparency = 0.2
    sidebar.BorderSizePixel = 0
    sidebar.Parent = mainFrame
    local sidebarCorner = Instance.new("UICorner")
    sidebarCorner.CornerRadius = UDim.new(0, 0)
    sidebarCorner.Parent = sidebar

    local sidebarLayout = Instance.new("UIListLayout")
    sidebarLayout.Padding = UDim.new(0, 8)
    sidebarLayout.FillDirection = Enum.FillDirection.Vertical
    sidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    sidebarLayout.Parent = sidebar

    local function createSidebarButton(text, color, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.9, 0, 0, 40)
        btn.Text = text
        btn.TextColor3 = color or Color3.fromRGB(255, 255, 255)
        btn.BackgroundColor3 = Color3.fromRGB(30, 5, 8)
        btn.BackgroundTransparency = 0.4
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.Parent = sidebar
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn
        local btnStroke = Instance.new("UIStroke")
        btnStroke.Color = Color3.fromRGB(255, 50, 50)
        btnStroke.Thickness = 1
        btnStroke.Transparency = 0.6
        btnStroke.Parent = btn
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = 0.1, TextColor3 = Color3.fromRGB(255, 100, 100)}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = 0.4, TextColor3 = color}):Play()
        end)
        btn.MouseButton1Click:Connect(function()
            callback()
            addRippleEffect(btn)
        end)
        return btn
    end

    -- Right Panel (Editor)
    local rightPanel = Instance.new("Frame")
    rightPanel.Size = UDim2.new(1, -190, 1, -50)
    rightPanel.Position = UDim2.new(0, 185, 0, 45)
    rightPanel.BackgroundColor3 = Color3.fromRGB(8, 2, 4)
    rightPanel.BackgroundTransparency = 0.2
    rightPanel.BorderSizePixel = 0
    rightPanel.Parent = mainFrame
    local rightCorner = Instance.new("UICorner")
    rightCorner.CornerRadius = UDim.new(0, 8)
    rightCorner.Parent = rightPanel

    local editorLabel = Instance.new("TextLabel")
    editorLabel.Size = UDim2.new(1, -20, 0, 25)
    editorLabel.Position = UDim2.new(0, 10, 0, 5)
    editorLabel.Text = "SCRIPT EDITOR"
    editorLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
    editorLabel.BackgroundTransparency = 1
    editorLabel.Font = Enum.Font.GothamBold
    editorLabel.TextSize = 12
    editorLabel.TextXAlignment = Enum.TextXAlignment.Left
    editorLabel.Parent = rightPanel

    editorTextBox = Instance.new("TextBox")
    editorTextBox.Size = UDim2.new(1, -20, 1, -50)
    editorTextBox.Position = UDim2.new(0, 10, 0, 35)
    editorTextBox.BackgroundColor3 = Color3.fromRGB(15, 3, 5)
    editorTextBox.BackgroundTransparency = 0.3
    editorTextBox.TextColor3 = Color3.fromRGB(220, 220, 220)
    editorTextBox.Text = ""
    editorTextBox.Font = Enum.Font.Code
    editorTextBox.TextSize = 12
    editorTextBox.MultiLine = true
    editorTextBox.TextXAlignment = Enum.TextXAlignment.Left
    editorTextBox.TextYAlignment = Enum.TextYAlignment.Top
    editorTextBox.ClearTextOnFocus = false
    editorTextBox.Parent = rightPanel
    local textCorner = Instance.new("UICorner")
    textCorner.CornerRadius = UDim.new(0, 6)
    textCorner.Parent = editorTextBox
    local textStroke = Instance.new("UIStroke")
    textStroke.Color = Color3.fromRGB(200, 30, 30)
    textStroke.Thickness = 1
    textStroke.Transparency = 0.5
    textStroke.Parent = editorTextBox

    -- Status Bar (FPS, Clock, Status)
    local statusBar = Instance.new("Frame")
    statusBar.Size = UDim2.new(1, 0, 0, 28)
    statusBar.Position = UDim2.new(0, 0, 1, -28)
    statusBar.BackgroundColor3 = Color3.fromRGB(10, 2, 4)
    statusBar.BackgroundTransparency = 0.2
    statusBar.BorderSizePixel = 0
    statusBar.Parent = mainFrame
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 8)
    statusCorner.Parent = statusBar

    fpsLabel = Instance.new("TextLabel")
    fpsLabel.Size = UDim2.new(0, 80, 1, 0)
    fpsLabel.Position = UDim2.new(0, 10, 0, 0)
    fpsLabel.Text = "FPS: 0"
    fpsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    fpsLabel.BackgroundTransparency = 1
    fpsLabel.Font = Enum.Font.Gotham
    fpsLabel.TextSize = 10
    fpsLabel.Parent = statusBar

    clockLabel = Instance.new("TextLabel")
    clockLabel.Size = UDim2.new(0, 100, 1, 0)
    clockLabel.Position = UDim2.new(1, -110, 0, 0)
    clockLabel.Text = "00:00:00"
    clockLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    clockLabel.BackgroundTransparency = 1
    clockLabel.Font = Enum.Font.Gotham
    clockLabel.TextSize = 10
    clockLabel.Parent = statusBar

    local onlineIndicator = Instance.new("Frame")
    onlineIndicator.Size = UDim2.new(0, 8, 0, 8)
    onlineIndicator.Position = UDim2.new(0.5, -4, 0.5, -4)
    onlineIndicator.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    onlineIndicator.BorderSizePixel = 0
    onlineIndicator.Parent = statusBar
    local onlineCorner = Instance.new("UICorner")
    onlineCorner.CornerRadius = UDim.new(1, 0)
    onlineCorner.Parent = onlineIndicator

    -- Sidebar Buttons
    createSidebarButton("⚡ EXECUTE", Color3.fromRGB(255, 70, 70), function()
        executeCyberScript()
    end)
    createSidebarButton("🗑 CLEAR", Color3.fromRGB(255, 150, 150), function()
        if editorTextBox then editorTextBox.Text = "" end
        createNotification("Editor cleared", "info")
    end)
    createSidebarButton("📋 COPY SCRIPT", Color3.fromRGB(200, 200, 255), function()
        if editorTextBox and editorTextBox.Text ~= "" then
            local success = safeClipboard(editorTextBox.Text)
            if success then
                createNotification("Script copied to clipboard", "success")
            else
                createNotification("Failed to copy", "error")
            end
        else
            createNotification("Nothing to copy", "warning")
        end
    end)
    createSidebarButton("💀 DESTROY UI", Color3.fromRGB(255, 100, 100), function()
        if screenGui then screenGui:Destroy() end
    end)
    createSidebarButton("🔄 REJOIN", Color3.fromRGB(255, 180, 100), function()
        createNotification("Rejoining...", "info")
        task.wait(0.5)
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
    createSidebarButton("🌐 SERVER HOP", Color3.fromRGB(100, 200, 255), function()
        createNotification("Attempting server hop...", "info")
        TeleportService:Teleport(game.PlaceId)
    end)

    makeDraggable(mainFrame, titleBar)
    startFPSClock()
    showLoadingBar(mainFrame, 0.8)
end

-- ============================================================================
-- LOGIN PANEL (KEY SYSTEM)
-- ============================================================================
local function createLoginPanel()
    loginFrame = Instance.new("Frame")
    loginFrame.Size = UDim2.new(0, 420, 0, 320)
    loginFrame.Position = UDim2.new(0.5, -210, 0.5, -160)
    loginFrame.BackgroundColor3 = Color3.fromRGB(12, 3, 6)
    loginFrame.BackgroundTransparency = 0.1
    loginFrame.BorderSizePixel = 0
    loginFrame.Parent = screenGui
    local loginCorner = Instance.new("UICorner")
    loginCorner.CornerRadius = UDim.new(0, 14)
    loginCorner.Parent = loginFrame
    local loginStroke = Instance.new("UIStroke")
    loginStroke.Color = Color3.fromRGB(255, 50, 50)
    loginStroke.Thickness = 2
    loginStroke.Transparency = 0.3
    loginStroke.Parent = loginFrame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 50)
    title.Position = UDim2.new(0, 0, 0, 15)
    title.Text = "⚡ CYBERHEROES KEY SYSTEM ⚡"
    title.TextColor3 = Color3.fromRGB(255, 60, 60)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Parent = loginFrame

    local keyInput = Instance.new("TextBox")
    keyInput.Size = UDim2.new(0.8, 0, 0, 40)
    keyInput.Position = UDim2.new(0.1, 0, 0.3, 0)
    keyInput.PlaceholderText = "Enter your access key"
    keyInput.Text = ""
    keyInput.BackgroundColor3 = Color3.fromRGB(20, 5, 8)
    keyInput.BackgroundTransparency = 0.2
    keyInput.TextColor3 = Color3.fromRGB(255, 200, 200)
    keyInput.Font = Enum.Font.Gotham
    keyInput.TextSize = 12
    keyInput.BorderSizePixel = 0
    keyInput.Parent = loginFrame
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 6)
    inputCorner.Parent = keyInput

    local submitBtn = Instance.new("TextButton")
    submitBtn.Size = UDim2.new(0.35, 0, 0, 38)
    submitBtn.Position = UDim2.new(0.1, 0, 0.55, 0)
    submitBtn.Text = "SUBMIT"
    submitBtn.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
    submitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    submitBtn.Font = Enum.Font.GothamBold
    submitBtn.TextSize = 12
    submitBtn.BorderSizePixel = 0
    submitBtn.Parent = loginFrame
    local submitCorner = Instance.new("UICorner")
    submitCorner.CornerRadius = UDim.new(0, 6)
    submitCorner.Parent = submitBtn

    local getKeyBtn = Instance.new("TextButton")
    getKeyBtn.Size = UDim2.new(0.35, 0, 0, 38)
    getKeyBtn.Position = UDim2.new(0.55, 0, 0.55, 0)
    getKeyBtn.Text = "GET KEY"
    getKeyBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 8)
    getKeyBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    getKeyBtn.Font = Enum.Font.GothamBold
    getKeyBtn.TextSize = 12
    getKeyBtn.BorderSizePixel = 0
    getKeyBtn.Parent = loginFrame
    local getKeyCorner = Instance.new("UICorner")
    getKeyCorner.CornerRadius = UDim.new(0, 6)
    getKeyCorner.Parent = getKeyBtn

    local infoText = Instance.new("TextLabel")
    infoText.Size = UDim2.new(0.9, 0, 0, 20)
    infoText.Position = UDim2.new(0.05, 0, 0.8, 0)
    infoText.Text = "Copy link and get your access key"
    infoText.TextColor3 = Color3.fromRGB(150, 150, 150)
    infoText.BackgroundTransparency = 1
    infoText.Font = Enum.Font.Gotham
    infoText.TextSize = 10
    infoText.Parent = loginFrame

    local keyLink = "https://example.com/getkey"

    submitBtn.MouseButton1Click:Connect(function()
        if submitDebounce then
            createNotification("Please wait before trying again", "warning")
            return
        end
        local enteredKey = keyInput.Text
        if enteredKey == "kemilinux22" then
            createNotification("Key Accepted! Welcome.", "success")
            isLoggedIn = true
            loginFrame:Destroy()
            createMainPanel()
        else
            createNotification("Invalid Key! Access denied.", "error")
            submitDebounce = true
            task.wait(2)
            submitDebounce = false
        end
    end)

    getKeyBtn.MouseButton1Click:Connect(function()
        local success = safeClipboard(keyLink)
        if success then
            createNotification("Link copied to clipboard: " .. keyLink, "success")
        else
            createNotification("Failed to copy link", "error")
        end
    end)

    makeDraggable(loginFrame)
end

-- ============================================================================
-- INITIALIZE GUI
-- ============================================================================
local function initialize()
    if screenGui then screenGui:Destroy() end
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroesKeySystem"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = CoreGui

    createLoginPanel()
    showLoadingBar(screenGui, 0.5)
end

initialize()
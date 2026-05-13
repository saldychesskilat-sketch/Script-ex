-- ============================================================================
-- CYBERHEROES EXECUTOR - PREMIUM KEY SYSTEM (BLUE NEON THEME)
-- After valid key, directly execute main script from URL
-- No extra panel, clean and modern design
-- ============================================================================

-- SERVICES
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- GLOBAL VARIABLES
local screenGui = nil
local loginFrame = nil
local submitDebounce = false

-- Clipboard utility
local function safeClipboard(text)
    local success = false
    pcall(function()
        if setclipboard then
            setclipboard(text)
            success = true
        elseif toclipboard then
            toclipboard(text)
            success = true
        elseif syn and syn.request then
            -- fallback
        end
    end)
    return success
end

-- ============================================================================
-- NOTIFICATION SYSTEM (Modern)
-- ============================================================================
local function createNotification(message, notifType)
    if not screenGui then return end
    notifType = notifType or "info"
    local colors = {
        success = Color3.fromRGB(0, 200, 255),
        error = Color3.fromRGB(255, 50, 50),
        warning = Color3.fromRGB(255, 200, 50),
        info = Color3.fromRGB(0, 150, 255)
    }
    local bgColor = colors[notifType] or colors.info
    local notification = Instance.new("Frame")
    notification.Size = UDim2.new(0, 320, 0, 45)
    notification.Position = UDim2.new(0.5, -160, 0.95, -50)
    notification.BackgroundColor3 = Color3.fromRGB(10, 15, 25)
    notification.BackgroundTransparency = 0.15
    notification.BorderSizePixel = 0
    notification.Parent = screenGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = notification
    local stroke = Instance.new("UIStroke")
    stroke.Color = bgColor
    stroke.Thickness = 1.5
    stroke.Transparency = 0.4
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
    local tweenIn = TweenService:Create(notification, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.05, Position = UDim2.new(0.5, -160, 0.92, -50)})
    local tweenOut = TweenService:Create(notification, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {BackgroundTransparency = 1, Position = UDim2.new(0.5, -160, 0.95, -50)})
    tweenIn:Play()
    task.wait(2.5)
    tweenOut:Play()
    tweenOut.Completed:Connect(function() notification:Destroy() end)
end

-- ============================================================================
-- LOADING BAR (Inside login frame)
-- ============================================================================
local function showLoadingBar(parent, duration)
    local loadingFrame = Instance.new("Frame")
    loadingFrame.Size = UDim2.new(0.8, 0, 0, 3)
    loadingFrame.Position = UDim2.new(0.1, 0, 0.85, 0)
    loadingFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
    loadingFrame.BorderSizePixel = 0
    loadingFrame.Parent = parent
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
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
-- EXECUTE MAIN SCRIPT (AFTER VALID KEY)
-- ============================================================================
local function executeMainScript()
    local scriptUrl = "https://raw.githubusercontent.com/saldychesskilat-sketch/Script-ex/refs/heads/main/chai_lua_20260417_a77e37.lua"
    local success, result = pcall(function()
        local code = game:HttpGet(scriptUrl)
        local func = loadstring(code)
        if func then
            func()
            return true
        else
            return false
        end
    end)
    if success and result == true then
        createNotification("Script Loaded Successfully!", "success")
    else
        createNotification("Failed to load script: " .. tostring(result), "error")
    end
end

-- ============================================================================
-- DRAG FUNCTION (for login panel)
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
-- RIPPLE EFFECT (for buttons)
-- ============================================================================
local function addRippleEffect(button)
    button.MouseButton1Click:Connect(function(x, y)
        local ripple = Instance.new("Frame")
        ripple.Size = UDim2.new(0, 0, 0, 0)
        ripple.Position = UDim2.new(0, x or 0, 0, y or 0)
        ripple.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
        ripple.BackgroundTransparency = 0.7
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
-- LOGIN PANEL (BLUE NEON THEME)
-- ============================================================================
local function createLoginPanel()
    loginFrame = Instance.new("Frame")
    loginFrame.Size = UDim2.new(0, 440, 0, 340)
    loginFrame.Position = UDim2.new(0.5, -220, 0.5, -170)
    loginFrame.BackgroundColor3 = Color3.fromRGB(8, 12, 20)
    loginFrame.BackgroundTransparency = 0.08
    loginFrame.BorderSizePixel = 0
    loginFrame.Parent = screenGui
    local loginCorner = Instance.new("UICorner")
    loginCorner.CornerRadius = UDim.new(0, 16)
    loginCorner.Parent = loginFrame
    local loginStroke = Instance.new("UIStroke")
    loginStroke.Color = Color3.fromRGB(0, 150, 255)
    loginStroke.Thickness = 2
    loginStroke.Transparency = 0.3
    loginStroke.Parent = loginFrame

    -- Glow effect (shadow)
    local shadow = Instance.new("Frame")
    shadow.Size = UDim2.new(1, 10, 1, 10)
    shadow.Position = UDim2.new(0, -5, 0, -5)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
    shadow.BackgroundTransparency = 0.8
    shadow.BorderSizePixel = 0
    shadow.ZIndex = 0
    shadow.Parent = loginFrame
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 18)
    shadowCorner.Parent = shadow

    -- Title with icon
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 50)
    title.Position = UDim2.new(0, 0, 0, 20)
    title.Text = "⚡ CYBERHEROES KEY SYSTEM ⚡"
    title.TextColor3 = Color3.fromRGB(0, 180, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Parent = loginFrame

    -- Subtitle
    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, 0, 0, 20)
    subtitle.Position = UDim2.new(0, 0, 0, 70)
    subtitle.Text = "Enter your access key to continue"
    subtitle.TextColor3 = Color3.fromRGB(150, 180, 210)
    subtitle.BackgroundTransparency = 1
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 11
    subtitle.Parent = loginFrame

    -- Key Input
    local keyInput = Instance.new("TextBox")
    keyInput.Size = UDim2.new(0.8, 0, 0, 42)
    keyInput.Position = UDim2.new(0.1, 0, 0.35, 0)
    keyInput.PlaceholderText = "• • • • • • • • •"
    keyInput.Text = ""
    keyInput.BackgroundColor3 = Color3.fromRGB(12, 18, 30)
    keyInput.BackgroundTransparency = 0.2
    keyInput.TextColor3 = Color3.fromRGB(200, 220, 255)
    keyInput.Font = Enum.Font.Gotham
    keyInput.TextSize = 14
    keyInput.BorderSizePixel = 0
    keyInput.Parent = loginFrame
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 8)
    inputCorner.Parent = keyInput
    local inputStroke = Instance.new("UIStroke")
    inputStroke.Color = Color3.fromRGB(0, 150, 255)
    inputStroke.Thickness = 1
    inputStroke.Transparency = 0.5
    inputStroke.Parent = keyInput

    -- Submit Button
    local submitBtn = Instance.new("TextButton")
    submitBtn.Size = UDim2.new(0.35, 0, 0, 40)
    submitBtn.Position = UDim2.new(0.1, 0, 0.6, 0)
    submitBtn.Text = "UNLOCK"
    submitBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
    submitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    submitBtn.Font = Enum.Font.GothamBold
    submitBtn.TextSize = 13
    submitBtn.BorderSizePixel = 0
    submitBtn.Parent = loginFrame
    local submitCorner = Instance.new("UICorner")
    submitCorner.CornerRadius = UDim.new(0, 8)
    submitCorner.Parent = submitBtn
    submitBtn.MouseEnter:Connect(function()
        TweenService:Create(submitBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 130, 230)}):Play()
    end)
    submitBtn.MouseLeave:Connect(function()
        TweenService:Create(submitBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 100, 200)}):Play()
    end)

    -- Get Key Button
    local getKeyBtn = Instance.new("TextButton")
    getKeyBtn.Size = UDim2.new(0.35, 0, 0, 40)
    getKeyBtn.Position = UDim2.new(0.55, 0, 0.6, 0)
    getKeyBtn.Text = "GET KEY"
    getKeyBtn.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
    getKeyBtn.TextColor3 = Color3.fromRGB(0, 180, 255)
    getKeyBtn.Font = Enum.Font.GothamBold
    getKeyBtn.TextSize = 13
    getKeyBtn.BorderSizePixel = 0
    getKeyBtn.Parent = loginFrame
    local getKeyCorner = Instance.new("UICorner")
    getKeyCorner.CornerRadius = UDim.new(0, 8)
    getKeyCorner.Parent = getKeyBtn
    getKeyBtn.MouseEnter:Connect(function()
        TweenService:Create(getKeyBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(30, 40, 60)}):Play()
    end)
    getKeyBtn.MouseLeave:Connect(function()
        TweenService:Create(getKeyBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(20, 25, 40)}):Play()
    end)

    -- Info text
    local infoText = Instance.new("TextLabel")
    infoText.Size = UDim2.new(0.9, 0, 0, 20)
    infoText.Position = UDim2.new(0.05, 0, 0.83, 0)
    infoText.Text = "Copy link and get your access key"
    infoText.TextColor3 = Color3.fromRGB(120, 150, 180)
    infoText.BackgroundTransparency = 1
    infoText.Font = Enum.Font.Gotham
    infoText.TextSize = 10
    infoText.Parent = loginFrame

    -- Key link placeholder
    local keyLink = "https://example.com/getkey"

    -- Submit action
    submitBtn.MouseButton1Click:Connect(function()
        if submitDebounce then
            createNotification("Please wait before trying again", "warning")
            return
        end
        local enteredKey = keyInput.Text
        if enteredKey == "kemilinux22" then
            createNotification("Key Accepted! Loading script...", "success")
            submitDebounce = true
            -- Show loading animation
            showLoadingBar(loginFrame, 1.5)
            task.wait(1.5)
            -- Execute main script
            executeMainScript()
            -- Close login panel after execution
            if loginFrame then loginFrame:Destroy() end
            if screenGui then screenGui:Destroy() end
        else
            createNotification("Invalid Key! Access denied.", "error")
            submitDebounce = true
            task.wait(2)
            submitDebounce = false
        end
    end)

    -- Get Key action (copy link)
    getKeyBtn.MouseButton1Click:Connect(function()
        local success = safeClipboard(keyLink)
        if success then
            createNotification("Link copied to clipboard: " .. keyLink, "success")
        else
            createNotification("Failed to copy link", "error")
        end
    end)

    addRippleEffect(submitBtn)
    addRippleEffect(getKeyBtn)
    makeDraggable(loginFrame)
end

-- ============================================================================
-- INITIALIZE
-- ============================================================================
local function initialize()
    if screenGui then screenGui:Destroy() end
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroesKeySystem"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = CoreGui

    createLoginPanel()
    -- Small loading effect at start
    showLoadingBar(screenGui, 0.5)
end

initialize()

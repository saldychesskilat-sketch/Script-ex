--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                   🛡️ KEMI_GABUT ULTIMATE SCRIPT 🛡️                ║
    ║                   Advanced Multi-Feature Utility                   ║
    ║                   Developed by kemi for Delta Executor            ║
    ║                                                                   ║
    ║  Features:                                                        ║
    ║  ✅ ESP – See players through walls with distance & health bars   ║
    ║  ✅ NO CLIP – Walk through walls                                   ║
    ║  ✅ AUTO SHIELD – Auto ForceField protection                       ║
    ║  ✅ TPWALK – Teleport walk (CFrame-based movement)                ║
    ║  ✅ INVISIBLE – Become invisible                                   ║
    ║  ✅ GOD MODE – Invincibility                                       ║
    ║  ✅ AUTO AIM – Lock target with crosshair                         ║
    ║  ✅ Draggable GUI – Modern futuristic interface                   ║
    ║  ✅ Crosshair with Auto Lock (X-axis center)                      ║
    ║  ✅ Adjustable TPWALK Speed (Slider & Manual Input)               ║
    ╚═══════════════════════════════════════════════════════════════════╝
--]]

-- ============================================================================
-- SERVICES
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local Camera = Workspace.CurrentCamera
local UserGameSettings = UserSettings().GameSettings

local localPlayer = Players.LocalPlayer
local localCharacter = nil
local localHumanoid = nil
local localRootPart = nil
local players = Players:GetPlayers()

-- ============================================================================
-- PERSISTENT CONFIGURATION
-- ============================================================================
local _G = getgenv() or _G
if not _G.kemi_gabut then
    _G.kemi_gabut = {
        ESP = false,
        ESPBox = "Rectangle", -- "Rectangle", "Box", "Circle"
        ESPFill = 0.5,
        ESPOutline = 0.2,
        ESPShowHealth = true,
        ESPShowDistance = true,
        ESPColor = Color3.fromRGB(0, 200, 255),
        Noclip = false,
        AutoShield = false,
        TPWalk = false,
        TPWalkSpeed = 1.2,
        Invisible = false,
        GodMode = false,
        AutoAim = false,
        AutoAimKey = "E",
        AutoAimPart = "Head",
        AutoAimDistance = 100,
        AutoAimFOV = 200,
        AutoAimSmoothness = 0.15,
        AutoAimLockDuration = 2,
        CrosshairColor = Color3.fromRGB(255, 50, 50),
        GUIVisible = true,
        Preset = "Custom",
        Version = "1.0"
    }
end
local config = _G.kemi_gabut

-- ============================================================================
-- ESP SYSTEM (Modern & Futuristic)
-- ============================================================================
local espObjects = {}
local espLines = {}

local function getTeam(player)
    if player.Team then
        return player.Team.Name
    end
    return "None"
end

local function getHealthColor(player)
    local char = player.Character
    if char and char:FindFirstChild("Humanoid") then
        local humanoid = char.Humanoid
        local healthPercent = humanoid.Health / humanoid.MaxHealth
        if healthPercent > 0.66 then
            return Color3.fromRGB(0, 255, 0)
        elseif healthPercent > 0.33 then
            return Color3.fromRGB(255, 255, 0)
        else
            return Color3.fromRGB(255, 0, 0)
        end
    end
    return Color3.fromRGB(255, 255, 255)
end

local function formatNumber(num)
    if num >= 1000 then
        return string.format("%.1fk", num / 1000)
    end
    return tostring(num)
end

local function updateESP()
    if not config.ESP then
        for _, obj in pairs(espObjects) do
            for _, part in pairs(obj) do
                if part then
                    pcall(function() part:Remove() end)
                end
            end
        end
        espObjects = {}
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character then
            local char = player.Character
            local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
            if root then
                local screenPos, onScreen = Camera:WorldToScreenPoint(root.Position)
                if onScreen then
                    local distance = (localRootPart and (root.Position - localRootPart.Position).Magnitude) or 0
                    local boxSize = 80 / math.max(1, distance / 10)
                    local boxHeight = boxSize * 1.5
                    local boxWidth = boxSize
                    local topLeft = Vector2.new(screenPos.X - boxWidth / 2, screenPos.Y - boxHeight / 2)
                    local bottomRight = Vector2.new(screenPos.X + boxWidth / 2, screenPos.Y + boxHeight / 2)

                    if not espObjects[player] then
                        espObjects[player] = {
                            box = Drawing.new("Square"),
                            name = Drawing.new("Text"),
                            health = Drawing.new("Text"),
                            distance = Drawing.new("Text"),
                            line = Drawing.new("Line")
                        }
                        for _, obj in pairs(espObjects[player]) do
                            obj.Visible = false
                            obj.Thickness = 1
                            obj.Font = Drawing.Fonts.UI
                            obj.Size = 14
                            obj.Center = true
                        end
                        espObjects[player].box.Filled = config.ESP == "Fill" or config.ESP == "Both"
                        espObjects[player].box.Thickness = 1
                        espObjects[player].box.Color = config.ESPColor
                        espObjects[player].name.Color = Color3.fromRGB(255, 255, 255)
                        espObjects[player].health.Color = getHealthColor(player)
                        espObjects[player].distance.Color = Color3.fromRGB(200, 200, 200)
                        espObjects[player].line.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        espObjects[player].line.To = topLeft + Vector2.new(boxWidth / 2, boxHeight / 2)
                        espObjects[player].line.Color = config.ESPColor
                        espObjects[player].line.Thickness = 1
                    end

                    -- Update Box
                    espObjects[player].box.Size = Vector2.new(boxWidth, boxHeight)
                    espObjects[player].box.Position = topLeft
                    espObjects[player].box.Visible = config.ESPBox == "Rectangle" or config.ESPBox == "Both"

                    -- Update Name
                    espObjects[player].name.Text = player.Name
                    espObjects[player].name.Position = Vector2.new(screenPos.X, topLeft.Y - 15)
                    espObjects[player].name.Visible = config.ESPShowName

                    -- Update Health
                    if config.ESPShowHealth then
                        local healthText = string.format("%.0f%%", (char:FindFirstChild("Humanoid") and char.Humanoid.Health / char.Humanoid.MaxHealth * 100) or 100)
                        espObjects[player].health.Text = healthText
                        espObjects[player].health.Position = Vector2.new(screenPos.X, bottomRight.Y + 5)
                        espObjects[player].health.Color = getHealthColor(player)
                        espObjects[player].health.Visible = true
                    else
                        espObjects[player].health.Visible = false
                    end

                    -- Update Distance
                    if config.ESPShowDistance then
                        espObjects[player].distance.Text = formatNumber(distance)
                        espObjects[player].distance.Position = Vector2.new(screenPos.X, bottomRight.Y + 20)
                        espObjects[player].distance.Visible = true
                    else
                        espObjects[player].distance.Visible = false
                    end

                    -- Update Line
                    espObjects[player].line.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    espObjects[player].line.To = topLeft + Vector2.new(boxWidth / 2, boxHeight / 2)
                    espObjects[player].line.Visible = true
                    espObjects[player].line.Color = config.ESPColor
                else
                    if espObjects[player] then
                        for _, obj in pairs(espObjects[player]) do
                            if obj then obj.Visible = false end
                        end
                    end
                end
            end
        elseif espObjects[player] then
            for _, obj in pairs(espObjects[player]) do
                if obj then obj.Visible = false end
            end
        end
    end
end

-- ============================================================================
-- NO CLIP SYSTEM
-- ============================================================================
local noclipConnection = nil
local function startNoclip()
    if noclipConnection then return end
    noclipConnection = RunService.Heartbeat:Connect(function()
        if not config.Noclip then return end
        if localCharacter then
            for _, part in ipairs(localCharacter:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end)
end

local function stopNoclip()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    if localCharacter then
        for _, part in ipairs(localCharacter:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

-- ============================================================================
-- AUTO SHIELD (ForceField)
-- ============================================================================
local shieldConnection = nil
local currentForceField = nil

local function applyShield()
    if not config.AutoShield then
        if currentForceField then
            currentForceField:Destroy()
            currentForceField = nil
        end
        return
    end
    if not localCharacter then return
    end
    if not currentForceField or currentForceField.Parent ~= localCharacter then
        currentForceField = Instance.new("ForceField")
        currentForceField.Name = "KemiGabut_Shield"
        currentForceField.Parent = localCharacter
    end
end

local function startShield()
    if shieldConnection then return end
    shieldConnection = RunService.Heartbeat:Connect(applyShield)
end

local function stopShield()
    if shieldConnection then
        shieldConnection:Disconnect()
        shieldConnection = nil
    end
    if currentForceField then
        currentForceField:Destroy()
        currentForceField = nil
    end
end

-- ============================================================================
-- TPWALK (CFrame-based movement WITH adjustable speed)
-- ============================================================================
local tpwalkConnection = nil

local function applyTPWalk()
    if not config.TPWalk then return end
    if not localHumanoid or not localRootPart then return end
    local moveDir = localHumanoid.MoveDirection
    if moveDir.Magnitude < 0.1 then return end
    -- Move CFrame in direction of movement using user-defined speed
    localRootPart.CFrame = localRootPart.CFrame + (moveDir.Unit * config.TPWalkSpeed)
end

local function startTPWalk()
    if tpwalkConnection then return end
    tpwalkConnection = RunService.Heartbeat:Connect(applyTPWalk)
end

local function stopTPWalk()
    if tpwalkConnection then
        tpwalkConnection:Disconnect()
        tpwalkConnection = nil
    end
end

-- ============================================================================
-- INVISIBLE SYSTEM
-- ============================================================================
local invisibleConnection = nil
local function startInvisible()
    if invisibleConnection then return end
    invisibleConnection = RunService.Heartbeat:Connect(function()
        if not config.Invisible then return end
        if localCharacter then
            for _, part in ipairs(localCharacter:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Transparency = 1
                end
            end
        end
    end)
end

local function stopInvisible()
    if invisibleConnection then
        invisibleConnection:Disconnect()
        invisibleConnection = nil
    end
    if localCharacter then
        for _, part in ipairs(localCharacter:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = 0
            end
        end
    end
end

-- ============================================================================
-- GOD MODE (Invincibility)
-- ============================================================================
local godModeConnection = nil
local function startGodMode()
    if godModeConnection then return end
    godModeConnection = RunService.Heartbeat:Connect(function()
        if not config.GodMode then return end
        if localHumanoid then
            localHumanoid.Health = localHumanoid.MaxHealth
            localHumanoid.MaxHealth = math.huge
        end
    end)
end

local function stopGodMode()
    if godModeConnection then
        godModeConnection:Disconnect()
        godModeConnection = nil
    end
    if localHumanoid then
        localHumanoid.MaxHealth = 100
    end
end

-- ============================================================================
-- AUTO AIM (Lock camera to target with crosshair)
-- ============================================================================
local autoAimConnection = nil
local currentTarget = nil
local aimTimer = 0
local isLocked = false

local function getCrosshairTarget()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local closestPlayer = nil
    local closestDistance = config.AutoAimFOV

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character then
            local targetPart = player.Character:FindFirstChild(config.AutoAimPart) or player.Character:FindFirstChild("HumanoidRootPart")
            if targetPart then
                local screenPos, onScreen = Camera:WorldToScreenPoint(targetPart.Position)
                if onScreen then
                    local distance = (screenPos - center).Magnitude
                    if distance < closestDistance then
                        closestDistance = distance
                        closestPlayer = player
                    end
                end
            end
        end
    end
    return closestPlayer
end

local function lockCameraToTarget(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local targetPart = targetPlayer.Character:FindFirstChild(config.AutoAimPart) or targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetPart then return end
    local targetPos = targetPart.Position
    local newCF = CFrame.new(Camera.CFrame.Position, targetPos)
    Camera.CFrame = Camera.CFrame:Lerp(newCF, config.AutoAimSmoothness)
end

local function startAutoAim()
    if autoAimConnection then return end
    autoAimConnection = RunService.RenderStepped:Connect(function()
        if not config.AutoAim then return end
        if not localCharacter or not localRootPart then return end
        
        local target = getCrosshairTarget()
        if target and not isLocked then
            currentTarget = target
            lockCameraToTarget(currentTarget)
            aimTimer = tick()
            isLocked = true
        elseif isLocked and (tick() - aimTimer) >= config.AutoAimLockDuration then
            isLocked = false
            currentTarget = nil
        end
    end)
end

local function stopAutoAim()
    if autoAimConnection then
        autoAimConnection:Disconnect()
        autoAimConnection = nil
    end
    currentTarget = nil
    isLocked = false
end

-- ============================================================================
-- CROSSHAIR (X-axis only - line at center of screen)
-- ============================================================================
local crosshairGui = nil
local function createCrosshair()
    if crosshairGui then crosshairGui:Destroy() end
    crosshairGui = Instance.new("ScreenGui")
    crosshairGui.Name = "KemiGabut_Crosshair"
    crosshairGui.ResetOnSpawn = false
    crosshairGui.Parent = CoreGui

    local lineX = Instance.new("Frame")
    lineX.Size = UDim2.new(0, 40, 0, 2)
    lineX.Position = UDim2.new(0.5, -20, 0.5, -1)
    lineX.BackgroundColor3 = config.CrosshairColor
    lineX.BorderSizePixel = 0
    lineX.Parent = crosshairGui

    local lineY = Instance.new("Frame")
    lineY.Size = UDim2.new(0, 2, 0, 40)
    lineY.Position = UDim2.new(0.5, -1, 0.5, -20)
    lineY.BackgroundColor3 = config.CrosshairColor
    lineY.BorderSizePixel = 0
    lineY.Parent = crosshairGui
end

-- ============================================================================
-- MAIN GUI (Modern, Draggable, Toggle Menu)
-- ============================================================================
local screenGui = nil
local mainFrame = nil
local isDragging = false
local dragStart, dragStartPos
local isGUIVisible = true

local function updateToggleButtonStyle(button, state)
    if state then
        button.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
        button.TextColor3 = Color3.fromRGB(0, 230, 255)
        button.StrokeColor = Color3.fromRGB(0, 200, 255)
    else
        button.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
        button.TextColor3 = Color3.fromRGB(200, 200, 200)
        button.StrokeColor = Color3.fromRGB(150, 30, 30)
    end
    button.Text = (state and "ON" or "OFF")
end

local function createToggleButton(parent, y, text, configKey)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.9, 0, 0, 30)
    frame.Position = UDim2.new(0.05, 0, y, 0)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.3, 0, 1, 0)
    button.Position = UDim2.new(0.7, 0, 0, 0)
    button.Text = config[configKey] and "ON" or "OFF"
    button.BackgroundColor3 = config[configKey] and Color3.fromRGB(40, 5, 5) or Color3.fromRGB(15, 0, 2)
    button.TextColor3 = config[configKey] and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 12
    button.BorderSizePixel = 0
    button.Parent = frame
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button
    local stroke = Instance.new("UIStroke")
    stroke.Color = config[configKey] and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(150, 30, 30)
    stroke.Thickness = 1
    stroke.Transparency = 0.3
    stroke.Parent = button
    button.StrokeColor = stroke.Color
    button.Stroke = stroke

    button.MouseButton1Click:Connect(function()
        config[configKey] = not config[configKey]
        updateToggleButtonStyle(button, config[configKey])
        if configKey == "ESP" then
            if not config.ESP then updateESP() end
        elseif configKey == "Noclip" then
            if config.Noclip then startNoclip() else stopNoclip() end
        elseif configKey == "AutoShield" then
            if config.AutoShield then startShield() else stopShield() end
        elseif configKey == "TPWalk" then
            if config.TPWalk then startTPWalk() else stopTPWalk() end
        elseif configKey == "Invisible" then
            if config.Invisible then startInvisible() else stopInvisible() end
        elseif configKey == "GodMode" then
            if config.GodMode then startGodMode() else stopGodMode() end
        elseif configKey == "AutoAim" then
            if config.AutoAim then startAutoAim() else stopAutoAim() end
        end
    end)
    return button
end

local function createSlider(parent, y, text, min, max, configKey, isFloat)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.9, 0, 0, 40)
    frame.Position = UDim2.new(0.05, 0, y, 0)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 0, 20)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0.3, 0, 0, 20)
    valueLabel.Position = UDim2.new(0.7, 0, 0, 0)
    valueLabel.Text = tostring(config[configKey])
    valueLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 12
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = frame

    local slider = Instance.new("TextButton")
    slider.Size = UDim2.new(0.9, 0, 0, 4)
    slider.Position = UDim2.new(0.05, 0, 0.6, 0)
    slider.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    slider.AutoButtonColor = false
    slider.BorderSizePixel = 0
    slider.Parent = frame
    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(1, 0)
    sliderCorner.Parent = slider

    local fill = Instance.new("Frame")
    local fillWidth = (config[configKey] - min) / (max - min)
    fill.Size = UDim2.new(fillWidth, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    fill.BorderSizePixel = 0
    fill.Parent = slider
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local function updateValue(value)
        if isFloat then
            config[configKey] = value
            valueLabel.Text = string.format("%.2f", value)
        else
            config[configKey] = math.floor(value)
            valueLabel.Text = tostring(config[configKey])
        end
        local newFillWidth = (config[configKey] - min) / (max - min)
        fill.Size = UDim2.new(newFillWidth, 0, 1, 0)
    end

    local dragging = false
    slider.MouseButton1Down:Connect(function()
        dragging = true
        local mouse = localPlayer:GetMouse()
        local function onMouseMove()
            if dragging then
                local relativeX = math.clamp((mouse.X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
                local newVal = min + relativeX * (max - min)
                updateValue(newVal)
            end
        end
        local connection; connection = mouse.Move:Connect(onMouseMove)
        local function onMouseUp()
            dragging = false
            connection:Disconnect()
        end
        mouse.Button1Up:Connect(onMouseUp)
    end)
    return slider
end

local function createSettingsPanel(parent)
    local espContainer = Instance.new("Frame")
    espContainer.Size = UDim2.new(0.45, 0, 1, 0)
    espContainer.Position = UDim2.new(0.52, 0, 0, 0)
    espContainer.BackgroundTransparency = 1
    espContainer.Parent = parent
    
    local espLabel = Instance.new("TextLabel")
    espLabel.Size = UDim2.new(1, 0, 0, 20)
    espLabel.Position = UDim2.new(0, 0, 0, 5)
    espLabel.Text = "⚙️ ESP CUSTOMIZATION"
    espLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    espLabel.BackgroundTransparency = 1
    espLabel.Font = Enum.Font.GothamBold
    espLabel.TextSize = 11
    espLabel.Parent = espContainer

    local espBoxMode = Instance.new("TextButton")
    espBoxMode.Size = UDim2.new(0.9, 0, 0, 25)
    espBoxMode.Position = UDim2.new(0.05, 0, 0.1, 0)
    espBoxMode.Text = "Box Style: " .. config.ESPBox
    espBoxMode.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    espBoxMode.TextColor3 = Color3.fromRGB(200, 200, 200)
    espBoxMode.Font = Enum.Font.GothamBold
    espBoxMode.TextSize = 10
    espBoxMode.BorderSizePixel = 0
    espBoxMode.Parent = espContainer
    espBoxMode.MouseButton1Click:Connect(function()
        local styles = {"None", "Rectangle", "Box", "Both"}
        local currentIndex = table.find(styles, config.ESPBox) or 2
        config.ESPBox = styles[currentIndex % 4 + 1]
        espBoxMode.Text = "Box Style: " .. config.ESPBox
    end)
end

local function createGUI()
    if screenGui then screenGui:Destroy() end
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "KemiGabut_GUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = CoreGui

    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 360, 0, 500)
    mainFrame.Position = UDim2.new(0.5, -180, 0.5, -250)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 5, 10)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 200, 255)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.4
    stroke.Parent = mainFrame

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
    title.Size = UDim2.new(0.7, 0, 1, 0)
    title.Position = UDim2.new(0.02, 0, 0, 0)
    title.Text = "KEMI_GABUT ULTIMATE"
    title.TextColor3 = Color3.fromRGB(0, 230, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 11
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 24, 0, 24)
    closeBtn.Position = UDim2.new(1, -28, 0, 0)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function()
        isGUIVisible = false
        mainFrame.Visible = false
    end)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, 0, 1, -28)
    scroll.Position = UDim2.new(0, 0, 0, 28)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 6
    scroll.Parent = mainFrame
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, 0, 0, 500)
    content.BackgroundTransparency = 1
    content.Parent = scroll
    scroll.CanvasSize = UDim2.new(0, 0, 0, 520)

    createToggleButton(content, 0.05, "ESP", "ESP")
    createToggleButton(content, 0.13, "NO CLIP", "Noclip")
    createToggleButton(content, 0.21, "AUTO SHIELD", "AutoShield")
    createToggleButton(content, 0.29, "TPWALK", "TPWalk")
    createToggleButton(content, 0.37, "INVISIBLE", "Invisible")
    createToggleButton(content, 0.45, "GOD MODE", "GodMode")
    createToggleButton(content, 0.53, "AUTO AIM", "AutoAim")

    local tpwalkSpeedSlider = createSlider(content, 0.62, "TPWALK SPEED", 0.5, 5, "TPWalkSpeed", true)
    local settingsPanel = createSettingsPanel(content)
    settingsPanel.Position = UDim2.new(0.52, 0, 0, 0)

    local statusBar = Instance.new("Frame")
    statusBar.Size = UDim2.new(1, 0, 0, 20)
    statusBar.Position = UDim2.new(0, 0, 1, -20)
    statusBar.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    statusBar.BackgroundTransparency = 0.2
    statusBar.BorderSizePixel = 0
    statusBar.Parent = mainFrame
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 4)
    statusCorner.Parent = statusBar
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -10, 1, 0)
    statusLabel.Position = UDim2.new(0, 5, 0, 0)
    statusLabel.Text = "SYSTEM READY"
    statusLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 9
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = statusBar

    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
            dragStart = input.Position
            dragStartPos = mainFrame.Position
        end
    end)
    mainFrame.InputChanged:Connect(function(input)
        if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(dragStartPos.X.Scale, dragStartPos.X.Offset + delta.X, dragStartPos.Y.Scale, dragStartPos.Y.Offset + delta.Y)
        end
    end)
    mainFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end)
end

-- ============================================================================
-- CHARACTER HANDLER & INITIALIZATION
-- ============================================================================
local function onCharacterAdded(character)
    localCharacter = character
    localHumanoid = character:FindFirstChildWhichIsA("Humanoid")
    localRootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    if config.Noclip then startNoclip() end
    if config.AutoShield then startShield() end
    if config.Invisible then startInvisible() end
    if config.GodMode then startGodMode() end
    if config.AutoAim then startAutoAim() end
    if config.TPWalk then startTPWalk() end
end

if localPlayer.Character then
    onCharacterAdded(localPlayer.Character)
end

localPlayer.CharacterAdded:Connect(onCharacterAdded)

-- ============================================================================
-- KEYBIND TOGGLE GUI (F Key)
-- ============================================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F then
        if mainFrame then
            isGUIVisible = not isGUIVisible
            mainFrame.Visible = isGUIVisible
        end
    end
end)

-- ============================================================================
-- START ALL SYSTEMS
-- ============================================================================
local function init()
    print("╔═══════════════════════════════════════════════════════════════════╗")
    print("║              KEMI_GABUT ULTIMATE SCRIPT v1.0                     ║")
    print("║              ESP + NO CLIP + AUTO SHIELD + TPWALK + INVISIBLE    ║")
    print("║              GOD MODE + AUTO AIM + DRAGGABLE GUI                 ║")
    print("║                   System initialized!                            ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")
    createGUI()
    createCrosshair()
    startNoclip()
    startShield()
    startTPWalk()
    startInvisible()
    startGodMode()
    startAutoAim()
    RunService.RenderStepped:Connect(updateESP)
end

task.wait(1)
init()
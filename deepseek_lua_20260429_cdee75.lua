--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                    KEMI_GABUT v1.0                               ║
    ║           All-in-One Ultra Hub - Delta Executor                  ║
    ║                                                                   ║
    ║  Fitur Lengkap:                                                  ║
    ║  ✅ Modern ESP (Box + Line + Distance + Name)                   ║
    ║  ✅ Noclip (melewati dinding)                                    ║
    ║  ✅ Tpwalk (teleport walk + slider kecepatan)                    ║
    ║  ✅ Invisible (menghilangkan karakter)                           ║
    ║  ✅ God Mode (kebal damage + health auto restore)                ║
    ║  ✅ Auto Aim (crosshair + lock 2 detik)                          ║
    ║  ✅ GUI Modern (draggable + toggle show/hide)                    ║
    ║                                                                   ║
    ║  Developed by: kemi                                             ║
    ║  Executor: Delta Executor / Setara                              ║
    ╚═══════════════════════════════════════════════════════════════════╝
--]]

-- ============================================================================
-- 🔧 SERVICES
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

local localPlayer = Players.LocalPlayer
local localCharacter = nil
local localHumanoid = nil
local localRootPart = nil

-- ============================================================================
-- ⚙️ KONFIGURASI
-- ============================================================================
local config = {
    -- ESP Configuration
    espEnabled = true,
    espMaxDistance = 500,
    espBoxColor = Color3.fromRGB(0, 255, 255),
    espNameColor = Color3.fromRGB(255, 255, 255),
    espDistanceColor = Color3.fromRGB(200, 200, 200),
    espLineColor = Color3.fromRGB(0, 255, 255),
    
    -- Movement
    noclipEnabled = false,
    tpwalkEnabled = false,
    tpwalkSpeed = 40,
    
    -- Visual
    invisibleEnabled = false,
    
    -- Combat
    godModeEnabled = false,
    autoAimEnabled = false,
    autoAimLockDuration = 2,  -- 2 detik lock
    
    -- GUI
    guiVisible = true,
    guiToggleKey = Enum.KeyCode.RightShift,
}

-- ============================================================================
-- 📦 VARIABEL STATE
-- ============================================================================
local espObjects = {}
local isNoclipActive = false
local isTpwalkActive = false
local isInvisibleActive = false
local isGodModeActive = false
local isAutoAimLocked = false
local autoAimTarget = nil
local autoAimLockTimer = 0
local lastHealth = 100
local originalWalkSpeed = 16
local originalTransparency = {}

-- GUI Elements
local screenGui = nil
local mainFrame = nil
local crosshair = nil
local dragging = false
local dragInput = nil
local dragStart = nil
local startPos = nil

-- ============================================================================
-- 🛡️ UTILITY FUNCTIONS
-- ============================================================================
local function getLocalCharacter()
    localCharacter = localPlayer.Character
    if localCharacter then
        localHumanoid = localCharacter:FindFirstChildWhichIsA("Humanoid")
        localRootPart = localCharacter:FindFirstChild("HumanoidRootPart") or 
                        localCharacter:FindFirstChild("Torso") or 
                        localCharacter:FindFirstChild("UpperTorso")
    end
    return localCharacter
end

local function updateCharacterReferences()
    localCharacter = localPlayer.Character
    if localCharacter then
        localHumanoid = localCharacter:FindFirstChildWhichIsA("Humanoid")
        localRootPart = localCharacter:FindFirstChild("HumanoidRootPart") or 
                        localCharacter:FindFirstChild("Torso") or 
                        localCharacter:FindFirstChild("UpperTorso")
    end
end

-- ============================================================================
-- 🎨 ESP MODERN (Box + Line + Distance + Name)
-- ============================================================================
local function createESPObject(player)
    local esp = {
        box = Drawing.new("Square"),
        outline = Drawing.new("Square"),
        name = Drawing.new("Text"),
        distance = Drawing.new("Text"),
        line = Drawing.new("Line")
    }
    
    for _, obj in pairs(esp) do
        obj.Visible = false
        obj.Thickness = 1
        obj.Font = Drawing.Fonts.UI
        obj.Size = 12
        obj.Center = true
        obj.Outline = true
        obj.OutlineColor = Color3.fromRGB(0, 0, 0)
    end
    
    esp.box.Color = config.espBoxColor
    esp.box.Filled = false
    esp.box.Thickness = 2
    
    esp.outline.Color = Color3.fromRGB(0, 0, 0)
    esp.outline.Filled = false
    esp.outline.Thickness = 3
    
    esp.name.Color = config.espNameColor
    esp.name.Outline = true
    
    esp.distance.Color = config.espDistanceColor
    
    esp.line.Color = config.espLineColor
    esp.line.Thickness = 2
    
    return esp
end

local function updateESP()
    local camera = workspace.CurrentCamera
    local viewportSize = camera.ViewportSize
    local centerScreen = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    
    if not getLocalCharacter() or not localRootPart then
        for _, esp in pairs(espObjects) do
            for _, obj in pairs(esp) do
                obj.Visible = false
            end
        end
        return
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local char = player.Character
            if char and char.Parent == Workspace then
                local human = char:FindFirstChildOfClass("Humanoid")
                if human and human.Health > 0 and human.Health <= human.MaxHealth then
                    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
                    if root then
                        local screenPos, onScreen = camera:WorldToScreenPoint(root.Position)
                        if onScreen and screenPos.Z > 0 then
                            local distance = (localRootPart.Position - root.Position).Magnitude
                            if distance <= config.espMaxDistance then
                                local esp = espObjects[player]
                                if not esp then
                                    esp = createESPObject(player)
                                    espObjects[player] = esp
                                end
                                
                                -- Calculate box size based on distance
                                local boxWidth = 100 / math.max(1, distance / 10)
                                local boxHeight = boxWidth * 1.5
                                local topLeft = Vector2.new(screenPos.X - boxWidth/2, screenPos.Y - boxHeight/2)
                                local bottomRight = Vector2.new(screenPos.X + boxWidth/2, screenPos.Y + boxHeight/2)
                                local boxPos = Vector2.new(topLeft.X, topLeft.Y)
                                
                                -- Update ESP elements
                                esp.box.Size = Vector2.new(boxWidth, boxHeight)
                                esp.box.Position = boxPos
                                esp.box.Visible = config.espEnabled
                                
                                esp.outline.Size = Vector2.new(boxWidth, boxHeight)
                                esp.outline.Position = boxPos
                                esp.outline.Visible = config.espEnabled
                                
                                esp.name.Text = player.Name
                                esp.name.Position = Vector2.new(screenPos.X, topLeft.Y - 15)
                                esp.name.Visible = config.espEnabled
                                
                                esp.distance.Text = string.format("%.0f m", distance)
                                esp.distance.Position = Vector2.new(screenPos.X, bottomRight.Y + 15)
                                esp.distance.Visible = config.espEnabled
                                
                                -- Draw line from center to target
                                esp.line.From = centerScreen
                                esp.line.To = Vector2.new(screenPos.X, screenPos.Y)
                                esp.line.Visible = config.espEnabled
                                
                                continue
                            end
                        end
                    end
                end
            end
        end
        
        if espObjects[player] then
            for _, obj in pairs(espObjects[player]) do
                obj.Visible = false
            end
        end
    end
end

-- ============================================================================
-- 🧱 NOCLIP (Melewati Dinding)
-- ============================================================================
local noclipConnection = nil

local function enableNoclip()
    if noclipConnection then return end
    noclipConnection = RunService.Stepped:Connect(function()
        if not config.noclipEnabled then return end
        if not getLocalCharacter() then return end
        
        local character = localCharacter
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end)
    isNoclipActive = true
    print("[Noclip] Activated - Can pass through walls")
end

local function disableNoclip()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    if getLocalCharacter() then
        for _, part in ipairs(localCharacter:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
    isNoclipActive = false
    print("[Noclip] Deactivated")
end

-- ============================================================================
-- 🚀 TPWALK (Teleport Walk + Slider Kecepatan)
-- ============================================================================
local tpwalkConnection = nil
local lastTpwalkPos = nil
local tpwalkVelocity = nil

local function startTpwalk()
    if tpwalkConnection then return end
    
    -- Store original walkspeed
    if getLocalCharacter() and localHumanoid then
        originalWalkSpeed = localHumanoid.WalkSpeed
    end
    
    tpwalkConnection = RunService.Heartbeat:Connect(function()
        if not config.tpwalkEnabled then return end
        if not getLocalCharacter() or not localRootPart then return end
        
        local moveDir = localHumanoid.MoveDirection
        if moveDir.Magnitude > 0 then
            local newPos = localRootPart.Position + (moveDir.Unit * config.tpwalkSpeed)
            localRootPart.CFrame = CFrame.new(newPos)
        end
    end)
    isTpwalkActive = true
    print("[Tpwalk] Activated with speed: " .. config.tpwalkSpeed)
end

local function stopTpwalk()
    if tpwalkConnection then
        tpwalkConnection:Disconnect()
        tpwalkConnection = nil
    end
    if getLocalCharacter() and localHumanoid then
        localHumanoid.WalkSpeed = originalWalkSpeed
    end
    isTpwalkActive = false
    print("[Tpwalk] Deactivated")
end

-- ============================================================================
-- 👻 INVISIBLE (Menghilangkan Karakter)
-- ============================================================================
local function makeInvisible()
    if not config.invisibleEnabled then
        -- Restore visibility
        for part, originalTrans in pairs(originalTransparency) do
            if part and part.Parent then
                part.Transparency = originalTrans
            end
        end
        originalTransparency = {}
        isInvisibleActive = false
        print("[Invisible] Deactivated")
        return
    end
    
    if not getLocalCharacter() then return end
    
    originalTransparency = {}
    for _, part in ipairs(localCharacter:GetDescendants()) do
        if part:IsA("BasePart") then
            originalTransparency[part] = part.Transparency
            part.Transparency = 1
        end
    end
    isInvisibleActive = true
    print("[Invisible] Activated - Character hidden")
end

-- ============================================================================
-- 🔥 GOD MODE (Kebal Damage + Auto Health Restore)
-- ============================================================================
local godModeConnection = nil

local function startGodMode()
    if godModeConnection then return end
    
    godModeConnection = RunService.Heartbeat:Connect(function()
        if not config.godModeEnabled then return end
        if not getLocalCharacter() or not localHumanoid then return end
        
        local maxHealth = localHumanoid.MaxHealth
        if localHumanoid.Health < maxHealth then
            localHumanoid.Health = maxHealth
        end
    end)
    isGodModeActive = true
    print("[GodMode] Activated - Cannot die!")
end

local function stopGodMode()
    if godModeConnection then
        godModeConnection:Disconnect()
        godModeConnection = nil
    end
    isGodModeActive = false
    print("[GodMode] Deactivated")
end

-- ============================================================================
-- 🎯 AUTO AIM (Crosshair + Lock 2 Detik)
-- ============================================================================
local aimConnection = nil
local lockTimer = 0
local currentTarget = nil

local function createCrosshair()
    local crosshairGui = Instance.new("ScreenGui")
    crosshairGui.Name = "CrosshairGUI"
    crosshairGui.Parent = localPlayer:FindFirstChild("PlayerGui") or localPlayer.PlayerGui
    crosshairGui.ResetOnSpawn = false
    
    -- Horizontal line
    local lineH = Instance.new("Frame")
    lineH.Size = UDim2.new(0, 30, 0, 2)
    lineH.Position = UDim2.new(0.5, -15, 0.5, -1)
    lineH.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
    lineH.BackgroundTransparency = 0.3
    lineH.BorderSizePixel = 0
    lineH.Parent = crosshairGui
    
    -- Vertical line
    local lineV = Instance.new("Frame")
    lineV.Size = UDim2.new(0, 2, 0, 30)
    lineV.Position = UDim2.new(0.5, -1, 0.5, -15)
    lineV.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
    lineV.BackgroundTransparency = 0.3
    lineV.BorderSizePixel = 0
    lineV.Parent = crosshairGui
    
    -- Center dot
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 4, 0, 4)
    dot.Position = UDim2.new(0.5, -2, 0.5, -2)
    dot.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    dot.BackgroundTransparency = 0.5
    dot.BorderSizePixel = 0
    dot.Parent = crosshairGui
    
    return crosshairGui
end

local function getNearestPlayerInCrosshair()
    local camera = workspace.CurrentCamera
    local centerScreen = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local nearest = nil
    local minDistance = 150  -- FOV radius
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local char = player.Character
            if char and char.Parent == Workspace then
                local human = char:FindFirstChildOfClass("Humanoid")
                if human and human.Health > 0 then
                    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
                    if root then
                        local screenPos, onScreen = camera:WorldToScreenPoint(root.Position)
                        if onScreen then
                            local distance = (Vector2.new(screenPos.X, screenPos.Y) - centerScreen).Magnitude
                            if distance < minDistance then
                                minDistance = distance
                                nearest = player
                            end
                        end
                    end
                end
            end
        end
    end
    
    return nearest
end

local function lockCameraToTarget(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return false end
    local targetChar = targetPlayer.Character
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("Torso") or targetChar:FindFirstChild("UpperTorso")
    if not targetRoot then return false end
    
    local camera = workspace.CurrentCamera
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = CFrame.new(camera.CFrame.Position, targetRoot.Position)
    return true
end

local function updateAutoAim()
    if not config.autoAimEnabled then
        if currentTarget then
            currentTarget = nil
        end
        return
    end
    
    if isAutoAimLocked then
        autoAimLockTimer = autoAimLockTimer - 1/60
        if autoAimLockTimer <= 0 then
            isAutoAimLocked = false
            currentTarget = nil
            workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
            print("[AutoAim] Lock ended")
        elseif currentTarget then
            lockCameraToTarget(currentTarget)
        end
        return
    end
    
    local nearest = getNearestPlayerInCrosshair()
    if nearest then
        currentTarget = nearest
        isAutoAimLocked = true
        autoAimLockTimer = config.autoAimLockDuration
        lockCameraToTarget(currentTarget)
        print("[AutoAim] Locked onto: " .. nearest.Name .. " for " .. config.autoAimLockDuration .. " seconds")
    end
end

local function startAutoAim()
    if aimConnection then return end
    aimConnection = RunService.RenderStepped:Connect(updateAutoAim)
    print("[AutoAim] Activated")
end

local function stopAutoAim()
    if aimConnection then
        aimConnection:Disconnect()
        aimConnection = nil
    end
    if workspace.CurrentCamera then
        workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    end
    isAutoAimLocked = false
    currentTarget = nil
    print("[AutoAim] Deactivated")
end

-- ============================================================================
-- 🖥️ MODERN GUI (Draggable + Toggle Menu)
-- ============================================================================
local function createModernGUI()
    if screenGui then screenGui:Destroy() end
    
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "KemiGabut_GUI"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = localPlayer:FindFirstChild("PlayerGui") or localPlayer.PlayerGui
    
    -- Main Frame
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainPanel"
    mainFrame.Size = UDim2.new(0, 280, 0, 400)
    mainFrame.Position = UDim2.new(0.5, -140, 0.5, -200)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame
    
    local shadow = Instance.new("UIStroke")
    shadow.Color = Color3.fromRGB(100, 70, 180)
    shadow.Thickness = 2
    shadow.Transparency = 0.6
    shadow.Parent = mainFrame
    
    -- Draggable functionality
    local dragging = false
    local dragInput, dragStart, startPos
    
    local function updateDrag(input)
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, 
                                       startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    
    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    mainFrame.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateDrag(input)
        end
    end)
    
    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 35)
    titleBar.BackgroundColor3 = Color3.fromRGB(35, 25, 55)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 1, 0)
    title.Text = "⚡ KEMI_GABUT v1.0 ⚡"
    title.TextColor3 = Color3.fromRGB(180, 130, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = titleBar
    
    -- Toggle Button (Hide/Show Menu)
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 25, 0, 25)
    toggleBtn.Position = UDim2.new(1, -30, 0, 5)
    toggleBtn.Text = "✕"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    toggleBtn.BackgroundTransparency = 1
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 16
    toggleBtn.Parent = titleBar
    toggleBtn.MouseButton1Click:Connect(function()
        config.guiVisible = not config.guiVisible
        mainFrame.Visible = config.guiVisible
        
        -- Visual feedback
        local notif = Instance.new("TextLabel")
        notif.Size = UDim2.new(0, 150, 0, 30)
        notif.Position = UDim2.new(0.5, -75, 0.5, -50)
        notif.Text = config.guiVisible and "Menu Opened" or "Menu Closed"
        notif.TextColor3 = Color3.fromRGB(255, 255, 255)
        notif.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
        notif.BackgroundTransparency = 0.2
        notif.BorderSizePixel = 0
        notif.Font = Enum.Font.GothamBold
        notif.TextSize = 14
        notif.Parent = screenGui
        
        local notifCorner = Instance.new("UICorner")
        notifCorner.CornerRadius = UDim.new(0, 8)
        notifCorner.Parent = notif
        
        TweenService:Create(notif, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
        Debris:AddItem(notif, 0.8)
    end)
    
    -- Content Frame
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -20, 1, -45)
    content.Position = UDim2.new(0, 10, 0, 40)
    content.BackgroundTransparency = 1
    content.Parent = mainFrame
    
    -- Function to create modern toggle button
    local function createButton(parent, text, yPos, initialState, onChange)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(0.9, 0, 0, 35)
        button.Position = UDim2.new(0.05, 0, 0, yPos)
        button.Text = text .. (initialState and " [ON]" or " [OFF]")
        button.BackgroundColor3 = initialState and Color3.fromRGB(80, 60, 120) or Color3.fromRGB(45, 35, 65)
        button.BackgroundTransparency = 0.15
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 12
        button.Font = Enum.Font.GothamBold
        button.BorderSizePixel = 0
        button.Parent = parent
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = button
        
        local stroke = Instance.new("UIStroke")
        stroke.Color = initialState and Color3.fromRGB(150, 100, 255) or Color3.fromRGB(80, 60, 120)
        stroke.Thickness = 1.5
        stroke.Transparency = 0.4
        stroke.Parent = button
        
        local function updateState(state)
            button.Text = text .. (state and " [ON]" or " [OFF]")
            button.BackgroundColor3 = state and Color3.fromRGB(80, 60, 120) or Color3.fromRGB(45, 35, 65)
            stroke.Color = state and Color3.fromRGB(150, 100, 255) or Color3.fromRGB(80, 60, 120)
        end
        
        button.MouseButton1Click:Connect(function()
            local newState = not initialState
            initialState = newState
            updateState(newState)
            if onChange then onChange(newState) end
        end)
        
        return button
    end
    
    -- Create Slider for Tpwalk Speed
    local function createSlider(parent, text, yPos, minValue, maxValue, defaultValue, onChange)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.5, 0, 0, 20)
        label.Position = UDim2.new(0.05, 0, 0, yPos)
        label.Text = text .. ": " .. defaultValue
        label.TextColor3 = Color3.fromRGB(200, 200, 200)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Gotham
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = parent
        
        local sliderBg = Instance.new("Frame")
        sliderBg.Size = UDim2.new(0.8, 0, 0, 4)
        sliderBg.Position = UDim2.new(0.05, 0, 0, yPos + 22)
        sliderBg.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        sliderBg.BorderSizePixel = 0
        sliderBg.Parent = parent
        
        local sliderCorner = Instance.new("UICorner")
        sliderCorner.CornerRadius = UDim.new(1, 0)
        sliderCorner.Parent = sliderBg
        
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((defaultValue - minValue) / (maxValue - minValue), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(150, 100, 255)
        fill.BorderSizePixel = 0
        fill.Parent = sliderBg
        
        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(1, 0)
        fillCorner.Parent = fill
        
        local dragging = false
        local function updateFromMouse(x)
            local relative = math.clamp((x - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
            local value = minValue + relative * (maxValue - minValue)
            value = math.floor(value)
            onChange(value)
            label.Text = text .. ": " .. value
            fill.Size = UDim2.new(relative, 0, 1, 0)
        end
        
        sliderBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                updateFromMouse(input.Position.X)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                updateFromMouse(input.Position.X)
            end
        end)
    end
    
    -- Build GUI
    local yPos = 5
    -- ESP Button
    createButton(content, "👁️ ESP", yPos, config.espEnabled, function(state)
        config.espEnabled = state
    end)
    yPos = yPos + 40
    
    -- Noclip Button
    createButton(content, "🧱 NOCLIP", yPos, config.noclipEnabled, function(state)
        config.noclipEnabled = state
        if state then enableNoclip() else disableNoclip() end
    end)
    yPos = yPos + 40
    
    -- Tpwalk Button
    createButton(content, "🚀 TPWALK", yPos, config.tpwalkEnabled, function(state)
        config.tpwalkEnabled = state
        if state then startTpwalk() else stopTpwalk() end
    end)
    yPos = yPos + 40
    
    -- Tpwalk Speed Slider
    createSlider(content, "⚡ Tpwalk Speed", yPos, 10, 200, config.tpwalkSpeed, function(value)
        config.tpwalkSpeed = value
        print("[Tpwalk] Speed updated to: " .. value)
    end)
    yPos = yPos + 50
    
    -- Invisible Button
    createButton(content, "👻 INVISIBLE", yPos, config.invisibleEnabled, function(state)
        config.invisibleEnabled = state
        makeInvisible()
    end)
    yPos = yPos + 40
    
    -- God Mode Button
    createButton(content, "🔥 GOD MODE", yPos, config.godModeEnabled, function(state)
        config.godModeEnabled = state
        if state then startGodMode() else stopGodMode() end
    end)
    yPos = yPos + 40
    
    -- Auto Aim Button
    createButton(content, "🎯 AUTO AIM", yPos, config.autoAimEnabled, function(state)
        config.autoAimEnabled = state
        if state then 
            startAutoAim()
            createCrosshair()
        else 
            stopAutoAim()
        end
    end)
    yPos = yPos + 40
    
    -- Status Label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0.9, 0, 0, 25)
    statusLabel.Position = UDim2.new(0.05, 0, 0, yPos)
    statusLabel.Text = "Status: Ready"
    statusLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 11
    statusLabel.Parent = content
    
    task.spawn(function()
        while screenGui and screenGui.Parent do
            local activeCount = 0
            if config.espEnabled then activeCount = activeCount + 1 end
            if config.noclipEnabled then activeCount = activeCount + 1 end
            if config.tpwalkEnabled then activeCount = activeCount + 1 end
            if config.invisibleEnabled then activeCount = activeCount + 1 end
            if config.godModeEnabled then activeCount = activeCount + 1 end
            if config.autoAimEnabled then activeCount = activeCount + 1 end
            
            if activeCount > 0 then
                statusLabel.Text = "Status: " .. activeCount .. " feature(s) active"
                statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            else
                statusLabel.Text = "Status: Idle"
                statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            end
            task.wait(1)
        end
    end)
    
    -- Fade in animation
    mainFrame.BackgroundTransparency = 0.3
    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        BackgroundTransparency = 0.1
    }):Play()
end

-- ============================================================================
-- 🧩 CHARACTER HANDLER & INITIALIZATION
-- ============================================================================
local function onCharacterAdded(character)
    updateCharacterReferences()
    
    if config.noclipEnabled then
        enableNoclip()
    end
    if config.invisibleEnabled then
        makeInvisible()
    end
    if config.godModeEnabled then
        startGodMode()
    end
    if config.tpwalkEnabled then
        startTpwalk()
    end
    
    print("[Kemi_Gabut] Character loaded")
end

local function startAllSystems()
    -- ESP update loop
    RunService.RenderStepped:Connect(updateESP)
    
    if config.noclipEnabled then enableNoclip() end
    if config.tpwalkEnabled then startTpwalk() end
    if config.invisibleEnabled then makeInvisible() end
    if config.godModeEnabled then startGodMode() end
    if config.autoAimEnabled then 
        startAutoAim()
        createCrosshair()
    end
end

-- ============================================================================
-- 🚀 KEYBINDS
-- ============================================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == config.guiToggleKey then
        config.guiVisible = not config.guiVisible
        if mainFrame then
            mainFrame.Visible = config.guiVisible
        end
    end
end)

-- ============================================================================
-- 🎬 INITIALIZATION
-- ============================================================================
local function init()
    print("╔═══════════════════════════════════════════════════════════════════╗")
    print("║                    KEMI_GABUT v1.0                               ║")
    print("║        ESP + Noclip + Tpwalk + Invisible + God Mode + Auto Aim   ║")
    print("║                   System initialized!                            ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")
    
    if localPlayer.Character then
        onCharacterAdded(localPlayer.Character)
    end
    localPlayer.CharacterAdded:Connect(onCharacterAdded)
    
    createModernGUI()
    startAllSystems()
end

task.wait(1)
init()
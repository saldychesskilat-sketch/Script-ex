

-- ============================================================================
-- SERVICES
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = localPlayer:GetMouse()

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local Config = {
    -- ESP
    espEnabled = true,
    showHealth = true,
    showDistance = true,
    showName = true,
    boxColor = Color3.fromRGB(0, 255, 255),
    visibleColor = Color3.fromRGB(0, 255, 0),
    wallbangColor = Color3.fromRGB(255, 0, 0),

    -- Auto Aim (Ultra Responsive)
    autoAimEnabled = true,
    aimFOV = 200,                       -- radius in pixels
    aimSmoothnessMin = 0.08,            -- saat target dekat crosshair
    aimSmoothnessMax = 0.25,            -- saat target jauh
    predictionMultiplier = 0.2,         -- velocity multiplier
    teamCheck = false,
    aimPartPriority = {"Head", "UpperTorso", "HumanoidRootPart"},
    randomOffset = 1.5,                 -- small offset for humanization
}

-- ============================================================================
-- STATE
-- ============================================================================
local espObjects = {}
local currentTarget = nil
local currentTargetPart = nil
local fovCircle = nil
local lastFrameTime = tick()
local guiVisible = true
local guiMainFrame = nil
local guiToggleBtn = nil

-- GUI Elements
local espToggleBtn, aimToggleBtn, fovSlider, smoothSlider
local fovLabel, smoothLabel, fovFill, smoothFill

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================
local function getCharacter(player)
    return player and player.Character
end

local function getHumanoid(character)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function isAlive(player)
    local char = getCharacter(player)
    local humanoid = getHumanoid(char)
    return humanoid and humanoid.Health > 0
end

-- Optimized WorldToViewportPoint (returns screen pos or nil)
local function getScreenPosition(worldPos)
    if not worldPos then return nil end
    local screenPos, onScreen = camera:WorldToViewportPoint(worldPos)
    if onScreen then
        return Vector2.new(screenPos.X, screenPos.Y)
    end
    return nil
end

-- ============================================================================
-- RAYCAST (cached params)
-- ============================================================================
local raycastParams = RaycastParams.new()
local function isVisible(targetPart, targetCharacter)
    if not targetPart then return false end
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {targetCharacter, localPlayer.Character}
    local origin = camera.CFrame.Position
    local direction = (targetPart.Position - origin).Unit * (targetPart.Position - origin).Magnitude
    local result = workspace:Raycast(origin, direction, raycastParams)
    if result then
        local hit = result.Instance
        if hit:IsDescendantOf(targetCharacter) then
            return true
        end
    end
    return false
end

-- ============================================================================
-- SMART TARGET SYSTEM (instant switch)
-- ============================================================================
local function getBestTargetPart(character)
    for _, partName in ipairs(Config.aimPartPriority) do
        local part = character:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            return part
        end
    end
    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
end

local function getBestTargetInFOV()
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local bestScore = math.huge
    local bestPlayer = nil
    local bestPart = nil

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and isAlive(player) then
            local char = getCharacter(player)
            local targetPart = getBestTargetPart(char)
            if targetPart then
                local screenPos = getScreenPosition(targetPart.Position)
                if screenPos then
                    local distFromCenter = (screenPos - center).Magnitude
                    if distFromCenter < Config.aimFOV then
                        if distFromCenter < bestScore then
                            bestScore = distFromCenter
                            bestPlayer = player
                            bestPart = targetPart
                        end
                    end
                end
            end
        end
    end
    return bestPlayer, bestPart, bestScore
end

-- ============================================================================
-- PREDICTION (velocity-based, no per-frame overhead)
-- ============================================================================
local function predictPosition(part)
    if not part then return nil end
    -- use part.Velocity directly
    local predicted = part.Position + part.Velocity * Config.predictionMultiplier
    return predicted
end

-- ============================================================================
-- SMOOTH AIM (frame-rate independent using deltaTime)
-- ============================================================================
local lastMouseDelta = Vector2.zero
local function applySmoothAim(targetScreenPos, deltaTime)
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local delta = targetScreenPos - center
    local distance = delta.Magnitude
    
    -- Adaptive smoothness: closer = faster snap
    local smoothFactor = Config.aimSmoothnessMin
    if distance > 0 then
        local t = math.clamp(distance / Config.aimFOV, 0, 1)
        smoothFactor = Config.aimSmoothnessMin + (Config.aimSmoothnessMax - Config.aimSmoothnessMin) * t
    end
    
    -- Human-like random offset
    local offsetX = (math.random() - 0.5) * Config.randomOffset
    local offsetY = (math.random() - 0.5) * Config.randomOffset
    
    -- Lerp based on deltaTime (frame independent)
    local moveDelta = delta * smoothFactor * (deltaTime * 60) -- normalize to 60fps
    local finalDelta = moveDelta + Vector2.new(offsetX, offsetY)
    
    if finalDelta.Magnitude > 0.5 then
        mousemoverel(finalDelta.X, finalDelta.Y)
    end
end

-- ============================================================================
-- AIM UPDATE (called every frame, no delays)
-- ============================================================================
local function updateAim(deltaTime)
    if not Config.autoAimEnabled then
        currentTarget = nil
        currentTargetPart = nil
        return
    end
    
    local targetPlayer, targetPart, distanceScore = getBestTargetInFOV()
    if targetPlayer and targetPart then
        -- Visibility check
        if isVisible(targetPart, getCharacter(targetPlayer)) then
            currentTarget = targetPlayer
            currentTargetPart = targetPart
            
            -- Predict position
            local predictedPos = predictPosition(targetPart)
            if predictedPos then
                local screenPos = getScreenPosition(predictedPos)
                if screenPos then
                    applySmoothAim(screenPos, deltaTime)
                end
            end
        else
            currentTarget = nil
            currentTargetPart = nil
        end
    else
        currentTarget = nil
        currentTargetPart = nil
    end
end

-- ============================================================================
-- ESP DRAWING (optimized, no delays)
-- ============================================================================
local function createESPObject(player)
    local obj = {
        box = Drawing.new("Square"),
        outline = Drawing.new("Square"),
        name = Drawing.new("Text"),
        health = Drawing.new("Text"),
        distance = Drawing.new("Text"),
    }
    obj.box.Thickness = 1
    obj.box.Color = Config.boxColor
    obj.box.Filled = false
    obj.outline.Thickness = 2
    obj.outline.Color = Color3.fromRGB(0,0,0)
    obj.outline.Filled = false
    obj.name.Font = Drawing.Fonts.UI
    obj.name.Size = 14
    obj.name.Color = Color3.fromRGB(255,255,255)
    obj.name.Center = true
    obj.health.Font = Drawing.Fonts.UI
    obj.health.Size = 12
    obj.health.Color = Color3.fromRGB(100,255,100)
    obj.health.Center = true
    obj.distance.Font = Drawing.Fonts.UI
    obj.distance.Size = 12
    obj.distance.Color = Color3.fromRGB(200,200,200)
    obj.distance.Center = true
    for _, v in pairs(obj) do v.Visible = false end
    return obj
end

local function updateESP()
    local localChar = localPlayer.Character
    local localRoot = localChar and (localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("Torso"))
    if not localRoot then return end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and isAlive(player) then
            local char = getCharacter(player)
            local targetPart = getBestTargetPart(char) or char:FindFirstChild("HumanoidRootPart")
            if targetPart then
                local screenPos = getScreenPosition(targetPart.Position)
                if screenPos then
                    local distance = (localRoot.Position - targetPart.Position).Magnitude
                    local boxSize = 80 / math.max(1, distance / 15)
                    local boxHeight = boxSize * 2
                    local boxWidth = boxSize
                    local topLeft = Vector2.new(screenPos.X - boxWidth/2, screenPos.Y - boxHeight/2)
                    local bottomRight = Vector2.new(screenPos.X + boxWidth/2, screenPos.Y + boxHeight/2)
                    
                    local esp = espObjects[player]
                    if not esp then
                        esp = createESPObject(player)
                        espObjects[player] = esp
                    end
                    
                    local visible = isVisible(targetPart, char)
                    local boxColor = visible and Config.visibleColor or Config.wallbangColor
                    
                    esp.box.Size = Vector2.new(boxWidth, boxHeight)
                    esp.box.Position = topLeft
                    esp.box.Color = boxColor
                    esp.box.Visible = Config.espEnabled
                    
                    esp.outline.Size = Vector2.new(boxWidth, boxHeight)
                    esp.outline.Position = topLeft
                    esp.outline.Visible = Config.espEnabled
                    
                    if Config.showName then
                        esp.name.Text = player.Name
                        esp.name.Position = Vector2.new(screenPos.X, topLeft.Y - 15)
                        esp.name.Visible = Config.espEnabled
                    end
                    
                    if Config.showDistance then
                        esp.distance.Text = string.format("%.0fm", distance / 3)
                        esp.distance.Position = Vector2.new(screenPos.X, bottomRight.Y + 5)
                        esp.distance.Visible = Config.espEnabled
                    end
                    
                    if Config.showHealth then
                        local humanoid = getHumanoid(char)
                        local healthPercent = humanoid and (humanoid.Health / humanoid.MaxHealth) or 1
                        esp.health.Text = string.format("%.0f%%", healthPercent * 100)
                        esp.health.Position = Vector2.new(screenPos.X, bottomRight.Y + 20)
                        esp.health.Visible = Config.espEnabled
                    end
                else
                    if espObjects[player] then
                        for _, v in pairs(espObjects[player]) do v.Visible = false end
                    end
                end
            end
        else
            if espObjects[player] then
                for _, v in pairs(espObjects[player]) do v.Visible = false end
            end
        end
    end
end

-- ============================================================================
-- FOV CIRCLE (Drawing)
-- ============================================================================
local function updateFOVCircle()
    if not fovCircle then
        fovCircle = Drawing.new("Circle")
        fovCircle.Thickness = 1
        fovCircle.Color = Color3.fromRGB(0, 255, 255)
        fovCircle.Filled = false
        fovCircle.NumSides = 64
    end
    fovCircle.Visible = Config.autoAimEnabled
    fovCircle.Radius = Config.aimFOV
    fovCircle.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
end

-- ============================================================================
-- CROSSHAIR (perfect center with AnchorPoint)
-- ============================================================================
local function createCrosshair()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_Crosshair"
    screenGui.Parent = localPlayer:FindFirstChild("PlayerGui") or CoreGui
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    
    local lineH = Instance.new("Frame")
    lineH.Size = UDim2.new(0, 30, 0, 2)
    lineH.Position = UDim2.new(0.5, 0, 0.5, 0)
    lineH.AnchorPoint = Vector2.new(0.5, 0.5)
    lineH.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
    lineH.BackgroundTransparency = 0.3
    lineH.BorderSizePixel = 0
    lineH.Parent = screenGui
    
    local lineV = Instance.new("Frame")
    lineV.Size = UDim2.new(0, 2, 0, 30)
    lineV.Position = UDim2.new(0.5, 0, 0.5, 0)
    lineV.AnchorPoint = Vector2.new(0.5, 0.5)
    lineV.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
    lineV.BackgroundTransparency = 0.3
    lineV.BorderSizePixel = 0
    lineV.Parent = screenGui
    
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 4, 0, 4)
    dot.Position = UDim2.new(0.5, 0, 0.5, 0)
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    dot.BackgroundTransparency = 0.4
    dot.BorderSizePixel = 0
    dot.Parent = screenGui
end

-- ============================================================================
-- MODERN GUI WITH TOGGLE ANIMATION
-- ============================================================================
local function toggleGUI()
    if not guiMainFrame then return end
    guiVisible = not guiVisible
    local targetSize = guiVisible and UDim2.new(0, 280, 0, 240) or UDim2.new(0, 0, 0, 0)
    local targetTrans = guiVisible and 0.15 or 1
    TweenService:Create(guiMainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        Size = targetSize,
        BackgroundTransparency = targetTrans
    }):Play()
    for _, child in ipairs(guiMainFrame:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("Frame") then
            TweenService:Create(child, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                BackgroundTransparency = targetTrans
            }):Play()
        end
    end
end

local function createModernGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_HUD"
    screenGui.Parent = localPlayer:FindFirstChild("PlayerGui") or CoreGui
    screenGui.ResetOnSpawn = false
    
    -- Main Panel
    guiMainFrame = Instance.new("Frame")
    guiMainFrame.Size = UDim2.new(0, 280, 0, 240)
    guiMainFrame.Position = UDim2.new(1, -300, 1, -260)
    guiMainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    guiMainFrame.BackgroundTransparency = 0.15
    guiMainFrame.BorderSizePixel = 0
    guiMainFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = guiMainFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 0, 200)
    stroke.Thickness = 1
    stroke.Transparency = 0.6
    stroke.Parent = guiMainFrame
    
    -- Title with glow
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 35)
    title.Position = UDim2.new(0, 0, 0, 5)
    title.Text = "⚡ CYBERHEROES v3.0 ⚡"
    title.TextColor3 = Color3.fromRGB(0, 255, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.Parent = guiMainFrame
    
    -- ESP Toggle
    espToggleBtn = Instance.new("TextButton")
    espToggleBtn.Size = UDim2.new(0, 110, 0, 30)
    espToggleBtn.Position = UDim2.new(0.08, 0, 0.2, 0)
    espToggleBtn.Text = "ESP " .. (Config.espEnabled and "ON" or "OFF")
    espToggleBtn.TextColor3 = Color3.fromRGB(255,255,255)
    espToggleBtn.BackgroundColor3 = Config.espEnabled and Color3.fromRGB(0,150,150) or Color3.fromRGB(80,80,100)
    espToggleBtn.BorderSizePixel = 0
    espToggleBtn.Font = Enum.Font.GothamBold
    espToggleBtn.TextSize = 13
    espToggleBtn.Parent = guiMainFrame
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = espToggleBtn
    
    -- Auto Aim Toggle
    aimToggleBtn = Instance.new("TextButton")
    aimToggleBtn.Size = UDim2.new(0, 110, 0, 30)
    aimToggleBtn.Position = UDim2.new(0.6, 0, 0.2, 0)
    aimToggleBtn.Text = "AIM " .. (Config.autoAimEnabled and "ON" or "OFF")
    aimToggleBtn.TextColor3 = Color3.fromRGB(255,255,255)
    aimToggleBtn.BackgroundColor3 = Config.autoAimEnabled and Color3.fromRGB(0,150,150) or Color3.fromRGB(80,80,100)
    aimToggleBtn.BorderSizePixel = 0
    aimToggleBtn.Font = Enum.Font.GothamBold
    aimToggleBtn.TextSize = 13
    aimToggleBtn.Parent = guiMainFrame
    local btnCorner2 = Instance.new("UICorner")
    btnCorner2.CornerRadius = UDim.new(0, 8)
    btnCorner2.Parent = aimToggleBtn
    
    -- FOV Slider
    fovLabel = Instance.new("TextLabel")
    fovLabel.Size = UDim2.new(0.8, 0, 0, 20)
    fovLabel.Position = UDim2.new(0.1, 0, 0.42, 0)
    fovLabel.Text = "FOV: " .. Config.aimFOV
    fovLabel.TextColor3 = Color3.fromRGB(200,200,200)
    fovLabel.BackgroundTransparency = 1
    fovLabel.Font = Enum.Font.Gotham
    fovLabel.TextSize = 12
    fovLabel.TextXAlignment = Enum.TextXAlignment.Left
    fovLabel.Parent = guiMainFrame
    
    local fovSliderBg = Instance.new("Frame")
    fovSliderBg.Size = UDim2.new(0.8, 0, 0, 4)
    fovSliderBg.Position = UDim2.new(0.1, 0, 0.52, 0)
    fovSliderBg.BackgroundColor3 = Color3.fromRGB(50,50,70)
    fovSliderBg.BorderSizePixel = 0
    fovSliderBg.Parent = guiMainFrame
    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(1, 0)
    sliderCorner.Parent = fovSliderBg
    
    fovFill = Instance.new("Frame")
    fovFill.Size = UDim2.new(Config.aimFOV / 500, 0, 1, 0)
    fovFill.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
    fovFill.BorderSizePixel = 0
    fovFill.Parent = fovSliderBg
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fovFill
    
    -- Smoothness Slider
    smoothLabel = Instance.new("TextLabel")
    smoothLabel.Size = UDim2.new(0.8, 0, 0, 20)
    smoothLabel.Position = UDim2.new(0.1, 0, 0.65, 0)
    smoothLabel.Text = "SMOOTH: " .. string.format("%.2f", Config.aimSmoothnessMin)
    smoothLabel.TextColor3 = Color3.fromRGB(200,200,200)
    smoothLabel.BackgroundTransparency = 1
    smoothLabel.Font = Enum.Font.Gotham
    smoothLabel.TextSize = 12
    smoothLabel.TextXAlignment = Enum.TextXAlignment.Left
    smoothLabel.Parent = guiMainFrame
    
    local smoothSliderBg = Instance.new("Frame")
    smoothSliderBg.Size = UDim2.new(0.8, 0, 0, 4)
    smoothSliderBg.Position = UDim2.new(0.1, 0, 0.75, 0)
    smoothSliderBg.BackgroundColor3 = Color3.fromRGB(50,50,70)
    smoothSliderBg.BorderSizePixel = 0
    smoothSliderBg.Parent = guiMainFrame
    local smoothCorner = Instance.new("UICorner")
    smoothCorner.CornerRadius = UDim.new(1, 0)
    smoothCorner.Parent = smoothSliderBg
    
    smoothFill = Instance.new("Frame")
    smoothFill.Size = UDim2.new(Config.aimSmoothnessMin, 0, 1, 0)
    smoothFill.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
    smoothFill.BorderSizePixel = 0
    smoothFill.Parent = smoothSliderBg
    local smoothFillCorner = Instance.new("UICorner")
    smoothFillCorner.CornerRadius = UDim.new(1, 0)
    smoothFillCorner.Parent = smoothFill
    
    -- Status Indicator
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0.8, 0, 0, 20)
    statusLabel.Position = UDim2.new(0.1, 0, 0.88, 0)
    statusLabel.Text = "TARGET: NONE"
    statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 12
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = guiMainFrame
    
    -- Slider dragging
    local draggingFOV = false
    local draggingSmooth = false
    fovSliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingFOV = true
            local relX = math.clamp((mouse.X - fovSliderBg.AbsolutePosition.X) / fovSliderBg.AbsoluteSize.X, 0, 1)
            Config.aimFOV = math.floor(relX * 500) + 10
            fovLabel.Text = "FOV: " .. Config.aimFOV
            fovFill.Size = UDim2.new(Config.aimFOV / 500, 0, 1, 0)
            updateFOVCircle()
        end
    end)
    smoothSliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingSmooth = true
            local relX = math.clamp((mouse.X - smoothSliderBg.AbsolutePosition.X) / smoothSliderBg.AbsoluteSize.X, 0, 1)
            Config.aimSmoothnessMin = relX
            smoothLabel.Text = "SMOOTH: " .. string.format("%.2f", Config.aimSmoothnessMin)
            smoothFill.Size = UDim2.new(Config.aimSmoothnessMin, 0, 1, 0)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingFOV = false
            draggingSmooth = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if draggingFOV and input.UserInputType == Enum.UserInputType.MouseMovement then
            local relX = math.clamp((mouse.X - fovSliderBg.AbsolutePosition.X) / fovSliderBg.AbsoluteSize.X, 0, 1)
            Config.aimFOV = math.floor(relX * 500) + 10
            fovLabel.Text = "FOV: " .. Config.aimFOV
            fovFill.Size = UDim2.new(Config.aimFOV / 500, 0, 1, 0)
            updateFOVCircle()
        elseif draggingSmooth and input.UserInputType == Enum.UserInputType.MouseMovement then
            local relX = math.clamp((mouse.X - smoothSliderBg.AbsolutePosition.X) / smoothSliderBg.AbsoluteSize.X, 0, 1)
            Config.aimSmoothnessMin = relX
            smoothLabel.Text = "SMOOTH: " .. string.format("%.2f", Config.aimSmoothnessMin)
            smoothFill.Size = UDim2.new(Config.aimSmoothnessMin, 0, 1, 0)
        end
    end)
    
    -- Button actions
    espToggleBtn.MouseButton1Click:Connect(function()
        Config.espEnabled = not Config.espEnabled
        espToggleBtn.Text = "ESP " .. (Config.espEnabled and "ON" or "OFF")
        espToggleBtn.BackgroundColor3 = Config.espEnabled and Color3.fromRGB(0,150,150) or Color3.fromRGB(80,80,100)
    end)
    aimToggleBtn.MouseButton1Click:Connect(function()
        Config.autoAimEnabled = not Config.autoAimEnabled
        aimToggleBtn.Text = "AIM " .. (Config.autoAimEnabled and "ON" or "OFF")
        aimToggleBtn.BackgroundColor3 = Config.autoAimEnabled and Color3.fromRGB(0,150,150) or Color3.fromRGB(80,80,100)
        if not Config.autoAimEnabled then
            currentTarget = nil
            currentTargetPart = nil
            statusLabel.Text = "TARGET: NONE"
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
        updateFOVCircle()
    end)
    
    -- Update status label every frame (lightweight)
    RunService.RenderStepped:Connect(function()
        if Config.autoAimEnabled and currentTarget then
            statusLabel.Text = "TARGET: " .. currentTarget.Name
            statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        elseif Config.autoAimEnabled then
            statusLabel.Text = "TARGET: SEARCHING"
            statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
        else
            statusLabel.Text = "AIM: OFF"
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
    end)
    
    -- Toggle button (small icon)
    local toggleMenuBtn = Instance.new("TextButton")
    toggleMenuBtn.Size = UDim2.new(0, 30, 0, 30)
    toggleMenuBtn.Position = UDim2.new(1, -35, 0, 5)
    toggleMenuBtn.Text = "≡"
    toggleMenuBtn.TextColor3 = Color3.fromRGB(255,255,255)
    toggleMenuBtn.BackgroundColor3 = Color3.fromRGB(30,30,40)
    toggleMenuBtn.BorderSizePixel = 0
    toggleMenuBtn.Font = Enum.Font.GothamBold
    toggleMenuBtn.TextSize = 18
    toggleMenuBtn.Parent = guiMainFrame
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 8)
    toggleCorner.Parent = toggleMenuBtn
    toggleMenuBtn.MouseButton1Click:Connect(toggleGUI)
end

-- ============================================================================
-- KEYBINDS (RightShift to toggle GUI)
-- ============================================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F then
        Config.espEnabled = not Config.espEnabled
        if espToggleBtn then
            espToggleBtn.Text = "ESP " .. (Config.espEnabled and "ON" or "OFF")
            espToggleBtn.BackgroundColor3 = Config.espEnabled and Color3.fromRGB(0,150,150) or Color3.fromRGB(80,80,100)
        end
    elseif input.KeyCode == Enum.KeyCode.V then
        Config.autoAimEnabled = not Config.autoAimEnabled
        if aimToggleBtn then
            aimToggleBtn.Text = "AIM " .. (Config.autoAimEnabled and "ON" or "OFF")
            aimToggleBtn.BackgroundColor3 = Config.autoAimEnabled and Color3.fromRGB(0,150,150) or Color3.fromRGB(80,80,100)
        end
        if not Config.autoAimEnabled then
            currentTarget = nil
            currentTargetPart = nil
        end
        updateFOVCircle()
    elseif input.KeyCode == Enum.KeyCode.RightShift then
        toggleGUI()
    end
end)

-- ============================================================================
-- MAIN LOOP (RenderStepped with deltaTime)
-- ============================================================================
local lastTime = tick()
RunService.RenderStepped:Connect(function()
    local now = tick()
    local deltaTime = math.min(0.033, now - lastTime) -- cap at 30fps equivalent
    lastTime = now
    
    updateESP()
    updateFOVCircle()
    updateAim(deltaTime)
end)

-- Cleanup
Players.PlayerRemoving:Connect(function(player)
    if espObjects[player] then
        for _, v in pairs(espObjects[player]) do v:Remove() end
        espObjects[player] = nil
    end
end)

-- Initialize
createCrosshair()
createModernGUI()
updateFOVCircle()

print("CyberHeroes Auto Aim v3.0 (Ultra Responsive) loaded. F = ESP | V = Auto Aim | RightShift = Toggle GUI")

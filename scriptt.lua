--[[
    CyberHeroes Auto Aim + ESP v1.0
    Developed for Delta Executor
    Features: ESP (boxes, health, name, distance), Auto Aim (smooth lock to nearest player)
    Physics-based aiming prediction for moving targets
    Modern Neon GUI with gradient, glow, and interactive buttons
    Keybind: F (toggle ESP), V (toggle Auto Aim)
--]]

-- ============================================================================
-- SERVICES
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = localPlayer:GetMouse()

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local config = {
    espEnabled = true,
    autoAimEnabled = true,
    aimSmoothness = 0.2,      -- 0 = instant, 1 = slow
    aimFOV = 150,              -- field of view untuk auto aim (pixels from center)
    predictionMultiplier = 0.25, -- prediksi posisi berdasarkan velocity
    teamCheck = false,         -- false: target semua, true: hanya enemy team
    showHealth = true,
    showDistance = true,
    showName = true,
    boxColor = Color3.fromRGB(0, 255, 255),     -- cyan
    visibleColor = Color3.fromRGB(0, 255, 0),   -- green
    wallbangColor = Color3.fromRGB(255, 0, 0),  -- red
}

-- ============================================================================
-- STATE
-- ============================================================================
local espObjects = {}
local currentTarget = nil
local aimLock = false
local crosshair = nil

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================
local function getPlayerCharacter(player)
    return player and player.Character
end

local function getPlayerRootPart(character)
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
end

local function isPlayerAlive(player)
    local char = getPlayerCharacter(player)
    if not char then return false end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function getScreenPosition(worldPos)
    if not worldPos then return nil end
    local screenPos, onScreen = camera:WorldToScreenPoint(worldPos)
    if onScreen then
        return Vector2.new(screenPos.X, screenPos.Y)
    end
    return nil
end

-- ============================================================================
-- ESP DRAWING
-- ============================================================================
local function createESPObject(player)
    local drawingObjects = {
        box = Drawing.new("Square"),
        name = Drawing.new("Text"),
        health = Drawing.new("Text"),
        distance = Drawing.new("Text"),
        outline = Drawing.new("Square")
    }
    
    for _, obj in pairs(drawingObjects) do
        obj.Visible = false
        obj.Thickness = 1
        obj.Color = config.boxColor
        obj.Font = Drawing.Fonts.UI
        obj.Size = 14
        obj.Center = true
    end
    drawingObjects.outline.Thickness = 2
    drawingObjects.outline.Color = Color3.fromRGB(0, 0, 0)
    drawingObjects.outline.Filled = false
    
    drawingObjects.name.Color = Color3.fromRGB(255, 255, 255)
    drawingObjects.health.Color = Color3.fromRGB(100, 255, 100)
    drawingObjects.distance.Color = Color3.fromRGB(200, 200, 200)
    
    return drawingObjects
end

local function updateESP()
    local localChar = localPlayer.Character
    local localRoot = localChar and getPlayerRootPart(localChar)
    if not localRoot then return end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and isPlayerAlive(player) then
            local char = getPlayerCharacter(player)
            local root = getPlayerRootPart(char)
            if root then
                local screenPos = getScreenPosition(root.Position)
                if screenPos then
                    local distance = (localRoot.Position - root.Position).Magnitude
                    local boxSize = 100 / math.max(1, distance / 10)
                    local boxHeight = boxSize * 2
                    local boxWidth = boxSize
                    
                    local topLeft = Vector2.new(screenPos.X - boxWidth/2, screenPos.Y - boxHeight/2)
                    local bottomRight = Vector2.new(screenPos.X + boxWidth/2, screenPos.Y + boxHeight/2)
                    
                    local esp = espObjects[player]
                    if not esp then
                        esp = createESPObject(player)
                        espObjects[player] = esp
                    end
                    
                    -- Check if visible (raycast)
                    local visible = true
                    local ray = Ray.new(camera.CFrame.Position, (root.Position - camera.CFrame.Position).Unit * distance)
                    local hit, hitPos = workspace:FindPartOnRay(ray, localChar)
                    if hit and hit ~= root and hit.Parent ~= char then
                        visible = false
                    end
                    
                    local boxColor = visible and config.visibleColor or config.wallbangColor
                    
                    esp.box.Size = Vector2.new(boxWidth, boxHeight)
                    esp.box.Position = topLeft
                    esp.box.Color = boxColor
                    esp.box.Visible = config.espEnabled
                    
                    esp.outline.Size = Vector2.new(boxWidth, boxHeight)
                    esp.outline.Position = topLeft
                    esp.outline.Visible = config.espEnabled
                    
                    if config.showName then
                        esp.name.Text = player.Name
                        esp.name.Position = Vector2.new(screenPos.X, topLeft.Y - 15)
                        esp.name.Visible = config.espEnabled
                    end
                    
                    if config.showDistance then
                        esp.distance.Text = string.format("%.0fm", distance / 3)
                        esp.distance.Position = Vector2.new(screenPos.X, bottomRight.Y + 5)
                        esp.distance.Visible = config.espEnabled
                    end
                    
                    if config.showHealth then
                        local humanoid = char:FindFirstChildOfClass("Humanoid")
                        local healthPercent = humanoid and (humanoid.Health / humanoid.MaxHealth) or 1
                        local healthText = string.format("%.0f%%", healthPercent * 100)
                        esp.health.Text = healthText
                        esp.health.Position = Vector2.new(screenPos.X, bottomRight.Y + 20)
                        esp.health.Visible = config.espEnabled
                    end
                else
                    if espObjects[player] then
                        for _, obj in pairs(espObjects[player]) do
                            obj.Visible = false
                        end
                    end
                end
            end
        else
            if espObjects[player] then
                for _, obj in pairs(espObjects[player]) do
                    obj.Visible = false
                end
            end
        end
    end
end

-- ============================================================================
-- AUTO AIM (Physics-based)
-- ============================================================================
local function getNearestPlayerInFOV()
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local nearest = nil
    local minAngle = math.huge
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and isPlayerAlive(player) then
            local char = getPlayerCharacter(player)
            local root = getPlayerRootPart(char)
            if root then
                local screenPos = getScreenPosition(root.Position)
                if screenPos then
                    local delta = screenPos - center
                    local distance = delta.Magnitude
                    if distance < config.aimFOV and distance < minAngle then
                        minAngle = distance
                        nearest = player
                    end
                end
            end
        end
    end
    return nearest
end

-- Prediksi posisi target berdasarkan velocity (untuk smooth aiming)
local lastPositions = {}
local function predictPosition(character, deltaTime)
    local root = getPlayerRootPart(character)
    if not root then return nil end
    local currentPos = root.Position
    if not lastPositions[character] then
        lastPositions[character] = {pos = currentPos, time = tick()}
        return currentPos
    end
    local last = lastPositions[character]
    local elapsed = tick() - last.time
    if elapsed > 0.1 then
        local velocity = (currentPos - last.pos) / elapsed
        local predicted = currentPos + velocity * config.predictionMultiplier
        lastPositions[character] = {pos = currentPos, time = tick()}
        return predicted
    end
    return currentPos
end

local function aimAt(targetPlayer)
    if not targetPlayer then return end
    local char = getPlayerCharacter(targetPlayer)
    if not char then return end
    local predictedPos = predictPosition(char, 1/60)
    if not predictedPos then return end
    local screenPos = camera:WorldToScreenPoint(predictedPos)
    if screenPos.Z > 0 then
        local targetPos = Vector2.new(screenPos.X, screenPos.Y)
        local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
        local delta = targetPos - center
        if config.aimSmoothness > 0 then
            -- smooth movement
            local newDelta = delta * (1 - config.aimSmoothness)
            mousemoverel(newDelta.X, newDelta.Y)
        else
            mousemoverel(delta.X, delta.Y)
        end
    end
end

-- Auto aim loop
RunService.RenderStepped:Connect(function()
    if config.autoAimEnabled and currentTarget and isPlayerAlive(currentTarget) then
        aimAt(currentTarget)
    end
end)

-- Update target every frame (refresh nearest)
local function updateTarget()
    if config.autoAimEnabled then
        local nearest = getNearestPlayerInFOV()
        if nearest then
            currentTarget = nearest
        elseif not nearest then
            currentTarget = nil
        end
    else
        currentTarget = nil
    end
end

-- ============================================================================
-- CROSSHAIR (Sumbu X di tengah layar)
-- ============================================================================
local function createCrosshair()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_Crosshair"
    screenGui.Parent = localPlayer:FindFirstChild("PlayerGui") or CoreGui
    screenGui.ResetOnSpawn = false
    
    -- Sumbu X (garis horizontal)
    local lineH = Instance.new("Frame")
    lineH.Size = UDim2.new(0, 30, 0, 2)
    lineH.Position = UDim2.new(0.5, -15, 0.5, -1)
    lineH.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
    lineH.BackgroundTransparency = 0.2
    lineH.BorderSizePixel = 0
    lineH.Parent = screenGui
    
    -- Sumbu Y (garis vertikal)
    local lineV = Instance.new("Frame")
    lineV.Size = UDim2.new(0, 2, 0, 30)
    lineV.Position = UDim2.new(0.5, -1, 0.5, -15)
    lineV.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
    lineV.BackgroundTransparency = 0.2
    lineV.BorderSizePixel = 0
    lineV.Parent = screenGui
    
    -- Titik tengah (dot)
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 4, 0, 4)
    dot.Position = UDim2.new(0.5, -2, 0.5, -2)
    dot.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    dot.BackgroundTransparency = 0.5
    dot.BorderSizePixel = 0
    dot.Parent = screenGui
    
    -- Glow effect (optional)
    local glow = Instance.new("Frame")
    glow.Size = UDim2.new(0, 12, 0, 12)
    glow.Position = UDim2.new(0.5, -6, 0.5, -6)
    glow.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
    glow.BackgroundTransparency = 0.8
    glow.BorderSizePixel = 0
    glow.Parent = screenGui
    
    return screenGui
end

-- ============================================================================
-- GUI MODERN NEON
-- ============================================================================
local function createModernGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_HUD"
    screenGui.Parent = localPlayer:FindFirstChild("PlayerGui") or CoreGui
    screenGui.ResetOnSpawn = false
    
    -- Main Panel (bottom right)
    local mainPanel = Instance.new("Frame")
    mainPanel.Size = UDim2.new(0, 220, 0, 180)
    mainPanel.Position = UDim2.new(1, -240, 1, -200)
    mainPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    mainPanel.BackgroundTransparency = 0.2
    mainPanel.BorderSizePixel = 0
    mainPanel.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainPanel
    
    -- Shadow/glow
    local shadow = Instance.new("UIStroke")
    shadow.Color = Color3.fromRGB(100, 0, 200)
    shadow.Thickness = 1
    shadow.Transparency = 0.7
    shadow.Parent = mainPanel
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 5)
    title.Text = "⚡ CYBERHEROES ⚡"
    title.TextColor3 = Color3.fromRGB(0, 255, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = mainPanel
    
    -- ESP Toggle
    local espToggle = Instance.new("TextButton")
    espToggle.Size = UDim2.new(0, 100, 0, 30)
    espToggle.Position = UDim2.new(0.1, 0, 0.25, 0)
    espToggle.Text = "ESP " .. (config.espEnabled and "ON" or "OFF")
    espToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    espToggle.BackgroundColor3 = config.espEnabled and Color3.fromRGB(0, 150, 150) or Color3.fromRGB(80, 80, 100)
    espToggle.BorderSizePixel = 0
    espToggle.Font = Enum.Font.GothamBold
    espToggle.TextSize = 12
    espToggle.Parent = mainPanel
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = espToggle
    
    -- Auto Aim Toggle
    local aimToggle = Instance.new("TextButton")
    aimToggle.Size = UDim2.new(0, 100, 0, 30)
    aimToggle.Position = UDim2.new(0.55, 0, 0.25, 0)
    aimToggle.Text = "AIM " .. (config.autoAimEnabled and "ON" or "OFF")
    aimToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    aimToggle.BackgroundColor3 = config.autoAimEnabled and Color3.fromRGB(0, 150, 150) or Color3.fromRGB(80, 80, 100)
    aimToggle.BorderSizePixel = 0
    aimToggle.Font = Enum.Font.GothamBold
    aimToggle.TextSize = 12
    aimToggle.Parent = mainPanel
    local btnCorner2 = Instance.new("UICorner")
    btnCorner2.CornerRadius = UDim.new(0, 6)
    btnCorner2.Parent = aimToggle
    
    -- FOV Slider
    local fovLabel = Instance.new("TextLabel")
    fovLabel.Size = UDim2.new(0.8, 0, 0, 20)
    fovLabel.Position = UDim2.new(0.1, 0, 0.55, 0)
    fovLabel.Text = "FOV: " .. config.aimFOV
    fovLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    fovLabel.BackgroundTransparency = 1
    fovLabel.Font = Enum.Font.Gotham
    fovLabel.TextSize = 11
    fovLabel.TextXAlignment = Enum.TextXAlignment.Left
    fovLabel.Parent = mainPanel
    
    local fovSlider = Instance.new("Frame")
    fovSlider.Size = UDim2.new(0.8, 0, 0, 4)
    fovSlider.Position = UDim2.new(0.1, 0, 0.68, 0)
    fovSlider.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    fovSlider.BorderSizePixel = 0
    fovSlider.Parent = mainPanel
    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(1, 0)
    sliderCorner.Parent = fovSlider
    
    local fovFill = Instance.new("Frame")
    fovFill.Size = UDim2.new(config.aimFOV / 500, 0, 1, 0)
    fovFill.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
    fovFill.BorderSizePixel = 0
    fovFill.Parent = fovSlider
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fovFill
    
    -- Smoothness Slider
    local smoothLabel = Instance.new("TextLabel")
    smoothLabel.Size = UDim2.new(0.8, 0, 0, 20)
    smoothLabel.Position = UDim2.new(0.1, 0, 0.78, 0)
    smoothLabel.Text = "SMOOTH: " .. string.format("%.1f", config.aimSmoothness)
    smoothLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    smoothLabel.BackgroundTransparency = 1
    smoothLabel.Font = Enum.Font.Gotham
    smoothLabel.TextSize = 11
    smoothLabel.TextXAlignment = Enum.TextXAlignment.Left
    smoothLabel.Parent = mainPanel
    
    local smoothSlider = Instance.new("Frame")
    smoothSlider.Size = UDim2.new(0.8, 0, 0, 4)
    smoothSlider.Position = UDim2.new(0.1, 0, 0.91, 0)
    smoothSlider.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    smoothSlider.BorderSizePixel = 0
    smoothSlider.Parent = mainPanel
    local smoothCorner = Instance.new("UICorner")
    smoothCorner.CornerRadius = UDim.new(1, 0)
    smoothCorner.Parent = smoothSlider
    
    local smoothFill = Instance.new("Frame")
    smoothFill.Size = UDim2.new(config.aimSmoothness, 0, 1, 0)
    smoothFill.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
    smoothFill.BorderSizePixel = 0
    smoothFill.Parent = smoothSlider
    local smoothFillCorner = Instance.new("UICorner")
    smoothFillCorner.CornerRadius = UDim.new(1, 0)
    smoothFillCorner.Parent = smoothFill
    
    -- Slider dragging logic
    local draggingFOV = false
    local draggingSmooth = false
    
    fovSlider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingFOV = true
            local mousePos = mouse.X
            local relativeX = math.clamp((mousePos - fovSlider.AbsolutePosition.X) / fovSlider.AbsoluteSize.X, 0, 1)
            local newFOV = math.floor(relativeX * 500) + 10
            config.aimFOV = math.clamp(newFOV, 10, 500)
            fovLabel.Text = "FOV: " .. config.aimFOV
            fovFill.Size = UDim2.new(config.aimFOV / 500, 0, 1, 0)
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
            local mousePos = mouse.X
            local relativeX = math.clamp((mousePos - fovSlider.AbsolutePosition.X) / fovSlider.AbsoluteSize.X, 0, 1)
            local newFOV = math.floor(relativeX * 500) + 10
            config.aimFOV = math.clamp(newFOV, 10, 500)
            fovLabel.Text = "FOV: " .. config.aimFOV
            fovFill.Size = UDim2.new(config.aimFOV / 500, 0, 1, 0)
        elseif draggingSmooth and input.UserInputType == Enum.UserInputType.MouseMovement then
            local mousePos = mouse.X
            local relativeX = math.clamp((mousePos - smoothSlider.AbsolutePosition.X) / smoothSlider.AbsoluteSize.X, 0, 1)
            config.aimSmoothness = relativeX
            smoothLabel.Text = "SMOOTH: " .. string.format("%.1f", config.aimSmoothness)
            smoothFill.Size = UDim2.new(config.aimSmoothness, 0, 1, 0)
        end
    end)
    
    smoothSlider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingSmooth = true
            local mousePos = mouse.X
            local relativeX = math.clamp((mousePos - smoothSlider.AbsolutePosition.X) / smoothSlider.AbsoluteSize.X, 0, 1)
            config.aimSmoothness = relativeX
            smoothLabel.Text = "SMOOTH: " .. string.format("%.1f", config.aimSmoothness)
            smoothFill.Size = UDim2.new(config.aimSmoothness, 0, 1, 0)
        end
    end)
    
    -- Button actions
    espToggle.MouseButton1Click:Connect(function()
        config.espEnabled = not config.espEnabled
        espToggle.Text = "ESP " .. (config.espEnabled and "ON" or "OFF")
        espToggle.BackgroundColor3 = config.espEnabled and Color3.fromRGB(0, 150, 150) or Color3.fromRGB(80, 80, 100)
    end)
    
    aimToggle.MouseButton1Click:Connect(function()
        config.autoAimEnabled = not config.autoAimEnabled
        aimToggle.Text = "AIM " .. (config.autoAimEnabled and "ON" or "OFF")
        aimToggle.BackgroundColor3 = config.autoAimEnabled and Color3.fromRGB(0, 150, 150) or Color3.fromRGB(80, 80, 100)
        if not config.autoAimEnabled then
            currentTarget = nil
        end
    end)
    
    return screenGui
end

-- ============================================================================
-- KEYBINDS
-- ============================================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F then
        config.espEnabled = not config.espEnabled
        -- Update GUI button text if exists (optional)
    elseif input.KeyCode == Enum.KeyCode.V then
        config.autoAimEnabled = not config.autoAimEnabled
        if not config.autoAimEnabled then
            currentTarget = nil
        end
    end
end)

-- ============================================================================
-- MAIN LOOP
-- ============================================================================
-- Start ESP update loop
RunService.RenderStepped:Connect(function()
    updateESP()
    updateTarget()
end)

-- Initialize UI
createCrosshair()
createModernGUI()

-- Cleanup on player leave
Players.PlayerRemoving:Connect(function(player)
    if espObjects[player] then
        for _, obj in pairs(espObjects[player]) do
            obj:Remove()
        end
        espObjects[player] = nil
    end
end)

print("CyberHeroes Auto Aim + ESP loaded. Press F for ESP toggle, V for Auto Aim toggle.")
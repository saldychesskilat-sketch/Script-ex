--[[
    CyberHeroes Advanced Auto Aim + ESP v2.0
    Developed for Delta Executor
    Features:
    - Smart Target System (prioritas Head > UpperTorso > HumanoidRootPart)
    - Visibility Check (Raycast dengan blacklist)
    - Smooth Aim dengan dynamic smoothness
    - Prediction System berdasarkan velocity
    - FOV Circle (Drawing API)
    - GUI Modern dengan Toggle, Slider, efek neon
    - Optimasi performa (caching, throttling)
    - Modular structure
--]]

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
-- CONFIGURATION MODULE
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

    -- Auto Aim
    autoAimEnabled = true,
    aimFOV = 150,               -- radius dalam pixels
    aimSmoothness = 0.3,       -- 0 = instant, 1 = sangat lambat
    predictionMultiplier = 0.25,
    teamCheck = false,
    aimPartPriority = {"Head", "UpperTorso", "HumanoidRootPart"}, -- prioritas
    aimDelayMin = 0.05,         -- delay minimum sebelum aim (random)
    aimDelayMax = 0.15,
    randomOffset = 2,           -- pixel offset random untuk menghindari perfect aim
    dynamicSmoothness = true,   -- smoothness berubah berdasarkan jarak target
    targetSwitchDelay = 0.3,    -- delay sebelum ganti target (ms)
}

-- ============================================================================
-- STATE & CACHE
-- ============================================================================
local espObjects = {}
local currentTarget = nil
local lastTargetSwitch = 0
local lastPositions = {}   -- untuk prediction
local fovCircle = nil
local lastFrameTime = tick()

-- GUI Elements
local gui = nil
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

local function getWorldToScreenPoint(worldPos)
    if not worldPos then return nil end
    local screenPos, onScreen = camera:WorldToScreenPoint(worldPos)
    if onScreen then
        return Vector2.new(screenPos.X, screenPos.Y)
    end
    return nil
end

-- ============================================================================
-- RAYCAST VISIBILITY CHECK (MODERN)
-- ============================================================================
local raycastParams = RaycastParams.new()
local function isVisible(targetPart, ignoreCharacter)
    if not targetPart or not targetPart.Parent then return false end
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {ignoreCharacter, localPlayer.Character}
    local origin = camera.CFrame.Position
    local direction = (targetPart.Position - origin).Unit * (targetPart.Position - origin).Magnitude
    local raycastResult = workspace:Raycast(origin, direction, raycastParams)
    if raycastResult then
        local hitPart = raycastResult.Instance
        if hitPart:IsDescendantOf(targetPart.Parent) then
            return true
        end
    end
    return false
end

-- ============================================================================
-- SMART TARGET SYSTEM
-- ============================================================================
local function getBestTargetPart(character)
    if not character then return nil end
    for _, partName in ipairs(Config.aimPartPriority) do
        local part = character:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            return part
        end
    end
    -- fallback ke HumanoidRootPart atau Torso
    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
end

local function getNearestTargetInFOV()
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local bestScore = math.huge
    local bestTarget = nil
    local bestPart = nil

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and isAlive(player) then
            if Config.teamCheck then
                -- implement team check jika diperlukan
            end
            local char = getCharacter(player)
            local targetPart = getBestTargetPart(char)
            if targetPart then
                local screenPos = getWorldToScreenPoint(targetPart.Position)
                if screenPos then
                    local delta = screenPos - center
                    local distanceFromCenter = delta.Magnitude
                    if distanceFromCenter < Config.aimFOV then
                        -- Skor: prioritas jarak dari crosshair (semakin kecil semakin baik)
                        if distanceFromCenter < bestScore then
                            bestScore = distanceFromCenter
                            bestTarget = player
                            bestPart = targetPart
                        end
                    end
                end
            end
        end
    end
    return bestTarget, bestPart
end

-- ============================================================================
-- PREDICTION SYSTEM
-- ============================================================================
local function predictPosition(character, part, deltaTime)
    if not part then return part and part.Position end
    local currentPos = part.Position
    if not lastPositions[character] then
        lastPositions[character] = {pos = currentPos, time = tick(), part = part}
        return currentPos
    end
    local last = lastPositions[character]
    if last.part ~= part then
        lastPositions[character] = {pos = currentPos, time = tick(), part = part}
        return currentPos
    end
    local elapsed = tick() - last.time
    if elapsed > 0.05 then
        local velocity = (currentPos - last.pos) / elapsed
        local predicted = currentPos + velocity * Config.predictionMultiplier
        lastPositions[character] = {pos = currentPos, time = tick(), part = part}
        return predicted
    end
    return currentPos
end

-- ============================================================================
-- AIM SMOOTHING (HUMAN-LIKE)
-- ============================================================================
local function smoothAim(targetScreenPos)
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local delta = targetScreenPos - center
    
    -- Dynamic smoothness berdasarkan jarak
    local smoothness = Config.aimSmoothness
    if Config.dynamicSmoothness then
        local distance = delta.Magnitude
        if distance > 100 then
            smoothness = math.min(0.8, Config.aimSmoothness * 1.5)
        elseif distance < 30 then
            smoothness = math.max(0.1, Config.aimSmoothness * 0.5)
        else
            smoothness = Config.aimSmoothness
        end
    end
    
    -- Random offset untuk humanization
    local randomOffsetX = (math.random() - 0.5) * Config.randomOffset
    local randomOffsetY = (math.random() - 0.5) * Config.randomOffset
    local finalDelta = delta * (1 - smoothness) + Vector2.new(randomOffsetX, randomOffsetY)
    
    mousemoverel(finalDelta.X, finalDelta.Y)
end

-- ============================================================================
-- AIM LOOP (with delay and target switching)
-- ============================================================================
local function updateAim()
    if not Config.autoAimEnabled then
        currentTarget = nil
        return
    end
    
    local now = tick()
    local target, targetPart = getNearestTargetInFOV()
    if target and targetPart then
        -- Cek visibility
        if isVisible(targetPart, getCharacter(target)) then
            if currentTarget ~= target then
                if now - lastTargetSwitch >= Config.targetSwitchDelay then
                    currentTarget = target
                    lastTargetSwitch = now
                else
                    return
                end
            end
            
            -- Prediksi posisi
            local predictedPos = predictPosition(getCharacter(target), targetPart, RunService.RenderStepped:Wait())
            local screenPos = getWorldToScreenPoint(predictedPos)
            if screenPos then
                -- Random delay sebelum aim (humanization)
                local aimDelay = Config.aimDelayMin + math.random() * (Config.aimDelayMax - Config.aimDelayMin)
                task.wait(aimDelay)
                smoothAim(screenPos)
            end
        else
            -- Target tidak visible, coba cari lain
            currentTarget = nil
        end
    else
        currentTarget = nil
    end
end

-- ============================================================================
-- ESP DRAWING (OPTIMIZED)
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
                local screenPos = getWorldToScreenPoint(targetPart.Position)
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
                    
                    -- Visibility check untuk warna box
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
-- FOV CIRCLE (Drawing API)
-- ============================================================================
local function createFOVCircle()
    if fovCircle then fovCircle:Remove() end
    fovCircle = Drawing.new("Circle")
    fovCircle.Visible = Config.autoAimEnabled
    fovCircle.Thickness = 1
    fovCircle.Color = Color3.fromRGB(0, 255, 255)
    fovCircle.Filled = false
    fovCircle.NumSides = 64
    fovCircle.Radius = Config.aimFOV
    fovCircle.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
end

local function updateFOVCircle()
    if fovCircle then
        fovCircle.Visible = Config.autoAimEnabled
        fovCircle.Radius = Config.aimFOV
        fovCircle.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    end
end

-- ============================================================================
-- CROSSHAIR (Sumbu X)
-- ============================================================================
local function createCrosshair()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_Crosshair"
    screenGui.Parent = localPlayer:FindFirstChild("PlayerGui") or CoreGui
    screenGui.ResetOnSpawn = false
    
    local lineH = Instance.new("Frame")
    lineH.Size = UDim2.new(0, 30, 0, 2)
    lineH.Position = UDim2.new(0.5, -15, 0.5, -1)
    lineH.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
    lineH.BackgroundTransparency = 0.3
    lineH.BorderSizePixel = 0
    lineH.Parent = screenGui
    
    local lineV = Instance.new("Frame")
    lineV.Size = UDim2.new(0, 2, 0, 30)
    lineV.Position = UDim2.new(0.5, -1, 0.5, -15)
    lineV.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
    lineV.BackgroundTransparency = 0.3
    lineV.BorderSizePixel = 0
    lineV.Parent = screenGui
    
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 4, 0, 4)
    dot.Position = UDim2.new(0.5, -2, 0.5, -2)
    dot.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    dot.BackgroundTransparency = 0.4
    dot.BorderSizePixel = 0
    dot.Parent = screenGui
end

-- ============================================================================
-- MODERN GUI (Neon, Slider, Toggle)
-- ============================================================================
local function createModernGUI()
    gui = Instance.new("ScreenGui")
    gui.Name = "CyberHeroes_HUD"
    gui.Parent = localPlayer:FindFirstChild("PlayerGui") or CoreGui
    gui.ResetOnSpawn = false
    
    local mainPanel = Instance.new("Frame")
    mainPanel.Size = UDim2.new(0, 250, 0, 210)
    mainPanel.Position = UDim2.new(1, -270, 1, -230)
    mainPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    mainPanel.BackgroundTransparency = 0.15
    mainPanel.BorderSizePixel = 0
    mainPanel.Parent = gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainPanel
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 0, 200)
    stroke.Thickness = 1
    stroke.Transparency = 0.6
    stroke.Parent = mainPanel
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 5)
    title.Text = "⚡ CYBERHEROES v2.0 ⚡"
    title.TextColor3 = Color3.fromRGB(0, 255, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = mainPanel
    
    -- ESP Toggle
    espToggleBtn = Instance.new("TextButton")
    espToggleBtn.Size = UDim2.new(0, 100, 0, 30)
    espToggleBtn.Position = UDim2.new(0.1, 0, 0.25, 0)
    espToggleBtn.Text = "ESP " .. (Config.espEnabled and "ON" or "OFF")
    espToggleBtn.TextColor3 = Color3.fromRGB(255,255,255)
    espToggleBtn.BackgroundColor3 = Config.espEnabled and Color3.fromRGB(0,150,150) or Color3.fromRGB(80,80,100)
    espToggleBtn.BorderSizePixel = 0
    espToggleBtn.Font = Enum.Font.GothamBold
    espToggleBtn.TextSize = 12
    espToggleBtn.Parent = mainPanel
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = espToggleBtn
    
    -- Auto Aim Toggle
    aimToggleBtn = Instance.new("TextButton")
    aimToggleBtn.Size = UDim2.new(0, 100, 0, 30)
    aimToggleBtn.Position = UDim2.new(0.55, 0, 0.25, 0)
    aimToggleBtn.Text = "AIM " .. (Config.autoAimEnabled and "ON" or "OFF")
    aimToggleBtn.TextColor3 = Color3.fromRGB(255,255,255)
    aimToggleBtn.BackgroundColor3 = Config.autoAimEnabled and Color3.fromRGB(0,150,150) or Color3.fromRGB(80,80,100)
    aimToggleBtn.BorderSizePixel = 0
    aimToggleBtn.Font = Enum.Font.GothamBold
    aimToggleBtn.TextSize = 12
    aimToggleBtn.Parent = mainPanel
    local btnCorner2 = Instance.new("UICorner")
    btnCorner2.CornerRadius = UDim.new(0, 6)
    btnCorner2.Parent = aimToggleBtn
    
    -- FOV Slider
    fovLabel = Instance.new("TextLabel")
    fovLabel.Size = UDim2.new(0.8, 0, 0, 20)
    fovLabel.Position = UDim2.new(0.1, 0, 0.55, 0)
    fovLabel.Text = "FOV: " .. Config.aimFOV
    fovLabel.TextColor3 = Color3.fromRGB(200,200,200)
    fovLabel.BackgroundTransparency = 1
    fovLabel.Font = Enum.Font.Gotham
    fovLabel.TextSize = 11
    fovLabel.TextXAlignment = Enum.TextXAlignment.Left
    fovLabel.Parent = mainPanel
    
    local fovSliderBg = Instance.new("Frame")
    fovSliderBg.Size = UDim2.new(0.8, 0, 0, 4)
    fovSliderBg.Position = UDim2.new(0.1, 0, 0.68, 0)
    fovSliderBg.BackgroundColor3 = Color3.fromRGB(50,50,70)
    fovSliderBg.BorderSizePixel = 0
    fovSliderBg.Parent = mainPanel
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
    smoothLabel.Position = UDim2.new(0.1, 0, 0.78, 0)
    smoothLabel.Text = "SMOOTH: " .. string.format("%.2f", Config.aimSmoothness)
    smoothLabel.TextColor3 = Color3.fromRGB(200,200,200)
    smoothLabel.BackgroundTransparency = 1
    smoothLabel.Font = Enum.Font.Gotham
    smoothLabel.TextSize = 11
    smoothLabel.TextXAlignment = Enum.TextXAlignment.Left
    smoothLabel.Parent = mainPanel
    
    local smoothSliderBg = Instance.new("Frame")
    smoothSliderBg.Size = UDim2.new(0.8, 0, 0, 4)
    smoothSliderBg.Position = UDim2.new(0.1, 0, 0.91, 0)
    smoothSliderBg.BackgroundColor3 = Color3.fromRGB(50,50,70)
    smoothSliderBg.BorderSizePixel = 0
    smoothSliderBg.Parent = mainPanel
    local smoothCorner = Instance.new("UICorner")
    smoothCorner.CornerRadius = UDim.new(1, 0)
    smoothCorner.Parent = smoothSliderBg
    
    smoothFill = Instance.new("Frame")
    smoothFill.Size = UDim2.new(Config.aimSmoothness, 0, 1, 0)
    smoothFill.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
    smoothFill.BorderSizePixel = 0
    smoothFill.Parent = smoothSliderBg
    local smoothFillCorner = Instance.new("UICorner")
    smoothFillCorner.CornerRadius = UDim.new(1, 0)
    smoothFillCorner.Parent = smoothFill
    
    -- Slider dragging
    local draggingFOV = false
    local draggingSmooth = false
    fovSliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingFOV = true
            local mousePos = mouse.X
            local relX = math.clamp((mousePos - fovSliderBg.AbsolutePosition.X) / fovSliderBg.AbsoluteSize.X, 0, 1)
            local newFOV = math.floor(relX * 500) + 10
            Config.aimFOV = math.clamp(newFOV, 10, 500)
            fovLabel.Text = "FOV: " .. Config.aimFOV
            fovFill.Size = UDim2.new(Config.aimFOV / 500, 0, 1, 0)
            updateFOVCircle()
        end
    end)
    smoothSliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingSmooth = true
            local mousePos = mouse.X
            local relX = math.clamp((mousePos - smoothSliderBg.AbsolutePosition.X) / smoothSliderBg.AbsoluteSize.X, 0, 1)
            Config.aimSmoothness = relX
            smoothLabel.Text = "SMOOTH: " .. string.format("%.2f", Config.aimSmoothness)
            smoothFill.Size = UDim2.new(Config.aimSmoothness, 0, 1, 0)
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
            local relX = math.clamp((mousePos - fovSliderBg.AbsolutePosition.X) / fovSliderBg.AbsoluteSize.X, 0, 1)
            local newFOV = math.floor(relX * 500) + 10
            Config.aimFOV = math.clamp(newFOV, 10, 500)
            fovLabel.Text = "FOV: " .. Config.aimFOV
            fovFill.Size = UDim2.new(Config.aimFOV / 500, 0, 1, 0)
            updateFOVCircle()
        elseif draggingSmooth and input.UserInputType == Enum.UserInputType.MouseMovement then
            local mousePos = mouse.X
            local relX = math.clamp((mousePos - smoothSliderBg.AbsolutePosition.X) / smoothSliderBg.AbsoluteSize.X, 0, 1)
            Config.aimSmoothness = relX
            smoothLabel.Text = "SMOOTH: " .. string.format("%.2f", Config.aimSmoothness)
            smoothFill.Size = UDim2.new(Config.aimSmoothness, 0, 1, 0)
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
        end
        updateFOVCircle()
    end)
end

-- ============================================================================
-- KEYBINDS
-- ============================================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F then
        Config.espEnabled = not Config.espEnabled
        espToggleBtn.Text = "ESP " .. (Config.espEnabled and "ON" or "OFF")
        espToggleBtn.BackgroundColor3 = Config.espEnabled and Color3.fromRGB(0,150,150) or Color3.fromRGB(80,80,100)
    elseif input.KeyCode == Enum.KeyCode.V then
        Config.autoAimEnabled = not Config.autoAimEnabled
        aimToggleBtn.Text = "AIM " .. (Config.autoAimEnabled and "ON" or "OFF")
        aimToggleBtn.BackgroundColor3 = Config.autoAimEnabled and Color3.fromRGB(0,150,150) or Color3.fromRGB(80,80,100)
        if not Config.autoAimEnabled then
            currentTarget = nil
        end
        updateFOVCircle()
    end
end)

-- ============================================================================
-- MAIN LOOP (Optimized)
-- ============================================================================
-- Update ESP dan FOV Circle setiap frame (render)
RunService.RenderStepped:Connect(function()
    updateESP()
    if fovCircle then
        fovCircle.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    end
    updateAim()  -- Auto aim loop dengan prediksi
end)

-- Cleanup
Players.PlayerRemoving:Connect(function(player)
    if espObjects[player] then
        for _, v in pairs(espObjects[player]) do v:Remove() end
        espObjects[player] = nil
    end
end)

-- Inisialisasi
createCrosshair()
createModernGUI()
createFOVCircle()

print("CyberHeroes Advanced Auto Aim + ESP v2.0 loaded. Press F (ESP), V (Auto Aim).")
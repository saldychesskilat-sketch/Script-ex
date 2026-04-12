--[[
    CYBERHEROES AGGRESSIVE AIM v6.0 PRO
    - Total fix ESP & detection (termasuk lobby)
    - Physics-based aim with CFrame:Lerp (smooth like FPS)
    - Smart prediction + acceleration system
    - X-axis correction + auto relock
    - Back enemy indicator with UIGradient (premium visual)
    - Team check + ESP fade distance
    - Optimized performance
--]]

-- ============================================================================
-- SERVICES
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = localPlayer:GetMouse()

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local Config = {
    -- Main
    enabled = true,
    aimMode = "legit",          -- "legit" or "rage"
    teamCheck = false,
    
    -- ESP
    espEnabled = true,
    espFadeDistance = 300,
    espColors = {
        visible = Color3.fromRGB(0, 255, 0),
        occluded = Color3.fromRGB(255, 0, 0),
        locked = Color3.fromRGB(255, 255, 0),
        teammate = Color3.fromRGB(0, 100, 255)
    },
    
    -- Aiming (Physics-based)
    smoothness = 0.12,          -- untuk CFrame:Lerp
    acceleration = 8,           -- kecepatan akselerasi aim
    predictionMultiplier = 0.25,
    aimFOV = 200,
    xAxisCorrection = 0.1,      -- koreksi horizontal
    
    -- Visual
    showFOVCircle = true,
    fovCircleColor = Color3.fromRGB(0, 255, 255),
    hitIndicatorDuration = 0.2,
    lockEffectEnabled = true,
    enemyBehindEnabled = true,
}

-- ============================================================================
-- GLOBAL STATE
-- ============================================================================
local espObjects = {}
local currentTarget = nil
local currentTargetPart = nil
local currentTargetVisible = false
local lastTargetTime = 0
local fovCircle = nil
local hitIndicatorGui = nil
local behindGradient = nil
local myTeam = nil
local raycastParams = RaycastParams.new()
local lastVelocities = {}
local cameraOriginalCF = nil

-- GUI Elements
local guiMainFrame = nil
local guiVisible = true
local espToggle, aimToggle, legitBtn, rageBtn, fovSlider, smoothSlider, fovFill, smoothFill
local fovLabel, smoothLabel, lockStatusLabel, teamCheckToggle

-- ============================================================================
-- UTILITIES
-- ============================================================================
local function getCharacter(player)
    return player and player.Character
end

local function getHumanoid(character)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function getBestPart(character)
    if not character then return nil end
    local part = character:FindFirstChild("HumanoidRootPart")
    if not part then part = character:FindFirstChild("UpperTorso") end
    if not part then part = character:FindFirstChild("Torso") end
    if not part then part = character:FindFirstChild("Head") end
    return part
end

local function getScreenPosition(worldPos)
    if not worldPos then return nil end
    local screenPos, onScreen = camera:WorldToViewportPoint(worldPos)
    if onScreen then
        return Vector2.new(screenPos.X, screenPos.Y)
    end
    return nil
end

local function getTeam(player)
    if player.Team then return player.Team end
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        for _, v in ipairs(leaderstats:GetChildren()) do
            if v.Name:lower():find("team") then
                return v.Value
            end
        end
    end
    return nil
end

local function isTeammate(player)
    if not Config.teamCheck then return false end
    if not myTeam then myTeam = getTeam(localPlayer) end
    local theirTeam = getTeam(player)
    return myTeam and theirTeam and myTeam == theirTeam
end

-- ============================================================================
-- RAYCAST VISIBILITY (CACHED)
-- ============================================================================
local lastRaycastCache = {}
local function isVisible(part, character)
    if not part then return false end
    local key = part
    if lastRaycastCache[key] ~= nil then
        return lastRaycastCache[key]
    end
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {character, localPlayer.Character}
    local origin = camera.CFrame.Position
    local direction = (part.Position - origin).Unit * (part.Position - origin).Magnitude
    local result = Workspace:Raycast(origin, direction, raycastParams)
    local visible = false
    if result then
        local hit = result.Instance
        if hit:IsDescendantOf(character) then
            visible = true
        end
    end
    lastRaycastCache[key] = visible
    task.delay(0.1, function() lastRaycastCache[key] = nil end)
    return visible
end

-- ============================================================================
-- PREDICTION SYSTEM (Physics-based)
-- ============================================================================
local function predictPosition(part)
    if not part then return nil end
    local vel = part.Velocity
    local speed = vel.Magnitude
    local multiplier = Config.predictionMultiplier
    if speed < 5 then
        multiplier = multiplier * 0.3
    elseif speed > 30 then
        multiplier = multiplier * 1.2
    end
    return part.Position + vel * multiplier
end

-- ============================================================================
-- AIM SYSTEM (CFrame:Lerp + Acceleration)
-- ============================================================================
local currentAimCF = nil
local function updateAim(dt)
    if not Config.enabled or not currentTargetPart then return end
    local predictedPos = predictPosition(currentTargetPart)
    if not predictedPos then return end
    local targetCF = CFrame.new(camera.CFrame.Position, predictedPos)
    if not currentAimCF then currentAimCF = camera.CFrame end
    -- Smooth factor (Legit vs Rage)
    local smooth = Config.smoothness
    if Config.aimMode == "rage" then smooth = 0.02 end
    -- Acceleration: lerp dengan kecepatan yang bergantung dt
    local factor = math.clamp(dt * Config.acceleration, 0, 1)
    currentAimCF = currentAimCF:Lerp(targetCF, factor)
    camera.CFrame = currentAimCF
end

-- ============================================================================
-- X-AXIS CORRECTION (Horizontal)
-- ============================================================================
local function applyXAxisCorrection()
    if not currentTargetPart then return end
    local screenPos = getScreenPosition(currentTargetPart.Position)
    if screenPos then
        local centerX = camera.ViewportSize.X / 2
        local deltaX = screenPos.X - centerX
        if math.abs(deltaX) > 5 then
            local correction = deltaX * Config.xAxisCorrection
            mousemoverel(correction, 0)
        end
    end
end

-- ============================================================================
-- TARGET SELECTION (Prioritas: visible, jarak layar)
-- ============================================================================
local function getBestTarget()
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local bestScore = math.huge
    local bestPlayer = nil
    local bestPart = nil
    local bestVisible = false
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and not isTeammate(player) then
            local char = getCharacter(player)
            if char then
                local part = getBestPart(char)
                if part then
                    local screenPos = getScreenPosition(part.Position)
                    if screenPos then
                        local distFromCenter = (screenPos - center).Magnitude
                        local visible = isVisible(part, char)
                        local score = distFromCenter
                        if not visible then score = score + 1000 end
                        -- tambah jarak dunia
                        local worldDist = (camera.CFrame.Position - part.Position).Magnitude
                        score = score + worldDist * 0.3
                        if score < bestScore then
                            bestScore = score
                            bestPlayer = player
                            bestPart = part
                            bestVisible = visible
                        end
                    end
                end
            end
        end
    end
    return bestPlayer, bestPart, bestVisible
end

-- ============================================================================
-- AUTO RELOCK
-- ============================================================================
local function shouldKeepTarget(target)
    if not target then return false end
    local char = getCharacter(target)
    if not char then return false end
    local part = getBestPart(char)
    if not part then return false end
    local screenPos = getScreenPosition(part.Position)
    if not screenPos then return false end
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local dist = (screenPos - center).Magnitude
    if dist > Config.aimFOV * 1.5 then return false end
    return true
end

-- ============================================================================
-- UPDATE TARGET LOOP
-- ============================================================================
local function updateTarget()
    if not Config.enabled then
        currentTarget = nil
        currentTargetPart = nil
        return
    end
    if currentTarget and shouldKeepTarget(currentTarget) then
        -- update part
        local char = getCharacter(currentTarget)
        if char then
            currentTargetPart = getBestPart(char)
            currentTargetVisible = currentTargetPart and isVisible(currentTargetPart, char)
        else
            currentTarget = nil
        end
    else
        local newTarget, newPart, newVisible = getBestTarget()
        if newTarget then
            currentTarget = newTarget
            currentTargetPart = newPart
            currentTargetVisible = newVisible
        end
    end
end

-- ============================================================================
-- BACK ENEMY INDICATOR (UIGradient Premium)
-- ============================================================================
local function updateBehindEffect()
    if not Config.enemyBehindEnabled then
        if behindGradient then behindGradient.Visible = false end
        return
    end
    local cameraPos = camera.CFrame.Position
    local forward = camera.CFrame.LookVector
    local left = camera.CFrame.RightVector
    local behindPlayers = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and not isTeammate(player) then
            local char = getCharacter(player)
            local part = getBestPart(char)
            if part then
                local toPlayer = (part.Position - cameraPos).Unit
                local dot = forward:Dot(toPlayer)
                if dot < 0 then
                    local side = left:Dot(toPlayer)
                    local direction = side > 0 and "right" or "left"
                    local distance = (cameraPos - part.Position).Magnitude
                    table.insert(behindPlayers, {dir = direction, dist = distance})
                end
            end
        end
    end
    if #behindPlayers > 0 then
        if not behindGradient then
            behindGradient = Instance.new("ScreenGui")
            behindGradient.Name = "BehindEffect"
            behindGradient.Parent = localPlayer:FindFirstChild("PlayerGui") or CoreGui
            behindGradient.ResetOnSpawn = false
            
            local leftFrame = Instance.new("Frame")
            leftFrame.Size = UDim2.new(0, 150, 1, 0)
            leftFrame.Position = UDim2.new(0, 0, 0, 0)
            leftFrame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            leftFrame.BackgroundTransparency = 0.7
            leftFrame.BorderSizePixel = 0
            leftFrame.Parent = behindGradient
            local leftGrad = Instance.new("UIGradient")
            leftGrad.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
            leftGrad.Transparency = NumberSequence.new{
                NumberSequenceKeypoint.new(0, 0.2),
                NumberSequenceKeypoint.new(1, 1)
            }
            leftGrad.Parent = leftFrame
            
            local rightFrame = Instance.new("Frame")
            rightFrame.Size = UDim2.new(0, 150, 1, 0)
            rightFrame.Position = UDim2.new(1, -150, 0, 0)
            rightFrame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            rightFrame.BackgroundTransparency = 0.7
            rightFrame.BorderSizePixel = 0
            rightFrame.Parent = behindGradient
            local rightGrad = Instance.new("UIGradient")
            rightGrad.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
            rightGrad.Transparency = NumberSequence.new{
                NumberSequenceKeypoint.new(0, 0.2),
                NumberSequenceKeypoint.new(1, 1)
            }
            rightGrad.Parent = rightFrame
            
            behindGradient.Left = leftFrame
            behindGradient.Right = rightFrame
        end
        -- intensitas berdasarkan jarak terdekat
        local minDist = math.huge
        for _, b in ipairs(behindPlayers) do
            if b.dist < minDist then minDist = b.dist end
        end
        local intensity = math.clamp(1 - (minDist / 60), 0.2, 0.8)
        behindGradient.Left.BackgroundTransparency = 1 - intensity
        behindGradient.Right.BackgroundTransparency = 1 - intensity
        behindGradient.Visible = true
    else
        if behindGradient then behindGradient.Visible = false end
    end
end

-- ============================================================================
-- ESP SYSTEM (Dengan Fade Distance)
-- ============================================================================
local function createESPObject(player)
    local obj = {
        box = Drawing.new("Square"),
        name = Drawing.new("Text"),
        health = Drawing.new("Text"),
        distance = Drawing.new("Text"),
        locked = Drawing.new("Text"),
    }
    obj.box.Thickness = 1.5
    obj.box.Filled = false
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
    obj.locked.Font = Drawing.Fonts.UI
    obj.locked.Size = 12
    obj.locked.Color = Color3.fromRGB(255,255,0)
    obj.locked.Center = true
    for _, v in pairs(obj) do v.Visible = false end
    return obj
end

local function updateESP()
    if not Config.espEnabled then
        for _, obj in pairs(espObjects) do
            for _, v in pairs(obj) do v.Visible = false end
        end
        return
    end
    
    local localChar = localPlayer.Character
    local localRoot = localChar and getBestPart(localChar)
    if not localRoot then return end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and not isTeammate(player) then
            local char = getCharacter(player)
            local part = getBestPart(char)
            if part then
                local screenPos = getScreenPosition(part.Position)
                if screenPos then
                    local distance = (localRoot.Position - part.Position).Magnitude
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
                    
                    local visible = isVisible(part, char)
                    local isLocked = (currentTarget == player)
                    local boxColor
                    if isLocked then
                        boxColor = Config.espColors.locked
                    elseif visible then
                        boxColor = Config.espColors.visible
                    else
                        boxColor = Config.espColors.occluded
                    end
                    
                    -- Fade berdasarkan jarak
                    local alpha = math.clamp(1 - (distance / Config.espFadeDistance), 0.2, 1)
                    esp.box.Color = boxColor
                    esp.box.Transparency = 1 - alpha
                    esp.box.Size = Vector2.new(boxWidth, boxHeight)
                    esp.box.Position = topLeft
                    esp.box.Visible = true
                    
                    esp.name.Text = player.Name
                    esp.name.Position = Vector2.new(screenPos.X, topLeft.Y - 15)
                    esp.name.Visible = true
                    
                    esp.distance.Text = string.format("%.0fm", distance / 3)
                    esp.distance.Position = Vector2.new(screenPos.X, bottomRight.Y + 5)
                    esp.distance.Visible = true
                    
                    local humanoid = getHumanoid(char)
                    local healthPercent = humanoid and (humanoid.Health / humanoid.MaxHealth) or 1
                    esp.health.Text = string.format("%.0f%%", healthPercent * 100)
                    esp.health.Position = Vector2.new(screenPos.X, bottomRight.Y + 20)
                    esp.health.Visible = true
                    
                    if isLocked then
                        esp.locked.Text = "🔒 LOCKED"
                        esp.locked.Position = Vector2.new(screenPos.X, topLeft.Y - 28)
                        esp.locked.Visible = true
                    else
                        esp.locked.Visible = false
                    end
                else
                    if espObjects[player] then
                        for _, v in pairs(espObjects[player]) do v.Visible = false end
                    end
                end
            else
                if espObjects[player] then
                    for _, v in pairs(espObjects[player]) do v.Visible = false end
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
-- FOV CIRCLE
-- ============================================================================
local function updateFOVCircle()
    if not fovCircle then
        fovCircle = Drawing.new("Circle")
        fovCircle.Thickness = 1.5
        fovCircle.Color = Config.fovCircleColor
        fovCircle.Filled = false
        fovCircle.NumSides = 64
    end
    fovCircle.Visible = Config.showFOVCircle and Config.enabled
    fovCircle.Radius = Config.aimFOV
    fovCircle.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
end

-- ============================================================================
-- HIT INDICATOR
-- ============================================================================
local function showHitIndicator()
    if not hitIndicatorGui then
        hitIndicatorGui = Instance.new("ScreenGui")
        hitIndicatorGui.Name = "HitIndicator"
        hitIndicatorGui.Parent = localPlayer:FindFirstChild("PlayerGui") or CoreGui
        hitIndicatorGui.ResetOnSpawn = false
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 80, 0, 80)
        frame.Position = UDim2.new(0.5, -40, 0.5, -40)
        frame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        frame.BackgroundTransparency = 0.8
        frame.BorderSizePixel = 0
        frame.Parent = hitIndicatorGui
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = frame
        hitIndicatorGui.Frame = frame
    end
    hitIndicatorGui.Frame.Visible = true
    TweenService:Create(hitIndicatorGui.Frame, TweenInfo.new(Config.hitIndicatorDuration, Enum.EasingStyle.Quad), {
        BackgroundTransparency = 1
    }):Play()
    task.delay(Config.hitIndicatorDuration, function()
        if hitIndicatorGui then hitIndicatorGui.Frame.Visible = false end
    end)
end

-- ============================================================================
-- LOCK EFFECT (VISUAL)
-- ============================================================================
local lockEffectPart = nil
local function createLockEffect(targetPart)
    if lockEffectPart then lockEffectPart:Destroy() end
    if not Config.lockEffectEnabled then return end
    local part = Instance.new("Part")
    part.Size = Vector3.new(1, 1, 1)
    part.Shape = Enum.PartType.Ball
    part.BrickColor = BrickColor.new("Bright red")
    part.Material = Enum.Material.Neon
    part.Anchored = true
    part.CanCollide = false
    part.Parent = Workspace
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = targetPart
    weld.Part1 = part
    weld.Parent = part
    lockEffectPart = part
    TweenService:Create(part, TweenInfo.new(0.3), {Size = Vector3.new(2, 2, 2)}):Play()
    task.delay(0.5, function()
        if lockEffectPart then lockEffectPart:Destroy() end
    end)
end

-- ============================================================================
-- CROSSHAIR
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
    lineH.BackgroundColor3 = Config.fovCircleColor
    lineH.BackgroundTransparency = 0.3
    lineH.BorderSizePixel = 0
    lineH.Parent = screenGui
    
    local lineV = Instance.new("Frame")
    lineV.Size = UDim2.new(0, 2, 0, 30)
    lineV.Position = UDim2.new(0.5, 0, 0.5, 0)
    lineV.AnchorPoint = Vector2.new(0.5, 0.5)
    lineV.BackgroundColor3 = Config.fovCircleColor
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
-- GUI MODERN (dengan slider, toggle)
-- ============================================================================
local function toggleGUI()
    if not guiMainFrame then return end
    guiVisible = not guiVisible
    local targetSize = guiVisible and UDim2.new(0, 360, 0, 320) or UDim2.new(0, 0, 0, 0)
    TweenService:Create(guiMainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Size = targetSize}):Play()
end

local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_HUD"
    screenGui.Parent = localPlayer:FindFirstChild("PlayerGui") or CoreGui
    screenGui.ResetOnSpawn = false
    
    guiMainFrame = Instance.new("Frame")
    guiMainFrame.Size = UDim2.new(0, 360, 0, 320)
    guiMainFrame.Position = UDim2.new(1, -380, 1, -340)
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
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 35)
    title.Position = UDim2.new(0, 0, 0, 5)
    title.Text = "🔥 AGGRESSIVE AIM v6.0 PRO 🔥"
    title.TextColor3 = Color3.fromRGB(0, 255, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.Parent = guiMainFrame
    
    -- Mode buttons
    legitBtn = Instance.new("TextButton")
    legitBtn.Size = UDim2.new(0, 80, 0, 30)
    legitBtn.Position = UDim2.new(0.08, 0, 0.18, 0)
    legitBtn.Text = "LEGIT"
    legitBtn.TextColor3 = Color3.fromRGB(255,255,255)
    legitBtn.BackgroundColor3 = Config.aimMode == "legit" and Color3.fromRGB(0,150,150) or Color3.fromRGB(80,80,100)
    legitBtn.BorderSizePixel = 0
    legitBtn.Font = Enum.Font.GothamBold
    legitBtn.TextSize = 13
    legitBtn.Parent = guiMainFrame
    local legitCorner = Instance.new("UICorner")
    legitCorner.CornerRadius = UDim.new(0, 8)
    legitCorner.Parent = legitBtn
    
    rageBtn = Instance.new("TextButton")
    rageBtn.Size = UDim2.new(0, 80, 0, 30)
    rageBtn.Position = UDim2.new(0.4, 0, 0.18, 0)
    rageBtn.Text = "RAGE"
    rageBtn.TextColor3 = Color3.fromRGB(255,255,255)
    rageBtn.BackgroundColor3 = Config.aimMode == "rage" and Color3.fromRGB(0,150,150) or Color3.fromRGB(80,80,100)
    rageBtn.BorderSizePixel = 0
    rageBtn.Font = Enum.Font.GothamBold
    rageBtn.TextSize = 13
    rageBtn.Parent = guiMainFrame
    local rageCorner = Instance.new("UICorner")
    rageCorner.CornerRadius = UDim.new(0, 8)
    rageCorner.Parent = rageBtn
    
    -- Toggles
    espToggle = Instance.new("TextButton")
    espToggle.Size = UDim2.new(0, 100, 0, 30)
    espToggle.Position = UDim2.new(0.08, 0, 0.32, 0)
    espToggle.Text = "ESP " .. (Config.espEnabled and "ON" or "OFF")
    espToggle.TextColor3 = Color3.fromRGB(255,255,255)
    espToggle.BackgroundColor3 = Config.espEnabled and Color3.fromRGB(0,150,150) or Color3.fromRGB(80,80,100)
    espToggle.BorderSizePixel = 0
    espToggle.Font = Enum.Font.GothamBold
    espToggle.TextSize = 13
    espToggle.Parent = guiMainFrame
    local espCorner = Instance.new("UICorner")
    espCorner.CornerRadius = UDim.new(0, 8)
    espCorner.Parent = espToggle
    
    teamCheckToggle = Instance.new("TextButton")
    teamCheckToggle.Size = UDim2.new(0, 100, 0, 30)
    teamCheckToggle.Position = UDim2.new(0.6, 0, 0.32, 0)
    teamCheckToggle.Text = "TEAM " .. (Config.teamCheck and "ON" or "OFF")
    teamCheckToggle.TextColor3 = Color3.fromRGB(255,255,255)
    teamCheckToggle.BackgroundColor3 = Config.teamCheck and Color3.fromRGB(0,150,150) or Color3.fromRGB(80,80,100)
    teamCheckToggle.BorderSizePixel = 0
    teamCheckToggle.Font = Enum.Font.GothamBold
    teamCheckToggle.TextSize = 13
    teamCheckToggle.Parent = guiMainFrame
    local teamCorner = Instance.new("UICorner")
    teamCorner.CornerRadius = UDim.new(0, 8)
    teamCorner.Parent = teamCheckToggle
    
    -- FOV Slider
    fovLabel = Instance.new("TextLabel")
    fovLabel.Size = UDim2.new(0.8, 0, 0, 20)
    fovLabel.Position = UDim2.new(0.1, 0, 0.48, 0)
    fovLabel.Text = "FOV: " .. Config.aimFOV
    fovLabel.TextColor3 = Color3.fromRGB(200,200,200)
    fovLabel.BackgroundTransparency = 1
    fovLabel.Font = Enum.Font.Gotham
    fovLabel.TextSize = 12
    fovLabel.TextXAlignment = Enum.TextXAlignment.Left
    fovLabel.Parent = guiMainFrame
    
    local fovSliderBg = Instance.new("Frame")
    fovSliderBg.Size = UDim2.new(0.8, 0, 0, 4)
    fovSliderBg.Position = UDim2.new(0.1, 0, 0.56, 0)
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
    smoothLabel.Position = UDim2.new(0.1, 0, 0.68, 0)
    smoothLabel.Text = "SMOOTH: " .. string.format("%.2f", Config.smoothness)
    smoothLabel.TextColor3 = Color3.fromRGB(200,200,200)
    smoothLabel.BackgroundTransparency = 1
    smoothLabel.Font = Enum.Font.Gotham
    smoothLabel.TextSize = 12
    smoothLabel.TextXAlignment = Enum.TextXAlignment.Left
    smoothLabel.Parent = guiMainFrame
    
    local smoothSliderBg = Instance.new("Frame")
    smoothSliderBg.Size = UDim2.new(0.8, 0, 0, 4)
    smoothSliderBg.Position = UDim2.new(0.1, 0, 0.76, 0)
    smoothSliderBg.BackgroundColor3 = Color3.fromRGB(50,50,70)
    smoothSliderBg.BorderSizePixel = 0
    smoothSliderBg.Parent = guiMainFrame
    local smoothCorner = Instance.new("UICorner")
    smoothCorner.CornerRadius = UDim.new(1, 0)
    smoothCorner.Parent = smoothSliderBg
    
    smoothFill = Instance.new("Frame")
    smoothFill.Size = UDim2.new(Config.smoothness / 0.2, 0, 1, 0)
    smoothFill.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
    smoothFill.BorderSizePixel = 0
    smoothFill.Parent = smoothSliderBg
    local smoothFillCorner = Instance.new("UICorner")
    smoothFillCorner.CornerRadius = UDim.new(1, 0)
    smoothFillCorner.Parent = smoothFill
    
    -- Status
    lockStatusLabel = Instance.new("TextLabel")
    lockStatusLabel.Size = UDim2.new(0.8, 0, 0, 20)
    lockStatusLabel.Position = UDim2.new(0.1, 0, 0.88, 0)
    lockStatusLabel.Text = "TARGET: NONE"
    lockStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    lockStatusLabel.BackgroundTransparency = 1
    lockStatusLabel.Font = Enum.Font.GothamBold
    lockStatusLabel.TextSize = 12
    lockStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    lockStatusLabel.Parent = guiMainFrame
    
    -- Slider drag logic
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
            Config.smoothness = relX * 0.2
            smoothLabel.Text = "SMOOTH: " .. string.format("%.2f", Config.smoothness)
            smoothFill.Size = UDim2.new(Config.smoothness / 0.2, 0, 1, 0)
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
            Config.smoothness = relX * 0.2
            smoothLabel.Text = "SMOOTH: " .. string.format("%.2f", Config.smoothness)
            smoothFill.Size = UDim2.new(Config.smoothness / 0.2, 0, 1, 0)
        end
    end)
    
    -- Button actions
    espToggle.MouseButton1Click:Connect(function()
        Config.espEnabled = not Config.espEnabled
        espToggle.Text = "ESP " .. (Config.espEnabled and "ON" or "OFF")
        espToggle.BackgroundColor3 = Config.espEnabled and Color3.fromRGB(0,150,150) or Color3.fromRGB(80,80,100)
    end)
    teamCheckToggle.MouseButton1Click:Connect(function()
        Config.teamCheck = not Config.teamCheck
        teamCheckToggle.Text = "TEAM " .. (Config.teamCheck and "ON" or "OFF")
        teamCheckToggle.BackgroundColor3 = Config.teamCheck and Color3.fromRGB(0,150,150) or Color3.fromRGB(80,80,100)
        myTeam = nil
    end)
    legitBtn.MouseButton1Click:Connect(function()
        Config.aimMode = "legit"
        legitBtn.BackgroundColor3 = Color3.fromRGB(0,150,150)
        rageBtn.BackgroundColor3 = Color3.fromRGB(80,80,100)
    end)
    rageBtn.MouseButton1Click:Connect(function()
        Config.aimMode = "rage"
        rageBtn.BackgroundColor3 = Color3.fromRGB(0,150,150)
        legitBtn.BackgroundColor3 = Color3.fromRGB(80,80,100)
    end)
    
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
    
    -- Update lock status
    RunService.RenderStepped:Connect(function()
        if Config.enabled and currentTarget then
            lockStatusLabel.Text = "🔒 LOCKED: " .. currentTarget.Name
            lockStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        elseif Config.enabled then
            lockStatusLabel.Text = "🎯 SEARCHING..."
            lockStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
        else
            lockStatusLabel.Text = "⚡ AIM OFF"
            lockStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
    end)
end

-- ============================================================================
-- KEYBINDS
-- ============================================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F then
        Config.espEnabled = not Config.espEnabled
        if espToggle then
            espToggle.Text = "ESP " .. (Config.espEnabled and "ON" or "OFF")
            espToggle.BackgroundColor3 = Config.espEnabled and Color3.fromRGB(0,150,150) or Color3.fromRGB(80,80,100)
        end
    elseif input.KeyCode == Enum.KeyCode.V then
        Config.enabled = not Config.enabled
        if aimToggle then
            aimToggle.Text = "AIM " .. (Config.enabled and "ON" or "OFF")
            aimToggle.BackgroundColor3 = Config.enabled and Color3.fromRGB(0,150,150) or Color3.fromRGB(80,80,100)
        end
        if not Config.enabled then
            currentTarget = nil
            currentTargetPart = nil
        end
        updateFOVCircle()
    elseif input.KeyCode == Enum.KeyCode.RightShift then
        toggleGUI()
    end
end)

-- ============================================================================
-- MAIN LOOP (Physics-based aim dengan deltaTime)
-- ============================================================================
local lastTime = tick()
RunService.RenderStepped:Connect(function(deltaTime)
    local now = tick()
    local dt = math.min(0.033, now - lastTime)
    lastTime = now
    
    updateTarget()
    updateESP()
    updateFOVCircle()
    updateAim(dt)
    applyXAxisCorrection()
    updateBehindEffect()
    
    -- Hit indicator (sederhana: jika target di tengah layar)
    if currentTargetPart then
        local screenPos = getScreenPosition(currentTargetPart.Position)
        if screenPos then
            local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
            if (screenPos - center).Magnitude < 20 then
                showHitIndicator()
            end
        end
    end
    
    if currentTarget and currentTargetPart and Config.lockEffectEnabled then
        createLockEffect(currentTargetPart)
    end
end)

-- ============================================================================
-- CLEANUP & INIT
-- ============================================================================
Players.PlayerRemoving:Connect(function(player)
    if espObjects[player] then
        for _, v in pairs(espObjects[player]) do v:Remove() end
        espObjects[player] = nil
    end
end)

createCrosshair()
createGUI()
updateFOVCircle()

print("🔥 CYBERHEROES AGGRESSIVE AIM v6.0 PRO loaded! 🔥")
print("F = ESP | V = Auto Aim | RightShift = Toggle GUI")
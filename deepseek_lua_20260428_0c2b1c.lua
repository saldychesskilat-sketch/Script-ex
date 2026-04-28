--[[
    ============================================================================
    CYBERHEROES DELTA EXECUTOR - ULTIMATE SCRIPT v2.0
    Fitur Lengkap: Movement, Visual, Automation, Advanced Systems
    Compatible: Delta Executor, Synapse X, Krnl
    Author: CyberHeroes AI
    Date: 2026-04-28
    ============================================================================
--]]

-- ============================================================================
--                               ENVIRONMENT SETUP
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local localCharacter = nil
local localHumanoid = nil
local localRootPart = nil

-- Global state persistence
local state = getgenv().CyberState or {}
_G.CyberState = state

-- Default configuration
local config = {
    -- Movement
    speedBoostEnabled = false,
    speedValue = 50,
    superJumpEnabled = false,
    jumpPower = 100,
    teleportEnabled = false,
    dashEnabled = false,
    dashDistance = 20,
    noclipEnabled = false,
    flyEnabled = false,
    flySpeed = 80,
    godModeEnabled = false,
    
    -- Visual
    espEnabled = false,
    espColor = Color3.fromRGB(0, 255, 0),
    nameTagEnabled = false,
    distanceIndicatorEnabled = false,
    fovIndicatorEnabled = false,
    fovRadius = 120,
    
    -- Automation
    autoFarmEnabled = false,
    farmRadius = 30,
    autoSkillCheckEnabled = false,
    autoCollectEnabled = false,
    autoInteractEnabled = false,
    bypassCooldownEnabled = false,
    
    -- UI
    guiVisible = true,
    toggleKey = Enum.KeyCode.F,
    notificationDuration = 2,
    
    -- Advanced
    predictionEnabled = false,
    predictionFactor = 0.2,
}

-- Merge with saved state
for k, v in pairs(config) do
    if state[k] == nil then state[k] = v end
end
for k, v in pairs(state) do
    config[k] = v
end

-- ============================================================================
--                               UTILITY FUNCTIONS
-- ============================================================================
local function getLocalCharacter()
    localCharacter = localPlayer.Character
    if localCharacter then
        localHumanoid = localCharacter:FindFirstChildWhichIsA("Humanoid")
        localRootPart = localCharacter:FindFirstChild("HumanoidRootPart") or localCharacter:FindFirstChild("Torso") or localCharacter:FindFirstChild("UpperTorso")
    end
    return localCharacter
end

local function notify(title, text, duration)
    if not config.guiVisible then return end
    if not screenGui then return end
    local notifFrame = Instance.new("Frame")
    notifFrame.Size = UDim2.new(0, 280, 0, 50)
    notifFrame.Position = UDim2.new(0.5, -140, 0.85, 0)
    notifFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    notifFrame.BackgroundTransparency = 0.2
    notifFrame.BorderSizePixel = 0
    notifFrame.Parent = screenGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = notifFrame
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 20)
    titleLabel.Position = UDim2.new(0, 5, 0, 0)
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(0, 230, 255)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 12
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = notifFrame
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 0, 25)
    textLabel.Position = UDim2.new(0, 5, 0, 20)
    textLabel.Text = text
    textLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    textLabel.BackgroundTransparency = 1
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextSize = 10
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Parent = notifFrame
    task.spawn(function()
        wait(duration or config.notificationDuration)
        local tween = TweenService:Create(notifFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {BackgroundTransparency = 1})
        tween:Play()
        wait(0.3)
        notifFrame:Destroy()
    end)
end

-- ============================================================================
--                               MOVEMENT SYSTEM
-- ============================================================================
local speedConnection = nil
local noclipConnection = nil
local flyConnection = nil
local godConnection = nil
local dashDebounce = false

-- Speed Boost
local function updateSpeed()
    if not getLocalCharacter() then return end
    if config.speedBoostEnabled then
        localHumanoid.WalkSpeed = config.speedValue
    else
        localHumanoid.WalkSpeed = 16
    end
end

local function toggleSpeed(state)
    config.speedBoostEnabled = state
    updateSpeed()
    notify("Speed Boost", state and "ON" or "OFF")
end

-- Super Jump
local function applySuperJump()
    if not config.superJumpEnabled then return end
    localHumanoid.JumpPower = config.superJumpEnabled and config.jumpPower or 50
end

local function toggleSuperJump(state)
    config.superJumpEnabled = state
    applySuperJump()
    notify("Super Jump", state and "ON" or "OFF")
end

-- Teleport to mouse
local function teleportToMouse()
    local mouse = localPlayer:GetMouse()
    local target = mouse.Hit
    if target and localRootPart then
        localRootPart.CFrame = CFrame.new(target.Position)
        notify("Teleport", "Teleported to cursor")
    end
end

-- Dash (Blink)
local function dash()
    if not config.dashEnabled then return end
    if dashDebounce then return end
    dashDebounce = true
    local direction = camera.CFrame.LookVector
    local newPos = localRootPart.Position + direction * config.dashDistance
    localRootPart.CFrame = CFrame.new(newPos)
    notify("Dash", "Dashed " .. config.dashDistance .. " studs")
    task.wait(0.5)
    dashDebounce = false
end

-- Noclip
local function applyNoclip(state)
    if not getLocalCharacter() then return end
    for _, part in ipairs(localCharacter:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = not state
        end
    end
end

local function toggleNoclip(state)
    config.noclipEnabled = state
    applyNoclip(state)
    notify("Noclip", state and "ON" or "OFF")
end

-- Fly System
local bodyVelocity = nil
local bodyGyro = nil

local function startFly()
    if flyConnection then return end
    if not getLocalCharacter() then return end
    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bodyVelocity.Parent = localRootPart
    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    bodyGyro.Parent = localRootPart
    flyConnection = RunService.RenderStepped:Connect(function()
        if not config.flyEnabled then return end
        if not localRootPart then return end
        local moveDirection = Vector3.zero
        local uis = UserInputService
        if uis:IsKeyDown(Enum.KeyCode.W) then moveDirection = moveDirection + camera.CFrame.LookVector end
        if uis:IsKeyDown(Enum.KeyCode.S) then moveDirection = moveDirection - camera.CFrame.LookVector end
        if uis:IsKeyDown(Enum.KeyCode.A) then moveDirection = moveDirection - camera.CFrame.RightVector end
        if uis:IsKeyDown(Enum.KeyCode.D) then moveDirection = moveDirection + camera.CFrame.RightVector end
        if uis:IsKeyDown(Enum.KeyCode.Space) then moveDirection = moveDirection + Vector3.new(0, 1, 0) end
        if uis:IsKeyDown(Enum.KeyCode.LeftControl) then moveDirection = moveDirection - Vector3.new(0, 1, 0) end
        local velocity = moveDirection * config.flySpeed
        bodyVelocity.Velocity = velocity
        bodyGyro.CFrame = camera.CFrame
    end)
end

local function stopFly()
    if flyConnection then flyConnection:Disconnect(); flyConnection = nil end
    if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity = nil end
    if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end
end

local function toggleFly(state)
    config.flyEnabled = state
    if state then
        startFly()
    else
        stopFly()
    end
    notify("Fly", state and "ON" or "OFF")
end

-- God Mode (Invincible)
local function startGodMode()
    if godConnection then return end
    godConnection = RunService.Heartbeat:Connect(function()
        if not config.godModeEnabled then return end
        if not getLocalCharacter() or not localHumanoid then return end
        local maxHealth = localHumanoid.MaxHealth
        localHumanoid.Health = maxHealth
    end)
end

local function stopGodMode()
    if godConnection then godConnection:Disconnect(); godConnection = nil end
end

local function toggleGodMode(state)
    config.godModeEnabled = state
    if state then
        startGodMode()
    else
        stopGodMode()
    end
    notify("God Mode", state and "ON" or "OFF")
end

-- ============================================================================
--                               VISUAL SYSTEMS
-- ============================================================================
local espHighlights = {}
local nameTagData = {}
local distanceData = {}

local function createESP(player)
    if espHighlights[player.UserId] then
        pcall(function() espHighlights[player.UserId]:Destroy() end)
    end
    local character = player.Character
    if not character then return end
    local highlight = Instance.new("Highlight")
    highlight.Name = "CyberESP"
    highlight.FillColor = config.espColor
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = config.espColor
    highlight.OutlineTransparency = 0.2
    highlight.Adornee = character
    highlight.Parent = character
    espHighlights[player.UserId] = highlight
end

local function updateESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            if config.espEnabled then
                createESP(player)
            else
                if espHighlights[player.UserId] then
                    espHighlights[player.UserId]:Destroy()
                    espHighlights[player.UserId] = nil
                end
            end
        end
    end
end

local function toggleESP(state)
    config.espEnabled = state
    updateESP()
    notify("ESP", state and "ON" or "OFF")
end

-- NameTag System
local function createNameTag(player)
    if nameTagData[player.UserId] then
        pcall(function() nameTagData[player.UserId]:Destroy() end)
    end
    local character = player.Character
    if not character then return end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "CyberNameTag"
    billboard.Adornee = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    billboard.Size = UDim2.new(0, 120, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.Parent = character
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = player.Name
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0.5
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = billboard
    nameTagData[player.UserId] = billboard
end

local function updateNameTags()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            if config.nameTagEnabled then
                createNameTag(player)
            else
                if nameTagData[player.UserId] then
                    nameTagData[player.UserId]:Destroy()
                    nameTagData[player.UserId] = nil
                end
            end
        end
    end
end

local function toggleNameTag(state)
    config.nameTagEnabled = state
    updateNameTags()
    notify("NameTag", state and "ON" or "OFF")
end

-- Distance Indicator (added to name tag)
local function updateDistanceIndicators()
    if not config.distanceIndicatorEnabled then return end
    if not localRootPart then return end
    for playerId, billboard in pairs(nameTagData) do
        if billboard and billboard.Parent then
            local player = Players:GetPlayerByUserId(playerId)
            if player and player.Character then
                local charPos = player.Character:GetPivot().Position
                local dist = (localRootPart.Position - charPos).Magnitude
                local label = billboard:FindFirstChildWhichIsA("TextLabel")
                if label then
                    label.Text = player.Name .. "  [" .. math.floor(dist) .. " studs]"
                end
            end
        end
    end
end

-- FOV Indicator (circle on screen)
local fovCircle = nil
local function createFOVIndicator()
    if fovCircle then fovCircle:Destroy() end
    if not config.fovIndicatorEnabled then return end
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberFOV"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = CoreGui
    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, config.fovRadius * 2, 0, config.fovRadius * 2)
    circle.Position = UDim2.new(0.5, -config.fovRadius, 0.5, -config.fovRadius)
    circle.BackgroundTransparency = 1
    circle.BorderSizePixel = 0
    circle.Parent = screenGui
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 0, 0)
    stroke.Thickness = 2
    stroke.Transparency = 0.5
    stroke.Parent = circle
    fovCircle = screenGui
end

local function toggleFOV(state)
    config.fovIndicatorEnabled = state
    if state then
        createFOVIndicator()
    else
        if fovCircle then fovCircle:Destroy(); fovCircle = nil end
    end
    notify("FOV Indicator", state and "ON" or "OFF")
end

-- ============================================================================
--                               AUTOMATION SYSTEMS
-- ============================================================================
local autoFarmConnection = nil
local autoCollectConnection = nil
local autoInteractConnection = nil
local autoSkillConnection = nil

-- Auto Farm (nearest object with ClickDetector/ProximityPrompt)
local function findNearestFarmable()
    local nearest = nil
    local minDist = math.huge
    if not localRootPart then return nil end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local isTarget = false
        if obj:IsA("ClickDetector") or obj:IsA("ProximityPrompt") then
            isTarget = true
        elseif obj:IsA("BasePart") and (obj:FindFirstChildWhichIsA("ClickDetector") or obj:FindFirstChildWhichIsA("ProximityPrompt")) then
            isTarget = true
        end
        if isTarget then
            local pos = obj:IsA("BasePart") and obj.Position or (obj.Parent and obj.Parent:IsA("BasePart") and obj.Parent.Position)
            if pos then
                local dist = (localRootPart.Position - pos).Magnitude
                if dist < minDist and dist <= config.farmRadius then
                    minDist = dist
                    nearest = obj
                end
            end
        end
    end
    return nearest
end

local function doFarm()
    if not config.autoFarmEnabled then return end
    if not getLocalCharacter() or not localRootPart then return end
    local target = findNearestFarmable()
    if target then
        local targetPos = target:IsA("BasePart") and target.Position or (target.Parent and target.Parent:IsA("BasePart") and target.Parent.Position)
        if targetPos then
            localRootPart.CFrame = CFrame.new(targetPos)
            task.wait(0.05)
            if target:IsA("ClickDetector") then
                pcall(function() target:FireClick() end)
            elseif target:IsA("ProximityPrompt") then
                pcall(function() target:Hold(); task.wait(0.1); target:Release() end)
            end
        end
    end
end

local function startAutoFarm()
    if autoFarmConnection then return end
    autoFarmConnection = RunService.Heartbeat:Connect(doFarm)
end

local function stopAutoFarm()
    if autoFarmConnection then autoFarmConnection:Disconnect(); autoFarmConnection = nil end
end

local function toggleAutoFarm(state)
    config.autoFarmEnabled = state
    if state then
        startAutoFarm()
    else
        stopAutoFarm()
    end
    notify("Auto Farm", state and "ON" or "OFF")
end

-- Auto Collect (collect nearby pickups)
local function findNearestCollectable()
    local nearest = nil
    local minDist = math.huge
    if not localRootPart then return nil end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and (obj.Name:lower():find("coin") or obj.Name:lower():find("collect") or obj.Name:lower():find("orb") or obj.Name:lower():find("drop")) then
            local dist = (localRootPart.Position - obj.Position).Magnitude
            if dist < minDist and dist <= config.farmRadius then
                minDist = dist
                nearest = obj
            end
        end
    end
    return nearest
end

local function doCollect()
    if not config.autoCollectEnabled then return end
    if not getLocalCharacter() or not localRootPart then return end
    local target = findNearestCollectable()
    if target then
        localRootPart.CFrame = CFrame.new(target.Position)
        task.wait(0.05)
        pcall(function() target:Destroy() end) -- fallback
    end
end

local function startAutoCollect()
    if autoCollectConnection then return end
    autoCollectConnection = RunService.Heartbeat:Connect(doCollect)
end

local function stopAutoCollect()
    if autoCollectConnection then autoCollectConnection:Disconnect(); autoCollectConnection = nil end
end

local function toggleAutoCollect(state)
    config.autoCollectEnabled = state
    if state then startAutoCollect() else stopAutoCollect() end
    notify("Auto Collect", state and "ON" or "OFF")
end

-- Auto Interact (click all visible buttons with "interact" keywords)
local function doAutoInteract()
    if not config.autoInteractEnabled then return end
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        for _, button in ipairs(playerGui:GetDescendants()) do
            if button:IsA("TextButton") or button:IsA("ImageButton") then
                local text = (button.Text or ""):lower()
                if text:find("claim") or text:find("collect") or text:find("next") or text:find("skip") or text:find("interact") then
                    if button.Visible and button.Active then
                        pcall(function() button:FireClick() end)
                        wait(0.5)
                    end
                end
            end
        end
    end
end

local function startAutoInteract()
    if autoInteractConnection then return end
    autoInteractConnection = RunService.Heartbeat:Connect(doAutoInteract)
end

local function stopAutoInteract()
    if autoInteractConnection then autoInteractConnection:Disconnect(); autoInteractConnection = nil end
end

local function toggleAutoInteract(state)
    config.autoInteractEnabled = state
    if state then startAutoInteract() else stopAutoInteract() end
    notify("Auto Interact", state and "ON" or "OFF")
end

-- Auto Skill Check (advanced detection)
local autoSkillConnection = nil
local skillCheckDetected = false
local lastPress = 0

local function findSkillCheckGUI()
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    for _, gui in ipairs(playerGui:GetDescendants()) do
        if gui:IsA("Frame") and gui.Name:lower():find("skill") then
            return gui
        end
    end
    return nil
end

local function doSkillCheck()
    if not config.autoSkillCheckEnabled then return end
    local skillGui = findSkillCheckGUI()
    if skillGui and skillGui.Visible then
        local success = false
        if tick() - lastPress > 0.2 then
            -- Simulate click on skill check button
            local button = skillGui:FindFirstChildWhichIsA("TextButton") or skillGui:FindFirstChildWhichIsA("ImageButton")
            if button then
                pcall(function() button:FireClick() end)
                success = true
            else
                -- Fallback: send touch at center of GUI
                local absPos = skillGui.AbsolutePosition
                local size = skillGui.AbsoluteSize
                local cx = absPos.X + size.X/2
                local cy = absPos.Y + size.Y/2
                pcall(function()
                    VirtualInputManager:SendTouchEvent(1, 0, cx, cy)
                    task.wait(0.01)
                    VirtualInputManager:SendTouchEvent(1, 2, cx, cy)
                end)
                success = true
            end
            lastPress = tick()
        end
        if success then
            notify("Skill Check", "Success")
        end
    end
end

local function startAutoSkill()
    if autoSkillConnection then return end
    autoSkillConnection = RunService.Heartbeat:Connect(doSkillCheck)
end

local function stopAutoSkill()
    if autoSkillConnection then autoSkillConnection:Disconnect(); autoSkillConnection = nil end
end

local function toggleAutoSkill(state)
    config.autoSkillCheckEnabled = state
    if state then startAutoSkill() else stopAutoSkill() end
    notify("Auto Skill Check", state and "ON" or "OFF")
end

-- Cooldown Bypass (logic-based: find cooldown values and set to 0)
local function bypassCooldowns()
    if not config.bypassCooldownEnabled then return end
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("NumberValue") and (obj.Name:lower():find("cooldown") or obj.Name:lower():find("cd")) then
            pcall(function() obj.Value = 0 end)
        elseif obj:IsA("BoolValue") and obj.Name:lower():find("cooldown") then
            pcall(function() obj.Value = false end)
        end
    end
end

local bypassConnection = nil
local function startBypass()
    if bypassConnection then return end
    bypassConnection = RunService.Heartbeat:Connect(bypassCooldowns)
end

local function stopBypass()
    if bypassConnection then bypassConnection:Disconnect(); bypassConnection = nil end
end

local function toggleBypass(state)
    config.bypassCooldownEnabled = state
    if state then startBypass() else stopBypass() end
    notify("Cooldown Bypass", state and "ON" or "OFF")
end

-- ============================================================================
--                               ADVANCED SYSTEMS
-- ============================================================================
-- Prediction System (target movement prediction)
local function predictPosition(targetPlayer, time)
    if not config.predictionEnabled then return targetPlayer.Character and targetPlayer.Character:GetPivot().Position end
    local char = targetPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return char:GetPivot().Position end
    local currentPos = root.Position
    local velocity = root.AssemblyLinearVelocity
    return currentPos + velocity * time * config.predictionFactor
end

-- State Machine (simple player state)
local playerState = "idle" -- idle, running, flying, combat
local function updateStateMachine()
    if not getLocalCharacter() then playerState = "idle"; return end
    if config.flyEnabled then
        playerState = "flying"
    elseif localHumanoid and localHumanoid.MoveDirection.Magnitude > 0 then
        playerState = "running"
    elseif localHumanoid and localHumanoid.Health < localHumanoid.MaxHealth then
        playerState = "combat"
    else
        playerState = "idle"
    end
end

-- Tween Animation System
local function tweenPart(part, targetCFrame, duration)
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(part, tweenInfo, {CFrame = targetCFrame})
    tween:Play()
    return tween
end

-- Raycasting System (check line of sight)
local function lineOfSight(startPos, endPos, ignoreList)
    local ray = Ray.new(startPos, (endPos - startPos).Unit * (endPos - startPos).Magnitude)
    local hit = Workspace:FindPartOnRayWithIgnoreList(ray, ignoreList or {localCharacter})
    return not hit
end

-- Client-Server Sync Logic (simulate sync by throttling events)
local syncQueue = {}
local lastSyncTime = 0
local function syncToServer(remote, data)
    if not remote then return end
    if tick() - lastSyncTime < 0.1 then
        table.insert(syncQueue, {remote, data})
        return
    end
    pcall(function() remote:FireServer(data) end)
    lastSyncTime = tick()
    for _, item in ipairs(syncQueue) do
        local rem, dt = item[1], item[2]
        pcall(function() rem:FireServer(dt) end)
    end
    syncQueue = {}
end

-- ============================================================================
--                               GUI SYSTEM
-- ============================================================================
local screenGui = nil
local mainFrame = nil
local floatingLogo = nil
local isGuiMinimized = false

local function makeDraggable(frame)
    local dragging = false
    local dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    frame.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                      startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    frame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

local function createGUI()
    if screenGui then screenGui:Destroy() end
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroesGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = CoreGui

    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 380, 0, 480)
    mainFrame.Position = UDim2.new(0.5, -190, 0.3, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 10, 15)
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

    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(15, 5, 10)
    titleBar.BackgroundTransparency = 0.2
    titleBar.Parent = mainFrame
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.7, 0, 1, 0)
    title.Position = UDim2.new(0.02, 0, 0, 0)
    title.Text = "CYBERHEROES ULTIMATE"
    title.TextColor3 = Color3.fromRGB(0, 230, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 25, 0, 25)
    minimizeBtn.Position = UDim2.new(1, -55, 0, 2)
    minimizeBtn.Text = "−"
    minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(40, 10, 15)
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextSize = 18
    minimizeBtn.Parent = titleBar
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Position = UDim2.new(1, -28, 0, 2)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.BackgroundColor3 = Color3.fromRGB(40, 10, 15)
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.Parent = titleBar

    local contentScroller = Instance.new("ScrollingFrame")
    contentScroller.Size = UDim2.new(1, -10, 1, -40)
    contentScroller.Position = UDim2.new(0, 5, 0, 35)
    contentScroller.BackgroundTransparency = 1
    contentScroller.BorderSizePixel = 0
    contentScroller.CanvasSize = UDim2.new(0, 0, 0, 800)
    contentScroller.ScrollBarThickness = 6
    contentScroller.Parent = mainFrame
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = contentScroller

    -- Helper to create toggle button
    local function addToggle(text, configKey, icon, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.9, 0, 0, 32)
        btn.Text = icon .. "  " .. text .. (config[configKey] and " [ON]" or " [OFF]")
        btn.BackgroundColor3 = config[configKey] and Color3.fromRGB(40, 10, 15) or Color3.fromRGB(25, 5, 10)
        btn.BackgroundTransparency = 0.2
        btn.TextColor3 = config[configKey] and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)
        btn.TextSize = 12
        btn.Font = Enum.Font.GothamBold
        btn.BorderSizePixel = 0
        btn.Parent = contentScroller
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = btn
        btn.MouseButton1Click:Connect(function()
            config[configKey] = not config[configKey]
            btn.Text = icon .. "  " .. text .. (config[configKey] and " [ON]" or " [OFF]")
            btn.BackgroundColor3 = config[configKey] and Color3.fromRGB(40, 10, 15) or Color3.fromRGB(25, 5, 10)
            btn.TextColor3 = config[configKey] and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)
            if callback then callback(config[configKey]) end
            notify(text, config[configKey] and "Enabled" or "Disabled")
        end)
        return btn
    end

    -- Movement section
    local moveLabel = Instance.new("TextLabel")
    moveLabel.Size = UDim2.new(0.9, 0, 0, 20)
    moveLabel.Text = "⚡ MOVEMENT"
    moveLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    moveLabel.BackgroundTransparency = 1
    moveLabel.Font = Enum.Font.GothamBold
    moveLabel.TextSize = 14
    moveLabel.TextXAlignment = Enum.TextXAlignment.Left
    moveLabel.Parent = contentScroller

    addToggle("Speed Boost", "speedBoostEnabled", "🏃", function(s) toggleSpeed(s) end)
    -- Speed slider (value)
    local speedSlider = Instance.new("TextBox")
    speedSlider.Size = UDim2.new(0.4, 0, 0, 25)
    speedSlider.Position = UDim2.new(0.5, 0, 0, 0)
    speedSlider.Text = tostring(config.speedValue)
    speedSlider.PlaceholderText = "Speed"
    speedSlider.BackgroundColor3 = Color3.fromRGB(30, 10, 15)
    speedSlider.TextColor3 = Color3.fromRGB(255, 255, 255)
    speedSlider.Font = Enum.Font.Gotham
    speedSlider.TextSize = 12
    speedSlider.Parent = contentScroller
    speedSlider.FocusLost:Connect(function()
        local val = tonumber(speedSlider.Text)
        if val then config.speedValue = val; updateSpeed() end
    end)

    addToggle("Super Jump", "superJumpEnabled", "🦘", function(s) toggleSuperJump(s) end)
    local jumpSlider = Instance.new("TextBox")
    jumpSlider.Size = UDim2.new(0.4, 0, 0, 25)
    jumpSlider.Text = tostring(config.jumpPower)
    jumpSlider.PlaceholderText = "Jump Power"
    jumpSlider.BackgroundColor3 = Color3.fromRGB(30, 10, 15)
    jumpSlider.TextColor3 = Color3.fromRGB(255, 255, 255)
    jumpSlider.Font = Enum.Font.Gotham
    jumpSlider.TextSize = 12
    jumpSlider.Parent = contentScroller
    jumpSlider.FocusLost:Connect(function()
        local val = tonumber(jumpSlider.Text)
        if val then config.jumpPower = val; applySuperJump() end
    end)

    addToggle("Dash (Blink)", "dashEnabled", "💨", nil)
    local dashSlider = Instance.new("TextBox")
    dashSlider.Size = UDim2.new(0.4, 0, 0, 25)
    dashSlider.Text = tostring(config.dashDistance)
    dashSlider.PlaceholderText = "Dash Distance"
    dashSlider.Parent = contentScroller
    dashSlider.FocusLost:Connect(function()
        local val = tonumber(dashSlider.Text)
        if val then config.dashDistance = val end
    end)

    addToggle("NoClip", "noclipEnabled", "🔓", function(s) toggleNoclip(s) end)
    addToggle("Fly", "flyEnabled", "✈️", function(s) toggleFly(s) end)
    local flySlider = Instance.new("TextBox")
    flySlider.Size = UDim2.new(0.4, 0, 0, 25)
    flySlider.Text = tostring(config.flySpeed)
    flySlider.PlaceholderText = "Fly Speed"
    flySlider.Parent = contentScroller
    flySlider.FocusLost:Connect(function()
        local val = tonumber(flySlider.Text)
        if val then config.flySpeed = val end
    end)

    addToggle("God Mode", "godModeEnabled", "🛡️", function(s) toggleGodMode(s) end)

    -- Visual section
    local visualLabel = Instance.new("TextLabel")
    visualLabel.Size = UDim2.new(0.9, 0, 0, 20)
    visualLabel.Text = "👁️ VISUAL"
    visualLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    visualLabel.BackgroundTransparency = 1
    visualLabel.Font = Enum.Font.GothamBold
    visualLabel.TextSize = 14
    visualLabel.TextXAlignment = Enum.TextXAlignment.Left
    visualLabel.Parent = contentScroller

    addToggle("ESP", "espEnabled", "🔍", function(s) toggleESP(s) end)
    addToggle("NameTag", "nameTagEnabled", "🏷️", function(s) toggleNameTag(s) end)
    addToggle("Distance Indicator", "distanceIndicatorEnabled", "📏", function(s) config.distanceIndicatorEnabled = s; notify("Distance Indicator", s and "ON" or "OFF") end)
    addToggle("FOV Indicator", "fovIndicatorEnabled", "🎯", function(s) toggleFOV(s) end)
    local fovSlider = Instance.new("TextBox")
    fovSlider.Size = UDim2.new(0.4, 0, 0, 25)
    fovSlider.Text = tostring(config.fovRadius)
    fovSlider.PlaceholderText = "FOV Radius"
    fovSlider.Parent = contentScroller
    fovSlider.FocusLost:Connect(function()
        local val = tonumber(fovSlider.Text)
        if val then config.fovRadius = val; createFOVIndicator() end
    end)

    -- Automation section
    local autoLabel = Instance.new("TextLabel")
    autoLabel.Size = UDim2.new(0.9, 0, 0, 20)
    autoLabel.Text = "🤖 AUTOMATION"
    autoLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    autoLabel.BackgroundTransparency = 1
    autoLabel.Font = Enum.Font.GothamBold
    autoLabel.TextSize = 14
    autoLabel.TextXAlignment = Enum.TextXAlignment.Left
    autoLabel.Parent = contentScroller

    addToggle("Auto Farm", "autoFarmEnabled", "🌾", function(s) toggleAutoFarm(s) end)
    local farmSlider = Instance.new("TextBox")
    farmSlider.Size = UDim2.new(0.4, 0, 0, 25)
    farmSlider.Text = tostring(config.farmRadius)
    farmSlider.PlaceholderText = "Farm Radius"
    farmSlider.Parent = contentScroller
    farmSlider.FocusLost:Connect(function()
        local val = tonumber(farmSlider.Text)
        if val then config.farmRadius = val end
    end)

    addToggle("Auto Skill Check", "autoSkillCheckEnabled", "🎮", function(s) toggleAutoSkill(s) end)
    addToggle("Auto Collect", "autoCollectEnabled", "💰", function(s) toggleAutoCollect(s) end)
    addToggle("Auto Interact", "autoInteractEnabled", "🔄", function(s) toggleAutoInteract(s) end)
    addToggle("Cooldown Bypass", "bypassCooldownEnabled", "⏩", function(s) toggleBypass(s) end)

    -- Advanced section
    local advLabel = Instance.new("TextLabel")
    advLabel.Size = UDim2.new(0.9, 0, 0, 20)
    advLabel.Text = "⚙️ ADVANCED"
    advLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    advLabel.BackgroundTransparency = 1
    advLabel.Font = Enum.Font.GothamBold
    advLabel.TextSize = 14
    advLabel.TextXAlignment = Enum.TextXAlignment.Left
    advLabel.Parent = contentScroller

    addToggle("Prediction System", "predictionEnabled", "🔮", function(s) config.predictionEnabled = s; notify("Prediction", s and "ON" or "OFF") end)
    local predSlider = Instance.new("TextBox")
    predSlider.Size = UDim2.new(0.4, 0, 0, 25)
    predSlider.Text = tostring(config.predictionFactor)
    predSlider.PlaceholderText = "Prediction Factor"
    predSlider.Parent = contentScroller
    predSlider.FocusLost:Connect(function()
        local val = tonumber(predSlider.Text)
        if val then config.predictionFactor = val end
    end)

    -- Teleport button
    local tpBtn = Instance.new("TextButton")
    tpBtn.Size = UDim2.new(0.9, 0, 0, 32)
    tpBtn.Text = "📍 TELEPORT TO MOUSE"
    tpBtn.BackgroundColor3 = Color3.fromRGB(40, 10, 15)
    tpBtn.TextColor3 = Color3.fromRGB(0, 230, 255)
    tpBtn.Font = Enum.Font.GothamBold
    tpBtn.TextSize = 12
    tpBtn.Parent = contentScroller
    tpBtn.MouseButton1Click:Connect(teleportToMouse)

    -- Dash button
    local dashBtn = Instance.new("TextButton")
    dashBtn.Size = UDim2.new(0.9, 0, 0, 32)
    dashBtn.Text = "💨 DASH NOW"
    dashBtn.BackgroundColor3 = Color3.fromRGB(40, 10, 15)
    dashBtn.TextColor3 = Color3.fromRGB(0, 230, 255)
    dashBtn.Font = Enum.Font.GothamBold
    dashBtn.TextSize = 12
    dashBtn.Parent = contentScroller
    dashBtn.MouseButton1Click:Connect(dash)

    -- Minimize/restore logic
    minimizeBtn.MouseButton1Click:Connect(function()
        if isGuiMinimized then
            mainFrame.Visible = true
            if floatingLogo then floatingLogo:Destroy(); floatingLogo = nil end
            isGuiMinimized = false
        else
            mainFrame.Visible = false
            if not floatingLogo then
                floatingLogo = Instance.new("ImageButton")
                floatingLogo.Name = "CyberLogo"
                floatingLogo.Size = UDim2.new(0, 40, 0, 40)
                floatingLogo.Position = UDim2.new(0.02, 0, 0.85, 0)
                floatingLogo.BackgroundColor3 = Color3.fromRGB(30, 10, 15)
                floatingLogo.BackgroundTransparency = 0.2
                floatingLogo.Image = "rbxassetid://6031091979"
                floatingLogo.ImageColor3 = Color3.fromRGB(255, 80, 80)
                floatingLogo.Parent = CoreGui
                local logoCorner = Instance.new("UICorner")
                logoCorner.CornerRadius = UDim.new(1, 0)
                logoCorner.Parent = floatingLogo
                floatingLogo.MouseButton1Click:Connect(function()
                    floatingLogo:Destroy()
                    mainFrame.Visible = true
                    isGuiMinimized = false
                end)
                makeDraggable(floatingLogo)
            end
            isGuiMinimized = true
        end
    end)

    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
        if floatingLogo then floatingLogo:Destroy() end
    end)

    makeDraggable(mainFrame)
end

-- ============================================================================
--                               KEYBIND SYSTEM
-- ============================================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == config.toggleKey then
        if screenGui and mainFrame then
            mainFrame.Visible = not mainFrame.Visible
            config.guiVisible = mainFrame.Visible
            if not mainFrame.Visible and not floatingLogo then
                -- already minimized
            else
                if floatingLogo then floatingLogo:Destroy(); floatingLogo = nil end
            end
        end
    end
    if input.KeyCode == Enum.KeyCode.Q and config.dashEnabled then
        dash()
    end
    if input.KeyCode == Enum.KeyCode.T and config.flyEnabled then
        -- toggle fly? no, just a helpful note
    end
end)

-- ============================================================================
--                               STATE MACHINE & LOOP
-- ============================================================================
local function mainLoop()
    updateStateMachine()
    if config.speedBoostEnabled then updateSpeed() end
    if config.superJumpEnabled then applySuperJump() end
    if config.nameTagEnabled and config.distanceIndicatorEnabled then
        updateDistanceIndicators()
    end
    if config.espEnabled then updateESP() end
    if config.nameTagEnabled then updateNameTags() end
    if config.autoSkillCheckEnabled then doSkillCheck() end
    if config.autoFarmEnabled then doFarm() end
    if config.autoCollectEnabled then doCollect() end
    if config.autoInteractEnabled then doAutoInteract() end
end

local loopConnection = RunService.Heartbeat:Connect(mainLoop)

-- ============================================================================
--                               INITIALIZATION
-- ============================================================================
local function init()
    print("╔═══════════════════════════════════════════════════════════════╗")
    print("║       CYBERHEROES ULTIMATE SCRIPT v2.0 LOADED                ║")
    print("║    Features: Movement, Visual, Automation, Advanced          ║")
    print("║    Press F to toggle GUI | Q to Dash                         ║")
    print("╚═══════════════════════════════════════════════════════════════╝")
    getLocalCharacter()
    if localPlayer.Character then
        onCharacterAdded(localPlayer.Character)
    end
    localPlayer.CharacterAdded:Connect(onCharacterAdded)
    createGUI()
    -- start default states
    if config.speedBoostEnabled then updateSpeed() end
    if config.superJumpEnabled then applySuperJump() end
    if config.noclipEnabled then applyNoclip(true) end
    if config.flyEnabled then toggleFly(true) end
    if config.godModeEnabled then toggleGodMode(true) end
    if config.espEnabled then updateESP() end
    if config.nameTagEnabled then updateNameTags() end
    if config.fovIndicatorEnabled then createFOVIndicator() end
    if config.autoFarmEnabled then startAutoFarm() end
    if config.autoCollectEnabled then startAutoCollect() end
    if config.autoInteractEnabled then startAutoInteract() end
    if config.autoSkillCheckEnabled then startAutoSkill() end
    if config.bypassCooldownEnabled then startBypass() end
end

local function onCharacterAdded(character)
    localCharacter = character
    localHumanoid = character:FindFirstChildWhichIsA("Humanoid")
    localRootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    if localHumanoid then
        config.originalWalkSpeed = localHumanoid.WalkSpeed
        if config.speedBoostEnabled then localHumanoid.WalkSpeed = config.speedValue end
        if config.superJumpEnabled then localHumanoid.JumpPower = config.jumpPower end
    end
    if config.noclipEnabled then applyNoclip(true) end
    if config.flyEnabled then
        stopFly()
        startFly()
    end
end

-- Run
task.wait(1)
init()
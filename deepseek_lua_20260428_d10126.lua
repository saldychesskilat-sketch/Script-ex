-- ============================================================================
-- CYBERHEROES OMNI SUITE v2.0 (Delta Executor)
-- Modular Exploit Framework with 20+ features
-- Optimized, lag-free, production-ready
-- ============================================================================

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
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ============================================================================
-- PERSISTENT STATE (getgenv)
-- ============================================================================
local _G = getgenv()
if not _G.CyberHeroesOmni then
    _G.CyberHeroesOmni = {
        config = {
            speedEnabled = false,
            speedValue = 50,
            superJumpEnabled = false,
            superJumpPower = 80,
            teleportEnabled = false,
            dashEnabled = false,
            dashDistance = 15,
            noclipEnabled = false,
            wallClimbEnabled = false,
            wallClimbSpeed = 30,
            glideEnabled = false,
            glideDrag = 0.95,
            espEnabled = false,
            fovEnabled = false,
            fovRadius = 120,
            autoFarmEnabled = false,
            autoSkillCheckEnabled = false,
            autoCollectEnabled = false,
            autoInteractEnabled = false,
            cooldownBypassEnabled = false,
            notificationEnabled = true,
            predictionEnabled = false,
            guiVisible = true,
            minimized = false,
        },
        keybinds = {
            toggleGui = Enum.KeyCode.F12,
            teleport = Enum.KeyCode.T,
            dash = Enum.KeyCode.Q,
            noclip = Enum.KeyCode.N,
            wallClimb = Enum.KeyCode.C,
            glide = Enum.KeyCode.G,
            superJump = Enum.KeyCode.Space,
        },
        state = {
            currentState = "idle", -- idle, moving, airborne, climbing, gliding
            lastVelocity = Vector3.zero,
            lastPosition = Vector3.zero,
            groundDetected = false,
            wallDetected = false,
            wallNormal = Vector3.zero,
        },
        espObjects = {},
        activeConnections = {},
        cachedRemotes = {},
    }
end
local state = _G.CyberHeroesOmni
local config = state.config
local keybinds = state.keybinds

-- ============================================================================
-- LOCAL VARIABLES
-- ============================================================================
local character = nil
local humanoid = nil
local rootPart = nil
local originalWalkSpeed = 16
local originalJumpPower = 50
local bodyVelocity = nil
local noclipParts = {}
local espHighlights = {}
local tracerLines = {}
local nametagBillboards = {}
local distanceLabels = {}
local activeFarmTarget = nil
local farmLoopConnection = nil
local skillCheckConnection = nil
local collectLoopConnection = nil
local interactLoopConnection = nil
local predictionConnections = {}
local screenGui = nil
local mainFrame = nil
local minimizeBtn = nil
local toggleButtons = {}
local fovCircle = nil
local isFOVVisible = false
local isMinimized = false
local notificationQueue = {}
local notificationGui = nil
local debounce = {}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================
local function getCharacter()
    character = localPlayer.Character
    if character then
        humanoid = character:FindFirstChildOfClass("Humanoid")
        rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    end
    return character
end

local function safeCall(func, ...)
    local success, err = pcall(func, ...)
    if not success then
        warn("Error: " .. tostring(err))
    end
    return success
end

local function createNotification(title, text, duration)
    if not config.notificationEnabled then return end
    if not notificationGui then
        notificationGui = Instance.new("ScreenGui")
        notificationGui.Name = "CyberHeroes_Notifications"
        notificationGui.Parent = CoreGui
        notificationGui.ResetOnSpawn = false
    end
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 250, 0, 60)
    frame.Position = UDim2.new(1, -260, 0, 5)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = notificationGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 20)
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 12
    titleLabel.Parent = frame
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 0, 30)
    textLabel.Position = UDim2.new(0, 0, 0, 20)
    textLabel.Text = text
    textLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    textLabel.BackgroundTransparency = 1
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextSize = 10
    textLabel.TextWrapped = true
    textLabel.Parent = frame
    local tween = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Position = UDim2.new(1, -260, 0, 5)})
    tween:Play()
    task.delay(duration or 3, function()
        local outTween = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Position = UDim2.new(1, 0, 0, 5)})
        outTween:Play()
        outTween.Completed:Wait()
        frame:Destroy()
    end)
end

-- ============================================================================
-- RAYCASTING SYSTEM
-- ============================================================================
local function raycastFromPoint(origin, direction, length, ignoreList)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = ignoreList or {character}
    local result = workspace:Raycast(origin, direction * length, raycastParams)
    return result
end

local function isGrounded()
    if not rootPart then return false end
    local result = raycastFromPoint(rootPart.Position, Vector3.new(0, -1, 0), 3, {character})
    return result ~= nil
end

local function getWallNormal()
    if not rootPart then return nil end
    local forward = rootPart.CFrame.LookVector
    local result = raycastFromPoint(rootPart.Position, forward, 2, {character})
    if result then
        return result.Normal
    end
    return nil
end

-- ============================================================================
-- STATE MACHINE
-- ============================================================================
local function updateState()
    if not humanoid or not rootPart then return end
    local vel = rootPart.AssemblyLinearVelocity
    local speed = vel.Magnitude
    local grounded = isGrounded()
    local wallNormal = getWallNormal()
    if wallNormal and config.wallClimbEnabled and not grounded then
        state.state.currentState = "climbing"
    elseif not grounded then
        state.state.currentState = "airborne"
    elseif speed > 1 then
        state.state.currentState = "moving"
    else
        state.state.currentState = "idle"
    end
    state.state.lastVelocity = vel
    state.state.lastPosition = rootPart.Position
    state.state.groundDetected = grounded
    state.state.wallDetected = wallNormal ~= nil
    if wallNormal then state.state.wallNormal = wallNormal end
end

-- ============================================================================
-- SPEED BOOST (BodyVelocity based)
-- ============================================================================
local function applySpeedBoost()
    if not config.speedEnabled then
        if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity = nil end
        if humanoid then humanoid.WalkSpeed = originalWalkSpeed end
        return
    end
    if not humanoid then return end
    humanoid.WalkSpeed = config.speedValue
    -- optional: BodyVelocity for extra push when moving
    local moveDir = humanoid.MoveDirection
    if moveDir.Magnitude > 0.1 then
        if not bodyVelocity then
            bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            bodyVelocity.Parent = rootPart
        end
        bodyVelocity.Velocity = moveDir * config.speedValue
    else
        if bodyVelocity then
            bodyVelocity:Destroy()
            bodyVelocity = nil
        end
    end
end

-- ============================================================================
-- SUPER JUMP
-- ============================================================================
local function superJump()
    if not config.superJumpEnabled then return end
    if not humanoid or not isGrounded() then return end
    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    local impulse = Vector3.new(0, config.superJumpPower, 0)
    if rootPart then
        rootPart.AssemblyLinearVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, config.superJumpPower, rootPart.AssemblyLinearVelocity.Z)
    end
    createNotification("Super Jump", "Jump power " .. config.superJumpPower, 1)
end

-- ============================================================================
-- TELEPORT TO CURSOR / TARGET
-- ============================================================================
local function teleportToMouse()
    if not config.teleportEnabled then return end
    local mouse = localPlayer:GetMouse()
    local unitRay = camera:ViewportPointToRay(mouse.X, mouse.Y)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {character}
    local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)
    if result and rootPart then
        local targetPos = result.Position + Vector3.new(0, 3, 0) -- slightly above ground
        rootPart.CFrame = CFrame.new(targetPos)
        createNotification("Teleport", "Moved to cursor position", 1)
    else
        createNotification("Teleport", "No valid surface", 1)
    end
end

local function teleportToNearestPlayer()
    if not config.teleportEnabled then return end
    local nearest = nil
    local minDist = math.huge
    local localPos = rootPart and rootPart.Position or Vector3.zero
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local dist = (char.HumanoidRootPart.Position - localPos).Magnitude
                if dist < minDist then
                    minDist = dist
                    nearest = player
                end
            end
        end
    end
    if nearest and rootPart then
        local targetPos = nearest.Character.HumanoidRootPart.Position + Vector3.new(0, 2, 0)
        rootPart.CFrame = CFrame.new(targetPos)
        createNotification("Teleport", "Teleported to " .. nearest.Name, 1)
    end
end

-- ============================================================================
-- DASH/BLINK
-- ============================================================================
local function dash()
    if not config.dashEnabled then return end
    if not rootPart then return end
    local direction = camera.CFrame.LookVector
    local newPos = rootPart.Position + direction * config.dashDistance
    local tween = TweenService:Create(rootPart, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {CFrame = CFrame.new(newPos)})
    tween:Play()
    createNotification("Dash", "Blinked forward", 0.5)
end

-- ============================================================================
-- NOCLIP TOGGLE
-- ============================================================================
local function setNoclip(state)
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = not state
        end
    end
    createNotification("Noclip", state and "Enabled" or "Disabled", 1)
end

-- ============================================================================
-- WALL CLIMB
-- ============================================================================
local function wallClimbHandler()
    if not config.wallClimbEnabled then return end
    if state.state.currentState ~= "climbing" then return end
    local moveDir = humanoid and humanoid.MoveDirection
    if moveDir and moveDir.Magnitude > 0.1 then
        local climbDirection = Vector3.new(0, config.wallClimbSpeed, 0)
        rootPart.AssemblyLinearVelocity = climbDirection
    end
end

-- ============================================================================
-- GLIDE / AIR CONTROL
-- ============================================================================
local function glideHandler()
    if not config.glideEnabled then return end
    if state.state.currentState ~= "airborne" then return end
    local moveDir = humanoid and humanoid.MoveDirection
    if moveDir and moveDir.Magnitude > 0.1 then
        local currentVel = rootPart.AssemblyLinearVelocity
        local horizontalVel = Vector3.new(currentVel.X, 0, currentVel.Z)
        local newVel = moveDir * (horizontalVel.Magnitude + 10) + Vector3.new(0, currentVel.Y * 0.95, 0)
        rootPart.AssemblyLinearVelocity = newVel
    else
        -- reduce falling speed
        if rootPart.AssemblyLinearVelocity.Y < 0 then
            rootPart.AssemblyLinearVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, rootPart.AssemblyLinearVelocity.Y * 0.95, rootPart.AssemblyLinearVelocity.Z)
        end
    end
end

-- ============================================================================
-- ESP SYSTEM (Highlight + Tracer + Nametag + Distance)
-- ============================================================================
local function createESPForPlayer(player)
    if espHighlights[player.UserId] then
        -- cleanup existing
        if espHighlights[player.UserId].Highlight then espHighlights[player.UserId].Highlight:Destroy() end
        if tracerLines[player.UserId] then tracerLines[player.UserId]:Destroy() end
        if nametagBillboards[player.UserId] then nametagBillboards[player.UserId]:Destroy() end
        if distanceLabels[player.UserId] then distanceLabels[player.UserId]:Destroy() end
        espHighlights[player.UserId] = nil
    end
    local char = player.Character
    if not char then return end
    local highlight = Instance.new("Highlight")
    highlight.Name = "CyberHeroes_ESP"
    highlight.FillColor = Color3.fromRGB(255, 0, 150)
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.fromRGB(0, 200, 255)
    highlight.OutlineTransparency = 0.2
    highlight.Adornee = char
    highlight.Parent = char

    -- Tracer line (beam from camera to player)
    local tracer = Instance.new("Part")
    tracer.Size = Vector3.new(0.1, 0.1, 0.1)
    tracer.Anchored = true
    tracer.CanCollide = false
    tracer.BrickColor = BrickColor.new("Bright red")
    tracer.Material = Enum.Material.Neon
    tracer.Parent = Workspace

    -- Billboard nametag
    local billboard = Instance.new("BillboardGui")
    billboard.Adornee = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    billboard.Size = UDim2.new(0, 120, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.Parent = char
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Parent = billboard

    -- Distance label
    local distLabel = Instance.new("BillboardGui")
    distLabel.Adornee = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    distLabel.Size = UDim2.new(0, 60, 0, 20)
    distLabel.StudsOffset = Vector3.new(0, 3, 0)
    distLabel.Parent = char
    local distText = Instance.new("TextLabel")
    distText.Size = UDim2.new(1, 0, 1, 0)
    distText.BackgroundTransparency = 1
    distText.TextColor3 = Color3.fromRGB(0, 255, 0)
    distText.TextScaled = true
    distText.Font = Enum.Font.Gotham
    distText.Parent = distLabel

    espHighlights[player.UserId] = {Highlight = highlight, Billboard = billboard, DistLabel = distLabel, DistText = distText}
    tracerLines[player.UserId] = tracer
    nametagBillboards[player.UserId] = billboard
    distanceLabels[player.UserId] = distLabel

    -- update tracer and distance
    local function updateTracerAndDistance()
        if not config.espEnabled then return end
        local charPos = char and char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart.Position
        if charPos and rootPart then
            local dist = (rootPart.Position - charPos).Magnitude
            if distText then distText.Text = string.format("%.1f", dist) .. " studs" end
            if tracer then
                local camPos = camera.CFrame.Position
                local direction = (charPos - camPos).Unit
                local length = (charPos - camPos).Magnitude
                tracer.Size = Vector3.new(0.1, length, 0.1)
                tracer.CFrame = CFrame.new(camPos, charPos) * CFrame.new(0, 0, -length/2)
            end
        end
    end
    -- Connect to heartbeat for real-time update
    local conn = RunService.Heartbeat:Connect(updateTracerAndDistance)
    table.insert(state.activeConnections, conn)
end

local function clearAllESP()
    for uid, data in pairs(espHighlights) do
        if data.Highlight then data.Highlight:Destroy() end
        if data.Billboard then data.Billboard:Destroy() end
        if data.DistLabel then data.DistLabel:Destroy() end
    end
    for _, tracer in pairs(tracerLines) do
        if tracer then tracer:Destroy() end
    end
    espHighlights = {}
    tracerLines = {}
    nametagBillboards = {}
    distanceLabels = {}
end

local function updateESP()
    if not config.espEnabled then
        clearAllESP()
        return
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            createESPForPlayer(player)
        end
    end
end

-- ============================================================================
-- FOV INDICATOR
-- ============================================================================
local function createFOVCircle()
    if fovCircle then fovCircle:Destroy() end
    if not config.fovEnabled then return end
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "FOVIndicator"
    screenGui.Parent = CoreGui
    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, config.fovRadius*2, 0, config.fovRadius*2)
    circle.Position = UDim2.new(0.5, -config.fovRadius, 0.5, -config.fovRadius)
    circle.BackgroundTransparency = 1
    circle.BorderSizePixel = 0
    circle.Parent = screenGui
    local img = Instance.new("ImageLabel")
    img.Size = UDim2.new(1, 0, 1, 0)
    img.Image = "rbxassetid://339895640" -- circle image
    img.ImageColor3 = Color3.fromRGB(0, 200, 255)
    img.BackgroundTransparency = 1
    img.Parent = circle
    fovCircle = screenGui
end

-- ============================================================================
-- AUTO FARM (detect nearest ClickDetector/ProximityPrompt and move)
-- ============================================================================
local function findNearestInteractable()
    local nearest = nil
    local minDist = math.huge
    local localPos = rootPart and rootPart.Position
    if not localPos then return nil end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ClickDetector") or obj:IsA("ProximityPrompt") then
            local parent = obj.Parent
            if parent and parent:IsA("BasePart") then
                local dist = (parent.Position - localPos).Magnitude
                if dist < minDist then
                    minDist = dist
                    nearest = obj
                end
            end
        end
    end
    return nearest, minDist
end

local function autoFarmLoop()
    if not config.autoFarmEnabled then return end
    if not getCharacter() or not rootPart then return end
    local target, dist = findNearestInteractable()
    if target then
        if dist <= 5 then
            -- interact
            if target:IsA("ClickDetector") then
                target:FireClick()
            elseif target:IsA("ProximityPrompt") then
                target:Prompt()
            end
        else
            -- move towards
            local targetPos = target.Parent.Position
            local direction = (targetPos - rootPart.Position).Unit
            humanoid:MoveTo(targetPos)
        end
    end
end

local function startAutoFarm()
    if farmLoopConnection then farmLoopConnection:Disconnect() end
    farmLoopConnection = RunService.Heartbeat:Connect(autoFarmLoop)
end

-- ============================================================================
-- AUTO SKILL CHECK (QTE detection on GUI)
-- ============================================================================
local function detectSkillCheckUI()
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return end
    for _, gui in ipairs(playerGui:GetDescendants()) do
        if gui:IsA("Frame") and gui.Name:lower():find("skill") or gui.Name:lower():find("qte") then
            -- dummy detection: look for a rotating circle
            local rotating = gui:FindFirstChild("Circle")
            if rotating and rotating:IsA("ImageLabel") then
                -- simulate click
                local clickable = gui:FindFirstChild("ClickArea") or gui
                if clickable:IsA("TextButton") or clickable:IsA("ImageButton") then
                    clickable:FireClick()
                    createNotification("Skill Check", "Auto completed", 1)
                end
            end
        end
    end
end

local function startAutoSkillCheck()
    if skillCheckConnection then skillCheckConnection:Disconnect() end
    skillCheckConnection = RunService.Heartbeat:Connect(detectSkillCheckUI)
end

-- ============================================================================
-- AUTO COLLECT (items in radius)
-- ============================================================================
local function collectNearbyItems()
    if not config.autoCollectEnabled then return end
    if not rootPart then return end
    local radius = 15
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and (obj.Name:lower():find("item") or obj.Name:lower():find("coin") or obj:FindFirstChildWhichIsA("ClickDetector")) then
            local dist = (obj.Position - rootPart.Position).Magnitude
            if dist <= radius then
                local detector = obj:FindFirstChildWhichIsA("ClickDetector")
                if detector then
                    detector:FireClick()
                elseif obj:FindFirstChildWhichIsA("ProximityPrompt") then
                    obj:FindFirstChildWhichIsA("ProximityPrompt"):Prompt()
                end
            end
        end
    end
end

local function startAutoCollect()
    if collectLoopConnection then collectLoopConnection:Disconnect() end
    collectLoopConnection = RunService.Heartbeat:Connect(collectNearbyItems)
end

-- ============================================================================
-- AUTO INTERACT (nearest prompt/detector)
-- ============================================================================
local function autoInteractLoop()
    if not config.autoInteractEnabled then return end
    if not rootPart then return end
    local nearest, dist = findNearestInteractable()
    if nearest and dist <= 8 then
        if nearest:IsA("ClickDetector") then
            nearest:FireClick()
        elseif nearest:IsA("ProximityPrompt") then
            nearest:Prompt()
        end
    end
end

local function startAutoInteract()
    if interactLoopConnection then interactLoopConnection:Disconnect() end
    interactLoopConnection = RunService.Heartbeat:Connect(autoInteractLoop)
end

-- ============================================================================
-- COOLDOWN BYPASS (find NumberValue/IntValue with cooldown and reset)
-- ============================================================================
local function bypassCooldowns()
    if not config.cooldownBypassEnabled then return end
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        for _, v in ipairs(playerGui:GetDescendants()) do
            if v:IsA("NumberValue") and v.Name:lower():find("cooldown") then
                v.Value = 0
            elseif v:IsA("IntValue") and v.Name:lower():find("cooldown") then
                v.Value = 0
            end
        end
    end
    local backpack = localPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                for _, v in ipairs(tool:GetDescendants()) do
                    if v:IsA("NumberValue") and (v.Name:lower():find("cooldown") or v.Name:lower():find("cooldown")) then
                        v.Value = 0
                    end
                end
            end
        end
    end
end

local cooldownBypassConnection
local function startCooldownBypass()
    if cooldownBypassConnection then return end
    cooldownBypassConnection = RunService.Heartbeat:Connect(bypassCooldowns)
end

-- ============================================================================
-- PREDICTION SYSTEM (target movement)
-- ============================================================================
local predictionTargets = {}
local function updatePrediction()
    if not config.predictionEnabled then return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local vel = char.HumanoidRootPart.AssemblyLinearVelocity
                local pos = char.HumanoidRootPart.Position
                local futurePos = pos + vel * 0.5
                -- store for potential aim assist or visual
                predictionTargets[player.UserId] = futurePos
            end
        end
    end
end

local function startPrediction()
    local conn = RunService.Heartbeat:Connect(updatePrediction)
    table.insert(state.activeConnections, conn)
end

-- ============================================================================
-- CLIENT-SERVER SYNC (safe remote events)
-- ============================================================================
local function fireRemoteSafely(remoteName, ...)
    local remote = ReplicatedStorage:FindFirstChild(remoteName)
    if remote and remote:IsA("RemoteEvent") then
        remote:FireServer(...)
    elseif remote and remote:IsA("RemoteFunction") then
        return remote:InvokeServer(...)
    end
end

-- ============================================================================
-- TWEEN ANIMATION SYSTEM
-- ============================================================================
local function tweenPart(part, properties, duration, style)
    local tweenInfo = TweenInfo.new(duration, style or Enum.EasingStyle.Quad)
    local tween = TweenService:Create(part, tweenInfo, properties)
    tween:Play()
    return tween
end

-- ============================================================================
-- GUI CREATION (Draggable, Minimizable)
-- ============================================================================
local function createGUI()
    if screenGui then screenGui:Destroy() end
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroesOmniGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = CoreGui

    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 320, 0, 450)
    mainFrame.Position = UDim2.new(0.5, -160, 0.3, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = mainFrame
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 200, 255)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.3
    stroke.Parent = mainFrame

    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 10, 40)
    titleBar.BackgroundTransparency = 0.2
    titleBar.Parent = mainFrame
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = titleBar

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.Text = "OMNI SUITE v2.0"
    title.TextColor3 = Color3.fromRGB(0, 230, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 25, 0, 25)
    minimizeBtn.Position = UDim2.new(1, -55, 0, 2.5)
    minimizeBtn.Text = "—"
    minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    minimizeBtn.BackgroundTransparency = 0.2
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextSize = 16
    minimizeBtn.Parent = titleBar
    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 4)
    minCorner.Parent = minimizeBtn

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Position = UDim2.new(1, -28, 0, 2.5)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.Parent = titleBar
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeBtn

    -- Scrolling frame for buttons
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -10, 1, -40)
    scroll.Position = UDim2.new(0, 5, 0, 35)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.CanvasSize = UDim2.new(0, 0, 0, 800)
    scroll.ScrollBarThickness = 6
    scroll.Parent = mainFrame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll

    local function addToggle(text, key, colorOn, colorOff)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.9, 0, 0, 30)
        btn.Text = text .. (config[key] and " [ON]" or " [OFF]")
        btn.BackgroundColor3 = config[key] and colorOn or colorOff
        btn.BackgroundTransparency = 0.2
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.BorderSizePixel = 0
        btn.Parent = scroll
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn
        toggleButtons[key] = btn
        btn.MouseButton1Click:Connect(function()
            config[key] = not config[key]
            btn.Text = text .. (config[key] and " [ON]" or " [OFF]")
            btn.BackgroundColor3 = config[key] and colorOn or colorOff
            -- trigger feature
            if key == "speedEnabled" then applySpeedBoost()
            elseif key == "noclipEnabled" then setNoclip(config.noclipEnabled)
            elseif key == "espEnabled" then updateESP()
            elseif key == "fovEnabled" then createFOVCircle()
            elseif key == "autoFarmEnabled" then if config.autoFarmEnabled then startAutoFarm() elseif farmLoopConnection then farmLoopConnection:Disconnect() end
            elseif key == "autoSkillCheckEnabled" then if config.autoSkillCheckEnabled then startAutoSkillCheck() elseif skillCheckConnection then skillCheckConnection:Disconnect() end
            elseif key == "autoCollectEnabled" then if config.autoCollectEnabled then startAutoCollect() elseif collectLoopConnection then collectLoopConnection:Disconnect() end
            elseif key == "autoInteractEnabled" then if config.autoInteractEnabled then startAutoInteract() elseif interactLoopConnection then interactLoopConnection:Disconnect() end
            elseif key == "cooldownBypassEnabled" then if config.cooldownBypassEnabled then startCooldownBypass() elseif cooldownBypassConnection then cooldownBypassConnection:Disconnect() end
            elseif key == "predictionEnabled" then if config.predictionEnabled then startPrediction() end
            end
        end)
    end

    addToggle("⚡ Speed Boost", "speedEnabled", Color3.fromRGB(0, 120, 80), Color3.fromRGB(60, 20, 60))
    addToggle("🦘 Super Jump", "superJumpEnabled", Color3.fromRGB(0, 120, 80), Color3.fromRGB(60, 20, 60))
    addToggle("📡 Teleport", "teleportEnabled", Color3.fromRGB(0, 120, 80), Color3.fromRGB(60, 20, 60))
    addToggle("💨 Dash/Blink", "dashEnabled", Color3.fromRGB(0, 120, 80), Color3.fromRGB(60, 20, 60))
    addToggle("🌀 Noclip", "noclipEnabled", Color3.fromRGB(0, 120, 80), Color3.fromRGB(60, 20, 60))
    addToggle("🧗 Wall Climb", "wallClimbEnabled", Color3.fromRGB(0, 120, 80), Color3.fromRGB(60, 20, 60))
    addToggle("🕊️ Glide", "glideEnabled", Color3.fromRGB(0, 120, 80), Color3.fromRGB(60, 20, 60))
    addToggle("👁️ ESP", "espEnabled", Color3.fromRGB(0, 120, 80), Color3.fromRGB(60, 20, 60))
    addToggle("🎯 FOV Indicator", "fovEnabled", Color3.fromRGB(0, 120, 80), Color3.fromRGB(60, 20, 60))
    addToggle("🤖 Auto Farm", "autoFarmEnabled", Color3.fromRGB(0, 120, 80), Color3.fromRGB(60, 20, 60))
    addToggle("✅ Auto Skill Check", "autoSkillCheckEnabled", Color3.fromRGB(0, 120, 80), Color3.fromRGB(60, 20, 60))
    addToggle("📦 Auto Collect", "autoCollectEnabled", Color3.fromRGB(0, 120, 80), Color3.fromRGB(60, 20, 60))
    addToggle("🤝 Auto Interact", "autoInteractEnabled", Color3.fromRGB(0, 120, 80), Color3.fromRGB(60, 20, 60))
    addToggle("⏱️ Cooldown Bypass", "cooldownBypassEnabled", Color3.fromRGB(0, 120, 80), Color3.fromRGB(60, 20, 60))
    addToggle("📈 Prediction", "predictionEnabled", Color3.fromRGB(0, 120, 80), Color3.fromRGB(60, 20, 60))

    -- Dragging
    local dragging = false
    local dragStartPos, dragStartFrame
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStartPos = input.Position
            dragStartFrame = mainFrame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStartPos
            mainFrame.Position = UDim2.new(0, dragStartFrame.X.Offset + delta.X, 0, dragStartFrame.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    minimizeBtn.MouseButton1Click:Connect(function()
        if isMinimized then
            mainFrame.Size = UDim2.new(0, 320, 0, 450)
            isMinimized = false
            minimizeBtn.Text = "—"
        else
            mainFrame.Size = UDim2.new(0, 320, 0, 30)
            isMinimized = true
            minimizeBtn.Text = "□"
        end
    end)

    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
        screenGui = nil
    end)
end

-- ============================================================================
-- KEYBIND SYSTEM
-- ============================================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == keybinds.toggleGui then
        if screenGui and screenGui.Parent then
            screenGui:Destroy()
            screenGui = nil
        else
            createGUI()
        end
    elseif input.KeyCode == keybinds.teleport then
        teleportToMouse()
    elseif input.KeyCode == keybinds.dash then
        dash()
    elseif input.KeyCode == keybinds.noclip then
        config.noclipEnabled = not config.noclipEnabled
        setNoclip(config.noclipEnabled)
        if toggleButtons.noclipEnabled then
            toggleButtons.noclipEnabled.Text = "🌀 Noclip" .. (config.noclipEnabled and " [ON]" or " [OFF]")
            toggleButtons.noclipEnabled.BackgroundColor3 = config.noclipEnabled and Color3.fromRGB(0, 120, 80) or Color3.fromRGB(60, 20, 60)
        end
    elseif input.KeyCode == keybinds.wallClimb then
        config.wallClimbEnabled = not config.wallClimbEnabled
        if toggleButtons.wallClimbEnabled then
            toggleButtons.wallClimbEnabled.Text = "🧗 Wall Climb" .. (config.wallClimbEnabled and " [ON]" or " [OFF]")
        end
    elseif input.KeyCode == keybinds.glide then
        config.glideEnabled = not config.glideEnabled
        if toggleButtons.glideEnabled then
            toggleButtons.glideEnabled.Text = "🕊️ Glide" .. (config.glideEnabled and " [ON]" or " [OFF]")
        end
    elseif input.KeyCode == keybinds.superJump then
        superJump()
    end
end)

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
local function init()
    getCharacter()
    originalWalkSpeed = humanoid and humanoid.WalkSpeed or 16
    originalJumpPower = humanoid and humanoid.JumpPower or 50
    if config.speedEnabled then applySpeedBoost() end
    if config.noclipEnabled then setNoclip(true) end
    if config.espEnabled then updateESP() end
    if config.fovEnabled then createFOVCircle() end
    if config.autoFarmEnabled then startAutoFarm() end
    if config.autoSkillCheckEnabled then startAutoSkillCheck() end
    if config.autoCollectEnabled then startAutoCollect() end
    if config.autoInteractEnabled then startAutoInteract() end
    if config.cooldownBypassEnabled then startCooldownBypass() end
    if config.predictionEnabled then startPrediction() end
    createGUI()
    -- State machine loop
    RunService.Heartbeat:Connect(function()
        updateState()
        if config.wallClimbEnabled then wallClimbHandler() end
        if config.glideEnabled then glideHandler() end
        if config.speedEnabled then applySpeedBoost() end
    end)
    -- Character respawn handling
    localPlayer.CharacterAdded:Connect(function(newChar)
        character = newChar
        humanoid = newChar:FindFirstChildOfClass("Humanoid")
        rootPart = newChar:FindFirstChild("HumanoidRootPart") or newChar:FindFirstChild("Torso")
        originalWalkSpeed = humanoid and humanoid.WalkSpeed or 16
        originalJumpPower = humanoid and humanoid.JumpPower or 50
        if config.speedEnabled then applySpeedBoost() end
        if config.noclipEnabled then setNoclip(true) end
        if config.espEnabled then updateESP() end
        createNotification("Respawn", "Character respawned, features restored", 2)
    end)
    createNotification("Omni Suite", "All systems ready. Press F12 for GUI", 3)
end

init()
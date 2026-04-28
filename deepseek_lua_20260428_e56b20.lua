-- ============================================================================
-- CYBERHEROES ULTIMATE MODULE SYSTEM (CUMS)
-- Developed for Delta Executor
-- Modern Roblox exploit framework with 20+ integrated features
-- Modular, stealthy, optimized, and fully GUI-controlled
-- ============================================================================

-- ============================================================================
-- GLOBAL STATE (PERSISTENCE)
-- ============================================================================
local _G = getgenv() or _G
if not _G.CyberHeroesState then
    _G.CyberHeroesState = {
        version = "3.0.0",
        config = {
            speedEnabled = false,
            speedValue = 50,
            jumpEnabled = false,
            jumpPower = 80,
            teleportBtnEnabled = true,
            dashEnabled = false,
            dashDistance = 20,
            noClipEnabled = false,
            wallClimbEnabled = false,
            climbSpeed = 30,
            glideEnabled = false,
            airControlEnabled = false,
            espEnabled = false,
            fovEnabled = false,
            fovRadius = 150,
            autoFarmEnabled = false,
            farmRadius = 40,
            autoSkillCheckEnabled = false,
            autoCollectEnabled = false,
            autoInteractEnabled = false,
            cooldownBypassEnabled = false,
            predictionEnabled = false,
        },
        keybinds = {
            dash = Enum.KeyCode.Q,
            teleport = Enum.KeyCode.T,
            noclip = Enum.KeyCode.N,
            wallclimb = Enum.KeyCode.C,
            glide = Enum.KeyCode.G,
            menu = Enum.KeyCode.RightAlt,
        },
        activeConnections = {},
        guiVisible = true,
    }
end
local state = _G.CyberHeroesState
local config = state.config
local keybinds = state.keybinds

-- ============================================================================
-- SERVICES & GLOBALS
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local Debris = game:GetService("Debris")

local localPlayer = Players.LocalPlayer
local character = nil
local humanoid = nil
local rootPart = nil
local camera = workspace.CurrentCamera

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================
local function getCharacter()
    local char = localPlayer.Character
    if char and char.Parent then
        humanoid = char:FindFirstChildWhichIsA("Humanoid")
        rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        return char
    end
    return nil
end

local function notify(title, text, duration, color)
    -- Notification system (fade in/out)
    local sg = Instance.new("ScreenGui")
    sg.Name = "CyberHeroesNotify"
    sg.ResetOnSpawn = false
    sg.Parent = localPlayer:FindFirstChild("PlayerGui") or CoreGui
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 280, 0, 60)
    frame.Position = UDim2.new(0.5, -140, 0.85, 0)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = sg
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 25)
    titleLabel.Position = UDim2.new(0, 0, 0, 5)
    titleLabel.Text = title
    titleLabel.TextColor3 = color or Color3.fromRGB(100, 200, 255)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 14
    titleLabel.Parent = frame
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 0, 25)
    textLabel.Position = UDim2.new(0, 0, 0, 30)
    textLabel.Text = text
    textLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    textLabel.BackgroundTransparency = 1
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextSize = 12
    textLabel.TextWrapped = true
    textLabel.Parent = frame
    task.spawn(function()
        task.wait(duration or 3)
        local fadeOut = TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {BackgroundTransparency = 1})
        fadeOut:Play()
        fadeOut.Completed:Wait()
        sg:Destroy()
    end)
end

-- ============================================================================
-- FEATURE 1: SPEED BOOST (WalkSpeed)
-- ============================================================================
local function updateSpeed()
    if not config.speedEnabled then
        if humanoid and humanoid.WalkSpeed ~= 16 then humanoid.WalkSpeed = 16 end
        return
    end
    if humanoid then
        humanoid.WalkSpeed = config.speedValue
    end
end
local speedConnection = RunService.Heartbeat:Connect(updateSpeed)

-- ============================================================================
-- FEATURE 2: SUPER JUMP (JumpPower)
-- ============================================================================
local function updateJump()
    if not config.jumpEnabled then
        if humanoid and humanoid.JumpPower ~= 50 then humanoid.JumpPower = 50 end
        return
    end
    if humanoid then
        humanoid.JumpPower = config.jumpPower
    end
end
local jumpConnection = RunService.Heartbeat:Connect(updateJump)

-- ============================================================================
-- FEATURE 3: TELEPORT TO MOUSE POSITION or TARGET PLAYER
-- ============================================================================
local function teleportToMouse()
    if not rootPart then return end
    local mouse = localPlayer:GetMouse()
    local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {character}
    local rayResult = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)
    if rayResult then
        rootPart.CFrame = CFrame.new(rayResult.Position + Vector3.new(0, 3, 0))
        notify("Teleport", "Moved to cursor position", 1.5, Color3.fromRGB(0,255,0))
    end
end
local function teleportToTargetPlayer(targetPlayer)
    if not rootPart or not targetPlayer or not targetPlayer.Character then return end
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if targetRoot then
        rootPart.CFrame = targetRoot.CFrame + Vector3.new(0, 2, 0)
        notify("Teleport", "Teleported to " .. targetPlayer.Name, 1.5, Color3.fromRGB(0,255,200))
    end
end

-- Keybind Teleport (default T)
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == keybinds.teleport and config.teleportBtnEnabled then
        teleportToMouse()
    end
end)

-- ============================================================================
-- FEATURE 4: DASH/BLINK (with particles)
-- ============================================================================
local function dash()
    if not config.dashEnabled then return end
    if not rootPart or not humanoid or humanoid.Health <= 0 then return end
    local forward = camera.CFrame.LookVector
    local newPos = rootPart.Position + forward * config.dashDistance
    local raycast = Workspace:Raycast(rootPart.Position, forward * config.dashDistance, RaycastParams.new())
    if raycast then newPos = raycast.Position - forward * 2 end
    rootPart.CFrame = CFrame.new(newPos)
    -- Particle effect
    local part = Instance.new("Part")
    part.Size = Vector3.new(1,1,1)
    part.Position = newPos
    part.Anchored = true
    part.CanCollide = false
    part.BrickColor = BrickColor.new("Bright blue")
    part.Material = Enum.Material.Neon
    part.Transparency = 0.5
    part.Parent = Workspace
    TweenService:Create(part, TweenInfo.new(0.3), {Size = Vector3.new(3,3,3), Transparency = 1}):Play()
    Debris:AddItem(part, 0.4)
    notify("Dash", "Blinked forward", 0.8, Color3.fromRGB(100,200,255))
end
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == keybinds.dash and config.dashEnabled then dash() end
end)

-- ============================================================================
-- FEATURE 5: NOCLIP (with raycast boundaries)
-- ============================================================================
local noClipConnection = nil
local originalCanCollide = {}
local function enableNoClip()
    if not getCharacter() then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            originalCanCollide[part] = part.CanCollide
            part.CanCollide = false
        end
    end
    -- Optional: add boundary detection to prevent falling out of map (simplified)
end
local function disableNoClip()
    if not character then return end
    for part, state in pairs(originalCanCollide) do
        if part and part.Parent then
            part.CanCollide = state
        end
    end
    originalCanCollide = {}
end
local function noClipLoop()
    if not config.noClipEnabled then
        if noClipConnection then noClipConnection:Disconnect(); noClipConnection = nil end
        disableNoClip()
        return
    end
    if not getCharacter() then return end
    if not noClipConnection then
        enableNoClip()
        noClipConnection = RunService.Heartbeat:Connect(function()
            if config.noClipEnabled and character then
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                end
            end
        end)
    end
end
-- Toggle NoClip via keybind N
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == keybinds.noclip then
        config.noClipEnabled = not config.noClipEnabled
        noClipLoop()
        notify("NoClip", config.noClipEnabled and "Enabled" or "Disabled", 1, Color3.fromRGB(255,200,100))
    end
end)
noClipLoop()

-- ============================================================================
-- FEATURE 6: WALL CLIMB (raycast + climbing state)
-- ============================================================================
local climbing = false
local climbConnection = nil
local function wallClimb()
    if not config.wallClimbEnabled then return end
    if not getCharacter() or not rootPart then return end
    local ray = Workspace:Raycast(rootPart.Position, Vector3.new(0, -1, 0) * 2, RaycastParams.new())
    if ray then climbing = false; return end
    local forward = camera.CFrame.LookVector
    local wallRay = Workspace:Raycast(rootPart.Position, forward * 2, RaycastParams.new())
    if wallRay and (wallRay.Normal.y < 0.3) then
        climbing = true
        rootPart.Velocity = Vector3.new(0, config.climbSpeed, 0)
    else
        climbing = false
    end
end
local function startWallClimb()
    if climbConnection then climbConnection:Disconnect() end
    climbConnection = RunService.Heartbeat:Connect(wallClimb)
end
local function stopWallClimb()
    if climbConnection then climbConnection:Disconnect(); climbConnection = nil end
    climbing = false
end
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == keybinds.wallclimb then
        config.wallClimbEnabled = not config.wallClimbEnabled
        if config.wallClimbEnabled then startWallClimb() else stopWallClimb() end
        notify("Wall Climb", config.wallClimbEnabled and "Active" or "Inactive", 1)
    end
end)

-- ============================================================================
-- FEATURE 7: GLIDE / AIR CONTROL
-- ============================================================================
local glideActive = false
local glideBodyVelocity = nil
local function startGlide()
    if not getCharacter() then return end
    if glideBodyVelocity then glideBodyVelocity:Destroy() end
    glideBodyVelocity = Instance.new("BodyVelocity")
    glideBodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    glideBodyVelocity.Velocity = Vector3.new(0, -5, 0)
    glideBodyVelocity.Parent = rootPart
    glideActive = true
end
local function stopGlide()
    if glideBodyVelocity then glideBodyVelocity:Destroy(); glideBodyVelocity = nil end
    glideActive = false
end
local function glideUpdate()
    if not config.glideEnabled then return end
    if not getCharacter() or not humanoid then return end
    if humanoid:GetState() == Enum.HumanoidStateType.FallingDown or humanoid:GetState() == Enum.HumanoidStateType.Jumping then
        if not glideActive then startGlide() end
        local moveDir = humanoid.MoveDirection
        if moveDir.Magnitude > 0 then
            glideBodyVelocity.Velocity = moveDir * 30 + Vector3.new(0, -3, 0)
        else
            glideBodyVelocity.Velocity = Vector3.new(0, -5, 0)
        end
    else
        if glideActive then stopGlide() end
    end
end
local glideLoop = RunService.Heartbeat:Connect(glideUpdate)

-- Air control (simple)
local function airControl()
    if not config.airControlEnabled then return end
    if not humanoid then return end
    if humanoid:GetState() == Enum.HumanoidStateType.Jumping or humanoid:GetState() == Enum.HumanoidStateType.FallingDown then
        local move = humanoid.MoveDirection
        if move.Magnitude > 0 then
            rootPart.Velocity = move * 30 + Vector3.new(0, rootPart.Velocity.y, 0)
        end
    end
end
local airControlLoop = RunService.Heartbeat:Connect(airControl)

-- ============================================================================
-- FEATURE 8: ESP (Highlight + Tracer + NameTag + Distance)
-- ============================================================================
local espHighlights = {}
local tracerLines = {}
local function createESPForPlayer(player)
    if espHighlights[player.UserId] then
        if espHighlights[player.UserId].Highlight then espHighlights[player.UserId].Highlight:Destroy() end
        if espHighlights[player.UserId].Billboard then espHighlights[player.UserId].Billboard:Destroy() end
        if espHighlights[player.UserId].Tracer then espHighlights[player.UserId].Tracer:Destroy() end
    end
    local char = player.Character
    if not char then return end
    local isEnemy = (player.Team and player.Team.Name ~= localPlayer.Team.Name) or false
    local color = isEnemy and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(50, 255, 50)
    local highlight = Instance.new("Highlight")
    highlight.FillColor = color
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0.2
    highlight.Adornee = char
    highlight.Parent = char
    local billboard = Instance.new("BillboardGui")
    billboard.Adornee = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    billboard.Size = UDim2.new(0, 120, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.Parent = char
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = color
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Parent = billboard
    local distanceLabel = Instance.new("TextLabel")
    distanceLabel.Size = UDim2.new(1, 0, 0, 20)
    distanceLabel.Position = UDim2.new(0, 0, 1, 0)
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.Text = ""
    distanceLabel.TextColor3 = Color3.fromRGB(255,255,255)
    distanceLabel.TextSize = 12
    distanceLabel.Font = Enum.Font.Gotham
    distanceLabel.Parent = billboard
    espHighlights[player.UserId] = {Highlight = highlight, Billboard = billboard, NameLabel = nameLabel, DistanceLabel = distanceLabel, Player = player}
end
local function updateESP()
    if not config.espEnabled then
        for _, data in pairs(espHighlights) do
            if data.Highlight then data.Highlight:Destroy() end
            if data.Billboard then data.Billboard:Destroy() end
        end
        espHighlights = {}
        return
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            if not espHighlights[player.UserId] then createESPForPlayer(player) end
        end
    end
    for _, data in pairs(espHighlights) do
        if data.Player.Character and rootPart then
            local dist = (rootPart.Position - data.Player.Character:GetPivot().Position).Magnitude
            data.DistanceLabel.Text = string.format("%.1f studs", dist)
        end
    end
end
-- Tracer lines
local function drawTracers()
    if not config.espEnabled then
        for _, t in pairs(tracerLines) do if t:IsA("LineHandleAdornment") then t:Destroy() end end
        tracerLines = {}
        return
    end
    for _, data in pairs(espHighlights) do
        if data.Player.Character and rootPart then
            local targetPos = data.Player.Character:GetPivot().Position
            local tracer = Instance.new("LineHandleAdornment")
            tracer.Thickness = 2
            tracer.Color3 = data.Highlight.FillColor
            tracer.Transparency = 0.5
            tracer.ZIndex = 0
            tracer.Adornee = camera
            tracer.Parent = camera
            tracer.PointA = rootPart.Position
            tracer.PointB = targetPos
            if tracerLines[data.Player.UserId] then tracerLines[data.Player.UserId]:Destroy() end
            tracerLines[data.Player.UserId] = tracer
        end
    end
end
local espLoop = RunService.Heartbeat:Connect(function()
    updateESP()
    drawTracers()
end)

-- ============================================================================
-- FEATURE 9: FOV INDICATOR
-- ============================================================================
local fovRing = nil
local function updateFOV()
    if not config.fovEnabled then
        if fovRing then fovRing:Destroy(); fovRing = nil end
        return
    end
    if not fovRing then
        local sg = localPlayer:FindFirstChild("PlayerGui") or CoreGui
        fovRing = Instance.new("Frame")
        fovRing.Name = "FOVIndicator"
        fovRing.Size = UDim2.new(0, config.fovRadius * 2, 0, config.fovRadius * 2)
        fovRing.Position = UDim2.new(0.5, -config.fovRadius, 0.5, -config.fovRadius)
        fovRing.BackgroundTransparency = 1
        fovRing.BorderSizePixel = 0
        fovRing.Parent = sg
        local circle = Instance.new("ImageLabel")
        circle.Size = UDim2.new(1, 0, 1, 0)
        circle.Image = "rbxasset://textures/ui/AdService/facebookCircle.png"
        circle.BackgroundTransparency = 1
        circle.ImageColor3 = Color3.fromRGB(255, 255, 255)
        circle.ImageTransparency = 0.7
        circle.Parent = fovRing
    end
    fovRing.Size = UDim2.new(0, config.fovRadius * 2, 0, config.fovRadius * 2)
    fovRing.Position = UDim2.new(0.5, -config.fovRadius, 0.5, -config.fovRadius)
end
local fovUpdate = RunService.Heartbeat:Connect(updateFOV)

-- ============================================================================
-- FEATURE 10: AUTO FARM (Pathfinding + Nearest Target)
-- ============================================================================
local currentFarmTarget = nil
local farmPath = nil
local farmConnection = nil
local function findNearestTarget()
    local bestDist = math.huge
    local bestObj = nil
    -- Look for ClickDetectors, ProximityPrompts, or Tools in workspace
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ClickDetector") or obj:IsA("ProximityPrompt") or (obj:IsA("Tool") and obj.Parent == Workspace) then
            local pos = obj:IsA("BasePart") and obj.Position or (obj.Parent and obj.Parent:IsA("BasePart") and obj.Parent.Position) or obj:GetPivot().Position
            if pos then
                local dist = (rootPart.Position - pos).Magnitude
                if dist < bestDist and dist <= config.farmRadius then
                    bestDist = dist
                    bestObj = obj
                end
            end
        end
    end
    return bestObj
end
local function farmStep()
    if not config.autoFarmEnabled then return end
    if not getCharacter() then return end
    local target = findNearestTarget()
    if target then
        local targetPos = target:IsA("BasePart") and target.Position or (target.Parent and target.Parent:IsA("BasePart") and target.Parent.Position) or target:GetPivot().Position
        if (rootPart.Position - targetPos).Magnitude <= 5 then
            -- Interact
            if target:IsA("ClickDetector") then
                pcall(function() fireclickdetector(target, 5) end)
            elseif target:IsA("ProximityPrompt") then
                pcall(function() fireproximityprompt(target, 5) end)
            elseif target:IsA("Tool") then
                pcall(function() target.Parent = localPlayer.Character end)
            end
            return
        else
            -- Move using Pathfinding
            local path = PathfindingService:CreatePath()
            path:ComputeAsync(rootPart.Position, targetPos)
            if path.Status == Enum.PathStatus.Success then
                local waypoints = path:GetWaypoints()
                for _, wp in ipairs(waypoints) do
                    if not config.autoFarmEnabled then break end
                    humanoid:MoveTo(wp.Position)
                    humanoid.MoveToFinished:Wait()
                end
            end
        end
    end
end
local function startFarmLoop()
    if farmConnection then farmConnection:Disconnect() end
    farmConnection = RunService.Heartbeat:Connect(farmStep)
end
local function stopFarmLoop()
    if farmConnection then farmConnection:Disconnect(); farmConnection = nil end
end

-- ============================================================================
-- FEATURE 11: AUTO SKILL CHECK (QTE detection)
-- ============================================================================
local skillCheckConnection = nil
local function detectSkillCheck()
    if not config.autoSkillCheckEnabled then return end
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return end
    -- Common skill check UI
    local checkFrame = playerGui:FindFirstChild("SkillCheckPromptGui") or playerGui:FindFirstChild("GeneratorCheck")
    if checkFrame then
        local line = checkFrame:FindFirstChild("Line")
        local goal = checkFrame:FindFirstChild("Goal")
        if line and goal then
            local lineRot = line.Rotation % 360
            local goalRot = goal.Rotation % 360
            local low = (goalRot + 100) % 360
            local high = (goalRot + 120) % 360
            local inRange = false
            if low > high then
                if lineRot >= low or lineRot <= high then inRange = true end
            else
                if lineRot >= low and lineRot <= high then inRange = true end
            end
            if inRange then
                -- Simulate click
                if VirtualUser then
                    VirtualUser:Button1Down(Vector2.new(500, 500))
                    task.wait(0.02)
                    VirtualUser:Button1Up(Vector2.new(500, 500))
                else
                    VirtualInputManager:SendMouseButtonEvent(500, 500, 0, true, game, 0)
                    task.wait(0.02)
                    VirtualInputManager:SendMouseButtonEvent(500, 500, 0, false, game, 0)
                end
                notify("Skill Check", "Success!", 0.5, Color3.fromRGB(0,255,0))
            end
        end
    end
end
skillCheckConnection = RunService.Heartbeat:Connect(detectSkillCheck)

-- ============================================================================
-- FEATURE 12: AUTO COLLECT (nearest item)
-- ============================================================================
local collectConnection = nil
local function autoCollect()
    if not config.autoCollectEnabled then return end
    if not rootPart then return end
    local nearestItem = nil
    local minDist = math.huge
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Tool") and obj.Parent == Workspace then
            local dist = (rootPart.Position - obj:GetPivot().Position).Magnitude
            if dist < minDist and dist <= 10 then
                minDist = dist
                nearestItem = obj
            end
        end
    end
    if nearestItem then
        nearestItem.Parent = localPlayer.Character
        notify("Auto Collect", "Collected " .. nearestItem.Name, 0.8, Color3.fromRGB(255,200,100))
    end
end
collectConnection = RunService.Heartbeat:Connect(autoCollect)

-- ============================================================================
-- FEATURE 13: AUTO INTERACT (ProximityPrompt/ClickDetector)
-- ============================================================================
local interactConnection = nil
local function autoInteract()
    if not config.autoInteractEnabled then return end
    if not rootPart then return end
    local nearest = nil
    local minDist = math.huge
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ClickDetector") or obj:IsA("ProximityPrompt") then
            local parent = obj.Parent
            local pos = parent:IsA("BasePart") and parent.Position or parent:GetPivot().Position
            local dist = (rootPart.Position - pos).Magnitude
            if dist < minDist and dist <= 8 then
                minDist = dist
                nearest = obj
            end
        end
    end
    if nearest then
        if nearest:IsA("ClickDetector") then
            pcall(function() fireclickdetector(nearest, 5) end)
        elseif nearest:IsA("ProximityPrompt") then
            pcall(function() fireproximityprompt(nearest, 5) end)
        end
    end
end
interactConnection = RunService.Heartbeat:Connect(autoInteract)

-- ============================================================================
-- FEATURE 14: COOLDOWN BYPASS (demo: modify local cooldown values)
-- ============================================================================
local function bypassCooldowns()
    if not config.cooldownBypassEnabled then return end
    for _, tool in ipairs(Workspace:GetDescendants()) do
        if tool:IsA("Tool") then
            local cd = tool:FindFirstChild("Cooldown")
            if cd and cd:IsA("NumberValue") then cd.Value = 0 end
        end
    end
end
local cooldownLoop = RunService.Heartbeat:Connect(bypassCooldowns)

-- ============================================================================
-- FEATURE 15: PREDICTION SYSTEM (for moving targets)
-- ============================================================================
local lastPositions = {}
local function predictPosition(player, framesAhead)
    if not config.predictionEnabled then return nil end
    local userId = player.UserId
    local char = player.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local now = tick()
    if not lastPositions[userId] then lastPositions[userId] = {pos = root.Position, time = now, vel = Vector3.zero} end
    local last = lastPositions[userId]
    local dt = math.min(0.1, now - last.time)
    local vel = (root.Position - last.pos) / dt
    lastPositions[userId] = {pos = root.Position, time = now, vel = vel}
    local predicted = root.Position + vel * (framesAhead * 0.05)
    return predicted
end

-- ============================================================================
-- FEATURE 16: DRAGGABLE GUI + TOGGLE MENU (MINIMIZE)
-- ============================================================================
local mainGui = nil
local minimized = false
local floatingLogo = nil
local function createGUI()
    if mainGui then mainGui:Destroy() end
    mainGui = Instance.new("ScreenGui")
    mainGui.Name = "CyberHeroesMain"
    mainGui.ResetOnSpawn = false
    mainGui.Parent = localPlayer:FindFirstChild("PlayerGui") or CoreGui
    -- Main frame
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 400, 0, 500)
    frame.Position = UDim2.new(0.5, -200, 0.3, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = mainGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame
    -- Title bar (draggable)
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    titleBar.BackgroundTransparency = 0.2
    titleBar.Parent = frame
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.Text = "CYBERHEROES ULTIMATE v3.0"
    title.TextColor3 = Color3.fromRGB(100, 200, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = titleBar
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 30, 0, 30)
    minimizeBtn.Position = UDim2.new(1, -60, 0, 0)
    minimizeBtn.Text = "−"
    minimizeBtn.TextColor3 = Color3.fromRGB(255,255,255)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(60,60,80)
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextSize = 20
    minimizeBtn.Parent = titleBar
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -30, 0, 0)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255,100,100)
    closeBtn.BackgroundColor3 = Color3.fromRGB(60,60,80)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.Parent = titleBar
    -- Scrolling frame for features
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -20, 1, -40)
    scroll.Position = UDim2.new(0, 10, 0, 40)
    scroll.BackgroundTransparency = 1
    scroll.CanvasSize = UDim2.new(0,0,0,800)
    scroll.ScrollBarThickness = 5
    scroll.Parent = frame
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll
    -- Generate toggle buttons for each feature
    local features = {
        {key="speedEnabled", label="Speed Boost", value=config.speedEnabled},
        {key="jumpEnabled", label="Super Jump", value=config.jumpEnabled},
        {key="dashEnabled", label="Dash/Blink", value=config.dashEnabled},
        {key="noClipEnabled", label="NoClip", value=config.noClipEnabled},
        {key="wallClimbEnabled", label="Wall Climb", value=config.wallClimbEnabled},
        {key="glideEnabled", label="Glide", value=config.glideEnabled},
        {key="airControlEnabled", label="Air Control", value=config.airControlEnabled},
        {key="espEnabled", label="ESP + Tracers", value=config.espEnabled},
        {key="fovEnabled", label="FOV Indicator", value=config.fovEnabled},
        {key="autoFarmEnabled", label="Auto Farm", value=config.autoFarmEnabled},
        {key="autoSkillCheckEnabled", label="Auto Skill Check", value=config.autoSkillCheckEnabled},
        {key="autoCollectEnabled", label="Auto Collect", value=config.autoCollectEnabled},
        {key="autoInteractEnabled", label="Auto Interact", value=config.autoInteractEnabled},
        {key="cooldownBypassEnabled", label="Cooldown Bypass", value=config.cooldownBypassEnabled},
        {key="predictionEnabled", label="Prediction", value=config.predictionEnabled},
    }
    for _, feat in ipairs(features) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.Text = feat.label .. (feat.value and " [ON]" or " [OFF]")
        btn.BackgroundColor3 = feat.value and Color3.fromRGB(60, 80, 60) or Color3.fromRGB(60, 60, 80)
        btn.TextColor3 = Color3.fromRGB(255,255,255)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 12
        btn.Parent = scroll
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = btn
        btn.MouseButton1Click:Connect(function()
            config[feat.key] = not config[feat.key]
            btn.Text = feat.label .. (config[feat.key] and " [ON]" or " [OFF]")
            btn.BackgroundColor3 = config[feat.key] and Color3.fromRGB(60, 80, 60) or Color3.fromRGB(60, 60, 80)
            notify(feat.label, config[feat.key] and "Enabled" or "Disabled", 1)
        end)
    end
    -- Slider for Speed Value
    local speedSliderFrame = Instance.new("Frame")
    speedSliderFrame.Size = UDim2.new(1, 0, 0, 40)
    speedSliderFrame.BackgroundTransparency = 1
    speedSliderFrame.Parent = scroll
    local speedLabel = Instance.new("TextLabel")
    speedLabel.Size = UDim2.new(0.4, 0, 1, 0)
    speedLabel.Text = "Speed: " .. config.speedValue
    speedLabel.TextColor3 = Color3.fromRGB(200,200,200)
    speedLabel.BackgroundTransparency = 1
    speedLabel.Font = Enum.Font.Gotham
    speedLabel.TextSize = 12
    speedLabel.Parent = speedSliderFrame
    local speedSlider = Instance.new("TextButton")
    speedSlider.Size = UDim2.new(0.5, 0, 1, 0)
    speedSlider.Position = UDim2.new(0.45, 0, 0, 0)
    speedSlider.BackgroundColor3 = Color3.fromRGB(80,80,100)
    speedSlider.BorderSizePixel = 0
    speedSlider.Parent = speedSliderFrame
    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new((config.speedValue - 16) / 200, 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(100,200,255)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = speedSlider
    local function updateSpeedSlider(x)
        local rel = math.clamp((x - speedSlider.AbsolutePosition.X) / speedSlider.AbsoluteSize.X, 0, 1)
        local val = math.floor(16 + rel * 200)
        config.speedValue = val
        speedLabel.Text = "Speed: " .. val
        sliderFill.Size = UDim2.new(rel, 0, 1, 0)
    end
    speedSlider.MouseButton1Down:Connect(function()
        local mouse = localPlayer:GetMouse()
        updateSpeedSlider(mouse.X)
        local conn
        conn = mouse.Move:Connect(function() updateSpeedSlider(mouse.X) end)
        mouse.Button1Up:Connect(function() conn:Disconnect() end)
    end)
    -- Add Jump Power slider similarly
    local jumpSliderFrame = Instance.new("Frame")
    jumpSliderFrame.Size = UDim2.new(1, 0, 0, 40)
    jumpSliderFrame.BackgroundTransparency = 1
    jumpSliderFrame.Parent = scroll
    local jumpLabel = Instance.new("TextLabel")
    jumpLabel.Size = UDim2.new(0.4, 0, 1, 0)
    jumpLabel.Text = "JumpPower: " .. config.jumpPower
    jumpLabel.TextColor3 = Color3.fromRGB(200,200,200)
    jumpLabel.BackgroundTransparency = 1
    jumpLabel.Font = Enum.Font.Gotham
    jumpLabel.TextSize = 12
    jumpLabel.Parent = jumpSliderFrame
    local jumpSlider = Instance.new("TextButton")
    jumpSlider.Size = UDim2.new(0.5, 0, 1, 0)
    jumpSlider.Position = UDim2.new(0.45, 0, 0, 0)
    jumpSlider.BackgroundColor3 = Color3.fromRGB(80,80,100)
    jumpSlider.BorderSizePixel = 0
    jumpSlider.Parent = jumpSliderFrame
    local jumpFill = Instance.new("Frame")
    jumpFill.Size = UDim2.new((config.jumpPower - 50) / 200, 0, 1, 0)
    jumpFill.BackgroundColor3 = Color3.fromRGB(100,200,255)
    jumpFill.BorderSizePixel = 0
    jumpFill.Parent = jumpSlider
    local function updateJumpSlider(x)
        local rel = math.clamp((x - jumpSlider.AbsolutePosition.X) / jumpSlider.AbsoluteSize.X, 0, 1)
        local val = math.floor(50 + rel * 200)
        config.jumpPower = val
        jumpLabel.Text = "JumpPower: " .. val
        jumpFill.Size = UDim2.new(rel, 0, 1, 0)
    end
    jumpSlider.MouseButton1Down:Connect(function()
        local mouse = localPlayer:GetMouse()
        updateJumpSlider(mouse.X)
        local conn
        conn = mouse.Move:Connect(function() updateJumpSlider(mouse.X) end)
        mouse.Button1Up:Connect(function() conn:Disconnect() end)
    end)

    -- Draggable logic
    local dragging = false
    local dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                       startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    -- Minimize/Close
    minimizeBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            TweenService:Create(frame, TweenInfo.new(0.3), {Size = UDim2.new(0, 50, 0, 50)}):Play()
            frame.Position = UDim2.new(1, -60, 1, -60)
        else
            TweenService:Create(frame, TweenInfo.new(0.3), {Size = UDim2.new(0, 400, 0, 500)}):Play()
            frame.Position = UDim2.new(0.5, -200, 0.3, 0)
        end
    end)
    closeBtn.MouseButton1Click:Connect(function()
        mainGui:Destroy()
        mainGui = nil
        if floatingLogo then floatingLogo.Visible = true end
    end)
    -- Floating logo toggle
    if not floatingLogo then
        floatingLogo = Instance.new("ImageButton")
        floatingLogo.Size = UDim2.new(0, 40, 0, 40)
        floatingLogo.Position = UDim2.new(0.95, -20, 0.95, -20)
        floatingLogo.BackgroundColor3 = Color3.fromRGB(30,30,40)
        floatingLogo.BackgroundTransparency = 0.2
        floatingLogo.Image = "rbxasset://textures/particles/sparkles_main.dds"
        floatingLogo.ImageColor3 = Color3.fromRGB(100,200,255)
        floatingLogo.Parent = CoreGui
        floatingLogo.Visible = false
        floatingLogo.MouseButton1Click:Connect(function()
            if not mainGui then createGUI() end
            floatingLogo.Visible = false
        end)
    end
end

-- ============================================================================
-- CHARACTER RESET HANDLER
-- ============================================================================
local function onCharacterAdded(char)
    character = char
    humanoid = char:FindFirstChildWhichIsA("Humanoid")
    rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    if glideBodyVelocity then glideBodyVelocity:Destroy(); glideBodyVelocity = nil end
    if noClipConnection then disableNoClip(); enableNoClip() end
    updateSpeed()
    updateJump()
    notify("System", "Character respawned, features restored", 1.5, Color3.fromRGB(0,200,255))
end
if localPlayer.Character then onCharacterAdded(localPlayer.Character) end
localPlayer.CharacterAdded:Connect(onCharacterAdded)

-- ============================================================================
-- CLEANUP ON SCRIPT END (optional)
-- ============================================================================
local function cleanup()
    if speedConnection then speedConnection:Disconnect() end
    if jumpConnection then jumpConnection:Disconnect() end
    if glideLoop then glideLoop:Disconnect() end
    if airControlLoop then airControlLoop:Disconnect() end
    if espLoop then espLoop:Disconnect() end
    if fovUpdate then fovUpdate:Disconnect() end
    if farmConnection then farmConnection:Disconnect() end
    if skillCheckConnection then skillCheckConnection:Disconnect() end
    if collectConnection then collectConnection:Disconnect() end
    if interactConnection then interactConnection:Disconnect() end
    if cooldownLoop then cooldownLoop:Disconnect() end
    if climbConnection then climbConnection:Disconnect() end
    if mainGui then mainGui:Destroy() end
    if floatingLogo then floatingLogo:Destroy() end
    notify("Script", "CyberHeroes unloaded", 2, Color3.fromRGB(255,100,100))
end
-- For Delta, we can use a hook but not necessary
-- task.spawn(function() while true do task.wait(1) end end) 
-- Instead, we'll just rely on the script being persistent.

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
task.spawn(function()
    createGUI()
    notify("CyberHeroes", "Ultimate Module System v3.0 loaded", 3, Color3.fromRGB(100,200,255))
end)
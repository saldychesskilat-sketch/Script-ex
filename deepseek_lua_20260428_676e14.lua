-- ============================================================================
-- CYBERHEROES ULTIMATE OMNI EXECUTOR SCRIPT v1.0
-- Fitur lengkap: SpeedBoost, SuperJump, Teleport, Dash/Blink, NoClip, WallClimb,
-- Glide, ESP (Highlight + Tracer), NameTag + Distance, FOV Indicator, Auto Farm,
-- Auto Skill Check, Auto Collect, Auto Interact, Cooldown Bypass, Draggable GUI,
-- Minimize ke Icon, Keybind System, Notification System, Prediction System,
-- State Machine, Client-Server Sync (valid RemoteEvent), Tween Animation, Raycasting.
-- Struktur modular, performa tinggi, tidak lag.
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
local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ============================================================================
-- CONFIGURATION (DEFAULT)
-- ============================================================================
local config = {
    -- Speed Boost
    walkSpeed = 50,
    jumpPower = 80,
    -- Teleport
    teleportKey = Enum.KeyCode.T,
    -- Dash
    dashKey = Enum.KeyCode.Q,
    dashDistance = 15,
    dashCooldown = 1,
    -- NoClip
    noClipKey = Enum.KeyCode.X,
    noClipEnabled = false,
    -- Wall Climb
    wallClimbEnabled = false,
    wallClimbSpeed = 30,
    -- Glide
    glideEnabled = false,
    glideFallSpeed = 10,
    -- ESP
    espEnabled = false,
    espColor = Color3.fromRGB(0, 255, 255),
    espOutlineColor = Color3.fromRGB(255, 0, 255),
    -- Auto Farm
    autoFarmEnabled = false,
    farmTargetTag = "Collectable", -- tag atau nama object
    farmRadius = 100,
    -- Auto Skill Check
    autoSkillCheckEnabled = false,
    -- Auto Collect
    autoCollectEnabled = false,
    collectRadius = 20,
    -- Auto Interact
    autoInteractEnabled = false,
    interactRadius = 10,
    -- FOV Indicator
    fovEnabled = false,
    fovRadius = 200,
    -- Keybinds (custom)
    keybinds = {
        toggleMenu = Enum.KeyCode.F1,
        toggleNoClip = Enum.KeyCode.X,
        toggleGlide = Enum.KeyCode.G,
        toggleAutoFarm = Enum.KeyCode.F,
        dash = Enum.KeyCode.Q,
        teleport = Enum.KeyCode.T,
    },
    -- GUI
    guiVisible = true,
}

-- ============================================================================
-- STATE MACHINE
-- ============================================================================
local playerState = {
    current = "idle",
    isAirborne = false,
    isClimbing = false,
    isGliding = false,
    lastGroundTime = 0,
}

-- ============================================================================
-- GLOBAL STORAGE
-- ============================================================================
local espHighlights = {}        -- player -> highlight
local tracerLines = {}          -- player -> line part
local nameBillboards = {}       -- player -> billboard
local targetObjects = {}        -- untuk auto farm
local currentDashCooldown = 0
local noClipConnection = nil
local wallClimbConnection = nil
local glideConnection = nil
local autoFarmConnection = nil
local autoSkillCheckConnection = nil
local autoCollectConnection = nil
local autoInteractConnection = nil
local fovCircle = nil          -- ScreenGui circle
local mainGui = nil
local minimizedIcon = nil
local isGuiMinimized = false
local notifications = {}

-- ============================================================================
-- UTILITIES
-- ============================================================================
local function getCharacter()
    return localPlayer.Character
end

local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRootPart()
    local char = getCharacter()
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
end

local function showNotification(title, text, duration)
    -- Simple popup GUI
    if not mainGui then return end
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 50)
    frame.Position = UDim2.new(0.5, -100, 0.8, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = mainGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 20)
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 12
    titleLabel.Parent = frame
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 0, 25)
    textLabel.Position = UDim2.new(0, 0, 0, 20)
    textLabel.Text = text
    textLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    textLabel.BackgroundTransparency = 1
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextSize = 10
    textLabel.Parent = frame
    task.spawn(function()
        task.wait(duration or 2)
        local tween = TweenService:Create(frame, TweenInfo.new(0.3), {BackgroundTransparency = 1})
        tween:Play()
        tween.Completed:Connect(function() frame:Destroy() end)
    end)
end

-- ============================================================================
-- FEATURE: SPEED BOOST & SUPER JUMP
-- ============================================================================
local function applySpeedBoost()
    local hum = getHumanoid()
    if hum then
        hum.WalkSpeed = config.walkSpeed
        hum.JumpPower = config.jumpPower
    end
end

-- Monitor for character respawn
local function startSpeedBoostMonitor()
    local connection
    connection = localPlayer.CharacterAdded:Connect(function()
        task.wait(0.1)
        applySpeedBoost()
    end)
    applySpeedBoost()
    return connection
end

-- ============================================================================
-- FEATURE: TELEPORT TO MOUSE POSITION
-- ============================================================================
local function teleportToMouse()
    local mouse = localPlayer:GetMouse()
    local targetPos = mouse.Hit.Position
    local root = getRootPart()
    if root then
        root.CFrame = CFrame.new(targetPos)
        showNotification("Teleport", "Teleported to cursor", 1)
    end
end

-- ============================================================================
-- FEATURE: DASH / BLINK (forward based on camera)
-- ============================================================================
local function dash()
    if tick() - currentDashCooldown < config.dashCooldown then return end
    currentDashCooldown = tick()
    local root = getRootPart()
    if not root then return end
    local direction = camera.CFrame.LookVector
    local newPos = root.Position + direction * config.dashDistance
    root.CFrame = CFrame.new(newPos)
    showNotification("Dash", "Quick dash!", 0.5)
end

-- ============================================================================
-- FEATURE: NO CLIP (toggle)
-- ============================================================================
local function setNoClip(enabled)
    config.noClipEnabled = enabled
    local char = getCharacter()
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = not enabled
            end
        end
    end
    if enabled then
        if noClipConnection then noClipConnection:Disconnect() end
        noClipConnection = RunService.Stepped:Connect(function()
            if not config.noClipEnabled then
                if noClipConnection then noClipConnection:Disconnect(); noClipConnection = nil end
                return
            end
            local root = getRootPart()
            if root then
                root.Velocity = root.Velocity -- keep existing velocity
                root.CanCollide = false
            end
        end)
    else
        if noClipConnection then noClipConnection:Disconnect(); noClipConnection = nil end
        local char = getCharacter()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end
end

-- ============================================================================
-- FEATURE: WALL CLIMB (raycast to detect wall)
-- ============================================================================
local function startWallClimb()
    if wallClimbConnection then wallClimbConnection:Disconnect() end
    wallClimbConnection = RunService.Heartbeat:Connect(function()
        if not config.wallClimbEnabled then return end
        local root = getRootPart()
        if not root then return end
        local rayOrigin = root.Position
        local rayDir = root.CFrame.LookVector
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {getCharacter()}
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        local result = workspace:Raycast(rayOrigin, rayDir * 3, raycastParams)
        if result and result.Normal.Y < 0.5 then -- wall detected
            local upward = Vector3.new(0, config.wallClimbSpeed, 0)
            root.Velocity = upward
            playerState.isClimbing = true
        else
            playerState.isClimbing = false
        end
    end)
end

-- ============================================================================
-- FEATURE: GLIDE / AIR CONTROL
-- ============================================================================
local function startGlide()
    if glideConnection then glideConnection:Disconnect() end
    glideConnection = RunService.Heartbeat:Connect(function()
        if not config.glideEnabled then return end
        local hum = getHumanoid()
        local root = getRootPart()
        if not hum or not root then return end
        if hum.FloorMaterial == Enum.Material.Air then
            playerState.isAirborne = true
            playerState.isGliding = true
            -- reduce gravity effect by adjusting velocity
            local vel = root.Velocity
            if vel.Y < -config.glideFallSpeed then
                root.Velocity = Vector3.new(vel.X, -config.glideFallSpeed, vel.Z)
            end
            -- air control: allow move direction influence
            local moveDir = hum.MoveDirection
            if moveDir.Magnitude > 0 then
                root.Velocity = root.Velocity + moveDir * 20
            end
        else
            playerState.isAirborne = false
            playerState.isGliding = false
        end
    end)
end

-- ============================================================================
-- FEATURE: ESP (Highlight + Tracer)
-- ============================================================================
local function createESP(player)
    if espHighlights[player.UserId] then return end
    local char = player.Character
    if not char then return end
    local highlight = Instance.new("Highlight")
    highlight.Name = "CyberHeroes_ESP"
    highlight.FillColor = config.espColor
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = config.espOutlineColor
    highlight.OutlineTransparency = 0.2
    highlight.Adornee = char
    highlight.Parent = char
    -- Tracer line (from camera to player root)
    local line = Instance.new("Part")
    line.Size = Vector3.new(0.1, 0.1, 0.1)
    line.Anchored = true
    line.CanCollide = false
    line.BrickColor = BrickColor.new("Bright red")
    line.Material = Enum.Material.Neon
    line.Parent = Workspace
    espHighlights[player.UserId] = {Highlight = highlight, Tracer = line}
    -- update tracer position
    local conn
    conn = RunService.RenderStepped:Connect(function()
        if not config.espEnabled then
            if line then line:Destroy() end
            conn:Disconnect()
            return
        end
        if not char or not char.Parent then
            if line then line:Destroy() end
            if conn then conn:Disconnect() end
            return
        end
        local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
        if rootPart and camera then
            local start = camera.CFrame.Position
            local finish = rootPart.Position
            local distance = (start - finish).Magnitude
            local mid = (start + finish) / 2
            local dir = (finish - start).Unit
            line.Size = Vector3.new(0.1, distance, 0.1)
            line.CFrame = CFrame.lookAt(mid, finish) * CFrame.new(0, 0, -distance/2)
        end
    end)
    espHighlights[player.UserId].Connection = conn
end

local function startESP()
    Players.PlayerAdded:Connect(function(player)
        if config.espEnabled then
            player.CharacterAdded:Connect(function() createESP(player) end)
            if player.Character then createESP(player) end
        end
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            player.CharacterAdded:Connect(function() createESP(player) end)
            if player.Character then createESP(player) end
        end
    end
end

-- ============================================================================
-- FEATURE: NAMETAG + DISTANCE INDICATOR (already in ESP with billboard, here we add distance)
-- ============================================================================
local function addNameTagWithDistance(player)
    if nameBillboards[player.UserId] then return end
    local char = player.Character
    if not char then return end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "CyberHeroes_NameTag"
    billboard.Adornee = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    billboard.Size = UDim2.new(0, 150, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.Parent = char
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0.3
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Parent = billboard
    local distLabel = Instance.new("TextLabel")
    distLabel.Size = UDim2.new(1, 0, 0.4, 0)
    distLabel.Position = UDim2.new(0, 0, 0.6, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.Text = ""
    distLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    distLabel.TextScaled = true
    distLabel.Font = Enum.Font.Gotham
    distLabel.Parent = billboard
    nameBillboards[player.UserId] = {Billboard = billboard, DistLabel = distLabel}
    -- update distance
    local conn
    conn = RunService.RenderStepped:Connect(function()
        if not config.espEnabled then return end
        local root = getRootPart()
        if root and char and char.Parent then
            local targetRoot = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
            if targetRoot then
                local dist = (root.Position - targetRoot.Position).Magnitude
                distLabel.Text = string.format("%.1f studs", dist)
            end
        end
    end)
    nameBillboards[player.UserId].Connection = conn
end

local function startNameTagSystem()
    Players.PlayerAdded:Connect(function(player)
        if config.espEnabled then
            player.CharacterAdded:Connect(function() addNameTagWithDistance(player) end)
            if player.Character then addNameTagWithDistance(player) end
        end
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            player.CharacterAdded:Connect(function() addNameTagWithDistance(player) end)
            if player.Character then addNameTagWithDistance(player) end
        end
    end
end

-- ============================================================================
-- FEATURE: FOV INDICATOR (circle on screen)
-- ============================================================================
local function createFOVIndicator()
    if fovCircle then fovCircle:Destroy() end
    if not config.fovEnabled then return end
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_FOV"
    screenGui.Parent = CoreGui
    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, config.fovRadius * 2, 0, config.fovRadius * 2)
    circle.Position = UDim2.new(0.5, -config.fovRadius, 0.5, -config.fovRadius)
    circle.BackgroundTransparency = 1
    circle.BorderSizePixel = 0
    circle.Parent = screenGui
    local drawing = Instance.new("ImageLabel")
    drawing.Size = UDim2.new(1, 0, 1, 0)
    drawing.BackgroundTransparency = 1
    drawing.Image = "rbxasset://textures/ui/circle.png" -- circular image
    drawing.ImageColor3 = Color3.fromRGB(0, 255, 0)
    drawing.ImageTransparency = 0.6
    drawing.Parent = circle
    fovCircle = screenGui
end

-- ============================================================================
-- FEATURE: AUTO FARM (detect nearest object by name or tag)
-- ============================================================================
local function findNearestFarmTarget()
    local root = getRootPart()
    if not root then return nil end
    local localPos = root.Position
    local nearest = nil
    local minDist = math.huge
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and (obj.Name:lower():find(config.farmTargetTag:lower()) or CollectionService:HasTag(obj, config.farmTargetTag)) then
            local dist = (localPos - obj.Position).Magnitude
            if dist < minDist and dist <= config.farmRadius then
                minDist = dist
                nearest = obj
            end
        end
    end
    return nearest, minDist
end

local function startAutoFarm()
    if autoFarmConnection then autoFarmConnection:Disconnect() end
    autoFarmConnection = RunService.Heartbeat:Connect(function()
        if not config.autoFarmEnabled then return end
        local target, dist = findNearestFarmTarget()
        if target then
            -- move to target? teleport? just collect
            local clickDetector = target:FindFirstChildWhichIsA("ClickDetector")
            if clickDetector then
                pcall(function() clickDetector:FireClick() end)
            else
                local prompt = target:FindFirstChildWhichIsA("ProximityPrompt")
                if prompt then pcall(function() prompt:Prompt() end) end
            end
            showNotification("Auto Farm", "Collected "..target.Name, 0.5)
        end
    end)
end

-- ============================================================================
-- FEATURE: AUTO SKILL CHECK (detect UI QTE)
-- ============================================================================
local function startAutoSkillCheck()
    if autoSkillCheckConnection then autoSkillCheckConnection:Disconnect() end
    autoSkillCheckConnection = RunService.Heartbeat:Connect(function()
        if not config.autoSkillCheckEnabled then return end
        local playerGui = localPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            for _, frame in ipairs(playerGui:GetDescendants()) do
                if frame:IsA("Frame") and (frame.Name:lower():find("skill") or frame.Name:lower():find("qte")) then
                    -- try to find a button or check if it's a prompt
                    local button = frame:FindFirstChildWhichIsA("TextButton") or frame:FindFirstChildWhichIsA("ImageButton")
                    if button and button.Visible then
                        pcall(function() button:FireClick() end)
                    end
                end
            end
        end
    end)
end

-- ============================================================================
-- FEATURE: AUTO COLLECT (nearest item with ClickDetector/ProximityPrompt)
-- ============================================================================
local function findNearestCollectible()
    local root = getRootPart()
    if not root then return nil end
    local localPos = root.Position
    local nearest = nil
    local minDist = math.huge
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ClickDetector") then
            local parent = obj.Parent
            if parent and parent:IsA("BasePart") then
                local dist = (localPos - parent.Position).Magnitude
                if dist < minDist and dist <= config.collectRadius then
                    minDist = dist
                    nearest = {detector = obj, part = parent}
                end
            end
        elseif obj:IsA("ProximityPrompt") then
            local parent = obj.Parent
            if parent and parent:IsA("BasePart") then
                local dist = (localPos - parent.Position).Magnitude
                if dist < minDist and dist <= config.collectRadius then
                    minDist = dist
                    nearest = {prompt = obj, part = parent}
                end
            end
        end
    end
    return nearest
end

local function startAutoCollect()
    if autoCollectConnection then autoCollectConnection:Disconnect() end
    autoCollectConnection = RunService.Heartbeat:Connect(function()
        if not config.autoCollectEnabled then return end
        local target = findNearestCollectible()
        if target then
            if target.detector then
                pcall(function() target.detector:FireClick() end)
            elseif target.prompt then
                pcall(function() target.prompt:Prompt() end)
            end
            showNotification("Auto Collect", "Collected item", 0.3)
        end
    end)
end

-- ============================================================================
-- FEATURE: AUTO INTERACT (GUI buttons)
-- ============================================================================
local function startAutoInteract()
    if autoInteractConnection then autoInteractConnection:Disconnect() end
    autoInteractConnection = RunService.Heartbeat:Connect(function()
        if not config.autoInteractEnabled then return end
        local playerGui = localPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            for _, btn in ipairs(playerGui:GetDescendants()) do
                if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                    local text = btn.Text:lower()
                    if text:find("claim") or text:find("collect") or text:find("take") or text:find("open") then
                        pcall(function() btn:FireClick() end)
                        showNotification("Auto Interact", "Clicked "..btn.Text, 0.3)
                    end
                end
            end
        end
    end)
end

-- ============================================================================
-- FEATURE: COOLDOWN BYPASS (client-side simulation)
-- ============================================================================
-- In many games, cooldowns are stored in local variables. We can attempt to find NumberValues and set to 0.
-- This is client-side only and may not work server-side, but as requested "berbasis logic client".
local function startCooldownBypass()
    task.spawn(function()
        while true do
            if config.cooldownBypassEnabled then
                -- scan for NumberValue or IntValue with names like "Cooldown", "CD", "Timer"
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("NumberValue") or obj:IsA("IntValue") then
                        local name = obj.Name:lower()
                        if name:find("cooldown") or name:find("cd") or name:find("timer") then
                            pcall(function() obj.Value = 0 end)
                        end
                    end
                end
                local playerGui = localPlayer:FindFirstChild("PlayerGui")
                if playerGui then
                    for _, obj in ipairs(playerGui:GetDescendants()) do
                        if obj:IsA("NumberValue") or obj:IsA("IntValue") then
                            local name = obj.Name:lower()
                            if name:find("cooldown") or name:find("cd") or name:find("timer") then
                                pcall(function() obj.Value = 0 end)
                            end
                        end
                    end
                end
            end
            task.wait(0.5)
        end
    end)
end

-- ============================================================================
-- FEATURE: PREDICTION SYSTEM (for moving target)
-- ============================================================================
local function predictPosition(player, time)
    local char = player.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not root then return nil end
    local velocity = root.AssemblyLinearVelocity
    return root.Position + velocity * time
end

-- (optional) use in auto aim or farm

-- ============================================================================
-- CLIENT-SERVER SYNC LOGIC (valid RemoteEvent/RemoteFunction)
-- ============================================================================
-- Example: create a RemoteEvent in ReplicatedStorage if not exists, then fire to server
local function setupRemoteSync()
    local remote = ReplicatedStorage:FindFirstChild("CyberHeroes_Sync")
    if not remote then
        remote = Instance.new("RemoteEvent")
        remote.Name = "CyberHeroes_Sync"
        remote.Parent = ReplicatedStorage
    end
    -- Now we can fire to server for things like teleport or dash if needed
    -- But server may not handle. We'll just keep for potential usage.
end

-- ============================================================================
-- TWEEN ANIMATION SYSTEM (for GUI)
-- ============================================================================
local function tweenObject(obj, properties, duration, style)
    local tweenInfo = TweenInfo.new(duration, style or Enum.EasingStyle.Quad)
    local tween = TweenService:Create(obj, tweenInfo, properties)
    tween:Play()
    return tween
end

-- ============================================================================
-- DRAGGABLE GUI WITH MINIMIZE TO ICON
-- ============================================================================
local function createDraggableGUI()
    if mainGui then mainGui:Destroy() end
    mainGui = Instance.new("ScreenGui")
    mainGui.Name = "CyberHeroes_OmniGUI"
    mainGui.ResetOnSpawn = false
    mainGui.Parent = CoreGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 400)
    frame.Position = UDim2.new(0.5, -150, 0.4, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = mainGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    mainGui.Frame = frame

    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 10, 40)
    titleBar.BackgroundTransparency = 0.2
    titleBar.Parent = frame
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = titleBar

    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(1, -60, 1, 0)
    titleText.Position = UDim2.new(0, 10, 0, 0)
    titleText.Text = "CYBERHEROES OMNI v1.0"
    titleText.TextColor3 = Color3.fromRGB(0, 230, 255)
    titleText.BackgroundTransparency = 1
    titleText.Font = Enum.Font.GothamBold
    titleText.TextSize = 12
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = titleBar

    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 25, 0, 25)
    minimizeBtn.Position = UDim2.new(1, -55, 0, 2.5)
    minimizeBtn.Text = "−"
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

    -- Scrollable content
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, 0, 1, -30)
    scroll.Position = UDim2.new(0, 0, 0, 30)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.CanvasSize = UDim2.new(0, 0, 0, 600)
    scroll.Parent = frame
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll

    -- Function to create toggle buttons
    local function addToggle(text, configKey, default)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.9, 0, 0, 30)
        btn.Position = UDim2.new(0.05, 0, 0, 0)
        btn.Text = text .. " [" .. (config[configKey] and "ON" or "OFF") .. "]"
        btn.BackgroundColor3 = config[configKey] and Color3.fromRGB(0, 100, 150) or Color3.fromRGB(60, 20, 60)
        btn.BackgroundTransparency = 0.2
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.BorderSizePixel = 0
        btn.Parent = scroll
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = btn
        btn.MouseButton1Click:Connect(function()
            config[configKey] = not config[configKey]
            btn.Text = text .. " [" .. (config[configKey] and "ON" or "OFF") .. "]"
            btn.BackgroundColor3 = config[configKey] and Color3.fromRGB(0, 100, 150) or Color3.fromRGB(60, 20, 60)
            -- Trigger feature start/stop
            if configKey == "noClipEnabled" then
                setNoClip(config.noClipEnabled)
            elseif configKey == "wallClimbEnabled" then
                if config.wallClimbEnabled then startWallClimb() else if wallClimbConnection then wallClimbConnection:Disconnect(); wallClimbConnection = nil end end
            elseif configKey == "glideEnabled" then
                if config.glideEnabled then startGlide() else if glideConnection then glideConnection:Disconnect(); glideConnection = nil end end
            elseif configKey == "espEnabled" then
                if config.espEnabled then startESP(); startNameTagSystem() else
                    for _, data in pairs(espHighlights) do data.Highlight:Destroy(); if data.Tracer then data.Tracer:Destroy() end end
                    espHighlights = {}
                end
            elseif configKey == "autoFarmEnabled" then
                if config.autoFarmEnabled then startAutoFarm() else if autoFarmConnection then autoFarmConnection:Disconnect(); autoFarmConnection = nil end end
            elseif configKey == "autoSkillCheckEnabled" then
                if config.autoSkillCheckEnabled then startAutoSkillCheck() else if autoSkillCheckConnection then autoSkillCheckConnection:Disconnect(); autoSkillCheckConnection = nil end end
            elseif configKey == "autoCollectEnabled" then
                if config.autoCollectEnabled then startAutoCollect() else if autoCollectConnection then autoCollectConnection:Disconnect(); autoCollectConnection = nil end end
            elseif configKey == "autoInteractEnabled" then
                if config.autoInteractEnabled then startAutoInteract() else if autoInteractConnection then autoInteractConnection:Disconnect(); autoInteractConnection = nil end end
            elseif configKey == "fovEnabled" then
                createFOVIndicator()
            end
            showNotification("Config", text.. " " .. (config[configKey] and "ON" or "OFF"), 1)
        end)
        return btn
    end

    addToggle("⚡ Speed Boost", "walkSpeed", true) -- walkSpeed selalu on
    addToggle("🔧 NoClip", "noClipEnabled", false)
    addToggle("🧗 Wall Climb", "wallClimbEnabled", false)
    addToggle("🕊️ Glide", "glideEnabled", false)
    addToggle("👁️ ESP (Player)", "espEnabled", false)
    addToggle("🎯 Auto Farm", "autoFarmEnabled", false)
    addToggle("⚙️ Auto Skill Check", "autoSkillCheckEnabled", false)
    addToggle("📦 Auto Collect", "autoCollectEnabled", false)
    addToggle("🤝 Auto Interact", "autoInteractEnabled", false)
    addToggle("🎯 FOV Indicator", "fovEnabled", false)

    -- Slider for WalkSpeed value
    local speedSliderLabel = Instance.new("TextLabel")
    speedSliderLabel.Size = UDim2.new(0.9, 0, 0, 20)
    speedSliderLabel.Position = UDim2.new(0.05, 0, 0, 0)
    speedSliderLabel.Text = "Walk Speed: " .. config.walkSpeed
    speedSliderLabel.TextColor3 = Color3.fromRGB(200,200,200)
    speedSliderLabel.BackgroundTransparency = 1
    speedSliderLabel.Font = Enum.Font.Gotham
    speedSliderLabel.TextSize = 10
    speedSliderLabel.Parent = scroll
    local speedSlider = Instance.new("TextButton")
    speedSlider.Size = UDim2.new(0.9, 0, 0, 4)
    speedSlider.Position = UDim2.new(0.05, 0, 0, 0)
    speedSlider.BackgroundColor3 = Color3.fromRGB(80,80,100)
    speedSlider.BorderSizePixel = 0
    speedSlider.Parent = scroll
    local speedFill = Instance.new("Frame")
    speedFill.Size = UDim2.new((config.walkSpeed - 16)/100, 0, 1, 0)
    speedFill.BackgroundColor3 = Color3.fromRGB(0,200,255)
    speedFill.BorderSizePixel = 0
    speedFill.Parent = speedSlider
    local dragging = false
    speedSlider.MouseButton1Down:Connect(function()
        dragging = true
        local mouse = localPlayer:GetMouse()
        local function update(x)
            local rel = math.clamp((x - speedSlider.AbsolutePosition.X) / speedSlider.AbsoluteSize.X, 0, 1)
            local newSpeed = 16 + math.floor(rel * 200)
            config.walkSpeed = newSpeed
            speedSliderLabel.Text = "Walk Speed: " .. newSpeed
            speedFill.Size = UDim2.new(rel, 0, 1, 0)
            applySpeedBoost()
        end
        update(mouse.X)
        local conn
        conn = mouse.Move:Connect(function(_, x) if dragging then update(x) end end)
        mouse.Button1Up:Connect(function() dragging = false; conn:Disconnect() end)
    end)

    -- Minimize logic
    local isMinimized = false
    local minimizedIcon = Instance.new("ImageButton")
    minimizedIcon.Size = UDim2.new(0, 40, 0, 40)
    minimizedIcon.Position = UDim2.new(0.9, 0, 0.8, 0)
    minimizedIcon.BackgroundColor3 = Color3.fromRGB(30,30,40)
    minimizedIcon.BackgroundTransparency = 0.2
    minimizedIcon.Image = "rbxasset://textures/ui/options.png"
    minimizedIcon.ImageColor3 = Color3.fromRGB(0,230,255)
    minimizedIcon.Visible = false
    minimizedIcon.Parent = mainGui
    minimizeBtn.MouseButton1Click:Connect(function()
        isMinimized = true
        frame.Visible = false
        minimizedIcon.Visible = true
    end)
    minimizedIcon.MouseButton1Click:Connect(function()
        isMinimized = false
        frame.Visible = true
        minimizedIcon.Visible = false
    end)
    closeBtn.MouseButton1Click:Connect(function()
        mainGui:Destroy()
        if minimizedIcon then minimizedIcon:Destroy() end
    end)

    -- Dragging
    local dragStart, dragStartPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragStart = input.Position
            dragStartPos = frame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and dragStart then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(0, dragStartPos.X.Offset + delta.X, 0, dragStartPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragStart = nil
        end
    end)
end

-- ============================================================================
-- KEYBIND SYSTEM
-- ============================================================================
local function setupKeybinds()
    ContextActionService:BindAction("Teleport", function()
        teleportToMouse()
    end, false, config.keybinds.teleport)

    ContextActionService:BindAction("Dash", function()
        dash()
    end, false, config.keybinds.dash)

    ContextActionService:BindAction("ToggleNoClip", function()
        config.noClipEnabled = not config.noClipEnabled
        setNoClip(config.noClipEnabled)
        showNotification("NoClip", config.noClipEnabled and "ON" or "OFF", 1)
    end, false, config.keybinds.toggleNoClip)

    ContextActionService:BindAction("ToggleGlide", function()
        config.glideEnabled = not config.glideEnabled
        if config.glideEnabled then startGlide() else if glideConnection then glideConnection:Disconnect(); glideConnection = nil end end
        showNotification("Glide", config.glideEnabled and "ON" or "OFF", 1)
    end, false, config.keybinds.toggleGlide)

    ContextActionService:BindAction("ToggleAutoFarm", function()
        config.autoFarmEnabled = not config.autoFarmEnabled
        if config.autoFarmEnabled then startAutoFarm() else if autoFarmConnection then autoFarmConnection:Disconnect(); autoFarmConnection = nil end end
        showNotification("Auto Farm", config.autoFarmEnabled and "ON" or "OFF", 1)
    end, false, config.keybinds.toggleAutoFarm)

    ContextActionService:BindAction("ToggleMenu", function()
        if mainGui then
            if mainGui.Frame.Visible then
                mainGui.Frame.Visible = false
                if minimizedIcon then minimizedIcon.Visible = true end
            else
                mainGui.Frame.Visible = true
                if minimizedIcon then minimizedIcon.Visible = false end
            end
        end
    end, false, config.keybinds.toggleMenu)
end

-- ============================================================================
-- INITIALIZATION & CLEANUP
-- ============================================================================
local function cleanup()
    if noClipConnection then noClipConnection:Disconnect() end
    if wallClimbConnection then wallClimbConnection:Disconnect() end
    if glideConnection then glideConnection:Disconnect() end
    if autoFarmConnection then autoFarmConnection:Disconnect() end
    if autoSkillCheckConnection then autoSkillCheckConnection:Disconnect() end
    if autoCollectConnection then autoCollectConnection:Disconnect() end
    if autoInteractConnection then autoInteractConnection:Disconnect() end
    for _, data in pairs(espHighlights) do
        if data.Highlight then data.Highlight:Destroy() end
        if data.Tracer then data.Tracer:Destroy() end
        if data.Connection then data.Connection:Disconnect() end
    end
    for _, data in pairs(nameBillboards) do
        if data.Billboard then data.Billboard:Destroy() end
        if data.Connection then data.Connection:Disconnect() end
    end
    if mainGui then mainGui:Destroy() end
end

local function init()
    applySpeedBoost()
    startSpeedBoostMonitor()
    setupRemoteSync()
    setupKeybinds()
    createDraggableGUI()
    -- Start features that are ON by default
    if config.noClipEnabled then setNoClip(true) end
    if config.wallClimbEnabled then startWallClimb() end
    if config.glideEnabled then startGlide() end
    if config.espEnabled then startESP(); startNameTagSystem() end
    if config.autoFarmEnabled then startAutoFarm() end
    if config.autoSkillCheckEnabled then startAutoSkillCheck() end
    if config.autoCollectEnabled then startAutoCollect() end
    if config.autoInteractEnabled then startAutoInteract() end
    if config.fovEnabled then createFOVIndicator() end
    startCooldownBypass() -- always running cooldown bypass (set config.cooldownBypassEnabled to true)
    print("╔════════════════════════════════════════════════════════════╗")
    print("║     CYBERHEROES ULTIMATE OMNI EXECUTOR v1.0 LOADED        ║")
    print("║  Features: Speed, Jump, Teleport, Dash, NoClip, WallClimb ║")
    print("║  Glide, ESP, NameTag+Distance, FOV, Auto Farm, SkillCheck ║")
    print("║  AutoCollect, AutoInteract, CooldownBypass, Prediction,    ║")
    print("║  Client-Server Sync, Tween UI, Draggable GUI, Keybinds    ║")
    print("╚════════════════════════════════════════════════════════════╝")
end

init()
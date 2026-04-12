--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                    CYBERHEROES DELTA EXECUTOR v3.0               ║
    ║              Auto Win + Auto Task + ESP + Speed Boost            ║
    ║              Survivor vs Killer - Generator Fixer                ║
    ║                   Developed by Deepseek-CH                       ║
    ║                     For Delta Executor                           ║
    ╚═══════════════════════════════════════════════════════════════════╝
    
    Fitur:
    ✅ Auto Win - Instant generator completion via value manipulation
    ✅ Auto Task - Smart pathfinding to nearest generator
    ✅ ESP - Player tracking with Highlight + BillboardGui
    ✅ Speed Boost - Temporary speed increase when damaged
    ✅ Modern GUI - Dark purple theme with neon glow & animations
    
    Cara Penggunaan:
    - Execute script di Delta Executor
    - Gunakan toggle button di GUI untuk mengaktifkan/menonaktifkan fitur
    - Tekan 'F' untuk toggle GUI (show/hide)
--]]

-- ============================================================================
-- SERVICES
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local localPlayer = Players.LocalPlayer
local localCharacter = nil
local localHumanoid = nil
local localRootPart = nil

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local config = {
    -- Auto Win Settings
    autoWinEnabled = true,
    maxProgress = 100,              -- Nilai maksimum progress generator
    
    -- Auto Task Settings (Pathfinding)
    autoTaskEnabled = false,
    taskRadius = 50,                -- Jarak maksimum untuk mencari generator
    pathfindingParams = {
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentMaxSlope = 45
    },
    
    -- ESP Settings
    espEnabled = true,
    highlightColorKiller = Color3.fromRGB(255, 50, 50),    -- Merah untuk killer
    highlightColorSurvivor = Color3.fromRGB(50, 255, 50),  -- Hijau untuk survivor
    highlightTransparency = 0.5,
    
    -- Speed Boost Settings
    speedBoostEnabled = true,
    boostAmount = 15,               -- Tambahan walkspeed saat terkena damage
    boostDuration = 3,              -- Durasi boost dalam detik
    originalWalkSpeed = 16,
    
    -- GUI Settings
    guiVisible = true,
    guiToggleKey = Enum.KeyCode.F
}

-- ============================================================================
-- STATE VARIABLES
-- ============================================================================
local isSpeedBoostActive = false
local boostDebounce = false
local currentBoostConnection = nil
local currentTaskConnection = nil
local currentEspConnections = {}
local generatorCache = {}
local espHighlights = {}
local lastFullScan = 0

-- GUI References
local screenGui = nil
local mainFrame = nil
local toggleButtons = {}

-- ============================================================================
-- UTILITY FUNCTIONS
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

-- ============================================================================
-- CORE FEATURE 1: AUTO WIN (INSTANT COMPLETION)
-- ============================================================================

-- Scan semua generator di workspace
local function scanGenerators()
    local generators = {}
    local generatorFolder = Workspace:FindFirstChild("Generators")
    
    if generatorFolder then
        -- Jika generator berada di folder khusus
        for _, child in ipairs(generatorFolder:GetChildren()) do
            -- Cek apakah ini generator (memiliki Progress dan Completed)
            local progress = child:FindFirstChild("Progress")
            local completed = child:FindFirstChild("Completed")
            if progress and completed then
                table.insert(generators, {
                    instance = child,
                    progress = progress,
                    completed = completed
                })
            end
        end
    else
        -- Fallback: scan seluruh workspace
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") or obj:IsA("BasePart") then
                local progress = obj:FindFirstChild("Progress")
                local completed = obj:FindFirstChild("Completed")
                if progress and completed then
                    table.insert(generators, {
                        instance = obj,
                        progress = progress,
                        completed = completed
                    })
                end
            end
        end
    end
    
    return generators
end

-- Complete single generator via value manipulation
local function completeGenerator(generator)
    if not generator or not generator.progress or not generator.completed then
        return false
    end
    
    -- Manipulasi nilai progress ke maksimum
    pcall(function()
        if generator.progress:IsA("NumberValue") or generator.progress:IsA("IntValue") then
            generator.progress.Value = config.maxProgress
        end
    end)
    
    -- Set completed ke true
    pcall(function()
        if generator.completed:IsA("BoolValue") then
            generator.completed.Value = true
        end
    end)
    
    return true
end

-- Complete all generators
local function completeAllGenerators()
    local generators = scanGenerators()
    local completedCount = 0
    
    for _, gen in ipairs(generators) do
        if completeGenerator(gen) then
            completedCount = completedCount + 1
        end
    end
    
    if completedCount > 0 then
        print("[AutoWin] Completed " .. completedCount .. " generator(s)")
    end
    
    return completedCount
end

-- Auto win loop (monitoring + instant completion)
local autoWinConnection = nil
local function startAutoWin()
    if autoWinConnection then return end
    
    autoWinConnection = RunService.Heartbeat:Connect(function()
        if not config.autoWinEnabled then return end
        if not getLocalCharacter() then return end
        
        -- Scan dan complete semua generator
        completeAllGenerators()
        
        -- Throttle: jangan terlalu sering (cukup setiap 0.5 detik)
        task.wait(0.5)
    end)
end

local function stopAutoWin()
    if autoWinConnection then
        autoWinConnection:Disconnect()
        autoWinConnection = nil
    end
end

-- ============================================================================
-- CORE FEATURE 2: AUTO TASK (PATHFINDING)
-- ============================================================================

-- Cari generator terdekat yang belum completed
local function getNearestGenerator()
    local generators = scanGenerators()
    local nearest = nil
    local minDistance = math.huge
    
    if not localRootPart then return nil end
    local localPos = localRootPart.Position
    
    for _, gen in ipairs(generators) do
        -- Cek apakah generator sudah completed
        local isCompleted = false
        if gen.completed and gen.completed:IsA("BoolValue") then
            isCompleted = gen.completed.Value
        end
        
        if not isCompleted then
            local genPos = gen.instance:GetPivot().Position
            local distance = (localPos - genPos).Magnitude
            
            if distance < minDistance and distance <= config.taskRadius then
                minDistance = distance
                nearest = gen
            end
        end
    end
    
    return nearest
end

-- Move to target using pathfinding
local function moveWithPathfinding(targetPart, waypointCallback)
    if not localHumanoid or not localRootPart then return false end
    
    local path = PathfindingService:CreatePath(config.pathfindingParams)
    local success, errorMsg = pcall(function()
        path:ComputeAsync(localRootPart.Position, targetPart.Position)
    end)
    
    if not success or path.Status == Enum.PathStatus.NoPath then
        print("[AutoTask] No path found, trying direct movement")
        -- Fallback: direct movement
        localHumanoid:MoveTo(targetPart.Position)
        return true
    end
    
    local waypoints = path:GetWaypoints()
    
    for i, waypoint in ipairs(waypoints) do
        if not localHumanoid or not localHumanoid.Parent then
            return false
        end
        
        localHumanoid:MoveTo(waypoint.Position)
        localHumanoid.MoveToFinished:Wait()
        
        if waypointCallback then
            waypointCallback(waypoint, i)
        end
        
        -- Recompute path periodically to avoid getting stuck
        if i % 5 == 0 then
            pcall(function()
                path:ComputeAsync(localRootPart.Position, targetPart.Position)
                waypoints = path:GetWaypoints()
            end)
        end
    end
    
    return true
end

-- Main auto task loop
local function startAutoTask()
    if currentTaskConnection then return end
    
    currentTaskConnection = RunService.Heartbeat:Connect(function()
        if not config.autoTaskEnabled then return end
        if not getLocalCharacter() or not localHumanoid or not localRootPart then return end
        
        local nearestGen = getNearestGenerator()
        if not nearestGen then
            -- Tidak ada generator yang belum completed, idle
            task.wait(1)
            return
        end
        
        local targetPart = nearestGen.instance:FindFirstChildWhichIsA("BasePart") or nearestGen.instance
        if not targetPart then return end
        
        -- Pindah ke generator
        print("[AutoTask] Moving to generator: " .. nearestGen.instance.Name)
        moveWithPathfinding(targetPart)
        
        -- Setelah sampai, complete generator
        completeGenerator(nearestGen)
        print("[AutoTask] Completed generator: " .. nearestGen.instance.Name)
        
        -- Delay sebelum cari generator berikutnya
        task.wait(0.5)
    end)
end

local function stopAutoTask()
    if currentTaskConnection then
        currentTaskConnection:Disconnect()
        currentTaskConnection = nil
    end
    if localHumanoid then
        localHumanoid:MoveTo(Vector3.zero)
    end
end

-- ============================================================================
-- CORE FEATURE 3: ESP SYSTEM
-- ============================================================================

-- Create Highlight for a player
local function createHighlightForPlayer(player)
    if espHighlights[player.UserId] then
        -- Remove existing highlight
        if espHighlights[player.UserId].Highlight then
            espHighlights[player.UserId].Highlight:Destroy()
        end
        if espHighlights[player.UserId].Billboard then
            espHighlights[player.UserId].Billboard:Destroy()
        end
        espHighlights[player.UserId] = nil
    end
    
    local character = player.Character
    if not character then return end
    
    -- Determine team color
    local isKiller = false
    if player.Team then
        isKiller = (player.Team.Name:lower():find("killer") or 
                   player.Team.Name:lower():find("monster") or
                   player.Team.Name:lower():find("enemy"))
    end
    
    local highlightColor = isKiller and config.highlightColorKiller or config.highlightColorSurvivor
    
    -- Create Highlight instance
    local highlight = Instance.new("Highlight")
    highlight.Name = "CyberHeroes_ESP"
    highlight.FillColor = highlightColor
    highlight.FillTransparency = config.highlightTransparency
    highlight.OutlineColor = highlightColor
    highlight.OutlineTransparency = 0.2
    highlight.Adornee = character
    highlight.Parent = character
    
    -- Create BillboardGui for name and distance
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "CyberHeroes_NameTag"
    billboard.Adornee = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    billboard.Size = UDim2.new(0, 120, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.Parent = character
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = highlightColor
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Parent = billboard
    
    -- Store references
    espHighlights[player.UserId] = {
        Highlight = highlight,
        Billboard = billboard,
        NameLabel = nameLabel
    }
end

-- Update all ESPs (when characters change or players join/leave)
local function updateAllESP()
    if not config.espEnabled then
        -- Clear all ESPs
        for _, data in pairs(espHighlights) do
            if data.Highlight then data.Highlight:Destroy() end
            if data.Billboard then data.Billboard:Destroy() end
        end
        espHighlights = {}
        return
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            createHighlightForPlayer(player)
        end
    end
end

-- Monitor player list changes
local function startESP()
    -- Handle player added
    Players.PlayerAdded:Connect(function(player)
        if config.espEnabled then
            task.wait(0.5) -- Tunggu character spawn
            createHighlightForPlayer(player)
        end
    end)
    
    -- Handle player removed
    Players.PlayerRemoving:Connect(function(player)
        if espHighlights[player.UserId] then
            if espHighlights[player.UserId].Highlight then
                espHighlights[player.UserId].Highlight:Destroy()
            end
            if espHighlights[player.UserId].Billboard then
                espHighlights[player.UserId].Billboard:Destroy()
            end
            espHighlights[player.UserId] = nil
        end
    end)
    
    -- Handle character added for existing players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            player.CharacterAdded:Connect(function()
                if config.espEnabled then
                    createHighlightForPlayer(player)
                end
            end)
        end
    end
    
    -- Initial update
    updateAllESP()
    
    -- Periodic update untuk memastikan ESP tetap attached
    RunService.Heartbeat:Connect(function()
        if config.espEnabled then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= localPlayer then
                    if not espHighlights[player.UserId] or 
                       (espHighlights[player.UserId].Highlight and 
                        espHighlights[player.UserId].Highlight.Adornee ~= player.Character) then
                        createHighlightForPlayer(player)
                    end
                end
            end
        end
    end)
end

-- ============================================================================
-- CORE FEATURE 4: SPEED BOOST ON DAMAGE
-- ============================================================================

local function applySpeedBoost()
    if not config.speedBoostEnabled then return end
    if not localHumanoid then return end
    if boostDebounce then return end
    
    boostDebounce = true
    
    -- Save original walkspeed if not already saved
    if config.originalWalkSpeed == 16 then
        config.originalWalkSpeed = localHumanoid.WalkSpeed
    end
    
    -- Apply boost
    localHumanoid.WalkSpeed = config.originalWalkSpeed + config.boostAmount
    isSpeedBoostActive = true
    
    -- Reset after duration
    task.wait(config.boostDuration)
    
    if localHumanoid then
        localHumanoid.WalkSpeed = config.originalWalkSpeed
    end
    isSpeedBoostActive = false
    
    boostDebounce = false
end

local function startSpeedBoostMonitor()
    if currentBoostConnection then return end
    
    currentBoostConnection = RunService.Heartbeat:Connect(function()
        if not config.speedBoostEnabled then return end
        if not getLocalCharacter() or not localHumanoid then return end
        
        -- Monitor health changes via .Changed event
        if not localHumanoid.HealthChanged then
            -- Alternative: store previous health and compare
            local lastHealth = localHumanoid.Health
            local connection = localHumanoid:GetPropertyChangedSignal("Health"):Connect(function()
                if localHumanoid.Health < lastHealth then
                    -- Health decreased = damaged
                    applySpeedBoost()
                end
                lastHealth = localHumanoid.Health
            end)
            -- Store connection to clean up later
            if not localHumanoid._healthMonitor then
                localHumanoid._healthMonitor = connection
            end
        end
    end)
end

local function stopSpeedBoostMonitor()
    if currentBoostConnection then
        currentBoostConnection:Disconnect()
        currentBoostConnection = nil
    end
    if localHumanoid then
        localHumanoid.WalkSpeed = config.originalWalkSpeed
    end
end

-- ============================================================================
-- CORE FEATURE 5: MODERN GUI
-- ============================================================================

-- Create rounded button helper
local function createRoundedButton(parent, name, position, size, text, callback)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = size
    button.Position = position
    button.Text = text
    button.BackgroundColor3 = Color3.fromRGB(45, 35, 65)
    button.BackgroundTransparency = 0.2
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 14
    button.Font = Enum.Font.GothamBold
    button.BorderSizePixel = 0
    button.Parent = parent
    
    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button
    
    -- Neon glow effect (UIStroke)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(120, 80, 200)
    stroke.Thickness = 2
    stroke.Transparency = 0.5
    stroke.Parent = button
    
    -- Gradient background
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 45, 75)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 25, 55))
    })
    gradient.Parent = button
    
    -- Hover animation
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {
            BackgroundTransparency = 0.05
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), {
            Transparency = 0.2
        }):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {
            BackgroundTransparency = 0.2
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), {
            Transparency = 0.5
        }):Play()
    end)
    
    if callback then
        button.MouseButton1Click:Connect(callback)
    end
    
    return button
end

-- Create toggle button
local function createToggleButton(parent, name, position, text, initialState, onChange)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(0.8, 0, 0, 35)
    button.Position = position
    button.Text = text .. (initialState and " [ON]" or " [OFF]")
    button.BackgroundColor3 = initialState and Color3.fromRGB(80, 60, 120) or Color3.fromRGB(45, 35, 65)
    button.BackgroundTransparency = 0.15
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 14
    button.Font = Enum.Font.GothamBold
    button.BorderSizePixel = 0
    button.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    
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
        local newState = not (config[name] or false)
        if name == "autoWinEnabled" then
            config.autoWinEnabled = newState
            if newState then startAutoWin() else stopAutoWin() end
        elseif name == "autoTaskEnabled" then
            config.autoTaskEnabled = newState
            if newState then startAutoTask() else stopAutoTask() end
        elseif name == "espEnabled" then
            config.espEnabled = newState
            updateAllESP()
        elseif name == "speedBoostEnabled" then
            config.speedBoostEnabled = newState
            if not newState then
                if localHumanoid then
                    localHumanoid.WalkSpeed = config.originalWalkSpeed
                end
            end
        end
        updateState(newState)
        if onChange then onChange(newState) end
    end)
    
    return button
end

-- Create main GUI
local function createGUI()
    -- Clean up existing GUI
    if screenGui then screenGui:Destroy() end
    
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_GUI"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = localPlayer:FindFirstChild("PlayerGui") or localPlayer.PlayerGui
    
    -- Main panel
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainPanel"
    mainFrame.Size = UDim2.new(0, 280, 0, 350)
    mainFrame.Position = UDim2.new(0.85, -290, 0.5, -175)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    -- Rounded corners
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = mainFrame
    
    -- Shadow effect (UIStroke)
    local shadowStroke = Instance.new("UIStroke")
    shadowStroke.Color = Color3.fromRGB(100, 70, 180)
    shadowStroke.Thickness = 2
    shadowStroke.Transparency = 0.6
    shadowStroke.Parent = mainFrame
    
    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(35, 25, 55)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    -- Title text
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 1, 0)
    title.Text = "⚡ CYBERHEROES v3.0 ⚡"
    title.TextColor3 = Color3.fromRGB(180, 130, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.Parent = titleBar
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 18
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function()
        config.guiVisible = not config.guiVisible
        mainFrame.Visible = config.guiVisible
    end)
    
    -- Content frame
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -20, 1, -55)
    content.Position = UDim2.new(0, 10, 0, 50)
    content.BackgroundTransparency = 1
    content.Parent = mainFrame
    
    -- Toggle buttons
    local toggleY = 0
    local toggleSpacing = 45
    
    local autoWinBtn = createToggleButton(content, "autoWinEnabled", UDim2.new(0.1, 0, 0, toggleY), "🤖 AUTO WIN", config.autoWinEnabled)
    toggleY = toggleY + toggleSpacing
    
    local autoTaskBtn = createToggleButton(content, "autoTaskEnabled", UDim2.new(0.1, 0, 0, toggleY), "🎯 AUTO TASK", config.autoTaskEnabled)
    toggleY = toggleY + toggleSpacing
    
    local espBtn = createToggleButton(content, "espEnabled", UDim2.new(0.1, 0, 0, toggleY), "👁️ ESP", config.espEnabled)
    toggleY = toggleY + toggleSpacing
    
    local speedBoostBtn = createToggleButton(content, "speedBoostEnabled", UDim2.new(0.1, 0, 0, toggleY), "⚡ SPEED BOOST", config.speedBoostEnabled)
    toggleY = toggleY + toggleSpacing
    
    -- Status label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0.9, 0, 0, 30)
    statusLabel.Position = UDim2.new(0.05, 0, 0, toggleY + 10)
    statusLabel.Text = "Status: Ready"
    statusLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 12
    statusLabel.Parent = content
    
    -- Update status periodically
    task.spawn(function()
        while screenGui and screenGui.Parent do
            if config.autoWinEnabled or config.autoTaskEnabled or config.espEnabled or config.speedBoostEnabled then
                local activeCount = (config.autoWinEnabled and 1 or 0) + 
                                    (config.autoTaskEnabled and 1 or 0) + 
                                    (config.espEnabled and 1 or 0) + 
                                    (config.speedBoostEnabled and 1 or 0)
                statusLabel.Text = "Status: " .. activeCount .. " feature(s) active"
                statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            else
                statusLabel.Text = "Status: Idle - Enable features above"
                statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            end
            task.wait(1)
        end
    end)
    
    -- Animasi fade in
    mainFrame.BackgroundTransparency = 0.3
    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        BackgroundTransparency = 0.1
    }):Play()
end

-- Toggle GUI visibility with keybind
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
-- CHARACTER HANDLER & INITIALIZATION
-- ============================================================================

local function onCharacterAdded(character)
    localCharacter = character
    localHumanoid = character:FindFirstChildWhichIsA("Humanoid")
    localRootPart = character:FindFirstChild("HumanoidRootPart") or 
                    character:FindFirstChild("Torso") or 
                    character:FindFirstChild("UpperTorso")
    
    if localHumanoid then
        config.originalWalkSpeed = localHumanoid.WalkSpeed
    end
    
    print("[CyberHeroes] Character loaded")
end

-- Start all enabled systems
local function startAllSystems()
    if config.autoWinEnabled then startAutoWin() end
    if config.autoTaskEnabled then startAutoTask() end
    if config.speedBoostEnabled then startSpeedBoostMonitor() end
    startESP()
end

-- Initialize
local function init()
    print("╔═══════════════════════════════════════════════════════════════════╗")
    print("║                    CYBERHEROES DELTA EXECUTOR v3.0               ║")
    print("║              Auto Win + Auto Task + ESP + Speed Boost            ║")
    print("║                   System initialized!                            ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")
    
    if localPlayer.Character then
        onCharacterAdded(localPlayer.Character)
    end
    
    localPlayer.CharacterAdded:Connect(onCharacterAdded)
    
    createGUI()
    startAllSystems()
end

-- Start the script
task.wait(1)
init()
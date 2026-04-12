--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                    CYBERHEROES DELTA EXECUTOR v3.2               ║
    ║              Auto Win + Auto Task + ESP + Speed Boost            ║
    ║              Survivor vs Killer - Generator Fixer                ║
    ║                   Developed by Deepseek-CH                       ║
    ║                     For Delta Executor                           ║
    ║              OPTIMIZED: No more lag, event-driven auto win       ║
    ╚═══════════════════════════════════════════════════════════════════╝
    
    Fitur:
    ✅ Auto Win - Instant generator completion via event-driven detection
    ✅ Auto Task - Smart pathfinding with optimized scanning
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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local localCharacter = nil
local localHumanoid = nil
local localRootPart = nil

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local config = {
    autoWinEnabled = true,
    maxProgress = 100,
    autoTaskEnabled = false,
    taskRadius = 50,
    taskInterval = 1.5,          -- Interval auto task (detik), lebih lambat agar tidak lag
    pathfindingParams = {
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentMaxSlope = 45
    },
    espEnabled = true,
    highlightColorKiller = Color3.fromRGB(255, 50, 50),
    highlightColorSurvivor = Color3.fromRGB(50, 255, 50),
    highlightTransparency = 0.5,
    speedBoostEnabled = true,
    boostAmount = 15,
    boostDuration = 3,
    originalWalkSpeed = 16,
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
local currentTaskThread = nil
local espHighlights = {}
local screenGui = nil
local mainFrame = nil

-- Cache untuk generator yang sudah diproses (agar tidak double-complete)
local processedGenerators = {}

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
-- CORE FEATURE 1: AUTO WIN (EVENT-DRIVEN - NO LAG)
-- ============================================================================

-- Complete a generator using multiple methods (without heavy scanning)
local function completeGeneratorInstance(genInstance)
    if not genInstance or processedGenerators[genInstance] then return false end
    
    local completed = false
    
    -- Method 1: RemoteEvent
    local remote = genInstance:FindFirstChildWhichIsA("RemoteEvent") or 
                   genInstance:FindFirstChild("Complete") or 
                   genInstance:FindFirstChild("Finish")
    if remote and remote:IsA("RemoteEvent") then
        pcall(function() remote:FireServer() end)
        completed = true
    end
    
    -- Method 2: ClickDetector
    local click = genInstance:FindFirstChildWhichIsA("ClickDetector")
    if click and click.Enabled then
        pcall(function() click:FireClick() end)
        completed = true
    end
    
    -- Method 3: ProximityPrompt
    local prompt = genInstance:FindFirstChildWhichIsA("ProximityPrompt")
    if prompt and prompt.Enabled then
        pcall(function()
            prompt:Hold()
            task.wait(0.1)
            prompt:Release()
        end)
        completed = true
    end
    
    -- Method 4: Value manipulation (fallback)
    local progress = genInstance:FindFirstChild("Progress")
    local completedVal = genInstance:FindFirstChild("Completed")
    if progress and (progress:IsA("NumberValue") or progress:IsA("IntValue")) then
        pcall(function() progress.Value = config.maxProgress end)
        completed = true
    end
    if completedVal and completedVal:IsA("BoolValue") then
        pcall(function() completedVal.Value = true end)
        completed = true
    end
    
    if completed then
        processedGenerators[genInstance] = true
        print("[AutoWin] Completed generator: " .. tostring(genInstance.Name))
    end
    return completed
end

-- Scan for generators once at start, then listen for new ones
local function scanAndCompleteExistingGenerators()
    local containers = {Workspace, ReplicatedStorage}
    for _, container in ipairs(containers) do
        for _, obj in ipairs(container:GetDescendants()) do
            local name = obj.Name:lower()
            local isGenerator = name:find("generator") or name:find("gen") or name:find("repair") or name:find("fix")
            if not isGenerator then
                isGenerator = obj:FindFirstChild("Progress") or obj:FindFirstChild("Completed") or
                             obj:FindFirstChildWhichIsA("ClickDetector") or obj:FindFirstChildWhichIsA("ProximityPrompt")
            end
            if isGenerator and not processedGenerators[obj] then
                completeGeneratorInstance(obj)
            end
        end
    end
end

-- Event handler for new objects added to Workspace/ReplicatedStorage
local function onDescendantAdded(instance)
    if not config.autoWinEnabled then return end
    if not instance then return end
    
    local name = instance.Name:lower()
    local isGenerator = name:find("generator") or name:find("gen") or name:find("repair") or name:find("fix")
    if not isGenerator then
        isGenerator = instance:FindFirstChild("Progress") or instance:FindFirstChild("Completed") or
                     instance:FindFirstChildWhichIsA("ClickDetector") or instance:FindFirstChildWhichIsA("ProximityPrompt")
    end
    if isGenerator and not processedGenerators[instance] then
        completeGeneratorInstance(instance)
    end
end

-- Start Auto Win (event-driven)
local autoWinDescendantConnections = {}
local function startAutoWin()
    if #autoWinDescendantConnections > 0 then return end
    
    -- Scan existing generators once
    scanAndCompleteExistingGenerators()
    
    -- Listen for new generators
    local conn1 = Workspace.DescendantAdded:Connect(onDescendantAdded)
    local conn2 = ReplicatedStorage.DescendantAdded:Connect(onDescendantAdded)
    table.insert(autoWinDescendantConnections, conn1)
    table.insert(autoWinDescendantConnections, conn2)
    print("[AutoWin] Started (event-driven)")
end

local function stopAutoWin()
    for _, conn in ipairs(autoWinDescendantConnections) do
        conn:Disconnect()
    end
    autoWinDescendantConnections = {}
    print("[AutoWin] Stopped")
end

-- ============================================================================
-- CORE FEATURE 2: AUTO TASK (OPTIMIZED)
-- ============================================================================

-- Find nearest uncompleted generator (cached, but we need to check completion status)
local function getNearestGeneratorOptimized()
    if not localRootPart then return nil end
    local localPos = localRootPart.Position
    local nearest = nil
    local minDist = math.huge
    
    -- Only scan Workspace (generators are usually there)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local name = obj.Name:lower()
        local isGenerator = name:find("generator") or name:find("gen") or name:find("repair") or name:find("fix")
        if not isGenerator then
            isGenerator = obj:FindFirstChild("Progress") or obj:FindFirstChild("Completed") or
                         obj:FindFirstChildWhichIsA("ClickDetector") or obj:FindFirstChildWhichIsA("ProximityPrompt")
        end
        
        if isGenerator then
            -- Check if already completed
            local completed = false
            local progress = obj:FindFirstChild("Progress")
            if progress and (progress:IsA("NumberValue") or progress:IsA("IntValue")) then
                completed = progress.Value >= config.maxProgress
            end
            local completedBool = obj:FindFirstChild("Completed")
            if completedBool and completedBool:IsA("BoolValue") then
                completed = completed or completedBool.Value
            end
            
            if not completed then
                local pos = obj:GetPivot().Position
                local dist = (localPos - pos).Magnitude
                if dist < minDist and dist <= config.taskRadius then
                    minDist = dist
                    nearest = obj
                end
            end
        end
    end
    return nearest
end

-- Move to target using pathfinding
local function moveWithPathfinding(targetPart, waypointCallback)
    if not localHumanoid or not localRootPart then return false end
    local path = PathfindingService:CreatePath(config.pathfindingParams)
    local success = pcall(function()
        path:ComputeAsync(localRootPart.Position, targetPart.Position)
    end)
    if not success or path.Status == Enum.PathStatus.NoPath then
        localHumanoid:MoveTo(targetPart.Position)
        return true
    end
    local waypoints = path:GetWaypoints()
    for i, waypoint in ipairs(waypoints) do
        if not localHumanoid or not localHumanoid.Parent then return false end
        localHumanoid:MoveTo(waypoint.Position)
        localHumanoid.MoveToFinished:Wait()
        if waypointCallback then waypointCallback(waypoint, i) end
        if i % 5 == 0 then
            pcall(function()
                path:ComputeAsync(localRootPart.Position, targetPart.Position)
                waypoints = path:GetWaypoints()
            end)
        end
    end
    return true
end

-- Auto task loop (using task.wait, not Heartbeat, to avoid lag)
local taskRunning = false
local function autoTaskLoop()
    while taskRunning and config.autoTaskEnabled do
        if getLocalCharacter() and localHumanoid and localRootPart then
            local nearestGen = getNearestGeneratorOptimized()
            if nearestGen then
                local targetPart = nearestGen:FindFirstChildWhichIsA("BasePart") or nearestGen
                if targetPart then
                    print("[AutoTask] Moving to: " .. nearestGen.Name)
                    moveWithPathfinding(targetPart)
                    completeGeneratorInstance(nearestGen)
                    print("[AutoTask] Completed: " .. nearestGen.Name)
                end
            else
                -- No generator found, wait longer
                task.wait(config.taskInterval)
            end
        end
        task.wait(config.taskInterval)
    end
end

local function startAutoTask()
    if taskRunning then return end
    taskRunning = true
    currentTaskThread = task.spawn(autoTaskLoop)
    print("[AutoTask] Started")
end

local function stopAutoTask()
    taskRunning = false
    if currentTaskThread then
        coroutine.close(currentTaskThread)
        currentTaskThread = nil
    end
    if localHumanoid then
        localHumanoid:MoveTo(Vector3.zero)
    end
    print("[AutoTask] Stopped")
end

-- ============================================================================
-- CORE FEATURE 3: ESP (SAME AS ORIGINAL - WORKS FINE)
-- ============================================================================
local function createHighlightForPlayer(player)
    if espHighlights[player.UserId] then
        if espHighlights[player.UserId].Highlight then espHighlights[player.UserId].Highlight:Destroy() end
        if espHighlights[player.UserId].Billboard then espHighlights[player.UserId].Billboard:Destroy() end
        espHighlights[player.UserId] = nil
    end
    
    local character = player.Character
    if not character then return end
    
    local isKiller = false
    if player.Team then
        isKiller = (player.Team.Name:lower():find("killer") or 
                   player.Team.Name:lower():find("monster") or
                   player.Team.Name:lower():find("enemy"))
    end
    local highlightColor = isKiller and config.highlightColorKiller or config.highlightColorSurvivor
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "CyberHeroes_ESP"
    highlight.FillColor = highlightColor
    highlight.FillTransparency = config.highlightTransparency
    highlight.OutlineColor = highlightColor
    highlight.OutlineTransparency = 0.2
    highlight.Adornee = character
    highlight.Parent = character
    
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
    
    espHighlights[player.UserId] = { Highlight = highlight, Billboard = billboard, NameLabel = nameLabel }
end

local function updateAllESP()
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
            createHighlightForPlayer(player)
        end
    end
end

local function startESP()
    Players.PlayerAdded:Connect(function(player)
        if config.espEnabled then
            task.wait(0.5)
            createHighlightForPlayer(player)
        end
    end)
    Players.PlayerRemoving:Connect(function(player)
        if espHighlights[player.UserId] then
            if espHighlights[player.UserId].Highlight then espHighlights[player.UserId].Highlight:Destroy() end
            if espHighlights[player.UserId].Billboard then espHighlights[player.UserId].Billboard:Destroy() end
            espHighlights[player.UserId] = nil
        end
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            player.CharacterAdded:Connect(function()
                if config.espEnabled then createHighlightForPlayer(player) end
            end)
        end
    end
    updateAllESP()
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
-- CORE FEATURE 4: SPEED BOOST ON DAMAGE (SAME AS ORIGINAL)
-- ============================================================================
local function applySpeedBoost()
    if not config.speedBoostEnabled or not localHumanoid or boostDebounce then return end
    boostDebounce = true
    if config.originalWalkSpeed == 16 then config.originalWalkSpeed = localHumanoid.WalkSpeed end
    localHumanoid.WalkSpeed = config.originalWalkSpeed + config.boostAmount
    isSpeedBoostActive = true
    task.wait(config.boostDuration)
    if localHumanoid then localHumanoid.WalkSpeed = config.originalWalkSpeed end
    isSpeedBoostActive = false
    boostDebounce = false
end

local function startSpeedBoostMonitor()
    if currentBoostConnection then return end
    currentBoostConnection = RunService.Heartbeat:Connect(function()
        if not config.speedBoostEnabled or not getLocalCharacter() or not localHumanoid then return end
        if not localHumanoid.HealthChanged then
            local lastHealth = localHumanoid.Health
            local connection = localHumanoid:GetPropertyChangedSignal("Health"):Connect(function()
                if localHumanoid.Health < lastHealth then applySpeedBoost() end
                lastHealth = localHumanoid.Health
            end)
            if not localHumanoid._healthMonitor then localHumanoid._healthMonitor = connection end
        end
    end)
end

local function stopSpeedBoostMonitor()
    if currentBoostConnection then currentBoostConnection:Disconnect(); currentBoostConnection = nil end
    if localHumanoid then localHumanoid.WalkSpeed = config.originalWalkSpeed end
end

-- ============================================================================
-- CORE FEATURE 5: MODERN GUI (SAME AS ORIGINAL - SHORTENED FOR BREVITY)
-- ============================================================================
local function createToggleButton(parent, name, position, text, initialState, onChange)
    local button = Instance.new("TextButton")
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
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 6); corner.Parent = button
    local stroke = Instance.new("UIStroke"); stroke.Color = initialState and Color3.fromRGB(150,100,255) or Color3.fromRGB(80,60,120); stroke.Thickness = 1.5; stroke.Transparency = 0.4; stroke.Parent = button
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
            if not newState and localHumanoid then localHumanoid.WalkSpeed = config.originalWalkSpeed end
        end
        updateState(newState)
        if onChange then onChange(newState) end
    end)
    return button
end

local function createGUI()
    if screenGui then screenGui:Destroy() end
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_GUI"
    screenGui.Parent = localPlayer:FindFirstChild("PlayerGui") or localPlayer.PlayerGui
    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 280, 0, 350)
    mainFrame.Position = UDim2.new(0.85, -290, 0.5, -175)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    local mainCorner = Instance.new("UICorner"); mainCorner.CornerRadius = UDim.new(0, 12); mainCorner.Parent = mainFrame
    local shadowStroke = Instance.new("UIStroke"); shadowStroke.Color = Color3.fromRGB(100,70,180); shadowStroke.Thickness = 2; shadowStroke.Transparency = 0.6; shadowStroke.Parent = mainFrame
    local titleBar = Instance.new("Frame"); titleBar.Size = UDim2.new(1, 0, 0, 40); titleBar.BackgroundColor3 = Color3.fromRGB(35,25,55); titleBar.BackgroundTransparency = 0.2; titleBar.BorderSizePixel = 0; titleBar.Parent = mainFrame
    local titleCorner = Instance.new("UICorner"); titleCorner.CornerRadius = UDim.new(0, 12); titleCorner.Parent = titleBar
    local title = Instance.new("TextLabel"); title.Size = UDim2.new(1, 0, 1, 0); title.Text = "⚡ CYBERHEROES v3.2 ⚡"; title.TextColor3 = Color3.fromRGB(180,130,255); title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBold; title.TextSize = 16; title.Parent = titleBar
    local closeBtn = Instance.new("TextButton"); closeBtn.Size = UDim2.new(0, 30, 0, 30); closeBtn.Position = UDim2.new(1, -35, 0, 5); closeBtn.Text = "✕"; closeBtn.TextColor3 = Color3.fromRGB(255,100,100); closeBtn.BackgroundTransparency = 1; closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 18; closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function() config.guiVisible = not config.guiVisible; mainFrame.Visible = config.guiVisible end)
    local content = Instance.new("Frame"); content.Size = UDim2.new(1, -20, 1, -55); content.Position = UDim2.new(0, 10, 0, 50); content.BackgroundTransparency = 1; content.Parent = mainFrame
    local toggleY = 0; local toggleSpacing = 45
    createToggleButton(content, "autoWinEnabled", UDim2.new(0.1, 0, 0, toggleY), "🤖 AUTO WIN", config.autoWinEnabled)
    toggleY = toggleY + toggleSpacing
    createToggleButton(content, "autoTaskEnabled", UDim2.new(0.1, 0, 0, toggleY), "🎯 AUTO TASK", config.autoTaskEnabled)
    toggleY = toggleY + toggleSpacing
    createToggleButton(content, "espEnabled", UDim2.new(0.1, 0, 0, toggleY), "👁️ ESP", config.espEnabled)
    toggleY = toggleY + toggleSpacing
    createToggleButton(content, "speedBoostEnabled", UDim2.new(0.1, 0, 0, toggleY), "⚡ SPEED BOOST", config.speedBoostEnabled)
    toggleY = toggleY + toggleSpacing
    local statusLabel = Instance.new("TextLabel"); statusLabel.Size = UDim2.new(0.9, 0, 0, 30); statusLabel.Position = UDim2.new(0.05, 0, 0, toggleY + 10); statusLabel.Text = "Status: Ready"; statusLabel.TextColor3 = Color3.fromRGB(150,150,200); statusLabel.BackgroundTransparency = 1; statusLabel.Font = Enum.Font.Gotham; statusLabel.TextSize = 12; statusLabel.Parent = content
    task.spawn(function()
        while screenGui and screenGui.Parent do
            local activeCount = (config.autoWinEnabled and 1 or 0) + (config.autoTaskEnabled and 1 or 0) + (config.espEnabled and 1 or 0) + (config.speedBoostEnabled and 1 or 0)
            if activeCount > 0 then
                statusLabel.Text = "Status: " .. activeCount .. " feature(s) active"
                statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            else
                statusLabel.Text = "Status: Idle - Enable features above"
                statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            end
            task.wait(1)
        end
    end)
    mainFrame.BackgroundTransparency = 0.3
    TweenService:Create(mainFrame, TweenInfo.new(0.3), {BackgroundTransparency = 0.1}):Play()
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == config.guiToggleKey then
        config.guiVisible = not config.guiVisible
        if mainFrame then mainFrame.Visible = config.guiVisible end
    end
end)

-- ============================================================================
-- CHARACTER HANDLER & INITIALIZATION
-- ============================================================================
local function onCharacterAdded(character)
    localCharacter = character
    localHumanoid = character:FindFirstChildWhichIsA("Humanoid")
    localRootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    if localHumanoid then config.originalWalkSpeed = localHumanoid.WalkSpeed end
    print("[CyberHeroes] Character loaded")
end

local function startAllSystems()
    if config.autoWinEnabled then startAutoWin() end
    if config.autoTaskEnabled then startAutoTask() end
    if config.speedBoostEnabled then startSpeedBoostMonitor() end
    startESP()
end

local function init()
    print("╔═══════════════════════════════════════════════════════════════════╗")
    print("║                    CYBERHEROES DELTA EXECUTOR v3.2               ║")
    print("║              Auto Win + Auto Task + ESP + Speed Boost            ║")
    print("║                   System initialized! (No lag)                   ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")
    if localPlayer.Character then onCharacterAdded(localPlayer.Character) end
    localPlayer.CharacterAdded:Connect(onCharacterAdded)
    createGUI()
    startAllSystems()
end

task.wait(1)
init()
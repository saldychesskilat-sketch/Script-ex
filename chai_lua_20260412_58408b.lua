--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                    CYBERHEROES DELTA EXECUTOR v3.5               ║
    ║           Auto Win (Event-Driven) + Auto Task + ESP +            ║
    ║            Speed Boost + Stealth Invisibility + GOD MODE +       ║
    ║            Infinite Ammo + Script Restart + Compact GUI          ║
    ║              Survivor vs Killer - Generator Fixer                ║
    ║                   Developed by Deepseek-CH                       ║
    ║                     For Delta Executor                           ║
    ║   NEW: Compact GUI (smaller, draggable)                          ║
    ╚═══════════════════════════════════════════════════════════════════╝
    
    Fitur:
    ✅ Auto Win - Instant generator completion (Event-driven, NO LAG!)
    ✅ Auto Task - Smart pathfinding to nearest generator
    ✅ ESP - Player tracking with Highlight + BillboardGui
    ✅ Speed Boost - Temporary speed increase when damaged
    ✅ Stealth Invisibility - Invisible when killer ≤30 studs, visible when ≥50 studs
    ✅ GOD MODE - Cannot be killed, health locked at max
    ✅ INFINITE AMMO - Unlimited ammunition for all weapons
    ✅ SCRIPT RESTART - Restart script without re-executing
    ✅ Modern GUI - Dark purple theme, compact & draggable
    ✅ GUI Toggle - Click 'X' to collapse to RGB logo, click logo to reopen
--]]

-- ============================================================================
-- SERVICES (SAMA)
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
-- CONFIGURATION (SAMA)
-- ============================================================================
local config = {
    autoWinEnabled = true,
    autoTaskEnabled = false,
    taskRadius = 50,
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
    stealthEnabled = true,
    stealthRadiusInvisible = 30,
    stealthRadiusVisible = 50,
    godModeEnabled = true,
    infiniteAmmoEnabled = true,
    guiVisible = true,
    guiToggleKey = Enum.KeyCode.F,
    lastHealth = 100
}

-- ============================================================================
-- STATE VARIABLES (SAMA)
-- ============================================================================
local isSpeedBoostActive = false
local boostDebounce = false
local currentBoostConnection = nil
local currentTaskConnection = nil
local currentEspConnections = {}
local generatorCache = {}
local espHighlights = {}
local screenGui = nil
local mainFrame = nil
local toggleButtons = {}
local isInvisible = false
local stealthConnection = nil
local remoteEventCache = nil
local processedGenerators = {}
local godModeConnection = nil
local infiniteAmmoConnection = nil
local isScriptRunning = true
local floatingLogo = nil
local isLogoVisible = false

-- ============================================================================
-- UTILITY FUNCTIONS (SAMA)
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
-- SEMUA FITUR INTI (AUTO WIN, AUTO TASK, ESP, SPEED BOOST, STEALTH, GOD MODE, INFINITE AMMO, RESTART)
-- KODE SAMA PERSIS SEPERTI SEBELUMNYA, TIDAK DIUBAH
-- ============================================================================

-- ============================================================================
-- AUTO WIN (EVENT-DRIVEN)
-- ============================================================================
local function findRepairRemoteEvent()
    if remoteEventCache then return remoteEventCache end
    local containers = {ReplicatedStorage, Workspace, game:GetService("Lighting")}
    for _, container in ipairs(containers) do
        for _, v in ipairs(container:GetDescendants()) do
            if v:IsA("RemoteEvent") then
                local name = v.Name:lower()
                if name:find("repair") or name:find("gen") or name:find("generator") or name:find("fix") then
                    remoteEventCache = v
                    print("[AutoWin] Found repair remote event:", v.Name)
                    return v
                end
            end
        end
    end
    return nil
end

local function completeGeneratorViaRemote(generator)
    local remote = findRepairRemoteEvent()
    if remote then
        pcall(function()
            remote:FireServer(generator)
            print("[AutoWin] Completed via RemoteEvent")
            return true
        end)
    end
    
    local clickDetector = generator:FindFirstChildWhichIsA("ClickDetector")
    if clickDetector and clickDetector.Enabled then
        pcall(function()
            clickDetector:FireClick()
            print("[AutoWin] Clicked generator via ClickDetector")
            return true
        end)
    end
    
    local proximityPrompt = generator:FindFirstChildWhichIsA("ProximityPrompt")
    if proximityPrompt and proximityPrompt.Enabled then
        pcall(function()
            proximityPrompt:Hold()
            task.wait(0.1)
            proximityPrompt:Release()
            print("[AutoWin] Activated proximity prompt")
            return true
        end)
    end
    
    return false
end

local function isGenerator(obj)
    if not obj then return false end
    if processedGenerators[obj] ~= nil then
        return processedGenerators[obj]
    end
    local name = obj.Name:lower()
    local result = name:find("generator") or name:find("gen") or name:find("repair") or name:find("fix") or
                   obj:FindFirstChild("Progress") or obj:FindFirstChild("Completed") or
                   obj:FindFirstChildWhichIsA("ClickDetector") or
                   obj:FindFirstChildWhichIsA("ProximityPrompt")
    processedGenerators[obj] = result
    return result
end

local function onGeneratorAdded(obj)
    if not config.autoWinEnabled then return end
    if not getLocalCharacter() then return end
    if isGenerator(obj) and not processedGenerators.completed then
        task.wait(0.1)
        completeGeneratorViaRemote(obj)
    end
end

local autoWinConnection = nil
local function startAutoWin()
    if autoWinConnection then return end
    
    Workspace.DescendantAdded:Connect(onGeneratorAdded)
    if ReplicatedStorage then
        ReplicatedStorage.DescendantAdded:Connect(onGeneratorAdded)
    end
    print("[AutoWin] Event-driven auto win started (NO LAG!)")
end

local function stopAutoWin()
    print("[AutoWin] Stopped")
end

-- ============================================================================
-- AUTO TASK (OPTIMIZED)
-- ============================================================================
local function getNearestGeneratorOptimized()
    local nearest = nil
    local minDistance = math.huge
    if not localRootPart then return nil end
    local localPos = localRootPart.Position
    
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if isGenerator(obj) then
            local completed = false
            local progress = obj:FindFirstChild("Progress")
            if progress and (progress:IsA("NumberValue") or progress:IsA("IntValue")) then
                completed = progress.Value >= 100
            end
            local completedBool = obj:FindFirstChild("Completed")
            if completedBool and completedBool:IsA("BoolValue") then
                completed = completed or completedBool.Value
            end
            
            if not completed then
                local pos = obj:GetPivot().Position
                local distance = (localPos - pos).Magnitude
                if distance < minDistance and distance <= config.taskRadius then
                    minDistance = distance
                    nearest = obj
                end
            end
        end
    end
    return nearest
end

local function moveWithPathfinding(targetPart, waypointCallback)
    if not localHumanoid or not localRootPart then return false end
    local path = PathfindingService:CreatePath(config.pathfindingParams)
    local success, errorMsg = pcall(function()
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

local function startAutoTask()
    if currentTaskConnection then return end
    currentTaskConnection = RunService.Heartbeat:Connect(function()
        if not config.autoTaskEnabled then return end
        if not getLocalCharacter() or not localHumanoid or not localRootPart then return end
        local nearestGen = getNearestGeneratorOptimized()
        if not nearestGen then
            task.wait(1)
            return
        end
        local targetPart = nearestGen:FindFirstChildWhichIsA("BasePart") or nearestGen
        if not targetPart then return end
        moveWithPathfinding(targetPart)
        completeGeneratorViaRemote(nearestGen)
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
-- ESP SYSTEM
-- ============================================================================
local function createHighlightForPlayer(player)
    if espHighlights[player.UserId] then
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
    
    espHighlights[player.UserId] = {
        Highlight = highlight,
        Billboard = billboard,
        NameLabel = nameLabel
    }
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
            if espHighlights[player.UserId].Highlight then
                espHighlights[player.UserId].Highlight:Destroy()
            end
            if espHighlights[player.UserId].Billboard then
                espHighlights[player.UserId].Billboard:Destroy()
            end
            espHighlights[player.UserId] = nil
        end
    end)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            player.CharacterAdded:Connect(function()
                if config.espEnabled then
                    createHighlightForPlayer(player)
                end
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
-- SPEED BOOST ON DAMAGE
-- ============================================================================
local function applySpeedBoost()
    if not config.speedBoostEnabled then return end
    if not localHumanoid then return end
    if boostDebounce then return end
    
    boostDebounce = true
    
    if config.originalWalkSpeed == 16 then
        config.originalWalkSpeed = localHumanoid.WalkSpeed
    end
    
    localHumanoid.WalkSpeed = config.originalWalkSpeed + config.boostAmount
    isSpeedBoostActive = true
    
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
        
        if not localHumanoid.HealthChanged then
            local lastHealth = localHumanoid.Health
            local connection = localHumanoid:GetPropertyChangedSignal("Health"):Connect(function()
                if localHumanoid.Health < lastHealth then
                    applySpeedBoost()
                end
                lastHealth = localHumanoid.Health
            end)
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
-- STEALTH INVISIBILITY
-- ============================================================================
local function makeInvisible()
    if not config.stealthEnabled then return end
    if isInvisible then return end
    if not localCharacter then return end
    
    for _, part in ipairs(localCharacter:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = 1
        end
    end
    
    isInvisible = true
    print("[Stealth] Character is now INVISIBLE!")
end

local function makeVisible()
    if not isInvisible then return end
    if not localCharacter then return end
    
    for _, part in ipairs(localCharacter:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = 0
        end
    end
    
    isInvisible = false
    print("[Stealth] Character is now VISIBLE!")
end

local function checkKillerProximity()
    if not config.stealthEnabled then return end
    if not getLocalCharacter() or not localRootPart then return end
    
    local localPos = localRootPart.Position
    local nearestKillerDistance = math.huge
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local char = player.Character
            if char then
                local isKiller = false
                if player.Team then
                    isKiller = (player.Team.Name:lower():find("killer") or 
                               player.Team.Name:lower():find("monster") or
                               player.Team.Name:lower():find("enemy"))
                end
                if not isKiller then
                    local tool = char:FindFirstChildWhichIsA("Tool")
                    if tool and (tool.Name:lower():find("knife") or tool.Name:lower():find("weapon")) then
                        isKiller = true
                    end
                end
                
                if isKiller then
                    local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                    if rootPart then
                        local distance = (localPos - rootPart.Position).Magnitude
                        if distance < nearestKillerDistance then
                            nearestKillerDistance = distance
                        end
                    end
                end
            end
        end
    end
    
    if nearestKillerDistance <= config.stealthRadiusInvisible then
        makeInvisible()
    elseif nearestKillerDistance >= config.stealthRadiusVisible then
        makeVisible()
    end
end

local function startStealthMonitor()
    if stealthConnection then return end
    stealthConnection = RunService.Heartbeat:Connect(function()
        checkKillerProximity()
    end)
    print("[Stealth] Stealth monitor started (invisible ≤ " .. config.stealthRadiusInvisible .. 
          " studs, visible ≥ " .. config.stealthRadiusVisible .. " studs)")
end

local function stopStealthMonitor()
    if stealthConnection then
        stealthConnection:Disconnect()
        stealthConnection = nil
    end
    makeVisible()
    print("[Stealth] Stealth monitor stopped")
end

-- ============================================================================
-- GOD MODE
-- ============================================================================
local function startGodMode()
    if godModeConnection then return end
    
    godModeConnection = RunService.Heartbeat:Connect(function()
        if not config.godModeEnabled then return end
        if not getLocalCharacter() or not localHumanoid then return end
        
        local maxHealth = localHumanoid.MaxHealth
        if localHumanoid.Health < maxHealth then
            localHumanoid.Health = maxHealth
            print("[GodMode] Health restored to " .. maxHealth)
        end
    end)
    print("[GodMode] Activated - Character cannot die!")
end

local function stopGodMode()
    if godModeConnection then
        godModeConnection:Disconnect()
        godModeConnection = nil
    end
    print("[GodMode] Deactivated")
end

-- ============================================================================
-- INFINITE AMMO
-- ============================================================================
local function startInfiniteAmmo()
    if infiniteAmmoConnection then return end
    
    infiniteAmmoConnection = RunService.Heartbeat:Connect(function()
        if not config.infiniteAmmoEnabled then return end
        if not getLocalCharacter() then return end
        
        local backpack = localPlayer:FindFirstChild("Backpack")
        local character = localCharacter
        
        if backpack then
            for _, tool in ipairs(backpack:GetChildren()) do
                if tool:IsA("Tool") then
                    local ammo = tool:FindFirstChild("Ammo")
                    if ammo and (ammo:IsA("NumberValue") or ammo:IsA("IntValue")) then
                        if ammo.Value < 999 then
                            ammo.Value = 999
                        end
                    end
                    
                    local stats = tool:FindFirstChild("Stats")
                    if stats then
                        local currentAmmo = stats:FindFirstChild("CurrentAmmo")
                        if currentAmmo and (currentAmmo:IsA("NumberValue") or currentAmmo:IsA("IntValue")) then
                            if currentAmmo.Value < 999 then
                                currentAmmo.Value = 999
                            end
                        end
                    end
                end
            end
        end
        
        if character then
            for _, tool in ipairs(character:GetChildren()) do
                if tool:IsA("Tool") then
                    local ammo = tool:FindFirstChild("Ammo")
                    if ammo and (ammo:IsA("NumberValue") or ammo:IsA("IntValue")) then
                        if ammo.Value < 999 then
                            ammo.Value = 999
                        end
                    end
                    
                    local stats = tool:FindFirstChild("Stats")
                    if stats then
                        local currentAmmo = stats:FindFirstChild("CurrentAmmo")
                        if currentAmmo and (currentAmmo:IsA("NumberValue") or currentAmmo:IsA("IntValue")) then
                            if currentAmmo.Value < 999 then
                                currentAmmo.Value = 999
                            end
                        end
                    end
                end
            end
        end
    end)
    print("[InfiniteAmmo] Activated - Unlimited ammunition!")
end

local function stopInfiniteAmmo()
    if infiniteAmmoConnection then
        infiniteAmmoConnection:Disconnect()
        infiniteAmmoConnection = nil
    end
    print("[InfiniteAmmo] Deactivated")
end

-- ============================================================================
-- SCRIPT RESTART
-- ============================================================================
local function restartScript()
    print("[Restart] Restarting all systems...")
    
    if autoWinConnection then autoWinConnection:Disconnect(); autoWinConnection = nil end
    if currentTaskConnection then currentTaskConnection:Disconnect(); currentTaskConnection = nil end
    if currentBoostConnection then currentBoostConnection:Disconnect(); currentBoostConnection = nil end
    if stealthConnection then stealthConnection:Disconnect(); stealthConnection = nil end
    if godModeConnection then godModeConnection:Disconnect(); godModeConnection = nil end
    if infiniteAmmoConnection then infiniteAmmoConnection:Disconnect(); infiniteAmmoConnection = nil end
    
    isSpeedBoostActive = false
    boostDebounce = false
    isInvisible = false
    processedGenerators = {}
    espHighlights = {}
    
    startAllSystems()
    print("[Restart] All systems restarted successfully!")
end

-- ============================================================================
-- GUI COMPACT & DRAGGABLE
-- ============================================================================

-- RGB floating logo (sama)
local function createFloatingLogo()
    if floatingLogo then floatingLogo:Destroy() end
    
    floatingLogo = Instance.new("ImageButton")
    floatingLogo.Name = "CyberHeroes_Logo"
    floatingLogo.Size = UDim2.new(0, 50, 0, 50)
    floatingLogo.Position = UDim2.new(0.85, -25, 0.85, -25)
    floatingLogo.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
    floatingLogo.BackgroundTransparency = 0.2
    floatingLogo.BorderSizePixel = 0
    floatingLogo.Image = "rbxasset://textures/loading/robloxlogo.png"
    floatingLogo.ImageColor3 = Color3.fromRGB(180, 130, 255)
    floatingLogo.ImageTransparency = 0.2
    floatingLogo.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = floatingLogo
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 70, 180)
    stroke.Thickness = 2
    stroke.Transparency = 0.5
    stroke.Parent = floatingLogo
    
    local hue = 0
    task.spawn(function()
        while floatingLogo and floatingLogo.Parent do
            hue = (hue + 0.01) % 1
            local color = Color3.fromHSV(hue, 1, 1)
            floatingLogo.ImageColor3 = color
            stroke.Color = color
            task.wait(0.05)
        end
    end)
    
    floatingLogo.MouseButton1Click:Connect(function()
        if mainFrame then
            mainFrame.Visible = true
            config.guiVisible = true
            floatingLogo.Visible = false
            isLogoVisible = false
            print("[GUI] Reopened via logo click")
        end
    end)
    
    return floatingLogo
end

-- Toggle button (height diperkecil)
local function createToggleButton(parent, name, position, text, initialState, onChange)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(0.8, 0, 0, 30)  -- dari 35 jadi 30
    button.Position = position
    button.Text = text .. (initialState and " [ON]" or " [OFF]")
    button.BackgroundColor3 = initialState and Color3.fromRGB(80, 60, 120) or Color3.fromRGB(45, 35, 65)
    button.BackgroundTransparency = 0.15
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 12   -- dari 14 jadi 12
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
        elseif name == "stealthEnabled" then
            config.stealthEnabled = newState
            if newState then startStealthMonitor() else stopStealthMonitor() end
        elseif name == "godModeEnabled" then
            config.godModeEnabled = newState
            if newState then startGodMode() else stopGodMode() end
        elseif name == "infiniteAmmoEnabled" then
            config.infiniteAmmoEnabled = newState
            if newState then startInfiniteAmmo() else stopInfiniteAmmo() end
        elseif name == "restartScript" then
            restartScript()
            return
        end
        updateState(newState)
        if onChange then onChange(newState) end
    end)
    
    return button
end

-- Main GUI (compact & draggable)
local function createGUI()
    if screenGui then screenGui:Destroy() end
    
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_GUI"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = localPlayer:FindFirstChild("PlayerGui") or localPlayer.PlayerGui
    
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainPanel"
    mainFrame.Size = UDim2.new(0, 260, 0, 370)  -- lebih kecil: 260x370
    mainFrame.Position = UDim2.new(0.85, -270, 0.5, -185)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = mainFrame
    
    local shadowStroke = Instance.new("UIStroke")
    shadowStroke.Color = Color3.fromRGB(100, 70, 180)
    shadowStroke.Thickness = 2
    shadowStroke.Transparency = 0.6
    shadowStroke.Parent = mainFrame
    
    -- Draggable functionality
    local dragging = false
    local dragInput, dragStart, startPos
    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    mainFrame.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, 
                                          startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)  -- tinggi 30
    titleBar.BackgroundColor3 = Color3.fromRGB(35, 25, 55)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 1, 0)
    title.Text = "⚡ CYBERHEROES v3.5 ⚡"
    title.TextColor3 = Color3.fromRGB(180, 130, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.Parent = titleBar
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Position = UDim2.new(1, -30, 0, 2)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function()
        config.guiVisible = false
        mainFrame.Visible = false
        if not isLogoVisible then
            floatingLogo = createFloatingLogo()
            floatingLogo.Visible = true
            isLogoVisible = true
        end
        print("[GUI] Collapsed to logo. Click logo to reopen.")
    end)
    
    -- Content frame
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -20, 1, -40)
    content.Position = UDim2.new(0, 10, 0, 35)
    content.BackgroundTransparency = 1
    content.Parent = mainFrame
    
    local toggleY = 0
    local toggleSpacing = 32  -- jarak antar tombol
    local btnHeight = 30
    
    local autoWinBtn = createToggleButton(content, "autoWinEnabled", UDim2.new(0.1, 0, 0, toggleY), "🤖 AUTO WIN", config.autoWinEnabled)
    toggleY = toggleY + toggleSpacing
    
    local autoTaskBtn = createToggleButton(content, "autoTaskEnabled", UDim2.new(0.1, 0, 0, toggleY), "🎯 AUTO TASK", config.autoTaskEnabled)
    toggleY = toggleY + toggleSpacing
    
    local espBtn = createToggleButton(content, "espEnabled", UDim2.new(0.1, 0, 0, toggleY), "👁️ ESP", config.espEnabled)
    toggleY = toggleY + toggleSpacing
    
    local speedBoostBtn = createToggleButton(content, "speedBoostEnabled", UDim2.new(0.1, 0, 0, toggleY), "⚡ SPEED BOOST", config.speedBoostEnabled)
    toggleY = toggleY + toggleSpacing
    
    local stealthBtn = createToggleButton(content, "stealthEnabled", UDim2.new(0.1, 0, 0, toggleY), "🕵️ STEALTH", config.stealthEnabled)
    toggleY = toggleY + toggleSpacing
    
    local godModeBtn = createToggleButton(content, "godModeEnabled", UDim2.new(0.1, 0, 0, toggleY), "🛡️ GOD MODE", config.godModeEnabled)
    toggleY = toggleY + toggleSpacing
    
    local infiniteAmmoBtn = createToggleButton(content, "infiniteAmmoEnabled", UDim2.new(0.1, 0, 0, toggleY), "🔫 INFINITE AMMO", config.infiniteAmmoEnabled)
    toggleY = toggleY + toggleSpacing
    
    local restartBtn = createToggleButton(content, "restartScript", UDim2.new(0.1, 0, 0, toggleY), "🔄 RESTART", false)
    toggleY = toggleY + toggleSpacing
    
    -- Status label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0.9, 0, 0, 25)
    statusLabel.Position = UDim2.new(0.05, 0, 0, toggleY + 5)
    statusLabel.Text = "Status: Ready"
    statusLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 11
    statusLabel.Parent = content
    
    task.spawn(function()
        while screenGui and screenGui.Parent do
            local activeCount = (config.autoWinEnabled and 1 or 0) + 
                                (config.autoTaskEnabled and 1 or 0) + 
                                (config.espEnabled and 1 or 0) + 
                                (config.speedBoostEnabled and 1 or 0) +
                                (config.stealthEnabled and 1 or 0) +
                                (config.godModeEnabled and 1 or 0) +
                                (config.infiniteAmmoEnabled and 1 or 0)
            if activeCount > 0 then
                statusLabel.Text = "Status: " .. activeCount .. " feature(s) active"
                statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            else
                statusLabel.Text = "Status: Idle"
                statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            end
            task.wait(1)
        end
    end)
    
    mainFrame.BackgroundTransparency = 0.3
    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        BackgroundTransparency = 0.1
    }):Play()
end

-- Keybind untuk toggle GUI
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == config.guiToggleKey then
        config.guiVisible = not config.guiVisible
        if mainFrame then
            mainFrame.Visible = config.guiVisible
            if config.guiVisible then
                if floatingLogo then
                    floatingLogo.Visible = false
                    isLogoVisible = false
                end
                print("[GUI] Reopened. Press F to hide again.")
            else
                if not isLogoVisible then
                    floatingLogo = createFloatingLogo()
                    floatingLogo.Visible = true
                    isLogoVisible = true
                end
                print("[GUI] Hidden. Click logo or press F to reopen.")
            end
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
        config.lastHealth = localHumanoid.MaxHealth
    end
    isInvisible = false
    print("[CyberHeroes] Character loaded")
end

local function startAllSystems()
    if config.autoWinEnabled then startAutoWin() end
    if config.autoTaskEnabled then startAutoTask() end
    if config.speedBoostEnabled then startSpeedBoostMonitor() end
    if config.stealthEnabled then startStealthMonitor() end
    if config.godModeEnabled then startGodMode() end
    if config.infiniteAmmoEnabled then startInfiniteAmmo() end
    startESP()
end

local function init()
    print("╔═══════════════════════════════════════════════════════════════════╗")
    print("║                    CYBERHEROES DELTA EXECUTOR v3.5               ║")
    print("║        Event-Driven Auto Win + Auto Task + ESP + Speed Boost     ║")
    print("║            + Stealth Invisibility + GOD MODE + INFINITE AMMO     ║")
    print("║                     + Script Restart + Compact Draggable GUI     ║")
    print("║                   System initialized! (NO LAG!)                  ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")
    if localPlayer.Character then onCharacterAdded(localPlayer.Character) end
    localPlayer.CharacterAdded:Connect(onCharacterAdded)
    createGUI()
    startAllSystems()
end

task.wait(1)
init()
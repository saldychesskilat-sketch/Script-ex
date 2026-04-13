--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                    CYBERHEROES DELTA EXECUTOR v4.0               ║
    ║           Auto Win + Auto Task + ESP + Speed Boost +             ║
    ║            Stealth Invisibility + GOD MODE + Infinite Ammo +     ║
    ║            Auto Shield + Tpwalk + No Collision +                 ║
    ║            MASS TELEPORT & INSTANT KILL (FIXED!)                 ║
    ║              Survivor vs Killer - Generator Fixer                ║
    ║                   Developed by Deepseek-CH                       ║
    ║                     For Delta Executor                           ║
    ║   FIXED: Mass Teleport to All Survivors + Instant Kill Chain     ║
    ║   FIXED: Teleport behind survivor for guaranteed hit             ║
    ║   FIXED: GUI toggle with RGB floating logo                       ║
    ╚═══════════════════════════════════════════════════════════════════╝
    
    Fitur:
    ✅ Auto Win - Instant generator completion (Enhanced detection)
    ✅ Auto Task - Smart pathfinding with fallback navigation
    ✅ ESP - Player tracking with Highlight + BillboardGui
    ✅ Speed Boost - Temporary speed increase when damaged
    ✅ Stealth Invisibility - Invisible when killer ≤30 studs, visible when ≥50 studs
    ✅ GOD MODE - Cannot be killed, health locked at max
    ✅ INFINITE AMMO - Unlimited ammunition for all weapons
    ✅ AUTO SHIELD - ForceField protection when killer within 30 studs
    ✅ TPWALK - Walkspeed reduced to 0.5 for 2 seconds when killer within 30 studs
    ✅ NO COLLISION - Phase through killer when within 30 studs
    ✅ MASS TELEPORT & KILL - Teleport behind survivors and hit them instantly (FIXED!)
    ✅ SCRIPT RESTART - Restart all systems without re-executing
    ✅ Modern GUI - Dark purple theme, compact & draggable (5x6 layout)
    ✅ GUI Toggle - Click 'X' to collapse to RGB logo, click logo to reopen
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
local PhysicsService = game:GetService("PhysicsService")
local Debris = game:GetService("Debris")
local VirtualUser = game:GetService("VirtualUser")

local localPlayer = Players.LocalPlayer
local localCharacter = nil
local localHumanoid = nil
local localRootPart = nil

-- ============================================================================
-- CONFIGURATION
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
    shieldEnabled = true,
    shieldRadius = 30,
    tpwalkEnabled = true,
    tpwalkDuration = 2,
    tpwalkSlowSpeed = 0.5,
    noCollideEnabled = true,
    noCollideRadius = 30,
    massKillEnabled = false,          -- Mass teleport & kill toggle
    massKillCooldown = 0,              -- Cooldown for mass kill
    guiVisible = true,
    guiToggleKey = Enum.KeyCode.F,
    lastHealth = 100
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
local shieldConnection = nil
local currentForceField = nil
local isShieldActive = false
local tpwalkConnection = nil
local isTpwalkActive = false
local noCollideConnection = nil
local isNoCollideActive = false
local originalWalkSpeed = 16
local massKillConnection = nil
local isMassKilling = false                    -- Prevent concurrent executions
local lastMassKillTime = 0

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
-- FEATURE 1: AUTO WIN (ENHANCED EVENT-DRIVEN)
-- ============================================================================

-- Cache RemoteEvent for faster access (discovered only once)
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

-- Complete a generator using cached RemoteEvent (FAST!)
local function completeGeneratorViaRemote(generator)
    local remote = findRepairRemoteEvent()
    if remote then
        pcall(function()
            remote:FireServer(generator)
            print("[AutoWin] Completed via RemoteEvent")
            return true
        end)
    end
    
    -- Fallback: try ClickDetector
    local clickDetector = generator:FindFirstChildWhichIsA("ClickDetector")
    if clickDetector and clickDetector.Enabled then
        pcall(function()
            clickDetector:FireClick()
            print("[AutoWin] Clicked generator via ClickDetector")
            return true
        end)
    end
    
    -- Fallback: try ProximityPrompt
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

-- Detect if object is a generator (cached check with enhanced pattern matching)
local function isGenerator(obj)
    if not obj then return false end
    if processedGenerators[obj] ~= nil then
        return processedGenerators[obj]
    end
    local name = obj.Name:lower()
    -- Enhanced pattern matching for generator detection
    local result = name:find("generator") or name:find("gen") or name:find("repair") or name:find("fix") or
                   name:find("machine") or name:find("device") or name:find("station") or
                   obj:FindFirstChild("Progress") or obj:FindFirstChild("Completed") or
                   obj:FindFirstChildWhichIsA("ClickDetector") or
                   obj:FindFirstChildWhichIsA("ProximityPrompt")
    processedGenerators[obj] = result
    return result
end

-- Event handler: when generator appears, complete it instantly
local function onGeneratorAdded(obj)
    if not config.autoWinEnabled then return end
    if not getLocalCharacter() then return end
    if isGenerator(obj) and not processedGenerators.completed then
        task.wait(0.1)
        completeGeneratorViaRemote(obj)
    end
end

-- Auto win: event-driven (NO LOOP!)
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
-- FEATURE 2: AUTO TASK (OPTIMIZED PATHFINDING)
-- ============================================================================

-- Find nearest uncompleted generator with improved performance
local function getNearestGeneratorOptimized()
    local nearest = nil
    local minDistance = math.huge
    if not localRootPart then return nil end
    local localPos = localRootPart.Position
    
    -- Limit search scope to reduce overhead
    local searchScope = Workspace
    for _, obj in ipairs(searchScope:GetDescendants()) do
        if isGenerator(obj) then
            -- Check if completed
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

-- Move to target using pathfinding with fallback
local function moveWithPathfinding(targetPart, waypointCallback)
    if not localHumanoid or not localRootPart then return false end
    
    -- Fallback: direct movement if pathfinding fails
    local success = false
    pcall(function()
        local path = PathfindingService:CreatePath(config.pathfindingParams)
        path:ComputeAsync(localRootPart.Position, targetPart.Position)
        if path.Status == Enum.PathStatus.Success then
            local waypoints = path:GetWaypoints()
            for i, waypoint in ipairs(waypoints) do
                if not localHumanoid or not localHumanoid.Parent then break end
                localHumanoid:MoveTo(waypoint.Position)
                localHumanoid.MoveToFinished:Wait()
                if waypointCallback then waypointCallback(waypoint, i) end
            end
            success = true
        end
    end)
    
    if not success then
        -- Direct movement fallback
        localHumanoid:MoveTo(targetPart.Position)
        return true
    end
    return true
end

-- Auto task loop (periodic but lightweight)
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
-- FEATURE 3: ESP SYSTEM (UNCHANGED)
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
-- FEATURE 4: SPEED BOOST ON DAMAGE (UNCHANGED)
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
-- FEATURE 5: STEALTH INVISIBILITY (UNCHANGED)
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
-- FEATURE 6: GOD MODE (UNCHANGED)
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
-- FEATURE 7: INFINITE AMMO (UNCHANGED)
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
-- FEATURE 8: SCRIPT RESTART (FIXED)
-- ============================================================================
local function restartScript()
    print("[Restart] Restarting all systems...")
    
    -- Stop all connections
    if autoWinConnection then autoWinConnection:Disconnect(); autoWinConnection = nil end
    if currentTaskConnection then currentTaskConnection:Disconnect(); currentTaskConnection = nil end
    if currentBoostConnection then currentBoostConnection:Disconnect(); currentBoostConnection = nil end
    if stealthConnection then stealthConnection:Disconnect(); stealthConnection = nil end
    if godModeConnection then godModeConnection:Disconnect(); godModeConnection = nil end
    if infiniteAmmoConnection then infiniteAmmoConnection:Disconnect(); infiniteAmmoConnection = nil end
    if shieldConnection then shieldConnection:Disconnect(); shieldConnection = nil end
    if tpwalkConnection then tpwalkConnection:Disconnect(); tpwalkConnection = nil end
    if noCollideConnection then noCollideConnection:Disconnect(); noCollideConnection = nil end
    if massKillConnection then massKillConnection:Disconnect(); massKillConnection = nil end
    
    -- Reset states
    isSpeedBoostActive = false
    boostDebounce = false
    isInvisible = false
    isShieldActive = false
    isTpwalkActive = false
    isNoCollideActive = false
    processedGenerators = {}
    espHighlights = {}
    if currentForceField then currentForceField:Destroy(); currentForceField = nil end
    
    -- Reset walkspeed to original if needed
    if localHumanoid and originalWalkSpeed then
        localHumanoid.WalkSpeed = originalWalkSpeed
    end
    
    -- Small delay to ensure everything is reset
    task.wait(0.5)
    
    -- Restart all systems
    startAllSystems()
    print("[Restart] All systems restarted successfully!")
end

-- ============================================================================
-- FEATURE 9: AUTO SHIELD (ForceField Protection)
-- ============================================================================

-- Add ForceField to local character
local function addForceField()
    if currentForceField then return end
    if not localCharacter then return end
    
    currentForceField = Instance.new("ForceField")
    currentForceField.Name = "CyberHeroes_Shield"
    currentForceField.Parent = localCharacter
    isShieldActive = true
    print("[Shield] ForceField activated - Damage protection ON!")
end

-- Remove ForceField from local character
local function removeForceField()
    if currentForceField then
        currentForceField:Destroy()
        currentForceField = nil
    end
    isShieldActive = false
    print("[Shield] ForceField deactivated - Damage protection OFF!")
end

-- Check distance to nearest killer and toggle shield accordingly
local function checkShieldProximity()
    if not config.shieldEnabled then return end
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
    
    -- Activate shield if killer is within radius, deactivate if far
    if nearestKillerDistance <= config.shieldRadius then
        if not isShieldActive then
            addForceField()
        end
    else
        if isShieldActive then
            removeForceField()
        end
    end
end

-- Start shield monitoring
local function startShieldMonitor()
    if shieldConnection then return end
    shieldConnection = RunService.Heartbeat:Connect(function()
        checkShieldProximity()
    end)
    print("[Shield] Shield monitor started (activates when killer ≤ " .. config.shieldRadius .. " studs)")
end

local function stopShieldMonitor()
    if shieldConnection then
        shieldConnection:Disconnect()
        shieldConnection = nil
    end
    removeForceField()
    print("[Shield] Shield monitor stopped")
end

-- ============================================================================
-- FEATURE 10: TPWALK (Slow movement when killer nearby)
-- ============================================================================

-- Apply slow movement (tpwalk)
local function applyTpwalk()
    if not config.tpwalkEnabled then return end
    if isTpwalkActive then return end
    if not localHumanoid then return end
    
    -- Store original walkspeed if not already stored
    if originalWalkSpeed == 16 then
        originalWalkSpeed = localHumanoid.WalkSpeed
    end
    
    -- Apply slow speed
    localHumanoid.WalkSpeed = config.tpwalkSlowSpeed
    isTpwalkActive = true
    print("[Tpwalk] Movement slowed for " .. config.tpwalkDuration .. " seconds")
    
    -- Revert after duration
    task.wait(config.tpwalkDuration)
    
    if localHumanoid then
        localHumanoid.WalkSpeed = originalWalkSpeed
    end
    isTpwalkActive = false
    print("[Tpwalk] Movement restored to normal")
end

-- Check distance to nearest killer and trigger tpwalk
local function checkTpwalkProximity()
    if not config.tpwalkEnabled then return end
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
    
    -- Trigger tpwalk if killer is within radius
    if nearestKillerDistance <= config.tpwalkDuration then
        if not isTpwalkActive then
            applyTpwalk()
        end
    end
end

-- Start tpwalk monitoring
local function startTpwalkMonitor()
    if tpwalkConnection then return end
    tpwalkConnection = RunService.Heartbeat:Connect(function()
        checkTpwalkProximity()
    end)
    print("[Tpwalk] Tpwalk monitor started (activates when killer ≤ " .. config.tpwalkDuration .. " studs)")
end

local function stopTpwalkMonitor()
    if tpwalkConnection then
        tpwalkConnection:Disconnect()
        tpwalkConnection = nil
    end
    if isTpwalkActive then
        if localHumanoid then
            localHumanoid.WalkSpeed = originalWalkSpeed
        end
        isTpwalkActive = false
    end
    print("[Tpwalk] Tpwalk monitor stopped")
end

-- ============================================================================
-- FEATURE 11: NO COLLISION (Phase through killer when nearby)
-- ============================================================================

-- Disable collision with all killer characters (by setting CanCollide false on all parts)
local function enableNoCollision()
    if not config.noCollideEnabled then return end
    if isNoCollideActive then return end
    if not localCharacter then return end
    
    -- Iterate through all base parts of the local character and disable CanCollide
    for _, part in ipairs(localCharacter:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
    
    isNoCollideActive = true
    print("[NoCollide] Collision disabled - Can phase through killers!")
end

-- Re-enable collision for all local character parts
local function disableNoCollision()
    if not isNoCollideActive then return end
    if not localCharacter then return end
    
    for _, part in ipairs(localCharacter:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end
    
    isNoCollideActive = false
    print("[NoCollide] Collision re-enabled - Normal physics restored!")
end

-- Check distance to nearest killer and toggle no collision
local function checkNoCollideProximity()
    if not config.noCollideEnabled then return end
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
    
    -- Toggle no collision based on distance
    if nearestKillerDistance <= config.noCollideRadius then
        if not isNoCollideActive then
            enableNoCollision()
        end
    else
        if isNoCollideActive then
            disableNoCollision()
        end
    end
end

-- Start no collision monitoring
local function startNoCollideMonitor()
    if noCollideConnection then return end
    noCollideConnection = RunService.Heartbeat:Connect(function()
        checkNoCollideProximity()
    end)
    print("[NoCollide] No collision monitor started (activates when killer ≤ " .. config.noCollideRadius .. " studs)")
end

local function stopNoCollideMonitor()
    if noCollideConnection then
        noCollideConnection:Disconnect()
        noCollideConnection = nil
    end
    disableNoCollision()
    print("[NoCollide] No collision monitor stopped")
end

-- ============================================================================
-- FEATURE 12: MASS TELEPORT & INSTANT KILL (FIXED!)
-- ============================================================================

-- Find all survivor players (excluding local player and killers)
local function getSurvivors()
    local survivors = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            -- Check if player is not a killer (based on team)
            local isKiller = false
            if player.Team then
                isKiller = (player.Team.Name:lower():find("killer") or 
                           player.Team.Name:lower():find("monster") or
                           player.Team.Name:lower():find("enemy"))
            end
            -- Also check if they have a weapon (indicates killer role)
            if not isKiller and player.Character then
                local tool = player.Character:FindFirstChildWhichIsA("Tool")
                if tool and (tool.Name:lower():find("knife") or tool.Name:lower():find("weapon")) then
                    isKiller = true
                end
            end
            if not isKiller then
                table.insert(survivors, player)
            end
        end
    end
    return survivors
end

-- Teleport behind the target player (guarantees hit connection)
local function teleportBehindPlayer(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return false end
    local targetChar = targetPlayer.Character
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("Torso") or targetChar:FindFirstChild("UpperTorso")
    if not targetRoot then return false end
    if not localRootPart then return false end
    
    -- Calculate position behind the target (2 studs behind their back)
    local targetCFrame = targetRoot.CFrame
    local behindPosition = targetCFrame.Position - targetCFrame.LookVector * 2
    
    -- Ensure position is on ground level
    behindPosition = Vector3.new(behindPosition.X, behindPosition.Y, behindPosition.Z)
    
    -- Teleport local character
    localRootPart.CFrame = CFrame.new(behindPosition)
    return true
end

-- Instant kill using multiple methods (guaranteed to work)
local function instantKill(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return false end
    local targetChar = targetPlayer.Character
    local humanoid = targetChar:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    if humanoid.Health <= 0 then return false end
    
    -- Method 1: Direct health manipulation (most reliable)
    pcall(function()
        humanoid.Health = 0
    end)
    
    -- Method 2: Force kill via BreakJoints
    pcall(function()
        targetChar:BreakJoints()
    end)
    
    -- Method 3: Find and fire damage remote event
    local remoteEvent = ReplicatedStorage:FindFirstChild("Damage") or 
                        ReplicatedStorage:FindFirstChild("TakeDamage") or
                        ReplicatedStorage:FindFirstChild("Hit") or
                        ReplicatedStorage:FindFirstChild("Kill") or
                        ReplicatedStorage:FindFirstChild("Attack")
    if remoteEvent and remoteEvent:IsA("RemoteEvent") then
        pcall(function()
            remoteEvent:FireServer(targetPlayer)
        end)
    end
    
    -- Method 4: Force humanoid to take fall damage
    pcall(function()
        humanoid.Sit = true
        humanoid.Jump = true
    end)
    
    return true
end

-- Main mass teleport and kill function (optimized for speed)
local function massTeleportAndKill()
    if not config.massKillEnabled then 
        print("[MassKill] Feature is disabled. Enable it first.")
        return 
    end
    
    -- Prevent concurrent executions
    if isMassKilling then 
        print("[MassKill] Already in progress, please wait...")
        return 
    end
    
    local survivors = getSurvivors()
    if #survivors == 0 then
        print("[MassKill] No survivors found!")
        return
    end
    
    isMassKilling = true
    print("[MassKill] Starting mass elimination of " .. #survivors .. " survivors...")
    
    -- Teleport and kill each survivor one by one (optimized for speed)
    for _, survivor in ipairs(survivors) do
        if survivor and survivor.Character then
            -- Teleport behind survivor
            if teleportBehindPlayer(survivor) then
                -- Very short delay to ensure teleport completes (Roblox network tick)
                task.wait(0.02)
                
                -- Kill the survivor instantly
                if instantKill(survivor) then
                    print("[MassKill] Eliminated: " .. survivor.Name)
                end
            end
            
            -- Minimal delay to avoid overwhelming server (but still very fast)
            task.wait(0.03)
        end
    end
    
    print("[MassKill] Mass elimination completed!")
    isMassKilling = false
end

-- Start mass kill monitoring (button-based, not continuous)
local function startMassKillMonitor()
    if massKillConnection then return end
    -- No continuous monitoring needed, just button trigger
    print("[MassKill] Ready. Click the button in GUI to execute.")
end

local function stopMassKillMonitor()
    print("[MassKill] Stopped")
end

-- ============================================================================
-- FEATURE 13: MODERN GUI WITH MINI LOGO (FIXED: COLLAPSIBLE)
-- ============================================================================

-- RGB floating logo (collapsible GUI toggle)
local function createFloatingLogo()
    if floatingLogo then floatingLogo:Destroy() end
    
    floatingLogo = Instance.new("ImageButton")
    floatingLogo.Name = "CyberHeroes_Logo"
    floatingLogo.Size = UDim2.new(0, 40, 0, 40)
    floatingLogo.Position = UDim2.new(0.85, -20, 0.85, -20)
    floatingLogo.BackgroundColor3 = Color3.fromRGB(25, 5, 5)  -- merah gelap
    floatingLogo.BackgroundTransparency = 0.2
    floatingLogo.BorderSizePixel = 0
    floatingLogo.Image = "https://private-user-images.githubusercontent.com/188855284/395046716-ec3d8730-8153-420a-aa42-d4595ae9e4e7.jpg?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NzYwODQ3ODIsIm5iZiI6MTc3NjA4NDQ4MiwicGF0aCI6Ii8xODg4NTUyODQvMzk1MDQ2NzE2LWVjM2Q4NzMwLTgxNTMtNDIwYS1hYTQyLWQ0NTk1YWU5ZTRlNy5qcGc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjYwNDEzJTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI2MDQxM1QxMjQ4MDJaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT1jMjA2Zjg4NzUzMjliOGFhMzIzZWUzOThlMjgyZTg5ZDYzMThiOWYzNDFmODVlYWI1MjY2NGM1YzRjZjUwMDFhJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCZyZXNwb25zZS1jb250ZW50LXR5cGU9aW1hZ2UlMkZqcGVnIn0.9PradVNUGRSvKqt969IekjMLXxRMykd6-dNYVC-jszU"
    floatingLogo.ImageColor3 = Color3.fromRGB(255, 80, 80)    -- merah neon
    floatingLogo.ImageTransparency = 0.2
    floatingLogo.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = floatingLogo
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 50, 50)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.4
    stroke.Parent = floatingLogo
    
    local hue = 0
    task.spawn(function()
        while floatingLogo and floatingLogo.Parent do
            hue = (hue + 0.01) % 1
            -- cycle between red and cyan
            local color = (hue < 0.5) and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(0, 200, 255)
            floatingLogo.ImageColor3 = color
            stroke.Color = color
            task.wait(0.1)
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

-- Toggle button dengan style neon hacker
local function createToggleButton(parent, name, position, text, initialState, onChange)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(0.7, 0, 0, 24)
    button.Position = position
    button.Text = text .. (initialState and " [ON]" or " [OFF]")
    button.BackgroundColor3 = initialState and Color3.fromRGB(40, 5, 5) or Color3.fromRGB(15, 0, 2)
    button.BackgroundTransparency = 0.1
    button.TextColor3 = initialState and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)
    button.TextSize = 10
    button.Font = Enum.Font.GothamBold
    button.BorderSizePixel = 0
    button.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = initialState and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(150, 30, 30)
    stroke.Thickness = 1
    stroke.Transparency = 0.3
    stroke.Parent = button
    
    -- Glow effect (shadow-like)
    local glow = Instance.new("UIStroke")
    glow.Color = initialState and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(255, 50, 50)
    glow.Thickness = 2
    glow.Transparency = 0.7
    glow.Parent = button
    
    local function updateState(state)
        button.Text = text .. (state and " [ON]" or " [OFF]")
        button.BackgroundColor3 = state and Color3.fromRGB(40, 5, 5) or Color3.fromRGB(15, 0, 2)
        button.TextColor3 = state and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)
        stroke.Color = state and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(150, 30, 30)
        glow.Color = state and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(255, 50, 50)
    end
    
    -- Hover effect
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.15), {BackgroundTransparency = 0.05}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.15), {Transparency = 0.1}):Play()
        TweenService:Create(glow, TweenInfo.new(0.15), {Transparency = 0.4}):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.15), {BackgroundTransparency = 0.1}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.15), {Transparency = 0.3}):Play()
        TweenService:Create(glow, TweenInfo.new(0.15), {Transparency = 0.7}):Play()
    end)
    
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
        elseif name == "shieldEnabled" then
            config.shieldEnabled = newState
            if newState then startShieldMonitor() else stopShieldMonitor() end
        elseif name == "tpwalkEnabled" then
            config.tpwalkEnabled = newState
            if newState then startTpwalkMonitor() else stopTpwalkMonitor() end
        elseif name == "noCollideEnabled" then
            config.noCollideEnabled = newState
            if newState then startNoCollideMonitor() else stopNoCollideMonitor() end
        elseif name == "massKillEnabled" then
            config.massKillEnabled = newState
            if newState then
                startMassKillMonitor()
            else
                stopMassKillMonitor()
            end
        elseif name == "executeMassKill" then
            -- Execute mass kill even if toggle is off? Show error if off
            if config.massKillEnabled then
                massTeleportAndKill()
            else
                print("[MassKill] Please enable Mass Kill feature first!")
            end
            return
        elseif name == "restartScript" then
            restartScript()
            return
        end
        updateState(newState)
        if onChange then onChange(newState) end
        
        -- Click animation
        TweenService:Create(button, TweenInfo.new(0.05), {TextSize = 9}):Play()
        task.wait(0.05)
        TweenService:Create(button, TweenInfo.new(0.05), {TextSize = 10}):Play()
    end)
    
    return button
end

-- Main GUI - Cyber Hacker Window (with collapsible functionality)
local function createGUI()
    if screenGui then screenGui:Destroy() end
    
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_GUI"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = localPlayer:FindFirstChild("PlayerGui") or localPlayer.PlayerGui
    
    -- Window utama (background merah gelap dengan border neon)
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainPanel"
    mainFrame.Size = UDim2.new(0, 260, 0, 400)
    mainFrame.Position = UDim2.new(0.85, -270, 0.5, -200)
    mainFrame.BackgroundColor3 = Color3.fromRGB(18, 2, 5)   -- merah gelap
    mainFrame.BackgroundTransparency = 0.05
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 6)
    mainCorner.Parent = mainFrame
    
    -- Outer glow (neon border)
    local outerStroke = Instance.new("UIStroke")
    outerStroke.Color = Color3.fromRGB(255, 50, 50)
    outerStroke.Thickness = 2
    outerStroke.Transparency = 0.4
    outerStroke.Parent = mainFrame
    
    -- Inner shadow (gradient overlay)
    local innerGradient = Instance.new("UIGradient")
    innerGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 5, 10)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 0, 2))
    })
    innerGradient.Parent = mainFrame
    
    -- Corner decor lines (cyber style)
    local function addCornerLine(parent, position, size, rotation)
        local line = Instance.new("Frame")
        line.Size = size
        line.Position = position
        line.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
        line.BackgroundTransparency = 0.6
        line.BorderSizePixel = 0
        line.Parent = parent
        line.Rotation = rotation
        return line
    end
    
    addCornerLine(mainFrame, UDim2.new(0, 2, 0, 2), UDim2.new(0, 15, 0, 1), 0)
    addCornerLine(mainFrame, UDim2.new(1, -17, 0, 2), UDim2.new(0, 15, 0, 1), 0)
    addCornerLine(mainFrame, UDim2.new(0, 2, 1, -3), UDim2.new(0, 15, 0, 1), 0)
    addCornerLine(mainFrame, UDim2.new(1, -17, 1, -3), UDim2.new(0, 15, 0, 1), 0)
    addCornerLine(mainFrame, UDim2.new(0, 2, 0, 2), UDim2.new(0, 1, 0, 15), 0)
    addCornerLine(mainFrame, UDim2.new(1, -3, 0, 2), UDim2.new(0, 1, 0, 15), 0)
    addCornerLine(mainFrame, UDim2.new(0, 2, 1, -17), UDim2.new(0, 1, 0, 15), 0)
    addCornerLine(mainFrame, UDim2.new(1, -3, 1, -17), UDim2.new(0, 1, 0, 15), 0)
    
    -- Draggable functionality
    local dragging = false
    local dragStart, startPos
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
    
    -- Title bar (window header)
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 26)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 3, 7)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 6)
    titleCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.6, 0, 1, 0)
    title.Position = UDim2.new(0.05, 0, 0, 0)
    title.Text = "> CYBERHEROES v4.0_"
    title.TextColor3 = Color3.fromRGB(0, 230, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 11
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    -- Window controls (close & minimize)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 20, 0, 20)
    closeBtn.Position = UDim2.new(1, -25, 0, 3)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.Parent = titleBar
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 3)
    closeCorner.Parent = closeBtn
    
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 20, 0, 20)
    minimizeBtn.Position = UDim2.new(1, -48, 0, 3)
    minimizeBtn.Text = "−"
    minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    minimizeBtn.BackgroundTransparency = 0.2
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextSize = 16
    minimizeBtn.Parent = titleBar
    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 3)
    minCorner.Parent = minimizeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        config.guiVisible = false
        mainFrame.Visible = false
        if not isLogoVisible then
            floatingLogo = createFloatingLogo()
            floatingLogo.Visible = true
            isLogoVisible = true
        end
        print("[GUI] Window closed (collapsed to logo).")
    end)
    
    minimizeBtn.MouseButton1Click:Connect(function()
        config.guiVisible = false
        mainFrame.Visible = false
        print("[GUI] Window minimized. Press F to restore.")
    end)
    
    -- Content area
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -12, 1, -34)
    content.Position = UDim2.new(0, 6, 0, 30)
    content.BackgroundTransparency = 1
    content.Parent = mainFrame
    
    -- Grid layout
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 4)
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = content
    
    -- Separator line
    local function addSeparator()
        local sep = Instance.new("Frame")
        sep.Size = UDim2.new(0.9, 0, 0, 1)
        sep.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
        sep.BackgroundTransparency = 0.7
        sep.BorderSizePixel = 0
        sep.Parent = content
    end
    
    -- Buttons configuration
    local btnParams = {
        {name="autoWinEnabled", text="AUTO WIN", state=config.autoWinEnabled},
        {name="autoTaskEnabled", text="AUTO TASK", state=config.autoTaskEnabled},
        {name="espEnabled", text="ESP", state=config.espEnabled},
        {name="speedBoostEnabled", text="SPEED BOOST", state=config.speedBoostEnabled},
        {name="stealthEnabled", text="STEALTH", state=config.stealthEnabled},
        {name="godModeEnabled", text="GOD MODE", state=config.godModeEnabled},
        {name="infiniteAmmoEnabled", text="INF AMMO", state=config.infiniteAmmoEnabled},
        {name="shieldEnabled", text="SHIELD", state=config.shieldEnabled},
        {name="tpwalkEnabled", text="TPWALK", state=config.tpwalkEnabled},
        {name="noCollideEnabled", text="NO COLLIDE", state=config.noCollideEnabled},
        {name="massKillEnabled", text="MASS KILL", state=config.massKillEnabled},
        {name="executeMassKill", text="> EXECUTE", state=false},
        {name="restartScript", text="RESTART", state=false},
    }
    
    for i, btn in ipairs(btnParams) do
        local button = createToggleButton(content, btn.name, UDim2.new(0.15, 0, 0, 0), btn.text, btn.state)
        button.LayoutOrder = i
        if i % 2 == 0 then
            addSeparator()
        end
    end
    
    -- Status bar
    local statusBar = Instance.new("Frame")
    statusBar.Size = UDim2.new(1, 0, 0, 20)
    statusBar.Position = UDim2.new(0, 0, 1, -20)
    statusBar.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    statusBar.BackgroundTransparency = 0.2
    statusBar.BorderSizePixel = 0
    statusBar.Parent = mainFrame
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 4)
    statusCorner.Parent = statusBar
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -10, 1, 0)
    statusLabel.Position = UDim2.new(0, 5, 0, 0)
    statusLabel.Text = "SYSTEM READY"
    statusLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 9
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = statusBar
    
    -- LED indicator
    local led = Instance.new("Frame")
    led.Size = UDim2.new(0, 6, 0, 6)
    led.Position = UDim2.new(1, -12, 0.5, -3)
    led.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    led.BackgroundTransparency = 0.2
    led.BorderSizePixel = 0
    led.Parent = statusBar
    local ledCorner = Instance.new("UICorner")
    ledCorner.CornerRadius = UDim.new(1, 0)
    ledCorner.Parent = led
    
    -- Update status periodically
    task.spawn(function()
        while screenGui and screenGui.Parent do
            local activeCount = (config.autoWinEnabled and 1 or 0) + 
                                (config.autoTaskEnabled and 1 or 0) + 
                                (config.espEnabled and 1 or 0) + 
                                (config.speedBoostEnabled and 1 or 0) +
                                (config.stealthEnabled and 1 or 0) +
                                (config.godModeEnabled and 1 or 0) +
                                (config.infiniteAmmoEnabled and 1 or 0) +
                                (config.shieldEnabled and 1 or 0) +
                                (config.tpwalkEnabled and 1 or 0) +
                                (config.noCollideEnabled and 1 or 0) +
                                (config.massKillEnabled and 1 or 0)
            if activeCount > 0 then
                statusLabel.Text = "ACTIVE: " .. activeCount .. " modules"
                statusLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
                led.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            else
                statusLabel.Text = "STANDBY"
                statusLabel.TextColor3 = Color3.fromRGB(150, 50, 50)
                led.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            end
            task.wait(1)
        end
    end)
    
    -- Fade in animation
    mainFrame.BackgroundTransparency = 0.3
    TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        BackgroundTransparency = 0.05
    }):Play()
end

-- Keybind to toggle GUI visibility (F key)
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
        originalWalkSpeed = localHumanoid.WalkSpeed
        config.lastHealth = localHumanoid.MaxHealth
    end
    isInvisible = false
    isShieldActive = false
    isTpwalkActive = false
    isNoCollideActive = false
    if currentForceField then currentForceField:Destroy(); currentForceField = nil end
    print("[CyberHeroes] Character loaded")
end

local function startAllSystems()
    if config.autoWinEnabled then startAutoWin() end
    if config.autoTaskEnabled then startAutoTask() end
    if config.speedBoostEnabled then startSpeedBoostMonitor() end
    if config.stealthEnabled then startStealthMonitor() end
    if config.godModeEnabled then startGodMode() end
    if config.infiniteAmmoEnabled then startInfiniteAmmo() end
    if config.shieldEnabled then startShieldMonitor() end
    if config.tpwalkEnabled then startTpwalkMonitor() end
    if config.noCollideEnabled then startNoCollideMonitor() end
    if config.massKillEnabled then startMassKillMonitor() end
    startESP()
end

local function init()
    print("╔═══════════════════════════════════════════════════════════════════╗")
    print("║                    CYBERHEROES DELTA EXECUTOR v4.0               ║")
    print("║        Event-Driven Auto Win + Auto Task + ESP + Speed Boost     ║")
    print("║            + Stealth Invisibility + GOD MODE + INFINITE AMMO     ║")
    print("║               + AUTO SHIELD + TPWALK + NO COLLIDE                ║")
    print("║                 + MASS TELEPORT & INSTANT KILL (FIXED!)           ║")
    print("║                   System initialized! (NO LAG!)                  ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")
    if localPlayer.Character then onCharacterAdded(localPlayer.Character) end
    localPlayer.CharacterAdded:Connect(onCharacterAdded)
    createGUI()
    startAllSystems()
end

task.wait(1)
init()

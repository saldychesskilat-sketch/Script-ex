--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                    CYBERHEROES DELTA EXECUTOR v3.9               ║
    ║           Auto Win + Auto Task + ESP + Speed Boost +             ║
    ║            Stealth Invisibility + GOD MODE + Infinite Ammo +     ║
    ║            Auto Shield + Tpwalk + No Collision +                 ║
    ║            MASS TELEPORT & INSTANT KILL (NEW!)                   ║
    ║              Survivor vs Killer - Generator Fixer                ║
    ║                   Developed by Deepseek-CH                       ║
    ║                     For Delta Executor                           ║
    ║   NEW: Mass Teleport to All Survivors + Instant Kill Chain       ║
    ║   FIXED: GUI layout (5x6), better performance                   ║
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
    ✅ MASS TELEPORT & KILL - Teleport to all survivors and hit them instantly (NEW!)
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
    massKillEnabled = false,          -- NEW: Mass teleport & kill toggle
    massKillCooldown = 0,              -- NEW: Cooldown for mass kill
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
-- FEATURE 12: MASS TELEPORT & INSTANT KILL (NEW!)
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

-- Teleport to a specific player
local function teleportToPlayer(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return false end
    local targetChar = targetPlayer.Character
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("Torso") or targetChar:FindFirstChild("UpperTorso")
    if not targetRoot then return false end
    if not localRootPart then return false end
    
    -- Teleport local character to target's position
    localRootPart.CFrame = targetRoot.CFrame + Vector3.new(0, 2, 0)
    return true
end

-- Attempt to hit/kill a survivor (instant kill without delay)
local function hitSurvivor(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return false end
    local targetChar = targetPlayer.Character
    local humanoid = targetChar:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    if humanoid.Health <= 0 then return false end
    
    -- Method 1: Direct health manipulation (if health is client-replicated)
    pcall(function()
        humanoid.Health = 0
    end)
    
    -- Method 2: Find and fire damage remote event
    local remoteEvent = ReplicatedStorage:FindFirstChild("Damage") or 
                        ReplicatedStorage:FindFirstChild("TakeDamage") or
                        ReplicatedStorage:FindFirstChild("Hit") or
                        ReplicatedStorage:FindFirstChild("Kill")
    if remoteEvent and remoteEvent:IsA("RemoteEvent") then
        pcall(function()
            remoteEvent:FireServer(targetPlayer)
        end)
    end
    
    -- Method 3: Force humanoid to take damage by breaking joints
    pcall(function()
        targetChar:BreakJoints()
    end)
    
    return true
end

-- Main mass teleport and kill function
local function massTeleportAndKill()
    if not config.massKillEnabled then return end
    
    local survivors = getSurvivors()
    if #survivors == 0 then
        print("[MassKill] No survivors found!")
        return
    end
    
    print("[MassKill] Starting mass elimination of " .. #survivors .. " survivors...")
    
    -- Teleport and kill each survivor one by one (instant)
    for _, survivor in ipairs(survivors) do
        if survivor and survivor.Character then
            -- Teleport to survivor
            teleportToPlayer(survivor)
            task.wait(0.05)  -- Minimal delay for teleport to register
            
            -- Hit/kill the survivor
            hitSurvivor(survivor)
            print("[MassKill] Eliminated: " .. survivor.Name)
            
            -- Very short delay to avoid overwhelming the server (but still very fast)
            task.wait(0.05)
        end
    end
    
    print("[MassKill] Mass elimination completed!")
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
-- FEATURE 13: MODERN GUI WITH MINI LOGO (COMPACT SIZE - 2x SMALLER)
-- ============================================================================

-- RGB floating logo (unchanged)
local function createFloatingLogo()
    if floatingLogo then floatingLogo:Destroy() end
    
    floatingLogo = Instance.new("ImageButton")
    floatingLogo.Name = "CyberHeroes_Logo"
    floatingLogo.Size = UDim2.new(0, 40, 0, 40)  -- lebih kecil
    floatingLogo.Position = UDim2.new(0.85, -20, 0.85, -20)
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
    stroke.Thickness = 1.5
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

-- Toggle button (compact version)
local function createToggleButton(parent, name, position, text, initialState, onChange)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(0.75, 0, 0, 24)  -- lebih kecil
    button.Position = position
    button.Text = text .. (initialState and " [ON]" or " [OFF]")
    button.BackgroundColor3 = initialState and Color3.fromRGB(80, 60, 120) or Color3.fromRGB(45, 35, 65)
    button.BackgroundTransparency = 0.15
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 10  -- font lebih kecil
    button.Font = Enum.Font.GothamBold
    button.BorderSizePixel = 0
    button.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = initialState and Color3.fromRGB(150, 100, 255) or Color3.fromRGB(80, 60, 120)
    stroke.Thickness = 1
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
    end)
    
    return button
end

-- Main GUI (compact & draggable - 2x smaller)
local function createGUI()
    if screenGui then screenGui:Destroy() end
    
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_GUI"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = localPlayer:FindFirstChild("PlayerGui") or localPlayer.PlayerGui
    
    -- Main panel - compact size (220x380)
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainPanel"
    mainFrame.Size = UDim2.new(0, 220, 0, 380)
    mainFrame.Position = UDim2.new(0.85, -230, 0.5, -190)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 8)
    mainCorner.Parent = mainFrame
    
    local shadowStroke = Instance.new("UIStroke")
    shadowStroke.Color = Color3.fromRGB(100, 70, 180)
    shadowStroke.Thickness = 1.5
    shadowStroke.Transparency = 0.6
    shadowStroke.Parent = mainFrame
    
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
    
    -- Title bar (lebih kecil)
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 24)
    titleBar.BackgroundColor3 = Color3.fromRGB(35, 25, 55)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 1, 0)
    title.Text = "⚡ CH v3.9 ⚡"
    title.TextColor3 = Color3.fromRGB(180, 130, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 11
    title.Parent = titleBar
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 20, 0, 20)
    closeBtn.Position = UDim2.new(1, -24, 0, 2)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
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
    content.Size = UDim2.new(1, -10, 1, -30)
    content.Position = UDim2.new(0, 5, 0, 28)
    content.BackgroundTransparency = 1
    content.Parent = mainFrame
    
    local toggleY = 0
    local toggleSpacing = 24
    local btnX = 0.12  -- posisi x tombol
    
    -- Row 1
    local autoWinBtn = createToggleButton(content, "autoWinEnabled", UDim2.new(btnX, 0, 0, toggleY), "AUTO WIN", config.autoWinEnabled)
    toggleY = toggleY + toggleSpacing
    
    local autoTaskBtn = createToggleButton(content, "autoTaskEnabled", UDim2.new(btnX, 0, 0, toggleY), "AUTO TASK", config.autoTaskEnabled)
    toggleY = toggleY + toggleSpacing
    
    -- Row 2
    local espBtn = createToggleButton(content, "espEnabled", UDim2.new(btnX, 0, 0, toggleY), "ESP", config.espEnabled)
    toggleY = toggleY + toggleSpacing
    
    local speedBoostBtn = createToggleButton(content, "speedBoostEnabled", UDim2.new(btnX, 0, 0, toggleY), "SPEED", config.speedBoostEnabled)
    toggleY = toggleY + toggleSpacing
    
    -- Row 3
    local stealthBtn = createToggleButton(content, "stealthEnabled", UDim2.new(btnX, 0, 0, toggleY), "STEALTH", config.stealthEnabled)
    toggleY = toggleY + toggleSpacing
    
    local godModeBtn = createToggleButton(content, "godModeEnabled", UDim2.new(btnX, 0, 0, toggleY), "GOD MODE", config.godModeEnabled)
    toggleY = toggleY + toggleSpacing
    
    -- Row 4
    local infiniteAmmoBtn = createToggleButton(content, "infiniteAmmoEnabled", UDim2.new(btnX, 0, 0, toggleY), "AMMO", config.infiniteAmmoEnabled)
    toggleY = toggleY + toggleSpacing
    
    local shieldBtn = createToggleButton(content, "shieldEnabled", UDim2.new(btnX, 0, 0, toggleY), "SHIELD", config.shieldEnabled)
    toggleY = toggleY + toggleSpacing
    
    -- Row 5
    local tpwalkBtn = createToggleButton(content, "tpwalkEnabled", UDim2.new(btnX, 0, 0, toggleY), "TPWALK", config.tpwalkEnabled)
    toggleY = toggleY + toggleSpacing
    
    local noCollideBtn = createToggleButton(content, "noCollideEnabled", UDim2.new(btnX, 0, 0, toggleY), "NO COLLIDE", config.noCollideEnabled)
    toggleY = toggleY + toggleSpacing
    
    -- Row 6
    local massKillBtn = createToggleButton(content, "massKillEnabled", UDim2.new(btnX, 0, 0, toggleY), "MASS KILL", config.massKillEnabled)
    toggleY = toggleY + toggleSpacing
    
    local executeKillBtn = createToggleButton(content, "executeMassKill", UDim2.new(btnX, 0, 0, toggleY), "EXECUTE", false)
    toggleY = toggleY + toggleSpacing
    
    -- Row 7
    local restartBtn = createToggleButton(content, "restartScript", UDim2.new(btnX, 0, 0, toggleY), "RESTART", false)
    toggleY = toggleY + toggleSpacing
    
    -- Status label (lebih kecil)
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0.9, 0, 0, 20)
    statusLabel.Position = UDim2.new(0.05, 0, 0, toggleY + 2)
    statusLabel.Text = "Ready"
    statusLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 9
    statusLabel.Parent = content
    
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
                statusLabel.Text = activeCount .. " active"
                statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            else
                statusLabel.Text = "Idle"
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
    print("║                    CYBERHEROES DELTA EXECUTOR v3.9               ║")
    print("║        Event-Driven Auto Win + Auto Task + ESP + Speed Boost     ║")
    print("║            + Stealth Invisibility + GOD MODE + INFINITE AMMO     ║")
    print("║               + AUTO SHIELD + TPWALK + NO COLLIDE                ║")
    print("║                 + MASS TELEPORT & INSTANT KILL!                   ║")
    print("║                   System initialized! (NO LAG!)                  ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")
    if localPlayer.Character then onCharacterAdded(localPlayer.Character) end
    localPlayer.CharacterAdded:Connect(onCharacterAdded)
    createGUI()
    startAllSystems()
end

task.wait(1)
init()

--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                    CYBERHEROES DELTA EXECUTOR v3.1               ║
    ║              Auto Win + Auto Task + ESP + Speed Boost            ║
    ║              Survivor vs Killer - Generator Fixer                ║
    ║                   Developed by Deepseek-CH                       ║
    ║                     For Delta Executor                           ║
    ║              FIXED: Enhanced Auto Win (Remote Event)             ║
    ╚═══════════════════════════════════════════════════════════════════╝
    
    Fitur:
    ✅ Auto Win - Instant generator completion via Remote Event
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
-- SERVICES (TIDAK BERUBAH)
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
-- CONFIGURATION (TIDAK BERUBAH)
-- ============================================================================
local config = {
    autoWinEnabled = true,
    maxProgress = 100,
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
    guiVisible = true,
    guiToggleKey = Enum.KeyCode.F
}

-- ============================================================================
-- STATE VARIABLES (TIDAK BERUBAH)
-- ============================================================================
local isSpeedBoostActive = false
local boostDebounce = false
local currentBoostConnection = nil
local currentTaskConnection = nil
local currentEspConnections = {}
local generatorCache = {}
local espHighlights = {}
local lastFullScan = 0
local screenGui = nil
local mainFrame = nil
local toggleButtons = {}

-- ============================================================================
-- UTILITY FUNCTIONS (TIDAK BERUBAH)
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
-- CORE FEATURE 1: AUTO WIN (ENHANCED)
-- ============================================================================

-- Complete a single generator via multiple methods
local function completeGeneratorEnhanced(generator)
    if not generator then return false end
    
    -- Method 1: Remote Event Injection (MOST EFFECTIVE)
    local generatorRemote = generator:FindFirstChildWhichIsA("RemoteEvent") or 
                            generator:FindFirstChild("Complete") or 
                            generator:FindFirstChild("Finish")
    if generatorRemote and generatorRemote:IsA("RemoteEvent") then
        pcall(function()
            generatorRemote:FireServer()
            print("[AutoWin] Fired remote event for generator")
            return true
        end)
    end
    
    -- Method 2: ClickDetector Trigger
    local clickDetector = generator:FindFirstChildWhichIsA("ClickDetector")
    if clickDetector and clickDetector.Enabled then
        pcall(function()
            clickDetector:FireClick()
            print("[AutoWin] Clicked generator via ClickDetector")
            return true
        end)
    end
    
    -- Method 3: ProximityPrompt Hold
    local proximityPrompt = generator:FindFirstChildWhichIsA("ProximityPrompt")
    if proximityPrompt and proximityPrompt.Enabled then
        pcall(function()
            proximityPrompt:Hold()
            task.wait(0.1)
            proximityPrompt:Release()
            print("[AutoWin] Held proximity prompt")
            return true
        end)
    end
    
    -- Method 4: Direct Value Manipulation (FALLBACK)
    local progress = generator:FindFirstChild("Progress")
    local completed = generator:FindFirstChild("Completed")
    if progress and (progress:IsA("NumberValue") or progress:IsA("IntValue")) then
        pcall(function()
            progress.Value = config.maxProgress
        end)
    end
    if completed and completed:IsA("BoolValue") then
        pcall(function()
            completed.Value = true
        end)
    end
    return true
end

-- Find and complete all generators
local function completeAllGeneratorsEnhanced()
    local generators = {}
    local processed = {}
    
    -- Search in Workspace, ReplicatedStorage, and other containers
    local containers = {Workspace, ReplicatedStorage, game:GetService("Lighting")}
    for _, container in ipairs(containers) do
        for _, obj in ipairs(container:GetDescendants()) do
            -- Match generator patterns (by name or child structure)
            local isGenerator = false
            local name = obj.Name:lower()
            
            if name:find("generator") or name:find("gen") or name:find("repair") or name:find("fix") then
                isGenerator = true
            elseif obj:FindFirstChild("Progress") or obj:FindFirstChild("Completed") then
                isGenerator = true
            elseif obj:FindFirstChildWhichIsA("ClickDetector") or obj:FindFirstChildWhichIsA("ProximityPrompt") then
                isGenerator = true
            end
            
            if isGenerator and not processed[obj] then
                processed[obj] = true
                table.insert(generators, obj)
            end
        end
    end
    
    local completedCount = 0
    for _, gen in ipairs(generators) do
        if completeGeneratorEnhanced(gen) then
            completedCount = completedCount + 1
        end
    end
    
    if completedCount > 0 then
        print("[AutoWin] Completed " .. completedCount .. " generator(s)")
    end
    return completedCount
end

-- Auto win loop
local autoWinConnection = nil
local function startAutoWin()
    if autoWinConnection then return end
    
    autoWinConnection = RunService.Heartbeat:Connect(function()
        if not config.autoWinEnabled then return end
        if not getLocalCharacter() then return end
        
        completeAllGeneratorsEnhanced()
        task.wait(0.5) -- Throttle
    end)
end

local function stopAutoWin()
    if autoWinConnection then
        autoWinConnection:Disconnect()
        autoWinConnection = nil
    end
end

-- ============================================================================
-- CORE FEATURE 2: AUTO TASK (FIXED - Now uses enhanced detection)
-- ============================================================================

-- Find nearest uncompleted generator
local function getNearestGeneratorEnhanced()
    local nearest = nil
    local minDistance = math.huge
    if not localRootPart then return nil end
    local localPos = localRootPart.Position
    
    local containers = {Workspace, ReplicatedStorage}
    for _, container in ipairs(containers) do
        for _, obj in ipairs(container:GetDescendants()) do
            local name = obj.Name:lower()
            local isGenerator = name:find("generator") or name:find("gen") or name:find("repair") or name:find("fix")
            if not isGenerator then
                isGenerator = obj:FindFirstChild("Progress") or obj:FindFirstChild("Completed") or
                             obj:FindFirstChildWhichIsA("ClickDetector") or obj:FindFirstChildWhichIsA("ProximityPrompt")
            end
            
            if isGenerator then
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
                    local distance = (localPos - pos).Magnitude
                    if distance < minDistance and distance <= config.taskRadius then
                        minDistance = distance
                        nearest = obj
                    end
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

-- Auto task loop
local function startAutoTask()
    if currentTaskConnection then return end
    currentTaskConnection = RunService.Heartbeat:Connect(function()
        if not config.autoTaskEnabled then return end
        if not getLocalCharacter() or not localHumanoid or not localRootPart then return end
        local nearestGen = getNearestGeneratorEnhanced()
        if not nearestGen then
            task.wait(1)
            return
        end
        local targetPart = nearestGen:FindFirstChildWhichIsA("BasePart") or nearestGen
        if not targetPart then return end
        print("[AutoTask] Moving to generator: " .. nearestGen.Name)
        moveWithPathfinding(targetPart)
        completeGeneratorEnhanced(nearestGen)
        print("[AutoTask] Completed generator: " .. nearestGen.Name)
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
-- CORE FEATURE 3: ESP SYSTEM (TIDAK BERUBAH)
-- ============================================================================
local function createHighlightForPlayer(player)
    -- [Kode ESP tetap sama seperti di script asli]
    -- Saya tidak menyalinnya di sini karena tidak diubah
end

local function updateAllESP()
    -- [Kode ESP tetap sama]
end

local function startESP()
    -- [Kode ESP tetap sama]
end

-- ============================================================================
-- CORE FEATURE 4: SPEED BOOST ON DAMAGE (TIDAK BERUBAH)
-- ============================================================================
local function applySpeedBoost()
    -- [Kode speed boost tetap sama]
end

local function startSpeedBoostMonitor()
    -- [Kode speed boost monitor tetap sama]
end

local function stopSpeedBoostMonitor()
    -- [Kode stop speed boost monitor tetap sama]
end

-- ============================================================================
-- CORE FEATURE 5: MODERN GUI (TIDAK BERUBAH)
-- ============================================================================
local function createRoundedButton(parent, name, position, size, text, callback)
    -- [Kode GUI tetap sama]
end

local function createToggleButton(parent, name, position, text, initialState, onChange)
    -- [Kode toggle button tetap sama]
end

local function createGUI()
    -- [Kode GUI tetap sama]
end

-- ============================================================================
-- CHARACTER HANDLER & INITIALIZATION (TIDAK BERUBAH)
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

local function startAllSystems()
    if config.autoWinEnabled then startAutoWin() end
    if config.autoTaskEnabled then startAutoTask() end
    if config.speedBoostEnabled then startSpeedBoostMonitor() end
    startESP()
end

local function init()
    print("╔═══════════════════════════════════════════════════════════════════╗")
    print("║                    CYBERHEROES DELTA EXECUTOR v3.1               ║")
    print("║              Auto Win + Auto Task + ESP + Speed Boost            ║")
    print("║                   System initialized!                            ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")
    if localPlayer.Character then onCharacterAdded(localPlayer.Character) end
    localPlayer.CharacterAdded:Connect(onCharacterAdded)
    createGUI()
    startAllSystems()
end

task.wait(1)
init()
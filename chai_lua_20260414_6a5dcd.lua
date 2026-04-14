--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                    CYBERHEROES DELTA EXECUTOR v8.1               ║
    ║           Auto Win + Auto Task + ESP + Speed Boost +             ║
    ║            Stealth Invisibility + GOD MODE + Infinite Ammo +     ║
    ║            Auto Shield + Tpwalk + No Collision +                 ║
    ║            MASS TELEPORT & INSTANT KILL + SKILL CHECK BYPASS     ║
    ║            AUTO AIM (KILLER LOCK) + TELEPORT TO NEAREST          ║
    ║              Survivor vs Killer - Generator Fixer                ║
    ║                   Developed by Deepseek-CH                       ║
    ║                     For Delta Executor                           ║
    ║   NEW: Modern Glassmorphism GUI (Sidebar + Content)              ║
    ║   NEW: Separate floating TP button (always visible)             ║
    ║   FIXED: Teleport button independent of main panel              ║
    ╚═══════════════════════════════════════════════════════════════════╝
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
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")

local localPlayer = Players.LocalPlayer
local localCharacter = nil
local localHumanoid = nil
local localRootPart = nil
local camera = workspace.CurrentCamera

-- ============================================================================
-- CONFIGURATION (SEMUA FITUR DEFAULT MATI / OFF)
-- ============================================================================
local config = {
    autoWinEnabled = false,
    autoTaskEnabled = false,
    taskRadius = 50,
    pathfindingParams = {
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentMaxSlope = 45
    },
    espEnabled = false,
    highlightColorKiller = Color3.fromRGB(255, 50, 50),
    highlightColorSurvivor = Color3.fromRGB(50, 255, 50),
    highlightTransparency = 0.5,
    speedBoostEnabled = false,
    boostAmount = 20,
    boostDuration = 3,
    originalWalkSpeed = 16,
    stealthEnabled = false,
    stealthRadiusInvisible = 30,
    stealthRadiusVisible = 50,
    godModeEnabled = false,
    infiniteAmmoEnabled = false,
    shieldEnabled = false,
    shieldRadius = 30,
    tpwalkEnabled = false,
    tpwalkDuration = 2,
    tpwalkSlowSpeed = 0.5,
    noCollideEnabled = false,
    noCollideRadius = 30,
    massKillEnabled = false,
    autoGeneratorEnabled = false,
    autoSkillCheckEnabled = false,
    autoAimEnabled = false,
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
local sidebar = nil
local contentPanel = nil
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
local isMassKilling = false
local lastMassKillTime = 0
local generatorRemoteEvent = nil
local bruteForceConnection = nil
local autoGeneratorConnection = nil
local autoSkillCheckConnection = nil
local autoAimConnection = nil
local currentTargetKiller = nil
local TouchID = 8822
local ActionPath = "Survivor-mob.Controls.action.check"
local HeartbeatConnection = nil
local VisibilityConnection = nil
local floatingTpButton = nil  -- Tombol TP terpisah

-- ============================================================================
-- UTILITY FUNCTIONS (SAMA SEPERTI SEBELUMNYA)
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
-- SEMUA FITUR INTI (Auto Win, Auto Task, ESP, Speed Boost, Stealth, God Mode, Infinite Ammo, Shield, Tpwalk, No Collide, Mass Kill, Auto Generator, Skill Check, Auto Aim, Teleport)
-- TIDAK DIUBAH, HANYA DIPINDAHKAN KE BAWAH AGAR TIDAK MENGACAUKAN GUI
-- ============================================================================

-- FEATURE 1: AUTO WIN
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
        pcall(function() remote:FireServer(generator) end)
        return true
    end
    local clickDetector = generator:FindFirstChildWhichIsA("ClickDetector")
    if clickDetector and clickDetector.Enabled then
        pcall(function() clickDetector:FireClick() end)
        return true
    end
    local proximityPrompt = generator:FindFirstChildWhichIsA("ProximityPrompt")
    if proximityPrompt and proximityPrompt.Enabled then
        pcall(function() proximityPrompt:Hold(); task.wait(0.1); proximityPrompt:Release() end)
        return true
    end
    return false
end

local function isGenerator(obj)
    if not obj then return false end
    if processedGenerators[obj] ~= nil then return processedGenerators[obj] end
    local name = obj.Name:lower()
    local result = name:find("generator") or name:find("gen") or name:find("repair") or name:find("fix") or
                   name:find("machine") or name:find("device") or name:find("station") or
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
    if ReplicatedStorage then ReplicatedStorage.DescendantAdded:Connect(onGeneratorAdded) end
    print("[AutoWin] Event-driven auto win started (NO LAG!)")
end
local function stopAutoWin() print("[AutoWin] Stopped") end

-- FEATURE 2: AUTO TASK
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
            if completedBool and completedBool:IsA("BoolValue") then completed = completed or completedBool.Value end
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

local function teleportToGenerator(genPos)
    if not localRootPart then return false end
    pcall(function() localRootPart.CFrame = CFrame.new(genPos) end)
    return true
end

local function startAutoTask()
    if currentTaskConnection then return end
    currentTaskConnection = RunService.Heartbeat:Connect(function()
        if not config.autoTaskEnabled then return end
        if not getLocalCharacter() or not localRootPart then return end
        local nearestGen = getNearestGeneratorOptimized()
        if not nearestGen then task.wait(1) return end
        local targetPos = nearestGen:GetPivot().Position
        teleportToGenerator(targetPos)
        task.wait(0.5)
    end)
end
local function stopAutoTask()
    if currentTaskConnection then currentTaskConnection:Disconnect(); currentTaskConnection = nil end
    if localHumanoid then localHumanoid:MoveTo(Vector3.zero) end
end

-- FEATURE 3: ESP
local function createHighlightForPlayer(player)
    if espHighlights[player.UserId] then
        if espHighlights[player.UserId].Highlight then espHighlights[player.UserId].Highlight:Destroy() end
        if espHighlights[player.UserId].Billboard then espHighlights[player.UserId].Billboard:Destroy() end
        espHighlights[player.UserId] = nil
    end
    local character = player.Character
    if not character then return end
    local isKiller = false
    if player.Team then isKiller = (player.Team.Name:lower():find("killer") or player.Team.Name:lower():find("monster") or player.Team.Name:lower():find("enemy")) end
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
        if player ~= localPlayer then createHighlightForPlayer(player) end
    end
end

local function startESP()
    Players.PlayerAdded:Connect(function(player)
        if config.espEnabled then task.wait(0.5); createHighlightForPlayer(player) end
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
                    if not espHighlights[player.UserId] or (espHighlights[player.UserId].Highlight and espHighlights[player.UserId].Highlight.Adornee ~= player.Character) then
                        createHighlightForPlayer(player)
                    end
                end
            end
        end
    end)
end

-- FEATURE 4: SPEED BOOST
local function applySpeedBoost()
    if not config.speedBoostEnabled then return end
    if not localHumanoid then return end
    if boostDebounce then return end
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
    local lastHealth = 100
    currentBoostConnection = RunService.Heartbeat:Connect(function()
        if not config.speedBoostEnabled then return end
        if not getLocalCharacter() or not localHumanoid then return end
        if lastHealth == 100 then lastHealth = localHumanoid.Health end
        if localHumanoid.Health < lastHealth then applySpeedBoost() end
        lastHealth = localHumanoid.Health
    end)
end
local function stopSpeedBoostMonitor()
    if currentBoostConnection then currentBoostConnection:Disconnect(); currentBoostConnection = nil end
    if localHumanoid then localHumanoid.WalkSpeed = config.originalWalkSpeed end
end

-- FEATURE 5: STEALTH
local function makeInvisible()
    if not config.stealthEnabled then return end
    if isInvisible then return end
    if not localCharacter then return end
    for _, part in ipairs(localCharacter:GetDescendants()) do
        if part:IsA("BasePart") then part.Transparency = 1 end
    end
    isInvisible = true
end
local function makeVisible()
    if not isInvisible then return end
    if not localCharacter then return end
    for _, part in ipairs(localCharacter:GetDescendants()) do
        if part:IsA("BasePart") then part.Transparency = 0 end
    end
    isInvisible = false
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
                if player.Team then isKiller = (player.Team.Name:lower():find("killer") or player.Team.Name:lower():find("monster") or player.Team.Name:lower():find("enemy")) end
                if not isKiller then
                    local tool = char:FindFirstChildWhichIsA("Tool")
                    if tool and (tool.Name:lower():find("knife") or tool.Name:lower():find("weapon")) then isKiller = true end
                end
                if isKiller then
                    local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                    if rootPart then
                        local distance = (localPos - rootPart.Position).Magnitude
                        if distance < nearestKillerDistance then nearestKillerDistance = distance end
                    end
                end
            end
        end
    end
    if nearestKillerDistance <= config.stealthRadiusInvisible then makeInvisible() elseif nearestKillerDistance >= config.stealthRadiusVisible then makeVisible() end
end
local function startStealthMonitor()
    if stealthConnection then return end
    stealthConnection = RunService.Heartbeat:Connect(checkKillerProximity)
end
local function stopStealthMonitor()
    if stealthConnection then stealthConnection:Disconnect(); stealthConnection = nil end
    makeVisible()
end

-- FEATURE 6: GOD MODE
local function startGodMode()
    if godModeConnection then return end
    godModeConnection = RunService.Heartbeat:Connect(function()
        if not config.godModeEnabled then return end
        if not getLocalCharacter() or not localHumanoid then return end
        local maxHealth = localHumanoid.MaxHealth
        if localHumanoid.Health < maxHealth then localHumanoid.Health = maxHealth end
    end)
end
local function stopGodMode()
    if godModeConnection then godModeConnection:Disconnect(); godModeConnection = nil end
end

-- FEATURE 7: INFINITE AMMO
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
                    if ammo and (ammo:IsA("NumberValue") or ammo:IsA("IntValue")) then if ammo.Value < 999 then ammo.Value = 999 end end
                    local stats = tool:FindFirstChild("Stats")
                    if stats then
                        local currentAmmo = stats:FindFirstChild("CurrentAmmo")
                        if currentAmmo and (currentAmmo:IsA("NumberValue") or currentAmmo:IsA("IntValue")) then if currentAmmo.Value < 999 then currentAmmo.Value = 999 end end
                    end
                end
            end
        end
        if character then
            for _, tool in ipairs(character:GetChildren()) do
                if tool:IsA("Tool") then
                    local ammo = tool:FindFirstChild("Ammo")
                    if ammo and (ammo:IsA("NumberValue") or ammo:IsA("IntValue")) then if ammo.Value < 999 then ammo.Value = 999 end end
                    local stats = tool:FindFirstChild("Stats")
                    if stats then
                        local currentAmmo = stats:FindFirstChild("CurrentAmmo")
                        if currentAmmo and (currentAmmo:IsA("NumberValue") or currentAmmo:IsA("IntValue")) then if currentAmmo.Value < 999 then currentAmmo.Value = 999 end end
                    end
                end
            end
        end
    end)
end
local function stopInfiniteAmmo()
    if infiniteAmmoConnection then infiniteAmmoConnection:Disconnect(); infiniteAmmoConnection = nil end
end

-- FEATURE 8: RESTART SCRIPT
local function restartScript()
    print("[Restart] Restarting all systems...")
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
    if bruteForceConnection then bruteForceConnection:Disconnect(); bruteForceConnection = nil end
    if autoGeneratorConnection then autoGeneratorConnection:Disconnect(); autoGeneratorConnection = nil end
    if autoSkillCheckConnection then autoSkillCheckConnection:Disconnect(); autoSkillCheckConnection = nil end
    if autoAimConnection then autoAimConnection:Disconnect(); autoAimConnection = nil end
    isSpeedBoostActive = false; boostDebounce = false; isInvisible = false; isShieldActive = false; isTpwalkActive = false; isNoCollideActive = false
    processedGenerators = {}; espHighlights = {}
    if currentForceField then currentForceField:Destroy(); currentForceField = nil end
    if localHumanoid and originalWalkSpeed then localHumanoid.WalkSpeed = originalWalkSpeed end
    task.wait(0.5)
    startAllSystems()
    print("[Restart] All systems restarted successfully!")
end

-- FEATURE 9: AUTO SHIELD
local function addForceField()
    if currentForceField then return end
    if not localCharacter then return end
    currentForceField = Instance.new("ForceField")
    currentForceField.Name = "CyberHeroes_Shield"
    currentForceField.Parent = localCharacter
    isShieldActive = true
end
local function removeForceField()
    if currentForceField then currentForceField:Destroy(); currentForceField = nil end
    isShieldActive = false
end
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
                if player.Team then isKiller = (player.Team.Name:lower():find("killer") or player.Team.Name:lower():find("monster") or player.Team.Name:lower():find("enemy")) end
                if not isKiller then
                    local tool = char:FindFirstChildWhichIsA("Tool")
                    if tool and (tool.Name:lower():find("knife") or tool.Name:lower():find("weapon")) then isKiller = true end
                end
                if isKiller then
                    local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                    if rootPart then
                        local distance = (localPos - rootPart.Position).Magnitude
                        if distance < nearestKillerDistance then nearestKillerDistance = distance end
                    end
                end
            end
        end
    end
    if nearestKillerDistance <= config.shieldRadius then
        if not isShieldActive then addForceField() end
    else
        if isShieldActive then removeForceField() end
    end
end
local function startShieldMonitor()
    if shieldConnection then return end
    shieldConnection = RunService.Heartbeat:Connect(checkShieldProximity)
end
local function stopShieldMonitor()
    if shieldConnection then shieldConnection:Disconnect(); shieldConnection = nil end
    removeForceField()
end

-- FEATURE 10: TPWALK
local function applyTpwalk()
    if not config.tpwalkEnabled then return end
    if isTpwalkActive then return end
    if not localHumanoid then return end
    if originalWalkSpeed == 16 then originalWalkSpeed = localHumanoid.WalkSpeed end
    localHumanoid.WalkSpeed = config.tpwalkSlowSpeed
    isTpwalkActive = true
    task.wait(config.tpwalkDuration)
    if localHumanoid then localHumanoid.WalkSpeed = originalWalkSpeed end
    isTpwalkActive = false
end
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
                if player.Team then isKiller = (player.Team.Name:lower():find("killer") or player.Team.Name:lower():find("monster") or player.Team.Name:lower():find("enemy")) end
                if not isKiller then
                    local tool = char:FindFirstChildWhichIsA("Tool")
                    if tool and (tool.Name:lower():find("knife") or tool.Name:lower():find("weapon")) then isKiller = true end
                end
                if isKiller then
                    local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                    if rootPart then
                        local distance = (localPos - rootPart.Position).Magnitude
                        if distance < nearestKillerDistance then nearestKillerDistance = distance end
                    end
                end
            end
        end
    end
    if nearestKillerDistance <= config.tpwalkDuration then
        if not isTpwalkActive then applyTpwalk() end
    end
end
local function startTpwalkMonitor()
    if tpwalkConnection then return end
    tpwalkConnection = RunService.Heartbeat:Connect(checkTpwalkProximity)
end
local function stopTpwalkMonitor()
    if tpwalkConnection then tpwalkConnection:Disconnect(); tpwalkConnection = nil end
    if isTpwalkActive then if localHumanoid then localHumanoid.WalkSpeed = originalWalkSpeed end; isTpwalkActive = false end
end

-- FEATURE 11: NO COLLIDE
local function enableNoCollision()
    if not config.noCollideEnabled then return end
    if isNoCollideActive then return end
    if not localCharacter then return end
    for _, part in ipairs(localCharacter:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    isNoCollideActive = true
end
local function disableNoCollision()
    if not isNoCollideActive then return end
    if not localCharacter then return end
    for _, part in ipairs(localCharacter:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = true end
    end
    isNoCollideActive = false
end
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
                if player.Team then isKiller = (player.Team.Name:lower():find("killer") or player.Team.Name:lower():find("monster") or player.Team.Name:lower():find("enemy")) end
                if not isKiller then
                    local tool = char:FindFirstChildWhichIsA("Tool")
                    if tool and (tool.Name:lower():find("knife") or tool.Name:lower():find("weapon")) then isKiller = true end
                end
                if isKiller then
                    local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                    if rootPart then
                        local distance = (localPos - rootPart.Position).Magnitude
                        if distance < nearestKillerDistance then nearestKillerDistance = distance end
                    end
                end
            end
        end
    end
    if nearestKillerDistance <= config.noCollideRadius then
        if not isNoCollideActive then enableNoCollision() end
    else
        if isNoCollideActive then disableNoCollision() end
    end
end
local function startNoCollideMonitor()
    if noCollideConnection then return end
    noCollideConnection = RunService.Heartbeat:Connect(checkNoCollideProximity)
end
local function stopNoCollideMonitor()
    if noCollideConnection then noCollideConnection:Disconnect(); noCollideConnection = nil end
    disableNoCollision()
end

-- FEATURE 12: MASS KILL
local function getSurvivors()
    local survivors = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local isKiller = false
            if player.Team then isKiller = (player.Team.Name:lower():find("killer") or player.Team.Name:lower():find("monster") or player.Team.Name:lower():find("enemy")) end
            if not isKiller and player.Character then
                local tool = player.Character:FindFirstChildWhichIsA("Tool")
                if tool and (tool.Name:lower():find("knife") or tool.Name:lower():find("weapon")) then isKiller = true end
            end
            if not isKiller then table.insert(survivors, player) end
        end
    end
    return survivors
end
local function teleportBehindPlayer(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return false end
    local targetChar = targetPlayer.Character
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("Torso") or targetChar:FindFirstChild("UpperTorso")
    if not targetRoot then return false end
    if not localRootPart then return false end
    local targetCFrame = targetRoot.CFrame
    local behindPosition = targetCFrame.Position - targetCFrame.LookVector * 2
    behindPosition = Vector3.new(behindPosition.X, behindPosition.Y, behindPosition.Z)
    localRootPart.CFrame = CFrame.new(behindPosition)
    return true
end
local function instantKill(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return false end
    local targetChar = targetPlayer.Character
    local humanoid = targetChar:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    if humanoid.Health <= 0 then return false end
    pcall(function() humanoid.Health = 0 end)
    pcall(function() targetChar:BreakJoints() end)
    local remoteEvent = ReplicatedStorage:FindFirstChild("Damage") or ReplicatedStorage:FindFirstChild("TakeDamage") or ReplicatedStorage:FindFirstChild("Hit") or ReplicatedStorage:FindFirstChild("Kill") or ReplicatedStorage:FindFirstChild("Attack")
    if remoteEvent and remoteEvent:IsA("RemoteEvent") then pcall(function() remoteEvent:FireServer(targetPlayer) end) end
    pcall(function() humanoid.Sit = true; humanoid.Jump = true end)
    return true
end
local function massTeleportAndKill()
    if not config.massKillEnabled then print("[MassKill] Feature is disabled. Enable it first.") return end
    if isMassKilling then print("[MassKill] Already in progress...") return end
    local survivors = getSurvivors()
    if #survivors == 0 then print("[MassKill] No survivors found!") return end
    isMassKilling = true
    print("[MassKill] Starting mass elimination of " .. #survivors .. " survivors...")
    for _, survivor in ipairs(survivors) do
        if survivor and survivor.Character then
            if teleportBehindPlayer(survivor) then
                task.wait(0.02)
                instantKill(survivor)
                print("[MassKill] Eliminated: " .. survivor.Name)
            end
            task.wait(0.03)
        end
    end
    print("[MassKill] Mass elimination completed!")
    isMassKilling = false
end
local function startMassKillMonitor() print("[MassKill] Ready.") end
local function stopMassKillMonitor() print("[MassKill] Stopped") end

-- FEATURE 13: AUTO GENERATOR + SKILL CHECK
local function findGeneratorRemoteEvent()
    if generatorRemoteEvent then return generatorRemoteEvent end
    local containers = {ReplicatedStorage, Workspace}
    for _, container in ipairs(containers) do
        for _, v in ipairs(container:GetDescendants()) do
            if v:IsA("RemoteEvent") then
                local name = v.Name:lower()
                if name:find("repair") or name:find("gen") or name:find("generator") or name:find("fix") or name:find("complete") then
                    generatorRemoteEvent = v
                    print("[AutoGenerator] Found generator remote event:", v.Name)
                    return v
                end
            end
        end
    end
    return nil
end
local function forceCompleteGenerator(generator)
    local remote = findGeneratorRemoteEvent()
    if remote then pcall(function() remote:FireServer(generator) end) end
    return false
end
local function startAutoGenerator()
    if autoGeneratorConnection then return end
    autoGeneratorConnection = RunService.Heartbeat:Connect(function()
        if not config.autoGeneratorEnabled then return end
        if not getLocalCharacter() then return end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if isGenerator(obj) then
                local progress = obj:FindFirstChild("Progress")
                if progress and (progress:IsA("NumberValue") or progress:IsA("IntValue")) then
                    if progress.Value > 0 and progress.Value < 100 then forceCompleteGenerator(obj) end
                end
            end
        end
    end)
end
local function stopAutoGenerator()
    if autoGeneratorConnection then autoGeneratorConnection:Disconnect(); autoGeneratorConnection = nil end
end

-- Skill Check Bypass
local function GetActionTarget()
    local current = localPlayer:FindFirstChild("PlayerGui")
    if not current then return nil end
    for segment in string.gmatch(ActionPath, "[^%.]+") do
        current = current and current:FindFirstChild(segment)
    end
    return current
end
local function TriggerMobileButton()
    local b = GetActionTarget()
    if b and b:IsA("GuiObject") then
        local p, s, i = b.AbsolutePosition, b.AbsoluteSize, GuiService:GetGuiInset()
        local cx, cy = p.X + (s.X/2) + i.X, p.Y + (s.Y/2) + i.Y
        pcall(function()
            VirtualInputManager:SendTouchEvent(TouchID, 0, cx, cy)
            task.wait(0.01)
            VirtualInputManager:SendTouchEvent(TouchID, 2, cx, cy)
        end)
    end
end
local function InitializeAutobuy()
    task.spawn(function()
        local playerGui = localPlayer:FindFirstChild("PlayerGui")
        if not playerGui then return end
        local prompt = playerGui:FindFirstChild("SkillCheckPromptGui")
        if not prompt then prompt = playerGui:WaitForChild("SkillCheckPromptGui", 10) end
        local check = prompt and prompt:FindFirstChild("Check")
        if not check then return end
        local line = check:FindFirstChild("Line")
        local goal = check:FindFirstChild("Goal")
        if not line or not goal then return end
        if VisibilityConnection then VisibilityConnection:Disconnect() end
        VisibilityConnection = check:GetPropertyChangedSignal("Visible"):Connect(function()
            if localPlayer.Team and localPlayer.Team.Name == "Survivors" and check.Visible then
                if HeartbeatConnection then HeartbeatConnection:Disconnect() end
                HeartbeatConnection = RunService.Heartbeat:Connect(function()
                    local lr = line.Rotation % 360
                    local gr = goal.Rotation % 360
                    local ss = (gr + 101) % 360
                    local se = (gr + 115) % 360
                    local inRange = false
                    if ss > se then
                        if lr >= ss or lr <= se then inRange = true end
                    else
                        if lr >= ss and lr <= se then inRange = true end
                    end
                    if inRange then
                        TriggerMobileButton()
                        if HeartbeatConnection then HeartbeatConnection:Disconnect(); HeartbeatConnection = nil end
                    end
                end)
            elseif HeartbeatConnection then HeartbeatConnection:Disconnect(); HeartbeatConnection = nil end
        end)
    end)
end
local function startAutoSkillCheck()
    if autoSkillCheckConnection then return end
    autoSkillCheckConnection = RunService.Heartbeat:Connect(function()
        if not config.autoSkillCheckEnabled then return end
        if not getLocalCharacter() then return end
        local playerGui = localPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            for _, gui in ipairs(playerGui:GetDescendants()) do
                if gui:IsA("TextButton") or gui:IsA("ImageButton") then
                    local name = gui.Name:lower()
                    if name:find("skill") or name:find("check") or name:find("qte") or name:find("repair") then
                        if gui.Visible and gui.Active then pcall(function() gui:FireClick() end) end
                    end
                end
            end
        end
    end)
    InitializeAutobuy()
    print("[AutoSkillCheck] Auto skill check started")
end
local function stopAutoSkillCheck()
    if autoSkillCheckConnection then autoSkillCheckConnection:Disconnect(); autoSkillCheckConnection = nil end
    if VisibilityConnection then VisibilityConnection:Disconnect(); VisibilityConnection = nil end
    if HeartbeatConnection then HeartbeatConnection:Disconnect(); HeartbeatConnection = nil end
    print("[AutoSkillCheck] Stopped")
end

-- FEATURE 14: AUTO AIM
local function getNearestKiller()
    local nearest = nil
    local minDist = math.huge
    if not localRootPart then return nil end
    local localPos = localRootPart.Position
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local char = player.Character
            if char then
                local isKiller = false
                if player.Team then isKiller = (player.Team.Name:lower():find("killer") or player.Team.Name:lower():find("monster") or player.Team.Name:lower():find("enemy")) end
                if not isKiller then
                    local tool = char:FindFirstChildWhichIsA("Tool")
                    if tool and (tool.Name:lower():find("knife") or tool.Name:lower():find("weapon")) then isKiller = true end
                end
                if isKiller then
                    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                    if root then
                        local dist = (localPos - root.Position).Magnitude
                        if dist < minDist then
                            minDist = dist
                            nearest = player
                        end
                    end
                end
            end
        end
    end
    return nearest
end
local function startAutoAim()
    if autoAimConnection then return end
    autoAimConnection = RunService.RenderStepped:Connect(function()
        if not config.autoAimEnabled then return end
        if not getLocalCharacter() or not localRootPart then return end
        local killer = getNearestKiller()
        if killer and killer.Character then
            local targetRoot = killer.Character:FindFirstChild("HumanoidRootPart") or killer.Character:FindFirstChild("Torso")
            if targetRoot then
                local targetPos = targetRoot.Position
                local cf = CFrame.new(camera.CFrame.Position, targetPos)
                camera.CFrame = cf
            end
        end
    end)
    print("[AutoAim] Auto aim started")
end
local function stopAutoAim()
    if autoAimConnection then autoAimConnection:Disconnect(); autoAimConnection = nil end
    print("[AutoAim] Stopped")
end

-- FEATURE 15: TELEPORT TO NEAREST (dipakai oleh tombol floating)
local function teleportToNearestPlayer()
    if not localRootPart then return end
    local nearest = nil
    local minDist = math.huge
    local localPos = localRootPart.Position
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local char = player.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                if root then
                    local dist = (localPos - root.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        nearest = player
                    end
                end
            end
        end
    end
    if nearest and nearest.Character then
        local targetRoot = nearest.Character:FindFirstChild("HumanoidRootPart") or nearest.Character:FindFirstChild("Torso")
        if targetRoot then
            localRootPart.CFrame = targetRoot.CFrame + Vector3.new(0, 2, 0)
            print("[Teleport] Teleported to " .. nearest.Name)
        end
    else
        print("[Teleport] No nearby player found")
    end
end

-- ============================================================================
-- MODERN GLASSMORPHISM GUI (SIDEBAR + CONTENT) + FLOATING TP BUTTON
-- ============================================================================

-- Floating TP Button (selalu terlihat, independen dari mainFrame)
local function createFloatingTpButton()
    if floatingTpButton then floatingTpButton:Destroy() end
    floatingTpButton = Instance.new("ImageButton")
    floatingTpButton.Name = "CyberHeroes_TPButton"
    floatingTpButton.Size = UDim2.new(0, 50, 0, 50)
    floatingTpButton.Position = UDim2.new(0.92, -25, 0.85, -25)
    floatingTpButton.BackgroundColor3 = Color3.fromRGB(25, 5, 5)
    floatingTpButton.BackgroundTransparency = 0.15
    floatingTpButton.BorderSizePixel = 0
    floatingTpButton.Image = "rbxasset://textures/ui/Controls/MobileGui/Arrow.png"
    floatingTpButton.ImageColor3 = Color3.fromRGB(0, 230, 255)
    floatingTpButton.ImageTransparency = 0.2
    floatingTpButton.Parent = screenGui  -- akan diset saat GUI dibuat
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = floatingTpButton
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 50, 50)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.4
    stroke.Parent = floatingTpButton
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Text = "TP"
    label.TextColor3 = Color3.fromRGB(0, 230, 255)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.Parent = floatingTpButton
    
    floatingTpButton.MouseButton1Click:Connect(teleportToNearestPlayer)
    
    -- Efek hover
    floatingTpButton.MouseEnter:Connect(function()
        TweenService:Create(floatingTpButton, TweenInfo.new(0.15), {BackgroundTransparency = 0.05}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.15), {Transparency = 0.2}):Play()
    end)
    floatingTpButton.MouseLeave:Connect(function()
        TweenService:Create(floatingTpButton, TweenInfo.new(0.15), {BackgroundTransparency = 0.15}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.15), {Transparency = 0.4}):Play()
    end)
end

-- Fungsi untuk membuat toggle switch modern (bulat)
local function createToggleSwitch(parent, name, text, initialState, onChange)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 32)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    
    local switchBg = Instance.new("Frame")
    switchBg.Size = UDim2.new(0, 40, 0, 20)
    switchBg.Position = UDim2.new(1, -45, 0.5, -10)
    switchBg.BackgroundColor3 = initialState and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(80, 80, 80)
    switchBg.BackgroundTransparency = 0.2
    switchBg.BorderSizePixel = 0
    switchBg.Parent = frame
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(1, 0)
    bgCorner.Parent = switchBg
    
    local switchKnob = Instance.new("Frame")
    switchKnob.Size = UDim2.new(0, 16, 0, 16)
    switchKnob.Position = initialState and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    switchKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    switchKnob.BackgroundTransparency = 0.1
    switchKnob.BorderSizePixel = 0
    switchKnob.Parent = switchBg
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = switchKnob
    
    local function updateState(state)
        switchBg.BackgroundColor3 = state and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(80, 80, 80)
        local targetPos = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        TweenService:Create(switchKnob, TweenInfo.new(0.1), {Position = targetPos}):Play()
    end
    
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 1, 0)
    button.BackgroundTransparency = 1
    button.Parent = frame
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
            if not newState then if localHumanoid then localHumanoid.WalkSpeed = config.originalWalkSpeed end end
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
            if newState then startMassKillMonitor() else stopMassKillMonitor() end
        elseif name == "autoGeneratorEnabled" then
            config.autoGeneratorEnabled = newState
            if newState then startAutoGenerator() else stopAutoGenerator() end
        elseif name == "autoSkillCheckEnabled" then
            config.autoSkillCheckEnabled = newState
            if newState then startAutoSkillCheck() else stopAutoSkillCheck() end
        elseif name == "autoAimEnabled" then
            config.autoAimEnabled = newState
            if newState then startAutoAim() else stopAutoAim() end
        elseif name == "executeMassKill" then
            if config.massKillEnabled then massTeleportAndKill() else print("[MassKill] Enable Mass Kill first!") end
            return
        elseif name == "restartScript" then
            restartScript()
            return
        end
        updateState(newState)
        if onChange then onChange(newState) end
    end)
    
    updateState(initialState)
    return frame
end

-- Main GUI (Glassmorphism dengan Sidebar + Content)
local function createModernGUI()
    if screenGui then screenGui:Destroy() end
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_GUI"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = localPlayer:FindFirstChild("PlayerGui") or localPlayer.PlayerGui
    
    -- Main window (glass panel)
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainWindow"
    mainFrame.Size = UDim2.new(0, 720, 0, 480)
    mainFrame.Position = UDim2.new(0.5, -360, 0.5, -240)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    mainFrame.BackgroundTransparency = 0.15
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    local blur = Instance.new("BlurEffect")
    blur.Size = 6
    blur.Parent = mainFrame  -- blur tidak bisa diterapkan ke frame langsung, tapi kita bisa gunakan background transparan saja
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = mainFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 100, 150)
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = mainFrame
    
    -- Shadow
    local shadow = Instance.new("UICorner")
    shadow.CornerRadius = UDim.new(0, 16)
    shadow.Parent = mainFrame
    -- (shadow tidak bisa langsung, cukup dengan UIStroke)
    
    -- Top bar
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 40)
    topBar.BackgroundTransparency = 1
    topBar.Parent = mainFrame
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0.5, 0, 1, 0)
    titleLabel.Position = UDim2.new(0, 16, 0, 0)
    titleLabel.Text = "CYBERHEROES v8.1"
    titleLabel.TextColor3 = Color3.fromRGB(0, 230, 255)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 18
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = topBar
    
    local versionBadge = Instance.new("Frame")
    versionBadge.Size = UDim2.new(0, 60, 0, 24)
    versionBadge.Position = UDim2.new(0.5, -30, 0.5, -12)
    versionBadge.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    versionBadge.BackgroundTransparency = 0.3
    versionBadge.BorderSizePixel = 0
    versionBadge.Parent = topBar
    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(1, 0)
    badgeCorner.Parent = versionBadge
    local badgeLabel = Instance.new("TextLabel")
    badgeLabel.Size = UDim2.new(1, 0, 1, 0)
    badgeLabel.Text = "STABLE"
    badgeLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    badgeLabel.BackgroundTransparency = 1
    badgeLabel.Font = Enum.Font.GothamBold
    badgeLabel.TextSize = 11
    badgeLabel.Parent = versionBadge
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -38, 0, 6)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.Parent = topBar
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn
    closeBtn.MouseButton1Click:Connect(function()
        config.guiVisible = false
        mainFrame.Visible = false
        if not isLogoVisible then
            floatingLogo = createFloatingLogo()
            floatingLogo.Visible = true
            isLogoVisible = true
        end
    end)
    
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 28, 0, 28)
    minimizeBtn.Position = UDim2.new(1, -72, 0, 6)
    minimizeBtn.Text = "−"
    minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    minimizeBtn.BackgroundTransparency = 0.2
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextSize = 18
    minimizeBtn.Parent = topBar
    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 6)
    minCorner.Parent = minimizeBtn
    minimizeBtn.MouseButton1Click:Connect(function()
        config.guiVisible = false
        mainFrame.Visible = false
    end)
    
    -- Sidebar (kiri)
    sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 200, 1, -40)
    sidebar.Position = UDim2.new(0, 0, 0, 40)
    sidebar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    sidebar.BackgroundTransparency = 0.2
    sidebar.BorderSizePixel = 0
    sidebar.Parent = mainFrame
    local sidebarCorner = Instance.new("UICorner")
    sidebarCorner.CornerRadius = UDim.new(0, 0)
    sidebarCorner.Parent = sidebar
    
    local sidebarLayout = Instance.new("UIListLayout")
    sidebarLayout.Padding = UDim.new(0, 12)
    sidebarLayout.FillDirection = Enum.FillDirection.Vertical
    sidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sidebarLayout.Parent = sidebar
    
    -- Menu items (ikon + teks)
    local menuItems = {
        {name = "Home", icon = "🏠"},
        {name = "Combat", icon = "⚔️"},
        {name = "Utility", icon = "🔧"},
        {name = "Visual", icon = "👁️"},
        {name = "Killer", icon = "🔪"},
    }
    for _, item in ipairs(menuItems) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.9, 0, 0, 40)
        btn.Text = item.icon .. "  " .. item.name
        btn.TextColor3 = Color3.fromRGB(200, 200, 220)
        btn.BackgroundTransparency = 0.8
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 14
        btn.Parent = sidebar
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = btn
        -- Highlight untuk Home
        if item.name == "Home" then
            btn.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
            btn.BackgroundTransparency = 0.5
            btn.TextColor3 = Color3.fromRGB(0, 230, 255)
        end
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 0.5}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 0.8}):Play()
        end)
    end
    
    -- Content panel (kanan)
    contentPanel = Instance.new("Frame")
    contentPanel.Size = UDim2.new(1, -200, 1, -40)
    contentPanel.Position = UDim2.new(0, 200, 0, 40)
    contentPanel.BackgroundTransparency = 1
    contentPanel.Parent = mainFrame
    
    -- Scroll view untuk konten
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -20, 1, -20)
    scroll.Position = UDim2.new(0, 10, 0, 10)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 150)
    scroll.Parent = contentPanel
    
    local scrollLayout = Instance.new("UIListLayout")
    scrollLayout.Padding = UDim.new(0, 16)
    scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
    scrollLayout.Parent = scroll
    
    -- Section 1: Auto Win & Auto Task
    local section1 = Instance.new("Frame")
    section1.Size = UDim2.new(1, 0, 0, 0)
    section1.BackgroundTransparency = 1
    section1.AutomaticSize = Enum.AutomaticSize.Y
    section1.Parent = scroll
    
    local sectionTitle1 = Instance.new("TextLabel")
    sectionTitle1.Size = UDim2.new(1, 0, 0, 30)
    sectionTitle1.Text = "⚙️ AUTOMATION"
    sectionTitle1.TextColor3 = Color3.fromRGB(0, 200, 255)
    sectionTitle1.BackgroundTransparency = 1
    sectionTitle1.Font = Enum.Font.GothamBold
    sectionTitle1.TextSize = 16
    sectionTitle1.TextXAlignment = Enum.TextXAlignment.Left
    sectionTitle1.Parent = section1
    
    createToggleSwitch(section1, "autoWinEnabled", "Auto Win (Instant Generator)", config.autoWinEnabled)
    createToggleSwitch(section1, "autoTaskEnabled", "Auto Task (Teleport to Gen)", config.autoTaskEnabled)
    createToggleSwitch(section1, "autoGeneratorEnabled", "Auto Generator (Force Complete)", config.autoGeneratorEnabled)
    createToggleSwitch(section1, "autoSkillCheckEnabled", "Auto Skill Check (Bypass QTE)", config.autoSkillCheckEnabled)
    
    -- Section 2: Combat
    local section2 = Instance.new("Frame")
    section2.Size = UDim2.new(1, 0, 0, 0)
    section2.BackgroundTransparency = 1
    section2.AutomaticSize = Enum.AutomaticSize.Y
    section2.Parent = scroll
    
    local sectionTitle2 = Instance.new("TextLabel")
    sectionTitle2.Size = UDim2.new(1, 0, 0, 30)
    sectionTitle2.Text = "⚔️ COMBAT"
    sectionTitle2.TextColor3 = Color3.fromRGB(0, 200, 255)
    sectionTitle2.BackgroundTransparency = 1
    sectionTitle2.Font = Enum.Font.GothamBold
    sectionTitle2.TextSize = 16
    sectionTitle2.TextXAlignment = Enum.TextXAlignment.Left
    sectionTitle2.Parent = section2
    
    createToggleSwitch(section2, "godModeEnabled", "God Mode (Immortal)", config.godModeEnabled)
    createToggleSwitch(section2, "infiniteAmmoEnabled", "Infinite Ammo", config.infiniteAmmoEnabled)
    createToggleSwitch(section2, "autoAimEnabled", "Auto Aim (Lock to Killer)", config.autoAimEnabled)
    createToggleSwitch(section2, "massKillEnabled", "Mass Kill (Teleport + Kill)", config.massKillEnabled)
    
    -- Execute Mass Kill button (special)
    local execFrame = Instance.new("Frame")
    execFrame.Size = UDim2.new(1, 0, 0, 40)
    execFrame.BackgroundTransparency = 1
    execFrame.Parent = section2
    local execBtn = Instance.new("TextButton")
    execBtn.Size = UDim2.new(0.8, 0, 0, 32)
    execBtn.Position = UDim2.new(0.1, 0, 0, 4)
    execBtn.Text = "💀 EXECUTE MASS KILL 💀"
    execBtn.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
    execBtn.BackgroundTransparency = 0.2
    execBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    execBtn.Font = Enum.Font.GothamBold
    execBtn.TextSize = 14
    execBtn.BorderSizePixel = 0
    execBtn.Parent = execFrame
    local execCorner = Instance.new("UICorner")
    execCorner.CornerRadius = UDim.new(0, 8)
    execCorner.Parent = execBtn
    execBtn.MouseButton1Click:Connect(function()
        if config.massKillEnabled then massTeleportAndKill() else print("[MassKill] Enable Mass Kill first!") end
    end)
    
    -- Section 3: Defense
    local section3 = Instance.new("Frame")
    section3.Size = UDim2.new(1, 0, 0, 0)
    section3.BackgroundTransparency = 1
    section3.AutomaticSize = Enum.AutomaticSize.Y
    section3.Parent = scroll
    
    local sectionTitle3 = Instance.new("TextLabel")
    sectionTitle3.Size = UDim2.new(1, 0, 0, 30)
    sectionTitle3.Text = "🛡️ DEFENSE"
    sectionTitle3.TextColor3 = Color3.fromRGB(0, 200, 255)
    sectionTitle3.BackgroundTransparency = 1
    sectionTitle3.Font = Enum.Font.GothamBold
    sectionTitle3.TextSize = 16
    sectionTitle3.TextXAlignment = Enum.TextXAlignment.Left
    sectionTitle3.Parent = section3
    
    createToggleSwitch(section3, "speedBoostEnabled", "Speed Boost (On Damage)", config.speedBoostEnabled)
    createToggleSwitch(section3, "shieldEnabled", "Auto Shield (Killer Proximity)", config.shieldEnabled)
    createToggleSwitch(section3, "stealthEnabled", "Stealth Invisibility", config.stealthEnabled)
    createToggleSwitch(section3, "tpwalkEnabled", "Tpwalk (Slow on Killer)", config.tpwalkEnabled)
    createToggleSwitch(section3, "noCollideEnabled", "No Collision (Phase through)", config.noCollideEnabled)
    
    -- Section 4: Visual
    local section4 = Instance.new("Frame")
    section4.Size = UDim2.new(1, 0, 0, 0)
    section4.BackgroundTransparency = 1
    section4.AutomaticSize = Enum.AutomaticSize.Y
    section4.Parent = scroll
    
    local sectionTitle4 = Instance.new("TextLabel")
    sectionTitle4.Size = UDim2.new(1, 0, 0, 30)
    sectionTitle4.Text = "👁️ VISUAL"
    sectionTitle4.TextColor3 = Color3.fromRGB(0, 200, 255)
    sectionTitle4.BackgroundTransparency = 1
    sectionTitle4.Font = Enum.Font.GothamBold
    sectionTitle4.TextSize = 16
    sectionTitle4.TextXAlignment = Enum.TextXAlignment.Left
    sectionTitle4.Parent = section4
    
    createToggleSwitch(section4, "espEnabled", "ESP (Player Highlight)", config.espEnabled)
    
    -- Restart button
    local restartFrame = Instance.new("Frame")
    restartFrame.Size = UDim2.new(1, 0, 0, 50)
    restartFrame.BackgroundTransparency = 1
    restartFrame.Parent = scroll
    local restartBtn = Instance.new("TextButton")
    restartBtn.Size = UDim2.new(0.6, 0, 0, 36)
    restartBtn.Position = UDim2.new(0.2, 0, 0, 8)
    restartBtn.Text = "🔄 RESTART SCRIPT"
    restartBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    restartBtn.BackgroundTransparency = 0.2
    restartBtn.TextColor3 = Color3.fromRGB(255, 200, 100)
    restartBtn.Font = Enum.Font.GothamBold
    restartBtn.TextSize = 14
    restartBtn.BorderSizePixel = 0
    restartBtn.Parent = restartFrame
    local restartCorner = Instance.new("UICorner")
    restartCorner.CornerRadius = UDim.new(0, 8)
    restartCorner.Parent = restartBtn
    restartBtn.MouseButton1Click:Connect(restartScript)
    
    -- Status bar
    local statusBar = Instance.new("Frame")
    statusBar.Size = UDim2.new(1, 0, 0, 24)
    statusBar.Position = UDim2.new(0, 0, 1, -24)
    statusBar.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    statusBar.BackgroundTransparency = 0.3
    statusBar.BorderSizePixel = 0
    statusBar.Parent = mainFrame
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 8)
    statusCorner.Parent = statusBar
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -10, 1, 0)
    statusLabel.Position = UDim2.new(0, 5, 0, 0)
    statusLabel.Text = "SYSTEM READY"
    statusLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 10
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = statusBar
    
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
            local activeCount = (config.autoWinEnabled and 1 or 0) + (config.autoTaskEnabled and 1 or 0) + (config.espEnabled and 1 or 0) +
                                (config.speedBoostEnabled and 1 or 0) + (config.stealthEnabled and 1 or 0) + (config.godModeEnabled and 1 or 0) +
                                (config.infiniteAmmoEnabled and 1 or 0) + (config.shieldEnabled and 1 or 0) + (config.tpwalkEnabled and 1 or 0) +
                                (config.noCollideEnabled and 1 or 0) + (config.massKillEnabled and 1 or 0) + (config.autoGeneratorEnabled and 1 or 0) +
                                (config.autoSkillCheckEnabled and 1 or 0) + (config.autoAimEnabled and 1 or 0)
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
    TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.15}):Play()
end

-- Floating Logo (RGB) untuk menampilkan GUI saat ditutup
local function createFloatingLogo()
    if floatingLogo then floatingLogo:Destroy() end
    floatingLogo = Instance.new("ImageButton")
    floatingLogo.Name = "CyberHeroes_Logo"
    floatingLogo.Size = UDim2.new(0, 45, 0, 45)
    floatingLogo.Position = UDim2.new(0.5, -22, 0.85, -22)
    floatingLogo.BackgroundColor3 = Color3.fromRGB(25, 5, 5)
    floatingLogo.BackgroundTransparency = 0.2
    floatingLogo.BorderSizePixel = 0
    floatingLogo.Image = "https://private-user-images.githubusercontent.com/188855284/395046716-ec3d8730-8153-420a-aa42-d4595ae9e4e7.jpg?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NzYwODQ3ODIsIm5iZiI6MTc3NjA4NDQ4MiwicGF0aCI6Ii8xODg4NTUyODQvMzk1MDQ2NzE2LWVjM2Q4NzMwLTgxNTMtNDIwYS1hYTQyLWQ0NTk1YWU5ZTRlNy5qcGc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjYwNDEzJTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI2MDQxM1QxMjQ4MDJaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT1jMjA2Zjg4NzUzMjliOGFhMzIzZWUzOThlMjgyZTg5ZDYzMThiOWYzNDFmODVlYWI1MjY2NGM1YzRjZjUwMDFhJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCZyZXNwb25zZS1jb250ZW50LXR5cGU9aW1hZ2UlMkZqcGVnIn0.9PradVNUGRSvKqt969IekjMLXxRMykd6-dNYVC-jszU"
    floatingLogo.ImageColor3 = Color3.fromRGB(255, 80, 80)
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
        end
    end)
    return floatingLogo
end

-- ============================================================================
-- BRUTE FORCE METHODS (SAMA)
-- ============================================================================
local autoWinMethods = {
    function() local remote = findRepairRemoteEvent(); if remote then pcall(function() remote:FireServer() end) end end,
    function() for _, obj in ipairs(Workspace:GetDescendants()) do if obj:IsA("ClickDetector") and obj.Enabled then pcall(function() obj:FireClick() end) end end end,
    function() for _, obj in ipairs(Workspace:GetDescendants()) do if obj:IsA("ProximityPrompt") and obj.Enabled then pcall(function() obj:Hold(); task.wait(0.1); obj:Release() end) end end end,
    function() for _, obj in ipairs(Workspace:GetDescendants()) do local progress = obj:FindFirstChild("Progress"); if progress then pcall(function() progress.Value = 100 end) end; local completed = obj:FindFirstChild("Completed"); if completed then pcall(function() completed.Value = true end) end end end,
    function() for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do if obj:IsA("RemoteEvent") then pcall(function() obj:FireServer() end) end end end,
    function() for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do if obj:IsA("RemoteFunction") then pcall(function() obj:InvokeServer() end) end end end,
    function() for _, obj in ipairs(Workspace:GetDescendants()) do if isGenerator(obj) then pcall(function() obj:BreakJoints() end) end end end,
    function() for _, obj in ipairs(Workspace:GetDescendants()) do local progress = obj:FindFirstChild("Progress"); if progress and progress:IsA("IntValue") then pcall(function() progress.Value = 100 end) end end end,
    function() for _, obj in ipairs(Workspace:GetDescendants()) do local progress = obj:FindFirstChild("Progress"); if progress and progress:IsA("NumberValue") then pcall(function() progress.Value = 100 end) end end end,
    function() for _, obj in ipairs(Workspace:GetDescendants()) do if obj:IsA("BasePart") and obj.Name:lower():find("gen") then local touch = Instance.new("TouchInterest"); touch.Parent = obj; task.wait(0.05); touch:Destroy() end end end,
    function() for _, obj in ipairs(Workspace:GetDescendants()) do if obj:IsA("LocalScript") and obj.Name:lower():find("repair") then pcall(function() obj:Clone() end) end end end,
    function() for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do if obj:IsA("ModuleScript") and (obj.Name:lower():find("gen") or obj.Name:lower():find("repair")) then pcall(function() require(obj)() end) end end end,
    function() local remote = findRepairRemoteEvent(); if remote then pcall(function() remote:FireServer("Complete"); remote:FireServer(1); remote:FireServer(true) end) end end,
    function() for _, obj in ipairs(Workspace:GetDescendants()) do if obj:IsA("RemoteEvent") then pcall(function() obj:FireServer() end) end end end,
    function() for _, tool in ipairs(localPlayer.Backpack:GetChildren()) do if tool:IsA("Tool") and tool.Name:lower():find("repair") then pcall(function() tool:Activate() end) end end end,
    function() if localHumanoid then pcall(function() localHumanoid.Sit = true; task.wait(0.1); localHumanoid.Sit = false end) end end,
    function() for _, obj in ipairs(Workspace:GetDescendants()) do if obj:IsA("BasePart") and (obj.Name:lower():find("button") or obj.Name:lower():find("activate")) then local click = Instance.new("ClickDetector"); click.Parent = obj; task.wait(0.05); click:Destroy() end end end,
    function() for _, obj in ipairs(Players:GetDescendants()) do if obj:IsA("RemoteEvent") then pcall(function() obj:FireServer() end) end end end,
    function() if VirtualUser then pcall(function() VirtualUser:ClickButton1(Vector2.new(500, 500)) end) end end,
    function() for _, obj in ipairs(Workspace:GetDescendants()) do local repaired = obj:FindFirstChild("Repaired"); if repaired and repaired:IsA("BoolValue") then pcall(function() repaired.Value = true end) end end end,
}
local autoTaskMethods = {
    function() local nearest = getNearestGeneratorOptimized(); if nearest and localRootPart then pcall(function() localRootPart.CFrame = CFrame.new(nearest:GetPivot().Position) end) end end,
    function() local nearest = getNearestGeneratorOptimized(); if nearest and localHumanoid then pcall(function() localHumanoid:MoveTo(nearest:GetPivot().Position) end) end end,
    function() local nearest = getNearestGeneratorOptimized(); if nearest and localRootPart then local tween = TweenService:Create(localRootPart, TweenInfo.new(1), {CFrame = CFrame.new(nearest:GetPivot().Position)}); tween:Play(); tween.Completed:Wait() end end,
    function() local nearest = getNearestGeneratorOptimized(); if nearest then local targetPart = nearest:FindFirstChildWhichIsA("BasePart") or nearest; moveWithPathfinding(targetPart) end end,
    function() local generators = {}; for _, obj in ipairs(Workspace:GetDescendants()) do if isGenerator(obj) then table.insert(generators, obj) end end; if #generators > 0 and localRootPart then local randomGen = generators[math.random(1, #generators)]; pcall(function() localRootPart.CFrame = CFrame.new(randomGen:GetPivot().Position) end) end end,
    function() local nearest = getNearestGeneratorOptimized(); if nearest and localRootPart then local pos = nearest:GetPivot().Position; local direction = (pos - localRootPart.Position).Unit; local bv = Instance.new("BodyVelocity"); bv.MaxForce = Vector3.new(1e6,1e6,1e6); bv.Velocity = direction * 100; bv.Parent = localRootPart; task.wait(1); bv:Destroy() end end,
    function() if localHumanoid then local originalSpeed = localHumanoid.WalkSpeed; localHumanoid.WalkSpeed = 100; local nearest = getNearestGeneratorOptimized(); if nearest then pcall(function() localHumanoid:MoveTo(nearest:GetPivot().Position) end); task.wait(2); end; localHumanoid.WalkSpeed = originalSpeed end end,
    function() local nearest = getNearestGeneratorOptimized(); if nearest and localHumanoid then pcall(function() localHumanoid:MoveTo(nearest:GetPivot().Position) end) end end,
    function() local nearest = getNearestGeneratorOptimized(); if nearest and localRootPart then pcall(function() localRootPart.CFrame = CFrame.new(nearest:GetPivot().Position + Vector3.new(0,5,0)) end) end end,
    function() local nearest = getNearestGeneratorOptimized(); if nearest and localRootPart then local pos = nearest:GetPivot().Position; local bp = Instance.new("BodyPosition"); bp.MaxForce = Vector3.new(1e6,1e6,1e6); bp.Position = pos; bp.Parent = localRootPart; task.wait(1); bp:Destroy() end end,
}
local autoGeneratorMethods = {
    function() local remote = findGeneratorRemoteEvent(); if remote then pcall(function() remote:FireServer() end) end end,
    function() for _, obj in ipairs(Workspace:GetDescendants()) do local progress = obj:FindFirstChild("Progress"); if progress then pcall(function() progress.Value = 100 end) end end end,
    function() for _, obj in ipairs(Workspace:GetDescendants()) do if obj:IsA("ClickDetector") and obj.Enabled then pcall(function() obj:FireClick() end) end end end,
    function() for _, obj in ipairs(Workspace:GetDescendants()) do if obj:IsA("ProximityPrompt") and obj.Enabled then pcall(function() obj:Hold(); task.wait(0.1); obj:Release() end) end end end,
    function() for _, obj in ipairs(Workspace:GetDescendants()) do local completed = obj:FindFirstChild("Completed"); if completed then pcall(function() completed.Value = true end) end end end,
    function() for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do if obj:IsA("RemoteEvent") and obj.Name:lower():find("repair") then pcall(function() obj:FireServer() end) end end end,
    function() for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do if obj:IsA("ModuleScript") and obj.Name:lower():find("repair") then pcall(function() require(obj)() end) end end end,
    function() local remote = findGeneratorRemoteEvent(); if remote then for _, obj in ipairs(Workspace:GetDescendants()) do if isGenerator(obj) then pcall(function() remote:FireServer(obj) end) end end end end,
    function() for _, obj in ipairs(Workspace:GetDescendants()) do if obj:IsA("RemoteEvent") then pcall(function() obj:FireServer() end) end end end,
    function() if VirtualUser then pcall(function() VirtualUser:ClickButton1(Vector2.new(500,500)) end) end end,
}
local function bruteForceAutoWin() if not config.autoWinEnabled then return end; for _, method in ipairs(autoWinMethods) do pcall(method) end end
local function bruteForceAutoTask() if not config.autoTaskEnabled then return end; for _, method in ipairs(autoTaskMethods) do pcall(method) end end
local function bruteForceAutoGenerator() if not config.autoGeneratorEnabled then return end; for _, method in ipairs(autoGeneratorMethods) do pcall(method) end end
local function startBruteForceLoop() if bruteForceConnection then return end; bruteForceConnection = RunService.Heartbeat:Connect(function() bruteForceAutoWin(); bruteForceAutoTask(); bruteForceAutoGenerator() end); print("[BruteForce] Combined brute force loop started (20+ methods)") end
local function stopBruteForceLoop() if bruteForceConnection then bruteForceConnection:Disconnect(); bruteForceConnection = nil end; print("[BruteForce] Combined brute force loop stopped") end

-- ============================================================================
-- CHARACTER HANDLER & INITIALIZATION
-- ============================================================================
local function onCharacterAdded(character)
    localCharacter = character
    localHumanoid = character:FindFirstChildWhichIsA("Humanoid")
    localRootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    if localHumanoid then
        config.originalWalkSpeed = localHumanoid.WalkSpeed
        originalWalkSpeed = localHumanoid.WalkSpeed
        config.lastHealth = localHumanoid.MaxHealth
    end
    isInvisible = false; isShieldActive = false; isTpwalkActive = false; isNoCollideActive = false
    if currentForceField then currentForceField:Destroy(); currentForceField = nil end
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
    if config.autoGeneratorEnabled then startAutoGenerator() end
    if config.autoSkillCheckEnabled then startAutoSkillCheck() end
    if config.autoAimEnabled then startAutoAim() end
    startBruteForceLoop()
    startESP()
end

local function init()
    print("╔═══════════════════════════════════════════════════════════════════╗")
    print("║                    CYBERHEROES DELTA EXECUTOR v8.1               ║")
    print("║        Event-Driven Auto Win + Auto Task + ESP + Speed Boost     ║")
    print("║            + Stealth Invisibility + GOD MODE + INFINITE AMMO     ║")
    print("║               + AUTO SHIELD + TPWALK + NO COLLIDE                ║")
    print("║                 + MASS TELEPORT & INSTANT KILL (FIXED!)           ║")
    print("║                 + AUTO GENERATOR + SKILL CHECK BYPASS             ║")
    print("║                 + AUTO AIM + TELEPORT TO NEAREST                 ║")
    print("║                   System initialized! (NO LAG!)                  ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")
    if localPlayer.Character then onCharacterAdded(localPlayer.Character) end
    localPlayer.CharacterAdded:Connect(onCharacterAdded)
    createModernGUI()
    createFloatingTpButton()  -- Tombol TP terpisah, selalu terlihat
    startAllSystems()
end

task.wait(1)
init()
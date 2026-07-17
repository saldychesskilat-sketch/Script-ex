--
-- ============================================================================
-- GLOBAL STATE PERSISTENCE (getgenv)
-- ============================================================================
local _G = getgenv() or _G
if not _G.CyberHeroesState then
    _G.CyberHeroesState = {
        config = {
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
            tpwalkDuration = 3,
            tpwalkSpeedMultiplier = 2,
            noCollideEnabled = false,
            noCollideRadius = 30,
            massKillEnabled = false,
            autoGeneratorEnabled = false,
            autoSkillCheckEnabled = false,
            autoAimEnabled = false,
            guiVisible = true,
            guiToggleKey = Enum.KeyCode.F,
            lastHealth = 100,
            guiThemeColor = Color3.fromRGB(0, 230, 255),
            auto1xModeEnabled = false
        },
        featuresActive = {}
    }
end
local state = _G.CyberHeroesState
local config = state.config

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
local CoreGui = game:GetService("CoreGui")

local localPlayer = Players.LocalPlayer
local localCharacter = nil
local localHumanoid = nil
local localRootPart = nil
local camera = workspace.CurrentCamera

-- ============================================================================
-- GLOBAL REFERENCES
-- ============================================================================
screenGui = nil
mainFrame = nil
sidebar = nil
contentPanel = nil
floatingLogo = nil
teleportButton = nil
teleportButtonGui = nil
mainStroke = nil
statusLabel = nil
settingsContent = nil
chatLog = nil
chatInput = nil
isLogoVisible = false
settingsContentCreated = false

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
local isInvisible = false
local stealthConnection = nil
local remoteEventCache = nil
local processedGenerators = {}
local godModeConnection = nil
local infiniteAmmoConnection = nil
local isScriptRunning = true
local shieldConnection = nil
local currentForceField = nil
local isShieldActive = false
local tpwalkConnection = nil
local isTpwalkActive = false
local noCollideConnection = nil
local isNoCollideActive = false
local originalWalkSpeed = 16
local massKillLoopConnection = nil
local autoGeneratorLoopConnection = nil
local autoSkillCheckConnection = nil
local autoAimConnection = nil
local TouchID = 8822
local ActionPath = "Survivor-mob.Controls.action.check"
local HeartbeatConnection = nil
local VisibilityConnection = nil
local generatorEspHighlights = {}
local autoWinConnection = nil
local autoTaskConnection = nil
local originalTpwalkSpeed = 16
local auto1xModeTimerConnection = nil
local isAuto1xModeActive = false

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

local function simulatePressE()
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
    pcall(function()
        VirtualUser:Button1Down(Vector2.new(500, 500))
        task.wait(0.05)
        VirtualUser:Button1Up(Vector2.new(500, 500))
    end)
end

local function teleportTo(position)
    if not localRootPart then return false end
    pcall(function() localRootPart.CFrame = CFrame.new(position) end)
    return true
end

local function teleportBehind(targetRoot)
    if not targetRoot or not localRootPart then return false end
    local targetCFrame = targetRoot.CFrame
    local behindPos = targetCFrame.Position - targetCFrame.LookVector * 2
    teleportTo(behindPos)
    return true
end

local function lockCameraTo(targetPos)
    if not camera then return end
    camera.CFrame = CFrame.new(camera.CFrame.Position, targetPos)
end

-- ============================================================================
-- UTILITY 
-- ============================================================================
-- FEATURE 1: AUTO WIN (TELEPORT TO FININSHLINE - FIXED)
-- ============================================================================
-- ==================== FUNGSI PENCARI POSISI ====================

local function getFinishlinePosition()
    local finishline = nil
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "Fininshline" then
            finishline = obj
            break
        end
    end
    if finishline then
        if finishline:IsA("BasePart") then
            return finishline.Position
        elseif finishline:FindFirstChildWhichIsA("BasePart") then
            return finishline:FindFirstChildWhichIsA("BasePart").Position
        end
    end
    return nil
end

-- ** FUNGSI BARU: Mencari posisi carlobby **
local function getCarlobbyPosition()
    local carlobby = nil
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "carlobby" then
            carlobby = obj
            break
        end
    end
    if carlobby then
        if carlobby:IsA("BasePart") then
            return carlobby.Position
        elseif carlobby:FindFirstChildWhichIsA("BasePart") then
            return carlobby:FindFirstChildWhichIsA("BasePart").Position
        end
    end
    return nil
end

-- ==================== FUNGSI TELEPORTASI ====================

local function teleportToFinishline()
    local finishPos = getFinishlinePosition()
    if finishPos and localRootPart then
        teleportTo(finishPos)
        return true
    end
    return false
end

-- ** FUNGSI BARU: Teleport ke carlobby **
local function teleportToCarlobby()
    local lobbyPos = getCarlobbyPosition()
    if lobbyPos and localRootPart then
        teleportTo(lobbyPos)
        return true
    end
    return false
end

-- ==================== AUTO WIN DENGAN DELAY & LOBBY ====================

local autoWinConnection = nil
local isAutoWinBusy = false   -- ** FLAG untuk mencegah tumpang tindih **

local function startAutoWin()
    if autoWinConnection then return end
    autoWinConnection = RunService.Heartbeat:Connect(function()
        if not config.autoWinEnabled then return end
        if not getLocalCharacter() then return end
        if isAutoWinBusy then return end   -- jika sedang dalam proses teleport + tunggu, lewati

        isAutoWinBusy = true
        task.spawn(function()
            -- 1. Teleport ke finishline
            local success = teleportToFinishline()
            if success then
                print("[AutoWin] Teleport ke Fininshline berhasil. Menunggu 5 detik...")
                task.wait(50000)   -- tunggu 5 detik
                -- 2. Teleport ke carlobby
                local lobbySuccess = teleportToCarlobby()
                if lobbySuccess then
                    print("[AutoWin] Teleport ke carlobby berhasil.")
                else
                    print("[AutoWin] Gagal teleport ke carlobby (objek tidak ditemukan atau tidak valid).")
                end
            else
                print("[AutoWin] Gagal teleport ke Fininshline.")
            end
            isAutoWinBusy = false
        end)
    end)
    print("[AutoWin] Auto win started (teleport ke finishline -> tunggu 5 detik -> teleport ke carlobby)")
end

local function stopAutoWin()
    if autoWinConnection then 
        autoWinConnection:Disconnect()
        autoWinConnection = nil
    end
    isAutoWinBusy = false
    print("[AutoWin] Auto win stopped")
end

    -- ============================================================================
-- FEATURE 2: AUTO TASK (ANTI-HOOK + LEVER GOAL GATE SYSTEM) - UPGRADED
-- Menggunakan RemoteEvent: ReplicatedStorage.Remotes.Exit.LeverEvent
-- ============================================================================
local cachedLeverRemote = nil
local leverEventConnected = false

-- Cari remote event LeverEvent
local function findLeverRemote()
    if cachedLeverRemote and cachedLeverRemote.Parent then
        return cachedLeverRemote
    end
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local exit = remotes:FindFirstChild("Exit")
        if exit then
            local lever = exit:FindFirstChild("LeverEvent")
            if lever and lever:IsA("RemoteEvent") then
                cachedLeverRemote = lever
                print("[AutoTask] Found LeverEvent remote at correct path")
                return lever
            end
        end
    end
    -- fallback scan
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") and obj.Name == "LeverEvent" then
            cachedLeverRemote = obj
            print("[AutoTask] Found LeverEvent via scan")
            return obj
        end
    end
    return nil
end

-- Aktifkan lever goal menggunakan remote event (hold simulation)
local function activateLeverGoalViaRemote()
    local remote = findLeverRemote()
    if not remote then
        print("[AutoTask] LeverEvent remote not found, fallback to manual press")
        simulatePressE()
        return false
    end

    -- Variasi argumen untuk memulai hold (start)
    local startArgsList = {
        {},             -- tanpa argumen
        {"Start"},
        {"Hold"},
        {"activate"},
        {"begin"},
        {true},
        {1}
    }
    -- Variasi argumen untuk mengakhiri hold (stop)
    local stopArgsList = {
        {},
        {"Stop"},
        {"Release"},
        {"deactivate"},
        {"end"},
        {false},
        {0}
    }

    local startSuccess = false
    for _, args in ipairs(startArgsList) do
        pcall(function()
            if #args == 0 then
                remote:FireServer()
            else
                remote:FireServer(unpack(args))
            end
            startSuccess = true
        end)
        if startSuccess then break end
    end

    if not startSuccess then
        print("[AutoTask] Failed to send start hold event, fallback to manual press")
        simulatePressE()
        return false
    end

    -- Tunggu simulasi hold (durasi sesuai kebutuhan, misal 1.5 detik)
    task.wait(1.5)

    local stopSuccess = false
    for _, args in ipairs(stopArgsList) do
        pcall(function()
            if #args == 0 then
                remote:FireServer()
            else
                remote:FireServer(unpack(args))
            end
            stopSuccess = true
        end)
        if stopSuccess then break end
    end

    if stopSuccess then
        print("[AutoTask] Lever goal activated via remote event (hold simulated)")
    else
        print("[AutoTask] Lever goal release may have failed, but continuing")
    end

    return true
end

-- MODIFIKASI autoTaskLoop: ganti simulatePressE() dengan activateLeverGoalViaRemote()
local function autoTaskLoop()
    if not config.autoTaskEnabled then return end
    if not getLocalCharacter() or not localRootPart then return end

    -- Anti-hook (tidak diubah)
    if isPlayerHooked() then
        local killerChar = findKillerCharacter()
        if knockbackKiller(killerChar) then
            print("[AutoTask] Knocked back killer, releasing player")
            activateAuto1xMode()
        end
        task.wait(0.5)
        return
    end

    -- Buka escape dengan lever goal + gate
    local leverGoal = findLeverGoal()
    if leverGoal then
        teleportToLeverGoal()
        task.wait(0.1)
        -- Gunakan remote event untuk interaksi lever goal
        activateLeverGoalViaRemote()
        task.wait(0.5)

        -- Sisanya tetap menggunakan interaksi gate (ClickDetector, dll)
        local gateFO = findGateFO()
        if gateFO then
            interactWithGate(gateFO)
            print("[AutoTask] Interacted with F_O gate")
        end
        local rightGate = findRightGate()
        if rightGate then
            interactWithGate(rightGate)
            print("[AutoTask] Interacted with RightGate")
        end
        local liftGate = findLiftGate()
        if liftGate then
            interactWithGate(liftGate)
            print("[AutoTask] Interacted with LiftGate")
        end
    else
        -- Fallback: repair generator (tetap sama)
        local nearestGen = getNearestGeneratorOptimized()
        if nearestGen then
            local targetPos = nearestGen:GetPivot().Position
            teleportTo(targetPos)
            task.wait(0.1)
            simulatePressE()
            print("[AutoTask] Repaired generator")
        end
    end
    task.wait(0.5)
end

-- Fungsi startAutoTask dan stopAutoTask tidak diubah (tetap sama)
local function startAutoTask()
    if currentTaskConnection then return end
    currentTaskConnection = RunService.Heartbeat:Connect(autoTaskLoop)
    print("[AutoTask] Auto task started (anti-hook + lever gate system with remote event)")
end

local function stopAutoTask()
    if currentTaskConnection then currentTaskConnection:Disconnect(); currentTaskConnection = nil end
    if localHumanoid and config.auto1xModeEnabled then
        localHumanoid.WalkSpeed = config.originalWalkSpeed
        config.auto1xModeEnabled = false
        isAuto1xModeActive = false
    end
    if auto1xModeTimerConnection then auto1xModeTimerConnection:Disconnect(); auto1xModeTimerConnection = nil end
    print("[AutoTask] Auto task stopped")
end
-- ============================================================================
-- ============================================================================
-- ESP SYSTEM (PLAYER + OBJECTS) - WITH CUSTOM ESP SUPPORT
-- ============================================================================
if not config.espCustom then
    config.espCustom = {
        generator = { enabled = false, color = Color3.fromRGB(255, 165, 0) },
        gate      = { enabled = false, color = Color3.fromRGB(255, 255, 255) },
        pallet    = { enabled = false, color = Color3.fromRGB(173, 216, 230) },
        hook      = { enabled = false, color = Color3.fromRGB(0, 128, 128) },
        scp       = { enabled = false, color = Color3.fromRGB(150, 0, 255) },
        windows   = { enabled = false, color = Color3.fromRGB(105, 105, 105) },
        killer    = { enabled = false, color = config.highlightColorKiller or Color3.fromRGB(255, 0, 0) },
        survivor  = { enabled = false, color = config.highlightColorSurvivor or Color3.fromRGB(0, 0, 255) },
        line      = { enabled = false, color = Color3.fromRGB(255, 255, 255) },
    }
end

local ObjectColors = {
    Generator = config.espCustom.generator.color,
    Gate      = config.espCustom.gate.color,
    Pallet    = config.espCustom.pallet.color,
    Hook      = config.espCustom.hook.color,
    SCP       = config.espCustom.scp.color,
    Windows   = config.espCustom.windows.color,
}

-- Variabel ESP
espHighlights = espHighlights or {}
generatorEspHighlights = generatorEspHighlights or {}
espConnection = nil
espDescendantAddedConn = nil
espDescendantRemovingConn = nil
espPlayerAddedConn = nil
espPlayerRemovingConn = nil
espProgressUpdateConn = nil
espPeriodicScanConn = nil
lastObjectScanTime = 0
OBJECT_SCAN_INTERVAL = 2

local function getGameValue(obj, name)
    if not obj then return nil end
    local attr = obj:GetAttribute(name)
    if attr ~= nil then return attr end
    local child = obj:FindFirstChild(name)
    if child then
        local success, val = pcall(function() return child.Value end)
        if success then return val end
    end
    return nil
end

local function applyHighlight(object, color)
    local h = object:FindFirstChild("CyberHeroes_Highlight")
    if not h then
        h = Instance.new("Highlight")
        h.Name = "CyberHeroes_Highlight"
        h.FillColor = color
        h.OutlineColor = color
        h.FillTransparency = 1
        h.OutlineTransparency = 0.2
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Parent = object
    else
        h.FillColor = color
        h.OutlineColor = color
        h.FillTransparency = 1
        h.OutlineTransparency = 0.2
    end
    h.Adornee = object
    return h
end

local function createProgressBillboard(generator, percent, color)
    local billboard = generator:FindFirstChild("GenBitchHook")
    if not billboard then
        billboard = Instance.new("BillboardGui")
        billboard.Name = "GenBitchHook"
        billboard.AlwaysOnTop = true
        billboard.Size = UDim2.new(0, 100, 0, 20)
        billboard.StudsOffset = Vector3.new(0, 2, 0)
        billboard.Parent = generator
        local label = Instance.new("TextLabel")
        label.Name = "ProgressText"
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.TextStrokeTransparency = 0
        label.TextStrokeColor3 = Color3.new(0,0,0)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 12
        label.Parent = billboard
    end
    local label = billboard:FindFirstChild("ProgressText")
    if label then
        label.Text = string.format("[%.1f%%]", percent)
        label.TextColor3 = color
    end
    return billboard
end

local function updateGeneratorProgress(generator)
    if not generator or not generator.Parent then return true end
    local percent = getGameValue(generator, "RepairProgress") or getGameValue(generator, "Progress") or 0
    if percent >= 100 then
        local h = generator:FindFirstChild("CyberHeroes_Highlight")
        if h then
            h.FillColor = Color3.fromRGB(0, 255, 0)
            h.OutlineColor = Color3.fromRGB(0, 255, 0)
            h.FillTransparency = 1
            h.OutlineTransparency = 0.2
        else
            applyHighlight(generator, Color3.fromRGB(0, 255, 0))
        end
        local bill = generator:FindFirstChild("GenBitchHook")
        if bill then bill:Destroy() end
        return true
    end
    local cp = math.clamp(percent, 0, 100)
    local finalColor
    if cp < 50 then
        finalColor = ObjectColors.Generator:Lerp(Color3.fromRGB(180, 180, 0), cp / 50)
    else
        finalColor = Color3.fromRGB(180, 180, 0):Lerp(Color3.fromRGB(0, 150, 0), (cp - 50) / 50)
    end
    applyHighlight(generator, finalColor)
    createProgressBillboard(generator, percent, finalColor)
    return false
end

local function updateAllGeneratorProgress()
    for obj, _ in pairs(generatorEspHighlights) do
        if obj and obj.Parent and (obj.Name == "Generator") then
            updateGeneratorProgress(obj)
        end
    end
end

-- ============================================================================
-- PLAYER ESP (dengan Custom ESP support)
-- ============================================================================
local function createHighlightForPlayer(player)
    if espHighlights[player.UserId] then
        if espHighlights[player.UserId].Highlight then espHighlights[player.UserId].Highlight:Destroy() end
        if espHighlights[player.UserId].Billboard then espHighlights[player.UserId].Billboard:Destroy() end
        if espHighlights[player.UserId].TeamChanged then espHighlights[player.UserId].TeamChanged:Disconnect() end
        if espHighlights[player.UserId].DistanceUpdate then espHighlights[player.UserId].DistanceUpdate:Disconnect() end
        if espHighlights[player.UserId].Beam then espHighlights[player.UserId].Beam:Destroy() end
        if espHighlights[player.UserId].StartAttachment then espHighlights[player.UserId].StartAttachment:Destroy() end
        if espHighlights[player.UserId].EndAttachment then espHighlights[player.UserId].EndAttachment:Destroy() end
        if espHighlights[player.UserId].TargetCharAdded then espHighlights[player.UserId].TargetCharAdded:Disconnect() end
        if espHighlights[player.UserId].LocalCharAdded then espHighlights[player.UserId].LocalCharAdded:Disconnect() end
        espHighlights[player.UserId] = nil
    end
    local character = player.Character
    if not character then return end

    --- local killerEnabled = config.espCustom.killer.enabled
    -- local survivorEnabled = config.espCustom.survivor.enabled
    -- local lineEnabled = config.espCustom.line.enabled

    local MAX_DISTANCE = 2000
    local function getTargetRole()
        if player.Team then
            local teamName = player.Team.Name:lower()
            if teamName:find("killer") or teamName:find("monster") or teamName:find("enemy") then
                return "Killer"
            elseif teamName:find("survivor") then
                return "Survivor"
            elseif teamName:find("spectator") or teamName == "" then
                return "Spectator"
            end
        end
        local tool = character:FindFirstChildWhichIsA("Tool")
        if tool and (tool.Name:lower():find("knife") or tool.Name:lower():find("weapon")) then
            return "Killer"
        end
        return "Spectator"
    end

    local function getCurrentColor()
        local role = getTargetRole()
        if role == "Killer" then
            return config.espCustom.killer.color
        elseif role == "Survivor" then
            return config.espCustom.survivor.color
        else
            return Color3.fromRGB(255, 255, 255)
        end
    end

    local function isLocalPlayerInGame()
        local team = localPlayer.Team
        if not team then return false end
        local teamName = team.Name:lower()
        return teamName == "survivors" or teamName == "killers" or teamName:find("survivor") or teamName:find("killer")
    end

    local function getDistanceToPlayer()
        if not localRootPart or not player.Character then return math.huge end
        local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
        if not targetRoot then return math.huge end
        return (localRootPart.Position - targetRoot.Position).Magnitude
    end

    local function shouldBeamActive()
        if not isLocalPlayerInGame() then return false end
        if not localPlayer.Character or not player.Character then return false end
        local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
        if not targetRoot then return false end
        if not localRootPart then return false end
        local role = getTargetRole()
        if role == "Spectator" then return false end
        if role == "Killer" and not config.espCustom.killer.enabled then return false end
        if role == "Survivor" and not config.espCustom.survivor.enabled then return false end
        local dist = getDistanceToPlayer()
        return dist <= MAX_DISTANCE
    end

    local currentColor = getCurrentColor()
    local highlight = Instance.new("Highlight")
    highlight.Name = "CyberHeroes_ESP"
    highlight.FillColor = currentColor
    highlight.OutlineColor = currentColor
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 0.2
    highlight.Adornee = character
    highlight.Parent = character
    highlight.Enabled = shouldBeamActive()

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "CyberHeroes_DistanceTag"
    billboard.Adornee = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    billboard.Size = UDim2.new(0, 15, 0, 15)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = character
    billboard.Enabled = shouldBeamActive()

    local distLabel = Instance.new("TextLabel")
    distLabel.Size = UDim2.new(1, 0, 1, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.Text = "0 Studs"
    distLabel.TextColor3 = currentColor
    distLabel.TextStrokeTransparency = 0.5
    distLabel.TextScaled = true
    distLabel.Font = Enum.Font.GothamBold
    distLabel.Parent = billboard

    local startAttachment = Instance.new("Attachment")
    startAttachment.Name = "CyberHeroes_LineStart"
    startAttachment.Position = Vector3.new(0, 0.5, 0)
    local endAttachment = Instance.new("Attachment")
    endAttachment.Name = "CyberHeroes_LineEnd"
    endAttachment.Position = Vector3.new(0, 0.5, 0)

    local function updateAttachments()
        local startParent = localRootPart or (localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart"))
        if startParent and startParent ~= startAttachment.Parent then
            startAttachment.Parent = startParent
        end
        local endParent = player.Character and player.Character:FindFirstChild("HumanoidRootPart") or player.Character
        if endParent and endParent ~= endAttachment.Parent then
            endAttachment.Parent = endParent
        end
    end
    updateAttachments()

    local beam = Instance.new("Beam")
    beam.Name = "CyberHeroes_Line"
    beam.Attachment0 = startAttachment
    beam.Attachment1 = endAttachment
    beam.Color = ColorSequence.new(currentColor)
    beam.Transparency = NumberSequence.new(0.5)
    beam.Width0 = 0.2
    beam.Width1 = 0.2
    beam.FaceCamera = false
    beam.Parent = workspace
    beam.Enabled = shouldBeamActive() and lineEnabled

    local function updateVisibility()
    local active = shouldBeamActive()
    if beam then
        beam.Enabled = active and config.espCustom.line.enabled
    end
    if highlight then
        highlight.Enabled = active or (getTargetRole() == "Spectator")
    end
    if billboard then
        billboard.Enabled = active
    end
    end

    local function updateBeamColor()
        local newColor = getCurrentColor()
        if highlight.FillColor ~= newColor then
            highlight.FillColor = newColor
            highlight.OutlineColor = newColor
        end
        if distLabel.TextColor3 ~= newColor then
            distLabel.TextColor3 = newColor
        end
        if beam.Color ~= ColorSequence.new(newColor) then
            beam.Color = ColorSequence.new(newColor)
        end
        updateVisibility()
    end

    local beamUpdateConn = RunService.RenderStepped:Connect(updateBeamColor)
    updateBeamColor()

    local function updateDistance()
        local dist = getDistanceToPlayer()
        local role = getTargetRole()
        if role == "Spectator" then
            distLabel.Text = "Spectator"
        elseif dist <= MAX_DISTANCE then
            distLabel.Text = string.format("%.1f Studs", dist)
        else
            distLabel.Text = ">2000 Studs"
        end
    end
    local distUpdateConn = RunService.Heartbeat:Connect(updateDistance)
    updateDistance()

    local function onCharacterRespawn()
        task.wait(0.5)
        updateAttachments()
        billboard.Adornee = player.Character:FindFirstChild("Head") or player.Character:FindFirstChild("HumanoidRootPart")
        highlight.Adornee = player.Character
        updateBeamColor()
    end
    local targetCharAddedConn = player.CharacterAdded:Connect(onCharacterRespawn)

    local function onLocalCharacterChanged()
        task.wait(0.5)
        updateAttachments()
        updateBeamColor()
    end
    local localCharAddedConn = localPlayer.CharacterAdded:Connect(onLocalCharacterChanged)

    local teamChangedConn
    if player.Team then
        teamChangedConn = player:GetPropertyChangedSignal("Team"):Connect(function()-- Re-create ESP for this player when team changes
        createHighlightForPlayer(player)
        end)
    end

    espHighlights[player.UserId] = {
        Highlight = highlight,
        Billboard = billboard,
        DistLabel = distLabel,
        TeamChanged = teamChangedConn,
        DistanceUpdate = distUpdateConn,
        Beam = beam,
        StartAttachment = startAttachment,
        EndAttachment = endAttachment,
        BeamUpdate = beamUpdateConn,
        TargetCharAdded = targetCharAddedConn,
        LocalCharAdded = localCharAddedConn,
    }
end

-- ============================================================================
-- OBJECT ESP (dengan Custom ESP support)
-- ============================================================================
local function createObjectESP(obj, objType)
    if generatorEspHighlights[obj] then return end
    local key = objType:lower()
    if not config.espCustom[key] then return end
    if not config.espCustom[key].enabled then return end
    local color = config.espCustom[key].color
    local highlight = applyHighlight(obj, color)
    generatorEspHighlights[obj] = highlight
    if objType == "Generator" then
        updateGeneratorProgress(obj)
    end
end

local function removeObjectESP(obj)
    local highlight = generatorEspHighlights[obj]
    if highlight then highlight:Destroy() end
    generatorEspHighlights[obj] = nil
    local bill = obj:FindFirstChild("GenBitchHook")
    if bill then bill:Destroy() end
end

local function clearObjectESP()
    for obj, highlight in pairs(generatorEspHighlights) do
        if highlight then highlight:Destroy() end
        local bill = obj:FindFirstChild("GenBitchHook")
        if bill then bill:Destroy() end
    end
    generatorEspHighlights = {}
end

local function refreshAllObjectESP()
    clearObjectESP()
    for _, obj in ipairs(workspace:GetDescendants()) do
        local name = obj.Name
        if name == "Generator" then
            createObjectESP(obj, "Generator")
        elseif name == "Hook" then
            createObjectESP(obj, "Hook")
        elseif name == "Gate" then
            createObjectESP(obj, "Gate")
        elseif name:lower():find("scp") then
            createObjectESP(obj, "SCP")
        elseif name == "Pallet" or name == "Palletwrong" then
            createObjectESP(obj, "Pallet")
        elseif name == "Windows" or name:lower():find("inviswall") then
            createObjectESP(obj, "inviswall")
        end
    end
    print("[ESP] Object ESP refreshed with custom settings")
end

local function onDescendantAdded(instance)
    if not config.espEnabled then return end
    local name = instance.Name
    if name == "Generator" then
        createObjectESP(instance, "Generator")
    elseif name == "Hook" then
        createObjectESP(instance, "Hook")
    elseif name == "Gate" then
        createObjectESP(instance, "Gate")
    elseif name:lower():find("scp") then
        createObjectESP(instance, "SCP")
    elseif name == "Pallet" or name == "Palletwrong" then
        createObjectESP(instance, "Pallet")
    elseif name == "Windows" or name:lower():find("inviswall") then
        createObjectESP(instance, "inviswall")
    end
end

local function onDescendantRemoving(instance)
    if generatorEspHighlights[instance] then
        removeObjectESP(instance)
    end
end

local function periodicObjectScan()
    if not config.espEnabled then return end
    local now = tick()
    if now - lastObjectScanTime >= OBJECT_SCAN_INTERVAL then
        lastObjectScanTime = now
        refreshAllObjectESP()
    end
end

-- ============================================================================
-- START / STOP / UPDATE ESP
-- ============================================================================
local function startESP()
    if espConnection then return end
    if espDescendantAddedConn then espDescendantAddedConn:Disconnect() end
    if espDescendantRemovingConn then espDescendantRemovingConn:Disconnect() end
    if espPlayerAddedConn then espPlayerAddedConn:Disconnect() end
    if espPlayerRemovingConn then espPlayerRemovingConn:Disconnect() end
    if espProgressUpdateConn then espProgressUpdateConn:Disconnect() end
    if espPeriodicScanConn then espPeriodicScanConn:Disconnect() end

    espPlayerAddedConn = Players.PlayerAdded:Connect(function(player)
        if config.espEnabled then
            task.wait(1)
            createHighlightForPlayer(player)
        end
    end)
    espPlayerRemovingConn = Players.PlayerRemoving:Connect(function(player)
    local data = espHighlights[player.UserId]
    if data then
        if data.Highlight then data.Highlight:Destroy() end
        if data.Billboard then data.Billboard:Destroy() end
        if data.Beam then data.Beam:Destroy() end
        if data.StartAttachment then data.StartAttachment:Destroy() end
        if data.EndAttachment then data.EndAttachment:Destroy() end
        if data.TeamChanged then data.TeamChanged:Disconnect() end
        if data.DistanceUpdate then data.DistanceUpdate:Disconnect() end
        if data.BeamUpdate then data.BeamUpdate:Disconnect() end
        if data.TargetCharAdded then data.TargetCharAdded:Disconnect() end
        if data.LocalCharAdded then data.LocalCharAdded:Disconnect() end
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

    espDescendantAddedConn = workspace.DescendantAdded:Connect(onDescendantAdded)
    espDescendantRemovingConn = workspace.DescendantRemoving:Connect(onDescendantRemoving)
    refreshAllObjectESP()
    espPeriodicScanConn = RunService.Heartbeat:Connect(periodicObjectScan)
    espProgressUpdateConn = RunService.Heartbeat:Connect(function()
        if config.espEnabled then
            updateAllGeneratorProgress()
        end
    end)

    espConnection = RunService.Heartbeat:Connect(function()
        if config.espEnabled then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= localPlayer then
                    local currentChar = player.Character
                    local stored = espHighlights[player.UserId]
                    if not stored or not stored.Highlight or stored.Highlight.Adornee ~= currentChar then
                        createHighlightForPlayer(player)
                    end
                end
            end
        else
            for _, data in pairs(espHighlights) do
                if data.Highlight then data.Highlight:Destroy() end
                if data.Billboard then data.Billboard:Destroy() end
                if data.TeamChanged then data.TeamChanged:Disconnect() end
            end
            espHighlights = {}
            clearObjectESP()
        end
    end)

    print("[ESP] ESP started with custom settings")
end

local function stopESP()
    if espConnection then
        espConnection:Disconnect()
        espConnection = nil
    end
    if espDescendantAddedConn then espDescendantAddedConn:Disconnect() end
    if espDescendantRemovingConn then espDescendantRemovingConn:Disconnect() end
    if espPlayerAddedConn then espPlayerAddedConn:Disconnect() end
    if espPlayerRemovingConn then espPlayerRemovingConn:Disconnect() end
    if espProgressUpdateConn then espProgressUpdateConn:Disconnect() end
    if espPeriodicScanConn then espPeriodicScanConn:Disconnect() end

    for _, data in pairs(espHighlights) do
    if data.Highlight then data.Highlight:Destroy() end
    if data.Billboard then data.Billboard:Destroy() end
    if data.Beam then data.Beam:Destroy() end
    if data.StartAttachment then data.StartAttachment:Destroy() end
    if data.EndAttachment then data.EndAttachment:Destroy() end
    if data.TeamChanged then data.TeamChanged:Disconnect() end
    if data.DistanceUpdate then data.DistanceUpdate:Disconnect() end
    if data.BeamUpdate then data.BeamUpdate:Disconnect() end
    if data.TargetCharAdded then data.TargetCharAdded:Disconnect() end
    if data.LocalCharAdded then data.LocalCharAdded:Disconnect() end
end
espHighlights = {}
    clearObjectESP()
    print("[ESP] ESP stopped")
end

-- ============================================================================
-- UPDATE ALL ESP (dipanggil dari toggle utama)
-- ============================================================================
-- Perbaiki updateAllESP()
local function updateAllESP()
    if config.espEnabled then
        -- Aktifkan semua custom ESP secara kolektif
        for key, _ in pairs(config.espCustom) do
            config.espCustom[key].enabled = true
        end
        startESP()
    else
        -- Reset semua custom ESP ke false
        for key, _ in pairs(config.espCustom) do
            config.espCustom[key].enabled = false
        end
        stopESP()
    end
end

-- Fungsi refresh custom ESP (dipanggil dari GUI saat toggle/warna berubah di sidebar About)
local function refreshCustomESP()
    refreshAllObjectESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            createHighlightForPlayer(player)
        end
    end
    print("[ESP] Custom ESP refreshed")
end
-- ============================================================================
-- CATATAN: Kode di atas menggantikan seluruh bagian ESP SYSTEM dalam script utama.
-- Upgrade: 
-- 1. Menambahkan deteksi SCP entity (objek dengan nama mengandung "scp") dengan warna ungu.
-- 2. Semua highlight (player dan objek) menjadi lebih transparan (FillTransparency = 0.75).
-- 3. Outline tetap jelas (OutlineTransparency = 0.2).
-- Fungsi updateAllESP() tetap dipanggil untuk mengaktifkan/menonaktifkan ESP.
-- ============================================================================
-- ============================================================================
-- TPWALK NAMESPACE
-- ============================================================================

local TPWALK_SYSTEM = {}

TPWALK_SYSTEM.Active = false
TPWALK_SYSTEM.Speed = 1
TPWALK_SYSTEM.Connection = nil
TPWALK_SYSTEM.LastMoveDirection = Vector3.zero
TPWALK_SYSTEM.CharacterConnection = nil

-- ============================================================================
-- FUNGSI UTAMA TPWALK
-- ============================================================================

local function startTPWalk(speed)

    if TPWALK_SYSTEM.Active then
        return
    end

    TPWALK_SYSTEM.Active = true

    local char = localCharacter
    local hum = char and char:FindFirstChildWhichIsA("Humanoid")

    if not hum then
        TPWALK_SYSTEM.Active = false
        return
    end

    -- Gunakan Heartbeat agar sinkron dengan physics Roblox
    TPWALK_SYSTEM.Connection =
        RunService.Heartbeat:Connect(function(deltaTime)

        if not TPWALK_SYSTEM.Active then
            return
        end

        if not config.speedBoostEnabled then
            return
        end

        if not localCharacter
            or not localHumanoid
            or not localRootPart then
            return
        end

        -- Pastikan humanoid masih hidup
        if localHumanoid.Health <= 0 then
            stopTPWalk()
            return
        end

        -- Simpan arah depan karakter
        TPWALK_SYSTEM.LastMoveDirection =
            localRootPart.CFrame.LookVector.Unit

        -- Velocity correction ringan
        local currentVelocity =
            localRootPart.AssemblyLinearVelocity

        localRootPart.AssemblyLinearVelocity =
            Vector3.new(
                currentVelocity.X,
                0,
                currentVelocity.Z
            )

        -- Hitung perpindahan maju
        local movementOffset =
            TPWALK_SYSTEM.LastMoveDirection *
            speed *
            deltaTime

        -- Target posisi baru
        local targetCFrame =
            localRootPart.CFrame + movementOffset

        -- Teleport smooth menggunakan PivotTo
        pcall(function()

            localCharacter:PivotTo(targetCFrame)

        end)

        -- Anti-air correction
        if localHumanoid.FloorMaterial == Enum.Material.Air then

            local airVelocity =
                localRootPart.AssemblyLinearVelocity

            localRootPart.AssemblyLinearVelocity =
                Vector3.new(
                    airVelocity.X,
                    0,
                    airVelocity.Z
                )

        end

        -- Character validation
        if not localCharacter
            or localCharacter ~= char then

            stopTPWalk()

        end

    end)

    print(
        "[SpeedBoost] Continuous Forward TPWalk Active | Speed = "
        .. tostring(speed)
        .. " stud/s"
    )

end

-- ============================================================================
-- STOP TPWALK
-- ============================================================================

local function stopTPWalk()

    if TPWALK_SYSTEM.Connection then

        TPWALK_SYSTEM.Connection:Disconnect()
        TPWALK_SYSTEM.Connection = nil

    end

    TPWALK_SYSTEM.Active = false
    TPWALK_SYSTEM.LastMoveDirection = Vector3.zero

end

-- ============================================================================
-- CHARACTER ADDED
-- ============================================================================

local function onCharacterAddedForTPWalk()

    if config.speedBoostEnabled then

        stopTPWalk()

        task.wait(0.25)

        startTPWalk(TPWALK_SYSTEM.Speed)

    end

end

-- ============================================================================
-- SPEED BOOST UTAMA
-- ============================================================================

local function applySpeedBoost()
    -- Kompatibilitas
end

-- ============================================================================
-- MONITOR UTAMA
-- ============================================================================

local function startSpeedBoostMonitor()

    if currentBoostConnection then
        return
    end

    currentBoostConnection =
        RunService.Heartbeat:Connect(function()

        if not config.speedBoostEnabled then

            if TPWALK_SYSTEM.Active then
                stopTPWalk()
            end

            return
        end

        if not getLocalCharacter()
            or not localHumanoid
            or not localRootPart then

            if TPWALK_SYSTEM.Active then
                stopTPWalk()
            end

            return
        end

        -- Pastikan TPWalk aktif
        if not TPWALK_SYSTEM.Active then

            startTPWalk(TPWALK_SYSTEM.Speed)

        end

    end)

    -- Hindari connection duplicate
    if TPWALK_SYSTEM.CharacterConnection then
        TPWALK_SYSTEM.CharacterConnection:Disconnect()
    end

    TPWALK_SYSTEM.CharacterConnection =
        localPlayer.CharacterAdded:Connect(
            onCharacterAddedForTPWalk
        )

    print(
        "[SpeedBoost] TPWalk Monitor Active | Speed = "
        .. tostring(TPWALK_SYSTEM.Speed)
    )

end

-- ============================================================================
-- STOP MONITOR
-- ============================================================================

local function stopSpeedBoostMonitor()

    if currentBoostConnection then

        currentBoostConnection:Disconnect()
        currentBoostConnection = nil

    end

    if TPWALK_SYSTEM.CharacterConnection then

        TPWALK_SYSTEM.CharacterConnection:Disconnect()
        TPWALK_SYSTEM.CharacterConnection = nil

    end

    stopTPWalk()

    print("[SpeedBoost] TPWalk stopped")

end
-- ============================================================================
-- STEALTH INVISIBILITY (UPGRADED - SEAT METHOD + PRE-TELEPORT)
-- Fitur: Sebelum invisible, pemain dinaikkan 90 studs ke atas, lalu di-invisible,
--        kemudian dikembalikan ke posisi semula. Metode seat tetap digunakan.
-- ============================================================================

-- Variabel state untuk sistem seat
local currentSeat = nil
local seatWeld = nil
local isSeatActive = false
local seatTeleportPosition = Vector3.new(-25.95, 400, 3537.55)  -- dari script referensi
local voidLevelYThreshold = -50
local seatReturnHeartbeatConnection = nil

-- Fungsi untuk mulai memantau karakter agar tetap di seat (jika perlu)
local function startSeatReturnHeartbeat()
    if seatReturnHeartbeatConnection then
        seatReturnHeartbeatConnection:Disconnect()
        seatReturnHeartbeatConnection = nil
    end
    seatReturnHeartbeatConnection = RunService.Heartbeat:Connect(function()
        -- Kosongkan atau isi sesuai kebutuhan (bisa untuk mempertahankan posisi)
    end)
end

local function stopSeatReturnHeartbeat()
    if seatReturnHeartbeatConnection then
        seatReturnHeartbeatConnection:Disconnect()
        seatReturnHeartbeatConnection = nil
    end
end

-- Set transparency untuk seluruh karakter
local function setCharacterTransparency(transparency)
    if not localCharacter then return end
    for _, part in ipairs(localCharacter:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.Transparency = transparency
        end
    end
end

-- ** Fungsi utama makeInvisible (menggunakan metode seat + pre-teleport) **
local function makeInvisible()
    if not config.stealthEnabled then return end
    if isInvisible then return end
    if not localCharacter then return end

    -- ========== TAMBAHAN: TELEPORT KE ATAS (90 studs) ==========
    local humanoidRootPart = localCharacter:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        print("[Stealth] Cannot make invisible: No HumanoidRootPart")
        return
    end
    local originalCFrame = humanoidRootPart.CFrame
    local upPosition = originalCFrame.Position + Vector3.new(0, -90, 0)
    pcall(function() humanoidRootPart.CFrame = CFrame.new(upPosition) end)
    task.wait(0.05)
    -- =========================================================

    -- Bersihkan seat lama jika ada
    if currentSeat then
        pcall(function() currentSeat:Destroy() end)
        currentSeat = nil
        seatWeld = nil
    end
    stopSeatReturnHeartbeat()
    isSeatActive = false

    -- Simpan posisi asli untuk fallback (posisi setelah teleport ke atas)
    local savedpos = humanoidRootPart.CFrame

    -- Teleport ke posisi seat (posisi tetap dari script referensi)
    pcall(function() localCharacter:MoveTo(seatTeleportPosition) end)
    task.wait(0.05)

    -- Cek apakah teleport gagal (masuk void)
    if not localCharacter:FindFirstChild("HumanoidRootPart") or 
       localCharacter.HumanoidRootPart.Position.Y < voidLevelYThreshold then
        pcall(function() localCharacter:MoveTo(savedpos) end)
        print("[Stealth] Teleport to seat failed (void). Aborting.")
        -- Kembalikan ke posisi semula (setelah teleport ke atas)
        pcall(function() humanoidRootPart.CFrame = originalCFrame end)
        return
    end

    -- Buat seat baru
    local Seat = Instance.new('Seat')
    Seat.Name = 'CyberHeroes_Seat'
    Seat.Anchored = false
    Seat.CanCollide = false
    Seat.Transparency = 1
    Seat.Position = seatTeleportPosition
    Seat.Parent = workspace

    -- Weld ke torso
    local torso = localCharacter:FindFirstChild("Torso") or localCharacter:FindFirstChild("UpperTorso")
    if torso then
        seatWeld = Instance.new("Weld")
        seatWeld.Part0 = Seat
        seatWeld.Part1 = torso
        seatWeld.Parent = Seat
        task.wait()
        pcall(function() Seat.CFrame = savedpos end)
        currentSeat = Seat
        startSeatReturnHeartbeat()
        isSeatActive = true
    else
        Seat:Destroy()
        print("[Stealth] Cannot make invisible: No torso found")
        -- Kembalikan ke posisi semula
        pcall(function() humanoidRootPart.CFrame = originalCFrame end)
        return
    end

    -- Set transparency (default 0.75 dari script referensi)
    setCharacterTransparency(0.75)
    isInvisible = true

    -- ========== TAMBAHAN: KEMBALI KE POSISI SEMULA (setelah invisibility aktif) ==========
    pcall(function() humanoidRootPart.CFrame = originalCFrame end)
    print("[Stealth] Invisibility enabled (seat method) with pre-teleport up 90 studs")
end

-- ** Fungsi makeVisible (tidak berubah) **
local function makeVisible()
    if not isInvisible then return end
    if not localCharacter then return end

    -- Hancurkan seat dan weld
    if currentSeat then
        pcall(function() currentSeat:Destroy() end)
        currentSeat = nil
        seatWeld = nil
    end
    stopSeatReturnHeartbeat()
    isSeatActive = false

    -- Kembalikan transparency ke 0
    setCharacterTransparency(0)

    isInvisible = false
    print("[Stealth] Invisibility disabled")
end

-- ** Start/Stop Stealth Monitor (tetap sama) **
local function startStealthMonitor()
    if stealthConnection then return end
    if config.stealthEnabled then
        makeInvisible()
    end
    stealthConnection = RunService.Heartbeat:Connect(function()
        if config.stealthEnabled and not isInvisible then
            makeInvisible()
        elseif not config.stealthEnabled and isInvisible then
            makeVisible()
        end
    end)
    print("[Stealth] Stealth monitor started (seat method + pre-teleport)")
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
-- FEATURE 6: GOD MODE (HEALTH REGEN + STEALTH WITH DISTANCE TRIGGER)
-- Stealth aktif saat killer dalam jarak ≤ config.stealthTriggerDistance
-- Stealth nonaktif saat jarak > config.stealthTriggerDistance
-- Menggunakan salinan fungsi stealth internal (tidak konflik dengan fitur Stealth asli)
-- ============================================================================

-- Variabel untuk koneksi god mode (health regen + teleport)
local godModeConnection = nil

-- Konfigurasi jarak trigger teleport (dapat diubah)
if config.teleportTriggerDistance == nil then
    config.teleportTriggerDistance = 15   -- jarak dalam studs untuk memicu teleport
end
if config.teleportAwayDistance == nil then
    config.teleportAwayDistance = 16      -- jarak teleport mundur menjauhi killer
end

-- Cooldown untuk mencegah spam teleport
local lastTeleportTime = 0
local TELEPORT_COOLDOWN = 0.5  -- detik

-- ============================================================================
-- FUNGSI UTAMA: Teleportasi mundur menjauhi killer terdekat
-- ============================================================================
local function teleportAwayFromNearestKiller()
    if not getLocalCharacter() or not localRootPart then return end
    local localPos = localRootPart.Position
    local nearestKiller = nil
    local nearestDist = math.huge

    -- Cari killer terdekat
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local char = player.Character
            if char then
                local isKiller = false
                if player.Team then
                    local teamName = player.Team.Name:lower()
                    if teamName:find("killer") or teamName:find("monster") or teamName:find("enemy") then
                        isKiller = true
                    end
                end
                if not isKiller then
                    local tool = char:FindFirstChildWhichIsA("Tool")
                    if tool and (tool.Name:lower():find("knife") or tool.Name:lower():find("weapon")) then
                        isKiller = true
                    end
                end
                if isKiller then
                    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                    if root then
                        local dist = (localPos - root.Position).Magnitude
                        if dist < nearestDist then
                            nearestDist = dist
                            nearestKiller = root
                        end
                    end
                end
            end
        end
    end

    -- Jika tidak ada killer atau jarak > trigger distance, abaikan
    if not nearestKiller then return end
    if nearestDist > config.teleportTriggerDistance then return end

    -- Cek cooldown
    local now = tick()
    if now - lastTeleportTime < TELEPORT_COOLDOWN then return end
    lastTeleportTime = now

    -- Hitung arah dari killer ke player
    local killerPos = nearestKiller.Position
    local dirAway = (localPos - killerPos).Unit  -- arah menjauhi killer
    local newPos = localPos + dirAway * config.teleportAwayDistance

    -- Pastikan tidak jatuh ke void
    if newPos.Y < -50 then
        newPos = Vector3.new(newPos.X, 5, newPos.Z)
    end

    -- Teleport karakter lokal ke posisi baru
    local char = localPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(newPos)
            -- Reset velocity agar tidak melayang
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            print("[GodMode] Teleported away from killer, distance:", nearestDist)
        end
    end
end

-- ============================================================================
-- START / STOP GOD MODE
-- ============================================================================
local function startGodMode()
    if godModeConnection then return end

    -- Health regen + teleport checker dalam satu koneksi
    godModeConnection = RunService.Heartbeat:Connect(function()
        if not config.godModeEnabled then return end
        if not getLocalCharacter() or not localHumanoid then return end

        -- Health regen
        local maxHealth = localHumanoid.MaxHealth
        if localHumanoid.Health < maxHealth then
            localHumanoid.Health = maxHealth
        end

        -- Teleport checker (jika ada killer terdekat dalam radius)
        teleportAwayFromNearestKiller()
    end)

    print("[GodMode] Activated: Health regen + Teleport away from killer when within " .. config.teleportTriggerDistance .. " studs")
end

local function stopGodMode()
    if godModeConnection then
        godModeConnection:Disconnect()
        godModeConnection = nil
    end
    print("[GodMode] Deactivated: Health regen and teleport stopped")
end
-- ============================================================================

-- FEATURE 7: AUTO PARRY / AUTO BLOCK (FIXED - USING CORRECT REMOTE EVENT)        
-- Berdasarkan hasil scanning: ReplicatedStorage.Remotes.Items.Parrying Dagger.parry        
-- ============================================================================        
-- ============================================
-- PARRY VIA ACTION BUTTON (DOUBLE-CLICK MOUSE1)
-- ============================================

-- Cari tombol "action" di PlayerGui.Survivor-mob.Controls
-- ============================================
-- PARRY VIA REMOTE EVENT + ACTION BUTTON
-- ============================================

-- Cari RemoteEvent parry
-- Cari RemoteEvent parry dan parryResult (sekaligus)
local function findParryRemotes()
    local path = game:GetService("ReplicatedStorage")
    path = path and path:FindFirstChild("Remotes")
    path = path and path:FindFirstChild("Items")
    path = path and path:FindFirstChild("Parrying Dagger")
    
    local parry = path and path:FindFirstChild("parry")
    local parryResult = path and path:FindFirstChild("parryResult")
    
    return parry, parryResult
end

-- Cari tombol action
local function findActionButton()
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    local survivorMob = playerGui:FindFirstChild("Survivor-mob")
    if not survivorMob then return nil end
    local controls = survivorMob:FindFirstChild("Controls")
    if not controls then return nil end
    return controls:FindFirstChild("action")
end

-- Fungsi utama: remote event dulu, lalu action button
local function fireParryRemote(player)
    local parry, parryResult = findParryRemotes()
    
    if parry then
        pcall(function()
            parry:FireServer()
            parry:FireServer("parry")
            parry:FireServer("Parrying Dagger")
        end)
    end
    
    if parryResult then
        pcall(function()
            parryResult:FireServer()
            parryResult:FireServer("parryResult")
            parryResult:FireServer("Parrying Dagger")
        end)
    end

    -- Trigger tombol action untuk efek visual & cooldown
    local button = findActionButton()
    if button then
        local pos = button.AbsolutePosition
        local size = button.AbsoluteSize
        if size.X > 0 and size.Y > 0 then
            local cx = pos.X + size.X/2
            local cy = pos.Y + size.Y/2
            local vim = game:GetService("VirtualInputManager")
            -- Double-click cepat (2x klik)
            for i = 1, 2 do
                pcall(function()
                    vim:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
                    task.wait(0)
                    vim:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
                end)
                if i == 1 then task.wait(0) end
            end
        end
    end

    return true
end
-- (Hapus semua fungsi lama: TouchID, ActionPath, GetActionTarget, TriggerGUIAction, spamParryButton, fallbackParry)
-- ============================================================================        
-- AUTO PARRY MAIN LOOP        
-- ============================================================================ 
local combatHeartbeat = nil
local radiusFolder = nil

local function autoParryLoop()
    if combatStateConnected then return end
    combatStateConnected = true

    -- ================================
    -- STATE (persistent, tidak bergantung GUI)
    -- ================================
    local DETECTION_RADIUS = 9.6
    local sliderRadius = 9.6
    local loopingActive = false
    local fakeParryActive = false
    local selectedAnimIndex = 1
    local configGuiPosition = UDim2.new(0.85, -170, 0.5, -180)

    local ANIMATION_LIST = {"Parry 1", "Parry 2", "Parry 3", "Parry 4"}
    local ANIMATION_IDS = {
        "rbxassetid://109133187196613",
        "rbxassetid://123307242865945",
        "rbxassetid://127096285501517",
        "rbxassetid://126894569253341"
    }

    -- ================================
    -- CONNECTION TABLES
    -- ================================
    local coreConnections = {}
    local guiConnections = {}
    local hookedPlayers = {}

    -- ================================
    -- FREEZE SYSTEM
    -- ================================
    local freezeActive = false
    local freezeConnection = nil
    local originalWalkSpeed = nil
    local originalJumpPower = nil

    local function applyFreeze()
        local char = localPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if originalWalkSpeed == nil then
            originalWalkSpeed = hum.WalkSpeed
            originalJumpPower = hum.JumpPower
        end
        hum.WalkSpeed = 0
        hum.JumpPower = 0
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end

    local function restoreMovement()
        local char = localPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if originalWalkSpeed ~= nil then
            hum.WalkSpeed = originalWalkSpeed
            hum.JumpPower = originalJumpPower
            originalWalkSpeed = nil
            originalJumpPower = nil
        end
    end

    local function startFreeze(duration)
        if freezeConnection then
            freezeConnection:Disconnect()
            freezeConnection = nil
        end
        if freezeActive then return end
        freezeActive = true
        applyFreeze()
        freezeConnection = RunService.RenderStepped:Connect(function()
            if not freezeActive then
                freezeConnection:Disconnect()
                freezeConnection = nil
                return
            end
            applyFreeze()
        end)
        task.spawn(function()
            task.wait(duration)
            freezeActive = false
            if freezeConnection then
                freezeConnection:Disconnect()
                freezeConnection = nil
            end
            restoreMovement()
        end)
    end

    -- ================================
    -- CORE FUNCTIONS
    -- ================================
    local function playLocalParryAnimation(animId)
        local char = localPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then return end
        local anim = Instance.new("Animation")
        anim.AnimationId = animId
        local track = animator:LoadAnimation(anim)
        if track then
            track.Priority = Enum.AnimationPriority.Action
            track:Play()
        end
    end

    local function triggerFakeParry()
        if not fakeParryActive then return end
        task.spawn(function()
            playLocalParryAnimation(ANIMATION_IDS[selectedAnimIndex])
        end)
        task.spawn(function()
            startFreeze(1.5)
        end)
    end

    local COMBAT_ANIMATIONS = {
        "rbxassetid://110355011987939",
        "rbxassetid://139369275981139",
        "rbxassetid://105374834496520",
        "rbxassetid://111920872708571",
        "rbxassetid://117042998468241",
        "rbxassetid://133963973694098",
        "rbxassetid://129784271201071",
        "rbxassetid://132817836308238",
        "rbxassetid://82666958311998",
        "rbxassetid://130012819736632",
        "rbxassetid://113255068724446",
        "rbxassetid://74968262036854",
        "rbxassetid://122812055447896",
        "rbxassetid://78935059863801",
        "rbxassetid://135002183282873",
        "rbxassetid://121216847022485",
        "rbxassetid://118907603246885",
        "rbxassetid://78432063483146",
        "rbxassetid://105374834496520",
        "rbxassetid://111920872708571",
        "rbxassetid://115244153053858",
        "rbxassetid://130593238885843",
        "rbxassetid://80411309607666",
        "rbxassetid://98163597193511",
        "rbxassetid://88848807662765",
        "rbxassetid://123809268724645"
    }

    local function isCombatAnimation(animId)
        for _, id in ipairs(COMBAT_ANIMATIONS) do
            if animId == id then return true end
        end
        return false
    end

    local function getRoot(char)
        return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    end

    local function isPlayerKiller(player)
        if not player or player == localPlayer then return false end
        if player.Team then
            local teamName = player.Team.Name:lower()
            if teamName:find("killer") or teamName:find("monster") or teamName:find("enemy") then
                return true
            end
        end
        local char = player.Character
        if char then
            local tool = char:FindFirstChildWhichIsA("Tool")
            if tool and (tool.Name:lower():find("knife") or tool.Name:lower():find("weapon") or tool.Name:lower():find("blade")) then
                return true
            end
            for _, child in ipairs(char:GetChildren()) do
                if child.Name:lower():find("scp") then
                    return true
                end
            end
        end
        return false
    end

    local function getDistanceToPlayer(player)
        if not localRootPart or not player or not player.Character then return math.huge end
        local targetRoot = player.Character:FindFirstChild("HumanoidRootPart") or player.Character:FindFirstChild("Torso")
        if not targetRoot then return math.huge end
        return (localRootPart.Position - targetRoot.Position).Magnitude
    end

    -- ========== HOOK ANIMASI (TRIGGER PARRY) ==========
    local function hookAnimator(player, char)
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then
            local waitConn = char.DescendantAdded:Connect(function(obj)
                if obj:IsA("Animator") and obj.Parent == hum then
                    waitConn:Disconnect()
                    hookAnimator(player, char)
                end
            end)
            table.insert(coreConnections, waitConn)
            return
        end

        local animConn = animator.AnimationPlayed:Connect(function(track)
            local anim = track.Animation
            if not anim then return end
            local animId = anim.AnimationId
            if not animId then return end

            if isCombatAnimation(animId) then
                local dist = getDistanceToPlayer(player)
                if dist <= DETECTION_RADIUS then
                    task.spawn(function()
                        pcall(function() fireParryRemote(player) end)
                    end)
                end
            end
        end)
        table.insert(coreConnections, animConn)
        print("[AutoParry] Animator hooked for", player.Name)
    end

    local function hookCharacter(player, char)
        if not isPlayerKiller(player) then return end
        hookAnimator(player, char)
    end

    local function setupPlayer(player)
        if player == localPlayer then return end

        local teamConn = player:GetPropertyChangedSignal("Team"):Connect(function()
            if isPlayerKiller(player) then
                print("[AutoParry] Player", player.Name, "became killer. Hooking...")
                if player.Character then
                    hookCharacter(player, player.Character)
                end
            end
        end)
        table.insert(coreConnections, teamConn)

        local charConn = player.CharacterAdded:Connect(function(char)
            if isPlayerKiller(player) then
                hookCharacter(player, char)
            end
        end)
        table.insert(coreConnections, charConn)

        if player.Character and isPlayerKiller(player) then
            hookCharacter(player, player.Character)
        end
    end

    local function refreshKillers()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= localPlayer then
                if isPlayerKiller(player) then
                    if not hookedPlayers[player] then
                        hookedPlayers[player] = true
                        setupPlayer(player)
                    end
                else
                    hookedPlayers[player] = nil
                end
            end
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            setupPlayer(player)
        end
    end

    local playerConn = Players.PlayerAdded:Connect(function(player)
        setupPlayer(player)
    end)
    table.insert(coreConnections, playerConn)

    local scanConnection = RunService.Heartbeat:Connect(function()
        refreshKillers()
    end)
    table.insert(coreConnections, scanConnection)

    -- ========== ESP ==========
    if radiusFolder then radiusFolder:Destroy() end
    radiusFolder = Instance.new("Folder")
    radiusFolder.Name = "ParryESP"
    radiusFolder.Parent = workspace

    local espRing = Instance.new("Part")
    espRing.Name = "RadiusRing"
    espRing.Shape = Enum.PartType.Cylinder
    espRing.Material = Enum.Material.Neon
    espRing.Color = Color3.fromRGB(255, 50, 50)
    espRing.Transparency = 0.8
    espRing.Anchored = true
    espRing.CanCollide = false
    espRing.Size = Vector3.new(0.05, DETECTION_RADIUS*2, DETECTION_RADIUS*2)
    espRing.Parent = radiusFolder

    local ringLight = Instance.new("PointLight")
    ringLight.Color = Color3.fromRGB(255, 50, 50)
    ringLight.Brightness = 2
    ringLight.Range = DETECTION_RADIUS * 1.5
    ringLight.Parent = espRing

    -- ================================
    -- FAKE PARRY BUTTON (ScreenGui sendiri) - Fixed Position, No Drag
    -- ================================
    local fakeButtonGui = nil
    local fakeButton = nil

    local function createFakeButton()
        if fakeButton then return end
        if not fakeParryActive then return end

        fakeButtonGui = Instance.new("ScreenGui")
        fakeButtonGui.Name = "FakeParryButton"
        fakeButtonGui.ResetOnSpawn = false
        fakeButtonGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        fakeButtonGui.Parent = game.CoreGui

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 60, 0, 60)
        btn.Position = UDim2.new(0.63, 0, 0.73, 0)  -- posisi tetap, tidak bisa drag
        btn.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
        btn.BackgroundTransparency = 0.5
        btn.BorderSizePixel = 0
        btn.Text = "Ctrl"
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 18
        btn.Parent = fakeButtonGui
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(1, 0)
        btnCorner.Parent = btn
        local btnStroke = Instance.new("UIStroke")
        btnStroke.Color = Color3.fromRGB(0, 220, 255)
        btnStroke.Thickness = 1.5
        btnStroke.Transparency = 0.4
        btnStroke.Parent = btn

        fakeButton = btn

        -- Hanya klik, tidak ada drag
        btn.MouseButton1Click:Connect(function()
            triggerFakeParry()
        end)
    end

    local function destroyFakeButton()
        if fakeButtonGui then
            fakeButtonGui:Destroy()
            fakeButtonGui = nil
            fakeButton = nil
        end
    end

    -- ================================
    -- GUI SETTINGS
    -- ================================
    local parryConfigGui = nil
    local guiActive = false

    local function createParryConfigGUI()
        if parryConfigGui then
            parryConfigGui.Enabled = true
            return
        end

        local gui = Instance.new("ScreenGui")
        gui.Name = "AutoParryConfig"
        gui.ResetOnSpawn = false
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.Parent = game.CoreGui

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 240, 0, 280)
        frame.Position = configGuiPosition
        frame.BackgroundColor3 = Color3.fromRGB(12, 22, 38)
        frame.BackgroundTransparency = 0.1
        frame.BorderSizePixel = 0
        frame.Parent = gui
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = frame
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(0, 180, 255)
        stroke.Thickness = 1.2
        stroke.Transparency = 0.4
        stroke.Parent = frame

        local header = Instance.new("Frame")
        header.Size = UDim2.new(1, 0, 0, 24)
        header.BackgroundColor3 = Color3.fromRGB(18, 28, 44)
        header.BorderSizePixel = 0
        header.Parent = frame
        local headerCorner = Instance.new("UICorner")
        headerCorner.CornerRadius = UDim.new(0, 8)
        headerCorner.Parent = header
        local headerStroke = Instance.new("UIStroke")
        headerStroke.Color = Color3.fromRGB(0, 180, 255)
        headerStroke.Transparency = 0.5
        headerStroke.Parent = header

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(0.7, 0, 1, 0)
        title.Position = UDim2.new(0.02, 0, 0, 0)
        title.BackgroundTransparency = 1
        title.Text = "Auto Parry Config"
        title.TextColor3 = Color3.fromRGB(0, 220, 255)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 12
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = header

        -- Drag GUI
        local function startDrag(input)
            local dragConn = game:GetService("UserInputService").InputChanged:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
                    local delta = inp.Position - input.Position
                    local newX = frame.Position.X.Offset + delta.X
                    local newY = frame.Position.Y.Offset + delta.Y
                    frame.Position = UDim2.new(frame.Position.X.Scale, newX, frame.Position.Y.Scale, newY)
                    configGuiPosition = frame.Position
                end
            end)
            local endConn = game:GetService("UserInputService").InputEnded:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                    dragConn:Disconnect()
                    endConn:Disconnect()
                end
            end)
            table.insert(guiConnections, dragConn)
            table.insert(guiConnections, endConn)
        end

        header.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                startDrag(input)
            end
        end)

        -- Tombol close (hanya tutup GUI)
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 20, 0, 20)
        closeBtn.Position = UDim2.new(1, -24, 0.5, -10)
        closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        closeBtn.Text = "X"
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 12
        closeBtn.BorderSizePixel = 0
        closeBtn.Parent = header
        local closeCorner = Instance.new("UICorner")
        closeCorner.CornerRadius = UDim.new(0, 4)
        closeCorner.Parent = closeBtn

        closeBtn.MouseButton1Click:Connect(function()
            parryConfigGui:Destroy()
            parryConfigGui = nil
            for _, conn in ipairs(guiConnections) do
                pcall(function() conn:Disconnect() end)
            end
            guiConnections = {}
        end)

        -- ===== KONTEN GUI =====
        local yOffset = 30

        local radLabel = Instance.new("TextLabel")
        radLabel.Size = UDim2.new(0.6, 0, 0, 20)
        radLabel.Position = UDim2.new(0.05, 0, 0, yOffset)
        radLabel.BackgroundTransparency = 1
        radLabel.Text = "Detection Radius: " .. sliderRadius
        radLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
        radLabel.Font = Enum.Font.Gotham
        radLabel.TextSize = 11
        radLabel.Parent = frame
        yOffset = yOffset + 22

        local radBg = Instance.new("Frame")
        radBg.Size = UDim2.new(0.85, 0, 0, 4)
        radBg.Position = UDim2.new(0.075, 0, 0, yOffset)
        radBg.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
        radBg.BorderSizePixel = 0
        radBg.Parent = frame
        local radBgCorner = Instance.new("UICorner")
        radBgCorner.CornerRadius = UDim.new(1, 0)
        radBgCorner.Parent = radBg

        local radThumb = Instance.new("TextButton")
        radThumb.Size = UDim2.new(0, 12, 0, 12)
        radThumb.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
        radThumb.AutoButtonColor = false
        radThumb.Text = ""
        radThumb.BorderSizePixel = 0
        radThumb.Parent = radBg
        local thumbCorner = Instance.new("UICorner")
        thumbCorner.CornerRadius = UDim.new(1, 0)
        thumbCorner.Parent = radThumb

        local draggingRad = false
        local function updateRadUI(val)
            val = math.clamp(val, 1, 15)
            sliderRadius = val
            radLabel.Text = "Detection Radius: " .. string.format("%.1f", val)
            local rel = (val - 1) / 14
            local w = radBg.AbsoluteSize.X
            local tw = radThumb.AbsoluteSize.X
            if w > 0 then
                local px = math.clamp(rel * w, tw/2, w - tw/2)
                radThumb.Position = UDim2.new(0, px - tw/2, 0.5, -tw/2)
            end
            if not loopingActive then
                DETECTION_RADIUS = val
                espRing.Size = Vector3.new(0.05, DETECTION_RADIUS*2, DETECTION_RADIUS*2)
                ringLight.Range = DETECTION_RADIUS * 1.5
            end
        end

        task.wait(0.05)
        updateRadUI(sliderRadius)

        local function onRadDrag(mouseX)
            local bgX = radBg.AbsolutePosition.X
            local bgW = radBg.AbsoluteSize.X
            if bgW <= 0 then return end
            local rel = math.clamp((mouseX - bgX) / bgW, 0, 1)
            local val = 1 + rel * 14
            val = math.floor(val * 10 + 0.5) / 10
            updateRadUI(val)
        end

        local radThumbConn = radThumb.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingRad = true
                onRadDrag(input.Position.X)
            end
        end)
        table.insert(guiConnections, radThumbConn)

        local radBgConn = radBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingRad = true
                onRadDrag(input.Position.X)
            end
        end)
        table.insert(guiConnections, radBgConn)

        local radMove = RunService.RenderStepped:Connect(function()
            if draggingRad then
                onRadDrag(game:GetService("UserInputService"):GetMouseLocation().X)
            end
        end)
        table.insert(guiConnections, radMove)

        local radEnd = game:GetService("UserInputService").InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingRad = false
            end
        end)
        table.insert(guiConnections, radEnd)

        yOffset = yOffset + 20

        local loopToggle = Instance.new("TextButton")
        loopToggle.Size = UDim2.new(0.85, 0, 0, 24)
        loopToggle.Position = UDim2.new(0.075, 0, 0, yOffset)
        loopToggle.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
        loopToggle.Text = loopingActive and "Running MODE: ON" or "Running MODE: OFF"
        loopToggle.TextColor3 = Color3.fromRGB(220, 220, 220)
        loopToggle.Font = Enum.Font.GothamBold
        loopToggle.TextSize = 10
        loopToggle.BorderSizePixel = 0
        loopToggle.Parent = frame
        local loopCorner = Instance.new("UICorner")
        loopCorner.CornerRadius = UDim.new(0, 4)
        loopCorner.Parent = loopToggle

        local loopToggleConn = loopToggle.MouseButton1Click:Connect(function()
            loopingActive = not loopingActive
            if loopingActive then
                loopToggle.Text = "Running MODE: ON"
                loopToggle.BackgroundColor3 = Color3.fromRGB(0, 140, 200)
            else
                loopToggle.Text = "Running MODE: OFF"
                loopToggle.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
                DETECTION_RADIUS = sliderRadius
                espRing.Size = Vector3.new(0.05, DETECTION_RADIUS*2, DETECTION_RADIUS*2)
                ringLight.Range = DETECTION_RADIUS * 1.5
            end
        end)
        table.insert(guiConnections, loopToggleConn)

        yOffset = yOffset + 30

        local fakeToggle = Instance.new("TextButton")
        fakeToggle.Size = UDim2.new(0.85, 0, 0, 24)
        fakeToggle.Position = UDim2.new(0.075, 0, 0, yOffset)
        fakeToggle.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
        fakeToggle.Text = fakeParryActive and "FAKE PARRY: ON" or "FAKE PARRY: OFF"
        fakeToggle.TextColor3 = Color3.fromRGB(220, 220, 220)
        fakeToggle.Font = Enum.Font.GothamBold
        fakeToggle.TextSize = 10
        fakeToggle.BorderSizePixel = 0
        fakeToggle.Parent = frame
        local fakeCorner = Instance.new("UICorner")
        fakeCorner.CornerRadius = UDim.new(0, 4)
        fakeCorner.Parent = fakeToggle

        local fakeToggleConn = fakeToggle.MouseButton1Click:Connect(function()
            fakeParryActive = not fakeParryActive
            if fakeParryActive then
                fakeToggle.Text = "FAKE PARRY: ON"
                fakeToggle.BackgroundColor3 = Color3.fromRGB(0, 140, 200)
                createFakeButton()
            else
                fakeToggle.Text = "FAKE PARRY: OFF"
                fakeToggle.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
                destroyFakeButton()
            end
        end)
        table.insert(guiConnections, fakeToggleConn)

        yOffset = yOffset + 30

        local dropdownFrame = Instance.new("Frame")
        dropdownFrame.Size = UDim2.new(0.85, 0, 0, 24)
        dropdownFrame.Position = UDim2.new(0.075, 0, 0, yOffset)
        dropdownFrame.BackgroundColor3 = Color3.fromRGB(25, 35, 50)
        dropdownFrame.BorderSizePixel = 0
        dropdownFrame.ClipsDescendants = false
        dropdownFrame.Parent = frame
        local dropCorner = Instance.new("UICorner")
        dropCorner.CornerRadius = UDim.new(0, 4)
        dropCorner.Parent = dropdownFrame

        local dropBtn = Instance.new("TextButton")
        dropBtn.Size = UDim2.new(1, -4, 1, -4)
        dropBtn.Position = UDim2.new(0, 2, 0, 2)
        dropBtn.BackgroundTransparency = 1
        dropBtn.Text = ANIMATION_LIST[selectedAnimIndex]
        dropBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
        dropBtn.Font = Enum.Font.GothamBold
        dropBtn.TextSize = 10
        dropBtn.BorderSizePixel = 0
        dropBtn.Parent = dropdownFrame

        local dropdownList = Instance.new("Frame")
        dropdownList.Size = UDim2.new(1, 0, 0, 0)
        dropdownList.Position = UDim2.new(0, 0, 1, 2)
        dropdownList.BackgroundColor3 = Color3.fromRGB(20, 30, 45)
        dropdownList.BorderSizePixel = 0
        dropdownList.Visible = false
        dropdownList.ClipsDescendants = true
        dropdownList.ZIndex = 10
        dropdownList.Parent = dropdownFrame
        local listCorner = Instance.new("UICorner")
        listCorner.CornerRadius = UDim.new(0, 4)
        listCorner.Parent = dropdownList

        local listLayout = Instance.new("UIListLayout")
        listLayout.Padding = UDim.new(0, 2)
        listLayout.FillDirection = Enum.FillDirection.Vertical
        listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        listLayout.Parent = dropdownList

        local function rebuildDropdown()
            for _, child in ipairs(dropdownList:GetChildren()) do
                if child:IsA("TextButton") then child:Destroy() end
            end
            for i, name in ipairs(ANIMATION_LIST) do
                local opt = Instance.new("TextButton")
                opt.Size = UDim2.new(1, -4, 0, 18)
                opt.BackgroundColor3 = (i == selectedAnimIndex) and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(20, 30, 45)
                opt.Text = name
                opt.TextColor3 = (i == selectedAnimIndex) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
                opt.Font = Enum.Font.Gotham
                opt.TextSize = 9
                opt.BorderSizePixel = 0
                opt.ZIndex = 11
                opt.Parent = dropdownList
                opt.MouseButton1Click:Connect(function()
                    selectedAnimIndex = i
                    dropBtn.Text = name
                    fakeParryAnimId = ANIMATION_IDS[i]
                    dropdownList.Visible = false
                end)
            end
            local totalHeight = #ANIMATION_LIST * 20 + 4
            dropdownList.Size = UDim2.new(1, 0, 0, totalHeight)
        end
        rebuildDropdown()

        local dropToggleConn = dropBtn.MouseButton1Click:Connect(function()
            dropdownList.Visible = not dropdownList.Visible
            if dropdownList.Visible then
                rebuildDropdown()
            end
        end)
        table.insert(guiConnections, dropToggleConn)

        yOffset = yOffset + 30
        frame.Size = UDim2.new(0, 240, 0, yOffset + 10)

        parryConfigGui = gui
        guiActive = true
    end

    -- ================================
    -- SHORTCUT Ctrl
    -- ================================
    local userInputService = game:GetService("UserInputService")
    local ctrlConn = userInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
            triggerFakeParry()
        end
    end)
    table.insert(coreConnections, ctrlConn)

    -- ================================
    -- MAIN LOOP (ESP & Dynamic Radius)
    -- ================================
    combatHeartbeat = RunService.RenderStepped:Connect(function(dt)
        if not config.infiniteAmmoEnabled then
            combatStateConnected = false
            if combatHeartbeat then combatHeartbeat:Disconnect(); combatHeartbeat = nil end
            for _, conn in ipairs(coreConnections) do
                pcall(function() conn:Disconnect() end)
            end
            for _, conn in ipairs(guiConnections) do
                pcall(function() conn:Disconnect() end)
            end
            coreConnections = {}
            guiConnections = {}
            if radiusFolder then radiusFolder:Destroy(); radiusFolder = nil end
            hookedPlayers = {}
            if parryConfigGui then parryConfigGui:Destroy(); parryConfigGui = nil end
            destroyFakeButton()
            if freezeConnection then
                freezeConnection:Disconnect()
                freezeConnection = nil
            end
            freezeActive = false
            restoreMovement()
            return
        end

        local rootPart = localRootPart
        if not rootPart then
            local char = localPlayer.Character
            if char then
                rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
            end
        end

        if loopingActive then
            local nearestDist = math.huge
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= localPlayer and isPlayerKiller(player) then
                    local dist = getDistanceToPlayer(player)
                    if dist < nearestDist then
                        nearestDist = dist
                    end
                end
            end
            if nearestDist <= 11 then
                local newRadius = math.clamp(nearestDist, 1, 15)
                if DETECTION_RADIUS ~= newRadius then
                    DETECTION_RADIUS = newRadius
                    espRing.Size = Vector3.new(0.05, DETECTION_RADIUS*2, DETECTION_RADIUS*2)
                    ringLight.Range = DETECTION_RADIUS * 1.5
                end
            else
                if DETECTION_RADIUS ~= sliderRadius then
                    DETECTION_RADIUS = sliderRadius
                    espRing.Size = Vector3.new(0.05, DETECTION_RADIUS*2, DETECTION_RADIUS*2)
                    ringLight.Range = DETECTION_RADIUS * 1.5
                end
            end
        else
            if DETECTION_RADIUS ~= sliderRadius then
                DETECTION_RADIUS = sliderRadius
                espRing.Size = Vector3.new(0.05, DETECTION_RADIUS*2, DETECTION_RADIUS*2)
                ringLight.Range = DETECTION_RADIUS * 1.5
            end
        end

        if rootPart then
            local footPos = rootPart.Position - Vector3.new(0, 2, 0)
            espRing.CFrame = CFrame.new(footPos) * CFrame.Angles(0, 0, math.rad(90))
            espRing.Size = Vector3.new(0.05, DETECTION_RADIUS*2, DETECTION_RADIUS*2)
            if ringLight then ringLight.Range = DETECTION_RADIUS * 1.5 end
        end
    end)

    createParryConfigGUI()
    if fakeParryActive then
        createFakeButton()
    end

    print("[AutoParry] Animation ID detection + GUI config loaded (Fake Parry fixed position, no drag)")
end

-- ============================================================================        
-- START / STOP AUTO PARRY (menggantikan startInfiniteAmmo / stopInfiniteAmmo)        
-- ============================================================================        
local infiniteAmmoConnection = nil        
        
local function startInfiniteAmmo()        
    if infiniteAmmoConnection then return end        
    infiniteAmmoConnection = RunService.Heartbeat:Connect(autoParryLoop)        
    print("[AutoParry] Started (using remote 'parry' at correct path)")        
end        
        
local function stopInfiniteAmmo()        
    if infiniteAmmoConnection then        
        infiniteAmmoConnection:Disconnect()        
        infiniteAmmoConnection = nil        
    end        
    print("[AutoParry] Stopped")        
end
-- ============================================================================
-- PENGGANTI RESTART SCRIPT DENGAN FITUR POV (ZOOM OUT + BRIGHTNESS) - FIXED PERSISTENT
-- ============================================================================
  
-- Tambahkan di CONFIGURATION (setelah config lainnya)  
config.povEnabled = config.povEnabled or false  
  
-- Variabel untuk menyimpan nilai asli  
local originalFOV = nil  
local originalBrightness = nil  
local originalAmbient = nil  
local povConnection = nil  
local lightPart = nil  
  
-- Fungsi untuk menerapkan efek POV (dipanggil berkala)  
local function applyPOV()  
    if not config.povEnabled then return end  
    if not camera then return end  
    if originalFOV == nil then  
        originalFOV = camera.FieldOfView  
        originalBrightness = Lighting.Brightness  
        originalAmbient = Lighting.Ambient  
    end  
    camera.FieldOfView = math.clamp(originalFOV + 35, 70, 120)  
    Lighting.Brightness = 3  
    Lighting.Ambient = Color3.fromRGB(200, 200, 200)  
    Lighting.ClockTime = 14  
end  
  
-- Aktifkan POV (persistent, akan terus menjaga efek)  
local function enablePOV()  
    if povConnection then return end  
      
    if camera then  
        if originalFOV == nil then  
            originalFOV = camera.FieldOfView  
            originalBrightness = Lighting.Brightness  
            originalAmbient = Lighting.Ambient  
        end  
    end  
      
    -- Buat efek partikel cahaya (mengikuti kamera)  
    if not lightPart or not lightPart.Parent then  
        lightPart = Instance.new("Part")  
        lightPart.Name = "CyberHeroes_LightEffect"  
        lightPart.Size = Vector3.new(15,15,15)  
        lightPart.Anchored = true  
        lightPart.CanCollide = false  
        lightPart.Transparency = 0.8  
        lightPart.BrickColor = BrickColor.new("Bright yellow")  
        lightPart.Material = Enum.Material.Neon  
        lightPart.Parent = workspace  
    end  
      
    -- Koneksi utama untuk menjaga efek setiap frame (agar tidak direset oleh game)  
    povConnection = RunService.RenderStepped:Connect(function()  
        if not config.povEnabled then  
            if povConnection then povConnection:Disconnect() end  
            povConnection = nil  
            if lightPart then lightPart:Destroy() end  
            return  
        end  
        applyPOV()  
        if camera and lightPart then  
            lightPart.Position = camera.CFrame.Position  
        end  
    end)  
      
    -- Juga tangani saat karakter berganti (respawn, masuk game) yang mungkin mereset kamera  
    local function onCharacterAdded()  
        if config.povEnabled then  
            task.wait(1) -- tunggu kamera stabil  
            applyPOV()  
        end  
    end  
    if localPlayer.Character then  
        onCharacterAdded()  
    end  
    localPlayer.CharacterAdded:Connect(onCharacterAdded)  
      
    config.povEnabled = true  
    print("[POV] Zoom out + Brightness ON (persistent)")  
end  
  
-- Nonaktifkan POV  
local function disablePOV()  
    if povConnection then  
        povConnection:Disconnect()  
        povConnection = nil  
    end  
    if originalFOV and camera then  
        camera.FieldOfView = originalFOV  
    end  
    if originalBrightness then  
        Lighting.Brightness = originalBrightness  
        Lighting.Ambient = originalAmbient  
    end  
    Lighting.ClockTime = os.date("!*t").hour  -- waktu normal  
    if lightPart then lightPart:Destroy() end  
    config.povEnabled = false  
    print("[POV] Zoom out + Brightness OFF")  
end  
  
local function togglePOV()  
    if config.povEnabled then disablePOV() else enablePOV() end  
end 

-- ============================================================================      
-- FEATURE 9: AUTO ATTACK (RemoteEvent spam via BasicAttack) + Radius Detection + ESP      
-- Semua state (ESP, radius) berada di dalam performAutoAttack() agar tidak konflik.      
-- Toggle tetap menggunakan config.shieldEnabled.      
-- ============================================================================      

local attackRemote = nil

-- Cari RemoteEvent BasicAttack di ReplicatedStorage
local function findAttackRemote()
    if attackRemote and attackRemote.Parent then return attackRemote end
    local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    if remotes then
        local attacks = remotes:FindFirstChild("Attacks")
        if attacks then
            attackRemote = attacks:FindFirstChild("BasicAttack")
            if attackRemote and attackRemote:IsA("RemoteEvent") then
                return attackRemote
            end
        end
    end
    -- fallback: scan semua RemoteEvent
    for _, obj in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
        if obj:IsA("RemoteEvent") and obj.Name == "BasicAttack" then
            attackRemote = obj
            return obj
        end
    end
    return nil
end

local function performAutoAttack()
    local remote = findAttackRemote()
    if not remote then return false end

    -- Cek radius dan cari survivor terdekat
    if not localRootPart then return false end
    local localPos = localRootPart.Position
    local ATTACK_RADIUS = 9  -- bisa diubah atau diambil dari config nanti
    local targetFound = false

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            -- Cek apakah player adalah survivor (bukan killer/monster/enemy)
            local isSurvivor = true
            if player.Team then
                local teamName = player.Team.Name:lower()
                if teamName:find("killer") or teamName:find("monster") or teamName:find("enemy") then
                    isSurvivor = false
                end
            end
            if isSurvivor and player.Character then
                local targetRoot = player.Character:FindFirstChild("HumanoidRootPart") or player.Character:FindFirstChild("Torso")
                if targetRoot then
                    local dist = (localPos - targetRoot.Position).Magnitude
                    if dist <= ATTACK_RADIUS then
                        targetFound = true
                        break
                    end
                end
            end
        end
    end

    if not targetFound then
        return false
    end

    -- Jika ada target, spam remote
    pcall(function()
        remote:FireServer()
        remote:FireServer("BasicAttack")
        remote:FireServer(localPlayer)
    end)
    return true
end
-- Variabel koneksi (tetap di luar untuk start/stop)
local shieldConnection = nil

-- Start auto attack (dipanggil saat toggle ON)
local function startShieldMonitor()
    if shieldConnection then return end
    shieldConnection = RunService.Heartbeat:Connect(performAutoAttack)
    print("[AutoAttack] Started (Radius Mode)")
end

-- Stop auto attack (dipanggil saat toggle OFF)
local function stopShieldMonitor()
    if shieldConnection then
        shieldConnection:Disconnect()
        shieldConnection = nil
    end
    -- Panggil performAutoAttack sekali untuk menghancurkan ESP
    performAutoAttack()
    print("[AutoAttack] Stopped")
end
-- ============================================================================
-- FEATURE 10: TPWALK (2x speed boost + CFrame dash) - ONLY WHEN MOVING (CONTROLLED)
-- ============================================================================
local function applyTpwalkBoost()
    if not config.tpwalkEnabled then return end
    if isTpwalkActive then return end
    if not localHumanoid then return end

    -- Hanya aktif jika player sedang bergerak (MoveDirection tidak nol)
    local moveDirection = localHumanoid.MoveDirection
    if moveDirection.Magnitude < 0.1 then return end

    if originalTpwalkSpeed == 16 then originalTpwalkSpeed = localHumanoid.WalkSpeed end
    local boostSpeed = originalTpwalkSpeed * config.tpwalkSpeedMultiplier
    localHumanoid.WalkSpeed = boostSpeed
    isTpwalkActive = true

    -- CFrame dash: teleport kecil ke depan setiap 0.1 detik selama durasi, mengikuti arah gerakan
    local startTime = tick()
    local dashConnection
    dashConnection = RunService.Heartbeat:Connect(function()
        if not isTpwalkActive or (tick() - startTime) >= config.tpwalkDuration then
            if dashConnection then dashConnection:Disconnect() end
            return
        end
        if localRootPart then
            local moveDir = localHumanoid.MoveDirection
            if moveDir.Magnitude > 0.1 then
                local forward = moveDir.Unit * 2
                localRootPart.CFrame = localRootPart.CFrame + forward
            else
                -- Jika berhenti bergerak saat dash, hentikan boost lebih awal
                if dashConnection then dashConnection:Disconnect() end
                isTpwalkActive = false
                if localHumanoid then localHumanoid.WalkSpeed = originalTpwalkSpeed end
            end
        end
    end)

    task.spawn(function()
        task.wait(config.tpwalkDuration)
        if localHumanoid then localHumanoid.WalkSpeed = originalTpwalkSpeed end
        isTpwalkActive = false
        if dashConnection then dashConnection:Disconnect() end
    end)

    print("[Tpwalk] Speed boosted to " .. boostSpeed .. " for " .. config.tpwalkDuration .. " seconds + dash effect (only when moving)")
end

-- ============================================================================
-- MONITOR: aktifkan boost hanya saat player bergerak, matikan jika berhenti
-- ============================================================================
local function checkTpwalkProximity()
    if not config.tpwalkEnabled then return end
    if not getLocalCharacter() or not localRootPart or not localHumanoid then return end

    local moveDirection = localHumanoid.MoveDirection
    local isMoving = moveDirection.Magnitude > 0.1

    if isMoving and not isTpwalkActive then
        applyTpwalkBoost()
    elseif not isMoving and isTpwalkActive then
        -- Jika berhenti bergerak saat boost aktif, matikan boost segera
        if localHumanoid then localHumanoid.WalkSpeed = originalTpwalkSpeed end
        isTpwalkActive = false
        print("[Tpwalk] Boost cancelled because player stopped moving")
    end
end

local function startTpwalkMonitor()
    if tpwalkConnection then return end
    tpwalkConnection = RunService.Heartbeat:Connect(checkTpwalkProximity)
    print("[Tpwalk] Monitor started (active only when moving - controlled movement)")
end

local function stopTpwalkMonitor()
    if tpwalkConnection then tpwalkConnection:Disconnect(); tpwalkConnection = nil end
    if isTpwalkActive then
        if localHumanoid then localHumanoid.WalkSpeed = originalTpwalkSpeed end
        isTpwalkActive = false
    end
    print("[Tpwalk] Monitor stopped")
end

-- ============================================================================
-- FEATURE 11: NO COLLISION (ALWAYS ACTIVE WHEN ENABLED)
-- Tidak menggunakan trigger jarak killer. Noclip aktif terus saat fitur dinyalakan.
-- ============================================================================
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

-- Fungsi ini sekarang hanya mengaktifkan/menonaktifkan berdasarkan config (tanpa cek jarak).
local function checkNoCollideProximity()
    if not config.noCollideEnabled then
        if isNoCollideActive then disableNoCollision() end
        return
    end
    if not isNoCollideActive then enableNoCollision() end
end

local function startNoCollideMonitor()
    if noCollideConnection then return end
    noCollideConnection = RunService.Heartbeat:Connect(checkNoCollideProximity)
end

local function stopNoCollideMonitor()
    if noCollideConnection then noCollideConnection:Disconnect(); noCollideConnection = nil end
    disableNoCollision()
end

-- ============================================================================
-- FEATURE 12: MASS KILL LOOP (OPTIMIZED - TELEPORT FRONT + FASTER EXECUTION)
-- ============================================================================

-- Utility functions
local function getLocalCharacter()
    local char = localPlayer.Character
    if char then
        localRootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    end
    return char
end

-- ** TELEPORT KE DEPAN PLAYER (bukan belakang) dengan cepat **
local function teleportFront(targetRoot)
    if not targetRoot or not localRootPart then return false end
    local targetCFrame = targetRoot.CFrame
    local frontPos = targetCFrame.Position + targetCFrame.LookVector * 2
    local success = pcall(function()
        localRootPart.CFrame = CFrame.new(frontPos)
    end)
    return success
end

-- Lock camera ke target (opsional, tidak mengganggu kecepatan)
local function lockCameraTo(position)
    if not camera then return end
    pcall(function() camera.CFrame = CFrame.new(camera.CFrame.Position, position) end)
end

local function getAllSurvivors()
    local survivors = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local char = player.Character
            if char then
                local isKiller = false
                if player.Team then
                    isKiller = (player.Team.Name:lower():find("killer") or player.Team.Name:lower():find("monster") or player.Team.Name:lower():find("enemy"))
                end
                if not isKiller then
                    local tool = char:FindFirstChildWhichIsA("Tool")
                    if tool and (tool.Name:lower():find("knife") or tool.Name:lower():find("weapon")) then
                        isKiller = true
                    end
                end
                if not isKiller then
                    table.insert(survivors, player)
                end
            end
        end
    end
    return survivors
end

-- Simulasi tekan tombol E (dipersingkat)
local function simulatePressE()
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
    pcall(function()
        VirtualUser:Button1Down(Vector2.new(500, 500))
        VirtualUser:Button1Up(Vector2.new(500, 500))
    end)
end

-- Cari hilt hitbox (opsional)
local function findHiltHitbox()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name:lower():find("hilt") then
            return obj
        end
    end
    return nil
end

-- ============================================================================
-- HIT SURVIVOR DENGAN PRIORITAS REMOTE EVENT (DIOPTIMASI, HILANGKAN DELAY)
-- ============================================================================
local function hitSurvivorWithRemote(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return false end
    local targetChar = targetPlayer.Character
    local humanoid = targetChar:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end

    local hitSuccess = false

    -- METHOD 1: REMOTE EVENT (PRIORITAS UTAMA)
    local remoteEvents = {}
    for _, remote in ipairs(ReplicatedStorage:GetDescendants()) do
        if remote:IsA("RemoteEvent") then
            local name = remote.Name:lower()
            if name:find("damage") or name:find("hit") or name:find("kill") or name:find("attack") then
                table.insert(remoteEvents, remote)
            end
        end
    end
    for _, remote in ipairs(remoteEvents) do
        pcall(function() remote:FireServer(targetPlayer) end)
        pcall(function() remote:FireServer(targetPlayer, "attack") end)
        pcall(function() remote:FireServer(targetPlayer.Character) end)
        hitSuccess = true
    end

    -- METHOD 2: Direct health manipulation
    if not hitSuccess then
        pcall(function() humanoid.Health = 0 end)
        hitSuccess = true
    end

    -- METHOD 3: BreakJoints
    if not hitSuccess then
        pcall(function() targetChar:BreakJoints() end)
        hitSuccess = true
    end

    -- METHOD 4: Interaksi dengan hilt (tanpa delay)
    if not hitSuccess then
        local hilt = findHiltHitbox()
        if hilt then
            if hilt:IsA("Tool") then
                pcall(function() hilt:Activate() end)
                hitSuccess = true
            end
            local clickDetector = hilt:FindFirstChildWhichIsA("ClickDetector")
            if clickDetector and clickDetector.Enabled then
                pcall(function() clickDetector:FireClick() end)
                hitSuccess = true
            end
            local proximityPrompt = hilt:FindFirstChildWhichIsA("ProximityPrompt")
            if proximityPrompt and proximityPrompt.Enabled then
                pcall(function() proximityPrompt:Hold(); proximityPrompt:Release() end) -- tanpa task.wait
                hitSuccess = true
            end
        end
    end

    -- METHOD 5: Simulasi tekan E
    if not hitSuccess then
        simulatePressE()
        hitSuccess = true
    end

    return hitSuccess
end

-- ============================================================================
-- MASS KILL LOOP (LEBIH CEPAT: TELEPORT FRONT + LANGSUNG HIT)
-- ============================================================================
local function massKillLoop()
    if not config.massKillEnabled then return end
    if not getLocalCharacter() or not localRootPart then return end

    local survivors = getAllSurvivors()
    if #survivors == 0 then return end

    -- Ambil target random
    local target = survivors[math.random(1, #survivors)]
    if target and target.Character then
        local targetRoot = target.Character:FindFirstChild("HumanoidRootPart") or target.Character:FindFirstChild("Torso")
        if targetRoot then
            teleportFront(targetRoot)           -- Teleport ke depan player
            lockCameraTo(targetRoot.Position)   -- Kunci kamera
            hitSurvivorWithRemote(target)       -- Hit langsung
        end
    end
end

-- ============================================================================
-- START / STOP MASS KILL LOOP
-- ============================================================================
local massKillLoopConnection = nil

local function startMassKillLoop()
    if massKillLoopConnection then return end
    massKillLoopConnection = RunService.Heartbeat:Connect(massKillLoop)
    print("[MassKill] Mass kill loop started (teleport FRONT + optimized hit)")
end

local function stopMassKillLoop()
    if massKillLoopConnection then
        massKillLoopConnection:Disconnect()
        massKillLoopConnection = nil
    end
    print("[MassKill] Mass kill loop stopped")
end


-- ============================================================================
-- ============================================================================
-- FEATURE 13: 
-- ============================================================================
-- ============================================================================
-- AUTO GENERATOR LOOP (SPAM REMOTE EVENT)
-- Menggunakan remote: BreakGenAnim, BreakGenCommit, BreakGenEvent, BreakGenReject
-- ============================================================================
-- ============================================================================
-- AUTO GENERATOR LOOP (REMOTE EVENT SPAM - BREAKGENEVENT)
-- ============================================================================

local function startAutoGeneratorLoop()
    if config.autoGeneratorThread then
        return
    end

    -- Cari remote event BreakGenEvent
    local function findBreakGenRemote()
        local replicatedStorage = game:GetService("ReplicatedStorage")
        local remotes = replicatedStorage:FindFirstChild("Remotes")
        if remotes then
            local generator = remotes:FindFirstChild("Generator")
            if generator then
                local remote = generator:FindFirstChild("BreakGenEvent")
                if remote and remote:IsA("RemoteEvent") then
                    return remote
                end
            end
        end
        -- Fallback scan
        for _, obj in ipairs(replicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") and obj.Name == "BreakGenCommit" then
                return obj
            end
        end
        return nil
    end

    local breakGenRemote = findBreakGenRemote()
    if not breakGenRemote then
        print("[AutoGenerator] BreakGenEvent remote not found!")
        return
    end

    local thread = task.spawn(function()
        local lastSpamTime = 0
        local spamInterval = 0.05

        while config.autoGeneratorEnabled do
            if getLocalCharacter() then
                local now = tick()
                if now - lastSpamTime >= spamInterval then
                    lastSpamTime = now
                    pcall(function()
                        breakGenRemote:FireServer()
                    end)
                end
            end
            task.wait(0.01)
        end
    end)

    config.autoGeneratorThread = thread
    print("[AutoGenerator] Started (spamming BreakGenEvent)")
end

local function stopAutoGeneratorLoop()
    if config.autoGeneratorThread then
        task.cancel(config.autoGeneratorThread)
        config.autoGeneratorThread = nil
    end
    print("[AutoGenerator] Stopped")
end
--========================
-- Skull check
--=======================
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
            task.wait(0)                
            VirtualInputManager:SendTouchEvent(TouchID, 2, cx, cy)                
        end)                
    end                
end                
                
local currentRole = nil
local roleWatcherConnection = nil

-- Fungsi untuk mendapatkan role player lokal
local function getCurrentRole()
    local team = localPlayer.Team
    if not team then return "Spectator" end
    local name = team.Name
    if name == "Survivors" then return "Survivor"
    elseif name == "Killers" then return "Killer" end
    return "Spectator"
end

-- Modifikasi InitializeAutobuy agar tidak menyimpan cache Line/Goal secara permanen
local function InitializeAutobuy()                    
    task.spawn(function()                    
        local playerGui = localPlayer:FindFirstChild("PlayerGui")                    
        if not playerGui then return end                    
        local prompt = playerGui:FindFirstChild("SkillCheckPromptGui")                    
        if not prompt then                    
            prompt = playerGui:WaitForChild("SkillCheckPromptGui", 10)                    
        end                    
        if not prompt then return end
        local check = prompt:FindFirstChild("Check")                    
        if not check then return end                    
        -- Jangan cache line dan goal secara permanen, ambil ulang saat dibutuhkan
        if VisibilityConnection then VisibilityConnection:Disconnect() end                    
        
        local triggerCount = 0          
        local MAX_TRIGGER = 99999999999           
        local lastTriggerTime = 0
        
        VisibilityConnection = check:GetPropertyChangedSignal("Visible"):Connect(function()                    
            if localPlayer.Team and localPlayer.Team.Name == "Survivors" and check.Visible then                    
                triggerCount = 0         
                lastTriggerTime = 0
                if HeartbeatConnection then HeartbeatConnection:Disconnect() end                    
                -- Gunakan RenderStepped untuk respons lebih cepat
                HeartbeatConnection = RunService.RenderStepped:Connect(function()                    
                    if not check.Visible then     
                        if HeartbeatConnection then HeartbeatConnection:Disconnect(); HeartbeatConnection = nil end    
                        return     
                    end    
                    if triggerCount >= MAX_TRIGGER then 
                        if HeartbeatConnection then HeartbeatConnection:Disconnect(); HeartbeatConnection = nil end
                        return
                    end
                    
                    -- Ambil Line dan Goal secara real-time (tidak pakai cache)
                    local currentLine = check:FindFirstChild("Line")
                    local currentGoal = check:FindFirstChild("Goal")
                    if not currentLine or not currentGoal then return end
                    
                    local lr = currentLine.Rotation % 360                    
                    local gr = currentGoal.Rotation % 360
                    -- Perlebar zone untuk sensitivitas lebih tinggi (102-120)
                    local ss = (gr + 102) % 360                    
                    local se = (gr + 120) % 360                    
                    local inRange = false                    
                    if ss > se then                    
                        if lr >= ss or lr <= se then inRange = true end                    
                    else                    
                        if lr >= ss and lr <= se then inRange = true end                    
                    end                    
                    
                    if inRange then                    
                        local now = tick()
                        if now - lastTriggerTime > 0.05 then
                            lastTriggerTime = now
                            triggerCount = triggerCount + 1
                            TriggerMobileButton()                    
                            if triggerCount >= MAX_TRIGGER then
                                if HeartbeatConnection then HeartbeatConnection:Disconnect(); HeartbeatConnection = nil end
                            end
                        end
                    end                    
                end)                    
            elseif HeartbeatConnection then     
                HeartbeatConnection:Disconnect();     
                HeartbeatConnection = nil     
                triggerCount = 0
                lastTriggerTime = 0
            end                    
        end)                    
    end)                    
end

-- Watcher perubahan role (Survivor/Killer/Spectator)
local function startRoleWatcher()
    if roleWatcherConnection then return end
    roleWatcherConnection = RunService.Heartbeat:Connect(function()
        local role = getCurrentRole()
        if role ~= currentRole then
            currentRole = role
            print("[AutoSkillCheck] Role changed to", role, "- reloading hooks")
            -- Reset semua koneksi lama
            if VisibilityConnection then
                VisibilityConnection:Disconnect()
                VisibilityConnection = nil
            end
            if HeartbeatConnection then
                HeartbeatConnection:Disconnect()
                HeartbeatConnection = nil
            end
            -- Jika role Survivor dan fitur aktif, reload
            if config.autoSkillCheckEnabled and role == "Survivor" then
                task.wait(0.5) -- beri waktu GUI baru spawn
                InitializeAutobuy()
            end
        end
    end)
end

-- Modifikasi startAutoSkillCheck
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
                        if gui.Visible and gui.Active then                
                            pcall(function() gui:FireClick() end)                
                        end                
                    end                
                end                
            end                
        end                
    end)                
    -- Inisialisasi role awal
    currentRole = getCurrentRole()
    startRoleWatcher()
    if config.autoSkillCheckEnabled and currentRole == "Survivor" then
        InitializeAutobuy()
    end
    print("[AutoSkillCheck] Auto skill check started with role watcher + RenderStepped")                
end                
                
local function stopAutoSkillCheck()                
    if autoSkillCheckConnection then 
        autoSkillCheckConnection:Disconnect() 
        autoSkillCheckConnection = nil 
    end                
    if VisibilityConnection then 
        VisibilityConnection:Disconnect() 
        VisibilityConnection = nil 
    end                
    if HeartbeatConnection then 
        HeartbeatConnection:Disconnect() 
        HeartbeatConnection = nil 
    end
    if roleWatcherConnection then
        roleWatcherConnection:Disconnect()
        roleWatcherConnection = nil
    end
    print("[AutoSkillCheck] Auto skill check stopped")                
end
-- ============================================================================
-- FEATURE 15: AUTO AIM (unchanged)
-- ============================================================================
local autoAimState = {
    targetMode = "Killer",   -- Killer, Survivor, SCP
    lockActive = false,
    lockConn = nil,
    lockTimer = nil,
    mouseDownConn = nil,
    mouseUpConn = nil,
    keyConn = nil,
    guiRef = nil,
    isActive = false,
    mobileButton = nil,
    mobileButtonGui = nil,
    mobileLockEnabled = false,
    -- State untuk hold
    holding1 = false,
    holding2 = false,
    holdActive = false,
    holdConn = nil,
    -- Inf Shot
    infShotEnabled = false,
}

local function startAutoAim()
    if autoAimConnection then return end
    if not config.autoAimEnabled then return end

    -- ========== HELPER FUNCTIONS (tetap sama) ==========
    local function getNearestTarget(mode)
        local char = localPlayer.Character
        if not char then return nil end
        local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
        if not rootPart then return nil end
        local localPos = rootPart.Position
        local nearest = nil
        local minDist = math.huge

        if mode == "Killer" then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= localPlayer then
                    local pChar = player.Character
                    if pChar then
                        local isKiller = false
                        if player.Team then
                            local t = player.Team.Name:lower()
                            isKiller = t:find("killer") or t:find("monster") or t:find("enemy")
                        end
                        if not isKiller then
                            local tool = pChar:FindFirstChildWhichIsA("Tool")
                            if tool and (tool.Name:lower():find("knife") or tool.Name:lower():find("weapon")) then isKiller = true end
                        end
                        if isKiller then
                            local targetRoot = pChar:FindFirstChild("HumanoidRootPart") or pChar:FindFirstChild("Torso")
                            if targetRoot then
                                return { Object = targetRoot, Player = player }
                            end
                        end
                    end
                end
            end
            return nil
        elseif mode == "Survivor" then
            local camera = workspace.CurrentCamera
            if not camera then return nil end
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= localPlayer then
                    local pChar = player.Character
                    if pChar then
                        local isKiller = false
                        if player.Team then
                            local t = player.Team.Name:lower()
                            isKiller = t:find("killer") or t:find("monster") or t:find("enemy")
                        end
                        if not isKiller then
                            local tool = pChar:FindFirstChildWhichIsA("Tool")
                            if tool and (tool.Name:lower():find("knife") or tool.Name:lower():find("weapon")) then isKiller = true end
                        end
                        if not isKiller then
                            local targetRoot = pChar:FindFirstChild("HumanoidRootPart") or pChar:FindFirstChild("Torso")
                            if targetRoot then
                                local dirToTarget = (targetRoot.Position - camera.CFrame.Position).Unit
                                local dot = camera.CFrame.LookVector:Dot(dirToTarget)
                                if dot > 0 then
                                    local dist = (localPos - targetRoot.Position).Magnitude
                                    if dist < minDist then
                                        minDist = dist
                                        nearest = { Object = targetRoot, Player = player }
                                    end
                                end
                            end
                        end
                    end
                end
            end
            return nearest
        elseif mode == "SCP" then
         for _, model in ipairs(workspace:GetChildren()) do
        if model:IsA("Model") then
            local isSCP = false
            -- Cek atribut SCP pada model
            if model:GetAttribute("SCP") == true then
                isSCP = true
            end
            -- Cek nama model
            if not isSCP then
                local modelName = model.Name:lower()
                if modelName:find("scp") then
                    isSCP = true
                end
            end
            -- Cek descendant (BasePart) yang memiliki atribut atau nama scp
            if not isSCP then
                for _, child in ipairs(model:GetDescendants()) do
                    if child:IsA("BasePart") and (child.Name:lower():find("scp") or child:GetAttribute("SCP") == true) then
                        isSCP = true
                        break
                    end
                end
            end
            if isSCP then
                local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model.PrimaryPart
                if root then
                    local dist = (localPos - root.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        nearest = { Object = root }
                    end
                end
            end
        end
    end
    return nearest
        end
        return nil
    end

    local function lockToTarget(targetInfo, duration)
        if not targetInfo or not targetInfo.Object then return end
        if not workspace.CurrentCamera then return end
        local camera = workspace.CurrentCamera

        if autoAimState.lockConn then autoAimState.lockConn:Disconnect(); autoAimState.lockConn = nil end
        if autoAimState.lockTimer then task.cancel(autoAimState.lockTimer); autoAimState.lockTimer = nil end

        autoAimState.lockActive = true
        duration = duration or 2.5

        autoAimState.lockConn = RunService.RenderStepped:Connect(function()
            if not autoAimState.lockActive then
                autoAimState.lockConn:Disconnect()
                autoAimState.lockConn = nil
                return
            end
            local targetObj = targetInfo.Object
            if not targetObj or not targetObj.Parent then
                autoAimState.lockActive = false
                if autoAimState.lockConn then autoAimState.lockConn:Disconnect(); autoAimState.lockConn = nil end
                return
            end
            local targetPos = targetObj.Position
            if not targetPos then
                autoAimState.lockActive = false
                if autoAimState.lockConn then autoAimState.lockConn:Disconnect(); autoAimState.lockConn = nil end
                return
            end

            local localChar = localPlayer.Character
            if not localChar then
                autoAimState.lockActive = false
                if autoAimState.lockConn then autoAimState.lockConn:Disconnect(); autoAimState.lockConn = nil end
                return
            end
            local rootPart = localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("Torso")
            if not rootPart then
                autoAimState.lockActive = false
                if autoAimState.lockConn then autoAimState.lockConn:Disconnect(); autoAimState.lockConn = nil end
                return
            end
            local humanoid = localChar:FindFirstChildOfClass("Humanoid")
            if not humanoid then
                autoAimState.lockActive = false
                if autoAimState.lockConn then autoAimState.lockConn:Disconnect(); autoAimState.lockConn = nil end
                return
            end

            local camPos = camera.CFrame.Position
            camera.CFrame = CFrame.lookAt(camPos, targetPos)

            local currentPos = rootPart.Position
            local lookDir = (targetPos - currentPos)
            if lookDir.Magnitude > 0.5 then
                rootPart.CFrame = CFrame.new(currentPos, targetPos)
                humanoid.AutoRotate = false
            end
        end)

        autoAimState.lockTimer = task.spawn(function()
            task.wait(duration)
            autoAimState.lockActive = false
            if autoAimState.lockConn then
                autoAimState.lockConn:Disconnect()
                autoAimState.lockConn = nil
            end
            local localChar = localPlayer.Character
            if localChar then
                local humanoid = localChar:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.AutoRotate = true
                end
            end
            -- Inf Shot after lock ends (otomatis)
            if autoAimState.infShotEnabled then
                for i = 1, 5 do
                    fireInfShot()
                    task.wait(0.05)
                end
            end
        end)
    end

    local function showModeNotification(mode)
        local gui = Instance.new("ScreenGui")
        gui.Name = "AutoAimNotification"
        gui.ResetOnSpawn = false
        gui.Parent = game:GetService("CoreGui")
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 300, 0, 50)
        frame.Position = UDim2.new(0.5, -150, 0.5, -25)
        frame.BackgroundColor3 = Color3.fromRGB(12, 22, 38)
        frame.BackgroundTransparency = 0.3
        frame.BorderSizePixel = 0
        frame.Parent = gui
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(0, 180, 255)
        stroke.Thickness = 1
        stroke.Transparency = 0.4
        stroke.Parent = frame
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = "Target Mode: " .. mode
        label.TextColor3 = Color3.fromRGB(0, 220, 255)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.Parent = frame
        task.delay(2, function()
            gui:Destroy()
        end)
        if autoAimState.guiRef then
            local frame2 = autoAimState.guiRef:FindFirstChildWhichIsA("Frame")
            if frame2 then
                local content = frame2:FindFirstChild("Content")
                if content then
                    local modeLabel = content:FindFirstChild("ModeLabel")
                    if modeLabel then
                        modeLabel.Text = "Target: " .. mode
                    end
                end
            end
        end
    end

    local function createAutoAimGUI()
        if autoAimState.guiRef then
            autoAimState.guiRef:Destroy()
            autoAimState.guiRef = nil
        end
        local gui = Instance.new("ScreenGui")
        gui.Name = "AutoAimSettings"
        gui.ResetOnSpawn = false
        gui.Parent = game:GetService("CoreGui")
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 220, 0, 180)  -- diperbesar untuk inf shot
        frame.Position = UDim2.new(0.5, -110, 0.5, -90)
        frame.BackgroundColor3 = Color3.fromRGB(12, 22, 38)
        frame.BackgroundTransparency = 0.2
        frame.BorderSizePixel = 0
        frame.Parent = gui
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(0, 180, 255)
        stroke.Thickness = 1.2
        stroke.Transparency = 0.4
        stroke.Parent = frame

        local header = Instance.new("Frame")
        header.Size = UDim2.new(1, 0, 0, 24)
        header.BackgroundColor3 = Color3.fromRGB(18, 28, 44)
        header.BorderSizePixel = 0
        header.Parent = frame
        Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)
        local headerStroke = Instance.new("UIStroke")
        headerStroke.Color = Color3.fromRGB(0, 180, 255)
        headerStroke.Transparency = 0.5
        headerStroke.Parent = header

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(0.6, 0, 1, 0)
        title.Position = UDim2.new(0.04, 0, 0, 0)
        title.BackgroundTransparency = 1
        title.Text = "Auto Aim"
        title.TextColor3 = Color3.fromRGB(0, 220, 255)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 12
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = header

        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 20, 0, 20)
        closeBtn.Position = UDim2.new(1, -24, 0.5, -10)
        closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        closeBtn.Text = "X"
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 10
        closeBtn.BorderSizePixel = 0
        closeBtn.Parent = header
        Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
        closeBtn.MouseButton1Click:Connect(function()
            if autoAimState.guiRef then
                autoAimState.guiRef:Destroy()
                autoAimState.guiRef = nil
            end
        end)

        local content = Instance.new("Frame")
        content.Size = UDim2.new(1, -10, 1, -34)
        content.Position = UDim2.new(0, 5, 0, 28)
        content.BackgroundTransparency = 1
        content.Parent = frame
        content.Name = "Content"

        local modeLabel = Instance.new("TextLabel")
        modeLabel.Size = UDim2.new(1, 0, 0, 20)
        modeLabel.Position = UDim2.new(0, 0, 0, 4)
        modeLabel.BackgroundTransparency = 1
        modeLabel.Text = "Target: " .. autoAimState.targetMode
        modeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        modeLabel.Font = Enum.Font.Gotham
        modeLabel.TextSize = 11
        modeLabel.TextXAlignment = Enum.TextXAlignment.Left
        modeLabel.Parent = content
        modeLabel.Name = "ModeLabel"

        local switchModeBtn = Instance.new("TextButton")
        switchModeBtn.Size = UDim2.new(0.8, 0, 0, 20)
        switchModeBtn.Position = UDim2.new(0.1, 0, 0.3, 0)
        switchModeBtn.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
        switchModeBtn.Text = "Switch Target (Shift+T)"
        switchModeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        switchModeBtn.Font = Enum.Font.GothamBold
        switchModeBtn.TextSize = 10
        switchModeBtn.BorderSizePixel = 0
        switchModeBtn.Parent = content
        Instance.new("UICorner", switchModeBtn).CornerRadius = UDim.new(0, 4)
        switchModeBtn.MouseButton1Click:Connect(function()
            local modes = {"Killer", "Survivor", "SCP"}
            local idx
            for i, m in ipairs(modes) do
                if m == autoAimState.targetMode then idx = i; break end
            end
            idx = (idx % 3) + 1
            autoAimState.targetMode = modes[idx]
            modeLabel.Text = "Target: " .. autoAimState.targetMode
            showModeNotification(autoAimState.targetMode)
        end)

        -- ===== TOGGLE MOBILE LOCK BUTTON =====
        local mobileToggleRow = Instance.new("Frame")
        mobileToggleRow.Size = UDim2.new(1, 0, 0, 22)
        mobileToggleRow.Position = UDim2.new(0, 0, 0.55, 0)
        mobileToggleRow.BackgroundTransparency = 1
        mobileToggleRow.Parent = content

        local mobileLabel = Instance.new("TextLabel")
        mobileLabel.Size = UDim2.new(0.5, 0, 1, 0)
        mobileLabel.BackgroundTransparency = 1
        mobileLabel.Text = "Version mobile"
        mobileLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        mobileLabel.Font = Enum.Font.Gotham
        mobileLabel.TextSize = 10
        mobileLabel.TextXAlignment = Enum.TextXAlignment.Left
        mobileLabel.Parent = mobileToggleRow

        local mobileSwitch = Instance.new("TextButton")
        mobileSwitch.Size = UDim2.new(0, 36, 0, 16)
        mobileSwitch.Position = UDim2.new(0.65, 0, 0.5, -8)
        mobileSwitch.BackgroundColor3 = autoAimState.mobileLockEnabled and Color3.fromRGB(0, 140, 255) or Color3.fromRGB(45, 45, 65)
        mobileSwitch.Text = autoAimState.mobileLockEnabled and "ON" or "OFF"
        mobileSwitch.TextColor3 = Color3.fromRGB(255, 255, 255)
        mobileSwitch.Font = Enum.Font.GothamBold
        mobileSwitch.TextSize = 7
        mobileSwitch.BorderSizePixel = 0
        mobileSwitch.AutoButtonColor = false
        mobileSwitch.Parent = mobileToggleRow
        local switchCorner = Instance.new("UICorner")
        switchCorner.CornerRadius = UDim.new(1, 0)
        switchCorner.Parent = mobileSwitch

        mobileSwitch.MouseButton1Click:Connect(function()
            autoAimState.mobileLockEnabled = not autoAimState.mobileLockEnabled
            mobileSwitch.BackgroundColor3 = autoAimState.mobileLockEnabled and Color3.fromRGB(0, 140, 255) or Color3.fromRGB(45, 45, 65)
            mobileSwitch.Text = autoAimState.mobileLockEnabled and "ON" or "OFF"
            -- Update visibilitas tombol tanpa destroy
            if autoAimState.mobileButtonGui then
                autoAimState.mobileButtonGui.Enabled = autoAimState.mobileLockEnabled
                if autoAimState.mobileButton1 then
                    autoAimState.mobileButton1.Visible = autoAimState.mobileLockEnabled
                end
                if autoAimState.mobileButton2 then
                    autoAimState.mobileButton2.Visible = autoAimState.mobileLockEnabled
                end
            else
                setupMobileButton()
            end
            -- Jika dimatikan, hentikan hold yang aktif
            if not autoAimState.mobileLockEnabled then
                if autoAimState.holdActive then
                    stopHoldLoop()
                end
                autoAimState.holding1 = false
                autoAimState.holding2 = false
            end
        end)

        -- ===== TOGGLE INF SHOT =====
        local infToggleRow = Instance.new("Frame")
        infToggleRow.Size = UDim2.new(1, 0, 0, 22)
        infToggleRow.Position = UDim2.new(0, 0, 0.8, 0) -- di bawah mobile toggle
        infToggleRow.BackgroundTransparency = 1
        infToggleRow.Parent = content

        local infLabel = Instance.new("TextLabel")
        infLabel.Size = UDim2.new(0.5, 0, 1, 0)
        infLabel.BackgroundTransparency = 1
        infLabel.Text = "Never Miss"
        infLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        infLabel.Font = Enum.Font.Gotham
        infLabel.TextSize = 10
        infLabel.TextXAlignment = Enum.TextXAlignment.Left
        infLabel.Parent = infToggleRow

        local infSwitch = Instance.new("TextButton")
        infSwitch.Size = UDim2.new(0, 36, 0, 16)
        infSwitch.Position = UDim2.new(0.65, 0, 0.5, -8)
        infSwitch.BackgroundColor3 = autoAimState.infShotEnabled and Color3.fromRGB(0, 140, 255) or Color3.fromRGB(45, 45, 65)
        infSwitch.Text = autoAimState.infShotEnabled and "ON" or "OFF"
        infSwitch.TextColor3 = Color3.fromRGB(255, 255, 255)
        infSwitch.Font = Enum.Font.GothamBold
        infSwitch.TextSize = 7
        infSwitch.BorderSizePixel = 0
        infSwitch.AutoButtonColor = false
        infSwitch.Parent = infToggleRow
        local infSwitchCorner = Instance.new("UICorner")
        infSwitchCorner.CornerRadius = UDim.new(1, 0)
        infSwitchCorner.Parent = infSwitch

        infSwitch.MouseButton1Click:Connect(function()
            autoAimState.infShotEnabled = not autoAimState.infShotEnabled
            infSwitch.BackgroundColor3 = autoAimState.infShotEnabled and Color3.fromRGB(0, 140, 255) or Color3.fromRGB(45, 45, 65)
            infSwitch.Text = autoAimState.infShotEnabled and "ON" or "OFF"
        end)

        -- Drag GUI
        local dragging = false
        local dragStart, frameStart
        header.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                frameStart = frame.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                frame.Position = UDim2.new(frameStart.X.Scale, frameStart.X.Offset + delta.X, frameStart.Y.Scale, frameStart.Y.Offset + delta.Y)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)

        autoAimState.guiRef = gui
        return gui
    end
    -- ========== FUNGSI NEVER MISS (DETECTION + REMOTE) ==========
    local function getFireRemotes()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if not remotes then return nil, nil end
        local items = remotes:FindFirstChild("Items")
        if not items then return nil, nil end
        local twist = items:FindFirstChild("Twist of Fate")
        if not twist then return nil, nil end
        local fireRemote = twist:FindFirstChild("Fire")
        local resultRemote = twist:FindFirstChild("Result")
        return fireRemote, resultRemote
    end
    local function fireInfShot()
        local char = localPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        -- Cari target terdekat sesuai mode
        local targetInfo = getNearestTarget(autoAimState.targetMode)
        if not targetInfo or not targetInfo.Object then return end
        local targetPos = targetInfo.Object.Position

        -- Cek apakah ada penghalang (raycast)
        local camera = workspace.CurrentCamera
        if not camera then return end
        local origin = camera.CFrame.Position
        local direction = (targetPos - origin).Unit
        local rayLength = (targetPos - origin).Magnitude
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Blacklist
        rayParams.FilterDescendantsInstances = {char, targetInfo.Object.Parent} -- abaikan player sendiri dan target
        if targetInfo.Player then
            local targetChar = targetInfo.Player.Character
            if targetChar then
                table.insert(rayParams.FilterDescendantsInstances, targetChar)
            end
        end

        local hit = workspace:Raycast(origin, direction * rayLength, rayParams)

        -- Jika ada penghalang (atau kita ingin force), kirim remote double
        if hit then
            -- Set atribut Aiming
            pcall(function() char:SetAttribute("Aiming", true) end)

            local fireRemote, resultRemote = getFireRemotes()
            if fireRemote and fireRemote:IsA("RemoteEvent") then
                pcall(function() fireRemote:FireServer() end)
            end
            if resultRemote and resultRemote:IsA("RemoteEvent") then
                pcall(function() resultRemote:FireServer() end)
            end

            pcall(function() char:SetAttribute("Aiming", false) end)
        end
    end

    -- ========== FUNGSI HOLD LOOP ==========
    local function startHoldLoop()
        if autoAimState.holdActive then return end
        autoAimState.holdActive = true
        autoAimState.holdConn = RunService.RenderStepped:Connect(function()
            if not autoAimState.holdActive then
                if autoAimState.holdConn then
                    autoAimState.holdConn:Disconnect()
                    autoAimState.holdConn = nil
                end
                return
            end
            local target = getNearestTarget(autoAimState.targetMode)
            if target and target.Object then
                local camera = workspace.CurrentCamera
                if camera then
                    local targetPos = target.Object.Position
                    if targetPos then
                        local camPos = camera.CFrame.Position
                        camera.CFrame = CFrame.lookAt(camPos, targetPos)
                        local localChar = localPlayer.Character
                        if localChar then
                            local rootPart = localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("Torso")
                            if rootPart then
                                local currentPos = rootPart.Position
                                local lookDir = (targetPos - currentPos)
                                if lookDir.Magnitude > 0.5 then
                                    rootPart.CFrame = CFrame.new(currentPos, targetPos)
                                    local humanoid = localChar:FindFirstChildOfClass("Humanoid")
                                    if humanoid then
                                        humanoid.AutoRotate = false
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end)
    end

    local function stopHoldLoop()
        autoAimState.holdActive = false
        if autoAimState.holdConn then
            autoAimState.holdConn:Disconnect()
            autoAimState.holdConn = nil
        end
        -- Kembalikan AutoRotate
        local localChar = localPlayer.Character
        if localChar then
            local humanoid = localChar:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.AutoRotate = true
            end
        end
        -- Inf Shot after hold ends
        if autoAimState.infShotEnabled then
            for i = 1, 5 do
                fireInfShot()
                task.wait(0.05)
            end
        end
    end

    -- ========== TOMBOL MOBILE (DUA TOMBOL DENGAN HOLD) ==========
    local function setupMobileButton()
        if autoAimState.mobileButtonGui then
            autoAimState.mobileButtonGui.Enabled = autoAimState.mobileLockEnabled
            if autoAimState.mobileButton1 then
                autoAimState.mobileButton1.Visible = autoAimState.mobileLockEnabled
            end
            if autoAimState.mobileButton2 then
                autoAimState.mobileButton2.Visible = autoAimState.mobileLockEnabled
            end
            return
        end

        local mobileGui = Instance.new("ScreenGui")
        mobileGui.Name = "AutoAimMobileButton"
        mobileGui.ResetOnSpawn = false
        mobileGui.Parent = game:GetService("CoreGui")
        mobileGui.Enabled = autoAimState.mobileLockEnabled

        -- Tombol pertama (ukuran 50x50)
        local button1 = Instance.new("TextButton")
        button1.Name = "LockButton1"
        button1.Size = UDim2.new(0, 50, 0, 50)
        button1.Position = UDim2.new(0.63, 85, 0.73, -75)
        button1.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        button1.BackgroundTransparency = 1
        button1.BorderSizePixel = 0
        button1.Text = ""
        button1.TextColor3 = Color3.fromRGB(50, 50, 50)
        button1.Font = Enum.Font.GothamBold
        button1.TextSize = 22
        button1.Parent = mobileGui
        button1.AutoButtonColor = false
        button1.Visible = autoAimState.mobileLockEnabled
        local btnCorner1 = Instance.new("UICorner")
        btnCorner1.CornerRadius = UDim.new(1, 0)
        btnCorner1.Parent = button1

        -- Tombol kedua (ukuran 85x85, posisi X digeser)
        local button2 = Instance.new("TextButton")
        button2.Name = "LockButton2"
        button2.Size = UDim2.new(0, 0, 0, 0)
        button2.Position = UDim2.new(0.63, 160, 0.73, -55)
        button2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        button2.BackgroundTransparency = 1
        button2.BorderSizePixel = 0
        button2.Text = ""
        button2.TextColor3 = Color3.fromRGB(50, 50, 50)
        button2.Font = Enum.Font.GothamBold
        button2.TextSize = 22
        button2.Parent = mobileGui
        button2.AutoButtonColor = false
        button2.Visible = autoAimState.mobileLockEnabled
        local btnCorner2 = Instance.new("UICorner")
        btnCorner2.CornerRadius = UDim.new(1, 0)
        btnCorner2.Parent = button2

        autoAimState.mobileButtonGui = mobileGui
        autoAimState.mobileButton1 = button1
        autoAimState.mobileButton2 = button2

        button1.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                autoAimState.holding1 = true
                if not autoAimState.holdActive then
                    startHoldLoop()
                end
            end
        end)
        button1.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                autoAimState.holding1 = false
                if not autoAimState.holding2 then
                    stopHoldLoop()
                end
            end
        end)

        button2.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                autoAimState.holding2 = true
                if not autoAimState.holdActive then
                    startHoldLoop()
                end
            end
        end)
        button2.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                autoAimState.holding2 = false
                if not autoAimState.holding1 then
                    stopHoldLoop()
                end
            end
        end)
    end

    -- ========== DETEKSI INPUT MOUSE BUTTON 2 (PC) ==========
    local function setupMouseButton2Detection()
        if autoAimState.mouseDownConn then autoAimState.mouseDownConn:Disconnect() end
        if autoAimState.mouseUpConn then autoAimState.mouseUpConn:Disconnect() end

        autoAimState.mouseDownConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if not config.autoAimEnabled then return end
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                local target = getNearestTarget(autoAimState.targetMode)
                if target and target.Object then
                    lockToTarget(target)
                end
            end
        end)

        autoAimState.mouseUpConn = UserInputService.InputEnded:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if not config.autoAimEnabled then return end
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                if autoAimState.lockActive then
                    autoAimState.lockActive = false
                    if autoAimState.lockConn then
                        autoAimState.lockConn:Disconnect()
                        autoAimState.lockConn = nil
                    end
                    if autoAimState.lockTimer then
                        task.cancel(autoAimState.lockTimer)
                        autoAimState.lockTimer = nil
                    end
                    local localChar = localPlayer.Character
                    if localChar then
                        local humanoid = localChar:FindFirstChildOfClass("Humanoid")
                        if humanoid then
                            humanoid.AutoRotate = true
                        end
                    end
                    -- Inf Shot after mouse up
                    if autoAimState.infShotEnabled then
                        for i = 1, 5 do
                            fireInfShot()
                            task.wait(0.05)
                        end
                    end
                end
            end
        end)
    end

    -- ========== KEYBIND UNTUK MODE ==========
    local function setupKeybindDetection()
        if autoAimState.keyConn then autoAimState.keyConn:Disconnect() end
        autoAimState.keyConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if not config.autoAimEnabled then return end
            if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
                local shiftDown = true
                local releaseConn
                releaseConn = UserInputService.InputBegan:Connect(function(subInput, subProcessed)
                    if subProcessed then return end
                    if shiftDown and (subInput.KeyCode == Enum.KeyCode.T or subInput.KeyCode == Enum.KeyCode.Tab) then
                        local modes = {"Killer", "Survivor", "SCP"}
                        local idx
                        for i, m in ipairs(modes) do
                            if m == autoAimState.targetMode then idx = i; break end
                        end
                        idx = (idx % 3) + 1
                        autoAimState.targetMode = modes[idx]
                        showModeNotification(autoAimState.targetMode)
                        releaseConn:Disconnect()
                    end
                end)
                task.delay(1, function()
                    if releaseConn then releaseConn:Disconnect() end
                end)
            end
        end)
    end

    -- ========== AKTIVASI ==========
    createAutoAimGUI()
    setupMouseButton2Detection()
    setupKeybindDetection()
    setupMobileButton()

    autoAimConnection = RunService.Heartbeat:Connect(function() end)

    autoAimState.isActive = true
    print("[AutoAim] Auto aim started with mode: " .. autoAimState.targetMode)
end
              

-- Fungsi stopAutoAim (tidak berubah, tetap menghancurkan semua)
local function stopAutoAim()
    if not autoAimConnection then return end

    autoAimConnection:Disconnect()
    autoAimConnection = nil

    if autoAimState.mouseDownConn then
        autoAimState.mouseDownConn:Disconnect()
        autoAimState.mouseDownConn = nil
    end
    if autoAimState.mouseUpConn then
        autoAimState.mouseUpConn:Disconnect()
        autoAimState.mouseUpConn = nil
    end
    if autoAimState.keyConn then
        autoAimState.keyConn:Disconnect()
        autoAimState.keyConn = nil
    end
    if autoAimState.lockConn then
        autoAimState.lockConn:Disconnect()
        autoAimState.lockConn = nil
    end
    if autoAimState.lockTimer then
        task.cancel(autoAimState.lockTimer)
        autoAimState.lockTimer = nil
    end
    if autoAimState.mobileHoldTimer then
        task.cancel(autoAimState.mobileHoldTimer)
        autoAimState.mobileHoldTimer = nil
    end

    if autoAimState.mobileButtonGui then
        autoAimState.mobileButtonGui:Destroy()
        autoAimState.mobileButtonGui = nil
        autoAimState.mobileButton = nil
    end

    autoAimState.lockActive = false

    if autoAimState.guiRef then
        autoAimState.guiRef:Destroy()
        autoAimState.guiRef = nil
    end

    local localChar = localPlayer.Character
    if localChar then
        local humanoid = localChar:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.AutoRotate = true
        end
    end

    autoAimState.isActive = false
    print("[AutoAim] Auto aim stopped")
end

              
-- ============================================================================
-- FEATURE 16: TELEPORT TO NEAREST SURVIVOR (unchanged)
-- ============================================================================
local function getNearestSurvivor()
    local nearest = nil
    local minDist = math.huge
    if not localRootPart then return nil end
    local localPos = localRootPart.Position
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local char = player.Character
            if char then
                local isKiller = false
                if player.Team then
                    isKiller = (player.Team.Name:lower():find("killer") or player.Team.Name:lower():find("monster") or player.Team.Name:lower():find("enemy"))
                end
                if not isKiller then
                    local tool = char:FindFirstChildWhichIsA("Tool")
                    if tool and (tool.Name:lower():find("knife") or tool.Name:lower():find("weapon")) then
                        isKiller = true
                    end
                end
                if not isKiller then
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

local function teleportToNearestSurvivor()
    if not localRootPart then return end
    local targetPlayer = getNearestSurvivor()
    if targetPlayer and targetPlayer.Character then
        local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart") or targetPlayer.Character:FindFirstChild("Torso")
        if targetRoot then
            localRootPart.CFrame = targetRoot.CFrame + Vector3.new(0, 2, 0)
            print("[Teleport] Teleported to survivor: " .. targetPlayer.Name)
        else
            print("[Teleport] Target has no root part")
        end
    else
        print("[Teleport] No survivor found nearby")
    end
end



-- ============================================================================  
-- FEATURE 17: MODERN GUI (UPGRADED - MINIMIZE TO FLOATING BAR + INFO TAB)  
-- ============================================================================  
  
-- Variabel global untuk floating bar  
local floatingBar = nil  
local isFloatingVisible = false  

-- ============================================================================  
-- DRAGGABLE (tidak berubah)  
-- ============================================================================  
local function makeDraggable(frame)  
    local dragging = false  
    local dragStart, startPos  
    frame.InputBegan:Connect(function(input)  
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then  
            dragging = true  
            dragStart = input.Position  
            startPos = frame.Position  
        end  
    end)  
    frame.InputChanged:Connect(function(input)  
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then  
            local delta = input.Position - dragStart  
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,  
                                      startPos.Y.Scale, startPos.Y.Offset + delta.Y)  
        end  
    end)  
    frame.InputEnded:Connect(function(input)  
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then  
            dragging = false  
        end  
    end)  
end  
  
-- ============================================================================  
-- THEME UPDATE  
-- ============================================================================  
local function updateTheme()  
    if mainStroke then mainStroke.Color = config.guiThemeColor end  
    if sidebar then  
        for _, btn in ipairs(sidebar:GetDescendants()) do  
            if btn:IsA("TextButton") and btn.Text:find("HOME") then  
                btn.TextColor3 = config.guiThemeColor  
            end  
        end  
    end  
    if statusLabel then statusLabel.TextColor3 = config.guiThemeColor end  
end  
  
-- ============================================================================
local homeContent = nil

-- Simpan state crosshair di luar agar tidak hilang saat pindah sidebar
local crosshairState = {
    enabled = false,
    style = "plus", -- plus, x, o
    posX = 50,
    posY = 50
}

local function createHomeContent()
    if homeContent then
        homeContent:Destroy()
    end

    homeContent = Instance.new("Frame")
    homeContent.Size = UDim2.new(1,0,1,0)
    homeContent.BackgroundTransparency = 1
    homeContent.ClipsDescendants = true
    homeContent.Parent = contentPanel

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1,-8,1,-8)
    scroll.Position = UDim2.new(0,4,0,4)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 2
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = homeContent

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0,10)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0,4)
    padding.PaddingBottom = UDim.new(0,10)
    padding.PaddingLeft = UDim.new(0,2)
    padding.PaddingRight = UDim.new(0,2)
    padding.Parent = scroll

    --// HEADER CARD
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1,-6,0,110)
    header.BackgroundColor3 = Color3.fromRGB(8,18,34)
    header.BorderSizePixel = 0
    header.Parent = scroll
    Instance.new("UICorner",header).CornerRadius = UDim.new(0,10)
    local headerStroke = Instance.new("UIStroke")
    headerStroke.Color = Color3.fromRGB(0,180,255)
    headerStroke.Transparency = 0.35
    headerStroke.Parent = header

    -- LOGO HOLDER
    local logoHolder = Instance.new("Frame")
    logoHolder.Size = UDim2.new(0,56,0,56)
    logoHolder.Position = UDim2.new(0,12,0,12)
    logoHolder.BackgroundColor3 = Color3.fromRGB(10,28,48)
    logoHolder.BorderSizePixel = 0
    logoHolder.ClipsDescendants = true
    logoHolder.Parent = header
    Instance.new("UICorner",logoHolder).CornerRadius = UDim.new(0,8)
    local logoStroke = Instance.new("UIStroke")
    logoStroke.Color = Color3.fromRGB(0,200,255)
    logoStroke.Transparency = 0.45
    logoStroke.Parent = logoHolder

    local logo = Instance.new("ImageLabel")
    logo.Size = UDim2.new(1,-16,1,-16)
    logo.AnchorPoint = Vector2.new(0.5,0.5)
    logo.Position = UDim2.new(0.5,0,0.5,0)
    logo.BackgroundTransparency = 1
    logo.BorderSizePixel = 0
    logo.Image = "rbxassetid://172732271"
    logo.ScaleType = Enum.ScaleType.Fit
    logo.Visible = true
    logo.ImageTransparency = 0
    logo.ZIndex = 5
    logo.Parent = logoHolder

    -- TITLE
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1,-90,0,26)
    title.Position = UDim2.new(0,80,0,14)
    title.BackgroundTransparency = 1
    title.Text = "KEMI HUB"
    title.TextColor3 = Color3.fromRGB(0,225,255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextWrapped = true
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1,-92,0,46)
    desc.Position = UDim2.new(0,80,0,42)
    desc.BackgroundTransparency = 1
    desc.Text = "script by kemi"
    desc.TextColor3 = Color3.fromRGB(210,210,210)
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 12
    desc.TextWrapped = true
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextYAlignment = Enum.TextYAlignment.Top
    desc.ClipsDescendants = true
    desc.Parent = header

    --// INFORMATION CARD
    local infoCard = Instance.new("Frame")
    infoCard.Size = UDim2.new(1,-6,0,150)
    infoCard.BackgroundColor3 = Color3.fromRGB(8,18,32)
    infoCard.BorderSizePixel = 0
    infoCard.Parent = scroll
    Instance.new("UICorner",infoCard).CornerRadius = UDim.new(0,10)
    local infoStroke = Instance.new("UIStroke")
    infoStroke.Color = Color3.fromRGB(0,180,255)
    infoStroke.Transparency = 0.45
    infoStroke.Parent = infoCard

    local infoTitle = Instance.new("TextLabel")
    infoTitle.Size = UDim2.new(1,-20,0,22)
    infoTitle.Position = UDim2.new(0,10,0,10)
    infoTitle.BackgroundTransparency = 1
    infoTitle.Text = "SYSTEM INFORMATION"
    infoTitle.TextColor3 = Color3.fromRGB(0,220,255)
    infoTitle.Font = Enum.Font.GothamBold
    infoTitle.TextSize = 14
    infoTitle.TextXAlignment = Enum.TextXAlignment.Left
    infoTitle.Parent = infoCard

    local infoText = Instance.new("TextLabel")
    infoText.Size = UDim2.new(1,-20,1,-44)
    infoText.Position = UDim2.new(0,10,0,36)
    infoText.BackgroundTransparency = 1
    infoText.RichText = true
    infoText.TextWrapped = true
    infoText.TextXAlignment = Enum.TextXAlignment.Left
    infoText.TextYAlignment = Enum.TextYAlignment.Top
    infoText.ClipsDescendants = true
    infoText.Font = Enum.Font.Gotham
    infoText.TextSize = 10
    infoText.TextColor3 = Color3.fromRGB(225,225,225)
    infoText.Text = [[
<b>STATUS</b>
🟢 Online

<b>VERSION</b>
10.1 Experimental

<b>DEVELOPER</b>
Kemi Studio
    ]]
    infoText.Parent = infoCard

    --// CROSSHAIR SETTINGS (dengan slider posisi X dan Y)
    local crosshairCard = Instance.new("Frame")
    crosshairCard.Size = UDim2.new(1,-6,0,260)
    crosshairCard.BackgroundColor3 = Color3.fromRGB(8,20,36)
    crosshairCard.BorderSizePixel = 0
    crosshairCard.Parent = scroll

    Instance.new("UICorner",crosshairCard).CornerRadius = UDim.new(0,10)
    local crossStroke = Instance.new("UIStroke")
    crossStroke.Color = Color3.fromRGB(0,180,255)
    crossStroke.Transparency = 0.4
    crossStroke.Parent = crosshairCard

    local crossTitle = Instance.new("TextLabel")
    crossTitle.Size = UDim2.new(1,-20,0,24)
    crossTitle.Position = UDim2.new(0,10,0,10)
    crossTitle.BackgroundTransparency = 1
    crossTitle.Text = "🎯 CROSSHAIR SETTINGS"
    crossTitle.TextColor3 = Color3.fromRGB(0,220,255)
    crossTitle.Font = Enum.Font.GothamBold
    crossTitle.TextSize = 14
    crossTitle.TextXAlignment = Enum.TextXAlignment.Left
    crossTitle.Parent = crosshairCard

    local crossDesc = Instance.new("TextLabel")
    crossDesc.Size = UDim2.new(1,-20,0,30)
    crossDesc.Position = UDim2.new(0,10,0,34)
    crossDesc.BackgroundTransparency = 1
    crossDesc.Text = "Customize crosshair position and style."
    crossDesc.TextColor3 = Color3.fromRGB(180,180,180)
    crossDesc.Font = Enum.Font.Gotham
    crossDesc.TextSize = 10
    crossDesc.TextWrapped = true
    crossDesc.TextXAlignment = Enum.TextXAlignment.Left
    crossDesc.TextYAlignment = Enum.TextYAlignment.Top
    crossDesc.Parent = crosshairCard

    -- // SLIDER POSISI X
    local sliderXHolder = Instance.new("Frame")
    sliderXHolder.Size = UDim2.new(1,-20,0,28)
    sliderXHolder.Position = UDim2.new(0,10,0,70)
    sliderXHolder.BackgroundTransparency = 1
    sliderXHolder.Parent = crosshairCard

    local labelX = Instance.new("TextLabel")
    labelX.Size = UDim2.new(0.3,0,1,0)
    labelX.BackgroundTransparency = 1
    labelX.Text = "Position X"
    labelX.TextColor3 = Color3.fromRGB(220,220,220)
    labelX.Font = Enum.Font.GothamBold
    labelX.TextSize = 10
    labelX.TextXAlignment = Enum.TextXAlignment.Left
    labelX.Parent = sliderXHolder

    local valueX = Instance.new("TextLabel")
    valueX.Size = UDim2.new(0.2,0,1,0)
    valueX.Position = UDim2.new(0.3,0,0,0)
    valueX.BackgroundTransparency = 1
    valueX.Text = tostring(crosshairState.posX)
    valueX.TextColor3 = Color3.fromRGB(0,220,255)
    valueX.Font = Enum.Font.GothamBold
    valueX.TextSize = 10
    valueX.TextXAlignment = Enum.TextXAlignment.Left
    valueX.Parent = sliderXHolder

    local sliderXbg = Instance.new("Frame")
    sliderXbg.Size = UDim2.new(0.45,0,0.6,0)
    sliderXbg.Position = UDim2.new(0.55,0,0.2,0)
    sliderXbg.BackgroundColor3 = Color3.fromRGB(25,35,50)
    sliderXbg.BorderSizePixel = 0
    sliderXbg.Parent = sliderXHolder
    Instance.new("UICorner",sliderXbg).CornerRadius = UDim.new(1,0)

    local sliderXthumb = Instance.new("TextButton")
    sliderXthumb.Size = UDim2.new(0,12,0,12)
    sliderXthumb.BackgroundColor3 = Color3.fromRGB(0,200,255)
    sliderXthumb.AutoButtonColor = false
    sliderXthumb.Text = ""
    sliderXthumb.BorderSizePixel = 0
    sliderXthumb.Parent = sliderXbg
    Instance.new("UICorner",sliderXthumb).CornerRadius = UDim.new(1,0)

    -- // SLIDER POSISI Y
    local sliderYHolder = Instance.new("Frame")
    sliderYHolder.Size = UDim2.new(1,-20,0,28)
    sliderYHolder.Position = UDim2.new(0,10,0,102)
    sliderYHolder.BackgroundTransparency = 1
    sliderYHolder.Parent = crosshairCard

    local labelY = Instance.new("TextLabel")
    labelY.Size = UDim2.new(0.3,0,1,0)
    labelY.BackgroundTransparency = 1
    labelY.Text = "Position Y"
    labelY.TextColor3 = Color3.fromRGB(220,220,220)
    labelY.Font = Enum.Font.GothamBold
    labelY.TextSize = 10
    labelY.TextXAlignment = Enum.TextXAlignment.Left
    labelY.Parent = sliderYHolder

    local valueY = Instance.new("TextLabel")
    valueY.Size = UDim2.new(0.2,0,1,0)
    valueY.Position = UDim2.new(0.3,0,0,0)
    valueY.BackgroundTransparency = 1
    valueY.Text = tostring(crosshairState.posY)
    valueY.TextColor3 = Color3.fromRGB(0,220,255)
    valueY.Font = Enum.Font.GothamBold
    valueY.TextSize = 10
    valueY.TextXAlignment = Enum.TextXAlignment.Left
    valueY.Parent = sliderYHolder

    local sliderYbg = Instance.new("Frame")
    sliderYbg.Size = UDim2.new(0.45,0,0.6,0)
    sliderYbg.Position = UDim2.new(0.55,0,0.2,0)
    sliderYbg.BackgroundColor3 = Color3.fromRGB(25,35,50)
    sliderYbg.BorderSizePixel = 0
    sliderYbg.Parent = sliderYHolder
    Instance.new("UICorner",sliderYbg).CornerRadius = UDim.new(1,0)

    local sliderYthumb = Instance.new("TextButton")
    sliderYthumb.Size = UDim2.new(0,12,0,12)
    sliderYthumb.BackgroundColor3 = Color3.fromRGB(0,200,255)
    sliderYthumb.AutoButtonColor = false
    sliderYthumb.Text = ""
    sliderYthumb.BorderSizePixel = 0
    sliderYthumb.Parent = sliderYbg
    Instance.new("UICorner",sliderYthumb).CornerRadius = UDim.new(1,0)

    -- // SHAPE BUTTONS (style)
    local buttonHolder = Instance.new("Frame")
    buttonHolder.Size = UDim2.new(1,-20,0,34)
    buttonHolder.Position = UDim2.new(0,10,0,140)
    buttonHolder.BackgroundTransparency = 1
    buttonHolder.Parent = crosshairCard

    local btnLayout = Instance.new("UIListLayout")
    btnLayout.FillDirection = Enum.FillDirection.Horizontal
    btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    btnLayout.Padding = UDim.new(0,8)
    btnLayout.Parent = buttonHolder

    local function createShapeButton(text, selected)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.31,0,1,0)
        btn.BackgroundColor3 = selected and Color3.fromRGB(0,140,255) or Color3.fromRGB(12,22,38)
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255,255,255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.Parent = buttonHolder
        Instance.new("UICorner",btn).CornerRadius = UDim.new(0,7)
        return btn
    end

    local plusBtn = createShapeButton("+", crosshairState.style == "plus")
    local xBtn = createShapeButton("X", crosshairState.style == "x")
    local oBtn = createShapeButton("O", crosshairState.style == "o")

    -- // TOGGLE BUTTON
    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(1,-20,0,36)
    toggleButton.Position = UDim2.new(0,10,0,185)
    toggleButton.BackgroundColor3 = crosshairState.enabled and Color3.fromRGB(0,140,255) or Color3.fromRGB(14,24,40)
    toggleButton.Text = crosshairState.enabled and "CROSSHAIR ENABLED" or "CROSSHAIR DISABLED"
    toggleButton.TextColor3 = crosshairState.enabled and Color3.fromRGB(255,255,255) or Color3.fromRGB(220,220,220)
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.TextSize = 12
    toggleButton.BorderSizePixel = 0
    toggleButton.AutoButtonColor = false
    toggleButton.Parent = crosshairCard
    Instance.new("UICorner",toggleButton).CornerRadius = UDim.new(0,8)

    -- // LOGIKA CROSSHAIR GUI
    local crossGui = game.CoreGui:FindFirstChild("CyberCrosshair")
    if crossGui then crossGui:Destroy() end

    crossGui = Instance.new("ScreenGui")
    crossGui.Name = "CyberCrosshair"
    crossGui.IgnoreGuiInset = true
    crossGui.ResetOnSpawn = false
    crossGui.Enabled = crosshairState.enabled
    crossGui.Parent = game.CoreGui

    local center = Instance.new("Frame")
    center.Size = UDim2.new(0,0,0,0)
    center.Position = UDim2.new(0.5,0,0.5,0)
    center.BackgroundTransparency = 1
    center.Parent = crossGui

    local function createLine(size, pos)
        local line = Instance.new("Frame")
        line.Size = size
        line.Position = pos
        line.BackgroundColor3 = Color3.fromRGB(0,220,255)
        line.BorderSizePixel = 0
        line.Parent = center
        return line
    end

    local topLine = createLine(UDim2.new(0,2,0,18), UDim2.new(0,-1,0,-22))
    local bottomLine = createLine(UDim2.new(0,2,0,18), UDim2.new(0,-1,0,4))
    local leftLine = createLine(UDim2.new(0,18,0,2), UDim2.new(0,-22,0,-1))
    local rightLine = createLine(UDim2.new(0,18,0,2), UDim2.new(0,4,0,-1))

    local x1 = createLine(UDim2.new(0,2,0,30), UDim2.new(0,-1,0,-15))
    x1.Rotation = 45
    x1.Visible = false

    local x2 = createLine(UDim2.new(0,2,0,30), UDim2.new(0,-1,0,-15))
    x2.Rotation = -45
    x2.Visible = false

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0,24,0,24)
    circle.Position = UDim2.new(0,-12,0,-12)
    circle.BackgroundTransparency = 1
    circle.Visible = false
    circle.Parent = center
    Instance.new("UICorner",circle).CornerRadius = UDim.new(1,0)
    local circleStroke = Instance.new("UIStroke")
    circleStroke.Color = Color3.fromRGB(0,220,255)
    circleStroke.Thickness = 2
    circleStroke.Parent = circle

    -- Fungsi update posisi crosshair (perbaiki dengan viewport)
    local camera = workspace.CurrentCamera
    local function updateCrosshairPosition()
        local posX = tonumber(valueX.Text) or 0
        local posY = tonumber(valueY.Text) or 0
        crosshairState.posX = posX
        crosshairState.posY = posY
        local viewport = camera.ViewportSize
        local offsetX = (posX - 50) * viewport.X * 0.004
        local offsetY = (posY - 50) * viewport.Y * 0.004
        center.Position = UDim2.new(0.5, offsetX, 0.5, offsetY)
    end

    -- Fungsi update style visual
    local function applyStyle(style)
        crosshairState.style = style
        if style == "plus" then
            topLine.Visible = true
            bottomLine.Visible = true
            leftLine.Visible = true
            rightLine.Visible = true
            x1.Visible = false
            x2.Visible = false
            circle.Visible = false
        elseif style == "x" then
            topLine.Visible = false
            bottomLine.Visible = false
            leftLine.Visible = false
            rightLine.Visible = false
            x1.Visible = true
            x2.Visible = true
            circle.Visible = false
        elseif style == "o" then
            topLine.Visible = false
            bottomLine.Visible = false
            leftLine.Visible = false
            rightLine.Visible = false
            x1.Visible = false
            x2.Visible = false
            circle.Visible = true
        end
    end

    applyStyle(crosshairState.style)

    -- ========================
    -- SLIDER X & Y - REAL TIME DRAG (RenderStepped + GetMouseLocation)
    -- ========================
    local userInput = game:GetService("UserInputService")
    local runService = game:GetService("RunService")

    -- Slider X
    local draggingX = false
    local function setSliderX(val)
        val = math.clamp(val, 0, 100)
        valueX.Text = tostring(val)
        -- Hitung posisi thumb agar tidak keluar track
        local thumbSize = sliderXthumb.AbsoluteSize.X
        local trackSize = sliderXbg.AbsoluteSize.X
        if trackSize > 0 then
            local rel = val / 100
            local px = math.clamp(rel * trackSize, thumbSize/2, trackSize - thumbSize/2)
            sliderXthumb.Position = UDim2.new(0, px - thumbSize/2, 0.5, -thumbSize/2)
        else
            -- fallback
            sliderXthumb.Position = UDim2.new(val/100, -thumbSize/2, 0.5, -thumbSize/2)
        end
        crosshairState.posX = val
        updateCrosshairPosition()
    end

    local function updateSliderXFromMouse()
        if not draggingX then return end
        local mousePos = userInput:GetMouseLocation()
        local bgPos = sliderXbg.AbsolutePosition.X
        local bgWidth = sliderXbg.AbsoluteSize.X
        if bgWidth <= 0 then return end
        local rel = (mousePos.X - bgPos) / bgWidth
        local val = math.floor(math.clamp(rel, 0, 1) * 100)
        setSliderX(val)
    end

    sliderXthumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingX = true
            updateSliderXFromMouse()
        end
    end)
    sliderXbg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingX = true
            updateSliderXFromMouse()
        end
    end)
    userInput.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingX = false
        end
    end)
    runService.RenderStepped:Connect(function()
        if draggingX then
            updateSliderXFromMouse()
        end
    end)

    -- Slider Y (horizontal movement)
    local draggingY = false
    local function setSliderY(val)
        val = math.clamp(val, 0, 100)
        valueY.Text = tostring(val)
        local thumbSize = sliderYthumb.AbsoluteSize.X
        local trackSize = sliderYbg.AbsoluteSize.X
        if trackSize > 0 then
            local rel = val / 100
            local px = math.clamp(rel * trackSize, thumbSize/2, trackSize - thumbSize/2)
            sliderYthumb.Position = UDim2.new(0, px - thumbSize/2, 0.5, -thumbSize/2)
        else
            sliderYthumb.Position = UDim2.new(val/100, -thumbSize/2, 0.5, -thumbSize/2)
        end
        crosshairState.posY = val
        updateCrosshairPosition()
    end

    local function updateSliderYFromMouse()
        if not draggingY then return end
        local mousePos = userInput:GetMouseLocation()
        local bgPos = sliderYbg.AbsolutePosition.X  -- perhatikan: pakai X
        local bgWidth = sliderYbg.AbsoluteSize.X
        if bgWidth <= 0 then return end
        local rel = (mousePos.X - bgPos) / bgWidth
        local val = math.floor(math.clamp(rel, 0, 1) * 100)
        setSliderY(val)
    end

    sliderYthumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingY = true
            updateSliderYFromMouse()
        end
    end)
    sliderYbg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingY = true
            updateSliderYFromMouse()
        end
    end)
    userInput.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingY = false
        end
    end)
    runService.RenderStepped:Connect(function()
        if draggingY then
            updateSliderYFromMouse()
        end
    end)

    -- Style button logic
    local function resetButtons()
        plusBtn.BackgroundColor3 = Color3.fromRGB(12,22,38)
        xBtn.BackgroundColor3 = Color3.fromRGB(12,22,38)
        oBtn.BackgroundColor3 = Color3.fromRGB(12,22,38)
    end

    plusBtn.MouseButton1Click:Connect(function()
        resetButtons()
        plusBtn.BackgroundColor3 = Color3.fromRGB(0,140,255)
        applyStyle("plus")
    end)

    xBtn.MouseButton1Click:Connect(function()
        resetButtons()
        xBtn.BackgroundColor3 = Color3.fromRGB(0,140,255)
        applyStyle("x")
    end)

    oBtn.MouseButton1Click:Connect(function()
        resetButtons()
        oBtn.BackgroundColor3 = Color3.fromRGB(0,140,255)
        applyStyle("o")
    end)

    -- Toggle crosshair
    toggleButton.MouseButton1Click:Connect(function()
        crosshairState.enabled = not crosshairState.enabled
        crossGui.Enabled = crosshairState.enabled
        if crosshairState.enabled then
            toggleButton.Text = "CROSSHAIR ENABLED"
            toggleButton.BackgroundColor3 = Color3.fromRGB(0,140,255)
            toggleButton.TextColor3 = Color3.fromRGB(255,255,255)
        else
            toggleButton.Text = "CROSSHAIR DISABLED"
            toggleButton.BackgroundColor3 = Color3.fromRGB(14,24,40)
            toggleButton.TextColor3 = Color3.fromRGB(220,220,220)
        end
    end)

    -- Inisialisasi nilai slider sesuai state
    setSliderX(crosshairState.posX)
    setSliderY(crosshairState.posY)
    updateCrosshairPosition()

    print("[Home] Crosshair settings with position sliders loaded (state preserved, drag fixed)")
end
-- ============================================================================
-- INFO CONTENT
-- ============================================================================
local infoContent=nil
local function createInfoContent()
    if infoContent then infoContent:Destroy() end

    infoContent=Instance.new("Frame")
    infoContent.Size=UDim2.new(1,0,1,0)
    infoContent.BackgroundTransparency=1
    infoContent.ClipsDescendants=true
    infoContent.Parent=contentPanel

    local scroll=Instance.new("ScrollingFrame")
    scroll.Size=UDim2.new(1,-6,1,-6)
    scroll.Position=UDim2.new(0,3,0,3)
    scroll.BackgroundTransparency=1
    scroll.BorderSizePixel=0
    scroll.ScrollBarThickness=3
    scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
    scroll.CanvasSize=UDim2.new(0,0,0,0)
    scroll.Parent=infoContent

    local layout=Instance.new("UIListLayout")
    layout.Padding=UDim.new(0,8)
    layout.HorizontalAlignment=Enum.HorizontalAlignment.Center
    layout.SortOrder=Enum.SortOrder.LayoutOrder
    layout.Parent=scroll

    local padding=Instance.new("UIPadding")
    padding.PaddingTop=UDim.new(0,4)
    padding.PaddingBottom=UDim.new(0,8)
    padding.PaddingLeft=UDim.new(0,2)
    padding.PaddingRight=UDim.new(0,2)
    padding.Parent=scroll

    local header=Instance.new("Frame")
    header.Size=UDim2.new(1,-8,0,95)
    header.BackgroundColor3=Color3.fromRGB(8,20,38)
    header.BorderSizePixel=0
    header.Parent=scroll

    Instance.new("UICorner",header).CornerRadius=UDim.new(0,8)

    local headerStroke=Instance.new("UIStroke")
    headerStroke.Color=Color3.fromRGB(0,180,255)
    headerStroke.Transparency=0.35
    headerStroke.Parent=header

    local title=Instance.new("TextLabel")
    title.Size=UDim2.new(1,-20,0,28)
    title.Position=UDim2.new(0,10,0,8)
    title.BackgroundTransparency=1
    title.Text="🌐 COMMUNITY & INFORMATION"
    title.TextColor3=Color3.fromRGB(0,220,255)
    title.Font=Enum.Font.GothamBold
    title.TextSize=14
    title.TextWrapped=true
    title.TextXAlignment=Enum.TextXAlignment.Left
    title.Parent=header

    local desc=Instance.new("TextLabel")
    desc.Size=UDim2.new(1,-20,0,42)
    desc.Position=UDim2.new(0,10,0,40)
    desc.BackgroundTransparency=1
    desc.Text="Join our official community platforms and access script information, updates and announcements."
    desc.TextColor3=Color3.fromRGB(210,210,210)
    desc.Font=Enum.Font.Gotham
    desc.TextSize=10
    desc.TextWrapped=true
    desc.TextXAlignment=Enum.TextXAlignment.Left
    desc.TextYAlignment=Enum.TextYAlignment.Top
    desc.Parent=header

    local communityCard=Instance.new("Frame")
    communityCard.Size=UDim2.new(1,-8,0,180)
    communityCard.BackgroundColor3=Color3.fromRGB(8,18,32)
    communityCard.BorderSizePixel=0
    communityCard.Parent=scroll

    Instance.new("UICorner",communityCard).CornerRadius=UDim.new(0,8)

    local communityStroke=Instance.new("UIStroke")
    communityStroke.Color=Color3.fromRGB(0,180,255)
    communityStroke.Transparency=0.45
    communityStroke.Parent=communityCard

    local communityTitle=Instance.new("TextLabel")
    communityTitle.Size=UDim2.new(1,-20,0,24)
    communityTitle.Position=UDim2.new(0,10,0,8)
    communityTitle.BackgroundTransparency=1
    communityTitle.Text="📱 OFFICIAL SOCIAL"
    communityTitle.TextColor3=Color3.fromRGB(0,220,255)
    communityTitle.Font=Enum.Font.GothamBold
    communityTitle.TextSize=10
    communityTitle.TextXAlignment=Enum.TextXAlignment.Left
    communityTitle.Parent=communityCard

    local discordFrame=Instance.new("Frame")
    discordFrame.Size=UDim2.new(1,-20,0,58)
    discordFrame.Position=UDim2.new(0,10,0,40)
    discordFrame.BackgroundColor3=Color3.fromRGB(10,24,42)
    discordFrame.BorderSizePixel=0
    discordFrame.Parent=communityCard

    Instance.new("UICorner",discordFrame).CornerRadius=UDim.new(0,6)

    local discordImage=Instance.new("ImageLabel")
    discordImage.Size=UDim2.new(0,34,0,34)
    discordImage.Position=UDim2.new(0,10,0.5,-17)
    discordImage.BackgroundTransparency=1
    discordImage.Image="rbxassetid://8560914563"
    discordImage.Parent=discordFrame

    local discordText=Instance.new("TextLabel")
    discordText.Size=UDim2.new(0.45,0,1,0)
    discordText.Position=UDim2.new(0,52,0,0)
    discordText.BackgroundTransparency=1
    discordText.Text="Discord Server"
    discordText.TextColor3=Color3.fromRGB(220,220,220)
    discordText.Font=Enum.Font.GothamBold
    discordText.TextSize=12
    discordText.TextXAlignment=Enum.TextXAlignment.Left
    discordText.Parent=discordFrame

    local discordButton=Instance.new("TextButton")
    discordButton.Size=UDim2.new(0,88,0,30)
    discordButton.Position=UDim2.new(1,-98,0.5,-15)
    discordButton.BackgroundColor3=Color3.fromRGB(88,101,242)
    discordButton.Text="COPY LINK"
    discordButton.TextColor3=Color3.fromRGB(255,255,255)
    discordButton.Font=Enum.Font.GothamBold
    discordButton.TextSize=10
    discordButton.BorderSizePixel=0
    discordButton.Parent=discordFrame

    Instance.new("UICorner",discordButton).CornerRadius=UDim.new(0,6)

    local tiktokFrame=Instance.new("Frame")
    tiktokFrame.Size=UDim2.new(1,-20,0,58)
    tiktokFrame.Position=UDim2.new(0,10,0,108)
    tiktokFrame.BackgroundColor3=Color3.fromRGB(10,24,42)
    tiktokFrame.BorderSizePixel=0
    tiktokFrame.Parent=communityCard

    Instance.new("UICorner",tiktokFrame).CornerRadius=UDim.new(0,6)

    local tiktokImage=Instance.new("ImageLabel")
    tiktokImage.Size=UDim2.new(0,34,0,34)
    tiktokImage.Position=UDim2.new(0,10,0.5,-17)
    tiktokImage.BackgroundTransparency=1
    tiktokImage.Image="rbxassetid://8606920267"
    tiktokImage.Parent=tiktokFrame

    local tiktokText=Instance.new("TextLabel")
    tiktokText.Size=UDim2.new(0.45,0,1,0)
    tiktokText.Position=UDim2.new(0,52,0,0)
    tiktokText.BackgroundTransparency=1
    tiktokText.Text="TikTok Channel"
    tiktokText.TextColor3=Color3.fromRGB(220,220,220)
    tiktokText.Font=Enum.Font.GothamBold
    tiktokText.TextSize=5
    tiktokText.TextXAlignment=Enum.TextXAlignment.Left
    tiktokText.Parent=tiktokFrame

    local tiktokButton=Instance.new("TextButton")
    tiktokButton.Size=UDim2.new(0,88,0,30)
    tiktokButton.Position=UDim2.new(1,-98,0.5,-15)
    tiktokButton.BackgroundColor3=Color3.fromRGB(255,0,80)
    tiktokButton.Text="COPY LINK"
    tiktokButton.TextColor3=Color3.fromRGB(255,255,255)
    tiktokButton.Font=Enum.Font.GothamBold
    tiktokButton.TextSize=10
    tiktokButton.BorderSizePixel=0
    tiktokButton.Parent=tiktokFrame

    Instance.new("UICorner",tiktokButton).CornerRadius=UDim.new(0,6)

    local infoCard=Instance.new("Frame")
    infoCard.Size=UDim2.new(1,-8,0,165)
    infoCard.BackgroundColor3=Color3.fromRGB(8,20,36)
    infoCard.BorderSizePixel=0
    infoCard.Parent=scroll

    Instance.new("UICorner",infoCard).CornerRadius=UDim.new(0,8)

    local infoStroke=Instance.new("UIStroke")
    infoStroke.Color=Color3.fromRGB(0,180,255)
    infoStroke.Transparency=0.5
    infoStroke.Parent=infoCard

    local infoTitle=Instance.new("TextLabel")
    infoTitle.Size=UDim2.new(1,-20,0,24)
    infoTitle.Position=UDim2.new(0,10,0,8)
    infoTitle.BackgroundTransparency=1
    infoTitle.Text="SCRIPT INFORMATION"
    infoTitle.TextColor3=Color3.fromRGB(0,220,255)
    infoTitle.Font=Enum.Font.GothamBold
    infoTitle.TextSize=14
    infoTitle.TextXAlignment=Enum.TextXAlignment.Left
    infoTitle.Parent=infoCard

    local body=Instance.new("TextLabel")
    body.Size=UDim2.new(1,-20,1,-40)
    body.Position=UDim2.new(0,10,0,34)
    body.BackgroundTransparency=1
    body.RichText=true
    body.TextWrapped=true
    body.TextXAlignment=Enum.TextXAlignment.Left
    body.TextYAlignment=Enum.TextYAlignment.Top
    body.Font=Enum.Font.Gotham
    body.TextSize=10
    body.TextColor3=Color3.fromRGB(220,220,220)
    body.Text=[[
<b>KEMI HUB v10.1</b>
<b>AVAILABLE FEATURES</b>
• ESP System
• Auto Win
• Auto Skill Check
• TP Walk
• Auto Aim
• dagger
• Optimized Layout
    ]]
    body.Parent=infoCard

    local noteCard=Instance.new("Frame")
    noteCard.Size=UDim2.new(1,-8,0,85)
    noteCard.BackgroundColor3=Color3.fromRGB(8,18,32)
    noteCard.BorderSizePixel=0
    noteCard.Parent=scroll

    Instance.new("UICorner",noteCard).CornerRadius=UDim.new(0,8)

    local noteStroke=Instance.new("UIStroke")
    noteStroke.Color=Color3.fromRGB(0,180,255)
    noteStroke.Transparency=0.6
    noteStroke.Parent=noteCard

    local noteText=Instance.new("TextLabel")
    noteText.Size=UDim2.new(1,-20,1,-20)
    noteText.Position=UDim2.new(0,10,0,10)
    noteText.BackgroundTransparency=1
    noteText.Text="script comes from the cyberheroes community "
    noteText.TextColor3=Color3.fromRGB(180,180,180)
    noteText.Font=Enum.Font.Gotham
    noteText.TextSize=10
    noteText.TextWrapped=true
    noteText.TextXAlignment=Enum.TextXAlignment.Left
    noteText.TextYAlignment=Enum.TextYAlignment.Top
    noteText.Parent=noteCard

    discordButton.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard("https://discord.gg/blumbuat")
            discordButton.Text="COPIED"
            task.wait(1)
            discordButton.Text="COPY LINK"
        end
    end)

    tiktokButton.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard("https://tiktok.com/@kemilinux22")
            tiktokButton.Text="COPIED"
            task.wait(1)
            tiktokButton.Text="COPY LINK"
        end
    end)
end
-- ============================================================================
-- ABOUT CONTENT
-- ============================================================================
local aboutContent = nil

-- State movement disimpan di luar fungsi agar persist saat pindah sidebar
local movementState = {
    speed = 16.0,
    percent = 79.9,
    enabled = false
}

local function createAboutContent()
    if aboutContent then
        aboutContent:Destroy()
        aboutContent = nil 
    end
    -- Konstanta range kecepatan (min 0.1, max 20.0)
    local MIN_SPEED = 0.1
    local MAX_SPEED = 20.0

    local function percentToSpeed(percent)
        local speed = MIN_SPEED + ((MAX_SPEED - MIN_SPEED) * (percent / 100))
        return math.floor(speed * 10 + 0.5) / 10
    end

    local function speedToPercent(speed)
        return ((speed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED)) * 100
    end

    -- Ambil state dari luar
    local currentSpeed = movementState.speed
    local speedPercent = movementState.percent
    if speedPercent == 0 and currentSpeed > 0 then
        speedPercent = speedToPercent(currentSpeed)
        movementState.percent = speedPercent
    end
    local tpwalkActive = movementState.enabled

    local tpwalkConnection = nil
    local characterAddedConn = nil
    local sliderDragConnection = nil

    local function startTPWalk()
        if tpwalkConnection then
            tpwalkConnection:Disconnect()
            tpwalkConnection = nil
        end
        tpwalkConnection = RunService.RenderStepped:Connect(function(dt)
            if not tpwalkActive then return end
            local char = localPlayer.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if not hrp or not humanoid then return end
            if humanoid.Health <= 0 then return end
            local moveDirection = humanoid.MoveDirection
            if moveDirection.Magnitude > 0 then
                local delta = moveDirection.Unit * currentSpeed * dt
                hrp.CFrame = hrp.CFrame + delta
            end
        end)
    end

    local function stopTPWalk()
        if tpwalkConnection then
            tpwalkConnection:Disconnect()
            tpwalkConnection = nil
        end
    end

    local function onCharacterAdded()
        if tpwalkActive then
            stopTPWalk()
            startTPWalk()
        end
    end

    -- Buat GUI
    aboutContent = Instance.new("Frame")
    aboutContent.Size = UDim2.new(1,0,1,0)
    aboutContent.BackgroundTransparency = 1
    aboutContent.Parent = contentPanel

    local card = Instance.new("Frame")
    card.Size = UDim2.new(1,-12,1,-12)
    card.Position = UDim2.new(0,6,0,6)
    card.BackgroundColor3 = Color3.fromRGB(8,18,34)
    card.BorderSizePixel = 0
    card.Parent = aboutContent
    Instance.new("UICorner",card).CornerRadius = UDim.new(0,10)
    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = Color3.fromRGB(0,180,255)
    cardStroke.Transparency = 0.5
    cardStroke.Parent = card

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1,0,1,0)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = Color3.fromRGB(255,255,255)
    scroll.ScrollBarImageTransparency = 0.5
    scroll.Parent = card
    local scrollLayout = Instance.new("UIListLayout")
    scrollLayout.Padding = UDim.new(0,12)
    scrollLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
    scrollLayout.Parent = scroll
    local scrollPadding = Instance.new("UIPadding")
    scrollPadding.PaddingTop = UDim.new(0,12)
    scrollPadding.PaddingBottom = UDim.new(0,12)
    scrollPadding.PaddingLeft = UDim.new(0,12)
    scrollPadding.PaddingRight = UDim.new(0,12)
    scrollPadding.Parent = scroll

    -- ========== SLIDER KECEPATAN ========== (tidak diubah)
    local speedCard = Instance.new("Frame")
    speedCard.Size = UDim2.new(1,0,0,90)
    speedCard.BackgroundColor3 = Color3.fromRGB(10,20,36)
    speedCard.BorderSizePixel = 0
    speedCard.Parent = scroll
    Instance.new("UICorner",speedCard).CornerRadius = UDim.new(0,8)
    local speedStroke = Instance.new("UIStroke")
    speedStroke.Color = Color3.fromRGB(0,180,255)
    speedStroke.Transparency = 0.4
    speedStroke.Parent = speedCard

    local speedTitle = Instance.new("TextLabel")
    speedTitle.Size = UDim2.new(1,-16,0,24)
    speedTitle.Position = UDim2.new(0,8,0,6)
    speedTitle.BackgroundTransparency = 1
    speedTitle.Text = "MOVEMENT SPEED"
    speedTitle.TextColor3 = Color3.fromRGB(0,220,255)
    speedTitle.Font = Enum.Font.GothamBold
    speedTitle.TextSize = 14
    speedTitle.TextXAlignment = Enum.TextXAlignment.Left
    speedTitle.Parent = speedCard

    local speedDesc = Instance.new("TextLabel")
    speedDesc.Size = UDim2.new(1,-16,0,16)
    speedDesc.Position = UDim2.new(0,8,0,30)
    speedDesc.BackgroundTransparency = 1
    speedDesc.Text = "CFrame-based movement (permanent)"
    speedDesc.TextColor3 = Color3.fromRGB(160,160,160)
    speedDesc.Font = Enum.Font.Gotham
    speedDesc.TextSize = 8
    speedDesc.TextXAlignment = Enum.TextXAlignment.Left
    speedDesc.Parent = speedCard

    local speedValueLabel = Instance.new("TextLabel")
    speedValueLabel.Size = UDim2.new(0.2,0,0,20)
    speedValueLabel.Position = UDim2.new(0.75,0,0,52)
    speedValueLabel.BackgroundTransparency = 1
    speedValueLabel.Text = string.format("%.1f", currentSpeed)
    speedValueLabel.TextColor3 = Color3.fromRGB(0,220,255)
    speedValueLabel.Font = Enum.Font.GothamBold
    speedValueLabel.TextSize = 10
    speedValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    speedValueLabel.Parent = speedCard

    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(0.68,0,0,6)
    sliderBg.Position = UDim2.new(0,14,0,64)
    sliderBg.BackgroundColor3 = Color3.fromRGB(35,45,65)
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = speedCard
    Instance.new("UICorner",sliderBg).CornerRadius = UDim.new(1,0)

    local sliderThumb = Instance.new("TextButton")
    sliderThumb.Size = UDim2.new(0,12,0,12)
    local initRel = speedPercent / 100
    sliderThumb.Position = UDim2.new(initRel, -6, 0.5, -6)
    sliderThumb.BackgroundColor3 = Color3.fromRGB(0,200,255)
    sliderThumb.AutoButtonColor = false
    sliderThumb.Text = ""
    sliderThumb.BorderSizePixel = 0
    sliderThumb.Parent = sliderBg
    Instance.new("UICorner",sliderThumb).CornerRadius = UDim.new(1,0)

    -- ========== TOGGLE TP WALK ========== (tidak diubah)
    local toggleCard = Instance.new("Frame")
    toggleCard.Size = UDim2.new(1,0,0,70)
    toggleCard.BackgroundColor3 = Color3.fromRGB(10,20,36)
    toggleCard.BorderSizePixel = 0
    toggleCard.Parent = scroll
    Instance.new("UICorner",toggleCard).CornerRadius = UDim.new(0,8)
    local toggleStroke = Instance.new("UIStroke")
    toggleStroke.Color = Color3.fromRGB(0,180,255)
    toggleStroke.Transparency = 0.4
    toggleStroke.Parent = toggleCard

    local toggleTitle = Instance.new("TextLabel")
    toggleTitle.Size = UDim2.new(1,-16,0,24)
    toggleTitle.Position = UDim2.new(0,8,0,8)
    toggleTitle.BackgroundTransparency = 1
    toggleTitle.Text = "ENABLE TP WALK"
    toggleTitle.TextColor3 = Color3.fromRGB(0,220,255)
    toggleTitle.Font = Enum.Font.GothamBold
    toggleTitle.TextSize = 10
    toggleTitle.TextXAlignment = Enum.TextXAlignment.Left
    toggleTitle.Parent = toggleCard

    local toggleDesc = Instance.new("TextLabel")
    toggleDesc.Size = UDim2.new(1,-70,0,16)
    toggleDesc.Position = UDim2.new(0,8,0,32)
    toggleDesc.BackgroundTransparency = 1
    toggleDesc.Text = "CFrame teleport walk (bypass speed limit)"
    toggleDesc.TextColor3 = Color3.fromRGB(160,160,160)
    toggleDesc.Font = Enum.Font.Gotham
    toggleDesc.TextSize = 8
    toggleDesc.TextXAlignment = Enum.TextXAlignment.Left
    toggleDesc.Parent = toggleCard

    local toggleSwitch = Instance.new("TextButton")
    toggleSwitch.Size = UDim2.new(0,44,0,22)
    toggleSwitch.Position = UDim2.new(1,-52,0.5,-11)
    toggleSwitch.BackgroundColor3 = tpwalkActive and Color3.fromRGB(0,140,255) or Color3.fromRGB(45,45,65)
    toggleSwitch.Text = ""
    toggleSwitch.AutoButtonColor = false
    toggleSwitch.BorderSizePixel = 0
    toggleSwitch.Parent = toggleCard
    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(1,0)
    switchCorner.Parent = toggleSwitch
    local switchStroke = Instance.new("UIStroke")
    switchStroke.Color = tpwalkActive and Color3.fromRGB(0,220,255) or Color3.fromRGB(100,100,130)
    switchStroke.Thickness = 1
    switchStroke.Transparency = 0.3
    switchStroke.Parent = toggleSwitch

    local switchCircle = Instance.new("Frame")
    switchCircle.Size = UDim2.new(0,18,0,18)
    switchCircle.Position = tpwalkActive and UDim2.new(1,-22,0.5,-9) or UDim2.new(0,4,0.5,-9)
    switchCircle.BackgroundColor3 = Color3.fromRGB(255,255,255)
    switchCircle.BorderSizePixel = 0
    switchCircle.Parent = toggleSwitch
    Instance.new("UICorner",switchCircle).CornerRadius = UDim.new(1,0)

    -- ========== CARD CUSTOM ESP ==========
    local espCard = Instance.new("Frame")
    espCard.BackgroundColor3 = Color3.fromRGB(10,20,36)
    espCard.BorderSizePixel = 0
    espCard.Parent = scroll
    Instance.new("UICorner",espCard).CornerRadius = UDim.new(0,8)
    local espStroke = Instance.new("UIStroke")
    espStroke.Color = Color3.fromRGB(0,180,255)
    espStroke.Transparency = 0.4
    espStroke.Parent = espCard

    local espInner = Instance.new("Frame")
    espInner.Size = UDim2.new(1,-16,0,0)
    espInner.Position = UDim2.new(0,8,0,8)
    espInner.BackgroundTransparency = 1
    espInner.Parent = espCard

    local espLayout = Instance.new("UIListLayout")
    espLayout.Padding = UDim.new(0,6)
    espLayout.FillDirection = Enum.FillDirection.Vertical
    espLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    espLayout.SortOrder = Enum.SortOrder.LayoutOrder
    espLayout.Parent = espInner

    local espTitle = Instance.new("TextLabel")
    espTitle.Size = UDim2.new(1,0,0,24)
    espTitle.BackgroundTransparency = 1
    espTitle.Text = "CUSTOM ESP"
    espTitle.TextColor3 = Color3.fromRGB(0,220,255)
    espTitle.Font = Enum.Font.GothamBold
    espTitle.TextSize = 14
    espTitle.TextXAlignment = Enum.TextXAlignment.Left
    espTitle.Parent = espInner

    -- ============================================================
    -- FUNCTION: CREATE TOGGLE ROW (switch style seperti TPWalk)
    -- ============================================================
    local function createToggleRow(parent, labelText, stateKey, colorKey)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1,0,0,28)
        row.BackgroundTransparency = 1
        row.Parent = parent

        -- Label
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.45,0,1,0)
        label.Position = UDim2.new(0,2,0,0)
        label.BackgroundTransparency = 1
        label.Text = labelText
        label.TextColor3 = Color3.fromRGB(200,200,200)
        label.Font = Enum.Font.Gotham
        label.TextSize = 9
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = row

        -- Switch (seperti TPWalk, dengan stroke dan circle)
        local switch = Instance.new("TextButton")
        switch.Size = UDim2.new(0,40,0,20)
        switch.Position = UDim2.new(0.55,0,0.5,-10)
        switch.BackgroundColor3 = config.espCustom[stateKey].enabled and Color3.fromRGB(0,140,255) or Color3.fromRGB(45,45,65)
        switch.Text = ""
        switch.AutoButtonColor = false
        switch.BorderSizePixel = 0
        switch.Parent = row
        local switchCorner = Instance.new("UICorner")
        switchCorner.CornerRadius = UDim.new(1,0)
        switchCorner.Parent = switch

        -- Stroke (mirip TPWalk)
        local switchStroke = Instance.new("UIStroke")
        switchStroke.Color = config.espCustom[stateKey].enabled and Color3.fromRGB(0,220,255) or Color3.fromRGB(100,100,130)
        switchStroke.Thickness = 0.8
        switchStroke.Transparency = 0.3
        switchStroke.Parent = switch

        -- Circle indicator (mirip TPWalk)
        local circle = Instance.new("Frame")
        circle.Size = UDim2.new(0,16,0,16)
        circle.Position = config.espCustom[stateKey].enabled and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)
        circle.BackgroundColor3 = Color3.fromRGB(255,255,255)
        circle.BorderSizePixel = 0
        circle.Parent = switch
        local circleCorner = Instance.new("UICorner")
        circleCorner.CornerRadius = UDim.new(1,0)
        circleCorner.Parent = circle

        -- Label ON/OFF di samping switch
        local stateLabel = Instance.new("TextLabel")
        stateLabel.Size = UDim2.new(0,20,0,16)
        stateLabel.Position = UDim2.new(1, -24, 0.5, -8)
        stateLabel.BackgroundTransparency = 1
        stateLabel.Text = config.espCustom[stateKey].enabled and "ON" or "OFF"
        stateLabel.TextColor3 = config.espCustom[stateKey].enabled and Color3.fromRGB(0,220,255) or Color3.fromRGB(150,150,150)
        stateLabel.Font = Enum.Font.GothamBold
        stateLabel.TextSize = 7
        stateLabel.TextXAlignment = Enum.TextXAlignment.Left
        stateLabel.Parent = row

        -- Color preview (tetap ada)
        local colorPreview = Instance.new("Frame")
        colorPreview.Size = UDim2.new(0,12,0,12)
        colorPreview.Position = UDim2.new(0.78,0,0.5,-6)
        -- Gunakan warna dari config atau default untuk generator/line
        local previewColor = config.espCustom[colorKey] and config.espCustom[colorKey].color or Color3.fromRGB(255,255,255)
        if stateKey == "generator" then
            previewColor = Color3.fromRGB(255, 165, 0) -- warna orange default generator
        elseif stateKey == "line" then
            previewColor = Color3.fromRGB(255, 255, 255) -- putih (akan mengikuti target)
        end
        colorPreview.BackgroundColor3 = previewColor
        colorPreview.BorderSizePixel = 0
        colorPreview.Parent = row
        local previewCorner = Instance.new("UICorner")
        previewCorner.CornerRadius = UDim.new(1,0)
        previewCorner.Parent = colorPreview

        -- Color picker button (hanya jika bukan generator dan bukan line)
        if stateKey ~= "generator" and stateKey ~= "line" then
            local colorBtn = Instance.new("TextButton")
            colorBtn.Size = UDim2.new(0,14,0,14)
            colorBtn.Position = UDim2.new(0.86,0,0.5,-7)
            colorBtn.BackgroundColor3 = Color3.fromRGB(40,50,70)
            colorBtn.Text = "🎨"
            colorBtn.TextColor3 = Color3.fromRGB(255,255,255)
            colorBtn.Font = Enum.Font.Gotham
            colorBtn.TextSize = 10
            colorBtn.BorderSizePixel = 0
            colorBtn.Parent = row
            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0,4)
            btnCorner.Parent = colorBtn

            -- Event toggle
            switch.MouseButton1Click:Connect(function()
                local newState = not config.espCustom[stateKey].enabled
                config.espCustom[stateKey].enabled = newState
                switch.BackgroundColor3 = newState and Color3.fromRGB(0,140,255) or Color3.fromRGB(45,45,65)
                switchStroke.Color = newState and Color3.fromRGB(0,220,255) or Color3.fromRGB(100,100,130)
                circle.Position = newState and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)
                stateLabel.Text = newState and "" or ""
                stateLabel.TextColor3 = newState and Color3.fromRGB(0,220,255) or Color3.fromRGB(150,150,150)
                refreshCustomESP()
            end)

            -- Event color picker (Hue + Brightness slider)
            colorBtn.MouseButton1Click:Connect(function()
                -- Tutup popup sebelumnya
                local existingPopup = game.CoreGui:FindFirstChild("ColorPickerPopup")
                if existingPopup then existingPopup:Destroy() end

                local popup = Instance.new("ScreenGui")
                popup.Name = "ColorPickerPopup"
                popup.ResetOnSpawn = false
                popup.Parent = game.CoreGui

                local popupFrame = Instance.new("Frame")
                popupFrame.Size = UDim2.new(0, 280, 0, 200)
                popupFrame.Position = UDim2.new(0.5,-140,0.5,-100)
                popupFrame.BackgroundColor3 = Color3.fromRGB(12,22,38)
                popupFrame.BackgroundTransparency = 0.1
                popupFrame.BorderSizePixel = 0
                popupFrame.Parent = popup
                Instance.new("UICorner",popupFrame).CornerRadius = UDim.new(0,8)
                local popupStroke = Instance.new("UIStroke")
                popupStroke.Color = Color3.fromRGB(0,180,255)
                popupStroke.Transparency = 0.4
                popupStroke.Parent = popupFrame

                -- Animasi muncul
                popupFrame.Size = UDim2.new(0, 240, 0, 170)
                popupFrame.Position = UDim2.new(0.5,-120,0.5,-85)
                local tweenIn = TweenService:Create(popupFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0, 280, 0, 200),
                    Position = UDim2.new(0.5,-140,0.5,-100)
                })
                tweenIn:Play()

                local popupTitle = Instance.new("TextLabel")
                popupTitle.Size = UDim2.new(1,0,0,28)
                popupTitle.BackgroundTransparency = 1
                popupTitle.Text = "Warna " .. labelText
                popupTitle.TextColor3 = Color3.fromRGB(0,220,255)
                popupTitle.Font = Enum.Font.GothamBold
                popupTitle.TextSize = 12
                popupTitle.Parent = popupFrame

                -- Ambil warna saat ini, konversi ke HSV
                local currentColor = config.espCustom[colorKey].color
                local h, s, v = Color3.toHSV(currentColor)
                -- Satuan tetap 1 (full saturation)
                local currentHue = h
                local currentBrightness = v

                -- Preview warna di bawah title
                local previewContainer = Instance.new("Frame")
                previewContainer.Size = UDim2.new(1,-20,0,30)
                previewContainer.Position = UDim2.new(0,10,0,32)
                previewContainer.BackgroundTransparency = 1
                previewContainer.Parent = popupFrame

                local previewColor = Instance.new("Frame")
                previewColor.Size = UDim2.new(0,40,0,30)
                previewColor.Position = UDim2.new(0.5,-20,0,0)
                previewColor.BackgroundColor3 = currentColor
                previewColor.BorderSizePixel = 0
                previewColor.Parent = previewContainer
                local previewColorCorner = Instance.new("UICorner")
                previewColorCorner.CornerRadius = UDim.new(0,4)
                previewColorCorner.Parent = previewColor
                local previewColorStroke = Instance.new("UIStroke")
                previewColorStroke.Color = Color3.fromRGB(255,255,255)
                previewColorStroke.Transparency = 0.3
                previewColorStroke.Parent = previewColor

                -- Hex value label
                local hexLabel = Instance.new("TextLabel")
                hexLabel.Size = UDim2.new(0,60,0,16)
                hexLabel.Position = UDim2.new(0.5,30,0.5,-8)
                hexLabel.BackgroundTransparency = 1
                hexLabel.Text = string.format("#%02X%02X%02X", currentColor.R*255, currentColor.G*255, currentColor.B*255)
                hexLabel.TextColor3 = Color3.fromRGB(200,200,200)
                hexLabel.Font = Enum.Font.Gotham
                hexLabel.TextSize = 9
                hexLabel.TextXAlignment = Enum.TextXAlignment.Left
                hexLabel.Parent = previewContainer

                -- Fungsi update warna dari Hue dan Brightness
                local function updateColorFromHSB(newH, newB)
                    newH = math.clamp(newH, 0, 1)
                    newB = math.clamp(newB, 0, 1)
                    local newColor = Color3.fromHSV(newH, 1, newB)
                    config.espCustom[colorKey].color = newColor
                    colorPreview.BackgroundColor3 = newColor
                    previewColor.BackgroundColor3 = newColor
                    hexLabel.Text = string.format("#%02X%02X%02X", newColor.R*255, newColor.G*255, newColor.B*255)
                    refreshCustomESP()
                end

                -- Helper: membuat slider dengan gradien dan thumb
                local function createSlider(parent, y, labelText, initial, minVal, maxVal, colorGradient, callback)
                    local holder = Instance.new("Frame")
                    holder.Size = UDim2.new(1,-20,0,30)
                    holder.Position = UDim2.new(0,10,0,y)
                    holder.BackgroundTransparency = 1
                    holder.Parent = parent

                    local lbl = Instance.new("TextLabel")
                    lbl.Size = UDim2.new(0.08,0,1,0)
                    lbl.BackgroundTransparency = 1
                    lbl.Text = labelText
                    lbl.TextColor3 = Color3.fromRGB(200,200,200)
                    lbl.Font = Enum.Font.GothamBold
                    lbl.TextSize = 9
                    lbl.TextXAlignment = Enum.TextXAlignment.Left
                    lbl.Parent = holder

                    local valLabel = Instance.new("TextLabel")
                    valLabel.Size = UDim2.new(0.12,0,1,0)
                    valLabel.Position = UDim2.new(0.08,0,0,0)
                    valLabel.BackgroundTransparency = 1
                    valLabel.Text = tostring(math.floor(initial * 100))
                    valLabel.TextColor3 = Color3.fromRGB(0,220,255)
                    valLabel.Font = Enum.Font.GothamBold
                    valLabel.TextSize = 9
                    valLabel.TextXAlignment = Enum.TextXAlignment.Left
                    valLabel.Parent = holder

                    local bg = Instance.new("Frame")
                    bg.Size = UDim2.new(0.72,0,0,6)
                    bg.Position = UDim2.new(0.22,0,0.5,-3)
                    bg.BackgroundColor3 = Color3.fromRGB(40,50,70)
                    bg.BorderSizePixel = 0
                    bg.Parent = holder

                    -- Gradien warna pada background
                    local grad = Instance.new("UIGradient")
                    grad.Color = colorGradient
                    grad.Parent = bg

                    local bgCorner = Instance.new("UICorner")
                    bgCorner.CornerRadius = UDim.new(1,0)
                    bgCorner.Parent = bg

                    local thumb = Instance.new("TextButton")
                    thumb.Size = UDim2.new(0,12,0,12)
                    thumb.Position = UDim2.new(initial, -6, 0.5, -6)
                    thumb.BackgroundColor3 = Color3.fromRGB(255,255,255)
                    thumb.AutoButtonColor = false
                    thumb.Text = ""
                    thumb.BorderSizePixel = 0
                    thumb.Parent = bg
                    local thumbCorner = Instance.new("UICorner")
                    thumbCorner.CornerRadius = UDim.new(1,0)
                    thumbCorner.Parent = thumb
                    local thumbStroke = Instance.new("UIStroke")
                    thumbStroke.Color = Color3.fromRGB(200,200,200)
                    thumbStroke.Thickness = 1
                    thumbStroke.Transparency = 0.5
                    thumbStroke.Parent = thumb

                    local dragging = false
                    local function update(val)
                        val = math.clamp(val, 0, 1)
                        valLabel.Text = tostring(math.floor(val * 100))
                        thumb.Position = UDim2.new(val, -6, 0.5, -6)
                        callback(val)
                    end

                    thumb.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                            dragging = true
                            local mouseX = input.Position.X
                            local rel = (mouseX - bg.AbsolutePosition.X) / bg.AbsoluteSize.X
                            update(rel)
                        end
                    end)
                    bg.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                            local mouseX = input.Position.X
                            local rel = (mouseX - bg.AbsolutePosition.X) / bg.AbsoluteSize.X
                            update(rel)
                        end
                    end)
                    local moveConn = game:GetService("UserInputService").InputChanged:Connect(function(input)
                        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                            local rel = (input.Position.X - bg.AbsolutePosition.X) / bg.AbsoluteSize.X
                            update(rel)
                        end
                    end)
                    local endConn = game:GetService("UserInputService").InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                            dragging = false
                        end
                    end)

                    popup.Destroying:Connect(function()
                        moveConn:Disconnect()
                        endConn:Disconnect()
                    end)
                end

                -- Buat slider Hue (spektrum warna)
                local hueGradient = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
                    ColorSequenceKeypoint.new(1/6, Color3.fromHSV(1/6, 1, 1)),
                    ColorSequenceKeypoint.new(2/6, Color3.fromHSV(2/6, 1, 1)),
                    ColorSequenceKeypoint.new(3/6, Color3.fromHSV(3/6, 1, 1)),
                    ColorSequenceKeypoint.new(4/6, Color3.fromHSV(4/6, 1, 1)),
                    ColorSequenceKeypoint.new(5/6, Color3.fromHSV(5/6, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
                })
                createSlider(popupFrame, 66, "Hue", currentHue, 0, 1, hueGradient, function(val)
                    currentHue = val
                    updateColorFromHSB(currentHue, currentBrightness)
                end)

                -- Buat slider Brightness (hitam ke putih)
                local brightnessGradient = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(0,0,0)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(255,255,255))
                })
                createSlider(popupFrame, 102, "Bright", currentBrightness, 0, 1, brightnessGradient, function(val)
                    currentBrightness = val
                    updateColorFromHSB(currentHue, currentBrightness)
                end)

                -- Click outside untuk close (tanpa tombol close)
                local function checkClickOutside(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        local pos = input.Position
                        local framePos = popupFrame.AbsolutePosition
                        local frameSize = popupFrame.AbsoluteSize
                        if pos.X < framePos.X or pos.X > framePos.X + frameSize.X or pos.Y < framePos.Y or pos.Y > framePos.Y + frameSize.Y then
                            popup:Destroy()
                        end
                    end
                end
                local outsideConn = game:GetService("UserInputService").InputBegan:Connect(checkClickOutside)

                -- Animasi keluar
                popup.Destroying:Connect(function()
                    outsideConn:Disconnect()
                end)

                -- Animasi keluar saat destroy
                local oldDestroy = popup.Destroy
                popup.Destroy = function(self)
                    local tweenOut = TweenService:Create(popupFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                        Size = UDim2.new(0, 240, 0, 170),
                        Position = UDim2.new(0.5,-120,0.5,-85),
                        BackgroundTransparency = 0.8
                    })
                    tweenOut:Play()
                    tweenOut.Completed:Connect(function()
                        oldDestroy(self)
                    end)
                end
            end)
        else
            -- Untuk generator dan line, tombol color picker tidak dibuat, tetapi toggle tetap berfungsi
            switch.MouseButton1Click:Connect(function()
                local newState = not config.espCustom[stateKey].enabled
                config.espCustom[stateKey].enabled = newState
                switch.BackgroundColor3 = newState and Color3.fromRGB(0,140,255) or Color3.fromRGB(45,45,65)
                switchStroke.Color = newState and Color3.fromRGB(0,220,255) or Color3.fromRGB(100,100,130)
                circle.Position = newState and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)
                stateLabel.Text = newState and "ON" or "OFF"
                stateLabel.TextColor3 = newState and Color3.fromRGB(0,220,255) or Color3.fromRGB(150,150,150)
                refreshCustomESP()
            end)
        end

        return row
    end

    local espCategories = {
        { key = "generator", label = "Generator" },
        { key = "gate",      label = "Gate" },
        { key = "pallet",    label = "Pallet" },
        { key = "hook",      label = "Hook" },
        { key = "scp",       label = "SCP" },
        { key = "windows",   label = "Windows" },
        { key = "killer",    label = "Killer ESP" },
        { key = "survivor",  label = "Survivor ESP" },
        { key = "line",      label = "ESP Line" },
    }

    for _, cat in ipairs(espCategories) do
        createToggleRow(espInner, cat.label, cat.key, cat.key)
    end

    local function updateEspCardHeight()
        local contentHeight = espLayout.AbsoluteContentSize.Y
        espCard.Size = UDim2.new(1,0,0,contentHeight + 16)
    end
    espLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateEspCardHeight)
    task.wait(0.05)
    updateEspCardHeight()

    -- ========== LOGIKA SLIDER ========== (tidak diubah)
    local dragging = false
    local function setSpeedFromPercent(percent)
        percent = math.clamp(percent, 0, 100)
        speedPercent = percent
        currentSpeed = percentToSpeed(percent)
        speedValueLabel.Text = string.format("%.1f", currentSpeed)
        movementState.speed = currentSpeed
        movementState.percent = percent
        local rel = percent / 100
        local trackWidth = sliderBg.AbsoluteSize.X
        local thumbSize = sliderThumb.AbsoluteSize.X
        if trackWidth > 0 then
            local px = math.clamp(rel * trackWidth, thumbSize/2, trackWidth - thumbSize/2)
            sliderThumb.Position = UDim2.new(0, px - thumbSize/2, 0.5, -thumbSize/2)
        else
            sliderThumb.Position = UDim2.new(rel, -thumbSize/2, 0.5, -thumbSize/2)
        end
    end

    local function updateSliderFromMouse()
        if not dragging then return end
        local mousePos = UserInputService:GetMouseLocation()
        local bgPos = sliderBg.AbsolutePosition.X
        local bgWidth = sliderBg.AbsoluteSize.X
        if bgWidth <= 0 then return end
        local rel = (mousePos.X - bgPos) / bgWidth
        local percent = math.floor(math.clamp(rel, 0, 1) * 100)
        setSpeedFromPercent(percent)
    end

    sliderThumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateSliderFromMouse()
        end
    end)
    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateSliderFromMouse()
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    sliderDragConnection = RunService.RenderStepped:Connect(function()
        if dragging then
            updateSliderFromMouse()
        end
    end)

    -- ========== LOGIKA TOGGLE TPWALK ========== (tidak diubah)
    local function updateToggleUI(state)
        tpwalkActive = state
        movementState.enabled = state
        if state then
            toggleSwitch.BackgroundColor3 = Color3.fromRGB(0,140,255)
            switchStroke.Color = Color3.fromRGB(0,220,255)
            switchStroke.Transparency = 0.1
            TweenService:Create(switchCircle, TweenInfo.new(0.16, Enum.EasingStyle.Quad), {
                Position = UDim2.new(1,-22,0.5,-9)
            }):Play()
            startTPWalk()
        else
            toggleSwitch.BackgroundColor3 = Color3.fromRGB(45,45,65)
            switchStroke.Color = Color3.fromRGB(100,100,130)
            switchStroke.Transparency = 0.3
            TweenService:Create(switchCircle, TweenInfo.new(0.16, Enum.EasingStyle.Quad), {
                Position = UDim2.new(0,4,0.5,-9)
            }):Play()
            stopTPWalk()
        end
    end

    toggleSwitch.MouseButton1Click:Connect(function()
        updateToggleUI(not tpwalkActive)
    end)

    -- ========== HANDLE RESPAWN ==========
    characterAddedConn = localPlayer.CharacterAdded:Connect(onCharacterAdded)

    -- ========== GENERATOR PROGRESS UPDATE (DIPERCEPAT 0.1 DETIK) ==========
    local function startGeneratorWatchdog()
        task.spawn(function()
            while aboutContent and aboutContent.Parent do
                if type(updateAllGeneratorProgress) == "function" then
                    updateAllGeneratorProgress()
                end
                task.wait(0.1) -- diubah dari 1 menjadi 0.1 detik
            end
        end)
    end
    startGeneratorWatchdog()

    -- ========== REFRESH NON-GENERATOR ESP BERBASIS EVENT ==========
    local function refreshNonGeneratorESP()
        if type(refreshCustomESP) == "function" then
            refreshCustomESP()
        end
    end

    -- Deteksi perubahan status LocalPlayer (Team)
    local function onLocalPlayerTeamChanged()
        refreshNonGeneratorESP()
    end

    -- Deteksi perubahan karakter (respawn) yang bisa mempengaruhi status
    local function onLocalPlayerCharacterAdded()
        task.wait(0.5) -- tunggu sebentar agar status stabil
        refreshNonGeneratorESP()
    end

    -- Pasang event listener
    local teamChangedConn
    if localPlayer.Team then
        teamChangedConn = localPlayer:GetPropertyChangedSignal("Team"):Connect(onLocalPlayerTeamChanged)
    else
        -- Jika belum ada team, tunggu sampai ada
        local teamWaitConn = localPlayer:GetPropertyChangedSignal("Team"):Connect(function()
            if localPlayer.Team then
                teamWaitConn:Disconnect()
                teamChangedConn = localPlayer:GetPropertyChangedSignal("Team"):Connect(onLocalPlayerTeamChanged)
                refreshNonGeneratorESP()
            end
        end)
        -- Simpan koneksi untuk cleanup nanti
        aboutContent.Destroying:Connect(function()
            if teamWaitConn then teamWaitConn:Disconnect() end
        end)
    end

    local charAddedConn = localPlayer.CharacterAdded:Connect(onLocalPlayerCharacterAdded)

    -- ========== CLEANUP ==========
    aboutContent.Destroying:Connect(function()
        if sliderDragConnection then sliderDragConnection:Disconnect() end
        if characterAddedConn then characterAddedConn:Disconnect() end
        if teamChangedConn then teamChangedConn:Disconnect() end
        if charAddedConn then charAddedConn:Disconnect() end
        stopTPWalk()
    end)

    -- Inisialisasi nilai slider dan toggle
    setSpeedFromPercent(speedPercent)
    updateToggleUI(tpwalkActive)

    -- Refresh ESP pertama kali
    if type(refreshCustomESP) == "function" then
        refreshCustomESP()
    end

    -- Pastikan aboutContent terlihat
    aboutContent.Visible = true
end


-- ============================================================================
-- settings content 
-- ============================================================================
local function createSettingsContent()

    if settingsContent then
        settingsContent:Destroy()
    end

    settingsContent = Instance.new("Frame")
    settingsContent.Size = UDim2.new(1,0,1,0)
    settingsContent.BackgroundTransparency = 1
    settingsContent.Parent = contentPanel

    --// MAIN SCROLL

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1,-8,1,-8)
    scroll.Position = UDim2.new(0,4,0,4)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 2
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = settingsContent

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0,10)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0,4)
    padding.PaddingBottom = UDim.new(0,10)
    padding.PaddingLeft = UDim.new(0,2)
    padding.PaddingRight = UDim.new(0,2)
    padding.Parent = scroll

    --// THEME CARD

    local themeCard = Instance.new("Frame")
    themeCard.Size = UDim2.new(1,-6,0,140)
    themeCard.BackgroundColor3 = Color3.fromRGB(10,20,36)
    themeCard.BorderSizePixel = 0
    themeCard.Parent = scroll

    Instance.new("UICorner",themeCard).CornerRadius = UDim.new(0,10)

    local themeStroke = Instance.new("UIStroke")
    themeStroke.Color = Color3.fromRGB(0,180,255)
    themeStroke.Transparency = 0.45
    themeStroke.Parent = themeCard

    local colorLabel = Instance.new("TextLabel")
    colorLabel.Size = UDim2.new(1,-20,0,22)
    colorLabel.Position = UDim2.new(0,10,0,10)
    colorLabel.Text = "THEME COLOR"
    colorLabel.TextColor3 = Color3.fromRGB(0,220,255)
    colorLabel.BackgroundTransparency = 1
    colorLabel.Font = Enum.Font.GothamBold
    colorLabel.TextSize = 12
    colorLabel.TextXAlignment = Enum.TextXAlignment.Left
    colorLabel.Parent = themeCard

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1,-20,0,24)
    desc.Position = UDim2.new(0,10,0,34)
    desc.BackgroundTransparency = 1
    desc.Text = "Customize the interface accent color."
    desc.TextColor3 = Color3.fromRGB(180,180,180)
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 12
    desc.TextWrapped = true
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Parent = themeCard

    --// COLOR HOLDER

    local colorHolder = Instance.new("Frame")
    colorHolder.Size = UDim2.new(1,-20,0,56)
    colorHolder.Position = UDim2.new(0,10,0,72)
    colorHolder.BackgroundTransparency = 1
    colorHolder.Parent = themeCard

    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0,42,0,24)
    grid.CellPadding = UDim2.new(0,8,0,8)
    grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
    grid.VerticalAlignment = Enum.VerticalAlignment.Top
    grid.Parent = colorHolder

    local function createColorButton(name,color,textColor)

        local btn = Instance.new("TextButton")
        btn.Text = name
        btn.BackgroundColor3 = color
        btn.TextColor3 = textColor or Color3.fromRGB(255,255,255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 9
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.Parent = colorHolder

        Instance.new("UICorner",btn).CornerRadius = UDim.new(0,6)

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(255,255,255)
        stroke.Transparency = 0.8
        stroke.Parent = btn

        btn.MouseButton1Click:Connect(function()
            config.guiThemeColor = color
            updateTheme()
        end)

        return btn
    end

    local colorRed = createColorButton(
        "RED",
        Color3.fromRGB(255,60,60)
    )

    local colorCyan = createColorButton(
        "CYAN",
        Color3.fromRGB(0,255,255),
        Color3.fromRGB(0,0,0)
    )

    local colorYellow = createColorButton(
        "YELLOW",
        Color3.fromRGB(255,220,40),
        Color3.fromRGB(0,0,0)
    )

    local colorBlue = createColorButton(
        "BLUE",
        Color3.fromRGB(0,120,255)
    )

    local colorGreen = createColorButton(
        "GREEN",
        Color3.fromRGB(0,255,120),
        Color3.fromRGB(0,0,0)
    )

    local colorPink = createColorButton(
        "PINK",
        Color3.fromRGB(255,80,180)
    )

    local colorPurple = createColorButton(
        "PURPLE",
        Color3.fromRGB(170,90,255)
    )

    local colorWhite = createColorButton(
        "WHITE",
        Color3.fromRGB(240,240,240),
        Color3.fromRGB(0,0,0)
    )

    --// REPORT CARD

    local reportCard = Instance.new("Frame")
    reportCard.Size = UDim2.new(1,-6,0,190)
    reportCard.BackgroundColor3 = Color3.fromRGB(8,18,32)
    reportCard.BorderSizePixel = 0
    reportCard.Parent = scroll

    Instance.new("UICorner",reportCard).CornerRadius = UDim.new(0,10)

    local reportStroke = Instance.new("UIStroke")
    reportStroke.Color = Color3.fromRGB(0,180,255)
    reportStroke.Transparency = 0.45
    reportStroke.Parent = reportCard

    local reportTitle = Instance.new("TextLabel")
    reportTitle.Size = UDim2.new(1,-20,0,22)
    reportTitle.Position = UDim2.new(0,10,0,10)
    reportTitle.BackgroundTransparency = 1
    reportTitle.Text = "📩 REPORT"
    reportTitle.TextColor3 = Color3.fromRGB(0,220,255)
    reportTitle.Font = Enum.Font.GothamBold
    reportTitle.TextSize = 12
    reportTitle.TextXAlignment = Enum.TextXAlignment.Left
    reportTitle.Parent = reportCard

    local reportDesc = Instance.new("TextLabel")
    reportDesc.Size = UDim2.new(1,-20,0,22)
    reportDesc.Position = UDim2.new(0,10,0,34)
    reportDesc.BackgroundTransparency = 1
    reportDesc.Text = "Send bug reports or interface feedback."
    reportDesc.TextColor3 = Color3.fromRGB(180,180,180)
    reportDesc.Font = Enum.Font.Gotham
    reportDesc.TextSize = 10
    reportDesc.TextWrapped = true
    reportDesc.TextXAlignment = Enum.TextXAlignment.Left
    reportDesc.Parent = reportCard

    --// CHAT LOG

    chatLog = Instance.new("ScrollingFrame")
    chatLog.Size = UDim2.new(1,-20,0,80)
    chatLog.Position = UDim2.new(0,10,0,62)
    chatLog.BackgroundColor3 = Color3.fromRGB(6,12,22)
    chatLog.BackgroundTransparency = 0.1
    chatLog.BorderSizePixel = 0
    chatLog.ScrollBarThickness = 2
    chatLog.AutomaticCanvasSize = Enum.AutomaticSize.Y
    chatLog.CanvasSize = UDim2.new(0,0,0,0)
    chatLog.Parent = reportCard

    Instance.new("UICorner",chatLog).CornerRadius = UDim.new(0,8)

    local chatStroke = Instance.new("UIStroke")
    chatStroke.Color = Color3.fromRGB(0,180,255)
    chatStroke.Transparency = 0.7
    chatStroke.Parent = chatLog

    local chatPadding = Instance.new("UIPadding")
    chatPadding.PaddingTop = UDim.new(0,4)
    chatPadding.PaddingBottom = UDim.new(0,4)
    chatPadding.PaddingLeft = UDim.new(0,6)
    chatPadding.PaddingRight = UDim.new(0,6)
    chatPadding.Parent = chatLog

    local chatListLayout = Instance.new("UIListLayout")
    chatListLayout.Padding = UDim.new(0,4)
    chatListLayout.Parent = chatLog

    --// INPUT

    chatInput = Instance.new("TextBox")
    chatInput.Size = UDim2.new(0.72,0,0,30)
    chatInput.Position = UDim2.new(0,10,0,150)
    chatInput.PlaceholderText = "Type report..."
    chatInput.Text = ""
    chatInput.BackgroundColor3 = Color3.fromRGB(12,20,34)
    chatInput.TextColor3 = Color3.fromRGB(255,255,255)
    chatInput.PlaceholderColor3 = Color3.fromRGB(140,140,140)
    chatInput.Font = Enum.Font.Gotham
    chatInput.TextSize = 5
    chatInput.BorderSizePixel = 0
    chatInput.ClearTextOnFocus = false
    chatInput.Parent = reportCard

    Instance.new("UICorner",chatInput).CornerRadius = UDim.new(0,8)

    local inputStroke = Instance.new("UIStroke")
    inputStroke.Color = Color3.fromRGB(0,180,255)
    inputStroke.Transparency = 0.7
    inputStroke.Parent = chatInput

    --// SEND BUTTON

    local sendBtn = Instance.new("TextButton")
    sendBtn.Size = UDim2.new(0.22,0,0,30)
    sendBtn.Position = UDim2.new(0.76,0,0,150)
    sendBtn.Text = "SEND"
    sendBtn.BackgroundColor3 = Color3.fromRGB(0,140,255)
    sendBtn.TextColor3 = Color3.fromRGB(255,255,255)
    sendBtn.Font = Enum.Font.GothamBold
    sendBtn.TextSize = 5
    sendBtn.BorderSizePixel = 0
    sendBtn.AutoButtonColor = false
    sendBtn.Parent = reportCard

    Instance.new("UICorner",sendBtn).CornerRadius = UDim.new(0,8)

    local sendStroke = Instance.new("UIStroke")
    sendStroke.Color = Color3.fromRGB(255,255,255)
    sendStroke.Transparency = 0.8
    sendStroke.Parent = sendBtn

    --// SEND MESSAGE

    sendBtn.MouseButton1Click:Connect(function()

        local msg = chatInput.Text

        if msg == "" then
            return
        end

        local messageHolder = Instance.new("Frame")
        messageHolder.Size = UDim2.new(1,0,0,22)
        messageHolder.BackgroundTransparency = 1
        messageHolder.Parent = chatLog

        local newMsg = Instance.new("TextLabel")
        newMsg.Size = UDim2.new(1,-4,1,0)
        newMsg.BackgroundTransparency = 1
        newMsg.Text = "[USER] "..msg
        newMsg.TextColor3 = Color3.fromRGB(220,220,220)
        newMsg.Font = Enum.Font.Gotham
        newMsg.TextSize = 5
        newMsg.TextWrapped = true
        newMsg.TextXAlignment = Enum.TextXAlignment.Left
        newMsg.TextYAlignment = Enum.TextYAlignment.Center
        newMsg.Parent = messageHolder

        chatInput.Text = ""

        chatLog.CanvasPosition = Vector2.new(
            0,
            chatListLayout.AbsoluteContentSize.Y + 50
        )

        task.wait(2)

        if messageHolder then
            messageHolder:Destroy()
        end
    end)
end
-- ============================================================================  
-- FLOATING BAR (MINI GUI) - VERSI DIPERBAIKI  
-- ============================================================================  
local function createFloatingBar()  
    -- Jika sudah ada dan masih hidup, cukup tampilkan  
    if floatingBar and floatingBar.Parent then  
        floatingBar.Visible = true  
        return floatingBar  
    end  
    if floatingBar then floatingBar:Destroy() end  
  
    -- Buat ScreenGui untuk floating bar  
    local barGui = Instance.new("ScreenGui")  
    barGui.Name = "CyberHeroes_FloatingBar"  
    barGui.ResetOnSpawn = false  
    barGui.IgnoreGuiInset = true  
    barGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling  
    barGui.Parent = CoreGui  
  
    local barFrame = Instance.new("Frame")  
    barFrame.Name = "FloatingBar"  
    barFrame.Size = UDim2.new(0, 150, 0, 40)  
    barFrame.Position = UDim2.new(0.5, -75, 0.05, 0)  
    barFrame.BackgroundColor3 = Color3.fromRGB(20, 5, 10)  
    barFrame.BackgroundTransparency = 0.2  
    barFrame.BorderSizePixel = 0  
    barFrame.Parent = barGui  
  
    -- Styling  
    local barCorner = Instance.new("UICorner")  
    barCorner.CornerRadius = UDim.new(0, 8)  
    barCorner.Parent = barFrame  
  
    local barStroke = Instance.new("UIStroke")  
    barStroke.Color = config.guiThemeColor  
    barStroke.Thickness = 1.5  
    barStroke.Transparency = 0.4  
    barStroke.Parent = barFrame  
  
    local iconLabel = Instance.new("TextLabel")  
    iconLabel.Size = UDim2.new(0, 35, 1, 0)  
    iconLabel.Position = UDim2.new(0, 5, 0, 0)  
    iconLabel.Text = "⚡"  
    iconLabel.TextColor3 = config.guiThemeColor  
    iconLabel.BackgroundTransparency = 1  
    iconLabel.Font = Enum.Font.GothamBold  
    iconLabel.TextSize = 20  
    iconLabel.Parent = barFrame  
  
    local textLabel = Instance.new("TextLabel")  
    textLabel.Size = UDim2.new(1, -45, 1, 0)  
    textLabel.Position = UDim2.new(0, 45, 0, 0)  
    textLabel.Text = "KEMILINUX"  
    textLabel.TextColor3 = config.guiThemeColor  
    textLabel.BackgroundTransparency = 1  
    textLabel.Font = Enum.Font.GothamBold  
    textLabel.TextSize = 12  
    textLabel.TextXAlignment = Enum.TextXAlignment.Left  
    textLabel.Parent = barFrame  
  
    -- === Mekanisme drag (manual, tidak menggunakan makeDraggable agar lebih akurat) ===  
    local dragging = false  
    local dragStartPos, dragStartOffset  
  
    barFrame.InputBegan:Connect(function(input)  
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then  
            dragging = true  
            dragStartPos = input.Position  
            dragStartOffset = barFrame.Position  
        end  
    end)  
  
    barFrame.InputChanged:Connect(function(input)  
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then  
            local delta = input.Position - dragStartPos  
            barFrame.Position = UDim2.new(  
                dragStartOffset.X.Scale,  
                dragStartOffset.X.Offset + delta.X,  
                dragStartOffset.Y.Scale,  
                dragStartOffset.Y.Offset + delta.Y  
            )  
        end  
    end)  
  
    barFrame.InputEnded:Connect(function(input)  
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then  
            dragging = false  
        end  
    end)  
  
    -- === Klik untuk restore (hanya jika tidak drag) ===  
    local isDrag = false  
    barFrame.InputBegan:Connect(function(input)  
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then  
            isDrag = false  
        end  
    end)  
    barFrame.InputChanged:Connect(function(input)  
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then  
            isDrag = true  
        end  
    end)  
    barFrame.InputEnded:Connect(function(input)  
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not isDrag then  
            if mainFrame then  
                mainFrame.Visible = true  
                config.guiVisible = true  
                barGui:Destroy()  
                floatingBar = nil  
                isFloatingVisible = false  
            end  
        end  
    end)  
  
    -- Efek hover  
    barFrame.MouseEnter:Connect(function()  
        TweenService:Create(barFrame, TweenInfo.new(0.15), {BackgroundTransparency = 0.05}):Play()  
        TweenService:Create(barStroke, TweenInfo.new(0.15), {Transparency = 0.1, Thickness = 2}):Play()  
    end)  
    barFrame.MouseLeave:Connect(function()  
        TweenService:Create(barFrame, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play()  
        TweenService:Create(barStroke, TweenInfo.new(0.15), {Transparency = 0.4, Thickness = 1.5}):Play()  
    end)  
  
    floatingBar = barGui  
    return floatingBar  
end  
  
-- ============================================================================  
-- GUI BUTTONS (sama, tidak diubah)    
-- ============================================================================  
local featuresContainer = nil  
local function createGridButton(parent, name, text, initialState, onChange)    
    -- ============================================================
    -- KHUSUS POV: Tampilan biru neon tanpa [ON]/[OFF]
    -- ============================================================
    if name == "povMode" then
        local button = Instance.new("TextButton")    
        button.Name = name    
        button.Size = UDim2.new(0,85,0,32)    
        
        -- Hanya teks "POV" tanpa status ON/OFF
        button.Text = text
        button.TextSize = 9   
        button.Font = Enum.Font.GothamBold    
        
        local isActive = config.povEnabled or false
        button.TextColor3 = isActive and Color3.fromRGB(0,220,255) or Color3.fromRGB(220,220,220)
        button.BackgroundColor3 = Color3.fromRGB(8,18,32)  -- selalu gelap
        button.BackgroundTransparency = 0.05    
        button.BorderSizePixel = 0    
        button.AutoButtonColor = false    
        button.Parent = parent    
        
        local corner = Instance.new("UICorner")    
        corner.CornerRadius = UDim.new(0,8)    
        corner.Parent = button    
        
        local stroke = Instance.new("UIStroke")    
        stroke.Thickness = 1.2    
        stroke.Transparency = 0.35    
        stroke.Color = isActive and Color3.fromRGB(0,200,255) or Color3.fromRGB(70,120,160)    
        stroke.Parent = button    
        
        local function updatePOVState()
            local active = config.povEnabled or false
            button.TextColor3 = active and Color3.fromRGB(0,220,255) or Color3.fromRGB(220,220,220)
            stroke.Color = active and Color3.fromRGB(0,200,255) or Color3.fromRGB(70,120,160)
        end
        
        button.MouseButton1Click:Connect(function()    
            togglePOV()
            updatePOVState()
            TweenService:Create(button, TweenInfo.new(0.06), {Size = UDim2.new(0,82,0,30)}):Play()    
            task.wait(0.06)    
            TweenService:Create(button, TweenInfo.new(0.06), {Size = UDim2.new(0,85,0,32)}):Play()    
        end)    
        
        updatePOVState()
        return button
    end
    
    -- ============================================================
    -- FITUR LAIN (sama seperti sebelumnya)
    -- ============================================================
    local button = Instance.new("TextButton")    
    button.Name = name    
    button.Size = UDim2.new(0,85,0,32)    
    
    button.Text = text .. (initialState and " [ON]" or " [OFF]")    
    button.TextSize = 9   
    button.Font = Enum.Font.GothamBold    
    
    button.TextColor3 =    
        initialState    
        and Color3.fromRGB(0,225,255)    
        or Color3.fromRGB(220,220,220)    
    
    button.BackgroundColor3 =    
        initialState    
        and Color3.fromRGB(12,28,46)    
        or Color3.fromRGB(8,18,32)    
    
    button.BackgroundTransparency = 0.05    
    button.BorderSizePixel = 0    
    button.AutoButtonColor = false    
    button.Parent = parent    
    
    local corner = Instance.new("UICorner")    
    corner.CornerRadius = UDim.new(0,8)    
    corner.Parent = button    
    
    local stroke = Instance.new("UIStroke")    
    stroke.Thickness = 1.2    
    stroke.Transparency = 0.35    
    
    stroke.Color =    
        initialState    
        and Color3.fromRGB(0,200,255)    
        or Color3.fromRGB(70,120,160)    
    
    stroke.Parent = button    
    
    local function updateState(state)    
        button.Text = text .. (state and " [ON]" or " [OFF]")    
        button.BackgroundColor3 =    
            state    
            and Color3.fromRGB(12,28,46)    
            or Color3.fromRGB(8,18,32)    
        button.TextColor3 =    
            state    
            and Color3.fromRGB(0,225,255)    
            or Color3.fromRGB(220,220,220)    
        stroke.Color =    
            state    
            and Color3.fromRGB(0,200,255)    
            or Color3.fromRGB(70,120,160)    
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
            if newState then startMassKillLoop() else stopMassKillLoop() end    
    
        elseif name == "autoGeneratorEnabled" then    
            config.autoGeneratorEnabled = newState    
            if newState then startAutoGeneratorLoop() else stopAutoGeneratorLoop() end    
    
        elseif name == "autoSkillCheckEnabled" then    
            config.autoSkillCheckEnabled = newState    
            if newState then startAutoSkillCheck() else stopAutoSkillCheck() end    
    
        elseif name == "autoAimEnabled" then    
            config.autoAimEnabled = newState    
            if newState then startAutoAim() else stopAutoAim() end    
        
        -- Bagian POV dihapus dari sini karena sudah ditangani khusus di atas    
        end    
    
        updateState(newState)    
    
        if onChange then    
            onChange(newState)    
        end    
    
        TweenService:Create(    
            button,    
            TweenInfo.new(0.06),    
            {Size = UDim2.new(0,82,0,30)}    
        ):Play()    
    
        task.wait(0.06)    
    
        TweenService:Create(    
            button,    
            TweenInfo.new(0.06),    
            {Size = UDim2.new(0,85,0,32)}    
        ):Play()    
    end)    
    
    return button    
end
  
  
local function createSidebarItem(parent, text, icon, active)  
  
    local button = Instance.new("TextButton")  
    button.Size = UDim2.new(1,0,0,30)  
  
    button.Text = "   " .. icon .. "   " .. text  
    button.TextSize = 10  
    button.Font = Enum.Font.GothamBold  
  
    button.TextXAlignment = Enum.TextXAlignment.Left  
  
    button.TextColor3 =  
        active  
        and Color3.fromRGB(0,225,255)  
        or Color3.fromRGB(210,210,210)  
  
    button.BackgroundColor3 =  
        active  
        and Color3.fromRGB(12,30,50)  
        or Color3.fromRGB(8,18,32)  
  
    button.BackgroundTransparency = 0.08  
    button.BorderSizePixel = 0  
    button.AutoButtonColor = false  
    button.Parent = parent  
  
    local corner = Instance.new("UICorner")  
    corner.CornerRadius = UDim.new(0,8)  
    corner.Parent = button  
  
    local stroke = Instance.new("UIStroke")  
    stroke.Thickness = 1.2  
  
    stroke.Color =  
        active  
        and Color3.fromRGB(0,200,255)  
        or Color3.fromRGB(60,100,140)  
  
    stroke.Transparency =  
        active  
        and 0.25  
        or 0.55  
  
    stroke.Parent = button  
  
    return button  
end  
-- ============================================================================    
-- PERMANENT TELEPORT BUTTON (tidak berubah)    
-- ============================================================================    
local function createPermanentTeleportButton()    
    if teleportButtonGui then teleportButtonGui:Destroy() end    
    teleportButtonGui = Instance.new("ScreenGui")    
    teleportButtonGui.Name = "CyberHeroes_TeleportButton"    
    teleportButtonGui.ResetOnSpawn = false    
    teleportButtonGui.Parent = CoreGui    
    teleportButton = Instance.new("TextButton")    
    teleportButton.Name = "TeleportButton"    
    teleportButton.Size = UDim2.new(0, 45, 0, 45)    
    teleportButton.Position = UDim2.new(0.02, 0, 0.85, -30)  -- naik 30 piksel    
    teleportButton.Text = "⚡\nTP"    
    teleportButton.TextWrapped = true    
    teleportButton.BackgroundColor3 = Color3.fromRGB(40, 5, 5)    
    teleportButton.BackgroundTransparency = 0.2    
    teleportButton.TextColor3 = Color3.fromRGB(0, 230, 255)    
    teleportButton.TextSize = 12    
    teleportButton.Font = Enum.Font.GothamBold    
    teleportButton.BorderSizePixel = 0    
    teleportButton.Parent = teleportButtonGui    
    local btnCorner = Instance.new("UICorner")    
    btnCorner.CornerRadius = UDim.new(1, 0)    
    btnCorner.Parent = teleportButton    
    local btnStroke = Instance.new("UIStroke")    
    btnStroke.Color = Color3.fromRGB(0, 200, 255)    
    btnStroke.Thickness = 1.5    
    btnStroke.Transparency = 0.4    
    btnStroke.Parent = teleportButton    
    teleportButton.MouseButton1Click:Connect(teleportToNearestSurvivor)    
    makeDraggable(teleportButton)    
end    
    
-- ============================================================================    
-- MAIN GUI (dengan minimize ke floating bar)    
-- ============================================================================    
local function createGUI()
    if screenGui then screenGui:Destroy() end
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_GUI"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = CoreGui
    screenGui.ResetOnSpawn = false

    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainWindow"
    mainFrame.Size = UDim2.new(0, 360, 0, 240)
    mainFrame.Position = UDim2.new(0.5, -180, 0.5, -120)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 5, 10)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 8)
    mainCorner.Parent = mainFrame

    -- Stroke utama
    mainStroke = Instance.new("UIStroke")
    mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    mainStroke.Color = config.guiThemeColor
    mainStroke.Thickness = 1.5
    mainStroke.Transparency = 0.15
    mainStroke.Parent = mainFrame

    -- Glow Layer 1
    local glow1 = Instance.new("UIStroke")
    glow1.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    glow1.Color = config.guiThemeColor
    glow1.Thickness = 3
    glow1.Transparency = 0.35
    glow1.Parent = mainFrame

    -- Glow Layer 2
    local glow2 = Instance.new("UIStroke")
    glow2.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    glow2.Color = config.guiThemeColor
    glow2.Thickness = 5
    glow2.Transparency = 0.55
    glow2.Parent = mainFrame

    -- Glow Layer 3
    local glow3 = Instance.new("UIStroke")
    glow3.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    glow3.Color = config.guiThemeColor
    glow3.Thickness = 7
    glow3.Transparency = 0.75
    glow3.Parent = mainFrame
 
    -- Glow Layer 4
    local glow4 = Instance.new("UIStroke")
    glow4.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    glow4.Color = config.guiThemeColor
    glow4.Thickness = 9
    glow4.Transparency = 0.9
    glow4.Parent = mainFrame

    local titleBar = Instance.new("Frame")  
    titleBar.Size = UDim2.new(1, 0, 0, 24)  
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 3, 7)  
    titleBar.BackgroundTransparency = 0.2  
    titleBar.BorderSizePixel = 0  
    titleBar.Parent = mainFrame  
    local titleCorner = Instance.new("UICorner")  
    titleCorner.CornerRadius = UDim.new(0, 8)  
    titleCorner.Parent = titleBar  
    
    local title = Instance.new("TextLabel")  
    title.Size = UDim2.new(0.5, 0, 1, 0)  
    title.Position = UDim2.new(0.02, 0, 0, 0)  
    title.Text = "Cyberheroes script by KEMI"  
    title.TextColor3 = config.guiThemeColor  
    title.BackgroundTransparency = 1  
    title.Font = Enum.Font.GothamBold  
    title.TextSize = 12  
    title.TextXAlignment = Enum.TextXAlignment.Left  
    title.Parent = titleBar  
    local versionLabel = Instance.new("TextLabel")  
    versionLabel.Size = UDim2.new(0.3, 0, 1, 0)  
    versionLabel.Position = UDim2.new(0.55, 0, 0, 0)  
    versionLabel.Text = "Build 10.1"  
    versionLabel.TextColor3 = Color3.fromRGB(150, 150, 200)  
    versionLabel.BackgroundTransparency = 1  
    versionLabel.Font = Enum.Font.Gotham  
    versionLabel.TextSize = 12  
    versionLabel.TextXAlignment = Enum.TextXAlignment.Left  
    versionLabel.Parent = titleBar  
  
    local minimizeBtn = Instance.new("TextButton")  
    minimizeBtn.Size = UDim2.new(0, 22, 0, 22)  
    minimizeBtn.Position = UDim2.new(1, -50, 0, 1)  
    minimizeBtn.Text = "−"  
    minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)  
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)  
    minimizeBtn.BackgroundTransparency = 0.2  
    minimizeBtn.BorderSizePixel = 0  
    minimizeBtn.Font = Enum.Font.GothamBold  
    minimizeBtn.TextSize = 10  
    minimizeBtn.Parent = titleBar  
    local minCorner = Instance.new("UICorner")  
    minCorner.CornerRadius = UDim.new(0, 3)  
    minCorner.Parent = minimizeBtn  
  
    local closeBtn = Instance.new("TextButton")  
    closeBtn.Size = UDim2.new(0, 22, 0, 22)  
    closeBtn.Position = UDim2.new(1, -26, 0, 1)  
    closeBtn.Text = "✕"  
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)  
    closeBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)  
    closeBtn.BackgroundTransparency = 0.2  
    closeBtn.BorderSizePixel = 0  
    closeBtn.Font = Enum.Font.GothamBold  
    closeBtn.TextSize = 10  
    closeBtn.Parent = titleBar  
    local closeCorner = Instance.new("UICorner")  
    closeCorner.CornerRadius = UDim.new(0, 3)  
    closeCorner.Parent = closeBtn  
  
    -- Fungsi minimize: sembunyikan mainFrame, tampilkan floating bar  
    local function minimizeGUI()  
        config.guiVisible = false  
        if mainFrame then mainFrame.Visible = false end  
        if floatingBar then  
            pcall(function() floatingBar:Destroy() end)  
            floatingBar = nil  
        end  
        createFloatingBar()  
        isFloatingVisible = true  
    end  
  
    -- Popup konfirmasi close (hanya satu instance)  
    local closePopup = nil  
    local function showCloseConfirmation()  
        if closePopup then return end -- sudah ada popup, tidak buat baru  
  
        closePopup = Instance.new("ScreenGui")  
        closePopup.Name = "CloseConfirmation"  
        closePopup.ResetOnSpawn = false  
        closePopup.ZIndexBehavior = Enum.ZIndexBehavior.Sibling  
        closePopup.Parent = CoreGui  
  
        local popupFrame = Instance.new("Frame")  
        popupFrame.Size = UDim2.new(0, 280, 0, 120)  
        popupFrame.Position = UDim2.new(0.5, -140, 0.5, -60)  
        popupFrame.BackgroundColor3 = Color3.fromRGB(20, 5, 10)  
        popupFrame.BackgroundTransparency = 0.1  
        popupFrame.BorderSizePixel = 0  
        popupFrame.Parent = closePopup  
        local popupCorner = Instance.new("UICorner")  
        popupCorner.CornerRadius = UDim.new(0, 8)  
        popupCorner.Parent = popupFrame  
        local popupStroke = Instance.new("UIStroke")  
        popupStroke.Color = config.guiThemeColor  
        popupStroke.Thickness = 1.5  
        popupStroke.Transparency = 0.4  
        popupStroke.Parent = popupFrame  
  
        local popupTitle = Instance.new("TextLabel")  
        popupTitle.Size = UDim2.new(1, 0, 0, 28)  
        popupTitle.Position = UDim2.new(0, 0, 0, 0)  
        popupTitle.BackgroundTransparency = 1  
        popupTitle.Text = "Konfirmasi"  
        popupTitle.TextColor3 = config.guiThemeColor  
        popupTitle.Font = Enum.Font.GothamBold  
        popupTitle.TextSize = 14  
        popupTitle.TextXAlignment = Enum.TextXAlignment.Center  
        popupTitle.Parent = popupFrame  
  
        local popupMsg = Instance.new("TextLabel")  
        popupMsg.Size = UDim2.new(1, -20, 0, 30)  
        popupMsg.Position = UDim2.new(0, 10, 0, 32)  
        popupMsg.BackgroundTransparency = 1  
        popupMsg.Text = "Apakah Anda yakin ingin menutup window ini?"  
        popupMsg.TextColor3 = Color3.fromRGB(220, 220, 220)  
        popupMsg.Font = Enum.Font.Gotham  
        popupMsg.TextSize = 12  
        popupMsg.TextWrapped = true  
        popupMsg.TextXAlignment = Enum.TextXAlignment.Center  
        popupMsg.Parent = popupFrame  
  
        local btnYes = Instance.new("TextButton")  
        btnYes.Size = UDim2.new(0, 80, 0, 28)  
        btnYes.Position = UDim2.new(0.25, -45, 1, -40)  
        btnYes.BackgroundColor3 = Color3.fromRGB(180, 50, 50)  
        btnYes.Text = "YES"  
        btnYes.TextColor3 = Color3.fromRGB(255, 255, 255)  
        btnYes.Font = Enum.Font.GothamBold  
        btnYes.TextSize = 12  
        btnYes.BorderSizePixel = 0  
        btnYes.Parent = popupFrame  
        local yesCorner = Instance.new("UICorner")  
        yesCorner.CornerRadius = UDim.new(0, 4)  
        yesCorner.Parent = btnYes  
  
        local btnNo = Instance.new("TextButton")  
        btnNo.Size = UDim2.new(0, 80, 0, 28)  
        btnNo.Position = UDim2.new(0.75, -40, 1, -40)  
        btnNo.BackgroundColor3 = Color3.fromRGB(60, 60, 60)  
        btnNo.Text = "NO"  
        btnNo.TextColor3 = Color3.fromRGB(255, 255, 255)  
        btnNo.Font = Enum.Font.GothamBold  
        btnNo.TextSize = 12  
        btnNo.BorderSizePixel = 0  
        btnNo.Parent = popupFrame  
        local noCorner = Instance.new("UICorner")  
        noCorner.CornerRadius = UDim.new(0, 4)  
        noCorner.Parent = btnNo  
  
        btnYes.MouseButton1Click:Connect(function()  
            if screenGui then  
                screenGui:Destroy()  
                screenGui = nil  
            end  
            if closePopup then  
                closePopup:Destroy()  
                closePopup = nil  
            end  
        end)  
  
        btnNo.MouseButton1Click:Connect(function()  
            if closePopup then  
                closePopup:Destroy()  
                closePopup = nil  
            end  
        end)  
  
        -- Jika klik di luar popup, tutup popup (opsional)  
        popupFrame.InputBegan:Connect(function(input)  
            if input.UserInputType == Enum.UserInputType.MouseButton1 then  
                -- Biarkan popup tetap terbuka jika klik di dalam frame  
            end  
        end)  
        -- Tapi agar tidak menutup saat klik di luar, kita tidak perlu menambahkan handler untuk background.  
        -- Kita bisa menutup popup jika klik di luar dengan menambahkan frame transparan di belakang? Tidak diperlukan.  
    end  
  
    minimizeBtn.MouseButton1Click:Connect(minimizeGUI)  
    closeBtn.MouseButton1Click:Connect(showCloseConfirmation)  -- ganti dengan popup  
  
    sidebar = Instance.new("Frame")  
    sidebar.Size = UDim2.new(0, 80, 1, -24)  
    sidebar.Position = UDim2.new(0, 0, 0, 24)  
    sidebar.BackgroundColor3 = Color3.fromRGB(15, 0, 2)  
    sidebar.BackgroundTransparency = 0.2  
    sidebar.BorderSizePixel = 0  
    sidebar.Parent = mainFrame  
    local sidebarCorner = Instance.new("UICorner")  
    sidebarCorner.CornerRadius = UDim.new(0, 0)  
    sidebarCorner.Parent = sidebar  
    local sidebarList = Instance.new("Frame")  
    sidebarList.Size = UDim2.new(1, 0, 0, 150)  
    sidebarList.Position = UDim2.new(0, 0, 0.05, 0)  
    sidebarList.BackgroundTransparency = 1  
    sidebarList.Parent = sidebar  
    local sidebarLayout = Instance.new("UIListLayout")  
    sidebarLayout.Padding = UDim.new(0, 4)  
    sidebarLayout.FillDirection = Enum.FillDirection.Vertical  
    sidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center  
    sidebarLayout.Parent = sidebarList  
  
    local homeItem = createSidebarItem(sidebarList, "HOME", "", false)  
    local featuresItem = createSidebarItem(sidebarList, "FEATURES", "", false) 
    featuresItem.TextColor3 = Color3.fromRGB(0,230,255)
    local settingsItem = createSidebarItem(sidebarList, "SETTINGS", "", false)  
    local infoItem = createSidebarItem(sidebarList, "INFO", "", false)  
    local aboutItem = createSidebarItem(sidebarList, "ABOUT", "", false)  
    local sep = Instance.new("Frame")  
    sep.Size = UDim2.new(0.8, 0, 0, 1)  
    sep.BackgroundColor3 = Color3.fromRGB(0, 200, 255)  
    sep.BackgroundTransparency = 0.7  
    sep.Parent = sidebarList  
  
    -- ============================================================
    -- CONTENT PANEL & FEATURES CONTAINER (diperbaiki)
    -- ============================================================
    contentPanel = Instance.new("Frame")
    contentPanel.Size = UDim2.new(1, -90, 1, -30)
    contentPanel.Position = UDim2.new(0, 85, 0, 28)
    contentPanel.BackgroundTransparency = 1
    contentPanel.Parent = mainFrame

    local featuresContainer = nil  -- wadah untuk tombol fitur

    -- Fungsi untuk membuat ulang tombol fitur (dipanggil saat buka FEATURES)
    local function buildFeatures()
        if featuresContainer then
            featuresContainer:Destroy()
            featuresContainer = nil
        end

        featuresContainer = Instance.new("Frame")
        featuresContainer.Size = UDim2.new(1, 0, 1, 0)
        featuresContainer.BackgroundTransparency = 1
        featuresContainer.Parent = contentPanel

        local gridLayout = Instance.new("UIGridLayout")
        gridLayout.CellSize = UDim2.new(0, 80, 0, 32)
        gridLayout.CellPadding = UDim2.new(0, 4, 0, 4)
        gridLayout.FillDirection = Enum.FillDirection.Horizontal
        gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
        gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
        gridLayout.Parent = featuresContainer

        local features = {
            {name="autoWinEnabled", text="AUTO WIN"},
            {name="autoTaskEnabled", text="AUTO TASK"},
            {name="espEnabled", text="ESP All"},
            {name="speedBoostEnabled", text="Play AI"},
            {name="stealthEnabled", text="STEALTH"},
            {name="godModeEnabled", text="GOD MODE"},
            {name="infiniteAmmoEnabled", text="Dagger"},
            {name="shieldEnabled", text="auto Attack"},
            {name="tpwalkEnabled", text="TPWALK"},
            {name="noCollideEnabled", text="NO COLLIDE"},
            {name="massKillEnabled", text="MASS KILL"},
            {name="autoGeneratorEnabled", text="Break GEN"},
            {name="autoSkillCheckEnabled", text="SKILL CHECK"},
            {name="autoAimEnabled", text="AUTO AIM"},
            {name="povMode", text="POV"}
        }
        for _, feat in ipairs(features) do
            local initialState = (feat.name ~= "restartScript") and config[feat.name] or false
            createGridButton(featuresContainer, feat.name, feat.text, initialState)
        end
    end

    -- Buat fitur pertama kali
    buildFeatures()

    -- ============================================================
    -- NAVIGATION HANDLERS (disesuaikan)
    -- ============================================================

    homeItem.MouseButton1Click:Connect(function()
        homeItem.TextColor3 = Color3.fromRGB(0,230,255)
        featuresItem.TextColor3 = Color3.fromRGB(200,200,200)
        settingsItem.TextColor3 = Color3.fromRGB(200,200,200)
        infoItem.TextColor3 = Color3.fromRGB(200,200,200)
        aboutItem.TextColor3 = Color3.fromRGB(200,200,200)

        -- Hancurkan featuresContainer jika ada
        if featuresContainer then
            featuresContainer:Destroy()
            featuresContainer = nil
        end
        if settingsContent then settingsContent:Destroy() end
        if infoContent then infoContent:Destroy() end
        if aboutContent then aboutContent.Visible = false end

        createHomeContent()
    end)

    featuresItem.MouseButton1Click:Connect(function()
        featuresItem.TextColor3 = Color3.fromRGB(0,230,255)
        homeItem.TextColor3 = Color3.fromRGB(200,200,200)
        settingsItem.TextColor3 = Color3.fromRGB(200,200,200)
        infoItem.TextColor3 = Color3.fromRGB(200,200,200)
        aboutItem.TextColor3 = Color3.fromRGB(200,200,200)

        if homeContent then homeContent:Destroy() end
        if settingsContent then settingsContent:Destroy() end
        if infoContent then infoContent:Destroy() end
        if aboutContent then aboutContent.Visible = false end

        -- Buat ulang featuresContainer jika belum ada
        if not featuresContainer then
            buildFeatures()
        end
    end)

    settingsItem.MouseButton1Click:Connect(function()
        settingsItem.TextColor3 = Color3.fromRGB(0,230,255)
        homeItem.TextColor3 = Color3.fromRGB(200,200,200)
        featuresItem.TextColor3 = Color3.fromRGB(200,200,200)
        infoItem.TextColor3 = Color3.fromRGB(200,200,200)
        aboutItem.TextColor3 = Color3.fromRGB(200,200,200)

        if featuresContainer then
            featuresContainer:Destroy()
            featuresContainer = nil
        end
        if homeContent then homeContent:Destroy() end
        if infoContent then infoContent:Destroy() end
        if aboutContent then aboutContent.Visible = false end

        createSettingsContent()
    end)

    infoItem.MouseButton1Click:Connect(function()
        infoItem.TextColor3 = Color3.fromRGB(0,230,255)
        homeItem.TextColor3 = Color3.fromRGB(200,200,200)
        featuresItem.TextColor3 = Color3.fromRGB(200,200,200)
        settingsItem.TextColor3 = Color3.fromRGB(200,200,200)
        aboutItem.TextColor3 = Color3.fromRGB(200,200,200)

        if featuresContainer then
            featuresContainer:Destroy()
            featuresContainer = nil
        end
        if homeContent then homeContent:Destroy() end
        if settingsContent then settingsContent:Destroy() end
        if aboutContent then aboutContent.Visible = false end

        createInfoContent()
    end)

    aboutItem.MouseButton1Click:Connect(function()
        aboutItem.TextColor3 = Color3.fromRGB(0,230,255)
        homeItem.TextColor3 = Color3.fromRGB(200,200,200)
        featuresItem.TextColor3 = Color3.fromRGB(200,200,200)
        settingsItem.TextColor3 = Color3.fromRGB(200,200,200)
        infoItem.TextColor3 = Color3.fromRGB(200,200,200)

        if featuresContainer then
            featuresContainer:Destroy()
            featuresContainer = nil
        end
        if homeContent then homeContent:Destroy() end
        if settingsContent then settingsContent:Destroy() end
        if infoContent then infoContent:Destroy() end
        
        createAboutContent()
    end)

    makeDraggable(mainFrame)
  
    local statusBar = Instance.new("Frame")  
    statusBar.Size = UDim2.new(1, 0, 0, 18)  
    statusBar.Position = UDim2.new(0, 0, 1, -18)  
    statusBar.BackgroundColor3 = Color3.fromRGB(15, 0, 2)  
    statusBar.BackgroundTransparency = 0.2  
    statusBar.BorderSizePixel = 0  
    statusBar.Parent = mainFrame  
    local statusCorner = Instance.new("UICorner")  
    statusCorner.CornerRadius = UDim.new(0, 4)  
    statusCorner.Parent = statusBar  
    statusLabel = Instance.new("TextLabel")  
    statusLabel.Size = UDim2.new(1, -10, 1, 0)  
    statusLabel.Position = UDim2.new(0, 5, 0, 0)  
    statusLabel.Text = "SYSTEM READY"  
    statusLabel.TextColor3 = config.guiThemeColor  
    statusLabel.BackgroundTransparency = 1  
    statusLabel.Font = Enum.Font.GothamBold  
    statusLabel.TextSize = 10  
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left  
    statusLabel.Parent = statusBar  
    local led = Instance.new("Frame")  
    led.Size = UDim2.new(0, 5, 0, 5)  
    led.Position = UDim2.new(1, -10, 0.5, -2.5)  
    led.BackgroundColor3 = Color3.fromRGB(0, 255, 0)  
    led.BackgroundTransparency = 0.2  
    led.BorderSizePixel = 0  
    led.Parent = statusBar  
    local ledCorner = Instance.new("UICorner")  
    ledCorner.CornerRadius = UDim.new(1, 0)  
    ledCorner.Parent = led  
  
    task.spawn(function()  
        while screenGui and screenGui.Parent do  
            local activeCount = (config.autoWinEnabled and 1 or 0) + (config.autoTaskEnabled and 1 or 0) + (config.espEnabled and 1 or 0) +  
                                (config.speedBoostEnabled and 1 or 0) + (config.stealthEnabled and 1 or 0) + (config.godModeEnabled and 1 or 0) +  
                                (config.infiniteAmmoEnabled and 1 or 0) + (config.shieldEnabled and 1 or 0) + (config.tpwalkEnabled and 1 or 0) +  
                                (config.noCollideEnabled and 1 or 0) + (config.massKillEnabled and 1 or 0) + (config.autoGeneratorEnabled and 1 or 0) +  
                                (config.autoSkillCheckEnabled and 1 or 0) + (config.autoAimEnabled and 1 or 0)  
            if activeCount > 0 then  
                statusLabel.Text = "ACTIVE: " .. activeCount .. " modules"  
                statusLabel.TextColor3 = config.guiThemeColor  
                led.BackgroundColor3 = Color3.fromRGB(0, 255, 0)  
            else  
                statusLabel.Text = "STANDBY"  
                statusLabel.TextColor3 = Color3.fromRGB(150, 50, 50)  
                led.BackgroundColor3 = Color3.fromRGB(255, 0, 0)  
            end  
            task.wait(1)  
        end  
    end)  
  
    mainFrame.BackgroundTransparency = 0.3
    TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.1}):Play()
end
 
-- ============================================================================
-- RESTORE FEATURE STATES FUNCTION (LENGKAP)
-- ============================================================================
local function restoreFeatureStates()
    print("[State] Restoring feature states from persistent config...")
    
    if config.autoWinEnabled and not autoWinConnection then
        startAutoWin()
    elseif not config.autoWinEnabled and autoWinConnection then
        stopAutoWin()
    end
    
    if config.autoTaskEnabled and not currentTaskConnection then
        startAutoTask()
    elseif not config.autoTaskEnabled and currentTaskConnection then
        stopAutoTask()
    end
    
    if config.speedBoostEnabled and not currentBoostConnection then
        startSpeedBoostMonitor()
       elseif not config.speedBoostEnabled and currentBoostConnection then
        stopSpeedBoostMonitor()
    end
    if config.stealthEnabled and not stealthConnection then
        startStealthMonitor()
    elseif not config.stealthEnabled and stealthConnection then
        stopStealthMonitor()
    end
    
    if config.godModeEnabled and not godModeConnection then
        startGodMode()
    elseif not config.godModeEnabled and godModeConnection then
        stopGodMode()
    end
    
    if config.infiniteAmmoEnabled and not infiniteAmmoConnection then
        startInfiniteAmmo()
    elseif not config.infiniteAmmoEnabled and infiniteAmmoConnection then
        stopInfiniteAmmo()
    end
    
    if config.shieldEnabled and not shieldConnection then
        startShieldMonitor()
    elseif not config.shieldEnabled and shieldConnection then
        stopShieldMonitor()
    end
    
    if config.tpwalkEnabled and not tpwalkConnection then
        startTpwalkMonitor()
    elseif not config.tpwalkEnabled and tpwalkConnection then
        stopTpwalkMonitor()
    end
    
    if config.noCollideEnabled and not noCollideConnection then
        startNoCollideMonitor()
    elseif not config.noCollideEnabled and noCollideConnection then
        stopNoCollideMonitor()
    end
    
    if config.massKillEnabled and not massKillLoopConnection then
        startMassKillLoop()
    elseif not config.massKillEnabled and massKillLoopConnection then
        stopMassKillLoop()
    end
    
    if config.autoGeneratorEnabled and not autoGeneratorLoopConnection then
        startAutoGeneratorLoop()
    elseif not config.autoGeneratorEnabled and autoGeneratorLoopConnection then
        stopAutoGeneratorLoop()
    end
    
    if config.autoSkillCheckEnabled and not autoSkillCheckConnection then
        startAutoSkillCheck()
    elseif not config.autoSkillCheckEnabled and autoSkillCheckConnection then
        stopAutoSkillCheck()
    end
    
    if config.autoAimEnabled and not autoAimConnection then
        startAutoAim()
    elseif not config.autoAimEnabled and autoAimConnection then
        stopAutoAim()
    end
    
    if config.espEnabled and not espConnection then
        startESP()
    elseif not config.espEnabled and espConnection then
        stopESP()
    end
    
    if config.povEnabled then
         enablePOV()
     else
         disablePOV()
    end
    
    print("[State] Feature state restoration complete")
end

-- ============================================================================
-- AUTO RECOVERY SYSTEM (menjaga semua GUI komponen tetap ada)
-- ============================================================================
local function ensureGUIPersistent()
    task.spawn(function()
        while isScriptRunning do
            if not screenGui or not screenGui.Parent then
                print("[Recovery] Recreating main GUI...")
                createGUI()
            end
            if not config.guiVisible and (not floatingLogo or not floatingLogo.Parent) then
                    print("[Recovery] Recreating floating logo...")
                    createFloatingLogo()  -- fungsi ini sudah aman, tidak destroy jika sudah ada
                    floatingLogo.Visible = true
                    isLogoVisible = true
                end
                    -- 4. Di dalam fungsi init(), setelah createGUI(), tambahkan:
                if not floatingLogo then
                    createFloatingLogo()
                end
                    floatingLogo.Visible = false  
            if not teleportButtonGui or not teleportButtonGui.Parent then
                print("[Recovery] Recreating teleport button...")
                createPermanentTeleportButton()
            end
            task.wait(2)
        end
    end)
end

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
        originalTpwalkSpeed = localHumanoid.WalkSpeed
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
    if config.massKillEnabled then startMassKillLoop() end
    if config.autoGeneratorEnabled then startAutoGeneratorLoop() end
    if config.autoSkillCheckEnabled then startAutoSkillCheck() end
    if config.autoAimEnabled then startAutoAim() end
    if config.espEnabled then startESP() end
    if config.povEnabled then enablePOV() else disablePOV() end
end

local function init()
    print("╔═══════════════════════════════════════════════════════════════════╗")
    print("║                    CYBERHEROES DELTA EXECUTOR v10.1              ║")
    print("║        Auto Win (teleport to fininshline)                        ║")
    print("║        Auto Task (anti-hook + lever gate system)                 ║")
    print("║        Auto Generator (full ESP)                                ║")
    print("║        Tpwalk (2x speed + CFrame dash)                          ║")
    print("║        Auto Kill (hilt hitbox + multiple hit methods)           ║")
    print("║                   System initialized! (NO LAG!)                  ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")
    if localPlayer.Character then onCharacterAdded(localPlayer.Character) end
    localPlayer.CharacterAdded:Connect(onCharacterAdded)
    createGUI()
    ensureGUIPersistent()
    startAllSystems()
    restoreFeatureStates()
    createPermanentTeleportButton()
end

task.wait(1)
init()

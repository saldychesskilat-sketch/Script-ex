
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

-- Cache remote event lever
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
-- ESP SYSTEM (PLAYER + OBJECTS) - UPGRADED: SCP ENTITY + MORE TRANSPARENT
-- ============================================================================

-- Konfigurasi warna objek (sama seperti referensi)
local ObjectColors = {
    Generator = Color3.fromRGB(255, 165, 0), 
    Gate      = Color3.fromRGB(255, 255, 255),
    Pallet    = Color3.fromRGB(128, 128, 128),  
    Hook      = Color3.fromRGB(255, 165, 0),
    SCP       = Color3.fromRGB(150, 0, 255)      -- Warna ungu untuk SCP entity
}

-- Variabel ESP (global untuk script utama)
espHighlights = espHighlights or {}              -- player ESP
generatorEspHighlights = generatorEspHighlights or {}  -- object ESP
espConnection = nil
espDescendantAddedConn = nil
espDescendantRemovingConn = nil
espPlayerAddedConn = nil
espPlayerRemovingConn = nil
espProgressUpdateConn = nil
espPeriodicScanConn = nil
lastObjectScanTime = 0
OBJECT_SCAN_INTERVAL = 2

-- Helper untuk mendapatkan nilai dari objek (attribute atau child value)
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

-- ============================================================================
-- FUNGSI UNTUK MEMBUAT HIGHLIGHT (LEBIH TRANSPARAN, OUTLINE TETAP JELAS)
-- ============================================================================
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

-- Membuat BillboardGui untuk progress generator
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

-- Update progress generator (warna gradien + hilangkan jika sudah 100%)
local function updateGeneratorProgress(generator)
    if not generator or not generator.Parent then return true end
    local percent = getGameValue(generator, "RepairProgress") or getGameValue(generator, "Progress") or 0
    if percent >= 100 then
        local h = generator:FindFirstChild("CyberHeroes_Highlight")
        if h then h:Destroy() end
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

-- Update semua progress generator (dipanggil periodic)
local function updateAllGeneratorProgress()
    for obj, _ in pairs(generatorEspHighlights) do
        if obj and obj.Parent and (obj.Name == "Generator") then
            updateGeneratorProgress(obj)
        end
    end
end

-- ============================================================================
-- PLAYER ESP (dengan deteksi killer/survivor, jarak, status) - LEBIH TRANSPARAN
-- ============================================================================
local function createHighlightForPlayer(player)
    if espHighlights[player.UserId] then
        if espHighlights[player.UserId].Highlight then
            espHighlights[player.UserId].Highlight:Destroy()
        end
        if espHighlights[player.UserId].Billboard then
            espHighlights[player.UserId].Billboard:Destroy()
        end
        if espHighlights[player.UserId].TeamChanged then
            espHighlights[player.UserId].TeamChanged:Disconnect()
        end
        espHighlights[player.UserId] = nil
    end

    local character = player.Character
    if not character then return end

    local function getPlayerType()
        local isKiller = false
        if player.Team then
            local teamName = player.Team.Name:lower()
            if teamName:find("killer") or teamName:find("monster") or teamName:find("enemy") then
                isKiller = true
            end
        end
        if not isKiller then
            local tool = character:FindFirstChildWhichIsA("Tool")
            if tool and (tool.Name:lower():find("knife") or tool.Name:lower():find("weapon")) then
                isKiller = true
            end
        end
        return isKiller
    end

    local isKiller = getPlayerType()
    local highlightColor = isKiller and config.highlightColorKiller or config.highlightColorSurvivor

    local highlight = Instance.new("Highlight")
    highlight.Name = "CyberHeroes_ESP"
    highlight.FillColor = highlightColor
    highlight.OutlineColor = highlightColor
    highlight.FillTransparency = 1
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

    local teamChangedConn = nil
    if player.Team then
        teamChangedConn = player:GetPropertyChangedSignal("Team"):Connect(function()
            local newIsKiller = getPlayerType()
            local newColor = newIsKiller and config.highlightColorKiller or config.highlightColorSurvivor
            if highlight then
                highlight.FillColor = newColor
                highlight.OutlineColor = newColor
            end
            if nameLabel then
                nameLabel.TextColor3 = newColor
            end
        end)
    end

    espHighlights[player.UserId] = {
        Highlight = highlight,
        Billboard = billboard,
        NameLabel = nameLabel,
        TeamChanged = teamChangedConn
    }
end

local function updateAllESP()
    if not config.espEnabled then
        for _, data in pairs(espHighlights) do
            if data.Highlight then data.Highlight:Destroy() end
            if data.Billboard then data.Billboard:Destroy() end
            if data.TeamChanged then data.TeamChanged:Disconnect() end
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

-- ============================================================================
-- OBJECT ESP (Generator, Hook, Gate, Pallet, Window, SCP)
-- ============================================================================
local function createObjectESP(obj, objType)
    if generatorEspHighlights[obj] then return end
    local color
    if objType == "Generator" then
        color = ObjectColors.Generator
    elseif objType == "Hook" then
        color = ObjectColors.Hook
    elseif objType == "Gate" then
        color = ObjectColors.Gate
    elseif objType == "Pallet" then
        color = ObjectColors.Pallet
    elseif objType == "SCP" then
        color = ObjectColors.SCP               -- Warna ungu untuk SCP entity
    end
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

-- Refresh semua object ESP (pindai ulang seluruh workspace)
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
        elseif name:lower():find("scp") then          -- DETEKSI SCP ENTITY (scp1, scp2, ..., scp26)
            createObjectESP(obj, "SCP")
        elseif name == "Pallet" or name == "Palletwrong" then
            createObjectESP(obj, "Pallet")
        end
    end
    print("[ESP] Object ESP refreshed (including SCP entities)")
end

-- Event handlers untuk objek yang muncul/hilang
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
    end
end

local function onDescendantRemoving(instance)
    if generatorEspHighlights[instance] then
        removeObjectESP(instance)
    end
end

-- Periodic scan untuk menjamin objek yang muncul belakangan tetap terdeteksi
local function periodicObjectScan()
    if not config.espEnabled then return end
    local now = tick()
    if now - lastObjectScanTime >= OBJECT_SCAN_INTERVAL then
        lastObjectScanTime = now
        refreshAllObjectESP()
    end
end

-- ============================================================================
-- START ESP (mengaktifkan semua komponen)
-- ============================================================================
local function startESP()
    if espConnection then return end  -- sudah berjalan

    -- Bersihkan koneksi lama jika ada
    if espDescendantAddedConn then espDescendantAddedConn:Disconnect() end
    if espDescendantRemovingConn then espDescendantRemovingConn:Disconnect() end
    if espPlayerAddedConn then espPlayerAddedConn:Disconnect() end
    if espPlayerRemovingConn then espPlayerRemovingConn:Disconnect() end
    if espProgressUpdateConn then espProgressUpdateConn:Disconnect() end
    if espPeriodicScanConn then espPeriodicScanConn:Disconnect() end

    -- Player ESP events
    espPlayerAddedConn = Players.PlayerAdded:Connect(function(player)
        if config.espEnabled then
            task.wait(1)
            createHighlightForPlayer(player)
        end
    end)
    espPlayerRemovingConn = Players.PlayerRemoving:Connect(function(player)
        if espHighlights[player.UserId] then
            if espHighlights[player.UserId].Highlight then
                espHighlights[player.UserId].Highlight:Destroy()
            end
            if espHighlights[player.UserId].Billboard then
                espHighlights[player.UserId].Billboard:Destroy()
            end
            if espHighlights[player.UserId].TeamChanged then
                espHighlights[player.UserId].TeamChanged:Disconnect()
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

    -- Object ESP events
    espDescendantAddedConn = workspace.DescendantAdded:Connect(onDescendantAdded)
    espDescendantRemovingConn = workspace.DescendantRemoving:Connect(onDescendantRemoving)

    -- Scan awal
    refreshAllObjectESP()

    -- Periodic scan untuk memastikan semua objek terdeteksi
    espPeriodicScanConn = RunService.Heartbeat:Connect(periodicObjectScan)

    -- Periodic update progress generator (real-time)
    espProgressUpdateConn = RunService.Heartbeat:Connect(function()
        if config.espEnabled then
            updateAllGeneratorProgress()
        end
    end)

    -- Loop untuk menjaga player ESP tetap up-to-date
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
            -- Jika ESP dimatikan, bersihkan semua
            for _, data in pairs(espHighlights) do
                if data.Highlight then data.Highlight:Destroy() end
                if data.Billboard then data.Billboard:Destroy() end
                if data.TeamChanged then data.TeamChanged:Disconnect() end
            end
            espHighlights = {}
            clearObjectESP()
        end
    end)

    print("[ESP] ESP started (player + object ESP with real-time progress, including SCP entities)")
end

-- ============================================================================
-- STOP ESP (membersihkan semua)
-- ============================================================================
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

    -- Bersihkan semua highlight dan billboard
    for _, data in pairs(espHighlights) do
        if data.Highlight then data.Highlight:Destroy() end
        if data.Billboard then data.Billboard:Destroy() end
        if data.TeamChanged then data.TeamChanged:Disconnect() end
    end
    espHighlights = {}
    clearObjectESP()

    print("[ESP] ESP stopped")
end

-- ============================================================================
-- UPDATE ALL ESP (dipanggil saat config.espEnabled berubah melalui GUI)
-- ============================================================================
local function updateAllESP()
    if config.espEnabled then
        startESP()
    else
        stopESP()
    end
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
-- Menggabungkan health regeneration dengan stealth (seat method) yang hanya aktif
-- saat killer dalam jarak ≤ config.stealthTriggerDistance (default 20 studs)
-- Stealth nonaktif saat jarak > config.stealthTriggerDistance
-- Menggunakan salinan fungsi stealth dengan variabel internal sendiri (tidak konflik dengan fitur Stealth asli)
-- ============================================================================

-- Variabel untuk koneksi god mode (health regen + stealth trigger)
local godModeConnection = nil
local stealthDistanceConnection = nil
local god_isStealthCurrentlyActive = false   -- flag internal

-- Konfigurasi jarak trigger stealth (dapat diubah via config)
if config.stealthTriggerDistance == nil then
    config.stealthTriggerDistance = 20   -- jarak dalam studs
end

-- ============================================================================
-- FEATURE 6: GOD MODE (HEALTH REGEN + STEALTH WITH DISTANCE TRIGGER)
-- Stealth aktif saat killer dalam jarak ≤ config.stealthTriggerDistance
-- Stealth nonaktif saat jarak > config.stealthTriggerDistance
-- Menggunakan salinan fungsi stealth internal (tidak konflik dengan fitur Stealth asli)
-- ============================================================================

-- Variabel untuk koneksi god mode (health regen + stealth trigger)
local godModeConnection = nil
local stealthDistanceConnection = nil

-- Konfigurasi jarak trigger stealth (dapat diubah via config)
if config.stealthTriggerDistance == nil then
    config.stealthTriggerDistance = 20   -- jarak dalam studs
end

-- ============================================================================
-- FUNGSI STEALTH INTERNAL GOD MODE (SALINAN DENGAN NAMA VARIABEL UNIK)
-- ============================================================================
local god_currentSeat = nil
local god_seatWeld = nil
local god_isSeatActive = false
local god_seatTeleportPosition = Vector3.new(-25.95, 400, 3537.55)
local god_voidLevelYThreshold = -50
local god_seatReturnHeartbeatConnection = nil
local god_isInvisible = false

local function god_startSeatReturnHeartbeat()
    if god_seatReturnHeartbeatConnection then
        god_seatReturnHeartbeatConnection:Disconnect()
        god_seatReturnHeartbeatConnection = nil
    end
    god_seatReturnHeartbeatConnection = RunService.Heartbeat:Connect(function()
        -- kosong, bisa diisi jika diperlukan
    end)
end

local function god_stopSeatReturnHeartbeat()
    if god_seatReturnHeartbeatConnection then
        god_seatReturnHeartbeatConnection:Disconnect()
        god_seatReturnHeartbeatConnection = nil
    end
end

local function god_setCharacterTransparency(transparency)
    if not localCharacter then return end
    for _, part in ipairs(localCharacter:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.Transparency = transparency
        end
    end
end

local function god_makeInvisible()
    if not config.godModeEnabled then return end
    if god_isInvisible then return end
    if not localCharacter then return end

    local humanoidRootPart = localCharacter:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        print("[GodMode] Cannot make invisible: No HumanoidRootPart")
        return
    end
    local originalCFrame = humanoidRootPart.CFrame
    local upPosition = originalCFrame.Position + Vector3.new(0, -90, 0)
    pcall(function() humanoidRootPart.CFrame = CFrame.new(upPosition) end)
    task.wait(0.05)

    if god_currentSeat then
        pcall(function() god_currentSeat:Destroy() end)
        god_currentSeat = nil
        god_seatWeld = nil
    end
    god_stopSeatReturnHeartbeat()
    god_isSeatActive = false

    local savedpos = humanoidRootPart.CFrame
    pcall(function() localCharacter:MoveTo(god_seatTeleportPosition) end)
    task.wait(0.05)

    if not localCharacter:FindFirstChild("HumanoidRootPart") or 
       localCharacter.HumanoidRootPart.Position.Y < god_voidLevelYThreshold then
        pcall(function() localCharacter:MoveTo(savedpos) end)
        print("[GodMode] Teleport to seat failed (void). Aborting.")
        pcall(function() humanoidRootPart.CFrame = originalCFrame end)
        return
    end

    local Seat = Instance.new('Seat')
    Seat.Name = 'CyberHeroes_GodSeat'
    Seat.Anchored = false
    Seat.CanCollide = false
    Seat.Transparency = 1
    Seat.Position = god_seatTeleportPosition
    Seat.Parent = workspace

    local torso = localCharacter:FindFirstChild("Torso") or localCharacter:FindFirstChild("UpperTorso")
    if torso then
        god_seatWeld = Instance.new("Weld")
        god_seatWeld.Part0 = Seat
        god_seatWeld.Part1 = torso
        god_seatWeld.Parent = Seat
        task.wait()
        pcall(function() Seat.CFrame = savedpos end)
        god_currentSeat = Seat
        god_startSeatReturnHeartbeat()
        god_isSeatActive = true
    else
        Seat:Destroy()
        print("[GodMode] Cannot make invisible: No torso found")
        pcall(function() humanoidRootPart.CFrame = originalCFrame end)
        return
    end

    god_setCharacterTransparency(0.75)
    god_isInvisible = true
    pcall(function() humanoidRootPart.CFrame = originalCFrame end)
    print("[GodMode] Stealth activated (distance ≤ " .. config.stealthTriggerDistance .. " studs)")
end

local function god_makeVisible()
    if not god_isInvisible then return end
    if not localCharacter then return end

    if god_currentSeat then
        pcall(function() god_currentSeat:Destroy() end)
        god_currentSeat = nil
        god_seatWeld = nil
    end
    god_stopSeatReturnHeartbeat()
    god_isSeatActive = false

    god_setCharacterTransparency(0)
    god_isInvisible = false
    print("[GodMode] Stealth deactivated (distance > " .. config.stealthTriggerDistance .. " studs)")
end

-- ============================================================================
-- FUNGSI UNTUK MENGECEK JARAK KILLER DAN MENGGUNAKAN STEALTH
-- ============================================================================
local function god_checkKillerDistanceAndToggleStealth()
    if not config.godModeEnabled then return end
    if not getLocalCharacter() or not localRootPart then return end

    local localPos = localRootPart.Position
    local nearestKillerDistance = math.huge

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
                        if dist < nearestKillerDistance then
                            nearestKillerDistance = dist
                        end
                    end
                end
            end
        end
    end

    -- Stealth aktif jika jarak killer ≤ threshold, nonaktif jika > threshold
    if nearestKillerDistance <= config.stealthTriggerDistance then
        if not god_isInvisible then
            god_makeInvisible()
        end
    else
        if god_isInvisible then
            god_makeVisible()   -- <- otomatis mati saat jarak > threshold
        end
    end
end

-- ============================================================================
-- START / STOP GOD MODE
-- ============================================================================
local function startGodMode()
    if godModeConnection then return end

    -- Health regen
    godModeConnection = RunService.Heartbeat:Connect(function()
        if not config.godModeEnabled then return end
        if not getLocalCharacter() or not localHumanoid then return end
        local maxHealth = localHumanoid.MaxHealth
        if localHumanoid.Health < maxHealth then
            localHumanoid.Health = maxHealth
        end
    end)

    -- Stealth trigger berdasarkan jarak killer
    if stealthDistanceConnection then stealthDistanceConnection:Disconnect() end
    stealthDistanceConnection = RunService.Heartbeat:Connect(god_checkKillerDistanceAndToggleStealth)

    print("[GodMode] Activated: Health regen + Stealth (auto on/off when killer ≤ " .. config.stealthTriggerDistance .. " studs)")
end

local function stopGodMode()
    if godModeConnection then
        godModeConnection:Disconnect()
        godModeConnection = nil
    end
    if stealthDistanceConnection then
        stealthDistanceConnection:Disconnect()
        stealthDistanceConnection = nil
    end
    if god_isInvisible then
        god_makeVisible()   -- pastikan stealth dimatikan saat god mode berhenti
    end
    print("[GodMode] Deactivated: Health regen and stealth stopped")
end

-- ============================================================================

-- FEATURE 7: AUTO PARRY / AUTO BLOCK (FIXED - USING CORRECT REMOTE EVENT)        
-- Berdasarkan hasil scanning: ReplicatedStorage.Remotes.Items.Parrying Dagger.parry        
-- ============================================================================        
        
-- Cache remote event parry        
local cachedParryRemote = nil        
        
-- Cari remote event "parry" di path yang benar        
local function findParryRemoteEvent()        
    if cachedParryRemote and cachedParryRemote.Parent then        
        return cachedParryRemote        
    end        
            
    -- Coba akses langsung melalui path yang diketahui        
    local parryRemote = ReplicatedStorage:FindFirstChild("Remotes")        
    if parryRemote then        
        parryRemote = parryRemote:FindFirstChild("Items")        
        if parryRemote then        
            parryRemote = parryRemote:FindFirstChild("Parrying Dagger")        
            if parryRemote then        
                parryRemote = parryRemote:FindFirstChild("parry")        
                if parryRemote and parryRemote:IsA("RemoteEvent") then        
                    cachedParryRemote = parryRemote        
                    print("[AutoParry] Found parry remote event at correct path")        
                    return parryRemote        
                end        
            end        
        end        
    end
            
    -- Fallback: scan semua RemoteEvent di ReplicatedStorage        
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do        
        if obj:IsA("RemoteEvent") and obj.Name == "parry" then        
            cachedParryRemote = obj        
            print("[AutoParry] Found parry remote event via scan:", obj.Name)        
            return obj        
        end        
    end        
            
    return nil        
end        
        
-- Cari item Parrying Dagger di inventory player (Backpack atau Character)        
local function getParryingDaggerTool()        
    local backpack = localPlayer:FindFirstChild("Backpack")        
    local character = localPlayer.Character        
    if backpack then        
        for _, tool in ipairs(backpack:GetChildren()) do        
            if tool:IsA("Tool") and (tool.Name == "Parrying Dagger" or tool.Name == "Blade") then        
                return tool        
            end        
        end        
    end        
    if character then        
        for _, tool in ipairs(character:GetChildren()) do        
            if tool:IsA("Tool") and (tool.Name == "Parrying Dagger" or tool.Name == "Blade") then        
                return tool        
            end        
        end        
    end        
    return nil        
end        
        
-- Kirim remote event parry dengan argumen yang benar        
local function fireParryRemote(targetPlayer)        
    local remote = findParryRemoteEvent()        
    if not remote then        
        print("[AutoParry] Parry remote not found!")        
        return false        
    end        
            
    local dagger = getParryingDaggerTool()        
            
    -- Variasi argumen yang mungkin diterima (urutan prioritas)        
    local argsVariants = {        
        {dagger},                     -- objek tool (jika ada)        
        {"Parrying Dagger"},          -- string nama item        
        {"parry"},        
        {"parryResult"},        
        {dagger, targetPlayer},       -- tool + target        
        {"Parrying Dagger", targetPlayer},        
        {}                            -- tanpa argumen        
    }        
            
    -- Jika tidak punya dagger, hapus varian yang menggunakan objek tool        
    if not dagger then        
        for i = #argsVariants, 1, -1 do        
            local args = argsVariants[i]        
            if #args > 0 and type(args[1]) == "userdata" then        
                table.remove(argsVariants, i)        
            end        
        end        
    end        
            
    local success = false        
    for _, args in ipairs(argsVariants) do        
        pcall(function()        
            if #args == 0 then        
                remote:FireServer()        
            elseif #args == 1 then        
                remote:FireServer(args[1])        
            elseif #args == 2 then        
                remote:FireServer(args[1], args[2])        
            end        
        end)        
        success = true        
    end        
            
    return success        
end        
        
-- Fallback: fire multiple times untuk bypass cooldown        
local function fallbackParry()        
    local remote = findParryRemoteEvent()        
    if not remote then return false end        
            
    for i = 1, 3 do        
        pcall(function()        
            remote:FireServer()        
            remote:FireServer("Parrying Dagger")        
            remote:FireServer("parry")        
        end)        
        task.wait(0.01)        
    end        
    return true        
end        
        
-- ============================================================================        
-- AUTO PARRY MAIN LOOP        
-- ============================================================================        
local lastParryTime = 0        
local PARRY_COOLDOWN = 0.15        
        
local function getKillerDistance()        
    if not localRootPart then return math.huge end        
    local localPos = localRootPart.Position        
    local minDist = math.huge        
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
                if isKiller then        
                    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")        
                    if root then        
                        local dist = (localPos - root.Position).Magnitude        
                        if dist < minDist then        
                            minDist = dist        
                        end        
                    end        
                end        
            end        
        end        
    end        
    return minDist        
end        
local combatHeartbeat = nil
local combatStateConnected = false
local radiusFolder = nil

local function autoParryLoop()

    if combatStateConnected then
        return
    end

    combatStateConnected = true

    ----------------------------------------------------
    -- SETTINGS
    ----------------------------------------------------

    local DETECTION_RADIUS = 15
    local PARRY_COOLDOWN = 0.05

    local lastParry = 0
    local lastPulse = 0
    local espReloadTick = 0

    local scannedObjects = {}
    local hookedCharacters = {}
    local objectStates = {}

    ----------------------------------------------------
    -- BLOCKED CLASS
    ----------------------------------------------------

    local BLOCKED_CLASSES = {

        Sound = true,
        Animation = true,
        MeshPart = true,
        Part = true,
        UnionOperation = true,
        Model = true,
        Accessory = true,
        Attachment = true,
        Decal = true,
        Texture = true,
        Highlight = true,
        Trail = true,
        Beam = true,
        Smoke = true,
        Fire = true,
        Sparkles = true
    }

    ----------------------------------------------------
    -- BLOCKED NAMES
    ----------------------------------------------------

    local BLOCKED_NAMES = {

        ["movement spike"] = true,
        ["possible dash/lunge"] = true,

        ["idle"] = true,
        ["walk"] = true,
        ["run"] = true,
        ["jump"] = true,

        ["animation"] = true,
        ["sound"] = true,
        ["mesh"] = true,

        ["thumbnailcameratarget"] = true,
        ["pcube4_knife_0"] = true
    }

    ----------------------------------------------------
    -- ROOT
    ----------------------------------------------------

    local function getRoot(char)

        return
            char:FindFirstChild("HumanoidRootPart")
            or char:FindFirstChild("Torso")
    end

    ----------------------------------------------------
    -- VALID OBJECT FILTER
    ----------------------------------------------------

    local function isValidCombatObject(obj)

        if not obj then
            return false
        end

        local className =
            tostring(obj.ClassName)

        local objName =
            tostring(obj.Name):lower()

        ------------------------------------------------
        -- BLOCKED CLASS
        ------------------------------------------------

        if BLOCKED_CLASSES[className] then
            return false
        end

        ------------------------------------------------
        -- BLOCKED NAME
        ------------------------------------------------

        if BLOCKED_NAMES[objName] then
            return false
        end

        ------------------------------------------------
        -- ACCEPT
        ------------------------------------------------

        return true
    end

    ----------------------------------------------------
    -- KILLER CHECK
    ----------------------------------------------------

    local function isKiller(player)

        if not player
        or player == localPlayer then
            return false
        end

        ------------------------------------------------
        -- TEAM CHECK
        ------------------------------------------------

        if player.Team then

            local t =
                tostring(player.Team.Name):lower()

            if t:find("killer")
            or t:find("monster")
            or t:find("enemy") then

                return true
            end
        end

        ------------------------------------------------
        -- CHARACTER CHECK
        ------------------------------------------------

        local char = player.Character

        if char then

            if char:FindFirstChild("Weapon") then
                return true
            end

            local tool =
                char:FindFirstChildWhichIsA("Tool")

            if tool then

                local n =
                    tostring(tool.Name):lower()

                if n:find("knife")
                or n:find("blade")
                or n:find("weapon")
                or n:find("bat")
                or n:find("machete")
                or n:find("staff") then

                    return true
                end
            end
        end

        return false
    end

    ----------------------------------------------------
    -- PARRY
    ----------------------------------------------------

    local function triggerParry(reason, player)

        if tick() - lastParry < PARRY_COOLDOWN then
            return
        end

        if not player then
            return
        end

        local char = player.Character
        if not char then
            return
        end

        local root = getRoot(char)
        if not root then
            return
        end

        ------------------------------------------------
        -- ONLY RADIUS VALIDATION
        ------------------------------------------------

        local dist =
            (
                localRootPart.Position
                - root.Position
            ).Magnitude

        if dist > DETECTION_RADIUS then
            return
        end

        lastParry = tick()

        print("========== AUTO PARRY ==========")
        print("Reason :", reason)
        print("Killer :", player.Name)
        print("Distance :", math.floor(dist))
        print("================================")

        pcall(function()

            fireParryRemote(player)
        end)
    end

    ----------------------------------------------------
    -- ESP CLEAN
    ----------------------------------------------------

    if radiusFolder then

        pcall(function()
            radiusFolder:Destroy()
        end)
    end

    radiusFolder = Instance.new("Folder")
    radiusFolder.Name = "ParryESP"
    radiusFolder.Parent = workspace

    ----------------------------------------------------
    -- CREATE MAIN ESP
    ----------------------------------------------------

    local function createMainESP()

        local circle = Instance.new("Part")

        circle.Name = "MainRadius"

        circle.Shape = Enum.PartType.Cylinder
        circle.Material = Enum.Material.Neon

        circle.Color =
            Color3.fromRGB(255,140,0)

        circle.Transparency = 0.90

        circle.Anchored = true
        circle.CanCollide = false
        circle.CastShadow = false

        circle.Size = Vector3.new(
            0.04,
            DETECTION_RADIUS * 2,
            DETECTION_RADIUS * 2
        )

        circle.Parent = radiusFolder

        return circle
    end

    local mainCircle = createMainESP()

    ----------------------------------------------------
    -- PULSE
    ----------------------------------------------------

    local function createPulse()

        if not localRootPart then
            return
        end

        local pulse = Instance.new("Part")

        pulse.Shape = Enum.PartType.Cylinder
        pulse.Material = Enum.Material.Neon

        pulse.Color =
            Color3.fromRGB(255,170,0)

        pulse.Transparency = 0.86

        pulse.Anchored = true
        pulse.CanCollide = false
        pulse.CastShadow = false

        pulse.Size = Vector3.new(
            0.02,
            2,
            2
        )

        pulse.CFrame =
            CFrame.new(
                localRootPart.Position
                - Vector3.new(0,2,0)
            )
            * CFrame.Angles(
                0,
                0,
                math.rad(90)
            )

        pulse.Parent = radiusFolder

        task.spawn(function()

            local size = 2

            for i = 1,20 do

                if not pulse.Parent
                or not localRootPart then
                    break
                end

                size += DETECTION_RADIUS / 10

                pulse.Size = Vector3.new(
                    0.02,
                    size,
                    size
                )

                pulse.Transparency += 0.005

                pulse.CFrame =
                    CFrame.new(
                        localRootPart.Position
                        - Vector3.new(0,2,0)
                    )
                    * CFrame.Angles(
                        0,
                        0,
                        math.rad(90)
                    )

                RunService.Heartbeat:Wait()
            end

            pcall(function()
                pulse:Destroy()
            end)
        end)
    end

    ----------------------------------------------------
    -- STATE UPDATE DETECTION
    ----------------------------------------------------

    local function registerStateUpdate(player, obj, reason)

        if not isValidCombatObject(obj) then
            return
        end

        local previous =
            objectStates[obj]

        local current =
            tostring(obj:GetFullName())
            .. "|"
            .. tostring(obj.Parent)
            .. "|"
            .. tostring(obj.Name)

        ------------------------------------------------
        -- ONLY UPDATE TRIGGER
        ------------------------------------------------

        if previous ~= current then

            objectStates[obj] = current

            triggerParry(reason, player)
        end
    end

    ----------------------------------------------------
    -- OBJECT SCAN
    ----------------------------------------------------

    local function scanObject(player, obj)

        if scannedObjects[obj] then
            return
        end

        scannedObjects[obj] = true

        ------------------------------------------------
        -- FILTER
        ------------------------------------------------

        if not isValidCombatObject(obj) then
            return
        end

        ------------------------------------------------
        -- INITIAL STATE
        ------------------------------------------------

        objectStates[obj] =
            tostring(obj:GetFullName())

        ------------------------------------------------
        -- ATTRIBUTE UPDATE
        ------------------------------------------------

        pcall(function()

            obj.AttributeChanged:Connect(function(attr)

                registerStateUpdate(
                    player,
                    obj,
                    "AttributeUpdate : "..tostring(attr)
                )
            end)
        end)

        ------------------------------------------------
        -- PROPERTY UPDATE
        ------------------------------------------------

        pcall(function()

            obj.Changed:Connect(function()

                registerStateUpdate(
                    player,
                    obj,
                    "Changed : "..obj.ClassName
                )
            end)
        end)

        ------------------------------------------------
        -- VALUE OBJECT UPDATE
        ------------------------------------------------

        if obj:IsA("BoolValue")
        or obj:IsA("IntValue")
        or obj:IsA("StringValue")
        or obj:IsA("NumberValue")
        or obj:IsA("ObjectValue") then

            obj.Changed:Connect(function()

                registerStateUpdate(
                    player,
                    obj,
                    "ValueUpdate : "..obj.Name
                )
            end)
        end
    end

    ----------------------------------------------------
    -- HOOK CHARACTER
    ----------------------------------------------------

    local function hookCharacter(player, char)

        if hookedCharacters[char] then
            return
        end

        hookedCharacters[char] = true

        if not isKiller(player) then
            return
        end

        print("[AutoParry] Hooked :", player.Name)

        ------------------------------------------------
        -- EXISTING OBJECT
        ------------------------------------------------

        for _, obj in ipairs(char:GetDescendants()) do

            scanObject(player, obj)
        end

        ------------------------------------------------
        -- NEW OBJECT
        ------------------------------------------------

        char.DescendantAdded:Connect(function(obj)

            if not isValidCombatObject(obj) then
                return
            end

            scanObject(player, obj)

            ------------------------------------------------
            -- DIRECT UPDATE EVENT
            ------------------------------------------------

            triggerParry(
                "NewCombatUpdate : "..obj.ClassName,
                player
            )
        end)
    end

    ----------------------------------------------------
    -- PLAYER HOOK
    ----------------------------------------------------

    for _, player in ipairs(Players:GetPlayers()) do

        if player ~= localPlayer then

            if player.Character then

                hookCharacter(
                    player,
                    player.Character
                )
            end

            player.CharacterAdded:Connect(function(char)

                task.wait(1)

                hookCharacter(
                    player,
                    char
                )
            end)
        end
    end

    ----------------------------------------------------
    -- NEW PLAYER
    ----------------------------------------------------

    Players.PlayerAdded:Connect(function(player)

        player.CharacterAdded:Connect(function(char)

            task.wait(1)

            hookCharacter(
                player,
                char
            )
        end)
    end)

    ----------------------------------------------------
    -- HEARTBEAT
    ----------------------------------------------------

    combatHeartbeat =
        RunService.Heartbeat:Connect(function(dt)

        ------------------------------------------------
        -- DISABLE
        ------------------------------------------------

        if not config.infiniteAmmoEnabled then

            combatStateConnected = false

            if combatHeartbeat then

                combatHeartbeat:Disconnect()
                combatHeartbeat = nil
            end

            if radiusFolder then

                pcall(function()
                    radiusFolder:Destroy()
                end)

                radiusFolder = nil
            end

            return
        end

        if not localRootPart then
            return
        end

        ------------------------------------------------
        -- ESP RELOAD
        ------------------------------------------------

        espReloadTick += dt

        if not mainCircle
        or not mainCircle.Parent
        or espReloadTick >= 1 then

            espReloadTick = 0

            pcall(function()

                if mainCircle then
                    mainCircle:Destroy()
                end
            end)

            mainCircle = createMainESP()
        end

        ------------------------------------------------
        -- ESP POSITION
        ------------------------------------------------

        local espPos =
            localRootPart.Position
            - Vector3.new(0,2,0)

        mainCircle.CFrame =
            CFrame.new(espPos)
            * CFrame.Angles(
                0,
                0,
                math.rad(90)
            )

        ------------------------------------------------
        -- PULSE
        ------------------------------------------------

        if tick() - lastPulse >= 0.16 then

            lastPulse = tick()

            createPulse()
        end

        ------------------------------------------------
        -- RUNTIME UPDATE SCAN
        ------------------------------------------------

        for _, player in ipairs(Players:GetPlayers()) do

            if isKiller(player) then

                local char =
                    player.Character

                if char then

                    local root =
                        getRoot(char)

                    if root then

                        local dist =
                            (
                                localRootPart.Position
                                - root.Position
                            ).Magnitude

                        ------------------------------------------------
                        -- ONLY INSIDE RADIUS
                        ------------------------------------------------

                        if dist <= DETECTION_RADIUS then

                            for _, obj in ipairs(
                                char:GetDescendants()
                            ) do

                                if isValidCombatObject(obj) then

                                    ------------------------------------------------
                                    -- ONLY UPDATE / CHANGE
                                    ------------------------------------------------

                                    local current =
                                        tostring(obj:GetFullName())
                                        .. "|"
                                        .. tostring(obj.Parent)
                                        .. "|"
                                        .. tostring(obj.Name)

                                    local previous =
                                        objectStates[obj]

                                    if previous ~= current then

                                        objectStates[obj] = current

                                        triggerParry(
                                            "RuntimeUpdate : "..obj.ClassName,
                                            player
                                        )
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    print("[AutoParry] Adaptive update combat scanner initialized")
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
-- Hapus atau komentari seluruh fungsi restartScript() yang lama.
-- Tambahkan kode berikut di area yang sama (sebelum createGUI).

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
-- FEATURE 9: AUTO SHIELD (ForceField Protection - ALWAYS ACTIVE WHEN ENABLED)
-- Tidak menggunakan trigger jarak killer. Shield aktif terus saat fitur dinyalakan.
-- ============================================================================
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

-- Fungsi ini sekarang hanya mengaktifkan/menonaktifkan shield berdasarkan config (tanpa cek jarak).
local function checkShieldProximity()
    if not config.shieldEnabled then
        if isShieldActive then removeForceField() end
        return
    end
    if not isShieldActive then addForceField() end
end

local function startShieldMonitor()
    if shieldConnection then return end
    shieldConnection = RunService.Heartbeat:Connect(checkShieldProximity)
end

local function stopShieldMonitor()
    if shieldConnection then shieldConnection:Disconnect(); shieldConnection = nil end
    removeForceField()
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
-- AUTO GENERATOR LOOP (MANUAL REPAIR + SMART ESCAPE + SKILL CHECK)
-- Tidak membuat config/state global baru. Hanya menggunakan config.autoGeneratorThread.
-- Skill check menggunakan variabel lokal terisolasi (tidak konflik dengan autoSkillCheck asli).
-- ============================================================================

local function startAutoGeneratorLoop()
    -- Cegah multiple thread
    if config.autoGeneratorThread then
        return
    end

    -- =========================================================================
    -- FUNGSI DETEKSI GENERATOR (lokal, tidak global)
    -- =========================================================================
    local function isGeneratorObject(obj)
        if not obj then return false end
        local name = tostring(obj.Name):lower()
        if name:find("generator") or name:find("gen") or name == "generatorrepair" then
            return true
        end
        if obj:FindFirstChild("Progress") or obj:FindFirstChild("Completed") then
            return true
        end
        if obj:FindFirstChildWhichIsA("ClickDetector") or obj:FindFirstChildWhichIsA("ProximityPrompt", true) then
            return true
        end
        return false
    end

    local function getAllIncompleteGenerators()
        local list = {}
        for _, obj in ipairs(workspace:GetDescendants()) do
            if isGeneratorObject(obj) then
                local completed = false
                local prog = obj:FindFirstChild("Progress")
                if prog and (prog:IsA("IntValue") or prog:IsA("NumberValue")) then
                    if prog.Value >= 100 then completed = true end
                end
                local comp = obj:FindFirstChild("Completed")
                if comp and comp:IsA("BoolValue") and comp.Value then completed = true end
                if obj:GetAttribute("RepairProgress") and obj:GetAttribute("RepairProgress") >= 100 then completed = true end
                if not completed then
                    table.insert(list, obj)
                end
            end
        end
        return list
    end

    local function getRandomIncompleteGenerator()
        local gens = getAllIncompleteGenerators()
        if #gens == 0 then return nil end
        return gens[math.random(1, #gens)]
    end

    -- =========================================================================
    -- DETEKSI THREAT (killer / scp / enemy)
    -- =========================================================================
    local function isThreatNearby(radius)
        if not localRootPart then return false end
        local pos = localRootPart.Position
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= localPlayer then
                local char = player.Character
                if char then
                    local isThreat = false
                    if player.Team then
                        local teamName = player.Team.Name:lower()
                        if teamName:find("killer") or teamName:find("monster") or teamName:find("enemy") or teamName:find("scp") then
                            isThreat = true
                        end
                    end
                    if not isThreat then
                        local tool = char:FindFirstChildWhichIsA("Tool")
                        if tool and (tool.Name:lower():find("knife") or tool.Name:lower():find("weapon")) then
                            isThreat = true
                        end
                    end
                    if not isThreat then
                        for _, child in ipairs(char:GetChildren()) do
                            if child.Name:lower():find("scp") then
                                isThreat = true
                                break
                            end
                        end
                    end
                    if isThreat then
                        local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                        if root and (pos - root.Position).Magnitude <= radius then
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    -- =========================================================================
    -- SIMULASI INTERAKSI (tombol E)
    -- =========================================================================
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

    -- =========================================================================
    -- SKILL CHECK HANDLER KHUSUS UNTUK AUTO GENERATOR (tidak konflik dengan fitur lain)
    -- =========================================================================
    local function setupAutoGenSkillCheck()
        local visibilityConn = nil
        local heartbeatConn = nil
        local touchID = 8823  -- berbeda dengan fitur asli (8822)
        local actionPath = "SkillCheckPromptGui.Check"

        local function getActionTarget()
            local current = localPlayer:FindFirstChild("PlayerGui")
            if not current then return nil end
            for segment in string.gmatch(actionPath, "[^%.]+") do
                current = current and current:FindFirstChild(segment)
                if not current then break end
            end
            return current
        end

        local function triggerMobileButton()
            local b = getActionTarget()
            if b and b:IsA("GuiObject") then
                local p, s, i = b.AbsolutePosition, b.AbsoluteSize, GuiService:GetGuiInset()
                local cx, cy = p.X + (s.X/2) + i.X, p.Y + (s.Y/2) + i.Y
                pcall(function()
                    VirtualInputManager:SendTouchEvent(touchID, 0, cx, cy)
                    task.wait(0.01)
                    VirtualInputManager:SendTouchEvent(touchID, 2, cx, cy)
                end)
            end
        end

        task.spawn(function()
            local playerGui = localPlayer:FindFirstChild("PlayerGui")
            if not playerGui then return end
            local prompt = playerGui:FindFirstChild("SkillCheckPromptGui")
            if not prompt then
                prompt = playerGui:WaitForChild("SkillCheckPromptGui", 10)
            end
            local check = prompt and prompt:FindFirstChild("Check")
            if not check then return end
            local line = check:FindFirstChild("Line")
            local goal = check:FindFirstChild("Goal")
            if not line or not goal then return end

            if visibilityConn then visibilityConn:Disconnect() end
            visibilityConn = check:GetPropertyChangedSignal("Visible"):Connect(function()
                if localPlayer.Team and localPlayer.Team.Name == "Survivors" and check.Visible then
                    if heartbeatConn then heartbeatConn:Disconnect() end
                    heartbeatConn = RunService.Heartbeat:Connect(function()
                        local lr = line.Rotation % 360
                        local gr = goal.Rotation % 360
                        local ss = (gr + 104) % 360
                        local se = (gr + 118) % 360
                        local inRange = false
                        if ss > se then
                            if lr >= ss or lr <= se then inRange = true end
                        else
                            if lr >= ss and lr <= se then inRange = true end
                        end
                        if inRange then
                            triggerMobileButton()
                            if heartbeatConn then heartbeatConn:Disconnect(); heartbeatConn = nil end
                        end
                    end)
                elseif heartbeatConn then
                    heartbeatConn:Disconnect()
                    heartbeatConn = nil
                end
            end)
        end)

        -- Kembalikan fungsi cleanup
        return function()
            if visibilityConn then visibilityConn:Disconnect() end
            if heartbeatConn then heartbeatConn:Disconnect() end
        end
    end

    -- =========================================================================
    -- LOOP UTAMA (semua state disimpan dalam closure thread)
    -- =========================================================================
    local thread = task.spawn(function()
        -- State lokal (hanya ada dalam thread ini)
        local currentGen = nil
        local repairStarted = false
        local lastEscapeTime = 0
        local lastProgressCheck = 0
        local skillCheckCleanup = setupAutoGenSkillCheck()

        while config.autoGeneratorEnabled do
            pcall(function()
                if not getLocalCharacter() or not localRootPart then
                    task.wait(0.5)
                    return
                end

                -- 1. Cek ancaman (killer/scp dalam radius 30 studs)
                local threatNearby = isThreatNearby(30)

                -- 2. Jika ancaman, pindah ke generator lain (lompat)
                if threatNearby and tick() - lastEscapeTime >= 1 then
                    local newGen = getRandomIncompleteGenerator()
                    if newGen and newGen ~= currentGen then
                        local success, pivot = pcall(function() return newGen:GetPivot() end)
                        if success and pivot then
                            teleportTo(pivot.Position + Vector3.new(0, 3, 0))
                            currentGen = newGen
                            repairStarted = false
                            lastEscapeTime = tick()
                            print("[AutoGenerator] Escaped threat, switched to:", currentGen.Name)
                            task.wait(0.3)
                        end
                    end
                    task.wait(0.5)
                    return
                end

                -- 3. Pilih generator baru jika belum punya atau generator sebelumnya selesai
                if not currentGen then
                    local gen = getRandomIncompleteGenerator()
                    if gen then
                        currentGen = gen
                        repairStarted = false
                        print("[AutoGenerator] New target:", currentGen.Name)
                    else
                        task.wait(1)
                        return
                    end
                end

                -- 4. Cek progress generator saat ini
                local progress = 0
                local progVal = currentGen:FindFirstChild("Progress")
                if progVal and (progVal:IsA("IntValue") or progVal:IsA("NumberValue")) then
                    progress = progVal.Value
                elseif currentGen:GetAttribute("RepairProgress") then
                    progress = currentGen:GetAttribute("RepairProgress")
                end

                if progress >= 100 then
                    print("[AutoGenerator] Completed:", currentGen.Name)
                    currentGen = getRandomIncompleteGenerator()
                    repairStarted = false
                    if currentGen then
                        print("[AutoGenerator] Next target:", currentGen.Name)
                    end
                    task.wait(0.5)
                    return
                end

                -- 5. Mulai repair jika belum dimulai
                if not repairStarted then
                    local success, pivot = pcall(function() return currentGen:GetPivot() end)
                    if success and pivot then
                        teleportTo(pivot.Position + Vector3.new(0, 3, 0))
                        task.wait(0.2)
                        simulatePressE()   -- Interaksi mulai repair
                        repairStarted = true
                        print("[AutoGenerator] Repair started on:", currentGen.Name)
                        task.wait(0.3)
                    else
                        print("[AutoGenerator] Teleport failed, retrying...")
                        currentGen = nil
                    end
                    return
                end

                -- 6. Cek progress secara berkala (skill check sudah berjalan otomatis)
                if tick() - lastProgressCheck >= 0.3 then
                    lastProgressCheck = tick()
                    -- Tidak perlu aksi tambahan, skill check handler akan menangani QTE
                end
            end)
            task.wait(0.2)
        end

        -- Bersihkan skill check handler saat loop berhenti
        if skillCheckCleanup then
            skillCheckCleanup()
        end
    end)

    -- Simpan thread ke config (menggunakan field yang sudah ada)
    config.autoGeneratorThread = thread
    print("[AutoGenerator] Started (manual repair + smart escape + skill check)")
end

-- ============================================================================
-- STOP AUTO GENERATOR LOOP
-- ============================================================================
local function stopAutoGeneratorLoop()
    if config.autoGeneratorThread then
        task.cancel(config.autoGeneratorThread)
        config.autoGeneratorThread = nil
    end
    print("[AutoGenerator] Stopped")
end


--========================
-- Skull check
--========================
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
        if not prompt then
            prompt = playerGui:WaitForChild("SkillCheckPromptGui", 10)
        end
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
                    local ss = (gr + 104) % 360
                    local se = (gr + 118) % 360
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
                        if gui.Visible and gui.Active then
                            pcall(function() gui:FireClick() end)
                        end
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
    print("[AutoSkillCheck] Auto skill check stopped")
end
-- ============================================================================
-- FEATURE 15: AUTO AIM (unchanged)
-- ============================================================================
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
  
-- Teks untuk menu Info (bisa diedit langsung di sini)  
local infoText = [[  
CYBERHEROES SCRIPT v10.1  
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  ]]  
  
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
-- SETTINGS CONTENT (sama seperti sebelumnya)  
-- ============================================================================  
local function createSettingsContent()  
    if settingsContent then settingsContent:Destroy() end  
    settingsContent = Instance.new("Frame")  
    settingsContent.Size = UDim2.new(1, 0, 1, 0)  
    settingsContent.BackgroundTransparency = 1  
    settingsContent.Parent = contentPanel  
  
    local colorLabel = Instance.new("TextLabel")  
    colorLabel.Size = UDim2.new(1, -10, 0, 20)  
    colorLabel.Position = UDim2.new(0, 5, 0, 5)  
    colorLabel.Text = "THEME COLOR"  
    colorLabel.TextColor3 = Color3.fromRGB(200, 200, 200)  
    colorLabel.BackgroundTransparency = 1  
    colorLabel.Font = Enum.Font.GothamBold  
    colorLabel.TextSize = 12  
    colorLabel.Parent = settingsContent  
  
    local colorRed = Instance.new("TextButton")  
    colorRed.Size = UDim2.new(0, 60, 0, 25)  
    colorRed.Position = UDim2.new(0.05, 0, 0.1, 0)  
    colorRed.Text = "RED"  
    colorRed.BackgroundColor3 = Color3.fromRGB(255, 0, 0)  
    colorRed.TextColor3 = Color3.fromRGB(255, 255, 255)  
    colorRed.Font = Enum.Font.GothamBold  
    colorRed.TextSize = 10  
    colorRed.Parent = settingsContent  
    colorRed.MouseButton1Click:Connect(function()  
        config.guiThemeColor = Color3.fromRGB(255, 0, 0)  
        updateTheme()  
    end)  
  
    local colorCyan = Instance.new("TextButton")  
    colorCyan.Size = UDim2.new(0, 60, 0, 25)  
    colorCyan.Position = UDim2.new(0.35, 0, 0.1, 0)  
    colorCyan.Text = "CYAN"  
    colorCyan.BackgroundColor3 = Color3.fromRGB(0, 255, 255)  
    colorCyan.TextColor3 = Color3.fromRGB(0, 0, 0)  
    colorCyan.Font = Enum.Font.GothamBold  
    colorCyan.TextSize = 10  
    colorCyan.Parent = settingsContent  
    colorCyan.MouseButton1Click:Connect(function()  
        config.guiThemeColor = Color3.fromRGB(0, 255, 255)  
        updateTheme()  
    end)  
  
    local colorYellow = Instance.new("TextButton")  
    colorYellow.Size = UDim2.new(0, 60, 0, 25)  
    colorYellow.Position = UDim2.new(0.65, 0, 0.1, 0)  
    colorYellow.Text = "YELLOW"  
    colorYellow.BackgroundColor3 = Color3.fromRGB(255, 255, 0)  
    colorYellow.TextColor3 = Color3.fromRGB(0, 0, 0)  
    colorYellow.Font = Enum.Font.GothamBold  
    colorYellow.TextSize = 10  
    colorYellow.Parent = settingsContent  
    colorYellow.MouseButton1Click:Connect(function()  
        config.guiThemeColor = Color3.fromRGB(255, 255, 0)  
        updateTheme()  
    end)  
  
    local chatLabel = Instance.new("TextLabel")  
    chatLabel.Size = UDim2.new(1, -10, 0, 20)  
    chatLabel.Position = UDim2.new(0, 5, 0, 0.2)  
    chatLabel.Text = ""  
    chatLabel.TextColor3 = Color3.fromRGB(200, 200, 200)  
    chatLabel.BackgroundTransparency = 1  
    chatLabel.Font = Enum.Font.GothamBold  
    chatLabel.TextSize = 12  
    chatLabel.Parent = settingsContent  
  
    chatLog = Instance.new("ScrollingFrame")  
    chatLog.Size = UDim2.new(0.9, 0, 0, 100)  
    chatLog.Position = UDim2.new(0.05, 0, 0.26, 0)  
    chatLog.BackgroundColor3 = Color3.fromRGB(15, 0, 2)  
    chatLog.BackgroundTransparency = 0.3  
    chatLog.BorderSizePixel = 0  
    chatLog.Parent = settingsContent  
    local chatLogCorner = Instance.new("UICorner")  
    chatLogCorner.CornerRadius = UDim.new(0, 4)  
    chatLogCorner.Parent = chatLog  
  
    local chatListLayout = Instance.new("UIListLayout")  
    chatListLayout.Padding = UDim.new(0, 2)  
    chatListLayout.Parent = chatLog  
  
    chatInput = Instance.new("TextBox")  
    chatInput.Size = UDim2.new(0.7, 0, 0, 25)  
    chatInput.Position = UDim2.new(0.05, 0, 0.38, 0)  
    chatInput.PlaceholderText = "type report......"  
    chatInput.Text = ""  
    chatInput.BackgroundColor3 = Color3.fromRGB(15, 0, 2)  
    chatInput.BackgroundTransparency = 0.3  
    chatInput.TextColor3 = Color3.fromRGB(255, 255, 255)  
    chatInput.Font = Enum.Font.Gotham  
    chatInput.TextSize = 10  
    chatInput.BorderSizePixel = 0  
    chatInput.Parent = settingsContent  
    local chatInputCorner = Instance.new("UICorner")  
    chatInputCorner.CornerRadius = UDim.new(0, 4)  
    chatInputCorner.Parent = chatInput  
  
    local sendBtn = Instance.new("TextButton")  
    sendBtn.Size = UDim2.new(0.18, 0, 0, 25)  
    sendBtn.Position = UDim2.new(0.77, 0, 0.38, 0)  
    sendBtn.Text = "SEND"  
    sendBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)  
    sendBtn.TextColor3 = Color3.fromRGB(200, 200, 200)  
    sendBtn.Font = Enum.Font.GothamBold  
    sendBtn.TextSize = 10  
    sendBtn.BorderSizePixel = 0  
    sendBtn.Parent = settingsContent  
    local sendCorner = Instance.new("UICorner")  
    sendCorner.CornerRadius = UDim.new(0, 4)  
    sendCorner.Parent = sendBtn  
  
    sendBtn.MouseButton1Click:Connect(function()  
        local msg = chatInput.Text  
        if msg == "" then return end  
        local newMsg = Instance.new("TextLabel")  
        newMsg.Size = UDim2.new(1, 0, 0, 16)  
        newMsg.Text = "[user] " .. msg  
        newMsg.TextColor3 = Color3.fromRGB(200, 200, 200)  
        newMsg.BackgroundTransparency = 1  
        newMsg.Font = Enum.Font.Gotham  
        newMsg.TextSize = 9  
        newMsg.TextXAlignment = Enum.TextXAlignment.Left  
        newMsg.Parent = chatLog  
        chatInput.Text = ""  
        chatLog.CanvasSize = UDim2.new(0, 0, 0, chatListLayout.AbsoluteContentSize.Y)  
        task.wait(2)  
        newMsg:Destroy()  
    end)  
end  
  
-- ============================================================================  
-- INFO CONTENT (baru)  
-- ============================================================================  
local infoContent = nil  
local function createInfoContent()  
    if infoContent then infoContent:Destroy() end  
    infoContent = Instance.new("Frame")  
    infoContent.Size = UDim2.new(1, 0, 1, 0)  
    infoContent.BackgroundTransparency = 1  
    infoContent.Parent = contentPanel  
  
    local scrollFrame = Instance.new("ScrollingFrame")  
    scrollFrame.Size = UDim2.new(1, -10, 1, -10)  
    scrollFrame.Position = UDim2.new(0, 5, 0, 5)  
    scrollFrame.BackgroundColor3 = Color3.fromRGB(15, 0, 2)  
    scrollFrame.BackgroundTransparency = 0.3  
    scrollFrame.BorderSizePixel = 0  
    scrollFrame.ScrollBarThickness = 6  
    scrollFrame.Parent = infoContent  
    local scrollCorner = Instance.new("UICorner")  
    scrollCorner.CornerRadius = UDim.new(0, 4)  
    scrollCorner.Parent = scrollFrame  
  
    local textLabel = Instance.new("TextLabel")  
    textLabel.Size = UDim2.new(1, 0, 0, 0)  
    textLabel.Text = infoText  
    textLabel.TextColor3 = Color3.fromRGB(200, 200, 200)  
    textLabel.BackgroundTransparency = 1  
    textLabel.Font = Enum.Font.Gotham  
    textLabel.TextSize = 10  
    textLabel.TextXAlignment = Enum.TextXAlignment.Left  
    textLabel.TextYAlignment = Enum.TextYAlignment.Top  
    textLabel.TextWrapped = true  
    textLabel.Parent = scrollFrame  
  
    -- Hitung tinggi teks  
    textLabel.Text = infoText  
    local textBounds = textLabel.TextBounds  
    textLabel.Size = UDim2.new(1, 0, 0, textBounds.Y + 20)  
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, textBounds.Y + 30)  
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
local function createGridButton(parent, name, text, initialState, onChange)  
    local button = Instance.new("TextButton")  
    button.Name = name  
    button.Size = UDim2.new(0, 85, 0, 32)  
    button.Text = text .. (initialState and " [ON]" or " [OFF]")  
    button.BackgroundColor3 = initialState and Color3.fromRGB(40, 5, 5) or Color3.fromRGB(15, 0, 2)  
    button.BackgroundTransparency = 0.1  
    button.TextColor3 = initialState and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)  
    button.TextSize = 9  
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
    local function updateState(state)  
        button.Text = text .. (state and " [ON]" or " [OFF]")  
        button.BackgroundColor3 = state and Color3.fromRGB(40, 5, 5) or Color3.fromRGB(15, 0, 2)  
        button.TextColor3 = state and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)  
        stroke.Color = state and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(150, 30, 30)  
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
        elseif name == "povMode" then
            togglePOV()
            return  
        end  
        updateState(newState)  
        if onChange then onChange(newState) end  
        TweenService:Create(button, TweenInfo.new(0.05), {TextSize = 8}):Play()  
        task.wait(0.05)  
        TweenService:Create(button, TweenInfo.new(0.05), {TextSize = 9}):Play()  
    end)  
    return button  
end  
  
local function createSidebarItem(parent, text, icon, active)  
    local button = Instance.new("TextButton")  
    button.Size = UDim2.new(1, 0, 0, 28)  
    button.Text = " " .. icon .. "  " .. text  
    button.TextColor3 = active and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)  
    button.BackgroundColor3 = active and Color3.fromRGB(40, 5, 5) or Color3.fromRGB(15, 0, 2)  
    button.BackgroundTransparency = 0.2  
    button.TextSize = 10  
    button.Font = Enum.Font.GothamBold  
    button.TextXAlignment = Enum.TextXAlignment.Left  
    button.BorderSizePixel = 0  
    button.Parent = parent  
    local corner = Instance.new("UICorner")  
    corner.CornerRadius = UDim.new(0, 4)  
    corner.Parent = button  
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
    teleportButton.TextSize = 14  
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
    mainStroke = Instance.new("UIStroke")  
    mainStroke.Color = config.guiThemeColor  
    mainStroke.Thickness = 1.5  
    mainStroke.Transparency = 0.4  
    mainStroke.Parent = mainFrame  
  
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
    title.Text = "CYBERHEROES script by kemi"  
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
    versionLabel.TextSize = 9  
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
    minimizeBtn.TextSize = 18  
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
    closeBtn.TextSize = 14  
    closeBtn.Parent = titleBar  
    local closeCorner = Instance.new("UICorner")  
    closeCorner.CornerRadius = UDim.new(0, 3)  
    closeCorner.Parent = closeBtn  
  
        -- Fungsi minimize: sembunyikan mainFrame, tampilkan floating bar  
    local function minimizeGUI()  
        config.guiVisible = false  
        if mainFrame then mainFrame.Visible = false end  
        -- Hancurkan floating bar lama jika ada agar tidak bentrok  
        if floatingBar then  
            pcall(function() floatingBar:Destroy() end)  
            floatingBar = nil  
        end  
        createFloatingBar() -- buat baru  
        isFloatingVisible = true  
end  
  
    -- Fungsi close sama dengan minimize (tidak menghancurkan)  
    minimizeBtn.MouseButton1Click:Connect(minimizeGUI)  
    closeBtn.MouseButton1Click:Connect(minimizeGUI)  
  
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
  
    local homeItem = createSidebarItem(sidebarList, "HOME", "", true)  
    local featuresItem = createSidebarItem(sidebarList, "FEATURES", "", false)  
    local settingsItem = createSidebarItem(sidebarList, "SETTINGS", "", false)  
    local infoItem = createSidebarItem(sidebarList, "INFO", "", false)  
    local aboutItem = createSidebarItem(sidebarList, "ABOUT", "", false)  
    local sep = Instance.new("Frame")  
    sep.Size = UDim2.new(0.8, 0, 0, 1)  
    sep.BackgroundColor3 = Color3.fromRGB(0, 200, 255)  
    sep.BackgroundTransparency = 0.7  
    sep.Parent = sidebarList  
  
    contentPanel = Instance.new("Frame")  
    contentPanel.Size = UDim2.new(1, -90, 1, -30)  
    contentPanel.Position = UDim2.new(0, 85, 0, 28)  
    contentPanel.BackgroundTransparency = 1  
    contentPanel.Parent = mainFrame  
    local gridLayout = Instance.new("UIGridLayout")  
    gridLayout.CellSize = UDim2.new(0, 80, 0, 32)  
    gridLayout.CellPadding = UDim2.new(0, 4, 0, 4)  
    gridLayout.FillDirection = Enum.FillDirection.Horizontal  
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center  
    gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top  
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder  
    gridLayout.Parent = contentPanel  
  
    local features = {  
        {name="autoWinEnabled", text="AUTO WIN"},  
        {name="autoTaskEnabled", text="AUTO TASK"},  
        {name="espEnabled", text="ESP"},  
        {name="speedBoostEnabled", text="SPEED BOOST"},  
        {name="stealthEnabled", text="STEALTH"},  
        {name="godModeEnabled", text="GOD MODE"},  
        {name="infiniteAmmoEnabled", text="Dagger"},  
        {name="shieldEnabled", text="SHIELD"},  
        {name="tpwalkEnabled", text="TPWALK"},  
        {name="noCollideEnabled", text="NO COLLIDE"},  
        {name="massKillEnabled", text="MASS KILL"},  
        {name="autoGeneratorEnabled", text="AUTO GEN"},  
        {name="autoSkillCheckEnabled", text="SKILL CHECK"},  
        {name="autoAimEnabled", text="AUTO AIM"},  
        {name="povMode", text="POV"}  
    }  
    for _, feat in ipairs(features) do  
        local initialState = (feat.name ~= "restartScript") and config[feat.name] or false  
        createGridButton(contentPanel, feat.name, feat.text, initialState)  
    end  
  
    -- Navigation handlers  
    homeItem.MouseButton1Click:Connect(function()  
        homeItem.TextColor3 = Color3.fromRGB(0, 230, 255)  
        featuresItem.TextColor3 = Color3.fromRGB(200, 200, 200)  
        settingsItem.TextColor3 = Color3.fromRGB(200, 200, 200)  
        infoItem.TextColor3 = Color3.fromRGB(200, 200, 200)  
        aboutItem.TextColor3 = Color3.fromRGB(200, 200, 200)  
        if settingsContent then settingsContent:Destroy() end  
        if infoContent then infoContent:Destroy() end  
        gridLayout.Parent = contentPanel  
    end)  
    featuresItem.MouseButton1Click:Connect(function()  
        featuresItem.TextColor3 = Color3.fromRGB(0, 230, 255)  
        homeItem.TextColor3 = Color3.fromRGB(200, 200, 200)  
        settingsItem.TextColor3 = Color3.fromRGB(200, 200, 200)  
        infoItem.TextColor3 = Color3.fromRGB(200, 200, 200)  
        aboutItem.TextColor3 = Color3.fromRGB(200, 200, 200)  
        if settingsContent then settingsContent:Destroy() end  
        if infoContent then infoContent:Destroy() end  
        gridLayout.Parent = contentPanel  
    end)  
    settingsItem.MouseButton1Click:Connect(function()  
        settingsItem.TextColor3 = Color3.fromRGB(0, 230, 255)  
        homeItem.TextColor3 = Color3.fromRGB(200, 200, 200)  
        featuresItem.TextColor3 = Color3.fromRGB(200, 200, 200)  
        infoItem.TextColor3 = Color3.fromRGB(200, 200, 200)  
        aboutItem.TextColor3 = Color3.fromRGB(200, 200, 200)  
        gridLayout.Parent = nil  
        if infoContent then infoContent:Destroy() end  
        createSettingsContent()  
    end)  
    infoItem.MouseButton1Click:Connect(function()  
        infoItem.TextColor3 = Color3.fromRGB(0, 230, 255)  
        homeItem.TextColor3 = Color3.fromRGB(200, 200, 200)  
        featuresItem.TextColor3 = Color3.fromRGB(200, 200, 200)  
        settingsItem.TextColor3 = Color3.fromRGB(200, 200, 200)  
        aboutItem.TextColor3 = Color3.fromRGB(200, 200, 200)  
        gridLayout.Parent = nil  
        if settingsContent then settingsContent:Destroy() end  
        createInfoContent()  
    end)  
    aboutItem.MouseButton1Click:Connect(function()  
        aboutItem.TextColor3 = Color3.fromRGB(0, 230, 255)  
        homeItem.TextColor3 = Color3.fromRGB(200, 200, 200)  
        featuresItem.TextColor3 = Color3.fromRGB(200, 200, 200)  
        settingsItem.TextColor3 = Color3.fromRGB(200, 200, 200)  
        infoItem.TextColor3 = Color3.fromRGB(200, 200, 200)  
        if settingsContent then settingsContent:Destroy() end  
        if infoContent then infoContent:Destroy() end  
        gridLayout.Parent = contentPanel  
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
    statusLabel.TextSize = 8  
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
    createPermanentTeleportButton()
    ensureGUIPersistent()
    startAllSystems()
    restoreFeatureStates()
end

task.wait(1)
init()

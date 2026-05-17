

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
-- FEATURE 2: AUTO TASK (ANTI-HOOK + LEVER GOAL GATE SYSTEM)
-- ============================================================================
local function isPlayerHooked()
    if not localCharacter then return false end
    -- Deteksi melalui Humanoid state
    if localHumanoid and localHumanoid:GetState() == Enum.HumanoidStateType.Climbing then
        return true
    end
    -- Deteksi melalui Weld/Parent changes
    local hook = localCharacter:FindFirstChild("Hook") or localCharacter:FindFirstChild("Hooked") or localCharacter:FindFirstChild("Grabbed")
    if hook then return true end
    for _, part in ipairs(localCharacter:GetChildren()) do
        if part.Name:lower():find("hook") or part.Name:lower():find("grabbed") or part.Name:lower():find("carried") then
            return true
        end
    end
    -- Deteksi perubahan posisi drastis (killer membawa)
    if localRootPart and localRootPart.AssemblyLinearVelocity.Magnitude > 30 then
        return true
    end
    return false
end

local function findKillerCharacter()
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
                    return char
                end
            end
        end
    end
    return nil
end

local function knockbackKiller(killerChar)
    if not killerChar then return false end
    local killerRoot = killerChar:FindFirstChild("HumanoidRootPart") or killerChar:FindFirstChild("Torso")
    if not killerRoot then return false end
    -- Cari remote event untuk damage/knockback
    local remoteEvents = {}
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local name = obj.Name:lower()
            if name:find("damage") or name:find("hit") or name:find("knockback") or name:find("drop") or name:find("release") then
                table.insert(remoteEvents, obj)
            end
        end
    end
    for _, remote in ipairs(remoteEvents) do
        pcall(function() remote:FireServer(killerChar) end)
        pcall(function() remote:FireServer(killerChar, "knockback") end)
    end
    -- Brute force knockback dengan velocity
    local direction = (killerRoot.Position - localRootPart.Position).Unit
    killerRoot.Velocity = direction * 50 + Vector3.new(0, 20, 0)
    -- Simulasi press E untuk melepas
    simulatePressE()
    return true
end

local function activateAuto1xMode()
    if isAuto1xModeActive then return end
    if auto1xModeTimerConnection then auto1xModeTimerConnection:Disconnect() end
    if localHumanoid then
        config.originalWalkSpeed = localHumanoid.WalkSpeed
        localHumanoid.WalkSpeed = 16
    end
    isAuto1xModeActive = true
    config.auto1xModeEnabled = true
    print("[Auto1xMode] Activated")
    auto1xModeTimerConnection = task.delay(5, function()
        if isAuto1xModeActive then
            if localHumanoid then
                localHumanoid.WalkSpeed = config.originalWalkSpeed
            end
            isAuto1xModeActive = false
            config.auto1xModeEnabled = false
            if auto1xModeTimerConnection then auto1xModeTimerConnection = nil end
            print("[Auto1xMode] Deactivated")
        end
    end)
end

local function findLeverGoal()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name:lower():find("lever") and obj.Name:lower():find("goal") then
            return obj
        end
    end
    return nil
end

local function findGateFO()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "F_O" then
            return obj
        end
    end
    return nil
end

local function findRightGate()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name:lower():find("right") and obj.Name:lower():find("gate") then
            return obj
        end
    end
    return nil
end

local function findLiftGate()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name:lower():find("lift") and obj.Name:lower():find("gate") then
            return obj
        end
    end
    return nil
end

local function interactWithGate(gate)
    if not gate then return false end
    local targetPart = gate:IsA("BasePart") and gate or gate:FindFirstChildWhichIsA("BasePart")
    if not targetPart then return false end
    local clickDetector = targetPart:FindFirstChildWhichIsA("ClickDetector")
    if clickDetector and clickDetector.Enabled then
        pcall(function() clickDetector:FireClick() end)
        return true
    end
    local proximityPrompt = targetPart:FindFirstChildWhichIsA("ProximityPrompt")
    if proximityPrompt and proximityPrompt.Enabled then
        pcall(function() proximityPrompt:Hold(); task.wait(0.1); proximityPrompt:Release() end)
        return true
    end
    -- Brute force remote event
    for _, remote in ipairs(ReplicatedStorage:GetDescendants()) do
        if remote:IsA("RemoteEvent") and (remote.Name:lower():find("gate") or remote.Name:lower():find("open")) then
            pcall(function() remote:FireServer(gate) end)
            return true
        end
    end
    return false
end

local function teleportToLeverGoal()
    local leverGoal = findLeverGoal()
    if leverGoal then
        local targetPart = leverGoal:IsA("BasePart") and leverGoal or leverGoal:FindFirstChildWhichIsA("BasePart")
        if targetPart then
            teleportTo(targetPart.Position)
            return true
        end
    end
    return false
end

local function autoTaskLoop()
    if not config.autoTaskEnabled then return end
    if not getLocalCharacter() or not localRootPart then return end
    -- Anti-hook
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
        simulatePressE()
        print("[AutoTask] Activated lever goal")
        task.wait(0.5)
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
        -- Fallback: repair generator
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

local function startAutoTask()
    if currentTaskConnection then return end
    currentTaskConnection = RunService.Heartbeat:Connect(autoTaskLoop)
    print("[AutoTask] Auto task started (anti-hook + lever gate system)")
end
local function stopAutoTask()
    if currentTaskConnection then currentTaskConnection:Disconnect(); currentTaskConnection = nil end
    if localHumanoid and config.ao1xModeEnabled then
        localHumanoid.WalkSpeed = config.originalWalkSpeed
        config.auto1xModeEnabled = false
        isAuto1xModeActive = false
    end
    if auto1xModeTimerConnection then auto1xModeTimerConnection:Disconnect(); auto1xModeTimerConnection = nil end
    print("[AutoTask] Auto task stopped")
end

-- ============================================================================
-- FEATURE 3: ESP SYSTEM (UPGRADED - PLAYER + OBJECTS + GENERATOR PROGRESS + LiverGoal/F_O)
-- Menggabungkan pendekatan dari open source script (GetGameValue, ApplyHighlight, Billboard)
-- ============================================================================

-- Storage
local espHighlights = {}           -- untuk player
local objectEspHighlights = {}     -- untuk objek (hook, generator, LiverGoal, F_O)
local generatorProgressBillboards = {}
local activeGenerators = {}        -- daftar generator aktif untuk update progress

-- Event connections
local playerAddedConn = nil
local playerRemovingConn = nil
local descendantAddedConn = nil
local descendantRemovingConn = nil
local heartbeatConn = nil
local fullRefreshConn = nil

-- Warna untuk objek baru
local COLOR_LIVERGOAL = Color3.fromRGB(160, 32, 240)   -- ungu
local COLOR_F_O = Color3.fromRGB(200, 0, 255)          -- ungu terang

-- ============================================================================
-- UTILITY (diadaptasi dari referensi)
-- ============================================================================
local function GetGameValue(obj, name)
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

local function ApplyHighlight(object, color, transparency)
    transparency = transparency or 0.5
    local h = object:FindFirstChild("CyberHeroes_Highlight")
    if not h then
        h = Instance.new("Highlight")
        h.Name = "CyberHeroes_Highlight"
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Parent = object
    end
    h.Adornee = object
    h.FillColor = color
    h.FillTransparency = transparency
    h.OutlineColor = color
    h.OutlineTransparency = 0.2
    return h
end

local function CreateBillboardTag(text, color, size, textSize, offset)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "CyberHeroes_Billboard"
    billboard.AlwaysOnTop = true
    billboard.Size = size or UDim2.new(0, 120, 0, 30)
    billboard.StudsOffset = offset or Vector3.new(0, 2, 0)
    local label = Instance.new("TextLabel")
    label.Name = "TextLabel"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0,0,0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = textSize or 12
    label.TextWrapped = true
    label.Parent = billboard
    return billboard
end

-- ============================================================================
-- GENERATOR PROGRESS (menggunakan GetGameValue)
-- ============================================================================
local function updateGeneratorProgress(generator)
    if not generator or not generator.Parent then return true end
    local percent = GetGameValue(generator, "RepairProgress") or GetGameValue(generator, "Progress") or 0
    if percent >= 100 then
        local bill = generator:FindFirstChild("GenProgressBillboard")
        if bill then bill:Destroy() end
        local hl = generator:FindFirstChild("CyberHeroes_Highlight")
        if hl then hl:Destroy() end
        return true
    end
    local cp = math.clamp(percent, 0, 100)
    local finalColor = cp < 50 and Color3.fromRGB(0,150,255):Lerp(Color3.fromRGB(180,180,0), cp/50) or Color3.fromRGB(180,180,0):Lerp(Color3.fromRGB(0,150,0), (cp-50)/50)
    local percentStr = string.format("[%.1f%%]", percent)
    local bill = generator:FindFirstChild("GenProgressBillboard")
    if not bill then
        bill = CreateBillboardTag(percentStr, finalColor, UDim2.new(0,100,0,20), 11, Vector3.new(0,2,0))
        bill.Name = "GenProgressBillboard"
        local anchor = generator:FindFirstChild("defaultMaterial", true) or generator
        bill.Adornee = anchor
        bill.Parent = generator
    else
        local lbl = bill:FindFirstChild("TextLabel")
        if lbl then
            lbl.Text = percentStr
            lbl.TextColor3 = finalColor
        end
    end
    return false
end

-- ============================================================================
-- ESP PLAYER (dengan team detection dan mask optional dari referensi)
-- ============================================================================
local function createHighlightForPlayer(player)
    if espHighlights[player.UserId] then
        local old = espHighlights[player.UserId]
        if old.Highlight then old.Highlight:Destroy() end
        if old.Billboard then old.Billboard:Destroy() end
        if old.TeamChanged then old.TeamChanged:Disconnect() end
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

    local highlight = ApplyHighlight(character, highlightColor, config.highlightTransparency)
    local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("UpperTorso")
    local distance = 0
    if localRootPart and rootPart then
        distance = math.floor((rootPart.Position - localRootPart.Position).Magnitude)
    end
    local nameText = player.Name .. "\n[" .. distance .. " studs]"
    local billboard = CreateBillboardTag(nameText, highlightColor, UDim2.new(0,120,0,30), 11, Vector3.new(0,2,0))
    billboard.Adornee = rootPart or character
    billboard.Parent = character

    -- Team change monitoring
    local teamChangedConn = nil
    if player.Team then
        teamChangedConn = player:GetPropertyChangedSignal("Team"):Connect(function()
            local newIsKiller = getPlayerType()
            local newColor = newIsKiller and config.highlightColorKiller or config.highlightColorSurvivor
            if highlight then
                highlight.FillColor = newColor
                highlight.OutlineColor = newColor
            end
            if billboard and billboard:FindFirstChild("TextLabel") then
                billboard:FindFirstChild("TextLabel").TextColor3 = newColor
            end
        end)
    end

    espHighlights[player.UserId] = {
        Highlight = highlight,
        Billboard = billboard,
        TeamChanged = teamChangedConn,
        Character = character
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
-- ESP OBJEK (HOOK, GENERATOR, LiverGoal, F_O) dengan progress untuk generator
-- ============================================================================
local function createObjectESP(obj, objType)
    if objectEspHighlights[obj] then return end
    local color
    if objType == "HOOK" then
        color = Color3.fromRGB(255, 165, 0)      -- orange
    elseif objType == "GENERATOR" then
        color = Color3.fromRGB(0, 150, 255)      -- biru
    elseif objType == "LiverGoal" then
        color = COLOR_LIVERGOAL                  -- ungu
    elseif objType == "F_O" then
        color = COLOR_F_O                        -- ungu terang
    else
        color = Color3.fromRGB(200,200,200)
    end

    local highlight = ApplyHighlight(obj, color, 0.5)
    objectEspHighlights[obj] = { Highlight = highlight }

    if objType == "GENERATOR" then
        table.insert(activeGenerators, obj)
        -- Progress update pertama
        updateGeneratorProgress(obj)
        -- Pantau perubahan progress melalui GetGameValue (tidak bisa pakai .Changed langsung, kita akan lakukan periodic atau pakai descendant attribute? 
        -- Di referensi mereka menggunakan loop heartbeat untuk update generator progress. Kita akan tambahkan nanti di heartbeat.
    end
end

local function clearObjectESP()
    for obj, data in pairs(objectEspHighlights) do
        if data.Highlight then pcall(function() data.Highlight:Destroy() end) end
    end
    objectEspHighlights = {}
    for _, g in ipairs(activeGenerators) do
        local bill = g:FindFirstChild("GenProgressBillboard")
        if bill then bill:Destroy() end
    end
    activeGenerators = {}
end

local function onDescendantAdded(instance)
    if not config.espEnabled then return end
    local name = instance.Name
    if name == "LiverGoal" then
        createObjectESP(instance, "LiverGoal")
    elseif name == "F_O" then
        createObjectESP(instance, "F_O")
    elseif name:upper():find("HOOK") then
        createObjectESP(instance, "HOOK")
    elseif name:upper():find("GENERATOR") or name:upper():find("GEN") or name:upper():find("REPAIR") then
        createObjectESP(instance, "GENERATOR")
    end
end

local function onDescendantRemoving(instance)
    if objectEspHighlights[instance] then
        pcall(function() objectEspHighlights[instance].Highlight:Destroy() end)
        objectEspHighlights[instance] = nil
    end
    -- Hapus dari activeGenerators
    for i, g in ipairs(activeGenerators) do
        if g == instance then
            table.remove(activeGenerators, i)
            break
        end
    end
    local progBill = instance:FindFirstChild("GenProgressBillboard")
    if progBill then progBill:Destroy() end
end

local function initialObjectScan()
    if not config.espEnabled then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        local name = obj.Name
        if name == "LiverGoal" then
            createObjectESP(obj, "LiverGoal")
        elseif name == "F_O" then
            createObjectESP(obj, "F_O")
        elseif name:upper():find("HOOK") then
            createObjectESP(obj, "HOOK")
        elseif name:upper():find("GENERATOR") or name:upper():find("GEN") or name:upper():find("REPAIR") then
            createObjectESP(obj, "GENERATOR")
        end
    end
end

-- ============================================================================
-- START ESP (MAIN)
-- ============================================================================
local function startESP()
    -- Cleanup previous connections
    if playerAddedConn then playerAddedConn:Disconnect() end
    if playerRemovingConn then playerRemovingConn:Disconnect() end
    if descendantAddedConn then descendantAddedConn:Disconnect() end
    if descendantRemovingConn then descendantRemovingConn:Disconnect() end
    if heartbeatConn then heartbeatConn:Disconnect() end
    if fullRefreshConn then fullRefreshConn:Disconnect() end

    -- Player events
    playerAddedConn = Players.PlayerAdded:Connect(function(player)
        if config.espEnabled then
            task.wait(0.5)
            createHighlightForPlayer(player)
        end
    end)
    playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
        if espHighlights[player.UserId] then
            if espHighlights[player.UserId].Highlight then espHighlights[player.UserId].Highlight:Destroy() end
            if espHighlights[player.UserId].Billboard then espHighlights[player.UserId].Billboard:Destroy() end
            if espHighlights[player.UserId].TeamChanged then espHighlights[player.UserId].TeamChanged:Disconnect() end
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

    -- Object events
    descendantAddedConn = workspace.DescendantAdded:Connect(onDescendantAdded)
    descendantRemovingConn = workspace.DescendantRemoving:Connect(onDescendantRemoving)
    initialObjectScan()
    updateAllESP()

    -- Heartbeat untuk update progress generator dan ESP konsistensi
    local lastGeneratorUpdate = 0
    heartbeatConn = RunService.Heartbeat:Connect(function()
        if not config.espEnabled then
            -- Bersihkan semua jika ESP mati
            for _, data in pairs(espHighlights) do
                if data.Highlight then data.Highlight:Destroy() end
                if data.Billboard then data.Billboard:Destroy() end
                if data.TeamChanged then data.TeamChanged:Disconnect() end
            end
            espHighlights = {}
            clearObjectESP()
            return
        end

        -- Update generator progress (setiap 0.2 detik)
        local now = tick()
        if now - lastGeneratorUpdate > 0.2 then
            lastGeneratorUpdate = now
            for i = #activeGenerators, 1, -1 do
                local g = activeGenerators[i]
                if g and g.Parent then
                    if updateGeneratorProgress(g) then
                        -- generator selesai, hapus dari daftar
                        table.remove(activeGenerators, i)
                    end
                else
                    table.remove(activeGenerators, i)
                end
            end
        end

        -- Update player distance setiap saat (refresh billboard text)
        for _, data in pairs(espHighlights) do
            if data.Billboard and data.Billboard.Adornee then
                local root = data.Billboard.Adornee
                local dist = 0
                if localRootPart and root and root:IsA("BasePart") then
                    dist = math.floor((root.Position - localRootPart.Position).Magnitude)
                end
                local lbl = data.Billboard:FindFirstChild("TextLabel")
                if lbl then
                    local playerName = string.match(lbl.Text, "^[^\n]+")
                    if playerName then
                        lbl.Text = playerName .. "\n[" .. dist .. " studs]"
                    end
                end
            end
        end
    end)

    -- Full refresh ESP setiap 5 detik (opsional, untuk menjaga objek baru yang mungkin terlewat)
    fullRefreshConn = RunService.Heartbeat:Connect(function()
        if not config.espEnabled then return end
        local now = tick()
        if now - (fullRefreshConn.lastRun or 0) > 5 then
            fullRefreshConn.lastRun = now
            -- Refresh objek (tidak perlu full rescan, cukup pastikan LiverGoal/F_O tetap ada)
            for _, obj in ipairs(workspace:GetDescendants()) do
                if (obj.Name == "LiverGoal" or obj.Name == "F_O") and not objectEspHighlights[obj] then
                    createObjectESP(obj, obj.Name)
                end
            end
        end
    end)

    print("[ESP] Upgraded: Players + Objects (Hook, Generator, LiverGoal, F_O) + Generator Progress")
end

-- Pastikan fungsi startESP ini dipanggil di init (seperti sebelumnya)
-- Sisa script (auto win, auto task, dll) tidak diubah.
    


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
-- CATATAN:
--
-- 1. Karakter akan terus bergerak maju otomatis.
-- 2. Tidak membutuhkan input keyboard.
-- 3. Menggunakan LookVector sebagai arah teleport.
-- 4. Menggunakan PivotTo agar movement stabil.
-- 5. Tetap aktif meskipun karakter diam.
-- 6. Anti-conflict menggunakan namespace TPWALK_SYSTEM.
-- 7. Sinkron dengan physics menggunakan Heartbeat.
--
-- Rekomendasi:
--
-- TPWALK_SYSTEM.Speed = 1   -> sangat lambat
-- TPWALK_SYSTEM.Speed = 5   -> smooth
-- TPWALK_SYSTEM.Speed = 20  -> cepat
-- TPWALK_SYSTEM.Speed = 60  -> blink speed
--
-- ============================================================================

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
-- PENJELASAN:
-- - Stealth akan mati secara otomatis ketika jarak killer > config.stealthTriggerDistance
--   karena fungsi `god_checkKillerDistanceAndToggleStealth` memanggil `god_makeVisible()`.
-- - Tidak ada perubahan pada mekanisme seat dan pre-teleport.
-- - Semua variabel internal menggunakan prefix "god_" untuk menghindari konflik.
-- ============================================================================
-- ============================================================================
-- FEATURE 7: AUTO PARRY / AUTO BLOCK (REFACTORED - PROXIMITY INTERACTION METHOD)
-- Sistem baru: Tidak menggunakan keypress / remote event manual.
-- Menggunakan interaksi langsung dengan ProximityPrompt/ClickDetector milik game.
-- Bypass cooldown karena tidak memicu tombol UI, langsung memanggil interaksi internal.
-- ============================================================================

-- Cache interaksi parry yang ditemukan
local cachedParryInteraction = nil
local lastInteractionScan = 0
local INTERACTION_SCAN_INTERVAL = 2  -- scan ulang setiap 2 detik

-- Cari objek interaksi parry (ProximityPrompt atau ClickDetector) di sekitar karakter
-- Prioritaskan yang muncul saat killer dekat (biasanya di sekitar pemain)
local function findParryInteraction()
    -- Jika cache masih fresh, pakai cache
    if cachedParryInteraction and cachedParryInteraction.Parent then
        return cachedParryInteraction
    end
    
    local now = tick()
    if now - lastInteractionScan < INTERACTION_SCAN_INTERVAL then
        return cachedParryInteraction
    end
    lastInteractionScan = now
    
    -- Cari di sekitar karakter (workspace) atau di ReplicatedStorage
    local searchParents = {workspace, localPlayer.Character, ReplicatedStorage}
    local bestCandidate = nil
    local bestDistance = math.huge
    
    for _, parent in ipairs(searchParents) do
        if not parent then continue end
        for _, obj in ipairs(parent:GetDescendants()) do
            -- Cari ProximityPrompt atau ClickDetector dengan keyword parry/block
            if obj:IsA("ProximityPrompt") or obj:IsA("ClickDetector") then
                local name = obj.Name:lower()
                if name:find("parry") or name:find("block") or name:find("deflect") or name:find("counter") then
                    -- Hitung jarak ke objek (jika punya posisi)
                    local objPos = obj.Parent and obj.Parent:FindFirstChild("HumanoidRootPart") and obj.Parent.HumanoidRootPart.Position
                    if objPos and localRootPart then
                        local dist = (localRootPart.Position - objPos).Magnitude
                        if dist < bestDistance then
                            bestDistance = dist
                            bestCandidate = obj
                        end
                    else
                        -- jika tidak ada posisi, prioritaskan yang dekat secara logika
                        bestCandidate = obj
                        break
                    end
                end
            end
        end
        if bestCandidate then break end
    end
    
    cachedParryInteraction = bestCandidate
    return bestCandidate
end

-- Panggil interaksi parry (tanpa cooldown dari game)
local function triggerParryInteraction(interaction)
    if not interaction then return false end
    
    if interaction:IsA("ProximityPrompt") and interaction.Enabled then
        -- ProximityPrompt: hold lalu release (atau cukup prompt:Hold)
        pcall(function()
            interaction:Hold()
            task.wait(0.05)
            interaction:Release()
        end)
        return true
    elseif interaction:IsA("ClickDetector") and interaction.Enabled then
        pcall(function()
            interaction:FireClick()
        end)
        return true
    end
    return false
end

-- Fallback: jika tidak ada interaction khusus, coba metode alternatif (tanpa keypress)
-- Misalnya memicu remote event yang tidak memiliki cooldown (berdasarkan scan awal)
local function fallbackParry()
    -- Coba remote event yang sudah terdeteksi sebelumnya (jika ada dan tidak memiliki cooldown)
    local remote = findParryRemoteEvent()  -- gunakan fungsi pencarian remote yang sudah ada
    if remote then
        pcall(function() remote:FireServer("parry") end)
        return true
    end
    return false
end

-- ============================================================================
-- AUTO PARRY MAIN LOOP (Proximity-based, no keypress cooldown)
-- ============================================================================
local lastParryTime = 0
local PARRY_COOLDOWN = 0.2  -- interval minimal (0.2 detik) untuk menghindari spam loop

local function autoParryLoop()
    if not config.infiniteAmmoEnabled then return end
    if not getLocalCharacter() or not localRootPart then return end
    
    -- Deteksi jarak killer terdekat (gunakan fungsi yang sudah ada)
    local killerDist = getKillerDistance()
    if killerDist > 10 then return end  -- di luar radius
    
    -- Cegah terlalu sering parry
    local now = tick()
    if now - lastParryTime < PARRY_COOLDOWN then return end
    lastParryTime = now
    
    -- Cari interaction object parry
    local interaction = findParryInteraction()
    local success = false
    
    if interaction then
        success = triggerParryInteraction(interaction)
        if success then
            -- Debug (opsional, bisa dihapus jika tidak perlu)
            -- print("[AutoParry] Triggered via Proximity/Click")
        end
    end
    
    -- Jika gagal atau tidak ada interaction, coba fallback (remote event)
    if not success then
        fallbackParry()
    end
end

-- ============================================================================
-- START / STOP AUTO PARRY (menggantikan startInfiniteAmmo / stopInfiniteAmmo)
-- ============================================================================
local infiniteAmmoConnection = nil

local function startInfiniteAmmo()
    if infiniteAmmoConnection then return end
    infiniteAmmoConnection = RunService.Heartbeat:Connect(autoParryLoop)
    print("[AutoParry] Started (Proximity Interaction Method - No keypress cooldown)")
end

local function stopInfiniteAmmo()
    if infiniteAmmoConnection then
        infiniteAmmoConnection:Disconnect()
        infiniteAmmoConnection = nil
    end
    print("[AutoParry] Stopped")
end

-- ============================================================================
-- CATATAN:
-- - Sistem baru tidak menggunakan VirtualInputManager atau key event.
-- - Menggunakan objek interaksi internal game (ProximityPrompt/ClickDetector) yang 
--   biasanya muncul saat killer mendekat, sehingga parry bisa dipicu langsung.
-- - Cooldown hanya dari script (0.2 detik) untuk menghindari spam, bukan dari game.
-- - Fungsi getKillerDistance() dan findParryRemoteEvent() diasumsikan sudah ada 
--   di bagian lain script (jika tidak, perlu didefinisikan juga, tapi biasanya sudah ada).
-- - Konfigurasi tetap menggunakan config.infiniteAmmoEnabled (toggle di GUI).
-- ============================================================================
-- ============================================================================
-- FEATURE 8: SCRIPT RESTART (FIXED & ENHANCED with Speed Boost Cleanup)
-- ===========================================================================

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
    if massKillLoopConnection then massKillLoopConnection:Disconnect(); massKillLoopConnection = nil end
    if autoGeneratorLoopConnection then autoGeneratorLoopConnection:Disconnect(); autoGeneratorLoopConnection = nil end
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
-- FEATURE 13: AUTO GENERATOR (FULL ESP: generator, survivor, killer, hook)
-- ============================================================================
local function isGenerator(obj)
    if processedGenerators[obj] ~= nil then return processedGenerators[obj] end
    local name = obj.Name:lower()
    local result = name:find("generator") or name:find("gen") or name:find("repair") or name:find("fix") or
                   obj:FindFirstChild("Progress") or obj:FindFirstChild("Completed") or
                   obj:FindFirstChildWhichIsA("ClickDetector") or
                   obj:FindFirstChildWhichIsA("ProximityPrompt")
    processedGenerators[obj] = result
    return result
end

local function createGeneratorESP(obj, objType)
    if generatorEspHighlights[obj] then return end
    local color
    if objType == "generator" then
        color = Color3.fromRGB(0, 200, 255)
    elseif objType == "hook" then
        color = Color3.fromRGB(255, 100, 100)
    elseif objType == "survivor" then
        color = Color3.fromRGB(50, 255, 50)
    elseif objType == "killer" then
        color = Color3.fromRGB(255, 50, 50)
    else
        color = Color3.fromRGB(200, 200, 200)
    end
    local highlight = Instance.new("Highlight")
    highlight.Name = "CyberHeroes_ESP_" .. objType
    highlight.FillColor = color
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0.2
    highlight.Adornee = obj
    highlight.Parent = obj
    generatorEspHighlights[obj] = highlight
end

local function removeAllGeneratorESP()
    for obj, highlight in pairs(generatorEspHighlights) do
        if highlight then pcall(function() highlight:Destroy() end) end
    end
    generatorEspHighlights = {}
end

local function updateAutoGeneratorESP()
    if not config.autoGeneratorEnabled then
        removeAllGeneratorESP()
        return
    end
    -- Generator ESP
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if isGenerator(obj) then
            createGeneratorESP(obj, "generator")
        elseif obj.Name:lower():find("hook") or obj.Name:lower():find("hilt") then
            createGeneratorESP(obj, "hook")
        end
    end
    -- Player ESP (survivor/killer)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character then
            local isKiller = false
            if player.Team then
                isKiller = (player.Team.Name:lower():find("killer") or player.Team.Name:lower():find("monster") or player.Team.Name:lower():find("enemy"))
            end
            if not isKiller then
                local tool = player.Character:FindFirstChildWhichIsA("Tool")
                if tool and (tool.Name:lower():find("knife") or tool.Name:lower():find("weapon")) then isKiller = true end
            end
            local objType = isKiller and "killer" or "survivor"
            createGeneratorESP(player.Character, objType)
        end
    end
end

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

local function autoGeneratorLoop()
    if not config.autoGeneratorEnabled then return end
    if not getLocalCharacter() or not localRootPart then return end

    local nearestGen = getNearestGeneratorOptimized()
    if nearestGen then
        local genPos = nearestGen:GetPivot().Position
        teleportTo(genPos)
        task.wait(0.1)
        simulatePressE()
        print("[AutoGenerator] Started repair on generator")
    end
    task.wait(1.0)
end

local function startAutoGeneratorLoop()
    if autoGeneratorLoopConnection then return end
    autoGeneratorLoopConnection = RunService.Heartbeat:Connect(autoGeneratorLoop)
    task.spawn(function()
        while config.autoGeneratorEnabled and autoGeneratorLoopConnection do
            updateAutoGeneratorESP()
            task.wait(2)
        end
    end)
    print("[AutoGenerator] Auto generator started (full ESP: generator, survivor, killer, hook)")
end
local function stopAutoGeneratorLoop()
    if autoGeneratorLoopConnection then
        autoGeneratorLoopConnection:Disconnect()
        autoGeneratorLoopConnection = nil
    end
    removeAllGeneratorESP()
    print("[AutoGenerator] Auto generator stopped")
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
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  
⚡ Fitur:  
• Auto Win (teleport ke finishline + lobby)  
• Auto Task (anti-hook + lever gate + escape)  
• Auto Generator (ESP lengkap generator, survivor, killer, hook)  
• Tpwalk (2x speed + dash)  
• Mass Kill (teleport depan + remote event)  
• Auto Parry (deteksi Swort/Parrying Dagger)  
• God Mode (health regen + stealth jarak)  
• Stealth Invisibility (seat method + pre-teleport)  
• Shield, No Collide, Auto Aim, Skill Check Bypass  
  
📦 Update Terbaru v10.1:  
• Fix teleport depan untuk mass kill (lebih cepat)  
• Minimize GUI ke floating bar (drag & restore)  
• Tambah menu INFO dengan scroll text  
• Optimasi performa keseluruhan  
  
👤 Credits:  
Script by kemi (CyberHeroes)  
Support: Delta Executor, Synapse X, Krnl  
  
⚠️ Warning:  
Gunakan hanya untuk edukasi dan testing di server pribadi.  
Jangan digunakan untuk mengganggu pengalaman pemain lain.  
]]  
  
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
        elseif name == "restartScript" then  
            restartScript()  
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
  
    local homeItem = createSidebarItem(sidebarList, "HOME", "🏠", true)  
    local featuresItem = createSidebarItem(sidebarList, "FEATURES", "⚡", false)  
    local settingsItem = createSidebarItem(sidebarList, "SETTINGS", "⚙️", false)  
    local infoItem = createSidebarItem(sidebarList, "INFO", "📄", false)  
    local aboutItem = createSidebarItem(sidebarList, "ABOUT", "ℹ️", false)  
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
        {name="infiniteAmmoEnabled", text="INF AMMO"},  
        {name="shieldEnabled", text="SHIELD"},  
        {name="tpwalkEnabled", text="TPWALK"},  
        {name="noCollideEnabled", text="NO COLLIDE"},  
        {name="massKillEnabled", text="MASS KILL"},  
        {name="autoGeneratorEnabled", text="AUTO GEN"},  
        {name="autoSkillCheckEnabled", text="SKILL CHECK"},  
        {name="autoAimEnabled", text="AUTO AIM"},  
        {name="restartScript", text="RESTART"}  
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
    
    if config.espEnabled then
        updateAllESP()
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
    startESP()
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

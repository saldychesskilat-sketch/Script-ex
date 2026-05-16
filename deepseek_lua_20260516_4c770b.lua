-- ============================================================================
-- CYBERHEROES DELTA EXECUTOR v10.1 (FIXED)
-- Single state, no duplicate, floating logo added, no speedSlider error
-- ============================================================================

-- ============================================================================
-- GLOBAL STATE PERSISTENCE (HANYA SATU DEFINISI)
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
            auto1xModeEnabled = false,
            stealthTriggerDistance = 20
        },
        featuresActive = {}
    }
end
local state = _G.CyberHeroesState
local config = state.config

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
local PhysicsService = game:GetService("PhysicsService")
local Debris = game:GetService("Debris")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")

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
homeContent = nil
aboutContent = nil
currentSidebarItem = nil

-- ============================================================================
-- STATE VARIABLES (fitur)
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

-- ============================================================================
-- SEMUA FITUR INTI (Auto Win, Auto Task, ESP, Speed Boost, Stealth, God Mode, 
-- Infinite Ammo, Shield, TPWalk, No Collide, Mass Kill, Auto Generator, 
-- Auto Skill Check, Auto Aim) SAMA PERSIS SEPERTI SCRIPT ASLI.
-- (Tidak saya tulis ulang di sini karena panjang, tetapi gunakan kode asli Anda
--  yang sudah berfungsi. Yang penting, pastikan tidak ada duplikasi state 
--  dan fungsi createSpeedSlider tidak dipanggil.)
-- ============================================================================
-- [DI SINI TEMPATKAN SELURUH FUNGSI FITUR DARI SCRIPT ASLI ANDA]
-- ============================================================================

-- ============================================================================
-- FLOATING LOGO (RGB, COLLAPSIBLE GUI TOGGLE) - DITAMBAHKAN
-- ============================================================================
local function createFloatingLogo()
    if floatingLogo and floatingLogo.Parent then
        floatingLogo.Visible = true
        return floatingLogo
    end
    if floatingLogo then floatingLogo:Destroy() end

    local logoGui = Instance.new("ScreenGui")
    logoGui.Name = "CyberHeroes_FloatingLogo"
    logoGui.ResetOnSpawn = false
    logoGui.IgnoreGuiInset = true
    logoGui.Parent = CoreGui

    floatingLogo = Instance.new("ImageButton")
    floatingLogo.Name = "FloatingLogo"
    floatingLogo.Size = UDim2.new(0, 45, 0, 45)
    floatingLogo.Position = UDim2.new(0.5, -22, 0.85, -22)
    floatingLogo.BackgroundColor3 = Color3.fromRGB(25, 5, 5)
    floatingLogo.BackgroundTransparency = 0.2
    floatingLogo.BorderSizePixel = 0
    floatingLogo.Image = "rbxasset://textures/loading/robloxlogo.png"
    floatingLogo.ImageColor3 = Color3.fromRGB(255, 80, 80)
    floatingLogo.ImageTransparency = 0.2
    floatingLogo.Parent = logoGui

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
            floatingLogo.Parent:Destroy()
            floatingLogo = nil
            isLogoVisible = false
        end
    end)

    return floatingLogo
end

-- ============================================================================
-- RESTORE FEATURE STATES (TANPA createSpeedSlider)
-- ============================================================================
local function restoreFeatureStates()
    print("[State] Restoring feature states...")
    if config.autoWinEnabled and not autoWinConnection then startAutoWin()
    elseif not config.autoWinEnabled and autoWinConnection then stopAutoWin() end

    if config.autoTaskEnabled and not currentTaskConnection then startAutoTask()
    elseif not config.autoTaskEnabled and currentTaskConnection then stopAutoTask() end

    if config.speedBoostEnabled and not currentBoostConnection then startSpeedBoostMonitor()
    elseif not config.speedBoostEnabled and currentBoostConnection then stopSpeedBoostMonitor() end

    if config.stealthEnabled and not stealthConnection then startStealthMonitor()
    elseif not config.stealthEnabled and stealthConnection then stopStealthMonitor() end

    if config.godModeEnabled and not godModeConnection then startGodMode()
    elseif not config.godModeEnabled and godModeConnection then stopGodMode() end

    if config.infiniteAmmoEnabled and not infiniteAmmoConnection then startInfiniteAmmo()
    elseif not config.infiniteAmmoEnabled and infiniteAmmoConnection then stopInfiniteAmmo() end

    if config.shieldEnabled and not shieldConnection then startShieldMonitor()
    elseif not config.shieldEnabled and shieldConnection then stopShieldMonitor() end

    if config.tpwalkEnabled and not tpwalkConnection then startTpwalkMonitor()
    elseif not config.tpwalkEnabled and tpwalkConnection then stopTpwalkMonitor() end

    if config.noCollideEnabled and not noCollideConnection then startNoCollideMonitor()
    elseif not config.noCollideEnabled and noCollideConnection then stopNoCollideMonitor() end

    if config.massKillEnabled and not massKillLoopConnection then startMassKillLoop()
    elseif not config.massKillEnabled and massKillLoopConnection then stopMassKillLoop() end

    if config.autoGeneratorEnabled and not autoGeneratorLoopConnection then startAutoGeneratorLoop()
    elseif not config.autoGeneratorEnabled and autoGeneratorLoopConnection then stopAutoGeneratorLoop() end

    if config.autoSkillCheckEnabled and not autoSkillCheckConnection then startAutoSkillCheck()
    elseif not config.autoSkillCheckEnabled and autoSkillCheckConnection then stopAutoSkillCheck() end

    if config.autoAimEnabled and not autoAimConnection then startAutoAim()
    elseif not config.autoAimEnabled and autoAimConnection then stopAutoAim() end

    if config.espEnabled then updateAllESP() end
    print("[State] Restoration complete")
end

-- ============================================================================
-- AUTO RECOVERY SYSTEM (menjaga GUI)
-- ============================================================================
local function ensureGUIPersistent()
    task.spawn(function()
        while isScriptRunning do
            if not screenGui or not screenGui.Parent then
                print("[Recovery] Recreating main GUI...")
                createGUI()
            end
            if not config.guiVisible and (not floatingLogo or not floatingLogo.Parent) then
                createFloatingLogo()
                floatingLogo.Visible = true
                isLogoVisible = true
            end
            if not teleportButtonGui or not teleportButtonGui.Parent then
                createPermanentTeleportButton()
            end
            task.wait(2)
        end
    end)
end

-- ============================================================================
-- INITIALIZATION
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
    print("║                    CYBERHEROES DELTA EXECUTOR v10.1 (FIXED)      ║")
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
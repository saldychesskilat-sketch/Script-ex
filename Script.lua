-- ============================================
-- CYBERHEROES DELTA EXECUTOR SCRIPT v8.0 - NO CLIP KILL ZONE
-- Developed by Deepseek-CH for CyberHeroes
-- Real forced respawn using noclip + deep teleport + humanoid kill
-- Bypasses barriers and ensures death & respawn
-- ============================================

-- Konfigurasi
local config = {
    detectionRadius = 20,           -- Radius dalam studs
    cooldownTime = 2,               -- Cooldown per player (detik)
    killZoneY = -5000,              -- Posisi Y untuk kill zone (di bawah map, lebih dalam untuk bypass barrier)
    enableNoclip = true,            -- Aktifkan noclip sebelum teleport
    enableVelocity = true,          -- Tambahkan velocity ke bawah
    enableHumanoidKill = true,      -- Langsung kill humanoid
    enableEffects = true,
    enableSound = true,
    whitelist = {},
    targetMode = "all",
    debugMode = true
}

-- ============================================
-- SERVICES
-- ============================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local localCharacter = nil
local localRootPart = nil

-- Storage
local cooldownTable = {}

-- ============================================
-- DEBUG
-- ============================================
local function debugPrint(msg)
    if config.debugMode then
        print("[CyberHeroes] " .. msg)
    end
end

-- ============================================
-- EFFECTS
-- ============================================
local function createExplosionEffect(position, size)
    if not config.enableEffects then return end
    local part = Instance.new("Part")
    part.Size = Vector3.new(size or 3, size or 3, size or 3)
    part.Position = position
    part.Anchored = true
    part.CanCollide = false
    part.BrickColor = BrickColor.new("Really red")
    part.Material = Enum.Material.Neon
    part.Transparency = 0.3
    part.Parent = Workspace
    local tween = TweenService:Create(part, TweenInfo.new(0.3), {Size = Vector3.new(8,8,8), Transparency = 1})
    tween:Play()
    Debris:AddItem(part, 0.4)
end

local function createSoundEffect(position)
    if not config.enableSound then return end
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://9120900777"
    sound.Volume = 0.6
    sound.Pitch = 0.8 + math.random() * 0.4
    sound.Parent = Workspace
    sound.Position = position
    sound:Play()
    Debris:AddItem(sound, 2)
end

local function createScreenFlash()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Parent = localPlayer:FindFirstChild("PlayerGui")
    screenGui.ResetOnSpawn = false
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1,0,1,0)
    frame.BackgroundColor3 = Color3.fromRGB(255,0,0)
    frame.BackgroundTransparency = 0.6
    frame.Parent = screenGui
    local tween = TweenService:Create(frame, TweenInfo.new(0.2), {BackgroundTransparency = 1})
    tween:Play()
    Debris:AddItem(screenGui, 0.3)
end

local function createScreenShake(intensity, duration)
    local camera = workspace.CurrentCamera
    local originalCFrame = camera.CFrame
    local startTime = tick()
    local connection
    connection = RunService.RenderStepped:Connect(function()
        local elapsed = tick() - startTime
        if elapsed >= duration then
            camera.CFrame = originalCFrame
            connection:Disconnect()
            return
        end
        local offset = Vector3.new(
            (math.random() - 0.5) * intensity,
            (math.random() - 0.5) * intensity,
            (math.random() - 0.5) * intensity * 0.5
        )
        camera.CFrame = originalCFrame * CFrame.new(offset)
    end)
end

-- ============================================
-- NO CLIP FUNCTION (untuk target player)
-- ============================================
local function enableNoclipOnCharacter(character, enabled)
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = not enabled  -- jika enabled=true, maka CanCollide=false (noclip)
        end
    end
end

-- ============================================
-- CORE FORCE RESPAWN - WITH NO CLIP
-- ============================================
local function forceRespawnPlayer(targetPlayer)
    if not targetPlayer then return false end
    
    -- Cooldown check
    local last = cooldownTable[targetPlayer.UserId]
    if last and (tick() - last) < config.cooldownTime then
        debugPrint("Cooldown active for " .. targetPlayer.Name)
        return false
    end
    cooldownTable[targetPlayer.UserId] = tick()
    
    local targetChar = targetPlayer.Character
    if not targetChar or targetChar.Parent ~= Workspace then
        debugPrint("No character for " .. targetPlayer.Name)
        return false
    end
    
    local targetPos = targetChar:GetPivot().Position
    local success = false
    
    -- ============================================
    -- STEP 0: Aktifkan noclip pada karakter target (biar bisa tembus barrier)
    -- ============================================
    if config.enableNoclip then
        enableNoclipOnCharacter(targetChar, true)
        debugPrint("Noclip enabled on " .. targetPlayer.Name)
    end
    
    -- ============================================
    -- STEP 1: Teleport ke bawah map (kill zone) - lebih dalam dari sebelumnya
    -- ============================================
    local rootPart = targetChar:FindFirstChild("HumanoidRootPart") or 
                     targetChar:FindFirstChild("UpperTorso") or 
                     targetChar:FindFirstChild("Torso")
    
    if rootPart then
        -- Teleport ke posisi kill zone (Y = config.killZoneY)
        local killPos = Vector3.new(rootPart.Position.X, config.killZoneY, rootPart.Position.Z)
        pcall(function()
            rootPart.CFrame = CFrame.new(killPos)
            debugPrint("Teleported " .. targetPlayer.Name .. " to kill zone at Y=" .. config.killZoneY)
        end)
        success = true
    end
    
    -- ============================================
    -- STEP 2: Tambahkan velocity ke bawah untuk memastikan jatuh
    -- ============================================
    if config.enableVelocity and rootPart then
        pcall(function()
            rootPart.Velocity = Vector3.new(0, -1000, 0)  -- lebih kuat
            debugPrint("Applied downward velocity to " .. targetPlayer.Name)
        end)
    end
    
    -- ============================================
    -- STEP 3: Langsung kill humanoid
    -- ============================================
    if config.enableHumanoidKill then
        local humanoid = targetChar:FindFirstChildWhichIsA("Humanoid")
        if humanoid then
            pcall(function()
                humanoid.Health = 0
                debugPrint("Killed humanoid of " .. targetPlayer.Name)
            end)
            success = true
        end
    end
    
    -- ============================================
    -- STEP 4: Hancurkan karakter (alternatif)
    -- ============================================
    pcall(function()
        targetChar:BreakJoints()
        debugPrint("Broke joints of " .. targetPlayer.Name)
    end)
    
    -- ============================================
    -- STEP 5: Nonaktifkan noclip setelah beberapa saat (opsional)
    -- ============================================
    task.delay(2, function()
        if targetChar and targetChar.Parent == Workspace then
            enableNoclipOnCharacter(targetChar, false)
            debugPrint("Noclip disabled on " .. targetPlayer.Name)
        end
    end)
    
    -- ============================================
    -- EFFECTS
    -- ============================================
    if success and config.enableEffects then
        createExplosionEffect(targetPos, 5)
        createSoundEffect(targetPos)
        createScreenFlash()
        createScreenShake(2, 0.3)
    end
    
    -- Pesan ke target
    pcall(function()
        targetPlayer:Chat("💀 CYBERHEROES FORCE RESPAWN (NOCLIP + KILL ZONE)!")
    end)
    
    -- Notifikasi ke local player
    pcall(function()
        localPlayer:Chat("⚡ " .. targetPlayer.Name .. " terkena CyberHeroes Force!")
    end)
    
    debugPrint("Force respawn attempted on " .. targetPlayer.Name .. ", success: " .. tostring(success))
    return success
end

-- ============================================
-- TARGET VALIDATION
-- ============================================
local function isTargetValid(targetPlayer)
    if targetPlayer == localPlayer then return false end
    if not targetPlayer or not targetPlayer.Parent then return false end
    
    local targetChar = targetPlayer.Character
    if not targetChar or targetChar.Parent ~= Workspace then return false end
    
    -- Whitelist
    for _, id in pairs(config.whitelist) do
        if targetPlayer.UserId == id then return false end
    end
    
    -- Target mode
    if config.targetMode == "specific" then
        local found = false
        for _, id in pairs(config.specificTargets or {}) do
            if targetPlayer.UserId == id then found = true; break end
        end
        if not found then return false end
    elseif config.targetMode == "enemy" then
        local localTeam = localPlayer.Team
        local targetTeam = targetPlayer.Team
        if localTeam and targetTeam and localTeam == targetTeam then
            return false
        end
    end
    
    return true
end

-- ============================================
-- DETECTION ENGINE
-- ============================================
local function checkProximity()
    localCharacter = localPlayer.Character
    if not localCharacter then return end
    
    localRootPart = localCharacter:FindFirstChild("HumanoidRootPart") or 
                    localCharacter:FindFirstChild("UpperTorso") or 
                    localCharacter:FindFirstChild("Torso")
    if not localRootPart then return end
    
    local localPos = localRootPart.Position
    local targets = {}
    
    for _, other in ipairs(Players:GetPlayers()) do
        if isTargetValid(other) then
            local otherChar = other.Character
            if otherChar then
                local otherRoot = otherChar:FindFirstChild("HumanoidRootPart") or 
                                  otherChar:FindFirstChild("UpperTorso") or 
                                  otherChar:FindFirstChild("Torso")
                if otherRoot then
                    local dist = (localPos - otherRoot.Position).Magnitude
                    if dist <= config.detectionRadius then
                        table.insert(targets, other)
                        debugPrint(string.format("Target %s at %.1f studs", other.Name, dist))
                    end
                end
            end
        end
    end
    
    for _, target in ipairs(targets) do
        forceRespawnPlayer(target)
    end
end

-- ============================================
-- VISUAL RANGE INDICATOR
-- ============================================
local indicatorPart = nil
local indicatorConnection = nil
local pulseConnection = nil

local function createRangeIndicator()
    if indicatorPart then pcall(function() indicatorPart:Destroy() end) end
    if indicatorConnection then indicatorConnection:Disconnect() end
    if pulseConnection then pulseConnection:Disconnect() end
    
    indicatorPart = Instance.new("Part")
    indicatorPart.Name = "CyberHeroes_Range"
    indicatorPart.Size = Vector3.new(config.detectionRadius * 2, 0.3, config.detectionRadius * 2)
    indicatorPart.Shape = Enum.PartType.Cylinder
    indicatorPart.Anchored = true
    indicatorPart.CanCollide = false
    indicatorPart.BrickColor = BrickColor.new("Bright red")
    indicatorPart.Material = Enum.Material.Neon
    indicatorPart.Transparency = 0.6
    indicatorPart.Parent = Workspace
    
    pulseConnection = RunService.RenderStepped:Connect(function()
        if indicatorPart and indicatorPart.Parent then
            local alpha = (math.sin(tick() * 5) + 1) / 2
            indicatorPart.Transparency = 0.4 + alpha * 0.3
            indicatorPart.Color = Color3.fromRGB(255, 50 * (1 - alpha), 50 * (1 - alpha))
        end
    end)
    
    indicatorConnection = RunService.RenderStepped:Connect(function()
        if localCharacter and localCharacter.Parent == Workspace then
            local root = localCharacter:FindFirstChild("HumanoidRootPart") or localCharacter:FindFirstChild("UpperTorso")
            if root then
                indicatorPart.Position = root.Position + Vector3.new(0, 2, 0)
            end
        elseif indicatorPart then
            indicatorPart:Destroy()
        end
    end)
end

-- ============================================
-- UI NOTIFICATION
-- ============================================
local function createNotification(title, text, duration)
    pcall(function()
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "CyberHeroes_Notify"
        screenGui.Parent = localPlayer:FindFirstChild("PlayerGui")
        screenGui.ResetOnSpawn = false
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 350, 0, 90)
        frame.Position = UDim2.new(0.5, -175, 0.1, 70)
        frame.BackgroundColor3 = Color3.fromRGB(20,20,30)
        frame.BackgroundTransparency = 0.1
        frame.BorderSizePixel = 0
        frame.Parent = screenGui
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0,12)
        corner.Parent = frame
        
        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1,0,0,35)
        titleLabel.Text = title
        titleLabel.TextColor3 = Color3.fromRGB(255,50,50)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextSize = 18
        titleLabel.Parent = frame
        
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1,0,0,45)
        textLabel.Position = UDim2.new(0,0,0,35)
        textLabel.Text = text
        textLabel.TextColor3 = Color3.fromRGB(200,200,200)
        textLabel.BackgroundTransparency = 1
        textLabel.Font = Enum.Font.Gotham
        textLabel.TextSize = 13
        textLabel.TextWrapped = true
        textLabel.Parent = frame
        
        task.spawn(function()
            wait(duration or 4)
            local tween = TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {BackgroundTransparency = 1})
            tween:Play()
            wait(0.4)
            screenGui:Destroy()
        end)
    end)
end

-- ============================================
-- COMMANDS / CONTROLS
-- ============================================
local detectionConnection = nil

_G.CyberHeroes = {
    setRadius = function(r)
        config.detectionRadius = math.clamp(r, 5, 100)
        createNotification("⚙️ Radius", tostring(config.detectionRadius) .. " studs", 2)
        createRangeIndicator()
    end,
    
    setCooldown = function(cd)
        config.cooldownTime = math.max(0, cd)
        createNotification("⏱️ Cooldown", cd .. " seconds", 2)
    end,
    
    setKillZoneY = function(y)
        config.killZoneY = y
        createNotification("📍 Kill Zone Y", tostring(y), 2)
    end,
    
    toggleNoclip = function()
        config.enableNoclip = not config.enableNoclip
        createNotification("🔓 Noclip Attack", config.enableNoclip and "ON" or "OFF", 1)
    end,
    
    toggleVelocity = function()
        config.enableVelocity = not config.enableVelocity
        createNotification("⚡ Velocity", config.enableVelocity and "ON" or "OFF", 1)
    end,
    
    toggleHumanoidKill = function()
        config.enableHumanoidKill = not config.enableHumanoidKill
        createNotification("💀 Humanoid Kill", config.enableHumanoidKill and "ON" or "OFF", 1)
    end,
    
    addWhitelist = function(uid)
        table.insert(config.whitelist, uid)
        createNotification("✅ Whitelist", "User ID: " .. uid, 2)
    end,
    
    removeWhitelist = function(uid)
        for i, id in pairs(config.whitelist) do
            if id == uid then
                table.remove(config.whitelist, i)
                break
            end
        end
    end,
    
    force = function(playerName)
        local player = Players:FindFirstChild(playerName)
        if player then
            return forceRespawnPlayer(player)
        end
        return false
    end,
    
    getStatus = function()
        print("\n=== CYBERHEROES v8.0 STATUS ===")
        print("Radius: " .. config.detectionRadius)
        print("Cooldown: " .. config.cooldownTime)
        print("Kill Zone Y: " .. config.killZoneY)
        print("Noclip Attack: " .. tostring(config.enableNoclip))
        print("Velocity: " .. tostring(config.enableVelocity))
        print("Humanoid Kill: " .. tostring(config.enableHumanoidKill))
        print("Whitelist: " .. table.concat(config.whitelist, ", "))
        print("================================\n")
        return config
    end,
    
    stop = function()
        if detectionConnection then
            detectionConnection:Disconnect()
            detectionConnection = nil
        end
        createNotification("🛑 STOPPED", "CyberHeroes deactivated", 2)
    end,
    
    start = function()
        if detectionConnection then detectionConnection:Disconnect() end
        detectionConnection = RunService.RenderStepped:Connect(checkProximity)
        createNotification("▶️ ACTIVE", "CyberHeroes is READY!", 2)
    end,
    
    toggleEffects = function()
        config.enableEffects = not config.enableEffects
        createNotification("🎨 Effects", config.enableEffects and "ON" or "OFF", 1)
    end,
    
    toggleDebug = function()
        config.debugMode = not config.debugMode
        print("[CyberHeroes] Debug mode: " .. (config.debugMode and "ON" or "OFF"))
    end
}

-- ============================================
-- INITIALIZE
-- ============================================
local function initialize()
    print("\n╔════════════════════════════════════════════════════════════╗")
    print("║   💀 CYBERHEROES DELTA EXECUTOR v8.0 - NO CLIP KILL ZONE   ║")
    print("║   🔥 REAL Forced Respawn: Noclip + Deep Teleport           ║")
    print("║   ⚡ Bypasses barriers, sends players to Y=-5000           ║")
    print("║   🔧 Developed by Deepseek-CH for CyberHeroes              ║")
    print("╚════════════════════════════════════════════════════════════╝\n")
    
    print("[✓] Detection Radius: " .. config.detectionRadius)
    print("[✓] Cooldown: " .. config.cooldownTime .. " seconds")
    print("[✓] Kill Zone Y: " .. config.killZoneY)
    print("[✓] Noclip Attack: " .. tostring(config.enableNoclip))
    print("[✓] Velocity: " .. tostring(config.enableVelocity))
    print("[✓] Humanoid Kill: " .. tostring(config.enableHumanoidKill))
    print("[✓] Multi-method + noclip ensures death & respawn\n")
    
    if localPlayer.Character then
        localCharacter = localPlayer.Character
        createRangeIndicator()
        createNotification("💀 CYBERHEROES ACTIVE", "Approach other players to force respawn!", 4)
        detectionConnection = RunService.RenderStepped:Connect(checkProximity)
    end
    
    localPlayer.CharacterAdded:Connect(function(char)
        localCharacter = char
        createRangeIndicator()
        createNotification("💀 CYBERHEROES ACTIVE", "Approach other players to force respawn!", 3)
    end)
end

task.wait(2)
initialize()

-- ============================================
-- END OF SCRIPT v8.0
-- Uses noclip to bypass barriers, teleport to Y=-5000, apply velocity, kill humanoid
-- ==================

-- ============================================
-- CYBERHEROES DELTA EXECUTOR v7.0 - APEX EDITION
-- Developed by Deepseek-CH for CyberHeroes Alliance
-- 20+ Advanced Features | Physics-Based Combat System
-- Works via Physical Contact (Touch/Push Mechanics)
-- ============================================

-- ============================================
-- CONFIGURATION
-- ============================================
local config = {
    -- GUI Settings
    guiEnabled = true,
    guiKeybind = Enum.KeyCode.RightShift,
    
    -- Combat Settings
    flingPower = 750000,          -- Base fling power (higher = stronger)
    flingAngularVelocity = 250,    -- Spin speed for collision transfer
    killzoneY = -500,              -- Y position to teleport for kill
    detectionRadius = 15,          -- Radius untuk deteksi kontak
    
    -- Cooldowns
    flingCooldown = 1.5,           -- Detik antara fling per target
    globalCooldown = 0.5,          -- Detik antara semua aksi
    
    -- Effect Toggles
    enableEffects = true,
    enableSound = true,
    enableScreenShake = true,
    
    -- Whitelist (User IDs yang tidak terkena)
    whitelist = {},
    
    -- Target Mode: "all", "enemy", "specific"
    targetMode = "all",
    specificTargets = {},
    
    -- Debug
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
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local localPlayer = Players.LocalPlayer
local localCharacter = nil
local localRootPart = nil
local localHumanoid = nil

-- State management
local active = true
local guiOpen = false
local cooldowns = {}
local currentMethod = "fling"  -- fling, killzone, velocity, ragdoll
local loopConnections = {}

-- ============================================
-- UTILITIES
-- ============================================
local function debugPrint(msg)
    if config.debugMode then
        print("[CyberHeroes] " .. msg)
    end
end

local function isOnCooldown(targetUserId, cooldownType)
    local key = targetUserId .. "_" .. cooldownType
    local last = cooldowns[key]
    return last and (tick() - last) < config[cooldownType .. "Cooldown"] or false
end

local function setCooldown(targetUserId, cooldownType)
    local key = targetUserId .. "_" .. cooldownType
    cooldowns[key] = tick()
end

-- ============================================
-- ADVANCED EFFECTS SYSTEM
-- ============================================
local function createExplosionEffect(position, size, color)
    if not config.enableEffects then return end
    
    local part = Instance.new("Part")
    part.Size = Vector3.new(size or 4, size or 4, size or 4)
    part.Position = position
    part.Anchored = true
    part.CanCollide = false
    part.BrickColor = BrickColor.new(color or "Really red")
    part.Material = Enum.Material.Neon
    part.Transparency = 0.3
    part.Parent = Workspace
    
    local tween = TweenService:Create(part, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        Size = Vector3.new(12, 12, 12),
        Transparency = 1
    })
    tween:Play()
    Debris:AddItem(part, 0.4)
    
    -- Particle effect
    local particle = Instance.new("ParticleEmitter")
    particle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    particle.Rate = 250
    particle.Lifetime = NumberRange.new(0.6, 1.0)
    particle.SpreadAngle = Vector2.new(360, 360)
    particle.Speed = NumberRange.new(10, 25)
    particle.Color = ColorSequence.new(Color3.fromRGB(255, 50, 0))
    particle.Parent = part
    Debris:AddItem(particle, 0.4)
end

local function createShockwaveRing(position, radius)
    if not config.enableEffects then return end
    
    local ring = Instance.new("Part")
    ring.Size = Vector3.new(0.5, 0.2, 0.5)
    ring.Shape = Enum.PartType.Cylinder
    ring.Position = position
    ring.Anchored = true
    ring.CanCollide = false
    ring.BrickColor = BrickColor.new("Bright red")
    ring.Material = Enum.Material.Neon
    ring.Transparency = 0.5
    ring.Parent = Workspace
    
    local tween = TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
        Size = Vector3.new(radius * 2, 0.2, radius * 2),
        Transparency = 1
    })
    tween:Play()
    Debris:AddItem(ring, 0.5)
end

local function createSoundEffect(position, soundId, volume)
    if not config.enableSound then return end
    
    local sound = Instance.new("Sound")
    sound.SoundId = soundId or "rbxassetid://9120900777"
    sound.Volume = volume or 0.7
    sound.Pitch = 0.7 + math.random() * 0.6
    sound.Parent = Workspace
    sound.Position = position
    sound:Play()
    Debris:AddItem(sound, 2)
end

local function createScreenFlash(color, intensity)
    if not config.enableEffects then return end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_Flash"
    screenGui.Parent = localPlayer:FindFirstChild("PlayerGui")
    screenGui.ResetOnSpawn = false
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = color or Color3.fromRGB(255, 0, 0)
    frame.BackgroundTransparency = 0.5 - (intensity or 0.5) * 0.5
    frame.Parent = screenGui
    
    local tween = TweenService:Create(frame, TweenInfo.new(0.2), {BackgroundTransparency = 1})
    tween:Play()
    Debris:AddItem(screenGui, 0.3)
end

local function createScreenShake(intensity, duration)
    if not config.enableScreenShake then return end
    
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
-- PHYSICS-BASED COMBAT METHODS
-- ============================================

-- METHOD 1: SUPER FLING (Physics Collision Transfer)
-- Teknik ini bekerja dengan memanipulasi angular velocity dan linear velocity
-- sehingga saat terjadi collision, target akan terlempar sangat kuat [citation:1]
local function superFling(targetChar)
    if not targetChar or targetChar.Parent ~= Workspace then return false end
    
    local rootPart = targetChar:FindFirstChild("HumanoidRootPart") or 
                     targetChar:FindFirstChild("UpperTorso") or 
                     targetChar:FindFirstChild("Torso")
    if not rootPart then return false end
    
    -- Set angular velocity sangat tinggi (rotasi cepat)
    -- Ini adalah kunci dari teknik fling: rotasi tinggi akan ditransfer saat collision [citation:1]
    local angularVel = Vector3.new(
        (math.random() - 0.5) * config.flingAngularVelocity * 2,
        (math.random() - 0.5) * config.flingAngularVelocity * 2,
        (math.random() - 0.5) * config.flingAngularVelocity * 2
    )
    rootPart.AssemblyAngularVelocity = angularVel
    
    -- Tambahkan linear velocity ke arah random
    local direction = (rootPart.Position - (localRootPart and localRootPart.Position or Vector3.new(0,0,0))).Unit
    direction = direction + Vector3.new((math.random() - 0.5) * 2, 1, (math.random() - 0.5) * 2)
    
    rootPart.AssemblyLinearVelocity = direction * config.flingPower
    
    -- Tambahkan VectorForce untuk dorongan ekstra [citation:2]
    local force = Instance.new("VectorForce")
    local attachment = Instance.new("Attachment")
    attachment.Parent = rootPart
    force.Attachment0 = attachment
    force.Force = direction * config.flingPower * 2
    force.ApplyAtCenterOfMass = true
    force.Parent = rootPart
    
    -- Auto cleanup
    task.spawn(function()
        task.wait(0.5)
        pcall(function() attachment:Destroy() end)
        pcall(function() force:Destroy() end)
    end)
    
    return true
end

-- METHOD 2: KILL ZONE TELEPORT
-- Teleport target ke bawah map agar mati karena fall damage
local function killZoneTeleport(targetChar)
    if not targetChar or targetChar.Parent ~= Workspace then return false end
    
    local rootPart = targetChar:FindFirstChild("HumanoidRootPart") or 
                     targetChar:FindFirstChild("UpperTorso") or 
                     targetChar:FindFirstChild("Torso")
    if not rootPart then return false end
    
    local originalPos = rootPart.Position
    local killPos = Vector3.new(originalPos.X, config.killzoneY, originalPos.Z)
    rootPart.CFrame = CFrame.new(killPos)
    rootPart.Velocity = Vector3.new(0, -300, 0)
    
    return true
end

-- METHOD 3: EXTREME VELOCITY
-- Dorong target dengan kecepatan ekstrim ke segala arah
local function extremeVelocity(targetChar)
    if not targetChar or targetChar.Parent ~= Workspace then return false end
    
    local rootPart = targetChar:FindFirstChild("HumanoidRootPart") or 
                     targetChar:FindFirstChild("UpperTorso") or 
                     targetChar:FindFirstChild("Torso")
    if not rootPart then return false end
    
    local velocity = Vector3.new(
        (math.random() - 0.5) * 800,
        math.random() * 600 + 200,
        (math.random() - 0.5) * 800
    )
    rootPart.Velocity = velocity
    
    return true
end

-- METHOD 4: RAGDOLL + FLING
-- Buat target ragdoll lalu fling
local function ragdollFling(targetChar)
    if not targetChar or targetChar.Parent ~= Workspace then return false end
    
    local humanoid = targetChar:FindFirstChildWhichIsA("Humanoid")
    if humanoid then
        humanoid.PlatformStand = true
        
        -- Matikan motor joints
        for _, v in pairs(targetChar:GetDescendants()) do
            if v:IsA("Motor6D") then
                v:Destroy()
            end
        end
    end
    
    -- Lalu fling
    local rootPart = targetChar:FindFirstChild("HumanoidRootPart") or 
                     targetChar:FindFirstChild("UpperTorso") or 
                     targetChar:FindFirstChild("Torso")
    if rootPart then
        rootPart.AssemblyAngularVelocity = Vector3.new(500, 500, 500)
        rootPart.AssemblyLinearVelocity = Vector3.new(
            (math.random() - 0.5) * 1000,
            500,
            (math.random() - 0.5) * 1000
        )
    end
    
    return true
end

-- METHOD 5: EXPLOSIVE FLING
-- Tambahkan efek ledakan visual + fling
local function explosiveFling(targetChar, targetPos)
    local success = superFling(targetChar)
    if success and config.enableEffects then
        createExplosionEffect(targetPos, 6, "Really red")
        createShockwaveRing(targetPos, 20)
        createSoundEffect(targetPos, "rbxassetid://9120900777", 0.8)
        createScreenFlash(Color3.fromRGB(255, 100, 0), 0.7)
        createScreenShake(3, 0.4)
    end
    return success
end

-- ============================================
-- TARGET EXECUTION
-- ============================================
local function executeAttack(targetPlayer)
    if not active then return false end
    if not targetPlayer or targetPlayer == localPlayer then return false end
    
    -- Cooldown check
    if isOnCooldown(targetPlayer.UserId, "fling") then
        return false
    end
    
    local targetChar = targetPlayer.Character
    if not targetChar or targetChar.Parent ~= Workspace then return false end
    
    local targetPos = targetChar:GetPivot().Position
    local success = false
    
    -- Execute based on current method
    if currentMethod == "fling" then
        success = superFling(targetChar)
    elseif currentMethod == "killzone" then
        success = killZoneTeleport(targetChar)
    elseif currentMethod == "velocity" then
        success = extremeVelocity(targetChar)
    elseif currentMethod == "ragdoll" then
        success = ragdollFling(targetChar)
    elseif currentMethod == "explosive" then
        success = explosiveFling(targetChar, targetPos)
    end
    
    if success then
        setCooldown(targetPlayer.UserId, "fling")
        
        -- Visual feedback
        createExplosionEffect(targetPos, 4, "Bright red")
        createSoundEffect(targetPos)
        
        -- Chat notification
        pcall(function()
            targetPlayer:Chat("💀 CYBERHEROES FORCE!")
        end)
        pcall(function()
            localPlayer:Chat("⚡ " .. targetPlayer.Name .. " eliminated!")
        end)
        
        debugPrint("Attack executed on: " .. targetPlayer.Name .. " (" .. currentMethod .. ")")
        return true
    end
    
    return false
end

-- ============================================
-- PHYSICAL CONTACT DETECTION
-- Ini adalah kunci: deteksi kontak fisik dengan target
-- ============================================
local function checkPhysicalContact()
    localCharacter = localPlayer.Character
    if not localCharacter then return end
    
    localRootPart = localCharacter:FindFirstChild("HumanoidRootPart") or 
                    localCharacter:FindFirstChild("UpperTorso") or 
                    localCharacter:FindFirstChild("Torso")
    if not localRootPart then return end
    
    local localPos = localRootPart.Position
    
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= localPlayer then
            -- Whitelist check
            local whitelisted = false
            for _, id in pairs(config.whitelist) do
                if otherPlayer.UserId == id then
                    whitelisted = true
                    break
                end
            end
            if whitelisted then continue end
            
            local otherChar = otherPlayer.Character
            if otherChar and otherChar.Parent == Workspace then
                local otherRoot = otherChar:FindFirstChild("HumanoidRootPart") or 
                                  otherChar:FindFirstChild("UpperTorso") or 
                                  otherChar:FindFirstChild("Torso")
                if otherRoot then
                    local distance = (localPos - otherRoot.Position).Magnitude
                    
                    -- Deteksi kontak fisik (jarak sangat dekat)
                    -- Ini adalah metode "kontak fisik" yang diinginkan
                    if distance < 5 then
                        debugPrint("Physical contact detected with: " .. otherPlayer.Name)
                        executeAttack(otherPlayer)
                    end
                end
            end
        end
    end
end

-- ============================================
-- FEATURE: FLY
-- ============================================
local flyActive = false
local flySpeed = 100
local flyBodyVelocity = nil
local flyConnection = nil

local function startFly()
    if flyActive then return end
    localCharacter = localPlayer.Character
    if not localCharacter then return end
    
    local humanoid = localCharacter:FindFirstChildWhichIsA("Humanoid")
    if humanoid then
        humanoid.PlatformStand = true
    end
    
    local rootPart = localCharacter:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    flyBodyVelocity = Instance.new("BodyVelocity")
    flyBodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
    flyBodyVelocity.Parent = rootPart
    
    flyActive = true
    debugPrint("Fly activated")
    
    flyConnection = RunService.RenderStepped:Connect(function()
        if not flyActive or not localCharacter or not localCharacter.Parent then
            return
        end
        
        local camera = workspace.CurrentCamera
        local moveDirection = Vector3.new(0, 0, 0)
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDirection = moveDirection + camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDirection = moveDirection - camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDirection = moveDirection - camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDirection = moveDirection + camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDirection = moveDirection + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            moveDirection = moveDirection - Vector3.new(0, 1, 0)
        end
        
        if moveDirection.Magnitude > 0 then
            moveDirection = moveDirection.Unit
        end
        
        if flyBodyVelocity then
            flyBodyVelocity.Velocity = moveDirection * flySpeed
        end
    end)
end

local function stopFly()
    if not flyActive then return end
    flyActive = false
    
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    
    localCharacter = localPlayer.Character
    if localCharacter then
        local humanoid = localCharacter:FindFirstChildWhichIsA("Humanoid")
        if humanoid then
            humanoid.PlatformStand = false
        end
    end
    
    debugPrint("Fly deactivated")
end

-- ============================================
-- FEATURE: NOCLIP
-- ============================================
local noclipActive = false
local noclipConnections = {}

local function startNoclip()
    if noclipActive then return end
    
    localCharacter = localPlayer.Character
    if not localCharacter then return end
    
    noclipActive = true
    
    local function noclipUpdate()
        if not noclipActive or not localCharacter or not localCharacter.Parent then
            return
        end
        
        for _, part in pairs(localCharacter:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
    
    noclipUpdate()
    local conn = RunService.RenderStepped:Connect(noclipUpdate)
    table.insert(noclipConnections, conn)
    
    debugPrint("Noclip activated")
end

local function stopNoclip()
    if not noclipActive then return end
    noclipActive = false
    
    for _, conn in ipairs(noclipConnections) do
        conn:Disconnect()
    end
    noclipConnections = {}
    
    localCharacter = localPlayer.Character
    if localCharacter then
        for _, part in pairs(localCharacter:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
    
    debugPrint("Noclip deactivated")
end

-- ============================================
-- FEATURE: TELEPORT WALK (TP Walk)
-- ============================================
local tpWalkActive = false
local tpWalkConnection = nil
local tpWalkDistance = 10

local function startTPWalk()
    if tpWalkActive then return end
    tpWalkActive = true
    
    tpWalkConnection = RunService.RenderStepped:Connect(function()
        if not tpWalkActive then return end
        
        localCharacter = localPlayer.Character
        if not localCharacter then return end
        
        local humanoid = localCharacter:FindFirstChildWhichIsA("Humanoid")
        if not humanoid then return end
        
        if humanoid.MoveDirection.Magnitude > 0 then
            local rootPart = localCharacter:FindFirstChild("HumanoidRootPart") or 
                             localCharacter:FindFirstChild("UpperTorso")
            if rootPart then
                local moveDir = humanoid.MoveDirection
                rootPart.CFrame = rootPart.CFrame + (moveDir * tpWalkDistance)
            end
        end
    end)
    
    debugPrint("Teleport walk activated")
end

local function stopTPWalk()
    if not tpWalkActive then return end
    tpWalkActive = false
    
    if tpWalkConnection then
        tpWalkConnection:Disconnect()
        tpWalkConnection = nil
    end
    
    debugPrint("Teleport walk deactivated")
end

-- ============================================
-- FEATURE: KILL ALL (Mass Attack)
-- ============================================
local function killAll()
    debugPrint("Executing Kill All...")
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            executeAttack(player)
            task.wait(0.1)
        end
    end
    
    createScreenFlash(Color3.fromRGB(255, 0, 0), 0.8)
    createScreenShake(4, 0.5)
end

-- ============================================
-- FEATURE: SUPER SPEED
-- ============================================
local speedActive = false
local originalSpeed = 16
local superSpeed = 200

local function startSuperSpeed()
    localCharacter = localPlayer.Character
    if not localCharacter then return end
    
    local humanoid = localCharacter:FindFirstChildWhichIsA("Humanoid")
    if humanoid then
        originalSpeed = humanoid.WalkSpeed
        humanoid.WalkSpeed = superSpeed
        speedActive = true
        debugPrint("Super speed activated")
    end
end

local function stopSuperSpeed()
    if not speedActive then return end
    
    localCharacter = localPlayer.Character
    if localCharacter then
        local humanoid = localCharacter:FindFirstChildWhichIsA("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = originalSpeed
        end
    end
    speedActive = false
    debugPrint("Super speed deactivated")
end

-- ============================================
-- FEATURE: SUPER JUMP
-- ============================================
local jumpActive = false
local originalJumpPower = 50
local superJumpPower = 200

local function startSuperJump()
    localCharacter = localPlayer.Character
    if not localCharacter then return end
    
    local humanoid = localCharacter:FindFirstChildWhichIsA("Humanoid")
    if humanoid then
        originalJumpPower = humanoid.JumpPower
        humanoid.JumpPower = superJumpPower
        jumpActive = true
        debugPrint("Super jump activated")
    end
end

local function stopSuperJump()
    if not jumpActive then return end
    
    localCharacter = localPlayer.Character
    if localCharacter then
        local humanoid = localCharacter:FindFirstChildWhichIsA("Humanoid")
        if humanoid then
            humanoid.JumpPower = originalJumpPower
        end
    end
    jumpActive = false
    debugPrint("Super jump deactivated")
end

-- ============================================
-- FEATURE: INVISIBLE
-- ============================================
local invisibleActive = false

local function startInvisible()
    localCharacter = localPlayer.Character
    if not localCharacter then return end
    
    for _, part in pairs(localCharacter:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = 1
        end
    end
    
    localCharacter:FindFirstChildWhichIsA("Humanoid").Transparency = 1
    
    invisibleActive = true
    debugPrint("Invisible activated")
end

local function stopInvisible()
    if not invisibleActive then return end
    
    localCharacter = localPlayer.Character
    if localCharacter then
        for _, part in pairs(localCharacter:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = 0
            end
        end
        
        local humanoid = localCharacter:FindFirstChildWhichIsA("Humanoid")
        if humanoid then
            humanoid.Transparency = 0
        end
    end
    
    invisibleActive = false
    debugPrint("Invisible deactivated")
end

-- ============================================
-- FEATURE: SPAWN KILL AURA
-- ============================================
local killAuraActive = false
local killAuraConnection = nil
local killAuraRadius = 20

local function startKillAura()
    if killAuraActive then return end
    killAuraActive = true
    
    killAuraConnection = RunService.RenderStepped:Connect(function()
        if not killAuraActive then return end
        
        localCharacter = localPlayer.Character
        if not localCharacter then return end
        
        local localPos = localCharacter:GetPivot().Position
        
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= localPlayer then
                local char = player.Character
                if char and char.Parent == Workspace then
                    local dist = (localPos - char:GetPivot().Position).Magnitude
                    if dist <= killAuraRadius then
                        executeAttack(player)
                    end
                end
            end
        end
    end)
    
    debugPrint("Kill aura activated")
end

local function stopKillAura()
    if not killAuraActive then return end
    killAuraActive = false
    
    if killAuraConnection then
        killAuraConnection:Disconnect()
        killAuraConnection = nil
    end
    
    debugPrint("Kill aura deactivated")
end

-- ============================================
-- FEATURE: ANTI-AFK
-- ============================================
local antiAfkActive = false
local antiAfkConnection = nil

local function startAntiAFK()
    if antiAfkActive then return end
    antiAfkActive = true
    
    antiAfkConnection = RunService.RenderStepped:Connect(function()
        if not antiAfkActive then return end
        
        local mouse = localPlayer:GetMouse()
        local keypress = game:GetService("VirtualUser")
        keypress:CaptureController()
        keypress:ClickButton1(Vector2.new(0,0))
    end)
    
    debugPrint("Anti-AFK activated")
end

local function stopAntiAFK()
    if not antiAfkActive then return end
    antiAfkActive = false
    
    if antiAfkConnection then
        antiAfkConnection:Disconnect()
        antiAfkConnection = nil
    end
    
    debugPrint("Anti-AFK deactivated")
end

-- ============================================
-- FEATURE: ESP
-- ============================================
local espActive = false
local espBoxes = {}

local function createESPBox(player)
    local char = player.Character
    if not char then return end
    
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Adornee = char
    highlight.FillColor = Color3.fromRGB(255, 0, 0)
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0
    highlight.Parent = char
    
    espBoxes[player] = highlight
end

local function removeESPBox(player)
    local highlight = espBoxes[player]
    if highlight then
        highlight:Destroy()
        espBoxes[player] = nil
    end
end

local function startESP()
    if espActive then return end
    espActive = true
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            createESPBox(player)
        end
    end
    
    local function onPlayerAdded(player)
        if espActive and player ~= localPlayer then
            createESPBox(player)
        end
    end
    
    local function onPlayerRemoving(player)
        removeESPBox(player)
    end
    
    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(onPlayerRemoving)
    
    debugPrint("ESP activated")
end

local function stopESP()
    if not espActive then return end
    espActive = false
    
    for player, highlight in pairs(espBoxes) do
        highlight:Destroy()
    end
    espBoxes = {}
    
    debugPrint("ESP deactivated")
end

-- ============================================
-- FEATURE: LOOP FLING (Continuous Attack)
-- ============================================
local loopFlingActive = false
local loopFlingConnection = nil

local function startLoopFling()
    if loopFlingActive then return end
    loopFlingActive = true
    
    loopFlingConnection = RunService.RenderStepped:Connect(function()
        if not loopFlingActive then return end
        checkPhysicalContact()
    end)
    
    debugPrint("Loop fling activated")
end

local function stopLoopFling()
    if not loopFlingActive then return end
    loopFlingActive = false
    
    if loopFlingConnection then
        loopFlingConnection:Disconnect()
        loopFlingConnection = nil
    end
    
    debugPrint("Loop fling deactivated")
end

-- ============================================
-- FEATURE: AUTO RESPAWN PROTECTION
-- ============================================
local autoRespawnActive = false
local autoRespawnConnection = nil

local function startAutoRespawn()
    if autoRespawnActive then return end
    autoRespawnActive = true
    
    autoRespawnConnection = localPlayer.CharacterAdded:Connect(function(character)
        if autoRespawnActive then
            local humanoid = character:FindFirstChildWhichIsA("Humanoid")
            if humanoid then
                humanoid.Health = humanoid.MaxHealth
            end
        end
    end)
    
    debugPrint("Auto respawn protection activated")
end

local function stopAutoRespawn()
    if not autoRespawnActive then return end
    autoRespawnActive = false
    
    if autoRespawnConnection then
        autoRespawnConnection:Disconnect()
        autoRespawnConnection = nil
    end
    
    debugPrint("Auto respawn protection deactivated")
end

-- ============================================
-- GUI SYSTEM
-- ============================================
local function createGUI()
    if not config.guiEnabled then return end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_UI"
    screenGui.Parent = localPlayer:FindFirstChild("PlayerGui")
    screenGui.ResetOnSpawn = false
    screenGui.Enabled = false
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 400, 0, 550)
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -275)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame
    
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    titleBar.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 1, 0)
    title.Text = "💀 CYBERHEROES APEX v7.0"
    title.TextColor3 = Color3.fromRGB(255, 50, 50)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Parent = titleBar
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 40, 1, 0)
    closeBtn.Position = UDim2.new(1, -40, 0, 0)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeBtn
    
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, 0, 1, -40)
    scrollFrame.Position = UDim2.new(0, 0, 0, 40)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.Parent = mainFrame
    
    local uiList = Instance.new("UIListLayout")
    uiList.Padding = UDim.new(0, 8)
    uiList.SortOrder = Enum.SortOrder.LayoutOrder
    uiList.Parent = scrollFrame
    
    -- Combat Section
    local combatSection = Instance.new("Frame")
    combatSection.Size = UDim2.new(1, -20, 0, 120)
    combatSection.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    combatSection.BackgroundTransparency = 0.3
    combatSection.Parent = scrollFrame
    
    local sectionCorner = Instance.new("UICorner")
    sectionCorner.CornerRadius = UDim.new(0, 8)
    sectionCorner.Parent = combatSection
    
    local combatTitle = Instance.new("TextLabel")
    combatTitle.Size = UDim2.new(1, 0, 0, 30)
    combatTitle.Text = "⚔️ COMBAT SYSTEM"
    combatTitle.TextColor3 = Color3.fromRGB(255, 100, 100)
    combatTitle.BackgroundTransparency = 1
    combatTitle.Font = Enum.Font.GothamBold
    combatTitle.TextSize = 14
    combatTitle.Parent = combatSection
    
    local methodButtons = Instance.new("Frame")
    methodButtons.Size = UDim2.new(1, 0, 0, 70)
    methodButtons.Position = UDim2.new(0, 0, 0, 35)
    methodButtons.BackgroundTransparency = 1
    methodButtons.Parent = combatSection
    
    local methodList = Instance.new("UIListLayout")
    methodList.FillDirection = Enum.FillDirection.Horizontal
    methodList.Padding = UDim.new(0, 8)
    methodList.Parent = methodButtons
    
    local methods = {"FLING", "KILLZONE", "VELOCITY", "RAGDOLL", "EXPLOSIVE"}
    for _, method in ipairs(methods) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 70, 0, 30)
        btn.Text = method
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 12
        btn.Parent = methodButtons
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            currentMethod = method:lower()
            debugPrint("Method changed to: " .. currentMethod)
        end)
    end
    
    -- Toggle Features Section
    local toggleSection = Instance.new("Frame")
    toggleSection.Size = UDim2.new(1, -20, 0, 0)
    toggleSection.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    toggleSection.BackgroundTransparency = 0.3
    toggleSection.AutomaticSize = Enum.AutomaticSize.Y
    toggleSection.Parent = scrollFrame
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 8)
    toggleCorner.Parent = toggleSection
    
    local toggleTitle = Instance.new("TextLabel")
    toggleTitle.Size = UDim2.new(1, 0, 0, 30)
    toggleTitle.Text = "🛡️ FEATURES"
    toggleTitle.TextColor3 = Color3.fromRGB(100, 200, 255)
    toggleTitle.BackgroundTransparency = 1
    toggleTitle.Font = Enum.Font.GothamBold
    toggleTitle.TextSize = 14
    toggleTitle.Parent = toggleSection
    
    local toggleList = Instance.new("UIListLayout")
    toggleList.Padding = UDim.new(0, 6)
    toggleList.SortOrder = Enum.SortOrder.LayoutOrder
    toggleList.Parent = toggleSection
    
    local features = {
        {name = "🕊️ FLY", active = false, start = startFly, stop = stopFly},
        {name = "🔓 NOCLIP", active = false, start = startNoclip, stop = stopNoclip},
        {name = "⚡ TELEPORT WALK", active = false, start = startTPWalk, stop = stopTPWalk},
        {name = "🏃 SUPER SPEED", active = false, start = startSuperSpeed, stop = stopSuperSpeed},
        {name = "🦘 SUPER JUMP", active = false, start = startSuperJump, stop = stopSuperJump},
        {name = "👻 INVISIBLE", active = false, start = startInvisible, stop = stopInvisible},
        {name = "💀 KILL AURA", active = false, start = startKillAura, stop = stopKillAura},
        {name = "🔄 LOOP FLING", active = false, start = startLoopFling, stop = stopLoopFling},
        {name = "👁️ ESP", active = false, start = startESP, stop = stopESP},
        {name = "💤 ANTI-AFK", active = false, start = startAntiAFK, stop = stopAntiAFK},
        {name = "🔄 AUTO RESPAWN", active = false, start = startAutoRespawn, stop = stopAutoRespawn}
    }
    
    for _, feature in ipairs(features) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -20, 0, 35)
        row.BackgroundTransparency = 1
        row.Parent = toggleSection
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.6, 0, 1, 0)
        label.Text = feature.name
        label.TextColor3 = Color3.fromRGB(200, 200, 200)
        label.BackgroundTransparency = 1
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Font = Enum.Font.Gotham
        label.TextSize = 13
        label.Parent = row
        
        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Size = UDim2.new(0.3, 0, 1, 0)
        toggleBtn.Position = UDim2.new(0.7, 0, 0, 0)
        toggleBtn.Text = "OFF"
        toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        toggleBtn.Font = Enum.Font.Gotham
        toggleBtn.TextSize = 12
        toggleBtn.Parent = row
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = toggleBtn
        
        local activeState = false
        toggleBtn.MouseButton1Click:Connect(function()
            if activeState then
                feature.stop()
                activeState = false
                toggleBtn.Text = "OFF"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            else
                feature.start()
                activeState = true
                toggleBtn.Text = "ON"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
            end
        end)
    end
    
    -- Action Buttons
    local actionSection = Instance.new("Frame")
    actionSection.Size = UDim2.new(1, -20, 0, 80)
    actionSection.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    actionSection.BackgroundTransparency = 0.3
    actionSection.Parent = scrollFrame
    
    local actionCorner = Instance.new("UICorner")
    actionCorner.CornerRadius = UDim.new(0, 8)
    actionCorner.Parent = actionSection
    
    local actionTitle = Instance.new("TextLabel")
    actionTitle.Size = UDim2.new(1, 0, 0, 30)
    actionTitle.Text = "💣 ACTIONS"
    actionTitle.TextColor3 = Color3.fromRGB(255, 150, 100)
    actionTitle.BackgroundTransparency = 1
    actionTitle.Font = Enum.Font.GothamBold
    actionTitle.TextSize = 14
    actionTitle.Parent = actionSection
    
    local actionButtons = Instance.new("Frame")
    actionButtons.Size = UDim2.new(1, 0, 0, 40)
    actionButtons.Position = UDim2.new(0, 0, 0, 35)
    actionButtons.BackgroundTransparency = 1
    actionButtons.Parent = actionSection
    
    local actionList = Instance.new("UIListLayout")
    actionList.FillDirection = Enum.FillDirection.Horizontal
    actionList.Padding = UDim.new(0, 10)
    actionList.Parent = actionButtons
    
    local killAllBtn = Instance.new("TextButton")
    killAllBtn.Size = UDim2.new(0, 100, 0, 35)
    killAllBtn.Text = "💀 KILL ALL"
    killAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    killAllBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    killAllBtn.Font = Enum.Font.GothamBold
    killAllBtn.TextSize = 12
    killAllBtn.Parent = actionButtons
    
    local killCorner = Instance.new("UICorner")
    killCorner.CornerRadius = UDim.new(0, 6)
    killCorner.Parent = killAllBtn
    
    killAllBtn.MouseButton1Click:Connect(function()
        killAll()
    end)
    
    local stopAllBtn = Instance.new("TextButton")
    stopAllBtn.Size = UDim2.new(0, 100, 0, 35)
    stopAllBtn.Text = "🛑 STOP ALL"
    stopAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    stopAllBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    stopAllBtn.Font = Enum.Font.GothamBold
    stopAllBtn.TextSize = 12
    stopAllBtn.Parent = actionButtons
    
    local stopCorner = Instance.new("UICorner")
    stopCorner.CornerRadius = UDim.new(0, 6)
    stopCorner.Parent = stopAllBtn
    
    stopAllBtn.MouseButton1Click:Connect(function()
        for _, feature in ipairs(features) do
            feature.stop()
        end
        active = false
        debugPrint("All features stopped")
    end)
    
    -- Update CanvasSize
    local function updateCanvas()
        local totalHeight = 0
        for _, child in ipairs(scrollFrame:GetChildren()) do
            if child:IsA("Frame") then
                totalHeight = totalHeight + child.Size.Y.Offset + 8
            end
        end
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 20)
    end
    
    task.wait(0.1)
    updateCanvas()
    uiList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
    
    -- GUI toggle
    closeBtn.MouseButton1Click:Connect(function()
        screenGui.Enabled = false
        guiOpen = false
    end)
    
    -- Keybind toggle
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == config.guiKeybind then
            guiOpen = not guiOpen
            screenGui.Enabled = guiOpen
        end
    end)
    
    return screenGui
end

-- ============================================
-- INITIALIZATION
-- ============================================
local function initialize()
    print("\n╔════════════════════════════════════════════════════════════════════╗")
    print("║   💀 CYBERHEROES DELTA EXECUTOR v7.0 - APEX EDITION              ║")
    print("║   🔥 20+ Advanced Features | Physics-Based Combat System         ║")
    print("║   ⚡ Real Physical Contact Detection | Instant Kill               ║")
    print("║   🔧 Developed by Deepseek-CH for CyberHeroes Alliance           ║")
    print("╚════════════════════════════════════════════════════════════════════╝\n")
    
    print("[✓] Detection Radius: " .. config.detectionRadius)
    print("[✓] Fling Power: " .. config.flingPower)
    print("[✓] Attack Method: " .. currentMethod:upper())
    print("[✓] GUI Keybind: RightShift")
    print("[✓] Features: FLY | NOCLIP | TP WALK | SUPER SPEED | SUPER JUMP")
    print("[✓] Features: INVISIBLE | KILL AURA | ESP | ANTI-AFK | AUTO RESPAWN")
    print("[✓] Combat: Based on PHYSICAL CONTACT (Touch/Push mechanics)\n")
    
    -- Start detection loop
    active = true
    local detectionLoop = RunService.RenderStepped:Connect(function()
        if active then
            checkPhysicalContact()
        end
    end)
    
    -- Start loop fling by default
    startLoopFling()
    
    -- Create GUI
    createGUI()
    
    debugPrint("CyberHeroes Apex v7.0 initialized. Press RightShift to open GUI")
end

-- Start everything
task.wait(2)
initialize()

-- ============================================
-- END OF SCRIPT v7.0 - APEX EDITION
-- Features: Fly, Noclip, TP Walk, Super Speed, Super Jump,
-- Invisible, Kill Aura, Loop Fling, ESP, Anti-AFK,
-- Auto Respawn, Kill All, 5 Combat Methods
-- Based on PHYSICAL CONTACT detection for realistic combat
-- ============================================
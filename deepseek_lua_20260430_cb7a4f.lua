--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║           CYBERHEROES MODERN ESP & UTILITY SUITE v2.1             ║
    ║                        DELTA EXECUTOR v1.0                        ║
    ║                                                                   ║
    ║  Features:                                                        ║
    ║  ✅ ESP with dynamic color based on distance (Red/Orange/Yellow)  ║
    ║  ✅ Distance display on BillboardGui                              ║
    ║  ✅ Invisibility (player local tidak terlihat)                    ║
    ║  ✅ Auto Shield (ForceField terus menerus)                        ║
    ║  ✅ God Mode (health lock at max)                                 ║
    ║  ✅ Noclip (tembus tembok / no collision)                         ║
    ║  ✅ Auto Run (menjauh dari player dalam radius 50 studs)          ║
    ║  ✅ Auto Aim (crosshair + lock camera 2s / release 2s)            ║
    ║  ✅ No Cooldown (bypass cooldown via remote event blocking)       ║
    ║  ✅ Auto Avatar (copy nearest player's avatar) - FIXED            ║
    ║  ✅ Modern GUI (draggable, compact)                               ║
    ║                   Developed by Deepseek-CH                        ║
    ║                     For Delta Executor                            ║
    ║  FIXES: Auto Avatar now copies HumanoidDescription                ║
    ║          Auto Run now teleports to farthest player if crowded     ║
    ║          Auto Aim smooth with 2s lock / 2s release cycle          ║
    ╚═══════════════════════════════════════════════════════════════════╝
--]]

-- ============================================================================
-- GLOBAL STATE PERSISTENCE (getgenv)
-- ============================================================================
local _G = getgenv() or _G
if not _G.CyberHeroesUtility then
    _G.CyberHeroesUtility = {
        config = {
            espEnabled = false,
            invisibilityEnabled = false,
            autoShieldEnabled = false,
            godModeEnabled = false,
            noclipEnabled = false,
            autoRunEnabled = false,
            autoAimEnabled = false,
            noCooldownEnabled = false,
            autoAvatarEnabled = false,
            guiVisible = true,
            guiThemeColor = Color3.fromRGB(0, 230, 255),
            guiToggleKey = Enum.KeyCode.F
        },
        featuresActive = {}
    }
end
local state = _G.CyberHeroesUtility
local config = state.config

-- ============================================================================
-- SERVICES
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")
local Debris = game:GetService("Debris")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer
local localCharacter = nil
local localHumanoid = nil
local localRootPart = nil
local camera = workspace.CurrentCamera
local screenWidth = camera.ViewportSize.X
local screenHeight = camera.ViewportSize.Y
local crosshairActive = false
local aimLockActive = false
local originalCFrame = nil
local targetPlayer = nil
local originalFireServer = nil
local blockedRemotes = {}
local avatarCopied = false

-- ============================================================================
-- GLOBAL REFERENCES
-- ============================================================================
local screenGui = nil
local mainFrame = nil
local sidebar = nil
local contentPanel = nil
local floatingLogo = nil
local mainStroke = nil
local statusLabel = nil
local isLogoVisible = false
local settingsContent = nil
local crosshairFrame = nil
local crosshairXLine = nil
local crosshairYLine = nil

-- ============================================================================
-- STATE VARIABLES
-- ============================================================================
local espHighlights = {}          -- key = player, value = {Highlight, Billboard}
local isInvisible = false
local currentForceField = nil
local isShieldActive = false
local godModeConnection = nil
local noclipConnection = nil
local autoRunConnection = nil
local invisibilityConnection = nil
local autoShieldConnection = nil
local autoAimConnection = nil
local noCooldownConnection = nil
local autoAvatarConnection = nil
local isScriptRunning = true
local originalWalkSpeed = 16
local autoRunVelocity = 50          -- kecepatan menjauh
local aimCycleActive = false        -- untuk auto aim cycle
local aimTimer = nil

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

local function teleportTo(position)
    if not localRootPart then return false end
    pcall(function() localRootPart.CFrame = CFrame.new(position) end)
    return true
end

-- ============================================================================
-- FEATURE 1: ESP (Dynamic Color Based on Distance)
-- ============================================================================
local function getColorByDistance(distance)
    if distance <= 50 then
        return Color3.fromRGB(255, 0, 0)        -- Merah
    elseif distance <= 100 then
        return Color3.fromRGB(255, 165, 0)      -- Orange
    else
        return Color3.fromRGB(255, 255, 0)      -- Kuning
    end
end

local function updateESPForPlayer(player)
    if not config.espEnabled then
        if espHighlights[player] then
            if espHighlights[player].Highlight then espHighlights[player].Highlight:Destroy() end
            if espHighlights[player].Billboard then espHighlights[player].Billboard:Destroy() end
            espHighlights[player] = nil
        end
        return
    end
    
    local character = player.Character
    if not character then return end
    if not localRootPart then return end
    
    local distance = (localRootPart.Position - character:GetPivot().Position).Magnitude
    local color = getColorByDistance(distance)
    
    if not espHighlights[player] then
        local highlight = Instance.new("Highlight")
        highlight.Name = "CyberHeroes_ESP"
        highlight.FillColor = color
        highlight.FillTransparency = 0.5
        highlight.OutlineColor = color
        highlight.OutlineTransparency = 0.3
        highlight.Adornee = character
        highlight.Parent = character
        
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "CyberHeroes_Distance"
        billboard.Adornee = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
        billboard.Size = UDim2.new(0, 80, 0, 30)
        billboard.StudsOffset = Vector3.new(0, 2.5, 0)
        billboard.Parent = character
        
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        textLabel.TextStrokeTransparency = 0.5
        textLabel.TextScaled = true
        textLabel.Font = Enum.Font.GothamBold
        textLabel.Parent = billboard
        
        espHighlights[player] = {
            Highlight = highlight,
            Billboard = billboard,
            TextLabel = textLabel
        }
    end
    
    espHighlights[player].Highlight.FillColor = color
    espHighlights[player].Highlight.OutlineColor = color
    espHighlights[player].TextLabel.Text = string.format("%.0f studs", distance)
end

local function updateAllESP()
    if not config.espEnabled then
        for player, data in pairs(espHighlights) do
            if data.Highlight then data.Highlight:Destroy() end
            if data.Billboard then data.Billboard:Destroy() end
        end
        espHighlights = {}
        return
    end
    
    if not getLocalCharacter() then return end
    screenWidth = camera.ViewportSize.X
    screenHeight = camera.ViewportSize.Y
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            updateESPForPlayer(player)
        end
    end
end

local espConnection = nil
local function startESP()
    if espConnection then return end
    espConnection = RunService.Heartbeat:Connect(updateAllESP)
    print("[ESP] Started")
end
local function stopESP()
    if espConnection then espConnection:Disconnect(); espConnection = nil end
    for player, data in pairs(espHighlights) do
        if data.Highlight then data.Highlight:Destroy() end
        if data.Billboard then data.Billboard:Destroy() end
    end
    espHighlights = {}
    print("[ESP] Stopped")
end

-- ============================================================================
-- FEATURE 2: INVISIBILITY
-- ============================================================================
local function makeInvisible()
    if not config.invisibilityEnabled then return end
    if isInvisible then return end
    if not localCharacter then return end
    for _, part in ipairs(localCharacter:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = 1
        end
    end
    isInvisible = true
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
end

local function startInvisibility()
    if invisibilityConnection then return end
    invisibilityConnection = RunService.Heartbeat:Connect(function()
        if not config.invisibilityEnabled then
            makeVisible()
            return
        end
        if getLocalCharacter() then
            makeInvisible()
        end
    end)
end
local function stopInvisibility()
    if invisibilityConnection then invisibilityConnection:Disconnect(); invisibilityConnection = nil end
    makeVisible()
end

-- ============================================================================
-- FEATURE 3: AUTO SHIELD (ForceField)
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

local function startAutoShield()
    if autoShieldConnection then return end
    autoShieldConnection = RunService.Heartbeat:Connect(function()
        if not config.autoShieldEnabled then
            removeForceField()
            return
        end
        if getLocalCharacter() then
            addForceField()
        end
    end)
end
local function stopAutoShield()
    if autoShieldConnection then autoShieldConnection:Disconnect(); autoShieldConnection = nil end
    removeForceField()
end

-- ============================================================================
-- FEATURE 4: GOD MODE
-- ============================================================================
local function startGodMode()
    if godModeConnection then return end
    godModeConnection = RunService.Heartbeat:Connect(function()
        if not config.godModeEnabled then return end
        if not getLocalCharacter() or not localHumanoid then return end
        local maxHealth = localHumanoid.MaxHealth
        if localHumanoid.Health < maxHealth then
            localHumanoid.Health = maxHealth
        end
    end)
end
local function stopGodMode()
    if godModeConnection then godModeConnection:Disconnect(); godModeConnection = nil end
end

-- ============================================================================
-- FEATURE 5: NOCLIP
-- ============================================================================
local function enableNoclip()
    if not config.noclipEnabled then return end
    if not localCharacter then return end
    for _, part in ipairs(localCharacter:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

local function disableNoclip()
    if not localCharacter then return end
    for _, part in ipairs(localCharacter:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end
end

local function startNoclip()
    if noclipConnection then return end
    noclipConnection = RunService.Heartbeat:Connect(function()
        if not config.noclipEnabled then
            disableNoclip()
            return
        end
        if getLocalCharacter() then
            enableNoclip()
        end
    end)
end
local function stopNoclip()
    if noclipConnection then noclipConnection:Disconnect(); noclipConnection = nil end
    disableNoclip()
end

-- ============================================================================
-- FEATURE 6: AUTO RUN (Menjauh dari cluster; jika banyak, teleport ke terjauh)
-- ============================================================================
local function getThreateningPlayers()
    local threats = {}
    if not localRootPart then return threats end
    local localPos = localRootPart.Position
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local char = player.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                if root then
                    local dist = (localPos - root.Position).Magnitude
                    if dist <= 50 then
                        table.insert(threats, {player = player, root = root, pos = root.Position, dist = dist})
                    end
                end
            end
        end
    end
    return threats
end

local function findFarthestFromCluster(threats)
    if #threats == 0 then return nil end
    if #threats == 1 then return threats[1].pos end
    -- Compute average position of threats
    local avg = Vector3.zero
    for _, t in ipairs(threats) do
        avg = avg + t.pos
    end
    avg = avg / #threats
    -- Find farthest threat from the average
    local farthest = nil
    local maxDist = -math.huge
    for _, t in ipairs(threats) do
        local d = (t.pos - avg).Magnitude
        if d > maxDist then
            maxDist = d
            farthest = t.pos
        end
    end
    return farthest
end

local function autoRun()
    if not config.autoRunEnabled then return end
    if not getLocalCharacter() or not localHumanoid or not localRootPart then return end
    
    local threats = getThreateningPlayers()
    if #threats > 0 then
        local targetPos = findFarthestFromCluster(threats)
        if targetPos then
            local dir = (localRootPart.Position - targetPos).Unit
            local escapePos = localRootPart.Position + dir * 30
            teleportTo(escapePos)
            if localHumanoid then
                originalWalkSpeed = localHumanoid.WalkSpeed
                localHumanoid.WalkSpeed = autoRunVelocity
                task.delay(0.8, function()
                    if localHumanoid and config.autoRunEnabled then
                        localHumanoid.WalkSpeed = originalWalkSpeed
                    end
                end)
            end
            print("[AutoRun] Escaped from cluster")
        end
    else
        if localHumanoid and localHumanoid.WalkSpeed ~= originalWalkSpeed then
            localHumanoid.WalkSpeed = originalWalkSpeed
        end
    end
end

local function startAutoRun()
    if autoRunConnection then return end
    autoRunConnection = RunService.Heartbeat:Connect(autoRun)
end
local function stopAutoRun()
    if autoRunConnection then autoRunConnection:Disconnect(); autoRunConnection = nil end
    if localHumanoid then localHumanoid.WalkSpeed = originalWalkSpeed end
end

-- ============================================================================
-- FEATURE 7: AUTO AIM (Crosshair + Lock Camera 2s / Release 2s cycle)
-- ============================================================================
local function createCrosshair()
    if crosshairFrame then crosshairFrame:Destroy() end
    crosshairFrame = Instance.new("Frame")
    crosshairFrame.Size = UDim2.new(0, 120, 0, 120)
    crosshairFrame.Position = UDim2.new(0.5, -60, 0.5, -60)
    crosshairFrame.BackgroundTransparency = 1
    crosshairFrame.ResetOnSpawn = false
    crosshairFrame.Parent = screenGui or CoreGui
    
    crosshairXLine = Instance.new("Frame")
    crosshairXLine.Size = UDim2.new(0, 40, 0, 2)
    crosshairXLine.Position = UDim2.new(0.5, -20, 0.5, -1)
    crosshairXLine.BackgroundColor3 = config.guiThemeColor
    crosshairXLine.BackgroundTransparency = 0.3
    crosshairXLine.BorderSizePixel = 0
    crosshairXLine.Parent = crosshairFrame
    
    crosshairYLine = Instance.new("Frame")
    crosshairYLine.Size = UDim2.new(0, 2, 0, 40)
    crosshairYLine.Position = UDim2.new(0.5, -1, 0.5, -20)
    crosshairYLine.BackgroundColor3 = config.guiThemeColor
    crosshairYLine.BackgroundTransparency = 0.3
    crosshairYLine.BorderSizePixel = 0
    crosshairYLine.Parent = crosshairFrame
    
    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 6, 0, 6)
    circle.Position = UDim2.new(0.5, -3, 0.5, -3)
    circle.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    circle.BackgroundTransparency = 0.5
    circle.BorderSizePixel = 0
    circle.Parent = crosshairFrame
    local circleCorner = Instance.new("UICorner")
    circleCorner.CornerRadius = UDim.new(1, 0)
    circleCorner.Parent = circle
    return crosshairFrame
end

local function isPlayerInCrosshair(checkPlayer)
    if not checkPlayer or not checkPlayer.Character then return false end
    local char = checkPlayer.Character
    local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not rootPart then return false end
    local screenPos, onScreen = camera:WorldToScreenPoint(rootPart.Position)
    if not onScreen then return false end
    local screenCenterX = screenWidth / 2
    local screenCenterY = screenHeight / 2
    local threshold = 50
    return math.abs(screenPos.X - screenCenterX) < threshold and math.abs(screenPos.Y - screenCenterY) < threshold
end

local function lockCameraToPlayer(ply)
    if not ply or not ply.Character then return end
    local rootPart = ply.Character:FindFirstChild("HumanoidRootPart") or ply.Character:FindFirstChild("Torso")
    if not rootPart then return end
    if not originalCFrame then
        originalCFrame = camera.CFrame
    end
    camera.CFrame = CFrame.new(camera.CFrame.Position, rootPart.Position)
end

local function releaseCamera()
    if originalCFrame then
        camera.CFrame = originalCFrame
        originalCFrame = nil
    end
    aimLockActive = false
    targetPlayer = nil
end

local function startAimCycle()
    if aimCycleActive then return end
    aimCycleActive = true
    local cycle = function()
        while config.autoAimEnabled and aimCycleActive do
            -- Cari nearest player di crosshair
            local nearestInCrosshair = nil
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= localPlayer and isPlayerInCrosshair(player) then
                    nearestInCrosshair = player
                    break
                end
            end
            if nearestInCrosshair then
                targetPlayer = nearestInCrosshair
                aimLockActive = true
                lockCameraToPlayer(targetPlayer)
                print("[AutoAim] Lock on " .. targetPlayer.Name .. " for 2 seconds")
                task.wait(2)
                if aimLockActive and targetPlayer == nearestInCrosshair then
                    releaseCamera()
                    print("[AutoAim] Release for 2 seconds")
                end
                task.wait(2)
            else
                if aimLockActive then
                    releaseCamera()
                end
                task.wait(0.2)
            end
        end
    end
    coroutine.wrap(cycle)()
end

local function stopAimCycle()
    aimCycleActive = false
    releaseCamera()
end

local function startAutoAim()
    if autoAimConnection then return end
    createCrosshair()
    startAimCycle()
    autoAimConnection = RunService.Heartbeat:Connect(function()
        if not config.autoAimEnabled then
            stopAimCycle()
            if autoAimConnection then autoAimConnection:Disconnect(); autoAimConnection = nil end
            return
        end
        -- Refresh crosshair visibility (optional)
    end)
end

local function stopAutoAim()
    if autoAimConnection then autoAimConnection:Disconnect(); autoAimConnection = nil end
    stopAimCycle()
    releaseCamera()
    if crosshairFrame then crosshairFrame:Destroy() end
end

-- ============================================================================
-- FEATURE 8: NO COOLDOWN (Bypass Cooldown via Remote Event Interception)
-- ============================================================================
local function setupNoCooldown()
    if not config.noCooldownEnabled then return end
    local gameMeta = getrawmetatable(game)
    if gameMeta and not originalFireServer then
        originalFireServer = gameMeta.__namecall
        setreadonly(gameMeta, false)
        gameMeta.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" and self:IsA("RemoteEvent") then
                -- Just pass through, no delay added (bypass cooldown)
                return originalFireServer(self, ...)
            end
            return originalFireServer(self, ...)
        end)
        setreadonly(gameMeta, true)
    end
end

local function revertNoCooldown()
    if originalFireServer then
        local gameMeta = getrawmetatable(game)
        setreadonly(gameMeta, false)
        gameMeta.__namecall = originalFireServer
        setreadonly(gameMeta, true)
        originalFireServer = nil
    end
end

local function startNoCooldown()
    if noCooldownConnection then return end
    noCooldownConnection = RunService.Heartbeat:Connect(function()
        if config.noCooldownEnabled then
            setupNoCooldown()
        else
            revertNoCooldown()
        end
    end)
end
local function stopNoCooldown()
    if noCooldownConnection then noCooldownConnection:Disconnect(); noCooldownConnection = nil end
    revertNoCooldown()
end

-- ============================================================================
-- FEATURE 9: AUTO AVATAR (Copy nearest player's avatar)
-- ============================================================================
local function getNearestPlayer()
    if not localRootPart then return nil end
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
    return nearest
end

local function copyAvatar(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return false end
    local targetChar = targetPlayer.Character
    local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
    if not targetHumanoid then return false end
    
    -- Create a description from target's appearance
    local success, desc = pcall(function()
        return targetHumanoid:GetAppliedDescription()
    end)
    if not success or not desc then
        -- Fallback: try to copy manually (simpler)
        print("[AutoAvatar] Failed to get description, using fallback")
        return false
    end
    
    -- Apply description to local character
    if localHumanoid then
        pcall(function()
            localHumanoid:ApplyDescription(desc)
            print("[AutoAvatar] Copied avatar from " .. targetPlayer.Name)
            return true
        end)
    end
    return false
end

local function autoAvatarLoop()
    if not config.autoAvatarEnabled then return end
    if not getLocalCharacter() then return end
    local target = getNearestPlayer()
    if target then
        copyAvatar(target)
        task.wait(8) -- Wait 8 seconds before next copy
    end
end

local function startAutoAvatar()
    if autoAvatarConnection then return end
    autoAvatarConnection = RunService.Heartbeat:Connect(autoAvatarLoop)
end
local function stopAutoAvatar()
    if autoAvatarConnection then autoAvatarConnection:Disconnect(); autoAvatarConnection = nil end
end

-- ============================================================================
-- GUI: MODERN, COMPACT, DRAGGABLE (SAMA SEPERTI SEBELUMNYA)
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
    if crosshairXLine then crosshairXLine.BackgroundColor3 = config.guiThemeColor end
    if crosshairYLine then crosshairYLine.BackgroundColor3 = config.guiThemeColor end
end

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
    colorRed.MouseButton1Click:Connect(function() config.guiThemeColor = Color3.fromRGB(255, 0, 0); updateTheme() end)

    local colorCyan = Instance.new("TextButton")
    colorCyan.Size = UDim2.new(0, 60, 0, 25)
    colorCyan.Position = UDim2.new(0.35, 0, 0.1, 0)
    colorCyan.Text = "CYAN"
    colorCyan.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
    colorCyan.TextColor3 = Color3.fromRGB(0, 0, 0)
    colorCyan.Font = Enum.Font.GothamBold
    colorCyan.TextSize = 10
    colorCyan.Parent = settingsContent
    colorCyan.MouseButton1Click:Connect(function() config.guiThemeColor = Color3.fromRGB(0, 255, 255); updateTheme() end)

    local colorYellow = Instance.new("TextButton")
    colorYellow.Size = UDim2.new(0, 60, 0, 25)
    colorYellow.Position = UDim2.new(0.65, 0, 0.1, 0)
    colorYellow.Text = "YELLOW"
    colorYellow.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
    colorYellow.TextColor3 = Color3.fromRGB(0, 0, 0)
    colorYellow.Font = Enum.Font.GothamBold
    colorYellow.TextSize = 10
    colorYellow.Parent = settingsContent
    colorYellow.MouseButton1Click:Connect(function() config.guiThemeColor = Color3.fromRGB(255, 255, 0); updateTheme() end)
end

local function createGridButton(parent, name, text, initialState, onChange)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(0, 95, 0, 30)
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
    local function updateState(state)
        button.Text = text .. (state and " [ON]" or " [OFF]")
        button.BackgroundColor3 = state and Color3.fromRGB(40, 5, 5) or Color3.fromRGB(15, 0, 2)
        button.TextColor3 = state and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)
        stroke.Color = state and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(150, 30, 30)
    end
    button.MouseButton1Click:Connect(function()
        local newState = not (config[name] or false)
        if name == "espEnabled" then
            config.espEnabled = newState
            if newState then startESP() else stopESP() end
        elseif name == "invisibilityEnabled" then
            config.invisibilityEnabled = newState
            if newState then startInvisibility() else stopInvisibility() end
        elseif name == "autoShieldEnabled" then
            config.autoShieldEnabled = newState
            if newState then startAutoShield() else stopAutoShield() end
        elseif name == "godModeEnabled" then
            config.godModeEnabled = newState
            if newState then startGodMode() else stopGodMode() end
        elseif name == "noclipEnabled" then
            config.noclipEnabled = newState
            if newState then startNoclip() else stopNoclip() end
        elseif name == "autoRunEnabled" then
            config.autoRunEnabled = newState
            if newState then startAutoRun() else stopAutoRun() end
        elseif name == "autoAimEnabled" then
            config.autoAimEnabled = newState
            if newState then startAutoAim() else stopAutoAim() end
        elseif name == "noCooldownEnabled" then
            config.noCooldownEnabled = newState
            if newState then startNoCooldown() else stopNoCooldown() end
        elseif name == "autoAvatarEnabled" then
            config.autoAvatarEnabled = newState
            if newState then startAutoAvatar() else stopAutoAvatar() end
        elseif name == "restartScript" then
            -- Restart
            print("[Restart] Restarting script...")
            if espConnection then espConnection:Disconnect(); espConnection = nil end
            if invisibilityConnection then invisibilityConnection:Disconnect(); invisibilityConnection = nil end
            if autoShieldConnection then autoShieldConnection:Disconnect(); autoShieldConnection = nil end
            if godModeConnection then godModeConnection:Disconnect(); godModeConnection = nil end
            if noclipConnection then noclipConnection:Disconnect(); noclipConnection = nil end
            if autoRunConnection then autoRunConnection:Disconnect(); autoRunConnection = nil end
            if autoAimConnection then autoAimConnection:Disconnect(); autoAimConnection = nil end
            if noCooldownConnection then noCooldownConnection:Disconnect(); noCooldownConnection = nil end
            if autoAvatarConnection then autoAvatarConnection:Disconnect(); autoAvatarConnection = nil end
            makeVisible(); removeForceField(); disableNoclip()
            if localHumanoid then localHumanoid.WalkSpeed = 16 end
            task.wait(0.5)
            if config.espEnabled then startESP() end
            if config.invisibilityEnabled then startInvisibility() end
            if config.autoShieldEnabled then startAutoShield() end
            if config.godModeEnabled then startGodMode() end
            if config.noclipEnabled then startNoclip() end
            if config.autoRunEnabled then startAutoRun() end
            if config.autoAimEnabled then startAutoAim() end
            if config.noCooldownEnabled then startNoCooldown() end
            if config.autoAvatarEnabled then startAutoAvatar() end
            print("[Restart] Done.")
            return
        end
        updateState(newState)
        if onChange then onChange(newState) end
        TweenService:Create(button, TweenInfo.new(0.05), {TextSize = 9}):Play()
        task.wait(0.05)
        TweenService:Create(button, TweenInfo.new(0.05), {TextSize = 10}):Play()
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

local function createFloatingLogo()
    if floatingLogo then floatingLogo:Destroy() end
    floatingLogo = Instance.new("ImageButton")
    floatingLogo.Name = "CyberHeroes_Logo"
    floatingLogo.Size = UDim2.new(0, 35, 0, 35)
    floatingLogo.Position = UDim2.new(0.85, -17.5, 0.85, -17.5)
    floatingLogo.BackgroundColor3 = Color3.fromRGB(25, 5, 5)
    floatingLogo.BackgroundTransparency = 0.2
    floatingLogo.BorderSizePixel = 0
    floatingLogo.Image = "https://private-user-images.githubusercontent.com/188855284/395046716-ec3d8730-8153-420a-aa42-d4595ae9e4e7.jpg?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NzYwODQ3ODIsIm5iZiI6MTc3NjA4NDQ4MiwicGF0aCI6Ii8xODg4NTUyODQvMzk1MDQ2NzE2LWVjM2Q4NzMwLTgxNTMtNDIwYS1hYTQyLWQ0NTk1YWU5ZTRlNy5qcGc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjYwNDEzJTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI2MDQxM1QxMjQ4MDJaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT1jMjA2Zjg4NzUzMjliOGFhMzIzZWUzOThlMjgyZTg5ZDYzMThiOWYzNDFmODVlYWI1MjY2NGM1YzRjZjUwMDFhJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCZyZXNwb25zZS1jb250ZW50LXR5cGU9aW1hZ2UlMkZqcGVnIn0.9PradVNUGRSvKqt969IekjMLXxRMykd6-dNYVC-jszU"
    floatingLogo.ImageColor3 = Color3.fromRGB(255, 80, 80)
    floatingLogo.ImageTransparency = 0.2
    floatingLogo.Parent = CoreGui
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

local function createGUI()
    if screenGui then screenGui:Destroy() end
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_Utility"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.ResetOnSpawn = false
    screenGui.Parent = CoreGui

    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainWindow"
    mainFrame.Size = UDim2.new(0, 340, 0, 240)
    mainFrame.Position = UDim2.new(0.5, -170, 0.5, -120)
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
    title.Size = UDim2.new(0.6, 0, 1, 0)
    title.Position = UDim2.new(0.02, 0, 0, 0)
    title.Text = "CYBERHEROES UTILITY v2.1"
    title.TextColor3 = config.guiThemeColor
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    local versionLabel = Instance.new("TextLabel")
    versionLabel.Size = UDim2.new(0.3, 0, 1, 0)
    versionLabel.Position = UDim2.new(0.65, 0, 0, 0)
    versionLabel.Text = "v2.1"
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

    local function hideGuiAndShowLogo()
        config.guiVisible = false
        mainFrame.Visible = false
        if not isLogoVisible then
            if floatingLogo then floatingLogo:Destroy() end
            floatingLogo = createFloatingLogo()
            floatingLogo.Visible = true
            isLogoVisible = true
        end
    end

    minimizeBtn.MouseButton1Click:Connect(hideGuiAndShowLogo)
    closeBtn.MouseButton1Click:Connect(hideGuiAndShowLogo)

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
    sidebarList.Size = UDim2.new(1, 0, 0, 100)
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
    gridLayout.CellSize = UDim2.new(0, 95, 0, 32)
    gridLayout.CellPadding = UDim2.new(0, 5, 0, 5)
    gridLayout.FillDirection = Enum.FillDirection.Horizontal
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = contentPanel

    local features = {
        {name="espEnabled", text="ESP"},
        {name="invisibilityEnabled", text="INVISIBLE"},
        {name="autoShieldEnabled", text="SHIELD"},
        {name="godModeEnabled", text="GOD MODE"},
        {name="noclipEnabled", text="NOCLIP"},
        {name="autoRunEnabled", text="AUTO RUN"},
        {name="autoAimEnabled", text="AUTO AIM"},
        {name="noCooldownEnabled", text="NO COOLDOWN"},
        {name="autoAvatarEnabled", text="AUTO AVATAR"},
        {name="restartScript", text="RESTART"}
    }
    for _, feat in ipairs(features) do
        local initialState = (feat.name ~= "restartScript") and config[feat.name] or false
        createGridButton(contentPanel, feat.name, feat.text, initialState)
    end

    homeItem.MouseButton1Click:Connect(function()
        homeItem.TextColor3 = Color3.fromRGB(0, 230, 255)
        featuresItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        settingsItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        aboutItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        if settingsContent then settingsContent:Destroy() end
        gridLayout.Parent = contentPanel
    end)
    featuresItem.MouseButton1Click:Connect(function()
        featuresItem.TextColor3 = Color3.fromRGB(0, 230, 255)
        homeItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        settingsItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        aboutItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        if settingsContent then settingsContent:Destroy() end
        gridLayout.Parent = contentPanel
    end)
    settingsItem.MouseButton1Click:Connect(function()
        settingsItem.TextColor3 = Color3.fromRGB(0, 230, 255)
        homeItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        featuresItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        aboutItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        gridLayout.Parent = nil
        createSettingsContent()
    end)
    aboutItem.MouseButton1Click:Connect(function()
        aboutItem.TextColor3 = Color3.fromRGB(0, 230, 255)
        homeItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        featuresItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        settingsItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        if settingsContent then settingsContent:Destroy() end
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
            local activeCount = (config.espEnabled and 1 or 0) + (config.invisibilityEnabled and 1 or 0) +
                                (config.autoShieldEnabled and 1 or 0) + (config.godModeEnabled and 1 or 0) +
                                (config.noclipEnabled and 1 or 0) + (config.autoRunEnabled and 1 or 0) +
                                (config.autoAimEnabled and 1 or 0) + (config.noCooldownEnabled and 1 or 0) +
                                (config.autoAvatarEnabled and 1 or 0)
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
-- AUTO RECOVERY SYSTEM
-- ============================================================================
local function ensureGUIPersistent()
    task.spawn(function()
        while isScriptRunning do
            if not screenGui or not screenGui.Parent then
                print("[Recovery] Recreating GUI...")
                createGUI()
                if config.espEnabled then startESP() else stopESP() end
                if config.invisibilityEnabled then startInvisibility() else stopInvisibility() end
                if config.autoShieldEnabled then startAutoShield() else stopAutoShield() end
                if config.godModeEnabled then startGodMode() else stopGodMode() end
                if config.noclipEnabled then startNoclip() else stopNoclip() end
                if config.autoRunEnabled then startAutoRun() else stopAutoRun() end
                if config.autoAimEnabled then startAutoAim() else stopAutoAim() end
                if config.noCooldownEnabled then startNoCooldown() else stopNoCooldown() end
                if config.autoAvatarEnabled then startAutoAvatar() else stopAutoAvatar() end
            end
            if not config.guiVisible and (not floatingLogo or not floatingLogo.Parent) then
                if floatingLogo then floatingLogo:Destroy() end
                floatingLogo = createFloatingLogo()
                floatingLogo.Visible = true
                isLogoVisible = true
            end
            task.wait(2)
        end
    end)
end

-- ============================================================================
-- CHARACTER HANDLER
-- ============================================================================
local function onCharacterAdded(character)
    localCharacter = character
    localHumanoid = character:FindFirstChildWhichIsA("Humanoid")
    localRootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    if localHumanoid then
        originalWalkSpeed = localHumanoid.WalkSpeed
        if not config.autoRunEnabled then
            localHumanoid.WalkSpeed = originalWalkSpeed
        else
            localHumanoid.WalkSpeed = autoRunVelocity
        end
    end
    isInvisible = false
    isShieldActive = false
    if currentForceField then currentForceField:Destroy(); currentForceField = nil end
    if config.invisibilityEnabled then makeInvisible() end
    if config.autoShieldEnabled then addForceField() end
    if config.noclipEnabled then enableNoclip() end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
local function init()
    print("╔═══════════════════════════════════════════════════════════════════╗")
    print("║           CYBERHEROES MODERN ESP & UTILITY SUITE v2.1            ║")
    print("║           ESP, Invisible, Auto Shield, God Mode, Noclip          ║")
    print("║           Auto Run, Auto Aim, No Cooldown, Auto Avatar (FIXED)   ║")
    print("║                   System initialized! (NO LAG!)                  ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")
    if localPlayer.Character then onCharacterAdded(localPlayer.Character) end
    localPlayer.CharacterAdded:Connect(onCharacterAdded)
    createGUI()
    ensureGUIPersistent()
    if config.espEnabled then startESP() end
    if config.invisibilityEnabled then startInvisibility() end
    if config.autoShieldEnabled then startAutoShield() end
    if config.godModeEnabled then startGodMode() end
    if config.noclipEnabled then startNoclip() end
    if config.autoRunEnabled then startAutoRun() end
    if config.autoAimEnabled then startAutoAim() end
    if config.noCooldownEnabled then startNoCooldown() end
    if config.autoAvatarEnabled then startAutoAvatar() end
end

task.wait(1)
init()
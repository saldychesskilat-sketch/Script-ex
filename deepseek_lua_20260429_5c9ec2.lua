--[[
╔═══════════════════════════════════════════════════════════════════════════╗
║                          KEMI_GABUT v1.0                                 ║
║                  Advanced Roblox Utility Script                          ║
║                        For Delta Executor                                ║
║                                                                          ║
║  Features:                                                               ║
║  ✓ Modern ESP (box, name, distance, health)                             ║
║  ✓ Noclip (passthrough walls)                                           ║
║  ✓ Permanent Auto Shield (forcefield)                                   ║
║  ✓ Tpwalk (adjustable speed via slider)                                 ║
║  ✓ Invisibility (transparent character)                                 ║
║  ✓ God Mode (immortal)                                                  ║
║  ✓ Auto Aim (crosshair lock with X-axis)                                ║
║  ✓ Draggable GUI with toggle (hide/show)                                ║
║  ✓ Futuristic neon style                                                ║
╚═══════════════════════════════════════════════════════════════════════════╝
--]]

-- ============================================================================
-- SERVICES
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local Debris = game:GetService("Debris")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local localCharacter = nil
local localHumanoid = nil
local localRootPart = nil

-- ============================================================================
-- PERSISTENT CONFIGURATION
-- ============================================================================
local _G = getgenv() or _G
if not _G.kemi_gabut then
    _G.kemi_gabut = {
        espEnabled = true,
        noclipEnabled = false,
        shieldEnabled = true,
        tpwalkEnabled = false,
        tpwalkSpeed = 32,
        invisibleEnabled = false,
        godModeEnabled = false,
        autoAimEnabled = false,
        guiVisible = true,
        espColor = Color3.fromRGB(0, 200, 255)  -- cyan neon
    }
end
local cfg = _G.kemi_gabut

-- ============================================================================
-- GLOBAL VARIABLES
-- ============================================================================
local espObjects = {}
local shieldLoop = nil
local tpwalkLoop = nil
local noClipLoop = nil
local godModeLoop = nil
local autoAimLoop = nil
local currentAimTarget = nil
local aimLockTimer = nil
local crosshair = nil
local screenGui = nil
local mainFrame = nil
local isGuiVisible = true
local isDragging = false

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
-- FEATURE 1: MODERN ESP
-- ============================================================================
local function createESP(player)
    if espObjects[player] then
        for _, obj in pairs(espObjects[player]) do
            pcall(function() obj:Remove() end)
        end
        espObjects[player] = nil
    end
    
    local char = player.Character
    if not char then return end
    
    local espParts = {}
    
    -- Box (Square)
    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Color = cfg.espColor
    box.Filled = false
    box.Visible = false
    espParts.box = box
    
    -- Outline (shadow effect)
    local outline = Drawing.new("Square")
    outline.Thickness = 2
    outline.Color = Color3.fromRGB(0, 0, 0)
    outline.Transparency = 0.7
    outline.Filled = false
    outline.Visible = false
    espParts.outline = outline
    
    -- Name text
    local nameText = Drawing.new("Text")
    nameText.Size = 14
    nameText.Font = Drawing.Fonts.UI
    nameText.Color = cfg.espColor
    nameText.Outline = true
    nameText.OutlineColor = Color3.fromRGB(0, 0, 0)
    nameText.Visible = false
    espParts.name = nameText
    
    -- Distance text
    local distText = Drawing.new("Text")
    distText.Size = 12
    distText.Font = Drawing.Fonts.UI
    distText.Color = Color3.fromRGB(200, 200, 200)
    distText.Outline = true
    distText.OutlineColor = Color3.fromRGB(0, 0, 0)
    distText.Visible = false
    espParts.distance = distText
    
    -- Health bar (optional, menggunakan Drawing)
    local healthBarBg = Drawing.new("Line")
    healthBarBg.Thickness = 3
    healthBarBg.Color = Color3.fromRGB(50, 50, 50)
    healthBarBg.Visible = false
    espParts.healthBg = healthBarBg
    
    local healthBar = Drawing.new("Line")
    healthBar.Thickness = 3
    healthBar.Color = Color3.fromRGB(0, 255, 0)
    healthBar.Visible = false
    espParts.health = healthBar
    
    espObjects[player] = espParts
end

local function updateESP()
    if not cfg.espEnabled then
        for _, parts in pairs(espObjects) do
            for _, obj in pairs(parts) do
                pcall(function() obj.Visible = false end)
            end
        end
        return
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player == localPlayer then
            if espObjects[player] then
                for _, obj in pairs(espObjects[player]) do
                    pcall(function() obj.Visible = false end)
                end
            end
            goto skip
        end
        
        local parts = espObjects[player]
        if not parts then
            createESP(player)
            parts = espObjects[player]
        end
        if not parts then goto skip end
        
        local char = player.Character
        if not char then
            for _, obj in pairs(parts) do pcall(function() obj.Visible = false end) end
            goto skip
        end
        
        local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        if not rootPart then goto skip end
        
        local pos, onScreen = camera:WorldToScreenPoint(rootPart.Position)
        if not onScreen then
            for _, obj in pairs(parts) do pcall(function() obj.Visible = false end) end
            goto skip
        end
        
        local size = 100 / (math.max(1, (camera.CFrame.Position - rootPart.Position).Magnitude / 20))
        local boxSize = Vector2.new(size, size * 1.5)
        local boxPos = Vector2.new(pos.X - boxSize.X/2, pos.Y - boxSize.Y/2)
        
        parts.outline.Position = boxPos
        parts.outline.Size = boxSize
        parts.outline.Visible = true
        
        parts.box.Position = boxPos
        parts.box.Size = boxSize
        parts.box.Visible = true
        
        -- Name
        parts.name.Text = player.Name
        parts.name.Position = Vector2.new(pos.X, boxPos.Y - 15)
        parts.name.Visible = true
        
        -- Distance
        local distance = (localRootPart and localRootPart.Position or Vector3.zero) - rootPart.Position
        local distVal = math.floor(distance.Magnitude)
        parts.distance.Text = distVal .. " studs"
        parts.distance.Position = Vector2.new(pos.X, boxPos.Y + boxSize.Y + 5)
        parts.distance.Visible = true
        
        -- Health bar
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local healthPercent = humanoid.Health / humanoid.MaxHealth
            local barWidth = boxSize.X
            local barX = boxPos.X
            local barY = boxPos.Y + boxSize.Y + 2
            
            parts.healthBg.From = Vector2.new(barX, barY)
            parts.healthBg.To = Vector2.new(barX + barWidth, barY)
            parts.healthBg.Visible = true
            
            parts.health.From = Vector2.new(barX, barY)
            parts.health.To = Vector2.new(barX + (barWidth * healthPercent), barY)
            parts.health.Color = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)
            parts.health.Visible = true
        else
            parts.healthBg.Visible = false
            parts.health.Visible = false
        end
        
        ::skip::
    end
end

-- ============================================================================
-- FEATURE 2: NOCLIP (Pass through walls)
-- ============================================================================
local function applyNoclip()
    if not cfg.noclipEnabled then
        if localCharacter then
            for _, part in ipairs(localCharacter:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
        return
    end
    if not localCharacter then return end
    for _, part in ipairs(localCharacter:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

local function startNoclipLoop()
    if noClipLoop then noClipLoop:Disconnect() end
    noClipLoop = RunService.Heartbeat:Connect(applyNoclip)
end

local function stopNoclipLoop()
    if noClipLoop then noClipLoop:Disconnect(); noClipLoop = nil end
    applyNoclip() -- reset
end

-- ============================================================================
-- FEATURE 3: AUTO SHIELD (Permanent ForceField)
-- ============================================================================
local currentForceField = nil
local function addForceField()
    if not cfg.shieldEnabled then return end
    if not localCharacter then return end
    if not localCharacter:FindFirstChild("kemi_Shield") then
        if currentForceField then currentForceField:Destroy() end
        currentForceField = Instance.new("ForceField")
        currentForceField.Name = "kemi_Shield"
        currentForceField.Parent = localCharacter
    end
end

local function startShieldLoop()
    if shieldLoop then shieldLoop:Disconnect() end
    shieldLoop = RunService.Heartbeat:Connect(function()
        if cfg.shieldEnabled then
            addForceField()
        else
            if currentForceField then currentForceField:Destroy(); currentForceField = nil end
        end
    end)
end

-- ============================================================================
-- FEATURE 4: TPWALK (Adjustable speed)
-- ============================================================================
local originalSpeed = 16
local isTpwalkActive = false

local function applyTpwalk()
    if not cfg.tpwalkEnabled then
        if isTpwalkActive then
            if localHumanoid then localHumanoid.WalkSpeed = originalSpeed end
            isTpwalkActive = false
        end
        return
    end
    if not localHumanoid then return end
    if not isTpwalkActive then
        originalSpeed = localHumanoid.WalkSpeed
        isTpwalkActive = true
    end
    localHumanoid.WalkSpeed = cfg.tpwalkSpeed
end

local function startTpwalkLoop()
    if tpwalkLoop then tpwalkLoop:Disconnect() end
    tpwalkLoop = RunService.Heartbeat:Connect(applyTpwalk)
end

-- ============================================================================
-- FEATURE 5: INVISIBILITY
-- ============================================================================
local function setInvisible()
    if not cfg.invisibleEnabled then
        if localCharacter then
            for _, part in ipairs(localCharacter:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Transparency = 0
                end
            end
        end
        return
    end
    if not localCharacter then return end
    for _, part in ipairs(localCharacter:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = 1
        end
    end
end

local function startInvisibleLoop()
    if invisibleLoop then invisibleLoop:Disconnect() end
    invisibleLoop = RunService.Heartbeat:Connect(setInvisible)
end
local invisibleLoop = nil

-- ============================================================================
-- FEATURE 6: GOD MODE (Immortal)
-- ============================================================================
local function applyGodMode()
    if not cfg.godModeEnabled then return end
    if not localHumanoid then return end
    local maxHealth = localHumanoid.MaxHealth
    if localHumanoid.Health < maxHealth then
        localHumanoid.Health = maxHealth
    end
end

local function startGodModeLoop()
    if godModeLoop then godModeLoop:Disconnect() end
    godModeLoop = RunService.Heartbeat:Connect(applyGodMode)
end

-- ============================================================================
-- FEATURE 7: AUTO AIM (Crosshair X axis lock)
-- ============================================================================
-- Create crosshair
local function createCrosshair()
    if crosshair then
        pcall(function() crosshair:Destroy() end)
        crosshair = nil
    end
    local crosshairGui = Instance.new("ScreenGui")
    crosshairGui.Name = "kemi_Crosshair"
    crosshairGui.ResetOnSpawn = false
    crosshairGui.Parent = CoreGui
    
    -- Garis horizontal (sumbu X)
    local lineH = Instance.new("Frame")
    lineH.Size = UDim2.new(0, 60, 0, 2)
    lineH.Position = UDim2.new(0.5, -30, 0.5, -1)
    lineH.BackgroundColor3 = cfg.espColor
    lineH.BackgroundTransparency = 0.3
    lineH.BorderSizePixel = 0
    lineH.Parent = crosshairGui
    
    -- Garis vertikal (opsional, untuk presisi)
    local lineV = Instance.new("Frame")
    lineV.Size = UDim2.new(0, 2, 0, 60)
    lineV.Position = UDim2.new(0.5, -1, 0.5, -30)
    lineV.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    lineV.BackgroundTransparency = 0.5
    lineV.BorderSizePixel = 0
    lineV.Parent = crosshairGui
    
    -- Dot tengah
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 4, 0, 4)
    dot.Position = UDim2.new(0.5, -2, 0.5, -2)
    dot.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    dot.BackgroundTransparency = 0.4
    dot.BorderSizePixel = 0
    dot.Parent = crosshairGui
    
    crosshair = crosshairGui
end

-- Mendeteksi player yang terdekat dengan sumbu X crosshair
local function getPlayerUnderCrosshair()
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local bestPlayer = nil
    local bestDistance = math.huge
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local char = player.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
                if root then
                    local screenPos, onScreen = camera:WorldToScreenPoint(root.Position)
                    if onScreen then
                        local deltaX = math.abs(screenPos.X - center.X)
                        -- hanya pertimbangkan jika dalam radius horizontal 100px
                        if deltaX < 100 and deltaX < bestDistance then
                            bestDistance = deltaX
                            bestPlayer = player
                        end
                    end
                end
            end
        end
    end
    return bestPlayer
end

local function lockCameraToPlayer(player)
    if not player or not player.Character then return end
    local targetRoot = player.Character:FindFirstChild("HumanoidRootPart") or player.Character:FindFirstChild("Torso")
    if targetRoot then
        local targetPos = targetRoot.Position
        camera.CFrame = CFrame.new(camera.CFrame.Position, targetPos)
    end
end

local function startAutoAim()
    if autoAimLoop then autoAimLoop:Disconnect() end
    autoAimLoop = RunService.RenderStepped:Connect(function()
        if not cfg.autoAimEnabled then return end
        if not getLocalCharacter() then return end
        
        local target = getPlayerUnderCrosshair()
        if target then
            if currentAimTarget ~= target then
                currentAimTarget = target
                -- Reset timer jika ganti target
                if aimLockTimer then aimLockTimer:Disconnect() end
                aimLockTimer = nil
            end
            lockCameraToPlayer(currentAimTarget)
            -- Timer 2 detik untuk lock
            if not aimLockTimer then
                aimLockTimer = task.delay(2, function()
                    currentAimTarget = nil
                    aimLockTimer = nil
                end)
            end
        else
            -- Jika tidak ada target, reset timer
            if aimLockTimer then
                aimLockTimer:Disconnect()
                aimLockTimer = nil
            end
            currentAimTarget = nil
        end
    end)
end

-- ============================================================================
-- GUI: DRAGGABLE, TOGGLE, FUTURISTIC STYLE
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

-- Helper membuat slider
local function createSlider(parent, yPos, text, minVal, maxVal, getter, setter)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.8, 0, 0, 18)
    label.Position = UDim2.new(0.1, 0, yPos, 0)
    label.Text = text .. ": " .. tostring(getter())
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 11
    label.Parent = parent
    
    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(0.8, 0, 0, 4)
    sliderBg.Position = UDim2.new(0.1, 0, yPos + 0.12, 0)
    sliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = parent
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(1, 0)
    bgCorner.Parent = sliderBg
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((getter() - minVal) / (maxVal - minVal), 0, 1, 0)
    fill.BackgroundColor3 = cfg.espColor
    fill.BorderSizePixel = 0
    fill.Parent = sliderBg
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill
    
    local dragging = false
    local function updateSlider(x)
        local relative = math.clamp((x - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
        local newVal = math.floor(minVal + relative * (maxVal - minVal))
        setter(newVal)
        label.Text = text .. ": " .. tostring(newVal)
        fill.Size = UDim2.new(relative, 0, 1, 0)
    end
    
    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            local mouse = localPlayer:GetMouse()
            updateSlider(mouse.X)
            local conn
            conn = mouse.Move:Connect(function()
                if dragging then updateSlider(mouse.X) end
            end)
            mouse.Button1Up:Connect(function()
                dragging = false
                conn:Disconnect()
            end)
        end
    end)
end

local function createToggleButton(parent, yPos, text, stateKey, onToggle)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.8, 0, 0, 30)
    btn.Position = UDim2.new(0.1, 0, yPos, 0)
    btn.Text = text .. (cfg[stateKey] and " [ON]" or " [OFF]")
    btn.BackgroundColor3 = cfg[stateKey] and Color3.fromRGB(40, 5, 5) or Color3.fromRGB(15, 0, 2)
    btn.TextColor3 = cfg[stateKey] and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = btn
    local stroke = Instance.new("UIStroke")
    stroke.Color = cfg[stateKey] and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(150, 30, 30)
    stroke.Thickness = 1
    stroke.Transparency = 0.3
    stroke.Parent = btn
    
    btn.MouseButton1Click:Connect(function()
        cfg[stateKey] = not cfg[stateKey]
        btn.Text = text .. (cfg[stateKey] and " [ON]" or " [OFF]")
        btn.BackgroundColor3 = cfg[stateKey] and Color3.fromRGB(40, 5, 5) or Color3.fromRGB(15, 0, 2)
        btn.TextColor3 = cfg[stateKey] and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)
        stroke.Color = cfg[stateKey] and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(150, 30, 30)
        if onToggle then onToggle(cfg[stateKey]) end
    end)
    return btn
end

local function createGUI()
    if screenGui then screenGui:Destroy() end
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "kemi_gabut_GUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = CoreGui
    
    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 280, 0, 460)
    mainFrame.Position = UDim2.new(0.5, -140, 0.5, -230)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 5, 10)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = mainFrame
    local stroke = Instance.new("UIStroke")
    stroke.Color = cfg.espColor
    stroke.Thickness = 1.5
    stroke.Transparency = 0.4
    stroke.Parent = mainFrame
    
    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 3, 7)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.7, 0, 1, 0)
    title.Position = UDim2.new(0.05, 0, 0, 0)
    title.Text = "⚡ KEMI_GABUT v1.0"
    title.TextColor3 = cfg.espColor
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Position = UDim2.new(1, -30, 0, 2)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function()
        cfg.guiVisible = false
        mainFrame.Visible = false
    end)
    
    -- Content scrolling frame
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, 0, 1, -35)
    scroll.Position = UDim2.new(0, 0, 0, 35)
    scroll.BackgroundTransparency = 1
    scroll.CanvasSize = UDim2.new(0, 0, 0, 420)
    scroll.ScrollBarThickness = 4
    scroll.Parent = mainFrame
    
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, 0, 0, 420)
    content.BackgroundTransparency = 1
    content.Parent = scroll
    
    -- Toggle buttons
    createToggleButton(content, 0.02, "ESP", "espEnabled", function(val)
        if val then updateESP() else updateESP() end
    end)
    createToggleButton(content, 0.12, "NOCLIP", "noclipEnabled", function(val)
        if val then startNoclipLoop() else stopNoclipLoop() end
    end)
    createToggleButton(content, 0.22, "AUTO SHIELD", "shieldEnabled", nil)
    createToggleButton(content, 0.32, "TPWALK", "tpwalkEnabled", nil)
    
    -- Speed slider (hanya jika tpwalk aktif)
    createSlider(content, 0.42, "TP Speed", 16, 120, function() return cfg.tpwalkSpeed end, function(v) cfg.tpwalkSpeed = v end)
    
    createToggleButton(content, 0.56, "INVISIBLE", "invisibleEnabled", nil)
    createToggleButton(content, 0.66, "GOD MODE", "godModeEnabled", nil)
    createToggleButton(content, 0.76, "AUTO AIM", "autoAimEnabled", nil)
    
    -- Status LED
    local statusBar = Instance.new("Frame")
    statusBar.Size = UDim2.new(0.9, 0, 0, 20)
    statusBar.Position = UDim2.new(0.05, 0, 0.92, 0)
    statusBar.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    statusBar.BackgroundTransparency = 0.2
    statusBar.BorderSizePixel = 0
    statusBar.Parent = content
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 4)
    statusCorner.Parent = statusBar
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 1, 0)
    statusLabel.Text = "⚡ SYSTEM READY"
    statusLabel.TextColor3 = cfg.espColor
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 9
    statusLabel.Parent = statusBar
    
    task.spawn(function()
        while screenGui do
            local active = (cfg.espEnabled and 1 or 0) + (cfg.noclipEnabled and 1 or 0) + (cfg.shieldEnabled and 1 or 0) +
                          (cfg.tpwalkEnabled and 1 or 0) + (cfg.invisibleEnabled and 1 or 0) + (cfg.godModeEnabled and 1 or 0) +
                          (cfg.autoAimEnabled and 1 or 0)
            statusLabel.Text = "⚡ ACTIVE FEATURES: " .. active
            task.wait(1)
        end
    end)
    
    makeDraggable(mainFrame)
end

-- ============================================================================
-- INITIALIZATION & LOOP CONTROL
-- ============================================================================
local espUpdateConnection = nil
local function startAll()
    if espUpdateConnection then espUpdateConnection:Disconnect() end
    espUpdateConnection = RunService.RenderStepped:Connect(updateESP)
    
    if cfg.noclipEnabled then startNoclipLoop() end
    if cfg.shieldEnabled then startShieldLoop() end
    if cfg.tpwalkEnabled then startTpwalkLoop() end
    if cfg.invisibleEnabled then startInvisibleLoop() end
    if cfg.godModeEnabled then startGodModeLoop() end
    if cfg.autoAimEnabled then startAutoAim() end
end

local function stopAll()
    if espUpdateConnection then espUpdateConnection:Disconnect() end
    if noClipLoop then noClipLoop:Disconnect(); noClipLoop = nil end
    if shieldLoop then shieldLoop:Disconnect(); shieldLoop = nil end
    if tpwalkLoop then tpwalkLoop:Disconnect(); tpwalkLoop = nil end
    if invisibleLoop then invisibleLoop:Disconnect(); invisibleLoop = nil end
    if godModeLoop then godModeLoop:Disconnect(); godModeLoop = nil end
    if autoAimLoop then autoAimLoop:Disconnect(); autoAimLoop = nil end
end

-- Keybind F untuk toggle GUI
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F then
        cfg.guiVisible = not cfg.guiVisible
        if mainFrame then
            mainFrame.Visible = cfg.guiVisible
        end
    end
end)

-- Karakter handler
local function onCharacterAdded(char)
    localCharacter = char
    localHumanoid = char:FindFirstChildWhichIsA("Humanoid")
    localRootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    if cfg.invisibleEnabled then setInvisible() end
    if cfg.noclipEnabled then applyNoclip() end
    if cfg.shieldEnabled then addForceField() end
end

if localPlayer.Character then
    onCharacterAdded(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(onCharacterAdded)

-- ============================================================================
-- MAIN
-- ============================================================================
createCrosshair()
createGUI()
startAll()

print("╔═══════════════════════════════════════════════════════════════════╗")
print("║                    KEMI_GABUT v1.0                               ║")
print("║                Advanced Roblox Utility Script                    ║")
print("║                   System initialized!                            ║")
print("║         Press F to toggle GUI | Drag anywhere                    ║")
print("╚═══════════════════════════════════════════════════════════════════╝")
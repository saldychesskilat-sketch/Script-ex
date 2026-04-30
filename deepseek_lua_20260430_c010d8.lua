--[[
    Script: kemi_gabut cyberheroes
    Untuk Delta Executor | Game: Violence District
    Fitur canggih: ESP futuristik, noclip, auto shield, invisible (slider), god mode, TPWalk (slider), auto aim periodik, GUI draggable neon
--]]

-- ============================================================================
-- SERVICES & GLOBALS
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local Camera = workspace.CurrentCamera

local localPlayer = Players.LocalPlayer
local localChar = nil
local localHumanoid = nil
local localRoot = nil

-- Drawing objects storage
local espObjects = {}
local linesToPlayers = {}

-- GUI elements
local screenGui = nil
local mainFrame = nil
local toggleButtons = {}
local sliderValues = {}

-- Fitur states
local features = {
    esp = false,
    noclip = false,
    autoShield = false,
    invisible = false,
    godMode = false,
    tpwalk = false,
    autoAim = false,
}
local tpwalkSpeed = 32        -- default speed multiplier
local invisibleAlpha = 0.5    -- default transparansi (0 = transparan, 1 = solid)
local currentShield = nil
local aimLocked = false
local aimTarget = nil
local reticle = nil
local reticleLines = {}       -- untuk crosshair

-- ============================================================================
-- UTILITIES
-- ============================================================================
local function updateLocalReferences()
    localChar = localPlayer.Character
    if localChar then
        localHumanoid = localChar:FindFirstChildWhichIsA("Humanoid")
        localRoot = localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("Torso") or localChar:FindFirstChild("UpperTorso")
    end
end

-- ============================================================================
-- ESP FUTURISTIK (kotak 3D, jarak, line ke player)
-- ============================================================================
local function createESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local char = player.Character
            if char and char.Parent == Workspace then
                if not espObjects[player] then
                    -- Kotak
                    local box = Drawing.new("Square")
                    box.Thickness = 1
                    box.Filled = false
                    box.Color = Color3.fromRGB(0, 200, 255)
                    box.Visible = false
                    -- Teks jarak
                    local distText = Drawing.new("Text")
                    distText.Color = Color3.fromRGB(200, 200, 200)
                    distText.Size = 14
                    distText.Center = true
                    distText.Outline = true
                    distText.OutlineColor = Color3.fromRGB(0,0,0)
                    distText.Visible = false
                    espObjects[player] = {box = box, text = distText}
                end
            end
        end
    end
end

local function updateESP()
    if not features.esp then
        for _, obj in pairs(espObjects) do
            obj.box.Visible = false
            obj.text.Visible = false
        end
        return
    end

    updateLocalReferences()
    if not localRoot then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local char = player.Character
            if char and char.Parent == Workspace then
                local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                if rootPart then
                    local screenPos, onScreen = Camera:WorldToScreenPoint(rootPart.Position)
                    if onScreen then
                        -- Hitung jarak
                        local dist = (localRoot.Position - rootPart.Position).Magnitude
                        local distText = string.format("%.1fm", dist)
                        -- Ukuran kotak proporsional dengan jarak (misal 100 / jarak)
                        local size = 100 / math.max(0.5, dist/10)
                        local boxSize = Vector2.new(size, size*1.5)
                        local topLeft = Vector2.new(screenPos.X - boxSize.X/2, screenPos.Y - boxSize.Y/2)
                        local bottomRight = Vector2.new(screenPos.X + boxSize.X/2, screenPos.Y + boxSize.Y/2)

                        if espObjects[player] then
                            espObjects[player].box.Position = topLeft
                            espObjects[player].box.Size = boxSize
                            espObjects[player].box.Visible = true
                            espObjects[player].text.Text = distText
                            espObjects[player].text.Position = Vector2.new(screenPos.X, screenPos.Y - boxSize.Y/2 - 10)
                            espObjects[player].text.Visible = true
                        end
                    else
                        if espObjects[player] then
                            espObjects[player].box.Visible = false
                            espObjects[player].text.Visible = false
                        end
                    end
                end
            else
                if espObjects[player] then
                    espObjects[player].box.Visible = false
                    espObjects[player].text.Visible = false
                end
            end
        end
    end
end

-- ============================================================================
-- NOCLIP (walkthrough parts)
-- ============================================================================
local function applyNoclip(state)
    updateLocalReferences()
    if not localChar then return end
    for _, part in ipairs(localChar:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = not state
        end
    end
end

-- ============================================================================
-- AUTO SHIELD PERMANEN
-- ============================================================================
local function addShield()
    if not features.autoShield then return end
    updateLocalReferences()
    if not localChar then return end
    if not localChar:FindFirstChild("kemi_shield") then
        local shield = Instance.new("ForceField")
        shield.Name = "kemi_shield"
        shield.Parent = localChar
        currentShield = shield
    end
end

local function shieldLoop()
    if features.autoShield then
        addShield()
    else
        if currentShield then currentShield:Destroy() end
        if localChar then
            for _, v in pairs(localChar:GetChildren()) do
                if v:IsA("ForceField") and v.Name == "kemi_shield" then
                    v:Destroy()
                end
            end
        end
        currentShield = nil
    end
end

-- ============================================================================
-- INVISIBLE (slider transparansi)
-- ============================================================================
local function applyInvisible()
    updateLocalReferences()
    if not localChar then return end
    for _, part in ipairs(localChar:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = features.invisible and invisibleAlpha or 0
        end
    end
end

-- ============================================================================
-- GOD MODE
-- ============================================================================
local function godModeLoop()
    updateLocalReferences()
    if features.godMode and localHumanoid then
        local maxHealth = localHumanoid.MaxHealth
        if localHumanoid.Health < maxHealth then
            localHumanoid.Health = maxHealth
        end
    end
end

-- ============================================================================
-- TPWALK (kecepatan slider)
-- ============================================================================
local function applyTpwalk()
    updateLocalReferences()
    if features.tpwalk and localHumanoid then
        localHumanoid.WalkSpeed = tpwalkSpeed
    elseif localHumanoid then
        -- reset ke default (biasanya 16)
        if localHumanoid.WalkSpeed == tpwalkSpeed then
            localHumanoid.WalkSpeed = 16
        end
    end
end

-- ============================================================================
-- AUTO AIM PERIODIK + RETICLE Sumbu X
-- ============================================================================
-- Buat crosshair (sumbu X) di tengah layar menggunakan Drawing
local function createReticle()
    local centerX = Camera.ViewportSize.X / 2
    local centerY = Camera.ViewportSize.Y / 2
    -- Garis horizontal
    local lineH = Drawing.new("Line")
    lineH.From = Vector2.new(centerX - 20, centerY)
    lineH.To = Vector2.new(centerX + 20, centerY)
    lineH.Color = Color3.fromRGB(0, 255, 255)
    lineH.Thickness = 2
    lineH.Visible = true
    -- Garis vertikal (opsional tapi biar terlihat seperti crosshair)
    local lineV = Drawing.new("Line")
    lineV.From = Vector2.new(centerX, centerY - 20)
    lineV.To = Vector2.new(centerX, centerY + 20)
    lineV.Color = Color3.fromRGB(0, 255, 255)
    lineV.Thickness = 2
    lineV.Visible = true
    -- Dot tengah
    local dot = Drawing.new("Square")
    dot.Size = Vector2.new(4,4)
    dot.Position = Vector2.new(centerX-2, centerY-2)
    dot.Color = Color3.fromRGB(255, 0, 0)
    dot.Filled = true
    dot.Visible = true
    return {lineH, lineV, dot}
end

local function getMouseTarget()
    -- Raycast dari kamera ke arah depan
    local mouseLocation = UserInputService:GetMouseLocation()
    local ray = Camera:ScreenPointToRay(mouseLocation.X, mouseLocation.Y)
    local hit, hitPos, hitNorm, hitMat = Workspace:FindPartOnRayWithIgnoreList(ray, {localChar})
    if hit then
        -- Cari pemain yang memiliki karakter berisi part yang terkena
        local hitPlayer = hit:FindFirstAncestorWhichIsA("Model")
        if hitPlayer and hitPlayer:FindFirstChild("Humanoid") then
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character == hitPlayer and player ~= localPlayer then
                    return player, hitPos
                end
            end
        end
    end
    return nil, nil
end

local function lockCameraToTarget(targetPlayer, duration)
    if aimLocked then return end
    aimLocked = true
    aimTarget = targetPlayer
    local targetChar = targetPlayer.Character
    if targetChar then
        local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("Torso")
        if targetRoot then
            local originalCF = Camera.CFrame
            -- Lock smooth? langsung saja
            local lockCF = CFrame.new(Camera.CFrame.Position, targetRoot.Position)
            Camera.CFrame = lockCF
            task.wait(duration)
            -- Kembalikan pelan-pelan (opsional)
            Camera.CFrame = originalCF
        end
    end
    aimLocked = false
    aimTarget = nil
end

local function autoAimLoop()
    if not features.autoAim then return end
    if aimLocked then return end
    local target, hitPos = getMouseTarget()
    if target then
        -- Lock selama 2 detik
        task.spawn(function()
            lockCameraToTarget(target, 2)
        end)
    end
end

-- ============================================================================
-- GUI MODERN (draggable, neon, slider)
-- ============================================================================
local function makeDraggable(frame)
    local dragging = false
    local dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    frame.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                      startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    frame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

local function createSlider(parent, y, text, minVal, maxVal, defaultValue, callback)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 0, 20)
    label.Position = UDim2.new(0.05, 0, y, 0)
    label.Text = text .. ": " .. tostring(defaultValue)
    label.TextColor3 = Color3.fromRGB(200,200,200)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.Parent = parent

    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(0.6, 0, 0, 6)
    sliderBg.Position = UDim2.new(0.05, 0, y+0.05, 0)
    sliderBg.BackgroundColor3 = Color3.fromRGB(30,30,40)
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1,0)
    corner.Parent = sliderBg

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((defaultValue - minVal)/(maxVal - minVal), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0,200,255)
    fill.BorderSizePixel = 0
    fill.Parent = sliderBg
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1,0)
    fillCorner.Parent = fill

    local dragging = false
    local function updateValue(x)
        local rel = math.clamp((x - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
        local val = minVal + rel * (maxVal - minVal)
        if text == "Speed" then
            tpwalkSpeed = val
        elseif text == "Transparansi" then
            invisibleAlpha = val
            applyInvisible()
        end
        label.Text = text .. ": " .. string.format("%.1f", val)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        if callback then callback(val) end
    end

    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateValue(input.Position.X)
            local connect
            connect = UserInputService.InputChanged:Connect(function(inp)
                if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
                    updateValue(inp.Position.X)
                end
            end)
            UserInputService.InputEnded:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = false
                    connect:Disconnect()
                end
            end)
        end
    end)
end

local function createToggleButton(parent, y, text, stateKey, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.6, 0, 0, 28)
    btn.Position = UDim2.new(0.05, 0, y, 0)
    btn.Text = text .. (features[stateKey] and " [ON]" or " [OFF]")
    btn.BackgroundColor3 = features[stateKey] and Color3.fromRGB(40,5,5) or Color3.fromRGB(20,20,30)
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.BorderSizePixel = 0
    btn.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,6)
    corner.Parent = btn
    local stroke = Instance.new("UIStroke")
    stroke.Color = features[stateKey] and Color3.fromRGB(0,200,255) or Color3.fromRGB(80,80,100)
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = btn

    btn.MouseButton1Click:Connect(function()
        features[stateKey] = not features[stateKey]
        btn.Text = text .. (features[stateKey] and " [ON]" or " [OFF]")
        btn.BackgroundColor3 = features[stateKey] and Color3.fromRGB(40,5,5) or Color3.fromRGB(20,20,30)
        stroke.Color = features[stateKey] and Color3.fromRGB(0,200,255) or Color3.fromRGB(80,80,100)
        if callback then callback(features[stateKey]) end
        -- Terapkan efek langsung
        if stateKey == "noclip" then
            applyNoclip(features.noclip)
        elseif stateKey == "autoShield" then
            shieldLoop()
        elseif stateKey == "invisible" then
            applyInvisible()
        elseif stateKey == "tpwalk" then
            applyTpwalk()
        -- autoAim tidak perlu action langsung karena loop terus
        end
    end)
    return btn
end

local function createGUI()
    if screenGui then screenGui:Destroy() end
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "kemi_gabut"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = CoreGui

    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 280, 0, 420)
    mainFrame.Position = UDim2.new(0.5, -140, 0.5, -210)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 5, 8)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = mainFrame
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0,200,255)
    stroke.Thickness = 2
    stroke.Transparency = 0.5
    stroke.Parent = mainFrame

    -- Title bar untuk drag
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1,0,0,30)
    titleBar.BackgroundColor3 = Color3.fromRGB(20,5,10)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0,10)
    titleCorner.Parent = titleBar
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1,0,1,0)
    title.Text = "kemi_gabut cyberheroes"
    title.TextColor3 = Color3.fromRGB(0,230,255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = titleBar

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0,25,0,25)
    closeBtn.Position = UDim2.new(1,-30,0,2)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255,100,100)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)

    -- Content
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1,-10,1,-40)
    content.Position = UDim2.new(0,5,0,35)
    content.BackgroundTransparency = 1
    content.Parent = mainFrame

    local y = 0
    createToggleButton(content, y, "ESP", "esp", nil)
    y = y + 0.09
    createToggleButton(content, y, "NOCLIP", "noclip", nil)
    y = y + 0.09
    createToggleButton(content, y, "AUTO SHIELD", "autoShield", nil)
    y = y + 0.09
    createToggleButton(content, y, "INVISIBLE", "invisible", nil)
    createSlider(content, y+0.04, "Transparansi", 0, 1, invisibleAlpha, function(val)
        applyInvisible()
    end)
    y = y + 0.16
    createToggleButton(content, y, "GOD MODE", "godMode", nil)
    y = y + 0.09
    createToggleButton(content, y, "TPWALK", "tpwalk", nil)
    createSlider(content, y+0.04, "Speed", 16, 100, tpwalkSpeed, function(val)
        applyTpwalk()
    end)
    y = y + 0.16
    createToggleButton(content, y, "AUTO AIM", "autoAim", nil)

    -- Status label
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(0.9,0,0,20)
    status.Position = UDim2.new(0.05,0,0.95,0)
    status.Text = "READY"
    status.TextColor3 = Color3.fromRGB(0,200,255)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.GothamBold
    status.TextSize = 10
    status.Parent = content

    -- Update status LED setiap detik
    task.spawn(function()
        while screenGui and screenGui.Parent do
            local activeCount = 0
            for k,v in pairs(features) do if v then activeCount = activeCount + 1 end end
            if activeCount > 0 then
                status.Text = "ACTIVE: " .. activeCount .. " modules"
                status.TextColor3 = Color3.fromRGB(0,255,0)
            else
                status.Text = "STANDBY"
                status.TextColor3 = Color3.fromRGB(150,50,50)
            end
            task.wait(1)
        end
    end)

    makeDraggable(mainFrame)
end

-- ============================================================================
-- MAIN LOOP & INIT
-- ============================================================================
local function mainLoop()
    createESP()
    createReticle()
    -- Loop utama RenderStepped untuk ESP dan auto aim detection (tanpa lock)
    RunService.RenderStepped:Connect(function()
        updateLocalReferences()
        updateESP()
        if features.autoAim and not aimLocked then
            autoAimLoop()
        end
    end)

    -- Loop Heartbeat untuk shield, god mode, tpwalk, invisible (agar stabil)
    RunService.Heartbeat:Connect(function()
        updateLocalReferences()
        shieldLoop()
        godModeLoop()
        applyTpwalk()
        if features.invisible then
            applyInvisible()
        end
        if features.noclip then
            applyNoclip(true)
        end
    end)
end

-- Inisialisasi
local function init()
    print("╔════════════════════════════════════════════════════════╗")
    print("║   kemi_gabut cyberheroes - Advanced Cheat Framework  ║")
    print("║          For Violence District | Delta Executor       ║")
    print("╚════════════════════════════════════════════════════════╝")
    createGUI()
    mainLoop()
end

task.wait(1)
init()
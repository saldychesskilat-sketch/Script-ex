--[[
    CYBERHEROES MASS TELEPORT TEST v1.0
    Untuk Delta Executor (Roblox)
    Mencari RemoteEvent dan mencoba memicu teleportasi semua pemain ke "Fininshline"
    Menampilkan log, membandingkan posisi pemain, dan memberikan rekomendasi
    Tidak merusak, hanya uji coba eksploratif
--]]

-- ============================================================================
-- SERVICES
-- ============================================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")

local localPlayer = Players.LocalPlayer

-- ============================================================================
-- STATE & GUI
-- ============================================================================
local screenGui = nil
local mainFrame = nil
local logFrame = nil
local logListLayout = nil
local testButton = nil
local resetButton = nil
local statusLabel = nil
local autoTestButton = nil
local autoTestActive = false
local autoTestConnection = nil

-- Data untuk perbandingan posisi
local initialPositions = {}  -- player -> position
local finalPositions = {}

-- Log array
local logMessages = {}
local MAX_LOG = 30

-- ============================================================================
-- UTILITIES
-- ============================================================================
local function addLog(msg, color)
    color = color or Color3.fromRGB(200, 200, 200)
    table.insert(logMessages, 1, {text = msg, color = color})
    if #logMessages > MAX_LOG then table.remove(logMessages) end
    -- Update UI
    if logListLayout and logFrame then
        for _, child in ipairs(logFrame:GetChildren()) do
            if child:IsA("TextLabel") then child:Destroy() end
        end
        for i = #logMessages, 1, -1 do
            local log = logMessages[i]
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 0, 16)
            label.Text = log.text
            label.TextColor3 = log.color
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.Gotham
            label.TextSize = 10
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Parent = logFrame
        end
        logFrame.CanvasSize = UDim2.new(0, 0, 0, #logMessages * 18)
    end
end

local function clearLogs()
    logMessages = {}
    if logFrame then
        for _, child in ipairs(logFrame:GetChildren()) do
            if child:IsA("TextLabel") then child:Destroy() end
        end
    end
    addLog("Log cleared.", Color3.fromRGB(255, 255, 255))
end

-- ============================================================================
-- PENGUMPULAN POSISI PEMAIN
-- ============================================================================
local function capturePlayerPositions()
    local positions = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
            if root then
                positions[player] = root.Position
            end
        end
    end
    return positions
end

local function comparePositions(initial, final)
    local changes = {}
    for player, pos1 in pairs(initial) do
        local pos2 = final[player]
        if pos2 then
            local dist = (pos1 - pos2).Magnitude
            if dist > 5 then -- dianggap berubah jika bergerak lebih dari 5 studs
                changes[player] = dist
            end
        end
    end
    return changes
end

-- ============================================================================
-- PENCARIAN REMOTEEVENT
-- ============================================================================
local function findAllRemoteEvents()
    local events = {}
    local containers = {ReplicatedStorage, Workspace, Lighting}
    for _, container in ipairs(containers) do
        for _, obj in ipairs(container:GetDescendants()) do
            if obj:IsA("RemoteEvent") then
                table.insert(events, obj)
            end
        end
    end
    return events
end

-- ============================================================================
-- PENGIRIMAN SINYAL KE REMOTEEVENT
-- ============================================================================
local function tryFireRemoteEvent(remote, ...)
    local success, err = pcall(function()
        remote:FireServer(...)
    end)
    return success, err
end

-- ============================================================================
-- UJI COBA TELEPORTASI MASSAL
-- ============================================================================
local function testMassTeleport()
    addLog("========== STARTING MASS TELEPORT TEST ==========", Color3.fromRGB(255, 255, 0))
    
    -- Cari finishline
    local finishline = nil
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "Fininshline" then
            finishline = obj
            break
        end
    end
    if not finishline then
        addLog("ERROR: 'Fininshline' object not found in workspace!", Color3.fromRGB(255, 0, 0))
        addLog("Test cannot proceed.", Color3.fromRGB(255, 0, 0))
        return
    end
    local finishPos = finishline:IsA("BasePart") and finishline.Position or (finishline:FindFirstChildWhichIsA("BasePart") and finishline:FindFirstChildWhichIsA("BasePart").Position)
    if not finishPos then
        addLog("ERROR: Cannot determine position of Fininshline.", Color3.fromRGB(255, 0, 0))
        return
    end
    addLog("Found Fininshline at " .. tostring(finishPos), Color3.fromRGB(0, 255, 0))
    
    -- Catat posisi awal semua pemain
    addLog("Capturing initial player positions...", Color3.fromRGB(200, 200, 200))
    initialPositions = capturePlayerPositions()
    if #initialPositions == 0 then
        addLog("No players found (including yourself?)", Color3.fromRGB(255, 200, 0))
    else
        addLog("Captured positions for " .. #initialPositions .. " players.", Color3.fromRGB(0, 255, 0))
    end
    
    -- Cari semua RemoteEvent
    local remoteEvents = findAllRemoteEvents()
    addLog("Found " .. #remoteEvents .. " RemoteEvent(s) in game.", Color3.fromRGB(0, 200, 255))
    for _, ev in ipairs(remoteEvents) do
        addLog(" - " .. ev:GetFullName(), Color3.fromRGB(150, 150, 150))
    end
    
    if #remoteEvents == 0 then
        addLog("No RemoteEvent found. Cannot proceed.", Color3.fromRGB(255, 0, 0))
        addLog("Recommendation: If you own the game, add a RemoteEvent to ReplicatedStorage.", Color3.fromRGB(255, 200, 0))
        return
    end
    
    -- Coba kirim sinyal ke setiap RemoteEvent dengan berbagai argumen
    local anySuccess = false
    for _, remote in ipairs(remoteEvents) do
        local argsList = {
            {},
            {"all"},
            {"teleport"},
            {localPlayer},
            {localPlayer.Name},
            {"all", finishPos},
            {finishPos},
            {finishline},
            {"teleport", "all"},
            {"finishline"}
        }
        for _, args in ipairs(argsList) do
            local success, err = tryFireRemoteEvent(remote, table.unpack(args))
            if success then
                addLog("✓ Successfully fired " .. remote.Name .. " with args: " .. (next(args) and table.concat(args, ", ") or "none"), Color3.fromRGB(0, 255, 0))
                anySuccess = true
            else
                addLog("✗ Failed to fire " .. remote.Name .. " with args: " .. (next(args) and table.concat(args, ", ") or "none") .. " - " .. tostring(err), Color3.fromRGB(255, 100, 100))
            end
            task.wait(0.1)
        end
    end
    
    if not anySuccess then
        addLog("No RemoteEvent could be fired successfully.", Color3.fromRGB(255, 100, 0))
    else
        addLog("Waiting 2 seconds for potential effects...", Color3.fromRGB(200, 200, 200))
        task.wait(2)
    end
    
    -- Bandingkan posisi setelah percobaan
    addLog("Capturing final player positions...", Color3.fromRGB(200, 200, 200))
    finalPositions = capturePlayerPositions()
    local changes = comparePositions(initialPositions, finalPositions)
    
    if next(changes) then
        addLog("=== PLAYER MOVEMENT DETECTED! ===", Color3.fromRGB(0, 255, 0))
        for player, dist in pairs(changes) do
            addLog("   " .. player.Name .. " moved " .. math.floor(dist) .. " studs", Color3.fromRGB(0, 200, 255))
        end
        addLog("This indicates that some RemoteEvent may have triggered a teleport or knockback effect.", Color3.fromRGB(0, 255, 0))
        addLog("However, mass teleport to Fininshline may not be directly supported.", Color3.fromRGB(255, 200, 0))
    else
        addLog("No player movement detected.", Color3.fromRGB(255, 100, 100))
        addLog("Conclusion: No RemoteEvent caused teleportation of all players.", Color3.fromRGB(255, 200, 0))
        addLog("Recommendation: You may need to add a custom RemoteEvent to the game (if you own it).", Color3.fromRGB(255, 200, 0))
    end
    
    addLog("========== TEST COMPLETED ==========", Color3.fromRGB(255, 255, 0))
end

-- ============================================================================
-- AUTO TEST LOOP (OPSIONAL)
-- ============================================================================
local function startAutoTest()
    if autoTestActive then
        addLog("Auto test already running.", Color3.fromRGB(255, 200, 0))
        return
    end
    autoTestActive = true
    autoTestButton.Text = "STOP AUTO TEST"
    addLog("Auto test started (will repeat every 10 seconds).", Color3.fromRGB(0, 255, 0))
    if autoTestConnection then autoTestConnection:Disconnect() end
    autoTestConnection = RunService.Heartbeat:Connect(function()
        if not autoTestActive then return end
        if tick() % 10 < 0.05 then
            testMassTeleport()
        end
    end)
end

local function stopAutoTest()
    if autoTestConnection then
        autoTestConnection:Disconnect()
        autoTestConnection = nil
    end
    autoTestActive = false
    autoTestButton.Text = "AUTO TEST (LOOP)"
    addLog("Auto test stopped.", Color3.fromRGB(255, 100, 100))
end

local function toggleAutoTest()
    if autoTestActive then
        stopAutoTest()
    else
        startAutoTest()
    end
end

-- ============================================================================
-- GUI CREATION
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

local function createGUI()
    if screenGui then screenGui:Destroy() end
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_MassTeleportTest"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = CoreGui

    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 400, 0, 450)
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -225)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 5, 10)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 200, 255)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.4
    stroke.Parent = mainFrame

    -- Title bar
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
    title.Size = UDim2.new(0.7, 0, 1, 0)
    title.Position = UDim2.new(0.05, 0, 0, 0)
    title.Text = "MASS TELEPORT TEST v1.0"
    title.TextColor3 = Color3.fromRGB(0, 230, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 11
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 20, 0, 20)
    closeBtn.Position = UDim2.new(1, -24, 0, 2)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)

    -- Content
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -10, 1, -30)
    content.Position = UDim2.new(0, 5, 0, 28)
    content.BackgroundTransparency = 1
    content.Parent = mainFrame

    -- Status label
    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0.9, 0, 0, 20)
    statusLabel.Position = UDim2.new(0.05, 0, 0.05, 0)
    statusLabel.Text = "Ready"
    statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 10
    statusLabel.Parent = content

    -- Log frame (ScrollingFrame)
    logFrame = Instance.new("ScrollingFrame")
    logFrame.Size = UDim2.new(0.9, 0, 0, 280)
    logFrame.Position = UDim2.new(0.05, 0, 0.15, 0)
    logFrame.BackgroundColor3 = Color3.fromRGB(10, 0, 2)
    logFrame.BackgroundTransparency = 0.3
    logFrame.BorderSizePixel = 0
    logFrame.ScrollBarThickness = 6
    logFrame.Parent = content
    local logCorner = Instance.new("UICorner")
    logCorner.CornerRadius = UDim.new(0, 4)
    logCorner.Parent = logFrame
    logListLayout = Instance.new("UIListLayout")
    logListLayout.Padding = UDim.new(0, 2)
    logListLayout.Parent = logFrame

    -- Buttons
    testButton = Instance.new("TextButton")
    testButton.Size = UDim2.new(0.28, 0, 0, 30)
    testButton.Position = UDim2.new(0.05, 0, 0.8, 0)
    testButton.Text = "TEST TELEPORT"
    testButton.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    testButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    testButton.Font = Enum.Font.GothamBold
    testButton.TextSize = 11
    testButton.Parent = content
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = testButton
    testButton.MouseButton1Click:Connect(testMassTeleport)

    resetButton = Instance.new("TextButton")
    resetButton.Size = UDim2.new(0.28, 0, 0, 30)
    resetButton.Position = UDim2.new(0.36, 0, 0.8, 0)
    resetButton.Text = "CLEAR LOG"
    resetButton.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    resetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    resetButton.Font = Enum.Font.GothamBold
    resetButton.TextSize = 11
    resetButton.Parent = content
    local resetCorner = Instance.new("UICorner")
    resetCorner.CornerRadius = UDim.new(0, 4)
    resetCorner.Parent = resetButton
    resetButton.MouseButton1Click:Connect(clearLogs)

    autoTestButton = Instance.new("TextButton")
    autoTestButton.Size = UDim2.new(0.28, 0, 0, 30)
    autoTestButton.Position = UDim2.new(0.67, 0, 0.8, 0)
    autoTestButton.Text = "AUTO TEST (LOOP)"
    autoTestButton.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    autoTestButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoTestButton.Font = Enum.Font.GothamBold
    autoTestButton.TextSize = 11
    autoTestButton.Parent = content
    local autoCorner = Instance.new("UICorner")
    autoCorner.CornerRadius = UDim.new(0, 4)
    autoCorner.Parent = autoTestButton
    autoTestButton.MouseButton1Click:Connect(toggleAutoTest)

    makeDraggable(mainFrame)

    -- Fade in
    mainFrame.BackgroundTransparency = 0.3
    TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.1}):Play()
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
local function init()
    print("╔═══════════════════════════════════════════════════════════════════╗")
    print("║           CYBERHEROES MASS TELEPORT TEST v1.0                    ║")
    print("║           Mencari RemoteEvent dan mencoba teleportasi massal     ║")
    print("║                   System initialized!                            ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")
    createGUI()
    addLog("GUI loaded. Click 'TEST TELEPORT' to start.", Color3.fromRGB(0, 255, 0))
end

task.wait(1)
init()
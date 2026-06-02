--[[
    CYBERHEROES AUTO PARRY (REACTIVE) - Violence District
    Menggunakan event-driven attack detection, bukan spam.
    State machine: IDLE -> ARMED -> PARRYING -> COOLDOWN
    Dagger remote events: parry & parryResult
    Radius detection, reaction delay adjustable via GUI
    Circle ESP menunjukkan radius deteksi.
--]]

-- ============================================================================
-- SERVICES & GLOBALS
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local localPlayer = Players.LocalPlayer
local localCharacter = nil
local localRootPart = nil

-- ============================================================================
-- REMOTE CACHING
-- ============================================================================
local parryRemote = nil
local parryResultRemote = nil
local attackEventRemote = nil

local function cacheRemotes()
    local repStorage = game:GetService("ReplicatedStorage")
    local remotes = repStorage:FindFirstChild("Remotes")
    if remotes then
        local items = remotes:FindFirstChild("Items")
        if items then
            local dagger = items:FindFirstChild("Parrying Dagger")
            if dagger then
                parryRemote = dagger:FindFirstChild("parry")
                parryResultRemote = dagger:FindFirstChild("parryResult")
            end
        end
        attackEventRemote = remotes:FindFirstChild("AttackEvent")
    end
    -- Fallback: scan jika masih nil
    if not parryRemote then
        for _, obj in ipairs(repStorage:GetDescendants()) do
            if obj.Name == "parry" and obj:IsA("RemoteEvent") then
                parryRemote = obj
            elseif obj.Name == "parryResult" and obj:IsA("RemoteEvent") then
                parryResultRemote = obj
            elseif obj.Name == "AttackEvent" and obj:IsA("RemoteEvent") then
                attackEventRemote = obj
            end
        end
    end
    print("[AutoParry] Remotes cached: parry=", parryRemote ~= nil, " parryResult=", parryResultRemote ~= nil, " attackEvent=", attackEventRemote ~= nil)
end

-- ============================================================================
-- STATE MACHINE
-- ============================================================================
local State = {
    IDLE = 1,
    ARMED = 2,
    PARRYING = 3,
    COOLDOWN = 4
}
local currentState = State.IDLE
local currentStateName = "IDLE"
local stateStartTime = 0
local cooldownDuration = 0.5   -- detik setelah parry selesai sebelum kembali IDLE

-- Konfigurasi dari GUI
local config = {
    radius = 10,        -- jarak deteksi (1-15)
    reactionDelay = 0.3 -- delay sebelum fire parry (0.1-1)
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================
local function getLocalCharacter()
    localCharacter = localPlayer.Character
    if localCharacter then
        localRootPart = localCharacter:FindFirstChild("HumanoidRootPart") or localCharacter:FindFirstChild("Torso") or localCharacter:FindFirstChild("UpperTorso")
    end
    return localCharacter
end

local function isPlayerKiller(player)
    if not player then return false end
    if player.Team then
        local teamName = player.Team.Name:lower()
        if teamName:find("killer") or teamName:find("monster") or teamName:find("enemy") then
            return true
        end
    end
    local char = player.Character
    if char then
        local tool = char:FindFirstChildWhichIsA("Tool")
        if tool and (tool.Name:lower():find("knife") or tool.Name:lower():find("weapon")) then
            return true
        end
    end
    return false
end

local function getNearestKillerDistance()
    if not localRootPart then return math.huge end
    local localPos = localRootPart.Position
    local nearestDist = math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and isPlayerKiller(player) then
            local char = player.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                if root then
                    local dist = (localPos - root.Position).Magnitude
                    if dist < nearestDist then
                        nearestDist = dist
                    end
                end
            end
        end
    end
    return nearestDist
end

-- Fire parry remote (tanpa argumen atau dengan argumen dagger)
local function fireParry()
    if not parryRemote then return false end
    -- Coba dengan berbagai kemungkinan argumen (disesuaikan dengan game)
    local daggerTool = nil
    if localCharacter then
        daggerTool = localCharacter:FindFirstChild("Parrying Dagger") or localPlayer.Backpack:FindFirstChild("Parrying Dagger")
    end
    pcall(function()
        if daggerTool then
            parryRemote:FireServer(daggerTool)
        else
            parryRemote:FireServer()
        end
    end)
    return true
end

-- ============================================================================
-- CORE EVENT HANDLERS
-- ============================================================================
local attackEventConnection = nil
local parryResultConnection = nil
local killerCheckConnection = nil
local radiusUpdateConnection = nil
local circlePart = nil  -- untuk ESP lingkaran

-- Handler ketika AttackEvent terjadi (serangan dari killer)
local function onAttackEvent(...)
    if currentState ~= State.ARMED then return end
    -- Ubah state ke PARRYING, lalu setelah delay fire parry
    currentState = State.PARRYING
    currentStateName = "PARRYING"
    print("[AutoParry] Attack detected! Firing parry after delay:", config.reactionDelay)
    task.wait(config.reactionDelay)
    if currentState == State.PARRYING then
        fireParry()
        -- State akan berubah saat mendapatkan parryResult (success/fail)
        -- atau jika timeout, fallback ke COOLDOWN
        task.spawn(function()
            task.wait(1) -- timeout jika tidak ada result
            if currentState == State.PARRYING then
                print("[AutoParry] Parry result timeout, entering cooldown")
                currentState = State.COOLDOWN
                currentStateName = "COOLDOWN"
                task.wait(cooldownDuration)
                currentState = State.IDLE
                currentStateName = "IDLE"
            end
        end)
    end
end

-- Handler hasil parry dari server
local function onParryResult(success)
    print("[AutoParry] Parry result received:", success)
    if currentState == State.PARRYING then
        -- Masuk cooldown sebentar lalu IDLE
        currentState = State.COOLDOWN
        currentStateName = "COOLDOWN"
        task.wait(cooldownDuration)
        currentState = State.IDLE
        currentStateName = "IDLE"
    end
end

-- ============================================================================
-- RADIUS CHECK LOOP (ARMED / IDLE)
-- ============================================================================
local function updateStateByDistance()
    if not localRootPart then return end
    local nearestDist = getNearestKillerDistance()
    local isInRadius = (nearestDist <= config.radius)
    if currentState == State.IDLE and isInRadius then
        currentState = State.ARMED
        currentStateName = "ARMED"
        print("[AutoParry] Killer in radius, ARMED")
    elseif currentState == State.ARMED and not isInRadius then
        currentState = State.IDLE
        currentStateName = "IDLE"
        print("[AutoParry] Killer out of radius, back to IDLE")
    end
    -- Update visual lingkaran
    if circlePart then
        local newSize = config.radius * 2
        circlePart.Size = Vector3.new(newSize, 0.2, newSize)
    end
end

-- ============================================================================
-- GUI (Draggable + Sliders + Status)
-- ============================================================================
local screenGui = nil
local mainFrame = nil
local statusLabel = nil
local radiusSlider = nil
local radiusValueLabel = nil
local delaySlider = nil
local delayValueLabel = nil
local toggleButton = nil
local isGuiVisible = true

local function createGUI()
    if screenGui then screenGui:Destroy() end
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoParryGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = CoreGui

    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 220, 0, 160)
    mainFrame.Position = UDim2.new(0.02, 0, 0.7, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 5, 10)
    mainFrame.BackgroundTransparency = 0.2
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 230, 255)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.5
    stroke.Parent = mainFrame

    -- Draggable
    local dragging = false
    local dragStart, startPos
    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)
    mainFrame.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                          startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    mainFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 25)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.Text = "⚔️ AUTO PARRY ⚔️"
    title.TextColor3 = Color3.fromRGB(0, 230, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.Parent = mainFrame

    -- Status
    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 0, 20)
    statusLabel.Position = UDim2.new(0, 0, 0, 28)
    statusLabel.Text = "STATUS: IDLE"
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 10
    statusLabel.Parent = mainFrame

    -- Radius slider
    local radiusLabel = Instance.new("TextLabel")
    radiusLabel.Size = UDim2.new(0.5, 0, 0, 20)
    radiusLabel.Position = UDim2.new(0.05, 0, 0, 52)
    radiusLabel.Text = "Radius:"
    radiusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    radiusLabel.BackgroundTransparency = 1
    radiusLabel.Font = Enum.Font.Gotham
    radiusLabel.TextSize = 10
    radiusLabel.TextXAlignment = Enum.TextXAlignment.Left
    radiusLabel.Parent = mainFrame

    radiusValueLabel = Instance.new("TextLabel")
    radiusValueLabel.Size = UDim2.new(0.3, 0, 0, 20)
    radiusValueLabel.Position = UDim2.new(0.65, 0, 0, 52)
    radiusValueLabel.Text = tostring(config.radius) .. " studs"
    radiusValueLabel.TextColor3 = Color3.fromRGB(0, 230, 255)
    radiusValueLabel.BackgroundTransparency = 1
    radiusValueLabel.Font = Enum.Font.Gotham
    radiusValueLabel.TextSize = 10
    radiusValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    radiusValueLabel.Parent = mainFrame

    radiusSlider = Instance.new("TextButton")
    radiusSlider.Size = UDim2.new(0.85, 0, 0, 4)
    radiusSlider.Position = UDim2.new(0.075, 0, 0, 74)
    radiusSlider.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    radiusSlider.BackgroundTransparency = 0.3
    radiusSlider.BorderSizePixel = 0
    radiusSlider.Parent = mainFrame
    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(1, 0)
    sliderCorner.Parent = radiusSlider
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((config.radius - 1) / 14, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 230, 255)
    fill.BorderSizePixel = 0
    fill.Parent = radiusSlider
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local function updateRadius(x)
        local rel = math.clamp((x - radiusSlider.AbsolutePosition.X) / radiusSlider.AbsoluteSize.X, 0, 1)
        local newRad = math.floor(1 + rel * 14)
        config.radius = newRad
        radiusValueLabel.Text = tostring(config.radius) .. " studs"
        fill.Size = UDim2.new(rel, 0, 1, 0)
        if circlePart then
            circlePart.Size = Vector3.new(config.radius * 2, 0.2, config.radius * 2)
        end
    end
    local draggingRadius = false
    radiusSlider.MouseButton1Down:Connect(function()
        draggingRadius = true
        local mouse = localPlayer:GetMouse()
        updateRadius(mouse.X)
        local conn
        conn = mouse.Move:Connect(function()
            if draggingRadius then updateRadius(mouse.X) end
        end)
        mouse.Button1Up:Connect(function()
            draggingRadius = false
            conn:Disconnect()
        end)
    end)

    -- Delay slider
    local delayLabel = Instance.new("TextLabel")
    delayLabel.Size = UDim2.new(0.5, 0, 0, 20)
    delayLabel.Position = UDim2.new(0.05, 0, 0, 88)
    delayLabel.Text = "Reaction Delay:"
    delayLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    delayLabel.BackgroundTransparency = 1
    delayLabel.Font = Enum.Font.Gotham
    delayLabel.TextSize = 10
    delayLabel.TextXAlignment = Enum.TextXAlignment.Left
    delayLabel.Parent = mainFrame

    delayValueLabel = Instance.new("TextLabel")
    delayValueLabel.Size = UDim2.new(0.3, 0, 0, 20)
    delayValueLabel.Position = UDim2.new(0.65, 0, 0, 88)
    delayValueLabel.Text = string.format("%.2f s", config.reactionDelay)
    delayValueLabel.TextColor3 = Color3.fromRGB(0, 230, 255)
    delayValueLabel.BackgroundTransparency = 1
    delayValueLabel.Font = Enum.Font.Gotham
    delayValueLabel.TextSize = 10
    delayValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    delayValueLabel.Parent = mainFrame

    delaySlider = Instance.new("TextButton")
    delaySlider.Size = UDim2.new(0.85, 0, 0, 4)
    delaySlider.Position = UDim2.new(0.075, 0, 0, 110)
    delaySlider.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    delaySlider.BackgroundTransparency = 0.3
    delaySlider.BorderSizePixel = 0
    delaySlider.Parent = mainFrame
    local delaySliderCorner = Instance.new("UICorner")
    delaySliderCorner.CornerRadius = UDim.new(1, 0)
    delaySliderCorner.Parent = delaySlider
    local delayFill = Instance.new("Frame")
    delayFill.Size = UDim2.new((config.reactionDelay - 0.1) / 0.9, 0, 1, 0)
    delayFill.BackgroundColor3 = Color3.fromRGB(0, 230, 255)
    delayFill.BorderSizePixel = 0
    delayFill.Parent = delaySlider
    local delayFillCorner = Instance.new("UICorner")
    delayFillCorner.CornerRadius = UDim.new(1, 0)
    delayFillCorner.Parent = delayFill

    local function updateDelay(x)
        local rel = math.clamp((x - delaySlider.AbsolutePosition.X) / delaySlider.AbsoluteSize.X, 0, 1)
        local newDelay = 0.1 + rel * 0.9
        config.reactionDelay = newDelay
        delayValueLabel.Text = string.format("%.2f s", config.reactionDelay)
        delayFill.Size = UDim2.new(rel, 0, 1, 0)
    end
    local draggingDelay = false
    delaySlider.MouseButton1Down:Connect(function()
        draggingDelay = true
        local mouse = localPlayer:GetMouse()
        updateDelay(mouse.X)
        local conn
        conn = mouse.Move:Connect(function()
            if draggingDelay then updateDelay(mouse.X) end
        end)
        mouse.Button1Up:Connect(function()
            draggingDelay = false
            conn:Disconnect()
        end)
    end)

    -- Toggle button (hide/show GUI)
    toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(0.8, 0, 0, 25)
    toggleButton.Position = UDim2.new(0.1, 0, 0, 128)
    toggleButton.Text = "HIDE"
    toggleButton.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    toggleButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.TextSize = 10
    toggleButton.BorderSizePixel = 0
    toggleButton.Parent = mainFrame
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 4)
    toggleCorner.Parent = toggleButton
    toggleButton.MouseButton1Click:Connect(function()
        isGuiVisible = not isGuiVisible
        mainFrame.Visible = isGuiVisible
        toggleButton.Text = isGuiVisible and "HIDE" or "SHOW"
    end)

    -- Update status label periodically
    task.spawn(function()
        while screenGui and screenGui.Parent do
            if statusLabel then
                statusLabel.Text = "STATUS: " .. currentStateName
                if currentState == State.ARMED then
                    statusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
                elseif currentState == State.PARRYING then
                    statusLabel.TextColor3 = Color3.fromRGB(255, 100, 0)
                elseif currentState == State.COOLDOWN then
                    statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
                else
                    statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                end
            end
            task.wait(0.2)
        end
    end)
end

-- ============================================================================
-- CIRCLE ESP (visual radius)
-- ============================================================================
local function createCircleESP()
    if circlePart then circlePart:Destroy() end
    circlePart = Instance.new("Part")
    circlePart.Name = "AutoParry_RadiusCircle"
    circlePart.Size = Vector3.new(config.radius * 2, 0.1, config.radius * 2)
    circlePart.Shape = Enum.PartType.Cylinder
    circlePart.Anchored = true
    circlePart.CanCollide = false
    circlePart.BrickColor = BrickColor.new("Bright red")
    circlePart.Material = Enum.Material.Neon
    circlePart.Transparency = 0.7
    circlePart.Parent = workspace
    -- Follow player
    RunService.RenderStepped:Connect(function()
        if getLocalCharacter() and localRootPart then
            circlePart.Position = localRootPart.Position + Vector3.new(0, 0.5, 0)
        elseif circlePart then
            circlePart:Destroy()
        end
    end)
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
local function init()
    cacheRemotes()
    if not parryRemote or not parryResultRemote or not attackEventRemote then
        warn("[AutoParry] Missing required remotes. Script may not work.")
    end
    -- Hook events
    if attackEventRemote and not attackEventConnection then
        attackEventConnection = attackEventRemote.OnClientEvent:Connect(onAttackEvent)
    end
    if parryResultRemote and not parryResultConnection then
        parryResultConnection = parryResultRemote.OnClientEvent:Connect(onParryResult)
    end
    -- Radius check loop (0.1 second interval)
    killerCheckConnection = RunService.Heartbeat:Connect(function()
        if tick() % 0.1 < 0.05 then
            updateStateByDistance()
        end
    end)
    -- Create GUI and ESP
    createGUI()
    createCircleESP()
    print("[AutoParry] System started. ARMED when killer inside radius circle.")
end

-- Start
task.wait(1)
init()
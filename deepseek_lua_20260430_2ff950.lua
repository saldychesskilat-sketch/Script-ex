--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║           CYBERHEROES ADVANCED UTILITY SCRIPT v1.0               ║
    ║           ESP (Distance-based colors) + Invisible + Shield       ║
    ║           God Mode + Noclip + Auto Run (Avoid players)           ║
    ║                   Developed by Deepseek-CH                       ║
    ║                     For Delta Executor                           ║
    ╚═══════════════════════════════════════════════════════════════════╝
--]]

-- ============================================================================
-- GLOBAL STATE PERSISTENCE
-- ============================================================================
local _G = getgenv() or _G
if not _G.CyberHeroesUtility then
    _G.CyberHeroesUtility = {
        config = {
            espEnabled = false,
            invisibleEnabled = false,
            autoShieldEnabled = false,
            godModeEnabled = false,
            noclipEnabled = false,
            autoRunEnabled = false,
            guiVisible = true,
            guiThemeColor = Color3.fromRGB(0, 230, 255)
        },
        state = {}
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
local CoreGui = game:GetService("CoreGui")

local localPlayer = Players.LocalPlayer
local localCharacter = nil
local localHumanoid = nil
local localRootPart = nil

-- ============================================================================
-- GLOBAL REFERENCES
-- ============================================================================
local screenGui = nil
local mainFrame = nil
local statusLabel = nil
local floatingLogo = nil
local isLogoVisible = false
local mainStroke = nil

-- ============================================================================
-- STATE VARIABLES FOR FEATURES
-- ============================================================================
local espObjects = {}          -- { [player] = { highlight, billboard, textLabel } }
local forceField = nil
local godModeConnection = nil
local noclipConnection = nil
local autoRunConnection = nil
local originalWalkSpeed = 16
local currentForceField = nil

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
        if localHumanoid and originalWalkSpeed == 16 then
            originalWalkSpeed = localHumanoid.WalkSpeed
        end
    end
    return localCharacter
end

local function getDistance(pos1, pos2)
    return (pos1 - pos2).Magnitude
end

local function getColorByDistance(dist)
    if dist <= 50 then
        return Color3.fromRGB(255, 0, 0)     -- Merah
    elseif dist <= 100 then
        return Color3.fromRGB(255, 165, 0)  -- Orange
    else
        return Color3.fromRGB(255, 255, 0)  -- Kuning
    end
end

-- ============================================================================
-- FEATURE 1: ESP (Distance-based highlight + Billboard)
-- ============================================================================
local function updateESP()
    if not config.espEnabled then
        for _, data in pairs(espObjects) do
            if data.highlight then data.highlight:Destroy() end
            if data.billboard then data.billboard:Destroy() end
        end
        espObjects = {}
        return
    end

    if not getLocalCharacter() or not localRootPart then return end
    local localPos = localRootPart.Position

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local character = player.Character
            if not character then
                if espObjects[player] then
                    if espObjects[player].highlight then espObjects[player].highlight:Destroy() end
                    if espObjects[player].billboard then espObjects[player].billboard:Destroy() end
                    espObjects[player] = nil
                end
                goto continue
            end

            local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
            if not root then goto continue end

            local distance = getDistance(localPos, root.Position)
            local color = getColorByDistance(distance)

            if not espObjects[player] then
                -- Create Highlight
                local highlight = Instance.new("Highlight")
                highlight.Name = "CyberHeroes_ESP"
                highlight.FillTransparency = 0.5
                highlight.OutlineTransparency = 0.2
                highlight.Adornee = character
                highlight.Parent = character

                -- Create BillboardGui
                local billboard = Instance.new("BillboardGui")
                billboard.Name = "CyberHeroes_NameTag"
                billboard.Adornee = character:FindFirstChild("Head") or root
                billboard.Size = UDim2.new(0, 120, 0, 40)
                billboard.StudsOffset = Vector3.new(0, 2.5, 0)
                billboard.Parent = character

                local textLabel = Instance.new("TextLabel")
                textLabel.Size = UDim2.new(1, 0, 1, 0)
                textLabel.BackgroundTransparency = 1
                textLabel.TextColor3 = color
                textLabel.TextStrokeTransparency = 0.5
                textLabel.TextScaled = true
                textLabel.Font = Enum.Font.GothamBold
                textLabel.Parent = billboard

                espObjects[player] = { highlight = highlight, billboard = billboard, textLabel = textLabel }
            end

            -- Update highlight color
            espObjects[player].highlight.FillColor = color
            espObjects[player].highlight.OutlineColor = color

            -- Update text label
            local playerName = player.Name
            local distText = string.format("%.0f studs", distance)
            espObjects[player].textLabel.Text = playerName .. "\n" .. distText
            espObjects[player].textLabel.TextColor3 = color
        end
        ::continue::
    end

    -- Cleanup for players who left
    for player, data in pairs(espObjects) do
        if not player or not player.Parent then
            if data.highlight then data.highlight:Destroy() end
            if data.billboard then data.billboard:Destroy() end
            espObjects[player] = nil
        end
    end
end

-- ============================================================================
-- FEATURE 2: INVISIBLE (Player local menjadi transparan)
-- ============================================================================
local function updateInvisibility()
    if not config.invisibleEnabled then
        if getLocalCharacter() then
            for _, part in ipairs(localCharacter:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Transparency = 0
                end
            end
        end
        return
    end
    if getLocalCharacter() then
        for _, part in ipairs(localCharacter:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = 1
            end
        end
    end
end

-- ============================================================================
-- FEATURE 3: AUTO SHIELD (ForceField selalu aktif)
-- ============================================================================
local function updateAutoShield()
    if not config.autoShieldEnabled then
        if currentForceField then
            currentForceField:Destroy()
            currentForceField = nil
        end
        return
    end
    if not getLocalCharacter() then return
    if not currentForceField or currentForceField.Parent ~= localCharacter then
        if currentForceField then currentForceField:Destroy() end
        currentForceField = Instance.new("ForceField")
        currentForceField.Name = "CyberHeroes_Shield"
        currentForceField.Parent = localCharacter
    end
end

-- ============================================================================
-- FEATURE 4: GOD MODE (Health tidak pernah berkurang)
-- ============================================================================
local function startGodMode()
    if godModeConnection then godModeConnection:Disconnect() end
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
    if godModeConnection then
        godModeConnection:Disconnect()
        godModeConnection = nil
    end
end

-- ============================================================================
-- FEATURE 5: NOCLIP (Tembus tembok)
-- ============================================================================
local function updateNoclip()
    if not config.noclipEnabled then
        if getLocalCharacter() then
            for _, part in ipairs(localCharacter:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
        return
    end
    if getLocalCharacter() then
        for _, part in ipairs(localCharacter:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end

-- ============================================================================
-- FEATURE 6: AUTO RUN (Menjauhi player dalam radius 50 studs)
-- ============================================================================
local function autoRun()
    if not config.autoRunEnabled then return end
    if not getLocalCharacter() or not localRootPart or not localHumanoid then return end
    local localPos = localRootPart.Position
    local closestPlayer = nil
    local closestDist = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local char = player.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                if root then
                    local dist = getDistance(localPos, root.Position)
                    if dist < closestDist then
                        closestDist = dist
                        closestPlayer = player
                    end
                end
            end
        end
    end

    if closestPlayer and closestDist <= 50 then
        -- Hitung arah menjauhi
        local targetPos = closestPlayer.Character.HumanoidRootPart.Position
        local direction = (localPos - targetPos).Unit
        local movePos = localPos + direction * 20  -- Posisi target untuk menjauh
        localHumanoid:MoveTo(movePos)
        -- Tingkatkan kecepatan sementara
        localHumanoid.WalkSpeed = originalWalkSpeed * 1.5
    else
        if localHumanoid.WalkSpeed ~= originalWalkSpeed then
            localHumanoid.WalkSpeed = originalWalkSpeed
        end
    end
end

-- ============================================================================
-- GUI (Modern, horizontal, draggable)
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

local function createToggleButton(parent, name, text, initialState, onChange)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(0, 100, 0, 32)
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
        local newState = not config[name]
        config[name] = newState
        if name == "espEnabled" then
            if newState then updateESP() else updateESP() end
        elseif name == "invisibleEnabled" then
            updateInvisibility()
        elseif name == "autoShieldEnabled" then
            updateAutoShield()
        elseif name == "godModeEnabled" then
            if newState then startGodMode() else stopGodMode() end
        elseif name == "noclipEnabled" then
            updateNoclip()
        elseif name == "autoRunEnabled" then
            -- No additional setup needed
        end
        updateState(newState)
        if onChange then onChange(newState) end
    end)
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
    floatingLogo.Image = "https://private-user-images.githubusercontent.com/188855284/395046716-ec3d8730-8153-420a-aa42-d4595ae9e4e7.jpg?jwt=..."
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
    screenGui.Parent = CoreGui
    screenGui.ResetOnSpawn = false

    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainPanel"
    mainFrame.Size = UDim2.new(0, 520, 0, 100)  -- Horizontal panel
    mainFrame.Position = UDim2.new(0.5, -260, 0.5, -50)
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
    title.Size = UDim2.new(0.6, 0, 1, 0)
    title.Position = UDim2.new(0.02, 0, 0, 0)
    title.Text = "CYBERHEROES UTILITY v1.0"
    title.TextColor3 = config.guiThemeColor
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

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

    -- Content area (horizontal buttons)
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -10, 1, -30)
    content.Position = UDim2.new(0, 5, 0, 28)
    content.BackgroundTransparency = 1
    content.Parent = mainFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Horizontal
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    listLayout.Padding = UDim.new(0, 8)
    listLayout.Parent = content

    -- Tombol-tombol
    createToggleButton(content, "espEnabled", "ESP", config.espEnabled)
    createToggleButton(content, "invisibleEnabled", "INVISIBLE", config.invisibleEnabled)
    createToggleButton(content, "autoShieldEnabled", "SHIELD", config.autoShieldEnabled)
    createToggleButton(content, "godModeEnabled", "GOD MODE", config.godModeEnabled)
    createToggleButton(content, "noclipEnabled", "NOCLIP", config.noclipEnabled)
    createToggleButton(content, "autoRunEnabled", "AUTO RUN", config.autoRunEnabled)

    makeDraggable(mainFrame)

    -- Status bar
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
            local active = (config.espEnabled and 1 or 0) +
                           (config.invisibleEnabled and 1 or 0) +
                           (config.autoShieldEnabled and 1 or 0) +
                           (config.godModeEnabled and 1 or 0) +
                           (config.noclipEnabled and 1 or 0) +
                           (config.autoRunEnabled and 1 or 0)
            if active > 0 then
                statusLabel.Text = "ACTIVE: " .. active .. " modules"
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
    TweenService:Create(mainFrame, TweenInfo.new(0.2), {BackgroundTransparency = 0.1}):Play()
end

-- ============================================================================
-- MAIN LOOP (update ESP periodically, auto run loop, noclip/invisible dynamic)
-- ============================================================================
local function mainLoop()
    -- ESP update setiap frame (untuk pergerakan)
    RunService.RenderStepped:Connect(function()
        updateESP()
        if config.autoRunEnabled then
            autoRun()
        end
        if config.noclipEnabled then
            updateNoclip()
        end
        if config.invisibleEnabled then
            updateInvisibility()
        end
        if config.autoShieldEnabled then
            updateAutoShield()
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
    end
    -- Reset state features on new character
    updateInvisibility()
    updateNoclip()
    updateAutoShield()
end

if localPlayer.Character then
    onCharacterAdded(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(onCharacterAdded)

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
local function init()
    print("╔═══════════════════════════════════════════════════════════════════╗")
    print("║           CYBERHEROES ADVANCED UTILITY SCRIPT v1.0               ║")
    print("║           ESP | Invisible | Shield | God Mode | Noclip | Auto Run║")
    print("║                   System initialized!                            ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")
    createGUI()
    mainLoop()
    -- Start god mode if initially enabled
    if config.godModeEnabled then
        startGodMode()
    end
end

task.wait(1)
init()
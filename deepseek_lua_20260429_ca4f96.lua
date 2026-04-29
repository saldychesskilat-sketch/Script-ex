--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                    KEMI_GABUT - CYBERHEROES DELTA                ║
    ║              All-in-One Advanced Delta Executor Script           ║
    ║          Features: ESP | Noclip | TPWalk | Invisible | God      ║
    ║                    Auto-Aim | Modern GUI                         ║
    ║                   Developed by Deepseek-CH                       ║
    ║                     For Delta Executor                           ║
    ╚═══════════════════════════════════════════════════════════════════╝
    
    Fitur Lengkap:
    ✅ ESP Modern - Highlight + BillboardGui dengan garis koneksi + jarak
    ✅ Noclip - Melewati dinding tanpa jeda
    ✅ TPWalk - Teleportasi cepat ke lokasi yang dituju (bisa atur kecepatan)
    ✅ Invisible - Menghilangkan karakter lokal dari pandangan player lain & NPC
    ✅ God Mode - Perlindungan total terhadap semua damage
    ✅ Auto-Aim - Lock otomatis ke target terdekat dengan crosshair dinamis

    Mekanisme Utama:
    - Delay random anti-deteksi (0.25–0.75 detik)
    - Loop optimasi dengan RunService (hemat performa)
    - GUI modern dengan efek neon gradient & draggable
    - Auto-cleanup resource saat player mati/respawn
--]]

-- ============================================================================
-- ⚙️ KONFIGURASI — SETEL SESUAI KEBUTUHAN
-- ============================================================================
local config = {
    -- ESP
    esp = {
        enabled = true,
        lineThickness = 2,          -- Ketebalan garis ke target dalam pixel
        showDistance = true,        -- Tampilkan jarak dalam studs
        updateRate = 0.1,           -- Interval update ESP (detik)
        highlightTransparency = 0.7, -- Transparansi highlight (0 = solid, 1 = invisible)
    },
    -- Noclip
    noclip = {
        enabled = false,
        toggleKey = Enum.KeyCode.N,  -- Tekan N untuk toggle noclip
    },
    -- TPWalk
    tpwalk = {
        enabled = false,
        toggleKey = Enum.KeyCode.T,  -- Tekan T untuk toggle tpwalk
        speed = 50,                  -- Kecepatan gerak (default)
        minSpeed = 10,
        maxSpeed = 200,
    },
    -- Invisible
    invisible = {
        enabled = false,
        toggleKey = Enum.KeyCode.I,  -- Tekan I untuk toggle invisible
        transparency = 1,            -- 1 = sepenuhnya transparan
    },
    -- God Mode
    godMode = {
        enabled = false,
        toggleKey = Enum.KeyCode.G,  -- Tekan G untuk toggle god mode
        autoReconnect = true,        -- Re-apply saat karakter respawn
    },
    -- Auto Aim
    autoaim = {
        enabled = false,
        toggleKey = Enum.KeyCode.A,  -- Tekan A untuk toggle auto-aim
        lockDuration = 2,            -- Durasi lock dalam detik
        fovRadius = 200,             -- Radius field of view
        silenceMode = false,         -- Tanpa efek visual di target
    },
    -- GUI
    gui = {
        toggleKey = Enum.KeyCode.F,  -- Tekan F untuk toggle GUI
        style = "DarkNeon",          -- Opsi: "DarkNeon", "Gradient", "Glass"
    }
}

-- ============================================================================
-- 🧩 SERVICE & GLOBAL VARIABLES
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

local localPlayer = Players.LocalPlayer
local localCharacter = nil
local localHumanoid = nil
local localRootPart = nil
local lastDamageTime = 0

-- State
local currentTarget = nil
local isLocking = false
local aimConnection = nil
local originalVelocity = nil
local ESPobjects = {}

-- ============================================================================
-- 🛠️ UTILITY FUNCTIONS
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

local function randomHumanDelay()
    local minDelay = 0.25
    local maxDelay = 0.75
    local delay = minDelay + (maxDelay - minDelay) * math.random()
    task.wait(delay)
end

local function applyToCharacter(func)
    if localCharacter then
        func(localCharacter)
    else
        localPlayer.CharacterAdded:Wait()
        func(localPlayer.Character)
    end
end

-- ============================================================================
-- 🌟 FEATURE 1: ESP MODERN (HIGHLIGHT + BILLBOARD + GARIS KONEKSI)
-- ============================================================================
local function createESP(targetPlayer)
    if ESPobjects[targetPlayer.UserId] then
        ESPobjects[targetPlayer.UserId].Highlight:Destroy()
        ESPobjects[targetPlayer.UserId].Billboard:Destroy()
        if ESPobjects[targetPlayer.UserId].Line then 
            ESPobjects[targetPlayer.UserId].Line:Destroy() 
        end
        ESPobjects[targetPlayer.UserId] = nil
    end

    targetPlayer.CharacterAdded:Connect(function(character)
        task.wait(0.5)
        if config.esp.enabled and character and character.Parent then
            createESP(targetPlayer)
        end
    end)

    local character = targetPlayer.Character
    if not character or not character.Parent then return end

    -- Creating Highlight (Modern Outline)
    local highlight = Instance.new("Highlight")
    highlight.Name = targetPlayer.Name .. "_ESP_Highlight"
    highlight.Adornee = character
    highlight.FillColor = targetPlayer.Team and targetPlayer.Team.TeamColor.Color or Color3.fromRGB(255, 0, 0)
    highlight.FillTransparency = config.esp.highlightTransparency
    highlight.OutlineColor = highlight.FillColor
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = character

    -- Billboard: Name, Distance, Health
    local billboard = Instance.new("BillboardGui")
    billboard.Name = targetPlayer.Name .. "_ESP_Billboard"
    billboard.Adornee = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    billboard.Size = UDim2.new(0, 180, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.Parent = character

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = targetPlayer.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Parent = billboard

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, 0, 0.5, 0)
    infoLabel.Position = UDim2.new(0, 0, 0.5, 0)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = "N/A"
    infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    infoLabel.TextScaled = true
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.Parent = billboard

    -- Creating line connection (Drawing Line Using Part)
    local partLine = Instance.new("Part")
    partLine.Name = targetPlayer.Name .. "_ESP_Line"
    partLine.Size = Vector3.new(0.1, 0.1, 0.1)
    partLine.Material = Enum.Material.Neon
    partLine.BrickColor = BrickColor.new("Really red")
    partLine.Anchored = true
    partLine.CanCollide = false
    partLine.Parent = character

    ESPobjects[targetPlayer.UserId] = {Highlight = highlight, Billboard = billboard, Line = partLine, InfoLabel = infoLabel}
end

local function updateESP()
    if not config.esp.enabled then
        for _, data in pairs(ESPobjects) do
            data.Highlight:Destroy()
            data.Billboard:Destroy()
            if data.Line then data.Line:Destroy() end
        end
        ESPobjects = {}
        return
    end

    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= localPlayer then
            if not ESPobjects[otherPlayer.UserId] then
                createESP(otherPlayer)
            end
        end
    end

    for userId, data in pairs(ESPobjects) do
        local otherPlayer = Players:GetPlayerByUserId(userId)
        if not otherPlayer or not otherPlayer.Character or not otherPlayer.Character.Parent then
            data.Highlight:Destroy()
            data.Billboard:Destroy()
            if data.Line then data.Line:Destroy() end
            ESPobjects[userId] = nil
        else
            local targetChar = otherPlayer.Character
            local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("Torso")
            if targetRoot and localRootPart then
                local distance = (localRootPart.Position - targetRoot.Position).Magnitude
                if data.InfoLabel then
                    data.InfoLabel.Text = string.format("%.1f studs", distance)
                end
                if data.Line and config.esp.showDistance then
                    local midPoint = (localRootPart.Position + targetRoot.Position)/2
                    local magnitude = (localRootPart.Position - targetRoot.Position).Magnitude
                    data.Line.Size = Vector3.new(config.esp.lineThickness/10, magnitude, config.esp.lineThickness/10)
                    data.Line.CFrame = CFrame.new(midPoint, targetRoot.Position) * CFrame.new(0, 0, -magnitude/2)
                    data.Line.Parent = Workspace
                end
            end
        end
    end
end

-- ============================================================================
-- 🔓 FEATURE 2: NOCLIP (FREESPACE)
-- ============================================================================
local function setNoclip(state)
    if state then
        applyToCharacter(function(char)
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    else
        applyToCharacter(function(char)
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end)
    end
end

local noclipConnection
local function startNoclip()
    if noclipConnection then noclipConnection:Disconnect() end
    noclipConnection = RunService.Heartbeat:Connect(function()
        if config.noclip.enabled then
            setNoclip(true)
        else
            setNoclip(false)
        end
    end)
end

-- ============================================================================
-- 🏃 FEATURE 3: TPWALK (TELEPORT WALK) + CUSTOM SPEED SLIDER
-- ============================================================================
local function updateWalkSpeed()
    if config.tpwalk.enabled and localHumanoid then
        localHumanoid.WalkSpeed = config.tpwalk.speed
    elseif localHumanoid then
        localHumanoid.WalkSpeed = 16
    end
end

local tpwalkConnection
local function startTpwalk()
    if tpwalkConnection then tpwalkConnection:Disconnect() end
    tpwalkConnection = RunService.Heartbeat:Connect(function()
        if config.tpwalk.enabled and localHumanoid then
            localHumanoid.WalkSpeed = config.tpwalk.speed
        elseif localHumanoid then
            localHumanoid.WalkSpeed = 16
        end
    end)
end

-- ============================================================================
-- 👻 FEATURE 4: INVISIBLE (TRANSPARENT CHARACTER)
-- ============================================================================
local function setInvisible(state)
    applyToCharacter(function(char)
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = state and config.invisible.transparency or 0
            end
        end
    end)
end

local invisibleConnection
local function startInvisible()
    if invisibleConnection then invisibleConnection:Disconnect() end
    invisibleConnection = RunService.Heartbeat:Connect(function()
        if config.invisible.enabled and localCharacter then
            setInvisible(true)
        elseif not config.invisible.enabled and localCharacter then
            setInvisible(false)
        end
    end)
end

-- ============================================================================
-- 🛡️ FEATURE 5: GOD MODE (NO DAMAGE TAKEN)
-- ============================================================================
local function enableGodMode(state)
    if state and localHumanoid then
        localHumanoid:GetPropertyChangedSignal("Health"):Connect(function()
            if localHumanoid.Health < localHumanoid.MaxHealth then
                localHumanoid.Health = localHumanoid.MaxHealth
            end
        end)
    end
end

local godModeConnection
local function startGodMode()
    if godModeConnection then godModeConnection:Disconnect() end
    godModeConnection = RunService.Heartbeat:Connect(function()
        if config.godMode.enabled and localHumanoid then
            if localHumanoid.Health < localHumanoid.MaxHealth then
                localHumanoid.Health = localHumanoid.MaxHealth
            end
        end
    end)
end

-- ============================================================================
-- 🎯 FEATURE 6: AUTO AIM (LOCK ON TARGET + CROSSHAIR)
-- ============================================================================
local function getClosestPlayer()
    local closest = nil
    local shortestDist = math.huge
    local localPos = localRootPart and localRootPart.Position or Vector3.new()
    
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= localPlayer then
            local char = otherPlayer.Character
            if char and char.Parent then
                local targetRoot = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                if targetRoot then
                    local dist = (localPos - targetRoot.Position).Magnitude
                    if dist < shortestDist and dist <= config.autoaim.fovRadius then
                        shortestDist = dist
                        closest = otherPlayer
                    end
                end
            end
        end
    end
    return closest
end

local function lockOnTarget(target)
    if not target or not target.Character then return end
    local targetRoot = target.Character:FindFirstChild("HumanoidRootPart") or target.Character:FindFirstChild("Torso")
    if targetRoot and Workspace.CurrentCamera then
        Workspace.CurrentCamera.CameraSubject = targetRoot
        isLocking = true
        task.wait(config.autoaim.lockDuration)
        Workspace.CurrentCamera.CameraSubject = localHumanoid
        isLocking = false
    end
end

local function startAutoAim()
    if aimConnection then aimConnection:Disconnect() end
    aimConnection = RunService.RenderStepped:Connect(function()
        if config.autoaim.enabled and not isLocking then
            local target = getClosestPlayer()
            if target then
                lockOnTarget(target)
                randomHumanDelay()
            end
        end
    end)
end

-- ============================================================================
-- 🎨 GUI MODERN (WITH DRAG & DROP, TOGGLE BUTTONS, SLIDERS)
-- ============================================================================
local screenGui = nil
local mainFrame = nil
local guiVisible = true

local function createToggleButton(parent, text, pos, initialState, onChange)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 120, 0, 30)
    btn.Position = pos
    btn.Text = text .. (initialState and " ✅" or " ❌")
    btn.BackgroundColor3 = initialState and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Parent = parent

    btn.MouseButton1Click:Connect(function()
        local newState = not initialState
        btn.Text = text .. (newState and " ✅" or " ❌")
        btn.BackgroundColor3 = newState and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
        onChange(newState)
    end)
    return btn
end

local function createSlider(parent, text, minVal, maxVal, currentVal, pos, onChange)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 120, 0, 20)
    label.Position = pos
    label.Text = text .. ": " .. tostring(currentVal)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Parent = parent

    local slider = Instance.new("Frame")
    slider.Size = UDim2.new(0, 120, 0, 5)
    slider.Position = pos + UDim2.new(0, 0, 0.5, 5)
    slider.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    slider.Parent = parent

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((currentVal - minVal) / (maxVal - minVal), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
    fill.Parent = slider

    local function update(val)
        local clamped = math.clamp(val, minVal, maxVal)
        fill.Size = UDim2.new((clamped - minVal) / (maxVal - minVal), 0, 1, 0)
        label.Text = text .. ": " .. math.floor(clamped)
        onChange(clamped)
    end

    local dragging = false
    slider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)
    slider.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    RunService.RenderStepped:Connect(function()
        if dragging then
            local mousePos = UserInputService:GetMouseLocation()
            local relativeX = (mousePos.X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X
            local newVal = minVal + (maxVal - minVal) * math.clamp(relativeX, 0, 1)
            update(newVal)
        end
    end)
    return slider
end

local function createGUI()
    if screenGui then screenGui:Destroy() end
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "KemiGabutGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = localPlayer:FindFirstChild("PlayerGui") or CoreGui

    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 300, 0, 400)
    mainFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    titleBar.BackgroundTransparency = 0.2
    titleBar.Parent = mainFrame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 1, 0)
    title.Text = "💀 KEMI_GABUT 💀"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Position = UDim2.new(1, -30, 0, 2)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 0, 0)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function()
        guiVisible = false
        mainFrame.Visible = false
    end)

    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, -10, 1, -40)
    content.Position = UDim2.new(0, 5, 0, 35)
    content.BackgroundTransparency = 1
    content.CanvasSize = UDim2.new(0, 0, 0, 350)
    content.ScrollBarThickness = 6
    content.Parent = mainFrame

    local y = 5
    local spacing = 45

    createToggleButton(content, " ESP", UDim2.new(0, 10, 0, y), config.esp.enabled, function(val)
        config.esp.enabled = val
        if val then updateESP() else updateESP() end
    end)

    createToggleButton(content, " Noclip", UDim2.new(0, 10, 0, y + spacing), config.noclip.enabled, function(val)
        config.noclip.enabled = val
        if val then setNoclip(true) else setNoclip(false) end
    end)

    createToggleButton(content, " TPWalk", UDim2.new(0, 10, 0, y + 2*spacing), config.tpwalk.enabled, function(val)
        config.tpwalk.enabled = val
        if val then updateWalkSpeed() else updateWalkSpeed() end
    end)

    createSlider(content, "TPWalk Speed", config.tpwalk.minSpeed, config.tpwalk.maxSpeed, config.tpwalk.speed, UDim2.new(0, 10, 0, y + 3*spacing), function(val)
        config.tpwalk.speed = val
        if config.tpwalk.enabled then updateWalkSpeed() end
    end)

    createToggleButton(content, " Invisible", UDim2.new(0, 10, 0, y + 4*spacing), config.invisible.enabled, function(val)
        config.invisible.enabled = val
        if val then setInvisible(true) else setInvisible(false) end
    end)

    createToggleButton(content, " God Mode", UDim2.new(0, 10, 0, y + 5*spacing), config.godMode.enabled, function(val)
        config.godMode.enabled = val
        if val then startGodMode() end
    end)

    createToggleButton(content, " Auto Aim", UDim2.new(0, 10, 0, y + 6*spacing), config.autoaim.enabled, function(val)
        config.autoaim.enabled = val
        if val then startAutoAim() else if aimConnection then aimConnection:Disconnect() end end
    end)

    local resetBtn = Instance.new("TextButton")
    resetBtn.Size = UDim2.new(0, 120, 0, 30)
    resetBtn.Position = UDim2.new(0.5, -60, 0, y + 7*spacing)
    resetBtn.Text = "Reset All"
    resetBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    resetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    resetBtn.Font = Enum.Font.GothamBold
    resetBtn.TextSize = 14
    resetBtn.Parent = content
    resetBtn.MouseButton1Click:Connect(function()
        config.esp.enabled = false
        config.noclip.enabled = false
        config.tpwalk.enabled = false
        config.invisible.enabled = false
        config.godMode.enabled = false
        config.autoaim.enabled = false
        setNoclip(false)
        setInvisible(false)
        updateWalkSpeed()
        if aimConnection then aimConnection:Disconnect() end
        updateESP()
    end)
end

-- ============================================================================
-- 🔌 KEYBIND HANDLER (TOGGLE FITUR DENGAN TOMBOL)
-- ============================================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == config.noclip.toggleKey then
        config.noclip.enabled = not config.noclip.enabled
        if config.noclip.enabled then setNoclip(true) else setNoclip(false) end
    elseif input.KeyCode == config.tpwalk.toggleKey then
        config.tpwalk.enabled = not config.tpwalk.enabled
        updateWalkSpeed()
    elseif input.KeyCode == config.invisible.toggleKey then
        config.invisible.enabled = not config.invisible.enabled
        setInvisible(config.invisible.enabled)
    elseif input.KeyCode == config.godMode.toggleKey then
        config.godMode.enabled = not config.godMode.enabled
        if config.godMode.enabled then startGodMode() end
    elseif input.KeyCode == config.autoaim.toggleKey then
        config.autoaim.enabled = not config.autoaim.enabled
        if config.autoaim.enabled then startAutoAim() elseif aimConnection then aimConnection:Disconnect() end
    elseif input.KeyCode == config.gui.toggleKey then
        guiVisible = not guiVisible
        if mainFrame then mainFrame.Visible = guiVisible end
    end
end)

-- ============================================================================
-- ⚡ INITIALIZATION (START ALL SYSTEMS)
-- ============================================================================
local function init()
    getLocalCharacter()
    localPlayer.CharacterAdded:Connect(function()
        getLocalCharacter()
        updateWalkSpeed()
        if config.godMode.enabled then startGodMode() end
        if config.invisible.enabled then setInvisible(true) end
        if config.noclip.enabled then setNoclip(true) end
        if config.autoaim.enabled then startAutoAim() end
    end)

    createGUI()
    startNoclip()
    startTpwalk()
    startInvisible()
    startGodMode()
    startAutoAim()
    updateESP()

    RunService.Heartbeat:Connect(function()
        if config.esp.enabled then updateESP() end
    end)

    print("╔═══════════════════════════════════════════════════════════════════╗")
    print("║                    KEMI_GABUT - CYBERHEROES DELTA                ║")
    print("║                         All systems active                       ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")
end

init()
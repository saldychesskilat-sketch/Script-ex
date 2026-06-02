-- ============================================================================
-- REACTIVE PARRY SYSTEM (STANDALONE SCRIPT)
-- Fitur Auto Parry berbasis event AttackEvent dengan radius deteksi dan delay.
-- Tidak tergantung pada script utama, memiliki GUI sendiri.
-- ============================================================================

-- ============================================================================
-- SERVICES
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

-- ============================================================================
-- LOCAL REFERENCES
-- ============================================================================
local localPlayer = Players.LocalPlayer
local localCharacter = nil
local localHumanoid = nil
local localRootPart = nil
local camera = workspace.CurrentCamera

-- ============================================================================
-- KONFIGURASI DEFAULT
-- ============================================================================
local config = {
    enabled = false,
    detectionRadius = 10,        -- dalam studs (1-15)
    parryDelay = 0.15,           -- dalam detik (0.1-1)
    cooldown = 0.3               -- cooldown antar parry (detik)
}

-- ============================================================================
-- GLOBAL STATE
-- ============================================================================
local parryRemote = nil
local attackRemote = nil
local attackConnection = nil
local cooldownTimer = 0
local espPart = nil
local espConnection = nil
local gui = nil
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

-- Cari remote parry (ReplicatedStorage.Remotes.Items.Parrying Dagger.parry)
local function findParryRemote()
    if parryRemote and parryRemote.Parent then return parryRemote end
    local success, result = pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if not remotes then return nil end
        local items = remotes:FindFirstChild("Items")
        if not items then return nil end
        local dagger = items:FindFirstChild("Parrying Dagger")
        if not dagger then return nil end
        return dagger:FindFirstChild("parry")
    end)
    if success and result and result:IsA("RemoteEvent") then
        parryRemote = result
        print("[ParrySystem] Parry remote ditemukan")
        return parryRemote
    end
    -- Fallback scan
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") and obj.Name == "parry" then
            parryRemote = obj
            print("[ParrySystem] Parry remote ditemukan via scan")
            return parryRemote
        end
    end
    warn("[ParrySystem] Peringatan: Remote parry tidak ditemukan!")
    return nil
end

-- Cari remote AttackEvent
local function findAttackRemote()
    if attackRemote and attackRemote.Parent then return attackRemote end
    local attack = ReplicatedStorage:FindFirstChild("Remotes")
    if attack then attack = attack:FindFirstChild("AttackEvent") end
    if attack and attack:IsA("RemoteEvent") then
        attackRemote = attack
        print("[ParrySystem] AttackEvent ditemukan")
        return attackRemote
    end
    -- Fallback scan
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") and obj.Name == "AttackEvent" then
            attackRemote = obj
            return attackRemote
        end
    end
    warn("[ParrySystem] Peringatan: AttackEvent tidak ditemukan!")
    return nil
end

-- Ambil tool Parrying Dagger dari inventory
local function getParryingDaggerTool()
    local backpack = localPlayer:FindFirstChild("Backpack")
    local character = localPlayer.Character
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and (tool.Name == "Parrying Dagger" or tool.Name == "Blade") then
                return tool
            end
        end
    end
    if character then
        for _, tool in ipairs(character:GetChildren()) do
            if tool:IsA("Tool") and (tool.Name == "Parrying Dagger" or tool.Name == "Blade") then
                return tool
            end
        end
    end
    return nil
end

-- Eksekusi parry dengan berbagai variasi argumen
local function fireParry(targetPlayer)
    local remote = findParryRemote()
    if not remote then return false end
    local dagger = getParryingDaggerTool()
    local argsVariants = {
        {dagger},
        {"Parrying Dagger"},
        {"parry"},
        {"block"},
        {dagger, targetPlayer},
        {"Parrying Dagger", targetPlayer},
        {}
    }
    if not dagger then
        for i = #argsVariants, 1, -1 do
            local args = argsVariants[i]
            if #args > 0 and type(args[1]) == "userdata" then
                table.remove(argsVariants, i)
            end
        end
    end
    for _, args in ipairs(argsVariants) do
        pcall(function()
            if #args == 0 then
                remote:FireServer()
            elseif #args == 1 then
                remote:FireServer(args[1])
            elseif #args == 2 then
                remote:FireServer(args[1], args[2])
            end
        end)
    end
    return true
end

-- Validasi apakah player adalah killer
local function isKiller(player)
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
        for _, child in ipairs(char:GetChildren()) do
            if child.Name:lower():find("scp") then return true end
        end
    end
    return false
end

-- Hitung jarak antara local player dan target player
local function getDistanceToPlayer(player)
    if not localRootPart or not player or not player.Character then return math.huge end
    local targetRoot = player.Character:FindFirstChild("HumanoidRootPart") or player.Character:FindFirstChild("Torso")
    if not targetRoot then return math.huge end
    return (localRootPart.Position - targetRoot.Position).Magnitude
end

-- ============================================================================
-- EVENT HANDLER (AttackEvent)
-- ============================================================================
local function onAttackEvent(...)
    if not config.enabled then return end
    if not getLocalCharacter() or not localRootPart then return end
    
    -- Cek cooldown
    local now = tick()
    if now - cooldownTimer < config.cooldown then return end
    
    -- Ekstrak attacker dari argumen
    local args = {...}
    local attacker = nil
    for _, arg in ipairs(args) do
        if type(arg) == "userdata" then
            if arg:IsA("Player") then
                attacker = arg
                break
            elseif arg:IsA("Model") and arg:FindFirstChild("Humanoid") then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Character == arg then
                        attacker = p
                        break
                    end
                end
                if attacker then break end
            end
        end
    end
    if not attacker then return end
    
    -- Validasi killer
    if not isKiller(attacker) then return end
    
    -- Cek jarak
    local distance = getDistanceToPlayer(attacker)
    if distance > config.detectionRadius then return end
    
    -- Jika ada delay, tunggu
    if config.parryDelay > 0 then
        task.wait(config.parryDelay)
    end
    
    -- Eksekusi parry
    local success = fireParry(attacker)
    if success then
        cooldownTimer = tick()
        -- Optional: print ringan
        -- print("[ParrySystem] Parry executed against", attacker.Name)
    end
end

-- ============================================================================
-- VISUAL ESP (lingkaran radius)
-- ============================================================================
local function createEspPart()
    if espPart and espPart.Parent then espPart:Destroy() end
    espPart = Instance.new("Part")
    espPart.Name = "ParrySystem_Radius"
    espPart.Size = Vector3.new(config.detectionRadius * 2, 0.2, config.detectionRadius * 2)
    espPart.Shape = Enum.PartType.Cylinder
    espPart.BrickColor = BrickColor.new("Bright red")
    espPart.Material = Enum.Material.Neon
    espPart.Transparency = 0.7
    espPart.CanCollide = false
    espPart.Anchored = false
    espPart.Parent = Workspace
    return espPart
end

local function updateEspPosition()
    if not espPart or not config.enabled then return end
    if not getLocalCharacter() or not localRootPart then return
    espPart.CFrame = CFrame.new(localRootPart.Position - Vector3.new(0, localRootPart.Size.Y/2 - 0.2, 0))
end

local function updateEspRadius()
    if not espPart then return
    espPart.Size = Vector3.new(config.detectionRadius * 2, 0.2, config.detectionRadius * 2)
end

local function startEspLoop()
    if espConnection then espConnection:Disconnect() end
    espConnection = RunService.Heartbeat:Connect(updateEspPosition)
end

local function stopEspLoop()
    if espConnection then
        espConnection:Disconnect()
        espConnection = nil
    end
    if espPart then espPart:Destroy() end
end

-- ============================================================================
-- GUI (terpisah, draggable, slider)
-- ============================================================================
local function createGUI()
    -- Hapus GUI lama jika ada
    if gui and gui.Parent then gui:Destroy() end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ParrySystem_GUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = CoreGui
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 220, 0, 160)
    mainFrame.Position = UDim2.new(0.8, -110, 0.5, -80)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 5, 10)
    mainFrame.BackgroundTransparency = 0.15
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 230, 255)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.4
    stroke.Parent = mainFrame
    
    -- Title bar (draggable)
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 24)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 3, 7)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = titleBar
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0.7, 0, 1, 0)
    titleLabel.Position = UDim2.new(0.02, 0, 0, 0)
    titleLabel.Text = "⚔️ REACTIVE PARRY"
    titleLabel.TextColor3 = Color3.fromRGB(0, 230, 255)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 11
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 22, 0, 22)
    closeBtn.Position = UDim2.new(1, -26, 0, 1)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.Parent = titleBar
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 3)
    closeCorner.Parent = closeBtn
    
    -- Enable/Disable toggle button
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0.8, 0, 0, 28)
    toggleBtn.Position = UDim2.new(0.1, 0, 0.2, 0)
    toggleBtn.Text = config.enabled and "▶️ ACTIVE" or "⏸️ INACTIVE"
    toggleBtn.BackgroundColor3 = config.enabled and Color3.fromRGB(40, 5, 5) or Color3.fromRGB(15, 0, 2)
    toggleBtn.TextColor3 = config.enabled and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 12
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Parent = mainFrame
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 4)
    toggleCorner.Parent = toggleBtn
    
    -- Slider: Detection Radius
    local radiusLabel = Instance.new("TextLabel")
    radiusLabel.Size = UDim2.new(0.45, 0, 0, 18)
    radiusLabel.Position = UDim2.new(0.05, 0, 0.45, 0)
    radiusLabel.Text = "RADIUS: " .. config.detectionRadius .. " studs"
    radiusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    radiusLabel.BackgroundTransparency = 1
    radiusLabel.Font = Enum.Font.Gotham
    radiusLabel.TextSize = 10
    radiusLabel.TextXAlignment = Enum.TextXAlignment.Left
    radiusLabel.Parent = mainFrame
    
    local radiusSlider = Instance.new("TextButton")
    radiusSlider.Size = UDim2.new(0.4, 0, 0, 4)
    radiusSlider.Position = UDim2.new(0.55, 0, 0.47, 0)
    radiusSlider.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    radiusSlider.AutoButtonColor = false
    radiusSlider.BorderSizePixel = 0
    radiusSlider.Parent = mainFrame
    local radiusSliderCorner = Instance.new("UICorner")
    radiusSliderCorner.CornerRadius = UDim.new(1, 0)
    radiusSliderCorner.Parent = radiusSlider
    
    local radiusFill = Instance.new("Frame")
    radiusFill.Size = UDim2.new((config.detectionRadius - 1) / 14, 0, 1, 0)
    radiusFill.BackgroundColor3 = Color3.fromRGB(0, 230, 255)
    radiusFill.BorderSizePixel = 0
    radiusFill.Parent = radiusSlider
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = radiusFill
    
    local radiusValue = Instance.new("TextLabel")
    radiusValue.Size = UDim2.new(0.15, 0, 0, 18)
    radiusValue.Position = UDim2.new(0.8, 0, 0.45, 0)
    radiusValue.Text = tostring(config.detectionRadius)
    radiusValue.TextColor3 = Color3.fromRGB(0, 230, 255)
    radiusValue.BackgroundTransparency = 1
    radiusValue.Font = Enum.Font.GothamBold
    radiusValue.TextSize = 10
    radiusValue.Parent = mainFrame
    
    -- Slider: Parry Delay
    local delayLabel = Instance.new("TextLabel")
    delayLabel.Size = UDim2.new(0.45, 0, 0, 18)
    delayLabel.Position = UDim2.new(0.05, 0, 0.65, 0)
    delayLabel.Text = "DELAY: " .. string.format("%.2f", config.parryDelay) .. " s"
    delayLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    delayLabel.BackgroundTransparency = 1
    delayLabel.Font = Enum.Font.Gotham
    delayLabel.TextSize = 10
    delayLabel.TextXAlignment = Enum.TextXAlignment.Left
    delayLabel.Parent = mainFrame
    
    local delaySlider = Instance.new("TextButton")
    delaySlider.Size = UDim2.new(0.4, 0, 0, 4)
    delaySlider.Position = UDim2.new(0.55, 0, 0.67, 0)
    delaySlider.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    delaySlider.AutoButtonColor = false
    delaySlider.BorderSizePixel = 0
    delaySlider.Parent = mainFrame
    local delaySliderCorner = Instance.new("UICorner")
    delaySliderCorner.CornerRadius = UDim.new(1, 0)
    delaySliderCorner.Parent = delaySlider
    
    local delayFill = Instance.new("Frame")
    local delayPercent = (config.parryDelay - 0.1) / 0.9
    delayFill.Size = UDim2.new(delayPercent, 0, 1, 0)
    delayFill.BackgroundColor3 = Color3.fromRGB(0, 230, 255)
    delayFill.BorderSizePixel = 0
    delayFill.Parent = delaySlider
    local delayFillCorner = Instance.new("UICorner")
    delayFillCorner.CornerRadius = UDim.new(1, 0)
    delayFillCorner.Parent = delayFill
    
    local delayValue = Instance.new("TextLabel")
    delayValue.Size = UDim2.new(0.15, 0, 0, 18)
    delayValue.Position = UDim2.new(0.8, 0, 0.65, 0)
    delayValue.Text = string.format("%.2f", config.parryDelay)
    delayValue.TextColor3 = Color3.fromRGB(0, 230, 255)
    delayValue.BackgroundTransparency = 1
    delayValue.Font = Enum.Font.GothamBold
    delayValue.TextSize = 10
    delayValue.Parent = mainFrame
    
    -- Draggable logic
    local dragging = false
    local dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)
    titleBar.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                          startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    -- Slider interaction (radius)
    local function updateRadius(value)
        value = math.clamp(value, 1, 15)
        config.detectionRadius = value
        radiusLabel.Text = "RADIUS: " .. value .. " studs"
        radiusValue.Text = tostring(value)
        local percent = (value - 1) / 14
        radiusFill.Size = UDim2.new(percent, 0, 1, 0)
        updateEspRadius()
    end
    
    radiusSlider.MouseButton1Down:Connect(function()
        local mouse = UserInputService.GetMouseLocation
        local connect
        connect = UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                local pos = (input.Position.X - radiusSlider.AbsolutePosition.X) / radiusSlider.AbsoluteSize.X
                pos = math.clamp(pos, 0, 1)
                local val = 1 + pos * 14
                updateRadius(math.floor(val + 0.5))
            end
        end)
        local releaseConn
        releaseConn = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                connect:Disconnect()
                releaseConn:Disconnect()
            end
        end)
    end)
    
    -- Slider interaction (delay)
    local function updateDelay(value)
        value = math.clamp(value, 0.1, 1.0)
        config.parryDelay = value
        delayLabel.Text = "DELAY: " .. string.format("%.2f", value) .. " s"
        delayValue.Text = string.format("%.2f", value)
        local percent = (value - 0.1) / 0.9
        delayFill.Size = UDim2.new(percent, 0, 1, 0)
    end
    
    delaySlider.MouseButton1Down:Connect(function()
        local mouse = UserInputService.GetMouseLocation
        local connect
        connect = UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                local pos = (input.Position.X - delaySlider.AbsolutePosition.X) / delaySlider.AbsoluteSize.X
                pos = math.clamp(pos, 0, 1)
                local val = 0.1 + pos * 0.9
                updateDelay(val)
            end
        end)
        local releaseConn
        releaseConn = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                connect:Disconnect()
                releaseConn:Disconnect()
            end
        end)
    end)
    
    -- Toggle button
    toggleBtn.MouseButton1Click:Connect(function()
        config.enabled = not config.enabled
        toggleBtn.Text = config.enabled and "▶️ ACTIVE" or "⏸️ INACTIVE"
        toggleBtn.BackgroundColor3 = config.enabled and Color3.fromRGB(40, 5, 5) or Color3.fromRGB(15, 0, 2)
        toggleBtn.TextColor3 = config.enabled and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)
        if config.enabled then
            if not attackConnection then
                local attack = findAttackRemote()
                if attack then
                    attackConnection = attack.OnClientEvent:Connect(onAttackEvent)
                else
                    warn("[ParrySystem] AttackEvent tidak ditemukan, tidak bisa aktif")
                    config.enabled = false
                    toggleBtn.Text = "⏸️ INACTIVE"
                    toggleBtn.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
                    toggleBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
                    return
                end
            end
            startEspLoop()
            createEspPart()
            updateEspRadius()
        else
            if attackConnection then
                attackConnection:Disconnect()
                attackConnection = nil
            end
            stopEspLoop()
        end
    end)
    
    -- Close button
    closeBtn.MouseButton1Click:Connect(function()
        if attackConnection then attackConnection:Disconnect() end
        stopEspLoop()
        screenGui:Destroy()
        gui = nil
    end)
    
    -- Initial setup if enabled
    if config.enabled then
        local attack = findAttackRemote()
        if attack then
            attackConnection = attack.OnClientEvent:Connect(onAttackEvent)
            startEspLoop()
            createEspPart()
            updateEspRadius()
        end
    end
    
    gui = screenGui
    return screenGui
end

-- ============================================================================
-- INISIALISASI SISTEM
-- ============================================================================
local function init()
    print("[ParrySystem] Reactive Parry System dimulai (standalone)")
    -- Cari remote di awal untuk cache
    findParryRemote()
    findAttackRemote()
    -- Buat GUI
    createGUI()
    -- Update karakter setiap saat untuk posisi ESP
    getLocalCharacter()
    localPlayer.CharacterAdded:Connect(function()
        getLocalCharacter()
        if config.enabled then
            createEspPart()
        end
    end)
end

-- Jalankan
init()
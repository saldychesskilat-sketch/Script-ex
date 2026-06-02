-- ============================================================================
-- AUTO PARRY V3 (EVENT-DRIVEN + CIRCLE ESP + GUI)
-- Menggantikan FEATURE 7 yang lama
-- ============================================================================

-- ============================================================================
-- 1. CORE REMOTE EVENTS (sama seperti sebelumnya)
-- ============================================================================
local cachedParryRemote = nil
local cachedAttackRemote = nil

local function findParryRemoteEvent()
    if cachedParryRemote and cachedParryRemote.Parent then return cachedParryRemote end
    local parryRemote = ReplicatedStorage:FindFirstChild("Remotes")
    if parryRemote then
        local items = parryRemote:FindFirstChild("Items")
        if items then
            local dagger = items:FindFirstChild("Parrying Dagger")
            if dagger then
                local parry = dagger:FindFirstChild("parry")
                if parry and parry:IsA("RemoteEvent") then
                    cachedParryRemote = parry
                    print("[AutoParry] Found parry remote at correct path")
                    return parry
                end
            end
        end
    end
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") and obj.Name == "parry" then
            cachedParryRemote = obj
            print("[AutoParry] Found parry remote via scan")
            return obj
        end
    end
    return nil
end

local function findAttackRemoteEvent()
    if cachedAttackRemote and cachedAttackRemote.Parent then return cachedAttackRemote end
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local attack = remotes:FindFirstChild("AttackEvent")
        if attack and attack:IsA("RemoteEvent") then
            cachedAttackRemote = attack
            print("[AutoParry] Found AttackEvent")
            return attack
        end
    end
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") and obj.Name == "AttackEvent" then
            cachedAttackRemote = obj
            print("[AutoParry] Found AttackEvent via scan")
            return obj
        end
    end
    return nil
end

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

local function fireParryRemote(targetPlayer)
    local remote = findParryRemoteEvent()
    if not remote then return false end
    local dagger = getParryingDaggerTool()
    local argsVariants = {
        {dagger}, {"Parrying Dagger"}, {"parry"}, {"block"},
        {dagger, targetPlayer}, {"Parrying Dagger", targetPlayer}, {}
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
            if #args == 0 then remote:FireServer()
            elseif #args == 1 then remote:FireServer(args[1])
            else remote:FireServer(args[1], args[2]) end
        end)
    end
    return true
end

-- ============================================================================
-- 2. SISTEM BARU: EVENT-DRIVEN + RADIUS DETECTION + DELAY
-- ============================================================================
local newParry = {
    enabled = false,               -- sesuai config.infiniteAmmoEnabled
    radius = 5,                    -- detection radius (studs), default 5
    delay = 0.2,                   -- delay after attack event (seconds)
    cooldown = 0.15,
    lastParryTime = 0,
    killerInRange = false,
    attackConnection = nil,
    monitorConnection = nil,
}

-- Fungsi untuk mendapatkan killer terdekat dan jaraknya
local function getNearestKillerInfo()
    if not localRootPart then return nil, math.huge end
    local localPos = localRootPart.Position
    local nearest = nil
    local minDist = math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local char = player.Character
            if char then
                local isKiller = false
                if player.Team then
                    local teamName = player.Team.Name:lower()
                    if teamName:find("killer") or teamName:find("monster") or teamName:find("enemy") then
                        isKiller = true
                    end
                end
                if not isKiller then
                    local tool = char:FindFirstChildWhichIsA("Tool")
                    if tool and (tool.Name:lower():find("knife") or tool.Name:lower():find("weapon")) then
                        isKiller = true
                    end
                end
                if isKiller then
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
    end
    return nearest, minDist
end

-- Handler saat AttackEvent diterima
local function onAttackEvent(...)
    if not newParry.enabled then return end
    if not newParry.killerInRange then return end  -- hanya parry jika ada killer dalam radius
    local now = tick()
    if now - newParry.lastParryTime < newParry.cooldown then return end
    newParry.lastParryTime = now

    -- Ekstrak attacker dari argumen (opsional, tidak wajib)
    local attacker = nil
    local args = {...}
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
    if not attacker then
        -- fallback: cari killer terdekat
        local nearest, _ = getNearestKillerInfo()
        attacker = nearest
    end
    if not attacker then return end

    -- Delay sebelum parry (reaction speed)
    if newParry.delay > 0 then
        task.wait(newParry.delay)
    end
    fireParryRemote(attacker)
end

-- Fungsi untuk memperbarui status killerInRange dan mengaktifkan/menonaktifkan event listener
local function updateKillerInRange()
    if not newParry.enabled then
        if newParry.killerInRange then newParry.killerInRange = false end
        return
    end
    local _, dist = getNearestKillerInfo()
    local inRange = (dist <= newParry.radius)
    if inRange ~= newParry.killerInRange then
        newParry.killerInRange = inRange
        if inRange then
            print("[AutoParry] Killer entered radius, arming...")
        else
            print("[AutoParry] Killer left radius, disarming")
        end
    end
end

-- Monitor jarak killer dan update status
local function startMonitor()
    if newParry.monitorConnection then return end
    newParry.monitorConnection = RunService.Heartbeat:Connect(updateKillerInRange)
end

local function stopMonitor()
    if newParry.monitorConnection then
        newParry.monitorConnection:Disconnect()
        newParry.monitorConnection = nil
    end
end

-- Aktifkan sistem (pasang listener AttackEvent)
local function enableParry()
    if newParry.attackConnection then return end
    local attackRemote = findAttackRemoteEvent()
    if not attackRemote then
        print("[AutoParry] AttackEvent not found, cannot enable")
        return
    end
    newParry.attackConnection = attackRemote.OnClientEvent:Connect(onAttackEvent)
    startMonitor()
    newParry.enabled = true
    print("[AutoParry] Enabled (event-driven, radius="..newParry.radius..", delay="..newParry.delay..")")
end

local function disableParry()
    if newParry.attackConnection then
        newParry.attackConnection:Disconnect()
        newParry.attackConnection = nil
    end
    stopMonitor()
    newParry.enabled = false
    newParry.killerInRange = false
    print("[AutoParry] Disabled")
end

-- Toggle sesuai config.infiniteAmmoEnabled
local function syncParryWithConfig()
    if config.infiniteAmmoEnabled and not newParry.enabled then
        enableParry()
    elseif not config.infiniteAmmoEnabled and newParry.enabled then
        disableParry()
    end
end

-- ============================================================================
-- 3. CIRCLE ESP (menggunakan Drawing API)
-- ============================================================================
local circle = nil
local circleUpdateConnection = nil

local function createCircleESP()
    if not Drawing then return end
    if circle then circle:Remove() end
    circle = Drawing.new("Circle")
    circle.Thickness = 2
    circle.Color = Color3.fromRGB(0, 200, 255)
    circle.Filled = false
    circle.Visible = true
    circle.NumSides = 32
end

local function updateCircleESP()
    if not circle then return end
    if not newParry.enabled then
        circle.Visible = false
        return
    end
    if not localRootPart then
        circle.Visible = false
        return
    end
    local screenPos, onScreen = camera:WorldToScreenPoint(localRootPart.Position)
    if onScreen then
        circle.Visible = true
        circle.Position = Vector2.new(screenPos.X, screenPos.Y)
        circle.Radius = newParry.radius * (50 / camera.FieldOfView) * 100 -- konversi studs ke pixel (kira-kira)
        circle.Color = newParry.killerInRange and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(0, 200, 255)
    else
        circle.Visible = false
    end
end

local function startCircleESP()
    if circleUpdateConnection then return end
    createCircleESP()
    circleUpdateConnection = RunService.RenderStepped:Connect(updateCircleESP)
end

local function stopCircleESP()
    if circleUpdateConnection then
        circleUpdateConnection:Disconnect()
        circleUpdateConnection = nil
    end
    if circle then circle:Remove() circle = nil end
end

-- ============================================================================
-- 4. GUI UNTUK AUTO PARRY (DRAGGABLE, DUA SLIDER)
-- ============================================================================
local parryGui = nil
local parryFrame = nil
local radiusSliderFill = nil
local delaySliderFill = nil
local radiusValueLabel = nil
local delayValueLabel = nil
local statusButton = nil
local draggingRadius = false
local draggingDelay = false

local function createParryGUI()
    if parryGui then parryGui:Destroy() end
    parryGui = Instance.new("ScreenGui")
    parryGui.Name = "CyberHeroes_AutoParry"
    parryGui.ResetOnSpawn = false
    parryGui.Parent = CoreGui

    parryFrame = Instance.new("Frame")
    parryFrame.Size = UDim2.new(0, 180, 0, 90)
    parryFrame.Position = UDim2.new(0.5, -90, 0.7, 0)
    parryFrame.BackgroundColor3 = Color3.fromRGB(20, 5, 10)
    parryFrame.BackgroundTransparency = 0.1
    parryFrame.BorderSizePixel = 0
    parryFrame.Parent = parryGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = parryFrame
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 200, 255)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.4
    stroke.Parent = parryFrame

    -- Title bar (draggable)
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 20)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 3, 7)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0
    titleBar.Parent = parryFrame
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 6)
    titleCorner.Parent = titleBar
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0.7, 0, 1, 0)
    titleLabel.Position = UDim2.new(0.02, 0, 0, 0)
    titleLabel.Text = "AUTO PARRY"
    titleLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 10
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 18, 0, 18)
    closeBtn.Position = UDim2.new(1, -20, 0, 1)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 10
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function()
        parryGui.Visible = not parryGui.Visible
    end)

    -- Draggable
    local dragging = false
    local dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = parryFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    titleBar.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            parryFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                            startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Konten
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -10, 1, -25)
    content.Position = UDim2.new(0, 5, 0, 22)
    content.BackgroundTransparency = 1
    content.Parent = parryFrame

    -- Radius slider
    local radiusLabel = Instance.new("TextLabel")
    radiusLabel.Size = UDim2.new(0.6, 0, 0, 18)
    radiusLabel.Position = UDim2.new(0, 0, 0, 0)
    radiusLabel.Text = "Detection Radius"
    radiusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    radiusLabel.BackgroundTransparency = 1
    radiusLabel.Font = Enum.Font.Gotham
    radiusLabel.TextSize = 9
    radiusLabel.TextXAlignment = Enum.TextXAlignment.Left
    radiusLabel.Parent = content

    radiusValueLabel = Instance.new("TextLabel")
    radiusValueLabel.Size = UDim2.new(0.3, 0, 0, 18)
    radiusValueLabel.Position = UDim2.new(0.7, 0, 0, 0)
    radiusValueLabel.Text = tostring(newParry.radius).." studs"
    radiusValueLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    radiusValueLabel.BackgroundTransparency = 1
    radiusValueLabel.Font = Enum.Font.GothamBold
    radiusValueLabel.TextSize = 9
    radiusValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    radiusValueLabel.Parent = content

    local radiusSliderBg = Instance.new("Frame")
    radiusSliderBg.Size = UDim2.new(1, 0, 0, 4)
    radiusSliderBg.Position = UDim2.new(0, 0, 0, 20)
    radiusSliderBg.BackgroundColor3 = Color3.fromRGB(30, 10, 15)
    radiusSliderBg.BorderSizePixel = 0
    radiusSliderBg.Parent = content
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(1, 0)
    bgCorner.Parent = radiusSliderBg

    radiusSliderFill = Instance.new("Frame")
    radiusSliderFill.Size = UDim2.new((newParry.radius-1)/14, 0, 1, 0) -- range 1-15
    radiusSliderFill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    radiusSliderFill.BorderSizePixel = 0
    radiusSliderFill.Parent = radiusSliderBg
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = radiusSliderFill

    -- Delay slider
    local delayLabel = Instance.new("TextLabel")
    delayLabel.Size = UDim2.new(0.6, 0, 0, 18)
    delayLabel.Position = UDim2.new(0, 0, 0, 30)
    delayLabel.Text = "Parry Delay"
    delayLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    delayLabel.BackgroundTransparency = 1
    delayLabel.Font = Enum.Font.Gotham
    delayLabel.TextSize = 9
    delayLabel.TextXAlignment = Enum.TextXAlignment.Left
    delayLabel.Parent = content

    delayValueLabel = Instance.new("TextLabel")
    delayValueLabel.Size = UDim2.new(0.3, 0, 0, 18)
    delayValueLabel.Position = UDim2.new(0.7, 0, 0, 30)
    delayValueLabel.Text = string.format("%.2f s", newParry.delay)
    delayValueLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    delayValueLabel.BackgroundTransparency = 1
    delayValueLabel.Font = Enum.Font.GothamBold
    delayValueLabel.TextSize = 9
    delayValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    delayValueLabel.Parent = content

    local delaySliderBg = Instance.new("Frame")
    delaySliderBg.Size = UDim2.new(1, 0, 0, 4)
    delaySliderBg.Position = UDim2.new(0, 0, 0, 50)
    delaySliderBg.BackgroundColor3 = Color3.fromRGB(30, 10, 15)
    delaySliderBg.BorderSizePixel = 0
    delaySliderBg.Parent = content
    local bgCorner2 = Instance.new("UICorner")
    bgCorner2.CornerRadius = UDim.new(1, 0)
    bgCorner2.Parent = delaySliderBg

    delaySliderFill = Instance.new("Frame")
    delaySliderFill.Size = UDim2.new((newParry.delay-0.1)/0.9, 0, 1, 0) -- range 0.1-1.0
    delaySliderFill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    delaySliderFill.BorderSizePixel = 0
    delaySliderFill.Parent = delaySliderBg
    local fillCorner2 = Instance.new("UICorner")
    fillCorner2.CornerRadius = UDim.new(1, 0)
    fillCorner2.Parent = delaySliderFill

    -- Toggle button (menggunakan config.infiniteAmmoEnabled)
    statusButton = Instance.new("TextButton")
    statusButton.Size = UDim2.new(0.8, 0, 0, 22)
    statusButton.Position = UDim2.new(0.1, 0, 0, 62)
    statusButton.Text = config.infiniteAmmoEnabled and "PARRY ON" or "PARRY OFF"
    statusButton.BackgroundColor3 = config.infiniteAmmoEnabled and Color3.fromRGB(40, 5, 5) or Color3.fromRGB(15, 0, 2)
    statusButton.BackgroundTransparency = 0.2
    statusButton.TextColor3 = config.infiniteAmmoEnabled and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)
    statusButton.Font = Enum.Font.GothamBold
    statusButton.TextSize = 10
    statusButton.BorderSizePixel = 0
    statusButton.Parent = content
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = statusButton

    statusButton.MouseButton1Click:Connect(function()
        config.infiniteAmmoEnabled = not config.infiniteAmmoEnabled
        statusButton.Text = config.infiniteAmmoEnabled and "PARRY ON" or "PARRY OFF"
        statusButton.BackgroundColor3 = config.infiniteAmmoEnabled and Color3.fromRGB(40, 5, 5) or Color3.fromRGB(15, 0, 2)
        statusButton.TextColor3 = config.infiniteAmmoEnabled and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)
        syncParryWithConfig()
    end)

    -- Slider dragging logic
    local function updateRadius(value)
        value = math.clamp(value, 1, 15)
        newParry.radius = value
        radiusValueLabel.Text = tostring(value).." studs"
        radiusSliderFill.Size = UDim2.new((value-1)/14, 0, 1, 0)
    end

    local function updateDelay(value)
        value = math.clamp(value, 0.1, 1.0)
        newParry.delay = value
        delayValueLabel.Text = string.format("%.2f s", value)
        delaySliderFill.Size = UDim2.new((value-0.1)/0.9, 0, 1, 0)
    end

    radiusSliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingRadius = true
            local mouse = localPlayer:GetMouse()
            local function onMove(newX)
                local relX = math.clamp((newX - radiusSliderBg.AbsolutePosition.X) / radiusSliderBg.AbsoluteSize.X, 0, 1)
                local val = 1 + relX * 14
                updateRadius(val)
            end
            onMove(mouse.X)
            local conn
            conn = mouse.Move:Connect(function()
                if draggingRadius then onMove(mouse.X) end
            end)
            mouse.Button1Up:Connect(function()
                draggingRadius = false
                conn:Disconnect()
            end)
        end
    end)

    delaySliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingDelay = true
            local mouse = localPlayer:GetMouse()
            local function onMove(newX)
                local relX = math.clamp((newX - delaySliderBg.AbsolutePosition.X) / delaySliderBg.AbsoluteSize.X, 0, 1)
                local val = 0.1 + relX * 0.9
                updateDelay(val)
            end
            onMove(mouse.X)
            local conn
            conn = mouse.Move:Connect(function()
                if draggingDelay then onMove(mouse.X) end
            end)
            mouse.Button1Up:Connect(function()
                draggingDelay = false
                conn:Disconnect()
            end)
        end
    end)
end

-- ============================================================================
-- 5. START / STOP FUNCTIONS (menggantikan startInfiniteAmmo / stopInfiniteAmmo)
-- ============================================================================
local function startInfiniteAmmo()
    if not newParry.enabled then
        enableParry()
    end
    startCircleESP()
    if not parryGui then createParryGUI() end
    -- Sinkronkan status toggle dengan GUI
    if statusButton then
        statusButton.Text = "PARRY ON"
        statusButton.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
        statusButton.TextColor3 = Color3.fromRGB(0, 230, 255)
    end
    print("[AutoParry] System started (GUI active)")
end

local function stopInfiniteAmmo()
    disableParry()
    stopCircleESP()
    if parryGui then parryGui:Destroy() parryGui = nil end
    print("[AutoParry] System stopped")
end

-- ============================================================================
-- 6. INISIALISASI (panggil saat script load)
-- ============================================================================
local function initAutoParry()
    -- Pastikan remote ditemukan
    findParryRemoteEvent()
    findAttackRemoteEvent()
    -- Buat GUI awal (visible)
    createParryGUI()
    startCircleESP()
    -- Sinkronkan dengan config saat ini
    syncParryWithConfig()
    -- Juga update GUI toggle jika config berubah dari luar (opsional)
    if statusButton then
        statusButton.Text = config.infiniteAmmoEnabled and "PARRY ON" or "PARRY OFF"
        statusButton.BackgroundColor3 = config.infiniteAmmoEnabled and Color3.fromRGB(40, 5, 5) or Color3.fromRGB(15, 0, 2)
        statusButton.TextColor3 = config.infiniteAmmoEnabled and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)
    end
end

-- Jalankan inisialisasi
initAutoParry()

-- ============================================================================
-- AKHIR AUTO PARRY V3
-- ============================================================================
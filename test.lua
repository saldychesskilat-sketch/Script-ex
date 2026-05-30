-- ============================================================================
-- [ CyberHeroes | VD Auto Parry BruteForce ]
-- ============================================================================
-- Fungsi : Menemukan remote event parry yang benar di Violence District
-- Metode : Loop semua remote event + scan internal game, trigger dengan berbagai argumen
-- GUI    : Tombol untuk setiap metode (lihat mana yang berhasil)
-- Versi  : 1.0 (Brute Force)
-- ============================================================================
-- Cara Pakai:
-- 1. Jalankan script di executor (Delta, Xeno, etc.)
-- 2. Tunggu GUI muncul
-- 3. Tekan tombol "Scan Remote Events" untuk mendeteksi event dari game
-- 4. Coba tombol metode satu per satu (lihat console output)
-- 5. Jika ada yang berhasil, akan muncul notifikasi dan fitur bisa diaktifkan/dinonaktifkan
-- ============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer
local localCharacter = nil
local localHumanoid = nil
local localRootPart = nil

-- ============================================================================
-- KONFIGURASI (Bisa diubah)
-- ============================================================================
local config = {
    autoParryEnabled = false,          -- Auto Parry aktif/nonaktif
    parryRadius = 15,                  -- Jarak radius parry (studs)
    parryCooldown = 0.2,              -- Cooldown antar parry (detik)
    currentMethod = "remote_scan",     -- Metode yang aktif
    debugMode = true                   -- Tampilkan log di console
}

-- ============================================================================
-- STATE & CACHE
-- ============================================================================
local parryRemoteEvents = {}           -- Semua remote event yang terdeteksi
local parryLastTrigger = 0
local parryLoopConnection = nil
local currentTestMethod = nil
local gui = nil
local guiFrame = nil
local statusLabel = nil

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

local function debugPrint(msg)
    if config.debugMode then
        print("[CyberHeroes BruteForce] " .. msg)
    end
end

local function simulatePressE()
    -- Method 1: VirtualInputManager
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.03)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
    -- Method 2: VirtualUser sebagai fallback
    pcall(function()
        VirtualUser:Button1Down(Vector2.new(500, 500))
        task.wait(0.03)
        VirtualUser:Button1Up(Vector2.new(500, 500))
    end)
end

-- ============================================================================
-- DETEKSI KILLER (Proximity)
-- ============================================================================
local function getNearestKiller()
    if not localRootPart then return nil end
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

-- ============================================================================
-- SCAN REMOTE EVENTS (Otomatis untuk semua method)
-- ============================================================================
local function scanRemoteEvents()
    debugPrint("Scanning for RemoteEvents...")
    local events = {}
    local containers = {ReplicatedStorage, Workspace, localPlayer.Character}
    for _, container in ipairs(containers) do
        if container then
            for _, obj in ipairs(container:GetDescendants()) do
                if obj:IsA("RemoteEvent") then
                    table.insert(events, obj)
                    debugPrint("Found RemoteEvent: " .. obj:GetFullName())
                end
            end
        end
    end
    parryRemoteEvents = events
    debugPrint("Total RemoteEvents found: " .. #parryRemoteEvents)
    return parryRemoteEvents
end

-- ============================================================================
-- METODE 1: FIRE REMOTE EVENT LANGSUNG (Tanpa argumen)
-- ============================================================================
local function fireRemoteEvents(remoteEvents)
    for _, remote in ipairs(remoteEvents) do
        pcall(function() remote:FireServer() end)
        pcall(function() remote:FireServer("parry") end)
        pcall(function() remote:FireServer("block") end)
        pcall(function() remote:FireServer("deflect") end)
        pcall(function() remote:FireServer("counter") end)
        pcall(function() remote:FireServer("attack") end)
        pcall(function() remote:FireServer("damage") end)
        pcall(function() remote:FireServer("hit") end)
        pcall(function() remote:FireServer("kill") end)
        pcall(function() remote:FireServer("parry", true) end)
        pcall(function() remote:FireServer("Block") end)
        pcall(function() remote:FireServer("Parry") end)
    end
end

-- ============================================================================
-- METODE 2: INTERAKSI DENGAN PARRIED OBJECT
-- ============================================================================
local function findParryInteraction()
    local searchParents = {Workspace, localPlayer.Character, ReplicatedStorage}
    for _, parent in ipairs(searchParents) do
        if parent then
            for _, obj in ipairs(parent:GetDescendants()) do
                local name = obj.Name:lower()
                if name:find("parry") or name:find("block") or name:find("deflect") or name:find("counter") then
                    if obj:IsA("ProximityPrompt") and obj.Enabled then
                        return obj, "proximity"
                    elseif obj:IsA("ClickDetector") and obj.Enabled then
                        return obj, "click"
                    elseif obj:IsA("RemoteEvent") then
                        return obj, "remote"
                    end
                end
            end
        end
    end
    return nil, nil
end

local function triggerParryInteraction(interaction, objType)
    if not interaction then return false end
    if objType == "proximity" then
        pcall(function()
            interaction:Hold()
            task.wait(0.05)
            interaction:Release()
        end)
        return true
    elseif objType == "click" then
        pcall(function() interaction:FireClick() end)
        return true
    elseif objType == "remote" then
        pcall(function() interaction:FireServer() end)
        return true
    end
    return false
end

-- ============================================================================
-- METODE 3: SIMULASI KEYPRESS (E)
-- ============================================================================
local function keypressMethod()
    simulatePressE()
end

-- ============================================================================
-- METODE 4: MOUSE CLICK SIMULATION (Klik di tengah layar atau posisi tertentu)
-- ============================================================================
local function mouseClickMethod()
    local viewport = workspace.CurrentCamera.ViewportSize
    local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
    pcall(function()
        VirtualUser:Button1Down(center)
        task.wait(0.03)
        VirtualUser:Button1Up(center)
    end)
end

-- ============================================================================
-- METODE 5: MOBILE TOUCH SIMULATION
-- ============================================================================
local function touchMethod()
    pcall(function()
        VirtualUser:Touch(1, Vector2.new(500, 500))
    end)
end

-- ============================================================================
-- METODE 6: TOOL ACTIVATION (Jika player memiliki Parry Dagger)
-- ============================================================================
local function activateParryTool()
    if not localCharacter then return end
    for _, tool in ipairs(localCharacter:GetChildren()) do
        if tool:IsA("Tool") then
            local name = tool.Name:lower()
            if name:find("parry") or name:find("dagger") or name:find("knife") then
                pcall(function() tool:Activate() end)
                break
            end
        end
    end
end

-- ============================================================================
-- METODE 7: CLICK DETECTOR TERDEKAT (Cari yang paling dekat)
-- ============================================================================
local function clickNearestClickDetector()
    if not localRootPart then return end
    local localPos = localRootPart.Position
    local nearestCD = nil
    local minDist = math.huge

    for _, cd in ipairs(Workspace:GetDescendants()) do
        if cd:IsA("ClickDetector") and cd.Enabled then
            local pos = cd.Parent and cd.Parent:FindFirstChildWhichIsA("BasePart")
            if pos then
                local dist = (localPos - pos.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    nearestCD = cd
                end
            end
        end
    end

    if nearestCD then
        pcall(function() nearestCD:FireClick() end)
        return true
    end
    return false
end

-- ============================================================================
-- METODE 8: PROXIMITY PROMPT TERDEKAT
-- ============================================================================
local function useNearestProximityPrompt()
    if not localRootPart then return end
    local localPos = localRootPart.Position
    local nearestPP = nil
    local minDist = math.huge

    for _, pp in ipairs(Workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") and pp.Enabled then
            local pos = pp.Parent and pp.Parent:FindFirstChildWhichIsA("BasePart")
            if pos then
                local dist = (localPos - pos.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    nearestPP = pp
                end
            end
        end
    end

    if nearestPP then
        pcall(function()
            nearestPP:Hold()
            task.wait(0.05)
            nearestPP:Release()
        end)
        return true
    end
    return false
end

-- ============================================================================
-- METODE 9: BRUTE FORCE REMOTE ARGUMENTS (Coba semua kemungkinan)
-- ============================================================================
local function bruteForceRemoteArguments(remoteEvents)
    local possibleArgs = {
        {"Parry"}, {"Block"}, {"Deflect"}, {"Counter"}, {"Attack"}, {"Damage"},
        {"Hit"}, {"Kill"}, {"parry"}, {"block"}, {"deflect"}, {"counter"}, {"attack"},
        {"damage"}, {"hit"}, {"kill"}, {true}, {false}, {1}, {0}, {"Parry", true},
        {"Block", true}, {"Deflect", true}, {"Attack", true}, {"Damage", 50},
        {"Hit", 50}, {"Kill", localPlayer}, {"parry", localPlayer}, {}
    }
    for _, remote in ipairs(remoteEvents) do
        for _, args in ipairs(possibleArgs) do
            pcall(function()
                if #args == 0 then
                    remote:FireServer()
                elseif #args == 1 then
                    remote:FireServer(args[1])
                else
                    remote:FireServer(args[1], args[2])
                end
            end)
        end
    end
end

-- ============================================================================
-- MAIN AUTO PARRY LOOP (Pilih metode yang aktif)
-- ============================================================================
local function autoParryLoop()
    if not config.autoParryEnabled then return end
    if not getLocalCharacter() or not localRootPart then return end

    local now = tick()
    if now - parryLastTrigger < config.parryCooldown then return end

    local nearestKiller, killerDist = getNearestKiller()
    if not nearestKiller or killerDist > config.parryRadius then return end

    parryLastTrigger = now
    local success = false

    if config.currentMethod == "remote_scan" then
        fireRemoteEvents(parryRemoteEvents)
        success = true
    elseif config.currentMethod == "parry_object" then
        local interaction, objType = findParryInteraction()
        if interaction then
            success = triggerParryInteraction(interaction, objType)
        end
    elseif config.currentMethod == "keypress" then
        keypressMethod()
        success = true
    elseif config.currentMethod == "mouse_click" then
        mouseClickMethod()
        success = true
    elseif config.currentMethod == "touch" then
        touchMethod()
        success = true
    elseif config.currentMethod == "activate_tool" then
        activateParryTool()
        success = true
    elseif config.currentMethod == "click_detector" then
        success = clickNearestClickDetector()
    elseif config.currentMethod == "proximity_prompt" then
        success = useNearestProximityPrompt()
    elseif config.currentMethod == "brute_force" then
        bruteForceRemoteArguments(parryRemoteEvents)
        success = true
    end

    if success then
        debugPrint("Parry triggered via method: " .. config.currentMethod)
        if statusLabel then
            statusLabel.Text = "[Parry Triggered] " .. config.currentMethod
            TweenService:Create(statusLabel, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
            task.wait(0.5)
            TweenService:Create(statusLabel, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
        end
    end
end

-- ============================================================================
-- GUI (Testing Methods)
-- ============================================================================
local function createGUI()
    if gui then gui:Destroy() end
    gui = Instance.new("ScreenGui")
    gui.Name = "CyberHeroes_ParryBruteForce"
    gui.ResetOnSpawn = false
    gui.Parent = CoreGui

    guiFrame = Instance.new("Frame")
    guiFrame.Size = UDim2.new(0, 380, 0, 420)
    guiFrame.Position = UDim2.new(0.5, -190, 0.5, -210)
    guiFrame.BackgroundColor3 = Color3.fromRGB(20, 5, 10)
    guiFrame.BackgroundTransparency = 0.1
    guiFrame.BorderSizePixel = 0
    guiFrame.Parent = gui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = guiFrame

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 3, 7)
    titleBar.BackgroundTransparency = 0.2
    titleBar.Parent = guiFrame
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = titleBar

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.7, 0, 1, 0)
    title.Position = UDim2.new(0.02, 0, 0, 0)
    title.Text = "> Auto Parry BruteForce v1.0"
    title.TextColor3 = Color3.fromRGB(0, 230, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 24, 0, 24)
    closeBtn.Position = UDim2.new(1, -28, 0, 3)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.Parent = titleBar
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeBtn
    closeBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
        gui = nil
    end)

    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, -12, 1, -40)
    content.Position = UDim2.new(0, 6, 0, 36)
    content.BackgroundTransparency = 1
    content.CanvasSize = UDim2.new(0, 0, 0, 500)
    content.ScrollBarThickness = 6
    content.Parent = guiFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 6)
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.Parent = content

    local function createButton(text, callback, color)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 170, 0, 34)
        btn.Text = text
        btn.BackgroundColor3 = color or Color3.fromRGB(40, 5, 5)
        btn.BackgroundTransparency = 0.1
        btn.TextColor3 = Color3.fromRGB(220, 220, 220)
        btn.TextSize = 11
        btn.Font = Enum.Font.GothamBold
        btn.BorderSizePixel = 0
        btn.Parent = content
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btn
        btn.MouseButton1Click:Connect(callback)
        return btn
    end

    local function createToggleButton(text, getter, setter)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 170, 0, 34)
        btn.Text = text .. (getter() and " [ON]" or " [OFF]")
        btn.BackgroundColor3 = getter() and Color3.fromRGB(40, 5, 5) or Color3.fromRGB(25, 3, 7)
        btn.BackgroundTransparency = 0.1
        btn.TextColor3 = getter() and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)
        btn.TextSize = 11
        btn.Font = Enum.Font.GothamBold
        btn.BorderSizePixel = 0
        btn.Parent = content
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btn
        btn.MouseButton1Click:Connect(function()
            setter(not getter())
            btn.Text = text .. (getter() and " [ON]" or " [OFF]")
            btn.BackgroundColor3 = getter() and Color3.fromRGB(40, 5, 5) or Color3.fromRGB(25, 3, 7)
            btn.TextColor3 = getter() and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)
        end)
        return btn
    end

    createButton("1. Scan Remote Events", function()
        scanRemoteEvents()
        debugPrint("Scan complete. Found " .. #parryRemoteEvents .. " RemoteEvents.")
        if statusLabel then
            statusLabel.Text = "Scanned: " .. #parryRemoteEvents .. " events"
            TweenService:Create(statusLabel, TweenInfo.new(1), {TextTransparency = 0}):Play()
            task.wait(1)
            TweenService:Create(statusLabel, TweenInfo.new(1), {TextTransparency = 1}):Play()
        end
    end, Color3.fromRGB(60, 20, 20))

    createButton("2. Fire Remote Events (ALL)", function()
        fireRemoteEvents(parryRemoteEvents)
        debugPrint("Fired all remote events.")
    end)

    createButton("3. Interact with Parry Object", function()
        local interaction, objType = findParryInteraction()
        if interaction then
            triggerParryInteraction(interaction, objType)
            debugPrint("Interacted with parry object.")
        else
            debugPrint("No parry object found.")
        end
    end)

    createButton("4. Simulate Keypress (E)", function()
        keypressMethod()
        debugPrint("Simulated E keypress.")
    end)

    createButton("5. Simulate Mouse Click", function()
        mouseClickMethod()
        debugPrint("Simulated mouse click.")
    end)

    createButton("6. Simulate Mobile Touch", function()
        touchMethod()
        debugPrint("Simulated touch.")
    end)

    createButton("7. Activate Parry Tool", function()
        activateParryTool()
        debugPrint("Activated parry tool.")
    end)

    createButton("8. Click Nearest ClickDetector", function()
        clickNearestClickDetector()
        debugPrint("Clicked nearest ClickDetector.")
    end)

    createButton("9. Use Nearest ProximityPrompt", function()
        useNearestProximityPrompt()
        debugPrint("Used nearest ProximityPrompt.")
    end)

    createButton("10. Brute Force Remote Args", function()
        bruteForceRemoteArguments(parryRemoteEvents)
        debugPrint("Brute forced remote arguments.")
    end)

    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(0.9, 0, 0, 1)
    sep.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    sep.BackgroundTransparency = 0.7
    sep.Parent = content

    local titleActive = Instance.new("TextLabel")
    titleActive.Size = UDim2.new(0.9, 0, 0, 20)
    titleActive.Text = "⚙️ ACTIVE METHOD"
    titleActive.TextColor3 = Color3.fromRGB(0, 200, 255)
    titleActive.BackgroundTransparency = 1
    titleActive.Font = Enum.Font.GothamBold
    titleActive.TextSize = 12
    titleActive.Parent = content

    local methodButtons = {}
    local methods = {
        {"Remote Scan", "remote_scan"},
        {"Parry Object", "parry_object"},
        {"Keypress", "keypress"},
        {"Mouse Click", "mouse_click"},
        {"Touch", "touch"},
        {"Activate Tool", "activate_tool"},
        {"Click Detector", "click_detector"},
        {"Proximity Prompt", "proximity_prompt"},
        {"Brute Force", "brute_force"}
    }

    for _, method in ipairs(methods) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 170, 0, 28)
        btn.Text = method[1]
        btn.BackgroundColor3 = config.currentMethod == method[2] and Color3.fromRGB(40, 5, 5) or Color3.fromRGB(25, 3, 7)
        btn.BackgroundTransparency = 0.1
        btn.TextColor3 = config.currentMethod == method[2] and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)
        btn.TextSize = 10
        btn.Font = Enum.Font.GothamBold
        btn.BorderSizePixel = 0
        btn.Parent = content
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 5)
        corner.Parent = btn
        btn.MouseButton1Click:Connect(function()
            config.currentMethod = method[2]
            for _, b in ipairs(methodButtons) do
                b.BackgroundColor3 = Color3.fromRGB(25, 3, 7)
                b.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
            btn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
            btn.TextColor3 = Color3.fromRGB(0, 230, 255)
            debugPrint("Method changed to: " .. method[1])
        end)
        table.insert(methodButtons, btn)
    end

    local sep2 = Instance.new("Frame")
    sep2.Size = UDim2.new(0.9, 0, 0, 1)
    sep2.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    sep2.BackgroundTransparency = 0.7
    sep2.Parent = content

    createToggleButton("Auto Parry", function() return config.autoParryEnabled end, function(v)
        config.autoParryEnabled = v
        if v then
            if not parryLoopConnection then
                parryLoopConnection = RunService.Heartbeat:Connect(autoParryLoop)
                debugPrint("Auto Parry started")
            end
        else
            if parryLoopConnection then
                parryLoopConnection:Disconnect()
                parryLoopConnection = nil
                debugPrint("Auto Parry stopped")
            end
        end
    end)

    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0.9, 0, 0, 24)
    statusLabel.Text = "Ready"
    statusLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 10
    statusLabel.TextTransparency = 1
    statusLabel.Parent = content

    local function updateCanvas()
        task.wait(0.1)
        content.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)
    end
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
    updateCanvas()

    -- Draggable functionality
    local dragging = false
    local dragStart, startPos
    guiFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = guiFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    guiFrame.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            guiFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                          startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
local function init()
    print("╔═══════════════════════════════════════════════════════════════════╗")
    print("║     CYBERHEROES | Auto Parry BruteForce v1.0 - VD                ║")
    print("║     Testing all possible parry methods to find the correct one   ║")
    print("║     Developed by Deepseek-CH for CyberHeroes                     ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")
    getLocalCharacter()
    if not localRootPart then
        localPlayer.CharacterAdded:Wait()
        getLocalCharacter()
    end
    createGUI()
    scanRemoteEvents()
    debugPrint("Ready. Use GUI to test methods.")
end

task.wait(1)
init()

-- ============================================================================
-- USAGE:
-- 1. Scan Remote Events (deteksi semua remote event)
-- 2. Pilih metode satu per satu (lihat console)
-- 3. Jika ada yang berhasil, aktifkan Auto Parry
-- ============================================================================
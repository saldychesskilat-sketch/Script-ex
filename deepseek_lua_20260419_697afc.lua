--[[
    CYBERHEROES GENERATOR INTERACTION TESTER v1.0
    Untuk Violence District (Distrik Kekerasan)
    Developed for Delta Executor
    Tujuan: Menguji berbagai metode interaksi (repair) terhadap generator
    Fitur: Deteksi generator terdekat, teleport ke generator, 9 metode interaksi, loop otomatis, GUI interaktif
    Cara pakai: Jalankan script, klik REFRESH untuk cari generator, klik tombol metode.
    Hasil akan muncul di status dan console.
--]]

-- ============================================================================
-- SERVICES & GLOBAL STATE
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = syn and syn.input or (getrenv and getrenv().VirtualInputManager) or game:GetService("VirtualInputManager")
local VirtualUser = syn and syn.virtual_user or (getrenv and getrenv().VirtualUser) or game:GetService("VirtualUser")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Persistent config
local _G = getgenv() or _G
if not _G.CyberHeroesGenTester then
    _G.CyberHeroesGenTester = {
        selectedMethod = nil,
        loopEnabled = false,
        loopDelay = 0.2,
        currentGenerator = nil
    }
end
local state = _G.CyberHeroesGenTester

-- ============================================================================
-- VARIABLES
-- ============================================================================
local screenGui = nil
local mainFrame = nil
local targetLabel = nil
local statusLabel = nil
local lastResultLabel = nil
local loopCheckbox = nil
local delaySlider = nil
local delayValue = nil
local currentLoopConnection = nil
local isLooping = false
local localCharacter = nil
local localRootPart = nil

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

local function teleportTo(position)
    if not localRootPart then return false end
    pcall(function() localRootPart.CFrame = CFrame.new(position) end)
    return true
end

local function lockCameraTo(position)
    if not camera then return end
    pcall(function() camera.CFrame = CFrame.new(camera.CFrame.Position, position) end)
end

-- Deteksi generator (objek dengan Progress atau Completed atau nama mengandung generator/repair)
local function isGenerator(obj)
    if not obj then return false end
    local name = obj.Name:lower()
    if name:find("generator") or name:find("gen") or name:find("repair") or name:find("fix") then
        return true
    end
    if obj:FindFirstChild("Progress") or obj:FindFirstChild("Completed") then
        return true
    end
    if obj:FindFirstChildWhichIsA("ClickDetector") or obj:FindFirstChildWhichIsA("ProximityPrompt") then
        return true
    end
    return false
end

local function getAllGenerators()
    local generators = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if isGenerator(obj) then
            -- Cek apakah belum completed (progress < 100)
            local completed = false
            local progress = obj:FindFirstChild("Progress")
            if progress and (progress:IsA("NumberValue") or progress:IsA("IntValue")) then
                if progress.Value >= 100 then completed = true end
            end
            local completedBool = obj:FindFirstChild("Completed")
            if completedBool and completedBool:IsA("BoolValue") and completedBool.Value then
                completed = true
            end
            if not completed then
                table.insert(generators, obj)
            end
        end
    end
    return generators
end

local function getNearestGenerator()
    if not localRootPart then return nil end
    local localPos = localRootPart.Position
    local nearest = nil
    local minDist = math.huge
    for _, gen in ipairs(getAllGenerators()) do
        local pos = gen:GetPivot().Position
        local dist = (localPos - pos).Magnitude
        if dist < minDist then
            minDist = dist
            nearest = gen
        end
    end
    return nearest, minDist
end

local function teleportToGenerator(generator)
    if not generator then return false end
    local targetPart = generator:IsA("BasePart") and generator or generator:FindFirstChildWhichIsA("BasePart")
    if not targetPart then return false end
    return teleportTo(targetPart.Position + Vector3.new(0, 2, 0))
end

-- Simulasi klik pada posisi (button: 0=left, 1=right)
local function simulateClickAt(position, button)
    if not position then return end
    pcall(function()
        local screenPoint = camera:WorldToScreenPoint(position)
        if screenPoint.Z > 0 then
            local x, y = screenPoint.X, screenPoint.Y
            VirtualInputManager:SendMouseButtonEvent(x, y, button, true, game, 0)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(x, y, button, false, game, 0)
        end
    end)
end

local function simulatePressE()
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
    pcall(function()
        VirtualUser:Button1Down(Vector2.new(500, 500))
        task.wait(0.05)
        VirtualUser:Button1Up(Vector2.new(500, 500))
    end)
end

-- ============================================================================
-- METODE INTERAKSI GENERATOR
-- ============================================================================
local function methodLeftClick(generator)
    local targetPart = generator:IsA("BasePart") and generator or generator:FindFirstChildWhichIsA("BasePart")
    if targetPart then
        simulateClickAt(targetPart.Position, 0)
        return true
    end
    return false
end

local function methodRightClick(generator)
    local targetPart = generator:IsA("BasePart") and generator or generator:FindFirstChildWhichIsA("BasePart")
    if targetPart then
        simulateClickAt(targetPart.Position, 1)
        return true
    end
    return false
end

local function methodPressE(generator)
    simulatePressE()
    return true
end

local function methodRemoteEvent(generator)
    local success = false
    for _, remote in ipairs(ReplicatedStorage:GetDescendants()) do
        if remote:IsA("RemoteEvent") then
            local name = remote.Name:lower()
            if name:find("repair") or name:find("gen") or name:find("fix") or name:find("complete") then
                pcall(function() remote:FireServer(generator) end)
                success = true
            end
        end
    end
    return success
end

local function methodClickDetector(generator)
    local cd = generator:FindFirstChildWhichIsA("ClickDetector")
    if cd and cd.Enabled then
        pcall(function() cd:FireClick() end)
        return true
    end
    local targetPart = generator:IsA("BasePart") and generator or generator:FindFirstChildWhichIsA("BasePart")
    if targetPart then
        local cd2 = targetPart:FindFirstChildWhichIsA("ClickDetector")
        if cd2 and cd2.Enabled then
            pcall(function() cd2:FireClick() end)
            return true
        end
    end
    return false
end

local function methodProximityPrompt(generator)
    local pp = generator:FindFirstChildWhichIsA("ProximityPrompt")
    if pp and pp.Enabled then
        pcall(function() pp:Hold(); task.wait(0.1); pp:Release() end)
        return true
    end
    local targetPart = generator:IsA("BasePart") and generator or generator:FindFirstChildWhichIsA("BasePart")
    if targetPart then
        local pp2 = targetPart:FindFirstChildWhichIsA("ProximityPrompt")
        if pp2 and pp2.Enabled then
            pcall(function() pp2:Hold(); task.wait(0.1); pp2:Release() end)
            return true
        end
    end
    return false
end

local function methodTouchInterest(generator)
    local targetPart = generator:IsA("BasePart") and generator or generator:FindFirstChildWhichIsA("BasePart")
    if targetPart then
        local ti = Instance.new("TouchInterest")
        ti.Parent = targetPart
        task.wait(0.1)
        ti:Destroy()
        return true
    end
    return false
end

local function methodActivateTool(generator)
    -- Coba cari tool di sekitar atau generator sebagai tool
    if generator:IsA("Tool") then
        pcall(function() generator:Activate() end)
        return true
    end
    return false
end

local function methodDirectProgress(generator)
    local progress = generator:FindFirstChild("Progress")
    if progress and (progress:IsA("NumberValue") or progress:IsA("IntValue")) then
        pcall(function() progress.Value = 100 end)
        return true
    end
    local completed = generator:FindFirstChild("Completed")
    if completed and completed:IsA("BoolValue") then
        pcall(function() completed.Value = true end)
        return true
    end
    return false
end

-- Daftar metode
local methodsList = {
    {name = "Left Click", func = methodLeftClick},
    {name = "Right Click", func = methodRightClick},
    {name = "Press E", func = methodPressE},
    {name = "Remote Event", func = methodRemoteEvent},
    {name = "Click Detector", func = methodClickDetector},
    {name = "Proximity Prompt", func = methodProximityPrompt},
    {name = "Touch Interest", func = methodTouchInterest},
    {name = "Activate Tool", func = methodActivateTool},
    {name = "Direct Progress", func = methodDirectProgress}
}

-- ============================================================================
-- EKSEKUSI METODE DENGAN TELEPORT + FEEDBACK
-- ============================================================================
local function executeMethod(methodFunc, methodName, generator)
    if not generator then
        statusLabel.Text = "No generator selected!"
        return false
    end
    
    -- Teleport ke generator
    if not teleportToGenerator(generator) then
        statusLabel.Text = "Teleport failed!"
        return false
    end
    task.wait(0.05)
    
    -- Lock camera ke generator
    local targetPart = generator:IsA("BasePart") and generator or generator:FindFirstChildWhichIsA("BasePart")
    if targetPart then
        lockCameraTo(targetPart.Position)
    end
    
    -- Eksekusi metode
    local success = false
    pcall(function()
        success = methodFunc(generator)
    end)
    
    -- Cek hasil: apakah progress meningkat atau generator completed?
    local progressIncreased = false
    local progressVal = nil
    local progressObj = generator:FindFirstChild("Progress")
    if progressObj and (progressObj:IsA("NumberValue") or progressObj:IsA("IntValue")) then
        progressVal = progressObj.Value
        if progressVal >= 100 then
            progressIncreased = true
        end
    end
    local completedObj = generator:FindFirstChild("Completed")
    if completedObj and completedObj:IsA("BoolValue") and completedObj.Value then
        progressIncreased = true
    end
    
    local resultText = (success or progressIncreased) and "SUCCESS" or "FAILED"
    local color = (success or progressIncreased) and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    lastResultLabel.Text = string.format("[%s] %s - %s", methodName, generator.Name or "Generator", resultText)
    lastResultLabel.TextColor3 = color
    statusLabel.Text = string.format("Executed: %s -> %s", methodName, resultText)
    
    print(string.format("[GenTester] %s on %s: %s (Progress: %s)", methodName, generator.Name or "Generator", resultText, tostring(progressVal)))
    return success or progressIncreased
end

-- Loop
local function startLoop()
    if currentLoopConnection then return end
    isLooping = true
    currentLoopConnection = RunService.Heartbeat:Connect(function()
        if not state.loopEnabled then return end
        local gen = state.currentGenerator or getNearestGenerator()
        if not gen then return end
        if state.selectedMethod then
            executeMethod(state.selectedMethod.func, state.selectedMethod.name, gen)
        else
            for _, m in ipairs(methodsList) do
                executeMethod(m.func, m.name, gen)
                task.wait(state.loopDelay)
            end
        end
        task.wait(state.loopDelay)
    end)
end

local function stopLoop()
    if currentLoopConnection then
        currentLoopConnection:Disconnect()
        currentLoopConnection = nil
    end
    isLooping = false
    statusLabel.Text = "Loop stopped"
end

-- ============================================================================
-- GUI
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

local function createButton(parent, text, yPos, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.28, 0, 0, 28)
    btn.Position = UDim2.new(0.02 + (yPos % 3) * 0.33, 0, 0.15 + math.floor(yPos / 3) * 0.12, 0)
    btn.Text = text
    btn.BackgroundColor3 = color
    btn.BackgroundTransparency = 0.2
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 10
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = btn
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function createGUI()
    if screenGui then screenGui:Destroy() end
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroesGenTester"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = CoreGui

    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 400, 0, 320)
    mainFrame.Position = UDim2.new(0.5, -200, 0.4, -160)
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
    titleBar.Parent = mainFrame
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = titleBar
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.7, 0, 1, 0)
    title.Position = UDim2.new(0.02, 0, 0, 0)
    title.Text = "🔧 GENERATOR TESTER"
    title.TextColor3 = Color3.fromRGB(0, 230, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 11
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 22, 0, 22)
    closeBtn.Position = UDim2.new(1, -24, 0, 1)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function()
        screenGui.Visible = false
    end)

    -- Target info
    targetLabel = Instance.new("TextLabel")
    targetLabel.Size = UDim2.new(1, -10, 0, 20)
    targetLabel.Position = UDim2.new(0, 5, 0, 30)
    targetLabel.Text = "Generator: None"
    targetLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    targetLabel.BackgroundTransparency = 1
    targetLabel.Font = Enum.Font.Gotham
    targetLabel.TextSize = 11
    targetLabel.Parent = mainFrame

    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Size = UDim2.new(0, 60, 0, 20)
    refreshBtn.Position = UDim2.new(0.8, 0, 0, 30)
    refreshBtn.Text = "REFRESH"
    refreshBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    refreshBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    refreshBtn.TextSize = 9
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.BorderSizePixel = 0
    refreshBtn.Parent = mainFrame
    refreshBtn.MouseButton1Click:Connect(function()
        local nearest, dist = getNearestGenerator()
        if nearest then
            targetLabel.Text = string.format("Generator: %s (%.1f studs)", nearest.Name, dist)
            state.currentGenerator = nearest
        else
            targetLabel.Text = "Generator: None"
            state.currentGenerator = nil
        end
    end)

    -- Status label
    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -10, 0, 18)
    statusLabel.Position = UDim2.new(0, 5, 0, 55)
    statusLabel.Text = "Ready"
    statusLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 10
    statusLabel.Parent = mainFrame

    lastResultLabel = Instance.new("TextLabel")
    lastResultLabel.Size = UDim2.new(1, -10, 0, 18)
    lastResultLabel.Position = UDim2.new(0, 5, 0, 75)
    lastResultLabel.Text = "Last result: -"
    lastResultLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    lastResultLabel.BackgroundTransparency = 1
    lastResultLabel.Font = Enum.Font.Gotham
    lastResultLabel.TextSize = 10
    lastResultLabel.Parent = mainFrame

    -- Tombol metode (9 tombol)
    local buttonColors = {
        Color3.fromRGB(50, 180, 50),   -- hijau
        Color3.fromRGB(180, 50, 50),   -- merah
        Color3.fromRGB(200, 180, 50),  -- kuning
        Color3.fromRGB(50, 100, 200),  -- biru
        Color3.fromRGB(100, 50, 150),  -- ungu
        Color3.fromRGB(200, 100, 50),  -- oranye
        Color3.fromRGB(50, 150, 150),  -- cyan
        Color3.fromRGB(150, 50, 100),  -- pink
        Color3.fromRGB(100, 100, 100)  -- abu
    }
    for i, method in ipairs(methodsList) do
        createButton(mainFrame, method.name, i-1, buttonColors[i], function()
            local gen = state.currentGenerator or getNearestGenerator()
            if not gen then
                statusLabel.Text = "No generator found!"
                return
            end
            state.selectedMethod = method
            executeMethod(method.func, method.name, gen)
            refreshBtn.MouseButton1Click:Fire()
        end)
    end

    -- Loop controls
    local loopFrame = Instance.new("Frame")
    loopFrame.Size = UDim2.new(1, -10, 0, 40)
    loopFrame.Position = UDim2.new(0, 5, 0, 0.78)
    loopFrame.BackgroundTransparency = 1
    loopFrame.Parent = mainFrame

    loopCheckbox = Instance.new("TextButton")
    loopCheckbox.Size = UDim2.new(0, 100, 0, 24)
    loopCheckbox.Position = UDim2.new(0, 0, 0, 0)
    loopCheckbox.Text = state.loopEnabled and "LOOP: ON" or "LOOP: OFF"
    loopCheckbox.BackgroundColor3 = state.loopEnabled and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)
    loopCheckbox.TextColor3 = Color3.fromRGB(255, 255, 255)
    loopCheckbox.TextSize = 10
    loopCheckbox.Font = Enum.Font.GothamBold
    loopCheckbox.BorderSizePixel = 0
    loopCheckbox.Parent = loopFrame
    loopCheckbox.MouseButton1Click:Connect(function()
        state.loopEnabled = not state.loopEnabled
        loopCheckbox.Text = state.loopEnabled and "LOOP: ON" or "LOOP: OFF"
        loopCheckbox.BackgroundColor3 = state.loopEnabled and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)
        if state.loopEnabled then
            startLoop()
        else
            stopLoop()
        end
    end)

    local delayLabel = Instance.new("TextLabel")
    delayLabel.Size = UDim2.new(0, 50, 0, 24)
    delayLabel.Position = UDim2.new(0.28, 0, 0, 0)
    delayLabel.Text = "Delay:"
    delayLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    delayLabel.BackgroundTransparency = 1
    delayLabel.Font = Enum.Font.Gotham
    delayLabel.TextSize = 10
    delayLabel.Parent = loopFrame

    delaySlider = Instance.new("TextButton")
    delaySlider.Size = UDim2.new(0, 120, 0, 8)
    delaySlider.Position = UDim2.new(0.45, 0, 0.35, 0)
    delaySlider.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    delaySlider.BackgroundTransparency = 0.3
    delaySlider.BorderSizePixel = 0
    delaySlider.Parent = loopFrame
    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(1, 0)
    sliderCorner.Parent = delaySlider
    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new((state.loopDelay - 0.05) / 0.45, 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = delaySlider
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = sliderFill

    delayValue = Instance.new("TextLabel")
    delayValue.Size = UDim2.new(0, 40, 0, 24)
    delayValue.Position = UDim2.new(0.8, 0, 0, 0)
    delayValue.Text = string.format("%.2fs", state.loopDelay)
    delayValue.TextColor3 = Color3.fromRGB(0, 230, 255)
    delayValue.BackgroundTransparency = 1
    delayValue.Font = Enum.Font.GothamBold
    delayValue.TextSize = 10
    delayValue.Parent = loopFrame

    local dragging = false
    delaySlider.MouseButton1Down:Connect(function()
        dragging = true
        local mouse = localPlayer:GetMouse()
        local update = function()
            local relX = math.clamp((mouse.X - delaySlider.AbsolutePosition.X) / delaySlider.AbsoluteSize.X, 0, 1)
            local newDelay = 0.05 + relX * 0.45
            state.loopDelay = newDelay
            delayValue.Text = string.format("%.2fs", newDelay)
            sliderFill.Size = UDim2.new(relX, 0, 1, 0)
        end
        update()
        local conn = mouse.Move:Connect(update)
        mouse.Button1Up:Connect(function()
            dragging = false
            conn:Disconnect()
        end)
    end)

    makeDraggable(mainFrame)
    refreshBtn.MouseButton1Click:Fire()
end

-- ============================================================================
-- INIT
-- ============================================================================
local function onCharacterAdded(character)
    getLocalCharacter()
end

if localPlayer.Character then
    onCharacterAdded(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(onCharacterAdded)

createGUI()
print("[GenTester] GUI loaded. Click REFRESH to find generators, then test interaction methods.")
-- ============================================================================
-- CYBERHEROES PARRY REMOTE FUZZER v2.0
-- Developed for Delta Executor - Violence District
-- Brute force parry remote events with multiple argument variations
-- Auto bypass cooldown using rotation methods
-- ============================================================================

-- ============================================================================
-- SERVICES
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = cloneref and cloneref(game:GetService("VirtualInputManager")) or game:GetService("VirtualInputManager")
local VirtualUser = cloneref and cloneref(game:GetService("VirtualUser")) or game:GetService("VirtualUser")

local localPlayer = Players.LocalPlayer

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local config = {
    cooldownBypass = true,      -- Aktifkan bypass cooldown
    rotationInterval = 0.05,    -- Interval antar percobaan (detik)
    useAllRemotes = true,       -- True = test semua remote, False = test remote pertama saja
    autoResetCooldown = true,   -- Auto reset cooldown dengan mengirim event lain
    debugPrint = true           -- Tampilkan debug di console
}

-- ============================================================================
-- VARIABLES
-- ============================================================================
local screenGui = nil
local mainFrame = nil
local logFrame = nil
local logList = {}
local isTesting = false
local foundWorkingRemotes = {}  -- Simpan remote yang bekerja
local lastTestTime = 0
local COOLDOWN_SECONDS = 0.3     -- Minimal jeda antar test (dikurangi untuk bypass)
local rotationCount = 0
local currentMethodIndex = 1

-- ============================================================================
-- ARGUMEN VARIANTS (DIPERBESAR UNTUK BYPASS)
-- ============================================================================
local argVariants = {
    -- Single string arguments
    {args = {}, name = "NO ARGS", type = "basic"},
    {args = {"parry"}, name = "PARRY", type = "basic"},
    {args = {"Parry"}, name = "PARRY(C)", type = "basic"},
    {args = {"PARRY"}, name = "PARRY(UC)", type = "basic"},
    {args = {"block"}, name = "BLOCK", type = "basic"},
    {args = {"Block"}, name = "BLOCK(C)", type = "basic"},
    {args = {"deflect"}, name = "DEFLECT", type = "basic"},
    {args = {"counter"}, name = "COUNTER", type = "basic"},
    {args = {"attack"}, name = "ATTACK", type = "basic"},
    {args = {"damage"}, name = "DAMAGE", type = "basic"},
    {args = {"hit"}, name = "HIT", type = "basic"},
    {args = {"Dagger"}, name = "DAGGER", type = "basic"},
    {args = {"Parrying Dagger"}, name = "PARRYING DAGGER", type = "basic"},
    {args = {"parry", true}, name = "PARRY+TRUE", type = "bool"},
    {args = {"parry", false}, name = "PARRY+FALSE", type = "bool"},
    {args = {"block", true}, name = "BLOCK+TRUE", type = "bool"},
    {args = {"block", false}, name = "BLOCK+FALSE", type = "bool"},
    {args = {"deflect", true}, name = "DEFLECT+TRUE", type = "bool"},
    {args = {"counter", true}, name = "COUNTER+TRUE", type = "bool"},
    {args = {"parry", 1}, name = "PARRY+1", type = "num"},
    {args = {"parry", 0}, name = "PARRY+0", type = "num"},
    {args = {"parry", "start"}, name = "PARRY START", type = "cmd"},
    {args = {"parry", "end"}, name = "PARRY END", type = "cmd"},
    {args = {"parry", "begin"}, name = "PARRY BEGIN", type = "cmd"},
    {args = {"parry", "stop"}, name = "PARRY STOP", type = "cmd"},
    {args = {"parry", "activate"}, name = "PARRY ACT", type = "cmd"},
    {args = {"parry", "deactivate"}, name = "PARRY DEACT", type = "cmd"},
    {args = {"block", "start"}, name = "BLOCK START", type = "cmd"},
    {args = {"block", "stop"}, name = "BLOCK STOP", type = "cmd"},
    {args = {"deflect", "start"}, name = "DEFLECT START", type = "cmd"},
    {args = {"counter", "start"}, name = "COUNTER START", type = "cmd"},
    {args = {"skill", "parry"}, name = "SKILL PARRY", type = "compound"},
    {args = {"ability", "block"}, name = "ABILITY BLOCK", type = "compound"},
    {args = {"use", "parry"}, name = "USE PARRY", type = "compound"},
    {args = {"activate", "block"}, name = "ACTIVATE BLOCK", type = "compound"},
    {args = {"trigger", "parry"}, name = "TRIGGER PARRY", type = "compound"},
    {args = {"perform", "parry"}, name = "PERFORM PARRY", type = "compound"},
    {args = {"execute", "parry"}, name = "EXECUTE PARRY", type = "compound"},
    {args = {"do", "parry"}, name = "DO PARRY", type = "compound"},
    {args = {"cast", "parry"}, name = "CAST PARRY", type = "compound"},
    {args = {"parry", "weapon"}, name = "PARRY WEAPON", type = "compound"},
    {args = {"block", "weapon"}, name = "BLOCK WEAPON", type = "compound"},
    {args = {"parry", "melee"}, name = "PARRY MELEE", type = "compound"},
    {args = {"block", "melee"}, name = "BLOCK MELEE", type = "compound"},
    {args = {"parry", "attack"}, name = "PARRY ATTACK", type = "compound"},
    {args = {"block", "attack"}, name = "BLOCK ATTACK", type = "compound"},
    {args = {"counter", "attack"}, name = "COUNTER ATTACK", type = "compound"},
    {args = {"parry", "incoming"}, name = "PARRY INCOMING", type = "compound"},
    {args = {"block", "incoming"}, name = "BLOCK INCOMING", type = "compound"},
    {args = {"parry", "damage"}, name = "PARRY DAMAGE", type = "compound"},
    {args = {"block", "damage"}, name = "BLOCK DAMAGE", type = "compound"},
    {args = {"deflect", "damage"}, name = "DEFLECT DAMAGE", type = "compound"},
    {args = {"parry", "skill", "active"}, name = "PARRY SKILL ACT", type = "compound"},
    {args = {"block", "skill", "active"}, name = "BLOCK SKILL ACT", type = "compound"},
    {args = {"parry", "ready"}, name = "PARRY READY", type = "compound"},
    {args = {"block", "ready"}, name = "BLOCK READY", type = "compound"},
    {args = {"parry", "available"}, name = "PARRY AVAIL", type = "compound"},
    {args = {"block", "available"}, name = "BLOCK AVAIL", type = "compound"},
    {args = {"parry", "cooldown", "reset"}, name = "PARRY CD RESET", type = "bypass"},
    {args = {"block", "cooldown", "reset"}, name = "BLOCK CD RESET", type = "bypass"},
    {args = {"reset", "parry"}, name = "RESET PARRY", type = "bypass"},
    {args = {"reset", "block"}, name = "RESET BLOCK", type = "bypass"},
    {args = {"clear", "cooldown"}, name = "CLEAR CD", type = "bypass"},
    {args = {"remove", "cooldown"}, name = "REMOVE CD", type = "bypass"},
}

-- ============================================================================
-- FUNGSI MENCARI REMOTE EVENT
-- ============================================================================
local function findPotentialRemotes()
    local remotes = {}
    local containers = {ReplicatedStorage, Workspace, localPlayer.Character, game:GetService("Lighting")}
    
    -- Keywords untuk mencari remote yang relevan
    local keywords = {
        "parry", "block", "deflect", "counter", "attack", "damage", "hit",
        "combat", "melee", "skill", "ability", "action", "interact", "weapon",
        "sword", "knife", "dagger", "fight", "pvp", "strike", "slash",
        "defense", "guard", "shield", "protect", "reflect", "parryResult",
        "SkillCheck", "SkillCheckResult", "GenRepair", "Generator", "Gate"
    }
    
    for _, container in ipairs(containers) do
        if container then
            for _, obj in ipairs(container:GetDescendants()) do
                if obj:IsA("RemoteEvent") then
                    local name = obj.Name:lower()
                    local isRelevant = false
                    for _, kw in ipairs(keywords) do
                        if name:find(kw:lower()) then
                            isRelevant = true
                            break
                        end
                    end
                    if isRelevant then
                        table.insert(remotes, obj)
                    end
                end
            end
        end
    end
    
    -- Hapus duplikat
    local unique = {}
    local uniqueRemotes = {}
    for _, v in ipairs(remotes) do
        if not unique[v] then
            unique[v] = true
            table.insert(uniqueRemotes, v)
        end
    end
    
    return uniqueRemotes
end

-- ============================================================================
-- BYPASS COOLDOWN - KIRIM PERINTAH RESET
-- ============================================================================
local function attemptCooldownReset(remote)
    if not config.autoResetCooldown then return end
    
    -- Coba kirim argumen yang mungkin mereset cooldown
    local resetArgs = {
        {"reset"}, {"clear"}, {"remove"}, {"cooldown", "reset"},
        {"reset", "cooldown"}, {"clear", "cooldown"}, {"remove", "cooldown"},
        {"parry", "reset"}, {"block", "reset"}, {"skill", "reset"},
        {"reset", "parry"}, {"reset", "block"}, {"cancel"},
        {"stop", "parry"}, {"stop", "block"}, {"end", "parry"},
        {"deactivate", "parry"}, {"deactivate", "block"},
        {"disable", "parry"}, {"disable", "block"},
        {"parry", "off"}, {"block", "off"},
        {"parry", "disable"}, {"block", "disable"},
        {"cooldown", "clear"}, {"cooldown", "remove"},
        {"reset", "all"}, {"clear", "all"},
        {"parry", "cancel"}, {"block", "cancel"}
    }
    
    for _, args in ipairs(resetArgs) do
        pcall(function()
            if #args == 1 then
                remote:FireServer(args[1])
            elseif #args == 2 then
                remote:FireServer(args[1], args[2])
            elseif #args == 3 then
                remote:FireServer(args[1], args[2], args[3])
            end
        end)
    end
end

-- ============================================================================
-- FIRE REMOTE EVENT DENGAN ARGUMEN
-- ============================================================================
local function fireRemoteWithArgs(remote, argsTable)
    local success = false
    local result = nil
    
    pcall(function()
        if #argsTable == 0 then
            remote:FireServer()
            result = "Fired with no args"
        elseif #argsTable == 1 then
            remote:FireServer(argsTable[1])
            result = "Fired with: " .. tostring(argsTable[1])
        elseif #argsTable == 2 then
            remote:FireServer(argsTable[1], argsTable[2])
            result = "Fired with: " .. tostring(argsTable[1]) .. ", " .. tostring(argsTable[2])
        elseif #argsTable == 3 then
            remote:FireServer(argsTable[1], argsTable[2], argsTable[3])
            result = "Fired with: " .. tostring(argsTable[1]) .. ", " .. tostring(argsTable[2]) .. ", " .. tostring(argsTable[3])
        else
            remote:FireServer(unpack(argsTable))
            result = "Fired with " .. #argsTable .. " args"
        end
        success = true
    end)
    
    return success, result
end

-- ============================================================================
-- BYPASS COOLDOWN - ROTASI METODE
-- ============================================================================
local function rotateMethod()
    rotationCount = rotationCount + 1
    currentMethodIndex = (currentMethodIndex % #argVariants) + 1
    if config.debugPrint then
        print("[Rotate] Method " .. currentMethodIndex .. "/" .. #argVariants)
    end
end

-- ============================================================================
-- TEST ALL REMOTES (DENGAN BYPASS COOLDOWN)
-- ============================================================================
local function testAllRemotes()
    if isTesting then
        addLog("⏳ Test already in progress...")
        return
    end
    
    local now = tick()
    if now - lastTestTime < COOLDOWN_SECONDS then
        addLog("⏰ Wait " .. math.ceil(COOLDOWN_SECONDS - (now - lastTestTime)) .. "s")
        return
    end
    lastTestTime = now
    
    isTesting = true
    addLog("🔍 Scanning for remote events...")
    
    local remotes = findPotentialRemotes()
    if #remotes == 0 then
        addLog("❌ No remote events found!")
        isTesting = false
        return
    end
    
    addLog("📡 Found " .. #remotes .. " potential remote events")
    
    -- Reset tracking
    foundWorkingRemotes = {}
    
    -- Test setiap remote dengan semua variasi argumen
    for i, remote in ipairs(remotes) do
        addLog("[" .. i .. "/" .. #remotes .. "] Testing: " .. remote.Name)
        
        for j, variant in ipairs(argVariants) do
            -- Rotasi method untuk bypass cooldown
            if config.cooldownBypass and j % 5 == 0 then
                rotateMethod()
                attemptCooldownReset(remote)
            end
            
            local success, result = fireRemoteWithArgs(remote, variant.args)
            if success then
                -- Tambahkan delay kecil agar tidak overload
                task.wait(config.rotationInterval)
                
                -- Catat yang berhasil
                table.insert(foundWorkingRemotes, {
                    remote = remote,
                    args = variant.args,
                    argsName = variant.name,
                    result = result,
                    type = variant.type
                })
                
                addLog("   ✅ WORKING: " .. remote.Name .. " | " .. variant.name)
                
                -- Kirim notifikasi suara saat berhasil
                pcall(function()
                    local sound = Instance.new("Sound")
                    sound.SoundId = "rbxassetid://9120900777"
                    sound.Volume = 0.2
                    sound.Parent = Workspace
                    sound:Play()
                    task.wait(0.3)
                    sound:Destroy()
                end)
            end
        end
        task.wait(0.05)
    end
    
    isTesting = false
    addLog("")
    addLog("========== TEST COMPLETE ==========")
    addLog("✅ Working methods found: " .. #foundWorkingRemotes)
    
    if #foundWorkingRemotes == 0 then
        addLog("❌ No working remote/args found.")
    else
        addLog("💡 Working methods:")
        for k, w in ipairs(foundWorkingRemotes) do
            addLog("   " .. k .. ". " .. w.remote.Name .. " | " .. w.argsName)
        end
    end
end

-- ============================================================================
-- TEST SINGLE METHOD (UNTUK TEST CEPAT)
-- ============================================================================
local function testSingleMethod(remote, variant)
    local now = tick()
    if now - lastTestTime < COOLDOWN_SECONDS then
        addLog("⏰ Wait " .. math.ceil(COOLDOWN_SECONDS - (now - lastTestTime)) .. "s")
        return
    end
    lastTestTime = now
    
    -- Bypass: reset cooldown sebelum test
    if config.cooldownBypass then
        attemptCooldownReset(remote)
        rotateMethod()
    end
    
    addLog("🧪 Testing: " .. variant.name)
    local success, result = fireRemoteWithArgs(remote, variant.args)
    if success then
        addLog("   ✅ SUCCESS! " .. result)
        addLog("   🎯 Remote: " .. remote.Name)
        addLog("   📦 Args: " .. (#variant.args == 0 and "(none)" or table.concat(variant.args, ", ")))
        
        -- Notifikasi visual
        pcall(function()
            local sound = Instance.new("Sound")
            sound.SoundId = "rbxassetid://9120900777"
            sound.Volume = 0.3
            sound.Parent = Workspace
            sound:Play()
            task.wait(0.5)
            sound:Destroy()
        end)
    else
        addLog("   ❌ FAILED: " .. (result or "No response"))
    end
end

-- ============================================================================
-- CONTINUOUS TEST MODE (UNTUK MENCARI POLA)
-- ============================================================================
local continuousConnection = nil
local isContinuous = false
local continuousRemote = nil

local function startContinuousMode(remote)
    if isContinuous then
        stopContinuousMode()
    end
    isContinuous = true
    continuousRemote = remote
    
    addLog("🔄 Starting continuous test mode on: " .. remote.Name)
    addLog("⚡ Rotating through all argument variations...")
    
    continuousConnection = RunService.Heartbeat:Connect(function()
        if not isContinuous then return end
        if not continuousRemote then return end
        
        local variant = argVariants[currentMethodIndex]
        if variant then
            fireRemoteWithArgs(continuousRemote, variant.args)
            if config.debugPrint then
                print("[Continuous] Testing: " .. variant.name)
            end
        end
        
        -- Rotasi method setiap 2 detik
        rotationCount = rotationCount + 1
        if rotationCount % 40 == 0 then
            currentMethodIndex = (currentMethodIndex % #argVariants) + 1
            addLog("🔄 Rotated to method " .. currentMethodIndex .. "/" .. #argVariants)
            if config.autoResetCooldown then
                attemptCooldownReset(continuousRemote)
            end
        end
    end)
end

local function stopContinuousMode()
    if continuousConnection then
        continuousConnection:Disconnect()
        continuousConnection = nil
    end
    isContinuous = false
    continuousRemote = nil
    addLog("⏹️ Continuous test mode stopped")
end

-- ============================================================================
-- ADD LOG KE GUI
-- ============================================================================
local function addLog(msg)
    print("[ParryFuzzer] " .. msg)
    if not logFrame then return end
    
    local logText = Instance.new("TextLabel")
    logText.Size = UDim2.new(1, 0, 0, 16)
    logText.Text = msg
    logText.TextColor3 = Color3.fromRGB(200, 200, 200)
    logText.BackgroundTransparency = 1
    logText.Font = Enum.Font.Gotham
    logText.TextSize = 10
    logText.TextXAlignment = Enum.TextXAlignment.Left
    logText.Parent = logFrame
    
    table.insert(logList, logText)
    
    -- Batasi jumlah log
    while #logList > 50 do
        local oldest = table.remove(logList, 1)
        oldest:Destroy()
    end
    
    -- Scroll ke bawah
    local scrollFrame = logFrame.Parent
    if scrollFrame and scrollFrame:IsA("ScrollingFrame") then
        scrollFrame.CanvasPosition = Vector2.new(0, scrollFrame.CanvasSize.Y.Offset)
    end
end

-- ============================================================================
-- GUI CREATION (COMPACT)
-- ============================================================================
local function createGUI()
    if screenGui then screenGui:Destroy() end
    
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_ParryFuzzer"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = CoreGui
    screenGui.ResetOnSpawn = false
    
    -- Main Frame
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainPanel"
    mainFrame.Size = UDim2.new(0, 360, 0, 300)
    mainFrame.Position = UDim2.new(0.5, -180, 0.5, -150)
    mainFrame.BackgroundColor3 = Color3.fromRGB(18, 2, 5)
    mainFrame.BackgroundTransparency = 0.05
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = mainFrame
    
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(0, 230, 255)
    mainStroke.Thickness = 1.5
    mainStroke.Transparency = 0.4
    mainStroke.Parent = mainFrame
    
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
    
    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 28)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 3, 7)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.7, 0, 1, 0)
    title.Position = UDim2.new(0.02, 0, 0, 0)
    title.Text = "🔧 PARRY REMOTE FUZZER v2.0"
    title.TextColor3 = Color3.fromRGB(0, 230, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 11
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 22, 0, 22)
    closeBtn.Position = UDim2.new(1, -25, 0, 3)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 11
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function()
        if isContinuous then stopContinuousMode() end
        screenGui:Destroy()
    end)
    
    -- LEFT PANEL - Control Buttons
    local leftPanel = Instance.new("Frame")
    leftPanel.Size = UDim2.new(0, 110, 1, -35)
    leftPanel.Position = UDim2.new(0, 5, 0, 32)
    leftPanel.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    leftPanel.BackgroundTransparency = 0.2
    leftPanel.BorderSizePixel = 0
    leftPanel.Parent = mainFrame
    
    local leftCorner = Instance.new("UICorner")
    leftCorner.CornerRadius = UDim.new(0, 6)
    leftCorner.Parent = leftPanel
    
    local buttonScroll = Instance.new("ScrollingFrame")
    buttonScroll.Size = UDim2.new(1, -6, 1, -6)
    buttonScroll.Position = UDim2.new(0, 3, 0, 3)
    buttonScroll.BackgroundTransparency = 1
    buttonScroll.BorderSizePixel = 0
    buttonScroll.ScrollBarThickness = 3
    buttonScroll.Parent = leftPanel
    
    local btnLayout = Instance.new("UIListLayout")
    btnLayout.Padding = UDim.new(0, 4)
    btnLayout.FillDirection = Enum.FillDirection.Vertical
    btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    btnLayout.Parent = buttonScroll
    
    -- Tombol Scan
    local scanBtn = Instance.new("TextButton")
    scanBtn.Size = UDim2.new(0.9, 0, 0, 28)
    scanBtn.Text = "🔍 SCAN REMOTES"
    scanBtn.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
    scanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    scanBtn.Font = Enum.Font.GothamBold
    scanBtn.TextSize = 9
    scanBtn.Parent = buttonScroll
    scanBtn.MouseButton1Click:Connect(function()
        if isContinuous then stopContinuousMode() end
        testAllRemotes()
    end)
    
    -- Tombol Test All Variants
    local testAllBtn = Instance.new("TextButton")
    testAllBtn.Size = UDim2.new(0.9, 0, 0, 28)
    testAllBtn.Text = "⚡ TEST ALL VARIANTS"
    testAllBtn.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
    testAllBtn.TextColor3 = Color3.fromRGB(255, 200, 100)
    testAllBtn.Font = Enum.Font.GothamBold
    testAllBtn.TextSize = 9
    testAllBtn.Parent = buttonScroll
    testAllBtn.MouseButton1Click:Connect(function()
        if isContinuous then stopContinuousMode() end
        local remotes = findPotentialRemotes()
        if #remotes > 0 then
            for _, variant in ipairs(argVariants) do
                testSingleMethod(remotes[1], variant)
                task.wait(0.1)
            end
        else
            addLog("⚠️ No remotes found! Scan first.")
        end
    end)
    
    -- Separator
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(0.9, 0, 0, 1)
    sep.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    sep.BackgroundTransparency = 0.5
    sep.Parent = buttonScroll
    
    -- Tombol Continuous Test
    local continuousBtn = Instance.new("TextButton")
    continuousBtn.Size = UDim2.new(0.9, 0, 0, 28)
    continuousBtn.Text = "🔄 CONTINUOUS TEST"
    continuousBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 100)
    continuousBtn.TextColor3 = Color3.fromRGB(255, 200, 100)
    continuousBtn.Font = Enum.Font.GothamBold
    continuousBtn.TextSize = 9
    continuousBtn.Parent = buttonScroll
    continuousBtn.MouseButton1Click:Connect(function()
        local remotes = findPotentialRemotes()
        if #remotes > 0 then
            if isContinuous then
                stopContinuousMode()
                continuousBtn.Text = "🔄 CONTINUOUS TEST"
                continuousBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 100)
            else
                startContinuousMode(remotes[1])
                continuousBtn.Text = "⏹️ STOP TEST"
                continuousBtn.BackgroundColor3 = Color3.fromRGB(100, 30, 30)
            end
        else
            addLog("⚠️ No remotes found! Scan first.")
        end
    end)
    
    -- Tombol Clear Log
    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0.9, 0, 0, 28)
    clearBtn.Text = "🗑️ CLEAR LOG"
    clearBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    clearBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    clearBtn.Font = Enum.Font.GothamBold
    clearBtn.TextSize = 9
    clearBtn.Parent = buttonScroll
    clearBtn.MouseButton1Click:Connect(function()
        for _, log in ipairs(logList) do
            log:Destroy()
        end
        logList = {}
        addLog("📋 Log cleared")
    end)
    
    -- RIGHT PANEL - Log Output
    local rightPanel = Instance.new("Frame")
    rightPanel.Size = UDim2.new(0, 230, 1, -35)
    rightPanel.Position = UDim2.new(0, 120, 0, 32)
    rightPanel.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    rightPanel.BackgroundTransparency = 0.2
    rightPanel.BorderSizePixel = 0
    rightPanel.Parent = mainFrame
    
    local rightCorner = Instance.new("UICorner")
    rightCorner.CornerRadius = UDim.new(0, 6)
    rightCorner.Parent = rightPanel
    
    local logScroll = Instance.new("ScrollingFrame")
    logScroll.Size = UDim2.new(1, -6, 1, -6)
    logScroll.Position = UDim2.new(0, 3, 0, 3)
    logScroll.BackgroundTransparency = 1
    logScroll.BorderSizePixel = 0
    logScroll.ScrollBarThickness = 3
    logScroll.Parent = rightPanel
    
    logFrame = Instance.new("Frame")
    logFrame.Size = UDim2.new(1, 0, 0, 0)
    logFrame.BackgroundTransparency = 1
    logFrame.Parent = logScroll
    
    local logListLayout = Instance.new("UIListLayout")
    logListLayout.Padding = UDim.new(0, 2)
    logListLayout.Parent = logFrame
    
    logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    logListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        logScroll.CanvasSize = UDim2.new(0, 0, 0, logListLayout.AbsoluteContentSize.Y)
    end)
    
    -- Status Bar
    local statusBar = Instance.new("Frame")
    statusBar.Size = UDim2.new(1, -8, 0, 18)
    statusBar.Position = UDim2.new(0, 4, 1, -20)
    statusBar.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    statusBar.BackgroundTransparency = 0.3
    statusBar.BorderSizePixel = 0
    statusBar.Parent = mainFrame
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -8, 1, 0)
    statusLabel.Position = UDim2.new(0, 4, 0, 0)
    statusLabel.Text = "Ready | Cooldown Bypass: ON"
    statusLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 8
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = statusBar
    
    -- Log awal
    addLog("🧪 PARRY REMOTE FUZZER v2.0")
    addLog("⚡ Cooldown bypass active")
    addLog("🔄 Method rotation: " .. #argVariants .. " variants")
    addLog("💡 Click SCAN to find remotes, then test")
    addLog("")
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
local function init()
    print("╔═══════════════════════════════════════════════════════════════════╗")
    print("║           CYBERHEROES PARRY REMOTE FUZZER v2.0                   ║")
    print("║           Advanced brute force for parry remote events          ║")
    print("║           Cooldown bypass + Rotation method                     ║")
    print("║           Press F5 to open/close GUI                            ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")
    createGUI()
end
createGUI()
task.wait(1)
init()

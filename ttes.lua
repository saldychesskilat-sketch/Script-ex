--[[
    CYBERHEROES PARRY TESTER v1.0
    Developed for Delta Executor - Violence District
    Menguji berbagai metode remote event untuk parry/block
    Setiap tombol menjalankan satu variasi argumen
    Warna tombol berbeda untuk identifikasi
--]]

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

local localPlayer = Players.LocalPlayer

-- ============================================================================
-- VARIABLES
-- ============================================================================
local screenGui = nil
local mainFrame = nil
local logFrame = nil
local logList = {}
local isTesting = false
local foundWorkingRemote = nil
local workingArgs = nil
local lastTestTime = 0
local COOLDOWN_SECONDS = 1  -- minimal jeda antar test

-- ============================================================================
-- FUNGSI MENCARI REMOTE EVENT POTENSIAL
-- ============================================================================
local function findPotentialRemotes()
    local remotes = {}
    local containers = {ReplicatedStorage, Workspace, localPlayer.Character, game:GetService("Lighting")}
    
    for _, container in ipairs(containers) do
        if container then
            for _, obj in ipairs(container:GetDescendants()) do
                if obj:IsA("RemoteEvent") then
                    local name = obj.Name:lower()
                    -- Cari remote yang berpotensi terkait parry/block/combat
                    if name:find("parry") or name:find("block") or name:find("deflect") or
                       name:find("counter") or name:find("attack") or name:find("damage") or
                       name:find("hit") or name:find("combat") or name:find("melee") or
                       name:find("sword") or name:find("weapon") or name:find("skill") or
                       name:find("action") or name:find("interact") then
                        table.insert(remotes, obj)
                    end
                end
            end
        end
    end
    
    -- Hapus duplikat
    local unique = {}
    for _, v in ipairs(remotes) do
        if not unique[v] then
            unique[v] = true
            table.insert(remotes, v)
        end
    end
    
    return remotes
end

-- ============================================================================
-- MENCOBA FIRE REMOTE EVENT DENGAN ARGUMEN TERTENTU
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
-- TESTING SETIAP REMOTE DENGAN VARIOUS ARGUMEN
-- ============================================================================
local function testAllRemotes()
    if isTesting then
        addLog("⏳ Test already in progress...")
        return
    end
    
    local now = tick()
    if now - lastTestTime < COOLDOWN_SECONDS then
        addLog("⏰ Please wait " .. math.ceil(COOLDOWN_SECONDS - (now - lastTestTime)) .. " seconds before next test")
        return
    end
    lastTestTime = now
    
    isTesting = true
    addLog("🔍 Scanning for remote events...")
    
    local remotes = findPotentialRemotes()
    if #remotes == 0 then
        addLog("❌ No potential remote events found!")
        isTesting = false
        return
    end
    
    addLog("📡 Found " .. #remotes .. " potential remote events")
    
    -- Variasi argumen yang akan diuji (tambahkan sebanyak mungkin)
    local argVariants = {
        {},  -- tanpa argumen
        {"Parrying Dagger"},
        {"block"},
        {"deflect"},
        {"counter"},
        {"attack"},
        {"damage"},
        {"hit"},
        {"Dagger"},
        {"parry", true},
        {"Block"},
        {"Parry"},
        {"parry"},
        {"block", true},
        {"deflect", true},
        {"counter", true},
        {"attack", true},
        {"damage", 10},
        {"hit", "melee"},
        {"parry", "start"},
        {"block", "enable"},
        {"deflect", "on"},
        {"counter", "activate"},
        {"skill", "parry"},
        {"ability", "block"},
        {"action", "parry"},
        {"interact", "deflect"},
        {"use", "parry"},
        {"activate", "block"},
        {"trigger", "counter"},
        {"start", "parry"},
        {"begin", "block"},
        {"execute", "parry"},
        {"perform", "block"},
        {"do", "parry"},
        {"cast", "deflect"},
        {"parry", 1},
        {"block", 1},
        {"deflect", 1},
        {"counter", 1},
    }
    
    -- Track hasil kerja
    local workingRemotes = {}
    
    for i, remote in ipairs(remotes) do
        addLog("[" .. i .. "/" .. #remotes .. "] Testing: " .. remote.Name)
        
        for _, args in ipairs(argVariants) do
            local success, result = fireRemoteWithArgs(remote, args)
            if success then
                -- Tambahkan delay kecil agar tidak overload
                task.wait(0.05)
                -- Jika berhasil, catat
                local argsStr = #args == 0 and "(no args)" or table.concat(args, ", ")
                table.insert(workingRemotes, {
                    remote = remote,
                    args = args,
                    argsStr = argsStr,
                    result = result
                })
                addLog("   ✅ WORKING: " .. remote.Name .. " | Args: " .. argsStr)
                -- Simpan yang pertama kali bekerja
                if not foundWorkingRemote then
                    foundWorkingRemote = remote
                    workingArgs = args
                end
            end
        end
        task.wait(0.05) -- jeda antar remote
    end
    
    isTesting = false
    addLog("")
    addLog("========== TEST COMPLETE ==========")
    addLog("✅ Working methods found: " .. #workingRemotes)
    
    for _, w in ipairs(workingRemotes) do
        addLog("   • " .. w.remote.Name .. " | Args: " .. w.argsStr)
    end
    
    if #workingRemotes == 0 then
        addLog("❌ No working remote/args found. Try different approach.")
    else
        addLog("💡 Suggestion: Use the first working method in your main script.")
    end
end

-- ============================================================================
-- TESTING SINGLE TOMBOL (untuk masing-masing variasi)
-- ============================================================================
local function testSingleRemote(remote, args, buttonName)
    local now = tick()
    if now - lastTestTime < COOLDOWN_SECONDS then
        addLog("⏰ Please wait " .. math.ceil(COOLDOWN_SECONDS - (now - lastTestTime)) .. " seconds")
        return
    end
    lastTestTime = now
    
    addLog("🧪 Testing: " .. buttonName)
    local success, result = fireRemoteWithArgs(remote, args)
    if success then
        addLog("   ✅ SUCCESS! " .. result)
        addLog("   🎯 Remote: " .. remote.Name)
        addLog("   📦 Args: " .. (#args == 0 and "(none)" or table.concat(args, ", ")))
        -- Mainkan suara notifikasi jika berhasil
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
-- ADD LOG KE GUI
-- ============================================================================
local function addLog(msg)
    print("[ParryTester] " .. msg)
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
    
    -- Batasi jumlah log (max 50)
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
-- GET NEAREST KILLER (UNTUK KONTEKS)
-- ============================================================================
local function getNearestKiller()
    if not localPlayer.Character or not localPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    local localPos = localPlayer.Character.HumanoidRootPart.Position
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
    return nearest
end

-- ============================================================================
-- GUI CREATION (TOMBIK TERPISAH UNTUK SETIAP VARIASI)
-- ============================================================================
local function createGUI()
    if screenGui then screenGui:Destroy() end
    
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_ParryTester"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = CoreGui
    screenGui.ResetOnSpawn = false
    
    -- Main Frame
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainPanel"
    mainFrame.Size = UDim2.new(0, 650, 0, 480)
    mainFrame.Position = UDim2.new(0.5, -325, 0.5, -240)
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
    
    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 3, 7)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.7, 0, 1, 0)
    title.Position = UDim2.new(0.02, 0, 0, 0)
    title.Text = "🔧 PARRY REMOTE TESTER - VIOLENCE DISTRICT"
    title.TextColor3 = Color3.fromRGB(0, 230, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Position = UDim2.new(1, -28, 0, 2)
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
    
    -- LEFT PANEL: DAFTAR TOMBOL TEST
    local leftPanel = Instance.new("Frame")
    leftPanel.Size = UDim2.new(0, 220, 1, -40)
    leftPanel.Position = UDim2.new(0, 5, 0, 35)
    leftPanel.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    leftPanel.BackgroundTransparency = 0.2
    leftPanel.BorderSizePixel = 0
    leftPanel.Parent = mainFrame
    local leftCorner = Instance.new("UICorner")
    leftCorner.CornerRadius = UDim.new(0, 6)
    leftCorner.Parent = leftPanel
    
    -- Scrolling frame untuk tombol
    local buttonScroll = Instance.new("ScrollingFrame")
    buttonScroll.Size = UDim2.new(1, -10, 1, -10)
    buttonScroll.Position = UDim2.new(0, 5, 0, 5)
    buttonScroll.BackgroundTransparency = 1
    buttonScroll.BorderSizePixel = 0
    buttonScroll.ScrollBarThickness = 4
    buttonScroll.Parent = leftPanel
    
    local buttonLayout = Instance.new("UIListLayout")
    buttonLayout.Padding = UDim.new(0, 4)
    buttonLayout.FillDirection = Enum.FillDirection.Vertical
    buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    buttonLayout.Parent = buttonScroll
    
    -- RIGHT PANEL: LOG OUTPUT
    local rightPanel = Instance.new("Frame")
    rightPanel.Size = UDim2.new(0, 410, 1, -40)
    rightPanel.Position = UDim2.new(0, 230, 0, 35)
    rightPanel.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    rightPanel.BackgroundTransparency = 0.2
    rightPanel.BorderSizePixel = 0
    rightPanel.Parent = mainFrame
    local rightCorner = Instance.new("UICorner")
    rightCorner.CornerRadius = UDim.new(0, 6)
    rightCorner.Parent = rightPanel
    
    -- Log Scrolling Frame
    local logScroll = Instance.new("ScrollingFrame")
    logScroll.Size = UDim2.new(1, -10, 1, -10)
    logScroll.Position = UDim2.new(0, 5, 0, 5)
    logScroll.BackgroundTransparency = 1
    logScroll.BorderSizePixel = 0
    logScroll.ScrollBarThickness = 4
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
    
    -- ==========================================================================
    -- DAFTAR TOMBOL DENGAN WARNA BERBEDA UNTUK SETIAP VARIASI
    -- ==========================================================================
    
    -- Kumpulan remote yang akan diuji (bisa dicari dulu atau pakai manual)
    local remotesToTest = {}
    
    -- Cari remote otomatis
    local function refreshRemotes()
        remotesToTest = findPotentialRemotes()
        addLog("🔍 Found " .. #remotesToTest .. " remote events")
        return remotesToTest
    end
    
    -- Buat tombol untuk setiap variasi argumen
    local argVariantsList = {
        {args = {}, name = "NO ARGS", color = Color3.fromRGB(80, 80, 80), desc = "FireServer()"},
        {args = {"Parrying Dagger"}, name = "PARRYING DAGGER", color = Color3.fromRGB(200, 100, 0), desc = 'FireServer("Parrying Dagger")'},
        {args = {"block"}, name = "BLOCK", color = Color3.fromRGB(0, 150, 200), desc = 'FireServer("block")'},
        {args = {"deflect"}, name = "DEFLECT", color = Color3.fromRGB(100, 200, 100), desc = 'FireServer("deflect")'},
        {args = {"counter"}, name = "COUNTER", color = Color3.fromRGB(200, 200, 0), desc = 'FireServer("counter")'},
        {args = {"attack"}, name = "ATTACK", color = Color3.fromRGB(255, 80, 80), desc = 'FireServer("attack")'},
        {args = {"damage"}, name = "DAMAGE", color = Color3.fromRGB(255, 50, 50), desc = 'FireServer("damage")'},
        {args = {"hit"}, name = "HIT", color = Color3.fromRGB(200, 100, 150), desc = 'FireServer("hit")'},
        {args = {"Dagger"}, name = "DAGGER", color = Color3.fromRGB(150, 50, 200), desc = 'FireServer("Dagger")'},
        {args = {"parry", true}, name = "PARRY + TRUE", color = Color3.fromRGB(255, 150, 0), desc = 'FireServer("parry", true)'},
        {args = {"Block"}, name = "BLOCK (capital)", color = Color3.fromRGB(0, 200, 255), desc = 'FireServer("Block")'},
        {args = {"Parry"}, name = "PARRY (capital)", color = Color3.fromRGB(255, 100, 100), desc = 'FireServer("Parry")'},
        {args = {"parry"}, name = "PARRY", color = Color3.fromRGB(255, 200, 100), desc = 'FireServer("parry")'},
        {args = {"parry", "start"}, name = "PARRY START", color = Color3.fromRGB(200, 100, 50), desc = 'FireServer("parry", "start")'},
        {args = {"block", 1}, name = "BLOCK + 1", color = Color3.fromRGB(50, 150, 200), desc = 'FireServer("block", 1)'},
        {args = {"deflect", "on"}, name = "DEFLECT ON", color = Color3.fromRGB(50, 200, 100), desc = 'FireServer("deflect", "on")'},
        {args = {"counter", "activate"}, name = "COUNTER ACT", color = Color3.fromRGB(200, 150, 0), desc = 'FireServer("counter", "activate")'},
        {args = {"skill", "parry"}, name = "SKILL PARRY", color = Color3.fromRGB(150, 100, 200), desc = 'FireServer("skill", "parry")'},
        {args = {"ability", "block"}, name = "ABILITY BLOCK", color = Color3.fromRGB(100, 150, 200), desc = 'FireServer("ability", "block")'},
        {args = {"use", "parry"}, name = "USE PARRY", color = Color3.fromRGB(200, 80, 120), desc = 'FireServer("use", "parry")'},
        {args = {"activate", "block"}, name = "ACTIVATE BLOCK", color = Color3.fromRGB(80, 200, 150), desc = 'FireServer("activate", "block")'},
    }
    
    -- Tombol "Scan Remotes" (refresh daftar remote)
    local scanBtn = Instance.new("TextButton")
    scanBtn.Size = UDim2.new(0.9, 0, 0, 30)
    scanBtn.Text = "🔍 SCAN & FIND REMOTES"
    scanBtn.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
    scanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    scanBtn.Font = Enum.Font.GothamBold
    scanBtn.TextSize = 11
    scanBtn.Parent = buttonScroll
    local scanCorner = Instance.new("UICorner")
    scanCorner.CornerRadius = UDim.new(0, 4)
    scanCorner.Parent = scanBtn
    scanBtn.MouseButton1Click:Connect(function()
        refreshRemotes()
        addLog("📡 Remotes found: " .. #remotesToTest)
        for _, r in ipairs(remotesToTest) do
            addLog("   - " .. r.Name)
        end
    end)
    
    -- Separator
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(0.9, 0, 0, 1)
    sep.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    sep.BackgroundTransparency = 0.5
    sep.Parent = buttonScroll
    
    -- Tombol Auto Test All
    local autoTestBtn = Instance.new("TextButton")
    autoTestBtn.Size = UDim2.new(0.9, 0, 0, 30)
    autoTestBtn.Text = "⚡ AUTO TEST ALL REMOTES"
    autoTestBtn.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
    autoTestBtn.TextColor3 = Color3.fromRGB(255, 200, 100)
    autoTestBtn.Font = Enum.Font.GothamBold
    autoTestBtn.TextSize = 11
    autoTestBtn.Parent = buttonScroll
    local autoCorner = Instance.new("UICorner")
    autoCorner.CornerRadius = UDim.new(0, 4)
    autoCorner.Parent = autoTestBtn
    autoTestBtn.MouseButton1Click:Connect(function()
        if #remotesToTest == 0 then
            addLog("⚠️ No remotes found! Please scan first.")
            return
        end
        testAllRemotes()
    end)
    
    -- Separator lagi
    local sep2 = Instance.new("Frame")
    sep2.Size = UDim2.new(0.9, 0, 0, 1)
    sep2.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    sep2.BackgroundTransparency = 0.5
    sep2.Parent = buttonScroll
    
    -- Tombol untuk setiap variasi argumen (menggunakan remote pertama yang ditemukan)
    local function createVariationButton(variant)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.9, 0, 0, 32)
        btn.Text = variant.name
        btn.BackgroundColor3 = variant.color
        btn.BackgroundTransparency = 0.3
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
        btn.Parent = buttonScroll
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = btn
        
        -- Tooltip (desc) bisa di hover
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 0.1}):Play()
            addLog("ℹ️ " .. variant.desc)
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 0.3}):Play()
        end)
        
        btn.MouseButton1Click:Connect(function()
            if #remotesToTest == 0 then
                addLog("⚠️ No remotes found! Please scan first.")
                return
            end
            -- Gunakan remote pertama yang ditemukan, atau bisa juga loop semua
            local targetRemote = remotesToTest[1]
            if targetRemote then
                addLog("🎯 Testing on remote: " .. targetRemote.Name)
                testSingleRemote(targetRemote, variant.args, variant.name)
            else
                addLog("❌ No remote available")
            end
        end)
        
        return btn
    end
    
    -- Buat tombol untuk setiap variasi
    for _, variant in ipairs(argVariantsList) do
        createVariationButton(variant)
    end
    
    -- Tombol Clear Log
    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0.9, 0, 0, 28)
    clearBtn.Text = "🗑️ CLEAR LOG"
    clearBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    clearBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    clearBtn.Font = Enum.Font.GothamBold
    clearBtn.TextSize = 10
    clearBtn.Parent = buttonScroll
    local clearCorner = Instance.new("UICorner")
    clearCorner.CornerRadius = UDim.new(0, 4)
    clearCorner.Parent = clearBtn
    clearBtn.MouseButton1Click:Connect(function()
        for _, log in ipairs(logList) do
            log:Destroy()
        end
        logList = {}
        addLog("📋 Log cleared")
    end)
    
    -- Status info di bawah log
    local statusBar = Instance.new("Frame")
    statusBar.Size = UDim2.new(1, -10, 0, 20)
    statusBar.Position = UDim2.new(0, 5, 1, -22)
    statusBar.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    statusBar.BackgroundTransparency = 0.3
    statusBar.BorderSizePixel = 0
    statusBar.Parent = mainFrame
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 4)
    statusCorner.Parent = statusBar
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -10, 1, 0)
    statusLabel.Position = UDim2.new(0, 5, 0, 0)
    statusLabel.Text = "Ready. Click SCAN to find remotes, then test each button."
    statusLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 9
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = statusBar
    
    -- Log awal
    addLog("🧪 Parry Remote Tester v1.0 - Violence District")
    addLog("💡 Click 'SCAN & FIND REMOTES' to discover remote events")
    addLog("🎯 Then click any colored button to test that argument variation")
    addLog("🟢 GREEN/SUCCESS = remote accepted (may produce sound/effect)")
    addLog("🔴 RED/FAILED = remote rejected or no response")
    addLog("")
    addLog("⚡ Press F5 to toggle this GUI")
    
    refreshRemotes()
end

-- ============================================================================
-- KEYBIND TOGGLE GUI (F5)
-- ============================================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F5 then
        if screenGui and screenGui.Parent then
            screenGui:Destroy()
        else
            createGUI()
        end
    end
end)

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
local function init()
    print("╔═══════════════════════════════════════════════════════════════════╗")
    print("║           CYBERHEROES PARRY REMOTE TESTER v1.0                   ║")
    print("║           Test various remote event arguments for parry         ║")
    print("║           Press F5 to open/close GUI                            ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")
    createGUI()
end

task.wait(1)
init()
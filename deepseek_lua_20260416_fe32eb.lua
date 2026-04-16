--[[
    CYBERHEROES ESCAPE GATE FINDER & TELEPORTER v1.0
    For Delta Executor - Violence District
    Features:
    - Scan entire map for all exit gates
    - Copy gate coordinates to clipboard
    - Teleport to any coordinate (manual paste)
    - Auto teleport to nearest gate
--]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local localPlayer = Players.LocalPlayer
local localCharacter = nil
local localRootPart = nil

-- GUI References
local screenGui = nil
local mainFrame = nil
local gateList = {}
local gateButtons = {}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================
local function getLocalCharacter()
    localCharacter = localPlayer.Character
    if localCharacter then
        localRootPart = localCharacter:FindFirstChild("HumanoidRootPart") or 
                        localCharacter:FindFirstChild("Torso") or 
                        localCharacter:FindFirstChild("UpperTorso")
    end
    return localCharacter
end

-- Format Vector3 untuk clipboard
local function formatVector3(vec)
    return string.format("Vector3.new(%.2f, %.2f, %.2f)", vec.X, vec.Y, vec.Z)
end

-- Copy ke clipboard (Delta Executor support)
local function copyToClipboard(text)
    if setclipboard then
        pcall(function() setclipboard(text) end)
        return true
    elseif toclipboard then
        pcall(function() toclipboard(text) end)
        return true
    end
    return false
end

-- Teleport ke posisi tertentu
local function teleportTo(position)
    if not localRootPart then 
        getLocalCharacter()
        if not localRootPart then return false end
    end
    pcall(function() 
        localRootPart.CFrame = CFrame.new(position) 
    end)
    return true
end

-- ============================================================================
-- GATE DETECTION ENGINE
-- ============================================================================
local function isGate(obj)
    if not obj then return false end
    local name = obj.Name and obj.Name:lower() or ""
    -- Cek berdasarkan nama atau properti khas gate
    if name:find("gate") or name:find("exit") or name:find("door") or name:find("portal") then
        return true
    end
    -- Cek berdasarkan komponen interaksi
    if obj:FindFirstChildWhichIsA("ProximityPrompt") or obj:FindFirstChildWhichIsA("ClickDetector") then
        return true
    end
    -- Cek berdasarkan parent
    local parent = obj.Parent
    if parent and parent.Name and parent.Name:lower():find("gate") then
        return true
    end
    return false
end

local function getAllGates()
    local gates = {}
    local processed = {}
    
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if isGate(obj) and not processed[obj] then
            processed[obj] = true
            -- Dapatkan posisi gate (coba dari berbagai kemungkinan)
            local gatePos = nil
            if obj:IsA("BasePart") then
                gatePos = obj.Position
            elseif obj:IsA("Model") then
                local primary = obj:FindFirstChild("PrimaryPart")
                if primary then
                    gatePos = primary.Position
                else
                    local anyPart = obj:FindFirstChildWhichIsA("BasePart")
                    if anyPart then
                        gatePos = anyPart.Position
                    end
                end
            end
            
            if gatePos then
                table.insert(gates, {
                    instance = obj,
                    name = obj.Name,
                    position = gatePos,
                    vectorString = formatVector3(gatePos)
                })
            end
        end
    end
    
    return gates
end

-- ============================================================================
-- GUI CREATION
-- ============================================================================
local function createGUI()
    if screenGui then screenGui:Destroy() end
    
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_GateFinder"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = CoreGui
    screenGui.ResetOnSpawn = false
    
    -- Main Window
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainWindow"
    mainFrame.Size = UDim2.new(0, 320, 0, 400)
    mainFrame.Position = UDim2.new(0.5, -160, 0.5, -200)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 5, 10)
    mainFrame.BackgroundTransparency = 0.05
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 8)
    mainCorner.Parent = mainFrame
    
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(0, 230, 255)
    mainStroke.Thickness = 1.5
    mainStroke.Transparency = 0.4
    mainStroke.Parent = mainFrame
    
    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 28)
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
    title.Text = "🚪 ESCAPE GATE FINDER"
    title.TextColor3 = Color3.fromRGB(0, 230, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 22, 0, 22)
    closeBtn.Position = UDim2.new(1, -26, 0, 3)
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
    
    -- Draggable functionality
    local dragging = false
    local dragStart, startPos
    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    mainFrame.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                          startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    -- Scan button
    local scanBtn = Instance.new("TextButton")
    scanBtn.Size = UDim2.new(0.9, 0, 0, 35)
    scanBtn.Position = UDim2.new(0.05, 0, 0.1, 0)
    scanBtn.Text = "🔍 SCAN GATES"
    scanBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    scanBtn.BackgroundTransparency = 0.1
    scanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    scanBtn.TextSize = 12
    scanBtn.Font = Enum.Font.GateBodyGuard.GothamBold
    scanBtn.BorderSizePixel = 0
    scanBtn.Parent = mainFrame
    local scanCorner = Instance.new("UICorner")
    scanCorner.CornerRadius = UDim.new(0, 6)
    scanCorner.Parent = scanBtn
    
    -- Status label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0.9, 0, 0, 20)
    statusLabel.Position = UDim2.new(0.05, 0, 0.2, 0)
    statusLabel.Text = "Click SCAN to find escape gates"
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 10
    statusLabel.Parent = mainFrame
    
    -- Gate list scrolling frame
    local gateScroll = Instance.new("ScrollingFrame")
    gateScroll.Size = UDim2.new(0.9, 0, 0, 180)
    gateScroll.Position = UDim2.new(0.05, 0, 0.28, 0)
    gateScroll.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    gateScroll.BackgroundTransparency = 0.3
    gateScroll.BorderSizePixel = 0
    gateScroll.ScrollBarThickness = 6
    gateScroll.Parent = mainFrame
    local gateCorner = Instance.new("UICorner")
    gateCorner.CornerRadius = UDim.new(0, 6)
    gateCorner.Parent = gateScroll
    
    local gateListLayout = Instance.new("UIListLayout")
    gateListLayout.Padding = UDim.new(0, 4)
    gateListLayout.Parent = gateScroll
    
    -- Manual teleport section
    local manualLabel = Instance.new("TextLabel")
    manualLabel.Size = UDim2.new(0.9, 0, 0, 20)
    manualLabel.Position = UDim2.new(0.05, 0, 0.72, 0)
    manualLabel.Text = "MANUAL TELEPORT"
    manualLabel.TextColor3 = Color3.fromRGB(0, 230, 255)
    manualLabel.BackgroundTransparency = 1
    manualLabel.Font = Enum.Font.GothamBold
    manualLabel.TextSize = 10
    manualLabel.Parent = mainFrame
    
    local coordInput = Instance.new("TextBox")
    coordInput.Size = UDim2.new(0.9, 0, 0, 30)
    coordInput.Position = UDim2.new(0.05, 0, 0.77, 0)
    coordInput.PlaceholderText = "Paste coordinates: Vector3.new(x, y, z)"
    coordInput.Text = ""
    coordInput.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    coordInput.BackgroundTransparency = 0.3
    coordInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    coordInput.Font = Enum.Font.Gotham
    coordInput.TextSize = 10
    coordInput.BorderSizePixel = 0
    coordInput.Parent = mainFrame
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 4)
    inputCorner.Parent = coordInput
    
    local teleportBtn = Instance.new("TextButton")
    teleportBtn.Size = UDim2.new(0.9, 0, 0, 30)
    teleportBtn.Position = UDim2.new(0.05, 0, 0.85, 0)
    teleportBtn.Text = "✨ TELEPORT"
    teleportBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    teleportBtn.BackgroundTransparency = 0.1
    teleportBtn.TextColor3 = Color3.fromRGB(0, 230, 255)
    teleportBtn.TextSize = 12
    teleportBtn.Font = Enum.Font.GothamBold
    teleportBtn.BorderSizePixel = 0
    teleportBtn.Parent = mainFrame
    local teleCorner = Instance.new("UICorner")
    teleCorner.CornerRadius = UDim.new(0, 6)
    teleCorner.Parent = teleportBtn
    
    -- Teleport to nearest button
    local nearestBtn = Instance.new("TextButton")
    nearestBtn.Size = UDim2.new(0.9, 0, 0, 25)
    nearestBtn.Position = UDim2.new(0.05, 0, 0.93, 0)
    nearestBtn.Text = "📍 TELEPORT TO NEAREST GATE"
    nearestBtn.BackgroundColor3 = Color3.fromRGB(30, 5, 8)
    nearestBtn.BackgroundTransparency = 0.2
    nearestBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    nearestBtn.TextSize = 10
    nearestBtn.Font = Enum.Font.GothamBold
    nearestBtn.BorderSizePixel = 0
    nearestBtn.Parent = mainFrame
    local nearCorner = Instance.new("UICorner")
    nearCorner.CornerRadius = UDim.new(0, 6)
    nearCorner.Parent = nearestBtn
    
    -- Scan action
    scanBtn.MouseButton1Click:Connect(function()
        -- Clear existing buttons
        for _, btn in ipairs(gateButtons) do
            btn:Destroy()
        end
        gateButtons = {}
        gateList = {}
        
        statusLabel.Text = "Scanning for gates..."
        statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
        
        task.wait(0.1)
        
        local gates = getAllGates()
        
        if #gates == 0 then
            statusLabel.Text = "No gates found! Try moving around the map."
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end
        
        gateList = gates
        
        for _, gate in ipairs(gates) do
            local gateBtn = Instance.new("TextButton")
            gateBtn.Size = UDim2.new(1, 0, 0, 28)
            gateBtn.Text = string.format("📌 %s [%.0f, %.0f, %.0f]", 
                gate.name, gate.position.X, gate.position.Y, gate.position.Z)
            gateBtn.BackgroundColor3 = Color3.fromRGB(20, 5, 10)
            gateBtn.BackgroundTransparency = 0.3
            gateBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
            gateBtn.TextSize = 10
            gateBtn.Font = Enum.Font.Gotham
            gateBtn.TextXAlignment = Enum.TextXAlignment.Left
            gateBtn.BorderSizePixel = 0
            gateBtn.Parent = gateScroll
            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 4)
            btnCorner.Parent = gateBtn
            
            gateBtn.MouseButton1Click:Connect(function()
                -- Copy coordinates to clipboard
                if copyToClipboard(gate.vectorString) then
                    statusLabel.Text = "✓ Copied: " .. gate.vectorString
                    statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                    coordInput.Text = gate.vectorString
                    task.wait(2)
                    statusLabel.Text = #gateList .. " gate(s) found"
                    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
                else
                    statusLabel.Text = "✗ Failed to copy! Paste manually."
                    statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                    coordInput.Text = gate.vectorString
                end
            end)
            
            table.insert(gateButtons, gateBtn)
        end
        
        statusLabel.Text = #gateList .. " gate(s) found! Click on any to copy coordinates."
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        
        -- Update canvas size
        gateScroll.CanvasSize = UDim2.new(0, 0, 0, #gateList * 32 + 10)
    end)
    
    -- Manual teleport action
    teleportBtn.MouseButton1Click:Connect(function()
        local inputText = coordInput.Text:gsub("%s+", "")
        if inputText == "" then
            statusLabel.Text = "⚠️ Paste coordinates first!"
            statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
            return
        end
        
        -- Parse Vector3 from string
        local x, y, z = inputText:match("Vector3%.new%(([%d%.%-]+),%s*([%d%.%-]+),%s*([%d%.%-]+)%)")
        if not x then
            x, y, z = inputText:match("([%d%.%-]+),%s*([%d%.%-]+),%s*([%d%.%-]+)")
        end
        
        if x and y and z then
            x, y, z = tonumber(x), tonumber(y), tonumber(z)
            if x and y and z then
                if teleportTo(Vector3.new(x, y, z)) then
                    statusLabel.Text = "✨ Teleported to: " .. string.format("%.0f, %.0f, %.0f", x, y, z)
                    statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                else
                    statusLabel.Text = "❌ Teleport failed! Character not loaded."
                    statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                end
                return
            end
        end
        
        statusLabel.Text = "❌ Invalid coordinates format!"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    end)
    
    -- Teleport to nearest gate
    nearestBtn.MouseButton1Click:Connect(function()
        if #gateList == 0 then
            statusLabel.Text = "⚠️ Scan for gates first!"
            statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
            return
        end
        
        getLocalCharacter()
        if not localRootPart then
            statusLabel.Text = "❌ Character not found!"
            return
        end
        
        local localPos = localRootPart.Position
        local nearest = nil
        local minDist = math.huge
        
        for _, gate in ipairs(gateList) do
            local dist = (localPos - gate.position).Magnitude
            if dist < minDist then
                minDist = dist
                nearest = gate
            end
        end
        
        if nearest and teleportTo(nearest.position) then
            statusLabel.Text = "📍 Teleported to: " .. nearest.name
            statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            coordInput.Text = nearest.vectorString
        else
            statusLabel.Text = "❌ Teleport failed!"
        end
    end)
    
    -- Fade in animation
    mainFrame.BackgroundTransparency = 0.3
    TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.05}):Play()
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
local function init()
    print("╔═══════════════════════════════════════════════════════════════════╗")
    print("║           CYBERHEROES ESCAPE GATE FINDER & TELEPORTER             ║")
    print("║              Find all exit gates & copy coordinates              ║")
    print("║                   System initialized!                           ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")
    createGUI()
end

init()
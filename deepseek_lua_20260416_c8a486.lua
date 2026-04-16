--[[
    CYBERHEROES COORDINATE COPIER & TELEPORTER v1.0
    For Delta Executor - Violence District
    Features:
    - Copy current player position to clipboard
    - Paste coordinates and teleport instantly
    - Simple, lightweight GUI
--]]

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local localPlayer = Players.LocalPlayer
local localCharacter = nil
local localRootPart = nil

-- GUI References
local screenGui = nil
local mainFrame = nil
local coordInput = nil
local statusLabel = nil

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
    getLocalCharacter()
    if not localRootPart then 
        statusLabel.Text = "❌ Character not loaded!"
        return false
    end
    pcall(function() 
        localRootPart.CFrame = CFrame.new(position) 
    end)
    return true
end

-- Parse koordinat dari string
local function parseCoordinates(input)
    -- Remove spaces
    local clean = input:gsub("%s+", "")
    -- Try Vector3.new format
    local x, y, z = clean:match("Vector3%.new%(([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)%)")
    if not x then
        -- Try plain "x, y, z" format
        x, y, z = clean:match("([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)")
    end
    if x and y and z then
        return Vector3.new(tonumber(x), tonumber(y), tonumber(z))
    end
    return nil
end

-- ============================================================================
-- GUI CREATION
-- ============================================================================
local function createGUI()
    if screenGui then screenGui:Destroy() end
    
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_CoordTool"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = CoreGui
    screenGui.ResetOnSpawn = false
    
    -- Main Window
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainWindow"
    mainFrame.Size = UDim2.new(0, 280, 0, 220)
    mainFrame.Position = UDim2.new(0.5, -140, 0.5, -110)
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
    title.Size = UDim2.new(0.7, 0, 1, 0)
    title.Position = UDim2.new(0.02, 0, 0, 0)
    title.Text = "📍 COORDINATE TOOL"
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
    
    -- Draggable
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
    
    -- Status label
    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0.9, 0, 0, 20)
    statusLabel.Position = UDim2.new(0.05, 0, 0.05, 0)
    statusLabel.Text = "Ready"
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 10
    statusLabel.Parent = mainFrame
    
    -- Copy current position button
    local copyPosBtn = Instance.new("TextButton")
    copyPosBtn.Size = UDim2.new(0.9, 0, 0, 35)
    copyPosBtn.Position = UDim2.new(0.05, 0, 0.15, 0)
    copyPosBtn.Text = "📋 COPY MY POSITION"
    copyPosBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    copyPosBtn.BackgroundTransparency = 0.1
    copyPosBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    copyPosBtn.TextSize = 12
    copyPosBtn.Font = Enum.Font.GothamBold
    copyPosBtn.BorderSizePixel = 0
    copyPosBtn.Parent = mainFrame
    local copyCorner = Instance.new("UICorner")
    copyCorner.CornerRadius = UDim.new(0, 6)
    copyCorner.Parent = copyPosBtn
    
    copyPosBtn.MouseButton1Click:Connect(function()
        getLocalCharacter()
        if not localRootPart then
            statusLabel.Text = "❌ Character not found!"
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end
        local pos = localRootPart.Position
        local posStr = formatVector3(pos)
        if copyToClipboard(posStr) then
            statusLabel.Text = "✓ Copied: " .. posStr
            statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            coordInput.Text = posStr
            task.wait(2)
            statusLabel.Text = "Ready"
            statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        else
            statusLabel.Text = "❌ Copy failed! Manual copy: " .. posStr
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            coordInput.Text = posStr
        end
    end)
    
    -- Input field for coordinates
    local inputLabel = Instance.new("TextLabel")
    inputLabel.Size = UDim2.new(0.9, 0, 0, 16)
    inputLabel.Position = UDim2.new(0.05, 0, 0.3, 0)
    inputLabel.Text = "Enter coordinates (Vector3.new format or x,y,z):"
    inputLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    inputLabel.BackgroundTransparency = 1
    inputLabel.Font = Enum.Font.Gotham
    inputLabel.TextSize = 9
    inputLabel.Parent = mainFrame
    
    coordInput = Instance.new("TextBox")
    coordInput.Size = UDim2.new(0.9, 0, 0, 30)
    coordInput.Position = UDim2.new(0.05, 0, 0.37, 0)
    coordInput.PlaceholderText = "Vector3.new(100, 20, 50) or 100,20,50"
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
    
    -- Teleport button
    local teleportBtn = Instance.new("TextButton")
    teleportBtn.Size = UDim2.new(0.9, 0, 0, 35)
    teleportBtn.Position = UDim2.new(0.05, 0, 0.52, 0)
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
    
    teleportBtn.MouseButton1Click:Connect(function()
        local inputText = coordInput.Text:gsub("%s+", "")
        if inputText == "" then
            statusLabel.Text = "⚠️ Enter coordinates first!"
            statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
            return
        end
        
        local pos = parseCoordinates(inputText)
        if pos then
            if teleportTo(pos) then
                statusLabel.Text = "✨ Teleported to " .. formatVector3(pos)
                statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            else
                statusLabel.Text = "❌ Teleport failed!"
                statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            end
        else
            statusLabel.Text = "❌ Invalid coordinates format!"
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
    end)
    
    -- Copy input button
    local copyInputBtn = Instance.new("TextButton")
    copyInputBtn.Size = UDim2.new(0.9, 0, 0, 30)
    copyInputBtn.Position = UDim2.new(0.05, 0, 0.68, 0)
    copyInputBtn.Text = "📋 COPY FROM INPUT"
    copyInputBtn.BackgroundColor3 = Color3.fromRGB(30, 5, 8)
    copyInputBtn.BackgroundTransparency = 0.2
    copyInputBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    copyInputBtn.TextSize = 10
    copyInputBtn.Font = Enum.Font.GothamBold
    copyInputBtn.BorderSizePixel = 0
    copyInputBtn.Parent = mainFrame
    local copyInCorner = Instance.new("UICorner")
    copyInCorner.CornerRadius = UDim.new(0, 6)
    copyInCorner.Parent = copyInputBtn
    
    copyInputBtn.MouseButton1Click:Connect(function()
        local inputText = coordInput.Text
        if inputText == "" then
            statusLabel.Text = "⚠️ Input is empty!"
            statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
            return
        end
        if copyToClipboard(inputText) then
            statusLabel.Text = "✓ Copied input to clipboard"
            statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            task.wait(1.5)
            statusLabel.Text = "Ready"
            statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        else
            statusLabel.Text = "❌ Copy failed"
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
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
    print("║           CYBERHEROES COORDINATE COPIER & TELEPORTER              ║")
    print("║                   System initialized!                           ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")
    createGUI()
end

init()
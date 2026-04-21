--[[
    CYBERHEROES SMART TELEPORT v2.0
    Auto-detect semua objek bernama "TeleportPart1" hingga "TeleportPart26"
    Atau format lain: "CHECKPOINT 1", "Checkpoint1", "Trigger1", dll.
    Menampilkan daftar objek yang ditemukan sebelum teleport
    Developed for Delta Executor
--]]

-- ============================================================================
-- SERVICES
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local localCharacter = nil
local localRootPart = nil

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local config = {
    teleportDelay = 0.1,
    autoStart = false
}

-- ============================================================================
-- STATE VARIABLES
-- ============================================================================
local screenGui = nil
local mainFrame = nil
local startButton = nil
local statusLabel = nil
local progressLabel = nil
local isTeleporting = false
local foundObjects = {}  -- {name, position, number}

-- ============================================================================
-- UTILITY
-- ============================================================================
local function getLocalCharacter()
    localCharacter = localPlayer.Character
    if localCharacter then
        localRootPart = localCharacter:FindFirstChild("HumanoidRootPart") or 
                        localCharacter:FindFirstChild("Torso") or 
                        localCharacter:FindFirstChild("UpperTorso")
        if not localRootPart then
            warn("No HumanoidRootPart/Torso found!")
        end
    else
        warn("Character not loaded yet!")
    end
    return localCharacter
end

local function teleportTo(position)
    if not localRootPart then 
        warn("Cannot teleport: no root part")
        return false 
    end
    if not position then 
        warn("Cannot teleport: position is nil")
        return false 
    end
    local success, err = pcall(function()
        localRootPart.CFrame = CFrame.new(position)
    end)
    if not success then
        warn("Teleport failed: " .. tostring(err))
    end
    return success
end

-- ============================================================================
-- DETEKSI SEMUA OBJEK TELEPORT (FLEKSIBEL)
-- ============================================================================
local function detectTeleportObjects()
    local objects = {}
    local patterns = {
        { prefix = "TeleportPart", hasSpace = false },   -- TeleportPart1
        { prefix = "CHECKPOINT ", hasSpace = true },      -- CHECKPOINT 1
        { prefix = "Checkpoint", hasSpace = false },      -- Checkpoint1
        { prefix = "Trigger", hasSpace = false },         -- Trigger1
        { prefix = "CP", hasSpace = false },              -- CP1
        { prefix = "Waypoint", hasSpace = false },        -- Waypoint1
    }
    
    -- Scan semua objek di Workspace
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local name = obj.Name
        -- Cari objek yang memiliki BasePart (bisa dijadikan target teleport)
        local part = nil
        if obj:IsA("BasePart") then
            part = obj
        elseif obj:FindFirstChildWhichIsA("BasePart") then
            part = obj:FindFirstChildWhichIsA("BasePart")
        end
        
        if part then
            -- Coba semua pola
            for _, pattern in ipairs(patterns) do
                local num = nil
                if pattern.hasSpace then
                    -- Format: "PREFIX 1"
                    local patternStr = "^" .. pattern.prefix .. "(%d+)$"
                    num = tonumber(string.match(name, patternStr))
                else
                    -- Format: "PREFIX1"
                    local patternStr = "^" .. pattern.prefix .. "(%d+)$"
                    num = tonumber(string.match(name, patternStr))
                end
                if num then
                    table.insert(objects, {
                        name = name,
                        number = num,
                        position = part.Position,
                        obj = obj
                    })
                    break
                end
            end
        end
    end
    
    -- Urutkan berdasarkan nomor
    table.sort(objects, function(a, b) return a.number < b.number end)
    return objects
end

-- ============================================================================
-- DETEKSI BASE CAMP
-- ============================================================================
local function detectBaseCamp()
    local keywords = {"BackBasecamp", "Basecamp", "Base", "Camp", "Spawn", "Lobby", "Start"}
    for _, keyword in ipairs(keywords) do
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if string.find(obj.Name, keyword) then
                local part = nil
                if obj:IsA("BasePart") then
                    part = obj
                elseif obj:FindFirstChildWhichIsA("BasePart") then
                    part = obj:FindFirstChildWhichIsA("BasePart")
                end
                if part then
                    return { name = obj.Name, position = part.Position }
                end
            end
        end
    end
    return nil
end

-- ============================================================================
-- CORE TELEPORT SEQUENCE
-- ============================================================================
local function startTeleportSequence()
    if isTeleporting then
        statusLabel.Text = "Already teleporting!"
        return
    end
    if not getLocalCharacter() then
        statusLabel.Text = "Character not found!"
        return
    end
    
    -- Deteksi objek sebelum mulai
    foundObjects = detectTeleportObjects()
    local baseCamp = detectBaseCamp()
    
    if #foundObjects == 0 then
        statusLabel.Text = "No teleport objects found!"
        progressLabel.Text = "Error: No TeleportPart/Checkpoint objects detected"
        -- Tampilkan daftar objek yang ada di workspace (debug)
        local allParts = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                table.insert(allParts, obj.Name)
            end
        end
        print("[Debug] BaseParts in workspace: " .. table.concat(allParts, ", "))
        return
    end
    
    if not baseCamp then
        statusLabel.Text = "Base camp not found, continuing without it"
    end
    
    isTeleporting = true
    startButton.Text = "TELEPORTING..."
    startButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
    statusLabel.Text = "Found " .. #foundObjects .. " teleport objects"
    progressLabel.Text = "Starting teleport sequence..."
    
    task.spawn(function()
        local successCount = 0
        local failCount = 0
        local total = #foundObjects + (baseCamp and 1 or 0)
        
        -- Teleport ke semua objek yang ditemukan (sudah terurut)
        for idx, obj in ipairs(foundObjects) do
            progressLabel.Text = "Teleporting to " .. obj.name .. " (" .. idx .. "/" .. #foundObjects .. ")"
            statusLabel.Text = "Teleporting to " .. obj.name
            
            if obj.position then
                local success = teleportTo(obj.position)
                if success then
                    successCount = successCount + 1
                    progressLabel.Text = "✓ " .. obj.name .. " success (" .. successCount .. "/" .. #foundObjects .. ")"
                else
                    failCount = failCount + 1
                    progressLabel.Text = "✗ " .. obj.name .. " teleport failed"
                end
            else
                failCount = failCount + 1
                progressLabel.Text = "✗ " .. obj.name .. " invalid position"
            end
            
            if idx < #foundObjects then
                task.wait(config.teleportDelay)
            end
        end
        
        -- Teleport ke base camp jika ada
        if baseCamp then
            progressLabel.Text = "Teleporting to " .. baseCamp.name .. " ..."
            statusLabel.Text = "Teleporting to base camp..."
            if teleportTo(baseCamp.position) then
                successCount = successCount + 1
                progressLabel.Text = "✓ " .. baseCamp.name .. " success"
                statusLabel.Text = "Teleport sequence completed!"
            else
                failCount = failCount + 1
                progressLabel.Text = "✗ " .. baseCamp.name .. " teleport failed"
                statusLabel.Text = "Base camp teleport failed!"
            end
        else
            statusLabel.Text = "Teleport sequence completed (no base camp)"
        end
        
        -- Final status
        progressLabel.Text = "Complete: " .. successCount .. "/" .. total .. " success"
        if failCount > 0 then
            statusLabel.Text = "Completed with " .. failCount .. " failures"
            statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
        else
            statusLabel.Text = "All teleports successful!"
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        end
        
        startButton.Text = "START TELEPORT"
        startButton.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
        isTeleporting = false
    end)
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

local function createGUI()
    if screenGui then screenGui:Destroy() end
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_SmartTeleport"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = CoreGui

    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 320, 0, 210)
    mainFrame.Position = UDim2.new(0.5, -160, 0.5, -105)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 5, 10)
    mainFrame.BackgroundTransparency = 0.15
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
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = titleBar

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.7, 0, 1, 0)
    title.Position = UDim2.new(0.05, 0, 0, 0)
    title.Text = "SMART TELEPORT v2.0"
    title.TextColor3 = Color3.fromRGB(0, 230, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 11
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 20, 0, 20)
    closeBtn.Position = UDim2.new(1, -24, 0, 2)
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

    -- Content
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -10, 1, -30)
    content.Position = UDim2.new(0, 5, 0, 28)
    content.BackgroundTransparency = 1
    content.Parent = mainFrame

    -- Info label
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(0.9, 0, 0, 30)
    infoLabel.Position = UDim2.new(0.05, 0, 0.05, 0)
    infoLabel.Text = "Auto-detects TeleportPart/Checkpoint objects"
    infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 11
    infoLabel.Parent = content

    -- Progress label
    progressLabel = Instance.new("TextLabel")
    progressLabel.Size = UDim2.new(0.9, 0, 0, 20)
    progressLabel.Position = UDim2.new(0.05, 0, 0.3, 0)
    progressLabel.Text = "Ready"
    progressLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
    progressLabel.BackgroundTransparency = 1
    progressLabel.Font = Enum.Font.Gotham
    progressLabel.TextSize = 10
    progressLabel.Parent = content

    -- Status label
    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0.9, 0, 0, 20)
    statusLabel.Position = UDim2.new(0.05, 0, 0.5, 0)
    statusLabel.Text = "Press START to detect & teleport"
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 10
    statusLabel.Parent = content

    -- Start button
    startButton = Instance.new("TextButton")
    startButton.Size = UDim2.new(0.6, 0, 0, 32)
    startButton.Position = UDim2.new(0.2, 0, 0.7, 0)
    startButton.Text = "START TELEPORT"
    startButton.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    startButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    startButton.TextSize = 12
    startButton.Font = Enum.Font.GothamBold
    startButton.BorderSizePixel = 0
    startButton.Parent = content
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = startButton

    startButton.MouseButton1Click:Connect(startTeleportSequence)

    makeDraggable(mainFrame)

    -- Fade in
    mainFrame.BackgroundTransparency = 0.3
    TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.15}):Play()
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
local function onCharacterAdded(character)
    localCharacter = character
    localRootPart = character:FindFirstChild("HumanoidRootPart") or 
                    character:FindFirstChild("Torso") or 
                    character:FindFirstChild("UpperTorso")
end

if localPlayer.Character then
    onCharacterAdded(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(onCharacterAdded)

-- Create GUI
createGUI()

print("Smart Teleport v2.0 loaded. Script will auto-detect TeleportPart/Checkpoint objects.")
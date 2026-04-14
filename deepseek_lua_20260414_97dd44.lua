--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║           CYBERHEROES SCRIPT BROWSER v2.0 - DELTA EXECUTOR       ║
    ║           Browse & Copy Scripts from Violence District           ║
    ║                   Developed by Deepseek-CH                       ║
    ║                                                                  ║
    ║   Features:                                                      ║
    ║   ✅ Browse folder structure (no extraction needed)              ║
    ║   ✅ View file content                                           ║
    ║   ✅ Copy file content to clipboard                              ║
    ║   ✅ Modern GUI with draggable window                            ║
    ║   ✅ Fast and lightweight                                        ║
    ╚═══════════════════════════════════════════════════════════════════╝
--]]

-- ============================================================================
-- SERVICES
-- ============================================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local localPlayer = Players.LocalPlayer

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local config = {
    basePath = "/storage/emulated/0/Download/ViolenceDistrict_Scripts/",
    guiToggleKey = Enum.KeyCode.F
}

-- ============================================================================
-- STATE VARIABLES
-- ============================================================================
local screenGui = nil
local mainFrame = nil
local currentPath = config.basePath
local fileList = {}
local isGuiVisible = true
local floatingLogo = nil
local isLogoVisible = false
local currentContentFrame = nil

-- ============================================================================
-- UTILITY FUNCTIONS (Delta Executor file operations)
-- ============================================================================

-- List files in a directory
local function listDirectory(path)
    local files = {}
    if listfiles then
        local success, result = pcall(function()
            local allFiles = listfiles(path)
            for _, file in ipairs(allFiles) do
                table.insert(files, file)
            end
        end)
        if not success then
            print("[Browser] Failed to list directory: " .. path)
        end
    else
        -- Fallback: use dummy data if no listfiles support
        print("[Browser] listfiles not available, using fallback")
        files = {
            config.basePath .. "Script/",
            config.basePath .. "LocalScript/",
            config.basePath .. "ModuleScript/"
        }
    end
    return files
end

-- Read file content
local function readFileContent(filePath)
    if readfile then
        local success, content = pcall(readfile, filePath)
        if success and content then
            return content
        end
    end
    return nil
end

-- Copy to clipboard (Delta Executor support)
local function copyToClipboard(text)
    if setclipboard then
        pcall(function()
            setclipboard(text)
        end)
        return true
    elseif toclipboard then
        pcall(function()
            toclipboard(text)
        end)
        return true
    end
    return false
end

-- ============================================================================
-- FILE BROWSER GUI
-- ============================================================================

-- Create content viewer window
local function showFileContent(filePath, fileName, fileContent)
    if currentContentFrame then
        currentContentFrame:Destroy()
        currentContentFrame = nil
    end
    
    local contentGui = Instance.new("ScreenGui")
    contentGui.Name = "CyberHeroes_ContentViewer"
    contentGui.Parent = localPlayer:FindFirstChild("PlayerGui") or CoreGui
    
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(0, 600, 0, 450)
    contentFrame.Position = UDim2.new(0.5, -300, 0.5, -225)
    contentFrame.BackgroundColor3 = Color3.fromRGB(18, 2, 5)
    contentFrame.BackgroundTransparency = 0.05
    contentFrame.BorderSizePixel = 0
    contentFrame.Parent = contentGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = contentFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 50, 50)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.4
    stroke.Parent = contentFrame
    
    -- Draggable
    local dragging = false
    local dragStart, startPos
    contentFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = contentFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    contentFrame.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            contentFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                             startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 32)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 3, 7)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0
    titleBar.Parent = contentFrame
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.6, 0, 1, 0)
    title.Position = UDim2.new(0.02, 0, 0, 0)
    title.Text = "> " .. fileName
    title.TextColor3 = Color3.fromRGB(0, 230, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -32, 0, 2)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function()
        contentGui:Destroy()
        currentContentFrame = nil
    end)
    
    -- Copy button
    local copyBtn = Instance.new("TextButton")
    copyBtn.Size = UDim2.new(0, 80, 0, 28)
    copyBtn.Position = UDim2.new(1, -120, 0, 2)
    copyBtn.Text = "📋 COPY"
    copyBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    copyBtn.BackgroundTransparency = 0.2
    copyBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    copyBtn.TextSize = 11
    copyBtn.Font = Enum.Font.GothamBold
    copyBtn.BorderSizePixel = 0
    copyBtn.Parent = titleBar
    local copyCorner = Instance.new("UICorner")
    copyCorner.CornerRadius = UDim.new(0, 4)
    copyCorner.Parent = copyBtn
    
    copyBtn.MouseButton1Click:Connect(function()
        if fileContent then
            if copyToClipboard(fileContent) then
                copyBtn.Text = "✓ COPIED!"
                task.wait(1)
                copyBtn.Text = "📋 COPY"
            else
                copyBtn.Text = "✗ FAILED"
                task.wait(1)
                copyBtn.Text = "📋 COPY"
            end
        end
    end)
    
    -- Scrollable content
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -10, 1, -42)
    scrollFrame.Position = UDim2.new(0, 5, 0, 38)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 50, 50)
    scrollFrame.Parent = contentFrame
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 0, 0)
    textLabel.Text = fileContent or "-- No content --"
    textLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    textLabel.BackgroundTransparency = 1
    textLabel.Font = Enum.Font.Code
    textLabel.TextSize = 11
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.TextYAlignment = Enum.TextYAlignment.Top
    textLabel.TextWrapped = true
    textLabel.Parent = scrollFrame
    
    -- Adjust height based on content
    textLabel.Text = fileContent or "-- No content --"
    local textHeight = textLabel.TextBounds.Y + 20
    textLabel.Size = UDim2.new(1, 0, 0, textHeight)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, textHeight)
    
    currentContentFrame = contentGui
end

-- Create file/folder item button
local function createItemButton(parent, name, isFolder, fullPath, yPos)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.9, 0, 0, 32)
    button.Position = UDim2.new(0.05, 0, 0, yPos)
    button.Text = (isFolder and "📁 " or "📄 ") .. name
    button.TextColor3 = isFolder and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)
    button.TextSize = 11
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    button.BackgroundTransparency = 0.3
    button.BorderSizePixel = 0
    button.Font = Enum.Font.Gotham
    button.Parent = parent
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = button
    
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.1), {BackgroundTransparency = 0.1}):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.1), {BackgroundTransparency = 0.3}):Play()
    end)
    
    if isFolder then
        button.MouseButton1Click:Connect(function()
            -- Navigate into folder
            refreshFileList(fullPath)
        end)
    else
        button.MouseButton1Click:Connect(function()
            -- Show file content
            local content = readFileContent(fullPath)
            if content then
                showFileContent(fullPath, name, content)
            else
                -- Show error
                local errorGui = Instance.new("ScreenGui")
                errorGui.Parent = localPlayer:FindFirstChild("PlayerGui") or CoreGui
                local errorFrame = Instance.new("Frame")
                errorFrame.Size = UDim2.new(0, 300, 0, 80)
                errorFrame.Position = UDim2.new(0.5, -150, 0.5, -40)
                errorFrame.BackgroundColor3 = Color3.fromRGB(30, 5, 10)
                errorFrame.BackgroundTransparency = 0.1
                errorFrame.BorderSizePixel = 0
                errorFrame.Parent = errorGui
                local errorCorner = Instance.new("UICorner")
                errorCorner.CornerRadius = UDim.new(0, 8)
                errorCorner.Parent = errorFrame
                
                local errorLabel = Instance.new("TextLabel")
                errorLabel.Size = UDim2.new(1, 0, 1, 0)
                errorLabel.Text = "Failed to read file!\nFile may not exist or permission denied."
                errorLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                errorLabel.BackgroundTransparency = 1
                errorLabel.Font = Enum.Font.Gotham
                errorLabel.TextSize = 11
                errorLabel.TextWrapped = true
                errorLabel.Parent = errorFrame
                
                task.wait(2)
                errorGui:Destroy()
            end
        end)
    end
    
    return button
end

-- Refresh file list for current path
local function refreshFileList(path)
    currentPath = path
    fileList = listDirectory(currentPath)
    
    -- Clear existing buttons in scroll frame
    local scrollFrame = mainFrame:FindFirstChild("ScrollFrame")
    if scrollFrame then
        for _, child in ipairs(scrollFrame:GetChildren()) do
            if child:IsA("TextButton") or child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        local yPos = 5
        local itemCount = 0
        
        -- Add parent folder button (if not at root)
        if currentPath ~= config.basePath and currentPath ~= "/storage/emulated/0/Download/" then
            local parentPath = currentPath:match("(.*)/[^/]+/") or config.basePath
            if parentPath == "" then parentPath = config.basePath end
            local parentBtn = createItemButton(scrollFrame, "..", true, parentPath, yPos)
            yPos = yPos + 36
            itemCount = itemCount + 1
        end
        
        -- Sort: folders first, then files
        local folders = {}
        local files = {}
        for _, item in ipairs(fileList) do
            local isDir = item:sub(-1) == "/"
            if isDir then
                table.insert(folders, item)
            else
                table.insert(files, item)
            end
        end
        table.sort(folders)
        table.sort(files)
        
        for _, folder in ipairs(folders) do
            local name = folder:match("([^/]+)/$") or folder:match("([^/]+)$") or "unknown"
            createItemButton(scrollFrame, name, true, folder, yPos)
            yPos = yPos + 36
            itemCount = itemCount + 1
        end
        
        for _, file in ipairs(files) do
            local name = file:match("([^/]+)$") or "unknown"
            createItemButton(scrollFrame, name, false, file, yPos)
            yPos = yPos + 36
            itemCount = itemCount + 1
        end
        
        if itemCount == 0 then
            local emptyLabel = Instance.new("TextLabel")
            emptyLabel.Size = UDim2.new(0.9, 0, 0, 30)
            emptyLabel.Position = UDim2.new(0.05, 0, 0, yPos)
            emptyLabel.Text = "Empty folder"
            emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            emptyLabel.BackgroundTransparency = 1
            emptyLabel.Font = Enum.Font.Gotham
            emptyLabel.TextSize = 11
            emptyLabel.Parent = scrollFrame
        end
        
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yPos + 40)
    end
    
    -- Update path label
    local pathLabel = mainFrame:FindFirstChild("PathLabel")
    if pathLabel then
        pathLabel.Text = "📍 " .. currentPath
    end
end

-- ============================================================================
-- RGB FLOATING LOGO (COLLAPSIBLE GUI TOGGLE)
-- ============================================================================
local function createFloatingLogo()
    if floatingLogo then floatingLogo:Destroy() end
    
    floatingLogo = Instance.new("ImageButton")
    floatingLogo.Name = "CyberHeroes_Logo"
    floatingLogo.Size = UDim2.new(0, 45, 0, 45)
    floatingLogo.Position = UDim2.new(0.5, -22, 0.85, -22)
    floatingLogo.BackgroundColor3 = Color3.fromRGB(25, 5, 5)
    floatingLogo.BackgroundTransparency = 0.2
    floatingLogo.BorderSizePixel = 0
    floatingLogo.Image = "https://private-user-images.githubusercontent.com/188855284/395046716-ec3d8730-8153-420a-aa42-d4595ae9e4e7.jpg?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NzYwODQ3ODIsIm5iZiI6MTc3NjA4NDQ4MiwicGF0aCI6Ii8xODg4NTUyODQvMzk1MDQ2NzE2LWVjM2Q4NzMwLTgxNTMtNDIwYS1hYTQyLWQ0NTk1YWU5ZTRlNy5qcGc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjYwNDEzJTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI2MDQxM1QxMjQ4MDJaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT1jMjA2Zjg4NzUzMjliOGFhMzIzZWUzOThlMjgyZTg5ZDYzMThiOWYzNDFmODVlYWI1MjY2NGM1YzRjZjUwMDFhJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCZyZXNwb25zZS1jb250ZW50LXR5cGU9aW1hZ2UlMkZqcGVnIn0.9PradVNUGRSvKqt969IekjMLXxRMykd6-dNYVC-jszU"
    floatingLogo.ImageColor3 = Color3.fromRGB(255, 80, 80)
    floatingLogo.ImageTransparency = 0.2
    floatingLogo.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = floatingLogo
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 50, 50)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.4
    stroke.Parent = floatingLogo
    
    local hue = 0
    task.spawn(function()
        while floatingLogo and floatingLogo.Parent do
            hue = (hue + 0.01) % 1
            local color = (hue < 0.5) and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(0, 200, 255)
            floatingLogo.ImageColor3 = color
            stroke.Color = color
            task.wait(0.1)
        end
    end)
    
    floatingLogo.MouseButton1Click:Connect(function()
        if mainFrame then
            mainFrame.Visible = true
            isGuiVisible = true
            floatingLogo.Visible = false
            isLogoVisible = false
            refreshFileList(currentPath)
        end
    end)
    
    return floatingLogo
end

-- ============================================================================
-- MAIN GUI
-- ============================================================================
local function createGUI()
    if screenGui then screenGui:Destroy() end
    
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_Browser"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = localPlayer:FindFirstChild("PlayerGui") or CoreGui
    
    -- Main window
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
    
    local outerStroke = Instance.new("UIStroke")
    outerStroke.Color = Color3.fromRGB(255, 50, 50)
    outerStroke.Thickness = 1.5
    outerStroke.Transparency = 0.4
    outerStroke.Parent = mainFrame
    
    local innerGradient = Instance.new("UIGradient")
    innerGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 5, 10)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 0, 2))
    })
    innerGradient.Parent = mainFrame
    
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
    
    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 32)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 3, 7)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.5, 0, 1, 0)
    title.Position = UDim2.new(0.02, 0, 0, 0)
    title.Text = "> CYBERHEROES SCRIPT BROWSER"
    title.TextColor3 = Color3.fromRGB(0, 230, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -32, 0, 2)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function()
        isGuiVisible = false
        mainFrame.Visible = false
        if not isLogoVisible then
            floatingLogo = createFloatingLogo()
            floatingLogo.Visible = true
            isLogoVisible = true
        end
    end)
    
    -- Minimize button
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 28, 0, 28)
    minimizeBtn.Position = UDim2.new(1, -64, 0, 2)
    minimizeBtn.Text = "−"
    minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    minimizeBtn.BackgroundTransparency = 0.2
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextSize = 18
    minimizeBtn.Parent = titleBar
    minimizeBtn.MouseButton1Click:Connect(function()
        isGuiVisible = false
        mainFrame.Visible = false
        print("[Browser] Window minimized. Press F to restore.")
    end)
    
    -- Path label
    local pathLabel = Instance.new("TextLabel")
    pathLabel.Name = "PathLabel"
    pathLabel.Size = UDim2.new(1, -10, 0, 24)
    pathLabel.Position = UDim2.new(0, 5, 0, 38)
    pathLabel.Text = "📍 " .. currentPath
    pathLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
    pathLabel.BackgroundTransparency = 1
    pathLabel.Font = Enum.Font.Gotham
    pathLabel.TextSize = 10
    pathLabel.TextXAlignment = Enum.TextXAlignment.Left
    pathLabel.Parent = mainFrame
    
    -- Scrollable file list
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ScrollFrame"
    scrollFrame.Size = UDim2.new(1, -10, 1, -70)
    scrollFrame.Position = UDim2.new(0, 5, 0, 68)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 50, 50)
    scrollFrame.Parent = mainFrame
    
    -- Initial load
    refreshFileList(currentPath)
    
    -- Fade in animation
    mainFrame.BackgroundTransparency = 0.3
    TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        BackgroundTransparency = 0.05
    }):Play()
end

-- ============================================================================
-- KEYBIND
-- ============================================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == config.guiToggleKey then
        isGuiVisible = not isGuiVisible
        if mainFrame then
            mainFrame.Visible = isGuiVisible
            if isGuiVisible then
                if floatingLogo then
                    floatingLogo.Visible = false
                    isLogoVisible = false
                end
                refreshFileList(currentPath)
            else
                if not isLogoVisible then
                    floatingLogo = createFloatingLogo()
                    floatingLogo.Visible = true
                    isLogoVisible = true
                end
            end
        end
    end
end)

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
local function init()
    print("╔═══════════════════════════════════════════════════════════════════╗")
    print("║           CYBERHEROES SCRIPT BROWSER v2.0                        ║")
    print("║           Browse & Copy Scripts from Violence District           ║")
    print("║                   System initialized!                           ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")
    createGUI()
end

task.wait(1)
init()
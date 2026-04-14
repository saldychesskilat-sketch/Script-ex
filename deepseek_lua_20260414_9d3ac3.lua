--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║           CYBERHEROES SCRIPT EXTRACTOR v1.0 - DELTA EXECUTOR      ║
    ║           Extract All Scripts from Violence District             ║
    ║                   Developed by Deepseek-CH                       ║
    ║                  For Android (Oppo A6x / Delta)                  ║
    ║                                                                  ║
    ║   Features:                                                      ║
    ║   ✅ Extract all Lua scripts from the game                       ║
    ║   ✅ Save to /storage/emulated/0/Download/ViolenceDistrict_Scripts║
    ║   ✅ GUI with folder viewer                                      ║
    ║   ✅ Auto-create folder structure                                ║
    ║   ✅ Progress indicator                                          ║
    ╚═══════════════════════════════════════════════════════════════════╝
--]]

-- ============================================================================
-- SERVICES
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local config = {
    savePath = "/storage/emulated/0/Download/ViolenceDistrict_Scripts/",
    maxRetries = 3,
    retryDelay = 0.5,
    batchSize = 5
}

-- ============================================================================
-- STATE VARIABLES
-- ============================================================================
local screenGui = nil
local mainFrame = nil
local statusLabel = nil
local progressBar = nil
local fileList = {}
local isExtracting = false
local floatingLogo = nil
local isLogoVisible = false
local fileBrowserOpen = false

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Generate unique ID untuk file
local function generateID()
    return HttpService:GenerateGUID(false)
end

-- Sanitasi nama file (hapus karakter ilegal)
local function sanitizeFilename(name)
    if not name then return "unnamed" end
    -- Replace invalid characters with underscore
    local sanitized = name:gsub("[<>:\"/\\|?*%[%]%s]", "_")
    -- Limit length
    if #sanitized > 100 then
        sanitized = sanitized:sub(1, 100)
    end
    return sanitized
end

-- Membuat folder dengan writefile (Delta Executor support)
local function createFolder(path)
    -- Delta Executor supports makefolder
    if makefolder then
        pcall(function()
            makefolder(path)
        end)
    end
end

-- Menulis file ke storage
local function writeToFile(filePath, content)
    local success = false
    for attempt = 1, config.maxRetries do
        success = pcall(function()
            if writefile then
                writefile(filePath, content)
            elseif writefile then
                -- Fallback jika writefile tidak tersedia
                writefile(filePath, content)
            else
                -- Jika tidak ada writefile, simpan ke variable global sementara
                _G.CyberHeroes_ExtractedData = _G.CyberHeroes_ExtractedData or {}
                _G.CyberHeroes_ExtractedData[filePath] = content
                success = true
                return
            end
        end)
        if success then break end
        task.wait(config.retryDelay)
    end
    return success
end

-- Baca isi folder (Delta Executor support)
local function listFolder(folderPath)
    local files = {}
    if listfiles then
        pcall(function()
            local allFiles = listfiles(folderPath)
            for _, file in ipairs(allFiles) do
                table.insert(files, file)
            end
        end)
    elseif _G.CyberHeroes_ExtractedData then
        for path, _ in pairs(_G.CyberHeroes_ExtractedData) do
            if path:match(folderPath) then
                table.insert(files, path)
            end
        end
    end
    return files
end

-- Baca isi file
local function readFile(filePath)
    if readfile then
        return pcall(readfile, filePath)
    elseif _G.CyberHeroes_ExtractedData and _G.CyberHeroes_ExtractedData[filePath] then
        return true, _G.CyberHeroes_ExtractedData[filePath]
    end
    return false, nil
end

-- ============================================================================
-- SCRIPT EXTRACTION ENGINE
-- ============================================================================

-- Mendapatkan semua instance dari game
local function getAllInstances()
    local instances = {}
    local processed = {}
    local queue = {game}
    
    while #queue > 0 do
        local current = table.remove(queue, 1)
        if not processed[current] then
            processed[current] = true
            table.insert(instances, current)
            
            -- Ambil semua children
            for _, child in ipairs(current:GetChildren()) do
                if not processed[child] then
                    table.insert(queue, child)
                end
            end
        end
    end
    
    return instances
end

-- Extract script source code
local function extractScriptSource(scriptInstance)
    local source = nil
    local success = false
    
    -- Method 1: Langsung akses .Source property (jika tersedia)
    pcall(function()
        if scriptInstance.Source then
            source = scriptInstance.Source
            success = true
        end
    end)
    
    -- Method 2: Gunakan getfenv/getrenv untuk akses environment
    if not success then
        pcall(function()
            if getrenv and getrenv().script and getrenv().script == scriptInstance then
                source = getrenv().script.Source
                success = true
            end
        end)
    end
    
    -- Method 3: Coba gunakan getfenv
    if not success then
        pcall(function()
            local env = getfenv(scriptInstance)
            if env and env.script and env.script.Source then
                source = env.script.Source
                success = true
            end
        end)
    end
    
    -- Method 4: Jika masih gagal, coba debug.getinfo
    if not success then
        pcall(function()
            local info = debug.getinfo(scriptInstance)
            if info and info.source then
                source = info.source
                success = true
            end
        end)
    end
    
    return success, source or "-- Source not available"
end

-- Extract all scripts from game
local function extractAllScripts()
    local extractedScripts = {}
    local allInstances = getAllInstances()
    local total = #allInstances
    local processed = 0
    
    print("[Extractor] Total instances to scan: " .. total)
    
    for _, instance in ipairs(allInstances) do
        processed = processed + 1
        
        -- Update progress setiap 10 instances
        if processed % 10 == 0 then
            if statusLabel then
                statusLabel.Text = "Scanning: " .. processed .. "/" .. total
            end
            task.wait()
        end
        
        -- Check if instance is a script
        if instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript") then
            local scriptType = "Script"
            if instance:IsA("LocalScript") then
                scriptType = "LocalScript"
            elseif instance:IsA("ModuleScript") then
                scriptType = "ModuleScript"
            end
            
            local success, source = extractScriptSource(instance)
            
            -- Get path hierarchy
            local path = ""
            local parent = instance
            local pathParts = {}
            while parent and parent ~= game do
                table.insert(pathParts, 1, parent.Name)
                parent = parent.Parent
            end
            path = table.concat(pathParts, "/")
            
            local filename = sanitizeFilename(instance.Name) .. ".lua"
            local fullPath = config.savePath .. scriptType .. "/" .. path .. "/"
            local filePath = fullPath .. filename
            
            table.insert(extractedScripts, {
                name = instance.Name,
                type = scriptType,
                path = path,
                fullPath = fullPath,
                filePath = filePath,
                source = source,
                success = success
            })
        end
    end
    
    return extractedScripts
end

-- Save all extracted scripts to storage
local function saveExtractedScripts(scripts)
    local saved = 0
    local failed = 0
    local total = #scripts
    
    -- Create base folder
    createFolder(config.savePath)
    
    for i, script in ipairs(scripts) do
        -- Update progress
        if statusLabel then
            statusLabel.Text = "Saving: " .. i .. "/" .. total
        end
        if progressBar then
            progressBar.Size = UDim2.new(i / total, 0, 1, 0)
        end
        task.wait()
        
        -- Create folder structure
        createFolder(config.savePath .. script.type)
        createFolder(script.fullPath)
        
        -- Write file
        local header = string.format("--[[\n    Script Name: %s\n    Type: %s\n    Path: %s\n    Extracted: %s\n--]]\n\n",
            script.name, script.type, script.path, os.date("%Y-%m-%d %H:%M:%S"))
        
        local content = header .. script.source
        if writeToFile(script.filePath, content) then
            saved = saved + 1
        else
            failed = failed + 1
            print("[Extractor] Failed to save: " .. script.filePath)
        end
        
        -- Small delay to prevent overwhelming the system
        if i % config.batchSize == 0 then
            task.wait(0.1)
        end
    end
    
    return saved, failed
end

-- ============================================================================
-- FILE BROWSER GUI
-- ============================================================================

-- Create file browser window
local function createFileBrowser()
    if fileBrowserOpen then return end
    fileBrowserOpen = true
    
    local browserGui = Instance.new("ScreenGui")
    browserGui.Name = "CyberHeroes_FileBrowser"
    browserGui.Parent = localPlayer:FindFirstChild("PlayerGui") or CoreGui
    
    local browserFrame = Instance.new("Frame")
    browserFrame.Size = UDim2.new(0, 500, 0, 400)
    browserFrame.Position = UDim2.new(0.5, -250, 0.5, -200)
    browserFrame.BackgroundColor3 = Color3.fromRGB(18, 2, 5)
    browserFrame.BackgroundTransparency = 0.05
    browserFrame.BorderSizePixel = 0
    browserFrame.Parent = browserGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = browserFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 50, 50)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.4
    stroke.Parent = browserFrame
    
    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 3, 7)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0
    titleBar.Parent = browserFrame
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.6, 0, 1, 0)
    title.Position = UDim2.new(0.02, 0, 0, 0)
    title.Text = "> EXTRACTED SCRIPTS"
    title.TextColor3 = Color3.fromRGB(0, 230, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    -- Close button
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
        browserGui:Destroy()
        fileBrowserOpen = false
    end)
    
    -- File list scrolling frame
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -10, 1, -40)
    scrollFrame.Position = UDim2.new(0, 5, 0, 35)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 50, 50)
    scrollFrame.Parent = browserFrame
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 4)
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = scrollFrame
    
    -- Populate file list
    local files = listFolder(config.savePath)
    if #files == 0 then
        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Size = UDim2.new(0.9, 0, 0, 30)
        emptyLabel.Text = "No files extracted yet. Run extraction first."
        emptyLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Font = Enum.Font.Gotham
        emptyLabel.TextSize = 12
        emptyLabel.Parent = scrollFrame
    else
        for _, file in ipairs(files) do
            local fileName = file:match("([^/]+)$") or file
            local fileButton = Instance.new("TextButton")
            fileButton.Size = UDim2.new(0.9, 0, 0, 30)
            fileButton.Text = "📄 " .. fileName
            fileButton.TextColor3 = Color3.fromRGB(200, 200, 200)
            fileButton.TextSize = 11
            fileButton.TextXAlignment = Enum.TextXAlignment.Left
            fileButton.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
            fileButton.BackgroundTransparency = 0.3
            fileButton.BorderSizePixel = 0
            fileButton.Font = Enum.Font.Gotham
            fileButton.Parent = scrollFrame
            
            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 4)
            btnCorner.Parent = fileButton
            
            fileButton.MouseButton1Click:Connect(function()
                -- Show file content in new window
                local success, content = readFile(file)
                if success and content then
                    local contentGui = Instance.new("ScreenGui")
                    contentGui.Name = "CyberHeroes_FileContent"
                    contentGui.Parent = localPlayer:FindFirstChild("PlayerGui") or CoreGui
                    
                    local contentFrame = Instance.new("Frame")
                    contentFrame.Size = UDim2.new(0, 600, 0, 400)
                    contentFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
                    contentFrame.BackgroundColor3 = Color3.fromRGB(18, 2, 5)
                    contentFrame.BackgroundTransparency = 0.05
                    contentFrame.BorderSizePixel = 0
                    contentFrame.Parent = contentGui
                    
                    local contentCorner = Instance.new("UICorner")
                    contentCorner.CornerRadius = UDim.new(0, 10)
                    contentCorner.Parent = contentFrame
                    
                    local contentStroke = Instance.new("UIStroke")
                    contentStroke.Color = Color3.fromRGB(255, 50, 50)
                    contentStroke.Thickness = 1.5
                    contentStroke.Transparency = 0.4
                    contentStroke.Parent = contentFrame
                    
                    -- Title bar
                    local contentTitleBar = Instance.new("Frame")
                    contentTitleBar.Size = UDim2.new(1, 0, 0, 30)
                    contentTitleBar.BackgroundColor3 = Color3.fromRGB(25, 3, 7)
                    contentTitleBar.BackgroundTransparency = 0.2
                    contentTitleBar.BorderSizePixel = 0
                    contentTitleBar.Parent = contentFrame
                    
                    local contentTitle = Instance.new("TextLabel")
                    contentTitle.Size = UDim2.new(0.6, 0, 1, 0)
                    contentTitle.Position = UDim2.new(0.02, 0, 0, 0)
                    contentTitle.Text = "> " .. fileName
                    contentTitle.TextColor3 = Color3.fromRGB(0, 230, 255)
                    contentTitle.BackgroundTransparency = 1
                    contentTitle.Font = Enum.Font.GothamBold
                    contentTitle.TextSize = 11
                    contentTitle.TextXAlignment = Enum.TextXAlignment.Left
                    contentTitle.Parent = contentTitleBar
                    
                    local contentCloseBtn = Instance.new("TextButton")
                    contentCloseBtn.Size = UDim2.new(0, 25, 0, 25)
                    contentCloseBtn.Position = UDim2.new(1, -28, 0, 2)
                    contentCloseBtn.Text = "✕"
                    contentCloseBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
                    contentCloseBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
                    contentCloseBtn.BackgroundTransparency = 0.2
                    contentCloseBtn.BorderSizePixel = 0
                    contentCloseBtn.Font = Enum.Font.GothamBold
                    contentCloseBtn.TextSize = 12
                    contentCloseBtn.Parent = contentTitleBar
                    contentCloseBtn.MouseButton1Click:Connect(function()
                        contentGui:Destroy()
                    end)
                    
                    local contentScroll = Instance.new("ScrollingFrame")
                    contentScroll.Size = UDim2.new(1, -10, 1, -40)
                    contentScroll.Position = UDim2.new(0, 5, 0, 35)
                    contentScroll.BackgroundTransparency = 1
                    contentScroll.BorderSizePixel = 0
                    contentScroll.ScrollBarThickness = 6
                    contentScroll.Parent = contentFrame
                    
                    local textLabel = Instance.new("TextLabel")
                    textLabel.Size = UDim2.new(1, 0, 0, 0)
                    textLabel.Text = content
                    textLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
                    textLabel.BackgroundTransparency = 1
                    textLabel.Font = Enum.Font.Code
                    textLabel.TextSize = 10
                    textLabel.TextXAlignment = Enum.TextXAlignment.Left
                    textLabel.TextYAlignment = Enum.TextYAlignment.Top
                    textLabel.TextWrapped = true
                    textLabel.Parent = contentScroll
                    
                    -- Auto adjust height
                    textLabel.Text = content
                    textLabel.Size = UDim2.new(1, 0, 0, textLabel.TextBounds.Y + 10)
                    contentScroll.CanvasSize = UDim2.new(0, 0, 0, textLabel.Size.Y.Offset)
                end
            end)
        end
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
            config.guiVisible = true
            floatingLogo.Visible = false
            isLogoVisible = false
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
    screenGui.Name = "CyberHeroes_Extractor"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = localPlayer:FindFirstChild("PlayerGui") or CoreGui
    
    -- Main panel
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainPanel"
    mainFrame.Size = UDim2.new(0, 500, 0, 300)
    mainFrame.Position = UDim2.new(0.5, -250, 0.5, -150)
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
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 3, 7)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.6, 0, 1, 0)
    title.Position = UDim2.new(0.02, 0, 0, 0)
    title.Text = "> CYBERHEROES SCRIPT EXTRACTOR"
    title.TextColor3 = Color3.fromRGB(0, 230, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    -- Close button
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
        config.guiVisible = false
        mainFrame.Visible = false
        if not isLogoVisible then
            floatingLogo = createFloatingLogo()
            floatingLogo.Visible = true
            isLogoVisible = true
        end
    end)
    
    -- Minimize button
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 25, 0, 25)
    minimizeBtn.Position = UDim2.new(1, -56, 0, 2)
    minimizeBtn.Text = "−"
    minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    minimizeBtn.BackgroundTransparency = 0.2
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextSize = 18
    minimizeBtn.Parent = titleBar
    minimizeBtn.MouseButton1Click:Connect(function()
        config.guiVisible = false
        mainFrame.Visible = false
        print("[GUI] Window minimized. Press F to restore.")
    end)
    
    -- Content
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -20, 1, -45)
    content.Position = UDim2.new(0, 10, 0, 40)
    content.BackgroundTransparency = 1
    content.Parent = mainFrame
    
    -- Status label
    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 0, 25)
    statusLabel.Text = "Ready to extract scripts"
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 11
    statusLabel.Parent = content
    
    -- Progress bar background
    local progressBg = Instance.new("Frame")
    progressBg.Size = UDim2.new(1, 0, 0, 8)
    progressBg.Position = UDim2.new(0, 0, 0, 30)
    progressBg.BackgroundColor3 = Color3.fromRGB(30, 5, 10)
    progressBg.BackgroundTransparency = 0.3
    progressBg.BorderSizePixel = 0
    progressBg.Parent = content
    
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(1, 0)
    bgCorner.Parent = progressBg
    
    -- Progress bar fill
    progressBar = Instance.new("Frame")
    progressBar.Size = UDim2.new(0, 0, 1, 0)
    progressBar.BackgroundColor3 = Color3.fromRGB(0, 230, 255)
    progressBar.BackgroundTransparency = 0.2
    progressBar.BorderSizePixel = 0
    progressBar.Parent = progressBg
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = progressBar
    
    -- Extract button
    local extractBtn = Instance.new("TextButton")
    extractBtn.Size = UDim2.new(0.45, 0, 0, 35)
    extractBtn.Position = UDim2.new(0, 0, 0, 50)
    extractBtn.Text = "▶ EXTRACT SCRIPTS"
    extractBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    extractBtn.BackgroundTransparency = 0.1
    extractBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    extractBtn.TextSize = 12
    extractBtn.Font = Enum.Font.GothamBold
    extractBtn.BorderSizePixel = 0
    extractBtn.Parent = content
    
    local extractCorner = Instance.new("UICorner")
    extractCorner.CornerRadius = UDim.new(0, 6)
    extractCorner.Parent = extractBtn
    
    -- Browse button
    local browseBtn = Instance.new("TextButton")
    browseBtn.Size = UDim2.new(0.45, 0, 0, 35)
    browseBtn.Position = UDim2.new(0.55, 0, 0, 50)
    browseBtn.Text = "📁 BROWSE FILES"
    browseBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    browseBtn.BackgroundTransparency = 0.1
    browseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    browseBtn.TextSize = 12
    browseBtn.Font = Enum.Font.GothamBold
    browseBtn.BorderSizePixel = 0
    browseBtn.Parent = content
    
    local browseCorner = Instance.new("UICorner")
    browseCorner.CornerRadius = UDim.new(0, 6)
    browseCorner.Parent = browseBtn
    
    -- Result label
    local resultLabel = Instance.new("TextLabel")
    resultLabel.Size = UDim2.new(1, 0, 0, 50)
    resultLabel.Position = UDim2.new(0, 0, 0, 95)
    resultLabel.Text = ""
    resultLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    resultLabel.BackgroundTransparency = 1
    resultLabel.Font = Enum.Font.Gotham
    resultLabel.TextSize = 10
    resultLabel.TextWrapped = true
    resultLabel.Parent = content
    
    -- Extract action
    extractBtn.MouseButton1Click:Connect(function()
        if isExtracting then
            resultLabel.Text = "Extraction already in progress!"
            return
        end
        
        isExtracting = true
        extractBtn.Text = "⏳ EXTRACTING..."
        extractBtn.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
        resultLabel.Text = ""
        progressBar.Size = UDim2.new(0, 0, 1, 0)
        
        task.spawn(function()
            local scripts = extractAllScripts()
            local saved, failed = saveExtractedScripts(scripts)
            
            resultLabel.Text = string.format("Extraction complete!\nSaved: %d scripts | Failed: %d\nLocation: %s",
                saved, failed, config.savePath)
            
            extractBtn.Text = "▶ EXTRACT SCRIPTS"
            extractBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
            isExtracting = false
            progressBar.Size = UDim2.new(1, 0, 1, 0)
            
            if statusLabel then
                statusLabel.Text = "Extraction completed"
            end
        end)
    end)
    
    -- Browse action
    browseBtn.MouseButton1Click:Connect(function()
        createFileBrowser()
    end)
    
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
    if input.KeyCode == Enum.KeyCode.F then
        config.guiVisible = not config.guiVisible
        if mainFrame then
            mainFrame.Visible = config.guiVisible
            if config.guiVisible then
                if floatingLogo then
                    floatingLogo.Visible = false
                    isLogoVisible = false
                end
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
    print("║           CYBERHEROES SCRIPT EXTRACTOR v1.0                      ║")
    print("║           Extract All Scripts from Violence District             ║")
    print("║                   System initialized!                           ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")
    createGUI()
end

task.wait(1)
init()
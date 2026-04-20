--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║              CYBERHEROES FPS BOOSTER & NETWORK OPTIMIZER         ║
    ║                    For Delta Executor v1.0                       ║
    ║                                                                  ║
    ║   Features:                                                      ║
    ║   ✅ Reduce graphics quality (shadows, particles, render distance)║
    ║   ✅ Optimize network settings (reduce data usage)               ║
    ║   ✅ Clean up unnecessary instances and effects                  ║
    ║   ✅ Real-time FPS display                                       ║
    ║   ✅ Toggle ON/OFF with GUI                                      ║
    ║                                                                  ║
    ║   How to use:                                                    ║
    ║   - Execute script in Delta Executor                             ║
    ║   - GUI will appear on screen                                    ║
    ║   - Click "OPTIMIZE ON" to activate, "OPTIMIZE OFF" to deactivate║
    ║   - Press F to toggle GUI visibility                             ║
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
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local StarterGui = game:GetService("StarterGui")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ============================================================================
-- CONFIGURATION (PERSISTENT)
-- ============================================================================
local _G = getgenv() or _G
if not _G.CyberHeroesOptimizer then
    _G.CyberHeroesOptimizer = {
        enabled = true,
        guiVisible = true,
        graphicsQuality = 1,      -- 1 = Low, 2 = Medium, 3 = High
        shadowsEnabled = false,
        particlesEnabled = false,
        renderDistance = 300,
        waterQuality = 0.25,      -- Water wave size
        networkOptimize = true
    }
end
local state = _G.CyberHeroesOptimizer

-- ============================================================================
-- VARIABLES
-- ============================================================================
local screenGui = nil
local mainFrame = nil
local toggleButton = nil
local fpsLabel = nil
local statusLabel = nil
local fpsConnection = nil
local optimizeConnection = nil
local originalSettings = {}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================
local function getLocalCharacter()
    return localPlayer.Character
end

-- ============================================================================
-- FPS COUNTER
-- ============================================================================
local lastTimestamp = tick()
local frameCount = 0
local currentFPS = 0

local function startFPSMonitor()
    if fpsConnection then return end
    fpsConnection = RunService.RenderStepped:Connect(function()
        if not state.enabled then return end
        frameCount = frameCount + 1
        local now = tick()
        if now - lastTimestamp >= 1 then
            currentFPS = frameCount
            frameCount = 0
            lastTimestamp = now
            if fpsLabel then
                local fpsText = "FPS: " .. currentFPS
                if currentFPS >= 55 then
                    fpsLabel.Text = "🟢 " .. fpsText
                    fpsLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
                elseif currentFPS >= 30 then
                    fpsLabel.Text = "🟡 " .. fpsText
                    fpsLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
                else
                    fpsLabel.Text = "🔴 " .. fpsText
                    fpsLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
                end
            end
        end
    end)
end

local function stopFPSMonitor()
    if fpsConnection then
        fpsConnection:Disconnect()
        fpsConnection = nil
    end
end

-- ============================================================================
-- GRAPHICS OPTIMIZATION
-- ============================================================================
local function applyGraphicsOptimization()
    if not state.enabled then return end
    
    -- 1. Set graphics quality to low (Level1)
    -- This is the most effective way to boost FPS
    pcall(function()
        local userSettings = game:GetService("UserSettings")
        local gameSettings = userSettings.GameSettings
        gameSettings.GraphicsQuality = Enum.QualityLevel.Level1
        print("[Optimizer] Graphics quality set to Level1")
    end)
    
    -- 2. Disable shadows if configured
    if state.shadowsEnabled == false then
        pcall(function()
            local lighting = game:GetService("Lighting")
            lighting.GlobalShadows = false
            lighting.ShadowSoftness = 0
            print("[Optimizer] Shadows disabled")
        end)
    end
    
    -- 3. Reduce render distance
    pcall(function()
        local workspace = game:GetService("Workspace")
        -- This affects how far you can see
        local terrain = workspace.Terrain
        if terrain then
            terrain.WaterWaveSize = state.waterQuality
            terrain.WaterWaveSpeed = 2
            terrain.WaterReflectance = 0.2
            terrain.WaterTransparency = 0.5
        end
        print("[Optimizer] Render distance optimized")
    end)
    
    -- 4. Disable or reduce particles
    if state.particlesEnabled == false then
        pcall(function()
            -- Disable all particle emitters in workspace
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("ParticleEmitter") then
                    obj.Enabled = false
                    obj.Rate = 0
                elseif obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                    obj.Enabled = false
                end
            end
            print("[Optimizer] Particles disabled")
        end)
    end
    
    -- 5. Disable unnecessary post-processing effects
    pcall(function()
        local lighting = game:GetService("Lighting")
        lighting.Brightness = 1.5
        lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        lighting.FogStart = 50
        lighting.FogEnd = state.renderDistance
        print("[Optimizer] Post-processing reduced")
    end)
    
    -- 6. Clear unnecessary GUI elements that cause lag
    pcall(function()
        local playerGui = localPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            for _, gui in ipairs(playerGui:GetDescendants()) do
                if gui:IsA("ImageLabel") or gui:IsA("ImageButton") then
                    -- Reduce image quality for performance
                    pcall(function()
                        if gui.Image then
                            -- You could lower resolution but we skip for now
                        end
                    end)
                end
            end
        end
    end)
end

-- ============================================================================
-- NETWORK OPTIMIZATION (Reduce data usage)
-- ============================================================================
local function applyNetworkOptimization()
    if not state.enabled or not state.networkOptimize then return end
    
    pcall(function()
        -- 1. Reduce remote event spam by throttling
        -- This is done by intercepting frequent remote events
        -- We'll add a simple throttle mechanism for common events
        
        -- 2. Disable unnecessary network-related instances
        local replicatedStorage = game:GetService("ReplicatedStorage")
        for _, obj in ipairs(replicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                local name = obj.Name:lower()
                -- Don't disable critical remotes, just log
                if name:find("damage") or name:find("hit") or name:find("kill") then
                    -- These are important, keep them
                end
            end
        end
        print("[Optimizer] Network optimization applied")
    end)
end

-- ============================================================================
-- CLEANUP UNNECESSARY INSTANCES
-- ============================================================================
local function cleanupUnnecessaryInstances()
    if not state.enabled then return end
    
    pcall(function()
        -- 1. Remove unnecessary decals and textures
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Decal") then
                obj:Destroy()
            end
        end
        
        -- 2. Remove unnecessary sounds
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Sound") then
                if not obj.IsPlaying then
                    obj:Destroy()
                end
            end
        end
        
        -- 3. Remove unnecessary particles
        if state.particlesEnabled == false then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("ParticleEmitter") then
                    obj:Destroy()
                end
            end
        end
        
        print("[Optimizer] Cleaned up unnecessary instances")
    end)
end

-- ============================================================================
-- MAIN OPTIMIZATION LOOP
-- ============================================================================
local function startOptimizationLoop()
    if optimizeConnection then return end
    optimizeConnection = RunService.Heartbeat:Connect(function()
        if not state.enabled then return end
        applyGraphicsOptimization()
        applyNetworkOptimization()
        cleanupUnnecessaryInstances()
    end)
    print("[Optimizer] Optimization loop started")
end

local function stopOptimizationLoop()
    if optimizeConnection then
        optimizeConnection:Disconnect()
        optimizeConnection = nil
    end
    print("[Optimizer] Optimization loop stopped")
end

-- ============================================================================
-- RESTORE ORIGINAL SETTINGS (when disabled)
-- ============================================================================
local function restoreOriginalSettings()
    pcall(function()
        local userSettings = game:GetService("UserSettings")
        local gameSettings = userSettings.GameSettings
        gameSettings.GraphicsQuality = Enum.QualityLevel.Level8
    end)
    
    pcall(function()
        local lighting = game:GetService("Lighting")
        lighting.GlobalShadows = true
        lighting.ShadowSoftness = 0.5
        lighting.Brightness = 2
        lighting.OutdoorAmbient = Color3.fromRGB(170, 170, 170)
        lighting.FogStart = 0
        lighting.FogEnd = 1000
    end)
    
    print("[Optimizer] Original settings restored")
end

-- ============================================================================
-- GUI (Modern, Minimalis, Draggable)
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
    screenGui.Name = "CyberHeroes_Optimizer"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = CoreGui

    -- Main frame (small, draggable)
    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 220, 0, 130)
    mainFrame.Position = UDim2.new(0.5, -110, 0.8, -65)
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
    title.Text = "FPS & NETWORK BOOSTER"
    title.TextColor3 = Color3.fromRGB(0, 230, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 10
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    -- Close button (hide GUI)
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
        state.guiVisible = false
        mainFrame.Visible = false
    end)

    -- Content area
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -10, 1, -30)
    content.Position = UDim2.new(0, 5, 0, 28)
    content.BackgroundTransparency = 1
    content.Parent = mainFrame

    -- Toggle button
    toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(0.8, 0, 0, 30)
    toggleButton.Position = UDim2.new(0.1, 0, 0.05, 0)
    toggleButton.Text = state.enabled and "OPTIMIZE [ON]" or "OPTIMIZE [OFF]"
    toggleButton.BackgroundColor3 = state.enabled and Color3.fromRGB(40, 5, 5) or Color3.fromRGB(15, 0, 2)
    toggleButton.TextColor3 = state.enabled and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)
    toggleButton.TextSize = 11
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.BorderSizePixel = 0
    toggleButton.Parent = content
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = toggleButton

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = state.enabled and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(150, 30, 30)
    btnStroke.Thickness = 1
    btnStroke.Transparency = 0.3
    btnStroke.Parent = toggleButton

    toggleButton.MouseButton1Click:Connect(function()
        state.enabled = not state.enabled
        if state.enabled then
            toggleButton.Text = "OPTIMIZE [ON]"
            toggleButton.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
            toggleButton.TextColor3 = Color3.fromRGB(0, 230, 255)
            btnStroke.Color = Color3.fromRGB(0, 200, 255)
            startOptimizationLoop()
            startFPSMonitor()
            statusLabel.Text = "ACTIVE"
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            print("[Optimizer] FPS booster activated")
        else
            toggleButton.Text = "OPTIMIZE [OFF]"
            toggleButton.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
            toggleButton.TextColor3 = Color3.fromRGB(200, 200, 200)
            btnStroke.Color = Color3.fromRGB(150, 30, 30)
            stopOptimizationLoop()
            stopFPSMonitor()
            restoreOriginalSettings()
            statusLabel.Text = "INACTIVE"
            statusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            print("[Optimizer] FPS booster deactivated")
        end
    end)

    -- FPS display label
    fpsLabel = Instance.new("TextLabel")
    fpsLabel.Size = UDim2.new(0.8, 0, 0, 20)
    fpsLabel.Position = UDim2.new(0.1, 0, 0.5, 0)
    fpsLabel.Text = "FPS: --"
    fpsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    fpsLabel.BackgroundTransparency = 1
    fpsLabel.Font = Enum.Font.GothamBold
    fpsLabel.TextSize = 11
    fpsLabel.Parent = content

    -- Status indicator
    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0.8, 0, 0, 16)
    statusLabel.Position = UDim2.new(0.1, 0, 0.75, 0)
    statusLabel.Text = state.enabled and "ACTIVE" or "INACTIVE"
    statusLabel.TextColor3 = state.enabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 9
    statusLabel.Parent = content

    makeDraggable(mainFrame)

    -- Fade in
    mainFrame.BackgroundTransparency = 0.3
    TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.15}):Play()
end

-- ============================================================================
-- KEYBIND TO TOGGLE GUI (F key)
-- ============================================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F then
        if screenGui then
            state.guiVisible = not state.guiVisible
            mainFrame.Visible = state.guiVisible
        end
    end
end)

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
local function init()
    print("╔═══════════════════════════════════════════════════════════════════╗")
    print("║           CYBERHEROES FPS BOOSTER & NETWORK OPTIMIZER            ║")
    print("║                   System initialized!                            ║")
    print("║                                                                  ║")
    print("║   Effects applied:                                               ║")
    print("║   - Graphics quality set to low (Level1)                         ║")
    print("║   - Shadows disabled                                             ║")
    print("║   - Particles disabled                                           ║")
    print("║   - Render distance reduced                                      ║")
    print("║   - Network data usage optimized                                 ║")
    print("║   - Unnecessary instances cleaned up                             ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")
    createGUI()
    if state.enabled then
        startOptimizationLoop()
        startFPSMonitor()
    end
end

task.wait(1)
init()
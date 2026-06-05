-- ============================================================================
-- GLOBAL STATE PERSISTENCE (getgenv) -- TIDAK DIUBAH
-- ============================================================================
local _G = getgenv() or _G
if not _G.CyberHeroesState then
    _G.CyberHeroesState = {
        config = {
            autoWinEnabled = false,
            autoTaskEnabled = false,
            taskRadius = 50,
            pathfindingParams = {
                AgentRadius = 2,
                AgentHeight = 5,
                AgentCanJump = true,
                AgentMaxSlope = 45
            },
            espEnabled = false,
            highlightColorKiller = Color3.fromRGB(255, 50, 50),
            highlightColorSurvivor = Color3.fromRGB(50, 255, 50),
            highlightTransparency = 0.5,
            speedBoostEnabled = false,
            boostAmount = 20,
            boostDuration = 3,
            originalWalkSpeed = 16,
            stealthEnabled = false,
            stealthRadiusInvisible = 30,
            stealthRadiusVisible = 50,
            godModeEnabled = false,
            infiniteAmmoEnabled = false,
            shieldEnabled = false,
            shieldRadius = 30,
            tpwalkEnabled = false,
            tpwalkDuration = 3,
            tpwalkSpeedMultiplier = 2,
            noCollideEnabled = false,
            noCollideRadius = 30,
            massKillEnabled = false,
            autoGeneratorEnabled = false,
            autoSkillCheckEnabled = false,
            autoAimEnabled = false,
            guiVisible = true,
            guiToggleKey = Enum.KeyCode.F,
            lastHealth = 100,
            guiThemeColor = Color3.fromRGB(0, 230, 255),
            auto1xModeEnabled = false
        },
        featuresActive = {}
    }
end
local state = _G.CyberHeroesState
local config = state.config

-- ============================================================================
-- SERVICES
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local Debris = game:GetService("Debris")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")

local localPlayer = Players.LocalPlayer
local localCharacter = nil
local localHumanoid = nil
local localRootPart = nil
local camera = workspace.CurrentCamera

-- ============================================================================
-- GLOBAL REFERENCES
-- ============================================================================
screenGui = nil
mainFrame = nil
sidebar = nil
sidebarScroll = nil        -- NEW: ScrollingFrame untuk sidebar
contentPanel = nil
floatingLogo = nil
teleportButton = nil
teleportButtonGui = nil
mainStroke = nil
statusLabel = nil
settingsContent = nil
chatLog = nil
chatInput = nil
isLogoVisible = false
settingsContentCreated = false

-- ============================================================================
-- STATE VARIABLES (fitur - tidak diubah)
-- ============================================================================
local isSpeedBoostActive = false
local boostDebounce = false
local currentBoostConnection = nil
local currentTaskConnection = nil
local currentEspConnections = {}
local generatorCache = {}
local espHighlights = {}
local isInvisible = false
local stealthConnection = nil
local remoteEventCache = nil
local processedGenerators = {}
local godModeConnection = nil
local infiniteAmmoConnection = nil
local isScriptRunning = true
local shieldConnection = nil
local currentForceField = nil
local isShieldActive = false
local tpwalkConnection = nil
local isTpwalkActive = false
local noCollideConnection = nil
local isNoCollideActive = false
local originalWalkSpeed = 16
local massKillLoopConnection = nil
local autoGeneratorLoopConnection = nil
local autoSkillCheckConnection = nil
local autoAimConnection = nil
local TouchID = 8822
local ActionPath = "Survivor-mob.Controls.action.check"
local HeartbeatConnection = nil
local VisibilityConnection = nil
local generatorEspHighlights = {}
local autoWinConnection = nil
local autoTaskConnection = nil
local originalTpwalkSpeed = 16
local auto1xModeTimerConnection = nil
local isAuto1xModeActive = false

-- ============================================================================
-- UTILITY FUNCTIONS (tidak diubah)
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

local function teleportTo(position)
    if not localRootPart then return false end
    pcall(function() localRootPart.CFrame = CFrame.new(position) end)
    return true
end

local function teleportBehind(targetRoot)
    if not targetRoot or not localRootPart then return false end
    local targetCFrame = targetRoot.CFrame
    local behindPos = targetCFrame.Position - targetCFrame.LookVector * 2
    teleportTo(behindPos)
    return true
end

local function lockCameraTo(targetPos)
    if not camera then return end
    camera.CFrame = CFrame.new(camera.CFrame.Position, targetPos)
end

-- ============================================================================
-- DRAGGABLE (tidak berubah)
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

-- ============================================================================
-- THEME UPDATE (tidak diubah)
-- ============================================================================
local function updateTheme()
    if mainStroke then mainStroke.Color = config.guiThemeColor end
    if sidebar then
        for _, btn in ipairs(sidebar:GetDescendants()) do
            if btn:IsA("TextButton") and btn.Text:find("HOME") then
                btn.TextColor3 = config.guiThemeColor
            end
        end
    end
    if statusLabel then statusLabel.TextColor3 = config.guiThemeColor end
end

-- ============================================================================
-- SETTINGS CONTENT (DIPERBAIKI LAYOUTNYA)
-- ============================================================================
local function createSettingsContent()
    if settingsContent then settingsContent:Destroy() end
    settingsContent = Instance.new("Frame")
    settingsContent.Size = UDim2.new(1, 0, 1, 0)
    settingsContent.BackgroundTransparency = 1
    settingsContent.Parent = contentPanel

    -- Gunakan UIListLayout untuk mengatur elemen secara vertikal
    local mainLayout = Instance.new("UIListLayout")
    mainLayout.Padding = UDim.new(0, 8)
    mainLayout.FillDirection = Enum.FillDirection.Vertical
    mainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    mainLayout.Parent = settingsContent

    local topPadding = Instance.new("Frame")
    topPadding.Size = UDim2.new(1, 0, 0, 5)
    topPadding.BackgroundTransparency = 1
    topPadding.Parent = settingsContent

    -- Theme Color Label
    local colorLabel = Instance.new("TextLabel")
    colorLabel.Size = UDim2.new(0.9, 0, 0, 20)
    colorLabel.Text = "THEME COLOR"
    colorLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    colorLabel.BackgroundTransparency = 1
    colorLabel.Font = Enum.Font.GothamBold
    colorLabel.TextSize = 12
    colorLabel.TextXAlignment = Enum.TextXAlignment.Left
    colorLabel.Parent = settingsContent

    local colorButtonsFrame = Instance.new("Frame")
    colorButtonsFrame.Size = UDim2.new(0.9, 0, 0, 30)
    colorButtonsFrame.BackgroundTransparency = 1
    colorButtonsFrame.Parent = settingsContent

    local btnLayout = Instance.new("UIListLayout")
    btnLayout.FillDirection = Enum.FillDirection.Horizontal
    btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    btnLayout.Padding = UDim.new(0, 10)
    btnLayout.Parent = colorButtonsFrame

    local function createColorButton(text, bgColor, textColor)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 70, 0, 25)
        btn.Text = text
        btn.BackgroundColor3 = bgColor
        btn.TextColor3 = textColor
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
        btn.BorderSizePixel = 0
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = btn
        btn.Parent = colorButtonsFrame
        return btn
    end

    local colorRed = createColorButton("RED", Color3.fromRGB(255,0,0), Color3.fromRGB(255,255,255))
    local colorCyan = createColorButton("CYAN", Color3.fromRGB(0,255,255), Color3.fromRGB(0,0,0))
    local colorYellow = createColorButton("YELLOW", Color3.fromRGB(255,255,0), Color3.fromRGB(0,0,0))

    colorRed.MouseButton1Click:Connect(function()
        config.guiThemeColor = Color3.fromRGB(255, 0, 0)
        updateTheme()
    end)
    colorCyan.MouseButton1Click:Connect(function()
        config.guiThemeColor = Color3.fromRGB(0, 255, 255)
        updateTheme()
    end)
    colorYellow.MouseButton1Click:Connect(function()
        config.guiThemeColor = Color3.fromRGB(255, 255, 0)
        updateTheme()
    end)

    -- Chat Section Label
    local chatLabel = Instance.new("TextLabel")
    chatLabel.Size = UDim2.new(0.9, 0, 0, 20)
    chatLabel.Text = "CHAT LOG (REPORT)"
    chatLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    chatLabel.BackgroundTransparency = 1
    chatLabel.Font = Enum.Font.GothamBold
    chatLabel.TextSize = 12
    chatLabel.TextXAlignment = Enum.TextXAlignment.Left
    chatLabel.Parent = settingsContent

    -- ScrollingFrame untuk chat
    chatLog = Instance.new("ScrollingFrame")
    chatLog.Size = UDim2.new(0.9, 0, 0, 100)
    chatLog.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    chatLog.BackgroundTransparency = 0.3
    chatLog.BorderSizePixel = 0
    chatLog.ScrollBarThickness = 6
    chatLog.AutomaticCanvasSize = Enum.AutomaticSize.Y
    chatLog.CanvasSize = UDim2.new(0, 0, 0, 0)
    chatLog.Parent = settingsContent
    local chatCorner = Instance.new("UICorner")
    chatCorner.CornerRadius = UDim.new(0, 4)
    chatCorner.Parent = chatLog

    local chatListLayout = Instance.new("UIListLayout")
    chatListLayout.Padding = UDim.new(0, 2)
    chatListLayout.Parent = chatLog

    -- Input row
    local inputFrame = Instance.new("Frame")
    inputFrame.Size = UDim2.new(0.9, 0, 0, 30)
    inputFrame.BackgroundTransparency = 1
    inputFrame.Parent = settingsContent

    local inputLayout = Instance.new("UIListLayout")
    inputLayout.FillDirection = Enum.FillDirection.Horizontal
    inputLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    inputLayout.Padding = UDim.new(0, 8)
    inputLayout.Parent = inputFrame

    chatInput = Instance.new("TextBox")
    chatInput.Size = UDim2.new(0.7, 0, 1, 0)
    chatInput.PlaceholderText = "type report..."
    chatInput.Text = ""
    chatInput.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    chatInput.BackgroundTransparency = 0.3
    chatInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    chatInput.Font = Enum.Font.Gotham
    chatInput.TextSize = 10
    chatInput.BorderSizePixel = 0
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 4)
    inputCorner.Parent = chatInput
    chatInput.Parent = inputFrame

    local sendBtn = Instance.new("TextButton")
    sendBtn.Size = UDim2.new(0.2, 0, 1, 0)
    sendBtn.Text = "SEND"
    sendBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    sendBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    sendBtn.Font = Enum.Font.GothamBold
    sendBtn.TextSize = 10
    sendBtn.BorderSizePixel = 0
    local sendCorner = Instance.new("UICorner")
    sendCorner.CornerRadius = UDim.new(0, 4)
    sendCorner.Parent = sendBtn
    sendBtn.Parent = inputFrame

    sendBtn.MouseButton1Click:Connect(function()
        local msg = chatInput.Text
        if msg == "" then return end
        local newMsg = Instance.new("TextLabel")
        newMsg.Size = UDim2.new(1, 0, 0, 16)
        newMsg.Text = "[user] " .. msg
        newMsg.TextColor3 = Color3.fromRGB(200, 200, 200)
        newMsg.BackgroundTransparency = 1
        newMsg.Font = Enum.Font.Gotham
        newMsg.TextSize = 9
        newMsg.TextXAlignment = Enum.TextXAlignment.Left
        newMsg.Parent = chatLog
        chatInput.Text = ""
        chatLog.CanvasSize = UDim2.new(0, 0, 0, chatListLayout.AbsoluteContentSize.Y)
        task.wait(2)
        newMsg:Destroy()
    end)

    -- Bottom padding
    local bottomPadding = Instance.new("Frame")
    bottomPadding.Size = UDim2.new(1, 0, 0, 5)
    bottomPadding.BackgroundTransparency = 1
    bottomPadding.Parent = settingsContent
end

-- ============================================================================
-- INFO CONTENT (DIPERBAIKI)
-- ============================================================================
local infoContent = nil
local function createInfoContent()
    if infoContent then infoContent:Destroy() end
    infoContent = Instance.new("Frame")
    infoContent.Size = UDim2.new(1, 0, 1, 0)
    infoContent.BackgroundTransparency = 1
    infoContent.Parent = contentPanel

    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -10, 1, -10)
    scrollFrame.Position = UDim2.new(0, 5, 0, 5)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    scrollFrame.BackgroundTransparency = 0.3
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.Parent = infoContent
    local scrollCorner = Instance.new("UICorner")
    scrollCorner.CornerRadius = UDim.new(0, 4)
    scrollCorner.Parent = scrollFrame

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -10, 0, 0)
    textLabel.Text = [[
CYBERHEROES SCRIPT v10.1
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Premium Roblox Executor Script
Fitur lengkap untuk game survival.

Cara Penggunaan:
- Klik tombol fitur untuk mengaktifkan
- Minimize ke floating bar dengan tombol - atau X
- Klik floating bar untuk restore

Dibuat oleh: KemiLinux
Terima kasih telah menggunakan script ini!
]]
    textLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    textLabel.BackgroundTransparency = 1
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextSize = 10
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.TextYAlignment = Enum.TextYAlignment.Top
    textLabel.TextWrapped = true
    textLabel.Parent = scrollFrame

    -- Auto adjust height
    textLabel.Size = UDim2.new(1, -10, 0, textLabel.TextBounds.Y + 20)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, textLabel.TextBounds.Y + 30)
end

-- ============================================================================
-- FLOATING BAR (VERSI DIPERBAIKI - TIDAK DIUBAH)
-- ============================================================================
local floatingBar = nil
local isFloatingVisible = false

local function createFloatingBar()
    if floatingBar and floatingBar.Parent then
        floatingBar.Visible = true
        return floatingBar
    end
    if floatingBar then floatingBar:Destroy() end

    local barGui = Instance.new("ScreenGui")
    barGui.Name = "CyberHeroes_FloatingBar"
    barGui.ResetOnSpawn = false
    barGui.IgnoreGuiInset = true
    barGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    barGui.Parent = CoreGui

    local barFrame = Instance.new("Frame")
    barFrame.Name = "FloatingBar"
    barFrame.Size = UDim2.new(0, 150, 0, 40)
    barFrame.Position = UDim2.new(0.5, -75, 0.05, 0)
    barFrame.BackgroundColor3 = Color3.fromRGB(20, 5, 10)
    barFrame.BackgroundTransparency = 0.2
    barFrame.BorderSizePixel = 0
    barFrame.Parent = barGui

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 8)
    barCorner.Parent = barFrame

    local barStroke = Instance.new("UIStroke")
    barStroke.Color = config.guiThemeColor
    barStroke.Thickness = 1.5
    barStroke.Transparency = 0.4
    barStroke.Parent = barFrame

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(0, 35, 1, 0)
    iconLabel.Position = UDim2.new(0, 5, 0, 0)
    iconLabel.Text = "⚡"
    iconLabel.TextColor3 = config.guiThemeColor
    iconLabel.BackgroundTransparency = 1
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 20
    iconLabel.Parent = barFrame

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -45, 1, 0)
    textLabel.Position = UDim2.new(0, 45, 0, 0)
    textLabel.Text = "KEMILINUX"
    textLabel.TextColor3 = config.guiThemeColor
    textLabel.BackgroundTransparency = 1
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextSize = 12
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Parent = barFrame

    -- Drag logic
    local dragging = false
    local dragStartPos, dragStartOffset
    barFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStartPos = input.Position
            dragStartOffset = barFrame.Position
        end
    end)
    barFrame.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStartPos
            barFrame.Position = UDim2.new(
                dragStartOffset.X.Scale,
                dragStartOffset.X.Offset + delta.X,
                dragStartOffset.Y.Scale,
                dragStartOffset.Y.Offset + delta.Y
            )
        end
    end)
    barFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    local isDrag = false
    barFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDrag = false
        end
    end)
    barFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            isDrag = true
        end
    end)
    barFrame.InputEnded:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not isDrag then
            if mainFrame then
                mainFrame.Visible = true
                config.guiVisible = true
                barGui:Destroy()
                floatingBar = nil
                isFloatingVisible = false
            end
        end
    end)

    -- Hover effects
    barFrame.MouseEnter:Connect(function()
        TweenService:Create(barFrame, TweenInfo.new(0.15), {BackgroundTransparency = 0.05}):Play()
        TweenService:Create(barStroke, TweenInfo.new(0.15), {Transparency = 0.1, Thickness = 2}):Play()
    end)
    barFrame.MouseLeave:Connect(function()
        TweenService:Create(barFrame, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play()
        TweenService:Create(barStroke, TweenInfo.new(0.15), {Transparency = 0.4, Thickness = 1.5}):Play()
    end)

    floatingBar = barGui
    return floatingBar
end

-- ============================================================================
-- PERMANENT TELEPORT BUTTON (tidak diubah)
-- ============================================================================
local function createPermanentTeleportButton()
    if teleportButtonGui then teleportButtonGui:Destroy() end
    teleportButtonGui = Instance.new("ScreenGui")
    teleportButtonGui.Name = "CyberHeroes_TeleportButton"
    teleportButtonGui.ResetOnSpawn = false
    teleportButtonGui.Parent = CoreGui
    teleportButton = Instance.new("TextButton")
    teleportButton.Name = "TeleportButton"
    teleportButton.Size = UDim2.new(0, 45, 0, 45)
    teleportButton.Position = UDim2.new(0.02, 0, 0.85, -30)
    teleportButton.Text = "⚡\nTP"
    teleportButton.TextWrapped = true
    teleportButton.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    teleportButton.BackgroundTransparency = 0.2
    teleportButton.TextColor3 = Color3.fromRGB(0, 230, 255)
    teleportButton.TextSize = 14
    teleportButton.Font = Enum.Font.GothamBold
    teleportButton.BorderSizePixel = 0
    teleportButton.Parent = teleportButtonGui
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(1, 0)
    btnCorner.Parent = teleportButton
    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Color3.fromRGB(0, 200, 255)
    btnStroke.Thickness = 1.5
    btnStroke.Transparency = 0.4
    btnStroke.Parent = teleportButton
    teleportButton.MouseButton1Click:Connect(teleportToNearestSurvivor) -- asumsi fungsi ini ada
    makeDraggable(teleportButton)
end

-- ============================================================================
-- GUI BUTTONS (DIPERBAIKI DENGAN ANIMASI)
-- ============================================================================
local function createGridButton(parent, name, text, initialState, onChange)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(0, 85, 0, 32)
    button.Text = text .. (initialState and " [ON]" or " [OFF]")
    button.BackgroundColor3 = initialState and Color3.fromRGB(40, 5, 5) or Color3.fromRGB(15, 0, 2)
    button.BackgroundTransparency = 0.1
    button.TextColor3 = initialState and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)
    button.TextSize = 9
    button.Font = Enum.Font.GothamBold
    button.BorderSizePixel = 0
    button.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.Color = initialState and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(150, 30, 30)
    stroke.Thickness = 1
    stroke.Transparency = 0.3
    stroke.Parent = button

    -- Hover effect
    local defaultTrans = button.BackgroundTransparency
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.1), {BackgroundTransparency = 0.05}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.1), {Transparency = 0.1, Thickness = 1.2}):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.1), {BackgroundTransparency = defaultTrans}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.1), {Transparency = 0.3, Thickness = 1}):Play()
    end)

    local function updateState(state)
        button.Text = text .. (state and " [ON]" or " [OFF]")
        button.BackgroundColor3 = state and Color3.fromRGB(40, 5, 5) or Color3.fromRGB(15, 0, 2)
        button.TextColor3 = state and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)
        stroke.Color = state and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(150, 30, 30)
    end

    button.MouseButton1Click:Connect(function()
        -- Click animation
        TweenService:Create(button, TweenInfo.new(0.05), {TextSize = 8}):Play()
        task.wait(0.05)
        TweenService:Create(button, TweenInfo.new(0.05), {TextSize = 9}):Play()

        local newState = not (config[name] or false)
        if name == "autoWinEnabled" then
            config.autoWinEnabled = newState
            if newState then startAutoWin() else stopAutoWin() end
        elseif name == "autoTaskEnabled" then
            config.autoTaskEnabled = newState
            if newState then startAutoTask() else stopAutoTask() end
        elseif name == "espEnabled" then
            config.espEnabled = newState
            updateAllESP()
        elseif name == "speedBoostEnabled" then
            config.speedBoostEnabled = newState
            if not newState then if localHumanoid then localHumanoid.WalkSpeed = config.originalWalkSpeed end end
        elseif name == "stealthEnabled" then
            config.stealthEnabled = newState
            if newState then startStealthMonitor() else stopStealthMonitor() end
        elseif name == "godModeEnabled" then
            config.godModeEnabled = newState
            if newState then startGodMode() else stopGodMode() end
        elseif name == "infiniteAmmoEnabled" then
            config.infiniteAmmoEnabled = newState
            if newState then startInfiniteAmmo() else stopInfiniteAmmo() end
        elseif name == "shieldEnabled" then
            config.shieldEnabled = newState
            if newState then startShieldMonitor() else stopShieldMonitor() end
        elseif name == "tpwalkEnabled" then
            config.tpwalkEnabled = newState
            if newState then startTpwalkMonitor() else stopTpwalkMonitor() end
        elseif name == "noCollideEnabled" then
            config.noCollideEnabled = newState
            if newState then startNoCollideMonitor() else stopNoCollideMonitor() end
        elseif name == "massKillEnabled" then
            config.massKillEnabled = newState
            if newState then startMassKillLoop() else stopMassKillLoop() end
        elseif name == "autoGeneratorEnabled" then
            config.autoGeneratorEnabled = newState
            if newState then startAutoGeneratorLoop() else stopAutoGeneratorLoop() end
        elseif name == "autoSkillCheckEnabled" then
            config.autoSkillCheckEnabled = newState
            if newState then startAutoSkillCheck() else stopAutoSkillCheck() end
        elseif name == "autoAimEnabled" then
            config.autoAimEnabled = newState
            if newState then startAutoAim() else stopAutoAim() end
        elseif name == "povMode" then
            togglePOV()
            return
        end
        updateState(newState)
        if onChange then onChange(newState) end
    end)
    return button
end

-- ============================================================================
-- SIDEBAR ITEM (DIPERBAIKI: ICON, HOVER, ACTIVE INDICATOR)
-- ============================================================================
local activeSidebarItem = nil
local function createSidebarItem(parent, text, icon, isActive)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -10, 0, 28)
    button.Text = icon .. "  " .. text
    button.TextColor3 = isActive and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(200, 200, 200)
    button.BackgroundColor3 = isActive and Color3.fromRGB(40, 5, 5) or Color3.fromRGB(15, 0, 2)
    button.BackgroundTransparency = 0.2
    button.TextSize = 11
    button.Font = Enum.Font.GothamBold
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.BorderSizePixel = 0
    button.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button

    -- Hover effect
    button.MouseEnter:Connect(function()
        if activeSidebarItem ~= button then
            TweenService:Create(button, TweenInfo.new(0.1), {BackgroundTransparency = 0.05, TextColor3 = Color3.fromRGB(0, 230, 255)}):Play()
        end
    end)
    button.MouseLeave:Connect(function()
        if activeSidebarItem ~= button then
            TweenService:Create(button, TweenInfo.new(0.1), {BackgroundTransparency = 0.2, TextColor3 = Color3.fromRGB(200, 200, 200)}):Play()
        end
    end)

    -- Set active indicator
    if isActive then
        activeSidebarItem = button
    end
    return button
end

local function setActiveSidebarItem(button)
    if activeSidebarItem == button then return end
    if activeSidebarItem then
        TweenService:Create(activeSidebarItem, TweenInfo.new(0.1), {BackgroundTransparency = 0.2, TextColor3 = Color3.fromRGB(200, 200, 200)}):Play()
    end
    activeSidebarItem = button
    TweenService:Create(button, TweenInfo.new(0.1), {BackgroundTransparency = 0.05, TextColor3 = Color3.fromRGB(0, 230, 255)}):Play()
end

-- ============================================================================
-- MAIN GUI (DIPERBAIKI: SIDEBAR SCROLLING, LAYOUT, TITLE BAR, STATUS BAR)
-- ============================================================================
local function createGUI()
    if screenGui then screenGui:Destroy() end
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CyberHeroes_GUI"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = CoreGui
    screenGui.ResetOnSpawn = false

    -- Main Frame
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainWindow"
    mainFrame.Size = UDim2.new(0, 380, 0, 260)  -- Sedikit lebih lebar untuk sidebar
    mainFrame.Position = UDim2.new(0.5, -190, 0.5, -130)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 5, 10)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 8)
    mainCorner.Parent = mainFrame

    mainStroke = Instance.new("UIStroke")
    mainStroke.Color = config.guiThemeColor
    mainStroke.Thickness = 1.5
    mainStroke.Transparency = 0.4
    mainStroke.Parent = mainFrame

    -- ===== TITLE BAR (DIPERBAIKI) =====
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
    title.Text = "CYBERHEROES script by kemi"
    title.TextColor3 = config.guiThemeColor
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    local versionLabel = Instance.new("TextLabel")
    versionLabel.Size = UDim2.new(0.25, 0, 1, 0)
    versionLabel.Position = UDim2.new(0.6, 0, 0, 0)
    versionLabel.Text = "Build 10.1"
    versionLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
    versionLabel.BackgroundTransparency = 1
    versionLabel.Font = Enum.Font.Gotham
    versionLabel.TextSize = 9
    versionLabel.TextXAlignment = Enum.TextXAlignment.Left
    versionLabel.Parent = titleBar

    -- Tombol minimize & close
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 24, 0, 24)
    minimizeBtn.Position = UDim2.new(1, -52, 0, 2)
    minimizeBtn.Text = "−"
    minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    minimizeBtn.BackgroundTransparency = 0.2
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextSize = 18
    minimizeBtn.Parent = titleBar
    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 4)
    minCorner.Parent = minimizeBtn

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 24, 0, 24)
    closeBtn.Position = UDim2.new(1, -26, 0, 2)
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

    -- Minimize function
    local function minimizeGUI()
        config.guiVisible = false
        if mainFrame then mainFrame.Visible = false end
        if floatingBar then pcall(function() floatingBar:Destroy() end) end
        createFloatingBar()
        isFloatingVisible = true
    end
    minimizeBtn.MouseButton1Click:Connect(minimizeGUI)
    closeBtn.MouseButton1Click:Connect(minimizeGUI)

    -- ===== SIDEBAR DENGAN SCROLLING (DIPERBAIKI) =====
    sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 100, 1, -28)
    sidebar.Position = UDim2.new(0, 0, 0, 28)
    sidebar.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    sidebar.BackgroundTransparency = 0.2
    sidebar.BorderSizePixel = 0
    sidebar.Parent = mainFrame

    local sidebarCorner = Instance.new("UICorner")
    sidebarCorner.CornerRadius = UDim.new(0, 0)
    sidebarCorner.Parent = sidebar

    -- ScrollingFrame untuk sidebar
    sidebarScroll = Instance.new("ScrollingFrame")
    sidebarScroll.Size = UDim2.new(1, 0, 1, 0)
    sidebarScroll.BackgroundTransparency = 1
    sidebarScroll.BorderSizePixel = 0
    sidebarScroll.ScrollBarThickness = 4
    sidebarScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sidebarScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    sidebarScroll.Parent = sidebar

    local sidebarList = Instance.new("Frame")
    sidebarList.Size = UDim2.new(1, 0, 0, 0)
    sidebarList.BackgroundTransparency = 1
    sidebarList.AutomaticSize = Enum.AutomaticSize.Y
    sidebarList.Parent = sidebarScroll

    local sidebarLayout = Instance.new("UIListLayout")
    sidebarLayout.Padding = UDim.new(0, 6)
    sidebarLayout.FillDirection = Enum.FillDirection.Vertical
    sidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    sidebarLayout.Parent = sidebarList

    local sidebarPadding = Instance.new("UIPadding")
    sidebarPadding.PaddingTop = UDim.new(0, 8)
    sidebarPadding.PaddingBottom = UDim.new(0, 8)
    sidebarPadding.Parent = sidebarList

    -- Buat item sidebar dengan ikon
    local homeItem = createSidebarItem(sidebarList, "HOME", "🏠", true)
    local featuresItem = createSidebarItem(sidebarList, "FEATURES", "⚡", false)
    local settingsItem = createSidebarItem(sidebarList, "SETTINGS", "⚙️", false)
    local infoItem = createSidebarItem(sidebarList, "INFO", "ℹ️", false)
    local aboutItem = createSidebarItem(sidebarList, "ABOUT", "📄", false)

    -- Divider
    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(0.8, 0, 0, 1)
    divider.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    divider.BackgroundTransparency = 0.7
    divider.Parent = sidebarList

    -- Spacer bottom
    local spacer = Instance.new("Frame")
    spacer.Size = UDim2.new(1, 0, 0, 4)
    spacer.BackgroundTransparency = 1
    spacer.Parent = sidebarList

    -- ===== CONTENT PANEL (DIPERBAIKI) =====
    contentPanel = Instance.new("Frame")
    contentPanel.Size = UDim2.new(1, -110, 1, -34)
    contentPanel.Position = UDim2.new(0, 105, 0, 32)
    contentPanel.BackgroundTransparency = 1
    contentPanel.Parent = mainFrame

    local contentPadding = Instance.new("UIPadding")
    contentPadding.PaddingLeft = UDim.new(0, 5)
    contentPadding.PaddingRight = UDim.new(0, 5)
    contentPadding.PaddingTop = UDim.new(0, 5)
    contentPadding.PaddingBottom = UDim.new(0, 5)
    contentPadding.Parent = contentPanel

    -- Grid untuk tombol fitur
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 88, 0, 34)
    gridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
    gridLayout.FillDirection = Enum.FillDirection.Horizontal
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = contentPanel

    -- Daftar fitur
    local features = {
        {name="autoWinEnabled", text="AUTO WIN"},
        {name="autoTaskEnabled", text="AUTO TASK"},
        {name="espEnabled", text="ESP"},
        {name="speedBoostEnabled", text="SPEED BOOST"},
        {name="stealthEnabled", text="STEALTH"},
        {name="godModeEnabled", text="GOD MODE"},
        {name="infiniteAmmoEnabled", text="Dagger"},
        {name="shieldEnabled", text="SHIELD"},
        {name="tpwalkEnabled", text="TPWALK"},
        {name="noCollideEnabled", text="NO COLLIDE"},
        {name="massKillEnabled", text="MASS KILL"},
        {name="autoGeneratorEnabled", text="AUTO GEN"},
        {name="autoSkillCheckEnabled", text="SKILL CHECK"},
        {name="autoAimEnabled", text="AUTO AIM"},
        {name="povMode", text="POV"}
    }
    for _, feat in ipairs(features) do
        local initialState = config[feat.name] or false
        createGridButton(contentPanel, feat.name, feat.text, initialState)
    end

    -- ===== NAVIGATION HANDLERS (dengan perubahan konten) =====
    local function switchToHome()
        setActiveSidebarItem(homeItem)
        if settingsContent then settingsContent:Destroy() end
        if infoContent then infoContent:Destroy() end
        gridLayout.Parent = contentPanel
    end
    local function switchToFeatures()
        setActiveSidebarItem(featuresItem)
        if settingsContent then settingsContent:Destroy() end
        if infoContent then infoContent:Destroy() end
        gridLayout.Parent = contentPanel
    end
    local function switchToSettings()
        setActiveSidebarItem(settingsItem)
        gridLayout.Parent = nil
        if infoContent then infoContent:Destroy() end
        createSettingsContent()
    end
    local function switchToInfo()
        setActiveSidebarItem(infoItem)
        gridLayout.Parent = nil
        if settingsContent then settingsContent:Destroy() end
        createInfoContent()
    end
    local function switchToAbout()
        setActiveSidebarItem(aboutItem)
        if settingsContent then settingsContent:Destroy() end
        if infoContent then infoContent:Destroy() end
        gridLayout.Parent = contentPanel
        -- About bisa menampilkan teks lain jika perlu, untuk sini kita tampilkan grid lagi
    end

    homeItem.MouseButton1Click:Connect(switchToHome)
    featuresItem.MouseButton1Click:Connect(switchToFeatures)
    settingsItem.MouseButton1Click:Connect(switchToSettings)
    infoItem.MouseButton1Click:Connect(switchToInfo)
    aboutItem.MouseButton1Click:Connect(switchToAbout)

    -- ===== STATUS BAR (DIPERBAIKI) =====
    local statusBar = Instance.new("Frame")
    statusBar.Size = UDim2.new(1, 0, 0, 20)
    statusBar.Position = UDim2.new(0, 0, 1, -20)
    statusBar.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    statusBar.BackgroundTransparency = 0.2
    statusBar.BorderSizePixel = 0
    statusBar.Parent = mainFrame

    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 4)
    statusCorner.Parent = statusBar

    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -15, 1, 0)
    statusLabel.Position = UDim2.new(0, 5, 0, 0)
    statusLabel.Text = "SYSTEM READY"
    statusLabel.TextColor3 = config.guiThemeColor
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 8
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = statusBar

    local led = Instance.new("Frame")
    led.Size = UDim2.new(0, 6, 0, 6)
    led.Position = UDim2.new(1, -12, 0.5, -3)
    led.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    led.BackgroundTransparency = 0.2
    led.BorderSizePixel = 0
    led.Parent = statusBar
    local ledCorner = Instance.new("UICorner")
    ledCorner.CornerRadius = UDim.new(1, 0)
    ledCorner.Parent = led

    -- Animasi masuk
    mainFrame.BackgroundTransparency = 0.3
    TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.1}):Play()

    -- Loop status aktif
    task.spawn(function()
        while screenGui and screenGui.Parent do
            local activeCount = (config.autoWinEnabled and 1 or 0) + (config.autoTaskEnabled and 1 or 0) +
                                (config.espEnabled and 1 or 0) + (config.speedBoostEnabled and 1 or 0) +
                                (config.stealthEnabled and 1 or 0) + (config.godModeEnabled and 1 or 0) +
                                (config.infiniteAmmoEnabled and 1 or 0) + (config.shieldEnabled and 1 or 0) +
                                (config.tpwalkEnabled and 1 or 0) + (config.noCollideEnabled and 1 or 0) +
                                (config.massKillEnabled and 1 or 0) + (config.autoGeneratorEnabled and 1 or 0) +
                                (config.autoSkillCheckEnabled and 1 or 0) + (config.autoAimEnabled and 1 or 0)
            if activeCount > 0 then
                statusLabel.Text = "ACTIVE: " .. activeCount .. " modules"
                statusLabel.TextColor3 = config.guiThemeColor
                led.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            else
                statusLabel.Text = "STANDBY"
                statusLabel.TextColor3 = Color3.fromRGB(150, 50, 50)
                led.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            end
            task.wait(1)
        end
    end)

    makeDraggable(mainFrame)
end

-- ============================================================================
-- INISIALISASI
-- ============================================================================
createGUI()
createPermanentTeleportButton() -- jika fungsi teleportToNearestSurvivor tersedia
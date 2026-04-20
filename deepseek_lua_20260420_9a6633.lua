--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║           CYBERHEROES FORCE KILLER ROLE v1.0                     ║
    ║           Force your role to be KILLER in Violence District      ║
    ║                   Developed for Delta Executor                   ║
    ║                                                                  ║
    ║   How it works:                                                  ║
    ║   - Automatically forces the game to assign you as Killer       ║
    ║   - Works by intercepting role assignment RemoteEvents          ║
    ║   - Toggle ON/OFF via GUI                                        ║
    ║                                                                  ║
    ║   ⚠️ DISCLAIMER: Use at your own risk! This may be detectable    ║
    ║   by anti-cheat systems. Use on alt accounts only.              ║
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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local localPlayer = Players.LocalPlayer
local localCharacter = nil
local localHumanoid = nil

-- ============================================================================
-- CONFIGURATION (PERSISTENT)
-- ============================================================================
local _G = getgenv() or _G
if not _G.CyberHeroesForceKiller then
    _G.CyberHeroesForceKiller = {
        enabled = false,
        guiVisible = true
    }
end
local state = _G.CyberHeroesForceKiller

-- ============================================================================
-- VARIABLES
-- ============================================================================
local forceKillerConnection = nil
local screenGui = nil
local mainFrame = nil
local toggleButton = nil
local statusLabel = nil
local targetRemoteEvent = nil

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================
local function getLocalCharacter()
    localCharacter = localPlayer.Character
    if localCharacter then
        localHumanoid = localCharacter:FindFirstChildWhichIsA("Humanoid")
    end
    return localCharacter
end

-- ============================================================================
-- REMOTE EVENT SCANNER
-- ============================================================================
local function findRoleAssignmentRemote()
    -- Scan ReplicatedStorage for RemoteEvents with killer/role related names
    local possibleRemotes = {}
    local keywords = {"role", "assign", "team", "killer", "survivor", "setteam", "changeteam", "setrole", "forcerole"}
    
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local name = obj.Name:lower()
            for _, kw in ipairs(keywords) do
                if name:find(kw) then
                    table.insert(possibleRemotes, obj)
                    break
                end
            end
        end
    end
    
    -- Also check game.ReplicatedFirst and game.Players
    local containers = {game.ReplicatedFirst, game.Players}
    for _, container in ipairs(containers) do
        for _, obj in ipairs(container:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                local name = obj.Name:lower()
                for _, kw in ipairs(keywords) do
                    if name:find(kw) then
                        table.insert(possibleRemotes, obj)
                        break
                    end
                end
            end
        end
    end
    
    return possibleRemotes
end

-- ============================================================================
-- CORE FORCE KILLER FUNCTION
-- ============================================================================
local function forceKillerRole()
    if not state.enabled then return end
    
    -- Method 1: Try to fire all possible remote events related to role assignment
    local remotes = findRoleAssignmentRemote()
    for _, remote in ipairs(remotes) do
        pcall(function()
            if remote:IsA("RemoteEvent") then
                remote:FireServer("Killer")
                remote:FireServer("killer")
                remote:FireServer("setTeam", "Killer")
                remote:FireServer("setRole", "Killer")
                remote:FireServer("forceKiller")
                remote:FireServer(localPlayer, "Killer")
            elseif remote:IsA("RemoteFunction") then
                remote:InvokeServer("Killer")
                remote:InvokeServer("killer")
                remote:InvokeServer("setTeam", "Killer")
            end
        end)
    end
    
    -- Method 2: Try to modify Team property directly (if accessible)
    pcall(function()
        if localPlayer.Team then
            -- If team is a Team object, try to change it
            local killerTeam = nil
            for _, team in ipairs(game:GetService("Teams"):GetChildren()) do
                if team.Name:lower():find("killer") or team.Name:lower():find("monster") or team.Name:lower():find("enemy") then
                    killerTeam = team
                    break
                end
            end
            if killerTeam then
                localPlayer.Team = killerTeam
            end
        end
    end)
    
    -- Method 3: Try to find a "SetTeam" remote event specifically
    local setTeamRemote = ReplicatedStorage:FindFirstChild("SetTeam") or 
                          ReplicatedStorage:FindFirstChild("ChangeTeam") or
                          ReplicatedStorage:FindFirstChild("AssignTeam")
    if setTeamRemote and setTeamRemote:IsA("RemoteEvent") then
        pcall(function()
            setTeamRemote:FireServer("Killer")
            setTeamRemote:FireServer(localPlayer, "Killer")
        end)
    end
end

-- ============================================================================
-- MONITOR LOOP
-- ============================================================================
local function startForceKillerLoop()
    if forceKillerConnection then return end
    forceKillerConnection = RunService.Heartbeat:Connect(function()
        if not state.enabled then return end
        if not getLocalCharacter() then return end
        
        -- Check if player is already killer (based on team)
        local isAlreadyKiller = false
        if localPlayer.Team then
            local teamName = localPlayer.Team.Name:lower()
            if teamName:find("killer") or teamName:find("monster") or teamName:find("enemy") then
                isAlreadyKiller = true
            end
        end
        
        -- If not killer, try to force the role
        if not isAlreadyKiller then
            forceKillerRole()
            -- Log every few seconds to avoid spam
            if math.random(1, 30) == 1 then
                print("[ForceKiller] Attempting to force Killer role...")
            end
        end
    end)
end

local function stopForceKillerLoop()
    if forceKillerConnection then
        forceKillerConnection:Disconnect()
        forceKillerConnection = nil
    end
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
    screenGui.Name = "CyberHeroes_ForceKiller"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = CoreGui

    -- Main frame (small, draggable)
    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 200, 0, 100)
    mainFrame.Position = UDim2.new(0.5, -100, 0.8, -50)
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
    title.Text = "FORCE KILLER ROLE"
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
    toggleButton.Position = UDim2.new(0.1, 0, 0.1, 0)
    toggleButton.Text = state.enabled and "FORCE KILLER [ON]" or "FORCE KILLER [OFF]"
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
            toggleButton.Text = "FORCE KILLER [ON]"
            toggleButton.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
            toggleButton.TextColor3 = Color3.fromRGB(0, 230, 255)
            btnStroke.Color = Color3.fromRGB(0, 200, 255)
            startForceKillerLoop()
        else
            toggleButton.Text = "FORCE KILLER [OFF]"
            toggleButton.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
            toggleButton.TextColor3 = Color3.fromRGB(200, 200, 200)
            btnStroke.Color = Color3.fromRGB(150, 30, 30)
            stopForceKillerLoop()
        end
    end)

    -- Status indicator
    local statusFrame = Instance.new("Frame")
    statusFrame.Size = UDim2.new(0.8, 0, 0, 16)
    statusFrame.Position = UDim2.new(0.1, 0, 0.6, 0)
    statusFrame.BackgroundColor3 = Color3.fromRGB(15, 0, 2)
    statusFrame.BackgroundTransparency = 0.2
    statusFrame.BorderSizePixel = 0
    statusFrame.Parent = content
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 4)
    statusCorner.Parent = statusFrame

    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 1, 0)
    statusLabel.Text = state.enabled and "ACTIVE" or "INACTIVE"
    statusLabel.TextColor3 = state.enabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 9
    statusLabel.Parent = statusFrame

    -- Update status setiap detik
    task.spawn(function()
        while screenGui and screenGui.Parent do
            if state.enabled then
                statusLabel.Text = "ACTIVE"
                statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            else
                statusLabel.Text = "INACTIVE"
                statusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            end
            task.wait(1)
        end
    end)

    makeDraggable(mainFrame)

    -- Fade in
    mainFrame.BackgroundTransparency = 0.3
    TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.15}):Play()
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
local function init()
    print("╔═══════════════════════════════════════════════════════════════════╗")
    print("║           CYBERHEROES FORCE KILLER ROLE v1.0                     ║")
    print("║                   System initialized!                            ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")
    createGUI()
    if state.enabled then
        startForceKillerLoop()
    end
end

task.wait(1)
init()
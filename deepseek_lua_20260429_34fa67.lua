--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                                                                   ║
    ║              ⚡ KEMI_GABUT ULTIMATE HUB (FIXED) ⚡                 ║
    ║                   Developed by: kemi                              ║
    ║                     Version: 1.1.0                                ║
    ║                                                                   ║
    ║                     DELTA EXECUTOR READY                          ║
    ║                                                                   ║
    ╚═══════════════════════════════════════════════════════════════════╝
    
    🔧 FEATURES:
    • ESP (Player Box, Tracer, Name, Distance)
    • Noclip (Walk Through Walls)
    • TPWalk (Adjustable WalkSpeed via Slider)
    • Invisible (Make Yourself Invisible)
    • God Mode (Invincibility)
    • Auto Aim (Camera Lock on Nearest Player)
    • Customizable GUI with Draggable Frame

    🎮 CONTROLS:
    • Toggle UI: F
    • Everything else is configurable via the GUI

    💻 Made with ❤️ by kemi (Fixed Version)
--]]

--[[
    KEMI_GABUT Ultimate Hub - Fixed
───────────────────────────────────────────────────────────────────────────────
]]

-- Detect the executor type and set up the environment
pcall(function()
    local syn_supported, syn = pcall(function()
        return (syn and syn.crypt) or (synapse and synapse) or (getfenv and getfenv())
    end)
end)

--[[
    SERVICES
───────────────────────────────────────────────────────────────────────────────
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

--[[
    PLAYER REFERENCES
───────────────────────────────────────────────────────────────────────────────
]]
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = Workspace.CurrentCamera

-- Dynamic references (will be updated when character spawns)
local Character = nil
local Humanoid = nil
local HumanoidRootPart = nil

--[[
    CONFIGURATION
───────────────────────────────────────────────────────────────────────────────
]]
local Settings = {
    ESP = {
        Enabled = true,
        BoxColor = Color3.fromRGB(0, 255, 255),
        TracerColor = Color3.fromRGB(255, 0, 255),
        NameColor = Color3.fromRGB(255, 255, 255),
        DistanceColor = Color3.fromRGB(200, 200, 200),
        BoxThickness = 1,
        TracerThickness = 1,
        ShowName = true,
        ShowDistance = true,
        MaxDistance = 500,
    },
    Movement = {
        Noclip = false,
        WalkSpeed = 16,
        CustomWalkSpeed = false,
    },
    Combat = {
        Invisible = false,
        GodMode = false,
        AutoAim = false,
        AutoAimRadius = 200,
        AutoAimPart = "HumanoidRootPart",
        AutoAimDuration = 0.1,
    },
    UI = {
        Visible = true,
        Draggable = true,
    },
}

--[[
    STATE VARIABLES
───────────────────────────────────────────────────────────────────────────────
]]
local ESPObjects = {}
local AutoAimCooldown = false
local GodModeConnection = nil
local healthMonitorConnection = nil

--[[
    DRAWING API (Safe Check)
───────────────────────────────────────────────────────────────────────────────
]]
local Drawing = _G.Drawing or (getgenv and getgenv().Drawing) or nil
local HAS_DRAWING = (Drawing and Drawing.new and type(Drawing.new) == "function")

if not HAS_DRAWING then
    print("[KemiGabut] Warning: Drawing API not found. ESP features will be disabled.")
    -- Fallback: disable ESP
    Settings.ESP.Enabled = false
    -- Create dummy Drawing table to avoid errors
    Drawing = {
        new = function() 
            return setmetatable({}, {__index = function() return nil end})
        end
    }
end

--[[
    UTILITY FUNCTIONS
───────────────────────────────────────────────────────────────────────────────
]]
local function GetCharacter(Player)
    return Player and Player.Character
end

local function GetHumanoid(Player)
    local Char = GetCharacter(Player)
    return Char and Char:FindFirstChildOfClass("Humanoid")
end

local function IsAlive(Player)
    local Hum = GetHumanoid(Player)
    return Hum and Hum.Health > 0
end

local function GetScreenPosition(WorldPosition)
    if not WorldPosition then return nil end
    local Vector, OnScreen = Camera:WorldToViewportPoint(WorldPosition)
    if OnScreen then
        return Vector2.new(Vector.X, Vector.Y)
    end
    return nil
end

local function GetLocalRoot()
    if not Character then return nil end
    return Character:FindFirstChild("HumanoidRootPart") or Character:FindFirstChild("Torso") or Character:FindFirstChild("UpperTorso")
end

-- Update local references
local function UpdateLocalReferences()
    Character = LocalPlayer.Character
    if Character then
        Humanoid = Character:FindFirstChildOfClass("Humanoid")
        HumanoidRootPart = GetLocalRoot()
    else
        Humanoid = nil
        HumanoidRootPart = nil
    end
end

--[[
    ESP IMPLEMENTATION (Safe with Drawing API)
───────────────────────────────────────────────────────────────────────────────
]]
local function CreateESPForPlayer(Player)
    if not Settings.ESP.Enabled then return end
    if Player == LocalPlayer then return end
    if ESPObjects[Player] then return end
    
    local Char = GetCharacter(Player)
    if not Char then return end
    
    -- Safe creation with pcall
    local success, Box = pcall(Drawing.new, "Square")
    if not success then Box = {Visible = false} end
    local success2, Tracer = pcall(Drawing.new, "Line")
    if not success2 then Tracer = {Visible = false} end
    local success3, NameText = pcall(Drawing.new, "Text")
    if not success3 then NameText = {Visible = false} end
    local success4, DistanceText = pcall(Drawing.new, "Text")
    if not success4 then DistanceText = {Visible = false} end
    
    if Box then
        Box.Visible = false
        Box.Thickness = Settings.ESP.BoxThickness
        Box.Color = Settings.ESP.BoxColor
        Box.Filled = false
    end
    if Tracer then
        Tracer.Visible = false
        Tracer.Thickness = Settings.ESP.TracerThickness
        Tracer.Color = Settings.ESP.TracerColor
        Tracer.Transparency = 0.5
    end
    if NameText then
        NameText.Visible = false
        NameText.Color = Settings.ESP.NameColor
        NameText.Center = true
        NameText.Size = 12
        NameText.Font = (Drawing.Fonts and Drawing.Fonts.UI) or 0
    end
    if DistanceText then
        DistanceText.Visible = false
        DistanceText.Color = Settings.ESP.DistanceColor
        DistanceText.Center = true
        DistanceText.Size = 10
        DistanceText.Font = (Drawing.Fonts and Drawing.Fonts.UI) or 0
    end
    
    ESPObjects[Player] = {
        Box = Box,
        Tracer = Tracer,
        Name = NameText,
        Distance = DistanceText,
    }
end

local function UpdateESP()
    if not Settings.ESP.Enabled then
        for _, Data in pairs(ESPObjects) do
            if Data.Box then Data.Box.Visible = false end
            if Data.Tracer then Data.Tracer.Visible = false end
            if Data.Name then Data.Name.Visible = false end
            if Data.Distance then Data.Distance.Visible = false end
        end
        return
    end
    
    UpdateLocalReferences()
    if not HumanoidRootPart then return end
    
    for Player, Data in pairs(ESPObjects) do
        if not IsAlive(Player) then
            if Data.Box then Data.Box.Visible = false end
            if Data.Tracer then Data.Tracer.Visible = false end
            if Data.Name then Data.Name.Visible = false end
            if Data.Distance then Data.Distance.Visible = false end
            goto Continue
        end
        
        local Char = GetCharacter(Player)
        if not Char then goto Continue end
        
        local RootPart = Char:FindFirstChild("HumanoidRootPart")
        if not RootPart then goto Continue end
        
        local ScreenPos = GetScreenPosition(RootPart.Position)
        if not ScreenPos then
            if Data.Box then Data.Box.Visible = false end
            if Data.Tracer then Data.Tracer.Visible = false end
            if Data.Name then Data.Name.Visible = false end
            if Data.Distance then Data.Distance.Visible = false end
            goto Continue
        end
        
        local Distance = (HumanoidRootPart.Position - RootPart.Position).Magnitude
        if Distance > Settings.ESP.MaxDistance then
            if Data.Box then Data.Box.Visible = false end
            if Data.Tracer then Data.Tracer.Visible = false end
            if Data.Name then Data.Name.Visible = false end
            if Data.Distance then Data.Distance.Visible = false end
            goto Continue
        end
        
        -- Box size calculation
        local BoxSize = 100 / math.max(1, Distance) * 3
        local BoxPos = Vector2.new(ScreenPos.X - BoxSize / 2, ScreenPos.Y - BoxSize / 1.5)
        
        if Data.Box then
            Data.Box.Size = Vector2.new(BoxSize, BoxSize * 1.5)
            Data.Box.Position = BoxPos
            Data.Box.Visible = true
        end
        
        -- Tracer (line from center of screen)
        local ScreenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        if Data.Tracer then
            Data.Tracer.From = ScreenCenter
            Data.Tracer.To = ScreenPos
            Data.Tracer.Visible = true
        end
        
        -- Name
        if Settings.ESP.ShowName and Data.Name then
            Data.Name.Text = Player.Name
            Data.Name.Position = Vector2.new(ScreenPos.X, BoxPos.Y - 15)
            Data.Name.Visible = true
        elseif Data.Name then
            Data.Name.Visible = false
        end
        
        -- Distance
        if Settings.ESP.ShowDistance and Data.Distance then
            Data.Distance.Text = string.format("%.1fm", Distance / 3)
            Data.Distance.Position = Vector2.new(ScreenPos.X, BoxPos.Y + BoxSize * 1.5 + 5)
            Data.Distance.Visible = true
        elseif Data.Distance then
            Data.Distance.Visible = false
        end
        
        ::Continue::
    end
end

local function CleanupESP()
    for _, Data in pairs(ESPObjects) do
        if Data.Box then pcall(Data.Box.Remove, Data.Box) end
        if Data.Tracer then pcall(Data.Tracer.Remove, Data.Tracer) end
        if Data.Name then pcall(Data.Name.Remove, Data.Name) end
        if Data.Distance then pcall(Data.Distance.Remove, Data.Distance) end
    end
    ESPObjects = {}
end

--[[
    AUTO AIM IMPLEMENTATION
───────────────────────────────────────────────────────────────────────────────
]]
local function IsTargetValid(TargetPlayer)
    if TargetPlayer == LocalPlayer then return false end
    if not IsAlive(TargetPlayer) then return false end
    local Char = GetCharacter(TargetPlayer)
    if not Char then return false end
    if not HumanoidRootPart then return false end
    local Distance = (HumanoidRootPart.Position - Char:GetPivot().Position).Magnitude
    return Distance <= Settings.Combat.AutoAimRadius
end

local function GetNearestPlayer()
    local Nearest = nil
    local MinDistance = math.huge
    for _, Player in ipairs(Players:GetPlayers()) do
        if IsTargetValid(Player) then
            local Char = GetCharacter(Player)
            if Char then
                local Dist = (HumanoidRootPart.Position - Char:GetPivot().Position).Magnitude
                if Dist < MinDistance then
                    MinDistance = Dist
                    Nearest = Player
                end
            end
        end
    end
    return Nearest
end

local function LockCameraToPlayer(TargetPlayer)
    if not IsTargetValid(TargetPlayer) then return false end
    local Char = GetCharacter(TargetPlayer)
    if not Char then return false
    local TargetPart = Char:FindFirstChild(Settings.Combat.AutoAimPart)
    if not TargetPart then
        TargetPart = Char:FindFirstChild("HumanoidRootPart")
    end
    if not TargetPart then return false end
    
    local LockDuration = Settings.Combat.AutoAimDuration
    local StartTime = tick()
    local Connection
    Connection = RunService.RenderStepped:Connect(function()
        local Elapsed = tick() - StartTime
        if Elapsed >= LockDuration or not IsTargetValid(TargetPlayer) then
            Connection:Disconnect()
            return
        end
        -- Smoothly adjust camera to target
        local CameraCF = CFrame.new(Camera.CFrame.Position, TargetPart.Position)
        Camera.CFrame = Camera.CFrame:Lerp(CameraCF, 0.3)
    end)
    return true
end

local function ProcessAutoAim()
    if not Settings.Combat.AutoAim then return end
    UpdateLocalReferences()
    if not Character or not Humanoid or not HumanoidRootPart then return end
    if AutoAimCooldown then return end
    
    local Nearest = GetNearestPlayer()
    if not Nearest then return end
    
    local Char = GetCharacter(Nearest)
    if not Char then return end
    
    local TargetPart = Char:FindFirstChild(Settings.Combat.AutoAimPart)
    if not TargetPart then return end
    
    -- Convert target position to screen coordinates
    local ScreenPos, OnScreen = Camera:WorldToViewportPoint(TargetPart.Position)
    if not OnScreen then return end
    local ScreenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local DistanceFromCenter = math.abs(ScreenPos.X - ScreenCenter.X)
    
    if DistanceFromCenter < 50 then
        AutoAimCooldown = true
        LockCameraToPlayer(Nearest)
        task.spawn(function()
            task.wait(Settings.Combat.AutoAimDuration + 0.1)
            AutoAimCooldown = false
        end)
    end
end

--[[
    MOVEMENT FEATURES
───────────────────────────────────────────────────────────────────────────────
]]
local function UpdateNoclip()
    UpdateLocalReferences()
    if not Character then return end
    
    if Settings.Movement.Noclip then
        for _, Part in ipairs(Character:GetDescendants()) do
            if Part:IsA("BasePart") then
                Part.CanCollide = false
            end
        end
    else
        for _, Part in ipairs(Character:GetDescendants()) do
            if Part:IsA("BasePart") and Part.Name ~= "HumanoidRootPart" then
                Part.CanCollide = true
            end
        end
        if HumanoidRootPart then
            HumanoidRootPart.CanCollide = true
        end
    end
end

local function UpdateWalkSpeed()
    UpdateLocalReferences()
    if not Humanoid then return end
    
    if Settings.Movement.CustomWalkSpeed then
        if Humanoid.WalkSpeed ~= Settings.Movement.WalkSpeed then
            Humanoid.WalkSpeed = Settings.Movement.WalkSpeed
        end
    else
        if Humanoid.WalkSpeed ~= 16 then
            Humanoid.WalkSpeed = 16
        end
    end
end

--[[
    GOD MODE & INVISIBLE
───────────────────────────────────────────────────────────────────────────────
]]
local function UpdateGodMode()
    UpdateLocalReferences()
    if not Character then return end
    
    if Settings.Combat.GodMode then
        if not GodModeConnection and Humanoid then
            GodModeConnection = Humanoid:GetPropertyChangedSignal("Health"):Connect(function()
                if Humanoid.Health <= 0 then
                    Humanoid.Health = Humanoid.MaxHealth
                elseif Humanoid.Health < Humanoid.MaxHealth then
                    Humanoid.Health = Humanoid.MaxHealth
                end
            end)
        end
    else
        if GodModeConnection then
            GodModeConnection:Disconnect()
            GodModeConnection = nil
        end
    end
end

local function UpdateInvisible()
    UpdateLocalReferences()
    if not Character then return end
    
    if Settings.Combat.Invisible then
        for _, Part in ipairs(Character:GetDescendants()) do
            if Part:IsA("BasePart") then
                Part.Transparency = 1
            end
        end
        if Humanoid then
            Humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
        end
    else
        for _, Part in ipairs(Character:GetDescendants()) do
            if Part:IsA("BasePart") then
                Part.Transparency = 0
            end
        end
        if Humanoid then
            Humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
        end
    end
end

--[[
    CROSSHAIR CREATION
───────────────────────────────────────────────────────────────────────────────
]]
local function CreateCrosshair()
    local success, ScreenGui = pcall(function()
        local gui = Instance.new("ScreenGui")
        gui.Name = "KemiGabut_Crosshair"
        gui.Parent = LocalPlayer:FindFirstChild("PlayerGui") or CoreGui
        gui.ResetOnSpawn = false
        return gui
    end)
    if not success then return end
    
    local CrosshairContainer = Instance.new("Frame")
    CrosshairContainer.Size = UDim2.new(0, 30, 0, 30)
    CrosshairContainer.Position = UDim2.new(0.5, -15, 0.5, -15)
    CrosshairContainer.BackgroundTransparency = 1
    CrosshairContainer.Parent = ScreenGui
    
    local Circle = Instance.new("Frame")
    Circle.Size = UDim2.new(0, 20, 0, 20)
    Circle.Position = UDim2.new(0.5, -10, 0.5, -10)
    Circle.BackgroundTransparency = 1
    Circle.BorderSizePixel = 3
    Circle.BorderColor3 = Color3.fromRGB(0, 255, 255)
    Circle.Parent = CrosshairContainer
    local CircleCorner = Instance.new("UICorner")
    CircleCorner.CornerRadius = UDim.new(1, 0)
    CircleCorner.Parent = Circle
    
    local Dot = Instance.new("Frame")
    Dot.Size = UDim2.new(0, 3, 0, 3)
    Dot.Position = UDim2.new(0.5, -1.5, 0.5, -1.5)
    Dot.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    Dot.BorderSizePixel = 0
    Dot.Parent = CrosshairContainer
    local DotCorner = Instance.new("UICorner")
    DotCorner.CornerRadius = UDim.new(1, 0)
    DotCorner.Parent = Dot
    
    local Line1 = Instance.new("Frame")
    Line1.Size = UDim2.new(0, 10, 0, 2)
    Line1.Position = UDim2.new(0.5, -5, 0.5, -1)
    Line1.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
    Line1.BorderSizePixel = 0
    Line1.Parent = CrosshairContainer
    
    local Line2 = Instance.new("Frame")
    Line2.Size = UDim2.new(0, 2, 0, 10)
    Line2.Position = UDim2.new(0.5, -1, 0.5, -5)
    Line2.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
    Line2.BorderSizePixel = 0
    Line2.Parent = CrosshairContainer
end

--[[
    CREATE GUI (MAIN MENU)
───────────────────────────────────────────────────────────────────────────────
]]
local function MakeDraggable(Frame)
    local Dragging = false
    local DragStart = nil
    local StartPos = nil
    
    Frame.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            Dragging = true
            DragStart = Input.Position
            StartPos = Frame.Position
        end
    end)
    
    Frame.InputEnded:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            Dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(Input)
        if Dragging and Input.UserInputType == Enum.UserInputType.MouseMovement then
            local Delta = Input.Position - DragStart
            Frame.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + Delta.X, StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y)
        end
    end)
end

local function CreateGUI()
    local success, ScreenGui = pcall(function()
        local gui = Instance.new("ScreenGui")
        gui.Name = "KemiGabut_Hub"
        gui.Parent = LocalPlayer:FindFirstChild("PlayerGui") or CoreGui
        gui.ResetOnSpawn = false
        return gui
    end)
    if not success then return end
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 350, 0, 450)
    MainFrame.Position = UDim2.new(0.5, -175, 0.5, -225)
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    MainFrame.BackgroundTransparency = 0.15
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 12)
    MainCorner.Parent = MainFrame
    
    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(100, 70, 200)
    MainStroke.Thickness = 2
    MainStroke.Transparency = 0.6
    MainStroke.Parent = MainFrame
    
    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 40)
    TitleBar.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
    TitleBar.BackgroundTransparency = 0.2
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 12)
    TitleCorner.Parent = TitleBar
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 1, 0)
    Title.Text = "⚡ KEMI_GABUT ULTIMATE HUB ⚡"
    Title.TextColor3 = Color3.fromRGB(180, 130, 255)
    Title.BackgroundTransparency = 1
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 16
    Title.Parent = TitleBar
    
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 30, 0, 30)
    CloseBtn.Position = UDim2.new(1, -35, 0, 5)
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    CloseBtn.BackgroundTransparency = 1
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 18
    CloseBtn.Parent = TitleBar
    CloseBtn.MouseButton1Click:Connect(function()
        ScreenGui.Visible = not ScreenGui.Visible
    end)
    
    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -20, 1, -55)
    Content.Position = UDim2.new(0, 10, 0, 50)
    Content.BackgroundTransparency = 1
    Content.Parent = MainFrame
    
    local ScrollY = 0
    local Spacing = 45
    
    local function CreateSectionTitle(Text)
        local TitleLabel = Instance.new("TextLabel")
        TitleLabel.Size = UDim2.new(1, 0, 0, 25)
        TitleLabel.Position = UDim2.new(0, 0, 0, ScrollY)
        TitleLabel.Text = Text
        TitleLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
        TitleLabel.BackgroundTransparency = 1
        TitleLabel.Font = Enum.Font.GothamBold
        TitleLabel.TextSize = 14
        TitleLabel.Parent = Content
        ScrollY = ScrollY + 30
    end
    
    local function CreateToggle(Text, Setting, ConfigPath)
        local Button = Instance.new("TextButton")
        Button.Size = UDim2.new(0.9, 0, 0, 32)
        Button.Position = UDim2.new(0.05, 0, 0, ScrollY)
        Button.Text = Text .. (Setting and " [ON]" or " [OFF]")
        Button.BackgroundColor3 = Setting and Color3.fromRGB(80, 60, 120) or Color3.fromRGB(45, 35, 65)
        Button.BackgroundTransparency = 0.15
        Button.TextColor3 = Color3.fromRGB(255, 255, 255)
        Button.TextSize = 13
        Button.Font = Enum.Font.GothamBold
        Button.BorderSizePixel = 0
        Button.Parent = Content
        local ButtonCorner = Instance.new("UICorner")
        ButtonCorner.CornerRadius = UDim.new(0, 6)
        ButtonCorner.Parent = Button
        local ButtonStroke = Instance.new("UIStroke")
        ButtonStroke.Color = Setting and Color3.fromRGB(150, 100, 255) or Color3.fromRGB(80, 60, 120)
        ButtonStroke.Thickness = 1.5
        ButtonStroke.Transparency = 0.4
        ButtonStroke.Parent = Button
        
        Button.MouseButton1Click:Connect(function()
            if not ConfigPath then return end
            local Parts = {}
            for Part in string.gmatch(ConfigPath, "[^%.]+") do
                table.insert(Parts, Part)
            end
            local Target = Settings
            for i = 1, #Parts - 1 do
                Target = Target[Parts[i]]
            end
            local Key = Parts[#Parts]
            Target[Key] = not Target[Key]
            Button.Text = Text .. (Target[Key] and " [ON]" or " [OFF]")
            Button.BackgroundColor3 = Target[Key] and Color3.fromRGB(80, 60, 120) or Color3.fromRGB(45, 35, 65)
            ButtonStroke.Color = Target[Key] and Color3.fromRGB(150, 100, 255) or Color3.fromRGB(80, 60, 120)
            
            if Key == "Noclip" then UpdateNoclip()
            elseif Key == "GodMode" then UpdateGodMode()
            elseif Key == "Invisible" then UpdateInvisible()
            end
        end)
        ScrollY = ScrollY + Spacing
        return Button
    end
    
    local function CreateSlider(Text, Min, Max, Default, Callback)
        local Container = Instance.new("Frame")
        Container.Size = UDim2.new(0.9, 0, 0, 50)
        Container.Position = UDim2.new(0.05, 0, 0, ScrollY)
        Container.BackgroundTransparency = 1
        Container.Parent = Content
        
        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(1, 0, 0, 20)
        Label.Text = Text .. ": " .. tostring(Default)
        Label.TextColor3 = Color3.fromRGB(200, 200, 200)
        Label.BackgroundTransparency = 1
        Label.Font = Enum.Font.Gotham
        Label.TextSize = 12
        Label.Parent = Container
        
        local SliderBg = Instance.new("Frame")
        SliderBg.Size = UDim2.new(1, 0, 0, 4)
        SliderBg.Position = UDim2.new(0, 0, 0, 25)
        SliderBg.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
        SliderBg.BorderSizePixel = 0
        SliderBg.Parent = Container
        local SliderBgCorner = Instance.new("UICorner")
        SliderBgCorner.CornerRadius = UDim.new(1, 0)
        SliderBgCorner.Parent = SliderBg
        
        local Fill = Instance.new("Frame")
        Fill.Size = UDim2.new((Default - Min) / (Max - Min), 0, 1, 0)
        Fill.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
        Fill.BorderSizePixel = 0
        Fill.Parent = SliderBg
        local FillCorner = Instance.new("UICorner")
        FillCorner.CornerRadius = UDim.new(1, 0)
        FillCorner.Parent = Fill
        
        local Value = Default
        local Dragging = false
        local function UpdateValue(X)
            local RelativeX = math.clamp((X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
            Value = Min + (RelativeX * (Max - Min))
            Value = math.floor(Value)
            Fill.Size = UDim2.new(RelativeX, 0, 1, 0)
            Label.Text = Text .. ": " .. tostring(Value)
            Callback(Value)
        end
        
        SliderBg.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                Dragging = true
                UpdateValue(Mouse.X)
            end
        end)
        UserInputService.InputEnded:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                Dragging = false
            end
        end)
        UserInputService.InputChanged:Connect(function(Input)
            if Dragging and Input.UserInputType == Enum.UserInputType.MouseMovement then
                UpdateValue(Mouse.X)
            end
        end)
        
        ScrollY = ScrollY + Spacing
    end
    
    local function CreateDropdown(Text, Options, Default, Callback)
        local Container = Instance.new("Frame")
        Container.Size = UDim2.new(0.9, 0, 0, 50)
        Container.Position = UDim2.new(0.05, 0, 0, ScrollY)
        Container.BackgroundTransparency = 1
        Container.Parent = Content
        
        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(1, 0, 0, 20)
        Label.Text = Text .. ": " .. Default
        Label.TextColor3 = Color3.fromRGB(200, 200, 200)
        Label.BackgroundTransparency = 1
        Label.Font = Enum.Font.Gotham
        Label.TextSize = 12
        Label.Parent = Container
        
        local Dropdown = Instance.new("TextButton")
        Dropdown.Size = UDim2.new(1, 0, 0, 25)
        Dropdown.Position = UDim2.new(0, 0, 0, 25)
        Dropdown.Text = Default
        Dropdown.BackgroundColor3 = Color3.fromRGB(45, 35, 65)
        Dropdown.BackgroundTransparency = 0.15
        Dropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
        Dropdown.TextSize = 12
        Dropdown.Font = Enum.Font.Gotham
        Dropdown.BorderSizePixel = 0
        Dropdown.Parent = Container
        local DropdownCorner = Instance.new("UICorner")
        DropdownCorner.CornerRadius = UDim.new(0, 6)
        DropdownCorner.Parent = Dropdown
        local DropdownStroke = Instance.new("UIStroke")
        DropdownStroke.Color = Color3.fromRGB(80, 60, 120)
        DropdownStroke.Thickness = 1
        DropdownStroke.Transparency = 0.4
        DropdownStroke.Parent = Dropdown
        
        local CurrentIndex = 1
        for i, opt in ipairs(Options) do
            if opt == Default then CurrentIndex = i break end
        end
        
        Dropdown.MouseButton1Click:Connect(function()
            CurrentIndex = CurrentIndex % #Options + 1
            local NewValue = Options[CurrentIndex]
            Dropdown.Text = NewValue
            Label.Text = Text .. ": " .. NewValue
            Callback(NewValue)
        end)
        
        ScrollY = ScrollY + Spacing
    end
    
    -- Build UI
    CreateSectionTitle("⚡ ESP VISUALS")
    CreateToggle("ESP Box & Tracer", Settings.ESP.Enabled, "ESP.Enabled")
    CreateSlider("Max Distance (studs)", 50, 1000, Settings.ESP.MaxDistance, function(v)
        Settings.ESP.MaxDistance = v
    end)
    ScrollY = ScrollY + 10
    
    CreateSectionTitle("🛡️ MOVEMENT")
    CreateToggle("Noclip", Settings.Movement.Noclip, "Movement.Noclip")
    CreateToggle("Custom WalkSpeed", Settings.Movement.CustomWalkSpeed, "Movement.CustomWalkSpeed")
    CreateSlider("WalkSpeed", 16, 250, Settings.Movement.WalkSpeed, function(v)
        Settings.Movement.WalkSpeed = v
        if Settings.Movement.CustomWalkSpeed then UpdateWalkSpeed() end
    end)
    ScrollY = ScrollY + 10
    
    CreateSectionTitle("💀 COMBAT")
    CreateToggle("God Mode", Settings.Combat.GodMode, "Combat.GodMode")
    CreateToggle("Invisible", Settings.Combat.Invisible, "Combat.Invisible")
    CreateToggle("Auto Aim", Settings.Combat.AutoAim, "Combat.AutoAim")
    CreateSlider("Auto Aim Radius", 50, 1000, Settings.Combat.AutoAimRadius, function(v)
        Settings.Combat.AutoAimRadius = v
    end)
    CreateDropdown("Aim Part", {"HumanoidRootPart", "Head", "Torso"}, Settings.Combat.AutoAimPart, function(v)
        Settings.Combat.AutoAimPart = v
    end)
    CreateSlider("Lock Duration (sec)", 0.1, 2, Settings.Combat.AutoAimDuration, function(v)
        Settings.Combat.AutoAimDuration = v
    end)
    
    local BottomSpacer = Instance.new("Frame")
    BottomSpacer.Size = UDim2.new(1, 0, 0, 20)
    BottomSpacer.Position = UDim2.new(0, 0, 0, ScrollY)
    BottomSpacer.BackgroundTransparency = 1
    BottomSpacer.Parent = Content
    
    MakeDraggable(MainFrame)
end

--[[
    CHARACTER MONITORING
───────────────────────────────────────────────────────────────────────────────
]]
local function OnCharacterAdded(Char)
    UpdateLocalReferences()
    UpdateNoclip()
    UpdateWalkSpeed()
    UpdateGodMode()
    UpdateInvisible()
    print("[KemiGabut] Character loaded, features updated.")
end

if LocalPlayer.Character then
    OnCharacterAdded(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)

--[[
    PLAYER HANDLING
───────────────────────────────────────────────────────────────────────────────
]]
Players.PlayerAdded:Connect(function(Player)
    if Player ~= LocalPlayer then
        task.wait(0.5)
        if Settings.ESP.Enabled then
            CreateESPForPlayer(Player)
        end
    end
end)

Players.PlayerRemoving:Connect(function(Player)
    if ESPObjects[Player] then
        if ESPObjects[Player].Box then pcall(ESPObjects[Player].Box.Remove, ESPObjects[Player].Box) end
        if ESPObjects[Player].Tracer then pcall(ESPObjects[Player].Tracer.Remove, ESPObjects[Player].Tracer) end
        if ESPObjects[Player].Name then pcall(ESPObjects[Player].Name.Remove, ESPObjects[Player].Name) end
        if ESPObjects[Player].Distance then pcall(ESPObjects[Player].Distance.Remove, ESPObjects[Player].Distance) end
        ESPObjects[Player] = nil
    end
end)

--[[
    MAIN LOOPS
───────────────────────────────────────────────────────────────────────────────
]]
task.spawn(function()
    while true do
        task.wait()
        if Settings.ESP.Enabled then
            for _, Player in ipairs(Players:GetPlayers()) do
                if Player ~= LocalPlayer and not ESPObjects[Player] then
                    CreateESPForPlayer(Player)
                end
            end
            UpdateESP()
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.1)
        UpdateNoclip()
        if Settings.Movement.CustomWalkSpeed then UpdateWalkSpeed() end
        UpdateGodMode()
        UpdateInvisible()
    end
end)

task.spawn(function()
    while true do
        task.wait()
        if Settings.Combat.AutoAim then
            ProcessAutoAim()
        end
    end
end)

-- Cleanup old ESP objects
task.spawn(function()
    while true do
        task.wait(5)
        for Player, _ in pairs(ESPObjects) do
            if not Player or not Player.Parent then
                ESPObjects[Player] = nil
            end
        end
    end
end)

--[[
    INITIALIZE UI and CROSSHAIR
───────────────────────────────────────────────────────────────────────────────
]]
CreateCrosshair()
CreateGUI()

print([[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                                                                   ║
    ║              ⚡ KEMI_GABUT ULTIMATE HUB (FIXED) ⚡                 ║
    ║                   Script Loaded Successfully!                     ║
    ║                    Developed by: kemi                             ║
    ║                                                                   ║
    ║  📌 Controls:                                                     ║
    ║     • Toggle UI: Press 'F' Key                                    ║
    ║     • Everything else is configurable via the GUI                 ║
    ║                                                                   ║
    ║  💡 Note: If ESP does not appear, your executor may not support   ║
    ║     Drawing API. Other features should still work.                ║
    ║                                                                   ║
    ╚═══════════════════════════════════════════════════════════════════╝
]])

-- Keybind to toggle UI
UserInputService.InputBegan:Connect(function(Input, GameProcessed)
    if GameProcessed then return end
    if Input.KeyCode == Enum.KeyCode.F then
        local Gui = LocalPlayer.PlayerGui:FindFirstChild("KemiGabut_Hub")
        if Gui then
            Gui.Visible = not Gui.Visible
        end
    end
end)
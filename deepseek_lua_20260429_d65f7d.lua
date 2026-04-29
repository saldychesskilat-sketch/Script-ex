--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                                                                   ║
    ║              ⚡ KEMI_GABUT ULTIMATE HUB ⚡                         ║
    ║                   Developed by: kemi                              ║
    ║                     Version: 1.0.0                                ║
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
    • Customizable GUI with Draggabvle Frame

    🎮 CONTROLS:
    • Toggle UI: F
    • Everything else is configurable via the GUI

    💻 Made with ❤️ by kemi
--]]

--[[
    KEMI_GABUT Ultimate Hub
───────────────────────────────────────────────────────────────────────────────
]]

-- Detect the executor type and set up the environment
local syn_supported, syn = pcall(function()
    return (syn and syn.crypt) or (synapse and synapse) or (getfenv and getfenv())
end)

local isDelta = (type(identifyexecutor) == "function" and identifyexecutor():lower():find("delta")) or false

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

local Character = LocalPlayer.Character
local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
local HumanoidRootPart = Character and (Character:FindFirstChild("HumanoidRootPart") or Character:FindFirstChild("Torso") or Character:FindFirstChild("UpperTorso"))

--[[
    CONFIGURATION
───────────────────────────────────────────────────────────────────────────────
]]
local Settings = {
    -- ESP Settings
    ESP = {
        Enabled = true,
        BoxColor = Color3.fromRGB(0, 255, 255),   -- Cyan
        TracerColor = Color3.fromRGB(255, 0, 255), -- Magenta
        NameColor = Color3.fromRGB(255, 255, 255),
        DistanceColor = Color3.fromRGB(200, 200, 200),
        BoxThickness = 1,
        TracerThickness = 1,
        ShowName = true,
        ShowDistance = true,
        MaxDistance = 500,
        TracerFrom = "Head",
    },
    
    -- Movement Settings
    Movement = {
        Noclip = false,
        WalkSpeed = 16,
        CustomWalkSpeed = false,
    },
    
    -- Combat Settings
    Combat = {
        Invisible = false,
        GodMode = false,
        AutoAim = false,
        AutoAimRadius = 200,
        AutoAimPart = "HumanoidRootPart",
        AutoAimDuration = 0.1,
    },
    
    -- UI Settings
    UI = {
        Visible = true,
        Draggable = true,
    },
}

--[[
    STATE VARIABLES
───────────────────────────────────────────────────────────────────────────────
]]
local ESPObjects = {}  -- {Player = {Box, Tracer, Name, Distance}}
local AutoAimActive = false
local AutoAimCooldown = false
local LastAutoAimTime = 0

--[[
    DRAWING API WRAPPER (Compatible with Delta)
───────────────────────────────────────────────────────────────────────────────
]]
local Drawing = {new = function() return {} end}
if Drawing and Drawing.Fonts then
    -- Already have Drawing
else
    -- Attempt to get Drawing from environment
    local env = getgenv and getgenv() or _G
    if env.Drawing then Drawing = env.Drawing end
    if not Drawing.new then
        Drawing = {new = function() return {} end}
    end
end

--[[
    UTILITY FUNCTIONS
───────────────────────────────────────────────────────────────────────────────
]]
local function GetCharacter(Player)
    return Player.Character
end

local function GetHumanoid(Player)
    local Char = GetCharacter(Player)
    return Char and Char:FindFirstChildOfClass("Humanoid")
end

local function IsAlive(Player)
    local Hum = GetHumanoid(Player)
    return Hum and Hum.Health > 0
end

local function GetWorldPosition(Player, PartName)
    local Char = GetCharacter(Player)
    if not Char then return nil end
    local Part = Char:FindFirstChild(PartName)
    if Part then return Part.Position end
    return nil
end

local function GetScreenPosition(WorldPosition)
    if not WorldPosition then return nil end
    local Vector, OnScreen = Camera:WorldToViewportPoint(WorldPosition)
    if OnScreen then
        return Vector2.new(Vector.X, Vector.Y)
    end
    return nil
end

--[[
    ESP IMPLEMENTATION
───────────────────────────────────────────────────────────────────────────────
]]
local function CreateESPForPlayer(Player)
    if not Settings.ESP.Enabled then return end
    if Player == LocalPlayer then return end
    if ESPObjects[Player] then return end
    
    local Char = GetCharacter(Player)
    if not Char then return end
    
    -- Create Box Drawing Object
    local Box = Drawing.new("Square")
    Box.Visible = false
    Box.Thickness = Settings.ESP.BoxThickness
    Box.Color = Settings.ESP.BoxColor
    Box.Filled = false
    
    -- Create Tracer Line
    local Tracer = Drawing.new("Line")
    Tracer.Visible = false
    Tracer.Thickness = Settings.ESP.TracerThickness
    Tracer.Color = Settings.ESP.TracerColor
    Tracer.Transparency = 0.5
    
    -- Create Name Label (only if Drawing supports Text)
    local NameText = Drawing.new("Text")
    NameText.Visible = false
    NameText.Color = Settings.ESP.NameColor
    NameText.Center = true
    NameText.Size = 12
    NameText.Font = Drawing.Fonts and Drawing.Fonts.UI or 0
    
    -- Create Distance Label
    local DistanceText = Drawing.new("Text")
    DistanceText.Visible = false
    DistanceText.Color = Settings.ESP.DistanceColor
    DistanceText.Center = true
    DistanceText.Size = 10
    DistanceText.Font = Drawing.Fonts and Drawing.Fonts.UI or 0
    
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
    
    local LocalRoot = HumanoidRootPart
    if not LocalRoot then return end
    
    for Player, Data in pairs(ESPObjects) do
        if not IsAlive(Player) then
            Data.Box.Visible = false
            Data.Tracer.Visible = false
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
            Data.Box.Visible = false
            Data.Tracer.Visible = false
            if Data.Name then Data.Name.Visible = false end
            if Data.Distance then Data.Distance.Visible = false end
            goto Continue
        end
        
        -- Calculate distance
        local Distance = (LocalRoot.Position - RootPart.Position).Magnitude
        if Distance > Settings.ESP.MaxDistance then
            Data.Box.Visible = false
            Data.Tracer.Visible = false
            if Data.Name then Data.Name.Visible = false end
            if Data.Distance then Data.Distance.Visible = false end
            goto Continue
        end
        
        -- Box Size
        local BoxSize = 100 / Distance * 3
        local BoxPos = Vector2.new(ScreenPos.X - BoxSize / 2, ScreenPos.Y - BoxSize / 1.5)
        
        -- Update Box
        Data.Box.Size = Vector2.new(BoxSize, BoxSize * 1.5)
        Data.Box.Position = BoxPos
        Data.Box.Visible = true
        
        -- Update Tracer
        local ScreenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        Data.Tracer.From = ScreenCenter
        Data.Tracer.To = ScreenPos
        Data.Tracer.Visible = true
        
        -- Update Name
        if Settings.ESP.ShowName and Data.Name then
            Data.Name.Text = Player.Name
            Data.Name.Position = Vector2.new(ScreenPos.X, BoxPos.Y - 15)
            Data.Name.Visible = true
        elseif Data.Name then
            Data.Name.Visible = false
        end
        
        -- Update Distance
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
        if Data.Box then Data.Box:Remove() end
        if Data.Tracer then Data.Tracer:Remove() end
        if Data.Name then Data.Name:Remove() end
        if Data.Distance then Data.Distance:Remove() end
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
                local Distance = (HumanoidRootPart.Position - Char:GetPivot().Position).Magnitude
                if Distance < MinDistance then
                    MinDistance = Distance
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
    if not Char then return false end
    
    local TargetPart = Char:FindFirstChild(Settings.Combat.AutoAimPart)
    if not TargetPart then
        TargetPart = Char:FindFirstChild("HumanoidRootPart")
    end
    if not TargetPart then return false end
    
    -- Lock Camera
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
    if not Character or not Humanoid or not HumanoidRootPart then return end
    
    if AutoAimCooldown then return end
    
    -- Check if crosshair aligns with nearest player
    local Nearest = GetNearestPlayer()
    if not Nearest then return end
    
    local Char = GetCharacter(Nearest)
    if not Char then return end
    
    local TargetPart = Char:FindFirstChild(Settings.Combat.AutoAimPart)
    if not TargetPart then return end
    
    -- Convert target position to screen coordinates
    local ScreenPos = Camera:WorldToViewportPoint(TargetPart.Position)
    local ScreenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local DistanceFromCenter = math.abs(ScreenPos.X - ScreenCenter.X)
    
    -- Detect if crosshair is near the target
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
    if not Character then return end
    
    if Settings.Combat.GodMode then
        -- Prevent health from dropping
        local Hum = Humanoid
        if Hum then
            local Connection
            Connection = Hum:GetPropertyChangedSignal("Health"):Connect(function()
                if Hum.Health <= 0 then
                    -- Disable health monitoring to prevent infinite loop
                    Connection:Disconnect()
                    Hum.Health = Hum.MaxHealth
                    task.wait(0.1)
                    Connection = nil
                    UpdateGodMode()
                elseif Hum.Health < Hum.MaxHealth then
                    Hum.Health = Hum.MaxHealth
                end
            end)
            -- Store connection for cleanup if needed
            if not Hum._godModeConnection then
                Hum._godModeConnection = Connection
            end
        end
    else
        if Humanoid and Humanoid._godModeConnection then
            Humanoid._godModeConnection:Disconnect()
            Humanoid._godModeConnection = nil
        end
    end
end

local function UpdateInvisible()
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
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "KemiGabut_Crosshair"
    ScreenGui.Parent = LocalPlayer:FindFirstChild("PlayerGui") or CoreGui
    ScreenGui.ResetOnSpawn = false
    
    local CrosshairContainer = Instance.new("Frame")
    CrosshairContainer.Size = UDim2.new(0, 30, 0, 30)
    CrosshairContainer.Position = UDim2.new(0.5, -15, 0.5, -15)
    CrosshairContainer.BackgroundTransparency = 1
    CrosshairContainer.Parent = ScreenGui
    
    -- Outer Circle
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
    
    -- Inner Dot
    local Dot = Instance.new("Frame")
    Dot.Size = UDim2.new(0, 3, 0, 3)
    Dot.Position = UDim2.new(0.5, -1.5, 0.5, -1.5)
    Dot.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    Dot.BorderSizePixel = 0
    Dot.Parent = CrosshairContainer
    
    local DotCorner = Instance.new("UICorner")
    DotCorner.CornerRadius = UDim.new(1, 0)
    DotCorner.Parent = Dot
    
    -- Crosshair Lines (X shape)
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
    
    return ScreenGui
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
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "KemiGabut_Hub"
    ScreenGui.Parent = LocalPlayer:FindFirstChild("PlayerGui") or CoreGui
    ScreenGui.ResetOnSpawn = false
    
    -- Main Frame
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
    
    -- Title Bar
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
    
    -- Close Button
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
    
    -- Content Container
    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -20, 1, -55)
    Content.Position = UDim2.new(0, 10, 0, 50)
    Content.BackgroundTransparency = 1
    Content.Parent = MainFrame
    
    local ScrollY = 0
    local Spacing = 45
    
    -- Helper function to create a section title
    local function CreateSectionTitle(Text)
        local Title = Instance.new("TextLabel")
        Title.Size = UDim2.new(1, 0, 0, 25)
        Title.Position = UDim2.new(0, 0, 0, ScrollY)
        Title.Text = Text
        Title.TextColor3 = Color3.fromRGB(0, 255, 255)
        Title.BackgroundTransparency = 1
        Title.Font = Enum.Font.GothamBold
        Title.TextSize = 14
        Title.Parent = Content
        ScrollY = ScrollY + 30
    end
    
    -- Helper function to create a toggle button
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
            
            -- Update features
            if Key == "Noclip" then
                UpdateNoclip()
            elseif Key == "GodMode" then
                UpdateGodMode()
            elseif Key == "Invisible" then
                UpdateInvisible()
            elseif Key == "AutoAim" then
                -- Auto-aim toggled
            end
        end)
        
        ScrollY = ScrollY + Spacing
        return Button
    end
    
    -- Helper function to create a slider
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
    
    -- Helper function to create a dropdown
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
        
        Dropdown = Instance.new("TextButton")
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
        
        Dropdown.MouseButton1Click:Connect(function()
            -- In a real implementation, you would show a list of options
            -- For simplicity, we'll cycle through options
            local CurrentIndex = 1
            for i, Opt in ipairs(Options) do
                if Opt == Callback then
                    CurrentIndex = i
                    break
                end
            end
            local NextIndex = CurrentIndex % #Options + 1
            local NewValue = Options[NextIndex]
            Dropdown.Text = NewValue
            Label.Text = Text .. ": " .. NewValue
            Callback(NewValue)
        end)
        
        ScrollY = ScrollY + Spacing
    end
    
    -- Build UI Sections
    CreateSectionTitle("⚡ ESP VISUALS")
    CreateToggle("ESP Box & Tracer", Settings.ESP.Enabled, "ESP.Enabled")
    CreateSlider("Max Distance (studs)", 50, 1000, Settings.ESP.MaxDistance, function(Value)
        Settings.ESP.MaxDistance = Value
    end)
    
    ScrollY = ScrollY + 10
    
    CreateSectionTitle("🛡️ MOVEMENT")
    CreateToggle("Noclip", Settings.Movement.Noclip, "Movement.Noclip")
    CreateToggle("Custom WalkSpeed", Settings.Movement.CustomWalkSpeed, "Movement.CustomWalkSpeed")
    CreateSlider("WalkSpeed", 16, 250, Settings.Movement.WalkSpeed, function(Value)
        Settings.Movement.WalkSpeed = Value
        if Settings.Movement.CustomWalkSpeed then
            UpdateWalkSpeed()
        end
    end)
    
    ScrollY = ScrollY + 10
    
    CreateSectionTitle("💀 COMBAT")
    CreateToggle("God Mode", Settings.Combat.GodMode, "Combat.GodMode")
    CreateToggle("Invisible", Settings.Combat.Invisible, "Combat.Invisible")
    CreateToggle("Auto Aim", Settings.Combat.AutoAim, "Combat.AutoAim")
    CreateSlider("Auto Aim Radius", 50, 1000, Settings.Combat.AutoAimRadius, function(Value)
        Settings.Combat.AutoAimRadius = Value
    end)
    CreateDropdown("Aim Part", {"HumanoidRootPart", "Head", "Torso"}, Settings.Combat.AutoAimPart, function(Value)
        Settings.Combat.AutoAimPart = Value
    end)
    CreateSlider("Lock Duration (sec)", 0.1, 2, Settings.Combat.AutoAimDuration, function(Value)
        Settings.Combat.AutoAimDuration = Value
    end)
    
    -- Add some space at the end
    local BottomSpacer = Instance.new("Frame")
    BottomSpacer.Size = UDim2.new(1, 0, 0, 20)
    BottomSpacer.Position = UDim2.new(0, 0, 0, ScrollY)
    BottomSpacer.BackgroundTransparency = 1
    BottomSpacer.Parent = Content
    
    -- Make GUI draggable
    MakeDraggable(MainFrame)
    
    return ScreenGui
end

--[[
    CHARACTER MONITORING
───────────────────────────────────────────────────────────────────────────────
]]
local function OnCharacterAdded(Char)
    Character = Char
    Humanoid = Char:FindFirstChildOfClass("Humanoid")
    HumanoidRootPart = Char:FindFirstChild("HumanoidRootPart") or Char:FindFirstChild("Torso") or Char:FindFirstChild("UpperTorso")
    
    -- Update features
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
        if ESPObjects[Player].Box then ESPObjects[Player].Box:Remove() end
        if ESPObjects[Player].Tracer then ESPObjects[Player].Tracer:Remove() end
        if ESPObjects[Player].Name then ESPObjects[Player].Name:Remove() end
        if ESPObjects[Player].Distance then ESPObjects[Player].Distance:Remove() end
        ESPObjects[Player] = nil
    end
end)

--[[
    MAIN LOOP
───────────────────────────────────────────────────────────────────────────────
]]
local function StartLoops()
    -- ESP Update Loop
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
    
    -- Movement Updates
    task.spawn(function()
        while true do
            task.wait(0.1)
            if Settings.Movement.Noclip then
                UpdateNoclip()
            end
            if Settings.Movement.CustomWalkSpeed then
                UpdateWalkSpeed()
            end
            if Settings.Combat.GodMode then
                UpdateGodMode()
            end
            if Settings.Combat.Invisible then
                UpdateInvisible()
            end
        end
    end)
    
    -- Auto Aim Loop
    task.spawn(function()
        while true do
            task.wait()
            if Settings.Combat.AutoAim and Character and Humanoid and HumanoidRootPart then
                ProcessAutoAim()
            end
        end
    end)
    
    -- Cleanup old ESP objects for players who left
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
end

--[[
    INITIALIZE
───────────────────────────────────────────────────────────────────────────────
]]
CreateCrosshair()
CreateGUI()
StartLoops()

print([[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                                                                   ║
    ║              ⚡ KEMI_GABUT ULTIMATE HUB ⚡                         ║
    ║                   Script Loaded Successfully!                     ║
    ║                    Developed by: kemi                             ║
    ║                                                                   ║
    ║  📌 Controls:                                                     ║
    ║     • Toggle UI: Press 'F' Key                                    ║
    ║     • Everything else is configurable via the GUI                 ║
    ║                                                                   ║
    ║  💡 Note: For the best experience, adjust the settings            ║
    ║     according to your preferences in the GUI.                     ║
    ║                                                                   ║
    ╚═══════════════════════════════════════════════════════════════════╝
]])

-- Keybind to toggle UI
UserInputService.InputBegan:Connect(function(Input, GameProcessed)
    if GameProcessed then return end
    if Input.KeyCode == Enum.KeyCode.F then
        local GUI = LocalPlayer.PlayerGui:FindFirstChild("KemiGabut_Hub")
        if GUI then
            GUI.Visible = not GUI.Visible
        end
    end
end)
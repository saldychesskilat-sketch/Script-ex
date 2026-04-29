--[[
    CyberHeroes Script - kemi_gabut
    Fitur: ESP Modern (garis + jarak), Noclip, Tpwalk (slider), Invisible, God Mode, Auto Aim (busur lock 2 detik)
    GUI Draggable + Toggle (Hide/Show)
    Developed for Delta Executor
]]

-- ============================================================================
-- SERVICES
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- ============================================================================
-- VARIABLES GLOBAL
-- ============================================================================
local getgenv = getgenv or _G
local state = getgenv.KemiGabut or {}
getgenv.KemiGabut = state

-- Default config
state.config = state.config or {
    espEnabled = true,
    noclipEnabled = false,
    tpwalkEnabled = false,
    tpwalkSpeed = 50,
    invisibleEnabled = false,
    godModeEnabled = false,
    autoAimEnabled = false,
    guiVisible = true,
}

-- Variabel internal
local localChar = nil
local localHumanoid = nil
local localRoot = nil
local drawingLines = {} -- untuk garis ESP
local espLabels = {}    -- untuk teks jarak
local autoAimLocked = false
local autoAimLockEnd = 0
local originalWalkspeed = 16

-- ============================================================================
-- FUNGSI UTILITY
-- ============================================================================
local function getLocalChar()
    localChar = LocalPlayer.Character
    if localChar then
        localHumanoid = localChar:FindFirstChildOfClass("Humanoid")
        localRoot = localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("Torso")
    end
    return localChar
end

-- ============================================================================
-- ESP MODERN: Garis lurus + label jarak (menggunakan Drawing)
-- ============================================================================
local function createDrawingLine()
    local line = Drawing.new("Line")
    line.Thickness = 2
    line.Color = Color3.fromRGB(0, 255, 255)
    line.Transparency = 0.7
    line.Visible = true
    return line
end

local function createTextLabel()
    local text = Drawing.new("Text")
    text.Center = true
    text.Outline = true
    text.OutlineColor = Color3.fromRGB(0, 0, 0)
    text.Color = Color3.fromRGB(255, 255, 255)
    text.Size = 14
    text.Visible = true
    return text
end

local function updateESP()
    if not state.config.espEnabled then
        -- Hapus semua drawing
        for _, line in pairs(drawingLines) do line.Visible = false end
        for _, txt in pairs(espLabels) do txt.Visible = false end
        return
    end
    
    local localPos = localRoot and localRoot.Position
    if not localPos or not Camera then return end
    
    local players = Players:GetPlayers()
    for _, player in ipairs(players) do
        if player ~= LocalPlayer then
            local char = player.Character
            if char and char.Parent then
                local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                if rootPart then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
                    if onScreen then
                        -- Line dari posisi layar local? Sebenarnya garis dari player ke player lain.
                        -- Lebih baik garis dari posisi local player ke target player di layar?
                        -- Alternatif: garis dari titik bawah layar ke player? Tapi permintaan "garis lurus"
                        -- Saya buat garis dari tengah layar (local ke target) menggunakan vector2D
                        local localScreen, _ = Camera:WorldToViewportPoint(localPos)
                        if localScreen then
                            local line = drawingLines[player]
                            if not line then
                                line = createDrawingLine()
                                drawingLines[player] = line
                            end
                            line.From = Vector2.new(localScreen.X, localScreen.Y)
                            line.To = Vector2.new(screenPos.X, screenPos.Y)
                            line.Visible = true
                            
                            -- Jarak
                            local dist = (localPos - rootPart.Position).Magnitude
                            local txt = espLabels[player]
                            if not txt then
                                txt = createTextLabel()
                                espLabels[player] = txt
                            end
                            txt.Text = string.format("%.1f", dist)
                            txt.Position = Vector2.new(screenPos.X, screenPos.Y - 20)
                            txt.Visible = true
                        end
                    else
                        if drawingLines[player] then drawingLines[player].Visible = false end
                        if espLabels[player] then espLabels[player].Visible = false end
                    end
                end
            else
                if drawingLines[player] then drawingLines[player].Visible = false end
                if espLabels[player] then espLabels[player].Visible = false end
            end
        end
    end
end

-- ============================================================================
-- NO CLIP
-- ============================================================================
local function updateNoclip()
    if not state.config.noclipEnabled then
        if localChar then
            for _, part in ipairs(localChar:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
        return
    end
    if localChar then
        for _, part in ipairs(localChar:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end

-- ============================================================================
-- TPWALK (CFrame-based movement) dengan slider
-- ============================================================================
local function tpwalk()
    if not state.config.tpwalkEnabled then return end
    if not localHumanoid or not localRoot then return end
    local moveDir = localHumanoid.MoveDirection
    if moveDir.Magnitude > 0.1 then
        local step = moveDir * (state.config.tpwalkSpeed * 0.05)  -- 0.05 faktor frame
        local newPos = localRoot.Position + step
        localRoot.CFrame = CFrame.new(newPos) * CFrame.Angles(0, localRoot.Orientation.Y, 0)
    end
end

-- ============================================================================
-- INVISIBLE (Local player)
-- ============================================================================
local function updateInvisible()
    if not state.config.invisibleEnabled then
        if localChar then
            for _, part in ipairs(localChar:GetDescendants()) do
                if part:IsA("BasePart") then part.Transparency = 0 end
            end
        end
        return
    end
    if localChar then
        for _, part in ipairs(localChar:GetDescendants()) do
            if part:IsA("BasePart") then part.Transparency = 1 end
        end
    end
end

-- ============================================================================
-- GOD MODE
-- ============================================================================
local function updateGodMode()
    if not state.config.godModeEnabled then return end
    if localHumanoid then
        localHumanoid.Health = localHumanoid.MaxHealth
    end
end

-- ============================================================================
-- AUTO AIM dengan busur GUI (sumbu X detection)
-- ============================================================================
local screenGui = nil
local aimCircle = nil

local function createAimGUI()
    if screenGui then screenGui:Destroy() end
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AimAssist"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = game.CoreGui
    
    -- Busur/lingkaran di tengah
    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 60, 0, 60)
    circle.Position = UDim2.new(0.5, -30, 0.5, -30)
    circle.BackgroundTransparency = 1
    circle.BorderSizePixel = 0
    circle.Parent = screenGui
    
    -- Gambar lingkaran (menggunakan image label)
    local img = Instance.new("ImageLabel")
    img.Size = UDim2.new(1, 0, 1, 0)
    img.BackgroundTransparency = 1
    img.Image = "rbxassetid://10962615861" -- crosshair circle alternative? Atau buat sendiri dengan gradient?
    img.ImageColor3 = Color3.fromRGB(0, 255, 255)
    img.ImageTransparency = 0.3
    img.Parent = circle
    
    -- Garis sumbu X (horizontal)
    local lineX = Instance.new("Frame")
    lineX.Size = UDim2.new(0, 80, 0, 2)
    lineX.Position = UDim2.new(0.5, -40, 0.5, -1)
    lineX.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
    lineX.BackgroundTransparency = 0.5
    lineX.Parent = screenGui
    
    -- Garis sumbu Y (vertical)
    local lineY = Instance.new("Frame")
    lineY.Size = UDim2.new(0, 2, 0, 80)
    lineY.Position = UDim2.new(0.5, -1, 0.5, -40)
    lineY.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
    lineY.BackgroundTransparency = 0.5
    lineY.Parent = screenGui
    
    aimCircle = {circle = circle, lineX = lineX, lineY = lineY}
end

local function getTargetPlayerUnderCrosshair()
    local mousePos = UserInputService:GetMouseLocation()
    local target = nil
    local minDist = 50 -- radius deteksi (dalam pixel)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                if root then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if dist < minDist then
                            minDist = dist
                            target = player
                        end
                    end
                end
            end
        end
    end
    return target
end

local function updateAutoAim()
    if not state.config.autoAimEnabled then
        if aimCircle then
            aimCircle.circle.Visible = false
            aimCircle.lineX.Visible = false
            aimCircle.lineY.Visible = false
        end
        return
    end
    if not aimCircle then createAimGUI() end
    aimCircle.circle.Visible = true
    aimCircle.lineX.Visible = true
    aimCircle.lineY.Visible = true
    
    local now = tick()
    if autoAimLocked and now < autoAimLockEnd then
        -- Kamera masih locked (tidak usah update target)
        return
    elseif autoAimLocked and now >= autoAimLockEnd then
        autoAimLocked = false
        -- unlock kamera? Tidak perlu karena akan di-update lagi.
    end
    
    local targetPlayer = getTargetPlayerUnderCrosshair()
    if targetPlayer and targetPlayer.Character then
        local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart") or targetPlayer.Character:FindFirstChild("Torso")
        if targetRoot then
            -- Lock kamera selama 2 detik
            autoAimLocked = true
            autoAimLockEnd = now + 2
            -- Set kamera ke target
            local camCF = CFrame.new(Camera.CFrame.Position, targetRoot.Position)
            Camera.CFrame = camCF
        end
    end
end

-- ============================================================================
-- GUI MODERN (Draggable, Toggle, Slider)
-- ============================================================================
local gui = nil
local mainFrame = nil
local isGuiVisible = true

local function toggleGUI()
    isGuiVisible = not isGuiVisible
    if mainFrame then mainFrame.Visible = isGuiVisible end
end

local function createGUI()
    if gui then gui:Destroy() end
    gui = Instance.new("ScreenGui")
    gui.Name = "KemiGabut"
    gui.ResetOnSpawn = false
    gui.Parent = game.CoreGui
    
    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 280, 0, 320)
    mainFrame.Position = UDim2.new(0.5, -140, 0.5, -160)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = gui
    -- Sudut melengkung
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame
    -- Efek glowing
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 200, 255)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.6
    stroke.Parent = mainFrame
    
    -- Title bar (draggable)
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -40, 1, 0)
    titleLabel.Position = UDim2.new(0, 10, 0, 0)
    titleLabel.Text = "⚡ KEMI GABUT v1"
    titleLabel.TextColor3 = Color3.fromRGB(0, 230, 255)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 14
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar
    
    -- Tombol close
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 1, -6)
    closeBtn.Position = UDim2.new(1, -35, 0, 3)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(toggleGUI)
    
    -- Tombol hide/show (toggle menu) - bisa juga dengan keybind F
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 30, 1, -6)
    toggleBtn.Position = UDim2.new(1, -70, 0, 3)
    toggleBtn.Text = "⊟"
    toggleBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 5, 5)
    toggleBtn.BackgroundTransparency = 0.2
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 16
    toggleBtn.Parent = titleBar
    toggleBtn.MouseButton1Click:Connect(toggleGUI)
    
    -- Draggable logic
    local dragging = false
    local dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)
    titleBar.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                          startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    -- Konten: daftar toggle + slider
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -10, 1, -40)
    scroll.Position = UDim2.new(0, 5, 0, 35)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.CanvasSize = UDim2.new(0, 0, 0, 250)
    scroll.Parent = mainFrame
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll
    
    local function createToggle(text, configKey, default)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 30)
        frame.BackgroundTransparency = 1
        frame.Parent = scroll
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.6, 0, 1, 0)
        label.Text = text
        label.TextColor3 = Color3.fromRGB(220, 220, 220)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Gotham
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame
        
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 50, 0, 24)
        btn.Position = UDim2.new(1, -55, 0.5, -12)
        btn.Text = state.config[configKey] and "ON" or "OFF"
        btn.TextColor3 = state.config[configKey] and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(150, 150, 150)
        btn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
        btn.BackgroundTransparency = 0.2
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.Parent = frame
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            state.config[configKey] = not state.config[configKey]
            btn.Text = state.config[configKey] and "ON" or "OFF"
            btn.TextColor3 = state.config[configKey] and Color3.fromRGB(0, 230, 255) or Color3.fromRGB(150, 150, 150)
        end)
    end
    
    local function createSlider(text, configKey, minVal, maxVal, default)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 50)
        frame.BackgroundTransparency = 1
        frame.Parent = scroll
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 20)
        label.Text = text .. " (" .. tostring(state.config[configKey]) .. ")"
        label.TextColor3 = Color3.fromRGB(220, 220, 220)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Gotham
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame
        
        local slider = Instance.new("TextBox")
        slider.Size = UDim2.new(0.9, 0, 0, 20)
        slider.Position = UDim2.new(0.05, 0, 0, 25)
        slider.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        slider.Text = tostring(state.config[configKey])
        slider.TextColor3 = Color3.fromRGB(255, 255, 255)
        slider.Font = Enum.Font.Gotham
        slider.TextSize = 12
        slider.Parent = frame
        local slideCorner = Instance.new("UICorner")
        slideCorner.CornerRadius = UDim.new(0, 6)
        slideCorner.Parent = slider
        
        slider.FocusLost:Connect(function()
            local val = tonumber(slider.Text)
            if val then
                val = math.clamp(val, minVal, maxVal)
                state.config[configKey] = val
                slider.Text = tostring(val)
                label.Text = text .. " (" .. tostring(val) .. ")"
            else
                slider.Text = tostring(state.config[configKey])
            end
        end)
    end
    
    -- Buat toggle untuk setiap fitur
    createToggle("ESP (Garis + Jarak)", "espEnabled", true)
    createToggle("Noclip", "noclipEnabled", false)
    createToggle("Tpwalk (CFrame dash)", "tpwalkEnabled", false)
    createSlider("Tpwalk Speed", "tpwalkSpeed", 20, 200, 50)
    createToggle("Invisible (Hide Character)", "invisibleEnabled", false)
    createToggle("God Mode (Infinite Health)", "godModeEnabled", false)
    createToggle("Auto Aim (Busur + Lock 2s)", "autoAimEnabled", false)
    
    -- Update status label teks slider saat speed berubah
    task.spawn(function()
        while gui and gui.Parent do
            for _, frame in ipairs(scroll:GetChildren()) do
                if frame:IsA("Frame") and frame:FindFirstChildWhichIsA("TextLabel") then
                    local label = frame:FindFirstChildWhichIsA("TextLabel")
                    if label and label.Text:find("Tpwalk Speed") then
                        label.Text = "Tpwalk Speed (" .. tostring(state.config.tpwalkSpeed) .. ")"
                    end
                end
            end
            task.wait(0.5)
        end
    end)
end

-- ============================================================================
-- MAIN LOOP & EVENT HANDLER
-- ============================================================================
local function onCharacterAdded(char)
    localChar = char
    localHumanoid = char:FindFirstChildOfClass("Humanoid")
    localRoot = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if localHumanoid then
        originalWalkspeed = localHumanoid.WalkSpeed
    end
    updateNoclip()
    updateInvisible()
end

-- Init
local function init()
    createGUI()
    createAimGUI()
    if LocalPlayer.Character then onCharacterAdded(LocalPlayer.Character) end
    LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
    
    -- Keybind untuk toggle menu (F)
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.F then
            toggleGUI()
        end
    end)
    
    -- Loop utama untuk fitur yang memerlukan update terus
    RunService.RenderStepped:Connect(function()
        getLocalChar()
        if not localChar then return end
        updateESP()
        updateNoclip()
        tpwalk()
        updateInvisible()
        updateGodMode()
        updateAutoAim()
    end)
    
    print("╔═══════════════════════════════════════════╗")
    print("║     CyberHeroes - kemi_gabut loaded      ║")
    print("║  Tekan F untuk hide/show menu           ║")
    print("║  All features active!                   ║")
    print("╚═══════════════════════════════════════════╝")
end

-- Mulai
task.wait(1)
init()
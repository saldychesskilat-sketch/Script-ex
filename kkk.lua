-- ============================================================================
-- KEMI // ACCESS CONTROL — Welcome Screen + Loader
-- Delta Executor LocalScript
-- ============================================================================

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local CoreGui           = game:GetService("CoreGui")

local LocalPlayer       = Players.LocalPlayer

local MAIN_URL = "https://raw.githubusercontent.com/saldychesskilat-sketch/Script-ex/refs/heads/main/chai_lua_20260417_a77e37.lua"

local THEME = {
    BG          = Color3.fromRGB(20, 5, 10),
    BG_HEADER   = Color3.fromRGB(25, 3, 7),
    NEON        = Color3.fromRGB(0, 230, 255),
    TEXT        = Color3.fromRGB(235, 235, 235),
    TEXT_DIM    = Color3.fromRGB(170, 170, 170),
    WARN        = Color3.fromRGB(255, 200, 90),
    ERR         = Color3.fromRGB(255, 90, 90),
    OK          = Color3.fromRGB(0, 255, 150),
}

local GLITCH_CHARS = "!@#$%^&*()_+-=[]{}|;:,.<>?/0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

-- ============================================================================
local function createWelcomeScreen()
    -- ---------------------------------------------------------------------
    -- STATE LOKAL
    -- ---------------------------------------------------------------------
    local screenGui
    local mainFrame
    local glitchLabel
    local welcomeTitle
    local welcomeSubtitle
    local continueBtn

    local loadingContainer
    local progressBarBg
    local progressBarFill
    local progressFillStroke1
    local progressFillStroke2
    local progressPct
    local statusText
    local logLabel
    local spinnerFrame

    local glitchConn
    local loadingRunning  = false
    local guiDestroyed    = false

    -- ---------------------------------------------------------------------
    -- ROOT GUI (fallback CoreGui → PlayerGui)
    -- ---------------------------------------------------------------------
    local okCore, coreGuiInstance = pcall(function()
        return CoreGui
    end)

    screenGui = Instance.new("ScreenGui")
    screenGui.Name              = "KEMI_AccessControl"
    screenGui.ResetOnSpawn      = false
    screenGui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset    = true
    screenGui.DisplayOrder      = 9999

    if okCore and coreGuiInstance then
        local okParent = pcall(function() screenGui.Parent = coreGuiInstance end)
        if not okParent then
            screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end
    else
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    -- ---------------------------------------------------------------------
    -- MAIN FRAME
    -- ---------------------------------------------------------------------
    mainFrame = Instance.new("Frame")
    mainFrame.Name                  = "MainFrame"
    mainFrame.AnchorPoint           = Vector2.new(0.5, 0.5)
    mainFrame.Position              = UDim2.new(0.5, 0, 0.55, 0)
    mainFrame.Size                  = UDim2.new(0, 420, 0, 260)
    mainFrame.BackgroundColor3      = THEME.BG
    mainFrame.BackgroundTransparency= 1
    mainFrame.BorderSizePixel       = 0
    mainFrame.Parent                = screenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent       = mainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.ApplyStrokeMode  = Enum.ApplyStrokeMode.Border
    mainStroke.Color            = THEME.NEON
    mainStroke.Thickness        = 1.5
    mainStroke.Transparency     = 0.15
    mainStroke.Parent           = mainFrame

    for i, alpha in ipairs({0.35, 0.55, 0.75}) do
        local glow = Instance.new("UIStroke")
        glow.ApplyStrokeMode  = Enum.ApplyStrokeMode.Border
        glow.Color            = THEME.NEON
        glow.Thickness        = 3 + (i - 1) * 2
        glow.Transparency     = alpha
        glow.Parent           = mainFrame
    end

    -- Header bar
    local header = Instance.new("Frame")
    header.Name               = "Header"
    header.Size               = UDim2.new(1, 0, 0, 26)
    header.BackgroundColor3   = THEME.BG_HEADER
    header.BackgroundTransparency = 0.2
    header.BorderSizePixel    = 0
    header.Parent             = mainFrame
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 12)
    headerCorner.Parent       = header

    local headerTitle = Instance.new("TextLabel")
    headerTitle.Size               = UDim2.new(1, -20, 1, 0)
    headerTitle.Position           = UDim2.new(0, 10, 0, 0)
    headerTitle.BackgroundTransparency = 1
    headerTitle.Text               = "KEMI // ACCESS CONTROL"
    headerTitle.TextColor3         = THEME.NEON
    headerTitle.Font               = Enum.Font.GothamBold
    headerTitle.TextSize           = 12
    headerTitle.TextXAlignment     = Enum.TextXAlignment.Left
    headerTitle.Parent             = header

    -- WELCOME title
    welcomeTitle = Instance.new("TextLabel")
    welcomeTitle.Size               = UDim2.new(1, 0, 0, 40)
    welcomeTitle.Position           = UDim2.new(0, 0, 0, 44)
    welcomeTitle.BackgroundTransparency = 1
    welcomeTitle.Text               = "WELCOME"
    welcomeTitle.TextColor3         = Color3.fromRGB(245, 245, 245)
    welcomeTitle.Font               = Enum.Font.GothamBold
    welcomeTitle.TextSize           = 32
    welcomeTitle.Parent             = mainFrame

    welcomeSubtitle = Instance.new("TextLabel")
    welcomeSubtitle.Size               = UDim2.new(1, 0, 0, 20)
    welcomeSubtitle.Position           = UDim2.new(0, 0, 0, 86)
    welcomeSubtitle.BackgroundTransparency = 1
    welcomeSubtitle.Text               = "Script by KEMI"
    welcomeSubtitle.TextColor3         = THEME.NEON
    welcomeSubtitle.Font               = Enum.Font.Gotham
    welcomeSubtitle.TextSize           = 13
    welcomeSubtitle.Parent             = mainFrame

    -- Glitch text
    glitchLabel = Instance.new("TextLabel")
    glitchLabel.Size               = UDim2.new(1, -30, 0, 22)
    glitchLabel.Position           = UDim2.new(0, 15, 0, 118)
    glitchLabel.BackgroundTransparency = 1
    glitchLabel.Text               = ""
    glitchLabel.TextColor3         = THEME.TEXT_DIM
    glitchLabel.Font               = Enum.Font.Code
    glitchLabel.TextSize           = 12
    glitchLabel.Parent             = mainFrame

    -- Continue button
    continueBtn = Instance.new("TextButton")
    continueBtn.Size                = UDim2.new(0, 220, 0, 38)
    continueBtn.AnchorPoint         = Vector2.new(0.5, 0)
    continueBtn.Position            = UDim2.new(0.5, 0, 0, 200)
    continueBtn.BackgroundColor3    = Color3.fromRGB(10, 30, 45)
    continueBtn.BorderSizePixel     = 0
    continueBtn.Text                = "CONTINUE TO SCRIPT"
    continueBtn.TextColor3          = THEME.NEON
    continueBtn.Font                = Enum.Font.GothamBold
    continueBtn.TextSize            = 13
    continueBtn.AutoButtonColor     = false
    continueBtn.Active              = false
    continueBtn.Parent              = mainFrame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent       = continueBtn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    btnStroke.Color           = THEME.NEON
    btnStroke.Thickness       = 1.3
    btnStroke.Transparency    = 0.25
    btnStroke.Parent          = continueBtn

    continueBtn.MouseEnter:Connect(function()
        if continueBtn.Active then
            TweenService:Create(continueBtn, TweenInfo.new(0.15),
                { BackgroundColor3 = Color3.fromRGB(15, 45, 65) }):Play()
        end
    end)
    continueBtn.MouseLeave:Connect(function()
        if continueBtn.Active then
            TweenService:Create(continueBtn, TweenInfo.new(0.15),
                { BackgroundColor3 = Color3.fromRGB(10, 30, 45) }):Play()
        end
    end)

    -- ---------------------------------------------------------------------
    -- LOADING CONTAINER (hidden)
    -- ---------------------------------------------------------------------
    loadingContainer = Instance.new("Frame")
    loadingContainer.Name               = "LoadingContainer"
    loadingContainer.Size               = UDim2.new(1, -40, 0, 150)
    loadingContainer.Position           = UDim2.new(0, 20, 0, 100)
    loadingContainer.BackgroundTransparency = 1
    loadingContainer.Visible            = false
    loadingContainer.Parent             = mainFrame

    local loadTitle = Instance.new("TextLabel")
    loadTitle.Size               = UDim2.new(1, 0, 0, 20)
    loadTitle.BackgroundTransparency = 1
    loadTitle.Text               = "LOADING SCRIPT..."
    loadTitle.TextColor3         = THEME.NEON
    loadTitle.Font               = Enum.Font.GothamBold
    loadTitle.TextSize           = 12
    loadTitle.TextXAlignment     = Enum.TextXAlignment.Left
    loadTitle.Parent             = loadingContainer

    -- Progress bar background
    progressBarBg = Instance.new("Frame")
    progressBarBg.Size                = UDim2.new(1, 0, 0, 10)
    progressBarBg.Position            = UDim2.new(0, 0, 0, 30)
    progressBarBg.BackgroundColor3    = Color3.fromRGB(40, 15, 22)
    progressBarBg.BorderSizePixel     = 0
    progressBarBg.Parent              = loadingContainer
    local pbCorner = Instance.new("UICorner")
    pbCorner.CornerRadius = UDim.new(1, 0)
    pbCorner.Parent       = progressBarBg

    local pbBgStroke = Instance.new("UIStroke")
    pbBgStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    pbBgStroke.Color           = THEME.NEON
    pbBgStroke.Thickness       = 1
    pbBgStroke.Transparency    = 0.55
    pbBgStroke.Parent          = progressBarBg

    -- Progress bar fill
    progressBarFill = Instance.new("Frame")
    progressBarFill.Name              = "Fill"
    progressBarFill.Size              = UDim2.new(0, 0, 1, 0)
    progressBarFill.BackgroundColor3  = THEME.NEON
    progressBarFill.BorderSizePixel   = 0
    progressBarFill.Parent            = progressBarBg
    local pfCorner = Instance.new("UICorner")
    pfCorner.CornerRadius = UDim.new(1, 0)
    pfCorner.Parent       = progressBarFill

    progressFillStroke1 = Instance.new("UIStroke")
    progressFillStroke1.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    progressFillStroke1.Color           = THEME.NEON
    progressFillStroke1.Thickness       = 2
    progressFillStroke1.Transparency    = 0.4
    progressFillStroke1.Parent          = progressBarFill

    progressFillStroke2 = Instance.new("UIStroke")
    progressFillStroke2.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    progressFillStroke2.Color           = THEME.NEON
    progressFillStroke2.Thickness       = 4
    progressFillStroke2.Transparency    = 0.75
    progressFillStroke2.Parent          = progressBarFill

    -- Percentage text
    progressPct = Instance.new("TextLabel")
    progressPct.Size               = UDim2.new(0, 80, 0, 14)
    progressPct.AnchorPoint        = Vector2.new(1, 0)
    progressPct.Position           = UDim2.new(1, 0, 0, 46)
    progressPct.BackgroundTransparency = 1
    progressPct.Text               = "0.0%"
    progressPct.TextColor3         = THEME.NEON
    progressPct.Font               = Enum.Font.Code
    progressPct.TextSize           = 11
    progressPct.TextXAlignment     = Enum.TextXAlignment.Right
    progressPct.Parent             = loadingContainer

    -- Status text
    statusText = Instance.new("TextLabel")
    statusText.Size               = UDim2.new(1, 0, 0, 16)
    statusText.Position           = UDim2.new(0, 0, 0, 64)
    statusText.BackgroundTransparency = 1
    statusText.Text               = "Initializing..."
    statusText.TextColor3         = THEME.TEXT_DIM
    statusText.Font               = Enum.Font.Gotham
    statusText.TextSize           = 11
    statusText.TextXAlignment     = Enum.TextXAlignment.Left
    statusText.Parent             = loadingContainer

    -- Log label
    logLabel = Instance.new("TextLabel")
    logLabel.Size               = UDim2.new(1, 0, 0, 40)
    logLabel.Position           = UDim2.new(0, 0, 0, 86)
    logLabel.BackgroundTransparency = 1
    logLabel.Text               = ""
    logLabel.TextColor3         = Color3.fromRGB(140, 200, 200)
    logLabel.Font               = Enum.Font.Code
    logLabel.TextSize           = 10
    logLabel.TextWrapped        = true
    logLabel.TextXAlignment     = Enum.TextXAlignment.Left
    logLabel.TextYAlignment     = Enum.TextYAlignment.Top
    logLabel.Parent             = loadingContainer

    -- Spinner (small square rotated per step)
    spinnerFrame = Instance.new("Frame")
    spinnerFrame.Size             = UDim2.new(0, 10, 0, 10)
    spinnerFrame.Position         = UDim2.new(1, -12, 0, 0)
    spinnerFrame.AnchorPoint      = Vector2.new(1, 0)
    spinnerFrame.BackgroundColor3 = THEME.NEON
    spinnerFrame.BorderSizePixel  = 0
    spinnerFrame.Rotation         = 0
    spinnerFrame.Parent           = loadingContainer
    local spinCorner = Instance.new("UICorner")
    spinCorner.CornerRadius = UDim.new(0, 3)
    spinCorner.Parent       = spinnerFrame

    -- ---------------------------------------------------------------------
    -- ENTRANCE ANIMATION
    -- ---------------------------------------------------------------------
    mainFrame.Size       = UDim2.new(0, 420 * 0.85, 0, 260 * 0.85)
    mainFrame.Position   = UDim2.new(0.5, 0, 0.60, 0)

    TweenService:Create(mainFrame,
        TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {
            Size     = UDim2.new(0, 420, 0, 260),
            Position = UDim2.new(0.5, 0, 0.5, 0),
        }
    ):Play()

    TweenService:Create(mainFrame, TweenInfo.new(0.45),
        { BackgroundTransparency = 0.1 }):Play()

    -- Aktifkan tombol setelah entrance selesai
    task.delay(0.7, function()
        if guiDestroyed then return end
        if continueBtn and continueBtn.Parent then
            continueBtn.Active = true
        end
    end)

    -- ---------------------------------------------------------------------
    -- GLITCH TEXT LOOP (throttled)
    -- ---------------------------------------------------------------------
    local GLITCH_DURATION = 2.4
    local glitchStart     = tick()
    local lastGlitchTick  = 0
    local glitchSettled   = false

    glitchConn = RunService.RenderStepped:Connect(function()
        if guiDestroyed or not glitchLabel or not glitchLabel.Parent then
            if glitchConn then glitchConn:Disconnect() glitchConn = nil end
            return
        end

        local now = tick()
        if now - lastGlitchTick < 0.09 then return end
        lastGlitchTick = now

        -- Setelah durasi, settle ke "SYSTEM READY"
        if not glitchSettled and (now - glitchStart) >= GLITCH_DURATION then
            glitchSettled = true
            glitchLabel.Text = "> SYSTEM READY"
            glitchLabel.TextColor3 = THEME.OK
            if glitchConn then glitchConn:Disconnect() glitchConn = nil end
            return
        end

        local target = "> SYSTEM READY"
        local len = #target
        local out = {}
        for i = 1, len do
            if math.random() < 0.35 then
                local idx = math.random(1, #GLITCH_CHARS)
                out[i] = GLITCH_CHARS:sub(idx, idx)
            else
                out[i] = target:sub(i, i)
            end
        end
        glitchLabel.Text = table.concat(out)
        glitchLabel.TextColor3 = Color3.fromRGB(
            200 + math.random(-40, 40),
            200 + math.random(-40, 40),
            200 + math.random(-40, 40)
        )
    end)

    -- ---------------------------------------------------------------------
    -- LOADING PROCESS
    -- ---------------------------------------------------------------------
    local STATUS_MESSAGES = {
        "Initializing core modules...",
        "Fetching script from remote...",
        "Verifying integrity...",
        "Loading dependencies...",
        "Patching environment...",
        "Establishing secure channel...",
        "Compiling bytecode...",
        "Finalizing...",
    }

    local LOG_LINES = {
        "[OK]   core.modules.loaded",
        "[OK]   remote.connection.established",
        "[WARN] latency spike detected, retrying...",
        "[OK]   channel.secure",
        "[OK]   integrity.hash.verified",
        "[INFO] buffer.allocated",
        "[OK]   bytecode.compiled",
    }

    local function startLoadingProcess()
        if loadingRunning then return end
        loadingRunning = true

        -- Sembunyikan title & subtitle dengan fade
        TweenService:Create(welcomeTitle, TweenInfo.new(0.3),
            { TextTransparency = 1 }):Play()
        TweenService:Create(welcomeSubtitle, TweenInfo.new(0.3),
            { TextTransparency = 1 }):Play()

        -- Sembunyikan tombol continue (fade + slide)
        continueBtn.Active = false
        TweenService:Create(continueBtn, TweenInfo.new(0.3),
            { BackgroundTransparency = 0.9, TextTransparency = 1 }):Play()

        -- Tampilkan loading container
        loadingContainer.Visible = true
        loadingContainer.BackgroundTransparency = 1

        -- Animasi fade-in tiap elemen
        task.wait(0.25)

        -- Durasi random 6.0 - 12.0 detik
        local totalDuration = math.random(60, 120) / 10

        local progress       = 0
        local stepCount      = 0
        local startTime      = tick()
        local nextStatusTick = 0
        local nextLogTick    = 0
        local statusIdx      = 1
        local logIdx         = 1
        local spinnerAngle   = 0

        while progress < 100 do
            -- hitung progress berdasarkan waktu + jitter
            local elapsed    = tick() - startTime
            local timeRatio  = math.clamp(elapsed / totalDuration, 0, 1)
            local targetPct  = timeRatio * 100

            -- Jitter: kadang naik cepat, kadang freeze
            stepCount = stepCount + 1

            if math.random() < 0.18 then
                -- freeze sebentar
                task.wait(math.random(20, 60) / 100)
            else
                local inc = math.random(1, 5) / 10
                progress = progress + inc
            end

            -- Samakan dengan targetPct agar tidak melenceng jauh dari durasi
            if progress > targetPct + 3 then
                progress = math.max(targetPct - 1, 0)
            end

            if progress > 100 then progress = 100 end

            -- Update bar + teks persen
            if progressBarFill and progressBarFill.Parent then
                progressBarFill.Size = UDim2.new(progress / 100, 0, 1, 0)
            end
            if progressPct and progressPct.Parent then
                progressPct.Text = string.format("%.1f%%", progress)
            end

            -- Spinner rotate
            if spinnerFrame and spinnerFrame.Parent then
                spinnerAngle = (spinnerAngle + 25) % 360
                spinnerFrame.Rotation = spinnerAngle
            end

            -- Ganti status text
            if tick() - nextStatusTick >= (math.random(8, 15) / 10) then
                nextStatusTick = tick()
                statusIdx = statusIdx + 1
                if statusIdx > #STATUS_MESSAGES then statusIdx = 1 end
                if statusText and statusText.Parent then
                    statusText.Text = STATUS_MESSAGES[statusIdx]
                end
            end

            -- Ganti log
            if tick() - nextLogTick >= (math.random(6, 12) / 10) then
                nextLogTick = tick()
                local line = LOG_LINES[math.random(1, #LOG_LINES)]
                if logLabel and logLabel.Parent then
                    local cur = logLabel.Text
                    logLabel.Text = line .. "\n" .. cur
                    if #logLabel.Text > 120 then
                        logLabel.Text = logLabel.Text:sub(1, 120)
                    end
                end
            end

            task.wait(math.random(3, 12) / 100)
        end

        -- Finalisasi visual
        if progressBarFill and progressBarFill.Parent then
            progressBarFill.Size = UDim2.new(1, 0, 1, 0)
        end
        if progressPct and progressPct.Parent then
            progressPct.Text = "100.0%"
        end
        if statusText and statusText.Parent then
            statusText.Text = "LOADING COMPLETE"
            statusText.TextColor3 = THEME.OK
        end

        task.wait(0.4)

        -- ===== LOADSTRING SCRIPT UTAMA =====
        if statusText and statusText.Parent then
            statusText.Text = "EXECUTING SCRIPT..."
            statusText.TextColor3 = THEME.NEON
        end

        local success, result
        success, result = pcall(function()
            local source = game:HttpGet(MAIN_URL)
            if type(source) ~= "string" or #source < 10 then
                error("Empty or invalid source from URL")
            end
            local fn = loadstring(source)
            if not fn then
                error("loadstring returned nil")
            end
            return fn()
        end)

        if success then
            if statusText and statusText.Parent then
                statusText.Text = "SCRIPT LOADED"
                statusText.TextColor3 = THEME.OK
            end

            task.wait(0.5)

            -- Fade-out semua
            local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad)
            TweenService:Create(mainFrame, fadeInfo,
                { BackgroundTransparency = 1 }):Play()

            -- Fade-out elemen
            for _, inst in ipairs(mainFrame:GetDescendants()) do
                if inst:IsA("TextLabel") or inst:IsA("TextButton") then
                    pcall(function()
                        TweenService:Create(inst, fadeInfo, { TextTransparency = 1 }):Play()
                    end)
                end
            end

            task.wait(0.55)

            guiDestroyed = true
            if glitchConn then glitchConn:Disconnect() glitchConn = nil end
            if screenGui and screenGui.Parent then
                pcall(function() screenGui:Destroy() end)
            end
        else
            -- Tampilkan error
            if statusText and statusText.Parent then
                statusText.Text = "LOAD FAILED"
                statusText.TextColor3 = THEME.ERR
            end
            if logLabel and logLabel.Parent then
                logLabel.Text = "[ERR] " .. tostring(result)
                logLabel.TextColor3 = THEME.ERR
            end

            -- Aktifkan tombol continue sebagai retry
            loadingRunning = false
            continueBtn.Active = true
            continueBtn.Text = "RETRY"
            TweenService:Create(continueBtn, TweenInfo.new(0.3),
                { BackgroundTransparency = 0, TextTransparency = 0 }):Play()
        end
    end

    -- ---------------------------------------------------------------------
    -- TOMBOL CONTINUE
    -- ---------------------------------------------------------------------
    continueBtn.MouseButton1Click:Connect(function()
        if not continueBtn.Active then return end
        if loadingRunning then return end
        startLoadingProcess()
    end)
end

-- ============================================================================
createWelcomeScreen()
-- ============================================================================
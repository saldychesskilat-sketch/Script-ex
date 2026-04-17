--[[
    Roblox Executor dengan Key System
    Script ini akan menampilkan GUI untuk memasukkan key.
    Jika key yang dimasukkan benar, maka akan langsung menjalankan script utama.
    
    Cara Penggunaan:
    1. Jalankan script ini di executor Roblox Anda.
    2. Masukkan key pada kolom yang tersedia.
    3. Tekan tombol "Verifikasi".
    4. Jika key benar, script utama akan dijalankan secara otomatis.
]]--

-- ================== KONFIGURASI ==================
local Configuration = {
    CorrectKey = "kemilinux22",  -- Ganti dengan key rahasia Anda!
    GuiTitle = "Key System",
    MainScript = "https://raw.githubusercontent.com/saldychesskilat-sketch/Script-ex/refs/heads/main/chai_lua_20260417_a77e37.lua"
}

-- ================== MEMBUAT GUI ==================
-- Referensi GUI: Painel com Key - Lua Script Roblox untuk Executor (Xeno, Delta, Arceus etc.)[reference:0]

local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Membuat ScreenGui utama
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "KeySystemGui"
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Frame utama (panel)
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 350, 0, 250)
mainFrame.Position = UDim2.new(0.5, -175, 0.5, -125)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

-- Judul
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 50)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
titleLabel.Text = Configuration.GuiTitle
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 20
titleLabel.Parent = mainFrame

-- Kotak input key
local keyBox = Instance.new("TextBox")
keyBox.Size = UDim2.new(0.8, 0, 0, 40)
keyBox.Position = UDim2.new(0.1, 0, 0.35, 0)
keyBox.PlaceholderText = "Masukkan Key..."
keyBox.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
keyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
keyBox.Font = Enum.Font.Gotham
keyBox.TextSize = 16
keyBox.ClearTextOnFocus = false
keyBox.Parent = mainFrame

-- Tombol verifikasi
local verifyButton = Instance.new("TextButton")
verifyButton.Size = UDim2.new(0.4, 0, 0, 40)
verifyButton.Position = UDim2.new(0.3, 0, 0.6, 0)
verifyButton.Text = "Verifikasi"
verifyButton.BackgroundColor3 = Color3.fromRGB(0, 150, 200)
verifyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
verifyButton.Font = Enum.Font.GothamBold
verifyButton.TextSize = 16
verifyButton.Parent = mainFrame

-- Label status
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 30)
statusLabel.Position = UDim2.new(0, 0, 0.85, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Menunggu verifikasi..."
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 14
statusLabel.Parent = mainFrame

-- ================== FUNGSI EKSEKUSI SCRIPT UTAMA ==================
-- Referensi: Menggunakan pcall untuk menangani error saat loadstring[reference:1]
local function executeMainScript()
    local success, err = pcall(function()
        loadstring(game:HttpGet(Configuration.MainScript))()
    end)
    
    if success then
        print("Script utama berhasil dijalankan!")
    else
        warn("Gagal menjalankan script utama: " .. tostring(err))
        statusLabel.Text = "Gagal menjalankan script!"
        statusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
    end
end

-- ================== LOGIKA VERIFIKASI ==================
verifyButton.MouseButton1Click:Connect(function()
    local enteredKey = keyBox.Text
    
    if enteredKey == Configuration.CorrectKey then
        -- Key valid
        statusLabel.Text = "Key valid! Menjalankan script..."
        statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        
        -- Hapus GUI
        screenGui:Destroy()
        
        -- Jalankan script utama
        executeMainScript()
    else
        -- Key salah
        statusLabel.Text = "Key salah! Coba lagi."
        statusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
        keyBox.Text = ""  -- Kosongkan input
    end
end)
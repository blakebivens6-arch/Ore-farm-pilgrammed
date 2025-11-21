-- OreFarmGUI.lua
-- Simple GUI for OreFarm.lua (assumes OreFarm module loaded into _G.OreFarm or via loadstring)

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local task = task

-- fetch engine
local OreFarm = _G.OreFarm
if not OreFarm then
    -- Try to require if module placed in ReplicatedStorage or similar (optional)
    local ok, m = pcall(function() return _G.OreFarm end)
    if ok and m then OreFarm = m end
end

if not OreFarm then
    warn("OreFarm engine not found. Please load OreFarm.lua before the GUI.")
    -- create fallback
    OreFarm = {
        Enabled = false,
        SelectedLocation = "BearIsland",
        SelectedOreType = nil,
        TeleportDelay = 1.5,
        MINE_DELAY = 1.4,
        AUTO_RANDOM_FALLBACK = true,
        ScanAllOreTypes = function() return {} end,
        GetAvailableLocations = function() return {} end
    }
    _G.OreFarm = OreFarm
end

-- build GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "OreFarmGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 360, 0, 420)
frame.Position = UDim2.new(0, 12, 0.08, 0)
frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
frame.BorderSizePixel = 0

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1,0,0,34)
title.BackgroundTransparency = 1
title.Text = "Ore Farm"
title.Font = Enum.Font.SourceSansBold
title.TextSize = 20
title.TextColor3 = Color3.fromRGB(230,230,230)

-- Location dropdown (textbox)
local locLabel = Instance.new("TextLabel", frame)
locLabel.Position = UDim2.new(0.05,0,0.12,0); locLabel.Size = UDim2.new(0.9,0,0,20)
locLabel.BackgroundTransparency = 1; locLabel.Text = "Location:"; locLabel.TextColor3 = Color3.fromRGB(200,200,200)

local locBox = Instance.new("TextBox", frame)
locBox.Position = UDim2.new(0.05,0,0.17,0); locBox.Size = UDim2.new(0.9,0,0,30)
locBox.PlaceholderText = tostring(OreFarm.SelectedLocation or "BearIsland")
locBox.Text = OreFarm.SelectedLocation or ""

-- Ore dropdown (simple textbox)
local oreLabel = Instance.new("TextLabel", frame)
oreLabel.Position = UDim2.new(0.05,0,0.28,0); oreLabel.Size = UDim2.new(0.9,0,0,20)
oreLabel.BackgroundTransparency = 1; oreLabel.Text = "Ore Type:"; oreLabel.TextColor3 = Color3.fromRGB(200,200,200)

local oreBox = Instance.new("TextBox", frame)
oreBox.Position = UDim2.new(0.05,0,0.33,0); oreBox.Size = UDim2.new(0.9,0,0,30)
oreBox.PlaceholderText = "Select ore type (or leave blank for random)"
oreBox.Text = OreFarm.SelectedOreType or ""

-- Teleport delay
local tpLabel = Instance.new("TextLabel", frame)
tpLabel.Position = UDim2.new(0.05,0,0.45,0); tpLabel.Size = UDim2.new(0.9,0,0,18)
tpLabel.BackgroundTransparency = 1; tpLabel.Text = "Teleport Delay (s):"; tpLabel.TextColor3 = Color3.fromRGB(200,200,200)

local tpBox = Instance.new("TextBox", frame)
tpBox.Position = UDim2.new(0.05,0,0.50,0); tpBox.Size = UDim2.new(0.3,0,0,28)
tpBox.Text = tostring(OreFarm.TeleportDelay)

-- Fallback toggle
local fallbackBtn = Instance.new("TextButton", frame)
fallbackBtn.Position = UDim2.new(0.37,0,0.50,0); fallbackBtn.Size = UDim2.new(0.58,0,0,28)
fallbackBtn.Text = (OreFarm.AUTO_RANDOM_FALLBACK and "Fallback: ON" or "Fallback: OFF")
fallbackBtn.Font = Enum.Font.SourceSans; fallbackBtn.TextSize = 14

-- Start/Stop
local startBtn = Instance.new("TextButton", frame)
startBtn.Position = UDim2.new(0.05,0,0.72,0); startBtn.Size = UDim2.new(0.4,0,0,34)
startBtn.Text = "Start"
startBtn.Font = Enum.Font.SourceSans; startBtn.TextSize = 16; startBtn.BackgroundColor3 = Color3.fromRGB(60,150,60)

local stopBtn = Instance.new("TextButton", frame)
stopBtn.Position = UDim2.new(0.55,0,0.72,0); stopBtn.Size = UDim2.new(0.4,0,0,34)
stopBtn.Text = "Stop"
stopBtn.Font = Enum.Font.SourceSans; stopBtn.TextSize = 16; stopBtn.BackgroundColor3 = Color3.fromRGB(150,60,60)

-- Refresh types
local refreshBtn = Instance.new("TextButton", frame)
refreshBtn.Position = UDim2.new(0.05,0,0.80,0); refreshBtn.Size = UDim2.new(0.9,0,0,30)
refreshBtn.Text = "Refresh Ore Types"; refreshBtn.Font = Enum.Font.SourceSans; refreshBtn.TextSize = 14

-- Status
local status = Instance.new("TextLabel", frame)
status.Position = UDim2.new(0.05,0,0.90,0); status.Size = UDim2.new(0.9,0,0,40)
status.BackgroundTransparency = 1; status.TextWrapped = true
status.Text = "Status: Idle"; status.TextColor3 = Color3.fromRGB(200,200,200)

local function refreshOreTypesToDropdown()
    local types = {}
    local ok, t = pcall(function() return OreFarm.ScanAllOreTypes() end)
    if ok and type(t) == "table" and #t > 0 then
        types = t
    else
        types = OreFarm.KNOWN_ORES or {}
    end
    -- show first few in placeholder
    oreBox.PlaceholderText = (#types>0 and table.concat(types, ", ") or "No types found")
end

startBtn.MouseButton1Click:Connect(function()
    OreFarm.SelectedLocation = (locBox.Text ~= "" and locBox.Text) or OreFarm.SelectedLocation
    OreFarm.SelectedOreType = (oreBox.Text ~= "" and oreBox.Text) or OreFarm.SelectedOreType
    local tv = tonumber(tpBox.Text)
    if tv and tv > 0 then OreFarm.TeleportDelay = tv end
    OreFarm.AUTO_RANDOM_FALLBACK = (fallbackBtn.Text == "Fallback: ON")
    OreFarm.Enabled = true
    status.Text = "Status: Running | Loc: "..tostring(OreFarm.SelectedLocation).." | Ore: "..tostring(OreFarm.SelectedOreType)
end)

stopBtn.MouseButton1Click:Connect(function()
    OreFarm.Enabled = false
    status.Text = "Status: Stopped"
end)

refreshBtn.MouseButton1Click:Connect(function()
    refreshOreTypesToDropdown()
    status.Text = "Status: Ore list refreshed"
end)

fallbackBtn.MouseButton1Click:Connect(function()
    OreFarm.AUTO_RANDOM_FALLBACK = not OreFarm.AUTO_RANDOM_FALLBACK
    fallbackBtn.Text = ("Fallback: " .. (OreFarm.AUTO_RANDOM_FALLBACK and "ON" or "OFF"))
end)

-- initial populate
task.spawn(refreshOreTypesToDropdown)

return screenGui


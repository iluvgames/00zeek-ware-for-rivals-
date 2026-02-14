--[[ 00zeek.ware ]]--
-- \x4C\x6F\x67\x69\x63\x3A\x20\x55\x6E\x6E\x61\x6D\x65\x64
-- \x4F\x70\x74\x69\x6D\x69\x7A\x61\x74\x69\x6F\x6E\x3A\x20\x52\x69\x76\x61\x6C\x73

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- // SOUND DATABASE
local HitSounds = {
    ["Rust Crunch"] = "rbxassetid://5043536230",
    ["Classic Bell"] = "rbxassetid://160433791",
    ["COD Marker"] = "rbxassetid://160432331",
    ["Metal Ping"] = "rbxassetid://6831002221"
}

-- // SETTINGS
local Settings = {
    Combat = {
        LegitEnabled = false, Smoothness = 0.1, LegitPart = "Head",
        SilentEnabled = false, HitChance = 100, SilentPart = "HumanoidRootPart",
        RageEnabled = false, Wallbang = false, SafeMode = true,
        HitSoundEnabled = true, HitSoundVolume = 3, SelectedSound = "Rust Crunch",
        WalkSpeed = 16, JumpPower = 50, InfJump = false, 
        FlyEnabled = false, FlyKey = Enum.KeyCode.F, FlySpeed = 50
    },
    Visuals = {
        EspEnabled = false, Names = false, Distance = false, 
        Boxes = false, Skeletons = false, HealthBar = false,
        TracersEnabled = false, TracerColor = Color3.fromRGB(255, 255, 255),
        TracerThickness = 2, TracerDuration = 2
    },
    UI = {
        MenuKey = Enum.KeyCode.P,
        MainColor = Color3.fromRGB(18, 18, 22),
        AccentColor = Color3.fromRGB(0, 162, 255),
        FontColor = Color3.fromRGB(255, 255, 255),
        Streamproof = false
    }
}

local Connections = {}

-- // --- UI ELEMENT CREATORS ---
local function CreateRoundedFrame(parent, size, pos, color)
    local f = Instance.new("Frame", parent)
    f.Size = size; f.Position = pos; f.BackgroundColor3 = color; f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    return f
end

local function AddToggle(parent, text, callback)
    local ToggleBtn = Instance.new("TextButton", parent)
    ToggleBtn.Size = UDim2.new(1, -20, 0, 35); ToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    ToggleBtn.Text = "  " .. text; ToggleBtn.TextColor3 = Settings.UI.FontColor
    ToggleBtn.Font = "GothamSemibold"; ToggleBtn.TextSize = 13; ToggleBtn.TextXAlignment = "Left"
    Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 6)
    local Status = Instance.new("Frame", ToggleBtn)
    Status.Size = UDim2.new(0, 20, 0, 20); Status.Position = UDim2.new(1, -25, 0.5, -10)
    Status.BackgroundColor3 = Color3.fromRGB(50, 50, 55); Instance.new("UICorner", Status).CornerRadius = UDim.new(1, 0)
    local Enabled = false
    ToggleBtn.MouseButton1Click:Connect(function()
        Enabled = not Enabled; Status.BackgroundColor3 = Enabled and Settings.UI.AccentColor or Color3.fromRGB(50, 50, 55)
        callback(Enabled)
    end)
end

local function AddSlider(parent, text, min, max, default, callback)
    local Container = Instance.new("Frame", parent); Container.Size = UDim2.new(1, -20, 0, 45); Container.BackgroundTransparency = 1
    local Label = Instance.new("TextLabel", Container); Label.Size = UDim2.new(1, 0, 0, 20); Label.Text = text .. ": " .. default; Label.TextColor3 = Settings.UI.FontColor; Label.BackgroundTransparency = 1; Label.Font = "GothamSemibold"; Label.TextSize = 12; Label.TextXAlignment = "Left"
    local Bar = Instance.new("TextButton", Container); Bar.Size = UDim2.new(1, 0, 0, 6); Bar.Position = UDim2.new(0, 0, 0, 25); Bar.BackgroundColor3 = Color3.fromRGB(45, 45, 50); Bar.Text = ""; Instance.new("UICorner", Bar)
    local Fill = Instance.new("Frame", Bar); Fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0); Fill.BackgroundColor3 = Settings.UI.AccentColor; Instance.new("UICorner", Fill)
    Bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local conn; conn = UserInputService.InputChanged:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseMovement then
                    local p = math.clamp((i.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
                    local v = math.floor(min + (max - min) * p)
                    Fill.Size = UDim2.new(p, 0, 1, 0); Label.Text = text .. ": " .. v; callback(v)
                end
            end)
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then conn:Disconnect() end end)
        end
    end)
end

local function AddDropdown(parent, text, options, callback)
    local DropBtn = Instance.new("TextButton", parent)
    DropBtn.Size = UDim2.new(1, -20, 0, 35); DropBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    DropBtn.Text = "  " .. text; DropBtn.TextColor3 = Settings.UI.FontColor; DropBtn.Font = "GothamSemibold"; DropBtn.TextXAlignment = "Left"
    Instance.new("UICorner", DropBtn).CornerRadius = UDim.new(0, 6)
    local count = 1
    DropBtn.MouseButton1Click:Connect(function()
        count = count + 1; if count > #options then count = 1 end
        DropBtn.Text = "  " .. text .. ": " .. options[count]
        callback(options[count])
    end)
end

-- // --- HITSOUND LOGIC ---
local function PlayHitEffect()
    if not Settings.Combat.HitSoundEnabled then return end
    local Sound = Instance.new("Sound", SoundService)
    Sound.SoundId = HitSounds[Settings.Combat.SelectedSound]
    Sound.Volume = Settings.Combat.HitSoundVolume
    Sound:Play(); Sound.Ended:Connect(function() Sound:Destroy() end)
end

local function MonitorHealth(player)
    if player == LocalPlayer then return end
    player.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid")
        local lastHealth = hum.Health
        hum.HealthChanged:Connect(function(newHealth)
            if newHealth < lastHealth then PlayHitEffect() end
            lastHealth = newHealth
        end)
    end)
end

-- // --- UNNAMED SILENT AIM ---
local mt = getrawmetatable(game); local oldIndex = mt.__index; setreadonly(mt, false)
mt.__index = newcclosure(function(self, k)
    if not checkcaller() and Settings.Combat.SilentEnabled and self == Mouse and (k == "Hit" or k == "Target") then
        local target, closest = nil, math.huge
        for _, v in pairs(Players:GetPlayers()) do
            if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                local p = v.Character:FindFirstChild(Settings.Combat.SilentPart)
                if p then
                    local screenPos, on = Camera:WorldToViewportPoint(p.Position)
                    local dist = (Vector2.new(Mouse.X, Mouse.Y) - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
                    if dist < closest then target = v; closest = dist end
                end
            end
        end
        if target and math.random(1, 100) <= Settings.Combat.HitChance then
            local p = target.Character[Settings.Combat.SilentPart]; return (k == "Hit" and p.CFrame or p)
        end
    end
    return oldIndex(self, k)
end)
setreadonly(mt, true)

-- // --- MOVEMENT CONTROL ---
table.insert(Connections, RunService.Stepped:Connect(function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        local H = LocalPlayer.Character.Humanoid
        if Settings.Combat.WalkSpeed > 16 then H.WalkSpeed = Settings.Combat.WalkSpeed end
        if Settings.Combat.JumpPower > 50 then H.JumpPower = Settings.Combat.JumpPower end
    end
end))

-- // --- MAIN UI SETUP ---
local ScreenGui = Instance.new("ScreenGui", LocalPlayer.PlayerGui); ScreenGui.Name = "00zeek.ware"
local MainShadow = Instance.new("ImageLabel", ScreenGui); MainShadow.Size = UDim2.new(0, 520, 0, 480); MainShadow.Position = UDim2.new(0.5, -260, 0.5, -240); MainShadow.BackgroundTransparency = 1; MainShadow.Image = "rbxassetid://1316045217"; MainShadow.ImageColor3 = Color3.new(0,0,0)
local MainFrame = CreateRoundedFrame(MainShadow, UDim2.new(0, 500, 0, 460), UDim2.new(0, 10, 0, 10), Settings.UI.MainColor)
local Sidebar = CreateRoundedFrame(MainFrame, UDim2.new(0, 140, 1, -20), UDim2.new(0, 10, 0, 10), Color3.fromRGB(24, 24, 28))
local TabHolder = Instance.new("Frame", MainFrame); TabHolder.Size = UDim2.new(1, -170, 1, -20); TabHolder.Position = UDim2.new(0, 160, 0, 10); TabHolder.BackgroundTransparency = 1
local Title = Instance.new("TextLabel", Sidebar); Title.Size = UDim2.new(1, 0, 0, 40); Title.BackgroundTransparency = 1; Title.Text = "00zeek.ware"; Title.TextColor3 = Settings.UI.FontColor; Title.Font = "GothamBold"; Title.TextSize = 16

local function AddTab(name, order)
    local Btn = Instance.new("TextButton", Sidebar); Btn.Size = UDim2.new(1, -10, 0, 35); Btn.Position = UDim2.new(0, 5, 0, (order * 40) + 50); Btn.BackgroundColor3 = Color3.fromRGB(35, 35, 40); Btn.Text = name; Btn.TextColor3 = Settings.UI.FontColor; Btn.Font = "GothamSemibold"; Instance.new("UICorner", Btn)
    local Page = Instance.new("ScrollingFrame", TabHolder); Page.Size = UDim2.new(1, 0, 1, 0); Page.Visible = (order == 0); Page.BackgroundTransparency = 1; Page.ScrollBarThickness = 0; Page.CanvasSize = UDim2.new(0,0,2,0)
    local L = Instance.new("UIListLayout", Page); L.Padding = UDim.new(0, 8); L.HorizontalAlignment = "Center"
    Btn.MouseButton1Click:Connect(function() for _, p in pairs(TabHolder:GetChildren()) do if p:IsA("ScrollingFrame") then p.Visible = false end end; Page.Visible = true end)
    return Page
end

local CombatP = AddTab("Combat", 0); local VisualsP = AddTab("Visuals", 1); local SettingsP = AddTab("Settings", 2)

-- // POPULATE TABS
AddToggle(CombatP, "Silent Aim", function(v) Settings.Combat.SilentEnabled = v end)
AddDropdown(CombatP, "HitSound", {"Rust Crunch", "Classic Bell", "COD Marker", "Metal Ping"}, function(v) Settings.Combat.SelectedSound = v end)
AddSlider(CombatP, "Sound Volume", 1, 10, 3, function(v) Settings.Combat.HitSoundVolume = v end)
AddSlider(CombatP, "WalkSpeed", 16, 200, 16, function(v) Settings.Combat.WalkSpeed = v end)
AddToggle(CombatP, "Inf Jump", function(v) Settings.Combat.InfJump = v end)

AddToggle(VisualsP, "Master Visuals", function(v) Settings.Visuals.EspEnabled = v end)
AddToggle(VisualsP, "Skeleton ESP", function(v) Settings.Visuals.Skeletons = v end)

-- Self Destruct & Bypass
local DestructBtn = Instance.new("TextButton", SettingsP); DestructBtn.Size = UDim2.new(1, -20, 0, 35); DestructBtn.BackgroundColor3 = Color3.fromRGB(150, 30, 30); DestructBtn.Text = "SELF DESTRUCT"; DestructBtn.TextColor3 = Color3.new(1,1,1); DestructBtn.Font = "GothamBold"; Instance.new("UICorner", DestructBtn)
DestructBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy(); setreadonly(mt, false); mt.__index = oldIndex; setreadonly(mt, true) end)

local BypassBtn = Instance.new("TextButton", SettingsP); BypassBtn.Size = UDim2.new(1, -20, 0, 35); BypassBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35); BypassBtn.Text = "Initialize Bypass"; BypassBtn.TextColor3 = Color3.new(1,1,1); BypassBtn.Font = "GothamSemibold"; Instance.new("UICorner", BypassBtn)
BypassBtn.MouseButton1Click:Connect(function() BypassBtn.Text = "Patching Rivals..."; task.wait(1.5); BypassBtn.Text = "Bypass Active" end)

-- // --- INITIALIZE ---
for _, p in pairs(Players:GetPlayers()) do MonitorHealth(p) end
Players.PlayerAdded:Connect(MonitorHealth)

UserInputService.InputBegan:Connect(function(i)
    if i.KeyCode == Settings.UI.MenuKey and not Settings.UI.Streamproof then MainShadow.Visible = not MainShadow.Visible
    elseif i.KeyCode == Enum.KeyCode.L and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        Settings.UI.Streamproof = not Settings.UI.Streamproof; MainShadow.Visible = not Settings.UI.Streamproof
    end
end)

-- Dragging
local d, ds, sp
Sidebar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d = true; ds = i.Position; sp = MainShadow.Position end end)
UserInputService.InputChanged:Connect(function(i) if d and i.UserInputType == Enum.UserInputType.MouseMovement then local del = i.Position - ds; MainShadow.Position = UDim2.new(sp.X.Scale, sp.X.Offset + del.X, sp.Y.Scale, sp.Y.Offset + del.Y) end end)
UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then d = false end end)

print("00zeek.ware Final Build Loaded. Toggle: P | Panic: Ctrl+L")

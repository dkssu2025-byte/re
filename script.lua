-- RIVALS Script (Cleaned Syntax & Input Conflict Fix)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local function DetectExecutor()
    local name = (identifyexecutor and identifyexecutor()) or (getexecutorname and getexecutorname()) or "unknown"
    return string.lower(tostring(name))
end

local ExecutorName = DetectExecutor()
local IsSolara = ExecutorName:find("solara") or ExecutorName:find("xeno") or ExecutorName:find("wave")
local ENV = (getgenv and getgenv()) or _G

local HasDrawing = pcall(function()
    local t = Drawing.new("Circle")
    t:Remove()
end)

local function GetUIParent()
    local ok, core = pcall(function() return game:GetService("CoreGui") end)
    if ok and core then
        local test = Instance.new("ScreenGui")
        local parented = pcall(function() test.Parent = core end)
        if parented and test.Parent then test:Destroy() return core end
        test:Destroy()
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local UIParent = GetUIParent()

local Config = {
    ESP = {
        Enabled = true,
        Boxes = true,
        Names = true,
        Health = true,
        Distance = true,
        TeamCheck = true,
        MaxDistance = 600,
        UpdateRate = 1/30,
        Colors = {
            Box = Color3.fromRGB(255, 50, 50),
            Name = Color3.fromRGB(255, 255, 255),
            HealthHigh = Color3.fromRGB(0, 255, 100),
            HealthMid = Color3.fromRGB(255, 200, 0),
            HealthLow = Color3.fromRGB(255, 40, 40),
        },
    },
    Aimbot = {
        Enabled = true,
        ToggleKey = Enum.KeyCode.E,
        FOV = 90,
        Smoothness = 0.22,
        TeamCheck = true,
        TargetPart = "Head",
        Prediction = 0.08,
        ShowFOV = false,
        FOVColor = Color3.fromRGB(0, 255, 200),
        Key = Enum.UserInputType.MouseButton2,
        Humanize = true,
        ReactionMin = 0.04,
        ReactionMax = 0.11,
    },
    SilentAim = {
        Enabled = false,
        TeamCheck = true,
        TargetPart = "Head",
        FOV = 120,
        HitChance = 85,
    },
    Wallbang = {
        Enabled = true,
        MaxExtraDistance = 40,
        OnlyEnemies = true,
    },
    AntiKatana = {
        Enabled = true,
    },
    SkinChanger = {
        Enabled = true,
        Skins = {
            ["Knife"] = "Karambit",
            ["Assault Rifle"] = "AK-47",
            ["Handgun"] = "Blaster",
            ["Revolver"] = "Desert Eagle",
            ["Sniper"] = "Hyper Sniper",
            ["Katana"] = "Lightning Bolt",
            ["Uzi"] = "Electro Uzi",
            ["RPG"] = "Nuke Launcher",
        },
    },
    Sky = {
        Enabled = true,
        Preset = "Space",
        RainbowSpeed = 0.35,
        Lighting = {
            Brightness = 2,
            ClockTime = 14,
            Ambient = Color3.fromRGB(80, 80, 120),
            OutdoorAmbient = Color3.fromRGB(100, 100, 140),
            FogEnd = 2000,
            FogColor = Color3.fromRGB(20, 20, 40),
            GlobalShadows = false,
        },
    },
    Fly = {
        Enabled = false,
        ToggleKey = Enum.KeyCode.U,
        Speed = 60,
        SpeedBoost = 110,
        VerticalSpeed = 50,
    },
    Stealth = {
        Enabled = true,
        NoPrint = false,
        MaxESP = 12,
        RandomSeedJitter = true,
    },
}

if IsSolara then
    Config.SilentAim.Enabled = false
    Config.Wallbang.Enabled = false
    Config.Aimbot.ShowFOV = false
    Config.ESP.UpdateRate = 1/20
end

local DrawingObjects = {}
local AimbotHolding = false
local AimReactionUntil = 0
local LastESPUpdate = 0
local AppliedSkins = {}
local ESPGui = nil
local FlyBodyVel, FlyBodyGyro, FlyConnection
local FlyKeys = {W=false, A=false, S=false, D=false, Space=false, Ctrl=false, Shift=false}

local function SafePrint(...)
    if Config.Stealth.NoPrint then return end
    print(...)
end

local function Rand(a, b)
    return a + (b - a) * math.random()
end

local function IsAlive(plr)
    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function IsEnemy(plr)
    if plr == LocalPlayer then return false end
    if not Config.ESP.TeamCheck and not Config.Aimbot.TeamCheck then return true end
    if not LocalPlayer.Team or not plr.Team then return true end
    return plr.Team ~= LocalPlayer.Team
end

local function WorldToScreen(pos)
    local s, on = Camera:WorldToViewportPoint(pos)
    return Vector2.new(s.X, s.Y), on, s.Z
end

local function GetClosestInFOV(fov, partName, teamCheck)
    local closest, best = nil, fov
    local mouse = UserInputService:GetMouseLocation()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and IsAlive(plr) and (not teamCheck or IsEnemy(plr)) then
            local part = plr.Character and plr.Character:FindFirstChild(partName or "Head")
            if part then
                local sp, on = WorldToScreen(part.Position)
                if on then
                    local d = (sp - mouse).Magnitude
                    if d < best then
                        best = d
                        closest = plr
                    end
                end
            end
        end
    end
    return closest
end

local function HealthColor(ratio)
    local c = Config.ESP.Colors
    if ratio >= 0.7 then return c.HealthHigh end
    if ratio >= 0.3 then return c.HealthMid end
    return c.HealthLow
end

local function EnsureESPGui()
    if ESPGui then return end
    ESPGui = Instance.new("ScreenGui")
    ESPGui.Name = "RivalsESP"
    ESPGui.ResetOnSpawn = false
    ESPGui.IgnoreGuiInset = true
    ESPGui.Parent = UIParent
end

local function CreateESP(plr)
    if DrawingObjects[plr] then return end
    local count = 0
    for _ in pairs(DrawingObjects) do count += 1 end
    if count >= Config.Stealth.MaxESP then return end

    if HasDrawing then
        local box = Drawing.new("Square")
        box.Thickness = 1.3
        box.Filled = false
        box.Color = Config.ESP.Colors.Box
        box.Visible = false

        local name = Drawing.new("Text")
        name.Size = 13
        name.Center = true
        name.Outline = true
        name.Color = Config.ESP.Colors.Name
        name.Visible = false

        local hp = Drawing.new("Text")
        hp.Size = 11
        hp.Center = true
        hp.Outline = true
        hp.Color = Config.ESP.Colors.HealthHigh
        hp.Visible = false

        DrawingObjects[plr] = {Box=box, Name=name, HP=hp, IsGui=false}
    else
        EnsureESPGui()
        local box = Instance.new("Frame")
        box.BackgroundTransparency = 1
        box.BorderSizePixel = 2
        box.BorderColor3 = Config.ESP.Colors.Box
        box.Visible = false
        box.Parent = ESPGui

        local name = Instance.new("TextLabel")
        name.BackgroundTransparency = 1
        name.TextColor3 = Config.ESP.Colors.Name
        name.TextStrokeTransparency = 0.4
        name.Font = Enum.Font.GothamBold
        name.TextSize = 13
        name.Visible = false
        name.Parent = ESPGui

        local hp = Instance.new("TextLabel")
        hp.BackgroundTransparency = 1
        hp.TextColor3 = Config.ESP.Colors.HealthHigh
        hp.TextStrokeTransparency = 0.4
        hp.Font = Enum.Font.GothamBold
        hp.TextSize = 11
        hp.Visible = false
        hp.Parent = ESPGui

        DrawingObjects[plr] = {Box=box, Name=name, HP=hp, IsGui=true}
    end
end

local function RemoveESP(plr)
    local o = DrawingObjects[plr]
    if not o then return end
    for _, key in ipairs({"Box", "Name", "HP"}) do
        local item = o[key]
        if item then
            pcall(function()
                if o.IsGui then item:Destroy() else item:Remove() end
            end)
        end
    end
    DrawingObjects[plr] = nil
end

local function HideESP(obj)
    obj.Box.Visible = false
    obj.Name.Visible = false
    obj.HP.Visible = false
end

local function UpdateESP()
    local now = tick()
    if now - LastESPUpdate < Config.ESP.UpdateRate then return end
    LastESPUpdate = now

    for plr, obj in pairs(DrawingObjects) do
        local char = plr.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        if not Config.ESP.Enabled or not plr.Parent or not IsAlive(plr) or not IsEnemy(plr) or not root or not head or not hum then
            HideESP(obj)
            continue
        end

        local dist = (root.Position - Camera.CFrame.Position).Magnitude
        if dist > Config.ESP.MaxDistance then
            HideESP(obj)
            continue
        end

        local headPos, onScreen = WorldToScreen(head.Position + Vector3.new(0, 0.5, 0))
        local feetPos = WorldToScreen(root.Position - Vector3.new(0, 3, 0))
        if not onScreen then
            HideESP(obj)
            continue
        end

        local height = math.abs(headPos.Y - feetPos.Y)
        local width = height * 0.55
        local ratio = hum.Health / math.max(hum.MaxHealth, 1)
        local nameText = Config.ESP.Distance and ((plr.DisplayName or plr.Name) .. " [" .. math.floor(dist) .. "m]") or (plr.DisplayName or plr.Name)
        local hpText = math.floor(hum.Health) .. " HP"

        if not obj.IsGui then
            obj.Box.Visible = Config.ESP.Boxes
            if Config.ESP.Boxes then
                obj.Box.Size = Vector2.new(width, height)
                obj.Box.Position = Vector2.new(headPos.X - width / 2, headPos.Y)
                obj.Box.Color = Config.ESP.Colors.Box
            end
            obj.Name.Visible = Config.ESP.Names
            if Config.ESP.Names then
                obj.Name.Text = nameText
                obj.Name.Position = Vector2.new(headPos.X, headPos.Y - 16)
                obj.Name.Color = Config.ESP.Colors.Name
            end
            obj.HP.Visible = Config.ESP.Health
            if Config.ESP.Health then
                obj.HP.Text = hpText
                obj.HP.Position = Vector2.new(headPos.X, feetPos.Y + 3)
                obj.HP.Color = HealthColor(ratio)
            end
        else
            obj.Box.Visible = Config.ESP.Boxes
            if Config.ESP.Boxes then
                obj.Box.Size = UDim2.new(0, width, 0, height)
                obj.Box.Position = UDim2.new(0, headPos.X - width / 2, 0, headPos.Y)
                obj.Box.BorderColor3 = Config.ESP.Colors.Box
            end
            obj.Name.Visible = Config.ESP.Names
            if Config.ESP.Names then
                obj.Name.Text = nameText
                obj.Name.Size = UDim2.new(0, 200, 0, 16)
                obj.Name.Position = UDim2.new(0, headPos.X - 100, 0, headPos.Y - 18)
                obj.Name.TextColor3 = Config.ESP.Colors.Name
            end
            obj.HP.Visible = Config.ESP.Health
            

--[[ PAINEL ADMIN V8 ]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TextChatService = game:GetService("TextChatService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local TargetName = ""
local AvatarName = ""
local backroomsActive = false
local backroomsFolder = nil

local function Say(msg)
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        local c = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if c then c:SendAsync(msg) end
    else
        game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(msg, "All")
    end
end

local function findT(n)
    if not n or n == "" then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():sub(1, #n) == n:lower() then return p end
    end
end

local function kill(t)
    if not t or not t.Character then return end
    local root = LocalPlayer.Character.HumanoidRootPart
    local tRoot = t.Character.HumanoidRootPart
    local tool = LocalPlayer.Character:FindFirstChild("Sofa") or LocalPlayer.Backpack:FindFirstChild("Sofa")
    if tool and root and tRoot then
        tool.Parent = LocalPlayer.Character
        Say(";kill")
        local start = tick()
        local c; c = RunService.Heartbeat:Connect(function()
            if tick()-start > 0.4 then c:Disconnect() return end
            root.Velocity = Vector3.new(0, 8000, 0)
            root.RotVelocity = Vector3.new(0, 8000, 0)
            root.CFrame = tRoot.CFrame * CFrame.new(0, 0, 0.5)
        end)
        task.wait(0.4)
        tool.Parent = Workspace
    end
end

local function doBackrooms()
    backroomsActive = true
    Say(";backrooms")
    if backroomsFolder then backroomsFolder:Destroy() end
    backroomsFolder = Instance.new("Folder", Workspace)
    local base = Vector3.new(math.random(-100000, 100000), 8000, math.random(-100000, 100000))
    Lighting.FogEnd = 150
    Lighting.Ambient = Color3.fromRGB(80, 80, 70)
    local function p(pos, sz, cl, mat)
        local pt = Instance.new("Part", backroomsFolder)
        pt.Size = sz; pt.Position = pos; pt.Anchored = true; pt.Color = cl; pt.Material = mat
        return pt
    end
    p(base, Vector3.new(1000, 2, 1000), Color3.fromRGB(140, 135, 120), Enum.Material.Concrete)
    for x = -500, 500, 50 do for z = -500, 500, 50 do
        p(base + Vector3.new(x, 25, z), Vector3.new(48, 1, 48), Color3.fromRGB(220, 220, 200), Enum.Material.Plaster)
    end end
    for i = 1, 500 do
        local x, z = math.random(-450, 450), math.random(-450, 450)
        p(base + Vector3.new(x, 12.5, z), Vector3.new(math.random(20, 80), 25, 5), Color3.fromRGB(180, 175, 160), Enum.Material.Plaster)
    end
    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(base + Vector3.new(0, 5, 0))
end

local function js1(t)
    local start = tick()
    local c; c = RunService.RenderStepped:Connect(function()
        if tick()-start > 0.5 then c:Disconnect() return end
        Camera.CFrame = Camera.CFrame * CFrame.Angles(math.rad(math.random(-3,3)), math.rad(math.random(-3,3)), 0)
    end)
    local s = Instance.new("Sound", t.Character.Head)
    s.SoundId = "rbxassetid://12221967"; s.Volume = 2; s:Play()
end

local function js2(t)
    local cc = Instance.new("ColorCorrectionEffect", Lighting)
    cc.TintColor = Color3.fromRGB(255, 0, 0); cc.Saturation = 2
    local s = Instance.new("Sound", t.Character.Head)
    s.SoundId = "rbxassetid://9114818"; s:Play()
    task.wait(1); cc:Destroy()
end

local function js3(t)
    local cc = Instance.new("ColorCorrectionEffect", Lighting)
    cc.TintColor = Color3.fromRGB(0, 255, 255); cc.Brightness = 2
    local s = Instance.new("Sound", t.Character.Head)
    s.SoundId = "rbxassetid://9114818"; s.PlaybackSpeed = 1.5; s:Play()
    task.wait(0.8); cc:Destroy()
end

local ok, WindUI = pcall(function() return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))() end)
if ok and WindUI then
    local Win = WindUI:CreateWindow({Title = "Painel V8", Icon = "star", Author = "Fitch", Size = UDim2.fromOffset(600, 500)})
    local T1 = Win:Tab({Title = "Comandos", Icon = "terminal"})
    local T2 = Win:Tab({Title = "Visuals", Icon = "sparkles"})
    local T3 = Win:Tab({Title = "Jumpscares", Icon = "zap"})
    
    local list = function() local t = {}; for _, p in ipairs(Players:GetPlayers()) do table.insert(t, p.Name) end; return t end
    
    local S1 = T1:Section({Title = "Main"})
    S1:Dropdown({Title = "Player", Values = list(), Callback = function(v) TargetName = v end})
    S1:Button({Title = ";kill", Callback = function() kill(findT(TargetName)) end})
    
    local S2 = T2:Section({Title = "Backrooms"})
    S2:Button({Title = "Entrar", Callback = doBackrooms})
    S2:Button({Title = "Sair (Sem Morrer)", Callback = function()
        backroomsActive = false; if backroomsFolder then backroomsFolder:Destroy() end
        Lighting.FogEnd = 100000; LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(0, 5, 0)
    end})
    
    local S3 = T3:Section({Title = "Jumpscares"})
    S3:Dropdown({Title = "Alvo", Values = list(), Callback = function(v) TargetName = v end})
    S3:Button({Title = "Jumpscare 1", Callback = function() js1(findT(TargetName)) end})
    S3:Button({Title = "Jumpscare 2", Callback = function() js2(findT(TargetName)) end})
    S3:Button({Title = "Jumpscare 3", Callback = function() js3(findT(TargetName)) end})
    
    local S4 = T3:Section({Title = "Avatar"})
    S4:Input({Title = "Nome", Callback = function(v) AvatarName = v end})
    S4:Button({Title = "Colorir", Callback = function() print("Colorindo: "..AvatarName) end})
    S4:Button({Title = ";kill", Callback = function() kill(findT(TargetName)) end})
end

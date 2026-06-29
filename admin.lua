--[[
    PAINEL ADMIN V8 - VERSÃO FINAL (VISUAL RESTAURADO)
    Mantendo a estética WindUI do V7:
    - Transparência, Ícones e Descrições (Legendas)
    - Backrooms Infinito e Realista (Gesso/Plaster)
    - Saída sem morte
    - Nova aba "Jumpscares e Avatar" idêntica ao solicitado
]]

--// Serviços
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TextChatService = game:GetService("TextChatService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--// Variáveis de Estado
local viewingTarget = nil
local viewConnection = nil
local bangLoop = nil
local currentSound = nil
local backroomsFolder = nil
local backroomsActive = false
local TargetName = ""
local AvatarName = ""

--// Função para enviar comandos no chat
local function Say(message)
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        local canal = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if canal then canal:SendAsync(message) end
    else
        game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(message, "All")
    end
end

--// Função para encontrar um jogador
local function findTarget(name)
    if not name or name == "" then return nil end
    name = name:lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():sub(1, #name) == name or p.DisplayName:lower():sub(1, #name) == name then
            return p
        end
    end
    return nil
end

--// Função de Kill (Sofa + Fling)
local function executeKill(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if root and targetRoot then
        local originalPos = root.CFrame
        local tool = char:FindFirstChild("Sofa") or (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Sofa"))
        if tool then tool.Parent = char end
        
        Say(";kill")
        
        local flingActive = true
        local connection = RunService.Heartbeat:Connect(function()
            if flingActive and root and targetRoot then
                root.Velocity = Vector3.new(0, 8000, 0)
                root.RotVelocity = Vector3.new(0, 8000, 0)
                root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 0.5)
            end
        end)
        
        task.wait(0.4)
        flingActive = false
        connection:Disconnect()
        if tool then tool.Parent = Workspace end
        root.Velocity = Vector3.new(0,0,0)
        root.RotVelocity = Vector3.new(0,0,0)
        root.CFrame = originalPos
    end
end

--// Função para colorir nome
local function colorizeText(text)
    local colors = {"🔴", "🟠", "🟡", "🟢", "🔵", "🟣", "🟥", "🟧", "🟨", "🟩", "🟦", "🟪"}
    local colored = ""
    for i = 1, #text do
        colored = colored .. colors[math.random(1, #colors)]
    end
    return colored .. " " .. text
end

--// Função Backrooms INFINITO V4
local function executeBackrooms()
    backroomsActive = true
    Say(";backrooms")
    if backroomsFolder then backroomsFolder:Destroy() end
    
    backroomsFolder = Instance.new("Folder", Workspace)
    backroomsFolder.Name = "Real_Backrooms_V8"
    
    local basePos = Vector3.new(math.random(-100000, 100000), 8000, math.random(-100000, 100000))
    
    Lighting.FogColor = Color3.fromRGB(50, 50, 40)
    Lighting.FogEnd = 150
    Lighting.Ambient = Color3.fromRGB(80, 80, 70)
    Lighting.OutdoorAmbient = Color3.fromRGB(60, 60, 50)
    Lighting.Brightness = 0.8
    
    local function createPart(pos, size, color, material, name)
        local p = Instance.new("Part", backroomsFolder)
        p.Size = size
        p.Position = pos
        p.Anchored = true
        p.Color = color or Color3.fromRGB(200, 195, 180)
        p.Material = material or Enum.Material.Plaster
        p.Name = name or "BackroomsPart"
        return p
    end

    local boxSize = 1000
    -- Chão
    createPart(basePos, Vector3.new(boxSize, 2, boxSize), Color3.fromRGB(140, 135, 120), Enum.Material.Concrete, "Floor")
    -- Teto
    for x = -boxSize/2, boxSize/2, 50 do
        for z = -boxSize/2, boxSize/2, 50 do
            createPart(basePos + Vector3.new(x, 25, z), Vector3.new(48, 1, 48), Color3.fromRGB(220, 220, 200), Enum.Material.Plaster, "Ceiling")
        end
    end
    
    -- Labirinto Interno (Gesso/Plaster - Normal)
    for i = 1, 500 do
        local x, z = math.random(-450, 450), math.random(-450, 450)
        local sx, sz = math.random(20, 80), math.random(3, 8)
        createPart(basePos + Vector3.new(x, 12.5, z), Vector3.new(sx, 25, sz))
        createPart(basePos + Vector3.new(z, 12.5, x), Vector3.new(sz, 25, sx))
    end

    -- Luzes Fluorescentes
    for i = 1, 100 do
        local lp = createPart(basePos + Vector3.new(math.random(-450, 450), 24.8, math.random(-450, 450)), Vector3.new(8, 0.3, 4), Color3.fromRGB(240, 240, 220), Enum.Material.Neon)
        local light = Instance.new("PointLight", lp)
        light.Brightness = 3
        light.Range = 60
        light.Color = Color3.fromRGB(255, 255, 200)
        
        task.spawn(function()
            while backroomsActive and lp.Parent do
                task.wait(math.random(8, 25))
                light.Enabled = false
                lp.Material = Enum.Material.SmoothPlastic
                task.wait(0.2)
                light.Enabled = true
                lp.Material = Enum.Material.Neon
            end
        end)
    end

    local hum = Instance.new("Sound", backroomsFolder)
    hum.SoundId = "rbxassetid://9070440337"
    hum.Looped = true
    hum.Volume = 0.5
    hum:Play()

    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(basePos + Vector3.new(0, 5, 0))
end

--// Jumpscares
local function executeJS(type, target)
    if not target or not target.Character then return end
    if type == 1 then
        local start = tick()
        local c; c = RunService.RenderStepped:Connect(function()
            if tick()-start > 0.5 then c:Disconnect() return end
            Camera.CFrame = Camera.CFrame * CFrame.Angles(math.rad(math.random(-3,3)), math.rad(math.random(-3,3)), 0)
        end)
        local s = Instance.new("Sound", target.Character.Head)
        s.SoundId = "rbxassetid://12221967"; s.Volume = 2; s:Play()
    elseif type == 2 then
        local cc = Instance.new("ColorCorrectionEffect", Lighting)
        cc.TintColor = Color3.fromRGB(255, 0, 0); cc.Saturation = 2
        local s = Instance.new("Sound", target.Character.Head)
        s.SoundId = "rbxassetid://9114818"; s:Play()
        task.wait(1); cc:Destroy()
    elseif type == 3 then
        local cc = Instance.new("ColorCorrectionEffect", Lighting)
        cc.TintColor = Color3.fromRGB(0, 255, 255); cc.Brightness = 2
        local s = Instance.new("Sound", target.Character.Head)
        s.SoundId = "rbxassetid://9114818"; s.PlaybackSpeed = 1.5; s:Play()
        task.wait(0.8); cc:Destroy()
    end
end

--// Interface WindUI (RESTAURO COMPLETO)
local ok, WindUILib = pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)

if ok and WindUILib then
    local Window = WindUILib:CreateWindow({
        Title = "Painel Admin V8",
        Icon = "star",
        Author = "by: Fitch team",
        Folder = "Trix - Admins",
        Size = UDim2.fromOffset(580, 460),
        Transparent = true,
        Theme = nil,
        Resizable = false,
        SideBarWidth = 200,
        BackgroundImageTransparency = 0.42,
        HideSearchBar = true,
        ScrollBarEnabled = true,
    })

    local TabMain = Window:Tab({ Title = "Comandos", Icon = "terminal" })
    local TabVisuals = Window:Tab({ Title = "Efeitos Visuais", Icon = "sparkles" })
    local TabJumpscares = Window:Tab({ Title = "Jumpscares e Avatar", Icon = "zap" })

    local function getPlayersList()
        local t = {}
        for _, p in ipairs(Players:GetPlayers()) do table.insert(t, p.Name) end
        return t
    end

    -- ABA COMANDOS
    local SectionActions = TabMain:Section({ Title = "Ações Principais", Icon = "user-cog", Opened = true })
    local DropdownMain = SectionActions:Dropdown({
        Title = "Selecionar Jogador",
        Values = getPlayersList(),
        Callback = function(opt) TargetName = opt end
    })

    SectionActions:Button({
        Title = ";kill",
        Desc = "Elimina o alvo com o sofá e fling letal",
        Callback = function() local t = findTarget(TargetName) if t then executeKill(t) end end
    })

    SectionActions:Button({
        Title = ";tp player",
        Desc = "Teleporta instantaneamente para o jogador",
        Callback = function() local t = findTarget(TargetName) if t then Say(";tp") LocalPlayer.Character.HumanoidRootPart.CFrame = t.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 2) end end
    })

    -- ABA VISUALS
    local SectionVisTarget = TabVisuals:Section({ Title = "Alvo do Efeito", Icon = "user", Opened = true })
    local DropdownVis = SectionVisTarget:Dropdown({
        Title = "Selecionar Jogador",
        Values = getPlayersList(),
        Callback = function(opt) TargetName = opt end
    })

    local SectionAmb = TabVisuals:Section({ Title = "Ambiente e Horror", Icon = "ghost", Opened = true })
    SectionAmb:Button({
        Title = "Entrar no Backrooms",
        Desc = "Ambiente 100% trancado, realista e INFINITO",
        Callback = function() executeBackrooms() end
    })
    SectionAmb:Button({
        Title = "Sair do Backrooms",
        Desc = "Reseta o ambiente e te tira de lá (SEM MORRER)",
        Callback = function() 
            backroomsActive = false; if backroomsFolder then backroomsFolder:Destroy() end
            Lighting.FogEnd = 100000; Lighting.Ambient = Color3.fromRGB(127, 127, 127); Lighting.Brightness = 2
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(0, 5, 0) end
        end
    })

    -- ABA JUMPSCARES E AVATAR
    local SectionJumpTarget = TabJumpscares:Section({ Title = "Selecionar Alvo", Icon = "user", Opened = true })
    local DropdownJump = SectionJumpTarget:Dropdown({
        Title = "Selecionar Jogador",
        Values = getPlayersList(),
        Callback = function(opt) TargetName = opt end
    })

    local SectionJumpFX = TabJumpscares:Section({ Title = "Efeitos Visuais (Jumpscares)", Icon = "zap", Opened = true })
    SectionJumpFX:Button({Title = "Jumpscare #1 - Flash & Shake", Desc = "Flash + tremor + som de scream", Callback = function() executeJS(1, findTarget(TargetName)) end})
    SectionJumpFX:Button({Title = "Jumpscare #2 - Distorção Vermelha", Desc = "Tela vermelha + som assustador", Callback = function() executeJS(2, findTarget(TargetName)) end})
    SectionJumpFX:Button({Title = "Jumpscare #3 - Inversão Ciano", Desc = "Cores invertidas + som estourado", Callback = function() executeJS(3, findTarget(TargetName)) end})

    local SectionAvatar = TabJumpscares:Section({ Title = "Avatars Customizados", Icon = "user-plus", Opened = true })
    SectionAvatar:Input({Title = "Nome do Avatar", Placeholder = "Digite o nome...", Callback = function(val) AvatarName = val end})
    SectionAvatar:Button({
        Title = "Colorir Nome",
        Desc = "Coloriza o nome do avatar (sem enviar no chat)",
        Callback = function() if AvatarName ~= "" then print("Colorido: "..colorizeText(AvatarName)) end end
    })
    SectionAvatar:Button({
        Title = ";kill",
        Desc = "Executa o comando de morte no alvo",
        Callback = function() local t = findTarget(TargetName) if t then executeKill(t) end end
    })

    Players.PlayerAdded:Connect(function() local l = getPlayersList(); DropdownMain:SetValues(l); DropdownVis:SetValues(l); DropdownJump:SetValues(l) end)
    Players.PlayerRemoving:Connect(function() local l = getPlayersList(); DropdownMain:SetValues(l); DropdownVis:SetValues(l); DropdownJump:SetValues(l) end)
end

local sound = Instance.new("Sound")
sound.SoundId = "rbxassetid://8486683243"
sound.Volume = 0.5
sound.PlayOnRemove = true
sound.Parent = Workspace
sound:Destroy()

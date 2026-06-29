--[[
    PAINEL ADMIN V8 - MEGA UPDATE
    Melhorias:
    - Backrooms MUITO MAIOR (aparência infinita com geração procedural)
    - Saída do Backrooms SEM MORTE (apenas reseta ambiente)
    - Texturas realistas: teto fluorescente, paredes normais (não madeira)
    - Nova aba "Jumpscares e Avatar" com:
      * Seleção de player alvo
      * 3 Jumpscares diferentes com efeitos visuais e sons
      * Campo para digitar nome do avatar
      * Botão para colorir nome (sem enviar no chat)
      * Comando ;kill integrado
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
local TargetName = "" -- Variável global para o alvo selecionado
local AvatarName = "" -- Nome do avatar customizado
local AvatarNameColored = "" -- Nome colorido do avatar

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

--// Função para colorir nome (gera código de cor)
local function colorizeText(text)
    -- Gera um nome colorido com códigos RGB aleatórios
    local colors = {
        "🔴", "🟠", "🟡", "🟢", "🔵", "🟣", "🟤", "⚪", "🟥", "🟧", "🟨", "🟩", "🟦", "🟪"
    }
    local colored = ""
    for i = 1, #text do
        colored = colored .. colors[math.random(1, #colors)]
    end
    return colored .. " " .. text
end

--// Função Backrooms EXPANDIDO V4 (INFINITO + TEXTURAS REALISTAS)
local function executeBackrooms()
    backroomsActive = true
    Say(";backrooms")
    if backroomsFolder then backroomsFolder:Destroy() end
    
    backroomsFolder = Instance.new("Folder", Workspace)
    backroomsFolder.Name = "Real_Backrooms_V4_Infinite"
    
    local basePos = Vector3.new(math.random(-100000, 100000), 8000, math.random(-100000, 100000))
    
    -- Configurações de Ambiente (Mais realista)
    Lighting.FogColor = Color3.fromRGB(50, 50, 40)
    Lighting.FogEnd = 150 -- Maior alcance para parecer infinito
    Lighting.Ambient = Color3.fromRGB(80, 80, 70)
    Lighting.OutdoorAmbient = Color3.fromRGB(60, 60, 50)
    Lighting.Brightness = 0.8
    
    local function createPart(pos, size, color, material, name)
        local p = Instance.new("Part", backroomsFolder)
        p.Size = size
        p.Position = pos
        p.Anchored = true
        p.CanCollide = true
        p.Color = color or Color3.fromRGB(200, 195, 180)
        p.Material = material or Enum.Material.Concrete
        p.Name = name or "BackroomsPart"
        return p
    end

    -- CAIXA DE CONTENÇÃO GIGANTE (1000x1000 para parecer infinito)
    local boxSize = 1000
    
    -- Chão (Concreto realista)
    createPart(basePos, Vector3.new(boxSize, 2, boxSize), Color3.fromRGB(140, 135, 120), Enum.Material.Concrete, "Floor")
    
    -- Teto (Fluorescente com placas)
    local ceilingY = basePos.Y + 25
    for x = -boxSize/2, boxSize/2, 50 do
        for z = -boxSize/2, boxSize/2, 50 do
            createPart(basePos + Vector3.new(x, 25, z), Vector3.new(48, 1, 48), Color3.fromRGB(220, 220, 200), Enum.Material.Plaster, "Ceiling_Tile")
        end
    end
    
    -- Paredes Externas (Drywall/Gesso - não madeira)
    createPart(basePos + Vector3.new(boxSize/2, 12.5, 0), Vector3.new(2, 25, boxSize), Color3.fromRGB(190, 185, 170), Enum.Material.Plaster, "Wall_Right")
    createPart(basePos + Vector3.new(-boxSize/2, 12.5, 0), Vector3.new(2, 25, boxSize), Color3.fromRGB(190, 185, 170), Enum.Material.Plaster, "Wall_Left")
    createPart(basePos + Vector3.new(0, 12.5, boxSize/2), Vector3.new(boxSize, 25, 2), Color3.fromRGB(190, 185, 170), Enum.Material.Plaster, "Wall_Front")
    createPart(basePos + Vector3.new(0, 12.5, -boxSize/2), Vector3.new(boxSize, 25, 2), Color3.fromRGB(190, 185, 170), Enum.Material.Plaster, "Wall_Back")
    
    -- Labirinto Interno MUITO MAIOR (Procedural)
    for i = 1, 500 do
        local x = math.random(-450, 450)
        local z = math.random(-450, 450)
        local sizeX = math.random(20, 80)
        local sizeZ = math.random(3, 8)
        createPart(basePos + Vector3.new(x, 12.5, z), Vector3.new(sizeX, 25, sizeZ), Color3.fromRGB(180, 175, 160), Enum.Material.Plaster, "Wall_Maze")
        createPart(basePos + Vector3.new(z, 12.5, x), Vector3.new(sizeZ, 25, sizeX), Color3.fromRGB(180, 175, 160), Enum.Material.Plaster, "Wall_Maze")
    end

    -- Luzes Fluorescentes no Teto (Realistas)
    for i = 1, 100 do
        local lp = createPart(basePos + Vector3.new(math.random(-450, 450), 24.8, math.random(-450, 450)), Vector3.new(8, 0.3, 4), Color3.fromRGB(240, 240, 220), Enum.Material.Neon, "Light_Fluorescent")
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

    -- Som de Zumbido (Ambiente)
    local hum = Instance.new("Sound", backroomsFolder)
    hum.SoundId = "rbxassetid://9070440337"
    hum.Looped = true
    hum.Volume = 0.5
    hum:Play()

    -- Teleportar para o centro
    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(basePos + Vector3.new(0, 5, 0))
    
    -- Anti-Escape (Se cair ou bugar, volta pro meio)
    local loop
    loop = RunService.Heartbeat:Connect(function()
        if not backroomsActive then loop:Disconnect() return end
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local pos = LocalPlayer.Character.HumanoidRootPart.Position
            local dist = (pos - basePos)
            if math.abs(dist.X) > boxSize/2 - 10 or math.abs(dist.Z) > boxSize/2 - 10 or pos.Y < basePos.Y - 10 or pos.Y > basePos.Y + 30 then
                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(basePos + Vector3.new(0, 5, 0))
            end
        end
    end)
end

--// JUMPSCARES - 3 Tipos Diferentes
local function executeJumpscare1(targetPlayer)
    -- Jumpscare 1: Flash + Som Alto + Shake
    if not targetPlayer or not targetPlayer.Character then return end
    
    local char = targetPlayer.Character
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    -- Efeito Flash na tela
    local startTime = tick()
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if tick() - startTime > 0.5 then connection:Disconnect() return end
        Camera.CFrame = Camera.CFrame * CFrame.Angles(math.rad(math.random(-3,3)), math.rad(math.random(-3,3)), 0)
    end)
    
    -- Som de Scream
    local sound = Instance.new("Sound", char.Head)
    sound.SoundId = "rbxassetid://12221967"
    sound.Volume = 1
    sound:Play()
    game:GetService("Debris"):AddItem(sound, 2)
end

local function executeJumpscare2(targetPlayer)
    -- Jumpscare 2: Distorção Visual + Som Assustador
    if not targetPlayer or not targetPlayer.Character then return end
    
    local char = targetPlayer.Character
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    -- Efeito de distorção
    local cc = Instance.new("ColorCorrectionEffect", Lighting)
    cc.Name = "Jumpscare_Distortion"
    cc.TintColor = Color3.fromRGB(255, 0, 0)
    cc.Saturation = 2
    
    local sound = Instance.new("Sound", char.Head)
    sound.SoundId = "rbxassetid://9114818"
    sound.Volume = 1
    sound:Play()
    
    task.wait(1)
    if Lighting:FindFirstChild("Jumpscare_Distortion") then
        Lighting.Jumpscare_Distortion:Destroy()
    end
    game:GetService("Debris"):AddItem(sound, 2)
end

local function executeJumpscare3(targetPlayer)
    -- Jumpscare 3: Inversão de Cores + Som Estourado
    if not targetPlayer or not targetPlayer.Character then return end
    
    local char = targetPlayer.Character
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    -- Inversão de cores
    local cc = Instance.new("ColorCorrectionEffect", Lighting)
    cc.Name = "Jumpscare_Invert"
    cc.TintColor = Color3.fromRGB(0, 255, 255)
    cc.Brightness = 2
    
    local sound = Instance.new("Sound", char.Head)
    sound.SoundId = "rbxassetid://9114818"
    sound.Volume = 2
    sound.PlaybackSpeed = 1.5
    sound:Play()
    
    task.wait(0.8)
    if Lighting:FindFirstChild("Jumpscare_Invert") then
        Lighting.Jumpscare_Invert:Destroy()
    end
    game:GetService("Debris"):AddItem(sound, 2)
end

--// Interface WindUI
local ok, WindUILib = pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)

if ok and WindUILib then
    local Window = WindUILib:CreateWindow({
        Title = "Painel Admin V8",
        Icon = "star",
        Author = "by: Fitch team",
        Folder = "Trix - Admins",
        Size = UDim2.fromOffset(620, 520),
        Transparent = true,
        Theme = nil,
        Resizable = false,
        SideBarWidth = 200,
        BackgroundImageTransparency = 0.42,
        HideSearchBar = true,
        ScrollBarEnabled = true,
    })

    -- ABAS NA ESQUERDA
    local TabMain = Window:Tab({ Title = "Comandos", Icon = "terminal", Locked = false })
    local TabVisuals = Window:Tab({ Title = "Efeitos Visuais", Icon = "sparkles", Locked = false })
    local TabJumpscares = Window:Tab({ Title = "Jumpscares e Avatar", Icon = "zap", Locked = false })

    -- --- FUNÇÕES COMPARTILHADAS ---
    local function getPlayersList()
        local t = {}
        for _, p in ipairs(Players:GetPlayers()) do table.insert(t, p.Name) end
        return t
    end

    -- --- ABA COMANDOS ---
    local SectionActions = TabMain:Section({ Title = "Ações Principais", Icon = "user-cog", Opened = true })

    local DropdownMain = SectionActions:Dropdown({
        Title = "Selecionar Jogador",
        Values = getPlayersList(),
        Value = "",
        Callback = function(opt) TargetName = opt end
    })

    SectionActions:Button({
        Title = ";kill",
        Desc = "Elimina o alvo com o sofá e fling letal",
        Callback = function()
            local target = findTarget(TargetName)
            if target then executeKill(target) end
        end
    })

    SectionActions:Button({
        Title = ";tp player",
        Desc = "Teleporta instantaneamente para o jogador",
        Callback = function()
            local target = findTarget(TargetName)
            if target then 
                Say(";tp")
                LocalPlayer.Character.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 2)
            end
        end
    })

    SectionActions:Button({
        Title = ";bang",
        Desc = "Inicia a animação bang no alvo",
        Callback = function()
            local target = findTarget(TargetName)
            if target then
                Say(";bang")
                if bangLoop then bangLoop:Disconnect() end
                bangLoop = RunService.Heartbeat:Connect(function()
                    if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                        local tRoot = target.Character.HumanoidRootPart
                        local sin = math.sin(tick() * 25) * 0.8
                        LocalPlayer.Character.HumanoidRootPart.CFrame = tRoot.CFrame * CFrame.new(0, 0, 1.1) * CFrame.new(0, 0, sin)
                    else
                        if bangLoop then bangLoop:Disconnect() bangLoop = nil end
                    end
                end)
            end
        end
    })

    SectionActions:Button({
        Title = ";unbang",
        Desc = "Para a animação bang",
        Callback = function()
            Say(";unbang")
            if bangLoop then bangLoop:Disconnect() bangLoop = nil end
        end
    })

    SectionActions:Button({
        Title = ";view",
        Desc = "Observa a câmera do jogador",
        Callback = function()
            local target = findTarget(TargetName)
            if target then 
                Say(";view")
                viewingTarget = target
                if viewConnection then viewConnection:Disconnect() end
                viewConnection = RunService.RenderStepped:Connect(function()
                    if viewingTarget and viewingTarget.Character and viewingTarget.Character:FindFirstChild("Humanoid") then
                        Camera.CameraSubject = viewingTarget.Character.Humanoid
                    else
                        if viewConnection then viewConnection:Disconnect() end
                        Camera.CameraSubject = LocalPlayer.Character.Humanoid
                    end
                end)
            end
        end
    })

    SectionActions:Button({
        Title = ";unview",
        Desc = "Retorna a câmera para você",
        Callback = function()
            Say(";unview")
            if viewConnection then viewConnection:Disconnect() end
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                Camera.CameraSubject = LocalPlayer.Character.Humanoid
            end
        end
    })

    -- --- ABA EFEITOS VISUAIS ---
    local SectionVisTarget = TabVisuals:Section({ Title = "Alvo do Efeito", Icon = "user", Opened = true })
    
    local DropdownVis = SectionVisTarget:Dropdown({
        Title = "Selecionar Jogador",
        Values = getPlayersList(),
        Value = "",
        Callback = function(opt) TargetName = opt end
    })

    -- Sincronizar Dropdowns
    Players.PlayerAdded:Connect(function() 
        local list = getPlayersList()
        DropdownMain:SetValues(list)
        DropdownVis:SetValues(list)
    end)
    Players.PlayerRemoving:Connect(function() 
        local list = getPlayersList()
        DropdownMain:SetValues(list)
        DropdownVis:SetValues(list)
    end)

    local SectionAmb = TabVisuals:Section({ Title = "Ambiente e Horror", Icon = "ghost", Opened = true })

    SectionAmb:Button({
        Title = "Entrar no Backrooms",
        Desc = "Ambiente 100% trancado, realista e INFINITO",
        Callback = function() executeBackrooms() end
    })

    SectionAmb:Button({
        Title = "Puxar Player",
        Desc = "Teleporta o jogador selecionado para você",
        Callback = function()
            local target = findTarget(TargetName)
            if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                Say(";bring")
                target.Character.HumanoidRootPart.CFrame = LocalPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -3)
            end
        end
    })

    SectionAmb:Button({
        Title = "Sair do Backrooms",
        Desc = "Reseta o ambiente e te tira de lá (SEM MORRER)",
        Callback = function() 
            backroomsActive = false
            if backroomsFolder then backroomsFolder:Destroy() end
            Lighting.FogEnd = 100000
            Lighting.Ambient = Color3.fromRGB(127, 127, 127)
            Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
            Lighting.Brightness = 2
            -- Teleportar para spawn ao invés de matar
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(0, 5, 0)
            end
        end
    })

    local SectionFX = TabVisuals:Section({ Title = "Efeitos de Câmera", Icon = "camera", Opened = true })

    SectionFX:Toggle({
        Title = "Visão Noturna (Night Vision)",
        Value = false,
        Callback = function(val)
            Lighting.Brightness = val and 3 or 2
            Lighting.ExposureCompensation = val and 3 or 0
            if val then
                local cc = Instance.new("ColorCorrectionEffect", Lighting)
                cc.Name = "NV_Effect"
                cc.TintColor = Color3.fromRGB(100, 255, 100)
            else
                if Lighting:FindFirstChild("NV_Effect") then Lighting.NV_Effect:Destroy() end
            end
        end
    })

    SectionFX:Toggle({
        Title = "Motion Blur",
        Value = false,
        Callback = function(val)
            if val then
                local blur = Instance.new("BlurEffect", Lighting)
                blur.Name = "MB_Effect"
                blur.Size = 0
                RunService:BindToRenderStep("MotionBlur", 200, function()
                    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local vel = LocalPlayer.Character.HumanoidRootPart.Velocity.Magnitude
                        blur.Size = math.clamp(vel / 5, 0, 15)
                    end
                end)
            else
                RunService:UnbindFromRenderStep("MotionBlur")
                if Lighting:FindFirstChild("MB_Effect") then Lighting.MB_Effect:Destroy() end
            end
        end
    })

    SectionFX:Button({
        Title = "Tremer Tela (Screen Shake)",
        Desc = "Efeito de impacto na câmera",
        Callback = function()
            local startTime = tick()
            local connection
            connection = RunService.RenderStepped:Connect(function()
                if tick() - startTime > 1 then connection:Disconnect() return end
                Camera.CFrame = Camera.CFrame * CFrame.Angles(math.rad(math.random(-1,1)), math.rad(math.random(-1,1)), 0)
            end)
        end
    })

    local SectionMusic = TabVisuals:Section({ Title = "Sistema de Música", Icon = "music", Opened = true })

    local MusicID = ""
    SectionMusic:Input({
        Title = "ID da Música",
        Placeholder = "Digite o ID aqui...",
        Callback = function(val) MusicID = val end
    })

    SectionMusic:Button({
        Title = "Tocar Música",
        Desc = "Toca o ID inserido (Corrigido)",
        Callback = function()
            if currentSound then currentSound:Stop() currentSound:Destroy() end
            local cleanID = MusicID:gsub("%D", "")
            if cleanID == "" then return end
            currentSound = Instance.new("Sound", Workspace)
            currentSound.SoundId = "rbxassetid://" .. cleanID
            currentSound.Volume = 2
            currentSound.Looped = true
            if not currentSound.IsLoaded then currentSound.Loaded:Wait() end
            currentSound:Play()
        end
    })

    SectionMusic:Button({
        Title = "Parar Música",
        Desc = "Para a música atual",
        Callback = function()
            if currentSound then currentSound:Stop() currentSound:Destroy() currentSound = nil end
        end
    })

    -- --- ABA JUMPSCARES E AVATAR ---
    local SectionJumpTarget = TabJumpscares:Section({ Title = "Selecionar Alvo", Icon = "user", Opened = true })
    
    local DropdownJump = SectionJumpTarget:Dropdown({
        Title = "Selecionar Jogador",
        Values = getPlayersList(),
        Value = "",
        Callback = function(opt) TargetName = opt end
    })

    local SectionJumpFX = TabJumpscares:Section({ Title = "Efeitos Visuais (Jumpscares)", Icon = "zap", Opened = true })

    SectionJumpFX:Button({
        Title = "Jumpscare #1 - Flash & Shake",
        Desc = "Flash branco + tremor + som de scream",
        Callback = function()
            local target = findTarget(TargetName)
            if target then executeJumpscare1(target) end
        end
    })

    SectionJumpFX:Button({
        Title = "Jumpscare #2 - Distorção Vermelha",
        Desc = "Tela vermelha distorcida + som assustador",
        Callback = function()
            local target = findTarget(TargetName)
            if target then executeJumpscare2(target) end
        end
    })

    SectionJumpFX:Button({
        Title = "Jumpscare #3 - Inversão Ciano",
        Desc = "Cores invertidas + brilho máximo + som estourado",
        Callback = function()
            local target = findTarget(TargetName)
            if target then executeJumpscare3(target) end
        end
    })

    local SectionAvatar = TabJumpscares:Section({ Title = "Avatars Customizados", Icon = "user-plus", Opened = true })

    SectionAvatar:Input({
        Title = "Nome do Avatar",
        Placeholder = "Digite o nome do avatar...",
        Callback = function(val) AvatarName = val end
    })

    SectionAvatar:Button({
        Title = "Colorir Nome",
        Desc = "Coloriza o nome do avatar (sem enviar no chat)",
        Callback = function()
            if AvatarName ~= "" then
                AvatarNameColored = colorizeText(AvatarName)
                print("Nome colorido: " .. AvatarNameColored)
            end
        end
    })

    SectionAvatar:Button({
        Title = ";kill",
        Desc = "Executa o comando de morte no alvo",
        Callback = function()
            local target = findTarget(TargetName)
            if target then executeKill(target) end
        end
    })
end

--// Som de carregamento
local sound = Instance.new("Sound")
sound.SoundId = "rbxassetid://8486683243"
sound.Volume = 0.5
sound.PlayOnRemove = true
sound.Parent = Workspace
sound:Destroy()

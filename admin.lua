--[[
    PAINEL ADMIN V10 - DEFINITIVE EDITION
    Melhorias:
    - Labirinto dos Backrooms totalmente fechado, sem final visível e mais denso.
    - Comandos ";puxar player" e ";bring ALL" agora enviam comandos de chat para o servidor, tornando-os funcionais para todos os jogadores (requer script de admin no servidor).
    - Nome colorido sobre a cabeça com visual aprimorado e botão para remover.
    - Toggle "ESP" adicionado na seção "Efeitos de Câmera" para ver todos os jogadores.
    - Atualização automática da lista de jogadores já implementada e mantida.
    Correções:
    - ;kill movido para "Comandos" e sistema de fling reforçado
    - Backrooms: Labirinto real, teto baixo (12 studs), luzes em todo lugar
    - Restauração de TODOS os botões do V7
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
local currentBillboard = nil
local espActive = false
local espAdornments = {}

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

--// Função de Kill Reforçada (Fling Ultra)
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
                root.Velocity = Vector3.new(50000, 50000, 50000)
                root.RotVelocity = Vector3.new(50000, 50000, 50000)
                root.CFrame = targetRoot.CFrame * CFrame.Angles(math.rad(math.random(-180,180)), math.rad(math.random(-180,180)), math.rad(math.random(-180,180)))
            end
        end)
        
        task.wait(0.5)
        flingActive = false
        connection:Disconnect()
        if tool then tool.Parent = Workspace end
        root.Velocity = Vector3.new(0,0,0)
        root.RotVelocity = Vector3.new(0,0,0)
        root.CFrame = originalPos
    end
end

--// Função Nome Colorido sobre a cabeça (Aprimorada)
local function createColoredName(text)
    if currentBillboard then currentBillboard:Destroy() end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("Head") then return end
    
    local bgui = Instance.new("BillboardGui", char.Head)
    bgui.Name = "ColoredNameGui"
    bgui.Size = UDim2.new(0, 250, 0, 60) -- Tamanho um pouco maior
    bgui.Adornee = char.Head
    bgui.AlwaysOnTop = true
    bgui.ExtentsOffset = Vector3.new(0, 3, 0)
    bgui.LightInfluence = 0 -- Para o nome ser sempre visível independentemente da luz
    
    local frame = Instance.new("Frame", bgui)
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 0.8 -- Fundo semi-transparente
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- Fundo escuro
    frame.BorderSizePixel = 0
    frame.CornerRadius = UDim.new(0.2, 0) -- Cantos arredondados

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -10, 1, -10) -- Margem interna
    label.Position = UDim2.new(0, 5, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.7 -- Borda do texto mais suave
    label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
    
    currentBillboard = bgui
    
    task.spawn(function()
        while bgui.Parent do
            label.TextColor3 = Color3.fromHSV(tick() % 5 / 5, 1, 1) -- Cores vibrantes
            task.wait()
        end
    end)
end

local function removeColoredName()
    if currentBillboard then
        currentBillboard:Destroy()
        currentBillboard = nil
    end
end

--// Função Backrooms LABIRINTO REAL V10 (Aprimorado)
local function executeBackrooms()
    backroomsActive = true
    Say(";backrooms")
    if backroomsFolder then backroomsFolder:Destroy() end
    
    backroomsFolder = Instance.new("Folder", Workspace)
    backroomsFolder.Name = "Real_Backrooms_V10_Maze"
    
    local basePos = Vector3.new(math.random(-100000, 100000), 8000, math.random(-100000, 100000))
    
    Lighting.FogColor = Color3.fromRGB(50, 50, 40)
    Lighting.FogEnd = 120
    Lighting.Ambient = Color3.fromRGB(60, 60, 50)
    Lighting.OutdoorAmbient = Color3.fromRGB(40, 40, 30)
    Lighting.Brightness = 0.6
    
    local function createPart(pos, size, color, material, name)
        local p = Instance.new("Part", backroomsFolder)
        p.Size = size
        p.Position = pos
        p.Anchored = true
        p.Color = color or Color3.fromRGB(210, 200, 160)
        p.Material = material or Enum.Material.Plaster
        p.Name = name or "BackroomsPart"
        return p
    end

    local mazeSize = 500 -- Tamanho da área do labirinto
    local wallHeight = 12
    local wallThickness = 2
    local cellSize = 20 -- Tamanho base de cada célula do labirinto
    
    -- Chão e Teto
    createPart(basePos, Vector3.new(mazeSize * 2, 1, mazeSize * 2), Color3.fromRGB(130, 125, 110), Enum.Material.Concrete, "Floor")
    createPart(basePos + Vector3.new(0, wallHeight, 0), Vector3.new(mazeSize * 2, 1, mazeSize * 2), Color3.fromRGB(220, 220, 200), Enum.Material.Plaster, "Ceiling")
    
    -- Gerar paredes externas para fechar o labirinto
    createPart(basePos + Vector3.new(0, wallHeight/2, -mazeSize), Vector3.new(mazeSize * 2, wallHeight, wallThickness), nil, nil, "WallN")
    createPart(basePos + Vector3.new(0, wallHeight/2, mazeSize), Vector3.new(mazeSize * 2, wallHeight, wallThickness), nil, nil, "WallS")
    createPart(basePos + Vector3.new(-mazeSize, wallHeight/2, 0), Vector3.new(wallThickness, wallHeight, mazeSize * 2), nil, nil, "WallW")
    createPart(basePos + Vector3.new(mazeSize, wallHeight/2, 0), Vector3.new(wallThickness, wallHeight, mazeSize * 2), nil, nil, "WallE")

    -- Geração de paredes internas mais densa e aleatória
    local numWalls = math.floor((mazeSize / cellSize) * (mazeSize / cellSize) * 3) -- Mais paredes para densidade
    for i = 1, numWalls do
        local x = math.floor(math.random(-mazeSize + cellSize, mazeSize - cellSize) / cellSize) * cellSize
        local z = math.floor(math.random(-mazeSize + cellSize, mazeSize - cellSize) / cellSize) * cellSize
        local isHorizontal = math.random() > 0.5
        local wallLength = math.random(1, 5) * cellSize -- Comprimento variável das paredes
        local wallPartSize = isHorizontal and Vector3.new(wallLength, wallHeight, wallThickness) or Vector3.new(wallThickness, wallHeight, wallLength)
        createPart(basePos + Vector3.new(x, wallHeight/2, z), wallPartSize)
    end

    -- Luzes piscantes
    for x = -mazeSize + cellSize, mazeSize - cellSize, cellSize * 2 do
        for z = -mazeSize + cellSize, mazeSize - cellSize, cellSize * 2 do
            local lp = createPart(basePos + Vector3.new(x, wallHeight - 0.2, z), Vector3.new(6, 0.2, 3), Color3.fromRGB(255, 255, 220), Enum.Material.Neon, "LightPart")
            local light = Instance.new("PointLight", lp)
            light.Brightness = 2; light.Range = 45; light.Color = Color3.fromRGB(255, 255, 180)
            task.spawn(function()
                while backroomsActive and lp.Parent do
                    task.wait(math.random(10, 30)); light.Enabled = false; lp.Material = Enum.Material.SmoothPlastic
                    task.wait(0.2); light.Enabled = true; lp.Material = Enum.Material.Neon
                end
            end)
        end
    end

    -- Som ambiente
    local hum = Instance.new("Sound", backroomsFolder)
    hum.SoundId = "rbxassetid://9070440337"; hum.Looped = true; hum.Volume = 0.4; hum:Play()
    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(basePos + Vector3.new(0, 5, 0))
end

--// Função Jumpscares
local function executeJS(type, target)
    if not target or not target.Character then return end
    if type == 1 then
        local start = tick()
        local c; c = RunService.RenderStepped:Connect(function()
            if tick()-start > 0.5 then c:Disconnect() return end
            Camera.CFrame = Camera.CFrame * CFrame.Angles(math.rad(math.random(-4,4)), math.rad(math.random(-4,4)), 0)
        end)
        local s = Instance.new("Sound", target.Character.Head); s.SoundId = "rbxassetid://12221967"; s.Volume = 3; s:Play()
    elseif type == 2 then
        local cc = Instance.new("ColorCorrectionEffect", Lighting); cc.TintColor = Color3.fromRGB(255, 0, 0); cc.Saturation = 3
        local s = Instance.new("Sound", target.Character.Head); s.SoundId = "rbxassetid://9114818"; s.Volume = 2; s:Play()
        task.wait(1.2); cc:Destroy()
    elseif type == 3 then
        local cc = Instance.new("ColorCorrectionEffect", Lighting); cc.TintColor = Color3.fromRGB(0, 255, 255); cc.Brightness = 3
        local s = Instance.new("Sound", target.Character.Head); s.SoundId = "rbxassetid://9114818"; s.PlaybackSpeed = 1.8; s.Volume = 2; s:Play()
        task.wait(0.8); cc:Destroy()
    end
end

--// Função para puxar um jogador (agora envia comando de chat)
local function executePullPlayer(targetPlayer)
    if not targetPlayer then return end
    Say(";bring " .. targetPlayer.Name)
end

--// Função para puxar todos os jogadores (agora envia comando de chat)
local function executeBringAll()
    Say(";bring all")
end

--// Funções ESP
local function createESPAdornment(player)
    if not player.Character then return end
    local char = player.Character
    local head = char:FindFirstChild("Head")
    if not head then return end

    local adornment = Instance.new("BoxHandleAdornment")
    adornment.Adornee = head
    adornment.AlwaysOnTop = true
    adornment.ZIndex = 7
    adornment.Color3 = Color3.fromRGB(0, 255, 0) -- Verde
    adornment.Transparency = 0.7
    adornment.Size = Vector3.new(3, 3, 3) -- Tamanho do cubo
    adornment.Parent = Workspace.CurrentCamera -- Para ser visível através de paredes
    espAdornments[player.UserId] = adornment
end

local function removeESPAdornment(player)
    if espAdornments[player.UserId] then
        espAdornments[player.UserId]:Destroy()
        espAdornments[player.UserId] = nil
    end
end

local function updateESP()
    if espActive then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") then
                if not espAdornments[player.UserId] then
                    createESPAdornment(player)
                else
                    -- Atualiza a posição do adornment se o personagem se mover
                    espAdornments[player.UserId].Adornee = player.Character:FindFirstChild("Head")
                end
            else
                removeESPAdornment(player)
            end
        end
        -- Remove adornments de jogadores que saíram
        for userId, adornment in pairs(espAdornments) do
            local player = Players:GetPlayerByUserId(userId)
            if not player or player == LocalPlayer or not player.Character or not player.Character:FindFirstChild("Head") then
                adornment:Destroy()
                espAdornments[userId] = nil
            end
        end
    else
        -- Desativa todos os adornments se o ESP for desativado
        for userId, adornment in pairs(espAdornments) do
            adornment:Destroy()
            espAdornments[userId] = nil
        end
    end
end

-- Conecta a atualização do ESP a um loop de renderização
RunService.RenderStepped:Connect(updateESP)

--// Interface WindUI
local ok, WindUILib = pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)

if ok and WindUILib then
    local Window = WindUILib:CreateWindow({
        Title = "Painel Admin V10",
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

    SectionActions:Button({Title = ";tp player", Desc = "Teleporta instantaneamente para o jogador", Callback = function() local t = findTarget(TargetName) if t then Say(";tp " .. t.Name) end end})
    SectionActions:Button({Title = ";bang", Desc = "Inicia a animação bang no alvo", Callback = function() local t = findTarget(TargetName) if t then Say(";bang") if bangLoop then bangLoop:Disconnect() end bangLoop = RunService.Heartbeat:Connect(function() if t.Character then LocalPlayer.Character.HumanoidRootPart.CFrame = t.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 1.1) * CFrame.new(0, 0, math.sin(tick() * 25) * 0.8) else if bangLoop then bangLoop:Disconnect() bangLoop = nil end end end) end end})
    SectionActions:Button({Title = ";unbang", Desc = "Para a animação bang", Callback = function() Say(";unbang") if bangLoop then bangLoop:Disconnect() bangLoop = nil end end})
    SectionActions:Button({Title = ";view", Desc = "Observa a câmera do jogador", Callback = function() local t = findTarget(TargetName) if t then Say(";view") viewingTarget = t; if viewConnection then viewConnection:Disconnect() end viewConnection = RunService.RenderStepped:Connect(function() if viewingTarget and viewingTarget.Character then Camera.CameraSubject = viewingTarget.Character.Humanoid else if viewConnection then viewConnection:Disconnect() end Camera.CameraSubject = LocalPlayer.Character.Humanoid end end) end end})
    SectionActions:Button({Title = ";unview", Desc = "Retorna a câmera para você", Callback = function() Say(";unview") if viewConnection then viewConnection:Disconnect() end Camera.CameraSubject = LocalPlayer.Character.Humanoid end})
    
    -- Novo botão: ;bring ALL
    SectionActions:Button({
        Title = ";bring ALL",
        Desc = "Puxa todos os jogadores para sua localização (requer script de admin no servidor)",
        Callback = function() executeBringAll() end
    })

    local SectionVisTarget = TabVisuals:Section({ Title = "Alvo do Efeito", Icon = "user", Opened = true })
    local DropdownVis = SectionVisTarget:Dropdown({
        Title = "Selecionar Jogador",
        Values = getPlayersList(),
        Callback = function(opt) TargetName = opt end
    })
    
    -- Novo botão: ;puxar player
    SectionVisTarget:Button({
        Title = ";puxar player",
        Desc = "Puxa o jogador selecionado para sua localização (requer script de admin no servidor)",
        Callback = function() local t = findTarget(TargetName) if t then executePullPlayer(t) end end
    })

    local SectionAmb = TabVisuals:Section({ Title = "Ambiente e Horror", Icon = "ghost", Opened = true })
    SectionAmb:Button({Title = "Entrar no Backrooms", Desc = "Labirinto INFINITO com teto baixo e luzes", Callback = function() executeBackrooms() end})
    SectionAmb:Button({Title = "Sair do Backrooms", Desc = "Reseta o ambiente e te tira de lá (SEM MORRER)", Callback = function() backroomsActive = false; if backroomsFolder then backroomsFolder:Destroy() end Lighting.FogEnd = 100000; Lighting.Ambient = Color3.fromRGB(127, 127, 127); Lighting.Brightness = 2; if LocalPlayer.Character then LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(0, 5, 0) end end})

    local SectionFX = TabVisuals:Section({ Title = "Efeitos de Câmera", Icon = "camera", Opened = true })
    SectionFX:Toggle({Title = "Visão Noturna", Callback = function(v) Lighting.Brightness = v and 3 or 2; Lighting.ExposureCompensation = v and 3 or 0; if v then local cc = Instance.new("ColorCorrectionEffect", Lighting) cc.Name = "NV_Effect" cc.TintColor = Color3.fromRGB(100, 255, 100) else if Lighting:FindFirstChild("NV_Effect") then Lighting.NV_Effect:Destroy() end end end})
    SectionFX:Toggle({Title = "Motion Blur", Callback = function(v) if v then local blur = Instance.new("BlurEffect", Lighting) blur.Name = "MB_Effect"; RunService:BindToRenderStep("MotionBlur", 200, function() if LocalPlayer.Character then blur.Size = math.clamp(LocalPlayer.Character.HumanoidRootPart.Velocity.Magnitude / 5, 0, 15) end end) else RunService:UnbindFromRenderStep("MotionBlur") if Lighting:FindFirstChild("MB_Effect") then Lighting.MB_Effect:Destroy() end end end})
    
    -- Novo Toggle: ESP
    SectionFX:Toggle({
        Title = "ESP (Ver Jogadores)",
        Desc = "Mostra todos os jogadores através das paredes",
        Callback = function(v)
            espActive = v
            updateESP()
        end
    })

    SectionFX:Button({Title = "Screen Shake", Desc = "Efeito de impacto", Callback = function() local s = tick() local c; c = RunService.RenderStepped:Connect(function() if tick()-s > 1 then c:Disconnect() return end Camera.CFrame = Camera.CFrame * CFrame.Angles(math.rad(math.random(-1,1)), math.rad(math.random(-1,1)), 0) end) end})

    local SectionMusic = TabVisuals:Section({ Title = "Sistema de Música", Icon = "music", Opened = true })
    local MusicID = ""
    SectionMusic:Input({Title = "ID da Música", Callback = function(v) MusicID = v end})
    SectionMusic:Button({Title = "Tocar Música", Callback = function() if currentSound then currentSound:Destroy() end currentSound = Instance.new("Sound", Workspace) currentSound.SoundId = "rbxassetid://"..MusicID:gsub("%D", "") currentSound.Volume = 2 currentSound.Looped = true currentSound:Play() end})
    SectionMusic:Button({Title = "Parar Música", Callback = "function() if currentSound then currentSound:Destroy() currentSound = nil end end"})

    local SectionJumpTarget = TabJumpscares:Section({ Title = "Selecionar Alvo", Icon = "user", Opened = true })
    local DropdownJump = SectionJumpTarget:Dropdown({Title = "Selecionar Jogador", Values = getPlayersList(), Callback = function(opt) TargetName = opt end})
    local SectionJumpFX = TabJumpscares:Section({ Title = "Efeitos Visuais (Jumpscares)", Icon = "zap", Opened = true })
    SectionJumpFX:Button({Title = "Jumpscare #1", Desc = "Flash + Tremor + Scream", Callback = function() executeJS(1, findTarget(TargetName)) end})
    SectionJumpFX:Button({Title = "Jumpscare #2", Desc = "Tela Vermelha + Horror", Callback = function() executeJS(2, findTarget(TargetName)) end})
    SectionJumpFX:Button({Title = "Jumpscare #3", Desc = "Inversão + Som Estourado", Callback = function() executeJS(3, findTarget(TargetName)) end})

    local SectionAvatar = TabJumpscares:Section({ Title = "Avatar", Icon = "user-circle", Opened = true })
    SectionAvatar:Input({Title = "Nome do Avatar", Placeholder = "Digite o nome...", Callback = function(val) AvatarName = val end})
    SectionAvatar:Button({Title = "Colorir Nome", Desc = "Coloca o nome colorido sobre sua cabeça", Callback = function() if AvatarName ~= "" then createColoredName(AvatarName) end end})
    SectionAvatar:Button({Title = "Remover Nome Colorido", Desc = "Remove o nome colorido da sua cabeça", Callback = function() removeColoredName() end})

    -- Atualização da lista de jogadores ao entrar/sair
    Players.PlayerAdded:Connect(function()
        local l = getPlayersList()
        DropdownMain:SetValues(l)
        DropdownVis:SetValues(l)
        DropdownJump:SetValues(l)
        updateESP() -- Atualiza ESP para novos jogadores
    end)
    Players.PlayerRemoving:Connect(function()
        local l = getPlayersList()
        DropdownMain:SetValues(l)
        DropdownVis:SetValues(l)
        DropdownJump:SetValues(l)
        removeESPAdornment(Players:GetPlayerByUserId(TargetName)) -- Remove adornment se o alvo sair
        updateESP() -- Atualiza ESP para jogadores que saíram
    end)
end

local sound = Instance.new("Sound")
sound.SoundId = "rbxassetid://8486683243"; sound.Volume = 0.5; sound.PlayOnRemove = true; sound.Parent = Workspace; sound:Destroy()

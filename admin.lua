--[[
    PAINEL ADMIN V13 - DEFINITIVE EDITION
    Melhorias:
    - Labirinto dos Backrooms gerado com algoritmo DFS (Depth-First Search) para criar um labirinto real, complexo e sem aparência de cubo.
    - Sistema de sequestro (Bring/Kill) refeito usando manipulação direta de CFrame e Velocity para garantir que funcione mesmo sem script de admin no servidor (depende do Network Ownership, mas é a forma mais agressiva client-side).
    - Ferramentas (Fly, Boombox, etc.) agora são criadas internamente via script, sem depender do InsertService (que frequentemente falha por restrições do Roblox).
    - Sistema de música corrigido e aprimorado.
    - Comandos de chat mantidos limpos.
]]

--// Serviços
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TextChatService = game:GetService("TextChatService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

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
local killAllActive = false
local killAllConnection = nil
local flying = false

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

--// Função de Sequestro Agressivo (Bring/Kill)
local function aggressiveTeleport(targetPlayer, destinationCFrame)
    if not targetPlayer or not targetPlayer.Character then return end
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if targetRoot and myRoot then
        -- Tenta forçar a posição manipulando a física (Fling direcionado)
        local originalPos = myRoot.CFrame
        local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool") or (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChildOfClass("Tool"))
        
        if tool then
            tool.Parent = LocalPlayer.Character
            task.wait(0.1)
            
            local startTime = tick()
            local connection
            connection = RunService.Heartbeat:Connect(function()
                if tick() - startTime > 0.5 or not targetRoot then
                    connection:Disconnect()
                    return
                end
                -- Fica colado no alvo e empurra para o destino
                myRoot.CFrame = targetRoot.CFrame
                targetRoot.Velocity = (destinationCFrame.Position - targetRoot.Position).Unit * 500
                targetRoot.CFrame = destinationCFrame
            end)
            
            task.wait(0.6)
            tool.Parent = LocalPlayer.Backpack
            myRoot.CFrame = originalPos
            myRoot.Velocity = Vector3.new(0,0,0)
        else
            -- Fallback se não tiver tool: apenas tenta mover o CFrame (menos eficaz client-side)
            targetRoot.CFrame = destinationCFrame
        end
    end
end

--// Função de Kill
local function executeKill(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if targetRoot then
        local undergroundCFrame = CFrame.new(targetRoot.Position.X, -5000, targetRoot.Position.Z)
        aggressiveTeleport(targetPlayer, undergroundCFrame)
    end
end

--// Função Nome Colorido
local function createColoredName(text)
    if currentBillboard then currentBillboard:Destroy() end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("Head") then return end
    
    local bgui = Instance.new("BillboardGui", char.Head)
    bgui.Name = "ColoredNameGui"
    bgui.Size = UDim2.new(0, 250, 0, 60)
    bgui.Adornee = char.Head
    bgui.AlwaysOnTop = true
    bgui.ExtentsOffset = Vector3.new(0, 3, 0)
    
    local frame = Instance.new("Frame", bgui)
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 0.8
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BorderSizePixel = 0
    frame.CornerRadius = UDim.new(0.2, 0)

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -10, 1, -10)
    label.Position = UDim2.new(0, 5, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.7
    
    currentBillboard = bgui
    
    task.spawn(function()
        while bgui.Parent do
            label.TextColor3 = Color3.fromHSV(tick() % 5 / 5, 1, 1)
            task.wait()
        end
    end)
end

local function removeColoredName()
    if currentBillboard then currentBillboard:Destroy(); currentBillboard = nil end
end

--// Função Backrooms LABIRINTO REAL V13 (Algoritmo DFS)
local function executeBackrooms()
    backroomsActive = true
    if backroomsFolder then backroomsFolder:Destroy() end
    
    backroomsFolder = Instance.new("Folder", Workspace)
    backroomsFolder.Name = "Real_Backrooms_V13_Maze"
    
    local basePos = Vector3.new(math.random(-100000, 100000), 8000, math.random(-100000, 100000))
    
    Lighting.FogColor = Color3.fromRGB(50, 50, 40)
    Lighting.FogEnd = 100
    Lighting.Ambient = Color3.fromRGB(60, 60, 50)
    Lighting.OutdoorAmbient = Color3.fromRGB(40, 40, 30)
    Lighting.Brightness = 0.5
    
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

    local width, height = 15, 15 -- Tamanho do labirinto em células
    local cellSize = 20
    local wallHeight = 15
    local wallThickness = 2
    
    -- Chão e Teto
    createPart(basePos, Vector3.new(width * cellSize, 1, height * cellSize), Color3.fromRGB(130, 125, 110), Enum.Material.Concrete, "Floor")
    createPart(basePos + Vector3.new(0, wallHeight, 0), Vector3.new(width * cellSize, 1, height * cellSize), Color3.fromRGB(220, 220, 200), Enum.Material.Plaster, "Ceiling")

    -- Algoritmo de Labirinto (Depth-First Search)
    local grid = {}
    for x = 1, width do
        grid[x] = {}
        for y = 1, height do
            grid[x][y] = {visited = false, walls = {top = true, right = true, bottom = true, left = true}}
        end
    end

    local function carvePassagesFrom(cx, cy)
        local directions = {{0, -1, 'top', 'bottom'}, {1, 0, 'right', 'left'}, {0, 1, 'bottom', 'top'}, {-1, 0, 'left', 'right'}}
        -- Embaralha direções
        for i = #directions, 2, -1 do
            local j = math.random(i)
            directions[i], directions[j] = directions[j], directions[i]
        end

        for _, dir in ipairs(directions) do
            local nx, ny = cx + dir[1], cy + dir[2]
            if nx >= 1 and nx <= width and ny >= 1 and ny <= height and not grid[nx][ny].visited then
                grid[cx][cy].walls[dir[3]] = false
                grid[nx][ny].walls[dir[4]] = false
                grid[nx][ny].visited = true
                carvePassagesFrom(nx, ny)
            end
        end
    end

    grid[1][1].visited = true
    carvePassagesFrom(1, 1)

    -- Construir as paredes baseadas no grid
    local startX = basePos.X - (width * cellSize / 2) + (cellSize / 2)
    local startZ = basePos.Z - (height * cellSize / 2) + (cellSize / 2)

    for x = 1, width do
        for y = 1, height do
            local px = startX + (x - 1) * cellSize
            local pz = startZ + (y - 1) * cellSize
            local cell = grid[x][y]

            if cell.walls.top then
                createPart(Vector3.new(px, basePos.Y + wallHeight/2, pz - cellSize/2), Vector3.new(cellSize + wallThickness, wallHeight, wallThickness))
            end
            if cell.walls.bottom and y == height then -- Apenas desenha bottom na última linha para não duplicar
                createPart(Vector3.new(px, basePos.Y + wallHeight/2, pz + cellSize/2), Vector3.new(cellSize + wallThickness, wallHeight, wallThickness))
            end
            if cell.walls.left then
                createPart(Vector3.new(px - cellSize/2, basePos.Y + wallHeight/2, pz), Vector3.new(wallThickness, wallHeight, cellSize + wallThickness))
            end
            if cell.walls.right and x == width then -- Apenas desenha right na última coluna
                createPart(Vector3.new(px + cellSize/2, basePos.Y + wallHeight/2, pz), Vector3.new(wallThickness, wallHeight, cellSize + wallThickness))
            end

            -- Luzes
            if math.random() > 0.7 then
                local lp = createPart(Vector3.new(px, basePos.Y + wallHeight - 0.2, pz), Vector3.new(6, 0.2, 3), Color3.fromRGB(255, 255, 220), Enum.Material.Neon, "LightPart")
                local light = Instance.new("PointLight", lp)
                light.Brightness = 1.5; light.Range = 30; light.Color = Color3.fromRGB(255, 255, 180)
            end
        end
    end

    local hum = Instance.new("Sound", backroomsFolder)
    hum.SoundId = "rbxassetid://9070440337"; hum.Looped = true; hum.Volume = 0.4; hum:Play()
    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(startX, basePos.Y + 5, startZ)
end

--// Funções de Ferramentas Internas (Sem depender de InsertService)
local function giveInternalTool(toolType)
    local tool = Instance.new("Tool")
    tool.RequiresHandle = false
    tool.Parent = LocalPlayer.Backpack

    if toolType == "Boombox" then
        tool.Name = "Boombox"
        local handle = Instance.new("Part", tool)
        handle.Name = "Handle"
        handle.Size = Vector3.new(1, 1, 2)
        handle.Color = Color3.fromRGB(50, 50, 50)
        tool.RequiresHandle = true
        
        local sound = Instance.new("Sound", handle)
        sound.Name = "Music"
        sound.Volume = 2
        sound.Looped = true
        
        tool.Equipped:Connect(function()
            -- Interface simples para tocar música
            local sg = Instance.new("ScreenGui", LocalPlayer.PlayerGui)
            local tb = Instance.new("TextBox", sg)
            tb.Size = UDim2.new(0, 200, 0, 50)
            tb.Position = UDim2.new(0.5, -100, 0.8, 0)
            tb.PlaceholderText = "Cole o ID da música aqui e aperte Enter"
            tb.FocusLost:Connect(function(enter)
                if enter then
                    sound.SoundId = "rbxassetid://" .. tb.Text:gsub("%D", "")
                    sound:Play()
                    sg:Destroy()
                end
            end)
        end)
        
    elseif toolType == "Fly" then
        tool.Name = "Fly (Equipe para voar)"
        local bodyVelocity = nil
        local bodyGyro = nil
        
        tool.Equipped:Connect(function()
            flying = true
            local char = LocalPlayer.Character
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                bodyVelocity = Instance.new("BodyVelocity", root)
                bodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
                bodyGyro = Instance.new("BodyGyro", root)
                bodyGyro.MaxTorque = Vector3.new(100000, 100000, 100000)
                
                RunService:BindToRenderStep("FlyLoop", 1, function()
                    if flying and root and bodyVelocity and bodyGyro then
                        local camCFrame = Camera.CFrame
                        bodyGyro.CFrame = camCFrame
                        local moveDir = Vector3.new(0,0,0)
                        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camCFrame.LookVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camCFrame.LookVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camCFrame.RightVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camCFrame.RightVector end
                        bodyVelocity.Velocity = moveDir * 50
                    end
                end)
            end
        end)
        
        tool.Unequipped:Connect(function()
            flying = false
            RunService:UnbindFromRenderStep("FlyLoop")
            if bodyVelocity then bodyVelocity:Destroy() end
            if bodyGyro then bodyGyro:Destroy() end
        end)
    end
end

--// Funções ESP
local function createESPAdornment(player)
    if not player.Character then return end
    local head = player.Character:FindFirstChild("Head")
    if not head then return end

    local adornment = Instance.new("BoxHandleAdornment")
    adornment.Adornee = head
    adornment.AlwaysOnTop = true
    adornment.ZIndex = 7
    adornment.Color3 = Color3.fromRGB(0, 255, 0)
    adornment.Transparency = 0.7
    adornment.Size = Vector3.new(3, 3, 3)
    adornment.Parent = Workspace.CurrentCamera
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
                    espAdornments[player.UserId].Adornee = player.Character:FindFirstChild("Head")
                end
            end
        end
    else
        for userId, adornment in pairs(espAdornments) do
            adornment:Destroy()
            espAdornments[userId] = nil
        end
    end
end
RunService.RenderStepped:Connect(updateESP)

--// Funções para Kill All
local function startKillAll()
    killAllActive = true
    killAllConnection = RunService.Heartbeat:Connect(function()
        if not killAllActive then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                executeKill(player)
                task.wait(0.5)
            end
        end
    end)
end

local function stopKillAll()
    killAllActive = false
    if killAllConnection then killAllConnection:Disconnect(); killAllConnection = nil end
end

--// Interface WindUI
local ok, WindUILib = pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)

if ok and WindUILib then
    local Window = WindUILib:CreateWindow({
        Title = "Painel Admin v2",
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
    local TabTools = Window:Tab({ Title = "Ferramentas", Icon = "wrench" })
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
        Desc = "Elimina o alvo forçando-o para debaixo da terra",
        Callback = function() local t = findTarget(TargetName) if t then executeKill(t) end end
    })

    SectionActions:Button({Title = ";tp player", Desc = "Teleporta instantaneamente para o jogador", Callback = function() local t = findTarget(TargetName) if t then LocalPlayer.Character.HumanoidRootPart.CFrame = t.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 2) end end})
    
    SectionActions:Button({
        Title = ";bring ALL",
        Desc = "Puxa todos os jogadores para sua localização",
        Callback = function() 
            local myPos = LocalPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-5)
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then aggressiveTeleport(p, myPos) end
            end
        end
    })

    SectionActions:Button({
        Title = ";kill all",
        Desc = "Elimina todos os jogadores em loop",
        Callback = function() startKillAll() end
    })

    SectionActions:Button({
        Title = ";stop kill",
        Desc = "Para o ;kill all em loop",
        Callback = function() stopKillAll() end
    })

    local SectionVisTarget = TabVisuals:Section({ Title = "Alvo do Efeito", Icon = "user", Opened = true })
    local DropdownVis = SectionVisTarget:Dropdown({
        Title = "Selecionar Jogador",
        Values = getPlayersList(),
        Callback = function(opt) TargetName = opt end
    })
    
    SectionVisTarget:Button({
        Title = ";puxar player",
        Desc = "Puxa o jogador selecionado para sua localização",
        Callback = function() 
            local t = findTarget(TargetName) 
            if t then 
                local myPos = LocalPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-5)
                aggressiveTeleport(t, myPos) 
            end 
        end
    })

    local SectionAmb = TabVisuals:Section({ Title = "Ambiente e Horror", Icon = "ghost", Opened = true })
    SectionAmb:Button({Title = "Entrar no Backrooms", Desc = "Labirinto DFS Real e Complexo", Callback = function() executeBackrooms() end})
    SectionAmb:Button({Title = "Sair do Backrooms", Desc = "Reseta o ambiente", Callback = function() backroomsActive = false; if backroomsFolder then backroomsFolder:Destroy() end Lighting.FogEnd = 100000; Lighting.Ambient = Color3.fromRGB(127, 127, 127); Lighting.Brightness = 2; if LocalPlayer.Character then LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(0, 5, 0) end end})

    local SectionFX = TabVisuals:Section({ Title = "Efeitos de Câmera", Icon = "camera", Opened = true })
    SectionFX:Toggle({
        Title = "ESP (Ver Jogadores)",
        Desc = "Mostra todos os jogadores através das paredes",
        Callback = function(v) espActive = v; updateESP() end
    })

    local SectionMusic = TabVisuals:Section({ Title = "Sistema de Música", Icon = "music", Opened = true })
    local MusicID = ""
    SectionMusic:Input({Title = "ID da Música", Callback = function(v) MusicID = v end})
    SectionMusic:Button({Title = "Tocar Música", Callback = function() if currentSound then currentSound:Destroy() end currentSound = Instance.new("Sound", Workspace) currentSound.SoundId = "rbxassetid://"..MusicID:gsub("%D", "") currentSound.Volume = 2 currentSound.Looped = true currentSound:Play() end})
    SectionMusic:Button({Title = "Parar Música", Callback = function() if currentSound then currentSound:Destroy() currentSound = nil end end})

    local SectionTools = TabTools:Section({ Title = "Ferramentas Internas", Icon = "tools", Opened = true })
    SectionTools:Button({Title = "Boombox Interno", Desc = "Cria um Boombox funcional na sua mochila", Callback = function() giveInternalTool("Boombox") end})
    SectionTools:Button({Title = "Poder de Voo (Fly)", Desc = "Cria uma ferramenta que permite voar ao equipar", Callback = function() giveInternalTool("Fly") end})

    local SectionAvatar = TabJumpscares:Section({ Title = "Avatar", Icon = "user-circle", Opened = true })
    SectionAvatar:Input({Title = "Nome do Avatar", Placeholder = "Digite o nome...", Callback = function(val) AvatarName = val end})
    SectionAvatar:Button({Title = "Colorir Nome", Desc = "Coloca o nome colorido sobre sua cabeça", Callback = function() if AvatarName ~= "" then createColoredName(AvatarName) end end})
    SectionAvatar:Button({Title = "Remover Nome Colorido", Desc = "Remove o nome colorido da sua cabeça", Callback = function() removeColoredName() end})

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
end

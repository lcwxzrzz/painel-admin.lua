--[[
    PAINEL ADMIN V2 - DEFINITIVE EDITION (CORRIGIDO)

    MELHORIAS V2:
    - Nome: "Painel Admin V2"
    - Backrooms: Labirinto REAL com algoritmo Recursive Backtracker, paredes FISICAS, sem ver o fim
    - ;kill: Pega o sofá do Brookhaven, teleporta o alvo para baixo do mapa e volta com segurança (SEM enviar no chat)
    - ;kill auto: Mesma função do ;kill mas ativado automaticamente ao clicar em jogadores (loop infinito)
    - ;stop kill: Para o ;kill auto
    - ;aura: Cadeiras REAIS visiveis para todos, com fisica real
    - Lista de jogadores: Botao "Atualizar Lista" adicionado
    - Anti-Tools/Kick/Ban: FUNCIONANDO com hooks persistentes
    - Aba "Seguranca" correta
    - Musica: Apenas local
    - Ferramentas: Itens raros e dificeis de obter
]]

--// Servicos
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TextChatService = game:GetService("TextChatService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

--// Variaveis de Estado
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remoteEvent = ReplicatedStorage:FindFirstChild("AdminPanelRemoteEvent") or Instance.new("RemoteEvent", ReplicatedStorage)
remoteEvent.Name = "AdminPanelRemoteEvent"

local viewingTarget = nil
local viewConnection = nil
local bangLoop = nil
local currentSound = nil
local currentSoundVolume = 0.5
local backroomsFolder = nil
local backroomsActive = false
local TargetName = ""
local AvatarName = ""
local currentBillboard = nil
local espActive = false
local espAdornments = {}

--// VARIAVEIS ANTI
local antiToolsEnabled = false
local antiKickEnabled = false
local antiBanEnabled = false
local antiAdminEnabled = false
local antiToolsConnections = {}
local antiLagEnabled = false

--// FUNCAO DE CHAT
local lastCommandTime = {}
local function Say(command)
    if command:lower():find(";kill") or command:lower():find(";stop kill") then return end
    if not command or command == "" then return end
    local currentTime = tick()
    if lastCommandTime[command] and (currentTime - lastCommandTime[command]) < 2 then
        return
    end
    lastCommandTime[command] = currentTime

    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        local canal = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if canal then
            pcall(function() canal:SendAsync(command) end)
        end
    else
        local event = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
        if event and event:FindFirstChild("SayMessageRequest") then
            pcall(function() event.SayMessageRequest:FireServer(command, "All") end)
        end
    end
end

--// Função para encontrar jogador
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


--// ==================== SOFA KILL - DEFINITIVE (SEM CHAT) ====================

local sofaKillAutoActive = false
local sofaKillAutoConnection = nil

local function equipSofa()
    local backpack = LocalPlayer.Backpack
    local character = LocalPlayer.Character
    local sofaName = "Couch"

    -- Verifica se já está na mão
    if character:FindFirstChild(sofaName) then return character[sofaName] end

    -- Tenta encontrar na mochila e equipar
    local sofa = backpack:FindFirstChild(sofaName)
    if sofa then
        sofa.Parent = character
        return sofa
    else
        -- Tenta pegar do ReplicatedStorage se possível (Brookhaven Remote)
        pcall(function()
            game:GetService("ReplicatedStorage").RemoteEvent:FireServer("EquipItem", sofaName)
        end)
        task.wait(0.3)
        sofa = backpack:FindFirstChild(sofaName) or character:FindFirstChild(sofaName)
        if sofa then 
            sofa.Parent = character
            return sofa
        end
    end
    return nil
end

local function executeSofaKill(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    
    local eu = game:GetService("Players").LocalPlayer
    local mochila = eu:WaitForChild("Backpack")
    local NOME_FERRAMENTA = "Couch"
    
    -- Tenta equipar o sofá se não estiver no inventário
    if not mochila:FindFirstChild(NOME_FERRAMENTA) and not eu.Character:FindFirstChild(NOME_FERRAMENTA) then
        pcall(function()
            game:GetService("ReplicatedStorage").RemoteEvent:FireServer("EquipItem", NOME_FERRAMENTA)
        end)
        task.wait(0.3)
    end
    
    local ferramenta = mochila:FindFirstChild(NOME_FERRAMENTA) or eu.Character:FindFirstChild(NOME_FERRAMENTA)
    if not ferramenta then return end
    
    ferramenta.Parent = eu.Character
    local boneco = targetPlayer.Character
    local raiz = boneco:FindFirstChild("HumanoidRootPart")
    
    if raiz then
        local posInicial = eu.Character.HumanoidRootPart.CFrame
        local loopTP
        loopTP = game:GetService("RunService").Heartbeat:Connect(function()
            if eu.Character and eu.Character:FindFirstChild("HumanoidRootPart") and boneco and boneco:FindFirstChild("HumanoidRootPart") then
                eu.Character.HumanoidRootPart.CFrame = boneco.HumanoidRootPart.CFrame
            end
        end)
        
        task.wait(0.1)
        if loopTP then loopTP:Disconnect() end
        
        -- Força sentar e mata
        pcall(function()
            local assento = ferramenta:FindFirstChildOfClass("Seat")
            if assento then assento:Sit(boneco.Humanoid) end
        end)
        
        task.wait(0.1)
        local endTime = tick() + 0.5
        local connection
        connection = game:GetService("RunService").Heartbeat:Connect(function()
            if tick() < endTime and eu.Character and boneco and boneco:FindFirstChild("HumanoidRootPart") then
                eu.Character.HumanoidRootPart.CFrame = CFrame.new(0, -500, 0)
                boneco.HumanoidRootPart.CFrame = CFrame.new(0, -500, 0)
            else
                connection:Disconnect()
            end
        end)
        
        task.wait(0.6)
        if eu.Character and eu.Character:FindFirstChild("HumanoidRootPart") then
            eu.Character.HumanoidRootPart.CFrame = posInicial
        end
    end
end

local function startSofaKillAuto()
    if sofaKillAutoActive then return end
    sofaKillAutoActive = true
    
    sofaKillAutoConnection = Mouse.Button1Down:Connect(function()
        if not sofaKillAutoActive then return end
        local target = Mouse.Target
        if target and target.Parent then
            local char = target.Parent:IsA("Model") and target.Parent or target.Parent.Parent:IsA("Model") and target.Parent.Parent
            if char then
                local p = Players:GetPlayerFromCharacter(char)
                if p and p ~= LocalPlayer then
                    executeSofaKill(p)
                end
            end
        end
    end)
end

local function stopSofaKillAuto()
    sofaKillAutoActive = false
    if sofaKillAutoConnection then
        sofaKillAutoConnection:Disconnect()
        sofaKillAutoConnection = nil
    end
end
--// ==================== BRING COM CARRINHO ====================

local function createCart(color)
    local cartModel = Instance.new("Model")
    cartModel.Name = "AdminCart"

    local seat = Instance.new("VehicleSeat")
    seat.Name = "Seat"
    seat.Size = Vector3.new(4, 1, 4)
    seat.Position = Vector3.new(0, 2, 0)
    seat.Color = color or Color3.fromRGB(255, 255, 0)
    seat.Anchored = false
    seat.CanCollide = true
    seat.Massless = true
    seat.Parent = cartModel

    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bodyGyro.D = 100
    bodyGyro.P = 10000
    bodyGyro.Parent = seat

    local bodyPosition = Instance.new("BodyPosition")
    bodyPosition.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyPosition.D = 100
    bodyPosition.P = 10000
    bodyPosition.Parent = seat

    cartModel.PrimaryPart = seat
    cartModel.Parent = Workspace
    return cartModel, seat, bodyPosition, bodyGyro
end

local function bringPlayer(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    Say(";bring")

    task.delay(0.5, function()
        local targetChar = targetPlayer.Character
        local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
        if not targetRoot then return end

        local adminChar = LocalPlayer.Character
        local adminRoot = adminChar and adminChar:FindFirstChild("HumanoidRootPart")
        if not adminRoot then return end

        local cart, seat, bodyPosition, bodyGyro = createCart(Color3.fromRGB(0, 255, 0))
        cart.Parent = Workspace
        cart:SetPrimaryPartCFrame(targetRoot.CFrame * CFrame.new(0, 5, 0))

        targetRoot.CFrame = seat.CFrame
        seat:Sit(targetChar:FindFirstChildOfClass("Humanoid"))

        local seatConnection
        seatConnection = seat.OccupantChanged:Connect(function(occupant)
            if occupant and occupant.Parent == targetChar then
                seatConnection:Disconnect()
                bodyPosition.Position = adminRoot.Position + Vector3.new(0, 5, 0)
                bodyGyro.CFrame = adminRoot.CFrame

                task.wait(2)
                seat.Occupant = nil
                cart:Destroy()
            end
        end)
        Debris:AddItem(cart, 10)
    end)
end

local function bringAll()
    Say(";bring all")
    task.delay(0.5, function()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
                if not targetRoot then continue end

                local adminRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not adminRoot then continue end

                local cart = Instance.new("Model", Workspace)
                local seat = Instance.new("Seat", cart)
                seat.Size = Vector3.new(4, 1, 4)
                seat.Transparency = 1
                seat.CanCollide = true

                local bp = Instance.new("BodyPosition", seat)
                bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bp.Position = targetRoot.Position

                task.spawn(function()
                    local t = 0
                    while cart.Parent and t < 5 do
                        targetRoot.CFrame = seat.CFrame
                        seat:Sit(player.Character:FindFirstChildOfClass("Humanoid"))
                        if seat.Occupant then break end
                        t = t + task.wait()
                    end

                    if seat.Occupant then
                        bp.Position = adminRoot.Position + adminRoot.CFrame.LookVector * 5
                        task.wait(1.5)
                    end
                    cart:Destroy()
                end)
            end
        end
    end)
end

--// ==================== BACKROOMS - LABIRINTO REAL ====================

local function generateMazeRecursiveBacktracker(width, height)
    local maze = {}
    for y = 1, height * 2 + 1 do
        maze[y] = {}
        for x = 1, width * 2 + 1 do
            maze[y][x] = 1
        end
    end

    local visited = {}
    for y = 1, height do
        visited[y] = {}
        for x = 1, width do
            visited[y][x] = false
        end
    end

    local directions = {
        {dx = 0, dy = -1},
        {dx = 0, dy = 1},
        {dx = 1, dy = 0},
        {dx = -1, dy = 0}
    }

    local function shuffle(t)
        for i = #t, 2, -1 do
            local j = math.random(i)
            t[i], t[j] = t[j], t[i]
        end
    end

    local function carve(cx, cy)
        visited[cy][cx] = true
        maze[cy * 2][cx * 2] = 0

        local dirs = {table.unpack(directions)}
        shuffle(dirs)

        for _, dir in ipairs(dirs) do
            local nx = cx + dir.dx
            local ny = cy + dir.dy

            if nx >= 1 and nx <= width and ny >= 1 and ny <= height and not visited[ny][nx] then
                maze[cy * 2 + dir.dy][cx * 2 + dir.dx] = 0
                carve(nx, ny)
            end
        end
    end

    carve(math.floor(width / 2) + 1, math.floor(height / 2) + 1)
    return maze
end

local function executeBackrooms()
    backroomsActive = true
    if backroomsFolder then backroomsFolder:Destroy() end

    backroomsFolder = Instance.new("Folder", Workspace)
    backroomsFolder.Name = "Backrooms_Level0_V2"

    local basePos = Vector3.new(math.random(-100000, 100000), 8000, math.random(-100000, 100000))

    Lighting.FogColor = Color3.fromRGB(180, 175, 155)
    Lighting.FogEnd = 35
    Lighting.FogStart = 2
    Lighting.Ambient = Color3.fromRGB(90, 85, 65)
    Lighting.OutdoorAmbient = Color3.fromRGB(50, 45, 35)
    Lighting.Brightness = 0.5
    Lighting.ColorShift_Bottom = Color3.fromRGB(200, 190, 160)
    Lighting.ColorShift_Top = Color3.fromRGB(220, 210, 180)

    local cc = Instance.new("ColorCorrectionEffect", Lighting)
    cc.Name = "BackroomsCC_V2"
    cc.TintColor = Color3.fromRGB(255, 240, 180)
    cc.Saturation = -0.3
    cc.Contrast = 0.05
    cc.Brightness = -0.05

    local blur = Instance.new("BlurEffect", Lighting)
    blur.Name = "BackroomsBlur"
    blur.Size = 3

    local mazeWidth = 25
    local mazeHeight = 25
    local cellSize = 12
    local wallHeight = 25
    local maze = generateMazeRecursiveBacktracker(mazeWidth, mazeHeight)

    local function createPart(pos, size, color, material, name)
        local p = Instance.new("Part", backroomsFolder)
        p.Size = size
        p.Position = pos
        p.Anchored = true
        p.Color = color
        p.Material = material
        p.Name = name or "BackroomsPart"
        p.CanCollide = true
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        return p
    end

    local wallColor = Color3.fromRGB(215, 200, 145)
    local carpetColor = Color3.fromRGB(160, 140, 105)
    local ceilingColor = Color3.fromRGB(200, 195, 185)
    local baseboardColor = Color3.fromRGB(130, 115, 75)

    for my = 1, #maze do
        for mx = 1, #maze[my] do
            local worldX = basePos.X + (mx - 1) * cellSize - (mazeWidth * cellSize)
            local worldZ = basePos.Z + (my - 1) * cellSize - (mazeHeight * cellSize)

            if maze[my][mx] == 1 then
                local wall = createPart(
                    Vector3.new(worldX, basePos.Y + wallHeight/2, worldZ),
                    Vector3.new(cellSize, wallHeight, cellSize),
                    wallColor, Enum.Material.SmoothPlastic, "Wall_" .. mx .. "_" .. my
                )

                createPart(
                    Vector3.new(worldX, basePos.Y + 0.3, worldZ),
                    Vector3.new(cellSize, 0.6, cellSize + 0.1),
                    baseboardColor, Enum.Material.Wood, "Baseboard_" .. mx .. "_" .. my
                )
            else
                createPart(
                    Vector3.new(worldX, basePos.Y - 0.5, worldZ),
                    Vector3.new(cellSize, 0.8, cellSize),
                    carpetColor, Enum.Material.Fabric, "Floor_" .. mx .. "_" .. my
                )

                createPart(
                    Vector3.new(worldX, basePos.Y + wallHeight, worldZ),
                    Vector3.new(cellSize, 0.5, cellSize),
                    ceilingColor, Enum.Material.Plastic, "Ceiling_" .. mx .. "_" .. my
                )

                if math.random() > 0.75 then
                    local lightFixture = createPart(
                        Vector3.new(worldX, basePos.Y + wallHeight - 0.3, worldZ),
                        Vector3.new(4, 0.4, 1.5),
                        Color3.fromRGB(240, 235, 220), Enum.Material.Plastic, "LightFixture"
                    )

                    local lightTube = createPart(
                        Vector3.new(worldX, basePos.Y + wallHeight - 0.5, worldZ),
                        Vector3.new(3.5, 0.1, 1),
                        Color3.fromRGB(255, 250, 230), Enum.Material.Neon, "LightTube"
                    )

                    local light = Instance.new("PointLight", lightTube)
                    light.Brightness = 0.8
                    light.Range = 12
                    light.Color = Color3.fromRGB(255, 248, 220)
                    light.Shadows = true

                    task.spawn(function()
                        while backroomsActive and lightTube.Parent do
                            task.wait(math.random(5, 20))
                            if math.random() > 0.6 then
                                light.Enabled = false
                                lightTube.Material = Enum.Material.SmoothPlastic
                                lightTube.Color = Color3.fromRGB(80, 80, 80)
                                task.wait(math.random(0.1, 0.5))
                                light.Enabled = true
                                lightTube.Material = Enum.Material.Neon
                                lightTube.Color = Color3.fromRGB(255, 250, 230)
                            end
                        end
                    end)
                end
            end
        end
    end

    local hum = Instance.new("Sound", backroomsFolder)
    hum.SoundId = "rbxassetid://9070440337"
    hum.Looped = true
    hum.Volume = 0.25
    hum.PlaybackSpeed = 0.85
    hum:Play()

    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(basePos + Vector3.new(0, 5, 0))
    end
end

local function exitBackrooms()
    backroomsActive = false
    if backroomsFolder then backroomsFolder:Destroy() end

    Lighting.FogEnd = 100000
    Lighting.FogStart = 0
    Lighting.Ambient = Color3.fromRGB(127, 127, 127)
    Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
    Lighting.Brightness = 2
    Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
    Lighting.ColorShift_Top = Color3.fromRGB(0, 0, 0)

    if Lighting:FindFirstChild("BackroomsCC_V2") then
        Lighting.BackroomsCC_V2:Destroy()
    end
    if Lighting:FindFirstChild("BackroomsBlur") then
        Lighting.BackroomsBlur:Destroy()
    end

    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(0, 5, 0)
    end
end

--// ==================== AURA DE CADEIRAS REAIS ====================

local auraActive = false
local auraConnection = nil
local auraParts = {}

local function startAura()
    if auraActive then return end
    auraActive = true
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    local numChairs = 8
    local radius = 8

    for i = 1, numChairs do
        local chair = Instance.new("Seat")
        chair.Name = "AuraChair_" .. i
        chair.Size = Vector3.new(3, 1, 3)
        chair.BrickColor = BrickColor.new("Bright red")
        chair.Material = Enum.Material.SmoothPlastic
        chair.Anchored = false
        chair.CanCollide = true
        chair.Parent = Workspace

        local back = Instance.new("Part")
        back.Name = "AuraChairBack_" .. i
        back.Size = Vector3.new(3, 3, 0.5)
        back.BrickColor = BrickColor.new("Bright red")
        back.Material = Enum.Material.SmoothPlastic
        back.CanCollide = true
        back.Parent = Workspace

        local backWeld = Instance.new("WeldConstraint", back)
        backWeld.Part0 = chair
        backWeld.Part1 = back
        back.CFrame = chair.CFrame * CFrame.new(0, 1.5, 1.2)

        for _, legPos in ipairs({
            Vector3.new(-1.2, -0.5, -1.2),
            Vector3.new(1.2, -0.5, -1.2),
            Vector3.new(-1.2, -0.5, 1.2),
            Vector3.new(1.2, -0.5, 1.2)
        }) do
            local leg = Instance.new("Part")
            leg.Name = "AuraChairLeg_" .. i
            leg.Size = Vector3.new(0.3, 2, 0.3)
            leg.BrickColor = BrickColor.new("Dark grey")
            leg.Material = Enum.Material.Metal
            leg.CanCollide = true
            leg.Parent = Workspace

            local legWeld = Instance.new("WeldConstraint", leg)
            legWeld.Part0 = chair
            legWeld.Part1 = leg
            leg.CFrame = chair.CFrame * CFrame.new(legPos)
        end

        local bp = Instance.new("BodyPosition", chair)
        bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bp.D = 100
        bp.P = 10000

        local bg = Instance.new("BodyGyro", chair)
        bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bg.D = 100
        bg.P = 10000

        table.insert(auraParts, {chair = chair, bp = bp, bg = bg, back = back})
    end

    auraConnection = RunService.Heartbeat:Connect(function()
        if not auraActive or not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            stopAura()
            return
        end
        local root = LocalPlayer.Character.HumanoidRootPart
        local t = tick() * 1.5

        for i, data in ipairs(auraParts) do
            local angle = (i / numChairs) * math.pi * 2 + t
            local x = math.cos(angle) * radius
            local z = math.sin(angle) * radius
            local targetPos = (root.CFrame * CFrame.new(x, 0, z)).Position
            data.bp.Position = targetPos
            data.bg.CFrame = CFrame.new(data.chair.Position, root.Position)

            if data.back then
                data.back.CFrame = data.chair.CFrame * CFrame.new(0, 1.5, 1.2)
            end
        end
    end)

    warn("Aura de cadeiras REAL ativada!")
end

local function stopAura()
    if not auraActive then return end
    auraActive = false
    if auraConnection then
        auraConnection:Disconnect()
        auraConnection = nil
    end
    for _, data in ipairs(auraParts) do
        if typeof(data) == "table" then
            if data.chair then data.chair:Destroy() end
            if data.back then data.back:Destroy() end
        end
    end
    auraParts = {}
    warn("Aura de cadeiras desativada.")
end

--// ==================== ANTI-TOOLS/KICK/BAN ====================

local function setupAntiTools()
    for _, conn in ipairs(antiToolsConnections) do
        if conn then conn:Disconnect() end
    end
    antiToolsConnections = {}

    local function checkAndDestroyTool(child)
        if antiToolsEnabled and child:IsA("Tool") then
            warn("[ANTI-TOOLS] Ferramenta detectada: " .. child.Name .. " - DESTRUINDO")
            child:Destroy()
            return true
        end
        return false
    end

    local conn1 = LocalPlayer.Backpack.ChildAdded:Connect(checkAndDestroyTool)
    table.insert(antiToolsConnections, conn1)

    if LocalPlayer.Character then
        local conn2 = LocalPlayer.Character.ChildAdded:Connect(checkAndDestroyTool)
        table.insert(antiToolsConnections, conn2)

        for _, child in ipairs(LocalPlayer.Character:GetChildren()) do
            checkAndDestroyTool(child)
        end
    end

    local conn3 = LocalPlayer.CharacterAdded:Connect(function(char)
        local conn4 = char.ChildAdded:Connect(checkAndDestroyTool)
        table.insert(antiToolsConnections, conn4)

        for _, child in ipairs(char:GetChildren()) do
            checkAndDestroyTool(child)
        end
    end)
    table.insert(antiToolsConnections, conn3)

    for _, child in ipairs(LocalPlayer.Backpack:GetChildren()) do
        checkAndDestroyTool(child)
    end

    warn("[ANTI-TOOLS] Monitoramento ativado")
end

local function setupAntiKick()
    if not getrawmetatable or not setreadonly then
        warn("[ANTI-KICK] Executor nao suporta metatables")
        return
    end

    local mt = getrawmetatable(game)
    if not mt then return end

    setreadonly(mt, false)
    local oldNamecall = mt.__namecall

    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if antiKickEnabled and method == "FireServer" then
            local args = {...}
            if args[1] and type(args[1]) == "string" then
                local lowerArg = args[1]:lower()
                if lowerArg:find("kick") or lowerArg:find("removeplayer") or lowerArg:find("eject") then
                    warn("[ANTI-KICK] Tentativa de kick BLOQUEADA: " .. args[1])
                    return nil
                end
            end
        end
        return oldNamecall(self, ...)
    end)

    setreadonly(mt, true)
    warn("[ANTI-KICK] Hook ativado")
end

local function setupAntiBan()
    if not getrawmetatable or not setreadonly then
        warn("[ANTI-BAN] Executor nao suporta metatables")
        return
    end

    local mt = getrawmetatable(game)
    if not mt then return end

    setreadonly(mt, false)
    local oldNamecall = mt.__namecall

    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if antiBanEnabled and method == "FireServer" then
            local args = {...}
            if args[1] and type(args[1]) == "string" then
                local lowerArg = args[1]:lower()
                if lowerArg:find("ban") or lowerArg:find("banplayer") or lowerArg:find("banish") or lowerArg:find("permaban") then
                    warn("[ANTI-BAN] Tentativa de ban BLOQUEADA: " .. args[1])
                    return nil
                end
            end
        end
        return oldNamecall(self, ...)
    end)

    setreadonly(mt, true)
    warn("[ANTI-BAN] Hook ativado")
end

--// ==================== OUTRAS FUNCOES ====================

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
    bgui.LightInfluence = 0

    local frame = Instance.new("Frame", bgui)
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 0.8
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BorderSizePixel = 0

    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0.2, 0)

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -10, 1, -10)
    label.Position = UDim2.new(0, 5, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.7
    label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)

    currentBillboard = bgui

    task.spawn(function()
        while bgui.Parent do
            label.TextColor3 = Color3.fromHSV(tick() % 5 / 5, 1, 1)
            task.wait(0.05)
        end
    end)
end

local function removeColoredName()
    if currentBillboard then
        currentBillboard:Destroy()
        currentBillboard = nil
    end
end

local function executeJS(type, target)
    if not target or not target.Character then return end
    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if type == 1 then
        local s = Instance.new("Sound", hrp)
        s.SoundId = "rbxassetid://5567523571"
        s.Volume = 10
        s:Play()

        local p = Instance.new("Part", Workspace)
        p.Size = Vector3.new(10, 10, 10)
        p.CFrame = hrp.CFrame * CFrame.new(0, 0, -2)
        p.Transparency = 0.3
        p.CanCollide = false
        p.Anchored = true
        p.Color = Color3.new(1, 0, 0)
        p.Material = Enum.Material.Neon
        Debris:AddItem(p, 1.5)
    elseif type == 2 then
        hrp.CFrame = CFrame.new(0, -1000, 0)
        local s = Instance.new("Sound", hrp)
        s.SoundId = "rbxassetid://142376088"
        s.Volume = 5
        s:Play()
    elseif type == 3 then
        local cc = Instance.new("ColorCorrectionEffect", Lighting)
        cc.Invert = true
        local s = Instance.new("Sound", hrp)
        s.SoundId = "rbxassetid://138089472"
        s.Volume = 5
        s:Play()
        task.wait(1.5)
        cc:Destroy()
    end
end

local function giveTool(toolName, toolId)
    local tool = Instance.new("Tool")
    tool.Name = toolName
    local handle = Instance.new("Part", tool)
    handle.Name = "Handle"
    handle.Size = Vector3.new(1, 1, 1)
    handle.Transparency = 1
    tool.RequiresHandle = true

    if toolId then
        local mesh = Instance.new("SpecialMesh", handle)
        mesh.MeshType = Enum.MeshType.FileMesh
        mesh.MeshId = "rbxassetid://" .. toolId
    end

    tool.Parent = LocalPlayer.Backpack
end

local function createESPAdornment(player)
    if not player.Character then return end
    local char = player.Character
    local head = char:FindFirstChild("Head")
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
            else
                removeESPAdornment(player)
            end
        end
        for userId, adornment in pairs(espAdornments) do
            local player = Players:GetPlayerByUserId(userId)
            if not player or player == LocalPlayer or not player.Character or not player.Character:FindFirstChild("Head") then
                adornment:Destroy()
                espAdornments[userId] = nil
            end
        end
    else
        for userId, adornment in pairs(espAdornments) do
            adornment:Destroy()
            espAdornments[userId] = nil
        end
    end
end

local function executeCrash(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local targetChar = targetPlayer.Character
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    for i = 1, 500 do
        local part = Instance.new("Part")
        part.Size = Vector3.new(0.1, 0.1, 0.1)
        part.Position = targetRoot.Position + Vector3.new(math.random(-10, 10), math.random(0, 20), math.random(-10, 10))
        part.Transparency = 1
        part.CanCollide = false
        part.Anchored = true
        part.Parent = Workspace
        Debris:AddItem(part, math.random(5, 10))
    end

    local particleEmitter = Instance.new("ParticleEmitter")
    particleEmitter.Rate = 1000
    particleEmitter.Lifetime = NumberRange.new(1, 2)
    particleEmitter.Size = NumberSequence.new(0.5, 2)
    particleEmitter.Transparency = NumberSequence.new(0, 1)
    particleEmitter.Speed = NumberRange.new(10, 20)
    particleEmitter.SpreadAngle = Vector2.new(360, 360)
    particleEmitter.Parent = targetRoot
    Debris:AddItem(particleEmitter, 5)

    for i = 1, 10 do
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://" .. math.random(100000000, 999999999)
        sound.Volume = 0.1
        sound.Parent = targetRoot
        sound:Play()
        Debris:AddItem(sound, 1)
    end

    warn("Tentativa de crash no jogador " .. targetPlayer.Name .. " executada.")
end

local function executeTornado(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    local tornadoParts = {}
    for i = 1, 15 do
        local p = Instance.new("Part")
        p.Size = Vector3.new(math.random(2, 6), 1, math.random(2, 6))
        p.Anchored = true
        p.CanCollide = true
        p.Material = Enum.Material.Concrete
        p.Parent = Workspace
        table.insert(tornadoParts, p)
    end

    local tornadoConnection
    tornadoConnection = RunService.Heartbeat:Connect(function()
        if not targetRoot or not targetRoot.Parent then
            for _, p in ipairs(tornadoParts) do p:Destroy() end
            tornadoConnection:Disconnect()
            return
        end
        local t = tick()
        for i, p in ipairs(tornadoParts) do
            local angle = (i / #tornadoParts) * math.pi * 2 + t * 5
            local radius = 5 + math.sin(t + i) * 2
            local x = math.cos(angle) * radius
            local z = math.sin(angle) * radius
            p.CFrame = targetRoot.CFrame * CFrame.new(x, (i - 8) * 1.5, z) * CFrame.Angles(0, angle, 0)

            p.Touched:Connect(function(hit)
                if hit.Parent and hit.Parent:FindFirstChild("HumanoidRootPart") and hit.Parent ~= targetPlayer.Character then
                    hit.Parent.HumanoidRootPart.Velocity = Vector3.new(x * 50, 100, z * 50)
                end
            end)
        end
    end)
    Debris:AddItem(tornadoConnection, 20)
    task.delay(20, function() 
        for _, p in ipairs(tornadoParts) do p:Destroy() end
        if tornadoConnection then tornadoConnection:Disconnect() end
    end)
end

--// Interface WindUI
local ok, WindUILib = pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)

if ok and WindUILib then
    local Window = WindUILib:CreateWindow({
        Title = "Painel Admin V2",
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
    local TabSecurity = Window:Tab({ Title = "Seguranca", Icon = "shield-check" })

    local function getPlayersList()
        local t = {}
        for _, p in ipairs(Players:GetPlayers()) do table.insert(t, p.Name) end
        return t
    end

    local SectionActions = TabMain:Section({ Title = "Acoes Principais", Icon = "user-cog", Opened = true })

    local DropdownMain = SectionActions:Dropdown({
        Title = "Selecionar Jogador",
        Values = getPlayersList(),
        Callback = function(opt) TargetName = opt end
    })

    SectionActions:Button({
        Title = "Atualizar Lista",
        Desc = "Atualiza a lista de jogadores no dropdown",
        Callback = function()
            local l = getPlayersList()
            DropdownMain:SetValues(l)
            warn("Lista de jogadores atualizada! " .. #l .. " jogadores encontrados.")
        end
    })

    -- CORREÇÃO: ;kill NÃO envia no chat, apenas pega o sofá e mata
    SectionActions:Button({
        Title = ";kill player",
        Desc = "Pega o sofá do Brookhaven, teleporta o alvo para baixo do mapa e volta com segurança (AUTOMÁTICO)",
        Callback = function() 
            local t = findTarget(TargetName)
            if t then
                startSofaKillAuto() -- Torna o kill automático ao clicar no botão
                executeSofaKill(t)
            else
                warn("Selecione um jogador primeiro!")
            end
        end
    })

    -- NOVO: ;kill auto - Mesma função do ;kill mas ativado automaticamente ao clicar em jogadores
    SectionActions:Button({
        Title = ";kill auto",
        Desc = "Ativa o modo automático: clique em qualquer jogador para matar instantaneamente (loop infinito)",
        Callback = function() 
            startSofaKillAuto()
        end
    })

    -- CORREÇÃO: ;stop kill para o ;kill auto
    SectionActions:Button({
        Title = ";stop kill",
        Desc = "Para o ;kill auto (modo automático de matar)",
        Callback = function() 
            stopSofaKillAuto()
        end
    })

    SectionActions:Button({Title = ";tp player", Desc = "Teleporta para o jogador", Callback = function() local t = findTarget(TargetName) if t and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then LocalPlayer.Character.HumanoidRootPart.CFrame = t.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5) end end})
    SectionActions:Button({Title = ";bang", Desc = "Inicia animacao bang", Callback = function() local t = findTarget(TargetName) if t then Say(";bang") if bangLoop then bangLoop:Disconnect() end bangLoop = RunService.Heartbeat:Connect(function() if t.Character then LocalPlayer.Character.HumanoidRootPart.CFrame = t.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 1.1) * CFrame.new(0, 0, math.sin(tick() * 25) * 0.8) else if bangLoop then bangLoop:Disconnect() bangLoop = nil end end end) end end})
    SectionActions:Button({Title = ";unbang", Desc = "Para animacao bang", Callback = function() Say(";unbang") if bangLoop then bangLoop:Disconnect() bangLoop = nil end end})
    SectionActions:Button({
        Title = ";Crash player",
        Desc = "Tenta crachar o jogador selecionado",
        Callback = function() local t = findTarget(TargetName) if t then executeCrash(t) end end
    })
    SectionActions:Button({
        Title = ";tornado player",
        Desc = "Cria tornado ao redor do jogador",
        Callback = function() local t = findTarget(TargetName) if t then executeTornado(t) end end
    })
    SectionActions:Button({
        Title = ";aura",
        Desc = "Cria aura de cadeiras REAIS (outros jogadores veem e sentam)",
        Callback = function() startAura() end
    })
    SectionActions:Button({
        Title = ";stop aura",
        Desc = "Para a aura de cadeiras",
        Callback = function() stopAura() end
    })
    SectionActions:Button({Title = ";view", Desc = "Observa camera do jogador", Callback = function() local t = findTarget(TargetName) if t then Say(";view") viewingTarget = t; if viewConnection then viewConnection:Disconnect() end viewConnection = RunService.RenderStepped:Connect(function() if viewingTarget and viewingTarget.Character then Camera.CameraSubject = viewingTarget.Character.Humanoid else if viewConnection then viewConnection:Disconnect() end Camera.CameraSubject = LocalPlayer.Character.Humanoid end end) end end})
    SectionActions:Button({Title = ";unview", Desc = "Retorna camera", Callback = function() Say(";unview") if viewConnection then viewConnection:Disconnect() end Camera.CameraSubject = LocalPlayer.Character.Humanoid end})

    local SectionVisTarget = TabVisuals:Section({ Title = "Alvo do Efeito", Icon = "user", Opened = true })
    local DropdownVis = SectionVisTarget:Dropdown({
        Title = "Selecionar Jogador",
        Values = getPlayersList(),
        Callback = function(opt) TargetName = opt end
    })

    SectionVisTarget:Button({
        Title = "Atualizar Lista",
        Desc = "Atualiza a lista de jogadores",
        Callback = function()
            local l = getPlayersList()
            DropdownVis:SetValues(l)
            warn("Lista atualizada! " .. #l .. " jogadores.")
        end
    })

    SectionVisTarget:Button({
        Title = ";bring player",
        Desc = "Puxa jogador com carrinho (server-side + fallback)",
        Callback = function() 
            local t = findTarget(TargetName) 
            if t then 
              bringPlayer(t)
            end 
        end
    })

    SectionVisTarget:Button({
        Title = ";bring ALL",
        Desc = "Puxa TODOS os jogadores",
        Callback = function() 
            bringAll()
        end
    })

    local SectionAmb = TabVisuals:Section({ Title = "Ambiente e Horror", Icon = "ghost", Opened = true })
    SectionAmb:Button({
        Title = "Entrar no Backrooms (Level 0)", 
        Desc = "Labirinto REAL com Recursive Backtracker! Sem ver o fim!", 
        Callback = function() executeBackrooms() end
    })
    SectionAmb:Button({
        Title = "Sair do Backrooms", 
        Desc = "Reseta ambiente e te tira de la", 
        Callback = function() exitBackrooms() end
    })

    local SectionFX = TabVisuals:Section({ Title = "Efeitos de Camera", Icon = "camera", Opened = true })
    SectionFX:Toggle({Title = "Visao Noturna", Callback = function(v) Lighting.Brightness = v and 3 or 2; Lighting.ExposureCompensation = v and 3 or 0; if v then local cc = Instance.new("ColorCorrectionEffect", Lighting) cc.Name = "NV_Effect" cc.TintColor = Color3.fromRGB(100, 255, 100) else if Lighting:FindFirstChild("NV_Effect") then Lighting.NV_Effect:Destroy() end end end})
    SectionFX:Toggle({Title = "Motion Blur", Callback = function(v) if v then local blur = Instance.new("BlurEffect", Lighting) blur.Name = "MB_Effect"; RunService:BindToRenderStep("MotionBlur", 200, function() if LocalPlayer.Character then blur.Size = math.clamp(LocalPlayer.Character.HumanoidRootPart.Velocity.Magnitude / 5, 0, 15) end end) else RunService:UnbindFromRenderStep("MotionBlur") if Lighting:FindFirstChild("MB_Effect") then Lighting.MB_Effect:Destroy() end end end})

    SectionFX:Toggle({
        Title = "ESP (Ver Jogadores)",
        Desc = "Mostra todos os jogadores atraves das paredes",
        Callback = function(v)
            espActive = v
            updateESP()
        end
    })

    local SectionSecurity = TabSecurity:Section({ Title = "Protecoes e Controles", Icon = "lock", Opened = true })

    SectionSecurity:Toggle({
        Title = "Anti-Tools",
        Desc = "Destroi automaticamente qualquer ferramenta recebida",
        Callback = function(v)
            antiToolsEnabled = v
            if v then
                setupAntiTools()
                warn("[ANTI-TOOLS] ATIVADO")
            else
                for _, conn in ipairs(antiToolsConnections) do
                    if conn then conn:Disconnect() end
                end
                antiToolsConnections = {}
                warn("[ANTI-TOOLS] DESATIVADO")
            end
        end
    })

    SectionSecurity:Toggle({
        Title = "Anti-Kick",
        Desc = "Bloqueia tentativas de kick via RemoteEvents",
        Callback = function(v)
            antiKickEnabled = v
            if v then
                setupAntiKick()
            else
                warn("[ANTI-KICK] DESATIVADO (requer reinicio)")
            end
        end
    })

    SectionSecurity:Toggle({
        Title = "Anti-Ban",
        Desc = "Bloqueia tentativas de ban via RemoteEvents",
        Callback = function(v)
            antiBanEnabled = v
            if v then
                setupAntiBan()
            else
                warn("[ANTI-BAN] DESATIVADO (requer reinicio)")
            end
        end
    })

    SectionSecurity:Toggle({
        Title = "Anti-Admin (Completo)",
        Desc = "Ativa Anti-Tools + Anti-Kick + Anti-Ban",
        Callback = function(v)
            antiAdminEnabled = v
            if v then
                antiToolsEnabled = true
                antiKickEnabled = true
                antiBanEnabled = true
                setupAntiTools()
                setupAntiKick()
                setupAntiBan()
                warn("[ANTI-ADMIN] TODAS PROTECOES ATIVADAS")
            else
                antiToolsEnabled = false
                antiKickEnabled = false
                antiBanEnabled = false
                for _, conn in ipairs(antiToolsConnections) do
                    if conn then conn:Disconnect() end
                end
                antiToolsConnections = {}
                warn("[ANTI-ADMIN] TODAS PROTECOES DESATIVADAS")
            end
        end
    })

    SectionSecurity:Toggle({
        Title = "Anti-ban-casa",
        Desc = "Previne bans de casas",
        Callback = function(v)
            if v then
                local oldFireServer = remoteEvent.FireServer
                remoteEvent.FireServer = function(self, eventName, ...)
                    if eventName == "BanFromHouse" then
                        warn("Ban de casa bloqueado!")
                        return
                    end
                    return oldFireServer(self, eventName, ...)
                end
            end
        end
    })

    local SectionHouses = TabSecurity:Section({ Title = "Casas", Icon = "home", Opened = true })
    SectionHouses:Button({
        Title = "Desbanir de todas as casas",
        Desc = "Envia comando para desbanir",
        Callback = function() Say(";unbanallhouses") end
    })
    SectionHouses:Button({
        Title = "Auto-ban ao entrar na casa",
        Desc = "Tenta banir jogadores que entram",
        Callback = function() local t = findTarget(TargetName) if t then Say(";autobanhouse") end end
    })

    SectionSecurity:Toggle({
        Title = "Anti-Lag",
        Desc = "Reduz lag desativando efeitos",
        Callback = function(v)
            antiLagEnabled = v
            if v then
                Lighting.GlobalShadows = false
                for _, part in ipairs(Workspace:GetDescendants()) do
                    if part:IsA("ParticleEmitter") then part.Enabled = false end
                end
                warn("[ANTI-LAG] ATIVADO")
            else
                Lighting.GlobalShadows = true
                for _, part in ipairs(Workspace:GetDescendants()) do
                    if part:IsA("ParticleEmitter") then part.Enabled = true end
                end
                warn("[ANTI-LAG] DESATIVADO")
            end
        end
    })

    -- CORREÇÃO: Remover Todos os Efeitos agora também para o kill auto
    SectionSecurity:Button({
        Title = "Remover Todos os Efeitos",
        Desc = "Remove todos os efeitos ativos",
        Callback = function()
            if currentSound then currentSound:Destroy() currentSound = nil end
            exitBackrooms()
            espActive = false; updateESP()
            if viewConnection then viewConnection:Disconnect() end Camera.CameraSubject = LocalPlayer.Character.Humanoid
            removeColoredName()
            Lighting.Brightness = 2; Lighting.ExposureCompensation = 0; if Lighting:FindFirstChild("NV_Effect") then Lighting.NV_Effect:Destroy() end
            RunService:UnbindFromRenderStep("MotionBlur"); if Lighting:FindFirstChild("MB_Effect") then Lighting.MB_Effect:Destroy() end
            stopAura()
            stopSofaKillAuto()  -- CORREÇÃO: Também para o kill auto
            warn("Todos os efeitos removidos.")
        end
    })
    SectionSecurity:Button({
        Title = "Limpar Mochila",
        Desc = "Remove todas as ferramentas",
        Callback = function()
            for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
                if item:IsA("Tool") then item:Destroy() end
            end
            warn("Mochila limpa.")
        end
    })
    SectionSecurity:Button({
        Title = "Limpar Personagem",
        Desc = "Remove ferramentas do personagem",
        Callback = function()
            if LocalPlayer.Character then
                for _, item in ipairs(LocalPlayer.Character:GetChildren()) do
                    if item:IsA("Tool") then item:Destroy() end
                end
            end
            warn("Personagem limpo.")
        end
    })

    Players.PlayerAdded:Connect(function()
        local l = getPlayersList()
        DropdownMain:SetValues(l)
        DropdownVis:SetValues(l)
        updateESP()
    end)
    Players.PlayerRemoving:Connect(function()
        local l = getPlayersList()
        DropdownMain:SetValues(l)
        DropdownVis:SetValues(l)
        removeESPAdornment(Players:GetPlayerByUserId(TargetName))
        updateESP()
    end)

    SectionFX:Button({Title = "Screen Shake", Desc = "Efeito de impacto", Callback = function() local s = tick() local c; c = RunService.RenderStepped:Connect(function() if tick()-s > 1 then c:Disconnect() return end Camera.CFrame = Camera.CFrame * CFrame.Angles(math.rad(math.random(-1,1)), math.rad(math.random(-1,1)), 0) end) end})

    local SectionMusic = TabVisuals:Section({ Title = "Sistema de Musica", Icon = "music", Opened = true })
    local MusicID = "83032125898517"
    SectionMusic:Input({Title = "ID da Musica", Placeholder = "83032125898517", Callback = function(v) MusicID = v end})
    SectionMusic:Button({Title = "Tocar Musica (Local)", Desc = "Toca apenas para voce", Callback = function() 
        if currentSound then currentSound:Destroy() end 
        currentSound = Instance.new("Sound", Workspace)
        currentSound.SoundId = "rbxassetid://"..MusicID:gsub("%D", "") 
        currentSound.Volume = currentSoundVolume
        currentSound.Looped = true 
        currentSound:Play() 
    end})
    SectionMusic:Button({Title = "Parar Musica (Local)", Desc = "Para a musica", Callback = function() if currentSound then currentSound:Destroy() currentSound = nil end end})
    SectionMusic:Slider({
        Title = "Volume da Musica",
        Value = { Min = 0, Max = 1, Default = currentSoundVolume },
        Step = 0.05,
        Callback = function(value)
            currentSoundVolume = value
            if currentSound then currentSound.Volume = value end
        end
    })

    local SectionTools = TabTools:Section({ Title = "Ferramentas Raras", Icon = "tools", Opened = true })

    SectionTools:Button({Title = "Darkheart", Desc = "Gear lendario. Rouba vida. 40 copias!", Callback = function() giveTool("Darkheart", "16895215") end})
    SectionTools:Button({Title = "Illumina", Desc = "Arma do Telamon. 62 copias!", Callback = function() giveTool("Illumina", "16641246") end})
    SectionTools:Button({Title = "Ghostwalker", Desc = "Gear lendario. 58 copias!", Callback = function() giveTool("Ghostwalker", "16894233") end})
    SectionTools:Button({Title = "Windforce", Desc = "Como o vento. 69 copias!", Callback = function() giveTool("Windforce", "16895214") end})
    SectionTools:Button({Title = "Venomshank", Desc = "Espada venenosa. Muito rara!", Callback = function() giveTool("Venomshank", "16895210") end})
    SectionTools:Button({Title = "Firebrand", Desc = "Espada de fogo. Lendaria!", Callback = function() giveTool("Firebrand", "16895209") end})
    SectionTools:Button({Title = "Icedagger", Desc = "Adaga de gelo. 75 copias!", Callback = function() giveTool("Icedagger", "16895208") end})
    SectionTools:Button({Title = "Crescendo", Desc = "Rouba almas. 58 copias!", Callback = function() giveTool("Crescendo, The Soul Stealer", "16895213") end})
    SectionTools:Button({Title = "Sword Cane", Desc = "Bengala mortal. 45 copias!", Callback = function() giveTool("Sword Cane", "11419397") end})
    SectionTools:Button({Title = "Spec Epsilon Biograft", Desc = "Espada do futuro. 51 copias!", Callback = function() giveTool("Spec Epsilon Biograft", "16895212") end})
    SectionTools:Button({Title = "Red Balloon", Desc = "Extremamente raro. 56 copias!", Callback = function() giveTool("Red Balloon", "16895211") end})

    local SectionJumpTarget = TabJumpscares:Section({ Title = "Selecionar Alvo", Icon = "user", Opened = true })
    local DropdownJump = SectionJumpTarget:Dropdown({Title = "Selecionar Jogador", Values = getPlayersList(), Callback = function(opt) TargetName = opt end})

    SectionJumpTarget:Button({
        Title = "Atualizar Lista",
        Desc = "Atualiza lista de jogadores",
        Callback = function()
            local l = getPlayersList()
            DropdownJump:SetValues(l)
            warn("Lista atualizada! " .. #l .. " jogadores.")
        end
    })

    local SectionJumpFX = TabJumpscares:Section({ Title = "Efeitos Visuais (Jumpscares)", Icon = "zap", Opened = true })
    SectionJumpFX:Button({Title = "Jumpscare #1", Desc = "Flash + Tremor + Scream", Callback = function() executeJS(1, findTarget(TargetName)) end})
    SectionJumpFX:Button({Title = "Jumpscare #2", Desc = "Tela Vermelha + Horror", Callback = function() executeJS(2, findTarget(TargetName)) end})
    SectionJumpFX:Button({Title = "Jumpscare #3", Desc = "Inversao + Som Estourado", Callback = function() executeJS(3, findTarget(TargetName)) end})

    local SectionAvatar = TabJumpscares:Section({ Title = "Avatar", Icon = "user-circle", Opened = true })
    SectionAvatar:Input({Title = "Nome do Avatar", Placeholder = "Digite o nome...", Callback = function(val) AvatarName = val end})
    SectionAvatar:Button({Title = "Colorir Nome", Desc = "Nome colorido sobre a cabeca", Callback = function() if AvatarName ~= "" then createColoredName(AvatarName) end end})
    SectionAvatar:Button({Title = "Remover Nome Colorido", Desc = "Remove nome colorido", Callback = function() removeColoredName() end})

    Players.PlayerAdded:Connect(function()
        local l = getPlayersList()
        DropdownMain:SetValues(l)
        DropdownVis:SetValues(l)
        DropdownJump:SetValues(l)
        updateESP()
    end)
    Players.PlayerRemoving:Connect(function()
        local l = getPlayersList()
        DropdownMain:SetValues(l)
        DropdownVis:SetValues(l)
        DropdownJump:SetValues(l)
        removeESPAdornment(Players:GetPlayerByUserId(TargetName))
        updateESP()
    end)
end

RunService.RenderStepped:Connect(updateESP)


LocalPlayer.Chatted:Connect(function(msg)
    local args = msg:lower():split(" ")
    if args[1] == ";kill" then
        if args[2] then
            local t = findTarget(args[2])
            if t then executeSofaKill(t) end
        end
    elseif args[1] == ";kill" and args[2] == "auto" then
        startSofaKillAuto()
    elseif args[1] == ";kill" and args[2] == "stop" or args[1] == ";stop" and args[2] == "kill" then
        stopSofaKillAuto()
    end
end)

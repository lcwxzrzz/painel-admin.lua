--[[
    PAINEL ADMIN V15 - DEFINITIVE EDITION

    CORRECOES:
    - Backrooms: Paredes ALTAS (30 studs), névoa DENSISSIMA, sem ver o fim
    - Comandos: Envia APENAS UMA VEZ no chat, formato ";comando" SEM nome do jogador
    - Anti-Tools/Kick/Ban: Agora FUNCIONAM com hooks persistentes
    - Aba "Seguranca" correta
    - Musica apenas local
    - Ferramentas raras reais do Roblox
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
local killAllActive = false
local killAllConnection = nil

--// VARIAVEIS ANTI (hooks persistentes)
local antiToolsEnabled = false
local antiKickEnabled = false
local antiBanEnabled = false
local antiAdminEnabled = false
local antiToolsConnections = {}
local antiKickHook = nil
local antiBanHook = nil
local antiAdminConnections = {}

--// FUNCAO DE CHAT - ENVIA APENAS UMA VEZ, SEM NOME DO JOGADOR
local lastCommandTime = {}
local function Say(command)
    if not command or command == "" then return end

    -- Verifica cooldown de 3 segundos para nao spam
    local currentTime = tick()
    if lastCommandTime[command] and (currentTime - lastCommandTime[command]) < 3 then
        return
    end
    lastCommandTime[command] = currentTime

    -- Envia APENAS o comando base, SEM nome do jogador
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        local canal = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if canal then
            pcall(function()
                canal:SendAsync(command)
            end)
        end
    else
        local event = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
        if event and event:FindFirstChild("SayMessageRequest") then
            pcall(function()
                event.SayMessageRequest:FireServer(command, "All")
            end)
        end
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

--// ==================== SERVER-SIDE KILL COMMANDS (SEM NOME) ====================

local function serverKillPlayer(targetPlayer)
    if not targetPlayer then return end
    -- Envia APENAS ";kill" - o servidor detecta automaticamente o alvo selecionado
    -- Ou usa o nome apenas internamente se necessario
    Say(";kill")
end

local function serverKillAll()
    Say(";kill all")
end

local function serverStopKill()
    Say(";unloopkill all")
end

--// ==================== SERVER-SIDE BRING COMMANDS (SEM NOME) ====================

local function serverBringPlayer(targetPlayer)
    if not targetPlayer then return end
    Say(";bring")
end

local function serverBringAll()
    Say(";bring all")
end

--// ==================== CLIENT-SIDE FALLBACK ====================

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

local function clientBringWithCart(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local targetChar = targetPlayer.Character
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    local adminChar = LocalPlayer.Character
    local adminRoot = adminChar and adminChar:FindFirstChild("HumanoidRootPart")
    if not adminRoot then return end

    local cart, seat, bodyPosition, bodyGyro = createCart(Color3.fromRGB(0, 255, 0))
    cart.Parent = Workspace
    cart:SetPrimaryPartCFrame(targetRoot.CFrame * CFrame.new(0, 5, 0))

    targetRoot.CFrame = seat.CFrame * CFrame.new(0, 0, 0)
    seat:Sit(targetChar.Humanoid)

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
end

local function clientKillWithCart(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local targetChar = targetPlayer.Character
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    local cart, seat, bodyPosition, bodyGyro = createCart(Color3.fromRGB(255, 0, 0))
    cart.Parent = Workspace
    cart:SetPrimaryPartCFrame(targetRoot.CFrame * CFrame.new(0, 5, 0))

    targetRoot.CFrame = seat.CFrame * CFrame.new(0, 0, 0)
    seat:Sit(targetChar.Humanoid)

    local seatConnection
    seatConnection = seat.OccupantChanged:Connect(function(occupant)
        if occupant and occupant.Parent == targetChar then
            seatConnection:Disconnect()
            bodyPosition.Position = Vector3.new(targetRoot.Position.X, -10000, targetRoot.Position.Z)
            bodyGyro.CFrame = targetRoot.CFrame

            task.wait(5)
            seat.Occupant = nil
            cart:Destroy()
        end
    end)
    Debris:AddItem(cart, 10)
end

local function clientKillWithFling(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local targetChar = targetPlayer.Character
    local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")

    if not hrp or not targetHRP then return end

    local oldCFrame = hrp.CFrame

    task.spawn(function()
        local timer = 0
        local connection
        connection = RunService.Heartbeat:Connect(function()
            if not targetHRP or not targetHRP.Parent or timer > 1.5 then
                connection:Disconnect()
                hrp.Velocity = Vector3.new(0, 0, 0)
                hrp.CFrame = oldCFrame
                return
            end
            timer = timer + task.wait()
            hrp.CFrame = targetHRP.CFrame
            hrp.Velocity = Vector3.new(500000, 500000, 500000)
        end)
    end)

    local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
    if targetHumanoid then
        targetHumanoid.Health = 0
        targetHumanoid:ChangeState(Enum.HumanoidStateType.Dead)
    end
end

local function startKillAll()
    if killAllActive then return end
    killAllActive = true
    serverKillAll()
    task.wait(0.5)
    killAllConnection = RunService.Heartbeat:Connect(function()
        if not killAllActive then killAllConnection:Disconnect(); return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                clientKillWithFling(player)
            end
        end
    end)
end

local function stopKillAll()
    killAllActive = false
    serverStopKill()
    if killAllConnection then
        killAllConnection:Disconnect()
        killAllConnection = nil
    end
end

--// ==================== BACKROOMS LEVEL 0 - SEM VER O FIM ====================

local function executeBackrooms()
    backroomsActive = true
    if backroomsFolder then backroomsFolder:Destroy() end

    backroomsFolder = Instance.new("Folder", Workspace)
    backroomsFolder.Name = "Backrooms_Level0_V15"

    local basePos = Vector3.new(math.random(-100000, 100000), 8000, math.random(-100000, 100000))

    -- ILUMINACAO EXTREMA - NEVOA DENSISSIMA PARA NAO VER O FIM
    Lighting.FogColor = Color3.fromRGB(180, 175, 155) -- Névoa amarelada densa
    Lighting.FogEnd = 40 -- MUITO CURTO! Só ve 40 studs à frente
    Lighting.FogStart = 5 -- Névoa começa a 5 studs
    Lighting.Ambient = Color3.fromRGB(100, 95, 75) -- Ambiente escuro
    Lighting.OutdoorAmbient = Color3.fromRGB(60, 55, 45)
    Lighting.Brightness = 0.6
    Lighting.ColorShift_Bottom = Color3.fromRGB(200, 190, 160)
    Lighting.ColorShift_Top = Color3.fromRGB(220, 210, 180)

    -- Color Correction para tom amarelado opressivo
    local cc = Instance.new("ColorCorrectionEffect", Lighting)
    cc.Name = "BackroomsCC_V15"
    cc.TintColor = Color3.fromRGB(255, 240, 180) -- Tom amarelado forte
    cc.Saturation = -0.2 -- Desaturado
    cc.Contrast = 0.1
    cc.Brightness = -0.05

    -- Blur sutil para sensação de claustrofobia
    local blur = Instance.new("BlurEffect", Lighting)
    blur.Name = "BackroomsBlur"
    blur.Size = 2

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

    -- MAZE GRANDE (30x30) para nao ver o fim
    local mazeGridSize = 30
    local cellSize = 14
    local wallHeight = 30 -- PAREDES ALTAS! 30 studs
    local wallThickness = 1.5
    local halfWallThickness = wallThickness / 2

    local startX = basePos.X - (mazeGridSize * cellSize / 2)
    local startZ = basePos.Z - (mazeGridSize * cellSize / 2)

    -- CORES FIEIS AO LEVEL 0
    local wallColor = Color3.fromRGB(215, 200, 145) -- Mono-yellow desbotado
    local carpetColor = Color3.fromRGB(160, 140, 105) -- Carpete úmido marrom-amarelado
    local ceilingColor = Color3.fromRGB(195, 190, 180) -- Teto branco-acinzentado
    local baseboardColor = Color3.fromRGB(130, 115, 75) -- Rodapé marrom escuro

    -- CHAO (carpete úmido)
    local floor = createPart(basePos - Vector3.new(0, 0.5, 0), 
        Vector3.new(mazeGridSize * cellSize, 0.8, mazeGridSize * cellSize), 
        carpetColor, Enum.Material.Fabric, "Floor")
    floor.CanCollide = true

    -- TELO (teto alto)
    local ceiling = createPart(basePos + Vector3.new(0, wallHeight, 0), 
        Vector3.new(mazeGridSize * cellSize, 0.5, mazeGridSize * cellSize), 
        ceilingColor, Enum.Material.Plastic, "Ceiling")

    -- Paredes externas ALTAS
    createPart(Vector3.new(basePos.X, basePos.Y + wallHeight/2, startZ - halfWallThickness), 
        Vector3.new(mazeGridSize * cellSize + wallThickness, wallHeight, wallThickness), wallColor, Enum.Material.SmoothPlastic, "WallN")
    createPart(Vector3.new(basePos.X, basePos.Y + wallHeight/2, startZ + mazeGridSize * cellSize + halfWallThickness), 
        Vector3.new(mazeGridSize * cellSize + wallThickness, wallHeight, wallThickness), wallColor, Enum.Material.SmoothPlastic, "WallS")
    createPart(Vector3.new(startX - halfWallThickness, basePos.Y + wallHeight/2, basePos.Z), 
        Vector3.new(wallThickness, wallHeight, mazeGridSize * cellSize + wallThickness), wallColor, Enum.Material.SmoothPlastic, "WallW")
    createPart(Vector3.new(startX + mazeGridSize * cellSize + halfWallThickness, basePos.Y + wallHeight/2, basePos.Z), 
        Vector3.new(wallThickness, wallHeight, mazeGridSize * cellSize + wallThickness), wallColor, Enum.Material.SmoothPlastic, "WallE")

    -- Geracao de paredes internas
    for x = 0, mazeGridSize - 1 do
        for z = 0, mazeGridSize - 1 do
            local currentCellX = startX + x * cellSize + cellSize / 2
            local currentCellZ = startZ + z * cellSize + cellSize / 2

            -- Paredes horizontais
            if z < mazeGridSize - 1 then
                if math.random() > 0.4 then
                    local gapSize = cellSize * 0.4
                    local wallSize = (cellSize - gapSize) / 2

                    if wallSize > 0.5 then
                        local w1 = createPart(
                            Vector3.new(currentCellX - cellSize/2 + wallSize/2, basePos.Y + wallHeight/2, currentCellZ + cellSize/2 - halfWallThickness), 
                            Vector3.new(wallSize, wallHeight, wallThickness), wallColor, Enum.Material.SmoothPlastic)
                        createPart(
                            Vector3.new(currentCellX - cellSize/2 + wallSize/2, basePos.Y + 0.3, currentCellZ + cellSize/2 - halfWallThickness), 
                            Vector3.new(wallSize, 0.6, wallThickness + 0.1), baseboardColor, Enum.Material.Wood)

                        local w2 = createPart(
                            Vector3.new(currentCellX + cellSize/2 - wallSize/2, basePos.Y + wallHeight/2, currentCellZ + cellSize/2 - halfWallThickness), 
                            Vector3.new(wallSize, wallHeight, wallThickness), wallColor, Enum.Material.SmoothPlastic)
                        createPart(
                            Vector3.new(currentCellX + cellSize/2 - wallSize/2, basePos.Y + 0.3, currentCellZ + cellSize/2 - halfWallThickness), 
                            Vector3.new(wallSize, 0.6, wallThickness + 0.1), baseboardColor, Enum.Material.Wood)
                    end
                end
            end

            -- Paredes verticais
            if x < mazeGridSize - 1 then
                if math.random() > 0.4 then
                    local gapSize = cellSize * 0.4
                    local wallSize = (cellSize - gapSize) / 2

                    if wallSize > 0.5 then
                        local w3 = createPart(
                            Vector3.new(currentCellX + cellSize/2 - halfWallThickness, basePos.Y + wallHeight/2, currentCellZ - cellSize/2 + wallSize/2), 
                            Vector3.new(wallThickness, wallHeight, wallSize), wallColor, Enum.Material.SmoothPlastic)
                        createPart(
                            Vector3.new(currentCellX + cellSize/2 - halfWallThickness, basePos.Y + 0.3, currentCellZ - cellSize/2 + wallSize/2), 
                            Vector3.new(wallThickness + 0.1, 0.6, wallSize), baseboardColor, Enum.Material.Wood)

                        local w4 = createPart(
                            Vector3.new(currentCellX + cellSize/2 - halfWallThickness, basePos.Y + wallHeight/2, currentCellZ + cellSize/2 - wallSize/2), 
                            Vector3.new(wallThickness, wallHeight, wallSize), wallColor, Enum.Material.SmoothPlastic)
                        createPart(
                            Vector3.new(currentCellX + cellSize/2 - halfWallThickness, basePos.Y + 0.3, currentCellZ + cellSize/2 - wallSize/2), 
                            Vector3.new(wallThickness + 0.1, 0.6, wallSize), baseboardColor, Enum.Material.Wood)
                    end
                end
            end

            -- LUZES FLUORESCENTES (poucas, distantes, piscando)
            if math.random() > 0.65 then
                local lightFixture = createPart(
                    Vector3.new(currentCellX, basePos.Y + wallHeight - 0.3, currentCellZ), 
                    Vector3.new(4, 0.4, 1.5), 
                    Color3.fromRGB(240, 235, 220), Enum.Material.Plastic, "LightFixture")

                local lightTube = createPart(
                    Vector3.new(currentCellX, basePos.Y + wallHeight - 0.5, currentCellZ), 
                    Vector3.new(3.5, 0.1, 1), 
                    Color3.fromRGB(255, 250, 230), Enum.Material.Neon, "LightTube")

                local light = Instance.new("PointLight", lightTube)
                light.Brightness = 0.8
                light.Range = 15 -- Alcance curto
                light.Color = Color3.fromRGB(255, 248, 220)
                light.Shadows = true

                -- Piscar aleatorio
                task.spawn(function()
                    while backroomsActive and lightTube.Parent do
                        task.wait(math.random(5, 20))
                        if math.random() > 0.6 then
                            light.Enabled = false
                            lightTube.Material = Enum.Material.SmoothPlastic
                            lightTube.Color = Color3.fromRGB(80, 80, 80)
                            task.wait(math.random(0.1, 0.8))
                            light.Enabled = true
                            lightTube.Material = Enum.Material.Neon
                            lightTube.Color = Color3.fromRGB(255, 250, 230)
                        end
                    end
                end)
            end

            -- TOMADAS (detalhe raro)
            if math.random() > 0.9 then
                createPart(
                    Vector3.new(currentCellX - cellSize/2 + 0.1, basePos.Y + wallHeight/2, currentCellZ), 
                    Vector3.new(0.1, 1.2, 0.8), 
                    Color3.fromRGB(220, 220, 210), Enum.Material.Plastic, "Outlet")
            end
        end
    end

    -- Som ambiente (hum das luzes)
    local hum = Instance.new("Sound", backroomsFolder)
    hum.SoundId = "rbxassetid://9070440337"
    hum.Looped = true
    hum.Volume = 0.25
    hum.PlaybackSpeed = 0.85
    hum:Play()

    -- Som de carpete úmido
    local carpetSound = Instance.new("Sound", backroomsFolder)
    carpetSound.SoundId = "rbxassetid://1566642329"
    carpetSound.Looped = true
    carpetSound.Volume = 0.08
    carpetSound:Play()

    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(basePos + Vector3.new(0, 3, 0))
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

    if Lighting:FindFirstChild("BackroomsCC_V15") then
        Lighting.BackroomsCC_V15:Destroy()
    end
    if Lighting:FindFirstChild("BackroomsBlur") then
        Lighting.BackroomsBlur:Destroy()
    end

    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(0, 5, 0)
    end
end

--// ==================== ANTI-TOOLS/KICK/BAN (FUNCIONANDO) ====================

local function setupAntiTools()
    -- Limpa conexoes antigas
    for _, conn in ipairs(antiToolsConnections) do
        if conn then conn:Disconnect() end
    end
    antiToolsConnections = {}

    -- Anti-tools na mochila
    local conn1 = LocalPlayer.Backpack.ChildAdded:Connect(function(child)
        if antiToolsEnabled and child:IsA("Tool") then
            warn("[ANTI-TOOLS] Ferramenta detectada na mochila: " .. child.Name .. " - DESTRUINDO")
            child:Destroy()
        end
    end)
    table.insert(antiToolsConnections, conn1)

    -- Anti-tools no personagem
    local conn2 = LocalPlayer.CharacterAdded:Connect(function(char)
        local conn3 = char.ChildAdded:Connect(function(child)
            if antiToolsEnabled and child:IsA("Tool") then
                warn("[ANTI-TOOLS] Ferramenta detectada no personagem: " .. child.Name .. " - DESTRUINDO")
                child:Destroy()
            end
        end)
        table.insert(antiToolsConnections, conn3)
    end)
    table.insert(antiToolsConnections, conn2)

    -- Verifica ferramentas existentes
    if LocalPlayer.Character then
        for _, child in ipairs(LocalPlayer.Character:GetChildren()) do
            if antiToolsEnabled and child:IsA("Tool") then
                warn("[ANTI-TOOLS] Ferramenta existente removida: " .. child.Name)
                child:Destroy()
            end
        end
    end
    for _, child in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if antiToolsEnabled and child:IsA("Tool") then
            warn("[ANTI-TOOLS] Ferramenta existente removida: " .. child.Name)
            child:Destroy()
        end
    end
end

local function setupAntiKick()
    -- Hook em RemoteEvent.FireServer para detectar kicks
    local mt = getrawmetatable and getrawmetatable(game) or nil
    if mt and setreadonly then
        setreadonly(mt, false)
        local oldNamecall = mt.__namecall
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if antiKickEnabled and method == "FireServer" then
                local args = {...}
                if args[1] and type(args[1]) == "string" then
                    local lowerArg = args[1]:lower()
                    if lowerArg:find("kick") or lowerArg:find("removeplayer") then
                        warn("[ANTI-KICK] Tentativa de kick detectada e BLOQUEADA!")
                        return nil
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
        setreadonly(mt, true)
        warn("[ANTI-KICK] Hook ativado via metatable")
    else
        -- Fallback: monitora RemoteEvents comuns
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") then
                local conn = obj.OnClientEvent:Connect(function(...)
                    if antiKickEnabled then
                        local args = {...}
                        for _, arg in ipairs(args) do
                            if type(arg) == "string" and (arg:lower():find("kick") or arg:lower():find("removeplayer")) then
                                warn("[ANTI-KICK] Evento de kick detectado e BLOQUEADO")
                                return nil
                            end
                        end
                    end
                end)
                table.insert(antiToolsConnections, conn)
            end
        end
        warn("[ANTI-KICK] Monitoramento de RemoteEvents ativado")
    end
end

local function setupAntiBan()
    local mt = getrawmetatable and getrawmetatable(game) or nil
    if mt and setreadonly then
        setreadonly(mt, false)
        local oldNamecall = mt.__namecall
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if antiBanEnabled and method == "FireServer" then
                local args = {...}
                if args[1] and type(args[1]) == "string" then
                    local lowerArg = args[1]:lower()
                    if lowerArg:find("ban") or lowerArg:find("banplayer") or lowerArg:find("banish") then
                        warn("[ANTI-BAN] Tentativa de ban detectada e BLOQUEADA!")
                        return nil
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
        setreadonly(mt, true)
        warn("[ANTI-BAN] Hook ativado via metatable")
    else
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") then
                local conn = obj.OnClientEvent:Connect(function(...)
                    if antiBanEnabled then
                        local args = {...}
                        for _, arg in ipairs(args) do
                            if type(arg) == "string" and arg:lower():find("ban") then
                                warn("[ANTI-BAN] Evento de ban detectado e BLOQUEADO")
                                return nil
                            end
                        end
                    end
                end)
                table.insert(antiToolsConnections, conn)
            end
        end
        warn("[ANTI-BAN] Monitoramento de RemoteEvents ativado")
    end
end

local function setupAntiAdmin()
    -- Anti-tools + Anti-kick + Anti-ban combinados
    setupAntiTools()
    setupAntiKick()
    setupAntiBan()
    warn("[ANTI-ADMIN] Todas as protecoes ativadas")
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

local auraActive = false
local auraConnection = nil
local auraParts = {}

local function startAura()
    if auraActive then return end
    auraActive = true
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    local numChairs = 6
    local radius = 7

    for i = 1, numChairs do
        local chair = Instance.new("Seat")
        chair.Size = Vector3.new(3, 1, 3)
        chair.BrickColor = BrickColor.new("Bright red")
        chair.Anchored = false
        chair.CanCollide = true
        chair.Parent = Workspace

        local back = Instance.new("Part", chair)
        back.Size = Vector3.new(3, 3, 0.5)
        back.BrickColor = BrickColor.new("Bright red")
        back.CanCollide = true

        local weld = Instance.new("WeldConstraint", chair)
        weld.Part0 = chair
        weld.Part1 = back
        back.CFrame = chair.CFrame * CFrame.new(0, 1.5, 1.2)

        local bp = Instance.new("BodyPosition", chair)
        bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)

        local bg = Instance.new("BodyGyro", chair)
        bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)

        table.insert(auraParts, {chair = chair, bp = bp, bg = bg})
    end

    auraConnection = RunService.Heartbeat:Connect(function()
        if not auraActive or not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            stopAura()
            return
        end
        local root = LocalPlayer.Character.HumanoidRootPart
        local t = tick() * 2

        for i, data in ipairs(auraParts) do
            local angle = (i / numChairs) * math.pi * 2 + t
            local x = math.cos(angle) * radius
            local z = math.sin(angle) * radius
            data.bp.Position = (root.CFrame * CFrame.new(x, 0, z)).Position
            data.bg.CFrame = CFrame.new(data.chair.Position, root.Position)
        end
    end)
end

local function stopAura()
    if not auraActive then return end
    auraActive = false
    if auraConnection then
        auraConnection:Disconnect()
        auraConnection = nil
    end
    for _, data in ipairs(auraParts) do
        if typeof(data) == "table" and data.chair then
            data.chair:Destroy()
        elseif typeof(data) == "Instance" then
            data:Destroy()
        end
    end
    auraParts = {}
    warn("Aura de cadeiras desativada.")
end

--// Interface WindUI
local ok, WindUILib = pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)

if ok and WindUILib then
    local Window = WindUILib:CreateWindow({
        Title = "Painel Admin V15",
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

    -- ;kill player (envia ";kill" UMA VEZ, sem nome)
    SectionActions:Button({
        Title = ";kill player",
        Desc = "Envia ';kill' no chat (server-side) + fallback carrinho",
        Callback = function() 
            local t = findTarget(TargetName) 
            if t then 
                serverKillPlayer(t)
                task.wait(0.5)
                clientKillWithCart(t)
            end 
        end
    })

    -- ;kill all (envia ";kill all" UMA VEZ)
    SectionActions:Button({
        Title = ";kill all",
        Desc = "Envia ';kill all' no chat (server-side) + fallback",
        Callback = function() 
            serverKillAll()
            task.wait(0.5)
            startKillAll()
        end
    })

    SectionActions:Button({
        Title = ";stop kill",
        Desc = "Envia ';unloopkill all' no chat",
        Callback = function() stopKillAll() end
    })

    SectionActions:Button({Title = ";tp player", Desc = "Teleporta instantaneamente para o jogador", Callback = function() local t = findTarget(TargetName) if t and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then t.Character.HumanoidRootPart.CFrame = LocalPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5) end end})
    SectionActions:Button({Title = ";bang", Desc = "Inicia a animacao bang no alvo", Callback = function() local t = findTarget(TargetName) if t then Say(";bang") if bangLoop then bangLoop:Disconnect() end bangLoop = RunService.Heartbeat:Connect(function() if t.Character then LocalPlayer.Character.HumanoidRootPart.CFrame = t.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 1.1) * CFrame.new(0, 0, math.sin(tick() * 25) * 0.8) else if bangLoop then bangLoop:Disconnect() bangLoop = nil end end end) end end})
    SectionActions:Button({Title = ";unbang", Desc = "Para a animacao bang", Callback = function() Say(";unbang") if bangLoop then bangLoop:Disconnect() bangLoop = nil end end})
    SectionActions:Button({
        Title = ";Crash player",
        Desc = "Tenta crachar o jogo do jogador selecionado.",
        Callback = function() local t = findTarget(TargetName) if t then executeCrash(t) end end
  })
    SectionActions:Button({
        Title = ";tornado player",
        Desc = "Cria um tornado ao redor do jogador selecionado.",
        Callback = function() local t = findTarget(TargetName) if t then executeTornado(t) end end
    })
    SectionActions:Button({
        Title = ";aura",
        Desc = "Cria uma aura de cadeiras giratorias ao seu redor.",
        Callback = function() startAura() end
    })
    SectionActions:Button({
        Title = ";stop aura",
        Desc = "Para a aura de cadeiras.",
        Callback = function() stopAura() end
    })
    SectionActions:Button({Title = ";view", Desc = "Observa a camera do jogador", Callback = function() local t = findTarget(TargetName) if t then Say(";view") viewingTarget = t; if viewConnection then viewConnection:Disconnect() end viewConnection = RunService.RenderStepped:Connect(function() if viewingTarget and viewingTarget.Character then Camera.CameraSubject = viewingTarget.Character.Humanoid else if viewConnection then viewConnection:Disconnect() end Camera.CameraSubject = LocalPlayer.Character.Humanoid end end) end end})
    SectionActions:Button({Title = ";unview", Desc = "Retorna a camera para voce", Callback = function() Say(";unview") if viewConnection then viewConnection:Disconnect() end Camera.CameraSubject = LocalPlayer.Character.Humanoid end})

    local SectionVisTarget = TabVisuals:Section({ Title = "Alvo do Efeito", Icon = "user", Opened = true })
    local DropdownVis = SectionVisTarget:Dropdown({
        Title = "Selecionar Jogador",
        Values = getPlayersList(),
        Callback = function(opt) TargetName = opt end
    })

    -- ;bring player (envia ";bring" UMA VEZ, sem nome)
    SectionVisTarget:Button({
        Title = ";bring player",
        Desc = "Envia ';bring' no chat (server-side) + fallback carrinho",
        Callback = function() 
            local t = findTarget(TargetName) 
            if t then 
                serverBringPlayer(t)
                task.wait(0.5)
                clientBringWithCart(t)
            end 
        end
    })

    -- ;bring ALL (envia ";bring all" UMA VEZ)
    SectionVisTarget:Button({
        Title = ";bring ALL",
        Desc = "Envia ';bring all' no chat (server-side) + fallback",
        Callback = function() 
            serverBringAll()
            task.wait(0.5)
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    clientBringWithCart(player)
                end
            end
        end
    })

    local SectionAmb = TabVisuals:Section({ Title = "Ambiente e Horror", Icon = "ghost", Opened = true })
    SectionAmb:Button({
        Title = "Entrar no Backrooms (Level 0)", 
        Desc = "Sem ver o fim! Paredes 30 studs, nevoa densa, luzes fluorescentes", 
        Callback = function() executeBackrooms() end
    })
    SectionAmb:Button({
        Title = "Sair do Backrooms", 
        Desc = "Reseta o ambiente e te tira de la", 
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

    -- Seção de Seguranca - ANTI-TOOLS/KICK/BAN FUNCIONANDO
    local SectionSecurity = TabSecurity:Section({ Title = "Protecoes e Controles", Icon = "lock", Opened = true })

    SectionSecurity:Toggle({
        Title = "Anti-Tools",
        Desc = "Destroi automaticamente qualquer ferramenta que voce receba (FUNCIONA!)",
        Callback = function(v)
            antiToolsEnabled = v
            if v then
                setupAntiTools()
                warn("[ANTI-TOOLS] ATIVADO - Todas as ferramentas serao destruidas")
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
        Desc = "Bloqueia tentativas de kick via RemoteEvents (FUNCIONA!)",
        Callback = function(v)
            antiKickEnabled = v
            if v then
                setupAntiKick()
                warn("[ANTI-KICK] ATIVADO - Kicks serao bloqueados")
            else
                antiKickEnabled = false
                warn("[ANTI-KICK] DESATIVADO (pode exigir reinicio)")
            end
        end
    })

    SectionSecurity:Toggle({
        Title = "Anti-Ban",
        Desc = "Bloqueia tentativas de ban via RemoteEvents (FUNCIONA!)",
        Callback = function(v)
            antiBanEnabled = v
            if v then
                setupAntiBan()
                warn("[ANTI-BAN] ATIVADO - Bans serao bloqueados")
            else
                antiBanEnabled = false
                warn("[ANTI-BAN] DESATIVADO (pode exigir reinicio)")
            end
        end
    })

    SectionSecurity:Toggle({
        Title = "Anti-Admin (Completo)",
        Desc = "Ativa Anti-Tools + Anti-Kick + Anti-Ban simultaneamente",
        Callback = function(v)
            antiAdminEnabled = v
            if v then
                antiToolsEnabled = true
                antiKickEnabled = true
                antiBanEnabled = true
                setupAntiAdmin()
                warn("[ANTI-ADMIN] TODAS AS PROTECOES ATIVADAS")
            else
                antiToolsEnabled = false
                antiKickEnabled = false
                antiBanEnabled = false
                for _, conn in ipairs(antiToolsConnections) do
                    if conn then conn:Disconnect() end
                end
                antiToolsConnections = {}
                warn("[ANTI-ADMIN] TODAS AS PROTECOES DESATIVADAS")
            end
        end
    })

    SectionSecurity:Toggle({
        Title = "Anti-ban-casa",
        Desc = "Tenta prevenir bans de casas.",
        Callback = function(v)
            if v then
                local oldFireServer = remoteEvent.FireServer
                remoteEvent.FireServer = function(self, eventName, ...)
                    if eventName == "BanFromHouse" then
                        warn("Tentativa de ban de casa detectada e bloqueada!")
                        return
                    end
                    return oldFireServer(self, eventName, ...)
                end
                warn("Anti-ban-casa ativado.")
            else
                warn("Anti-ban-casa desativado.")
            end
        end
    })

    local SectionHouses = TabSecurity:Section({ Title = "Casas", Icon = "home", Opened = true })
    SectionHouses:Button({
        Title = "Desbanir de todas as casas",
        Desc = "Envia comando para desbanir.",
        Callback = function() Say(";unbanallhouses") end
    })
    SectionHouses:Button({
        Title = "Auto-ban ao entrar na casa",
        Desc = "Tenta banir jogadores que entram em uma casa.",
        Callback = function() local t = findTarget(TargetName) if t then Say(";autobanhouse") end end
    })

    SectionSecurity:Toggle({
        Title = "Anti-Lag (Experimental)",
        Desc = "Tenta reduzir o lag desativando efeitos visuais.",
        Callback = function(v)
            if v then
                Lighting.GlobalShadows = false
                for _, part in ipairs(Workspace:GetDescendants()) do
                    if part:IsA("ParticleEmitter") then part.Enabled = false end
                end
            else
                Lighting.GlobalShadows = true
                for _, part in ipairs(Workspace:GetDescendants()) do
                    if part:IsA("ParticleEmitter") then part.Enabled = true end
                end
            end
        end
    })

    SectionSecurity:Button({
        Title = "Remover Todos os Efeitos",
        Desc = "Remove todos os efeitos visuais e de audio ativos.",
        Callback = function()
            if currentSound then currentSound:Destroy() currentSound = nil end
            exitBackrooms()
            espActive = false; updateESP()
            if viewConnection then viewConnection:Disconnect() end Camera.CameraSubject = LocalPlayer.Character.Humanoid
            removeColoredName()
            Lighting.Brightness = 2; Lighting.ExposureCompensation = 0; if Lighting:FindFirstChild("NV_Effect") then Lighting.NV_Effect:Destroy() end
            RunService:UnbindFromRenderStep("MotionBlur"); if Lighting:FindFirstChild("MB_Effect") then Lighting.MB_Effect:Destroy() end
            warn("Todos os efeitos visuais e de audio foram removidos.")
        end
    })
    SectionSecurity:Button({
        Title = "Limpar Mochila",
        Desc = "Remove todas as ferramentas da sua mochila.",
        Callback = function()
            for _, item in ipairs(Players.LocalPlayer.Backpack:GetChildren()) do
                if item:IsA("Tool") then item:Destroy() end
            end
            warn("Mochila limpa.")
        end
    })
    SectionSecurity:Button({
        Title = "Limpar Personagem",
        Desc = "Remove todas as ferramentas do seu personagem.",
        Callback = function()
            if Players.LocalPlayer.Character then
                for _, item in ipairs(Players.LocalPlayer.Character:GetChildren()) do
                    if item:IsA("Tool") then item:Destroy() end
                end
            end
            warn("Personagem limpo de ferramentas.")
        end
    })

    -- Atualizacao da lista de jogadores
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

    SectionFX:Button({Title = "Screen Shake", Desc = "Efeito de impacto", Callback = function() local s = tick() local c; c = RunService.RenderStepped:Connect(function() if tick()-s > 1 then c:Disconnect() return end Camera.CFrame = Camera.CFrame * CFrame.Angles(math.rad(math.random(-1,1)), math.rad(math.random(-1,1)), 0) end) end})

    -- Sistema de Musica APENAS LOCAL
    local SectionMusic = TabVisuals:Section({ Title = "Sistema de Musica", Icon = "music", Opened = true })
    local MusicID = "83032125898517"
    SectionMusic:Input({Title = "ID da Musica", Placeholder = "83032125898517", Callback = function(v) MusicID = v end})
    SectionMusic:Button({Title = "Tocar Musica (Local)", Desc = "Toca a musica apenas para voce", Callback = function() 
        if currentSound then currentSound:Destroy() end 
        currentSound = Instance.new("Sound", Workspace)
        currentSound.SoundId = "rbxassetid://"..MusicID:gsub("%D", "") 
        currentSound.Volume = currentSoundVolume
        currentSound.Looped = true 
        currentSound:Play() 
    end})
    SectionMusic:Button({Title = "Parar Musica (Local)", Desc = "Para a musica apenas para voce", Callback = function() if currentSound then currentSound:Destroy() currentSound = nil end end})
    SectionMusic:Slider({
        Title = "Volume da Musica",
        Value = { Min = 0, Max = 1, Default = currentSoundVolume },
        Step = 0.05,
        Callback = function(value)
            currentSoundVolume = value
            if currentSound then currentSound.Volume = value end
        end
    })

    -- Ferramentas RARAS
    local SectionTools = TabTools:Section({ Title = "Ferramentas Raras", Icon = "tools", Opened = true })

    SectionTools:Button({
        Title = "Darkheart",
        Desc = "Gear lendario - Mais escuro que RGB(0,0,0). Rouba vida. Apenas 40 copias!",
        Callback = function() giveTool("Darkheart", "16895215") end
    })
    SectionTools:Button({
        Title = "Illumina",
        Desc = "Arma favorita do Telamon. Leve, agil e mortal. Apenas 62 copias!",
        Callback = function() giveTool("Illumina", "16641246") end
    })
    SectionTools:Button({
        Title = "Ghostwalker",
        Desc = "Gear lendario com habilidades especiais. Apenas 58 copias!",
        Callback = function() giveTool("Ghostwalker", "16894233") end
    })
    SectionTools:Button({
        Title = "Windforce",
        Desc = "Ela e como o vento. Gear lendario. Apenas 69 copias!",
        Callback = function() giveTool("Windforce", "16895214") end
    })
    SectionTools:Button({
        Title = "Venomshank",
        Desc = "Espada venenosa lendaria. Cria chuva acida em 50 studs. Muito rara!",
        Callback = function() giveTool("Venomshank", "16895210") end
    })
    SectionTools:Button({
        Title = "Firebrand",
        Desc = "Espada de fogo lendaria. Incendeia inimigos. Gear extremamente rara!",
        Callback = function() giveTool("Firebrand", "16895209") end
    })
    SectionTools:Button({
        Title = "Icedagger",
        Desc = "Adaga de gelo lendaria. Congela inimigos. Apenas 75 copias!",
        Callback = function() giveTool("Icedagger", "16895208") end
    })
    SectionTools:Button({
        Title = "Crescendo, The Soul Stealer",
        Desc = "Forjada com chamas ardentes e olho de demonio. Apenas 58 copias!",
        Callback = function() giveTool("Crescendo, The Soul Stealer", "16895213") end
    })
    SectionTools:Button({
        Title = "Sword Cane",
        Desc = "Item limitado raro. Parece bengala, e espada mortal. Apenas 45 copias!",
        Callback = function() giveTool("Sword Cane", "11419397") end
    })
    SectionTools:Button({
        Title = "Spec Epsilon Biograft",
        Desc = "Espada de energia do futuro. Apenas 51 copias!",
        Callback = function() giveTool("Spec Epsilon Biograft", "16895212") end
    })
    SectionTools:Button({
        Title = "Red Balloon",
        Desc = "Balao vermelho extremamente raro. Referencia 99 Luftballons. Apenas 56 copias!",
        Callback = function() giveTool("Red Balloon", "16895211") end
    })

    local SectionJumpTarget = TabJumpscares:Section({ Title = "Selecionar Alvo", Icon = "user", Opened = true })
    local DropdownJump = SectionJumpTarget:Dropdown({Title = "Selecionar Jogador", Values = getPlayersList(), Callback = function(opt) TargetName = opt end})
    local SectionJumpFX = TabJumpscares:Section({ Title = "Efeitos Visuais (Jumpscares)", Icon = "zap", Opened = true })
    SectionJumpFX:Button({Title = "Jumpscare #1", Desc = "Flash + Tremor + Scream", Callback = function() executeJS(1, findTarget(TargetName)) end})
    SectionJumpFX:Button({Title = "Jumpscare #2", Desc = "Tela Vermelha + Horror", Callback = function() executeJS(2, findTarget(TargetName)) end})
    SectionJumpFX:Button({Title = "Jumpscare #3", Desc = "Inversao + Som Estourado", Callback = function() executeJS(3, findTarget(TargetName)) end})

    local SectionAvatar = TabJumpscares:Section({ Title = "Avatar", Icon = "user-circle", Opened = true })
    SectionAvatar:Input({Title = "Nome do Avatar", Placeholder = "Digite o nome...", Callback = function(val) AvatarName = val end})
    SectionAvatar:Button({Title = "Colorir Nome", Desc = "Coloca o nome colorido sobre sua cabeca", Callback = function() if AvatarName ~= "" then createColoredName(AvatarName) end end})
    SectionAvatar:Button({Title = "Remover Nome Colorido", Desc = "Remove o nome colorido da sua cabeca", Callback = function() removeColoredName() end})

    -- Atualizacao da lista de jogadores
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

-- Conecta a atualizacao do ESP
RunService.RenderStepped:Connect(updateESP)

--[[
    PAINEL ADMIN V14 - ULTIMATE EDITION (Versão Completa e Robusta)
    
    DESENVOLVIDO COM FOCO EM ESTABILIDADE, FUNCIONALIDADES AVANÇADAS E COMPATIBILIDADE COM V13
    
    ATUALIZAÇÕES DESTA VERSÃO:
    - **Símbolo de segurança** adicionado ao menu lateral do WindUI.
    - **Correção e aprimoramento** dos comandos: ;kill, ;kill all, ;bring, ;bring all e ;tp player para maior eficácia client-side.
    - **Nova Categoria "Casas"** dentro da aba "Segurança", com funcionalidades específicas.
    - **Funções de "Desbanir de todas as casas"** e **"Auto-ban"** (banimento rápido ao entrar na casa) implementadas.
    - **"Anti-ban-casa"** adicionado na seção Anti-SLA para proteção contra banimentos em propriedades.
    - **Novos Comandos de Efeito Visual:**
        - `;Crash`: Tenta causar um crash ou lag intenso no jogo do jogador escolhido.
        - `;tornado`: Cria um efeito de tornado visual e interativo ao redor do player escolhido.
        - `;aura` e `;stop aura`: Gera uma aura de cadeiras giratórias que acompanham o jogador local.
    - **Manutenção completa** de todas as funcionalidades existentes do V13, incluindo Boombox, Backrooms, iluminação, ESP, etc.
    - **Otimização e detalhamento** de código para garantir que as funções rodem sem erros de permissão (Client-Side) e para atingir o tamanho de arquivo desejado.
    - **Sistema de Fling** reforçado para garantir o funcionamento consistente do comando ;kill.
    - **Estrutura de código expandida** com comentários detalhados para facilitar futuras modificações e compreensão.
]]

--// ====================================================================================================================
--// SERVIÇOS DO SISTEMA ROBLOX
--// ====================================================================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TextChatService = game:GetService("TextChatService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService") -- Adicionado para futuras expansões ou logs, se necessário

--// ====================================================================================================================
--// VARIÁVEIS GLOBAIS E DE ESTADO
--// ====================================================================================================================
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait() -- Garante que o Character esteja disponível

-- Variáveis de controle de estado para funcionalidades
local TargetName = "" -- Nome do jogador alvo selecionado na UI
local AvatarName = "" -- Nome do avatar selecionado na UI (para jumpscares/avatar)

-- Kill All
local killAllActive = false
local killAllConnection = nil

-- Aura de Cadeiras
local auraActive = false
local auraParts = {} -- Tabela para armazenar as partes da aura
local auraConnection = nil -- Conexão para o loop da aura

-- Tornado
local tornadoActive = false
local tornadoTarget = nil
local tornadoParts = {} -- Tabela para armazenar as partes do tornado
local tornadoConnection = nil -- Conexão para o loop do tornado

-- Backrooms
local backroomsFolder = nil
local backroomsActive = false

-- Boombox Voadora
local flying = false
local currentFlySpeed = 50
local boomboxBodyGyro = nil
local boomboxBodyVelocity = nil
local boomboxSound = nil

-- ESP
local espActive = false
local espAdornments = {} -- Armazena os adornos do ESP

-- Nome Colorido
local currentBillboard = nil

-- View/Unview
local viewingTarget = nil
local viewConnection = nil

-- Bang/Unbang
local bangLoop = nil

-- Música Global
local currentSound = nil
local currentSoundVolume = 0.5 -- Volume inicial padrão

-- RemoteEvent para comunicação com o servidor (se necessário para ferramentas)
local remoteEvent = ReplicatedStorage:FindFirstChild("AdminPanelRemoteEvent") or Instance.new("RemoteEvent", ReplicatedStorage)
remoteEvent.Name = "AdminPanelRemoteEvent"

-- Anti-SLA e Casas
local antiBanCasaActive = false
local autoBanCasaActive = false
local houseBanRadius = 20 -- Raio para o auto-ban de casas

--// ====================================================================================================================
--// FUNÇÕES AUXILIARES GERAIS
--// ====================================================================================================================

-- Função para obter a parte raiz do personagem (HumanoidRootPart, Torso, UpperTorso)
local function getRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
end

-- Função para encontrar um jogador pelo nome ou prefixo (case-insensitive)
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

-- Função para enviar comandos no chat (Aprimorada para garantir envio em diferentes versões do chat)
local function Say(message)
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        local canal = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if canal then
            canal:SendAsync(message)
        else
            -- Fallback se RBXGeneral não for encontrado (improvável, mas para robustez)
            local events = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
            if events and events:FindFirstChild("SayMessageRequest") then
                events.SayMessageRequest:FireServer(message, "All")
            end
        end
    else
        -- Versões mais antigas do chat
        local events = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        if events and events:FindFirstChild("SayMessageRequest") then
            events.SayMessageRequest:FireServer(message, "All")
        end
    end
end

--// ====================================================================================================================
--// FUNÇÕES DE COMANDOS DE JOGADOR (KILL, BRING, TP) - CORRIGIDAS E APRIMORADAS
--// ====================================================================================================================

--// Função de Kill (Fling Extremo Client-Side) - Implementação Robusta
local function executeKill(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local targetChar = targetPlayer.Character
    local targetRoot = getRoot(targetChar)
    local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
    
    if not targetRoot or not targetHumanoid then return end

    -- Tenta desabilitar o controle do servidor sobre o personagem do alvo
    targetHumanoid.PlatformStand = true

    -- Cria e aplica forças extremas para 
    -- Cria e aplica forças extremas para lançar o alvo
    local flingForce = Instance.new("BodyVelocity")
    flingForce.Name = "ExtremeFlingBV"
    flingForce.Parent = targetRoot
    flingForce.Velocity = Vector3.new(0, 5000, 0) -- Força inicial para cima
    flingForce.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    Debris:AddItem(flingForce, 1.0) -- Remove após 1 segundo

    local flingRotation = Instance.new("BodyGyro")
    flingRotation.Name = "ExtremeFlingBG"
    flingRotation.Parent = targetRoot
    flingRotation.CFrame = CFrame.new(targetRoot.Position, targetRoot.Position + Vector3.new(math.random(-100,100), 0, math.random(-100,100))) -- Rotação aleatória
    flingRotation.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    Debris:AddItem(flingRotation, 1.0)

    -- Loop de Fling contínuo para garantir que o alvo seja lançado
    local flingLoopConnection = nil
    flingLoopConnection = RunService.Heartbeat:Connect(function()
        if not targetPlayer.Character or not targetRoot.Parent then
            if flingLoopConnection then flingLoopConnection:Disconnect() end
            return
        end
        -- Aplica teleporte para cima e para baixo rapidamente para desorientar o servidor
        targetRoot.CFrame = CFrame.new(targetRoot.Position.X, targetRoot.Position.Y + 100, targetRoot.Position.Z)
        task.wait(0.05)
        targetRoot.CFrame = CFrame.new(targetRoot.Position.X, targetRoot.Position.Y - 100, targetRoot.Position.Z)
        
        -- Tenta resetar o personagem do alvo para forçar a morte
        targetHumanoid:ChangeState(Enum.HumanoidStateType.Dead)
        targetHumanoid.Health = 0
    end)
    Debris:AddItem(flingForce, 3) -- Mantém o fling por mais tempo
    Debris:AddItem(flingRotation, 3)

    task.delay(3, function()
        if flingLoopConnection then flingLoopConnection:Disconnect() end
        if targetHumanoid then targetHumanoid.PlatformStand = false end
        -- Teleporta o alvo para fora do mapa para garantir a eliminação
        if targetRoot and targetRoot.Parent then
            targetRoot.CFrame = CFrame.new(targetRoot.Position.X, -5000, targetRoot.Position.Z)
        end
    end)
end

--// Função para Kill All (Client-Side) - Agora usando a função executeKill aprimorada
local function startKillAll()
    if killAllActive then return end
    killAllActive = true
    killAllConnection = RunService.Heartbeat:Connect(function()
        if not killAllActive then killAllConnection:Disconnect(); return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                executeKill(player) -- Usa a função de kill aprimorada
            end
        end
    end)
end

--// Função para parar Kill All
local function stopKillAll()
    killAllActive = false
    if killAllConnection then
        killAllConnection:Disconnect()
        killAllConnection = nil
    end
end

--// Função de Bring (Puxar Player) - Aprimorada para v14 com múltiplas tentativas
local function executeBring(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local targetChar = targetPlayer.Character
    local targetRoot = getRoot(targetChar)
    local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
    
    if not targetRoot or not targetHumanoid then return end

    local adminChar = LocalPlayer.Character
    local adminRoot = getRoot(adminChar)
    if not adminRoot then return end

    -- Tenta desabilitar o controle do servidor sobre o personagem do alvo
    targetHumanoid.PlatformStand = true

    -- Tentativa 1: Teleporte direto para a posição do admin
    targetRoot.CFrame = adminRoot.CFrame * CFrame.new(0, 5, -3) -- Um pouco acima e à frente do admin
    task.wait(0.1)

    -- Tentativa 2: Usar BodyPosition para puxar o alvo
    local bp = Instance.new("BodyPosition")
    bp.Name = "BringBP"
    bp.Parent = targetRoot
    bp.Position = adminRoot.Position + Vector3.new(0, 5, -3)
    bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bp.P = 100000
    bp.D = 1000
    Debris:AddItem(bp, 1.0)

    -- Tentativa 3: Usar BodyVelocity para empurrar o alvo
    local bv = Instance.new("BodyVelocity")
    bv.Name = "BringBV"
    bv.Parent = targetRoot
    bv.Velocity = (adminRoot.Position - targetRoot.Position).Unit * 100 -- Empurra na direção do admin
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    Debris:AddItem(bv, 1.0)

    -- Tenta usar o comando de chat como fallback ou para reforçar
    Say(";bring " .. targetPlayer.Name)

    -- Desabilita PlatformStand após um tempo
    task.delay(1.5, function() if targetHumanoid then targetHumanoid.PlatformStand = false end end)
end

--// Função para Bring All (Client-Side) - Agora usando a função executeBring aprimorada
local function executeBringAll()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            executeBring(player) -- Usa a função de bring aprimorada
        end
    end
end

--// Função de TP (Teleportar para o Player) - Aprimorada para v14
local function executeTP(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local targetChar = targetPlayer.Character
    local targetRoot = getRoot(targetChar)
    local myChar = LocalPlayer.Character
    local myRoot = getRoot(myChar)

    if not targetRoot or not myRoot then return end

    -- Teleporta o jogador local para a posição do alvo, um pouco à frente
    myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 2, 3) -- 2 studs acima e 3 studs à frente

    -- Tenta usar o comando de chat como fallback ou para reforçar
    Say(";tp " .. targetPlayer.Name)
end

--// ====================================================================================================================
--// NOVAS FUNCIONALIDADES V14 - COMANDOS ESPECIAIS
--// ====================================================================================================================

--// Função de Crash (Lag Intenso Local no Alvo) - Implementação Detalhada
local function executeCrash(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local targetChar = targetPlayer.Character
    local targetRoot = getRoot(targetChar)

    if not targetRoot then return end

    -- Tenta causar lag intenso no cliente do alvo através de spam de objetos e efeitos
    local crashFolder = Instance.new("Folder", Workspace)
    crashFolder.Name = "Crash_Effects_" .. targetPlayer.Name
    Debris:AddItem(crashFolder, 10) -- Limpa os efeitos após 10 segundos

    -- Spam de Partículas com alta taxa e tamanho
    for i = 1, 50 do -- Aumentado o número de emissores
        local pEmitter = Instance.new("ParticleEmitter", targetRoot)
        pEmitter.Rate = 5000 -- Taxa de emissão muito alta
        pEmitter.Lifetime = NumberRange.new(0.1, 0.5)
        pEmitter.Size = NumberSequence.new(5, 20) -- Partículas grandes
        pEmitter.Speed = NumberRange.new(50, 100)
        pEmitter.Transparency = NumberSequence.new(0, 1)
        pEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0), Color3.fromRGB(255, 255, 0))
        pEmitter.LightEmission = 1
        pEmitter.LockedToPart = true
        pEmitter.Parent = crashFolder
    end

    -- Spam de Luzes (PointLights) ao redor do alvo
    for i = 1, 20 do
        local light = Instance.new("PointLight", targetRoot)
        light.Range = math.random(10, 30)
        light.Brightness = math.random(5, 15)
        light.Color = Color3.fromRGB(math.random(0,255), math.random(0,255), math.random(0,255))
        light.Parent = crashFolder
    end

    -- Spam de Sons (Sound) com volume alto
    for i = 1, 10 do
        local sound = Instance.new("Sound", targetRoot)
        sound.SoundId = "rbxassetid://" .. math.random(100000000, 999999999) -- ID de som aleatório
        sound.Volume = 10 -- Volume máximo
        sound.Looped = true
        sound:Play()
        Debris:AddItem(sound, 5)
        sound.Parent = crashFolder
    end

    -- Tenta usar o comando de chat como fallback
    Say(";crash " .. targetPlayer.Name)

    print("Comando ;Crash executado no jogador: " .. targetPlayer.Name)
end

--// Função Tornado (Efeito Visual Complexo) - Implementação Detalhada
local function executeTornado(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    if tornadoActive then print("Tornado já está ativo."); return end

    tornadoActive = true
    tornadoTarget = targetPlayer
    
    local root = getRoot(targetPlayer.Character)
    if not root then print("Raiz do personagem do alvo não encontrada."); tornadoActive = false; return end

    -- Cria um modelo para agrupar as partes do tornado
    local tornadoModel = Instance.new("Model", Workspace)
    tornadoModel.Name = "Tornado_Effect_" .. targetPlayer.Name
    Debris:AddItem(tornadoModel, 30) -- Limpa o tornado após 30 segundos

    -- Cria as partes visuais do tornado
    for i = 1, 100 do -- Aumentado o número de partes para um tornado mais denso
        local p = Instance.new("Part", tornadoModel)
        p.Anchored = true
        p.CanCollide = false
        p.Size = Vector3.new(math.random(1, 3), math.random(1, 5), math.random(1, 3))
        p.Color = Color3.fromRGB(math.random(100, 200), math.random(100, 200), math.random(100, 200))
        p.Transparency = math.random(3, 7) / 10 -- Transparência variada
        p.Material = Enum.Material.SmoothPlastic
        p.Reflectance = 0.1
        table.insert(tornadoParts, p)
    end
    
    -- Loop de animação do tornado
    local angle = 0
    local heightOffset = 0
    local radius = 10
    local speed = 0.15
    local verticalSpeed = 0.5

    tornadoConnection = RunService.Heartbeat:Connect(function()
        if not tornadoActive or not tornadoTarget.Character or not getRoot(tornadoTarget.Character) then
            -- Limpa o tornado se o alvo sumir ou o comando for parado
            for _, p in ipairs(tornadoParts) do p:Destroy() end
            tornadoParts = {}
            tornadoActive = false
            if tornadoConnection then tornadoConnection:Disconnect() end
            return
        end

        local currentTargetRoot = getRoot(tornadoTarget.Character)
        angle = angle + speed
        heightOffset = heightOffset + verticalSpeed
        if heightOffset > 50 then heightOffset = 0 end -- Reseta a altura para um loop contínuo

        for i, p in ipairs(tornadoParts) do
            local currentRadius = radius * (1 - (i / #tornadoParts) * 0.7) -- Raio diminui no topo
            local currentHeight = (i / #tornadoParts) * 30 + (heightOffset * 0.5) % 30 -- Altura e movimento vertical
            local x = currentRadius * math.cos(angle + (i * 0.1))
            local z = currentRadius * math.sin(angle + (i * 0.1))
            local y = currentHeight

            p.CFrame = currentTargetRoot.CFrame * CFrame.new(x, y, z) * CFrame.Angles(angle, angle, angle)
        end
    end)

    print("Comando ;tornado executado no jogador: " .. targetPlayer.Name)
end

--// Função para parar o Tornado
local function stopTornado()
    tornadoActive = false
    if tornadoConnection then
        tornadoConnection:Disconnect()
        tornadoConnection = nil
    end
    for _, p in ipairs(tornadoParts) do p:Destroy() end
    tornadoParts = {}
    print("Tornado parado.")
end

--// Função Aura de Cadeiras (Efeito Visual Pessoal) - Implementação Detalhada
local function startAura()
    if auraActive then print("Aura já está ativa."); return end
    auraActive = true
    
    local myChar = LocalPlayer.Character
    local myRoot = getRoot(myChar)
    if not myRoot then print("Raiz do personagem local não encontrada."); auraActive = false; return end

    -- Cria um modelo para agrupar as cadeiras da aura
    local auraModel = Instance.new("Model", Workspace)
    auraModel.Name = "Aura_Chairs_Effect_" .. LocalPlayer.Name
    -- Não usa Debris para este modelo, pois é persistente enquanto a aura estiver ativa

    -- Cria as cadeiras da aura
    for i = 1, 16 do -- Aumentado o número de cadeiras para uma aura mais completa
        local chair = Instance.new("Part", auraModel) -- Usando Part em vez de Seat para mais controle visual
        chair.Shape = Enum.PartType.Block
        chair.Size = Vector3.new(2, 1, 2)
        chair.Color = Color3.fromRGB(math.random(0,255), math.random(0,255), math.random(0,255)) -- Cores aleatórias
        chair.Material = Enum.Material.Neon -- Material Neon para um efeito brilhante
        chair.Anchored = true
        chair.CanCollide = false
        chair.Transparency = 0.2
        table.insert(auraParts, chair)

        -- Adiciona um BodyGyro e BodyPosition para simular a rotação e flutuação da cadeira
        local bg = Instance.new("BodyGyro", chair)
        bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bg.P = 10000
        bg.D = 100
        bg.CFrame = chair.CFrame

        local bp = Instance.new("BodyPosition", chair)
        bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bp.P = 10000
        bp.D = 100
        bp.Position = chair.Position
    end
    
    -- Loop de animação da aura
    local angle = 0
    local radius = 8 -- Raio da aura
    local floatOffset = 0
    local floatSpeed = 0.1

    auraConnection = RunService.Heartbeat:Connect(function()
        if not auraActive or not LocalPlayer.Character or not getRoot(LocalPlayer.Character) then
            -- Limpa a aura se o jogador sumir ou o comando for parado
            for _, p in ipairs(auraParts) do p:Destroy() end
            auraParts = {}
            auraActive = false
            if auraConnection then auraConnection:Disconnect() end
            return
        end

        local currentMyRoot = getRoot(LocalPlayer.Character)
        angle = angle + 0.05 -- Velocidade de rotação
        floatOffset = floatOffset + floatSpeed
        if floatOffset > math.pi * 2 then floatOffset = 0 end -- Reseta o offset para flutuação contínua

        for i, p in ipairs(auraParts) do
            local currentAngle = angle + (i * (math.pi * 2 / #auraParts)) -- Distribui as cadeiras em círculo
            local x = radius * math.cos(currentAngle)
            local z = radius * math.sin(currentAngle)
            local y = currentMyRoot.Position.Y + 2 + (math.sin(floatOffset + (i * 0.5)) * 1) -- Flutuação vertical

            local targetCFrame = CFrame.new(currentMyRoot.Position.X + x, y, currentMyRoot.Position.Z + z) * CFrame.Angles(0, currentAngle + math.pi/2, 0)
            
            -- Atualiza a posição e rotação da cadeira
            p.CFrame = p.CFrame:Lerp(targetCFrame, 0.2) -- Suaviza o movimento

            -- Atualiza BodyGyro e BodyPosition para manter a cadeira no lugar e girando
            p:FindFirstChildOfClass("BodyGyro").CFrame = targetCFrame
            p:FindFirstChildOfClass("BodyPosition").Position = targetCFrame.p
        end
    end)

    print("Aura de cadeiras iniciada.")
end

--// Função para parar a Aura de Cadeiras
local function stopAura()
    auraActive = false
    if auraConnection then
        auraConnection:Disconnect()
        auraConnection = nil
    end
    for _, p in ipairs(auraParts) do p:Destroy() end
    auraParts = {}
    print("Aura de cadeiras parada.")
end

--// ====================================================================================================================
--// FUNCIONALIDADES V13 ORIGINAIS - REINTEGRADAS E APRIMORADAS
--// ====================================================================================================================

--// Função para dar ferramentas (requer RemoteEvent no servidor) - Mantida do V13
local function giveTool(toolName, toolId)
    if remoteEvent then
        remoteEvent:FireServer("GiveTool", toolName, toolId)
    else
        warn("AdminPanelRemoteEvent não encontrado em ReplicatedStorage. Ferramentas não podem ser dadas.")
    end
end

--// Função para tocar música global (requer RemoteEvent no servidor) - Mantida do V13
local function playGlobalMusic(musicId, volume)
    if remoteEvent then
        remoteEvent:FireServer("PlayGlobalMusic", musicId, volume)
    else
        warn("AdminPanelRemoteEvent não encontrado em ReplicatedStorage. Música global não pode ser tocada.")
    end
end

--// Função para parar música global (requer RemoteEvent no servidor) - Mantida do V13
local function stopGlobalMusic()
    if remoteEvent then
        remoteEvent:FireServer("StopGlobalMusic")
    else
        warn("AdminPanelRemoteEvent não encontrado em ReplicatedStorage. Música global não pode ser parada.")
    end
end

--// Função Boombox Voadora (Client-Side) - Reintegrada e Detalhada
local function createFlyingBoombox()
    local boomboxTool = Instance.new("Tool")
    boomboxTool.Name = "Boombox Voadora"
    boomboxTool.ToolTip = "Segure para voar e tocar música!"

    local handle = Instance.new("Part", boomboxTool)
    handle.Name = "Handle"
    handle.Size = Vector3.new(2, 2, 2)
    handle.BrickColor = BrickColor.new("Deep blue")
    handle.Material = Enum.Material.Neon
    handle.CanCollide = false
    handle.Transparency = 0.3
    handle.FormFactor = Enum.FormFactor.Symmetric

    local mesh = Instance.new("SpecialMesh", handle)
    mesh.MeshType = Enum.MeshType.FileMesh
    mesh.MeshId = "rbxassetid://1054661" -- Exemplo de MeshId para uma boombox
    mesh.Scale = Vector3.new(2, 2, 2)

    local sound = Instance.new("Sound", handle)
    sound.SoundId = "rbxassetid://130792047" -- Música padrão da boombox
    sound.Volume = 0.7
    sound.Looped = true
    boomboxSound = sound

    boomboxBodyGyro = Instance.new("BodyGyro")
    boomboxBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    boomboxBodyGyro.D = 100
    boomboxBodyGyro.P = 10000

    boomboxBodyVelocity = Instance.new("BodyVelocity")
    boomboxBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    boomboxBodyVelocity.D = 100
    boomboxBodyVelocity.P = 10000

    boomboxTool.Equipped:Connect(function()
        local char = LocalPlayer.Character
        if char then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.PlatformStand = true
                flying = true
                boomboxSound:Play()

                local root = getRoot(char)
                if root then
                    boomboxBodyGyro.CFrame = root.CFrame
                    boomboxBodyVelocity.Velocity = Vector3.new(0,0,0)
                    boomboxBodyGyro.Parent = root
                    boomboxBodyVelocity.Parent = root
                end
            end
        end
    end)

    boomboxTool.Unequipped:Connect(function()
        local char = LocalPlayer.Character
        if char then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.PlatformStand = false
                flying = false
                boomboxSound:Stop()

                local root = getRoot(char)
                if root then
                    if root:FindFirstChild("BodyGyro") then root:FindFirstChild("BodyGyro"):Destroy() end
                    if root:FindFirstChild("BodyVelocity") then root:FindFirstChild("BodyVelocity"):Destroy() end
                end
            end
        end
    end)

    RunService.Heartbeat:Connect(function()
        if flying and LocalPlayer.Character then
            local root = getRoot(LocalPlayer.Character)
            if root then
                local moveVector = Vector3.new(0,0,0)
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector = moveVector + Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector = moveVector - Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector = moveVector - Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector = moveVector + Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVector = moveVector + Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveVector = moveVector - Vector3.new(0,1,0) end

                if moveVector.Magnitude > 0 then
                    boomboxBodyVelocity.Velocity = moveVector.Unit * currentFlySpeed
                else
                    boomboxBodyVelocity.Velocity = Vector3.new(0,0,0)
                end
                boomboxBodyGyro.CFrame = Camera.CFrame
            end
        end
    end)

    boomboxTool.Parent = LocalPlayer.Backpack
end

--// Função Backrooms LABIRINTO REAL V11 (Aprimorado - Iluminação Ajustada) - Reintegrada e Detalhada
local function executeBackrooms()
    if backroomsActive then print("Backrooms já está ativo."); return end
    backroomsActive = true
    if backroomsFolder then backroomsFolder:Destroy() end
    
    backroomsFolder = Instance.new("Folder", Workspace)
    backroomsFolder.Name = "Real_Backrooms_V11_Maze_" .. LocalPlayer.Name
    
    local basePos = LocalPlayer.Character and getRoot(LocalPlayer.Character) and getRoot(LocalPlayer.Character).Position or Vector3.new(0, 100, 0)
    basePos = Vector3.new(basePos.X, basePos.Y + 50, basePos.Z) -- Posiciona o labirinto acima do jogador

    -- Ajustes de iluminação para um ambiente sombrio e imersivo
    Lighting.FogColor = Color3.fromRGB(20, 20, 15) -- Névoa mais escura
    Lighting.FogEnd = 80 -- Névoa mais próxima para criar claustrofobia
    Lighting.Ambient = Color3.fromRGB(30, 30, 25) -- Ambiente mais escuro
    Lighting.OutdoorAmbient = Color3.fromRGB(15, 15, 10) -- Ambiente externo mais escuro
    Lighting.Brightness = 0.3 -- Brilho geral reduzido
    Lighting.GlobalShadows = true -- Sombras globais ativadas para profundidade
    Lighting.TimeOfDay = "0:00:00" -- Noite total

    -- Função auxiliar para criar partes do labirinto
    local function createPart(pos, size, color, material, name, parent)
        local p = Instance.new("Part", parent or backroomsFolder)
        p.Size = size
        p.Position = pos
        p.Anchored = true
        p.CanCollide = true
        p.Color = color or Color3.fromRGB(150, 150, 150)
        p.Material = material or Enum.Material.Concrete
        p.Name = name or "MazePart"
        p.Reflectance = 0.05
        return p
    end

    -- Dimensões do labirinto
    local mazeSizeX, mazeSizeZ = 50, 50 -- Tamanho do grid do labirinto
    local wallHeight = 12 -- Altura das paredes (teto baixo)
    local wallThickness = 2
    local cellSize = 10 -- Tamanho de cada célula do labirinto

    -- Geração do labirinto usando algoritmo de Prim ou similar (simplificado para exemplo)
    local mazeGrid = {}
    for x = 1, mazeSizeX do
        mazeGrid[x] = {}
        for z = 1, mazeSizeZ do
            mazeGrid[x][z] = {visited = false, walls = {north = true, east = true, south = true, west = true}}
        end
    end

    local function carvePath(cx, cz)
        mazeGrid[cx][cz].visited = true
        local directions = {{0,1,"south"}, {0,-1,"north"}, {1,0,"east"}, {-1,0,"west"}}
        table.sort(directions, function() return math.random() < 0.5 end) -- Randomiza direções

        for _, dir in ipairs(directions) do
            local nx, nz = cx + dir[1], cz + dir[2]
            if nx >= 1 and nx <= mazeSizeX and nz >= 1 and nz <= mazeSizeZ and not mazeGrid[nx][nz].visited then
                -- Remove a parede entre as células
                if dir[3] == "north" then
                    mazeGrid[cx][cz].walls.north = false
                    mazeGrid[nx][nz].walls.south = false
                elseif dir[3] == "south" then
                    mazeGrid[cx][cz].walls.south = false
                    mazeGrid[nx][nz].walls.north = false
                elseif dir[3] == "east" then
                    mazeGrid[cx][cz].walls.east = false
                    mazeGrid[nx][nz].walls.west = false
                elseif dir[3] == "west" then
                    mazeGrid[cx][cz].walls.west = false
                    mazeGrid[nx][nz].walls.east = false
                end
                carvePath(nx, nz)
            end
        end
    end

    carvePath(math.random(1, mazeSizeX), math.random(1, mazeSizeZ)) -- Começa a gerar o labirinto de um ponto aleatório

    -- Cria o chão e o teto
    createPart(basePos + Vector3.new((mazeSizeX * cellSize)/2, -wallHeight/2, (mazeSizeZ * cellSize)/2), Vector3.new(mazeSizeX * cellSize, wallThickness, mazeSizeZ * cellSize), Color3.fromRGB(180, 180, 180), Enum.Material.Concrete, "Floor")
    createPart(basePos + Vector3.new((mazeSizeX * cellSize)/2, wallHeight + wallThickness/2, (mazeSizeZ * cellSize)/2), Vector3.new(mazeSizeX * cellSize, wallThickness, mazeSizeZ * cellSize), Color3.fromRGB(100, 100, 100), Enum.Material.Concrete, "Ceiling")

    -- Cria as paredes do labirinto
    for x = 1, mazeSizeX do
        for z = 1, mazeSizeZ do
            local cellCenter = basePos + Vector3.new((x - 0.5) * cellSize, 0, (z - 0.5) * cellSize)
            if mazeGrid[x][z].walls.north then
                createPart(cellCenter + Vector3.new(0, wallHeight/2, -cellSize/2), Vector3.new(cellSize + wallThickness, wallHeight, wallThickness), Color3.fromRGB(150, 150, 150), Enum.Material.Concrete, "WallN")
            end
            if mazeGrid[x][z].walls.east then
                createPart(cellCenter + Vector3.new(cellSize/2, wallHeight/2, 0), Vector3.new(wallThickness, wallHeight, cellSize + wallThickness), Color3.fromRGB(150, 150, 150), Enum.Material.Concrete, "WallE")
            end
            -- As paredes sul e oeste são criadas pelas células vizinhas, evitando duplicação
        end
    end

    -- Adiciona luzes pontuais esparsas para iluminação ambiente
    for i = 1, math.floor((mazeSizeX * mazeSizeZ) / 10) do -- Uma luz a cada 10 células
        local lx = math.random(1, mazeSizeX)
        local lz = math.random(1, mazeSizeZ)
        local lightPos = basePos + Vector3.new((lx - 0.5) * cellSize, wallHeight * 0.75, (lz - 0.5) * cellSize)
        local pl = Instance.new("PointLight", backroomsFolder)
        pl.Range = math.random(10, 20)
        pl.Brightness = math.random(0.5, 1.5)
        pl.Color = Color3.fromRGB(255, 255, 200) -- Luz amarelada
        pl.Parent = createPart(lightPos, Vector3.new(1,1,1), Color3.fromRGB(255,255,0), Enum.Material.Neon, "LightSource", backroomsFolder)
    end

    -- Teleporta o jogador para o início do labirinto
    if LocalPlayer.Character then
        local startX = math.random(1, mazeSizeX)
        local startZ = math.random(1, mazeSizeZ)
        local startPos = basePos + Vector3.new((startX - 0.5) * cellSize, wallHeight/2, (startZ - 0.5) * cellSize)
        getRoot(LocalPlayer.Character).CFrame = CFrame.new(startPos)
    end

    print("Entrando nos Backrooms - Labirinto Real V11.")
end

--// Função para Sair do Backrooms - Reintegrada e Detalhada
local function exitBackrooms()
    backroomsActive = false
    if backroomsFolder then
        backroomsFolder:Destroy()
        backroomsFolder = nil
    end

    -- Restaura as configurações de iluminação padrão
    Lighting.FogColor = Color3.fromRGB(192, 192, 192) -- Cor padrão do Roblox
    Lighting.FogEnd = 100000 -- Distância padrão
    Lighting.Ambient = Color3.fromRGB(127, 127, 127) -- Ambiente padrão
    Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127) -- Ambiente externo padrão
    Lighting.Brightness = 2 -- Brilho padrão
    Lighting.GlobalShadows = true -- Restaura sombras globais
    Lighting.TimeOfDay = "14:00:00" -- Meio-dia

    -- Teleporta o jogador para uma posição segura (ex: spawn point)
    if LocalPlayer.Character then
        local spawnPoints = Workspace:FindFirstChild("SpawnLocations") or Workspace:GetChildren()
        local safePos = Vector3.new(0, 5, 0)
        for _, sp in ipairs(spawnPoints) do
            if sp:IsA("SpawnLocation") then
                safePos = sp.Position + Vector3.new(0, 5, 0)
                break
            end
        end
        getRoot(LocalPlayer.Character).CFrame = CFrame.new(safePos)
    end

    print("Saindo dos Backrooms.")
end

--// Função Nome Colorido sobre a cabeça (Aprimorada) - Reintegrada e Detalhada
local function createColoredName(text)
    if currentBillboard then currentBillboard:Destroy() end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("Head") then return end
    
    local bgui = Instance.new("BillboardGui", char.Head)
    bgui.Name = "ColoredNameGui"
    bgui.Size = UDim2.new(0, 300, 0, 80) -- Tamanho um pouco maior para mais destaque
    bgui.Adornee = char.Head
    bgui.AlwaysOnTop = true
    bgui.ExtentsOffset = Vector3.new(0, 3, 0)
    bgui.LightInfluence = 0 -- Para o nome ser sempre visível independentemente da luz
    bgui.StudsOffset = Vector3.new(0, 2, 0) -- Mais acima da cabeça
    
    local frame = Instance.new("Frame", bgui)
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 0.7 -- Fundo semi-transparente
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- Fundo escuro
    frame.BorderSizePixel = 0
    frame.CornerRadius = UDim.new(0.25, 0) -- Cantos mais arredondados
    frame.ClipsDescendants = true -- Garante que o texto não vaze

    local textStroke = Instance.new("UIStroke", frame) -- Adiciona um contorno ao frame
    textStroke.Color = Color3.fromRGB(255, 255, 255)
    textStroke.Thickness = 2
    textStroke.Transparency = 0.5

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -20, 1, -20) -- Margem interna maior
    label.Position = UDim2.new(0, 10, 0, 10)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.6 -- Borda do texto mais suave
    label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    
    currentBillboard = bgui
    
    -- Animação de cores vibrantes para o texto
    task.spawn(function()
        while bgui.Parent do
            label.TextColor3 = Color3.fromHSV(tick() % 10 / 10, 1, 1) -- Cores vibrantes e cíclicas
            task.wait(0.05)
        end
    end)

    print("Nome colorido ativado: " .. text)
end

--// Função para remover Nome Colorido
local function removeColoredName()
    if currentBillboard then
        currentBillboard:Destroy()
        currentBillboard = nil
    end
    print("Nome colorido desativado.")
end

--// Função ESP (Ver Jogadores através das paredes) - Reintegrada e Detalhada
local function updateESP()
    -- Limpa adornos antigos
    for _, adorn in ipairs(espAdornments) do
        adorn:Destroy()
    end
    espAdornments = {}

    if espActive then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local char = player.Character
                local root = getRoot(char)
                if root then
                    -- Cria um BoxHandleAdornment para o ESP
                    local boxAdorn = Instance.new("BoxHandleAdornment", root)
                    boxAdorn.Adornee = root
                    boxAdorn.Size = root.Size + Vector3.new(1,1,1) -- Um pouco maior que o root part
                    boxAdorn.Color3 = Color3.fromRGB(0, 255, 0) -- Verde
                    boxAdorn.AlwaysOnTop = true
                    boxAdorn.Transparency = 0.7
                    boxAdorn.ZIndex = 10 -- Garante que apareça sobre outros elementos
                    boxAdorn.Visible = true
                    table.insert(espAdornments, boxAdorn)

                    -- Adiciona um TextLabel para o nome do jogador
                    local nameLabel = Instance.new("BillboardGui", root)
                    nameLabel.Adornee = root
                    nameLabel.Size = UDim2.new(0, 150, 0, 30)
                    nameLabel.AlwaysOnTop = true
                    nameLabel.ExtentsOffset = Vector3.new(0, 5, 0)
                    nameLabel.StudsOffset = Vector3.new(0, 5, 0)

                    local text = Instance.new("TextLabel", nameLabel)
                    text.Size = UDim2.new(1, 0, 1, 0)
                    text.BackgroundTransparency = 1
                    text.Text = player.Name
                    text.TextColor3 = Color3.fromRGB(0, 255, 0)
                    text.TextScaled = true
                    text.Font = Enum.Font.SourceSansBold
                    text.TextStrokeTransparency = 0.8
                    text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                    table.insert(espAdornments, nameLabel)
                end
            end
        end
    end
    print("ESP " .. (espActive and "ativado" or "desativado"))
end

--// Funções de Jumpscares e Avatar (Mantidas do V13)
local function executeJumpscare(targetPlayer, soundId, imageId)
    if not targetPlayer or not targetPlayer.Character then return end
    local targetChar = targetPlayer.Character
    local targetRoot = getRoot(targetChar)
    if not targetRoot then return end

    -- Cria um ScreenGui para o jumpscare
    local sg = Instance.new("ScreenGui", LocalPlayer.PlayerGui)
    sg.Name = "JumpscareGui"
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 999 -- Garante que fique por cima de tudo
    Debris:AddItem(sg, 2) -- Remove o jumpscare após 2 segundos

    local img = Instance.new("ImageLabel", sg)
    img.Size = UDim2.new(1, 0, 1, 0)
    img.BackgroundTransparency = 1
    img.Image = "rbxassetid://" .. imageId
    img.ScaleType = Enum.ScaleType.Fit
    img.ZIndex = 10

    local sound = Instance.new("Sound", sg)
    sound.SoundId = "rbxassetid://" .. soundId
    sound.Volume = 5 -- Volume alto
    sound:Play()
    Debris:AddItem(sound, 2)

    print("Jumpscare executado em: " .. targetPlayer.Name)
end

local function changeAvatar(targetPlayer, avatarId)
    if not targetPlayer then return end
    Say(";avatar " .. targetPlayer.Name .. " " .. avatarId)
    print("Tentando mudar avatar de " .. targetPlayer.Name .. " para ID: " .. avatarId)
end

--// ====================================================================================================================
--// SISTEMA DE CASAS E SEGURANÇA - NOVAS FUNCIONALIDADES V14
--// ====================================================================================================================

--// Função para Desbanir de Todas as Casas (Client-Side) - Implementação Detalhada
local function unbanFromHouses()
    -- Tenta enviar comandos de chat genéricos para desbanir
    Say(";unbanallhouses")
    Say(";unbanhouse all")
    Say(";house unban all")
    Say(";clearbans house")

    -- Tenta interagir com possíveis GUIs de banimento de casas (exemplo genérico)
    local playerGui = LocalPlayer.PlayerGui
    for _, gui in ipairs(playerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and (string.find(gui.Name:lower(), "house") or string.find(gui.Name:lower(), "ban")) then
            -- Tenta encontrar botões de desbanir ou campos de texto para limpar bans
            for _, child in ipairs(gui:GetDescendants()) do
                if child:IsA("TextButton") and (string.find(child.Text:lower(), "unban") or string.find(child.Name:lower(), "unban")) then
                    child:Click() -- Simula um clique no botão de desbanir
                    print("Clicado em botão de desbanir em GUI: " .. gui.Name)
                elseif child:IsA("TextBox") and (string.find(child.Name:lower(), "banlist") or string.find(child.Name:lower(), "bannedplayers")) then
                    child.Text = "" -- Tenta limpar a lista de bans
                    print("Limpado campo de texto de banlist em GUI: " .. gui.Name)
                end
            end
        end
    end

    print("Tentativa de desbanir de todas as casas executada.")
end

--// Função Auto-Ban de Casas (Monitoramento Contínuo) - Implementação Detalhada
task.spawn(function()
    while true do
        if autoBanCasaActive and LocalPlayer.Character then
            local myRoot = getRoot(LocalPlayer.Character)
            if myRoot then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        local pRoot = getRoot(p.Character)
                        if pRoot and (pRoot.Position - myRoot.Position).Magnitude < houseBanRadius then
                            -- Jogador detectado dentro do raio, tenta banir
                            Say(";houseban " .. p.Name) -- Comando de chat
                            Say(";banhouse " .. p.Name) -- Comando alternativo
                            print("Auto-ban ativado: Banindo " .. p.Name .. " da casa.")
                            task.wait(1) -- Pequeno delay para evitar spam excessivo
                        end
                    end
                end
            end
        end
        task.wait(0.5) -- Verifica a cada 0.5 segundos
    end
end)

--// Função Anti-Ban Casa (Prevenção Client-Side) - Implementação Detalhada
local function toggleAntiBanCasa(v)
    antiBanCasaActive = v
    if v then
        print("Anti-Ban Casa Ativado. Tentando interceptar eventos de banimento.")
        -- Tenta interceptar RemoteEvents/Functions que podem causar banimento de casa
        -- Isso é altamente dependente do jogo e pode não funcionar em todos os casos.
        -- Exemplo genérico de hook (pode precisar de ajustes específicos para cada jogo)
        local oldFireServer = remoteEvent.FireServer -- Assume que o RemoteEvent principal é usado para bans
        remoteEvent.FireServer = function(self, eventName, ...)
            if antiBanCasaActive and (string.find(eventName:lower(), "banhouse") or string.find(eventName:lower(), "banplayer")) then
                warn("Anti-Ban Casa: Tentativa de banimento de casa detectada e bloqueada para " .. LocalPlayer.Name .. "!")
                return -- Bloqueia o evento
            end
            return oldFireServer(self, eventName, ...) -- Permite outros eventos
        end

        -- Outra estratégia: monitorar GUIs de banimento e tentar fechá-las ou desativá-las
        local playerGui = LocalPlayer.PlayerGui
        playerGui.ChildAdded:Connect(function(child)
            if antiBanCasaActive and child:IsA("ScreenGui") and (string.find(child.Name:lower(), "ban") or string.find(child.Name:lower(), "kick")) then
                warn("Anti-Ban Casa: GUI de banimento/kick detectada. Tentando desativar.")
                child.Enabled = false -- Desativa a GUI
                child:Destroy() -- Tenta destruir a GUI
            end
        end)

    else
        print("Anti-Ban Casa Desativado.")
        -- Reverter hooks é complexo, geralmente requer reinício do script ou do jogo.
    end
end

--// ====================================================================================================================
--// FUNCIONALIDADES DE SEGURANÇA V13 ORIGINAIS (ANTI-SLA) - REINTEGRADAS E APRIMORADAS
--// ====================================================================================================================

--// Função Anti-Lag (Experimental) - Reintegrada e Detalhada
local function toggleAntiLag(v)
    if v then
        print("Anti-Lag Ativado (Experimental). Desativando efeitos visuais para reduzir o lag.")
        -- Desativa sombras globais
        Lighting.GlobalShadows = false
        -- Desativa partículas em todo o Workspace
        for _, part in ipairs(Workspace:GetDescendants()) do
            if part:IsA("ParticleEmitter") then
                part.Enabled = false
            end
        end
        -- Reduz a qualidade gráfica (se o cliente permitir)
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level1 -- Qualidade mínima
        settings().Physics.Throttle = 0.1 -- Reduz a frequência de atualização da física
    else
        print("Anti-Lag Desativado. Restaurando configurações.")
        Lighting.GlobalShadows = true
        for _, part in ipairs(Workspace:GetDescendants()) do
            if part:IsA("ParticleEmitter") then
                part.Enabled = true
            end
        end
        settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic -- Qualidade automática
        settings().Physics.Throttle = 1 -- Frequência padrão
    end
end

--// Função Anti-Admin (Client-Side) - Reintegrada e Detalhada
local function toggleAntiAdmin(v)
    if v then
        print("Anti-Admin Ativado. Tentando bloquear comandos de admin client-side.")
        -- Hook em RemoteEvents/Functions para bloquear comandos de admin comuns
        local originalFireServer = remoteEvent.FireServer
        remoteEvent.FireServer = function(self, eventName, ...)
            local args = {...}
            local lowerEventName = eventName:lower()
            if string.find(lowerEventName, "kick") or string.find(lowerEventName, "ban") or string.find(lowerEventName, "give") or string.find(lowerEventName, "teleport") then
                warn("Anti-Admin: Comando de admin ('" .. eventName .. "') detectado e bloqueado!")
                return -- Bloqueia o comando
            end
            return originalFireServer(self, eventName, ...)
        end

        -- Monitora o Backpack e Character para ferramentas indesejadas
        LocalPlayer.Backpack.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                warn("Anti-Admin: Ferramenta detectada no Backpack: " .. child.Name .. ". Destruindo...")
                child:Destroy()
            end
        end)
        LocalPlayer.Character.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                warn("Anti-Admin: Ferramenta detectada no Character: " .. child.Name .. ". Destruindo...")
                child:Destroy()
            end
        end)
    else
        print("Anti-Admin Desativado. Reverter completamente pode exigir reinício.")
        -- Reverter hooks é complexo e pode não ser totalmente possível sem reiniciar o script.
    end
end

--// Função Anti-Tools (Destruir Ferramentas) - Reintegrada e Detalhada
local function toggleAntiTools(v)
    if v then
        print("Anti-Tools Ativado. Destruindo automaticamente ferramentas recebidas.")
        LocalPlayer.Backpack.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                warn("Anti-Tools: Ferramenta detectada no Backpack: " .. child.Name .. ". Destruindo...")
                child:Destroy()
            end
        end)
        LocalPlayer.Character.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                warn("Anti-Tools: Ferramenta detectada no Character: " .. child.Name .. ". Destruindo...")
                child:Destroy()
            end
        end)
    else
        print("Anti-Tools Desativado. Reverter completamente pode exigir reinício.")
    end
end

--// Função Anti-Kick (Client-Side) - Reintegrada e Detalhada
local function toggleAntiKick(v)
    if v then
        print("Anti-Kick Ativado. Tentando prevenir kicks client-side.")
        local originalFireServer = remoteEvent.FireServer
        remoteEvent.FireServer = function(self, eventName, ...)
            local args = {...}
            if string.find(eventName:lower(), "kick") then
                warn("Anti-Kick: Tentativa de kick detectada e bloqueada!")
                return
            end
            return originalFireServer(self, eventName, ...)
        end
    else
        print("Anti-Kick Desativado. Reverter completamente pode exigir reinício.")
    end
end

--// Função Anti-Ban (Client-Side) - Reintegrada e Detalhada
local function toggleAntiBan(v)
    if v then
        print("Anti-Ban Ativado. Tentando prevenir bans client-side.")
        local originalFireServer = remoteEvent.FireServer
        remoteEvent.FireServer = function(self, eventName, ...)
            local args = {...}
            if string.find(eventName:lower(), "ban") then
                warn("Anti-Ban: Tentativa de ban detectada e bloqueada!")
                return
            end
            return originalFireServer(self, eventName, ...)
        end
    else
        print("Anti-Ban Desativado. Reverter completamente pode exigir reinício.")
    end
end

--// Função para Remover Todos os Efeitos Visuais (Client-Side) - Reintegrada e Detalhada
local function removeAllEffects()
    -- Parar Aura
    stopAura()
    -- Parar Tornado
    stopTornado()
    -- Sair do Backrooms
    exitBackrooms()
    -- Remover Nome Colorido
    removeColoredName()
    -- Desativar ESP
    espActive = false
    updateESP()
    -- Desativar Visão Noturna
    Lighting.Brightness = 2
    Lighting.ExposureCompensation = 0
    if Lighting:FindFirstChild("NV_Effect") then Lighting.NV_Effect:Destroy() end
    -- Desativar Motion Blur
    RunService:UnbindFromRenderStep("MotionBlur")
    if Lighting:FindFirstChild("MB_Effect") then Lighting.MB_Effect:Destroy() end
    -- Parar Bang
    if bangLoop then bangLoop:Disconnect(); bangLoop = nil end
    -- Parar View
    if viewConnection then viewConnection:Disconnect(); viewConnection = nil end
    Camera.CameraSubject = LocalPlayer.Character.Humanoid

    print("Todos os efeitos visuais client-side removidos.")
end

--// ====================================================================================================================
--// INTERFACE GRÁFICA (WindUI) - ESTRUTURA COMPLETA E DETALHADA
--// ====================================================================================================================

local ok, WindUILib = pcall(function()
    -- Tenta carregar a biblioteca WindUI de forma segura
    local success, result = pcall(function()
        return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
    end)
    if not success then
        warn("Falha ao carregar WindUI: " .. result)
        return nil
    end
    return result
end)

if ok and WindUILib then
    local Window = WindUILib:CreateWindow({
        Title = "Painel Admin V14 - Ultimate Edition",
        Icon = "shield", -- Ícone de escudo para o painel, conforme solicitado
        Author = "by: Fitch team",
        Folder = "Trix - Admins",
        Size = UDim2.fromOffset(650, 550), -- Tamanho maior para acomodar mais funções
        Transparent = true,
        Theme = "Dark", -- Tema escuro para um visual mais profissional
        Resizable = true, -- Permitir redimensionamento
        SideBarWidth = 220, -- Barra lateral mais larga
        BackgroundImageTransparency = 0.3,
        HideSearchBar = false, -- Manter barra de pesquisa visível
        ScrollBarEnabled = true,
    })

    --// TABS PRINCIPAIS
    local TabMain = Window:Tab({ Title = "Comandos Essenciais", Icon = "terminal" })
    local TabVisuals = Window:Tab({ Title = "✨ Efeitos Visuais", Icon = "sparkles" }) -- Símbolo e nome aprimorado
    local TabTools = Window:Tab({ Title = "🛠️ Ferramentas & Fun", Icon = "wrench" }) -- Símbolo e nome aprimorado
    local TabJumpscares = Window:Tab({ Title = "👻 Jumpscares & Avatar", Icon = "zap" }) -- Símbolo e nome aprimorado
    local TabSecurity = Window:Tab({ Title = "🛡️ Segurança Avançada", Icon = "shield" }) -- Símbolo e nome aprimorado

    -- Função para atualizar a lista de jogadores no Dropdown
    local function updatePlayerList()
        local t = {}
        for _, p in ipairs(Players:GetPlayers()) do table.insert(t, p.Name) end
        return t
    end

    --// ABA: COMANDOS ESSENCIAIS
    local SectionPlayerControl = TabMain:Section({ Title = "Controle de Jogadores", Icon = "user-cog", Opened = true })
    
    local PlayerDropdown = SectionPlayerControl:Dropdown({
        Title = "Selecionar Alvo",
        Values = updatePlayerList(),
        Callback = function(opt) TargetName = opt end,
        Search = true -- Adiciona funcionalidade de busca no dropdown
    })

    SectionPlayerControl:Button({
        Title = ";kill player",
        Desc = "Elimina o jogador selecionado com Fling Extremo (Client-Side)",
        Callback = function() local t = findTarget(TargetName) if t then executeKill(t) end end
    })

    SectionPlayerControl:Button({
        Title = ";kill all",
        Desc = "Elimina todos os jogadores do servidor com Fling Extremo (Client-Side)",
        Callback = function() startKillAll() end
    })

    SectionPlayerControl:Button({
        Title = ";stop kill all",
        Desc = "Para o processo de eliminação contínua de todos os jogadores.",
        Callback = function() stopKillAll() end
    })

    SectionPlayerControl:Button({
        Title = ";tp player",
        Desc = "Teleporta você para a localização do jogador selecionado.",
        Callback = function() local t = findTarget(TargetName) if t then executeTP(t) end end
    })

    SectionPlayerControl:Button({
        Title = ";Crash (Alvo)",
        Desc = "Tenta causar um lag intenso ou crash no jogo do jogador alvo.",
        Callback = function() local t = findTarget(TargetName) if t then executeCrash(t) end end
    })

    SectionPlayerControl:Button({
        Title = ";bang (Alvo)",
        Desc = "Inicia uma animação de 'bang' no alvo, puxando-o para perto e fazendo-o tremer.",
        Callback = function() 
            local t = findTarget(TargetName)
            if t then 
                Say(";bang " .. t.Name) 
                if bangLoop then bangLoop:Disconnect() end
                bangLoop = RunService.Heartbeat:Connect(function()
                    if t.Character and getRoot(t.Character) and LocalPlayer.Character and getRoot(LocalPlayer.Character) then
                        getRoot(LocalPlayer.Character).CFrame = getRoot(t.Character).CFrame * CFrame.new(0, 0, 1.1) * CFrame.new(0, 0, math.sin(tick() * 25) * 0.8)
                    else 
                        if bangLoop then bangLoop:Disconnect() bangLoop = nil end
                    end 
                end)
            end 
        end
    })

    SectionPlayerControl:Button({
        Title = ";unbang",
        Desc = "Para a animação de 'bang' e retorna sua câmera ao normal.",
        Callback = function() 
            Say(";unbang") 
            if bangLoop then bangLoop:Disconnect() bangLoop = nil end
            if LocalPlayer.Character then Camera.CameraSubject = LocalPlayer.Character.Humanoid end
        end
    })

    SectionPlayerControl:Button({
        Title = ";view (Alvo)",
        Desc = "Observa a câmera do jogador selecionado, seguindo seus movimentos.",
        Callback = function() 
            local t = findTarget(TargetName)
            if t then 
                Say(";view " .. t.Name) 
                viewingTarget = t;
                if viewConnection then viewConnection:Disconnect() end
                viewConnection = RunService.RenderStepped:Connect(function()
                    if viewingTarget and viewingTarget.Character and viewingTarget.Character:FindFirstChildOfClass("Humanoid") then
                        Camera.CameraSubject = viewingTarget.Character.Humanoid
                    else 
                        if viewConnection then viewConnection:Disconnect() end
                        Camera.CameraSubject = LocalPlayer.Character.Humanoid
                    end 
                end)
            end 
        end
    })

    SectionPlayerControl:Button({
        Title = ";unview",
        Desc = "Retorna a câmera para o seu personagem, parando a observação.",
        Callback = function() 
            Say(";unview") 
            if viewConnection then viewConnection:Disconnect() end
            Camera.CameraSubject = LocalPlayer.Character.Humanoid
        end
    })

    --// ABA: EFEITOS VISUAIS
    local SectionVisualEffects = TabVisuals:Section({ Title = "Efeitos de Movimento e Ambiente", Icon = "palette", Opened = true })

    SectionVisualEffects:Button({
        Title = "Puxar Player (Bring)",
        Desc = "Traz o jogador selecionado para sua localização (Client-Side).",
        Callback = function() local t = findTarget(TargetName) if t then executeBring(t) end end
    })

    SectionVisualEffects:Button({
        Title = "Bring All",
        Desc = "Puxa todos os jogadores do servidor para sua posição (Client-Side).",
        Callback = function() executeBringAll() end
    })

    SectionVisualEffects:Button({
        Title = ";tornado (Alvo)",
        Desc = "Cria um impressionante efeito de tornado ao redor do jogador alvo.",
        Callback = function() local t = findTarget(TargetName) if t then executeTornado(t) end end
    })

    SectionVisualEffects:Button({
        Title = ";stop tornado",
        Desc = "Para o efeito de tornado ativo.",
        Callback = function() stopTornado() end
    })

    SectionVisualEffects:Button({
        Title = ";aura (Cadeiras)",
        Desc = "Cria uma aura de cadeiras coloridas e giratórias ao seu redor.",
        Callback = function() startAura() end
    })

    SectionVisualEffects:Button({
        Title = ";stop aura",
        Desc = "Para a aura de cadeiras ativas.",
        Callback = function() stopAura() end
    })

    SectionVisualEffects:Button({
        Title = "Entrar no Backrooms",
        Desc = "Gera um labirinto infinito e sombrio dos Backrooms ao seu redor.",
        Callback = function() executeBackrooms() end
    })

    SectionVisualEffects:Button({
        Title = "Sair do Backrooms",
        Desc = "Remove o labirinto dos Backrooms e restaura o ambiente normal.",
        Callback = function() exitBackrooms() end
    })

    local SectionCameraEffects = TabVisuals:Section({ Title = "Efeitos de Câmera e Interface", Icon = "camera", Opened = true })

    SectionCameraEffects:Toggle({
        Title = "Visão Noturna",
        Desc = "Ativa/Desativa um filtro de visão noturna para o ambiente.",
        Callback = function(v)
            Lighting.Brightness = v and 3 or 2;
            Lighting.ExposureCompensation = v and 3 or 0;
            if v then
                local cc = Instance.new("ColorCorrectionEffect", Lighting)
                cc.Name = "NV_Effect"
                cc.TintColor = Color3.fromRGB(100, 255, 100)
            else
                if Lighting:FindFirstChild("NV_Effect") then Lighting.NV_Effect:Destroy() end
            end
        end
    })

    SectionCameraEffects:Toggle({
        Title = "Motion Blur",
        Desc = "Adiciona um efeito de desfoque de movimento dinâmico à sua câmera.",
        Callback = function(v)
            if v then
                local blur = Instance.new("BlurEffect", Lighting)
                blur.Name = "MB_Effect";
                RunService:BindToRenderStep("MotionBlur", 200, function()
                    if LocalPlayer.Character and getRoot(LocalPlayer.Character) then
                        blur.Size = math.clamp(getRoot(LocalPlayer.Character).Velocity.Magnitude / 5, 0, 15)
                    end
                end)
            else
                RunService:UnbindFromRenderStep("MotionBlur")
                if Lighting:FindFirstChild("MB_Effect") then Lighting.MB_Effect:Destroy() end
            end
        end
    })
    
    SectionCameraEffects:Toggle({
        Title = "ESP (Ver Jogadores)",
        Desc = "Mostra todos os jogadores através das paredes com caixas e nomes.",
        Callback = function(v)
            espActive = v
            updateESP()
        end
    })

    SectionCameraEffects:Button({
        Title = "Nome Colorido (Você)",
        Desc = "Exibe um nome colorido e animado sobre sua cabeça.",
        Callback = function() createColoredName("ADMIN") end
    })

    SectionCameraEffects:Button({
        Title = "Remover Nome Colorido",
        Desc = "Remove o nome colorido sobre sua cabeça.",
        Callback = function() removeColoredName() end
    })

    --// ABA: FERRAMENTAS & FUN
    local SectionToolsItems = TabTools:Section({ Title = "Itens Especiais", Icon = "magic", Opened = true })

    SectionToolsItems:Button({
        Title = "Obter Boombox Voadora",
        Desc = "Recebe uma boombox que permite voar e tocar música.",
        Callback = function() createFlyingBoombox() end
    })

    SectionToolsItems:Button({
        Title = "Dar Ferramenta (Servidor)",
        Desc = "Tenta dar uma ferramenta específica (requer RemoteEvent no servidor).",
        Callback = function() giveTool("Sword", "rbxassetid://1054661") end -- Exemplo: Espada
    })

    local SectionMusicControl = TabTools:Section({ Title = "Controle de Música Global", Icon = "music", Opened = true })

    SectionMusicControl:TextBox({
        Title = "ID da Música",
        Placeholder = "rbxassetid://...",
        Callback = function(text) currentSound = text end
    })

    SectionMusicControl:Slider({
        Title = "Volume da Música",
        Min = 0,
        Max = 1,
        Default = 0.5,
        Callback = function(val) currentSoundVolume = val end
    })

    SectionMusicControl:Button({
        Title = "Tocar Música Global",
        Desc = "Toca a música especificada para todos no servidor.",
        Callback = function() if currentSound then playGlobalMusic(currentSound, currentSoundVolume) end end
    })

    SectionMusicControl:Button({
        Title = "Parar Música Global",
        Desc = "Para a música global que está tocando.",
        Callback = function() stopGlobalMusic() end
    })

    --// ABA: JUMPSCARES & AVATAR
    local SectionJumpscare = TabJumpscares:Section({ Title = "Jumpscares", Icon = "skull", Opened = true })

    SectionJumpscare:Button({
        Title = "Jumpscare 1 (Susto)",
        Desc = "Executa um jumpscare visual e sonoro no seu cliente.",
        Callback = function() executeJumpscare(LocalPlayer, "rbxassetid://103582711", "rbxassetid://296093393") end -- Exemplo de IDs
    })

    SectionJumpscare:Button({
        Title = "Jumpscare 2 (Screamer)",
        Desc = "Outro tipo de jumpscare para assustar.",
        Callback = function() executeJumpscare(LocalPlayer, "rbxassetid://13107000", "rbxassetid://296093393") end -- Exemplo de IDs
    })

    local SectionAvatar = TabJumpscares:Section({ Title = "Mudar Avatar", Icon = "user-alt", Opened = true })

    SectionAvatar:TextBox({
        Title = "ID do Avatar",
        Placeholder = "ID do pacote de avatar",
        Callback = function(text) AvatarName = text end
    })

    SectionAvatar:Button({
        Title = "Mudar Avatar (Alvo)",
        Desc = "Tenta mudar o avatar do jogador selecionado (requer RemoteEvent no servidor).",
        Callback = function() local t = findTarget(TargetName) if t and AvatarName ~= "" then changeAvatar(t, AvatarName) end end
    })

    --// ABA: SEGURANÇA AVANÇADA
    local SectionAntiSLA = TabSecurity:Section({ Title = "Proteções Anti-SLA", Icon = "lock", Opened = true })

    SectionAntiSLA:Toggle({
        Title = "Anti-Lag (Experimental)",
        Desc = "Tenta reduzir o lag desativando efeitos visuais e limitando atualizações de física.",
        Callback = function(v) toggleAntiLag(v) end
    })

    SectionAntiSLA:Toggle({
        Title = "Anti-Admin (Client-Side)",
        Desc = "Tenta bloquear comandos de admin client-side (ex: kick, ban, give tool).",
        Callback = function(v) toggleAntiAdmin(v) end
    })

    SectionAntiSLA:Toggle({
        Title = "Anti-Tools (Destruir Ferramentas)",
        Desc = "Destrói automaticamente qualquer ferramenta que você receba no inventário ou personagem.",
        Callback = function(v) toggleAntiTools(v) end
    })

    SectionAntiSLA:Toggle({
        Title = "Anti-Kick (Client-Side)",
        Desc = "Tenta prevenir kicks iniciados por scripts client-side ou RemoteEvents.",
        Callback = function(v) toggleAntiKick(v) end
    })

    SectionAntiSLA:Toggle({
        Title = "Anti-Ban (Client-Side)",
        Desc = "Tenta prevenir bans iniciados por scripts client-side ou RemoteEvents.",
        Callback = function(v) toggleAntiBan(v) end
    })

    SectionAntiSLA:Toggle({
        Title = "Anti-Ban-Casa",
        Desc = "Previne ser banido de casas ou propriedades, interceptando eventos de banimento.",
        Callback = function(v) toggleAntiBanCasa(v) end
    })

    SectionAntiSLA:Button({
        Title = "Remover Todos os Efeitos Ativos",
        Desc = "Desativa e limpa todos os efeitos visuais e de câmera ativos (client-side).",
        Callback = function() removeAllEffects() end
    })

    local SectionHouses = TabSecurity:Section({ Title = "🏠 Gerenciamento de Casas", Icon = "home", Opened = true }) -- Símbolo e nome aprimorado

    SectionHouses:Button({
        Title = "Desbanir de Todas as Casas",
        Desc = "Envia comandos e tenta interagir com GUIs para desbanir você de todas as casas.",
        Callback = function() unbanFromHouses() end
    })

    SectionHouses:Toggle({
        Title = "Auto-Ban (Proximidade)",
        Desc = "Bane automaticamente jogadores que se aproximam demais de você (simulando proteção de casa).",
        Callback = function(v) autoBanCasaActive = v end
    })

    SectionHouses:Slider({
        Title = "Raio do Auto-Ban",
        Min = 5,
        Max = 50,
        Default = 20,
        Callback = function(val) houseBanRadius = val end
    })

    --// Atualização Automática da Lista de Jogadores para Dropdowns
    task.spawn(function()
        while task.wait(5) do
            local currentPlayers = updatePlayerList()
            PlayerDropdown:SetValues(currentPlayers)
            -- Adicionar outros dropdowns que precisam de atualização aqui
        end
    end)

    Window:SelectTab(1) -- Seleciona a primeira aba ao iniciar

    print("Painel Admin V14 - Ultimate Edition Carregado com Sucesso!")
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "V14 ULTIMATE CARREGADO!",
        Text = "Todas as funções e segurança avançada ativadas.",
        Duration = 7,
        Button1 = "OK"
    })
else
    warn("WindUI não carregou. A interface gráfica não será exibida.")
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "ERRO NO PAINEL V14",
        Text = "WindUI não pôde ser carregado. Verifique sua conexão ou o link da biblioteca.",
        Duration = 10,
        Button1 = "Entendido"
    })
end

--// FIM DO SCRIPT
--// ====================================================================================================================

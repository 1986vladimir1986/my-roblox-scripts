local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local FOV_RADIUS = 30
local isScriptActive, isRmbPressed, currentTargetPart = false, false, nil

-- Очистка старых подключений
if _G.AimConnection then _G.AimConnection:Disconnect() end
if _G.InputBeganConn then _G.InputBeganConn:Disconnect() end
if _G.InputEndedConn then _G.InputEndedConn:Disconnect() end
if _G.FOVCircle then _G.FOVCircle:Destroy() end

if _G.ESP_Storage then
    for _, s in pairs(_G.ESP_Storage) do
        pcall(function() 
            s.Box:Destroy(); s.HealthBar:Destroy(); s.HealthBG:Destroy(); s.NameText:Destroy()
            if s.Skeleton then
                for _, bone in pairs(s.Skeleton) do bone:Destroy() end
            end
        end)
    end
end
_G.ESP_Storage = {}

local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible, FOVCircle.Radius, FOVCircle.Color, FOVCircle.Thickness = false, FOV_RADIUS, Color3.fromRGB(0, 255, 0), 1
_G.FOVCircle = FOVCircle

local function isAlly(player)
    if player == LocalPlayer then return true end
    return player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team and player.Team.Name ~= "Neutral"
end

local function getClosestTarget()
    if currentTargetPart and currentTargetPart.Parent and currentTargetPart.Parent:FindFirstChildOfClass("Humanoid") and currentTargetPart.Parent:FindFirstChildOfClass("Humanoid").Health > 0 then
        return currentTargetPart
    end
    local closest, shortest = nil, math.huge
    local mousePos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and not isAlly(p) then
            local head = p.Character:FindFirstChild("Head")
            if head then
                local sPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen and (Vector2.new(sPos.X, sPos.Y) - mousePos).Magnitude < FOV_RADIUS then
                    local dist = (head.Position - Camera.CFrame.Position).Magnitude
                    if dist < shortest then shortest, closest = dist, head end
                end
            end
        end
    end
    currentTargetPart = closest
    return closest
end

-- Скелетные структуры для R6 и R15
local SkeletonRig = {
    R6 = {
        {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
        {"Torso", "Left Leg"}, {"Torso", "Right Leg"}
    },
    R15 = {
        {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
        {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
        {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
        {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
        {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}
    }
}

local function initPlayerESP(player)
    if player == LocalPlayer then return end
    local function setup()
        if _G.ESP_Storage[player.UserId] then return end
        
        local skeletonLines = {}
        for i = 1, 15 do 
            local line = Drawing.new("Line")
            line.Color = Color3.fromRGB(255, 255, 255)
            line.Thickness = 1.5
            line.Visible = false
            table.insert(skeletonLines, line)
        end

        local s = {
            Box = Drawing.new("Square"), HealthBG = Drawing.new("Square"), HealthBar = Drawing.new("Square"),
            NameText = Drawing.new("Text"), Skeleton = skeletonLines
        }
        s.Box.Color, s.Box.Visible = Color3.fromRGB(255,0,0), false
        s.HealthBG.Color, s.HealthBG.Filled, s.HealthBG.Visible = Color3.fromRGB(0,0,0), true, false
        s.HealthBar.Filled, s.HealthBar.Visible = true, false
        s.NameText.Color, s.NameText.Size, s.NameText.Center, s.NameText.Outline, s.NameText.Visible = Color3.fromRGB(255, 255, 255), 14, true, true, false
        
        _G.ESP_Storage[player.UserId] = s
    end
    player.CharacterAdded:Connect(setup)
    setup()
end

for _, p in ipairs(Players:GetPlayers()) do initPlayerESP(p) end
_G.PlayerAddedConn = Players.PlayerAdded:Connect(initPlayerESP)

_G.InputBeganConn = UserInputService.InputBegan:Connect(function(i)
    if i.KeyCode == Enum.KeyCode.F1 then
        isScriptActive = not isScriptActive
        FOVCircle.Visible = isScriptActive
        if not isScriptActive then
            for _, s in pairs(_G.ESP_Storage) do 
                s.Box.Visible, s.HealthBG.Visible, s.HealthBar.Visible, s.NameText.Visible = false, false, false, false
                for _, line in pairs(s.Skeleton) do line.Visible = false end
            end
            currentTargetPart = nil
        end
    elseif i.UserInputType == Enum.UserInputType.MouseButton2 then isRmbPressed = true end
end)

_G.InputEndedConn = UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton2 then isRmbPressed, currentTargetPart = false, nil end
end)

-- Основной цикл обновлений
_G.AimConnection = RunService.RenderStepped:Connect(function()
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    -- Шаг 1: Жесткий Лок-он с блокировкой поведения мыши
    if isScriptActive and isRmbPressed then
        local t = getClosestTarget()
        if t then 
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, t.Position)
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter -- Сбрасывает ручной сдвиг мыши во время аима
        end
    else currentTargetPart = nil end

    -- Шаг 2: Отрисовка ВХ и Скелетов
    for _, p in ipairs(Players:GetPlayers()) do
        local s = _G.ESP_Storage[p.UserId]
        if isScriptActive and s and p.Character and not isAlly(p) then
            local r = p.Character:FindFirstChild("HumanoidRootPart") or p.Character:FindFirstChild("Head")
            local h = p.Character:FindFirstChildOfClass("Humanoid")
            
            if r and h and h.Health > 0 then
                local sPos, onScreen = Camera:WorldToViewportPoint(r.Position)
                if onScreen then
                    -- Расчет Боксов
                    local sc = 1 / (sPos.Z * 2) * 1000
                    local w, hDim = 2.5 * sc, 4.5 * sc
                    local x, y = sPos.X - w / 2, sPos.Y - hDim / 2
                    
                    s.Box.Size, s.Box.Position, s.Box.Visible = Vector2.new(w, hDim), Vector2.new(x, y), true
                    s.HealthBG.Size, s.HealthBG.Position, s.HealthBG.Visible = Vector2.new(3, hDim), Vector2.new(x - 7, y), true
                    
                    local hp = math.clamp(h.Health / h.MaxHealth, 0, 1)
                    s.HealthBar.Size, s.HealthBar.Position = Vector2.new(3, hDim * hp), Vector2.new(x - 7, y + (hDim - hDim * hp))
                    s.HealthBar.Color, s.HealthBar.Visible = Color3.fromHSV(hp * 0.33, 1, 1), true
                    
                    s.NameText.Text, s.NameText.Position, s.NameText.Visible = p.Name, Vector2.new(sPos.X, y - 16), true
                    
                    -- Отрисовка скелета
                    local rigType = (h.RigType == Enum.HumanoidRigType.R6) and "R6" or "R15"
                    local connections = SkeletonRig[rigType]
                    
                    for lineIdx, line in ipairs(s.Skeleton) do
                        local conn = connections[lineIdx]
                        if conn then
                            local partA = p.Character:FindFirstChild(conn[1])
                            local partB = p.Character:FindFirstChild(conn[2])
                            
                            if partA and partB then
                                local posA, onScreenA = Camera:WorldToViewportPoint(partA.Position)
                                local posB, onScreenB = Camera:WorldToViewportPoint(partB.Position)
                                
                                if onScreenA and onScreenB then
                                    line.From = Vector2.new(posA.X, posA.Y)
                                    line.To = Vector2.new(posB.X, posB.Y)
                                    line.Visible = true
                                    continue
                                end
                            end
                        end
                        line.Visible = false
                    end
                    continue
                end
            end
        end
        if s then 
            s.Box.Visible, s.HealthBG.Visible, s.HealthBar.Visible, s.NameText.Visible = false, false, false, false 
            for _, line in pairs(s.Skeleton) do line.Visible = false end
        end
    end
end)

Players.PlayerRemoving:Connect(function(p)
    if _G.ESP_Storage[p.UserId] then
        pcall(function() 
            _G.ESP_Storage[p.UserId].Box:Destroy(); _G.ESP_Storage[p.UserId].HealthBar:Destroy(); _G.ESP_Storage[p.UserId].HealthBG:Destroy()
            _G.ESP_Storage[p.UserId].NameText:Destroy()
            for _, line in pairs(_G.ESP_Storage[p.UserId].Skeleton) do line:Destroy() end
        end)
        _G.ESP_Storage[p.UserId] = nil
    end
end)

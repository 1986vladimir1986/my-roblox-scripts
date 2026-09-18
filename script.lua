local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local FOV_RADIUS = 30
local isScriptActive, isRmbPressed, currentTargetPart = false, false, nil

-- Очистка старых сессий скрипта
if _G.AimConnection then _G.AimConnection:Disconnect() end
if _G.InputBeganConn then _G.InputBeganConn:Disconnect() end
if _G.InputEndedConn then _G.InputEndedConn:Disconnect() end
if _G.FOVCircle then _G.FOVCircle:Destroy() end

if _G.ESP_Storage then
    for _, s in pairs(_G.ESP_Storage) do
        pcall(function() 
            s.HealthBar:Destroy(); s.HealthBG:Destroy(); s.NameText:Destroy()
            if s.Corners then for _, line in pairs(s.Corners) do line:Destroy() end end
            if s.Skeleton then for _, bone in pairs(s.Skeleton) do bone:Destroy() end end
        end)
    end
end
_G.ESP_Storage = {}

-- Создание FOV круга аима
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
        
        -- Ровно 8 линий для уголков (по 2 линии на каждый из 4 углов 2D-квадрата)
        local cornerLines = {}
        for i = 1, 8 do
            local line = Drawing.new("Line")
            line.Color = Color3.fromRGB(255, 0, 0)
            line.Thickness = 1.5
            line.Visible = false
            table.insert(cornerLines, line)
        end

        local skeletonLines = {}
        for i = 1, 15 do 
            local line = Drawing.new("Line")
            line.Color = Color3.fromRGB(255, 255, 255)
            line.Thickness = 1.5
            line.Visible = false
            table.insert(skeletonLines, line)
        end

        local s = {
            Corners = cornerLines, HealthBG = Drawing.new("Square"), HealthBar = Drawing.new("Square"),
            NameText = Drawing.new("Text"), Skeleton = skeletonLines
        }
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

-- Обработка клавиш (Активация по F1, удержание на ПКМ)
_G.InputBeganConn = UserInputService.InputBegan:Connect(function(i)
    if i.KeyCode == Enum.KeyCode.F1 then
        isScriptActive = not isScriptActive
        FOVCircle.Visible = isScriptActive
        if not isScriptActive then
            for _, s in pairs(_G.ESP_Storage) do 
                s.HealthBG.Visible, s.HealthBar.Visible, s.NameText.Visible = false, false, false
                for _, line in pairs(s.Corners) do line.Visible = false end
                for _, line in pairs(s.Skeleton) do line.Visible = false end
            end
            currentTargetPart = nil
        end
    elseif i.UserInputType == Enum.UserInputType.MouseButton2 then isRmbPressed = true end
end)

_G.InputEndedConn = UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton2 then isRmbPressed, currentTargetPart = false, nil end
end)

-- Обход тряски камеры через метатаблицы
local mt = getrawmetatable(game)
local oldNewIndex = mt.__newindex
setreadonly(mt, false)
mt.__newindex = newcclosure(function(t, k, v)
    if t == Camera and (k == "CFrame" or k == "CoordinateFrame" or k == "Focus") then
        if isScriptActive and isRmbPressed and currentTargetPart then return end
    end
    return oldNewIndex(t, k, v)
end)
setreadonly(mt, true)

-- Единый поток рендеринга (Aim, Boxes, Skeletons)
_G.AimConnection = RunService.RenderStepped:Connect(function()
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    if isScriptActive and isRmbPressed then
        local t = getClosestTarget()
        if t then 
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, t.Position)
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter 
        end
    else currentTargetPart = nil end

    for _, p in ipairs(Players:GetPlayers()) do
        local s = _G.ESP_Storage[p.UserId]
        if isScriptActive and s and p.Character and not isAlly(p) then
            local r = p.Character:FindFirstChild("HumanoidRootPart") or p.Character:FindFirstChild("Head")
            local h = p.Character:FindFirstChildOfClass("Humanoid")
            
            if r and h and h.Health > 0 then
                local sPos, onScreen = Camera:WorldToViewportPoint(r.Position)
                if onScreen then
                    -- Размеры увеличенного бокса
                    local sc = 1 / (sPos.Z * 2) * 1000
                    local w, hDim = 3.0 * sc, 5.2 * sc 
                    local x, y = sPos.X - w / 2, sPos.Y - hDim / 2
                    local cornerLength = w / 4 
                    
                    -- Отрисовка уголков по индексам 1-8 (Корректное сопоставление)
                    s.Corners[1].From, s.Corners[1].To, s.Corners[1].Visible = Vector2.new(x, y), Vector2.new(x + cornerLength, y), true
                    s.Corners[2].From, s.Corners[2].To, s.Corners[2].Visible = Vector2.new(x, y), Vector2.new(x, y + cornerLength), true
                    
                    s.Corners[3].From, s.Corners[3].To, s.Corners[3].Visible = Vector2.new(x + w, y), Vector2.new(x + w - cornerLength, y), true
                    s.Corners[4].From, s.Corners[4].To, s.Corners[4].Visible = Vector2.new(x + w, y), Vector2.new(x + w, y + cornerLength), true
                    
                    s.Corners[5].From, s.Corners[5].To, s.Corners[5].Visible = Vector2.new(x, y + hDim), Vector2.new(x + cornerLength, y + hDim), true
                    s.Corners[6].From, s.Corners[6].To, s.Corners[6].Visible = Vector2.new(x, y + hDim), Vector2.new(x, y + hDim - cornerLength), true
                    
                    s.Corners[7].From, s.Corners[7].To, s.Corners[7].Visible = Vector2.new(x + w, y + hDim), Vector2.new(x + w - cornerLength, y + hDim), true
                    s.Corners[8].From, s.Corners[8].To, s.Corners[8].Visible = Vector2.new(x + w, y + hDim), Vector2.new(x + w, y + hDim - cornerLength), true

                    -- Полоска здоровья
                    s.HealthBG.Size, s.HealthBG.Position, s.HealthBG.Visible = Vector2.new(3, hDim), Vector2.new(x - 10, y), true
                    local hp = math.clamp(h.Health / h.MaxHealth, 0, 1)
                    s.HealthBar.Size, s.HealthBar.Position = Vector2.new(3, hDim * hp), Vector2.new(x - 10, y + (hDim - hDim * hp))
                    s.HealthBar.Color, s.HealthBar.Visible = Color3.fromHSV(hp * 0.33, 1, 1), true
                    
                    s.NameText.Text, s.NameText.Position, s.NameText.Visible = p.Name, Vector2.new(sPos.X, y - 18), true
                    
                    -- Скелет
                    local rigType = (h.RigType == Enum.HumanoidRigType.R6) and "R6" or "R15"
                    local connections = SkeletonRig[rigType]
                    
                    for lineIdx, line in ipairs(s.Skeleton) do
                        local conn = connections[lineIdx]
                        if conn then
                            local partA = p.Character:FindFirstChild(conn[1])
                            local partB = p.Character:FindFirstChild(conn[2])
                            
                            if partA and partB then
Используйте код с осторожностью.local posA, onScreenA = Camera:WorldToViewportPoint(partA.Position)local posB, onScreenB = Camera:WorldToViewportPoint(partB.Position)if onScreenA and onScreenB thenline.From = Vector2.new(posA.X, posA.Y)line.To = Vector2.new(posB.X, posB.Y)line.Visible = truetable.insert({}, 1) -- Технический пропуск-- Заменяем некорректный continue на явное ветвлениеendendendif not line.Visible or not (p.Character:FindFirstChild(conn and conn[1] or "") and p.Character:FindFirstChild(conn and conn[2] or "")) thenline.Visible = falseendend-- Переход к следующему игрокуs.Corners[1].Visible = true -- Заглушка вместо continueendendendif s and (not isScriptActive or not p.Character or not p.Character:FindFirstChildOfClass("Humanoid") or p.Character:FindFirstChildOfClass("Humanoid").Health <= 0) thens.HealthBG.Visible, s.HealthBar.Visible, s.NameText.Visible = false, false, falsefor _, line in pairs(s.Corners) do line.Visible = false endfor _, line in pairs(s.Skeleton) do line.Visible = false endendendend)Players.PlayerRemoving:Connect(function(p)if _G.ESP_Storage[p.UserId] thenpcall(function()_G.ESP_Storage[p.UserId].HealthBar:Destroy(); _G.ESP_Storage[p.UserId].HealthBG:Destroy(); _G.ESP_Storage[p.UserId].NameText:Destroy()for _, line in pairs(_G.ESP_Storage[p.UserId].Corners) do line:Destroy() endfor _, line in pairs(_G.ESP_Storage[p.UserId].Skeleton) do line:Destroy() endend)_G.ESP_Storage[p.UserId] = nilendend)

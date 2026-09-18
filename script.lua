task.wait(0.5)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local FOV_RADIUS = 30
local isScriptActive, isRmbPressed, currentTargetPart = false, false, nil

pcall(function()
    if _G.AimConnection then _G.AimConnection:Disconnect() end
    if _G.InputBeganConn then _G.InputBeganConn:Disconnect() end
    if _G.InputEndedConn then _G.InputEndedConn:Disconnect() end
    if _G.PlayerAddedConn then _G.PlayerAddedConn:Disconnect() end
    if _G.PlayerRemovingConn then _G.PlayerRemovingConn:Disconnect() end
    if _G.FOVCircle then _G.FOVCircle:Destroy() end

    if _G.ESP_Storage then
        for _, s in pairs(_G.ESP_Storage) do
            pcall(function() 
                s.Tracer:Destroy()
                if s.Chams then s.Chams:Destroy() end
                if s.Gui3D then s.Gui3D:Destroy() end
            end)
        end
    end
end)

_G.ESP_Storage = {}

local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = false
FOVCircle.Radius = FOV_RADIUS
FOVCircle.Color = Color3.fromRGB(0, 255, 0)
FOVCircle.Thickness = 1
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

local function create3DGui(character, playerName)
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 150, 0, 30)
    bb.AlwaysOnTop = true
    bb.ExtentsOffset = Vector3.new(0, 3.5, 0)
    bb.Enabled = false
    
    local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    if head then bb.Adornee = head end
    
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, 0, 0, 14)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.fromRGB(255, 255, 255)
    text.TextStrokeTransparency = 0
    text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    text.TextSize = 12
    text.Font = Enum.Font.SourceSansBold
    text.Text = playerName
    text.Parent = bb
    
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0, 60, 0, 4)
    bg.Position = UDim2.new(0.5, -30, 0, 16)
    bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bg.BorderSizePixel = 0
    bg.Parent = bb
    
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 1, 0)
    bar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    bar.BorderSizePixel = 0
    bar.Parent = bg
    
    bb.Parent = game:GetService("CoreGui")
    return bb, bar, text
end

local function initPlayerESP(player)
    if player == LocalPlayer then return end
    local function setup()
        if _G.ESP_Storage[player.UserId] then return end
        
        local highlight = Instance.new("Highlight")
        highlight.FillColor = Color3.fromRGB(255, 255, 255)
        highlight.FillTransparency = 0.5
        highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Enabled = false

        local gui3d, bar3d, text3d = nil, nil, nil
        if player.Character then
            highlight.Parent = player.Character
            gui3d, bar3d, text3d = create3DGui(player.Character, player.Name)
        end

        local s = {
            Tracer = Drawing.new("Line"),
            Chams = highlight,
            Gui3D = gui3d,
            Bar3D = bar3d,
            Text3D = text3d
        }
        
        s.Tracer.Color, s.Tracer.Thickness, s.Tracer.Visible = Color3.fromRGB(255, 255, 255), 1, false
        
        _G.ESP_Storage[player.UserId] = s
    end
    
    player.CharacterAdded:Connect(function(char)
        task.wait(0.2)
        local s = _G.ESP_Storage[player.UserId]
        if s then
            if s.Chams then s.Chams.Parent = char end
            if s.Gui3D then s.Gui3D:Destroy() end
            local gui3d, bar3d, text3d = create3DGui(char, player.Name)
            s.Gui3D = gui3d
            s.Bar3D = bar3d
            s.Text3D = text3d
        end
    end)
    setup()
end

local function removePlayerESP(player)
    local s = _G.ESP_Storage[player.UserId]
    if s then
        pcall(function()
            s.Tracer:Destroy()
            if s.Chams then s.Chams:Destroy() end
            if s.Gui3D then s.Gui3D:Destroy() end
        end)
        _G.ESP_Storage[player.UserId] = nil
    end
end

for _, p in ipairs(Players:GetPlayers()) do initPlayerESP(p) end
_G.PlayerAddedConn = Players.PlayerAdded:Connect(initPlayerESP)
_G.PlayerRemovingConn = Players.PlayerRemoving:Connect(removePlayerESP)

_G.InputBeganConn = UserInputService.InputBegan:Connect(function(i)
    if i.KeyCode == Enum.KeyCode.F1 then
        isScriptActive = not isScriptActive
        FOVCircle.Visible = isScriptActive
        if not isScriptActive then
            for _, s in pairs(_G.ESP_Storage) do 
                s.Tracer.Visible = false
                if s.Chams then s.Chams.Enabled = false end
                if s.Gui3D then s.Gui3D.Enabled = false end
            end
            currentTargetPart = nil
        end
    elseif i.UserInputType == Enum.UserInputType.MouseButton2 then 
        isRmbPressed = true 
    end
end)

_G.InputEndedConn = UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton2 then 
        isRmbPressed, currentTargetPart = false, nil 
    end
end)

_G.AimConnection = RunService.RenderStepped:Connect(function()
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    if isScriptActive and isRmbPressed then
        local t = getClosestTarget()
        if t then 
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, t.Position)
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        end
    else 
        currentTargetPart = nil 
    end

    pcall(function()
        for _, p in ipairs(Players:GetPlayers()) do
            local s = _G.ESP_Storage[p.UserId]
            if isScriptActive and s and p.Character and not isAlly(p) then
                local r = p.Character:FindFirstChild("HumanoidRootPart") or p.Character:FindFirstChild("Head")
                local h = p.Character:FindFirstChildOfClass("Humanoid")
                
                if r and h and h.Health > 0 then
                    if s.Chams then 
                        if s.Chams.Parent ~= p.Character then s.Chams.Parent = p.Character end
                        s.Chams.Enabled = true 
                    end
                    
                    if s.Gui3D then 
                        s.Gui3D.Enabled = true 
                        local currentHp = math.floor(h.Health)
                        local maxHp = math.floor(h.MaxHealth)
                        local hpPercent = math.clamp(h.Health / h.MaxHealth, 0, 1)
                        
                        s.Text3D.Text = p.Name .. " [" .. currentHp .. "/" .. maxHp .. "]"
                        s.Bar3D.Size = UDim2.new(hpPercent, 0, 1, 0)
                        s.Bar3D.BackgroundColor3 = Color3.fromHSV(hpPercent * 0.33, 1, 1)
                    end

                    local sPos, onScreen = Camera:WorldToViewportPoint(r.Position)
                    if onScreen then                   
                        s.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        s.Tracer.To = Vector2.new(sPos.X, sPos.Y)
                        s.Tracer.Visible = true
                    else
                        s.Tracer.Visible = false
                    end
                else
                    s.Tracer.Visible = false
                    if s.Chams then s.Chams.Enabled = false end
                    if s.Gui3D then s.Gui3D.Enabled = false end
                end
            elseif s then
                s.Tracer.Visible = false
                if s.Chams then s.Chams.Enabled = false end
                if s.Gui3D then s.Gui3D.Enabled = false end
            end
        end
    end)
end)

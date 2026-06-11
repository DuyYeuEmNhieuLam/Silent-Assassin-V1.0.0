--[[
    ================================================================
    [ SCRIPT INFORMATION ]
    Project: Custom Script
    Author: OYB
    YouTube: https://www.youtube.com/channel/UCAlXXV1Hbvf7WbfXARuVtiQ
    
    [ TERMS AND CONDITIONS ]
    - You ARE allowed to use and modify this script for your own games.
    - You ARE NOT allowed to re-upload, redistribute, or claim 
      ownership of this script.
    - Removing or altering these credits is strictly prohibited.
    
    Copyright (c) 2026 OYB. All rights reserved.
    ================================================================
]]

-- ⚠️ IMPORTANT: Put this code at the VERY TOP of your Main Script (before obfuscating) ⚠️

local ProtectionConfig = {
    -- 🔴 CRITICAL: This MUST exactly match the 'Secret' value in your Key System's Config!
    -- If your Key System has: Secret = "Test"
    -- Then this must also be: SecretKey = "Test"
    SecretKey = "16092012",
    
    -- The name of your Hub (shown in the kick message if they try to bypass)
    HubName = "Perfect LoopDash"
}

-- Anti-Bypass Logic: Checks if the Key System successfully set the global variable
if not _G[ProtectionConfig.SecretKey] then
    local player = game:GetService("Players").LocalPlayer
    if player then
        player:Kick("\n🛡️ Unauthorized Execution 🛡️\n\nPlease use the official Key System to run " .. ProtectionConfig.HubName)
    end
    return -- Stops the rest of the script from loading!
end

-------------------------------------------------------------------------------
-- 👇 YOUR MAIN SCRIPT CODE STARTS HERE 👇
-------------------------------------------------------------------------------

print(ProtectionConfig.HubName .. " Loaded Successfully!")

local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = game.Players.LocalPlayer
local TweenService = game:GetService("TweenService")

--// HỆ THỐNG KHAI TỬ SCRIPT CŨ
local scriptId = math.random(1, 1000000)
_G.LoopDashId = scriptId
local function isCurrent() return _G.LoopDashId == scriptId end

--// CONFIG
local Config = {
    Enabled = true,
    LoopDashAnim = "rbxassetid://10503381238",
    LoopDashDelay = 0.28,
    LoopDashJump = 55,
    LoopDashAccuracy = 15,
    LoopDashCancelDelay = 0.4,
    LoopDashMode = "BodyGyro",
    CancelEnabled = true,
    CooldownActive = true,
    NoClipEnabled = true,
    DashRange = 8,
    Platform = "PC",
    Keybind = "E",
    CooldownAnims = {
        ["10491993682"] = true,
        ["10479335397"] = true,
        ["13380255751"] = true,
    },
    JumpMode = "Normal",
    JumpDelay = 0.25,
    DashDuration = 1.5,
    CamSmooth = false,
}

local isNoclipping = false
local isCooldown = false
local isExecuting = false

-- // BIẾN GUI TOÀN CỤC
local ScreenGui, MainFrame, CooldownBar, CooldownFill
local SettingsFrame = nil
local isSettingsOpen = false

-- // HÀM TRÍCH XUẤT ID SỐ
local function getId(str)
    return tostring(str):match("%d+")
end

--// HÀM DASH MỚI (SỬ DỤNG REMOTEEVENT)
local function fireDash()
    local char = player.Character
    if not char then return end
    local communicate = char:FindFirstChild("Communicate")
    if communicate then
        local args = {{
            Dash = Enum.KeyCode.W,
            Key = Enum.KeyCode.Q,
            Goal = "KeyPress"
        }}
        communicate:FireServer(table.unpack(args))
    end
end

--// HÀM BỔ TRỢ
local function clip()
    isNoclipping = false
    if player.Character then
        local hum = player.Character:FindFirstChild("Humanoid")
        if hum then hum.AutoRotate = true end
    end
end

local function forceCancel()
    clip()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        for _, obj in pairs(hrp:GetChildren()) do
            if obj:IsA("BodyVelocity") or obj:IsA("LinearVelocity") or obj:IsA("BodyAngularVelocity") or obj:IsA("AlignOrientation") then
                obj:Destroy()
            elseif obj:IsA("Attachment") and obj.Name == "LoopDashAtt" then
                obj:Destroy()
            end
        end
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
end

-- // HÀM XỬ LÝ COOLDOWN (VỚI THANH CHẠY)
local function startCooldown(duration)
    if not isCurrent() or isCooldown then return end
    isCooldown = true
    
    if MainFrame and CooldownBar and CooldownFill then
        CooldownBar.Visible = true
        CooldownFill.Size = UDim2.new(1, 0, 1, 0)
        local tween = TweenService:Create(CooldownFill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 1, 0)})
        tween:Play()
        
        task.delay(duration, function()
            isCooldown = false
            if CooldownBar and CooldownBar.Parent then
                CooldownBar.Visible = false
            end
        end)
    else
        task.wait(duration)
        isCooldown = false
    end
end

-- Hàm quét mục tiêu bằng Radius
local function getTorsoTarget()
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
    
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char}
    
    local parts = workspace:GetPartBoundsInRadius(char.HumanoidRootPart.Position, Config.DashRange, params)
    local target = nil
    local dist = Config.DashRange
    
    for _, part in pairs(parts) do
        local model = part:FindFirstAncestorOfClass("Model")
        if model and model:FindFirstChild("Humanoid") and model ~= char then
            local torso = model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("HumanoidRootPart")
            if torso then
                local d = (char.HumanoidRootPart.Position - torso.Position).Magnitude
                if d < dist then 
                    dist = d 
                    target = torso 
                end
            end
        end
    end
    return target
end

--// HÀM XOAY (CHẠY SONG SONG VỚI DASH)
local function startRotation(torso)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if not root or not hum or not torso or not torso.Parent then 
        isExecuting = false 
        return 
    end

    local startT = os.clock()
    local flipped = false
    local forwardDir = (torso.Position - root.Position).Unit
    local sideVec = Vector3.new(-forwardDir.Z, 0, forwardDir.X)
    local bav = nil
    local ao = nil
    local att0 = nil
    
    hum.AutoRotate = false

    if Config.LoopDashMode == "BodyGyro" then
        bav = root:FindFirstChild("LoopDashBAV") or Instance.new("BodyAngularVelocity")
        bav.Name = "LoopDashBAV"
        bav.MaxTorque = Vector3.new(0, 1000000, 0)
        bav.P = 15000
        bav.AngularVelocity = Vector3.zero
        bav.Parent = root
    elseif Config.LoopDashMode == "AlignOrientation" then
        ao = root:FindFirstChild("LoopDashAO") or Instance.new("AlignOrientation")
        ao.Name = "LoopDashAO"
        ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
        ao.MaxTorque = 1000000
        ao.Responsiveness = 100
        
        att0 = root:FindFirstChild("LoopDashAtt") or Instance.new("Attachment", root)
        att0.Name = "LoopDashAtt"
        ao.Attachment0 = att0
        ao.Parent = root
    end
    
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not isCurrent() or not torso or not torso.Parent or not root or not root.Parent then 
            if bav then bav:Destroy() end 
            if ao then ao:Destroy() end
            if att0 then att0:Destroy() end
            clip()
            isExecuting = false
            if conn then conn:Disconnect() end
            return 
        end
        
        hum.AutoRotate = false
        
        local elapsed = os.clock() - startT
        local torsoPos, rootPos = torso.Position, root.Position
        
        if Config.LoopDashMode == "BodyGyro" then
            local calcElapsed = elapsed
            local angle = (calcElapsed / 0.45) * (math.pi / (Config.DashDuration / 1))
            local radius = Config.LoopDashAccuracy * (1 - math.clamp(calcElapsed / (Config.DashDuration * 0.3), 0, 1))
            local targetLookPos = torsoPos + (sideVec * math.cos(angle) + forwardDir * math.sin(angle)) * radius
            local lookAtCF = CFrame.lookAt(rootPos, Vector3.new(targetLookPos.X, rootPos.Y, targetLookPos.Z))
            local relativeCF = root.CFrame:Inverse() * lookAtCF
            local _, y, _ = relativeCF:ToEulerAnglesXYZ()
            if bav and bav.Parent then 
                bav.AngularVelocity = Vector3.new(0, y * 30, 0) 
            end
        elseif Config.LoopDashMode == "AlignOrientation" then
            local calcElapsed = elapsed
            local angle = (calcElapsed / 0.45) * (math.pi / (Config.DashDuration / 1))
            local radius = Config.LoopDashAccuracy * (1 - math.clamp(calcElapsed / (Config.DashDuration * 0.3), 0, 1))
            local targetLookPos = torsoPos + (sideVec * math.cos(angle) + forwardDir * math.sin(angle)) * radius
            if ao and ao.Parent then
                ao.CFrame = CFrame.lookAt(rootPos, Vector3.new(targetLookPos.X, rootPos.Y, targetLookPos.Z))
            end
        else
            -- Flip Mode
            if elapsed >= Config.LoopDashAccuracy and not flipped then
                root.CFrame = root.CFrame * CFrame.Angles(0, math.pi, 0)
                flipped = true
            end
        end

        local distXZ = (Vector2.new(rootPos.X, rootPos.Z) - Vector2.new(torsoPos.X, torsoPos.Z)).Magnitude
        if (Config.CancelEnabled and elapsed > Config.LoopDashCancelDelay and distXZ < 2.2) or elapsed > Config.DashDuration or not Config.Enabled then
            if bav then bav:Destroy() end
            if ao then ao:Destroy() end
            if att0 then att0:Destroy() end
            forceCancel()
            isExecuting = false
            conn:Disconnect()
            return
        end
    end)
end

--// CAM SMOOTH SYSTEM
local camSmoothConn
local FIXED_CAM_SMOOTH_SPEED = 0.04
local _wasAttachedByScript = false
local _prevCamType, _prevCamSubject, _prevCamCFrame

local function updateCamSmooth(enabled)
    if camSmoothConn then
        camSmoothConn:Disconnect()
        camSmoothConn = nil
    end
    if not enabled then return end

    camSmoothConn = RunService.RenderStepped:Connect(function(dt)
        if not isCurrent() then return end

        if not isExecuting then
            if _wasAttachedByScript then
                local cam = workspace and workspace.CurrentCamera
                if cam then
                    pcall(function()
                        cam.CameraType = _prevCamType or Enum.CameraType.Custom
                        cam.CameraSubject = _prevCamSubject or (player.Character and player.Character:FindFirstChildOfClass("Humanoid"))
                        if _prevCamCFrame then cam.CFrame = _prevCamCFrame end
                    end)
                end
                _wasAttachedByScript = false
            end
            return
        end

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local cam = workspace and workspace.CurrentCamera
        if not root or not cam then return end

        local rotatorObj = root:FindFirstChild("LoopDashBAV") or root:FindFirstChild("LoopDashAO")

        if rotatorObj then
            if not _wasAttachedByScript then
                _prevCamType = cam.CameraType
                _prevCamSubject = cam.CameraSubject
                _prevCamCFrame = cam.CFrame
                _wasAttachedByScript = true
            end
            pcall(function()
                cam.CameraType = Enum.CameraType.Attach
                cam.CameraSubject = root
            end)
        else
            if _wasAttachedByScript then
                pcall(function()
                    cam.CameraType = _prevCamType or Enum.CameraType.Custom
                    cam.CameraSubject = _prevCamSubject or (player.Character and player.Character:FindFirstChildOfClass("Humanoid"))
                    if _prevCamCFrame then cam.CFrame = _prevCamCFrame end
                end)
                _wasAttachedByScript = false
            end
            local targetPos = Vector3.new(root.Position.X, cam.CFrame.Position.Y, root.Position.Z)
            local targetCF = CFrame.lookAt(cam.CFrame.Position, targetPos)
            local alpha = 1 - math.exp(-FIXED_CAM_SMOOTH_SPEED * (dt or (1/60)) * 60)
            cam.CFrame = cam.CFrame:Lerp(targetCF, alpha)
        end
    end)
end

--// HÀM THỰC THI LOOP DASH
local function executeLoopDash()
    if not isCurrent() or isExecuting or isCooldown then return end
    if not Config.Enabled then return end
    
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local torso = getTorsoTarget()
    if not torso then clip() return end
    
    isExecuting = true
    
    local preDashConn
    preDashConn = RunService.Heartbeat:Connect(function()
        if not isExecuting or not torso or not torso.Parent or not root or not root.Parent then 
            if preDashConn then preDashConn:Disconnect() end
            return 
        end
        local hum = char:FindFirstChild("Humanoid")
        if hum then hum.AutoRotate = false end
        root.CFrame = CFrame.lookAt(root.Position, Vector3.new(torso.Position.X, root.Position.Y, torso.Position.Z))
    end)

    task.spawn(function()
        if Config.JumpMode == "Normal" then
            local totalDelay = Config.LoopDashDelay
            task.wait(math.max(0, totalDelay - 0.03))
            if not isCurrent() or not torso.Parent or not root.Parent then 
                if preDashConn then preDashConn:Disconnect() end
                isExecuting = false 
                return 
            end
            
            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, Config.LoopDashJump, root.AssemblyLinearVelocity.Z)
            isNoclipping = true
            
            task.wait(0.03)
            if not isCurrent() or not torso.Parent or not root.Parent then 
                if preDashConn then preDashConn:Disconnect() end
                isExecuting = false 
                return 
            end
            
            if preDashConn then preDashConn:Disconnect() end
            fireDash()
            startRotation(torso)
        else
            -- Custom Jump
            task.spawn(function()
                task.wait(Config.JumpDelay)
                if isCurrent() and Config.Enabled and root.Parent then
                    root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, Config.LoopDashJump, root.AssemblyLinearVelocity.Z)
                end
            end)

            task.wait(Config.LoopDashDelay)
            if not isCurrent() or not torso.Parent or not root.Parent then 
                if preDashConn then preDashConn:Disconnect() end
                isExecuting = false 
                return 
            end
            
            if preDashConn then preDashConn:Disconnect() end
            isNoclipping = true
            fireDash()
            startRotation(torso)
        end
    end)
end

--// BACKGROUND GRADIENT ANIMATION
local bgGradient
local GradientRunning = false

local function startGradient()
    if GradientRunning or not bgGradient then return end
    GradientRunning = true
    
    task.spawn(function()
        while GradientRunning and bgGradient and bgGradient.Parent do
            local tween = TweenService:Create(
                bgGradient,
                TweenInfo.new(6, Enum.EasingStyle.Linear),
                {Rotation = 360}
            )
            tween:Play()
            tween.Completed:Wait()
            if bgGradient then bgGradient.Rotation = 0 end
        end
    end)
end

local function stopGradient()
    GradientRunning = false
    if bgGradient then bgGradient.Rotation = 0 end
end

--// GUI SYSTEM
local function createUI()
    local existingGui = game.CoreGui:FindFirstChild("PefectLoopDash")
    if existingGui then existingGui:Destroy() end

    local GuiRoot = Instance.new("ScreenGui", game.CoreGui)
    GuiRoot.Name = "PefectLoopDash"
    GuiRoot.ResetOnSpawn = false
    GuiRoot.DisplayOrder = 999
    GuiRoot.IgnoreGuiInset = true

    -- Main Button
    MainFrame = Instance.new("TextButton", GuiRoot)
    MainFrame.Name = "MainButton"
    MainFrame.Size = UDim2.new(0, 200, 0, 45)
    MainFrame.Position = UDim2.new(0.02, 0, 0.5, -22)
    MainFrame.Text = "<i><font face='Arcade'><font color='#a855f7'>P</font><font color='#b066ff'>e</font><font color='#b878ff'>f</font><font color='#c089ff'>e</font><font color='#c89bff'>c</font><font color='#d0acff'>t</font> <font color='#a855f7'>L</font><font color='#b066ff'>o</font><font color='#b878ff'>o</font><font color='#c089ff'>p</font><font color='#c89bff'>D</font><font color='#d0acff'>a</font><font color='#d8bdff'>s</font><font color='#e0ceff'>h</font></font></i>"
    MainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    MainFrame.TextColor3 = Color3.new(1, 1, 1)
    MainFrame.TextScaled = true
    MainFrame.BorderSizePixel = 0
    MainFrame.RichText = true
    MainFrame.AutoButtonColor = false
    
    local corner = Instance.new("UICorner", MainFrame)
    corner.CornerRadius = UDim.new(0, 10)
    
    -- Gradient
    bgGradient = Instance.new("UIGradient", MainFrame)
    bgGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 40, 40)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 90, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 40, 40))
    }
    bgGradient.Rotation = 0
    
    -- Cooldown bar
    CooldownBar = Instance.new("Frame", MainFrame)
    CooldownBar.Name = "CooldownBar"
    CooldownBar.Size = UDim2.new(1, 0, 0, 3)
    CooldownBar.Position = UDim2.new(0, 0, 0, 42)
    CooldownBar.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
    CooldownBar.BackgroundTransparency = 0.5
    CooldownBar.BorderSizePixel = 0
    CooldownBar.Visible = false

    CooldownFill = Instance.new("Frame", CooldownBar)
    CooldownFill.Size = UDim2.new(1, 0, 1, 0)
    CooldownFill.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
    CooldownFill.BorderSizePixel = 0
    
    -- Settings Panel
    SettingsFrame = Instance.new("Frame", GuiRoot)
    SettingsFrame.Name = "SettingsPanel"
    SettingsFrame.Size = UDim2.new(0, 280, 0, 0)
    SettingsFrame.Position = UDim2.new(0.02, 0, 0.5, 50)
    SettingsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    SettingsFrame.BackgroundTransparency = 0.05
    SettingsFrame.ClipsDescendants = true
    SettingsFrame.Visible = false
    
    local settingsCorner = Instance.new("UICorner", SettingsFrame)
    settingsCorner.CornerRadius = UDim.new(0, 12)
    
    local settingsStroke = Instance.new("UIStroke", SettingsFrame)
    settingsStroke.Color = Color3.fromRGB(168, 85, 247)
    settingsStroke.Thickness = 1
    settingsStroke.Transparency = 0.6
    
    -- Title bar
    local SettingsHeader = Instance.new("Frame", SettingsFrame)
    SettingsHeader.Size = UDim2.new(1, 0, 0, 35)
    SettingsHeader.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    SettingsHeader.BackgroundTransparency = 0.3
    
    local headerCorner = Instance.new("UICorner", SettingsHeader)
    headerCorner.CornerRadius = UDim.new(0, 12)
    
    local SettingsTitle = Instance.new("TextLabel", SettingsHeader)
    SettingsTitle.Size = UDim2.new(1, -40, 1, 0)
    SettingsTitle.Position = UDim2.new(0, 15, 0, 0)
    SettingsTitle.Text = "⚙ SETTINGS"
    SettingsTitle.TextColor3 = Color3.fromRGB(168, 85, 247)
    SettingsTitle.Font = Enum.Font.GothamBold
    SettingsTitle.TextSize = 14
    SettingsTitle.TextXAlignment = Enum.TextXAlignment.Left
    SettingsTitle.BackgroundTransparency = 1
    
    local CloseBtn = Instance.new("TextButton", SettingsHeader)
    CloseBtn.Size = UDim2.new(0, 25, 0, 25)
    CloseBtn.Position = UDim2.new(1, -30, 0.5, -12)
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 14
    CloseBtn.BackgroundTransparency = 1
    CloseBtn.BorderSizePixel = 0
    
    -- Scrolling Frame
    local ScrollingFrame = Instance.new("ScrollingFrame", SettingsFrame)
    ScrollingFrame.Size = UDim2.new(1, -10, 1, -45)
    ScrollingFrame.Position = UDim2.new(0, 5, 0, 40)
    ScrollingFrame.BackgroundTransparency = 1
    ScrollingFrame.ScrollBarThickness = 4
    ScrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(168, 85, 247)
    ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    ScrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    
    local UIListLayout = Instance.new("UIListLayout", ScrollingFrame)
    UIListLayout.Padding = UDim.new(0, 6)
    UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
    -- Hàm tạo toggle
    local function CreateToggle(name, configKey)
        local frame = Instance.new("Frame", ScrollingFrame)
        frame.Size = UDim2.new(0.95, 0, 0, 35)
        frame.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
        frame.BackgroundTransparency = 0.3
        
        local toggleCorner = Instance.new("UICorner", frame)
        toggleCorner.CornerRadius = UDim.new(0, 8)
        
        local label = Instance.new("TextLabel", frame)
        label.Text = name
        label.Size = UDim2.new(0.65, 0, 1, 0)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.TextColor3 = Color3.fromRGB(220, 220, 220)
        label.Font = Enum.Font.Gotham
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.BackgroundTransparency = 1
        
        local toggleBtn = Instance.new("TextButton", frame)
        toggleBtn.Size = UDim2.new(0, 40, 0, 20)
        toggleBtn.Position = UDim2.new(1, -50, 0.5, -10)
        toggleBtn.BackgroundColor3 = Config[configKey] and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(80, 80, 90)
        toggleBtn.Text = ""
        toggleBtn.BorderSizePixel = 0
        
        local toggleCornerBtn = Instance.new("UICorner", toggleBtn)
        toggleCornerBtn.CornerRadius = UDim.new(0, 10)
        
        local toggleDot = Instance.new("Frame", toggleBtn)
        toggleDot.Size = UDim2.new(0, 16, 0, 16)
        toggleDot.Position = Config[configKey] and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        toggleDot.BackgroundColor3 = Color3.new(1, 1, 1)
        
        local dotCorner = Instance.new("UICorner", toggleDot)
        dotCorner.CornerRadius = UDim.new(0, 8)
        
        toggleBtn.MouseButton1Click:Connect(function()
            Config[configKey] = not Config[configKey]
            local enabled = Config[configKey]
            TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = enabled and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(80, 80, 90)}):Play()
            TweenService:Create(toggleDot, TweenInfo.new(0.2), {Position = enabled and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}):Play()
            
            if configKey == "CamSmooth" then
                updateCamSmooth(enabled)
            elseif configKey == "Enabled" then
                if enabled then startGradient() else stopGradient() end
            end
        end)
        
        return frame
    end
    
    -- Hàm tạo input
    local function CreateInput(name, configKey, isNumber)
        local frame = Instance.new("Frame", ScrollingFrame)
        frame.Size = UDim2.new(0.95, 0, 0, 35)
        frame.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
        frame.BackgroundTransparency = 0.3
        
        local inputCorner = Instance.new("UICorner", frame)
        inputCorner.CornerRadius = UDim.new(0, 8)
        
        local label = Instance.new("TextLabel", frame)
        label.Text = name
        label.Size = UDim2.new(0.6, 0, 1, 0)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.TextColor3 = Color3.fromRGB(220, 220, 220)
        label.Font = Enum.Font.Gotham
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.BackgroundTransparency = 1
        
        local box = Instance.new("TextBox", frame)
        box.Size = UDim2.new(0, 60, 0, 24)
        box.Position = UDim2.new(1, -70, 0.5, -12)
        box.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        box.Text = tostring(Config[configKey])
        box.TextColor3 = Color3.fromRGB(168, 85, 247)
        box.Font = Enum.Font.Gotham
        box.TextSize = 12
        box.BorderSizePixel = 0
        
        local boxCorner = Instance.new("UICorner", box)
        boxCorner.CornerRadius = UDim.new(0, 6)
        
        box.FocusLost:Connect(function()
            if isNumber then
                local val = tonumber(box.Text)
                if val then Config[configKey] = val end
                box.Text = tostring(Config[configKey])
            else
                Config[configKey] = box.Text
            end
        end)
        
        return frame
    end
    
    -- Hàm tạo button
    local function CreateButton(name, callback)
        local btn = Instance.new("TextButton", ScrollingFrame)
        btn.Size = UDim2.new(0.95, 0, 0, 35)
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        btn.Text = name
        btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.BorderSizePixel = 0
        
        local btnCorner = Instance.new("UICorner", btn)
        btnCorner.CornerRadius = UDim.new(0, 8)
        
        btn.MouseButton1Click:Connect(function() callback(btn) end)
        return btn
    end
    
    -- TẠO CÁC SETTINGS (ĐÃ BỎ TOUCH MODE, FLICK, SLOT)
    CreateToggle("LoopDash Status", "Enabled")
    CreateToggle("Cooldown Hide", "CooldownActive")
    CreateToggle("NoClip better", "NoClipEnabled")
    CreateToggle("Cam Smooth", "CamSmooth")
    
    local ModeBtn = CreateButton("Mode: " .. Config.LoopDashMode, function(btn)
        if Config.LoopDashMode == "BodyGyro" then
            Config.LoopDashMode = "Flip"
            _G.LastV1Acc = Config.LoopDashAccuracy
            Config.LoopDashAccuracy = 0.25
        elseif Config.LoopDashMode == "Flip" then
            Config.LoopDashMode = "AlignOrientation"
            Config.LoopDashAccuracy = _G.LastV1Acc or 15
        else
            Config.LoopDashMode = "BodyGyro"
            Config.LoopDashAccuracy = _G.LastV1Acc or 15
        end
        btn.Text = "Mode: " .. Config.LoopDashMode
    end)
    
    local JumpModeBtn = CreateButton("Jump Mode: " .. Config.JumpMode, function(btn)
        Config.JumpMode = (Config.JumpMode == "Normal") and "Custom" or "Normal"
        btn.Text = "Jump Mode: " .. Config.JumpMode
    end)
    
    CreateInput("Dash Delay", "LoopDashDelay", true)
    CreateInput("Jump Delay", "JumpDelay", true)
    CreateInput("Jump Power", "LoopDashJump", true)
    CreateInput("Dash Duration", "DashDuration", true)
    CreateInput("Accuracy/Flip", "LoopDashAccuracy", true)
    CreateInput("Dash Range", "DashRange", true)
    CreateInput("Cancel Delay", "LoopDashCancelDelay", true)
    CreateInput("Keybind", "Keybind", false)
    
    -- Discord Button
    local DiscordBtn = CreateButton("💬 Join Discord", function(btn)
        if setclipboard then
            setclipboard("https://discord.gg/nUaTCfeN")
            btn.Text = "✓ Copied!"
            task.delay(2, function() if btn.Parent then btn.Text = "💬 Join Discord" end end)
        end
    end)
    DiscordBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
    
    -- DRAG functionality
    local dragging = false
    local dragStart
    local startPos
    
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    MainFrame.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
            if SettingsFrame and SettingsFrame.Visible then
                SettingsFrame.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + 50 + delta.Y
                )
            end
        end
    end)
    
    -- Toggle settings
    MainFrame.MouseButton1Click:Connect(function()
        if not SettingsFrame then return end
        isSettingsOpen = not isSettingsOpen
        
        if isSettingsOpen then
            SettingsFrame.Visible = true
            local targetHeight = 520
            TweenService:Create(SettingsFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0, 280, 0, targetHeight)}):Play()
            SettingsFrame.Position = UDim2.new(MainFrame.Position.X.Scale, MainFrame.Position.X.Offset, MainFrame.Position.Y.Scale, MainFrame.Position.Y.Offset + 55)
        else
            TweenService:Create(SettingsFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0, 280, 0, 0)}):Play()
            task.wait(0.3)
            SettingsFrame.Visible = false
        end
    end)
    
    CloseBtn.MouseButton1Click:Connect(function()
        isSettingsOpen = false
        TweenService:Create(SettingsFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0, 280, 0, 0)}):Play()
        task.wait(0.3)
        SettingsFrame.Visible = false
    end)
    
    -- Keybind
    UIS.InputBegan:Connect(function(input, gpe)
        if not isCurrent() then return end
        if gpe then return end
        if input.KeyCode == Enum.KeyCode[Config.Keybind:upper()] then
            executeLoopDash()
        end
    end)
    
    -- Animation open
    MainFrame.Position = UDim2.new(0.02, -300, 0.5, -22)
    TweenService:Create(MainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.02, 0, 0.5, -22)}):Play()
end

createUI()
updateCamSmooth(Config.CamSmooth)

--// CORE LOGIC LOOP DASH
local function setup(char)
    if not isCurrent() then return end
    local hum = char:WaitForChild("Humanoid")
    hum.AnimationPlayed:Connect(function(track)
        if not isCurrent() then return end
        
        local animId = getId(track.Animation.AnimationId)
        if Config.CooldownActive and Config.CooldownAnims[animId] then
            startCooldown(5)
        end
        
        if not Config.Enabled then return end
        if track.Animation.AnimationId == Config.LoopDashAnim then
            executeLoopDash()
        end
    end)
end

--// NO CLIP SMART
RunService.Stepped:Connect(function()
    if not isCurrent() or not Config.NoClipEnabled or not isNoclipping then return end
    
    local char = player.Character
    if char then
        for _, part in pairs(char:GetChildren()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

if player.Character then setup(player.Character) end
player.CharacterAdded:Connect(setup)
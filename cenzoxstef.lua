-- ═══════════════════════════════════════════════════════
--  CENZO X STEF | Rivals Script v1.0
--  Executors : Delta · KRNL · Arceus X
--  Game      : Rivals (Roblox FPS)
-- ═══════════════════════════════════════════════════════

-- ── Services ──────────────────────────────────────────
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService   = game:GetService("TweenService")
local Camera         = workspace.CurrentCamera
local lp             = Players.LocalPlayer
local mouse          = lp:GetMouse()

-- ── State ─────────────────────────────────────────────
local State = {
    -- COMB / Silent Aim
    SA = {
        enabled     = false,
        useFOV      = true,
        fov         = 150,
        maxDist     = 500,
        infiniteDist = false,
        targetPart  = "Head",
        teamCheck   = true,
    },
    -- COMB / Aimbot
    AB = {
        enabled     = false,
        useFOV      = true,
        fov         = 150,
        smoothness  = 0.3,
        targetPart  = "Head",
        teamCheck   = true,
        holdKey     = Enum.UserInputType.MouseButton2,
    },
    -- COMB / Triggerbot
    TB = {
        enabled     = false,
        delay       = 0.05,
        teamCheck   = true,
    },
    -- COMB / Backtrack
    BT = {
        enabled     = false,
        ticks       = 10,
    },
    -- COMB / Hitbox Extender
    HBX = {
        enabled     = false,
        size        = 5,
    },
    -- FOV Circle
    FC = {
        draw        = true,
        outline     = true,
        filled      = false,
        smoothness  = 48,
        radius      = 150,
        color       = Color3.fromRGB(255, 255, 255),
        outlineColor = Color3.fromRGB(0, 0, 0),
        centerMode  = "Center on Screen",
        lerpSpeed   = 0.5,
    },
    -- RAGE
    RAGE = {
        rapidFire   = false,
        noRecoil    = false,
        noSpread    = false,
        infiniteAmmo = false,
        autoReload  = false,
    },
    -- PLAY
    PLAY = {
        fly         = false,
        flySpeed    = 60,
        noclip      = false,
        speed       = false,
        speedMult   = 1.5,
        infiniteJump = false,
        antiAfk     = false,
    },
    -- VISU
    VISU = {
        esp         = false,
        espBox      = true,
        espName     = true,
        espHealth   = true,
        espDist     = true,
        espTracers  = false,
        chams       = false,
        crosshair   = false,
    },
    -- WORL
    WORL = {
        gravity     = false,
        gravityVal  = 196.2,
        fullbright  = false,
        noFog       = false,
    },
    -- MISC
    MISC = {
        antiAfk     = false,
        killAura    = false,
        killAuraRange = 20,
        autoRejoin  = false,
    },
}

-- ── FOV Circle Drawing ─────────────────────────────────
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness  = 1.5
fovCircle.NumSides   = State.FC.smoothness
fovCircle.Radius     = State.FC.radius
fovCircle.Filled     = State.FC.filled
fovCircle.Color      = State.FC.color
fovCircle.Visible    = State.FC.draw
fovCircle.Position   = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

local fovOutline = Drawing.new("Circle")
fovOutline.Thickness = 3
fovOutline.NumSides  = State.FC.smoothness
fovOutline.Radius    = State.FC.radius
fovOutline.Filled    = false
fovOutline.Color     = State.FC.outlineColor
fovOutline.Visible   = State.FC.draw and State.FC.outline
fovOutline.Position  = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

-- ── Utility ───────────────────────────────────────────
local conns = {}

local function disc(key)
    if conns[key] then conns[key]:Disconnect(); conns[key] = nil end
end

local function getChar() return lp.Character end
local function getRoot()
    local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar(); return c and c:FindFirstChildOfClass("Humanoid")
end

local function isTeammate(plr)
    if not State.SA.teamCheck then return false end
    return lp.Team ~= nil and plr.Team == lp.Team
end

local function getTarget(fovRadius, partName, useTeamCheck)
    local best, bestDist = nil, math.huge
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == lp then continue end
        if useTeamCheck and isTeammate(plr) then continue end
        local char = plr.Character
        if not char then continue end
        local part = char:FindFirstChild(partName) or char:FindFirstChild("HumanoidRootPart")
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not part or not hum or hum.Health <= 0 then continue end

        local dist3d = (part.Position - Camera.CFrame.Position).Magnitude
        local maxD   = State.SA.infiniteDist and math.huge or State.SA.maxDist
        if dist3d > maxD then continue end

        local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end

        local screenDist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if fovRadius and screenDist > fovRadius then continue end

        if screenDist < bestDist then
            bestDist = screenDist
            best     = plr
        end
    end
    return best
end

-- ── Backtrack Storage ─────────────────────────────────
local backtrackData = {}  -- [player] = {CFrame records}

-- ── ESP Objects ───────────────────────────────────────
local espObjects = {}

local function removeESP(plr)
    if espObjects[plr] then
        for _, d in pairs(espObjects[plr]) do
            if d.Remove then d:Remove() elseif d.Visible ~= nil then d.Visible = false end
        end
        espObjects[plr] = nil
    end
end

local function createESP(plr)
    if espObjects[plr] then return end
    local objs = {}
    
    local box = Drawing.new("Square")
    box.Visible     = false
    box.Thickness   = 1.5
    box.Color       = Color3.fromRGB(255, 80, 80)
    box.Filled      = false
    objs.box        = box

    local name = Drawing.new("Text")
    name.Visible    = false
    name.Size       = 14
    name.Color      = Color3.fromRGB(255, 255, 255)
    name.Center     = true
    name.Outline    = true
    name.Text       = plr.Name
    objs.name       = name

    local health = Drawing.new("Square")
    health.Visible  = false
    health.Thickness = 1.5
    health.Color    = Color3.fromRGB(80, 255, 80)
    health.Filled   = true
    objs.health     = health

    local dist = Drawing.new("Text")
    dist.Visible    = false
    dist.Size       = 12
    dist.Color      = Color3.fromRGB(200, 200, 200)
    dist.Center     = true
    dist.Outline    = true
    objs.dist       = dist

    local tracer = Drawing.new("Line")
    tracer.Visible  = false
    tracer.Thickness = 1
    tracer.Color    = Color3.fromRGB(255, 80, 80)
    objs.tracer     = tracer

    espObjects[plr] = objs
end

-- ── Fly ───────────────────────────────────────────────
local flyParts = {}

local function enableFly()
    local root = getRoot()
    local hum  = getHum()
    if not root or not hum then return end
    hum.PlatformStand = true

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Velocity = Vector3.zero
    bv.Parent   = root
    flyParts.bv = bv

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bg.D = 100
    bg.Parent = root
    flyParts.bg = bg

    conns["fly"] = RunService.Heartbeat:Connect(function()
        if not State.PLAY.fly then return end
        local cf  = Camera.CFrame
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
        bv.Velocity = dir.Magnitude > 0 and dir.Unit * State.PLAY.flySpeed or Vector3.zero
        bg.CFrame   = cf
    end)
end

local function disableFly()
    disc("fly")
    for _, v in pairs(flyParts) do pcall(function() v:Destroy() end) end
    flyParts = {}
    local hum = getHum()
    if hum then hum.PlatformStand = false end
end

-- ── Noclip ────────────────────────────────────────────
local function enableNoclip()
    conns["noclip"] = RunService.Stepped:Connect(function()
        local char = getChar()
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end)
end

local function disableNoclip()
    disc("noclip")
    local char = getChar()
    if char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
    end
end

-- ── Infinite Jump ─────────────────────────────────────
local function enableInfJump()
    conns["infjump"] = UserInputService.JumpRequest:Connect(function()
        local hum = getHum()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end

-- ── Anti-AFK ─────────────────────────────────────────
local VirtualUser = game:GetService("VirtualUser")
local function enableAntiAfk()
    conns["antiafk"] = lp.Idled:Connect(function()
        VirtualUser:Button2Down(Vector2.new(0,0), Camera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0,0), Camera.CFrame)
    end)
end

-- ── Hitbox Extender ───────────────────────────────────
local origSizes = {}

local function applyHBX()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == lp then continue end
        local char = plr.Character
        if not char then continue end
        local head = char:FindFirstChild("Head")
        if head then
            if not origSizes[plr] then origSizes[plr] = head.Size end
            head.Size = Vector3.new(State.HBX.size, State.HBX.size, State.HBX.size)
        end
    end
end

local function removeHBX()
    for plr, sz in pairs(origSizes) do
        local char = plr.Character
        if char then
            local head = char:FindFirstChild("Head")
            if head then head.Size = sz end
        end
    end
    origSizes = {}
end

-- ── Namecall Hook (Silent Aim + Triggerbot) ───────────
local hookActive = false
local origNC

local function installHook()
    if hookActive then return end
    hookActive = true
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    origNC = mt.__namecall
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        
        -- Silent Aim: intercept FireServer on shoot remotes
        if State.SA.enabled and method == "FireServer" then
            local args = {...}
            local target = getTarget(
                State.SA.useFOV and State.SA.fov or nil,
                State.SA.targetPart,
                State.SA.teamCheck
            )
            if target then
                local char = target.Character
                local part = char and char:FindFirstChild(State.SA.targetPart)
                    or (char and char:FindFirstChild("HumanoidRootPart"))
                if part then
                    local aimDir = (part.Position - Camera.CFrame.Position).Unit
                    local aimCF  = CFrame.new(Camera.CFrame.Position, part.Position)
                    for i, v in ipairs(args) do
                        if typeof(v) == "Vector3" and v.Magnitude <= 1.001 then
                            args[i] = aimDir; break
                        elseif typeof(v) == "CFrame" then
                            args[i] = aimCF; break
                        end
                    end
                    return origNC(self, table.unpack(args))
                end
            end
        end
        
        return origNC(self, ...)
    end)
    setreadonly(mt, true)
end

-- ── RenderStepped Loop ────────────────────────────────
conns["render"] = RunService.RenderStepped:Connect(function()
    local vp = Camera.ViewportSize

    -- FOV Circle position
    local fcPos
    if State.FC.centerMode == "Center on Screen" then
        fcPos = Vector2.new(vp.X / 2, vp.Y / 2)
    else
        fcPos = Vector2.new(mouse.X, mouse.Y)
    end

    -- Lerp circle toward target position
    fovCircle.Position  = fovCircle.Position:Lerp(fcPos, State.FC.lerpSpeed)
    fovOutline.Position = fovCircle.Position

    fovCircle.Visible   = State.FC.draw
    fovCircle.Radius    = State.FC.radius
    fovCircle.Filled    = State.FC.filled
    fovCircle.NumSides  = State.FC.smoothness
    fovCircle.Color     = State.FC.color

    fovOutline.Visible  = State.FC.draw and State.FC.outline
    fovOutline.Radius   = State.FC.radius + 1
    fovOutline.NumSides = State.FC.smoothness
    fovOutline.Color    = State.FC.outlineColor

    -- Aimbot
    if State.AB.enabled and UserInputService:IsMouseButtonPressed(State.AB.holdKey) then
        local target = getTarget(
            State.AB.useFOV and State.AB.fov or nil,
            State.AB.targetPart,
            State.AB.teamCheck
        )
        if target then
            local char = target.Character
            local part = char and char:FindFirstChild(State.AB.targetPart)
                or (char and char:FindFirstChild("HumanoidRootPart"))
            if part then
                local goal = CFrame.new(Camera.CFrame.Position, part.Position)
                Camera.CFrame = Camera.CFrame:Lerp(goal, State.AB.smoothness)
            end
        end
    end

    -- Triggerbot
    if State.TB.enabled then
        local target = getTarget(30, State.AB.targetPart, State.TB.teamCheck)
        if target then
            task.delay(State.TB.delay, function()
                mouse1click()  -- executor API
            end)
        end
    end

    -- Hitbox Extender
    if State.HBX.enabled then applyHBX() end

    -- ESP update
    if State.VISU.esp then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == lp then continue end
            createESP(plr)
            local char = plr.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local head = char and char:FindFirstChild("Head")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            local objs = espObjects[plr]
            if not objs then continue end

            if not root or not hum or hum.Health <= 0 then
                for _, d in pairs(objs) do d.Visible = false end
                continue
            end

            local topSP, topVis = Camera:WorldToViewportPoint((head or root).Position + Vector3.new(0, 1.5, 0))
            local botSP         = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))

            if not topVis then
                for _, d in pairs(objs) do d.Visible = false end
                continue
            end

            local h    = math.abs(topSP.Y - botSP.Y)
            local w    = h * 0.6
            local dist = (root.Position - Camera.CFrame.Position).Magnitude

            -- Box
            if State.VISU.espBox and objs.box then
                objs.box.Visible = true
                objs.box.Size    = Vector2.new(w, h)
                objs.box.Position = Vector2.new(topSP.X - w/2, topSP.Y)
            else
                if objs.box then objs.box.Visible = false end
            end

            -- Name
            if State.VISU.espName and objs.name then
                objs.name.Visible   = true
                objs.name.Position  = Vector2.new(topSP.X, topSP.Y - 16)
                objs.name.Text      = plr.Name
            else
                if objs.name then objs.name.Visible = false end
            end

            -- Distance
            if State.VISU.espDist and objs.dist then
                objs.dist.Visible  = true
                objs.dist.Position = Vector2.new(topSP.X, botSP.Y + 2)
                objs.dist.Text     = string.format("[%d]", math.floor(dist))
            else
                if objs.dist then objs.dist.Visible = false end
            end

            -- Health bar
            if State.VISU.espHealth and objs.health then
                local hpRatio = hum.Health / hum.MaxHealth
                objs.health.Visible  = true
                objs.health.Size     = Vector2.new(3, h * hpRatio)
                objs.health.Position = Vector2.new(topSP.X - w/2 - 5, topSP.Y + h * (1 - hpRatio))
                objs.health.Color    = Color3.fromRGB(math.floor(255*(1-hpRatio)), math.floor(255*hpRatio), 0)
            else
                if objs.health then objs.health.Visible = false end
            end

            -- Tracers
            if State.VISU.espTracers and objs.tracer then
                objs.tracer.Visible  = true
                objs.tracer.From     = Vector2.new(vp.X/2, vp.Y)
                objs.tracer.To       = Vector2.new(topSP.X, topSP.Y + h)
            else
                if objs.tracer then objs.tracer.Visible = false end
            end
        end
    else
        for plr, objs in pairs(espObjects) do
            for _, d in pairs(objs) do d.Visible = false end
        end
    end
end)

-- ═══════════════════════════════════════════════════════
--  GUI CONSTRUCTION
-- ═══════════════════════════════════════════════════════

local function cleanGUI()
    local e = lp.PlayerGui:FindFirstChild("CenzoXStef")
    if e then e:Destroy() end
end
cleanGUI()

local sg = Instance.new("ScreenGui")
sg.Name           = "CenzoXStef"
sg.ResetOnSpawn   = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.DisplayOrder   = 999
sg.Parent         = lp.PlayerGui

-- Colors
local C = {
    bg       = Color3.fromRGB(10, 10, 20),
    bgDark   = Color3.fromRGB(6, 6, 14),
    bgMid    = Color3.fromRGB(16, 14, 32),
    tabBg    = Color3.fromRGB(14, 12, 28),
    tabAct   = Color3.fromRGB(28, 20, 56),
    accent   = Color3.fromRGB(100, 60, 220),
    accentBr = Color3.fromRGB(140, 90, 255),
    text     = Color3.fromRGB(200, 200, 220),
    textDim  = Color3.fromRGB(100, 100, 130),
    checkOn  = Color3.fromRGB(100, 60, 220),
    checkOff = Color3.fromRGB(30, 25, 55),
    border   = Color3.fromRGB(50, 35, 110),
    white    = Color3.fromRGB(255, 255, 255),
}

-- Main window
local win = Instance.new("Frame")
win.Size              = UDim2.new(0, 580, 0, 420)
win.Position          = UDim2.new(0.5, -290, 0.5, -210)
win.BackgroundColor3  = C.bg
win.BorderSizePixel   = 0
win.Active            = true
win.Draggable         = true
win.Parent            = sg

local winCorner = Instance.new("UICorner")
winCorner.CornerRadius = UDim.new(0, 8)
winCorner.Parent = win

local winStroke = Instance.new("UIStroke")
winStroke.Color    = C.border
winStroke.Thickness = 1
winStroke.Parent   = win

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size            = UDim2.new(1, 0, 0, 32)
titleBar.BackgroundColor3 = C.bgDark
titleBar.BorderSizePixel = 0
titleBar.Parent          = win

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleBar

-- Bottom cover for title (so bottom corners aren't rounded)
local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1,0,0,8)
titleFix.Position = UDim2.new(0,0,1,-8)
titleFix.BackgroundColor3 = C.bgDark
titleFix.BorderSizePixel = 0
titleFix.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -10, 1, 0)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "✦ CENZO X STEF"
titleLabel.TextColor3 = C.accentBr
titl

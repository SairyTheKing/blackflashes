if _G.boomshaka then
    warn("Script already running!")
    return
end
_G.boomshaka = true

local ScriptEnabled = true

local UserInputService    = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local LocalPlayer         = Players.LocalPlayer
local Camera              = workspace.CurrentCamera

local AnimationTriggers = {
    ["rbxassetid://100962226150441"] = 0.19,
    ["rbxassetid://95852624447551"]  = 0.19,
    ["rbxassetid://74145636023952"]  = 0.19,
    ["rbxassetid://72475960800126"]  = 0.20,
}

local StraightAnimations = {
    ["rbxassetid://123171106092050"] = true,
}

local Settings = {
    Duration      = 0.25,
    Radius        = 3,
    Range         = 25,
    CurveStrength = 14,
    CamOffset     = 4,
}

local GhostColor = Color3.fromRGB(255, 80, 80)

local pingVisualizerEnabled = false
local ghostModel            = nil
local positionHistory       = {}
local MAX_HISTORY           = 300

local function setGhostColor(color)
    GhostColor = color
    if ghostModel then
        for _, part in pairs(ghostModel:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("MeshPart") then
                part.Color = color
            end
        end
    end
end

local function createGhost(character)
    if ghostModel then ghostModel:Destroy() ghostModel = nil end
    if not character then return end
    ghostModel = Instance.new("Model")
    ghostModel.Name = "PingGhost"
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") or part:IsA("MeshPart") then
            local clone = part:Clone()
            for _, child in pairs(clone:GetChildren()) do
                if not child:IsA("SpecialMesh") and not child:IsA("Decal") then child:Destroy() end
            end
            clone.Anchored     = true
            clone.CanCollide   = false
            clone.CastShadow   = false
            clone.Transparency = 0.6
            clone.Color        = GhostColor
            clone.Material     = Enum.Material.Neon
            clone.Parent       = ghostModel
        end
    end
    ghostModel.Parent = workspace
end

local function destroyGhost()
    if ghostModel then ghostModel:Destroy() ghostModel = nil end
    positionHistory = {}
end

local function recordSnapshot(character)
    if not character then return end
    local snapshot = { time = tick(), parts = {} }
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") or part:IsA("MeshPart") then
            snapshot.parts[part.Name] = part.CFrame
        end
    end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then snapshot.parts["HumanoidRootPart"] = hrp.CFrame end
    table.insert(positionHistory, snapshot)
    while #positionHistory > MAX_HISTORY do table.remove(positionHistory, 1) end
end

local function getDelayedSnapshot()
    local targetTime = tick() - LocalPlayer:GetNetworkPing()
    for i = #positionHistory, 1, -1 do
        if positionHistory[i].time <= targetTime then return positionHistory[i] end
    end
    return positionHistory[1]
end

local function applySnapshotToGhost(snapshot)
    if not ghostModel or not snapshot then return end
    for _, part in pairs(ghostModel:GetDescendants()) do
        if (part:IsA("BasePart") or part:IsA("MeshPart")) and snapshot.parts[part.Name] then
            part.CFrame = snapshot.parts[part.Name]
        end
    end
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "BoomshakaPC"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = LocalPlayer.PlayerGui

local BTN_SIZE          = 62
local mobileBtnLocked   = false
local mobileBtnDragging = false
local mobileBtnDragOff  = Vector2.new(0, 0)
local dashBtn = Instance.new("TextButton")
dashBtn.Name                   = "DashButton"
dashBtn.Size                   = UDim2.new(0, BTN_SIZE, 0, BTN_SIZE)
dashBtn.Position               = UDim2.new(1, -(BTN_SIZE + 20), 1, -(BTN_SIZE * 3 + 20))
dashBtn.BackgroundColor3       = Color3.fromRGB(28, 28, 28)
dashBtn.BackgroundTransparency = 0.25
dashBtn.Text                   = ""
dashBtn.BorderSizePixel        = 0
dashBtn.Visible                = true
dashBtn.ZIndex                 = 10
dashBtn.ClipsDescendants       = false
dashBtn.Parent                 = screenGui
Instance.new("UICorner", dashBtn).CornerRadius = UDim.new(1, 0)

local dashStroke = Instance.new("UIStroke", dashBtn)
dashStroke.Color     = Color3.fromRGB(90, 90, 90)
dashStroke.Thickness = 2

local dashIcon = Instance.new("TextLabel")
dashIcon.Size                   = UDim2.new(0, 36, 0, 36)
dashIcon.Position               = UDim2.new(0.5, -18, 0.5, -22)
dashIcon.BackgroundTransparency = 1
dashIcon.Text                   = "✦"
dashIcon.TextColor3             = Color3.fromRGB(220, 220, 220)
dashIcon.TextSize               = 22
dashIcon.Font                   = Enum.Font.GothamBold
dashIcon.TextXAlignment         = Enum.TextXAlignment.Center
dashIcon.TextYAlignment         = Enum.TextYAlignment.Center
dashIcon.ZIndex                 = 11
dashIcon.Parent                 = dashBtn

local dashLabel = Instance.new("TextLabel")
dashLabel.Size                   = UDim2.new(1, 0, 0, 13)
dashLabel.Position               = UDim2.new(0, 0, 1, -16)
dashLabel.BackgroundTransparency = 1
dashLabel.Text                   = "DASH"
dashLabel.TextColor3             = Color3.fromRGB(150, 150, 150)
dashLabel.TextSize               = 9
dashLabel.Font                   = Enum.Font.Gotham
dashLabel.TextXAlignment         = Enum.TextXAlignment.Center
dashLabel.ZIndex                 = 11
dashLabel.Parent                 = dashBtn

local lockDot = Instance.new("Frame")
lockDot.Size             = UDim2.new(0, 10, 0, 10)
lockDot.Position         = UDim2.new(1, -3, 0, -3)
lockDot.BackgroundColor3 = Color3.fromRGB(65, 65, 65)
lockDot.BorderSizePixel  = 0
lockDot.ZIndex           = 12
lockDot.Parent           = dashBtn
Instance.new("UICorner", lockDot).CornerRadius = UDim.new(1, 0)
local lockDotStroke = Instance.new("UIStroke", lockDot)
lockDotStroke.Color     = Color3.fromRGB(18, 18, 18)
lockDotStroke.Thickness = 1

local function updateLockVisual()
    if mobileBtnLocked then
        lockDot.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
        dashStroke.Color         = Color3.fromRGB(255, 200, 50)
    else
        lockDot.BackgroundColor3 = Color3.fromRGB(65, 65, 65)
        dashStroke.Color         = Color3.fromRGB(90, 90, 90)
    end
end

dashBtn.MouseButton1Down:Connect(function()
    if not mobileBtnLocked then
        mobileBtnDragging = true
        local abs  = dashBtn.AbsolutePosition
        local mpos = UserInputService:GetMouseLocation()
        mobileBtnDragOff = Vector2.new(mpos.X - abs.X, mpos.Y - abs.Y)
    end
end)

dashBtn.MouseButton1Up:Connect(function()
    mobileBtnDragging = false
end)

UserInputService.InputChanged:Connect(function(input)
    if not mobileBtnDragging or mobileBtnLocked then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
        local pos = input.Position
        local ss  = screenGui.AbsoluteSize
        local nx  = math.clamp(pos.X - mobileBtnDragOff.X, 0, ss.X - BTN_SIZE)
        local ny  = math.clamp(pos.Y - mobileBtnDragOff.Y, 0, ss.Y - BTN_SIZE)
        dashBtn.Position = UDim2.new(0, nx, 0, ny)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        mobileBtnDragging = false
    end
end)

local hintLabel = Instance.new("TextLabel")
hintLabel.Size             = UDim2.new(0, 260, 0, 28)
hintLabel.Position         = UDim2.new(0, 20, 0, 20)
hintLabel.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
hintLabel.TextColor3       = Color3.fromRGB(130, 130, 130)
hintLabel.Text             = "RightShift to open settings"
hintLabel.TextSize         = 13
hintLabel.Font             = Enum.Font.Gotham
hintLabel.BorderSizePixel  = 0
hintLabel.Visible          = false
hintLabel.Parent           = screenGui
Instance.new("UICorner", hintLabel).CornerRadius = UDim.new(0, 8)
Instance.new("UIPadding", hintLabel).PaddingLeft = UDim.new(0, 10)

local tutorialPages = {
    {
        icon  = "⌨",
        title = "How to use",
        body  = "Press E or tap DASH to curve-glide to the nearest enemy's back.\n\nAlso triggers automatically on certain attack animations.",
    },
    {
        icon  = "⚙",
        title = "Settings",
        body  = "RightShift opens/closes this panel.\n\nGlide Speed — dash travel time\nLanding Distance — studs behind target\nDetection Range — enemy scan distance\nCurve Width — arc width\nCamera Height — cam offset during dash",
    },
    {
        icon  = "✦",
        title = "Dash Button",
        body  = "Drag it anywhere on screen.\nUse the Lock button in settings to stop it moving.",
    },
    {
        icon  = "◎",
        title = "Ping Visualizer",
        body  = "Shows a ghost of where the server thinks you are.\nHelps you time dashes on high ping.",
    },
}

local tutPage    = 1
local tutOverlay = Instance.new("Frame")
tutOverlay.Size                    = UDim2.new(1, 0, 1, 0)
tutOverlay.BackgroundColor3        = Color3.fromRGB(0, 0, 0)
tutOverlay.BackgroundTransparency  = 0.45
tutOverlay.BorderSizePixel         = 0
tutOverlay.ZIndex                  = 50
tutOverlay.Visible                 = false
tutOverlay.Parent                  = screenGui

local tutCard = Instance.new("Frame")
tutCard.Size             = UDim2.new(0, 340, 0, 350)
tutCard.Position         = UDim2.new(0.5, -170, 0.5, -175)
tutCard.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
tutCard.BorderSizePixel  = 0
tutCard.ZIndex           = 51
tutCard.Parent           = tutOverlay
Instance.new("UICorner", tutCard).CornerRadius = UDim.new(0, 16)
local tutCardStroke = Instance.new("UIStroke", tutCard)
tutCardStroke.Color     = Color3.fromRGB(52, 52, 52)
tutCardStroke.Thickness = 1

local tutIconCircle = Instance.new("Frame")
tutIconCircle.Size             = UDim2.new(0, 54, 0, 54)
tutIconCircle.Position         = UDim2.new(0.5, -27, 0, 26)
tutIconCircle.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
tutIconCircle.BorderSizePixel  = 0
tutIconCircle.ZIndex           = 52
tutIconCircle.Parent           = tutCard
Instance.new("UICorner", tutIconCircle).CornerRadius = UDim.new(1, 0)
local tutIconRing = Instance.new("UIStroke", tutIconCircle)
tutIconRing.Color     = Color3.fromRGB(55, 55, 55)
tutIconRing.Thickness = 1.5

local tutIconLbl = Instance.new("TextLabel")
tutIconLbl.Size                   = UDim2.new(1, 0, 1, 0)
tutIconLbl.BackgroundTransparency = 1
tutIconLbl.TextColor3             = Color3.fromRGB(200, 200, 200)
tutIconLbl.TextSize               = 22
tutIconLbl.Font                   = Enum.Font.GothamBold
tutIconLbl.ZIndex                 = 53
tutIconLbl.Parent                 = tutIconCircle

local tutTitle = Instance.new("TextLabel")
tutTitle.Size                   = UDim2.new(1, -32, 0, 26)
tutTitle.Position               = UDim2.new(0, 16, 0, 94)
tutTitle.BackgroundTransparency = 1
tutTitle.TextColor3             = Color3.fromRGB(240, 240, 240)
tutTitle.TextSize               = 17
tutTitle.Font                   = Enum.Font.GothamBold
tutTitle.TextXAlignment         = Enum.TextXAlignment.Center
tutTitle.ZIndex                 = 52
tutTitle.Parent                 = tutCard

local tutBody = Instance.new("TextLabel")
tutBody.Size                   = UDim2.new(1, -32, 0, 148)
tutBody.Position               = UDim2.new(0, 16, 0, 128)
tutBody.BackgroundTransparency = 1
tutBody.TextColor3             = Color3.fromRGB(148, 148, 148)
tutBody.TextSize               = 13
tutBody.Font                   = Enum.Font.Gotham
tutBody.TextXAlignment         = Enum.TextXAlignment.Center
tutBody.TextYAlignment         = Enum.TextYAlignment.Top
tutBody.TextWrapped            = true
tutBody.ZIndex                 = 52
tutBody.Parent                 = tutCard

local dotsFrame = Instance.new("Frame")
dotsFrame.Size                   = UDim2.new(1, -32, 0, 10)
dotsFrame.Position               = UDim2.new(0, 16, 0, 284)
dotsFrame.BackgroundTransparency = 1
dotsFrame.ZIndex                 = 52
dotsFrame.Parent                 = tutCard
local dotsLayout = Instance.new("UIListLayout", dotsFrame)
dotsLayout.FillDirection       = Enum.FillDirection.Horizontal
dotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
dotsLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
dotsLayout.Padding             = UDim.new(0, 6)

local pageDots = {}
for i = 1, #tutorialPages do
    local dot = Instance.new("Frame")
    dot.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    dot.BorderSizePixel  = 0
    dot.ZIndex           = 53
    dot.Parent           = dotsFrame
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    pageDots[i] = dot
end

local tutPrev = Instance.new("TextButton")
tutPrev.Size             = UDim2.new(0, 88, 0, 34)
tutPrev.Position         = UDim2.new(0, 16, 0, 302)
tutPrev.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
tutPrev.Text             = "← Back"
tutPrev.TextColor3       = Color3.fromRGB(145, 145, 145)
tutPrev.TextSize         = 13
tutPrev.Font             = Enum.Font.GothamBold
tutPrev.BorderSizePixel  = 0
tutPrev.ZIndex           = 52
tutPrev.Parent           = tutCard
Instance.new("UICorner", tutPrev).CornerRadius = UDim.new(0, 8)

local tutNext = Instance.new("TextButton")
tutNext.Size             = UDim2.new(0, 88, 0, 34)
tutNext.Position         = UDim2.new(1, -104, 0, 302)
tutNext.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
tutNext.Text             = "Next →"
tutNext.TextColor3       = Color3.fromRGB(200, 200, 200)
tutNext.TextSize         = 13
tutNext.Font             = Enum.Font.GothamBold
tutNext.BorderSizePixel  = 0
tutNext.ZIndex           = 52
tutNext.Parent           = tutCard
Instance.new("UICorner", tutNext).CornerRadius = UDim.new(0, 8)

local tutClose = Instance.new("TextButton")
tutClose.Size             = UDim2.new(0, 26, 0, 26)
tutClose.Position         = UDim2.new(1, -34, 0, 8)
tutClose.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
tutClose.Text             = "✕"
tutClose.TextColor3       = Color3.fromRGB(140, 140, 140)
tutClose.TextSize         = 12
tutClose.Font             = Enum.Font.GothamBold
tutClose.BorderSizePixel  = 0
tutClose.ZIndex           = 52
tutClose.Parent           = tutCard
Instance.new("UICorner", tutClose).CornerRadius = UDim.new(1, 0)

local function renderTutPage()
    local p = tutorialPages[tutPage]
    tutIconLbl.Text = p.icon
    tutTitle.Text   = p.title
    tutBody.Text    = p.body
    for i, dot in ipairs(pageDots) do
        local active = i == tutPage
        dot.BackgroundColor3 = active
            and Color3.fromRGB(210, 210, 210)
            or  Color3.fromRGB(52, 52, 52)
        dot.Size = active
            and UDim2.new(0, 20, 0, 8)
            or  UDim2.new(0, 8,  0, 8)
    end
    tutPrev.Visible          = tutPage > 1
    local isLast             = tutPage == #tutorialPages
    tutNext.Text             = isLast and "Done ✓" or "Next →"
    tutNext.BackgroundColor3 = isLast
        and Color3.fromRGB(0, 148, 75)
        or  Color3.fromRGB(30, 30, 30)
    tutNext.TextColor3       = isLast
        and Color3.fromRGB(255, 255, 255)
        or  Color3.fromRGB(200, 200, 200)
end

tutPrev.MouseButton1Click:Connect(function()
    if tutPage > 1 then tutPage -= 1 renderTutPage() end
end)
tutNext.MouseButton1Click:Connect(function()
    if tutPage < #tutorialPages then
        tutPage += 1 renderTutPage()
    else
        tutOverlay.Visible = false
        tutPage = 1
        renderTutPage()
    end
end)
tutClose.MouseButton1Click:Connect(function()
    tutOverlay.Visible = false
    tutPage = 1
    renderTutPage()
end)

renderTutPage()

local frame = Instance.new("Frame")
frame.Size             = UDim2.new(0, 320, 0, 740)
frame.Position         = UDim2.new(0, 20, 0.5, -370)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
frame.BorderSizePixel  = 0
frame.Active           = true
frame.Draggable        = true
frame.Parent           = screenGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
local outerStroke = Instance.new("UIStroke", frame)
outerStroke.Color     = Color3.fromRGB(55, 55, 55)
outerStroke.Thickness = 1

local header = Instance.new("Frame")
header.Size             = UDim2.new(1, 0, 0, 52)
header.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
header.BorderSizePixel  = 0
header.Parent           = frame
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)
local headerFix = Instance.new("Frame")
headerFix.Size             = UDim2.new(1, 0, 0.5, 0)
headerFix.Position         = UDim2.new(0, 0, 0.5, 0)
headerFix.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
headerFix.BorderSizePixel  = 0
headerFix.Parent           = header

local headerTitle = Instance.new("TextLabel")
headerTitle.Size                   = UDim2.new(1, -130, 1, 0)
headerTitle.Position               = UDim2.new(0, 16, 0, 0)
headerTitle.BackgroundTransparency = 1
headerTitle.Text                   = "Curve Settings"
headerTitle.TextColor3             = Color3.fromRGB(255, 255, 255)
headerTitle.TextSize               = 16
headerTitle.Font                   = Enum.Font.GothamBold
headerTitle.TextXAlignment         = Enum.TextXAlignment.Left
headerTitle.Parent                 = header

local headerSub = Instance.new("TextLabel")
headerSub.Size                   = UDim2.new(1, -130, 0, 16)
headerSub.Position               = UDim2.new(0, 16, 0, 30)
headerSub.BackgroundTransparency = 1
headerSub.Text                   = "RightShift to hide"
headerSub.TextColor3             = Color3.fromRGB(90, 90, 90)
headerSub.TextSize               = 11
headerSub.Font                   = Enum.Font.Gotham
headerSub.TextXAlignment         = Enum.TextXAlignment.Left
headerSub.Parent                 = header

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size             = UDim2.new(0, 72, 0, 30)
toggleBtn.Position         = UDim2.new(1, -82, 0.5, -15)
toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 90)
toggleBtn.Text             = "ENABLED"
toggleBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
toggleBtn.TextSize         = 12
toggleBtn.Font             = Enum.Font.GothamBold
toggleBtn.BorderSizePixel  = 0
toggleBtn.Parent           = header
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)

local divider = Instance.new("Frame")
divider.Size             = UDim2.new(1, -24, 0, 1)
divider.Position         = UDim2.new(0, 12, 0, 52)
divider.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
divider.BorderSizePixel  = 0
divider.Parent           = frame

local container = Instance.new("Frame")
container.Size                   = UDim2.new(1, -24, 1, -68)
container.Position               = UDim2.new(0, 12, 0, 60)
container.BackgroundTransparency = 1
container.Parent                 = frame
local layout = Instance.new("UIListLayout", container)
layout.Padding   = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
Instance.new("UIPadding", container).PaddingBottom = UDim.new(0, 8)

local function makeSlider(labelText, description, min, max, default, settingKey, step)
    step = step or 0.01
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 72)
    row.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    row.BorderSizePixel  = 0
    row.Parent           = container
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, -80, 0, 20)
    lbl.Position               = UDim2.new(0, 12, 0, 8)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = labelText
    lbl.TextColor3             = Color3.fromRGB(230, 230, 230)
    lbl.TextSize               = 14
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.Parent                 = row

    local desc = Instance.new("TextLabel")
    desc.Size                   = UDim2.new(1, -16, 0, 14)
    desc.Position               = UDim2.new(0, 12, 0, 28)
    desc.BackgroundTransparency = 1
    desc.Text                   = description
    desc.TextColor3             = Color3.fromRGB(100, 100, 100)
    desc.TextSize               = 11
    desc.Font                   = Enum.Font.Gotham
    desc.TextXAlignment         = Enum.TextXAlignment.Left
    desc.Parent                 = row

    local valLbl = Instance.new("TextLabel")
    valLbl.Size                   = UDim2.new(0, 60, 0, 20)
    valLbl.Position               = UDim2.new(1, -70, 0, 8)
    valLbl.BackgroundTransparency = 1
    valLbl.Text                   = tostring(default)
    valLbl.TextColor3             = Color3.fromRGB(80, 180, 255)
    valLbl.TextSize               = 14
    valLbl.Font                   = Enum.Font.GothamBold
    valLbl.TextXAlignment         = Enum.TextXAlignment.Right
    valLbl.Parent                 = row

    local track = Instance.new("Frame")
    track.Size             = UDim2.new(1, -24, 0, 6)
    track.Position         = UDim2.new(0, 12, 0, 52)
    track.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    track.BorderSizePixel  = 0
    track.Parent           = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size             = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(80, 180, 255)
    fill.BorderSizePixel  = 0
    fill.Parent           = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("TextButton")
    knob.Size             = UDim2.new(0, 16, 0, 16)
    knob.Position         = UDim2.new((default - min) / (max - min), -8, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Text             = ""
    knob.BorderSizePixel  = 0
    knob.ZIndex           = 2
    knob.Parent           = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local function update(xPos)
        local alpha   = math.clamp((xPos - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local snapped = math.round((min + (max - min) * alpha) / step) * step
        local display = math.floor(snapped * 1000 + 0.5) / 1000
        fill.Size            = UDim2.new(alpha, 0, 1, 0)
        knob.Position        = UDim2.new(alpha, -8, 0.5, -8)
        valLbl.Text          = tostring(display)
        Settings[settingKey] = snapped
    end

    local dragging = false
    knob.MouseButton1Down:Connect(function() dragging = true end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (
            i.UserInputType == Enum.UserInputType.MouseMovement or
            i.UserInputType == Enum.UserInputType.Touch
        ) then update(i.Position.X) end
    end)
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(i.Position.X)
        end
    end)
end

makeSlider("Glide Speed",      "Lower = faster. (0.1 is instant, 1.0 is slow)", 0.1, 1.0, Settings.Duration,      "Duration",      0.025)
makeSlider("Landing Distance", "How many studs behind the target you land",      1,   10,  Settings.Radius,        "Radius",        0.5)
makeSlider("Detection Range",  "How far away a target can be detected (studs)",  10,  50,  Settings.Range,         "Range",         1)
makeSlider("Curve Width",      "How wide the arc swings around the target",      0,   30,  Settings.CurveStrength, "CurveStrength", 1)
makeSlider("Camera Height",    "How high the lock-on camera floats above you",   0,   10,  Settings.CamOffset,     "CamOffset",     0.5)

local pingDivider = Instance.new("Frame")
pingDivider.Size             = UDim2.new(1, 0, 0, 1)
pingDivider.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
pingDivider.BorderSizePixel  = 0
pingDivider.Parent           = container

local pingSection = Instance.new("Frame")
pingSection.Size             = UDim2.new(1, 0, 0, 158)
pingSection.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
pingSection.BorderSizePixel  = 0
pingSection.Parent           = container
Instance.new("UICorner", pingSection).CornerRadius = UDim.new(0, 10)

local pingSectionTitle = Instance.new("TextLabel")
pingSectionTitle.Size                   = UDim2.new(1, -16, 0, 20)
pingSectionTitle.Position               = UDim2.new(0, 12, 0, 8)
pingSectionTitle.BackgroundTransparency = 1
pingSectionTitle.Text                   = "Ping Visualizer"
pingSectionTitle.TextColor3             = Color3.fromRGB(230, 230, 230)
pingSectionTitle.TextSize               = 14
pingSectionTitle.Font                   = Enum.Font.GothamBold
pingSectionTitle.TextXAlignment         = Enum.TextXAlignment.Left
pingSectionTitle.Parent                 = pingSection

local pingSectionDesc = Instance.new("TextLabel")
pingSectionDesc.Size                   = UDim2.new(1, -16, 0, 14)
pingSectionDesc.Position               = UDim2.new(0, 12, 0, 28)
pingSectionDesc.BackgroundTransparency = 1
pingSectionDesc.Text                   = "Shows ghost of where server thinks you are"
pingSectionDesc.TextColor3             = Color3.fromRGB(100, 100, 100)
pingSectionDesc.TextSize               = 11
pingSectionDesc.Font                   = Enum.Font.Gotham
pingSectionDesc.TextXAlignment         = Enum.TextXAlignment.Left
pingSectionDesc.Parent                 = pingSection

local pingDisplay = Instance.new("TextLabel")
pingDisplay.Size                   = UDim2.new(0, 80, 0, 20)
pingDisplay.Position               = UDim2.new(1, -90, 0, 8)
pingDisplay.BackgroundTransparency = 1
pingDisplay.Text                   = "-- ms"
pingDisplay.TextColor3             = Color3.fromRGB(80, 180, 255)
pingDisplay.TextSize               = 14
pingDisplay.Font                   = Enum.Font.GothamBold
pingDisplay.TextXAlignment         = Enum.TextXAlignment.Right
pingDisplay.Parent                 = pingSection

local pingToggle = Instance.new("TextButton")
pingToggle.Size             = UDim2.new(0, 72, 0, 28)
pingToggle.Position         = UDim2.new(1, -82, 0, 46)
pingToggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
pingToggle.Text             = "OFF"
pingToggle.TextColor3       = Color3.fromRGB(180, 180, 180)
pingToggle.TextSize         = 12
pingToggle.Font             = Enum.Font.GothamBold
pingToggle.BorderSizePixel  = 0
pingToggle.Parent           = pingSection
Instance.new("UICorner", pingToggle).CornerRadius = UDim.new(0, 8)

local colorLabel = Instance.new("TextLabel")
colorLabel.Size                   = UDim2.new(1, -16, 0, 14)
colorLabel.Position               = UDim2.new(0, 12, 0, 84)
colorLabel.BackgroundTransparency = 1
colorLabel.Text                   = "Ghost color"
colorLabel.TextColor3             = Color3.fromRGB(100, 100, 100)
colorLabel.TextSize               = 11
colorLabel.Font                   = Enum.Font.Gotham
colorLabel.TextXAlignment         = Enum.TextXAlignment.Left
colorLabel.Parent                 = pingSection

local swatchColors = {
    { name = "Red",    color = Color3.fromRGB(255, 80,  80)  },
    { name = "Orange", color = Color3.fromRGB(255, 160, 50)  },
    { name = "Yellow", color = Color3.fromRGB(255, 230, 50)  },
    { name = "Green",  color = Color3.fromRGB(80,  220, 100) },
    { name = "Blue",   color = Color3.fromRGB(80,  180, 255) },
    { name = "Purple", color = Color3.fromRGB(180, 80,  255) },
    { name = "Pink",   color = Color3.fromRGB(255, 100, 200) },
    { name = "White",  color = Color3.fromRGB(255, 255, 255) },
}

local swatchRow = Instance.new("Frame")
swatchRow.Size                   = UDim2.new(1, -24, 0, 32)
swatchRow.Position               = UDim2.new(0, 12, 0, 104)
swatchRow.BackgroundTransparency = 1
swatchRow.Parent                 = pingSection
local swatchLayout = Instance.new("UIListLayout", swatchRow)
swatchLayout.FillDirection = Enum.FillDirection.Horizontal
swatchLayout.Padding       = UDim.new(0, 6)
swatchLayout.SortOrder     = Enum.SortOrder.LayoutOrder

local selectedSwatch = nil
local function selectSwatch(btn, color)
    if selectedSwatch then
        for _, c in pairs(selectedSwatch:GetChildren()) do
            if c:IsA("UIStroke") then c:Destroy() end
        end
    end
    selectedSwatch = btn
    local stroke = Instance.new("UIStroke", btn)
    stroke.Color     = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 2
    setGhostColor(color)
end

for _, swatch in ipairs(swatchColors) do
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(0, 26, 0, 26)
    btn.BackgroundColor3 = swatch.color
    btn.Text             = ""
    btn.BorderSizePixel  = 0
    btn.Parent           = swatchRow
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
    if swatch.name == "Red" then
        selectedSwatch = btn
        local stroke = Instance.new("UIStroke", btn)
        stroke.Color     = Color3.fromRGB(255, 255, 255)
        stroke.Thickness = 2
    end
    local swatchColor = swatch.color
    btn.MouseButton1Click:Connect(function() selectSwatch(btn, swatchColor) end)
end

pingSection.Size = UDim2.new(1, 0, 0, 158)

local div2 = Instance.new("Frame")
div2.Size             = UDim2.new(1, 0, 0, 1)
div2.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
div2.BorderSizePixel  = 0
div2.Parent           = container

local dashRow = Instance.new("Frame")
dashRow.Size             = UDim2.new(1, 0, 0, 44)
dashRow.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
dashRow.BorderSizePixel  = 0
dashRow.Parent           = container
Instance.new("UICorner", dashRow).CornerRadius = UDim.new(0, 10)

local dashRowLabel = Instance.new("TextLabel")
dashRowLabel.Size                   = UDim2.new(0, 120, 1, 0)
dashRowLabel.Position               = UDim2.new(0, 12, 0, 0)
dashRowLabel.BackgroundTransparency = 1
dashRowLabel.Text                   = "Dash Button"
dashRowLabel.TextColor3             = Color3.fromRGB(200, 200, 200)
dashRowLabel.TextSize               = 13
dashRowLabel.Font                   = Enum.Font.GothamBold
dashRowLabel.TextXAlignment         = Enum.TextXAlignment.Left
dashRowLabel.Parent                 = dashRow

local lockBtn = Instance.new("TextButton")
lockBtn.Size             = UDim2.new(1, -140, 0, 28)
lockBtn.Position         = UDim2.new(0, 132, 0.5, -14)
lockBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
lockBtn.Text             = "🔓 Unlocked"
lockBtn.TextColor3       = Color3.fromRGB(180, 180, 180)
lockBtn.TextSize         = 12
lockBtn.Font             = Enum.Font.GothamBold
lockBtn.BorderSizePixel  = 0
lockBtn.Parent           = dashRow
Instance.new("UICorner", lockBtn).CornerRadius = UDim.new(0, 8)

local utilRow = Instance.new("Frame")
utilRow.Size             = UDim2.new(1, 0, 0, 44)
utilRow.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
utilRow.BorderSizePixel  = 0
utilRow.Parent           = container
Instance.new("UICorner", utilRow).CornerRadius = UDim.new(0, 10)

local tutBtn = Instance.new("TextButton")
tutBtn.Size             = UDim2.new(1, -24, 0, 28)
tutBtn.Position         = UDim2.new(0, 12, 0.5, -14)
tutBtn.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
tutBtn.Text             = "? How to use / Tutorial"
tutBtn.TextColor3       = Color3.fromRGB(190, 190, 190)
tutBtn.TextSize         = 13
tutBtn.Font             = Enum.Font.GothamBold
tutBtn.BorderSizePixel  = 0
tutBtn.Parent           = utilRow
Instance.new("UICorner", tutBtn).CornerRadius = UDim.new(0, 8)
local tutBtnStroke = Instance.new("UIStroke", tutBtn)
tutBtnStroke.Color     = Color3.fromRGB(58, 58, 58)
tutBtnStroke.Thickness = 1

toggleBtn.MouseButton1Click:Connect(function()
    ScriptEnabled              = not ScriptEnabled
    toggleBtn.Text             = ScriptEnabled and "ENABLED" or "DISABLED"
    toggleBtn.BackgroundColor3 = ScriptEnabled
        and Color3.fromRGB(0, 180, 90)
        or  Color3.fromRGB(190, 50, 50)
end)

pingToggle.MouseButton1Click:Connect(function()
    pingVisualizerEnabled = not pingVisualizerEnabled
    if pingVisualizerEnabled then
        pingToggle.Text             = "ON"
        pingToggle.TextColor3       = Color3.fromRGB(255, 255, 255)
        pingToggle.BackgroundColor3 = Color3.fromRGB(0, 180, 90)
        createGhost(LocalPlayer.Character)
    else
        pingToggle.Text             = "OFF"
        pingToggle.TextColor3       = Color3.fromRGB(180, 180, 180)
        pingToggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        destroyGhost()
    end
end)

lockBtn.MouseButton1Click:Connect(function()
    mobileBtnLocked = not mobileBtnLocked
    updateLockVisual()
    if mobileBtnLocked then
        lockBtn.Text             = "🔒 Locked"
        lockBtn.TextColor3       = Color3.fromRGB(255, 200, 50)
        lockBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 20)
    else
        lockBtn.Text             = "🔓 Unlocked"
        lockBtn.TextColor3       = Color3.fromRGB(180, 180, 180)
        lockBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    end
end)

tutBtn.MouseButton1Click:Connect(function()
    tutPage = 1
    renderTutPage()
    tutOverlay.Visible = true
end)

local guiVisible = true
UserInputService.InputBegan:Connect(function(input, processed)
    if input.KeyCode == Enum.KeyCode.RightShift then
        guiVisible = not guiVisible
        frame.Visible     = guiVisible
        hintLabel.Visible = false
        dashBtn.Visible   = guiVisible
    end
end)

local function getHRP(character)
    return character and (
        character:FindFirstChild("HumanoidRootPart") or
        character:FindFirstChild("Torso") or
        character:FindFirstChild("UpperTorso")
    )
end

local function pressKey(keyCode)
    if not ScriptEnabled then return end
    VirtualInputManager:SendKeyEvent(true,  keyCode, false, game)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

local function getNearestPlayer(maxRange)
    local myHRP = getHRP(LocalPlayer.Character)
    if not myHRP then return nil end
    local nearest, nearestDist = nil, maxRange
    for _, pl in pairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character
        and pl.Character:FindFirstChild("Humanoid")
        and pl.Character.Humanoid.Health > 0 then
            local tHRP = getHRP(pl.Character)
            if tHRP then
                local dist = (myHRP.Position - tHRP.Position).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearest     = pl
                end
            end
        end
    end
    return nearest
end

local function isEnemyRagdolled(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return false end
    local hum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
    local hrp = getHRP(targetPlayer.Character)
    if hum and hrp then
        return hum:GetState() == Enum.HumanoidStateType.Physics
            or math.abs(hrp.CFrame.UpVector.Y) < 0.7
    end
    return false
end

local function getActiveAnimId()
    local char     = LocalPlayer.Character
    local hum      = char and char:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do
            local id = track.Animation.AnimationId
            if AnimationTriggers[id] or StraightAnimations[id] then return id end
        end
    end
    return nil
end

function startCurveGlide()
    if not ScriptEnabled then return end
    local target = getNearestPlayer(Settings.Range)
    local myChar = LocalPlayer.Character
    local myHRP  = getHRP(myChar)
    local hum    = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not (target and myHRP and hum) then return end
    if isEnemyRagdolled(target) then return end

    local tHRP = getHRP(target.Character)
    if not tHRP or not tHRP.Parent then return end

    local startTime = tick()
    local startPos  = Vector3.new(myHRP.Position.X, 0, myHRP.Position.Z)

    local function getBehindPos()
        local lookFlat = Vector3.new(
            tHRP.CFrame.LookVector.X, 0, tHRP.CFrame.LookVector.Z
        ).Unit
        return Vector3.new(tHRP.Position.X, 0, tHRP.Position.Z) - lookFlat * Settings.Radius
    end

    local function getSideControlPoint()
        local rightVec = Vector3.new(
            tHRP.CFrame.RightVector.X, 0, tHRP.CFrame.RightVector.Z
        ).Unit
        local toPlayer    = Vector3.new(myHRP.Position.X, 0, myHRP.Position.Z)
                          - Vector3.new(tHRP.Position.X,  0, tHRP.Position.Z)
        local sideSign    = toPlayer:Dot(rightVec) >= 0 and 1 or -1
        local initEnd     = getBehindPos()
        local flatDist    = (initEnd - startPos).Magnitude
        local scaledCurve = math.clamp(flatDist * 0.6, 4, Settings.CurveStrength)
        return Vector3.new(tHRP.Position.X, 0, tHRP.Position.Z)
             + rightVec * (scaledCurve * sideSign)
    end

    local controlPt       = getSideControlPoint()
    hum.AutoRotate        = false
    local prevCam         = Camera.CameraType
    Camera.CameraType     = Enum.CameraType.Custom

    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not ScriptEnabled then
            conn:Disconnect()
            hum.AutoRotate    = true
            Camera.CameraType = prevCam
            return
        end

        local alpha = math.clamp((tick() - startTime) / Settings.Duration, 0, 1)

        if alpha >= 1 or not tHRP.Parent then
            conn:Disconnect()
            hum.AutoRotate    = true
            Camera.CameraType = prevCam
            if tHRP and tHRP.Parent then
                local finalBehind = getBehindPos()
                myHRP.CFrame = CFrame.new(
                    Vector3.new(finalBehind.X, myHRP.Position.Y, finalBehind.Z),
                    Vector3.new(tHRP.Position.X, myHRP.Position.Y, tHRP.Position.Z)
                )
            end
            return
        end

        local liveEndPos     = getBehindPos()
        local blendedControl = Vector3.new(
            controlPt.X * (1 - alpha) + liveEndPos.X * alpha,
            0,
            controlPt.Z * (1 - alpha) + liveEndPos.Z * alpha
        )

        local t  = 1 - (1 - alpha)^2
        local t1 = 1 - t
        local movePos = Vector3.new(
            (t1*t1)*startPos.X + (2*t1*t)*blendedControl.X + (t*t)*liveEndPos.X,
            myHRP.Position.Y,
            (t1*t1)*startPos.Z + (2*t1*t)*blendedControl.Z + (t*t)*liveEndPos.Z
        )

        myHRP.CFrame  = CFrame.new(
            movePos,
            Vector3.new(tHRP.Position.X, movePos.Y, tHRP.Position.Z)
        )
        Camera.CFrame = CFrame.new(
            myHRP.Position + Vector3.new(0, Settings.CamOffset, 0),
            tHRP.Position
        )
    end)
end

dashBtn.MouseButton1Click:Connect(function()
    if not ScriptEnabled then return end
    pressKey(Enum.KeyCode.Three)
    task.wait(0.2)
    startCurveGlide()
end)

local function setupCharacter(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    local animator = humanoid and humanoid:WaitForChild("Animator", 5)
    if not animator then return end
    animator.AnimationPlayed:Connect(function(track)
        if not ScriptEnabled then return end
        local animId    = track.Animation.AnimationId
        local delayTime = AnimationTriggers[animId]
        if not delayTime and StraightAnimations[animId] then delayTime = 0.19 end
        if delayTime then
            task.delay(delayTime, function()
                if humanoid.Health > 0 and ScriptEnabled then
                    pressKey(Enum.KeyCode.Three)
                end
            end)
        end
    end)
    if pingVisualizerEnabled then createGhost(character) end
end

if LocalPlayer.Character then setupCharacter(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(setupCharacter)

RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local pingMs = math.round(LocalPlayer:GetNetworkPing() * 1000)
    pingDisplay.Text = pingMs .. " ms"
    pingDisplay.TextColor3 =
        pingMs < 80  and Color3.fromRGB(80,  220, 100) or
        pingMs < 150 and Color3.fromRGB(255, 200, 50)  or
        Color3.fromRGB(255, 80, 80)
    if not pingVisualizerEnabled then return end
    recordSnapshot(char)
    local snapshot = getDelayedSnapshot()
    if snapshot then applySnapshotToGhost(snapshot) end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if ScriptEnabled and input.KeyCode == Enum.KeyCode.E then
        pressKey(Enum.KeyCode.Three)
        task.wait(0.2)
        startCurveGlide()
    end
end)

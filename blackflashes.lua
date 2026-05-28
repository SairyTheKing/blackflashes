if _G.boomshaka then
    warn("Script already running!")
    return
end
setclipboard("https://discord.gg/wNkmb2HB69")
local NotificationLibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/IceMinisterq/Notification-Library/Main/Library.lua"))()
NotificationLibrary:SendNotification("Info", "Discord copied to clipboard, if script doesn't execute please report in discord", 5)

_G.boomshaka = true

local ScriptEnabled = true
local glideInProgress = false

local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService      = game:GetService("HttpService")
local TweenService     = game:GetService("TweenService")
local LocalPlayer      = Players.LocalPlayer
local Camera           = workspace.CurrentCamera

local AnimationTriggers = {
    ["rbxassetid://100962226150441"] = 0.19,
    ["rbxassetid://95852624447551"]  = 0.19,
    ["rbxassetid://74145636023952"]  = 0.19,
    ["rbxassetid://72475960800126"]  = 0.20,
}

local StraightAnimations = {
    ["rbxassetid://123171106092050"] = true,
}

local DefaultSettings = {
    Duration      = 0.25,
    Radius        = 3,
    Range         = 25,
    CurveStrength = 14,
    CamOffset     = 4,
}

local Settings = {}
for k, v in pairs(DefaultSettings) do
    Settings[k] = v
end

local GhostColor = Color3.fromRGB(255, 80, 80)

local pingVisualizerEnabled = false
local ghostModel            = nil
local positionHistory       = {}
local MAX_HISTORY           = 300

local CONFIG_FOLDER = "Boomshaka_Configs"
local CONFIG_FILE = CONFIG_FOLDER .. "/config.json"

local function loadConfig()
    local success, result = pcall(function()
        if not isfolder(CONFIG_FOLDER) then
            makefolder(CONFIG_FOLDER)
        end
        if isfile(CONFIG_FILE) then
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end
        return nil
    end)
    if success and result then
        for k, v in pairs(result) do
            if k == "Duration" or k == "Radius" or k == "Range" or k == "CurveStrength" or k == "CamOffset" then
                if typeof(v) == "number" then
                    Settings[k] = v
                end
            end
            if k == "GhostColor" and typeof(v) == "table" then
                GhostColor = Color3.new(v.R, v.G, v.B)
            end
            if k == "PingVisualizer" and typeof(v) == "boolean" then
                pingVisualizerEnabled = v
            end
            if k == "DashButtonLocked" and typeof(v) == "boolean" then
                mobileBtnLocked = v
            end
        end
    end
end

local function saveConfig()
    pcall(function()
        if not isfolder(CONFIG_FOLDER) then
            makefolder(CONFIG_FOLDER)
        end
        local data = {
            Duration = Settings.Duration,
            Radius = Settings.Radius,
            Range = Settings.Range,
            CurveStrength = Settings.CurveStrength,
            CamOffset = Settings.CamOffset,
            GhostColor = {R = GhostColor.R, G = GhostColor.G, B = GhostColor.B},
            PingVisualizer = pingVisualizerEnabled,
            DashButtonLocked = mobileBtnLocked,
        }
        writefile(CONFIG_FILE, HttpService:JSONEncode(data))
    end)
end

local function fireActivated()
    if not ScriptEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local moveset = char:FindFirstChild("Moveset")
    if not moveset then return end
    local move = moveset:FindFirstChild("Divergent Fist")
    if not move then return end
    local ok, re = pcall(function()
        return ReplicatedStorage.Knit.Knit.Services.DivergentFistService.RE.Activated
    end)
    if not ok or not re then return end
    re:FireServer(move)
end

local function setGhostColor(color)
    GhostColor = color
    if ghostModel then
        for _, part in pairs(ghostModel:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("MeshPart") then
                part.Color = color
            end
        end
    end
    saveConfig()
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

local notifGui = Instance.new("ScreenGui")
notifGui.Name = "BoomshakaNotif"
notifGui.ResetOnSpawn = false
notifGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
notifGui.Parent = LocalPlayer.PlayerGui

local function showNotification()
    local notifFrame = Instance.new("Frame")
    notifFrame.Size = UDim2.new(0, 340, 0, 72)
    notifFrame.Position = UDim2.new(0.5, -170, 0, -100)
    notifFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
    notifFrame.BorderSizePixel = 0
    notifFrame.Parent = notifGui
    Instance.new("UICorner", notifFrame).CornerRadius = UDim.new(0, 14)
    local notifStroke = Instance.new("UIStroke", notifFrame)
    notifStroke.Color = Color3.fromRGB(80, 180, 255)
    notifStroke.Thickness = 1.5

    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, 44, 0, 44)
    icon.Position = UDim2.new(0, 14, 0.5, -22)
    icon.BackgroundTransparency = 1
    icon.Text = "⚡"
    icon.TextColor3 = Color3.fromRGB(80, 180, 255)
    icon.TextSize = 28
    icon.Font = Enum.Font.GothamBold
    icon.Parent = notifFrame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -72, 0, 24)
    title.Position = UDim2.new(0, 60, 0, 12)
    title.BackgroundTransparency = 1
    title.Text = "Boomshaka Loaded"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = notifFrame

    local body = Instance.new("TextLabel")
    body.Size = UDim2.new(1, -72, 0, 18)
    body.Position = UDim2.new(0, 60, 0, 38)
    body.BackgroundTransparency = 1
    body.Text = "Press E to start Black Flashing"
    body.TextColor3 = Color3.fromRGB(160, 160, 160)
    body.TextSize = 13
    body.Font = Enum.Font.Gotham
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.Parent = notifFrame

    TweenService:Create(notifFrame, TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -170, 0, 28)
    }):Play()

    task.delay(4.5, function()
        local tween = TweenService:Create(notifFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, -170, 0, -100)
        })
        tween:Play()
        tween.Completed:Connect(function()
            notifFrame:Destroy()
        end)
    end)
end

showNotification()

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
        body  = "RightShift opens/closes this panel.\n\nGlide Duration — how long the dash takes\nStop Distance — studs behind the target you land\nTarget Range — how far enemies are detected\nArc Width — how wide the curve swings\nCam Lift — camera height during the dash",
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
frame.Size             = UDim2.new(0, 320, 0, 820)
frame.Position         = UDim2.new(0, 20, 0.5, -410)
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

local sliderRefs = {}

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
        saveConfig()
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

    sliderRefs[settingKey] = {fill = fill, knob = knob, track = track, valLbl = valLbl, min = min, max = max}
end

makeSlider("Glide Duration",  "How long the dash takes in seconds. Lower = faster", 0.1, 1.0, Settings.Duration,      "Duration",      0.025)
makeSlider("Stop Distance",   "Studs behind the target where you stop",              1,   10,  Settings.Radius,        "Radius",        0.5)
makeSlider("Target Range",    "Max distance to detect enemies (studs)",              10,  50,  Settings.Range,         "Range",         1)
makeSlider("Arc Width",       "Curve arc size. 0 = straight dash, 30 = wide arc",   0,   30,  Settings.CurveStrength, "CurveStrength", 1)
makeSlider("Cam Lift",        "How high the camera rises above you during the dash", 0,   10,  Settings.CamOffset,     "CamOffset",     0.5)

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

local configRow = Instance.new("Frame")
configRow.Size             = UDim2.new(1, 0, 0, 44)
configRow.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
configRow.BorderSizePixel  = 0
configRow.Parent           = container
Instance.new("UICorner", configRow).CornerRadius = UDim.new(0, 10)

local configLabel = Instance.new("TextLabel")
configLabel.Size                   = UDim2.new(0, 100, 1, 0)
configLabel.Position               = UDim2.new(0, 12, 0, 0)
configLabel.BackgroundTransparency = 1
configLabel.Text                   = "Config"
configLabel.TextColor3             = Color3.fromRGB(200, 200, 200)
configLabel.TextSize               = 13
configLabel.Font                   = Enum.Font.GothamBold
configLabel.TextXAlignment         = Enum.TextXAlignment.Left
configLabel.Parent                 = configRow

local saveConfigBtn = Instance.new("TextButton")
saveConfigBtn.Size             = UDim2.new(0, 55, 0, 28)
saveConfigBtn.Position         = UDim2.new(0, 120, 0.5, -14)
saveConfigBtn.BackgroundColor3 = Color3.fromRGB(0, 148, 75)
saveConfigBtn.Text             = "💾 Save"
saveConfigBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
saveConfigBtn.TextSize         = 11
saveConfigBtn.Font             = Enum.Font.GothamBold
saveConfigBtn.BorderSizePixel  = 0
saveConfigBtn.Parent           = configRow
Instance.new("UICorner", saveConfigBtn).CornerRadius = UDim.new(0, 8)

local loadConfigBtn = Instance.new("TextButton")
loadConfigBtn.Size             = UDim2.new(0, 55, 0, 28)
loadConfigBtn.Position         = UDim2.new(0, 181, 0.5, -14)
loadConfigBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
loadConfigBtn.Text             = "↺ Load"
loadConfigBtn.TextColor3       = Color3.fromRGB(180, 180, 180)
loadConfigBtn.TextSize         = 11
loadConfigBtn.Font             = Enum.Font.GothamBold
loadConfigBtn.BorderSizePixel  = 0
loadConfigBtn.Parent           = configRow
Instance.new("UICorner", loadConfigBtn).CornerRadius = UDim.new(0, 8)

local resetConfigBtn = Instance.new("TextButton")
resetConfigBtn.Size             = UDim2.new(0, 55, 0, 28)
resetConfigBtn.Position         = UDim2.new(0, 242, 0.5, -14)
resetConfigBtn.BackgroundColor3 = Color3.fromRGB(190, 50, 50)
resetConfigBtn.Text             = "↺ Reset"
resetConfigBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
resetConfigBtn.TextSize         = 11
resetConfigBtn.Font             = Enum.Font.GothamBold
resetConfigBtn.BorderSizePixel  = 0
resetConfigBtn.Parent           = configRow
Instance.new("UICorner", resetConfigBtn).CornerRadius = UDim.new(0, 8)

local function updateSlidersFromSettings()
    for key, ref in pairs(sliderRefs) do
        local val = Settings[key]
        if val then
            local alpha = (val - ref.min) / (ref.max - ref.min)
            ref.fill.Size = UDim2.new(alpha, 0, 1, 0)
            ref.knob.Position = UDim2.new(alpha, -8, 0.5, -8)
            ref.valLbl.Text = tostring(math.floor(val * 1000 + 0.5) / 1000)
        end
    end
end

saveConfigBtn.MouseButton1Click:Connect(function()
    saveConfig()
    saveConfigBtn.Text = "✓ Saved"
    saveConfigBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 90)
    task.delay(1.5, function()
        saveConfigBtn.Text = "💾 Save"
        saveConfigBtn.BackgroundColor3 = Color3.fromRGB(0, 148, 75)
    end)
end)

loadConfigBtn.MouseButton1Click:Connect(function()
    loadConfig()
    updateSlidersFromSettings()
    if pingVisualizerEnabled then
        pingToggle.Text = "ON"
        pingToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
        pingToggle.BackgroundColor3 = Color3.fromRGB(0, 180, 90)
        createGhost(LocalPlayer.Character)
    else
        pingToggle.Text = "OFF"
        pingToggle.TextColor3 = Color3.fromRGB(180, 180, 180)
        pingToggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        destroyGhost()
    end
    updateLockVisual()
    if mobileBtnLocked then
        lockBtn.Text = "🔒 Locked"
        lockBtn.TextColor3 = Color3.fromRGB(255, 200, 50)
        lockBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 20)
    else
        lockBtn.Text = "🔓 Unlocked"
        lockBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
        lockBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    end
    loadConfigBtn.Text = "✓ Loaded"
    loadConfigBtn.BackgroundColor3 = Color3.fromRGB(0, 148, 75)
    loadConfigBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    task.delay(1.5, function()
        loadConfigBtn.Text = "↺ Load"
        loadConfigBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        loadConfigBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    end)
end)

resetConfigBtn.MouseButton1Click:Connect(function()
    Settings.Duration = 0.25
    Settings.Radius = 3
    Settings.Range = 25
    Settings.CurveStrength = 14
    Settings.CamOffset = 4
    GhostColor = Color3.fromRGB(255, 80, 80)
    pingVisualizerEnabled = false
    mobileBtnLocked = false
    updateSlidersFromSettings()
    destroyGhost()
    pingToggle.Text = "OFF"
    pingToggle.TextColor3 = Color3.fromRGB(180, 180, 180)
    pingToggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    updateLockVisual()
    lockBtn.Text = "🔓 Unlocked"
    lockBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    lockBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    for _, swatch in ipairs(swatchColors) do
        if swatch.name == "Red" then
            for _, child in pairs(swatchRow:GetChildren()) do
                if child:IsA("TextButton") then
                    for _, c in pairs(child:GetChildren()) do
                        if c:IsA("UIStroke") then c:Destroy() end
                    end
                    if child.BackgroundColor3 == swatch.color then
                        selectedSwatch = child
                        local stroke = Instance.new("UIStroke", child)
                        stroke.Color = Color3.fromRGB(255, 255, 255)
                        stroke.Thickness = 2
                    end
                end
            end
        end
    end
    saveConfig()
    resetConfigBtn.Text = "✓ Reset"
    resetConfigBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
    task.delay(1.5, function()
        resetConfigBtn.Text = "↺ Reset"
        resetConfigBtn.BackgroundColor3 = Color3.fromRGB(190, 50, 50)
    end)
end)

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
    saveConfig()
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
    saveConfig()
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

-- Modified: now also detects non-player characters (NPCs) in workspace.Character or workspace
local function getNearestTarget(maxRange, exclude)
    local myHRP = getHRP(LocalPlayer.Character)
    if not myHRP then return nil end
    local nearest, nearestDist = nil, maxRange

    local function considerCharacter(charModel, ownerPlayer)
        if charModel == LocalPlayer.Character then return end
        if exclude then
            if ownerPlayer and exclude == ownerPlayer then return end
            if not ownerPlayer and exclude.Character and exclude.Character == charModel then return end
            if not ownerPlayer and typeof(exclude) == "Instance" and exclude == charModel then return end
        end
        local hum = charModel:FindFirstChildOfClass("Humanoid")
        local hrp = getHRP(charModel)
        if hum and hum.Health > 0 and hrp then
            local dist = (myHRP.Position - hrp.Position).Magnitude
            if dist < nearestDist then
                nearestDist = dist
                if ownerPlayer then
                    nearest = ownerPlayer
                else
                    nearest = {Character = charModel}  -- wrapper for NPC
                end
            end
        end
    end

    -- Player characters
    for _, pl in pairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer then
            local char = pl.Character
            if char then considerCharacter(char, pl) end
        end
    end

    -- Non-player characters: first check workspace.Character folder, else scan workspace
    local charFolder = workspace:FindFirstChild("Character")
    local modelsToCheck = {}
    if charFolder then
        for _, obj in ipairs(charFolder:GetChildren()) do
            if obj:IsA("Model") then table.insert(modelsToCheck, obj) end
        end
    else
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(obj) then
                if not table.find(modelsToCheck, obj) then
                    table.insert(modelsToCheck, obj)
                end
            end
        end
    end
    for _, charModel in ipairs(modelsToCheck) do
        considerCharacter(charModel, nil)
    end

    return nearest
end

-- Modified: works with both Player objects and character models directly
local function isEnemyRagdolled(target)
    local char
    if target and target.Character then
        char = target.Character  -- player or NPC wrapper
    else
        char = target            -- assume it's a character model
    end
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = getHRP(char)
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
    if not ScriptEnabled or glideInProgress then return end
    glideInProgress = true

    local target = getNearestTarget(Settings.Range)
    local myChar = LocalPlayer.Character
    local myHRP  = getHRP(myChar)
    local hum    = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not (target and myHRP and hum) then glideInProgress = false return end
    if isEnemyRagdolled(target) then glideInProgress = false return end

    -- Extract the target character (works for Player, NPC wrapper, or direct model)
    local targetChar
    if target.Character then
        targetChar = target.Character
    elseif typeof(target) == "Instance" then
        targetChar = target
    else
        glideInProgress = false
        return
    end

    local tHRP = getHRP(targetChar)
    if not tHRP or not tHRP.Parent then glideInProgress = false return end

    local startTime = tick()
    local startPos  = Vector3.new(myHRP.Position.X, 0, myHRP.Position.Z)

    local initialTargetCF = tHRP.CFrame
    local initialLookFlat = Vector3.new(initialTargetCF.LookVector.X, 0, initialTargetCF.LookVector.Z).Unit
    local initialRightVec = Vector3.new(initialTargetCF.RightVector.X, 0, initialTargetCF.RightVector.Z).Unit
    local toPlayer = startPos - Vector3.new(tHRP.Position.X, 0, tHRP.Position.Z)
    local lockedSideSign = toPlayer:Dot(initialRightVec) >= 0 and 1 or -1

    local function getBehindPos()
        if not (tHRP and tHRP.Parent) then return nil end
        return Vector3.new(tHRP.Position.X, 0, tHRP.Position.Z) - initialLookFlat * Settings.Radius
    end

    local function getSideControlPoint()
        if not (tHRP and tHRP.Parent) then return nil end
        return Vector3.new(tHRP.Position.X, 0, tHRP.Position.Z) + initialRightVec * (Settings.CurveStrength * lockedSideSign)
    end

    hum.AutoRotate        = false
    local prevCam         = Camera.CameraType
    Camera.CameraType     = Enum.CameraType.Custom

    local MAX_DEST_SPEED = 18
    local smoothedEnd    = getBehindPos()
    local lastHeartbeat  = tick()

    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not ScriptEnabled then
            conn:Disconnect()
            if hum then hum.AutoRotate = true end
            Camera.CameraType = prevCam
            glideInProgress = false
            return
        end

        myHRP = getHRP(LocalPlayer.Character)
        if not (myHRP and myHRP.Parent and hum and hum.Health > 0) then
            conn:Disconnect()
            if hum then hum.AutoRotate = true end
            Camera.CameraType = prevCam
            glideInProgress = false
            return
        end

        -- Check if current target is still valid, else find a new one
        local currentTargetChar = target.Character or (typeof(target) == "Instance" and target)
        if not currentTargetChar or not currentTargetChar:FindFirstChildOfClass("Humanoid")
            or currentTargetChar.Humanoid.Health <= 0 then
            local newTarget = getNearestTarget(Settings.Range, target)
            if newTarget then
                target = newTarget
                if target.Character then
                    currentTargetChar = target.Character
                elseif typeof(target) == "Instance" then
                    currentTargetChar = target
                end
                if currentTargetChar then
                    tHRP = getHRP(currentTargetChar)
                    if tHRP then
                        initialTargetCF = tHRP.CFrame
                        initialLookFlat = Vector3.new(initialTargetCF.LookVector.X, 0, initialTargetCF.LookVector.Z).Unit
                        initialRightVec = Vector3.new(initialTargetCF.RightVector.X, 0, initialTargetCF.RightVector.Z).Unit
                        local currentPos = Vector3.new(myHRP.Position.X, 0, myHRP.Position.Z)
                        local targetPos = Vector3.new(tHRP.Position.X, 0, tHRP.Position.Z)
                        local toPlayerNow = currentPos - targetPos
                        lockedSideSign = toPlayerNow:Dot(initialRightVec) >= 0 and 1 or -1
                    end
                end
            end
        end

        if not (tHRP and tHRP.Parent) then
            conn:Disconnect()
            hum.AutoRotate = true
            Camera.CameraType = prevCam
            glideInProgress = false
            return
        end

        local now   = tick()
        local dt    = now - lastHeartbeat
        lastHeartbeat = now

        local alpha = math.clamp((now - startTime) / Settings.Duration, 0, 1)

        if alpha >= 1 then
            conn:Disconnect()
            hum.AutoRotate    = true
            Camera.CameraType = prevCam
            local finalPos = getBehindPos()
            if finalPos then
                myHRP.CFrame = CFrame.new(
                    Vector3.new(finalPos.X, myHRP.Position.Y, finalPos.Z),
                    Vector3.new(tHRP.Position.X, myHRP.Position.Y, tHRP.Position.Z)
                )
            end
            glideInProgress = false
            return
        end

        local rawEnd  = getBehindPos()
        if not rawEnd then
            conn:Disconnect()
            hum.AutoRotate = true
            Camera.CameraType = prevCam
            glideInProgress = false
            return
        end

        local delta   = rawEnd - smoothedEnd
        local maxStep = MAX_DEST_SPEED * dt
        if delta.Magnitude > maxStep then
            smoothedEnd = smoothedEnd + delta.Unit * maxStep
        else
            smoothedEnd = rawEnd
        end

        local controlPos = getSideControlPoint()
        if not controlPos then
            conn:Disconnect()
            hum.AutoRotate = true
            Camera.CameraType = prevCam
            glideInProgress = false
            return
        end

        local blendedControl = Vector3.new(
            controlPos.X * (1 - alpha) + smoothedEnd.X * alpha,
            0,
            controlPos.Z * (1 - alpha) + smoothedEnd.Z * alpha
        )

        local t  = 1 - (1 - alpha)^2
        local t1 = 1 - t
        local movePos = Vector3.new(
            (t1*t1)*startPos.X + (2*t1*t)*blendedControl.X + (t*t)*smoothedEnd.X,
            myHRP.Position.Y,
            (t1*t1)*startPos.Z + (2*t1*t)*blendedControl.Z + (t*t)*smoothedEnd.Z
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
    if not ScriptEnabled or glideInProgress then return end
    fireActivated()
    task.wait(0.2)
    startCurveGlide()
end)

local function setupCharacter(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    local animator = humanoid and humanoid:WaitForChild("Animator", 5)
    if not animator then return end

    local ANIM_GLIDE_COOLDOWN = 0.6
    local lastAnimGlide       = 0

    animator.AnimationPlayed:Connect(function(track)
        if not ScriptEnabled then return end
        local animId    = track.Animation.AnimationId
        local delayTime = AnimationTriggers[animId]
        if not delayTime and StraightAnimations[animId] then delayTime = 0.19 end
        if delayTime then
            task.delay(delayTime, function()
                if not (humanoid.Health > 0 and ScriptEnabled) then return end
                local now = tick()
                if now - lastAnimGlide < ANIM_GLIDE_COOLDOWN then return end
                lastAnimGlide = now
                fireActivated()
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
    if ScriptEnabled and input.KeyCode == Enum.KeyCode.E and not glideInProgress then
        fireActivated()
        task.wait(0.2)
        startCurveGlide()
    end
end)

loadConfig()
updateSlidersFromSettings()
if pingVisualizerEnabled then
    pingToggle.Text = "ON"
    pingToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    pingToggle.BackgroundColor3 = Color3.fromRGB(0, 180, 90)
    createGhost(LocalPlayer.Character)
end
updateLockVisual()
if mobileBtnLocked then
    lockBtn.Text = "🔒 Locked"
    lockBtn.TextColor3 = Color3.fromRGB(255, 200, 50)
    lockBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 20)
end

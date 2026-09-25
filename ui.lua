-- ui.lua
-- EMS HUB ScreenGui. Patches baked in:
--   * TELEPORT tab removed
--   * AutoCollect/AutoGacha toggles removed (forced true in State)
--   * SetText hardened with pcall + .Parent guards
-- Publishes Spirit.EmsUI so core.lua's SetText wrapper can find it.

local Spirit = getgenv().Spirit
if not Spirit then error("[ui] core.lua not loaded") end

local Players      = Spirit.Players
local CoreGui      = Spirit.CoreGui
local TweenService = Spirit.TweenService
local LocalPlayer  = Spirit.LocalPlayer

-- Destroy any prior EMS UI (e.g. on script reload)
for _, container in ipairs({CoreGui, LocalPlayer:FindFirstChild("PlayerGui")}) do
    if container then
        for _, name in ipairs({"EmsHubUI"}) do
            pcall(function()
                local old = container:FindFirstChild(name)
                if old then old:Destroy() end
            end)
        end
    end
end

local EmsUI = {Instances = {}}
Spirit.EmsUI = EmsUI

-- ═══════════════════════════════════════════════════════════════
-- PALETTE
-- ═══════════════════════════════════════════════════════════════
local C = {
    panel     = Color3.fromRGB(20, 20, 24),
    card      = Color3.fromRGB(28, 28, 33),
    cardHover = Color3.fromRGB(36, 36, 42),
    border    = Color3.fromRGB(45, 45, 52),
    accent    = Color3.fromRGB(190, 230, 60),
    text      = Color3.fromRGB(228, 228, 231),
    muted     = Color3.fromRGB(130, 130, 140),
    success   = Color3.fromRGB(74, 222, 128),
    danger    = Color3.fromRGB(239, 68, 68),
    frag      = Color3.fromRGB(180, 200, 255),
    race      = Color3.fromRGB(255, 160, 210),
    beli      = Color3.fromRGB(120, 230, 120),
    melee     = Color3.fromRGB(255, 220, 120),
}

-- ═══════════════════════════════════════════════════════════════
-- ROOT
-- ═══════════════════════════════════════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name = "EmsHubUI"
gui.Parent = CoreGui
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.IgnoreGuiInset = true
EmsUI.ScreenGui = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Parent = gui
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0, 420, 0, 520)
panel.BackgroundColor3 = C.panel
panel.BorderSizePixel = 0
panel.Active = true
panel.Draggable = true
panel.ClipsDescendants = true
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

local panelBorder = Instance.new("UIStroke", panel)
panelBorder.Color = C.border
panelBorder.Thickness = 1

local panelGrad = Instance.new("UIGradient", panel)
panelGrad.Rotation = 90
panelGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 24, 28)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 16, 20)),
}
EmsUI.Panel = panel

-- ═══════════════════════════════════════════════════════════════
-- HEADER
-- ═══════════════════════════════════════════════════════════════
local header = Instance.new("Frame")
header.Parent = panel
header.Size = UDim2.new(1, 0, 0, 62)
header.BackgroundTransparency = 1

local headerLine = Instance.new("Frame")
headerLine.Parent = header
headerLine.AnchorPoint = Vector2.new(0.5, 1)
headerLine.Position = UDim2.new(0.5, 0, 1, 0)
headerLine.Size = UDim2.new(1, -32, 0, 1)
headerLine.BackgroundColor3 = C.border
headerLine.BorderSizePixel = 0

local logoDot = Instance.new("Frame")
logoDot.Parent = header
logoDot.Position = UDim2.new(0, 20, 0, 24)
logoDot.Size = UDim2.new(0, 10, 0, 10)
logoDot.BackgroundColor3 = C.accent
logoDot.BorderSizePixel = 0
Instance.new("UICorner", logoDot).CornerRadius = UDim.new(1, 0)

local glow = Instance.new("ImageLabel")
glow.Parent = logoDot
glow.AnchorPoint = Vector2.new(0.5, 0.5)
glow.Position = UDim2.new(0.5, 0, 0.5, 0)
glow.Size = UDim2.new(3, 0, 3, 0)
glow.BackgroundTransparency = 1
glow.Image = "rbxassetid://5028857084"
glow.ImageColor3 = C.accent
glow.ImageTransparency = 0.4

local title = Instance.new("TextLabel")
title.Parent = header
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 38, 0, 16)
title.Size = UDim2.new(1, -100, 0, 24)
title.Text = "EMS HUB"
title.Font = Enum.Font.FredokaOne
title.TextSize = 22
title.TextColor3 = C.text
title.TextXAlignment = Enum.TextXAlignment.Left

local subtitle = Instance.new("TextLabel")
subtitle.Parent = header
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.new(0, 39, 0, 38)
subtitle.Size = UDim2.new(1, -100, 0, 14)
subtitle.Text = "v3.0  •  BLOX FRUITS"
subtitle.Font = Enum.Font.GothamBold
subtitle.TextSize = 9
subtitle.TextColor3 = C.muted
subtitle.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton")
closeBtn.Parent = header
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, -16, 0, 20)
closeBtn.Size = UDim2.new(0, 22, 0, 22)
closeBtn.BackgroundColor3 = C.card
closeBtn.Text = "×"
closeBtn.TextColor3 = C.muted
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.BorderSizePixel = 0
closeBtn.AutoButtonColor = false
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
closeBtn.MouseEnter:Connect(function()
    closeBtn.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
    closeBtn.TextColor3 = C.danger
end)
closeBtn.MouseLeave:Connect(function()
    closeBtn.BackgroundColor3 = C.card
    closeBtn.TextColor3 = C.muted
end)
closeBtn.MouseButton1Click:Connect(function() panel.Visible = false end)

local minBtn = Instance.new("TextButton")
minBtn.Parent = header
minBtn.AnchorPoint = Vector2.new(1, 0)
minBtn.Position = UDim2.new(1, -44, 0, 20)
minBtn.Size = UDim2.new(0, 22, 0, 22)
minBtn.BackgroundColor3 = C.card
minBtn.Text = "—"
minBtn.TextColor3 = C.muted
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 12
minBtn.BorderSizePixel = 0
minBtn.AutoButtonColor = false
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)
minBtn.MouseEnter:Connect(function() minBtn.BackgroundColor3 = C.cardHover end)
minBtn.MouseLeave:Connect(function() minBtn.BackgroundColor3 = C.card end)
minBtn.MouseButton1Click:Connect(function() panel.Visible = false end)

-- ═══════════════════════════════════════════════════════════════
-- TAB BAR + CONTENT AREA
-- ═══════════════════════════════════════════════════════════════
local tabBar = Instance.new("Frame")
tabBar.Parent = panel
tabBar.Position = UDim2.new(0, 16, 0, 70)
tabBar.Size = UDim2.new(1, -32, 0, 34)
tabBar.BackgroundTransparency = 1
local tabLayout = Instance.new("UIListLayout", tabBar)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Padding = UDim.new(0, 6)

local content = Instance.new("Frame")
content.Parent = panel
content.Position = UDim2.new(0, 16, 0, 116)
content.Size = UDim2.new(1, -32, 1, -180)
content.BackgroundTransparency = 1
content.ClipsDescendants = true

local footer = Instance.new("TextLabel")
footer.Parent = panel
footer.AnchorPoint = Vector2.new(0.5, 1)
footer.Position = UDim2.new(0.5, 0, 1, -12)
footer.Size = UDim2.new(1, -32, 0, 16)
footer.BackgroundTransparency = 1
footer.Text = "discord.gg/EmsHub"
footer.Font = Enum.Font.GothamBold
footer.TextSize = 11
footer.TextColor3 = C.muted
footer.TextXAlignment = Enum.TextXAlignment.Center

local footSep = Instance.new("Frame")
footSep.Parent = panel
footSep.AnchorPoint = Vector2.new(0.5, 1)
footSep.Position = UDim2.new(0.5, 0, 1, -34)
footSep.Size = UDim2.new(1, -32, 0, 1)
footSep.BackgroundColor3 = C.border
footSep.BorderSizePixel = 0

-- ═══════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════
local function makeCard(parent, size, pos)
    local card = Instance.new("Frame")
    card.Parent = parent
    card.Size = size
    card.Position = pos
    card.BackgroundColor3 = C.card
    card.BorderSizePixel = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", card)
    stroke.Color = C.border
    stroke.Thickness = 1
    return card
end

local TABS = {}
local activeTab = nil
local contentPages = {}

local function makeTab(id, label, order)
    local btn = Instance.new("TextButton")
    btn.Parent = tabBar
    btn.LayoutOrder = order
    btn.Size = UDim2.new(0, 180, 1, 0)
    btn.BackgroundColor3 = C.card
    btn.Text = label
    btn.TextColor3 = C.muted
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = C.border
    stroke.Thickness = 1
    stroke.Transparency = 1

    local page = Instance.new("ScrollingFrame")
    page.Name = id
    page.Parent = content
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = C.accent
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false

    contentPages[id] = page
    TABS[id] = {btn = btn, page = page, stroke = stroke}

    btn.MouseEnter:Connect(function()
        if activeTab ~= id then btn.BackgroundColor3 = C.cardHover end
    end)
    btn.MouseLeave:Connect(function()
        if activeTab ~= id then btn.BackgroundColor3 = C.card end
    end)
    btn.MouseButton1Click:Connect(function()
        for tid, tdata in pairs(TABS) do
            tdata.page.Visible = false
            tdata.btn.BackgroundColor3 = C.card
            tdata.btn.TextColor3 = C.muted
            tdata.stroke.Transparency = 1
        end
        activeTab = id
        TABS[id].page.Visible = true
        TABS[id].btn.BackgroundColor3 = C.cardHover
        TABS[id].btn.TextColor3 = C.accent
        TABS[id].stroke.Color = C.accent
        TABS[id].stroke.Transparency = 0
    end)
end

-- [PATCH 2] TELEPORT tab removed
makeTab("home", "HOME", 1)
makeTab("settings", "SETTINGS", 2)

activeTab = "home"
TABS.home.page.Visible = true
TABS.home.btn.BackgroundColor3 = C.cardHover
TABS.home.btn.TextColor3 = C.accent
TABS.home.stroke.Color = C.accent
TABS.home.stroke.Transparency = 0

-- ═══════════════════════════════════════════════════════════════
-- HOME TAB
-- ═══════════════════════════════════════════════════════════════
local homePage = contentPages.home
local homeLayout = Instance.new("UIListLayout", homePage)
homeLayout.Padding = UDim.new(0, 10)
homeLayout.SortOrder = Enum.SortOrder.LayoutOrder

local statusCard = makeCard(homePage, UDim2.new(1, -4, 0, 48), UDim2.new(0, 0, 0, 0))
statusCard.LayoutOrder = 1

local statusDot = Instance.new("Frame")
statusDot.Parent = statusCard
statusDot.Position = UDim2.new(0, 14, 0, 19)
statusDot.Size = UDim2.new(0, 10, 0, 10)
statusDot.BackgroundColor3 = C.success
statusDot.BorderSizePixel = 0
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

local pulse = Instance.new("ImageLabel")
pulse.Parent = statusDot
pulse.AnchorPoint = Vector2.new(0.5, 0.5)
pulse.Position = UDim2.new(0.5, 0, 0.5, 0)
pulse.Size = UDim2.new(3, 0, 3, 0)
pulse.BackgroundTransparency = 1
pulse.Image = "rbxassetid://5028857084"
pulse.ImageColor3 = C.success
pulse.ImageTransparency = 0.5

local statusText = Instance.new("TextLabel")
statusText.Parent = statusCard
statusText.BackgroundTransparency = 1
statusText.Position = UDim2.new(0, 34, 0, 6)
statusText.Size = UDim2.new(1, -50, 0, 18)
statusText.Text = "Idle"
statusText.Font = Enum.Font.GothamBold
statusText.TextSize = 12
statusText.TextColor3 = C.text
statusText.TextXAlignment = Enum.TextXAlignment.Left
statusText.TextTruncate = Enum.TextTruncate.AtEnd

local subStatusText = Instance.new("TextLabel")
subStatusText.Parent = statusCard
subStatusText.BackgroundTransparency = 1
subStatusText.Position = UDim2.new(0, 34, 0, 24)
subStatusText.Size = UDim2.new(1, -50, 0, 16)
subStatusText.Text = "Waiting..."
subStatusText.Font = Enum.Font.Gotham
subStatusText.TextSize = 10
subStatusText.TextColor3 = C.muted
subStatusText.TextXAlignment = Enum.TextXAlignment.Left
subStatusText.TextTruncate = Enum.TextTruncate.AtEnd

EmsUI.StatusLabel = statusText
EmsUI.SubStatusLabel = subStatusText

local statsGrid = Instance.new("Frame")
statsGrid.Parent = homePage
statsGrid.LayoutOrder = 2
statsGrid.Size = UDim2.new(1, -4, 0, 180)
statsGrid.BackgroundTransparency = 1
local gridLayout = Instance.new("UIGridLayout", statsGrid)
gridLayout.CellSize = UDim2.new(0.5, -5, 0, 52)
gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function makeStatCard(label, initial, color, order)
    local card = Instance.new("Frame")
    card.Parent = statsGrid
    card.LayoutOrder = order
    card.BackgroundColor3 = C.card
    card.BorderSizePixel = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", card)
    stroke.Color = C.border
    stroke.Thickness = 1

    local lbl = Instance.new("TextLabel")
    lbl.Parent = card
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 12, 0, 6)
    lbl.Size = UDim2.new(1, -24, 0, 14)
    lbl.Text = label
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 9
    lbl.TextColor3 = C.muted
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local val = Instance.new("TextLabel")
    val.Parent = card
    val.BackgroundTransparency = 1
    val.Position = UDim2.new(0, 12, 0, 22)
    val.Size = UDim2.new(1, -24, 0, 22)
    val.Text = initial
    val.Font = Enum.Font.GothamBold
    val.TextSize = 15
    val.TextColor3 = color
    val.TextXAlignment = Enum.TextXAlignment.Left
    val.TextTruncate = Enum.TextTruncate.AtEnd
    return val
end

EmsUI.LevelLabel = makeStatCard("LEVEL",    "0",        C.text,  1)
EmsUI.BeliLabel  = makeStatCard("BELI",     "$0",       C.beli,  2)
EmsUI.FragLabel  = makeStatCard("FRAGMENT", "[0]",      C.frag,  3)
EmsUI.RaceLabel  = makeStatCard("RACE",     "Unknown",  C.race,  4)
EmsUI.MeleeLabel = makeStatCard("MELEE",    "[0]",      C.melee, 5)
EmsUI.TimerLabel = makeStatCard("UPTIME",   "0h 0m 0s", C.text,  6)

local toggleSection = Instance.new("Frame")
toggleSection.Parent = homePage
toggleSection.LayoutOrder = 3
toggleSection.Size = UDim2.new(1, -4, 0, 0)
toggleSection.AutomaticSize = Enum.AutomaticSize.Y
toggleSection.BackgroundTransparency = 1
local toggleLayout = Instance.new("UIListLayout", toggleSection)
toggleLayout.Padding = UDim.new(0, 6)
toggleLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- [PATCH 3] AutoCollect/AutoGacha forced true, toggles removed from UI
local State = {
    Noclip = true,
    AutoCollect = true,
    AutoGacha = true,
    AutoKatakuri = false,
}
EmsUI.State = State

local function makeToggleRow(label, getter, setter, order)
    local row = Instance.new("Frame")
    row.Parent = toggleSection
    row.LayoutOrder = order
    row.Size = UDim2.new(1, 0, 0, 40)
    row.BackgroundColor3 = C.card
    row.BorderSizePixel = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", row)
    stroke.Color = C.border
    stroke.Thickness = 1

    local lbl = Instance.new("TextLabel")
    lbl.Parent = row
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.Size = UDim2.new(1, -80, 1, 0)
    lbl.Text = label
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextColor3 = C.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local sw = Instance.new("Frame")
    sw.Parent = row
    sw.AnchorPoint = Vector2.new(1, 0.5)
    sw.Position = UDim2.new(1, -12, 0.5, 0)
    sw.Size = UDim2.new(0, 38, 0, 20)
    sw.BackgroundColor3 = Color3.fromRGB(50, 50, 56)
    sw.BorderSizePixel = 0
    Instance.new("UICorner", sw).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Parent = sw
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.Position = UDim2.new(0, 2, 0.5, 0)
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.BackgroundColor3 = Color3.fromRGB(180, 180, 190)
    knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local function refresh(animate)
        local on = getter()
        local kp = on and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
        local sc = on and C.accent or Color3.fromRGB(50, 50, 56)
        local kc = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 190)
        if animate then
            TweenService:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = kp, BackgroundColor3 = kc}):Play()
            TweenService:Create(sw, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = sc}):Play()
        else
            knob.Position = kp
            knob.BackgroundColor3 = kc
            sw.BackgroundColor3 = sc
        end
    end
    refresh(false)

    local btn = Instance.new("TextButton")
    btn.Parent = row
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 5
    btn.MouseButton1Click:Connect(function()
        setter(not getter())
        refresh(true)
    end)

    row.MouseEnter:Connect(function() row.BackgroundColor3 = C.cardHover end)
    row.MouseLeave:Connect(function() row.BackgroundColor3 = C.card end)
end

-- [PATCH 3] Only Noclip + Auto Katakuri survive
makeToggleRow("Noclip",        function() return State.Noclip end,       function(v) State.Noclip = v end, 1)
makeToggleRow("Auto Katakuri", function() return State.AutoKatakuri end, function(v) State.AutoKatakuri = v end, 2)

-- ═══════════════════════════════════════════════════════════════
-- SETTINGS TAB
-- ═══════════════════════════════════════════════════════════════
local setPage = contentPages.settings
local setLayout = Instance.new("UIListLayout", setPage)
setLayout.Padding = UDim.new(0, 10)
setLayout.SortOrder = Enum.SortOrder.LayoutOrder

local infoCard = makeCard(setPage, UDim2.new(1, -4, 0, 90), UDim2.new(0, 0, 0, 0))
infoCard.LayoutOrder = 1

local infoTitle = Instance.new("TextLabel")
infoTitle.Parent = infoCard
infoTitle.BackgroundTransparency = 1
infoTitle.Position = UDim2.new(0, 14, 0, 10)
infoTitle.Size = UDim2.new(1, -28, 0, 16)
infoTitle.Text = "ABOUT"
infoTitle.Font = Enum.Font.GothamBold
infoTitle.TextSize = 10
infoTitle.TextColor3 = C.muted
infoTitle.TextXAlignment = Enum.TextXAlignment.Left

local infoBody = Instance.new("TextLabel")
infoBody.Parent = infoCard
infoBody.BackgroundTransparency = 1
infoBody.Position = UDim2.new(0, 14, 0, 30)
infoBody.Size = UDim2.new(1, -28, 0, 50)
infoBody.Text = "Ems Hub v3.0\nBlox Fruits automation\nRedeem • Farm • Teleport"
infoBody.Font = Enum.Font.GothamBold
infoBody.TextSize = 11
infoBody.TextColor3 = C.text
infoBody.TextXAlignment = Enum.TextXAlignment.Left
infoBody.TextYAlignment = Enum.TextYAlignment.Top

local redeemCard = makeCard(setPage, UDim2.new(1, -4, 0, 46), UDim2.new(0, 0, 0, 0))
redeemCard.LayoutOrder = 2

local rsTitle = Instance.new("TextLabel")
rsTitle.Parent = redeemCard
rsTitle.BackgroundTransparency = 1
rsTitle.Position = UDim2.new(0, 14, 0, 6)
rsTitle.Size = UDim2.new(1, -28, 0, 14)
rsTitle.Text = "AUTO REDEEM"
rsTitle.Font = Enum.Font.GothamBold
rsTitle.TextSize = 9
rsTitle.TextColor3 = C.muted
rsTitle.TextXAlignment = Enum.TextXAlignment.Left

local rsBody = Instance.new("TextLabel")
rsBody.Parent = redeemCard
rsBody.BackgroundTransparency = 1
rsBody.Position = UDim2.new(0, 14, 0, 22)
rsBody.Size = UDim2.new(1, -28, 0, 18)
rsBody.Text = "Waiting to start..."
rsBody.Font = Enum.Font.GothamBold
rsBody.TextSize = 12
rsBody.TextColor3 = C.text
rsBody.TextXAlignment = Enum.TextXAlignment.Left
rsBody.TextTruncate = Enum.TextTruncate.AtEnd
EmsUI.RedeemStatus = rsBody

-- ═══════════════════════════════════════════════════════════════
-- FLOATING TOGGLE BUTTON
-- ═══════════════════════════════════════════════════════════════
local floatBtn = Instance.new("TextButton")
floatBtn.Name = "EmsFloat"
floatBtn.Parent = gui
floatBtn.Size = UDim2.new(0, 48, 0, 48)
floatBtn.AnchorPoint = Vector2.new(0, 0.5)
floatBtn.Position = UDim2.new(0, 15, 0.5, -24)
floatBtn.BackgroundColor3 = C.panel
floatBtn.Text = "E"
floatBtn.TextColor3 = C.accent
floatBtn.Font = Enum.Font.FredokaOne
floatBtn.TextSize = 22
floatBtn.BorderSizePixel = 0
floatBtn.Draggable = true
floatBtn.Active = true
floatBtn.ZIndex = 100
Instance.new("UICorner", floatBtn).CornerRadius = UDim.new(1, 0)
local fbStroke = Instance.new("UIStroke", floatBtn)
fbStroke.Color = C.accent
fbStroke.Thickness = 1.5
floatBtn.MouseButton1Click:Connect(function() panel.Visible = not panel.Visible end)
floatBtn.MouseEnter:Connect(function()
    TweenService:Create(floatBtn, TweenInfo.new(0.15), {BackgroundColor3 = C.cardHover}):Play()
end)
floatBtn.MouseLeave:Connect(function()
    TweenService:Create(floatBtn, TweenInfo.new(0.15), {BackgroundColor3 = C.panel}):Play()
end)

-- ═══════════════════════════════════════════════════════════════
-- PUBLIC API (PATCHED SetText)
-- ═══════════════════════════════════════════════════════════════
function EmsUI.SetText(key, text)
    if text == nil then return end
    pcall(function()
        local safeText = tostring(text):gsub("<[^>]->", "")
        if key == "MainTextLabel" or key == "Task1" or key == "DebugLine" then
            if statusText and statusText.Parent then statusText.Text = safeText end
        elseif key == "Task2" then
            if subStatusText and subStatusText.Parent then subStatusText.Text = safeText end
        elseif key == "LiveTime" then
            if EmsUI.TimerLabel and EmsUI.TimerLabel.Parent then
                EmsUI.TimerLabel.Text = safeText
            end
        elseif key == "Melees" then
            if EmsUI.MeleeLabel and EmsUI.MeleeLabel.Parent then
                EmsUI.MeleeLabel.Text = "[" .. (safeText:match("%d+") or "0") .. "]"
            end
        elseif key == "Currencies" then
            if statusText and statusText.Parent then statusText.Text = safeText end
        end
    end)
end

function EmsUI.SetStatus(text)
    if not text then return end
    pcall(function()
        if statusText and statusText.Parent then
            statusText.Text = tostring(text)
        end
    end)
end

function EmsUI.SetSubStatus(text)
    if not text then return end
    pcall(function()
        if subStatusText and subStatusText.Parent then
            subStatusText.Text = tostring(text)
        end
    end)
end

function EmsUI.SetRedeemStatus(text)
    if not text then return end
    pcall(function()
        if rsBody and rsBody.Parent then
            rsBody.Text = tostring(text)
        end
    end)
end

function EmsUI.Toggle()
    panel.Visible = not panel.Visible
end

function EmsUI.SetStats(data)
    if not data then return end
    pcall(function()
        if data.Level and EmsUI.LevelLabel and EmsUI.LevelLabel.Parent then
            EmsUI.LevelLabel.Text = tostring(data.Level)
        end
        if data.Beli and EmsUI.BeliLabel and EmsUI.BeliLabel.Parent then
            local b = tonumber(data.Beli) or 0
            local s
            if b >= 1e9 then s = string.format("$%.2fB", b / 1e9)
            elseif b >= 1e6 then s = string.format("$%.2fM", b / 1e6)
            elseif b >= 1e3 then s = string.format("$%.1fK", b / 1e3)
            else s = "$" .. tostring(b) end
            EmsUI.BeliLabel.Text = s
        end
        if data.Fragments and EmsUI.FragLabel and EmsUI.FragLabel.Parent then
            EmsUI.FragLabel.Text = "[" .. tostring(data.Fragments) .. "]"
        end
        if data.Race and EmsUI.RaceLabel and EmsUI.RaceLabel.Parent then
            EmsUI.RaceLabel.Text = tostring(data.Race)
        end
        if data.Melee and EmsUI.MeleeLabel and EmsUI.MeleeLabel.Parent then
            EmsUI.MeleeLabel.Text = "[" .. tostring(data.Melee) .. "]"
        end
        if data.Elapsed and EmsUI.TimerLabel and EmsUI.TimerLabel.Parent then
            local h = math.floor(data.Elapsed / 3600)
            local m = math.floor((data.Elapsed % 3600) / 60)
            local s = math.floor(data.Elapsed % 60)
            EmsUI.TimerLabel.Text = string.format("%dh %dm %ds", h, m, s)
        end
    end)
end

-- Bind global helpers (used by other modules via Spirit.SetText / _G.SetText)
_G.EmsUI = EmsUI
getgenv().EmsUI = EmsUI

-- ═══════════════════════════════════════════════════════════════
-- LIVE STATS REFRESH
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    local start = os.time() - (Spirit.OldSessionTime or 0)
    while task.wait(1) do
        pcall(function()
            local Data = LocalPlayer:FindFirstChild("Data")
            if not Data then return end

            local level = Data:FindFirstChild("Level") and Data.Level.Value or 0
            local beli  = Data:FindFirstChild("Beli")  and Data.Beli.Value  or 0
            local frag  = Data:FindFirstChild("Fragments") and Data.Fragments.Value or 0

            local raceName = "Unknown"
            local raceObj = Data:FindFirstChild("Race")
            if raceObj then
                if raceObj:IsA("StringValue") then
                    raceName = raceObj.Value
                elseif raceObj:IsA("Folder") then
                    local v = raceObj:FindFirstChild("Value")
                    if v then raceName = v.Value end
                end
            end

            local melee = 0
            local sf = Data:FindFirstChild("Stats")
            if sf and sf:FindFirstChild("Melee") then
                local m = sf.Melee
                melee = m:FindFirstChild("Level") and m.Level.Value or m.Value or 0
            end

            EmsUI.SetStats({
                Level = level,
                Beli = beli,
                Fragments = frag,
                Race = raceName,
                Melee = melee,
                Elapsed = os.time() - start,
            })
        end)
    end
end)

-- Publish to Spirit so core.SetText wrapper finds us
Spirit.EmsUI = EmsUI
Spirit.__ui_ready = true
print("[Spirit] ui.lua loaded")

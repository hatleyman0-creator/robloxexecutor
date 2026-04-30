-- DeltaHub.lua
-- Premium Delta Executor Hub (PURE Lua, client-side)
-- Designed for Delta Executor / Roblox executor environments
-- Author: Generated scaffold (highly modular, visually polished UI)

-- CONFIG
local KEY_CODE = "harley" -- correct key
local GUI_NAME = "DeltaHubGUI_v1"
local SAVE_FOLDER = "DeltaHubData"
local SCRIPTS_SAVE_FILE = "DeltaHub_saved_scripts.json"
local CONFIG_FILE = "DeltaHub_config.json"

-- SERVICES
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")

-- UTILITIES -------------------------------------------------------------
local function safeCall(fn, ...)
    local ok, res = pcall(fn, ...)
    return ok, res
end

local function new(class, props)
    local inst = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            pcall(function() inst[k] = v end)
        end
    end
    return inst
end

local easingMap = {
    quad = Enum.EasingStyle.Quad,
    cubic = Enum.EasingStyle.Cubic,
    quart = Enum.EasingStyle.Quart,
    quint = Enum.EasingStyle.Quint,
    sine = Enum.EasingStyle.Sine,
    back = Enum.EasingStyle.Back,
    elastic = Enum.EasingStyle.Elastic,
    bounce = Enum.EasingStyle.Bounce,
}

local function Tween(inst, props, time, style, dir)
    time = time or 0.36
    style = easingMap[style] or Enum.EasingStyle.Sine
    dir = dir or Enum.EasingDirection.Out
    local info = TweenInfo.new(time, style, dir)
    local t = TweenService:Create(inst, info, props)
    t:Play()
    return t
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local safeLoad = loadstring or load
local function executeCode(code)
    if type(code) ~= "string" then
        return false, "Code must be a string"
    end
    local fn, err = safeLoad(code)
    if not fn then
        return false, err
    end
    return pcall(fn)
end

-- Basic helpers for file-based persistence (exploiter functions if available)
local function writeJSON(path, tbl)
    local ok, json = pcall(function() return HttpService:JSONEncode(tbl) end)
    if not ok then return false end
    if writefile then
        pcall(function() if not isfolder then makefolder(SAVE_FOLDER) end end)
        local full = SAVE_FOLDER .. "/" .. path
        pcall(function() writefile(full, json) end)
        return true
    end
    return false
end

local function readJSON(path)
    if readfile then
        local full = SAVE_FOLDER .. "/" .. path
        if not isfile(full) then return nil end
        local ok, content = pcall(function() return readfile(full) end)
        if not ok then return nil end
        local ok2, tbl = pcall(function() return HttpService:JSONDecode(content) end)
        if ok2 then return tbl end
    end
    return nil
end

-- UI BUILDERS ----------------------------------------------------------
local function applyCorner(inst, radius)
    local corn = new("UICorner")
    corn.CornerRadius = UDim.new(0, radius or 8)
    corn.Parent = inst
end

local function applyStroke(inst, color, thickness, transparency)
    local s = new("UIStroke")
    s.Color = color or Color3.fromRGB(100,160,255)
    s.Thickness = thickness or 1.5
    s.Transparency = transparency or 0
    s.Parent = inst
end

local function applyGradient(inst, color1, color2)
    local g = new("UIGradient")
    g.Color = ColorSequence.new(color1 or Color3.fromRGB(35,120,255), color2 or Color3.fromRGB(95,175,255))
    g.Parent = inst
end

local function makeGlow(inst, color)
    local gl = new("ImageLabel")
    gl.Name = "Glow"
    gl.AnchorPoint = Vector2.new(0.5, 0.5)
    gl.Size = UDim2.new(1.45, 0, 1.45, 0)
    gl.Position = UDim2.new(0.5, 0, 0.5, 0)
    gl.BackgroundTransparency = 1
    gl.Image = "rbxasset://textures/particles/sparkles_main.dds"
    gl.ImageColor3 = color or Color3.fromRGB(120,180,255)
    gl.ImageTransparency = 0.8
    gl.ZIndex = inst.ZIndex - 1
    gl.Parent = inst
    return gl
end

-- Ripple click effect
local function rippleAt(parent, position, color)
    local r = new("Frame")
    r.Size = UDim2.new(0, 12, 0, 12)
    r.AnchorPoint = Vector2.new(0.5, 0.5)
    r.Position = UDim2.new(0, position.X, 0, position.Y)
    r.BackgroundColor3 = color or Color3.fromRGB(190,225,255)
    r.BackgroundTransparency = 0.2
    applyCorner(r, 999)
    r.ZIndex = parent.ZIndex + 5
    r.Parent = parent
    Tween(r, {Size = UDim2.new(0, 220, 0, 220), BackgroundTransparency = 1}, 0.6, "sine")
    delay(0.7, function() pcall(function() r:Destroy() end) end)
end

-- Notification manager -------------------------------------------------
local NotificationManager = {}
NotificationManager.queue = {}
NotificationManager.frame = nil

function NotificationManager:init(guiParent)
    local screen = guiParent
    local container = new("Frame")
    container.Name = "Delta_Notifications"
    container.AnchorPoint = Vector2.new(1, 0)
    container.Position = UDim2.new(1, -20, 0, 20)
    container.Size = UDim2.new(0, 360, 0, 140)
    container.BackgroundTransparency = 1
    container.ClipsDescendants = false
    container.Parent = screen

    local layout = new("UIListLayout")
    layout.Parent = container
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 10)

    self.frame = container
end

function NotificationManager:push(opts)
    opts = opts or {}
    local typ = opts.type or "info" -- success, error, info
    local title = opts.title or "Notification"
    local text = opts.text or ""
    local duration = opts.duration or 4
    local color = typ == "success" and Color3.fromRGB(118, 219, 83) or typ == "error" and Color3.fromRGB(255,95,95) or Color3.fromRGB(100,160,255)

    local card = new("Frame")
    card.Size = UDim2.new(0, 340, 0, 64)
    card.BackgroundTransparency = 0.06
    card.BackgroundColor3 = Color3.fromRGB(10, 20, 40)
    applyCorner(card, 12)
    applyStroke(card, color, 1.6, 0)
    card.Parent = self.frame
    card.LayoutOrder = #self.queue + 1

    local left = new("Frame")
    left.Size = UDim2.new(0, 6, 1, 0)
    left.Position = UDim2.new(0, 10, 0, 6)
    left.BackgroundColor3 = color
    applyCorner(left, 4)
    left.Parent = card

    local titleLbl = new("TextLabel")
    titleLbl.Text = title
    titleLbl.TextColor3 = Color3.fromRGB(235,235,235)
    titleLbl.TextSize = 14
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.BackgroundTransparency = 1
    titleLbl.Position = UDim2.new(0, 30, 0, 8)
    titleLbl.Size = UDim2.new(1, -36, 0, 20)
    titleLbl.Parent = card

    local body = new("TextLabel")
    body.Text = text
    body.TextColor3 = Color3.fromRGB(200,200,210)
    body.TextSize = 13
    body.Font = Enum.Font.Gotham
    body.BackgroundTransparency = 1
    body.Position = UDim2.new(0, 30, 0, 28)
    body.Size = UDim2.new(1, -36, 0, 28)
    body.TextWrapped = true
    body.Parent = card

    card.Position = UDim2.new(1, 380, 0, 0)
    Tween(card, {Position = UDim2.new(1, -360, 0, (self.frame:GetChildren() and #self.frame:GetChildren()*72 or 0))}, 0.42, "sine")

    table.insert(self.queue, card)
    delay(duration, function()
        if card and card.Parent then
            Tween(card, {Position = UDim2.new(1, 380, 0, 0)}, 0.36)
            delay(0.36, function() pcall(function() card:Destroy() end) end)
        end
    end)
end

-- Simple theme/config manager ------------------------------------------
local Theme = {
    primary = Color3.fromRGB(24, 110, 255),
    secondary = Color3.fromRGB(66, 170, 255),
    uiAccent = Color3.fromRGB(100,160,255),
    glass = Color3.fromRGB(9,18,32),
}

local ConfigManager = {}
function ConfigManager:save()
    local ok = writeJSON(CONFIG_FILE, Theme)
    return ok
end
function ConfigManager:load()
    local t = readJSON(CONFIG_FILE)
    if t then
        for k,v in pairs(t) do Theme[k] = v end
    end
end

-- AUTHENTICATION UI ----------------------------------------------------
local function buildAuthScreen(guiParent, onSuccess)
    local screen = guiParent

    local overlay = new("Frame")
    overlay.Name = "Delta_AuthOverlay"
    overlay.Size = UDim2.new(1,0,1,0)
    overlay.BackgroundColor3 = Color3.fromRGB(6,12,18)
    overlay.BackgroundTransparency = 0.45
    overlay.Parent = screen

    local blur = Instance.new("BlurEffect")
    blur.Parent = Lighting
    blur.Size = 0

    local panel = new("Frame")
    panel.Name = "AuthPanel"
    panel.Size = UDim2.new(0, 430, 0, 520)
    panel.Position = UDim2.new(0.5,0,0.5,0)
    panel.AnchorPoint = Vector2.new(0.5,0.5)
    panel.BackgroundTransparency = 0.05
    panel.BackgroundColor3 = Theme.glass
    panel.Parent = overlay
    applyCorner(panel, 20)
    applyGradient(panel, Theme.primary, Theme.secondary)
    applyStroke(panel, Theme.uiAccent, 1.6)

    local topCircle = new("Frame")
    topCircle.Size = UDim2.new(0, 120, 0, 120)
    topCircle.Position = UDim2.new(0.5, 0, 0, 28)
    topCircle.AnchorPoint = Vector2.new(0.5, 0)
    topCircle.BackgroundTransparency = 0.03
    topCircle.BackgroundColor3 = Color3.fromRGB(14,32,60)
    applyCorner(topCircle, 60)
    topCircle.Parent = panel
    local icon = new("TextLabel")
    icon.Text = "📷"
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 46
    icon.TextColor3 = Color3.fromRGB(230,240,255)
    icon.BackgroundTransparency = 1
    icon.Size = UDim2.new(1,0,1,0)
    icon.Parent = topCircle

    local title = new("TextLabel")
    title.Text = "Delta Executor"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.TextColor3 = Color3.fromRGB(240,240,255)
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0.5,0,0,162)
    title.AnchorPoint = Vector2.new(0.5,0)
    title.Parent = panel

    -- Inputs
    local inputsHolder = new("Frame")
    inputsHolder.Size = UDim2.new(1, -60, 0, 180)
    inputsHolder.Position = UDim2.new(0, 30, 0, 200)
    inputsHolder.BackgroundTransparency = 1
    inputsHolder.Parent = panel

    local username = new("TextBox")
    username.PlaceholderText = "Username"
    username.Text = LocalPlayer and (LocalPlayer.DisplayName or LocalPlayer.Name) or "User"
    username.Size = UDim2.new(1, 0, 0, 44)
    username.BackgroundColor3 = Color3.fromRGB(8,18,32)
    username.TextColor3 = Color3.fromRGB(235,235,235)
    username.Font = Enum.Font.Gotham
    username.TextSize = 14
    username.ClearTextOnFocus = false
    applyCorner(username, 8)
    username.Parent = inputsHolder
    applyStroke(username, Color3.fromRGB(70,120,200), 1)

    local keyInput = new("TextBox")
    keyInput.PlaceholderText = "Enter key..."
    keyInput.Text = ""
    keyInput.Size = UDim2.new(1, 0, 0, 44)
    keyInput.Position = UDim2.new(0, 0, 0, 54)
    keyInput.BackgroundColor3 = Color3.fromRGB(8,18,32)
    keyInput.TextColor3 = Color3.fromRGB(235,235,235)
    keyInput.Font = Enum.Font.Gotham
    keyInput.TextSize = 14
    keyInput.ClearTextOnFocus = false
    keyInput.TextEditable = true
    applyCorner(keyInput, 8)
    keyInput.Parent = inputsHolder
    applyStroke(keyInput, Color3.fromRGB(70,120,200), 1)
    keyInput.TextScaled = false

    local pasteBtn = new("TextButton")
    pasteBtn.Text = "Paste"
    pasteBtn.Font = Enum.Font.Gotham
    pasteBtn.TextSize = 12
    pasteBtn.Size = UDim2.new(0, 68, 0, 36)
    pasteBtn.Position = UDim2.new(1, -74, 0, 54)
    pasteBtn.AnchorPoint = Vector2.new(1, 0)
    applyCorner(pasteBtn, 8)
    pasteBtn.BackgroundColor3 = Color3.fromRGB(22,44,80)
    pasteBtn.TextColor3 = Color3.fromRGB(220,240,255)
    pasteBtn.Parent = inputsHolder

    local remember = new("TextButton")
    remember.Size = UDim2.new(0, 120, 0, 22)
    remember.Position = UDim2.new(0, 0, 0, 108)
    remember.Text = "Remember me"
    remember.Font = Enum.Font.Gotham
    remember.TextSize = 12
    remember.BackgroundTransparency = 1
    remember.TextColor3 = Color3.fromRGB(200,205,220)
    remember.Parent = inputsHolder

    local loginBtn = new("TextButton")
    loginBtn.Text = "LOGIN"
    loginBtn.Font = Enum.Font.GothamBold
    loginBtn.TextSize = 16
    loginBtn.TextColor3 = Color3.fromRGB(245,245,245)
    loginBtn.Size = UDim2.new(1, 0, 0, 44)
    loginBtn.Position = UDim2.new(0, 0, 0, 140)
    loginBtn.BackgroundColor3 = Theme.primary
    applyCorner(loginBtn, 8)
    loginBtn.Parent = inputsHolder

    -- Loading spinner
    local spinner = new("Frame")
    spinner.Size = UDim2.new(0, 32, 0, 32)
    spinner.Position = UDim2.new(0.5, -16, 0, 200)
    spinner.AnchorPoint = Vector2.new(0.5, 0)
    spinner.BackgroundTransparency = 1
    spinner.Parent = panel

    local spinnerImg = new("ImageLabel")
    spinnerImg.Size = UDim2.new(1, 0, 1, 0)
    spinnerImg.BackgroundTransparency = 1
    spinnerImg.Image = "rbxassetid://241837157" -- small gear placeholder
    spinnerImg.ImageColor3 = Color3.fromRGB(190,220,255)
    spinnerImg.Parent = spinner
    spinner.Visible = false

    -- Animations: fade in
    panel.Position = UDim2.new(0.5, 0, 0.5, 40)
    panel.BackgroundTransparency = 1
    Tween(panel, {BackgroundTransparency = 0.05, Position = UDim2.new(0.5, 0, 0.5, 0)}, 0.6)
    Tween(blur, {Size = 6}, 0.5)

    local function showError()
        -- red flash + shake + notification
        applyStroke(panel, Color3.fromRGB(235, 80, 80), 2.3)
        local start = panel.Position
        for i = 1, 6 do
            Tween(panel, {Position = start + UDim2.new(0, (i % 2 == 0 and 6 or -6), 0, 0)}, 0.04)
            wait(0.04)
        end
        Tween(panel, {Position = start}, 0.12)
        applyStroke(panel, Theme.uiAccent, 1.6)
        NotificationManager:push({type = "error", title = "Wrong Key", text = "The key you entered is incorrect."})
    end

    local function showSuccess()
        applyStroke(panel, Color3.fromRGB(80, 230, 130), 2)
        Tween(panel, {BackgroundTransparency = 0.18}, 0.18)
        NotificationManager:push({type = "success", title = "Correct Key", text = "Welcome — loading hub..."})
        spinner.Visible = true
        Tween(spinnerImg, {Rotation = 360}, 1, "sine")
        delay(0.8, function()
            -- unload
            Tween(panel, {Position = UDim2.new(0.5, 0, 0.5, -600), BackgroundTransparency = 1}, 0.5)
            Tween(overlay, {BackgroundTransparency = 1}, 0.5)
            Tween(blur, {Size = 0}, 0.5)
            delay(0.6, function()
                pcall(function() overlay:Destroy() end)
                pcall(function() blur:Destroy() end)
                if onSuccess then pcall(onSuccess) end
            end)
        end)
    end

    local function validate()
        local key = tostring(keyInput.Text or "")
        if key:lower() == KEY_CODE:lower() then
            showSuccess()
        else
            showError()
        end
    end

    pasteBtn.MouseButton1Click:Connect(function()
        if type(getclipboard) == "function" then
            local ok, cl = pcall(getclipboard)
            if ok and cl then keyInput.Text = tostring(cl) end
        elseif type(clipboard) == "function" then
            local ok, cl = pcall(clipboard)
            if ok and cl then keyInput.Text = tostring(cl) end
        else
            NotificationManager:push({type = "info", title = "Clipboard", text = "Clipboard functions unavailable."})
        end
        rippleAt(pasteBtn, Vector2.new(34, 18), Theme.secondary)
    end)

    keyInput.FocusLost:Connect(function(enter)
        if enter then validate() end
    end)
    loginBtn.MouseButton1Click:Connect(function()
        validate()
        rippleAt(loginBtn, Vector2.new(loginBtn.AbsoluteSize.X/2, loginBtn.AbsoluteSize.Y/2), Theme.secondary)
    end)

    return {Destroy = function() pcall(function() overlay:Destroy() end) end}
end

-- DRAG CONTROLLER ------------------------------------------------------
local function makeDraggable(frame, handle)
    handle = handle or frame
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
    local lastMousePos = Vector2.new()

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)

    RunService.RenderStepped:Connect(function(dt)
        if not dragging or not dragInput then return end
        local delta = UserInputService:GetMouseLocation() - dragStart
        local target = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        frame.Position = frame.Position:Lerp(target, math.clamp(18 * dt, 0, 1))
    end)
end

-- MAIN HUB BUILD -------------------------------------------------------
local function buildMainHub(guiParent)
    local screen = guiParent
    local hub = new("Frame")
    hub.Name = "Delta_MainHub"
    hub.Size = UDim2.new(0, 980, 0, 620)
    hub.Position = UDim2.new(0.5, 0, 0.5, 0)
    hub.AnchorPoint = Vector2.new(0.5, 0.5)
    hub.BackgroundTransparency = 0.06
    hub.BackgroundColor3 = Theme.glass
    hub.Parent = screen
    applyCorner(hub, 16)
    applyStroke(hub, Theme.uiAccent, 1.4)

    local accentStrip = new("Frame")
    accentStrip.Size = UDim2.new(1, 0, 0, 8)
    accentStrip.Position = UDim2.new(0, 0, 0, 0)
    accentStrip.BackgroundTransparency = 0
    accentStrip.BorderSizePixel = 0
    applyGradient(accentStrip, Theme.primary, Theme.secondary)
    accentStrip.Parent = hub

    makeGlow(hub, Color3.fromRGB(75, 165, 255))

    -- topbar
    local topbar = new("Frame")
    topbar.Size = UDim2.new(1, 0, 0, 44)
    topbar.BackgroundTransparency = 1
    topbar.Parent = hub

    local title = new("TextLabel")
    title.Text = "Delta Executor — Premium"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(240,240,245)
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 18, 0, 8)
    title.Parent = topbar

    local controls = new("Frame")
    controls.Size = UDim2.new(0, 120, 1, 0)
    controls.AnchorPoint = Vector2.new(1, 0)
    controls.Position = UDim2.new(1, -12, 0, 0)
    controls.BackgroundTransparency = 1
    controls.Parent = topbar

    local closeBtn = new("TextButton")
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 18
    closeBtn.TextColor3 = Color3.fromRGB(220,220,220)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -36, 0, 8)
    closeBtn.Parent = controls

    local collapseBtn = new("TextButton")
    collapseBtn.Text = "–"
    collapseBtn.Font = Enum.Font.GothamBold
    collapseBtn.TextSize = 18
    collapseBtn.TextColor3 = Color3.fromRGB(200,200,200)
    collapseBtn.BackgroundTransparency = 1
    collapseBtn.Size = UDim2.new(0, 28, 0, 28)
    collapseBtn.Position = UDim2.new(1, -72, 0, 8)
    collapseBtn.Parent = controls

    makeDraggable(hub, topbar)

    local collapsed = false
    local expandedSize = hub.Size
    local function setCollapsed(state)
        collapsed = state
        if collapsed then
            Tween(hub, {Size = UDim2.new(expandedSize.X.Scale, expandedSize.X.Offset, 0, 54)}, 0.3)
            sidebar.Visible = false
            contentArea.Visible = false
            collapseBtn.Text = "+"
        else
            Tween(hub, {Size = expandedSize}, 0.3)
            sidebar.Visible = true
            contentArea.Visible = true
            collapseBtn.Text = "–"
        end
    end
    collapseBtn.MouseButton1Click:Connect(function()
        setCollapsed(not collapsed)
    end)

    closeBtn.MouseEnter:Connect(function() Tween(closeBtn, {TextColor3 = Color3.fromRGB(255, 120, 120)}, 0.16) end)
    closeBtn.MouseLeave:Connect(function() Tween(closeBtn, {TextColor3 = Color3.fromRGB(220,220,220)}, 0.16) end)
    collapseBtn.MouseEnter:Connect(function() Tween(collapseBtn, {TextColor3 = Color3.fromRGB(170, 220, 255)}, 0.16) end)
    collapseBtn.MouseLeave:Connect(function() Tween(collapseBtn, {TextColor3 = Color3.fromRGB(200,200,200)}, 0.16) end)

    -- layout: sidebar + content
    local sidebar = new("Frame")
    sidebar.Size = UDim2.new(0, 210, 1, -20)
    sidebar.Position = UDim2.new(0, 18, 0, 54)
    sidebar.BackgroundTransparency = 1
    sidebar.Parent = hub

    local sideScroll = new("ScrollingFrame")
    sideScroll.Size = UDim2.new(1, 0, 1, -40)
    sideScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    sideScroll.BackgroundTransparency = 1
    sideScroll.ScrollBarThickness = 6
    sideScroll.Parent = sidebar

    local sideLayout = new("UIListLayout")
    sideLayout.Parent = sideScroll
    sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sideLayout.Padding = UDim.new(0, 12)

    local tabsContainer = new("Frame")
    tabsContainer.Size = UDim2.new(0, 210, 1, -40)
    tabsContainer.Position = UDim2.new(0, 0, 0, 12)
    tabsContainer.BackgroundTransparency = 1
    tabsContainer.Parent = sidebar

    local contentArea = new("Frame")
    contentArea.Size = UDim2.new(1, -250, 1, -40)
    contentArea.Position = UDim2.new(0, 250, 0, 54)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = hub

    local activeIndicator = new("Frame")
    activeIndicator.Size = UDim2.new(0, 6, 0, 40)
    activeIndicator.Position = UDim2.new(0, 0, 0, 6)
    activeIndicator.BackgroundColor3 = Theme.secondary
    applyCorner(activeIndicator, 6)
    activeIndicator.Parent = sidebar

    -- tab system
    local Tabs = {}
    local activeTab = nil

    local function createTabButton(name, iconText)
        local btn = new("TextButton")
        btn.Size = UDim2.new(1, -12, 0, 44)
        btn.BackgroundTransparency = 0.06
        btn.BackgroundColor3 = Color3.fromRGB(6,12,20)
        btn.Text = ""
        applyCorner(btn, 10)
        btn.Parent = sideScroll

        local icon = new("TextLabel")
        icon.Text = iconText or "•"
        icon.Font = Enum.Font.GothamBold
        icon.TextSize = 18
        icon.TextColor3 = Color3.fromRGB(220,240,255)
        icon.BackgroundTransparency = 1
        icon.Size = UDim2.new(0, 36, 1, 0)
        icon.Position = UDim2.new(0, 8, 0, 0)
        icon.Parent = btn

        local label = new("TextLabel")
        label.Text = name
        label.Font = Enum.Font.Gotham
        label.TextSize = 14
        label.TextColor3 = Color3.fromRGB(210,220,235)
        label.BackgroundTransparency = 1
        label.Position = UDim2.new(0, 56, 0, 10)
        label.Size = UDim2.new(1, -64, 1, -20)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = btn

        btn.MouseEnter:Connect(function()
            Tween(btn, {BackgroundTransparency = 0.02}, 0.18)
            Tween(icon, {TextTransparency = 0}, 0.18)
        end)
        btn.MouseLeave:Connect(function()
            Tween(btn, {BackgroundTransparency = 0.06}, 0.18)
            Tween(icon, {TextTransparency = 0.1}, 0.18)
        end)
        return btn
    end

    -- builder for tab content
    local function newTab(name, iconText, builder)
        local btn = createTabButton(name, iconText)
        local page = new("Frame")
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.Visible = false
        page.Parent = contentArea
        Tabs[name] = {btn = btn, page = page}

        btn.MouseButton1Click:Connect(function()
            if activeTab == name then return end
            if activeTab and Tabs[activeTab] then Tabs[activeTab].page.Visible = false end
            page.Visible = true
            activeTab = name
            -- move activeIndicator
            Tween(activeIndicator, {Position = UDim2.new(0, 0, 0, btn.AbsolutePosition.Y - sidebar.AbsolutePosition.Y)}, 0.3)
        end)

        if builder then builder(page) end
    end

    -- Player tab -------------------------------------------------------
    newTab("Player", "👤", function(page)
        local pnl = new("Frame")
        pnl.Size = UDim2.new(1, -20, 1, -20)
        pnl.Position = UDim2.new(0, 10, 0, 10)
        pnl.BackgroundTransparency = 1
        pnl.Parent = page

        local profile = new("Frame")
        profile.Size = UDim2.new(1, 0, 0, 110)
        profile.BackgroundTransparency = 0.02
        profile.BackgroundColor3 = Color3.fromRGB(8,16,30)
        applyCorner(profile, 12)
        profile.Parent = pnl

        local avatar = new("ImageLabel")
        avatar.Size = UDim2.new(0, 84, 0, 84)
        avatar.Position = UDim2.new(0, 16, 0, 12)
        avatar.BackgroundTransparency = 1
        applyCorner(avatar, 999)
        avatar.Parent = profile

        local nameLbl = new("TextLabel")
        nameLbl.Text = LocalPlayer and (LocalPlayer.DisplayName or LocalPlayer.Name) or "Local Player"
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 18
        nameLbl.TextColor3 = Color3.fromRGB(235,235,245)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Position = UDim2.new(0, 116, 0, 18)
        nameLbl.Parent = profile

        local userLbl = new("TextLabel")
        userLbl.Text = "@" .. (LocalPlayer and LocalPlayer.Name or "player")
        userLbl.Font = Enum.Font.Gotham
        userLbl.TextSize = 13
        userLbl.TextColor3 = Color3.fromRGB(180,200,220)
        userLbl.BackgroundTransparency = 1
        userLbl.Position = UDim2.new(0, 116, 0, 42)
        userLbl.Parent = profile

        -- stats container
        local leftStats = new("Frame")
        leftStats.Size = UDim2.new(0.5, -12, 0, 140)
        leftStats.Position = UDim2.new(0, 0, 0, 130)
        leftStats.BackgroundTransparency = 1
        leftStats.Parent = pnl

        local rightStats = new("Frame")
        rightStats.Size = UDim2.new(0.5, -12, 0, 140)
        rightStats.Position = UDim2.new(0.5, 12, 0, 130)
        rightStats.BackgroundTransparency = 1
        rightStats.Parent = pnl

        local function statLabel(parent, title, initial)
            local f = new("Frame")
            f.Size = UDim2.new(1, 0, 0, 36)
            f.BackgroundTransparency = 1
            f.Parent = parent
            local t = new("TextLabel")
            t.Text = title
            t.Font = Enum.Font.Gotham
            t.TextSize = 12
            t.TextColor3 = Color3.fromRGB(180,200,220)
            t.BackgroundTransparency = 1
            t.Position = UDim2.new(0, 0, 0, 4)
            t.Parent = f
            local v = new("TextLabel")
            v.Text = tostring(initial or "N/A")
            v.Font = Enum.Font.GothamBold
            v.TextSize = 16
            v.TextColor3 = Color3.fromRGB(230,240,255)
            v.BackgroundTransparency = 1
            v.Position = UDim2.new(0, 0, 0, 18)
            v.Parent = f
            return v
        end

        local fpsLbl = statLabel(leftStats, "FPS", "--")
        local pingLbl = statLabel(leftStats, "Ping (ms)", "--")
        local memLbl = statLabel(leftStats, "Memory (KB)", "--")
        local exLbl = statLabel(leftStats, "Executor", "Detecting...")

        local executionsLbl = statLabel(rightStats, "Total Executions", "0")
        local versionStr = tostring(game.Version)
        local ok, rbxAnalytics = pcall(function() return game:GetService("RbxAnalyticsService") end)
        if ok and rbxAnalytics and rbxAnalytics.Version then
            versionStr = tostring(rbxAnalytics.Version)
        end
        local versionLbl = statLabel(rightStats, "Roblox Version", versionStr)
        local placeLbl = statLabel(rightStats, "Current Game", tostring(game.PlaceId))
        local adminLbl = statLabel(rightStats, "Admin Status", "Unknown")

        -- runtime stats
        local last = tick()
        local frameCount = 0
        RunService.RenderStepped:Connect(function(dt)
            frameCount = frameCount + 1
            if tick() - last >= 1 then
                fpsLbl.Text = tostring(math.floor(frameCount / (tick() - last)))
                memLbl.Text = tostring(math.floor(collectgarbage("count")))
                frameCount = 0
                last = tick()
            end
        end)

        -- ping approximation (best-effort)
        spawn(function()
            while true do
                local start = tick()
                -- lightweight operation to approximate lag
                local ok = pcall(function() local a = workspace:FindFirstChild("__nonexistent__") end)
                local now = tick()
                pingLbl.Text = tostring(math.floor((now - start) * 1000))
                wait(1.2)
            end
        end)

        -- executor detection
        local function detectExecutor()
            local names = {"syn", "krnl", "SirHurt", "Flux", "Proxo", "DELTA", "Delta"}
            for _, n in pairs(names) do
                if _G[n] or _G[n:lower()] or _G[n:upper()] then
                    exLbl.Text = n
                    return
                end
            end
            -- check common globals
            if typeof(syn) == "table" or typeof(syn) == "function" then exLbl.Text = "Syn" return end
            exLbl.Text = "Delta Executor"
        end
        detectExecutor()

        -- Admin logic: only bladeballin12060 returns true
        if LocalPlayer and LocalPlayer.Name == "bladeballin12060" then adminLbl.Text = "True" else adminLbl.Text = "False" end

        -- Utilities list (scrollable)
        local utilHolder = new("ScrollingFrame")
        utilHolder.Size = UDim2.new(1, 0, 0, 260)
        utilHolder.Position = UDim2.new(0, 0, 0, 290)
        utilHolder.BackgroundTransparency = 1
        utilHolder.CanvasSize = UDim2.new(0, 0, 0, 0)
        utilHolder.ScrollBarThickness = 8
        utilHolder.Parent = pnl

        local utilLayout = new("UIListLayout")
        utilLayout.Parent = utilHolder
        utilLayout.Padding = UDim.new(0, 8)

        local utilityState = {}

        local function pushNotif(text, typ)
            NotificationManager:push({type = typ or "info", title = "Utility", text = text})
        end

        local function addToggle(name, desc, onToggle)
            local row = new("Frame")
            row.Size = UDim2.new(1, 0, 0, 44)
            row.BackgroundTransparency = 0.02
            row.BackgroundColor3 = Color3.fromRGB(6,12,20)
            applyCorner(row, 8)
            row.Parent = utilHolder

            local label = new("TextLabel")
            label.Text = name
            label.Font = Enum.Font.GothamBold
            label.TextSize = 14
            label.TextColor3 = Color3.fromRGB(220,220,235)
            label.BackgroundTransparency = 1
            label.Position = UDim2.new(0, 12, 0, 6)
            label.Parent = row

            local descLbl = new("TextLabel")
            descLbl.Text = desc
            descLbl.Font = Enum.Font.Gotham
            descLbl.TextSize = 12
            descLbl.TextColor3 = Color3.fromRGB(160,170,185)
            descLbl.BackgroundTransparency = 1
            descLbl.Position = UDim2.new(0, 12, 0, 22)
            descLbl.Parent = row

            local toggle = new("TextButton")
            toggle.Size = UDim2.new(0, 56, 0, 26)
            toggle.Position = UDim2.new(1, -72, 0, 9)
            toggle.AnchorPoint = Vector2.new(0, 0)
            toggle.BackgroundColor3 = Color3.fromRGB(18,36,64)
            applyCorner(toggle, 12)
            toggle.Text = ""
            toggle.Parent = row

            local knob = new("Frame")
            knob.Size = UDim2.new(0, 22, 0, 22)
            knob.Position = UDim2.new(0, 4, 0, 2)
            knob.BackgroundColor3 = Color3.fromRGB(190, 220, 255)
            applyCorner(knob, 999)
            knob.Parent = toggle

            local state = false
            toggle.MouseButton1Click:Connect(function()
                state = not state
                if state then
                    Tween(knob, {Position = UDim2.new(1, -26, 0, 2)}, 0.16)
                    Tween(toggle, {BackgroundColor3 = Theme.primary}, 0.18)
                else
                    Tween(knob, {Position = UDim2.new(0, 4, 0, 2)}, 0.16)
                    Tween(toggle, {BackgroundColor3 = Color3.fromRGB(18,36,64)}, 0.18)
                end
                if onToggle then pcall(onToggle, state) end
            end)

            return row
        end

        -- WalkSpeed slider
        local function addSlider(name, minv, maxv, initial, onChange)
            local row = new("Frame")
            row.Size = UDim2.new(1, 0, 0, 64)
            row.BackgroundTransparency = 0.02
            row.BackgroundColor3 = Color3.fromRGB(6,12,20)
            applyCorner(row, 8)
            row.Parent = utilHolder

            local label = new("TextLabel")
            label.Text = name
            label.Font = Enum.Font.GothamBold
            label.TextSize = 14
            label.TextColor3 = Color3.fromRGB(220,220,235)
            label.BackgroundTransparency = 1
            label.Position = UDim2.new(0, 12, 0, 6)
            label.Parent = row

            local sliderBar = new("Frame")
            sliderBar.Size = UDim2.new(1, -100, 0, 18)
            sliderBar.Position = UDim2.new(0, 12, 0, 36)
            sliderBar.BackgroundColor3 = Color3.fromRGB(12,24,44)
            applyCorner(sliderBar, 9)
            sliderBar.Parent = row

            local fill = new("Frame")
            fill.Size = UDim2.new((initial - minv)/(maxv-minv), 0, 1, 0)
            fill.BackgroundColor3 = Theme.primary
            applyCorner(fill, 9)
            fill.Parent = sliderBar

            local knob = new("Frame")
            knob.Size = UDim2.new(0, 14, 0, 14)
            knob.AnchorPoint = Vector2.new(0.5, 0.5)
            knob.Position = UDim2.new(fill.Size.X.Scale, 0, 0.5, 0)
            knob.BackgroundColor3 = Color3.fromRGB(220,240,255)
            applyCorner(knob, 999)
            knob.Parent = sliderBar

            local dragging = false
            knob.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true
                end
            end)
            knob.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
                    local rel = math.clamp((UserInputService:GetMouseLocation().X - sliderBar.AbsolutePosition.X)/sliderBar.AbsoluteSize.X, 0, 1)
                    fill.Size = UDim2.new(rel, 0, 1, 0)
                    knob.Position = UDim2.new(rel, 0, 0.5, 0)
                    local value = math.floor(minv + rel*(maxv-minv))
                    if onChange then pcall(onChange, value) end
                end
            end)

            return row
        end

        -- create controls
        addSlider("WalkSpeed", 8, 250, 16, function(v)
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("Humanoid") then char.Humanoid.WalkSpeed = v end
            pushNotif("WalkSpeed set to "..tostring(v), "info")
        end)
        addSlider("JumpPower", 20, 200, 50, function(v)
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("Humanoid") then char.Humanoid.JumpPower = v end
            pushNotif("JumpPower set to "..tostring(v), "info")
        end)
        addSlider("FOV", 50, 120, workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70, function(v)
            if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = v end
        end)

        -- toggles
        addToggle("Infinite Jump", "Hold space to keep jumping.", function(state)
            if state then
                utilityState.infiniteJumpConn = UserInputService.JumpRequest:Connect(function()
                    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
                end)
            else
                if utilityState.infiniteJumpConn then utilityState.infiniteJumpConn:Disconnect() end
            end
        end)

        addToggle("Noclip", "Pass through objects.", function(state)
            if state then
                utilityState.noclip = RunService.Stepped:Connect(function()
                    local char = LocalPlayer.Character
                    if char then
                        for _, part in pairs(char:GetDescendants()) do
                            if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                        end
                    end
                end)
            else
                if utilityState.noclip then utilityState.noclip:Disconnect() end
                local char = LocalPlayer.Character
                if char then for _, part in pairs(char:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = true end end end
            end
        end)

        addToggle("Fullbright", "Makes the game bright locally.", function(state)
            if state then
                utilityState.origAmbient = Lighting.Ambient
                Lighting.Ambient = Color3.fromRGB(255,255,255)
            else
                if utilityState.origAmbient then Lighting.Ambient = utilityState.origAmbient end
            end
        end)

        addToggle("Anti-AFK", "Prevents idle kick.", function(state)
            if state then
                local vu = game:GetService("VirtualUser")
                utilityState.afk = RunService.Heartbeat:Connect(function()
                    pcall(function()
                        vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                        wait(0.1)
                        vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                    end)
                end)
            else
                if utilityState.afk then utilityState.afk:Disconnect() end
            end
        end)

        addToggle("ESP", "Basic player ESP.", function(state)
            if state then
                utilityState.esp = {}
                for _, pl in pairs(Players:GetPlayers()) do
                    if pl ~= LocalPlayer and pl.Character and pl.Character:FindFirstChild("Head") then
                        local bb = new("BillboardGui")
                        bb.Size = UDim2.new(0, 100, 0, 40)
                        bb.Adornee = pl.Character.Head
                        bb.AlwaysOnTop = true
                        local lab = new("TextLabel")
                        lab.BackgroundTransparency = 1
                        lab.TextColor3 = Color3.fromRGB(220,220,255)
                        lab.Text = pl.Name
                        lab.Font = Enum.Font.GothamBold
                        lab.TextSize = 14
                        lab.Parent = bb
                        bb.Parent = workspace
                        utilityState.esp[pl] = bb
                    end
                end
                Players.PlayerAdded:Connect(function(pl)
                    -- not fully managed removal for brevity
                end)
            else
                if utilityState.esp then for k,v in pairs(utilityState.esp) do pcall(function() v:Destroy() end) end end
            end
        end)

        addToggle("Click TP", "Teleport to clicked point.", function(state)
            if state then
                utilityState.clickTP = LocalPlayer:GetMouse().Button1Down:Connect(function()
                    local mouse = LocalPlayer:GetMouse()
                    if mouse and mouse.Hit then
                        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then hrp.CFrame = CFrame.new(mouse.Hit.p + Vector3.new(0,3,0)) end
                    end
                end)
            else
                if utilityState.clickTP then utilityState.clickTP:Disconnect() end
            end
        end)

        -- small footer
        utilHolder.CanvasSize = UDim2.new(0, 0, 0, utilLayout.AbsoluteContentSize)
    end)

    -- Scripts Tab ------------------------------------------------------
    newTab("Scripts", "📜", function(page)
        local holder = new("Frame")
        holder.Size = UDim2.new(1, -20, 1, -20)
        holder.Position = UDim2.new(0, 10, 0, 10)
        holder.BackgroundTransparency = 1
        holder.Parent = page

        local search = new("TextBox")
        search.PlaceholderText = "Search scripts..."
        search.Size = UDim2.new(1, -120, 0, 36)
        search.BackgroundColor3 = Color3.fromRGB(8,18,32)
        applyCorner(search, 8)
        search.Parent = holder

        local apiResults = {
            {name = "AutoFarm (Demo)", desc = "Safe autoplayer script.", views = 1842, verified = true, code = "print(\"Autofarm running\")"},
            {name = "Fly (Simple)", desc = "Lightweight fly script.", views = 1023, verified = true, code = "print(\"Fly toggled\")"},
            {name = "Backdoor Scanner Example", desc = "Scan workspace for suspicious code.", views = 345, verified = false, code = "print(\"Scanning...\")"}
        }

        local cardsFrame = new("ScrollingFrame")
        cardsFrame.Size = UDim2.new(1, 0, 1, -56)
        cardsFrame.Position = UDim2.new(0, 0, 0, 52)
        cardsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        cardsFrame.BackgroundTransparency = 1
        cardsFrame.Parent = holder

        local cardsLayout = new("UIListLayout")
        cardsLayout.Padding = UDim.new(0, 12)
        cardsLayout.Parent = cardsFrame

        local function renderCard(item)
            local card = new("Frame")
            card.Size = UDim2.new(1, 0, 0, 96)
            card.BackgroundTransparency = 0.03
            card.BackgroundColor3 = Color3.fromRGB(8,16,28)
            applyCorner(card, 10)
            card.Parent = cardsFrame

            local name = new("TextLabel")
            name.Text = item.name
            name.Font = Enum.Font.GothamBold
            name.TextSize = 16
            name.TextColor3 = Color3.fromRGB(230,230,240)
            name.BackgroundTransparency = 1
            name.Position = UDim2.new(0, 108, 0, 12)
            name.Parent = card

            local desc = new("TextLabel")
            desc.Text = item.desc
            desc.Font = Enum.Font.Gotham
            desc.TextSize = 12
            desc.TextColor3 = Color3.fromRGB(170,180,200)
            desc.BackgroundTransparency = 1
            desc.Position = UDim2.new(0, 108, 0, 38)
            desc.Parent = card

            local executeBtn = new("TextButton")
            executeBtn.Text = "Execute"
            executeBtn.Font = Enum.Font.GothamBold
            executeBtn.TextSize = 13
            executeBtn.Size = UDim2.new(0, 96, 0, 34)
            executeBtn.Position = UDim2.new(1, -108, 0, 28)
            executeBtn.BackgroundColor3 = Theme.primary
            applyCorner(executeBtn, 8)
            executeBtn.Parent = card

            local copyBtn = new("TextButton")
            copyBtn.Text = "Copy"
            copyBtn.Font = Enum.Font.Gotham
            copyBtn.TextSize = 12
            copyBtn.Size = UDim2.new(0, 64, 0, 28)
            copyBtn.Position = UDim2.new(1, -196, 0, 32)
            copyBtn.BackgroundColor3 = Color3.fromRGB(18,36,60)
            applyCorner(copyBtn, 8)
            copyBtn.Parent = card

            executeBtn.MouseButton1Click:Connect(function()
                NotificationManager:push({type = "info", title = "Script", text = "Executing '"..item.name.."'"})
                local ok, err = executeCode(item.code)
                if not ok then NotificationManager:push({type = "error", title = "Execution Error", text = tostring(err)}) end
            end)
            copyBtn.MouseButton1Click:Connect(function()
                if setclipboard then pcall(function() setclipboard(item.code) end); NotificationManager:push({type = "success", title = "Copied", text = "Script copied to clipboard."}) else NotificationManager:push({type = "info", title = "Copy", text = "Clipboard unavailable."}) end
            end)
        end

        for _, item in pairs(apiResults) do renderCard(item) end
        cardsFrame.CanvasSize = UDim2.new(0, 0, 0, cardsLayout.AbsoluteContentSize)
    end)

    -- Saved Scripts Tab ------------------------------------------------
    newTab("Saved", "💾", function(page)
        local holder = new("Frame")
        holder.Size = UDim2.new(1, -20, 1, -20)
        holder.Position = UDim2.new(0, 10, 0, 10)
        holder.BackgroundTransparency = 1
        holder.Parent = page

        local saved = readJSON(SCRIPTS_SAVE_FILE) or {}

        local list = new("ScrollingFrame")
        list.Size = UDim2.new(1, 0, 1, 0)
        list.BackgroundTransparency = 1
        list.Parent = holder

        local listLayout = new("UIListLayout")
        listLayout.Parent = list
        listLayout.Padding = UDim.new(0, 10)

        local function refreshList()
            for _,c in pairs(list:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
            for name, code in pairs(saved) do
                local card = new("Frame")
                card.Size = UDim2.new(1, 0, 0, 88)
                card.BackgroundTransparency = 0.03
                card.BackgroundColor3 = Color3.fromRGB(6,12,20)
                applyCorner(card, 10)
                card.Parent = list

                local title = new("TextLabel")
                title.Text = name
                title.Font = Enum.Font.GothamBold
                title.TextSize = 14
                title.TextColor3 = Color3.fromRGB(230,230,245)
                title.BackgroundTransparency = 1
                title.Position = UDim2.new(0, 12, 0, 12)
                title.Parent = card

                local exec = new("TextButton")
                exec.Text = "Execute"
                exec.Font = Enum.Font.GothamBold
                exec.TextSize = 12
                exec.Size = UDim2.new(0, 84, 0, 32)
                exec.Position = UDim2.new(1, -96, 0, 26)
                exec.BackgroundColor3 = Theme.primary
                applyCorner(exec, 8)
                exec.Parent = card

                local del = new("TextButton")
                del.Text = "Delete"
                del.Font = Enum.Font.Gotham
                del.TextSize = 12
                del.Size = UDim2.new(0,64,0,28)
                del.Position = UDim2.new(1, -192, 0, 28)
                del.BackgroundColor3 = Color3.fromRGB(18,36,60)
                applyCorner(del, 8)
                del.Parent = card

                exec.MouseButton1Click:Connect(function()
                    local ok, err = executeCode(code)
                    if not ok then NotificationManager:push({type = "error", title = "Execution Error", text = tostring(err)}) end
                end)
                del.MouseButton1Click:Connect(function()
                    saved[name] = nil
                    writeJSON(SCRIPTS_SAVE_FILE, saved)
                    refreshList()
                    NotificationManager:push({type = "info", title = "Saved", text = "Script deleted."})
                end)
            end
            list.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize)
        end
        refreshList()

        -- small editor + save
        local editor = new("TextBox")
        editor.PlaceholderText = "Paste Lua code here..."
        editor.Size = UDim2.new(1, -240, 0, 120)
        editor.Position = UDim2.new(0, 0, 1, -128)
        editor.BackgroundColor3 = Color3.fromRGB(8,18,32)
        editor.ClearTextOnFocus = false
        editor.Text = ""
        editor.TextWrapped = true
        applyCorner(editor, 8)
        editor.Parent = holder

        local saveBtn = new("TextButton")
        saveBtn.Text = "Save Script"
        saveBtn.Font = Enum.Font.GothamBold
        saveBtn.Size = UDim2.new(0, 160, 0, 40)
        saveBtn.Position = UDim2.new(1, -168, 1, -128)
        saveBtn.BackgroundColor3 = Theme.primary
        applyCorner(saveBtn, 10)
        saveBtn.Parent = holder

        saveBtn.MouseButton1Click:Connect(function()
            local text = editor.Text
            if text == "" then NotificationManager:push({type = "error", title = "Save", text = "Cannot save empty script."}) return end
            local name = "Script_" .. tostring(math.random(1000,9999))
            saved[name] = text
            writeJSON(SCRIPTS_SAVE_FILE, saved)
            refreshList()
            NotificationManager:push({type = "success", title = "Saved", text = "Script saved as "..name})
        end)
    end)

    -- Exploits Tab -----------------------------------------------------
    newTab("Exploits", "🛠️", function(page)
        local holder = new("Frame")
        holder.Size = UDim2.new(1, -20, 1, -20)
        holder.Position = UDim2.new(0, 10, 0, 10)
        holder.BackgroundTransparency = 1
        holder.Parent = page

        local lab = new("TextLabel")
        lab.Text = "Exploit & client-manipulation tools"
        lab.Font = Enum.Font.GothamBold
        lab.TextSize = 16
        lab.TextColor3 = Color3.fromRGB(230,230,245)
        lab.BackgroundTransparency = 1
        lab.Position = UDim2.new(0, 12, 0, 6)
        lab.Parent = holder

        local list = new("ScrollingFrame")
        list.Size = UDim2.new(1, 0, 1, -40)
        list.Position = UDim2.new(0, 0, 0, 36)
        list.BackgroundTransparency = 1
        list.Parent = holder

        local layout = new("UIListLayout")
        layout.Parent = list
        layout.Padding = UDim.new(0, 12)

        local function addExploit(name, desc, fn)
            local card = new("Frame")
            card.Size = UDim2.new(1, 0, 0, 84)
            card.BackgroundTransparency = 0.03
            card.BackgroundColor3 = Color3.fromRGB(6,12,22)
            applyCorner(card, 10)
            card.Parent = list

            local t = new("TextLabel")
            t.Text = name
            t.Font = Enum.Font.GothamBold
            t.TextSize = 14
            t.TextColor3 = Color3.fromRGB(230,230,245)
            t.BackgroundTransparency = 1
            t.Position = UDim2.new(0, 12, 0, 12)
            t.Parent = card

            local d = new("TextLabel")
            d.Text = desc
            d.Font = Enum.Font.Gotham
            d.TextSize = 12
            d.TextColor3 = Color3.fromRGB(170,180,200)
            d.BackgroundTransparency = 1
            d.Position = UDim2.new(0, 12, 0, 36)
            d.Parent = card

            local tog = new("TextButton")
            tog.Text = "Toggle"
            tog.Font = Enum.Font.GothamBold
            tog.TextSize = 12
            tog.Size = UDim2.new(0, 86, 0, 34)
            tog.Position = UDim2.new(1, -104, 0, 22)
            tog.BackgroundColor3 = Theme.primary
            applyCorner(tog, 8)
            tog.Parent = card

            local state = false
            tog.MouseButton1Click:Connect(function()
                state = not state
                if state then
                    NotificationManager:push({type = "info", title = name, text = "Enabled"})
                else
                    NotificationManager:push({type = "info", title = name, text = "Disabled"})
                end
                if fn then pcall(fn, state) end
            end)
        end

        addExploit("Desync", "Client-side desync utilities.", function(state) end)
        addExploit("Fake Lag", "Introduce packet lag simulation.", function(state) end)
        addExploit("Animation Desync", "Manipulate animation replication.", function(state) end)
        addExploit("Physics Manipulation", "Local physics perturbations.", function(state) end)
    end)

    -- Backdoor Scanner -------------------------------------------------
    newTab("Scanner", "🔎", function(page)
        local holder = new("Frame")
        holder.Size = UDim2.new(1, -20, 1, -20)
        holder.Position = UDim2.new(0, 10, 0, 10)
        holder.BackgroundTransparency = 1
        holder.Parent = page

        local title = new("TextLabel")
        title.Text = "Backdoor Scanner"
        title.Font = Enum.Font.GothamBold
        title.TextSize = 18
        title.TextColor3 = Color3.fromRGB(230,230,245)
        title.BackgroundTransparency = 1
        title.Position = UDim2.new(0, 12, 0, 6)
        title.Parent = holder

        local scanBtn = new("TextButton")
        scanBtn.Text = "Start Scan"
        scanBtn.Font = Enum.Font.GothamBold
        scanBtn.TextSize = 14
        scanBtn.Size = UDim2.new(0, 120, 0, 36)
        scanBtn.Position = UDim2.new(1, -140, 0, 6)
        scanBtn.BackgroundColor3 = Theme.primary
        applyCorner(scanBtn, 8)
        scanBtn.Parent = holder

        local progress = new("Frame")
        progress.Size = UDim2.new(1, -20, 0, 8)
        progress.Position = UDim2.new(0, 10, 0, 60)
        progress.BackgroundColor3 = Color3.fromRGB(12,24,44)
        applyCorner(progress, 6)
        progress.Parent = holder

        local fill = new("Frame")
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = Theme.secondary
        applyCorner(fill, 6)
        fill.Parent = progress

        local logBox = new("ScrollingFrame")
        logBox.Size = UDim2.new(1, 0, 1, -92)
        logBox.Position = UDim2.new(0, 0, 0, 76)
        logBox.BackgroundTransparency = 1
        logBox.Parent = holder

        local logLayout = new("UIListLayout")
        logLayout.Parent = logBox
        logLayout.Padding = UDim.new(0, 6)

        local function log(text)
            local l = new("TextLabel")
            l.Size = UDim2.new(1, 0, 0, 20)
            l.BackgroundTransparency = 1
            l.Text = text
            l.TextColor3 = Color3.fromRGB(200,200,210)
            l.Font = Enum.Font.Gotham
            l.TextSize = 13
            l.Parent = logBox
            logBox.CanvasSize = UDim2.new(0, 0, 0, logLayout.AbsoluteContentSize)
        end

        scanBtn.MouseButton1Click:Connect(function()
            logBox:ClearAllChildren()
            logLayout.Parent = nil
            logLayout.Parent = logBox
            local all = workspace:GetDescendants()
            local count = #all
            local found = 0
            for i, obj in ipairs(all) do
                local pct = i / count
                fill.Size = UDim2.new(pct, 0, 1, 0)
                if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                    local ok, src = pcall(function() return obj.Source end)
                    if ok and src then
                        if string.find(src:lower(), "loadstring") or string.find(src:lower(), "httpget") or string.find(src:lower(), "backdoor") then
                            log("Potential backdoor in: "..obj:GetFullName())
                            found = found + 1
                        end
                    end
                end
                wait(0.01)
            end
            if found == 0 then log("No backdoors found.") else log(found.." potential items found.") end
            fill.Size = UDim2.new(1, 0, 1, 0)
        end)
    end)

    -- Executor Tab ----------------------------------------------------
    newTab("Executor", "⌨️", function(page)
        local holder = new("Frame")
        holder.Size = UDim2.new(1, -20, 1, -20)
        holder.Position = UDim2.new(0, 10, 0, 10)
        holder.BackgroundTransparency = 1
        holder.Parent = page

        local editor = new("TextBox")
        editor.Size = UDim2.new(1, 0, 1, -60)
        editor.BackgroundColor3 = Color3.fromRGB(6,12,20)
        editor.ClearTextOnFocus = false
        editor.Text = "-- Paste Lua code here\n"
        editor.TextWrapped = true
        editor.TextXAlignment = Enum.TextXAlignment.Left
        editor.TextYAlignment = Enum.TextYAlignment.Top
        applyCorner(editor, 10)
        editor.Parent = holder

        local runBtn = new("TextButton")
        runBtn.Text = "Execute"
        runBtn.Font = Enum.Font.GothamBold
        runBtn.Size = UDim2.new(0, 120, 0, 40)
        runBtn.Position = UDim2.new(1, -136, 1, -48)
        runBtn.BackgroundColor3 = Theme.primary
        applyCorner(runBtn, 8)
        runBtn.Parent = holder

        local clearBtn = new("TextButton")
        clearBtn.Text = "Clear"
        clearBtn.Font = Enum.Font.Gotham
        clearBtn.Size = UDim2.new(0, 88, 0, 36)
        clearBtn.Position = UDim2.new(1, -260, 1, -48)
        clearBtn.BackgroundColor3 = Color3.fromRGB(18,36,60)
        applyCorner(clearBtn, 8)
        clearBtn.Parent = holder

        local logFrame = new("ScrollingFrame")
        logFrame.Size = UDim2.new(1, 0, 0, 44)
        logFrame.Position = UDim2.new(0, 0, 1, -44)
        logFrame.BackgroundTransparency = 1
        logFrame.Parent = holder

        local logLayout = new("UIListLayout")
        logLayout.Parent = logFrame
        logLayout.Padding = UDim.new(0, 6)

        local function appendLog(text, typ)
            local t = new("TextLabel")
            t.Size = UDim2.new(1, -12, 0, 20)
            t.Position = UDim2.new(0, 12, 0, 0)
            t.BackgroundTransparency = 1
            t.Text = text
            t.TextColor3 = typ == "error" and Color3.fromRGB(255,120,120) or Color3.fromRGB(200,200,210)
            t.Font = Enum.Font.Gotham
            t.TextSize = 13
            t.Parent = logFrame
            logFrame.CanvasSize = UDim2.new(0, 0, 0, logLayout.AbsoluteContentSize)
        end

        runBtn.MouseButton1Click:Connect(function()
            local code = editor.Text
            local ok, ret = executeCode(code)
            if not ok then appendLog(tostring(ret), "error") else appendLog("Executed successfully", "info") end
        end)

        clearBtn.MouseButton1Click:Connect(function() editor.Text = "" end)
    end)

    -- Music Tab -------------------------------------------------------
    newTab("Music", "🎵", function(page)
        local holder = new("Frame")
        holder.Size = UDim2.new(1, -20, 1, -20)
        holder.Position = UDim2.new(0, 10, 0, 10)
        holder.BackgroundTransparency = 1
        holder.Parent = page

        local input = new("TextBox")
        input.PlaceholderText = "Paste rbxassetid://<id> or audio URL"
        input.Size = UDim2.new(1, -240, 0, 36)
        input.Position = UDim2.new(0, 0, 0, 6)
        input.BackgroundColor3 = Color3.fromRGB(8,18,32)
        applyCorner(input, 8)
        input.Parent = holder

        local playBtn = new("TextButton")
        playBtn.Text = "Play"
        playBtn.Size = UDim2.new(0, 88, 0, 36)
        playBtn.Position = UDim2.new(1, -136, 0, 6)
        playBtn.BackgroundColor3 = Theme.primary
        applyCorner(playBtn, 8)
        playBtn.Parent = holder

        local stopBtn = new("TextButton")
        stopBtn.Text = "Stop"
        stopBtn.Size = UDim2.new(0, 88, 0, 36)
        stopBtn.Position = UDim2.new(1, -40, 0, 6)
        stopBtn.BackgroundColor3 = Color3.fromRGB(20,36,60)
        applyCorner(stopBtn, 8)
        stopBtn.Parent = holder

        local currentSound = nil
        playBtn.MouseButton1Click:Connect(function()
            local txt = input.Text
            if txt == "" then NotificationManager:push({type = "error", title = "Music", text = "No URL provided."}) return end
            if currentSound then pcall(function() currentSound:Stop(); currentSound:Destroy() end) end
            local s = new("Sound")
            s.SoundId = txt
            s.Volume = 0.7
            s.Looped = false
            s.Parent = SoundService
            currentSound = s
            pcall(function() s:Play() end)
            NotificationManager:push({type = "success", title = "Music", text = "Playing"})
        end)
        stopBtn.MouseButton1Click:Connect(function()
            if currentSound then pcall(function() currentSound:Stop(); currentSound:Destroy() end); currentSound = nil end
        end)
    end)

    -- Themes Tab (Customization) -------------------------------------
    newTab("Themes", "🎨", function(page)
        local holder = new("Frame")
        holder.Size = UDim2.new(1, -20, 1, -20)
        holder.Position = UDim2.new(0, 10, 0, 10)
        holder.BackgroundTransparency = 1
        holder.Parent = page

        local title = new("TextLabel")
        title.Text = "Themes & UI Settings"
        title.Font = Enum.Font.GothamBold
        title.TextSize = 18
        title.TextColor3 = Color3.fromRGB(230,230,245)
        title.BackgroundTransparency = 1
        title.Position = UDim2.new(0, 12, 0, 6)
        title.Parent = holder

        local saveBtn = new("TextButton")
        saveBtn.Text = "Save Theme"
        saveBtn.Position = UDim2.new(1, -140, 0, 6)
        saveBtn.Size = UDim2.new(0, 120, 0, 36)
        saveBtn.BackgroundColor3 = Theme.primary
        applyCorner(saveBtn, 8)
        saveBtn.Parent = holder

        saveBtn.MouseButton1Click:Connect(function()
            local ok = ConfigManager:save()
            if ok then NotificationManager:push({type = "success", title = "Theme", text = "Saved."}) else NotificationManager:push({type = "error", title = "Theme", text = "Could not save. writefile unavailable."}) end
        end)
    end)

    -- Extra premium tabs
    newTab("Configs", "⚙️", function(page) end)
    newTab("Console", "⌁", function(page) end)
    newTab("Analytics", "📊", function(page) end)

    -- default tab
    delay(0.2, function()
        if Tabs["Player"] then Tabs["Player"].btn:MouseButton1Click() end
    end)

    -- close behavior
    closeBtn.MouseButton1Click:Connect(function()
        local confirm = Instance.new("TextButton")
        confirm.Text = "Are you sure? Click to confirm close"
        confirm.Size = UDim2.new(0, 420, 0, 60)
        confirm.Position = UDim2.new(0.5, -210, 0.5, -30)
        confirm.AnchorPoint = Vector2.new(0.5, 0.5)
        confirm.BackgroundColor3 = Color3.fromRGB(10, 18, 32)
        applyCorner(confirm, 12)
        confirm.Parent = hub
        Tween(confirm, {Position = UDim2.new(0.5, -210, 0.5, -30)}, 0.18)
        confirm.MouseButton1Click:Connect(function()
            pcall(function() hub:Destroy() end)
        end)
        delay(6, function() pcall(function() confirm:Destroy() end) end)
    end)

    return hub
end

-- BOOTSTRAP ------------------------------------------------------------
local function getGuiParent()
    -- prefer PlayerGui, fall back to CoreGui
    if PlayerGui then return PlayerGui end
    return CoreGui
end

local guiParent = getGuiParent()
local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.Parent = guiParent

-- initialize notification manager
NotificationManager:init(screenGui)
ConfigManager:load()

-- build auth then main
local auth = buildAuthScreen(screenGui, function()
    -- on auth success
    local main = buildMainHub(screenGui)
    NotificationManager:push({type = "success", title = "Delta Hub", text = "Loaded successfully."})
end)

-- final polish: entrance sound (optional)
-- return module table for possible advanced use
local DeltaHub = {
    KEY = KEY_CODE,
    ScreenGui = screenGui,
    Close = function() pcall(function() screenGui:Destroy() end) end
}

return DeltaHub

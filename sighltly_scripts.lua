--[[
    sighltly scripts
    Combined Auto Dive + Football Hitbox controller.

    Auto Dive only operates while its switch is ON and F is held.
    Hitbox targets workspace.Football.Hitbox, matching the supplied code.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local COLORS = {
    background = Color3.fromRGB(29, 23, 38),
    panel = Color3.fromRGB(42, 33, 55),
    card = Color3.fromRGB(53, 42, 68),
    cardHover = Color3.fromRGB(62, 49, 80),
    purple = Color3.fromRGB(139, 91, 210),
    purpleLight = Color3.fromRGB(184, 143, 241),
    track = Color3.fromRGB(76, 64, 91),
    text = Color3.fromRGB(246, 241, 252),
    muted = Color3.fromRGB(178, 166, 191),
    green = Color3.fromRGB(66, 196, 116),
    red = Color3.fromRGB(220, 76, 91),
}

local NORMAL_HITBOX_SIZE = 5
local MIN_HITBOX_SIZE = 5
local MAX_HITBOX_SIZE = 35

local GOAL_WIDTH, GOAL_HEIGHT = 50, 30
local DIVE_SPEED, DIVE_UP = 70, 40
local DECEL_VAL, GRAVITY_VAL = 28, 300
local DIVE_COOLDOWN = 3
local SILHOUETTE_WIDTH = 4.5
local MIN_SHOT_SPEED = 18
local REACTION_STRETCH = 22

local state = {
    autoDive = false,
    holdingF = false,
    hitbox = false,
    outline = false,
    hitboxSize = 28,
    transparency = 0.45,
    toggleKey = Enum.KeyCode.RightBracket,
    awaitingKey = false,
    lastDive = 0,
}

local humanoid, rootPart
local activeDiveCleanup
local connections = {}
local originalHitboxes = setmetatable({}, {__mode = "k"})

local function create(className, properties, parent)
    local object = Instance.new(className)
    for key, value in pairs(properties or {}) do object[key] = value end
    object.Parent = parent
    return object
end

local function corner(parent, radius)
    return create("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, parent)
end

local function tween(object, duration, properties, style)
    local animation = TweenService:Create(
        object,
        TweenInfo.new(duration, style or Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        properties
    )
    animation:Play()
    return animation
end

local old = playerGui:FindFirstChild("SighltlyScripts")
if old then old:Destroy() end

local gui = create("ScreenGui", {
    Name = "SighltlyScripts",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local window = create("CanvasGroup", {
    Name = "Window",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(430, 430),
    BackgroundColor3 = COLORS.background,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    GroupTransparency = 0,
}, gui)
corner(window, 18)
create("UIStroke", {Color = Color3.fromRGB(84, 58, 110), Thickness = 1, Transparency = 0.15}, window)

local topbar = create("Frame", {
    Size = UDim2.new(1, 0, 0, 52),
    BackgroundColor3 = COLORS.panel,
    BorderSizePixel = 0,
    Active = true,
}, window)

create("TextLabel", {
    Position = UDim2.fromOffset(17, 7),
    Size = UDim2.new(1, -34, 0, 23),
    BackgroundTransparency = 1,
    Text = "sighltly scripts",
    TextColor3 = COLORS.text,
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left,
}, topbar)

create("TextLabel", {
    Position = UDim2.fromOffset(17, 29),
    Size = UDim2.new(1, -34, 0, 16),
    BackgroundTransparency = 1,
    Text = "goalkeeper controls",
    TextColor3 = COLORS.muted,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
}, topbar)

local content = create("ScrollingFrame", {
    Position = UDim2.fromOffset(12, 64),
    Size = UDim2.new(1, -24, 1, -76),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = COLORS.purple,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, window)
create("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, content)
create("UIPadding", {PaddingBottom = UDim.new(0, 5)}, content)

local function makeCard(height, order)
    local card = create("Frame", {
        LayoutOrder = order,
        Size = UDim2.new(1, -3, 0, height),
        BackgroundColor3 = COLORS.card,
        BorderSizePixel = 0,
    }, content)
    corner(card, 10)
    create("UIStroke", {Color = COLORS.purple, Transparency = 0.78, Thickness = 1}, card)
    return card
end

local statusCard = makeCard(42, 1)
local statusDot = create("Frame", {
    Position = UDim2.fromOffset(13, 15),
    Size = UDim2.fromOffset(12, 12),
    BackgroundColor3 = COLORS.red,
    BorderSizePixel = 0,
}, statusCard)
corner(statusDot, 6)
local statusText = create("TextLabel", {
    Position = UDim2.fromOffset(34, 0),
    Size = UDim2.new(1, -45, 1, 0),
    BackgroundTransparency = 1,
    Text = "SCRIPT DISABLED",
    TextColor3 = COLORS.red,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
}, statusCard)

local function setStatus(text, color)
    statusText.Text = text
    tween(statusText, 0.2, {TextColor3 = color})
    tween(statusDot, 0.2, {BackgroundColor3 = color})
    statusDot.Size = UDim2.fromOffset(7, 7)
    statusDot.Position = UDim2.fromOffset(15, 17)
    tween(statusDot, 0.22, {Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(13, 15)}, Enum.EasingStyle.Back)
end

local function makeSwitch(parent, position)
    local switch = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = position,
        Size = UDim2.fromOffset(54, 28),
        BackgroundColor3 = COLORS.red,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, parent)
    corner(switch, 14)
    local knob = create("Frame", {
        Position = UDim2.fromOffset(3, 3),
        Size = UDim2.fromOffset(22, 22),
        BackgroundColor3 = COLORS.text,
        BorderSizePixel = 0,
    }, switch)
    corner(knob, 11)
    return switch, knob
end

local function animateSwitch(switch, knob, enabled)
    tween(switch, 0.22, {BackgroundColor3 = enabled and COLORS.green or COLORS.red})
    tween(knob, 0.22, {Position = enabled and UDim2.fromOffset(29, 3) or UDim2.fromOffset(3, 3)}, Enum.EasingStyle.Quint)
end

local autoCard = makeCard(86, 2)
create("TextLabel", {
    Position = UDim2.fromOffset(14, 11),
    Size = UDim2.new(1, -90, 0, 23),
    BackgroundTransparency = 1,
    Text = "Auto Dive",
    TextColor3 = COLORS.text,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
}, autoCard)
create("TextLabel", {
    Position = UDim2.fromOffset(14, 39),
    Size = UDim2.new(1, -28, 0, 32),
    BackgroundTransparency = 1,
    Text = "Enable, then hold F to predict and dive toward shots.",
    TextColor3 = COLORS.muted,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
}, autoCard)
local autoSwitch, autoKnob = makeSwitch(autoCard, UDim2.new(1, -14, 0, 25))

local hitboxCard = makeCard(246, 3)
create("TextLabel", {
    Position = UDim2.fromOffset(14, 11),
    Size = UDim2.new(1, -90, 0, 23),
    BackgroundTransparency = 1,
    Text = "Ball Hitbox",
    TextColor3 = COLORS.text,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
}, hitboxCard)
create("TextLabel", {
    Position = UDim2.fromOffset(14, 34),
    Size = UDim2.new(1, -90, 0, 18),
    BackgroundTransparency = 1,
    Text = "workspace.Football.Hitbox",
    TextColor3 = COLORS.muted,
    Font = Enum.Font.Code,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
}, hitboxCard)
local hitboxSwitch, hitboxKnob = makeSwitch(hitboxCard, UDim2.new(1, -14, 0, 28))

local function makeSlider(parent, y, labelText, minimum, maximum, initial, formatter, callback)
    local label = create("TextLabel", {
        Position = UDim2.fromOffset(14, y),
        Size = UDim2.new(1, -28, 0, 20),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = COLORS.text,
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
    local track = create("TextButton", {
        Position = UDim2.fromOffset(14, y + 25),
        Size = UDim2.new(1, -28, 0, 7),
        BackgroundColor3 = COLORS.track,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, parent)
    corner(track, 4)
    local fill = create("Frame", {
        Size = UDim2.fromScale((initial - minimum) / (maximum - minimum), 1),
        BackgroundColor3 = COLORS.purple,
        BorderSizePixel = 0,
    }, track)
    corner(fill, 4)
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale((initial - minimum) / (maximum - minimum), 0.5),
        Size = UDim2.fromOffset(15, 15),
        BackgroundColor3 = COLORS.purpleLight,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, track)
    corner(knob, 8)

    local dragging = false
    local function setValue(value, animated)
        value = math.clamp(value, minimum, maximum)
        local ratio = (value - minimum) / (maximum - minimum)
        if animated then
            tween(fill, 0.08, {Size = UDim2.fromScale(ratio, 1)})
            tween(knob, 0.08, {Position = UDim2.fromScale(ratio, 0.5)})
        else
            fill.Size = UDim2.fromScale(ratio, 1)
            knob.Position = UDim2.fromScale(ratio, 0.5)
        end
        label.Text = labelText .. ": " .. formatter(value)
        callback(value)
    end
    local function update(inputX)
        local ratio = math.clamp((inputX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        setValue(minimum + (maximum - minimum) * ratio, true)
    end
    label.Text = labelText .. ": " .. formatter(initial)
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input.Position.X)
        end
    end)
    track.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input.Position.X)
        end
    end))
    return function(value) setValue(value, false) end
end

local function getFootballHitbox()
    local football = workspace:FindFirstChild("Football")
    return football and football:FindFirstChild("Hitbox")
end

local function applyOutline(hitbox)
    if not hitbox then return end
    local outline = hitbox:FindFirstChild("SighltlyCartoonOutline")
    if state.outline then
        if not outline then
            outline = create("Highlight", {
                Name = "SighltlyCartoonOutline",
                Adornee = hitbox,
                DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
                FillTransparency = 1,
                OutlineColor = Color3.fromRGB(50, 24, 72),
                OutlineTransparency = 0.05,
            }, hitbox)
        end
        outline.Enabled = true
    elseif outline then
        outline:Destroy()
    end
end

local function applyHitbox()
    local hitbox = getFootballHitbox()
    if not hitbox or not hitbox:IsA("BasePart") then return end
    if not originalHitboxes[hitbox] then
        originalHitboxes[hitbox] = {
            Size = hitbox.Size,
            Transparency = hitbox.Transparency,
        }
    end
    if state.hitbox then
        hitbox.Size = Vector3.new(state.hitboxSize, state.hitboxSize, state.hitboxSize)
        hitbox.Transparency = state.transparency
    else
        local original = originalHitboxes[hitbox]
        hitbox.Size = original and original.Size or Vector3.new(NORMAL_HITBOX_SIZE, NORMAL_HITBOX_SIZE, NORMAL_HITBOX_SIZE)
        hitbox.Transparency = original and original.Transparency or 1
    end
    applyOutline(hitbox)
end

local setHitboxSizeSlider = makeSlider(hitboxCard, 64, "Hitbox size", MIN_HITBOX_SIZE, MAX_HITBOX_SIZE, state.hitboxSize,
    function(value) return tostring(math.floor(value + 0.5)) end,
    function(value) state.hitboxSize = math.floor(value + 0.5); if state.hitbox then applyHitbox() end end)

local setTransparencySlider = makeSlider(hitboxCard, 125, "Transparency", 0, 1, state.transparency,
    function(value) return tostring(math.floor(value * 100 + 0.5)) .. "%" end,
    function(value) state.transparency = value; if state.hitbox then applyHitbox() end end)

create("TextLabel", {
    Position = UDim2.fromOffset(14, 180),
    Size = UDim2.new(1, -90, 0, 28),
    BackgroundTransparency = 1,
    Text = "Cartoony Outline",
    TextColor3 = COLORS.text,
    Font = Enum.Font.GothamMedium,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
}, hitboxCard)
local outlineSwitch, outlineKnob = makeSwitch(hitboxCard, UDim2.new(1, -14, 0, 194))

local toggleCard = makeCard(78, 4)
create("TextLabel", {
    Position = UDim2.fromOffset(14, 10),
    Size = UDim2.new(1, -105, 0, 24),
    BackgroundTransparency = 1,
    Text = "Toggle GUI",
    TextColor3 = COLORS.text,
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
}, toggleCard)
create("TextLabel", {
    Position = UDim2.fromOffset(14, 36),
    Size = UDim2.new(1, -105, 0, 25),
    BackgroundTransparency = 1,
    Text = "Hides the GUI; enabled scripts keep running.",
    TextColor3 = COLORS.muted,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
}, toggleCard)
local keyButton = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -14, 0, 38),
    Size = UDim2.fromOffset(72, 34),
    BackgroundColor3 = COLORS.track,
    BorderSizePixel = 0,
    Text = "]",
    TextColor3 = COLORS.purpleLight,
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    AutoButtonColor = false,
}, toggleCard)
corner(keyButton, 8)

local uninjectCard = makeCard(68, 5)
create("TextLabel", {
    Position = UDim2.fromOffset(14, 8),
    Size = UDim2.new(1, -90, 0, 23),
    BackgroundTransparency = 1,
    Text = "Uninject",
    TextColor3 = COLORS.text,
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
}, uninjectCard)
create("TextLabel", {
    Position = UDim2.fromOffset(14, 31),
    Size = UDim2.new(1, -90, 0, 22),
    BackgroundTransparency = 1,
    Text = "Restore defaults and remove this script.",
    TextColor3 = COLORS.muted,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
}, uninjectCard)
local uninjectSwitch, uninjectKnob = makeSwitch(uninjectCard, UDim2.new(1, -14, 0, 34))

-- Three-second shutdown overlay.
local loadingOverlay = create("CanvasGroup", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.fromRGB(17, 12, 23),
    BackgroundTransparency = 0.18,
    BorderSizePixel = 0,
    GroupTransparency = 1,
    Visible = false,
    ZIndex = 50,
}, window)
corner(loadingOverlay, 18)

local loadingPanel = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(330, 164),
    BackgroundColor3 = Color3.fromRGB(44, 33, 58),
    BorderSizePixel = 0,
    ZIndex = 51,
}, loadingOverlay)
corner(loadingPanel, 14)
create("UIStroke", {Color = COLORS.purple, Thickness = 1, Transparency = 0.25}, loadingPanel)

local loadingPercent = create("TextLabel", {
    Position = UDim2.fromOffset(18, 15),
    Size = UDim2.new(1, -36, 0, 34),
    BackgroundTransparency = 1,
    Text = "0%",
    TextColor3 = COLORS.text,
    Font = Enum.Font.GothamBold,
    TextSize = 25,
    ZIndex = 52,
}, loadingPanel)
create("TextLabel", {
    Position = UDim2.fromOffset(18, 48),
    Size = UDim2.new(1, -36, 0, 20),
    BackgroundTransparency = 1,
    Text = "UNINJECTING",
    TextColor3 = COLORS.purpleLight,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    ZIndex = 52,
}, loadingPanel)
local loadingMessage = create("TextLabel", {
    Position = UDim2.fromOffset(18, 72),
    Size = UDim2.new(1, -36, 0, 19),
    BackgroundTransparency = 1,
    Text = "Stopping Auto Dive...",
    TextColor3 = COLORS.muted,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    ZIndex = 52,
}, loadingPanel)

local progressTrack = create("Frame", {
    Position = UDim2.fromOffset(20, 111),
    Size = UDim2.new(1, -40, 0, 13),
    BackgroundColor3 = Color3.fromRGB(27, 21, 35),
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 52,
}, loadingPanel)
corner(progressTrack, 7)
local progressFill = create("Frame", {
    Size = UDim2.fromScale(0, 1),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
    ZIndex = 53,
}, progressTrack)
corner(progressFill, 7)
create("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 130)),
        ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 184, 77)),
        ColorSequenceKeypoint.new(0.4, Color3.fromRGB(102, 224, 137)),
        ColorSequenceKeypoint.new(0.6, Color3.fromRGB(75, 191, 255)),
        ColorSequenceKeypoint.new(0.8, Color3.fromRGB(149, 101, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(236, 90, 220)),
    }),
}, progressFill)
create("TextLabel", {
    Position = UDim2.fromOffset(18, 133),
    Size = UDim2.new(1, -36, 0, 17),
    BackgroundTransparency = 1,
    Text = "Restoring game values safely",
    TextColor3 = COLORS.muted,
    Font = Enum.Font.Gotham,
    TextSize = 9,
    ZIndex = 52,
}, loadingPanel)

local KnitServices = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")
local DiveRemote = KnitServices:WaitForChild("BallService"):WaitForChild("RE"):WaitForChild("Dive")
local StaminaRemote = KnitServices:WaitForChild("StaminaService"):WaitForChild("RE"):WaitForChild("DecreaseStamina")
local MovementAnims = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("ReplicatedAnims"):WaitForChild("Movement")

local function setupCharacter(character)
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
end

local function getBall()
    local football = workspace:FindFirstChild("Football")
    if football then return football:FindFirstChild("BALL") or football:FindFirstChild("Hitbox") end
    for _, object in ipairs(workspace:GetChildren()) do
        if object.Name:lower():find("ball") then
            return object:FindFirstChild("BALL") or object:FindFirstChild("Hitbox") or (object:IsA("BasePart") and object)
        end
    end
end

local function isBallHeadingIntoGoal(ball)
    if not rootPart or not ball:IsA("BasePart") then return false end
    local velocity = ball.AssemblyLinearVelocity
    if velocity.Magnitude < MIN_SHOT_SPEED then return false end
    local relativeVelocity = rootPart.CFrame:VectorToObjectSpace(velocity)
    local relativePosition = rootPart.CFrame:PointToObjectSpace(ball.Position)
    if relativeVelocity.Z <= 1.5 then return false end
    local timeToGoal = math.abs(relativePosition.Z / relativeVelocity.Z)
    if timeToGoal > 3.5 then return false end
    local predictedX = relativePosition.X + relativeVelocity.X * timeToGoal
    local predictedY = ball.Position.Y + velocity.Y * timeToGoal - 0.5 * workspace.Gravity * timeToGoal ^ 2
    return math.abs(predictedX) < GOAL_WIDTH / 2 and predictedY > 0 and predictedY < GOAL_HEIGHT
end

local function cancelActiveDive()
    if activeDiveCleanup then activeDiveCleanup(); activeDiveCleanup = nil end
end

local function performDive()
    if not state.autoDive or not state.holdingF or tick() < state.lastDive or not rootPart or not humanoid then return end
    local ball = getBall()
    if not ball or not isBallHeadingIntoGoal(ball) then return end
    state.lastDive = tick() + DIVE_COOLDOWN
    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

    task.delay(0.001, function()
        if not state.autoDive or not state.holdingF or not rootPart or not humanoid or not ball.Parent then return end
        local velocity = ball.AssemblyLinearVelocity
        local distance = (ball.Position - rootPart.Position):Dot(rootPart.CFrame.LookVector)
        local predictionTime = math.clamp(math.abs(distance / math.max(velocity.Magnitude, 1)), 0.05, 0.45)
        local target = ball.Position + velocity * predictionTime + 0.5 * Vector3.new(0, -workspace.Gravity, 0) * predictionTime ^ 2
        local relative = rootPart.CFrame:PointToObjectSpace(target)
        local animationName, directionKey, velocityX, velocityZ = "DiveF", "f", 0, 0
        local vertical = DIVE_UP
        if math.abs(relative.X) > SILHOUETTE_WIDTH then
            if relative.X > 0 then animationName, directionKey, velocityX = "DiveR", "r", DIVE_SPEED
            else animationName, directionKey, velocityX = "DiveL", "l", -DIVE_SPEED end
        else
            velocityZ = -DIVE_SPEED
        end
        pcall(function() StaminaRemote:FireServer(10) end)
        pcall(function() DiveRemote:FireServer(target, 0.001, directionKey) end)
        pcall(function()
            local track = humanoid:LoadAnimation(MovementAnims:FindFirstChild(animationName))
            track.Priority = Enum.AnimationPriority.Action3
            track:Play(0.05, 1, 1.25)
        end)

        local ragdoll = player.Character and player.Character:FindFirstChild("IsRagdoll")
        rootPart.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0, 0, 0)
        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        local bodyVelocity = create("BodyVelocity", {MaxForce = Vector3.one * 500000}, rootPart)
        local bodyGyro = create("BodyGyro", {
            MaxTorque = Vector3.one * 9999999, D = 100, P = 1000, CFrame = rootPart.CFrame,
        }, rootPart)
        local heartbeat
        local cleaned = false
        local function cleanup()
            if cleaned then return end
            cleaned = true
            if heartbeat then heartbeat:Disconnect() end
            if bodyVelocity then bodyVelocity:Destroy() end
            if bodyGyro then bodyGyro:Destroy() end
            if rootPart then rootPart.CustomPhysicalProperties = nil end
            if humanoid and (not ragdoll or not ragdoll.Value) then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
        end
        activeDiveCleanup = cleanup
        heartbeat = RunService.Heartbeat:Connect(function(deltaTime)
            if not state.autoDive or not state.holdingF or not rootPart or (ragdoll and ragdoll.Value) then cleanup(); return end
            local worldMovement = rootPart.CFrame:VectorToWorldSpace(Vector3.new(velocityX, 0, velocityZ))
            bodyVelocity.Velocity = worldMovement + Vector3.new(0, vertical, 0)
            velocityX -= deltaTime * (velocityX > 0 and DECEL_VAL or -DECEL_VAL)
            velocityZ -= deltaTime * (velocityZ > 0 and DECEL_VAL or -DECEL_VAL)
            vertical -= deltaTime * GRAVITY_VAL
            if vertical <= -5 then cleanup() end
        end)
    end)
end

autoSwitch.MouseButton1Click:Connect(function()
    state.autoDive = not state.autoDive
    if not state.autoDive then state.holdingF = false; cancelActiveDive() end
    animateSwitch(autoSwitch, autoKnob, state.autoDive)
    setStatus(state.autoDive and "SCRIPT ACTIVATED" or "SCRIPT DISABLED", state.autoDive and COLORS.green or COLORS.red)
end)

hitboxSwitch.MouseButton1Click:Connect(function()
    state.hitbox = not state.hitbox
    animateSwitch(hitboxSwitch, hitboxKnob, state.hitbox)
    applyHitbox()
end)

outlineSwitch.MouseButton1Click:Connect(function()
    state.outline = not state.outline
    animateSwitch(outlineSwitch, outlineKnob, state.outline)
    applyHitbox()
end)

keyButton.MouseButton1Click:Connect(function()
    state.awaitingKey = true
    keyButton.Text = "press key..."
    tween(keyButton, 0.16, {BackgroundColor3 = COLORS.purple, TextColor3 = COLORS.text})
end)

local toggleAnimating = false
local uninjecting = false
local function toggleGui()
    if toggleAnimating or uninjecting then return end
    toggleAnimating = true
    if gui.Enabled then
        local animation = tween(window, 0.26, {
            Size = UDim2.fromOffset(0, 0),
            GroupTransparency = 1,
        }, Enum.EasingStyle.Quint)
        animation.Completed:Connect(function()
            gui.Enabled = false
            window.Size = UDim2.fromOffset(430, 430)
            window.GroupTransparency = 0
            toggleAnimating = false
        end)
    else
        gui.Enabled = true
        window.Size = UDim2.fromOffset(0, 0)
        window.GroupTransparency = 1
        local animation = tween(window, 0.32, {
            Size = UDim2.fromOffset(430, 430),
            GroupTransparency = 0,
        }, Enum.EasingStyle.Back)
        animation.Completed:Connect(function() toggleAnimating = false end)
    end
end

table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
    if state.awaitingKey and input.KeyCode ~= Enum.KeyCode.Unknown then
        state.toggleKey = input.KeyCode
        state.awaitingKey = false
        keyButton.Text = input.KeyCode == Enum.KeyCode.RightBracket and "]" or input.KeyCode.Name
        tween(keyButton, 0.16, {BackgroundColor3 = COLORS.track, TextColor3 = COLORS.purpleLight})
        return
    end
    if not processed and input.KeyCode == state.toggleKey then
        toggleGui()
        return
    end
    if not processed and input.KeyCode == Enum.KeyCode.F and state.autoDive then state.holdingF = true end
end))
table.insert(connections, UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.F then state.holdingF = false; cancelActiveDive() end
end))
table.insert(connections, RunService.Heartbeat:Connect(function()
    if state.autoDive and state.holdingF and rootPart then
        local ball = getBall()
        if ball and ball:IsA("BasePart") then
            local velocity = ball.AssemblyLinearVelocity
            local distance = (ball.Position - rootPart.Position):Dot(rootPart.CFrame.LookVector)
            local predictionTime = math.clamp(math.abs(distance / math.max(velocity.Magnitude, 1)), 0.05, 0.45)
            local target = ball.Position + velocity * predictionTime + 0.5 * Vector3.new(0, -workspace.Gravity, 0) * predictionTime ^ 2
            if (rootPart.Position - target).Magnitude < REACTION_STRETCH + velocity.Magnitude * 0.15 and isBallHeadingIntoGoal(ball) then
                performDive()
            end
        end
    end
end))
table.insert(connections, workspace.ChildAdded:Connect(function(child)
    if child.Name == "Football" then task.wait(0.1); applyHitbox() end
end))
table.insert(connections, player.CharacterAdded:Connect(setupCharacter))
setupCharacter(player.Character or player.CharacterAdded:Wait())

local dragging, dragStart, startPosition
topbar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging, dragStart, startPosition = true, input.Position, window.Position
    end
end)
topbar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)
table.insert(connections, UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        window.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
    end
end))

local function uninject()
    if uninjecting then return end
    uninjecting = true

    local function forceResetHitbox(hitbox)
        if not hitbox or not hitbox:IsA("BasePart") then return end
        hitbox.Size = Vector3.new(NORMAL_HITBOX_SIZE, NORMAL_HITBOX_SIZE, NORMAL_HITBOX_SIZE)
        hitbox.Transparency = 1
        local outline = hitbox:FindFirstChild("SighltlyCartoonOutline")
        if outline then outline:Destroy() end
    end

    local function forceResetEverything()
        state.autoDive = false
        state.holdingF = false
        state.hitbox = false
        state.outline = false
        cancelActiveDive()
        forceResetHitbox(getFootballHitbox())
        local football = workspace:FindFirstChild("Football")
        if football then
            for _, object in ipairs(football:GetDescendants()) do
                if object:IsA("BasePart") and object.Name == "Hitbox" then
                    forceResetHitbox(object)
                end
            end
        end
        for hitbox in pairs(originalHitboxes) do forceResetHitbox(hitbox) end
    end

    -- Disable all features before showing progress, then keep verifying the reset.
    state.autoDive, state.holdingF, state.hitbox, state.outline = false, false, false, false
    cancelActiveDive()
    state.hitboxSize = NORMAL_HITBOX_SIZE
    state.transparency = 1
    setHitboxSizeSlider(NORMAL_HITBOX_SIZE)
    setTransparencySlider(1)
    forceResetEverything()
    autoSwitch.BackgroundColor3, autoKnob.Position = COLORS.red, UDim2.fromOffset(3, 3)
    hitboxSwitch.BackgroundColor3, hitboxKnob.Position = COLORS.red, UDim2.fromOffset(3, 3)
    outlineSwitch.BackgroundColor3, outlineKnob.Position = COLORS.red, UDim2.fromOffset(3, 3)
    setStatus("SCRIPT DISABLED", COLORS.red)

    local oldBlur = Lighting:FindFirstChild("SighltlyShutdownBlur")
    if oldBlur then oldBlur:Destroy() end
    local blur = create("BlurEffect", {Name = "SighltlyShutdownBlur", Size = 0}, Lighting)
    tween(blur, 0.25, {Size = 18})

    loadingOverlay.Visible = true
    loadingOverlay.GroupTransparency = 1
    loadingPanel.Size = UDim2.fromOffset(292, 138)
    progressFill.Size = UDim2.fromScale(0, 1)
    loadingPercent.Text = "0%"
    loadingMessage.Text = "Stopping Auto Dive..."
    tween(loadingOverlay, 0.2, {GroupTransparency = 0})
    tween(loadingPanel, 0.3, {Size = UDim2.fromOffset(330, 164)}, Enum.EasingStyle.Back)

    local started = os.clock()
    local duration = 3
    local lastVerification = 0
    while true do
        local elapsed = os.clock() - started
        local ratio = math.clamp(elapsed / duration, 0, 1)
        local percent = math.floor(ratio * 100 + 0.5)
        loadingPercent.Text = tostring(percent) .. "%"
        progressFill.Size = UDim2.fromScale(ratio, 1)

        if ratio < 0.34 then
            loadingMessage.Text = "Stopping Auto Dive..."
        elseif ratio < 0.68 then
            loadingMessage.Text = "Restoring hitbox and transparency..."
        elseif ratio < 0.95 then
            loadingMessage.Text = "Removing outline and connections..."
        else
            loadingMessage.Text = "Shutdown complete"
        end

        if elapsed - lastVerification >= 0.08 then
            forceResetEverything()
            lastVerification = elapsed
        end
        if ratio >= 1 then break end
        RunService.RenderStepped:Wait()
    end

    forceResetEverything()
    loadingPercent.Text = "100%"
    progressFill.Size = UDim2.fromScale(1, 1)
    for _, connection in ipairs(connections) do connection:Disconnect() end

    tween(blur, 0.22, {Size = 0})
    local closeAnimation = tween(window, 0.34, {
        Size = UDim2.fromOffset(0, 0),
        GroupTransparency = 1,
    }, Enum.EasingStyle.Quint)
    closeAnimation.Completed:Wait()
    forceResetEverything()
    if blur then blur:Destroy() end
    gui:Destroy()
end

uninjectSwitch.MouseButton1Click:Connect(function()
    animateSwitch(uninjectSwitch, uninjectKnob, true)
    setStatus("UNINJECTING...", COLORS.red)
    task.spawn(uninject)
end)

window.Size = UDim2.fromOffset(0, 0)
window.GroupTransparency = 1
tween(window, 0.36, {Size = UDim2.fromOffset(430, 430), GroupTransparency = 0}, Enum.EasingStyle.Back)

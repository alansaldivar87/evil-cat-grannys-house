--[[
	VictoryCelebration - Enhances the boss defeat sequence with spectacular effects
	Handles: confetti particles, screen flash to white, fireworks particle bursts
	Triggered when BossDefeated / VictoryCelebration remote fires.
	All effects are client-side for performance.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LocalPlayer = Players.LocalPlayer

-- ==================
-- VICTORY FLASH OVERLAY
-- ==================

local victoryGui = Instance.new("ScreenGui")
victoryGui.Name = "VictoryCelebration"
victoryGui.ResetOnSpawn = false
victoryGui.IgnoreGuiInset = true
victoryGui.DisplayOrder = 15
victoryGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- White flash overlay
local flashOverlay = Instance.new("Frame")
flashOverlay.Name = "WhiteFlash"
flashOverlay.Size = UDim2.new(1, 0, 1, 0)
flashOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
flashOverlay.BackgroundTransparency = 1
flashOverlay.BorderSizePixel = 0
flashOverlay.Parent = victoryGui

-- Victory text (shows after the flash)
local victoryText = Instance.new("TextLabel")
victoryText.Name = "VictoryText"
victoryText.Size = UDim2.new(0, 700, 0, 100)
victoryText.Position = UDim2.new(0.5, 0, 0.35, 0)
victoryText.AnchorPoint = Vector2.new(0.5, 0.5)
victoryText.BackgroundTransparency = 1
victoryText.TextColor3 = Color3.fromRGB(255, 215, 0) -- Gold
victoryText.TextStrokeColor3 = Color3.fromRGB(180, 100, 0)
victoryText.TextStrokeTransparency = 0
victoryText.Font = Enum.Font.GothamBold
victoryText.TextSize = 56
victoryText.Text = "VICTORY!"
victoryText.TextTransparency = 1
victoryText.TextScaled = false
victoryText.Parent = victoryGui

local subtitleText = Instance.new("TextLabel")
subtitleText.Name = "Subtitle"
subtitleText.Size = UDim2.new(0, 600, 0, 50)
subtitleText.Position = UDim2.new(0.5, 0, 0.45, 0)
subtitleText.AnchorPoint = Vector2.new(0.5, 0.5)
subtitleText.BackgroundTransparency = 1
subtitleText.TextColor3 = Color3.fromRGB(255, 240, 200)
subtitleText.TextStrokeTransparency = 0.3
subtitleText.Font = Enum.Font.GothamBold
subtitleText.TextSize = 24
subtitleText.Text = "The Evil Cat has been defeated!"
subtitleText.TextTransparency = 1
subtitleText.Parent = victoryGui

-- ==================
-- CONFETTI SYSTEM
-- ==================

local confettiColors = {
	Color3.fromRGB(255, 50, 50),   -- Red
	Color3.fromRGB(50, 200, 50),   -- Green
	Color3.fromRGB(50, 100, 255),  -- Blue
	Color3.fromRGB(255, 215, 0),   -- Gold
	Color3.fromRGB(255, 100, 200), -- Pink
	Color3.fromRGB(100, 255, 255), -- Cyan
	Color3.fromRGB(255, 165, 0),   -- Orange
	Color3.fromRGB(200, 100, 255), -- Purple
}

local function createConfettiEmitter(): Part
	local camera = workspace.CurrentCamera

	local emitterPart = Instance.new("Part")
	emitterPart.Name = "ConfettiEmitter"
	emitterPart.Transparency = 1
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.Anchored = true
	emitterPart.Size = Vector3.new(30, 1, 30) -- Wide area for confetti spread

	-- Position above the camera
	if camera then
		emitterPart.CFrame = camera.CFrame * CFrame.new(0, 15, -5)
	end

	-- Color sequence from our confetti colors (cycle through them)
	local colorKeypoints = {}
	for i, color in confettiColors do
		local t = (i - 1) / (#confettiColors - 1)
		table.insert(colorKeypoints, ColorSequenceKeypoint.new(t, color))
	end

	local confetti = Instance.new("ParticleEmitter")
	confetti.Name = "Confetti"
	confetti.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	confetti.Color = ColorSequence.new(colorKeypoints)
	confetti.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	confetti.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	confetti.Lifetime = NumberRange.new(3, 5)
	confetti.Rate = 80
	confetti.Speed = NumberRange.new(2, 6)
	confetti.SpreadAngle = Vector2.new(180, 180)
	confetti.RotSpeed = NumberRange.new(-200, 200)
	confetti.Rotation = NumberRange.new(0, 360)
	confetti.Acceleration = Vector3.new(0, -8, 0) -- Gravity pull
	confetti.LightEmission = 0.4
	confetti.LightInfluence = 0.6
	confetti.Parent = emitterPart

	emitterPart.Parent = workspace

	return emitterPart
end

-- ==================
-- FIREWORKS SYSTEM
-- ==================

local function createFireworkBurst(position: Vector3, color: Color3)
	local burstPart = Instance.new("Part")
	burstPart.Name = "FireworkBurst"
	burstPart.Transparency = 1
	burstPart.CanCollide = false
	burstPart.CanQuery = false
	burstPart.CanTouch = false
	burstPart.Anchored = true
	burstPart.Size = Vector3.new(1, 1, 1)
	burstPart.Position = position

	-- Main burst emitter
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "Burst"
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.3))
	burst.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.3, 0.8),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	burst.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.6, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	burst.Lifetime = NumberRange.new(0.8, 1.5)
	burst.Rate = 0 -- We will use Emit()
	burst.Speed = NumberRange.new(15, 30)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.RotSpeed = NumberRange.new(-100, 100)
	burst.Acceleration = Vector3.new(0, -15, 0) -- Droop after burst
	burst.LightEmission = 1
	burst.LightInfluence = 0
	burst.Drag = 3
	burst.Parent = burstPart

	-- Glow light at burst center
	local flashLight = Instance.new("PointLight")
	flashLight.Color = color
	flashLight.Brightness = 4
	flashLight.Range = 30
	flashLight.Parent = burstPart

	burstPart.Parent = workspace

	-- Emit burst
	burst:Emit(50)

	-- Fade the light
	local lightFade = TweenService:Create(flashLight, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = 0,
	})
	lightFade:Play()

	-- Clean up after particles die
	task.delay(3, function()
		burstPart:Destroy()
	end)
end

local function launchFireworksSequence()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	-- Launch multiple fireworks over several seconds
	for i = 1, 12 do
		task.delay(i * 0.6 + math.random() * 0.4, function()
			if not camera then
				return
			end

			-- Random position in front of and above the camera
			local offset = Vector3.new(
				(math.random() - 0.5) * 80,
				math.random() * 30 + 20,
				(math.random() - 0.5) * 80 - 30
			)
			local worldPos = camera.CFrame.Position + offset

			-- Random color from confetti palette
			local color = confettiColors[math.random(1, #confettiColors)]
			createFireworkBurst(worldPos, color)
		end)
	end
end

-- ==================
-- VICTORY SEQUENCE
-- ==================

local celebrationActive = false

local function playCelebration()
	if celebrationActive then
		return
	end
	celebrationActive = true

	-- Phase 1: White flash (0 - 1.5s)
	flashOverlay.BackgroundTransparency = 1

	-- Quick flash to near-white
	local flashIn = TweenService:Create(flashOverlay, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.05,
	})
	flashIn:Play()
	flashIn.Completed:Wait()

	-- Hold briefly
	task.wait(0.3)

	-- Slow fade from white to reveal scene
	local flashOut = TweenService:Create(flashOverlay, TweenInfo.new(2.0, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	})
	flashOut:Play()

	-- Phase 2: Confetti (starts during fade)
	task.wait(0.5)
	local confettiEmitter = createConfettiEmitter()

	-- Phase 3: Victory text fades in
	task.wait(0.5)
	local textIn = TweenService:Create(victoryText, TweenInfo.new(1.0, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextTransparency = 0,
	})
	textIn:Play()

	task.wait(0.5)
	local subIn = TweenService:Create(subtitleText, TweenInfo.new(1.0), {
		TextTransparency = 0,
	})
	subIn:Play()

	-- Phase 4: Fireworks sequence
	task.wait(1.0)
	launchFireworksSequence()

	-- Second wave of fireworks
	task.delay(5, function()
		launchFireworksSequence()
	end)

	-- Phase 5: Pulse the victory text color
	task.spawn(function()
		local goldColors = {
			Color3.fromRGB(255, 215, 0),
			Color3.fromRGB(255, 240, 100),
			Color3.fromRGB(255, 200, 50),
		}
		local colorIndex = 1

		while celebrationActive do
			colorIndex = colorIndex % #goldColors + 1
			local colorTween = TweenService:Create(victoryText, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				TextColor3 = goldColors[colorIndex],
			})
			colorTween:Play()
			task.wait(0.8)
		end
	end)

	-- Stop confetti after 15 seconds
	task.delay(15, function()
		if confettiEmitter and confettiEmitter.Parent then
			local emitter = confettiEmitter:FindFirstChild("Confetti")
			if emitter then
				emitter.Rate = 0 -- Stop emitting, let existing particles die
			end
			task.delay(5, function()
				if confettiEmitter.Parent then
					confettiEmitter:Destroy()
				end
			end)
		end
	end)
end

-- ==================
-- EVENT LISTENERS
-- ==================

Remotes[Constants.EVENT_VICTORY_CELEBRATION].OnClientEvent:Connect(function()
	task.spawn(playCelebration)
end)

-- Also trigger on BossDefeated as a fallback
Remotes[Constants.EVENT_BOSS_DEFEATED].OnClientEvent:Connect(function()
	-- Small delay to let UIManager handle its victory text first
	task.delay(0.5, function()
		if not celebrationActive then
			task.spawn(playCelebration)
		end
	end)
end)

print("[VictoryCelebration] Victory celebration system initialized")

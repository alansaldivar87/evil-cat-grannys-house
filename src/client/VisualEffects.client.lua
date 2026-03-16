--[[
	VisualEffects - Client-side visual effects for horror atmosphere
	Handles: flickering lights, lightning flashes, dust particles, cat eye glow,
	         blood splatter vignette, dynamic fog zones, screen color grading
	All effects are purely client-side for performance.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Utils = require(Shared:WaitForChild("Utils"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LocalPlayer = Players.LocalPlayer

-- ==================
-- SCREEN COLOR GRADING
-- ==================

local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Name = "HorrorGrade"
colorCorrection.Brightness = -0.03
colorCorrection.Contrast = 0.15
colorCorrection.Saturation = -0.35
colorCorrection.TintColor = Color3.fromRGB(230, 255, 230) -- Slight sickly green tint
colorCorrection.Parent = Lighting

-- ==================
-- FLICKERING LIGHTS
-- ==================

-- Track active flicker lights and their original brightness
local flickerLights: { { light: PointLight, baseBrightness: number, timer: number, nextFlicker: number } } = {}

local function registerFlickerLight(instance: Instance)
	-- The tag can be on the PointLight itself or on its parent Part
	local light: PointLight? = nil
	if instance:IsA("PointLight") then
		light = instance
	elseif instance:IsA("BasePart") then
		light = instance:FindFirstChildOfClass("PointLight")
	end

	if not light then
		return
	end

	table.insert(flickerLights, {
		light = light,
		baseBrightness = light.Brightness,
		timer = 0,
		nextFlicker = math.random() * 0.5 + 0.05,
	})
end

-- Register existing flicker lights
for _, inst in CollectionService:GetTagged(Constants.TAG_FLICKER_LIGHT) do
	registerFlickerLight(inst)
end

CollectionService:GetInstanceAddedSignal(Constants.TAG_FLICKER_LIGHT):Connect(function(inst)
	registerFlickerLight(inst)
end)

-- Clean up removed flicker lights
CollectionService:GetInstanceRemovedSignal(Constants.TAG_FLICKER_LIGHT):Connect(function(inst)
	for i = #flickerLights, 1, -1 do
		local data = flickerLights[i]
		if data.light == inst or (data.light.Parent and data.light.Parent == inst) then
			table.remove(flickerLights, i)
		end
	end
end)

-- ==================
-- LIGHTNING FLASHES
-- ==================

-- Screen overlay for lightning flash
local lightningGui = Instance.new("ScreenGui")
lightningGui.Name = "LightningFlash"
lightningGui.ResetOnSpawn = false
lightningGui.IgnoreGuiInset = true
lightningGui.DisplayOrder = 5
lightningGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local lightningOverlay = Instance.new("Frame")
lightningOverlay.Name = "Flash"
lightningOverlay.Size = UDim2.new(1, 0, 1, 0)
lightningOverlay.BackgroundColor3 = Color3.fromRGB(200, 210, 255) -- Cool blue-white
lightningOverlay.BackgroundTransparency = 1
lightningOverlay.BorderSizePixel = 0
lightningOverlay.Parent = lightningGui

local lightningTimer = 0
local lightningInterval = math.random(15, 40) -- Seconds between lightning strikes

local function triggerLightning()
	-- Brief bright flash on Lighting
	local originalBrightness = Lighting.Brightness
	local originalAmbient = Lighting.Ambient

	-- Double flash pattern (realistic lightning)
	for flash = 1, 2 do
		lightningOverlay.BackgroundTransparency = 0.3
		Lighting.Brightness = originalBrightness + 3
		Lighting.Ambient = Color3.fromRGB(180, 180, 200)

		task.wait(0.05 + math.random() * 0.05)

		lightningOverlay.BackgroundTransparency = 1
		Lighting.Brightness = originalBrightness
		Lighting.Ambient = originalAmbient

		if flash == 1 then
			task.wait(0.08 + math.random() * 0.1) -- Gap between double flash
		end
	end

	-- Final lingering flash
	lightningOverlay.BackgroundTransparency = 0.6
	local fadeOut = TweenService:Create(lightningOverlay, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	})
	fadeOut:Play()
end

-- ==================
-- DUST / PARTICLE EFFECTS
-- ==================

-- Attach floating dust motes to the player camera area
local dustPart = Instance.new("Part")
dustPart.Name = "DustEmitterPart"
dustPart.Transparency = 1
dustPart.CanCollide = false
dustPart.Anchored = true
dustPart.Size = Vector3.new(1, 1, 1)
dustPart.Parent = workspace.CurrentCamera

local dustEmitter = Instance.new("ParticleEmitter")
dustEmitter.Name = "DustMotes"
dustEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds" -- Built-in sparkle texture
dustEmitter.Color = ColorSequence.new(Color3.fromRGB(200, 190, 170)) -- Warm dust color
dustEmitter.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.02),
	NumberSequenceKeypoint.new(0.5, 0.04),
	NumberSequenceKeypoint.new(1, 0.01),
})
dustEmitter.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.8),
	NumberSequenceKeypoint.new(0.4, 0.5),
	NumberSequenceKeypoint.new(1, 1),
})
dustEmitter.Lifetime = NumberRange.new(4, 8)
dustEmitter.Rate = 12
dustEmitter.Speed = NumberRange.new(0.2, 0.8)
dustEmitter.SpreadAngle = Vector2.new(180, 180) -- Emit in all directions
dustEmitter.RotSpeed = NumberRange.new(-30, 30)
dustEmitter.Rotation = NumberRange.new(0, 360)
dustEmitter.LightEmission = 0.1
dustEmitter.LightInfluence = 1
dustEmitter.Parent = dustPart

-- ==================
-- CAT EYE GLOW (Billboard GUI)
-- ==================

-- Track cat eye billboards so we can clean them up
local catEyeGuis: { [Model]: BillboardGui } = {}

local function createEyeGlow(catModel: Model): BillboardGui?
	local rootPart = catModel.PrimaryPart or catModel:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return nil
	end

	-- Find head if available, otherwise use root part
	local attachPart = catModel:FindFirstChild("Head") or rootPart

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EyeGlow"
	billboard.Size = UDim2.new(0, 60, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 0.5, -0.3) -- Slightly in front of head
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 120
	billboard.LightInfluence = 0 -- Eyes glow regardless of lighting
	billboard.Adornee = attachPart
	billboard.Parent = attachPart

	-- Left eye
	local leftEye = Instance.new("Frame")
	leftEye.Name = "LeftEye"
	leftEye.Size = UDim2.new(0, 10, 0, 14)
	leftEye.Position = UDim2.new(0.3, 0, 0.5, 0)
	leftEye.AnchorPoint = Vector2.new(0.5, 0.5)
	leftEye.BackgroundColor3 = Color3.fromRGB(255, 230, 0) -- Bright yellow
	leftEye.BorderSizePixel = 0
	leftEye.Parent = billboard

	local leftCorner = Instance.new("UICorner")
	leftCorner.CornerRadius = UDim.new(1, 0)
	leftCorner.Parent = leftEye

	-- Left eye inner glow (pupil slit)
	local leftPupil = Instance.new("Frame")
	leftPupil.Name = "Pupil"
	leftPupil.Size = UDim2.new(0, 3, 0, 12)
	leftPupil.Position = UDim2.new(0.5, 0, 0.5, 0)
	leftPupil.AnchorPoint = Vector2.new(0.5, 0.5)
	leftPupil.BackgroundColor3 = Color3.fromRGB(20, 20, 0)
	leftPupil.BorderSizePixel = 0
	leftPupil.Parent = leftEye

	local leftPupilCorner = Instance.new("UICorner")
	leftPupilCorner.CornerRadius = UDim.new(0, 2)
	leftPupilCorner.Parent = leftPupil

	-- Right eye
	local rightEye = Instance.new("Frame")
	rightEye.Name = "RightEye"
	rightEye.Size = UDim2.new(0, 10, 0, 14)
	rightEye.Position = UDim2.new(0.7, 0, 0.5, 0)
	rightEye.AnchorPoint = Vector2.new(0.5, 0.5)
	rightEye.BackgroundColor3 = Color3.fromRGB(255, 230, 0)
	rightEye.BorderSizePixel = 0
	rightEye.Parent = billboard

	local rightCorner = Instance.new("UICorner")
	rightCorner.CornerRadius = UDim.new(1, 0)
	rightCorner.Parent = rightEye

	local rightPupil = Instance.new("Frame")
	rightPupil.Name = "Pupil"
	rightPupil.Size = UDim2.new(0, 3, 0, 12)
	rightPupil.Position = UDim2.new(0.5, 0, 0.5, 0)
	rightPupil.AnchorPoint = Vector2.new(0.5, 0.5)
	rightPupil.BackgroundColor3 = Color3.fromRGB(20, 20, 0)
	rightPupil.BorderSizePixel = 0
	rightPupil.Parent = rightEye

	local rightPupilCorner = Instance.new("UICorner")
	rightPupilCorner.CornerRadius = UDim.new(0, 2)
	rightPupilCorner.Parent = rightPupil

	-- Add a subtle PointLight to the cat's head so the eyes cast a faint glow
	local eyeLight = Instance.new("PointLight")
	eyeLight.Name = "EyeLight"
	eyeLight.Color = Color3.fromRGB(255, 220, 0)
	eyeLight.Brightness = 0.6
	eyeLight.Range = 6
	eyeLight.Parent = attachPart

	return billboard
end

-- Register eye glow on existing and new cats
local function onCatAdded(catModel: Instance)
	if not catModel:IsA("Model") then
		return
	end
	if catEyeGuis[catModel] then
		return
	end
	-- Wait a brief moment for model to fully load
	task.defer(function()
		local gui = createEyeGlow(catModel)
		if gui then
			catEyeGuis[catModel] = gui
		end
	end)
end

for _, cat in CollectionService:GetTagged(Constants.TAG_EVIL_CAT) do
	onCatAdded(cat)
end
CollectionService:GetInstanceAddedSignal(Constants.TAG_EVIL_CAT):Connect(onCatAdded)

CollectionService:GetInstanceRemovedSignal(Constants.TAG_EVIL_CAT):Connect(function(inst)
	if catEyeGuis[inst] then
		catEyeGuis[inst]:Destroy()
		catEyeGuis[inst] = nil
	end
end)

-- ==================
-- BLOOD SPLATTER VIGNETTE
-- ==================

local vignetteGui = Instance.new("ScreenGui")
vignetteGui.Name = "BloodVignette"
vignetteGui.ResetOnSpawn = false
vignetteGui.IgnoreGuiInset = true
vignetteGui.DisplayOrder = 8
vignetteGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Create vignette edges (4 gradient frames forming a border)
local function createVignetteEdge(name: string, size: UDim2, position: UDim2, anchor: Vector2, gradientRotation: number): Frame
	local edge = Instance.new("Frame")
	edge.Name = name
	edge.Size = size
	edge.Position = position
	edge.AnchorPoint = anchor
	edge.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
	edge.BackgroundTransparency = 1
	edge.BorderSizePixel = 0
	edge.Parent = vignetteGui

	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0.8),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Rotation = gradientRotation
	gradient.Parent = edge

	return edge
end

local vignetteEdges = {
	createVignetteEdge("Top", UDim2.new(1, 0, 0.25, 0), UDim2.new(0, 0, 0, 0), Vector2.new(0, 0), 90),
	createVignetteEdge("Bottom", UDim2.new(1, 0, 0.25, 0), UDim2.new(0, 0, 1, 0), Vector2.new(0, 1), 270),
	createVignetteEdge("Left", UDim2.new(0.2, 0, 1, 0), UDim2.new(0, 0, 0, 0), Vector2.new(0, 0), 0),
	createVignetteEdge("Right", UDim2.new(0.2, 0, 1, 0), UDim2.new(1, 0, 0, 0), Vector2.new(1, 0), 180),
}

local function showBloodVignette()
	-- Flash all edges visible then fade out
	for _, edge in vignetteEdges do
		edge.BackgroundTransparency = 0.3
	end

	task.wait(0.1)

	for _, edge in vignetteEdges do
		local fadeOut = TweenService:Create(edge, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		})
		fadeOut:Play()
	end
end

Remotes[Constants.EVENT_PLAYER_DAMAGED].OnClientEvent:Connect(function()
	showBloodVignette()
end)

-- Also trigger on health decrease from any source
LocalPlayer.CharacterAdded:Connect(function(character)
	local humanoid = character:WaitForChild("Humanoid")
	local lastHealth = humanoid.Health

	humanoid.HealthChanged:Connect(function(newHealth)
		if newHealth < lastHealth then
			showBloodVignette()
		end
		lastHealth = newHealth
	end)
end)

-- ==================
-- DYNAMIC FOG ZONES
-- ==================

local defaultFogEnd = Lighting.FogEnd
local defaultFogStart = Lighting.FogStart
local currentFogTarget = defaultFogEnd
local isInFogZone = false

-- ==================
-- MAIN RENDER LOOP
-- ==================

RunService.RenderStepped:Connect(function(dt)
	local character = LocalPlayer.Character
	local camera = workspace.CurrentCamera

	-- ---- Dust particle follows camera ----
	if camera then
		dustPart.CFrame = camera.CFrame * CFrame.new(0, 0, -8) -- Slightly in front of camera
	end

	-- ---- Flickering lights ----
	for _, data in flickerLights do
		data.timer = data.timer + dt
		if data.timer >= data.nextFlicker then
			data.timer = 0
			-- Randomize next flicker interval for organic feel
			data.nextFlicker = math.random() * 0.3 + 0.03

			-- Random brightness between 20% and 120% of base
			local flicker = data.baseBrightness * (0.2 + math.random() * 1.0)

			-- Occasionally go very dim or off briefly
			if math.random() < 0.08 then
				flicker = 0 -- Momentary blackout
				data.nextFlicker = math.random() * 0.1 + 0.02 -- Quick recovery
			elseif math.random() < 0.05 then
				flicker = data.baseBrightness * 1.5 -- Bright surge
			end

			data.light.Brightness = flicker
		end
	end

	-- ---- Lightning timer ----
	lightningTimer = lightningTimer + dt
	if lightningTimer >= lightningInterval then
		lightningTimer = 0
		lightningInterval = math.random(20, 50) -- Randomize next interval
		task.spawn(triggerLightning)
	end

	-- ---- Dynamic fog zones ----
	if character then
		local playerPos = Utils.getCharacterPosition(character)
		if playerPos then
			local inZone = false
			local closestFogEnd = defaultFogEnd

			for _, zone in CollectionService:GetTagged(Constants.TAG_FOG_ZONE) do
				if zone:IsA("BasePart") then
					-- Check if player is inside the zone bounding box
					local relativePos = zone.CFrame:PointToObjectSpace(playerPos)
					local halfSize = zone.Size / 2
					if math.abs(relativePos.X) <= halfSize.X
						and math.abs(relativePos.Y) <= halfSize.Y
						and math.abs(relativePos.Z) <= halfSize.Z then
						inZone = true
						-- Use zone's FogEnd attribute, default to 60 for thick fog
						local zoneFogEnd = zone:GetAttribute("FogEnd") or 60
						if zoneFogEnd < closestFogEnd then
							closestFogEnd = zoneFogEnd
						end
					end
				end
			end

			if inZone then
				currentFogTarget = closestFogEnd
			else
				currentFogTarget = defaultFogEnd
			end

			-- Smooth fog transition
			Lighting.FogEnd = Lighting.FogEnd + (currentFogTarget - Lighting.FogEnd) * math.min(dt * 2, 1)
		end
	end

	-- ---- Cat eye glow pulsing ----
	local pulseTime = tick()
	for catModel, gui in catEyeGuis do
		if gui.Parent then
			-- Subtle brightness pulse on the eyes
			local pulse = 0.85 + math.sin(pulseTime * 3 + catModel:GetFullName():len()) * 0.15
			for _, child in gui:GetChildren() do
				if child:IsA("Frame") and (child.Name == "LeftEye" or child.Name == "RightEye") then
					child.BackgroundColor3 = Color3.fromRGB(
						math.floor(255 * pulse),
						math.floor(230 * pulse),
						0
					)
				end
			end
		end
	end
end)

print("[VisualEffects] Visual effects system initialized")
print("[VisualEffects] Tag Parts with 'FlickerLight' for flickering PointLights")
print("[VisualEffects] Tag Parts with 'FogZone' for thick fog areas (set 'FogEnd' attribute)")

--[[
	LightingManager - Advanced horror lighting setup
	Handles: professional post-processing effects, dynamic room-based brightness,
	         bloom, depth of field, and atmospheric adjustments
	All effects are client-side post-processing for performance.
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

local LocalPlayer = Players.LocalPlayer

-- ==================
-- ATMOSPHERE SETUP
-- ==================

-- Add Atmosphere effect for volumetric-looking environment
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if not atmosphere then
	atmosphere = Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
end

atmosphere.Density = 0.35
atmosphere.Offset = 0.2
atmosphere.Color = Color3.fromRGB(30, 25, 35) -- Dark purple-ish haze
atmosphere.Decay = Color3.fromRGB(50, 45, 55) -- Subtle purple decay
atmosphere.Glare = 0
atmosphere.Haze = 3

-- ==================
-- BLOOM EFFECT
-- ==================

-- Subtle bloom makes neon parts (weapon, cat eyes, checkpoints) glow beautifully
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
if not bloom then
	bloom = Instance.new("BloomEffect")
	bloom.Parent = Lighting
end

bloom.Intensity = 0.5
bloom.Size = 18
bloom.Threshold = 1.2 -- Only very bright things bloom (neon parts, cat eyes)

-- ==================
-- DEPTH OF FIELD
-- ==================

-- Very subtle cinematic depth of field
local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
if not dof then
	dof = Instance.new("DepthOfFieldEffect")
	dof.Parent = Lighting
end

dof.FarIntensity = 0.08 -- Very subtle far blur
dof.FocusDistance = 40
dof.InFocusRadius = 30
dof.NearIntensity = 0 -- No near blur to avoid discomfort

-- ==================
-- ROOM-BASED DYNAMIC BRIGHTNESS
-- ==================

-- Room lighting presets: keyed by RoomName attribute on tagged "Room" parts
-- Each room can have custom ambient, brightness, and fog settings
local roomPresets = {
	-- Dark, claustrophobic rooms
	Basement = {
		Ambient = Color3.fromRGB(5, 5, 10),
		Brightness = 0.15,
		FogEnd = 80,
		FogColor = Color3.fromRGB(3, 3, 8),
	},
	Cellar = {
		Ambient = Color3.fromRGB(5, 5, 10),
		Brightness = 0.15,
		FogEnd = 70,
		FogColor = Color3.fromRGB(3, 3, 8),
	},
	Attic = {
		Ambient = Color3.fromRGB(10, 8, 12),
		Brightness = 0.25,
		FogEnd = 120,
		FogColor = Color3.fromRGB(8, 6, 10),
	},

	-- Medium-lit rooms
	Kitchen = {
		Ambient = Color3.fromRGB(20, 18, 15),
		Brightness = 0.6,
		FogEnd = 180,
		FogColor = Color3.fromRGB(10, 9, 8),
	},
	LivingRoom = {
		Ambient = Color3.fromRGB(18, 15, 12),
		Brightness = 0.5,
		FogEnd = 160,
		FogColor = Color3.fromRGB(8, 7, 6),
	},
	DiningRoom = {
		Ambient = Color3.fromRGB(18, 15, 12),
		Brightness = 0.5,
		FogEnd = 160,
		FogColor = Color3.fromRGB(8, 7, 6),
	},

	-- Brighter rooms
	Bathroom = {
		Ambient = Color3.fromRGB(22, 22, 25),
		Brightness = 0.7,
		FogEnd = 200,
		FogColor = Color3.fromRGB(12, 12, 15),
	},

	-- Outside / transition areas
	Hallway = {
		Ambient = Color3.fromRGB(10, 10, 14),
		Brightness = 0.3,
		FogEnd = 120,
		FogColor = Color3.fromRGB(5, 5, 8),
	},
	Stairway = {
		Ambient = Color3.fromRGB(12, 10, 14),
		Brightness = 0.35,
		FogEnd = 130,
		FogColor = Color3.fromRGB(6, 5, 8),
	},

	-- Boss arena - dramatic red-tinted lighting
	BossRoom = {
		Ambient = Color3.fromRGB(20, 5, 5),
		Brightness = 0.4,
		FogEnd = 150,
		FogColor = Color3.fromRGB(15, 3, 3),
	},
}

-- Default (outdoor / no room) settings - matches the project.json Lighting config
local defaultLighting = {
	Ambient = Color3.new(0.1, 0.1, 0.12),
	Brightness = 0.5,
	FogEnd = 200,
	FogColor = Color3.new(0.05, 0.05, 0.08),
}

local currentRoom = ""
local transitionTween: Tween? = nil

-- Tween lighting properties smoothly
local function tweenLighting(targetPreset: { [string]: any }, duration: number)
	-- Cancel any in-progress transition
	if transitionTween then
		transitionTween:Cancel()
		transitionTween = nil
	end

	-- TweenService can tween Lighting properties directly
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	-- Tween ambient and brightness
	local ambientTween = TweenService:Create(Lighting, tweenInfo, {
		Ambient = targetPreset.Ambient,
		Brightness = targetPreset.Brightness,
		FogColor = targetPreset.FogColor,
	})
	ambientTween:Play()
	transitionTween = ambientTween

	-- FogEnd is handled by VisualEffects fog zones, so only adjust if we are NOT
	-- currently in a FogZone (fog zones override room fog)
	-- We set the default fog end that VisualEffects will return to
end

-- ==================
-- ROOM DETECTION LOOP
-- ==================

RunService.RenderStepped:Connect(function()
	local character = LocalPlayer.Character
	if not character then
		return
	end

	local playerPos = Utils.getCharacterPosition(character)
	if not playerPos then
		return
	end

	-- Check which Room part the player is inside
	local detectedRoom = ""
	for _, room in CollectionService:GetTagged(Constants.TAG_ROOM) do
		if room:IsA("BasePart") then
			-- Point-in-box check using the Room part's CFrame and Size
			local relativePos = room.CFrame:PointToObjectSpace(playerPos)
			local halfSize = room.Size / 2
			if math.abs(relativePos.X) <= halfSize.X
				and math.abs(relativePos.Y) <= halfSize.Y
				and math.abs(relativePos.Z) <= halfSize.Z then
				detectedRoom = room:GetAttribute("RoomName") or ""
				break
			end
		end
	end

	-- Only transition if room changed
	if detectedRoom ~= currentRoom then
		currentRoom = detectedRoom

		local preset = roomPresets[detectedRoom]
		if preset then
			tweenLighting(preset, 1.5) -- Smooth 1.5 second transition
		else
			tweenLighting(defaultLighting, 2.0) -- Slower return to default
		end
	end
end)

-- ==================
-- BOSS FIGHT LIGHTING OVERRIDE
-- ==================

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

Remotes[Constants.EVENT_BOSS_FIGHT_START].OnClientEvent:Connect(function()
	-- Dramatic red lighting for boss fight
	local bossPreset = roomPresets.BossRoom or {
		Ambient = Color3.fromRGB(20, 5, 5),
		Brightness = 0.4,
		FogEnd = 150,
		FogColor = Color3.fromRGB(15, 3, 3),
	}
	tweenLighting(bossPreset, 2.0)

	-- Increase bloom for dramatic effect during boss fight
	local bossBloom = TweenService:Create(bloom, TweenInfo.new(2), {
		Intensity = 0.8,
		Threshold = 0.9,
	})
	bossBloom:Play()
end)

Remotes[Constants.EVENT_BOSS_DEFEATED].OnClientEvent:Connect(function()
	-- Bright, warm victory lighting
	local victoryPreset = {
		Ambient = Color3.fromRGB(80, 70, 50),
		Brightness = 1.5,
		FogEnd = 500,
		FogColor = Color3.fromRGB(40, 35, 25),
	}
	tweenLighting(victoryPreset, 3.0)

	-- Restore bloom
	local restoreBloom = TweenService:Create(bloom, TweenInfo.new(3), {
		Intensity = 0.5,
		Threshold = 1.2,
	})
	restoreBloom:Play()

	-- Lighten the color correction for victory
	local lightColorCorrection = Lighting:FindFirstChild("HorrorGrade")
	if lightColorCorrection then
		local restoreColor = TweenService:Create(lightColorCorrection, TweenInfo.new(3), {
			Saturation = 0,
			Brightness = 0.05,
			Contrast = 0.05,
			TintColor = Color3.fromRGB(255, 250, 240), -- Warm white
		})
		restoreColor:Play()
	end
end)

print("[LightingManager] Advanced lighting initialized")
print("[LightingManager] Tag Parts with 'Room' and set 'RoomName' attribute for dynamic lighting")
print("[LightingManager] Supported rooms:", table.concat({
	"Basement", "Cellar", "Attic", "Kitchen", "LivingRoom",
	"DiningRoom", "Bathroom", "Hallway", "Stairway", "BossRoom",
}, ", "))

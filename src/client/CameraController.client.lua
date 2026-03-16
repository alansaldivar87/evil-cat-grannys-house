--[[
	CameraController - Camera effects for horror atmosphere
	Handles: camera shake on attacks, subtle effects during chase
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Shake state
local shakeIntensity = 0
local shakeDuration = 0
local shakeTimer = 0

local function startShake(duration: number, intensity: number)
	shakeDuration = duration
	shakeIntensity = intensity
	shakeTimer = 0
end

-- Apply camera shake each frame
RunService.RenderStepped:Connect(function(dt)
	if shakeTimer < shakeDuration then
		shakeTimer = shakeTimer + dt

		-- Decay intensity over duration
		local progress = shakeTimer / shakeDuration
		local currentIntensity = shakeIntensity * (1 - progress)

		-- Random offset
		local offsetX = (math.random() - 0.5) * 2 * currentIntensity
		local offsetY = (math.random() - 0.5) * 2 * currentIntensity

		Camera.CFrame = Camera.CFrame * CFrame.new(offsetX * 0.1, offsetY * 0.1, 0)
	end
end)

-- ==================
-- EVENT HANDLERS
-- ==================

-- Camera shake from server (cat attack, boss enrage, etc.)
Remotes[Constants.EVENT_CAMERA_SHAKE].OnClientEvent:Connect(function(duration: number, intensity: number)
	startShake(duration, intensity)
end)

-- Shake on player death
LocalPlayer.CharacterAdded:Connect(function(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		startShake(0.5, 8)
	end)
end)

print("[CameraController] Camera effects initialized")

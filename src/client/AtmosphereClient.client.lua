--[[
	AtmosphereClient - Handles ambient sounds, tension music, and proximity audio
	Creates a spooky atmosphere with dynamic audio based on cat proximity
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Utils = require(Shared:WaitForChild("Utils"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LocalPlayer = Players.LocalPlayer

-- ==================
-- SOUND SETUP
-- Note: Replace asset IDs below with actual Roblox audio asset IDs
-- You can find free sounds in the Roblox Creator Marketplace
-- or upload your own .ogg/.mp3 files as audio assets
-- ==================

-- Sound container
local soundGroup = Instance.new("SoundGroup")
soundGroup.Name = "GameSounds"
soundGroup.Parent = SoundService

-- Ambient creaking sound (loops)
local ambientSound = Instance.new("Sound")
ambientSound.Name = "Ambient"
ambientSound.SoundId = "" -- TODO: Add asset ID like "rbxassetid://123456789"
ambientSound.Volume = 0.3
ambientSound.Looped = true
ambientSound.SoundGroup = soundGroup
ambientSound.Parent = SoundService

-- Tension/heartbeat music (for when cat is near)
local tensionSound = Instance.new("Sound")
tensionSound.Name = "Tension"
tensionSound.SoundId = "" -- TODO: Add asset ID
tensionSound.Volume = 0
tensionSound.Looped = true
tensionSound.SoundGroup = soundGroup
tensionSound.Parent = SoundService

-- Cat hiss sound (one-shot)
local hissSound = Instance.new("Sound")
hissSound.Name = "CatHiss"
hissSound.SoundId = "" -- TODO: Add asset ID
hissSound.Volume = 0.8
hissSound.Looped = false
hissSound.SoundGroup = soundGroup
hissSound.Parent = SoundService

-- Checkpoint ding
local checkpointSound = Instance.new("Sound")
checkpointSound.Name = "CheckpointDing"
checkpointSound.SoundId = "" -- TODO: Add asset ID
checkpointSound.Volume = 0.6
checkpointSound.Looped = false
checkpointSound.SoundGroup = soundGroup
checkpointSound.Parent = SoundService

-- Death sting
local deathSound = Instance.new("Sound")
deathSound.Name = "DeathSting"
deathSound.SoundId = "" -- TODO: Add asset ID
deathSound.Volume = 0.7
deathSound.Looped = false
deathSound.SoundGroup = soundGroup
deathSound.Parent = SoundService

-- Victory fanfare
local victorySound = Instance.new("Sound")
victorySound.Name = "Victory"
victorySound.SoundId = "" -- TODO: Add asset ID
victorySound.Volume = 0.8
victorySound.Looped = false
victorySound.SoundGroup = soundGroup
victorySound.Parent = SoundService

-- Boss roar
local bossRoarSound = Instance.new("Sound")
bossRoarSound.Name = "BossRoar"
bossRoarSound.SoundId = "" -- TODO: Add asset ID
bossRoarSound.Volume = 1.0
bossRoarSound.Looped = false
bossRoarSound.SoundGroup = soundGroup
bossRoarSound.Parent = SoundService

-- Start ambient sound
ambientSound:Play()
tensionSound:Play() -- Plays at volume 0, we'll fade it in/out

-- ==================
-- PROXIMITY-BASED TENSION MUSIC
-- ==================

local TENSION_RANGE = 35 -- Distance at which tension starts
local targetTensionVolume = 0

RunService.RenderStepped:Connect(function()
	local character = LocalPlayer.Character
	if not character then
		return
	end

	local playerPos = Utils.getCharacterPosition(character)
	if not playerPos then
		return
	end

	-- Find nearest cat
	local nearestCatDist = math.huge
	for _, cat in CollectionService:GetTagged(Constants.TAG_EVIL_CAT) do
		if cat:IsA("Model") then
			local catRoot = cat.PrimaryPart or cat:FindFirstChild("HumanoidRootPart")
			if catRoot then
				local dist = Utils.getDistance(playerPos, catRoot.Position)
				if dist < nearestCatDist then
					nearestCatDist = dist
				end
			end
		end
	end

	-- Calculate tension volume based on proximity
	if nearestCatDist < TENSION_RANGE then
		targetTensionVolume = 1 - (nearestCatDist / TENSION_RANGE)
		targetTensionVolume = math.clamp(targetTensionVolume, 0, 0.8)
	else
		targetTensionVolume = 0
	end

	-- Smooth volume transition
	tensionSound.Volume = tensionSound.Volume + (targetTensionVolume - tensionSound.Volume) * 0.05
end)

-- ==================
-- EVENT-BASED SOUNDS
-- ==================

-- Cat warning hiss
Remotes[Constants.EVENT_CAT_WARNING].OnClientEvent:Connect(function(catPosition: Vector3)
	hissSound:Play()
end)

-- Checkpoint reached
Remotes[Constants.EVENT_CHECKPOINT_REACHED].OnClientEvent:Connect(function()
	checkpointSound:Play()
end)

-- Boss fight start
Remotes[Constants.EVENT_BOSS_FIGHT_START].OnClientEvent:Connect(function()
	bossRoarSound:Play()
end)

-- Boss defeated
Remotes[Constants.EVENT_BOSS_DEFEATED].OnClientEvent:Connect(function()
	tensionSound.Volume = 0
	victorySound:Play()
end)

-- Player death
LocalPlayer.CharacterAdded:Connect(function(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		deathSound:Play()
		-- Fade out tension
		local tween = TweenService:Create(tensionSound, TweenInfo.new(0.5), { Volume = 0 })
		tween:Play()
	end)
end)

print("[AtmosphereClient] Sound system initialized")
print("[AtmosphereClient] NOTE: Add Roblox audio asset IDs to the SoundId properties!")
print("[AtmosphereClient] Search for free sounds at create.roblox.com/marketplace")

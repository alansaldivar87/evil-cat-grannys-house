--[[
	SoundManager - Professional immersive audio system for Evil Cat in Granny's House

	Replaces the basic AtmosphereClient with a full-featured client-side sound manager.
	All audio runs on the client for performance. Events are cleaned up on death/respawn.

	Systems:
	  1. Positional 3D cat audio (growl, hiss, footsteps on cat models)
	  2. Room-based ambience (detects Room parts with RoomType attribute)
	  3. Dynamic music with crossfades (exploration, chase, boss, victory)
	  4. Material-based player footsteps (raycast downward for floor material)
	  5. Random jump-scare tension sounds (when a cat is within range)
	  6. UI / event one-shots (checkpoint, death, items, etc.)

	SPATIAL VOICE CHAT NOTE:
	  Roblox Spatial Voice is enabled in Game Settings > Communication, not via code.
	  When enabled, players 13+ with age verification hear each other in proximity.
	  The default ~50-stud rolloff suits horror well. No scripting needed.
]]

-- ============================================================================
-- Services
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local GameState = require(Shared:WaitForChild("GameState"))
local Utils = require(Shared:WaitForChild("Utils"))
local SoundConfig = require(Shared:WaitForChild("SoundConfig"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LocalPlayer = Players.LocalPlayer

-- ============================================================================
-- State
-- ============================================================================
local connections: { RBXScriptConnection } = {} -- cleaned up on respawn
local currentMusicTrack: string? = nil -- key into SoundConfig.Music
local currentRoomType: string? = nil
local isPlayerHidden = false
local jumpScareTimer = 0
local nextJumpScareInterval = 0
local footstepTimer = 0

-- ============================================================================
-- Sound Group (master volume control)
-- ============================================================================
local masterGroup = Instance.new("SoundGroup")
masterGroup.Name = "GameSounds"
masterGroup.Volume = 1
masterGroup.Parent = SoundService

local musicGroup = Instance.new("SoundGroup")
musicGroup.Name = "Music"
musicGroup.Volume = 1
musicGroup.Parent = masterGroup

local ambienceGroup = Instance.new("SoundGroup")
ambienceGroup.Name = "Ambience"
ambienceGroup.Volume = 1
ambienceGroup.Parent = masterGroup

local sfxGroup = Instance.new("SoundGroup")
sfxGroup.Name = "SFX"
sfxGroup.Volume = 1
sfxGroup.Parent = masterGroup

-- ============================================================================
-- Utility: create a Sound instance from a config table
-- ============================================================================
local function makeSound(config: { [string]: any }, parent: Instance, soundGroup: SoundGroup?): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = config.SoundId or ""
	sound.Volume = config.Volume or 0.5
	sound.Looped = if config.Looped ~= nil then config.Looped else false
	if soundGroup then
		sound.SoundGroup = soundGroup
	end
	-- Apply random pitch within range
	if config.PitchMin and config.PitchMax then
		sound.PlaybackSpeed = config.PitchMin + math.random() * (config.PitchMax - config.PitchMin)
	end
	sound.Parent = parent
	return sound
end

local function make3DSound(config: { [string]: any }, parent: Instance, soundGroup: SoundGroup?): Sound
	local sound = makeSound(config, parent, soundGroup)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = config.RollOffMinDistance or 5
	sound.RollOffMaxDistance = config.RollOffMaxDistance or 50
	return sound
end

-- Tween a sound's volume to a target over duration, then optionally call onComplete
local function tweenVolume(sound: Sound, targetVolume: number, duration: number, onComplete: (() -> ())?): Tween
	local tween = TweenService:Create(
		sound,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ Volume = targetVolume }
	)
	if onComplete then
		tween.Completed:Once(function()
			onComplete()
		end)
	end
	tween:Play()
	return tween
end

-- Randomize pitch on a sound from its config
local function randomizePitch(sound: Sound, config: { [string]: any })
	if config.PitchMin and config.PitchMax then
		sound.PlaybackSpeed = config.PitchMin + math.random() * (config.PitchMax - config.PitchMin)
	end
end

-- ============================================================================
-- 1. DYNAMIC MUSIC SYSTEM
-- Crossfades between exploration, chase, boss, and victory tracks.
-- ============================================================================
local musicSounds: { [string]: Sound } = {}

-- Pre-create all music sounds in SoundService (non-positional, 2D)
for trackName, config in SoundConfig.Music do
	local sound = makeSound(config, SoundService, musicGroup)
	sound.Name = "Music_" .. trackName
	sound.Volume = 0 -- start silent; we fade in the active track
	if config.Looped then
		sound:Play()
	end
	musicSounds[trackName] = sound
end

local function setMusicTrack(trackName: string)
	if trackName == currentMusicTrack then
		return
	end

	local fadeDuration = SoundConfig.MusicCrossfadeDuration

	-- Fade out old track
	if currentMusicTrack and musicSounds[currentMusicTrack] then
		local oldSound = musicSounds[currentMusicTrack]
		tweenVolume(oldSound, 0, fadeDuration, function()
			if not SoundConfig.Music[currentMusicTrack].Looped then
				oldSound:Stop()
			end
		end)
	end

	currentMusicTrack = trackName

	-- Fade in new track
	local newSound = musicSounds[trackName]
	if newSound then
		local targetVol = SoundConfig.Music[trackName].Volume or 0.3
		if not newSound.IsPlaying then
			newSound.Volume = 0
			newSound:Play()
		end
		tweenVolume(newSound, targetVol, fadeDuration)
	end
end

-- Start with exploration music
setMusicTrack("Exploration")

-- ============================================================================
-- 2. POSITIONAL 3D CAT AUDIO
-- Attach Sound objects to each cat model so audio is spatialized.
-- ============================================================================
local catSoundData: { [Model]: { [string]: Sound } } = {}

local function setupCatSounds(catModel: Model)
	if catSoundData[catModel] then
		return -- already set up
	end

	local rootPart = catModel.PrimaryPart or catModel:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local sounds: { [string]: Sound } = {}

	-- Growl (looping, always playing at low volume while patrolling)
	sounds.Growl = make3DSound(SoundConfig.Cat.Growl, rootPart, sfxGroup)
	sounds.Growl.Name = "CatGrowl"
	sounds.Growl.Looped = true
	sounds.Growl:Play()

	-- Hiss (one-shot, played on warning)
	sounds.Hiss = make3DSound(SoundConfig.Cat.Hiss, rootPart, sfxGroup)
	sounds.Hiss.Name = "CatHiss"

	-- Footstep (one-shot, played periodically when cat moves)
	sounds.Footstep = make3DSound(SoundConfig.Cat.Footstep, rootPart, sfxGroup)
	sounds.Footstep.Name = "CatFootstep"

	-- Attack
	sounds.Attack = make3DSound(SoundConfig.Cat.Attack, rootPart, sfxGroup)
	sounds.Attack.Name = "CatAttack"

	-- Boss roar (only for boss cats)
	if CollectionService:HasTag(catModel, Constants.TAG_BOSS_CAT) then
		sounds.BossRoar = make3DSound(SoundConfig.Cat.BossRoar, rootPart, sfxGroup)
		sounds.BossRoar.Name = "BossRoar"
	end

	catSoundData[catModel] = sounds
end

local function cleanupCatSounds(catModel: Model)
	local sounds = catSoundData[catModel]
	if sounds then
		for _, sound in sounds do
			sound:Stop()
			sound:Destroy()
		end
		catSoundData[catModel] = nil
	end
end

-- Register cats already in the world
for _, cat in CollectionService:GetTagged(Constants.TAG_EVIL_CAT) do
	if cat:IsA("Model") then
		setupCatSounds(cat)
	end
end

CollectionService:GetInstanceAddedSignal(Constants.TAG_EVIL_CAT):Connect(function(instance)
	if instance:IsA("Model") then
		setupCatSounds(instance)
	end
end)

CollectionService:GetInstanceRemovedSignal(Constants.TAG_EVIL_CAT):Connect(function(instance)
	if instance:IsA("Model") then
		cleanupCatSounds(instance)
	end
end)

-- Cat footstep timer: play cat footsteps based on humanoid velocity
local catFootstepTimers: { [Model]: number } = {}
local CAT_FOOTSTEP_INTERVAL = 0.4

-- ============================================================================
-- 3. ROOM-BASED AMBIENCE
-- Detect which Room part the player is inside and swap ambient loops.
-- ============================================================================
local roomAmbienceSounds: { Primary: Sound?, Secondary: Sound? } = {
	Primary = nil,
	Secondary = nil,
}

local function createRoomAmbienceSound(config: { [string]: any }, name: string): Sound
	local sound = makeSound(config, SoundService, ambienceGroup)
	sound.Name = name
	sound.Looped = true
	sound.Volume = 0
	sound:Play()
	return sound
end

local function setRoomAmbience(roomType: string?)
	local effectiveType = roomType or "Default"

	if effectiveType == currentRoomType then
		return
	end

	local config = SoundConfig.RoomAmbience[effectiveType] or SoundConfig.RoomAmbience.Default
	local fadeDuration = SoundConfig.RoomAmbienceCrossfadeDuration

	-- Fade out and destroy old sounds
	for key, oldSound in roomAmbienceSounds do
		if oldSound then
			local ref = oldSound
			tweenVolume(ref, 0, fadeDuration, function()
				ref:Stop()
				ref:Destroy()
			end)
			roomAmbienceSounds[key] = nil
		end
	end

	currentRoomType = effectiveType

	-- Create and fade in new sounds
	if config.Primary then
		local primary = createRoomAmbienceSound(config.Primary, "RoomAmbience_Primary")
		roomAmbienceSounds.Primary = primary
		tweenVolume(primary, config.Primary.Volume, fadeDuration)
	end

	if config.Secondary then
		local secondary = createRoomAmbienceSound(config.Secondary, "RoomAmbience_Secondary")
		roomAmbienceSounds.Secondary = secondary
		tweenVolume(secondary, config.Secondary.Volume, fadeDuration)
	end
end

-- Start with default ambience
setRoomAmbience("Default")

-- Detect room by checking which Room-tagged part contains the player
local function detectCurrentRoom(playerPos: Vector3): string?
	for _, roomPart in CollectionService:GetTagged(Constants.TAG_ROOM) do
		if roomPart:IsA("BasePart") then
			-- Check if player position is within the part's bounding box
			local cf = roomPart.CFrame
			local size = roomPart.Size / 2
			local localPos = cf:PointToObjectSpace(playerPos)

			if math.abs(localPos.X) <= size.X
				and math.abs(localPos.Y) <= size.Y
				and math.abs(localPos.Z) <= size.Z
			then
				return roomPart:GetAttribute("RoomType") or "Default"
			end
		end
	end
	return nil
end

-- ============================================================================
-- 4. PLAYER FOOTSTEP SYSTEM
-- Raycast downward to detect floor material, play matching footstep sound.
-- ============================================================================
local footstepSound: Sound = makeSound(SoundConfig.FootstepDefault, SoundService, sfxGroup)
footstepSound.Name = "PlayerFootstep"
footstepSound.Looped = false

local lastFootstepMaterial: Enum.Material? = nil

local function getFloorMaterial(character: Model): Enum.Material?
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return nil
	end

	local rayOrigin = rootPart.Position
	local rayDirection = Vector3.new(0, -5, 0) -- cast 5 studs down

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	params.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(rayOrigin, rayDirection, params)
	if result then
		return result.Material
	end
	return nil
end

local function playFootstep(material: Enum.Material?)
	local config = if material then SoundConfig.Footsteps[material] else nil
	if not config then
		config = SoundConfig.FootstepDefault
	end

	-- Update sound properties if material changed
	if material ~= lastFootstepMaterial then
		footstepSound.SoundId = config.SoundId
		lastFootstepMaterial = material
	end

	footstepSound.Volume = config.Volume
	randomizePitch(footstepSound, config)
	footstepSound:Play()
end

-- ============================================================================
-- 5. JUMP SCARE TENSION SYSTEM
-- Plays random creepy sounds when a cat is within proximity.
-- ============================================================================
local jumpScareSounds: { Sound } = {}
for _, jsConfig in SoundConfig.JumpScare do
	local sound = makeSound(jsConfig, SoundService, sfxGroup)
	sound.Name = "JumpScare_" .. jsConfig.Name
	table.insert(jumpScareSounds, sound)
end

local function resetJumpScareTimer()
	nextJumpScareInterval = SoundConfig.JumpScareIntervalMin
		+ math.random() * (SoundConfig.JumpScareIntervalMax - SoundConfig.JumpScareIntervalMin)
	jumpScareTimer = 0
end

resetJumpScareTimer()

local function tryPlayJumpScare(nearestCatDist: number)
	if nearestCatDist > SoundConfig.JumpScareProximity then
		return
	end
	if #jumpScareSounds == 0 then
		return
	end

	-- Pick a random jump scare sound
	local idx = math.random(1, #jumpScareSounds)
	local sound = jumpScareSounds[idx]
	local config = SoundConfig.JumpScare[idx]

	randomizePitch(sound, config)
	sound.Volume = config.Volume
	sound:Play()

	resetJumpScareTimer()
end

-- ============================================================================
-- 6. UI / EVENT SOUNDS
-- ============================================================================
local uiSounds: { [string]: Sound } = {}
for eventName, config in SoundConfig.UI do
	local sound = makeSound(config, SoundService, sfxGroup)
	sound.Name = "UI_" .. eventName
	uiSounds[eventName] = sound
end

local function playUISound(eventName: string)
	local sound = uiSounds[eventName]
	if sound then
		local config = SoundConfig.UI[eventName]
		if config then
			randomizePitch(sound, config)
		end
		sound:Play()
	end
end

-- ============================================================================
-- MAIN UPDATE LOOP (RenderStepped)
-- Handles: proximity detection, music switching, room detection,
--          footsteps, cat footsteps, jump scare timer
-- ============================================================================
local function getNearestCatDistance(playerPos: Vector3): number
	local nearest = math.huge
	for _, cat in CollectionService:GetTagged(Constants.TAG_EVIL_CAT) do
		if cat:IsA("Model") then
			local catRoot = cat.PrimaryPart or cat:FindFirstChild("HumanoidRootPart")
			if catRoot then
				local dist = (playerPos - catRoot.Position).Magnitude
				if dist < nearest then
					nearest = dist
				end
			end
		end
	end
	return nearest
end

-- Determine if any cat is in chase state by checking humanoid walk speed
-- (chase speed is significantly higher than patrol speed)
local function isAnyCatChasing(): boolean
	for _, cat in CollectionService:GetTagged(Constants.TAG_EVIL_CAT) do
		if cat:IsA("Model") then
			local humanoid = cat:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.WalkSpeed >= Constants.CAT_CHASE_SPEED then
				return true
			end
		end
	end
	return false
end

local isBossFightActive = false
local isVictory = false

local function onRenderStepped(dt: number)
	local character = LocalPlayer.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local playerPos = Utils.getCharacterPosition(character)
	if not playerPos then
		return
	end

	local nearestCatDist = getNearestCatDistance(playerPos)

	-- ---- Music state machine ----
	if isVictory then
		setMusicTrack("Victory")
	elseif isBossFightActive then
		setMusicTrack("BossFight")
	elseif nearestCatDist < Constants.CAT_DETECTION_RANGE and isAnyCatChasing() then
		setMusicTrack("Chase")
	else
		setMusicTrack("Exploration")
	end

	-- ---- Room ambience detection (check every ~0.5s to save perf) ----
	-- We use a simple frame counter approach
	local roomType = detectCurrentRoom(playerPos)
	setRoomAmbience(roomType) -- function already no-ops if same room

	-- ---- Player footsteps ----
	if humanoid.MoveDirection.Magnitude > 0.1 and humanoid.FloorMaterial ~= Enum.Material.Air then
		footstepTimer += dt
		-- Faster footsteps when running faster
		local speed = humanoid.WalkSpeed
		local interval = SoundConfig.FootstepBaseInterval * (16 / math.max(speed, 1))
		interval = math.clamp(interval, 0.2, 0.6)

		if footstepTimer >= interval then
			footstepTimer = 0
			local material = getFloorMaterial(character)
			playFootstep(material)
		end
	else
		footstepTimer = 0
	end

	-- ---- Cat footstep sounds ----
	for catModel, sounds in catSoundData do
		if catModel.Parent then
			local catHumanoid = catModel:FindFirstChildOfClass("Humanoid")
			if catHumanoid and catHumanoid.MoveDirection.Magnitude > 0.1 then
				local timer = catFootstepTimers[catModel] or 0
				timer += dt
				if timer >= CAT_FOOTSTEP_INTERVAL then
					timer = 0
					if sounds.Footstep then
						randomizePitch(sounds.Footstep, SoundConfig.Cat.Footstep)
						sounds.Footstep:Play()
					end
				end
				catFootstepTimers[catModel] = timer
			else
				catFootstepTimers[catModel] = 0
			end
		end
	end

	-- ---- Jump scare timer ----
	jumpScareTimer += dt
	if jumpScareTimer >= nextJumpScareInterval then
		tryPlayJumpScare(nearestCatDist)
	end
end

-- ============================================================================
-- EVENT CONNECTIONS
-- ============================================================================
local function connectEvents()
	-- Main update loop
	table.insert(connections, RunService.RenderStepped:Connect(onRenderStepped))

	-- Cat warning hiss: play the 3D hiss on the cat that issued the warning
	table.insert(connections, Remotes[Constants.EVENT_CAT_WARNING].OnClientEvent:Connect(
		function(catPosition: Vector3)
			-- Find the nearest cat to this position and play its hiss sound
			local bestCat: Model? = nil
			local bestDist = math.huge
			for cat, sounds in catSoundData do
				local root = cat.PrimaryPart or cat:FindFirstChild("HumanoidRootPart")
				if root then
					local d = (root.Position - catPosition).Magnitude
					if d < bestDist then
						bestDist = d
						bestCat = cat
					end
				end
			end
			if bestCat and catSoundData[bestCat] then
				local hiss = catSoundData[bestCat].Hiss
				if hiss then
					randomizePitch(hiss, SoundConfig.Cat.Hiss)
					hiss:Play()
				end
			end
		end
	))

	-- Checkpoint
	table.insert(connections, Remotes[Constants.EVENT_CHECKPOINT_REACHED].OnClientEvent:Connect(
		function()
			playUISound("CheckpointReached")
		end
	))

	-- Boss fight start
	table.insert(connections, Remotes[Constants.EVENT_BOSS_FIGHT_START].OnClientEvent:Connect(
		function()
			isBossFightActive = true
			-- Play boss roar on the boss cat model (3D)
			for cat, sounds in catSoundData do
				if CollectionService:HasTag(cat, Constants.TAG_BOSS_CAT) and sounds.BossRoar then
					randomizePitch(sounds.BossRoar, SoundConfig.Cat.BossRoar)
					sounds.BossRoar:Play()
					break
				end
			end
		end
	))

	-- Boss defeated -> victory
	table.insert(connections, Remotes[Constants.EVENT_BOSS_DEFEATED].OnClientEvent:Connect(
		function()
			isBossFightActive = false
			isVictory = true
			-- Music system will pick up Victory on next frame via the render loop
		end
	))

	-- Player damaged
	table.insert(connections, Remotes[Constants.EVENT_PLAYER_DAMAGED].OnClientEvent:Connect(
		function()
			-- Play the attack sound from the nearest cat
			local character = LocalPlayer.Character
			if not character then
				return
			end
			local playerPos = Utils.getCharacterPosition(character)
			if not playerPos then
				return
			end

			local bestCat: Model? = nil
			local bestDist = math.huge
			for cat, _ in catSoundData do
				local root = cat.PrimaryPart or cat:FindFirstChild("HumanoidRootPart")
				if root then
					local d = (root.Position - playerPos).Magnitude
					if d < bestDist then
						bestDist = d
						bestCat = cat
					end
				end
			end
			if bestCat and catSoundData[bestCat] and catSoundData[bestCat].Attack then
				local atk = catSoundData[bestCat].Attack
				randomizePitch(atk, SoundConfig.Cat.Attack)
				atk:Play()
			end
		end
	))

	-- Hide state
	table.insert(connections, Remotes[Constants.EVENT_HIDE_STATE_CHANGED].OnClientEvent:Connect(
		function(hidden: boolean)
			isPlayerHidden = hidden
			if hidden then
				playUISound("HideEnter")
				-- Muffle music slightly when hidden
				tweenVolume(musicGroup, 0.5, 0.5)
			else
				playUISound("HideExit")
				tweenVolume(musicGroup, 1.0, 0.5)
			end
		end
	))

	-- Game state changes
	table.insert(connections, Remotes[Constants.EVENT_GAME_STATE_CHANGED].OnClientEvent:Connect(
		function(newState: string)
			if newState == GameState.States.VICTORY then
				isVictory = true
				isBossFightActive = false
			elseif newState == GameState.States.BOSS_FIGHT then
				isBossFightActive = true
				isVictory = false
			elseif newState == GameState.States.PLAYING then
				isBossFightActive = false
				isVictory = false
			end
		end
	))

	-- Key collected
	if Remotes:FindFirstChild(Constants.EVENT_KEY_COLLECTED) then
		table.insert(connections, Remotes[Constants.EVENT_KEY_COLLECTED].OnClientEvent:Connect(
			function()
				playUISound("KeyCollected")
			end
		))
	end

	-- Door toggle
	if Remotes:FindFirstChild(Constants.EVENT_DOOR_TOGGLE) then
		table.insert(connections, Remotes[Constants.EVENT_DOOR_TOGGLE].OnClientEvent:Connect(
			function()
				playUISound("DoorOpen")
			end
		))
	end

	-- Treat collected
	if Remotes:FindFirstChild(Constants.EVENT_TREAT_COLLECTED) then
		table.insert(connections, Remotes[Constants.EVENT_TREAT_COLLECTED].OnClientEvent:Connect(
			function()
				playUISound("TreatCollected")
			end
		))
	end

	-- Story note
	if Remotes:FindFirstChild(Constants.EVENT_STORY_NOTE_SHOW) then
		table.insert(connections, Remotes[Constants.EVENT_STORY_NOTE_SHOW].OnClientEvent:Connect(
			function()
				playUISound("StoryNoteFound")
			end
		))
	end

	-- Flashlight toggle
	if Remotes:FindFirstChild(Constants.EVENT_FLASHLIGHT_TOGGLE) then
		table.insert(connections, Remotes[Constants.EVENT_FLASHLIGHT_TOGGLE].OnClientEvent:Connect(
			function(isOn: boolean)
				if isOn then
					playUISound("FlashlightOn")
				else
					playUISound("FlashlightOff")
				end
			end
		))
	end
end

-- ============================================================================
-- CLEANUP on character death / respawn
-- Disconnect all per-character connections to avoid memory leaks.
-- ============================================================================
local function disconnectAll()
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
end

local function onCharacterAdded(character: Model)
	-- Reset state
	isVictory = false
	isBossFightActive = false
	currentMusicTrack = nil
	footstepTimer = 0
	resetJumpScareTimer()

	-- Set room to default until detected
	currentRoomType = nil
	setRoomAmbience("Default")
	setMusicTrack("Exploration")

	-- Connect events
	connectEvents()

	-- On death: play death sting, fade music, and clean up
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Once(function()
		playUISound("DeathSting")

		-- Fade out all music
		for _, sound in musicSounds do
			tweenVolume(sound, 0, 0.5)
		end

		-- Disconnect everything; will be re-connected on next spawn
		disconnectAll()
	end)
end

-- Handle initial character and future respawns
if LocalPlayer.Character then
	task.spawn(onCharacterAdded, LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

print("[SoundManager] Audio system initialized")
print("[SoundManager] NOTE: Replace placeholder asset IDs in SoundConfig.lua with real Roblox audio assets")
print("[SoundManager] TIP: Search for free sounds at create.roblox.com/marketplace")

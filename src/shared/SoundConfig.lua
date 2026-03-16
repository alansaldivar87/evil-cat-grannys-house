--[[
	SoundConfig - Central audio configuration for Evil Cat in Granny's House
	All sound asset IDs, volume levels, pitch ranges, and rolloff distances.

	HOW TO USE:
	  1. Find or upload audio assets on create.roblox.com/marketplace
	  2. Replace "rbxassetid://0" with the real asset ID, e.g. "rbxassetid://123456789"
	  3. Adjust Volume, PitchMin/PitchMax, and RollOff values to taste

	ROBLOX SPATIAL VOICE CHAT (Proximity Chat):
	  Spatial voice is enabled per-experience in Game Settings, not via code.
	  Steps to enable:
	    1. Go to create.roblox.com -> your experience -> Settings -> Communication
	    2. Enable "Spatial Voice" (also called "Voice Chat")
	    3. Players who are 13+ with verified age will hear each other
	       based on proximity automatically -- no scripting required.
	    4. The default rolloff is ~50 studs which works well for horror games.
	  This pairs great with the horror atmosphere: players can whisper
	  warnings to nearby teammates when a cat is close.
]]

local SoundConfig = {}

-- ============================================================================
-- MUSIC
-- Background music tracks. These play through SoundService (2D, non-positional).
-- ============================================================================
SoundConfig.Music = {
	Exploration = {
		SoundId = "rbxassetid://0", -- Slow, eerie piano + ambient pads. Think music-box melody.
		Volume = 0.25,
		Looped = true,
		PitchMin = 1.0,
		PitchMax = 1.0,
	},
	Chase = {
		SoundId = "rbxassetid://0", -- Fast, intense strings + percussion. Heart-pounding tempo.
		Volume = 0.45,
		Looped = true,
		PitchMin = 1.0,
		PitchMax = 1.0,
	},
	BossFight = {
		SoundId = "rbxassetid://0", -- Epic orchestral / dramatic choir. High energy boss theme.
		Volume = 0.5,
		Looped = true,
		PitchMin = 1.0,
		PitchMax = 1.0,
	},
	Victory = {
		SoundId = "rbxassetid://0", -- Triumphant fanfare, bright and uplifting.
		Volume = 0.6,
		Looped = false,
		PitchMin = 1.0,
		PitchMax = 1.0,
	},
}

-- Crossfade duration in seconds when transitioning between music tracks
SoundConfig.MusicCrossfadeDuration = 2.0

-- ============================================================================
-- CAT SOUNDS
-- 3D positional audio parented to cat models. Uses RollOffMode InverseTapered.
-- ============================================================================
SoundConfig.Cat = {
	Growl = {
		SoundId = "rbxassetid://0", -- Low, rumbling cat growl. Menacing tone.
		Volume = 0.7,
		Looped = true,
		PitchMin = 0.85,
		PitchMax = 1.1,
		RollOffMinDistance = 5,
		RollOffMaxDistance = 50,
	},
	Hiss = {
		SoundId = "rbxassetid://0", -- Sharp, aggressive cat hiss.
		Volume = 0.9,
		Looped = false,
		PitchMin = 0.9,
		PitchMax = 1.15,
		RollOffMinDistance = 5,
		RollOffMaxDistance = 60,
	},
	Footstep = {
		SoundId = "rbxassetid://0", -- Soft padded footstep, like paws on a hard floor.
		Volume = 0.4,
		Looped = false,
		PitchMin = 0.8,
		PitchMax = 1.2,
		RollOffMinDistance = 3,
		RollOffMaxDistance = 30,
	},
	Attack = {
		SoundId = "rbxassetid://0", -- Quick claw swipe / scratch sound.
		Volume = 0.85,
		Looped = false,
		PitchMin = 0.9,
		PitchMax = 1.1,
		RollOffMinDistance = 5,
		RollOffMaxDistance = 40,
	},
	BossRoar = {
		SoundId = "rbxassetid://0", -- Massive, distorted roar. Reverb-heavy.
		Volume = 1.0,
		Looped = false,
		PitchMin = 0.7,
		PitchMax = 0.9,
		RollOffMinDistance = 10,
		RollOffMaxDistance = 120,
	},
}

-- ============================================================================
-- ROOM AMBIENCE
-- Looping ambient sounds for each room type. 2D audio, swapped on room change.
-- Tag parts with "Room" and set the "RoomType" attribute to one of these keys.
-- ============================================================================
SoundConfig.RoomAmbience = {
	Kitchen = {
		Primary = {
			SoundId = "rbxassetid://0", -- Dripping faucet, slow irregular drops.
			Volume = 0.3,
			PitchMin = 0.95,
			PitchMax = 1.05,
		},
		Secondary = {
			SoundId = "rbxassetid://0", -- Creaking pipes, metallic groaning.
			Volume = 0.2,
			PitchMin = 0.9,
			PitchMax = 1.0,
		},
	},
	Bedroom = {
		Primary = {
			SoundId = "rbxassetid://0", -- Wind howling outside the window.
			Volume = 0.25,
			PitchMin = 0.9,
			PitchMax = 1.1,
		},
		Secondary = {
			SoundId = "rbxassetid://0", -- Curtains rustling, soft fabric movement.
			Volume = 0.15,
			PitchMin = 0.95,
			PitchMax = 1.05,
		},
	},
	Basement = {
		Primary = {
			SoundId = "rbxassetid://0", -- Water dripping in a large echoey space.
			Volume = 0.3,
			PitchMin = 0.8,
			PitchMax = 1.0,
		},
		Secondary = {
			SoundId = "rbxassetid://0", -- Distant low rumbling, like a furnace or underground tremor.
			Volume = 0.2,
			PitchMin = 0.7,
			PitchMax = 0.9,
		},
	},
	Attic = {
		Primary = {
			SoundId = "rbxassetid://0", -- Wind whistling through cracks, high-pitched.
			Volume = 0.3,
			PitchMin = 0.9,
			PitchMax = 1.15,
		},
		Secondary = {
			SoundId = "rbxassetid://0", -- Creaking wood beams + occasional bat flutter.
			Volume = 0.2,
			PitchMin = 0.85,
			PitchMax = 1.05,
		},
	},
	Bathroom = {
		Primary = {
			SoundId = "rbxassetid://0", -- Dripping water into porcelain basin, echo.
			Volume = 0.3,
			PitchMin = 0.95,
			PitchMax = 1.05,
		},
		Secondary = {
			SoundId = "rbxassetid://0", -- Old mirror creaking on its frame, subtle glass rattle.
			Volume = 0.15,
			PitchMin = 0.9,
			PitchMax = 1.0,
		},
	},
	LivingRoom = {
		Primary = {
			SoundId = "rbxassetid://0", -- Old grandfather clock ticking, slow and deliberate.
			Volume = 0.25,
			PitchMin = 0.95,
			PitchMax = 1.0,
		},
		Secondary = {
			SoundId = "rbxassetid://0", -- Fireplace crackling, warm but slightly unsettling.
			Volume = 0.2,
			PitchMin = 0.9,
			PitchMax = 1.1,
		},
	},
	-- Fallback for rooms with unrecognized RoomType or no attribute
	Default = {
		Primary = {
			SoundId = "rbxassetid://0", -- Generic old house creaking ambience.
			Volume = 0.2,
			PitchMin = 0.9,
			PitchMax = 1.1,
		},
		Secondary = {
			SoundId = "rbxassetid://0", -- Faint wind / draft sound.
			Volume = 0.1,
			PitchMin = 0.95,
			PitchMax = 1.05,
		},
	},
}

-- Duration to crossfade between room ambience tracks (seconds)
SoundConfig.RoomAmbienceCrossfadeDuration = 1.5

-- ============================================================================
-- PLAYER FOOTSTEPS
-- One-shot sounds played per step. Material is detected via downward raycast.
-- ============================================================================
SoundConfig.Footsteps = {
	-- Enum.Material -> config
	[Enum.Material.Wood] = {
		SoundId = "rbxassetid://0", -- Creaky wooden floorboard.
		Volume = 0.35,
		PitchMin = 0.85,
		PitchMax = 1.15,
	},
	[Enum.Material.WoodPlanks] = {
		SoundId = "rbxassetid://0", -- Same as Wood, slightly different pitch.
		Volume = 0.35,
		PitchMin = 0.8,
		PitchMax = 1.1,
	},
	[Enum.Material.Fabric] = {
		SoundId = "rbxassetid://0", -- Muffled carpet footstep.
		Volume = 0.2,
		PitchMin = 0.9,
		PitchMax = 1.1,
	},
	[Enum.Material.Marble] = {
		SoundId = "rbxassetid://0", -- Hard tile clicking footstep.
		Volume = 0.4,
		PitchMin = 0.9,
		PitchMax = 1.15,
	},
	[Enum.Material.Slate] = {
		SoundId = "rbxassetid://0", -- Stone / tile step.
		Volume = 0.4,
		PitchMin = 0.85,
		PitchMax = 1.1,
	},
	[Enum.Material.Concrete] = {
		SoundId = "rbxassetid://0", -- Hard concrete step, echoey.
		Volume = 0.35,
		PitchMin = 0.9,
		PitchMax = 1.1,
	},
	[Enum.Material.SmoothPlastic] = {
		SoundId = "rbxassetid://0", -- Generic indoor footstep (default surface).
		Volume = 0.3,
		PitchMin = 0.9,
		PitchMax = 1.1,
	},
	[Enum.Material.Metal] = {
		SoundId = "rbxassetid://0", -- Metallic clang step, pipes / grates.
		Volume = 0.4,
		PitchMin = 0.8,
		PitchMax = 1.15,
	},
	[Enum.Material.Grass] = {
		SoundId = "rbxassetid://0", -- Soft rustling grass step.
		Volume = 0.25,
		PitchMin = 0.9,
		PitchMax = 1.1,
	},
}

-- Fallback footstep if material is not in the table above
SoundConfig.FootstepDefault = {
	SoundId = "rbxassetid://0", -- Generic indoor footstep.
	Volume = 0.3,
	PitchMin = 0.9,
	PitchMax = 1.1,
}

-- Minimum time between footstep sounds (seconds). Actual interval also depends on walk speed.
SoundConfig.FootstepBaseInterval = 0.35

-- ============================================================================
-- JUMP SCARE / TENSION SOUNDS
-- Random one-shot sounds that play to build tension.
-- Only trigger when a cat is within JumpScareProximity studs.
-- ============================================================================
SoundConfig.JumpScare = {
	{
		Name = "DistantMeow",
		SoundId = "rbxassetid://0", -- Distant, echoing cat meow. Slightly distorted.
		Volume = 0.35,
		PitchMin = 0.7,
		PitchMax = 1.0,
	},
	{
		Name = "DoorCreak",
		SoundId = "rbxassetid://0", -- Slow door creaking open by itself.
		Volume = 0.4,
		PitchMin = 0.8,
		PitchMax = 1.1,
	},
	{
		Name = "GlassBreak",
		SoundId = "rbxassetid://0", -- Distant glass shattering.
		Volume = 0.3,
		PitchMin = 0.9,
		PitchMax = 1.1,
	},
	{
		Name = "Whispers",
		SoundId = "rbxassetid://0", -- Unintelligible whispers, breathy and unsettling.
		Volume = 0.2,
		PitchMin = 0.8,
		PitchMax = 1.0,
	},
	{
		Name = "FloorboardCreak",
		SoundId = "rbxassetid://0", -- Single loud floorboard creak, as if someone stepped nearby.
		Volume = 0.4,
		PitchMin = 0.85,
		PitchMax = 1.15,
	},
	{
		Name = "ChildLaugh",
		SoundId = "rbxassetid://0", -- Faint, distant child's laugh. Very creepy.
		Volume = 0.15,
		PitchMin = 0.75,
		PitchMax = 0.95,
	},
}

-- Range in studs: a cat must be within this distance for jump scares to trigger
SoundConfig.JumpScareProximity = 50

-- Random interval range in seconds between jump scare sounds
SoundConfig.JumpScareIntervalMin = 30
SoundConfig.JumpScareIntervalMax = 90

-- ============================================================================
-- UI / EVENT SOUNDS
-- Non-positional one-shots for game events.
-- ============================================================================
SoundConfig.UI = {
	CheckpointReached = {
		SoundId = "rbxassetid://0", -- Satisfying chime / ding.
		Volume = 0.6,
		PitchMin = 1.0,
		PitchMax = 1.0,
	},
	DeathSting = {
		SoundId = "rbxassetid://0", -- Dramatic low stab sound + reverb. Like a horror movie sting.
		Volume = 0.7,
		PitchMin = 1.0,
		PitchMax = 1.0,
	},
	KeyCollected = {
		SoundId = "rbxassetid://0", -- Key jingle / metallic clink.
		Volume = 0.5,
		PitchMin = 0.95,
		PitchMax = 1.05,
	},
	DoorOpen = {
		SoundId = "rbxassetid://0", -- Heavy door opening creak.
		Volume = 0.5,
		PitchMin = 0.9,
		PitchMax = 1.1,
	},
	DoorLocked = {
		SoundId = "rbxassetid://0", -- Rattling locked door handle.
		Volume = 0.5,
		PitchMin = 0.95,
		PitchMax = 1.05,
	},
	TreatCollected = {
		SoundId = "rbxassetid://0", -- Small positive pickup sound, sparkle-like.
		Volume = 0.4,
		PitchMin = 0.95,
		PitchMax = 1.1,
	},
	StoryNoteFound = {
		SoundId = "rbxassetid://0", -- Paper rustling / page turning.
		Volume = 0.4,
		PitchMin = 0.95,
		PitchMax = 1.05,
	},
	HideEnter = {
		SoundId = "rbxassetid://0", -- Quick shuffling / closet door closing.
		Volume = 0.4,
		PitchMin = 0.9,
		PitchMax = 1.1,
	},
	HideExit = {
		SoundId = "rbxassetid://0", -- Closet / cupboard opening.
		Volume = 0.4,
		PitchMin = 0.9,
		PitchMax = 1.1,
	},
	FlashlightOn = {
		SoundId = "rbxassetid://0", -- Flashlight click on.
		Volume = 0.3,
		PitchMin = 1.0,
		PitchMax = 1.0,
	},
	FlashlightOff = {
		SoundId = "rbxassetid://0", -- Flashlight click off.
		Volume = 0.3,
		PitchMin = 1.0,
		PitchMax = 1.0,
	},
}

return SoundConfig

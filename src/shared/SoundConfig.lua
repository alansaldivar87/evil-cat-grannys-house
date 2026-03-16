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
		SoundId = "rbxassetid://209322206", -- Slow, eerie piano + ambient pads. Think music-box melody. (Scary/Creepy Music Box)
		Volume = 0.25,
		Looped = true,
		PitchMin = 1.0,
		PitchMax = 1.0,
	},
	Chase = {
		SoundId = "rbxassetid://305024085", -- Fast, intense strings + percussion. Heart-pounding tempo. (Horror Chase Music)
		Volume = 0.45,
		Looped = true,
		PitchMin = 1.0,
		PitchMax = 1.0,
	},
	BossFight = {
		SoundId = "rbxassetid://5690623432", -- Epic orchestral / dramatic choir. High energy boss theme. (The Epic Boss Fight)
		Volume = 0.5,
		Looped = true,
		PitchMin = 1.0,
		PitchMax = 1.0,
	},
	Victory = {
		SoundId = "rbxassetid://130774315", -- Triumphant fanfare, bright and uplifting. (Victory)
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
		SoundId = "rbxassetid://516484997", -- Low, rumbling cat growl. Menacing tone. (Cat Growl)
		Volume = 0.7,
		Looped = true,
		PitchMin = 0.85,
		PitchMax = 1.1,
		RollOffMinDistance = 5,
		RollOffMaxDistance = 50,
	},
	Hiss = {
		SoundId = "rbxassetid://7128655475", -- Sharp, aggressive cat hiss. (Cat Hiss)
		Volume = 0.9,
		Looped = false,
		PitchMin = 0.9,
		PitchMax = 1.15,
		RollOffMinDistance = 5,
		RollOffMaxDistance = 60,
	},
	Footstep = {
		SoundId = "rbxassetid://133705377", -- Soft padded footstep, like paws on a hard floor. (Carpet Footstep - soft/muffled)
		Volume = 0.4,
		Looped = false,
		PitchMin = 0.8,
		PitchMax = 1.2,
		RollOffMinDistance = 3,
		RollOffMaxDistance = 30,
	},
	Attack = {
		SoundId = "rbxassetid://368169621", -- Quick claw swipe / scratch sound. (Scratch)
		Volume = 0.85,
		Looped = false,
		PitchMin = 0.9,
		PitchMax = 1.1,
		RollOffMinDistance = 5,
		RollOffMaxDistance = 40,
	},
	BossRoar = {
		SoundId = "rbxassetid://2139510606", -- Massive, distorted roar. Reverb-heavy. (Monster Roar - Sound Effect)
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
			SoundId = "rbxassetid://140854662", -- Dripping faucet, slow irregular drops. (Water Dripping)
			Volume = 0.3,
			PitchMin = 0.95,
			PitchMax = 1.05,
		},
		Secondary = {
			SoundId = "rbxassetid://6011094380", -- Creaking pipes, metallic groaning. (Metal Pipe sound)
			Volume = 0.2,
			PitchMin = 0.9,
			PitchMax = 1.0,
		},
	},
	Bedroom = {
		Primary = {
			SoundId = "rbxassetid://131104992", -- Wind howling outside the window. (Wind Howl)
			Volume = 0.25,
			PitchMin = 0.9,
			PitchMax = 1.1,
		},
		Secondary = {
			SoundId = "rbxassetid://5799870105", -- Curtains rustling, soft fabric movement. (Ambient Wind - soft)
			Volume = 0.15,
			PitchMin = 0.95,
			PitchMax = 1.05,
		},
	},
	Basement = {
		Primary = {
			SoundId = "rbxassetid://403292408", -- Water dripping in a large echoey space. (Water Drop Sound)
			Volume = 0.3,
			PitchMin = 0.8,
			PitchMax = 1.0,
		},
		Secondary = {
			SoundId = "rbxassetid://1215389145", -- Distant low rumbling, like a furnace or underground tremor. (Low End Rumble Loop)
			Volume = 0.2,
			PitchMin = 0.7,
			PitchMax = 0.9,
		},
	},
	Attic = {
		Primary = {
			SoundId = "rbxassetid://3645269782", -- Wind whistling through cracks, high-pitched. (Wind Sound Effect)
			Volume = 0.3,
			PitchMin = 0.9,
			PitchMax = 1.15,
		},
		Secondary = {
			SoundId = "rbxassetid://1041586920", -- Creaking wood beams + occasional bat flutter. (Creaking Door Sound Effect)
			Volume = 0.2,
			PitchMin = 0.85,
			PitchMax = 1.05,
		},
	},
	Bathroom = {
		Primary = {
			SoundId = "rbxassetid://4766793559", -- Dripping water into porcelain basin, echo. (Water sound effect)
			Volume = 0.3,
			PitchMin = 0.95,
			PitchMax = 1.05,
		},
		Secondary = {
			SoundId = "rbxassetid://148088329", -- Old mirror creaking on its frame, subtle glass rattle. (Door Creak)
			Volume = 0.15,
			PitchMin = 0.9,
			PitchMax = 1.0,
		},
	},
	LivingRoom = {
		Primary = {
			SoundId = "rbxassetid://8966275754", -- Old grandfather clock ticking, slow and deliberate. (Clock Ticking Sound Effect)
			Volume = 0.25,
			PitchMin = 0.95,
			PitchMax = 1.0,
		},
		Secondary = {
			SoundId = "rbxassetid://4604808051", -- Fireplace crackling, warm but slightly unsettling. (Fire Crackling Sound Effect)
			Volume = 0.2,
			PitchMin = 0.9,
			PitchMax = 1.1,
		},
	},
	-- Fallback for rooms with unrecognized RoomType or no attribute
	Default = {
		Primary = {
			SoundId = "rbxassetid://9039981149", -- Generic old house creaking ambience. (Horror ambient)
			Volume = 0.2,
			PitchMin = 0.9,
			PitchMax = 1.1,
		},
		Secondary = {
			SoundId = "rbxassetid://6455667685", -- Faint wind / draft sound. (Wind Sound Effect)
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
		SoundId = "rbxassetid://8454543187", -- Creaky wooden floorboard. (Wood Planks footstep)
		Volume = 0.35,
		PitchMin = 0.85,
		PitchMax = 1.15,
	},
	[Enum.Material.WoodPlanks] = {
		SoundId = "rbxassetid://8454543187", -- Same as Wood, slightly different pitch. (Wood Planks footstep)
		Volume = 0.35,
		PitchMin = 0.8,
		PitchMax = 1.1,
	},
	[Enum.Material.Fabric] = {
		SoundId = "rbxassetid://133705377", -- Muffled carpet footstep. (Carpet Footstep)
		Volume = 0.2,
		PitchMin = 0.9,
		PitchMax = 1.1,
	},
	[Enum.Material.Marble] = {
		SoundId = "rbxassetid://9083855231", -- Hard tile clicking footstep. (Footsteps - Marble)
		Volume = 0.4,
		PitchMin = 0.9,
		PitchMax = 1.15,
	},
	[Enum.Material.Slate] = {
		SoundId = "rbxassetid://833564121", -- Stone / tile step. (Concrete/Stone footstep)
		Volume = 0.4,
		PitchMin = 0.85,
		PitchMax = 1.1,
	},
	[Enum.Material.Concrete] = {
		SoundId = "rbxassetid://7046517109", -- Hard concrete step, echoey. (Concrete Footstep Sounds)
		Volume = 0.35,
		PitchMin = 0.9,
		PitchMax = 1.1,
	},
	[Enum.Material.SmoothPlastic] = {
		SoundId = "rbxassetid://131436155", -- Generic indoor footstep (default surface). (Footstep)
		Volume = 0.3,
		PitchMin = 0.9,
		PitchMax = 1.1,
	},
	[Enum.Material.Metal] = {
		SoundId = "rbxassetid://9064974448", -- Metallic clang step, pipes / grates. (Metal footstep)
		Volume = 0.4,
		PitchMin = 0.8,
		PitchMax = 1.15,
	},
	[Enum.Material.Grass] = {
		SoundId = "rbxassetid://833564767", -- Soft rustling grass step. (Walking on grass sound effect)
		Volume = 0.25,
		PitchMin = 0.9,
		PitchMax = 1.1,
	},
}

-- Fallback footstep if material is not in the table above
SoundConfig.FootstepDefault = {
	SoundId = "rbxassetid://131436155", -- Generic indoor footstep. (Footstep)
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
		SoundId = "rbxassetid://6573099301", -- Distant, echoing cat meow. Slightly distorted. (OMORI Mewo/Cat Meow Sound Effect)
		Volume = 0.35,
		PitchMin = 0.7,
		PitchMax = 1.0,
	},
	{
		Name = "DoorCreak",
		SoundId = "rbxassetid://1041586920", -- Slow door creaking open by itself. (Creaking Door Sound Effect)
		Volume = 0.4,
		PitchMin = 0.8,
		PitchMax = 1.1,
	},
	{
		Name = "GlassBreak",
		SoundId = "rbxassetid://5541851859", -- Distant glass shattering. (Glass Breaking sound)
		Volume = 0.3,
		PitchMin = 0.9,
		PitchMax = 1.1,
	},
	{
		Name = "Whispers",
		SoundId = "rbxassetid://313948389", -- Unintelligible whispers, breathy and unsettling. (Scary Whispers Sound Effect)
		Volume = 0.2,
		PitchMin = 0.8,
		PitchMax = 1.0,
	},
	{
		Name = "FloorboardCreak",
		SoundId = "rbxassetid://148088329", -- Single loud floorboard creak, as if someone stepped nearby. (Door Creak - works for wood creak)
		Volume = 0.4,
		PitchMin = 0.85,
		PitchMax = 1.15,
	},
	{
		Name = "ChildLaugh",
		SoundId = "rbxassetid://5167850250", -- Faint, distant child's laugh. Very creepy. (Creepy Child Laugh)
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
		SoundId = "rbxassetid://7128958209", -- Satisfying chime / ding. (Bell Ding Sound Effect)
		Volume = 0.6,
		PitchMin = 1.0,
		PitchMax = 1.0,
	},
	DeathSting = {
		SoundId = "rbxassetid://5775523429", -- Dramatic low stab sound + reverb. Like a horror movie sting. (Horror Stab Sound Effect)
		Volume = 0.7,
		PitchMin = 1.0,
		PitchMax = 1.0,
	},
	KeyCollected = {
		SoundId = "rbxassetid://3144041977", -- Key jingle / metallic clink. (Key pickup sound)
		Volume = 0.5,
		PitchMin = 0.95,
		PitchMax = 1.05,
	},
	DoorOpen = {
		SoundId = "rbxassetid://6814491848", -- Heavy door opening creak. (Door Open Sound)
		Volume = 0.5,
		PitchMin = 0.9,
		PitchMax = 1.1,
	},
	DoorLocked = {
		SoundId = "rbxassetid://6814495006", -- Rattling locked door handle. (Door Locked Sound)
		Volume = 0.5,
		PitchMin = 0.95,
		PitchMax = 1.05,
	},
	TreatCollected = {
		SoundId = "rbxassetid://3292075199", -- Small positive pickup sound, sparkle-like. (Sparkle Noise - Sound Effect)
		Volume = 0.4,
		PitchMin = 0.95,
		PitchMax = 1.1,
	},
	StoryNoteFound = {
		SoundId = "rbxassetid://7196414334", -- Paper rustling / page turning. (door opening/closing sound - light rustling)
		Volume = 0.4,
		PitchMin = 0.95,
		PitchMax = 1.05,
	},
	HideEnter = {
		SoundId = "rbxassetid://7792948465", -- Quick shuffling / closet door closing. (Door Opening Sound Effect)
		Volume = 0.4,
		PitchMin = 0.9,
		PitchMax = 1.1,
	},
	HideExit = {
		SoundId = "rbxassetid://6058561902", -- Closet / cupboard opening. (Door Open)
		Volume = 0.4,
		PitchMin = 0.9,
		PitchMax = 1.1,
	},
	FlashlightOn = {
		SoundId = "rbxassetid://198914875", -- Flashlight click on. (Flashlight On)
		Volume = 0.3,
		PitchMin = 1.0,
		PitchMax = 1.0,
	},
	FlashlightOff = {
		SoundId = "rbxassetid://5991592592", -- Flashlight click off. (Flashlight Click)
		Volume = 0.3,
		PitchMin = 1.0,
		PitchMax = 1.0,
	},
}

return SoundConfig

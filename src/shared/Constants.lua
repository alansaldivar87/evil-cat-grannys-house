-- Constants shared between server and client
-- All tunable game values live here

local Constants = {}

-- Cat AI
Constants.CAT_WALK_SPEED = 10
Constants.CAT_CHASE_SPEED = 22 -- Player default is 16
Constants.CAT_DETECTION_RANGE = 40
Constants.CAT_ATTACK_RANGE = 5
Constants.CAT_ATTACK_DAMAGE = 50
Constants.CAT_ATTACK_COOLDOWN = 1.5
Constants.CAT_LOSE_INTEREST_RANGE = 60
Constants.CAT_WARNING_DURATION = 0.5 -- Hiss pause before chasing

-- Boss Cat
Constants.BOSS_CAT_HEALTH = 500
Constants.BOSS_CAT_WALK_SPEED = 14
Constants.BOSS_CAT_CHASE_SPEED = 26
Constants.BOSS_CAT_ATTACK_DAMAGE = 35
Constants.BOSS_CAT_ENRAGE_THRESHOLD = 0.5 -- 50% health
Constants.BOSS_CAT_ENRAGED_SPEED = 30
Constants.BOSS_CAT_ENRAGED_COOLDOWN = 0.8
Constants.BOSS_SUMMON_COUNT = 2 -- Mini cats summoned
Constants.BOSS_SUMMON_INTERVAL = 15 -- Seconds between summons

-- Weapon
Constants.WEAPON_DAMAGE = 25
Constants.WEAPON_RANGE = 50

-- Player
Constants.PLAYER_MAX_HEALTH = 100
Constants.RESPAWN_TIME = 3

-- Game
Constants.MAX_PLAYERS = 10
Constants.VICTORY_WAIT_TIME = 10

-- Pathfinding
Constants.PATHFIND_AGENT_RADIUS = 2
Constants.PATHFIND_AGENT_HEIGHT = 3

-- Story System
Constants.STORY_NOTE_DISPLAY_DURATION = 12
Constants.STORY_NOTE_FADE_TIME = 1.5
Constants.STORY_NOTE_COOLDOWN = 2
Constants.TOTAL_DIARY_ENTRIES = 10

-- Hiding System
Constants.HIDE_ENTER_DURATION = 0.5
Constants.HIDE_EXIT_DURATION = 0.3
Constants.HIDE_PROMPT_DISTANCE = 8
Constants.HIDE_PROMPT_TEXT = "Hide"
Constants.HIDE_PROMPT_TEXT_EXIT = "Leave Hiding Spot"

-- Flashlight
Constants.FLASHLIGHT_MAX_BATTERY = 100
Constants.FLASHLIGHT_DRAIN_RATE = 5
Constants.FLASHLIGHT_RECHARGE_RATE = 8
Constants.FLASHLIGHT_RANGE = 60
Constants.FLASHLIGHT_BRIGHTNESS = 1.5
Constants.FLASHLIGHT_ANGLE = 45
Constants.FLASHLIGHT_SLOW_FACTOR = 0.7
Constants.FLASHLIGHT_SLOW_RANGE = 30

-- Collectibles (Cat Treats)
Constants.TREAT_SCORE_VALUE = 10
Constants.TREAT_COLLECT_RADIUS = 5
Constants.TREATS_PER_ROOM_BONUS = 5
Constants.TREAT_BOB_SPEED = 2
Constants.TREAT_BOB_HEIGHT = 0.8

-- Door System
Constants.DOOR_OPEN_SPEED = 0.5
Constants.DOOR_SLOW_CAT_DURATION = 3
Constants.DOOR_SLOW_FACTOR = 0.4
Constants.DOOR_PROMPT_DISTANCE = 8

-- Tags (CollectionService)
Constants.TAG_EVIL_CAT = "EvilCat"
Constants.TAG_BOSS_CAT = "BossCat"
Constants.TAG_CHECKPOINT = "Checkpoint"
Constants.TAG_PATROL_POINT = "PatrolPoint"
Constants.TAG_KILL_BRICK = "KillBrick"
Constants.TAG_MOVING_PLATFORM = "MovingPlatform"
Constants.TAG_DISAPPEARING_PLATFORM = "DisappearingPlatform"
Constants.TAG_BOSS_ARENA = "BossArena"
Constants.TAG_WEAPON_PICKUP = "WeaponPickup"
Constants.TAG_FLICKER_LIGHT = "FlickerLight"
Constants.TAG_FOG_ZONE = "FogZone"
Constants.TAG_ROOM = "Room"
Constants.TAG_STORY_NOTE = "StoryNote"
Constants.TAG_HIDING_SPOT = "HidingSpot"
Constants.TAG_CAT_TREAT = "CatTreat"
Constants.TAG_DOOR = "Door"
Constants.TAG_LOCKED_DOOR = "LockedDoor"
Constants.TAG_KEY = "Key"
Constants.TAG_SECRET_PASSAGE = "SecretPassage"

-- RemoteEvent names
Constants.EVENT_CHECKPOINT_REACHED = "CheckpointReached"
Constants.EVENT_PLAYER_JOINED = "PlayerJoined"
Constants.EVENT_BOSS_FIGHT_START = "BossFightStart"
Constants.EVENT_BOSS_HEALTH_UPDATE = "BossHealthUpdate"
Constants.EVENT_BOSS_DEFEATED = "BossDefeated"
Constants.EVENT_WEAPON_ATTACK = "WeaponAttack"
Constants.EVENT_CAT_WARNING = "CatWarning"
Constants.EVENT_CAMERA_SHAKE = "CameraShake"
Constants.EVENT_GAME_STATE_CHANGED = "GameStateChanged"
Constants.EVENT_PLAYER_DAMAGED = "PlayerDamaged"
Constants.EVENT_VICTORY_CELEBRATION = "VictoryCelebration"
Constants.EVENT_STORY_NOTE_SHOW = "StoryNoteShow"
Constants.EVENT_HIDE_STATE_CHANGED = "HideStateChanged"
Constants.EVENT_FLASHLIGHT_TOGGLE = "FlashlightToggle"
Constants.EVENT_FLASHLIGHT_BATTERY = "FlashlightBattery"
Constants.EVENT_TREAT_COLLECTED = "TreatCollected"
Constants.EVENT_ROOM_TREATS_COMPLETE = "RoomTreatsComplete"
Constants.EVENT_DOOR_TOGGLE = "DoorToggle"
Constants.EVENT_KEY_COLLECTED = "KeyCollected"
Constants.EVENT_PLAYER_HIDDEN = "PlayerHidden"

-- Monetization RemoteEvent / RemoteFunction names
Constants.EVENT_PROMPT_GAME_PASS = "PromptGamePass"
Constants.EVENT_GAME_PASS_OWNED = "GamePassOwned"
Constants.EVENT_PROMPT_PRODUCT = "PromptProduct"
Constants.EVENT_PRODUCT_EFFECT_GRANTED = "ProductEffectGranted"
Constants.EVENT_DAILY_REWARD_READY = "DailyRewardReady"
Constants.EVENT_CLAIM_DAILY_REWARD = "ClaimDailyReward"
Constants.EVENT_DAILY_REWARD_CLAIMED = "DailyRewardClaimed"
Constants.EVENT_OPEN_SHOP = "OpenShop"
Constants.EVENT_INVITE_FRIEND = "InviteFriend"
Constants.EVENT_INVITE_BONUS_GRANTED = "InviteBonusGranted"
Constants.EVENT_STATS_UPDATED = "StatsUpdated"
Constants.EVENT_LIKE_GAME_PROMPT = "LikeGamePrompt"
Constants.FUNC_GET_PASS_STATUS = "GetPassStatus"
Constants.FUNC_GET_PLAYER_STATS = "GetPlayerStats"
Constants.FUNC_GET_DAILY_REWARD_INFO = "GetDailyRewardInfo"

-- ==========================================
-- GAME PASS IDs (replace with real IDs after creating in Roblox Studio)
-- To create: Game Settings > Monetization > Passes > Create a Pass
-- ==========================================
Constants.GAME_PASS_IDS = {
	VIP = 0,             -- TODO: Replace with real Game Pass ID
	EXTRA_LIVES = 0,     -- TODO: Replace with real Game Pass ID
	PET_COMPANION = 0,   -- TODO: Replace with real Game Pass ID
	RADIO = 0,           -- TODO: Replace with real Game Pass ID
}

-- Game Pass display info (for shop UI)
Constants.GAME_PASS_INFO = {
	VIP = {
		name = "VIP Pass",
		description = "2x speed boost, golden flashlight, VIP chat tag, exclusive VIP room with bonus loot!",
		icon = "rbxassetid://0", -- TODO: Replace with real icon asset
		color = Color3.fromRGB(255, 215, 0),
	},
	EXTRA_LIVES = {
		name = "Extra Lives",
		description = "Get 3 extra lives per round! Revive on the spot instead of dying immediately.",
		icon = "rbxassetid://0",
		color = Color3.fromRGB(255, 80, 80),
	},
	PET_COMPANION = {
		name = "Ghost Cat Pet",
		description = "A friendly ghost cat follows you and glows red when evil cats are nearby!",
		icon = "rbxassetid://0",
		color = Color3.fromRGB(150, 200, 255),
	},
	RADIO = {
		name = "Radio Pass",
		description = "Play music in-game from a custom playlist while you explore!",
		icon = "rbxassetid://0",
		color = Color3.fromRGB(200, 100, 255),
	},
}

-- ==========================================
-- DEVELOPER PRODUCT IDs (replace with real IDs after creating in Roblox Studio)
-- To create: Game Settings > Monetization > Developer Products > Create
-- ==========================================
Constants.PRODUCT_IDS = {
	SPEED_BOOST = 0,     -- TODO: Replace with real Developer Product ID
	SHIELD = 0,          -- TODO: Replace with real Developer Product ID
	REVIVE_TOKEN = 0,    -- TODO: Replace with real Developer Product ID
	CAT_TREATS = 0,      -- TODO: Replace with real Developer Product ID
}

-- Developer Product display info
Constants.PRODUCT_INFO = {
	SPEED_BOOST = {
		name = "Speed Boost",
		description = "1.5x speed for 60 seconds!",
		icon = "rbxassetid://0",
		color = Color3.fromRGB(0, 200, 255),
		priceRobux = 25,
	},
	SHIELD = {
		name = "Shield",
		description = "Blocks one cat attack! Shimmers when active.",
		icon = "rbxassetid://0",
		color = Color3.fromRGB(100, 255, 100),
		priceRobux = 35,
	},
	REVIVE_TOKEN = {
		name = "Revive Token",
		description = "Instant self-revive at your death location!",
		icon = "rbxassetid://0",
		color = Color3.fromRGB(255, 200, 50),
		priceRobux = 50,
	},
	CAT_TREATS = {
		name = "Cat Treats Pack",
		description = "Reveals all collectibles in the current room on the minimap!",
		icon = "rbxassetid://0",
		color = Color3.fromRGB(255, 150, 100),
		priceRobux = 15,
	},
}

-- ==========================================
-- MONETIZATION GAMEPLAY VALUES
-- ==========================================

-- VIP Pass
Constants.VIP_SPEED_MULTIPLIER = 2.0
Constants.VIP_FLASHLIGHT_COLOR = Color3.fromRGB(255, 215, 0)
Constants.VIP_CHAT_TAG = "[VIP]"

-- Extra Lives Pass
Constants.EXTRA_LIVES_PER_ROUND = 3

-- Pet Companion
Constants.PET_FOLLOW_DISTANCE = 5
Constants.PET_WARNING_RANGE = 30
Constants.PET_FLOAT_HEIGHT = 3

-- Speed Boost (consumable)
Constants.SPEED_BOOST_MULTIPLIER = 1.5
Constants.SPEED_BOOST_DURATION = 60

-- Shield (consumable)
Constants.SHIELD_HITS_BLOCKED = 1

-- Daily Rewards
Constants.DAILY_REWARD_CYCLE_LENGTH = 7
Constants.DAILY_REWARDS = {
	{ day = 1, type = "coins",    amount = 50,  label = "50 Coins" },
	{ day = 2, type = "coins",    amount = 75,  label = "75 Coins" },
	{ day = 3, type = "xp",      amount = 200, label = "200 Bonus XP" },
	{ day = 4, type = "coins",    amount = 100, label = "100 Coins" },
	{ day = 5, type = "cosmetic", item = "GhostTrail", label = "Ghost Trail Effect" },
	{ day = 6, type = "coins",    amount = 150, label = "150 Coins" },
	{ day = 7, type = "coins",    amount = 300, label = "300 Coins + Mystery Box" },
}

-- Social
Constants.INVITE_BONUS_COINS = 100
Constants.GROUP_BONUS_MULTIPLIER = 1.10
Constants.GROUP_ID = 0                            -- TODO: Replace with your Roblox Group ID

-- Coins
Constants.COINS_PER_CAT_DEFEATED = 10
Constants.COINS_PER_BOSS_DEFEATED = 100
Constants.COINS_PER_CHECKPOINT = 25
Constants.COINS_PER_COLLECTIBLE = 5
Constants.COINS_PER_GAME_COMPLETION = 200

-- DataStore keys
Constants.DATASTORE_PLAYER_STATS = "PlayerStats_v1"
Constants.DATASTORE_DAILY_REWARDS = "DailyRewards_v1"
Constants.DATASTORE_PURCHASES = "Purchases_v1"
Constants.DATASTORE_SOCIAL = "Social_v1"

return Constants

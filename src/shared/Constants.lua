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

return Constants

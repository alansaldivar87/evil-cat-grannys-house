-- Game state definitions

local GameState = {}

GameState.States = {
	WAITING = "Waiting",
	PLAYING = "Playing",
	BOSS_FIGHT = "BossFight",
	VICTORY = "Victory",
}

GameState.CatStates = {
	PATROL = "Patrol",
	WARNING = "Warning",
	CHASE = "Chase",
	ATTACK = "Attack",
}

GameState.BossPhases = {
	NORMAL = "Normal",
	ENRAGED = "Enraged",
}

return GameState

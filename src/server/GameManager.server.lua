--[[
	GameManager - Server-side game orchestration
	Handles: player lifecycle, game state transitions, RemoteEvent setup, cat spawning
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local GameState = require(Shared:WaitForChild("GameState"))

-- Create RemoteEvents folder
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

-- Create all RemoteEvents
local remoteEventNames = {
	Constants.EVENT_CHECKPOINT_REACHED,
	Constants.EVENT_PLAYER_JOINED,
	Constants.EVENT_BOSS_FIGHT_START,
	Constants.EVENT_BOSS_HEALTH_UPDATE,
	Constants.EVENT_BOSS_DEFEATED,
	Constants.EVENT_WEAPON_ATTACK,
	Constants.EVENT_CAT_WARNING,
	Constants.EVENT_CAMERA_SHAKE,
	Constants.EVENT_GAME_STATE_CHANGED,
	Constants.EVENT_PLAYER_DAMAGED,
	Constants.EVENT_VICTORY_CELEBRATION,
	Constants.EVENT_STORY_NOTE_SHOW,
	Constants.EVENT_HIDE_STATE_CHANGED,
	Constants.EVENT_FLASHLIGHT_TOGGLE,
	Constants.EVENT_FLASHLIGHT_BATTERY,
	Constants.EVENT_TREAT_COLLECTED,
	Constants.EVENT_ROOM_TREATS_COMPLETE,
	Constants.EVENT_DOOR_TOGGLE,
	Constants.EVENT_KEY_COLLECTED,
	Constants.EVENT_PLAYER_HIDDEN,
}

for _, eventName in remoteEventNames do
	local event = Instance.new("RemoteEvent")
	event.Name = eventName
	event.Parent = remotes
end

-- Game state
local currentState = GameState.States.WAITING
local playerCheckpoints: { [number]: BasePart } = {}
local catSpawned = false

local function setGameState(newState: string)
	currentState = newState
	remotes[Constants.EVENT_GAME_STATE_CHANGED]:FireAllClients(newState)
	print("[GameManager] State changed to:", newState)
end

local function getDefaultSpawn(): BasePart?
	-- Find the checkpoint with the lowest Order attribute, or any SpawnLocation
	local checkpoints = CollectionService:GetTagged(Constants.TAG_CHECKPOINT)
	local lowestOrder = math.huge
	local defaultCheckpoint: BasePart? = nil

	for _, checkpoint in checkpoints do
		local order = checkpoint:GetAttribute("Order") or math.huge
		if order < lowestOrder then
			lowestOrder = order
			defaultCheckpoint = checkpoint
		end
	end

	if defaultCheckpoint then
		return defaultCheckpoint
	end

	-- Fallback to any SpawnLocation in workspace
	return workspace:FindFirstChildOfClass("SpawnLocation")
end

local function spawnCats()
	if catSpawned then
		return
	end
	catSpawned = true

	-- Clone EvilCat from ServerStorage into Workspace
	local catTemplate = ServerStorage:FindFirstChild("EvilCat")
	if not catTemplate then
		warn("[GameManager] No EvilCat model found in ServerStorage! Please add one in Roblox Studio.")
		return
	end

	-- Find patrol points and spawn cats near them
	local patrolPoints = CollectionService:GetTagged(Constants.TAG_PATROL_POINT)
	if #patrolPoints == 0 then
		warn("[GameManager] No PatrolPoints found! Add Parts tagged 'PatrolPoint' in Studio.")
		-- Spawn one cat at origin as fallback
		local cat = catTemplate:Clone()
		cat.Parent = workspace
		CollectionService:AddTag(cat, Constants.TAG_EVIL_CAT)
		return
	end

	-- Spawn one cat at the first patrol point
	local cat = catTemplate:Clone()
	local spawnPoint = patrolPoints[1]
	if cat.PrimaryPart then
		cat:PivotTo(spawnPoint.CFrame + Vector3.new(0, 3, 0))
	end
	cat.Parent = workspace
	CollectionService:AddTag(cat, Constants.TAG_EVIL_CAT)
	print("[GameManager] Evil cat spawned!")
end

local function onPlayerAdded(player: Player)
	print("[GameManager] Player joined:", player.Name)

	-- Notify all clients
	remotes[Constants.EVENT_PLAYER_JOINED]:FireAllClients(player.Name, #Players:GetPlayers())

	player.CharacterAdded:Connect(function(character)
		-- Set up health
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.MaxHealth = Constants.PLAYER_MAX_HEALTH
		humanoid.Health = Constants.PLAYER_MAX_HEALTH

		-- Respawn at checkpoint on death
		humanoid.Died:Connect(function()
			task.wait(Constants.RESPAWN_TIME)

			-- Respawn at last checkpoint or default spawn
			local checkpoint = playerCheckpoints[player.UserId]
			if not checkpoint then
				checkpoint = getDefaultSpawn()
			end

			player:LoadCharacter()

			if checkpoint then
				-- Wait for character to load then teleport
				local newChar = player.CharacterAdded:Wait()
				local rootPart = newChar:WaitForChild("HumanoidRootPart")
				task.wait(0.1) -- Brief wait for physics
				rootPart.CFrame = checkpoint.CFrame + Vector3.new(0, 5, 0)
			end
		end)
	end)

	-- Start the game when first player joins
	if currentState == GameState.States.WAITING then
		setGameState(GameState.States.PLAYING)
		spawnCats()
	end
end

local function onPlayerRemoving(player: Player)
	playerCheckpoints[player.UserId] = nil
	print("[GameManager] Player left:", player.Name)
end

-- Expose checkpoint storage for CheckpointManager
local GameManager = {}

function GameManager.setPlayerCheckpoint(player: Player, checkpoint: BasePart)
	playerCheckpoints[player.UserId] = checkpoint
end

function GameManager.getPlayerCheckpoint(player: Player): BasePart?
	return playerCheckpoints[player.UserId]
end

function GameManager.getCurrentState(): string
	return currentState
end

function GameManager.setGameState(newState: string)
	setGameState(newState)
end

-- Store as module in ServerStorage for other server scripts to access
local managerModule = Instance.new("ModuleScript")
managerModule.Name = "GameManagerAPI"
managerModule.Source = "" -- This is handled via the shared reference below
managerModule.Parent = ServerStorage

-- Since Rojo manages our scripts, we use a shared value to expose the API
local gameManagerRef = Instance.new("ObjectValue")
gameManagerRef.Name = "GameManagerRef"
gameManagerRef.Parent = ServerStorage

-- Connect events
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players already in game (for Studio testing)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- Store checkpoint setter in a BindableFunction for cross-script communication
local setCheckpointFunc = Instance.new("BindableFunction")
setCheckpointFunc.Name = "SetPlayerCheckpoint"
setCheckpointFunc.OnInvoke = function(playerId: number, checkpoint: BasePart)
	playerCheckpoints[playerId] = checkpoint
end
setCheckpointFunc.Parent = ServerStorage

local getStateFunc = Instance.new("BindableFunction")
getStateFunc.Name = "GetGameState"
getStateFunc.OnInvoke = function()
	return currentState
end
getStateFunc.Parent = ServerStorage

local setStateEvent = Instance.new("BindableEvent")
setStateEvent.Name = "SetGameState"
setStateEvent.Event:Connect(function(newState: string)
	setGameState(newState)
end)
setStateEvent.Parent = ServerStorage

print("[GameManager] Initialized. Waiting for players...")

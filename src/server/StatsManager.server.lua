--[[
	StatsManager - Player statistics tracking and leaderboard
	Tracks: games played, cats defeated, fastest time, collectibles, deaths
	Uses DataStoreService with pcall error handling and retry logic.
	Creates leaderstats for the in-game player list.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- ==========================================
-- REMOTE SETUP
-- ==========================================

local function ensureRemote(name: string, className: string): Instance
	local existing = Remotes:FindFirstChild(name)
	if existing then
		return existing
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = Remotes
	return remote
end

ensureRemote(Constants.EVENT_STATS_UPDATED, "RemoteEvent")
local getStatsFunc = ensureRemote(Constants.FUNC_GET_PLAYER_STATS, "RemoteFunction")

-- ==========================================
-- DATASTORE
-- ==========================================

local statsStore = DataStoreService:GetDataStore(Constants.DATASTORE_PLAYER_STATS)

local MAX_RETRIES = 3
local RETRY_DELAY = 1
local AUTO_SAVE_INTERVAL = 120 -- Save every 2 minutes

-- In-memory stats cache
local playerStats: { [number]: { [string]: number } } = {}

-- Whether a player's stats have been modified since last save
local dirtyFlags: { [number]: boolean } = {}

-- Track game start times for "fastest completion"
local gameStartTimes: { [number]: number } = {}

-- Default stats template
local function getDefaultStats(): { [string]: number }
	return {
		gamesPlayed = 0,
		catsDefeated = 0,
		fastestTime = 0,        -- 0 means no completion yet
		collectiblesFound = 0,
		totalDeaths = 0,
		coins = 0,
		xp = 0,
	}
end

-- ==========================================
-- DATA LOAD / SAVE WITH RETRIES
-- ==========================================

local function loadPlayerStats(userId: number): { [string]: number }?
	for attempt = 1, MAX_RETRIES do
		local success, result = pcall(function()
			return statsStore:GetAsync("stats_" .. tostring(userId))
		end)

		if success then
			if result then
				-- Merge with defaults to handle new fields added in updates
				local defaults = getDefaultStats()
				for key, defaultValue in defaults do
					if result[key] == nil then
						result[key] = defaultValue
					end
				end
				return result
			else
				-- New player
				return getDefaultStats()
			end
		end

		warn("[StatsManager] Load attempt", attempt, "failed for userId", userId)
		if attempt < MAX_RETRIES then
			task.wait(RETRY_DELAY * attempt)
		end
	end

	warn("[StatsManager] All load attempts failed for userId", userId, "- using defaults")
	return getDefaultStats()
end

local function savePlayerStats(userId: number): boolean
	local stats = playerStats[userId]
	if not stats then
		return true -- Nothing to save
	end

	for attempt = 1, MAX_RETRIES do
		local success, err = pcall(function()
			statsStore:SetAsync("stats_" .. tostring(userId), stats)
		end)

		if success then
			dirtyFlags[userId] = false
			return true
		end

		warn("[StatsManager] Save attempt", attempt, "failed for userId", userId, ":", err)
		if attempt < MAX_RETRIES then
			task.wait(RETRY_DELAY * attempt)
		end
	end

	warn("[StatsManager] All save attempts failed for userId", userId)
	return false
end

-- ==========================================
-- LEADERSTATS (in-game player list)
-- ==========================================

local function createLeaderstats(player: Player, stats: { [string]: number })
	-- Remove existing leaderstats if any
	local existing = player:FindFirstChild("leaderstats")
	if existing then
		existing:Destroy()
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local catsDefeated = Instance.new("IntValue")
	catsDefeated.Name = "Cats"
	catsDefeated.Value = stats.catsDefeated
	catsDefeated.Parent = leaderstats

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = stats.coins
	coins.Parent = leaderstats

	local gamesPlayed = Instance.new("IntValue")
	gamesPlayed.Name = "Games"
	gamesPlayed.Value = stats.gamesPlayed
	gamesPlayed.Parent = leaderstats
end

local function updateLeaderstats(player: Player)
	local stats = playerStats[player.UserId]
	if not stats then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end

	local catsVal = leaderstats:FindFirstChild("Cats")
	if catsVal then
		catsVal.Value = stats.catsDefeated
	end

	local coinsVal = leaderstats:FindFirstChild("Coins")
	if coinsVal then
		coinsVal.Value = stats.coins
	end

	local gamesVal = leaderstats:FindFirstChild("Games")
	if gamesVal then
		gamesVal.Value = stats.gamesPlayed
	end
end

-- ==========================================
-- STAT MODIFICATION API
-- ==========================================

local function getStat(userId: number, statName: string): number
	local stats = playerStats[userId]
	if not stats then
		return 0
	end
	return stats[statName] or 0
end

local function incrementStat(userId: number, statName: string, amount: number?)
	local stats = playerStats[userId]
	if not stats then
		return
	end

	local increment = amount or 1
	stats[statName] = (stats[statName] or 0) + increment
	dirtyFlags[userId] = true

	-- Update leaderstats
	local player = Players:GetPlayerByUserId(userId)
	if player then
		updateLeaderstats(player)

		-- Notify client
		Remotes[Constants.EVENT_STATS_UPDATED]:FireClient(player, statName, stats[statName])
	end
end

local function setStat(userId: number, statName: string, value: number)
	local stats = playerStats[userId]
	if not stats then
		return
	end

	stats[statName] = value
	dirtyFlags[userId] = true

	local player = Players:GetPlayerByUserId(userId)
	if player then
		updateLeaderstats(player)
		Remotes[Constants.EVENT_STATS_UPDATED]:FireClient(player, statName, value)
	end
end

local function addCoins(userId: number, amount: number)
	-- Check for group bonus
	local player = Players:GetPlayerByUserId(userId)
	if player and Constants.GROUP_ID > 0 then
		local success, isInGroup = pcall(function()
			return player:IsInGroup(Constants.GROUP_ID)
		end)
		if success and isInGroup then
			amount = math.floor(amount * Constants.GROUP_BONUS_MULTIPLIER)
		end
	end

	incrementStat(userId, "coins", amount)
end

-- ==========================================
-- GAME EVENT TRACKING
-- ==========================================

-- Track deaths
local function onPlayerDeath(player: Player)
	incrementStat(player.UserId, "totalDeaths")
end

-- Track cat defeats (listen for evil cats dying)
CollectionService:GetInstanceRemovedSignal(Constants.TAG_EVIL_CAT):Connect(function(instance)
	-- Award coins to all players when a cat is defeated
	-- (In a more complex system, you'd track who dealt the killing blow)
	if instance:IsA("Model") then
		local humanoid = instance:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health <= 0 then
			for _, player in Players:GetPlayers() do
				incrementStat(player.UserId, "catsDefeated")
				addCoins(player.UserId, Constants.COINS_PER_CAT_DEFEATED)
			end
		end
	end
end)

-- Track game start (for fastest time)
local function onGameStarted()
	for _, player in Players:GetPlayers() do
		gameStartTimes[player.UserId] = os.clock()
		incrementStat(player.UserId, "gamesPlayed")
	end
end

-- Track game completion
local function onGameCompleted()
	local completionTime = os.clock()

	for _, player in Players:GetPlayers() do
		local userId = player.UserId
		local startTime = gameStartTimes[userId]

		if startTime then
			local elapsed = math.floor(completionTime - startTime)
			local currentFastest = getStat(userId, "fastestTime")

			-- Update fastest time if this is faster (or first completion)
			if currentFastest == 0 or elapsed < currentFastest then
				setStat(userId, "fastestTime", elapsed)
			end

			gameStartTimes[userId] = nil
		end

		-- Award completion coins
		addCoins(userId, Constants.COINS_PER_GAME_COMPLETION)
	end
end

-- Listen for game state changes
task.spawn(function()
	local setStateEvent = ServerStorage:WaitForChild("SetGameState", 10)
	if setStateEvent and setStateEvent:IsA("BindableEvent") then
		setStateEvent.Event:Connect(function(newState: string)
			if newState == "Playing" then
				onGameStarted()
			elseif newState == "Victory" then
				onGameCompleted()
			end
		end)
	end
end)

-- Track checkpoint coins
task.spawn(function()
	local checkpointReached = Remotes:WaitForChild(Constants.EVENT_CHECKPOINT_REACHED, 10)
	if checkpointReached then
		checkpointReached.OnServerEvent:Connect(function(player)
			addCoins(player.UserId, Constants.COINS_PER_CHECKPOINT)
		end)
	end
end)

-- Track collectible coins
task.spawn(function()
	local treatCollected = Remotes:WaitForChild(Constants.EVENT_TREAT_COLLECTED, 10)
	if treatCollected then
		treatCollected.OnServerEvent:Connect(function(player)
			incrementStat(player.UserId, "collectiblesFound")
			addCoins(player.UserId, Constants.COINS_PER_COLLECTIBLE)
		end)
	end
end)

-- ==========================================
-- CLIENT QUERIES
-- ==========================================

;(getStatsFunc :: RemoteFunction).OnServerInvoke = function(player: Player)
	local stats = playerStats[player.UserId]
	if stats then
		return stats
	end
	return getDefaultStats()
end

-- ==========================================
-- PLAYER LIFECYCLE
-- ==========================================

local function onPlayerAdded(player: Player)
	-- Load stats from DataStore
	task.spawn(function()
		local stats = loadPlayerStats(player.UserId)
		if stats then
			playerStats[player.UserId] = stats
			createLeaderstats(player, stats)
			print("[StatsManager] Stats loaded for", player.Name)
		end
	end)

	-- Track deaths
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			onPlayerDeath(player)
		end)
	end)
end

local function onPlayerRemoving(player: Player)
	local userId = player.UserId

	-- Final save
	if dirtyFlags[userId] then
		savePlayerStats(userId)
	end

	-- Clean up
	playerStats[userId] = nil
	dirtyFlags[userId] = nil
	gameStartTimes[userId] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- ==========================================
-- AUTO-SAVE LOOP
-- ==========================================

task.spawn(function()
	while true do
		task.wait(AUTO_SAVE_INTERVAL)

		for userId, dirty in dirtyFlags do
			if dirty then
				task.spawn(savePlayerStats, userId)
			end
		end
	end
end)

-- ==========================================
-- GAME SHUTDOWN SAVE
-- ==========================================

game:BindToClose(function()
	-- Save all dirty stats before server shuts down
	local saveTasks = {}
	for userId, dirty in dirtyFlags do
		if dirty then
			table.insert(saveTasks, task.spawn(savePlayerStats, userId))
		end
	end

	-- Wait a moment for saves to complete
	task.wait(3)
end)

-- ==========================================
-- BINDABLE API FOR OTHER SERVER SCRIPTS
-- ==========================================

local addCoinsFunc = Instance.new("BindableFunction")
addCoinsFunc.Name = "AddCoins"
addCoinsFunc.OnInvoke = function(userId: number, amount: number)
	addCoins(userId, amount)
end
addCoinsFunc.Parent = ServerStorage

local incrementStatFunc = Instance.new("BindableFunction")
incrementStatFunc.Name = "IncrementStat"
incrementStatFunc.OnInvoke = function(userId: number, statName: string, amount: number?)
	incrementStat(userId, statName, amount)
end
incrementStatFunc.Parent = ServerStorage

local getStatFunc = Instance.new("BindableFunction")
getStatFunc.Name = "GetStat"
getStatFunc.OnInvoke = function(userId: number, statName: string): number
	return getStat(userId, statName)
end
getStatFunc.Parent = ServerStorage

print("[StatsManager] Stats system initialized")

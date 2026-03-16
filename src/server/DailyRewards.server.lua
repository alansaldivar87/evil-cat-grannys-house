--[[
	DailyRewards - 7-day reward cycle that resets weekly
	Rewards: coins, cosmetic items, bonus XP
	Uses DataStoreService to persist last claim date and streak.
	Shows UI popup when player joins if they have unclaimed rewards.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
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

ensureRemote(Constants.EVENT_DAILY_REWARD_READY, "RemoteEvent")
ensureRemote(Constants.EVENT_CLAIM_DAILY_REWARD, "RemoteEvent")
ensureRemote(Constants.EVENT_DAILY_REWARD_CLAIMED, "RemoteEvent")
local getDailyInfoFunc = ensureRemote(Constants.FUNC_GET_DAILY_REWARD_INFO, "RemoteFunction")

-- ==========================================
-- DATASTORE
-- ==========================================

local dailyStore = DataStoreService:GetDataStore(Constants.DATASTORE_DAILY_REWARDS)

local MAX_RETRIES = 3
local RETRY_DELAY = 1

-- In-memory daily reward state per player
local playerDailyData: { [number]: {
	lastClaimDate: string,  -- "YYYY-MM-DD"
	currentDay: number,     -- 1 through 7
	streak: number,         -- consecutive days
} } = {}

-- ==========================================
-- DATE UTILITIES
-- ==========================================

local function getTodayDateString(): string
	local date = os.date("!*t") -- UTC to avoid timezone issues
	return string.format("%04d-%02d-%02d", date.year, date.month, date.day)
end

local function getYesterdayDateString(): string
	local yesterday = os.time() - 86400
	local date = os.date("!*t", yesterday)
	return string.format("%04d-%02d-%02d", date.year, date.month, date.day)
end

-- ==========================================
-- DATA LOAD / SAVE
-- ==========================================

local function loadDailyData(userId: number): { lastClaimDate: string, currentDay: number, streak: number }?
	for attempt = 1, MAX_RETRIES do
		local success, result = pcall(function()
			return dailyStore:GetAsync("daily_" .. tostring(userId))
		end)

		if success then
			if result then
				return result
			else
				-- New player
				return {
					lastClaimDate = "",
					currentDay = 1,
					streak = 0,
				}
			end
		end

		warn("[DailyRewards] Load attempt", attempt, "failed for userId", userId)
		if attempt < MAX_RETRIES then
			task.wait(RETRY_DELAY * attempt)
		end
	end

	warn("[DailyRewards] All load attempts failed for userId", userId)
	return nil
end

local function saveDailyData(userId: number): boolean
	local data = playerDailyData[userId]
	if not data then
		return true
	end

	for attempt = 1, MAX_RETRIES do
		local success, err = pcall(function()
			dailyStore:SetAsync("daily_" .. tostring(userId), data)
		end)

		if success then
			return true
		end

		warn("[DailyRewards] Save attempt", attempt, "failed for userId", userId, ":", err)
		if attempt < MAX_RETRIES then
			task.wait(RETRY_DELAY * attempt)
		end
	end

	return false
end

-- ==========================================
-- REWARD GRANTING
-- ==========================================

local function grantReward(player: Player, reward: { day: number, type: string, amount: number?, item: string?, label: string })
	local userId = player.UserId

	if reward.type == "coins" then
		-- Use StatsManager to add coins
		local addCoinsFunc = ServerStorage:FindFirstChild("AddCoins")
		if addCoinsFunc then
			addCoinsFunc:Invoke(userId, reward.amount or 0)
		end

	elseif reward.type == "xp" then
		-- Use StatsManager to add XP
		local incrementStatFunc = ServerStorage:FindFirstChild("IncrementStat")
		if incrementStatFunc then
			incrementStatFunc:Invoke(userId, "xp", reward.amount or 0)
		end

	elseif reward.type == "cosmetic" then
		-- Grant cosmetic item - store in player data
		-- For now, use an attribute on the player
		player:SetAttribute("Cosmetic_" .. (reward.item or "Unknown"), true)
		print("[DailyRewards] Cosmetic granted:", reward.item, "to", player.Name)
	end

	print("[DailyRewards] Granted day", reward.day, "reward to", player.Name, ":", reward.label)
end

-- ==========================================
-- CAN CLAIM CHECK
-- ==========================================

local function canClaimToday(userId: number): (boolean, number) -- canClaim, dayNumber
	local data = playerDailyData[userId]
	if not data then
		return false, 1
	end

	local today = getTodayDateString()
	local yesterday = getYesterdayDateString()

	-- Already claimed today
	if data.lastClaimDate == today then
		return false, data.currentDay
	end

	-- Determine what day they're on
	local dayNumber = data.currentDay

	if data.lastClaimDate == yesterday then
		-- Consecutive day - advance to next day
		dayNumber = data.currentDay + 1
		if dayNumber > Constants.DAILY_REWARD_CYCLE_LENGTH then
			dayNumber = 1 -- Reset cycle
		end
	elseif data.lastClaimDate == "" then
		-- Brand new player
		dayNumber = 1
	else
		-- Missed a day (or more) - reset to day 1
		dayNumber = 1
	end

	return true, dayNumber
end

-- ==========================================
-- CLAIM HANDLER
-- ==========================================

local function claimDailyReward(player: Player)
	local userId = player.UserId
	local canClaim, dayNumber = canClaimToday(userId)

	if not canClaim then
		warn("[DailyRewards]", player.Name, "cannot claim today (already claimed or data issue)")
		return
	end

	-- Find the reward for this day
	local reward = nil
	for _, r in Constants.DAILY_REWARDS do
		if r.day == dayNumber then
			reward = r
			break
		end
	end

	if not reward then
		warn("[DailyRewards] No reward configured for day", dayNumber)
		return
	end

	-- Grant the reward
	grantReward(player, reward)

	-- Update daily data
	local data = playerDailyData[userId]
	local yesterday = getYesterdayDateString()

	if data.lastClaimDate == yesterday then
		data.streak = data.streak + 1
	else
		data.streak = 1
	end

	data.lastClaimDate = getTodayDateString()
	data.currentDay = dayNumber

	-- Save to DataStore
	task.spawn(function()
		saveDailyData(userId)
	end)

	-- Notify client
	Remotes[Constants.EVENT_DAILY_REWARD_CLAIMED]:FireClient(player, {
		day = dayNumber,
		reward = reward,
		streak = data.streak,
		nextDay = dayNumber < Constants.DAILY_REWARD_CYCLE_LENGTH and dayNumber + 1 or 1,
	})

	print("[DailyRewards]", player.Name, "claimed day", dayNumber, "reward:", reward.label, "(streak:", data.streak, ")")
end

-- ==========================================
-- CLIENT EVENTS
-- ==========================================

-- Client clicks "Claim" button
Remotes[Constants.EVENT_CLAIM_DAILY_REWARD].OnServerEvent:Connect(function(player)
	claimDailyReward(player)
end)

-- Client queries daily reward info
;(getDailyInfoFunc :: RemoteFunction).OnServerInvoke = function(player: Player)
	local userId = player.UserId
	local canClaim, dayNumber = canClaimToday(userId)
	local data = playerDailyData[userId]

	return {
		canClaim = canClaim,
		currentDay = dayNumber,
		streak = data and data.streak or 0,
		lastClaimDate = data and data.lastClaimDate or "",
		rewards = Constants.DAILY_REWARDS,
	}
end

-- ==========================================
-- PLAYER LIFECYCLE
-- ==========================================

local function onPlayerAdded(player: Player)
	task.spawn(function()
		local data = loadDailyData(player.UserId)
		if data then
			playerDailyData[player.UserId] = data

			-- Check if player can claim a reward today
			local canClaim, dayNumber = canClaimToday(player.UserId)
			if canClaim then
				-- Wait a moment for client UI to load, then notify
				task.wait(3)

				-- Make sure player is still in the game
				if player.Parent then
					Remotes[Constants.EVENT_DAILY_REWARD_READY]:FireClient(player, {
						day = dayNumber,
						rewards = Constants.DAILY_REWARDS,
						streak = data.streak,
					})
				end
			end

			print("[DailyRewards] Daily data loaded for", player.Name, "- Can claim:", canClaim, "Day:", dayNumber)
		end
	end)
end

local function onPlayerRemoving(player: Player)
	local userId = player.UserId

	-- Final save
	if playerDailyData[userId] then
		saveDailyData(userId)
	end

	playerDailyData[userId] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- ==========================================
-- SHUTDOWN SAVE
-- ==========================================

game:BindToClose(function()
	for userId, _ in playerDailyData do
		task.spawn(saveDailyData, userId)
	end
	task.wait(3)
end)

print("[DailyRewards] Daily rewards system initialized")

--[[
	SocialManager - Social features for player growth
	Handles: friend invite bonus, group bonus, "like the game" prompt
	Uses DataStoreService to track invite relationships.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local SocialService = game:GetService("SocialService")
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

ensureRemote(Constants.EVENT_INVITE_FRIEND, "RemoteEvent")
ensureRemote(Constants.EVENT_INVITE_BONUS_GRANTED, "RemoteEvent")
ensureRemote(Constants.EVENT_LIKE_GAME_PROMPT, "RemoteEvent")

-- ==========================================
-- DATASTORE
-- ==========================================

local socialStore = DataStoreService:GetDataStore(Constants.DATASTORE_SOCIAL)

local MAX_RETRIES = 3
local RETRY_DELAY = 1

-- Track which players have been credited for invites this session
local inviteCredited: { [number]: { [number]: boolean } } = {} -- inviterUserId -> { inviteeUserId -> true }

-- Track who has been prompted to like the game
local likePrompted: { [number]: boolean } = {}

-- Track who has completed the game (for like prompt)
local hasCompletedGame: { [number]: boolean } = {}

-- ==========================================
-- INVITE SYSTEM
-- ==========================================

-- When player A invites player B, and B joins:
-- Both A and B get bonus coins.
-- We track this in DataStore to prevent abuse.

local function hasAlreadyInvited(inviterUserId: number, inviteeUserId: number): boolean
	local success, result = pcall(function()
		return socialStore:GetAsync("invite_" .. inviterUserId .. "_" .. inviteeUserId)
	end)

	if success and result then
		return true
	end
	return false
end

local function recordInvite(inviterUserId: number, inviteeUserId: number): boolean
	for attempt = 1, MAX_RETRIES do
		local success, err = pcall(function()
			socialStore:SetAsync("invite_" .. inviterUserId .. "_" .. inviteeUserId, {
				timestamp = os.time(),
			})
		end)

		if success then
			return true
		end

		warn("[SocialManager] Record invite attempt", attempt, "failed:", err)
		if attempt < MAX_RETRIES then
			task.wait(RETRY_DELAY * attempt)
		end
	end
	return false
end

local function grantInviteBonus(inviterPlayer: Player?, inviteePlayer: Player)
	local addCoinsFunc = ServerStorage:FindFirstChild("AddCoins")
	if not addCoinsFunc then
		warn("[SocialManager] AddCoins BindableFunction not found (StatsManager may not be loaded yet)")
		return
	end

	-- Grant coins to invitee
	addCoinsFunc:Invoke(inviteePlayer.UserId, Constants.INVITE_BONUS_COINS)
	Remotes[Constants.EVENT_INVITE_BONUS_GRANTED]:FireClient(inviteePlayer, {
		coins = Constants.INVITE_BONUS_COINS,
		reason = "Welcome bonus! Your friend invited you.",
	})

	-- Grant coins to inviter (if they're still online)
	if inviterPlayer and inviterPlayer.Parent then
		addCoinsFunc:Invoke(inviterPlayer.UserId, Constants.INVITE_BONUS_COINS)
		Remotes[Constants.EVENT_INVITE_BONUS_GRANTED]:FireClient(inviterPlayer, {
			coins = Constants.INVITE_BONUS_COINS,
			reason = inviteePlayer.Name .. " joined through your invite!",
		})
	end
end

-- ==========================================
-- FRIEND JOIN DETECTION
-- ==========================================

-- Check if a joining player was invited by any current player
local function checkForInviteBonus(newPlayer: Player)
	task.spawn(function()
		-- Wait for StatsManager to be ready
		task.wait(5)

		for _, existingPlayer in Players:GetPlayers() do
			if existingPlayer ~= newPlayer then
				-- Check if they're friends
				local areFriends = false
				local success, result = pcall(function()
					return existingPlayer:IsFriendsWith(newPlayer.UserId)
				end)

				if success and result then
					areFriends = true
				end

				if areFriends then
					local inviterId = existingPlayer.UserId
					local inviteeId = newPlayer.UserId

					-- Check session cache first
					if inviteCredited[inviterId] and inviteCredited[inviterId][inviteeId] then
						-- Already credited this session
						continue
					end

					-- Check DataStore for permanent record
					if hasAlreadyInvited(inviterId, inviteeId) then
						continue
					end

					-- Grant the bonus!
					grantInviteBonus(existingPlayer, newPlayer)

					-- Record it
					inviteCredited[inviterId] = inviteCredited[inviterId] or {}
					inviteCredited[inviterId][inviteeId] = true

					task.spawn(function()
						recordInvite(inviterId, inviteeId)
					end)

					print("[SocialManager] Invite bonus granted:", existingPlayer.Name, "->", newPlayer.Name)
					break -- Only credit one invite per join
				end
			end
		end
	end)
end

-- ==========================================
-- GROUP BONUS
-- ==========================================

-- Group bonus is handled in StatsManager's addCoins function.
-- Here we just notify the player if they're in the group.

local function checkGroupMembership(player: Player)
	if Constants.GROUP_ID == 0 then
		return
	end

	task.spawn(function()
		local success, isInGroup = pcall(function()
			return player:IsInGroup(Constants.GROUP_ID)
		end)

		if success and isInGroup then
			player:SetAttribute("IsGroupMember", true)
			print("[SocialManager]", player.Name, "is in the game's group - 10% coin bonus active!")
		end
	end)
end

-- ==========================================
-- LIKE THE GAME PROMPT
-- ==========================================

local function promptLikeGame(player: Player)
	if likePrompted[player.UserId] then
		return
	end
	likePrompted[player.UserId] = true

	-- Fire to client to show a "rate/like" prompt
	Remotes[Constants.EVENT_LIKE_GAME_PROMPT]:FireClient(player)
	print("[SocialManager] Like game prompt sent to", player.Name)
end

-- Listen for victory to trigger like prompt
task.spawn(function()
	local bossDefeated = Remotes:WaitForChild(Constants.EVENT_BOSS_DEFEATED, 10)
	if bossDefeated then
		bossDefeated.OnServerEvent:Connect(function(player)
			-- Not used directly since BossDefeated fires to all clients
		end)
	end

	-- Listen via BindableEvent instead
	local setStateEvent = ServerStorage:WaitForChild("SetGameState", 10)
	if setStateEvent and setStateEvent:IsA("BindableEvent") then
		setStateEvent.Event:Connect(function(newState: string)
			if newState == "Victory" then
				-- Prompt all players to like the game after a delay
				task.wait(5)
				for _, player in Players:GetPlayers() do
					if not hasCompletedGame[player.UserId] then
						hasCompletedGame[player.UserId] = true
						promptLikeGame(player)
					end
				end
			end
		end)
	end
end)

-- ==========================================
-- INVITE FRIEND BUTTON (client request)
-- ==========================================

Remotes[Constants.EVENT_INVITE_FRIEND].OnServerEvent:Connect(function(player)
	-- Use SocialService to prompt invite
	local success, err = pcall(function()
		SocialService:PromptGameInvite(player)
	end)

	if not success then
		warn("[SocialManager] Failed to prompt game invite for", player.Name, ":", err)
	end
end)

-- ==========================================
-- PLAYER LIFECYCLE
-- ==========================================

local function onPlayerAdded(player: Player)
	checkGroupMembership(player)
	checkForInviteBonus(player)
end

local function onPlayerRemoving(player: Player)
	inviteCredited[player.UserId] = nil
	likePrompted[player.UserId] = nil
	hasCompletedGame[player.UserId] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

print("[SocialManager] Social features initialized")
print("[SocialManager] NOTE: Set your Roblox Group ID in Constants.lua for group bonus!")

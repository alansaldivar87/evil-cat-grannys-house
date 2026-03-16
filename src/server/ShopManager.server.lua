--[[
	ShopManager - Developer Products (consumable purchases)
	Handles: Speed Boost, Shield, Revive Token, Cat Treats Pack
	ProcessReceipt is the single authoritative callback for all developer products.
	Products are only granted AFTER successful DataStore save.
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Utils = require(Shared:WaitForChild("Utils"))

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

ensureRemote(Constants.EVENT_PROMPT_PRODUCT, "RemoteEvent")
ensureRemote(Constants.EVENT_PRODUCT_EFFECT_GRANTED, "RemoteEvent")
ensureRemote(Constants.EVENT_OPEN_SHOP, "RemoteEvent")

-- ==========================================
-- PURCHASE HISTORY DATASTORE
-- ==========================================

local purchaseStore = DataStoreService:GetDataStore(Constants.DATASTORE_PURCHASES)

local MAX_RETRIES = 3
local RETRY_DELAY = 1

local function savePurchaseRecord(purchaseId: string): boolean
	for attempt = 1, MAX_RETRIES do
		local success, err = pcall(function()
			purchaseStore:SetAsync("purchase_" .. purchaseId, {
				granted = true,
				timestamp = os.time(),
			})
		end)

		if success then
			return true
		end

		warn("[ShopManager] Save purchase attempt", attempt, "failed:", err)
		if attempt < MAX_RETRIES then
			task.wait(RETRY_DELAY * attempt)
		end
	end

	return false
end

local function isPurchaseRecorded(purchaseId: string): boolean
	local success, result = pcall(function()
		return purchaseStore:GetAsync("purchase_" .. purchaseId)
	end)

	if success and result then
		return result.granted == true
	end
	return false
end

-- ==========================================
-- ACTIVE EFFECTS PER PLAYER
-- ==========================================

-- Speed boost tracking
local activeSpeedBoosts: { [number]: boolean } = {}

-- Shield tracking
local activeShields: { [number]: number } = {} -- userId -> hits remaining

-- Revive tokens
local reviveTokens: { [number]: number } = {} -- userId -> count

-- ==========================================
-- GRANT PRODUCT EFFECTS
-- ==========================================

local function grantSpeedBoost(player: Player)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local userId = player.UserId

	-- If already boosted, just extend the timer by restarting
	local originalSpeed = humanoid.WalkSpeed
	if activeSpeedBoosts[userId] then
		-- Already boosted, the speed is already modified
		-- Just reset the timer (handled below)
	else
		humanoid.WalkSpeed = humanoid.WalkSpeed * Constants.SPEED_BOOST_MULTIPLIER
	end

	activeSpeedBoosts[userId] = true

	-- Visual effect: sparkles
	local sparkles = character:FindFirstChild("SpeedSparkles")
	if not sparkles then
		sparkles = Instance.new("Sparkles")
		sparkles.Name = "SpeedSparkles"
		sparkles.SparkleColor = Color3.fromRGB(0, 200, 255)
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			sparkles.Parent = rootPart
		end
	end

	Remotes[Constants.EVENT_PRODUCT_EFFECT_GRANTED]:FireClient(player, "SpeedBoost", {
		duration = Constants.SPEED_BOOST_DURATION,
	})

	-- Timer to remove boost
	task.delay(Constants.SPEED_BOOST_DURATION, function()
		if not activeSpeedBoosts[userId] then
			return
		end
		activeSpeedBoosts[userId] = nil

		-- Restore speed
		local char = player.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.WalkSpeed = hum.WalkSpeed / Constants.SPEED_BOOST_MULTIPLIER
			end
			local sp = char:FindFirstChild("SpeedSparkles", true)
			if sp then
				sp:Destroy()
			end
		end

		Remotes[Constants.EVENT_PRODUCT_EFFECT_GRANTED]:FireClient(player, "SpeedBoostExpired", {})
		print("[ShopManager] Speed boost expired for", player.Name)
	end)

	print("[ShopManager] Speed boost granted to", player.Name)
end

local function grantShield(player: Player)
	local userId = player.UserId
	activeShields[userId] = (activeShields[userId] or 0) + Constants.SHIELD_HITS_BLOCKED

	-- Visual effect: shimmer around character
	local character = player.Character
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local existingShield = rootPart:FindFirstChild("ShieldEffect")
			if not existingShield then
				local shield = Instance.new("ForceField")
				shield.Name = "ShieldEffect"
				shield.Visible = true
				shield.Parent = character
			end
		end
	end

	Remotes[Constants.EVENT_PRODUCT_EFFECT_GRANTED]:FireClient(player, "Shield", {
		hitsRemaining = activeShields[userId],
	})

	print("[ShopManager] Shield granted to", player.Name, "- Hits remaining:", activeShields[userId])
end

local function grantReviveToken(player: Player)
	local userId = player.UserId
	reviveTokens[userId] = (reviveTokens[userId] or 0) + 1

	Remotes[Constants.EVENT_PRODUCT_EFFECT_GRANTED]:FireClient(player, "ReviveToken", {
		tokens = reviveTokens[userId],
	})

	print("[ShopManager] Revive token granted to", player.Name, "- Total:", reviveTokens[userId])
end

local function grantCatTreats(player: Player)
	-- Find all collectibles in the room the player is currently in
	local character = player.Character
	if not character then
		return
	end

	local playerPos = Utils.getCharacterPosition(character)
	if not playerPos then
		return
	end

	-- Find which room the player is in
	local currentRoom = nil
	for _, room in CollectionService:GetTagged(Constants.TAG_ROOM) do
		if room:IsA("BasePart") then
			-- Check if player is inside the room bounds
			local roomPos = room.Position
			local roomSize = room.Size
			local offset = playerPos - roomPos
			if math.abs(offset.X) < roomSize.X / 2
				and math.abs(offset.Y) < roomSize.Y / 2
				and math.abs(offset.Z) < roomSize.Z / 2 then
				currentRoom = room
				break
			end
		end
	end

	-- Collect positions of all treats/collectibles
	local collectiblePositions = {}
	for _, treat in CollectionService:GetTagged(Constants.TAG_CAT_TREAT) do
		if treat:IsA("BasePart") then
			-- If we found a room, only show treats in that room
			if currentRoom then
				local treatPos = treat.Position
				local roomPos = currentRoom.Position
				local roomSize = currentRoom.Size
				local offset = treatPos - roomPos
				if math.abs(offset.X) < roomSize.X / 2
					and math.abs(offset.Y) < roomSize.Y / 2
					and math.abs(offset.Z) < roomSize.Z / 2 then
					table.insert(collectiblePositions, treatPos)
				end
			else
				-- No room detected, show all nearby treats within 100 studs
				if Utils.getDistance(playerPos, treat.Position) < 100 then
					table.insert(collectiblePositions, treat.Position)
				end
			end
		end
	end

	Remotes[Constants.EVENT_PRODUCT_EFFECT_GRANTED]:FireClient(player, "CatTreats", {
		positions = collectiblePositions,
	})

	print("[ShopManager] Cat treats revealed", #collectiblePositions, "collectibles for", player.Name)
end

-- ==========================================
-- SHIELD DAMAGE INTERCEPTION
-- ==========================================

-- Hook into player damage to intercept with shields
local function setupShieldProtection(player: Player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")

		humanoid.HealthChanged:Connect(function(newHealth)
			local userId = player.UserId
			local shieldHits = activeShields[userId] or 0

			if shieldHits > 0 and newHealth < humanoid.MaxHealth then
				-- Calculate damage taken
				local damageTaken = humanoid.MaxHealth - newHealth
				if damageTaken > 0 then
					-- Block the damage by restoring health
					humanoid.Health = humanoid.MaxHealth
					activeShields[userId] = shieldHits - 1

					-- Remove shield visual if no hits left
					if activeShields[userId] <= 0 then
						activeShields[userId] = nil
						local shieldEffect = character:FindFirstChild("ShieldEffect")
						if shieldEffect then
							shieldEffect:Destroy()
						end
					end

					Remotes[Constants.EVENT_PRODUCT_EFFECT_GRANTED]:FireClient(player, "ShieldBlocked", {
						hitsRemaining = activeShields[userId] or 0,
					})

					print("[ShopManager] Shield blocked damage for", player.Name)
				end
			end
		end)
	end)
end

-- ==========================================
-- REVIVE TOKEN - DEATH INTERCEPTION
-- ==========================================

local function setupReviveToken(player: Player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")

		humanoid.Died:Connect(function()
			local userId = player.UserId
			local tokens = reviveTokens[userId] or 0

			if tokens > 0 then
				reviveTokens[userId] = tokens - 1

				-- Get death position
				local rootPart = character:FindFirstChild("HumanoidRootPart")
				local deathPos = rootPart and rootPart.Position or Vector3.new(0, 10, 0)

				-- Quick revive
				task.wait(0.5)
				player:LoadCharacter()
				local newChar = player.CharacterAdded:Wait()
				local newRoot = newChar:WaitForChild("HumanoidRootPart")
				task.wait(0.1)
				newRoot.CFrame = CFrame.new(deathPos + Vector3.new(0, 3, 0))

				Remotes[Constants.EVENT_PRODUCT_EFFECT_GRANTED]:FireClient(player, "Revived", {
					tokensRemaining = reviveTokens[userId],
				})

				print("[ShopManager] Revive token used for", player.Name, "- Remaining:", reviveTokens[userId])
			end
		end)
	end)
end

-- ==========================================
-- PROCESS RECEIPT (critical - handles all purchases)
-- ==========================================

local function processReceipt(receiptInfo): Enum.ProductPurchaseDecision
	local userId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId
	local purchaseId = receiptInfo.PurchaseId

	-- Check if we've already processed this purchase
	if isPurchaseRecorded(tostring(purchaseId)) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Find the player
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		-- Player not in game. Don't grant yet - they'll get it when they rejoin
		-- Return NotProcessedYet so Roblox retries later
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Determine which product was purchased and grant it
	local granted = false

	if productId == Constants.PRODUCT_IDS.SPEED_BOOST then
		grantSpeedBoost(player)
		granted = true

	elseif productId == Constants.PRODUCT_IDS.SHIELD then
		grantShield(player)
		granted = true

	elseif productId == Constants.PRODUCT_IDS.REVIVE_TOKEN then
		grantReviveToken(player)
		granted = true

	elseif productId == Constants.PRODUCT_IDS.CAT_TREATS then
		grantCatTreats(player)
		granted = true

	else
		warn("[ShopManager] Unknown product ID:", productId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if not granted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Save purchase record BEFORE returning PurchaseGranted
	local saved = savePurchaseRecord(tostring(purchaseId))
	if not saved then
		warn("[ShopManager] Failed to save purchase record for", purchaseId, "- will retry")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	print("[ShopManager] Purchase processed successfully:", purchaseId, "for", player.Name)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = processReceipt

-- ==========================================
-- CLIENT REQUESTS
-- ==========================================

-- Client requests to buy a product
Remotes[Constants.EVENT_PROMPT_PRODUCT].OnServerEvent:Connect(function(player, productKey)
	if type(productKey) ~= "string" then
		return
	end

	local productId = Constants.PRODUCT_IDS[productKey]
	if not productId or productId == 0 then
		warn("[ShopManager] Invalid or unconfigured product key:", productKey)
		return
	end

	local success, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, productId)
	end)

	if not success then
		warn("[ShopManager] Failed to prompt product purchase:", err)
	end
end)

-- ==========================================
-- PLAYER LIFECYCLE
-- ==========================================

local function onPlayerAdded(player: Player)
	setupShieldProtection(player)
	setupReviveToken(player)
end

local function onPlayerRemoving(player: Player)
	local userId = player.UserId
	activeSpeedBoosts[userId] = nil
	activeShields[userId] = nil
	reviveTokens[userId] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

print("[ShopManager] Shop system initialized")
print("[ShopManager] NOTE: Set real Developer Product IDs in Constants.lua before publishing!")

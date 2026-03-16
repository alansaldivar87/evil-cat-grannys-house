--[[
	GamePassManager - Server-side game pass ownership and effects
	Handles: VIP Pass, Extra Lives, Pet Companion, Radio Pass
	All pass checks are done server-side for security.
	Uses MarketplaceService to verify ownership - NEVER trusts the client.
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ChatService = nil -- Loaded lazily

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Utils = require(Shared:WaitForChild("Utils"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- ==========================================
-- INTERNAL STATE
-- ==========================================

-- Cache of pass ownership per player: { [userId] = { VIP = true, EXTRA_LIVES = false, ... } }
local passCache: { [number]: { [string]: boolean } } = {}

-- Extra lives remaining per player per round
local extraLivesRemaining: { [number]: number } = {}

-- Active pet models per player
local activePets: { [number]: Model } = {}

-- ==========================================
-- REMOTE SETUP
-- ==========================================

-- Create monetization remotes if they don't exist
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

ensureRemote(Constants.EVENT_PROMPT_GAME_PASS, "RemoteEvent")
ensureRemote(Constants.EVENT_GAME_PASS_OWNED, "RemoteEvent")
ensureRemote(Constants.EVENT_PRODUCT_EFFECT_GRANTED, "RemoteEvent")
local getPassStatusFunc = ensureRemote(Constants.FUNC_GET_PASS_STATUS, "RemoteFunction")

-- ==========================================
-- PASS OWNERSHIP CHECK (server-side only)
-- ==========================================

local function checkPassOwnership(player: Player, passKey: string): boolean
	local passId = Constants.GAME_PASS_IDS[passKey]
	if not passId or passId == 0 then
		-- Pass ID not configured yet; return false
		return false
	end

	local success, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)

	if success then
		return owns
	else
		warn("[GamePassManager] Failed to check pass ownership for", player.Name, passKey)
		return false
	end
end

local function cacheAllPasses(player: Player)
	local userId = player.UserId
	passCache[userId] = {}

	for passKey, _ in Constants.GAME_PASS_IDS do
		passCache[userId][passKey] = checkPassOwnership(player, passKey)
	end

	print("[GamePassManager] Cached passes for", player.Name, ":", passCache[userId])
end

local function ownsPass(player: Player, passKey: string): boolean
	local userId = player.UserId
	if not passCache[userId] then
		return false
	end
	return passCache[userId][passKey] == true
end

-- ==========================================
-- VIP PASS EFFECTS
-- ==========================================

local function applyVIPEffects(player: Player)
	if not ownsPass(player, "VIP") then
		return
	end

	-- Speed boost applied on character spawn
	local function onCharacterAdded(character: Model)
		local humanoid = character:WaitForChild("Humanoid")
		-- Apply double speed
		humanoid.WalkSpeed = humanoid.WalkSpeed * Constants.VIP_SPEED_MULTIPLIER

		-- Create golden flashlight effect: add a golden PointLight to the character
		local head = character:WaitForChild("Head", 5)
		if head then
			local existingLight = head:FindFirstChild("VIPFlashlight")
			if not existingLight then
				local light = Instance.new("SpotLight")
				light.Name = "VIPFlashlight"
				light.Color = Constants.VIP_FLASHLIGHT_COLOR
				light.Brightness = 2
				light.Range = 50
				light.Angle = 45
				light.Face = Enum.NormalId.Front
				light.Parent = head
			end
		end
	end

	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)

	-- VIP chat tag
	task.spawn(function()
		-- Try to add a chat tag using TextChatService (modern chat)
		local textChatService = game:GetService("TextChatService")
		-- Attributes-based approach for chat tags
		player:SetAttribute("ChatTag", Constants.VIP_CHAT_TAG)
		player:SetAttribute("ChatTagColor", "255,215,0")
	end)

	print("[GamePassManager] VIP effects applied for", player.Name)
end

-- ==========================================
-- EXTRA LIVES PASS
-- ==========================================

local function setupExtraLives(player: Player)
	if not ownsPass(player, "EXTRA_LIVES") then
		return
	end

	extraLivesRemaining[player.UserId] = Constants.EXTRA_LIVES_PER_ROUND

	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")

		humanoid.Died:Connect(function()
			local lives = extraLivesRemaining[player.UserId] or 0
			if lives > 0 then
				extraLivesRemaining[player.UserId] = lives - 1

				-- Revive on the spot after a brief delay
				task.wait(1)

				local rootPart = character:FindFirstChild("HumanoidRootPart")
				local deathPosition = rootPart and rootPart.Position or Vector3.new(0, 10, 0)

				player:LoadCharacter()
				local newChar = player.CharacterAdded:Wait()
				local newRoot = newChar:WaitForChild("HumanoidRootPart")
				task.wait(0.1)
				newRoot.CFrame = CFrame.new(deathPosition + Vector3.new(0, 3, 0))

				-- Notify client
				Remotes[Constants.EVENT_PRODUCT_EFFECT_GRANTED]:FireClient(
					player,
					"ExtraLife",
					{ livesRemaining = extraLivesRemaining[player.UserId] }
				)

				print("[GamePassManager] Extra life used for", player.Name, "- Remaining:", extraLivesRemaining[player.UserId])
			end
		end)
	end)
end

-- Reset extra lives each round (call from GameManager when a new round starts)
local function resetExtraLives(player: Player)
	if ownsPass(player, "EXTRA_LIVES") then
		extraLivesRemaining[player.UserId] = Constants.EXTRA_LIVES_PER_ROUND
	end
end

-- ==========================================
-- PET COMPANION
-- ==========================================

local function createGhostCatPet(player: Player): Model
	local pet = Instance.new("Model")
	pet.Name = player.Name .. "_GhostCat"

	-- Create a simple ghost cat body (sphere with cat ears)
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(2, 2, 2)
	body.Material = Enum.Material.ForceField
	body.BrickColor = BrickColor.new("Pastel light blue")
	body.Transparency = 0.4
	body.CanCollide = false
	body.Anchored = true
	body.Parent = pet

	-- Left ear
	local leftEar = Instance.new("Part")
	leftEar.Name = "LeftEar"
	leftEar.Size = Vector3.new(0.6, 0.8, 0.3)
	leftEar.Material = Enum.Material.ForceField
	leftEar.BrickColor = BrickColor.new("Pastel light blue")
	leftEar.Transparency = 0.4
	leftEar.CanCollide = false
	leftEar.Anchored = true
	leftEar.CFrame = body.CFrame * CFrame.new(-0.5, 1.2, 0)
	leftEar.Parent = pet

	-- Right ear
	local rightEar = Instance.new("Part")
	rightEar.Name = "RightEar"
	rightEar.Size = Vector3.new(0.6, 0.8, 0.3)
	rightEar.Material = Enum.Material.ForceField
	rightEar.BrickColor = BrickColor.new("Pastel light blue")
	rightEar.Transparency = 0.4
	rightEar.CanCollide = false
	rightEar.Anchored = true
	rightEar.CFrame = body.CFrame * CFrame.new(0.5, 1.2, 0)
	rightEar.Parent = pet

	-- Eyes (two small black spheres)
	for _, offset in { Vector3.new(-0.4, 0.2, -0.8), Vector3.new(0.4, 0.2, -0.8) } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(0.3, 0.3, 0.3)
		eye.Material = Enum.Material.Neon
		eye.BrickColor = BrickColor.new("Cyan")
		eye.Transparency = 0.2
		eye.CanCollide = false
		eye.Anchored = true
		eye.CFrame = body.CFrame * CFrame.new(offset)
		eye.Parent = pet
	end

	-- Glow light (changes color based on danger)
	local glow = Instance.new("PointLight")
	glow.Name = "WarningGlow"
	glow.Color = Color3.fromRGB(150, 200, 255) -- Calm blue
	glow.Brightness = 1
	glow.Range = 8
	glow.Parent = body

	pet.PrimaryPart = body
	pet.Parent = workspace

	return pet
end

local function updatePetPosition(player: Player, pet: Model)
	local character = player.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local body = pet:FindFirstChild("Body")
	if not body then
		return
	end

	-- Float behind and above the player
	local targetPos = rootPart.Position
		- rootPart.CFrame.LookVector * Constants.PET_FOLLOW_DISTANCE
		+ Vector3.new(0, Constants.PET_FLOAT_HEIGHT, 0)

	-- Gentle bobbing
	local bobOffset = math.sin(tick() * 2) * 0.3

	-- Smooth follow
	local currentPos = body.Position
	local newPos = currentPos:Lerp(targetPos + Vector3.new(0, bobOffset, 0), 0.1)

	-- Move all parts relative to body
	local delta = newPos - body.Position
	for _, part in pet:GetChildren() do
		if part:IsA("BasePart") then
			part.Position = part.Position + delta
		end
	end
end

local function updatePetWarning(player: Player, pet: Model)
	local character = player.Character
	if not character then
		return
	end

	local playerPos = Utils.getCharacterPosition(character)
	if not playerPos then
		return
	end

	local body = pet:FindFirstChild("Body")
	if not body then
		return
	end

	local glow = body:FindFirstChild("WarningGlow")
	if not glow then
		return
	end

	-- Check distance to nearest evil cat
	local nearestCatDist = math.huge
	for _, cat in CollectionService:GetTagged(Constants.TAG_EVIL_CAT) do
		if cat:IsA("Model") then
			local catRoot = cat.PrimaryPart or cat:FindFirstChild("HumanoidRootPart")
			if catRoot then
				local dist = Utils.getDistance(playerPos, catRoot.Position)
				if dist < nearestCatDist then
					nearestCatDist = dist
				end
			end
		end
	end

	-- Change color based on proximity
	if nearestCatDist < Constants.PET_WARNING_RANGE then
		-- Danger! Glow red with pulsing intensity
		local pulse = (math.sin(tick() * 6) + 1) / 2
		glow.Color = Color3.fromRGB(255, 0, 0)
		glow.Brightness = 1 + pulse * 2
		body.BrickColor = BrickColor.new("Really red")
		body.Transparency = 0.3 + pulse * 0.2
	else
		-- Safe - calm blue glow
		glow.Color = Color3.fromRGB(150, 200, 255)
		glow.Brightness = 1
		body.BrickColor = BrickColor.new("Pastel light blue")
		body.Transparency = 0.4
	end
end

local function spawnPet(player: Player)
	if not ownsPass(player, "PET_COMPANION") then
		return
	end

	-- Remove existing pet
	if activePets[player.UserId] then
		activePets[player.UserId]:Destroy()
	end

	local pet = createGhostCatPet(player)
	activePets[player.UserId] = pet

	print("[GamePassManager] Ghost cat pet spawned for", player.Name)
end

local function removePet(player: Player)
	if activePets[player.UserId] then
		activePets[player.UserId]:Destroy()
		activePets[player.UserId] = nil
	end
end

-- ==========================================
-- PASS PURCHASE CALLBACK
-- ==========================================

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if not wasPurchased then
		return
	end

	-- Refresh cache for this player
	for passKey, id in Constants.GAME_PASS_IDS do
		if id == gamePassId then
			passCache[player.UserId] = passCache[player.UserId] or {}
			passCache[player.UserId][passKey] = true

			-- Apply effects immediately
			if passKey == "VIP" then
				applyVIPEffects(player)
			elseif passKey == "EXTRA_LIVES" then
				setupExtraLives(player)
			elseif passKey == "PET_COMPANION" then
				spawnPet(player)
			elseif passKey == "RADIO" then
				-- Radio is handled client-side; just notify
				Remotes[Constants.EVENT_GAME_PASS_OWNED]:FireClient(player, "RADIO", true)
			end

			-- Notify client
			Remotes[Constants.EVENT_GAME_PASS_OWNED]:FireClient(player, passKey, true)
			print("[GamePassManager]", player.Name, "purchased", passKey)
			break
		end
	end
end)

-- ==========================================
-- CLIENT REQUESTS
-- ==========================================

-- Client requests to purchase a pass
Remotes[Constants.EVENT_PROMPT_GAME_PASS].OnServerEvent:Connect(function(player, passKey)
	if type(passKey) ~= "string" then
		return
	end

	local passId = Constants.GAME_PASS_IDS[passKey]
	if not passId or passId == 0 then
		warn("[GamePassManager] Invalid or unconfigured pass key:", passKey)
		return
	end

	-- Check if already owned
	if ownsPass(player, passKey) then
		Remotes[Constants.EVENT_GAME_PASS_OWNED]:FireClient(player, passKey, true)
		return
	end

	-- Prompt the purchase
	local success, err = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, passId)
	end)

	if not success then
		warn("[GamePassManager] Failed to prompt purchase:", err)
	end
end)

-- Client queries pass status
;(getPassStatusFunc :: RemoteFunction).OnServerInvoke = function(player: Player, passKey: string)
	if type(passKey) ~= "string" then
		return false
	end
	return ownsPass(player, passKey)
end

-- ==========================================
-- PLAYER LIFECYCLE
-- ==========================================

local function onPlayerAdded(player: Player)
	-- Cache all pass ownership
	task.spawn(function()
		cacheAllPasses(player)

		-- Apply persistent effects
		applyVIPEffects(player)
		setupExtraLives(player)

		-- Spawn pet when character loads
		player.CharacterAdded:Connect(function()
			task.wait(1) -- Wait for character to fully load
			spawnPet(player)
		end)

		-- Spawn pet for current character if exists
		if player.Character then
			task.spawn(function()
				task.wait(1)
				spawnPet(player)
			end)
		end

		-- Notify client of all owned passes
		for passKey, owned in passCache[player.UserId] or {} do
			if owned then
				Remotes[Constants.EVENT_GAME_PASS_OWNED]:FireClient(player, passKey, true)
			end
		end
	end)
end

local function onPlayerRemoving(player: Player)
	passCache[player.UserId] = nil
	extraLivesRemaining[player.UserId] = nil
	removePet(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players already in game (Studio testing)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- ==========================================
-- PET UPDATE LOOP
-- ==========================================

RunService.Heartbeat:Connect(function()
	for userId, pet in activePets do
		local player = Players:GetPlayerByUserId(userId)
		if player and pet.Parent then
			updatePetPosition(player, pet)
			updatePetWarning(player, pet)
		elseif not player then
			-- Player left, clean up
			pet:Destroy()
			activePets[userId] = nil
		end
	end
end)

-- ==========================================
-- BINDABLE FOR OTHER SERVER SCRIPTS
-- ==========================================

-- Expose pass check for other server scripts
local checkPassFunc = Instance.new("BindableFunction")
checkPassFunc.Name = "CheckGamePass"
checkPassFunc.OnInvoke = function(userId: number, passKey: string): boolean
	local cached = passCache[userId]
	if cached then
		return cached[passKey] == true
	end
	return false
end
checkPassFunc.Parent = game:GetService("ServerStorage")

-- Expose extra lives reset for GameManager
local resetLivesEvent = Instance.new("BindableEvent")
resetLivesEvent.Name = "ResetExtraLives"
resetLivesEvent.Event:Connect(function(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		resetExtraLives(player)
	end
end)
resetLivesEvent.Parent = game:GetService("ServerStorage")

print("[GamePassManager] Game pass system initialized")
print("[GamePassManager] NOTE: Set real Game Pass IDs in Constants.lua before publishing!")

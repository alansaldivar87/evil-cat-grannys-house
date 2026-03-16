--[[
	BossFight - Final boss encounter
	Handles: boss spawning, phase transitions, weapon pickups, victory condition
	The boss is a larger, tougher version of the evil cat with two phases
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local GameState = require(Shared:WaitForChild("GameState"))
local Utils = require(Shared:WaitForChild("Utils"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local bossActive = false
local bossModel: Model? = nil
local bossHumanoid: Humanoid? = nil
local bossPhase = GameState.BossPhases.NORMAL
local lastSummonTime = 0

-- ==================
-- WEAPON SYSTEM
-- ==================

local function createWeaponTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "CatRepellent"
	tool.ToolTip = "Click to zap the evil cats!"
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	-- Create a simple handle (glowing orb)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 3)
	handle.BrickColor = BrickColor.new("Bright yellow")
	handle.Material = Enum.Material.Neon
	handle.Parent = tool

	-- Add a point light for glow effect
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 255, 0)
	light.Brightness = 2
	light.Range = 8
	light.Parent = handle

	return tool
end

local function setupWeaponPickup(pickup: BasePart)
	if not pickup:GetAttribute("Configured") then
		pickup.Material = Enum.Material.Neon
		pickup.BrickColor = BrickColor.new("Bright yellow")
		pickup.Shape = Enum.PartType.Ball
		pickup.Size = Vector3.new(2, 2, 2)
		pickup.CanCollide = false
		pickup.Anchored = true
		pickup:SetAttribute("Configured", true)

		-- Add a gentle bob animation
		local originalY = pickup.Position.Y
		task.spawn(function()
			while pickup.Parent do
				for i = 0, math.pi * 2, 0.05 do
					if not pickup.Parent then
						break
					end
					pickup.Position = Vector3.new(
						pickup.Position.X,
						originalY + math.sin(i) * 1.5,
						pickup.Position.Z
					)
					task.wait(0.03)
				end
			end
		end)
	end

	pickup.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		-- Check if player already has a weapon
		local backpack = player:FindFirstChild("Backpack")
		if backpack and backpack:FindFirstChild("CatRepellent") then
			return
		end
		if character:FindFirstChild("CatRepellent") then
			return
		end

		-- Give weapon
		local weapon = createWeaponTool()
		weapon.Parent = backpack

		-- Remove the pickup
		pickup:Destroy()

		print("[BossFight]", player.Name, "picked up CatRepellent!")
	end)
end

-- ==================
-- WEAPON ATTACK HANDLER
-- ==================

local function onWeaponAttack(player: Player)
	local character = player.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	-- Check if player has the weapon equipped
	if not character:FindFirstChild("CatRepellent") then
		return
	end

	-- Raycast from player's position in look direction
	local lookDirection = rootPart.CFrame.LookVector
	local rayOrigin = rootPart.Position
	local rayDirection = lookDirection * Constants.WEAPON_RANGE

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	if not result then
		return
	end

	-- Check if we hit a cat
	local hitPart = result.Instance
	local hitModel = hitPart:FindFirstAncestorOfClass("Model")
	if not hitModel then
		return
	end

	local hitHumanoid = hitModel:FindFirstChildOfClass("Humanoid")
	if not hitHumanoid then
		return
	end

	-- Check if it's tagged as a cat
	if CollectionService:HasTag(hitModel, Constants.TAG_EVIL_CAT) or CollectionService:HasTag(hitModel, Constants.TAG_BOSS_CAT) then
		hitHumanoid:TakeDamage(Constants.WEAPON_DAMAGE)
		print("[BossFight]", player.Name, "hit", hitModel.Name, "for", Constants.WEAPON_DAMAGE, "damage! HP:", hitHumanoid.Health)

		-- Update boss health bar for all clients
		if CollectionService:HasTag(hitModel, Constants.TAG_BOSS_CAT) and bossHumanoid then
			Remotes[Constants.EVENT_BOSS_HEALTH_UPDATE]:FireAllClients(
				bossHumanoid.Health,
				bossHumanoid.MaxHealth
			)
		end
	end
end

-- ==================
-- BOSS SPAWNING
-- ==================

local function spawnBoss(arenaCenter: Vector3)
	if bossActive then
		return
	end
	bossActive = true

	-- Look for BossCat template in ServerStorage
	local bossTemplate = ServerStorage:FindFirstChild("BossCat")
	if not bossTemplate then
		-- Create a fallback boss from EvilCat (scaled up)
		local catTemplate = ServerStorage:FindFirstChild("EvilCat")
		if not catTemplate then
			warn("[BossFight] No BossCat or EvilCat model found in ServerStorage!")
			return
		end
		bossTemplate = catTemplate:Clone()
		bossTemplate.Name = "BossCat"
		-- Scale up the boss
		if bossTemplate:IsA("Model") and bossTemplate.PrimaryPart then
			bossTemplate:ScaleTo(2.5)
		end
	end

	bossModel = bossTemplate:Clone()
	if bossModel.PrimaryPart then
		bossModel:PivotTo(CFrame.new(arenaCenter + Vector3.new(0, 5, 0)))
	end

	-- Set boss stats
	bossHumanoid = bossModel:FindFirstChildOfClass("Humanoid")
	if bossHumanoid then
		bossHumanoid.MaxHealth = Constants.BOSS_CAT_HEALTH
		bossHumanoid.Health = Constants.BOSS_CAT_HEALTH
		bossHumanoid.WalkSpeed = Constants.BOSS_CAT_CHASE_SPEED

		-- Listen for boss death
		bossHumanoid.Died:Connect(function()
			onBossDefeated()
		end)

		-- Listen for health changes (phase transitions)
		bossHumanoid.HealthChanged:Connect(function(newHealth)
			local healthPercent = newHealth / bossHumanoid.MaxHealth

			-- Phase 2: Enraged
			if healthPercent <= Constants.BOSS_CAT_ENRAGE_THRESHOLD and bossPhase == GameState.BossPhases.NORMAL then
				bossPhase = GameState.BossPhases.ENRAGED
				bossHumanoid.WalkSpeed = Constants.BOSS_CAT_ENRAGED_SPEED
				print("[BossFight] Boss ENRAGED!")

				-- Camera shake for all players
				for _, player in Players:GetPlayers() do
					Remotes[Constants.EVENT_CAMERA_SHAKE]:FireClient(player, 1.0, 10)
				end
			end

			-- Update all clients with boss health
			Remotes[Constants.EVENT_BOSS_HEALTH_UPDATE]:FireAllClients(newHealth, bossHumanoid.MaxHealth)
		end)
	end

	bossModel.Parent = workspace
	CollectionService:AddTag(bossModel, Constants.TAG_BOSS_CAT)
	CollectionService:AddTag(bossModel, Constants.TAG_EVIL_CAT) -- So CatAI controls it too

	-- Notify clients
	Remotes[Constants.EVENT_BOSS_FIGHT_START]:FireAllClients()

	-- Update game state
	local setStateEvent = ServerStorage:FindFirstChild("SetGameState")
	if setStateEvent then
		setStateEvent:Fire(GameState.States.BOSS_FIGHT)
	end

	print("[BossFight] BOSS SPAWNED! Health:", Constants.BOSS_CAT_HEALTH)
end

function onBossDefeated()
	print("[BossFight] BOSS DEFEATED! VICTORY!")
	bossActive = false

	-- Remove all remaining evil cats
	for _, cat in CollectionService:GetTagged(Constants.TAG_EVIL_CAT) do
		if cat:IsA("Model") then
			local h = cat:FindFirstChildOfClass("Humanoid")
			if h then
				h.Health = 0
			end
			task.delay(2, function()
				cat:Destroy()
			end)
		end
	end

	-- Notify all clients of victory and trigger celebration effects
	Remotes[Constants.EVENT_BOSS_DEFEATED]:FireAllClients()
	Remotes[Constants.EVENT_VICTORY_CELEBRATION]:FireAllClients()

	-- Set game state to victory
	local setStateEvent = ServerStorage:FindFirstChild("SetGameState")
	if setStateEvent then
		setStateEvent:Fire(GameState.States.VICTORY)
	end
end

-- ==================
-- BOSS SUMMON MINIONS
-- ==================

local function bossSummonMinions(arenaCenter: Vector3)
	if not bossActive or not bossModel then
		return
	end

	local catTemplate = ServerStorage:FindFirstChild("EvilCat")
	if not catTemplate then
		return
	end

	for i = 1, Constants.BOSS_SUMMON_COUNT do
		local minion = catTemplate:Clone()
		local offset = Vector3.new(math.random(-15, 15), 3, math.random(-15, 15))
		if minion.PrimaryPart then
			minion:PivotTo(CFrame.new(arenaCenter + offset))
		end
		minion.Name = "MinionCat_" .. i
		minion.Parent = workspace
		CollectionService:AddTag(minion, Constants.TAG_EVIL_CAT)
	end

	print("[BossFight] Boss summoned", Constants.BOSS_SUMMON_COUNT, "minion cats!")
end

-- ==================
-- BOSS ARENA TRIGGER
-- ==================

local function setupBossArena(arena: BasePart)
	arena.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		spawnBoss(arena.Position)
	end)
end

-- ==================
-- INITIALIZATION
-- ==================

-- Set up boss arena triggers
for _, arena in CollectionService:GetTagged(Constants.TAG_BOSS_ARENA) do
	if arena:IsA("BasePart") then
		setupBossArena(arena)
	end
end

CollectionService:GetInstanceAddedSignal(Constants.TAG_BOSS_ARENA):Connect(function(inst)
	if inst:IsA("BasePart") then
		setupBossArena(inst)
	end
end)

-- Set up weapon pickups
for _, pickup in CollectionService:GetTagged(Constants.TAG_WEAPON_PICKUP) do
	if pickup:IsA("BasePart") then
		setupWeaponPickup(pickup)
	end
end

CollectionService:GetInstanceAddedSignal(Constants.TAG_WEAPON_PICKUP):Connect(function(inst)
	if inst:IsA("BasePart") then
		setupWeaponPickup(inst)
	end
end)

-- Listen for weapon attacks from clients
Remotes[Constants.EVENT_WEAPON_ATTACK].OnServerEvent:Connect(onWeaponAttack)

-- Periodic boss summon check
task.spawn(function()
	while true do
		task.wait(1)
		if bossActive and bossModel and bossHumanoid and bossHumanoid.Health > 0 then
			local now = tick()
			if now - lastSummonTime >= Constants.BOSS_SUMMON_INTERVAL then
				lastSummonTime = now
				local arenaList = CollectionService:GetTagged(Constants.TAG_BOSS_ARENA)
				if #arenaList > 0 then
					bossSummonMinions(arenaList[1].Position)
				end
			end
		end
	end
end)

print("[BossFight] Boss fight system initialized")

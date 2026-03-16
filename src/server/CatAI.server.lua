--[[
	CatAI - Evil cat NPC artificial intelligence
	Handles: patrol, detection, chase, attack behaviors using a state machine
	Uses PathfindingService for navigation
]]

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local GameState = require(Shared:WaitForChild("GameState"))
local Utils = require(Shared:WaitForChild("Utils"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Cat data structure
type CatData = {
	model: Model,
	humanoid: Humanoid,
	rootPart: BasePart,
	state: string,
	targetPlayer: Player?,
	patrolPoints: { BasePart },
	currentPatrolIndex: number,
	lastAttackTime: number,
	territory: { BasePart }?, -- If set, cat won't chase beyond territory
}

local activeCats: { CatData } = {}
local AI_TICK_RATE = 0.3 -- Seconds between AI updates

-- Create pathfinding parameters
local pathParams = {
	AgentRadius = Constants.PATHFIND_AGENT_RADIUS,
	AgentHeight = Constants.PATHFIND_AGENT_HEIGHT,
	AgentCanJump = false,
	AgentCanClimb = false,
}

local function getPatrolPoints(): { BasePart }
	return CollectionService:GetTagged(Constants.TAG_PATROL_POINT)
end

local function navigateTo(catData: CatData, targetPosition: Vector3): boolean
	local path = PathfindingService:CreatePath(pathParams)

	local success, err = pcall(function()
		path:ComputeAsync(catData.rootPart.Position, targetPosition)
	end)

	if not success then
		warn("[CatAI] Pathfinding error:", err)
		return false
	end

	if path.Status ~= Enum.PathStatus.Success then
		-- Fallback: direct move
		catData.humanoid:MoveTo(targetPosition)
		return true
	end

	local waypoints = path:GetWaypoints()
	for i = 2, #waypoints do -- Skip first waypoint (current position)
		local waypoint = waypoints[i]
		catData.humanoid:MoveTo(waypoint.Position)

		-- Wait for move or timeout
		local moveFinished = catData.humanoid.MoveToFinished:Wait()
		if not moveFinished then
			return false
		end

		-- Re-check state during navigation (allows interruption)
		if catData.state ~= GameState.CatStates.PATROL then
			return true -- State changed, stop patrolling path
		end
	end

	return true
end

local function patrol(catData: CatData)
	if #catData.patrolPoints == 0 then
		return
	end

	catData.humanoid.WalkSpeed = Constants.CAT_WALK_SPEED

	-- Move to next patrol point
	local targetPoint = catData.patrolPoints[catData.currentPatrolIndex]
	if targetPoint then
		catData.humanoid:MoveTo(targetPoint.Position)
	end

	-- Advance patrol index
	catData.currentPatrolIndex = catData.currentPatrolIndex + 1
	if catData.currentPatrolIndex > #catData.patrolPoints then
		catData.currentPatrolIndex = 1
	end
end

local function checkForPlayers(catData: CatData): (Player?, number)
	local catPos = catData.rootPart.Position

	-- Custom search that skips hidden players
	local nearestPlayer: Player? = nil
	local nearestDistance = Constants.CAT_DETECTION_RANGE

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			-- Skip hidden players (from GameplayEnhancements hiding system)
			if character:GetAttribute("IsHidden") then
				continue
			end

			local charPos = Utils.getCharacterPosition(character)
			if charPos and Utils.isAlive(character) then
				local distance = Utils.getDistance(catPos, charPos)
				if distance < nearestDistance then
					nearestDistance = distance
					nearestPlayer = player
				end
			end
		end
	end

	return nearestPlayer, nearestDistance
end

local function isInTerritory(catData: CatData, position: Vector3): boolean
	-- If no territory defined, cat can go anywhere
	if not catData.territory or #catData.territory == 0 then
		return true
	end

	-- Check if position is within range of any territory point
	for _, point in catData.territory do
		if Utils.getDistance(position, point.Position) < 80 then
			return true
		end
	end
	return false
end

local function attackPlayer(catData: CatData, player: Player)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = Utils.getHumanoid(character)
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local now = tick()
	if now - catData.lastAttackTime < Constants.CAT_ATTACK_COOLDOWN then
		return
	end

	catData.lastAttackTime = now
	humanoid:TakeDamage(Constants.CAT_ATTACK_DAMAGE)

	-- Notify client for camera shake and blood vignette
	Remotes[Constants.EVENT_CAMERA_SHAKE]:FireClient(player, 0.3, 5)
	Remotes[Constants.EVENT_PLAYER_DAMAGED]:FireClient(player)

	print("[CatAI] Cat attacked", player.Name, "- Health:", humanoid.Health)
end

local function updateCat(catData: CatData)
	-- Safety check
	if not catData.model.Parent or not catData.rootPart or not catData.humanoid or catData.humanoid.Health <= 0 then
		return
	end

	local catPos = catData.rootPart.Position

	-- If cat is slowed by a door or flashlight, don't override the speed reduction
	local isExternallySlowed = catData.model:GetAttribute("DoorSlowed") or catData.model:GetAttribute("FlashlightSlowed")

	if catData.state == GameState.CatStates.PATROL then
		-- Check for nearby players
		local nearestPlayer, distance = checkForPlayers(catData)
		if nearestPlayer then
			-- Transition to WARNING state
			catData.targetPlayer = nearestPlayer
			catData.state = GameState.CatStates.WARNING
			catData.humanoid:MoveTo(catData.rootPart.Position) -- Stop moving

			-- Notify the detected player (for hiss sound)
			Remotes[Constants.EVENT_CAT_WARNING]:FireClient(nearestPlayer, catPos)

			print("[CatAI] Cat detected", nearestPlayer.Name, "! Hissing...")

			-- Brief warning pause then chase
			task.delay(Constants.CAT_WARNING_DURATION, function()
				if catData.state == GameState.CatStates.WARNING then
					catData.state = GameState.CatStates.CHASE
					print("[CatAI] Cat chasing", nearestPlayer.Name)
				end
			end)
		else
			patrol(catData)
		end

	elseif catData.state == GameState.CatStates.WARNING then
		-- Waiting for warning to finish, do nothing
		-- (The delay in PATROL->WARNING handles transition)

	elseif catData.state == GameState.CatStates.CHASE then
		local target = catData.targetPlayer
		if not target or not target.Character then
			catData.state = GameState.CatStates.PATROL
			catData.targetPlayer = nil
			return
		end

		-- If target hid, lose interest
		if target.Character:GetAttribute("IsHidden") then
			catData.state = GameState.CatStates.PATROL
			catData.targetPlayer = nil
			if not isExternallySlowed then
				catData.humanoid.WalkSpeed = Constants.CAT_WALK_SPEED
			end
			print("[CatAI] Target hid! Cat lost interest, returning to patrol")
			return
		end

		local targetPos = Utils.getCharacterPosition(target.Character)
		if not targetPos or not Utils.isAlive(target.Character) then
			catData.state = GameState.CatStates.PATROL
			catData.targetPlayer = nil
			return
		end

		local distance = Utils.getDistance(catPos, targetPos)

		-- Check if target is out of range or outside territory
		if distance > Constants.CAT_LOSE_INTEREST_RANGE or not isInTerritory(catData, targetPos) then
			catData.state = GameState.CatStates.PATROL
			catData.targetPlayer = nil
			if not isExternallySlowed then
				catData.humanoid.WalkSpeed = Constants.CAT_WALK_SPEED
			end
			print("[CatAI] Cat lost interest, returning to patrol")
			return
		end

		-- Close enough to attack?
		if distance <= Constants.CAT_ATTACK_RANGE then
			catData.state = GameState.CatStates.ATTACK
			return
		end

		-- Chase!
		if not isExternallySlowed then
			catData.humanoid.WalkSpeed = Constants.CAT_CHASE_SPEED
		end
		catData.humanoid:MoveTo(targetPos)

	elseif catData.state == GameState.CatStates.ATTACK then
		local target = catData.targetPlayer
		if not target or not target.Character or not Utils.isAlive(target.Character) then
			catData.state = GameState.CatStates.PATROL
			catData.targetPlayer = nil
			catData.humanoid.WalkSpeed = Constants.CAT_WALK_SPEED
			return
		end

		local targetPos = Utils.getCharacterPosition(target.Character)
		if not targetPos then
			catData.state = GameState.CatStates.PATROL
			catData.targetPlayer = nil
			return
		end

		local distance = Utils.getDistance(catPos, targetPos)

		if distance > Constants.CAT_ATTACK_RANGE then
			-- Target moved away, chase again
			catData.state = GameState.CatStates.CHASE
			return
		end

		-- Attack!
		attackPlayer(catData, target)
		catData.humanoid:MoveTo(targetPos) -- Keep moving toward target
	end
end

local function registerCat(catModel: Model)
	local humanoid = catModel:FindFirstChildOfClass("Humanoid")
	local rootPart = catModel.PrimaryPart or catModel:FindFirstChild("HumanoidRootPart")

	if not humanoid or not rootPart then
		warn("[CatAI] Cat model missing Humanoid or PrimaryPart:", catModel.Name)
		return
	end

	-- Find patrol points - use territory attribute if set
	local allPatrolPoints = getPatrolPoints()
	local territoryName = catModel:GetAttribute("Territory")
	local catPatrolPoints = {}
	local territoryPoints = {}

	if territoryName then
		for _, point in allPatrolPoints do
			if point:GetAttribute("Territory") == territoryName then
				table.insert(catPatrolPoints, point)
				table.insert(territoryPoints, point)
			end
		end
	end

	-- Fallback to all patrol points if no territory match
	if #catPatrolPoints == 0 then
		catPatrolPoints = allPatrolPoints
	end

	local catData: CatData = {
		model = catModel,
		humanoid = humanoid,
		rootPart = rootPart,
		state = GameState.CatStates.PATROL,
		targetPlayer = nil,
		patrolPoints = Utils.shuffleTable(catPatrolPoints),
		currentPatrolIndex = 1,
		lastAttackTime = 0,
		territory = #territoryPoints > 0 and territoryPoints or nil,
	}

	table.insert(activeCats, catData)
	print("[CatAI] Registered cat:", catModel.Name, "with", #catPatrolPoints, "patrol points")
end

-- Listen for cats being added (from GameManager or BossFight)
CollectionService:GetInstanceAddedSignal(Constants.TAG_EVIL_CAT):Connect(function(instance)
	if instance:IsA("Model") then
		registerCat(instance)
	end
end)

-- Register any cats already tagged
for _, cat in CollectionService:GetTagged(Constants.TAG_EVIL_CAT) do
	if cat:IsA("Model") then
		registerCat(cat)
	end
end

-- Clean up destroyed cats
CollectionService:GetInstanceRemovedSignal(Constants.TAG_EVIL_CAT):Connect(function(instance)
	for i, catData in activeCats do
		if catData.model == instance then
			table.remove(activeCats, i)
			print("[CatAI] Cat removed:", instance.Name)
			break
		end
	end
end)

-- Main AI loop
local timeSinceLastTick = 0
RunService.Heartbeat:Connect(function(dt)
	timeSinceLastTick = timeSinceLastTick + dt
	if timeSinceLastTick < AI_TICK_RATE then
		return
	end
	timeSinceLastTick = 0

	for _, catData in activeCats do
		task.spawn(updateCat, catData)
	end
end)

print("[CatAI] Cat AI system initialized")

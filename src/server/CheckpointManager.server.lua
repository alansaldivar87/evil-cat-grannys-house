--[[
	CheckpointManager - Handles checkpoint tracking and player respawn locations
	Checkpoints are Parts tagged "Checkpoint" with an "Order" IntValue attribute
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Track which checkpoint each player has reached (by order number)
local playerProgress: { [number]: number } = {} -- userId -> highest checkpoint order

local function getCheckpointOrder(checkpoint: BasePart): number
	return checkpoint:GetAttribute("Order") or 0
end

local function onCheckpointTouched(checkpoint: BasePart, hit: BasePart)
	-- Check if a player character touched it
	local character = hit.Parent
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local player = game:GetService("Players"):GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local checkpointOrder = getCheckpointOrder(checkpoint)
	local currentProgress = playerProgress[player.UserId] or 0

	-- Only update if this is a new (higher) checkpoint
	if checkpointOrder > currentProgress then
		playerProgress[player.UserId] = checkpointOrder

		-- Tell GameManager about the new checkpoint
		local setCheckpoint = ServerStorage:FindFirstChild("SetPlayerCheckpoint")
		if setCheckpoint then
			setCheckpoint:Invoke(player.UserId, checkpoint)
		end

		-- Notify the player's client
		local totalCheckpoints = #CollectionService:GetTagged(Constants.TAG_CHECKPOINT)
		Remotes[Constants.EVENT_CHECKPOINT_REACHED]:FireClient(
			player,
			checkpointOrder,
			totalCheckpoints
		)

		print("[Checkpoints] " .. player.Name .. " reached checkpoint " .. checkpointOrder .. "/" .. totalCheckpoints)
	end
end

local function setupCheckpoint(checkpoint: BasePart)
	-- Make checkpoint semi-transparent and glowing
	if not checkpoint:GetAttribute("Configured") then
		checkpoint.Transparency = 0.7
		checkpoint.Material = Enum.Material.Neon
		checkpoint.BrickColor = BrickColor.new("Lime green")
		checkpoint.CanCollide = false
		checkpoint.Anchored = true
		checkpoint:SetAttribute("Configured", true)
	end

	-- Connect touch event
	checkpoint.Touched:Connect(function(hit)
		onCheckpointTouched(checkpoint, hit)
	end)
end

-- Set up existing checkpoints
for _, checkpoint in CollectionService:GetTagged(Constants.TAG_CHECKPOINT) do
	if checkpoint:IsA("BasePart") then
		setupCheckpoint(checkpoint)
	end
end

-- Listen for new checkpoints (in case they're added dynamically)
CollectionService:GetInstanceAddedSignal(Constants.TAG_CHECKPOINT):Connect(function(instance)
	if instance:IsA("BasePart") then
		setupCheckpoint(instance)
	end
end)

-- Clean up when player leaves
game:GetService("Players").PlayerRemoving:Connect(function(player)
	playerProgress[player.UserId] = nil
end)

print("[CheckpointManager] Initialized with", #CollectionService:GetTagged(Constants.TAG_CHECKPOINT), "checkpoints")

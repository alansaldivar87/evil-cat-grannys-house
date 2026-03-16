--[[
	GameplayEnhancements - Server-side gameplay systems
	Handles: Hiding system, Flashlight, Cat Treats collectibles, Door system with keys

	All systems use CollectionService tags for level-designer-friendly setup:
	  - "HidingSpot": Parts where players can hide (closets, beds, etc.)
	  - "CatTreat": Parts that are collectible cat treats
	  - "Door": Parts that can be opened/closed
	  - "LockedDoor": Parts that require a key to open
	  - "Key": Parts that are keys (with "KeyId" attribute matching door's "KeyId")
	  - "SecretPassage": Parts revealed when all treats in a room are collected
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Utils = require(Shared:WaitForChild("Utils"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- ==========================================
-- PLAYER DATA TRACKING
-- ==========================================

type PlayerData = {
	isHidden: boolean,
	hidingSpot: BasePart?,
	flashlightOn: boolean,
	flashlightBattery: number,
	treatsCollected: { [string]: boolean }, -- treatId -> true
	treatsPerRoom: { [string]: number }, -- roomName -> count collected
	keysCollected: { [string]: boolean }, -- keyId -> true
	extraLives: number,
}

local playerData: { [number]: PlayerData } = {}

local function getPlayerData(player: Player): PlayerData
	if not playerData[player.UserId] then
		playerData[player.UserId] = {
			isHidden = false,
			hidingSpot = nil,
			flashlightOn = false,
			flashlightBattery = Constants.FLASHLIGHT_MAX_BATTERY,
			treatsCollected = {},
			treatsPerRoom = {},
			keysCollected = {},
			extraLives = 0,
		}
	end
	return playerData[player.UserId]
end

-- ==========================================
-- HIDING SYSTEM
-- ==========================================

-- Store which hiding spots are occupied
local occupiedSpots: { [BasePart]: Player } = {}

local function setupHidingSpot(spot: BasePart)
	if spot:GetAttribute("Configured") then
		return
	end
	spot:SetAttribute("Configured", true)

	-- Create proximity prompt for hiding
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Constants.HIDE_PROMPT_TEXT
	prompt.ObjectText = "Hiding Spot"
	prompt.MaxActivationDistance = Constants.HIDE_PROMPT_DISTANCE
	prompt.HoldDuration = 0.3
	prompt.RequiresLineOfSight = false
	prompt.Parent = spot

	prompt.Triggered:Connect(function(player)
		local data = getPlayerData(player)
		local character = player.Character
		if not character then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		if data.isHidden then
			-- EXIT hiding spot
			data.isHidden = false
			data.hidingSpot = nil
			occupiedSpots[spot] = nil

			-- Restore character visibility
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") then
					part.Transparency = part:GetAttribute("OriginalTransparency") or 0
				end
			end

			-- Re-enable movement
			humanoid.WalkSpeed = 16
			humanoid.JumpPower = 50

			-- Teleport player slightly away from hiding spot
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				rootPart.CFrame = spot.CFrame + spot.CFrame.LookVector * 3 + Vector3.new(0, 2, 0)
			end

			prompt.ActionText = Constants.HIDE_PROMPT_TEXT

			-- Notify client
			Remotes[Constants.EVENT_HIDE_STATE_CHANGED]:FireClient(player, false)
			-- Notify all clients that this player is no longer hidden (for cat AI)
			Remotes[Constants.EVENT_PLAYER_HIDDEN]:FireAllClients(player.UserId, false)

			print("[Hiding]", player.Name, "left hiding spot")
		else
			-- CHECK if spot is occupied
			if occupiedSpots[spot] then
				return
			end

			-- ENTER hiding spot
			data.isHidden = true
			data.hidingSpot = spot
			occupiedSpots[spot] = player

			-- Teleport player into hiding spot
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				rootPart.CFrame = spot.CFrame
			end

			-- Make character invisible
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") then
					part:SetAttribute("OriginalTransparency", part.Transparency)
					part.Transparency = 1
				end
			end

			-- Freeze movement
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0

			prompt.ActionText = Constants.HIDE_PROMPT_TEXT_EXIT

			-- Notify client
			Remotes[Constants.EVENT_HIDE_STATE_CHANGED]:FireClient(player, true)
			-- Notify all clients that this player is hidden (for cat AI)
			Remotes[Constants.EVENT_PLAYER_HIDDEN]:FireAllClients(player.UserId, true)

			print("[Hiding]", player.Name, "is now hiding!")
		end
	end)
end

-- ==========================================
-- FLASHLIGHT SYSTEM
-- ==========================================

-- Track flashlight states for cat AI interaction
local flashlightPlayers: { [number]: boolean } = {} -- userId -> isOn

local function createFlashlightTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Flashlight"
	tool.ToolTip = "Press to toggle flashlight. Cats are slower in the light!"
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	-- Create handle (looks like a flashlight)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.6, 0.6, 2.5)
	handle.BrickColor = BrickColor.new("Medium stone grey")
	handle.Material = Enum.Material.Metal
	handle.Parent = tool

	-- Spotlight (the actual flashlight beam)
	local spotlight = Instance.new("SpotLight")
	spotlight.Name = "FlashlightBeam"
	spotlight.Brightness = 0 -- Off by default
	spotlight.Range = Constants.FLASHLIGHT_RANGE
	spotlight.Angle = Constants.FLASHLIGHT_ANGLE
	spotlight.Color = Color3.fromRGB(255, 255, 230)
	spotlight.Face = Enum.NormalId.Front
	spotlight.Enabled = false
	spotlight.Parent = handle

	-- Small indicator light on the handle
	local indicator = Instance.new("PointLight")
	indicator.Name = "Indicator"
	indicator.Brightness = 0.3
	indicator.Range = 3
	indicator.Color = Color3.fromRGB(50, 50, 50)
	indicator.Parent = handle

	return tool
end

local function giveFlashlight(player: Player)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return
	end

	-- Don't give if they already have one
	if backpack:FindFirstChild("Flashlight") then
		return
	end
	local character = player.Character
	if character and character:FindFirstChild("Flashlight") then
		return
	end

	local flashlight = createFlashlightTool()
	flashlight.Parent = backpack
end

-- Handle flashlight toggle from client
Remotes[Constants.EVENT_FLASHLIGHT_TOGGLE].OnServerEvent:Connect(function(player: Player)
	local data = getPlayerData(player)
	local character = player.Character
	if not character then
		return
	end

	-- Find flashlight tool (check both character and backpack)
	local flashlight = character:FindFirstChild("Flashlight")
	if not flashlight then
		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			flashlight = backpack:FindFirstChild("Flashlight")
			if flashlight then
				-- Auto-equip: move from backpack to character
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid:EquipTool(flashlight)
				end
			end
		end
	end
	if not flashlight then
		return
	end

	local handle = flashlight:FindFirstChild("Handle")
	if not handle then
		return
	end

	local spotlight = handle:FindFirstChild("FlashlightBeam")
	local indicator = handle:FindFirstChild("Indicator")
	if not spotlight then
		return
	end

	if data.flashlightOn then
		-- Turn OFF
		data.flashlightOn = false
		flashlightPlayers[player.UserId] = false
		spotlight.Enabled = false
		spotlight.Brightness = 0
		if indicator then
			indicator.Color = Color3.fromRGB(50, 50, 50)
		end
	else
		-- Turn ON (only if battery > 0)
		if data.flashlightBattery <= 0 then
			return
		end
		data.flashlightOn = true
		flashlightPlayers[player.UserId] = true
		spotlight.Enabled = true
		spotlight.Brightness = Constants.FLASHLIGHT_BRIGHTNESS
		if indicator then
			indicator.Color = Color3.fromRGB(100, 255, 100)
		end
	end
end)

-- Battery drain/recharge loop
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			local data = getPlayerData(player)

			if data.flashlightOn then
				-- Drain battery
				data.flashlightBattery = math.max(0, data.flashlightBattery - Constants.FLASHLIGHT_DRAIN_RATE)

				-- Auto-off when battery dies
				if data.flashlightBattery <= 0 then
					data.flashlightOn = false
					flashlightPlayers[player.UserId] = false

					local character = player.Character
					if character then
						local flashlight = character:FindFirstChild("Flashlight")
						if flashlight then
							local handle = flashlight:FindFirstChild("Handle")
							if handle then
								local spotlight = handle:FindFirstChild("FlashlightBeam")
								if spotlight then
									spotlight.Enabled = false
									spotlight.Brightness = 0
								end
								local indicator = handle:FindFirstChild("Indicator")
								if indicator then
									indicator.Color = Color3.fromRGB(200, 50, 50) -- Red = dead
								end
							end
						end
					end
				end
			else
				-- Recharge battery when off
				data.flashlightBattery = math.min(Constants.FLASHLIGHT_MAX_BATTERY, data.flashlightBattery + Constants.FLASHLIGHT_RECHARGE_RATE)
			end

			-- Send battery update to client
			Remotes[Constants.EVENT_FLASHLIGHT_BATTERY]:FireClient(player, data.flashlightBattery, Constants.FLASHLIGHT_MAX_BATTERY)
		end
	end
end)

-- Flashlight effect on cats: slow down cats within flashlight beam
-- This integrates with the existing CatAI system
task.spawn(function()
	while true do
		task.wait(0.5)

		local cats = CollectionService:GetTagged(Constants.TAG_EVIL_CAT)

		for _, player in Players:GetPlayers() do
			local data = getPlayerData(player)
			if not data.flashlightOn then
				continue
			end

			local character = player.Character
			if not character then
				continue
			end

			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if not rootPart then
				continue
			end

			local playerPos = rootPart.Position
			local lookDir = rootPart.CFrame.LookVector

			for _, cat in cats do
				if not cat:IsA("Model") then
					continue
				end

				local catRoot = cat.PrimaryPart or cat:FindFirstChild("HumanoidRootPart")
				if not catRoot then
					continue
				end

				local catHumanoid = cat:FindFirstChildOfClass("Humanoid")
				if not catHumanoid then
					continue
				end

				local toCat = (catRoot.Position - playerPos)
				local distance = toCat.Magnitude

				if distance > Constants.FLASHLIGHT_SLOW_RANGE then
					-- Restore speed if cat attribute was set
					if cat:GetAttribute("FlashlightSlowed") then
						cat:SetAttribute("FlashlightSlowed", false)
						-- Speed will be restored by CatAI naturally
					end
					continue
				end

				-- Check if cat is in the flashlight cone
				local dotProduct = lookDir.Unit:Dot(toCat.Unit)
				local angleThreshold = math.cos(math.rad(Constants.FLASHLIGHT_ANGLE / 2))

				if dotProduct > angleThreshold then
					-- Cat is in the beam! Slow it down
					if not cat:GetAttribute("FlashlightSlowed") then
						cat:SetAttribute("FlashlightSlowed", true)
						catHumanoid.WalkSpeed = catHumanoid.WalkSpeed * Constants.FLASHLIGHT_SLOW_FACTOR
					end
				else
					if cat:GetAttribute("FlashlightSlowed") then
						cat:SetAttribute("FlashlightSlowed", false)
						-- Let CatAI reset the speed naturally on next tick
					end
				end
			end
		end
	end
end)

-- ==========================================
-- COLLECTIBLES: CAT TREATS
-- ==========================================

-- Track total treats per room for bonus checks
local treatsPerRoom: { [string]: number } = {} -- roomName -> total count in room

local function countTreatsInRoom(roomName: string): number
	local count = 0
	for _, treat in CollectionService:GetTagged(Constants.TAG_CAT_TREAT) do
		if treat:IsA("BasePart") and treat:GetAttribute("Room") == roomName then
			count = count + 1
		end
	end
	return count
end

local function setupCatTreat(treatPart: BasePart)
	if treatPart:GetAttribute("Configured") then
		return
	end
	treatPart:SetAttribute("Configured", true)

	-- Generate a unique ID if not set
	local treatId = treatPart:GetAttribute("TreatId")
	if not treatId then
		treatId = treatPart:GetFullName() .. "_" .. tostring(math.random(100000, 999999))
		treatPart:SetAttribute("TreatId", treatId)
	end

	local roomName = treatPart:GetAttribute("Room") or "Unknown"

	-- Count treats in this room (cache)
	if not treatsPerRoom[roomName] then
		-- Defer counting to ensure all treats are loaded
		task.defer(function()
			treatsPerRoom[roomName] = countTreatsInRoom(roomName)
		end)
	end

	-- Style the treat
	treatPart.Material = Enum.Material.SmoothPlastic
	treatPart.BrickColor = BrickColor.new("Bright orange")
	treatPart.Shape = Enum.PartType.Cylinder
	treatPart.Size = Vector3.new(0.8, 1.2, 1.2)
	treatPart.CanCollide = false
	treatPart.Anchored = true

	-- Sparkle effect
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "TreatSparkle"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 200, 50))
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Lifetime = NumberRange.new(0.5, 1)
	sparkle.Rate = 5
	sparkle.Speed = NumberRange.new(1, 2)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = treatPart

	-- Bob animation
	local originalY = treatPart.Position.Y
	local phase = math.random() * math.pi * 2
	task.spawn(function()
		while treatPart.Parent do
			phase = phase + 0.05 * Constants.TREAT_BOB_SPEED
			treatPart.Position = Vector3.new(
				treatPart.Position.X,
				originalY + math.sin(phase) * Constants.TREAT_BOB_HEIGHT * 0.5,
				treatPart.Position.Z
			)
			-- Slow spin
			treatPart.CFrame = treatPart.CFrame * CFrame.Angles(0, math.rad(1), 0)
			task.wait(0.03)
		end
	end)

	-- Collect on touch
	treatPart.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		local data = getPlayerData(player)

		-- Already collected?
		if data.treatsCollected[treatId] then
			return
		end

		-- Collect it
		data.treatsCollected[treatId] = true

		-- Track room progress
		if not data.treatsPerRoom[roomName] then
			data.treatsPerRoom[roomName] = 0
		end
		data.treatsPerRoom[roomName] = data.treatsPerRoom[roomName] + 1

		-- Hide the treat (don't destroy, since other players may need it)
		treatPart.Transparency = 1
		treatPart.CanCollide = false
		local emitter = treatPart:FindFirstChild("TreatSparkle")
		if emitter then
			emitter.Enabled = false
		end

		-- Count total treats collected by this player
		local totalCollected = 0
		for _ in data.treatsCollected do
			totalCollected = totalCollected + 1
		end

		-- Notify client
		local roomTotal = treatsPerRoom[roomName] or Constants.TREATS_PER_ROOM_BONUS
		Remotes[Constants.EVENT_TREAT_COLLECTED]:FireClient(
			player,
			totalCollected,
			roomName,
			data.treatsPerRoom[roomName],
			roomTotal
		)

		print("[Treats]", player.Name, "collected treat in", roomName, "(" .. data.treatsPerRoom[roomName] .. "/" .. roomTotal .. ")")

		-- Check if all treats in this room are collected
		if data.treatsPerRoom[roomName] >= roomTotal and roomTotal > 0 then
			-- Room complete! Reveal secret passage
			Remotes[Constants.EVENT_ROOM_TREATS_COMPLETE]:FireClient(player, roomName)
			revealSecretPassage(roomName, player)
			print("[Treats]", player.Name, "completed all treats in", roomName, "! Secret passage revealed!")
		end
	end)
end

function revealSecretPassage(roomName: string, player: Player)
	for _, passage in CollectionService:GetTagged(Constants.TAG_SECRET_PASSAGE) do
		if passage:IsA("BasePart") and passage:GetAttribute("Room") == roomName then
			-- Animate the passage opening
			local targetTransparency = 0.8
			local targetCanCollide = false

			local tween = TweenService:Create(passage, TweenInfo.new(1, Enum.EasingStyle.Sine), {
				Transparency = targetTransparency,
			})
			tween:Play()
			passage.CanCollide = targetCanCollide

			-- Visual effect
			local glow = Instance.new("PointLight")
			glow.Color = Color3.fromRGB(255, 200, 50)
			glow.Brightness = 3
			glow.Range = 15
			glow.Parent = passage

			-- Fade glow after a moment
			task.delay(3, function()
				local glowFade = TweenService:Create(glow, TweenInfo.new(2), {
					Brightness = 0.5,
				})
				glowFade:Play()
			end)

			-- Camera shake for the discovering player
			Remotes[Constants.EVENT_CAMERA_SHAKE]:FireClient(player, 0.5, 3)
		end
	end
end

-- ==========================================
-- DOOR SYSTEM
-- ==========================================

-- Track door states: { [doorPart]: { isOpen: boolean } }
local doorStates: { [BasePart]: { isOpen: boolean, originalCFrame: CFrame } } = {}

local function setupDoor(doorPart: BasePart)
	if doorPart:GetAttribute("Configured") then
		return
	end
	doorPart:SetAttribute("Configured", true)

	local isLocked = CollectionService:HasTag(doorPart, Constants.TAG_LOCKED_DOOR)
	local keyId = doorPart:GetAttribute("KeyId")

	doorStates[doorPart] = {
		isOpen = false,
		originalCFrame = doorPart.CFrame,
	}

	-- Create proximity prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.MaxActivationDistance = Constants.DOOR_PROMPT_DISTANCE
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = doorPart

	if isLocked then
		prompt.ActionText = "Locked"
		prompt.ObjectText = "Requires Key"
		prompt.Enabled = true
	else
		prompt.ActionText = "Open Door"
		prompt.ObjectText = ""
	end

	prompt.Triggered:Connect(function(player)
		local data = getPlayerData(player)
		local state = doorStates[doorPart]
		if not state then
			return
		end

		-- Check if locked
		if isLocked and keyId then
			if not data.keysCollected[keyId] then
				-- Player doesn't have the key
				Remotes[Constants.EVENT_DOOR_TOGGLE]:FireClient(player, "locked", keyId)
				return
			end
		end

		if state.isOpen then
			-- CLOSE the door
			state.isOpen = false
			prompt.ActionText = "Open Door"

			doorPart.CanCollide = true
			local closeTween = TweenService:Create(doorPart, TweenInfo.new(Constants.DOOR_OPEN_SPEED, Enum.EasingStyle.Sine), {
				Transparency = 0,
			})
			closeTween:Play()

			-- Closing a door slows nearby cats temporarily
			task.spawn(function()
				local cats = CollectionService:GetTagged(Constants.TAG_EVIL_CAT)
				for _, cat in cats do
					if not cat:IsA("Model") then
						continue
					end
					local catRoot = cat.PrimaryPart or cat:FindFirstChild("HumanoidRootPart")
					if not catRoot then
						continue
					end
					local catHumanoid = cat:FindFirstChildOfClass("Humanoid")
					if not catHumanoid then
						continue
					end

					local dist = Utils.getDistance(doorPart.Position, catRoot.Position)
					if dist < 15 then
						-- Slow the cat
						local originalSpeed = catHumanoid.WalkSpeed
						catHumanoid.WalkSpeed = originalSpeed * Constants.DOOR_SLOW_FACTOR
						cat:SetAttribute("DoorSlowed", true)

						task.delay(Constants.DOOR_SLOW_CAT_DURATION, function()
							if cat.Parent and catHumanoid.Health > 0 then
								cat:SetAttribute("DoorSlowed", false)
								-- CatAI will handle restoring proper speed
							end
						end)
					end
				end
			end)

			Remotes[Constants.EVENT_DOOR_TOGGLE]:FireAllClients("closed", doorPart)
			print("[Door] Door closed by", player.Name)
		else
			-- OPEN the door
			state.isOpen = true
			prompt.ActionText = "Close Door"

			-- Make door passable and semi-transparent (reliable open)
			doorPart.CanCollide = false
			local openTween = TweenService:Create(doorPart, TweenInfo.new(Constants.DOOR_OPEN_SPEED, Enum.EasingStyle.Sine), {
				Transparency = 0.7,
			})
			openTween:Play()

			Remotes[Constants.EVENT_DOOR_TOGGLE]:FireAllClients("opened", doorPart)
			print("[Door] Door opened by", player.Name)
		end
	end)
end

-- ==========================================
-- KEY SYSTEM
-- ==========================================

local function setupKey(keyPart: BasePart)
	if keyPart:GetAttribute("Configured") then
		return
	end
	keyPart:SetAttribute("Configured", true)

	local keyId = keyPart:GetAttribute("KeyId")
	if not keyId then
		warn("[Keys] Key part missing KeyId attribute:", keyPart:GetFullName())
		return
	end

	-- Style the key
	keyPart.Material = Enum.Material.Neon
	keyPart.BrickColor = BrickColor.new("Bright yellow")
	keyPart.Size = Vector3.new(0.5, 1.5, 0.2)
	keyPart.CanCollide = false
	keyPart.Anchored = true

	-- Glow
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 215, 0)
	light.Brightness = 1
	light.Range = 8
	light.Parent = keyPart

	-- Bob animation
	local originalY = keyPart.Position.Y
	task.spawn(function()
		local phase = math.random() * math.pi * 2
		while keyPart.Parent do
			phase = phase + 0.04
			keyPart.Position = Vector3.new(
				keyPart.Position.X,
				originalY + math.sin(phase) * 0.6,
				keyPart.Position.Z
			)
			keyPart.CFrame = keyPart.CFrame * CFrame.Angles(0, math.rad(2), 0)
			task.wait(0.03)
		end
	end)

	-- Collect on touch
	keyPart.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		local data = getPlayerData(player)

		-- Already collected?
		if data.keysCollected[keyId] then
			return
		end

		-- Collect the key
		data.keysCollected[keyId] = true

		-- Hide the key for this player (don't destroy for others)
		keyPart.Transparency = 1
		keyPart.CanCollide = false
		local glow = keyPart:FindFirstChildOfClass("PointLight")
		if glow then
			glow.Enabled = false
		end

		-- Update any locked doors with this keyId to show "unlocked"
		for _, door in CollectionService:GetTagged(Constants.TAG_LOCKED_DOOR) do
			if door:GetAttribute("KeyId") == keyId then
				local doorPrompt = door:FindFirstChildOfClass("ProximityPrompt")
				if doorPrompt then
					doorPrompt.ActionText = "Open Door"
					doorPrompt.ObjectText = "Unlocked!"
				end
			end
		end

		-- Notify client
		Remotes[Constants.EVENT_KEY_COLLECTED]:FireClient(player, keyId)

		print("[Keys]", player.Name, "collected key:", keyId)
	end)
end

-- ==========================================
-- CAT AI INTEGRATION: Hidden players are undetectable
-- ==========================================

-- Override the findNearestPlayer to exclude hidden players
-- We do this by storing hidden state as a player attribute the CatAI can check
local function updatePlayerHiddenAttribute(player: Player, isHidden: boolean)
	local character = player.Character
	if character then
		character:SetAttribute("IsHidden", isHidden)
	end
end

-- Hook into hide state changes
Remotes[Constants.EVENT_HIDE_STATE_CHANGED].OnServerEvent:Connect(function(player: Player, _isHidden: boolean)
	-- This is fired FROM client but we already handle state on server
	-- Just a safety sync; the actual hiding logic is in the prompt handler above
end)

-- ==========================================
-- PLAYER LIFECYCLE
-- ==========================================

local function onPlayerAdded(player: Player)
	getPlayerData(player) -- Initialize data

	player.CharacterAdded:Connect(function(character)
		-- Give flashlight on spawn
		task.wait(0.5) -- Wait for character to fully load
		giveFlashlight(player)

		-- Reset hidden state on respawn
		local data = getPlayerData(player)
		data.isHidden = false
		data.hidingSpot = nil
		data.flashlightOn = false

		character:SetAttribute("IsHidden", false)

		-- Clean up occupied spots
		for spot, occupant in occupiedSpots do
			if occupant == player then
				occupiedSpots[spot] = nil
			end
		end
	end)
end

local function onPlayerRemoving(player: Player)
	-- Clean up
	for spot, occupant in occupiedSpots do
		if occupant == player then
			occupiedSpots[spot] = nil
		end
	end
	playerData[player.UserId] = nil
	flashlightPlayers[player.UserId] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players already in game (Studio testing)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- ==========================================
-- INITIALIZATION: Set up tagged objects
-- ==========================================

-- Hiding spots
for _, spot in CollectionService:GetTagged(Constants.TAG_HIDING_SPOT) do
	if spot:IsA("BasePart") then
		setupHidingSpot(spot)
	end
end
CollectionService:GetInstanceAddedSignal(Constants.TAG_HIDING_SPOT):Connect(function(inst)
	if inst:IsA("BasePart") then
		setupHidingSpot(inst)
	end
end)

-- Cat treats
for _, treat in CollectionService:GetTagged(Constants.TAG_CAT_TREAT) do
	if treat:IsA("BasePart") then
		setupCatTreat(treat)
	end
end
CollectionService:GetInstanceAddedSignal(Constants.TAG_CAT_TREAT):Connect(function(inst)
	if inst:IsA("BasePart") then
		setupCatTreat(inst)
	end
end)

-- Doors
for _, door in CollectionService:GetTagged(Constants.TAG_DOOR) do
	if door:IsA("BasePart") then
		setupDoor(door)
	end
end
CollectionService:GetInstanceAddedSignal(Constants.TAG_DOOR):Connect(function(inst)
	if inst:IsA("BasePart") then
		setupDoor(inst)
	end
end)

-- Locked doors (also set up as regular doors)
for _, door in CollectionService:GetTagged(Constants.TAG_LOCKED_DOOR) do
	if door:IsA("BasePart") then
		setupDoor(door)
	end
end
CollectionService:GetInstanceAddedSignal(Constants.TAG_LOCKED_DOOR):Connect(function(inst)
	if inst:IsA("BasePart") then
		setupDoor(inst)
	end
end)

-- Keys
for _, key in CollectionService:GetTagged(Constants.TAG_KEY) do
	if key:IsA("BasePart") then
		setupKey(key)
	end
end
CollectionService:GetInstanceAddedSignal(Constants.TAG_KEY):Connect(function(inst)
	if inst:IsA("BasePart") then
		setupKey(inst)
	end
end)

print("[GameplayEnhancements] All gameplay systems initialized")
print("[GameplayEnhancements] Hiding spots:", #CollectionService:GetTagged(Constants.TAG_HIDING_SPOT))
print("[GameplayEnhancements] Cat treats:", #CollectionService:GetTagged(Constants.TAG_CAT_TREAT))
print("[GameplayEnhancements] Doors:", #CollectionService:GetTagged(Constants.TAG_DOOR))
print("[GameplayEnhancements] Locked doors:", #CollectionService:GetTagged(Constants.TAG_LOCKED_DOOR))
print("[GameplayEnhancements] Keys:", #CollectionService:GetTagged(Constants.TAG_KEY))
print("[GameplayEnhancements] Secret passages:", #CollectionService:GetTagged(Constants.TAG_SECRET_PASSAGE))

--[[
	FootprintTrail - The evil cat leaves faint glowing paw print decals as it walks
	Helps players track where the cat has been recently, building tension.
	Paw prints fade out after a few seconds.
	All effects are client-side for performance.
]]

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

-- ==================
-- CONFIGURATION
-- ==================

local PAW_PRINT_INTERVAL = 1.2 -- Seconds between paw prints
local PAW_PRINT_LIFETIME = 6.0 -- Seconds before a print fully fades
local PAW_PRINT_FADE_TIME = 2.5 -- Seconds for the fade-out portion
local PAW_PRINT_SIZE = Vector3.new(1.2, 0.05, 1.4) -- Flat decal size
local PAW_PRINT_COLOR = Color3.fromRGB(255, 220, 0) -- Glowing yellow
local PAW_PRINT_GLOW_COLOR = Color3.fromRGB(255, 200, 0)
local MAX_ACTIVE_PRINTS = 40 -- Cap to prevent memory issues
local MIN_MOVE_DISTANCE = 2 -- Cat must move at least this far for a new print

-- ==================
-- PAW PRINT POOL
-- ==================

local activePrints: { { part: Part, light: PointLight, createdAt: number } } = {}

-- Cat tracking data
local catTrackData: { [Model]: { lastPrintPos: Vector3, timer: number, leftFoot: boolean } } = {}

local function createPawPrint(position: Vector3, rotation: CFrame)
	-- Raycast down to find the floor
	local rayResult = workspace:Raycast(
		position + Vector3.new(0, 2, 0),
		Vector3.new(0, -10, 0),
		RaycastParams.new()
	)

	local floorPos = position
	local floorNormal = Vector3.new(0, 1, 0)

	if rayResult then
		floorPos = rayResult.Position
		floorNormal = rayResult.Normal
	end

	-- Create the paw print part
	local pawPrint = Instance.new("Part")
	pawPrint.Name = "PawPrint"
	pawPrint.Size = PAW_PRINT_SIZE
	pawPrint.Anchored = true
	pawPrint.CanCollide = false
	pawPrint.CanQuery = false
	pawPrint.CanTouch = false
	pawPrint.Material = Enum.Material.Neon
	pawPrint.Color = PAW_PRINT_COLOR
	pawPrint.Transparency = 0.4

	-- Orient to floor surface and cat's facing direction
	local lookDir = rotation.LookVector
	local flatLook = Vector3.new(lookDir.X, 0, lookDir.Z).Unit
	if flatLook.Magnitude < 0.1 then
		flatLook = Vector3.new(1, 0, 0)
	end

	-- Place on floor, aligned with surface normal
	pawPrint.CFrame = CFrame.new(floorPos + floorNormal * 0.02) * CFrame.lookAt(Vector3.zero, flatLook, floorNormal)

	-- Add a subtle glow light
	local glow = Instance.new("PointLight")
	glow.Name = "PawGlow"
	glow.Color = PAW_PRINT_GLOW_COLOR
	glow.Brightness = 0.4
	glow.Range = 4
	glow.Parent = pawPrint

	-- Create paw pad pattern using small child parts
	-- Main pad (large oval)
	local mainPad = Instance.new("Part")
	mainPad.Name = "MainPad"
	mainPad.Size = Vector3.new(0.5, 0.06, 0.5)
	mainPad.Anchored = true
	mainPad.CanCollide = false
	mainPad.CanQuery = false
	mainPad.CanTouch = false
	mainPad.Material = Enum.Material.Neon
	mainPad.Color = PAW_PRINT_COLOR
	mainPad.Transparency = 0.3
	mainPad.Shape = Enum.PartType.Cylinder
	mainPad.CFrame = pawPrint.CFrame * CFrame.new(0, 0.01, 0.15) * CFrame.Angles(0, 0, math.rad(90))
	mainPad.Parent = pawPrint

	-- Toe pads (3 small circles above the main pad)
	local toeOffsets = {
		CFrame.new(-0.25, 0.01, -0.25),
		CFrame.new(0, 0.01, -0.35),
		CFrame.new(0.25, 0.01, -0.25),
	}

	for i, offset in toeOffsets do
		local toe = Instance.new("Part")
		toe.Name = "Toe" .. i
		toe.Size = Vector3.new(0.2, 0.06, 0.2)
		toe.Anchored = true
		toe.CanCollide = false
		toe.CanQuery = false
		toe.CanTouch = false
		toe.Material = Enum.Material.Neon
		toe.Color = PAW_PRINT_COLOR
		toe.Transparency = 0.3
		toe.Shape = Enum.PartType.Ball
		toe.CFrame = pawPrint.CFrame * offset
		toe.Parent = pawPrint
	end

	pawPrint.Parent = workspace

	-- Track the print
	local printData = {
		part = pawPrint,
		light = glow,
		createdAt = tick(),
	}
	table.insert(activePrints, printData)

	-- Enforce max prints limit
	while #activePrints > MAX_ACTIVE_PRINTS do
		local oldest = table.remove(activePrints, 1)
		if oldest and oldest.part.Parent then
			oldest.part:Destroy()
		end
	end
end

-- ==================
-- CAT TRACKING
-- ==================

local function onCatAdded(catModel: Instance)
	if not catModel:IsA("Model") then
		return
	end

	catTrackData[catModel] = {
		lastPrintPos = Vector3.zero,
		timer = 0,
		leftFoot = false,
	}
end

local function onCatRemoved(catModel: Instance)
	catTrackData[catModel] = nil
end

-- Register existing cats
for _, cat in CollectionService:GetTagged(Constants.TAG_EVIL_CAT) do
	onCatAdded(cat)
end

CollectionService:GetInstanceAddedSignal(Constants.TAG_EVIL_CAT):Connect(onCatAdded)
CollectionService:GetInstanceRemovedSignal(Constants.TAG_EVIL_CAT):Connect(onCatRemoved)

-- ==================
-- UPDATE LOOP
-- ==================

RunService.Heartbeat:Connect(function(dt)
	local now = tick()

	-- ---- Update cat footprints ----
	for catModel, trackData in catTrackData do
		if not catModel.Parent then
			continue
		end

		local rootPart = catModel.PrimaryPart or catModel:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			continue
		end

		local humanoid = catModel:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			continue
		end

		-- Only place prints when cat is moving
		local velocity = rootPart.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		if speed < 1 then
			continue
		end

		trackData.timer = trackData.timer + dt
		if trackData.timer < PAW_PRINT_INTERVAL then
			continue
		end

		-- Check minimum distance
		local currentPos = rootPart.Position
		if (currentPos - trackData.lastPrintPos).Magnitude < MIN_MOVE_DISTANCE then
			continue
		end

		trackData.timer = 0
		trackData.lastPrintPos = currentPos
		trackData.leftFoot = not trackData.leftFoot

		-- Offset slightly left or right for alternating feet
		local sideOffset = trackData.leftFoot and -0.4 or 0.4
		local printPos = currentPos + rootPart.CFrame.RightVector * sideOffset

		createPawPrint(printPos, rootPart.CFrame)
	end

	-- ---- Fade out old prints ----
	for i = #activePrints, 1, -1 do
		local printData = activePrints[i]
		local age = now - printData.createdAt

		if age > PAW_PRINT_LIFETIME then
			-- Fully expired, destroy
			if printData.part.Parent then
				printData.part:Destroy()
			end
			table.remove(activePrints, i)
		elseif age > (PAW_PRINT_LIFETIME - PAW_PRINT_FADE_TIME) then
			-- In fade-out period
			local fadeProgress = (age - (PAW_PRINT_LIFETIME - PAW_PRINT_FADE_TIME)) / PAW_PRINT_FADE_TIME
			local transparency = 0.4 + fadeProgress * 0.6 -- 0.4 -> 1.0

			printData.part.Transparency = transparency
			printData.light.Brightness = 0.4 * (1 - fadeProgress)

			-- Fade child parts too
			for _, child in printData.part:GetChildren() do
				if child:IsA("BasePart") then
					child.Transparency = 0.3 + fadeProgress * 0.7
				end
			end
		end
	end
end)

print("[FootprintTrail] Cat footprint tracking initialized")

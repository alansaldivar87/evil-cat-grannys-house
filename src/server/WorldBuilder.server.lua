--[[
	WorldBuilder - Procedurally generates the entire game world from basic Parts
	Creates a complete, playable horror house with all required gameplay elements.

	This script runs after AssetLoader and generates:
	  - Full house structure (walls, floors, ceilings)
	  - Multiple rooms: Entrance, Hallway, Kitchen, Living Room, Bedroom,
	    Bathroom, Basement, Attic, Boss Arena
	  - Doors between rooms (tagged for the door system)
	  - Furniture (tables, chairs, beds, closets, bookshelves)
	  - Hiding spots (closets, beds) tagged "HidingSpot"
	  - Story notes tagged "StoryNote" with NoteId attributes
	  - Checkpoints tagged "Checkpoint" with Order attributes
	  - PatrolPoints for cat AI navigation
	  - Cat treats tagged "CatTreat" with Room attributes
	  - Keys tagged "Key" with KeyId attributes
	  - Locked doors tagged "LockedDoor" with matching KeyId
	  - KillBrick obby obstacles
	  - WeaponPickup in boss area
	  - BossArena trigger
	  - Lighting (PointLights, some tagged FlickerLight)
	  - SpawnLocation at the entrance
	  - Outdoor elements (ground, fence, trees)
	  - Secret passages tagged "SecretPassage"
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

-- Wait for AssetLoader to finish
task.wait(2)

-- Only run once
if ServerStorage:FindFirstChild("WorldSetup") then
	print("[WorldBuilder] World already set up, skipping.")
	return
end

print("[WorldBuilder] Beginning world generation...")

-- ==========================================
-- CONFIGURATION
-- ==========================================

local WALL_THICKNESS = 1
local WALL_HEIGHT = 12
local FLOOR_THICKNESS = 1
local ROOM_HEIGHT = WALL_HEIGHT
local STUD_SIZE = 1 -- Base unit

-- Materials and colors
local MATERIALS = {
	FLOOR_WOOD = { material = Enum.Material.Wood, color = Color3.fromRGB(101, 67, 33) },
	FLOOR_TILE = { material = Enum.Material.Marble, color = Color3.fromRGB(200, 200, 210) },
	FLOOR_STONE = { material = Enum.Material.Slate, color = Color3.fromRGB(80, 80, 90) },
	FLOOR_CARPET = { material = Enum.Material.Fabric, color = Color3.fromRGB(100, 30, 30) },
	WALL_BRICK = { material = Enum.Material.Brick, color = Color3.fromRGB(120, 80, 60) },
	WALL_PLASTER = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(160, 150, 140) },
	WALL_DARK = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(60, 55, 50) },
	WALL_BASEMENT = { material = Enum.Material.Concrete, color = Color3.fromRGB(90, 85, 80) },
	CEILING = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(140, 135, 130) },
	ROOF = { material = Enum.Material.Slate, color = Color3.fromRGB(50, 45, 40) },
	GROUND = { material = Enum.Material.Grass, color = Color3.fromRGB(50, 80, 40) },
	FENCE = { material = Enum.Material.Wood, color = Color3.fromRGB(60, 40, 25) },
	DOOR = { material = Enum.Material.Wood, color = Color3.fromRGB(80, 50, 30) },
}

-- World container
local worldFolder = Instance.new("Folder")
worldFolder.Name = "HorrorHouse"
worldFolder.Parent = workspace

-- ==========================================
-- PART CREATION HELPERS
-- ==========================================

local function createPart(props): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.Name = props.name or "Part"
	part.Size = props.size or Vector3.new(1, 1, 1)
	part.Position = props.position or Vector3.new(0, 0, 0)
	if props.cframe then
		part.CFrame = props.cframe
	end
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.fromRGB(128, 128, 128)
	part.CanCollide = props.canCollide ~= false
	part.Transparency = props.transparency or 0
	part.Parent = props.parent or worldFolder
	return part
end

local function applyStyle(part: BasePart, style)
	part.Material = style.material
	part.Color = style.color
end

local function addLight(parent: BasePart, props)
	local light = Instance.new("PointLight")
	light.Color = props.color or Color3.fromRGB(255, 200, 150)
	light.Brightness = props.brightness or 0.5
	light.Range = props.range or 15
	light.Shadows = props.shadows or false
	light.Parent = parent
	return light
end

local function addTag(part: Instance, tag: string)
	CollectionService:AddTag(part, tag)
end

-- ==========================================
-- ROOM DEFINITIONS
-- Room origin is at the center-bottom of the floor
-- ==========================================

-- All rooms with their positions, sizes, and styles
local rooms = {
	{
		name = "Entrance",
		origin = Vector3.new(0, 0, 0),
		size = Vector3.new(20, ROOM_HEIGHT, 15),
		floorStyle = MATERIALS.FLOOR_WOOD,
		wallStyle = MATERIALS.WALL_PLASTER,
		hasSpawn = true,
	},
	{
		name = "Hallway",
		origin = Vector3.new(0, 0, -17.5),
		size = Vector3.new(8, ROOM_HEIGHT, 20),
		floorStyle = MATERIALS.FLOOR_WOOD,
		wallStyle = MATERIALS.WALL_DARK,
	},
	{
		name = "LivingRoom",
		origin = Vector3.new(-18, 0, -20),
		size = Vector3.new(24, ROOM_HEIGHT, 20),
		floorStyle = MATERIALS.FLOOR_CARPET,
		wallStyle = MATERIALS.WALL_PLASTER,
	},
	{
		name = "Kitchen",
		origin = Vector3.new(18, 0, -20),
		size = Vector3.new(20, ROOM_HEIGHT, 20),
		floorStyle = MATERIALS.FLOOR_TILE,
		wallStyle = MATERIALS.WALL_PLASTER,
	},
	{
		name = "Bedroom",
		origin = Vector3.new(-18, ROOM_HEIGHT, -20),
		size = Vector3.new(24, ROOM_HEIGHT, 20),
		floorStyle = MATERIALS.FLOOR_CARPET,
		wallStyle = MATERIALS.WALL_DARK,
	},
	{
		name = "Bathroom",
		origin = Vector3.new(18, ROOM_HEIGHT, -20),
		size = Vector3.new(20, ROOM_HEIGHT, 12),
		floorStyle = MATERIALS.FLOOR_TILE,
		wallStyle = MATERIALS.WALL_PLASTER,
	},
	{
		name = "Attic",
		origin = Vector3.new(18, ROOM_HEIGHT, -34),
		size = Vector3.new(20, ROOM_HEIGHT, 10),
		floorStyle = MATERIALS.FLOOR_WOOD,
		wallStyle = MATERIALS.WALL_DARK,
	},
	{
		name = "Basement",
		origin = Vector3.new(0, -ROOM_HEIGHT, -20),
		size = Vector3.new(40, ROOM_HEIGHT, 30),
		floorStyle = MATERIALS.FLOOR_STONE,
		wallStyle = MATERIALS.WALL_BASEMENT,
	},
	{
		name = "BossArena",
		origin = Vector3.new(0, -ROOM_HEIGHT, -55),
		size = Vector3.new(50, ROOM_HEIGHT + 4, 40),
		floorStyle = MATERIALS.FLOOR_STONE,
		wallStyle = MATERIALS.WALL_BASEMENT,
	},
}

-- ==========================================
-- BUILD ROOMS
-- ==========================================

local roomFolders = {}

local function buildRoom(roomDef)
	local folder = Instance.new("Folder")
	folder.Name = roomDef.name
	folder.Parent = worldFolder

	roomFolders[roomDef.name] = folder

	local ox, oy, oz = roomDef.origin.X, roomDef.origin.Y, roomDef.origin.Z
	local sx, sy, sz = roomDef.size.X, roomDef.size.Y, roomDef.size.Z

	-- Floor
	local floor = createPart({
		name = "Floor",
		size = Vector3.new(sx, FLOOR_THICKNESS, sz),
		position = Vector3.new(ox, oy, oz),
		parent = folder,
	})
	applyStyle(floor, roomDef.floorStyle)
	addTag(floor, Constants.TAG_ROOM)
	floor:SetAttribute("Room", roomDef.name)

	-- Ceiling
	local ceiling = createPart({
		name = "Ceiling",
		size = Vector3.new(sx, FLOOR_THICKNESS, sz),
		position = Vector3.new(ox, oy + sy, oz),
		parent = folder,
	})
	applyStyle(ceiling, MATERIALS.CEILING)

	-- Walls (4 sides)
	-- North wall (positive Z excluded since that's typically the entrance side)
	local northWall = createPart({
		name = "WallNorth",
		size = Vector3.new(sx, sy, WALL_THICKNESS),
		position = Vector3.new(ox, oy + sy / 2, oz + sz / 2),
		parent = folder,
	})
	applyStyle(northWall, roomDef.wallStyle)

	-- South wall
	local southWall = createPart({
		name = "WallSouth",
		size = Vector3.new(sx, sy, WALL_THICKNESS),
		position = Vector3.new(ox, oy + sy / 2, oz - sz / 2),
		parent = folder,
	})
	applyStyle(southWall, roomDef.wallStyle)

	-- East wall
	local eastWall = createPart({
		name = "WallEast",
		size = Vector3.new(WALL_THICKNESS, sy, sz),
		position = Vector3.new(ox + sx / 2, oy + sy / 2, oz),
		parent = folder,
	})
	applyStyle(eastWall, roomDef.wallStyle)

	-- West wall
	local westWall = createPart({
		name = "WallWest",
		size = Vector3.new(WALL_THICKNESS, sy, sz),
		position = Vector3.new(ox - sx / 2, oy + sy / 2, oz),
		parent = folder,
	})
	applyStyle(westWall, roomDef.wallStyle)

	-- Room lighting
	local lightPart = createPart({
		name = "RoomLight",
		size = Vector3.new(1, 0.5, 1),
		position = Vector3.new(ox, oy + sy - 1, oz),
		transparency = 0.9,
		canCollide = false,
		parent = folder,
	})
	lightPart.Material = Enum.Material.Neon
	lightPart.Color = Color3.fromRGB(255, 200, 120)

	local brightness = 0.4
	local range = math.max(sx, sz) * 0.8
	if roomDef.name == "Basement" or roomDef.name == "BossArena" then
		brightness = 0.2
		range = range * 0.6
	end

	addLight(lightPart, {
		color = Color3.fromRGB(255, 200, 150),
		brightness = brightness,
		range = range,
	})

	-- Add a flicker light in some rooms
	if roomDef.name == "Hallway" or roomDef.name == "Basement" or roomDef.name == "Attic" or roomDef.name == "Bedroom" then
		addTag(lightPart, Constants.TAG_FLICKER_LIGHT)
	end

	-- SpawnLocation
	if roomDef.hasSpawn then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "SpawnLocation"
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.Position = Vector3.new(ox, oy + 1, oz)
		spawn.Anchored = true
		spawn.Material = Enum.Material.Neon
		spawn.Color = Color3.fromRGB(0, 200, 100)
		spawn.Transparency = 0.5
		spawn.CanCollide = true
		spawn.Parent = folder
	end

	return folder
end

-- Build all rooms
print("[WorldBuilder] Building rooms...")
for _, roomDef in rooms do
	buildRoom(roomDef)
	print("[WorldBuilder]   Built:", roomDef.name)
end

-- ==========================================
-- DOORWAYS (cut holes in walls by creating split walls)
-- We handle this by creating door parts tagged "Door"
-- ==========================================

print("[WorldBuilder] Creating doors...")

local function createDoor(props)
	local door = createPart({
		name = props.name or "Door",
		size = props.size or Vector3.new(5, 8, WALL_THICKNESS),
		position = props.position,
		parent = props.parent or worldFolder,
	})
	applyStyle(door, MATERIALS.DOOR)
	addTag(door, Constants.TAG_DOOR)

	if props.locked then
		addTag(door, Constants.TAG_LOCKED_DOOR)
		door:SetAttribute("KeyId", props.keyId or "default")
	end

	return door
end

-- Entrance to Hallway (south wall of entrance)
createDoor({
	name = "Door_EntranceToHallway",
	size = Vector3.new(5, 8, WALL_THICKNESS),
	position = Vector3.new(0, 4.5, -7.5),
	parent = roomFolders["Entrance"],
})

-- Hallway to Living Room (west wall of hallway)
createDoor({
	name = "Door_HallwayToLiving",
	size = Vector3.new(WALL_THICKNESS, 8, 5),
	position = Vector3.new(-4, 4.5, -20),
	parent = roomFolders["Hallway"],
})

-- Hallway to Kitchen (east wall of hallway)
createDoor({
	name = "Door_HallwayToKitchen",
	size = Vector3.new(WALL_THICKNESS, 8, 5),
	position = Vector3.new(4, 4.5, -20),
	parent = roomFolders["Hallway"],
})

-- Stairs to Bedroom (locked door to upstairs)
createDoor({
	name = "Door_ToUpstairs",
	size = Vector3.new(5, 8, WALL_THICKNESS),
	position = Vector3.new(-18, ROOM_HEIGHT + 4.5, -10),
	parent = roomFolders["Bedroom"],
	locked = true,
	keyId = "upstairs_key",
})

-- Door to Bathroom
createDoor({
	name = "Door_ToBathroom",
	size = Vector3.new(WALL_THICKNESS, 8, 5),
	position = Vector3.new(8, ROOM_HEIGHT + 4.5, -20),
	parent = roomFolders["Bathroom"],
})

-- Door to Attic
createDoor({
	name = "Door_ToAttic",
	size = Vector3.new(5, 8, WALL_THICKNESS),
	position = Vector3.new(18, ROOM_HEIGHT + 4.5, -26),
	parent = roomFolders["Attic"],
	locked = true,
	keyId = "attic_key",
})

-- Stairs to Basement (locked)
createDoor({
	name = "Door_ToBasement",
	size = Vector3.new(5, 8, WALL_THICKNESS),
	position = Vector3.new(0, -ROOM_HEIGHT + 4.5, -5),
	parent = roomFolders["Basement"],
	locked = true,
	keyId = "basement_key",
})

-- Basement to Boss Arena
createDoor({
	name = "Door_ToBossArena",
	size = Vector3.new(6, 10, WALL_THICKNESS),
	position = Vector3.new(0, -ROOM_HEIGHT + 5, -35),
	parent = roomFolders["BossArena"],
	locked = true,
	keyId = "boss_key",
})

-- ==========================================
-- STAIRCASES
-- ==========================================

print("[WorldBuilder] Building staircases...")

local function buildStaircase(startPos, endPos, numSteps, parent)
	local stairFolder = Instance.new("Folder")
	stairFolder.Name = "Staircase"
	stairFolder.Parent = parent or worldFolder

	local dx = (endPos.X - startPos.X) / numSteps
	local dy = (endPos.Y - startPos.Y) / numSteps
	local dz = (endPos.Z - startPos.Z) / numSteps

	for i = 0, numSteps - 1 do
		local step = createPart({
			name = "Step_" .. i,
			size = Vector3.new(5, 1, 2),
			position = Vector3.new(
				startPos.X + dx * i,
				startPos.Y + dy * i,
				startPos.Z + dz * i
			),
			parent = stairFolder,
		})
		applyStyle(step, MATERIALS.FLOOR_WOOD)
	end

	return stairFolder
end

-- Stairs from Hallway up to Bedroom level
buildStaircase(
	Vector3.new(-14, 1, -10),
	Vector3.new(-14, ROOM_HEIGHT + 1, -20),
	12,
	roomFolders["Bedroom"]
)

-- Stairs from Hallway down to Basement
buildStaircase(
	Vector3.new(0, 0, -10),
	Vector3.new(0, -ROOM_HEIGHT + 1, -15),
	12,
	roomFolders["Basement"]
)

-- ==========================================
-- FURNITURE
-- ==========================================

print("[WorldBuilder] Placing furniture...")

local function createTable(position, parent, roomName)
	local top = createPart({
		name = "Table",
		size = Vector3.new(5, 0.5, 3),
		position = position + Vector3.new(0, 3, 0),
		parent = parent,
	})
	applyStyle(top, MATERIALS.FLOOR_WOOD)

	-- Legs
	for _, offset in {
		Vector3.new(-2, 1.5, -1),
		Vector3.new(2, 1.5, -1),
		Vector3.new(-2, 1.5, 1),
		Vector3.new(2, 1.5, 1),
	} do
		local leg = createPart({
			name = "TableLeg",
			size = Vector3.new(0.3, 2.5, 0.3),
			position = position + offset,
			parent = parent,
		})
		applyStyle(leg, MATERIALS.FLOOR_WOOD)
	end
end

local function createChair(position, parent, rotation)
	local seat = createPart({
		name = "Chair",
		size = Vector3.new(2, 0.3, 2),
		position = position + Vector3.new(0, 2, 0),
		parent = parent,
	})
	applyStyle(seat, MATERIALS.FLOOR_WOOD)

	-- Back
	local back = createPart({
		name = "ChairBack",
		size = Vector3.new(2, 2.5, 0.3),
		position = position + Vector3.new(0, 3.5, -1),
		parent = parent,
	})
	applyStyle(back, MATERIALS.FLOOR_WOOD)
end

local function createBed(position, parent, roomName)
	-- Mattress
	local mattress = createPart({
		name = "Bed_" .. roomName,
		size = Vector3.new(5, 1, 8),
		position = position + Vector3.new(0, 2, 0),
		parent = parent,
	})
	mattress.Material = Enum.Material.Fabric
	mattress.Color = Color3.fromRGB(180, 180, 200)
	addTag(mattress, Constants.TAG_HIDING_SPOT)

	-- Frame
	local frame = createPart({
		name = "BedFrame",
		size = Vector3.new(5.5, 1.5, 8.5),
		position = position + Vector3.new(0, 0.75, 0),
		parent = parent,
	})
	applyStyle(frame, MATERIALS.FLOOR_WOOD)

	-- Headboard
	local headboard = createPart({
		name = "Headboard",
		size = Vector3.new(5.5, 3, 0.5),
		position = position + Vector3.new(0, 3, -4),
		parent = parent,
	})
	applyStyle(headboard, MATERIALS.FLOOR_WOOD)

	-- Pillow
	local pillow = createPart({
		name = "Pillow",
		size = Vector3.new(3, 0.5, 1.5),
		position = position + Vector3.new(0, 2.8, -3),
		parent = parent,
	})
	pillow.Material = Enum.Material.Fabric
	pillow.Color = Color3.fromRGB(220, 220, 230)
end

local function createCloset(position, parent, roomName)
	local closet = createPart({
		name = "Closet_" .. roomName,
		size = Vector3.new(4, 7, 2),
		position = position + Vector3.new(0, 3.5, 0),
		parent = parent,
	})
	applyStyle(closet, MATERIALS.FLOOR_WOOD)
	closet.Color = Color3.fromRGB(70, 45, 25)
	addTag(closet, Constants.TAG_HIDING_SPOT)
end

local function createBookshelf(position, parent)
	local shelf = createPart({
		name = "Bookshelf",
		size = Vector3.new(4, 7, 1.5),
		position = position + Vector3.new(0, 3.5, 0),
		parent = parent,
	})
	applyStyle(shelf, MATERIALS.FLOOR_WOOD)
	shelf.Color = Color3.fromRGB(90, 55, 30)

	-- Books (colored blocks)
	local bookColors = {
		Color3.fromRGB(150, 30, 30),
		Color3.fromRGB(30, 80, 30),
		Color3.fromRGB(30, 30, 120),
		Color3.fromRGB(120, 80, 20),
	}

	for i = 1, 3 do
		local book = createPart({
			name = "Book",
			size = Vector3.new(3.5, 1, 1),
			position = position + Vector3.new(0, 1 + i * 2, 0),
			parent = parent,
		})
		book.Color = bookColors[((i - 1) % #bookColors) + 1]
		book.Material = Enum.Material.SmoothPlastic
	end
end

local function createKitchenCounter(position, parent)
	local counter = createPart({
		name = "Counter",
		size = Vector3.new(8, 3, 2),
		position = position + Vector3.new(0, 1.5, 0),
		parent = parent,
	})
	counter.Material = Enum.Material.Marble
	counter.Color = Color3.fromRGB(180, 180, 180)
end

local function createCandle(position, parent, roomName)
	-- Candle body
	local candle = createPart({
		name = "Candle",
		size = Vector3.new(0.3, 1, 0.3),
		position = position,
		parent = parent,
	})
	candle.Material = Enum.Material.SmoothPlastic
	candle.Color = Color3.fromRGB(230, 220, 180)

	-- Flame
	local flame = createPart({
		name = "Flame",
		size = Vector3.new(0.15, 0.4, 0.15),
		position = position + Vector3.new(0, 0.7, 0),
		canCollide = false,
		parent = parent,
	})
	flame.Material = Enum.Material.Neon
	flame.Color = Color3.fromRGB(255, 150, 30)

	local light = addLight(flame, {
		color = Color3.fromRGB(255, 150, 50),
		brightness = 0.6,
		range = 10,
	})

	addTag(flame, Constants.TAG_FLICKER_LIGHT)
end

local function createPainting(position, parent, wallNormal)
	local painting = createPart({
		name = "Painting",
		size = Vector3.new(4, 3, 0.2),
		position = position,
		parent = parent,
	})
	painting.Material = Enum.Material.SmoothPlastic
	-- Dark creepy painting
	painting.Color = Color3.fromRGB(40, 30, 25)

	-- Frame
	local frame = createPart({
		name = "PaintingFrame",
		size = Vector3.new(4.4, 3.4, 0.1),
		position = position + Vector3.new(0, 0, -0.15),
		parent = parent,
	})
	frame.Material = Enum.Material.Metal
	frame.Color = Color3.fromRGB(100, 80, 30)
end

local function createClock(position, parent)
	local clock = createPart({
		name = "Clock",
		size = Vector3.new(2, 2, 0.3),
		position = position,
		parent = parent,
	})
	clock.Shape = Enum.PartType.Cylinder
	clock.Material = Enum.Material.Wood
	clock.Color = Color3.fromRGB(80, 50, 30)
	clock.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
end

-- Place furniture in rooms

-- Kitchen furniture
local kitchenFolder = roomFolders["Kitchen"]
if kitchenFolder then
	createTable(Vector3.new(18, 0.5, -18), kitchenFolder, "Kitchen")
	createChair(Vector3.new(15, 0.5, -18), kitchenFolder)
	createChair(Vector3.new(21, 0.5, -18), kitchenFolder)
	createKitchenCounter(Vector3.new(22, 0.5, -12), kitchenFolder)
	createKitchenCounter(Vector3.new(22, 0.5, -28), kitchenFolder)
	createCandle(Vector3.new(18, 3.8, -18), kitchenFolder, "Kitchen")
end

-- Living Room furniture
local livingFolder = roomFolders["LivingRoom"]
if livingFolder then
	createTable(Vector3.new(-18, 0.5, -18), livingFolder, "LivingRoom")
	createChair(Vector3.new(-22, 0.5, -18), livingFolder)
	createChair(Vector3.new(-14, 0.5, -18), livingFolder)
	createBookshelf(Vector3.new(-28, 0.5, -12), livingFolder)
	createBookshelf(Vector3.new(-28, 0.5, -28), livingFolder)
	createCloset(Vector3.new(-8, 0.5, -28), livingFolder, "LivingRoom")
	createPainting(Vector3.new(-18, 7, -29.5), livingFolder)
	createCandle(Vector3.new(-24, 4, -20), livingFolder, "LivingRoom")
	createClock(Vector3.new(-18, 9, -29.5), livingFolder)
end

-- Bedroom furniture
local bedroomFolder = roomFolders["Bedroom"]
if bedroomFolder then
	local by = ROOM_HEIGHT + 0.5
	createBed(Vector3.new(-22, by, -25), bedroomFolder, "Bedroom")
	createCloset(Vector3.new(-10, by, -28), bedroomFolder, "Bedroom")
	createBookshelf(Vector3.new(-28, by, -15), bedroomFolder)
	createCandle(Vector3.new(-15, by + 3.5, -25), bedroomFolder, "Bedroom")
	createPainting(Vector3.new(-22, by + 6, -29.5), bedroomFolder)
end

-- Bathroom furniture (minimal)
local bathroomFolder = roomFolders["Bathroom"]
if bathroomFolder then
	local by = ROOM_HEIGHT + 0.5
	-- Bathtub
	local tub = createPart({
		name = "Bathtub",
		size = Vector3.new(3, 2, 6),
		position = Vector3.new(26, by + 1, -20),
		parent = bathroomFolder,
	})
	tub.Material = Enum.Material.Marble
	tub.Color = Color3.fromRGB(220, 220, 230)
	addTag(tub, Constants.TAG_HIDING_SPOT)
end

-- Entrance furniture
local entranceFolder = roomFolders["Entrance"]
if entranceFolder then
	createBookshelf(Vector3.new(-8, 0.5, 5), entranceFolder)
	createCandle(Vector3.new(8, 4, 5), entranceFolder, "Entrance")
	createPainting(Vector3.new(0, 7, 6.5), entranceFolder)
end

-- ==========================================
-- CHECKPOINTS
-- ==========================================

print("[WorldBuilder] Creating checkpoints...")

local checkpoints = {
	{ order = 1, position = Vector3.new(0, 1.5, 0), name = "Entrance" },
	{ order = 2, position = Vector3.new(0, 1.5, -17), name = "Hallway" },
	{ order = 3, position = Vector3.new(-18, 1.5, -20), name = "LivingRoom" },
	{ order = 4, position = Vector3.new(18, 1.5, -20), name = "Kitchen" },
	{ order = 5, position = Vector3.new(-18, ROOM_HEIGHT + 1.5, -20), name = "Bedroom" },
	{ order = 6, position = Vector3.new(18, ROOM_HEIGHT + 1.5, -20), name = "Bathroom" },
	{ order = 7, position = Vector3.new(18, ROOM_HEIGHT + 1.5, -34), name = "Attic" },
	{ order = 8, position = Vector3.new(0, -ROOM_HEIGHT + 1.5, -20), name = "Basement" },
	{ order = 9, position = Vector3.new(0, -ROOM_HEIGHT + 1.5, -50), name = "BossArena" },
}

for _, cp in checkpoints do
	local part = createPart({
		name = "Checkpoint_" .. cp.name,
		size = Vector3.new(5, 1, 5),
		position = cp.position,
		transparency = 0.7,
		canCollide = false,
	})
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(0, 200, 0)
	part:SetAttribute("Order", cp.order)
	addTag(part, Constants.TAG_CHECKPOINT)
end

-- ==========================================
-- PATROL POINTS (for cat AI pathfinding)
-- ==========================================

print("[WorldBuilder] Creating patrol points...")

local patrolPositions = {
	-- Ground floor patrol route
	Vector3.new(0, 2, -5),
	Vector3.new(0, 2, -15),
	Vector3.new(0, 2, -25),
	Vector3.new(-15, 2, -15),
	Vector3.new(-15, 2, -25),
	Vector3.new(-25, 2, -15),
	Vector3.new(-25, 2, -25),
	Vector3.new(15, 2, -15),
	Vector3.new(15, 2, -25),
	Vector3.new(25, 2, -15),
	Vector3.new(25, 2, -25),
	-- Upstairs patrol
	Vector3.new(-15, ROOM_HEIGHT + 2, -15),
	Vector3.new(-15, ROOM_HEIGHT + 2, -25),
	Vector3.new(-25, ROOM_HEIGHT + 2, -20),
	Vector3.new(15, ROOM_HEIGHT + 2, -20),
	-- Basement patrol
	Vector3.new(-10, -ROOM_HEIGHT + 2, -15),
	Vector3.new(10, -ROOM_HEIGHT + 2, -15),
	Vector3.new(0, -ROOM_HEIGHT + 2, -25),
	Vector3.new(-15, -ROOM_HEIGHT + 2, -25),
	Vector3.new(15, -ROOM_HEIGHT + 2, -25),
}

for i, pos in patrolPositions do
	local pp = createPart({
		name = "PatrolPoint_" .. i,
		size = Vector3.new(1, 1, 1),
		position = pos,
		transparency = 1,
		canCollide = false,
	})
	addTag(pp, Constants.TAG_PATROL_POINT)
end

-- ==========================================
-- STORY NOTES (diary entries)
-- ==========================================

print("[WorldBuilder] Placing story notes...")

local notePositions = {
	{ noteId = 1,  position = Vector3.new(5, 1.5, 3), room = "Entrance" },
	{ noteId = 2,  position = Vector3.new(0, 1.5, -22), room = "Hallway" },
	{ noteId = 3,  position = Vector3.new(-22, 3.5, -15), room = "LivingRoom" },
	{ noteId = 4,  position = Vector3.new(22, 3.5, -25), room = "Kitchen" },
	{ noteId = 5,  position = Vector3.new(-25, 3.5, -22), room = "LivingRoom" },
	{ noteId = 6,  position = Vector3.new(-15, ROOM_HEIGHT + 3.5, -25), room = "Bedroom" },
	{ noteId = 7,  position = Vector3.new(22, ROOM_HEIGHT + 3.5, -18), room = "Bathroom" },
	{ noteId = 8,  position = Vector3.new(18, ROOM_HEIGHT + 3.5, -34), room = "Attic" },
	{ noteId = 9,  position = Vector3.new(-10, -ROOM_HEIGHT + 3.5, -18), room = "Basement" },
	{ noteId = 10, position = Vector3.new(10, -ROOM_HEIGHT + 3.5, -50), room = "BossArena" },
}

for _, noteData in notePositions do
	local note = createPart({
		name = "StoryNote_" .. noteData.noteId,
		size = Vector3.new(1.5, 0.1, 2),
		position = noteData.position,
		canCollide = false,
	})
	note.Material = Enum.Material.SmoothPlastic
	note.Color = Color3.fromRGB(255, 245, 220)
	note:SetAttribute("NoteId", noteData.noteId)
	note:SetAttribute("Room", noteData.room)
	addTag(note, Constants.TAG_STORY_NOTE)
end

-- ==========================================
-- KEYS
-- ==========================================

print("[WorldBuilder] Placing keys...")

local keyData = {
	{ keyId = "upstairs_key", position = Vector3.new(20, 3, -15), room = "Kitchen" },
	{ keyId = "basement_key", position = Vector3.new(-25, 3, -25), room = "LivingRoom" },
	{ keyId = "attic_key", position = Vector3.new(-20, ROOM_HEIGHT + 3, -28), room = "Bedroom" },
	{ keyId = "boss_key", position = Vector3.new(12, -ROOM_HEIGHT + 3, -28), room = "Basement" },
}

for _, kd in keyData do
	local key = createPart({
		name = "Key_" .. kd.keyId,
		size = Vector3.new(0.5, 1.5, 0.2),
		position = kd.position,
		canCollide = false,
	})
	key.Material = Enum.Material.Neon
	key.Color = Color3.fromRGB(255, 215, 0)
	key:SetAttribute("KeyId", kd.keyId)
	key:SetAttribute("Room", kd.room)
	addTag(key, Constants.TAG_KEY)
end

-- ==========================================
-- CAT TREATS
-- ==========================================

print("[WorldBuilder] Placing cat treats...")

local treatRooms = {
	{ room = "Entrance",   positions = { Vector3.new(7, 2, 5), Vector3.new(-7, 2, 5), Vector3.new(0, 2, -3) } },
	{ room = "Hallway",    positions = { Vector3.new(2, 2, -12), Vector3.new(-2, 2, -22) } },
	{ room = "LivingRoom", positions = { Vector3.new(-12, 2, -14), Vector3.new(-24, 2, -14), Vector3.new(-18, 2, -26), Vector3.new(-12, 2, -26), Vector3.new(-28, 2, -20) } },
	{ room = "Kitchen",    positions = { Vector3.new(12, 2, -14), Vector3.new(24, 2, -14), Vector3.new(18, 2, -26), Vector3.new(12, 2, -26), Vector3.new(24, 2, -26) } },
	{ room = "Bedroom",    positions = { Vector3.new(-12, ROOM_HEIGHT + 2, -14), Vector3.new(-24, ROOM_HEIGHT + 2, -14), Vector3.new(-18, ROOM_HEIGHT + 2, -26), Vector3.new(-12, ROOM_HEIGHT + 2, -26), Vector3.new(-28, ROOM_HEIGHT + 2, -20) } },
	{ room = "Bathroom",   positions = { Vector3.new(14, ROOM_HEIGHT + 2, -16), Vector3.new(22, ROOM_HEIGHT + 2, -16), Vector3.new(18, ROOM_HEIGHT + 2, -24) } },
	{ room = "Attic",      positions = { Vector3.new(14, ROOM_HEIGHT + 2, -32), Vector3.new(22, ROOM_HEIGHT + 2, -36) } },
	{ room = "Basement",   positions = { Vector3.new(-15, -ROOM_HEIGHT + 2, -10), Vector3.new(15, -ROOM_HEIGHT + 2, -10), Vector3.new(-15, -ROOM_HEIGHT + 2, -30), Vector3.new(15, -ROOM_HEIGHT + 2, -30), Vector3.new(0, -ROOM_HEIGHT + 2, -20) } },
}

local treatIndex = 0
for _, roomTreats in treatRooms do
	for _, pos in roomTreats.positions do
		treatIndex = treatIndex + 1
		local treat = createPart({
			name = "CatTreat_" .. treatIndex,
			size = Vector3.new(0.8, 1.2, 1.2),
			position = pos,
			canCollide = false,
		})
		treat.Shape = Enum.PartType.Cylinder
		treat.Material = Enum.Material.SmoothPlastic
		treat.Color = Color3.fromRGB(255, 180, 50)
		treat:SetAttribute("Room", roomTreats.room)
		treat:SetAttribute("TreatId", "treat_" .. treatIndex)
		addTag(treat, Constants.TAG_CAT_TREAT)
	end
end

-- ==========================================
-- SECRET PASSAGES
-- ==========================================

print("[WorldBuilder] Creating secret passages...")

local secretPassages = {
	{
		room = "LivingRoom",
		position = Vector3.new(-29.5, 4, -20),
		size = Vector3.new(WALL_THICKNESS, 6, 4),
	},
	{
		room = "Kitchen",
		position = Vector3.new(27.5, 4, -22),
		size = Vector3.new(WALL_THICKNESS, 6, 4),
	},
	{
		room = "Bedroom",
		position = Vector3.new(-29.5, ROOM_HEIGHT + 4, -22),
		size = Vector3.new(WALL_THICKNESS, 6, 4),
	},
	{
		room = "Basement",
		position = Vector3.new(0, -ROOM_HEIGHT + 4, -34.5),
		size = Vector3.new(6, 6, WALL_THICKNESS),
	},
}

for _, sp in secretPassages do
	local passage = createPart({
		name = "SecretPassage_" .. sp.room,
		size = sp.size,
		position = sp.position,
	})
	passage.Material = Enum.Material.Brick
	passage.Color = Color3.fromRGB(100, 70, 50)
	passage:SetAttribute("Room", sp.room)
	addTag(passage, Constants.TAG_SECRET_PASSAGE)
end

-- ==========================================
-- KILL BRICKS (obby section in basement approach)
-- ==========================================

print("[WorldBuilder] Creating obby obstacles...")

local killBrickPositions = {
	-- Path from basement to boss arena has dangerous obstacles
	Vector3.new(-8, -ROOM_HEIGHT + 0.5, -38),
	Vector3.new(0, -ROOM_HEIGHT + 0.5, -40),
	Vector3.new(8, -ROOM_HEIGHT + 0.5, -38),
	Vector3.new(-4, -ROOM_HEIGHT + 0.5, -42),
	Vector3.new(4, -ROOM_HEIGHT + 0.5, -44),
}

for i, pos in killBrickPositions do
	local kb = createPart({
		name = "KillBrick_" .. i,
		size = Vector3.new(4, 0.5, 4),
		position = pos,
	})
	kb.Material = Enum.Material.Neon
	kb.Color = Color3.fromRGB(200, 0, 0)
	kb.Transparency = 0.3
	addTag(kb, Constants.TAG_KILL_BRICK)

	-- Touched handler for kill
	kb.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = 0
		end
	end)
end

-- Safe platforms to jump across
local safePlatformPositions = {
	Vector3.new(-4, -ROOM_HEIGHT + 1.5, -37),
	Vector3.new(4, -ROOM_HEIGHT + 1.5, -39),
	Vector3.new(-2, -ROOM_HEIGHT + 1.5, -41),
	Vector3.new(6, -ROOM_HEIGHT + 1.5, -43),
	Vector3.new(0, -ROOM_HEIGHT + 1.5, -46),
}

for i, pos in safePlatformPositions do
	local plat = createPart({
		name = "SafePlatform_" .. i,
		size = Vector3.new(3, 1, 3),
		position = pos,
	})
	plat.Material = Enum.Material.Neon
	plat.Color = Color3.fromRGB(0, 150, 0)
	plat.Transparency = 0.5
end

-- ==========================================
-- WEAPON PICKUPS (boss area)
-- ==========================================

print("[WorldBuilder] Placing weapon pickups...")

local weaponPositions = {
	Vector3.new(-15, -ROOM_HEIGHT + 3, -48),
	Vector3.new(15, -ROOM_HEIGHT + 3, -48),
}

for i, pos in weaponPositions do
	local wp = createPart({
		name = "WeaponPickup_" .. i,
		size = Vector3.new(2, 2, 2),
		position = pos,
		canCollide = false,
	})
	wp.Shape = Enum.PartType.Ball
	wp.Material = Enum.Material.Neon
	wp.Color = Color3.fromRGB(255, 255, 0)
	addTag(wp, Constants.TAG_WEAPON_PICKUP)
end

-- ==========================================
-- BOSS ARENA TRIGGER
-- ==========================================

print("[WorldBuilder] Creating boss arena trigger...")

local bossTrigger = createPart({
	name = "BossArenaTrigger",
	size = Vector3.new(20, 5, 5),
	position = Vector3.new(0, -ROOM_HEIGHT + 3, -52),
	transparency = 1,
	canCollide = false,
})
addTag(bossTrigger, Constants.TAG_BOSS_ARENA)

-- Crystal decoration in boss room center
local crystal = createPart({
	name = "DarkCrystal",
	size = Vector3.new(3, 6, 3),
	position = Vector3.new(0, -ROOM_HEIGHT + 4, -60),
})
crystal.Material = Enum.Material.Glass
crystal.Color = Color3.fromRGB(40, 0, 60)
crystal.Transparency = 0.3

local crystalLight = addLight(crystal, {
	color = Color3.fromRGB(120, 0, 180),
	brightness = 2,
	range = 20,
	shadows = true,
})
addTag(crystal, Constants.TAG_FLICKER_LIGHT)

-- ==========================================
-- OUTDOOR ENVIRONMENT
-- ==========================================

print("[WorldBuilder] Building outdoor environment...")

-- Ground plane
local ground = createPart({
	name = "Ground",
	size = Vector3.new(200, 1, 200),
	position = Vector3.new(0, -0.5, 0),
})
applyStyle(ground, MATERIALS.GROUND)

-- Fence around yard
local fencePositions = {
	{ pos = Vector3.new(0, 3, 50), size = Vector3.new(100, 6, 1) },   -- North
	{ pos = Vector3.new(0, 3, -100), size = Vector3.new(100, 6, 1) },  -- South
	{ pos = Vector3.new(50, 3, -25), size = Vector3.new(1, 6, 150) },  -- East
	{ pos = Vector3.new(-50, 3, -25), size = Vector3.new(1, 6, 150) }, -- West
}

for _, fd in fencePositions do
	local fence = createPart({
		name = "Fence",
		size = fd.size,
		position = fd.pos,
	})
	applyStyle(fence, MATERIALS.FENCE)

	-- Fence pickets (vertical slats)
	local slotCount = math.floor(math.max(fd.size.X, fd.size.Z) / 3)
	for s = 1, math.min(slotCount, 30) do -- Limit to prevent lag
		local isHorizontal = fd.size.X > fd.size.Z
		local offset
		if isHorizontal then
			offset = Vector3.new(-fd.size.X / 2 + s * 3, 0.5, 0)
		else
			offset = Vector3.new(0, 0.5, -fd.size.Z / 2 + s * 3)
		end

		local picket = createPart({
			name = "FencePicket",
			size = Vector3.new(0.3, 7.5, 0.3),
			position = fd.pos + offset,
		})
		applyStyle(picket, MATERIALS.FENCE)
	end
end

-- Gate (entrance to yard)
local gate = createPart({
	name = "Gate",
	size = Vector3.new(8, 7, 1),
	position = Vector3.new(0, 3.5, 50),
})
gate.Material = Enum.Material.Metal
gate.Color = Color3.fromRGB(40, 40, 40)
addTag(gate, Constants.TAG_DOOR)

-- Trees
local function createTree(position)
	local treeFolder = Instance.new("Folder")
	treeFolder.Name = "Tree"
	treeFolder.Parent = worldFolder

	-- Trunk
	local trunk = createPart({
		name = "Trunk",
		size = Vector3.new(2, 10, 2),
		position = position + Vector3.new(0, 5, 0),
		parent = treeFolder,
	})
	trunk.Material = Enum.Material.Wood
	trunk.Color = Color3.fromRGB(60, 35, 20)

	-- Canopy (dark, dead-looking)
	local canopy = createPart({
		name = "Canopy",
		size = Vector3.new(8, 8, 8),
		position = position + Vector3.new(0, 12, 0),
		parent = treeFolder,
	})
	canopy.Shape = Enum.PartType.Ball
	canopy.Material = Enum.Material.Grass
	canopy.Color = Color3.fromRGB(25, 40, 20) -- Dark, sickly green
	canopy.Transparency = 0.1

	return treeFolder
end

-- Place trees around the house
local treePositions = {
	Vector3.new(35, 0, 30),
	Vector3.new(-35, 0, 30),
	Vector3.new(40, 0, -10),
	Vector3.new(-40, 0, -10),
	Vector3.new(35, 0, -50),
	Vector3.new(-35, 0, -50),
	Vector3.new(30, 0, -80),
	Vector3.new(-30, 0, -80),
	Vector3.new(0, 0, 40),
	Vector3.new(20, 0, 40),
	Vector3.new(-20, 0, 40),
}

for _, pos in treePositions do
	createTree(pos)
end

-- Bushes
local function createBush(position)
	local bush = createPart({
		name = "Bush",
		size = Vector3.new(4, 3, 4),
		position = position + Vector3.new(0, 1.5, 0),
	})
	bush.Shape = Enum.PartType.Ball
	bush.Material = Enum.Material.Grass
	bush.Color = Color3.fromRGB(30, 50, 25)
end

local bushPositions = {
	Vector3.new(12, 0, 8), Vector3.new(-12, 0, 8),
	Vector3.new(8, 0, 12), Vector3.new(-8, 0, 12),
	Vector3.new(15, 0, -5), Vector3.new(-15, 0, -5),
}

for _, pos in bushPositions do
	createBush(pos)
end

-- ==========================================
-- FOG ZONE (outdoor spooky fog)
-- ==========================================

local fogZone = createPart({
	name = "OutdoorFogZone",
	size = Vector3.new(200, 20, 200),
	position = Vector3.new(0, 10, -25),
	transparency = 1,
	canCollide = false,
})
addTag(fogZone, Constants.TAG_FOG_ZONE)

-- ==========================================
-- SPOOKY DECORATIONS
-- ==========================================

print("[WorldBuilder] Adding spooky decorations...")

-- Cobwebs (flat semi-transparent parts in corners)
local cobwebPositions = {
	{ pos = Vector3.new(9, 10, 6), size = Vector3.new(3, 3, 0.1) },
	{ pos = Vector3.new(-9, 10, 6), size = Vector3.new(3, 3, 0.1) },
	{ pos = Vector3.new(-29, 10, -11), size = Vector3.new(3, 0.1, 3) },
	{ pos = Vector3.new(27, 10, -11), size = Vector3.new(3, 0.1, 3) },
	{ pos = Vector3.new(-29, ROOM_HEIGHT + 10, -11), size = Vector3.new(3, 0.1, 3) },
	{ pos = Vector3.new(0, -2, -6), size = Vector3.new(4, 4, 0.1) },
}

for i, cw in cobwebPositions do
	local cobweb = createPart({
		name = "Cobweb_" .. i,
		size = cw.size,
		position = cw.pos,
		transparency = 0.6,
		canCollide = false,
	})
	cobweb.Material = Enum.Material.Fabric
	cobweb.Color = Color3.fromRGB(200, 200, 200)
end

-- Broken mirror in bathroom
if roomFolders["Bathroom"] then
	local mirror = createPart({
		name = "BrokenMirror",
		size = Vector3.new(3, 4, 0.2),
		position = Vector3.new(14, ROOM_HEIGHT + 6, -14.5),
		parent = roomFolders["Bathroom"],
	})
	mirror.Material = Enum.Material.Glass
	mirror.Color = Color3.fromRGB(150, 180, 200)
	mirror.Transparency = 0.3
	mirror.Reflectance = 0.5

	-- Crack lines (thin dark parts overlaid)
	for j = 1, 3 do
		local crack = createPart({
			name = "Crack_" .. j,
			size = Vector3.new(0.1, 2 + j * 0.5, 0.05),
			position = Vector3.new(13.5 + j * 0.5, ROOM_HEIGHT + 5.5 + j * 0.3, -14.4),
			canCollide = false,
			parent = roomFolders["Bathroom"],
		})
		crack.Material = Enum.Material.Metal
		crack.Color = Color3.fromRGB(30, 30, 30)
		crack.CFrame = crack.CFrame * CFrame.Angles(0, 0, math.rad(15 * j - 30))
	end
end

-- ==========================================
-- ADDITIONAL ROOM LIGHTS
-- ==========================================

-- Extra wall sconces / candles for atmosphere
local extraLightPositions = {
	{ pos = Vector3.new(0, 8, -10), room = "Hallway", flicker = true },
	{ pos = Vector3.new(0, 8, -25), room = "Hallway", flicker = true },
	{ pos = Vector3.new(-18, 8, -12), room = "LivingRoom", flicker = false },
	{ pos = Vector3.new(18, 8, -12), room = "Kitchen", flicker = false },
	{ pos = Vector3.new(0, -ROOM_HEIGHT + 10, -20), room = "Basement", flicker = true },
	{ pos = Vector3.new(0, -ROOM_HEIGHT + 10, -55), room = "BossArena", flicker = true },
}

for i, ld in extraLightPositions do
	local sconce = createPart({
		name = "WallSconce_" .. i,
		size = Vector3.new(0.5, 0.8, 0.5),
		position = ld.pos,
		canCollide = false,
	})
	sconce.Material = Enum.Material.Neon
	sconce.Color = Color3.fromRGB(255, 180, 80)
	sconce.Transparency = 0.5

	addLight(sconce, {
		color = Color3.fromRGB(255, 150, 50),
		brightness = 0.4,
		range = 12,
	})

	if ld.flicker then
		addTag(sconce, Constants.TAG_FLICKER_LIGHT)
	end
end

-- ==========================================
-- MARK WORLD AS SET UP
-- ==========================================

local setupFlag = Instance.new("BoolValue")
setupFlag.Name = "WorldSetup"
setupFlag.Value = true
setupFlag.Parent = ServerStorage

-- Print summary
print("[WorldBuilder] ============================================")
print("[WorldBuilder] WORLD GENERATION COMPLETE!")
print("[WorldBuilder] ============================================")
print("[WorldBuilder] Rooms built:", #rooms)
print("[WorldBuilder] Checkpoints:", #checkpoints)
print("[WorldBuilder] Patrol points:", #patrolPositions)
print("[WorldBuilder] Story notes:", #notePositions)
print("[WorldBuilder] Keys:", #keyData)
print("[WorldBuilder] Cat treats:", treatIndex)
print("[WorldBuilder] Kill bricks:", #killBrickPositions)
print("[WorldBuilder] Weapon pickups:", #weaponPositions)
print("[WorldBuilder] Trees:", #treePositions)
print("[WorldBuilder] The game world is ready to play!")
print("[WorldBuilder] ============================================")

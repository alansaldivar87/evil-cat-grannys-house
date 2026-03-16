--[[
	WorldBuilder - Generates Evil Cat Granny's Mansion
	A massive multi-floor horror mansion with:
	  - Basement (4 rooms): Boiler Room, Storage, Wine Cellar, Secret Lab
	  - Ground Floor (6 rooms): Grand Foyer, Kitchen, Dining Room, Living Room, Library, Hallways
	  - Second Floor (5 rooms): Master Bedroom, Children's Room, Bathroom, Study, Long Hallway
	  - Rooftop: Open-air boss arena with pillars and weapon pickups
	  - Elevators between floors (MovingPlatform with vertical movement)
	  - Obby sections, kill bricks, disappearing platforms
	  - 2 Evil Cats patrolling the mansion
	  - Full connectivity: every room reachable via doorway gaps in walls
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

local WALL_THICKNESS = 1.5
local WALL_HEIGHT = 14
local FLOOR_THICKNESS = 1.5
local ROOM_HEIGHT = WALL_HEIGHT
local DOOR_WIDTH = 6
local DOOR_HEIGHT = 10

-- Floor Y positions
local BASEMENT_Y = -ROOM_HEIGHT - FLOOR_THICKNESS
local GROUND_Y = 0
local SECOND_Y = ROOM_HEIGHT + FLOOR_THICKNESS
local ROOF_Y = 2 * (ROOM_HEIGHT + FLOOR_THICKNESS)

-- Materials and colors
local MATERIALS = {
	FLOOR_WOOD = { material = Enum.Material.Wood, color = Color3.fromRGB(101, 67, 33) },
	FLOOR_TILE = { material = Enum.Material.Marble, color = Color3.fromRGB(200, 200, 210) },
	FLOOR_STONE = { material = Enum.Material.Slate, color = Color3.fromRGB(80, 80, 90) },
	FLOOR_CARPET = { material = Enum.Material.Fabric, color = Color3.fromRGB(100, 30, 30) },
	FLOOR_MARBLE = { material = Enum.Material.Marble, color = Color3.fromRGB(220, 210, 200) },
	FLOOR_CONCRETE = { material = Enum.Material.Concrete, color = Color3.fromRGB(120, 115, 110) },
	WALL_BRICK = { material = Enum.Material.Brick, color = Color3.fromRGB(120, 80, 60) },
	WALL_PLASTER = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(160, 150, 140) },
	WALL_DARK = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(60, 55, 50) },
	WALL_BASEMENT = { material = Enum.Material.Concrete, color = Color3.fromRGB(90, 85, 80) },
	WALL_FANCY = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(140, 120, 100) },
	WALL_TILE = { material = Enum.Material.Marble, color = Color3.fromRGB(210, 210, 220) },
	CEILING = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(140, 135, 130) },
	ROOF = { material = Enum.Material.Slate, color = Color3.fromRGB(50, 45, 40) },
	GROUND = { material = Enum.Material.Grass, color = Color3.fromRGB(50, 80, 40) },
	FENCE = { material = Enum.Material.Wood, color = Color3.fromRGB(60, 40, 25) },
	DOOR = { material = Enum.Material.Wood, color = Color3.fromRGB(80, 50, 30) },
	METAL = { material = Enum.Material.Metal, color = Color3.fromRGB(100, 100, 110) },
	CARPET_RED = { material = Enum.Material.Fabric, color = Color3.fromRGB(120, 20, 20) },
	CARPET_PURPLE = { material = Enum.Material.Fabric, color = Color3.fromRGB(60, 20, 80) },
}

-- World container
local worldFolder = Instance.new("Folder")
worldFolder.Name = "HorrorHouse"
worldFolder.Parent = workspace

-- ==========================================
-- PART CREATION HELPERS
-- ==========================================

local function createPart(props)
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

local function applyStyle(part, style)
	part.Material = style.material
	part.Color = style.color
end

local function addLight(parent, props)
	local light = Instance.new("PointLight")
	light.Color = props.color or Color3.fromRGB(255, 200, 150)
	light.Brightness = props.brightness or 0.5
	light.Range = props.range or 15
	light.Shadows = props.shadows or false
	light.Parent = parent
	return light
end

local function addTag(part, tag)
	CollectionService:AddTag(part, tag)
end

-- ==========================================
-- WALL BUILDER WITH DOORWAY GAPS
-- ==========================================
-- Builds a wall segment with one or more doorway gaps cut into it.
-- gaps is an array of {offset, width, height} where offset is from center of wall along its length.
-- axis = "X" means the wall extends along X (north/south wall), "Z" means along Z (east/west wall).

local function buildWallWithGaps(props)
	local folder = props.parent or worldFolder
	local wallStyle = props.wallStyle or MATERIALS.WALL_PLASTER
	local ox, oy, oz = props.position.X, props.position.Y, props.position.Z
	local totalLength = props.length
	local wallHeight = props.height or WALL_HEIGHT
	local axis = props.axis or "X" -- "X" = wall runs along X axis, "Z" = wall runs along Z
	local gaps = props.gaps or {}

	-- Sort gaps by offset
	table.sort(gaps, function(a, b) return a.offset < b.offset end)

	-- Build wall segments around the gaps
	-- Convert gap offsets to absolute positions along the wall
	-- The wall extends from -totalLength/2 to +totalLength/2 relative to center
	local segments = {}
	local currentStart = -totalLength / 2

	for _, gap in ipairs(gaps) do
		local gapCenter = gap.offset
		local gapHalfW = (gap.width or DOOR_WIDTH) / 2
		local gapH = gap.height or DOOR_HEIGHT
		local gapLeft = gapCenter - gapHalfW
		local gapRight = gapCenter + gapHalfW

		-- Segment before the gap (full height)
		if gapLeft > currentStart + 0.1 then
			local segLen = gapLeft - currentStart
			local segCenter = currentStart + segLen / 2
			table.insert(segments, {
				center = segCenter,
				length = segLen,
				height = wallHeight,
				yOffset = wallHeight / 2,
			})
		end

		-- Segment above the gap (lintel)
		local lintelH = wallHeight - gapH
		if lintelH > 0.1 then
			table.insert(segments, {
				center = gapCenter,
				length = gap.width or DOOR_WIDTH,
				height = lintelH,
				yOffset = gapH + lintelH / 2,
			})
		end

		currentStart = gapRight
	end

	-- Final segment after last gap
	local wallEnd = totalLength / 2
	if wallEnd > currentStart + 0.1 then
		local segLen = wallEnd - currentStart
		local segCenter = currentStart + segLen / 2
		table.insert(segments, {
			center = segCenter,
			length = segLen,
			height = wallHeight,
			yOffset = wallHeight / 2,
		})
	end

	local parts = {}
	for i, seg in ipairs(segments) do
		local size, position
		if axis == "X" then
			size = Vector3.new(seg.length, seg.height, WALL_THICKNESS)
			position = Vector3.new(ox + seg.center, oy + seg.yOffset, oz)
		else
			size = Vector3.new(WALL_THICKNESS, seg.height, seg.length)
			position = Vector3.new(ox, oy + seg.yOffset, oz + seg.center)
		end

		local part = createPart({
			name = props.name or "Wall",
			size = size,
			position = position,
			parent = folder,
		})
		applyStyle(part, wallStyle)
		table.insert(parts, part)
	end

	return parts
end

-- Place a door part inside a doorway gap
local function placeDoor(props)
	local folder = props.parent or worldFolder
	local ox, oy, oz = props.position.X, props.position.Y, props.position.Z
	local axis = props.axis or "X"

	local size
	if axis == "X" then
		size = Vector3.new(props.width or DOOR_WIDTH, props.height or DOOR_HEIGHT, WALL_THICKNESS)
	else
		size = Vector3.new(WALL_THICKNESS, props.height or DOOR_HEIGHT, props.width or DOOR_WIDTH)
	end

	local door = createPart({
		name = props.name or "Door",
		size = size,
		position = Vector3.new(ox, oy + (props.height or DOOR_HEIGHT) / 2, oz),
		parent = folder,
	})
	applyStyle(door, MATERIALS.DOOR)
	addTag(door, Constants.TAG_DOOR)

	if props.locked then
		addTag(door, Constants.TAG_LOCKED_DOOR)
		door:SetAttribute("KeyId", props.keyId or "default")
	end

	return door
end

-- ==========================================
-- ROOM BUILDER
-- ==========================================

local roomFolders = {}

-- Build a room: floor, ceiling (optional), 4 walls with optional gaps for doorways
-- doorways is a table: { north = {{offset=0, width=6, height=10}}, south = {}, east = {}, west = {} }
local function buildRoom(def)
	local folder = Instance.new("Folder")
	folder.Name = def.name
	folder.Parent = worldFolder
	roomFolders[def.name] = folder

	local ox, oy, oz = def.origin.X, def.origin.Y, def.origin.Z
	local sx, sy, sz = def.size.X, def.size.Y, def.size.Z
	local doorways = def.doorways or {}

	-- Floor
	local floor = createPart({
		name = "Floor",
		size = Vector3.new(sx, FLOOR_THICKNESS, sz),
		position = Vector3.new(ox, oy, oz),
		parent = folder,
	})
	applyStyle(floor, def.floorStyle or MATERIALS.FLOOR_WOOD)
	addTag(floor, Constants.TAG_ROOM)
	floor:SetAttribute("RoomName", def.name)
	floor:SetAttribute("Room", def.name)

	-- Ceiling (unless noCeiling)
	if not def.noCeiling then
		local ceiling = createPart({
			name = "Ceiling",
			size = Vector3.new(sx, FLOOR_THICKNESS, sz),
			position = Vector3.new(ox, oy + sy, oz),
			parent = folder,
		})
		applyStyle(ceiling, def.ceilingStyle or MATERIALS.CEILING)
	end

	-- North wall (+Z side)
	buildWallWithGaps({
		name = "WallNorth",
		position = Vector3.new(ox, oy, oz + sz / 2),
		length = sx,
		height = sy,
		axis = "X",
		gaps = doorways.north or {},
		wallStyle = def.wallStyle or MATERIALS.WALL_PLASTER,
		parent = folder,
	})

	-- South wall (-Z side)
	buildWallWithGaps({
		name = "WallSouth",
		position = Vector3.new(ox, oy, oz - sz / 2),
		length = sx,
		height = sy,
		axis = "X",
		gaps = doorways.south or {},
		wallStyle = def.wallStyle or MATERIALS.WALL_PLASTER,
		parent = folder,
	})

	-- East wall (+X side)
	buildWallWithGaps({
		name = "WallEast",
		position = Vector3.new(ox + sx / 2, oy, oz),
		length = sz,
		height = sy,
		axis = "Z",
		gaps = doorways.east or {},
		wallStyle = def.wallStyle or MATERIALS.WALL_PLASTER,
		parent = folder,
	})

	-- West wall (-X side)
	buildWallWithGaps({
		name = "WallWest",
		position = Vector3.new(ox - sx / 2, oy, oz),
		length = sz,
		height = sy,
		axis = "Z",
		gaps = doorways.west or {},
		wallStyle = def.wallStyle or MATERIALS.WALL_PLASTER,
		parent = folder,
	})

	-- Room light
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

	local brightness = def.brightness or 0.5
	local range = math.max(sx, sz) * 0.9

	addLight(lightPart, {
		color = def.lightColor or Color3.fromRGB(255, 200, 150),
		brightness = brightness,
		range = range,
	})

	if def.flickerLight then
		addTag(lightPart, Constants.TAG_FLICKER_LIGHT)
	end

	if def.fogZone then
		local fog = createPart({
			name = "FogZone_" .. def.name,
			size = Vector3.new(sx, sy, sz),
			position = Vector3.new(ox, oy + sy / 2, oz),
			transparency = 1,
			canCollide = false,
			parent = folder,
		})
		addTag(fog, Constants.TAG_FOG_ZONE)
	end

	return folder
end

-- ==========================================
-- MANSION LAYOUT COORDINATE SYSTEM
-- ==========================================
-- The mansion is centered roughly around X=0, Z=0.
-- Mansion footprint: about 120 x 100 studs.
-- Ground floor: Y = 0
-- Second floor: Y = ROOM_HEIGHT + FLOOR_THICKNESS (~15.5)
-- Basement: Y = -(ROOM_HEIGHT + FLOOR_THICKNESS) (~-15.5)
-- Roof: Y = 2*(ROOM_HEIGHT+FLOOR_THICKNESS) (~31)

-- GROUND FLOOR LAYOUT (Y = 0):
--  +------+----------+------+
--  |Library|  Hallway | Kitchen|
--  |50x40 |  12x40  | 50x40  |
--  +------+----++----+--------+
--              ||
--       +------++------+
--       | Grand Foyer  |
--       |   60x50      |
--       +--------------+
--  +------+----------+------+
--  |Living |  Hallway |Dining |
--  | 50x40|  12x40   |50x40  |
--  +------+----------+-------+

-- Simplified approach: each room has an origin (center-bottom of floor)

local GF = GROUND_Y
local SF = SECOND_Y
local BF = BASEMENT_Y

-- ==========================================
-- DEFINE ALL ROOMS
-- ==========================================

print("[WorldBuilder] Building rooms...")

-- =====================
-- GROUND FLOOR
-- =====================

-- Grand Foyer (center, large)
buildRoom({
	name = "GrandFoyer",
	origin = Vector3.new(0, GF, 0),
	size = Vector3.new(60, ROOM_HEIGHT, 50),
	floorStyle = MATERIALS.FLOOR_MARBLE,
	wallStyle = MATERIALS.WALL_FANCY,
	doorways = {
		north = { { offset = 0, width = 10, height = DOOR_HEIGHT } },  -- Front entrance
		south = { { offset = 0, width = 8, height = DOOR_HEIGHT } },   -- To south hallway
		east = { { offset = 10, width = 6, height = DOOR_HEIGHT } },   -- To kitchen
		west = { { offset = 10, width = 6, height = DOOR_HEIGHT } },   -- To living room
	},
	hasSpawn = true,
	brightness = 0.7,
})

-- Kitchen (east of foyer)
buildRoom({
	name = "Kitchen",
	origin = Vector3.new(55, GF, 10),
	size = Vector3.new(50, ROOM_HEIGHT, 40),
	floorStyle = MATERIALS.FLOOR_TILE,
	wallStyle = MATERIALS.WALL_PLASTER,
	doorways = {
		west = { { offset = 0, width = 6, height = DOOR_HEIGHT } },   -- To foyer
		south = { { offset = -10, width = 6, height = DOOR_HEIGHT } }, -- To dining room
	},
	brightness = 0.6,
})

-- Living Room (west of foyer)
buildRoom({
	name = "LivingRoom",
	origin = Vector3.new(-55, GF, 10),
	size = Vector3.new(50, ROOM_HEIGHT, 40),
	floorStyle = MATERIALS.FLOOR_CARPET,
	wallStyle = MATERIALS.WALL_PLASTER,
	doorways = {
		east = { { offset = 0, width = 6, height = DOOR_HEIGHT } },  -- To foyer
		south = { { offset = 10, width = 6, height = DOOR_HEIGHT } }, -- To library
	},
	brightness = 0.5,
})

-- Dining Room (east, south of kitchen)
buildRoom({
	name = "DiningRoom",
	origin = Vector3.new(55, GF, -35),
	size = Vector3.new(50, ROOM_HEIGHT, 40),
	floorStyle = MATERIALS.FLOOR_WOOD,
	wallStyle = MATERIALS.WALL_FANCY,
	doorways = {
		north = { { offset = -10, width = 6, height = DOOR_HEIGHT } }, -- To kitchen
		west = { { offset = 0, width = 6, height = DOOR_HEIGHT } },    -- To hallway
	},
	brightness = 0.4,
	flickerLight = true,
})

-- Library (west, south of living room)
buildRoom({
	name = "Library",
	origin = Vector3.new(-55, GF, -35),
	size = Vector3.new(50, ROOM_HEIGHT, 40),
	floorStyle = MATERIALS.FLOOR_CARPET,
	wallStyle = MATERIALS.WALL_DARK,
	doorways = {
		north = { { offset = 10, width = 6, height = DOOR_HEIGHT } }, -- To living room
		east = { { offset = 0, width = 6, height = DOOR_HEIGHT } },   -- To hallway
	},
	brightness = 0.3,
	flickerLight = true,
})

-- Ground Floor South Hallway (connects dining, library, and leads to basement stairs)
buildRoom({
	name = "GroundHallway",
	origin = Vector3.new(0, GF, -35),
	size = Vector3.new(50, ROOM_HEIGHT, 40),
	floorStyle = MATERIALS.FLOOR_WOOD,
	wallStyle = MATERIALS.WALL_DARK,
	doorways = {
		north = { { offset = 0, width = 8, height = DOOR_HEIGHT } }, -- From foyer
		east = { { offset = 0, width = 6, height = DOOR_HEIGHT } },  -- To dining
		west = { { offset = 0, width = 6, height = DOOR_HEIGHT } },  -- To library
		south = { { offset = -10, width = 6, height = DOOR_HEIGHT } }, -- To basement stairs area
	},
	flickerLight = true,
	brightness = 0.3,
})

print("[WorldBuilder]   Built: Ground Floor (6 rooms)")

-- =====================
-- SECOND FLOOR
-- =====================

-- Master Bedroom (above foyer, center-west)
buildRoom({
	name = "MasterBedroom",
	origin = Vector3.new(-25, SF, 0),
	size = Vector3.new(50, ROOM_HEIGHT, 45),
	floorStyle = MATERIALS.CARPET_RED,
	wallStyle = MATERIALS.WALL_DARK,
	doorways = {
		east = { { offset = 5, width = 6, height = DOOR_HEIGHT } }, -- To second floor hallway
	},
	brightness = 0.3,
	flickerLight = true,
})

-- Children's Room (above kitchen area)
buildRoom({
	name = "ChildrensRoom",
	origin = Vector3.new(50, SF, 0),
	size = Vector3.new(40, ROOM_HEIGHT, 40),
	floorStyle = MATERIALS.FLOOR_CARPET,
	wallStyle = MATERIALS.WALL_PLASTER,
	doorways = {
		west = { { offset = 5, width = 6, height = DOOR_HEIGHT } }, -- To hallway
	},
	brightness = 0.4,
	flickerLight = true,
})

-- Second Floor Hallway (long corridor)
buildRoom({
	name = "SecondHallway",
	origin = Vector3.new(5, SF, -5),
	size = Vector3.new(12, ROOM_HEIGHT, 80),
	floorStyle = MATERIALS.FLOOR_WOOD,
	wallStyle = MATERIALS.WALL_DARK,
	doorways = {
		west = {
			{ offset = 10, width = 6, height = DOOR_HEIGHT },   -- To master bedroom
			{ offset = -25, width = 6, height = DOOR_HEIGHT },  -- To study
		},
		east = {
			{ offset = 10, width = 6, height = DOOR_HEIGHT },   -- To children's room
			{ offset = -15, width = 6, height = DOOR_HEIGHT },  -- To bathroom
		},
		south = { { offset = 0, width = 6, height = DOOR_HEIGHT } }, -- Dead end / window
	},
	flickerLight = true,
	brightness = 0.25,
})

-- Bathroom (east side, south area)
buildRoom({
	name = "Bathroom",
	origin = Vector3.new(45, SF, -25),
	size = Vector3.new(40, ROOM_HEIGHT, 30),
	floorStyle = MATERIALS.FLOOR_TILE,
	wallStyle = MATERIALS.WALL_TILE,
	doorways = {
		west = { { offset = 5, width = 6, height = DOOR_HEIGHT } }, -- To hallway
	},
	brightness = 0.5,
})

-- Study (west side, south area)
buildRoom({
	name = "Study",
	origin = Vector3.new(-30, SF, -35),
	size = Vector3.new(40, ROOM_HEIGHT, 40),
	floorStyle = MATERIALS.FLOOR_WOOD,
	wallStyle = MATERIALS.WALL_DARK,
	doorways = {
		east = { { offset = 5, width = 6, height = DOOR_HEIGHT } }, -- To hallway
	},
	brightness = 0.3,
	flickerLight = true,
})

print("[WorldBuilder]   Built: Second Floor (5 rooms)")

-- =====================
-- BASEMENT
-- =====================

-- Boiler Room (north-west basement)
buildRoom({
	name = "BoilerRoom",
	origin = Vector3.new(-30, BF, 0),
	size = Vector3.new(40, ROOM_HEIGHT, 40),
	floorStyle = MATERIALS.FLOOR_CONCRETE,
	wallStyle = MATERIALS.WALL_BASEMENT,
	doorways = {
		east = { { offset = 5, width = 6, height = DOOR_HEIGHT } }, -- To basement hallway
	},
	brightness = 0.15,
	flickerLight = true,
	fogZone = true,
	lightColor = Color3.fromRGB(255, 100, 50),
})

-- Storage Room (north-east basement)
buildRoom({
	name = "StorageRoom",
	origin = Vector3.new(30, BF, 0),
	size = Vector3.new(40, ROOM_HEIGHT, 40),
	floorStyle = MATERIALS.FLOOR_STONE,
	wallStyle = MATERIALS.WALL_BASEMENT,
	doorways = {
		west = { { offset = 5, width = 6, height = DOOR_HEIGHT } }, -- To basement hallway
	},
	brightness = 0.2,
	flickerLight = true,
})

-- Basement Center Hallway
buildRoom({
	name = "BasementHallway",
	origin = Vector3.new(0, BF, 0),
	size = Vector3.new(20, ROOM_HEIGHT, 80),
	floorStyle = MATERIALS.FLOOR_STONE,
	wallStyle = MATERIALS.WALL_BASEMENT,
	doorways = {
		north = { { offset = 0, width = 6, height = DOOR_HEIGHT } }, -- Stairs from ground
		west = {
			{ offset = 20, width = 6, height = DOOR_HEIGHT },  -- Boiler room
			{ offset = -15, width = 6, height = DOOR_HEIGHT },  -- Wine cellar
		},
		east = {
			{ offset = 20, width = 6, height = DOOR_HEIGHT },  -- Storage room
			{ offset = -15, width = 6, height = DOOR_HEIGHT },  -- Secret lab
		},
		south = { { offset = 0, width = 6, height = DOOR_HEIGHT } }, -- Obby exit
	},
	brightness = 0.15,
	flickerLight = true,
	fogZone = true,
})

-- Wine Cellar (south-west basement)
buildRoom({
	name = "WineCellar",
	origin = Vector3.new(-30, BF, -40),
	size = Vector3.new(40, ROOM_HEIGHT, 40),
	floorStyle = MATERIALS.FLOOR_STONE,
	wallStyle = MATERIALS.WALL_DARK,
	doorways = {
		east = { { offset = 5, width = 6, height = DOOR_HEIGHT } },
	},
	brightness = 0.2,
	flickerLight = true,
})

-- Secret Lab (south-east basement, locked)
buildRoom({
	name = "SecretLab",
	origin = Vector3.new(30, BF, -40),
	size = Vector3.new(40, ROOM_HEIGHT, 40),
	floorStyle = MATERIALS.FLOOR_TILE,
	wallStyle = MATERIALS.WALL_DARK,
	doorways = {
		west = { { offset = 5, width = 6, height = DOOR_HEIGHT } },
	},
	brightness = 0.25,
	flickerLight = true,
	lightColor = Color3.fromRGB(100, 0, 180),
})

print("[WorldBuilder]   Built: Basement (5 rooms)")

-- =====================
-- ROOFTOP BOSS ARENA
-- =====================

buildRoom({
	name = "Rooftop",
	origin = Vector3.new(0, ROOF_Y, -10),
	size = Vector3.new(80, 16, 80),
	floorStyle = MATERIALS.FLOOR_STONE,
	wallStyle = MATERIALS.WALL_BRICK,
	noCeiling = true, -- Open to the sky
	doorways = {
		south = { { offset = 0, width = 8, height = DOOR_HEIGHT } }, -- Elevator arrival
	},
	brightness = 0.6,
	lightColor = Color3.fromRGB(200, 50, 50),
})

print("[WorldBuilder]   Built: Rooftop Boss Arena")

-- ==========================================
-- DOORS IN DOORWAY GAPS
-- ==========================================

print("[WorldBuilder] Placing doors in doorway gaps...")

-- Ground Floor doors
-- Front entrance (Foyer north wall)
placeDoor({
	name = "FrontDoor",
	position = Vector3.new(0, GF, 25),
	axis = "X",
	parent = roomFolders["GrandFoyer"],
})

-- Foyer to Kitchen (foyer east wall)
placeDoor({
	name = "Door_FoyerToKitchen",
	position = Vector3.new(30, GF, 10),
	axis = "Z",
	parent = roomFolders["GrandFoyer"],
})

-- Foyer to Living Room (foyer west wall)
placeDoor({
	name = "Door_FoyerToLiving",
	position = Vector3.new(-30, GF, 10),
	axis = "Z",
	parent = roomFolders["GrandFoyer"],
})

-- Foyer to South Hallway
placeDoor({
	name = "Door_FoyerToHallway",
	position = Vector3.new(0, GF, -25),
	axis = "X",
	width = 8,
	parent = roomFolders["GrandFoyer"],
})

-- Kitchen to Dining
placeDoor({
	name = "Door_KitchenToDining",
	position = Vector3.new(45, GF, -10),
	axis = "X",
	parent = roomFolders["Kitchen"],
})

-- Living Room to Library
placeDoor({
	name = "Door_LivingToLibrary",
	position = Vector3.new(-45, GF, -10),
	axis = "X",
	parent = roomFolders["LivingRoom"],
})

-- Hallway to Dining Room
placeDoor({
	name = "Door_HallwayToDining",
	position = Vector3.new(25, GF, -35),
	axis = "Z",
	parent = roomFolders["GroundHallway"],
})

-- Hallway to Library
placeDoor({
	name = "Door_HallwayToLibrary",
	position = Vector3.new(-25, GF, -35),
	axis = "Z",
	parent = roomFolders["GroundHallway"],
})

-- Second Floor doors
-- Master Bedroom to Hallway
placeDoor({
	name = "Door_MasterToHallway",
	position = Vector3.new(0, SF, 5),
	axis = "Z",
	parent = roomFolders["MasterBedroom"],
})

-- Children's Room to Hallway
placeDoor({
	name = "Door_ChildrenToHallway",
	position = Vector3.new(30, SF, 5),
	axis = "Z",
	parent = roomFolders["ChildrensRoom"],
})

-- Bathroom to Hallway
placeDoor({
	name = "Door_BathroomToHallway",
	position = Vector3.new(25, SF, -15),
	axis = "Z",
	parent = roomFolders["Bathroom"],
})

-- Study to Hallway (locked - need study key)
placeDoor({
	name = "Door_StudyToHallway",
	position = Vector3.new(-10, SF, -30),
	axis = "Z",
	parent = roomFolders["Study"],
	locked = true,
	keyId = "study_key",
})

-- Basement doors
-- Boiler Room
placeDoor({
	name = "Door_BoilerToHallway",
	position = Vector3.new(-10, BF, 5),
	axis = "Z",
	parent = roomFolders["BoilerRoom"],
})

-- Storage Room
placeDoor({
	name = "Door_StorageToHallway",
	position = Vector3.new(10, BF, 5),
	axis = "Z",
	parent = roomFolders["StorageRoom"],
})

-- Wine Cellar
placeDoor({
	name = "Door_WineCellarToHallway",
	position = Vector3.new(-10, BF, -35),
	axis = "Z",
	parent = roomFolders["WineCellar"],
})

-- Secret Lab (locked)
placeDoor({
	name = "Door_SecretLabToHallway",
	position = Vector3.new(10, BF, -35),
	axis = "Z",
	parent = roomFolders["SecretLab"],
	locked = true,
	keyId = "lab_key",
})

-- Basement entry from ground floor (locked)
placeDoor({
	name = "Door_ToBasement",
	position = Vector3.new(-10, GF, -55),
	axis = "X",
	parent = roomFolders["GroundHallway"],
	locked = true,
	keyId = "basement_key",
})

print("[WorldBuilder]   Placed all doors")

-- ==========================================
-- STAIRCASES
-- ==========================================

print("[WorldBuilder] Building staircases...")

local function buildStaircase(startPos, endPos, numSteps, width, parent)
	local stairFolder = Instance.new("Folder")
	stairFolder.Name = "Staircase"
	stairFolder.Parent = parent or worldFolder

	local dx = (endPos.X - startPos.X) / numSteps
	local dy = (endPos.Y - startPos.Y) / numSteps
	local dz = (endPos.Z - startPos.Z) / numSteps
	local w = width or 6

	for i = 0, numSteps - 1 do
		local step = createPart({
			name = "Step_" .. i,
			size = Vector3.new(w, 1, 2.5),
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

-- Grand staircase in foyer going up to second floor
buildStaircase(
	Vector3.new(-20, GF + 1, -15),
	Vector3.new(-20, SF + 1, -5),
	14,
	8,
	roomFolders["GrandFoyer"]
)

-- Secondary staircase on the right side
buildStaircase(
	Vector3.new(20, GF + 1, -15),
	Vector3.new(20, SF + 1, -5),
	14,
	8,
	roomFolders["GrandFoyer"]
)

-- Stairs down to basement from ground hallway
buildStaircase(
	Vector3.new(-10, GF, -45),
	Vector3.new(-10, BF + 1, -35),
	14,
	6,
	roomFolders["GroundHallway"]
)

print("[WorldBuilder]   Built staircases")

-- ==========================================
-- ELEVATORS (MovingPlatforms between floors)
-- ==========================================

print("[WorldBuilder] Building elevators...")

local function createElevator(props)
	local elevFolder = Instance.new("Folder")
	elevFolder.Name = "Elevator_" .. (props.name or "Main")
	elevFolder.Parent = worldFolder

	-- Shaft walls (decorative)
	local shaftHeight = props.topY - props.bottomY + ROOM_HEIGHT
	local shaftCenter = (props.topY + props.bottomY) / 2 + ROOM_HEIGHT / 2

	-- Back wall of shaft
	createPart({
		name = "ElevShaftBack",
		size = Vector3.new(8, shaftHeight, 1),
		position = Vector3.new(props.x, shaftCenter, props.z - 4),
		parent = elevFolder,
	}).Color = Color3.fromRGB(60, 60, 70)

	-- Side walls
	for _, side in ipairs({-4, 4}) do
		createPart({
			name = "ElevShaftSide",
			size = Vector3.new(1, shaftHeight, 8),
			position = Vector3.new(props.x + side, shaftCenter, props.z),
			parent = elevFolder,
		}).Color = Color3.fromRGB(60, 60, 70)
	end

	-- The moving platform itself
	local platform = createPart({
		name = "ElevatorPlatform",
		size = Vector3.new(7, 1, 7),
		position = Vector3.new(props.x, props.bottomY + 1, props.z),
		parent = elevFolder,
	})
	platform.Material = Enum.Material.DiamondPlate
	platform.Color = Color3.fromRGB(150, 150, 160)
	addTag(platform, Constants.TAG_MOVING_PLATFORM)
	platform:SetAttribute("MoveDirection", "Y")
	platform:SetAttribute("MoveDistance", props.topY - props.bottomY)
	platform:SetAttribute("MoveSpeed", props.speed or 8)
	platform:SetAttribute("PauseTime", props.pauseTime or 3)

	-- Indicator lights at each floor
	for _, floorY in ipairs(props.stops or {}) do
		local indicator = createPart({
			name = "ElevIndicator",
			size = Vector3.new(1, 1, 0.5),
			position = Vector3.new(props.x + 4.5, floorY + 5, props.z),
			canCollide = false,
			parent = elevFolder,
		})
		indicator.Material = Enum.Material.Neon
		indicator.Color = Color3.fromRGB(0, 255, 100)
	end

	return elevFolder
end

-- Main elevator: Basement to Rooftop (all 4 floors)
createElevator({
	name = "Main",
	x = 25,
	z = -20,
	bottomY = BF,
	topY = ROOF_Y,
	speed = 6,
	pauseTime = 4,
	stops = { BF, GF, SF, ROOF_Y },
})

-- Service elevator: Basement to Second Floor
createElevator({
	name = "Service",
	x = -25,
	z = -50,
	bottomY = BF,
	topY = SF,
	speed = 8,
	pauseTime = 3,
	stops = { BF, GF, SF },
})

print("[WorldBuilder]   Built 2 elevators")

-- ==========================================
-- SPAWN LOCATION
-- ==========================================

print("[WorldBuilder] Placing spawn...")

local spawn = Instance.new("SpawnLocation")
spawn.Name = "SpawnLocation"
spawn.Size = Vector3.new(8, 1, 8)
spawn.Position = Vector3.new(0, GF + 1, 15)
spawn.Anchored = true
spawn.Material = Enum.Material.Neon
spawn.Color = Color3.fromRGB(0, 200, 100)
spawn.Transparency = 0.5
spawn.CanCollide = true
spawn.Parent = roomFolders["GrandFoyer"]

-- ==========================================
-- FURNITURE: GRAND FOYER
-- ==========================================

print("[WorldBuilder] Placing furniture...")

local function createTable(position, parent, sizeOverride)
	local s = sizeOverride or Vector3.new(6, 0.5, 4)
	local top = createPart({
		name = "Table",
		size = s,
		position = position + Vector3.new(0, 3, 0),
		parent = parent,
	})
	applyStyle(top, MATERIALS.FLOOR_WOOD)

	for _, offset in ipairs({
		Vector3.new(-s.X/2+0.3, 1.5, -s.Z/2+0.3),
		Vector3.new(s.X/2-0.3, 1.5, -s.Z/2+0.3),
		Vector3.new(-s.X/2+0.3, 1.5, s.Z/2-0.3),
		Vector3.new(s.X/2-0.3, 1.5, s.Z/2-0.3),
	}) do
		local leg = createPart({
			name = "TableLeg",
			size = Vector3.new(0.4, 2.5, 0.4),
			position = position + offset,
			parent = parent,
		})
		applyStyle(leg, MATERIALS.FLOOR_WOOD)
	end
end

local function createChair(position, parent)
	local seat = createPart({
		name = "Chair",
		size = Vector3.new(2, 0.3, 2),
		position = position + Vector3.new(0, 2, 0),
		parent = parent,
	})
	applyStyle(seat, MATERIALS.FLOOR_WOOD)

	local back = createPart({
		name = "ChairBack",
		size = Vector3.new(2, 2.5, 0.3),
		position = position + Vector3.new(0, 3.5, -1),
		parent = parent,
	})
	applyStyle(back, MATERIALS.FLOOR_WOOD)
end

local function createBed(position, parent, roomName)
	local mattress = createPart({
		name = "Bed_" .. roomName,
		size = Vector3.new(6, 1, 9),
		position = position + Vector3.new(0, 2.5, 0),
		parent = parent,
	})
	mattress.Material = Enum.Material.Fabric
	mattress.Color = Color3.fromRGB(180, 180, 200)
	addTag(mattress, Constants.TAG_HIDING_SPOT)

	local frame = createPart({
		name = "BedFrame",
		size = Vector3.new(6.5, 2, 9.5),
		position = position + Vector3.new(0, 1, 0),
		parent = parent,
	})
	applyStyle(frame, MATERIALS.FLOOR_WOOD)

	local headboard = createPart({
		name = "Headboard",
		size = Vector3.new(6.5, 4, 0.5),
		position = position + Vector3.new(0, 4, -4.5),
		parent = parent,
	})
	applyStyle(headboard, MATERIALS.FLOOR_WOOD)

	local pillow = createPart({
		name = "Pillow",
		size = Vector3.new(3, 0.6, 2),
		position = position + Vector3.new(0, 3.3, -3),
		parent = parent,
	})
	pillow.Material = Enum.Material.Fabric
	pillow.Color = Color3.fromRGB(220, 220, 230)
end

local function createCloset(position, parent, roomName)
	local closet = createPart({
		name = "Closet_" .. roomName,
		size = Vector3.new(5, 8, 3),
		position = position + Vector3.new(0, 4, 0),
		parent = parent,
	})
	applyStyle(closet, MATERIALS.FLOOR_WOOD)
	closet.Color = Color3.fromRGB(70, 45, 25)
	addTag(closet, Constants.TAG_HIDING_SPOT)
end

local function createBookshelf(position, parent)
	local shelf = createPart({
		name = "Bookshelf",
		size = Vector3.new(5, 8, 2),
		position = position + Vector3.new(0, 4, 0),
		parent = parent,
	})
	applyStyle(shelf, MATERIALS.FLOOR_WOOD)
	shelf.Color = Color3.fromRGB(90, 55, 30)

	local bookColors = {
		Color3.fromRGB(150, 30, 30),
		Color3.fromRGB(30, 80, 30),
		Color3.fromRGB(30, 30, 120),
		Color3.fromRGB(120, 80, 20),
		Color3.fromRGB(80, 20, 80),
	}

	for i = 1, 4 do
		local book = createPart({
			name = "Book",
			size = Vector3.new(4, 1.2, 1.5),
			position = position + Vector3.new(0, 0.5 + i * 1.8, 0),
			parent = parent,
		})
		book.Color = bookColors[((i - 1) % #bookColors) + 1]
		book.Material = Enum.Material.SmoothPlastic
	end
end

local function createKitchenCounter(position, parent, length)
	local counter = createPart({
		name = "Counter",
		size = Vector3.new(length or 10, 3.5, 2.5),
		position = position + Vector3.new(0, 1.75, 0),
		parent = parent,
	})
	counter.Material = Enum.Material.Marble
	counter.Color = Color3.fromRGB(180, 180, 180)
end

local function createCandle(position, parent)
	local candle = createPart({
		name = "Candle",
		size = Vector3.new(0.3, 1.2, 0.3),
		position = position,
		parent = parent,
	})
	candle.Material = Enum.Material.SmoothPlastic
	candle.Color = Color3.fromRGB(230, 220, 180)

	local flame = createPart({
		name = "Flame",
		size = Vector3.new(0.15, 0.4, 0.15),
		position = position + Vector3.new(0, 0.8, 0),
		canCollide = false,
		parent = parent,
	})
	flame.Material = Enum.Material.Neon
	flame.Color = Color3.fromRGB(255, 150, 30)

	addLight(flame, {
		color = Color3.fromRGB(255, 150, 50),
		brightness = 0.6,
		range = 12,
	})
	addTag(flame, Constants.TAG_FLICKER_LIGHT)
end

local function createPainting(position, parent, sizeOverride)
	local sz = sizeOverride or Vector3.new(5, 4, 0.2)
	local painting = createPart({
		name = "Painting",
		size = sz,
		position = position,
		parent = parent,
	})
	painting.Material = Enum.Material.SmoothPlastic
	painting.Color = Color3.fromRGB(40 + math.random(0, 30), 30 + math.random(0, 20), 25 + math.random(0, 15))

	local frame = createPart({
		name = "PaintingFrame",
		size = Vector3.new(sz.X + 0.4, sz.Y + 0.4, 0.1),
		position = position + Vector3.new(0, 0, -0.15),
		parent = parent,
	})
	frame.Material = Enum.Material.Metal
	frame.Color = Color3.fromRGB(100, 80, 30)
end

local function createChandelier(position, parent)
	local base = createPart({
		name = "ChandelierBase",
		size = Vector3.new(4, 1, 4),
		position = position,
		parent = parent,
	})
	base.Material = Enum.Material.Metal
	base.Color = Color3.fromRGB(120, 100, 40)

	for a = 0, 3 do
		local angle = math.rad(a * 90)
		local armPos = position + Vector3.new(math.cos(angle) * 3, -1, math.sin(angle) * 3)
		local arm = createPart({
			name = "ChandelierArm",
			size = Vector3.new(0.3, 2, 0.3),
			position = armPos,
			parent = parent,
		})
		arm.Material = Enum.Material.Metal
		arm.Color = Color3.fromRGB(120, 100, 40)

		local candleFlame = createPart({
			name = "ChandelierFlame",
			size = Vector3.new(0.2, 0.5, 0.2),
			position = armPos + Vector3.new(0, -1.5, 0),
			canCollide = false,
			parent = parent,
		})
		candleFlame.Material = Enum.Material.Neon
		candleFlame.Color = Color3.fromRGB(255, 180, 50)
		addLight(candleFlame, {
			color = Color3.fromRGB(255, 180, 80),
			brightness = 0.8,
			range = 20,
		})
		addTag(candleFlame, Constants.TAG_FLICKER_LIGHT)
	end
end

local function createRug(position, parent, size, color)
	local rug = createPart({
		name = "Rug",
		size = size or Vector3.new(12, 0.1, 8),
		position = position,
		parent = parent,
	})
	rug.Material = Enum.Material.Fabric
	rug.Color = color or Color3.fromRGB(120, 20, 20)
end

-- FOYER furniture
local foyerFolder = roomFolders["GrandFoyer"]
createChandelier(Vector3.new(0, GF + ROOM_HEIGHT - 2, 5), foyerFolder)
createRug(Vector3.new(0, GF + 0.9, 5), foyerFolder, Vector3.new(20, 0.1, 15))
createTable(Vector3.new(0, GF + 0.5, 8), foyerFolder)
createCandle(Vector3.new(0, GF + 4, 8), foyerFolder)
createPainting(Vector3.new(-15, GF + 8, 24.3), foyerFolder, Vector3.new(8, 5, 0.2))
createPainting(Vector3.new(15, GF + 8, 24.3), foyerFolder, Vector3.new(8, 5, 0.2))
-- Grandfather clock
local clock = createPart({
	name = "GrandfatherClock",
	size = Vector3.new(3, 9, 2),
	position = Vector3.new(25, GF + 4.5, 22),
	parent = foyerFolder,
})
applyStyle(clock, MATERIALS.FLOOR_WOOD)
clock.Color = Color3.fromRGB(60, 35, 20)

-- Coat rack
local coatRack = createPart({
	name = "CoatRack",
	size = Vector3.new(1, 7, 1),
	position = Vector3.new(-25, GF + 3.5, 22),
	parent = foyerFolder,
})
applyStyle(coatRack, MATERIALS.FLOOR_WOOD)

-- Grand staircase railings (decorative)
for i = 0, 13 do
	local railL = createPart({
		name = "RailPost",
		size = Vector3.new(0.3, 3, 0.3),
		position = Vector3.new(-17, GF + 1 + i * (ROOM_HEIGHT / 14), -15 + i * (10 / 14)),
		parent = foyerFolder,
	})
	railL.Material = Enum.Material.Wood
	railL.Color = Color3.fromRGB(70, 40, 20)

	local railR = createPart({
		name = "RailPost",
		size = Vector3.new(0.3, 3, 0.3),
		position = Vector3.new(17, GF + 1 + i * (ROOM_HEIGHT / 14), -15 + i * (10 / 14)),
		parent = foyerFolder,
	})
	railR.Material = Enum.Material.Wood
	railR.Color = Color3.fromRGB(70, 40, 20)
end

-- ==========================================
-- FURNITURE: KITCHEN
-- ==========================================

local kitchenFolder = roomFolders["Kitchen"]
createKitchenCounter(Vector3.new(72, GF + 0.5, 20), kitchenFolder, 12)
createKitchenCounter(Vector3.new(72, GF + 0.5, 0), kitchenFolder, 12)
createKitchenCounter(Vector3.new(45, GF + 0.5, 25), kitchenFolder, 8)
createTable(Vector3.new(55, GF + 0.5, 10), kitchenFolder)
createChair(Vector3.new(52, GF + 0.5, 10), kitchenFolder)
createChair(Vector3.new(58, GF + 0.5, 10), kitchenFolder)
createChair(Vector3.new(55, GF + 0.5, 7), kitchenFolder)
createChair(Vector3.new(55, GF + 0.5, 13), kitchenFolder)
createCandle(Vector3.new(55, GF + 4, 10), kitchenFolder)

-- Fridge
local fridge = createPart({
	name = "Fridge",
	size = Vector3.new(4, 8, 3),
	position = Vector3.new(38, GF + 4, 25),
	parent = kitchenFolder,
})
fridge.Material = Enum.Material.Metal
fridge.Color = Color3.fromRGB(200, 200, 210)

-- Oven
local oven = createPart({
	name = "Oven",
	size = Vector3.new(4, 4, 3),
	position = Vector3.new(65, GF + 2, 25),
	parent = kitchenFolder,
})
oven.Material = Enum.Material.Metal
oven.Color = Color3.fromRGB(50, 50, 55)

-- ==========================================
-- FURNITURE: LIVING ROOM
-- ==========================================

local livingFolder = roomFolders["LivingRoom"]
-- Sofa
local sofa = createPart({
	name = "Sofa",
	size = Vector3.new(10, 3, 4),
	position = Vector3.new(-55, GF + 1.5, 20),
	parent = livingFolder,
})
sofa.Material = Enum.Material.Fabric
sofa.Color = Color3.fromRGB(80, 40, 40)
-- Sofa back
createPart({
	name = "SofaBack",
	size = Vector3.new(10, 2, 0.5),
	position = Vector3.new(-55, GF + 3.5, 22),
	parent = livingFolder,
}).Material = Enum.Material.Fabric

createTable(Vector3.new(-55, GF + 0.5, 12), livingFolder)
createCloset(Vector3.new(-73, GF + 0.5, 5), livingFolder, "LivingRoom")
createBookshelf(Vector3.new(-73, GF + 0.5, 15), livingFolder)
createBookshelf(Vector3.new(-73, GF + 0.5, 25), livingFolder)
createPainting(Vector3.new(-55, GF + 8, 29.3), livingFolder)
createCandle(Vector3.new(-60, GF + 4, 12), livingFolder)
createRug(Vector3.new(-55, GF + 0.9, 10), livingFolder, Vector3.new(14, 0.1, 10))

-- Fireplace
local fireplace = createPart({
	name = "Fireplace",
	size = Vector3.new(8, 7, 3),
	position = Vector3.new(-38, GF + 3.5, 28),
	parent = livingFolder,
})
fireplace.Material = Enum.Material.Brick
fireplace.Color = Color3.fromRGB(100, 60, 40)

local fire = createPart({
	name = "Fire",
	size = Vector3.new(4, 3, 1),
	position = Vector3.new(-38, GF + 2, 27),
	canCollide = false,
	parent = livingFolder,
})
fire.Material = Enum.Material.Neon
fire.Color = Color3.fromRGB(255, 100, 20)
addLight(fire, {
	color = Color3.fromRGB(255, 120, 30),
	brightness = 1,
	range = 20,
})
addTag(fire, Constants.TAG_FLICKER_LIGHT)

-- ==========================================
-- FURNITURE: DINING ROOM
-- ==========================================

local diningFolder = roomFolders["DiningRoom"]
-- Long dining table
createTable(Vector3.new(55, GF + 0.5, -35), diningFolder, Vector3.new(12, 0.5, 5))
for i = -2, 2 do
	createChair(Vector3.new(55 + i * 3, GF + 0.5, -31), diningFolder)
	createChair(Vector3.new(55 + i * 3, GF + 0.5, -39), diningFolder)
end
createChandelier(Vector3.new(55, GF + ROOM_HEIGHT - 2, -35), diningFolder)
createRug(Vector3.new(55, GF + 0.9, -35), diningFolder, Vector3.new(16, 0.1, 10))
createCandle(Vector3.new(55, GF + 4, -35), diningFolder)
createPainting(Vector3.new(55, GF + 8, -54.3), diningFolder, Vector3.new(10, 5, 0.2))

-- China cabinet
local cabinet = createPart({
	name = "ChinaCabinet",
	size = Vector3.new(6, 9, 2),
	position = Vector3.new(73, GF + 4.5, -35),
	parent = diningFolder,
})
applyStyle(cabinet, MATERIALS.FLOOR_WOOD)
cabinet.Color = Color3.fromRGB(60, 35, 20)

-- ==========================================
-- FURNITURE: LIBRARY
-- ==========================================

local libraryFolder = roomFolders["Library"]
-- Many bookshelves along walls
for i = 0, 3 do
	createBookshelf(Vector3.new(-73, GF + 0.5, -20 - i * 10), libraryFolder)
	createBookshelf(Vector3.new(-40, GF + 0.5, -20 - i * 10), libraryFolder)
end
createTable(Vector3.new(-55, GF + 0.5, -35), libraryFolder)
createChair(Vector3.new(-52, GF + 0.5, -35), libraryFolder)
createChair(Vector3.new(-58, GF + 0.5, -35), libraryFolder)
createCloset(Vector3.new(-45, GF + 0.5, -50), libraryFolder, "Library")
createCandle(Vector3.new(-55, GF + 4, -35), libraryFolder)
createCandle(Vector3.new(-65, GF + 4, -25), libraryFolder)
createRug(Vector3.new(-55, GF + 0.9, -35), libraryFolder, Vector3.new(10, 0.1, 8), Color3.fromRGB(60, 20, 80))

-- ==========================================
-- FURNITURE: MASTER BEDROOM
-- ==========================================

local masterFolder = roomFolders["MasterBedroom"]
createBed(Vector3.new(-35, SF + 0.5, 10), masterFolder, "MasterBedroom")
createCloset(Vector3.new(-45, SF + 0.5, -10), masterFolder, "MasterBedroom")
createCloset(Vector3.new(-45, SF + 0.5, -5), masterFolder, "MasterBedroom2")
createTable(Vector3.new(-15, SF + 0.5, 10), masterFolder, Vector3.new(4, 0.5, 3))
createCandle(Vector3.new(-15, SF + 4, 10), masterFolder)
createPainting(Vector3.new(-25, SF + 8, 21.7), masterFolder)
createRug(Vector3.new(-25, SF + 0.9, 5), masterFolder, Vector3.new(16, 0.1, 12), Color3.fromRGB(100, 25, 25))

-- Vanity mirror
local vanityTable = createPart({
	name = "VanityTable",
	size = Vector3.new(5, 3, 2),
	position = Vector3.new(-10, SF + 1.5, 18),
	parent = masterFolder,
})
applyStyle(vanityTable, MATERIALS.FLOOR_WOOD)

local vanityMirror = createPart({
	name = "VanityMirror",
	size = Vector3.new(4, 4, 0.2),
	position = Vector3.new(-10, SF + 5, 19),
	parent = masterFolder,
})
vanityMirror.Material = Enum.Material.Glass
vanityMirror.Color = Color3.fromRGB(180, 200, 220)
vanityMirror.Reflectance = 0.4

-- ==========================================
-- FURNITURE: CHILDREN'S ROOM
-- ==========================================

local childFolder = roomFolders["ChildrensRoom"]
createBed(Vector3.new(55, SF + 0.5, 10), childFolder, "ChildrensRoom")
-- Small bed
local smallBed = createPart({
	name = "SmallBed",
	size = Vector3.new(4, 1, 6),
	position = Vector3.new(42, SF + 2, 10),
	parent = childFolder,
})
smallBed.Material = Enum.Material.Fabric
smallBed.Color = Color3.fromRGB(150, 180, 220)
addTag(smallBed, Constants.TAG_HIDING_SPOT)

-- Toy box
local toyBox = createPart({
	name = "ToyBox",
	size = Vector3.new(4, 2, 3),
	position = Vector3.new(60, SF + 1, -5),
	parent = childFolder,
})
toyBox.Material = Enum.Material.Wood
toyBox.Color = Color3.fromRGB(200, 50, 50)

-- Rocking chair
local rockChair = createPart({
	name = "RockingChair",
	size = Vector3.new(3, 4, 3),
	position = Vector3.new(45, SF + 2, -5),
	parent = childFolder,
})
rockChair.Material = Enum.Material.Wood
rockChair.Color = Color3.fromRGB(100, 60, 30)

createCandle(Vector3.new(50, SF + 4, 0), childFolder)

-- ==========================================
-- FURNITURE: BATHROOM
-- ==========================================

local bathroomFolder = roomFolders["Bathroom"]
-- Bathtub
local tub = createPart({
	name = "Bathtub",
	size = Vector3.new(4, 2.5, 8),
	position = Vector3.new(60, SF + 1.25, -20),
	parent = bathroomFolder,
})
tub.Material = Enum.Material.Marble
tub.Color = Color3.fromRGB(220, 220, 230)
addTag(tub, Constants.TAG_HIDING_SPOT)

-- Sink
local sink = createPart({
	name = "Sink",
	size = Vector3.new(3, 3, 2),
	position = Vector3.new(35, SF + 1.5, -12),
	parent = bathroomFolder,
})
sink.Material = Enum.Material.Marble
sink.Color = Color3.fromRGB(230, 230, 240)

-- Broken mirror
local mirror = createPart({
	name = "BrokenMirror",
	size = Vector3.new(4, 5, 0.2),
	position = Vector3.new(35, SF + 6, -10.5),
	parent = bathroomFolder,
})
mirror.Material = Enum.Material.Glass
mirror.Color = Color3.fromRGB(150, 180, 200)
mirror.Reflectance = 0.5
mirror.Transparency = 0.3

for j = 1, 3 do
	local crack = createPart({
		name = "Crack_" .. j,
		size = Vector3.new(0.1, 2 + j * 0.5, 0.05),
		position = Vector3.new(34 + j * 0.5, SF + 5.5 + j * 0.3, -10.3),
		canCollide = false,
		parent = bathroomFolder,
	})
	crack.Material = Enum.Material.Metal
	crack.Color = Color3.fromRGB(30, 30, 30)
	crack.CFrame = crack.CFrame * CFrame.Angles(0, 0, math.rad(15 * j - 30))
end

-- ==========================================
-- FURNITURE: STUDY
-- ==========================================

local studyFolder = roomFolders["Study"]
-- Desk
local desk = createPart({
	name = "Desk",
	size = Vector3.new(8, 3, 4),
	position = Vector3.new(-30, SF + 1.5, -45),
	parent = studyFolder,
})
applyStyle(desk, MATERIALS.FLOOR_WOOD)
desk.Color = Color3.fromRGB(50, 30, 15)

createChair(Vector3.new(-30, SF + 0.5, -40), studyFolder)
createBookshelf(Vector3.new(-45, SF + 0.5, -25), studyFolder)
createBookshelf(Vector3.new(-45, SF + 0.5, -35), studyFolder)
createBookshelf(Vector3.new(-45, SF + 0.5, -45), studyFolder)
createCandle(Vector3.new(-30, SF + 4, -45), studyFolder)
createCandle(Vector3.new(-40, SF + 4, -30), studyFolder)
createCloset(Vector3.new(-18, SF + 0.5, -50), studyFolder, "Study")

-- Globe
local globe = createPart({
	name = "Globe",
	size = Vector3.new(2, 2, 2),
	position = Vector3.new(-22, SF + 4, -45),
	parent = studyFolder,
})
globe.Shape = Enum.PartType.Ball
globe.Material = Enum.Material.SmoothPlastic
globe.Color = Color3.fromRGB(50, 100, 150)

-- ==========================================
-- FURNITURE: SECOND FLOOR HALLWAY
-- ==========================================

local hallway2Folder = roomFolders["SecondHallway"]
-- Paintings along the hallway walls
for i = -3, 3 do
	createPainting(Vector3.new(10.2, SF + 7, -5 + i * 10), hallway2Folder, Vector3.new(0.2, 4, 5))
	createPainting(Vector3.new(-0.2, SF + 7, -5 + i * 10), hallway2Folder, Vector3.new(0.2, 4, 5))
end
-- Runner rug
createRug(Vector3.new(5, SF + 0.9, -5), hallway2Folder, Vector3.new(8, 0.1, 60), Color3.fromRGB(100, 20, 20))

-- ==========================================
-- FURNITURE: BASEMENT ROOMS
-- ==========================================

-- Boiler Room
local boilerFolder = roomFolders["BoilerRoom"]
-- Boiler (big metal cylinder)
local boiler = createPart({
	name = "Boiler",
	size = Vector3.new(6, 8, 6),
	position = Vector3.new(-35, BF + 4, 10),
	parent = boilerFolder,
})
boiler.Shape = Enum.PartType.Cylinder
boiler.Material = Enum.Material.Metal
boiler.Color = Color3.fromRGB(80, 70, 60)
boiler.CFrame = CFrame.new(-35, BF + 4, 10) * CFrame.Angles(0, 0, math.rad(90))

-- Pipes
for i = 1, 4 do
	local pipe = createPart({
		name = "Pipe_" .. i,
		size = Vector3.new(1, 12, 1),
		position = Vector3.new(-25 - i * 3, BF + 6, 5),
		parent = boilerFolder,
	})
	pipe.Material = Enum.Material.Metal
	pipe.Color = Color3.fromRGB(100, 90, 80)
end

createCandle(Vector3.new(-20, BF + 4, -5), boilerFolder)

-- Storage Room
local storageFolder = roomFolders["StorageRoom"]
-- Crates
for i = 1, 5 do
	local crate = createPart({
		name = "Crate_" .. i,
		size = Vector3.new(3 + math.random() * 2, 3 + math.random() * 2, 3 + math.random() * 2),
		position = Vector3.new(25 + math.random(-5, 5), BF + 2 + (i > 3 and 3 or 0), 5 + math.random(-8, 8)),
		parent = storageFolder,
	})
	crate.Material = Enum.Material.Wood
	crate.Color = Color3.fromRGB(120, 80, 40)
end
createCloset(Vector3.new(45, BF + 0.5, 10), storageFolder, "StorageRoom")
createCandle(Vector3.new(30, BF + 4, 0), storageFolder)

-- Wine Cellar
local wineFolder = roomFolders["WineCellar"]
-- Wine racks (bookshelves work visually)
for i = 0, 3 do
	createBookshelf(Vector3.new(-45, BF + 0.5, -30 - i * 6), wineFolder)
	createBookshelf(Vector3.new(-20, BF + 0.5, -30 - i * 6), wineFolder)
end
-- Barrel
for i = 1, 3 do
	local barrel = createPart({
		name = "Barrel_" .. i,
		size = Vector3.new(3, 4, 3),
		position = Vector3.new(-30 - i * 4, BF + 2, -50),
		parent = wineFolder,
	})
	barrel.Shape = Enum.PartType.Cylinder
	barrel.Material = Enum.Material.Wood
	barrel.Color = Color3.fromRGB(90, 55, 30)
	barrel.CFrame = CFrame.new(barrel.Position) * CFrame.Angles(0, 0, math.rad(90))
end
createCandle(Vector3.new(-30, BF + 4, -40), wineFolder)

-- Secret Lab
local labFolder = roomFolders["SecretLab"]
-- Lab tables
createTable(Vector3.new(25, BF + 0.5, -35), labFolder, Vector3.new(8, 0.5, 3))
createTable(Vector3.new(35, BF + 0.5, -45), labFolder, Vector3.new(8, 0.5, 3))

-- Crystal (the main objective in basement)
local crystal = createPart({
	name = "DarkCrystal",
	size = Vector3.new(3, 6, 3),
	position = Vector3.new(30, BF + 4, -40),
	parent = labFolder,
})
crystal.Material = Enum.Material.Glass
crystal.Color = Color3.fromRGB(40, 0, 60)
crystal.Transparency = 0.3
addLight(crystal, {
	color = Color3.fromRGB(120, 0, 180),
	brightness = 2,
	range = 25,
	shadows = true,
})
addTag(crystal, Constants.TAG_FLICKER_LIGHT)

-- Lab equipment (glowing containers)
for i = 1, 3 do
	local container = createPart({
		name = "LabContainer_" .. i,
		size = Vector3.new(1.5, 3, 1.5),
		position = Vector3.new(20 + i * 5, BF + 2, -50),
		parent = labFolder,
	})
	container.Material = Enum.Material.Glass
	container.Color = Color3.fromRGB(0, 150 + i * 30, 50)
	container.Transparency = 0.4
	addLight(container, {
		color = Color3.fromRGB(0, 200, 100),
		brightness = 0.5,
		range = 8,
	})
end

-- ==========================================
-- ROOFTOP BOSS ARENA DETAILS
-- ==========================================

print("[WorldBuilder] Decorating rooftop boss arena...")

local roofFolder = roomFolders["Rooftop"]

-- Pillars for cover (8 pillars in a ring)
for i = 0, 7 do
	local angle = math.rad(i * 45)
	local radius = 28
	local px = math.cos(angle) * radius
	local pz = -10 + math.sin(angle) * radius

	local pillar = createPart({
		name = "Pillar_" .. i,
		size = Vector3.new(4, 14, 4),
		position = Vector3.new(px, ROOF_Y + 7, pz),
		parent = roofFolder,
	})
	pillar.Material = Enum.Material.Brick
	pillar.Color = Color3.fromRGB(90, 80, 70)
end

-- Center pedestal (boss summon point)
local pedestal = createPart({
	name = "BossPedestal",
	size = Vector3.new(8, 2, 8),
	position = Vector3.new(0, ROOF_Y + 1, -10),
	parent = roofFolder,
})
pedestal.Material = Enum.Material.Marble
pedestal.Color = Color3.fromRGB(40, 30, 30)

-- Dramatic lighting - red torches on pillars
for i = 0, 7 do
	local angle = math.rad(i * 45)
	local radius = 28
	local torch = createPart({
		name = "RoofTorch_" .. i,
		size = Vector3.new(0.5, 1.5, 0.5),
		position = Vector3.new(math.cos(angle) * radius, ROOF_Y + 14, -10 + math.sin(angle) * radius),
		canCollide = false,
		parent = roofFolder,
	})
	torch.Material = Enum.Material.Neon
	torch.Color = Color3.fromRGB(255, 50, 20)
	addLight(torch, {
		color = Color3.fromRGB(255, 50, 30),
		brightness = 1.5,
		range = 18,
		shadows = true,
	})
	addTag(torch, Constants.TAG_FLICKER_LIGHT)
end

-- Low wall parapet around rooftop edge
for _, wallDef in ipairs({
	{ pos = Vector3.new(0, ROOF_Y + 2, 30), size = Vector3.new(80, 4, 2) },
	{ pos = Vector3.new(0, ROOF_Y + 2, -50), size = Vector3.new(80, 4, 2) },
	{ pos = Vector3.new(40, ROOF_Y + 2, -10), size = Vector3.new(2, 4, 80) },
	{ pos = Vector3.new(-40, ROOF_Y + 2, -10), size = Vector3.new(2, 4, 80) },
}) do
	local parapet = createPart({
		name = "Parapet",
		size = wallDef.size,
		position = wallDef.pos,
		parent = roofFolder,
	})
	parapet.Material = Enum.Material.Brick
	parapet.Color = Color3.fromRGB(80, 70, 60)
end

-- Boss arena trigger
local bossTrigger = createPart({
	name = "BossArenaTrigger",
	size = Vector3.new(50, 8, 50),
	position = Vector3.new(0, ROOF_Y + 5, -10),
	transparency = 1,
	canCollide = false,
	parent = roofFolder,
})
addTag(bossTrigger, Constants.TAG_BOSS_ARENA)

-- Weapon pickups on rooftop
local roofWeaponPositions = {
	Vector3.new(-30, ROOF_Y + 3, -30),
	Vector3.new(30, ROOF_Y + 3, -30),
	Vector3.new(-30, ROOF_Y + 3, 15),
	Vector3.new(30, ROOF_Y + 3, 15),
}

for i, pos in ipairs(roofWeaponPositions) do
	local wp = createPart({
		name = "WeaponPickup_Roof_" .. i,
		size = Vector3.new(2.5, 2.5, 2.5),
		position = pos,
		canCollide = false,
		parent = roofFolder,
	})
	wp.Shape = Enum.PartType.Ball
	wp.Material = Enum.Material.Neon
	wp.Color = Color3.fromRGB(255, 255, 0)
	addTag(wp, Constants.TAG_WEAPON_PICKUP)
end

-- ==========================================
-- OBBY SECTION (between Ground Hallway and Basement)
-- ==========================================

print("[WorldBuilder] Creating obby sections...")

-- Obby in basement hallway south section
local obbyFolder = Instance.new("Folder")
obbyFolder.Name = "ObbySection"
obbyFolder.Parent = worldFolder

-- Kill bricks (lava floor)
for ix = -2, 2 do
	for iz = 0, 3 do
		local kb = createPart({
			name = "KillBrick_" .. ix .. "_" .. iz,
			size = Vector3.new(4.5, 0.5, 4.5),
			position = Vector3.new(ix * 5, BF + 0.3, -50 - iz * 5),
			parent = obbyFolder,
		})
		kb.Material = Enum.Material.Neon
		kb.Color = Color3.fromRGB(200, 0, 0)
		kb.Transparency = 0.3
		addTag(kb, Constants.TAG_KILL_BRICK)
	end
end

-- Safe jumping platforms over the kill bricks
local safePlatforms = {
	Vector3.new(-5, BF + 2, -50),
	Vector3.new(3, BF + 2, -53),
	Vector3.new(-3, BF + 3, -56),
	Vector3.new(5, BF + 3, -59),
	Vector3.new(-2, BF + 4, -62),
	Vector3.new(4, BF + 4, -65),
	Vector3.new(0, BF + 5, -68),
}

for i, pos in ipairs(safePlatforms) do
	local plat = createPart({
		name = "SafePlatform_" .. i,
		size = Vector3.new(4, 1, 4),
		position = pos,
		parent = obbyFolder,
	})
	plat.Material = Enum.Material.Neon
	plat.Color = Color3.fromRGB(0, 150, 0)
	plat.Transparency = 0.4
end

-- Disappearing platforms in the obby
local disappPlatforms = {
	Vector3.new(0, BF + 2.5, -52),
	Vector3.new(-4, BF + 3.5, -58),
	Vector3.new(2, BF + 4.5, -64),
}

for i, pos in ipairs(disappPlatforms) do
	local dp = createPart({
		name = "DisappearingPlatform_" .. i,
		size = Vector3.new(4, 1, 4),
		position = pos,
		parent = obbyFolder,
	})
	dp.Material = Enum.Material.Neon
	dp.Color = Color3.fromRGB(255, 200, 0)
	dp.Transparency = 0.2
	addTag(dp, Constants.TAG_DISAPPEARING_PLATFORM)
end

-- Moving platform in the obby (horizontal)
local movPlat = createPart({
	name = "MovingPlatform_Obby",
	size = Vector3.new(5, 1, 5),
	position = Vector3.new(0, BF + 3, -55),
	parent = obbyFolder,
})
movPlat.Material = Enum.Material.DiamondPlate
movPlat.Color = Color3.fromRGB(100, 150, 200)
addTag(movPlat, Constants.TAG_MOVING_PLATFORM)
movPlat:SetAttribute("MoveDirection", "X")
movPlat:SetAttribute("MoveDistance", 10)
movPlat:SetAttribute("MoveSpeed", 4)

-- Second obby section between second floor hallway and rooftop access
local obby2Folder = Instance.new("Folder")
obby2Folder.Name = "ObbySection2"
obby2Folder.Parent = worldFolder

-- Vertical climbing obby to reach rooftop elevator
for i = 0, 5 do
	local climbPlat = createPart({
		name = "ClimbPlatform_" .. i,
		size = Vector3.new(5, 1, 5),
		position = Vector3.new(25, SF + 3 + i * 3, -40 + i * 2),
		parent = obby2Folder,
	})
	climbPlat.Material = Enum.Material.DiamondPlate
	climbPlat.Color = Color3.fromRGB(120, 120, 130)

	if i % 2 == 0 then
		addTag(climbPlat, Constants.TAG_MOVING_PLATFORM)
		climbPlat:SetAttribute("MoveDirection", "X")
		climbPlat:SetAttribute("MoveDistance", 6)
		climbPlat:SetAttribute("MoveSpeed", 3)
	end
end

-- ==========================================
-- CHECKPOINTS (15 throughout the mansion)
-- ==========================================

print("[WorldBuilder] Creating checkpoints...")

local checkpoints = {
	{ order = 1,  position = Vector3.new(0, GF + 1.5, 15), name = "FrontDoor" },
	{ order = 2,  position = Vector3.new(0, GF + 1.5, 0), name = "Foyer" },
	{ order = 3,  position = Vector3.new(55, GF + 1.5, 10), name = "Kitchen" },
	{ order = 4,  position = Vector3.new(-55, GF + 1.5, 10), name = "LivingRoom" },
	{ order = 5,  position = Vector3.new(55, GF + 1.5, -35), name = "DiningRoom" },
	{ order = 6,  position = Vector3.new(-55, GF + 1.5, -35), name = "Library" },
	{ order = 7,  position = Vector3.new(0, GF + 1.5, -35), name = "GroundHallway" },
	{ order = 8,  position = Vector3.new(-25, SF + 1.5, 0), name = "MasterBedroom" },
	{ order = 9,  position = Vector3.new(50, SF + 1.5, 0), name = "ChildrensRoom" },
	{ order = 10, position = Vector3.new(45, SF + 1.5, -25), name = "Bathroom" },
	{ order = 11, position = Vector3.new(-30, SF + 1.5, -35), name = "Study" },
	{ order = 12, position = Vector3.new(0, BF + 1.5, 0), name = "BasementHallway" },
	{ order = 13, position = Vector3.new(-30, BF + 1.5, -40), name = "WineCellar" },
	{ order = 14, position = Vector3.new(30, BF + 1.5, -40), name = "SecretLab" },
	{ order = 15, position = Vector3.new(0, ROOF_Y + 1.5, -10), name = "Rooftop" },
}

for _, cp in ipairs(checkpoints) do
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
-- PATROL POINTS (for cat AI)
-- ==========================================

print("[WorldBuilder] Creating patrol points...")

local patrolPositions = {
	-- Ground floor
	Vector3.new(0, GF + 2, 10),
	Vector3.new(0, GF + 2, -10),
	Vector3.new(20, GF + 2, 0),
	Vector3.new(-20, GF + 2, 0),
	Vector3.new(55, GF + 2, 15),
	Vector3.new(55, GF + 2, 0),
	Vector3.new(-55, GF + 2, 15),
	Vector3.new(-55, GF + 2, 0),
	Vector3.new(55, GF + 2, -30),
	Vector3.new(55, GF + 2, -40),
	Vector3.new(-55, GF + 2, -30),
	Vector3.new(-55, GF + 2, -40),
	Vector3.new(0, GF + 2, -30),
	Vector3.new(0, GF + 2, -40),
	-- Second floor
	Vector3.new(-25, SF + 2, 5),
	Vector3.new(-25, SF + 2, -5),
	Vector3.new(50, SF + 2, 5),
	Vector3.new(50, SF + 2, -5),
	Vector3.new(5, SF + 2, 0),
	Vector3.new(5, SF + 2, -20),
	Vector3.new(5, SF + 2, -35),
	Vector3.new(45, SF + 2, -20),
	Vector3.new(-30, SF + 2, -30),
	Vector3.new(-30, SF + 2, -40),
	-- Basement
	Vector3.new(0, BF + 2, 10),
	Vector3.new(0, BF + 2, -10),
	Vector3.new(0, BF + 2, -30),
	Vector3.new(-30, BF + 2, 5),
	Vector3.new(-30, BF + 2, -5),
	Vector3.new(30, BF + 2, 5),
	Vector3.new(30, BF + 2, -5),
	Vector3.new(-30, BF + 2, -35),
	Vector3.new(30, BF + 2, -35),
}

for i, pos in ipairs(patrolPositions) do
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
-- STORY NOTES (10 diary entries)
-- ==========================================

print("[WorldBuilder] Placing story notes...")

local notePositions = {
	{ noteId = 1,  position = Vector3.new(10, GF + 2, 15), room = "GrandFoyer" },
	{ noteId = 2,  position = Vector3.new(60, GF + 4, 5), room = "Kitchen" },
	{ noteId = 3,  position = Vector3.new(-60, GF + 2, 12), room = "LivingRoom" },
	{ noteId = 4,  position = Vector3.new(60, GF + 4, -40), room = "DiningRoom" },
	{ noteId = 5,  position = Vector3.new(-60, GF + 4, -30), room = "Library" },
	{ noteId = 6,  position = Vector3.new(-30, SF + 4, 5), room = "MasterBedroom" },
	{ noteId = 7,  position = Vector3.new(50, SF + 4, -3), room = "ChildrensRoom" },
	{ noteId = 8,  position = Vector3.new(-35, SF + 4, -40), room = "Study" },
	{ noteId = 9,  position = Vector3.new(-25, BF + 4, -5), room = "BoilerRoom" },
	{ noteId = 10, position = Vector3.new(35, BF + 4, -45), room = "SecretLab" },
}

for _, noteData in ipairs(notePositions) do
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
	{ keyId = "basement_key", position = Vector3.new(-65, GF + 3, -30), room = "Library" },
	{ keyId = "study_key", position = Vector3.new(65, GF + 3, -45), room = "DiningRoom" },
	{ keyId = "lab_key", position = Vector3.new(-35, BF + 3, -50), room = "WineCellar" },
	{ keyId = "rooftop_key", position = Vector3.new(35, BF + 3, -35), room = "SecretLab" },
}

for _, kd in ipairs(keyData) do
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
-- CAT TREATS (spread across all rooms)
-- ==========================================

print("[WorldBuilder] Placing cat treats...")

local treatRooms = {
	{ room = "GrandFoyer", positions = {
		Vector3.new(10, GF + 2, 10), Vector3.new(-10, GF + 2, 10), Vector3.new(20, GF + 2, -10),
		Vector3.new(-20, GF + 2, -10), Vector3.new(0, GF + 2, 20),
	}},
	{ room = "Kitchen", positions = {
		Vector3.new(45, GF + 2, 15), Vector3.new(65, GF + 2, 15), Vector3.new(55, GF + 2, 0),
		Vector3.new(45, GF + 2, 25), Vector3.new(65, GF + 2, 5),
	}},
	{ room = "LivingRoom", positions = {
		Vector3.new(-45, GF + 2, 15), Vector3.new(-65, GF + 2, 15), Vector3.new(-55, GF + 2, 0),
		Vector3.new(-45, GF + 2, 25), Vector3.new(-65, GF + 2, 5),
	}},
	{ room = "DiningRoom", positions = {
		Vector3.new(45, GF + 2, -30), Vector3.new(65, GF + 2, -30), Vector3.new(55, GF + 2, -45),
	}},
	{ room = "Library", positions = {
		Vector3.new(-45, GF + 2, -25), Vector3.new(-65, GF + 2, -25), Vector3.new(-55, GF + 2, -45),
		Vector3.new(-45, GF + 2, -45),
	}},
	{ room = "GroundHallway", positions = {
		Vector3.new(5, GF + 2, -25), Vector3.new(-5, GF + 2, -45),
	}},
	{ room = "MasterBedroom", positions = {
		Vector3.new(-30, SF + 2, 15), Vector3.new(-20, SF + 2, -5), Vector3.new(-40, SF + 2, -10),
		Vector3.new(-15, SF + 2, 10),
	}},
	{ room = "ChildrensRoom", positions = {
		Vector3.new(45, SF + 2, 10), Vector3.new(55, SF + 2, -5), Vector3.new(60, SF + 2, 10),
	}},
	{ room = "Bathroom", positions = {
		Vector3.new(40, SF + 2, -20), Vector3.new(55, SF + 2, -30),
	}},
	{ room = "Study", positions = {
		Vector3.new(-25, SF + 2, -30), Vector3.new(-35, SF + 2, -45), Vector3.new(-20, SF + 2, -45),
	}},
	{ room = "BoilerRoom", positions = {
		Vector3.new(-25, BF + 2, 10), Vector3.new(-35, BF + 2, -5),
	}},
	{ room = "StorageRoom", positions = {
		Vector3.new(25, BF + 2, 10), Vector3.new(35, BF + 2, -5), Vector3.new(40, BF + 2, 10),
	}},
	{ room = "WineCellar", positions = {
		Vector3.new(-25, BF + 2, -35), Vector3.new(-40, BF + 2, -45), Vector3.new(-30, BF + 2, -50),
	}},
	{ room = "SecretLab", positions = {
		Vector3.new(25, BF + 2, -35), Vector3.new(40, BF + 2, -45),
	}},
}

local treatIndex = 0
for _, roomTreats in ipairs(treatRooms) do
	for _, pos in ipairs(roomTreats.positions) do
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
		position = Vector3.new(-79.5, GF + 5, 10),
		size = Vector3.new(WALL_THICKNESS, 7, 5),
	},
	{
		room = "Library",
		position = Vector3.new(-79.5, GF + 5, -35),
		size = Vector3.new(WALL_THICKNESS, 7, 5),
	},
	{
		room = "MasterBedroom",
		position = Vector3.new(-49.5, SF + 5, 0),
		size = Vector3.new(WALL_THICKNESS, 7, 5),
	},
	{
		room = "BasementHallway",
		position = Vector3.new(0, BF + 5, -39.5),
		size = Vector3.new(6, 7, WALL_THICKNESS),
	},
}

for _, sp in ipairs(secretPassages) do
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
-- EVIL CATS (2 patrolling cats)
-- ==========================================

print("[WorldBuilder] Spawning evil cats...")

local function createEvilCat(name, position, parent)
	local catModel = Instance.new("Model")
	catModel.Name = name
	catModel.Parent = parent or worldFolder

	-- Body
	local body = createPart({
		name = "HumanoidRootPart",
		size = Vector3.new(3, 2, 4),
		position = position + Vector3.new(0, 1.5, 0),
		parent = catModel,
	})
	body.Material = Enum.Material.Fabric
	body.Color = Color3.fromRGB(50, 50, 50)

	-- Head
	local head = createPart({
		name = "Head",
		size = Vector3.new(2, 2, 2),
		position = position + Vector3.new(0, 3, 2),
		parent = catModel,
	})
	head.Shape = Enum.PartType.Ball
	head.Material = Enum.Material.Fabric
	head.Color = Color3.fromRGB(50, 50, 50)

	-- Eyes (glowing red)
	for _, side in ipairs({-0.5, 0.5}) do
		local eye = createPart({
			name = "Eye",
			size = Vector3.new(0.3, 0.3, 0.3),
			position = position + Vector3.new(side, 3.3, 3),
			canCollide = false,
			parent = catModel,
		})
		eye.Shape = Enum.PartType.Ball
		eye.Material = Enum.Material.Neon
		eye.Color = Color3.fromRGB(255, 0, 0)
		addLight(eye, {
			color = Color3.fromRGB(255, 0, 0),
			brightness = 1,
			range = 5,
		})
	end

	-- Tail
	local tail = createPart({
		name = "Tail",
		size = Vector3.new(0.5, 0.5, 3),
		position = position + Vector3.new(0, 2, -2.5),
		parent = catModel,
	})
	tail.Material = Enum.Material.Fabric
	tail.Color = Color3.fromRGB(50, 50, 50)

	catModel.PrimaryPart = body
	addTag(catModel, Constants.TAG_EVIL_CAT)

	return catModel
end

-- Cat 1: Ground floor patrol
createEvilCat("EvilCat_Ground", Vector3.new(0, GF, -20), worldFolder)

-- Cat 2: Second floor patrol
createEvilCat("EvilCat_SecondFloor", Vector3.new(5, SF, -5), worldFolder)

-- ==========================================
-- OUTDOOR ENVIRONMENT
-- ==========================================

print("[WorldBuilder] Building outdoor environment...")

-- Ground plane
local ground = createPart({
	name = "Ground",
	size = Vector3.new(300, 1, 300),
	position = Vector3.new(0, -0.5, 0),
})
applyStyle(ground, MATERIALS.GROUND)

-- Fence around yard
local fencePositions = {
	{ pos = Vector3.new(0, 3, 80), size = Vector3.new(160, 6, 1) },
	{ pos = Vector3.new(0, 3, -120), size = Vector3.new(160, 6, 1) },
	{ pos = Vector3.new(80, 3, -20), size = Vector3.new(1, 6, 200) },
	{ pos = Vector3.new(-80, 3, -20), size = Vector3.new(1, 6, 200) },
}

for _, fd in ipairs(fencePositions) do
	local fence = createPart({
		name = "Fence",
		size = fd.size,
		position = fd.pos,
	})
	applyStyle(fence, MATERIALS.FENCE)

	local slotCount = math.floor(math.max(fd.size.X, fd.size.Z) / 4)
	for s = 1, math.min(slotCount, 40) do
		local isHorizontal = fd.size.X > fd.size.Z
		local offset
		if isHorizontal then
			offset = Vector3.new(-fd.size.X / 2 + s * 4, 0.5, 0)
		else
			offset = Vector3.new(0, 0.5, -fd.size.Z / 2 + s * 4)
		end
		local picket = createPart({
			name = "FencePicket",
			size = Vector3.new(0.3, 7.5, 0.3),
			position = fd.pos + offset,
		})
		applyStyle(picket, MATERIALS.FENCE)
	end
end

-- Gate
local gate = createPart({
	name = "Gate",
	size = Vector3.new(10, 8, 1),
	position = Vector3.new(0, 4, 80),
})
gate.Material = Enum.Material.Metal
gate.Color = Color3.fromRGB(40, 40, 40)
addTag(gate, Constants.TAG_DOOR)

-- Path from gate to front door
for i = 0, 12 do
	local pathPiece = createPart({
		name = "Path_" .. i,
		size = Vector3.new(6, 0.2, 5),
		position = Vector3.new(0, 0.1, 30 + i * 4),
	})
	pathPiece.Material = Enum.Material.Slate
	pathPiece.Color = Color3.fromRGB(130, 120, 110)
end

-- Trees
local function createTree(position)
	local treeFolder = Instance.new("Folder")
	treeFolder.Name = "Tree"
	treeFolder.Parent = worldFolder

	local trunk = createPart({
		name = "Trunk",
		size = Vector3.new(2, 12, 2),
		position = position + Vector3.new(0, 6, 0),
		parent = treeFolder,
	})
	trunk.Material = Enum.Material.Wood
	trunk.Color = Color3.fromRGB(60, 35, 20)

	local canopy = createPart({
		name = "Canopy",
		size = Vector3.new(10, 10, 10),
		position = position + Vector3.new(0, 14, 0),
		parent = treeFolder,
	})
	canopy.Shape = Enum.PartType.Ball
	canopy.Material = Enum.Material.Grass
	canopy.Color = Color3.fromRGB(25, 40, 20)
	canopy.Transparency = 0.1

	return treeFolder
end

local treePositions = {
	Vector3.new(60, 0, 60), Vector3.new(-60, 0, 60),
	Vector3.new(70, 0, 20), Vector3.new(-70, 0, 20),
	Vector3.new(70, 0, -40), Vector3.new(-70, 0, -40),
	Vector3.new(60, 0, -80), Vector3.new(-60, 0, -80),
	Vector3.new(40, 0, 70), Vector3.new(-40, 0, 70),
	Vector3.new(0, 0, 70), Vector3.new(30, 0, -100),
	Vector3.new(-30, 0, -100),
}

for _, pos in ipairs(treePositions) do
	createTree(pos)
end

-- Bushes
local function createBush(position)
	local bush = createPart({
		name = "Bush",
		size = Vector3.new(5, 3, 5),
		position = position + Vector3.new(0, 1.5, 0),
	})
	bush.Shape = Enum.PartType.Ball
	bush.Material = Enum.Material.Grass
	bush.Color = Color3.fromRGB(30, 50, 25)
end

local bushPositions = {
	Vector3.new(15, 0, 30), Vector3.new(-15, 0, 30),
	Vector3.new(25, 0, 40), Vector3.new(-25, 0, 40),
	Vector3.new(35, 0, 30), Vector3.new(-35, 0, 30),
	Vector3.new(10, 0, 50), Vector3.new(-10, 0, 50),
}

for _, pos in ipairs(bushPositions) do
	createBush(pos)
end

-- ==========================================
-- FOG ZONES
-- ==========================================

-- Outdoor fog
local outdoorFog = createPart({
	name = "OutdoorFogZone",
	size = Vector3.new(300, 30, 300),
	position = Vector3.new(0, 15, -20),
	transparency = 1,
	canCollide = false,
})
addTag(outdoorFog, Constants.TAG_FOG_ZONE)

-- Basement fog
local basementFog = createPart({
	name = "BasementFogZone",
	size = Vector3.new(120, ROOM_HEIGHT, 120),
	position = Vector3.new(0, BF + ROOM_HEIGHT / 2, -20),
	transparency = 1,
	canCollide = false,
})
addTag(basementFog, Constants.TAG_FOG_ZONE)

-- ==========================================
-- SPOOKY DECORATIONS
-- ==========================================

print("[WorldBuilder] Adding spooky decorations...")

-- Cobwebs in room corners
local cobwebData = {
	{ pos = Vector3.new(28, GF + ROOM_HEIGHT - 1, 23), size = Vector3.new(4, 4, 0.1) },
	{ pos = Vector3.new(-28, GF + ROOM_HEIGHT - 1, 23), size = Vector3.new(4, 4, 0.1) },
	{ pos = Vector3.new(75, GF + ROOM_HEIGHT - 1, 28), size = Vector3.new(4, 0.1, 4) },
	{ pos = Vector3.new(-75, GF + ROOM_HEIGHT - 1, 28), size = Vector3.new(4, 0.1, 4) },
	{ pos = Vector3.new(0, SF + ROOM_HEIGHT - 1, 33), size = Vector3.new(4, 4, 0.1) },
	{ pos = Vector3.new(-45, SF + ROOM_HEIGHT - 1, -18), size = Vector3.new(4, 0.1, 4) },
	{ pos = Vector3.new(-25, BF + ROOM_HEIGHT - 1, 18), size = Vector3.new(4, 0.1, 4) },
	{ pos = Vector3.new(25, BF + ROOM_HEIGHT - 1, 18), size = Vector3.new(4, 0.1, 4) },
}

for i, cw in ipairs(cobwebData) do
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

-- Blood stains (dark red splotches on floors)
local bloodPositions = {
	Vector3.new(10, GF + 0.85, -30),
	Vector3.new(-40, SF + 0.85 + SF, -10),
	Vector3.new(0, BF + 0.85, -10),
	Vector3.new(-25, BF + 0.85, -40),
}

for i, pos in ipairs(bloodPositions) do
	local stain = createPart({
		name = "BloodStain_" .. i,
		size = Vector3.new(3, 0.05, 3),
		position = pos,
		canCollide = false,
	})
	stain.Material = Enum.Material.SmoothPlastic
	stain.Color = Color3.fromRGB(80, 10, 10)
end

-- Scratches on walls (thin dark marks)
local scratchPositions = {
	{ pos = Vector3.new(5, GF + 5, 24.3), size = Vector3.new(0.1, 3, 0.05) },
	{ pos = Vector3.new(-50, SF + 5, 21.7), size = Vector3.new(0.1, 4, 0.05) },
	{ pos = Vector3.new(0, BF + 4, 39.5), size = Vector3.new(0.1, 2, 0.05) },
}

for i, sc in ipairs(scratchPositions) do
	for j = 1, 3 do
		local scratch = createPart({
			name = "Scratch_" .. i .. "_" .. j,
			size = sc.size,
			position = sc.pos + Vector3.new(j * 0.4, j * 0.3, 0),
			canCollide = false,
		})
		scratch.Material = Enum.Material.Metal
		scratch.Color = Color3.fromRGB(30, 25, 20)
		scratch.CFrame = scratch.CFrame * CFrame.Angles(0, 0, math.rad(10 * j - 15))
	end
end

-- ==========================================
-- ADDITIONAL WALL SCONCES / LIGHTS
-- ==========================================

local extraLights = {
	{ pos = Vector3.new(0, GF + 10, 24), flicker = false },
	{ pos = Vector3.new(0, GF + 10, -24), flicker = true },
	{ pos = Vector3.new(29, GF + 10, 0), flicker = false },
	{ pos = Vector3.new(-29, GF + 10, 0), flicker = false },
	{ pos = Vector3.new(55, GF + 10, 28), flicker = false },
	{ pos = Vector3.new(-55, GF + 10, 28), flicker = false },
	{ pos = Vector3.new(55, GF + 10, -54), flicker = true },
	{ pos = Vector3.new(-55, GF + 10, -54), flicker = true },
	{ pos = Vector3.new(5, SF + 10, 30), flicker = true },
	{ pos = Vector3.new(5, SF + 10, -40), flicker = true },
	{ pos = Vector3.new(-25, SF + 10, 21), flicker = false },
	{ pos = Vector3.new(50, SF + 10, 18), flicker = true },
	{ pos = Vector3.new(0, BF + 10, 38), flicker = true },
	{ pos = Vector3.new(0, BF + 10, -38), flicker = true },
}

for i, ld in ipairs(extraLights) do
	local sconce = createPart({
		name = "WallSconce_" .. i,
		size = Vector3.new(0.6, 1, 0.6),
		position = ld.pos,
		canCollide = false,
	})
	sconce.Material = Enum.Material.Neon
	sconce.Color = Color3.fromRGB(255, 180, 80)
	sconce.Transparency = 0.5

	addLight(sconce, {
		color = Color3.fromRGB(255, 150, 50),
		brightness = 0.5,
		range = 15,
	})

	if ld.flicker then
		addTag(sconce, Constants.TAG_FLICKER_LIGHT)
	end
end

-- ==========================================
-- MANSION EXTERIOR WALLS (decorative facade)
-- ==========================================

print("[WorldBuilder] Building exterior facade...")

-- Front facade columns
for _, xPos in ipairs({-25, -15, 15, 25}) do
	local column = createPart({
		name = "FacadeColumn",
		size = Vector3.new(3, ROOM_HEIGHT * 2 + FLOOR_THICKNESS, 3),
		position = Vector3.new(xPos, ROOM_HEIGHT, 26),
	})
	column.Material = Enum.Material.Marble
	column.Color = Color3.fromRGB(180, 170, 160)
end

-- Front porch overhang
local porch = createPart({
	name = "PorchRoof",
	size = Vector3.new(60, 1, 10),
	position = Vector3.new(0, ROOM_HEIGHT - 1, 30),
})
porch.Material = Enum.Material.Slate
porch.Color = Color3.fromRGB(60, 50, 40)

-- Porch floor
local porchFloor = createPart({
	name = "PorchFloor",
	size = Vector3.new(60, 0.5, 10),
	position = Vector3.new(0, 0.25, 30),
})
porchFloor.Material = Enum.Material.Wood
porchFloor.Color = Color3.fromRGB(90, 60, 35)

-- Steps up to porch
for i = 0, 2 do
	local step = createPart({
		name = "PorchStep_" .. i,
		size = Vector3.new(12, 0.5, 2),
		position = Vector3.new(0, 0.25 + i * 0.3, 36 + i * 2),
	})
	step.Material = Enum.Material.Slate
	step.Color = Color3.fromRGB(140, 130, 120)
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
print("[WorldBuilder] Ground Floor: Grand Foyer, Kitchen, Living Room, Dining Room, Library, Hallway")
print("[WorldBuilder] Second Floor: Master Bedroom, Children's Room, Bathroom, Study, Hallway")
print("[WorldBuilder] Basement: Boiler Room, Storage Room, Wine Cellar, Secret Lab, Hallway")
print("[WorldBuilder] Rooftop: Boss Arena with pillars and weapon pickups")
print("[WorldBuilder] Elevators: 2 (Main + Service)")
print("[WorldBuilder] Checkpoints:", #checkpoints)
print("[WorldBuilder] Patrol points:", #patrolPositions)
print("[WorldBuilder] Story notes:", #notePositions)
print("[WorldBuilder] Keys:", #keyData)
print("[WorldBuilder] Cat treats:", treatIndex)
print("[WorldBuilder] Evil Cats: 2")
print("[WorldBuilder] Obby sections: 2")
print("[WorldBuilder] Secret passages: 4")
print("[WorldBuilder] The mansion is ready!")
print("[WorldBuilder] ============================================")

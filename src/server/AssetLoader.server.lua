--[[
	AssetLoader - Attempts to load free models from the Roblox Creator Store
	Uses InsertService:LoadAsset() to pull community assets into the game.

	IMPORTANT: InsertService:LoadAsset() only works for assets owned by
	the game creator or by Roblox. If loading fails, the WorldBuilder script
	will procedurally generate everything from basic Parts instead.

	This script runs BEFORE WorldBuilder (alphabetical order) and sets a flag
	so WorldBuilder knows which assets were successfully loaded.

	Free Model IDs sourced from the Roblox Creator Store:
	  - Old cat model (free): 491761648
	  - Cartoon cat: 4906820308
	  - Cat Models: 136390642
	  - Door: 44100564
	  - Door model: 16908241906
]]

local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

-- Only run once
if ServerStorage:FindFirstChild("WorldSetup") then
	print("[AssetLoader] World already set up, skipping.")
	return
end

-- ==========================================
-- ASSET ID REGISTRY
-- All IDs sourced from the Roblox Creator Store (free models)
-- ==========================================

local ASSET_IDS = {
	-- Cat models (try multiple in case one fails)
	CATS = {
		491761648,    -- "Old cat model (free)" by community creator
		4906820308,   -- "cartoon cat" from Creator Store
		136390642,    -- "Cat Models" from Creator Store
	},

	-- Door models
	DOORS = {
		44100564,     -- "door" from Creator Store
		16908241906,  -- "door model" from Creator Store
	},
}

-- ==========================================
-- HELPER FUNCTIONS
-- ==========================================

local function tryLoadAsset(assetId: number): Model?
	local success, result = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)

	if success and result then
		print("[AssetLoader] Successfully loaded asset:", assetId)
		return result
	else
		warn("[AssetLoader] Failed to load asset", assetId, ":", result or "unknown error")
		return nil
	end
end

local function findFirstModelInContainer(container: Instance): Model?
	for _, child in container:GetChildren() do
		if child:IsA("Model") then
			return child
		end
	end
	-- If no Model found, check for a MeshPart or Part we can wrap
	for _, child in container:GetChildren() do
		if child:IsA("BasePart") then
			local wrapper = Instance.new("Model")
			wrapper.Name = child.Name
			child.Parent = wrapper
			wrapper.PrimaryPart = child
			return wrapper
		end
	end
	return nil
end

local function ensureHumanoid(model: Model): Humanoid?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = Instance.new("Humanoid")
		humanoid.MaxHealth = 100
		humanoid.Health = 100
		humanoid.WalkSpeed = Constants.CAT_WALK_SPEED
		humanoid.Parent = model
	end
	return humanoid
end

local function ensurePrimaryPart(model: Model)
	if model.PrimaryPart then
		return
	end
	-- Try to find a HumanoidRootPart
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		model.PrimaryPart = hrp
		return
	end
	-- Try to find any part named "Torso" or "Head"
	for _, name in {"Torso", "Head", "Body", "Root"} do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			model.PrimaryPart = part
			return
		end
	end
	-- Fallback: use the first BasePart found
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			model.PrimaryPart = desc
			return
		end
	end
	-- Last resort: create a HumanoidRootPart
	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(2, 2, 1)
	rootPart.Transparency = 1
	rootPart.CanCollide = false
	rootPart.Parent = model
	model.PrimaryPart = rootPart
end

-- Create a cat model procedurally (fallback when no assets load)
local function createProceduralCat(name: string, scale: number): Model
	local cat = Instance.new("Model")
	cat.Name = name

	-- Body
	local body = Instance.new("Part")
	body.Name = "HumanoidRootPart"
	body.Size = Vector3.new(2 * scale, 1.5 * scale, 3 * scale)
	body.Color = Color3.fromRGB(20, 20, 20) -- Black cat
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = false
	body.CanCollide = true
	body.Parent = cat

	-- Head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.5 * scale, 1.5 * scale, 1.5 * scale)
	head.Color = Color3.fromRGB(20, 20, 20)
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = false
	head.CanCollide = false
	head.Parent = cat

	-- Weld head to body
	local headWeld = Instance.new("Weld")
	headWeld.Part0 = body
	headWeld.Part1 = head
	headWeld.C0 = CFrame.new(0, 0.3 * scale, -1.5 * scale)
	headWeld.Parent = head

	-- Eyes (glowing red/purple for evil cat)
	for i, offset in { Vector3.new(-0.3, 0.2, -0.7), Vector3.new(0.3, 0.2, -0.7) } do
		local eye = Instance.new("Part")
		eye.Name = "Eye" .. i
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(0.3 * scale, 0.3 * scale, 0.3 * scale)
		eye.Color = Color3.fromRGB(255, 255, 0) -- Evil yellow glow (daughter's design!)
		eye.Material = Enum.Material.Neon
		eye.Anchored = false
		eye.CanCollide = false
		eye.Parent = cat

		local eyeWeld = Instance.new("Weld")
		eyeWeld.Part0 = head
		eyeWeld.Part1 = eye
		eyeWeld.C0 = CFrame.new(offset * scale)
		eyeWeld.Parent = eye

		-- Eye glow
		local eyeLight = Instance.new("PointLight")
		eyeLight.Color = Color3.fromRGB(255, 255, 0)
		eyeLight.Brightness = 1
		eyeLight.Range = 4 * scale
		eyeLight.Parent = eye
	end

	-- Ears (two small wedge-like parts)
	for i, xOff in { -0.4, 0.4 } do
		local ear = Instance.new("Part")
		ear.Name = "Ear" .. i
		ear.Size = Vector3.new(0.3 * scale, 0.5 * scale, 0.3 * scale)
		ear.Color = Color3.fromRGB(20, 20, 20)
		ear.Material = Enum.Material.SmoothPlastic
		ear.Anchored = false
		ear.CanCollide = false
		ear.Parent = cat

		local earWeld = Instance.new("Weld")
		earWeld.Part0 = head
		earWeld.Part1 = ear
		earWeld.C0 = CFrame.new(xOff * scale, 0.7 * scale, 0)
		earWeld.Parent = ear
	end

	-- Tail
	local tail = Instance.new("Part")
	tail.Name = "Tail"
	tail.Size = Vector3.new(0.3 * scale, 0.3 * scale, 2 * scale)
	tail.Color = Color3.fromRGB(20, 20, 20)
	tail.Material = Enum.Material.SmoothPlastic
	tail.Anchored = false
	tail.CanCollide = false
	tail.Parent = cat

	local tailWeld = Instance.new("Weld")
	tailWeld.Part0 = body
	tailWeld.Part1 = tail
	tailWeld.C0 = CFrame.new(0, 0.3 * scale, 1.8 * scale) * CFrame.Angles(math.rad(-30), 0, 0)
	tailWeld.Parent = tail

	-- Legs (4 legs)
	local legPositions = {
		Vector3.new(-0.6, -0.75, -0.8),  -- Front left
		Vector3.new(0.6, -0.75, -0.8),   -- Front right
		Vector3.new(-0.6, -0.75, 0.8),   -- Back left
		Vector3.new(0.6, -0.75, 0.8),    -- Back right
	}

	for i, pos in legPositions do
		local leg = Instance.new("Part")
		leg.Name = "Leg" .. i
		leg.Size = Vector3.new(0.4 * scale, 1 * scale, 0.4 * scale)
		leg.Color = Color3.fromRGB(20, 20, 20)
		leg.Material = Enum.Material.SmoothPlastic
		leg.Anchored = false
		leg.CanCollide = false
		leg.Parent = cat

		local legWeld = Instance.new("Weld")
		legWeld.Part0 = body
		legWeld.Part1 = leg
		legWeld.C0 = CFrame.new(pos * scale)
		legWeld.Parent = leg
	end

	-- Set up as a walkable NPC
	cat.PrimaryPart = body

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.WalkSpeed = Constants.CAT_WALK_SPEED
	humanoid.Parent = cat

	return cat
end

-- ==========================================
-- MAIN ASSET LOADING
-- ==========================================

local loadedAssets = {
	catLoaded = false,
	doorLoaded = false,
}

-- Create a folder in ServerStorage to track what was loaded
local assetStatusFolder = Instance.new("Folder")
assetStatusFolder.Name = "AssetLoadStatus"
assetStatusFolder.Parent = ServerStorage

-- Try to load a cat model
print("[AssetLoader] Attempting to load cat models from Creator Store...")
local catModel: Model? = nil

for _, assetId in ASSET_IDS.CATS do
	local container = tryLoadAsset(assetId)
	if container then
		local model = findFirstModelInContainer(container)
		if model then
			catModel = model:Clone()
			catModel.Name = "EvilCat"
			container:Destroy()
			print("[AssetLoader] Cat model loaded from asset ID:", assetId)
			break
		end
		container:Destroy()
	end
end

-- Set up the cat in ServerStorage
if catModel then
	-- Ensure it has a Humanoid and PrimaryPart for CatAI
	ensureHumanoid(catModel)
	ensurePrimaryPart(catModel)
	catModel.Parent = ServerStorage
	loadedAssets.catLoaded = true

	-- Create a BossCat (scaled-up version)
	local bossCat = catModel:Clone()
	bossCat.Name = "BossCat"
	if bossCat:IsA("Model") and bossCat.PrimaryPart then
		pcall(function()
			bossCat:ScaleTo(2.5)
		end)
	end
	local bossHumanoid = bossCat:FindFirstChildOfClass("Humanoid")
	if bossHumanoid then
		bossHumanoid.MaxHealth = Constants.BOSS_CAT_HEALTH
		bossHumanoid.Health = Constants.BOSS_CAT_HEALTH
		bossHumanoid.WalkSpeed = Constants.BOSS_CAT_CHASE_SPEED
	end
	bossCat.Parent = ServerStorage

	print("[AssetLoader] EvilCat and BossCat stored in ServerStorage (from loaded model)")
else
	-- Fallback: create procedural cats
	warn("[AssetLoader] Could not load any cat models. Creating procedural cats...")

	local evilCat = createProceduralCat("EvilCat", 1)
	evilCat.Parent = ServerStorage

	local bossCat = createProceduralCat("BossCat", 2.5)
	local bossHumanoid = bossCat:FindFirstChildOfClass("Humanoid")
	if bossHumanoid then
		bossHumanoid.MaxHealth = Constants.BOSS_CAT_HEALTH
		bossHumanoid.Health = Constants.BOSS_CAT_HEALTH
		bossHumanoid.WalkSpeed = Constants.BOSS_CAT_CHASE_SPEED
	end
	bossCat.Parent = ServerStorage

	loadedAssets.catLoaded = true -- Procedural counts as loaded
	print("[AssetLoader] Procedural EvilCat and BossCat created and stored in ServerStorage")
end

-- Store load status so WorldBuilder knows what it needs to build
local catLoadedValue = Instance.new("BoolValue")
catLoadedValue.Name = "CatLoaded"
catLoadedValue.Value = loadedAssets.catLoaded
catLoadedValue.Parent = assetStatusFolder

local doorLoadedValue = Instance.new("BoolValue")
doorLoadedValue.Name = "DoorLoaded"
doorLoadedValue.Value = loadedAssets.doorLoaded
doorLoadedValue.Parent = assetStatusFolder

print("[AssetLoader] Asset loading complete.")
print("[AssetLoader]   Cat loaded:", loadedAssets.catLoaded)
print("[AssetLoader]   Door loaded:", loadedAssets.doorLoaded)
print("[AssetLoader] WorldBuilder will generate the rest of the world from Parts.")

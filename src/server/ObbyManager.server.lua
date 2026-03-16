--[[
	ObbyManager - Handles obstacle course mechanics
	Kill bricks, moving platforms, and disappearing platforms
]]

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

-- ==================
-- KILL BRICKS
-- ==================

local function setupKillBrick(brick: BasePart)
	-- Style the kill brick
	if not brick:GetAttribute("Configured") then
		brick.Material = Enum.Material.Neon
		brick.BrickColor = BrickColor.new("Really red")
		brick:SetAttribute("Configured", true)
	end

	brick.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		-- Instant kill
		humanoid.Health = 0
	end)
end

-- ==================
-- MOVING PLATFORMS
-- ==================

local function setupMovingPlatform(platform: BasePart)
	-- Read movement attributes (set these in Roblox Studio on each platform)
	-- MoveDirection: Vector3 (e.g., 0, 0, 20 to move 20 studs on Z axis)
	-- MoveDuration: number (seconds for one way, default 3)
	local moveDirection = platform:GetAttribute("MoveDirection") or Vector3.new(0, 0, 20)
	local moveDuration = platform:GetAttribute("MoveDuration") or 3

	-- Ensure server owns the physics
	platform.Anchored = true
	platform:SetAttribute("Configured", true)

	local startCFrame = platform.CFrame
	local endCFrame = startCFrame + moveDirection

	local tweenInfo = TweenInfo.new(
		moveDuration,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		-1, -- Repeat forever
		true, -- Reverses
		0 -- Delay
	)

	local tween = TweenService:Create(platform, tweenInfo, {
		CFrame = endCFrame,
	})

	tween:Play()
end

-- ==================
-- DISAPPEARING PLATFORMS
-- ==================

local function setupDisappearingPlatform(platform: BasePart)
	-- DisappearDelay: seconds after touching before it vanishes (default 1)
	-- ReappearDelay: seconds before it comes back (default 3)
	local disappearDelay = platform:GetAttribute("DisappearDelay") or 1
	local reappearDelay = platform:GetAttribute("ReappearDelay") or 3

	platform.Anchored = true
	platform:SetAttribute("Configured", true)

	local originalTransparency = platform.Transparency
	local originalColor = platform.Color
	local isDisappearing = false

	platform.Touched:Connect(function(hit)
		-- Only trigger for player characters
		local character = hit.Parent
		if not character or not character:FindFirstChildOfClass("Humanoid") then
			return
		end
		if not Players:GetPlayerFromCharacter(character) then
			return
		end

		if isDisappearing then
			return
		end
		isDisappearing = true

		-- Warning flash
		local warningTween = TweenService:Create(platform, TweenInfo.new(disappearDelay, Enum.EasingStyle.Linear), {
			Transparency = 0.8,
			Color = Color3.fromRGB(255, 100, 100),
		})
		warningTween:Play()
		warningTween.Completed:Wait()

		-- Disappear
		platform.Transparency = 1
		platform.CanCollide = false

		-- Wait then reappear
		task.wait(reappearDelay)

		platform.Transparency = originalTransparency
		platform.CanCollide = true
		platform.Color = originalColor
		isDisappearing = false
	end)
end

-- ==================
-- INITIALIZATION
-- ==================

local function initializeAll()
	-- Kill bricks
	for _, brick in CollectionService:GetTagged(Constants.TAG_KILL_BRICK) do
		if brick:IsA("BasePart") then
			setupKillBrick(brick)
		end
	end

	-- Moving platforms
	for _, platform in CollectionService:GetTagged(Constants.TAG_MOVING_PLATFORM) do
		if platform:IsA("BasePart") then
			setupMovingPlatform(platform)
		end
	end

	-- Disappearing platforms
	for _, platform in CollectionService:GetTagged(Constants.TAG_DISAPPEARING_PLATFORM) do
		if platform:IsA("BasePart") then
			setupDisappearingPlatform(platform)
		end
	end

	print("[ObbyManager] Kill bricks:", #CollectionService:GetTagged(Constants.TAG_KILL_BRICK))
	print("[ObbyManager] Moving platforms:", #CollectionService:GetTagged(Constants.TAG_MOVING_PLATFORM))
	print("[ObbyManager] Disappearing platforms:", #CollectionService:GetTagged(Constants.TAG_DISAPPEARING_PLATFORM))
end

-- Listen for dynamically added objects
CollectionService:GetInstanceAddedSignal(Constants.TAG_KILL_BRICK):Connect(function(inst)
	if inst:IsA("BasePart") then
		setupKillBrick(inst)
	end
end)

CollectionService:GetInstanceAddedSignal(Constants.TAG_MOVING_PLATFORM):Connect(function(inst)
	if inst:IsA("BasePart") then
		setupMovingPlatform(inst)
	end
end)

CollectionService:GetInstanceAddedSignal(Constants.TAG_DISAPPEARING_PLATFORM):Connect(function(inst)
	if inst:IsA("BasePart") then
		setupDisappearingPlatform(inst)
	end
end)

initializeAll()
print("[ObbyManager] Initialized")

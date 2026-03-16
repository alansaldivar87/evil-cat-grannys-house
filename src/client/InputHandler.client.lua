--[[
	InputHandler - Custom input bindings for cross-platform support
	Handles: weapon activation, flashlight toggle
	Works on PC (keyboard/mouse) and PlayStation controller automatically
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LocalPlayer = Players.LocalPlayer

-- ==================
-- WEAPON INPUT
-- ==================

-- The CatRepellent is a Tool, so Roblox handles equip/activate natively.
-- Tool:Activate() fires on left mouse click (PC) and R2 (PlayStation).
-- We just need to tell the server when the player attacks.

local function onCharacterAdded(character: Model)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == "CatRepellent" then
			child.Activated:Connect(function()
				-- Tell server we attacked
				Remotes[Constants.EVENT_WEAPON_ATTACK]:FireServer()
			end)
		end
	end)

	-- Also check tools already equipped
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child.Name == "CatRepellent" then
			child.Activated:Connect(function()
				Remotes[Constants.EVENT_WEAPON_ATTACK]:FireServer()
			end)
		end
	end
end

-- Connect for current and future characters
if LocalPlayer.Character then
	onCharacterAdded(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

-- ==================
-- FLASHLIGHT INPUT
-- ==================

-- F key (PC) or left bumper (gamepad) toggles flashlight
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	local isFlashlightKey = input.KeyCode == Enum.KeyCode.F
	local isFlashlightButton = input.KeyCode == Enum.KeyCode.ButtonL1

	if isFlashlightKey or isFlashlightButton then
		-- Check if player has flashlight equipped or in backpack
		local character = LocalPlayer.Character
		if not character then
			return
		end

		local hasFlashlight = character:FindFirstChild("Flashlight")
		if not hasFlashlight then
			local backpack = LocalPlayer:FindFirstChild("Backpack")
			if backpack then
				hasFlashlight = backpack:FindFirstChild("Flashlight")
			end
		end

		if hasFlashlight then
			Remotes[Constants.EVENT_FLASHLIGHT_TOGGLE]:FireServer()
		end
	end
end)

-- ==================
-- PLATFORM DETECTION
-- ==================

local function getPlatform(): string
	if UserInputService.GamepadEnabled then
		return "Gamepad"
	elseif UserInputService.TouchEnabled then
		return "Mobile"
	else
		return "PC"
	end
end

print("[InputHandler] Platform:", getPlatform())
print("[InputHandler] Input system initialized")

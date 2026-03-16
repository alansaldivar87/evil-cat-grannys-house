--[[
	InputHandler - Custom input bindings for cross-platform support
	Handles: weapon activation (works on PC mouse + PlayStation controller automatically)
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

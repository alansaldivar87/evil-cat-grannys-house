--[[
	HUD - Main game heads-up display
	Shows game state info and tips
	(Main UI elements are in UIManager - this handles supplementary HUD elements)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local GameState = require(Shared:WaitForChild("GameState"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LocalPlayer = Players.LocalPlayer

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Tip/hint text at bottom of screen
local tipLabel = Instance.new("TextLabel")
tipLabel.Name = "Tip"
tipLabel.Size = UDim2.new(0, 500, 0, 30)
tipLabel.Position = UDim2.new(0.5, 0, 1, -15)
tipLabel.AnchorPoint = Vector2.new(0.5, 1)
tipLabel.BackgroundTransparency = 1
tipLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
tipLabel.TextStrokeTransparency = 0.5
tipLabel.Font = Enum.Font.Gotham
tipLabel.TextSize = 14
tipLabel.Text = "Explore Granny's house... but beware of the evil cat!"
tipLabel.Parent = screenGui

-- Game state indicator
local stateLabel = Instance.new("TextLabel")
stateLabel.Name = "GameState"
stateLabel.Size = UDim2.new(0, 200, 0, 25)
stateLabel.Position = UDim2.new(1, -20, 0, 50)
stateLabel.AnchorPoint = Vector2.new(1, 0)
stateLabel.BackgroundTransparency = 0.5
stateLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
stateLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
stateLabel.Font = Enum.Font.Gotham
stateLabel.TextSize = 12
stateLabel.Text = "Exploring..."
stateLabel.Parent = screenGui

local stateCorner = Instance.new("UICorner")
stateCorner.CornerRadius = UDim.new(0, 4)
stateCorner.Parent = stateLabel

-- Tips rotation
local tips = {
	"Explore Granny's house... but beware of the evil cat!",
	"Find checkpoints to save your progress.",
	"The evil cat can hear you... stay quiet!",
	"Look for the CatRepellent weapon in the boss arena.",
	"Work together with your friends to defeat the boss!",
	"Touch the green glowing parts to save your checkpoint.",
	"Watch out for kill bricks in the obby sections!",
}

-- Rotate tips every 10 seconds
task.spawn(function()
	local tipIndex = 1
	while true do
		task.wait(10)
		tipIndex = tipIndex % #tips + 1

		-- Fade out
		local fadeOut = TweenService:Create(tipLabel, TweenInfo.new(0.5), { TextTransparency = 1 })
		fadeOut:Play()
		fadeOut.Completed:Wait()

		tipLabel.Text = tips[tipIndex]

		-- Fade in
		local fadeIn = TweenService:Create(tipLabel, TweenInfo.new(0.5), { TextTransparency = 0 })
		fadeIn:Play()
	end
end)

-- Game state updates
Remotes[Constants.EVENT_GAME_STATE_CHANGED].OnClientEvent:Connect(function(newState: string)
	if newState == GameState.States.PLAYING then
		stateLabel.Text = "Exploring..."
		stateLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	elseif newState == GameState.States.BOSS_FIGHT then
		stateLabel.Text = "BOSS FIGHT!"
		stateLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
	elseif newState == GameState.States.VICTORY then
		stateLabel.Text = "VICTORY!"
		stateLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	end
end)

print("[HUD] HUD initialized")

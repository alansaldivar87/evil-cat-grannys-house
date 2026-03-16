--[[
	DeathScreen - Overlay shown when the player dies
	Shows "You were caught!" message and respawn countdown
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local LocalPlayer = Players.LocalPlayer

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DeathScreen"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 10 -- Above other UI
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Dark overlay
local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 1
overlay.BorderSizePixel = 0
overlay.Visible = false
overlay.Parent = screenGui

-- Death message
local deathMessage = Instance.new("TextLabel")
deathMessage.Name = "Message"
deathMessage.Size = UDim2.new(0, 500, 0, 80)
deathMessage.Position = UDim2.new(0.5, 0, 0.35, 0)
deathMessage.AnchorPoint = Vector2.new(0.5, 0.5)
deathMessage.BackgroundTransparency = 1
deathMessage.TextColor3 = Color3.fromRGB(255, 50, 50)
deathMessage.TextStrokeTransparency = 0
deathMessage.TextStrokeColor3 = Color3.fromRGB(50, 0, 0)
deathMessage.Font = Enum.Font.GothamBold
deathMessage.TextSize = 48
deathMessage.Text = "THE CAT GOT YOU!"
deathMessage.Parent = overlay

-- Cat face ASCII art (fun touch for the daughter!)
local catFace = Instance.new("TextLabel")
catFace.Name = "CatFace"
catFace.Size = UDim2.new(0, 300, 0, 100)
catFace.Position = UDim2.new(0.5, 0, 0.5, 0)
catFace.AnchorPoint = Vector2.new(0.5, 0.5)
catFace.BackgroundTransparency = 1
catFace.TextColor3 = Color3.fromRGB(255, 200, 0)
catFace.Font = Enum.Font.Code
catFace.TextSize = 36
catFace.Text = "=^..^="
catFace.Parent = overlay

-- Respawn countdown
local countdownLabel = Instance.new("TextLabel")
countdownLabel.Name = "Countdown"
countdownLabel.Size = UDim2.new(0, 400, 0, 40)
countdownLabel.Position = UDim2.new(0.5, 0, 0.65, 0)
countdownLabel.AnchorPoint = Vector2.new(0.5, 0.5)
countdownLabel.BackgroundTransparency = 1
countdownLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
countdownLabel.Font = Enum.Font.Gotham
countdownLabel.TextSize = 22
countdownLabel.Text = ""
countdownLabel.Parent = overlay

-- Death messages (random pick)
local deathMessages = {
	"THE CAT GOT YOU!",
	"CAUGHT BY THE EVIL CAT!",
	"THE CAT WINS... THIS TIME!",
	"MEOW... GAME OVER!",
	"THE EVIL CAT STRIKES!",
}

local function showDeathScreen()
	overlay.Visible = true

	-- Pick random death message
	deathMessage.Text = deathMessages[math.random(1, #deathMessages)]

	-- Fade in overlay
	overlay.BackgroundTransparency = 1
	local fadeIn = TweenService:Create(overlay, TweenInfo.new(0.5), {
		BackgroundTransparency = 0.3,
	})
	fadeIn:Play()

	-- Countdown
	for i = Constants.RESPAWN_TIME, 1, -1 do
		countdownLabel.Text = "Respawning in " .. i .. "..."
		task.wait(1)
	end
	countdownLabel.Text = "Respawning..."
end

local function hideDeathScreen()
	local fadeOut = TweenService:Create(overlay, TweenInfo.new(0.5), {
		BackgroundTransparency = 1,
	})
	fadeOut:Play()
	fadeOut.Completed:Wait()
	overlay.Visible = false
end

-- Connect to character events
LocalPlayer.CharacterAdded:Connect(function(character)
	-- Hide death screen when new character spawns
	hideDeathScreen()

	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		showDeathScreen()
	end)
end)

-- Handle if character already exists
if LocalPlayer.Character then
	local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			showDeathScreen()
		end)
	end
end

print("[DeathScreen] Death screen initialized")

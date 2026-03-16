--[[
	UIManager - Client-side UI management
	Creates and manages the health bar, checkpoint notifications, and boss health bar
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LocalPlayer = Players.LocalPlayer

-- ==================
-- CREATE UI
-- ==================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GameUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Health Bar
local healthFrame = Instance.new("Frame")
healthFrame.Name = "HealthBar"
healthFrame.Size = UDim2.new(0, 250, 0, 30)
healthFrame.Position = UDim2.new(0, 20, 1, -50)
healthFrame.AnchorPoint = Vector2.new(0, 1)
healthFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
healthFrame.BorderSizePixel = 0
healthFrame.Parent = screenGui

local healthCorner = Instance.new("UICorner")
healthCorner.CornerRadius = UDim.new(0, 6)
healthCorner.Parent = healthFrame

local healthFill = Instance.new("Frame")
healthFill.Name = "Fill"
healthFill.Size = UDim2.new(1, 0, 1, 0)
healthFill.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
healthFill.BorderSizePixel = 0
healthFill.Parent = healthFrame

local healthFillCorner = Instance.new("UICorner")
healthFillCorner.CornerRadius = UDim.new(0, 6)
healthFillCorner.Parent = healthFill

local healthLabel = Instance.new("TextLabel")
healthLabel.Name = "Label"
healthLabel.Size = UDim2.new(1, 0, 1, 0)
healthLabel.BackgroundTransparency = 1
healthLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
healthLabel.TextStrokeTransparency = 0.5
healthLabel.Font = Enum.Font.GothamBold
healthLabel.TextSize = 14
healthLabel.Text = "100/100"
healthLabel.Parent = healthFrame

-- Checkpoint notification
local checkpointLabel = Instance.new("TextLabel")
checkpointLabel.Name = "CheckpointNotif"
checkpointLabel.Size = UDim2.new(0, 400, 0, 50)
checkpointLabel.Position = UDim2.new(0.5, 0, 0.15, 0)
checkpointLabel.AnchorPoint = Vector2.new(0.5, 0.5)
checkpointLabel.BackgroundTransparency = 1
checkpointLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
checkpointLabel.TextStrokeTransparency = 0.3
checkpointLabel.Font = Enum.Font.GothamBold
checkpointLabel.TextSize = 24
checkpointLabel.Text = ""
checkpointLabel.TextTransparency = 1
checkpointLabel.Parent = screenGui

-- Boss health bar (hidden by default)
local bossFrame = Instance.new("Frame")
bossFrame.Name = "BossHealthBar"
bossFrame.Size = UDim2.new(0, 500, 0, 35)
bossFrame.Position = UDim2.new(0.5, 0, 0.05, 0)
bossFrame.AnchorPoint = Vector2.new(0.5, 0)
bossFrame.BackgroundColor3 = Color3.fromRGB(30, 0, 0)
bossFrame.BorderSizePixel = 0
bossFrame.Visible = false
bossFrame.Parent = screenGui

local bossCorner = Instance.new("UICorner")
bossCorner.CornerRadius = UDim.new(0, 6)
bossCorner.Parent = bossFrame

local bossFill = Instance.new("Frame")
bossFill.Name = "Fill"
bossFill.Size = UDim2.new(1, 0, 1, 0)
bossFill.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
bossFill.BorderSizePixel = 0
bossFill.Parent = bossFrame

local bossFillCorner = Instance.new("UICorner")
bossFillCorner.CornerRadius = UDim.new(0, 6)
bossFillCorner.Parent = bossFill

local bossLabel = Instance.new("TextLabel")
bossLabel.Name = "Label"
bossLabel.Size = UDim2.new(1, 0, 1, 0)
bossLabel.BackgroundTransparency = 1
bossLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
bossLabel.TextStrokeTransparency = 0.3
bossLabel.Font = Enum.Font.GothamBold
bossLabel.TextSize = 18
bossLabel.Text = "EVIL CAT BOSS"
bossLabel.Parent = bossFrame

-- Player count
local playerCountLabel = Instance.new("TextLabel")
playerCountLabel.Name = "PlayerCount"
playerCountLabel.Size = UDim2.new(0, 150, 0, 25)
playerCountLabel.Position = UDim2.new(1, -20, 0, 20)
playerCountLabel.AnchorPoint = Vector2.new(1, 0)
playerCountLabel.BackgroundTransparency = 0.5
playerCountLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
playerCountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
playerCountLabel.Font = Enum.Font.Gotham
playerCountLabel.TextSize = 14
playerCountLabel.Text = "Players: 1/" .. Constants.MAX_PLAYERS
playerCountLabel.Parent = screenGui

local playerCountCorner = Instance.new("UICorner")
playerCountCorner.CornerRadius = UDim.new(0, 4)
playerCountCorner.Parent = playerCountLabel

-- Game title (shown briefly at start)
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(0, 600, 0, 80)
titleLabel.Position = UDim2.new(0.5, 0, 0.3, 0)
titleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
titleLabel.TextStrokeColor3 = Color3.fromRGB(100, 0, 0)
titleLabel.TextStrokeTransparency = 0
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 42
titleLabel.Text = "EVIL CAT IN GRANNY'S HOUSE"
titleLabel.TextTransparency = 1
titleLabel.Parent = screenGui

-- ==================
-- UI UPDATES
-- ==================

-- Health bar update
RunService.RenderStepped:Connect(function()
	local character = LocalPlayer.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local healthPercent = humanoid.Health / humanoid.MaxHealth
	healthFill.Size = UDim2.new(math.clamp(healthPercent, 0, 1), 0, 1, 0)
	healthLabel.Text = math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth)

	-- Color based on health
	if healthPercent > 0.6 then
		healthFill.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
	elseif healthPercent > 0.3 then
		healthFill.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
	else
		healthFill.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	end
end)

-- Player count update
local function updatePlayerCount()
	playerCountLabel.Text = "Players: " .. #Players:GetPlayers() .. "/" .. Constants.MAX_PLAYERS
end

Players.PlayerAdded:Connect(updatePlayerCount)
Players.PlayerRemoving:Connect(updatePlayerCount)
updatePlayerCount()

-- ==================
-- REMOTE EVENT HANDLERS
-- ==================

-- Checkpoint reached notification
Remotes[Constants.EVENT_CHECKPOINT_REACHED].OnClientEvent:Connect(function(order, total)
	checkpointLabel.Text = "Checkpoint " .. order .. "/" .. total .. " reached!"
	checkpointLabel.TextTransparency = 0

	-- Fade out after 2 seconds
	task.delay(2, function()
		local tween = TweenService:Create(checkpointLabel, TweenInfo.new(1), {
			TextTransparency = 1,
		})
		tween:Play()
	end)
end)

-- Boss fight start
Remotes[Constants.EVENT_BOSS_FIGHT_START].OnClientEvent:Connect(function()
	bossFrame.Visible = true
	bossFill.Size = UDim2.new(1, 0, 1, 0)

	-- Flash warning text
	checkpointLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
	checkpointLabel.Text = "THE EVIL CAT BOSS HAS APPEARED!"
	checkpointLabel.TextTransparency = 0
	checkpointLabel.TextSize = 30

	task.delay(3, function()
		local tween = TweenService:Create(checkpointLabel, TweenInfo.new(1), {
			TextTransparency = 1,
		})
		tween:Play()
		task.wait(1)
		checkpointLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		checkpointLabel.TextSize = 24
	end)
end)

-- Boss health update
Remotes[Constants.EVENT_BOSS_HEALTH_UPDATE].OnClientEvent:Connect(function(currentHealth, maxHealth)
	local percent = currentHealth / maxHealth
	local tween = TweenService:Create(bossFill, TweenInfo.new(0.3), {
		Size = UDim2.new(math.clamp(percent, 0, 1), 0, 1, 0),
	})
	tween:Play()

	-- Enraged color
	if percent <= Constants.BOSS_CAT_ENRAGE_THRESHOLD then
		bossFill.BackgroundColor3 = Color3.fromRGB(255, 50, 0)
		bossLabel.Text = "EVIL CAT BOSS (ENRAGED!)"
	end
end)

-- Boss defeated / Victory
Remotes[Constants.EVENT_BOSS_DEFEATED].OnClientEvent:Connect(function()
	bossFrame.Visible = false

	checkpointLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	checkpointLabel.Text = "VICTORY! You defeated the Evil Cat!"
	checkpointLabel.TextTransparency = 0
	checkpointLabel.TextSize = 36

	-- Don't fade - keep showing victory
end)

-- Show title on game start
task.spawn(function()
	task.wait(1)
	-- Fade in
	local fadeIn = TweenService:Create(titleLabel, TweenInfo.new(1.5), {
		TextTransparency = 0,
	})
	fadeIn:Play()
	fadeIn.Completed:Wait()

	task.wait(3)

	-- Fade out
	local fadeOut = TweenService:Create(titleLabel, TweenInfo.new(1.5), {
		TextTransparency = 1,
	})
	fadeOut:Play()
end)

print("[UIManager] UI initialized")

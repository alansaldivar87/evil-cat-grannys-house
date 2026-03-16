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
-- FLASHLIGHT BATTERY BAR
-- ==================

local batteryFrame = Instance.new("Frame")
batteryFrame.Name = "BatteryBar"
batteryFrame.Size = UDim2.new(0, 150, 0, 20)
batteryFrame.Position = UDim2.new(0, 20, 1, -85)
batteryFrame.AnchorPoint = Vector2.new(0, 1)
batteryFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
batteryFrame.BorderSizePixel = 0
batteryFrame.Parent = screenGui

local batteryCorner = Instance.new("UICorner")
batteryCorner.CornerRadius = UDim.new(0, 4)
batteryCorner.Parent = batteryFrame

local batteryFill = Instance.new("Frame")
batteryFill.Name = "Fill"
batteryFill.Size = UDim2.new(1, 0, 1, 0)
batteryFill.BackgroundColor3 = Color3.fromRGB(255, 255, 100)
batteryFill.BorderSizePixel = 0
batteryFill.Parent = batteryFrame

local batteryFillCorner = Instance.new("UICorner")
batteryFillCorner.CornerRadius = UDim.new(0, 4)
batteryFillCorner.Parent = batteryFill

local batteryIcon = Instance.new("TextLabel")
batteryIcon.Name = "Icon"
batteryIcon.Size = UDim2.new(0, 25, 0, 20)
batteryIcon.Position = UDim2.new(0, -28, 0, 0)
batteryIcon.BackgroundTransparency = 1
batteryIcon.TextColor3 = Color3.fromRGB(255, 255, 200)
batteryIcon.Font = Enum.Font.GothamBold
batteryIcon.TextSize = 14
batteryIcon.Text = "F"
batteryIcon.Parent = batteryFrame

-- ==================
-- TREAT COUNTER
-- ==================

local treatLabel = Instance.new("TextLabel")
treatLabel.Name = "TreatCounter"
treatLabel.Size = UDim2.new(0, 150, 0, 25)
treatLabel.Position = UDim2.new(0, 20, 1, -110)
treatLabel.AnchorPoint = Vector2.new(0, 1)
treatLabel.BackgroundTransparency = 0.5
treatLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
treatLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
treatLabel.Font = Enum.Font.GothamBold
treatLabel.TextSize = 13
treatLabel.Text = "Cat Treats: 0"
treatLabel.Parent = screenGui

local treatCorner = Instance.new("UICorner")
treatCorner.CornerRadius = UDim.new(0, 4)
treatCorner.Parent = treatLabel

-- ==================
-- HIDING INDICATOR
-- ==================

local hidingLabel = Instance.new("TextLabel")
hidingLabel.Name = "HidingIndicator"
hidingLabel.Size = UDim2.new(0, 200, 0, 35)
hidingLabel.Position = UDim2.new(0.5, 0, 0.85, 0)
hidingLabel.AnchorPoint = Vector2.new(0.5, 0.5)
hidingLabel.BackgroundTransparency = 0.3
hidingLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
hidingLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
hidingLabel.TextStrokeTransparency = 0.3
hidingLabel.Font = Enum.Font.GothamBold
hidingLabel.TextSize = 16
hidingLabel.Text = "HIDDEN"
hidingLabel.Visible = false
hidingLabel.Parent = screenGui

local hidingCorner = Instance.new("UICorner")
hidingCorner.CornerRadius = UDim.new(0, 6)
hidingCorner.Parent = hidingLabel

-- ==================
-- KEY NOTIFICATION
-- ==================

local keyNotifLabel = Instance.new("TextLabel")
keyNotifLabel.Name = "KeyNotif"
keyNotifLabel.Size = UDim2.new(0, 350, 0, 40)
keyNotifLabel.Position = UDim2.new(0.5, 0, 0.25, 0)
keyNotifLabel.AnchorPoint = Vector2.new(0.5, 0.5)
keyNotifLabel.BackgroundTransparency = 1
keyNotifLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
keyNotifLabel.TextStrokeTransparency = 0.3
keyNotifLabel.Font = Enum.Font.GothamBold
keyNotifLabel.TextSize = 22
keyNotifLabel.Text = ""
keyNotifLabel.TextTransparency = 1
keyNotifLabel.Parent = screenGui

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

-- ==================
-- GAMEPLAY ENHANCEMENT EVENT HANDLERS
-- ==================

-- Flashlight battery update
Remotes[Constants.EVENT_FLASHLIGHT_BATTERY].OnClientEvent:Connect(function(current, max)
	local percent = current / max
	batteryFill.Size = UDim2.new(math.clamp(percent, 0, 1), 0, 1, 0)

	-- Color based on charge
	if percent > 0.5 then
		batteryFill.BackgroundColor3 = Color3.fromRGB(255, 255, 100)
	elseif percent > 0.2 then
		batteryFill.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
	else
		batteryFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	end
end)

-- Hide state changed
Remotes[Constants.EVENT_HIDE_STATE_CHANGED].OnClientEvent:Connect(function(isHidden)
	hidingLabel.Visible = isHidden

	if isHidden then
		-- Pulse animation for the hidden indicator
		task.spawn(function()
			while hidingLabel.Visible do
				local fadeOut = TweenService:Create(hidingLabel, TweenInfo.new(0.8), {
					TextTransparency = 0.5,
				})
				fadeOut:Play()
				fadeOut.Completed:Wait()

				local fadeIn = TweenService:Create(hidingLabel, TweenInfo.new(0.8), {
					TextTransparency = 0,
				})
				fadeIn:Play()
				fadeIn.Completed:Wait()
			end
		end)
	end
end)

-- Treat collected
Remotes[Constants.EVENT_TREAT_COLLECTED].OnClientEvent:Connect(function(totalCollected, roomName, roomCollected, roomTotal)
	treatLabel.Text = "Cat Treats: " .. totalCollected

	-- Flash notification for room progress
	checkpointLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
	checkpointLabel.Text = "Cat Treat collected! (" .. roomName .. ": " .. roomCollected .. "/" .. roomTotal .. ")"
	checkpointLabel.TextTransparency = 0

	task.delay(2, function()
		local tween = TweenService:Create(checkpointLabel, TweenInfo.new(1), {
			TextTransparency = 1,
		})
		tween:Play()
		task.wait(1)
		checkpointLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	end)
end)

-- Room treats complete
Remotes[Constants.EVENT_ROOM_TREATS_COMPLETE].OnClientEvent:Connect(function(roomName)
	checkpointLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	checkpointLabel.Text = "SECRET PASSAGE REVEALED in " .. roomName .. "!"
	checkpointLabel.TextTransparency = 0
	checkpointLabel.TextSize = 28

	task.delay(4, function()
		local tween = TweenService:Create(checkpointLabel, TweenInfo.new(1), {
			TextTransparency = 1,
		})
		tween:Play()
		task.wait(1)
		checkpointLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		checkpointLabel.TextSize = 24
	end)
end)

-- Key collected
Remotes[Constants.EVENT_KEY_COLLECTED].OnClientEvent:Connect(function(keyId)
	keyNotifLabel.Text = "KEY FOUND: " .. keyId
	keyNotifLabel.TextTransparency = 0

	task.delay(3, function()
		local tween = TweenService:Create(keyNotifLabel, TweenInfo.new(1), {
			TextTransparency = 1,
		})
		tween:Play()
	end)
end)

-- Door locked feedback
Remotes[Constants.EVENT_DOOR_TOGGLE].OnClientEvent:Connect(function(action, data)
	if action == "locked" then
		checkpointLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
		checkpointLabel.Text = "This door is locked! Find the key: " .. tostring(data)
		checkpointLabel.TextTransparency = 0

		task.delay(2, function()
			local tween = TweenService:Create(checkpointLabel, TweenInfo.new(1), {
				TextTransparency = 1,
			})
			tween:Play()
			task.wait(1)
			checkpointLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		end)
	end
end)

print("[UIManager] UI initialized")

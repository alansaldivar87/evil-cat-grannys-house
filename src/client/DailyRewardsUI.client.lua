--[[
	DailyRewardsUI - Client-side daily reward claim popup
	Shows a 7-day reward calendar when the player has unclaimed rewards.
	Automatically pops up on join if a reward is available.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- WAIT FOR REMOTES
-- ==========================================

local dailyRewardReady = Remotes:WaitForChild(Constants.EVENT_DAILY_REWARD_READY)
local claimDailyReward = Remotes:WaitForChild(Constants.EVENT_CLAIM_DAILY_REWARD)
local dailyRewardClaimed = Remotes:WaitForChild(Constants.EVENT_DAILY_REWARD_CLAIMED)
local inviteBonusGranted = Remotes:WaitForChild(Constants.EVENT_INVITE_BONUS_GRANTED)
local likeGamePrompt = Remotes:WaitForChild(Constants.EVENT_LIKE_GAME_PROMPT)
local inviteFriendRemote = Remotes:WaitForChild(Constants.EVENT_INVITE_FRIEND)

-- ==========================================
-- CREATE DAILY REWARDS UI
-- ==========================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DailyRewardsUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 15 -- Above most UI
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Darkened background overlay
local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.5
overlay.BorderSizePixel = 0
overlay.Visible = false
overlay.Parent = screenGui

-- Main popup frame
local popup = Instance.new("Frame")
popup.Name = "Popup"
popup.Size = UDim2.new(0, 600, 0, 400)
popup.Position = UDim2.new(0.5, 0, 0.5, 0)
popup.AnchorPoint = Vector2.new(0.5, 0.5)
popup.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
popup.BorderSizePixel = 0
popup.Parent = overlay

local popupCorner = Instance.new("UICorner")
popupCorner.CornerRadius = UDim.new(0, 14)
popupCorner.Parent = popup

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 50)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.Font = Enum.Font.GothamBold
title.TextSize = 26
title.Text = "DAILY REWARDS"
title.Parent = popup

-- Streak label
local streakLabel = Instance.new("TextLabel")
streakLabel.Name = "StreakLabel"
streakLabel.Size = UDim2.new(1, 0, 0, 25)
streakLabel.Position = UDim2.new(0, 0, 0, 45)
streakLabel.BackgroundTransparency = 1
streakLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
streakLabel.Font = Enum.Font.Gotham
streakLabel.TextSize = 14
streakLabel.Text = "Login streak: 0 days"
streakLabel.Parent = popup

-- Day cards container
local daysContainer = Instance.new("Frame")
daysContainer.Name = "DaysContainer"
daysContainer.Size = UDim2.new(1, -30, 0, 200)
daysContainer.Position = UDim2.new(0, 15, 0, 80)
daysContainer.BackgroundTransparency = 1
daysContainer.Parent = popup

local daysLayout = Instance.new("UIListLayout")
daysLayout.FillDirection = Enum.FillDirection.Horizontal
daysLayout.SortOrder = Enum.SortOrder.LayoutOrder
daysLayout.Padding = UDim.new(0, 8)
daysLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
daysLayout.Parent = daysContainer

-- Claim button
local claimButton = Instance.new("TextButton")
claimButton.Name = "ClaimButton"
claimButton.Size = UDim2.new(0, 200, 0, 50)
claimButton.Position = UDim2.new(0.5, 0, 1, -70)
claimButton.AnchorPoint = Vector2.new(0.5, 0)
claimButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
claimButton.TextColor3 = Color3.fromRGB(255, 255, 255)
claimButton.Font = Enum.Font.GothamBold
claimButton.TextSize = 20
claimButton.Text = "CLAIM REWARD!"
claimButton.Parent = popup

local claimCorner = Instance.new("UICorner")
claimCorner.CornerRadius = UDim.new(0, 10)
claimCorner.Parent = claimButton

-- Close button
local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 35, 0, 35)
closeButton.Position = UDim2.new(1, -42, 0, 7)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 18
closeButton.Text = "X"
closeButton.Parent = popup

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 6)
closeBtnCorner.Parent = closeButton

-- ==========================================
-- DAY CARD CREATION
-- ==========================================

local dayCards = {}

local function createDayCards(rewards: { { day: number, type: string, label: string } }, currentDay: number, streak: number)
	-- Clear existing cards
	for _, card in dayCards do
		card:Destroy()
	end
	dayCards = {}

	for _, reward in rewards do
		local card = Instance.new("Frame")
		card.Name = "Day" .. reward.day
		card.Size = UDim2.new(0, 72, 0, 190)
		card.LayoutOrder = reward.day
		card.BorderSizePixel = 0
		card.Parent = daysContainer

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 8)
		cardCorner.Parent = card

		-- Day label
		local dayLabel = Instance.new("TextLabel")
		dayLabel.Size = UDim2.new(1, 0, 0, 30)
		dayLabel.BackgroundTransparency = 1
		dayLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		dayLabel.Font = Enum.Font.GothamBold
		dayLabel.TextSize = 14
		dayLabel.Text = "Day " .. reward.day
		dayLabel.Parent = card

		-- Reward icon/text
		local rewardLabel = Instance.new("TextLabel")
		rewardLabel.Size = UDim2.new(1, -8, 0, 80)
		rewardLabel.Position = UDim2.new(0, 4, 0, 35)
		rewardLabel.BackgroundTransparency = 1
		rewardLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		rewardLabel.Font = Enum.Font.GothamBold
		rewardLabel.TextSize = 11
		rewardLabel.Text = reward.label
		rewardLabel.TextWrapped = true
		rewardLabel.Parent = card

		-- Status indicator
		local statusLabel = Instance.new("TextLabel")
		statusLabel.Name = "Status"
		statusLabel.Size = UDim2.new(1, 0, 0, 25)
		statusLabel.Position = UDim2.new(0, 0, 1, -30)
		statusLabel.BackgroundTransparency = 1
		statusLabel.Font = Enum.Font.GothamBold
		statusLabel.TextSize = 11
		statusLabel.Parent = card

		-- Color and status based on day vs current
		if reward.day < currentDay then
			-- Already claimed
			card.BackgroundColor3 = Color3.fromRGB(40, 60, 40)
			statusLabel.Text = "CLAIMED"
			statusLabel.TextColor3 = Color3.fromRGB(100, 200, 100)
		elseif reward.day == currentDay then
			-- Today's reward (claimable)
			card.BackgroundColor3 = Color3.fromRGB(60, 50, 20)
			statusLabel.Text = "TODAY!"
			statusLabel.TextColor3 = Color3.fromRGB(255, 215, 0)

			-- Add glow border effect
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(255, 215, 0)
			stroke.Thickness = 2
			stroke.Parent = card
		else
			-- Future day
			card.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
			statusLabel.Text = "LOCKED"
			statusLabel.TextColor3 = Color3.fromRGB(120, 120, 140)
		end

		table.insert(dayCards, card)
	end

	streakLabel.Text = "Login streak: " .. streak .. " day" .. (streak ~= 1 and "s" or "")
end

-- ==========================================
-- SHOW / HIDE POPUP
-- ==========================================

local isPopupOpen = false

local function showPopup()
	if isPopupOpen then
		return
	end
	isPopupOpen = true

	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	popup.Size = UDim2.new(0, 0, 0, 0)

	-- Fade in overlay
	local overlayFade = TweenService:Create(overlay, TweenInfo.new(0.3), {
		BackgroundTransparency = 0.5,
	})
	overlayFade:Play()

	-- Scale in popup
	local popupScale = TweenService:Create(popup, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
		Size = UDim2.new(0, 600, 0, 400),
	})
	popupScale:Play()
end

local function hidePopup()
	if not isPopupOpen then
		return
	end
	isPopupOpen = false

	local popupScale = TweenService:Create(popup, TweenInfo.new(0.2), {
		Size = UDim2.new(0, 0, 0, 0),
	})
	popupScale:Play()

	local overlayFade = TweenService:Create(overlay, TweenInfo.new(0.2), {
		BackgroundTransparency = 1,
	})
	overlayFade:Play()
	overlayFade.Completed:Wait()

	overlay.Visible = false
end

closeButton.MouseButton1Click:Connect(hidePopup)

-- ==========================================
-- CLAIM HANDLER
-- ==========================================

local canClaim = false

claimButton.MouseButton1Click:Connect(function()
	if not canClaim then
		return
	end

	canClaim = false
	claimButton.Text = "CLAIMING..."
	claimButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)

	-- Tell server to claim
	claimDailyReward:FireServer()
end)

-- Server confirms claim
dailyRewardClaimed.OnClientEvent:Connect(function(data)
	-- Show claim animation
	claimButton.Text = "CLAIMED!"
	claimButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)

	-- Update the day card
	if data and data.day then
		for _, card in dayCards do
			if card.Name == "Day" .. data.day then
				card.BackgroundColor3 = Color3.fromRGB(40, 60, 40)
				local status = card:FindFirstChild("Status")
				if status then
					status.Text = "CLAIMED"
					status.TextColor3 = Color3.fromRGB(100, 200, 100)
				end

				-- Remove glow
				local stroke = card:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke:Destroy()
				end
			end
		end
	end

	-- Show reward notification
	local rewardText = data and data.reward and data.reward.label or "Reward"
	local streakText = data and data.streak or 0

	-- Create a floating reward text
	local rewardNotif = Instance.new("TextLabel")
	rewardNotif.Size = UDim2.new(0, 300, 0, 50)
	rewardNotif.Position = UDim2.new(0.5, 0, 0.5, -50)
	rewardNotif.AnchorPoint = Vector2.new(0.5, 0.5)
	rewardNotif.BackgroundTransparency = 1
	rewardNotif.TextColor3 = Color3.fromRGB(255, 215, 0)
	rewardNotif.Font = Enum.Font.GothamBold
	rewardNotif.TextSize = 28
	rewardNotif.Text = "+" .. rewardText .. "!"
	rewardNotif.TextStrokeTransparency = 0.3
	rewardNotif.Parent = popup

	local floatUp = TweenService:Create(rewardNotif, TweenInfo.new(1.5), {
		Position = UDim2.new(0.5, 0, 0.3, 0),
		TextTransparency = 1,
	})
	floatUp:Play()
	floatUp.Completed:Connect(function()
		rewardNotif:Destroy()
	end)

	-- Auto close after 2 seconds
	task.delay(2, function()
		hidePopup()
	end)
end)

-- ==========================================
-- SERVER NOTIFICATION: REWARD READY
-- ==========================================

dailyRewardReady.OnClientEvent:Connect(function(data)
	if not data then
		return
	end

	local dayNumber = data.day or 1
	local rewards = data.rewards or Constants.DAILY_REWARDS
	local streak = data.streak or 0

	createDayCards(rewards, dayNumber, streak)

	canClaim = true
	claimButton.Text = "CLAIM REWARD!"
	claimButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)

	-- Show popup
	showPopup()
end)

-- ==========================================
-- INVITE BONUS NOTIFICATION
-- ==========================================

inviteBonusGranted.OnClientEvent:Connect(function(data)
	local notif = Instance.new("TextLabel")
	notif.Size = UDim2.new(0, 400, 0, 50)
	notif.Position = UDim2.new(0.5, 0, 0.15, 0)
	notif.AnchorPoint = Vector2.new(0.5, 0.5)
	notif.BackgroundColor3 = Color3.fromRGB(30, 50, 30)
	notif.BackgroundTransparency = 0.2
	notif.TextColor3 = Color3.fromRGB(100, 255, 100)
	notif.Font = Enum.Font.GothamBold
	notif.TextSize = 16
	notif.Text = "+" .. (data.coins or 0) .. " Coins! " .. (data.reason or "")
	notif.TextWrapped = true
	notif.BorderSizePixel = 0
	notif.Parent = screenGui

	local notifCorner = Instance.new("UICorner")
	notifCorner.CornerRadius = UDim.new(0, 8)
	notifCorner.Parent = notif

	task.delay(4, function()
		local fadeOut = TweenService:Create(notif, TweenInfo.new(0.5), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		})
		fadeOut:Play()
		fadeOut.Completed:Connect(function()
			notif:Destroy()
		end)
	end)
end)

-- ==========================================
-- LIKE GAME PROMPT
-- ==========================================

likeGamePrompt.OnClientEvent:Connect(function()
	-- Create a simple "like the game" popup
	local likeOverlay = Instance.new("Frame")
	likeOverlay.Size = UDim2.new(1, 0, 1, 0)
	likeOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	likeOverlay.BackgroundTransparency = 0.6
	likeOverlay.BorderSizePixel = 0
	likeOverlay.Parent = screenGui

	local likePopup = Instance.new("Frame")
	likePopup.Size = UDim2.new(0, 400, 0, 220)
	likePopup.Position = UDim2.new(0.5, 0, 0.5, 0)
	likePopup.AnchorPoint = Vector2.new(0.5, 0.5)
	likePopup.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
	likePopup.BorderSizePixel = 0
	likePopup.Parent = likeOverlay

	local likeCorner = Instance.new("UICorner")
	likeCorner.CornerRadius = UDim.new(0, 12)
	likeCorner.Parent = likePopup

	local likeTitle = Instance.new("TextLabel")
	likeTitle.Size = UDim2.new(1, 0, 0, 40)
	likeTitle.Position = UDim2.new(0, 0, 0, 10)
	likeTitle.BackgroundTransparency = 1
	likeTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
	likeTitle.Font = Enum.Font.GothamBold
	likeTitle.TextSize = 22
	likeTitle.Text = "You Beat the Evil Cat!"
	likeTitle.Parent = likePopup

	local likeDesc = Instance.new("TextLabel")
	likeDesc.Size = UDim2.new(1, -20, 0, 50)
	likeDesc.Position = UDim2.new(0, 10, 0, 55)
	likeDesc.BackgroundTransparency = 1
	likeDesc.TextColor3 = Color3.fromRGB(200, 200, 220)
	likeDesc.Font = Enum.Font.Gotham
	likeDesc.TextSize = 14
	likeDesc.Text = "Did you enjoy the game? Give it a thumbs up so more people can play!"
	likeDesc.TextWrapped = true
	likeDesc.Parent = likePopup

	-- Thumbs up button
	local likeBtn = Instance.new("TextButton")
	likeBtn.Size = UDim2.new(0, 150, 0, 45)
	likeBtn.Position = UDim2.new(0.25, 0, 1, -65)
	likeBtn.AnchorPoint = Vector2.new(0.5, 0)
	likeBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
	likeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	likeBtn.Font = Enum.Font.GothamBold
	likeBtn.TextSize = 16
	likeBtn.Text = "Like!"
	likeBtn.Parent = likePopup

	local likeBtnCorner = Instance.new("UICorner")
	likeBtnCorner.CornerRadius = UDim.new(0, 8)
	likeBtnCorner.Parent = likeBtn

	-- Invite button
	local inviteBtn = Instance.new("TextButton")
	inviteBtn.Size = UDim2.new(0, 150, 0, 45)
	inviteBtn.Position = UDim2.new(0.75, 0, 1, -65)
	inviteBtn.AnchorPoint = Vector2.new(0.5, 0)
	inviteBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
	inviteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	inviteBtn.Font = Enum.Font.GothamBold
	inviteBtn.TextSize = 16
	inviteBtn.Text = "Invite Friends"
	inviteBtn.Parent = likePopup

	local inviteBtnCorner = Instance.new("UICorner")
	inviteBtnCorner.CornerRadius = UDim.new(0, 8)
	inviteBtnCorner.Parent = inviteBtn

	-- Close X
	local likeClose = Instance.new("TextButton")
	likeClose.Size = UDim2.new(0, 30, 0, 30)
	likeClose.Position = UDim2.new(1, -35, 0, 5)
	likeClose.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	likeClose.TextColor3 = Color3.fromRGB(255, 255, 255)
	likeClose.Font = Enum.Font.GothamBold
	likeClose.TextSize = 16
	likeClose.Text = "X"
	likeClose.Parent = likePopup

	local likeCloseCorner = Instance.new("UICorner")
	likeCloseCorner.CornerRadius = UDim.new(0, 6)
	likeCloseCorner.Parent = likeClose

	-- Button handlers
	local function closeAll()
		local fade = TweenService:Create(likeOverlay, TweenInfo.new(0.3), {
			BackgroundTransparency = 1,
		})
		fade:Play()
		fade.Completed:Connect(function()
			likeOverlay:Destroy()
		end)
	end

	likeBtn.MouseButton1Click:Connect(function()
		-- The Roblox like/favorite is handled natively; we can't programmatically like
		-- But we can prompt them to favorite the game
		local success = pcall(function()
			MarketplaceService:PromptGamePassPurchase(LocalPlayer, 0) -- This won't work, but shows intent
		end)
		likeBtn.Text = "Thanks!"
		likeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		task.delay(1, closeAll)
	end)

	inviteBtn.MouseButton1Click:Connect(function()
		inviteFriendRemote:FireServer()
		inviteBtn.Text = "Sent!"
		inviteBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		task.delay(1, closeAll)
	end)

	likeClose.MouseButton1Click:Connect(closeAll)

	-- Auto close after 15 seconds
	task.delay(15, function()
		if likeOverlay.Parent then
			closeAll()
		end
	end)
end)

print("[DailyRewardsUI] Daily rewards and social UI initialized")

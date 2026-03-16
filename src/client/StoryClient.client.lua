--[[
	StoryClient - Client-side story/lore display
	Handles: rendering diary entries on screen when the player finds story notes,
	tracking discovery progress, and providing atmospheric story presentation
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LocalPlayer = Players.LocalPlayer

-- ==================
-- SOUND SETUP
-- ==================

local pageFlipSound = Instance.new("Sound")
pageFlipSound.Name = "PageFlip"
pageFlipSound.SoundId = "" -- TODO: Add asset ID for page flip sound
pageFlipSound.Volume = 0.6
pageFlipSound.Looped = false
pageFlipSound.Parent = SoundService

local discoverySound = Instance.new("Sound")
discoverySound.Name = "Discovery"
discoverySound.SoundId = "" -- TODO: Add asset ID for discovery chime
discoverySound.Volume = 0.5
discoverySound.Looped = false
discoverySound.Parent = SoundService

-- ==================
-- UI CREATION
-- ==================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StoryUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 5
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Dark overlay behind the diary entry
local overlay = Instance.new("Frame")
overlay.Name = "DiaryOverlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 1
overlay.BorderSizePixel = 0
overlay.Visible = false
overlay.Parent = screenGui

-- Diary page frame (parchment look)
local diaryFrame = Instance.new("Frame")
diaryFrame.Name = "DiaryPage"
diaryFrame.Size = UDim2.new(0, 550, 0, 400)
diaryFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
diaryFrame.AnchorPoint = Vector2.new(0.5, 0.5)
diaryFrame.BackgroundColor3 = Color3.fromRGB(245, 235, 210)
diaryFrame.BorderSizePixel = 0
diaryFrame.Visible = false
diaryFrame.Parent = screenGui

local diaryCorner = Instance.new("UICorner")
diaryCorner.CornerRadius = UDim.new(0, 8)
diaryCorner.Parent = diaryFrame

local diaryStroke = Instance.new("UIStroke")
diaryStroke.Color = Color3.fromRGB(139, 90, 43)
diaryStroke.Thickness = 3
diaryStroke.Parent = diaryFrame

-- Inner padding
local diaryPadding = Instance.new("UIPadding")
diaryPadding.PaddingTop = UDim.new(0, 20)
diaryPadding.PaddingBottom = UDim.new(0, 20)
diaryPadding.PaddingLeft = UDim.new(0, 25)
diaryPadding.PaddingRight = UDim.new(0, 25)
diaryPadding.Parent = diaryFrame

-- Diary title
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 35)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(80, 40, 10)
titleLabel.Font = Enum.Font.Antique
titleLabel.TextSize = 24
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Text = ""
titleLabel.Parent = diaryFrame

-- Divider line under title
local divider = Instance.new("Frame")
divider.Name = "Divider"
divider.Size = UDim2.new(1, 0, 0, 2)
divider.Position = UDim2.new(0, 0, 0, 40)
divider.BackgroundColor3 = Color3.fromRGB(139, 90, 43)
divider.BackgroundTransparency = 0.5
divider.BorderSizePixel = 0
divider.Parent = diaryFrame

-- Diary text body
local bodyLabel = Instance.new("TextLabel")
bodyLabel.Name = "Body"
bodyLabel.Size = UDim2.new(1, 0, 0, 240)
bodyLabel.Position = UDim2.new(0, 0, 0, 50)
bodyLabel.BackgroundTransparency = 1
bodyLabel.TextColor3 = Color3.fromRGB(60, 30, 10)
bodyLabel.Font = Enum.Font.Garamond
bodyLabel.TextSize = 18
bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
bodyLabel.TextWrapped = true
bodyLabel.Text = ""
bodyLabel.Parent = diaryFrame

-- Hint text at bottom
local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.Size = UDim2.new(1, 0, 0, 30)
hintLabel.Position = UDim2.new(0, 0, 1, -55)
hintLabel.BackgroundTransparency = 1
hintLabel.TextColor3 = Color3.fromRGB(150, 80, 20)
hintLabel.Font = Enum.Font.GothamBold
hintLabel.TextSize = 14
hintLabel.TextWrapped = true
hintLabel.Text = ""
hintLabel.Parent = diaryFrame

-- Progress counter
local progressLabel = Instance.new("TextLabel")
progressLabel.Name = "Progress"
progressLabel.Size = UDim2.new(1, 0, 0, 20)
progressLabel.Position = UDim2.new(0, 0, 1, -25)
progressLabel.BackgroundTransparency = 1
progressLabel.TextColor3 = Color3.fromRGB(120, 80, 40)
progressLabel.Font = Enum.Font.Gotham
progressLabel.TextSize = 12
progressLabel.Text = ""
progressLabel.Parent = diaryFrame

-- "New Discovery" badge
local newBadge = Instance.new("TextLabel")
newBadge.Name = "NewBadge"
newBadge.Size = UDim2.new(0, 120, 0, 25)
newBadge.Position = UDim2.new(1, -10, 0, -5)
newBadge.AnchorPoint = Vector2.new(1, 0)
newBadge.BackgroundColor3 = Color3.fromRGB(200, 160, 50)
newBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
newBadge.Font = Enum.Font.GothamBold
newBadge.TextSize = 12
newBadge.Text = "NEW DISCOVERY!"
newBadge.Visible = false
newBadge.Parent = diaryFrame

local newBadgeCorner = Instance.new("UICorner")
newBadgeCorner.CornerRadius = UDim.new(0, 4)
newBadgeCorner.Parent = newBadge

-- Close hint text
local closeHint = Instance.new("TextLabel")
closeHint.Name = "CloseHint"
closeHint.Size = UDim2.new(0, 300, 0, 20)
closeHint.Position = UDim2.new(0.5, 0, 1, 20)
closeHint.AnchorPoint = Vector2.new(0.5, 0)
closeHint.BackgroundTransparency = 1
closeHint.TextColor3 = Color3.fromRGB(200, 200, 200)
closeHint.TextStrokeTransparency = 0.3
closeHint.Font = Enum.Font.Gotham
closeHint.TextSize = 14
closeHint.Text = "Click anywhere or wait to close"
closeHint.Parent = diaryFrame

-- ==================
-- DISPLAY LOGIC
-- ==================

local isShowing = false
local autoCloseThread: thread? = nil

local function showDiaryEntry(noteId: number, title: string, text: string, hint: string, totalFound: number, totalNotes: number, isNew: boolean)
	if isShowing then
		return
	end
	isShowing = true

	-- Set content
	titleLabel.Text = title
	bodyLabel.Text = text
	hintLabel.Text = hint
	progressLabel.Text = "Diary Pages Found: " .. totalFound .. "/" .. totalNotes
	newBadge.Visible = isNew

	-- Play sound
	if isNew then
		discoverySound:Play()
	else
		pageFlipSound:Play()
	end

	-- Show with animation
	overlay.Visible = true
	diaryFrame.Visible = true
	overlay.BackgroundTransparency = 1
	diaryFrame.Size = UDim2.new(0, 550, 0, 400)

	-- Scale from small
	diaryFrame.Size = UDim2.new(0, 50, 0, 50)

	-- Fade in overlay
	local overlayFade = TweenService:Create(overlay, TweenInfo.new(Constants.STORY_NOTE_FADE_TIME * 0.5), {
		BackgroundTransparency = 0.6,
	})
	overlayFade:Play()

	-- Scale up diary
	local scaleUp = TweenService:Create(diaryFrame, TweenInfo.new(Constants.STORY_NOTE_FADE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 550, 0, 400),
	})
	scaleUp:Play()

	-- Auto-close after duration
	if autoCloseThread then
		task.cancel(autoCloseThread)
	end
	autoCloseThread = task.delay(Constants.STORY_NOTE_DISPLAY_DURATION, function()
		hideDiaryEntry()
	end)
end

function hideDiaryEntry()
	if not isShowing then
		return
	end

	if autoCloseThread then
		task.cancel(autoCloseThread)
		autoCloseThread = nil
	end

	-- Animate out
	local scaleDown = TweenService:Create(diaryFrame, TweenInfo.new(Constants.STORY_NOTE_FADE_TIME * 0.7, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 50, 0, 50),
	})

	local overlayFade = TweenService:Create(overlay, TweenInfo.new(Constants.STORY_NOTE_FADE_TIME * 0.7), {
		BackgroundTransparency = 1,
	})

	scaleDown:Play()
	overlayFade:Play()

	scaleDown.Completed:Connect(function()
		overlay.Visible = false
		diaryFrame.Visible = false
		isShowing = false
	end)
end

-- Click overlay to close
overlay.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		hideDiaryEntry()
	end
end)

-- Click diary frame to close too
diaryFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		hideDiaryEntry()
	end
end)

-- ==================
-- REMOTE EVENT HANDLER
-- ==================

Remotes[Constants.EVENT_STORY_NOTE_SHOW].OnClientEvent:Connect(function(noteId, title, text, hint, totalFound, totalNotes, isNew)
	showDiaryEntry(noteId, title, text, hint, totalFound, totalNotes, isNew)
end)

print("[StoryClient] Story display system initialized")

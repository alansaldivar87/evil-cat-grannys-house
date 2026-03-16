--[[
	GamePassUI - Client-side UI for game passes and developer products shop
	Shows a shop button, pass cards, product cards with purchase buttons.
	All purchases are validated server-side.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- WAIT FOR REMOTES
-- ==========================================

local promptGamePass = Remotes:WaitForChild(Constants.EVENT_PROMPT_GAME_PASS)
local gamePassOwned = Remotes:WaitForChild(Constants.EVENT_GAME_PASS_OWNED)
local promptProduct = Remotes:WaitForChild(Constants.EVENT_PROMPT_PRODUCT)
local productEffectGranted = Remotes:WaitForChild(Constants.EVENT_PRODUCT_EFFECT_GRANTED)
local openShopRemote = Remotes:WaitForChild(Constants.EVENT_OPEN_SHOP)

-- ==========================================
-- CREATE SHOP UI
-- ==========================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ShopUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 5
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Shop button (floating on right side)
local shopButton = Instance.new("TextButton")
shopButton.Name = "ShopButton"
shopButton.Size = UDim2.new(0, 50, 0, 50)
shopButton.Position = UDim2.new(1, -70, 0.5, -25)
shopButton.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
shopButton.TextColor3 = Color3.fromRGB(0, 0, 0)
shopButton.Font = Enum.Font.GothamBold
shopButton.TextSize = 24
shopButton.Text = "SHOP"
shopButton.TextScaled = true
shopButton.Parent = screenGui

local shopBtnCorner = Instance.new("UICorner")
shopBtnCorner.CornerRadius = UDim.new(0, 10)
shopBtnCorner.Parent = shopButton

local shopBtnPadding = Instance.new("UIPadding")
shopBtnPadding.PaddingBottom = UDim.new(0, 4)
shopBtnPadding.PaddingTop = UDim.new(0, 4)
shopBtnPadding.PaddingLeft = UDim.new(0, 4)
shopBtnPadding.PaddingRight = UDim.new(0, 4)
shopBtnPadding.Parent = shopButton

-- Shop frame (main container, hidden by default)
local shopFrame = Instance.new("Frame")
shopFrame.Name = "ShopFrame"
shopFrame.Size = UDim2.new(0, 700, 0, 500)
shopFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
shopFrame.AnchorPoint = Vector2.new(0.5, 0.5)
shopFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
shopFrame.BackgroundTransparency = 0.05
shopFrame.BorderSizePixel = 0
shopFrame.Visible = false
shopFrame.Parent = screenGui

local shopCorner = Instance.new("UICorner")
shopCorner.CornerRadius = UDim.new(0, 12)
shopCorner.Parent = shopFrame

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
titleBar.BorderSizePixel = 0
titleBar.Parent = shopFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = titleBar

-- Cover bottom corners of title bar
local titleCover = Instance.new("Frame")
titleCover.Size = UDim2.new(1, 0, 0, 12)
titleCover.Position = UDim2.new(0, 0, 1, -12)
titleCover.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
titleCover.BorderSizePixel = 0
titleCover.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -60, 1, 0)
titleLabel.Position = UDim2.new(0, 15, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 22
titleLabel.Text = "SHOP"
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

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
closeButton.Parent = titleBar

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 6)
closeBtnCorner.Parent = closeButton

-- Scrolling content area
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "Content"
scrollFrame.Size = UDim2.new(1, -20, 1, -60)
scrollFrame.Position = UDim2.new(0, 10, 0, 55)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0) -- Auto-sized
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = shopFrame

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 10)
listLayout.Parent = scrollFrame

-- ==========================================
-- SECTION HEADER
-- ==========================================

local function createSectionHeader(text: string, layoutOrder: number): TextLabel
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 35)
	header.BackgroundTransparency = 1
	header.TextColor3 = Color3.fromRGB(255, 215, 0)
	header.Font = Enum.Font.GothamBold
	header.TextSize = 18
	header.Text = text
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.LayoutOrder = layoutOrder
	header.Parent = scrollFrame
	return header
end

-- ==========================================
-- PASS / PRODUCT CARD CREATION
-- ==========================================

-- Track owned passes client-side (for display only, server authoritative)
local ownedPasses: { [string]: boolean } = {}

local function createCard(
	cardName: string,
	displayName: string,
	description: string,
	accentColor: Color3,
	buttonText: string,
	layoutOrder: number,
	onClick: () -> ()
): Frame
	local card = Instance.new("Frame")
	card.Name = cardName
	card.Size = UDim2.new(1, 0, 0, 80)
	card.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
	card.BorderSizePixel = 0
	card.LayoutOrder = layoutOrder
	card.Parent = scrollFrame

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = card

	-- Color accent bar on left
	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0, 4, 1, -10)
	accent.Position = UDim2.new(0, 5, 0, 5)
	accent.BackgroundColor3 = accentColor
	accent.BorderSizePixel = 0
	accent.Parent = card

	local accentCorner = Instance.new("UICorner")
	accentCorner.CornerRadius = UDim.new(0, 2)
	accentCorner.Parent = accent

	-- Name label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.6, -20, 0, 25)
	nameLabel.Position = UDim2.new(0, 20, 0, 10)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 16
	nameLabel.Text = displayName
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = card

	-- Description
	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(0.6, -20, 0, 35)
	descLabel.Position = UDim2.new(0, 20, 0, 35)
	descLabel.BackgroundTransparency = 1
	descLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 12
	descLabel.Text = description
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextWrapped = true
	descLabel.Parent = card

	-- Buy button
	local buyButton = Instance.new("TextButton")
	buyButton.Name = "BuyButton"
	buyButton.Size = UDim2.new(0, 120, 0, 40)
	buyButton.Position = UDim2.new(1, -135, 0.5, -20)
	buyButton.BackgroundColor3 = accentColor
	buyButton.TextColor3 = Color3.fromRGB(0, 0, 0)
	buyButton.Font = Enum.Font.GothamBold
	buyButton.TextSize = 14
	buyButton.Text = buttonText
	buyButton.Parent = card

	local buyCorner = Instance.new("UICorner")
	buyCorner.CornerRadius = UDim.new(0, 6)
	buyCorner.Parent = buyButton

	buyButton.MouseButton1Click:Connect(function()
		-- Button press animation
		local pressDown = TweenService:Create(buyButton, TweenInfo.new(0.1), {
			Size = UDim2.new(0, 110, 0, 36),
		})
		pressDown:Play()
		pressDown.Completed:Wait()

		local pressUp = TweenService:Create(buyButton, TweenInfo.new(0.1), {
			Size = UDim2.new(0, 120, 0, 40),
		})
		pressUp:Play()

		onClick()
	end)

	return card
end

-- ==========================================
-- POPULATE SHOP
-- ==========================================

-- Game Passes section
createSectionHeader("GAME PASSES", 1)

local passOrder = 2
for passKey, info in Constants.GAME_PASS_INFO do
	local card = createCard(
		"Pass_" .. passKey,
		info.name,
		info.description,
		info.color,
		"BUY PASS",
		passOrder,
		function()
			promptGamePass:FireServer(passKey)
		end
	)

	-- Mark as owned if already purchased
	if ownedPasses[passKey] then
		local buyBtn = card:FindFirstChild("BuyButton")
		if buyBtn then
			buyBtn.Text = "OWNED"
			buyBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		end
	end

	passOrder = passOrder + 1
end

-- Developer Products section
createSectionHeader("POWER-UPS", 10)

local productOrder = 11
for productKey, info in Constants.PRODUCT_INFO do
	createCard(
		"Product_" .. productKey,
		info.name,
		info.description,
		info.color,
		info.priceRobux .. " R$",
		productOrder,
		function()
			promptProduct:FireServer(productKey)
		end
	)
	productOrder = productOrder + 1
end

-- ==========================================
-- SHOP OPEN/CLOSE
-- ==========================================

local shopOpen = false

local function toggleShop()
	shopOpen = not shopOpen

	if shopOpen then
		shopFrame.Visible = true
		shopFrame.Size = UDim2.new(0, 0, 0, 0)
		local openTween = TweenService:Create(shopFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
			Size = UDim2.new(0, 700, 0, 500),
		})
		openTween:Play()
	else
		local closeTween = TweenService:Create(shopFrame, TweenInfo.new(0.2), {
			Size = UDim2.new(0, 0, 0, 0),
		})
		closeTween:Play()
		closeTween.Completed:Wait()
		shopFrame.Visible = false
	end
end

shopButton.MouseButton1Click:Connect(toggleShop)
closeButton.MouseButton1Click:Connect(function()
	if shopOpen then
		toggleShop()
	end
end)

-- ==========================================
-- PASS OWNERSHIP UPDATES
-- ==========================================

gamePassOwned.OnClientEvent:Connect(function(passKey: string, owned: boolean)
	ownedPasses[passKey] = owned

	-- Update the card's buy button
	local card = scrollFrame:FindFirstChild("Pass_" .. passKey)
	if card then
		local buyBtn = card:FindFirstChild("BuyButton")
		if buyBtn and owned then
			buyBtn.Text = "OWNED"
			buyBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		end
	end
end)

-- ==========================================
-- PRODUCT EFFECT NOTIFICATIONS
-- ==========================================

-- Floating notification for granted effects
local function showEffectNotification(effectName: string, details: { [string]: any }?)
	local notif = Instance.new("TextLabel")
	notif.Size = UDim2.new(0, 350, 0, 45)
	notif.Position = UDim2.new(0.5, 0, 0.2, 0)
	notif.AnchorPoint = Vector2.new(0.5, 0.5)
	notif.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	notif.BackgroundTransparency = 0.2
	notif.TextColor3 = Color3.fromRGB(100, 255, 100)
	notif.Font = Enum.Font.GothamBold
	notif.TextSize = 16
	notif.BorderSizePixel = 0
	notif.Parent = screenGui

	local notifCorner = Instance.new("UICorner")
	notifCorner.CornerRadius = UDim.new(0, 8)
	notifCorner.Parent = notif

	if effectName == "SpeedBoost" then
		notif.Text = "SPEED BOOST ACTIVATED! (60s)"
		notif.TextColor3 = Color3.fromRGB(0, 200, 255)
	elseif effectName == "SpeedBoostExpired" then
		notif.Text = "Speed boost expired"
		notif.TextColor3 = Color3.fromRGB(150, 150, 150)
	elseif effectName == "Shield" then
		local hits = details and details.hitsRemaining or 1
		notif.Text = "SHIELD ACTIVE! (" .. hits .. " hit" .. (hits > 1 and "s" or "") .. " blocked)"
		notif.TextColor3 = Color3.fromRGB(100, 255, 100)
	elseif effectName == "ShieldBlocked" then
		local hits = details and details.hitsRemaining or 0
		notif.Text = "Shield absorbed an attack!" .. (hits > 0 and (" " .. hits .. " remaining") or " Shield depleted!")
		notif.TextColor3 = Color3.fromRGB(255, 200, 50)
	elseif effectName == "ReviveToken" then
		local tokens = details and details.tokens or 1
		notif.Text = "Revive Token acquired! (Total: " .. tokens .. ")"
		notif.TextColor3 = Color3.fromRGB(255, 200, 50)
	elseif effectName == "Revived" then
		notif.Text = "REVIVED! You cheated death!"
		notif.TextColor3 = Color3.fromRGB(255, 215, 0)
	elseif effectName == "ExtraLife" then
		local remaining = details and details.livesRemaining or 0
		notif.Text = "Extra Life used! (" .. remaining .. " remaining)"
		notif.TextColor3 = Color3.fromRGB(255, 80, 80)
	elseif effectName == "CatTreats" then
		local count = details and details.positions and #details.positions or 0
		notif.Text = "Cat Treats revealed " .. count .. " collectibles!"
		notif.TextColor3 = Color3.fromRGB(255, 150, 100)

		-- Create markers on screen for revealed collectibles
		if details and details.positions then
			for _, pos in details.positions do
				task.spawn(function()
					local marker = Instance.new("BillboardGui")
					marker.Size = UDim2.new(0, 30, 0, 30)
					marker.AlwaysOnTop = true
					marker.MaxDistance = 200

					local markerPart = Instance.new("Part")
					markerPart.Position = pos
					markerPart.Anchored = true
					markerPart.CanCollide = false
					markerPart.Transparency = 1
					markerPart.Size = Vector3.new(1, 1, 1)
					markerPart.Parent = workspace

					marker.Adornee = markerPart
					marker.Parent = markerPart

					local markerIcon = Instance.new("TextLabel")
					markerIcon.Size = UDim2.new(1, 0, 1, 0)
					markerIcon.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
					markerIcon.BackgroundTransparency = 0.3
					markerIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
					markerIcon.Font = Enum.Font.GothamBold
					markerIcon.TextSize = 14
					markerIcon.Text = "!"
					markerIcon.Parent = marker

					local markerCorner = Instance.new("UICorner")
					markerCorner.CornerRadius = UDim.new(1, 0)
					markerCorner.Parent = markerIcon

					-- Remove after 30 seconds
					task.wait(30)
					markerPart:Destroy()
				end)
			end
		end
	else
		notif.Text = effectName .. " activated!"
	end

	-- Animate: slide in, hold, fade out
	notif.TextTransparency = 1
	notif.BackgroundTransparency = 1

	local fadeIn = TweenService:Create(notif, TweenInfo.new(0.3), {
		TextTransparency = 0,
		BackgroundTransparency = 0.2,
	})
	fadeIn:Play()

	task.delay(3, function()
		local fadeOut = TweenService:Create(notif, TweenInfo.new(0.5), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		})
		fadeOut:Play()
		fadeOut.Completed:Wait()
		notif:Destroy()
	end)
end

productEffectGranted.OnClientEvent:Connect(function(effectName, details)
	showEffectNotification(effectName, details)
end)

print("[GamePassUI] Shop UI initialized")

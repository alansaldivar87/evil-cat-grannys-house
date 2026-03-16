--[[
	StoryManager - Server-side story/lore system
	Handles: diary note discovery, story progression tracking per player

	Story notes are Parts tagged "StoryNote" with a "NoteId" integer attribute (1-10).
	When a player touches a note, the server fires a RemoteEvent to show the diary entry.

	BACKSTORY:
	Granny was a kind old lady who loved cats. One day she found a mysterious black crystal
	in the basement. The crystal corrupted her favorite cat, Midnight, and its dark magic
	spread to the other cats. Granny disappeared, and now the house is overrun with evil cats.
	The final diary entry reveals the key to victory: destroy the crystal the boss cat guards.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- ==================
-- DIARY ENTRIES
-- ==================

local DiaryEntries = {
	[1] = {
		title = "Granny's Diary - June 3rd",
		text = "The new kittens are settling in nicely. Midnight is already the boss of the group — she struts around like she owns the place! I made them all little beds near the fireplace. This old house feels so much warmer with cats in it. I think I'll adopt a few more from the shelter next week.",
		hint = "You found a page from Granny's diary. There may be more hidden in the house...",
	},
	[2] = {
		title = "Granny's Diary - June 15th",
		text = "Something strange happened today. I was cleaning out the basement and found a large black crystal wedged behind the old boiler. It was ice cold to the touch, even though the basement was warm. It has an odd shimmer to it, almost like it's glowing from the inside. I brought it upstairs to get a better look. Midnight seems fascinated by it — she won't stop staring.",
		hint = "The crystal... it started in the basement.",
	},
	[3] = {
		title = "Granny's Diary - June 22nd",
		text = "Midnight has been acting strange since I brought that crystal up. She hisses at the other cats now, and her eyes... I could swear they glow in the dark. A faint purple, like the shimmer inside the crystal. I tried to move the crystal back to the basement, but it felt heavier than before. Almost like it didn't want to be moved. I'm being silly. It's just a rock.",
		hint = "Midnight's eyes began to glow purple...",
	},
	[4] = {
		title = "Granny's Diary - July 1st",
		text = "I'm worried about the cats. Three more of them have started acting like Midnight — aggressive, hissing, scratching at the walls at night. I can hear them running through the hallways at 3 AM. Their eyes all have that same purple glow now. The crystal sits on the mantelpiece and I can feel it humming sometimes, a low vibration that makes my teeth ache.",
		hint = "The corruption is spreading from cat to cat...",
	},
	[5] = {
		title = "Granny's Diary - July 10th",
		text = "I barricaded some of the rooms today. The cats have grown stronger — much stronger than any normal cat should be. Whiskers knocked a solid oak door right off its hinges. I've been hiding in the kitchen mostly. I found that closing doors slows them down; they seem confused by them for a few seconds. And they won't come near my old flashlight — the bright light makes them flinch and move slower.",
		hint = "Doors slow the cats down. Flashlights make them flinch!",
	},
	[6] = {
		title = "Granny's Diary - July 18th",
		text = "I discovered something today. The cats still love their treats! Even corrupted, when I scatter cat treats around a room, they get distracted and calm down for a moment. I've been using treats to sneak past them. I hid some in every room of the house, just in case. Also found that hiding in the closets and under the beds works — they can't seem to detect me there. Their senses aren't perfect.",
		hint = "Cat treats distract them! And hiding spots keep you safe.",
	},
	[7] = {
		title = "Granny's Diary - July 25th",
		text = "The crystal is growing. I measured it — it's twice the size it was when I found it. Midnight guards it now, day and night. She's grown too, bigger than any housecat should be. The other corrupted cats follow her like soldiers. I tried to take the crystal away while she slept, but she woke instantly and nearly took my hand off. There has to be another way.",
		hint = "Midnight is growing larger, guarding the crystal...",
	},
	[8] = {
		title = "Granny's Diary - August 2nd",
		text = "I found old records in the attic. This house was built on land where a meteor struck in 1847. The previous owners all reported strange occurrences with animals — dogs that attacked their masters, birds that flew in endless circles around the chimney. The crystal must be a fragment of that meteor. Something alien. Something that corrupts living things.",
		hint = "The crystal is not from this world...",
	},
	[9] = {
		title = "Granny's Diary - August 8th",
		text = "I'm leaving this house. I can't fight them anymore. But I need someone to know the truth: the crystal is the source. DESTROY THE CRYSTAL and the corruption will end. Midnight — my poor sweet Midnight — she guards it in the deepest room. You'll need a weapon; I left my old Cat Repellent device near the arena. It shoots a beam of light that hurts them. Please, if you're reading this, save my cats. They're not evil. They're just... lost.",
		hint = "DESTROY THE CRYSTAL that the boss cat guards to break the curse!",
	},
	[10] = {
		title = "A Final Note (written in shaky handwriting)",
		text = "To whoever finds this: I didn't abandon them. I hid the keys to the locked rooms around the house — you'll need them to reach the basement where Midnight has made her lair. Collect the cat treats along the way; gathering all the treats in a room will reveal hidden passages I built years ago. The cats fear the light. Use your flashlight. Hide when you must. And please... when the crystal shatters and the curse breaks... tell Midnight that Granny loves her. Tell all of them.",
		hint = "Collect all treats in a room to reveal secret passages. Find keys to unlock doors. Use your flashlight!",
	},
}

-- ==================
-- PLAYER TRACKING
-- ==================

-- Track which notes each player has found: { [userId]: { [noteId]: true } }
local playerNotesFound: { [number]: { [number]: boolean } } = {}

-- Track cooldowns to prevent spam: { [userId_noteId]: tick }
local noteCooldowns: { [string]: number } = {}

local function getPlayerNotes(player: Player): { [number]: boolean }
	if not playerNotesFound[player.UserId] then
		playerNotesFound[player.UserId] = {}
	end
	return playerNotesFound[player.UserId]
end

local function getNotesFoundCount(player: Player): number
	local notes = getPlayerNotes(player)
	local count = 0
	for _ in notes do
		count = count + 1
	end
	return count
end

-- ==================
-- NOTE SETUP
-- ==================

local function setupStoryNote(notePart: BasePart)
	local noteId = notePart:GetAttribute("NoteId")
	if not noteId or type(noteId) ~= "number" then
		warn("[StoryManager] StoryNote missing NoteId attribute:", notePart:GetFullName())
		return
	end

	if noteId < 1 or noteId > Constants.TOTAL_DIARY_ENTRIES then
		warn("[StoryManager] Invalid NoteId:", noteId, "on", notePart:GetFullName())
		return
	end

	-- Style the note part to look like a piece of paper
	if not notePart:GetAttribute("Configured") then
		notePart.Material = Enum.Material.SmoothPlastic
		notePart.BrickColor = BrickColor.new("Institutional white")
		notePart.CanCollide = false
		notePart.Anchored = true
		notePart.Size = Vector3.new(1.5, 0.1, 2)
		notePart:SetAttribute("Configured", true)

		-- Add a subtle glow so players can spot them
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 240, 200)
		light.Brightness = 0.5
		light.Range = 6
		light.Parent = notePart

		-- Add a BillboardGui with a small "?" indicator
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "NoteIndicator"
		billboard.Size = UDim2.new(0, 30, 0, 30)
		billboard.StudsOffset = Vector3.new(0, 2, 0)
		billboard.AlwaysOnTop = false
		billboard.Parent = notePart

		local indicator = Instance.new("TextLabel")
		indicator.Size = UDim2.new(1, 0, 1, 0)
		indicator.BackgroundTransparency = 1
		indicator.TextColor3 = Color3.fromRGB(255, 240, 200)
		indicator.TextStrokeTransparency = 0.3
		indicator.Font = Enum.Font.GothamBold
		indicator.TextSize = 20
		indicator.Text = "?"
		indicator.Parent = billboard

		-- Gentle floating animation
		local originalY = notePart.Position.Y
		task.spawn(function()
			local phase = math.random() * math.pi * 2 -- Random start phase
			while notePart.Parent do
				phase = phase + 0.03
				notePart.Position = Vector3.new(
					notePart.Position.X,
					originalY + math.sin(phase) * 0.3,
					notePart.Position.Z
				)
				task.wait(0.03)
			end
		end)
	end

	-- Touch detection
	notePart.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		-- Cooldown check
		local cooldownKey = player.UserId .. "_" .. noteId
		local lastTriggered = noteCooldowns[cooldownKey]
		if lastTriggered and tick() - lastTriggered < Constants.STORY_NOTE_COOLDOWN then
			return
		end
		noteCooldowns[cooldownKey] = tick()

		-- Get diary entry data
		local entry = DiaryEntries[noteId]
		if not entry then
			return
		end

		-- Mark as found for this player
		local playerNotes = getPlayerNotes(player)
		local isNewDiscovery = not playerNotes[noteId]
		playerNotes[noteId] = true

		local totalFound = getNotesFoundCount(player)

		-- Fire to client to display the diary entry
		Remotes[Constants.EVENT_STORY_NOTE_SHOW]:FireClient(
			player,
			noteId,
			entry.title,
			entry.text,
			entry.hint,
			totalFound,
			Constants.TOTAL_DIARY_ENTRIES,
			isNewDiscovery
		)

		if isNewDiscovery then
			print("[StoryManager]", player.Name, "discovered diary entry", noteId .. "/" .. Constants.TOTAL_DIARY_ENTRIES .. ":", entry.title)
		end
	end)
end

-- ==================
-- INITIALIZATION
-- ==================

-- Set up existing story notes
for _, note in CollectionService:GetTagged(Constants.TAG_STORY_NOTE) do
	if note:IsA("BasePart") then
		setupStoryNote(note)
	end
end

-- Listen for dynamically added story notes
CollectionService:GetInstanceAddedSignal(Constants.TAG_STORY_NOTE):Connect(function(instance)
	if instance:IsA("BasePart") then
		setupStoryNote(instance)
	end
end)

-- Clean up when player leaves
Players.PlayerRemoving:Connect(function(player)
	playerNotesFound[player.UserId] = nil
	-- Clean up cooldowns for this player
	for key in noteCooldowns do
		if string.find(key, tostring(player.UserId) .. "_") then
			noteCooldowns[key] = nil
		end
	end
end)

print("[StoryManager] Story system initialized with", Constants.TOTAL_DIARY_ENTRIES, "diary entries")
print("[StoryManager] Found", #CollectionService:GetTagged(Constants.TAG_STORY_NOTE), "story note parts in world")

-- Shared utility functions

local Utils = {}

function Utils.getDistance(pos1: Vector3, pos2: Vector3): number
	return (pos1 - pos2).Magnitude
end

function Utils.getCharacterPosition(character: Model): Vector3?
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		return rootPart.Position
	end
	return nil
end

function Utils.getHumanoid(character: Model): Humanoid?
	return character:FindFirstChildOfClass("Humanoid")
end

function Utils.isAlive(character: Model): boolean
	local humanoid = Utils.getHumanoid(character)
	if humanoid and humanoid.Health > 0 then
		return true
	end
	return false
end

function Utils.findNearestPlayer(position: Vector3, maxRange: number): (Player?, number)
	local Players = game:GetService("Players")
	local nearestPlayer: Player? = nil
	local nearestDistance = maxRange

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			local charPos = Utils.getCharacterPosition(character)
			if charPos and Utils.isAlive(character) then
				local distance = Utils.getDistance(position, charPos)
				if distance < nearestDistance then
					nearestDistance = distance
					nearestPlayer = player
				end
			end
		end
	end

	return nearestPlayer, nearestDistance
end

function Utils.shuffleTable(t: { any }): { any }
	local shuffled = table.clone(t)
	for i = #shuffled, 2, -1 do
		local j = math.random(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	return shuffled
end

return Utils

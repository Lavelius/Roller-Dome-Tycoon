local PlayerDataService = {}
local stateByUserId = {}

local DEFAULT = {
	_v = 1,
	dubloons = 100000,
	stationId = nil,
	cannons = {

		cannon1 = {
			state = true,
			dieEnabled = 4,
			d4 = {
				prestige = 0,
				sides = 4,
				cannonPowerLevel = 0,
				dieValueMultiplierLevel = 0,
				amountFiredLevel = 0,
				cannonCooldownLevel = 0,
			},
			d6 = {
				prestige = 0,
				sides = 6,
				cannonPowerLevel = 0,
				dieValueMultiplierLevel = 0,
				amountFiredLevel = 0,
				cannonCooldownLevel = 0,
			},
			d8 = {
				prestige = 0,
				sides = 8,
				cannonPowerLevel = 0,
				dieValueMultiplierLevel = 0,
				amountFiredLevel = 0,
				cannonCooldownLevel = 0,
			},
			d10 = {
				prestige = 0,
				sides = 10,
				cannonPowerLevel = 0,
				dieValueMultiplierLevel = 0,
				amountFiredLevel = 0,
				cannonCooldownLevel = 0,
			},
			d12 = {
				prestige = 0,
				sides = 12,
				cannonPowerLevel = 0,
				dieValueMultiplierLevel = 0,
				amountFiredLevel = 0,
				cannonCooldownLevel = 0,
			},
			d20 = {
				prestige = 0,
				sides = 20,
				cannonPowerLevel = 0,
				dieValueMultiplierLevel = 0,
				amountFiredLevel = 0,
				cannonCooldownLevel = 0,
			},
		},
		cannon2 = {
			state = false,
			dieEnabled = 4,
			d4 = {
				prestige = 0,
				sides = 4,
				cannonPowerLevel = 0,
				dieValueMultiplierLevel = 0,
				amountFiredLevel = 0,
				cannonCooldownLevel = 0,
			},
			d6 = {
				prestige = 0,
				sides = 6,
				cannonPowerLevel = 0,
				dieValueMultiplierLevel = 0,
				amountFiredLevel = 0,
				cannonCooldownLevel = 0,
			},
			d8 = {
				prestige = 0,
				sides = 8,
				cannonPowerLevel = 0,
				dieValueMultiplierLevel = 0,
				amountFiredLevel = 0,
				cannonCooldownLevel = 0,
			},
			d10 = {
				prestige = 0,
				sides = 10,
				cannonPowerLevel = 0,
				dieValueMultiplierLevel = 0,
				amountFiredLevel = 0,
				cannonCooldownLevel = 0,
			},
			d12 = {
				prestige = 0,
				sides = 12,
				cannonPowerLevel = 0,
				dieValueMultiplierLevel = 0,
				amountFiredLevel = 0,
				cannonCooldownLevel = 0,
			},
			d20 = {
				prestige = 0,
				sides = 20,
				cannonPowerLevel = 0,
				dieValueMultiplierLevel = 0,
				amountFiredLevel = 0,
				cannonCooldownLevel = 0,
			},
		},
	},
}

local function deepCopy(t)
	local c = {}
	for k, v in pairs(t) do
		c[k] = (type(v) == "table") and deepCopy(v) or v
	end
	return c
end

function PlayerDataService.init()
	stateByUserId = {}
end

function PlayerDataService.load(player)
	local userId = player.UserId
	if stateByUserId[userId] then
		return stateByUserId[userId]
	end

	local state = deepCopy(DEFAULT)
	stateByUserId[userId] = state
	return state
end

--NOT YET IMPLEMENTED
function PlayerDataService.save(player)
	local userId = player.UserId
	local state = stateByUserId[userId]
	if not state then
		return false, "no state"
	end
	-- TODO: DataStoreService:SetAsync(key, state)
	return true
end

function PlayerDataService.get(player)
	return stateByUserId[player.UserId]
end

function PlayerDataService.assignStation(player, stationId)
	local s = PlayerDataService.get(player) or PlayerDataService.load(player)
	s.stationId = stationId
end

function PlayerDataService.addDubloons(player, amount)
	local s = PlayerDataService.get(player) or PlayerDataService.load(player)
	s.dubloons = (s.dubloons or 0) + (amount or 0)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local d = ls:FindFirstChild("Dubloons")
		if d then
			d.Value = s.dubloons
		end
	end
end

function PlayerDataService.trySpendDubloons(player, cost)
	local s = PlayerDataService.get(player) or PlayerDataService.load(player)
	cost = cost or 0
	if (s.dubloons or 0) >= cost then
		s.dubloons -= cost
		local ls = player:FindFirstChild("leaderstats")
		if ls then
			local d = ls:FindFirstChild("Dubloons")
			if d then
				d.Value = s.dubloons
			end
		end
		return true
	end
	return false
end

function PlayerDataService.getDieSides(player, cannonKey)
	local s = PlayerDataService.get(player) or PlayerDataService.load(player)
	cannonKey = cannonKey or "cannon1"
	local d = s.dice or {}
	s.dice = d
	d[cannonKey] = d[cannonKey] or 4
	return d[cannonKey]
end

function PlayerDataService.setDieSides(player, cannonKey, sides)
	local s = PlayerDataService.get(player) or PlayerDataService.load(player)
	cannonKey = cannonKey or "cannon1"
	local d = s.dice or {}
	s.dice = d
	d[cannonKey] = sides
end

return PlayerDataService

local PlayerDataService = {}
local stateByUserId = {}

local DEFAULT = {
	_v = 1,
	dubloons = 0,
	stationId = nil,
	upgrades = {
		cannon1 = false,
		cannon2 = false,
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
end

function PlayerDataService.trySpendDubloons(player, cost)
	local s = PlayerDataService.get(player) or PlayerDataService.load(player)
	if (s.dubloons or 0) >= cost then
		s.dubloons -= cost
		-- player:SetAttribute("Coins", s.dubloons)
		return true
	end
	return false
end

return PlayerDataService

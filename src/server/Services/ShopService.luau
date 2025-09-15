local Config = require(
	game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("ConfigFolder"):WaitForChild("Config")
)
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local ShopService = {}

local order = Config.Upgrades.DiceSidesOrder
local cost = Config.Upgrades.DiceSidesCost

local function nextSides(current)
	for i, v in ipairs(order) do
		if v == current then
			return order[i + 1] -- may be nil at end
		end
	end
	-- if current not found, default to first greater
	for _, v in ipairs(order) do
		if v > current then
			return v
		end
	end
	return nil
end

function ShopService.upgradeDie(player, cannonKey)
	cannonKey = cannonKey or "cannon1"
	local cur = PlayerDataService.getDieSides(player, cannonKey)
	local nxt = nextSides(cur)
	if not nxt then
		warn(("No further upgrades for %s (%s)"):format(player.Name, cannonKey))
		return false, "maxed"
	end
	local price = cost and cost[nxt] or 0
	if price > 0 then
		local ok = PlayerDataService.trySpendDubloons(player, price)
		if not ok then
			warn(("Not enough dubloons: need %d for %s on %s"):format(price, player.Name, cannonKey))
			return false, "insufficient"
		end
	end
	PlayerDataService.setDieSides(player, cannonKey, nxt)
	print(("%s upgraded %s to D%d (cost %d)"):format(player.Name, cannonKey, nxt, price))
	return true, nxt
end

return ShopService

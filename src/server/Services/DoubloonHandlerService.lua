-- ServerScriptService/Services/DoubloonHandlerService.lua
-- Minimal wallet ops using your DataService profile

local DoubloonHandler = {}

local DataService = require(script.Parent:WaitForChild("DataService"))
local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))

local function uidOf(who)
	return typeof(who) == "Instance" and who.UserId or who
end
local function playerOf(who)
	return typeof(who) == "Instance" and who or game:GetService("Players"):GetPlayerByUserId(uidOf(who))
end

function DoubloonHandler.GetBalance(who)
	local uid = uidOf(who)
	local p = DataService:GetProfile(uid)
	return (p and p.wallet and p.wallet.doubloons) or 0
end

-- Try to charge amount (>=0). Returns success:boolean, newBalance:number
function DoubloonHandler.TryCharge(who, amount)
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if amount == 0 then
		return true, DoubloonHandler.GetBalance(who)
	end

	local uid = uidOf(who)
	local p = DataService:GetProfile(uid)
	if not p then
		return false, 0
	end

	local bal = p.wallet.doubloons or 0
	if bal < amount then
		return false, bal
	end

	p.wallet.doubloons = bal - amount
	local plr = playerOf(who)
	if plr then
		LeaderboardService.Refresh(plr)
	end
	return true, p.wallet.doubloons
end

-- Grant (can be negative, but we clamp at 0)
function DoubloonHandler.Grant(who, amount)
	local uid = uidOf(who)
	local p = DataService:GetProfile(uid)
	if not p then
		return 0
	end

	local bal = p.wallet.doubloons or 0
	bal = math.max(0, bal + math.floor(tonumber(amount) or 0))
	p.wallet.doubloons = bal
	local plr = playerOf(who)
	if plr then
		LeaderboardService.Refresh(plr)
	end
	return bal
end

return DoubloonHandler

--JLKJ;LKasdfafsdsdafdsfaasdfaSDfasdfasdfasdfasdfsadfasdfasdasdfasdfasdfasdfasdfasdfasdfsadf

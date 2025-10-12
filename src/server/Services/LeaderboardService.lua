-- ServerScriptService/Services/LeaderboardService.lua
local LeaderboardService = {}

local DataService = require(script.Parent:WaitForChild("DataService"))

local function computePrestige(profile)
	if not profile then
		return 0
	end
	local total = 0
	local cannons = profile.cannons or {}
	for _, cannon in pairs(cannons) do
		if cannon and cannon.dice then
			for _, dieState in pairs(cannon.dice) do
				if dieState and typeof(dieState.tier) == "number" then
					total += dieState.tier
				end
			end
		end
	end
	-- keep profile.prestige.total in sync if you like:
	if profile.prestige then
		profile.prestige.total = total
	end
	return total
end

local function ensureLeaderstats(player)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		return ls
	end
	ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player
	return ls
end

function LeaderboardService.Attach(player)
	local profile = DataService:GetProfile(player)
	local ls = ensureLeaderstats(player)

	local doub = ls:FindFirstChild("Doubloons") or Instance.new("IntValue")
	doub.Name = "Doubloons"
	doub.Parent = ls

	local prest = ls:FindFirstChild("Prestige") or Instance.new("IntValue")
	prest.Name = "Prestige"
	prest.Parent = ls

	-- initial fill
	local wallet = (profile and profile.wallet) or {}
	doub.Value = wallet.doubloons or 0
	prest.Value = computePrestige(profile)
end

function LeaderboardService.Refresh(player)
	local profile = DataService:GetProfile(player)
	if not profile then
		return
	end

	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		return
	end

	local doub = ls:FindFirstChild("Doubloons")
	local prest = ls:FindFirstChild("Prestige")
	if doub then
		doub.Value = (profile.wallet and profile.wallet.doubloons) or 0
	end
	if prest then
		prest.Value = computePrestige(profile)
	end
end

-- Optional: expose prestige calc if others need it
function LeaderboardService.ComputePrestige(playerOrProfile)
	local profile = typeof(playerOrProfile) == "Instance" and DataService:GetProfile(playerOrProfile) or playerOrProfile
	return computePrestige(profile)
end

return LeaderboardService

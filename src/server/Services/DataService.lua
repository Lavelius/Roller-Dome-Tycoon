local DataService = {}
local _profiles = {}

local DataStoreService = game:GetService("DataStoreService")
local PROFILE_STORE = DataStoreService:GetDataStore("PlayerProfiles")

local function key(userId)
	return "profile_" .. tostring(userId)
end

local function reconcile(dst, srcDefaults)
	for k, v in pairs(srcDefaults) do
		if type(v) == "table" then
			dst[k] = type(dst[k]) == "table" and dst[k] or {}
			reconcile(dst[k], v)
		else
			if dst[k] == nil then
				dst[k] = v
			end
		end
	end
end

local function newDie()
	return {
		tier = 0,
		upgradesPurchased = {
			cooldown = 0,
			valueMultiplier = 0,
			additionalProjectiles = 0,
			power = 0,
		},
	}
end

local function newCannon()
	return {
		enabled = false,
		golden = false,
		autofireOwned = false,
		autofireEnabled = false,
		dice = {
			D4 = newDie(),
			D6 = newDie(),
			D8 = newDie(),
			D10 = newDie(),
			D12 = newDie(),
			D20 = newDie(),
		},
	}
end

local function newProfile()
	return {
		wallet = { doubloons = 0 },
		prestige = { total = 0 },
		cannons = { cannon1 = newCannon(), cannon2 = newCannon() },
	}
end

function DataService:LoadOrCreateProfile(player)
	local uid = player.UserId
	if _profiles[uid] then
		return _profiles[uid]
	end

	-- 1) Try to load
	local data
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return PROFILE_STORE:GetAsync(key(uid))
		end)
		if ok then
			data = result
			break
		end
		task.wait(attempt) -- tiny backoff: 1s, 2s
	end

	-- 2) If none, make a fresh profile
	if type(data) ~= "table" then
		data = newProfile()
	else
		-- 3) Reconcile to ensure any new fields exist
		reconcile(data, newProfile())
	end

	_profiles[uid] = data
	return data
end

function DataService:SaveProfile(who)
	print("Saving profile for", who)
	local uid = typeof(who) == "Instance" and who.UserId or who
	local data = _profiles[uid]
	if not data then
		return false
	end

	-- Never store Instances in datastores:
	data.station = nil

	local success = false
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			PROFILE_STORE:SetAsync(key(uid), data)
		end)
		if ok then
			success = true
			break
		end
		task.wait(attempt)
	end
	return success
end

-- Save all connected players once (returns how many succeeded)
function DataService:SaveAll()
	local Players = game:GetService("Players")
	local okCount = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if self:SaveProfile(p) then
			okCount += 1
		end
		-- Small yield helps respect DataStore budgets when many players are online
		task.wait(0.1)
	end
	return okCount
end

local _autosaveRunning = false

-- Start one autosave loop. Safe to call multiple times; it guards itself.
function DataService:StartAutoSave(intervalSeconds)
	if _autosaveRunning then
		return
	end
	_autosaveRunning = true
	intervalSeconds = intervalSeconds or 300 -- default 5 minutes

	task.spawn(function()
		while _autosaveRunning do
			task.wait(intervalSeconds)
			-- You can wrap in pcall if you want to be extra cautious:
			local ok, err = pcall(function()
				self:SaveAll()
			end)
			if not ok then
				warn("[DataService] Autosave error:", err)
			end
		end
	end)
end

function DataService:GetProfile(who)
	local uid = typeof(who) == "Instance" and who.UserId or who
	return _profiles[uid]
end

function DataService:DebugPrint()
	print("---- Profiles ----")
	for uid, profile in pairs(_profiles) do
		print("UserId:", uid, profile)
		for k, v in pairs(profile) do
			print("  ", k, v)
			if type(v) == "table" then
				for k2, v2 in pairs(v) do
					print("    ", k2, v2)
					if type(v2) == "table" then
						for k3, v3 in pairs(v2) do
							print("      ", k3, v3)
						end
					end
				end
			end
		end
	end
	print("------------------")
end

return DataService

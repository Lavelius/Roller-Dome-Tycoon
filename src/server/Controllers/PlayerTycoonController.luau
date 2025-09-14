local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ServerScriptService:WaitForChild("Server"):WaitForChild("ConfigFolder"):WaitForChild("Config"))
local CannonService =
	require(ServerScriptService:WaitForChild("Server"):WaitForChild("Services"):WaitForChild("CannonService"))
local PlayerDataService =
	require(ServerScriptService:WaitForChild("Server"):WaitForChild("Services"):WaitForChild("PlayerDataService"))

local Tycoon = {}
local function getPlayerFromHit(hit)
	local inst = hit
	for _ = 1, 4 do
		if not inst then
			break
		end
		local p = Players:GetPlayerFromCharacter(inst)
		if p then
			return p
		end
		inst = inst.Parent
	end
	return nil
end
function Tycoon._wirePlate(plate, ownerId, sationCF, cost, upgradeKey)
	local claimed = false
	plate.CanTouch = true
	plate.Touched:Connect(function(hit)
		if claimed then
			return
		end
		local plr = getPlayerFromHit(hit)
		if not plr or plr.userId ~= ownerId then
			return
		end
		if cost > 0 then
			local ok = PlayerDataService.trySpendDubloons(plr, cost)
			if not ok then
				print(("Not enough dubloons for %s (%d needed)"):format(plr.Name, cost))
				return
			end
		end
		claimed = true
		local placePos = plate.Position + Vector3.new(0, 0.1, 0)
		plate:Destroy()
		local _cannon = CannonService.spawnAt(placePos, sationCF, ownerId)
		local state = PlayerDataService.get(plr) or PlayerDataService.load(plr)
		state.upgrades[upgradeKey] = true
		print(("Built %s for %s"):format(upgradeKey, plr.Name))
	end)
end
function Tycoon.hydrate(player, podium, stationCF, upgrades)
	print(
		"hydrate:",
		player.Name,
		"plates:",
		podium:FindFirstChild("TycCannon1", true),
		podium:FindFirstChild("TycCannon2", true),
		"upgrades:",
		upgrades and upgrades.cannon1,
		upgrades and upgrades.cannon2
	)
	local ownerId = player.UserId
	local plate1 = podium:FindFirstChild("TycCannon1")
	local plate2 = podium:FindFirstChild("TycCannon2")
	if upgrades and upgrades.cannon and plate1 then
		local pos = plate1.Position + Vector3.new(0, 0.1, 0)
		plate1:Destroy()
		CannonService.spawnAt(pos, stationCF, ownerId)
		plate1 = nil
	end
	if upgrades and upgrades.cannon2 and plate2 then
		local pos = plate2.Position + Vector3.new(0, 0.1, 0)
		plate2:Destroy()
		CannonService.spawnAt(pos, stationCF, ownerId)
		plate2 = nil
	end
	if plate1 then
		Tycoon._wirePlate(plate1, ownerId, stationCF, Config.Costs.TycCannon1, "cannon1")
	end
	if plate2 then
		Tycoon._wirePlate(plate2, ownerId, stationCF, Config.Costs.TycCannon2, "cannon2")
	end
end
return Tycoon

local StationService = {}

local stations = {} -- reset

function StationService.init()
	local arena = workspace:WaitForChild("RollerOctodome")
	for i = 1, 8 do
		local wall = arena:FindFirstChild("wall" .. i)
		if not wall then
			warn("Missing wall" .. i)
			continue
		end
		local loading = wall:FindFirstChild("loadingZone")
		if not loading then
			warn(string.format("wall%d missing loadingZone", i))
			continue
		end
		table.insert(stations, { wall = wall, loadingZone = loading, owner = nil, podium = nil })
	end
end

function StationService.claimFree(player)
	for i, st in ipairs(stations) do
		if not st.owner then
			st.owner = player
			return i, st.loadingZone.WorldCFrame
		end
	end
	return nil, nil
end

function StationService.release(player)
	for _, station in ipairs(stations) do
		if station.owner == player then
			station.owner = nil
			if station.podium and station.podium.Parent then
				station.podium:Destroy()
			end
			station.podium = nil
			return true
		end
	end
	return false
end

function StationService.spawnPodium(player, stationId)
	local station = stations[stationId]
	if not station then
		warn("Invalid stationId:", stationId)
		return nil
	end

	station.owner = player

	local template = game.ServerStorage:FindFirstChild("Templates"):FindFirstChild("PlayerPodium")
	if not template then
		warn("ServerStorage.PlayerPodium not found")
		return nil
	end
	local podium = template:Clone()

	-- anchor all parts BEFORE parenting (less physics churn)
	for _, d in ipairs(podium:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end

	local cf = station.loadingZone.WorldCFrame
	local position = cf.Position + cf.UpVector * 11 + (-cf.LookVector * 0.5)
	local facing = cf.LookVector
	podium:PivotTo(CFrame.lookAt(position, position + facing))

	podium.Parent = workspace
	station.podium = podium
	return podium
end

function StationService.getStationCF(stationId)
	local st = stations[stationId]
	if not st then
		return nil
	end
	local att = st.loadingZone
	if not att or not att:IsA("Attachment") then
		return nil
	end
	return att.WorldCFrame
end

function StationService.getPlayerPodium(player)
	for _, station in ipairs(stations) do
		if station.owner == player then
			return station.podium
		end
	end
	return nil
end

return StationService

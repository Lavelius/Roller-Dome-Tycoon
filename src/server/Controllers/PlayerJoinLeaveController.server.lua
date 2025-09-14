-- intialization
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerFolder = ServerScriptService:WaitForChild("Server")
local ServicesFolder = ServerFolder:WaitForChild("Services")

local ptcInst = ServerFolder:WaitForChild("Controllers"):WaitForChild("PlayerTycoonController")
print("PTC class:", ptcInst.ClassName, "path:", ptcInst:GetFullName())

local okPDS, PlayerDataService = pcall(require, ServicesFolder:WaitForChild("PlayerDataService"))
local okSTS, StationService = pcall(require, ServicesFolder:WaitForChild("StationService"))
local okPTC, Tycoon = pcall(require, (ServerFolder:WaitForChild("Controllers"):WaitForChild("PlayerTycoonController")))

print("PDS require ok?", okPDS, "type:", typeof(PlayerDataService)) -- expect: true, "table"
print("STS require ok?", okSTS, "type:", typeof(StationService)) -- expect: true, "table"
print("PTC require ok?", okPTC, "type:", typeof(Tycoon)) -- expect: true, "table"
if not okPDS then
	error(PlayerDataService)
end
if not okSTS then
	error(StationService)
end
if not okPTC then
	error("PlayerTycoonController require failed: " .. tostring(Tycoon))
end

PlayerDataService.init()
StationService.init()

local function teleportToPodium(player)
	local function tp(char)
		local podium = StationService.getPlayerPodium(player)
		if not podium then
			return
		end

		local hrp = char:WaitForChild("HumanoidRootPart")
		-- Try SpawnLocation first; fallback to SpawnPart if that's your name
		local spawnPart = podium:FindFirstChild("SpawnLocation", true) or podium:FindFirstChild("SpawnPart", true)
		if spawnPart then
			hrp.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0) -- lift a bit to avoid clipping
		else
			warn("No spawn part on podium for", player.Name)
		end
	end

	-- If the character already exists, move them now
	if player.Character then
		tp(player.Character)
	end
	-- And also on future spawns
	player.CharacterAdded:Connect(tp)
end

-- Handle player join / spawn?
Players.PlayerAdded:Connect(function(player)
	print("Player joined:", player.Name)

	-- 1) Ensure in-memory state exists
	PlayerDataService.load(player)

	-- 2) Claim a free station
	local stationId, stationCF = StationService.claimFree(player)
	if not stationId then
		warn("No free stations available for", player.Name)
		return
	end
	print("Assigned station", stationId, "to", player.Name)
	PlayerDataService.assignStation(player, stationId)

	-- 3) Spawn & anchor the podium above the wall
	local podium = StationService.spawnPodium(player, stationId)
	if not podium then
		warn("Failed to spawn podium for", player.Name)
		return
	end

	-- Hydrate the podium (wiring up plates, cannons, etc)
	local state = PlayerDataService.get(player)
	Tycoon.hydrate(player, podium, stationCF, state.upgrades)

	-- 4) Teleport player to podium (now and on respawns)
	teleportToPodium(player)
end)

-- Handle player leaving / disconnect
Players.PlayerRemoving:Connect(function(player)
	print("Player leaving:", player.Name)

	-- Free their station (also destroys the podium)
	local released = StationService.release(player)
	if released then
		print("Released station for", player.Name)
	end

	-- Save their data (DataStore later)
	local ok, err = PlayerDataService.save(player)
	if not ok then
		warn("Save failed for", player.Name, err)
	end
end)

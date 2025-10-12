-- ServerScriptService/Boot.server.lua
local Players = game:GetService("Players")
local DataService = require(script.Parent.Services:WaitForChild("DataService"))
local StationService = require(script.Parent.Services:WaitForChild("StationService"))

--1) Init station index once when server boots
StationService.init()

--2) Start autosave loop
DataService:StartAutoSave(300) -- every 5 minutes

-- helper function to move player to a cframe safely
local function movePlayerTo(player, targetCF)
	if not targetCF then
		return
	end
	local function place(char)
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			-- Lift a bit to avoid clipping the floor
			hrp.CFrame = targetCF + Vector3.new(0, 3, 0)
		end
	end
	-- If character already exists, place now; also hook future spawns
	if player.Character then
		place(player.Character)
	end
	player.CharacterAdded:Connect(place)
end

Players.PlayerAdded:Connect(function(player)
	-- 2) Load or create their persistent profile
	local profile = DataService:LoadOrCreateProfile(player)

	-- 3) Claim a free station and spawn their podium
	local stationId, stationCF = StationService.claimFree(player)
	if not stationId then
		warn(("No free station for %s"):format(player.Name))
		return
	end

	-- 4) Spawn the podium
	StationService.spawnPodium(player, stationId)
	-- After spawning the podium:
	StationService.bindOfferPlates(player, stationId)

	-- 5) Move the player to their station
	local targetCF = StationService.getSpawnCF(stationId) or stationCF
	movePlayerTo(player, targetCF)

	-- 6) Hydrate station from profile data
	StationService.hydrateCannons(player, stationId, profile)

	print(("[Boot] %s claimed station %d"):format(player.Name, stationId))
end)

-- Save the profile when the player leaves this server
Players.PlayerRemoving:Connect(function(player)
	StationService.release(player)
	DataService:SaveProfile(player)
	print("Profile saved for", player.Name)
end)

-- Save all profiles in game when the server is shutting down
game:BindToClose(function()
	DataService:SaveAll()
	print("All profiles saved")
end)

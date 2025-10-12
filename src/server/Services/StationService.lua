-- ServerScriptService/StationService.lua
-- Handles station indexing, claiming, releasing, and podium spawning.

local StationService = {}

-- Internal storage of all stations
local stations = {} -- { {wall, loadingZone, ownerUserId, podium}, ... }

-- Cache templates for efficiency
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Templates = ServerStorage:WaitForChild("Templates")
local PodiumTemplate = Templates:WaitForChild("PlayerPodium")
local DoubloonHandler = require(script.Parent:WaitForChild("DoubloonHandlerService"))
local CannonService = require(script.Parent:WaitForChild("CannonService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
---------------------------------------------------------
-- Initialization
---------------------------------------------------------
function StationService.init()
	local arena = workspace:WaitForChild("RollerOctodome")
	stations = {} -- reset

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

		-- Create a clean data entry for each station
		table.insert(stations, {
			wall = wall,
			loadingZone = loading,
			ownerUserId = nil,
			podium = nil,
		})

		-- Initialize replicated attribute
		wall:SetAttribute("OwnerUserId", 0)
	end

	print("[StationService] Initialized", #stations, "stations.")
end

---------------------------------------------------------
-- Claim / Release
---------------------------------------------------------

-- Claim the first free station and return its index + spawn point
function StationService.claimFree(player)
	for i, st in ipairs(stations) do
		if not st.ownerUserId then
			st.ownerUserId = player.UserId
			st.wall:SetAttribute("OwnerUserId", player.UserId)
			return i, st.loadingZone.WorldCFrame, st.wall
		end
	end
	return nil, nil, nil
end

-- Release a player's station and destroy their podium
function StationService.release(player)
	local uid = player.UserId
	for _, st in ipairs(stations) do
		if st.ownerUserId == uid then
			st.ownerUserId = nil
			st.wall:SetAttribute("OwnerUserId", 0)

			if st.podium and st.podium.Parent then
				st.podium:Destroy()
			end
			st.podium = nil
			return true
		end
	end
	return false
end

---------------------------------------------------------
-- Podium Handling
---------------------------------------------------------

-- Spawn a podium at a claimed station (idempotent)
function StationService.spawnPodium(player, stationId)
	local st = stations[stationId]
	if not st then
		warn("Invalid stationId:", stationId)
		return nil
	end

	-- If it already exists, just return it
	if st.podium and st.podium.Parent then
		return st.podium
	end

	if not PodiumTemplate then
		warn("Podium template missing in ServerStorage.Templates")
		return nil
	end

	local podium = PodiumTemplate:Clone()

	-- Anchor everything before parenting (avoid physics chaos)
	for _, d in ipairs(podium:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end

	local cf = st.loadingZone.WorldCFrame
	local position = cf.Position + cf.UpVector * 11 + (-cf.LookVector * 0.5)
	local facing = cf.LookVector
	podium:PivotTo(CFrame.lookAt(position, position + facing))

	podium.Parent = workspace
	podium:SetAttribute("StationId", stationId)
	st.podium = podium

	local function markPlate(platePart: Instance, attrs: table)
		if not platePart or not platePart:IsA("BasePart") then
			return
		end
		for k, v in pairs(attrs) do
			platePart:SetAttribute(k, v)
		end
		CollectionService:AddTag(platePart, "OfferPlate")
	end

	-- Adjust these paths to match your podium model
	local platesFolder = podium:FindFirstChild("Plates") or podium
	local plate1 = platesFolder:FindFirstChild("Plate_Cannon1")
	local plate2 = platesFolder:FindFirstChild("Plate_Cannon2")

	-- Stamp metadata so CannonService can bind logic cleanly
	markPlate(plate1, {
		OfferId = "cannon1",
		Title = "Free Cannon",
		Cost = 0,
		Currency = "doubloons",
		Range = 14,
		CannonIndex = 1,
		StationId = stationId, -- <-- pass the current stationId from spawnPodium's scope
	})
	markPlate(plate2, {
		OfferId = "cannon2",
		Title = "Cannon 2",
		Cost = 5000,
		Currency = "doubloons",
		Range = 14,
		CannonIndex = 2,
		StationId = stationId,
	})

	return podium
end

local function playerFromHit(hit: BasePart)
	local char = hit and hit:FindFirstAncestorOfClass("Model")
	return char and Players:GetPlayerFromCharacter(char) or nil
end

function StationService.bindOfferPlates(player: Player, stationId: number)
	local st = stations[stationId]
	if not st or not st.podium then
		return
	end
	local podium = st.podium

	local debounces = setmetatable({}, { __mode = "k" })

	local function onPlateTouched(plate: BasePart, hit: BasePart)
		local p = playerFromHit(hit)
		if p ~= player then
			return
		end

		local plateStationId = tonumber(plate:GetAttribute("StationId") or -1)
		if plateStationId ~= stationId then
			return
		end

		if debounces[plate] then
			return
		end
		debounces[plate] = true
		task.delay(0.2, function()
			debounces[plate] = nil
		end)

		local offerId = tostring(plate:GetAttribute("OfferId") or "")
		local cannonIndex = tonumber(plate:GetAttribute("CannonIndex") or 0) or 0
		local cost = tonumber(plate:GetAttribute("Cost") or 0) or 0

		-- For now: Free Cannon (cannon1). Still flows through TryCharge for parity.
		if offerId == "cannon1" and cannonIndex == 1 then
			local ok = false
			do
				local charged, _ = DoubloonHandler.TryCharge(player, cost)
				ok = charged
			end
			if not ok then
				return
			end

			-- flip profile flag for hydration later
			local DataService = require(script.Parent.DataService)
			local profile = DataService:GetProfile(player)
			if profile and profile.cannons and profile.cannons.cannon1 then
				profile.cannons.cannon1.enabled = true
			end

			-- get facing from this station and spawn at plate
			local stationCF = StationService.getStationCF(stationId)
			local model = CannonService.SpawnAtPlate(player, plate, stationCF, 1)
			if model then
				plate:Destroy() -- remove plate after successful purchase
				print(("[StationService] Spawned Cannon 1 for %s at station %d"):format(player.Name, stationId))
			end
		end

		-- Later: cannon2 purchase (charge > 0, spawn, then destroy plate)
	end

	for _, obj in ipairs(podium:GetDescendants()) do
		if obj:IsA("BasePart") and obj:GetAttribute("OfferId") ~= nil then
			obj.Touched:Connect(function(hit)
				onPlateTouched(obj, hit)
			end)
		end
	end
end

function StationService.hydrateCannons(player: Player, stationId: number, profile)
	local st = stations[stationId]
	if not st or not st.podium then
		return
	end
	local podium = st.podium
	if not profile then
		profile = DataService:GetProfile(player)
	end
	if not profile or not profile.cannons then
		return
	end

	local stationCF = StationService.getStationCF(stationId)

	local function findPlate(name)
		return podium:FindFirstChild(name, true)
	end

	-- utility: safely remove a plate
	local function removePlate(plate)
		if not plate then
			return
		end
		-- either destroy or disable visually
		plate:Destroy()
		--[[ alternative if you prefer hiding:
		plate.CanTouch = false
		plate.CanCollide = false
		plate.Transparency = 0.75
		plate.Color = Color3.fromRGB(40,40,40)
		]]
	end

	-- Hydrate Cannon 1
	if profile.cannons.cannon1 and profile.cannons.cannon1.enabled then
		local plate = findPlate("Plate_Cannon1")
		if plate then
			removePlate(plate)
		end
		CannonService.SpawnAtPlate(player, plate or podium, stationCF, 1)
		print(("[Hydrate] Cannon1 hydrated for %s"):format(player.Name))
	end

	-- Hydrate Cannon 2
	if profile.cannons.cannon2 and profile.cannons.cannon2.enabled then
		local plate = findPlate("Plate_Cannon2")
		if plate then
			removePlate(plate)
		end
		CannonService.SpawnAtPlate(player, plate or podium, stationCF, 2)
		print(("[Hydrate] Cannon2 hydrated for %s"):format(player.Name))
	end
end

---------------------------------------------------------
-- Utility Getters
---------------------------------------------------------

-- Get a station's world CFrame (loadingZone)
function StationService.getStationCF(stationId)
	local st = stations[stationId]
	if not st then
		return nil
	end
	local node = st.loadingZone
	if not node then
		return nil
	end

	if node:IsA("Attachment") then
		return node.WorldCFrame
	elseif node:IsA("BasePart") then
		return node.CFrame
	end
	return nil
end

-- Get the podium owned by a specific player
function StationService.getPlayerPodium(player)
	local uid = player.UserId
	for _, st in ipairs(stations) do
		if st.ownerUserId == uid then
			return st.podium
		end
	end
	return nil
end

-- find which station a player owns
function StationService.getPlayerStationId(player)
	local uid = player.UserId
	for i, st in ipairs(stations) do
		if st.ownerUserId == uid then
			return i
		end
	end
	return nil
end

-- Get the podium at a specific station
function StationService.getPodium(stationId)
	local st = stations[stationId]
	return st and st.podium or nil
end

-- Return the best spawn CFrame for a claimed station:
-- 1) podium's SpawnLocation (Attachment or BasePart), else
-- 2) the station's loadingZone as a fallback.
function StationService.getSpawnCF(stationId)
	local st = stations[stationId]
	if not st then
		return nil
	end

	-- Prefer a marker on the spawned podium
	if st.podium then
		-- Look for a child named "SpawnLocation" anywhere under the podium
		local node = st.podium:FindFirstChild("SpawnLocation", true)
		if node then
			if node:IsA("Attachment") then
				return node.WorldCFrame
			elseif node:IsA("BasePart") then
				return node.CFrame
			end
		end
	end

	-- Fallback: station loading zone
	if st.loadingZone and st.loadingZone:IsA("Attachment") then
		return st.loadingZone.WorldCFrame
	end
	return nil
end
---------------------------------------------------------
return StationService

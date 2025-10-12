--local DeviceIdService = game:GetService("DeviceIdService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local WALLS_PARENT = workspace:WaitForChild("RollerOctodome")
local PODIUM_TEMPLATE = ServerStorage:WaitForChild("PlayerPodium")
local CANNON_TEMPLATE = ServerStorage:WaitForChild("DiceCannon")
local DICE_TEMPLATES = ServerStorage:WaitForChild("Dice")
local D4_TEMPLATE = DICE_TEMPLATES:WaitForChild("D4")
--local D6_TEMPLATE = DICE_TEMPLATES:WaitForChild("D6")
--local D8_TEMPLATE = DICE_TEMPLATES:WaitForChild("D8")
--local D10_TEMPLATE = DICE_TEMPLATES:WaitForChild("D10")
--local D12_TEMPLATE = DICE_TEMPLATES:WaitForChild("D12")
--local D20_TEMPLATE = DICE_TEMPLATES:WaitForChild("D20")
local ACTIVE_DICE = workspace:FindFirstChild("ActiveDice") or Instance.new("Folder")
ACTIVE_DICE.Name = "ActiveDice"
ACTIVE_DICE.Parent = workspace

local stations = {}
for i = 1, 8 do
	local wall = WALLS_PARENT:FindFirstChild("wall" .. i)
	local loading = wall:WaitForChild("loadingZone")
	table.insert(stations, { wall = wall, loadingZone = loading, owner = nil, podium = nil })
end

local function debugAttachments(dieModel)
	for _, att in ipairs(dieModel:GetDescendants()) do
		if att:IsA("Attachment") and att.Parent:IsA("BasePart") then
			print(
				att:GetFullName(),
				"FaceValue=",
				att:GetAttribute("FaceValue"),
				"dotUp(Look)=",
				att.WorldCFrame.LookVector:Dot(Vector3.yAxis),
				"dotUp(Up)=",
				att.WorldCFrame.UpVector:Dot(Vector3.yAxis),
				"dotUp(Right)=",
				att.WorldCFrame.RightVector:Dot(Vector3.yAxis)
			)
		end
	end
end

local function getAnyPart(inst)
	return inst:FindFirstChildWhichIsA("BasePart") or (inst:IsA("BasePart") and inst) or nil
end

local function unanchorAll(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
		end
	end
end

local function anchorAll(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
end

local function getMuzzleCF(muzzle)
	return muzzle:IsA("Attachments") and muzzle.WorldCFrame or muzzle.CFrame
end

local function isResting(part)
	return part.AssemblyLinearVelocity.Magnitude < 0.05 and part.AssemblyAngularVelocity.Magnitude < 0.05
end

local function readFaceValueFromAttachments(model)
	local bestAtt, bestDot = nil, -1e9
	for _, att in ipairs(model:GetDescendants()) do
		if att:IsA("Attachment") then
			local val = att:GetAttribute("FaceValue")
			if typeof(val) == "number" then
				local dot = att.WorldCFrame.LookVector:Dot(Vector3.yAxis) -- how “up” this face is
				if dot > bestDot then
					bestDot, bestAtt = dot, att
				end
			end
		end
	end
	return bestAtt and bestAtt:GetAttribute("FaceValue") or nil
end

local function startDieWatcher(die, ownerId)
	local part = getAnyPart(die)
	if not part then
		return
	end
	local stillSince = nil
	while die.Parent do
		if isResting(part) then
			stillSince = stillSince or time()
			if time() - stillSince > 0.6 then
				local value = readFaceValueFromAttachments(die)
				if value then
					local plr = Players:GetPlayerByUserId(ownerId)
					if plr and plr:FindFirstChild("leaderstats") then
						plr.leaderstats.Score.Value += value
						print(("Rolled %d for %s"):format(value, plr.Name))
					end
				else
					warn("No FaceValue found on attachments")
				end
				return
			end
		else
			stillSince = nil
		end
		task.wait(0.12)
	end
end

local POWER = 100
local function spawnAndLaunchFromMuzzle(muzzle, ownerId)
	local die = D4_TEMPLATE:Clone()
	die:SetAttribute("OwnerUserId", ownerId)
	task.spawn(function()
		startDieWatcher(die, ownerId)
	end)
	die.Parent = ACTIVE_DICE
	debugAttachments(die)

	local muzzleCF = getMuzzleCF(muzzle)
	local forward = -muzzleCF.LookVector
	local spawnCF = CFrame.new(muzzleCF.Position + forward * 1.5, muzzleCF.Position + forward * 2.5)

	if die:IsA("Model") then
		unanchorAll(die)
		die:PivotTo(spawnCF)
	else
		die.CFrame = spawnCF
		die.Anchored = false
	end

	local diePart = getAnyPart(die)
	if not diePart then
		warn("Spawned die has no BasePart")
		die:Destroy()
		return
	end

	diePart:SetNetworkOwner(nil)
	diePart.AssemblyLinearVelocity = Vector3.new()
	diePart.AssemblyAngularVelocity = Vector3.new()

	diePart.CanCollide = false
	task.delay(0.12, function()
		if diePart and diePart.Parent then
			diePart.CanCollide = true
		end
	end)

	local mass = diePart.AssemblyMass
	diePart:ApplyImpulse(forward * (POWER * mass))
	diePart:ApplyAngularImpulse(Vector3.new(math.random(), math.random(), math.random()) * (20 * mass))

	task.delay(20, function()
		if die and die.Parent then
			die:Destroy()
		end
	end)
end

local function teleportPlayerToPodium(player, podium)
	local function tp(char)
		local hrp = char:WaitForChild("HumanoidRootPart")
		-- tiny delay so the podium is in the world and anchored
		task.wait(0.1)
		local spawnPart = podium:FindFirstChild("SpawnLocation", true)
		if spawnPart and spawnPart:IsA("BasePart") then
			hrp.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
		end
	end

	-- if already spawned, move them now
	if player.Character then
		tp(player.Character)
	end

	-- and also on future respawns
	player.CharacterAdded:Connect(tp)
end

-- Gated cannon wiring
local function wireCannonForOwner(cannon, ownerPlayer)
	local button = cannon:WaitForChild("Button")
	local click = button:WaitForChild("ClickDetector")
	local muzzle = cannon:WaitForChild("Muzzle")
	local last = 0

	click.MouseClick:Connect(function(player)
		if player.UserId == ownerPlayer.UserId then
			print("Dice cannon used by", player.Name)
			if time() - last > 1 then
				spawnAndLaunchFromMuzzle(muzzle, ownerPlayer.UserId)
				last = time()
			end
		else
			print("Unauthorized dice cannon use attempt by", player.Name)
		end
	end)
end

local function setupTycoonPlate(plate, ownerPlayer, stationCF)
	local claimed = false
	local ownerId = ownerPlayer.UserId

	plate.Touched:Connect(function(hit)
		if claimed then
			return
		end
		local plr = hit and hit.Parent and Players:GetPlayerFromCharacter(hit.Parent)
		if not plr or plr.UserId ~= ownerId then
			return
		end

		claimed = true
		local placePos = plate.Position + Vector3.new(-8, 2, 0)
		plate:destroy()

		local inward = -stationCF.LookVector
		local baseCF = CFrame.lookAt(placePos, placePos + inward)
		local rollCF = CFrame.fromAxisAngle(Vector3.new(1, 0, 0), math.rad(-90))
		local cannonCF = baseCF * rollCF

		local cannon = CANNON_TEMPLATE:Clone()
		cannon:PivotTo(cannonCF)
		cannon.Parent = workspace
		wireCannonForOwner(cannon, ownerPlayer)
		print("Placed cannon for", ownerPlayer.Name)
	end)
end

local ownerByUserId = {}

local function placePodiumAtLoadingZone(podium, loadingAttachment, heightOffset, inwardOffset)
	local cf = loadingAttachment.WorldCFrame
	local up = cf.UpVector
	local inward = cf.LookVector -- opposite of wall's outward normal

	local pos = cf.Position + up * (heightOffset or 11) + inward * (inwardOffset or 0.5)
	-- Face the podium inward
	local podiumCF = CFrame.lookAt(pos, pos + inward)

	podium:PivotTo(podiumCF)
end

local function assignStation(player)
	for _, st in ipairs(stations) do
		if not st.owner then
			local podium = PODIUM_TEMPLATE:Clone()
			anchorAll(podium)
			teleportPlayerToPodium(player, podium)
			podium:SetAttribute("OwnerUserId", player.UserId)
			podium.Parent = workspace
			placePodiumAtLoadingZone(podium, st.loadingZone, 11, 0.5)

			local plate1 = podium:FindFirstChild("TycCannon1", true)
			local plate2 = podium:FindFirstChild("TycCannon2", true)
			if plate1 then
				setupTycoonPlate(plate1, player, st.loadingZone.CFrame)
			end
			if plate2 then
				setupTycoonPlate(plate2, player, st.loadingZone.CFrame)
			end

			st.owner = player
			st.podium = podium
			ownerByUserId[player.UserId] = st

			player.CharacterAdded:Connect(function(char)
				local hrp = char:WaitForChild("HumanoidRootPart")
				local spawnPart = podium:FindFirstChild("SpawnPart", true)
				if spawnPart then
					hrp.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
				end
			end)
			return
		end
	end
	print("No available stations for", player.Name)
end

local function releaseStation(player)
	local st = ownerByUserId[player.UserId]
	if not st then
		return
	end
	ownerByUserId[player.UserId] = nil
	if st.podium and st.podium.Parent then
		st.podium:Destroy()
	end
	st.podium = nil
end

---- Spawning Event ----

Players.PlayerAdded:Connect(assignStation)
Players.PlayerRemoving:Connect(releaseStation)

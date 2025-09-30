-- setup

local ServerStorage = game:GetService("ServerStorage")
local ShopService = require(script.Parent:WaitForChild("ShopService"))
local Config = require(
	game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("ConfigFolder"):WaitForChild("Config")
)
local DiceService = require(script.Parent:WaitForChild("DiceService"))

local CannonService = {}

local Templates = ServerStorage:WaitForChild("Templates")
local CannonTemplate = Templates:WaitForChild("DiceCannon")

function CannonService.spawnAt(placePos, stationCF, ownerId, parentInstance, cannonKey)
	local inward = -stationCF.LookVector
	local up = Vector3.yAxis
	local baseCF = CFrame.lookAt(placePos, placePos + inward, up)

	-- rotation trim (local)
	local lr = (Config.Cannon and Config.Cannon.LocalRotationDeg) or {}
	local rx, ry, rz = math.rad(lr.x or 0), math.rad(lr.y or 0), math.rad(lr.z or 0)

	-- position trim (local)
	local lp = (Config.Cannon and Config.Cannon.LocalPositionOffset) or {}
	local px, py, pz = lp.x or 0, lp.y or 0, lp.z or 0

	-- apply: aim → rotate → translate (all in local space)
	local finalCF = baseCF * CFrame.Angles(rx, ry, rz) * CFrame.new(px, py, pz)

	local cannon = CannonTemplate:Clone()
	cannon:SetAttribute("OwnerUserId", ownerId)
	cannon:SetAttribute("CannonKey", cannonKey)
	cannon:PivotTo(finalCF)
	cannon.Parent = parentInstance or workspace:FindFirstChild("Cannons") or workspace
	CannonService.wire(cannon)
	return cannon
end

function CannonService.wire(cannon)
	local button = cannon:WaitForChild("Barrel"):WaitForChild("Button")
	local click = button:WaitForChild("ClickDetector")
	local muzzle = cannon:WaitForChild("Barrel"):WaitForChild("Muzzle")

	click.MaxActivationDistance = Config.Cannon.ClickDistance or 64

	local ownerId = tonumber(cannon:GetAttribute("OwnerUserId"))
	local cannonKey = cannon:GetAttribute("CannonKey") or "cannon1"
	local lastFired = 0
	local cooldown = Config.Cannon.CooldownSec or 1.0

	click.MouseClick:Connect(function(player)
		if player.UserId ~= ownerId then
			return
		end

		local now = time()
		if now - lastFired < cooldown then
			return
		end
		lastFired = now

		print(player.Name, "Fired their cannon!")
		local _roll, _sides = DiceService.fire(muzzle, ownerId, cannonKey)
	end)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UpgradePrompt"
	prompt.ActionText = "Upgrade Die"
	prompt.ObjectText = "Cannon"
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.Parent = button

	prompt.Triggered:Connect(function(player)
		if player.UserId ~= ownerId then
			return
		end
		ShopService.upgradeDie(player, cannonKey) -- server validates + charges + sets new sides//
	end)

	-- GREEN BUTTONS: any part with Number attr 'YawDeltaDeg'
	for _, d in ipairs(cannon:GetDescendants()) do
		if d:IsA("BasePart") then
			local delta = d:GetAttribute("YawDeltaDeg")
			if typeof(delta) == "number" then
				local cd = d:FindFirstChildWhichIsA("ClickDetector") or Instance.new("ClickDetector", d)
				cd.MaxActivationDistance = 16
				cd.MouseClick:Connect(function(player)
					CannonService.nudgeYaw(cannon, delta, player)
				end)
			end
		end
	end
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder", ReplicatedStorage)
	Remotes.Name = "Remotes"
	local OpenShop = Remotes:FindFirstChild("OpenShop") or Instance.new("RemoteEvent", Remotes)
	OpenShop.Name = "OpenShop"

	for _, d in ipairs(cannon:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("OpensShop") == true then
			local cd = d:FindFirstChildWhichIsA("ClickDetector") or Instance.new("ClickDetector", d)
			cd.MaxActivationDistance = 16
			cd.MouseClick:Connect(function(player)
				if player.UserId ~= ownerId then
					return
				end
				OpenShop:FireClient(player, cannonKey) -- client opens the UI
			end)
		end
	end
end

local function v3Attr(inst, name, fallback)
	local v = inst:GetAttribute(name)
	return typeof(v) == "Vector3" and v or fallback
end

function CannonService.realign(cannon)
	local pos = cannon:GetPivot().Position
	local up = v3Attr(cannon, "StationUp", Vector3.yAxis)
	local inward0 = v3Attr(cannon, "StationInward", -Vector3.zAxis)
	local yawDeg = cannon:GetAttribute("YawDeg") or 0

	-- rotate the base "inward" around 'up' by yawDeg (local yaw)
	local rot = CFrame.fromAxisAngle(up.Unit, math.rad(yawDeg))
	local dir = rot:VectorToWorldSpace(inward0)

	local base = CFrame.lookAt(pos, pos + dir, up)
	local lr = Config.Cannon.LocalRotationDeg or {}
	local lp = Config.Cannon.LocalPositionOffset or {}

	local final = base
		* CFrame.Angles(math.rad(lr.x or 0), math.rad(lr.y or 0), math.rad(lr.z or 0))
		* CFrame.new(lp.x or 0, lp.y or 0, lp.z or 0)

	cannon:PivotTo(final)
end

function CannonService.nudgeYaw(cannon, deltaDeg, player)
	local ownerId = cannon:GetAttribute("OwnerUserId")
	if not player or player.UserId ~= ownerId then
		return
	end
	local yaw = cannon:GetAttribute("YawDeg") or 0
	yaw = yaw + (deltaDeg or 0)
	-- keep it tidy (0..360)
	yaw = (yaw % 360 + 360) % 360
	cannon:SetAttribute("YawDeg", yaw)
	CannonService.realign(cannon)
end

return CannonService

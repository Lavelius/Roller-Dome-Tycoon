-- setup

local ServerStorage = game:GetService("ServerStorage")
local Config = require(
	game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("ConfigFolder"):WaitForChild("Config")
)
local DiceService = require(script.Parent:WaitForChild("DiceService"))

local CannonService = {}

local Templates = ServerStorage:WaitForChild("Templates")
local CannonTemplate = Templates:WaitForChild("DiceCannon")

function CannonService.spawnAt(placePos, stationCF, ownerId, parentInstance)
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
	cannon:PivotTo(finalCF)
	cannon.Parent = parentInstance or workspace:FindFirstChild("Cannons") or workspace
	CannonService.wire(cannon)
	return cannon
end

function CannonService.wire(cannon)
	local button = cannon:WaitForChild("Button")
	local click = button:WaitForChild("ClickDetector")
	local muzzle = cannon:WaitForChild("Muzzle")

	click.MaxActivationDistance = Config.Cannon.ClickDistance or 64

	local ownerId = tonumber(cannon:GetAttribute("OwnerUserId"))
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
		local _roll, _sides = DiceService.fire(muzzle, ownerId)
	end)
end

return CannonService

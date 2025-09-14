-- setup

local ServerStorage = game:GetService("ServerStorage")
local Config = require(
	game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("ConfigFolder"):WaitForChild("Config")
)

local CannonService = {}

local Templates = ServerStorage:WaitForChild("Templates")
local CannonTemplate = Templates:WaitForChild("DiceCannon")

function CannonService.spawnAt(placePos, stationCF, ownerId)
	-- Aim the cannon inward; keep it upright
	local inward = -stationCF.LookVector
	local up = Vector3.yAxis -- or: stationCF.UpVector if you want wall-relative up
	local baseCF = CFrame.lookAt(placePos, placePos + inward, up)

	-- Local-axis trim from Config (degrees → radians)
	local lr = (Config.Cannon and Config.Cannon.LocalRotationDeg) or {}
	local rx = math.rad(lr.x or 0) -- pitch  (around local X/right)
	local ry = math.rad(lr.y or 0) -- yaw    (around local Y/up)
	local rz = math.rad(lr.z or 0) -- roll   (around local Z/forward)

	-- Apply AFTER aiming so it rotates in the cannon's local space
	local finalCF = baseCF * CFrame.Angles(rx, ry, rz)

	-- Spawn
	local cannon = CannonTemplate:Clone()
	cannon:SetAttribute("OwnerUserId", ownerId)
	cannon:PivotTo(finalCF)
	cannon.Parent = workspace:FindFirstChild("Cannons") or workspace
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
	end)
end

return CannonService

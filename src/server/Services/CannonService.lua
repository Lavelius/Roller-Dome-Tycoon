-- ServerScriptService/Services/CannonService.lua
-- Minimal: spawn a cannon using a floorplate as the reference.
-- NOTE: No require of StationService here to avoid circular requires.

local CannonService = {}

local ServerStorage = game:GetService("ServerStorage")
local Templates = ServerStorage:WaitForChild("Templates")
local CannonTemplate = Templates:WaitForChild("DiceCannon")
local DataService = require(script.Parent:WaitForChild("DataService"))
local TweenService = game:GetService("TweenService")
local DiceService = require(script.Parent:WaitForChild("DiceService"))

-- Place a model at an Instance's transform (BasePart or Attachment)
local function pivotToNode(model: Model, node: Instance)
	if node:IsA("Attachment") then
		model:PivotTo(node.WorldCFrame)
	elseif node:IsA("BasePart") then
		model:PivotTo(node.CFrame)
	else
		warn("[CannonService] pivot node must be BasePart/Attachment:", node:GetFullName())
	end
end

---------------------------------------------------------------------
-- 🔫 FIRE BEHAVIOR
---------------------------------------------------------------------
local MIN_COOLDOWN = 0.2

local function doFire(cannon, player)
	if not cannon or not cannon:IsDescendantOf(workspace) then
		return
	end
	if player.UserId ~= cannon:GetAttribute("OwnerUserId") then
		return
	end

	-- cooldown guard (per cannon)
	local now = time()
	local last = cannon:GetAttribute("LastFireT") or 0
	if now - last < MIN_COOLDOWN then
		return
	end
	cannon:SetAttribute("LastFireT", now)

	-- parts
	local barrel = cannon:FindFirstChild("Barrel")
	local muzzle = barrel and barrel:FindFirstChild("Muzzle")
	if not barrel or not muzzle then
		warn("[CannonService] Missing Barrel or Muzzle")
		return
	end

	-- which die to fire (let Cannon hold the selection)
	local dieId = cannon:GetAttribute("CurrentDieId") or "D4"

	-- 1) SOUND (play first so it feels instant). Prefer a BasePart emitter.
	local emitter = muzzle:IsA("Attachment") and muzzle.Parent or muzzle
	if emitter and emitter:IsA("BasePart") then
		local s = emitter:FindFirstChild("FireSound")
		if not s then
			s = Instance.new("Sound")
			s.Name = "FireSound"
			s.SoundId = "rbxassetid://2228998125"
			s.Volume = 1.5
			s.RollOffMode = Enum.RollOffMode.Inverse
			s.MaxDistance = 200
			s.Parent = emitter
		end
		s:Play()
	end

	-- 2) RECOIL (move BACK along the muzzle's forward)
	local isModel = barrel:IsA("Model")
	local startCF = isModel and barrel:GetPivot() or barrel.CFrame

	local look = (muzzle:IsA("Attachment") and muzzle.WorldCFrame.LookVector) or muzzle.CFrame.LookVector
	local recoilDir = -look -- backward
	local recoilDist = 0.45 -- shorter = nicer
	local backCF = CFrame.new(recoilDir * recoilDist) * startCF

	if isModel then
		barrel:PivotTo(backCF)
		task.wait(0.06)
		barrel:PivotTo(startCF)
	else
		barrel.CFrame = backCF
		task.wait(0.06)
		barrel.CFrame = startCF
	end

	-- 3) VFX: small explosion at muzzle
	local pos = muzzle:IsA("Attachment") and muzzle.WorldPosition or muzzle.Position
	local explosion = Instance.new("Explosion")
	explosion.BlastPressure = 0
	explosion.BlastRadius = 4
	explosion.Position = pos
	explosion.Parent = workspace

	-- 4) FIRE the die (DiceService handles physics + payout)
	local ownerId = cannon:GetAttribute("OwnerUserId")
	DiceService.fire(muzzle, ownerId, dieId)
end

---------------------------------------------------------------------
-- 🧠 WIRING
---------------------------------------------------------------------
function CannonService.WireCannon(cannon)
	local button = cannon:WaitForChild("Barrel"):WaitForChild("Button")
	local click = button:FindFirstChildWhichIsA("ClickDetector")
	if not click then
		click = Instance.new("ClickDetector", button)
		click.MaxActivationDistance = 32
	end

	click.MouseClick:Connect(function(player)
		doFire(cannon, player)
	end)
end

-- Spawns & returns the cannon Model at the given plate.
-- stationCF: CFrame that indicates the *inward* facing (from StationService).
-- cannonIndex: 1 or 2. CurrentDie defaults to D4.
function CannonService.SpawnAtPlate(player: Player, plate: BasePart, stationCF: CFrame?, cannonIndex: number)
	if not player or not plate or not plate:IsA("BasePart") then
		return nil
	end

	local model = CannonTemplate:Clone()

	-- Anchor before parenting to avoid physics pops
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end

	if stationCF then
		local placePos = plate.Position
		local inward = -stationCF.LookVector
		local up = stationCF.UpVector
		local baseCF = CFrame.lookAt(placePos, placePos + inward, up)

		-- tweak these three values to move the cannon in local space
		local sideOffset = 0 -- +X = right, -X = left
		local heightOffset = 4 -- +Y = up, -Y = down
		local forwardOffset = 4 -- +Z = forward, -Z = backward

		local offsetCF = CFrame.new(sideOffset, heightOffset, forwardOffset)

		-- apply position offset + your existing rotation correction
		model:PivotTo(baseCF * offsetCF * CFrame.Angles(math.rad(-90), 0, math.rad(-90)))
	else
		-- Fallback: align exactly with the plate
		pivotToNode(model, plate)
	end

	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("CannonIndex", cannonIndex)
	model:SetAttribute("CurrentDieId", "D4") -- default

	model.Parent = workspace

	CannonService.WireCannon(model)

	return model
end

return CannonService

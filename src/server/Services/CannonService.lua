-- ServerScriptService/Services/CannonService.lua
-- Minimal: spawn a cannon using a floorplate as the reference.
-- NOTE: No require of StationService here to avoid circular requires.

local CannonService = {}

local ServerStorage = game:GetService("ServerStorage")
local Templates = ServerStorage:WaitForChild("Templates")
local CannonTemplate = Templates:WaitForChild("DiceCannon")

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
	return model
end

return CannonService

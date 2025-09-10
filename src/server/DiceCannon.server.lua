print("Dice Cannon script running")

local diceFolder = workspace:WaitForChild("Dice")
local die = diceFolder:WaitForChild("D4")
local buttonPart = workspace:WaitForChild("Dice"):WaitForChild("Button")
local click = buttonPart:WaitForChild("ClickDetector")

local POWER = 12000

local diePart = die:IsA("Model") and (die.PrimaryPart or die:FindFirstChildWhichIsA("BasePart")) or die
if not diePart then
	warn("D4 has no BasePart/PrimaryPart to push")
	return
end

local function launchD4()
	if diePart.Anchored then
		diePart.Anchored = false
	end
	diePart.AssemblyLinearVelocity = Vector3.new()
	diePart.AssemblyAngularVelocity = Vector3.new()
	local dir = (Vector3.new(0, 1, 1)).Unit
	diePart:ApplyImpulse(dir * POWER)
	print(diePart)
end

click.MouseClick:Connect(function(player)
	print(player.Name .. " clicked the button to roll the D4")
	launchD4()
end)

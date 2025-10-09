print("Dice Cannon script running")

--define the folders where gameobjects other shared files are located
local ServerStorage = game:GetService("ServerStorage")
--local ReplicatedStorage = game:GetService("ReplicatedStorage")

local templateParent = ServerStorage
local DICE_TEMPLATE = templateParent:WaitForChild("Dice"):WaitForChild("D4")

local cannon = workspace:WaitForChild("DiceCannonModel")
local button = cannon:WaitForChild("Button")
local click = button:WaitForChild("ClickDetector")
local muzzle = cannon:WaitForChild("Muzzle")

local POWER = 100

local activeFolder = workspace:FindFirstChild("ActiveDice") or Instance.new("Folder")
activeFolder.Parent = workspace
activeFolder.Name = "ActiveDice"

-- this returns the location the dice should spawn from
local function getMuzzleWorldCFrame()
	return muzzle.CFrame
end

--returns the basepart of a model for applying forces
local function getAnyPart(modelOrPart)
	if modelOrPart:IsA("BasePart") then
		return modelOrPart
	else
		return modelOrPart:FindFirstChildWhichIsA("BasePart")
	end
end

--preparation for launching objects by unachoring all parts in a model
local function unanchorAll(model)
	for _, d in ipairs(model.GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
		end
	end
end

local function spawnAndLaunch()
	-- 1) Clone
	local die = DICE_TEMPLATE:Clone()
	die.Parent = activeFolder

	-- 2) Choose a spawn position in front of the button, in front of the cannon itself
	local muzzleCF = getMuzzleWorldCFrame()
	local forward = -muzzleCF.LookVector

	local spawnCF = CFrame.new(muzzleCF.Position + forward * 0.75, muzzleCF.Position + forward * 1.75)

	if die:IsA("Model") then
		unanchorAll(die)
		die:PivotTo(spawnCF)
	else
		die.CFrame = spawnCF
		die.Anchored = false
	end

	-- 3) Get the physical part to push
	local diePart = getAnyPart(die)
	if not diePart then
		warn("Spawned die has no BasePart")
		die:Destroy()
		return
	end

	-- Ensure the server ownes the phsyics
	diePart:SetNetworkOwner(nil)

	-- 4) Reset motion & apply impulse (scaled by mass so POWER feels consistant)
	diePart.AssemblyLinearVelocity = Vector3.new()
	diePart.AssemblyAngularVelocity = Vector3.new()

	local mass = diePart.AssemblyMass
	local impulse = forward * (POWER * mass)

	diePart:ApplyImpulse(impulse)
	diePart:ApplyAngularImpulse(Vector3.new(math.random(), math.random(), math.random()) * (20 * mass))

	-- 5) Auto cleanup after 20 seconds
	task.delay(20, function()
		if die and die.Parent then
			die:Destroy()
		end
	end)
end

click.MouseClick:Connect(function(player)
	print("Dice cannon used by", player.Name)
	spawnAndLaunch()
end)
--ajsdf;lkajsdf asdfasdfa asdfasdf
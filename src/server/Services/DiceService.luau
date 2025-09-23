local TweenService = game:GetService("TweenService")

local Config = require(
	game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("ConfigFolder"):WaitForChild("Config")
)
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local DiceService = {}

local DICE_FOLDER = ServerStorage:WaitForChild("Templates"):WaitForChild("Dice")
local RNG = Random.new()
local POWER = 100

local function getAnyPart(inst)
	if inst:IsA("BasePart") then
		return inst
	end
	if inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
	end
end

local function unanchorAll(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
		end
	end
end

local function isResting(part)
	return part.AssemblyLinearVelocity.Magnitude < (Config.Dice.RestLin or 0.15)
		and part.AssemblyAngularVelocity.Magnitude < (Config.Dice.RestAng or 0.15)
end

local function chooseTemplateFor(player)
	local sides = PlayerDataService.getDieSides(player) -- 4/6/8/10/12/20
	local name = "D" .. tostring(sides)
	local tpl = DICE_FOLDER:FindFirstChild(name)
	if not tpl then
		warn("Dice template missing:", name, "— defaulting to D4")
		tpl = DICE_FOLDER:FindFirstChild("D4")
	end
	return tpl, sides
end

local function showPopup(part, text)
	local bill = Instance.new("BillboardGui")
	bill.Name = "RollPopup"
	bill.Adornee = part
	bill.AlwaysOnTop = true
	bill.Size = UDim2.fromOffset(100, 40)
	bill.StudsOffset = Vector3.new(0, 2, 0)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Text = text
	label.Parent = bill

	bill.Parent = part

	-- fade out
	local t = TweenService:Create(
		label,
		TweenInfo.new(Config.Dice.PopupLife or 1.2),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	t:Play()
	task.delay((Config.Dice.PopupLife or 1.2) + 0.1, function()
		if bill then
			bill:Destroy()
		end
	end)
end

local function watchAndPayout(die, part, ownerId, sides)
	local dwellStart = nil
	local deadline = time() + (Config.Dice.MaxWait or 8)

	while die.Parent and time() < deadline do
		if isResting(part) then
			dwellStart = dwellStart or time()
			if time() - dwellStart >= (Config.Dice.RestDwell or 0.6) then
				-- landed: score it now
				local roll = RNG:NextInteger(1, sides)
				local player = Players:GetPlayerByUserId(ownerId)
				if player then
					PlayerDataService.addDubloons(player, roll)
					showPopup(part, ("+%d"):format(roll))
				end
				-- NEW: fast despawn after popup
				local delaySec = Config.Dice.DespawnAfterScore or (Config.Dice.PopupLife or 1.2)
				task.delay(delaySec, function()
					if die and die.Parent then
						die:Destroy()
					end
				end)
				return
			end
		else
			dwellStart = nil
		end
		task.wait(0.12)
	end

	-- Fallback if it never really “rests”
	local roll = RNG:NextInteger(1, sides)
	local player = game:GetService("Players"):GetPlayerByUserId(ownerId)
	if player then
		PlayerDataService.addDubloons(player, roll)
		if part.Parent then
			showPopup(part, ("+%d"):format(roll))
		end
	end
end

-- muzzle: Attachment or Part; ownerId: number
function DiceService.fire(muzzle, ownerId, cannonKey)
	local player = game:GetService("Players"):GetPlayerByUserId(ownerId)
	if not player then
		return
	end

	-- choose template by player’s current dieSides
	local sides = PlayerDataService.getDieSides(player, cannonKey) -- 4/6/8/10/12/20
	local name = "D" .. tostring(sides)
	local template = DICE_FOLDER:FindFirstChild(name)
	if not template then
		warn("Dice template missing:", name, "— defaulting to D4 from Templates/Dice")
		template = DICE_FOLDER:FindFirstChild("D4")
		sides = 4
	end

	-- spawn & place
	local muzzleCF = muzzle:IsA("Attachment") and muzzle.WorldCFrame or muzzle.CFrame
	local dir = muzzleCF.LookVector

	local die = template:Clone()
	die.Parent = workspace:FindFirstChild("ActiveDice") or workspace

	local spawnCF = CFrame.new(muzzleCF.Position + dir * 1.5, muzzleCF.Position + dir * 2.5)
	if die:IsA("Model") then
		unanchorAll(die)
		die:PivotTo(spawnCF)
	else
		die.Anchored = false
		die.CFrame = spawnCF
	end

	-- push
	local part = getAnyPart(die)
	if not part then
		die:Destroy()
		return
	end
	part:SetNetworkOwner(nil)
	part.AssemblyLinearVelocity = Vector3.new()
	part.AssemblyAngularVelocity = Vector3.new()
	part.CanCollide = false
	task.delay(0.12, function()
		if part.Parent then
			part.CanCollide = true
		end
	end)
	local mass = part.AssemblyMass
	part:ApplyImpulse(-dir * (POWER * mass))
	part:ApplyAngularImpulse(Vector3.new(0, 1, 1) * (POWER * mass * 0.5))

	-- watch for landing + payout
	task.spawn(function()
		watchAndPayout(die, part, ownerId, sides)
		-- cleanup after a bit
		task.delay(20, function()
			if die and die.Parent then
				die:Destroy()
			end
		end)
	end)
end

return DiceService

--wooby wobby wubbly goo wompy swampy goo goo ga ga wompy

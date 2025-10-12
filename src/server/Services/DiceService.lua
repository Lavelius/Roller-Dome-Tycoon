-- ServerScriptService/Services/DiceService.lua
-- Minimal, focused dice spawner/firer.
-- API: DiceService.fire(muzzle: Attachment|BasePart, ownerId: number, dieId: "D4"|"D6"|... )

local DiceService = {}

local TweenService = game:GetService("TweenService")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local DoubloonHandler = require(script.Parent:WaitForChild("DoubloonHandlerService"))

-- Assets
local TEMPLATES = ServerStorage:WaitForChild("Templates")
local DICE_FOLDER = TEMPLATES:WaitForChild("Dice")

-- Tunables (keep these simple & local for now)
local POWER = 110 -- forward speed-ish (impulse will scale by mass)
local ANGULAR_POWER = 0.5 -- spin intensity multiplier
local REST_LIN_THRESH = 0.15 -- how "still" linear (stud/s)
local REST_ANG_THRESH = 0.15 -- how "still" angular (rad/s)
local REST_DWELL_SEC = 0.60 -- must be still this long to count as landed
local MAX_WAIT_SEC = 8.0 -- give up and score anyway if never truly rests
local DIE_LIFETIME_SEC = 20 -- hard cleanup
local POPUP_LIFE_SEC = 1.2 -- how long the +N popup lives

local RNG = Random.new()

-- ---------- small helpers ----------
local function getAnyPart(inst: Instance): BasePart?
	if inst:IsA("BasePart") then
		return inst
	end
	if inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
	end
	return nil
end

local function unanchorAll(model: Instance)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
		end
	end
end

local function isResting(part: BasePart): boolean
	return part.AssemblyLinearVelocity.Magnitude < REST_LIN_THRESH
		and part.AssemblyAngularVelocity.Magnitude < REST_ANG_THRESH
end

local function showPopup(part: BasePart, text: string)
	local bill = Instance.new("BillboardGui")
	bill.Name = "RollPopup"
	bill.Adornee = part
	bill.AlwaysOnTop = true
	bill.Size = UDim2.fromOffset(110, 42)
	bill.StudsOffset = Vector3.new(0, 2, 0)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Text = text
	label.Parent = bill

	bill.Parent = part

	local tween =
		TweenService:Create(label, TweenInfo.new(POPUP_LIFE_SEC), { TextTransparency = 1, TextStrokeTransparency = 1 })
	tween:Play()
	task.delay(POPUP_LIFE_SEC + 0.1, function()
		if bill then
			bill:Destroy()
		end
	end)
end

local function parseSides(dieId)
	-- dieId might be nil or not a string; normalize first
	local s = tostring(dieId or "")
	-- grab the first number sequence (e.g., "D20" -> "20")
	local digits = s:match("%d+")
	local n = tonumber(digits)
	return n or 4
end

-- ---------- landing & payout ----------
local function watchAndPayout(die: Instance, mainPart: BasePart, ownerId: number, sides: number)
	local dwellStart: number? = nil
	local deadline = time() + MAX_WAIT_SEC

	while die.Parent and time() < deadline do
		if isResting(mainPart) then
			dwellStart = dwellStart or time()
			if time() - dwellStart >= REST_DWELL_SEC then
				-- Landed: score 1..sides
				local roll = RNG:NextInteger(1, sides)
				DoubloonHandler.Grant(ownerId, roll)
				showPopup(mainPart, ("+%d"):format(roll))
				-- quick cleanup a moment after popup finishes
				task.delay(POPUP_LIFE_SEC, function()
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

	-- Fallback: never really rested — still award something
	local roll = RNG:NextInteger(1, sides)
	DoubloonHandler.Grant(ownerId, roll)
	if mainPart.Parent then
		showPopup(mainPart, ("+%d"):format(roll))
	end
end

-- ---------- public API ----------
-- muzzle: Attachment or BasePart
-- ownerId: number (UserId)
-- dieId: "D4"/"D6"/... (string)
function DiceService.fire(muzzle: Instance, ownerId: number, dieId: string)
	local player = Players:GetPlayerByUserId(ownerId)
	if not player then
		return
	end

	-- choose template by dieId
	local tpl = DICE_FOLDER:FindFirstChild(dieId)
	if not tpl then
		warn("[DiceService] Missing template for", dieId, "— defaulting to D4")
		tpl, dieId = DICE_FOLDER:FindFirstChild("D4"), "D4"
	end
	if not tpl then
		return
	end

	local sides = parseSides(dieId)

	-- spawn ahead of muzzle, aiming forward
	local muzzleCF = muzzle:IsA("Attachment") and muzzle.WorldCFrame or (muzzle :: BasePart).CFrame
	local dir = -muzzleCF.LookVector

	local die = tpl:Clone()
	die.Parent = workspace:FindFirstChild("ActiveDice") or workspace

	local spawnCF = CFrame.new(muzzleCF.Position + dir * 1.5, muzzleCF.Position + dir * 3.0)

	local mainPart = getAnyPart(die)
	if not mainPart then
		die:Destroy()
		return
	end

	if die:IsA("Model") then
		unanchorAll(die)
		die:PivotTo(spawnCF)
	else
		(die :: BasePart).Anchored = false
		(die :: BasePart).CFrame = spawnCF
	end

	-- physics kick
	mainPart:SetNetworkOwner(nil) -- server owns it for consistency
	mainPart.AssemblyLinearVelocity = Vector3.zero
	mainPart.AssemblyAngularVelocity = Vector3.zero

	-- briefly disable collide to avoid clipping the muzzle
	mainPart.CanCollide = false
	task.delay(0.10, function()
		if mainPart.Parent then
			mainPart.CanCollide = true
		end
	end)

	local mass = mainPart.AssemblyMass
	mainPart:ApplyImpulse(dir * (POWER * mass))
	local randomSpin = Vector3.new(RNG:NextNumber(-1, 1), RNG:NextNumber(-1, 1), RNG:NextNumber(-1, 1)).Unit
	mainPart:ApplyAngularImpulse(randomSpin * (POWER * mass * ANGULAR_POWER))

	-- watch rest & payout
	task.spawn(function()
		watchAndPayout(die, mainPart, ownerId, sides)
		-- hard cleanup
		Debris:AddItem(die, DIE_LIFETIME_SEC)
	end)
end

return DiceService

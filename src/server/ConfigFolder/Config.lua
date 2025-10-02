return {
	Costs = {
		TycCannon1 = 0,
		TycCannon2 = 10000,
	},
	Cannon = {
		CooldownSec = 2.0,
		LocalRotationDeg = { x = 90, y = 180, z = 90 },
		LocalPositionOffset = { x = 5, y = 0, z = 4 },
		ClickDistance = 64,
	},
	Dice = {
		RestLin = 0.15, -- m/s below this counts as still
		RestAng = 0.15, -- rad/s
		RestDwell = 0.60, -- seconds it must remain still
		MaxWait = 8.0, -- fallback: auto-score after this many seconds
		PopupLife = 1.2, -- seconds to show +X over the die
		DespawnAfterScore = 0.8, -- NEW: seconds after awarding to delete the die
	},
}
-- boop

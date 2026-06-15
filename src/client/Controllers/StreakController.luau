local StateController = require(script.Parent.StateController)

local StreakController = {}

function StreakController.getStreak(): { day: number, safeUntil: number }?
	return StateController.get().streak
end

function StreakController.init(): typeof(StreakController)
	return StreakController
end

return StreakController

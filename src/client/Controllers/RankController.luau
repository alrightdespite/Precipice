local StateController = require(script.Parent.StateController)

local RankController = {}

function RankController.getRank(): { currentRun: number, lifetime: number, title: string }?
	return StateController.get().rank
end

function RankController.init(): typeof(RankController)
	return RankController
end

return RankController

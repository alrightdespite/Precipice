local RemoteController = require(script.Parent.RemoteController)
local StateController = require(script.Parent.StateController)

local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
type LeaderboardEntry = Types.LeaderboardEntry

local LeaderboardController = {}

function LeaderboardController.request(board: string): (boolean, { LeaderboardEntry } | string)
	local ok, entries, ownRow = RemoteController.invoke("LeaderboardRequest", board)
	if ok then
		-- Cache results in state
		local lb = table.clone(StateController.get().leaderboard)
		local ownRows = table.clone(StateController.get().ownRows)
		lb[board] = entries or {}
		ownRows[board] = ownRow
		StateController.set({ leaderboard = lb, ownRows = ownRows })
	end
	return ok, entries or ""
end

function LeaderboardController.getCached(board: string): { LeaderboardEntry }
	return StateController.get().leaderboard[board] or {}
end

function LeaderboardController.getOwnRow(board: string): LeaderboardEntry?
	return StateController.get().ownRows[board]
end

function LeaderboardController.init(): typeof(LeaderboardController)
	return LeaderboardController
end

return LeaderboardController

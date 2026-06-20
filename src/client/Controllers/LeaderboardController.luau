local RemoteController = require(script.Parent.RemoteController)
local StateController = require(script.Parent.StateController)

local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
type LeaderboardEntry = Types.LeaderboardEntry

local LeaderboardController = {}

function LeaderboardController.request(board: string): (boolean, { LeaderboardEntry } | string)
	-- The server returns two values (entries, ownRow); RemoteController.invoke passes
	-- them through directly (no leading pcallOk on success). On transport/rate-limit
	-- failure the first value is false/nil, so guard on entries being a table.
	local entries, ownRow = RemoteController.invoke("LeaderboardRequest", board)
	if type(entries) ~= "table" then
		return false, "request failed"
	end
	-- Cache results in state
	local lb = table.clone(StateController.get().leaderboard)
	local ownRows = table.clone(StateController.get().ownRows)
	lb[board] = entries
	ownRows[board] = ownRow
	StateController.set({ leaderboard = lb, ownRows = ownRows })
	return true, entries
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

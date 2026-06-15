-- Pure prestige eligibility check. No Roblox globals. Lune-testable.
-- PrestigeController wraps this with live StateController data.

local PrestigeLogic = {}

-- Returns false if any slot is RUNNING, DONE (unrevealed), or REVEALING.
function PrestigeLogic.canPrestige(slots: { [number]: { state: string } }): boolean
	for _, slot in pairs(slots) do
		local s = slot.state
		if s == "RUNNING" or s == "DONE" or s == "REVEALING" then
			return false
		end
	end
	return true
end

return PrestigeLogic

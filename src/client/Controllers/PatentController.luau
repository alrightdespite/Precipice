local RemoteController = require(script.Parent.RemoteController)
local StateController = require(script.Parent.StateController)

local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
type PatentRecord = Types.PatentRecord

local PatentController = {}

function PatentController.query(compoundId: string): (boolean, PatentRecord | string)
	return RemoteController.invoke("PatentQuery", compoundId)
end

function PatentController.getLocal(compoundId: string): PatentRecord?
	return StateController.get().patents[compoundId]
end

-- Returns a formatted decay string if the patent is HELD and holder lead is finite, else nil.
function PatentController.getDecayProjection(compoundId: string): string?
	local record = StateController.get().patents[compoundId]
	if not record or record.state ~= "HELD" then
		return nil
	end
	local holderCount = record.holderCount or 0
	local challengerCount = record.challengerCount or 0
	if holderCount <= 0 or challengerCount <= 0 then
		return nil
	end
	-- Estimate days based on count gap: each challenger synth erodes one holder count per week.
	local lead = holderCount - challengerCount
	if lead <= 0 then
		return nil
	end
	return string.format("Lead expires in ~%d days", lead * 7)
end

function PatentController.init(): typeof(PatentController)
	return PatentController
end

return PatentController

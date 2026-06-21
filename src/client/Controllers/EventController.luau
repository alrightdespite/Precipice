local RemoteController = require(script.Parent.RemoteController)
local StateController = require(script.Parent.StateController)

local EventController = {}

-- Server BlueprintPurchase returns a single { ok, err } table; RemoteController.invoke
-- passes it through directly (no leading pcallOk). Normalize to (ok, err).
function EventController.purchaseBlueprint(compoundId: string): (boolean, string?)
	local res = RemoteController.invoke("BlueprintPurchase", compoundId)
	if type(res) ~= "table" then
		return false, "request failed"
	end
	return res.ok == true, res.err
end

function EventController.getFlux(): { seasonKey: string, total: number }?
	return StateController.get().flux
end

function EventController.isEventActive(): boolean
	return StateController.get().flux ~= nil
end

function EventController.init(): typeof(EventController)
	return EventController
end

return EventController

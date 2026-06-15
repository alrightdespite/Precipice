local RemoteController = require(script.Parent.RemoteController)
local StateController = require(script.Parent.StateController)

local EventController = {}

function EventController.purchaseBlueprint(compoundId: string): (boolean, string?)
	return RemoteController.invoke("BlueprintPurchase", compoundId)
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

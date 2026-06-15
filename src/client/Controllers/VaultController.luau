local RemoteController = require(script.Parent.RemoteController)
local StateController = require(script.Parent.StateController)

local VaultController = {}

function VaultController.instantSell(compoundId: string, quantity: number): (boolean, string?)
	return RemoteController.invoke("VaultInstantSell", compoundId, quantity)
end

function VaultController.getQuantity(compoundId: string): number
	return StateController.get().vault[compoundId] or 0
end

function VaultController.init(): typeof(VaultController)
	return VaultController
end

return VaultController

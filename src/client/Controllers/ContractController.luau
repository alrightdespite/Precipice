local RemoteController = require(script.Parent.RemoteController)
local StateController = require(script.Parent.StateController)

local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
type ContractRecord = Types.ContractRecord

local ContractController = {}

function ContractController.claim(slotIndex: number): (boolean, string?)
	return RemoteController.invoke("ContractClaim", slotIndex)
end

function ContractController.getContracts(): { ContractRecord }
	return StateController.get().contracts
end

function ContractController.init(): typeof(ContractController)
	return ContractController
end

return ContractController

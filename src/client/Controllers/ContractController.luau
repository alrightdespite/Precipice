local RemoteController = require(script.Parent.RemoteController)
local StateController = require(script.Parent.StateController)

local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
type ContractRecord = Types.ContractRecord

local ContractController = {}

-- Server ContractClaim returns a single { ok, err } table; RemoteController.invoke
-- passes it through directly (no leading pcallOk). Normalize to (ok, err).
function ContractController.claim(slotIndex: number): (boolean, string?)
	local res = RemoteController.invoke("ContractClaim", slotIndex)
	if type(res) ~= "table" then
		return false, "request failed"
	end
	return res.ok == true, res.err
end

function ContractController.getContracts(): { ContractRecord }
	return StateController.get().contracts
end

function ContractController.init(): typeof(ContractController)
	return ContractController
end

return ContractController

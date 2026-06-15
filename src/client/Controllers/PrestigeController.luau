local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PrestigeLogic = require(ReplicatedStorage.Shared.Core.PrestigeLogic)
local RemoteController = require(script.Parent.RemoteController)
local StateController = require(script.Parent.StateController)

local PrestigeController = {}

function PrestigeController.request(): (boolean, { string }? | string)
	return RemoteController.invoke("PrestigeRequest")
end

function PrestigeController.confirm(): (boolean, string?)
	return RemoteController.invoke("PrestigeConfirm")
end

-- Pure eligibility check — no server call. Returns false if any slot is RUNNING/DONE/REVEALING.
function PrestigeController.canPrestige(): boolean
	return PrestigeLogic.canPrestige(StateController.get().slots)
end

function PrestigeController.init(): typeof(PrestigeController)
	return PrestigeController
end

return PrestigeController

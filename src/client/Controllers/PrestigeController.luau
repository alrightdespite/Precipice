local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PrestigeLogic = require(ReplicatedStorage.Shared.Core.PrestigeLogic)
local RemoteController = require(script.Parent.RemoteController)
local StateController = require(script.Parent.StateController)

local PrestigeController = {}

-- Returns (ok, blockers). RemoteController.invoke returns the server's value(s)
-- directly on success, or (false, errString) on transport/rate-limit failure. The
-- server replies with a single { ok, blockers } table, so read .blockers off it.
function PrestigeController.request(): (boolean, { string })
	local res = RemoteController.invoke("PrestigeRequest")
	if type(res) ~= "table" or type(res.blockers) ~= "table" then
		return false, {}
	end
	return true, res.blockers
end

-- Returns (ok, err). Server replies with { ok, err }; ok must reflect the server's
-- result, not the transport (else a blocked confirm would read as success).
function PrestigeController.confirm(): (boolean, string?)
	local res = RemoteController.invoke("PrestigeConfirm")
	if type(res) ~= "table" then
		return false, "request failed"
	end
	return res.ok == true, res.err
end

-- Pure eligibility check — no server call. Returns false if any slot is RUNNING/DONE/REVEALING.
function PrestigeController.canPrestige(): boolean
	return PrestigeLogic.canPrestige(StateController.get().slots)
end

function PrestigeController.init(): typeof(PrestigeController)
	return PrestigeController
end

return PrestigeController

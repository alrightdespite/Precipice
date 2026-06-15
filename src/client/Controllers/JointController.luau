local RemoteController = require(script.Parent.RemoteController)
local StateController = require(script.Parent.StateController)

local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
type JointSlotRecord = Types.JointSlotRecord

local JointController = {}

function JointController.stage(
	slotIndex: number,
	myCompound: string,
	partnerCompound: string,
	async: boolean,
	accelerated: boolean
): (boolean, string?)
	return RemoteController.invoke("JointStage", slotIndex, myCompound, partnerCompound, async, accelerated)
end

function JointController.contribute(slotIndex: number, compound: string): (boolean, string?)
	return RemoteController.invoke("JointContribute", slotIndex, compound)
end

function JointController.cancel(slotIndex: number): (boolean, string?)
	return RemoteController.invoke("JointCancel", slotIndex)
end

function JointController.getSlot(slotIndex: number): JointSlotRecord?
	local syndicate = StateController.get().syndicate
	if not syndicate then
		return nil
	end
	return syndicate.jointSlots and syndicate.jointSlots[slotIndex]
end

function JointController.init(): typeof(JointController)
	return JointController
end

return JointController

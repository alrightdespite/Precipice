-- Handles all slot interactions and chamber part resolution.

local Players = game:GetService("Players")
local RemoteController = require(script.Parent.RemoteController)

local SlotController = {}

function SlotController.startExtraction(_slotIndex: number, compoundId: string): (boolean, string?)
	return RemoteController.invoke("SlotStartExtraction", compoundId)
end

function SlotController.startSynthesis(
	slotIndex: number,
	input1: string,
	input2: string,
	stabilized: boolean
): (boolean, string?)
	return RemoteController.invoke("SlotStartSynthesis", slotIndex, input1, input2, stabilized)
end

function SlotController.cancel(slotIndex: number): (boolean, string?)
	return RemoteController.invoke("SlotCancel", slotIndex)
end

function SlotController.reveal(slotIndex: number)
	local RevealController = require(script.Parent.RevealController)
	RevealController.enqueue(slotIndex)
end

function SlotController.skip(slotIndex: number, skipType: string): (boolean, string?)
	return RemoteController.invoke("SlotSkip", slotIndex, skipType)
end

-- Resolves the chamber BasePart from workspace.
-- Returns nil if not found (headless / template not yet built in Studio).
function SlotController.getChamberPart(slotIndex: number): BasePart?
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return nil
	end
	local userId = tostring(localPlayer.UserId)
	local ok, result = pcall(function()
		return workspace
			:FindFirstChild("Plots")
			:FindFirstChild(userId)
			:FindFirstChild("Lab")
			:FindFirstChild("Chambers")
			:FindFirstChild(tostring(slotIndex))
	end)
	if ok and result then
		return result :: BasePart
	end
	return nil
end

function SlotController.init(): typeof(SlotController)
	return SlotController
end

return SlotController

-- Handles all slot interactions and chamber part resolution.
-- STUB: Phase 12B wires real geometry here.

local Players = game:GetService("Players")
local RemoteController = require(script.Parent.RemoteController)

-- STUB: Phase 12B wires real geometry here.
local CHAMBER_PATH_TEMPLATE = "workspace.Plots[localUserId].Lab.Chambers[slotIndex]"

local SlotController = {}

function SlotController.startExtraction(slotIndex: number, compoundId: string): (boolean, string?)
	return RemoteController.invoke("SlotStartExtraction", slotIndex, compoundId)
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

function SlotController.reveal(slotIndex: number): (boolean, string?)
	local ok, result, err = RemoteController.invoke("SlotReveal", slotIndex)
	if ok and result then
		-- STUB: Phase 12B replaces with VFX reveal sequence.
		local compoundId = type(result) == "table" and result.compoundId or tostring(result)
		print(string.format("[REVEAL STUB] slot %d compound %s", slotIndex, compoundId))
	end
	return ok, err
end

function SlotController.skip(slotIndex: number, skipType: string): (boolean, string?)
	return RemoteController.invoke("SlotSkip", slotIndex, skipType)
end

-- Resolves the chamber BasePart from workspace using the stub path template.
-- Returns nil if not found (headless / no-world context).
function SlotController.getChamberPart(slotIndex: number): BasePart?
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return nil
	end
	local userId = tostring(localPlayer.UserId)
	-- STUB: Phase 12B wires real geometry here (see CHAMBER_PATH_TEMPLATE).
	local _ = CHAMBER_PATH_TEMPLATE
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

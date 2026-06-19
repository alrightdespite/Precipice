-- Handles all slot interactions and chamber part resolution.

local Players = game:GetService("Players")
local RemoteController = require(script.Parent.RemoteController)

local SlotController = {}

function SlotController.startExtraction(_slotIndex: number, compoundId: string): (boolean, string?)
	return RemoteController.invoke("SlotStartExtraction", compoundId)
end

-- desiredResultId: only honored when stabilized — forces a specific discovered
-- variant of a variable pair (§8). nil → this week's active variant.
function SlotController.startSynthesis(
	slotIndex: number,
	input1: string,
	input2: string,
	stabilized: boolean,
	desiredResultId: string?
): (boolean, string?)
	return RemoteController.invoke("SlotStartSynthesis", slotIndex, input1, input2, stabilized, desiredResultId)
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

-- Chambers physically exist for slots 1..6 in the current map; higher indices
-- resolve nil and are skipped (see STATUS B4).
local CHAMBER_COUNT = 10

-- Wires each chamber's RevealPrompt to reveal that slot, but only while the slot
-- is DONE. The prompt is enabled/disabled to match slot state so players can't
-- trigger it on empty or still-running chambers. Reveal stays UI-driven too
-- (HomeScreen "tap" path); this is the in-world equivalent.
function SlotController.bindRevealPrompts()
	local StateController = require(script.Parent.StateController)
	local connected: { [number]: boolean } = {}

	local function isDone(i: number): boolean
		local slot = StateController.get().slots[i]
		return slot ~= nil and (slot :: any).state == "DONE"
	end

	local function refresh()
		for i = 1, CHAMBER_COUNT do
			local chamber = SlotController.getChamberPart(i)
			local prompt = chamber and chamber:FindFirstChild("RevealPrompt")
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.Enabled = isDone(i)
				prompt.ActionText = "Reveal"
				if not connected[i] then
					connected[i] = true
					prompt.Triggered:Connect(function()
						if isDone(i) then
							SlotController.reveal(i)
						end
					end)
				end
			end
		end
	end

	StateController.Changed:Connect(function(patch)
		if patch.slots ~= nil then
			refresh()
		end
	end)
	refresh()
end

function SlotController.init(): typeof(SlotController)
	return SlotController
end

return SlotController

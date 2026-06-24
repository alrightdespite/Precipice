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

-- Chambers physically exist for slots 1..10 in the map; indices past the built
-- count resolve nil and are skipped.
local CHAMBER_COUNT = 10

-- §31: "the room is built with all 10 chambers present; chambers for slots you
-- have not unlocked stand dark and inactive — the slot cap is legible at a
-- glance." Locked chambers kill their teal neon glow and read "LOCKED"; unlocked
-- ones restore the Industrial Standard teal accent. Owner-only (driven off the
-- local player's slotCap); a visitor sees the template default (active) per §24.
local ACTIVE_RIB = Color3.fromRGB(0, 180, 200) -- teal accent (matches LightPanel/sign neon)
local ACTIVE_RIM = Color3.fromRGB(0, 95, 105)
local LOCKED_GREY = Color3.fromRGB(38, 38, 45)
local LOCKED_TEXT = Color3.fromRGB(110, 110, 120)
local STANDBY_TEXT = Color3.fromRGB(120, 200, 140)

local function applyChamberLock(chamber: Instance, locked: boolean)
	for _, d in chamber:GetChildren() do
		if d:IsA("BasePart") and (d.Name == "Rib" or d.Name == "Rim") then
			if locked then
				d.Material = Enum.Material.SmoothPlastic
				d.Color = LOCKED_GREY
			else
				d.Material = Enum.Material.Neon
				d.Color = if d.Name == "Rib" then ACTIVE_RIB else ACTIVE_RIM
			end
		end
	end
	local labelPlate = chamber:FindFirstChild("LabelPlate")
	local gui = labelPlate and labelPlate:FindFirstChildWhichIsA("SurfaceGui")
	if gui then
		for _, t in gui:GetDescendants() do
			if t:IsA("TextLabel") and (string.find(t.Text, "STANDBY") or string.find(t.Text, "LOCKED")) then
				t.Text = if locked then "🔒 LOCKED" else "● STANDBY"
				t.TextColor3 = if locked then LOCKED_TEXT else STANDBY_TEXT
			end
		end
	end
end

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
		local slotCap = StateController.get().slotCap or CHAMBER_COUNT
		for i = 1, CHAMBER_COUNT do
			local chamber = SlotController.getChamberPart(i)
			if chamber then
				applyChamberLock(chamber, i > slotCap)
			end
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
		if patch.slots ~= nil or patch.slotCap ~= nil then
			refresh()
		end
	end)
	refresh()
end

function SlotController.init(): typeof(SlotController)
	return SlotController
end

return SlotController

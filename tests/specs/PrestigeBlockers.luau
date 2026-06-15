-- Tests for PrestigeLogic.canPrestige (§ client Phase 12A).
-- Mirrors PrestigeController.canPrestige() — tests the pure function directly.

local spec = require("../spec")
local PrestigeLogic = require("../../src/shared/Core/PrestigeLogic")

local describe, it, expect = spec.describe, spec.it, spec.expect

local function slot(state: string)
	return { state = state, isActive = false }
end

describe("PrestigeLogic — canPrestige", function()
	it("all slots EMPTY → true", function()
		expect(PrestigeLogic.canPrestige({ [1] = slot("EMPTY"), [2] = slot("EMPTY"), [3] = slot("EMPTY") })).toBe(true)
	end)

	it("no slots → true (vacuously clear)", function()
		expect(PrestigeLogic.canPrestige({})).toBe(true)
	end)

	it("one RUNNING slot → false", function()
		expect(PrestigeLogic.canPrestige({ [1] = slot("EMPTY"), [2] = slot("RUNNING"), [3] = slot("EMPTY") })).toBe(false)
	end)

	it("one DONE (unrevealed) slot → false", function()
		expect(PrestigeLogic.canPrestige({ [1] = slot("EMPTY"), [2] = slot("DONE") })).toBe(false)
	end)

	it("one REVEALING slot → false", function()
		expect(PrestigeLogic.canPrestige({ [1] = slot("REVEALING"), [2] = slot("EMPTY") })).toBe(false)
	end)

	it("all EMPTY after reveal (slots returned to EMPTY) → true", function()
		local slots = {}
		for i = 1, 5 do
			slots[i] = slot("EMPTY")
		end
		expect(PrestigeLogic.canPrestige(slots)).toBe(true)
	end)

	it("mixed EMPTY and RUNNING → false", function()
		expect(PrestigeLogic.canPrestige({
			[1] = slot("EMPTY"),
			[2] = slot("EMPTY"),
			[3] = slot("RUNNING"),
			[4] = slot("EMPTY"),
		})).toBe(false)
	end)

	it("all 10 slots EMPTY → true", function()
		local slots = {}
		for i = 1, 10 do
			slots[i] = slot("EMPTY")
		end
		expect(PrestigeLogic.canPrestige(slots)).toBe(true)
	end)

	it("last slot DONE blocks prestige", function()
		local slots = {}
		for i = 1, 9 do
			slots[i] = slot("EMPTY")
		end
		slots[10] = slot("DONE")
		expect(PrestigeLogic.canPrestige(slots)).toBe(false)
	end)
end)

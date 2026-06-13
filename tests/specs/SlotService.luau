-- SlotMachine (pure slot state machine) tests.
-- SlotService wires SlotMachine to Roblox globals (Studio-tested); we test SlotMachine here.
--
-- Known values (SlotService looks these up from Compounds; tests pass them directly):
--   T1_01: timeMins=2  → baseWorkSeconds=120
--   T2_01: timeMins=12 → baseWorkSeconds=720

local spec = require("../spec")
local SlotMachine = require("../../src/shared/Core/SlotMachine")

local NOW = 1000000 -- arbitrary fixed timestamp for tests
local CAP = 5
local BASE_120 = 120 -- T1_01: 2 * 60
local BASE_720 = 720 -- T2_01: 12 * 60

-- ── startExtraction ────────────────────────────────────────────────────────

spec.describe("SlotMachine — startExtraction", function()
	spec.it("adds slot with index 1 when slots empty", function()
		local newSlots, idx, err = SlotMachine.startExtraction({}, "T1_01", BASE_120, NOW, CAP)
		spec.expect(err).toBeNil()
		spec.expect(idx).toBe(1)
		spec.expect(#newSlots).toBe(1)
		spec.expect(newSlots[1].compoundId).toBe("T1_01")
		spec.expect(newSlots[1].kind).toBe("extraction")
	end)

	spec.it("stores baseWorkSeconds as workRemaining", function()
		local newSlots, _, _ = SlotMachine.startExtraction({}, "T1_01", BASE_120, NOW, CAP)
		spec.expect(newSlots[1].workRemaining).toBe(120)
	end)

	spec.it("isNatural starts true", function()
		local newSlots, _, _ = SlotMachine.startExtraction({}, "T1_01", BASE_120, NOW, CAP)
		spec.expect(newSlots[1].isNatural).toBeTrue()
	end)

	spec.it("picks lowest free index when slot 1 is occupied", function()
		local existing, _, _ = SlotMachine.startExtraction({}, "T1_01", BASE_120, NOW, CAP)
		local newSlots, idx, err = SlotMachine.startExtraction(existing, "T1_02", BASE_120, NOW, CAP)
		spec.expect(err).toBeNil()
		spec.expect(idx).toBe(2)
		spec.expect(#newSlots).toBe(2)
	end)

	spec.it("returns error when all slots full", function()
		local slots = {}
		for _ = 1, CAP do
			slots, _, _ = SlotMachine.startExtraction(slots, "T1_01", BASE_120, NOW, CAP)
		end
		local _, idx, err = SlotMachine.startExtraction(slots, "T1_01", BASE_120, NOW, CAP)
		spec.expect(idx).toBeNil()
		spec.expect(err ~= nil).toBeTrue()
	end)

	spec.it("does not mutate input slots array", function()
		local original = {}
		SlotMachine.startExtraction(original, "T1_01", BASE_120, NOW, CAP)
		spec.expect(#original).toBe(0)
	end)
end)

-- ── startSynthesis ─────────────────────────────────────────────────────────

spec.describe("SlotMachine — startSynthesis", function()
	spec.it("creates synthesis slot at specified index", function()
		local newSlots, err = SlotMachine.startSynthesis({}, "T2_01", BASE_720, false, 3, NOW, CAP)
		spec.expect(err).toBeNil()
		spec.expect(#newSlots).toBe(1)
		spec.expect(newSlots[1].index).toBe(3)
		spec.expect(newSlots[1].kind).toBe("synthesis")
		spec.expect(newSlots[1].compoundId).toBe("T2_01")
	end)

	spec.it("stores baseWorkSeconds as workRemaining when not stabilized", function()
		local newSlots, _ = SlotMachine.startSynthesis({}, "T2_01", BASE_720, false, 1, NOW, CAP)
		spec.expect(newSlots[1].workRemaining).toBe(720)
	end)

	spec.it("stabilized multiplies workRemaining by 1.5", function()
		local newSlots, _ = SlotMachine.startSynthesis({}, "T2_01", BASE_720, true, 1, NOW, CAP)
		spec.expect(newSlots[1].workRemaining).toBe(1080) -- 720 * 1.5
	end)

	spec.it("isNatural starts true", function()
		local newSlots, _ = SlotMachine.startSynthesis({}, "T2_01", BASE_720, false, 1, NOW, CAP)
		spec.expect(newSlots[1].isNatural).toBeTrue()
	end)

	spec.it("isStabilized stored correctly", function()
		local s1, _ = SlotMachine.startSynthesis({}, "T2_01", BASE_720, true, 1, NOW, CAP)
		local s2, _ = SlotMachine.startSynthesis({}, "T2_01", BASE_720, false, 2, NOW, CAP)
		spec.expect(s1[1].isStabilized).toBeTrue()
		spec.expect(s2[1].isStabilized).toBeFalse()
	end)

	spec.it("returns error if slot already occupied", function()
		local occupied, _ = SlotMachine.startSynthesis({}, "T2_01", BASE_720, false, 2, NOW, CAP)
		local _, err = SlotMachine.startSynthesis(occupied, "T2_01", BASE_720, false, 2, NOW, CAP)
		spec.expect(err ~= nil).toBeTrue()
	end)

	spec.it("returns error for slot index out of range", function()
		local _, err1 = SlotMachine.startSynthesis({}, "T2_01", BASE_720, false, 0, NOW, CAP)
		local _, err2 = SlotMachine.startSynthesis({}, "T2_01", BASE_720, false, CAP + 1, NOW, CAP)
		spec.expect(err1 ~= nil).toBeTrue()
		spec.expect(err2 ~= nil).toBeTrue()
	end)
end)

-- ── cancel ─────────────────────────────────────────────────────────────────

spec.describe("SlotMachine — cancel", function()
	spec.it("removes the slot from the array", function()
		local slots, idx, _ = SlotMachine.startExtraction({}, "T1_01", BASE_120, NOW, CAP)
		local newSlots, err = SlotMachine.cancel(slots, idx)
		spec.expect(err).toBeNil()
		spec.expect(#newSlots).toBe(0)
	end)

	spec.it("returns error for nonexistent slot index", function()
		local _, err = SlotMachine.cancel({}, 1)
		spec.expect(err ~= nil).toBeTrue()
	end)

	spec.it("removes only the targeted slot when multiple exist", function()
		local slots = {}
		slots, _, _ = SlotMachine.startExtraction(slots, "T1_01", BASE_120, NOW, CAP)
		slots, _, _ = SlotMachine.startExtraction(slots, "T1_02", BASE_120, NOW, CAP)
		local newSlots, _ = SlotMachine.cancel(slots, 1)
		spec.expect(#newSlots).toBe(1)
		spec.expect(newSlots[1].index).toBe(2)
	end)
end)

-- ── reveal ─────────────────────────────────────────────────────────────────

spec.describe("SlotMachine — reveal", function()
	spec.it("awards compound and removes slot when complete", function()
		local slots, idx, _ = SlotMachine.startExtraction({}, "T1_01", BASE_120, NOW, CAP)
		local newSlots, compoundId, isNatural, err = SlotMachine.reveal(slots, idx, NOW + 9999)
		spec.expect(err).toBeNil()
		spec.expect(compoundId).toBe("T1_01")
		spec.expect(isNatural).toBeTrue()
		spec.expect(#newSlots).toBe(0)
	end)

	spec.it("returns error when slot not complete", function()
		local slots, idx, _ = SlotMachine.startExtraction({}, "T1_01", BASE_120, NOW, CAP)
		local _, compoundId, _, err = SlotMachine.reveal(slots, idx, NOW + 1)
		spec.expect(err ~= nil).toBeTrue()
		spec.expect(compoundId).toBeNil()
	end)

	spec.it("returns error for nonexistent slot", function()
		local _, _, _, err = SlotMachine.reveal({}, 1, NOW)
		spec.expect(err ~= nil).toBeTrue()
	end)

	spec.it("isNatural = false after skip", function()
		local slots, idx, _ = SlotMachine.startExtraction({}, "T1_01", BASE_120, NOW, CAP)
		slots, _ = SlotMachine.skip(slots, idx, NOW)
		local _, _, isNatural, err = SlotMachine.reveal(slots, idx, NOW)
		spec.expect(err).toBeNil()
		spec.expect(isNatural).toBeFalse()
	end)
end)

-- ── skip ───────────────────────────────────────────────────────────────────

spec.describe("SlotMachine — skip", function()
	spec.it("drains workRemaining to 0", function()
		local slots, idx, _ = SlotMachine.startExtraction({}, "T1_01", BASE_120, NOW, CAP)
		local newSlots, err = SlotMachine.skip(slots, idx, NOW)
		spec.expect(err).toBeNil()
		local found = nil
		for _, s in ipairs(newSlots) do
			if s.index == idx then
				found = s
				break
			end
		end
		spec.expect(found ~= nil).toBeTrue()
		spec.expect(found.workRemaining).toBe(0)
	end)

	spec.it("sets isNatural to false", function()
		local slots, idx, _ = SlotMachine.startExtraction({}, "T1_01", BASE_120, NOW, CAP)
		local newSlots, _ = SlotMachine.skip(slots, idx, NOW)
		for _, s in ipairs(newSlots) do
			if s.index == idx then
				spec.expect(s.isNatural).toBeFalse()
			end
		end
	end)

	spec.it("returns error for nonexistent slot", function()
		local _, err = SlotMachine.skip({}, 1, NOW)
		spec.expect(err ~= nil).toBeTrue()
	end)
end)

-- ── tick ───────────────────────────────────────────────────────────────────

spec.describe("SlotMachine — tick", function()
	spec.it("reduces workRemaining by elapsed time at online rate", function()
		local slots, _, _ = SlotMachine.startExtraction({}, "T1_01", BASE_120, NOW, CAP)
		local newSlots, _ = SlotMachine.tick(slots, NOW + 30)
		spec.expect(newSlots[1].workRemaining).toBe(90) -- 120 - 30
	end)

	spec.it("returns completedIndices for slots that reached zero", function()
		local slots, idx, _ = SlotMachine.startExtraction({}, "T1_01", BASE_120, NOW, CAP)
		local _, completedIndices = SlotMachine.tick(slots, NOW + 9999)
		spec.expect(#completedIndices).toBe(1)
		spec.expect(completedIndices[1]).toBe(idx)
	end)

	spec.it("completedIndices empty when no slots finish", function()
		local slots, _, _ = SlotMachine.startExtraction({}, "T1_01", BASE_120, NOW, CAP)
		local _, completedIndices = SlotMachine.tick(slots, NOW + 1)
		spec.expect(#completedIndices).toBe(0)
	end)

	spec.it("already-complete slots pass through unchanged", function()
		local slots, idx, _ = SlotMachine.startExtraction({}, "T1_01", BASE_120, NOW, CAP)
		slots, _ = SlotMachine.skip(slots, idx, NOW) -- workRemaining = 0
		local original = slots[1]
		local newSlots, _ = SlotMachine.tick(slots, NOW + 10)
		spec.expect(newSlots[1]).toBe(original) -- same table reference (pass-through)
	end)

	spec.it("handles multiple slots independently", function()
		local slots = {}
		slots, _, _ = SlotMachine.startExtraction(slots, "T1_01", BASE_120, NOW, CAP)
		slots, _ = SlotMachine.startSynthesis(slots, "T2_01", BASE_720, false, 2, NOW, CAP)
		local newSlots, completedIndices = SlotMachine.tick(slots, NOW + 200)
		-- T1_01 (120s) completes, T2_01 (720s) does not
		spec.expect(#completedIndices).toBe(1)
		-- Both slots still present until revealed
		spec.expect(#newSlots).toBe(2)
	end)
end)

-- LabAnalysis pure-logic tests (§11, §12).
-- Covers: pairKey ordering, getRefusal, getFee, getResidueAmount, getButtonState.

local spec = require("../spec")
local LabAnalysis = require("../../src/shared/Core/LabAnalysis")

-- ── pairKey ────────────────────────────────────────────────────────────────

spec.describe("LabAnalysis — pairKey", function()
	spec.it("A+B and B+A produce the same key", function()
		spec.expect(LabAnalysis.pairKey("T1_01", "T2_05")).toBe(LabAnalysis.pairKey("T2_05", "T1_01"))
	end)

	spec.it("same compound returns id|id", function()
		spec.expect(LabAnalysis.pairKey("T3_07", "T3_07")).toBe("T3_07|T3_07")
	end)

	spec.it("lexicographic order: lower id first", function()
		spec.expect(LabAnalysis.pairKey("T2_01", "T1_30")).toBe("T1_30|T2_01")
	end)
end)

-- ── getRefusal ─────────────────────────────────────────────────────────────

spec.describe("LabAnalysis — getRefusal", function()
	spec.it("either input T7 → exotic", function()
		spec.expect(LabAnalysis.getRefusal(7, 1)).toBe("exotic")
		spec.expect(LabAnalysis.getRefusal(1, 7)).toBe("exotic")
		spec.expect(LabAnalysis.getRefusal(7, 7)).toBe("exotic")
	end)

	spec.it("T4+T5 → joint", function()
		spec.expect(LabAnalysis.getRefusal(4, 5)).toBe("joint")
		spec.expect(LabAnalysis.getRefusal(5, 4)).toBe("joint")
	end)

	spec.it("T5+T5 → joint", function()
		spec.expect(LabAnalysis.getRefusal(5, 5)).toBe("joint")
	end)

	spec.it("T6+T6 → joint", function()
		spec.expect(LabAnalysis.getRefusal(6, 6)).toBe("joint")
	end)

	spec.it("T4+T6 → nil (not refused per spec)", function()
		spec.expect(LabAnalysis.getRefusal(4, 6)).toBeNil()
	end)

	spec.it("T5+T6 → nil (not refused per spec)", function()
		spec.expect(LabAnalysis.getRefusal(5, 6)).toBeNil()
	end)

	spec.it("T1+T1 → nil", function()
		spec.expect(LabAnalysis.getRefusal(1, 1)).toBeNil()
	end)

	spec.it("T3+T4 → nil", function()
		spec.expect(LabAnalysis.getRefusal(3, 4)).toBeNil()
	end)
end)

-- ── getFee ─────────────────────────────────────────────────────────────────

spec.describe("LabAnalysis — getFee standard (prestige 0)", function()
	spec.it("min tier 1 → 25P", function()
		spec.expect(LabAnalysis.getFee(1, 0)).toBe(25)
	end)

	spec.it("min tier 2 → 75P", function()
		spec.expect(LabAnalysis.getFee(2, 0)).toBe(75)
	end)

	spec.it("min tier 3 → 75P", function()
		spec.expect(LabAnalysis.getFee(3, 0)).toBe(75)
	end)

	spec.it("min tier 4 → 200P", function()
		spec.expect(LabAnalysis.getFee(4, 0)).toBe(200)
	end)

	spec.it("min tier 5 → 200P", function()
		spec.expect(LabAnalysis.getFee(5, 0)).toBe(200)
	end)
end)

spec.describe("LabAnalysis — getFee P1+ discount (prestige ≥ 1)", function()
	spec.it("min tier 1 → 15P at P1", function()
		spec.expect(LabAnalysis.getFee(1, 1)).toBe(15)
	end)

	spec.it("min tier 2 → 45P at P1", function()
		spec.expect(LabAnalysis.getFee(2, 1)).toBe(45)
	end)

	spec.it("min tier 3 → 45P at P1", function()
		spec.expect(LabAnalysis.getFee(3, 1)).toBe(45)
	end)

	spec.it("min tier 4 → 120P at P1", function()
		spec.expect(LabAnalysis.getFee(4, 1)).toBe(120)
	end)

	spec.it("P3 gives same discount as P1 (40% flat, non-stacking)", function()
		spec.expect(LabAnalysis.getFee(2, 3)).toBe(45)
	end)
end)

-- ── getResidueAmount ───────────────────────────────────────────────────────

spec.describe("LabAnalysis — getResidueAmount (§12)", function()
	spec.it("min tier 1 → 1 unit", function()
		spec.expect(LabAnalysis.getResidueAmount(1)).toBe(1)
	end)

	spec.it("min tier 2 → 2 units", function()
		spec.expect(LabAnalysis.getResidueAmount(2)).toBe(2)
	end)

	spec.it("min tier 3 → 4 units", function()
		spec.expect(LabAnalysis.getResidueAmount(3)).toBe(4)
	end)

	spec.it("min tier 4 → 6 units", function()
		spec.expect(LabAnalysis.getResidueAmount(4)).toBe(6)
	end)

	spec.it("min tier 5 → 6 units", function()
		spec.expect(LabAnalysis.getResidueAmount(5)).toBe(6)
	end)
end)

-- ── getButtonState (§11 mandatory four-state table) ───────────────────────

spec.describe("LabAnalysis — getButtonState", function()
	local function emptyLog()
		return { discovered = {}, validatedPairs = {}, failedPairs = {} }
	end

	-- MANDATORY: Unknown — pair never attempted
	spec.it("Unknown: pair not in any log", function()
		local log = emptyLog()
		local state = LabAnalysis.getButtonState(log, "T1_01|T2_05", {})
		spec.expect(state).toBe("Unknown")
	end)

	spec.it("Unknown: possibleResultIds non-empty but none discovered", function()
		local log = emptyLog()
		local state = LabAnalysis.getButtonState(log, "T1_01|T2_05", { "T3_01", "T3_02" })
		spec.expect(state).toBe("Unknown")
	end)

	-- MANDATORY: Validated — pair in validatedPairs (always false until Phase 5 JointSynthService)
	spec.it("Validated: pair in validatedPairs", function()
		local log = emptyLog()
		log.validatedPairs["T4_01|T5_03"] = true
		local state = LabAnalysis.getButtonState(log, "T4_01|T5_03", {})
		spec.expect(state).toBe("Validated")
	end)

	spec.it("Validated returns false (Unknown) when validatedPairs is empty", function()
		local log = emptyLog()
		local state = LabAnalysis.getButtonState(log, "T4_01|T5_03", {})
		spec.expect(state).toBe("Unknown")
	end)

	-- MANDATORY: Discovered — a result compound for this pair is in discovered
	spec.it("Discovered: one result in formulaLog.discovered", function()
		local log = emptyLog()
		log.discovered["T2_07"] = true
		local state = LabAnalysis.getButtonState(log, "T1_03|T1_09", { "T2_07" })
		spec.expect(state).toBe("Discovered")
	end)

	spec.it("Discovered: at least one of two variable results is known", function()
		local log = emptyLog()
		log.discovered["T3_02"] = true -- only primary variant discovered
		local state = LabAnalysis.getButtonState(log, "T1_05|T2_11", { "T3_02", "T3_14" })
		spec.expect(state).toBe("Discovered")
	end)

	-- MANDATORY: Failed — pair in failedPairs cache
	spec.it("Failed: pair in failedPairs", function()
		local log = emptyLog()
		log.failedPairs["T1_01|T1_02"] = true
		local state = LabAnalysis.getButtonState(log, "T1_01|T1_02", {})
		spec.expect(state).toBe("Failed")
	end)

	-- Priority: Failed beats Validated (defensive)
	spec.it("Failed takes priority over Validated", function()
		local log = emptyLog()
		log.failedPairs["T1_01|T1_02"] = true
		log.validatedPairs["T1_01|T1_02"] = true
		local state = LabAnalysis.getButtonState(log, "T1_01|T1_02", {})
		spec.expect(state).toBe("Failed")
	end)

	-- Priority: Failed beats Discovered
	spec.it("Failed takes priority over Discovered", function()
		local log = emptyLog()
		log.failedPairs["T1_01|T1_02"] = true
		log.discovered["T2_07"] = true
		local state = LabAnalysis.getButtonState(log, "T1_01|T1_02", { "T2_07" })
		spec.expect(state).toBe("Failed")
	end)
end)

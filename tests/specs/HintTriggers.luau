-- Tests for HintTriggerLogic.evaluate (§ client Phase 12A).
-- Verifies correct hint fires for each trigger condition and dismissed hints do not re-fire.

local spec = require("../spec")
local Logic = require("../../src/shared/Core/HintTriggerLogic")

local describe, it, expect = spec.describe, spec.it, spec.expect

local function noHints(): { [string]: boolean }
	return {}
end

local function emptyState(): Logic.HintState
	return {
		slots = {},
		formulaLog = {},
		syndicate = nil,
		streak = nil,
		patents = {},
		flux = nil,
	}
end

local function hasId(results: { Logic.HintDef }, id: string): boolean
	for _, def in ipairs(results) do
		if def.id == id then
			return true
		end
	end
	return false
end

describe("HintTriggers — lab_intro", function()
	it("fires when all slots RUNNING and formulaLog empty", function()
		local state = emptyState()
		state.slots = { [1] = { state = "RUNNING" }, [2] = { state = "RUNNING" } }
		state.formulaLog = {}
		local results = Logic.evaluate(state, noHints())
		expect(hasId(results, "lab_intro")).toBe(true)
	end)

	it("does not fire when formulaLog has entries", function()
		local state = emptyState()
		state.slots = { [1] = { state = "RUNNING" } }
		state.formulaLog = { { compoundId = "T2_01", discoveredAt = 0 } }
		local results = Logic.evaluate(state, noHints())
		expect(hasId(results, "lab_intro")).toBe(false)
	end)

	it("does not fire when not all slots are RUNNING", function()
		local state = emptyState()
		state.slots = { [1] = { state = "RUNNING" }, [2] = { state = "EMPTY" } }
		state.formulaLog = {}
		local results = Logic.evaluate(state, noHints())
		expect(hasId(results, "lab_intro")).toBe(false)
	end)

	it("does not fire when no slots at all", function()
		local state = emptyState()
		state.slots = {}
		local results = Logic.evaluate(state, noHints())
		expect(hasId(results, "lab_intro")).toBe(false)
	end)

	it("dismissed lab_intro does not re-fire", function()
		local state = emptyState()
		state.slots = { [1] = { state = "RUNNING" } }
		local results = Logic.evaluate(state, { lab_intro = true })
		expect(hasId(results, "lab_intro")).toBe(false)
	end)
end)

describe("HintTriggers — market_intro", function()
	it("fires when formulaLog has ≥1 entry", function()
		local state = emptyState()
		state.formulaLog = { { compoundId = "T2_01", discoveredAt = 0 } }
		local results = Logic.evaluate(state, noHints())
		expect(hasId(results, "market_intro")).toBe(true)
	end)

	it("does not fire when formulaLog is empty", function()
		local results = Logic.evaluate(emptyState(), noHints())
		expect(hasId(results, "market_intro")).toBe(false)
	end)

	it("dismissed market_intro does not re-fire", function()
		local state = emptyState()
		state.formulaLog = { { compoundId = "T2_01", discoveredAt = 0 } }
		local results = Logic.evaluate(state, { market_intro = true })
		expect(hasId(results, "market_intro")).toBe(false)
	end)
end)

describe("HintTriggers — tier_system", function()
	it("fires when first formula discovered (log length = 1)", function()
		local state = emptyState()
		state.formulaLog = { { compoundId = "T2_01", discoveredAt = 0 } }
		local results = Logic.evaluate(state, noHints())
		expect(hasId(results, "tier_system")).toBe(true)
	end)

	it("does not fire when log is empty", function()
		local results = Logic.evaluate(emptyState(), noHints())
		expect(hasId(results, "tier_system")).toBe(false)
	end)

	it("dismissed tier_system does not re-fire", function()
		local state = emptyState()
		state.formulaLog = { { compoundId = "T2_01", discoveredAt = 0 } }
		local results = Logic.evaluate(state, { tier_system = true })
		expect(hasId(results, "tier_system")).toBe(false)
	end)
end)

describe("HintTriggers — syndicate_intro", function()
	it("fires when streak day ≥ 7 and no syndicate", function()
		local state = emptyState()
		state.streak = { day = 7, safeUntil = 0 }
		state.syndicate = nil
		local results = Logic.evaluate(state, noHints())
		expect(hasId(results, "syndicate_intro")).toBe(true)
	end)

	it("does not fire when streak day < 7", function()
		local state = emptyState()
		state.streak = { day = 6, safeUntil = 0 }
		local results = Logic.evaluate(state, noHints())
		expect(hasId(results, "syndicate_intro")).toBe(false)
	end)

	it("does not fire when syndicate exists", function()
		local state = emptyState()
		state.streak = { day = 10, safeUntil = 0 }
		state.syndicate =
			{ id = "syn1", name = "Alpha", members = {}, vaultPellets = 0, upgrades = {}, jointSlots = {}, memberCap = 5 }
		local results = Logic.evaluate(state, noHints())
		expect(hasId(results, "syndicate_intro")).toBe(false)
	end)

	it("does not fire when no streak", function()
		local state = emptyState()
		state.streak = nil
		local results = Logic.evaluate(state, noHints())
		expect(hasId(results, "syndicate_intro")).toBe(false)
	end)

	it("dismissed syndicate_intro does not re-fire", function()
		local state = emptyState()
		state.streak = { day = 8, safeUntil = 0 }
		local results = Logic.evaluate(state, { syndicate_intro = true })
		expect(hasId(results, "syndicate_intro")).toBe(false)
	end)
end)

describe("HintTriggers — patent_mechanics", function()
	it("fires when patents table is non-empty", function()
		local state = emptyState()
		state.patents = { ["T3_01"] = { compoundId = "T3_01", holderCount = 5, challengerCount = 0, state = "HELD" } }
		local results = Logic.evaluate(state, noHints())
		expect(hasId(results, "patent_mechanics")).toBe(true)
	end)

	it("does not fire when patents table is empty", function()
		local results = Logic.evaluate(emptyState(), noHints())
		expect(hasId(results, "patent_mechanics")).toBe(false)
	end)

	it("dismissed patent_mechanics does not re-fire", function()
		local state = emptyState()
		state.patents = { ["T3_01"] = { compoundId = "T3_01", holderCount = 5, challengerCount = 0, state = "HELD" } }
		local results = Logic.evaluate(state, { patent_mechanics = true })
		expect(hasId(results, "patent_mechanics")).toBe(false)
	end)
end)

describe("HintTriggers — event_intro", function()
	it("fires when flux is non-nil", function()
		local state = emptyState()
		state.flux = { seasonKey = "2026-S1", total = 0 }
		local results = Logic.evaluate(state, noHints())
		expect(hasId(results, "event_intro")).toBe(true)
	end)

	it("does not fire when flux is nil", function()
		local results = Logic.evaluate(emptyState(), noHints())
		expect(hasId(results, "event_intro")).toBe(false)
	end)

	it("dismissed event_intro does not re-fire", function()
		local state = emptyState()
		state.flux = { seasonKey = "2026-S1", total = 0 }
		local results = Logic.evaluate(state, { event_intro = true })
		expect(hasId(results, "event_intro")).toBe(false)
	end)
end)

describe("HintTriggers — multiple hints", function()
	it("multiple hints can fire simultaneously", function()
		local state = emptyState()
		state.formulaLog = { { compoundId = "T2_01", discoveredAt = 0 } }
		state.flux = { seasonKey = "2026-S1", total = 10 }
		local results = Logic.evaluate(state, noHints())
		expect(hasId(results, "market_intro")).toBe(true)
		expect(hasId(results, "event_intro")).toBe(true)
	end)

	it("selectively dismissing one hint leaves others active", function()
		local state = emptyState()
		state.formulaLog = { { compoundId = "T2_01", discoveredAt = 0 } }
		state.flux = { seasonKey = "2026-S1", total = 10 }
		local results = Logic.evaluate(state, { market_intro = true })
		expect(hasId(results, "market_intro")).toBe(false)
		expect(hasId(results, "event_intro")).toBe(true)
	end)
end)

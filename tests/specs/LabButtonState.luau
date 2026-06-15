-- Tests for pure LabButtonStateLogic (§ client Phase 12A).
-- Does NOT require LabController (Roblox globals) — tests the extracted pure fn directly.

local spec = require("../spec")
local Logic = require("../../src/shared/Core/LabButtonStateLogic")

local describe, it, expect = spec.describe, spec.it, spec.expect

-- Helper: build params with sensible defaults, override per-test.
local function params(overrides: { [string]: any })
	local base = {
		input1 = "T1_01",
		input2 = "T1_02",
		tier1 = 1,
		tier2 = 1,
		isJointRequired = false,
		isDiscovered = false,
		isVariablePair = false,
	}
	for k, v in pairs(overrides) do
		base[k] = v
	end
	return base
end

-- Baseline for nil tests: table with no input fields (pairs skips nil, so construct directly).
local function nilParams(overrides: { [string]: any })
	local base = {
		tier1 = 1,
		tier2 = 1,
		isJointRequired = false,
		isDiscovered = false,
		isVariablePair = false,
	}
	for k, v in pairs(overrides) do
		base[k] = v
	end
	return base
end

describe("LabButtonState — SELECT_INPUTS", function()
	it("nil input1 → SELECT_INPUTS", function()
		expect(Logic.compute(nilParams({ input2 = "T1_02" }))).toBe("SELECT_INPUTS")
	end)

	it("nil input2 → SELECT_INPUTS", function()
		expect(Logic.compute(nilParams({ input1 = "T1_01" }))).toBe("SELECT_INPUTS")
	end)

	it("both nil → SELECT_INPUTS", function()
		expect(Logic.compute(nilParams({}))).toBe("SELECT_INPUTS")
	end)
end)

describe("LabButtonState — INVALID (exotic T7)", function()
	it("tier1 = 7 → INVALID", function()
		expect(Logic.compute(params({ tier1 = 7 }))).toBe("INVALID")
	end)

	it("tier2 = 7 → INVALID", function()
		expect(Logic.compute(params({ tier2 = 7 }))).toBe("INVALID")
	end)

	it("both T7 → INVALID", function()
		expect(Logic.compute(params({ tier1 = 7, tier2 = 7 }))).toBe("INVALID")
	end)
end)

describe("LabButtonState — JOINT_REQUIRED", function()
	it("isJointRequired true + T5+T5 → JOINT_REQUIRED", function()
		expect(Logic.compute(params({ tier1 = 5, tier2 = 5, isJointRequired = true }))).toBe("JOINT_REQUIRED")
	end)

	it("isJointRequired true + T4+T5 → JOINT_REQUIRED", function()
		expect(Logic.compute(params({ tier1 = 4, tier2 = 5, isJointRequired = true }))).toBe("JOINT_REQUIRED")
	end)

	it("isJointRequired true + T6+T6 → JOINT_REQUIRED", function()
		expect(Logic.compute(params({ tier1 = 6, tier2 = 6, isJointRequired = true }))).toBe("JOINT_REQUIRED")
	end)
end)

describe("LabButtonState — ANALYZE (undiscovered)", function()
	it("no discovery, not joint → ANALYZE", function()
		expect(Logic.compute(params({ isDiscovered = false, isJointRequired = false }))).toBe("ANALYZE")
	end)

	it("T3+T4 undiscovered → ANALYZE", function()
		expect(Logic.compute(params({ tier1 = 3, tier2 = 4, isDiscovered = false }))).toBe("ANALYZE")
	end)
end)

describe("LabButtonState — SYNTHESIZE (discovered, non-variable)", function()
	it("discovered non-variable → SYNTHESIZE", function()
		expect(Logic.compute(params({ isDiscovered = true, isVariablePair = false }))).toBe("SYNTHESIZE")
	end)

	it("T2+T3 discovered non-variable → SYNTHESIZE", function()
		expect(Logic.compute(params({ tier1 = 2, tier2 = 3, isDiscovered = true, isVariablePair = false }))).toBe(
			"SYNTHESIZE"
		)
	end)
end)

describe("LabButtonState — SYNTHESIZE_VARIABLE (discovered, variable)", function()
	it("discovered variable pair → SYNTHESIZE_VARIABLE", function()
		expect(Logic.compute(params({ isDiscovered = true, isVariablePair = true }))).toBe("SYNTHESIZE_VARIABLE")
	end)
end)

describe("LabButtonState — priority ordering", function()
	it("T7 beats JOINT_REQUIRED", function()
		expect(Logic.compute(params({ tier1 = 7, isJointRequired = true }))).toBe("INVALID")
	end)

	it("JOINT_REQUIRED beats ANALYZE", function()
		expect(Logic.compute(params({ isJointRequired = true, isDiscovered = false }))).toBe("JOINT_REQUIRED")
	end)

	it("JOINT_REQUIRED beats SYNTHESIZE", function()
		expect(Logic.compute(params({ isJointRequired = true, isDiscovered = true, isVariablePair = false }))).toBe(
			"JOINT_REQUIRED"
		)
	end)
end)

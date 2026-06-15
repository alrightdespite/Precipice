-- Phase 11 hardening tests — covers items not reachable through Roblox-globals services.
-- All tests are pure Luau or use the injection pattern directly.

local spec = require("../spec")
local EventCompounds = require("../../src/shared/Data/EventCompounds")
local AnalyticsService = require("../../src/server/Services/AnalyticsService")

local describe, it, expect = spec.describe, spec.it, spec.expect

-- ── AnalyticsService — no-error (item 8) ──────────────────────────────────

describe("AnalyticsService — track does not error", function()
	it("track with each defined event constant and arbitrary payload succeeds", function()
		for _, eventName in pairs(AnalyticsService.Events) do
			local ok, err = pcall(AnalyticsService.track, eventName, {
				userId = 123,
				compoundId = "T2_01",
				extra = true,
			})
			expect(ok).toBeTrue()
			expect(err).toBeNil()
		end
	end)

	it("track with unknown event name and empty payload does not error", function()
		local ok, err = pcall(AnalyticsService.track, "unknown_event", {})
		expect(ok).toBeTrue()
		expect(err).toBeNil()
	end)
end)

-- ── Event compound blueprint gate — pure logic (item 4) ───────────────────

describe("SlotStartSynthesis — event compound blueprint gate (pure logic)", function()
	local firstEventId: string? = nil
	for k in pairs(EventCompounds) do
		firstEventId = k
		break
	end

	it("EventCompounds table is non-empty (gate has compounds to protect)", function()
		expect(firstEventId ~= nil).toBeTrue()
	end)

	it("event compound without blueprint in profile.blueprints is gated", function()
		assert(firstEventId ~= nil, "no event compounds")
		local data = { blueprints = {} }
		local isBlocked = EventCompounds[firstEventId] ~= nil
			and not (data.blueprints or {})[firstEventId]
		expect(isBlocked).toBeTrue()
	end)

	it("event compound with blueprint in profile.blueprints passes gate", function()
		assert(firstEventId ~= nil, "no event compounds")
		local data = { blueprints = { [firstEventId] = true } }
		local isBlocked = EventCompounds[firstEventId] ~= nil
			and not (data.blueprints or {})[firstEventId]
		expect(isBlocked).toBeFalse()
	end)

	it("non-event compound is never gated regardless of blueprints", function()
		local nonEventId = "T2_01"
		local data = { blueprints = {} }
		local isBlocked = EventCompounds[nonEventId] ~= nil
			and not (data.blueprints or {})[nonEventId]
		expect(isBlocked).toBeFalse()
	end)
end)

-- ── FormulaLogRequest handler logic (item 3) ──────────────────────────────

describe("FormulaLogRequest handler — session guard and data return", function()
	-- Simulate the handler logic directly (LabService uses Roblox globals so we test the pattern)
	local function simulateHandler(loaded: { [number]: boolean }, profiles: { [number]: any }, userId: number): any
		if not loaded[userId] then return {} end
		local data = profiles[userId]
		if not data then return {} end
		return data.formulaLog
	end

	it("returns formulaLog when session is loaded", function()
		local formulaLog = { discovered = { T2_01 = true }, validatedPairs = {}, failedPairs = {} }
		local loaded = { [42] = true }
		local profiles = { [42] = { formulaLog = formulaLog } }
		local result = simulateHandler(loaded, profiles, 42)
		expect(result).toBe(formulaLog)
		expect(result.discovered["T2_01"]).toBeTrue()
	end)

	it("returns empty table when session is not loaded", function()
		local loaded: { [number]: boolean } = {}
		local profiles: { [number]: any } = {}
		local result = simulateHandler(loaded, profiles, 99)
		expect(type(result)).toBe("table")
		local count = 0
		for _ in pairs(result) do count += 1 end
		expect(count).toBe(0)
	end)
end)

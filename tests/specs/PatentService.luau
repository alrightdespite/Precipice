-- PatentService tests.
-- Mandatory per docs/specs/PatentService.md:
--   - Defense windows for all 7 tiers
--   - First claim
--   - Challenge opens
--   - Immunity blocks
--   - Multi-party race (holder H, challenger C, queued third T; two sweep passes)
--   - Queue processing

local spec = require("../spec")
local PatentWindow = require("../../src/shared/Core/PatentWindow")
local SynthCountService = require("../../src/server/Services/SynthCountService")
local PatentService = require("../../src/server/Services/PatentService")
local MockDataStore = require("../mocks/MockDataStore")

local describe, it, expect = spec.describe, spec.it, spec.expect

-- Minimal compound table used for all patent tests.
-- Only T4_01 (tier 4) and T2_01 (tier 2) are needed.
local TEST_COMPOUNDS = {
	["T4_01"] = { id = "T4_01", tier = 4 },
	["T2_01"] = { id = "T2_01", tier = 2 },
}

-- Reset both services with fresh MockDataStores before each test.
local function setup()
	local synthDs = MockDataStore.new()
	local patentDs = MockDataStore.new()
	SynthCountService._setDs(synthDs)
	PatentService._setDs(patentDs)
	PatentService._setScs(SynthCountService)
	PatentService._setPw(PatentWindow)
	PatentService._setRs(nil) -- no remote fires in tests
	PatentService._setCompounds(TEST_COMPOUNDS)
	return synthDs, patentDs
end

-- Convenience: call recordNaturalSynthesis n times for a player.
local function synthesize(player, compoundId, n, now)
	for _ = 1, n do
		PatentService.recordNaturalSynthesis(player, compoundId, {}, now)
	end
end

-- ── Defense windows (§15) ──────────────────────────────────────────────────

describe("PatentWindow — defense windows §15", function()
	it("T2 window = 72 hours", function()
		expect(PatentWindow.windowSeconds(2)).toBe(72 * 3600)
	end)
	it("T3 window = 72 hours", function()
		expect(PatentWindow.windowSeconds(3)).toBe(72 * 3600)
	end)
	it("T4 window = 96 hours", function()
		expect(PatentWindow.windowSeconds(4)).toBe(96 * 3600)
	end)
	it("T5 window = 120 hours", function()
		expect(PatentWindow.windowSeconds(5)).toBe(120 * 3600)
	end)
	it("T6 window = 168 hours (7 days)", function()
		expect(PatentWindow.windowSeconds(6)).toBe(7 * 24 * 3600)
	end)
	it("T7 window = 168 hours (7 days)", function()
		expect(PatentWindow.windowSeconds(7)).toBe(7 * 24 * 3600)
	end)
end)

-- ── First claim ───────────────────────────────────────────────────────────

describe("PatentService — first claim", function()
	it("nil record → new PatentRecord with correct fields", function()
		setup()
		local H = { UserId = 101 }
		local now = 1_000_000

		PatentService.recordNaturalSynthesis(H, "T4_01", {}, now)

		local record = PatentService.getRecord("T4_01")
		expect(record ~= nil).toBeTrue()
		expect(record.holderId).toBe(101)
		expect(record.firstClaimantId).toBe(101)
		expect(record.tier).toBe(4)
		expect(record.challenge).toBeNil()
		expect(record.immunityUntil).toBeNil()
		expect(#record.challengeQueue).toBe(0)
	end)

	it("second synthesis by same user does not overwrite the record", function()
		setup()
		local H = { UserId = 101 }
		local now = 1_000_000
		PatentService.recordNaturalSynthesis(H, "T4_01", {}, now)
		PatentService.recordNaturalSynthesis(H, "T4_01", {}, now)

		local record = PatentService.getRecord("T4_01")
		expect(record.holderId).toBe(101)
		expect(record.challenge).toBeNil()
	end)
end)

-- ── Challenge opens ───────────────────────────────────────────────────────

describe("PatentService — challenge opens", function()
	it("challenger with higher 30-day count opens a challenge window", function()
		setup()
		local H = { UserId = 101 }
		local C = { UserId = 102 }
		local now = 2_000_000

		-- H claims (H.count = 1)
		PatentService.recordNaturalSynthesis(H, "T4_01", {}, now)

		-- C synthesizes twice → C.count = 2 > H.count = 1 → challenge on 2nd call
		PatentService.recordNaturalSynthesis(C, "T4_01", {}, now)
		PatentService.recordNaturalSynthesis(C, "T4_01", {}, now)

		local record = PatentService.getRecord("T4_01")
		expect(record.holderId).toBe(101) -- H still holds
		expect(record.challenge ~= nil).toBeTrue()
		expect(record.challenge.challengerId).toBe(102)
		-- T4 window = 96h = 345600s
		expect(record.challenge.windowEnd).toBe(now + 96 * 3600)
	end)

	it("challenger with equal count does NOT open a challenge", function()
		setup()
		local H = { UserId = 101 }
		local C = { UserId = 102 }
		local now = 2_000_000

		-- H.count = 1, C.count = 1 — tie; no challenge
		PatentService.recordNaturalSynthesis(H, "T4_01", {}, now)
		PatentService.recordNaturalSynthesis(C, "T4_01", {}, now)

		local record = PatentService.getRecord("T4_01")
		expect(record.challenge).toBeNil()
	end)

	it("holder synthesizing again does not challenge themselves", function()
		setup()
		local H = { UserId = 101 }
		local now = 2_000_000
		synthesize(H, "T4_01", 5, now) -- 5 calls, all same player

		local record = PatentService.getRecord("T4_01")
		expect(record.challenge).toBeNil()
		expect(record.holderId).toBe(101)
	end)
end)

-- ── Immunity blocks ───────────────────────────────────────────────────────

describe("PatentService — immunity blocks challenge", function()
	it("recordNaturalSynthesis no-ops when isInImmunity is true", function()
		local _, patentDs = setup()
		local H = { UserId = 101 }
		local C = { UserId = 102 }
		local now = 3_000_000

		-- H claims
		PatentService.recordNaturalSynthesis(H, "T4_01", {}, now)

		-- Manually set immunity on the record (simulating post-resolution state)
		patentDs:UpdateAsync("patent:T4_01", function(record)
			record.immunityUntil = now + 7 * 86400
			return record
		end)

		-- C has higher count but can't challenge during immunity
		synthesize(C, "T4_01", 5, now)

		local record = PatentService.getRecord("T4_01")
		expect(record.challenge).toBeNil()
		expect(record.holderId).toBe(H.UserId)
	end)
end)

-- ── Multi-party race (mandatory §spec) ───────────────────────────────────

describe("PatentService — multi-party race", function()
	it("H holds → C challenges → T queued → sweep 1: C wins, T gets window → sweep 2: T wins", function()
		setup()

		local H = { UserId = 1001 }
		local C = { UserId = 1002 }
		local T = { UserId = 1003 }
		local compound = "T4_01"
		local t0 = 10_000_000

		-- ── Phase 1: H claims ──────────────────────────────────────────────
		-- H.count = 1 after this call
		PatentService.recordNaturalSynthesis(H, compound, {}, t0)

		local record = PatentService.getRecord(compound)
		expect(record.holderId).toBe(H.UserId)
		expect(record.challenge).toBeNil()

		-- ── Phase 2: C opens challenge ────────────────────────────────────
		-- C needs count > 1 (H's count). Two calls → C.count = 2.
		-- 1st call: C.count=1, H.count=1 → no challenge
		PatentService.recordNaturalSynthesis(C, compound, {}, t0 + 100)
		-- 2nd call: C.count=2, H.count=1 → challenge opens
		PatentService.recordNaturalSynthesis(C, compound, {}, t0 + 200)

		record = PatentService.getRecord(compound)
		expect(record.holderId).toBe(H.UserId)
		expect(record.challenge ~= nil).toBeTrue()
		expect(record.challenge.challengerId).toBe(C.UserId)
		local challengeWindowEnd = record.challenge.windowEnd -- t0+200 + 96h

		-- ── Phase 3: T gets queued ────────────────────────────────────────
		-- T needs count > holder(1) AND > challenger(2) → needs 3 calls.
		-- Call 1: T.count=1; 1>1? No.
		PatentService.recordNaturalSynthesis(T, compound, {}, t0 + 300)
		-- Call 2: T.count=2; 2>1 YES, 2>2? No.
		PatentService.recordNaturalSynthesis(T, compound, {}, t0 + 400)
		-- Call 3: T.count=3; 3>1 YES, 3>2 YES → queued.
		PatentService.recordNaturalSynthesis(T, compound, {}, t0 + 500)

		record = PatentService.getRecord(compound)
		expect(record.holderId).toBe(H.UserId)
		expect(record.challenge.challengerId).toBe(C.UserId)
		expect(#record.challengeQueue).toBe(1)
		expect(record.challengeQueue[1].challengerId).toBe(T.UserId)

		-- ── Phase 4: Sweep 1 — window expires, C wins, T pops from queue ──
		local sweep1Time = challengeWindowEnd + 1
		PatentService.runDecaySweep(sweep1Time)

		record = PatentService.getRecord(compound)
		-- C.count=2 > H.count=1 → C wins
		expect(record.holderId).toBe(C.UserId)
		-- Queue had T → T pops and gets a new challenge window immediately
		expect(record.challenge ~= nil).toBeTrue()
		expect(record.challenge.challengerId).toBe(T.UserId)
		-- No immunity when queue pops
		expect(record.immunityUntil).toBeNil()
		expect(#record.challengeQueue).toBe(0)

		-- ── Phase 5: Sweep 2 — T's window expires, T wins ─────────────────
		local sweep2WindowEnd = record.challenge.windowEnd
		local sweep2Time = sweep2WindowEnd + 1
		PatentService.runDecaySweep(sweep2Time)

		record = PatentService.getRecord(compound)
		-- T.count=3 > C.count=2 → T wins
		expect(record.holderId).toBe(T.UserId)
		expect(record.challenge).toBeNil()
		expect(#record.challengeQueue).toBe(0)
		-- Immunity applied (no queue to pop)
		expect(record.immunityUntil ~= nil).toBeTrue()
		expect(record.immunityUntil).toBe(sweep2Time + PatentWindow.immunitySeconds)
	end)
end)

-- ── Queue processing ──────────────────────────────────────────────────────

describe("PatentService — queue processing", function()
	it("after resolution with empty queue, new holder gets immunity", function()
		setup()
		local H = { UserId = 201 }
		local C = { UserId = 202 }
		local now = 5_000_000

		-- H claims
		PatentService.recordNaturalSynthesis(H, "T4_01", {}, now)

		-- C challenges (C.count=2, H.count=1)
		PatentService.recordNaturalSynthesis(C, "T4_01", {}, now)
		PatentService.recordNaturalSynthesis(C, "T4_01", {}, now)

		local record = PatentService.getRecord("T4_01")
		local windowEnd = record.challenge.windowEnd
		local sweepTime = windowEnd + 1

		-- Sweep with empty queue
		PatentService.runDecaySweep(sweepTime)

		record = PatentService.getRecord("T4_01")
		expect(record.holderId).toBe(C.UserId) -- C.count=2 > H.count=1
		expect(record.challenge).toBeNil()
		expect(record.immunityUntil).toBe(sweepTime + PatentWindow.immunitySeconds)
	end)

	it("duplicate queue entries are rejected", function()
		setup()
		local H = { UserId = 301 }
		local C = { UserId = 302 }
		local T = { UserId = 303 }
		local now = 6_000_000

		-- H claims (H.count=1), C challenges (C.count=2)
		PatentService.recordNaturalSynthesis(H, "T4_01", {}, now)
		PatentService.recordNaturalSynthesis(C, "T4_01", {}, now)
		PatentService.recordNaturalSynthesis(C, "T4_01", {}, now)

		-- T synthesizes enough to qualify for queue (T.count=3 > H.count=1, C.count=2)
		synthesize(T, "T4_01", 3, now)

		-- T synthesizes more — should NOT be added to queue again
		synthesize(T, "T4_01", 3, now)

		local record = PatentService.getRecord("T4_01")
		expect(#record.challengeQueue).toBe(1) -- T appears exactly once
		expect(record.challengeQueue[1].challengerId).toBe(T.UserId)
	end)

	it("holder is immune after sweep resolves with no queue — rival cannot challenge", function()
		setup()
		local H = { UserId = 401 }
		local C = { UserId = 402 }
		local Rival = { UserId = 403 }
		local now = 7_000_000

		PatentService.recordNaturalSynthesis(H, "T4_01", {}, now)
		PatentService.recordNaturalSynthesis(C, "T4_01", {}, now)
		PatentService.recordNaturalSynthesis(C, "T4_01", {}, now)

		local record = PatentService.getRecord("T4_01")
		PatentService.runDecaySweep(record.challenge.windowEnd + 1)

		-- C now holds with immunity; Rival has higher count but cannot challenge
		synthesize(Rival, "T4_01", 5, now)

		record = PatentService.getRecord("T4_01")
		expect(record.holderId).toBe(C.UserId)
		expect(record.challenge).toBeNil() -- immunity blocked the challenge
	end)
end)

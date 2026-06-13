-- SynthCountService tests.
-- Covers recordCompletion (append + prune), getCount, getCountForWindow, getCountForUser.

local spec = require("../spec")
local SynthCountService = require("../../src/server/Services/SynthCountService")
local MockDataStore = require("../mocks/MockDataStore")

local describe, it, expect = spec.describe, spec.it, spec.expect

local THIRTY_DAYS = 30 * 86400

local function freshDs()
	local ds = MockDataStore.new()
	SynthCountService._setDs(ds)
	return ds
end

describe("SynthCountService — recordCompletion", function()
	it("appends an entry and makes it visible to getCount", function()
		freshDs()
		local now = 1_000_000
		SynthCountService.recordCompletion("T1_01", 101, now)
		expect(SynthCountService.getCount("T1_01", now)).toBe(1)
	end)

	it("multiple completions accumulate", function()
		freshDs()
		local now = 1_000_000
		SynthCountService.recordCompletion("T1_01", 101, now)
		SynthCountService.recordCompletion("T1_01", 102, now)
		SynthCountService.recordCompletion("T1_01", 101, now)
		expect(SynthCountService.getCount("T1_01", now)).toBe(3)
	end)

	it("prunes entries older than 30 days on write", function()
		freshDs()
		local old = 1_000_000
		local now = old + THIRTY_DAYS + 1 -- just past the 30-day cutoff

		-- Write two old entries (they will be outside the 30-day window from `now`)
		SynthCountService.recordCompletion("T2_01", 101, old)
		SynthCountService.recordCompletion("T2_01", 102, old)

		-- Write one fresh entry — this triggers a prune pass inside UpdateAsync
		SynthCountService.recordCompletion("T2_01", 103, now)

		-- Only the fresh entry survives
		expect(SynthCountService.getCount("T2_01", now)).toBe(1)
	end)

	it("entry exactly at the 30-day boundary is kept", function()
		freshDs()
		local now = 2_000_000
		local boundary = now - THIRTY_DAYS -- exactly 30 days ago

		SynthCountService.recordCompletion("T1_02", 101, boundary)
		SynthCountService.recordCompletion("T1_02", 102, now) -- triggers prune

		-- boundary timestamp >= cutoff (cutoff == boundary), so it stays
		expect(SynthCountService.getCount("T1_02", now)).toBe(2)
	end)

	it("returns 0 for a compound with no entries", function()
		freshDs()
		expect(SynthCountService.getCount("T6_01", 1_000_000)).toBe(0)
	end)
end)

describe("SynthCountService — getCountForWindow", function()
	it("7-day window returns subset of 30-day entries", function()
		freshDs()
		local now = 3_000_000
		local sevenDays = 7 * 86400

		-- Entry 10 days ago (outside 7-day window, inside 30-day window)
		SynthCountService.recordCompletion("T3_01", 101, now - 10 * 86400)
		-- Entry 3 days ago (inside both windows)
		SynthCountService.recordCompletion("T3_01", 102, now - 3 * 86400)
		-- Trigger prune with a fresh entry
		SynthCountService.recordCompletion("T3_01", 103, now)

		local count30 = SynthCountService.getCountForWindow("T3_01", 30, now)
		local count7 = SynthCountService.getCountForWindow("T3_01", sevenDays / 86400, now)

		expect(count30).toBe(3) -- all three entries within 30 days
		expect(count7).toBe(2) -- only 3-day-ago and now entries within 7 days
	end)

	it("0-day window returns only entries at exactly now", function()
		freshDs()
		local now = 1_000_000
		SynthCountService.recordCompletion("T1_03", 101, now - 100)
		SynthCountService.recordCompletion("T1_03", 102, now)
		-- window=0 means cutoff=now; only entries with timestamp >= now count
		expect(SynthCountService.getCountForWindow("T1_03", 0, now)).toBe(1)
	end)
end)

describe("SynthCountService — getCountForUser", function()
	it("counts only entries for the specified userId", function()
		freshDs()
		local now = 5_000_000
		SynthCountService.recordCompletion("T4_01", 101, now)
		SynthCountService.recordCompletion("T4_01", 101, now)
		SynthCountService.recordCompletion("T4_01", 202, now)

		expect(SynthCountService.getCountForUser("T4_01", 101, 30, now)).toBe(2)
		expect(SynthCountService.getCountForUser("T4_01", 202, 30, now)).toBe(1)
		expect(SynthCountService.getCountForUser("T4_01", 999, 30, now)).toBe(0)
	end)

	it("respects the window parameter for per-user count", function()
		freshDs()
		local now = 6_000_000
		-- Entry 20 days ago — inside 30d, outside 7d
		SynthCountService.recordCompletion("T4_02", 101, now - 20 * 86400)
		-- Entry 2 days ago — inside both
		SynthCountService.recordCompletion("T4_02", 101, now - 2 * 86400)
		SynthCountService.recordCompletion("T4_02", 101, now) -- trigger prune

		expect(SynthCountService.getCountForUser("T4_02", 101, 30, now)).toBe(3)
		expect(SynthCountService.getCountForUser("T4_02", 101, 7, now)).toBe(2)
	end)
end)

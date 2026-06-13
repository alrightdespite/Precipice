-- Tests for GlobalJobService H1 lock/ledger/resume pattern.
-- Uses MockDataStore + MockClock; no Roblox globals needed.

local spec = require("../spec")
local GlobalJobService = require("../../src/server/Services/GlobalJobService")
local MockDataStore = require("../mocks/MockDataStore")
local MockClock = require("../mocks/MockClock")

local describe, it, expect = spec.describe, spec.it, spec.expect

describe("GlobalJobService — lock", function()
	it("first claimer acquires the lock", function()
		local ds = MockDataStore.new()
		local clock = MockClock.new(1000)
		local s1 = GlobalJobService.new(ds, function() return clock:now() end, "server-1")

		expect(s1:claimLock("TestJob")).toBeTrue()
	end)

	it("second claimer loses while first holds", function()
		local ds = MockDataStore.new()
		local clock = MockClock.new(1000)
		local s1 = GlobalJobService.new(ds, function() return clock:now() end, "server-1")
		local s2 = GlobalJobService.new(ds, function() return clock:now() end, "server-2")

		local got1 = s1:claimLock("TestJob")
		local got2 = s2:claimLock("TestJob")

		expect(got1).toBeTrue()
		expect(got2).toBeFalse()
	end)

	it("expired lock (TTL elapsed) can be stolen by a new claimer", function()
		local ds = MockDataStore.new()
		local clock = MockClock.new(1000)
		local s1 = GlobalJobService.new(ds, function() return clock:now() end, "server-1")
		local s2 = GlobalJobService.new(ds, function() return clock:now() end, "server-2")

		expect(s1:claimLock("TestJob")).toBeTrue()

		-- Advance past 300 s TTL
		clock:advance(301)

		expect(s2:claimLock("TestJob")).toBeTrue()
	end)

	it("renewLock extends expiry; rival cannot steal before renewed TTL expires", function()
		local ds = MockDataStore.new()
		local clock = MockClock.new(1000)
		local s1 = GlobalJobService.new(ds, function() return clock:now() end, "server-1")
		local s2 = GlobalJobService.new(ds, function() return clock:now() end, "server-2")

		s1:claimLock("RenewJob") -- expiresAt = 1300

		clock:advance(200) -- t=1200; original lock would expire at 1300
		s1:renewLock("RenewJob") -- expiresAt = 1200+300 = 1500

		clock:advance(200) -- t=1400; original would have expired but renewed hasn't
		expect(s2:claimLock("RenewJob")).toBeFalse()

		clock:advance(101) -- t=1501; renewed TTL now elapsed
		expect(s2:claimLock("RenewJob")).toBeTrue()
	end)

	it("releaseLock zeroes expiry so any server can immediately claim", function()
		local ds = MockDataStore.new()
		local clock = MockClock.new(1000)
		local s1 = GlobalJobService.new(ds, function() return clock:now() end, "server-1")
		local s2 = GlobalJobService.new(ds, function() return clock:now() end, "server-2")

		s1:claimLock("ReleaseJob")
		s1:releaseLock("ReleaseJob")

		-- No time advance needed — expiresAt = 0 < now = 1000
		expect(s2:claimLock("ReleaseJob")).toBeTrue()
	end)

	it("non-owner renewLock is a no-op", function()
		local ds = MockDataStore.new()
		local clock = MockClock.new(1000)
		local s1 = GlobalJobService.new(ds, function() return clock:now() end, "server-1")
		local s2 = GlobalJobService.new(ds, function() return clock:now() end, "server-2")

		s1:claimLock("StolenJob")
		local renewed = s2:renewLock("StolenJob")
		expect(renewed).toBeFalse()
	end)
end)

describe("GlobalJobService — ledger and resume", function()
	it("stampStep writes a timestamp for the step", function()
		local ds = MockDataStore.new()
		local clock = MockClock.new(5000)
		local s = GlobalJobService.new(ds, function() return clock:now() end, "server-1")

		s:stampStep("weekly:2026-W24", "dividends")

		local ledger = s:readLedger("weekly:2026-W24")
		expect(ledger["dividends"]).toBe(5000)
	end)

	it("readLedger returns empty table when no record exists", function()
		local ds = MockDataStore.new()
		local clock = MockClock.new(1000)
		local s = GlobalJobService.new(ds, function() return clock:now() end, "server-1")

		local ledger = s:readLedger("weekly:2026-W99")
		expect(type(ledger)).toBe("table")
	end)

	it("resumed job skips already-stamped steps", function()
		local ds = MockDataStore.new()
		local clock = MockClock.new(1000)
		local s = GlobalJobService.new(ds, function() return clock:now() end, "server-1")

		local ran: { string } = {}
		local jobDef: GlobalJobService.JobDef = {
			name = "ResumeJob",
			steps = {
				{ name = "step_a", fn = function() table.insert(ran, "step_a") end },
				{ name = "step_b", fn = function() table.insert(ran, "step_b") end },
				{ name = "step_c", fn = function() table.insert(ran, "step_c") end },
			},
		}

		-- Pre-stamp step_a as if a prior run completed it before crashing
		s:stampStep("resume:run-1", "step_a")

		local ok, err = s:runJob(jobDef, "resume:run-1")
		expect(ok).toBeTrue()
		expect(err).toBeNil()

		-- Only step_b and step_c should have executed
		expect(#ran).toBe(2)
		expect(ran[1]).toBe("step_b")
		expect(ran[2]).toBe("step_c")
	end)

	it("fully-stamped job run is a no-op (all steps skipped)", function()
		local ds = MockDataStore.new()
		local clock = MockClock.new(1000)
		local s = GlobalJobService.new(ds, function() return clock:now() end, "server-1")

		local ran: { string } = {}
		local jobDef: GlobalJobService.JobDef = {
			name = "FullStampJob",
			steps = {
				{ name = "step_x", fn = function() table.insert(ran, "step_x") end },
				{ name = "step_y", fn = function() table.insert(ran, "step_y") end },
			},
		}

		s:stampStep("idempotent:run-1", "step_x")
		s:stampStep("idempotent:run-1", "step_y")

		local ok = s:runJob(jobDef, "idempotent:run-1")
		expect(ok).toBeTrue()
		expect(#ran).toBe(0)
	end)

	it("steps stamp in order; each gets the clock time at execution", function()
		local ds = MockDataStore.new()
		local clock = MockClock.new(100)
		local s = GlobalJobService.new(ds, function() return clock:now() end, "server-1")

		local jobDef: GlobalJobService.JobDef = {
			name = "OrderJob",
			steps = {
				{ name = "first", fn = function() clock:advance(10) end },
				{ name = "second", fn = function() clock:advance(10) end },
			},
		}

		s:runJob(jobDef, "order:run-1")

		local ledger = s:readLedger("order:run-1")
		-- stampStep is called AFTER fn(), so first stamps at 110, second at 120
		expect(ledger["first"]).toBe(110)
		expect(ledger["second"]).toBe(120)
	end)
end)

describe("GlobalJobService — NoopJob end-to-end", function()
	it("NoopJob runs both steps, stamps ledger, releases lock", function()
		local ds = MockDataStore.new()
		local clock = MockClock.new(2000)
		local s = GlobalJobService.new(ds, function() return clock:now() end, "server-1")

		local ok, err = s:runJob(GlobalJobService.NOOP_JOB, "noop:2026-W24")
		expect(ok).toBeTrue()
		expect(err).toBeNil()

		-- Both steps stamped
		local ledger = s:readLedger("noop:2026-W24")
		expect(ledger["noop_a"] ~= nil).toBeTrue()
		expect(ledger["noop_b"] ~= nil).toBeTrue()

		-- Lock released (expiresAt = 0 < now = 2000)
		local lockRecord = ds:GetAsync("lock:NoopTest")
		expect(lockRecord ~= nil).toBeTrue()
		expect(lockRecord.expiresAt).toBe(0)
	end)

	it("second server cannot run NoopJob while first is mid-run", function()
		local ds = MockDataStore.new()
		local clock = MockClock.new(1000)
		local s1 = GlobalJobService.new(ds, function() return clock:now() end, "server-1")
		local s2 = GlobalJobService.new(ds, function() return clock:now() end, "server-2")

		-- s1 grabs lock
		s1:claimLock(GlobalJobService.NOOP_JOB.name)

		-- s2 tries to run the same job
		local ok2, err2 = s2:runJob(GlobalJobService.NOOP_JOB, "noop:2026-W24")
		expect(ok2).toBeFalse()
		expect(err2).toBe("lock not acquired")
	end)
end)

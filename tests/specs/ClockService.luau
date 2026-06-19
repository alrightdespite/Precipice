-- ClockService pure boundary-math tests (daily / Monday-weekly / sweep-bucket detection).
-- Production tick()/init() use Roblox globals and are Studio-tested; only the pure functions run here.
-- Anchor T = 1798416000 = 2026-12-28 00:00 UTC (a Monday), which divides evenly by 86400, 3600,
-- and 900 — so every bucket starts aligned.

local spec = require("../spec")
local ClockService = require("../../src/server/Services/ClockService")

local describe, it, expect = spec.describe, spec.it, spec.expect

local T = 1798416000 -- Monday 2026-12-28 00:00 UTC
local DAY = 86400
local HOUR = 3600
local PATENT = 900
local WEEK = 7 * DAY

describe("ClockService — dayNumber / weekIndex", function()
	it("dayNumber is floor(now/86400)", function()
		expect(ClockService.dayNumber(T)).toBe(20815)
		expect(ClockService.dayNumber(T + 50000)).toBe(20815) -- same UTC day
		expect(ClockService.dayNumber(T + DAY)).toBe(20816)
	end)

	it("weekIndex is constant within a Monday-aligned week", function()
		local mon = ClockService.weekIndex(T)
		local tue = ClockService.weekIndex(T + DAY)
		local sun = ClockService.weekIndex(T + 6 * DAY)
		expect(tue).toBe(mon)
		expect(sun).toBe(mon)
	end)

	it("weekIndex increments at the next Monday boundary", function()
		expect(ClockService.weekIndex(T + WEEK)).toBe(ClockService.weekIndex(T) + 1)
		-- one second before Monday is still the prior week
		expect(ClockService.weekIndex(T + WEEK - 1)).toBe(ClockService.weekIndex(T))
	end)
end)

describe("ClockService — computeSignals", function()
	it("fresh state fires every job on the first tick (E3 backstop)", function()
		local s = ClockService.newState()
		local sig = ClockService.computeSignals(s, T)
		expect(sig.daily).toBeTrue()
		expect(sig.weekly).toBe(ClockService.weekIndex(T))
		expect(sig.patentSweep).toBe(math.floor(T / PATENT))
		expect(sig.marketSweep).toBe(math.floor(T / HOUR))
	end)

	it("an immediate re-tick at the same time fires nothing", function()
		local s = ClockService.newState()
		ClockService.computeSignals(s, T)
		local sig = ClockService.computeSignals(s, T)
		expect(sig.daily).toBeFalse()
		expect(sig.weekly).toBeNil()
		expect(sig.patentSweep).toBeNil()
		expect(sig.marketSweep).toBeNil()
	end)

	it("crossing one 900s bucket fires only the patent sweep", function()
		local s = ClockService.newState()
		ClockService.computeSignals(s, T)
		local sig = ClockService.computeSignals(s, T + PATENT)
		expect(sig.patentSweep).toBe(math.floor((T + PATENT) / PATENT))
		expect(sig.marketSweep).toBeNil() -- still the same hour
		expect(sig.daily).toBeFalse()
		expect(sig.weekly).toBeNil()
	end)

	it("crossing an hour fires the market sweep (and the patent sweep)", function()
		local s = ClockService.newState()
		ClockService.computeSignals(s, T)
		local sig = ClockService.computeSignals(s, T + HOUR)
		expect(sig.marketSweep).toBe(math.floor((T + HOUR) / HOUR))
		expect(sig.patentSweep).toBe(math.floor((T + HOUR) / PATENT))
		expect(sig.daily).toBeFalse()
		expect(sig.weekly).toBeNil()
	end)

	it("crossing a UTC day fires daily but not weekly (same week)", function()
		local s = ClockService.newState()
		ClockService.computeSignals(s, T)
		local sig = ClockService.computeSignals(s, T + DAY)
		expect(sig.daily).toBeTrue()
		expect(sig.weekly).toBeNil()
	end)

	it("crossing to the next Monday fires the weekly rotation", function()
		local s = ClockService.newState()
		ClockService.computeSignals(s, T)
		local sig = ClockService.computeSignals(s, T + WEEK)
		expect(sig.weekly).toBe(ClockService.weekIndex(T) + 1)
		expect(sig.daily).toBeTrue()
	end)
end)

-- SeedService / SeedResolver pure-logic tests.
-- SeedService.init() touches DataStoreService (Studio-tested); we test SeedResolver here.
-- NOTE: SeedResolver is a module singleton. setSalt may only be called once per Lune
-- run, so we call it in the describe body (outside it blocks) and share across tests.

local spec = require("../spec")
local SeedResolver = require("../../src/shared/Core/SeedResolver")

-- Guard: only set salt if this is the first spec to touch SeedResolver.
if not SeedResolver.hasSalt() then
	SeedResolver.setSalt("test-salt-phase2-abc123")
end

spec.describe("SeedResolver — hasSalt", function()
	spec.it("salt is set after setSalt", function()
		spec.expect(SeedResolver.hasSalt()).toBeTrue()
	end)
end)

spec.describe("SeedResolver — getWeekSeed", function()
	spec.it("returns a positive integer", function()
		local seed = SeedResolver.getWeekSeed(1)
		spec.expect(seed > 0).toBeTrue()
		spec.expect(math.floor(seed) == seed).toBeTrue()
	end)

	spec.it("same week always returns same seed (deterministic)", function()
		local a = SeedResolver.getWeekSeed(24)
		local b = SeedResolver.getWeekSeed(24)
		spec.expect(a).toBe(b)
	end)

	spec.it("different weeks return different seeds", function()
		local s1 = SeedResolver.getWeekSeed(1)
		local s2 = SeedResolver.getWeekSeed(2)
		spec.expect(s1 == s2).toBeFalse()
	end)

	spec.it("seed fits in a 32-bit positive integer", function()
		local seed = SeedResolver.getWeekSeed(52)
		spec.expect(seed < 2147483647).toBeTrue()
	end)
end)

spec.describe("SeedResolver — getCurrentWeekNumber", function()
	spec.it("returns a positive number for a real unix timestamp", function()
		-- 2024-06-01 00:00:00 UTC
		local week = SeedResolver.getCurrentWeekNumber(1717200000)
		spec.expect(week > 0).toBeTrue()
	end)

	spec.it("timestamp 7 days later yields same or next week number", function()
		local t = 1717200000
		local w1 = SeedResolver.getCurrentWeekNumber(t)
		local w2 = SeedResolver.getCurrentWeekNumber(t + 7 * 86400)
		-- w2 must equal w1 (same week) or w1 + 1 (crossed boundary)
		spec.expect(w2 == w1 or w2 == w1 + 1).toBeTrue()
	end)

	spec.it("timestamp 14 days later yields a non-decreasing week number", function()
		local t = 1717200000
		local w1 = SeedResolver.getCurrentWeekNumber(t)
		local w2 = SeedResolver.getCurrentWeekNumber(t + 14 * 86400)
		spec.expect(w2 >= w1).toBeTrue()
	end)

	spec.it("same timestamp always returns same week number", function()
		local t = 1717200000
		spec.expect(SeedResolver.getCurrentWeekNumber(t)).toBe(SeedResolver.getCurrentWeekNumber(t))
	end)
end)

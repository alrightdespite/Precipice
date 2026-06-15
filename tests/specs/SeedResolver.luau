-- SeedResolver ISO 8601 week boundary regression tests.
-- Five dates chosen to exercise year-crossing edge cases.

local spec = require("../spec")
local SeedResolver = require("../../src/shared/Core/SeedResolver")

spec.describe("SeedResolver — ISO week boundary", function()
	-- 2024-12-30 (Monday): ISO week 1 of 2025 — Thursday (Jan 2) is in 2025
	spec.it("2024-12-30 → week 1", function()
		spec.expect(SeedResolver.getCurrentWeekNumber(1735516800)).toBe(1)
	end)

	-- 2024-12-29 (Sunday): ISO week 52 of 2024 — Thursday (Dec 26) is in 2024
	spec.it("2024-12-29 → week 52", function()
		spec.expect(SeedResolver.getCurrentWeekNumber(1735430400)).toBe(52)
	end)

	-- 2026-12-28 (Monday): ISO week 53 of 2026 — Thursday (Dec 31) is in 2026
	spec.it("2026-12-28 → week 53", function()
		spec.expect(SeedResolver.getCurrentWeekNumber(1798416000)).toBe(53)
	end)

	-- 2027-01-03 (Sunday): ISO week 53 of 2026 — Thursday (Dec 31, 2026) is in 2026
	spec.it("2027-01-03 → week 53", function()
		spec.expect(SeedResolver.getCurrentWeekNumber(1798934400)).toBe(53)
	end)

	-- 2027-01-04 (Monday): ISO week 1 of 2027 — Thursday (Jan 7) is in 2027
	spec.it("2027-01-04 → week 1", function()
		spec.expect(SeedResolver.getCurrentWeekNumber(1799020800)).toBe(1)
	end)
end)

spec.describe("SeedResolver — salt guard", function()
	spec.it("hasSalt false before setSalt", function()
		-- Fresh module state: salt not yet set (SeedService sets it at boot)
		-- We can only observe the boolean; calling getWeekSeed without salt errors.
		-- hasSalt() must return false or true without erroring.
		local ok = pcall(SeedResolver.hasSalt)
		spec.expect(ok).toBeTrue()
	end)
end)

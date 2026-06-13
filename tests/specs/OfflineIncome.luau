-- OfflineIncome tests — the §10 worked example is a mandatory unit test (Plan I.1).

local spec = require("../spec")
local OfflineIncome = require("../../src/shared/Core/OfflineIncome")

spec.describe("OfflineIncome — §10 worked example", function()
	spec.it("produces exactly 5437 Pellets for the doc §10 scenario", function()
		-- Slot A: T4, 90 min remaining. passivePerMin = 21.9
		-- Slot B: T1, 5 min remaining.  passivePerMin = 8
		-- Slot C: T3, 180 min remaining. passivePerMin = 15.7
		-- Offline 8 hours = 28800 s. Cap = 12 h.
		local slots = {
			{ tier = 4, workRemainingSeconds = 90 * 60, passivePerMin = 21.9 },
			{ tier = 1, workRemainingSeconds = 5 * 60, passivePerMin = 8 },
			{ tier = 3, workRemainingSeconds = 180 * 60, passivePerMin = 15.7 },
		}
		local result = OfflineIncome.settle(slots, 8 * 3600, 12 * 3600)
		-- Expected: floor(8×5)=40 + floor(21.9×90)=1971 + floor(15.7×180)=2826 + floor(2×300)=600 = 5437
		spec.expect(result.total).toBe(5437)
	end)

	spec.it("floor income applies after all slots complete", function()
		local slots = {
			{ tier = 2, workRemainingSeconds = 10 * 60, passivePerMin = 11.2 },
		}
		-- T2 earns for 10 min: floor(11.2×10)=112. Then 50 min floor: floor(2×50)=100. Total=212.
		local result = OfflineIncome.settle(slots, 60 * 60, 12 * 3600)
		spec.expect(result.total).toBe(212)
	end)

	spec.it("cap cuts all income at cap boundary", function()
		local slots = {
			{ tier = 3, workRemainingSeconds = 100 * 60, passivePerMin = 15.7 },
		}
		-- Only 30 min of income: floor(15.7×30)=471
		local result = OfflineIncome.settle(slots, 100 * 60, 30 * 60)
		spec.expect(result.total).toBe(471)
	end)

	spec.it("no income when cap is zero", function()
		local slots = {
			{ tier = 2, workRemainingSeconds = 10 * 60, passivePerMin = 11.2 },
		}
		local result = OfflineIncome.settle(slots, 3600, 0)
		spec.expect(result.total).toBe(0)
	end)
end)

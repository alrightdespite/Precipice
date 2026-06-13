-- TimerMath tests: work-unit settle, completion, display time.

local spec = require("../spec")
local TimerMath = require("../../src/shared/Core/TimerMath")

spec.describe("TimerMath — settle", function()
	spec.it("online mode consumes work at rate 1.0", function()
		local run = { compoundId = "T2_01", workRemaining = 720, lastTickAt = 1000, mode = "online" }
		local settled = TimerMath.settle(run, 1100)
		spec.expect(settled.workRemaining).toBe(620)
	end)

	spec.it("offline mode consumes work at rate 0.8", function()
		local run = { compoundId = "T2_01", workRemaining = 720, lastTickAt = 1000, mode = "offline" }
		local settled = TimerMath.settle(run, 1100) -- 100s elapsed × 0.8 = 80 done
		spec.expect(settled.workRemaining).toBe(640)
	end)

	spec.it("joint mode uses rate 1.0", function()
		local run = { compoundId = "T6_01", workRemaining = 86400, lastTickAt = 0, mode = "joint" }
		local settled = TimerMath.settle(run, 100)
		spec.expect(settled.workRemaining).toBe(86300)
	end)

	spec.it("work never goes below 0", function()
		local run = { compoundId = "T1_01", workRemaining = 50, lastTickAt = 0, mode = "online" }
		local settled = TimerMath.settle(run, 200)
		spec.expect(settled.workRemaining).toBe(0)
	end)
end)

spec.describe("TimerMath — completion", function()
	spec.it("isComplete true when workRemaining = 0", function()
		local run = { compoundId = "T1_01", workRemaining = 0, lastTickAt = 0, mode = "online" }
		spec.expect(TimerMath.isComplete(run)).toBeTrue()
	end)

	spec.it("isComplete false when work remains", function()
		local run = { compoundId = "T1_01", workRemaining = 1, lastTickAt = 0, mode = "online" }
		spec.expect(TimerMath.isComplete(run)).toBeFalse()
	end)
end)

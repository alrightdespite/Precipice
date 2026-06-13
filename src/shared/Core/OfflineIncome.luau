-- OfflineIncome: pure offline income settlement (doc §10, E1).
-- No Roblox globals. Lune-testable.
--
-- Contract:
--   settle(slots, offlineSeconds, capSeconds) → { total, breakdown[] }
--   Each slot: { tier, workRemainingSeconds, passivePerMin }
--   Each slot earns floor(passivePerMin × durationMins) over exactly the time it runs.
--   Duration = min(workRemainingSeconds, effectiveCap). Floor applied once per slot.
--   After the last slot finishes, floor income (2 P/min) for remaining offline time.
--   Cap cuts ALL income — tier and floor — at effectiveCap seconds.
--   The §10 worked example (40+1971+2826+600 = 5437) is a mandatory unit test.

local FLOOR_RATE = 2

export type SlotInput = {
	tier: number,
	workRemainingSeconds: number,
	passivePerMin: number,
}

export type IncomeBreakdown = {
	tier: number,
	durationMins: number,
	pellets: number,
}

export type SettleResult = {
	total: number,
	breakdown: { IncomeBreakdown },
	floorPellets: number,
}

local OfflineIncome = {}

function OfflineIncome.settle(slots: { SlotInput }, offlineSeconds: number, capSeconds: number): SettleResult
	local effectiveCap = math.min(offlineSeconds, capSeconds)
	if effectiveCap <= 0 then
		return { total = 0, breakdown = {}, floorPellets = 0 }
	end

	local breakdown: { IncomeBreakdown } = {}
	local total = 0
	local lastFinish = 0 -- tracks when the last slot finishes (for floor)

	for _, slot in ipairs(slots) do
		local durationSec = math.min(slot.workRemainingSeconds, effectiveCap)
		if durationSec <= 0 then
			continue
		end
		local durationMin = durationSec / 60
		local pellets = math.round(slot.passivePerMin * durationMin)
		if pellets > 0 then
			table.insert(breakdown, { tier = slot.tier, durationMins = durationMin, pellets = pellets })
			total += pellets
		end
		if slot.workRemainingSeconds < effectiveCap then
			-- This slot finishes before cap; track latest finish for floor calculation
			lastFinish = math.max(lastFinish, slot.workRemainingSeconds)
		else
			-- Slot is still running when cap hits; no floor needed for this slot
			lastFinish = effectiveCap
		end
	end

	-- Floor income: applies only when ALL personal slots are simultaneously empty
	-- Compute the earliest time all slots have finished (= max of all completions capped)
	local allFinished = 0
	for _, slot in ipairs(slots) do
		if slot.workRemainingSeconds < effectiveCap then
			allFinished = math.max(allFinished, slot.workRemainingSeconds)
		else
			-- At least one slot runs to the cap; no empty period
			allFinished = effectiveCap
			break
		end
	end

	local floorSec = effectiveCap - allFinished
	local floorPellets = 0
	if floorSec > 0 then
		floorPellets = math.round(FLOOR_RATE * (floorSec / 60))
		if floorPellets > 0 then
			table.insert(breakdown, { tier = 0, durationMins = floorSec / 60, pellets = floorPellets })
			total += floorPellets
		end
	end

	return { total = total, breakdown = breakdown, floorPellets = floorPellets }
end

return OfflineIncome

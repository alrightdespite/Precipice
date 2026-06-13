-- OfflineIncome: pure offline income settlement (doc §10, E1).
-- No Roblox globals. Lune-testable.
--
-- Contract:
--   settle(slots, offlineSeconds, capSeconds) → { total, breakdown[] }
--   Each slot: { tier, workRemainingSeconds, passivePerMin }
--   Slots earn at their tier rate for exactly the duration they are running offline.
--   After all slots finish, floor income (2 Pellets/min) applies for remaining offline time.
--   Cap cuts ALL income — tier income, joint income, and floor income — at capSeconds.
--   An active Joint Synthesis run does NOT suppress the floor (floor checks personal slots only).
--   The §10 worked example (40+1971+2826+600 = 5437) is a mandatory unit test.

local FLOOR_RATE = 2 -- Pellets/min when all personal slots are empty

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
	local effectiveSeconds = math.min(offlineSeconds, capSeconds)
	local remaining = effectiveSeconds

	-- Sort slots by completion time ascending (shortest first = complete soonest)
	local sorted = table.clone(slots)
	table.sort(sorted, function(a, b)
		return a.workRemainingSeconds < b.workRemainingSeconds
	end)

	local breakdown: { IncomeBreakdown } = {}
	local total = 0
	local lastMark = 0 -- seconds since went offline

	-- Process each slot's completion in order
	local activeCount = #sorted
	local i = 1
	while i <= #sorted do
		local slot = sorted[i]
		local completionTime = slot.workRemainingSeconds
		if completionTime > effectiveSeconds then
			-- This slot doesn't complete within cap; earn for remaining time
			local durationSec = effectiveSeconds - lastMark
			local durationMin = durationSec / 60
			local pellets = math.floor(slot.passivePerMin * durationMin)
			if pellets > 0 then
				table.insert(breakdown, {
					tier = slot.tier,
					durationMins = durationMin,
					pellets = pellets,
				})
				total = total + pellets
			end
			lastMark = effectiveSeconds
			-- Advance remaining slots too (they also earn for this stretch)
			for j = i + 1, #sorted do
				local s2 = sorted[j]
				local dur = durationSec / 60
				local p = math.floor(s2.passivePerMin * dur)
				if p > 0 then
					table.insert(breakdown, { tier = s2.tier, durationMins = dur, pellets = p })
					total = total + p
				end
			end
			break
		end

		-- All slots that finish at or before this completion time earn for the stretch
		local stretchSec = completionTime - lastMark
		if stretchSec > 0 then
			for j = i, #sorted do
				local s = sorted[j]
				local durationMin = stretchSec / 60
				local pellets = math.floor(s.passivePerMin * durationMin)
				if pellets > 0 then
					table.insert(breakdown, {
						tier = s.tier,
						durationMins = durationMin,
						pellets = pellets,
					})
					total = total + pellets
				end
			end
		end
		lastMark = completionTime
		activeCount = activeCount - 1
		i = i + 1

		-- If all personal slots now empty, apply floor for remaining time
		if activeCount == 0 then
			local floorSec = effectiveSeconds - lastMark
			if floorSec > 0 then
				local floorPellets = math.floor(FLOOR_RATE * (floorSec / 60))
				if floorPellets > 0 then
					table.insert(breakdown, { tier = 0, durationMins = floorSec / 60, pellets = floorPellets })
					total = total + floorPellets
				end
			end
			return { total = total, breakdown = breakdown, floorPellets = math.floor(FLOOR_RATE * ((effectiveSeconds - completionTime) / 60)) }
		end
	end

	-- If we never ran out of slots, compute floor for any trailing empty time
	-- (handled above in the per-slot completion loop)
	return { total = total, breakdown = breakdown, floorPellets = 0 }
end

return OfflineIncome

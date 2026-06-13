-- TimerMath: pure timer work-unit calculations (doc §8, §9, E1).
-- No Roblox globals. Clock injected. Lune-testable.
--
-- Contract:
--   A run is stored as { workRemaining (seconds at online rate), lastTickAt (unix), mode }
--   mode: "online" (rate 1.0) | "offline" (rate 0.8) | "joint" (rate 1.0, no online bonus)
--   settle(run, now) → run with workRemaining decremented by elapsed × rate.
--   complete(run) → true if workRemaining <= 0.
--   displaySeconds(run, now, isOnline) → display countdown (derived, never stored).
--   Stabilized Synthesis: caller multiplies initial workRemaining × 1.5 before creating run.

local ONLINE_RATE = 1.0
local OFFLINE_RATE = 0.8

export type RunMode = "online" | "offline" | "joint"
export type SlotRun = {
	compoundId: string,
	workRemaining: number,
	lastTickAt: number,
	mode: RunMode,
}

local TimerMath = {}

function TimerMath.settle(run: SlotRun, now: number): SlotRun
	local elapsed = math.max(0, now - run.lastTickAt)
	local rate = if run.mode == "offline" then OFFLINE_RATE else ONLINE_RATE
	local workDone = elapsed * rate
	return {
		compoundId = run.compoundId,
		workRemaining = math.max(0, run.workRemaining - workDone),
		lastTickAt = now,
		mode = run.mode,
	}
end

function TimerMath.isComplete(run: SlotRun): boolean
	return run.workRemaining <= 0
end

function TimerMath.displaySeconds(run: SlotRun, now: number, isOnline: boolean): number
	local settled = TimerMath.settle(run, now)
	local rate = if (run.mode == "joint" or not isOnline) then OFFLINE_RATE else ONLINE_RATE
	if rate <= 0 then
		return settled.workRemaining
	end
	return settled.workRemaining / rate
end

function TimerMath.setMode(run: SlotRun, now: number, isOnline: boolean): SlotRun
	local settled = TimerMath.settle(run, now)
	local newMode: RunMode
	if run.mode == "joint" then
		newMode = "joint"
	elseif isOnline then
		newMode = "online"
	else
		newMode = "offline"
	end
	return {
		compoundId = settled.compoundId,
		workRemaining = settled.workRemaining,
		lastTickAt = now,
		mode = newMode,
	}
end

return TimerMath

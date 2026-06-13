-- PatentWindow: patent defense window math (doc §15, E2).
-- No Roblox globals. Clock injected. Lune-testable.
--
-- Contract:
--   windowSeconds(tier) → defense window in seconds for this tier
--   challengeImmunitySeconds = 7 * 24 * 3600 (post-defense immunity)
--   isChallengeActive(patentRecord, now) → boolean
--   isInImmunity(patentRecord, now) → boolean
--   windowExpired(patentRecord, now) → boolean (window open but time elapsed)
--   sweepIntervalSeconds = 15 * 60 (E2: sweep every 15 min)

local WINDOWS: { [number]: number } = {
	[2] = 72 * 3600,
	[3] = 72 * 3600,
	[4] = 96 * 3600,
	[5] = 120 * 3600,
	[6] = 7 * 24 * 3600,
	[7] = 7 * 24 * 3600,
}

local IMMUNITY_SECONDS = 7 * 24 * 3600
local SWEEP_INTERVAL = 15 * 60

export type Challenge = {
	challengerId: number,
	windowStart: number,
	windowEnd: number,
}

export type PatentRecord = {
	compoundId: string,
	tier: number,
	holderId: number,
	firstClaimantId: number,
	challenge: Challenge?,
	immunityUntil: number?,
}

local PatentWindow = {}

PatentWindow.sweepIntervalSeconds = SWEEP_INTERVAL
PatentWindow.immunitySeconds = IMMUNITY_SECONDS

function PatentWindow.windowSeconds(tier: number): number
	local w = WINDOWS[tier]
	assert(w, "PatentWindow: unknown tier " .. tostring(tier))
	return w
end

function PatentWindow.isChallengeActive(record: PatentRecord, now: number): boolean
	return record.challenge ~= nil and now < record.challenge.windowEnd
end

function PatentWindow.isInImmunity(record: PatentRecord, now: number): boolean
	return record.immunityUntil ~= nil and now < record.immunityUntil
end

function PatentWindow.windowExpired(record: PatentRecord, now: number): boolean
	if not record.challenge then
		return false
	end
	return now >= record.challenge.windowEnd
end

function PatentWindow.newChallenge(record: PatentRecord, challengerId: number, now: number): Challenge
	return {
		challengerId = challengerId,
		windowStart = now,
		windowEnd = now + PatentWindow.windowSeconds(record.tier),
	}
end

return PatentWindow

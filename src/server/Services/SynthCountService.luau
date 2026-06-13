-- SynthCountService: 30-day rolling natural synthesis counts per compound (H6, R12).
-- DataStore: SynthCounts, one key per compoundId.
-- Record shape: { entries: { {userId: number, timestamp: number}[] } }
-- Prunes entries >30 days old on every write (compaction free at write time, H6).
-- Only natural completions (§14) are recorded — callers enforce this.
--
-- TODO Phase 4 hardening: shard hot compounds if write budget exceeded

local THIRTY_DAYS = 30 * 86400

-- ── Injected state ─────────────────────────────────────────────────────────

local _ds: any = nil

-- ── Module ─────────────────────────────────────────────────────────────────

local SynthCountService = {}

-- Inject a mock DataStore for Lune tests.
function SynthCountService._setDs(ds: any)
	_ds = ds
end

-- Production init — called by GameInit.
function SynthCountService.init()
	local DataStoreService = game:GetService("DataStoreService")
	_ds = DataStoreService:GetDataStore("SynthCounts")
end

-- ── Writes ─────────────────────────────────────────────────────────────────

-- Append one natural completion for userId; prune entries older than 30 days
-- in the same UpdateAsync write (H6: compaction is free at write time).
function SynthCountService.recordCompletion(compoundId: string, userId: number, now: number)
	local cutoff = now - THIRTY_DAYS
	_ds:UpdateAsync(compoundId, function(record)
		local r = record or { entries = {} }
		-- Append new entry
		table.insert(r.entries, { userId = userId, timestamp = now })
		-- Prune expired entries in-place
		local fresh = {}
		for _, e in ipairs(r.entries) do
			if e.timestamp >= cutoff then
				table.insert(fresh, e)
			end
		end
		r.entries = fresh
		return r
	end)
end

-- ── Reads ──────────────────────────────────────────────────────────────────

-- Total entries within the 30-day window.
function SynthCountService.getCount(compoundId: string, now: number): number
	return SynthCountService.getCountForWindow(compoundId, 30, now)
end

-- Total entries within a parameterized window (days).
-- Used by PatentService for the 7-day "actively synthesizing" query (R12).
function SynthCountService.getCountForWindow(compoundId: string, windowDays: number, now: number): number
	local cutoff = now - (windowDays * 86400)
	local record = _ds:GetAsync(compoundId)
	if not record then
		return 0
	end
	local count = 0
	for _, e in ipairs(record.entries) do
		if e.timestamp >= cutoff then
			count += 1
		end
	end
	return count
end

-- Per-user entry count within a parameterized window.
-- Used by PatentService to compare holder vs challenger synthesis rates.
function SynthCountService.getCountForUser(
	compoundId: string,
	userId: number,
	windowDays: number,
	now: number
): number
	local cutoff = now - (windowDays * 86400)
	local record = _ds:GetAsync(compoundId)
	if not record then
		return 0
	end
	local count = 0
	for _, e in ipairs(record.entries) do
		if e.timestamp >= cutoff and e.userId == userId then
			count += 1
		end
	end
	return count
end

return SynthCountService

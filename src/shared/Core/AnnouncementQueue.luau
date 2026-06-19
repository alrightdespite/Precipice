-- AnnouncementQueue: min-gap release queue with per-key dedup (§15, A22).
-- No Roblox globals. Clock injected. Lune-testable.
--
-- Global announcements pass through a queue with a minimum 30s gap between broadcasts (§15).
-- Dedup suppresses the same event (e.g. one compound's first-claim) from re-broadcasting within
-- an epoch window. The marquee is cosmetic (design F2 / line 2099), so this is best-effort
-- per-server spam control, not authoritative cross-server arbitration.
--
-- Contract:
--   AnnouncementQueue.new(minGapSeconds, dedupTTLSeconds) -> instance
--   :enqueue(item, now) -> boolean   item = { kind, message, tier?, dedupKey? }; false if deduped
--   :release(now) -> item?           next item if >= minGap since last release, else nil
--   :size() -> number
--   :clearDedup() -> ()              forget dedup memory (e.g. on a new weekly epoch)

local AnnouncementQueue = {}
AnnouncementQueue.__index = AnnouncementQueue

export type Item = { kind: string, message: string, tier: number?, dedupKey: string? }

function AnnouncementQueue.new(minGapSeconds: number, dedupTTLSeconds: number)
	return setmetatable({
		_minGap = minGapSeconds,
		_dedupTTL = dedupTTLSeconds,
		_queue = {} :: { Item },
		_seen = {} :: { [string]: number }, -- dedupKey -> last-enqueued time
		_lastReleaseAt = -math.huge,
	}, AnnouncementQueue)
end

-- Enqueue an item. Returns false (and does not enqueue) if its dedupKey was seen within dedupTTL.
function AnnouncementQueue:enqueue(item: Item, now: number): boolean
	if item.dedupKey then
		local seenAt = self._seen[item.dedupKey]
		if seenAt ~= nil and (now - seenAt) < self._dedupTTL then
			return false
		end
		self._seen[item.dedupKey] = now
	end
	table.insert(self._queue, item)
	return true
end

-- Release the next queued item if at least minGap has elapsed since the previous release.
function AnnouncementQueue:release(now: number): Item?
	if #self._queue == 0 then
		return nil
	end
	if now - self._lastReleaseAt < self._minGap then
		return nil
	end
	self._lastReleaseAt = now
	return table.remove(self._queue, 1)
end

function AnnouncementQueue:size(): number
	return #self._queue
end

function AnnouncementQueue:clearDedup()
	self._seen = {}
end

return AnnouncementQueue

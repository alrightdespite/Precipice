-- RateLimiter: token-bucket throttle for C2S remotes (doc §D hardening — per player+remote).
-- No Roblox globals. Clock injected. Lune-testable.
--
-- A bucket holds up to `capacity` tokens, refilling at `refillRate` tokens/sec. Each request
-- consumes one token; a request with no whole token available is rejected. This allows a short
-- burst (capacity) then settles to the steady rate — the right shape for a spam guard: legit
-- single calls always pass, sustained spam is clamped to the configured rate.
--
-- Contract:
--   RateLimiter.allow(buckets, key, refillRate, capacity, now) -> boolean
--     buckets:    caller-owned table { [key] = { tokens, lastRefill } }, mutated in place
--     key:        stable string, e.g. "<userId>:<remoteName>"
--     refillRate: tokens per second (= the Manifest rateLimit; supports fractional, e.g. 0.1)
--     capacity:   max burst (whole tokens)
--     now:        monotonic seconds
--   RateLimiter.clear(buckets, prefix) -> () drops every bucket whose key starts with prefix

local RateLimiter = {}

function RateLimiter.allow(
	buckets: { [string]: { tokens: number, lastRefill: number } },
	key: string,
	refillRate: number,
	capacity: number,
	now: number
): boolean
	local b = buckets[key]
	if not b then
		-- Fresh bucket starts full, so the very first request is always allowed.
		b = { tokens = capacity, lastRefill = now }
		buckets[key] = b
	else
		local elapsed = now - b.lastRefill
		if elapsed > 0 then
			b.tokens = math.min(capacity, b.tokens + elapsed * refillRate)
			b.lastRefill = now
		end
	end

	if b.tokens >= 1 then
		b.tokens -= 1
		return true
	end
	return false
end

-- Drop all buckets whose key begins with prefix (e.g. "<userId>:") — call on player leave so
-- the table never grows without bound.
function RateLimiter.clear(buckets: { [string]: any }, prefix: string)
	for key in pairs(buckets) do
		if string.sub(key, 1, #prefix) == prefix then
			buckets[key] = nil
		end
	end
end

return RateLimiter

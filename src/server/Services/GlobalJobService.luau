-- GlobalJobService: cross-server singleton lock + ledger for all global jobs (H1).
-- Pattern: CAS lock via UpdateAsync, per-step ledger, resume from first unstamped step.
-- Use GlobalJobService.new(ds, clockFn, serverId) in tests.
-- Use GlobalJobService.init() in GameInit (production).

local LOCK_TTL = 300 -- seconds; renewed every 60s by owner
local LOCK_PREFIX = "lock:"
local LEDGER_PREFIX = "ledger:"

-- ── Types ──────────────────────────────────────────────────────────────────

export type DS = {
	GetAsync: (self: DS, key: string) -> any,
	UpdateAsync: (self: DS, key: string, fn: (any) -> any) -> any,
}

export type JobStep = { name: string, fn: () -> () }
export type JobDef = { name: string, steps: { JobStep } }

export type Instance = {
	claimLock: (self: Instance, jobName: string) -> boolean,
	renewLock: (self: Instance, jobName: string) -> boolean,
	releaseLock: (self: Instance, jobName: string) -> (),
	readLedger: (self: Instance, runKey: string) -> { [string]: number },
	stampStep: (self: Instance, runKey: string, stepName: string) -> (),
	runJob: (self: Instance, jobDef: JobDef, runKey: string) -> (boolean, string?),
}

-- ── Module ─────────────────────────────────────────────────────────────────

local GlobalJobService = {}
GlobalJobService.__index = GlobalJobService

-- Constructor — used directly by tests; also called by init() for the singleton.
function GlobalJobService.new(ds: DS, clockFn: () -> number, serverId: string)
	return setmetatable({
		_ds = ds,
		_clock = clockFn,
		_serverId = serverId,
	}, GlobalJobService)
end

-- ── Lock ───────────────────────────────────────────────────────────────────

-- Claim the lock for jobName. Returns true if acquired.
-- Succeeds when the slot is empty or the existing record has expired (expiresAt < now).
function GlobalJobService:claimLock(jobName: string): boolean
	local now = self._clock()
	local owner = self._serverId
	local claimed = false

	self._ds:UpdateAsync(LOCK_PREFIX .. jobName, function(current)
		if current == nil or current.expiresAt < now then
			claimed = true
			return { owner = owner, expiresAt = now + LOCK_TTL }
		end
		return nil -- leave existing record unchanged
	end)

	return claimed
end

-- Extend expiry by LOCK_TTL from now, only if this server still owns the lock.
function GlobalJobService:renewLock(jobName: string): boolean
	local now = self._clock()
	local renewed = false

	self._ds:UpdateAsync(LOCK_PREFIX .. jobName, function(current)
		if current and current.owner == self._serverId then
			renewed = true
			return { owner = self._serverId, expiresAt = now + LOCK_TTL }
		end
		return nil
	end)

	return renewed
end

-- Release the lock by zeroing expiresAt (makes it immediately stealable).
-- No-ops if this server no longer owns it.
function GlobalJobService:releaseLock(jobName: string)
	self._ds:UpdateAsync(LOCK_PREFIX .. jobName, function(current)
		if current and current.owner == self._serverId then
			return { owner = self._serverId, expiresAt = 0 }
		end
		return nil
	end)
end

-- ── Ledger ─────────────────────────────────────────────────────────────────

-- Read the completion ledger for a run key (e.g. "weekly:2026-W24").
-- Returns a map of stepName → unix timestamp, or {} if no ledger exists yet.
function GlobalJobService:readLedger(runKey: string): { [string]: number }
	return self._ds:GetAsync(LEDGER_PREFIX .. runKey) or {}
end

-- Stamp a step as completed. Written AFTER that step's effects are durable (H1).
function GlobalJobService:stampStep(runKey: string, stepName: string)
	local now = self._clock()
	self._ds:UpdateAsync(LEDGER_PREFIX .. runKey, function(current)
		local ledger = current or {}
		ledger[stepName] = now
		return ledger
	end)
end

-- ── Job runner ─────────────────────────────────────────────────────────────

-- Claim the lock, read the ledger, skip stamped steps, execute from first
-- unstamped step, stamp after each, release on completion or error.
function GlobalJobService:runJob(jobDef: JobDef, runKey: string): (boolean, string?)
	if not self:claimLock(jobDef.name) then
		return false, "lock not acquired"
	end

	local ledger = self:readLedger(runKey)

	for _, step in ipairs(jobDef.steps) do
		if ledger[step.name] then
			continue -- already durably completed in a prior run
		end

		local ok, err = pcall(step.fn)
		if not ok then
			self:releaseLock(jobDef.name)
			return false, "step " .. step.name .. " failed: " .. tostring(err)
		end

		-- Stamp only after the step's effects are written (caller responsibility
		-- for side-effectful jobs; no-op steps stamp immediately).
		self:stampStep(runKey, step.name)
	end

	self:releaseLock(jobDef.name)
	return true, nil
end

-- ── No-op test job ─────────────────────────────────────────────────────────

-- Two-step job that does nothing. Used to prove the lock/ledger/resume pattern
-- without requiring any real job implementation.
GlobalJobService.NOOP_JOB = {
	name = "NoopTest",
	steps = {
		{ name = "noop_a", fn = function() end },
		{ name = "noop_b", fn = function() end },
	},
} :: JobDef

-- ── Production singleton ───────────────────────────────────────────────────

local _instance: any = nil

-- Called from GameInit after DataService (H9 boot order).
-- ClockService will wire epoch-boundary triggers in Phase 4; for now the poll
-- loop runs independently every 60 s as the H3 backstop.
function GlobalJobService.init()
	local DataStoreService = game:GetService("DataStoreService")
	local ds = DataStoreService:GetDataStore("GlobalJobs")
	local serverId = (game.JobId ~= "" and game.JobId) or ("dev-" .. tostring(math.random(1, 99999)))
	_instance = GlobalJobService.new(ds, os.time, serverId)

	-- Poll every 60s: re-check epoch ledger in case MessagingService delivery
	-- was missed (H3). Phase 4 will replace this stub with ClockService calls.
	task.spawn(function()
		while true do
			task.wait(60)
			-- TODO Phase 4: ClockService.onEpochBoundary → runJobIfLeader
		end
	end)
end

function GlobalJobService.getInstance(): any
	return _instance
end

return GlobalJobService

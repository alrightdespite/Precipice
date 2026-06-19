-- ClockService: UTC tick + daily / Monday-weekly epoch detection.
-- Design refs: §15 (Monday dividends → Sprint reset → seed reroll), §21, §7 (variable seed),
-- E3 (every server checks the clock each minute; boundary crossed live, server start is a backstop),
-- F1 (the weekly job is a ledger of week-stamped steps under an expiring lock — resumable, never
-- repeated), H1 (CAS lock via GlobalJobService), H3 (cross-server messages are hints, never truth —
-- this is the authoritative poll). Boot order H9: init() runs before GlobalJobService and must not
-- yield; the tick loop runs in task.spawn and resolves dependent services lazily once boot is done.
--
-- The pure boundary math (newState / dayNumber / weekIndex / computeSignals) carries no Roblox
-- globals and is Lune-tested. tick()/init() are the production driver (Studio-tested).

-- ── Constants ──────────────────────────────────────────────────────────────

local SECONDS_PER_DAY = 86400
local TICK_INTERVAL = 60 -- E3: every server checks the clock each minute
-- Mirrors PatentWindow.sweepIntervalSeconds (15 min, E2) and the hourly market sweep; kept as
-- bare literals here so the pure functions never require a Roblox-pathed module. init() asserts
-- the patent value still matches PatentWindow.
local PATENT_SWEEP_INTERVAL = 15 * 60
local MARKET_SWEEP_INTERVAL = 3600

local ClockService = {}

-- ── Pure boundary math (Lune-tested) ───────────────────────────────────────

export type State = {
	lastDay: number?,
	lastWeek: number?,
	lastPatentBucket: number?,
	lastMarketBucket: number?,
}

export type Signals = {
	daily: boolean,
	weekly: number?, -- weekIndex when a Monday boundary was crossed
	patentSweep: number?, -- bucket index when a 900s window opened
	marketSweep: number?, -- bucket index when an hourly window opened
}

-- Fresh state: all last-seen markers nil so the first tick fires every job as the E3
-- server-start backstop. The GlobalJobService ledger (F1) makes that backstop idempotent —
-- already-stamped steps are skipped, never repeated.
function ClockService.newState(): State
	return { lastDay = nil, lastWeek = nil, lastPatentBucket = nil, lastMarketBucket = nil }
end

-- UTC day number (changes at 00:00 UTC daily).
function ClockService.dayNumber(now: number): number
	return math.floor(now / SECONDS_PER_DAY)
end

-- Monday-aligned absolute week index (changes at Monday 00:00 UTC). Every server computes the
-- same value with zero coordination, so it doubles as the shared weekly ledger run key.
function ClockService.weekIndex(now: number): number
	local days = math.floor(now / SECONDS_PER_DAY)
	local dow = (days + 3) % 7 -- 0=Mon .. 6=Sun (Jan 1 1970 was Thursday); matches SeedResolver
	return math.floor((days - dow) / 7)
end

-- Compare the current time against state, mutate state to the new markers, and return which
-- boundaries fired. Pure aside from mutating the caller-owned state table.
function ClockService.computeSignals(state: State, now: number): Signals
	local day = ClockService.dayNumber(now)
	local week = ClockService.weekIndex(now)
	local patentBucket = math.floor(now / PATENT_SWEEP_INTERVAL)
	local marketBucket = math.floor(now / MARKET_SWEEP_INTERVAL)

	local signals: Signals = { daily = false }

	if state.lastDay ~= day then
		signals.daily = true
		state.lastDay = day
	end
	if state.lastWeek ~= week then
		signals.weekly = week
		state.lastWeek = week
	end
	if state.lastPatentBucket ~= patentBucket then
		signals.patentSweep = patentBucket
		state.lastPatentBucket = patentBucket
	end
	if state.lastMarketBucket ~= marketBucket then
		signals.marketSweep = marketBucket
		state.lastMarketBucket = marketBucket
	end

	return signals
end

-- ── Production job dispatch ─────────────────────────────────────────────────

local _state: State = ClockService.newState()

-- Lazily-resolved service deps. Resolved on first tick (after boot completes), never at module
-- load, so the pure functions above stay free of Roblox globals (Lune-safe) and H9 boot order is
-- respected (ClockService.init runs before these services init).
local _resolved = false
local _gjs: any = nil
local _patentService: any = nil
local _rankService: any = nil
local _marketService: any = nil
local _seedResolver: any = nil
local _announcementService: any = nil
local _leaderboardService: any = nil

local function resolveDeps()
	if _resolved then
		return
	end
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	_gjs = require(ServerScriptService.Server.Services.GlobalJobService)
	_patentService = require(ServerScriptService.Server.Services.PatentService)
	_rankService = require(ServerScriptService.Server.Services.RankService)
	_marketService = require(ServerScriptService.Server.Services.MarketService)
	_seedResolver = require(ReplicatedStorage.Shared.Core.SeedResolver)
	_announcementService = require(ServerScriptService.Server.Services.AnnouncementService)
	_leaderboardService = require(ServerScriptService.Server.Services.LeaderboardService)
	_resolved = true
end

-- Sprint score wipe (Monday step 3). Sprint scores live in a per-week OrderedDataStore
-- (Sprint_{weekEpoch}) and per-player data.sprintPoints resets lazily when its weekEpoch changes
-- (RankService.addSprintPoints), so the new week starts clean with no destructive write. This step
-- exists to hold the mandated R3 order in the ledger; champion archival happens in sprintArchive.
function ClockService._wipeSprint(_endedWeekEpoch: number)
	-- No-op by construction (week-keyed ODS rotation is implicit). Kept as an explicit ledger step.
end

-- Seed-epoch announcement (Monday step 4). The variable-recipe seed is deterministic from the week
-- number (§7) — every server already agrees, so there is no state to write; this step only
-- announces the new week. The seed itself is deterministic (every server already agrees).
function ClockService._announceSeedEpoch(now: number)
	local week = _seedResolver and _seedResolver.getCurrentWeekNumber(now) or ClockService.weekIndex(now)
	if _announcementService then
		_announcementService.announceSeedEpoch(week)
	end
	print(string.format("ClockService: seed epoch — week %d active", week))
end

-- Monday weekly rotation (R3 mandated order: dividends → Sprint archive+badges → Sprint wipe →
-- seed epoch). Runs as a GlobalJobService ledger keyed by the shared weekIndex (F1): one server
-- claims, a crashed claimant is resumed at the first unstamped step, no step ever repeats.
function ClockService._runWeeklyJob(now: number, weekIndex: number)
	local instance = _gjs.getInstance()
	if not instance then
		return
	end

	-- The week that just ended (Sunday is one day before the Monday boundary). Robust across
	-- year/ISO-week wraps because it is read from the timestamp, not by decrementing.
	local endedWeekEpoch = _seedResolver.getCurrentWeekNumber(now - SECONDS_PER_DAY)
	local weekKey = "weekly:" .. weekIndex

	local jobDef = {
		name = "WeeklyEpochRotation",
		steps = {
			{ name = "dividends", fn = function()
				_patentService.payDividends(weekKey, now)
			end },
			{ name = "sprintArchive", fn = function()
				_rankService.archiveSprint(endedWeekEpoch)
			end },
			{ name = "sprintWipe", fn = function()
				ClockService._wipeSprint(endedWeekEpoch)
			end },
			{ name = "seedEpoch", fn = function()
				ClockService._announceSeedEpoch(now)
			end },
		},
	}

	instance:runJob(jobDef, weekKey)
end

-- 900s patent decay sweep (E2). Resolves expired defense windows to the higher 30-day count.
function ClockService._runPatentSweep(now: number, bucket: number)
	local instance = _gjs.getInstance()
	if not instance then
		return
	end
	instance:runJob({
		name = "PatentDividendSweep",
		steps = {
			{ name = "decaySweep", fn = function()
				_patentService.runDecaySweep(now)
			end },
		},
	}, "patentsweep:" .. bucket)
end

-- Hourly market listing expiry sweep (E7). MarketService had a ready runExpirySweep but no driver
-- — without this, listings never expire in production.
function ClockService._runMarketSweep(now: number, bucket: number)
	local instance = _gjs.getInstance()
	if not instance then
		return
	end
	instance:runJob({
		name = "MarketExpirySweep",
		steps = {
			{ name = "expirySweep", fn = function()
				_marketService.runExpirySweep(now)
			end },
		},
	}, "marketsweep:" .. bucket)
end

-- Hourly percentile blob refresh (§21/E4): recomputes leaderboard rank-checkpoint thresholds so
-- own-row rank estimates beyond the top 100 stay fresh.
function ClockService._runPercentileJob(now: number, bucket: number)
	local instance = _gjs.getInstance()
	if not instance then
		return
	end
	instance:runJob({
		name = "PercentileBlob",
		steps = {
			{ name = "compute", fn = function()
				_leaderboardService.computePercentileBlob(now)
			end },
		},
	}, "percentile:" .. bucket)
end

-- One production tick: detect boundaries against the module state and dispatch any fired jobs.
-- Each job is independently pcall-guarded by GlobalJobService.runJob; a failure in one never
-- blocks another or the next tick.
function ClockService.tick(now: number?)
	now = now or os.time()
	resolveDeps()

	local signals = ClockService.computeSignals(_state, now :: number)

	if signals.patentSweep then
		ClockService._runPatentSweep(now :: number, signals.patentSweep)
	end
	if signals.marketSweep then
		ClockService._runMarketSweep(now :: number, signals.marketSweep)
		-- Percentile blob shares the hourly bucket (E4 hourly refresh).
		ClockService._runPercentileJob(now :: number, signals.marketSweep)
	end
	if signals.weekly then
		ClockService._runWeeklyJob(now :: number, signals.weekly)
	end
	-- signals.daily: contract refresh is login-driven (E8), so no global daily job is needed yet.
	-- Hook left intentionally empty; future daily jobs dispatch here.
end

-- Force an immediate tick (Studio debug / manual trigger) without waiting out TICK_INTERVAL.
function ClockService.forceTick()
	ClockService.tick(os.time())
end

-- ── Init (H9: must not yield) ───────────────────────────────────────────────

function ClockService.init()
	-- Sanity: the bare literal must track PatentWindow's authoritative interval (E2).
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local PatentWindow = require(ReplicatedStorage.Shared.Core.PatentWindow)
	assert(
		PATENT_SWEEP_INTERVAL == PatentWindow.sweepIntervalSeconds,
		"ClockService: PATENT_SWEEP_INTERVAL out of sync with PatentWindow.sweepIntervalSeconds"
	)

	_state = ClockService.newState()

	-- Tick loop runs detached so init() never yields (H9). First tick after one interval gives
	-- the rest of boot time to finish; live servers still pick up a boundary within a minute (E3).
	task.spawn(function()
		while true do
			task.wait(TICK_INTERVAL)
			local ok, err = pcall(ClockService.tick)
			if not ok then
				warn("ClockService: tick failed:", err)
			end
		end
	end)

	print("ClockService: tick loop started (60s)")
end

return ClockService

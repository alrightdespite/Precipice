-- RankService: rank score writes, sprint ODS tracking, RankUpdate S2C.
-- Sprint tracking merged into RankService per Session B decision. No separate SprintService.
-- See addSprintPoints and archiveSprint.
-- No Roblox globals at module level — Lune-testable via injection helpers.

-- ── Injected / initialized state ───────────────────────────────────────────

local _remoteService: any = nil
local _rankMath: any = nil    -- RankMath core module
local _seedResolver: any = nil -- SeedResolver core module
local _compounds: any = nil    -- Compounds data module (lazy-loaded in production)
local _dataStoreService: any = nil
local _chiefOds: any = nil
local _sprintOdsFactory: ((number) -> any)? = nil -- injectable for Lune tests
local _lastSprintWrite: { [number]: number } = {} -- debounce: userId → last written score
-- task.spawn is a Roblox global unavailable in Lune. Default to synchronous
-- execution (fallback); production init() sets this to task.spawn.
local _spawnFn: (((() -> ()) -> ())) = function(fn) fn() end

local RankService = {}

-- ── Test injection helpers ─────────────────────────────────────────────────

function RankService._setRemoteService(rs: any) _remoteService = rs end
function RankService._setRankMath(rm: any) _rankMath = rm end
function RankService._setSeedResolver(sr: any) _seedResolver = sr end
function RankService._setCompounds(c: any) _compounds = c end
function RankService._setChiefOds(ods: any) _chiefOds = ods end
function RankService._setSprintOdsFactory(fn: any) _sprintOdsFactory = fn end
function RankService._setSpawnFn(fn: any) _spawnFn = fn end
function RankService._resetSprintWriteCache() _lastSprintWrite = {} end

-- ── ODS accessors (used by LeaderboardService) ─────────────────────────────

function RankService.getChiefBoardOds(): any
	return _chiefOds
end

function RankService.getSprintOds(weekEpoch: number): any
	if _sprintOdsFactory then
		return _sprintOdsFactory(weekEpoch)
	end
	assert(_dataStoreService, "RankService: not initialized — call init() first")
	return _dataStoreService:GetOrderedDataStore("Sprint_" .. tostring(weekEpoch))
end

-- ── Core score mutation ────────────────────────────────────────────────────

-- addScore: apply rank points from a scored event. Mutates data.rank in-place.
-- Fires RankUpdate S2C. Daily caps apply to "market" and "vault" sources only.
function RankService.addScore(player: any, data: any, amount: number, source: string)
	local RM = _rankMath
	assert(RM, "RankService: RankMath not injected")

	local effective = amount

	if source == "market" or source == "vault" then
		local today = os.date("!%Y-%m-%d") :: string

		-- Refresh cap counters on a new UTC date
		if data.rank.dailyCaps.date ~= today then
			data.rank.dailyCaps.date = today
			data.rank.dailyCaps.marketPoints = 0
			data.rank.dailyCaps.vaultPoints = 0
		end

		if source == "market" then
			effective = math.min(amount, RM.DAILY_MARKET_CAP - data.rank.dailyCaps.marketPoints)
			if effective <= 0 then return end
			data.rank.dailyCaps.marketPoints += effective
		else
			effective = math.min(amount, RM.DAILY_VAULT_CAP - data.rank.dailyCaps.vaultPoints)
			if effective <= 0 then return end
			data.rank.dailyCaps.vaultPoints += effective
		end
	end

	data.rank.currentRun += effective
	data.rank.lifetime += effective

	if _remoteService then
		_remoteService.getEvent("RankUpdate"):FireClient(player, {
			currentRun = data.rank.currentRun,
			lifetime = data.rank.lifetime,
			title = RM.titleForScore(data.rank.currentRun),
		})
	end
end

-- addSprintPoints: accumulate weekly sprint score and write to ODS (fire-and-forget).
-- Only writes to ODS when the new score strictly exceeds the last written value (H6).
function RankService.addSprintPoints(player: any, data: any, amount: number, now: number)
	local SR = _seedResolver
	assert(SR, "RankService: SeedResolver not injected")

	local weekEpoch = SR.getCurrentWeekNumber(now)

	if data.sprintPoints.weekEpoch ~= weekEpoch then
		-- Stale entry from a previous week; reset
		data.sprintPoints = { weekEpoch = weekEpoch, points = 0 }
	end

	data.sprintPoints.points += amount

	local userId = player.UserId
	local newScore = data.sprintPoints.points
	local lastWritten = _lastSprintWrite[userId] or 0

	if newScore <= lastWritten then
		return -- debounce: don't write if value did not increase
	end
	_lastSprintWrite[userId] = newScore

	-- Fire-and-forget ODS write; never yield the caller (H6).
	-- _spawnFn defaults to synchronous for Lune tests; init() overrides with task.spawn.
	_spawnFn(function()
		local ok, err = pcall(function()
			local ods = RankService.getSprintOds(weekEpoch)
			ods:SetAsync(tostring(userId), newScore)
		end)
		if not ok then
			warn("RankService: sprint ODS write failed:", err)
		end
	end)
end

-- ── Higher-level score entry points ────────────────────────────────────────

-- Called by SlotService after a natural reveal.
function RankService.scoreNaturalCompletion(
	player: any,
	data: any,
	compoundId: string,
	now: number
)
	local C = _compounds
	assert(C, "RankService: Compounds not injected")
	local compound = C[compoundId]
	if not compound then return end

	local points = _rankMath.scoreForCompletion(compound.tier)
	if points > 0 then
		RankService.addScore(player, data, points, "synthesis")
		RankService.addSprintPoints(player, data, points, now)
	end
end

-- Called by LabService after a new recipe is discovered.
-- §14 / §11: lab analysis grant is competitively invisible — no rank points awarded.
function RankService.scoreDiscovery(_player: any, _data: any)
	-- Intentional no-op: discovery earns no rank points (doc §14).
	-- Exists so LabService wires cleanly; Phase 7+ can add behavior without touching LabService.
end

-- Called by PatentService after a successful defense.
-- No Sprint points for defense (doc §21 — Sprint tracks synthesis output only).
function RankService.scoreDefense(player: any, data: any, tier: number)
	RankService.addScore(player, data, _rankMath.defenseScore(tier), "defense")
end

-- Called by PatentService after a first-claim. No Sprint points for claims.
function RankService.scoreClaim(player: any, data: any)
	RankService.addScore(player, data, _rankMath.CLAIM_SCORE, "claim")
end

-- Called by MarketService after online seller proceeds are credited. Cap inside addScore.
function RankService.scoreMarketSale(player: any, data: any, proceeds: number)
	RankService.addScore(player, data, _rankMath.marketSaleScore(proceeds), "market")
end

-- Called by SyndicateService (Phase 5) after a vault contribution. Cap inside addScore.
function RankService.scoreVaultContribution(player: any, data: any, pellets: number)
	RankService.addScore(player, data, _rankMath.vaultContributionScore(pellets), "vault")
end

-- Stub: award champion badges from Sprint_{weekEpoch} ODS top-3. Phase 7 implements fully.
function RankService.archiveSprint(_weekEpoch: number)
	warn("RankService.archiveSprint: not yet implemented")
end

-- ── Init ───────────────────────────────────────────────────────────────────

function RankService.init()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	_dataStoreService = game:GetService("DataStoreService")

	_remoteService = require(ServerScriptService.Server.Services.RemoteService)
	_rankMath = require(ReplicatedStorage.Shared.Core.RankMath)
	_seedResolver = require(ReplicatedStorage.Shared.Core.SeedResolver)
	_compounds = require(ReplicatedStorage.Shared.Data.Compounds)
	_chiefOds = _dataStoreService:GetOrderedDataStore("ChiefBoard")
	_spawnFn = task.spawn -- use Roblox's task.spawn in production
	-- Sprint ODS instances created on demand via getSprintOds(weekEpoch)
end

return RankService

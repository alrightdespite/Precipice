-- LeaderboardService: serves LeaderboardRequest C2S. Reads Sprint and ChiefBoard ODS.
-- Does NOT write scores — that is RankService's responsibility.
-- No Roblox globals at module level — Lune-testable via injection helpers.

-- ── Injected / initialized state ───────────────────────────────────────────

local _rankService: any = nil
local _remoteService: any = nil
local _dataService: any = nil
local _seedResolver: any = nil
local _globalJobsDs: any = nil -- DataStore("GlobalJobs") for percentile blob reads
local _clock: (() -> number)? = nil

local CACHE_TTL = 60 -- seconds (H6)

local _cache: { [string]: { entries: { any }, fetchedAt: number } } = {
	sprint = { entries = {}, fetchedAt = 0 },
	chiefs = { entries = {}, fetchedAt = 0 },
}

-- Per-player rate limiting (Manifest: 0.5/s = 1 req per 2 seconds)
local _lastRequestAt: { [number]: number } = {}
local RATE_LIMIT_INTERVAL = 2

local LeaderboardService = {}

-- ── Test injection helpers ─────────────────────────────────────────────────

function LeaderboardService._setRankService(rs: any) _rankService = rs end
function LeaderboardService._setRemoteService(rs: any) _remoteService = rs end
function LeaderboardService._setDataService(ds: any) _dataService = ds end
function LeaderboardService._setSeedResolver(sr: any) _seedResolver = sr end
function LeaderboardService._setGlobalJobsDs(ds: any) _globalJobsDs = ds end
function LeaderboardService._setClock(fn: any) _clock = fn end

function LeaderboardService._resetCache()
	_cache = {
		sprint = { entries = {}, fetchedAt = 0 },
		chiefs = { entries = {}, fetchedAt = 0 },
	}
	_lastRequestAt = {}
end

-- ── Internal helpers ───────────────────────────────────────────────────────

local function nowTime(): number
	return _clock and _clock() or os.time()
end

-- Fetch up to 100 entries from an ODS descending. Returns {} on any error.
local function fetchOdsEntries(ods: any): { any }
	local entries: { any } = {}
	local ok, result = pcall(function()
		local pages = ods:GetSortedAsync(false, 100)
		local page = pages:GetCurrentPage()
		local rank = 1
		for _, entry in ipairs(page) do
			table.insert(entries, {
				rank = rank,
				userId = tonumber(entry.key),
				score = entry.value,
				displayName = nil, -- client resolves display names via UserId
			})
			rank += 1
		end
	end)
	if not ok then
		warn("LeaderboardService: ODS fetch failed:", result)
	end
	return entries
end

-- ── Request handler ────────────────────────────────────────────────────────

local function handleLeaderboardRequest(player: any, board: any)
	if type(board) ~= "string" or (board ~= "sprint" and board ~= "chiefs") then
		return { entries = {}, ownRow = nil }
	end

	local userId = player.UserId
	local now = nowTime()

	-- Server-side rate limit (belt-and-suspenders; Manifest already limits at 0.5/s)
	local lastAt = _lastRequestAt[userId] or 0
	if now - lastAt < RATE_LIMIT_INTERVAL then
		return { entries = {}, ownRow = nil }
	end
	_lastRequestAt[userId] = now

	-- Determine which ODS to read
	local ods: any
	if board == "sprint" then
		local SR = _seedResolver
		assert(SR, "LeaderboardService: SeedResolver not injected")
		local weekEpoch = SR.getCurrentWeekNumber(now)
		ods = _rankService.getSprintOds(weekEpoch)
	else
		ods = _rankService.getChiefBoardOds()
	end

	-- Cache check
	local cacheEntry = _cache[board]
	if cacheEntry.fetchedAt > 0 and now - cacheEntry.fetchedAt < CACHE_TTL then
		-- cache hit — fall through with cached entries
	else
		-- Cache miss: fetch from ODS and update cache
		local fetched = fetchOdsEntries(ods)
		cacheEntry.entries = fetched
		cacheEntry.fetchedAt = now
	end

	local entries = cacheEntry.entries

	-- Own-row resolution (R4)
	local ownRow = nil
	local foundInTop = false

	for _, entry in ipairs(entries) do
		if entry.userId == userId then
			ownRow = entry
			foundInTop = true
			break
		end
	end

	if not foundInTop then
		-- Player not in top-100: build their own row from profile
		local score = 0
		if _dataService then
			local data = _dataService.getProfile(userId)
			if data then
				if board == "sprint" then
					score = data.sprintPoints and data.sprintPoints.points or 0
				else
					score = data.rank and data.rank.lifetime or 0
				end
			end
		end

		-- Attempt percentile blob lookup from GlobalJobs DS (written by hourly job — Phase 7)
		local estimatedRank = -1 -- -1 = unranked / calculating (client interprets)
		if _globalJobsDs then
			local ok, blob = pcall(function()
				return _globalJobsDs:GetAsync("percentile_blob:" .. board)
			end)
			if ok and blob then
				-- Phase 7 will populate this blob; for now rank stays -1
				estimatedRank = -1
			end
		end

		ownRow = { rank = estimatedRank, userId = userId, score = score }
	end

	return { entries = entries, ownRow = ownRow }
end

-- Exposed for Lune tests — same logic as OnServerInvoke handler.
LeaderboardService._handleRequest = handleLeaderboardRequest

-- ── Init ───────────────────────────────────────────────────────────────────

function LeaderboardService.init()
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	_remoteService = require(ServerScriptService.Server.Services.RemoteService)
	_dataService = require(ServerScriptService.Server.Services.DataService)
	_rankService = require(ServerScriptService.Server.Services.RankService)
	_seedResolver = require(ReplicatedStorage.Shared.Core.SeedResolver)
	_globalJobsDs = game:GetService("DataStoreService"):GetDataStore("GlobalJobs")

	_remoteService.getFunction("LeaderboardRequest").OnServerInvoke =
		function(player: any, board: any)
			return handleLeaderboardRequest(player, board)
		end
end

return LeaderboardService

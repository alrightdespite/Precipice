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

	-- Cache check — refresh only on a miss; a hit falls through with cached entries.
	local cacheEntry = _cache[board]
	local cacheHit = cacheEntry.fetchedAt > 0 and now - cacheEntry.fetchedAt < CACHE_TTL
	if not cacheHit then
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

		-- Estimate rank from the hourly percentile blob (§21/E4). -1 = no blob yet (client shows
		-- "calculating"); a positive value is an interpolated estimate within ~top 1000, or the
		-- blob's readCount as a "1000+" lower bound below the captured window.
		local estimatedRank = -1
		if _globalJobsDs then
			local ok, blob = pcall(function()
				return _globalJobsDs:GetAsync("percentile_blob:" .. board)
			end)
			if ok and blob then
				estimatedRank = LeaderboardService._estimateRankFromBlob(blob, score)
			end
		end

		ownRow = { rank = estimatedRank, userId = userId, score = score }
	end

	return { entries = entries, ownRow = ownRow }
end

-- Exposed for Lune tests — same logic as OnServerInvoke handler.
LeaderboardService._handleRequest = handleLeaderboardRequest

-- ── Percentile blob (§21/E4) ─────────────────────────────────────────────────

-- Pure: estimate a player's rank from the blob's rank checkpoints. The blob is
-- { thresholds = { {rank, score}, ... } (ascending rank / descending score), readCount }.
-- Returns an interpolated rank within the captured window, the readCount lower bound below it,
-- or -1 if the blob is empty. Lune-tested.
function LeaderboardService._estimateRankFromBlob(blob: any, score: number): number
	if blob == nil or blob.thresholds == nil or #blob.thresholds == 0 then
		return -1
	end
	local prev: any = nil
	for _, cp in ipairs(blob.thresholds) do
		if score >= cp.score then
			if prev == nil then
				return cp.rank -- beats the top checkpoint
			end
			-- Player's score sits in (cp.score, prev.score]; interpolate rank linearly.
			local denom = math.max(1, prev.score - cp.score)
			local frac = (prev.score - score) / denom
			return math.floor(prev.rank + frac * (cp.rank - prev.rank) + 0.5)
		end
		prev = cp
	end
	-- Below every checkpoint → outside the captured top window.
	return blob.readCount or -1
end

local PERCENTILE_WINDOW = 1000
local PERCENTILE_CHECKPOINT = 50

-- Read up to the top PERCENTILE_WINDOW of a board and write rank-checkpoint thresholds to the
-- GlobalJobs DS. Driven hourly by ClockService through GlobalJobService (singleton). Studio-tested.
function LeaderboardService.computePercentileBlob(now: number?)
	now = now or nowTime()
	local boards = { "sprint", "chiefs" }
	for _, board in ipairs(boards) do
		local ods: any
		if board == "sprint" then
			ods = _rankService.getSprintOds(_seedResolver.getCurrentWeekNumber(now))
		else
			ods = _rankService.getChiefBoardOds()
		end

		local thresholds: { { rank: number, score: number } } = {}
		local readCount = 0
		local ok, err = pcall(function()
			local pages = ods:GetSortedAsync(false, 100)
			local rank = 1
			while true do
				for _, entry in ipairs(pages:GetCurrentPage()) do
					readCount = rank
					if rank == 1 or rank % PERCENTILE_CHECKPOINT == 0 then
						table.insert(thresholds, { rank = rank, score = entry.value })
					end
					rank += 1
				end
				if pages.IsFinished or rank > PERCENTILE_WINDOW then
					break
				end
				pages:AdvanceToNextPageAsync()
			end
		end)
		if not ok then
			warn("LeaderboardService: percentile read failed for", board, "—", err)
			continue
		end

		local blob = { thresholds = thresholds, readCount = readCount, computedAt = now }
		local wok, werr = pcall(function()
			_globalJobsDs:SetAsync("percentile_blob:" .. board, blob)
		end)
		if not wok then
			warn("LeaderboardService: percentile blob write failed for", board, "—", werr)
		end
	end
end

-- ── Init ───────────────────────────────────────────────────────────────────

function LeaderboardService.init()
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	_remoteService = require(ServerScriptService.Server.Services.RemoteService)
	_dataService = require(ServerScriptService.Server.Services.DataService)
	_rankService = require(ServerScriptService.Server.Services.RankService)
	_seedResolver = require(ReplicatedStorage.Shared.Core.SeedResolver)
	_globalJobsDs = game:GetService("DataStoreService"):GetDataStore("GlobalJobs")

	-- The client expects two return values (entries, ownRow) per the Manifest; the internal
	-- handler returns a { entries, ownRow } table (asserted by Lune tests), so unpack it here.
	_remoteService.setInvoke("LeaderboardRequest",
		function(player: any, board: any)
			local result = handleLeaderboardRequest(player, board)
			return result.entries, result.ownRow
		end)
end

return LeaderboardService

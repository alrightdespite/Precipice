-- LeaderboardService tests.
-- Uses injection — no Roblox globals.

local spec = require("../spec")
local SeedResolver = require("../../src/shared/Core/SeedResolver")
local LeaderboardService = require("../../src/server/Services/LeaderboardService")

-- Fake ODS: returns a fixed sorted list (descending order pre-sorted)
local function makeFakeOds(entries: { { key: string, value: number } }): any
	return {
		GetSortedAsync = function(_self, _descending: boolean, _pageSize: number)
			return {
				GetCurrentPage = function(_page)
					return entries
				end,
				IsFinished = true,
			}
		end,
	}
end

-- Fixed sorted entries: userId 10 scored 5000, userId 20 scored 3000, userId 30 scored 1000
local SPRINT_ENTRIES = {
	{ key = "10", value = 5000 },
	{ key = "20", value = 3000 },
	{ key = "30", value = 1000 },
}

local CHIEF_ENTRIES = {
	{ key = "10", value = 120000 },
	{ key = "20", value = 40000 },
}

local fakeSprintOds = makeFakeOds(SPRINT_ENTRIES)
local fakeChiefOds = makeFakeOds(CHIEF_ENTRIES)

local mockRankService = {
	getSprintOds = function(_weekEpoch: number)
		return fakeSprintOds
	end,
	getChiefBoardOds = function()
		return fakeChiefOds
	end,
}

-- Fixed clock so cache TTL tests are deterministic
local fakeNow = 1749859200

local mockDataService = {
	getProfile = function(_userId: number): any
		return {
			sprintPoints = { weekEpoch = 0, points = 42 },
			rank = { currentRun = 0, lifetime = 99 },
		}
	end,
}

LeaderboardService._setRankService(mockRankService)
LeaderboardService._setSeedResolver(SeedResolver)
LeaderboardService._setDataService(mockDataService)
LeaderboardService._setGlobalJobsDs(nil) -- no percentile blob in tests
LeaderboardService._setClock(function() return fakeNow end)

local function mockPlayer(userId: number): any
	return { UserId = userId }
end

-- Reset between each test group
local function reset()
	LeaderboardService._resetCache()
	fakeNow = 1749859200
end

-- ── Test 1: sprint board returns sorted entries ────────────────────────────

spec.describe("LeaderboardService — sprint board returns sorted entries", function()
	spec.it("entries descending, rank 1 = highest score", function()
		reset()
		local result = LeaderboardService._handleRequest(mockPlayer(999), "sprint")
		spec.expect(#result.entries).toBe(3)
		spec.expect(result.entries[1].rank).toBe(1)
		spec.expect(result.entries[1].score).toBe(5000)
		spec.expect(result.entries[2].rank).toBe(2)
		spec.expect(result.entries[2].score).toBe(3000)
		spec.expect(result.entries[3].rank).toBe(3)
		spec.expect(result.entries[3].score).toBe(1000)
	end)
end)

-- ── Test 2: chiefs board returns sorted entries ────────────────────────────

spec.describe("LeaderboardService — chiefs board returns sorted entries", function()
	spec.it("entries descending by lifetime rank", function()
		reset()
		local result = LeaderboardService._handleRequest(mockPlayer(999), "chiefs")
		spec.expect(#result.entries).toBe(2)
		spec.expect(result.entries[1].score).toBe(120000)
		spec.expect(result.entries[2].score).toBe(40000)
	end)
end)

-- ── Test 3: own-row in top entries ────────────────────────────────────────

spec.describe("LeaderboardService — own-row found in top entries", function()
	spec.it("ownRow.rank == 2 for userId 20 on sprint board", function()
		reset()
		local result = LeaderboardService._handleRequest(mockPlayer(20), "sprint")
		spec.expect(result.ownRow ~= nil).toBeTrue()
		spec.expect(result.ownRow.rank).toBe(2)
		spec.expect(result.ownRow.score).toBe(3000)
		spec.expect(result.ownRow.userId).toBe(20)
	end)
end)

-- ── Test 4: own-row outside top entries, no percentile blob → rank = -1 ───

spec.describe("LeaderboardService — own-row not in top, no blob → rank = -1", function()
	spec.it("ownRow.rank == -1 when userId not in top entries", function()
		reset()
		local result = LeaderboardService._handleRequest(mockPlayer(999), "sprint")
		spec.expect(result.ownRow ~= nil).toBeTrue()
		spec.expect(result.ownRow.rank).toBe(-1)
		spec.expect(result.ownRow.userId).toBe(999)
		-- Score from mock profile: sprintPoints.points = 42
		spec.expect(result.ownRow.score).toBe(42)
	end)
end)

-- ── Test 5: cache hit within 60s reuses entries ───────────────────────────

spec.describe("LeaderboardService — cache hit within TTL", function()
	spec.it("second request within 60s returns same data without re-read", function()
		reset()

		-- Replace sprint ODS with a counter to detect re-reads
		local readCount = 0
		local countingOds = {
			GetSortedAsync = function(_self, _d, _ps)
				readCount += 1
				return {
					GetCurrentPage = function(_) return SPRINT_ENTRIES end,
				}
			end,
		}
		local countingRankService = {
			getSprintOds = function(_) return countingOds end,
			getChiefBoardOds = function() return fakeChiefOds end,
		}
		LeaderboardService._setRankService(countingRankService)
		LeaderboardService._resetCache()

		-- First request — populates cache
		LeaderboardService._handleRequest(mockPlayer(999), "sprint")
		spec.expect(readCount).toBe(1)

		-- Second request 30s later — cache still hot
		fakeNow += 30
		LeaderboardService._handleRequest(mockPlayer(999), "sprint")
		spec.expect(readCount).toBe(1) -- no additional ODS read

		-- Restore
		LeaderboardService._setRankService(mockRankService)
	end)
end)

-- ── Test 6: cache miss after 61s triggers re-read ─────────────────────────

spec.describe("LeaderboardService — cache miss after TTL", function()
	spec.it("request after 61s re-reads ODS", function()
		reset()

		local readCount = 0
		local countingOds = {
			GetSortedAsync = function(_self, _d, _ps)
				readCount += 1
				return {
					GetCurrentPage = function(_) return SPRINT_ENTRIES end,
				}
			end,
		}
		local countingRankService = {
			getSprintOds = function(_) return countingOds end,
			getChiefBoardOds = function() return fakeChiefOds end,
		}
		LeaderboardService._setRankService(countingRankService)
		LeaderboardService._resetCache()

		LeaderboardService._handleRequest(mockPlayer(999), "sprint")
		spec.expect(readCount).toBe(1)

		-- Advance clock past TTL
		fakeNow += 61
		LeaderboardService._handleRequest(mockPlayer(999), "sprint")
		spec.expect(readCount).toBe(2)

		-- Restore
		LeaderboardService._setRankService(mockRankService)
	end)
end)

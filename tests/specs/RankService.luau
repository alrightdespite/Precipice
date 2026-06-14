-- RankService tests.
-- Uses injection — no DataService, no real ODS, no Roblox globals.

local spec = require("../spec")
local RankMath = require("../../src/shared/Core/RankMath")
local SeedResolver = require("../../src/shared/Core/SeedResolver")
local Compounds = require("../../src/shared/Data/Compounds")
local RankService = require("../../src/server/Services/RankService")

-- Inject pure modules
RankService._setRankMath(RankMath)
RankService._setSeedResolver(SeedResolver)
RankService._setCompounds(Compounds)

-- Null remote service — fires silently
local lastRankUpdate: any = nil
local mockRemoteService = {
	getEvent = function(_self, _name)
		return {
			FireClient = function(_event, _player, payload)
				lastRankUpdate = payload
			end,
		}
	end,
}
RankService._setRemoteService(mockRemoteService)

local mockPlayer = { UserId = 9001, Name = "TestPlayer" }

-- Fixed week epoch for sprint tests (SeedResolver.getCurrentWeekNumber is pure)
-- 2026-06-14 00:00:00 UTC = 1749859200
local NOW_WEEK = 1749859200

-- A week later: approx 2026-06-21
local NOW_NEXT_WEEK = NOW_WEEK + 7 * 86400

local function makeData(): any
	return {
		rank = {
			currentRun = 0,
			lifetime = 0,
			dailyCaps = { date = "", marketPoints = 0, vaultPoints = 0 },
		},
		sprintPoints = { weekEpoch = 0, points = 0 },
	}
end

local function makeOdsMock(): ({ writes: { { key: string, score: number } }, ods: any })
	local writes: { { key: string, score: number } } = {}
	local ods = {
		SetAsync = function(_self, key: string, score: number)
			table.insert(writes, { key = key, score = score })
		end,
	}
	return { writes = writes, ods = ods }
end

local function setupSprintMock(factory: (number) -> any)
	RankService._setSprintOdsFactory(factory)
	RankService._resetSprintWriteCache()
end

-- ── Test 1: T2 natural completion → +3 rank, +3 sprint ────────────────────

spec.describe("RankService — T2 natural completion", function()
	spec.it("currentRun += 3, lifetime += 3, sprintPoints += 3", function()
		local mock = makeOdsMock()
		setupSprintMock(function(_) return mock.ods end)

		local data = makeData()
		local week = SeedResolver.getCurrentWeekNumber(NOW_WEEK)
		data.sprintPoints = { weekEpoch = week, points = 0 }

		-- Find a T2 compound
		local t2id: string? = nil
		for id, c in pairs(Compounds) do
			if c.tier == 2 then
				t2id = id
				break
			end
		end
		assert(t2id, "No T2 compound found in data")

		RankService.scoreNaturalCompletion(mockPlayer, data, t2id :: string, NOW_WEEK)

		spec.expect(data.rank.currentRun).toBe(3)
		spec.expect(data.rank.lifetime).toBe(3)
		spec.expect(data.sprintPoints.points).toBe(3)
	end)
end)

-- ── Test 2: T1 (extraction) → no rank, no sprint ──────────────────────────

spec.describe("RankService — T1 (extraction) scoreNaturalCompletion", function()
	spec.it("no rank or sprint awarded (T1 earns 0)", function()
		local mock = makeOdsMock()
		setupSprintMock(function(_) return mock.ods end)

		local data = makeData()

		local t1id: string? = nil
		for id, c in pairs(Compounds) do
			if c.tier == 1 then
				t1id = id
				break
			end
		end
		assert(t1id, "No T1 compound found in data")

		RankService.scoreNaturalCompletion(mockPlayer, data, t1id :: string, NOW_WEEK)

		spec.expect(data.rank.currentRun).toBe(0)
		spec.expect(data.rank.lifetime).toBe(0)
		spec.expect(data.sprintPoints.points).toBe(0)
		spec.expect(#mock.writes).toBe(0)
	end)
end)

-- ── Test 3: T6 natural completion → +1150 rank, +1150 sprint ─────────────

spec.describe("RankService — T6 natural completion", function()
	spec.it("currentRun += 1150, sprintPoints += 1150", function()
		local mock = makeOdsMock()
		setupSprintMock(function(_) return mock.ods end)

		local data = makeData()

		local t6id: string? = nil
		for id, c in pairs(Compounds) do
			if c.tier == 6 then
				t6id = id
				break
			end
		end
		assert(t6id, "No T6 compound found in data")

		RankService.scoreNaturalCompletion(mockPlayer, data, t6id :: string, NOW_WEEK)

		spec.expect(data.rank.currentRun).toBe(1150)
		spec.expect(data.rank.lifetime).toBe(1150)
		spec.expect(data.sprintPoints.points).toBe(1150)
	end)
end)

-- ── Test 4: market daily cap ───────────────────────────────────────────────

spec.describe("RankService — market sale daily cap (1000)", function()
	spec.it("first 900 awarded; second 200 capped to 100; third 50 yields 0", function()
		local data = makeData()

		-- Force today's date into caps so cap refresh doesn't interfere
		local today = os.date("!%Y-%m-%d") :: string
		data.rank.dailyCaps.date = today

		RankService.addScore(mockPlayer, data, 900, "market")
		spec.expect(data.rank.currentRun).toBe(900)
		spec.expect(data.rank.dailyCaps.marketPoints).toBe(900)

		RankService.addScore(mockPlayer, data, 200, "market") -- cap is 1000; 200 remaining
		spec.expect(data.rank.currentRun).toBe(1000)
		spec.expect(data.rank.dailyCaps.marketPoints).toBe(1000)

		-- Fully capped — no additional points
		RankService.addScore(mockPlayer, data, 50, "market")
		spec.expect(data.rank.currentRun).toBe(1000)
	end)
end)

-- ── Test 5: market cap resets on new UTC date ──────────────────────────────

spec.describe("RankService — market cap resets on new UTC date", function()
	spec.it("stale date triggers reset; points awarded fresh", function()
		local data = makeData()

		-- Saturate cap with a past date
		data.rank.dailyCaps.date = "2000-01-01"
		data.rank.dailyCaps.marketPoints = 1000

		-- addScore should detect stale date and reset
		RankService.addScore(mockPlayer, data, 500, "market")
		spec.expect(data.rank.currentRun).toBe(500)
		spec.expect(data.rank.dailyCaps.marketPoints).toBe(500)
	end)
end)

-- ── Test 6: vault contribution daily cap (500) ─────────────────────────────

spec.describe("RankService — vault contribution daily cap (500)", function()
	spec.it("first 400 awarded; second 200 capped to 100; third attempt gives 0", function()
		local data = makeData()
		local today = os.date("!%Y-%m-%d") :: string
		data.rank.dailyCaps.date = today

		RankService.addScore(mockPlayer, data, 400, "vault")
		spec.expect(data.rank.currentRun).toBe(400)

		RankService.addScore(mockPlayer, data, 200, "vault")
		spec.expect(data.rank.currentRun).toBe(500)

		RankService.addScore(mockPlayer, data, 100, "vault")
		spec.expect(data.rank.currentRun).toBe(500) -- no change
	end)
end)

-- ── Test 7: scoreDiscovery → no-op (§14) ─────────────────────────────────

spec.describe("RankService — scoreDiscovery is a no-op (§14)", function()
	spec.it("currentRun and lifetime unchanged", function()
		local data = makeData()
		data.rank.currentRun = 100
		data.rank.lifetime = 100

		RankService.scoreDiscovery(mockPlayer, data)

		spec.expect(data.rank.currentRun).toBe(100)
		spec.expect(data.rank.lifetime).toBe(100)
	end)
end)

-- ── Test 8: scoreClaim → +500, no sprint ─────────────────────────────────

spec.describe("RankService — scoreClaim awards CLAIM_SCORE, no sprint", function()
	spec.it("currentRun += 500, lifetime += 500", function()
		local mock = makeOdsMock()
		setupSprintMock(function(_) return mock.ods end)

		local data = makeData()
		local week = SeedResolver.getCurrentWeekNumber(NOW_WEEK)
		data.sprintPoints = { weekEpoch = week, points = 0 }

		RankService.scoreClaim(mockPlayer, data)

		spec.expect(data.rank.currentRun).toBe(500)
		spec.expect(data.rank.lifetime).toBe(500)
		-- No sprint write expected
		spec.expect(#mock.writes).toBe(0)
	end)
end)

-- ── Test 9: scoreDefense T4 → +100, no sprint ────────────────────────────

spec.describe("RankService — scoreDefense T4 awards 100, no sprint", function()
	spec.it("currentRun += 100", function()
		local mock = makeOdsMock()
		setupSprintMock(function(_) return mock.ods end)

		local data = makeData()

		RankService.scoreDefense(mockPlayer, data, 4)

		spec.expect(data.rank.currentRun).toBe(100)
		spec.expect(data.rank.lifetime).toBe(100)
		spec.expect(#mock.writes).toBe(0)
	end)
end)

-- ── Test 10: RankUpdate fires with correct title ──────────────────────────

spec.describe("RankService — RankUpdate S2C fires correct title on threshold cross", function()
	spec.it("2999 points + 1 → title becomes 'Researcher'", function()
		local data = makeData()
		data.rank.currentRun = 2999
		data.rank.lifetime = 2999

		lastRankUpdate = nil
		RankService.addScore(mockPlayer, data, 1, "synthesis")

		spec.expect(data.rank.currentRun).toBe(3000)
		spec.expect(lastRankUpdate ~= nil).toBeTrue()
		spec.expect(lastRankUpdate.title).toBe("Researcher")
	end)
end)

-- ── Test 11: sprint epoch rollover resets points ──────────────────────────

spec.describe("RankService — sprint epoch rollover resets points", function()
	spec.it("adding in week A then week B: only week B points remain", function()
		local mock = makeOdsMock()
		setupSprintMock(function(_) return mock.ods end)

		local data = makeData()
		local weekA = SeedResolver.getCurrentWeekNumber(NOW_WEEK)
		local weekB = SeedResolver.getCurrentWeekNumber(NOW_NEXT_WEEK)
		assert(weekA ~= weekB, "weeks must differ for this test")

		data.sprintPoints = { weekEpoch = weekA, points = 0 }

		-- Week A: add 100 points
		RankService.addSprintPoints(mockPlayer, data, 100, NOW_WEEK)
		spec.expect(data.sprintPoints.points).toBe(100)
		spec.expect(data.sprintPoints.weekEpoch).toBe(weekA)

		-- Week B: epoch changed → reset, then add 50 points
		RankService.addSprintPoints(mockPlayer, data, 50, NOW_NEXT_WEEK)
		spec.expect(data.sprintPoints.weekEpoch).toBe(weekB)
		spec.expect(data.sprintPoints.points).toBe(50)
	end)
end)

-- ── Test 12: sprint ODS write debounced when value does not increase ───────

spec.describe("RankService — sprint ODS write skipped when score does not increase", function()
	spec.it("second call with amount=0 produces no additional ODS write", function()
		local mock = makeOdsMock()
		setupSprintMock(function(_) return mock.ods end)

		local data = makeData()
		local week = SeedResolver.getCurrentWeekNumber(NOW_WEEK)
		data.sprintPoints = { weekEpoch = week, points = 0 }

		-- First call: points 0 → 100, write happens
		RankService.addSprintPoints(mockPlayer, data, 100, NOW_WEEK)
		spec.expect(#mock.writes).toBe(1)
		spec.expect(mock.writes[1].score).toBe(100)

		-- Second call: amount = 0, points stay 100, not > last write (100) → no write
		RankService.addSprintPoints(mockPlayer, data, 0, NOW_WEEK)
		spec.expect(#mock.writes).toBe(1) -- still just 1
	end)
end)

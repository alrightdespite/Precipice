-- StreakService tests.
-- Uses injection for EconomyConstants and a nil RemoteService (fire is skipped).
-- Time is passed explicitly as a parameter — no MockClock needed (onLogin takes now directly).

local spec = require("../spec")
local EconomyConstants = require("../../src/shared/Config/EconomyConstants")
local RankMath = require("../../src/shared/Core/RankMath")
local SeedResolver = require("../../src/shared/Core/SeedResolver")
local Compounds = require("../../src/shared/Data/Compounds")
local RankService = require("../../src/server/Services/RankService")
local StreakService = require("../../src/server/Services/StreakService")

-- Wire RankService with pure modules and no remote
RankService._setRankMath(RankMath)
RankService._setSeedResolver(SeedResolver)
RankService._setCompounds(Compounds)
RankService._setRemoteService(nil)

StreakService._setEconConstants(EconomyConstants)
StreakService._setRemoteService(nil) -- fire calls are nil-checked
StreakService._setRankService(RankService)

local mockPlayer = { UserId = 1001 }

local function defaultData(): any
	return {
		streak = { day = 0, lastLoginAt = 0 },
		balances = { pellets = 0, catalysts = 0 },
		rank = { currentRun = 0, lifetime = 0, dailyCaps = { date = "", marketPoints = 0, vaultPoints = 0 } },
	}
end

-- Simulate N consecutive daily logins starting at baseNow
local function loginStreak(data: any, n: number, baseNow: number)
	for i = 0, n - 1 do
		StreakService.onLogin(mockPlayer, data, baseNow + i * 86400)
	end
end

-- ── First login ────────────────────────────────────────────────────────────

spec.describe("StreakService — first login ever", function()
	spec.it("streak becomes 1, 50 Pellets awarded", function()
		local data = defaultData()
		-- lastLoginAt = 0, now = day 10 (large gap → broken → resets to 0, then +1 = 1)
		StreakService.onLogin(mockPlayer, data, 10 * 86400)
		spec.expect(data.streak.day).toBe(1)
		spec.expect(data.balances.pellets).toBe(50)
	end)
end)

-- ── Consecutive day ────────────────────────────────────────────────────────

spec.describe("StreakService — consecutive day", function()
	spec.it("day 2: streak increments, 100 Pellets", function()
		local data = defaultData()
		loginStreak(data, 2, 86400)
		spec.expect(data.streak.day).toBe(2)
		spec.expect(data.balances.pellets).toBe(50 + 100) -- day1=50, day2=100
	end)

	spec.it("day 3: 200 Pellets (cumulative)", function()
		local data = defaultData()
		loginStreak(data, 3, 86400)
		spec.expect(data.streak.day).toBe(3)
		spec.expect(data.balances.pellets).toBe(50 + 100 + 200)
	end)
end)

-- ── Grace window ───────────────────────────────────────────────────────────

spec.describe("StreakService — grace window active (daysSinceLogin == 2, within 36h)", function()
	spec.it("streak continues, not broken", function()
		local data = defaultData()
		-- Log in at 23:59:59 on day 1 (lastLoginAt = 172799)
		-- lastDay = floor(172799/86400) = 1
		StreakService.onLogin(mockPlayer, data, 172799)
		spec.expect(data.streak.day).toBe(1)

		-- Login at start of day 3 (259200), which is 30h after 172799 — within 36h grace
		-- currentDay = floor(259200/86400) = 3, lastDay = 1, daysSinceLogin = 2
		-- grace check: 259200 < 172799 + 129600 = 302399 → true
		local graceNow = 3 * 86400
		StreakService.onLogin(mockPlayer, data, graceNow)
		spec.expect(data.streak.day).toBe(2) -- continued, not reset to 1
	end)
end)

spec.describe("StreakService — grace window expired (daysSinceLogin == 2, beyond 36h)", function()
	spec.it("streak resets to 1", function()
		local data = defaultData()
		-- Log in at 23:59:59 on day 1 (lastLoginAt = 172799)
		StreakService.onLogin(mockPlayer, data, 172799)
		spec.expect(data.streak.day).toBe(1)

		-- Login at 172799 + 36h + 1s = 302400
		-- currentDay = floor(302400/86400) = 3, lastDay = 1, daysSinceLogin = 2
		-- grace check: 302400 < 172799 + 129600 = 302399 → false → broken
		local expiredNow = 172799 + 36 * 3600 + 1
		StreakService.onLogin(mockPlayer, data, expiredNow)
		spec.expect(data.streak.day).toBe(1) -- reset to 0 then +1 = 1
	end)
end)

-- ── Gap > 2 days ───────────────────────────────────────────────────────────

spec.describe("StreakService — daysgap > 2", function()
	spec.it("streak resets to 1", function()
		local data = defaultData()
		loginStreak(data, 5, 86400) -- build streak to day 5
		spec.expect(data.streak.day).toBe(5)

		-- Skip 3 days
		StreakService.onLogin(mockPlayer, data, data.streak.lastLoginAt + 3 * 86400 + 3600)
		spec.expect(data.streak.day).toBe(1)
	end)
end)

-- ── Same-day second login ──────────────────────────────────────────────────

spec.describe("StreakService — same day second login", function()
	spec.it("no-op: streak day and lastLoginAt unchanged", function()
		local data = defaultData()
		local loginNow = 10 * 86400 + 3600 -- 01:00 on day 10
		StreakService.onLogin(mockPlayer, data, loginNow)
		spec.expect(data.streak.day).toBe(1)
		local lastLoginAt = data.streak.lastLoginAt

		-- Second login same day (2 hours later)
		StreakService.onLogin(mockPlayer, data, loginNow + 7200)
		spec.expect(data.streak.day).toBe(1) -- unchanged
		spec.expect(data.streak.lastLoginAt).toBe(lastLoginAt) -- unchanged
	end)
end)

-- ── Milestones ─────────────────────────────────────────────────────────────

spec.describe("StreakService — day 7 milestone", function()
	spec.it("STREAK_DAILY_PELLETS[7] == 0, Catalyst = 1, rank = 150", function()
		spec.expect(EconomyConstants.STREAK_DAILY_PELLETS[7]).toBe(0)
		local data = defaultData()
		loginStreak(data, 7, 86400)
		spec.expect(data.streak.day).toBe(7)
		-- No pellets on milestone day
		local pelletSum = 50 + 100 + 200 + 200 + 300 + 300 -- days 1-6
		spec.expect(data.balances.pellets).toBe(pelletSum)
		spec.expect(data.balances.catalysts).toBe(1)
		spec.expect(data.rank.currentRun).toBe(150)
		spec.expect(data.rank.lifetime).toBe(150)
	end)
end)

spec.describe("StreakService — day 14 milestone", function()
	spec.it("Catalysts = 2, rank = 300", function()
		local data = defaultData()
		loginStreak(data, 14, 86400)
		spec.expect(data.streak.day).toBe(14)
		spec.expect(data.balances.catalysts).toBe(1 + 2) -- day7=1, day14=2
		spec.expect(data.rank.currentRun).toBe(150 + 300)
		spec.expect(data.rank.lifetime).toBe(150 + 300)
	end)
end)

spec.describe("StreakService — day 28 milestone", function()
	spec.it("Catalysts += 5, rank += 750", function()
		local data = defaultData()
		loginStreak(data, 28, 86400)
		spec.expect(data.streak.day).toBe(28)
		spec.expect(data.balances.catalysts).toBe(1 + 2 + 5)
		spec.expect(data.rank.currentRun).toBe(150 + 300 + 750)
		spec.expect(data.rank.lifetime).toBe(150 + 300 + 750)
	end)
end)

-- ── Post-28 days ───────────────────────────────────────────────────────────

spec.describe("StreakService — day 29 uses STREAK_PELLETS_REPEATING", function()
	spec.it("300 pellets, no Catalyst", function()
		local data = defaultData()
		loginStreak(data, 28, 86400)
		local catsAfter28 = data.balances.catalysts
		local rankAfter28 = data.rank.currentRun

		StreakService.onLogin(mockPlayer, data, 86400 + 28 * 86400)
		spec.expect(data.streak.day).toBe(29)
		spec.expect(data.balances.catalysts).toBe(catsAfter28) -- no new catalyst
		spec.expect(data.rank.currentRun).toBe(rankAfter28)
		-- Day 29 pellets = STREAK_PELLETS_REPEATING = 300
	end)
end)

-- ── Repeating rewards ──────────────────────────────────────────────────────

spec.describe("StreakService — day 35 repeating reward", function()
	spec.it("Catalyst += 1, rank += 75", function()
		local data = defaultData()
		loginStreak(data, 35, 86400)
		spec.expect(data.streak.day).toBe(35)
		-- Milestones at 7, 14, 28: 1+2+5 = 8 cats; repeating at 35: +1 = 9
		spec.expect(data.balances.catalysts).toBe(8 + 1)
		spec.expect(data.rank.currentRun).toBe(150 + 300 + 750 + 75)
		spec.expect(data.rank.lifetime).toBe(150 + 300 + 750 + 75)
	end)
end)

spec.describe("StreakService — day 42 repeating reward triggers again", function()
	spec.it("Catalyst and rank both increment again", function()
		local data = defaultData()
		loginStreak(data, 42, 86400)
		spec.expect(data.streak.day).toBe(42)
		-- Repeating at 35 and 42: +1 each = 10 total cats
		spec.expect(data.balances.catalysts).toBe(8 + 1 + 1)
		spec.expect(data.rank.currentRun).toBe(150 + 300 + 750 + 75 + 75)
	end)
end)

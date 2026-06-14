-- PrestigeService tests.
-- Injection pattern — no Roblox globals, no DataStore.

local spec = require("../spec")
local EconomyConstants = require("../../src/shared/Config/EconomyConstants")
local ProfileTemplate = require("../../src/shared/Core/ProfileTemplate")
local PrestigeService = require("../../src/server/Services/PrestigeService")

local describe, it, expect = spec.describe, spec.it, spec.expect

-- ── Constants ──────────────────────────────────────────────────────────────

local P1_COST = EconomyConstants.PRESTIGE_COSTS[1] -- 500000
local RANK_GATE = 250000
local NOW = 1749859200 -- 2026-06-14 UTC

-- ── Mock player ────────────────────────────────────────────────────────────

local mockPlayer = { UserId = 1, Name = "TestPlayer" }

-- ── Default data builder ───────────────────────────────────────────────────

local function defaultData(): any
	return {
		schemaVersion = 2,
		balances = { pellets = P1_COST, catalysts = 0 },
		vault = { compounds = { ["T2_01"] = 3 }, residue = 5 },
		formulaLog = {
			discovered = { ["T2_01"] = true },
			validatedPairs = {},
			failedPairs = {},
		},
		slots = {},
		lastSeenAt = 0,
		rank = {
			currentRun = RANK_GATE,
			lifetime = 12345,
			dailyCaps = { date = "", marketPoints = 0, vaultPoints = 0 },
		},
		sprintPoints = { weekEpoch = 0, points = 999 },
		streak = { day = 5, lastLoginAt = NOW - 86400 },
		contracts = { dayKey = "2026-06-14", slots = { { templateId = "e1", progress = 2, target = 5, completed = false, claimed = false } } },
		prestige = { level = 0, jointQualLifetime = false },
		monetization = { gamepasses = {}, rushUses = 0, archiveUsesByMonth = {}, receiptLedger = {} },
		cosmetics = { owned = {}, equipped = {} },
		eventState = { fluxBySeason = {}, blueprintsOwned = {} },
		pendingCreditsApplied = {},
		syndicate = nil,
	}
end

-- ── Setup helper ───────────────────────────────────────────────────────────

local function setup()
	PrestigeService._setEconomyConstants(EconomyConstants)
	PrestigeService._setProfileTemplate(ProfileTemplate)
end

setup()

-- ── Blocker tests ──────────────────────────────────────────────────────────

describe("PrestigeService — blocker: rank below 250000", function()
	it("returns a string containing 'Chief Scientist'", function()
		local data = defaultData()
		data.rank.currentRun = 249999
		local blockers = PrestigeService.getBlockers(data)
		expect(#blockers > 0).toBeTrue()
		local found = false
		for _, b in ipairs(blockers) do
			if b:find("Chief Scientist") then found = true end
		end
		expect(found).toBeTrue()
	end)
end)

describe("PrestigeService — blocker: rank exactly 250000, pellets sufficient", function()
	it("returns empty blockers", function()
		local data = defaultData()
		local blockers = PrestigeService.getBlockers(data)
		expect(#blockers).toBe(0)
	end)
end)

describe("PrestigeService — blocker: pellets below P1 cost", function()
	it("returns a string containing 'Pellets'", function()
		local data = defaultData()
		data.balances.pellets = P1_COST - 1
		local blockers = PrestigeService.getBlockers(data)
		expect(#blockers > 0).toBeTrue()
		local found = false
		for _, b in ipairs(blockers) do
			if b:find("Pellets") then found = true end
		end
		expect(found).toBeTrue()
	end)
end)

describe("PrestigeService — blocker: running slot", function()
	it("returns a string about 'running'", function()
		local data = defaultData()
		data.slots = {
			{ index = 1, kind = "synthesis", compoundId = "T2_01", workRemaining = 300, lastTickAt = NOW, mode = "online", isStabilized = false, isNatural = true, startedAt = NOW },
		}
		local blockers = PrestigeService.getBlockers(data)
		local found = false
		for _, b in ipairs(blockers) do
			if b:find("running") then found = true end
		end
		expect(found).toBeTrue()
	end)
end)

describe("PrestigeService — blocker: complete (unrevealed) slot", function()
	it("returns a string about 'unrevealed'", function()
		local data = defaultData()
		data.slots = {
			{ index = 1, kind = "synthesis", compoundId = "T2_01", workRemaining = 0, lastTickAt = NOW, mode = "online", isStabilized = false, isNatural = true, startedAt = NOW },
		}
		local blockers = PrestigeService.getBlockers(data)
		local found = false
		for _, b in ipairs(blockers) do
			if b:find("unrevealed") then found = true end
		end
		expect(found).toBeTrue()
	end)
end)

describe("PrestigeService — multiple blockers", function()
	it("all returned in the list", function()
		local data = defaultData()
		data.rank.currentRun = 0
		data.balances.pellets = 0
		data.slots = {
			{ index = 1, kind = "synthesis", compoundId = "T2_01", workRemaining = 100, lastTickAt = NOW, mode = "online", isStabilized = false, isNatural = true, startedAt = NOW },
		}
		local blockers = PrestigeService.getBlockers(data)
		expect(#blockers >= 3).toBeTrue()
	end)
end)

-- ── preReset tests ─────────────────────────────────────────────────────────

describe("PrestigeService — preReset: cancelAllForUser called", function()
	it("MarketService.cancelAllForUser call count = 1", function()
		local data = defaultData()
		local callCount = 0
		local mockMarket = {
			cancelAllForUser = function(_player)
				callCount += 1
				return 0
			end,
		}
		local mockDs = {
			drainPending = function(_userId, _data) end,
		}
		PrestigeService._setMarketService(mockMarket)
		PrestigeService._setDataService(mockDs)

		PrestigeService.preReset(mockPlayer, data)

		expect(callCount).toBe(1)

		-- Reset injected deps
		PrestigeService._setMarketService(nil)
		PrestigeService._setDataService(nil)
	end)
end)

describe("PrestigeService — preReset: drainPending called", function()
	it("DataService.drainPending call count = 1", function()
		local data = defaultData()
		local callCount = 0
		local mockMarket = { cancelAllForUser = function(_p) return 0 end }
		local mockDs = {
			drainPending = function(_userId, _data)
				callCount += 1
			end,
		}
		PrestigeService._setMarketService(mockMarket)
		PrestigeService._setDataService(mockDs)

		PrestigeService.preReset(mockPlayer, data)

		expect(callCount).toBe(1)

		PrestigeService._setMarketService(nil)
		PrestigeService._setDataService(nil)
	end)
end)

-- ── executeReset tests ─────────────────────────────────────────────────────

local function runReset(data: any): any
	local chiefWrites: { { key: string, score: number } } = {}
	local mockOds = {
		SetAsync = function(_self, key, score)
			table.insert(chiefWrites, { key = key, score = score })
		end,
	}
	local mockRank = {
		writeChiefBoardScore = function(player, d)
			mockOds:SetAsync(tostring(player.UserId), d.rank.lifetime)
		end,
	}
	PrestigeService._setRankService(mockRank)
	PrestigeService.executeReset(mockPlayer, data, NOW)
	PrestigeService._setRankService(nil)
	return chiefWrites
end

describe("PrestigeService — executeReset: vault.compounds wiped", function()
	it("vault.compounds = {}", function()
		local data = defaultData()
		runReset(data)
		expect(next(data.vault.compounds) == nil).toBeTrue()
	end)
end)

describe("PrestigeService — executeReset: vault.residue wiped", function()
	it("vault.residue = 0", function()
		local data = defaultData()
		runReset(data)
		expect(data.vault.residue).toBe(0)
	end)
end)

describe("PrestigeService — executeReset: balances.pellets = 500", function()
	it("pellets set to 500 post-prestige floor", function()
		local data = defaultData()
		runReset(data)
		expect(data.balances.pellets).toBe(500)
	end)
end)

describe("PrestigeService — executeReset: balances.catalysts preserved", function()
	it("catalysts not touched", function()
		local data = defaultData()
		data.balances.catalysts = 7
		runReset(data)
		expect(data.balances.catalysts).toBe(7)
	end)
end)

describe("PrestigeService — executeReset: slots wiped", function()
	it("slots = {}", function()
		local data = defaultData()
		data.slots = {
			{ index = 1, kind = "synthesis", compoundId = "T2_01", workRemaining = 0, lastTickAt = NOW, mode = "online", isStabilized = false, isNatural = true, startedAt = NOW },
		}
		runReset(data)
		expect(#data.slots).toBe(0)
	end)
end)

describe("PrestigeService — executeReset: contracts wiped", function()
	it("contracts = { dayKey='', slots={} }", function()
		local data = defaultData()
		runReset(data)
		expect(data.contracts.dayKey).toBe("")
		expect(#data.contracts.slots).toBe(0)
	end)
end)

describe("PrestigeService — executeReset: streak wiped", function()
	it("streak = { day=0, lastLoginAt=0 }", function()
		local data = defaultData()
		runReset(data)
		expect(data.streak.day).toBe(0)
		expect(data.streak.lastLoginAt).toBe(0)
	end)
end)

describe("PrestigeService — executeReset: rank.currentRun = 0", function()
	it("currentRun reset to 0", function()
		local data = defaultData()
		runReset(data)
		expect(data.rank.currentRun).toBe(0)
	end)
end)

describe("PrestigeService — executeReset: rank.lifetime preserved", function()
	it("lifetime was 12345, still 12345", function()
		local data = defaultData()
		runReset(data)
		expect(data.rank.lifetime).toBe(12345)
	end)
end)

describe("PrestigeService — executeReset: rank.dailyCaps reset", function()
	it("dailyCaps = { date='', marketPoints=0, vaultPoints=0 }", function()
		local data = defaultData()
		data.rank.dailyCaps = { date = "2026-06-14", marketPoints = 999, vaultPoints = 500 }
		runReset(data)
		expect(data.rank.dailyCaps.date).toBe("")
		expect(data.rank.dailyCaps.marketPoints).toBe(0)
		expect(data.rank.dailyCaps.vaultPoints).toBe(0)
	end)
end)

describe("PrestigeService — executeReset: sprintPoints preserved", function()
	it("sprintPoints.points unchanged (was 999)", function()
		local data = defaultData()
		runReset(data)
		expect(data.sprintPoints.points).toBe(999)
	end)
end)

describe("PrestigeService — executeReset: formulaLog preserved", function()
	it("T2_01 discovery survives", function()
		local data = defaultData()
		runReset(data)
		expect(data.formulaLog.discovered["T2_01"]).toBeTrue()
	end)
end)

describe("PrestigeService — executeReset: prestige.level incremented", function()
	it("level 0 → 1", function()
		local data = defaultData()
		runReset(data)
		expect(data.prestige.level).toBe(1)
	end)
end)

describe("PrestigeService — executeReset: prestige.jointQualLifetime preserved", function()
	it("jointQualLifetime false stays false", function()
		local data = defaultData()
		runReset(data)
		expect(data.prestige.jointQualLifetime).toBe(false)
	end)
end)

describe("PrestigeService — executeReset: ChiefBoard ODS write called", function()
	it("ODS receives (userId, lifetimeScore=12345)", function()
		local data = defaultData()
		local chiefWrites = runReset(data)
		expect(#chiefWrites).toBe(1)
		expect(chiefWrites[1].key).toBe("1")
		expect(chiefWrites[1].score).toBe(12345)
	end)
end)

-- ── End-to-end confirm tests ───────────────────────────────────────────────

describe("PrestigeService — full confirm: prestige.level == 1 and releaseFanOut fires", function()
	it("preReset + executeReset in order; PatentService.releaseAllForUser called", function()
		local data = defaultData()

		local releaseCount = 0
		local mockPatent = {
			releaseAllForUser = function(_userId, _now)
				releaseCount += 1
				return 0
			end,
		}
		local marketCallCount = 0
		local mockMarket = { cancelAllForUser = function(_p) marketCallCount += 1 return 0 end }
		local drainCallCount = 0

		local sessions: { [number]: any } = { [1] = data }
		local mockDs = {
			getProfile = function(userId) return sessions[userId] end,
			updateProfile = function(userId, fn) fn(sessions[userId]) end,
			drainPending = function(_uid, _d) drainCallCount += 1 end,
		}
		local chiefWrites: { any } = {}
		local mockRank = {
			writeChiefBoardScore = function(_p, d) table.insert(chiefWrites, d.rank.lifetime) end,
			addScore = function(_p, _d, _amt, _src) end,
		}

		PrestigeService._setDataService(mockDs)
		PrestigeService._setMarketService(mockMarket)
		PrestigeService._setPatentService(mockPatent)
		PrestigeService._setRankService(mockRank)
		PrestigeService._setEconomyConstants(EconomyConstants)

		-- Simulate the confirm flow manually (remote handler body)
		local blockers = PrestigeService.getBlockers(data)
		expect(#blockers).toBe(0)

		mockDs.updateProfile(1, function(d)
			PrestigeService.preReset(mockPlayer, d)
			PrestigeService.executeReset(mockPlayer, d, NOW)
		end)
		PrestigeService.releaseFanOut(mockPlayer, NOW)

		expect(data.prestige.level).toBe(1)
		expect(marketCallCount).toBe(1)
		expect(drainCallCount).toBe(1)
		expect(releaseCount).toBe(1)

		-- Reset
		PrestigeService._setDataService(nil)
		PrestigeService._setMarketService(nil)
		PrestigeService._setPatentService(nil)
		PrestigeService._setRankService(nil)
	end)
end)

describe("PrestigeService — double-confirm guard: blocker present returns ok=false", function()
	it("low pellets → blocked", function()
		local data = defaultData()
		data.balances.pellets = 0
		local blockers = PrestigeService.getBlockers(data)
		expect(#blockers > 0).toBeTrue()
		-- Simulate confirm returning early
		local result = if #blockers > 0 then { ok = false, err = blockers[1] } else { ok = true }
		expect(result.ok).toBe(false)
	end)
end)

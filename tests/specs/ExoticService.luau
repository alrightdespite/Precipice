-- ExoticService tests. Phase 10B.
-- Injection pattern — no Roblox globals, no live DataStores.
-- Tests 1–11: getCurrentValue decay math + onPairCompleted fan-out.

local spec = require("../spec")
local MockDataStore = require("../mocks/MockDataStore")
local EconomyConstants = require("../../src/shared/Config/EconomyConstants")
local Exotics = require("../../src/shared/Data/Exotics")
local RankMath = require("../../src/shared/Core/RankMath")
local ExoticService = require("../../src/server/Services/ExoticService")

local describe, it, expect = spec.describe, spec.it, spec.expect

local NOW = 1700000000

-- ── Fixtures ───────────────────────────────────────────────────────────────

local function defaultOpener()
	return {
		UserId = 1,
		Name = "Opener",
	}
end

local function defaultPartner()
	return {
		UserId = 2,
		Name = "Partner",
	}
end

local function defaultData()
	return {
		balances = { pellets = 0, catalysts = 0 },
		vault = { compounds = {}, residue = 0 },
		formulaLog = { discovered = {}, validatedPairs = {}, failedPairs = {} },
		rank = {
			currentRun = 0,
			lifetime = 0,
			dailyCaps = { date = "", marketPoints = 0, vaultPoints = 0 },
		},
		sprintPoints = { weekEpoch = 0, points = 0 },
		monetization = { rushUses = 0, timerSkipUses = 0 },
	}
end

-- ── Setup ──────────────────────────────────────────────────────────────────

local function setup()
	local exoticDs = MockDataStore.new()

	local vaultLog: { any } = {}
	local mockVaultService = {
		applyAward = function(data: any, compoundId: string, qty: number)
			data.vault.compounds[compoundId] = (data.vault.compounds[compoundId] or 0) + qty
			table.insert(vaultLog, { compoundId = compoundId, qty = qty })
		end,
	}

	local rankLog: { any } = {}
	local mockRankService = {
		addScore = function(player: any, _data: any, amount: number, source: string)
			table.insert(rankLog, { userId = player.UserId, amount = amount, source = source })
		end,
		addSprintPoints = function() end,
	}

	local mockEventService = {
		awardFlux = function() end,
	}

	local mockPatentService = {
		recordNaturalSynthesis = function() end,
	}

	local firedEvents: { any } = {}
	local mockRemoteService = {
		getEvent = function(name: string)
			return {
				FireClient = function(_, player: any, ...)
					table.insert(firedEvents, { name = name, userId = player and player.UserId, args = { ... } })
				end,
			}
		end,
	}

	ExoticService._setExoticDs(exoticDs)
	ExoticService._setExotics(Exotics)
	ExoticService._setEconomyConstants(EconomyConstants)
	ExoticService._setRankMath(RankMath)
	ExoticService._setVaultService(mockVaultService)
	ExoticService._setRankService(mockRankService)
	ExoticService._setEventService(mockEventService)
	ExoticService._setPatentService(mockPatentService)
	ExoticService._setRemoteService(mockRemoteService)
	ExoticService._setSpawnFn(function() end)

	return {
		exoticDs = exoticDs,
		vaultLog = vaultLog,
		rankLog = rankLog,
		firedEvents = firedEvents,
	}
end

-- EX_001: initialValue=376000, floorValue=94000, EXOTIC_DECAY_CONSTANT=0.97

describe("ExoticService — getCurrentValue at unitCount=0", function()
	it("returns initialValue unchanged", function()
		setup()
		local v = ExoticService.getCurrentValue("EX_001", 0)
		expect(v).toBe(376000)
	end)
end)

describe("ExoticService — getCurrentValue at unitCount=1", function()
	it("returns floor(initialValue × 0.97) = 364720", function()
		setup()
		local v = ExoticService.getCurrentValue("EX_001", 1)
		expect(v).toBe(math.floor(376000 * 0.97))
	end)
end)

describe("ExoticService — getCurrentValue at unitCount=46", function()
	it("floor kicks in — result equals floorValue", function()
		setup()
		-- 0.97^46 < 0.25, so decayed < floorValue
		local v = ExoticService.getCurrentValue("EX_001", 46)
		expect(v).toBe(Exotics["EX_001"].floorValue)
	end)
end)

describe("ExoticService — getCurrentValue at unitCount=48", function()
	it("still returns floorValue (never goes below floor)", function()
		setup()
		local v = ExoticService.getCurrentValue("EX_001", 48)
		expect(v).toBe(Exotics["EX_001"].floorValue)
	end)
end)

describe("ExoticService — onPairCompleted: unitCount increments by 2", function()
	it("DS record has unitCount == 2 after first completion", function()
		local ctx = setup()
		local opener = defaultOpener()
		local partner = defaultPartner()
		ExoticService.onPairCompleted(opener, partner, defaultData(), defaultData(), "EX_001", true, NOW)
		local rec = ctx.exoticDs:GetAsync("exotic:EX_001")
		expect(rec.unitCount).toBe(2)
	end)
end)

describe("ExoticService — onPairCompleted: both players receive 1 unit", function()
	it("applyAward called twice, each qty=1", function()
		local ctx = setup()
		ExoticService.onPairCompleted(defaultOpener(), defaultPartner(), defaultData(), defaultData(), "EX_001", true, NOW)
		local awards = 0
		for _, entry in ipairs(ctx.vaultLog) do
			if entry.compoundId == "EX_001" and entry.qty == 1 then
				awards += 1
			end
		end
		expect(awards).toBe(2)
	end)
end)

describe("ExoticService — onPairCompleted: firstPair recorded on first completion", function()
	it("firstPair.userId1 == opener.UserId", function()
		local ctx = setup()
		local opener = defaultOpener()
		ExoticService.onPairCompleted(opener, defaultPartner(), defaultData(), defaultData(), "EX_001", true, NOW)
		local rec = ctx.exoticDs:GetAsync("exotic:EX_001")
		expect(rec.firstPair ~= nil).toBeTrue()
		expect(rec.firstPair.userId1).toBe(opener.UserId)
	end)
end)

describe("ExoticService — onPairCompleted: firstPair NOT overwritten on second completion", function()
	it("firstPair.userId1 remains the original opener", function()
		local ctx = setup()
		local opener1 = defaultOpener()
		local opener2 = { UserId = 3, Name = "SecondOpener" }
		local partner = defaultPartner()
		-- First completion
		ExoticService.onPairCompleted(opener1, partner, defaultData(), defaultData(), "EX_001", true, NOW)
		-- Second completion with different opener
		ExoticService.onPairCompleted(opener2, partner, defaultData(), defaultData(), "EX_001", true, NOW)
		local rec = ctx.exoticDs:GetAsync("exotic:EX_001")
		expect(rec.firstPair.userId1).toBe(opener1.UserId)
	end)
end)

describe("ExoticService — onPairCompleted isNatural=true: addScore called for both", function()
	it("rankLog has two synthesis entries (one per player)", function()
		local ctx = setup()
		ExoticService.onPairCompleted(defaultOpener(), defaultPartner(), defaultData(), defaultData(), "EX_001", true, NOW)
		local synthCount = 0
		for _, entry in ipairs(ctx.rankLog) do
			if entry.source == "synthesis" then synthCount += 1 end
		end
		expect(synthCount).toBe(2)
	end)
end)

describe("ExoticService — onPairCompleted isNatural=false (Accelerated): addScore NOT called", function()
	it("rankLog has zero synthesis entries", function()
		local ctx = setup()
		ExoticService.onPairCompleted(defaultOpener(), defaultPartner(), defaultData(), defaultData(), "EX_001", false, NOW)
		local synthCount = 0
		for _, entry in ipairs(ctx.rankLog) do
			if entry.source == "synthesis" then synthCount += 1 end
		end
		expect(synthCount).toBe(0)
	end)
end)

describe("ExoticService — onPairCompleted isWorldFirst=true: claim bonus awarded to both", function()
	it("both players get claimBonus pellets and PATENT_CLAIM_CATALYSTS", function()
		setup()
		local openerData = defaultData()
		local partnerData = defaultData()
		ExoticService.onPairCompleted(defaultOpener(), defaultPartner(), openerData, partnerData, "EX_001", true, NOW)
		local exotic = Exotics["EX_001"]
		expect(openerData.balances.pellets).toBe(exotic.claimBonus)
		expect(partnerData.balances.pellets).toBe(exotic.claimBonus)
		expect(openerData.balances.catalysts).toBe(EconomyConstants.PATENT_CLAIM_CATALYSTS)
		expect(partnerData.balances.catalysts).toBe(EconomyConstants.PATENT_CLAIM_CATALYSTS)
	end)
end)

describe("ExoticService — onPairCompleted: recipe added to both formulaLog.discovered", function()
	it("both data.formulaLog.discovered[exoticId] == exoticId", function()
		setup()
		local openerData = defaultData()
		local partnerData = defaultData()
		ExoticService.onPairCompleted(defaultOpener(), defaultPartner(), openerData, partnerData, "EX_001", true, NOW)
		expect(openerData.formulaLog.discovered["EX_001"]).toBe("EX_001")
		expect(partnerData.formulaLog.discovered["EX_001"]).toBe("EX_001")
	end)
end)

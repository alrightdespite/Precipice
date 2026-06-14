-- EventService tests.
-- Injection pattern — no Roblox globals, no live DataStores.
-- Tests 1–24: EventService. Tests 25–26 live in OfflineIncome spec.

local spec = require("../spec")
local RankMath = require("../../src/shared/Core/RankMath")
local EconomyConstants = require("../../src/shared/Config/EconomyConstants")
local EventCompounds = require("../../src/shared/Data/EventCompounds")
local MockDataStore = require("../mocks/MockDataStore")
local EventService = require("../../src/server/Services/EventService")

local describe, it, expect = spec.describe, spec.it, spec.expect

local NOW = 1700000000 -- fixed timestamp for deterministic tests

-- ── Helpers ────────────────────────────────────────────────────────────────

local function defaultEvent()
	return {
		seasonKey = "cascade:s1",
		displayName = "The Cascade Protocol",
		isActive = true,
		isFirstRun = true,
		startAt = NOW - 100,
		endAt = NOW + 86400 * 7,
		milestoneTarget = 10000,
		milestoneReached = false,
		totalFluxEarned = 0,
	}
end

local function defaultData()
	return {
		schemaVersion = 3,
		balances = { pellets = 1000, catalysts = 0 },
		vault = { compounds = {}, residue = 0 },
		formulaLog = { discovered = {}, validatedPairs = {}, failedPairs = {} },
		slots = {},
		lastSeenAt = 0,
		rank = { currentRun = 0, lifetime = 0, dailyCaps = { date = "", marketPoints = 0, vaultPoints = 0 } },
		sprintPoints = { weekEpoch = 0, points = 0 },
		streak = { day = 0, lastLoginAt = 0 },
		contracts = { dayKey = "", slots = {} },
		prestige = { level = 0, jointQualLifetime = false },
		monetization = {
			gamepasses = { eventPass = false },
			rushUses = 0,
			timerSkipUses = 0,
			archiveUsesByMonth = {},
			receiptLedger = {},
		},
		cosmetics = { owned = {}, equipped = {} },
		eventState = {
			fluxBySeason = {},
			blueprintsOwned = {},
			extractionFluxToday = { date = "", count = 0 },
			milestoneClaimed = {},
		},
		pendingCreditsApplied = {},
	}
end

local function makeDs(initialEvent)
	local ds = MockDataStore.new()
	if initialEvent then
		ds._data["activeEvent"] = initialEvent
	end
	return ds
end

local noopRemote = {
	getEvent = function(_name)
		return { FireClient = function() end }
	end,
}

local mockPlayer = { UserId = 1, Name = "TestPlayer" }

local function setup(eventRecord, remoteService)
	EventService._setGlobalDs(makeDs(eventRecord))
	EventService._setRankMath(RankMath)
	EventService._setEconomyConstants(EconomyConstants)
	EventService._setEventCompounds(EventCompounds)
	EventService._setRemoteService(remoteService or noopRemote)
	EventService._setSpawnFn(function(fn)
		fn()
	end) -- synchronous for tests
	EventService._setClockFn(function()
		return NOW
	end)
end

-- ── 1–3: isEventActive ────────────────────────────────────────────────────

describe("EventService — isEventActive: no event", function()
	it("returns false when DS has no event", function()
		setup(nil)
		expect(EventService.isEventActive()).toBe(false)
	end)
end)

describe("EventService — isEventActive: active event", function()
	it("returns true when event is active and not expired", function()
		setup(defaultEvent())
		expect(EventService.isEventActive()).toBe(true)
	end)
end)

describe("EventService — isEventActive: expired event", function()
	it("returns false when endAt < now", function()
		local ev = defaultEvent()
		ev.endAt = NOW - 1
		setup(ev)
		expect(EventService.isEventActive()).toBe(false)
	end)
end)

-- ── 4–5: getIncomeMultiplier ──────────────────────────────────────────────

describe("EventService — getIncomeMultiplier: no event", function()
	it("returns 1.0", function()
		setup(nil)
		expect(EventService.getIncomeMultiplier(defaultData())).toBe(1.0)
	end)
end)

describe("EventService — getIncomeMultiplier: event active", function()
	it("returns 1.5", function()
		setup(defaultEvent())
		expect(EventService.getIncomeMultiplier(defaultData())).toBe(1.5)
	end)
end)

-- ── 6–7: getFluxMultiplier ────────────────────────────────────────────────

describe("EventService — getFluxMultiplier: event active, no pass", function()
	it("returns 1.0", function()
		setup(defaultEvent())
		local data = defaultData()
		data.monetization.gamepasses.eventPass = false
		expect(EventService.getFluxMultiplier(data)).toBe(1.0)
	end)
end)

describe("EventService — getFluxMultiplier: event active, event pass owned", function()
	it("returns 2.0", function()
		setup(defaultEvent())
		local data = defaultData()
		data.monetization.gamepasses.eventPass = true
		expect(EventService.getFluxMultiplier(data)).toBe(2.0)
	end)
end)

-- ── 8–12: awardFlux — synthesis ───────────────────────────────────────────

describe("EventService — awardFlux synthesis: T2, no pass", function()
	it("earns 3 Flux (base score × 1.0)", function()
		setup(defaultEvent())
		local data = defaultData()
		EventService.awardFlux(mockPlayer, data, "synthesis", 2, NOW)
		expect(data.eventState.fluxBySeason["cascade:s1"]).toBe(3)
	end)
end)

describe("EventService — awardFlux synthesis: T3, no pass", function()
	it("earns 16 Flux (base score × 1.0)", function()
		setup(defaultEvent())
		local data = defaultData()
		EventService.awardFlux(mockPlayer, data, "synthesis", 3, NOW)
		expect(data.eventState.fluxBySeason["cascade:s1"]).toBe(16)
	end)
end)

describe("EventService — awardFlux synthesis: T2, event pass", function()
	it("earns 6 Flux (3 × 2.0)", function()
		setup(defaultEvent())
		local data = defaultData()
		data.monetization.gamepasses.eventPass = true
		EventService.awardFlux(mockPlayer, data, "synthesis", 2, NOW)
		expect(data.eventState.fluxBySeason["cascade:s1"]).toBe(6)
	end)
end)

describe("EventService — awardFlux extraction: source = extraction for T1", function()
	it("uses extraction path: count increments, not synthesis scoring", function()
		setup(defaultEvent())
		local data = defaultData()
		EventService.awardFlux(mockPlayer, data, "extraction", 1, NOW)
		expect(data.eventState.extractionFluxToday.count).toBe(1)
		expect(data.eventState.fluxBySeason["cascade:s1"]).toBe(1)
	end)
end)

describe("EventService — awardFlux: no event active", function()
	it("returns without modifying data", function()
		setup(nil)
		local data = defaultData()
		EventService.awardFlux(mockPlayer, data, "synthesis", 2, NOW)
		expect(data.eventState.fluxBySeason["cascade:s1"]).toBe(nil)
	end)
end)

-- ── 13–16: awardFlux — extraction ────────────────────────────────────────

describe("EventService — awardFlux extraction: first extraction", function()
	it("extractionFluxToday.count becomes 1", function()
		setup(defaultEvent())
		local data = defaultData()
		EventService.awardFlux(mockPlayer, data, "extraction", 1, NOW)
		expect(data.eventState.extractionFluxToday.count).toBe(1)
	end)
end)

describe("EventService — awardFlux extraction: cap at 50", function()
	it("50 extractions fill cap; 51st earns 0", function()
		setup(defaultEvent())
		local data = defaultData()
		for _ = 1, 50 do
			EventService.awardFlux(mockPlayer, data, "extraction", 1, NOW)
		end
		expect(data.eventState.extractionFluxToday.count).toBe(50)
		local fluxBefore = data.eventState.fluxBySeason["cascade:s1"]
		EventService.awardFlux(mockPlayer, data, "extraction", 1, NOW)
		expect(data.eventState.fluxBySeason["cascade:s1"]).toBe(fluxBefore)
	end)
end)

describe("EventService — awardFlux extraction: cap resets on new UTC date", function()
	it("count resets to 1 after midnight UTC", function()
		setup(defaultEvent())
		local data = defaultData()
		-- Day 1
		EventService.awardFlux(mockPlayer, data, "extraction", 1, NOW)
		expect(data.eventState.extractionFluxToday.count).toBe(1)
		-- Day 2 (+86400s, guaranteed different UTC date string)
		EventService.awardFlux(mockPlayer, data, "extraction", 1, NOW + 86400)
		expect(data.eventState.extractionFluxToday.count).toBe(1)
	end)
end)

describe("EventService — awardFlux extraction: event pass earns 2", function()
	it("first extraction earns 2 Flux with event pass (1 × 2.0), cap still 50", function()
		setup(defaultEvent())
		local data = defaultData()
		data.monetization.gamepasses.eventPass = true
		EventService.awardFlux(mockPlayer, data, "extraction", 1, NOW)
		expect(data.eventState.extractionFluxToday.count).toBe(2)
		expect(data.eventState.fluxBySeason["cascade:s1"]).toBe(2)
	end)
end)

-- ── 17–19: spendFlux ──────────────────────────────────────────────────────

describe("EventService — spendFlux: sufficient Flux", function()
	it("returns true, decrements Flux, sets blueprintAccess", function()
		setup(defaultEvent())
		local data = defaultData()
		data.eventState.fluxBySeason["cascade:s1"] = 100
		local ok = EventService.spendFlux(mockPlayer, data, "EV_01", 50)
		expect(ok).toBe(true)
		expect(data.eventState.fluxBySeason["cascade:s1"]).toBe(50)
		expect(data.eventState.blueprintsOwned["EV_01"]).toBe(true)
		expect(data.formulaLog.blueprintAccess["EV_01"]).toBe(true)
	end)
end)

describe("EventService — spendFlux: insufficient Flux", function()
	it("returns false, no mutation", function()
		setup(defaultEvent())
		local data = defaultData()
		data.eventState.fluxBySeason["cascade:s1"] = 10
		local ok = EventService.spendFlux(mockPlayer, data, "EV_01", 50)
		expect(ok).toBe(false)
		expect(data.eventState.fluxBySeason["cascade:s1"]).toBe(10)
		expect(data.eventState.blueprintsOwned["EV_01"]).toBe(nil)
	end)
end)

describe("EventService — spendFlux: no event active", function()
	it("returns false", function()
		setup(nil)
		local data = defaultData()
		data.eventState.fluxBySeason["cascade:s1"] = 1000
		local ok = EventService.spendFlux(mockPlayer, data, "EV_01", 50)
		expect(ok).toBe(false)
	end)
end)

-- ── 20–21: hasBlueprint ───────────────────────────────────────────────────

describe("EventService — hasBlueprint: owned", function()
	it("returns true", function()
		local data = defaultData()
		data.eventState.blueprintsOwned["EV_01"] = true
		expect(EventService.hasBlueprint(data, "EV_01")).toBe(true)
	end)
end)

describe("EventService — hasBlueprint: not owned", function()
	it("returns false", function()
		local data = defaultData()
		expect(EventService.hasBlueprint(data, "EV_01")).toBe(false)
	end)
end)

-- ── 22–24: checkMilestoneDelivery ────────────────────────────────────────

describe("EventService — checkMilestoneDelivery: milestone reached, not claimed", function()
	it("awards 25 Catalysts and marks claimed", function()
		local eventRecord = defaultEvent()
		eventRecord.milestoneReached = true
		EventService._setGlobalDs(makeDs(eventRecord))
		EventService._setEconomyConstants(EconomyConstants)
		EventService._setRemoteService(noopRemote)
		local data = defaultData()
		local ev = { seasonKey = "cascade:s1" }
		EventService.checkMilestoneDelivery(mockPlayer, data, ev)
		expect(data.balances.catalysts).toBe(25)
		expect(data.eventState.milestoneClaimed["cascade:s1"]).toBe(true)
	end)
end)

describe("EventService — checkMilestoneDelivery: already claimed", function()
	it("no-op; catalysts unchanged", function()
		local eventRecord = defaultEvent()
		eventRecord.milestoneReached = true
		EventService._setGlobalDs(makeDs(eventRecord))
		EventService._setEconomyConstants(EconomyConstants)
		local data = defaultData()
		data.eventState.milestoneClaimed["cascade:s1"] = true
		data.balances.catalysts = 10
		local ev = { seasonKey = "cascade:s1" }
		EventService.checkMilestoneDelivery(mockPlayer, data, ev)
		expect(data.balances.catalysts).toBe(10)
	end)
end)

describe("EventService — checkMilestoneDelivery: milestone not reached", function()
	it("no-op; catalysts unchanged", function()
		local eventRecord = defaultEvent() -- milestoneReached = false
		EventService._setGlobalDs(makeDs(eventRecord))
		EventService._setEconomyConstants(EconomyConstants)
		local data = defaultData()
		local ev = { seasonKey = "cascade:s1" }
		EventService.checkMilestoneDelivery(mockPlayer, data, ev)
		expect(data.balances.catalysts).toBe(0)
	end)
end)

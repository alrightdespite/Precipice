-- MonetizationService tests.
-- Injection pattern — no Roblox globals, no DataStore.

local spec = require("../spec")
local EventCompounds = require("../../src/shared/Data/EventCompounds")
local MonetizationService = require("../../src/server/Services/MonetizationService")

local describe, it, expect = spec.describe, spec.it, spec.expect

-- ── Constants ──────────────────────────────────────────────────────────────

local GRANTED = "PurchaseGranted"
local NOT_PROCESSED = "NotProcessedYet"

local NOW = 1749859200 -- 2026-06-14 UTC

-- Mock game config with distinct IDs for test dispatch
local mockGameConfig = {
	BASE_SLOTS = 5,
	MAX_SLOTS = 10,
	EXPANDED_LAB_BONUS = 2,
	OFFLINE_CAP_BASE_HOURS = 12,
	OFFLINE_CAP_EXTENDED_HOURS = 24,
	OFFLINE_CAP_PRESTIGE4_BONUS_HOURS = 3.6,
	GAMEPASS_EXPANDED_LAB     = 2001,
	GAMEPASS_EXTENDED_OFFLINE  = 2002,
	GAMEPASS_COMPOUND_ARCHIVE  = 2003,
	GAMEPASS_EVENT_PASS        = 2004,
	PRODUCT_TIMER_SKIP    = 1001,
	PRODUCT_CATALYST_S    = 1002,
	PRODUCT_CATALYST_L    = 1003,
	PRODUCT_RUSH_ANALYSIS = 1004,
	PRODUCT_CATALYST_S_AMOUNT = 50,
	PRODUCT_CATALYST_L_AMOUNT = 150,
	PRODUCT_RUSH_USES_AMOUNT  = 3,
	CATALYST_SKIP_COST = 30,
}

local mockPlayer = { UserId = 99, Name = "TestPlayer" }

-- ── Default data builder ───────────────────────────────────────────────────

local function defaultData(): any
	return {
		schemaVersion = 2,
		balances = { pellets = 500000, catalysts = 100 },
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
			gamepasses = {},
			rushUses = 0,
			timerSkipUses = 0,
			archiveUsesByMonth = {},
			receiptLedger = {},
		},
		cosmetics = { owned = {}, equipped = {} },
		eventState = { fluxBySeason = {}, blueprintsOwned = {} },
		pendingCreditsApplied = {},
	}
end

-- ── Shared setup ───────────────────────────────────────────────────────────

local function setup()
	MonetizationService._setGameConfig(mockGameConfig)
	MonetizationService._setDecisions(GRANTED, NOT_PROCESSED)
	MonetizationService._setEventCompounds(EventCompounds)
	MonetizationService._setRemoteService({
		getEvent = function(_, _name) return { FireClient = function() end } end,
	})
end

setup()

-- ── Gamepass cache ─────────────────────────────────────────────────────────

describe("MonetizationService — refreshGamepasses: all passes false", function()
	it("gamepasses all false in data", function()
		local data = defaultData()
		local fired = nil
		MonetizationService._setRemoteService({
			getEvent = function(_, _name)
				return { FireClient = function(_, _p, payload) fired = payload end }
			end,
		})
		MonetizationService._setMarketplaceService({
			UserOwnsGamePassAsync = function(_, _userId, _passId) return false end,
		})
		MonetizationService.refreshGamepasses(mockPlayer, data)
		expect(data.monetization.gamepasses.expandedLab).toBe(false)
		expect(data.monetization.gamepasses.extendedOffline).toBe(false)
		expect(data.monetization.gamepasses.compoundArchive).toBe(false)
		expect(fired ~= nil).toBeTrue()
		setup()
	end)
end)

describe("MonetizationService — refreshGamepasses: ExpandedLab = true", function()
	it("gamepasses.expandedLab == true; others false", function()
		local data = defaultData()
		MonetizationService._setMarketplaceService({
			UserOwnsGamePassAsync = function(_, _userId, passId)
				return passId == mockGameConfig.GAMEPASS_EXPANDED_LAB
			end,
		})
		MonetizationService.refreshGamepasses(mockPlayer, data)
		expect(data.monetization.gamepasses.expandedLab).toBe(true)
		expect(data.monetization.gamepasses.extendedOffline).toBe(false)
		setup()
	end)
end)

-- ── Slot cap ──────────────────────────────────────────────────────────────

describe("MonetizationService — getSlotCap: P0, no ExpandedLab", function()
	it("== 5", function()
		local data = defaultData()
		expect(MonetizationService.getSlotCap(data)).toBe(5)
	end)
end)

describe("MonetizationService — getSlotCap: P1, no ExpandedLab", function()
	it("== 6", function()
		local data = defaultData()
		data.prestige.level = 1
		expect(MonetizationService.getSlotCap(data)).toBe(6)
	end)
end)

describe("MonetizationService — getSlotCap: P3, no ExpandedLab", function()
	it("== 7", function()
		local data = defaultData()
		data.prestige.level = 3
		expect(MonetizationService.getSlotCap(data)).toBe(7)
	end)
end)

describe("MonetizationService — getSlotCap: P5, no ExpandedLab", function()
	it("== 8", function()
		local data = defaultData()
		data.prestige.level = 5
		expect(MonetizationService.getSlotCap(data)).toBe(8)
	end)
end)

describe("MonetizationService — getSlotCap: P5, ExpandedLab owned", function()
	it("== 10 (8 + 2)", function()
		local data = defaultData()
		data.prestige.level = 5
		data.monetization.gamepasses = { expandedLab = true }
		expect(MonetizationService.getSlotCap(data)).toBe(10)
	end)
end)

describe("MonetizationService — getSlotCap: P9, ExpandedLab owned, hard cap enforced", function()
	it("== 10", function()
		local data = defaultData()
		data.prestige.level = 9
		data.monetization.gamepasses = { expandedLab = true }
		expect(MonetizationService.getSlotCap(data)).toBe(10)
	end)
end)

-- ── Offline cap ───────────────────────────────────────────────────────────

describe("MonetizationService — getOfflineCap: P0, no ExtendedOffline", function()
	it("== 12", function()
		local data = defaultData()
		expect(MonetizationService.getOfflineCap(data)).toBe(12)
	end)
end)

describe("MonetizationService — getOfflineCap: P0, ExtendedOffline owned", function()
	it("== 24", function()
		local data = defaultData()
		data.monetization.gamepasses = { extendedOffline = true }
		expect(MonetizationService.getOfflineCap(data)).toBe(24)
	end)
end)

describe("MonetizationService — getOfflineCap: P4, no ExtendedOffline", function()
	it("== 15.6", function()
		local data = defaultData()
		data.prestige.level = 4
		expect(MonetizationService.getOfflineCap(data)).toBe(15.6)
	end)
end)

describe("MonetizationService — getOfflineCap: P4, ExtendedOffline owned", function()
	it("== 27.6", function()
		local data = defaultData()
		data.prestige.level = 4
		data.monetization.gamepasses = { extendedOffline = true }
		expect(MonetizationService.getOfflineCap(data)).toBe(27.6)
	end)
end)

-- ── ProcessReceipt helpers ─────────────────────────────────────────────────

local function makeSession(data: any)
	local sessions: { [number]: any } = { [mockPlayer.UserId] = data }
	return {
		updateProfile = function(userId, fn) fn(sessions[userId]) end,
		getProfile = function(userId) return sessions[userId] end,
	}
end

local function makeMockRemote()
	local fired: { any } = {}
	local remote = {
		getEvent = function(_, _name)
			return {
				FireClient = function(_, _p, ...)
					table.insert(fired, { ... })
				end,
			}
		end,
		fired = fired,
	}
	return remote
end

local function resetForReceipt(data: any)
	local ds = makeSession(data)
	MonetizationService._setDataService(ds)
	MonetizationService._setPlayers({
		GetPlayerByUserId = function(_, _id) return mockPlayer end,
	})
	MonetizationService._setLoaded({ [mockPlayer.UserId] = true })
	MonetizationService._setRemoteService(makeMockRemote())
	return ds
end

-- ── ProcessReceipt / idempotency ──────────────────────────────────────────

describe("MonetizationService — receipt CatalystS: catalysts += 50, receiptId recorded", function()
	it("catalysts == 150, ledger has purchaseId", function()
		local data = defaultData()
		resetForReceipt(data)
		local result = MonetizationService._processReceipt({
			PurchaseId = 1000,
			PlayerId = mockPlayer.UserId,
			ProductId = mockGameConfig.PRODUCT_CATALYST_S,
		})
		expect(result).toBe(GRANTED)
		expect(data.balances.catalysts).toBe(150)
		expect(data.monetization.receiptLedger["1000"]).toBe(true)
		setup()
	end)
end)

describe("MonetizationService — receipt CatalystS replayed: idempotent", function()
	it("second call with same purchaseId leaves catalysts unchanged", function()
		local data = defaultData()
		resetForReceipt(data)
		local receipt = { PurchaseId = 2000, PlayerId = mockPlayer.UserId, ProductId = mockGameConfig.PRODUCT_CATALYST_S }
		MonetizationService._processReceipt(receipt)
		local catalystsAfterFirst = data.balances.catalysts
		MonetizationService._processReceipt(receipt)
		expect(data.balances.catalysts).toBe(catalystsAfterFirst)
		setup()
	end)
end)

describe("MonetizationService — receipt CatalystL: catalysts += 150", function()
	it("catalysts == 250", function()
		local data = defaultData()
		resetForReceipt(data)
		MonetizationService._processReceipt({
			PurchaseId = 3000,
			PlayerId = mockPlayer.UserId,
			ProductId = mockGameConfig.PRODUCT_CATALYST_L,
		})
		expect(data.balances.catalysts).toBe(250)
		setup()
	end)
end)

describe("MonetizationService — receipt RushAnalysis: rushUses += 3", function()
	it("rushUses == 3", function()
		local data = defaultData()
		resetForReceipt(data)
		MonetizationService._processReceipt({
			PurchaseId = 4000,
			PlayerId = mockPlayer.UserId,
			ProductId = mockGameConfig.PRODUCT_RUSH_ANALYSIS,
		})
		expect(data.monetization.rushUses).toBe(3)
		setup()
	end)
end)

describe("MonetizationService — receipt RushAnalysis when rushUses == 8: capped at 9", function()
	it("rushUses == 9, not 11", function()
		local data = defaultData()
		data.monetization.rushUses = 8
		resetForReceipt(data)
		MonetizationService._processReceipt({
			PurchaseId = 5000,
			PlayerId = mockPlayer.UserId,
			ProductId = mockGameConfig.PRODUCT_RUSH_ANALYSIS,
		})
		expect(data.monetization.rushUses).toBe(9)
		setup()
	end)
end)

describe("MonetizationService — receipt unknown productId: returns PurchaseGranted, no crash", function()
	it("granted, data unchanged", function()
		local data = defaultData()
		resetForReceipt(data)
		local result = MonetizationService._processReceipt({
			PurchaseId = 6000,
			PlayerId = mockPlayer.UserId,
			ProductId = 9999,
		})
		expect(result).toBe(GRANTED)
		expect(data.balances.catalysts).toBe(100)
		setup()
	end)
end)

describe("MonetizationService — receipt player not in session: NotProcessedYet", function()
	it("returns NOT_PROCESSED", function()
		local data = defaultData()
		resetForReceipt(data)
		MonetizationService._setLoaded({}) -- userId NOT in loaded
		local result = MonetizationService._processReceipt({
			PurchaseId = 7000,
			PlayerId = mockPlayer.UserId,
			ProductId = mockGameConfig.PRODUCT_CATALYST_S,
		})
		expect(result).toBe(NOT_PROCESSED)
		expect(data.balances.catalysts).toBe(100) -- unchanged
		setup()
	end)
end)

-- ── Catalyst skip deduction ───────────────────────────────────────────────

describe("MonetizationService — deductCatalystSkip: 30 catalysts → returns true, catalysts == 0", function()
	it("ok", function()
		local data = defaultData()
		data.balances.catalysts = 30
		local ok = MonetizationService.deductCatalystSkip(data)
		expect(ok).toBe(true)
		expect(data.balances.catalysts).toBe(0)
	end)
end)

describe("MonetizationService — deductCatalystSkip: 29 catalysts → returns false, unchanged", function()
	it("ok", function()
		local data = defaultData()
		data.balances.catalysts = 29
		local ok = MonetizationService.deductCatalystSkip(data)
		expect(ok).toBe(false)
		expect(data.balances.catalysts).toBe(29)
	end)
end)

-- ── CompoundArchive monthly grant ─────────────────────────────────────────

describe("MonetizationService — grantArchiveUses: first grant this month", function()
	it("archiveAccess populated for all EventCompounds IDs, monthKey recorded", function()
		local data = defaultData()
		MonetizationService._setRemoteService(makeMockRemote())
		MonetizationService.grantArchiveUses(mockPlayer, data, NOW)
		local monthKey = os.date("!%Y-%m", NOW) :: string
		expect(data.monetization.archiveUsesByMonth[monthKey]).toBe(true)
		local count = 0
		for compoundId in pairs(EventCompounds) do
			expect(data.formulaLog.archiveAccess[compoundId]).toBe(true)
			count += 1
		end
		expect(count > 0).toBeTrue()
		setup()
	end)
end)

describe("MonetizationService — grantArchiveUses: second call same month is no-op", function()
	it("archiveAccess not double-written", function()
		local data = defaultData()
		MonetizationService._setRemoteService(makeMockRemote())
		MonetizationService.grantArchiveUses(mockPlayer, data, NOW)
		-- Manually remove one compound to verify second call doesn't re-add
		local firstCompound = next(EventCompounds)
		data.formulaLog.archiveAccess[firstCompound] = nil
		MonetizationService.grantArchiveUses(mockPlayer, data, NOW) -- should no-op
		expect(data.formulaLog.archiveAccess[firstCompound]).toBeNil()
		setup()
	end)
end)

-- ── TimerSkip routing ─────────────────────────────────────────────────────

describe("MonetizationService — applyTimerSkip: no running slots → timerSkipUses += 1", function()
	it("timerSkipUses == 1", function()
		local data = defaultData()
		-- No slots
		MonetizationService.applyTimerSkip(mockPlayer, data)
		expect(data.monetization.timerSkipUses).toBe(1)
	end)
end)

describe("MonetizationService — applyTimerSkip: running slot → applySkipToSlot called", function()
	it("mock slotService.applySkipToSlot called with correct slotIndex", function()
		local data = defaultData()
		data.slots = {
			{ index = 2, compoundId = "T2_01", workRemaining = 300, kind = "synthesis" },
			{ index = 4, compoundId = "T1_01", workRemaining = 60, kind = "extraction" },
		}
		local calls: { { player: any, slotIndex: number } } = {}
		MonetizationService._setSlotService({
			applySkipToSlot = function(p, idx)
				table.insert(calls, { player = p, slotIndex = idx })
			end,
		})
		MonetizationService.applyTimerSkip(mockPlayer, data)
		expect(#calls).toBe(1)
		expect(calls[1].slotIndex).toBe(2) -- lowest running index
		expect(data.monetization.timerSkipUses).toBe(0) -- not incremented
		MonetizationService._setSlotService(nil)
	end)
end)

-- MarketService tests.
-- Mandatory per task spec:
--   createListing (valid, invalid price, insufficient stock)
--   cancelListing (valid, wrong player)
--   buyListing (valid online, valid offline, insufficient pellets, concurrent R13)
--   browseTier (active-only filter, pagination)
--   runExpirySweep (expired listing → EXPIRED, compounds returned)

local spec = require("../spec")
local MarketMath = require("../../src/shared/Core/MarketMath")
local MarketService = require("../../src/server/Services/MarketService")
local MockDataStore = require("../mocks/MockDataStore")

local describe, it, expect = spec.describe, spec.it, spec.expect

-- ── Shared helpers ─────────────────────────────────────────────────────────

local TEST_COMPOUNDS = {
	["T2_01"] = { id = "T2_01", tier = 2, baseValue = 100 },
	["T3_01"] = { id = "T3_01", tier = 3, baseValue = 400 },
}

-- Minimal mock VaultService: uses the same logic as VaultService inner helpers.
local MockVault = {
	applyAward = function(data: any, compoundId: string, qty: number)
		data.vault.compounds[compoundId] = (data.vault.compounds[compoundId] or 0) + qty
	end,
	applyDeduct = function(data: any, compoundId: string, qty: number)
		local have = data.vault.compounds[compoundId] or 0
		assert(have >= qty, "applyDeduct: insufficient " .. compoundId)
		data.vault.compounds[compoundId] = have - qty
	end,
	fireVaultUpdate = function(_player: any, _data: any) end, -- no-op
}

local function defaultData(): any
	return {
		balances = { pellets = 0, catalysts = 0 },
		vault = { compounds = {}, residue = 0 },
		pendingCreditsApplied = {},
	}
end

-- Build a mock DataService backed by a sessions table.
local function makeMockDs(sessions: { [number]: any })
	return {
		updateProfile = function(userId: number, fn: (any) -> ())
			assert(sessions[userId], "no session for " .. tostring(userId))
			fn(sessions[userId])
		end,
		getProfile = function(userId: number): any
			assert(sessions[userId], "no session for " .. tostring(userId))
			return sessions[userId]
		end,
	}
end

-- Clock that returns a fixed base and auto-increments each call (unique listingIds).
local function makeTickClock(base: number)
	local t = base
	return function()
		t += 1
		return t
	end
end

-- Wire all injected deps fresh for each test.
local function setup(sessions: { [number]: any }, onlinePlayers: { [number]: any }?)
	local listingsDs = MockDataStore.new()
	local indexDs = MockDataStore.new()
	local pendingDs = MockDataStore.new()
	local mockDs = makeMockDs(sessions)
	local online = onlinePlayers or {}

	MarketService._setListingsDs(listingsDs)
	MarketService._setIndexDs(indexDs)
	MarketService._setPendingDs(pendingDs)
	MarketService._setDataService(mockDs)
	MarketService._setVaultService(MockVault)
	MarketService._setRemoteService(nil)
	MarketService._setMm(MarketMath)
	MarketService._setCompounds(TEST_COMPOUNDS)
	MarketService._setGetPlayer(function(userId: number) return online[userId] end)
	MarketService._setClock(makeTickClock(1_000_000))
	MarketService._resetSeq()

	return listingsDs, indexDs, pendingDs
end

-- ── createListing ──────────────────────────────────────────────────────────

describe("MarketService — createListing valid", function()
	it("returns listingId; vault deducted; fee deducted; listing written ACTIVE", function()
		local seller = { UserId = 1001 }
		local sellerData = defaultData()
		sellerData.vault.compounds["T2_01"] = 5
		sellerData.balances.pellets = 1000

		local listingsDs, indexDs = setup({ [1001] = sellerData })

		-- price=100 → within floor/ceil for baseValue=100; fee = floor(100*5*0.01) = 5
		local listingId, err = MarketService.createListing(seller, "T2_01", 5, 100)

		expect(err).toBeNil()
		expect(type(listingId)).toBe("string")

		-- Vault deducted
		expect(sellerData.vault.compounds["T2_01"]).toBe(0)

		-- Fee deducted: listingFee(100*5) = listingFee(500) = floor(500*0.01) = 5
		expect(sellerData.balances.pellets).toBe(995)

		-- Listing written ACTIVE
		local record = listingsDs:GetAsync("listing:" .. listingId)
		expect(record ~= nil).toBeTrue()
		expect(record.status).toBe("ACTIVE")
		expect(record.compoundId).toBe("T2_01")
		expect(record.quantity).toBe(5)
		expect(record.price).toBe(100)
		expect(record.sellerId).toBe(1001)
		expect(record.expiresAt - record.createdAt).toBe(72 * 3600)

		-- listingId in tier index
		local index = indexDs:GetAsync("index:tier:2")
		expect(index ~= nil).toBeTrue()
		local found = false
		for _, id in ipairs(index) do
			if id == listingId then found = true end
		end
		expect(found).toBeTrue()
	end)
end)

describe("MarketService — createListing invalid price", function()
	it("price below floor → err, no mutation", function()
		local seller = { UserId = 1002 }
		local sellerData = defaultData()
		sellerData.vault.compounds["T2_01"] = 5
		sellerData.balances.pellets = 1000
		setup({ [1002] = sellerData })

		-- floor = floor(100 * 0.80) = 80; price 50 is below floor
		local listingId, err = MarketService.createListing(seller, "T2_01", 5, 50)

		expect(listingId).toBeNil()
		expect(type(err)).toBe("string")
		-- No mutation
		expect(sellerData.vault.compounds["T2_01"]).toBe(5)
		expect(sellerData.balances.pellets).toBe(1000)
	end)

	it("price above ceiling → err, no mutation", function()
		local seller = { UserId = 1003 }
		local sellerData = defaultData()
		sellerData.vault.compounds["T2_01"] = 5
		sellerData.balances.pellets = 1000
		setup({ [1003] = sellerData })

		-- ceil = ceil(100 * 5.00) = 500; price 600 is above ceiling
		local listingId, err = MarketService.createListing(seller, "T2_01", 5, 600)

		expect(listingId).toBeNil()
		expect(type(err)).toBe("string")
		expect(sellerData.vault.compounds["T2_01"]).toBe(5)
		expect(sellerData.balances.pellets).toBe(1000)
	end)
end)

describe("MarketService — createListing insufficient vault stock", function()
	it("quantity exceeds vault → err, no mutation", function()
		local seller = { UserId = 1004 }
		local sellerData = defaultData()
		sellerData.vault.compounds["T2_01"] = 2
		sellerData.balances.pellets = 1000
		setup({ [1004] = sellerData })

		local listingId, err = MarketService.createListing(seller, "T2_01", 5, 100)

		expect(listingId).toBeNil()
		expect(type(err)).toBe("string")
		expect(sellerData.vault.compounds["T2_01"]).toBe(2)
		expect(sellerData.balances.pellets).toBe(1000)
	end)
end)

-- ── cancelListing ──────────────────────────────────────────────────────────

describe("MarketService — cancelListing valid", function()
	it("status → CANCELLED; compounds returned to vault", function()
		local seller = { UserId = 2001 }
		local sellerData = defaultData()
		sellerData.vault.compounds["T2_01"] = 10
		sellerData.balances.pellets = 2000

		local listingsDs, indexDs = setup({ [2001] = sellerData }, { [2001] = seller })

		local listingId = MarketService.createListing(seller, "T2_01", 5, 100)
		expect(sellerData.vault.compounds["T2_01"]).toBe(5) -- deducted

		local ok, err = MarketService.cancelListing(seller, listingId)

		expect(ok).toBeTrue()
		expect(err).toBeNil()

		-- Compounds returned
		expect(sellerData.vault.compounds["T2_01"]).toBe(10)

		-- Listing status CANCELLED
		local record = listingsDs:GetAsync("listing:" .. listingId)
		expect(record.status).toBe("CANCELLED")

		-- Removed from index
		local index = indexDs:GetAsync("index:tier:2") or {}
		local found = false
		for _, id in ipairs(index) do
			if id == listingId then found = true end
		end
		expect(found).toBeFalse()
	end)
end)

describe("MarketService — cancelListing wrong player", function()
	it("sellerId mismatch → err, no mutation", function()
		local seller = { UserId = 2002 }
		local intruder = { UserId = 2003 }
		local sellerData = defaultData()
		sellerData.vault.compounds["T2_01"] = 5
		sellerData.balances.pellets = 1000

		local listingsDs = setup({ [2002] = sellerData, [2003] = defaultData() })

		local listingId = MarketService.createListing(seller, "T2_01", 5, 100)

		local ok, err = MarketService.cancelListing(intruder, listingId)

		expect(ok).toBeFalse()
		expect(type(err)).toBe("string")

		-- Listing still ACTIVE
		local record = listingsDs:GetAsync("listing:" .. listingId)
		expect(record.status).toBe("ACTIVE")
	end)
end)

-- ── buyListing ─────────────────────────────────────────────────────────────

describe("MarketService — buyListing valid (online seller)", function()
	it("buyer debited; seller credited; compounds awarded; status SOLD", function()
		local seller = { UserId = 3001 }
		local buyer = { UserId = 3002 }
		local sellerData = defaultData()
		sellerData.vault.compounds["T2_01"] = 5
		sellerData.balances.pellets = 1000
		local buyerData = defaultData()
		buyerData.balances.pellets = 5000

		local listingsDs = setup(
			{ [3001] = sellerData, [3002] = buyerData },
			{ [3001] = seller, [3002] = buyer }
		)

		local listingId = MarketService.createListing(seller, "T2_01", 5, 100)
		-- fee = listingFee(500) = 5; seller now has 995 pellets, 0 T2_01

		local ok, err = MarketService.buyListing(buyer, listingId)

		expect(ok).toBeTrue()
		expect(err).toBeNil()

		-- Buyer debited: 5000 - 500 = 4500 (totalCost = 5 * 100)
		expect(buyerData.balances.pellets).toBe(4500)

		-- Buyer awarded compounds
		expect(buyerData.vault.compounds["T2_01"]).toBe(5)

		-- Seller credited: sellerProceeds(500) = 500 - floor(500*0.05) = 500 - 25 = 475
		-- seller started with 995 (1000 - fee 5); +475 = 1470
		expect(sellerData.balances.pellets).toBe(1470)

		-- Listing SOLD
		local record = listingsDs:GetAsync("listing:" .. listingId)
		expect(record.status).toBe("SOLD")
	end)
end)

describe("MarketService — buyListing insufficient pellets", function()
	it("buyer too poor → err, no debit", function()
		local seller = { UserId = 3003 }
		local buyer = { UserId = 3004 }
		local sellerData = defaultData()
		sellerData.vault.compounds["T2_01"] = 5
		sellerData.balances.pellets = 1000
		local buyerData = defaultData()
		buyerData.balances.pellets = 10 -- not enough for 5*100=500

		setup({ [3003] = sellerData, [3004] = buyerData })

		local listingId = MarketService.createListing(seller, "T2_01", 5, 100)

		local ok, err = MarketService.buyListing(buyer, listingId)

		expect(ok).toBeFalse()
		expect(type(err)).toBe("string")
		expect(buyerData.balances.pellets).toBe(10) -- no debit
	end)
end)

describe("MarketService — buyListing offline seller → PendingCredits", function()
	it("offline seller receives PendingCredit with correct creditId", function()
		local seller = { UserId = 3005 }
		local buyer = { UserId = 3006 }
		local sellerData = defaultData()
		sellerData.vault.compounds["T2_01"] = 5
		sellerData.balances.pellets = 1000
		local buyerData = defaultData()
		buyerData.balances.pellets = 5000

		-- seller NOT in onlinePlayers → offline path
		local _, _, pendingDs = setup(
			{ [3005] = sellerData, [3006] = buyerData },
			{ [3006] = buyer } -- seller 3005 absent
		)

		local listingId = MarketService.createListing(seller, "T2_01", 5, 100)
		local ok, err = MarketService.buyListing(buyer, listingId)

		expect(ok).toBeTrue()
		expect(err).toBeNil()

		-- Seller profile pellets unchanged (offline)
		-- sellerData.balances.pellets started at 1000, had fee of 5 deducted = 995
		expect(sellerData.balances.pellets).toBe(995)

		-- PendingCredit written for seller
		local pending = pendingDs:GetAsync("PendingCredits/" .. tostring(3005))
		expect(pending ~= nil).toBeTrue()
		expect(#pending.credits).toBe(1)

		local credit = pending.credits[1]
		expect(credit.creditId).toBe("market:" .. listingId .. ":" .. tostring(3005))
		-- proceeds = sellerProceeds(500) = 475
		expect(credit.amount).toBe(475)
		expect(credit.source).toBe("market_sale")
	end)
end)

-- R13 mandatory concurrency test
describe("MarketService — buyListing concurrent race (R13)", function()
	it("two buyers, one listing → exactly one succeeds; other refunded with 'already sold'", function()
		local seller = { UserId = 4001 }
		local buyerA = { UserId = 4002 }
		local buyerB = { UserId = 4003 }
		local sellerData = defaultData()
		sellerData.vault.compounds["T2_01"] = 5
		sellerData.balances.pellets = 1000
		local dataA = defaultData()
		dataA.balances.pellets = 2000
		local dataB = defaultData()
		dataB.balances.pellets = 2000

		local listingsDs, _, pendingDs = setup(
			{ [4001] = sellerData, [4002] = dataA, [4003] = dataB },
			{ [4001] = seller, [4002] = buyerA, [4003] = dataB }
		)

		local listingId = MarketService.createListing(seller, "T2_01", 5, 100)
		-- totalCost = 500

		-- buyerA buys first — succeeds, marks SOLD
		local okA, errA = MarketService.buyListing(buyerA, listingId)
		-- buyerB buys same listing — CAS sees SOLD, must fail and refund
		local okB, errB = MarketService.buyListing(buyerB, listingId)

		-- Exactly one succeeds
		expect(okA).toBeTrue()
		expect(okB).toBeFalse()
		expect(errB).toBe("already sold")

		-- BuyerA debited and got compounds
		expect(dataA.balances.pellets).toBe(1500) -- 2000 - 500
		expect(dataA.vault.compounds["T2_01"]).toBe(5)

		-- BuyerB fully refunded
		expect(dataB.balances.pellets).toBe(2000)
		expect((dataB.vault.compounds["T2_01"] or 0)).toBe(0)

		-- Listing is SOLD
		local record = listingsDs:GetAsync("listing:" .. listingId)
		expect(record.status).toBe("SOLD")
	end)
end)

-- ── browseTier ─────────────────────────────────────────────────────────────

describe("MarketService — browseTier active-only filter", function()
	it("skips SOLD, CANCELLED, EXPIRED stale entries; returns only ACTIVE", function()
		local seller = { UserId = 5001 }
		local sellerData = defaultData()
		sellerData.vault.compounds["T2_01"] = 20
		sellerData.balances.pellets = 50000

		local listingsDs, indexDs = setup({ [5001] = sellerData })

		-- Create 3 listings
		local id1 = MarketService.createListing(seller, "T2_01", 1, 100)
		local id2 = MarketService.createListing(seller, "T2_01", 1, 100)
		local id3 = MarketService.createListing(seller, "T2_01", 1, 100)

		-- Manually mark id2 as SOLD, id3 as CANCELLED in the DataStore
		listingsDs:UpdateAsync("listing:" .. id2, function(r)
			local u = {} for k, v in pairs(r) do u[k] = v end
			u.status = "SOLD"
			return u
		end)
		listingsDs:UpdateAsync("listing:" .. id3, function(r)
			local u = {} for k, v in pairs(r) do u[k] = v end
			u.status = "CANCELLED"
			return u
		end)

		local results, err = MarketService.browseTier(nil, 2, 1)

		expect(err).toBeNil()
		expect(#results).toBe(1)
		expect(results[1].listingId).toBe(id1)
	end)
end)

describe("MarketService — browseTier pagination", function()
	it("page 1 returns items 1-20; page 2 returns items 21-40", function()
		local seller = { UserId = 5002 }
		local sellerData = defaultData()
		sellerData.vault.compounds["T2_01"] = 40
		sellerData.balances.pellets = 1_000_000

		setup({ [5002] = sellerData })

		-- Create 40 listings
		local ids = {}
		for _ = 1, 40 do
			local id = MarketService.createListing(seller, "T2_01", 1, 100)
			table.insert(ids, id)
		end

		local page1, _ = MarketService.browseTier(nil, 2, 1)
		local page2, _ = MarketService.browseTier(nil, 2, 2)

		expect(#page1).toBe(20)
		expect(#page2).toBe(20)

		-- page1 listings are ids[1..20], page2 are ids[21..40]
		expect(page1[1].listingId).toBe(ids[1])
		expect(page1[20].listingId).toBe(ids[20])
		expect(page2[1].listingId).toBe(ids[21])
		expect(page2[20].listingId).toBe(ids[40])
	end)
end)

-- ── runExpirySweep ─────────────────────────────────────────────────────────

describe("MarketService — runExpirySweep", function()
	it("expired ACTIVE listing → status EXPIRED; compounds returned to online seller", function()
		local seller = { UserId = 6001 }
		local sellerData = defaultData()
		sellerData.vault.compounds["T2_01"] = 5
		sellerData.balances.pellets = 1000

		local listingsDs, indexDs = setup(
			{ [6001] = sellerData },
			{ [6001] = seller }
		)

		local listingId = MarketService.createListing(seller, "T2_01", 5, 100)
		-- seller now has 0 T2_01 in vault

		-- Read the listing to get its expiresAt
		local record = listingsDs:GetAsync("listing:" .. listingId)
		expect(record.status).toBe("ACTIVE")

		-- Sweep at expiresAt + 1
		MarketService.runExpirySweep(record.expiresAt + 1)

		-- Listing marked EXPIRED
		local updated = listingsDs:GetAsync("listing:" .. listingId)
		expect(updated.status).toBe("EXPIRED")

		-- Compounds returned to seller
		expect(sellerData.vault.compounds["T2_01"]).toBe(5)

		-- Removed from index
		local index = indexDs:GetAsync("index:tier:2") or {}
		local found = false
		for _, id in ipairs(index) do
			if id == listingId then found = true end
		end
		expect(found).toBeFalse()
	end)

	it("not-yet-expired ACTIVE listing is left untouched", function()
		local seller = { UserId = 6002 }
		local sellerData = defaultData()
		sellerData.vault.compounds["T2_01"] = 5
		sellerData.balances.pellets = 1000

		local listingsDs = setup({ [6002] = sellerData })

		local listingId = MarketService.createListing(seller, "T2_01", 5, 100)
		local record = listingsDs:GetAsync("listing:" .. listingId)

		-- Sweep one second before expiry
		MarketService.runExpirySweep(record.expiresAt - 1)

		local stillActive = listingsDs:GetAsync("listing:" .. listingId)
		expect(stillActive.status).toBe("ACTIVE")
	end)
end)

-- ── self-trade guard ───────────────────────────────────────────────────────

describe("MarketService — buyListing self-trade rejection", function()
	it("seller cannot buy their own listing: returns SELF_TRADE error", function()
		local seller = { UserId = 7001 }
		local sellerData = defaultData()
		sellerData.vault.compounds["T2_01"] = 5
		sellerData.balances.pellets = 10000

		local listingsDs = setup({ [7001] = sellerData }, { [7001] = seller })

		local listingId = MarketService.createListing(seller, "T2_01", 5, 100)
		local record = listingsDs:GetAsync("listing:" .. listingId)
		expect(record.status).toBe("ACTIVE")

		-- Seller tries to buy their own listing
		local ok, err = MarketService.buyListing(seller, listingId)
		expect(ok).toBeFalse()
		expect(err).toBe("SELF_TRADE")

		-- Listing still ACTIVE; no pellet debit occurred beyond the listing fee
		local afterRecord = listingsDs:GetAsync("listing:" .. listingId)
		expect(afterRecord.status).toBe("ACTIVE")
	end)
end)

-- ── onCreditDrained (offline-seller rank/contract parity) ───────────────────

describe("MarketService — onCreditDrained", function()
	-- Inject recording rank/contract mocks over a fresh setup.
	local function setupWithScoring()
		local sellerData = defaultData()
		setup({ [9001] = sellerData }, { [9001] = { UserId = 9001 } })

		local rankCalls: { number } = {}
		local contractCalls: { { progressType: string, amount: number } } = {}
		MarketService._setRankService({
			scoreMarketSale = function(_player: any, _data: any, proceeds: number)
				table.insert(rankCalls, proceeds)
			end,
		})
		MarketService._setContractService({
			recordProgress = function(_player: any, _data: any, progressType: string, amount: number)
				table.insert(contractCalls, { progressType = progressType, amount = amount })
			end,
		})
		return sellerData, rankCalls, contractCalls
	end

	it("market_sale credit awards rank + contract progress equal to proceeds", function()
		local sellerData, rankCalls, contractCalls = setupWithScoring()
		MarketService.onCreditDrained(9001, sellerData, {
			creditId = "market:x:9001",
			amount = 4750,
			source = "market_sale",
		})
		expect(#rankCalls).toBe(1)
		expect(rankCalls[1]).toBe(4750)
		expect(#contractCalls).toBe(1)
		expect(contractCalls[1].progressType).toBe("market_sell_pellets")
		expect(contractCalls[1].amount).toBe(4750)
	end)

	it("non-market_sale credit (e.g. patent dividend) is ignored", function()
		local sellerData, rankCalls, contractCalls = setupWithScoring()
		MarketService.onCreditDrained(9001, sellerData, {
			creditId = "dividend:wk25:9001",
			amount = 90800,
			source = "patent_dividend",
		})
		expect(#rankCalls).toBe(0)
		expect(#contractCalls).toBe(0)
	end)
end)

-- MarketService: cross-server compound marketplace (E7, H4).
-- DataStore: MarketListings (per-listing records), MarketIndex (tier index).
-- No Roblox globals at module level — all injected for Lune testability.
-- TODO Phase 5 hardening: MemoryStore sorted map per tier for fast browse

-- ── Injected state ─────────────────────────────────────────────────────────

local _listingsDs: any = nil  -- DataStore("MarketListings")
local _indexDs: any = nil     -- DataStore("MarketIndex")
local _pendingDs: any = nil   -- DataStore("PendingCredits")
local _dataService: any = nil -- DataService
local _vaultService: any = nil -- VaultService
local _remoteService: any = nil -- RemoteService
local _rankService: any = nil  -- RankService
local _contractService: any = nil -- ContractService
local _mm: any = nil          -- MarketMath
local _compounds: any = nil   -- Compounds data table
local _getPlayer: any = nil   -- fn(userId: number) -> Player?
local _clock: any = nil       -- fn() -> number (os.time in prod)

local _analyticsService: any = { track = function() end, Events = {} }
local _listingSeq = 0 -- monotonic counter for unique listingIds within same second

local MarketService = {}

-- ── Injection helpers ──────────────────────────────────────────────────────

function MarketService._setAnalyticsService(as: any) _analyticsService = as end
function MarketService._setListingsDs(ds: any) _listingsDs = ds end
function MarketService._setIndexDs(ds: any) _indexDs = ds end
function MarketService._setPendingDs(ds: any) _pendingDs = ds end
function MarketService._setDataService(ds: any) _dataService = ds end
function MarketService._setVaultService(vs: any) _vaultService = vs end
function MarketService._setRemoteService(rs: any) _remoteService = rs end
function MarketService._setMm(mm: any) _mm = mm end
function MarketService._setCompounds(c: any) _compounds = c end
function MarketService._setGetPlayer(fn: any) _getPlayer = fn end
function MarketService._setClock(fn: any) _clock = fn end
function MarketService._resetSeq() _listingSeq = 0 end
function MarketService._setRankService(rs: any) _rankService = rs end
function MarketService._setContractService(cs: any) _contractService = cs end

-- ── Internal helpers ───────────────────────────────────────────────────────

local function now(): number
	return _clock and _clock() or os.time()
end

-- Append a PendingCredit entry for userId. Idempotent on creditId.
-- NOTE: PendingCredits only drains into data.balances.pellets (DataService §drain).
-- Offline compound returns are credited as baseValue × quantity pellets (design limit).
local function writePendingCredit(userId: number, creditId: string, amount: number, source: string)
	_pendingDs:UpdateAsync("PendingCredits/" .. tostring(userId), function(stored)
		local credits = (stored and stored.credits) or {}
		for _, c in ipairs(credits) do
			if c.creditId == creditId then
				return nil -- already written; idempotent
			end
		end
		local newCredits = { table.unpack(credits) }
		table.insert(newCredits, { creditId = creditId, amount = amount, source = source })
		return { credits = newCredits }
	end)
end

local function removeFromIndex(tier: number, listingId: string, sellerId: number)
	_indexDs:UpdateAsync("index:tier:" .. tostring(tier), function(stored)
		if stored == nil then return nil end
		local newList = {}
		for _, id in ipairs(stored) do
			if id ~= listingId then
				table.insert(newList, id)
			end
		end
		return newList
	end)
	_indexDs:UpdateAsync("index:user:" .. tostring(sellerId), function(stored)
		if stored == nil then return nil end
		local newList = {}
		for _, id in ipairs(stored) do
			if id ~= listingId then
				table.insert(newList, id)
			end
		end
		return newList
	end)
end

-- ── Public API ─────────────────────────────────────────────────────────────

-- Create a listing. Deducts listing fee and compounds in one updateProfile callback.
-- Listing record written to DataStore separately after the profile commit.
function MarketService.createListing(
	player: any,
	compoundId: string,
	quantity: number,
	price: number
): (string?, string?)
	local compound = _compounds[compoundId]
	if not compound then
		return nil, "unknown compound"
	end
	quantity = math.floor(quantity)
	if quantity <= 0 then
		return nil, "quantity must be positive"
	end
	-- E7: price bounds enforced at creation only
	if not _mm.isValidPrice(price, compound.baseValue) then
		return nil, "price out of allowed range"
	end

	local listingFee = _mm.listingFee(price * quantity)
	local userId = player.UserId
	local failErr: string? = nil

	-- All vault/balance mutations in one updateProfile callback
	_dataService.updateProfile(userId, function(data)
		local have = data.vault.compounds[compoundId] or 0
		if have < quantity then
			failErr = "insufficient vault stock"
			return
		end
		if data.balances.pellets < listingFee then
			failErr = "insufficient pellets for listing fee"
			return
		end
		data.balances.pellets -= listingFee
		_vaultService.applyDeduct(data, compoundId, quantity)
		if _contractService then
			_contractService.recordProgress(player, data, "market_list", 1)
		end
	end)

	if failErr then
		return nil, failErr
	end

	-- Build listing record (separate DataStore write after profile commit)
	local t = now()
	_listingSeq += 1
	local listingId = compoundId .. ":" .. tostring(userId) .. ":" .. tostring(t) .. "_" .. tostring(_listingSeq)
	local record = {
		listingId = listingId,
		sellerId = userId,
		compoundId = compoundId,
		tier = compound.tier,
		quantity = quantity,
		price = price,
		createdAt = t,
		expiresAt = t + 72 * 3600,
		status = "ACTIVE",
	}

	_analyticsService.track(_analyticsService.Events.MARKET_LIST or "market_list", {
		userId = userId,
		compoundId = compoundId,
		quantity = quantity,
		price = price,
	})

	_listingsDs:SetAsync("listing:" .. listingId, record)

	_indexDs:UpdateAsync("index:tier:" .. tostring(compound.tier), function(stored)
		local list = stored or {}
		local newList = { table.unpack(list) }
		table.insert(newList, listingId)
		return newList
	end)

	_indexDs:UpdateAsync("index:user:" .. tostring(userId), function(stored)
		local list = stored or {}
		local newList = { table.unpack(list) }
		table.insert(newList, listingId)
		return newList
	end)

	return listingId, nil
end

-- Cancel a listing. Returns compounds; listing fee is NOT refunded (consumed on creation).
function MarketService.cancelListing(player: any, listingId: string): (boolean, string?)
	local userId = player.UserId
	local record = _listingsDs:GetAsync("listing:" .. listingId)

	if record == nil then
		return false, "listing not found"
	end
	if record.status ~= "ACTIVE" then
		return false, "listing not active"
	end
	if record.sellerId ~= userId then
		return false, "not your listing"
	end

	-- CAS: only cancel if still ACTIVE
	local cancelled = false
	_listingsDs:UpdateAsync("listing:" .. listingId, function(current)
		if current == nil or current.status ~= "ACTIVE" then
			return nil
		end
		cancelled = true
		local updated = {}
		for k, v in pairs(current) do updated[k] = v end
		updated.status = "CANCELLED"
		return updated
	end)

	if not cancelled then
		return false, "listing no longer active"
	end

	-- Return compounds to vault
	_dataService.updateProfile(userId, function(data)
		_vaultService.applyAward(data, record.compoundId, record.quantity)
	end)

	removeFromIndex(record.tier, listingId, record.sellerId)

	_analyticsService.track(_analyticsService.Events.MARKET_CANCEL or "market_cancel", {
		userId = userId,
		listingId = listingId,
	})

	local playerObj = _getPlayer(userId)
	if playerObj then
		_vaultService.fireVaultUpdate(playerObj, _dataService.getProfile(userId))
	end

	return true, nil
end

-- Buy a listing. Debit buyer first, then CAS the listing to SOLD.
-- If CAS fails (race), refund buyer immediately.
function MarketService.buyListing(player: any, listingId: string): (boolean, string?)
	local buyerId = player.UserId
	local record = _listingsDs:GetAsync("listing:" .. listingId)

	if record == nil then
		return false, "listing not found"
	end
	if record.status ~= "ACTIVE" then
		return false, "already sold"
	end
	if record.sellerId == buyerId then
		return false, "SELF_TRADE"
	end

	local totalCost = record.price * record.quantity
	local failErr: string? = nil

	-- Step 2: reserve buyer debit — committed before CAS attempt
	_dataService.updateProfile(buyerId, function(data)
		if data.balances.pellets < totalCost then
			failErr = "insufficient pellets"
			return
		end
		data.balances.pellets -= totalCost
	end)

	if failErr then
		return false, failErr
	end

	-- Step 3: CAS — only mark SOLD if still ACTIVE
	local purchased = false
	_listingsDs:UpdateAsync("listing:" .. listingId, function(current)
		if current == nil or current.status ~= "ACTIVE" then
			return nil
		end
		purchased = true
		local updated = {}
		for k, v in pairs(current) do updated[k] = v end
		updated.status = "SOLD"
		return updated
	end)

	if not purchased then
		-- Refund buyer immediately
		_dataService.updateProfile(buyerId, function(data)
			data.balances.pellets += totalCost
		end)
		return false, "already sold"
	end

	-- Step 5: pay seller
	local sellerId = record.sellerId
	local proceeds = _mm.sellerProceeds(totalCost)
	local sellerPlayer = _getPlayer(sellerId)

	if sellerPlayer then
		_dataService.updateProfile(sellerId, function(data)
			data.balances.pellets += proceeds
			if _rankService then
				_rankService.scoreMarketSale(sellerPlayer, data, proceeds)
			end
			if _contractService then
				_contractService.recordProgress(sellerPlayer, data, "market_sell_pellets", proceeds)
			end
		end)
	else
		local creditId = "market:" .. listingId .. ":" .. tostring(sellerId)
		writePendingCredit(sellerId, creditId, proceeds, "market_sale")
		-- TODO Phase 8: rank from market sale via PendingCredits drain (offline seller path)
	end

	-- Step 6: award compounds to buyer
	_dataService.updateProfile(buyerId, function(data)
		_vaultService.applyAward(data, record.compoundId, record.quantity)
		if _contractService then
			_contractService.recordProgress(player, data, "market_buy", 1)
		end
	end)

	_analyticsService.track(_analyticsService.Events.MARKET_BUY or "market_buy", {
		userId = buyerId,
		listingId = listingId,
		compoundId = record.compoundId,
		totalCost = totalCost,
	})

	-- Step 7: remove from index, push VaultUpdate to buyer
	removeFromIndex(record.tier, listingId, record.sellerId)

	local buyerPlayer = _getPlayer(buyerId)
	if buyerPlayer then
		_vaultService.fireVaultUpdate(buyerPlayer, _dataService.getProfile(buyerId))
	end

	return true, nil
end

-- Browse listings for a tier. Paginated, page size 20, 1-indexed.
-- Stale index entries (SOLD/EXPIRED/CANCELLED) are skipped silently (H4).
function MarketService.browseTier(_player: any, tier: number?, page: number): ({ any }, string?)
	if tier == nil then
		return {}, nil
	end

	local index = _indexDs:GetAsync("index:tier:" .. tostring(tier))
	if index == nil then
		return {}, nil
	end

	local PAGE_SIZE = 20
	local startIdx = (page - 1) * PAGE_SIZE + 1
	local endIdx = page * PAGE_SIZE

	local results = {}
	for i = startIdx, math.min(endIdx, #index) do
		local id = index[i]
		local listing = _listingsDs:GetAsync("listing:" .. id)
		if listing ~= nil and listing.status == "ACTIVE" then
			table.insert(results, listing)
		end
	end

	return results, nil
end

-- Expiry sweep: called hourly by GlobalJobService as MarketExpirySweep step.
-- Iterates all tier indexes, expires ACTIVE listings past their expiresAt.
-- Offline sellers: compounds returned as pellet value (PendingCredits pellet-only limit).
function MarketService.runExpirySweep(sweepNow: number?)
	sweepNow = sweepNow or now()

	for tier = 2, 7 do
		local index = _indexDs:GetAsync("index:tier:" .. tostring(tier))
		if index == nil then continue end

		for _, listingId in ipairs(index) do
			local listing = _listingsDs:GetAsync("listing:" .. listingId)
			if listing == nil or listing.status ~= "ACTIVE" then continue end
			if sweepNow < listing.expiresAt then continue end

			-- CAS expire: guard against another server expiring this listing first
			local expired = false
			_listingsDs:UpdateAsync("listing:" .. listingId, function(current)
				if current == nil or current.status ~= "ACTIVE" then
					return nil
				end
				if sweepNow < current.expiresAt then
					return nil
				end
				expired = true
				local updated = {}
				for k, v in pairs(current) do updated[k] = v end
				updated.status = "EXPIRED"
				return updated
			end)

			if not expired then continue end

			-- Return compounds to seller
			local sellerId = listing.sellerId
			local sellerPlayer = _getPlayer(sellerId)

			if sellerPlayer then
				_dataService.updateProfile(sellerId, function(data)
					_vaultService.applyAward(data, listing.compoundId, listing.quantity)
				end)
			else
				-- PendingCredits only supports pellets; convert at baseValue rate
				local compound = _compounds[listing.compoundId]
				local pelletValue = (compound and compound.baseValue or 0) * listing.quantity
				if pelletValue > 0 then
					local creditId = "expiry:" .. listingId .. ":" .. tostring(sellerId)
					writePendingCredit(sellerId, creditId, pelletValue, "market_expiry")
				end
			end

			removeFromIndex(tier, listingId, listing.sellerId)
		end
	end
end

-- Cancel all active listings for a player. Called by PrestigeService only.
-- Compounds are returned to vault by cancelListing. Idempotent on non-ACTIVE listings.
-- Returns count cancelled.
function MarketService.cancelAllForUser(player: any): number
	local userId = player.UserId
	local ids = _indexDs:GetAsync("index:user:" .. tostring(userId)) or {}
	local cancelled = 0
	for _, listingId in ipairs(ids) do
		local ok = MarketService.cancelListing(player, listingId)
		if ok then
			cancelled += 1
		end
	end
	return cancelled
end

-- ── Production init ────────────────────────────────────────────────────────

function MarketService.init()
	local DataStoreService = game:GetService("DataStoreService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	_listingsDs = DataStoreService:GetDataStore("MarketListings")
	_indexDs = DataStoreService:GetDataStore("MarketIndex")
	_pendingDs = DataStoreService:GetDataStore("PendingCredits")
	_mm = require(ReplicatedStorage.Shared.Core.MarketMath)
	_compounds = require(ReplicatedStorage.Shared.Data.Compounds)
	_dataService = require(ServerScriptService.Server.Services.DataService)
	_vaultService = require(ServerScriptService.Server.Services.VaultService)
	_remoteService = require(ServerScriptService.Server.Services.RemoteService)
	_rankService = require(ServerScriptService.Server.Services.RankService)
	_contractService = require(ServerScriptService.Server.Services.ContractService)
	_analyticsService = require(ServerScriptService.Server.Services.AnalyticsService)
	_getPlayer = function(userId: number) return Players:GetPlayerByUserId(userId) end
	_clock = os.time

	-- Wire C2S remotes
	_remoteService.getFunction("MarketCreateListing").OnServerInvoke =
		function(player: Player, compoundId: any, quantity: any, price: any)
			if type(compoundId) ~= "string" or type(quantity) ~= "number" or type(price) ~= "number" then
				return nil, "invalid args"
			end
			return MarketService.createListing(player, compoundId, math.floor(quantity), math.floor(price))
		end

	_remoteService.getFunction("MarketCancelListing").OnServerInvoke =
		function(player: Player, listingId: any)
			if type(listingId) ~= "string" then
				return false, "invalid args"
			end
			return MarketService.cancelListing(player, listingId)
		end

	_remoteService.getFunction("MarketBuyListing").OnServerInvoke =
		function(player: Player, listingId: any)
			if type(listingId) ~= "string" then
				return false, "invalid args"
			end
			return MarketService.buyListing(player, listingId)
		end

	_remoteService.getFunction("MarketBrowse").OnServerInvoke =
		function(player: Player, tier: any, page: any)
			if type(page) ~= "number" then
				return {}, "invalid args"
			end
			local tierNum: number? = if type(tier) == "number" then tier else nil
			return MarketService.browseTier(player, tierNum, math.max(1, math.floor(page)))
		end

	-- MarketExpirySweep is driven by ClockService: it attempts the GlobalJobService claim hourly
	-- via ClockService._runMarketSweep, which calls MarketService.runExpirySweep.
end

return MarketService

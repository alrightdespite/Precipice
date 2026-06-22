-- EventService: seasonal event lifecycle — Flux, blueprints, milestone, event patents.
-- No Roblox globals at module level. Injection pattern.
-- See docs/specs/EventService.md, doc §29.

-- ── Injected state ─────────────────────────────────────────────────────────

local _dataService: any = nil
local _rankMath: any = nil
local _remoteService: any = nil
local _economyConstants: any = nil
local _eventCompounds: any = nil
local _globalDs: any = nil
local _spawnFn: (((() -> ()) -> ())) = function(fn)
	fn()
end
local _clockFn: () -> number = os.time
local _analyticsService: any = { track = function() end, Events = {} }

-- ── Cache ──────────────────────────────────────────────────────────────────

local _eventCache: any = nil
local _cacheFetchedAt = 0
local CACHE_TTL = 60

-- ── Module ─────────────────────────────────────────────────────────────────

local EventService = {}

-- ── Injection helpers ──────────────────────────────────────────────────────

function EventService._setDataService(s: any)
	_dataService = s
end
function EventService._setRankMath(s: any)
	_rankMath = s
end
function EventService._setRemoteService(s: any)
	_remoteService = s
end
function EventService._setEconomyConstants(s: any)
	_economyConstants = s
end
function EventService._setEventCompounds(s: any)
	_eventCompounds = s
end
function EventService._setGlobalDs(s: any)
	_globalDs = s
	_eventCache = nil
	_cacheFetchedAt = 0
end
function EventService._setSpawnFn(fn: any)
	_spawnFn = fn
end
function EventService._setClockFn(fn: any)
	_clockFn = fn
end
function EventService._setAnalyticsService(as: any)
	_analyticsService = as
end

-- ── Public API ─────────────────────────────────────────────────────────────

function EventService.getActiveEvent(): any?
	local now = _clockFn()
	if _cacheFetchedAt > 0 and (now - _cacheFetchedAt) < CACHE_TTL then
		if _eventCache ~= nil and _eventCache.isActive and _eventCache.endAt > now then
			return _eventCache
		end
		return nil
	end
	-- Stale or uninitialized: refresh from DataStore
	if _globalDs then
		local ok, result = pcall(function()
			return _globalDs:GetAsync("activeEvent")
		end)
		_cacheFetchedAt = now
		if ok then
			_eventCache = result
		end
	end
	if _eventCache ~= nil and _eventCache.isActive and _eventCache.endAt > now then
		return _eventCache
	end
	return nil
end

function EventService.isEventActive(): boolean
	return EventService.getActiveEvent() ~= nil
end

function EventService.isFirstRun(): boolean
	local ev = EventService.getActiveEvent()
	return ev ~= nil and ev.isFirstRun == true
end

function EventService.getIncomeMultiplier(_data: any): number
	if not EventService.isEventActive() then
		return 1.0
	end
	return _economyConstants.EVENT_INCOME_MULTIPLIER
end

function EventService.getFluxMultiplier(data: any): number
	if not EventService.isEventActive() then
		return 1.0
	end
	if data.monetization.gamepasses.eventPass == true then
		return _economyConstants.EVENT_PASS_FLUX_MULTIPLIER
	end
	return 1.0
end

function EventService.awardFlux(player: any, data: any, source: string, tier: number?, now: number)
	if not EventService.isEventActive() then
		return
	end
	local ev = EventService.getActiveEvent()
	if not ev then
		return
	end
	local seasonKey = ev.seasonKey
	data.eventState.fluxBySeason[seasonKey] = data.eventState.fluxBySeason[seasonKey] or 0

	local multiplier = EventService.getFluxMultiplier(data)
	local earned = 0

	if source == "synthesis" then
		local baseFlux = _rankMath.scoreForCompletion(tier or 1)
		earned = math.floor(baseFlux * multiplier)
	elseif source == "extraction" then
		local today = tostring(os.date("!%Y-%m-%d", now))
		if data.eventState.extractionFluxToday.date ~= today then
			data.eventState.extractionFluxToday = { date = today, count = 0 }
		end
		local remaining = _economyConstants.FLUX_EXTRACTION_DAILY_CAP
			- data.eventState.extractionFluxToday.count
		if remaining <= 0 then
			return
		end
		local baseEarn = _economyConstants.FLUX_EXTRACTION_PER_COMPLETION
		local multiplied = math.floor(baseEarn * multiplier)
		earned = math.min(multiplied, remaining)
		data.eventState.extractionFluxToday.count += earned
	end

	if earned <= 0 then
		return
	end
	data.eventState.fluxBySeason[seasonKey] += earned

	_spawnFn(function()
		local ok, err = pcall(function()
			_globalDs:UpdateAsync("activeEvent", function(record)
				if record == nil or not record.isActive then
					return nil
				end
				local newRecord = table.clone(record)
				newRecord.totalFluxEarned = (newRecord.totalFluxEarned or 0) + earned
				if not newRecord.milestoneReached
					and newRecord.totalFluxEarned >= newRecord.milestoneTarget
				then
					newRecord.milestoneReached = true
				end
				return newRecord
			end)
		end)
		if not ok then
			warn("EventService: global Flux update failed:", err)
		end
	end)

	if _remoteService then
		_remoteService.getEvent("FluxUpdate"):FireClient(player, {
			seasonKey = seasonKey,
			total = data.eventState.fluxBySeason[seasonKey],
		})
	end

	_analyticsService.track(_analyticsService.Events.FLUX_EARN or "flux_earn", {
		userId = player.UserId,
		source = source,
		earned = earned,
	})

	EventService.checkMilestoneDelivery(player, data, ev)
end

function EventService.checkMilestoneDelivery(player: any, data: any, ev: any)
	local seasonKey = ev.seasonKey
	if data.eventState.milestoneClaimed[seasonKey] then
		return
	end
	local globalRecord = _globalDs:GetAsync("activeEvent")
	if globalRecord == nil or not globalRecord.milestoneReached then
		return
	end
	data.balances.catalysts += _economyConstants.EVENT_MILESTONE_CATALYSTS
	data.eventState.milestoneClaimed[seasonKey] = true
	if _remoteService then
		_remoteService.getEvent("BalanceUpdate"):FireClient(
			player,
			data.balances.pellets,
			data.balances.catalysts,
			data.monetization.rushUses,
			data.monetization.timerSkipUses or 0
		)
	end
end

function EventService.spendFlux(
	player: any,
	data: any,
	compoundId: string,
	cost: number
): boolean
	if not EventService.isEventActive() then
		return false
	end
	local ev = EventService.getActiveEvent()
	if not ev then
		return false
	end
	local seasonKey = ev.seasonKey
	local current = data.eventState.fluxBySeason[seasonKey] or 0
	if current < cost then
		return false
	end
	data.eventState.fluxBySeason[seasonKey] = current - cost
	data.eventState.blueprintsOwned[compoundId] = true
	data.formulaLog.blueprintAccess = data.formulaLog.blueprintAccess or {}
	data.formulaLog.blueprintAccess[compoundId] = true
	if _remoteService then
		_remoteService.getEvent("FluxUpdate"):FireClient(player, {
			seasonKey = seasonKey,
			total = data.eventState.fluxBySeason[seasonKey],
			blueprintsOwned = data.eventState.blueprintsOwned,
		})
	end
	return true
end

function EventService.hasBlueprint(data: any, compoundId: string): boolean
	return data.eventState.blueprintsOwned[compoundId] == true
end

function EventService.getBlueprintCost(compoundId: string): number?
	if _eventCompounds == nil then
		return nil
	end
	local c = _eventCompounds[compoundId]
	return c and c.blueprintFlux or nil
end

function EventService.isBlueprintAvailable(compoundId: string): boolean
	return EventService.isEventActive()
		and _eventCompounds ~= nil
		and _eventCompounds[compoundId] ~= nil
end

function EventService.onLogin(player: any, data: any)
	local ev = EventService.getActiveEvent()
	if not ev then
		return
	end
	EventService.checkMilestoneDelivery(player, data, ev)
	if _remoteService then
		local seasonKey = ev.seasonKey
		_remoteService.getEvent("FluxUpdate"):FireClient(player, {
			seasonKey = seasonKey,
			total = data.eventState.fluxBySeason[seasonKey] or 0,
			blueprintsOwned = data.eventState.blueprintsOwned,
		})
	end
end

function EventService.setActiveEvent(record: any)
	if _globalDs then
		_globalDs:UpdateAsync("activeEvent", function(_)
			return record
		end)
	end
	_eventCache = nil
	_cacheFetchedAt = 0
end

-- ── Init ────────────────────────────────────────────────────────────────────

function EventService.init()
	local DataStoreService = game:GetService("DataStoreService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	_dataService = require(ServerScriptService.Server.Services.DataService)
	_rankMath = require(ReplicatedStorage.Shared.Core.RankMath)
	_remoteService = require(ServerScriptService.Server.Services.RemoteService)
	_economyConstants = require(ReplicatedStorage.Shared.Config.EconomyConstants)
	_eventCompounds = require(ReplicatedStorage.Shared.Data.EventCompounds)
	_globalDs = DataStoreService:GetDataStore("EventGlobal")
	_analyticsService = require(ServerScriptService.Server.Services.AnalyticsService)
	_spawnFn = task.spawn

	-- Seed initial cache (non-fatal if no event configured yet)
	pcall(function()
		EventService.getActiveEvent()
	end)

	-- Wire BlueprintPurchase C2S Function
	_remoteService.setInvoke("BlueprintPurchase", function(player: Player, compoundId: any)
		if type(compoundId) ~= "string" then
			return { ok = false, err = "invalid args" }
		end
		if not EventService.isEventActive() then
			return { ok = false, err = "no active event" }
		end
		if not EventService.isBlueprintAvailable(compoundId) then
			return { ok = false, err = "blueprint not available" }
		end
		if not _dataService then
			return { ok = false, err = "service not ready" }
		end
		local userId = player.UserId
		local result = { ok = false, err = "unknown error" }
		_dataService.updateProfile(userId, function(data)
			if EventService.hasBlueprint(data, compoundId) then
				result = { ok = false, err = "already owned" }
				return
			end
			local cost = EventService.getBlueprintCost(compoundId)
			if not cost then
				result = { ok = false, err = "unknown blueprint" }
				return
			end
			local ok = EventService.spendFlux(player, data, compoundId, cost)
			if ok then
				result = { ok = true, err = nil }
				_analyticsService.track(_analyticsService.Events.BLUEPRINT_PURCHASE or "blueprint_purchase", {
					userId = userId,
					compoundId = compoundId,
				})
			else
				result = { ok = false, err = "insufficient Flux" }
			end
		end)
		return result
	end)
end

return EventService

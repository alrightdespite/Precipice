-- ExoticService: T6+T6 exotic synthesis — unit count, value decay, first-pair claim.
-- No Roblox globals at module level. Injection pattern.

-- ── Injected state ─────────────────────────────────────────────────────────

local _exoticDs: any = nil
local _exotics: any = nil
local _remoteService: any = nil
local _rankService: any = nil
local _eventService: any = nil
local _patentService: any = nil
local _vaultService: any = nil
local _rankMath: any = nil
local _economyConstants: any = nil
local _spawnFn: (((() -> ()) -> ())) = function(fn)
	fn()
end

local ExoticService = {}

-- ── Injection helpers ──────────────────────────────────────────────────────

function ExoticService._setExoticDs(ds: any) _exoticDs = ds end
function ExoticService._setExotics(e: any) _exotics = e end
function ExoticService._setRemoteService(r: any) _remoteService = r end
function ExoticService._setRankService(r: any) _rankService = r end
function ExoticService._setEventService(e: any) _eventService = e end
function ExoticService._setPatentService(p: any) _patentService = p end
function ExoticService._setVaultService(v: any) _vaultService = v end
function ExoticService._setRankMath(r: any) _rankMath = r end
function ExoticService._setEconomyConstants(ec: any) _economyConstants = ec end
function ExoticService._setSpawnFn(fn: any) _spawnFn = fn end

-- ── Decay math ─────────────────────────────────────────────────────────────

function ExoticService.getCurrentValue(exoticId: string, unitCount: number): number
	local exotic = _exotics[exoticId]
	assert(exotic, "ExoticService: unknown exotic " .. exoticId)
	local decayed = exotic.initialValue * (_economyConstants.EXOTIC_DECAY_CONSTANT ^ unitCount)
	return math.max(math.floor(decayed), exotic.floorValue)
end

function ExoticService.getCurrentValueLive(exoticId: string): number
	local ok, record = pcall(function()
		return _exoticDs:GetAsync("exotic:" .. exoticId)
	end)
	if not ok or not record then
		local exotic = _exotics[exoticId]
		return exotic and exotic.initialValue or 0
	end
	return ExoticService.getCurrentValue(exoticId, record.unitCount)
end

-- ── Completion handling ────────────────────────────────────────────────────

function ExoticService.onPairCompleted(
	openerPlayer: any,
	partnerPlayer: any,
	openerData: any,
	partnerData: any,
	exoticId: string,
	isNatural: boolean,
	now: number
)
	local EC = _economyConstants

	-- Step 1: Atomic unit count + first-pair claim.
	_exoticDs:UpdateAsync("exotic:" .. exoticId, function(record)
		local rec = record or { exoticId = exoticId, unitCount = 0, firstPair = nil }
		local newRec = {
			exoticId = rec.exoticId,
			unitCount = rec.unitCount + 2,
			firstPair = rec.firstPair,
		}
		if newRec.firstPair == nil then
			newRec.firstPair = {
				userId1 = openerPlayer.UserId,
				userId2 = partnerPlayer.UserId,
			}
		end
		return newRec
	end)

	local committed = _exoticDs:GetAsync("exotic:" .. exoticId)
	local isWorldFirst = committed ~= nil
		and committed.firstPair ~= nil
		and committed.firstPair.userId1 == openerPlayer.UserId
		and (committed.unitCount == 2) -- only first completion has unitCount == 2

	-- Step 2: Award to both.
	_vaultService.applyAward(openerData, exoticId, 1)
	_vaultService.applyAward(partnerData, exoticId, 1)

	-- Step 3: Natural synthesis rewards.
	if isNatural then
		local points = _rankMath.scoreForCompletion(7)
		_rankService.addScore(openerPlayer, openerData, points, "synthesis")
		_rankService.addSprintPoints(openerPlayer, openerData, points, now)
		_rankService.addScore(partnerPlayer, partnerData, points, "synthesis")
		_rankService.addSprintPoints(partnerPlayer, partnerData, points, now)
		_eventService.awardFlux(openerPlayer, openerData, "synthesis", 7, now)
		_eventService.awardFlux(partnerPlayer, partnerData, "synthesis", 7, now)
		_patentService.recordNaturalSynthesis(openerPlayer, exoticId, openerData, now)
		_patentService.recordNaturalSynthesis(partnerPlayer, exoticId, partnerData, now)
	end

	-- Step 4: World-first claim bonus.
	if isWorldFirst then
		local exotic = _exotics[exoticId]
		openerData.balances.pellets += exotic.claimBonus
		openerData.balances.catalysts += EC.PATENT_CLAIM_CATALYSTS
		partnerData.balances.pellets += exotic.claimBonus
		partnerData.balances.catalysts += EC.PATENT_CLAIM_CATALYSTS
		_rankService.addScore(openerPlayer, openerData, EC.PATENT_CLAIM_RANK, "claim")
		_rankService.addScore(partnerPlayer, partnerData, EC.PATENT_CLAIM_RANK, "claim")
		-- TODO Phase 11: fire world-first announcement via AnnouncementService
	end

	-- Step 5: Teach recipe to both.
	openerData.formulaLog.discovered[exoticId] = exoticId
	partnerData.formulaLog.discovered[exoticId] = exoticId

	-- Step 6: Fire remotes to online players.
	if _remoteService then
		local pairs_ = { { openerPlayer, openerData }, { partnerPlayer, partnerData } }
		for _, pair in ipairs(pairs_) do
			local player, data = pair[1], pair[2]
			if player then
				_remoteService.getEvent("BalanceUpdate"):FireClient(
					player,
					data.balances.pellets,
					data.balances.catalysts,
					data.monetization and data.monetization.rushUses or 0,
					data.monetization and data.monetization.timerSkipUses or 0
				)
				_remoteService.getEvent("VaultUpdate"):FireClient(player, data.vault)
			end
		end
	end
end

-- ── Init ───────────────────────────────────────────────────────────────────

function ExoticService.init()
	local DataStoreService = game:GetService("DataStoreService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	_exoticDs = DataStoreService:GetDataStore("Exotics")
	_exotics = require(ReplicatedStorage.Shared.Data.Exotics)
	_economyConstants = require(ReplicatedStorage.Shared.Config.EconomyConstants)
	_rankMath = require(ReplicatedStorage.Shared.Core.RankMath)
	_rankService = require(ServerScriptService.Server.Services.RankService)
	_eventService = require(ServerScriptService.Server.Services.EventService)
	_patentService = require(ServerScriptService.Server.Services.PatentService)
	_vaultService = require(ServerScriptService.Server.Services.VaultService)
	_remoteService = require(ServerScriptService.Server.Services.RemoteService)
	_spawnFn = task.spawn
end

return ExoticService

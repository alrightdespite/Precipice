-- JointSynthService: EMPTY→STAGED→RUNNING→COMPLETE state machine for joint synthesis.
-- No Roblox globals at module level. Injection pattern.
-- DS budget (§DS-01): tick() fires ONE UpdateAsync per active syndicate, not per slot.
-- Worst case: 4 syndicates × 12 ticks/min = 48 writes/min, well inside 140/min budget.

-- ── Injected state ─────────────────────────────────────────────────────────

local _dataService: any = nil
local _syndicateService: any = nil
local _syndicateDs: any = nil
local _profileDs: any = nil
local _vaultService: any = nil
local _patentService: any = nil
local _rankService: any = nil
local _eventService: any = nil
local _exoticService: any = nil
local _recipeResolver: any = nil
local _remoteService: any = nil
local _economyConstants: any = nil
local _compounds: any = nil
local _rankMath: any = nil
local _players: any = nil
local _analyticsService: any = { track = function() end, Events = {} }
local _spawnFn: (((() -> ()) -> ())) = function(fn)
	fn()
end

-- ── Module-level state ─────────────────────────────────────────────────────

local _activeSyndicates: { [string]: boolean } = {}
local _lastTick: { [string]: number } = {}

local JointSynthService = {}

-- ── Injection helpers ──────────────────────────────────────────────────────

function JointSynthService._setDataService(s: any) _dataService = s end
function JointSynthService._setSyndicateService(s: any) _syndicateService = s end
function JointSynthService._setSyndicateDs(s: any) _syndicateDs = s end
function JointSynthService._setProfileDs(s: any) _profileDs = s end
function JointSynthService._setVaultService(s: any) _vaultService = s end
function JointSynthService._setPatentService(s: any) _patentService = s end
function JointSynthService._setRankService(s: any) _rankService = s end
function JointSynthService._setEventService(s: any) _eventService = s end
function JointSynthService._setExoticService(s: any) _exoticService = s end
function JointSynthService._setRecipeResolver(s: any) _recipeResolver = s end
function JointSynthService._setRemoteService(s: any) _remoteService = s end
function JointSynthService._setEconomyConstants(s: any) _economyConstants = s end
function JointSynthService._setCompounds(s: any) _compounds = s end
function JointSynthService._setRankMath(s: any) _rankMath = s end
function JointSynthService._setPlayers(s: any) _players = s end
function JointSynthService._setAnalyticsService(as: any) _analyticsService = as end
function JointSynthService._setSpawnFn(fn: any) _spawnFn = fn end
function JointSynthService._resetActiveSyndicates() _activeSyndicates = {} end
function JointSynthService._resetLastTick() _lastTick = {} end

-- ── Helpers ────────────────────────────────────────────────────────────────

local function isExoticResult(resultId: string?): boolean
	return resultId ~= nil and resultId:sub(1, 3) == "EX_"
end

local function updateSyndicateSlot(syndicateId: string, slotKey: string, slotData: any?)
	_syndicateDs:UpdateAsync("syndicate:" .. syndicateId, function(record)
		if record == nil then return nil end
		record.jointSlots = record.jointSlots or {}
		record.jointSlots[slotKey] = slotData
		return record
	end)
end

local function fireJointSlotUpdate(syndicateId: string, slotKey: string, slotData: any?)
	if not _remoteService then return end
	local record = _syndicateService.getRecord(syndicateId)
	if not record then return end
	local slotIndex = tonumber(slotKey)
	for memberId in pairs(record.members) do
		local p = _players:GetPlayerByUserId(memberId)
		if p then
			_remoteService.getEvent("JointSlotUpdate"):FireClient(p, slotIndex, slotData)
		end
	end
end

local function fireBalanceAndVault(player: any, data: any)
	if not _remoteService or not player then return end
	_remoteService.getEvent("BalanceUpdate"):FireClient(
		player,
		data.balances.pellets,
		data.balances.catalysts,
		data.monetization and data.monetization.rushUses or 0,
		data.monetization and data.monetization.timerSkipUses or 0
	)
	_remoteService.getEvent("VaultUpdate"):FireClient(player, data.vault)
end

-- ── Public API ─────────────────────────────────────────────────────────────

function JointSynthService.stage(
	player: any,
	slotIndex: any,
	myCompound: any,
	partnerCompound: any,
	isAsync: boolean,
	accelerated: boolean
): (boolean, string?)
	local EC = _economyConstants

	-- 1. Must be in a syndicate
	local userId = player.UserId
	local data = _dataService.getProfile(userId)
	if data.syndicate == nil then return false, "not in a syndicate" end

	-- 2. Joint qual required
	if not data.prestige.jointQualLifetime then
		return false, "joint synthesis qualification required"
	end

	-- 3. slotIndex must be 1–3
	if type(slotIndex) ~= "number" or slotIndex < 1 or slotIndex > 3 then
		return false, "invalid slot index"
	end

	-- 4. Compounds must exist and be non-T7
	if type(myCompound) ~= "string" or type(partnerCompound) ~= "string" then
		return false, "invalid compound args"
	end
	if not _compounds[myCompound] then return false, "unknown compound: " .. myCompound end
	if not _compounds[partnerCompound] then return false, "unknown compound: " .. partnerCompound end
	if _recipeResolver.isExoticInput(myCompound) or _recipeResolver.isExoticInput(partnerCompound) then
		return false, "cannot stage T7 compounds"
	end

	-- 5. Pair must be joint-required
	if not _recipeResolver.isJointRequired(myCompound, partnerCompound) then
		return false, "pair is not joint-required"
	end

	-- 6. myCompound must be in vault
	if (data.vault.compounds[myCompound] or 0) < 1 then
		return false, "compound not in vault"
	end

	-- 7. Read syndicate record; validate slot index vs slot count
	local syndicateId = data.syndicate.id
	local record = _syndicateService.getRecord(syndicateId)
	if record == nil then return false, "syndicate not found" end

	local jointSlotCount = if record.upgrades and record.upgrades.thirdSlot then 3 else 2
	if slotIndex > jointSlotCount then return false, "slot not available" end

	-- 8. Slot must be EMPTY
	local slotKey = tostring(slotIndex)
	local existingSlot = record.jointSlots and record.jointSlots[slotKey]
	if existingSlot and existingSlot.state ~= "EMPTY" then
		return false, "slot not empty"
	end

	-- 9. Determine tier pair; handle fee for T4+T5 or T5+T5 undiscovered
	local c1 = _compounds[myCompound]
	local c2 = _compounds[partnerCompound]
	local minTier = math.min(c1.tier, c2.tier)
	local maxTier = math.max(c1.tier, c2.tier)
	local isT6Pair = (minTier == 6 and maxTier == 6)

	if not isT6Pair then
		-- Check if result is already discovered
		local resultId = _recipeResolver.resolve(myCompound, partnerCompound, 0)
		local discovered = resultId and data.formulaLog.discovered[resultId]
		if not discovered then
			-- Charge joint analysis fee
			local fee = if (data.prestige.level or 0) >= 1
				then EC.JOINT_ANALYSIS_FEE_PRESTIGE
				else EC.JOINT_ANALYSIS_FEE
			if data.balances.pellets < fee then
				return false, "insufficient pellets for joint analysis fee"
			end
			data.balances.pellets -= fee
		end
	end

	-- 10. Accelerated: deduct 30 Catalysts
	if accelerated then
		local catalystCost = 30
		if data.balances.catalysts < catalystCost then
			return false, "insufficient catalysts for accelerated run"
		end
		data.balances.catalysts -= catalystCost
	end

	-- 11. Remove myCompound from vault
	_vaultService.applyDeduct(data, myCompound, 1)

	-- 12. Write slot record
	local now = os.time()
	local slotRecord = {
		slotIndex = slotIndex,
		state = "STAGED",
		openerId = userId,
		partnerId = nil,
		openerCompound = myCompound,
		partnerCompound = partnerCompound,
		resultId = nil,
		isNatural = not accelerated,
		isAsync = isAsync,
		stagedAt = now,
		matchedAt = nil,
		workRemaining = nil,
		completedAt = nil,
		expiresAt = if isAsync then now + EC.JOINT_ASYNC_WINDOW_HOURS * 3600 else nil,
	}

	updateSyndicateSlot(syndicateId, slotKey, slotRecord)
	_activeSyndicates[syndicateId] = true

	fireJointSlotUpdate(syndicateId, slotKey, slotRecord)
	fireBalanceAndVault(player, data)

	return true, nil
end

function JointSynthService.contribute(
	player: any,
	slotIndex: any,
	compound: any
): (boolean, string?)
	local userId = player.UserId
	local data = _dataService.getProfile(userId)

	-- 1. Must be in a syndicate
	if data.syndicate == nil then return false, "not in a syndicate" end

	-- 2. Joint qual required
	if not data.prestige.jointQualLifetime then
		return false, "joint synthesis qualification required"
	end

	-- 3. Valid slot index
	if type(slotIndex) ~= "number" or slotIndex < 1 or slotIndex > 3 then
		return false, "invalid slot index"
	end

	-- 4. Valid compound
	if type(compound) ~= "string" then return false, "invalid compound arg" end

	local syndicateId = data.syndicate.id
	local record = _syndicateService.getRecord(syndicateId)
	if record == nil then return false, "syndicate not found" end

	local slotKey = tostring(slotIndex)
	local slot = record.jointSlots and record.jointSlots[slotKey]
	if not slot or slot.state ~= "STAGED" then return false, "slot not STAGED" end

	-- 5. Must NOT be the opener
	if slot.openerId == userId then return false, "opener cannot contribute to own slot" end

	-- 6. Compound must match declared partnerCompound
	if compound ~= slot.partnerCompound then
		return false, "compound does not match declared partner compound"
	end

	-- 7. Compound must be in vault
	if (data.vault.compounds[compound] or 0) < 1 then
		return false, "compound not in vault"
	end

	-- 8. Async expiry check
	local now = os.time()
	if slot.isAsync and slot.expiresAt and slot.expiresAt < now then
		return false, "async staging window has expired"
	end

	-- 9. Resolve resultId
	local resultId: string? = nil
	local c1 = _compounds[slot.openerCompound]
	local c2 = _compounds[slot.partnerCompound]
	if c1 and c2 and c1.tier == 6 and c2.tier == 6 then
		resultId = _recipeResolver.resolveExotic(slot.openerCompound, slot.partnerCompound)
	else
		resultId = _recipeResolver.resolve(slot.openerCompound, slot.partnerCompound, 0)
	end

	-- 10. Compute timer
	local baseSeconds = if slot.isAsync
		then _economyConstants.JOINT_ASYNC_HOURS * 3600
		else _economyConstants.JOINT_SYNC_HOURS * 3600
	local seconds = if slot.isNatural then baseSeconds else math.floor(baseSeconds * 0.75)

	-- 11. Remove partner compound from vault
	_vaultService.applyDeduct(data, compound, 1)

	-- 12. Transition STAGED → RUNNING
	local updatedSlot = {
		slotIndex = slot.slotIndex,
		state = "RUNNING",
		openerId = slot.openerId,
		partnerId = userId,
		openerCompound = slot.openerCompound,
		partnerCompound = compound,
		resultId = resultId,
		isNatural = slot.isNatural,
		isAsync = slot.isAsync,
		stagedAt = slot.stagedAt,
		matchedAt = now,
		workRemaining = seconds,
		completedAt = nil,
		expiresAt = nil,
	}

	updateSyndicateSlot(syndicateId, slotKey, updatedSlot)
	_lastTick[syndicateId] = now

	fireJointSlotUpdate(syndicateId, slotKey, updatedSlot)
	fireBalanceAndVault(player, data)

	return true, nil
end

function JointSynthService.cancel(player: any, slotIndex: any): (boolean, string?)
	local userId = player.UserId
	local data = _dataService.getProfile(userId)

	if data.syndicate == nil then return false, "not in a syndicate" end

	if type(slotIndex) ~= "number" or slotIndex < 1 or slotIndex > 3 then
		return false, "invalid slot index"
	end

	local syndicateId = data.syndicate.id
	local record = _syndicateService.getRecord(syndicateId)
	if record == nil then return false, "syndicate not found" end

	local slotKey = tostring(slotIndex)
	local slot = record.jointSlots and record.jointSlots[slotKey]
	if not slot then return false, "slot is empty" end

	if slot.state == "RUNNING" or slot.state == "COMPLETE" then
		return false, "cannot cancel a running or completed joint run"
	end

	if slot.state ~= "STAGED" then return false, "slot not cancellable" end

	-- Only the opener can cancel a staged slot
	if slot.openerId ~= userId then
		return false, "only the staging member can cancel"
	end

	-- Return opener's compound
	_vaultService.applyAward(data, slot.openerCompound, 1)

	-- Clear slot
	updateSyndicateSlot(syndicateId, slotKey, nil)

	-- Check if any remaining active slots
	local updatedRecord = _syndicateService.getRecord(syndicateId)
	local hasActive = false
	for _, s in pairs(updatedRecord and updatedRecord.jointSlots or {}) do
		if s and (s.state == "STAGED" or s.state == "RUNNING") then
			hasActive = true
			break
		end
	end
	if not hasActive then
		_activeSyndicates[syndicateId] = nil
	end

	fireJointSlotUpdate(syndicateId, slotKey, nil)
	fireBalanceAndVault(player, data)

	return true, nil
end

function JointSynthService.complete(syndicateId: string, slotKey: string, now: number)
	local record = _syndicateService.getRecord(syndicateId)
	if not record then return end

	local slot = record.jointSlots and record.jointSlots[slotKey]
	if not slot or slot.state ~= "RUNNING" then return end

	-- Resolve resultId if still unknown (undiscovered declaration)
	local resultId = slot.resultId
	if not resultId then
		local c1 = _compounds[slot.openerCompound]
		local c2 = _compounds[slot.partnerCompound]
		if c1 and c2 and c1.tier == 6 and c2.tier == 6 then
			resultId = _recipeResolver.resolveExotic(slot.openerCompound, slot.partnerCompound)
		else
			resultId = _recipeResolver.resolve(slot.openerCompound, slot.partnerCompound, 0)
		end
	end

	if not resultId then
		warn("JointSynthService: unresolvable declaration in slot " .. slotKey .. " of " .. syndicateId)
		updateSyndicateSlot(syndicateId, slotKey, nil)
		fireJointSlotUpdate(syndicateId, slotKey, nil)
		return
	end

	local openerId = slot.openerId
	local partnerId = slot.partnerId

	local openerPlayer = _players:GetPlayerByUserId(openerId)
	local partnerPlayer = _players:GetPlayerByUserId(partnerId)

	local openerData = openerPlayer and _dataService.getProfile(openerId)
	local partnerData = partnerPlayer and _dataService.getProfile(partnerId)

	-- Award
	if isExoticResult(resultId) then
		-- T6+T6 → exotic
		if openerData and partnerData then
			_exoticService.onPairCompleted(
				openerPlayer,
				partnerPlayer,
				openerData,
				partnerData,
				resultId,
				slot.isNatural,
				now
			)
		elseif openerData then
			-- Partner offline: award opener, queue for partner
			_vaultService.applyAward(openerData, resultId, 1)
			openerData.formulaLog.discovered[resultId] = resultId
			if _profileDs then
				_profileDs:UpdateAsync("Player_" .. tostring(partnerId), function(stored)
					if stored then
						stored.pendingJointResults = stored.pendingJointResults or {}
						table.insert(stored.pendingJointResults, {
							resultId = resultId,
							isNatural = slot.isNatural,
						})
					end
					return stored
				end)
			end
		end
	else
		-- T4+T5 or T5+T5 → T6 compound
		local compound = _compounds[resultId]
		local tier = compound and compound.tier or 6

		local function awardMember(memberPlayer: any, memberData: any, memberId: number)
			if memberData then
				_vaultService.applyAward(memberData, resultId, 1)
				memberData.formulaLog.discovered[resultId] = resultId
				if slot.isNatural and _rankService and _rankMath then
					local points = _rankMath.scoreForCompletion(tier)
					_rankService.addScore(memberPlayer, memberData, points, "synthesis")
					_rankService.addSprintPoints(memberPlayer, memberData, points, now)
					if _eventService then
						_eventService.awardFlux(memberPlayer, memberData, "synthesis", tier, now)
					end
					if _patentService then
						_patentService.recordNaturalSynthesis(memberPlayer, resultId, memberData, now)
					end
				end
			elseif _profileDs then
				_profileDs:UpdateAsync("Player_" .. tostring(memberId), function(stored)
					stored = stored or {}
					stored.pendingJointResults = stored.pendingJointResults or {}
					table.insert(stored.pendingJointResults, {
						resultId = resultId,
						isNatural = slot.isNatural,
					})
					return stored
				end)
			end
		end

		awardMember(openerPlayer, openerData, openerId)
		awardMember(partnerPlayer, partnerData, partnerId)
	end

	_analyticsService.track(_analyticsService.Events.JOINT_COMPLETE or "joint_complete", {
		syndicateId = syndicateId,
		resultId = resultId,
		openerId = openerId,
		partnerId = partnerId,
	})

	-- Clear slot
	updateSyndicateSlot(syndicateId, slotKey, nil)

	-- Fire remotes
	if openerData then fireBalanceAndVault(openerPlayer, openerData) end
	if partnerData then fireBalanceAndVault(partnerPlayer, partnerData) end
	fireJointSlotUpdate(syndicateId, slotKey, nil)

	-- Check if syndicate still has active slots
	local updatedRecord = _syndicateService.getRecord(syndicateId)
	local hasActive = false
	for _, s in pairs(updatedRecord and updatedRecord.jointSlots or {}) do
		if s and (s.state == "STAGED" or s.state == "RUNNING") then
			hasActive = true
			break
		end
	end
	if not hasActive then
		_activeSyndicates[syndicateId] = nil
	end
end

function JointSynthService.tick(syndicateId: string, now: number)
	local record = _syndicateService.getRecord(syndicateId)
	if not record then
		_activeSyndicates[syndicateId] = nil
		return
	end

	local lastTick = _lastTick[syndicateId] or now
	local elapsed = math.max(0, now - lastTick)
	_lastTick[syndicateId] = now

	if elapsed <= 0 then return end

	local hasActive = false
	local completingSlots: { string } = {}
	local hasStillRunning = false

	for slotKey, slot in pairs(record.jointSlots or {}) do
		if slot and slot.state == "RUNNING" then
			hasActive = true
			if slot.workRemaining - elapsed <= 0 then
				table.insert(completingSlots, slotKey)
			else
				hasStillRunning = true
			end
		elseif slot and slot.state == "STAGED" then
			hasActive = true
		end
	end

	-- §DS-01: one UpdateAsync per syndicate covers ALL still-running slots.
	-- Previously this was one write per slot (N_slots writes); now N_syndicates writes.
	if hasStillRunning then
		_syndicateDs:UpdateAsync("syndicate:" .. syndicateId, function(rec)
			if rec == nil then return nil end
			for _, slot in pairs(rec.jointSlots or {}) do
				if slot and slot.state == "RUNNING" then
					local newWork = slot.workRemaining - elapsed
					if newWork > 0 then
						slot.workRemaining = newWork
					end
				end
			end
			return rec
		end)
	end

	for _, slotKey in ipairs(completingSlots) do
		JointSynthService.complete(syndicateId, slotKey, now)
	end

	if not hasActive then
		_activeSyndicates[syndicateId] = nil
	end
end

function JointSynthService.checkAsyncExpiries(now: number)
	for syndicateId in pairs(_activeSyndicates) do
		local record = _syndicateService.getRecord(syndicateId)
		if not record then continue end

		for slotKey, slot in pairs(record.jointSlots or {}) do
			if slot and slot.state == "STAGED" and slot.isAsync then
				if slot.expiresAt and slot.expiresAt < now then
					-- Return opener's compound
					local openerPlayer = _players:GetPlayerByUserId(slot.openerId)
					local openerData = openerPlayer and _dataService.getProfile(slot.openerId)
					if openerData then
						_vaultService.applyAward(openerData, slot.openerCompound, 1)
					end

					-- Set cooldown on opener in syndicate record
					_syndicateDs:UpdateAsync("syndicate:" .. syndicateId, function(rec)
						if rec == nil then return nil end
						rec.asyncCooldowns = rec.asyncCooldowns or {}
						rec.asyncCooldowns[tostring(slot.openerId)] =
							now + _economyConstants.JOINT_ASYNC_COOLDOWN_HOURS * 3600
						rec.jointSlots = rec.jointSlots or {}
						rec.jointSlots[slotKey] = nil
						return rec
					end)

					if openerData then fireBalanceAndVault(openerPlayer, openerData) end
					fireJointSlotUpdate(syndicateId, slotKey, nil)
				end
			end
		end
	end
end

function JointSynthService.onLogin(player: any, data: any, _now: number)
	if not data.pendingJointResults or #data.pendingJointResults == 0 then return end
	for _, entry in ipairs(data.pendingJointResults) do
		_vaultService.applyAward(data, entry.resultId, 1)
	end
	data.pendingJointResults = {}
	if _remoteService then
		_remoteService.getEvent("VaultUpdate"):FireClient(player, data.vault)
	end
end

-- Returns virtual slot inputs for SlotService offline income settlement.
function JointSynthService.getRunningSlotInputs(
	syndicateId: string,
	userId: number,
	_now: number
): { { tier: number, workRemainingSeconds: number, passivePerMin: number } }
	local results: { { tier: number, workRemainingSeconds: number, passivePerMin: number } } = {}
	local record = _syndicateService.getRecord(syndicateId)
	if not record then return results end

	for _, slot in pairs(record.jointSlots or {}) do
		if slot
			and slot.state == "RUNNING"
			and (slot.openerId == userId or slot.partnerId == userId)
		then
			local tier = 6
			local passivePerMin = 0
			if slot.resultId then
				if isExoticResult(slot.resultId) then
					tier = 7
					passivePerMin = 0
				else
					local compound = _compounds[slot.resultId]
					if compound then
						tier = compound.tier
						passivePerMin = compound.passivePerMin
					end
				end
			end
			table.insert(results, {
				tier = tier,
				workRemainingSeconds = slot.workRemaining or 0,
				passivePerMin = passivePerMin,
			})
		end
	end

	return results
end

-- ── Init ───────────────────────────────────────────────────────────────────

function JointSynthService.init()
	local DataStoreService = game:GetService("DataStoreService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	_dataService = require(ServerScriptService.Server.Services.DataService)
	_syndicateService = require(ServerScriptService.Server.Services.SyndicateService)
	_syndicateDs = DataStoreService:GetDataStore("Syndicates")
	_profileDs = DataStoreService:GetDataStore("PlayerData_v1")
	_vaultService = require(ServerScriptService.Server.Services.VaultService)
	_patentService = require(ServerScriptService.Server.Services.PatentService)
	_rankService = require(ServerScriptService.Server.Services.RankService)
	_eventService = require(ServerScriptService.Server.Services.EventService)
	_remoteService = require(ServerScriptService.Server.Services.RemoteService)
	_economyConstants = require(ReplicatedStorage.Shared.Config.EconomyConstants)
	_recipeResolver = require(ReplicatedStorage.Shared.Core.RecipeResolver)
	_rankMath = require(ReplicatedStorage.Shared.Core.RankMath)
	_compounds = require(ReplicatedStorage.Shared.Data.Compounds)
	_players = game:GetService("Players")
	_analyticsService = require(ServerScriptService.Server.Services.AnalyticsService)
	_spawnFn = task.spawn

	local rs = _remoteService

	rs.getFunction("JointStage").OnServerInvoke = function(player, slotIndex, myCompound, partnerCompound, async, accelerated)
		if not _dataService.isLoaded(player.UserId) then return false, "session not ready" end
		return JointSynthService.stage(player, slotIndex, myCompound, partnerCompound, async, accelerated)
	end

	rs.getFunction("JointContribute").OnServerInvoke = function(player, slotIndex, compound)
		if not _dataService.isLoaded(player.UserId) then return false, "session not ready" end
		return JointSynthService.contribute(player, slotIndex, compound)
	end

	rs.getFunction("JointCancel").OnServerInvoke = function(player, slotIndex)
		if not _dataService.isLoaded(player.UserId) then return false, "session not ready" end
		return JointSynthService.cancel(player, slotIndex)
	end

	-- Tick loop
	_spawnFn(function()
		while true do
			task.wait(5)
			local now = os.time()
			local ok, err = pcall(JointSynthService.checkAsyncExpiries, now)
			if not ok then
				warn("JointSynthService.checkAsyncExpiries error:", err)
			end
			for syndicateId in pairs(_activeSyndicates) do
				local ok2, err2 = pcall(JointSynthService.tick, syndicateId, now)
				if not ok2 then
					warn("JointSynthService.tick error for", syndicateId, ":", err2)
				end
			end
		end
	end)
end

return JointSynthService

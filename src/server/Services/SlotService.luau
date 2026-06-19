-- SlotService: wires SlotMachine to DataService, remotes, and heartbeat.
-- Handles offline income settlement on join and real-time tick while online.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(ServerScriptService.Server.Services.DataService)
local RemoteService = require(ServerScriptService.Server.Services.RemoteService)
local SeedService = require(ServerScriptService.Server.Services.SeedService)
local VaultService = require(ServerScriptService.Server.Services.VaultService)
local PatentService = require(ServerScriptService.Server.Services.PatentService)
local RankService = require(ServerScriptService.Server.Services.RankService)
local ContractService = require(ServerScriptService.Server.Services.ContractService)
local MonetizationService = require(ServerScriptService.Server.Services.MonetizationService)
local SlotMachine = require(ReplicatedStorage.Shared.Core.SlotMachine)
local OfflineIncome = require(ReplicatedStorage.Shared.Core.OfflineIncome)
local RecipeResolver = require(ReplicatedStorage.Shared.Core.RecipeResolver)
local Compounds = require(ReplicatedStorage.Shared.Data.Compounds)
local EventCompounds = require(ReplicatedStorage.Shared.Data.EventCompounds)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local AnalyticsService = require(ServerScriptService.Server.Services.AnalyticsService)

local OFFLINE_RATE = 0.8 -- E1: offline work rate
local TICK_INTERVAL = 1 -- seconds between server ticks

local _loaded: { [number]: boolean } = {} -- userIds with active, ready sessions
local _tickAccum = 0
local _eventService: any = nil
local _jointService: any = nil

local SlotService = {}

function SlotService._setEventService(es: any)
	_eventService = es
end

function SlotService._setJointService(js: any)
	_jointService = js
end

-- ── Helpers ────────────────────────────────────────────────────────────────

local function getSlotCap(data: any): number
	return MonetizationService.getSlotCap(data)
end

local function toClientSlot(raw: any): any
	local state
	if raw.workRemaining and raw.workRemaining > 0 then
		state = "RUNNING"
	elseif raw.workRemaining == 0 then
		state = "DONE"
	else
		state = "EMPTY"
	end
	return {
		index = raw.index,
		state = state,
		compoundId = raw.compoundId,
		workRemaining = raw.workRemaining,
		lastTickAt = raw.lastTickAt,
		mode = raw.mode,
		isActive = true,
	}
end

local function fireSlotUpdate(player: Player, slot: any)
	RemoteService.getEvent("SlotStateUpdate"):FireClient(player, slot.index, toClientSlot(slot))
end

local function fireSlotCleared(player: Player, slotIndex: number)
	RemoteService.getEvent("SlotStateUpdate"):FireClient(player, slotIndex, nil)
end

-- ── Offline settlement (§10) ───────────────────────────────────────────────

local function settleOfflineForPlayer(userId: number)
	local offlineResult = nil

	DataService.updateProfile(userId, function(data)
		local now = os.time()
		local lastSeenAt = data.lastSeenAt or 0
		local offlineSeconds = math.max(0, now - lastSeenAt)
		local capSeconds = MonetizationService.getOfflineCap(data) * 3600

		data.lastSeenAt = now

		if offlineSeconds <= 0 or #data.slots == 0 then
			return
		end

		local effectiveCap = math.min(offlineSeconds, capSeconds)

		-- Convert SlotRecords → SlotInputs for OfflineIncome.settle
		local slotInputs = {}
		for _, slot in ipairs(data.slots) do
			local compound = Compounds[slot.compoundId]
			if compound and slot.workRemaining > 0 then
				table.insert(slotInputs, {
					tier = compound.tier,
					-- work units → real seconds at offline rate
					workRemainingSeconds = slot.workRemaining / OFFLINE_RATE,
					passivePerMin = compound.passivePerMin,
				})
			end
		end

		-- Add running joint synthesis slots as virtual slot inputs (§17, §10)
		if _jointService and data.syndicate then
			local jointInputs = _jointService.getRunningSlotInputs(
				data.syndicate.id,
				userId,
				now
			)
			for _, ji in ipairs(jointInputs) do
				table.insert(slotInputs, ji)
			end
		end

		local multiplier = if _eventService then _eventService.getIncomeMultiplier(data) else 1.0
		local result = OfflineIncome.settle(slotInputs, offlineSeconds, capSeconds, multiplier)
		data.balances.pellets += result.total

		-- Apply offline work-unit drain; award compounds that completed offline
		local newSlots = {}
		for _, slot in ipairs(data.slots) do
			if slot.workRemaining > 0 then
				local workDone = math.min(slot.workRemaining, effectiveCap * OFFLINE_RATE)
				local newWork = math.max(0, slot.workRemaining - workDone)
				if newWork <= 0 then
					VaultService.applyAward(data, slot.compoundId, 1)
				else
					table.insert(newSlots, {
						index = slot.index,
						kind = slot.kind,
						compoundId = slot.compoundId,
						workRemaining = newWork,
						lastTickAt = now,
						mode = "online",
						isStabilized = slot.isStabilized,
						isNatural = slot.isNatural,
						startedAt = slot.startedAt,
					})
				end
			end
		end
		data.slots = newSlots

		if result.total > 0 then
			offlineResult = result
		end
	end)

	-- Fire remotes outside updateProfile
	local player = Players:GetPlayerByUserId(userId)
	if player then
		if offlineResult then
			RemoteService.getEvent("OfflineIncomeDelivered"):FireClient(
				player,
				offlineResult.total,
				offlineResult.breakdown
			)
		end
		local data = DataService.getProfile(userId)
		-- Push vault state (may include compounds awarded offline)
		VaultService.fireVaultUpdate(player, data)
		-- Push current slot state to client
		for _, slot in ipairs(data.slots) do
			fireSlotUpdate(player, slot)
		end
	end
end

-- ── Remote handlers ────────────────────────────────────────────────────────

local function wireRemotes()
	-- SlotStartExtraction ── auto-picks first free slot
	local startExtractionFn = RemoteService.getFunction("SlotStartExtraction")
	startExtractionFn.OnServerInvoke = function(player: Player, compoundId: any)
		if type(compoundId) ~= "string" then
			return false, "invalid args"
		end
		local userId = player.UserId
		if not _loaded[userId] then
			return false, "session not ready"
		end

		local newSlotRecord = nil
		local failErr = nil

		DataService.updateProfile(userId, function(data)
			local compoundEntry = Compounds[compoundId]
			if not compoundEntry then
				failErr = "unknown compound"
				return
			end
			if not compoundEntry.starter and not data.formulaLog.discovered[compoundId] then
				failErr = "compound not discovered"
				return
			end
			local cap = getSlotCap(data)
			local compound = compoundEntry
			local newSlots, slotIdx, slotErr =
				SlotMachine.startExtraction(data.slots, compoundId, compound.timeMins * 60, os.time(), cap)
			if slotErr then
				failErr = slotErr
				return
			end
			data.slots = newSlots
			for _, s in ipairs(newSlots) do
				if s.index == slotIdx then
					newSlotRecord = s
					break
				end
			end
		end)

		if failErr then
			return false, failErr
		end
		if newSlotRecord then
			fireSlotUpdate(player, newSlotRecord)
		end
		return true, nil
	end

	-- SlotStartSynthesis ── player specifies slot index
	local startSynthesisFn = RemoteService.getFunction("SlotStartSynthesis")
	startSynthesisFn.OnServerInvoke = function(
		player: Player,
		slotIndex: any,
		input1: any,
		input2: any,
		stabilized: any
	)
		if
			type(slotIndex) ~= "number"
			or type(input1) ~= "string"
			or type(input2) ~= "string"
			or type(stabilized) ~= "boolean"
		then
			return false, "invalid args"
		end
		slotIndex = math.floor(slotIndex)
		local userId = player.UserId
		if not _loaded[userId] then
			return false, "session not ready"
		end

		local newSlotRecord = nil
		local failErr = nil

		DataService.updateProfile(userId, function(data)
			-- Joint recipes must go through JointSynthService
			if RecipeResolver.isJointRequired(input1, input2) then
				failErr = "joint synthesis required"
				return
			end

			local weekSeed = SeedService.getCurrentWeekSeed()
			local resultId = RecipeResolver.resolve(input1, input2, weekSeed)
			if not resultId then
				failErr = "no recipe for these inputs"
				return
			end

			if not data.formulaLog.discovered[resultId] then
				failErr = "recipe not discovered"
				return
			end

			-- Event compound blueprint gate (§4 hardening)
			if EventCompounds[resultId] then
				local blueprints = data.blueprints or {}
				if not blueprints[resultId] then
					failErr = "NO_BLUEPRINT"
					return
				end
			end

			-- Deduct inputs from vault (handles same-compound case)
			local required: { [string]: number } = {}
			required[input1] = (required[input1] or 0) + 1
			required[input2] = (required[input2] or 0) + 1
			for cid, qty in pairs(required) do
				if (data.vault.compounds[cid] or 0) < qty then
					failErr = "insufficient " .. cid
					return
				end
			end
			for cid, qty in pairs(required) do
				VaultService.applyDeduct(data, cid, qty)
			end

			local resultCompound = Compounds[resultId]
			if not resultCompound then
				failErr = "unknown result compound"
				return
			end
			local newSlots, slotErr = SlotMachine.startSynthesis(
				data.slots,
				resultId,
				resultCompound.timeMins * 60,
				stabilized,
				slotIndex,
				os.time(),
				getSlotCap(data)
			)
			if slotErr then
				-- Refund inputs if slot setup failed
				for cid, qty in pairs(required) do
					VaultService.applyAward(data, cid, qty)
				end
				failErr = slotErr
				return
			end

			data.slots = newSlots
			for _, s in ipairs(newSlots) do
				if s.index == slotIndex then
					newSlotRecord = s
					break
				end
			end
		end)

		if failErr then
			return false, failErr
		end
		-- Vault changed (inputs consumed); push update
		VaultService.fireVaultUpdate(player, DataService.getProfile(userId))
		if newSlotRecord then
			fireSlotUpdate(player, newSlotRecord)
		end
		return true, nil
	end

	-- SlotCancel ── removes slot, no reward
	local cancelFn = RemoteService.getFunction("SlotCancel")
	cancelFn.OnServerInvoke = function(player: Player, slotIndex: any)
		if type(slotIndex) ~= "number" then
			return false, "invalid args"
		end
		slotIndex = math.floor(slotIndex)
		local userId = player.UserId
		if not _loaded[userId] then
			return false, "session not ready"
		end

		local failErr = nil
		DataService.updateProfile(userId, function(data)
			local newSlots, slotErr = SlotMachine.cancel(data.slots, slotIndex)
			if slotErr then
				failErr = slotErr
				return
			end
			data.slots = newSlots
		end)

		if failErr then
			return false, failErr
		end
		fireSlotCleared(player, slotIndex)
		return true, nil
	end

	-- SlotReveal ── awards compound, scores natural (§14)
	local revealFn = RemoteService.getFunction("SlotReveal")
	revealFn.OnServerInvoke = function(player: Player, slotIndex: any)
		if type(slotIndex) ~= "number" then
			return nil, "invalid args"
		end
		slotIndex = math.floor(slotIndex)
		local userId = player.UserId
		if not _loaded[userId] then
			return nil, "session not ready"
		end

		local awardedId = nil
		local isNatural = false
		local isPatentClaim = false
		local failErr = nil

		DataService.updateProfile(userId, function(data)
			local newSlots, compoundId, nat, slotErr =
				SlotMachine.reveal(data.slots, slotIndex, os.time())
			if slotErr then
				failErr = slotErr
				return
			end
			data.slots = newSlots
			VaultService.applyAward(data, compoundId, 1)
			awardedId = compoundId
			isNatural = nat
			if isNatural then
				RankService.scoreNaturalCompletion(player, data, compoundId, os.time())
				-- Grant T4 joint qualification on first natural T4+ completion (§17)
				local compound = Compounds[compoundId]
				if compound and compound.tier >= 4 and not data.prestige.jointQualLifetime then
					data.prestige.jointQualLifetime = true
				end
				if _eventService then
					local fluxSource = if compound and compound.tier == 1 then "extraction" else "synthesis"
					_eventService.awardFlux(player, data, fluxSource, compound and compound.tier, os.time())
				end
				AnalyticsService.track(AnalyticsService.Events.SYNTHESIS_NATURAL, {
					userId = player.UserId,
					compoundId = compoundId,
					tier = Compounds[compoundId] and Compounds[compoundId].tier or 0,
				})
			end
			-- §14: only natural completions count toward patents. Skipped runs
			-- (isNatural == false) are delivered but never claim a patent.
			if isNatural and Compounds[compoundId] and Compounds[compoundId].tier >= 2 then
				isPatentClaim = PatentService.recordNaturalSynthesis(player, compoundId, data) == true
			end
			-- Contract progress counts for all reveals (natural and non-natural per §19)
			local revealTier = Compounds[compoundId] and Compounds[compoundId].tier or 0
			ContractService.recordProgress(player, data, "synthesis_t" .. revealTier, 1)
		end)

		if failErr then
			return nil, failErr
		end
		VaultService.fireVaultUpdate(player, DataService.getProfile(userId))
		fireSlotCleared(player, slotIndex)
		return { compoundId = awardedId, isNatural = isNatural, isPatent = isPatentClaim }, nil
	end

	-- SlotSkip ── marks non-natural, drains slot (§14)
	local skipFn = RemoteService.getFunction("SlotSkip")
	skipFn.OnServerInvoke = function(player: Player, slotIndex: any, skipType: any)
		if type(slotIndex) ~= "number" or type(skipType) ~= "string" then
			return false, "invalid args"
		end
		slotIndex = math.floor(slotIndex)
		if skipType ~= "catalyst" and skipType ~= "timerskip" then
			return false, "invalid skip type"
		end
		local userId = player.UserId
		if not _loaded[userId] then
			return false, "session not ready"
		end

		local newSlotRecord = nil
		local failErr = nil

		DataService.updateProfile(userId, function(data)
			-- Deduct skip cost (Phase 8)
			if skipType == "catalyst" then
				local ok = MonetizationService.deductCatalystSkip(data)
				if not ok then
					failErr = "insufficient Catalysts (need 30)"
					return
				end
			elseif skipType == "timerskip" then
				local uses = data.monetization.timerSkipUses or 0
				if uses <= 0 then
					failErr = "no TimerSkip uses available"
					return
				end
				data.monetization.timerSkipUses = uses - 1
			end

			-- Find compoundId before skip for contract progress
			local skipCompoundId = nil
			for _, s in ipairs(data.slots) do
				if s.index == slotIndex then
					skipCompoundId = s.compoundId
					break
				end
			end
			local newSlots, slotErr = SlotMachine.skip(data.slots, slotIndex, os.time())
			if slotErr then
				failErr = slotErr
				return
			end
			data.slots = newSlots
			for _, s in ipairs(newSlots) do
				if s.index == slotIndex then
					newSlotRecord = s
					break
				end
			end
			-- Skipped runs count toward contracts per §19 (not rank/patents/sprint)
			if skipCompoundId then
				local skipCompound = Compounds[skipCompoundId]
				if skipCompound then
					ContractService.recordProgress(
						player,
						data,
						"synthesis_t" .. skipCompound.tier,
						1
					)
				end
			end
		end)

		if failErr then
			return false, failErr
		end
		if newSlotRecord then
			fireSlotUpdate(player, newSlotRecord)
		end
		AnalyticsService.track(AnalyticsService.Events.SYNTHESIS_SKIP, {
			userId = userId,
			skipType = skipType,
			slotIndex = slotIndex,
		})
		local skipData = DataService.getProfile(userId)
		RemoteService.getEvent("BalanceUpdate"):FireClient(
			player,
			skipData.balances.pellets,
			skipData.balances.catalysts,
			skipData.monetization.rushUses,
			skipData.monetization.timerSkipUses or 0
		)
		return true, nil
	end
end

-- ── Heartbeat tick ─────────────────────────────────────────────────────────

local function runTick()
	local now = os.time()
	for _, player in ipairs(Players:GetPlayers()) do
		local userId = player.UserId
		if not _loaded[userId] then
			continue
		end
		local ok, err = pcall(function()
			local data = DataService.getProfile(userId)
			if #data.slots == 0 then
				return
			end
			local newSlots, completedIndices = SlotMachine.tick(data.slots, now)
			data.slots = newSlots

			-- Notify client: running slots (countdown) + newly completed slots
			local justCompleted: { [number]: boolean } = {}
			for _, idx in ipairs(completedIndices) do
				justCompleted[idx] = true
			end
			local event = RemoteService.getEvent("SlotStateUpdate")
			for _, slot in ipairs(newSlots) do
				if slot.workRemaining > 0 or justCompleted[slot.index] then
					event:FireClient(player, slot.index, toClientSlot(slot))
				end
			end
		end)
		if not ok then
			warn("SlotService: tick error for", userId, "—", err)
		end
	end
end

-- ── Public: applySkipToSlot (called by MonetizationService.applyTimerSkip) ──

function SlotService.applySkipToSlot(player: Player, slotIndex: number)
	local userId = player.UserId
	local newSlotRecord = nil
	DataService.updateProfile(userId, function(data)
		local newSlots, slotErr = SlotMachine.skip(data.slots, slotIndex, os.time())
		if slotErr then
			warn("SlotService.applySkipToSlot: skip error for slot", slotIndex, "—", slotErr)
			return
		end
		data.slots = newSlots
		for _, s in ipairs(newSlots) do
			if s.index == slotIndex then
				newSlotRecord = s
				break
			end
		end
	end)
	if newSlotRecord then
		RemoteService.getEvent("SlotStateUpdate"):FireClient(player, newSlotRecord.index, toClientSlot(newSlotRecord))
	end
end

-- ── Init ───────────────────────────────────────────────────────────────────

-- Pushes the player's current personal slot cap (§8) so the UI renders the
-- correct number of slot cards. Re-fired on gamepass/prestige changes.
function SlotService.fireSlotCap(player: Player, data: any)
	RemoteService.getEvent("SlotCapUpdate"):FireClient(player, getSlotCap(data))
end

-- Studio/debug only (called by DebugService): drains a running slot to natural
-- completion. Unlike a catalyst/TimerSkip skip, isNatural is preserved, so the
-- run still counts toward patents/Sprint/rank — lets us test the full natural
-- pipeline without waiting out real timers. Not a player code path.
function SlotService.forceCompleteSlot(player: Player, slotIndex: number): boolean
	local userId = player.UserId
	if not _loaded[userId] then
		return false
	end
	local completed = nil
	DataService.updateProfile(userId, function(data)
		for _, s in ipairs(data.slots) do
			if s.index == slotIndex and s.workRemaining > 0 then
				s.workRemaining = 0
				s.lastTickAt = os.time()
				completed = s
				break
			end
		end
	end)
	if completed then
		fireSlotUpdate(player, completed)
		return true
	end
	return false
end

function SlotService.init()
	DataService.onProfileLoaded:Connect(function(userId)
		_loaded[userId] = true
		task.spawn(settleOfflineForPlayer, userId)
		local player = Players:GetPlayerByUserId(userId)
		if player then
			SlotService.fireSlotCap(player, DataService.getProfile(userId))
		end
	end)

	DataService.onProfileReleased:Connect(function(userId)
		_loaded[userId] = nil
	end)

	-- Stamp lastSeenAt before session closes so next offline settle is accurate.
	-- Fires before GameInit's PlayerRemoving → DataService.closeSession because
	-- SlotService.init() runs before GameInit connects PlayerRemoving.
	Players.PlayerRemoving:Connect(function(player)
		local userId = player.UserId
		if not _loaded[userId] then
			return
		end
		local ok, err = pcall(DataService.updateProfile, userId, function(data)
			data.lastSeenAt = os.time()
		end)
		if not ok then
			warn("SlotService: lastSeenAt update failed for", userId, "—", err)
		end
	end)

	wireRemotes()

	RunService.Heartbeat:Connect(function(dt)
		_tickAccum += dt
		if _tickAccum < TICK_INTERVAL then
			return
		end
		_tickAccum -= TICK_INTERVAL
		runTick()
	end)
end

return SlotService

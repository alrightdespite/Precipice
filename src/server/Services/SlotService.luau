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
local SlotMachine = require(ReplicatedStorage.Shared.Core.SlotMachine)
local OfflineIncome = require(ReplicatedStorage.Shared.Core.OfflineIncome)
local RecipeResolver = require(ReplicatedStorage.Shared.Core.RecipeResolver)
local Compounds = require(ReplicatedStorage.Shared.Data.Compounds)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local OFFLINE_RATE = 0.8 -- E1: offline work rate
local TICK_INTERVAL = 1 -- seconds between server ticks

local _loaded: { [number]: boolean } = {} -- userIds with active, ready sessions
local _tickAccum = 0

local SlotService = {}

-- ── Helpers ────────────────────────────────────────────────────────────────

local function getSlotCap(_data: any): number
	-- TODO Phase 11: add gamepass slot expansion (MonetizationService)
	return GameConfig.BASE_SLOTS
end

local function fireSlotUpdate(player: Player, slot: any)
	RemoteService.getEvent("SlotStateUpdate"):FireClient(player, slot.index, slot)
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
		local capSeconds = GameConfig.OFFLINE_CAP_BASE_HOURS * 3600
		-- TODO Phase 11: extended cap for gamepass holders

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

		local result = OfflineIncome.settle(slotInputs, offlineSeconds, capSeconds)
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
			if not data.formulaLog.discovered[compoundId] then
				failErr = "compound not discovered"
				return
			end
			local cap = getSlotCap(data)
			local compound = Compounds[compoundId]
			if not compound then
				failErr = "unknown compound"
				return
			end
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
			-- TODO Phase 6: RankService.scoreNaturalCompletion(userId, compoundId)
			PatentService.recordNaturalSynthesis(player, compoundId, data)
			-- TODO Session B: ContractService.recordProgress(player, data, "synthesis_t" .. Compounds[compoundId].tier, 1)
		end)

		if failErr then
			return nil, failErr
		end
		VaultService.fireVaultUpdate(player, DataService.getProfile(userId))
		fireSlotCleared(player, slotIndex)
		return { compoundId = awardedId, isNatural = isNatural }, nil
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
			-- TODO Phase 11: validate and deduct cost (MonetizationService)
			-- TODO Session B: ContractService.recordProgress(player, data, "synthesis_t" .. Compounds[slot.compoundId].tier, 1)
			-- Note: skipped runs count toward contracts (doc §19) but not patents/rank/sprint.
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
		end)

		if failErr then
			return false, failErr
		end
		if newSlotRecord then
			fireSlotUpdate(player, newSlotRecord)
		end
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
					event:FireClient(player, slot.index, slot)
				end
			end
		end)
		if not ok then
			warn("SlotService: tick error for", userId, "—", err)
		end
	end
end

-- ── Init ───────────────────────────────────────────────────────────────────

function SlotService.init()
	DataService.onProfileLoaded:Connect(function(userId)
		_loaded[userId] = true
		task.spawn(settleOfflineForPlayer, userId)
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

-- Centralizes all remote wiring and S2C dispatch.
-- Resolves remotes from ReplicatedStorage.Remotes (created by server RemoteService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Manifest = require(ReplicatedStorage.Shared.Remotes.Manifest)
local StateController = require(script.Parent.StateController)

local _remotes: { [string]: RemoteEvent | RemoteFunction } = {}

local RemoteController = {}

-- pcall-wrapped InvokeServer. Returns the server's return values, or (false, errorString).
function RemoteController.invoke(name: string, ...: any): ...any
	local remote = _remotes[name] :: RemoteFunction
	if not remote then
		warn("[RemoteController] invoke: unknown remote:", name)
		return false, "REMOTE_NOT_FOUND"
	end
	local results = table.pack(pcall(remote.InvokeServer, remote, ...))
	if not results[1] then
		warn("[RemoteController] invoke error:", name, results[2])
		return false, tostring(results[2])
	end
	return table.unpack(results, 2, results.n)
end

-- Connect a callback to an S2C RemoteEvent.
function RemoteController.connect(name: string, callback: (...any) -> ()): RBXScriptConnection
	local remote = _remotes[name] :: RemoteEvent
	assert(remote, "[RemoteController] connect: unknown remote: " .. tostring(name))
	return remote.OnClientEvent:Connect(callback)
end

local function wireS2C()
	-- SlotStateUpdate: update one slot by index
	_remotes["SlotStateUpdate"].OnClientEvent:Connect(function(slotIndex: number, slotData: any)
		local slots = table.clone(StateController.get().slots)
		slots[slotIndex] = slotData
		StateController.set({ slots = slots })
	end)

	-- VaultUpdate
	_remotes["VaultUpdate"].OnClientEvent:Connect(function(vaultSnapshot: any)
		StateController.set({ vault = vaultSnapshot })
	end)

	-- BalanceUpdate
	_remotes["BalanceUpdate"].OnClientEvent:Connect(function(pellets, catalysts, rushUses, timerSkipUses)
		StateController.set({
			balance = {
				pellets = pellets,
				catalysts = catalysts,
				rushUses = rushUses,
				timerSkipUses = timerSkipUses,
			},
		})
	end)

	-- OfflineIncomeDelivered
	_remotes["OfflineIncomeDelivered"].OnClientEvent:Connect(function(amount: number, breakdown: any)
		StateController.set({ offlineIncome = { amount = amount, breakdown = breakdown } })
	end)

	-- SlotCapUpdate: personal slot count (§8) + current prestige level (§22)
	_remotes["SlotCapUpdate"].OnClientEvent:Connect(function(slotCap: number, prestigeLevel: number?)
		StateController.set({ slotCap = slotCap, prestige = { level = prestigeLevel or 0 } })
	end)

	-- LabDiscovery: append entry to formulaLog
	_remotes["LabDiscovery"].OnClientEvent:Connect(function(compoundId: string, recipeId: string)
		local log = table.clone(StateController.get().formulaLog)
		table.insert(log, { compoundId = compoundId, recipeId = recipeId, discoveredAt = os.time() })
		StateController.set({ formulaLog = log })
	end)

	-- PatentClaim
	_remotes["PatentClaim"].OnClientEvent:Connect(function(compoundId: string, claimantId: number, _isWorldFirst: boolean)
		local patents = table.clone(StateController.get().patents)
		local existing = patents[compoundId] or {}
		patents[compoundId] = {
			compoundId = compoundId,
			holderId = claimantId,
			holderCount = (existing.holderCount or 0) + 1,
			challengerId = existing.challengerId,
			challengerCount = existing.challengerCount or 0,
			windowEnd = existing.windowEnd,
			state = "HELD",
		}
		StateController.set({ patents = patents })
	end)

	-- PatentChallengeAlert: update windowEnd on existing record
	_remotes["PatentChallengeAlert"].OnClientEvent:Connect(function(compoundId: string, windowEnd: number)
		local patents = table.clone(StateController.get().patents)
		if patents[compoundId] then
			patents[compoundId] = table.clone(patents[compoundId])
			patents[compoundId].windowEnd = windowEnd
		end
		StateController.set({ patents = patents })
	end)

	-- PatentChallenged
	_remotes["PatentChallenged"].OnClientEvent:Connect(function(compoundId: string, challengerId: number)
		local patents = table.clone(StateController.get().patents)
		if patents[compoundId] then
			patents[compoundId] = table.clone(patents[compoundId])
			patents[compoundId].state = "CHALLENGED"
			patents[compoundId].challengerId = challengerId
		end
		StateController.set({ patents = patents })
	end)

	-- PatentResolved: set winner, clear challenge fields
	_remotes["PatentResolved"].OnClientEvent:Connect(function(compoundId: string, winnerId: number)
		local patents = table.clone(StateController.get().patents)
		if patents[compoundId] then
			patents[compoundId] = table.clone(patents[compoundId])
			patents[compoundId].holderId = winnerId
			patents[compoundId].challengerId = nil
			patents[compoundId].windowEnd = nil
			patents[compoundId].state = "HELD"
		end
		StateController.set({ patents = patents })
	end)

	-- ChampionshipsUpdate: §18 Hall of Fame — the player's synced championship cache
	_remotes["ChampionshipsUpdate"].OnClientEvent:Connect(function(championships: { any })
		StateController.set({ championships = championships or {} })
	end)

	-- SyndicateUpdate
	_remotes["SyndicateUpdate"].OnClientEvent:Connect(function(syndicateSnapshot: any)
		StateController.set({ syndicate = syndicateSnapshot })
	end)

	-- SyndicateInviteReceived
	_remotes["SyndicateInviteReceived"].OnClientEvent:Connect(
		function(syndicateId: string, inviterUserId: number, syndicateName: string)
			StateController.set({
				pendingInvite = {
					syndicateId = syndicateId,
					inviterUserId = inviterUserId,
					syndicateName = syndicateName,
				},
			})
		end
	)

	-- JointSlotUpdate: update one joint slot within syndicate
	_remotes["JointSlotUpdate"].OnClientEvent:Connect(function(slotIndex: number, jointSlotData: any)
		local syndicate = StateController.get().syndicate
		if not syndicate then
			return
		end
		local updated = table.clone(syndicate)
		updated.jointSlots = table.clone(syndicate.jointSlots or {})
		updated.jointSlots[slotIndex] = jointSlotData
		StateController.set({ syndicate = updated })
	end)

	-- RankUpdate
	_remotes["RankUpdate"].OnClientEvent:Connect(function(currentRun: number, lifetime: number, title: string)
		StateController.set({ rank = { currentRun = currentRun, lifetime = lifetime, title = title } })
	end)

	-- ContractUpdate
	_remotes["ContractUpdate"].OnClientEvent:Connect(function(contracts: any)
		StateController.set({ contracts = contracts })
	end)

	-- StreakUpdate: server fires a single { day, safeUntil } table
	_remotes["StreakUpdate"].OnClientEvent:Connect(function(streak: { day: number, safeUntil: number })
		StateController.set({ streak = streak })
	end)

	-- CosmeticUpdate: replace owned + equipped maps (§24)
	_remotes["CosmeticUpdate"].OnClientEvent:Connect(function(owned: { [string]: boolean }, equipped: { [string]: string })
		StateController.set({ cosmetics = { owned = owned or {}, equipped = equipped or {} } })
	end)

	-- Announcement: append, cap at 10
	_remotes["Announcement"].OnClientEvent:Connect(function(kind: string, message: string, tier: number?)
		local list = table.clone(StateController.get().announcements)
		table.insert(list, { kind = kind, message = message, tier = tier })
		while #list > 10 do
			table.remove(list, 1)
		end
		StateController.set({ announcements = list })
	end)

	-- GamepassStatus
	_remotes["GamepassStatus"].OnClientEvent:Connect(function(passes: any)
		StateController.set({ gamepasses = passes })
	end)

	-- FluxUpdate: server fires a single { seasonKey, total, blueprintsOwned? } table
	_remotes["FluxUpdate"].OnClientEvent:Connect(function(flux: { seasonKey: string, total: number, blueprintsOwned: { [string]: boolean }? })
		StateController.set({ flux = flux })
	end)

	-- ExoticRegistryUpdate
	_remotes["ExoticRegistryUpdate"].OnClientEvent:Connect(
		function(exoticId: string, unitCount: number, currentValue: number)
			local registry = table.clone(StateController.get().exoticRegistry)
			registry[exoticId] = { unitCount = unitCount, currentValue = currentValue }
			StateController.set({ exoticRegistry = registry })
		end
	)

	-- EpochChanged
	_remotes["EpochChanged"].OnClientEvent:Connect(function(epochType: string, timestamp: number)
		StateController.set({ epoch = { epochType = epochType, timestamp = timestamp } })
	end)
end

function RemoteController.init(): typeof(RemoteController)
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	assert(folder, "[RemoteController] Remotes folder missing — server may not have initialized")

	for _, entry in ipairs(Manifest) do
		local remote = folder:FindFirstChild(entry.name)
		if not remote then
			error("[RemoteController] missing remote: " .. entry.name)
		end
		_remotes[entry.name] = remote :: any
	end

	wireS2C()

	return RemoteController
end

return RemoteController

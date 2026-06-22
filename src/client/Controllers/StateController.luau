-- Client-side single source of truth. No remote calls — pure state management.

local Types = require(game:GetService("ReplicatedStorage").Shared.Types)

type SlotRecord = Types.SlotRecord
type VaultData = Types.VaultData
type BalanceData = Types.BalanceData
type PatentRecord = Types.PatentRecord
type SyndicateData = Types.SyndicateData
type ContractRecord = Types.ContractRecord
type FormulaLogEntry = Types.FormulaLogEntry
type OfflineBreakdownEntry = Types.OfflineBreakdownEntry
type AnnouncementData = Types.AnnouncementData
type LeaderboardEntry = Types.LeaderboardEntry
type JointSlotRecord = Types.JointSlotRecord

type State = {
	loaded: boolean,
	slotCap: number,
	slots: { [number]: SlotRecord },
	vault: VaultData,
	balance: BalanceData,
	patents: { [string]: PatentRecord },
	syndicate: SyndicateData?,
	pendingInvite: { syndicateId: string, inviterUserId: number, syndicateName: string }?,
	contracts: { ContractRecord },
	streak: { day: number, safeUntil: number }?,
	rank: { currentRun: number, lifetime: number, title: string }?,
	prestige: { level: number },
	leaderboard: { sprint: { LeaderboardEntry }, chief: { LeaderboardEntry } },
	ownRows: { sprint: LeaderboardEntry?, chief: LeaderboardEntry? },
	championships: { { weekEpoch: number, score: number, rank: number, awardedAt: number } },
	flux: { seasonKey: string, total: number, blueprintsOwned: { [string]: boolean }? }?,
	exoticRegistry: { [string]: { unitCount: number, currentValue: number } },
	gamepasses: { [string]: boolean },
	formulaLog: { FormulaLogEntry },
	cosmetics: { owned: { [string]: boolean }, equipped: { [string]: string } },
	offlineIncome: { amount: number, breakdown: { OfflineBreakdownEntry } }?,
	announcements: { AnnouncementData },
	epoch: { epochType: string, timestamp: number }?,
	hints: { [string]: boolean },
}

local _state: State = {
	loaded = false,
	slotCap = 5,
	slots = {},
	vault = {},
	balance = { pellets = 0, catalysts = 0, rushUses = 0, timerSkipUses = 0 },
	patents = {},
	syndicate = nil,
	pendingInvite = nil,
	contracts = {},
	streak = nil,
	rank = nil,
	prestige = { level = 0 },
	leaderboard = { sprint = {}, chief = {} },
	ownRows = { sprint = nil, chief = nil },
	championships = {},
	flux = nil,
	exoticRegistry = {},
	gamepasses = {},
	formulaLog = {},
	cosmetics = { owned = {}, equipped = {} },
	offlineIncome = nil,
	announcements = {},
	epoch = nil,
	hints = {},
}

local _listeners: { ({ [string]: any }) -> () } = {}

-- Minimal signal compatible with RBXScriptSignal's Connect/Disconnect interface.
local Changed = {}
Changed.__index = Changed

function Changed:Connect(fn: ({ [string]: any }) -> ()): { Disconnect: () -> () }
	table.insert(_listeners, fn)
	return {
		Disconnect = function()
			for i, f in ipairs(_listeners) do
				if f == fn then
					table.remove(_listeners, i)
					break
				end
			end
		end,
	}
end

local StateController = {}

StateController.Changed = setmetatable({}, Changed)

function StateController.get(): State
	return _state
end

function StateController.set(patch: { [string]: any })
	for k, v in pairs(patch) do
		(_state :: any)[k] = v
	end
	for _, fn in ipairs(_listeners) do
		fn(patch)
	end
end

function StateController.init(): typeof(StateController)
	return StateController
end

return StateController

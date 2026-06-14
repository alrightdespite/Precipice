-- GENERATED MANIFEST — add entries here; RemoteService creates instances at boot.
-- Never create RemoteEvent/RemoteFunction instances directly (design doc E13).
--
-- Format: { name, kind, direction, rateLimit, payloadDesc }
--   kind:      "Event" | "Function"
--   direction: "S2C" (server→client) | "C2S" (client→server) | "Bidirectional"
--   rateLimit: requests per second per player (nil = no limit on S2C or server-side)

export type RemoteEntry = {
	name: string,
	kind: "Event" | "Function",
	direction: "S2C" | "C2S" | "Bidirectional",
	rateLimit: number?,
	payloadDesc: string,
}

local Manifest: { RemoteEntry } = {

	-- ── Slot / Production ──────────────────────────────────────────────────────
	{
		name = "SlotStartExtraction",
		kind = "Function",
		direction = "C2S",
		rateLimit = 2,
		payloadDesc = "compoundId: string → ok: boolean, err: string?",
	},
	{
		name = "SlotStartSynthesis",
		kind = "Function",
		direction = "C2S",
		rateLimit = 2,
		payloadDesc = "slotIndex: number, input1: string, input2: string, stabilized: boolean → ok: boolean, err: string?",
	},
	{
		name = "SlotCancel",
		kind = "Function",
		direction = "C2S",
		rateLimit = 2,
		payloadDesc = "slotIndex: number → ok: boolean, err: string?",
	},
	{
		name = "SlotReveal",
		kind = "Function",
		direction = "C2S",
		rateLimit = 4,
		payloadDesc = "slotIndex: number → result: CompoundResult, err: string?",
	},
	{
		name = "SlotSkip",
		kind = "Function",
		direction = "C2S",
		rateLimit = 1,
		payloadDesc = "slotIndex: number, skipType: 'catalyst'|'timerskip' → ok: boolean, err: string?",
	},
	{
		name = "SlotStateUpdate",
		kind = "Event",
		direction = "S2C",
		payloadDesc = "slotIndex: number, slotData: SlotRecord",
	},

	-- ── Income / Vault ─────────────────────────────────────────────────────────
	{
		name = "VaultInstantSell",
		kind = "Function",
		direction = "C2S",
		rateLimit = 4,
		payloadDesc = "compoundId: string, quantity: number → pellets: number, err: string?",
	},
	{
		name = "VaultUpdate",
		kind = "Event",
		direction = "S2C",
		payloadDesc = "vaultSnapshot: VaultData",
	},
	{
		name = "BalanceUpdate",
		kind = "Event",
		direction = "S2C",
		payloadDesc = "pellets: number, catalysts: number, rushUses: number, timerSkipUses: number",
	},
	{
		name = "OfflineIncomeDelivered",
		kind = "Event",
		direction = "S2C",
		payloadDesc = "amount: number, breakdown: { tier: number, pellets: number }[]",
	},

	-- ── Formula Lab ────────────────────────────────────────────────────────────
	{
		name = "LabAnalyze",
		kind = "Function",
		direction = "C2S",
		rateLimit = 2,
		payloadDesc = "input1: string, input2: string → result: LabResult, err: string?",
	},
	{
		name = "LabDiscovery",
		kind = "Event",
		direction = "S2C",
		payloadDesc = "compoundId: string, recipeId: string",
	},

	-- ── Market ─────────────────────────────────────────────────────────────────
	{
		name = "MarketCreateListing",
		kind = "Function",
		direction = "C2S",
		rateLimit = 1,
		payloadDesc = "compoundId: string, quantity: number, price: number → listingId: string, err: string?",
	},
	{
		name = "MarketCancelListing",
		kind = "Function",
		direction = "C2S",
		rateLimit = 2,
		payloadDesc = "listingId: string → ok: boolean, err: string?",
	},
	{
		name = "MarketBuyListing",
		kind = "Function",
		direction = "C2S",
		rateLimit = 2,
		payloadDesc = "listingId: string → ok: boolean, err: string?",
	},
	{
		name = "MarketBrowse",
		kind = "Function",
		direction = "C2S",
		rateLimit = 4,
		payloadDesc = "tier: number?, page: number → listings: ListingRecord[], err: string?",
	},

	-- ── Patents ────────────────────────────────────────────────────────────────
	{
		name = "PatentClaim",
		kind = "Event",
		direction = "S2C",
		payloadDesc = "compoundId: string, claimantId: number, isWorldFirst: boolean",
	},
	{
		name = "PatentChallengeAlert",
		kind = "Event",
		direction = "S2C",
		payloadDesc = "compoundId: string, windowEnd: number",
	},
	{
		name = "PatentChallenged",
		kind = "Event",
		direction = "S2C",
		payloadDesc = "compoundId: string, challengerId: number",
	},
	{
		name = "PatentResolved",
		kind = "Event",
		direction = "S2C",
		payloadDesc = "compoundId: string, winnerId: number",
	},
	{
		name = "PatentQuery",
		kind = "Function",
		direction = "C2S",
		rateLimit = 2,
		payloadDesc = "compoundId: string → record: PatentRecord?",
	},
	{
		name = "FormulaLogRequest",
		kind = "Function",
		direction = "C2S",
		rateLimit = 2,
		payloadDesc = "() → formulaLog: FormulaLogData",
	},

	-- ── Syndicates / Joint Synthesis ──────────────────────────────────────────
	{
		name = "SyndicateCreate",
		kind = "Function",
		direction = "C2S",
		rateLimit = 0.1,
		payloadDesc = "name: string → syndicateId: string, err: string?",
	},
	{
		name = "SyndicateInvite",
		kind = "Function",
		direction = "C2S",
		rateLimit = 1,
		payloadDesc = "targetUserId: number → ok: boolean, err: string?",
	},
	{
		name = "SyndicateKick",
		kind = "Function",
		direction = "C2S",
		rateLimit = 1,
		payloadDesc = "targetUserId: number → ok: boolean, err: string?",
	},
	{
		name = "SyndicatePromote",
		kind = "Function",
		direction = "C2S",
		rateLimit = 1,
		payloadDesc = "targetUserId: number → ok: boolean, err: string?",
	},
	{
		name = "SyndicateContributeVault",
		kind = "Function",
		direction = "C2S",
		rateLimit = 2,
		payloadDesc = "amount: number → ok: boolean, err: string?",
	},
	{
		name = "SyndicateUpdate",
		kind = "Event",
		direction = "S2C",
		payloadDesc = "syndicateSnapshot: SyndicateData",
	},
	{
		name = "JointStage",
		kind = "Function",
		direction = "C2S",
		rateLimit = 1,
		payloadDesc = "slotIndex: number, myCompound: string, partnerCompound: string, async: boolean, accelerated: boolean → ok: boolean, err: string?",
	},
	{
		name = "JointContribute",
		kind = "Function",
		direction = "C2S",
		rateLimit = 1,
		payloadDesc = "slotIndex: number, compound: string → ok: boolean, err: string?",
	},
	{
		name = "JointCancel",
		kind = "Function",
		direction = "C2S",
		rateLimit = 1,
		payloadDesc = "slotIndex: number → ok: boolean, err: string?",
	},
	{
		name = "JointSlotUpdate",
		kind = "Event",
		direction = "S2C",
		payloadDesc = "slotIndex: number, jointSlotData: JointSlotRecord",
	},

	-- ── Rank / Sprint / Leaderboards ──────────────────────────────────────────
	{
		name = "RankUpdate",
		kind = "Event",
		direction = "S2C",
		payloadDesc = "currentRun: number, lifetime: number, title: string",
	},
	{
		name = "LeaderboardRequest",
		kind = "Function",
		direction = "C2S",
		rateLimit = 0.5,
		payloadDesc = "board: 'sprint'|'chiefs' → entries: LeaderboardEntry[], ownRow: LeaderboardEntry?",
	},

	-- ── Contracts / Streak ────────────────────────────────────────────────────
	{
		name = "ContractUpdate",
		kind = "Event",
		direction = "S2C",
		payloadDesc = "contracts: ContractRecord[]",
	},
	{
		name = "StreakUpdate",
		kind = "Event",
		direction = "S2C",
		payloadDesc = "day: number, safeUntil: number",
	},
	{
		name = "ContractClaim",
		kind = "Function",
		direction = "C2S",
		rateLimit = 2,
		payloadDesc = "slotIndex: number → ok: boolean, err: string?",
	},

	-- ── Prestige ──────────────────────────────────────────────────────────────
	{
		name = "PrestigeRequest",
		kind = "Function",
		direction = "C2S",
		rateLimit = 0.1,
		payloadDesc = "() → blockers: string[]?, ok: boolean",
	},
	{
		name = "PrestigeConfirm",
		kind = "Function",
		direction = "C2S",
		rateLimit = 0.1,
		payloadDesc = "() → ok: boolean, err: string?",
	},

	-- ── Announcements ─────────────────────────────────────────────────────────
	{
		name = "Announcement",
		kind = "Event",
		direction = "S2C",
		payloadDesc = "kind: string, message: string, tier: number?",
	},

	-- ── Monetization ──────────────────────────────────────────────────────────
	{
		name = "GamepassStatus",
		kind = "Event",
		direction = "S2C",
		payloadDesc = "passes: { [string]: boolean }",
	},

	-- ── Clock ─────────────────────────────────────────────────────────────────
	{
		name = "EpochChanged",
		kind = "Event",
		direction = "S2C",
		payloadDesc = "epochType: 'weekly'|'daily', timestamp: number",
	},
}

return Manifest

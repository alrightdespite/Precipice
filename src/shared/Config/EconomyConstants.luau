-- EconomyConstants: hand-authored economy rules from PRECIPICE_ECONOMY_MODEL.xlsx.
-- Checksum tie: verified against economy model v4.5 (all values cross-checked §30).
-- Never hand-edit src/shared/Data/*; this file is the hand-authored companion.

return {
	-- Analysis fees (doc §11)
	LAB_FEE_LOW = 25, -- T1+T1, T1+T2
	LAB_FEE_MID = 75, -- T2+T2, T2+T3, T3+T3, T3+T4
	LAB_FEE_HIGH = 200, -- T4+T4 and above

	-- Prestige fee reduction (doc §22)
	PRESTIGE_FEE_MULTIPLIER = 0.60, -- fees × 0.6 from P1+

	-- Joint analysis fee (doc §17)
	JOINT_ANALYSIS_FEE = 500,
	JOINT_ANALYSIS_FEE_PRESTIGE = 300,

	-- Residue grant amounts (doc §12)
	RESIDUE_GRANT = {
		LOW = 1, -- T1+T1, T1+T2
		MID = 2, -- T2+T2, T2+T3
		HIGH = 4, -- T3+T3, T3+T4
		TOP = 6, -- T4+T4+
	},

	-- Residue instant sell value (doc §12)
	RESIDUE_SELL_VALUE = 15,

	-- Market fees (doc §16)
	MARKET_LISTING_FEE_RATE = 0.01,
	MARKET_SALE_FEE_RATE = 0.05,
	MARKET_PRICE_FLOOR_RATIO = 0.80,
	MARKET_PRICE_CEILING_RATIO = 5.00,
	MARKET_MAX_ACTIVE_LISTINGS = 10,
	MARKET_LISTING_EXPIRY_DAYS = 7,

	-- Exotic decay (doc §23)
	EXOTIC_DECAY_CONSTANT = 0.97,
	EXOTIC_DECAY_FLOOR = 0.25,
	EXOTIC_WEEKLY_DIVIDEND = 200000,

	-- Patent dividends (doc §15) — indexed by tier
	PATENT_DIVIDENDS = {
		[2] = 800,
		[3] = 5000,
		[4] = 15000,
		[5] = 60000,
		[6] = 100000,
		[7] = 200000,
	},

	-- Patent claim bonuses (doc §15)
	PATENT_CLAIM_BONUSES = {
		[2] = 1150,
		[3] = 5500,
		[4] = 30000,
		[5] = 160000,
		[6] = 800000,
	},
	PATENT_CLAIM_CATALYSTS = 5,
	PATENT_CLAIM_RANK = 500,

	-- Prestige costs (doc §22 v4.3)
	PRESTIGE_COSTS = {
		[1] = 500000,
		[2] = 1500000,
		[3] = 4000000,
		[4] = 10000000,
		[5] = 25000000,
		[6] = 45000000,
		[7] = 60000000,
	},
	PRESTIGE_COST_MULTIPLIER_8PLUS = 1.25,

	-- Stabilized synthesis timer multiplier (doc §7)
	STABILIZE_MULTIPLIER = 1.5,

	-- Joint synthesis timers (doc §17)
	JOINT_SYNC_HOURS = 24,
	JOINT_ASYNC_HOURS = 36,
	JOINT_ASYNC_WINDOW_HOURS = 12,
	JOINT_ASYNC_COOLDOWN_HOURS = 6,

	-- T4 qualification (doc §17)
	JOINT_QUAL_REQUIRED = true,

	-- Syndicate vault upgrades (doc §17)
	SYNDICATE_THIRD_SLOT_COST = 10000000,
	SYNDICATE_CREST_COST = 1000000,
	SYNDICATE_ANIMATED_CREST_COST = 2500000,
	SYNDICATE_BROADCAST_CREST_COST = 5000000,
	SYNDICATE_MEMBER_CAP_BASE = 8,
	SYNDICATE_MEMBER_CAP_EXPANDED = 12,
	SYNDICATE_CAP_EXPANSION_CATALYSTS = 200,

	-- Streak window (doc §20)
	STREAK_WINDOW_HOURS = 36,

	-- Contract draw rule (E9, Contract_Pool sheet)
	-- Standard slots: 60% Easy / 40% Medium
	-- Bonus slots: 30% Medium / 70% Hard
	CONTRACT_STANDARD_SLOTS = 3,
	CONTRACT_BONUS_SLOTS = 2,

	-- Rank daily caps (doc §18)
	RANK_DAILY_MARKET_CAP = 1000,
	RANK_DAILY_VAULT_CAP = 500,

	-- Starting balance (doc §27)
	STARTING_PELLETS = 100,
	STARTING_COMPOUNDS_PER_STARTER = 1,

	-- Streak rewards (doc §20)
	-- STREAK_DAILY_PELLETS: index = streak day (1-based). 0 = milestone day (Catalyst/rank instead, no Pellets).
	STREAK_DAILY_PELLETS = {
		50,
		100,
		200,
		200,
		300,
		300,
		0,
		200,
		200,
		200,
		200,
		200,
		200,
		0,
		300,
		300,
		300,
		300,
		300,
		300,
		300,
		300,
		300,
		300,
		300,
		300,
		300,
		0,
	},
	STREAK_PELLETS_REPEATING = 300, -- days 29+
	STREAK_MILESTONE_DAYS = { 7, 14, 28 },
	STREAK_MILESTONE_CATALYSTS = { 1, 2, 5 },
	STREAK_MILESTONE_RANK = { 150, 300, 750 },
	STREAK_REPEATING_INTERVAL = 7, -- every 7 days from day 35 onward
	STREAK_REPEATING_CATALYSTS = 1,
	STREAK_REPEATING_RANK = 75,
}

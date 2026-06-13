-- RankMath: pure rank score calculations (doc §18).
-- No Roblox globals. Lune-testable.
--
-- Contract:
--   scoreForCompletion(tier) → rank points for a natural T2–T7 completion
--   extractionScore() → 0 (always; §18 "extraction earns zero")
--   titleForScore(currentRunScore) → title string
--   marketSaleScore(pellets) → rank points from a single sale (1 per 1000, min 1)
--   vaultContributionScore(pellets) → rank points (1 per 100, contributes to 500/day cap)
--   defenseScore(tier) → rank for successful patent defense
--   claimScore = 500 (once per compound ever)
--   DAILY_MARKET_CAP = 1000, DAILY_VAULT_CAP = 500

local PRODUCTION_SCORES: { [number]: number } = {
	[1] = 0,
	[2] = 3,
	[3] = 16,
	[4] = 85,
	[5] = 300,
	[6] = 1150,
	[7] = 1500,
}

local DEFENSE_SCORES: { [number]: number } = {
	[2] = 25,
	[3] = 50,
	[4] = 100,
	[5] = 150,
	[6] = 250,
	[7] = 250,
}

local TITLES = {
	{ score = 250000, title = "Chief Scientist" },
	{ score = 120000, title = "Director" },
	{ score = 40000, title = "Principal" },
	{ score = 12000, title = "Senior" },
	{ score = 3000, title = "Researcher" },
	{ score = 500, title = "Associate" },
	{ score = 0, title = "Intern" },
}

local DAILY_MARKET_CAP = 1000
local DAILY_VAULT_CAP = 500
local CLAIM_SCORE = 500

local RankMath = {}

RankMath.DAILY_MARKET_CAP = DAILY_MARKET_CAP
RankMath.DAILY_VAULT_CAP = DAILY_VAULT_CAP
RankMath.CLAIM_SCORE = CLAIM_SCORE

function RankMath.scoreForCompletion(tier: number): number
	local s = PRODUCTION_SCORES[tier]
	assert(s ~= nil, "RankMath: unknown tier " .. tostring(tier))
	return s
end

function RankMath.defenseScore(tier: number): number
	local s = DEFENSE_SCORES[tier]
	assert(s, "RankMath: unknown tier for defense " .. tostring(tier))
	return s
end

function RankMath.titleForScore(score: number): string
	for _, entry in ipairs(TITLES) do
		if score >= entry.score then
			return entry.title
		end
	end
	return "Intern"
end

function RankMath.marketSaleScore(pellets: number): number
	return math.max(1, math.floor(pellets / 1000))
end

function RankMath.vaultContributionScore(pellets: number): number
	return math.floor(pellets / 100)
end

return RankMath

-- LabAnalysis: pure formula-lab logic. No Roblox globals. Lune-testable.
-- Fee tables, refusal predicate, residue amounts, button-state derivation (§11, §12).

local LabAnalysis = {}

-- Canonical pair key — sort lexicographically so A+B == B+A.
function LabAnalysis.pairKey(id1: string, id2: string): string
	return if id1 < id2 then id1 .. "|" .. id2 else id2 .. "|" .. id1
end

-- Refusal check (tier-bracket, not recipe lookup).
-- Returns nil (no refusal), "exotic" (either input T7), or "joint" (T4+T5 / T5+T5 / T6+T6).
-- T4+T6 and T5+T6 are NOT refused — they attempt normally and fail (§11).
function LabAnalysis.getRefusal(tier1: number, tier2: number): string?
	if tier1 == 7 or tier2 == 7 then
		return "exotic"
	end
	local minT = math.min(tier1, tier2)
	local maxT = math.max(tier1, tier2)
	if (minT == 4 and maxT == 5) or (minT == 5 and maxT == 5) or (minT == 6 and maxT == 6) then
		return "joint"
	end
	return nil
end

-- Analysis fee (§11). Bracket determined by lower (min) input tier.
-- prestigeLevel >= 1 applies the permanent 40% P1+ reduction.
function LabAnalysis.getFee(minTier: number, prestigeLevel: number): number
	local standard: number
	local discounted: number
	if minTier >= 4 then
		standard, discounted = 200, 120
	elseif minTier == 3 then
		standard, discounted = 75, 45
	elseif minTier == 2 then
		standard, discounted = 75, 45
	else -- minTier == 1
		standard, discounted = 25, 15
	end
	return if prestigeLevel >= 1 then discounted else standard
end

-- Residue units awarded on a failed analysis (§12). Bracket by lower input tier.
function LabAnalysis.getResidueAmount(minTier: number): number
	if minTier >= 4 then
		return 6
	elseif minTier == 3 then
		return 4
	elseif minTier == 2 then
		return 2
	else -- minTier == 1
		return 1
	end
end

-- Button-state derivation per §11 table.
-- possibleResultIds: all valid result compound IDs for this pair (empty = no recipe).
-- Priority order: Failed > Validated > Discovered > Unknown.
function LabAnalysis.getButtonState(
	formulaLog: {
		discovered: { [string]: any },
		validatedPairs: { [string]: any },
		failedPairs: { [string]: any },
	},
	key: string,
	possibleResultIds: { string }
): string
	if formulaLog.failedPairs[key] then
		return "Failed"
	end
	if formulaLog.validatedPairs[key] then
		return "Validated"
	end
	for _, rid in ipairs(possibleResultIds) do
		if formulaLog.discovered[rid] then
			return "Discovered"
		end
	end
	return "Unknown"
end

return LabAnalysis

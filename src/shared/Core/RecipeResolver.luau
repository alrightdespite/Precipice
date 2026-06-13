-- RecipeResolver: pure recipe and formula-lab lookups.
-- No Roblox globals. Lune-testable.
--
-- Contract:
--   resolve(input1, input2, weekSeed) → resultId or nil
--     Returns the active result for the pair this week (weekSeed determines variant).
--     Returns nil if no recipe exists.
--   getLabResult(input1, input2, weekSeed, isRush) → { valid, resultId, isVariable, isPrimary }
--     isRush: Rush Analysis forces primary variant regardless of seed.
--   getTierPair(input1, input2) → (minTier, maxTier)
--   isJointRequired(input1, input2) → boolean (T4+T5, T5+T5, T6+T6)
--   isExoticInput(compoundId) → boolean (T6+T6 → Exotic, never a Lab analysis input)

local Compounds = require(script.Parent.Parent.Data.Compounds)
local Recipes = require(script.Parent.Parent.Data.Recipes)

-- Build lookup tables at module load time
local _byPair: { [string]: { string } } = {} -- "id1|id2" → { recipeId, ... }
local _variablePairs: { [string]: { string } } = {} -- variablePairId → { recipeId (primary first) }

for recipeId, recipe in pairs(Recipes) do
	local key = if recipe.input1 < recipe.input2
		then recipe.input1 .. "|" .. recipe.input2
		else recipe.input2 .. "|" .. recipe.input1
	if not _byPair[key] then
		_byPair[key] = {}
	end
	table.insert(_byPair[key], recipeId)

	if recipe.variablePairId then
		if not _variablePairs[recipe.variablePairId] then
			_variablePairs[recipe.variablePairId] = {}
		end
		table.insert(_variablePairs[recipe.variablePairId], recipeId)
	end
end

local RecipeResolver = {}

local function pairKey(a: string, b: string): string
	return if a < b then a .. "|" .. b else b .. "|" .. a
end

function RecipeResolver.getTierPair(id1: string, id2: string): (number, number)
	local c1 = Compounds[id1]
	local c2 = Compounds[id2]
	assert(c1, "Unknown compound: " .. tostring(id1))
	assert(c2, "Unknown compound: " .. tostring(id2))
	local t1, t2 = c1.tier, c2.tier
	return math.min(t1, t2), math.max(t1, t2)
end

function RecipeResolver.isJointRequired(id1: string, id2: string): boolean
	local minT, maxT = RecipeResolver.getTierPair(id1, id2)
	-- T4+T5, T5+T5, or T6+T6
	return (minT == 4 and maxT == 5) or (minT == 5 and maxT == 5) or (minT == 6 and maxT == 6)
end

function RecipeResolver.isExoticInput(compoundId: string): boolean
	local c = Compounds[compoundId]
	return c ~= nil and c.tier == 7
end

-- weekSeed: integer 0..N identifying this week; for variable pairs, seed % 2 == 0 → primary (70% weeks)
-- The primary/alternate split is a tuning parameter. For the resolver, treat even weeks as primary.
function RecipeResolver.resolve(id1: string, id2: string, weekSeed: number): (string?, boolean)
	local key = pairKey(id1, id2)
	local rids = _byPair[key]
	if not rids then
		return nil, false
	end
	if #rids == 1 then
		return Recipes[rids[1]].resultId, false
	end
	-- Variable pair: two results. Primary = first entry (lower recipe ID).
	table.sort(rids)
	local isPrimary = (weekSeed % 10) < 7 -- 70% primary
	local idx = if isPrimary then 1 else 2
	return Recipes[rids[idx]].resultId, true
end

function RecipeResolver.getLabResult(
	id1: string,
	id2: string,
	weekSeed: number,
	isRush: boolean
): { valid: boolean, resultId: string?, isVariable: boolean, isPrimary: boolean }
	local key = pairKey(id1, id2)
	local rids = _byPair[key]
	if not rids then
		return { valid = false, resultId = nil, isVariable = false, isPrimary = false }
	end
	if #rids == 1 then
		return { valid = true, resultId = Recipes[rids[1]].resultId, isVariable = false, isPrimary = true }
	end
	table.sort(rids)
	local isPrimary = isRush or ((weekSeed % 10) < 7)
	local idx = if isPrimary then 1 else 2
	return {
		valid = true,
		resultId = Recipes[rids[idx]].resultId,
		isVariable = true,
		isPrimary = isPrimary,
	}
end

return RecipeResolver

-- DataIntegrity: CI guard — re-runs structural assertions and BFS reachability in Luau.
-- Fails if src/shared/Data/ has drifted from a fresh export (H9).

local spec = require("../spec")
local Compounds = require("../../src/shared/Data/Compounds")
local Recipes = require("../../src/shared/Data/Recipes")
local Exotics = require("../../src/shared/Data/Exotics")
local ContractPool = require("../../src/shared/Data/ContractPool")

local STARTER_IDS = { "T1_01", "T1_02", "T1_03", "T1_04", "T1_05" }
local TIER_COUNTS = { [1] = 30, [2] = 30, [3] = 30, [4] = 25, [5] = 20, [6] = 15 }
local RECIPE_TIER_COUNTS = { [1] = 25, [2] = 40, [3] = 50, [4] = 45, [5] = 30, [6] = 15 }
local REWARD_BANDS = {
	Easy = { 200, 500 },
	Medium = { 500, 1500 },
	Hard = { 1500, 3000 },
}

spec.describe("DataIntegrity — Compound counts", function()
	spec.it("has exactly 150 compounds", function()
		local count = 0
		for _ in pairs(Compounds) do
			count += 1
		end
		spec.expect(count).toBe(150)
	end)

	for tier, expected in pairs(TIER_COUNTS) do
		local t, e = tier, expected
		spec.it(string.format("tier %d has %d compounds", t, e), function()
			local count = 0
			for _, c in pairs(Compounds) do
				if c.tier == t then
					count += 1
				end
			end
			spec.expect(count).toBe(e)
		end)
	end
end)

spec.describe("DataIntegrity — Recipe counts", function()
	spec.it("has exactly 205 recipes", function()
		local count = 0
		for _ in pairs(Recipes) do
			count += 1
		end
		spec.expect(count).toBe(205)
	end)

	for tier, expected in pairs(RECIPE_TIER_COUNTS) do
		local t, e = tier, expected
		spec.it(string.format("result tier %d has %d recipes", t, e), function()
			local count = 0
			for _, r in pairs(Recipes) do
				if r.resultTier == t then
					count += 1
				end
			end
			spec.expect(count).toBe(e)
		end)
	end
end)

spec.describe("DataIntegrity — Pair uniqueness", function()
	spec.it("no pair has more than 2 recipes", function()
		local pairCounts: { [string]: number } = {}
		for _, r in pairs(Recipes) do
			local key = if r.input1 < r.input2 then r.input1 .. "|" .. r.input2 else r.input2 .. "|" .. r.input1
			pairCounts[key] = (pairCounts[key] or 0) + 1
		end
		for pair, count in pairs(pairCounts) do
			if count > 2 then
				error("Pair " .. pair .. " has " .. count .. " recipes")
			end
		end
	end)

	spec.it("exactly 17 variable pairs (doubles)", function()
		local pairCounts: { [string]: number } = {}
		for _, r in pairs(Recipes) do
			local key = if r.input1 < r.input2 then r.input1 .. "|" .. r.input2 else r.input2 .. "|" .. r.input1
			pairCounts[key] = (pairCounts[key] or 0) + 1
		end
		local doubles = 0
		for _, count in pairs(pairCounts) do
			if count == 2 then
				doubles += 1
			end
		end
		spec.expect(doubles).toBe(17)
	end)
end)

spec.describe("DataIntegrity — BFS reachability", function()
	spec.it("all 150 compounds reachable from 5 starters", function()
		local reachable: { [string]: boolean } = {}
		for _, id in ipairs(STARTER_IDS) do
			reachable[id] = true
		end

		local changed = true
		while changed do
			changed = false
			for _, recipe in pairs(Recipes) do
				if reachable[recipe.input1] and reachable[recipe.input2] and not reachable[recipe.resultId] then
					reachable[recipe.resultId] = true
					changed = true
				end
			end
		end

		local unreachable: { string } = {}
		for id in pairs(Compounds) do
			if not reachable[id] then
				table.insert(unreachable, id)
			end
		end
		if #unreachable > 0 then
			error(string.format("%d compounds unreachable: %s", #unreachable, unreachable[1]))
		end
	end)
end)

spec.describe("DataIntegrity — Exotics", function()
	spec.it("has exactly 120 Exotics", function()
		local count = 0
		for _ in pairs(Exotics) do
			count += 1
		end
		spec.expect(count).toBe(120)
	end)

	spec.it("all Exotic names unique", function()
		local names: { [string]: boolean } = {}
		for _, e in pairs(Exotics) do
			if names[e.name] then
				error("Duplicate Exotic name: " .. e.name)
			end
			names[e.name] = true
		end
	end)

	spec.it("all Exotic initial values in 250k–800k range", function()
		for id, e in pairs(Exotics) do
			if e.initialValue < 250000 or e.initialValue > 800000 then
				error(string.format("%s: value %d outside range", id, e.initialValue))
			end
		end
	end)
end)

spec.describe("DataIntegrity — Contract pool", function()
	spec.it("has exactly 24 contract templates", function()
		local count = 0
		for _ in pairs(ContractPool) do
			count += 1
		end
		spec.expect(count).toBe(24)
	end)

	spec.it("all rewards inside §19 bands", function()
		for id, c in pairs(ContractPool) do
			local band = REWARD_BANDS[c.difficulty]
			if not band then
				error("Unknown difficulty: " .. tostring(c.difficulty) .. " on " .. id)
			end
			if c.pelletReward < band[1] or c.pelletReward > band[2] then
				error(string.format("%s: reward %d outside %s band %d–%d", id, c.pelletReward, c.difficulty, band[1], band[2]))
			end
		end
	end)
end)

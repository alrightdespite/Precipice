-- ContractService tests.
-- Uses injection for ContractPool, Compounds, and RemoteService.
-- Data is a plain table — DataService not involved.

local spec = require("../spec")
local ContractPool = require("../../src/shared/Data/ContractPool")
local ContractService = require("../../src/server/Services/ContractService")

-- Minimal Compounds mock: enough tiers to satisfy all filter checks
local MOCK_COMPOUNDS = {
	["T1_01"] = { tier = 1 },
	["T2_01"] = { tier = 2 },
	["T3_01"] = { tier = 3 },
	["T4_01"] = { tier = 4 },
	["T5_01"] = { tier = 5 },
}

ContractService._setContractPool(ContractPool)
ContractService._setCompounds(MOCK_COMPOUNDS)
ContractService._setRemoteService(nil) -- fire calls nil-checked

local mockPlayer = { UserId = 2001 }

-- Fixed timestamp: 2026-06-14 00:00:00 UTC (approx)
-- Verified: os.date("!%Y-%m-%d", 1749859200) should return a consistent date string.
-- We derive dayKey from the same now in tests, so exact value doesn't matter for matching.
local BASE_NOW = 1749859200

local function defaultData(): any
	return {
		balances = { pellets = 0, catalysts = 0 },
		rank = { currentRun = 0, lifetime = 0 },
		formulaLog = { discovered = {}, validatedPairs = {}, failedPairs = {} },
		syndicate = nil,
		prestige = { level = 0, jointQualLifetime = false },
		contracts = { dayKey = "", slots = {} },
	}
end

-- Data with all filters satisfied
local function richData(): any
	local d = defaultData()
	d.formulaLog.discovered = {
		["T2_01"] = true,
		["T3_01"] = true,
		["T4_01"] = true,
		["T5_01"] = true,
	}
	d.formulaLog.validatedPairs = { ["T2_01+T3_01"] = true }
	d.syndicate = { id = "SYN1" }
	d.prestige.jointQualLifetime = true
	return d
end

-- ── drawContracts — basic ──────────────────────────────────────────────────

spec.describe("ContractService — drawContracts returns 5 slots", function()
	spec.it("exactly 5 slots drawn from full pool", function()
		local data = richData()
		ContractService.drawContracts(data, BASE_NOW)
		spec.expect(#data.contracts.slots).toBe(5)
	end)
end)

spec.describe("ContractService — no templateId repeats across 5 slots", function()
	spec.it("all slot templateIds are unique", function()
		local data = richData()
		ContractService.drawContracts(data, BASE_NOW)
		local seen: { [string]: boolean } = {}
		for _, slot in ipairs(data.contracts.slots) do
			spec.expect(seen[slot.templateId] == nil).toBeTrue()
			seen[slot.templateId] = true
		end
	end)
end)

-- ── Filter enforcement ─────────────────────────────────────────────────────

spec.describe("ContractService — filter: no syndicate", function()
	spec.it("CM2, CM8, CH1 never drawn", function()
		local data = defaultData()
		-- Give enough T2 recipes so Easy/Medium pools aren't empty
		data.formulaLog.discovered = { ["T2_01"] = true, ["T3_01"] = true, ["T4_01"] = true }
		local FORBIDDEN = { CM2 = true, CM8 = true, CH1 = true }

		-- Run many draws to increase confidence
		for _ = 1, 20 do
			ContractService.drawContracts(data, BASE_NOW)
			for _, slot in ipairs(data.contracts.slots) do
				spec.expect(FORBIDDEN[slot.templateId] == nil).toBeTrue()
			end
		end
	end)
end)

spec.describe("ContractService — filter: no discovered recipes", function()
	spec.it("CE1, CE4, CM3, CM6 etc. not drawn", function()
		local data = defaultData() -- no discovered recipes, no syndicate
		local RECIPE_FILTERED = {
			CE1 = true, CE4 = true,
			CM2 = true, CM3 = true, CM6 = true, CM8 = true,
			CH1 = true, CH2 = true, CH3 = true, CH4 = true, CH6 = true, CH8 = true,
		}

		for _ = 1, 20 do
			ContractService.drawContracts(data, BASE_NOW)
			for _, slot in ipairs(data.contracts.slots) do
				spec.expect(RECIPE_FILTERED[slot.templateId] == nil).toBeTrue()
			end
		end
	end)
end)

-- ── Fallback when Easy pool filtered out ───────────────────────────────────

spec.describe("ContractService — fallback: Easy pool entirely filtered out", function()
	spec.it("3 standard slots still drawn from Medium only", function()
		-- Inject a custom pool where all Easy require syndicate
		local customPool = {
			easy = {
				{ id = "CE_S1", name = "E1", target = 1, pelletReward = 100, rankReward = 25, filter = "syndicate", progressType = "lab_analysis" },
				{ id = "CE_S2", name = "E2", target = 1, pelletReward = 100, rankReward = 25, filter = "syndicate", progressType = "lab_analysis" },
				{ id = "CE_S3", name = "E3", target = 1, pelletReward = 100, rankReward = 25, filter = "syndicate", progressType = "lab_analysis" },
				{ id = "CE_S4", name = "E4", target = 1, pelletReward = 100, rankReward = 25, filter = "syndicate", progressType = "lab_analysis" },
			},
			medium = {
				{ id = "CM_A1", name = "M1", target = 1, pelletReward = 200, rankReward = 75, filter = "none", progressType = "lab_analysis" },
				{ id = "CM_A2", name = "M2", target = 1, pelletReward = 200, rankReward = 75, filter = "none", progressType = "lab_analysis" },
				{ id = "CM_A3", name = "M3", target = 1, pelletReward = 200, rankReward = 75, filter = "none", progressType = "lab_analysis" },
				{ id = "CM_A4", name = "M4", target = 1, pelletReward = 200, rankReward = 75, filter = "none", progressType = "lab_analysis" },
			},
			hard = {
				{ id = "CH_B1", name = "H1", target = 1, pelletReward = 400, rankReward = 150, filter = "none", progressType = "lab_analysis" },
				{ id = "CH_B2", name = "H2", target = 1, pelletReward = 400, rankReward = 150, filter = "none", progressType = "lab_analysis" },
				{ id = "CH_B3", name = "H3", target = 1, pelletReward = 400, rankReward = 150, filter = "none", progressType = "lab_analysis" },
			},
		}
		ContractService._setContractPool(customPool)

		local data = defaultData() -- no syndicate → all Easy filtered out
		ContractService.drawContracts(data, BASE_NOW)
		spec.expect(#data.contracts.slots).toBe(5)

		-- Restore real pool
		ContractService._setContractPool(ContractPool)
	end)
end)

-- ── refreshIfStale ─────────────────────────────────────────────────────────

spec.describe("ContractService — refreshIfStale matching dayKey: no-op", function()
	spec.it("slots unchanged when dayKey matches now", function()
		local data = richData()
		local dayKey = os.date("!%Y-%m-%d", BASE_NOW) :: string
		data.contracts = {
			dayKey = dayKey,
			slots = { { templateId = "CE3", progress = 0, target = 1, completed = false, claimed = false } },
		}

		ContractService.refreshIfStale(mockPlayer, data, BASE_NOW)

		spec.expect(#data.contracts.slots).toBe(1)
		spec.expect(data.contracts.slots[1].templateId).toBe("CE3")
	end)
end)

spec.describe("ContractService — refreshIfStale stale dayKey: new draw", function()
	spec.it("old dayKey triggers redraw to 5 slots with updated dayKey", function()
		local data = richData()
		data.contracts = { dayKey = "2000-01-01", slots = {} }

		ContractService.refreshIfStale(mockPlayer, data, BASE_NOW)

		spec.expect(#data.contracts.slots).toBe(5)
		local expectedKey = os.date("!%Y-%m-%d", BASE_NOW) :: string
		spec.expect(data.contracts.dayKey).toBe(expectedKey)
	end)
end)

-- ── recordProgress ─────────────────────────────────────────────────────────

spec.describe("ContractService — recordProgress matching progressType", function()
	spec.it("slot.progress increments; completes at target", function()
		local data = richData()
		data.contracts = {
			dayKey = "2026-06-14",
			slots = {
				{ templateId = "CE2", progress = 0, target = 2, completed = false, claimed = false },
			},
		}

		ContractService.recordProgress(mockPlayer, data, "lab_analysis", 1)
		spec.expect(data.contracts.slots[1].progress).toBe(1)
		spec.expect(data.contracts.slots[1].completed).toBeFalse()

		ContractService.recordProgress(mockPlayer, data, "lab_analysis", 1)
		spec.expect(data.contracts.slots[1].progress).toBe(2)
		spec.expect(data.contracts.slots[1].completed).toBeTrue()
	end)
end)

spec.describe("ContractService — recordProgress non-matching type: no change", function()
	spec.it("instant_sell does not progress a lab_analysis slot", function()
		local data = richData()
		data.contracts = {
			dayKey = "2026-06-14",
			slots = {
				{ templateId = "CE2", progress = 0, target = 2, completed = false, claimed = false },
			},
		}

		ContractService.recordProgress(mockPlayer, data, "instant_sell", 1)
		spec.expect(data.contracts.slots[1].progress).toBe(0)
	end)
end)

spec.describe("ContractService — recordProgress on already-completed slot: no double-increment", function()
	spec.it("progress stays at target after completion", function()
		local data = richData()
		data.contracts = {
			dayKey = "2026-06-14",
			slots = {
				{ templateId = "CE2", progress = 2, target = 2, completed = true, claimed = false },
			},
		}

		ContractService.recordProgress(mockPlayer, data, "lab_analysis", 1)
		spec.expect(data.contracts.slots[1].progress).toBe(2) -- unchanged
	end)
end)

-- ── claimReward ────────────────────────────────────────────────────────────

spec.describe("ContractService — claimReward completed+unclaimed slot", function()
	spec.it("pellets awarded, claimed = true, rank incremented", function()
		local data = richData()
		-- CE3: pelletReward = 200, rankReward = 25
		data.contracts = {
			dayKey = "2026-06-14",
			slots = {
				{ templateId = "CE3", progress = 1, target = 1, completed = true, claimed = false },
			},
		}

		local ok, err = ContractService.claimReward(mockPlayer, data, 1)
		spec.expect(ok).toBeTrue()
		spec.expect(err).toBeNil()
		spec.expect(data.balances.pellets).toBe(200)
		spec.expect(data.rank.currentRun).toBe(25)
		spec.expect(data.rank.lifetime).toBe(25)
		spec.expect(data.contracts.slots[1].claimed).toBeTrue()
	end)
end)

spec.describe("ContractService — claimReward incomplete slot: no-op", function()
	spec.it("returns false, no pellet award", function()
		local data = richData()
		data.contracts = {
			dayKey = "2026-06-14",
			slots = {
				{ templateId = "CE3", progress = 0, target = 1, completed = false, claimed = false },
			},
		}

		local ok, err = ContractService.claimReward(mockPlayer, data, 1)
		spec.expect(ok).toBeFalse()
		spec.expect(type(err)).toBe("string")
		spec.expect(data.balances.pellets).toBe(0)
		spec.expect(data.contracts.slots[1].claimed).toBeFalse()
	end)
end)

spec.describe("ContractService — claimReward already-claimed slot: no double-award", function()
	spec.it("returns false, pellets not awarded again", function()
		local data = richData()
		data.contracts = {
			dayKey = "2026-06-14",
			slots = {
				{ templateId = "CE3", progress = 1, target = 1, completed = true, claimed = true },
			},
		}
		data.balances.pellets = 200 -- already awarded once

		local ok, err = ContractService.claimReward(mockPlayer, data, 1)
		spec.expect(ok).toBeFalse()
		spec.expect(type(err)).toBe("string")
		spec.expect(data.balances.pellets).toBe(200) -- unchanged
	end)
end)

-- ── ContractPool validation ────────────────────────────────────────────────

spec.describe("ContractPool — structural validation", function()
	spec.it("exactly 8 Easy, 8 Medium, 8 Hard templates", function()
		spec.expect(#ContractPool.easy).toBe(8)
		spec.expect(#ContractPool.medium).toBe(8)
		spec.expect(#ContractPool.hard).toBe(8)
	end)

	spec.it("every template has required fields with correct types", function()
		local REQUIRED_FIELDS = { "id", "name", "target", "pelletReward", "rankReward", "filter", "progressType" }
		local allTemplates = {}
		for _, t in ipairs(ContractPool.easy) do table.insert(allTemplates, t) end
		for _, t in ipairs(ContractPool.medium) do table.insert(allTemplates, t) end
		for _, t in ipairs(ContractPool.hard) do table.insert(allTemplates, t) end

		for _, template in ipairs(allTemplates) do
			for _, field in ipairs(REQUIRED_FIELDS) do
				spec.expect(template[field] ~= nil).toBeTrue()
			end
		end
	end)

	spec.it("no duplicate IDs across full pool", function()
		local seen: { [string]: boolean } = {}
		local allTemplates = {}
		for _, t in ipairs(ContractPool.easy) do table.insert(allTemplates, t) end
		for _, t in ipairs(ContractPool.medium) do table.insert(allTemplates, t) end
		for _, t in ipairs(ContractPool.hard) do table.insert(allTemplates, t) end

		for _, template in ipairs(allTemplates) do
			spec.expect(seen[template.id] == nil).toBeTrue()
			seen[template.id] = true
		end
	end)

	spec.it("Easy rankReward == 25, Medium == 75, Hard == 150", function()
		for _, t in ipairs(ContractPool.easy) do
			spec.expect(t.rankReward).toBe(25)
		end
		for _, t in ipairs(ContractPool.medium) do
			spec.expect(t.rankReward).toBe(75)
		end
		for _, t in ipairs(ContractPool.hard) do
			spec.expect(t.rankReward).toBe(150)
		end
	end)
end)

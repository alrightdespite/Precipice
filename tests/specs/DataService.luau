-- Tests for ProfileTemplate (pure layer under DataService).
-- DataService itself wraps ProfileStore and is integration-tested in Studio.

local spec = require("../spec")
local ProfileTemplate = require("../../src/shared/Core/ProfileTemplate")
local GameConfig = require("../../src/shared/Config/GameConfig")

local describe, it, expect = spec.describe, spec.it, spec.expect

describe("ProfileTemplate — DEFAULT shape", function()
	local d = ProfileTemplate.DEFAULT

	it("schemaVersion matches GameConfig.SCHEMA_VERSION", function()
		expect(d.schemaVersion).toBe(GameConfig.SCHEMA_VERSION)
	end)

	it("has all 16 top-level keys", function()
		local required = {
			"schemaVersion",
			"balances",
			"vault",
			"formulaLog",
			"slots",
			"lastSeenAt",
			"rank",
			"sprintPoints",
			"streak",
			"contracts",
			"prestige",
			"monetization",
			"cosmetics",
			"championships",
			"eventState",
			"pendingCreditsApplied",
		}
		for _, key in ipairs(required) do
			expect(d[key] ~= nil).toBeTrue()
		end
	end)

	it("balances starts at zero", function()
		expect(d.balances.pellets).toBe(0)
		expect(d.balances.catalysts).toBe(0)
	end)

	it("vault residue starts at zero", function()
		expect(d.vault.residue).toBe(0)
	end)

	it("rank starts at zero", function()
		expect(d.rank.currentRun).toBe(0)
		expect(d.rank.lifetime).toBe(0)
	end)

	it("prestige starts at level 0", function()
		expect(d.prestige.level).toBe(0)
		expect(d.prestige.jointQualLifetime).toBe(false)
	end)

	it("pendingCreditsApplied is empty table", function()
		expect(type(d.pendingCreditsApplied)).toBe("table")
		expect(#d.pendingCreditsApplied).toBe(0)
	end)

	it("slots is empty table", function()
		expect(type(d.slots)).toBe("table")
		expect(#d.slots).toBe(0)
	end)
end)

describe("ProfileTemplate — migrate", function()
	it("no-op when already at target version", function()
		local data = { schemaVersion = 1, value = "unchanged" }
		ProfileTemplate.migrate(data, {}, 1)
		expect(data.schemaVersion).toBe(1)
		expect(data.value).toBe("unchanged")
	end)

	it("runs a single migration and increments schemaVersion", function()
		local data = { schemaVersion = 0, existing = true }
		ProfileTemplate.migrate(data, {
			[0] = function(d)
				d.added = "yes"
			end,
		}, 1)
		expect(data.schemaVersion).toBe(1)
		expect(data.added).toBe("yes")
		expect(data.existing).toBe(true)
	end)

	it("runs migrations in order across multiple versions", function()
		local data = { schemaVersion = 0, log = {} }
		ProfileTemplate.migrate(data, {
			[0] = function(d)
				table.insert(d.log, "v0")
			end,
			[1] = function(d)
				table.insert(d.log, "v1")
			end,
		}, 2)
		expect(data.schemaVersion).toBe(2)
		expect(data.log[1]).toBe("v0")
		expect(data.log[2]).toBe("v1")
	end)

	it("silently skips gap versions with no migration defined", function()
		local data = { schemaVersion = 1, x = 99 }
		ProfileTemplate.migrate(data, {}, 3) -- no migrations[1] or [2]
		expect(data.schemaVersion).toBe(3)
		expect(data.x).toBe(99)
	end)

	it("does nothing when targetVersion equals current", function()
		local runCount = 0
		local data = { schemaVersion = 5 }
		ProfileTemplate.migrate(data, {
			[5] = function(_)
				runCount += 1
			end,
		}, 5)
		expect(runCount).toBe(0)
		expect(data.schemaVersion).toBe(5)
	end)
end)

-- ProfileTemplate: default profile data and pure migration runner.
-- No Roblox globals — Lune-testable.
-- Migrations must mutate `data` in-place (never replace the table).

local ProfileTemplate = {}

-- Hard-copied by ProfileStore.New as the DataStore template.
-- Never mutate this table at runtime.
ProfileTemplate.DEFAULT = {
	schemaVersion = 1,

	balances = { pellets = 0, catalysts = 0 },

	vault = { compounds = {}, residue = 0 },

	formulaLog = {
		discovered = {},
		validatedPairs = {},
		failedPairs = {},
	},

	slots = {},

	rank = {
		currentRun = 0,
		lifetime = 0,
		dailyCaps = { date = "", marketPoints = 0, vaultPoints = 0 },
	},

	sprintPoints = { weekEpoch = 0, points = 0 },

	streak = { day = 0, lastLoginUnix = 0 },

	contracts = { dayKey = "", list = {} },

	prestige = { level = 0, jointQualLifetime = false },

	monetization = {
		gamepasses = {},
		rushUses = 0,
		archiveUsesByMonth = {},
		receiptLedger = {},
	},

	cosmetics = { owned = {}, equipped = {} },

	eventState = { fluxBySeason = {}, blueprintsOwned = {} },

	pendingCreditsApplied = {},
}

-- Walks data.schemaVersion up to targetVersion by calling migrations[N] for each step.
-- Each migration must mutate `data` in-place and need not return anything.
-- Gaps in the migrations table are silently skipped (schemaVersion still increments).
function ProfileTemplate.migrate(
	data: { [string]: any },
	migrations: { [number]: (data: { [string]: any }) -> () },
	targetVersion: number
)
	while data.schemaVersion < targetVersion do
		local fn = migrations[data.schemaVersion]
		if fn then
			fn(data)
		end
		data.schemaVersion = data.schemaVersion + 1
	end
end

return ProfileTemplate

-- Entry point: lune run tests/run
-- Run from repo root.

local process = require("@lune/process")
local spec = require("spec")

-- Load all spec files — they register suites into the shared spec instance
require("specs/DataService")
require("specs/DataIntegrity")
require("specs/RemotesGuard")
require("specs/OfflineIncome")
require("specs/TimerMath")

print("\n=== PRECIPICE test suite ===")
local passed = spec.run()

if not passed then
	process.exit(1)
end

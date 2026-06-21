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
require("specs/Sha256")
require("specs/SeedResolver")
require("specs/SeedService")
require("specs/SlotService")
require("specs/LabAnalysis")
require("specs/GlobalJobService")
require("specs/ClockService")
require("specs/RateLimiter")
require("specs/AnnouncementQueue")
require("specs/CosmeticCatalog")
require("specs/SynthCountService")
require("specs/PatentService")
require("specs/MarketService")
require("specs/StreakService")
require("specs/ContractService")
require("specs/RankService")
require("specs/LeaderboardService")
require("specs/PrestigeService")
require("specs/MonetizationService")
require("specs/EventService")
require("specs/SyndicateService")
require("specs/ExoticService")
require("specs/JointSynthService")
require("specs/RemoteHandlers")
require("specs/Phase11Hardening")
require("specs/LabButtonState")
require("specs/PrestigeBlockers")
require("specs/HintTriggers")

print("\n=== PRECIPICE test suite ===")
local passed = spec.run()

if not passed then
	process.exit(1)
end

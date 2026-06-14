-- GameInit: server boot. Boot order per docs/01_ARCHITECTURE.md §Boot order (H9).
-- No service may yield during another's init().

local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

-- ── 1. Config ──────────────────────────────────────────────────────────────
-- GameConfig and EconomyConstants are required lazily by services that need them.

-- ── 2. Data tables (generated; loaded lazily by Core modules) ──────────────

-- ── 3. RemoteService ──────────────────────────────────────────────────────
local RemoteService = require(ServerScriptService.Server.Services.RemoteService)
RemoteService.init()

-- ── 4. DataService ────────────────────────────────────────────────────────
local DataService = require(ServerScriptService.Server.Services.DataService)
DataService.init()

-- ── 5. ClockService (Phase 4) ─────────────────────────────────────────────
-- TODO Phase 4: ClockService.init() goes here before GlobalJobService.

-- ── 5b. GlobalJobService ──────────────────────────────────────────────────
local GlobalJobService = require(ServerScriptService.Server.Services.GlobalJobService)
GlobalJobService.init()

-- ── 5c. SynthCountService ─────────────────────────────────────────────────
local SynthCountService = require(ServerScriptService.Server.Services.SynthCountService)
SynthCountService.init()

-- ── 5d. PatentService ─────────────────────────────────────────────────────
local PatentService = require(ServerScriptService.Server.Services.PatentService)
PatentService.init()

-- ── 6. SeedService ────────────────────────────────────────────────────────
local SeedService = require(ServerScriptService.Server.Services.SeedService)
SeedService.init()

-- ── 7. VaultService ───────────────────────────────────────────────────────
local VaultService = require(ServerScriptService.Server.Services.VaultService)
VaultService.init()

-- ── 8. SlotService ────────────────────────────────────────────────────────
local SlotService = require(ServerScriptService.Server.Services.SlotService)
SlotService.init()

-- ── 9. LabService ─────────────────────────────────────────────────────────
local LabService = require(ServerScriptService.Server.Services.LabService)
LabService.init()

-- ── 9b. MarketService ────────────────────────────────────────────────────
local MarketService = require(ServerScriptService.Server.Services.MarketService)
MarketService.init()

-- ── 10. StreakService ──────────────────────────────────────────────────────
local StreakService = require(ServerScriptService.Server.Services.StreakService)
StreakService.init()

-- ── 11. ContractService ───────────────────────────────────────────────────
local ContractService = require(ServerScriptService.Server.Services.ContractService)
ContractService.init()

-- ── 12. RankService ───────────────────────────────────────────────────────
local RankService = require(ServerScriptService.Server.Services.RankService)
RankService.init()

-- ── 13. LeaderboardService ────────────────────────────────────────────────
local LeaderboardService = require(ServerScriptService.Server.Services.LeaderboardService)
LeaderboardService.init()

-- ── 14. PrestigeService ───────────────────────────────────────────────────
local PrestigeService = require(ServerScriptService.Server.Services.PrestigeService)
PrestigeService.init()

-- ── Post-profile-load hooks (StreakService + ContractService) ──────────────
DataService.onProfileLoaded:Connect(function(userId)
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return
	end
	local data = DataService.getProfile(userId)
	StreakService.onLogin(player, data, os.time())
	ContractService.refreshIfStale(player, data, os.time())
end)

-- ── 9–N. Remaining services (wired up in Phases 4–11) ─────────────────────
-- ClockService, GlobalJobService, IncomeService,
-- LabService, RecipeService, MarketService, PatentService, SyndicateService,
-- JointSynthService, ExoticService, RankService, SprintService,
-- LeaderboardService, ContractService, StreakService, PrestigeService,
-- MonetizationService, EventService, CosmeticService, AnnouncementService,
-- AnalyticsService

-- ── PlayerAdded / PlayerRemoving — ALWAYS last ────────────────────────────
local function onPlayerAdded(player: Player)
	task.spawn(function()
		DataService.openSession(player)
		-- SlotService picks up onProfileLoaded signal and settles offline income.
	end)
end

local function onPlayerRemoving(player: Player)
	DataService.closeSession(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players already in-game when this script runs (Studio play-test edge case)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

print("GameInit: boot complete (Phase 7 — Prestige)")

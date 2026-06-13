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

-- ── 5. SeedService ────────────────────────────────────────────────────────
local SeedService = require(ServerScriptService.Server.Services.SeedService)
SeedService.init()

-- ── 6. SlotService ────────────────────────────────────────────────────────
local SlotService = require(ServerScriptService.Server.Services.SlotService)
SlotService.init()

-- ── 7–N. Remaining services (wired up in Phases 3–11) ─────────────────────
-- ClockService, GlobalJobService, IncomeService, VaultService,
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

print("GameInit: boot complete (Phase 2)")

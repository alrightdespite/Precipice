-- GameInit: server boot stub. Boot order per Plan IV H9.
-- Order: Config → Data tables → RemoteService → DataService → ClockService → services → PlayerAdded last.
-- No service may yield another's init.

local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

-- ── 1. Config ──────────────────────────────────────────────────────────────
-- (GameConfig and EconomyConstants loaded here when Phase 1 authors them)

-- ── 2. Data tables (generated; loaded by requiring shared modules) ─────────
-- Tables are required lazily by Core modules; no explicit init needed here.

-- ── 3. RemoteService ──────────────────────────────────────────────────────
local RemoteService = require(ServerScriptService.Server.Services.RemoteService)
RemoteService.init()

-- ── 4–N. Remaining services (stubs — wired up in Phases 1–11) ─────────────
-- DataService, ClockService, GlobalJobService, SlotService, IncomeService,
-- VaultService, LabService, RecipeService, MarketService, PatentService,
-- SyndicateService, JointSynthService, ExoticService, RankService,
-- SprintService, LeaderboardService, ContractService, StreakService,
-- PrestigeService, MonetizationService, EventService, CosmeticService,
-- AnnouncementService, AnalyticsService

-- ── PlayerAdded — ALWAYS last ──────────────────────────────────────────────
local function onPlayerAdded(_player: Player)
	-- Phase 1: wire DataService session open, offline income settle, remote state push.
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- Handle players who joined before this script ran (Studio testing edge case)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

print("GameInit: boot complete")

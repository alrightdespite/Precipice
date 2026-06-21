-- DebugService: Studio-only test hooks. NEVER active in production.
--
-- The DebugCommand remote is marked studioOnly in the Manifest, so RemoteService
-- does not even create it outside Studio (RunService:IsStudio()). init() also
-- bails early in production, so no handler is ever wired there.
--
-- Commands (invoke via DebugCommand:InvokeServer(cmd, arg1, arg2)):
--   "grantPellets",   amount                  → adds Pellets
--   "grantCatalysts", amount                  → adds Catalysts
--   "grantCompound",  compoundId, qty         → adds compound units to the vault
--   "discoverRecipe", resultId                → marks a recipe discovered
--   "completeSlot",   slotIndex               → natural completion (counts for patents/rank)
--   "announce",       message, tier?          → queues a §15 marquee announcement (test pipe)
--   "payDividends"                            → runs the Monday patent-dividend step now
--   "drainPending"                            → drains PendingCredits into the live session
--   "patentSweep"                             → runs the patent decay sweep (compounds + exotics)
--   "percentileJob"                           → recomputes the leaderboard percentile blob
--   "grantSprintPoints", amount               → adds Sprint ODS points (for archiveSprint tests)
--   "archiveSprint"                           → archives this week's Sprint + awards champions
--   "setPrestigeLevel", level                 → sets prestige.level (test PrestigeScreen)
--   "startEvent",      fluxAmount?            → starts a debug seasonal event + grants Flux
--   "grantRank",       amount                 → adds current-run rank points (Prestige gate test)
--   "qualifyJoint"                            → grants §17 T4 joint-synth qualification
--   "claimPatent",     compoundId             → simulates a natural patent claim (contest test)
--   "simulateOffline", hours?                 → backdates lastSeenAt + re-runs offline settle
--   "dumpProfile"                             → returns a state snapshot

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataService = require(ServerScriptService.Server.Services.DataService)
local RemoteService = require(ServerScriptService.Server.Services.RemoteService)
local VaultService = require(ServerScriptService.Server.Services.VaultService)
local SlotService = require(ServerScriptService.Server.Services.SlotService)
local AnnouncementService = require(ServerScriptService.Server.Services.AnnouncementService)
local PatentService = require(ServerScriptService.Server.Services.PatentService)
local RankService = require(ServerScriptService.Server.Services.RankService)
local EventService = require(ServerScriptService.Server.Services.EventService)
local SeedResolver = require(ReplicatedStorage.Shared.Core.SeedResolver)
local Compounds = require(ReplicatedStorage.Shared.Data.Compounds)

local DebugService = {}

local function fireBalance(player: Player, data: any)
	RemoteService.getEvent("BalanceUpdate"):FireClient(
		player,
		data.balances.pellets,
		data.balances.catalysts,
		data.monetization.rushUses,
		data.monetization.timerSkipUses or 0
	)
end

local function handle(player: Player, cmd: any, arg1: any, arg2: any): (boolean, any)
	local userId = player.UserId
	if not DataService.isLoaded(userId) then
		return false, "session not ready"
	end

	if cmd == "grantPellets" then
		local amount = tonumber(arg1)
		if not amount then
			return false, "amount must be a number"
		end
		DataService.updateProfile(userId, function(data)
			data.balances.pellets += amount
		end)
		fireBalance(player, DataService.getProfile(userId))
		return true, DataService.getProfile(userId).balances.pellets
	elseif cmd == "grantCatalysts" then
		local amount = tonumber(arg1)
		if not amount then
			return false, "amount must be a number"
		end
		DataService.updateProfile(userId, function(data)
			data.balances.catalysts += amount
		end)
		fireBalance(player, DataService.getProfile(userId))
		return true, DataService.getProfile(userId).balances.catalysts
	elseif cmd == "setPrestigeLevel" then
		-- Sets prestige.level directly (skips the 250k-rank prestige) so the
		-- §22 PrestigeScreen level display + SlotCapUpdate plumbing can be tested.
		local level = math.max(0, math.floor(tonumber(arg1) or 0))
		DataService.updateProfile(userId, function(data)
			data.prestige.level = level
		end)
		SlotService.fireSlotCap(player, DataService.getProfile(userId))
		return true, "prestige level set to " .. level
	elseif cmd == "startEvent" then
		-- Starts a debug seasonal event + grants Flux so the §29 Event UI can be tested.
		local amount = math.max(0, math.floor(tonumber(arg1) or 1000))
		local now = os.time()
		local seasonKey = "debug_season"
		EventService.setActiveEvent({
			isActive = true,
			seasonKey = seasonKey,
			startedAt = now,
			endAt = now + 24 * 3600,
			isFirstRun = true,
			milestoneTarget = 1000000,
			totalFluxEarned = 0,
			milestoneReached = false,
		})
		DataService.updateProfile(userId, function(data)
			data.eventState.fluxBySeason[seasonKey] = (data.eventState.fluxBySeason[seasonKey] or 0) + amount
		end)
		EventService.onLogin(player, DataService.getProfile(userId)) -- fires FluxUpdate
		return true, "event started, flux=" .. amount
	elseif cmd == "grantRank" then
		-- Adds current-run rank points (uncapped "synthesis" source) so the Prestige
		-- reset (250k rank gate) is testable. Fires RankUpdate.
		local n = math.max(0, math.floor(tonumber(arg1) or 0))
		DataService.updateProfile(userId, function(data)
			RankService.addScore(player, data, n, "synthesis")
		end)
		return true, "granted rank " .. n .. " (currentRun=" .. DataService.getProfile(userId).rank.currentRun .. ")"
	elseif cmd == "qualifyJoint" then
		-- Grants the §17 T4 joint-synthesis qualification so Joint Synthesis is testable
		-- without grinding a natural T4 completion.
		DataService.updateProfile(userId, function(data)
			data.prestige.jointQualLifetime = true
		end)
		return true, "joint qualification granted"
	elseif cmd == "claimPatent" then
		-- Simulates a natural-synthesis patent claim (world-first / contest / queue) so the
		-- multi-player patent flow is testable without the full synth+reveal sequence.
		local cid = tostring(arg1)
		if not Compounds[cid] then
			return false, "unknown compound: " .. cid
		end
		local didClaim = PatentService.recordNaturalSynthesis(player, cid, DataService.getProfile(userId), os.time())
		return true, "claimPatent " .. cid .. " didClaim=" .. tostring(didClaim)
	elseif cmd == "simulateOffline" then
		-- Backdates lastSeenAt then re-runs the login offline settle, so the offline-income
		-- time-gap path (running slots → passive income + offline completions) is testable.
		local hours = tonumber(arg1) or 4
		DataService.updateProfile(userId, function(data)
			data.lastSeenAt = os.time() - math.floor(hours * 3600)
		end)
		SlotService.settleOfflineNow(userId)
		return true, "simulated " .. hours .. "h offline"
	elseif cmd == "grantCompound" then
		local compoundId = tostring(arg1)
		local qty = math.max(1, math.floor(tonumber(arg2) or 1))
		if not Compounds[compoundId] then
			return false, "unknown compound: " .. compoundId
		end
		DataService.updateProfile(userId, function(data)
			VaultService.applyAward(data, compoundId, qty)
		end)
		VaultService.fireVaultUpdate(player, DataService.getProfile(userId))
		return true, DataService.getProfile(userId).vault.compounds[compoundId]
	elseif cmd == "discoverRecipe" then
		local resultId = tostring(arg1)
		if not Compounds[resultId] then
			return false, "unknown compound: " .. resultId
		end
		DataService.updateProfile(userId, function(data)
			data.formulaLog.discovered[resultId] = true
		end)
		return true, "discovered " .. resultId
	elseif cmd == "completeSlot" then
		local slotIndex = math.floor(tonumber(arg1) or 0)
		local ok = SlotService.forceCompleteSlot(player, slotIndex)
		return ok, ok and ("slot " .. slotIndex .. " completed") or "no running slot at index"
	elseif cmd == "announce" then
		-- Exercises the §15 marquee pipe (queue → MessagingService publish → Announcement S2C).
		AnnouncementService.broadcast("debug", tostring(arg1), tonumber(arg2))
		return true, "announcement queued"
	elseif cmd == "payDividends" then
		-- Runs the Monday dividend step directly (unique weekKey so it always pays).
		PatentService.payDividends("debug:" .. tostring(os.time()), os.time())
		return true, "dividends paid"
	elseif cmd == "drainPending" then
		-- Drains PendingCredits into the live session (same call openSession makes at login).
		DataService.drainPending(userId, DataService.getProfile(userId))
		return true, DataService.getProfile(userId).balances.pellets
	elseif cmd == "patentSweep" then
		-- Runs the 900s patent decay sweep now (resolves expired defense windows).
		PatentService.runDecaySweep(os.time())
		return true, "patent sweep run"
	elseif cmd == "percentileJob" then
		-- Recomputes the leaderboard percentile blob now (hourly job, §21).
		local LeaderboardService = require(ServerScriptService.Server.Services.LeaderboardService)
		LeaderboardService.computePercentileBlob(os.time())
		return true, "percentile blob computed"
	elseif cmd == "grantSprintPoints" then
		-- Seed a Sprint ODS score so archiveSprint has a champion to award.
		local amount = math.max(1, math.floor(tonumber(arg1) or 1000))
		RankService.addSprintPoints(player, DataService.getProfile(userId), amount, os.time())
		return true, "granted " .. amount .. " sprint points"
	elseif cmd == "archiveSprint" then
		-- Archives the current week's Sprint + awards champion badges.
		local week = SeedResolver.getCurrentWeekNumber(os.time())
		RankService.archiveSprint(week)
		return true, "archived sprint week " .. week
	elseif cmd == "dumpProfile" then
		local data = DataService.getProfile(userId)
		return true, {
			pellets = data.balances.pellets,
			catalysts = data.balances.catalysts,
			vault = data.vault.compounds,
			slots = data.slots,
			discovered = data.formulaLog.discovered,
			prestige = data.prestige,
			championships = data.championships,
			cosmetics = data.cosmetics,
			rank = data.rank,
			contracts = data.contracts,
		}
	end

	return false, "unknown command: " .. tostring(cmd)
end

function DebugService.init()
	-- Production: the studioOnly remote does not exist, so do not touch it.
	if not RunService:IsStudio() then
		return
	end
	RemoteService.setInvoke("DebugCommand", function(player, cmd, arg1, arg2)
		-- handle returns (ok, result); pcall wraps it once so the command runs exactly once.
		local results = table.pack(pcall(handle, player, cmd, arg1, arg2))
		if not results[1] then
			warn("[DebugService] command error:", results[2])
			return false, tostring(results[2])
		end
		return results[2], results[3]
	end)
end

return DebugService

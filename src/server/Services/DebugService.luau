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
--   "grantSprintPoints", amount               → adds Sprint ODS points (for archiveSprint tests)
--   "archiveSprint"                           → archives this week's Sprint + awards champions
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

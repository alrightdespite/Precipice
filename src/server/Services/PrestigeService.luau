-- PrestigeService: eligibility check, soft reset, patent fan-out (doc §22, R5, C19).
-- All dependencies injected for Lune testability — no Roblox globals at module level.

-- ── Injected state ─────────────────────────────────────────────────────────

local _dataService: any = nil
local _vaultService: any = nil
local _slotService: any = nil
local _contractService: any = nil
local _streakService: any = nil
local _rankService: any = nil
local _marketService: any = nil
local _patentService: any = nil
local _remoteService: any = nil
local _economyConstants: any = nil
local _profileTemplate: any = nil
local _jointService: any = nil
local _syndicateService: any = nil
local _analyticsService: any = { track = function() end, Events = {} }

local PrestigeService = {}

-- ── Injection helpers ──────────────────────────────────────────────────────

function PrestigeService._setAnalyticsService(as: any) _analyticsService = as end
function PrestigeService._setDataService(ds: any) _dataService = ds end
function PrestigeService._setVaultService(vs: any) _vaultService = vs end
function PrestigeService._setSlotService(ss: any) _slotService = ss end
function PrestigeService._setContractService(cs: any) _contractService = cs end
function PrestigeService._setStreakService(ss: any) _streakService = ss end
function PrestigeService._setRankService(rs: any) _rankService = rs end
function PrestigeService._setMarketService(ms: any) _marketService = ms end
function PrestigeService._setPatentService(ps: any) _patentService = ps end
function PrestigeService._setRemoteService(rs: any) _remoteService = rs end
function PrestigeService._setEconomyConstants(ec: any) _economyConstants = ec end
function PrestigeService._setProfileTemplate(pt: any) _profileTemplate = pt end
function PrestigeService._setJointService(js: any) _jointService = js end
function PrestigeService._setSyndicateService(ss: any) _syndicateService = ss end

-- ── Helpers ────────────────────────────────────────────────────────────────

-- Pellet cost for prestige level N (1-indexed: cost to enter level N).
local function prestigeCost(level: number): number
	local EC = _economyConstants
	if level <= 7 then
		return EC.PRESTIGE_COSTS[level]
	end
	return math.round(
		EC.PRESTIGE_COSTS[7] * (EC.PRESTIGE_COST_MULTIPLIER_8PLUS ^ (level - 7))
	)
end

-- ── Public API ─────────────────────────────────────────────────────────────

-- Returns list of human-readable blocker strings. Empty list = eligible (R5).
-- player is optional; joint slot checks are skipped when nil.
function PrestigeService.getBlockers(data: any, player: any?): { string }
	local blockers: { string } = {}

	-- 1. Rank gate: must have earned 250,000 current-run points
	if data.rank.currentRun < 250000 then
		table.insert(blockers, "Chief Scientist rank required (250,000 points)")
	end

	-- 2. Pellet cost
	local nextLevel = (data.prestige.level or 0) + 1
	local cost = prestigeCost(nextLevel)
	if data.balances.pellets < cost then
		table.insert(
			blockers,
			"Insufficient Pellets (need " .. tostring(cost) .. ", have " .. tostring(data.balances.pellets) .. ")"
		)
	end

	-- 3. Any personal slot is running
	for _, slot in ipairs(data.slots or {}) do
		if slot.workRemaining > 0 then
			table.insert(blockers, "A synthesis slot is still running")
			break
		end
	end

	-- 4. Any personal slot holds an unrevealed result
	for _, slot in ipairs(data.slots or {}) do
		if slot.workRemaining <= 0 then
			table.insert(blockers, "A slot has an unrevealed result")
			break
		end
	end

	-- 5. Active joint staging or running run involving this player.
	if player and data.syndicate and _jointService and _syndicateService then
		local syndicateId = data.syndicate.id
		local record = _syndicateService.getRecord(syndicateId)
		if record then
			for _, slot in pairs(record.jointSlots or {}) do
				if slot.state == "STAGED" and slot.openerId == player.UserId then
					table.insert(blockers, "A joint synthesis staging is pending")
					break
				end
				if slot.state == "RUNNING"
					and (slot.openerId == player.UserId or slot.partnerId == player.UserId)
				then
					table.insert(blockers, "A joint synthesis run is in progress")
					break
				end
			end
		end
	end

	return blockers
end

-- Runs before the reset inside DataService.updateProfile. Mutates data.
function PrestigeService.preReset(player: any, data: any)
	-- Step 1: cancel all active market listings (compounds return to vault before wipe)
	if _marketService then
		_marketService.cancelAllForUser(player)
	end

	-- Step 2: drain PendingCredits so offline credits land before balance wipe
	if _dataService then
		_dataService.drainPending(player.UserId, data)
	end
end

-- Applies the §22 reset table. Called inside DataService.updateProfile.
function PrestigeService.executeReset(player: any, data: any, now: number)
	-- Vault wipe
	data.vault.compounds = {}
	data.vault.residue = 0

	-- Balances: pellets floored to starting balance; catalysts preserved
	data.balances.pellets = 500

	-- Slots cleared
	data.slots = {}

	-- Contracts reset
	data.contracts = { dayKey = "", slots = {} }

	-- Streak reset
	data.streak = { day = 0, lastLoginAt = 0 }

	-- Rank: currentRun reset, lifetime preserved, dailyCaps reset
	data.rank.currentRun = 0
	data.rank.dailyCaps = { date = "", marketPoints = 0, vaultPoints = 0 }
	-- data.rank.lifetime: preserved

	-- sprintPoints: preserved (Sprint is its own weekly counter)

	-- formulaLog: preserved (discoveries survive prestige)

	-- Prestige: increment level
	data.prestige.level = (data.prestige.level or 0) + 1
	-- prestige.jointQualLifetime: preserved

	-- monetization, cosmetics, eventState, pendingCreditsApplied: preserved

	data.lastSeenAt = now

	-- Write ChiefBoard ODS with preserved lifetime score
	if _rankService then
		_rankService.writeChiefBoardScore(player, data)
	end
end

-- Runs after profile reset is committed. Releases patents outside the profile lock.
function PrestigeService.releaseFanOut(player: any, now: number)
	if _patentService then
		_patentService.releaseAllForUser(player.UserId, now)
	end
end

-- ── Production init ────────────────────────────────────────────────────────

function PrestigeService.init()
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	_dataService = require(ServerScriptService.Server.Services.DataService)
	_rankService = require(ServerScriptService.Server.Services.RankService)
	_marketService = require(ServerScriptService.Server.Services.MarketService)
	_patentService = require(ServerScriptService.Server.Services.PatentService)
	_remoteService = require(ServerScriptService.Server.Services.RemoteService)
	_analyticsService = require(ServerScriptService.Server.Services.AnalyticsService)
	_economyConstants = require(ReplicatedStorage.Shared.Config.EconomyConstants)
	_profileTemplate = require(ReplicatedStorage.Shared.Core.ProfileTemplate)

	-- PrestigeRequest: check eligibility, return blockers
	_remoteService.setInvoke("PrestigeRequest", function(player: Player)
		local data = _dataService.getProfile(player.UserId)
		local blockers = PrestigeService.getBlockers(data, player)
		if #blockers > 0 then
			return { ok = false, blockers = blockers }
		end
		return { ok = true, blockers = {} }
	end)

	-- PrestigeConfirm: double-check then execute
	_remoteService.setInvoke("PrestigeConfirm", function(player: Player)
		local data = _dataService.getProfile(player.UserId)
		local blockers = PrestigeService.getBlockers(data, player)
		if #blockers > 0 then
			return { ok = false, err = blockers[1] }
		end

		local now = os.time()

		_dataService.updateProfile(player.UserId, function(d)
			PrestigeService.preReset(player, d)
			PrestigeService.executeReset(player, d, now)
		end)

		PrestigeService.releaseFanOut(player, now)

		-- Fire RankUpdate so client sees currentRun = 0 immediately
		if _rankService then
			local freshData = _dataService.getProfile(player.UserId)
			_rankService.addScore(player, freshData, 0, "synthesis")
		end

		-- Prestige 1/3/5 each grant +1 slot (§8); re-push the cap.
		local SlotService = require(ServerScriptService.Server.Services.SlotService)
		SlotService.fireSlotCap(player, _dataService.getProfile(player.UserId))

		_analyticsService.track(_analyticsService.Events.PRESTIGE or "prestige", {
			userId = player.UserId,
			level = _dataService.getProfile(player.UserId).prestige.level,
		})

		return { ok = true }
	end)
end

return PrestigeService

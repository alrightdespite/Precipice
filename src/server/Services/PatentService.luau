-- PatentService: compound patent ownership, challenges, defense windows, dividends.
-- DataStore: Patents, key "patent:{compoundId}" per compound.
-- Pure window/immunity math delegated to PatentWindow (Core).
-- All dependencies injected for Lune testability — no Roblox globals at module level.
-- See docs/specs/PatentService.md, §15, H1, R2, R3, R12, R13.

-- ── Injected state ─────────────────────────────────────────────────────────

local _ds: any = nil -- DataStore("Patents")
local _scs: any = nil -- SynthCountService
local _rs: any = nil -- RemoteService
local _compounds: any = nil -- Compounds data table (for sweep iteration)
local _pw: any = nil -- PatentWindow module
local _eventCompounds: any = nil -- EventCompounds data table
local _eventService: any = nil -- EventService (for event patent guards)
local _announcementService: any = nil -- AnnouncementService (§15 marquee; optional)
local _analyticsService: any = { track = function() end, Events = {} }

-- ── Module ─────────────────────────────────────────────────────────────────

local PatentService = {}

-- Test injection helpers. Production uses init().
function PatentService._setAnalyticsService(as: any) _analyticsService = as end
function PatentService._setDs(ds: any)
	_ds = ds
end
function PatentService._setScs(scs: any)
	_scs = scs
end
function PatentService._setRs(rs: any)
	_rs = rs
end
function PatentService._setCompounds(c: any)
	_compounds = c
end
function PatentService._setPw(pw: any)
	_pw = pw
end
function PatentService._setEventCompounds(ec: any)
	_eventCompounds = ec
end
function PatentService._setEventService(es: any)
	_eventService = es
end
function PatentService._setAnnouncementService(as: any)
	_announcementService = as
end

function PatentService.isEventCompound(compoundId: string): boolean
	return _eventCompounds ~= nil and _eventCompounds[compoundId] ~= nil
end

-- ── Internal helpers ───────────────────────────────────────────────────────

-- Deep-enough copy for patent records: top-level fields + a fresh challengeQueue array.
local function copyRecord(record: any): any
	return {
		compoundId = record.compoundId,
		tier = record.tier,
		holderId = record.holderId,
		firstClaimantId = record.firstClaimantId,
		challenge = record.challenge, -- immutable value; replaced, never mutated
		immunityUntil = record.immunityUntil,
		synthLeaderId = record.synthLeaderId,
		challengeQueue = { table.unpack(record.challengeQueue or {}) },
		dividendPaidThruWeek = record.dividendPaidThruWeek,
	}
end

-- ── Public API ─────────────────────────────────────────────────────────────

-- Called by SlotService on every natural reveal (§14, isNatural = true).
-- player: Player (or mock {UserId} in tests)
-- compoundId: the synthesised compound
-- data: player profile (unused here; tier read from Compounds authoritative source)
-- now: injectable for tests; defaults to os.time() in production
function PatentService.recordNaturalSynthesis(player: any, compoundId: string, _data: any, now: number?)
	now = now or os.time()
	local userId = player.UserId

	-- Step 1: record completion in SynthCounts (SEPARATE write, different key — never
	-- nest DataStore calls inside an UpdateAsync transform).
	_scs.recordCompletion(compoundId, userId, now)

	-- Pre-fetch event state (cannot make DS calls inside UpdateAsync transform)
	local isEv = PatentService.isEventCompound(compoundId)
	local evFirstRun = isEv and _eventService ~= nil and (_eventService.isFirstRun() == true)
	local evActive = isEv and _eventService ~= nil and (_eventService.isEventActive() == true)

	-- Peek at current record to learn the holder/challenger IDs needed for count queries.
	-- (Cannot read DataStore inside an UpdateAsync transform in production.)
	local peek = _ds:GetAsync("patent:" .. compoundId)

	-- Pre-fetch counts so they are available inside the UpdateAsync closure.
	local myCount = _scs.getCountForUser(compoundId, userId, 30, now)
	local holderCount = peek and _scs.getCountForUser(compoundId, peek.holderId, 30, now) or 0
	local challengerCount = (peek and peek.challenge)
		and _scs.getCountForUser(compoundId, peek.challenge.challengerId, 30, now)
		or 0

	-- Outcome flags written by the UpdateAsync closure; read below to fire remotes.
	local didClaim = false
	local challengeOpened = false
	local challengeWindowEnd: number? = nil

	_ds:UpdateAsync("patent:" .. compoundId, function(record)
		-- ── First ever claim ──────────────────────────────────────────────
		if record == nil then
			didClaim = true
			local compound = _compounds[compoundId]
			return {
				compoundId = compoundId,
				tier = compound and compound.tier or 1,
				holderId = userId,
				firstClaimantId = userId,
				challenge = nil,
				immunityUntil = nil,
				synthLeaderId = userId,
				challengeQueue = {},
				dividendPaidThruWeek = nil,
			}
		end

		-- ── Event patent: first-run → permanent, uncontestable ───────────
		if isEv and evFirstRun then
			return nil
		end

		-- ── Immunity: new holder cannot be challenged yet ─────────────────
		if _pw.isInImmunity(record, now) then
			return nil
		end

		-- ── Challenge already active ──────────────────────────────────────
		if _pw.isChallengeActive(record, now) then
			-- Already the challenger or the holder: no-op
			if userId == record.challenge.challengerId or userId == record.holderId then
				return nil
			end
			-- Third party: queue if count exceeds BOTH holder and current challenger (§15)
			if myCount > holderCount and myCount > challengerCount then
				local alreadyQueued = false
				for _, q in ipairs(record.challengeQueue or {}) do
					if q.challengerId == userId then
						alreadyQueued = true
						break
					end
				end
				if not alreadyQueued then
					local newRecord = copyRecord(record)
					table.insert(newRecord.challengeQueue, { challengerId = userId })
					return newRecord
				end
			end
			return nil
		end

		-- ── No active challenge, no immunity: open one if warranted ───────
		-- Between event runs: event compounds are uncontestable (doc §29)
		if isEv and not evActive then
			return nil
		end
		if userId == record.holderId then
			return nil -- can't challenge your own patent
		end
		if myCount > holderCount then
			local newRecord = copyRecord(record)
			newRecord.challenge = _pw.newChallenge(record, userId, now)
			challengeOpened = true
			challengeWindowEnd = newRecord.challenge.windowEnd
			return newRecord
		end

		-- Synthesis counted; no state change needed
		return nil
	end)

	-- Fire remotes after UpdateAsync (outside the transform, outside any lock).
	if _rs then
		if didClaim then
			_rs.getEvent("PatentClaim"):FireClient(player, compoundId, userId, true)
			_analyticsService.track(_analyticsService.Events.PATENT_CLAIM or "patent_claim", {
				userId = userId,
				compoundId = compoundId,
			})
			-- §15: first claims announce globally at every patentable tier. The claimant is the
			-- local player, so the name is available without an async lookup.
			if _announcementService then
				local compound = _compounds[compoundId]
				_announcementService.announceFirstClaim(compoundId, player.Name, compound and compound.tier or 2)
			end
		elseif challengeOpened then
			_rs.getEvent("PatentChallengeAlert"):FireClient(player, compoundId, challengeWindowEnd)
		end
	end

	-- True when this completion was the first-ever claim (world-first). Lets the
	-- reveal flow show the WORLD FIRST banner authoritatively instead of racing
	-- the PatentClaim S2C event (see RevealController).
	return didClaim
end

-- Called by GlobalJobService as the "decaySweep" step of PatentDividendSweep (H1, R2).
-- Runs every sweepIntervalSeconds (900s). Iterates the finite compound set.
-- now: injectable for tests; defaults to os.time() in production.
function PatentService.runDecaySweep(now: number?)
	now = now or os.time()

	for compoundId, _ in pairs(_compounds) do
		local patentKey = "patent:" .. compoundId

		-- Cheap pre-filter: skip unclaimed or non-expired compounds
		local peek = _ds:GetAsync(patentKey)
		if peek == nil then
			continue
		end
		if not _pw.windowExpired(peek, now) then
			continue
		end

		-- Pre-fetch counts before UpdateAsync transform (no DS reads inside transform)
		local holderCount = _scs.getCountForUser(compoundId, peek.holderId, 30, now)
		local challengerCount = _scs.getCountForUser(
			compoundId,
			peek.challenge.challengerId,
			30,
			now
		)

		local winnerId = (challengerCount > holderCount) and peek.challenge.challengerId
			or peek.holderId

		_ds:UpdateAsync(patentKey, function(record)
			if record == nil then
				return nil
			end
			-- Guard: another server may have already resolved this window
			if not _pw.windowExpired(record, now) then
				return nil
			end

			local newRecord = copyRecord(record)
			newRecord.holderId = winnerId
			newRecord.synthLeaderId = winnerId
			newRecord.challenge = nil
			newRecord.immunityUntil = nil

			-- Process challengeQueue: pop front and open a new window immediately,
			-- OR apply immunity to the new holder if queue is empty.
			if #newRecord.challengeQueue > 0 then
				local next = table.remove(newRecord.challengeQueue, 1)
				-- newRecord.tier is still correct (unchanged from copyRecord)
				newRecord.challenge = _pw.newChallenge(newRecord, next.challengerId, now)
				-- No immunity: queued challenger had priority
			else
				newRecord.immunityUntil = now + _pw.immunitySeconds
			end

			return newRecord
		end)

		-- §15: a patent transfer (holder actually changed) announces globally only at T4+.
		-- Cosmetic marquee (F2) — a duplicate across servers is harmless (dedup + 30s gap).
		if _announcementService and winnerId ~= peek.holderId and peek.tier >= 4 then
			_announcementService.announcePatentTransfer(compoundId, peek.holderId, winnerId, peek.tier)
		end
	end
end

-- Release all patents held by userId. Called by PrestigeService after profile reset.
-- Clears holderId, challenge, challengeQueue, immunityUntil so the next natural
-- completion can claim the patent (doc §22, R6).
-- Does NOT reset SynthCounts — 30-day counts survive prestige (R6).
-- Returns count released.
function PatentService.releaseAllForUser(userId: number, now: number?): number
	now = now or os.time()
	local released = 0

	for compoundId, _ in pairs(_compounds) do
		_ds:UpdateAsync("patent:" .. compoundId, function(record)
			if record == nil then return nil end
			if record.holderId ~= userId then return nil end
			local newRecord = copyRecord(record)
			newRecord.holderId = nil
			newRecord.challenge = nil
			newRecord.challengeQueue = {}
			newRecord.immunityUntil = nil
			released += 1
			return newRecord
		end)
	end

	-- TODO Phase 10: announce patent releases as transfers for T4+
	return released
end

-- Simple read — used by UI remotes and tests.
function PatentService.getRecord(compoundId: string): any
	return _ds:GetAsync("patent:" .. compoundId)
end

-- Monday job step 1 (R3 mandated order: dividends → Sprint archive → seed).
-- weekKey: e.g. "2026-W24" — uniquely identifies this payout run.
function PatentService.payDividends(_weekKey: string, _now: number?)
	-- TODO Phase 6: dividend payout via PendingCredits per R3 step 1
end

-- ── Production init ────────────────────────────────────────────────────────

function PatentService.init()
	local DataStoreService = game:GetService("DataStoreService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	_ds = DataStoreService:GetDataStore("Patents")
	_pw = require(ReplicatedStorage.Shared.Core.PatentWindow)
	_compounds = require(ReplicatedStorage.Shared.Data.Compounds)
	_scs = require(ServerScriptService.Server.Services.SynthCountService)
	_rs = require(ServerScriptService.Server.Services.RemoteService)
	_analyticsService = require(ServerScriptService.Server.Services.AnalyticsService)

	-- Wire PatentQuery C2S remote (rate-limited via setInvoke)
	_rs.setInvoke("PatentQuery", function(_player: Player, compoundId: any)
		if type(compoundId) ~= "string" then
			return nil
		end
		return PatentService.getRecord(compoundId)
	end)

	-- PatentDividendSweep is driven by ClockService: it attempts the GlobalJobService claim
	-- every 900s (PatentWindow.sweepIntervalSeconds) via ClockService._runPatentSweep.
end

return PatentService

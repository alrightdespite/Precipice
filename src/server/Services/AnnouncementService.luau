-- AnnouncementService: cross-server marquee announcements (§15, A22, H3/F2).
--
-- Publishes global lines (patent first-claims, T4+ patent transfers, world-first Exotics, the
-- weekly seed epoch) over MessagingService and fans them out to every connected client via the
-- Announcement S2C remote. Per §15: first claims are global at all patentable tiers; transfers
-- are global only at T4+; all lines pass through a 30s min-gap queue (AnnouncementQueue).
--
-- H3/F2: the marquee is the one thing explicitly allowed to ride messages alone — it is purely
-- cosmetic (a missed line on one server costs nothing). Announcements never mutate state, so
-- there is no authoritative record to re-verify; the queue's dedup is best-effort per-server.

local MIN_GAP = 30 -- seconds between global broadcasts (§15)
local DEDUP_TTL = 7 * 24 * 3600 -- one epoch: suppress the same event re-broadcasting this week
local TOPIC = "PrecipiceAnnouncements"

local AnnouncementService = {}

-- ── Injected / initialized state ───────────────────────────────────────────
local _rs: any = nil -- RemoteService
local _players: any = nil
local _messaging: any = nil
local _compounds: any = nil
local _queue: any = nil
local _serverId: string = ""
local _spawnFn: (((() -> ()) -> ())) = function(fn)
	fn()
end

local function compoundName(compoundId: string): string
	local c = _compounds and _compounds[compoundId]
	return (c and c.name) or compoundId
end

local function resolveName(userId: number): string
	if not _players then
		return "Researcher #" .. tostring(userId)
	end
	local online = _players:GetPlayerByUserId(userId)
	if online then
		return online.Name
	end
	local ok, name = pcall(function()
		return _players:GetNameFromUserIdAsync(userId)
	end)
	return (ok and name) or ("Researcher #" .. tostring(userId))
end

local function fanOutLocal(kind: string, message: string, tier: number?)
	if not _rs then
		return
	end
	local ev = _rs.getEvent("Announcement")
	for _, player in ipairs(_players:GetPlayers()) do
		ev:FireClient(player, kind, message, tier)
	end
end

-- ── Public broadcast API ────────────────────────────────────────────────────

-- Enqueue a pre-formatted line. The worker releases it with the 30s gap and publishes it.
function AnnouncementService.broadcast(kind: string, message: string, tier: number?, dedupKey: string?)
	if not _queue then
		return
	end
	_queue:enqueue({ kind = kind, message = message, tier = tier, dedupKey = dedupKey }, os.time())
end

-- Patent first-claim — global at every patentable tier (§15). claimantName is supplied by the
-- caller (the claimant is the local player who just revealed), so no async name lookup is needed.
function AnnouncementService.announceFirstClaim(compoundId: string, claimantName: string, tier: number)
	AnnouncementService.broadcast(
		"patent_first",
		string.format("⬡ WORLD FIRST — %s claimed the patent on %s (T%d).", claimantName, compoundName(compoundId), tier),
		tier,
		"first:" .. compoundId
	)
end

-- Patent transfer — global only at T4+ (§15). Names may be offline, so resolve them off the
-- caller's thread.
function AnnouncementService.announcePatentTransfer(compoundId: string, fromUserId: number, toUserId: number, tier: number)
	if tier < 4 then
		return -- T2–T3 transfers notify only the two parties + Formula Log (§15)
	end
	_spawnFn(function()
		local toName = resolveName(toUserId)
		local fromName = resolveName(fromUserId)
		AnnouncementService.broadcast(
			"patent_transfer",
			string.format("⬡ PATENT TAKEN — %s has taken the patent on %s from %s.", toName, compoundName(compoundId), fromName),
			tier,
			"transfer:" .. compoundId .. ":" .. tostring(toUserId)
		)
	end)
end

-- World-first Exotic synthesis (§13/§15).
function AnnouncementService.announceWorldFirstExotic(exoticId: string, claimantName: string)
	AnnouncementService.broadcast(
		"exotic_first",
		string.format("⬡ WORLD FIRST EXOTIC — %s synthesised %s!", claimantName, exoticId),
		7,
		"exotic:" .. exoticId
	)
end

-- Weekly seed epoch / new week (§15, R3 step 4). Called by ClockService's seedEpoch step.
function AnnouncementService.announceSeedEpoch(weekNumber: number)
	AnnouncementService.broadcast(
		"seed_epoch",
		string.format("⟳ A new research week has begun (week %d). Variable recipes may have shifted.", weekNumber),
		nil,
		"seed:" .. tostring(weekNumber)
	)
end

-- ── Init ───────────────────────────────────────────────────────────────────

function AnnouncementService.init()
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local AnnouncementQueue = require(ReplicatedStorage.Shared.Core.AnnouncementQueue)

	_rs = require(ServerScriptService.Server.Services.RemoteService)
	_players = game:GetService("Players")
	_messaging = game:GetService("MessagingService")
	_compounds = require(ReplicatedStorage.Shared.Data.Compounds)
	_queue = AnnouncementQueue.new(MIN_GAP, DEDUP_TTL)
	_serverId = (game.JobId ~= "" and game.JobId) or ("dev-" .. tostring(math.random(1, 99999)))
	_spawnFn = task.spawn

	-- Subscribe for lines published by other servers (hint only, F2). The origin server fans out
	-- locally on release, so skip our own messages to avoid showing each line twice here.
	local ok, err = pcall(function()
		_messaging:SubscribeAsync(TOPIC, function(packet)
			local d = packet.Data
			if type(d) ~= "table" or d.origin == _serverId then
				return
			end
			fanOutLocal(d.kind, d.message, d.tier)
		end)
	end)
	if not ok then
		warn("AnnouncementService: MessagingService subscribe failed:", err)
	end

	-- Release worker: one line per >=30s. Fan out locally immediately (origin sees it without the
	-- round-trip) and publish for the other servers.
	_spawnFn(function()
		while true do
			task.wait(1)
			local item = _queue:release(os.time())
			if item then
				fanOutLocal(item.kind, item.message, item.tier)
				local pubOk, pubErr = pcall(function()
					_messaging:PublishAsync(TOPIC, {
						origin = _serverId,
						kind = item.kind,
						message = item.message,
						tier = item.tier,
					})
				end)
				if not pubOk then
					warn("AnnouncementService: PublishAsync failed:", pubErr)
				end
			end
		end
	end)

	print("AnnouncementService: ready")
end

return AnnouncementService

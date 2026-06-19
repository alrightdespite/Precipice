-- SyndicateService: syndicate CRUD, vault, upgrades, invites, T4 qual helper. Phase 10A.
-- No Roblox globals at module level — Lune-testable via injection helpers.

-- ── Injected state ─────────────────────────────────────────────────────────

local _dataService: any = nil
local _remoteService: any = nil
local _rankService: any = nil
local _economyConstants: any = nil
local _textService: any = nil
local _syndicateDs: any = nil
local _pendingInviteDs: any = nil
local _profileDs: any = nil -- DataStoreService:GetDataStore("PlayerData_v1") for offline writes
local _players: any = nil

local _pendingDisbands: { [number]: string } = {} -- userId → syndicateId awaiting confirm

local SyndicateService = {}

-- ── Injection helpers ──────────────────────────────────────────────────────

function SyndicateService._setDataService(s: any) _dataService = s end
function SyndicateService._setRemoteService(s: any) _remoteService = s end
function SyndicateService._setRankService(s: any) _rankService = s end
function SyndicateService._setEconomyConstants(s: any) _economyConstants = s end
function SyndicateService._setTextService(s: any) _textService = s end
function SyndicateService._setSyndicateDs(s: any) _syndicateDs = s end
function SyndicateService._setPendingInviteDs(s: any) _pendingInviteDs = s end
function SyndicateService._setProfileDs(s: any) _profileDs = s end
function SyndicateService._setPlayers(s: any) _players = s end
function SyndicateService._resetPendingDisbands() _pendingDisbands = {} end

-- ── ID generation ──────────────────────────────────────────────────────────

local function newSyndicateId(): string
	return "syn_" .. tostring(math.floor(os.time())) .. "_" .. tostring(math.random(1000, 9999))
end

-- ── Read/write helpers ─────────────────────────────────────────────────────

local function normalizeMemberKeys(record: any): any?
	if not record or not record.members then return record end
	local fixed = {}
	for k, v in pairs(record.members) do
		fixed[tonumber(k) or k] = v
	end
	record.members = fixed
	return record
end

local function getRecord(syndicateId: string): any?
	return normalizeMemberKeys(_syndicateDs:GetAsync("syndicate:" .. syndicateId))
end

local function updateRecord(syndicateId: string, fn: (any) -> any?)
	_syndicateDs:UpdateAsync("syndicate:" .. syndicateId, function(record)
		return fn(normalizeMemberKeys(record))
	end)
end

-- Public accessor for JointSynthService (Phase 10B)
SyndicateService.getRecord = getRecord

-- ── Member cap ─────────────────────────────────────────────────────────────

local function getMemberCap(record: any): number
	return if record.upgrades.memberCapExpanded
		then _economyConstants.SYNDICATE_MEMBER_CAP_EXPANDED
		else _economyConstants.SYNDICATE_MEMBER_CAP_BASE
end

local function countMembers(record: any): number
	local n = 0
	for _ in pairs(record.members) do
		n += 1
	end
	return n
end

-- ── Joint slot count ───────────────────────────────────────────────────────

function SyndicateService.getJointSlotCount(syndicateId: string): number
	local record = getRecord(syndicateId)
	if record == nil then return 0 end
	return if record.upgrades.thirdSlot then 3 else 2
end

-- ── Text filtering ─────────────────────────────────────────────────────────

local function filterName(name: string, userId: number): (string?, string?)
	local ok, result = pcall(function()
		local filterResult = _textService:FilterStringAsync(name, userId)
		return filterResult:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or result == nil then
		return nil, "name filter failed"
	end
	return result, nil
end

-- ── S2C helpers ────────────────────────────────────────────────────────────

function SyndicateService.fireSyndicateUpdate(player: any, record: any?)
	if _remoteService then
		_remoteService.getEvent("SyndicateUpdate"):FireClient(player, record)
	end
end

function SyndicateService.fireUpdateToAllMembers(record: any)
	for memberId in pairs(record.members) do
		local p = _players:GetPlayerByUserId(memberId)
		if p then
			SyndicateService.fireSyndicateUpdate(p, record)
		end
	end
end

-- ── Pending invite check (called on login) ─────────────────────────────────

function SyndicateService.checkPendingInvite(player: any)
	local userId = player.UserId
	local invite = _pendingInviteDs:GetAsync("pendingInvite:" .. tostring(userId))
	if invite == nil then return end
	if os.time() > invite.expiresAt then
		_pendingInviteDs:RemoveAsync("pendingInvite:" .. tostring(userId))
		return
	end
	local record = getRecord(invite.syndicateId)
	local syndicateName = record and record.name or "Unknown Syndicate"
	if _remoteService then
		_remoteService.getEvent("SyndicateInviteReceived"):FireClient(
			player,
			invite.syndicateId,
			invite.inviterId,
			syndicateName
		)
	end
end

-- ── Pure T4 joint qual helper (tested directly; called by SlotService inline) ──

-- Returns true if qualification was newly granted.
function SyndicateService.applyJointQual(data: any, tier: number, isNatural: boolean): boolean
	if isNatural and tier >= 4 and not data.prestige.jointQualLifetime then
		data.prestige.jointQualLifetime = true
		return true
	end
	return false
end

-- ── Public API ─────────────────────────────────────────────────────────────

function SyndicateService.create(player: any, name: any): (string?, string?)
	if type(name) ~= "string" or #name == 0 then
		return nil, "invalid name"
	end
	local userId = player.UserId
	local data = _dataService.getProfile(userId)
	if data.syndicate ~= nil then
		return nil, "already in a syndicate"
	end

	local filteredName, filterErr = filterName(name, userId)
	if filterErr then return nil, filterErr end

	local syndicateId = newSyndicateId()
	local record = {
		id = syndicateId,
		name = filteredName,
		founderId = userId,
		members = { [userId] = "Founder" },
		vaultBalance = 0,
		upgrades = {
			thirdSlot = false,
			crest = false,
			animatedCrest = false,
			broadcastCrest = false,
			memberCapExpanded = false,
		},
		asyncCooldowns = {},
		jointSlots = {},
		createdAt = os.time(),
	}

	_syndicateDs:SetAsync("syndicate:" .. syndicateId, record)
	_dataService.updateProfile(userId, function(d)
		d.syndicate = { id = syndicateId, role = "Founder" }
	end)
	SyndicateService.fireSyndicateUpdate(player, record)
	return syndicateId, nil
end

function SyndicateService.invite(player: any, targetUserId: any): (boolean, string?)
	if type(targetUserId) ~= "number" then
		return false, "invalid args"
	end
	if targetUserId ~= math.floor(targetUserId) or targetUserId <= 0 or targetUserId >= 10000000000 then
		return false, "invalid targetUserId"
	end
	local callerId = player.UserId
	if targetUserId == callerId then
		return false, "cannot invite yourself"
	end
	local data = _dataService.getProfile(callerId)
	if data.syndicate == nil then return false, "not in a syndicate" end
	local syndicateId = data.syndicate.id

	local record = getRecord(syndicateId)
	if record == nil then return false, "syndicate not found" end

	local callerRole = record.members[callerId]
	if callerRole ~= "Founder" and callerRole ~= "Officer" then
		return false, "insufficient rank"
	end

	if countMembers(record) >= getMemberCap(record) then
		return false, "syndicate is full"
	end

	-- Check if target is online and already in a syndicate
	local targetPlayer = _players:GetPlayerByUserId(targetUserId)
	if targetPlayer then
		local ok, targetData = pcall(_dataService.getProfile, targetUserId)
		if ok and targetData and targetData.syndicate ~= nil then
			return false, "target already in a syndicate"
		end
	end

	-- Write pending invite (persists for offline players; online players also get S2C)
	local expiresAt = os.time() + 48 * 3600
	_pendingInviteDs:SetAsync("pendingInvite:" .. tostring(targetUserId), {
		syndicateId = syndicateId,
		inviterId = callerId,
		expiresAt = expiresAt,
	})

	if targetPlayer and _remoteService then
		_remoteService.getEvent("SyndicateInviteReceived"):FireClient(
			targetPlayer,
			syndicateId,
			callerId,
			record.name
		)
	end

	return true, nil
end

function SyndicateService.acceptInvite(player: any, syndicateId: any): (boolean, string?)
	if type(syndicateId) ~= "string" then
		return false, "invalid args"
	end
	local userId = player.UserId
	local data = _dataService.getProfile(userId)
	if data.syndicate ~= nil then return false, "already in a syndicate" end

	local inviteKey = "pendingInvite:" .. tostring(userId)
	local invite = _pendingInviteDs:GetAsync(inviteKey)
	if invite == nil then return false, "no pending invite" end
	if invite.syndicateId ~= syndicateId then return false, "syndicateId mismatch" end
	if os.time() > invite.expiresAt then
		_pendingInviteDs:RemoveAsync(inviteKey)
		return false, "invite expired"
	end

	local failed: string? = nil
	updateRecord(syndicateId, function(record)
		if record == nil then
			failed = "syndicate not found"
			return nil
		end
		if countMembers(record) >= getMemberCap(record) then
			failed = "syndicate is full"
			return nil
		end
		record.members[userId] = "Member"
		return record
	end)

	if failed then return false, failed end

	_dataService.updateProfile(userId, function(d)
		d.syndicate = { id = syndicateId, role = "Member" }
	end)
	_pendingInviteDs:RemoveAsync(inviteKey)

	local updatedRecord = getRecord(syndicateId)
	if updatedRecord then
		SyndicateService.fireUpdateToAllMembers(updatedRecord)
	end

	return true, nil
end

function SyndicateService.declineInvite(player: any): (boolean, string?)
	local userId = player.UserId
	_pendingInviteDs:RemoveAsync("pendingInvite:" .. tostring(userId))
	return true, nil
end

function SyndicateService.kick(player: any, targetUserId: any): (boolean, string?)
	if type(targetUserId) ~= "number" then
		return false, "invalid args"
	end
	local callerId = player.UserId
	local data = _dataService.getProfile(callerId)
	if data.syndicate == nil then return false, "not in a syndicate" end
	local syndicateId = data.syndicate.id

	local record = getRecord(syndicateId)
	if record == nil then return false, "syndicate not found" end

	local callerRole = record.members[callerId]
	if callerRole ~= "Founder" and callerRole ~= "Officer" then
		return false, "insufficient rank"
	end

	local targetRole = record.members[targetUserId]
	if targetRole == nil then return false, "target not in syndicate" end
	if targetRole == "Founder" then return false, "cannot kick Founder" end
	if callerRole == "Officer" and targetRole == "Officer" then
		return false, "officers cannot kick other officers"
	end

	updateRecord(syndicateId, function(rec)
		if rec == nil then return nil end
		rec.members[targetUserId] = nil
		return rec
	end)

	local targetPlayer = _players:GetPlayerByUserId(targetUserId)
	if targetPlayer then
		_dataService.updateProfile(targetUserId, function(d)
			d.syndicate = nil
		end)
		SyndicateService.fireSyndicateUpdate(targetPlayer, nil)
	end

	local updatedRecord = getRecord(syndicateId)
	if updatedRecord then
		SyndicateService.fireUpdateToAllMembers(updatedRecord)
	end

	return true, nil
end

function SyndicateService.promote(player: any, targetUserId: any): (boolean, string?)
	if type(targetUserId) ~= "number" then
		return false, "invalid args"
	end
	local callerId = player.UserId
	local data = _dataService.getProfile(callerId)
	if data.syndicate == nil then return false, "not in a syndicate" end
	local syndicateId = data.syndicate.id

	local record = getRecord(syndicateId)
	if record == nil then return false, "syndicate not found" end

	if record.members[callerId] ~= "Founder" then
		return false, "only Founder can promote"
	end

	if record.members[targetUserId] ~= "Member" then
		return false, "target must be a Member"
	end

	updateRecord(syndicateId, function(rec)
		if rec == nil then return nil end
		rec.members[targetUserId] = "Officer"
		return rec
	end)

	local updatedRecord = getRecord(syndicateId)
	if updatedRecord then
		SyndicateService.fireUpdateToAllMembers(updatedRecord)
	end

	return true, nil
end

function SyndicateService.rename(player: any, newName: any): (boolean, string?)
	if type(newName) ~= "string" or #newName == 0 then
		return false, "invalid name"
	end
	local callerId = player.UserId
	local data = _dataService.getProfile(callerId)
	if data.syndicate == nil then return false, "not in a syndicate" end
	local syndicateId = data.syndicate.id

	local record = getRecord(syndicateId)
	if record == nil then return false, "syndicate not found" end
	if record.members[callerId] ~= "Founder" then
		return false, "only Founder can rename"
	end

	local filteredName, filterErr = filterName(newName, callerId)
	if filterErr then return false, filterErr end

	updateRecord(syndicateId, function(rec)
		if rec == nil then return nil end
		rec.name = filteredName
		return rec
	end)

	local updatedRecord = getRecord(syndicateId)
	if updatedRecord then
		SyndicateService.fireUpdateToAllMembers(updatedRecord)
	end

	return true, nil
end

function SyndicateService.contributeVault(player: any, amount: any): (boolean, string?)
	if type(amount) ~= "number" then
		return false, "invalid amount"
	end
	amount = math.floor(amount)
	if amount <= 0 then
		return false, "invalid amount"
	end
	local userId = player.UserId
	local data = _dataService.getProfile(userId)
	if data.syndicate == nil then return false, "not in a syndicate" end
	local syndicateId = data.syndicate.id

	-- Validate syndicate exists before mutating player data
	local record = getRecord(syndicateId)
	if record == nil then return false, "syndicate not found" end

	if data.balances.pellets < amount then return false, "insufficient pellets" end

	_dataService.updateProfile(userId, function(d)
		d.balances.pellets -= amount
	end)

	updateRecord(syndicateId, function(rec)
		if rec == nil then return nil end
		rec.vaultBalance += amount
		return rec
	end)

	_rankService.scoreVaultContribution(player, data, amount)

	local updatedRecord = getRecord(syndicateId)
	if updatedRecord then
		SyndicateService.fireUpdateToAllMembers(updatedRecord)
	end
	if _remoteService then
		_remoteService.getEvent("BalanceUpdate"):FireClient(
			player,
			data.balances.pellets,
			data.balances.catalysts,
			data.monetization and data.monetization.rushUses or 0,
			data.monetization and data.monetization.timerSkipUses or 0
		)
	end

	return true, nil
end

function SyndicateService.purchaseUpgrade(player: any, upgradeName: any): (boolean, string?)
	if type(upgradeName) ~= "string" then
		return false, "invalid args"
	end
	local validUpgrades = {
		thirdSlot = _economyConstants.SYNDICATE_THIRD_SLOT_COST,
		crest = _economyConstants.SYNDICATE_CREST_COST,
		animatedCrest = _economyConstants.SYNDICATE_ANIMATED_CREST_COST,
		broadcastCrest = _economyConstants.SYNDICATE_BROADCAST_CREST_COST,
	}
	local cost = validUpgrades[upgradeName]
	if cost == nil then
		return false, "unknown upgrade"
	end

	-- §17 crest progression: Animated requires Syndicate Crest; Broadcast requires Animated.
	local requires: { [string]: string } = {
		animatedCrest = "crest",
		broadcastCrest = "animatedCrest",
	}

	local callerId = player.UserId
	local data = _dataService.getProfile(callerId)
	if data.syndicate == nil then return false, "not in a syndicate" end
	local syndicateId = data.syndicate.id

	local record = getRecord(syndicateId)
	if record == nil then return false, "syndicate not found" end

	local callerRole = record.members[callerId]
	if callerRole ~= "Founder" and callerRole ~= "Officer" then
		return false, "insufficient rank"
	end

	if record.upgrades[upgradeName] then
		return false, "upgrade already owned"
	end

	local prereq = requires[upgradeName]
	if prereq and not record.upgrades[prereq] then
		return false, "requires " .. prereq
	end

	if record.vaultBalance < cost then
		return false, "insufficient vault balance"
	end

	updateRecord(syndicateId, function(rec)
		if rec == nil then return nil end
		if rec.vaultBalance < cost then return nil end -- race guard
		rec.vaultBalance -= cost
		rec.upgrades[upgradeName] = true
		return rec
	end)

	local updatedRecord = getRecord(syndicateId)
	if updatedRecord then
		SyndicateService.fireUpdateToAllMembers(updatedRecord)
	end

	return true, nil
end

function SyndicateService.expandMemberCap(player: any): (boolean, string?)
	local userId = player.UserId
	local data = _dataService.getProfile(userId)
	if data.syndicate == nil then return false, "not in a syndicate" end
	local syndicateId = data.syndicate.id

	local record = getRecord(syndicateId)
	if record == nil then return false, "syndicate not found" end

	if record.members[userId] ~= "Founder" then
		return false, "only Founder can expand member cap"
	end

	if record.upgrades.memberCapExpanded then
		return false, "member cap already expanded"
	end

	local cost = _economyConstants.SYNDICATE_CAP_EXPANSION_CATALYSTS
	if data.balances.catalysts < cost then
		return false, "insufficient Catalysts"
	end

	_dataService.updateProfile(userId, function(d)
		d.balances.catalysts -= cost
	end)

	updateRecord(syndicateId, function(rec)
		if rec == nil then return nil end
		rec.upgrades.memberCapExpanded = true
		return rec
	end)

	local updatedRecord = getRecord(syndicateId)
	if updatedRecord then
		SyndicateService.fireUpdateToAllMembers(updatedRecord)
	end
	if _remoteService then
		_remoteService.getEvent("BalanceUpdate"):FireClient(
			player,
			data.balances.pellets,
			data.balances.catalysts,
			data.monetization and data.monetization.rushUses or 0,
			data.monetization and data.monetization.timerSkipUses or 0
		)
	end

	return true, nil
end

-- disband: step 1 — discloses vault balance; client shows warning before confirming
function SyndicateService.disband(player: any): (number, boolean, string?)
	local userId = player.UserId
	local data = _dataService.getProfile(userId)
	if data.syndicate == nil then return 0, false, "not in a syndicate" end
	local syndicateId = data.syndicate.id

	local record = getRecord(syndicateId)
	if record == nil then return 0, false, "syndicate not found" end
	if record.members[userId] ~= "Founder" then
		return 0, false, "only Founder can disband"
	end

	_pendingDisbands[userId] = syndicateId
	return record.vaultBalance, true, nil
end

-- disbandConfirm: step 2 — executes the disband after client confirms vault loss
function SyndicateService.disbandConfirm(player: any): (boolean, string?)
	local userId = player.UserId
	local syndicateId = _pendingDisbands[userId]
	if syndicateId == nil then return false, "no pending disband" end
	_pendingDisbands[userId] = nil

	local record = getRecord(syndicateId)
	if record == nil then return false, "syndicate not found" end

	-- Clear all members' profiles (online: via DataService; offline: direct DS write)
	for memberId in pairs(record.members) do
		local memberPlayer = _players:GetPlayerByUserId(memberId)
		if memberPlayer then
			_dataService.updateProfile(memberId, function(d)
				d.syndicate = nil
			end)
			SyndicateService.fireSyndicateUpdate(memberPlayer, nil)
		elseif _profileDs then
			pcall(function()
				_profileDs:UpdateAsync("Player_" .. tostring(memberId), function(stored)
					if stored then
						stored.syndicate = nil
					end
					return stored
				end)
			end)
		end
	end

	_syndicateDs:RemoveAsync("syndicate:" .. syndicateId)

	return true, nil
end

-- ── Init ───────────────────────────────────────────────────────────────────

function SyndicateService.init()
	local DataStoreService = game:GetService("DataStoreService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	_dataService = require(ServerScriptService.Server.Services.DataService)
	_remoteService = require(ServerScriptService.Server.Services.RemoteService)
	_rankService = require(ServerScriptService.Server.Services.RankService)
	_economyConstants = require(ReplicatedStorage.Shared.Config.EconomyConstants)
	_textService = game:GetService("TextService")
	_syndicateDs = DataStoreService:GetDataStore("Syndicates")
	_pendingInviteDs = DataStoreService:GetDataStore("PendingInvites")
	_profileDs = DataStoreService:GetDataStore("PlayerData_v1")
	_players = game:GetService("Players")

	local rs = _remoteService
	local function guard(player) return _dataService.isLoaded(player.UserId) end

	rs.setInvoke("SyndicateCreate", function(player, name)
		if not guard(player) then return nil, "session not ready" end
		return SyndicateService.create(player, name)
	end)

	rs.setInvoke("SyndicateInvite", function(player, targetUserId)
		if not guard(player) then return false, "session not ready" end
		return SyndicateService.invite(player, targetUserId)
	end)

	rs.setInvoke("SyndicateKick", function(player, targetUserId)
		if not guard(player) then return false, "session not ready" end
		return SyndicateService.kick(player, targetUserId)
	end)

	rs.setInvoke("SyndicatePromote", function(player, targetUserId)
		if not guard(player) then return false, "session not ready" end
		return SyndicateService.promote(player, targetUserId)
	end)

	rs.setInvoke("SyndicateContributeVault", function(player, amount)
		if not guard(player) then return false, "session not ready" end
		return SyndicateService.contributeVault(player, amount)
	end)

	rs.setInvoke("SyndicateAcceptInvite", function(player, syndicateId)
		if not guard(player) then return false, "session not ready" end
		return SyndicateService.acceptInvite(player, syndicateId)
	end)

	rs.setInvoke("SyndicateDeclineInvite", function(player)
		if not guard(player) then return false, "session not ready" end
		return SyndicateService.declineInvite(player)
	end)

	rs.setInvoke("SyndicateRename", function(player, newName)
		if not guard(player) then return false, "session not ready" end
		return SyndicateService.rename(player, newName)
	end)

	rs.setInvoke("SyndicatePurchaseUpgrade", function(player, upgradeName)
		if not guard(player) then return false, "session not ready" end
		return SyndicateService.purchaseUpgrade(player, upgradeName)
	end)

	rs.setInvoke("SyndicateExpandCap", function(player)
		if not guard(player) then return false, "session not ready" end
		return SyndicateService.expandMemberCap(player)
	end)

	rs.setInvoke("SyndicateDisband", function(player)
		if not guard(player) then return 0, false, "session not ready" end
		return SyndicateService.disband(player)
	end)

	rs.setInvoke("SyndicateDisbandConfirm", function(player)
		if not guard(player) then return false, "session not ready" end
		return SyndicateService.disbandConfirm(player)
	end)
end

return SyndicateService

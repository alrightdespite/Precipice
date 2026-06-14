-- SyndicateService tests. Phase 10A.
-- Injection pattern — no Roblox globals, no live DataStores.
-- Tests 1–26: SyndicateService API. Tests 27–30: T4 joint qualification logic.

local spec = require("../spec")
local MockDataStore = require("../mocks/MockDataStore")
local EconomyConstants = require("../../src/shared/Config/EconomyConstants")
local SyndicateService = require("../../src/server/Services/SyndicateService")

local describe, it, expect = spec.describe, spec.it, spec.expect

local NOW = 1700000000 -- fixed timestamp; os.time() in tests uses real clock

-- ── Fixtures ───────────────────────────────────────────────────────────────

local player1 = { UserId = 1, Name = "TestPlayer" }
local player2 = { UserId = 2, Name = "PartnerPlayer" }

local function defaultData()
	return {
		syndicate = nil,
		balances = { pellets = 5000000, catalysts = 300 },
		prestige = { level = 0, jointQualLifetime = false },
		rank = {
			currentRun = 0,
			lifetime = 0,
			dailyCaps = { date = "", marketPoints = 0, vaultPoints = 0 },
		},
		sprintPoints = { weekEpoch = 0, points = 0 },
		monetization = { rushUses = 0, timerSkipUses = 0 },
	}
end

-- ── Setup helper — wires fresh mocks for each test ─────────────────────────

local function setup()
	local data1 = defaultData()
	local data2 = defaultData()
	local profiles: { [number]: any } = { [1] = data1, [2] = data2 }

	local syndicateDs = MockDataStore.new()
	local pendingInviteDs = MockDataStore.new()

	local firedEvents: { { name: string, player: any, args: { any } } } = {}
	local mockRemoteService = {
		getEvent = function(name: string)
			return {
				FireClient = function(_, p: any, ...)
					table.insert(firedEvents, { name = name, player = p, args = { ... } })
				end,
			}
		end,
		getFunction = function(_name: string)
			return { OnServerInvoke = nil }
		end,
	}

	local vaultContribs: { { player: any, amount: number } } = {}
	local mockRankService = {
		scoreVaultContribution = function(player: any, _data: any, amount: number)
			table.insert(vaultContribs, { player = player, amount = amount })
		end,
		addScore = function() end,
		addSprintPoints = function() end,
	}

	local mockTextService = {
		FilterStringAsync = function(_self: any, text: string, _userId: number)
			return {
				GetNonChatStringForBroadcastAsync = function()
					return text
				end,
			}
		end,
	}

	-- player1 online, player2 online by default; tests can override
	local onlinePlayers: { [number]: any } = { [1] = player1, [2] = player2 }
	local mockPlayers = {
		GetPlayerByUserId = function(_self: any, userId: number)
			return onlinePlayers[userId]
		end,
	}

	local mockDataService = {
		getProfile = function(userId: number)
			return profiles[userId]
		end,
		updateProfile = function(userId: number, fn: (any) -> ())
			fn(profiles[userId])
		end,
	}

	SyndicateService._setDataService(mockDataService)
	SyndicateService._setRemoteService(mockRemoteService)
	SyndicateService._setRankService(mockRankService)
	SyndicateService._setEconomyConstants(EconomyConstants)
	SyndicateService._setTextService(mockTextService)
	SyndicateService._setSyndicateDs(syndicateDs)
	SyndicateService._setPendingInviteDs(pendingInviteDs)
	SyndicateService._setProfileDs(nil)
	SyndicateService._setPlayers(mockPlayers)
	SyndicateService._resetPendingDisbands()

	return {
		data1 = data1,
		data2 = data2,
		profiles = profiles,
		syndicateDs = syndicateDs,
		pendingInviteDs = pendingInviteDs,
		firedEvents = firedEvents,
		vaultContribs = vaultContribs,
		onlinePlayers = onlinePlayers,
	}
end

-- Helper: create a syndicate as player1 and return its id
local function createSyndicate(name: string?): string
	local id, err = SyndicateService.create(player1, name or "TestSyndicate")
	assert(id ~= nil, "create failed: " .. tostring(err))
	return id
end

-- ── create ─────────────────────────────────────────────────────────────────

describe("SyndicateService — create", function()
	it("player not in syndicate: creates record and sets Founder role", function()
		local ctx = setup()
		local synId, err = SyndicateService.create(player1, "Alpha")
		expect(err).toBeNil()
		expect(synId ~= nil).toBeTrue()
		local record = ctx.syndicateDs:GetAsync("syndicate:" .. synId)
		expect(record ~= nil).toBeTrue()
		expect(record.founderId).toBe(1)
		expect(record.members[1]).toBe("Founder")
		expect(ctx.data1.syndicate ~= nil).toBeTrue()
		expect(ctx.data1.syndicate.id).toBe(synId)
		expect(ctx.data1.syndicate.role).toBe("Founder")
	end)

	it("player already in syndicate: returns nil, err", function()
		local _ = setup()
		local synId, _ = SyndicateService.create(player1, "Alpha")
		local synId2, err2 = SyndicateService.create(player1, "Beta")
		expect(synId ~= nil).toBeTrue()
		expect(synId2).toBeNil()
		expect(err2 ~= nil).toBeTrue()
	end)
end)

-- ── invite ─────────────────────────────────────────────────────────────────

describe("SyndicateService — invite", function()
	it("Founder invites offline player: pendingInvite DS key written", function()
		local ctx = setup()
		ctx.onlinePlayers[2] = nil -- player2 offline
		local synId = createSyndicate()
		local ok, err = SyndicateService.invite(player1, 2)
		expect(ok).toBeTrue()
		expect(err).toBeNil()
		local invite = ctx.pendingInviteDs:GetAsync("pendingInvite:2")
		expect(invite ~= nil).toBeTrue()
		expect(invite.syndicateId).toBe(synId)
		expect(invite.inviterId).toBe(1)
	end)

	it("non-member cannot invite: returns err", function()
		local _ = setup()
		-- player2 not in any syndicate
		local ok, err = SyndicateService.invite(player2, 99)
		expect(ok).toBeFalse()
		expect(err ~= nil).toBeTrue()
	end)

	it("syndicate at member cap: invite fails", function()
		local ctx = setup()
		local synId = createSyndicate()
		-- Fill to base cap (8): already have player1; add 7 more
		ctx.syndicateDs:UpdateAsync("syndicate:" .. synId, function(rec)
			for i = 3, 9 do
				rec.members[i] = "Member"
			end
			return rec
		end)
		local ok, err = SyndicateService.invite(player1, 2)
		expect(ok).toBeFalse()
		expect(err ~= nil).toBeTrue()
	end)
end)

-- ── acceptInvite ───────────────────────────────────────────────────────────

describe("SyndicateService — acceptInvite", function()
	it("valid invite not expired: player added, data.syndicate set, invite deleted", function()
		local ctx = setup()
		local synId = createSyndicate()
		ctx.pendingInviteDs:SetAsync("pendingInvite:2", {
			syndicateId = synId,
			inviterId = 1,
			expiresAt = os.time() + 86400,
		})
		local ok, err = SyndicateService.acceptInvite(player2, synId)
		expect(ok).toBeTrue()
		expect(err).toBeNil()
		expect(ctx.data2.syndicate ~= nil).toBeTrue()
		expect(ctx.data2.syndicate.id).toBe(synId)
		expect(ctx.data2.syndicate.role).toBe("Member")
		local record = ctx.syndicateDs:GetAsync("syndicate:" .. synId)
		expect(record.members[2]).toBe("Member")
		local invite = ctx.pendingInviteDs:GetAsync("pendingInvite:2")
		expect(invite).toBeNil()
	end)

	it("expired invite: returns err", function()
		local ctx = setup()
		local synId = createSyndicate()
		ctx.pendingInviteDs:SetAsync("pendingInvite:2", {
			syndicateId = synId,
			inviterId = 1,
			expiresAt = 1, -- in the past
		})
		local ok, err = SyndicateService.acceptInvite(player2, synId)
		expect(ok).toBeFalse()
		expect(err ~= nil).toBeTrue()
	end)

	it("wrong syndicateId: returns err", function()
		local ctx = setup()
		local synId = createSyndicate()
		ctx.pendingInviteDs:SetAsync("pendingInvite:2", {
			syndicateId = "different_id",
			inviterId = 1,
			expiresAt = os.time() + 86400,
		})
		local ok, err = SyndicateService.acceptInvite(player2, synId)
		expect(ok).toBeFalse()
		expect(err ~= nil).toBeTrue()
	end)
end)

-- ── kick ───────────────────────────────────────────────────────────────────

describe("SyndicateService — kick", function()
	local function setupWithMember()
		local ctx = setup()
		local synId = createSyndicate()
		-- Add player2 as Member
		ctx.syndicateDs:UpdateAsync("syndicate:" .. synId, function(rec)
			rec.members[2] = "Member"
			return rec
		end)
		ctx.data2.syndicate = { id = synId, role = "Member" }
		return ctx, synId
	end

	it("Founder kicks Member: member removed, member data.syndicate = nil", function()
		local ctx, synId = setupWithMember()
		local ok, err = SyndicateService.kick(player1, 2)
		expect(ok).toBeTrue()
		expect(err).toBeNil()
		local record = ctx.syndicateDs:GetAsync("syndicate:" .. synId)
		expect(record.members[2]).toBeNil()
		expect(ctx.data2.syndicate).toBeNil()
	end)

	it("Officer kicks Member: succeeds", function()
		local ctx, synId = setupWithMember()
		-- Promote player2 to Officer, add player3 as Member target
		ctx.syndicateDs:UpdateAsync("syndicate:" .. synId, function(rec)
			rec.members[2] = "Officer"
			rec.members[3] = "Member"
			return rec
		end)
		ctx.data2.syndicate = { id = synId, role = "Officer" }
		local data3 = defaultData()
		data3.syndicate = { id = synId, role = "Member" }
		ctx.profiles[3] = data3
		ctx.onlinePlayers[3] = { UserId = 3, Name = "Player3" }
		local ok, err = SyndicateService.kick(player2, 3)
		expect(ok).toBeTrue()
		expect(err).toBeNil()
		local record = ctx.syndicateDs:GetAsync("syndicate:" .. synId)
		expect(record.members[3]).toBeNil()
	end)

	it("Officer kicks Officer: fails", function()
		local ctx, synId = setupWithMember()
		-- player2 = Officer, player3 = Officer
		ctx.syndicateDs:UpdateAsync("syndicate:" .. synId, function(rec)
			rec.members[2] = "Officer"
			rec.members[3] = "Officer"
			return rec
		end)
		ctx.data2.syndicate = { id = synId, role = "Officer" }
		local data3 = defaultData()
		data3.syndicate = { id = synId, role = "Officer" }
		ctx.profiles[3] = data3
		local ok, err = SyndicateService.kick(player2, 3)
		expect(ok).toBeFalse()
		expect(err ~= nil).toBeTrue()
	end)

	it("Founder cannot be kicked", function()
		local ctx, _ = setupWithMember()
		local ok, err = SyndicateService.kick(player2, 1)
		expect(ok).toBeFalse()
		expect(err ~= nil).toBeTrue()
		expect(ctx.data1.syndicate ~= nil).toBeTrue()
	end)
end)

-- ── promote ────────────────────────────────────────────────────────────────

describe("SyndicateService — promote", function()
	it("Founder promotes Member to Officer: role updated", function()
		local ctx = setup()
		local synId = createSyndicate()
		ctx.syndicateDs:UpdateAsync("syndicate:" .. synId, function(rec)
			rec.members[2] = "Member"
			return rec
		end)
		ctx.data2.syndicate = { id = synId, role = "Member" }
		local ok, err = SyndicateService.promote(player1, 2)
		expect(ok).toBeTrue()
		expect(err).toBeNil()
		local record = ctx.syndicateDs:GetAsync("syndicate:" .. synId)
		expect(record.members[2]).toBe("Officer")
	end)

	it("non-Founder cannot promote: fails", function()
		local ctx = setup()
		local synId = createSyndicate()
		ctx.syndicateDs:UpdateAsync("syndicate:" .. synId, function(rec)
			rec.members[2] = "Officer"
			rec.members[3] = "Member"
			return rec
		end)
		ctx.data2.syndicate = { id = synId, role = "Officer" }
		local data3 = defaultData()
		ctx.profiles[3] = data3
		local ok, err = SyndicateService.promote(player2, 3)
		expect(ok).toBeFalse()
		expect(err ~= nil).toBeTrue()
	end)
end)

-- ── contributeVault ────────────────────────────────────────────────────────

describe("SyndicateService — contributeVault", function()
	it("valid contribution: pellets deducted, vaultBalance increased, RankService called", function()
		local ctx = setup()
		local synId = createSyndicate()
		local amount = 1000000
		local pelletsBefore = ctx.data1.balances.pellets
		local ok, err = SyndicateService.contributeVault(player1, amount)
		expect(ok).toBeTrue()
		expect(err).toBeNil()
		expect(ctx.data1.balances.pellets).toBe(pelletsBefore - amount)
		local record = ctx.syndicateDs:GetAsync("syndicate:" .. synId)
		expect(record.vaultBalance).toBe(amount)
		expect(#ctx.vaultContribs).toBe(1)
		expect(ctx.vaultContribs[1].amount).toBe(amount)
		expect(ctx.vaultContribs[1].player).toBe(player1)
	end)

	it("insufficient pellets: fails, no mutation", function()
		local ctx = setup()
		local synId = createSyndicate()
		local hugAmount = 999999999
		local pelletsBefore = ctx.data1.balances.pellets
		local ok, err = SyndicateService.contributeVault(player1, hugAmount)
		expect(ok).toBeFalse()
		expect(err ~= nil).toBeTrue()
		expect(ctx.data1.balances.pellets).toBe(pelletsBefore)
		local record = ctx.syndicateDs:GetAsync("syndicate:" .. synId)
		expect(record.vaultBalance).toBe(0)
		expect(#ctx.vaultContribs).toBe(0)
	end)
end)

-- ── purchaseUpgrade ────────────────────────────────────────────────────────

describe("SyndicateService — purchaseUpgrade", function()
	it("sufficient vault balance, Founder: upgrade purchased, vaultBalance reduced", function()
		local ctx = setup()
		local synId = createSyndicate()
		local cost = EconomyConstants.SYNDICATE_CREST_COST -- 1M
		-- Fund the vault
		ctx.syndicateDs:UpdateAsync("syndicate:" .. synId, function(rec)
			rec.vaultBalance = cost + 500000
			return rec
		end)
		local ok, err = SyndicateService.purchaseUpgrade(player1, "crest")
		expect(ok).toBeTrue()
		expect(err).toBeNil()
		local record = ctx.syndicateDs:GetAsync("syndicate:" .. synId)
		expect(record.upgrades.crest).toBeTrue()
		expect(record.vaultBalance).toBe(500000)
	end)

	it("insufficient vault balance: fails", function()
		local ctx = setup()
		local synId = createSyndicate()
		-- vault = 0 by default
		local ok, err = SyndicateService.purchaseUpgrade(player1, "crest")
		expect(ok).toBeFalse()
		expect(err ~= nil).toBeTrue()
		local record = ctx.syndicateDs:GetAsync("syndicate:" .. synId)
		expect(record.upgrades.crest).toBeFalse()
	end)

	it("already owned upgrade: fails", function()
		local ctx = setup()
		local synId = createSyndicate()
		local cost = EconomyConstants.SYNDICATE_CREST_COST
		ctx.syndicateDs:UpdateAsync("syndicate:" .. synId, function(rec)
			rec.vaultBalance = cost * 10
			rec.upgrades.crest = true
			return rec
		end)
		local ok, err = SyndicateService.purchaseUpgrade(player1, "crest")
		expect(ok).toBeFalse()
		expect(err ~= nil).toBeTrue()
	end)
end)

-- ── expandMemberCap ────────────────────────────────────────────────────────

describe("SyndicateService — expandMemberCap", function()
	it("Founder with 200+ Catalysts: catalysts deducted, upgrade set", function()
		local ctx = setup()
		local synId = createSyndicate()
		local catsBefore = ctx.data1.balances.catalysts -- 300
		local ok, err = SyndicateService.expandMemberCap(player1)
		expect(ok).toBeTrue()
		expect(err).toBeNil()
		expect(ctx.data1.balances.catalysts).toBe(
			catsBefore - EconomyConstants.SYNDICATE_CAP_EXPANSION_CATALYSTS
		)
		local record = ctx.syndicateDs:GetAsync("syndicate:" .. synId)
		expect(record.upgrades.memberCapExpanded).toBeTrue()
	end)

	it("non-Founder: fails", function()
		local ctx = setup()
		local synId = createSyndicate()
		ctx.syndicateDs:UpdateAsync("syndicate:" .. synId, function(rec)
			rec.members[2] = "Officer"
			return rec
		end)
		ctx.data2.syndicate = { id = synId, role = "Officer" }
		local ok, err = SyndicateService.expandMemberCap(player2)
		expect(ok).toBeFalse()
		expect(err ~= nil).toBeTrue()
		local record = ctx.syndicateDs:GetAsync("syndicate:" .. synId)
		expect(record.upgrades.memberCapExpanded).toBeFalse()
	end)

	it("already expanded: fails", function()
		local ctx = setup()
		local synId = createSyndicate()
		ctx.syndicateDs:UpdateAsync("syndicate:" .. synId, function(rec)
			rec.upgrades.memberCapExpanded = true
			return rec
		end)
		local ok, err = SyndicateService.expandMemberCap(player1)
		expect(ok).toBeFalse()
		expect(err ~= nil).toBeTrue()
	end)
end)

-- ── disband ────────────────────────────────────────────────────────────────

describe("SyndicateService — disband", function()
	it("Founder disbands: all member profiles cleared, DS record deleted, vault gone", function()
		local ctx = setup()
		local synId = createSyndicate()
		-- Add player2 as member, fund vault
		ctx.syndicateDs:UpdateAsync("syndicate:" .. synId, function(rec)
			rec.members[2] = "Member"
			rec.vaultBalance = 5000
			return rec
		end)
		ctx.data2.syndicate = { id = synId, role = "Member" }

		-- Step 1: disband returns vault amount
		local vaultAmount, ok, err = SyndicateService.disband(player1)
		expect(ok).toBeTrue()
		expect(err).toBeNil()
		expect(vaultAmount).toBe(5000)

		-- Step 2: confirm
		local ok2, err2 = SyndicateService.disbandConfirm(player1)
		expect(ok2).toBeTrue()
		expect(err2).toBeNil()

		-- Record deleted
		local record = ctx.syndicateDs:GetAsync("syndicate:" .. synId)
		expect(record).toBeNil()

		-- Both online members cleared
		expect(ctx.data1.syndicate).toBeNil()
		expect(ctx.data2.syndicate).toBeNil()
	end)

	it("non-Founder cannot disband", function()
		local ctx = setup()
		local synId = createSyndicate()
		ctx.syndicateDs:UpdateAsync("syndicate:" .. synId, function(rec)
			rec.members[2] = "Officer"
			return rec
		end)
		ctx.data2.syndicate = { id = synId, role = "Officer" }
		local _, ok, err = SyndicateService.disband(player2)
		expect(ok).toBeFalse()
		expect(err ~= nil).toBeTrue()
		-- Record still exists
		local record = ctx.syndicateDs:GetAsync("syndicate:" .. synId)
		expect(record ~= nil).toBeTrue()
	end)
end)

-- ── getJointSlotCount ──────────────────────────────────────────────────────

describe("SyndicateService — getJointSlotCount", function()
	it("no thirdSlot upgrade: returns 2", function()
		local _ = setup()
		local synId = createSyndicate()
		expect(SyndicateService.getJointSlotCount(synId)).toBe(2)
	end)

	it("thirdSlot upgrade purchased: returns 3", function()
		local ctx = setup()
		local synId = createSyndicate()
		ctx.syndicateDs:UpdateAsync("syndicate:" .. synId, function(rec)
			rec.upgrades.thirdSlot = true
			return rec
		end)
		expect(SyndicateService.getJointSlotCount(synId)).toBe(3)
	end)
end)

-- ── T4 joint qualification ─────────────────────────────────────────────────

describe("SyndicateService — T4 joint qualification (applyJointQual)", function()
	it("natural T4 reveal: jointQualLifetime set to true", function()
		local data = { prestige = { jointQualLifetime = false } }
		local granted = SyndicateService.applyJointQual(data, 4, true)
		expect(granted).toBeTrue()
		expect(data.prestige.jointQualLifetime).toBeTrue()
	end)

	it("natural T3 reveal: jointQualLifetime unchanged", function()
		local data = { prestige = { jointQualLifetime = false } }
		local granted = SyndicateService.applyJointQual(data, 3, true)
		expect(granted).toBeFalse()
		expect(data.prestige.jointQualLifetime).toBeFalse()
	end)

	it("skipped T4 reveal (isNatural=false): jointQualLifetime unchanged", function()
		local data = { prestige = { jointQualLifetime = false } }
		local granted = SyndicateService.applyJointQual(data, 4, false)
		expect(granted).toBeFalse()
		expect(data.prestige.jointQualLifetime).toBeFalse()
	end)

	it("already qualified, T4 reveal: no double-set (idempotent)", function()
		local data = { prestige = { jointQualLifetime = true } }
		local granted = SyndicateService.applyJointQual(data, 4, true)
		expect(granted).toBeFalse()
		expect(data.prestige.jointQualLifetime).toBeTrue()
	end)
end)

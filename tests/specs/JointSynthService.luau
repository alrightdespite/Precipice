-- JointSynthService tests. Phase 10B.
-- Injection pattern — no Roblox globals, no live DataStores.
-- Tests 12–27: state machine transitions, delivery, expiry, passive inputs.

local spec = require("../spec")
local MockDataStore = require("../mocks/MockDataStore")
local EconomyConstants = require("../../src/shared/Config/EconomyConstants")
local RankMath = require("../../src/shared/Core/RankMath")
local JointSynthService = require("../../src/server/Services/JointSynthService")

local describe, it, expect = spec.describe, spec.it, spec.expect

local NOW = 1700000000
local SYN_ID = "syn_test"

-- ── Fixtures ───────────────────────────────────────────────────────────────

local opener = { UserId = 1, Name = "Opener" }
local partner = { UserId = 2, Name = "Partner" }

local function openerData()
	return {
		syndicate = { id = SYN_ID, role = "Founder" },
		prestige = { level = 0, jointQualLifetime = true },
		balances = { pellets = 50000, catalysts = 100 },
		vault = { compounds = { ["T6_01"] = 2, ["T4_01"] = 1 }, residue = 0 },
		formulaLog = { discovered = {}, validatedPairs = {}, failedPairs = {} },
		rank = {
			currentRun = 0,
			lifetime = 0,
			dailyCaps = { date = "", marketPoints = 0, vaultPoints = 0 },
		},
		sprintPoints = { weekEpoch = 0, points = 0 },
		monetization = { rushUses = 0, timerSkipUses = 0 },
	}
end

local function partnerData()
	return {
		syndicate = { id = SYN_ID, role = "Member" },
		prestige = { level = 0, jointQualLifetime = true },
		balances = { pellets = 50000, catalysts = 100 },
		vault = { compounds = { ["T6_02"] = 2, ["T5_01"] = 1 }, residue = 0 },
		formulaLog = { discovered = {}, validatedPairs = {}, failedPairs = {} },
		rank = {
			currentRun = 0,
			lifetime = 0,
			dailyCaps = { date = "", marketPoints = 0, vaultPoints = 0 },
		},
		sprintPoints = { weekEpoch = 0, points = 0 },
		monetization = { rushUses = 0, timerSkipUses = 0 },
	}
end

local function defaultSyndicate()
	return {
		id = SYN_ID,
		name = "TestSyn",
		founderId = 1,
		members = { [1] = "Founder", [2] = "Member" },
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
		createdAt = NOW,
	}
end

-- ── Setup helper ───────────────────────────────────────────────────────────

local function setup()
	local syndicateDs = MockDataStore.new()
	local profileDs = MockDataStore.new()
	syndicateDs:SetAsync("syndicate:" .. SYN_ID, defaultSyndicate())

	local profiles: { [number]: any } = { [1] = openerData(), [2] = partnerData() }

	local mockDataService = {
		getProfile = function(userId: number) return profiles[userId] end,
		updateProfile = function(userId: number, fn: (any) -> ()) fn(profiles[userId]) end,
	}

	local mockSyndicateService = {
		getRecord = function(syndicateId: string)
			return syndicateDs:GetAsync("syndicate:" .. syndicateId)
		end,
	}

	local vaultLog: { any } = {}
	local mockVaultService = {
		applyAward = function(data: any, compoundId: string, qty: number)
			data.vault.compounds[compoundId] = (data.vault.compounds[compoundId] or 0) + qty
			table.insert(vaultLog, { op = "award", compoundId = compoundId, qty = qty })
		end,
		applyDeduct = function(data: any, compoundId: string, qty: number)
			local have = data.vault.compounds[compoundId] or 0
			assert(have >= qty, "VaultService.applyDeduct: insufficient " .. compoundId)
			data.vault.compounds[compoundId] = have - qty
			table.insert(vaultLog, { op = "deduct", compoundId = compoundId, qty = qty })
		end,
	}

	local rankLog: { any } = {}
	local mockRankService = {
		addScore = function(player: any, _data: any, amount: number, source: string)
			table.insert(rankLog, { userId = player and player.UserId, amount = amount, source = source })
		end,
		addSprintPoints = function() end,
	}

	local exoticLog: { any } = {}
	local mockExoticService = {
		onPairCompleted = function(op: any, pt: any, od: any, pd: any, exoticId: string, isNatural: boolean, _now: number)
			table.insert(exoticLog, {
				openerId = op.UserId,
				partnerId = pt.UserId,
				exoticId = exoticId,
				isNatural = isNatural,
			})
			-- Apply basic awards so downstream assertions work
			od.vault.compounds[exoticId] = (od.vault.compounds[exoticId] or 0) + 1
			pd.vault.compounds[exoticId] = (pd.vault.compounds[exoticId] or 0) + 1
		end,
	}

	local mockEventService = { awardFlux = function() end }
	local mockPatentService = { recordNaturalSynthesis = function() end }

	local firedEvents: { any } = {}
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

	local onlinePlayers: { [number]: any } = { [1] = opener, [2] = partner }
	local mockPlayers = {
		GetPlayerByUserId = function(_self: any, userId: number)
			return onlinePlayers[userId]
		end,
	}

	-- Resolver that knows T6_01+T6_02→EX_002, T6_01+T6_01→EX_001, T4_01+T5_01→T6_01
	local mockCompounds = {
		T4_01 = { id = "T4_01", tier = 4, passivePerMin = 21.9 },
		T5_01 = { id = "T5_01", tier = 5, passivePerMin = 35.0 },
		T6_01 = { id = "T6_01", tier = 6, passivePerMin = 50.0 },
		T6_02 = { id = "T6_02", tier = 6, passivePerMin = 52.0 },
	}

	local mockResolver = {
		resolve = function(c1: string, c2: string, _seed: number): string?
			if (c1 == "T4_01" and c2 == "T5_01") or (c1 == "T5_01" and c2 == "T4_01") then
				return "T6_01"
			end
			return nil
		end,
		resolveExotic = function(c1: string, c2: string): string?
			local key = if c1 < c2 then c1 .. "|" .. c2 else c2 .. "|" .. c1
			if key == "T6_01|T6_01" then return "EX_001" end
			if key == "T6_01|T6_02" then return "EX_002" end
			return nil
		end,
		isJointRequired = function(c1: string, c2: string): boolean
			local tiers: { [string]: number } = {
				T4_01 = 4, T5_01 = 5, T6_01 = 6, T6_02 = 6,
			}
			local t1 = tiers[c1] or 0
			local t2 = tiers[c2] or 0
			local lo, hi = math.min(t1, t2), math.max(t1, t2)
			return (lo == 4 and hi == 5) or (lo == 5 and hi == 5) or (lo == 6 and hi == 6)
		end,
		isExoticInput = function(_c: string): boolean
			return false -- none of our test compounds are T7
		end,
	}

	JointSynthService._setDataService(mockDataService)
	JointSynthService._setSyndicateService(mockSyndicateService)
	JointSynthService._setSyndicateDs(syndicateDs)
	JointSynthService._setProfileDs(profileDs)
	JointSynthService._setVaultService(mockVaultService)
	JointSynthService._setRankService(mockRankService)
	JointSynthService._setRankMath(RankMath)
	JointSynthService._setEventService(mockEventService)
	JointSynthService._setPatentService(mockPatentService)
	JointSynthService._setExoticService(mockExoticService)
	JointSynthService._setRecipeResolver(mockResolver)
	JointSynthService._setEconomyConstants(EconomyConstants)
	JointSynthService._setCompounds(mockCompounds)
	JointSynthService._setRemoteService(mockRemoteService)
	JointSynthService._setPlayers(mockPlayers)
	JointSynthService._setSpawnFn(function() end)
	JointSynthService._resetActiveSyndicates()

	return {
		syndicateDs = syndicateDs,
		profileDs = profileDs,
		profiles = profiles,
		vaultLog = vaultLog,
		rankLog = rankLog,
		exoticLog = exoticLog,
		firedEvents = firedEvents,
		onlinePlayers = onlinePlayers,
	}
end

-- ── Stage tests ────────────────────────────────────────────────────────────

describe("JointSynthService — test 12: stage T6+T6 valid → STAGED, compound removed", function()
	it("slot is STAGED; T6_01 deducted from opener vault", function()
		local ctx = setup()
		local ok, err = JointSynthService.stage(opener, 1, "T6_01", "T6_02", false, false)
		expect(ok).toBeTrue()
		expect(err).toBeNil()
		-- Slot stored in DS
		local rec = ctx.syndicateDs:GetAsync("syndicate:" .. SYN_ID)
		local slot = rec.jointSlots["1"]
		expect(slot ~= nil).toBeTrue()
		expect(slot.state).toBe("STAGED")
		-- Compound removed from vault
		local have = ctx.profiles[1].vault.compounds["T6_01"] or 0
		expect(have).toBe(1) -- started with 2, deducted 1
	end)
end)

describe("JointSynthService — test 13: stage without qual → fails", function()
	it("returns false with qualification message", function()
		setup()
		ctx_profiles_1 = nil
		-- Reset to unqualified
		local ctx = setup()
		ctx.profiles[1].prestige.jointQualLifetime = false
		local ok, err = JointSynthService.stage(opener, 1, "T6_01", "T6_02", false, false)
		expect(ok).toBeFalse()
		expect(err ~= nil).toBeTrue()
	end)
end)

describe("JointSynthService — test 14: stage when slot not EMPTY → fails", function()
	it("returns false", function()
		local ctx = setup()
		-- Stage first
		JointSynthService.stage(opener, 1, "T6_01", "T6_02", false, false)
		-- Try to stage again (same slot, opener has 1 T6_01 left but slot is STAGED)
		-- Use a different player for opener compound; simplify by re-staging with opener
		-- Actually opener no longer has T6_02 or the slot is already STAGED
		-- Just verify slot is not EMPTY
		local rec = ctx.syndicateDs:GetAsync("syndicate:" .. SYN_ID)
		local slot = rec.jointSlots["1"]
		expect(slot.state).toBe("STAGED")
		-- Attempt to stage slot 1 again
		ctx.profiles[1].vault.compounds["T6_01"] = 5 -- give more
		local ok, _err = JointSynthService.stage(opener, 1, "T6_01", "T6_02", false, false)
		expect(ok).toBeFalse()
	end)
end)

describe("JointSynthService — test 15: stage with compound not in vault → fails", function()
	it("returns false", function()
		local ctx = setup()
		ctx.profiles[1].vault.compounds["T6_01"] = 0
		local ok, _err = JointSynthService.stage(opener, 1, "T6_01", "T6_02", false, false)
		expect(ok).toBeFalse()
	end)
end)

describe("JointSynthService — test 16: contribute valid → RUNNING, partner compound removed", function()
	it("slot transitions to RUNNING; T6_02 deducted from partner vault", function()
		local ctx = setup()
		JointSynthService.stage(opener, 1, "T6_01", "T6_02", false, false)
		local ok, err = JointSynthService.contribute(partner, 1, "T6_02")
		expect(ok).toBeTrue()
		expect(err).toBeNil()
		local rec = ctx.syndicateDs:GetAsync("syndicate:" .. SYN_ID)
		local slot = rec.jointSlots["1"]
		expect(slot.state).toBe("RUNNING")
		local have = ctx.profiles[2].vault.compounds["T6_02"] or 0
		expect(have).toBe(1) -- started with 2, deducted 1
	end)
end)

describe("JointSynthService — test 17: contribute as opener → fails (same userId)", function()
	it("returns false", function()
		setup()
		JointSynthService.stage(opener, 1, "T6_01", "T6_02", false, false)
		-- opener tries to contribute
		local ctx2 = nil -- reuse current setup
		local ok, err = JointSynthService.contribute(opener, 1, "T6_02")
		expect(ok).toBeFalse()
		expect(err ~= nil).toBeTrue()
	end)
end)

describe("JointSynthService — test 18: contribute wrong compound → fails", function()
	it("returns false", function()
		setup()
		JointSynthService.stage(opener, 1, "T6_01", "T6_02", false, false)
		local ok, _err = JointSynthService.contribute(partner, 1, "T6_01") -- wrong compound
		expect(ok).toBeFalse()
	end)
end)

describe("JointSynthService — test 19: cancel from STAGED → compound returned, slot → EMPTY", function()
	it("opener gets T6_01 back; slot key nil in DS", function()
		local ctx = setup()
		JointSynthService.stage(opener, 1, "T6_01", "T6_02", false, false)
		local haveBefore = ctx.profiles[1].vault.compounds["T6_01"] or 0
		local ok, err = JointSynthService.cancel(opener, 1)
		expect(ok).toBeTrue()
		expect(err).toBeNil()
		local haveAfter = ctx.profiles[1].vault.compounds["T6_01"] or 0
		expect(haveAfter).toBe(haveBefore + 1)
		local rec = ctx.syndicateDs:GetAsync("syndicate:" .. SYN_ID)
		expect(rec.jointSlots["1"]).toBeNil()
	end)
end)

describe("JointSynthService — test 20: cancel from RUNNING → fails", function()
	it("returns false", function()
		setup()
		JointSynthService.stage(opener, 1, "T6_01", "T6_02", false, false)
		JointSynthService.contribute(partner, 1, "T6_02")
		local ok, err = JointSynthService.cancel(opener, 1)
		expect(ok).toBeFalse()
		expect(err ~= nil).toBeTrue()
	end)
end)

describe("JointSynthService — test 21: complete T6+T6 natural → ExoticService.onPairCompleted called", function()
	it("exoticLog has one entry with EX_002", function()
		local ctx = setup()
		JointSynthService.stage(opener, 1, "T6_01", "T6_02", false, false)
		JointSynthService.contribute(partner, 1, "T6_02")
		JointSynthService.complete(SYN_ID, "1", NOW)
		expect(#ctx.exoticLog).toBe(1)
		expect(ctx.exoticLog[1].exoticId).toBe("EX_002")
		expect(ctx.exoticLog[1].isNatural).toBeTrue()
	end)
end)

describe("JointSynthService — test 22: complete T4+T5 natural (known recipe) → both receive T6 result, rank awarded", function()
	it("both vaults get T6_01; rankLog has 2 synthesis entries", function()
		local ctx = setup()
		-- Stage with T4+T5 pair; opener has T4_01, partner declares T5_01
		JointSynthService.stage(opener, 1, "T4_01", "T5_01", false, false)
		-- Partner contributes T5_01
		JointSynthService.contribute(partner, 1, "T5_01")
		JointSynthService.complete(SYN_ID, "1", NOW)
		-- Both should have T6_01
		expect((ctx.profiles[1].vault.compounds["T6_01"] or 0) >= 1).toBeTrue()
		expect((ctx.profiles[2].vault.compounds["T6_01"] or 0) >= 1).toBeTrue()
		-- Rank awarded (isNatural=true)
		local synthCount = 0
		for _, entry in ipairs(ctx.rankLog) do
			if entry.source == "synthesis" then synthCount += 1 end
		end
		expect(synthCount).toBe(2)
	end)
end)

describe("JointSynthService — test 23: complete T4+T5 Accelerated → result delivered, rank NOT awarded", function()
	it("result in vaults but rankLog has zero synthesis entries", function()
		local ctx = setup()
		ctx.profiles[1].balances.catalysts = 100 -- ensure enough for accelerated
		JointSynthService.stage(opener, 1, "T4_01", "T5_01", false, true) -- accelerated=true
		JointSynthService.contribute(partner, 1, "T5_01")
		JointSynthService.complete(SYN_ID, "1", NOW)
		-- Result delivered
		local openerHas = (ctx.profiles[1].vault.compounds["T6_01"] or 0) >= 1
		local partnerHas = (ctx.profiles[2].vault.compounds["T6_01"] or 0) >= 1
		expect(openerHas).toBeTrue()
		expect(partnerHas).toBeTrue()
		-- No rank (isNatural=false)
		local synthCount = 0
		for _, entry in ipairs(ctx.rankLog) do
			if entry.source == "synthesis" then synthCount += 1 end
		end
		expect(synthCount).toBe(0)
	end)
end)

describe("JointSynthService — test 24: complete with offline partner → result in pendingJointResults", function()
	it("profileDs:UpdateAsync called for offline partner with pendingJointResults entry", function()
		local ctx = setup()
		-- Make partner offline
		ctx.onlinePlayers[2] = nil

		JointSynthService.stage(opener, 1, "T4_01", "T5_01", false, false)
		-- For contribute, make partner temporarily online
		ctx.onlinePlayers[2] = partner
		JointSynthService.contribute(partner, 1, "T5_01")
		-- Now partner goes offline before completion
		ctx.onlinePlayers[2] = nil

		JointSynthService.complete(SYN_ID, "1", NOW)

		-- Check that profileDs was written for partner
		local stored = ctx.profileDs:GetAsync("Player_2")
		-- profileDs might be nil if nothing was written (depends on whether partnerData is accessible)
		-- Since partner is offline, _dataService.getProfile returns nil, so pending goes to profileDs
		-- But our mock _dataService.getProfile(2) still returns profiles[2] even when "offline"
		-- The offline check is: openerPlayer and _dataService.getProfile() — openerPlayer is the Player object
		-- partnerPlayer is nil (offline), so partnerData = nil
		-- So the else branch writes to profileDs
		expect(stored ~= nil).toBeTrue()
		expect(stored.pendingJointResults ~= nil).toBeTrue()
		expect(#stored.pendingJointResults).toBe(1)
		expect(stored.pendingJointResults[1].resultId).toBe("T6_01")
	end)
end)

describe("JointSynthService — test 25: onLogin with pendingJointResults → delivers, clears list", function()
	it("vault gets T6_01; pendingJointResults is empty after", function()
		setup()
		local data = {
			vault = { compounds = {}, residue = 0 },
			pendingJointResults = {
				{ resultId = "T6_01", isNatural = true },
			},
		}
		JointSynthService.onLogin(opener, data, NOW)
		expect((data.vault.compounds["T6_01"] or 0)).toBe(1)
		expect(#data.pendingJointResults).toBe(0)
	end)
end)

describe("JointSynthService — test 26: async expiry → opener compound returned, cooldown set", function()
	it("opener gets T6_01 back; asyncCooldowns set for opener in syndicate record", function()
		local ctx = setup()
		-- Stage an async slot that has already expired
		JointSynthService.stage(opener, 1, "T6_01", "T6_02", true, false)
		-- Manually set expiresAt in the past
		ctx.syndicateDs:UpdateAsync("syndicate:" .. SYN_ID, function(rec)
			if rec and rec.jointSlots and rec.jointSlots["1"] then
				rec.jointSlots["1"].expiresAt = NOW - 1
			end
			return rec
		end)

		local haveBefore = ctx.profiles[1].vault.compounds["T6_01"] or 0
		JointSynthService.checkAsyncExpiries(NOW + 100)
		local haveAfter = ctx.profiles[1].vault.compounds["T6_01"] or 0
		expect(haveAfter).toBe(haveBefore + 1)

		-- Cooldown recorded in syndicate record
		local rec = ctx.syndicateDs:GetAsync("syndicate:" .. SYN_ID)
		local cooldown = rec.asyncCooldowns and rec.asyncCooldowns[tostring(opener.UserId)]
		expect(cooldown ~= nil).toBeTrue()
		expect(cooldown > NOW).toBeTrue()
	end)
end)

describe("JointSynthService — test 27: getRunningSlotInputs returns T6 slot for player", function()
	it("returns one entry with tier=6 and passivePerMin from compound", function()
		local ctx = setup()
		JointSynthService.stage(opener, 1, "T4_01", "T5_01", false, false)
		JointSynthService.contribute(partner, 1, "T5_01")
		-- Now slot is RUNNING with resultId = T6_01
		local inputs = JointSynthService.getRunningSlotInputs(SYN_ID, opener.UserId, NOW)
		expect(#inputs).toBe(1)
		expect(inputs[1].tier).toBe(6)
		expect(inputs[1].passivePerMin).toBe(50.0) -- T6_01.passivePerMin from mockCompounds
		expect(inputs[1].workRemainingSeconds > 0).toBeTrue()
	end)
end)

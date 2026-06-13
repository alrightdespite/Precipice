-- LabService: formula lab analysis (§11).
-- Handles refusal, fee, vault mutations, residue, Rush Analysis, and formulaLog writes.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(ServerScriptService.Server.Services.DataService)
local RemoteService = require(ServerScriptService.Server.Services.RemoteService)
local SeedService = require(ServerScriptService.Server.Services.SeedService)
local VaultService = require(ServerScriptService.Server.Services.VaultService)
local RecipeResolver = require(ReplicatedStorage.Shared.Core.RecipeResolver)
local LabAnalysis = require(ReplicatedStorage.Shared.Core.LabAnalysis)
local Compounds = require(ReplicatedStorage.Shared.Data.Compounds)

local _loaded: { [number]: boolean } = {}

local LabService = {}

-- ── Remote handler ─────────────────────────────────────────────────────────

local function wireRemotes()
	local analyzeFn = RemoteService.getFunction("LabAnalyze")
	analyzeFn.OnServerInvoke = function(player: Player, input1: any, input2: any)
		if type(input1) ~= "string" or type(input2) ~= "string" then
			return nil, "invalid args"
		end

		local userId = player.UserId
		if not _loaded[userId] then
			return nil, "session not ready"
		end

		local c1 = Compounds[input1]
		local c2 = Compounds[input2]
		if not c1 or not c2 then
			return nil, "unknown compound"
		end

		-- Refusal: tier-bracket check, not recipe lookup (§11)
		local refusal = LabAnalysis.getRefusal(c1.tier, c2.tier)
		if refusal then
			return { status = "refused", refusalKind = refusal }, nil
		end

		local pKey = LabAnalysis.pairKey(input1, input2)
		local minT = math.min(c1.tier, c2.tier)

		-- Required vault entries (same compound used twice → qty 2)
		local required: { [string]: number } = {}
		required[input1] = (required[input1] or 0) + 1
		required[input2] = (required[input2] or 0) + 1

		local result = nil
		local failErr = nil
		local vaultChanged = false
		local balanceChanged = false

		DataService.updateProfile(userId, function(data)
			-- Cache hit: already known to fail → no charge, no vault touch (§11)
			if data.formulaLog.failedPairs[pKey] then
				result = { status = "cached_failure", feePaid = 0, residueAwarded = 0, isRush = false }
				return
			end

			-- Rush Analysis: data.monetization.rushUses > 0 (§25, D18)
			local isRush = data.monetization.rushUses > 0

			-- Fee: waived for Rush, otherwise bracket by min tier + prestige (§11, §22/C32)
			local fee = if isRush then 0 else LabAnalysis.getFee(minT, data.prestige.level)

			-- Balance check
			if not isRush and data.balances.pellets < fee then
				failErr = "insufficient pellets"
				return
			end

			-- Vault check: player must hold the input compounds
			for cid, qty in pairs(required) do
				if (data.vault.compounds[cid] or 0) < qty then
					failErr = "insufficient " .. cid
					return
				end
			end

			-- Deduct fee
			if fee > 0 then
				data.balances.pellets -= fee
				balanceChanged = true
			end

			-- Consume Rush use
			if isRush then
				data.monetization.rushUses = math.max(0, data.monetization.rushUses - 1)
			end

			-- Resolve: Rush forces primary variant regardless of seed (§25, D7)
			local weekSeed = SeedService.getCurrentWeekSeed()
			local labResult = RecipeResolver.getLabResult(input1, input2, weekSeed, isRush)

			if labResult.valid then
				-- Success: consume inputs, award discovered compound (§11)
				for cid, qty in pairs(required) do
					VaultService.applyDeduct(data, cid, qty)
				end
				VaultService.applyAward(data, labResult.resultId :: string, 1)
				data.formulaLog.discovered[labResult.resultId :: string] = true
				vaultChanged = true
				-- TODO Phase 6: RankService.recordDiscovery(userId, labResult.resultId)
				result = {
					status = "discovery",
					resultId = labResult.resultId,
					isVariable = labResult.isVariable,
					isPrimary = labResult.isPrimary,
					feePaid = fee,
					isRush = isRush,
				}
			else
				-- Failure: inputs returned unharmed, residue awarded, pair logged (§11, §12)
				local residueAmt = LabAnalysis.getResidueAmount(minT)
				VaultService.applyResidue(data, residueAmt)
				data.formulaLog.failedPairs[pKey] = true
				vaultChanged = true
				result = {
					status = "failure",
					residueAwarded = residueAmt,
					feePaid = fee,
					isRush = isRush,
				}
			end
		end)

		if failErr then
			return nil, failErr
		end

		-- Fire remotes outside updateProfile
		if vaultChanged or balanceChanged then
			local data = DataService.getProfile(userId)
			VaultService.fireVaultUpdate(player, data)
			if balanceChanged then
				RemoteService.getEvent("BalanceUpdate"):FireClient(
					player,
					data.balances.pellets,
					data.balances.catalysts
				)
			end
		end

		if result and result.status == "discovery" then
			RemoteService.getEvent("LabDiscovery"):FireClient(player, result.resultId)
		end

		return result, nil
	end
end

-- ── Init ───────────────────────────────────────────────────────────────────

function LabService.init()
	DataService.onProfileLoaded:Connect(function(userId)
		_loaded[userId] = true
	end)
	DataService.onProfileReleased:Connect(function(userId)
		_loaded[userId] = nil
	end)
	wireRemotes()
end

return LabService

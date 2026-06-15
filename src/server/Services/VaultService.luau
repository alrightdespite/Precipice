-- VaultService: owns all vault mutations; fires VaultUpdate after every change.
-- SlotService calls applyAward/applyDeduct inside its own updateProfile callbacks,
-- then calls fireVaultUpdate after. LabService calls awardResidue (Phase 3).

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(ServerScriptService.Server.Services.DataService)
local RemoteService = require(ServerScriptService.Server.Services.RemoteService)
local Compounds = require(ReplicatedStorage.Shared.Data.Compounds)
local ContractService = require(ServerScriptService.Server.Services.ContractService)

local VaultService = {}

-- ── Inner helpers (use inside an existing updateProfile callback) ─────────────

function VaultService.applyAward(data: any, compoundId: string, qty: number)
	data.vault.compounds[compoundId] = (data.vault.compounds[compoundId] or 0) + qty
end

function VaultService.applyDeduct(data: any, compoundId: string, qty: number)
	local have = data.vault.compounds[compoundId] or 0
	assert(have >= qty, "VaultService.applyDeduct: insufficient " .. compoundId)
	data.vault.compounds[compoundId] = have - qty
end

-- §12: called by LabService on failed analysis. Unit sell value is 15 Pellets flat.
function VaultService.applyResidue(data: any, amount: number)
	data.vault.residue = (data.vault.residue or 0) + amount
end

-- ── Remote push ───────────────────────────────────────────────────────────────

function VaultService.fireVaultUpdate(player: Player, data: any)
	RemoteService.getEvent("VaultUpdate"):FireClient(player, data.vault)
end

-- ── Full-operation API (own their own updateProfile + remote fire) ────────────

function VaultService.awardCompounds(userId: number, compoundId: string, qty: number)
	DataService.updateProfile(userId, function(data)
		VaultService.applyAward(data, compoundId, qty)
	end)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		VaultService.fireVaultUpdate(player, DataService.getProfile(userId))
	end
end

-- §12: LabService calls this after a failed analysis.
function VaultService.awardResidue(userId: number, amount: number)
	DataService.updateProfile(userId, function(data)
		VaultService.applyResidue(data, amount)
	end)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		VaultService.fireVaultUpdate(player, DataService.getProfile(userId))
	end
end

-- ── VaultInstantSell remote (§16) ─────────────────────────────────────────────

local function wireRemotes()
	local sellFn = RemoteService.getFunction("VaultInstantSell")
	sellFn.OnServerInvoke = function(player: Player, compoundId: any, quantity: any)
		if not DataService.isLoaded(player.UserId) then return 0, "session not ready" end
		if type(compoundId) ~= "string" or type(quantity) ~= "number" then
			return 0, "invalid args"
		end
		quantity = math.floor(quantity)
		if quantity <= 0 then
			return 0, "quantity must be positive"
		end

		local compound = Compounds[compoundId]
		if not compound then
			return 0, "unknown compound"
		end

		local userId = player.UserId
		local earned = 0
		local failErr = nil

		DataService.updateProfile(userId, function(data)
			local have = data.vault.compounds[compoundId] or 0
			if have < quantity then
				failErr = "insufficient compounds"
				return
			end
			-- Instant sell = baseValue × qty, no market fee (§16)
			VaultService.applyDeduct(data, compoundId, quantity)
			earned = compound.baseValue * quantity
			data.balances.pellets += earned
			ContractService.recordProgress(player, data, "instant_sell", 1)
		end)

		if failErr then
			return 0, failErr
		end

		local data = DataService.getProfile(userId)
		VaultService.fireVaultUpdate(player, data)
		RemoteService.getEvent("BalanceUpdate"):FireClient(
			player,
			data.balances.pellets,
			data.balances.catalysts
		)

		return earned, nil
	end
end

-- ── Init ─────────────────────────────────────────────────────────────────────

function VaultService.init()
	wireRemotes()

	-- Push initial vault snapshot on join (before offline settle runs)
	DataService.onProfileLoaded:Connect(function(userId)
		local player = Players:GetPlayerByUserId(userId)
		if player then
			VaultService.fireVaultUpdate(player, DataService.getProfile(userId))
		end
	end)
end

return VaultService

-- CosmeticService: §24 personal cosmetics — purchase (Pellets/Catalysts), equip, event grants.
-- Pure catalog + rules live in Core/CosmeticCatalog; this service wires them to remotes + data.
-- Zero gameplay effect; selections are personal (client renders only the owner's choices).

local CosmeticService = {}

local _ds: any = nil -- DataService
local _rs: any = nil -- RemoteService
local _catalog: any = nil -- Core/CosmeticCatalog

-- ── Mutations (run inside DataService.updateProfile transforms) ──────────────

-- Purchase a currency-priced cosmetic. Mutates data.balances + data.cosmetics.owned.
function CosmeticService.purchase(_player: any, data: any, id: string): (boolean, string?)
	local ok, reason = _catalog.canPurchase(data, id)
	if not ok then
		return false, reason
	end
	local item = _catalog.get(id)
	data.cosmetics.owned = data.cosmetics.owned or {}
	data.balances[item.currency] -= item.price
	data.cosmetics.owned[id] = true
	return true, nil
end

-- Equip an owned cosmetic into its category slot. Mutates data.cosmetics.equipped.
function CosmeticService.equip(_player: any, data: any, id: string): (boolean, string?)
	local ok, reason = _catalog.canEquip(data, id)
	if not ok then
		return false, reason
	end
	local item = _catalog.get(id)
	data.cosmetics.equipped = data.cosmetics.equipped or {}
	data.cosmetics.equipped[item.category] = id
	return true, nil
end

-- Grant an event-pass cosmetic (e.g. Industrial Hazmat / Cascade Seal). Called by EventService
-- when an event pass is acquired. Idempotent.
function CosmeticService.grantEventCosmetic(data: any, id: string): boolean
	local item = _catalog.get(id)
	if item == nil or item.unlock ~= "event" then
		return false
	end
	data.cosmetics.owned = data.cosmetics.owned or {}
	data.cosmetics.owned[id] = true
	return true
end

-- ── S2C ──────────────────────────────────────────────────────────────────────

function CosmeticService.fireCosmeticUpdate(player: any, data: any)
	if not _rs then
		return
	end
	_rs.getEvent("CosmeticUpdate"):FireClient(player, data.cosmetics.owned or {}, data.cosmetics.equipped or {})
end

-- ── Init ───────────────────────────────────────────────────────────────────

function CosmeticService.init()
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	_ds = require(ServerScriptService.Server.Services.DataService)
	_rs = require(ServerScriptService.Server.Services.RemoteService)
	_catalog = require(ReplicatedStorage.Shared.Core.CosmeticCatalog)

	_rs.setInvoke("CosmeticPurchase", function(player: Player, cosmeticId: any)
		if type(cosmeticId) ~= "string" then
			return false, "invalid args"
		end
		local userId = player.UserId
		if not _ds.isLoaded(userId) then
			return false, "session not ready"
		end
		local ok, err = false, nil
		_ds.updateProfile(userId, function(data)
			ok, err = CosmeticService.purchase(player, data, cosmeticId)
		end)
		if ok then
			local data = _ds.getProfile(userId)
			CosmeticService.fireCosmeticUpdate(player, data)
			_rs.getEvent("BalanceUpdate"):FireClient(
				player,
				data.balances.pellets,
				data.balances.catalysts,
				data.monetization.rushUses,
				data.monetization.timerSkipUses or 0
			)
		end
		return ok, err
	end)

	_rs.setInvoke("CosmeticEquip", function(player: Player, cosmeticId: any)
		if type(cosmeticId) ~= "string" then
			return false, "invalid args"
		end
		local userId = player.UserId
		if not _ds.isLoaded(userId) then
			return false, "session not ready"
		end
		local ok, err = false, nil
		_ds.updateProfile(userId, function(data)
			ok, err = CosmeticService.equip(player, data, cosmeticId)
		end)
		if ok then
			CosmeticService.fireCosmeticUpdate(player, _ds.getProfile(userId))
		end
		return ok, err
	end)
end

return CosmeticService

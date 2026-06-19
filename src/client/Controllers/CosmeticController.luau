-- CosmeticController: thin client wrapper over the CosmeticPurchase / CosmeticEquip remotes (§24).
-- Ownership/equipped state arrives via CosmeticUpdate (RemoteController → StateController.cosmetics);
-- this controller only issues the C2S calls and normalizes their (ok, err) result.

local RemoteController = require(script.Parent.RemoteController)

local CosmeticController = {}

local function call(remoteName: string, id: string): (boolean, string?)
	local pcallOk, ok, err = RemoteController.invoke(remoteName, id)
	if not pcallOk then
		return false, "request failed"
	end
	return ok == true, err
end

function CosmeticController.purchase(id: string): (boolean, string?)
	return call("CosmeticPurchase", id)
end

function CosmeticController.equip(id: string): (boolean, string?)
	return call("CosmeticEquip", id)
end

function CosmeticController.init(): typeof(CosmeticController)
	return CosmeticController
end

return CosmeticController

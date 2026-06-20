local RemoteController = require(script.Parent.RemoteController)

local MarketController = {}

function MarketController.createListing(compoundId: string, quantity: number, price: number): (boolean, string?)
	return RemoteController.invoke("MarketCreateListing", compoundId, quantity, price)
end

function MarketController.cancelListing(listingId: string): (boolean, string?)
	return RemoteController.invoke("MarketCancelListing", listingId)
end

function MarketController.buyListing(listingId: string): (boolean, string?)
	return RemoteController.invoke("MarketBuyListing", listingId)
end

-- The server returns (listings, err); RemoteController.invoke passes them through
-- directly (no leading pcallOk on success). Normalize to (ok, listings) so the
-- screen's `local ok, result = browse(...)` check works.
function MarketController.browse(tier: number?, page: number): (boolean, { {} } | string)
	local listings, err = RemoteController.invoke("MarketBrowse", tier, page)
	if type(listings) ~= "table" then
		return false, err or "request failed"
	end
	return true, listings
end

function MarketController.init(): typeof(MarketController)
	return MarketController
end

return MarketController

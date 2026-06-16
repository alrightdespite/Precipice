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

function MarketController.browse(tier: number?, page: number): (boolean, { {} } | string)
	return RemoteController.invoke("MarketBrowse", tier, page)
end

function MarketController.init(): typeof(MarketController)
	return MarketController
end

return MarketController

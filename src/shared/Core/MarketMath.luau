-- MarketMath: pure market price and fee calculations (doc §16, E7).
-- No Roblox globals. Lune-testable.
--
-- Contract:
--   Bounds are enforced at listing creation only (E7).
--   LISTING_FEE_RATE = 0.01 (1%), minimum 1 Pellet.
--   SALE_FEE_RATE = 0.05 (5%).
--   isValidPrice(price, baseValue) → boolean
--   listingFee(askingPrice) → Pellets charged at creation
--   sellerProceeds(salePrice) → Pellets received by seller
--   buyerCost(salePrice) → same as salePrice (buyer pays the listed price)

local PRICE_FLOOR_RATIO = 0.80
local PRICE_CEILING_RATIO = 5.00
local LISTING_FEE_RATE = 0.01
local SALE_FEE_RATE = 0.05

local MarketMath = {}

function MarketMath.isValidPrice(price: number, baseValue: number): boolean
	local floor = math.floor(baseValue * PRICE_FLOOR_RATIO)
	local ceiling = math.ceil(baseValue * PRICE_CEILING_RATIO)
	return price >= floor and price <= ceiling
end

function MarketMath.listingFee(askingPrice: number): number
	return math.max(1, math.floor(askingPrice * LISTING_FEE_RATE))
end

function MarketMath.sellerProceeds(salePrice: number): number
	local fee = math.floor(salePrice * SALE_FEE_RATE)
	return salePrice - fee
end

function MarketMath.priceFloor(baseValue: number): number
	return math.floor(baseValue * PRICE_FLOOR_RATIO)
end

function MarketMath.priceCeiling(baseValue: number): number
	return math.ceil(baseValue * PRICE_CEILING_RATIO)
end

return MarketMath

# MarketService

## Mission

Cross-server compound marketplace. Players list compounds for sale; other players buy. Uses MemoryStore sorted map for fast browse, DataStore for durable listings. Enforces price floors/ceilings and listing fees.

## Key rules (E7)

- Price floor/ceiling via `MarketMath.priceFloor` / `priceCeiling`
- Listing fee: `MarketMath.listingFee(price, quantity)` deducted from seller on create
- Seller proceeds: `MarketMath.sellerProceeds(price, quantity)` at time of sale
- Listings expire after 72h; expiry handled by hourly sweep job (GlobalJobService)
- MemoryStore index per tier; fallback to rebuilt DataStore index on miss (H4)
- `MarketBrowse` is paginated (page size 20)

## Dependencies

- `MarketMath` (price validation, fees)
- `GlobalJobService` (hourly sweep)
- `DataService` (player balances/vault)

## Phase

Phase 3.

# SeedService

## Mission

Manages the weekly seed used for variable recipe pair selection. Reads salt from DataStore key `Config/SeedSalt` (generated once on first boot, never hardcoded). Provides `getCurrentWeekSeed()` to RecipeResolver.

## Key rules

- Salt stored in DataStore, never in source (design doc constraint, Task 3)
- Salt never sent to client
- `SeedResolver.setSalt(salt)` called at boot by SeedService after DataStore read
- Production: HMAC-SHA256 (stub in Phase 0; real implementation Phase 2)
- SeedService is singleton; initialized in GameInit boot order before SlotService

## Phase

Phase 2.

# LabService

## Mission

Handles formula lab analysis (§11). Players pay a fee to test two compounds for a recipe. Manages discovered-formula log in profile, Validated marks for joint-declared pairs, and formula rush monetization.

## Key rules

- Analysis fee: standard 200P, rush 500P. Deducted before result returned.
- If pair is already in `failedPairs`: no charge, return cached result
- If pair produces a recipe: add to `formulaLog.discovered`, award Rank score
- Button-state table (§11): four states — Unknown, Validated, Discovered, Failed. All four rows are mandatory unit tests (Phase 2).
- `LabDiscovery` remote fired S2C on new discovery

## Dependencies

- `RecipeResolver` (resolve pair to recipe)
- `DataService` (read/write formulaLog, balances)
- `RankService` (score discovery)

## Phase

Phase 2.

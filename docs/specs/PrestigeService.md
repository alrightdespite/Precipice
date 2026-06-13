# PrestigeService

## Mission

Handles prestige (soft reset). Validates prestige eligibility, wipes appropriate profile fields, applies prestige bonuses, and increments prestige level.

## Key rules

- `PrestigeRequest` returns list of blockers (unmet requirements) or empty → ready
- `PrestigeConfirm` executes the reset after second client confirmation
- Reset wipes: vault, balances (above floor), slots, contracts, streak, rank (current run only)
- Preserves: lifetime rank, formulaLog (discoveries), jointQualLifetime, monetization
- Each prestige level grants 10% fee reduction on lab analysis (stacks, up to design doc cap)
- Prestige cost from EconomyParams

## Phase

Phase 5.

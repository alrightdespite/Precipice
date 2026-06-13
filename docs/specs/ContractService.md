# ContractService

## Mission

Draws and tracks daily contracts from `ContractPool.luau`. Awards Pellets and rank score on completion. Manages the daily contract refresh epoch.

## Key rules

- Draw 3 contracts per day: 1 Easy, 1 Medium, 1 Hard (from ContractPool 8+8+8)
- Contracts tied to `profile.contracts.dayKey`; stale key → redraw on next login
- Progress incremented by SlotService (natural synthesis completions) and VaultService (sell events)
- `ContractUpdate` fires S2C after any progress change
- Reward deferred until reveal (player must claim)

## Phase

Phase 3.

# SlotService

## Mission

Manages all extraction and synthesis slot state. Ticks slots forward, writes results to the player profile, fires slot-update remotes. Enforces all Natural Completion Rule (§14) checks and delegates passive income settlement to OfflineIncome on player join.

## Responsibilities

- Start extraction: validate compound is discovered, slot is free, return `err` otherwise
- Start synthesis: validate inputs, formula legality (RecipeResolver), slot availability
- Cancel: zero out slot, no reward
- Reveal: mark slot complete, award compound to vault, score rank points (if natural)
- Skip (Accelerated): mark `isNatural = false`, advance `workRemaining` to zero
- Tick: called each server heartbeat (~1/s); calls `TimerMath.settle` on each running slot; fires `SlotStateUpdate` remote on change
- On player join: call `OfflineIncome.settle` with all running slots + elapsed offline time; apply result to profile balances and vault

## Work-units model (E1)

Slots store `{workRemaining, lastTickAt, mode}`. Never store a fixed end timestamp.

Online tick: `workRemaining -= elapsed × 1.0`
Offline (in settle): `workRemaining -= elapsed × 0.8`

On mode change: call `TimerMath.setMode` to settle first then change mode.

## Natural Completion Rule (§14)

A completion is natural iff `isNatural == true` at time of reveal. `isNatural` starts true, is set false by any Skip/Accelerated action. Natural completions count for:
- Patent 30-day synthesis count
- Sprint points
- Rank score
- Flux

Non-natural completions still award the compound and passive income.

## Slot caps

Base: 1 extraction, 2 synthesis. Gamepass/prestige expansions tracked in `GameConfig.luau`. SlotService reads cap from profile (prestige level) + monetization (gamepass flag) on each slot action.

## Remotes used

- `SlotStartExtraction` (C2S, validates and starts)
- `SlotStartSynthesis` (C2S, validates and starts)
- `SlotCancel` (C2S)
- `SlotReveal` (C2S, awards compound)
- `SlotSkip` (C2S, marks non-natural)
- `SlotStateUpdate` (S2C, fires on change)

All C2S remotes validate arguments server-side before touching profile. Invalid args return `false, "error message"`.

## Offline income settlement (§10)

On player join:
1. Compute `offlineSeconds = now - lastSeenAt` (capped at `GameConfig.OFFLINE_CAP_SECONDS`)
2. Call `OfflineIncome.settle(slots, offlineSeconds, capSeconds)`
3. Apply `result.pellets` to `balances.pellets`
4. Add `result.compounds` to vault
5. Update each slot's `workRemaining` and `lastTickAt`
6. Fire `OfflineIncomeDelivered` with breakdown

## Dependencies

- `src/shared/Core/TimerMath.luau`
- `src/shared/Core/OfflineIncome.luau`
- `src/shared/Core/RecipeResolver.luau`
- `DataService` (read/write profile)
- `RankService` (score natural completions)
- `PatentService` (record natural syntheses for count)

## Testing

- Spec: `tests/specs/SlotService.luau` (Phase 2)
- OfflineIncome Lune tests already cover §10 example
- Slot state-machine tests: start→tick→complete, skip sets isNatural=false, cancel resets

## Phase

Phase 2.

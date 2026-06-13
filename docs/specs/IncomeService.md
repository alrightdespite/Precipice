# IncomeService

## Mission

Drives passive income during online play. Ticks each running slot at the server heartbeat, computes earned Pellets using `OfflineIncome`-compatible math (rate × elapsed), adds to balance, fires `BalanceUpdate` remote. Also delivers deferred offline income on player join (delegates to SlotService).

## Key rules

- Online rate 1.0 × passivePerMin; offline rate 0.8 × (handled by OfflineIncome at join)
- Uses `math.round` for Pellet calculation (IR-01)
- Passive income does NOT require natural completion (§10 applies regardless of skip)
- BalanceUpdate fires per-tick only if delta > 0

## Phase

Phase 2.

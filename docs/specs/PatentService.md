# PatentService

## Mission

Manages compound patents — first-to-synthesize ownership, challenge windows, defense periods, and dividend payouts. Uses `Patents/{compoundId}` global DataStore with GlobalJobService CAS locks.

## Key rules (§15, R12)

- First natural synthesis of a compound earns a patent
- Challenge window by tier: T2-3=72h, T4=96h, T5=120h, T6-7=7d
- Immunity period: 7 days after challenge resolution
- 30-day rolling synthesis count: leader in top 7-of-30 days earns patent dividend
- Challenger queue: challenges 4+ wait; processed in order
- Non-natural completions (§14) do NOT count toward synthesis count
- `PatentWindow.luau` is the pure-logic layer; PatentService wraps it with DataStore ops

## Mandatory unit tests (Phase 4)

- Defense windows for all 7 tiers
- Multi-party race: holder/challenger/queued third

## Phase

Phase 4.

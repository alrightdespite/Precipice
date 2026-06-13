# ExoticService

## Mission

Handles exotic compound synthesis (T6+T6 → T7). Manages unit count, value decay, and first-pair claim bonuses. Persists to `Exotics/{exoticId}` global DataStore.

## Key rules (R13)

- Exotic value: `initialValue × 0.97^unitCount`, floor at 25% of initialValue
- Unit count incremented atomically (R13: IncrementAsync or UpdateAsync CAS)
- First pair (userId1, userId2) recorded once; subsequent pairs earn base value only
- Claim bonus sourced from Exotics data table
- Mandatory unit test: `0.97^46 < 0.25` → floor kicks in at unit 46 (Phase 5)
- ExoticService fires Announcement remote on world-first generation

## Phase

Phase 5.

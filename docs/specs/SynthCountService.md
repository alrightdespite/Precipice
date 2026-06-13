# SynthCountService

## Mission

Maintains 30-day rolling natural synthesis counts per compound (`SynthCounts/{compoundId}`). Provides count queries to PatentService and leaderboard display. Prunes entries older than 30 days on every write (H6 write budget).

## Key rules

- Only natural completions (§14) increment counts
- Sharding deferred to Phase 4 (hot compounds may need `shard_0..N`)
- Queries: `getCount(compoundId, windowDays)` → number

## Phase

Phase 4.

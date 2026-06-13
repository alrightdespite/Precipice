# LeaderboardService

## Mission

Reads Sprint and ChiefBoard OrderedDataStores and serves paginated leaderboard results to clients. Caches results in MemoryStore to reduce ODS reads. Computes percentile blobs stored in GlobalJobs for rank display.

## Key rules

- `LeaderboardRequest` remote returns up to 100 rows + player's own row
- Percentile blob refreshed weekly by GlobalJobService WeeklyEpochRotation job
- Stale cache (>60s) triggers background ODS refresh; client gets slightly stale data, not blocked

## Phase

Phase 3.

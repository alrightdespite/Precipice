# RankService

<!-- Sprint tracking merged into RankService per Session B decision. No separate SprintService.
     See addSprintPoints and archiveSprint. -->

## Mission

Manages player rank score (current run and lifetime) and sprint leaderboard. Uses `RankMath.luau` for score computation. Persists via player profile (rank sub-table) and `Sprint_{isoWeek}` / `ChiefBoard` OrderedDataStores.

## Key rules

- Rank score sources: natural synthesis completion, formula discovery, market sale, vault contribution (weights in RankMath / EconomyParams)
- Daily caps on market and vault rank points (profile.rank.dailyCaps)
- Sprint points reset weekly (isoWeek epoch); stale `sprintPoints.weekEpoch` entries ignored
- `RankUpdate` remote fires S2C on score change
- `LeaderboardRequest` returns paginated ODS rows (Sprint or ChiefBoard)

## Phase

Phase 3.

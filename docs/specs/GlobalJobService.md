# GlobalJobService

## Mission

Singleton lock service for cross-server jobs (patent dividend sweeps, market expiry sweeps, weekly epoch rotation). Implements the CAS UpdateAsync lock pattern (H1). Prevents duplicate execution across servers.

## Key rules (H1)

- Lock acquired via `GlobalJobs.locks[jobName]` UpdateAsync CAS
- Lock record: `{owner: serverId, expiresAt: now + ttl}`; stale locks (expiresAt < now) can be stolen
- Ledger tracks named steps per runKey; idempotent re-runs skip completed steps
- Jobs: `WeeklyEpochRotation`, `DailyContractRefresh`, `MarketExpirySweep`, `PatentDividendSweep`
- Sweep interval: every `PatentWindow.SWEEP_INTERVAL` seconds (900s) for patent windows

## Dependencies

- MockDataStore covers all lock patterns in Lune tests
- `GlobalJobs` DataStore key

## Phase

Phase 4.

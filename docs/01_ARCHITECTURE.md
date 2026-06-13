# Architecture

## Core / Service split

`src/shared/Core/` — **pure logic modules**. No Roblox globals. Clock injected. Lune-testable. Carry the full rule weight of the design doc. These are the only files Lune tests hammer directly.

`src/server/Services/` — **thin service adapters**. Wire Core to DataStores, remotes, and the game world. Get integration tests in Studio.

## Boot order (H9)

Fixed in `GameInit.server.luau`:

1. Config (`GameConfig`, `EconomyConstants`)
2. Data tables (generated modules auto-loaded by Core)
3. **RemoteService** — creates all remotes from `Remotes/Manifest.luau`
4. **DataService** — ProfileStore session lock, schema migration
5. **ClockService** — UTC tick, epoch detection
6. All other services (no fixed order among them, no inter-init yielding)
7. **PlayerAdded** wiring — **always last**

No service may yield during another's `init()`.

## Remote pattern (E13)

Zero authored `RemoteEvent`/`RemoteFunction` instances. All remotes created at boot by `RemoteService` from `Remotes/Manifest.luau`. The CI guard (`tests/specs/RemotesGuard.luau`) fails the build if any `.luau` file outside `RemoteService` instantiates a remote.

## Concurrency patterns (R13)

All named here; referenced by service specs.

- **Market purchase**: `UpdateAsync` compare-and-set on listing record (state must be `ACTIVE`); loser gets "already sold." Buyer debit reserved first, refunded on CAS failure.
- **Joint slot mutations**: all writes via `UpdateAsync` on syndicate record with state-machine guard (`EMPTY → STAGED → MATCHED → RUNNING → COMPLETE`); illegal transitions rejected.
- **World-first / Exotic-first claims**: `UpdateAsync` on patent record; first writer wins; losers get §13 "moments before you" path. DataStore is the arbiter — never MemoryStore.
- **PendingCredits**: append-only `UpdateAsync` on a per-user key, never touching the session-locked main profile. Drained transactionally at login.

## GlobalJobService pattern (H1)

Every cross-server singleton job uses the same pattern:

1. **Lock**: `{ owner, expiresAt }` DataStore record per job, taken via `UpdateAsync` CAS. TTL 5 min, renewed every 1 min by owner.
2. **Ledger**: per run key (e.g. `weekly:2026-W24`), named steps → completion stamps. Each step stamped after its effects are durably written.
3. **Resume**: any claimant reads ledger, starts at first unstamped step. Stamped steps never re-executed.
4. **Trigger**: ClockService fires candidates; MessagingService broadcast is hint only (H3).

Monday job step order (mandated): 1) dividends, 2) Sprint archive + badges, 3) Sprint score wipe, 4) seed epoch announcement.

## Messaging covenant (H3)

MessagingService is a hint, never truth. Subscribe for speed; poll for correctness.

| Signal | Poll interval |
|---|---|
| Epoch/week ledger | 60 s |
| Announcement queue | 30 s |
| Patent/challenge state | on-view + 15-min sweep |
| Market index | lazily on browse |
| Percentile blob | hourly |

## Write budgets (H6)

8-player server: 60 + 10×8 = 140 DS requests/min.

- Rank scores → OrderedDataStore: debounced, flush every 30 s if dirty + on logout.
- Profile autosave: ProfileStore default cadence only.
- SynthCounts: one `UpdateAsync` per natural completion; prune entries >30 days on every touch.
- Leaderboard reads: cached per server 60 s.

## Service inventory (24 services)

See `docs/specs/` for full specs. Brief responsibilities:

| Service | One-line responsibility |
|---|---|
| DataService | ProfileStore sessions, schema migrations, PendingCredits drain |
| RemoteService | Creates all remotes from Manifest at boot |
| ClockService | UTC tick, Monday/daily epoch detection |
| GlobalJobService | Singleton lock; dividends → Sprint reset → seed epoch → sweeps |
| SlotService | Personal slot state machine, work-units model, Prestige blockers |
| IncomeService | Online accrual tick, offline settlement |
| VaultService | Inventory, residue, instant sell |
| LabService | Analysis flow: fees, validity, discovery, residue, refusal rules |
| RecipeService | Static lookups over generated data; variable-pair resolution |
| MarketService | Listing CRUD, atomic purchase, PendingCredits, stats |
| PatentService | 30-day counts, claim flow, challenges, windows, sweep |
| SyndicateService | Roles, vault, upgrades, succession |
| JointSynthService | Declaration staging, joint analysis, completion fan-out |
| ExoticService | Seed-table lookup, unit counters, decay valuation |
| RankService | All score sources, caps, titles, Prestige gate |
| SprintService | Weekly tally, OrderedDataStore writes |
| LeaderboardService | Sprint top-50 + Chief top-100 reads |
| ContractService | Lazy daily generation, progress, rewards |
| StreakService | 36h window, milestones |
| PrestigeService | Blocker eval, pre-reset steps, reset, patent release |
| MonetizationService | Gamepasses, dev products, Catalyst wallet, receipts |
| EventService | Cascade lifecycle, Flux, blueprints, event patents |
| CosmeticService | Catalog, purchase, equip |
| AnnouncementService | MessagingService topic, 30s-gap queue, tier-scoped routing |
| AnalyticsService | §30 telemetry commitments |

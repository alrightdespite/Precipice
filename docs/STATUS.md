# Status

## Current phase: Phase 6A complete -> Session B next

**Last updated:** 2026-06-14

## Done

- [x] Task 1: PRECIPICE_SCAFFOLD -- rokit.toml, wally.toml, default.project.json, .gitignore, directory tree
- [x] Task 2: PRECIPICE_DATA -- data/gen/export_data.py, all 7 generated Data/ modules
- [x] Task 3: PRECIPICE_CORE -- Remotes/Manifest, RemoteService, GameInit, Config/GameConfig, Config/EconomyConstants, Core/TimerMath, Core/RecipeResolver, Core/SeedResolver, Core/MarketMath, Core/PatentWindow, Core/RankMath, Core/OfflineIncome
- [x] Task 4: PRECIPICE_TESTS -- tests/spec.luau, mocks/MockDataStore, mocks/MockClock, tests/run.luau, specs/DataIntegrity, specs/RemotesGuard, specs/OfflineIncome, specs/TimerMath
- [x] Task 5: PRECIPICE_DOCS -- docs/00_INDEX through 06_WORKFLOW, all 24 service stubs, DataService.md, SlotService.md, ui/ stubs, data/ stubs, root CLAUDE.md
- [x] Task 6: PRECIPICE_CLOSE -- 33/33 tests green, 0 selene errors, 0 stylua diffs, final commit
- [x] Task 7: PRECIPICE_PHASE1 -- DataService (ProfileStore sessions, migrations, PendingCredits drain); 46/46 tests green
- [x] Task 8: PRECIPICE_PHASE2 -- SeedService (salt read/generate/persist, SeedResolver wiring); SlotMachine (pure state machine, Lune-tested); SlotService (remotes, offline settle, heartbeat tick)
- [x] Task 9: PRECIPICE_PHASE3_VAULT -- VaultService (vault mutations, instant sell, VaultUpdate); SlotService refactor (all data.vault writes go through VaultService); 83/83 tests green
- [x] Task 10: PRECIPICE_PHASE3_LAB -- LabAnalysis pure core (pairKey, getRefusal, getFee, getResidueAmount, getButtonState); LabService (LabAnalyze remote, fee/refusal/rush/residue/discovery flow); 118/118 tests green
- [x] Task 11: PRECIPICE_PHASE4 -- GlobalJobService (H1 CAS lock/ledger/resume, NoopJob); SynthCountService (30-day rolling counts, per-user queries, prune-on-write); PatentService (first-claim, challenge/immunity/queue, decay sweep, two-pass multi-party race); SlotService wired to PatentService.recordNaturalSynthesis; Manifest +3 patent remotes; 156/156 tests green
- [x] Task 12: PRECIPICE_PHASE5 -- MarketService (createListing/cancelListing/buyListing/browseTier CAS purchase R13, hourly expiry sweep, PendingCredits offline seller/expiry paths, per-tier DataStore index H4, listing fee + seller proceeds via MarketMath); 170/170 tests green
- [x] Task 13: PRECIPICE_PHASE6A -- ProfileTemplate v2 (lastLoginAt/slots rename + migration [1]); EconomyConstants streak constants; ContractPool rewrite (easy/medium/hard arrays, progressType+filter enums, 5-slot draw rule 3+2); StreakService (grace window, milestone/repeating rewards, StreakUpdate S2C); ContractService (daily draw, filter eval, recordProgress, claimReward, ContractClaim C2S); RankService stub; Manifest +ContractClaim; GameInit wired; 200/200 tests green

## In progress

None.

## Next

Session B (Phase 6 completion): RankService, SprintService, LeaderboardService, full contract wiring
- `RankService`: lifetime rank tracking, prestige-run counter, RankUpdate remote, daily sprint reset
- `SprintService`: weekly sprint scores, sprint archive on epoch rotation
- `LeaderboardService`: ordered score tables for sprint and chiefs boards, LeaderboardRequest remote
- Wire Session B TODOs: ContractService.recordProgress in SlotService, VaultService, LabService, MarketService

## Known issues

- `SeedResolver.getCurrentWeekNumber` may be off by one week in some edge cases (ISO week boundary formula). Seeds change at consistent intervals so gameplay is unaffected, but the computed week number may not match ISO 8601 exactly. Flag for audit in Phase 11.

## Open questions

None currently.

## Known blockers

- `lune`/`rokit` require PATH addition on Windows (IR-02): `$env:PATH += ";$env:USERPROFILE\.rokit\bin"`

# Status

## Current phase: Phase 2 complete → Phase 3 next

**Last updated:** 2026-06-13

## Done

- [x] Task 1: PRECIPICE_SCAFFOLD — rokit.toml, wally.toml, default.project.json, .gitignore, directory tree
- [x] Task 2: PRECIPICE_DATA — data/gen/export_data.py, all 7 generated Data/ modules
- [x] Task 3: PRECIPICE_CORE — Remotes/Manifest, RemoteService, GameInit, Config/GameConfig, Config/EconomyConstants, Core/TimerMath, Core/RecipeResolver, Core/SeedResolver, Core/MarketMath, Core/PatentWindow, Core/RankMath, Core/OfflineIncome
- [x] Task 4: PRECIPICE_TESTS — tests/spec.luau, mocks/MockDataStore, mocks/MockClock, tests/run.luau, specs/DataIntegrity, specs/RemotesGuard, specs/OfflineIncome, specs/TimerMath
- [x] Task 5: PRECIPICE_DOCS — docs/00_INDEX through 06_WORKFLOW, all 24 service stubs, DataService.md, SlotService.md, ui/ stubs, data/ stubs, root CLAUDE.md
- [x] Task 6: PRECIPICE_CLOSE — 33/33 tests green, 0 selene errors, 0 stylua diffs, final commit
- [x] Task 7: PRECIPICE_PHASE1 — DataService (ProfileStore sessions, migrations, PendingCredits drain); 46/46 tests green
- [x] Task 8: PRECIPICE_PHASE2 — SeedService (salt read/generate/persist, SeedResolver wiring); SlotMachine (pure state machine, Lune-tested); SlotService (remotes, offline settle, heartbeat tick)

## In progress

None.

## Next

Phase 3: VaultService + LabService
- VaultService: inventory reads, residue, instant sell remote
- LabService: analysis flow, fees, discovery, residue, refusal rules
- Specs: docs/specs/VaultService.md, docs/specs/LabService.md

## Known issues

- `SeedResolver.getCurrentWeekNumber` may be off by one week in some edge cases (ISO week boundary formula). Seeds change at consistent intervals so gameplay is unaffected, but the computed week number may not match ISO 8601 exactly. Flag for audit in Phase 11.

## Open questions

None currently.

## Known blockers

- `lune`/`rokit` require PATH addition on Windows (IR-02): `$env:PATH += ";$env:USERPROFILE\.rokit\bin"`

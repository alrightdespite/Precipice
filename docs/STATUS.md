# Status

## Current phase: Phase 0 complete → Phase 1 next

**Last updated:** 2026-06-13

## Done

- [x] Task 1: PRECIPICE_SCAFFOLD — rokit.toml, wally.toml, default.project.json, .gitignore, directory tree
- [x] Task 2: PRECIPICE_DATA — data/gen/export_data.py, all 7 generated Data/ modules
- [x] Task 3: PRECIPICE_CORE — Remotes/Manifest, RemoteService, GameInit, Config/GameConfig, Config/EconomyConstants, Core/TimerMath, Core/RecipeResolver, Core/SeedResolver, Core/MarketMath, Core/PatentWindow, Core/RankMath, Core/OfflineIncome
- [x] Task 4: PRECIPICE_TESTS — tests/spec.luau, mocks/MockDataStore, mocks/MockClock, tests/run.luau, specs/DataIntegrity, specs/RemotesGuard, specs/OfflineIncome, specs/TimerMath
- [x] Task 5: PRECIPICE_DOCS — docs/00_INDEX through 06_WORKFLOW, all 24 service stubs, DataService.md, SlotService.md, ui/ stubs, data/ stubs, root CLAUDE.md
- [x] Task 6: PRECIPICE_CLOSE — 33/33 tests green, 0 selene errors, 0 stylua diffs, final commit

## In progress

None.

## Next

Phase 2: SlotService + SeedService
- SeedService: read salt from DataStore, call SeedResolver.setSalt(), expose getCurrentWeekSeed()
- SlotService: slot state machine, offline income settlement on join
- Spec: docs/specs/SlotService.md, docs/specs/SeedService.md

## Open questions

None currently.

## Known blockers

- `lune`/`rokit` require PATH addition on Windows (IR-02): `$env:PATH += ";$env:USERPROFILE\.rokit\bin"`

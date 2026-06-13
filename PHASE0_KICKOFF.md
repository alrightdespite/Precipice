# PHASE 0 KICKOFF — copy-paste this entire file into a fresh Claude Code session

> **For Guy:** Start Claude Code in an empty folder (suggested: `D:\RobloxProjects\PrecipiceV2`). Put the three artifacts — `PRECIPICE_GAME_DESIGN_v4_6.md`, `PRECIPICE_ECONOMY_MODEL.xlsx`, `PRECIPICE_COMPOUND_DATABASE.xlsx` — and `PRECIPICE_IMPLEMENTATION_PLAN_v3.md` into that folder first. Then paste everything below the line.

---

You are building Phase 0 of PRECIPICE, a Roblox idle chemistry tycoon, from scratch. The authoritative inputs are in this folder: `PRECIPICE_GAME_DESIGN_v4_6.md` (the design source of truth), `PRECIPICE_ECONOMY_MODEL.xlsx` and `PRECIPICE_COMPOUND_DATABASE.xlsx` (the data sources of truth), and `PRECIPICE_IMPLEMENTATION_PLAN_v3.md` (the architecture you must follow — read its Parts III and IV in full before writing anything).

Phase 0 produces a working repo skeleton, the data pipeline, and the docs system. No gameplay code yet. Work through these tasks in order, commit after each numbered task with the message given.

## Task 1 — Repo + toolchain (`chore: scaffold repo and toolchain`)
- `git init`. Create the layout from Plan III.4 exactly: `default.project.json`, `rokit.toml`, `wally.toml`, `stylua.toml`, `selene.toml`, `.gitignore` (ignore `/Packages`, `*.rbxl`, `/build`), and the `src/shared`, `src/server`, `src/client`, `tests`, `docs`, `data`, `map` trees.
- `rokit.toml`: pin rojo, wally, lune, stylua, selene (latest stable each — check with `rokit add`).
- `wally.toml`: ProfileStore, Promise, Signal, t. Run `wally install`.
- `default.project.json`: one-way Rojo mapping per Plan III.4. **Never configure two-way sync.**

## Task 2 — Data pipeline (`feat: data export pipeline with structural assertions`)
- Move the two `.xlsx` files into `data/`.
- Write `data/gen/export_data.py` (Python, openpyxl): reads both workbooks and emits `src/shared/Data/Compounds.luau`, `Recipes.luau`, `Exotics.luau`, `EventCompounds.luau`, `TierConstants.luau`, `EconomyParams.luau`, `ContractPool.luau` — plain Luau module tables, header comment `-- GENERATED FILE — never hand-edit; run data/gen/export_data.py`.
- The script re-runs the structural assertions before writing, and aborts on any failure: 150 compounds (30/30/30/25/20/15 by tier), 205 recipes (25/40/50/45/30/15), full BFS reachability from the 5 starters, every pair ≤2 mappings with exactly 17 doubles, tier legality per doc §11's pairing rules (read them from the doc, don't assume a formula), 120 unique Exotics, all 24 contracts inside doc §19 reward bands.
- Run it. Commit the generated files.

## Task 3 — Remotes manifest + Core skeleton (`feat: remotes manifest and pure-core skeleton`)
- `src/shared/Remotes/Manifest.luau`: the declarative list of every RemoteEvent/RemoteFunction with direction and payload type comment. Seed it from Plan III's service inventory (it will grow per-phase). Write `src/server/Services/RemoteService.luau`: at boot, creates every remote in the manifest under `ReplicatedStorage/Remotes`, errors on duplicates. **No remote may ever exist as an authored instance (design doc E13).**
- `src/shared/Core/`: empty modules with header contracts only — `TimerMath.luau`, `RecipeResolver.luau`, `SeedResolver.luau`, `MarketMath.luau`, `PatentWindow.luau`, `RankMath.luau`, `OfflineIncome.luau`. Each header states: pure module, no Roblox globals, clock injected, Lune-testable.
- `src/server/GameInit.server.luau`: boot order stub per Plan IV H9 (Config → Data → RemoteService → DataService → ClockService → services → PlayerAdded last).

- **Seed salt:** generate a random salt string on first server boot and store it in a DataStore key `Config/SeedSalt`. Never hardcode it in source. `SeedResolver.luau` reads it once at boot via DataService; the salt is never sent to the client.

## Task 4 — Test harness (`feat: lune test harness with CI guards`)
- `tests/run.luau` (entry for `lune run tests/run`), a tiny spec helper, `tests/mocks/MockDataStore.luau` and `MockClock.luau`.
- Two CI guard tests per Plan IV H9: (a) regenerate data via the export script and fail if `src/shared/Data` differs from a fresh export; (b) fail if any Instance of class RemoteEvent/RemoteFunction exists in `src/` as a file-authored instance.
- One real test: load `Compounds.luau` + `Recipes.luau` and re-run BFS reachability in Luau. All green before commit.

## Task 5 — PRECIPICE_DOCS (`docs: implementation docs system v1`)
Build `docs/` per Plan III.5: `00_INDEX.md`, `01_ARCHITECTURE.md` (condense Plan Part III), `02_DATA_SCHEMA.md` (profile shape + `schemaVersion` per H8, global record shapes), `03_REMOTES.md` (generated summary of the manifest), `04_RULINGS.md` (pointer to design doc Parts E–F + empty future-delta log), `05_TESTING.md`, `06_WORKFLOW.md` (the session protocol from Plan III.6), `STATUS.md` (initialized: Phase 0 complete, Phase 1 next, no known blockers).
- `docs/specs/`: create the 24 service spec files as stubs with their one-paragraph mission from Plan III.3 each; **fully write only `DataService.md` and `SlotService.md`** (Phase 1 needs them): include the H1/H2 patterns verbatim from Plan IV where relevant, the E1 work-units model for SlotService, and acceptance tests (§10's 5,437-Pellet example is a mandatory unit test).
- `docs/data/CONTRACT_POOL.md`: transcribe the economy model's Contract_Pool sheet. `docs/data/WORLD_MODEL.md`: transcribe design doc §31.
- Root `CLAUDE.md`, ≤150 lines, router only: repo map, the five iron rules (read STATUS + spec before coding; one task per session; tests green before done; update STATUS + commit at end; never hand-edit generated files or author remote instances), boot order, and pointers into `docs/`.

## Task 6 — Close out (`chore: phase 0 complete`)
- `lune run tests/run` green, `selene src` and `stylua --check src` clean.
- Update `STATUS.md`. Final commit. Print a summary of the tree and anything you had to deviate on.

Rules for this session: follow `PRECIPICE_IMPLEMENTATION_PLAN_v3.md` over your own preferences; where the plan and the design doc conflict, the design doc wins and you note the conflict in `docs/04_RULINGS.md`; ask nothing — make the call, document it, move on.

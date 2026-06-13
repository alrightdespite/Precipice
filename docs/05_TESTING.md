# Testing

## Running tests

```
# Windows: add rokit bin to PATH first
$env:PATH += ";$env:USERPROFILE\.rokit\bin"
lune run tests/run
```

All tests must be green before any commit that touches `src/`.

## Test structure

```
tests/
├─ run.luau          # entry point: lune run tests/run
├─ spec.luau         # minimal describe/it/expect runner
├─ mocks/
│  ├─ MockDataStore.luau   # in-memory UpdateAsync/GetAsync/SetAsync
│  └─ MockClock.luau       # injectable clock (advance/set/now)
└─ specs/
   ├─ DataIntegrity.luau   # CI guard: counts, BFS, pair uniqueness (33 tests)
   ├─ RemotesGuard.luau    # CI guard: no authored remote instances outside RemoteService
   ├─ OfflineIncome.luau   # §10 worked example + floor + cap
   └─ TimerMath.luau       # work-unit settle, completion
```

## CI guards (H9)

Two guards that must pass before any Phase 1+ work:

1. **DataIntegrity**: loads `src/shared/Data/*.luau` directly and re-runs all structural assertions in Luau — same checks as the Python exporter. Catches hand-edits and stale exports.

2. **RemotesGuard**: scans `src/` for `Instance.new("RemoteEvent")` / `Instance.new("RemoteFunction")` in any file other than `RemoteService.luau`. Enforces E13.

## Doc examples as mandatory tests

Per Plan I.1, these design doc worked examples MUST exist as literal unit tests:

| Doc reference | Test file | Status |
|---|---|---|
| §10 offline income: 40+1971+2826+600 = 5437 | `specs/OfflineIncome.luau` | ✓ Phase 0 |
| §11 fee/residue tables | `specs/LabService.luau` | Phase 2 |
| §15 defense windows (T2–T7) | `specs/PatentService.luau` | Phase 4 |
| §15 multi-party race (holder/challenger/third) | `specs/PatentService.luau` | Phase 4 |
| Exotic decay floor: 0.97^46 < 0.25 (floor at unit 46) | `specs/ExoticService.luau` | Phase 5 |
| Fee tables (joint analysis 500, prestige 40% off) | `specs/LabService.luau` | Phase 2 |
| §11 button-state table (all 4 rows) | `specs/LabService.luau` | Phase 2 |

## Adding tests

1. Create `tests/specs/MySpec.luau`
2. `require("../spec")` and register suites
3. Add `require("specs/MySpec")` to `tests/run.luau`
4. Run; confirm green

Core modules must have a spec before being shipped. Services get integration tests in Studio; Lune tests are for Core only.

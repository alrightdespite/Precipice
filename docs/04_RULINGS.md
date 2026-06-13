# Rulings

Design doc rulings E1–E13 and F1–F2 live in `data/PRECIPICE_GAME_DESIGN_v4_6.md` Parts E and F. This file is the **delta log** for implementation decisions that go beyond or diverge from the design doc.

## R1–R13 (adopted in design doc v4.5/v4.6)

See design doc Parts E and F. All 13 rulings are implemented verbatim. No conflicts.

---

## Implementation rulings (Phase 0)

### IR-01 — OfflineIncome uses math.round, not math.floor

**Rule:** `OfflineIncome.settle` uses `math.round` per slot-total, not `math.floor`.

**Why:** The passive income rates (8, 11.2, 15.7, 21.9, 30.7, 43.0, 60.0 P/min) are designed to produce integer Pellet payouts at their standard run durations. `21.9 × 90 = 1971` mathematically but `21.9 × 90 = 1970.9999...` in IEEE-754 binary float; `math.floor` gives 1970. The design doc's §10 worked example (total = 5437) only passes with round. The income rates are authoritative (workbook-verified); the rounding behavior must match them.

**How to apply:** All passive income Pellet computations use `math.round`. The floor rate (2 P/min) is an integer and uses either; convention is `math.round` for consistency.

---

### IR-02 — rokit not pre-installed on build machine

**Rule:** `lune` is installed via rokit. Session protocol requires adding `$env:USERPROFILE\.rokit\bin` to PATH before running `lune run tests/run` on Windows.

**Why:** rokit is not in the system PATH at shell startup; it installs into `~/.rokit/bin`. Add to PATH or run via `rokit run lune`.

**How to apply:** CLAUDE.md documents the PATH addition. CI scripts will need the same. Deferred to Phase 11.

---

### IR-03 — wally packages not installed (Phase 0)

**Rule:** `wally install` has not been run. `Packages/` does not exist. No service code uses Wally packages in Phase 0.

**Why:** Wally binary not yet in PATH via rokit (same issue as IR-02). Packages are needed starting Phase 1 (ProfileStore for DataService). Install step deferred.

**How to apply:** Run `rokit run wally install` before beginning Phase 1.

---

## Conflicts with design doc (none in Phase 0)

No design doc rule has been violated or overridden. All rulings above are engineering decisions below the design layer.

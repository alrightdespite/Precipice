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

## Conflicts with design doc

### IR-DIV-01 — Central Hub added (diverges from §31 "no shared room")

**Status:** Owner-directed override (2026-06-23). The owner explicitly chose to add a central
hub against the design doc's recommendation; recorded here per the delta-log contract.

**Design says (§31, *Why plots, and not the alternatives*):** the world is per-plot with **no
shared room** — "A single shared room makes simultaneous reveals collide and gives the player
nothing that is theirs… Plots are the cheapest model in which the reveal moment happens in a
world the player owns while other people visibly exist." §31 also rejects full private
instancing (teleport plumbing for zero gain).

**What was built instead:** a static **Central Operations hub** (`workspace.Hub`, ~286 parts) on a
shared **grass campus** (`workspace.WorldGround` — one 3000×1050 grass slab + `Landscape` folder of
~63 trees / 14 rocks), placed south of and centered on the 8-plot tiling row (mid-X ≈ 1145, derived
from `PlotService` stride 326×474). Contents: a 118-stud landmark **beacon tower** (teal energy
bands), a two-storey **Ops-building** backdrop with roof detail (RTUs, vents, antenna mast + red
beacon, railing, downpipes) and a `CENTRAL OPERATIONS` sign, **twin global-ranking boards**
(`Leaderboard_W` = TOP RESEARCHERS, `Leaderboard_E` = TOP SYNDICATES — SurfaceGuis, **not yet
wired**, a future LeaderboardService surface), an E-W **avenue** along the plot-row south edge, an
**entry arch**, a flag-lined central **walkway** with a `PRECIPICE` ground emblem, hedges, lamp
posts, bollards, **service vehicles** (box truck + forklift) on a marked service bay, and perimeter
treeline. Reuses the world's teal/concrete/steel palette + the existing Lighting post-FX (Atmosphere
/ Bloom). It is **not** inside `workspace.Plots`, so `PlotService` does **not** clone it — one shared
instance per server, sitting under the tiled plots which keep their own grass lots on top.

**Why the override is low-risk as built:** the hub does **not** change spawn routing, reveals,
or any economic/social system — those stay per-plot and cross-server exactly as designed. The
reveal-collision concern in §31 does not apply because reveals still happen at each player's own
chamber, never in the hub. Plots remain **sealed** (owner's call) — the hub is a visible
landmark/backdrop, not a walk-connected destination, so no inter-plot teleport/fence plumbing was
added. If "visible and walkable" (§31) is later desired, opening each plot's south perimeter +
aligning the avenue is the follow-up.

**Map-only:** the hub lives in the Studio place (gitignored, Workspace is Studio-only by design,
iron rule #5). It is **not** in `src/` and cannot be committed — it persists only via the user's
Ctrl+S. This ruling is the source-controlled record that it exists.

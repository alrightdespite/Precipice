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

**Plots now ring the hub (source-controlled).** `PlotService` was changed (commit `0124d29`) from a
single east-west row to **two facing rows of four** straddling the hub: row 0 north and row 1 south
of `HUB_CENTER = (1145, 0, 40)`, `ROW_GAP_STUDS = 560` from centre, the south row flipped 180° so
both rows face the hub. Placement is now **absolute** (`PivotTo` a computed CFrame) rather than
template-relative, so the unused `PLOT_TEMPLATE` no longer anchors spacing and is parked off-stage
(~(8000, 8000)) in the Studio place. `HUB_CENTER` in code **must stay in sync** with the Studio-built
hub geometry — they are the contract between the committed layout and the gitignored map.

**What was built (map) — the Civic Plaza.** Rebuilt clean from scratch (2026-06): a circular
**Civic Plaza** (`workspace.Hub`, ~2.3k parts) centred on the ring, themed as a real corporate
research campus — warm stone / charcoal / bronze / glass / greenery, with the brand **teal used only
on the central molecule** sculpture. Layout (all symmetric about `HUB_CENTER`):
- **Central molecule monument** — tiered stone base + reflecting pool + bronze-banded pillar, crowned
  by the game's icon, a glowing teal **molecule** (the single teal accent), with a bronze halo + warm
  uplights.
- **Four feature pavilions** (`Pavilions/`) facing centre — stone colonnade + roof + board, one each
  for **Hall of Fame** (world-first patents, §15, display-only), **Leaderboards** (Researchers +
  Syndicates), **Shop** (gamepass/cosmetics — its only in-world presence; the 5 plot stations don't
  include Shop), and **Events** (Cascade Protocol). The latter three carry a `Screen` attribute + a
  `Prompt`, wired by `StationController.bindHubPavilions()` (commit `e152d62`).
- **N/S gateways** over the boulevard carrying an **announcement marquee**; a continuous **seat-wall
  ring** with cardinal openings; **benches, lamp posts**; four manicured **garden parterres**.
- **Roads** (`Roads/`) — a single symmetric network: N–S **boulevard** + an E–W **cross street** at
  each plot row's front, with sidewalks, dashes, and formal **tree allées**; identical N and S so both
  rows connect to the plaza the same way.
- **Terrain** (`WorldGround/`) — one clean grass slab (default Baseplate removed) framed by a
  deliberate rectangular **perimeter treeline**; ~180 trees total, placed in formal rows not scatter.

It is **not** inside `workspace.Plots`, so `PlotService` does **not** clone it — one shared instance
per server, with the eight plot clones tiling at the ends of the two cross streets.

**Why the override is low-risk as built:** the hub does **not** change spawn routing, reveals,
or any economic/social system — those stay per-plot and cross-server exactly as designed. The
reveal-collision concern in §31 does not apply because reveals still happen at each player's own
chamber, never in the hub. Plots remain **sealed** (owner's call) — the hub is a visible
landmark/backdrop, not a walk-connected destination, so no inter-plot teleport/fence plumbing was
added. If "visible and walkable" (§31) is later desired, opening each plot's south perimeter +
aligning the avenue is the follow-up.

**What is / isn't source-controlled:** the **plot-ring placement logic** lives in
`PlotService.luau` (committed). The **hub geometry + campus** live only in the Studio place
(gitignored, Workspace is Studio-only by design, iron rule #5) and persist only via the user's
Ctrl+S. The two are coupled through `HUB_CENTER` / `ROW_GAP_STUDS`: if the hub is moved in Studio,
update those constants (and vice-versa). This ruling is the source-controlled record of the whole
arrangement.

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

> **CURRENT STATE NOTE (Session 9, 2026-06-29) — read this first; it supersedes details below.**
> The world is a **floating circular island** (`workspace.WorldGround.Island`: grass disc R870 +
> tapered rock underbelly to ~Y−388 + stalactites, in open sky with `Terrain` Clouds). The old square
> `GroundSlab`, square `Perimeter`, Terrain hills/water, and distant islands were **removed** (the now-
> empty `WorldGround.Perimeter` folder was deleted Session 9).
> **`PLOT_RING_RADIUS = 545`** (Session 9, was 580) — plots pulled in a bit; front sits at radius−205 =
> **340**, abutting the octagon ring road. The Studio **ring road + lab gateways + lamp posts were
> pulled inward 35** to match, and the **8 spoke roads were rebuilt** as one clean straight road each
> (plaza → plot, through the gateway) — the old dead-end Y-fork dashes were removed.
> Plaza floor = **Concrete** with readable concentric medallion rings (Session 9); pavilions at r137;
> element pylons + festoon (hanging string-lights) at r188; monument on a 3-tier podium.
> **8 plot markers** (`workspace.WorldGround.PlotMarkers/PlotMarker_0..7`) — Session 9 rebuilt to
> **190×190** cyan "surveyed blueprint" squares matching the plot's **fenced buildable area** (not the
> full 262×410 pad), positioned at the fence location (local centre slot+75 outward); `PlotService`
> hides each while its slot is occupied.
> **`PLOT_TEMPLATE` (load-bearing contract):** `PrimaryPart = PlotBounds` so `PivotTo` centres the plot
> on its concrete (else the lopsided bbox skews placement ~67 studs). `PlotBounds` is now the **visible
> concrete floor** (262×4×410 Concrete, top Y4); the old `Exterior.Grass` lawn was **removed** (it
> z-fought the equipment pads).
> **Trees** = 33 rebuilt Session 9 as real trees (tapered trunk + branches + roots + species canopy:
> oak/pine/blossom/maple/birch) using mixed shapes, on raycast-found ground in gardens + island-edge ring.
> **Intentionally deleted (owner cleanup):** element spires, holo kiosks, energy beams/atmosphere,
> monument halo+jets, entry banners, most flags. The map was once accidentally flattened by a Studio
> Ungroup and rebuilt programmatically. The hub geometry remains Studio-only (Ctrl+S), with
> `HUB_CENTER (1145,0,40)` / `PLOT_RING_RADIUS 545` the code↔map contract. Sections below are the
> historical build record and are partly out of date.

**Design says (§31, *Why plots, and not the alternatives*):** the world is per-plot with **no
shared room** — "A single shared room makes simultaneous reveals collide and gives the player
nothing that is theirs… Plots are the cheapest model in which the reveal moment happens in a
world the player owns while other people visibly exist." §31 also rejects full private
instancing (teleport plumbing for zero gain).

**Plots ring the hub in a regular octagon (source-controlled).** `PlotService` places the eight plots
evenly on a circle of `PLOT_RING_RADIUS = 580` around `HUB_CENTER = (1145, 0, 40)`, each turned via
`CFrame.lookAt` so its −Z entrance faces the hub — so **every player is the same distance from the
hub** (the most uniform equal-distance formation for the 262×410 lot). The radius was **shortened
620 → 580** (Session 7) to bring the plots in: front sits at radius−205 = **375**, just outside the
hub's octagon **ring road (vertices at ~370)**, so the 262-wide fronts still clear (front
circumference 2π·375 ≈ 2356, /8 = 294 > 262). Placement is **absolute**, so the unused `PLOT_TEMPLATE`
no longer anchors spacing and is parked off-stage (~(8000, 8000)). `HUB_CENTER` / `PLOT_RING_RADIUS`
in code **must stay in sync** with the Studio-built hub geometry — the ring road + lab gateways were
rebuilt to the 580/370 layout.

**What was built (map) — the Civic Plaza.** Rebuilt clean from scratch (2026-06): a circular
**Civic Plaza** (`workspace.Hub`, ~4.7k parts) centred on the ring, themed as a real corporate
research campus — warm stone / charcoal / bronze / glass / greenery, with the brand **teal used only
on the central molecule** sculpture. Layout (all symmetric about `HUB_CENTER`):
- **Central molecule monument** — tiered stone base + reflecting pool (water jets) + bronze-banded
  fluted pillar, crowned by the game's icon, a glowing teal **molecule** that **emits energy
  particles** (ParticleEmitters; jets emit mist), bronze halo + warm uplights.
- **Ring of 8 "element pylons"** (`ElementPylons/`) between the monument and pavilions — each a stone
  pylon topped with a small glowing **mini-molecule** in a distinct jewel tone (teal/amber/emerald/
  sapphire/amethyst/ruby/aqua/topaz), lit + particle-emitting. The plaza's main "exciting" feature.
- **Four feature pavilions** (`Pavilions/`) facing centre — open-front stone colonnade + roof +
  readable per-line board, one each for **Hall of Fame** (world-first patents, §15, display-only),
  **Leaderboards** (Researchers + Syndicates), **Shop** (gamepass/cosmetics — its only in-world
  presence; the 5 plot stations don't include Shop), and **Events** (Cascade Protocol). The latter
  three carry a `Screen` attribute + a `Prompt`, wired by `StationController.bindHubPavilions()`
  (commit `e152d62`).
- **8 entry arches** (`Entries/`) at the plaza openings with **colour-matched hanging banners** + an
  announcement marquee theme; **festoon string-lights** (`Festoon/`) between the pylons; a continuous
  **seat-wall ring** with 8 spoke openings; **benches + lamp posts**.
- **Roads** (`Roads/`) — a **hub-and-spoke** network replicating the **plot road system exactly**:
  asphalt `(42,42,46)`, dashes `0.6×0.12×4` `(224,182,32)`, curbs `0.6×0.6` `(120,120,124)`, and the
  plot's **22-stud road lamps** (pole + arm + warm neon lamp + light). Eight **spokes** from the plaza
  to an **octagon ring road** whose vertices sit at the plot fronts. Plaza **R230** with 8 openings.
- **Terrain + landscaping** (`WorldGround/`) — one clean grass slab (plot grass colour, Baseplate
  removed); **detailed trees** of three types — **oak** (root flare, branches with tip-foliage, full
  layered crown + highlights), **conifer** (tapered tiered cone), **blossom** (pink/white) — placed in
  formal spoke allées + spaced clusters; eight hedge-bordered **garden wedges**; perimeter ring.
  Floor z-fighting audited programmatically → **0 coplanar pairs**.

Board text uses per-line rows (title + spaced body lines, capped `UITextSizeConstraint`) and the
pavilions have an **open-front colonnade** so the boards read cleanly.

It is **not** inside `workspace.Plots`, so `PlotService` does **not** clone it — one shared instance
per server, with the eight plot clones tiling at the ends of the two cross streets.

**Why the override is low-risk as built:** the hub does **not** change spawn routing, reveals,
or any economic/social system — those stay per-plot and cross-server exactly as designed. The
reveal-collision concern in §31 does not apply because reveals still happen at each player's own
chamber, never in the hub. Plots remain **sealed** (owner's call) — the hub is a visible
landmark/backdrop, not a walk-connected destination, so no inter-plot teleport/fence plumbing was
added. If "visible and walkable" (§31) is later desired, opening each plot's south perimeter +
aligning the avenue is the follow-up.

**Session 7 campus build-out (map; Studio-only).** The plaza was developed into a coherent
**"the plaza is an atom"** design where every element carries meaning:
- **Atomic floor medallion** (`Hub.PlazaInlay`) — bronze nucleus ring + 8 **bond-lines** from the
  monument (nucleus) to the 8 pylons, each pylon standing on a **district coin** in its element's hue.
- **Element identity** — the 8 pylons/coins/gardens are branded as the 8 **Elements** (C, S, Cl, Co,
  I, Li, Cu, Na — all real compounds in `Compounds.luau`), color-matched (e.g. cobalt = blue).
- **Pavilion forecourts + grandeur** (`Hub.Forecourts`, per-pavilion `Grandeur` model) — apron +
  bronze threshold + bollard-lights + planters + a function-colored banner, plus a stone **attic +
  crown lantern + name cartouche** so each civic function reads as a landmark. **Board/Prompt wiring
  untouched** (`StationController.bindHubPavilions` still works).
- **Element gardens** (`WorldGround.GardenWedges.ElementMarkers` + `GardenDetail`) — named plaque
  plinth + glowing specimen + bench + hedge arc per wedge; blooms tinted to the element.
- **Lab gateways** (`Hub.LabGateways`) — flanking pylons + lintel + "LABORATORIES" wayfinding at each
  spoke head, pointing to the player plots.
- **Element avenues** (`Hub.ElementAvenues`) — each spoke is lined with its element's colored
  pennants (spoke angle = pylon angle), so the walk out to a lab travels that element's avenue.
- **Commons** (`Hub.Commons`) — element-tinted topiary planters in the plaza ring + bold **PRECIPICE**
  institute flag pairs at the 4 cardinal exit-spokes.
- **World-edge frame** (`WorldGround.Perimeter`) — grass berms + retaining curbs + a clustered
  tree-line along the slab edge, hiding the void so the world reads finished from ground level.
- **Ring road rebuilt** to the 580/370 layout (vertices r370, spokes plaza→r358), with **junction
  node pads** at the 8 octagon vertices that cap the corner seam (the old `RingEdge` coplanar note).
  Floor z-fighting on new floor plates audited → **0**; road-corner overlaps are hidden under pads.
- **Verticality / depth pass** (the map had read too flat): **8 element-crystal spires**
  (`Hub.ElementSpires`, ~63 tall, at r330 on the vertex/element angles — Carbon's is a diamond);
  the monument lifted **+11 onto a 3-tier stepped podium** (`Hub.MonumentPodium`, you ascend to the
  nucleus; medallion bonds rebuilt podium→coins); and a **backdrop of smooth Terrain hills**
  (`workspace.Terrain`, rolling green/rock ridges beyond the slab across the water — campus-on-a-
  peninsula). New plaza-floor plates re-audited → 0 coplanar.
- **Pro-polish pass** (`Hub.Atmosphere`, `Hub.HoloKiosks`): glowing **energy Beams** from the nucleus
  molecule out to each element-crystal spire ("the nucleus powers the 8 Elements", element-colored);
  ambient **atmosphere motes** (ParticleEmitters) drifting across the plaza; and 4 **holographic info
  kiosks** at the cardinal entries — glowing "FEATURED COMPOUND" data screens (real compounds: NaCl /
  CuSO4 / CoCl2 / KI with demand stats) + a floating molecule hologram. High-tech research-lab read.

**What is / isn't source-controlled:** the **plot-ring placement logic** lives in
`PlotService.luau` (committed). The **hub geometry + campus** live only in the Studio place
(gitignored, Workspace is Studio-only by design, iron rule #5) and persist only via the user's
Ctrl+S. The two are coupled through `HUB_CENTER` / `ROW_GAP_STUDS`: if the hub is moved in Studio,
update those constants (and vice-versa). This ruling is the source-controlled record of the whole
arrangement.

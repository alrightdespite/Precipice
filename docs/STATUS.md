# Status

## Current phase: Phase B (full UI restyle) DONE. Phase A + Phase 14 backend complete.

**Last updated:** 2026-06-30 (Session 10 — open follow-ups cleared + map polish)

> **Session 10 summary (CODE + MAP).** Cleared the three open follow-ups:
> - **`Hub.LabGateways`** empty leftover folder **deleted** (Edit mode).
> - **`ShopScreen`** HUD built (`src/client/UI/ShopScreen.luau`, registered as `Shop` in `UIController`):
>   Phase B styling, two tabs — **Boosts** (dev products: Timer Skip / Rush ×3 / Catalyst Pack / Crate)
>   and **Passes** (Expanded Lab / Extended Offline / Compound Archive / Event Pass, with Owned badge).
>   Buy pills call `MarketplaceService:Prompt{Product,GamePass}Purchase`; IDs read from `GameConfig`
>   (still placeholder `0` → warn-no-op until real Robux IDs ship). The hub Shop prompt now opens it.
> - **Hub info boards wired** (`src/client/Controllers/HubBoardController.luau`, init in `ClientInit`,
>   bound at PlayerReady): the **Leaderboards** pavilion board shows the weekly **Sprint** top-5, the
>   **Hall of Fame** board shows the all-time **Chief's Board** top-5, via `LeaderboardController`.
>   Controller owns the `Board` SurfaceGui (rebuilds it live; map only needs a `Board` part + SurfaceGui),
>   names resolved via `GetNameFromUserIdAsync`, polled ~60s staggered to respect the 1-req/2s rate limit.
>   Verified live in Play: Hall of Fame rendered `#1 … 6.0M`; Sprint showed "No entries yet".
> - 525 tests green, selene 0/0. **Known latent bug (separate):** `LeaderboardScreen` requests board
>   `"chief"` but `LeaderboardService` only accepts `"chiefs"` → the screen's Chief tab returns empty.
> - **MAP polish pass** (Studio-only, Ctrl+S to persist): per-prop organic **yaw + small XZ jitter**
>   on the 33 trees + Decor rock/boulder/shrub (idempotent via a `polishV10` attribute) to break the
>   mirrored-clone look. Base Y preserved (yaw is vertical-axis + horizontal nudge only). The deliberate
>   8-fold beds/hedges/gardens/markers/plaza/roads were left untouched.
>
> **Session 10 cont. — "perfect map" pass (8 ideas approved). CODE (committed) + MAP (Ctrl+S).**
> CODE foundations (`feat(world)`): `ElementMeta.luau` (8 elements C,S,Cl,Co,I,Li,Cu,Na — symbol/atomic#/
> name/colour, single source of truth); `SoundController.luau` (Music+SFX SoundGroups, one-shot SFX
> catalog + music loop; wires the previously-dead Settings Music/SFX toggles; UI SFX hooks in
> UIController/Components.Button/ShopScreen — **audio asset ids are placeholder `0`, every call no-ops
> until real ids are approved**); `TickerController.luau` (in-world news marquee fed by
> `StateController.announcements`, renders onto a `TickerBoard` SurfaceGui); `WorldDressController.luau`
> (element plaques from ElementMeta via `ElementIndex` attr; flask `Reagent` tints to live Flux season +
> pulses on world-first; 3 Hall-of-Fame plinths from the cached Chief's Board, refilled on
> `patch.leaderboard`). All binders no-op when their map parts are absent. selene 0/0, 525 tests green;
> verified live (ticker scrolls; Plinth1 = `alrightdespite / 6.0M`; garden symbols tinted; no errors).
> MAP (Studio, **press Ctrl+S**): 8 element-garden markers upgraded to periodic-tile look (atomic number
> added, labels renamed to Symbol/ElementName/AtomicNumber, symbol tinted, `ElementIndex` 1–8 set);
> 3 HoF podium plinths (gold/silver/bronze) in front of the HallOfFame pavilion; off-spoke **ticker
> ribbon** (`Hub.Ticker.TickerBoard`) at ang 112.5°; **glass parapet** ring at R858 (144 parts,
> `Hub`→`WorldGround.EdgeRail`) + **overlook deck + telescope** at ang −90° (`WorldGround.Overlook`);
> flask material pass (Body/Shoulder/Neck→Glass, brass bands→Metal, Reagent/Bubbles→Neon, Cork→Wood).
> `StreamingEnabled` already on. **Pending:** audio asset ids for `SoundController`/env Sounds (B1).

> **Session 9 summary (MAP polish + one CODE change. Supersedes Session 8 plot/road/tree details.)**
> Map is still **gitignored / Studio-only** (persists only via Ctrl+S). Changes:
> - **Owner manual cleanup (Studio, latest — current truth):** grouped the lamp posts into a
>   `Hub.Roads.RoadLamps` Model; **deleted `Hub.Monument.Branding`** (the PRECIPICE / CHEMISTRY TYCOON
>   plaques are gone); **simplified the centerpiece bottle** (`Hub.Monument.Flask` — removed the
>   labels/hanging-tag/graduation/meniscus/highlight/core detail → clean glass body + teal reagent +
>   bubbles + brass bands/collar/lip/cork); removed the island stalactites (kept the 9 stacked-slate-disc
>   underbelly); removed the thin flower **stems** from the decor beds (blooms kept); trimmed
>   `Hub.Forecourts`. Verified clean: **0 unanchored, 0 loose parts at root, markers 8/8 keep
>   `HoloSign`+`SurfaceGui`, `PLOT_TEMPLATE.PrimaryPart = PlotBounds`**. (`Hub.LabGateways` is an empty
>   leftover folder — delete it in Edit mode.)
> - **CODE:** `PlotService.PLOT_RING_RADIUS` **580 → 510** (plots pulled in close to the plaza; 510 is
>   below the no-overlap floor so the 262-wide concrete *pads* touch at front corners, but that is thin
>   same-colour floor and the 190-wide facilities stay clear). 525 tests green, selene 0/0.
> - **`PLOT_TEMPLATE` (map):** set **`PrimaryPart = PlotBounds`** — fixes a ~67-stud placement skew so
>   plots spawn centred on their marker. Removed the glitching `Exterior.Grass`; `PlotBounds` is now the
>   **visible concrete floor** (262×4×410, top Y4).
> - **Plot markers (map):** rebuilt to **190×190** cyan blueprint squares = the plot's **fenced
>   buildable area** (was the full 262×410 pad), at the fence location; cyan grid + white frame + posts.
> - **Roads (map):** **removed the LABORATORIES lab gateways + the octagon ring road + all the messy
>   overlapping curbs and dead-end Y-fork dashes.** Rebuilt as **8 clean straight radial roads**
>   (plaza edge r232 → plot), asphalt + centre dashes. Junctions are clean.
> - **Signs (map):** all pavilion-board / nameplate / marker `SurfaceGui`s set **`LightInfluence=0`**
>   (full-bright, readable in any lighting) + non-ASCII tofu glyphs stripped from labels.
> - **Terrain/decor (map):** new `WorldGround.Decor` folder — ~105 scattered clusters (rock piles,
>   boulders, shrubs, flower beds, grass tufts) across the empty grass, avoiding roads/plots/gardens.
> - **Lighting/atmosphere (Studio-only, `Lighting`):** Future tech, ClockTime 14.6, Brightness 2.2,
>   warm ambient; added `Atmosphere` (density .27/haze 1.1), `BloomEffect`, `SunRaysEffect`,
>   `ColorCorrectionEffect` (sat +.22/contrast +.12/warm tint), `Sky`. Big appeal jump.
> - **Branding/centerpiece (map):** 4 "PRECIPICE / CHEMISTRY TYCOON" standing signs around the monument
>   (`Hub.Monument.Branding`, full-bright); fountain `PoolWater` recoloured vivid blue.
> - **"Human-made" premium pass (CODE + map):** display font switched **Fredoka One → Oswald**
>   (condensed editorial; Fredoka reads "AI") in `src/client/UI/Theme.luau` (Display/Header/HeaderBold;
>   body stays BuilderSans) — single choke-point restyles all UI; map sign titles re-swept to Oswald
>   FontFace (40 titles / 29 BuilderSans body, 0 stale). 525 tests green, selene 0/0.
>   - **Centerpiece reimagined (map):** the molecule-on-pillar is now a crafted **glass lab flask** with
>     glowing teal reagent (translucent-neon sphere + meniscus + bubbles), brass cradle/neck/cork, and a
>     small orbiting-atom nod, on the kept fluted column + podium; pool recoloured teal.
>     (`Hub.Monument.Flask`; old `CoreAtom`/`Sat`/`Bond` removed.)
>   - **Plot signs reimagined (map):** flat floating boards → crafted **wooden signposts** (timber posts +
>     framed hanging board + brass caps/brackets). Kept `HoloSign` + `SurfaceGui` so
>     `PlotService.setMarkerVisible` still hides/shows them. 8/8 verified.
>   - Materials were already crafted (Concrete/Metal/WoodPlanks) — kept the cohesion pass light (no
>     forced material sweep) per "don't overdo".
>   - **Cleanup pass (map):** centerpiece rebuilt again into a proper **detailed bottle** (glass body +
>     teal reagent + meniscus/bubbles, brass foot/collar/lip, glass neck, cork, parchment label) — the
>     orbiting-atom version was scrapped. **Trees** given a clean **flared base** (scattered wedge "roots"
>     removed) + reseated flush to ground everywhere (fixed the floating-tree look). **Gardens** fixed:
>     hedge borders rebuilt aligned to each lawn + the planter tree centered on its lawn. Pavilion boards
>     + brand plates set translucent (tr 0.35) to match the marker signs. Float/glitch sweep: 0 real
>     floaters (0 unanchored, decor/trees/signposts all ground-seated).
> - **(superseded) Earlier Fredoka cohesion pass:** all map sign `TextLabel`s converted from legacy
>   `Enum.Font` (Gotham*) to `FontFace` matching the UI `Theme.Font` — **FredokaOne** titles (x40) +
>   **BuilderSans** body (x29); 0 stale. (UI already used FredokaOne via `Theme.luau:58-68` — no src
>   change.) Sign plate bases unified to navy (22,24,32). `WorldGround.Decor` **rebuilt as intentional
>   landscaping** (was 105 random clusters → 16 road-flanking flower beds + 8 mid rock outcrops + 8
>   island-edge outcrops + edge/plaza shrub clumps, all tied to the 8-fold symmetry).
> - **Trees (map):** all 33 **rebuilt** as real trees (tapered trunk + branches + roots + species
>   canopy: oak/pine/blossom/maple/birch) with mixed shapes, on raycast-found ground.
> - **Plaza floor (map):** concentric bands re-toned into a readable medallion. Removed empty
>   `WorldGround.Perimeter` folder.
> - **Studio-only preview:** `workspace.PlotPreview` (a live clone of a plot at slot 0) is an editing
>   aid — **delete it before publishing** or it overlaps the first player's spawned plot.
> - **Open:** wire leaderboard/Hall-of-Fame SurfaceGuis to live data; build the `Shop` HUD screen.

> **Session 8 summary (MAP overhaul + one CODE change pushed). Supersedes parts of Session 7 below.**
> The map is still **gitignored / Studio-only** (persists only via the user's Ctrl+S). Big changes:
> - **World is now a FLOATING CIRCULAR ISLAND** (`workspace.WorldGround.Island`): round grass disc
>   **R870** (top Y4) + tapered rock **underbelly** (8 stacked tiers to ~Y−388) + hanging stalactites,
>   in **open sky** with `workspace.Terrain` **Clouds**. **Removed:** the old square 2048² `GroundSlab`,
>   the square `Perimeter` berms/curbs, all Terrain hills + water, and the distant backdrop islands.
> - **CODE (committed `c7cc822`, pushed):** `PlotService` now hides a plot's **blueprint marker** while
>   its slot is occupied and restores it on leave. `PLOT_RING_RADIUS` stays **580**. 525 tests, selene 0/0.
> - **Plot markers (NEW, map):** 8 concrete "surveyed blueprint" footprints in
>   `workspace.WorldGround.PlotMarkers` (`PlotMarker_0..7`) at the EXACT PlotService placement (radius
>   580, 262×410, −Z faces hub) — grid + white survey lines + corner stakes + "RESEARCH PLOT / AVAILABLE"
>   holo-sign. They mark where each plot spawns; PlotService hides them per occupied slot.
> - **Plaza tweaks:** floor is now **Concrete** (`PlazaMarble`, was Marble); **pavilions pulled in**
>   to r137 (from 155); **element pylons + festoon moved out to r188** (behind pavilions), festoon
>   rebuilt as **hanging string-lights** between pylons; monument on a **3-tier podium**; plaza furniture
>   (Commons planters + PlazaFurnish) pulled inward; **lamps rebuilt as connected top-lanterns** (no
>   floating parts); 8 **element gardens** rebuilt bigger (50×42 hedge planter, readable sign at front,
>   bench, flower beds, corner lanterns).
> - **Trees:** 33 detailed **mixed-shape** trees (ball/wedge/corner-wedge/cylinder canopies, fruit,
>   glow spores; 6 types oak/blossom/pine/willow/maple/birch) in the gardens + a ring along the island
>   edge (~r805). The old `BoundaryTrees` + scattered plot-zone trees were removed.
> - **Plot template:** the standard plot's `Grass` lawn shrunk 262×410 → **196×300** (Studio template).
> - **Intentional DELETIONS (owner cleanup):** Element spires, holo kiosks, energy beams + atmosphere
>   motes, monument halo + water jets, entry banners, most Commons flags.
> - **History note:** mid-session an accidental Studio **Ungroup** flattened the whole hierarchy (Hub/
>   WorldGround/Plots gone, ~2448 loose parts, trees dissolved). It was rebuilt **programmatically** —
>   containers recreated, all parts re-parented by name+radius, trees + pavilions re-clustered, GroundSlab
>   recreated. Lesson: don't select-all + ungroup; the structure is the contract.
> - **Open:** wire leaderboard/Hall-of-Fame SurfaceGuis to live data; build the `Shop` HUD screen.

> **Session 7 summary (in-world MAP build-out; one CODE change pushed):** developed the plaza into a
> coherent **"the plaza is an atom"** campus where every element has narrative meaning. Map is still
> **gitignored / Studio-only** (persists only via Ctrl+S); `IR-DIV-01` is the source-controlled record.
> - **CODE (committed):** `PlotService` `PLOT_RING_RADIUS` **620 → 580** — pulls plots in (front
>   375, just outside the rebuilt ring road vertices at 370); plaza→plot walk ~22% shorter. 525 tests
>   green, selene 0/0.
> - **MAP:** atomic floor medallion (nucleus ring + 8 bond-lines + element district coins); the 8
>   pylons/gardens branded as the 8 real Elements (C/S/Cl/Co/I/Li/Cu/Na); pavilion **forecourts +
>   grandeur** (attic/crown/cartouche, Board/Prompt untouched); **element gardens** (plinth + specimen
>   + bench/hedge); **lab gateways** ("LABORATORIES" wayfinding at spoke heads); **element avenues**
>   (per-spoke element pennants); **commons** (topiary planters + PRECIPICE flags); **world-edge berm +
>   tree-line**; ring road **rebuilt** to 580/370 with **junction node pads** (caps the old RingEdge
>   corner seam). New floor plates audited → 0 coplanar.
> - **Depth/verticality pass** (map was too flat): 8 **element-crystal spires** (~63 tall, r330);
>   monument lifted onto a **3-tier podium** (ascend to the nucleus); **Terrain hill** backdrop across
>   the water (`workspace.Terrain`). Theme held ("the plaza is an atom", element crystals).
> - **Pro-polish:** energy **Beams** nucleus→spires, ambient atmosphere **motes**, and 4 **holo info
>   kiosks** (FEATURED COMPOUND screens w/ real compounds + molecule holograms) at the cardinal entries.
> - **Open:** wire leaderboard/Hall-of-Fame SurfaceGuis to live data; build the `Shop` HUD screen.


> **Session 6 summary (in-world MAP build-out, all CODE pushed to `main`; 525 tests green, selene 0/0):**
> built out the physical world around the gameplay. The map itself is **gitignored / Studio-only**
> (Workspace is not Rojo-synced, iron rule #5) — it persists only via the user's Ctrl+S; these docs +
> `IR-DIV-01` are the source-controlled record. Done:
> - **Equal-distance plot formation** (`PlotService`, `0193f3d`): 8 plots ring the hub in a regular
>   **octagon** at `PLOT_RING_RADIUS = 620` around `HUB_CENTER = (1145,0,40)`, each `CFrame.lookAt`-turned
>   to face the hub. Absolute placement; the unused `PLOT_TEMPLATE` is parked off-stage (~8000,8000).
> - **Central Hub = Civic Plaza** (owner-directed override of §31, see `IR-DIV-01`): a clean circular
>   plaza (R230) with a molecule monument (reflecting pool + particles), a ring of 8 glowing **element
>   pylons**, 4 feature **pavilions** (Hall of Fame / Leaderboards / Shop / Events — open-front, readable
>   per-line boards), N/S-style entry arches + banners, seat-wall, benches, garden wedges, festoon
>   lights. Warm corporate palette, teal only on the molecule.
> - **Roads** match the plot road system **exactly** (asphalt `(42,42,46)`, dashes `0.6×0.12×4`, curbs
>   `0.6×0.6`, plot-style 22-stud road lamps): a hub-and-spoke network — 8 spokes + an octagon ring road
>   whose vertices sit at the plot fronts.
> - **Hub pavilions wired** (`StationController.bindHubPavilions`, `e152d62`) — Leaderboard/Event/Shop
>   prompts open their HUD screens (Shop had no in-world presence; unknown screens warn-no-op safely).
> - **Detailed landscaping** — oak/pine/blossom trees (layered crowns, branches, root flare), spaced
>   formally; clean grass terrain (Baseplate removed). Floor z-fighting audited → 0 pairs.
> - Map ≈ 4.7k parts, 63 lights (shadow-free). **Open follow-ups:** wire the leaderboard/Hall-of-Fame
>   board SurfaceGuis to live data; build the `Shop` HUD screen; optional: thin hub road-lamp lights.
>
> **Session 5 summary (Phase B — Modern sim-game UI overhaul, all pushed to `main`; 525 tests green,
> selene 0/0):** restyled the entire frontend to a cohesive custom look — one honey/indigo palette,
> a signature 3D pill button everywhere, soft drop-shadows, gradient backdrops, Fredoka display
> headers + honey underlines, spring hover/press motion. **Functions unchanged — visual only.**
> Foundation-first then per-screen, committed + live-verified in Studio in batches:
> - **Foundation** (`a24143c`): reworked `Theme.luau` (palette, {fill,shadow,text} action triples,
>   Fredoka font, shadow/backdrop/gloss tokens) + `Components.luau` (3D pill `Button`, `Card` w/ soft
>   shadow, `dropShadow`/`Backdrop` helpers; later added `ScreenHeader`/`TabBar`/`SectionLabel`).
> - **HomeScreen + bottom nav** (`c1cb6b2`), **More drawer** (`e345d6a`), **Synthesize/Lab** (`718dc5c`),
>   **Vault/Settings/Log/Leaderboard** (`69409da`), **Contracts/Event/Cosmetics/Prestige/Market/
>   Syndicate/Loading/RevealCard** (`63bc6f4`).
> - Unified `formatNum` to K/M/B/T across HomeScreen/Market/Syndicate; fixed a pre-existing
>   formula-log row layout bug (name/badge/button stacked at origin).
> - Live-verified each batch via the real path (nav clicks / drawer). HEAD `63bc6f4`.
>
> **Session 5b — full verification sweep + fixes (all pushed):** drove **every** screen live in
> Studio (real click/type path), not just spot-checks. Found + fixed two real bugs and shipped the
> rename feature:
> - **RevealCard layout bug** (`04ca603`) — the Phase B `Components.dropShadow` was a child of the
>   reveal Card, but the Card uses a `UIListLayout`, so the shadow ImageLabel got laid out in the flow
>   and spread the card content down the whole screen. Removed it; verified the real reveal flow
>   (start→force-complete→Reveal): card is contained, Keep advances the queue.
> - **Syndicate member-role contract bug + Founder rename UI** (`34b6727`) — server `members` maps
>   userId→role STRING, but the client read `members[uid].role`/`.displayName` as a table, so
>   `localRole` was always nil → role badges blank, `canManage` always false, and the entire
>   management UI (invite/kick/promote/rename/disband) was **dead after any rejoin**. Fixed to read the
>   role string directly (number- or string-keyed). Built the Founder-only **Rename** control (wired to
>   the existing remote); verified live (typed a name → renamed test→"Cascade Labs"). Officer badge
>   recoloured blue; pruned the muddy `AccentDim`/`SecondaryDim` Theme tokens; Leaderboard score now
>   K/M/B/T.
> - Live-verified flows: Vault sell (row cleared), Event buy (−300 flux), Contracts progress tick,
>   Settings, Cosmetics, Market, Prestige, Loading screen.
>
> **Could NOT do autonomously (needs the user):** a **mobile-viewport pass** — Studio device emulation
> isn't scriptable via the MCP, so phone-layout verification needs a manual emulation toggle. One known
> risk to check there: the HomeScreen slot panel is a fixed 212px (everything else is scale-based).
>
> **Still gated on the user:** Robux monetization IDs · analytics vendor · economy workbooks (below).
> **Known pre-existing (not Phase B):** the Syndicate UPGRADES/Joint "Buy"/"Cancel" buttons sit
> bottom-left of their rows (original vertical-list structure) — functional, looks rough; left as-is to
> avoid a risky restructure. `Components.Card` is defined but unused (dead code).

## Phase A → B history

> **Session 4 summary (HEAD `6fe3652`, all pushed; 525 tests green, selene 0/0):** finished the last
> Phase-14 items + hardening, then built Phase A. Done this session:
> offline-seller market rank credit (2-player verified) · map polish (WingLight dim + plot stride via
> PlotBounds + resized Grass) · joint-synth full 2-player e2e · Market sell picker (pick by name) ·
> `joinSyndicate` studioOnly debug · 4 sweep follow-ups (Hall-of-Fame UI/`ChampionshipsUpdate`,
> leaderboard display names, Event blueprint persistence, per-party `PatentResolved`) · **boot-race
> fix** (`RemoteController` WaitForChild + RemoteService parents folder last — killed the intermittent
> `missing remote` boot error) · patent-release announcements · +7 Lune tests · selene 155→0 warnings ·
> **Phase A: 5 in-world station terminals** (Vault/Market/Syndicate/Leaderboard/Prestige) + new
> `VaultScreen` + `StationController` (verified live via the E-prompt path).
>
> **⚠️ Map unsaved:** `Lab.Stations`, chambers 7–10, `PlotBounds`, resized `Grass` are in the gitignored
> `.rbxl` — **Ctrl+S in Studio** to persist or they're lost on close.
>
> **NEXT — Phase B (approved, not started):** full UI overhaul to a Modern rounded "sim-game" look
> (rounded cards, gradient backdrops, 3D pill buttons, bold rounded headers, shadows + hover/press
> motion). Functions unchanged, frontend only. Foundation first (`Theme.luau` + `Components.luau`),
> then per-screen migration (~14 screens), verify + commit in batches. Details in SESSION4_HANDOFF.md.
>
> **Still gated on the user:** Robux monetization IDs · analytics vendor pick · economy workbooks.

## Phase 14 — Finish-line build (planned)

Goal: take the game from "backend ~85%, loop verified" to feature-complete + launch-ready. Grounded in a code/STATUS audit on 2026-06-19. Priority: 🔴 blocker, 🟡 important, 🟢 nice-to-have.

### Phase 14 progress (2026-06-19)
- [x] **ClockService** (suggested-order 1) — built `src/server/Services/ClockService.luau`: 60s UTC tick (E3), daily + Monday-weekly boundary detection (pure, Lune-tested), drives GlobalJobService CAS jobs (F1 ledger): Monday `WeeklyEpochRotation` (dividends → sprintArchive → sprintWipe → seedEpoch, R3 order), 900s `PatentDividendSweep` (E2), hourly `MarketExpirySweep` (E7). Wired GameInit step 5 (before GlobalJobService, H9). Removed GlobalJobService dead poll loop; updated stale PatentService/MarketService wiring TODOs. **Latent bug fixed:** MarketExpirySweep previously had no driver — listings never expired in prod. 467/467 tests green; 0 selene errors; live boot-verified. NOTE: `payDividends`/`archiveSprint` still stubs (suggested-order 3); `seedEpoch` step logs only until AnnouncementService exists.
- [x] **Rate limiting** (suggested-order 2, §D) — built `src/shared/Core/RateLimiter.luau` (token bucket, clock-injected, Lune-tested). `RemoteService.setInvoke(name, handler)` enforces per-(player, remote) throttle from the Manifest `rateLimit` (capacity = ceil(rate); over-limit → `(nil, "rate_limited")`, handler skipped). Buckets keyed `userId:remote`, cleared on PlayerRemoving. Migrated all 33 C2S `OnServerInvoke` sites across 13 services to `setInvoke` (only RemoteService assigns OnServerInvoke now). RemoteHandlers CI guard updated to detect `setInvoke`. 474/474 tests green; 0 selene errors. Live-verified: PatentQuery (2/s) spammed 8× → `ok ok THROTTLED×6 ... ok` (burst 2, then refill).
- [x] **SynthesizeScreen real synthesis UI** (suggested-order 3, §B/12B) — replaced the analyze-only stub. ANALYZE state unchanged; SYNTHESIZE / SYNTHESIZE_VARIABLE now open a config modal: **slot routing** (free-slot chips within `slotCap`, prefers the launching slot), **variant picker** (lists only *discovered* result variants) + **Stabilized toggle** (off → active variant, standard timer; on → forces chosen variant, ×1.5 §8 — passes `desiredResultId` per B9), Synthesize/Cancel with status feedback; on success navigates Home. Client-only change; 0 selene errors (no new warnings); 474/474 tests still green. Live-verified in Studio: UI builds clean (modal tree present, hidden by default); standard synth → slot T2_13 (work 720); Stabilized-forced T3_06 → work 4050 (×1.5 of 2700). Variant picker is discovered-only, so an undiscovered variant can't be submitted (server enforces regardless). **Playtest fix (2026-06-20):** the Lab analyze button showed "Cannot analyze" for valid pairs — `LabAnalysis.getFee` was called with compound-ID strings instead of a tier number; now passes `math.min(tier1,tier2)` + prestige 0, button reads "Analyze — N". Picker cards now show the compound name, not the raw id. User-verified working. NOTE on UX: slot **Start** = extraction (1 compound, auto-starts); the **Lab** screen = synthesis (2 compounds) — two separate flows by design (could be merged into one Start flow if desired).
- [x] **AnnouncementService** (suggested-order 4, §15/A22/F2) — built `src/server/Services/AnnouncementService.luau` + pure `src/shared/Core/AnnouncementQueue.luau` (30s min-gap release + per-key/per-epoch dedup, Lune-tested). Publishes over MessagingService topic + fans out via the `Announcement` S2C; subscribe is hint-only (origin-guarded to avoid double-display), marquee is cosmetic so no DS re-verify (F2). Tier scoping per §15: first-claims announce at all patentable tiers, transfers only at **T4+**. Emit points wired: PatentService first-claim (`announceFirstClaim`, local player name) + T4+ decay-sweep transfer (`announcePatentTransfer`, async name resolve); ClockService `seedEpoch` step now calls `announceSeedEpoch` (closed its TODO). GameInit step 16b inits it + injects into PatentService. Added Studio-only `DebugCommand("announce", msg, tier?)` test hook. 482/482 tests green (+8); 0 selene errors. Live-verified: boot clean (`AnnouncementService: ready`); debug announce → client received `debug|Test marquee line|4` end-to-end. NOTE: real cross-server dedup is best-effort (cosmetic per F2); T2–T3 two-party transfer notifications (non-marquee) remain a later follow-up.

- [x] **PendingCredits login-drain** (bug, found post-sweep) — offline-accrued credits (patent dividends, market sales, expiry refunds) were drained only at logout/prestige, never at **login** — contradicting §15 "delivered on next login". Added `flushPendingCredits` in `DataService.openSession` (before `onProfileLoaded`, so services see the drained balance). Idempotent (store wiped + `pendingCreditsApplied` set). Verified via debug `drainPending`: +7777 applied once, double-drain no-op. NOTE: the two-store wipe+save isn't atomic (pre-existing) — narrow loss window on a crash between DS-wipe and profile-save; acceptable under ProfileStore's awaited saves.

### A. Core systems with NO implementation (build from scratch)
- [x] ~~🔴 **ClockService**~~ — DONE (see Phase 14 progress above).
- [x] ~~🔴 **AnnouncementService**~~ — DONE (see Phase 14 progress above): §15 tier-scoped marquee over MessagingService + 30s-gap queue; wired at PatentService first-claim/transfer emit points + ClockService seed epoch.
- [x] ~~🟡 **CosmeticService**~~ — DONE: §24 personal cosmetics. Pure `Core/CosmeticCatalog.luau` (4 categories — labSkin/particles/hudAccent/patentStamp, 20 items; Pellets/Catalysts/Prestige-5/event-pass acquisition; ownership/canPurchase/canEquip, Lune-tested ×16). `Services/CosmeticService.luau` wires `CosmeticPurchase`/`CosmeticEquip` C2S + `CosmeticUpdate` S2C (3 new Manifest remotes), purchase deducts currency, equip sets the category slot, `grantEventCosmetic` for event passes. Client: `StateController.cosmetics` + RemoteController handler. GameInit step 16c + fires CosmeticUpdate on login. Live-verified: buy arctic (500 deducted) → re-buy "already owned" → equip → free-default equip → Void blocked at P0 → S2C propagated.
- [x] **Cosmetics Lab-tab UI** — DONE: `src/client/UI/CosmeticsScreen.luau` (4 category sections from `CosmeticCatalog.byCategory`, reactive owned/equipped/affordability, Buy/Equip rows; server-authoritative with inline error status) + thin `CosmeticController`. Registered in UIController `_screens` + the "More" drawer ("Cosmetics"). `CosmeticCatalog.byCategory` ordered helper (+3 Lune tests). Build-verified in Studio: ScreenGui + all 4 sections + item rows render with no Fusion errors. **Playtest DONE (2026-06-20)** — drove the real button-click path in Studio via the MCP mouse driver (clicks the live TextButton, fires Activated → OnClick → CosmeticController → remote): Buy/pellets (Carbon Black −1200), Buy/catalysts (Oxidized Copper −80), Equip (Arctic Research → labSkin) all succeeded; rows flipped Owned/Equipped reactively from CosmeticUpdate and currency deducted via BalanceUpdate. (MCP `user_mouse_input` x/y are VIEWPORT coords, not screenshot coords — buttons at the far-right edge need the true AbsolutePosition center.) Minor UX wart (not fixed): unowned prestige5/event items (Void, Industrial Hazmat, Void Particles) show an enabled "Equip"; server `canEquip` rejects, but the button should be disabled-until-owned.
- [x] ~~🟡 **AdminService**~~ — DONE: `src/server/Services/AdminService.luau`. Permission = place owner (`game.CreatorId`) + `GameConfig.ADMIN_USER_IDS` (empty default; keep private). Commands `/give <compound> [qty]`, `/setbalance <amount>`, `/kick <player>`, `/inspect [player]`, `/tp <player>`; every accepted action logged with the admin's UserId. **Chat delivery (TextChatService):** the project uses TextChatService, which swallows typed `/` messages so `Player.Chatted` is not reliable for them. AdminService registers the slash-commands **server-side** as `TextChatCommand`s; `Triggered` fires on the server with the sender's `TextSource`, server re-checks `isAdmin`, runs `handleCommand`. No client code, no relay remote. `/setbalance` fires BalanceUpdate so the HUD refreshes; the Player.Chatted fallback was removed (it double-fired → would double `/give`). **User-verified working** (2026-06-20): typed `/setbalance`/`/give`/`/inspect` execute once and update the HUD.

### B. Client UI unwired / incomplete
- [x] ~~🔴 **SynthesizeScreen → real synthesis**~~ — DONE (see Phase 14 progress above): config modal with slot routing + variant picker + Stabilized toggle → `startSynthesis`.
- [x] ~~🟡 **PrestigeScreen**~~ — DONE (2026-06-20): real prestige level now reaches the client (piggybacked on `SlotCapUpdate`, which fires at login + prestige confirm — payload now `(slotCap, prestigeLevel)`; new `StateController.prestige.level`). Replaced the level-0 stub with a reactive Value. **Found + fixed two return-shape bugs in PrestigeController** (same class as the leaderboard bug): `RemoteController.invoke` returns server values *directly* on success (no leading pcallOk — see MEMORY `reference_remotecontroller_invoke_contract`), so `request()`/`confirm()` were reading nil → blockers never displayed, button never disabled, and a blocked confirm read as success. Now `request()` reads `res.blockers`, `confirm()` reads `res.ok`/`res.err`. Live-verified via real UI: level shows 0→1 / 2→3 / 25→26 with correct §22 bonuses; at level 25 the BLOCKERS section renders both blockers (rank gate + insufficient pellets) and the Prestige button is disabled. Added debug `setPrestigeLevel <n>` (studioOnly) to test without a 250k-rank prestige. `confirm()` is code-correct but not live-run (eligible profile needs 250k rank + a destructive full reset). NOTE: CosmeticController has the same latent invoke-misread (masked; status-line error text only).
- 🟡 **Live-verify built screens** — **sweep pass 2 done 2026-06-20** (user-playtested in Studio):
  - ~~**Cosmetics Lab-tab**~~ — Buy/Equip real-click verified.
  - ~~**Prestige**~~ — level + blockers + disabled button verified (real UI).
  - ~~**Leaderboard**~~ — sprint row renders (controller return-shape bug fixed).
  - ~~**Market**~~ — browse renders rows (BROWSE_COUNT 3 via remote, UI shows them after the browse return-shape fix + card field-name fix price/sellerId).
  - ~~**Syndicate CRUD**~~ — was crashing on open (`formatNum(syn.vaultPellets)` → nil; field is `vaultBalance`) + upgrade list keys/costs were fake; both fixed. Create / contribute vault / buy Syndicate Crest (1.0M from vault, → Owned) all verified.
  - ~~**Settings**~~ — Music/SFX toggles hold; gamepass rows render "Not owned" (IDs are 0).
  - **Exotic Registry** — renders empty, which is CORRECT (only shows T7 `EX_xxx` exotics; discovering a compound doesn't populate it).
  - [x] ~~**Contract / Streak — NO client UI**~~ — BUILT 2026-06-20: `src/client/UI/ContractsScreen.luau` (More → Contracts). 5 contract rows (difficulty tag + description + progress bar + `progress/target · reward ◈`), Claim button on completed-unclaimed slots, streak-day indicator; template details looked up from `Data/ContractPool` by `templateId` (server slots carry only templateId/progress/target/completed/claimed). Registered in UIController `_screens` + More drawer. Fixed two bugs found while building: **ContractController.claim** misread the `{ok,err}` return (return-shape class); **StreakUpdate** client handler read `(day, safeUntil)` but the server fires a single `{day,safeUntil}` table → `streak.day` was a table (crashed the screen) — handler now takes the table. **Live-verified**: contracts render, a completed contract ("List a compound on the Market", 1/1) claimed → button → "Claimed" reactively; streak shows "🔥 Daily streak: day 3"; no Fusion errors.
  - [x] ~~**Event / Flux — NO purchase/display UI**~~ — BUILT 2026-06-20: `src/client/UI/EventScreen.luau` (More → Event). Flux balance + season header (from `StateController.flux`), 7 blueprint rows from `Data/EventCompounds` (name/tier/`blueprintFlux` cost) with affordability-aware Buy buttons, empty-state when no event is active. Ownership tracked locally (optimistic on a successful buy; server rejects double-buys — a `blueprintsOwned` S2C for cross-reopen persistence is a follow-up). Registered in UIController + More drawer. Added studioOnly debug `startEvent <flux?>` to set a debug event + grant Flux. Fixed **FluxUpdate** client handler (read `(seasonKey, total)` but server fires a single `{seasonKey,total}` table — same class as the StreakUpdate bug) and **EventController.purchaseBlueprint** return-shape. **Live-verified**: empty state when no event; after `startEvent`, header "◇ 2000 Flux · debug_season", 7 blueprints render (4000-Flux T5 ones red+disabled at 2000 flux), bought Cascade Trace (50) → flux 2000→1950, button → "Owned".
  - [x] ~~**FormulaLog**~~ — swept 2026-06-20. 🐛 **FOUND + FIXED**: the Formula Log screen + `LabController.getButtonState` read `StateController.formulaLog`, which was only ever appended to by the incremental `LabDiscovery` S2C — so a **returning player's log was empty** (and every known recipe read as undiscovered, so the Lab button wrongly showed "Analyze"). The `FormulaLogRequest` remote existed server-side but nothing called it. Added `LabController.hydrateFormulaLog()` (fetch `FormulaLogRequest` → convert the `discovered` map to the `{compoundId,...}` array the UI expects) and call it at login (ClientInit PlayerReady). Live-verified: log renders discovered recipes (Zinc Ferrite / Tungsten Carbide / Magnesium Chloride) after a fresh login.

**Sweep follow-up fixes (2026-06-20, sweep pass 2 cont.)** — three return-shape/UX bugs found during the sweep, all fixed + tests green:
  - **CosmeticController** invoke misread (`local pcallOk, ok, err` → returned wrong values; buy/equip status text was wrong, success could read as failure). Now `local ok, err = invoke(...)`.
  - **SynthesizeScreen analyze** always said "Analysis complete." regardless of outcome (and "nil" on hard errors). Now maps `result.status` (discovery/failure/already_discovered/refused/cached_failure) to an accurate message; handles the `(nil, err)` hard-error case.
  - **CosmeticsScreen** unowned prestige5/event items showed an enabled Equip (server rejected). Now Equip is disabled until owned. **Live-verified**: Void / Industrial Hazmat / Void Particles show disabled Equip; owned (Carbon Black/Oxidized Copper/Blue-White) show enabled Equip; equipped shows disabled ✓.

### C. Server features half-built (TODOs in shipped code)
- [x] ~~🔴 **PatentService weekly dividend payout**~~ — DONE: `payDividends(weekKey, now)` pays each held patent its §15 tier dividend (T2 800 → T6 100k) — online to balance + BalanceUpdate, offline to PendingCredits; idempotent via `dividendPaidThruWeek` stamp (F1 resume-safe). Driven by ClockService Monday job. Live-verified: held patents paid (+90,800), same-week re-run paid nothing. `PatentResolved`/release marquee = AnnouncementService transfer (T4+) wired; per-party PatentResolved S2C still a follow-up.
- [x] **T7 Exotic dividends** — DONE: exotic patents share the Patents DS (`ExoticService.onPairCompleted → recordNaturalSynthesis(EX_xxx)`); `payDividends` now also iterates `_exotics` and pays held exotic patents a flat 200k/week (§15/§23, decay-independent). Also fixed: `recordNaturalSynthesis` resolved unknown ids (exotics) to tier 1 → added `tierOf()` so exotic patents record/announce as **T7**. Live-verified: held EX_001 → +200,000 (delta 290,800 = 90,800 compounds + 200,000 exotic).
- [x] **Exotic patent decay/contest sweep** — DONE: `runDecaySweep` extracted a `sweepPatent` helper and now iterates `_compounds` **and** `_exotics`, so exotic patents' 7-day T6/T7 defense windows resolve (contest/transfer) via the 15-min sweep (§13/§23) — previously skipped. Winner-selection logic identical to compounds (Lune-tested). Live-verified: an exotic patent with an expired challenge had its window resolved (challenge cleared, immunity applied). Added debug `patentSweep`.
- [x] ~~🔴 **RankService.archiveSprint** + champion badges~~ — DONE: Monday job step 2. Reads Sprint_{weekEpoch} ODS top-3 → writes a `SprintHallOfFame` DS snapshot + awards each a championship in a dedicated, offline-safe `Championships` DS (idempotent per week); reflects into online winners' profiles. New profile field `championships` (schema 4→5, migration[4]) synced from the DS at login via `RankService.loadChampionships` (wired in GameInit). Score wipe is implicit (week-keyed ODS). Live-verified: granted sprint points → archive → champion (week 25, rank 1) awarded + profile-reflected; re-archive stayed idempotent (count 1). Added debug `grantSprintPoints`/`archiveSprint`. NOTE: Hall of Fame client UI display is a later follow-up (data is now persisted).
- [x] ~~🟡 **LeaderboardService** percentile blob~~ — DONE: hourly `PercentileBlob` GlobalJob (ClockService-driven, shares the hourly bucket) — `computePercentileBlob` pages the top ~1000 of each board's ODS and writes rank-checkpoint thresholds (every 50) + readCount to the GlobalJobs DS. Own-row resolution beyond top-100 now calls the pure, Lune-tested `_estimateRankFromBlob` (interpolates a rank within the window; readCount lower bound below it) instead of a flat -1. Live-verified: job wrote `{readCount=6, thresholds=[r1]}`; estimate(low)=readCount, estimate(high)=1. Added debug `percentileJob`.
- 🟡 **MarketService** — expiry-sweep-via-GlobalJob is DONE (ClockService-driven). **Offline-seller rank/contract credit: DONE 2026-06-21 (3f676c8).** Added `DataService.onCreditDrained(fn)` — `flushPendingCredits` now invokes registered handlers once per drained credit `(userId, data, credit)`, keeping DataService free of Rank/Contract deps. `MarketService.onCreditDrained` replays `scoreMarketSale` + `recordProgress("market_sell_pellets")` for `market_sale` credits at the seller's next login-drain (parity with the online path). Guarded the RankUpdate/ContractUpdate FireClient sites against a nil player (drain can run at logout/BindToClose). **FULL end-to-end verified 2026-06-21 (2-player local test):** P1 listed a compound → closed window (offline) → P2 bought it (`BUY -> true`, server took the offline-seller branch → wrote a `market_sale` pending credit) → P1 rejoined → **rank 5→6 at login-drain** (pre-fix it would have stayed 5; pellets-only). Also solo-verified the drain half earlier (+5000 pellets, rank 80→85, dailyCaps.marketPoints 0→5). **DONE.** Remaining (intentionally deferred): **MemoryStore fast browse** (perf rewrite of the working DataStore-index browse).
- [x] ~~🟡 **SeedResolver**~~ — DONE 2026-06-20: added `src/shared/Core/Sha256.luau` (pure-Luau SHA-256 + HMAC-SHA256, verified against NIST + RFC 4231 vectors in `tests/specs/Sha256.luau`). SeedResolver now derives the weekly seed from the top 32 bits of `HMAC-SHA256(salt, "week:N")` via an injected hasher (kept pure/Lune-testable; SeedService injects `Sha256.hmac` at boot alongside the salt). FNV-1a remains as a no-hasher fallback. Lune-verified (seed = HMAC top-32-bits, deterministic, differs per week) + Roblox-runtime-verified (Sha256 vectors match in a live Server VM; clean boot). 518 tests green.
- 🟢 **AnalyticsService** — no-op stub (§30); wire a provider eventually.

### D. Security / hardening
- [x] ~~🔴 **Rate limiting NOT enforced**~~ — DONE (see Phase 14 progress above): `RemoteService.setInvoke` enforces Manifest `rateLimit` per (player, remote) via `Core/RateLimiter`.
- [x] ~~🟡 **Strip/secure DebugService**~~ — VERIFIED 2026-06-20 unreachable in prod (triple-gated): Manifest `DebugCommand` has `studioOnly = true`; `RemoteService` skips creating any `studioOnly` remote when `not RunService:IsStudio()` (RemoteService.luau:35), so the remote does not exist in prod; and `DebugService.init()` early-returns in prod. No code change needed.
- 🟡 Configure real Robux product/gamepass IDs in `GameConfig`.

### E. Built + Lune-green but NEVER Studio-tested end-to-end (integration sweep)
Use the DebugService hook (grant/discover/`completeSlot` natural skip) to drive these fast:
Market full loop · Syndicate lifecycle · Joint Synthesis T6/T7 · Exotics (decay/world-first; verify T7 id scheme — `T7_01` doesn't exist) · Prestige full reset (§22 wipe-vs-persist) · Events/Flux · Streak · Contracts · Monetization receipts/gamepasses · Offline income · **Multiplayer 2+** (patent contests, cross-player market, plot tiling).

**Sweep pass 1 (2026-06-19, single client):**
- [x] **Market full loop** — create (in-bounds), out-of-bounds price rejected ("price out of allowed range"), browse shows own listing, self-buy rejected (`SELF_TRADE`), cancel returns stock. ✓ (NOTE: these were remote-level checks — see the client browse bug below, found when sweeping the actual UI.)
- [x] **Market browse (client)** — 🐛 **FOUND + FIXED (2026-06-20, sweep pass 2)**: server `MarketBrowse` returns `(listings, err)` but `MarketScreen` reads `local ok, result = MarketController.browse(...)` then checks `type(result) == "table"` — `result` was the err (nil on success), so listings **never rendered in the UI** even though the remote returned them. Same root cause as the leaderboard/prestige bugs (`RemoteController.invoke` returns server values directly). Fixed `MarketController.browse` to read `(listings, err)` and return normalized `(ok, listings)`. **Bug confirmed live pre-fix** (created a T2_13 listing via remote → remote browse returned it, but the Market UI Browse tab stayed empty). ✅ Post-fix render CONFIRMED (2026-06-20, user playtest): remote `BROWSE_COUNT` 3, Market → T2 shows rows. Also fixed the card field names (`pricePerUnit`→`price`, `sellerUserId`→`sellerId`). Tests 509 green, selene 0 errors.
- [x] **Prestige blockers** — `PrestigeRequest` correctly returns rank-gate (250k) + pellet-cost (500k) blockers. ✓
- [x] **Contracts** — `ContractClaim` validates `completed`/`claimed` (claimed a genuinely-complete contract; rejects otherwise). ✓
- [x] **Leaderboard** — 🐛 **FOUND + FIXED (server)**: server `LeaderboardRequest` returned one `{entries, ownRow}` table but the client destructures two values `(entries, ownRow)` → board showed garbage + nil own-row. Fixed: remote wiring unpacks to a tuple (internal handler/Lune tests unchanged). Verified: returns entries + ownRow (rank 1, score 4468). ✓
- [x] **Leaderboard (client)** — 🐛 **FOUND + FIXED (2026-06-20, sweep pass 2)**: the *previous* fix corrected the server to return `(entries, ownRow)` but `LeaderboardController.request` still destructured `local ok, entries, ownRow = invoke(...)` — `RemoteController.invoke` returns server values directly (no leading pcallOk), so `ok`=entries(empty-array→truthy), and the code set `lb[board]` = the ownRow object → board could never render rows (the server "verified" was only the remote layer). Now reads `local entries, ownRow = invoke(...)`. **Live-verified via real UI**: granted sprint points (debug `grantSprintPoints 5000`) → opened Weekly Sprint tab → row renders "#1 … 5000". (Minor: rows show userId, not displayName — server entries lack a displayName field; separate cosmetic follow-up.) See MEMORY `reference_remotecontroller_invoke_contract`.
- [x] **Syndicate lifecycle** — create / contributeVault / purchaseUpgrade(crest, 1M from vault) / disband (deletes vault) all work; rate limiting (1/s upgrade, 0.1/s disband) confirmed firing in practice. ✓
- [x] **Exotic id scheme** — confirmed `EX_001..EX_120` (120 exotics); **no `T7_xx` compounds exist** (`T7_01`=nil, Compounds T6=15/T7=0); `resolveExotic(T6_01+T6_01)=EX_001`. Matches the handoff flag. ✓
- [x] **Events gate** — `BlueprintPurchase` rejects "no active event" when none active. ✓
- [x] **2-client sweep (2026-06-20, user + self tested):** cross-player Market buy ✓ (P2 bought P1's listing); plot tiling ✓ (distinct plots); patent contest ✓ (P1 world-first `didClaim=true`, P2 `didClaim=false` + PatentQuery shows holder+challenger, via debug `claimPatent`). Joint Synthesis: **FULLY verified 2026-06-21 (2-player local test)** — P1 staged (`STAGE -> true`), real P2 joined the syndicate (new studioOnly `joinSyndicate` debug, since invite rejects Studio's negative test userIds) and **contributed → `CONTRIBUTE -> true`**, driving the slot STAGED→RUNNING. The same-userId contribute rejection was the gap; a genuinely different player cleared it. RUNNING→COMPLETE is the timer (Lune-tested ×8). **DONE.**
- [x] **Syndicate screen** — 🐛 layout + disband fixed 2026-06-20 (was logic-only, never visually laid out): disband never called the server step-1 arm (always "no pending disband"); upgrade Buy buttons + contribute/invite buttons were mis-ordered because inner UIListLayouts lacked `SortOrder` (sorted Frame-before-TextLabel by Name). Fixed + live-verified: upgrade cards read name→cost→Buy, contribute shows Amount then Contribute, disband arms (vault 8124) + confirms.
- [x] **Offline income** — DONE 2026-06-20 (debug `simulateOffline <hours>` backdates lastSeenAt + re-runs the login settle). 🐛 **FOUND + FIXED**: the offline settle only pushed slot state for *surviving* slots and never fired a BalanceUpdate — so slots that **completed offline stayed shown as running** on the client and the HUD pellet income was stale until another event fired. Now it `fireSlotCleared`s each offline-completed slot and fires BalanceUpdate. Live-verified: started a T1_01 extraction → `simulateOffline 4` → +743 pellets (passive), slot drained + compound awarded to vault, **client slot card cleared to "Slot idle" and HUD updated to 11.6K**.
- [x] **Prestige full reset** — DONE 2026-06-20 (user-tested + self-verified via debug `grantRank`/`grantPellets`). Reset is correct (pellets floored to 500, vault/slots/streak/contracts/currentRun wiped, formula log/lifetime/sprint/cosmetics + championships preserved, +1 slot at level 1). 🐛 **FOUND + FIXED**: PrestigeConfirm fired RankUpdate + SlotCapUpdate but **not BalanceUpdate or VaultUpdate**, so the HUD pellets + vault stayed stale (showed pre-prestige 2M) after the reset. Now fires both. Verified: HUD updated 2.0M → 500 immediately after confirm. (Note: PrestigeConfirm/Request are rate-limited 0.1/s — clicking fast yields a transient "request failed"; see the client-UX follow-up below.)
- ⏭️ **Needs special setup (still):** Monetization receipts (real Robux dev-product purchase).

### F. Map / world (Studio `.rbxl`, gitignored — manual save required)
- 🔴 **SAVE the place** (B4 + map-polish 2026-06-21) — chambers 7–10 AND the new map-polish edits (PlotBounds part + resized Grass) are in the live Edit DataModel but unsaved; **Ctrl+S to persist** or they're lost on Studio close.
- [x] ~~🟡 Plot stride ~2000 studs~~ — DONE 2026-06-21 (de4e097). Root cause: per-plot `Exterior.Grass` was a 2000×2000 slab → `GetExtentsSize` = 2000 → stride 2064. Added an invisible `PlotBounds` part (262×410, the real lot) that `PlotService.offsetForSlot` now reads for the stride (GetExtentsSize fallback); shrank Grass to the lot footprint so tiled plots don't overlap. Live-verified: clone spawned at z 472.7 (stride 474), was ~2064. **Map edits need Ctrl+S.**
- [x] ~~🟡 WingLight reveal-dim invisible~~ — DONE 2026-06-21 (de4e097). The only `WingLight` was a PointLight parented to the Lab *folder* (no transform → no light), so the dim was invisible. `RevealController.dimWingLights` now recursively dims the lab's real ambient lights (the `LightPanel` PointLights + any hosted WingLight), capturing/restoring each light's build brightness (factor-based; restores to 2.4, not the old hardcoded 1). Live-verified on a cloned plot: 4 panel lights 2.4→0.48→2.4 + WingLight 1→0.2→1. **Pure code fix — no map save needed for this one.** (Remaining: world space/art for chambers 7–10.)

### G. Content / data verification
- **Internal consistency: DONE** — locked by `tests/specs/DataIntegrity.luau` (150 compounds + per-tier counts, 205 recipes + per-tier counts, pair uniqueness + 17 variable pairs, BFS reachability of all 150 from the 5 starters, 120 exotics + unique names + value bands, 24 contract templates + reward bands). All green in the 518-test suite.
- **Needs the user (can't be automated):** exact economy values (rates/fees/timers per tier) vs the **two source workbooks** — those spreadsheets aren't in the repo, so the authoritative value-by-value comparison requires them. Provide the workbooks (or the specific values) and I can add exact-value assertions.

### Suggested order
1. 🔴 ClockService (unblocks C/E sprint+dividend+epoch testing)
2. 🔴 Rate limiting (security, isolated)
3. 🔴 SynthesizeScreen synthesis UI (+ PatentService dividends, RankService archiveSprint once Clock exists)
4. 🔴 AnnouncementService
5. 🟡 Build CosmeticService/AdminService; finish half-built server features
6. 🟡 Integration sweep (§E) with the debug hook; live-verify UI (§B)
7. 🟡 Map saves/polish (§F), content verification (§G), hardening (§D)

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
- [x] Task 14: PRECIPICE_PHASE6B -- RankService (addScore, addSprintPoints, daily caps market/vault, scoreNaturalCompletion/Discovery/Defense/Claim/MarketSale/VaultContribution, archiveSprint stub); LeaderboardService (LeaderboardRequest C2S, 60s cache, own-row resolution, rank=-1 fallback); Sprint tracking merged into RankService; full contract+streak wiring (SlotService, LabService, VaultService, MarketService, ContractService, StreakService); 218/218 tests green
- [x] Task 15: PRECIPICE_PHASE7 -- PrestigeService (R5 blockers: rank gate 250k, pellet cost, slot running/unrevealed; §22 reset table: vault/slots/streak/contracts/rank.currentRun wiped, lifetime/formulaLog/sprint/cosmetics preserved, pellets floored to 500; patent fan-out via PatentService.releaseAllForUser; ChiefBoard ODS write at prestige time); MarketService per-user listing index (index:user:{userId}) + cancelAllForUser; PatentService.releaseAllForUser; RankService.writeChiefBoardScore; DataService.drainPending public wrapper; GameInit wired; 244/244 tests green
- [x] Task 16: PRECIPICE_PHASE8 -- MonetizationService (gamepass cache: expandedLab/extendedOffline/compoundArchive; getSlotCap/getOfflineCap prestige+pass stacking; ProcessReceipt idempotency via receiptLedger; CatalystS/L/RushAnalysis/TimerSkip dispatch; CompoundArchive monthly archive grant; deductCatalystSkip; SlotService cost wiring for catalyst+timerskip skips; applySkipToSlot; BalanceUpdate payload +rushUses+timerSkipUses; GameInit wired; 269/269 tests green)
- [x] Task 17: PRECIPICE_PHASE9 -- EventService (Flux earn by extraction/synthesis; event pass 2x Flux; income 1.5x multiplier; community milestone 25 Catalysts; blueprint purchase via Flux; event patent first-run/between-run guards; schema v3 migration; FluxUpdate+BlueprintPurchase remotes; OfflineIncome multiplier param; GameInit wired; 295/295 tests green)
- [x] Task 18: PRECIPICE_PHASE10A -- SyndicateService (create/invite/accept/kick/promote/rename/contributeVault/purchaseUpgrade/expandMemberCap/disband+confirm; pending invite DS; schema v4 migration; 8 new remotes; T4 joint qualification hook in SlotService; GameInit wired; 325/325 tests green)
- [x] Task 19: PRECIPICE_PHASE10B -- JointSynthService (EMPTY/STAGED/RUNNING/COMPLETE state machine, async expiry+cooldown, offline pending delivery, passive income virtual slots); ExoticService (decay math 0.97^N, floor at 25%, world-first claim fan-out, atomic UpdateAsync unit count); RecipeResolver.resolveExotic; PrestigeService joint blockers wired; ExoticRegistryUpdate remote; GameInit wired; 353/353 tests green
- [x] Task 20: PRECIPICE_PHASE11 -- JointSynth DS budget fix (batch per-syndicate); vault contribute floor; FormulaLogRequest OnServerInvoke in LabService; event compound blueprint gate in SlotService; DataService.isLoaded session guards on all C2S handlers; MarketService self-trade SELF_TRADE check; SyndicateInvite userId validation (integer, positive, <10B, not-self); AnalyticsService stub (Events table + no-op track, wired at all emit points); RemoteHandlers CI spec; DataIntegrity known-limitation comment; 401/401 tests green
- [x] Task 21: PRECIPICE_PHASE12A -- src/shared/Types.luau; LabButtonStateLogic + PrestigeLogic + HintTriggerLogic pure modules; RecipeResolver +getResultIds +isVariablePair; 17 client Controllers (StateController signal, RemoteController S2C wiring x20, SlotController chamber stub, LabController button-state, all feature controllers); UIController + 9 UI stubs (LoadingScreen with taglines, Home/Synthesize/Market/FormulaLog/Leaderboard/Syndicate/Prestige/Settings); ClientInit.client.luau boot order; 3 Lune specs (LabButtonState x14, PrestigeBlockers x9, HintTriggers x34); default.project.json +StarterGui; 457/457 tests green
- [x] Task 22: PRECIPICE_PHASE12B -- Theme.luau + Components.luau (Button/Card/Label/TierBadge/Divider/ProgressBar/ScrollFrame); all 9 UI screens replaced with Fusion 0.3.0 implementations (LoadingScreen animated progress+taglines, HomeScreen slot cards with live timers+HUD+marquee+hint+offline-card, SynthesizeScreen pickers+formula-log, MarketScreen browse/my-listings+modal, FormulaLogScreen+ExoticRegistry, LeaderboardScreen 2 boards, SyndicateScreen full CRUD+joint slots, PrestigeScreen 2-step confirm, SettingsScreen toggles+gamepasses); UIController progress tracking + More drawer; 457/457 tests green; 0 selene errors; 0 stylua diffs

- [x] Task 25: PRECIPICE_UI_POLISH -- Theme.luau (CornerRadius 4→8, CornerRadiusSmall/Pill, Padding 16, PaddingSmall, GapSmall/Medium); Components.luau (Button TextSize 15, secondary UIStroke, Card uses Padding+UIStroke, TierBadge pill 32×22 TextSize 12, Divider #3A3A42, ProgressBar height 8 pill track+fill); HomeScreen.luau (HUD 56→60 bottom-border, accent bar 6px, slot card positions adjusted, scroll frame padding, nav active indicator, RevealBanner/Marquee sizes); RevealCard.luau (corner 12→16, padding 16→20, CompoundName 24→26, patent banner 10→14 pad/22→24 title, Keep UIStroke, value label "⬡ N Pellets", card heights 320→300/400→380); 457/457 tests green
- [x] Task 26: PRECIPICE_UI_LAYOUT -- HomeScreen full overhaul: uiVisible Value drives ScreenGui.Enabled (scope:Computed); activeTabValue lifted to HomeScreen.open scope; WorldHUD ScreenGui (DisplayOrder 5, always-on): circular open button + Heartbeat-driven timer strip (running/done summary); HUD 60→52 + minimize button (sets uiVisible=false); slot cards redesigned narrow (68px, pill accent bar, #N label, 48×24 action btn); left slot panel (200px, visible on Home tab, SLOTS header, ScrollingFrame 1px gap layout); bottom nav 56→52 + top separator + wrapper frame for border/tabs separation; makeHintBar AnchorPoint(0,1) at (0,0,1,-52); marquee/RevealBanner/OfflineCard positions updated; dead locals removed; 457/457 tests green

## Phase 13 — Studio debug pass (2026-06-18)

Live loop-walk in Studio (extraction → synthesis → lab discovery → reveal → market → vault → prestige/syndicate blockers) against design v4.6. Most systems verified working. Bugs fixed:

- [x] **B1 — slot count UI** — HomeScreen hardcoded `for i = 1, 10`, ignoring the personal slot cap (design §8: base 5). Added S2C remote `SlotCapUpdate`; server fires cap on profile load (`SlotService.fireSlotCap`), gamepass refresh (`MonetizationService.refreshGamepasses`), and prestige confirm (`PrestigeService`). Client `StateController.slotCap` (default 5) drives per-card `Visible = slotIndex <= slotCap`. Verified live: base player renders 5 cards, 6–10 hidden.
- [x] **B2 — patent world-first race** — `SlotReveal` now returns authoritative `isPatent`; `PatentService.recordNaturalSynthesis` returns `didClaim`, threaded through `SlotService` into the payload. `RevealController` reads `result.isPatent` instead of racing the `PatentClaim` S2C event (dead `StateController.patents` poll + unused `Players` import removed). Manifest `SlotReveal` payloadDesc updated.
- [x] **B6 — skipped runs claimed patents** — reveal recorded patents for tier ≥ 2 regardless of `isNatural`, violating §14. Now gated `if isNatural and tier >= 2`.
- [x] **B3 — plot overlap** — `PlotService` clones were never moved, stacking all plots at the template origin. Now tiled in an 8-col grid (stride = template extents + 64 studs) via `PivotTo`, with reusable slot indices freed on logout. Spawn routing added: per-player `RespawnLocation` → own plot spawn, existing character teleported on, origin template spawn disabled. Verified live: plot at z=2055 vs template z=-9, character routed on.
- [x] **B9 — Stabilized Synthesis never forced the variant** — `SlotStartSynthesis` always resolved this week's *active* variant; the `stabilized` flag only applied the ×1.5 timer. So stabilized was strictly worse than standard (same result, slower) and you could never produce the non-active variant of a variable pair — breaking §7/§8. Found during deeper-tier testing (17 variable pairs in the data). Fix: added optional `desiredResultId` to the remote; when `stabilized`, if it's a valid discovered variant of the pair, produce *that* (else reject "variant not discovered"). Non-stabilized ignores it (always active). Client `SlotController.startSynthesis` + Manifest updated. Verified live: standard → active T3_10 (work 2700); stabilized + `T3_06` → T3_06 (work 4050 = ×1.5); bogus variant rejected. NOTE: the SynthesizeScreen variant-picker UI is still unbuilt (synthesis UI is unwired overall — STATUS 12B); this fixes the server mechanic so that UI will work.
- [x] **B8 — LabAnalyze re-discovery exploit** — the analyze handler never checked whether the recipe was already discovered: re-analyzing a known recipe charged the fee, consumed both inputs, and granted a specimen instantly — a slot-free, timer-free production bypass and a fee-waste UX bug (§11: a known recipe is "Synthesize", not "Analyze"). Also a server-validation gap (remote trusted to only be called on undiscovered pairs). Fixed: resolve first, and if `formulaLog.discovered[resultId]` reject with `status = "already_discovered"` before any fee/consume/Rush/grant. Per-resultId check preserves variable pairs (alternate variant still discoverable). Verified live: re-analysis returns `already_discovered`, fee 0, inputs untouched.
- [x] **B5 — RevealPrompt wired** — `SlotController.bindRevealPrompts` (called on `PlayerReady`) connects each chamber's `RevealPrompt.Triggered` → `SlotController.reveal(i)`, guarded to DONE slots, and toggles `prompt.Enabled` to match slot state (`ActionText = "Reveal"`). Reveal stays UI-driven too; this is the in-world equivalent. Verified live: prompt enables when a slot completes, disables after reveal, skipped on chambers >6.

**Tooling — Studio-only debug hook (Phase 13):** added `DebugService` + a `studioOnly` `DebugCommand` remote (RemoteService skips creating it in production via `RunService:IsStudio()`; `DebugService.init` no-ops in prod). Commands: `grantPellets`/`grantCatalysts`/`grantCompound`/`discoverRecipe`/`completeSlot`/`dumpProfile`. `completeSlot` calls new `SlotService.forceCompleteSlot` which drains a slot to **natural** completion (`isNatural` preserved → still counts for patents/Sprint/rank), so the full natural pipeline is testable without waiting out 12-min timers. Used it to finally verify **B2 `isPatent=true` live**: granted inputs → discovered T2_13 → synth → completeSlot → reveal returned `isPatent=true` and a world-first patent record (holder/tier correct). RemoteHandlers CI test auto-covers the new C2S function (458 tests).

**Cleared (not bugs):** B7 timer "online speedup" — model stores `workRemaining` at online rate (1.0 baseline); offline is 0.8 (20% slower) per §9. Display and completion agree. · "DataService session bug" (old memory) — false alarm from the Studio MCP `execute_luau` separate require cache; real session loads fine (verified via remote round-trips).

- [x] **B4 — chambers 7–10** — cloned chamber 6 four times in `workspace.Plots.PLOT_TEMPLATE.Lab.Chambers`, named 7–10, positioned continuing the 3-wide grid (row z=-29: 7/8/9 at x=-22/0/22; 10 at x=-22 z=-49). Each carries the full assembly + `RevealPrompt`. Verified live: all 10 chambers resolve in the cloned player plot and bind reveal prompts. **NOTE: this is a Studio place-file change (`.rbxl` is gitignored) — must be saved in Studio (Ctrl+S) to persist; not captured by git.**

**Still open:** none. B1–B6 all resolved (B4 pending a manual Studio save).

## Phase 12E completed (2026-06-17)

- [x] **Starter compound seed** — `VaultService.onProfileLoaded` seeds 5 `starter=true` compounds (T1_01–T1_05) at `STARTING_COMPOUNDS_PER_STARTER = 1` when `vault.compounds` is empty (fresh profile). `EconomyConstants.STARTING_COMPOUNDS_PER_STARTER` consumed for the first time.
- [x] **Extraction picker data source** — `makeVaultBrowser` branches on `mode == "extraction"`: shows all starters + T1 `formulaLog` discoveries (qty from vault, may be 0) instead of vault-qty->0 filter. Synthesis picker unchanged.
- [x] **HomeScreen wiring** — slot Start button passes `slotMode = "extraction"` through `UIController.openScreen("Lab", "extraction")` → `SynthesizeScreen.open(uiController, slotMode)`. `UIController.openScreen` updated to forward varargs.
- [x] **Server-driven load gate** — `PlayerReady` S2C Event added to Manifest. `VaultService.onProfileLoaded` fires it after `fireVaultUpdate`. `ClientInit` replaced `task.defer({ loaded = true })` with `RemoteController.connect("PlayerReady", ...)` so the loading screen holds until vault state is guaranteed on the client.
- [x] **Picker declarative rows** — replaced `Observer/rowsFrame` imperative pattern in `makeVaultBrowser` with `scope:Computed` → `[Children]`; eliminates race where Observer fired before `rowsFrame` was set, leaving picker permanently empty when vault was already populated at open time.
- [x] **Compound display names** — picker rows and slot bar now show `Compounds[id].name` (e.g. "Sodium Chloride ×1") instead of raw IDs; `HomeScreen` gets `Compounds` require; `or id` fallback for unknown IDs.
- [x] **Extraction confirm wired** — `HomeScreen` threads `slotIndex` through `openScreen("Lab", "extraction", slotIndex)`; `SynthesizeScreen.open` gains `slotIndex` param; extraction `onSelect` calls `SlotController.startExtraction` then navigates Home. Synthesis `onSelect` unchanged.
- [x] **Starter extraction unblocked** — `SlotStartExtraction` handler now allows starters (`compoundEntry.starter == true`) to bypass `formulaLog.discovered` check; non-starters still require discovery.
- [x] **SlotController.startExtraction arg fix** — server handler takes only `compoundId`; client was incorrectly passing `(slotIndex, compoundId)` → `slotIndex` landed as `compoundId` → `"invalid args"`. Fixed to pass only `compoundId`; `_slotIndex` kept in signature for future per-slot routing.
- [x] **SlotService state translation fix** — `fireSlotUpdate` and all direct `SlotStateUpdate:FireClient` calls were sending raw `SlotMachine.SlotRecord` objects (no `state` field). Client `HomeScreen` checks `slot.state` → always `nil` → showed `"—"`. Added `toClientSlot(raw)` translator: `workRemaining > 0` → `"RUNNING"`, `== 0` → `"DONE"`, else `"EMPTY"`. Applied to all 3 call sites (tick loop, `fireSlotUpdate`, `applySkipToSlot`). 457/457 tests green.

## In progress

Phase 13 Studio debug pass complete. B1–B6 all resolved. B4 (chambers 7–10) is a Studio place-file change — save the place in Studio to persist it.

## Phase 12D — Lab world build (done in Studio)

Full lab + exterior built as clone-safe BaseParts. Lives at **`workspace.Plots.PLOT_TEMPLATE`** (so `PlotService` finds it) — see `docs/PLOT_TEMPLATE.md` for the full layout. Code↔map contract verified end-to-end: `PlotService` template lookup, `SlotController.getChamberPart` path (`Plots.<userId>.Lab.Chambers.<i>`), and `RevealController` per-chamber SpotLight/PointLight/ParticleEmitter + `WingLight` resolution all resolve. `Burst` emitters configured for the reveal pop.

## Next

- ~~**B4 — Slots 7–10**~~ — fixed in Phase 13: chambers 7–10 added to PLOT_TEMPLATE (must be saved in Studio to persist; `.rbxl` is gitignored).
- **WingLight dim is invisible:** `WingLight` is a Folder-child PointLight (no transform → no light), so the reveal dim has no visible effect. To make it visible: `RevealController` searches recursively + WingLights live on parts. Map currently matches the existing contract.
- ~~**B5 — RevealPrompt inert**~~ — fixed in Phase 13: `SlotController.bindRevealPrompts` wires `Triggered → reveal(i)`, enabled only on DONE slots.
- ~~**Plot overlap (PlotService)**~~ — fixed in Phase 13 (B3): clones now grid-offset via `PivotTo`, players routed to own plot.

## Known issues

- ~~**RevealCard patent timing (12D fix)**~~ — fixed in Phase 13 (B2): `SlotReveal` returns authoritative `isPatent`; `RevealController` reads it instead of polling `StateController.patents`.

## Phase 12C completed (2026-06-15)

- [x] Task 23: PRECIPICE_PHASE12C -- SynthesizeScreen nil vault guard; UIController 0.8s min loading screen; PlotService (PLOT_TEMPLATE clone per player, Plots folder); RevealController (§13 queue + VFX: dim WingLights → spotlight → 3× pulse → particle burst → chamber fade); RevealCard overlay (Keep/Sell + patent WORLD FIRST banner); SlotController.reveal delegates to RevealController; HomeScreen revealQueue HUD counter; ClientInit wires RevealController; 457/457 tests green
- [x] Task 24: PRECIPICE_PHASE12C_FIXES -- vault schema root fix (VaultService sends `data.vault.compounds` not `data.vault`; SynthesizeScreen sort crash resolved; VaultController.getQuantity correct); LoadingScreen fade (TweenService 0.3s bg fade before scope cleanup; duplicate UIController Changed connection removed); HUD overlay (SlotPanel height 200px anchored bottom; "Hide"/"Show Slots" toggle); ✕ close button added to SynthesizeScreen, MarketScreen, FormulaLogScreen, LeaderboardScreen, SyndicateScreen, SettingsScreen; 457/457 tests green

## Open questions

None currently.

## Known blockers

- `lune`/`rokit` require PATH addition on Windows (IR-02): `$env:PATH += ";$env:USERPROFILE\.rokit\bin"`

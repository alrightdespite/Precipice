# PRECIPICE — Implementation Plan v3

> **v3 status note:** v3 adds **Part IV — the Hardening Addendum**: the concrete patterns for every implementation risk I previously flagged as "will surface during Phases 1–4." Each is now specified to the level a Claude Code session implements without guessing. Two of them changed design-doc rules and are adopted there as **Part F (F1–F2)** of v4.6; the rest are pure engineering and live only here. Also verified in this pass: the E5 Prestige blockers cannot soft-lock — §17's cancellation (before second contribution) and 12-hour expiry rules both return the staged compound, and joint runs are time-bounded.

> **v2 status note:** every gap in Part I is now RESOLVED and every ruling in Part II is ADOPTED. The rulings were folded into the artifacts themselves: design doc **v4.5** carries them as Part E (E1–E13) plus the new **Section 31 (The World)**; the economy model gained the **Contract_Pool** and **Catalyst_Economy** sheets; the compound database needed no changes (it validated clean) beyond companion-version references. The R-numbers below map to E-numbers as noted. Part III is unchanged except for Phase 0 and next steps.

**Scope:** This document does three things. Part I reports the independent audit of the v4.4 design doc, economy model, and compound database — what was re-verified clean and what gaps remain. Part II makes a ruling on every gap (delegated judgment calls, per your standing preference — override any you disagree with). Part III is the from-scratch build plan: tooling, workflow architecture that prevents the context-loss / sync / disconnect failures of the first build, the full service and data architecture, the planned PRECIPICE_DOCS structure, and the phase-by-phase implementation order with exit criteria.

**This plan deliberately ignores the original PRECIPICE codebase.** Nothing from it is reused. The old modules embed superseded design (v3-era rules) and the old workflow is the thing being replaced.

---

# PART I — AUDIT RESULTS

## I.1 Independently re-verified (all PASS)

I re-ran every structural check with fresh code rather than trusting the workbook's embedded PASS marks:

| Check | Result |
|---|---|
| Compound counts: 150 total, 30/30/30/25/20/15 by tier | PASS |
| Recipe mappings: 205 total; result-tier density 25/40/50/45/30/15 | PASS (matches doc §7 exactly) |
| Input-class splits: 40 T1+T1→T2, 25 T1+T1→T1, 30 T1+T2→T3, 20 T2+T2→T3, 27 T2+T3→T4, 18 T3+T3→T4, 30 T3+T4→T5, 10 T4+T5→T6, 5 T5+T5→T6 | PASS (matches economy model) |
| Global pair uniqueness; exactly 17 variable pairs, each carrying exactly 2 mappings; variable result tiers 7×T3, 6×T4, 4×T5 | PASS |
| Tier legality of all 205 mappings; zero same-compound authored recipes | PASS |
| BFS reachability of all 150 compounds from the 5 starters | PASS |
| 100% of T1–T5 used as an input ≥1 time; T6 never an authored input | PASS |
| Exotic table: all 120 T6+T6 pairs (105 mixed + 15 same), unique names, values 250k–800k | PASS |
| Value ranges per tier + strict tier value separation | PASS |
| Doc-required names at correct tiers (starters, Zinc Titanate, Zinc Salt, Zinc Polymer, Cascade set) | PASS |

Economy cross-checks re-derived by hand:

- Residue economics: net failure costs 10/45/15/110 — arithmetic confirmed.
- Joint declaration net cost 410 (500 − 6×15) — confirmed.
- §17's "~355,000 Pellets to map all ~710 pairs" is gross fees (710 × 500); the model's 292,450 is net of residue. Both consistent; no error.
- 710 joint candidates = 500 (T4×T5) + 190 (C(20,2)) + 20 (T5 same-compound declarations) — confirmed.
- Exotic decay floor: 0.97^45 = 0.2539 > 0.25, 0.97^46 = 0.2463 < 0.25 → floor at unit 46 / run 23. Doc says "~24 runs (48 units)"; the "~" covers it. Fine.
- Defense windows: T2 360 online completions (72h ÷ 0.2h), T6/T7 = 7 — confirmed.
- §10 worked offline-income example: 40 + 1,971 + 2,826 + 600 = 5,437 — confirmed. (This example becomes a literal unit test — see Phase 1.)
- Rank model: Chief Scientist crossing at cumulative 250,255 on day 84 — confirmed against the 85–90 target.
- 435 T1+T1 pairs = C(30,2) — confirmed.

**Verdict on the artifacts:** the design layer is in genuinely good shape. The v4.4 audit chain did its job. The remaining problems are not in the rules — they are in the seam between the rules and a real Roblox server architecture, plus a small number of states the doc never addresses.

## I.2 Gaps found

Fourteen items, three categories. **All fourteen are resolved in v4.5** — the original severity tags are kept for the record. Mapping: G1→E1, G2→E2, G3→E3, G4→E4, G5→E5, G6→E6, G7→E7, G8→E8, G9→E9, G10→E10, G11→E11, G12+G14→E12, G13→data-design note in 02_DATA_SCHEMA (no rule change needed), plus E13 (stale C36 architecture note, found during the fix pass).

### Category A — Doc contradictions / platform-reality conflicts

**G1 🔴 Timer persistence model contradicts the online speed bonus (§8 vs §9).**
§8: "The timer end time is permanently saved and any server resumes it correctly." §9: production runs 20% slower while offline. Both cannot be literally true — a fixed saved end-timestamp cannot change rate when the player logs out. If implemented as written in §8, the offline slowdown silently never happens (or worse, is double-applied by a patch later). This is exactly the kind of trap that produced bugs in the first build.

**G2 🔴 "The instant" challenge triggers are unimplementable for decay-driven challenges (§15).**
A challenge triggers "the instant" a rival's 30-day count surpasses the holder's — "whether by the challenger synthesizing or by the holder's old runs decaying out." Synthesis-driven triggers can be event-driven (evaluate on every natural completion). Decay-driven triggers have no event: counts change as wall-clock time passes with nobody doing anything. Something must sweep. The doc never defines the evaluation cadence, and "instant" is physically impossible.

**G3 🔴 Long-running servers crossing the Monday boundary (§21, §7, §15).**
The only reset mechanism defined is "first server to start after Monday midnight handles the reset." Roblox servers routinely run for days. A server started Sunday evening with players on it crosses midnight live: those players would see the stale seed, stale Sprint, and unpaid dividends until that server happens to die. The Monday order of operations (dividends → Sprint reset → seed reroll) needs a live-rollover mechanism, not just a boot-time check.

**G4 🟡 "Your own rank always visible" vs OrderedDataStore reality (§21).**
OrderedDataStore can return sorted pages but cannot answer "what is player X's exact rank" without paging the entire board. At thousands of players, computing an exact rank for every viewer is not viable. The UI promise as written cannot be kept at scale.

**G5 🔴 Prestige vs in-flight production is completely unspecified (§22).**
The reset table covers market listings and PendingCredits but says nothing about: (a) personal slots currently running, (b) completed-but-unrevealed slot results, (c) your compound staged in a joint slot awaiting a partner, (d) a running joint run you contributed to (your compound already consumed; result due in hours). Every one of these is a silent-value-loss or dupe vector if handled ad hoc.

**G6 🟡 Whether the prestiging player's own 30-day counts survive is implied, never stated (§15/§22).**
D4 says "nobody's 30-day counts reset on release" — about rivals. The prestiging player's own counts are never addressed. (They should survive: they're history, not Formula Log. The natural brake is that the prestiger can't synthesize anything until they rediscover recipes.)

**G7 🟡 Market bounds vs Exotic decay at purchase time (§16/§23).**
§23 says the 80%/500% bounds reference current value "at the moment of listing or sale." Exotic decay moves base value down, so a legally created listing can drift above 500% of current base while listed. If bounds are enforced at sale, legal listings become unbuyable and strand. Note the anti-transfer purpose is unaffected by enforcing at creation only: the transfer exploit uses the *floor* (underpricing), and decay pushes a fixed price *away* from the floor, never toward it.

**G8 🟡 Daily contract generation for offline players (§19).**
"Drawn at midnight UTC" — an offline player has no server to draw them on. Needs a lazy-generation ruling that preserves "no mid-day rerolls."

### Category B — Content/spec gaps (things that must exist before code can be written)

**G9 🔴 The contract pool is not enumerated anywhere.**
§19 gives 8 examples and reward *ranges*. ContractService needs the full authored pool: every contract template, its parameters, difficulty, exact reward values, and its filter predicate. ~20–30 templates. This is a content-authoring task, not a design flaw — but it blocks Phase 6.

**G10 ⚪ The Catalyst economy is the only currency with zero model coverage.**
Free earn at steady state ≈ 1 Catalyst/week (streak) + 5 per world-first (finite: 240 ever) + 25 per event milestone. Costs: 30/skip, 200/syndicate expansion, 20–200 cosmetics. Free Catalysts are effectively cosmetic-savings-only over months. Probably intended for a premium currency — but §30 doesn't even flag it for tuning, and the economy model has no Catalyst sheet. Add it to Tuning_Flags; no design change now.

**G11 🔴 The spatial/world model is entirely undefined — the single biggest unanswered question.**
The doc reads UI-first ("tap a slot"), but the reveal sequence references a physical synthesis wing, chambers, spotlights, dimming lights; cosmetics are lab skins and particle sets. Nowhere does the doc say: how many players per server, whether each player has a physical lab, whether it's plots / private instancing / one shared room, whether other players are visible, what the camera model is, or whether this is mobile-portrait-first or desktop-first. Every hour of map/VFX/UI work depends on this decision. **Resolved:** decided and adopted as design doc Section 31 (plot-based shared servers, 8 players, chambers-are-slots; full text in the doc).

### Category C — Concurrency/architecture rulings the doc leaves to implementation

**G12 ⚪ Announcement transport.** Cross-server world-first broadcasts → MessagingService, one topic, server-side queue honoring the doc's 30-second gap. PublishAsync quotas are fine at this volume. Plan it; no design issue.

**G13 🟡 "X players were actively synthesizing" (§13/C34)** requires global per-compound, per-player, 7-day completion data at reveal time. Derivable from the patent count store, but only if the data design includes it from day one — it cannot be bolted on later without a backfill problem.

**G14 🟡 Atomicity rulings:** simultaneous purchase of one market listing; two syndicate members mutating the same joint slot from different servers; two joint runs completing the same brand-new Exotic near-simultaneously (§13 already acknowledges the race; the *resolution* must be an atomic claim). All three need a named concurrency pattern, not good intentions.

---

# PART II — RULINGS (ADOPTED — now design doc v4.5 Part E)

All thirteen rulings below are adopted and live in the design doc as Part E. `docs/RULINGS.md` at Phase 0 starts as a pointer to Part E and grows only with *future* implementation deltas.

**R1 (closes G1) — Work-units timer model.** A run is persisted as `{ compoundId, workRemaining (seconds at online rate), lastTickAt (unix), mode }` — never as a fixed end timestamp. The effective rate is 1.0 while the owner is present, 0.8 while absent (1.25× duration). `workRemaining` is settled (decremented by elapsed × rate) on: presence transitions, profile save, slot interaction, and load. Completion time displayed to the client is derived, not stored. §8's sentence is reworded in RULINGS to: "the run's remaining work is permanently saved and any server resumes it correctly." Stabilized Synthesis multiplies initial work by 1.5; T6/T7 joint runs use rate 1.0 always (online bonus exempt per §9).

**R2 (closes G2) — Challenge evaluation cadence.** Challenge conditions are evaluated (a) event-driven, on every natural completion of a compound, against that compound's holder, and (b) by a global decay sweep run by the singleton job scheduler every **15 minutes**, which re-evaluates every held patent whose holder lead is non-huge (cheap pre-filter: skip compounds where holder lead > max possible rival completions in 15 min). "The instant" in §15 is defined as "within one sweep interval." Defense-window expiries are processed by the same sweep plus a lazy check on any access to the patent record. 15 minutes is invisible at every tier — the shortest defense window is 72 hours.

**R3 (closes G3) — Live Monday rollover.** Every server runs a ClockService that checks UTC each minute. On detecting a boundary crossing (Monday 00:00 for the weekly set; any 00:00 for daily), it attempts to acquire a global lock (DataStore `UpdateAsync` on a `GlobalJobs` key with epoch-stamped ownership and a TTL). The winner executes the Monday sequence in the doc's mandated order — 1) dividends, 2) Sprint archive+reset, 3) seed reroll — writes the new epoch marker, and broadcasts `EpochChanged` via MessagingService. All servers also poll the epoch marker every 5 minutes as the MessagingService-loss backstop. Boot-time detection remains as a second backstop. The weekly seed itself is **deterministic from the ISO week number + a secret salt** (HMAC-style), so even a server that misses every signal computes the correct active variants locally — the stored marker exists only to coordinate the side-effectful jobs (dividends, archive), which are idempotent via the epoch stamp.

**R4 (closes G4) — Rank display ruling.** Top 50 (Sprint) / Top 100 (Chief's Board) are exact, from OrderedDataStore pages. Your own row always shows your **score**; your **exact rank** is shown only if you appear within the first 10 pages (top ~1,000); beyond that the row reads "Top N%" estimated from a sampled score distribution refreshed hourly by the singleton job. The §21 UI promise is softened accordingly in RULINGS. The alternative (full-board scans per viewer) is rejected on request-budget grounds.

**R5 (closes G5) — Prestige in-flight blockers.** The Prestige button is **disabled** while any of the following is true, and the confirmation screen lists exactly which: (a) any personal slot is running, (b) any slot holds an unrevealed result, (c) the player has an active joint staging (staged compound not yet matched), (d) the player is a contributor to a running joint run. Rationale: auto-resolving any of these silently destroys or duplicates value and generates support disputes; blocking costs the player at most 24 hours of finishing what they started, on an action they take a handful of times per year. Listings/PendingCredits keep the §22 auto-resolve because the doc already rules them.

**R6 (closes G6) — 30-day counts survive Prestige.** They are historical natural-completion records, not Formula Log entries. Stated explicitly. (Composes correctly: the prestiger keeps standing in races but cannot produce until rediscovery — the intended brake.)

**R7 (closes G7) — Bounds enforced at listing creation only.** A listing legal at creation remains purchasable for its full 7-day life regardless of Exotic decay. The purchase confirmation always shows current base value beside the asking price. Anti-transfer integrity is unaffected (decay moves prices away from the exploitable floor).

**R8 (closes G8) — Lazy daily contract generation.** Contracts are generated on the player's **first login of each UTC day** (or at midnight if online), filtered by state at that moment, then frozen — preserving "no mid-day rerolls" exactly. A player who doesn't log in simply has no contracts that day, which matches the doc's intent (contracts measure active sessions).

**R9 (closes G9) — Contract pool authoring task.** A `CONTRACT_POOL.md` data table is authored during Phase 0 docs work: ~24 templates (8 Easy / 8 Medium / 8 Hard) with parameterized targets, fixed rewards within the §19 ranges, and explicit filter predicates per D9/D20. **Done:** the 24-template pool (8/8/8 by difficulty, all rewards inside §19 bands, filters per D9/D18/D20) plus the draw rule now lives in the economy model's Contract_Pool sheet; expected all-five daily rank ≈ 390, range 225–525, matching §19's stated band.

**R10 (closes G10) — Catalyst economy flagged.** Added to Tuning_Flags as "unmodeled — premium currency intentionally scarce free; revisit free-earn rates if telemetry shows Catalyst-gated features (joint acceleration, syndicate expansion) have near-zero engagement from non-payers." No change now.

**R11 (closes G11) — World model (ADOPTED — design doc Section 31).**
**Plot-based shared servers.** Server size 6–8 players. Each player spawns into an identical pre-built lab interior on their own plot; the plot's physical synthesis chambers ARE the player's slots (chamber count tracks slot count; locked chambers visibly present, dark). Reveal VFX plays at the chamber. Other players' labs are visible at a distance / walkable (social proof, syndicate recruiting, ambient life in TikTok clips). Third-person camera, default Roblox controls, full mobile support with the entire game also operable from the HUD (every chamber interaction has a 2D equivalent — the UI is the game; the world is the stage). One lab interior is built once and instanced per plot. Rationale: this is the cheapest model that makes the reveal moment filmable *in a world* rather than as a flat UI, keeps the social layer ambient, and bounds map work to one interior + one exterior shell. Rejected alternatives: single shared room (reveals collide, no ownership feeling), full private instancing (kills ambient social, no recruiting surface, more teleport plumbing).

**R12 (closes G13) — Recent-completers data.** The patent count store records, per compound, a rolling list of `{userId, timestamp}` natural completions (it must anyway, for the 30-day window). The "actively synthesizing" figure = distinct userIds with a completion in the last 7 days who have the recipe discovered — computed from the same structure at claim time. No separate store.

**R13 (closes G14) — Concurrency patterns, named once, used everywhere:**
- **Market purchase:** `UpdateAsync` compare-and-set on the listing record (state must be `ACTIVE`); loser receives "already sold." Buyer debit reserved first, refunded on CAS failure.
- **Joint slot mutations:** all writes go through `UpdateAsync` on the syndicate record with a state-machine guard (`EMPTY → STAGED → MATCHED → RUNNING → COMPLETE`); illegal transitions rejected and surfaced.
- **World-first / Exotic-first claims:** `UpdateAsync` on the patent record; first writer wins; losers get the §13 "moments before you" path. Never decided in MemoryStore — DataStore is the arbiter of firsts.
- **PendingCredits:** append-only `UpdateAsync` on a dedicated per-user key, never touching the (possibly session-locked) main profile of an offline player; drained transactionally at login.

---

# PART III — THE BUILD PLAN

## III.1 Why the first build hurt, and the architecture that removes each failure

Three root causes, three structural fixes:

**Failure 1: the chat relay.** claude.ai wrote prompts → you pasted into Claude Code → details died in the copy. The integration point was a human clipboard, and the source of truth was chat history — which rots, truncates, and resets between sessions.
**Fix:** kill the relay entirely. The design is finished; claude.ai's prompt-writing role is over. **The repo is the only source of truth.** Every spec, ruling, schema, and status fact lives in files Claude Code reads directly. claude.ai (or Claude Desktop) is used only for design-level discussion and spreadsheet edits — never as a pipe in the build loop.

**Failure 2: two sources of truth for the game tree.** Argon two-way sync plus Weppy live-mutating the DataModel meant the filesystem and Studio could disagree, and when sync hiccupped you couldn't tell which side was right (the 27-RemoteEvents incident is the canonical symptom).
**Fix:** one-way sync, one direction, forever. The filesystem owns all code and all logic-relevant instances; Studio owns only the map and 3D/VFX assets. And critically: **zero authored instances for game logic** — every RemoteEvent/RemoteFunction, every runtime folder, is created by server code at boot from a single manifest module. There is nothing for a sync tool to lose, because remotes never exist as synced instances at all.

**Failure 3: load-bearing fragile bridges.** Weppy disconnects mattered because Weppy was in the critical path.
**Fix:** demote MCP bridges to conveniences. The critical path is `git → rojo serve → Studio` for code, and `lune run tests` (no Studio at all) for logic verification. If the MCP bridge dies mid-session, nothing is lost.

## III.2 Toolchain decisions (researched against the current landscape)

| Concern | Decision | Why |
|---|---|---|
| File→Studio sync | **Rojo 7, one-way (`rojo serve`)** | Still the de-facto standard and the most reliable tool for the one direction we need. Argon's value proposition is two-way sync — which this architecture deliberately doesn't use, and which is where your reliability problems lived. (Argon is Rojo-project-compatible if you ever want its QoL features; keep the project file Rojo-spec.) |
| Toolchain pinning | **Rokit** (`rokit.toml`) | Pins rojo/stylua/selene/lune/wally versions in-repo so Claude Code sessions are reproducible across machines and months. |
| Packages | **Wally** | ProfileStore (session-locked player data), Promise, Signal, t (runtime type checks for remote payloads). |
| Headless tests | **Lune** + a thin spec runner; MockDataStore-style fakes for DataStore/MemoryStore | The single biggest velocity unlock: ~70% of PRECIPICE is pure logic (economy math, recipe resolution, patent windows, decay, rank, offline income). Claude Code runs the test suite itself, in seconds, with no Studio and no MCP. The agent's loop closes without you. |
| Lint/format | **Selene + StyLua**, run by Claude Code pre-commit | Catches the dumb stuff before it reaches Studio. |
| Studio MCP bridge | **Weppy, demoted to convenience tier** (or Roblox's reference MCP — note it's now archive/reference status) | Used for: reading DataModel state while debugging, automated playtest kicks, occasional Studio-side asset queries. Never for creating logic instances, never for sync. Disconnects become a non-event. |
| Data pipeline | **`data/gen/export_data.py`** (Python, since your validation tooling is already Python) | Reads PRECIPICE_COMPOUND_DATABASE.xlsx → emits `src/shared/Data/{Compounds,Recipes,Exotics,EventCompounds,TierConstants}.luau` + re-runs all structural assertions on every export. The xlsx stays authoritative; generated Luau is never hand-edited (header comment says so). EconomyConstants.luau (fees, dividends, windows, prestige costs, rank values) is hand-authored once from the economy model with a checksum comment tying it to the model version. |
| Version control | **Git, fresh repository** (`precipice` clean, or an orphan branch) | Do not build on the old repo's history — old modules embed superseded v3-era rules and will leak into context. Archive the old repo; start clean. |
| Place file | One `PRECIPICE.rbxl` containing the map; Rojo serves code into it (partially-managed project) | Fully-managed (`rojo build` from zero) is purer but makes Studio-built maps miserable for a solo dev. Partially-managed is the pragmatic standard: Studio owns `Workspace` (map), Rojo owns `ServerScriptService`, `ReplicatedStorage`, `StarterPlayer`, `StarterGui` code trees. |
| CI (later, optional) | GitHub Actions: lune tests + selene on push; Open Cloud place publish for a test universe | Phase 11 concern. Not needed to start. |

## III.3 Repository layout

```
precipice/
├─ default.project.json        # Rojo project (partially managed)
├─ rokit.toml                  # pinned: rojo, lune, stylua, selene, wally
├─ wally.toml                  # ProfileStore, Promise, Signal, t
├─ stylua.toml / selene.toml
├─ CLAUDE.md                   # ≤150 lines; see III.6
├─ docs/                       # PRECIPICE_DOCS — see III.5
├─ data/
│  ├─ PRECIPICE_COMPOUND_DATABASE.xlsx
│  ├─ PRECIPICE_ECONOMY_MODEL.xlsx
│  └─ gen/export_data.py       # xlsx → Luau + assertions
├─ src/
│  ├─ shared/
│  │  ├─ Data/                 # GENERATED — never hand-edit
│  │  ├─ Config/               # EconomyConstants.luau, GameConfig.luau
│  │  ├─ Types/                # Luau type defs for profile, remotes, records
│  │  ├─ Remotes/Manifest.luau # the single remote registry (name, direction, payload type, rate limit)
│  │  └─ Core/                 # PURE logic, no Roblox globals: TimerMath, OfflineIncome,
│  │                           #   RecipeResolver, SeedResolver, PatentWindow, ExoticDecay,
│  │                           #   RankMath, FeeMath, MarketMath, PrestigeRules
│  ├─ server/
│  │  ├─ GameInit.server.luau  # boot order; owns ALL PlayerAdded wiring
│  │  └─ Services/             # one file per service (III.4)
│  └─ client/
│     ├─ ClientInit.client.luau
│     ├─ Controllers/          # one per system
│     └─ UI/                   # one folder per screen (III.4 screen list)
├─ tests/
│  ├─ mocks/                   # MockDataStore, MockMemoryStore, MockMessaging, FixedClock
│  └─ specs/                   # mirrors src/shared/Core + service logic
└─ map/
   └─ ASSET_LIST.md            # every model/VFX/SFX needed, status-tracked
```

The `src/shared/Core` ↔ `src/server/Services` split is the testability contract: **Core modules are pure** (take state in, return state/decisions out, clock injected) and carry the entire rule weight of the design doc; **Services are thin adapters** that wire Core to DataStores, remotes, and the world. Lune tests hammer Core exhaustively; Services get integration tests in Studio.

## III.4 Architecture inventory

### Server services (24)

| Service | Responsibility (one line) |
|---|---|
| **DataService** | ProfileStore session-locked profiles, schema version + migrations, save cadence, PendingCredits drain at login |
| **RemoteService** | Creates every remote at boot from `Remotes/Manifest`, attaches payload validation (`t`) + per-remote rate limits; the only module that touches remote instances |
| **ClockService** | UTC boundaries, minute tick, Monday/daily epoch detection (R3) |
| **GlobalJobService** | Cross-server singleton lock; runs dividends → Sprint reset → seed epoch → decay sweep (R2) → rank-distribution sampling (R4); all jobs idempotent via epoch stamps |
| **SlotService** | Personal slot state machine, work-units model (R1), start/cancel/skip, reveal handoff, Prestige blockers (R5) |
| **IncomeService** | Online accrual tick, offline settlement per §10 (per-slot remaining-time rule, floor rule, cap rule) |
| **VaultService** | Inventory add/remove, residue stacking, instant sell (incl. live Exotic valuation) |
| **LabService** | Analysis flow: fee brackets, validity, discovery grant, residue, failed-pair log, Rush Analysis arming, Lab refusal rules (joint-tier pairs, Exotics) |
| **RecipeService** | Static lookups over generated data; variable-pair resolution via SeedResolver; Stabilize legality |
| **MarketService** | Listing CRUD with bounds (R7), fees, 7-day expiry-to-vault, atomic purchase (R13), PendingCredits payout, per-compound stats/badges |
| **PatentService** | 30-day count store, claim flow + once-ever package, challenges/windows/immunity/queue, expiry resolution (multi-party ruling), decay projections, reclaim custody, dividends data |
| **SyndicateService** | Create/invite/kick/roles/rename/disband, communal vault + upgrades, member cap expansion, founder succession, name filtering (TextService) |
| **JointSynthService** | Declaration staging + joint analysis fees + Validated marks, sync/async modes, 12h expiry + 6h cooldown, Accelerated flag consent, completion fan-out (both members: unit, recipe, counts, rank/Sprint/Flux per D13–D15), qualification gate |
| **ExoticService** | Seed-table lookup on first completion, global unit counters (atomic), live decayed valuation, Exotic Registry feed |
| **RankService** | Current-run + lifetime scores, all sources, daily caps (market 1,000 / vault 500), title resolution, Prestige gate check |
| **SprintService** | Weekly Sprint tally, OrderedDataStore writes, archive + champion badges |
| **LeaderboardService** | Sprint top-50 + Chief's top-100 reads, own-row resolution (R4) |
| **ContractService** | Lazy daily generation (R8) from the authored pool (R9) with state filters, progress tracking (skipped runs count), rewards |
| **StreakService** | 36-hour window, milestone rewards, countdown data |
| **PrestigeService** | Blocker evaluation (R5), pre-reset steps (cancel listings, pay PendingCredits), reset execution, patent release fan-out, bonus application |
| **MonetizationService** | Gamepass cache, dev product receipts (idempotent ProcessReceipt), Catalyst wallet, TimerSkip routing, Rush inventory, CompoundArchive monthly grants |
| **EventService** | Event lifecycle, Flux earning (rank-mirrored + extraction cap, caps-after-multipliers), blueprints, community milestone, event patents (first-run vs re-run modes), 1.5× income flag |
| **CosmeticService** | Catalog, purchase (Pellet/Catalyst sinks), equip state, Void preview/unlock |
| **AnnouncementService** | MessagingService topic, 30-second-gap queue, tier-scoped routing (first-claim global / transfer T4+) |
| **AnalyticsService** | The §30 telemetry commitments as code from day one: days-to-Chief, Prestige run lengths, challenge volume per tier, dividend vs sink totals, faucet/sink counters |

### Client controllers + screens (the UI surface, enumerated)

Controllers: SlotController, RevealController (queue, 0.5s gaps, patent sequence), LabController, MarketController, PatentLogController, SyndicateController, JointSlotController, RankHUDController, LeaderboardController, ContractController, StreakController, PrestigeController, ShopController, EventController, AnnouncementController, HintController (C2/C3 contextual prompts), LoadingController.

Screens (each gets a spec section in `docs/ui/SCREENS.md`):
1. Loading screen (§26)
2. Home / slot panel (slots, contracts strip, streak countdown, contextual prompt, milestone bar during events)
3. Extraction picker
4. Synthesize screen (context-aware button table §11, variant panel, Stabilize toggle, Rush-armed state)
5. Reveal card (+ patent overlay, queued counter)
6. Vault
7. Market (browse/stats/badges, listing creation w/ fee disclosure, my listings)
8. Formula Log (indicators per §15, decay projection, Validated marks, Exotic Registry section, event silhouettes)
9. Syndicate (roster/roles, vault + upgrades, joint slots w/ staging & Accelerated flagging & async windows)
10. Leaderboards (Sprint + Hall of Fame, Chief's Board)
11. Prestige flow (overlay → blockers → double confirm)
12. Shop (gamepasses, dev products, Catalysts, cosmetics tabs)
13. Event hub (Flux, blueprints, pass)
14. Profile (titles, badges, lifetime vs current-run, patent portfolio)

This list exists so nothing gets "discovered" mid-build — UI is realistically ~half the total effort.

### Data architecture (summary — full schema is a Phase 0 docs deliverable)

**Player profile (ProfileStore, versioned `schemaVersion`):** balances {pellets, catalysts}; vault {compoundId→count, residue}; formulaLog {discovered{}, validatedPairs{}, failedPairs{}}; slots[] (R1 records); rank {currentRun, lifetime, dailyCaps{}}; sprintPoints (weekly epoch-tagged); streak; contracts (day-tagged); prestige {level}; jointQual (bool, lifetime); monetization {gamepasses cache, rushUses, archiveUsesByMonth, receiptLedger}; cosmetics {owned, equipped}; eventState {fluxBySeason, blueprintsOwned}; counters/stats.

**Global stores (DataStore):**
- `Patents` — per compound: {firstClaimant, firstClaimDate, holder, challenge{challenger, windowEnd, queue[]}, immunityUntil}. Firsts decided here, atomically (R13).
- `SynthCounts` — per compound: rolling {userId, timestamp} natural completions, pruned >30d on write; serves 30-day counts, decay projections, and the 7-day "actively synthesizing" figure (R12). Sharding plan for hot compounds documented in DATA_SCHEMA.
- `MarketListings` — per listing record + MemoryStore sorted-map index for browse; DataStore is truth, MemoryStore is cache.
- `Syndicates` — membership, roles, vault balance, upgrades, joint slot state machines.
- `Exotics` — per Exotic: generated?, unitCount (atomic increments), firstPair.
- `PendingCredits` — per user, append-only (R13).
- `GlobalJobs` — locks, epoch markers, sampled rank distribution.
- OrderedDataStores: `Sprint_{epoch}`, `ChiefBoard`.
- `EventState` — season, milestone progress, target.

**MemoryStore:** market browse index, announcement queue, presence/cross-server hints. Rule: MemoryStore is never the arbiter of anything permanent.

## III.5 PRECIPICE_DOCS — planned structure (not built yet, per your instruction)

```
docs/
├─ 00_INDEX.md            # one-paragraph map of everything below
├─ 01_ARCHITECTURE.md     # service inventory, boot order, Core/Service split, remote pattern, concurrency patterns (R13)
├─ 02_DATA_SCHEMA.md      # full profile schema, every global store, MemoryStore maps, migration policy, sharding notes
├─ 03_REMOTES.md          # the manifest in prose: every remote, direction, payload type, rate limit, validation, which service owns it
├─ 04_RULINGS.md          # R1–R13 + every future implementation ruling; THE delta log vs design doc v4.4
├─ 05_TESTING.md          # lune harness, mocks, the "doc examples as tests" list (§10 example, decay floor, fee tables, defense windows…)
├─ 06_WORKFLOW.md         # session protocol, commit rules, STATUS discipline, task sizing
├─ STATUS.md              # THE LEDGER: current phase, done, in-progress, next task, open questions — updated every session
├─ specs/                 # one per service, ≤400 lines each, SELF-CONTAINED:
│  │                      #   responsibility · owned state · public API · remotes · edge cases
│  │                      #   (each citing its design-doc § numbers) · test checklist
│  ├─ SlotService.md, IncomeService.md, LabService.md, MarketService.md,
│  ├─ PatentService.md, SyndicateService.md, JointSynthService.md, … (×24)
├─ ui/
│  ├─ SCREENS.md          # all 14 screens, every element, § references
│  └─ FLOWS.md            # reveal queue, prestige confirm, joint staging consent, NPE sequence
└─ data/
   ├─ CONTRACT_POOL.md    # the R9 authored table (~24 templates)
   └─ WORLD_MODEL.md      # the R11 decision record + plot/lab layout spec
```

Design principle for the specs: **a Claude Code session must be able to implement a service from its spec + CLAUDE.md alone**, with zero chat history and without reading the 200KB design doc. Each spec quotes the exact numbers it needs (with § citations for traceability) rather than referencing them. The design doc remains the source of truth for *design*; the specs are the source of truth for *implementation*; RULINGS.md is the bridge where they differ.

When we build these (next step after you approve this plan): generate them in dependency order, and each spec gets a verification pass against the doc + workbooks before it's marked authoritative in STATUS.md.

## III.6 The session protocol (the context-loss killer)

**CLAUDE.md contents (≤150 lines, strictly):** project one-liner; repo map; commands (`rojo serve`, `lune run tests`, `python data/gen/export_data.py`, lint); the five iron rules below; pointer to docs/00_INDEX.md and STATUS.md. CLAUDE.md is a router, not a knowledge base — knowledge lives in docs/.

**The five iron rules (verbatim into CLAUDE.md):**
1. Read `docs/STATUS.md` and the relevant `docs/specs/*.md` before writing any code. Never implement from memory of a previous session.
2. One task per session. A task is one spec section or smaller. If a task looks bigger, split it in STATUS.md first.
3. Tests green before done. New Core logic ships with lune specs; the §-cited doc examples are mandatory test cases.
4. End every session by updating STATUS.md (done / next / open questions) and committing with a descriptive message. Git history is the long-term memory; STATUS.md is the working memory.
5. Never hand-edit `src/shared/Data/*` (generated) and never create remotes as instances (manifest only).

**Session lifecycle:** start Claude Code in repo root → it reads CLAUDE.md automatically → "Implement {spec §}. Plan first." → review plan → execute → tests → STATUS update → commit → **end the session**. Start fresh for the next task. Long sessions are the enemy; the repo, not the conversation, carries state between them. Use plan mode for anything touching more than two files; use a subagent for "audit X against its spec" passes so the audit doesn't pollute the implementation context.

**claude.ai's remaining role:** design conversations, spreadsheet work, and reviewing rulings — that's it. If a design question comes up mid-implementation, Claude Code writes it into STATUS.md "open questions"; you resolve it (with claude.ai if you want), the answer lands in RULINGS.md, implementation resumes. Decisions flow through files, never through pasted prompts.

## III.7 Phase plan

Ordering rationale: logic-heavy, UI-light systems first so the Lune harness carries maximum weight early; Patents before Syndicates because joint completions hook into patent counting; the world/VFX last because it's the only genuinely Studio-bound work and blocks nothing.

**Phase 0 — Foundation** *(everything else depends on this; do not shortcut it)*
Repo init, Rokit/Wally/Rojo/Lune toolchain, lint configs. Data pipeline: export_data.py + generated Luau + assertions re-run. Remotes manifest + RemoteService. ClockService + GlobalJobService skeleton (lock pattern proven with a no-op job). DataService with ProfileStore + schema v1 + MockDataStore tests. Write CLAUDE.md + docs skeleton + the 6 core docs + STATUS.md. Port the contract pool (economy model Contract_Pool sheet) into docs/data/CONTRACT_POOL.md and the world model (design doc §31) into docs/data/WORLD_MODEL.md — both already authored, this is transcription.
*Exit:* `lune run tests` green on data integrity + lock + profile round-trip; `rojo serve` syncing into a stub place; STATUS.md live.

**Phase 1 — Core loop vertical slice**
TimerMath + OfflineIncome in Core (R1, §9, §10 incl. floor + cap rules). SlotService, IncomeService, VaultService, instant sell. Extraction end-to-end. Minimal Home UI + extraction picker + reveal card (no VFX polish). Loading screen data-gate (§26).
*Exit:* playable extract→reveal→sell loop in Studio; the §10 worked example (= 5,437) passes as a literal unit test; offline completion across a simulated server restart passes.

**Phase 2 — Discovery & synthesis**
RecipeResolver + SeedResolver (deterministic weekly seed, R3) in Core. LabService (fees, residue, failed-pair log, refusal rules, discovery grant counts-for-nothing), synthesis runs, Stabilized synthesis, cancel rules (§8). Synthesize screen with the full §11 button-state table and variant panel.
*Exit:* every row of the §11 button table reproduced by tests; fee/residue tables encoded as tests; variable-pair behavior verified across a simulated seed flip.

**Phase 3 — Market**
MarketMath in Core (bounds R7, fees). MarketService with atomic purchase (R13), expiry-to-vault, PendingCredits, stats/badges, rank-from-sales with the 1,000/day cap. Market screen.
*Exit:* concurrent-purchase test (two simulated buyers, one listing) deterministic; PendingCredits delivered across login; fee math tests green.

**Phase 4 — Patents** *(the hardest system; budget accordingly)*
PatentWindow in Core (30-day pruning, challenge predicates, expiry resolution, immunity, queue re-validation). PatentService: SynthCounts store, claim atomicity, once-ever package, dividends job (Monday order R3), decay sweep (R2), reclaim custody, announcements (scoping + 30s queue). Formula Log screen with all five indicator states + decay projection.
*Exit:* a scripted multi-party race scenario (holder, named challenger, third-party overtake, tie) resolves per §15 in tests; dividend timing rulings (C17) encoded as tests; sweep + event-driven triggers both proven.

**Phase 5 — Syndicates, Joint Synthesis, Exotics**
SyndicateService (full role matrix §17, vault, upgrades, succession, disband disclosure). JointSynthService (declaration staging state machine, joint analysis + Validated marks D17, async window/expiry/cooldown, Accelerated consent flow, completion fan-out paying both members everything per D13–D15, opener conventions D16). ExoticService (table lookup, atomic unit counters, decay valuation live in instant sell + market, Registry). Syndicate screens.
*Exit:* state-machine tests cover every joint transition incl. cross-server contention (R13); both-members fan-out verified for units/recipes/counts/rank/Sprint/Flux; first-completion Exotic race resolves atomically.

**Phase 6 — Progression & engagement**
RankService (all sources, caps, titles, current vs lifetime D6). SprintService + LeaderboardService (R4). ContractService from CONTRACT_POOL.md (filters D9/D20, skipped-runs-count rule). StreakService (36h window, milestones). Leaderboard + profile screens, contracts strip, streak countdown.
*Exit:* rank-source matrix tests (every source × cap × natural-only rules); Sprint archives + badges across a simulated Monday; contract filtering tested against synthetic player states.

**Phase 7 — Prestige**
PrestigeRules in Core. PrestigeService: blockers (R5), pre-reset steps (C19), the full §22 reset table, bonus application, patent release fan-out, announcement. Prestige flow UI.
*Exit:* the §22 reset table encoded as one table-driven test (every row asserted); blocker matrix tested; release→reclaim→instant-challenge composition (D4) verified.

**Phase 8 — Monetization**
MonetizationService: gamepasses (slot cap math C35, offline cap), dev products with idempotent receipts, Catalyst wallet, TimerSkip + Catalyst skip (Natural Completion flags everywhere), Rush Analysis (D5/D18 boundaries), CompoundArchive monthly grants. Shop screens. Skip-consequence labeling (§14 UI rule).
*Exit:* receipt replay test (duplicate ProcessReceipt) grants once; every skip path verified to deliver-but-not-count across patents/Sprint/rank/Flux; archive month rollover tested.

**Phase 9 — Seasonal events**
EventService: Cascade lifecycle, Flux (rank-mirrored, extraction cap, caps-after-multipliers D8), blueprints, community milestone (telemetry-set target), event patents (first-run permanence vs re-run contested modes §29), event pass effects, 1.5× income. Event hub UI.
*Exit:* event patent mode transitions tested (first run → gap → re-run → gap); Flux cap-vs-multiplier ordering tested; milestone payout via PendingCredits to offline players tested.

**Phase 10 — World, VFX, polish**
Map build per WORLD_MODEL.md (lab interior, plots, exterior shell). Reveal VFX tiers + patent sequence + queued reveals. Cosmetics application (skins/particles/HUD accent/stamps), Void preview. SFX. NPE/contextual hints (§27, C2/C3). Mobile UI pass on every screen.
*Exit:* the 15-second-vertical-video test — a reveal filmed on a phone reads with zero explanation; NPE walked end-to-end by a fresh account.

**Phase 11 — Hardening & launch**
AnalyticsService wired to every §30 commitment. Anti-exploit audit: every remote validated, every economy mutation server-authoritative, rate limits tuned. Load behavior: DataStore/MemoryStore budget review at target server size. Soft-launch checklist: private test universe via Open Cloud publish, telemetry dashboards, the §30 standing checklist run against the shipped build.
*Exit:* a written launch-readiness review against §30; no remote accepts unvalidated payloads; budget math documented.

## III.8 What you should do in what order (immediate next steps)

1. **Read design doc v4.6's Parts E–F and Section 31** — that's where every decision now lives. Veto anything you disagree with (Section 31's world model is the most consequential and the most taste-driven; everything else is engineering).
2. Build **Phase 0**: repo + toolchain + the docs system generated per III.5, done as files in the repo by Claude Code.
3. From Phase 1 onward, run Claude Code sessions per the III.6 protocol. claude.ai exits the build loop.

---
# PART IV — HARDENING ADDENDUM (H1–H9)

These are binding for implementation. H1 and H3 are design-doc rules (v4.6 F1/F2); the rest are engineering law for this repo. Every item below gets copied into the relevant `docs/specs/*.md` file at Phase 0 — this section is the master copy until then.

## H1 — GlobalJobService: claim-and-resume for every global job (doc F1)

One service owns every cross-server singleton job: the Monday rollover, the 15-minute patent sweep (E2), the hourly percentile sample (E4), market index rebuilds (H4).

**Pattern (all jobs identical):**
- **Lock:** a DataStore record per job, `{owner, expiresAt}`, taken via UpdateAsync compare-and-set. TTL 5 minutes, renewed by the owner every minute while working. DataStore, not MemoryStore — the lock and the ledger must share one consistency domain and survive eviction.
- **Ledger:** per job-run key (e.g. `weekly:2026-W24`), a table of named steps → completion stamps. The claimant executes steps in mandated order, stamping each via UpdateAsync **after** that step's effects are durably written.
- **Resume:** any claimant first reads the ledger and starts at the first unstamped step. Stamped steps are never re-executed. Every step's effects must therefore be idempotent *internally* too (e.g. dividends write per-recipient PendingCredits with deterministic credit IDs — see H2 — so even a crash mid-step double-pays no one).
- **Trigger:** ClockService fires candidate claims; MessagingService broadcast on completion is a hint only (H3) — every server also polls the current epoch/ledger key every 60s.

**Step list for the Monday job, in mandated doc order:** 1) dividends (per patent holder → PendingCredits), 2) Sprint archive top-3 + badges, 3) Sprint score wipe, 4) week-seed side effects (announcement). The seed itself is deterministic from the week number (E3) and needs no step.

## H2 — PendingCredits: idempotent application

- Pending key per user: append-only list of `{creditId, amount, source}` via UpdateAsync. **Deterministic creditIds** (e.g. `div:2026-W24:CMP-T4-07:userId`) so a retried append is a visible duplicate and droppable.
- Application happens inside the profile's own session-locked save: profile stores `appliedCreditIds` (rolling, pruned after the pending key is cleared). Order is strict: apply+record in profile → save → then delete from pending key. A crash between the two re-applies on next login, sees the id already in `appliedCreditIds`, skips. Double-credit impossible in both crash orders.

## H3 — Messaging covenant (doc F2)

MessagingService is a hint, never truth. Subscribe for speed; poll for correctness. Poll table: epoch/week ledger 60s · announcement queue read 30s · patent/challenge state on-view + the 15-min sweep · market index lazily on browse (H4) · percentile blob hourly. Nothing else may depend on message delivery. The marquee is the sole message-only feature.

## H4 — Market browse index

- **Authority:** one DataStore record per listing (CAS purchase per E12/R13 — purchase always re-reads and CASes the listing record; the index is never trusted for money).
- **Index:** MemoryStore sorted map per tier holding `{listingId, compoundId, price, expiresAt}`, write-through on create/sell/expiry, TTL = listing life + slack. On index miss/eviction, browse falls back to a DataStore index page maintained hourly by a GlobalJobService rebuild job. Stale index entries are harmless: purchase CAS rejects sold/expired listings and the client gets "already sold."

## H5 — Decay sweep ownership

The E2 15-minute sweep is a GlobalJobService job (H1 lock), not per-server. It iterates the finite patent set (≤ ~150 base + event compounds — keyed by compound ID, the list is static from the DB export). Challenge-start and window-expiry writes are UpdateAsync guarded on the patent record's state machine, so even a duplicate sweep is a no-op, not a double challenge.

## H6 — Write budgets and debouncing

8-player servers get 60 + 10×8 = 140 DataStore requests/min — generous, but discipline anyway:
- Rank scores → OrderedDataStore: debounced, flush every 30s if dirty + on logout. Never per-event.
- Profile autosave: ProfileStore default cadence; no manual extra saves except logout and pre-Prestige.
- SynthCounts (per-compound rolling lists): one UpdateAsync per natural completion (low frequency by nature — T2+ runs are 30 min+); **prune entries >30 days on every touch** (compaction is free at write time; records stay KBs, nowhere near 4MB).
- Leaderboard reads: top pages cached per server 60s.

## H7 — Contract expiry

Contracts expire at the next UTC midnight **regardless of generation time** (E8 lazy generation never grants a rolling 24h — a 23:55 login gets a 5-minute set, which is correct: contracts measure sessions on calendar days, and rolling windows would double-dip across day boundaries).

## H8 — Schema versioning

`profile.schemaVersion` (int) from the first line of Phase 1. A migration registry maps N→N+1 as pure functions, run on load, never destructive, each migration unit-tested in Lune. Global records (patents, listings, syndicates) carry the same field.

## H9 — Boot order and the no-instances rule

GameInit boot order is fixed and documented: Config → Data tables → RemoteService (manifest fan-out) → DataService → ClockService → everything else → PlayerAdded wiring last. No service may yield another's init. Reasserting E13: zero authored remote instances, zero hand-edited generated files — both enforced by a CI check (a Lune script that fails the test run if `src/shared/Data` differs from a fresh export or any Remote exists in the place file).

---

*Plan version 3 — written against PRECIPICE_GAME_DESIGN_v4_6.md (Parts E + F adopted), PRECIPICE_ECONOMY_MODEL.xlsx (Contract_Pool, Catalyst_Economy), PRECIPICE_COMPOUND_DATABASE.xlsx (validated clean). All artifacts re-validated post-edit: structural checks pass, zero formula errors, no stale wording. Nothing in this plan is pending a decision.*

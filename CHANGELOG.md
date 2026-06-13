# PRECIPICE — Change Log (v4.6 package)

## v4.6 changes (this pass — hardening)

**PRECIPICE_GAME_DESIGN_v4_6.md** (was v4.5)
- **Part F — The v4.6 Hardening Pass (F1–F2)** appended to the decision log; §32 intro and version header/footer/lineage updated.
- **F1 (resumable global jobs):** E3's weekly job could half-run if its claimant crashed mid-sequence — the week-stamp guard would then block all retries, leaving dividends paid but the Sprint stale forever. Fixed: the job is a ledger of week-stamped steps under an expiring claim lock; a dead claimant is resumed at the first unstamped step, never repeated. "Exactly once" = exactly once per step. Applies to every global job (Monday rollover, 15-min patent sweep, hourly percentile). §21 and E3 amended in place.
- **F2 (messaging covenant):** cross-server messages are hints, never truth. Every state that matters lives in an authoritative record that servers also poll on a bounded interval; only the ephemeral announcement marquee may ride messages alone.
- **Verified, no change needed:** the E5 Prestige blockers cannot soft-lock — §17 already returns staged compounds on cancellation (before second contribution) and on 12-hour expiry, and joint runs are time-bounded.

**Workbooks**
- Companion filename references synced v4.5 → v4.6 (ruling labels correctly remain "v4.5 E9/E10" — the E-numbers belong to that version). Recalculated: zero formula errors in both.

**PRECIPICE_IMPLEMENTATION_PLAN_v3.md** (was v2)
- New **Part IV — Hardening Addendum (H1–H9)**, eliminating every "will surface during Phases 1–4" risk previously flagged: H1 claim-and-resume GlobalJobService (lock TTL + step ledger), H2 idempotent PendingCredits (deterministic credit IDs, crash-safe in both orders), H3 poll-for-truth table, H4 market browse index (MemoryStore index, DataStore authority, CAS purchases never trust the index), H5 sweep ownership with state-guarded no-op duplicates, H6 write budgets and debouncing (140 req/min headroom at 8 players), H7 contract expiry at UTC midnight (no rolling 24h), H8 profile schemaVersion + migration registry from day one, H9 fixed boot order + CI guards enforcing the no-instances and no-hand-edit rules.

**New: PHASE0_KICKOFF.md**
- A complete, self-contained Claude Code prompt that scaffolds the entire Phase 0 repo: toolchain pins, data export pipeline with the structural assertions built in, remotes manifest + RemoteService, pure-Core skeleton, Lune test harness with CI guards, and the full PRECIPICE_DOCS system including transcribed CONTRACT_POOL.md and WORLD_MODEL.md. Paste it into Claude Code in an empty folder containing the four artifacts; nothing else is required to begin.

---

## v4.5 changes (prior pass)

Every edit made in this package, by file. All decisions were made and adopted (no open questions remain); the design rationale for each lives in the design doc's new **Part E (E1–E13)**.

## PRECIPICE_GAME_DESIGN_v4_5.md (was v4.4)

**New content**
- **Section 31 — The World — Servers, Plots, and the Physical Lab** (E11). Previously the game's physical form was entirely undefined. Now: 8-player servers; one plot + one instanced lab interior per player; the lab's 10 physical chambers ARE the slots (locked chambers stand dark); reveals stage physically at the chamber; other players' labs visible/walkable (default skin to visitors per §24; crests public); joint slots are Syndicate records, never chambers; standard third-person camera; full HUD parity, mobile-first.
- **Part E — The v4.5 Implementation-Seam Audit (E1–E13)** appended to the decision log, in the document's house style.

**Rule changes / clarifications, integrated in place**
- §8 Offline behavior (E1): "timer end time is permanently saved" — which contradicted §9's offline slowdown — replaced with the work-remaining model: the game saves how much work a run has left, never a finish time; countdowns are derived and recalculated at every login/logout.
- §15 (E2): challenge-trigger timing defined — event-driven on every natural completion, plus a ≤15-minute sweep for decay-driven challenges and window expiries. "The instant" = within one sweep.
- §15 (E6): 30-day natural synthesis counts are production history, not Formula Log entries — they explicitly survive Prestige.
- §16 + §23 (E7): the 80%/500% Market bounds are enforced at listing creation only; legal listings stay purchasable through Exotic decay; purchase confirmation always shows current base value. Anti-transfer function unaffected (decay moves prices away from the exploitable floor).
- §19 (E8): offline players' daily contracts generate at first login of the UTC day, state-filtered at that moment, then frozen — no-mid-day-rerolls preserved.
- §19 (E9): full contract pool referenced — 24 authored templates + draw rule, now in the economy model's Contract_Pool sheet.
- §21 (E3): Monday rollover rewritten for long-running servers — minute-level clock checks, one server claims the weekly job via a shared lock, runs dividends → Sprint reset → seed change exactly once (week-stamped, unrepeatable); live servers pick up the new week within a minute; the variant seed is deterministic from the week number so all servers agree without coordination. Server-start detection demoted to backstop.
- §21 (E4): both leaderboards — your score always shown; exact rank within ~top 1,000; honest hourly-refreshed percentile beyond. (Exact global rank for everyone is not feasible on the platform.)
- §22 (E5): Prestige is blocked, with blockers listed on the button, while any personal slot is running, any result is unrevealed, a joint staging is unmatched, or a contributed joint run is in progress. Auto-resolution rejected (silent value destruction).
- §22 reset table: new row — 30-day synthesis counts: ❌ not reset (E6).
- §30: two new flagged parameters — the Catalyst economy (E10) and the contract pool's weights/rewards (E9).
- §4: companion-file description updated for the two new economy-model sheets.
- C36 superseded (E13): the stale "27 RemoteEvents / 13 modules" note is void — no remote exists as an authored instance under the new architecture (all created at server start from a single manifest); module inventory belongs to PRECIPICE_DOCS.
- E12: simultaneity arbitration stated as a global rule — every contested record (listing purchases, world/Exotic firsts, joint-slot actions) has one authoritative copy and first-write-wins, with losers refunded/redirected per the existing §13 experience rules.

**Mechanical**
- Decision log renumbered §31 → §32; all five in-body references updated; TOC updated; version header, lineage paragraph, and footer updated to v4.5.

## PRECIPICE_ECONOMY_MODEL.xlsx

- **New sheet: Contract_Pool** (E9) — the full authored daily-contract pool: 24 templates (8 Easy / 8 Medium / 8 Hard), exact targets, Pellet/rank rewards (verified inside the §19 bands: 200–500/25, 500–1,500/75, 1,500–3,000/150), and an explicit state filter per template honoring D9/D18/D20 (e.g., the patent contract requires a discovered T2+ recipe; analysis contracts count personal Lab analyses only; Joint Synthesis requires membership + T4 qualification). Includes the draw rule — 3 standard from Easy(60%)/Medium(40%), 2 bonus from Medium(30%)/Hard(70%), no repeats per day — with live formulas: daily all-five rank min 225 / max 525 / expected 390, matching §19's "roughly 250–475" typical band. Notable template: CH8 "Complete a Stabilized Synthesis" pulls players into the weekly-seed system.
- **New sheet: Catalyst_Economy** (E10) — first model of the premium currency: free-earn sources (steady state = 102/yr ≈ 8.5/month for a streak-keeping non-payer including event milestones), months-to-afford per Catalyst-priced item, Robux conversion (best pack 3.33 R$/Cat; the 30-Catalyst skip ≈ 100 R$ vs the 75 R$ direct TimerSkip — direct skip is the efficient cash path by design; Catalysts exist for Catalyst-exclusive items), and the standing-flag verdict: scarcity is intentional; the first tuning lever is the streak steady-state rate, never price cuts.
- **Tuning_Flags:** two rows appended (Catalyst economy — FLAGGED v4.5; contract pool — AUTHORED v4.5).
- **README:** the two new sheets added to the sheet listing; companion reference updated v4.4 → v4.5.
- **Params:** stale source reference updated (v4.2 → v4.5).
- Recalculated: **728 formulas, zero errors.**

## PRECIPICE_COMPOUND_DATABASE.xlsx

- No content changes — the database passed every independent structural check (reachability, pair uniqueness, tier legality, value ranges, 120-Exotic coverage, name uniqueness) and v4.5 changes no shared numbers.
- Companion version references synced (README header v4.4 → v4.5 with a note that v4.5's rulings are implementation-seam only; Compounds header v4.3 → v4.5).
- Recalculated: **2,120 formulas, zero errors.**
- Full structural validation re-run post-edit: all checks pass.

## PRECIPICE_IMPLEMENTATION_PLAN_v2.md (was v1)

- All 14 gaps marked RESOLVED with the G→E mapping; all rulings marked ADOPTED with their new homes (design doc Part E / §31, economy model sheets).
- Phase 0 updated: contract pool and world model are now transcription into docs/, not authoring.
- Next steps updated: review Part E + §31 (veto pass), then Phase 0.

## Post-edit verification performed

1. Design doc: no stale wording survives (old timer/reset/rank-display sentences gone), headings and TOC consistent, all 13 E-rulings present, all §-renumber references updated.
2. Compound DB: full structural validation re-run on the saved file — 150 compounds, 205 mappings, full reachability, 17 variable pairs ×2, 120 Exotics.
3. Economy model: LibreOffice recalculation — zero formula errors; new-sheet formulas verified against hand math; all 24 contract rewards verified inside doc bands.

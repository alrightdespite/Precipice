# Status

## Current phase: Phase 14 — Finish-line build (planned). Phase 13 (Studio debug pass) complete.

**Last updated:** 2026-06-19

## Phase 14 — Finish-line build (planned)

Goal: take the game from "backend ~85%, loop verified" to feature-complete + launch-ready. Grounded in a code/STATUS audit on 2026-06-19. Priority: 🔴 blocker, 🟡 important, 🟢 nice-to-have.

### Phase 14 progress (2026-06-19)
- [x] **ClockService** (suggested-order 1) — built `src/server/Services/ClockService.luau`: 60s UTC tick (E3), daily + Monday-weekly boundary detection (pure, Lune-tested), drives GlobalJobService CAS jobs (F1 ledger): Monday `WeeklyEpochRotation` (dividends → sprintArchive → sprintWipe → seedEpoch, R3 order), 900s `PatentDividendSweep` (E2), hourly `MarketExpirySweep` (E7). Wired GameInit step 5 (before GlobalJobService, H9). Removed GlobalJobService dead poll loop; updated stale PatentService/MarketService wiring TODOs. **Latent bug fixed:** MarketExpirySweep previously had no driver — listings never expired in prod. 467/467 tests green; 0 selene errors; live boot-verified. NOTE: `payDividends`/`archiveSprint` still stubs (suggested-order 3); `seedEpoch` step logs only until AnnouncementService exists.
- [x] **Rate limiting** (suggested-order 2, §D) — built `src/shared/Core/RateLimiter.luau` (token bucket, clock-injected, Lune-tested). `RemoteService.setInvoke(name, handler)` enforces per-(player, remote) throttle from the Manifest `rateLimit` (capacity = ceil(rate); over-limit → `(nil, "rate_limited")`, handler skipped). Buckets keyed `userId:remote`, cleared on PlayerRemoving. Migrated all 33 C2S `OnServerInvoke` sites across 13 services to `setInvoke` (only RemoteService assigns OnServerInvoke now). RemoteHandlers CI guard updated to detect `setInvoke`. 474/474 tests green; 0 selene errors. Live-verified: PatentQuery (2/s) spammed 8× → `ok ok THROTTLED×6 ... ok` (burst 2, then refill).

### A. Core systems with NO implementation (build from scratch)
- [x] ~~🔴 **ClockService**~~ — DONE (see Phase 14 progress above).
- 🔴 **AnnouncementService** — §15 MessagingService announcements (patent claim/challenge/world-first, tier-scoped, 30s queue, H3 hint-not-truth). Wire at PatentService/MarketService emit points.
- 🟡 **CosmeticService** — §3 skins: catalog, purchase (Pellets), equip.
- 🟡 **AdminService** — moderation/admin tooling.

### B. Client UI unwired / incomplete
- 🔴 **SynthesizeScreen → real synthesis** — currently analyze-only ("Phase 12B: just analyze for now"); never calls `startSynthesis`. Build: pair → slot routing, Synthesize button, **variant picker + Stabilized toggle** (server supports it via B9: pass `desiredResultId`), confirm, input consumption feedback. This is the core loop's missing production UI.
- 🟡 **PrestigeScreen** — prestige level stubbed to 0; wire real level + 2-step confirm to `PrestigeConfirm`.
- 🟡 **Live-verify built screens** — Market buy/sell/cancel, Syndicate CRUD, Leaderboard, Settings gamepasses, FormulaLog/ExoticRegistry, Contract/Streak claim, Event/Flux UI.

### C. Server features half-built (TODOs in shipped code)
- 🔴 **PatentService** — weekly dividend payout (§15) TODO; `PatentResolved`/release announcements TODO; sweep needs ClockService.
- 🔴 **RankService.archiveSprint** + champion badges = stub (Monday job).
- 🟡 **LeaderboardService** percentile blob never populated (own-rank = -1 fallback).
- 🟡 **MarketService** — MemoryStore fast browse; market-sale rank on offline path; expiry sweep via GlobalJob.
- 🟡 **SeedResolver** — HMAC is a placeholder stub (seeds rotate by date but unsalted).
- 🟢 **AnalyticsService** — no-op stub (§30); wire a provider eventually.

### D. Security / hardening
- [x] ~~🔴 **Rate limiting NOT enforced**~~ — DONE (see Phase 14 progress above): `RemoteService.setInvoke` enforces Manifest `rateLimit` per (player, remote) via `Core/RateLimiter`.
- 🟡 **Strip/secure DebugService** before ship (studioOnly-gated now; verify unreachable in prod).
- 🟡 Configure real Robux product/gamepass IDs in `GameConfig`.

### E. Built + Lune-green but NEVER Studio-tested end-to-end (integration sweep)
Use the DebugService hook (grant/discover/`completeSlot` natural skip) to drive these fast:
Market full loop · Syndicate lifecycle · Joint Synthesis T6/T7 · Exotics (decay/world-first; verify T7 id scheme — `T7_01` doesn't exist) · Prestige full reset (§22 wipe-vs-persist) · Events/Flux · Streak · Contracts · Monetization receipts/gamepasses · Offline income · **Multiplayer 2+** (patent contests, cross-player market, plot tiling).

### F. Map / world (Studio `.rbxl`, gitignored — manual save required)
- 🔴 **SAVE chambers 7–10** (B4) — currently unsaved, lost on Studio close.
- 🟡 Plot stride ~2000 studs (Exterior bounds inflate it) — add a dedicated bounds part for tighter tiling.
- 🟡 WingLight reveal-dim invisible (lighting fix); world space/art for chambers 7–10.

### G. Content / data verification
- Economy data (rates/fees/timers) vs the two workbooks, all tiers · Exotic/T7 ids + recipes · event compounds/blueprints · contract pool reward values.

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

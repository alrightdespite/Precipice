# Status

## Current phase: Phase 12E — extraction picker fix + server-driven load gate

**Last updated:** 2026-06-17

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

## In progress

None.

## Phase 12D — Lab world build (done in Studio)

Full lab + exterior built as clone-safe BaseParts. Lives at **`workspace.Plots.PLOT_TEMPLATE`** (so `PlotService` finds it) — see `docs/PLOT_TEMPLATE.md` for the full layout. Code↔map contract verified end-to-end: `PlotService` template lookup, `SlotController.getChamberPart` path (`Plots.<userId>.Lab.Chambers.<i>`), and `RevealController` per-chamber SpotLight/PointLight/ParticleEmitter + `WingLight` resolution all resolve. `Burst` emitters configured for the reveal pop.

## Next

- **Slots 7–10:** map has chambers `"1"–"6"`; `MAX_SLOTS=10` (Expanded-Lab gamepass → 7). Reveals for slots >6 resolve nil and skip VFX gracefully. Add chambers 7–10 if/when expanded lab ships.
- **WingLight dim is invisible:** `WingLight` is a Folder-child PointLight (no transform → no light), so the reveal dim has no visible effect. To make it visible: `RevealController` searches recursively + WingLights live on parts. Map currently matches the existing contract.
- **RevealPrompt inert:** reveal is UI-driven; the chamber `ProximityPrompt` isn't wired. Either connect `Triggered → SlotController.reveal(i)` (guard on slot-complete) or disable the prompt.
- **Plot overlap (PlotService):** clones aren't position-offset, so multi-player plots stack at origin. Code-side fix (offset each clone) — not a map issue.

## Known issues

- **RevealCard patent timing (12D fix):** `isWorldFirst` in RevealController checks `StateController.patents` after VFX (~0.5s), relying on `PatentClaim` S2C arriving within that window. Fix: add `isPatent: boolean` to `SlotReveal` server response payload so the flag is authoritative and synchronous. Affects `SlotService.luau` (return value) and `RevealController.luau` (read from result instead of StateController).

## Phase 12C completed (2026-06-15)

- [x] Task 23: PRECIPICE_PHASE12C -- SynthesizeScreen nil vault guard; UIController 0.8s min loading screen; PlotService (PLOT_TEMPLATE clone per player, Plots folder); RevealController (§13 queue + VFX: dim WingLights → spotlight → 3× pulse → particle burst → chamber fade); RevealCard overlay (Keep/Sell + patent WORLD FIRST banner); SlotController.reveal delegates to RevealController; HomeScreen revealQueue HUD counter; ClientInit wires RevealController; 457/457 tests green
- [x] Task 24: PRECIPICE_PHASE12C_FIXES -- vault schema root fix (VaultService sends `data.vault.compounds` not `data.vault`; SynthesizeScreen sort crash resolved; VaultController.getQuantity correct); LoadingScreen fade (TweenService 0.3s bg fade before scope cleanup; duplicate UIController Changed connection removed); HUD overlay (SlotPanel height 200px anchored bottom; "Hide"/"Show Slots" toggle); ✕ close button added to SynthesizeScreen, MarketScreen, FormulaLogScreen, LeaderboardScreen, SyndicateScreen, SettingsScreen; 457/457 tests green

## Open questions

None currently.

## Known blockers

- `lune`/`rokit` require PATH addition on Windows (IR-02): `$env:PATH += ";$env:USERPROFILE\.rokit\bin"`

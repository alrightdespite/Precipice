# SESSION 4 HANDOFF — onboarding for the next session

You are continuing PRECIPICE (Roblox game, Luau + Fusion + Rojo). Read this fully, then read
`docs/STATUS.md` (live source of truth) and root `CLAUDE.md` (the five iron rules). This file
captures everything Session 4 did and the next planned work (Phase B: full UI restyle).

## ⚠️ DO THIS FIRST — save the map
The Studio place (`.rbxl`) is **gitignored**. Session 4 added in-world content that lives ONLY in
the place file and is LOST on Studio close unless saved: **`Lab.Stations` (5 terminals)**, chambers
7–10, the `PlotBounds` part, and the resized `Grass`. If the user hasn't already, tell them to
**Ctrl+S in Studio** before anything. The next session cannot see `.rbxl` contents except by
inspecting a running Studio via the MCP.

## Current state (HEAD `6fe3652`, all pushed to `main`)
- **525 Lune tests green, selene 0 errors / 0 warnings.** This is the baseline — keep it.
- Backend feature-complete; Phase 14 essentially done. The game loop, market, syndicate, joint
  synth, patents, prestige, events, cosmetics, contracts, leaderboard, Hall of Fame all work and
  are Studio-verified.

## What Session 4 completed (all committed + pushed)
1. **Offline-seller market rank/contract credit** (`3f676c8`) — `DataService.onCreditDrained(fn)`;
   `flushPendingCredits` invokes handlers per drained credit; `MarketService.onCreditDrained`
   replays `scoreMarketSale` + `recordProgress` for `market_sale` credits. 2-player verified
   (P1 lists→offline, P2 buys, P1 rejoins → rank 5→6 at login-drain).
2. **Map polish** (`de4e097`) — WingLight reveal-dim now dims the real `LightPanel` ambient lights
   (the old WingLight was a folder-child PointLight = invisible); plot stride fixed via a `PlotBounds`
   part (2064→474 studs) + resized per-plot `Grass`.
3. **Joint synthesis full e2e** — 2-player verified (real P2 contributed → STAGED→RUNNING).
4. **Market sell picker + `joinSyndicate` debug** (`d8b1110`) — Market "Create Listing" now picks an
   owned compound by NAME (no raw id typing); studioOnly `joinSyndicate` debug lets a local 2-player
   test form a syndicate (the test assigns NEGATIVE userIds which prod invite validation rejects).
5. **4 sweep follow-ups** (`1d6f401`) — Hall of Fame UI (`ChampionshipsUpdate` S2C + Leaderboard
   banner), leaderboard display names (client `GetNameFromUserIdAsync` cache), Event blueprint
   ownership persists across reopen (`FluxUpdate.blueprintsOwned`), per-party `PatentResolved` on
   decay transfers. HoF banner + names verified live.
6. **Boot-race fix** (`9f4632a`) — `RemoteController.init` raced replication (`FindFirstChild` →
   intermittent `missing remote: SlotStartExtraction`, aborting client init). Now `WaitForChild`
   (bounded, one-time) + `RemoteService` parents the Remotes folder LAST. Verified clean boot.
7. **Solo follow-ups** (`bb82605`) — patent-release announcements (`announcePatentReleased` on
   prestige, T4+); +7 Lune tests (debugForceJoin, onCreditDrained, releaseAllForUser → 525);
   selene 155→0 warnings (allowed 2 house-style lints in `selene.toml` + fixed 13 real:
   dead requires/locals, manual table.clone, empty-if).
8. **Phase A: in-world station terminals** (`6fe3652`) — see below.

### Phase A detail (just finished)
Walk-up terminals = physical equivalents of HUD screens (design §31). New `Lab.Stations` folder in
the plot template with 5 Models — `VaultStation`/`MarketStation`/`SyndicateStation`/
`LeaderboardStation`/`PrestigeStation` — styled to match the lab's existing control consoles
(`Detail.ConsoleBody`), each with a `Prompt` (ProximityPrompt), a `SurfaceGui`, and a **`Screen`
attribute** (editable in Studio, no code). Code: new `src/client/UI/VaultScreen.luau` (inventory
list + instant-sell + live pellet header — there was no standalone vault screen before), new
`src/client/Controllers/StationController.luau` (`bindStations()` at PlayerReady: reads each Model's
`Screen` attribute, wires `Prompt.Triggered → UIController.openScreen`, drives the Vault SurfaceGui
live), `UIController` registered Vault + added to More drawer, `ClientInit` wires it. Verified live
(real path): walked to Vault terminal, pressed E → VaultScreen; sold a stack → row cleared + station
SurfaceGui ticked 7→6; Market terminal → MarketScreen.

## NEXT: Phase B — full UI overhaul (APPROVED, not started)
Restyle **every** screen to a **Modern rounded "sim-game"** look: rounded cards, soft gradient
backdrops, chunky 3D pill buttons (darker bottom edge), bold rounded headers, subtle shadows +
hover/press spring motion. **Functions stay identical — only the frontend changes.** The user's bar:
nothing may look AI/templated; cohesive custom palette + a signature 3D pill button everywhere, real
depth, deliberate spacing, motion.

Approach — **foundation first, then propagate**:
1. Rework `src/client/UI/Theme.luau` — palette (gradient stops, card surface, accent + accent-shadow,
   soft drop-shadow), `CornerRadius` 12–16 + a pill radius, bigger paddings/gaps, a bold rounded
   display font (e.g. `Enum.Font.FredokaOne` / `BuilderSansExtraBold`) + clean numeric font, new
   tokens (`Shadow`, `Gradient`, button color sets). (Theme already has `Gradient.SurfaceSheen` +
   some bits — extend, don't fight.)
2. Rework `src/client/UI/Components.luau` — Button (3D pill + spring hover/press, primary/secondary/
   danger), Card (rounded + drop shadow), ProgressBar/TierBadge/Label/Divider/ScrollFrame, and shared
   `dropShadow` + `gradientBackdrop` helpers. ~80% of the restyle propagates from Theme+Components.
3. Per-screen migration (~14): `HomeScreen` + bottom nav + More drawer FIRST (highest visibility),
   then `SynthesizeScreen`, `MarketScreen`, `FormulaLogScreen`, `LeaderboardScreen`, `SyndicateScreen`,
   `PrestigeScreen`, `SettingsScreen`, `CosmeticsScreen`, `ContractsScreen`, `EventScreen`,
   `VaultScreen`, `LoadingScreen`, `RevealCard`. Verify each in Studio + commit in small batches.
   Spot-check no remote/controller call changed (diff is visual-only).

## Still gated on the USER (cannot finish without them)
- **Monetization** — real Robux gamepass/product asset IDs to wire into `GameConfig`.
- **Analytics** — vendor decision (PlayFab / GameAnalytics / custom); `AnalyticsService` is a no-op stub.
- **Economy workbooks** — the 2 spreadsheets for exact-value test asserts.

## Other open items (minor, code-doable)
- Unify `formatNum` (now K/M/B/T in the new files) across all screens during Phase B.
- Syndicate rename UI — server `SyndicateService.rename` + `SyndicateController.rename` exist, no UI
  wires them (a task chip was spawned). Add a Founder-only rename control to `SyndicateScreen`.
- MemoryStore fast-browse + SynthCount sharding — perf rewrites of verified paths; DEFERRED pre-launch.

## Test / commit protocol
- Run tests: `$env:PATH += ";$env:USERPROFILE\.rokit\bin"; lune run tests/run` then `selene src`.
  Must stay 525 green / 0 errors / 0 warnings before any commit touching `src/`.
- **Commit via a message file** (`git commit -F .git/COMMIT_MSG_TMP.txt` then delete it). PowerShell 5.1
  mangles `-m` strings containing quotes or angle-brackets — do NOT use `-m` for multi-line/special.
- End commit messages with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- The push prints a NativeCommandError/exit-255 from stderr wrapping — check for `main -> main` to
  confirm success, not the exit code.

## Studio MCP gotchas (all hit this session — see memory files)
- `start_stop_play` **wedges** sometimes ("Start play hasn't finished yet"); the MCP can't recover —
  ask the user to click Stop / restart Studio, then co-drive via **command-bar print snippets**.
- MCP **cannot reach 2-player local-test windows** (separate processes) — co-drive via snippets the
  user pastes back.
- `execute_luau` has a **separate require cache** (no live session/state) — drive real state via
  remotes / the `DebugCommand` hook, never `require()` a service to read live data.
- `screen_capture` **ignores the camera override in Play** — verify 3D/lighting functionally via
  `execute_luau` reads instead.
- `user_mouse_input` x/y are **viewport coords** (~2023×887), not screenshot px; read a button's
  `AbsolutePosition` center to click. GUI inset is 58px.
- Local 2-player test assigns **negative userIds** → breaks `userId>0` validations; use the
  `joinSyndicate` debug to form a syndicate.
- `RemoteController.invoke` returns server values **directly** on success (no leading pcallOk).
- `DebugCommand` remote (studioOnly) drives test setup: `grantPellets`/`grantCompound`/`grantRank`/
  `grantSprintPoints`/`archiveSprint`/`qualifyJoint`/`joinSyndicate`/`startEvent`/`simulateOffline`/
  `dumpProfile` (returns rank+contracts+championships) etc.
- Auto-memory lives at `D:\.claude\projects\D--RobloxProjects-Precipice\memory\` (MEMORY.md index).

## Connect to Studio
The user runs Roblox Studio with the MCP plugin (server name `Roblox_Studio`). Confirm via
`list_roblox_studios`; the active place is "Precipice". The map-relevant template is
`workspace.Plots.PLOT_TEMPLATE` (cloned per player to `workspace.Plots.<userId>`).

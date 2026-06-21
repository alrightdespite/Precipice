# PRECIPICE — Session 3 handoff (finishing Phase 14)

You're continuing **PRECIPICE**, an idle chemistry tycoon on Roblox (Rojo + Luau + Fusion). Repo: `D:\RobloxProjects\Precipice`, branch `main`, remote `origin` (github.com/alrightdespite/Precipice). This handoff is the current truth. The older `docs/SESSION2_HANDOFF.md` + `docs/PHASE14_HANDOFF.md` still hold deeper context (boot order H9, §E debug recipes, Studio gotchas, the five iron rules).

## First, orient (read in this order)
1. `docs/STATUS.md` — **the Phase 14 progress section is the live source of truth.** Every done + remaining item with detail. Read it fully.
2. `CLAUDE.md` (root) — the five iron rules. Non-negotiable.
3. `D:\.claude\projects\D--RobloxProjects-Precipice\memory\MEMORY.md` — auto-memory index; especially `reference_remotecontroller_invoke_contract`, `feedback_mcp_mouse_viewport_coords`, `feedback_verify_real_path`.

## State at handoff (2026-06-21)
- **518 Lune tests green** (`lune run tests/run`), **selene src: 0 errors** (157 pre-existing warnings — don't regress errors). Everything committed + pushed to `main` (HEAD `60016a9`).
- Solo direct-to-`main` workflow. Stage files explicitly. **NEVER commit** `weppy-project-sync/` or `Pictures Of FIrst Prototype Plot/` (the only uncommitted items; intentional).
- Schema at **v5**.

## Done in Session 3 (don't redo) — all committed + live-verified
- **Built 2 missing screens:** Contracts/Streak (`ContractsScreen.luau`) + Event/Flux (`EventScreen.luau`), registered in UIController + More drawer. Both playtested (render, claim, buy).
- **Formula log hydration** — `LabController.hydrateFormulaLog()` at login (returning players had empty log + wrong Lab button state).
- **HMAC-SHA256 weekly seed** — new `Core/Sha256.luau` (pure Luau, verified vs NIST + RFC 4231 vectors), injected into SeedResolver via SeedService.
- **Offline income** — fixed client sync (completed-offline slots now cleared + BalanceUpdate fired). Debug `simulateOffline`.
- **Prestige full reset** — fixed client sync (BalanceUpdate/VaultUpdate after reset, pcall-guarded) + UX (rate limits 0.1→2/s request, 0.5→2/s... now 2/s; "Checking…"/"Working…" states; confirm armed-on-failure). Reset itself correct.
- **Syndicate screen** — fixed disband (was missing the server step-1 arm call) + layout (`SortOrder=LayoutOrder` on inner UIListLayouts so Buy/Contribute buttons stop sorting before labels).
- **~15 return-shape/payload bugs** fixed across controllers (Prestige, Leaderboard, Market browse, Cosmetic, Contract, Event, Syndicate, Streak/Flux S2C handlers). Root cause + rule in MEMORY `reference_remotecontroller_invoke_contract`.
- **2-client sweep done:** cross-player market buy ✓, plot tiling ✓, patent contest ✓, joint synth qualify+stage ✓ (see below for the gap).
- **DebugService new commands** (all studioOnly): `setPrestigeLevel`, `grantRank`, `startEvent`, `simulateOffline`, `qualifyJoint`, `claimPatent`, + `dumpProfile` now returns `cosmetics`.

## What's LEFT — every item needs the user, a decision, or external files
1. **Joint Synthesis final step** — contribute → RUNNING → COMPLETE needs a **real 2nd player** (the contribute step rejects same-userId). Qualify + stage are verified; the state machine is Lune-tested ×8. Just needs a 2-player Studio run.
2. **Monetization** — set **real Robux gamepass/product asset IDs** in `src/shared/Config/GameConfig.luau` (currently 0), then test purchases in Studio. Needs the user's published asset IDs.
3. **AnalyticsService** — no-op stub (§30); needs a **vendor decision** (PlayFab / GameAnalytics / custom), then wire it.
4. **Economy workbooks** — internal data consistency is locked by `tests/specs/DataIntegrity.luau` (518 suite). Exact value-by-value comparison (rates/fees/timers per tier) needs the **two source spreadsheets** (not in repo).
5. **Offline-seller market rank** (flagged, code item) — an offline seller gets their pellets but misses the rank + contract credit an online seller gets. Clean fix needs plumbing `DataService.flushPendingCredits` (core save/load path, 4 call sites) to award rank at login-drain via a decoupled callback. Left as its own focused, 2-client-verified session because it touches the critical data path. Full approach is in the spawned task chip.
6. **Map polish** (Studio `.rbxl`, gitignored): tighter plot-stride bounds part; WingLight reveal-dim lighting fix. Chambers 7–10 are already SAVED (user did Ctrl+S).

## Test / commit protocol (every change)
```powershell
$env:PATH += ";$env:USERPROFILE\.rokit\bin"
lune run tests/run    # must stay green (518)
selene src            # 0 errors required
```
Commit per logical change; end body with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. Push to `main` when asked. **PowerShell here-string + `&&` gotcha:** chaining `git commit ...; git push ...` works but PowerShell wraps git's stderr as a red "error" even on success — check the actual `x..y main -> main` line + `## main...origin/main` to confirm a push worked (exit 255 is the wrapper, not a failure). Avoid `"`/`<`/`>` in `-m` messages.

## Studio + debug hook (Studio-only; gated by `RunService:IsStudio()`)
Rojo serves `src` into Studio live; **restart Play (Shift+F5 → F5) to load synced code** after edits. Drive runtime via the `DebugCommand` RemoteFunction from the **Client** Command Bar:
```lua
local r = game.ReplicatedStorage.Remotes
r.DebugCommand:InvokeServer("grantPellets", 5000)
r.DebugCommand:InvokeServer("grantCatalysts", 500)
r.DebugCommand:InvokeServer("grantCompound", "T2_13", 8)
r.DebugCommand:InvokeServer("discoverRecipe", "T3_06")
r.DebugCommand:InvokeServer("completeSlot", 1)          -- natural completion
r.DebugCommand:InvokeServer("setPrestigeLevel", 0)
r.DebugCommand:InvokeServer("grantRank", 300000)        -- for the 250k prestige gate
r.DebugCommand:InvokeServer("startEvent", 1000)         -- debug seasonal event + Flux
r.DebugCommand:InvokeServer("simulateOffline", 4)       -- offline-income time gap
r.DebugCommand:InvokeServer("qualifyJoint")             -- §17 T4 joint qual
r.DebugCommand:InvokeServer("claimPatent", "T5_07")     -- simulate a natural patent claim
local ok, prof = r.DebugCommand:InvokeServer("dumpProfile")  -- (ok, snapshot table)
```

## Gotchas (also see MEMORY)
- **`RemoteController.invoke` returns server values DIRECTLY on success** (no leading pcallOk). If a handler returns a single `{ok,...}` table, read fields off the FIRST return value. Several UIs broke from misreading this. Also: some S2C handlers fire a single `{...}` table — the client `OnClientEvent` handler must take the table, not positional args (bit StreakUpdate + FluxUpdate).
- **Verify the REAL path** — drive the actual UI/click, not a programmatic shortcut that skips the layer under test (this repeatedly exposed bugs the remote-level "verification" missed).
- **Studio MCP `user_mouse_input` x/y are VIEWPORT coords** (e.g. 2023×941), NOT screenshot px. Read a button's `AbsolutePosition` center to click it. MCP can't reliably click items clipped at the viewport's bottom edge (drawer last items).
- `execute_luau` uses a **separate require cache** (no live session/state) — hit real state via remotes; but PlayerGui *instances* are real and readable directly.
- The Studio MCP / weppy plugin connection is **flaky** — `start_stop_play` sometimes wedges; fall back to asking the user to run Command-Bar snippets.

## How to work
One coherent change at a time; 518 tests green + selene 0-errors before each commit; live-verify runtime/UI via the debug hook + the real click path. Flag uncertainty; ask before design decisions (analytics vendor, monetization IDs, layout aesthetics). Cite design §section for rules. Be terse; report `file:line` + verification result.

Begin: read `docs/STATUS.md`, confirm a 3-line plan, then ask which remaining item to take (or recommend the best one). The remaining items mostly need the user — so confirm what they can provide (2nd player session / Robux IDs / analytics vendor / workbooks) before picking.

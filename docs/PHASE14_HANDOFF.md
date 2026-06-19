# PRECIPICE — Phase 14 Finish-Line Build (session handoff)

You're continuing **PRECIPICE**, an idle chemistry tycoon on Roblox (Rojo + Luau + Fusion). Repo: `D:\RobloxProjects\Precipice` (git remote `origin`, branch `main`). A prior session got the backend to ~85% and live-verified the core production loop. Your job: execute **Phase 14 — Finish-line build**.

## First, orient (read in this order)
1. `docs/STATUS.md` — **Phase 14 section is your task list** (priority-tagged 🔴/🟡/🟢, with a suggested order). Read the whole file.
2. `CLAUDE.md` (root) — the five iron rules. Non-negotiable.
3. `docs/01_ARCHITECTURE.md` — boot order, service split, H1/H3/R13 concurrency patterns.
4. `docs/02_DATA_SCHEMA.md` + `docs/04_RULINGS.md` before touching data/schema/timing.
5. The relevant `docs/specs/*.md` for whatever service you build.
6. `PRECIPICE_GAME_DESIGN_v4_6.md` (repo root) — design source of truth; cite §N when implementing a rule.

## Iron rules (will break the build if violated)
- Never hand-edit `src/shared/Data/*` — regen via `python data/gen/export_data.py`.
- Never create `RemoteEvent`/`RemoteFunction` instances anywhere except via `Remotes/Manifest.luau` + `RemoteService` (CI guard enforces this).
- SlotRecords store `{workRemaining, lastTickAt, mode}` — never a fixed end-timestamp.
- Never hardcode the seed salt; never configure two-way Rojo sync.
- `math.round` (not floor) on passive-income Pellets (IR-01).

## Test / lint / commit protocol (every change)
```powershell
$env:PATH += ";$env:USERPROFILE\.rokit\bin"
lune run tests/run    # must stay green (currently 458 passed)
selene src            # 0 errors required (pre-existing warnings exist; don't regress errors)
```
- Lune tests cover **Core only** (no Roblox globals); services are Studio-tested.
- Commit per logical fix; end every commit body with:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
- Commit + push to `main` when the user asks (solo direct-to-main workflow). Stage files explicitly — do NOT commit `weppy-project-sync/` or the `Pictures Of FIrst Prototype Plot/` folder.

## Studio + tooling gotchas (saves hours)
- Roblox Studio MCP is available; Rojo serves `src` into Studio live. To test runtime: `start_stop_play(true)`, then drive via `execute_luau`.
- **`execute_luau` uses a SEPARATE require cache** — `require(...DataService)` there is a *different* instance with no session. To touch REAL server state, call **remotes** (`r.X:InvokeServer(...)`) from the **Client** datamodel, or use the debug hook below. (A past "DataService session bug" was a false alarm from this.)
- **`execute_luau` times out ~55–75s**; long `task.wait` can crash the MCP plugin. Keep waits ≤50s; split across calls. Play drops during idle gaps — restart and re-drive.
- **Repo is CRLF.** Multi-line `Edit` `old_string`s with embedded newlines often fail to match — use short, unique single-line/substring anchors.
- **Map (`PLOT_TEMPLATE`, chambers) lives in the gitignored `.rbxl`** — map changes persist only if the user saves in Studio (Ctrl+S). Chambers 7–10 (B4) may still be UNSAVED — remind the user.

## Debug hook (Studio-only, already built — use it to test fast)
`DebugService` + `DebugCommand` remote, gated by `RunService:IsStudio()` (skipped in prod via Manifest `studioOnly`). From the **Client** datamodel:
```lua
local r = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
r.DebugCommand:InvokeServer("grantPellets", 5000)
r.DebugCommand:InvokeServer("grantCompound", "T2_25", 8)
r.DebugCommand:InvokeServer("discoverRecipe", "T3_06")
r.DebugCommand:InvokeServer("completeSlot", 1)   -- NATURAL completion (counts for patents/rank); turns a 12-min synth into instant
r.DebugCommand:InvokeServer("dumpProfile")        -- reads real session: balances/vault/slots/discovered/prestige
```
Drives the §E integration sweep without waiting out timers. Verified recipe chain: T1_04+T1_03→T2_13 · T1_08+T2_01→T3_04 · T2_13+T3_04→T4_01 · T3_23+T4_01→T5_09. Variable pair: T2_25+T2_30→{T3_06, T3_10}.

## Already done (don't redo)
Bugs B1–B9 fixed + live-verified: slot-cap UI, patent world-first payload, plot tiling+spawn routing, RevealPrompt wiring, skipped-run patent gating, lint, LabAnalyze re-discovery exploit, Stabilized-Synthesis variant forcing. T2→T5 natural loop (discovery, fees 25/75/75, patents per tier, rank scoring, joint gating) verified.

## Your work — execute Phase 14 (STATUS.md) in suggested order
Start 🔴 blockers:
1. **ClockService** — build it (no file; only a `TODO` in `GameInit`). Wire epoch boundaries (Monday weekly + daily) per boot order (before GlobalJobService) and H1/H3. Fire GlobalJobService Monday steps (dividends → Sprint archive → Sprint wipe → seed epoch) + the 900s patent decay sweep. Unblocks PatentService dividends and RankService.archiveSprint.
2. **Rate limiting** — RemoteService defines `rateLimit` per Manifest entry but never enforces it. Add a server-side throttle (per player+remote).
3. **SynthesizeScreen synthesis UI** — currently analyze-only; never calls `startSynthesis`. Build production UI: input pair → slot routing → Synthesize → variant picker + Stabilized toggle (server supports `desiredResultId` via B9) → confirm.
4. **AnnouncementService** — §15 MessagingService announcements (tier-scoped, H3 hint-not-truth).

Then proceed down STATUS Phase 14 (half-built server features, CosmeticService/AdminService, §E integration sweep, §F map saves, §G content verification, §D hardening).

## How to work
- One coherent change at a time; tests green + selene 0-errors before each commit; live-verify runtime/integration changes in Studio with the debug hook.
- Cite the design §section for every rule you implement.
- Flag uncertainty — don't guess. If a task needs a design decision (cosmetic catalog, admin permission model), ask first.
- Be terse. Report what changed, `file:line`, and the verification result.

Begin: read `docs/STATUS.md` (Phase 14), confirm the plan, then start on ClockService.

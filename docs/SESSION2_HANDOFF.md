# PRECIPICE — Session 2 handoff (continuing Phase 14)

You're continuing **PRECIPICE**, an idle chemistry tycoon on Roblox (Rojo + Luau + Fusion). Repo: `D:\RobloxProjects\Precipice`, branch `main`, remote `origin`. The previous session (2026-06-19→20) cleared every 🔴 Phase 14 blocker plus most 🟡 work. This handoff is the current truth; `docs/PHASE14_HANDOFF.md` is the older one (still valid for the deeper context it covers: boot order, the debug hook, Studio gotchas).

## First, orient (read in this order)
1. `docs/STATUS.md` — **the Phase 14 progress section is the live source of truth.** Every done item + every remaining item is there with detail. Read it fully.
2. `CLAUDE.md` (root) — the five iron rules. Non-negotiable.
3. `docs/PHASE14_HANDOFF.md` — older handoff; boot order (H9), the §E debug-hook recipes, the Studio/`execute_luau` gotchas, the iron rules. Still accurate.
4. `docs/01_ARCHITECTURE.md`, `docs/02_DATA_SCHEMA.md`, `docs/04_RULINGS.md`, the relevant `docs/specs/*.md`, and `PRECIPICE_GAME_DESIGN_v4_6.md` (cite §N) as needed.

## State at handoff
- **509 Lune tests green** (`lune run tests/run`), **selene src: 0 errors** (159 pre-existing warnings — don't regress errors). All work committed + pushed to `main` (HEAD `00d56e4`).
- Solo direct-to-`main` workflow. Stage files explicitly; **never** commit `weppy-project-sync/` or `Pictures Of FIrst Prototype Plot/`.
- Schema is at **v5** (`GameConfig.SCHEMA_VERSION`; added `championships` profile field, migration[4]).

## Done in the previous session (don't redo)
All committed + (mostly) live-verified via the debug hook:
- **ClockService** — 60s UTC tick; drives every global job (Monday weekly: dividends→sprint-archive→seed-epoch; 900s patent sweep; hourly market expiry + percentile).
- **Rate limiting** — `RemoteService.setInvoke` enforces per-(player,remote) Manifest `rateLimit`; all 33 C2S handlers migrated.
- **Synthesis UI** — Lab synthesize flow (slot routing + variant picker + Stabilized toggle). Playtested.
- **AnnouncementService** — §15 tier-scoped marquee over MessagingService + 30s queue.
- **Weekly patent dividends** (§15) incl. **T7 exotic** (200k flat). **Sprint champions + Hall of Fame** (§18, offline-safe).
- **AdminService** — server-side `TextChatCommand` slash-commands (`/give /setbalance /kick /inspect /tp`); place-owner + `GameConfig.ADMIN_USER_IDS`. User-verified.
- **CosmeticService** (§24 catalog) + **Cosmetics Lab-tab UI** (build-verified; buy/equip clicks not yet playtested).
- **LeaderboardService percentile blob** (§21) — own-row rank estimate beyond top 100.
- **Bug fixes:** leaderboard return-shape, PendingCredits login-drain, exotic patent tier (→T7), exotic decay sweep coverage, §17 crest prerequisite chain, Lab "Cannot analyze" (getFee args), admin TextChatService delivery.

## What's LEFT
### Needs the user (can't be done autonomously) — see `MEMORY.md` → `project_phase14_manual_followups.md`
- **Chambers 7–10 unsaved in the gitignored `.rbxl`** — user must Ctrl+S in Studio.
- **2-client multiplayer sweep**: patent contests/challenges, cross-player Market buy + seller PendingCredits, Joint Synthesis (needs syndicate + T4 qual + partner), plot tiling. (Studio: Test → Players: 2 → Start.)
- **Real Robux IDs** in `GameConfig` (GAMEPASS_*/PRODUCT_* are 0) + Monetization receipt test (needs a real purchase).
- **Offline income** end-to-end (logout/login time gap); **full Prestige reset** live run; **AnalyticsService** provider (§30 — vendor decision).

### Autonomous + verifiable (safe to just do)
- **Cosmetics buy/equip** is built but the literal button clicks are unplaytested — wire-up is composed of verified parts.
- Hall-of-Fame client UI; SeedResolver HMAC (low value; shifts variant seed determinism); minor UI polish.
- Background-task chip pending: dedupe constants my new services hardcoded vs `GameConfig` (ANNOUNCEMENT_TOPIC, SWEEP_INTERVAL_SECONDS, etc.) — non-functional cleanup.

## Test / commit protocol (every change)
```powershell
$env:PATH += ";$env:USERPROFILE\.rokit\bin"
lune run tests/run    # must stay green (509)
selene src            # 0 errors required
```
- Lune covers Core only; services are Studio-tested. Commit per logical change; end the body with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. Commit + push to `main` when asked.
- **PowerShell here-string gotcha:** double-quotes inside `@'...'@` commit messages break the parse — avoid `"` in messages.

## Studio + debug hook (Studio-only; gated by `RunService:IsStudio()`)
Rojo serves `src` into Studio live; **restart Play (F5)** to load synced code. Drive runtime via the `DebugCommand` remote from the **Client** datamodel:
```lua
local r = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
r.DebugCommand:InvokeServer("grantPellets", 5000)
r.DebugCommand:InvokeServer("grantCompound", "T2_13", 8)
r.DebugCommand:InvokeServer("discoverRecipe", "T3_06")
r.DebugCommand:InvokeServer("completeSlot", 1)      -- natural completion
r.DebugCommand:InvokeServer("dumpProfile")          -- balances/vault/slots/discovered/prestige/championships
-- added this session:
r.DebugCommand:InvokeServer("announce", "msg", 4)   -- §15 marquee
r.DebugCommand:InvokeServer("payDividends")          -- Monday dividend step
r.DebugCommand:InvokeServer("archiveSprint")         -- + grantSprintPoints <n> first
r.DebugCommand:InvokeServer("drainPending")          -- PendingCredits login-drain
r.DebugCommand:InvokeServer("patentSweep")           -- decay sweep (compounds + exotics)
r.DebugCommand:InvokeServer("percentileJob")         -- recompute percentile blob
```
Gotchas (also in `docs/PHASE14_HANDOFF.md`): `execute_luau` uses a **separate require cache** (no session — hit real state via remotes, not `require(DataService)`); DataStore `GetAsync` caches ~4s (wait it out when reading back cross-VM writes); the Roblox Studio MCP / weppy plugin connection is flaky — fall back to asking the user to run snippets in the Command Bar.

## How to work
One coherent change at a time; tests green + selene 0-errors before each commit; live-verify runtime/integration changes via the debug hook. **Verify the REAL path** — don't claim "verified" from a programmatic shortcut that skips the layer under test (see `MEMORY.md` → `feedback_verify_real_path.md`; this bit us on the admin chat). Flag uncertainty; ask before design decisions (cosmetic catalog content, admin model, analytics vendor). Cite the design §section for rules. Be terse; report `file:line` + the verification result.

Begin: read `docs/STATUS.md`, confirm the plan in 3 lines, then ask the user which remaining item to take (or pick an autonomous-verifiable one).

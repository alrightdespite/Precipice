# PRECIPICE — Claude Code router

## Start of session

1. Read `docs/STATUS.md` → current phase and next task
2. Read the relevant `docs/specs/*.md` for what you're building
3. Read `docs/04_RULINGS.md` if touching anything math/timing/schema related

## Five iron rules

1. Never hand-edit `src/shared/Data/*` — run `python data/gen/export_data.py`
2. Never author a `RemoteEvent` or `RemoteFunction` instance anywhere except `RemoteService.luau`
3. Never store a fixed end-timestamp in a SlotRecord — use `{workRemaining, lastTickAt, mode}` (E1)
4. Never hardcode the seed salt — read from DataStore key `Config/SeedSalt`, never send to client
5. Never configure two-way Rojo sync

## Where things live

| What | Path |
|---|---|
| Toolchain versions | `rokit.toml` |
| Roblox packages | `wally.toml` |
| Studio sync config | `default.project.json` |
| Data pipeline | `data/gen/export_data.py` |
| Generated data | `src/shared/Data/*.luau` |
| Remotes manifest | `src/shared/Remotes/Manifest.luau` |
| Core logic (pure) | `src/shared/Core/*.luau` |
| Server services | `src/server/Services/*.luau` |
| Config | `src/shared/Config/*.luau` |
| Tests | `tests/` — run via `lune run tests/run` |
| Docs | `docs/` — see `docs/00_INDEX.md` |

## Running tests (Windows)

```powershell
$env:PATH += ";$env:USERPROFILE\.rokit\bin"
lune run tests/run
```

All tests must be green before any commit that touches `src/`.

## Key implementation notes

- `math.round` not `math.floor` for passive income Pellets (IR-01 in `docs/04_RULINGS.md`)
- Lune tests only cover Core modules (no Roblox globals); services are Studio-tested
- Wally packages not installed until Phase 1 — run `rokit run wally install` first
- See `docs/01_ARCHITECTURE.md` for service inventory and boot order
- See `docs/02_DATA_SCHEMA.md` for all DataStore shapes + `schemaVersion` requirement

## Anti-patterns (flag immediately)

- `LocalPlayer` in server context
- `WaitForChild` in a loop
- Bare `pcall` without error logging
- Remote args trusted without server-side validation
- `Instance.new("RemoteEvent")` outside `RemoteService.luau`
- `math.floor` on a passive income Pellet calculation

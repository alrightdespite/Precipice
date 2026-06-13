# PRECIPICE_DOCS — Index

PRECIPICE is an idle chemistry tycoon built on Roblox. This docs system is the single source of truth for implementation. The design doc (`data/PRECIPICE_GAME_DESIGN_v4_6.md`) is the source of truth for *design rules*; these docs are the source of truth for *how to build them*.

## Navigation

| File | Purpose |
|---|---|
| [STATUS.md](STATUS.md) | Current phase, done, in-progress, next task, open questions — read this first |
| [01_ARCHITECTURE.md](01_ARCHITECTURE.md) | Service inventory, boot order, Core/Service split, remote pattern, concurrency patterns |
| [02_DATA_SCHEMA.md](02_DATA_SCHEMA.md) | Player profile shape, global stores, MemoryStore maps, migration policy |
| [03_REMOTES.md](03_REMOTES.md) | Every remote: direction, payload type, rate limit, owner |
| [04_RULINGS.md](04_RULINGS.md) | Implementation delta log — where this repo diverges from or extends the design doc |
| [05_TESTING.md](05_TESTING.md) | Lune harness, mocks, CI guards, doc-example tests |
| [06_WORKFLOW.md](06_WORKFLOW.md) | Session protocol, commit rules, STATUS discipline |
| [specs/](specs/) | One spec per service (24 total) — self-contained implementation specs |
| [ui/](ui/) | Screen list and flow diagrams |
| [data/CONTRACT_POOL.md](data/CONTRACT_POOL.md) | The authored 24-template daily contract pool |
| [data/WORLD_MODEL.md](data/WORLD_MODEL.md) | Plot/lab world model decision record |

## Five iron rules (also in CLAUDE.md)

1. Read `docs/STATUS.md` and the relevant `docs/specs/*.md` before writing any code.
2. One task per session. Split in STATUS.md if it looks bigger.
3. Tests green before done. Doc-cited examples are mandatory test cases.
4. End every session by updating STATUS.md and committing.
5. Never hand-edit `src/shared/Data/*` and never create remotes as instances.

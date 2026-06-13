# DataService

## Mission

Owns all player data persistence. Single session-locked ProfileStore profile per player. Runs schema migrations on load. Provides typed read/write API to all other services; no other service touches a DataStore directly for player data.

## Responsibilities

- Load and release player profiles via ProfileStore (`Profile:Load`, `Profile:Release`)
- Run migration chain `schemaVersion N → N+1` on load; current version: 1
- Expose `getProfile(userId)` → `PlayerProfile`; throws if not loaded (never silently returns stale data)
- Expose `updateProfile(userId, fn)` → runs fn under session lock, retries on conflict
- Emit signal on profile load/unload so downstream services can initialize
- Handle server shutdown: release all profiles before server closes (bind to `game:BindToClose`)

## Session lock rules (Plan H1 applies to global stores; ProfileStore handles player lock)

- ProfileStore session lock is authoritative — only one server writes a profile at a time
- On load failure: kick player, do not start game for that session
- On profile release: flush pending credits first (H2 integration point)

## PendingCredits flush

- On profile release, iterate `PendingCredits/{userId}`, apply unapplied credits, mark applied in `pendingCreditsApplied` list, then wipe the PendingCredits store entry
- Credit IDs are deterministic — safe to retry (H2)

## Migration registry

```lua
local migrations: { (profile: PlayerProfile) -> PlayerProfile } = {
    -- [1] = function(p) ... return p end,  -- v0→v1
}
```

Run sequentially on load. Never destructive — always return full updated record.

## Schema

See `docs/02_DATA_SCHEMA.md` §Player profile.

## Dependencies

- Wally: `ProfileStore` (session-lock, autosave)
- `src/shared/Config/GameConfig.luau`: SCHEMA_VERSION
- `src/server/Services/RemoteService.luau`: none (DataService has no remotes; writes happen through other services)

## Testing

- MockDataStore covers UpdateAsync/GetAsync/SetAsync/IncrementAsync
- MockClock for time-dependent migration tests
- Spec: `tests/specs/DataService.luau` (Phase 1)

## Phase

Phase 1.

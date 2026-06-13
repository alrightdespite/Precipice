# RemoteService

## Mission

Creates all remote instances at server boot from `Remotes/Manifest.luau`. The only place in the codebase that calls `Instance.new("RemoteEvent")` or `Instance.new("RemoteFunction")`. Provides `getEvent`/`getFunction` accessors to all other services.

## Phase

Phase 0 — COMPLETE.

# AdminService

## Mission

Provides in-game admin commands for development and moderation. Protected by UserId whitelist. Never exposes DataStore write capability to non-whitelisted players.

## Key rules

- All admin commands are server-side only; no client remote
- Whitelist in private config (never committed to source)
- Commands: give compound, set balance, teleport, kick, inspect profile
- Admin actions logged to server console with userId

## Phase

Phase 7 (deferred; not needed for core gameplay loop).

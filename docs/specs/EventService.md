# EventService

## Mission

Manages time-limited seasonal events (Cascade Protocol and future events). Handles event compound blueprints, Flux currency, and event-exclusive synthesis rules. Reads EventCompounds data.

## Key rules

- Events are epoch-gated: start/end timestamps in GlobalJobs epochMarkers
- Flux earned only from natural completions (§14 applies)
- Blueprint ownership tracked in `profile.eventState.blueprintsOwned`
- `EpochChanged` remote fires S2C when event epoch changes

## Phase

Phase 6.

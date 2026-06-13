# CosmeticService

## Mission

Manages cosmetic ownership and equip state. Handles cosmetic purchases (via MonetizationService callbacks) and sends equipped state to client for rendering.

## Key rules

- Owned cosmetics stored in `profile.cosmetics.owned`
- Equipped loadout in `profile.cosmetics.equipped`
- Cosmetics have no gameplay effect; purely client-side rendering
- No dedicated remote — cosmetic state piggybacks on initial profile push

## Phase

Phase 6.

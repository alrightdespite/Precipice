# SyndicateService

## Mission

Manages Syndicate creation, membership (invite/kick/promote), shared vault contributions, and upgrade purchasing. Persists to `Syndicates/{syndicateId}` global DataStore.

## Key rules

- Max 8 members base, 12 with memberCapExpanded upgrade
- Upgrades: thirdSlot (adds joint slot 3), crest, animatedCrest, broadcastCrest
- Contribution to shared vault is one-way (no withdrawal)
- Founder can kick/promote; Officer can kick Members
- SyndicateUpdate remote fires S2C after any mutation

## Phase

Phase 3.

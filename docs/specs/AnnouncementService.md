# AnnouncementService

## Mission

Broadcasts server-wide announcements (world-first exotic synthesis, sprint end, prestige milestones) to all connected clients. Uses MessagingService as a hint (H3) — announcement is re-derived from DataStore state on receipt, not trusted directly.

## Key rules (H3)

- MessagingService messages are hints only; never authoritative
- Before broadcasting to clients, server verifies event against DataStore
- `Announcement` remote fires S2C with kind, message, tier?
- Rate limit: max 1 broadcast per compound per event type per epoch

## Phase

Phase 5.

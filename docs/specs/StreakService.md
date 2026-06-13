# StreakService

## Mission

Tracks daily login streak. Awards bonus Pellets on milestone streak days. Handles streak break (missed day) and grace window.

## Key rules

- Streak increments on first login each day (calendar day, server time)
- Grace window: `EconomyConstants.STREAK_GRACE_HOURS` after midnight before streak breaks
- `StreakUpdate` remote fires S2C with current day and `safeUntil` timestamp
- Milestone rewards sourced from EconomyConstants

## Phase

Phase 3.

# JointService

## Mission

Orchestrates joint synthesis between two players. Manages the EMPTY→STAGED→MATCHED→RUNNING→COMPLETE state machine for JointSlotRecords. Handles async mode, accelerated mode, and cooldowns.

## Key rules

- STAGED: player A declares `(myCompound, partnerCompound)`, slotIndex
- MATCHED: player B contributes their compound; synthesis begins
- Async mode: B can be offline; synthesis runs without B present
- Accelerated: marks `isNatural = false` on both sides (§14)
- Async cooldown per user: stored in `Syndicates/{id}.asyncCooldowns`
- JointSlotUpdate fires S2C after every state change

## Phase

Phase 3.

# Data Schema

## Schema versioning (H8)

Every profile and global record carries `schemaVersion: number` (integer). Migration registry maps N→N+1 as pure functions, run on load, never destructive. Current version: **1**.

## Player profile (ProfileStore, session-locked)

```
{
  schemaVersion: number,       -- H8; drives migration on load

  balances: {
    pellets: number,
    catalysts: number,
  },

  vault: {
    compounds: { [compoundId: string]: number },  -- count per compound
    residue: number,
  },

  formulaLog: {
    discovered: { [compoundId: string]: true },    -- known recipes (by result ID)
    validatedPairs: { [pairKey: string]: true },   -- joint-declared pairs (Validated mark)
    failedPairs: { [pairKey: string]: true },      -- prevents re-analysis fee
  },

  slots: SlotRecord[],          -- see below; index 1..N where N = current slot cap

  rank: {
    currentRun: number,
    lifetime: number,
    dailyCaps: {
      date: string,             -- "YYYY-MM-DD"
      marketPoints: number,
      vaultPoints: number,
    },
  },

  sprintPoints: {
    weekEpoch: number,          -- ISO week number; stale entries ignored
    points: number,
  },

  streak: {
    day: number,
    lastLoginUnix: number,
  },

  contracts: {
    dayKey: string,             -- "YYYY-MM-DD"
    list: ContractRecord[],
  },

  prestige: {
    level: number,
    jointQualLifetime: boolean, -- never resets
  },

  monetization: {
    gamepasses: { [passId: string]: boolean },
    rushUses: number,
    archiveUsesByMonth: { [monthKey: string]: { [compoundId: string]: boolean } },
    receiptLedger: { [receiptId: string]: true },  -- idempotency (H2 pattern)
  },

  cosmetics: {
    owned: { [cosmeticId: string]: boolean },
    equipped: { [slot: string]: string },
  },

  eventState: {
    fluxBySeason: { [seasonId: string]: number },
    blueprintsOwned: { [compoundId: string]: boolean },
  },

  pendingCreditsApplied: { string },  -- rolling list of applied credit IDs (H2)
}
```

### SlotRecord (E1 work-units model)

```
{
  compoundId: string,
  workRemaining: number,    -- seconds at online rate; never a fixed end timestamp
  lastTickAt: number,       -- unix seconds
  mode: "online"|"offline"|"joint",
  isStabilized: boolean,    -- Stabilized Synthesis flag
  isNatural: boolean,       -- false if Accelerated; drives Natural Completion Rule
  startedAt: number,        -- unix seconds; for analytics
}
```

### ContractRecord

```
{
  templateId: string,       -- e.g. "CE1"
  progress: number,
  target: number,
  completed: boolean,
  pelletReward: number,
  rankScore: number,
}
```

## Global DataStores

### Patents (`Patents/{compoundId}`)

```
{
  schemaVersion: number,
  compoundId: string,
  tier: number,
  firstClaimantId: number,
  firstClaimDate: number,       -- unix
  holderId: number,
  challenge: {
    challengerId: number,
    windowStart: number,
    windowEnd: number,
    queue: { { challengerId: number } },  -- challenges 4+ waiting
  }?,
  immunityUntil: number?,
}
```

### SynthCounts (`SynthCounts/{compoundId}`)

Rolling list of natural completions, sharded for hot compounds (Plan note).

```
{
  schemaVersion: number,
  entries: { { userId: number, timestamp: number } },
  -- pruned >30 days on every write (H6)
  -- serves: 30-day count, decay projection, 7-day "actively synthesizing" (R12)
}
```

Sharding: if a compound is in the top-10 active patents, split across `SynthCounts/{compoundId}/shard_{0..N}` keys. Decision deferred to Phase 4.

### MarketListings (`MarketListings/{listingId}`)

```
{
  schemaVersion: number,
  listingId: string,
  sellerId: number,
  compoundId: string,
  quantity: number,
  price: number,             -- checked at creation against baseValue (E7)
  basePriceAtCreation: number,
  state: "ACTIVE"|"SOLD"|"EXPIRED"|"CANCELLED",
  createdAt: number,
  expiresAt: number,
}
```

MemoryStore sorted-map index per tier: `{ listingId, compoundId, price, expiresAt }`. On miss, fallback to hourly-rebuilt DataStore index page (H4).

### Syndicates (`Syndicates/{syndicateId}`)

```
{
  schemaVersion: number,
  syndicateId: string,
  name: string,
  founderId: number,
  members: { [userId: number]: { role: "Founder"|"Officer"|"Member", joinedAt: number } },
  vaultBalance: number,
  upgrades: { thirdSlot: boolean, crest: boolean, animatedCrest: boolean, broadcastCrest: boolean },
  memberCapExpanded: boolean,
  jointSlots: JointSlotRecord[],   -- 2 base, 3 with thirdSlot upgrade
  asyncCooldowns: { [userId: number]: number },  -- unix expiry
}
```

JointSlotRecord state machine: `EMPTY → STAGED → MATCHED → RUNNING → COMPLETE`.

### Exotics (`Exotics/{exoticId}`)

```
{
  schemaVersion: number,
  exoticId: string,
  generated: boolean,
  unitCount: number,         -- atomic increments (R13)
  firstPair: { userId1: number, userId2: number }?,
  currentValue: number,      -- derived; recomputed from unitCount + decay constant
}
```

### PendingCredits (`PendingCredits/{userId}`)

Append-only (H2). Deterministic credit IDs prevent double-payment on retry.

```
{
  credits: { { creditId: string, amount: number, source: string } },
}
```

Credit ID format: `{source}:{epoch}:{compoundId?}:{userId}` — e.g. `div:2026-W24:T4_07:12345`.

### GlobalJobs (`GlobalJobs`)

```
{
  locks: { [jobName: string]: { owner: string, expiresAt: number } },
  ledgers: { [runKey: string]: { [stepName: string]: number } },  -- step → completion timestamp
  epochMarkers: { weekly: number, daily: number },
  percentileBlob: { sprint: number[], chiefs: number[], refreshedAt: number },
}
```

### OrderedDataStores

- `Sprint_{isoWeek}` — per-player Sprint points for the current week
- `ChiefBoard` — lifetime rank scores

## MemoryStore maps

- `Market_T{tier}` — sorted map: price → listingId, TTL = listing life + 1 h
- `AnnouncementQueue` — sorted map: timestamp → payload
- `PlayerPresence_{serverId}` — set of online userIds

Rule: **MemoryStore is never the arbiter of anything permanent** (H3).

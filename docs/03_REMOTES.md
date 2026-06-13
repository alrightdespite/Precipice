# Remotes

All remotes declared in `src/shared/Remotes/Manifest.luau`. Created at boot by `RemoteService`. Zero authored instances anywhere else (E13, CI guard enforced).

## Format

`name | kind | direction | rate limit | payload`

Rate limit = requests/second per player. `nil` = no client-side limit (S2C events or server-internal).

## Slot / Production

| Name | Kind | Dir | Rate | Payload |
|---|---|---|---|---|
| SlotStartExtraction | Function | C2S | 2/s | `compoundId → ok, err?` |
| SlotStartSynthesis | Function | C2S | 2/s | `slotIndex, input1, input2, stabilized → ok, err?` |
| SlotCancel | Function | C2S | 2/s | `slotIndex → ok, err?` |
| SlotReveal | Function | C2S | 4/s | `slotIndex → CompoundResult, err?` |
| SlotSkip | Function | C2S | 1/s | `slotIndex, skipType → ok, err?` |
| SlotStateUpdate | Event | S2C | — | `slotIndex, SlotRecord` |

## Income / Vault

| Name | Kind | Dir | Rate | Payload |
|---|---|---|---|---|
| VaultInstantSell | Function | C2S | 4/s | `compoundId, quantity → pellets, err?` |
| VaultUpdate | Event | S2C | — | `vaultSnapshot` |
| BalanceUpdate | Event | S2C | — | `pellets, catalysts` |
| OfflineIncomeDelivered | Event | S2C | — | `amount, breakdown[]` |

## Formula Lab

| Name | Kind | Dir | Rate | Payload |
|---|---|---|---|---|
| LabAnalyze | Function | C2S | 2/s | `input1, input2 → LabResult, err?` |
| LabDiscovery | Event | S2C | — | `compoundId, recipeId` |

## Market

| Name | Kind | Dir | Rate | Payload |
|---|---|---|---|---|
| MarketCreateListing | Function | C2S | 1/s | `compoundId, quantity, price → listingId, err?` |
| MarketCancelListing | Function | C2S | 2/s | `listingId → ok, err?` |
| MarketBuyListing | Function | C2S | 2/s | `listingId → ok, err?` |
| MarketBrowse | Function | C2S | 4/s | `tier?, page → listings[], err?` |

## Patents

| Name | Kind | Dir | Rate | Payload |
|---|---|---|---|---|
| PatentClaim | Event | S2C | — | `compoundId, claimantId, isWorldFirst` |
| PatentChallengeAlert | Event | S2C | — | `compoundId, windowEnd` |
| FormulaLogRequest | Function | C2S | 2/s | `() → FormulaLogData` |

## Syndicates / Joint Synthesis

| Name | Kind | Dir | Rate | Payload |
|---|---|---|---|---|
| SyndicateCreate | Function | C2S | 0.1/s | `name → syndicateId, err?` |
| SyndicateInvite | Function | C2S | 1/s | `targetUserId → ok, err?` |
| SyndicateKick | Function | C2S | 1/s | `targetUserId → ok, err?` |
| SyndicatePromote | Function | C2S | 1/s | `targetUserId → ok, err?` |
| SyndicateContributeVault | Function | C2S | 2/s | `amount → ok, err?` |
| SyndicateUpdate | Event | S2C | — | `syndicateSnapshot` |
| JointStage | Function | C2S | 1/s | `slotIndex, myCompound, partnerCompound, async, accelerated → ok, err?` |
| JointContribute | Function | C2S | 1/s | `slotIndex, compound → ok, err?` |
| JointCancel | Function | C2S | 1/s | `slotIndex → ok, err?` |
| JointSlotUpdate | Event | S2C | — | `slotIndex, JointSlotRecord` |

## Rank / Sprint / Leaderboards

| Name | Kind | Dir | Rate | Payload |
|---|---|---|---|---|
| RankUpdate | Event | S2C | — | `currentRun, lifetime, title` |
| LeaderboardRequest | Function | C2S | 0.5/s | `board → entries[], ownRow?` |

## Contracts / Streak

| Name | Kind | Dir | Rate | Payload |
|---|---|---|---|---|
| ContractUpdate | Event | S2C | — | `contracts[]` |
| StreakUpdate | Event | S2C | — | `day, safeUntil` |

## Prestige

| Name | Kind | Dir | Rate | Payload |
|---|---|---|---|---|
| PrestigeRequest | Function | C2S | 0.1/s | `() → blockers[]?, ok` |
| PrestigeConfirm | Function | C2S | 0.1/s | `() → ok, err?` |

## Announcements / Clock / Monetization

| Name | Kind | Dir | Rate | Payload |
|---|---|---|---|---|
| Announcement | Event | S2C | — | `kind, message, tier?` |
| GamepassStatus | Event | S2C | — | `passes: { [string]: boolean }` |
| EpochChanged | Event | S2C | — | `epochType, timestamp` |

# VaultService

## Mission

Owns all mutations to `data.vault`. Handles instant-sell (§16), residue grants from LabService (§12), vault snapshot push to client after every change.

## Key rules

- Instant-sell price = `compoundData.baseValue × quantity`, no market fee (§16)
- Residue units come **only** from failed Lab analyses (§12 fixed unit amounts 1/2/4/6 by tier bracket); LabService calls `VaultService.awardResidue()`. No residue on synthesis/extraction start (§6, §8: zero Pellet cost to start any slot).
- `VaultUpdate` remote fires after every vault mutation
- Inner helpers (`applyAward`, `applyDeduct`, `applyResidue`) used by callers inside their own `DataService.updateProfile` callbacks; full-operation API (`awardCompounds`, `awardResidue`) used by external callers
- Vault has no hard cap

## Public API

- `VaultService.applyAward(data, compoundId, qty)` — inner, no remote
- `VaultService.applyDeduct(data, compoundId, qty)` — inner, asserts sufficient stock
- `VaultService.applyResidue(data, amount)` — inner, for LabService
- `VaultService.fireVaultUpdate(player, data)` — fires VaultUpdate event
- `VaultService.awardCompounds(userId, compoundId, qty)` — full op
- `VaultService.awardResidue(userId, amount)` — full op (LabService calls this)
- `VaultService.init()` — wires VaultInstantSell remote; pushes snapshot on join

## Phase

Phase 3 — implemented.

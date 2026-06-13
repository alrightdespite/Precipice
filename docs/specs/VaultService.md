# VaultService

## Mission

Manages player compound vault. Handles instant-sell (converts compounds to Pellets at base value), residue accumulation from synthesis, and vault snapshot push to client.

## Key rules

- Instant-sell price = `compoundData.baseValue × quantity` (no market fee)
- Residue: 10% of synthesis cost added to vault.residue on each synthesis start
- VaultUpdate remote fires after any vault mutation
- Vault has no hard cap (design doc doesn't specify one)

## Phase

Phase 2.

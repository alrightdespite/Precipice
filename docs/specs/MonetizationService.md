# MonetizationService

## Mission

Handles gamepass checks, Developer Product purchases, and receipt processing. Receipt idempotency via `profile.monetization.receiptLedger` (H2 pattern). Fires `GamepassStatus` remote on join and on purchase.

## Key rules

- `ProcessReceipt` callback: check `receiptLedger` before applying; return `Enum.ProductPurchaseDecision.PurchaseGranted` only after confirmed write
- Gamepass checks cached in profile; refreshed on join
- Rush-use counter tracked per profile
- Archive uses tracked per month per compound

## Phase

Phase 6.

# PlayerService

## Mission

Handles player join/leave lifecycle. Orchestrates boot order for per-player initialization: load profile (DataService) → settle offline income (SlotService) → push initial remotes → mark player ready.

## Key rules (H9 boot order)

1. DataService.loadProfile(player) — blocks until loaded or kicks player
2. SlotService.settleOffline(player) — applies offline income
3. VaultService.pushVaultUpdate(player)
4. IncomeService.registerPlayer(player)
5. MonetizationService.pushGamepassStatus(player)
6. ContractService.refreshIfStale(player)
7. StreakService.checkStreak(player)
8. SyndicateService.loadSyndicate(player) — if member

On leave: reverse order, release profile last.

## Phase

Phase 1.

# Contract Pool

Source: `PRECIPICE_ECONOMY_MODEL.xlsx` Contract_Pool sheet. Generated into `src/shared/Data/ContractPool.luau`.

Draw rule: 1 Easy + 1 Medium + 1 Hard per day. Total pool: 8+8+8 = 24 templates.

## Easy (rank score: 25 each)

| ID | Name | Target | Pellet Reward | Draw Filter | Notes |
|---|---|---|---|---|---|
| CE1 | Synthesize 5 Tier 2 compounds | 5 | 400 | ≥1 discovered recipe producing T2 | Skipped runs count |
| CE2 | Complete 2 Formula Lab analyses | 2 | 300 | None (Lab always available) | Personal Lab analyses only (D18) |
| CE3 | Instant-sell a compound | 1 | 200 | None | |
| CE4 | Synthesize 3 Tier 2 compounds | 3 | 300 | ≥1 discovered recipe producing T2 | |
| CE5 | Complete 4 Formula Lab analyses | 4 | 450 | None | |
| CE6 | Instant-sell 3 compounds | 3 | 350 | None | |
| CE7 | List a compound on the Market | 1 | 250 | None | Listing fee applies normally |
| CE8 | Sell 3 Inert Residue | 3 | 200 | None | Residue obtainable from any failed analysis |

## Medium (rank score: 75 each)

| ID | Name | Target | Pellet Reward | Draw Filter | Notes |
|---|---|---|---|---|---|
| CM1 | List 3 compounds on the Market | 3 | 600 | None | |
| CM2 | Contribute 500 Pellets to your Syndicate vault | 500 | 500 | Syndicate member | Counts toward 500/day contribution rank cap |
| CM3 | Synthesize 5 Tier 3 compounds | 5 | 900 | ≥1 discovered recipe producing T3 | |
| CM4 | Buy a compound from the Market | 1 | 700 | None | |
| CM5 | Complete 6 Formula Lab analyses | 6 | 800 | None | |
| CM6 | Synthesize 8 Tier 2 compounds | 8 | 750 | ≥1 discovered recipe producing T2 | |
| CM7 | Discover a new recipe | 1 | 1200 | ≥1 undiscovered pair remaining | Always true in practice outside a fully mapped account |
| CM8 | Contribute 1,500 Pellets to your Syndicate vault | 1500 | 1000 | Syndicate member | |

## Hard (rank score: 150 each)

| ID | Name | Target | Pellet Reward | Draw Filter | Notes |
|---|---|---|---|---|---|
| CH1 | Complete a Joint Synthesis | 1 | 1500 | Syndicate member + T4 qualification | Either contributor role qualifies; Accelerated runs count |
| CH2 | Take a patent or successfully defend one of yours | 1 | 2000 | ≥1 discovered T2+ recipe (D20) | "Possible in principle" standard; quiet days unfinished is intended |
| CH3 | Synthesize 3 Tier 4 compounds | 3 | 1800 | ≥1 discovered recipe producing T4 | |
| CH4 | Synthesize 2 Tier 5 compounds | 2 | 2200 | ≥1 discovered recipe producing T5 + Syndicate member | T5 requires membership (doc §7) |
| CH5 | Earn 5,000 Pellets from Market sales | 5000 | 1600 | None | Completed sales only; Instant Sell excluded |
| CH6 | Synthesize 10 Tier 3 compounds | 10 | 1700 | ≥1 discovered recipe producing T3 | |
| CH7 | Complete 10 Formula Lab analyses | 10 | 1500 | None | |
| CH8 | Complete a Stabilized Synthesis | 1 | 1900 | ≥1 discovered variant of a variable pair | Stabilized counts as natural (§14) |

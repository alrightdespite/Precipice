# PRECIPICE — Complete Game Design Document

### Deepwell Studios

### Version 4.6 — Final · Cross-System Audit · Second-Pass Audit · Closure Rulings · Economy Calibration · Companion Sync · Implementation-Seam Audit · Hardening Pass

-----

> This document explains every system in PRECIPICE in plain language.
> No code. No jargon. If something is unclear after reading this, the design needs fixing — not the reader.
> Version 4 is a structural revision of Version 3. The v3 audit checked each system against itself. The v4 audit checked every currency and every competitive metric against every system that touches it. Several v3 systems were rebuilt as a result. Version 4.1 then audited v4 against itself and found six further contradictions and exploit holes introduced or exposed by the v4 changes; its rulings are Part D of the final section. Version 4.2 closed the remaining gaps in v4.1’s own new machinery — eight closure rulings, appended to Part D as D13–D20. Version 4.3 applied the findings of the economy model (PRECIPICE_ECONOMY_MODEL.xlsx): recalibrated Prestige costs and an honest restatement of the faucet/sink framing — Part D, D21–D22. Version 4.4 is the final companion-sync pass: a 58-point cross-verification of every shared number across this document, the economy model, and the compound database, plus correction of companion-file references that predated the database split — Part D, D23. Version 4.5 is the implementation-seam audit: thirteen rulings closing every gap found where the design meets a real server — timer persistence, challenge-trigger timing, the Monday rollover on long-running servers, leaderboard self-rank display, Prestige with in-flight production, Market bounds under Exotic decay, offline contract generation, the fully authored contract pool, the Catalyst economy model, the previously undefined world model (new Section 31), and simultaneity arbitration — Part E, E1–E13. Version 4.6 is the hardening pass: two rulings found by pressure-testing v4.5's own new machinery — crash-resumable global jobs, and the covenant that cross-server messages are hints, never truth — Part F, F1–F2. The final section documents every problem identified across all versions and exactly how each was resolved, including superseded rulings from every prior version.

-----

## TABLE OF CONTENTS

1. What Is PRECIPICE
1. The Core Loop
1. Currencies — Pellets and Catalysts
1. Compounds — What They Are
1. Tiers — The Seven Levels of Compounds
1. Extraction — How Tier 1 Compounds Are Produced
1. How You Get Compounds
1. Slots — How Extraction and Synthesis Work
1. The Online Speed Bonus
1. Passive Income — Earning Pellets Automatically
1. The Formula Lab — Discovering New Compounds
1. Inert Residue — What Failed Experiments Produce
1. The Reveal Animation — The Big Moment
1. The Natural Completion Rule — What Counts and What Doesn’t
1. Patents — The Race That Drives Everything
1. The Market — Buying and Selling Between Players
1. Syndicates — The Social Layer
1. Researcher Rank — Your Progression Title
1. Daily Contracts — Active Session Rewards
1. Login Streak — Daily Login Rewards
1. Leaderboards — Weekly Sprint and Chief’s Board
1. Prestige — The Long-Term Reset System
1. Exotic Compounds — Tier 7
1. Cosmetics — How Your Lab Looks
1. Robux Purchases — What You Can Buy
1. The Loading Screen
1. New Player Experience — First Session
1. Every Way to Earn Pellets
1. Seasonal Events — The Cascade Protocol
1. Economy Audit Commitments
1. The World — Servers, Plots, and the Physical Lab
1. Problems and Solutions — Every Design Decision Made

-----

## 1. WHAT IS PRECIPICE

PRECIPICE is an idle chemistry tycoon game on Roblox, built by Deepwell Studios for adults aged 18–34.

You run a research facility. You extract raw Tier 1 compounds and synthesize higher-tier compounds on timers that keep running while you are offline. You discover new compound formulas through experimentation in your Formula Lab. You sell compounds to other real players on a shared cross-server market. You race to be the first person in the entire game to synthesize a compound and claim its patent — and then defend that patent against anyone who tries to take it from you. You form a Syndicate with other players to access the highest tier content. Eventually you Prestige — resetting your progress in exchange for permanent bonuses — and do it all over again, faster.

The aesthetic is clean, industrial, and serious. Concrete walls. Steel equipment. Blue-white lighting. No cartoon. No bright colors. The game looks like a real research facility and treats the player as an adult.

The game never fully stops. Your slots run while you sleep. There is always something waiting when you return.

-----

## 2. THE CORE LOOP

Every session follows the same rhythm whether you play for 5 minutes or 2 hours.

**Log in.** Your offline results are waiting. Extractions and syntheses completed while you were away are sitting in your slots ready to be revealed. Passive income accumulated while you were gone has been added to your Pellet balance automatically.

**Reveal.** Tap each completed slot. The reveal animation plays. You see what you made. You decide to keep it in your vault or sell it instantly for Pellets.

**Refill your slots.** Empty slots earn nothing. Fill them immediately — extraction runs for raw Tier 1 material, synthesis runs for everything above it — and start the next batch of timers running.

**Experiment in the Formula Lab.** While your slots are running, take two compounds from your vault and try combining them. Most combinations fail and produce Inert Residue (your inputs are returned — see Section 11). When you find a valid recipe, you have permanently discovered a new compound formula and you receive one unit of the discovered compound on the spot. If you are then the first person in the entire game to synthesize that compound through a naturally completed run, you claim its patent.

**Check the market.** List compounds you do not need at a price you choose. Buy compounds you want from other players.

**Defend your patents.** Check the Formula Log for any patents under challenge. If someone has overtaken your 30-day synthesis count on a compound you hold, you have a tier-scaled defense window (72 hours to 7 days — see Section 15) to respond.

**Log off.** Your slots keep running. Passive income keeps accumulating.

That is the whole loop. Everything else — Syndicates, leaderboards, Prestige, Exotics — is built on top of this rhythm.

-----

## 3. CURRENCIES — PELLETS AND CATALYSTS

PRECIPICE has two currencies. They are kept completely separate on purpose.

### Pellets

Pellets are the main economy currency. You earn them entirely through play. You cannot buy them directly with Robux.

**What you spend Pellets on:**

- Formula Lab analysis attempts (25–200 Pellets per attempt depending on tier) and joint analysis declarations (500 Pellets — Section 17); all analysis fees are 40% cheaper from Prestige 1 onward
- Buying compounds from other players on the Market
- Market listing fees (1% of asking price, minimum 1 Pellet, non-refundable)
- Contributing to your Syndicate’s Communal Vault (spent by Officers/Founders on Syndicate upgrades — see Section 17)
- Purchasing basic cosmetic skins
- Paying the Prestige cost at endgame (500,000 to tens of millions of Pellets)

**What you cannot do with Pellets:**

- Cannot convert to Catalysts
- Cannot buy gamepasses
- Cannot buy compound recipes
- Cannot buy Researcher Rank score
- Cannot buy patents

**How Pellets leave the economy permanently:**
Every economy needs ways to delete currency or it inflates until everything feels worthless. PRECIPICE has six permanent Pellet sinks:

- 5% Platform Fee on every Market sale — deleted, goes to no one
- Market listing fees — deleted at listing creation, whether or not the item sells
- Formula Lab analysis costs — deleted (including joint analysis declaration fees — Section 17)
- Prestige costs — deleted
- Cosmetic purchases — deleted
- Syndicate vault Pellets — deleted when spent on Syndicate upgrades, and the full balance is deleted if the Syndicate disbands

### Catalysts

Catalysts are the premium secondary currency. You earn them slowly through play and can also purchase them with Robux.

**What you spend Catalysts on:**

- Skip a synthesis or extraction timer instantly (30 Catalysts — the result does not count toward patents, the Weekly Sprint, Researcher Rank, or Flux; see Section 14)
- Premium cosmetic skins (20–200 Catalysts)
- Expand your Syndicate member cap from 8 to 12 (200 Catalysts, one-time, Founder pays)
- Reduce a Joint Synthesis timer by 25% (30 Catalysts — flags the run as Accelerated; see Sections 14 and 17)

**What you cannot do with Catalysts:**

- Cannot convert to Pellets
- Cannot buy compound recipes
- Cannot buy Researcher Rank score
- Cannot buy patent-counting syntheses (the Natural Completion Rule applies to every Catalyst acceleration)

**How you earn Catalysts without spending Robux:**

- Every patent you claim: 5 Catalysts
- Login streak day 7: 1 Catalyst
- Login streak day 14: 2 Catalysts
- Login streak day 28: 5 Catalysts
- Login streak day 35 and every 7 days after: 1 Catalyst
- Seasonal event shared milestone completion: 25 Catalysts

-----

## 4. COMPOUNDS — WHAT THEY ARE

Compounds are the core content unit of the game. Every system revolves around them.

There are 150 base compounds split across 6 tiers. There are also event-exclusive compounds available only during seasonal events, and Tier 7 Exotic compounds that are procedurally generated through endgame Joint Synthesis.

Every compound has:

- A unique name (e.g. “Zinc Titanate”, “Cascade Gamma”)
- A tier (1 through 6, or 7 for Exotics)
- A production time (extraction time for Tier 1, synthesis time for Tier 2 and above)
- A base market value in Pellets (used for instant sell price and Market price bounds; for Exotics this value decays with global supply — see Section 23)
- For Tier 2 and above: at least one recipe (which two compounds produce it). A compound can have more than one valid recipe. Tier 1 compounds have no recipe — they are extracted, not synthesized
- A one-sentence flavor description

Per-compound data lives in two companion workbooks with a strict division of labor, and this document defines the rules their numbers operate under:

- **PRECIPICE_COMPOUND_DATABASE.xlsx** — the single source of truth for content: all 150 compound names, exact base values, all 205 recipes (including the 17 variable polymorph pairs), the 120-entry Exotic seed table, and the 7 event blueprint recipes. Its chemistry follows an element-conservation convention documented in its README.
- **PRECIPICE_ECONOMY_MODEL.xlsx** — the single source of truth for rules-level numbers and their validation: rank values and thresholds, fees, Prestige costs, decay constants, defense windows, and the faucet/sink and progression models that validated them — plus, from v4.5, the full authored daily-contract pool (Contract_Pool sheet) and the Catalyst earn/spend model (Catalyst_Economy sheet).
  A number stated in this document and in a workbook must agree; where granularity differs, the workbook is authoritative for data and this document is authoritative for rules.

-----

## 5. TIERS — THE SEVEN LEVELS OF COMPOUNDS

|Tier|Count|Production time       |Base sell value       |Passive income per slot|How you access it                                                                                                      |
|----|-----|----------------------|----------------------|-----------------------|-----------------------------------------------------------------------------------------------------------------------|
|1   |30   |2 minutes (extraction)|10–25 Pellets         |8 Pellets/min          |5 starters unlocked from the first second; the other 25 discovered in the Formula Lab. No inputs needed — see Section 6|
|2   |30   |12 minutes            |80–150 Pellets        |11.2/min               |Discover a T1+T1 recipe in the Formula Lab                                                                             |
|3   |30   |45 minutes            |400–700 Pellets       |15.7/min               |Discover a T1+T2 or T2+T2 recipe                                                                                       |
|4   |25   |3 hours               |2,000–4,000 Pellets   |21.9/min               |Discover a T2+T3 or T3+T3 recipe                                                                                       |
|5   |20   |8 hours               |12,000–20,000 Pellets |30.7/min               |Discover a T3+T4 recipe + must be in a Syndicate                                                                       |
|6   |15   |24 hours              |60,000–100,000 Pellets|43.0/min               |Joint Synthesis only — two qualified Syndicate members (see Section 17)                                                |

**Tier 7 Exotics** (procedurally generated):

- Synthesis time: 24 hours via Joint Synthesis only
- Base sell value: 250,000–800,000 Pellets initially, decaying with global supply down to a floor of 25% of initial value (see Section 23)
- Passive income per slot: 60 Pellets/min

-----

## 6. EXTRACTION — HOW TIER 1 COMPOUNDS ARE PRODUCED

Tier 1 compounds are not synthesized. They are **extracted** — pulled from raw feedstock your facility processes automatically. Extraction is the generative base of the entire economy: it is the only process in the game that produces compounds from nothing.

### How extraction works

1. Tap an empty slot
1. Choose **Extract** and pick any Tier 1 compound you have unlocked
1. The slot runs a 2-minute timer (1 minute 36 seconds with the online speed bonus)
1. When it completes, one unit of that compound is produced. Tap the slot to reveal it — Keep or Sell Instantly, like any other reveal

### Extraction rules

- **No inputs are consumed.** Extraction is free in materials. Its only cost is slot time.
- **No Pellet cost.** Starting an extraction costs nothing.
- One unit per run. Extraction always produces exactly one unit.
- Any slot can run an extraction or a synthesis. Slots are universal.
- Extraction slots earn Tier 1 passive income (8 Pellets/min) while running, online and offline, identical to a T1 slot in every respect.
- Cancelling an extraction loses nothing except the elapsed time — there were no inputs to lose.
- The online speed bonus applies to extraction timers normally.
- A Catalyst skip (30 Catalysts) or TimerSkip (75 Robux) completes an extraction instantly. As with all skips, the result does not count toward patents, the Weekly Sprint, Researcher Rank, or Flux (Section 14).
- **Extraction awards zero Researcher Rank and zero Weekly Sprint points.** Extraction is industrial production, not research. This is a deliberate, load-bearing rule — see Section 18 for why.
- **Tier 1 compounds carry no patents.** Patents exist for Tier 2 and above only — extraction is not synthesis, and you cannot patent raw feedstock (Section 15). Extraction reveals never trigger the patent reveal sequence, and T1 entries in the Formula Log carry no patent indicators — no RACE dot, no gold border. Discovering a non-starter T1 grants its extraction license; that is the whole reward, and it is a good one.

### Which Tier 1 compounds you can extract

- Every player permanently has extraction unlocked for the 5 starter compounds: Sodium Chloride, Calcium Oxide, Zinc Sulfate, Iron Acetate, and Potassium Iodide. These 5 licenses are baseline account features — they are not Formula Log entries and they survive Prestige.
- The other 25 Tier 1 compounds are unlocked by discovering them in the Formula Lab (certain T1+T1 combinations produce a new Tier 1 compound — see Section 7). Once discovered, that compound can be extracted freely and repeatedly. These 25 are Formula Log entries and are wiped on Prestige like all other discoveries.

### Why extraction means you can never be soft-locked

Because extraction consumes nothing and costs nothing, a player with zero compounds, zero Pellets, and zero running slots can always start an extraction and be back in the economy two minutes later. There is no reachable game state with no path forward. Version 3’s emergency restock system existed to patch a soft-lock that extraction makes structurally impossible; that system is deleted in v4 (full reasoning in Section 32).

-----

## 7. HOW YOU GET COMPOUNDS

### Method 1 — Extraction (Tier 1 only)

Described in full in Section 6. The 5 starters are available from your first second in the game; the other 25 Tier 1 compounds unlock through Formula Lab discovery.

### Method 2 — Formula Lab discovery, then synthesis (Tier 2 through Tier 5)

You cannot synthesize a compound you do not have a recipe for. The process is always:

1. Open the Synthesize screen
1. Put two compounds into the input slots
1. The action button reads **Analyze** (with the Pellet fee shown on the button) because this pair is undiscovered
1. Tap it and pay the fee
1. If a valid recipe exists: the 30-second discovery bar fills (24 seconds with the online speed bonus). The result is revealed, the recipe is permanently added to your Formula Log, your two input compounds are consumed, and **one unit of the discovered compound is delivered to your vault immediately** (a specimen grant — it counts for nothing competitively; Section 11)
1. If no recipe exists: the result is instant — your input compounds are **returned to your vault**, Inert Residue is granted (Section 12), and the failed pair is logged so you never accidentally repeat it
1. Once discovered, you can synthesize that compound any time you have the inputs

### Recipe density by result tier

Approximately 205 valid recipes exist across the whole game. The counts below are grouped by what the recipe **produces** (a compound can have more than one recipe, which is why some counts exceed the compound count for that tier):

- ~25 recipes producing Tier 1 results — these are T1+T1 pairs that unlock extraction of one of the 25 non-starter Tier 1 compounds (out of 435 possible T1+T1 pairs; discovery is real but not impossible)
- ~40 recipes producing Tier 2 results (all are T1+T1 pairs)
- ~50 recipes producing Tier 3 results (T1+T2 or T2+T2 pairs)
- ~45 recipes producing Tier 4 results (T2+T3 or T3+T3 pairs)
- ~30 recipes producing Tier 5 results (T3+T4 pairs)
- ~15 recipes producing Tier 6 results (exclusively T4+T5 and T5+T5 Joint Synthesis pairs — see Section 17)

Higher tier combinations have fewer valid recipes on purpose. The investment per attempt is higher at T4+, so discovery should feel proportionally more significant.

T6+T6 combinations are not recipes and are not in this count — every T6+T6 pair produces a procedurally generated Tier 7 Exotic, of which exactly 120 are possible (Section 23).

### Variable recipes — the weekly seed (T3 and above)

Approximately 15% of valid recipes at T3 and above are **reagent-variable**: the same two input compounds can produce one of two possible valid results. Which result is **active** is determined by a server-side seed that rerolls every Monday at midnight UTC alongside the Weekly Sprint reset. The primary result is active roughly 70% of weeks; the alternate roughly 30%.

**The seed governs synthesis, not just discovery.** This is the core of the system:

- Synthesizing a variable pair produces **the currently active variant** by default.
- If the active variant is one you have not yet discovered, completing the synthesis discovers it — the new compound is added to your Formula Log as a separate entry. Making a compound is discovering it.
- **Stabilized Synthesis:** once you have discovered a variant, you can force that specific variant regardless of the weekly seed by choosing Stabilized Synthesis when starting the run. Stabilization multiplies the synthesis timer by 1.5×. The online speed bonus applies normally on top. A stabilized run that completes naturally counts for patents, the Weekly Sprint, Researcher Rank, and Flux — stabilization is slower, not skipped, so the Natural Completion Rule is satisfied.
- You can never stabilize toward a variant you have not discovered. Default (seed-following) synthesis is the only way to produce an undiscovered variant.

**What this means in practice:** Wikis will document both results of every variable pair within days of launch. That is expected and fine. What a wiki cannot tell you is which variant is active *this week* — so the supply of each variant shifts weekly, market prices for variants oscillate with the seed, and defending a patent on a variant compound costs 50% more time on its off-weeks. Variable recipes create permanent week-to-week texture in the economy and the patent wars, not just a one-time bonus discovery.

**Which variant does discovery yield?** A standard analysis on an undiscovered variable pair discovers the **currently active** variant — the seed governs discovery exactly as it governs synthesis. Rush Analysis (Section 25) is the only override: it always delivers the **primary** variant regardless of the seed.

### Method 3 — Buying from the Market

You can skip producing and buy any compound another player has listed on the Market using Pellets. Faster but costs money.

### Method 4 — Joint Synthesis (Tier 6 and Tier 7 only)

Tier 6 compounds can only be produced through Joint Synthesis — two qualified Syndicate members each contributing one compound to a shared Syndicate-level slot. Both members receive the result. There is no solo path to Tier 6 within the rules; the alt-account threat to this gate and its mitigation are addressed head-on in Section 17. Every T6+T6 Joint Synthesis produces a Tier 7 Exotic (Section 23). Joint Synthesis supports an async mode with a time tradeoff — see Section 17 for full rules.

### Method 5 — Event-exclusive compounds

During seasonal events, special compounds become available for a limited window. You earn event currency (Flux) through natural synthesis completions, then spend Flux on event compound blueprints. A blueprint adds that compound’s recipe (including its specific required inputs, listed on the blueprint) to your Formula Log for the event’s duration. When the event ends, those compounds cannot be produced again until the event re-runs — except via the CompoundArchive gamepass’s monthly use (Section 25). Players who own units keep them permanently. See Section 29 for full event and event patent rules.

### T5 synthesis — important clarification

Tier 5 synthesis uses your personal slots on the Home or Synthesize screen — NOT the Syndicate screen. The Syndicate screen only shows Joint Synthesis slots for T6 and T7. To synthesize T5, go to your regular slots, select your T3+T4 inputs, and start it exactly like any other tier. The only requirement is that you are in a Syndicate (even a solo one you created yourself).

-----

## 8. SLOTS — HOW EXTRACTION AND SYNTHESIS WORK

Slots are the engines of your facility. Every slot can run either an extraction (Tier 1) or a synthesis (Tier 2+). All slots run independently and simultaneously.

### How many slots you have

- Base: 5 slots
- ExpandedLab gamepass: +2 slots (5 → 7)
- Prestige 1 permanent bonus: +1 slot
- Prestige 3 permanent bonus: +1 slot
- Prestige 5 permanent bonus: +1 slot
- Hard cap: 10 slots maximum regardless of any combination of bonuses

**Important:** Without the ExpandedLab gamepass, Prestige 1+3+5 brings you to 8 slots. The ExpandedLab gamepass is required to reach the 10-slot hard cap. A player with ExpandedLab (7 base) plus P1 (+1), P3 (+1), P5 (+1) has exactly 10 slots — the hard cap. No further bonuses can push past 10.

Joint Synthesis slots are separate — they belong to the Syndicate, not to you, and do not count toward your personal slot count or cap (Section 17).

### Starting a synthesis

1. Tap an empty slot — it shows “Slot idle — tap to start”
1. The Synthesize screen opens with that slot pre-selected
1. Pick two compounds from your vault as inputs
1. The action button is context-aware (full rules in Section 11): for a pair whose recipe you have discovered, it reads **Synthesize**
1. If the pair is reagent-variable: the run defaults to producing this week’s active variant. If you have discovered the variant you want and it is not active this week, choose **Stabilized Synthesis** (timer ×1.5) to force it
1. Tap Synthesize
1. Both input compounds are immediately consumed — removed from your vault
1. The slot shows a countdown timer
1. When the timer reaches zero the slot glows — tap it to trigger the reveal

**Synthesis itself costs no Pellets.** Its costs are the two input compounds and the slot time. The only Pellet fee in the production chain is the Formula Lab analysis fee for undiscovered pairs.

### Cancelling

- Cancelling a running **synthesis**: your input compounds are NOT returned. This is intentional — it keeps starting a synthesis a committed decision and prevents free slot-state shuffling. Cancelling is permanent.
- Cancelling a running **extraction**: nothing is lost except elapsed time. There were no inputs.

### Skipping a timer

- Spend 30 Catalysts to complete one slot instantly
- Buy a TimerSkip (75 Robux) to complete one slot instantly
- Either way, the result is delivered normally and counts toward daily contracts — but a skipped run does **not** count toward patents, the Weekly Sprint, Researcher Rank, or Flux. This is the Natural Completion Rule (Section 14) and it is the single most important monetization boundary in the game.

### Empty slots earn nothing

An empty slot generates zero passive income. The minimum floor income of 2 Pellets/min only applies when ALL slots are empty simultaneously. Keep every slot running at all times.

### Offline behavior

Extraction and synthesis timers always keep running when you log off. When you log back in, any run that completed while you were away is waiting — tap the slot to reveal it. If the server restarts mid-run, nothing is lost. The game permanently saves how much work each run has left — never a fixed finish time — and any server resumes it correctly. Because offline production runs 20% more slowly (Section 9), a run's finish time is recalculated whenever you log in or out; the countdown you see is always derived from the work remaining at your current pace. (v4.5 ruling E1: the old "timer end time is permanently saved" wording contradicted the offline slowdown — a fixed end time cannot change speed. The rule was always Section 9's rule; the wording now matches it.)

### Soft-lock impossibility

There is no emergency restock system in PRECIPICE, because none is needed. Extraction consumes nothing and costs nothing, and every account permanently holds 5 extraction licenses that survive every reset. A player at absolute zero — no compounds, no Pellets, no running slots — taps a slot, extracts, and is producing again in 2 minutes. The v3 emergency restock system is deleted (Section 32).

-----

## 9. THE ONLINE SPEED BONUS

Extraction and synthesis run 20% faster while you are actively in the game.

The base timer shown for each compound is the online speed. When you log off, production continues but 20% more slowly. Being present in your lab means your work moves faster.

**Example:** A T2 compound has a base timer of 12 minutes online. If you log off mid-synthesis, the remaining time ticks down 20% more slowly than it would if you stayed online.

**This applies to the Formula Lab discovery bar too.** When you discover a valid recipe, the 30-second progress bar fills in 24 seconds while you are online. The adjusted time is not displayed for this bar specifically since the difference is too small to be worth showing — it just completes slightly faster.

**This applies to Stabilized Synthesis normally** — the 1.5× stabilization multiplier and the 20% online bonus stack (a stabilized 45-minute T3 run is 67.5 minutes base, ~54 minutes if you stay online).

**This does NOT apply to T6 or T7 Joint Synthesis.** Those are 24-hour coordination runs. Applying a speed bonus to them would create unfair pressure to stay online all day.

**The online speed bonus counts as natural completion.** Playing the game faster is playing the game. It is the one and only acceleration that keeps a run fully eligible for patents, the Weekly Sprint, Researcher Rank, and Flux (Section 14).

**How it looks in the UI:** Every active slot displays: *“Zinc Salt · 09:36 remaining (online bonus active)”*

-----

## 10. PASSIVE INCOME — EARNING PELLETS AUTOMATICALLY

Every second you have an active extraction or synthesis running, you earn Pellets. This runs continuously — while you play and while you are offline up to the cap.

### Income rates per slot

|What is running in the slot    |Pellets per minute       |
|-------------------------------|-------------------------|
|Nothing — all slots empty      |2 Pellets/min total floor|
|Tier 1 (extraction)            |8                        |
|Tier 2                         |11.2                     |
|Tier 3                         |15.7                     |
|Tier 4                         |21.9                     |
|Tier 5                         |30.7                     |
|Tier 6 (Joint Synthesis)       |43.0                     |
|Tier 7 Exotic (Joint Synthesis)|60.0                     |

All active slots stack. Five T3 slots running simultaneously earns 78.5 Pellets/min.

**Joint Synthesis passive income:** while a Joint Synthesis run is active, **each of the two contributing members** earns the T6 or T7 rate for the run’s duration. The joint slot occupies no personal slot, so this is additional income on top of whatever your personal slots are doing. Offline accrual from a joint run counts against each member’s own offline cap normally.

During The Cascade Protocol seasonal event all income rates are multiplied by 1.5×.

### Offline income cap

- Base: 12 hours
- With ExtendedOffline gamepass: 24 hours
- Prestige 4 bonus: +3.6 hours added permanently

If you are offline longer than your cap, income stops accumulating after that point.

### How offline income is calculated — full ruling

Passive income accrues for the duration each slot is actively running, measured from the moment you go offline until the run completes (or the offline cap is reached, whichever comes first). It does not matter when the slot started before you went offline — only the time it runs while you are away counts toward offline income.

**Step-by-step example:**
You go offline with three slots running:

- Slot A: T4 compound, 90 minutes remaining
- Slot B: T1 extraction, 5 minutes remaining
- Slot C: T3 compound, 3 hours remaining

You are offline for 8 hours. Your offline cap is 12 hours so the cap is not hit.

- Slot B completes after 5 minutes offline. It earns T1 income (8 Pellets/min) for those 5 minutes = 40 Pellets. After it finishes it is empty.
- Slot A completes after 90 minutes offline. It earns T4 income (21.9 Pellets/min) for 90 minutes = 1,971 Pellets. After it finishes it is empty.
- Slot C completes after 3 hours (180 minutes) offline. It earns T3 income (15.7 Pellets/min) for 180 minutes = 2,826 Pellets. After it finishes it is empty.
- From the 3-hour mark to the 8-hour mark (300 minutes), all three slots are empty. The floor rate applies: 2 Pellets/min × 300 minutes = 600 Pellets.
- Total offline income: 40 + 1,971 + 2,826 + 600 = 5,437 Pellets for that 8-hour session.

**Ruling on partial runs:** If a slot had 90 minutes remaining when you logged off, it earns at its tier rate for exactly 90 minutes of offline time — no more, no less. The time the slot had already been running before you went offline is irrelevant to offline income. Online income for that pre-logout running time was already calculated and paid in real time while you were online.

**Floor income rule:** The floor rate of 2 Pellets/min applies whenever ALL personal slots are simultaneously empty. It is a total floor for the entire account, not per-slot. If even one slot is still running, that slot earns at its tier rate and no floor income is added. An active Joint Synthesis run does not suppress the floor — the floor looks only at personal slots.

**Offline cap behavior:** When the offline income cap is reached, all income stops — tier income, joint run income, and floor income alike. No income of any kind accrues beyond the cap regardless of what slots are running.

-----

## 11. THE FORMULA LAB — DISCOVERING NEW COMPOUNDS

The Formula Lab is the discovery mechanic. There is no recipe list anywhere in the game. You experiment.

### One screen, one context-aware button — the full arbitration ruling

The Formula Lab and synthesis share the Synthesize screen. You always do the same thing: pick two compounds. The action button then tells you exactly what will happen — there is no ambiguity about which system you are about to use:

|State of the selected pair                                    |Button shows                         |What happens on tap                                                                                                                                                                                                                                                                                                           |
|--------------------------------------------------------------|-------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|Undiscovered pair (no result of this pair in your Formula Log)|**Analyze — [fee] Pellets**          |A Formula Lab analysis attempt. Fee charged. Discovery or failure per the rules below                                                                                                                                                                                                                                         |
|Discovered, non-variable pair                                 |**Synthesize**                       |A normal synthesis. Inputs consumed, timer starts. No Pellet fee                                                                                                                                                                                                                                                              |
|Variable pair, at least one result discovered                 |**Synthesize** (with a variant panel)|A synthesis. The panel shows this week’s active variant as the default output. If a variant you have discovered is inactive this week, a **Stabilize (timer ×1.5)** toggle lets you force it. If the active variant is one you haven’t discovered yet, the panel shows it as “Unknown variant — synthesizing will discover it”|
|Fully exhausted pair (all results discovered, non-variable)   |**Synthesize**                       |Analysis is never offered again for this pair. You cannot accidentally pay a fee for nothing                                                                                                                                                                                                                                  |

Variable pairs are never “fully exhausted” for synthesis purposes — both variants remain synthesizable forever (active variant by default, discovered variants via Stabilize). There is no analysis path for the second variant of a variable pair: you discover it by synthesizing the pair during a week when that variant is active. The weekly seed is the gate, which is the point.

**Two pair classes the Lab refuses outright:**

1. **Any pair whose tier combination would produce a Tier 6 result — T4+T5, T5+T5, and T6+T6 — cannot be analyzed at personal scale.** The button shows **Joint research required** and points to your Syndicate’s joint slots, where these pairs are probed via joint analysis declarations (Section 17). The reason is structural: analysis success delivers one unit of the result, and a Lab-discovered T6 would be a solo-produced T6 — contradicting “Joint Synthesis only.”
1. **Tier 7 Exotics cannot be selected as analysis inputs at all.** Exotics are terminal and procedurally generated — no authored recipe can ever include one, so allowing the attempt would be a pure fee trap.

Every other pair, however hopeless, may be attempted and will fail normally — including combinations like T4+T6 or T5+T6 for which no recipe exists, and event compounds, which are authored content and fail like any other input.

### How a Formula Lab analysis works

1. Open the Synthesize screen
1. Select two compounds from your vault as inputs
1. The button reads Analyze with the fee shown. Tap it — the Pellet fee is deducted immediately
1. **If a valid recipe exists:** A 30-second discovery bar fills (24 seconds with the online speed bonus). When it completes, the result compound is revealed, the recipe is permanently added to your Formula Log, your two inputs are consumed, and one unit of the discovered compound is delivered to your vault. Discovery hands you the recipe AND your first specimen. If the pair is reagent-variable, a standard analysis discovers the **currently active** variant — only Rush Analysis (Section 25) forces the primary variant regardless of the seed.
1. **If no recipe exists:** The result is instant — no bar, no slot, no timer. Your two input compounds are **returned to your vault unharmed**. Inert Residue is granted (amount scales with tier — Section 12). The failed combination is logged so you never accidentally repeat it. You can attempt another combination immediately.

### The discovery grant counts for nothing

The unit delivered on a successful analysis is a specimen grant, not a production run. It is competitively invisible: it can never claim a patent, never adds to a 30-day synthesis count, and earns no Weekly Sprint points, no Researcher Rank, no Flux, and no credit toward any “synthesize X” contract (“complete N analyses” contracts count personal Lab analyses only — never joint analysis declarations, Section 17). This closes a real exploit: without this rule, Rush Analysis — a purchased, instant discovery — could touch a world first through the back door, violating the Natural Completion Rule (Section 14). Discover first, then race to synthesize: the RACE indicator means exactly what it says. The one place discovery and competition legitimately coincide is T6 joint discovery, where the discovering run is itself a full natural synthesis and rightly counts (Section 17).

### Why failed analyses return your inputs — and what failure actually costs

Version 3 consumed inputs on failure and then tried to soften the loss with consolation Pellets and recovery-percentage tables. Those tables only counted the analysis fee and ignored the destroyed inputs — a failed T3+T3 actually cost ~875–1,475 Pellets of committed value for ~75 back. That framing was wrong and the system underneath it felt terrible. Version 4 fixes the system instead of the framing: **failure never destroys inputs.** The consolation Pellet mechanic is deleted because the loss it compensated for no longer exists.

The true, complete cost of a failed analysis is now just the fee minus the residue’s sell value:

|Input tier combination     |Analysis fee|Residue granted|Residue sell value|Net cost of failure|
|---------------------------|------------|---------------|------------------|-------------------|
|T1 + T1 or T1 + T2         |25 Pellets  |1 unit         |15 Pellets        |10 Pellets         |
|T2 + T2 or T2 + T3         |75 Pellets  |2 units        |30 Pellets        |45 Pellets         |
|T3 + T3 or T3 + T4         |75 Pellets  |4 units        |60 Pellets        |15 Pellets         |
|T4 + T4 and anything higher|200 Pellets |6 units        |90 Pellets        |110 Pellets        |

The fee is always determined by the higher tier of the two inputs.

**Note on the T3 bracket:** the net cost of failure at T3+T3/T3+T4 (15 Pellets) is deliberately lower than the T2 bracket (45 Pellets). T3 is where players do their most active experimentation, and near-free failure keeps that tier approachable. T4+ jumps to 110 to maintain real stakes at the top. This non-monotonic step is intentional, not an error.

### From Prestige 1 onward, fees are 40% lower

|Input tier combination            |Standard fee|P1+ fee    |
|----------------------------------|------------|-----------|
|T1 + T1 or T1 + T2                |25 Pellets  |15 Pellets |
|T2 + T2, T2 + T3, T3 + T3, T3 + T4|75 Pellets  |45 Pellets |
|T4 + T4 and anything higher       |200 Pellets |120 Pellets|

Residue amounts are unchanged by Prestige.

### Recipe sharing between players

Players will share recipes externally within days of launch. This is not a problem. The patent system’s value is not secrecy — it is timing. Knowing a recipe exists does not hand you the patent. You still need the inputs, the synthesis time, and to beat everyone else who read the same guide. Variable recipes at T3+ ensure the weekly seed keeps shifting the ground under a fully wiki-documented game (Section 7).

### What to do while slots are running

When all your slots are full, a rotating contextual prompt appears below the slot panel on the Home screen. It cycles through suggestions based on what you have not engaged with yet this session:

- *“Try the Formula Lab while you wait →”* (shown until first Formula Lab use)
- *“Market is open — see what your compounds are worth →”* (shown after first Formula Lab use)
- *“Check the leaderboard →”* (shown only after player has created or joined a Syndicate)

Each prompt appears once per session, auto-dismisses after 8 seconds, and never shows the same suggestion twice in a row.

-----

## 12. INERT RESIDUE — WHAT FAILED EXPERIMENTS PRODUCE

Every failed Formula Lab combination produces Inert Residue alongside the return of your inputs. The amount scales with the tier of the input compounds.

### Residue amounts per failed combination

|Input tier combination    |Inert Residue produced|
|--------------------------|----------------------|
|T1 + T1 or T1 + T2        |1 Residue             |
|T2 + T2 or T2 + T3        |2 Residue             |
|T3 + T3 or T3 + T4        |4 Residue             |
|T4 + T4 or anything higher|6 Residue             |

### Residue properties

- Instant sell value: 15 Pellets per unit flat, sellable from the vault at any time
- **Cannot be listed on the Market.** Residue is a terminal byproduct with no use — no player has a reason to buy it, so listings would only clutter the Market UI. Version 3 allowed listing “at a fixed price” that was never defined; v4 deletes the option entirely
- Cannot be used as a synthesis input — it is terminal, end of the line
- Does not appear in your Formula Log
- Stacks in your vault under its own entry

### Why it exists

Failure should leave a trace. You ran a real experiment; you get a physical byproduct with modest value, and your net cost stays small (Section 11). A player who aggressively experiments at T3 and T4 accumulates meaningful Residue value over time as a side effect of doing the game’s most interesting activity.

-----

## 13. THE REVEAL ANIMATION — THE BIG MOMENT

Every extraction and synthesis completion triggers a reveal animation. This is the most important moment in the game. It is designed to look incredible in a 15-second vertical video with zero explanation needed to a viewer who has never heard of PRECIPICE.

### Standard reveal sequence

1. The synthesis wing lights dim to 20% intensity
1. A spotlight activates at the chamber — color matches the compound’s tier
1. The chamber pulses three times
1. The chamber fades out and the compound icon fades in
1. Particles burst from the chamber — type, color, and intensity scale with tier
1. A result card slides up from the bottom of the screen showing the compound name, tier badge, flavor description, and current base sell value
1. Two buttons appear: **Keep** and **Sell Instantly for [X] Pellets**

**Keep** — compound stays in your vault. (You can still Instant Sell it from the vault later at any time — Section 16.)
**Sell** — compound removed, base market value added to your Pellet balance immediately.

### Patent reveal — additional sequence

If this run is the first naturally completed synthesis of this compound anywhere in the game (possible at T2 and above only — T1 has no patents, Section 15):

- “PATENT CLAIMED” stamps onto the screen in large bold gold text with a bounce animation
- Below it: “FIRST IN THE WORLD” in slightly smaller text
- Competition context appears: “X players were actively synthesizing this compound” — where “actively synthesizing” is defined as players who have discovered this recipe AND had at least one natural synthesis of this compound complete in the last 7 days. This reflects genuine active competition, not merely awareness of the recipe.
- Floating number animations rise from the card showing your Pellet bonus and “+5 Catalysts”
- The result card has a gold border

When this fires on every other player’s screen across every server:

*“⬡ WORLD FIRST”*
*”[Chief Scientist] alrightdespite synthesized Cascade Gamma”*
*“The patent is claimed. Can you be next?”*

This full world-first sequence fires exactly once per compound, ever — it is the visual half of the once-ever claim package (Section 15). Taking custody of a released patent through a synthesis plays the standard reveal plus a notification — *“You now hold the patent on [compound]”* — and winning a patent at a challenge window’s expiry (no run involved) delivers the same notification with no reveal.

### Skipped-run reveals

A reveal from a skipped (Catalyst or TimerSkip) run plays the standard animation and delivers the compound normally, but can never trigger the patent sequence — skipped runs are invisible to the patent system (Section 14). If a skipped run produces a compound that has never been synthesized by anyone, the compound is delivered, no patent is claimed, and the compound remains unclaimed with its RACE indicator live for everyone, including you.

### Exotic patent race — when two players tie

If two pairs on different servers complete the same brand new Exotic synthesis nearly simultaneously and one narrowly loses the patent race, the losing players see: *“Someone else patented this compound moments before you — the race is now on.”* Their compounds are still delivered. They just did not get the patent bonus. The contested system means they can still take the patent by out-synthesizing the current holder.

### Multiple reveals queued

If you return offline with multiple completed slots, reveals play one at a time in sequence with a 0.5-second gap between each. A counter shows in your HUD: “3 reveals queued.” Each reveal gets its full moment.

-----

## 14. THE NATURAL COMPLETION RULE — WHAT COUNTS AND WHAT DOESN’T

This rule is the load-bearing wall between PRECIPICE’s monetization and its competition. It is stated once here and referenced everywhere it applies.

### The rule

A production run **counts** toward competitive and progression metrics only if its timer ran to natural completion. Specifically, a natural completion is required for:

- **Patent claims** — being first in the world only counts on a natural run
- **Patent 30-day synthesis counts** — challenges and defenses are fought exclusively with natural runs
- **Weekly Sprint points**
- **Researcher Rank score from production**
- **Flux earned during seasonal events**

A run does NOT count toward any of the above if it was completed or shortened by:

- A Catalyst timer skip (30 Catalysts)
- A TimerSkip purchase (75 Robux)
- The Catalyst Joint Synthesis 25% timer reduction (the run is flagged **Accelerated** — see Section 17)

### What always counts as natural

- The 20% online speed bonus. Playing the game is natural.
- Stabilized Synthesis (timer ×1.5). Slower is natural by definition.
- Offline completion at the reduced offline rate.

Formula Lab discovery grants are not production runs at all — they sit outside this rule entirely and count for nothing competitively (Section 11).

And the rule cuts one way only: it governs **competitive credit, never knowledge and never delivery**. A skipped or Accelerated run always delivers its compounds and, where completion teaches something (joint discovery runs — Section 17), always teaches it. Skips change what counts, not what you receive or learn.

### What skipped runs still do

A skipped run is not wasted — it is simply non-competitive:

- The compound is delivered to your vault normally
- It counts toward **daily contracts** (“Synthesize 5 T2 compounds” accepts skipped runs)
- It can be sold, listed, used as an input, or contributed to Joint Synthesis like any other unit

### Why this rule exists

The contested patent system’s win metric is synthesis count. The Weekly Sprint’s win metric is synthesis output. Researcher Rank gates Prestige. If purchased skips counted toward any of these, every competitive system in the game would be directly purchasable with Robux — and the game’s monetization pillar (“Robux buys time, not advantage” — Section 25) would be a lie. With this rule, every Robux product retains its full progression value (more compounds, faster economy, contract completion) while the leaderboards, the patent wars, and the rank ladder are contests of play, not spend. The UI always labels a skip’s consequence before purchase: *“Instant completion — this run will not count toward patents, the Weekly Sprint, or Researcher Rank.”*

-----

## 15. PATENTS — THE RACE THAT DRIVES EVERYTHING

### What a patent is

The first player in the entire game to **naturally complete** a synthesis of a specific compound claims its patent. They receive a one-time bonus and a weekly Pellet dividend for as long as they hold it. Patents are not permanent trophies — they are titles you hold and must defend. Anyone can take your patent by out-synthesizing you.

One patent per compound. No sub-tiers. **Patents exist for Tier 2 and above only.** Tier 1 compounds are extracted, not synthesized — you cannot patent raw feedstock, and a patent race decided by who taps a free 2-minute timer longest would be an attendance contest, not research. The patentable pool is the 120 base compounds at T2–T6 plus every Tier 7 Exotic as it is generated. T1 Formula Log entries never show patent indicators.

### Claiming a patent

When you are the first person anywhere in the game to naturally synthesize a compound:

- You receive a one-time Pellet bonus (see table below)
- You receive 5 Catalysts
- You receive 500 Researcher Rank points
- Your name and claim date are recorded permanently in the global Formula Log history — even if you later lose the patent, history shows you were first
- The patent announcement fires to every player on every server (first claims are always global, at every patentable tier)
- You begin receiving weekly Pellet dividends every Monday

**The claim package is paid exactly once per compound, ever.** The Pellet bonus, the 5 Catalysts, the 500 rank points, and the world-first reveal belong to the literal world first alone. Patent transfers, challenge wins, and reclaims of released patents convey the patent itself and its weekly dividend stream — never the one-time package. This kills two exploits at once: claim-bonus farming through coordinated Prestige cycles (release your patents, re-claim them, pocket 800,000 Pellets per T6 — now pays zero) and claim-rank farming through patent ping-pong.

### One-time claim bonuses

|Tier     |Pellet bonus                                                |
|---------|------------------------------------------------------------|
|T2       |1,150 Pellets                                               |
|T3       |5,500 Pellets                                               |
|T4       |30,000 Pellets                                              |
|T5       |160,000 Pellets                                             |
|T6       |800,000 Pellets                                             |
|T7 Exotic|3× the Exotic’s initial base value — up to 2,400,000 Pellets|

Plus 5 Catalysts and 500 Researcher Rank points — on the world-first claim only, once per compound, regardless of tier.

### Weekly patent dividends

Every Monday at midnight UTC, all current patent holders receive a Pellet payout. Dividends fire before the Weekly Sprint reset and the variable-recipe seed reroll — always in that order, never simultaneously.

|Compound tier|Weekly dividend|
|-------------|---------------|
|T2           |800 Pellets    |
|T3           |5,000 Pellets  |
|T4           |15,000 Pellets |
|T5           |60,000 Pellets |
|T6           |100,000 Pellets|
|T7 Exotic    |200,000 Pellets|

**Note on T6 and T7 dividend rates:** these are calibrated so that even a large patent portfolio does not trivialize Prestige costs. A realistic top-tier portfolio of 5 T6 patents and 10 T7 patents earns 500,000 + 2,000,000 = 2,500,000 Pellets/week — powerful but not game-breaking against Prestige costs in the 4M–60M+ range. The theoretical maximum (all 15 T6 and all 120 T7 patents on one player: 25.5M/week) is near-impossible under the contested system and the coordination cost of T7 production. The aggregate game-wide dividend faucet is tracked in the launch economy audit (Section 30).

Dividends are paid to your Pellet balance if online, or to PendingCredits if offline (delivered on next login).

**Dividend timing ruling:** Whoever holds the patent at the exact moment the dividend fires gets paid. If you lose a patent at any point before Monday midnight UTC, you receive nothing for that week. This makes patent defense economically urgent in the final hours before Monday.

**Dividend for contested patents during a defense window:** If your patent is under active challenge and the defense window is open, you still receive the dividend as normal — provided you hold the patent at midnight. Winning the defense after midnight does not retroactively grant the dividend for that week. Losing the patent before midnight means no dividend regardless of challenge status.

### The contested patent system

**The 30-day rolling window:**
At every moment the game tracks who has naturally synthesized each compound the most times in the last 30 days. This is a rolling window — syntheses older than 30 days automatically fall off. Skipped and Accelerated runs are never in the window at all (Section 14). Old syntheses decaying out of the window is how inactive players naturally lose their patents over time without any artificial expiry timer. These counts are production history, not Formula Log entries: they survive Prestige (v4.5, E6). A player who Prestiges keeps their standing in every race — the natural brake is that they cannot synthesize anything until they rediscover its recipe.

**When a challenge triggers:**
The instant any player’s 30-day natural synthesis count on a compound surpasses the current patent holder’s 30-day count — whether by the challenger synthesizing or by the holder’s old runs decaying out — a challenge triggers immediately, unless the compound is inside a post-defense immunity period (below). It does not wait for any boundary.

**How “the instant” works in practice (v4.5, E2):** synthesis-driven triggers are evaluated the moment the relevant run completes. Decay-driven triggers have no moment — counts fall as time passes with nobody acting — so the game re-checks every held patent on a fixed sweep that runs at least every 15 minutes. A decay-triggered challenge may therefore begin up to 15 minutes after the mathematical crossover. Against defense windows measured in days, that delay is imperceptible and changes no outcome; “the instant” means “within one sweep.” Defense-window expiries are resolved by the same sweep, so a window never silently overruns by more than minutes.

**Tier-scaled defense windows:**
The holder receives a notification: *“Your patent on Zinc Titanate is under challenge. Defend it within [window].”* The window scales with the compound’s tier, because the window must allow a meaningful number of natural completions at that tier’s production time:

|Compound tier|Defense window|Max natural completions per slot in the window|
|-------------|--------------|----------------------------------------------|
|T2–T3        |72 hours      |96 (T3, 45 min) to 360 (T2, 12 min)           |
|T4           |96 hours      |32                                            |
|T5           |120 hours     |15                                            |
|T6 / T7      |7 days        |7 per joint slot                              |

Version 3’s flat 72-hour window made T6/T7 defenses mathematically unwinnable whenever the deficit exceeded 3 — the window physically could not contain more than three 24-hour runs. The scaled windows guarantee a genuinely contestable defense at every tier.

**How a defense resolves:**
The holder must get their 30-day count back ahead of the top contender before the window expires. The challenger (and everyone else) keeps synthesizing during the window — it is a live race, not a frozen snapshot. If the holder is ahead when the window closes, the challenge is defended and the holder earns tier-scaled defense rank (Section 18). If not, the patent transfers.

**The expiry ruling — multi-party races:**
When a defense window expires with the holder behind, the patent transfers to **whoever holds the highest 30-day natural synthesis count at that exact moment** — the named challenger, or a third party who overtook both during the window. The challenge notification names the player who triggered it, but the trigger is just the alarm; the count decides the outcome. Ties at expiry are broken in favor of the current holder (defending a tie is holding the line).

**Post-defense immunity:**
After a successful defense, that compound cannot be challenged by anyone for **7 days**. The holder’s count continues accruing normally during immunity, and rivals’ counts continue accruing too — immunity delays the alarm, it does not freeze the race. Without this rule, a challenger at fast tiers could re-trigger a fresh challenge minutes after losing one, creating an infinite defense treadmill. One defense buys one week of peace on that compound.

**When a patent transfers:**
The first-claimant’s name remains in the Formula Log history entry. The current holder field updates to the new holder. Transfer announcements are tier-scoped (below).

### Announcement scoping — preventing global spam

- **First claims:** global cross-server announcement at every tier. There are finitely many of these and each is a genuine world event.
- **Patent transfers:** global cross-server announcement only at **T4 and above** (*“⬡ PATENT TAKEN — [Researcher] newplayer_404 has taken the patent on Cascade Gamma from alrightdespite.”*). T2–T3 transfers notify only the two parties involved and update the Formula Log — at low tiers, transfers are frequent enough that global broadcasts would become noise.
- All global announcements pass through a queue with a minimum 30-second gap between broadcasts.

### Simultaneous challenge limit — the multi-attack ruling

If a patent holder has more than 3 active challenges simultaneously across different compounds, the defense window for challenges 4 and beyond does not start until at least one of the earlier three resolves (defended or lost). A coordinated rival group can press up to 3 patents in a single sweep but cannot atomize an entire portfolio simultaneously.

**Clarification:** The cap applies per holder, not per challenger. If three separate unrelated players each challenge one of your patents at the same time, all three are active (exactly 3, within the cap). A fourth challenge from any player — related or unrelated — queues until one of the three resolves. Queued challenges re-validate when they activate: if the would-be challenger is no longer ahead of the holder’s count at activation time, the queued challenge dissolves without opening a window.

### Released patents — reclaim rules

When a Prestige releases patents back to the pool, each released compound’s patent goes to the **next natural completion** of that compound by anyone — which makes the RACE indicator’s “synthesize it now” literally true. Custody is all that completion grants: nobody’s 30-day counts reset on release, so a rival already sitting on a high count can trigger a challenge the instant custody lands — possibly immediately. That is the two systems composing correctly, not a bug: the sprint to claim and the marathon to hold are different contests, and a reclaimed patent is only as safe as your count makes it. Reclaims pay no one-time package (it went to the world first long ago) and announce as transfers — global at T4+, parties-only at T2–T3. If the reclaiming completion is a Joint Synthesis — which credits two members, and custody cannot be shared — **the member who opened the slot takes custody**, the same opener convention used for world firsts (Section 17).

### Decay visibility — no 3am ambushes

The Formula Log detail view for every patent you hold shows: your current 30-day count, the highest rival’s current count, and — if your lead is shrinking through decay — a projection: *“At current decay, your lead expires in N days.”* Decay-triggered challenges remain possible (they are how the system breathes), but an attentive holder always sees them coming.

### New players in a mature game

In a game where all patents are held by active defenders, a new player may find it difficult to immediately challenge an entrenched holder. This is intentional — the correct strategy is to target compounds whose holders have gone inactive (their 30-day count decays toward zero naturally) or to focus on higher tier compounds where the patent race is still live. The system does not protect veterans from challenges, nor new players from competition. It is fair in both directions. And because skips don’t count, no rival — new or veteran — can ever buy their way past you (Section 14).

### Formula Log patent indicators

- **Green pulsing dot — RACE:** You have discovered this recipe. Nobody currently holds the patent. Synthesize it now.
- **Gold border:** Someone holds this patent. Their name and claim date shown.
- **Gold border + star:** You hold this patent.
- **Gold border + pulsing warning:** Your patent is currently under challenge. The remaining defense window is shown.
- **Gold border + shield:** Your patent is in post-defense immunity. Days remaining shown.

-----

## 16. THE MARKET — BUYING AND SELLING BETWEEN PLAYERS

The Market is a shared economy where players list compounds for sale and other players buy them. It is cross-server — every player on every server sees and interacts with the same pool of listings.

### Two ways to sell a compound

**Instant Sell:** Available **anywhere a compound exists** — on the reveal card the moment it completes, or from your vault at any later time. The game buys the compound from you at its current base value immediately. Fast, guaranteed, always available. Instant Sell is the economy’s universal liquidity floor: every compound at every tier always has a guaranteed exit at 100% of base value, from day one, forever. (Version 3’s launch-window NPC floor buyer at 70% of base value is deleted — it was strictly dominated by Instant Sell in every case and solved a problem Instant Sell already solved. Full reasoning in Section 32.)

**Market listing:** Set your own price, pay a small listing fee, list it on the Market, wait for a real player to buy it. Higher potential payout. Requires other players to be active.

### Market rules

|Rule                        |Value                                                                                                       |
|----------------------------|------------------------------------------------------------------------------------------------------------|
|Price floor                 |80% of the compound’s current base value                                                                    |
|Price ceiling               |500% of the compound’s current base value                                                                   |
|Listing fee                 |1% of your asking price, minimum 1 Pellet — charged at listing creation, non-refundable, permanently deleted|
|Your maximum active listings|10 at one time                                                                                              |
|Listing expiry              |7 days — the compound is **returned to your vault** if unsold                                               |
|Platform Fee                |5% of every sale, permanently deleted                                                                       |

**What the price floor and ceiling are actually for:** they are not economic protection — no rational seller lists below ~105% of base anyway, because Instant Sell nets more after the 5% fee. The bounds exist as an **anti-transfer dampener**: deliberately underpriced listings are the standard mechanism for alt accounts gifting value to mains and for real-money trading moving Pellets between accounts. The 80% floor, the 500% ceiling, the 5% sale fee, and the listing fee together cap the efficiency of any disguised transfer. Do not remove these bounds as “redundant” — this is their function.

**When the bounds are checked (v4.5, E7):** the 80%/500% bounds are enforced once, at listing creation, against the compound’s base value at that moment. A listing that was legal when created remains purchasable for its full 7-day life even if the compound’s base value moves afterward — which only matters for Exotics, whose values decay (Section 23). Decay moves a fixed asking price *away* from the exploitable floor, never toward it, so checking at creation costs the anti-transfer function nothing. The purchase confirmation always shows the compound’s current base value beside the asking price, so a buyer sees exactly how a decayed Exotic listing compares to today’s value.

**Why listings expire to the vault, not to destruction:** Version 3 destroyed unsold listings at expiry while offering free cancellation at any time — a rule that punished only inattention and generated support pain for zero economic function. The non-refundable listing fee replaces it as both the spam deterrent and the sink.

### What you receive when something sells

If you list a compound for 1,000 Pellets and it sells:

- You paid a 10 Pellet listing fee at creation (1%)
- You receive 950 Pellets (95% of the sale)
- 50 Pellets are permanently deleted (the 5% fee)

Both deductions are shown explicitly before you create a listing and before any purchase is confirmed. The fees are true economy sinks — they go to no one.

### If you are offline when it sells

Your 950 Pellets go into PendingCredits. The next time you log in, the amount is added to your balance automatically with a notification showing what you earned while away.

### Cancelling a listing

You can cancel any active listing at any time. Your compound is returned to your vault immediately. The listing fee is not refunded.

### Market stats per compound

- Lowest current listed price
- Total units currently available
- **Hot** badge if purchased in the last 10 minutes
- **High Supply** badge if 10 or more units are currently listed
- For variable-recipe compounds: an **Active Variant** marker showing whether this variant is the one the weekly seed currently produces by default — off-week variants are more expensive to produce (Stabilized Synthesis) and the market will price that in

### What cannot be listed

- Inert Residue (instant sell only — Section 12)
- Nothing else is restricted; any compound including Exotics and event compounds can be listed

### Researcher Rank from Market sales

1 point per 1,000 Pellets earned from completed Market sales (rounded down, minimum 1 point per sale), capped at 1,000 rank points per day from Market sales. Applies to both online and PendingCredits deliveries. Does not apply to Instant Sell. (Full rank rules in Section 18.)

-----

## 17. SYNDICATES — THE SOCIAL LAYER

A Syndicate is a group of up to 8 players (12 with the member-cap expansion) who collaborate to access higher tier compounds. Without a Syndicate your progression permanently caps at Tier 4.

### Creating a Syndicate

Free. Go to the Syndicate tab, tap Create, pick a name. You are the Founder with one member — yourself. This immediately unlocks Tier 5 synthesis. You do not need another player for T5.

### Inviting members

Officers and Founders can search for players by username and send invites. Online players receive the invite immediately. Offline players receive it on their next login. Target must not already be in another Syndicate.

### Roles and permissions

|Action                               |Member          |Officer         |Founder         |
|-------------------------------------|----------------|----------------|----------------|
|View Syndicate                       |✅               |✅               |✅               |
|Contribute to vault                  |✅               |✅               |✅               |
|Start / contribute to Joint Synthesis|✅ (if qualified)|✅ (if qualified)|✅ (if qualified)|
|Invite new members                   |❌               |✅               |✅               |
|Kick members                         |❌               |✅               |✅               |
|Spend communal vault                 |❌               |✅               |✅               |
|Promote to Officer                   |❌               |❌               |✅               |
|Rename the Syndicate                 |❌               |❌               |✅               |
|Disband the Syndicate                |❌               |❌               |✅               |

### The Communal Vault

Any member can contribute Pellets to the shared vault. Contributions are one-way — no withdrawals. Vault Pellets can only be spent by Officers or Founders on Syndicate upgrades (below). Contributing earns Researcher Rank at 1 point per 100 Pellets contributed, capped at 500 rank points per day per player from contributions. (Version 3’s rate of 0.5 points per Pellet is dead — with the 10M-Pellet vault upgrade now defined, that rate would have let one rich contribution buy 5,000,000 rank points and twenty Chief Scientist titles. The new rate plus the daily cap keeps contribution rank meaningful and non-degenerate. See Section 32.)

**If the Syndicate disbands:** The entire vault balance is permanently deleted. This is clearly disclosed before the Founder can confirm disband.

### Syndicate upgrades — what the vault buys

The Communal Vault is the economy’s primary endgame Pellet sink. Officers and Founders can purchase:

|Upgrade                   |Vault cost        |Effect                                                                                                                  |
|--------------------------|------------------|------------------------------------------------------------------------------------------------------------------------|
|Third Joint Synthesis slot|10,000,000 Pellets|Permanent. The Syndicate’s joint slot count goes from 2 to 3 — the only way to get a third slot                         |
|Syndicate Crest           |1,000,000 Pellets |A custom crest displayed beside every member’s name on leaderboards and patent announcements                            |
|Animated Crest            |2,500,000 Pellets |Upgrades the crest with animation. Requires Syndicate Crest                                                             |
|Broadcast Crest           |5,000,000 Pellets |The crest appears on the cross-server announcement whenever any member claims or takes a patent. Requires Animated Crest|

All upgrade purchases permanently delete the Pellets. Upgrades survive membership changes and Founder succession. If the Syndicate disbands, upgrades are lost with it.

### Expanding the member cap

200 Catalysts from the Founder’s personal balance — one-time, permanent — expands from 8 to 12 members. This affects membership only; it does not grant a joint slot (the third joint slot is exclusively a vault upgrade).

### Joint Synthesis — full rules

Joint Synthesis is the only path to Tier 6 and Tier 7 compounds. It runs in Syndicate-level joint slots — **every Syndicate has 2 joint slots** (3 with the vault upgrade). Joint slots are separate from personal slots and do not count toward the personal 10-slot cap.

**The qualification gate:** contributing to any Joint Synthesis requires that the account has personally, naturally completed **at least one Tier 4 synthesis** in its lifetime. Buying a T4 off the Market does not qualify you — you must have produced one. Qualification is permanent and survives Prestige. The Joint Synthesis UI shows unqualified members a locked state: *“Qualified researchers only — complete a Tier 4 synthesis.”*

**Why the gate exists — the alt-account problem, addressed honestly:** Version 3 claimed Tier 6 had “no workaround.” That claim was false: on Roblox, a free second account in your own Syndicate trivially satisfied “two distinct members.” No rule can make alts impossible. What a rule can do is make them expensive: the qualification gate means a functional Joint Synthesis alt costs weeks of genuine progression to T4 production — per alt — instead of five minutes of account creation. Legitimate players are unaffected, because reaching T4 production is the natural road to T6 anyway. Residual alt usage by players willing to fully level a second account is accepted as unpreventable; they are, at that point, genuinely playing two accounts.

**It requires two distinct accounts.** A solo Syndicate founder cannot fill both sides of a joint run. The joint slot UI shows “Waiting for a Syndicate partner” as a locked state rather than an empty slot, making the requirement self-documenting.

**What Joint Synthesis produces:**

|Input combination|Result                                                                                                       |
|-----------------|-------------------------------------------------------------------------------------------------------------|
|T4 + T5          |T6 compound (specific result determined by the pair’s recipe)                                                |
|T5 + T5          |T6 compound (specific result determined by the pair’s recipe)                                                |
|T6 + T6          |**Always a Tier 7 Exotic** — every T6+T6 pair generates one; there are no standard T6+T6 recipes (Section 23)|

**Staging is a declaration.** A joint pair does not physically exist until the second member contributes — possibly hours later — so validity cannot be checked against “the pair in the slot.” Instead, the opening member stages their compound AND declares the required partner compound: *“my T5 Zinc Polymer + a partner’s T4 Cascade Gamma.”* The slot accepts only the declared compound from contributors — which also fixes async coordination, since contributors see exactly what is needed instead of guessing. Validity is evaluated at the moment of declaration:

- **Declared pair already discovered by the declarer:** stages free, runs normally.
- **T6+T6:** always stages free — every T6+T6 pair is valid because every one produces an Exotic. If that Exotic has never been generated anywhere, the slot shows *“Unknown Exotic — completion will generate and discover it.”*
- **Undiscovered T4+T5 or T5+T5 pair:** the declaration is a **joint analysis attempt** — a 500-Pellet fee (300 from Prestige 1, under the standard 40% analysis discount), charged to the declarer.
  - **Invalid pair:** instant failure at declaration — the staged compound is returned, 6 Inert Residue granted, no staging occurs. Identical in shape to a Formula Lab failure; net cost 410 Pellets (210 at P1+).
  - **Valid pair:** the slot stages, flagged *“Confirmed reaction — product unknown.”* Completion — natural **or** Accelerated — discovers the recipe and the product’s identity for **both** members, each of whom receives one unit; an Accelerated discovery run still teaches and delivers, it just counts for nothing competitively (Section 14). Making it is discovering it — the same principle as variable-recipe variants (Section 7).

**The declaration fee is an information purchase and is never refunded** — not on cancellation of a validated staging, not on async expiry, not ever. A refund would make mapping the entire pair space free except for mis-clicks; the 500 Pellets buys the validity answer, and you keep the answer. To make that literal, a paid-for pair is permanently marked **Validated** in the declarer’s Formula Log: re-declaring a Validated pair never charges again, so non-refundability can never become double-billing. Validated marks are Formula Log entries and are wiped on Prestige like all discoveries — re-validation after a reset is part of the re-discovery economy. The fee is charged to the declarer only; a different member declaring the same still-undiscovered pair pays their own fee unless the pair has since been discovered (in which case it stages free for anyone who has the recipe).

There is still no such thing as a failed Joint Synthesis **run** — failure can only happen at declaration, never after a timer starts. Joint pairs are never reagent-variable; the weekly seed does not apply to Joint Synthesis. Declaring requires the T4 qualification like all joint-slot interaction. And yes — a rich Syndicate can map all ~710 candidate T4+T5/T5+T5 pairs for roughly 355,000 Pellets in declaration fees and publish the results. That is paid probing, it is intended, and it changes nothing: discovery has never been the gate at any tier. Production is.

**Why the Formula Lab can’t do this instead:** Lab analysis success delivers one unit of the result, so a Lab-discovered T6 recipe would hand over a solo-produced T6 — contradicting “Joint Synthesis only.” The Lab therefore refuses T4+T5, T5+T5, and T6+T6 pairs outright with *“Joint research required”* (Section 11). The discovering joint run, by contrast, is a genuine natural completion: it counts toward the 30-day window, can be the world first, and earns rank, Sprint points, and Flux for both members.

**The T4+T4 path is deleted.** Version 3 allowed T4+T4 → T5 via Joint Synthesis: a 24-hour run requiring a partner, versus the 8-hour solo T5 path. It was strictly dominated, never rational to use, and existed only to confuse the table. Tier 5 is solo-only; Joint Synthesis is exclusively the T6/T7 mechanism.

**Synchronous Joint Synthesis (standard — 24-hour timer):**

1. Member A opens a joint slot, stages their compound, and declares the required partner compound — their compound is removed from their vault immediately (validity is resolved at declaration; see above)
1. All online Syndicate members are notified
1. Member B (qualified) places the declared compound in the same slot — removed from their vault immediately
1. Timer starts: 24 hours
1. When complete, **both members receive one copy of the result compound**

**Asynchronous Joint Synthesis (when session overlap is impossible — 36-hour timer):**

1. Member A opens a joint slot in async mode, stages their compound, and declares the required partner compound — their compound is removed from their vault immediately (validity resolved at declaration; see above)
1. A 12-hour window opens during which any qualified Syndicate member can contribute the declared second compound, even while Member A is offline
1. If a second member contributes within the window, the timer starts at 36 hours (50% longer than synchronous)
1. If no one contributes within 12 hours, the staging expires and **Member A’s compound is returned to their vault**. The member who let a staging expire cannot open another async staging for 6 hours (this prevents notification spam from idle re-staging; it does not block synchronous runs). Version 3 destroyed the staged compound on expiry — that punished Member A for their Syndicate-mates’ absence, served no anti-exploit function, and is reversed in v4
1. When complete, both contributing members receive one copy of the result. An offline member’s copy is held and delivered on next login: *“Your Joint Synthesis completed while you were away.”*

**Summary:** Synchronous is always faster (24h vs 36h). Async removes the session-overlap requirement at the cost of a longer run. Time-zone-mismatched Syndicates can still reach T6.

**Cancellation rules:** The staging member can cancel before the second contribution arrives — the staged compound is returned. Once both have contributed and the timer is running, cancellation is not available for either member. This prevents griefing.

**Acceleration — the Accelerated flag:** The 30-Catalyst Joint Synthesis timer reduction (−25%) can be applied only by the member who opens the slot, at the moment of opening, before anyone else contributes. The slot is then visibly flagged **Accelerated** so the second contributor sees — before committing their compound — that the run will not count toward patents, the Weekly Sprint, Researcher Rank, or Flux for either member (Section 14). The compounds are still delivered to both members normally. TimerSkip and the 30-Catalyst instant skip cannot be applied to joint slots at all — the 25% reduction is the only purchasable acceleration for Joint Synthesis.

**Patent counting for joint runs:** a naturally completed Joint Synthesis adds +1 to the 30-day synthesis count of **both** contributing members for the result compound, and either member can trigger a first-claim if it is the world’s first natural completion (the member who opened the slot is recorded as the claimant; the partner is named in the Formula Log history entry as co-synthesizer and receives the same one-time Pellet bonus, Catalysts, and rank points — first claims on joint runs pay both members in full — the once-ever world-first package, Section 15).

**Every completion teaches both members.** Any completed joint run — discovery or routine, natural or Accelerated — adds the result’s recipe to **both** members’ Formula Logs if they do not already hold it. A contributor can never be in the absurd position of having personally produced a compound they could later be charged to “analyze.” Knowledge is never gated by the Natural Completion Rule (Section 14).

**Every natural completion pays both members the full production package.** A naturally completed joint run awards **each** contributing member the tier’s full Researcher Rank score (1,150 for T6, 1,500 for T7 — Section 18), the matching Weekly Sprint points, and the matching Flux during events. This is the explicit statement of the symmetry the rest of this section already follows — passive income, patent counts, world-first packages, and recipes are all paid double, and production score is no exception. The throughput bound is structural, not numeric: joint score rides on the Syndicate’s 2–3 shared slots, not on personal slots, so it cannot be scaled by individual wealth. Accelerated runs pay zero of this, as always (Section 14).

**Custody tiebreak:** when a joint completion takes custody of a released patent (Section 15), the member who opened the slot takes it — the same opener convention as world firsts.

### Two named social dynamics

These are designed pressures, not oversights:

**The siege.** A 7-day T6/T7 patent defense is fought on the Syndicate’s 2–3 **shared** joint slots. One member under serious siege consumes most of the group’s top-end throughput for a week. Syndicates will argue about whose defense is worth the slots. That argument is content.

**The trusted rival.** Every natural joint completion adds +1 to **both** members’ 30-day counts — so your regular defense partner is simultaneously accumulating a challenge-ready count on the very patent they are helping you hold. Rotate partners, or trust yours. The game will not protect you from your friends.

### Leadership succession

If the Founder is offline for 14 days:

- Longest-serving Officer is auto-promoted to Founder
- If no Officers: longest-serving Member is promoted
- If everyone is inactive: Syndicate stays dormant, no auto-disband, members can leave individually

-----

## 18. RESEARCHER RANK — YOUR PROGRESSION TITLE

Researcher Rank is your progression score. Your title — derived from your **current-run** score (see “Current-run score and lifetime score” below) — is displayed next to your username everywhere in the game: patent announcements, Syndicate member list, leaderboards, and your own HUD.

### Titles and thresholds

|Title          |Score needed|Approximate real-world timeline (dedicated player)|
|---------------|------------|--------------------------------------------------|
|Intern         |0           |Day 0                                             |
|Associate      |500         |Day 2                                             |
|Researcher     |3,000       |Day 7                                             |
|Senior         |12,000      |Day 17                                            |
|Principal      |40,000      |Day 30                                            |
|Director       |120,000     |Day 58                                            |
|Chief Scientist|250,000     |Day 85–90                                         |

A “dedicated player” is defined as someone who logs in daily, completes all five daily contracts, runs 5 slots continuously, actively uses the Formula Lab, and participates in the Market and patent system. Casual players (3–4 logins per week, contracts partially completed) should expect 6–8 months to reach Chief Scientist. Both timelines are intentional — rank should mean something. These thresholds are tuned against the score table below and are explicitly flagged for live recalibration in the launch economy audit (Section 30).

### How you earn score

Current-run score never decreases except on Prestige; lifetime score never decreases at all (see below).

**From production — and why the curve is shaped this way:**

|Tier           |Score per natural completion|Points per slot-hour|
|---------------|----------------------------|--------------------|
|T1 (extraction)|**0**                       |0                   |
|T2             |3                           |15                  |
|T3             |16                          |21.3                |
|T4             |85                          |28.3                |
|T5             |300                         |37.5                |
|T6             |1,150                       |47.9                |
|T7 Exotic      |1,500                       |62.5                |

The column that matters is **points per slot-hour**, and it strictly increases with tier. This is the rule the whole table is built around. Version 3’s per-synthesis values (1/3/8/20/50/120) looked progressive but were regressive per slot-hour — T1 spam earned 30 points per slot-hour against T6’s 5, making round-the-clock T1 farming six times more rank-efficient than endgame play and putting Chief Scientist ~56 days away through pure T1 spam. The v4 curve inverts that: every step up the tier ladder is a strict rank-efficiency upgrade, so the optimal rank strategy and the intended progression are the same thing. Extraction earns zero because extraction is industrial supply, not research — and because any nonzero value at a 2-minute cycle re-opens the spam exploit. Skipped and Accelerated runs earn zero (Section 14). Joint Synthesis production score is paid in full to both contributing members on natural completion (Section 17).

**From patents:** every world-first patent claim adds 500 points — paid once per compound ever, to the world-first claimant only (Section 15); transfers and reclaims award no claim rank. Successful patent defenses award tier-scaled rank:

|Compound tier|Rank per successful defense|
|-------------|---------------------------|
|T2           |25                         |
|T3           |50                         |
|T4           |100                        |
|T5           |150                        |
|T6 / T7      |250                        |

The scaling exists because a flat 250 was collusion-farmable: two friends ping-ponging a T2 patent — challenge, a few 12-minute re-defense runs, 7-day immunity, repeat across twenty low-tier patents — would mint free rank indefinitely. At 25 points a T2 defense is worth less than nine T2 syntheses’ production rank; low-tier collusion is now worthless, and high-tier collusion requires real 24-hour joint runs whose production rank dwarfs the bonus anyway. Claim rank stays flat at 500 — world firsts are finite (240 across base compounds and Exotics, plus a handful per seasonal event) and a T2 world first is still a world first.

**From Syndicate vault contributions:** 1 point per 100 Pellets contributed, capped at 500 points per day.

**From Market sales:** 1 point per 1,000 Pellets earned from completed Market sales (rounded down, minimum 1 per sale), capped at 1,000 points per day. Does not apply to Instant Sell.

**From daily contracts:**

|Contract difficulty|Score reward|
|-------------------|------------|
|Easy               |25 points   |
|Medium             |75 points   |
|Hard               |150 points  |

**From login streak milestones:**

|Streak milestone             |Bonus rank score|
|-----------------------------|----------------|
|Day 7                        |150 points      |
|Day 14                       |300 points      |
|Day 28                       |750 points      |
|Day 35 and every 7 days after|75 points       |

### Why rank rewards depth — for real this time

A dedicated mid-game player running five T4 slots earns ~3,400 production points/day; the same five slots on T2 earn ~1,800; on extraction, zero. Contracts add up to ~250–475/day, market sales up to 1,000/day capped, defenses and claims are event-sized injections. Rank accrual accelerates as you climb tiers — by design, by arithmetic, with no farmable shortcut at the bottom.

### Current-run score and lifetime score

You have two scores. **Current-run score** is everything described above: it determines your title, gates Prestige at 250,000, and resets to zero when you Prestige. **Lifetime score** is the running sum of every point you have ever earned across all runs: it never resets, and it is what the Chief’s Board ranks (Section 21). Both are visible on your profile; your title always reflects current-run score, displayed alongside your Prestige badge.

### The Prestige badge

When you Prestige, current-run score resets to zero but your Prestige badge is always visible alongside your title everywhere. Badge colors: Silver (P1) → Gold (P2) → Platinum (P3) → Crimson (P4) → Void (P5+).

-----

## 19. DAILY CONTRACTS — ACTIVE SESSION REWARDS

Five contracts appear on your Home screen every day, displayed below your slot panel. Three are standard difficulty. Two are harder optional bonus contracts. All five reset at midnight UTC regardless of completion. Incomplete contracts do not carry over.

**Skipped runs count toward contracts.** Contracts measure activity, not competition — a TimerSkipped synthesis satisfies “Synthesize 5 T2 compounds.” This is the deliberate counterweight to the Natural Completion Rule: purchased skips keep their full progression value here while being worthless in every competitive system.

### Contract examples

|Contract                                         |Difficulty|Pellet reward|Rank score reward|
|-------------------------------------------------|----------|-------------|-----------------|
|Synthesize 5 T2 compounds                        |Easy      |400 Pellets  |25 pts           |
|Complete 2 Formula Lab analyses                  |Easy      |300 Pellets  |25 pts           |
|Sell a compound instantly                        |Easy      |200 Pellets  |25 pts           |
|List 3 compounds on the Market                   |Medium    |600 Pellets  |75 pts           |
|Contribute 500 Pellets to your Syndicate vault   |Medium    |500 Pellets  |75 pts           |
|Complete a Joint Synthesis                       |Hard      |1,500 Pellets|150 pts          |
|Take a patent or successfully defend one of yours|Hard      |2,000 Pellets|150 pts          |
|Synthesize 3 T4 compounds                        |Hard      |1,800 Pellets|150 pts          |

Extraction-based contracts do not exist — contracts always target synthesis, the Lab, the Market, Syndicates, or patents.

**The pool is filtered by your state at generation.** Contracts are drawn at midnight UTC only from systems you can actually use at that moment: Syndicate contracts require membership, tier-targeted synthesis contracts require at least one discovered recipe producing that tier, Joint Synthesis contracts require the T4 qualification, and Lab/Market contracts require nothing (both are always available). A brand-new account draws from analyses, instant sells, and listings until its first recipes exist. There are no mid-day rerolls — if you leave your Syndicate at noon, the vault contract you drew at midnight simply goes unfinished. The patent contract reads “take or defend,” not “claim,” because world-first claims are once-ever events (Section 15) and a contract requiring one would be uncompletable in a mature game. The patent contract is offered only to players with at least one discovered T2+ recipe — the same possible-in-principle standard as every other filter. And that is the standard, stated plainly: **“possible in principle” is the filter’s guarantee; “completable today” is not.** The two harder contracts are optional bonuses by design, and a Hard patent contract that goes unfinished on a quiet day is working as intended.

**When generation actually happens (v4.5, E8):** “drawn at midnight UTC” is the rule for players online at midnight. An offline player has no server to draw on, so their five contracts are generated at their first login of each UTC day, filtered by their state at that moment, and then frozen — the no-mid-day-rerolls rule is preserved exactly. A player who does not log in on a given day simply has no contracts that day, which is the point: contracts measure active sessions.

**The full contract pool (v4.5, E9):** the table above is examples. The complete authored pool — 24 templates with exact targets, rewards, and the state filter each requires — lives in PRECIPICE_ECONOMY_MODEL.xlsx on the Contract_Pool sheet, alongside the slot draw rule: the three standard contracts are drawn from the Easy and Medium pools, the two bonus contracts from the Medium and Hard pools, no template repeating within a day. The draw weights keep the all-five daily rank bonus in this section’s stated 250–475 typical band.

### Reward ranges

|Difficulty|Pellet reward      |Rank score|
|----------|-------------------|----------|
|Easy      |200–500 Pellets    |25 points |
|Medium    |500–1,500 Pellets  |75 points |
|Hard      |1,500–3,000 Pellets|150 points|

With all five contracts completed, the daily rank bonus lands between roughly 250 and 475 points depending on the day’s mix — meaningful enough to reward consistent active play, not large enough to be the primary path to Chief Scientist.

### Why contracts exist

Two reasons. First, they give active players something concrete to work toward. Second, contracts involving Market or Syndicate actions pull players toward systems they may not have discovered yet — better onboarding than any tutorial.

-----

## 20. LOGIN STREAK — DAILY LOGIN REWARDS

Log in on consecutive days to earn escalating rewards. The streak window is 36 hours — not 24 — to account for real-life scheduling differences.

**How the 36-hour window works:** If you log in at 11:00pm Monday, your streak remains safe until 11:00am Wednesday. The streak UI shows the exact time remaining: *“Streak safe for 14h 22m.”* This countdown is visible on the Home screen any time you are within 12 hours of the window expiring.

### Reward table

|Day  |Reward                                                                            |
|-----|----------------------------------------------------------------------------------|
|1    |50 Pellets                                                                        |
|2    |100 Pellets                                                                       |
|3    |200 Pellets                                                                       |
|4    |200 Pellets                                                                       |
|5    |300 Pellets                                                                       |
|6    |300 Pellets                                                                       |
|7    |1 Catalyst + 150 Researcher Rank points                                           |
|8–13 |200 Pellets/day                                                                   |
|14   |2 Catalysts + 300 Researcher Rank points                                          |
|15–27|300 Pellets/day                                                                   |
|28   |5 Catalysts + 750 Researcher Rank points                                          |
|29+  |300 Pellets/day + 1 Catalyst every 7 days + 75 Researcher Rank points every 7 days|

Day 7 gives a Catalyst specifically because it makes completing a full week feel genuinely worth the habit for players who do not spend Robux. The Researcher Rank points at milestone days are the same values described in Section 18 — they are not separate bonuses, they are the same reward listed here for completeness.

If your streak breaks, the counter resets to 1 silently. No punishment message.

-----

## 21. LEADERBOARDS — WEEKLY SPRINT AND CHIEF’S BOARD

Both leaderboards are global and cross-server.

### The Weekly Sprint

Tracks who has earned the most **Sprint points** in the current 7-day window. Sprint points use the exact production score table from Section 18: a natural T2 completion is 3 points, a natural T6 completion is 1,150, and so on. Extraction earns zero. Skipped and Accelerated runs earn zero (Section 14).

Version 3’s Sprint counted raw synthesis volume — “every compound at every tier counts as one” — which made the contest a T1-spam race (720 per slot per day) that purchased skips could also inflate. Tier-weighted, natural-only scoring makes the Sprint measure what it claims to measure: a week of real research output. New players can compete within their first week through T2 volume; endgame players compete through depth.

Resets every Monday at midnight UTC — always after patent dividends have been paid and before the variable-recipe seed reroll takes effect for discovery purposes. The full Monday order of operations: **1) patent dividends fire, 2) Weekly Sprint archives and resets, 3) the variable-recipe seed rerolls.**

The Sprint tally is its own weekly counter, separate from rank score — a mid-week Prestige resets your current-run rank, not your current Sprint points.

**Display (revised in v4.5, E4):** Top 50 players, exact. Your own row is always visible below the list: your score is always shown; your exact rank is shown while you are within roughly the top 1,000; beyond that the row shows a close percentile estimate (“Top 4%”), refreshed hourly. Computing an exact rank for every player outside the top of a global board is not feasible on the platform, and a fresh percentile is more honest than a stale number.

**Rewards:** Top 3 players when the week ends receive a permanent cosmetic badge: *“Weekly Sprint Champion — [date].”* Never removed. The previous week’s top 3 are shown in a Hall of Fame section below the current leaderboard.

**How the reset works (revised in v4.5, E3):** Roblox servers can run for days, so waiting for a fresh server start would leave live players on a stale week. Every server checks the clock once a minute. When Monday midnight UTC passes, one server claims the weekly job through a shared lock and runs the full Monday sequence in the mandated order — dividends, then Sprint archive and reset (top 3 archived, badges awarded, scores cleared), then the variable-recipe seed change. The job is a ledger of steps, not a single act: each step is individually stamped with the week number as it completes, and the claim lock expires after a few minutes, so a server that dies mid-job is succeeded by the next claimant, which resumes from the first unstamped step and can never repeat a stamped one (v4.6, F1). Every other live server picks up the new week within a minute, whether or not it ever restarts; server start remains a backstop check, not the mechanism. The weekly variant seed itself is computed deterministically from the week number, so every server independently agrees on the active variants even before any coordination happens — the claimed job exists to run the side effects (payouts, archiving, the announcement), not to decide the seed.

### The Chief’s Board

Ranks **lifetime score** — the sum of all rank points earned across every Prestige run (Section 18). It never resets, because Prestige resets only current-run score; the two are different numbers and the board tracks the one that can’t go backward. The board shows each player’s lifetime score, current title, and Prestige badge. Top 100 players shown, exact; your own row follows the same display rule as the Sprint — exact rank within roughly the top 1,000, a percentile estimate beyond (v4.5, E4). Rewards long-term depth across runs — a P6 grinder outranks a single long first run, as it should.

-----

## 22. PRESTIGE — THE LONG-TERM RESET SYSTEM

When you reach Chief Scientist (250,000 Researcher Rank score) a Prestige button appears on your Home screen.

### What Prestige resets

|Item                               |Reset?          |Detail                                                                                                                                                                                              |
|-----------------------------------|----------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|Pellet balance                     |✅ Yes           |Resets to 500 Pellets                                                                                                                                                                               |
|Slots                              |✅ Yes           |Returns to base count (Prestige bonuses reapply immediately)                                                                                                                                        |
|Vault compounds                    |✅ Yes           |Vault cleared; you restart with 1 unit of each of the 5 starter T1 compounds                                                                                                                        |
|Formula Log                        |✅ Yes           |All discovered recipes wiped — including the 25 discoverable T1 extraction licenses — must rediscover everything. The 5 starter extraction licenses are baseline account features and always survive|
|Patents held                       |✅ Yes           |All released back to the global pool                                                                                                                                                                |
|Researcher Rank score (current-run)|✅ Yes           |Resets to 0. Lifetime score (the Chief’s Board number) is untouched — it never resets (Section 18)                                                                                                  |
|Weekly Sprint points               |❌ No            |The Sprint tally is its own weekly counter; a mid-week Prestige does not touch it (Section 21)                                                                                                      |
|30-day synthesis counts            |❌ No            |Production history, not Formula Log entries — your standing in every patent race survives (Section 15, v4.5 E6). The brake: you cannot synthesize anything until you rediscover its recipe          |
|Joint Synthesis qualification      |❌ No            |Lifetime — survives Prestige (Section 17)                                                                                                                                                           |
|Active market listings             |✅ Yes           |All auto-cancelled — compounds returned to vault, then wiped with the vault. Listing fees already paid are not refunded                                                                             |
|Catalysts                          |❌ No            |Real money — never resets                                                                                                                                                                           |
|Gamepasses                         |❌ No            |Permanent                                                                                                                                                                                           |
|Syndicate membership               |❌ No            |You stay in your Syndicate; vault contributions and upgrades are Syndicate property and untouched                                                                                                   |
|Login streak                       |❌ No            |                                                                                                                                                                                                    |
|Cosmetics owned                    |❌ No            |                                                                                                                                                                                                    |
|Prestige level                     |➕ Increases by 1|Never resets                                                                                                                                                                                        |

### What must be settled before you can Prestige — the in-flight ruling (v4.5, E5)

The Prestige button is disabled — with the live blockers listed on the button itself — while any of the following is true:

- Any of your personal slots is running an extraction or synthesis
- Any of your slots holds a completed run you have not yet revealed
- You have a compound staged in a Joint Synthesis slot that has not yet been matched
- You are a contributor to a Joint Synthesis run that is still in progress

Reveal your results, let your runs finish (or cancel them yourself, accepting the normal cancellation rules), and collect your joint results — then Prestige. The rejected alternative — automatically destroying or resolving in-flight production during the reset — silently deletes value the player committed without warning, and every such case becomes a support dispute. Blocking costs at most one day of finishing what you started, on an action taken a handful of times per year. Market listings and PendingCredits keep their automatic pre-reset handling (below) because their resolution returns value rather than destroying it.

### Formula Log wipe — re-discovery and the permanent fee reduction

When you Prestige, your Formula Log is wiped and you must rediscover every recipe from scratch. This is the point — each Prestige is a speedrun of the same content with better tools.

Starting at Prestige 1, Formula Lab analysis fees are permanently reduced by 40% across all tiers (25 → 15, 75 → 45, 200 → 120). This reduction applies immediately at the start of your P1 run and does not stack further at higher Prestige levels — it is a flat 40% reduction in effect permanently from P1 onward. Residue amounts are unchanged. The re-discovery experience — input handling, the 30-second bar, the discovery unit grant — is identical to a first run.

### Market and pending money at Prestige — full ruling

When you press Prestige and reach the confirmation screen, **all active market listings are automatically cancelled and their compounds returned to your vault** as the first step, before you confirm. Any PendingCredits that exist are paid out to your Pellet balance in the same pre-reset step. Then the reset wipes the vault and sets your balance to 500. Any market sale that completes in the brief window between initiating the sequence and the pre-reset step finishing is captured in that PendingCredits payout. No Pellets from market activity are silently lost during a Prestige — they are paid, then reset with everything else, which is what Prestige means.

### Prestige cost — full scaling table

|Level|Cost                |Notes                                              |
|-----|--------------------|---------------------------------------------------|
|1    |500,000 Pellets     |                                                   |
|2    |1,500,000 Pellets   |                                                   |
|3    |4,000,000 Pellets   |                                                   |
|4    |10,000,000 Pellets  |                                                   |
|5    |25,000,000 Pellets  |                                                   |
|6    |45,000,000 Pellets  |                                                   |
|7    |60,000,000 Pellets  |                                                   |
|8+   |Previous cost × 1.25|Cap on multiplier — does not exceed ×1.25 per level|

**Why the multiplier drops to 1.25× from P8 onward:** Pellets reset at Prestige, so every run must earn its own cost in-run — and the economy model showed that a ×1.6 cost multiplier outruns income growth per level (~+10–15%) badly enough that P7 at 80M projected ~145 days and P8 at 128M projected ~197 days, violating the 120-day commitment below. The v4.3 costs (P6 45M, P7 60M, ×1.25 onward) bring P6–P8 to a projected ~107–115 days. P9 and beyond are projected to creep past 120 days even at ×1.25 (~130 days at P9) under baseline income assumptions; those levels are explicitly governed by the telemetry patch commitment rather than pre-tuned, because endgame income is the least certain number in the model and the P9+ population is vanishingly small.

**Both gates apply every cycle:** every Prestige requires Chief Scientist rank (250,000 — earned fresh each run) AND the Pellet cost. Early Prestiges are gated mostly by rank; later Prestiges mostly by Pellets. Both gates are covered by the same pacing commitment:

**Economy audit target:** Each Prestige run should take approximately 60–90 days for a dedicated player. If economy telemetry after launch shows any Prestige level taking longer than 120 days for the median dedicated player — whether the binding constraint is the rank gate or the Pellet cost — the binding number for that level is reduced in a patch. This is a live-service commitment. P9+ are expected to invoke it under baseline projections (see the cost-table note above); that is the lever working as designed, not a failure of it.

### What you permanently gain per Prestige level

|Level|Badge          |Permanent bonus                                        |
|-----|---------------|-------------------------------------------------------|
|1    |Silver         |+1 slot forever + 40% Formula Lab fee reduction forever|
|2    |Gold           |+10% passive income multiplier forever                 |
|3    |Platinum       |+1 slot forever                                        |
|4    |Crimson        |+3.6 hours added to offline income cap forever         |
|5    |Void           |+1 slot forever + Void facility aesthetic unlocked     |
|6+   |Void (numbered)|+5% passive income per additional level                |

**Slot hard cap reminder:** The maximum slots regardless of Prestige bonuses is 10. The ExpandedLab gamepass (+2) and Prestige slot bonuses all count toward this cap. Without ExpandedLab, P1+P3+P5 brings you to 8 slots. ExpandedLab (7 base) + P1 + P3 + P5 = 10 — the hard cap. The gamepass is required to reach the maximum.

**Income multipliers stack:** The P2 +10% multiplier and all P6+ +5% multipliers stack multiplicatively with each other and with all other income multipliers (seasonal event multipliers, etc.).

### Why you would Prestige

Your patents release back into the global pool. An announcement fires to every player: *“alrightdespite has entered Prestige 1 — 12 patents have been released. The race begins again.”* RACE indicators reappear. Released patents go to the next natural completion — custody only, with no one-time package, and rivals’ existing 30-day counts are waiting (Section 15). Releasing and re-claiming your own patents earns nothing one-time; the dividend stream is the only thing at stake. Your second playthrough is faster than your first: more slots, 40% cheaper discovery, and you already know the recipes. Each Prestige is a speedrun of the same content with better tools.

### The confirmation

Pressing Prestige opens a full-screen overlay listing exactly what resets and what you gain. Then a second screen: *“Are you sure? This cannot be undone.”* Two taps required.

-----

## 23. EXOTIC COMPOUNDS — TIER 7

Exotic compounds are Tier 7 compounds that emerge from endgame Joint Synthesis. No developer creates them — the game generates them procedurally from player actions.

### How they are produced

Only through T6+T6 Joint Synthesis — and **every** T6+T6 pair generates an Exotic. There are no standard T6+T6 recipes: the ~15 authored T6-result recipes are exclusively the T4+T5 and T5+T5 bootstrap paths (Sections 7, 17). The first time any pair of players completes a given T6+T6 combination, the server generates a brand new compound that has never existed before — unique name, unique value, its own patent available to claim. Both contributing members receive one unit (every joint run pays both members — Section 17).

### What an Exotic looks like

Each Exotic has a procedurally generated name from a three-part system. Examples: “Trans-chromate IX”, “Meta-titanate Prime”, “Hyper-zirconate Omega.” Initial base value: 250,000–800,000 Pellets. Passive income per slot: 60 Pellets/min. Synthesis time: 24 hours via Joint Synthesis only.

### Exotic value decay — the scarcity rule

An Exotic’s base value is not fixed. It decays as global supply grows:

**Current base value = initial value × 0.97^(total units of this Exotic ever created, game-wide), floored at 25% of the initial value.**

Every joint run of an Exotic pair creates 2 units (one per member), so each run multiplies that Exotic’s value by 0.97² ≈ 0.941. After ~24 runs (48 units) the value hits the 25% floor — 62,500 to 200,000 Pellets. A floored low-end Exotic (62,500) sits at the bottom of the T6 range (60,000–100,000) — intentionally comparable to a good T6, because a heavily mass-produced novelty is no longer novel. Floored high-end Exotics (200,000) remain clearly above every T6.

The current value is what Instant Sell pays, and what the Market’s 80%/500% bounds reference at the moment of listing — bounds are checked at listing creation only, and a legally created listing stays purchasable even as decay moves the base value underneath it (Section 16, v4.5 E7). The Exotic Registry and every reveal card display the current value live.

**Why decay exists:** without it, a Syndicate that found one Exotic pair could re-run it forever as a flat money printer — 2 units in the 250–800k range every 24 hours per joint slot, indefinitely. Decay makes novelty itself the valuable resource: the big money is in producing *new* Exotics early, exactly the behavior the Tier 7 system exists to reward. The 0.97 constant and 25% floor are economy-spreadsheet parameters flagged for live tuning (Section 30).

**What decay does not touch:** the weekly patent dividend (flat 200,000 Pellets regardless of decay) and the one-time claim bonus (3× the *initial* value, locked at generation).

### The same pair always produces the same Exotic

Two pairs of players who independently run the same T6+T6 combination will generate the same compound. The first natural completion claims the patent. The others receive units but not the bonus — and see: *“Someone else patented this compound moments before you — the race is now on.”*

### How many Exotics can exist

With 15 T6 compounds there are exactly 120 distinct T6+T6 combinations — 105 mixed pairs plus 15 same-compound pairs (T6a+T6a is a valid declaration; the two units come from two different members). Each combination generates exactly one Exotic. They emerge slowly over months as Syndicates invest in T6+T6 runs. Maximum 120 Exotics total in any game instance.

### Exotics are terminal

Cannot be used as synthesis inputs, cannot be declared in joint slots, and cannot be selected as Formula Lab analysis inputs (Section 11). T7+T7 does not generate T8. The chain ends at 7. Terminal means terminal.

### The Exotic seed table — how generation is implemented

The compound database carries a seeded table of all 120 T6+T6 combinations with their Exotic names and initial values. That table IS this section’s “the server generates” — implemented as a deterministic lookup on a pair’s first completion, which guarantees name uniqueness and stable values with zero runtime generation complexity. The doc’s example names occupy real slots in that table. This is the implementation of the rule above, not a change to it.

### The Exotic Registry

A global section at the bottom of the Formula Log shows every Exotic ever generated — name, tier badge, current value, total units in existence, and who first synthesized it. Visible to all players even those far from T6. Creates aspiration.

### Exotics and patents

Exotic patents are fully contestable via the 30-day rolling window and the 7-day T6/T7 defense window. Weekly dividends at 200,000 Pellets/week. Released through Prestige. Claim bonus and rank points per Section 15.

-----

## 24. COSMETICS — HOW YOUR LAB LOOKS

Cosmetics change the visual appearance of your facility and HUD. Zero gameplay effect. No cosmetic is Robux-exclusive — all are reachable through Pellets, Catalysts, or progression.

### Lab Skins

|Name               |Cost                          |
|-------------------|------------------------------|
|Industrial Standard|Free (default)                |
|Arctic Research    |500 Pellets                   |
|Carbon Black       |1,200 Pellets                 |
|Oxidized Copper    |80 Catalysts                  |
|Gold Standard      |200 Catalysts                 |
|Void               |Automatic unlock at Prestige 5|
|Industrial Hazmat  |Cascade Protocol event pass   |

**Note on Void:** The Void lab skin is a real, complete aesthetic that exists in the game at launch. It can be previewed — but not equipped — from the Lab cosmetics tab at any Prestige level. Reaching Prestige 5 unlocks it permanently.

### Particle Sets

|Name             |Cost                          |
|-----------------|------------------------------|
|Standard Emission|Free (default)                |
|Neon Burst       |300 Pellets                   |
|Ember Cascade    |150 Catalysts                 |
|Void Particles   |Automatic unlock at Prestige 5|

### HUD Accent Color

|Name         |Cost          |
|-------------|--------------|
|Blue-White   |Free (default)|
|Biosafe Green|200 Pellets   |
|Lab Amber    |100 Pellets   |
|Hazard Red   |100 Catalysts |
|Gold         |150 Catalysts |

### Patent Stamp Style

|Name        |Cost                       |
|------------|---------------------------|
|Standard    |Free (default)             |
|Minimal     |250 Pellets                |
|Broadcast   |200 Catalysts              |
|Cascade Seal|Cascade Protocol event pass|

### Syndicate Crests

Syndicate-level cosmetics (Crest, Animated Crest, Broadcast Crest) are purchased from the Communal Vault with Pellets — see Section 17. They are Syndicate property, not personal cosmetics.

### Equipping cosmetics

Open the Lab tab (sixth icon in the navigation bar). Browse, purchase, equip. Personal cosmetic selections (lab skin, particles, HUD accent, patent stamp) are visible only to you. Syndicate crests are the exception — they display publicly beside member names per their upgrade tier.

-----

## 25. ROBUX PURCHASES — WHAT YOU CAN BUY

Robux buys time, not advantage. Every purchase is deterministic — you know exactly what you are getting. No loot boxes. No random outcomes. No power free players cannot eventually reach. And under the Natural Completion Rule (Section 14), no purchase touches any competitive metric: patents, the Weekly Sprint, Researcher Rank, and Flux are earned exclusively through natural play. This claim is now structurally true, not just marketing — every product below is defined so that it cannot violate it.

### Gamepasses (one-time, permanent)

|Gamepass       |Price    |What it does                                                                                                                                       |
|---------------|---------|---------------------------------------------------------------------------------------------------------------------------------------------------|
|ExpandedLab    |800 Robux|+2 slots (5 → 7 base). Counts toward the 10-slot hard cap. Required to reach the 10-slot maximum — Prestige bonuses alone max at 8 slots without it|
|ExtendedOffline|400 Robux|Offline income cap doubles (12h → 24h)                                                                                                             |
|CompoundArchive|600 Robux|One synthesis use of each archived event-exclusive compound per calendar month. See full rules below                                               |

**CompoundArchive — full rules:**

- Each calendar month (midnight UTC on the 1st), CompoundArchive holders receive one synthesis use for each event-exclusive compound that has been archived. This is a synthesis use — not the compound itself. The use includes temporary access to that compound’s recipe (its blueprint expired with the event); you still supply the listed inputs and run the slot timer normally.
- The synthesis use expires at the end of the month if unused.
- CompoundArchive does not grant patents on event compounds by itself. Event patent rules apply normally (Section 29). A naturally completed archive-use synthesis counts toward the 30-day window when the contested system is open for that compound — so an archive holder can mount or defend a challenge during event re-runs, one unit per month.
- CompoundArchive does not grant access to event compounds that have not yet occurred. It only covers archived compounds (events that have already ended).
- The value: 600 Robux justifies access to the full catalog of past event content with a modest monthly drip. Original event participants retain their stockpile advantage permanently — CompoundArchive holders can never mass-produce event compounds.

### Developer Products (repeatable)

|Product      |Price    |What you get                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
|-------------|---------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|TimerSkip    |75 Robux |Instantly complete one personal slot (extraction or synthesis). The result is delivered normally and counts toward daily contracts, but never toward patents, the Weekly Sprint, Researcher Rank, or Flux (Section 14). Cannot be applied to Joint Synthesis slots                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
|CatalystS    |200 Robux|50 Catalysts                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
|CatalystL    |500 Robux|150 Catalysts (better value)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
|Rush Analysis|100 Robux|3 uses. Each use applies to one Formula Lab analysis: the result is instant (skips the 30-second bar), the Pellet analysis fee is waived, and if the pair is reagent-variable and undiscovered, the **primary** variant is delivered regardless of the current weekly seed. Rush Analysis does NOT change discovery outcomes — an invalid pair still fails (instantly, with Residue, fee waived). While a use is armed, the Analyze button glows gold and reads “Rush Analysis — active”. Like all discovery grants, a Rush discovery is competitively invisible — it can never produce a patent claim or any competitive credit (Section 11), so purchased discovery can never touch a world first. Rush Analysis applies to personal Formula Lab analyses only — it can never be applied to, or waive the fee of, a joint analysis declaration (Section 17)|

**Why Rush Analysis replaced v3’s PremiumAnalysis:** PremiumAnalysis guaranteed that your next attempt discovered a valid recipe even when the chosen pair had none — the server would invent an appropriate result. That is, verbatim, selling a compound recipe for 100 Robux, in direct contradiction of the “never sold” list below. No rewording could fix it, because any product that alters discovery *outcomes* sells recipes. Rush Analysis sells only speed (instant result), convenience (fee waived), and determinism on variable pairs (primary variant). Discovery outcomes are untouched. The product is honestly weaker, and that is the price of the never-sold list being true.

### What is never sold

- Pellets directly
- Patent rights — and patent-counting syntheses (no purchase can add to a 30-day window or claim a world first)
- Compound recipes — and discovery outcomes of any kind
- Researcher Rank score
- Weekly Sprint points or Flux
- Market advantages
- Anything with a random outcome

-----

## 26. THE LOADING SCREEN

A loading screen appears immediately when the game launches and stays until your full data is ready. While it is active the server is calculating offline income, completing offline runs, and preparing your vault and balances.

**What you see:**

- PRECIPICE logo centered on a dark industrial background
- A thin progress bar filling as your data loads
- A rotating tagline — one of:
  - *“The patent won’t wait.”*
  - *“First in the world. Every time.”*
  - *“Your lab never sleeps.”*

If loading exceeds 8 seconds the bar pulses and shows: *“Syncing your lab…”*

When ready, the loading screen fades out and the Home screen fades in. You never see a half-loaded UI.

-----

## 27. NEW PLAYER EXPERIENCE — FIRST SESSION

**Loading screen.** Logo, industrial background, tagline. Bar fills. Fades to Home.

**Home screen.** Five slots labeled *“Slot idle — tap to start.”* Balance: 100 Pellets. Vault: 1 unit of each of the 5 starter compounds. A single ambient line appears for 6 seconds: *“Your lab is ready. Tap a slot to start extracting.”* No popup. No tutorial. No forced flow.

**Player taps a slot.** The extraction picker opens showing the 5 starter compounds. Player picks one. A 2-minute timer starts (1:36 with the online bonus, which is active because they are here).

Within 10 seconds of loading the player understands the base loop: pick a compound, the slot produces it, wait.

**~2 minutes later.** First extraction completes. Slot glows. Player taps it. Reveal animation plays. Keep or Sell. Production loop understood.

**The second beat — the Lab.** With slots running, the contextual prompt appears: *“Try the Formula Lab while you wait →.”* The player opens the Synthesize screen, picks two compounds from their vault (they have the 5 starting units plus whatever they’ve extracted), and sees the Analyze button with its 25-Pellet fee. They have 100 Pellets. Most first attempts fail — instantly, with inputs returned and Residue granted — and a few succeed, delivering a brand new compound on the spot. Discovery loop understood: extraction feeds experimentation, experimentation unlocks synthesis.

**Systems reveal progressively based on actions, never on a timer:**

- All slots full → contextual prompt appears (Formula Lab → Market → Leaderboard in sequence, with Leaderboard only after Syndicate join/creation)
- After first Formula Lab use → tier system hint
- After Day 7 → Syndicate hint
- After first patent → patent mechanics hint

Each hint: single dismissable line at the bottom, auto-dismisses in 6 seconds, never shown twice.

**If a seasonal event is active when the player joins for the first time:**
A single additional ambient line appears on the Home screen on their first login during the event: *“The [Event Name] is running. Synthesize compounds to earn Flux and unlock event compounds.”* This line is dismissable, auto-dismisses in 8 seconds, and is only shown once. It is not a popup — same visual language as all other contextual hints.

-----

## 28. EVERY WAY TO EARN PELLETS

1. **Passive slot income** — Every active extraction or synthesis slot earns Pellets per minute by tier, running continuously online and offline up to the cap. Joint Synthesis runs pay both members the T6/T7 rate on top
1. **Instant selling compounds** — From the reveal card or the vault, any compound, any time, at 100% of current base value
1. **Player-to-player Market sales** — List compounds at your price (1% listing fee), earn when another player buys (minus the 5% sale fee). Offline sales delivered via PendingCredits on next login
1. **Patent claim bonuses** — One-time Pellet bonus when you are first globally to naturally synthesize a compound
1. **Weekly patent dividends** — Every Monday, current patent holders receive a Pellet payout by compound tier
1. **Inert Residue sales** — Every failed Formula Lab combination produces Residue worth 15 Pellets each (instant sell only)
1. **Login streak rewards** — 50–300 Pellets per day based on current streak day
1. **Daily contract rewards** — 200–3,000 Pellets per contract, five contracts per day
1. **PendingCredits on login** — Offline Market sales, dividends, and event milestone rewards delivered automatically on every login

(Version 3’s item “Formula Lab consolation payouts” is gone — the consolation mechanic was deleted along with the input loss it compensated for, Section 11.)

-----

## 29. SEASONAL EVENTS — THE CASCADE PROTOCOL

The Cascade Protocol is the first seasonal event. It launches Day 20 from public release — timed to bridge the T3→T4 progression window when casual players most commonly churn.

### Event parameters

|Detail           |Value                            |
|-----------------|---------------------------------|
|Duration         |21 days                          |
|Event currency   |Flux                             |
|Income multiplier|1.5× all passive income          |
|Shared milestone |Community Flux target (see below)|
|Milestone reward |25 Catalysts per player          |
|Event pass       |400 Robux                        |

### The event pass — exact contents

The Cascade Protocol event pass (400 Robux, valid for this event run) contains:

- The **Industrial Hazmat** lab skin (permanent)
- The **Cascade Seal** patent stamp style (permanent)
- **2× Flux earn rate** for the duration of the event
- **10 Catalysts**, delivered immediately on purchase

Nothing in the pass touches patents, rank, or the Sprint — doubled Flux accelerates blueprint access only, and blueprints are the event’s progression content, not a competitive metric. (Flux purchases blueprints; the patent race on event compounds is still fought with natural syntheses that anyone with the blueprint can run.)

### Event-exclusive compounds

|Name           |Tier|Synthesis time|Base value    |Blueprint cost|
|---------------|----|--------------|--------------|--------------|
|Cascade Trace  |2   |12 minutes    |120 Pellets   |50 Flux       |
|Cascade Alpha  |3   |45 min        |550 Pellets   |300 Flux      |
|Cascade Beta   |3   |45 min        |620 Pellets   |300 Flux      |
|Cascade Gamma  |4   |3 hours       |2,800 Pellets |1,200 Flux    |
|Cascade Delta  |4   |3 hours       |3,100 Pellets |1,200 Flux    |
|Cascade Epsilon|5   |8 hours       |14,000 Pellets|4,000 Flux    |
|Cascade Omega  |5   |8 hours       |17,000 Pellets|4,000 Flux    |

Each blueprint lists its specific required inputs (standard base compounds of the tier below; the exact pairs are specified in the compound database’s Event_Compounds sheet, and Cascade Trace’s inputs are deliberately two starter compounds so a day-one player can produce it) and adds the recipe to your Formula Log for the event’s duration. Event compounds follow all standard rules of their printed tier — Cascade Trace is a Tier 2 compound in every mechanical respect; it bypasses normal T1+T1 discovery only because its blueprint is its discovery.

### Earning Flux

**Flux earned per natural synthesis completion equals that synthesis’s Researcher Rank score value** (Section 18): a T2 completion earns 3 Flux, a T3 earns 16, a T4 earns 85, and so on. The same monotonic points-per-slot-hour curve that protects rank protects Flux — there is no low-tier spam route to event currency.

**Extraction earns 1 Flux per natural completion, capped at 50 Flux per day from extraction.** This exists purely for accessibility: a brand-new player who cannot yet synthesize anything can reach the Cascade Trace blueprint (50 Flux) within their first day of the event, and Trace synthesis (3 Flux each, uncapped) carries them from there. The cap means extraction can bootstrap event participation but never compete with synthesis as a Flux source. **Caps are applied after all multipliers:** the event pass’s 2× Flux (and any future multiplier) never raises the 50/day extraction ceiling — extraction Flux stops at 50 regardless. This is the general rule for every cap in the game: multipliers scale earnings, never limits.

Skipped and Accelerated runs earn zero Flux (Section 14). The event pass 2× multiplier applies to all Flux earned. After the event ends, unspent Flux has no value.

### The shared milestone

A progress bar on the Home screen tracks **total Flux earned by the entire community** across all players and servers. The target is computed at event start from active-population telemetry, calibrated so that the community is projected to reach it at roughly 60% participation effort — reachable with broad engagement, not trivial on day one. (Version 3’s fixed “10,000 syntheses” target was off by orders of magnitude for any healthy population — one dedicated player could clear it solo in days. A telemetry-set Flux target scales with the actual playerbase and cannot be trivialized by low-tier volume.) When the target is hit, every player receives 25 Catalysts — immediately if online, via PendingCredits if offline.

### Event patents — full rules

Event compound patents work differently from base game patents. The rules depend on whether the event has been run before.

**During the first run of an event:**

- The first player globally to naturally synthesize each event compound claims its patent normally, with the standard claim bonus, 5 Catalysts, and 500 rank points
- Event patents during their first run are permanent and uncontestable — since the compounds cannot be synthesized after the event ends, the normal contested mechanic cannot apply
- Weekly dividends apply normally for as long as the patent is held
- The world-first claim package for an event compound is paid during its first run only, once per compound ever — re-run takeovers convey the patent and its dividends, never the package (Section 15)

**Between event runs:**

- Event patents remain permanent and uncontestable between runs
- The holder collects weekly dividends undisturbed with zero challenge risk
- This is the intended reward for being first — a stable, guaranteed income stream until the event returns
- **Acknowledged magnitude:** A T5 event patent holder (Cascade Epsilon or Cascade Omega) earns 60,000 Pellets/week during a gap between runs. Over a 26-week gap (approximately 6 months between seasons), that is 1,560,000 Pellets of guaranteed risk-free income. This is the deliberate design intent — being first globally on a T5 event compound is a significant, lasting achievement and is compensated accordingly. Re-run cadence is targeted at approximately every 6 months per event.

**During a future re-run of the same event (e.g. Cascade Protocol Season 2):**

- Event compounds become synthesizable again for the duration of the re-run (blueprints purchasable with the new season’s Flux; previously purchased blueprints reactivate for the window)
- The contested patent system reopens fully for event compounds during the re-run window, using the standard tier-scaled defense windows and post-defense immunity from Section 15
- Existing holders must defend normally using the 30-day rolling window
- New players have a genuine opportunity to claim event patents for the first time
- When the re-run ends, patents return to permanent-uncontestable status until the next re-run

**Ruling on first-run vs re-run patent claims:** The all-time Formula Log history entry for who first synthesized each event compound permanently records the first-run claimant. If a new player takes the patent during a re-run, the “current holder” field updates but the “first claimed by” entry does not change.

**Prestige and event patents:** Prestiging releases event patents back to the global pool exactly like base compound patents. If the event is not currently running, a released event patent has no holder and no RACE indicator — it simply shows as unclaimed gold border with no synthesis path. When the event next runs, the RACE indicator activates for that compound.

### After the event

Event compounds archived permanently. Visible in Formula Log as locked silhouettes with the event name and season. Players with the CompoundArchive gamepass can synthesize one unit per month per archived compound (Section 25).

-----

## 30. ECONOMY AUDIT COMMITMENTS

This section exists because every major v3 failure was a cross-system failure: each system balanced against itself, none balanced against its neighbors. These commitments make the cross-system audit a permanent practice, not a one-time fix.

### Pre-launch: the faucet/sink model

Before launch, the economy model (PRECIPICE_ECONOMY_MODEL.xlsx, Game_Economy sheet) must model total Pellet creation against total Pellet destruction at 1,000 / 10,000 / 100,000 daily active users.

**Faucets:** Instant Sell payouts (the largest faucet by far — every compound has a guaranteed 100%-of-base exit), passive slot income, patent claim bonuses, weekly dividends (~3.25M/week game-wide when all 120 base T2–T6 patents are held, plus up to 24M/week from a fully generated 120-Exotic registry), contract rewards, streak rewards, event milestone payouts.

**Sinks:** the 5% Market sale fee, listing fees, Formula Lab analysis fees, Prestige costs, cosmetic purchases, Syndicate vault upgrades (the designed endgame sink — Section 17).

The economy model showed what the model must actually demonstrate — and it is not “sinks absorb faucets,” which is impossible in this genre: passive income alone outstrips every fee sink combined, and the economy runs a structural per-player surplus (~5,000–8,000 Pellets/player/day at maturity) by design, because numbers going up is the genre. The real requirement is threefold: (1) **Prestige absorbs per-player surplus within tolerance** — the surplus of exactly the players who accumulate it funds their Prestige cycles on the committed pacing; (2) the 80%/500% Market price bounds keep aggregate surplus from inflating player-to-player prices; (3) vault upgrades absorb Syndicate-level surplus at the top end. Fee sinks pace behavior (listing spam, analysis brute-force); they were never going to balance the books and are not asked to.

### Pre-launch: parameters explicitly flagged for tuning

These numbers are designed in this document but must be validated in the spreadsheet before launch and re-validated against telemetry after:

- Researcher Rank production values and title thresholds (Section 18) — the monotonic points-per-slot-hour property is non-negotiable; the integers are tunable
- Formula Lab fees vs the cheaper v4 failure costs — with inputs returned on failure and extraction free, the fee is the only brake on brute-force discovery; if T2/T3 discovery completes too fast in practice, fees rise
- T1 extraction value range (10–25) vs zero input cost
- Exotic decay constant (0.97) and floor (25%)
- Blueprint Flux prices and the extraction Flux cap (50/day)
- Joint Synthesis passive income paying both members the full tier rate
- The joint analysis declaration fee (500; 300 at P1+) and the tier-scaled defense rank values (25/50/100/150/250)
- The Catalyst economy — modeled for the first time in v4.5 (Catalyst_Economy sheet). Free Catalysts are deliberately scarce (~8–9/month steady state for a streak-keeping non-payer including event milestones); the flag exists to watch whether Catalyst-priced features (joint acceleration, member-cap expansion, premium cosmetics) see near-zero engagement from non-paying players. First tuning lever: the streak steady-state rate, before any price cuts
- The contract pool’s draw weights and reward values (Contract_Pool sheet, v4.5 E9)

### Post-launch: standing telemetry commitments

- Any Prestige level taking the median dedicated player longer than 120 days gets its binding gate (rank or cost) reduced in a patch (Section 22)
- Median days-to-Chief-Scientist tracked against the 85–90 day target; production score table rebalanced if it drifts beyond 70–110
- Patent challenge volume per tier tracked; if T2–T3 churn is noisy even with post-defense immunity, immunity extends before any other lever moves
- Game-wide weekly dividend total tracked against game-wide weekly sink total; if dividends outrun sinks at maturity, vault upgrade pricing extends (new tiers) before dividend rates are cut

### The standing rule for future design changes

Any new system, product, or reward must be checked against this list before it ships: Does it create Pellets, and which sink absorbs them? Does it touch a 30-day patent count, Sprint points, rank, or Flux — and if so, does it respect the Natural Completion Rule? Can extraction, alts, or purchased skips farm it? Can it move value between accounts? A “no” is required on every line.

-----

## 31. THE WORLD — SERVERS, PLOTS, AND THE PHYSICAL LAB

Every prior version described the game’s systems and screens but never said what the game physically is — how many players share a server, whether your lab is a real place or a menu, what the camera does. Everything in the map, the reveal staging, and half the UI hangs on those answers. Version 4.5 defines them (Part E, E11).

### Servers

8 players per server. Every economic and social system — the Market, patents, Syndicates, leaderboards, announcements — is cross-server, so server size is a social and performance decision, not an economic one. Eight is enough ambient life that a server never feels dead, and small enough that performance is never the constraint. Syndicate-mates never need to share a server for anything, including Joint Synthesis — joint slots are Syndicate records, not physical places (below).

### Plots and the lab

Each player spawns onto their own plot holding their lab: the same interior for everyone, built once, instanced per plot, reskinned by their cosmetics. There is no plot selection, no plot upgrading, and no building — the lab is the stage, not the game.

### Chambers are slots

The lab’s physical extraction/synthesis chambers ARE your slots. The room is built with all 10 chambers present; chambers for slots you have not unlocked stand dark and inactive — the slot cap is legible at a glance, and Prestige and ExpandedLab have visible, physical payoffs. Tapping a chamber and tapping its HUD slot are the same action.

### Reveals happen at the chamber

Section 13’s sequence is staged physically: the wing lights dim, the spotlight hits the completed chamber, the pulses and particles play there, and the result card rises over it. This is what makes a reveal filmable as a 15-second vertical clip of a place rather than a screen recording of a menu.

### Other players

Other players’ labs are visible and walkable. Per Section 24, personal cosmetics render only for their owner — a visitor sees the default Industrial Standard lab — and Syndicate crests are the public exception. Visibility exists for ambient life and Syndicate recruiting, not for inspection.

### Joint slots are not in the world

Joint Synthesis slots belong to the Syndicate and live on the Syndicate screen (Sections 7, 17). They have no physical chamber in anyone’s lab. The two contributors are usually on different servers; the run exists as a shared record, not a shared room.

### Camera, controls, and mobile parity

Standard Roblox third-person avatar and camera. No custom camera. The entire game is operable from the HUD alone — every chamber interaction has a 2D equivalent — because the UI is the game and the world is the stage. Full mobile parity from day one; this document’s “tap” language is literal.

### Why plots, and not the alternatives

A single shared room makes simultaneous reveals collide and gives the player nothing that is theirs. Fully private instancing gives ownership but kills ambient social proof and the recruiting surface, and adds teleport plumbing for zero gain. Plots are the cheapest model in which the reveal moment happens in a world the player owns while other people visibly exist.

-----

## 32. PROBLEMS AND SOLUTIONS — EVERY DESIGN DECISION MADE

This is the complete decision log. **Part A** documents the v4 cross-system audit — the problems found in Version 3 and the rulings that fixed them. **Part B** explicitly lists every v3 ruling that Version 4 superseded, so no stale rule survives by omission. **Part C** carries forward every v3 ruling that remains in force, with updated numbers noted where v4 changed them. **Part D** holds the v4.1–v4.4 rulings, **Part E** holds the v4.5 implementation-seam rulings, and **Part F** holds the v4.6 hardening rulings. If a rule is not in Part B, C, D, E, or F, it does not exist.

-----

### PART A — THE V4 CROSS-SYSTEM AUDIT

Version 3 balanced each system against itself. None were balanced against their neighbors. Every problem below is a cross-system failure: two or more individually-coherent rules producing a broken outcome where they meet.

-----

**PROBLEM A1: The base resource loop was undefined — the economy had no floor.**
Every synthesis consumed 2 compounds and produced 1, and T1 synthesis inputs were never specified anywhere in the document. Either T1 consumed inputs (and the economy strictly depleted toward zero) or it didn’t (and was an unacknowledged free faucet). The document never said which.
**SOLUTION:** Tier 1 production is **Extraction** — a distinct process generating T1 compounds from nothing. Zero inputs, zero Pellet cost, 2-minute timer, 1 unit per run. The thematic split (extraction = industrial supply, synthesis = research) is load-bearing: it justifies zero inputs, justifies zero Researcher Rank (A5), and justifies the 1-Flux event cap (A24). The 5 starter compound licenses are permanent and survive Prestige. Full rules in Section 6.

-----

**PROBLEM A2: The new player experience contradicted the game’s own rules.**
The v3 first session had the player “pick any two compounds” and a synthesis started. But two unknown compounds is a Formula Lab *analysis* under the game’s rules — fee, discovery bar, possible failure — not a synthesis. The very first thing a new player did was mechanically impossible.
**SOLUTION:** NPE rewritten around extraction. First tap → choose ONE starter compound → 2-minute extraction begins → reveal. Second beat: a contextual prompt introduces combining two compounds in the Formula Lab. Extraction → synthesis is now taught as a progression instead of being conflated. The first session is simpler than v3’s and contains zero rule violations. Full sequence in Section 27.

-----

**PROBLEM A3: The patent system was pay-to-win, contradicting the game’s stated monetization pillar.**
TimerSkip (75 Robux) and the 30-Catalyst instant skip delivered completed syntheses — and synthesis count was the patent win metric. A whale could buy a patent war outright. This directly contradicted “Robux buys time, not advantage” and would be review-bombed by the target 18–34 demographic.
**SOLUTION:** **The Natural Completion Rule (Section 14)** — one global rule: a synthesis counts toward patent 30-day windows, the Weekly Sprint, Researcher Rank, and event Flux only if its timer ran to natural completion. The online speed bonus and Stabilized Synthesis count as natural (they are timers running to completion). TimerSkip, Catalyst skips, and the Accelerated joint flag do not count — the compound is still delivered and still feeds your vault, contracts, and economy, but never a competitive metric. Skipped runs still satisfy daily contracts (contracts are personal engagement, not competition). Robux now purchases progression speed and zero competitive advantage, surgically.

-----

**PROBLEM A4: PremiumAnalysis literally sold recipes.**
The 100-Robux product “guarantees discovery even if no natural recipe exists for the chosen pair” — the server would invent a result. That is a recipe sale, in verbatim contradiction of the “never sold” list in the same document. No rewording could fix it: any product altering discovery *outcomes* sells recipes.
**SOLUTION:** PremiumAnalysis deleted. Replaced by **Rush Analysis** (100 Robux, 3 uses): instant result (skips the 30-second bar), Pellet fee waived, and the primary variant guaranteed on undiscovered variable pairs regardless of the weekly seed. Invalid pairs still fail (instantly, with Residue, fee waived). It sells speed, convenience, and determinism — never outcomes. The product is honestly weaker than PremiumAnalysis; that is the price of the never-sold list being true. Full rules in Section 25.

-----

**PROBLEM A5: Researcher Rank math was inverted — T1 spam was the optimal rank strategy.**
V3’s per-synthesis values (1/3/8/20/50/120) were monotonic per synthesis but regressive per slot-hour: T1 earned 30 points/slot-hour against T6’s 5. Round-the-clock T1 farming was six times more rank-efficient than endgame play and reached Chief Scientist in ~56 days of mindless spam.
**SOLUTION:** Extraction (T1) earns **zero** rank — extraction is not research. T2–T7 rescaled so points per slot-hour strictly increase with tier: 3 / 16 / 85 / 300 / 1,150 / 1,500 per natural completion (15 → 21.3 → 28.3 → 37.5 → 47.9 → 62.5 per slot-hour). Thresholds rescaled to match: Associate 500, Researcher 3,000, Senior 12,000, Principal 40,000, Director 120,000, Chief Scientist 250,000 — Day 85–90 for the dedicated player, 6–8 months casual. The monotonic per-slot-hour property is non-negotiable; the integers are flagged for spreadsheet validation (Section 30). Full table in Section 18.

-----

**PROBLEM A6: The Weekly Sprint was a T1-spam contest by construction.**
The Sprint metric was raw synthesis count. A 2-minute T1 cycle beat a 24-hour T6 run 720-to-1. The “most syntheses this week” crown would always go to whoever ran T1 longest.
**SOLUTION:** Sprint metric changed to **tier-weighted points** — the same production score table as Researcher Rank — counting T2 and above, natural completions only. Extraction is excluded for the same reason it earns no rank. New players can compete within week one via T2 volume. Full rules in Section 21.

-----

**PROBLEM A7: The NPC floor buyer was strictly dominated and therefore useless.**
The floor buyer paid 70% of base for T4+ compounds, while Instant Sell paid 100% for the same compounds at any time. No rational player would ever use the floor buyer. It also carried a Day-60 removal, removal comms, and bait-and-switch perception risk — all for a feature with zero use cases.
**SOLUTION:** Floor buyer **deleted entirely**. Instant Sell is universal — any compound, from the vault, at any time, at 100% of base value — and explicitly named as the economy’s liquidity floor and primary Pellet faucet. The launch-liquidity problem the floor buyer was meant to solve is solved better by Instant Sell with no expiry date, no comms plan, and one less system to build. Full rules in Section 16.

-----

**PROBLEM A8: The 80% Market price floor’s stated purpose was dead, but the floor itself is essential.**
With Instant Sell at 100%, the 80% floor does nothing as an economic floor — nobody lists below 100%’s equivalent rationally. But deleting it would open the real hole: underpriced listings are how alt accounts gift value to mains and how RMT moves Pellets between accounts.
**SOLUTION:** The 80% floor and 500% ceiling are kept and their purpose **rewritten honestly**: they are anti-transfer dampeners. Floor + ceiling + the 5% sale fee limit the efficiency of moving value between accounts through the Market. The doc names this function explicitly so the floor is never deleted as “redundant” later. Full reasoning in Section 16.

-----

**PROBLEM A9: The recovery-percentage tables lied about what failure cost.**
V3’s “recovery %” counted only the analysis fee and ignored the destroyed input compounds. A failed T3+T3 was presented as “~100% recovery” while actually destroying ~875–1,475 Pellets of committed value for ~75 back (~6% true recovery). The framing was wrong and the system underneath felt terrible.
**SOLUTION:** The system was fixed instead of the framing: **failed analyses return both inputs unharmed.** Failure costs exactly the fee minus residue value: net 10 / 45 / 15 / 110 Pellets by tier bracket (the cheap T3 bracket is intentional — T3 is the experimentation tier). The 20% consolation Pellet mechanic is deleted; it compensated for a loss that no longer exists. Successful analyses consume both inputs and deliver the recipe plus one unit of the discovered compound — discovery hands you the recipe AND your first specimen. Brute-force mapping becomes purely Pellet-gated, which is acceptable: the patent system was never built on secrecy (Section 11). Full tables in Sections 11–12.

-----

**PROBLEM A10: Inert Residue was listable on the Market “at a fixed price” that was never defined — and nobody would ever buy it.**
Residue is terminal with zero uses. Listings would be pure UI clutter with an undefined price rule.
**SOLUTION:** Residue **cannot be listed on the Market**. Instant sell at 15 Pellets flat is its only exit. Section 12.

-----

**PROBLEM A11: Variable recipes delivered ~21 one-time discoveries, not the perpetual tension Section 10 claimed.**
V3 let the player choose the output variant once both were known — so after both discoveries, the weekly seed did nothing forever. The system’s entire stated purpose (keeping a wiki-documented game uncertain) lasted exactly two discoveries per pair.
**SOLUTION:** **The weekly seed governs synthesis output forever.** Synthesizing a variable pair produces the active weekly variant by default; synthesizing when the active variant is undiscovered discovers it. Forcing a discovered-but-inactive variant requires **Stabilized Synthesis: timer ×1.5** (counts as natural — it is a longer timer running to completion). Consequences: variant supply shifts weekly, variant prices oscillate with the seed, and defending a patent on a variant compound costs 50% more time on its off-weeks — permanent strategic texture in the patent wars. Rush Analysis’s primary-variant guarantee stays coherent. Full rules in Section 7.

-----

**PROBLEM A12: A free alt account trivially defeated the Tier 6 gate, and the doc claimed otherwise.**
“Two distinct Syndicate members” was the only T6 requirement, and v3 claimed this had “no workaround.” On Roblox, a second free account in your own Syndicate satisfies it in five minutes. The claim was false.
**SOLUTION:** The false claim is removed and the gate made expensive instead of pretending it is impossible: **Joint Synthesis requires lifetime qualification — at least one personally, naturally completed T4 synthesis** (purchased T4s don’t qualify; qualification survives Prestige). A functional alt now costs weeks of genuine progression per alt. Legitimate players are unaffected — T4 production is the natural road to T6. Residual alting by players who fully level second accounts is accepted as unpreventable; at that point they are genuinely playing two accounts. Full ruling in Section 17.

-----

**PROBLEM A13: The number of Joint Synthesis slots per Syndicate was never specified.**
Per-member? Per-Syndicate? Unbounded? The answer determines Syndicate-level T6/T7 throughput, Exotic generation rates, and the entire top-end economy.
**SOLUTION:** **2 joint slots per Syndicate**, +1 purchasable from the Communal Vault for 10,000,000 Pellets (the only way to a third). The 200-Catalyst member expansion affects membership only and grants no slot. Joint slots are Syndicate property, separate from personal slots. Section 17.

-----

**PROBLEM A14: The T4+T4 → T5 joint path was strictly dominated and existed only to confuse.**
24 hours with a required partner versus the 8-hour solo T5 path. Never rational to use.
**SOLUTION:** **Deleted.** Tier 5 is solo-only. The joint table is exactly: T4+T5 → T6, T5+T5 → T6, T6+T6 → Exotic. Section 17. (As originally ruled, T6+T6 could also yield a standard T6 result; that branch was deleted in v4.1 — Part D, D2.)

-----

**PROBLEM A15: Invalid joint pairs had an unspecified failure state — possibly a 24-hour run ending in nothing.**
**SOLUTION:** The failure state is deleted rather than ruled on: **invalid pairs cannot be staged.** The joint slot UI only accepts pairs forming valid recipes. Joint pairs are never reagent-variable. There is no such thing as a failed Joint Synthesis. Section 17.
**Mechanism superseded in v4.1 (Part D, D3):** a pair does not exist until the second contribution, so validity is now evaluated at declaration time via declaration staging; undiscovered T4+T5/T5+T5 declarations are paid joint analyses, and every T6+T6 now resolves to an Exotic (D2). The principle — no failed joint runs — survives intact.

-----

**PROBLEM A16: Exotics were an infinite value printer.**
2 T6 inputs → 2 Exotic outputs (one per member) at 250,000–800,000 Pellets base value each, re-runnable forever. Repeatable runs of any discovered Exotic mint unbounded top-end value.
**SOLUTION:** **Exotic value decay:** each Exotic’s current base value = initial value × 0.97^(total units ever created game-wide), floored at 25% of initial. Scarcity premium — novel compounds are valuable because they’re novel. The one-time claim bonus (3× initial value) and the weekly dividend (flat 200,000) are untouched by decay; only base/market/Instant-Sell value decays. The 0.97 constant and 25% floor are flagged for spreadsheet tuning (Section 30). Full rules in Section 23.

-----

**PROBLEM A17: Async Joint Synthesis destroyed the staged compound on expiry.**
If no Syndicate-mate contributed within 12 hours, Member A’s compound — potentially a T5 or T6 worth tens of thousands of Pellets — was destroyed. This punished Member A for other people’s absence and served no anti-exploit purpose.
**SOLUTION:** Expired stagings **return the compound to Member A’s vault.** A 6-hour async re-staging cooldown for the member whose staging expired prevents idle notification spam (synchronous runs are not blocked). Cancellation before second contribution also returns the compound; after both contribute, no cancellation (anti-griefing). Section 17.

-----

**PROBLEM A18: T6/T7 patent defense was mathematically unwinnable.**
The flat 72-hour defense window physically could not contain more than three 24-hour joint runs. Any challenge deficit ≥ 4 at T6/T7 was unanswerable regardless of effort. The defense window was theater.
**SOLUTION:** **Tier-scaled defense windows:** T2–T3: 72h, T4: 96h, T5: 120h, T6/T7: 7 days (up to 7 natural completions per joint slot — a genuinely contestable race). Section 15. (Originally written T1–T3; T1 patents were removed entirely in v4.1 — Part D, D1.)

-----

**PROBLEM A19: Low-tier patents were an infinite challenge treadmill.**
At a 2-minute T1 cycle, a challenger who lost a defense could re-trigger a fresh challenge within minutes, forever, with a global announcement each time.
**SOLUTION:** **Post-defense immunity: 7 days per compound** after a successful defense. Counts keep accruing for everyone during immunity — it delays the alarm, not the race. One defense buys one week of peace. Section 15.

-----

**PROBLEM A20: Multi-party patent races had no resolution rule.**
The challenge system was framed as 1v1 (holder vs named challenger), but a third party could overtake both during a window. Who wins?
**SOLUTION:** **The expiry ruling:** when a defense window expires with the holder behind, the patent goes to whoever holds the highest 30-day natural count at that exact moment — named challenger or third party. The challenge notification is just the alarm; the count decides. Ties favor the current holder. Section 15.

-----

**PROBLEM A21: Decay-triggered challenges were 3am ambushes.**
A holder’s count silently aging out of the 30-day window could trigger a challenge with zero warning while they slept.
**SOLUTION:** **Decay projection UI:** every held patent’s detail view shows your current count, the top rival’s count, and — when your lead is shrinking — *“At current decay, your lead expires in N days.”* Decay challenges remain possible (they are how inactive holders lose patents); attentive holders always see them coming. Section 15.

-----

**PROBLEM A22: Patent announcements would become global spam at scale.**
Every transfer at every tier fired cross-server. At maturity, T1–T3 patents churn constantly — global noise.
**SOLUTION:** **Announcement scoping:** first claims are global at every patentable tier (finite, genuine world events). Transfers are global only at **T4+**; T2–T3 transfers notify the two parties and the Formula Log only. All global announcements pass through a queue with a minimum 30-second gap. Section 15. (Originally written T1–T3; T1 patents were removed in v4.1 — Part D, D1.)

-----

**PROBLEM A23: The Synthesize/Analyze button arbitration was unspecified, and synthesis’s Pellet cost was never stated.**
One screen serves both systems. What does the button do for each pair state? And does synthesis itself cost Pellets? (It was never said.)
**SOLUTION:** **The context-aware button table (Section 11):** undiscovered pair → “Analyze — [fee]”; discovered pair → “Synthesize”; variable pair → “Synthesize” with a variant panel (active variant default, Stabilize toggle for discovered inactive variants, undiscovered active variant labeled as discoverable); fully-exhausted non-variable pair → Analyze never offered again. And stated explicitly in Section 8: **synthesis costs no Pellets — inputs and time only.** Extraction costs nothing at all. Cancelling a running synthesis loses the inputs; cancelling an extraction loses nothing.

-----

**PROBLEM A24: The event’s shared milestone (10,000 syntheses) was off by orders of magnitude and T1-trivializable.**
One dedicated player could clear 10,000 syntheses solo in days of T1 spam. For any healthy population the target was meaningless.
**SOLUTION:** Metric changed to **total community Flux** (Flux already tier-scales), with the target computed at event start from active-population telemetry, calibrated to ~60% projected participation effort. **Extraction earns 1 Flux, capped at 50/day** — enough to bootstrap a brand-new player to the Cascade Trace blueprint (50 Flux) on day one, never enough to compete with synthesis as a Flux source. Reward: 25 Catalysts to every player. Section 29.

-----

**PROBLEM A25: Market listing expiry destroyed the compound.**
Destruction punished only inattention — free cancellation existed for anyone paying attention — generating support tickets and rage-quits, not economic value.
**SOLUTION:** Expired listings **return the compound to the vault.** The lost sink is replaced with a better one: a **non-refundable listing fee of 1% of asking price (minimum 1 Pellet)** charged at listing creation — a real sink that also deters listing spam. Section 16.

-----

**PROBLEM A26: Syndicate vault upgrades were referenced but never defined — and the endgame had no recurring Pellet sink.**
The vault said Pellets buy “Syndicate upgrades” that existed nowhere. Separately, aggregate weekly dividends inject millions of Pellets game-wide at maturity with no sink for established patent-holders who aren’t actively Prestiging.
**SOLUTION:** The **vault upgrade catalog (Section 17)** solves both: Third Joint Synthesis slot 10,000,000 · Syndicate Crest 1,000,000 · Animated Crest 2,500,000 · Broadcast Crest 5,000,000. All purchases permanently delete the Pellets. The vault is named as the economy’s primary endgame sink, routing dividend inflation into the social layer. The audit commitment (Section 30): if dividends outrun sinks at maturity, new vault tiers are added before dividend rates are cut.

-----

**PROBLEM A27: The vault contribution rank rate became catastrophic the moment vault upgrades were priced.**
V3’s 0.5 rank points per Pellet contributed × a 10M-Pellet upgrade = 5,000,000 rank points from one donation — twenty Chief Scientist titles for being rich.
**SOLUTION:** Rate changed to **1 point per 100 Pellets, capped at 500 rank points per day per player.** Contribution rank stays meaningful and non-degenerate. Section 18.

-----

**PROBLEM A28: The 400-Robux event pass had undefined contents.**
A priced product with no contents cannot ship.
**SOLUTION:** Defined (Section 29): Industrial Hazmat lab skin (permanent), Cascade Seal patent stamp (permanent), 2× Flux earn rate for the event run, 10 Catalysts.

-----

**PROBLEM A29: Joint Synthesis passive income, world-first credit, and the Accelerated flag’s consent were all unspecified.**
Who earns passive income during a 24-hour joint run? Who is the claimant on a world-first joint completion? Can the slot-opener silently waste their partner’s compound on a non-counting Accelerated run?
**SOLUTION (Section 17):** Both members earn full tier-rate passive income for the entire run. A natural joint completion adds +1 to **both** members’ 30-day counts; on a world first, the opener is recorded as claimant, the partner is named co-synthesizer in history, and **both receive the full one-time bonus, Catalysts, and rank points.** The −25% Catalyst acceleration can only be applied by the opener at staging time and visibly flags the slot **Accelerated** before the second member commits — informed consent that the run won’t count competitively. TimerSkip and instant skips cannot touch joint slots at all.

-----

**PROBLEM A30: Every v3 failure above was a cross-system failure, and nothing prevented the next one.**
Rank × timers, monetization × patents, Instant Sell × floor buyer, alts × Joint Synthesis, vault pricing × contribution rank — each system was fine alone and broken in combination.
**SOLUTION:** **Section 30 — Economy Audit Commitments** — is now a permanent part of this document: a pre-launch faucet/sink model at three population scales, an explicit list of tuning-flagged parameters, post-launch telemetry commitments with named corrective levers, and a standing checklist every future feature must pass (Does it create Pellets — which sink absorbs them? Does it touch a competitive metric — does it respect the Natural Completion Rule? Can extraction, alts, or skips farm it? Can it move value between accounts?).

-----

### PART B — VERSION 3 RULINGS SUPERSEDED BY VERSION 4

Each entry names the dead v3 rule and the live v4 rule that replaced it. These v3 rules are void everywhere, including anywhere a stale copy of them survives in PRECIPICE_DOCS.

|#  |Dead v3 ruling                                                                                          |Live v4 replacement                                                                                                                                                                                                                                                                        |
|---|--------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|B1 |Emergency restock system (auto-grant of 5 starter T1s on zero-resource state, 24h cooldown, bypass rule)|**Deleted — soft-lock is impossible.** Extraction generates compounds from nothing at zero cost, and starter licenses are permanent. The state the restock guarded against cannot occur (Section 6)                                                                                        |
|B2 |NPC floor buyer (70% of base, T4+, Day-60 removal, Day-45 announcement)                                 |**Deleted**, including the removal-comms ruling. Universal Instant Sell at 100% is the liquidity floor (Section 16, A7)                                                                                                                                                                    |
|B3 |Consolation Pellets on failed analysis (20% of fee: 5/15/40) and all “recovery %” tables                |**Deleted.** Inputs are returned on failure; net failure cost is fee minus residue (Section 11, A9)                                                                                                                                                                                        |
|B4 |Failed analysis consumes input compounds                                                                |**Inputs returned unharmed** (Section 11)                                                                                                                                                                                                                                                  |
|B5 |PremiumAnalysis (guaranteed discovery, invented recipes)                                                |**Rush Analysis** — instant result, fee waived, primary variant on variable pairs, outcomes untouched (Section 25, A4)                                                                                                                                                                     |
|B6 |Skipped syntheses count toward patents, Sprint, and rank                                                |**The Natural Completion Rule** — they count toward none of them, nor Flux (Section 14, A3)                                                                                                                                                                                                |
|B7 |Weekly Sprint metric = raw synthesis count                                                              |**Tier-weighted points, T2+, natural only** (Section 21, A6)                                                                                                                                                                                                                               |
|B8 |Rank production values 1/3/8/20/50/120 (T1–T6) and thresholds tuned to them                             |**0/3/16/85/300/1,150/1,500** (T1–T7) and thresholds 500/3k/12k/40k/120k/250k (Section 18, A5)                                                                                                                                                                                             |
|B9 |Rank from streak milestones 50/100/250/25 and defenses 75                                               |**150/300/750/75** and defenses **250**; contracts now 25/75/150 (Section 18)                                                                                                                                                                                                              |
|B10|Vault contribution rank at 0.5 points per Pellet, uncapped                                              |**1 point per 100 Pellets, 500/day cap** (Section 18, A27)                                                                                                                                                                                                                                 |
|B11|Choose-your-variant rule once both variable results known                                               |**Weekly seed governs synthesis output forever; Stabilized Synthesis (×1.5) forces discovered variants** (Section 7, A11)                                                                                                                                                                  |
|B12|T4+T4 → T5 Joint Synthesis path                                                                         |**Deleted; T5 is solo-only** (Section 17, A14)                                                                                                                                                                                                                                             |
|B13|Async staging expiry destroys the staged compound                                                       |**Compound returned; 6-hour async re-staging cooldown** (Section 17, A17)                                                                                                                                                                                                                  |
|B14|Flat 72-hour defense window at all tiers                                                                |**Tier-scaled: 72h/96h/120h/7d** (Section 15, A18)                                                                                                                                                                                                                                         |
|B15|No post-defense protection                                                                              |**7-day post-defense immunity per compound** (Section 15, A19)                                                                                                                                                                                                                             |
|B16|All patent transfers announced globally                                                                 |**Transfers global at T4+ only; first claims global at all tiers; 30-second announcement queue** (Section 15, A22)                                                                                                                                                                         |
|B17|Market listing expiry destroys the compound; listing is free                                            |**Expiry returns the compound; 1% non-refundable listing fee (min 1 Pellet)** (Section 16, A25)                                                                                                                                                                                            |
|B18|Inert Residue listable on the Market “at a fixed price”                                                 |**Not listable; instant sell 15 only** (Section 12, A10)                                                                                                                                                                                                                                   |
|B19|Event shared milestone = 10,000 syntheses                                                               |**Community Flux target set from telemetry at event start (~60% projected effort)** (Section 29, A24)                                                                                                                                                                                      |
|B20|T6 gate claimed to have “no workaround”                                                                 |Claim retracted; **T4 lifetime qualification gate** makes alting expensive, residual alting acknowledged (Section 17, A12)                                                                                                                                                                 |
|B21|“~20 T1+T1 recipes” and v3 recipe-count framing by input tier                                           |Recipe density restated **by result tier**: ~25 T1-result, ~40 T2, ~50 T3, ~45 T4, ~30 T5, ~15 T6 ≈ 205 standard recipes + up to 120 Exotics (count corrected in v4.1, ruling D2; Section 7). T1+T1 lab combinations producing new T1s remain valid and are part of the ~25 T1-result count|
|B22|T1 compounds produced by synthesis with unstated inputs                                                 |**T1 = Extraction, zero inputs** (Section 6, A1)                                                                                                                                                                                                                                           |
|B23|NPE: “pick any two compounds, synthesis starts”                                                         |**Pick one starter compound, extraction starts** (Section 27, A2)                                                                                                                                                                                                                          |
|B24|Online speed bonus described as ambiguous vs skips                                                      |Classified explicitly: **online bonus and Stabilized Synthesis are natural; all purchased skips are not** (Section 14)                                                                                                                                                                     |

-----

### PART C — VERSION 3 RULINGS CARRIED FORWARD (STILL IN FORCE)

Every ruling below survives into v4 unchanged unless an updated number is noted. Cross-references point at v4 sections.

**C1 — Loading screen.** Full join-process cover: PRECIPICE logo, industrial background, progress bar, rotating taglines, “Syncing your lab…” past 8 seconds (Section 26).

**C2 — Tutorial popup: rejected.** Adults skip popups. “Slot idle — tap to start” label, loading-screen taglines, and the single 6-second ambient hint bar carry the teaching load (Sections 26–27).

**C3 — Rotating contextual prompt** below the slot panel: Formula Lab → Market → Leaderboard, each once per session, 8-second auto-dismiss, Leaderboard suppressed until Syndicate membership exists (Sections 11, 27).

**C4 — Contested patent redesign.** One patent per compound, 30-day rolling natural-count window, challenge triggers the instant anyone surpasses the holder (decay-triggered challenges included), live race during the window, inactive holders decay out naturally. Defense windows now tier-scaled per B14 (Section 15).

**C5 — Three-tier patent system (Pioneer/Specialist/Master): removed.** One patent per compound, no sub-tiers (Section 15).

**C6 — New players vs entrenched holders: intentional.** Target inactive holders’ decaying counts or live higher-tier races. Fair in both directions — and under the Natural Completion Rule, nobody can buy past you (Section 15).

**C7 — Online speed bonus.** 20% faster synthesis while in-game; base displayed timer is the online speed; offline runs 20% slower. T6/T7 joint runs excluded (no pressure to camp 24-hour timers). Applies to the Formula Lab bar (30s → 24s, adjusted time not displayed). Counts as natural (Sections 9, 14).

**C8 — Five daily contracts.** Three standard + two harder bonus, 200–3,000 Pellets each, rank score now 25/75/150 per B9, midnight UTC reset, passively teaches undiscovered systems. Skipped syntheses still satisfy contracts (Sections 14, 19).

**C9 — Vault deleted on disband.** Permanently, with explicit pre-confirmation disclosure to the Founder. Vault upgrades are also lost on disband (Section 17).

**C10 — Founder succession.** 14 days inactive → longest-serving Officer promoted; no Officers → longest-serving Member; all inactive → dormant, no auto-disband, individual leaves allowed (Section 17).

**C11 — T5 access and location.** Creating a solo Syndicate fully satisfies the T5 requirement. T5 runs on personal slots (Home/Synthesize screen); the Syndicate screen holds only joint slots for T6/T7 (Sections 8, 17).

**C12 — Patent reveal context.** “FIRST IN THE WORLD” under “PATENT CLAIMED,” competition count = players who discovered the recipe AND completed ≥1 synthesis of it in the last 7 days, floating bonus animations, cross-server “⬡ WORLD FIRST” announcement (Sections 13, 15).

**C13 — Long-term content: three layers.** Contested patents are never locked; Prestige releases patents to the pool; up to 120 procedural Exotics require zero developer content (count per v4.1 ruling D2; Sections 15, 22, 23).

**C14 — Rank from varied behaviors.** Market sales (1 pt/1,000 Pellets, now capped 1,000/day), streak milestones, defenses, contracts all feed rank — values updated per B8/B9 (Section 18).

**C15 — Dual rank timeline.** Dedicated Day 85–90, casual 6–8 months, both documented and intentional (Section 18).

**C16 — Monday order ruling.** Dividends fire first, Weekly Sprint reset second, variable-recipe seed reroll third. Always that order, never simultaneous (Sections 15, 21, 7).

**C17 — Dividend timing at transfer.** Holder at the exact firing moment gets paid; lose it before midnight and that week pays nothing; defenses resolving after midnight are not retroactive (Section 15).

**C18 — 80% floor / 500% ceiling, repurposed per A8.** T1 minimum listing 8–20 Pellets; Residue’s 15 remains a fair lowest-tier baseline (Section 16).

**C19 — Prestige Step 1 protections.** Active listings auto-cancelled and compounds returned, PendingCredits paid out, all before any reset begins. Nothing is silently lost (Section 22).

**C20 — Exotic race-condition feedback.** The losing player sees *“Someone else patented this compound moments before you — the race is now on,”* keeps their compound, and can challenge (Section 23).

**C21 — Prestige cost pacing.** Each run targets roughly constant wall-clock time; live-service commitment to patch any level exceeding 120 median dedicated days (Sections 22, 30). **Costs recalibrated in v4.3 (Part D, D21):** P6 45M, P7 60M, ×1.25 from P8 — the original 50M/80M/×1.6 values failed the commitment in the economy model.

**C22 — Recipe sharing is fine.** The patent system’s value is timing, not secrecy; wikis are expected within days; variable recipes keep the ground shifting (Sections 11, 7).

**C23 — Async Joint Synthesis exists** for time-zone-mismatched Syndicates: 12-hour contribution window, 36-hour run (vs 24 synchronous), offline delivery of results. Expiry behavior updated per B13 (Section 17).

**C24 — Simultaneous challenge cap.** Max 3 active challenge windows per holder across all challengers; further challenges queue; **v4 addition: queued challenges re-validate on activation** — if the would-be challenger no longer leads, the queued challenge dissolves without opening a window (Section 15).

**C25 — Event patents are run-based.** Uncontestable between runs (compounds unsynthesizable), fully contested when the event re-runs, stable dividends between runs as the first-mover reward — magnitude explicitly acknowledged as deliberate. Prestige releases event patents; released event patents sit unclaimed with no RACE indicator until the event next runs (Section 29).

**C26 — Solo founders and joint slots.** Two distinct accounts required; the slot shows “Waiting for a Syndicate partner” as a self-documenting locked state — plus the v4 qualification gate per A12 (Section 17).

**C27 — CompoundArchive gamepass.** One synthesis per archived event compound per calendar month — a trickle that never competes with original holders’ stockpiles; patents contestable per the normal system when synthesizable (Sections 25, 29).

**C28 — Offline income partial-run ruling.** Accrues logout-to-completion (or cap), only offline time counts, worked multi-slot example retained — 5,437 Pellets in the Section 10 example — including the floor income and offline cap rules (Section 10).

**C29 — Streak countdown visibility.** Home-screen countdown whenever within 12 hours of the 36-hour window expiring: *“Streak safe for 14h 22m”* (Section 20).

**C30 — Cascade Trace, Tier 2.** Standard T2 stats (12 min, 120 Pellets), blueprint-unlocked via Flux (50) with no prior T2 discovery required, all T2 mechanics apply, exists for event accessibility — now bootstrappable day-one via the extraction Flux cap per A24 (Section 29).

**C31 — Void aesthetic is real at launch.** Previewable (not equippable) from the Lab tab at any Prestige level; unlocked permanently at P5 (Section 24).

**C32 — Prestige analysis discount.** From P1, Formula Lab fees permanently −40% (25→15, 75→45, 200→120), flat, non-stacking; the rediscovery experience otherwise fully preserved. Residue amounts unchanged by Prestige (Sections 11, 22).

**C33 — Dividend rates pre-cut for portfolio balance.** T6 = 100,000/week, T7 = 200,000/week (down from v3-draft 150k/400k); a realistic 5×T6 + 10×T7 portfolio earns 2.5M/week — strong without trivializing Prestige. No hidden income caps; the aggregate faucet is tracked per Section 30 (Section 15).

**C34 — “Currently synthesizing” definition.** Discovered the recipe AND ≥1 completed synthesis of that compound in the last 7 days (Section 13).

**C35 — The 10-slot cap path.** Prestige 1+3+5 alone reaches 8 slots; the ExpandedLab gamepass is required for 10. Called out in the gamepass description and the Prestige section both (Sections 8, 22, 25).

**C36 — implementation architecture note.** Implementation mapping lives in PRECIPICE_DOCS; this document is the design source of truth. **Superseded in v4.5 (E13):** the old “27 RemoteEvents / 13 modules” inventory is void — under the v4.5 implementation architecture, no remote exists as an authored instance (all are created at server start from a single manifest), and the module inventory is owned entirely by PRECIPICE_DOCS.

-----

### PART D — THE V4.1 SECOND-PASS AUDIT

Version 4 was audited against itself the same way v4 audited v3. Six contradictions and exploit holes were found — three introduced by v4’s own changes and never propagated, three inherited and never checked. Their rulings follow, plus the smaller rulings that closed remaining ambiguities. Where a Part A/B/C entry is affected, the supersession is noted in both places.

-----

**PROBLEM D1: Tier 1 patents were impossible by the document’s own definitions — and the doc still had them everywhere.**
Section 15 defined a patent as first to naturally complete a *synthesis*. Section 6 stated Tier 1 compounds are not synthesized. So no T1 patent could ever be claimed — yet the claim table had a T1 row (500 Pellets), the dividend table had a T1 row (200/week), announcement scoping discussed T1–T3 transfers, and the defense-window table listed “2,160 completions (T1, 2 min),” silently assuming extraction counted. The extraction change (A1) was never propagated through the patent system.
**SOLUTION: Patents are T2+ only.** You cannot patent raw feedstock — and the alternative (extraction counts) would have made the five starter patents a launch-second-zero attendance contest decided by whoever taps a free 2-minute timer longest, contested through windows holding 2,160 possible completions. The patentable pool is 120 base compounds (T2–T6) plus Exotics. T1 rows purged from the claim and dividend tables; the defense table re-based on T2 (360 completions); announcement scoping restated as T2–T3 quiet / T4+ global; T1 Formula Log entries carry no patent indicators; extraction reveals can never trigger the patent sequence. Discovering a non-starter T1 grants its extraction license — that is the reward (Sections 6, 13, 15).

-----

**PROBLEM D2: The Exotic arithmetic did not close — inherited from v3, never checked.**
15 T6 compounds yield 120 possible T6+T6 combinations. “~85 are Exotic” implied ~35 standard T6+T6 recipes — but the recipe density table allowed only ~15 recipes producing T6 results *total*, and those ~15 also had to cover the T4+T5/T5+T5 bootstrap paths without which T6 is unreachable at all. 35 > 15. The numbers could not all be true.
**SOLUTION: Every T6+T6 pair generates an Exotic; the standard-result branch is deleted.** Authoring ~35 T6+T6→T6 recipes would have added content burden to preserve a mechanic nobody benefits from — same-tier conversion (2 T6 in, 2 T6 out) is economically pointless, and hitting a standard recipe would feel like a failed Exotic roll. Now: the ~15 T6 recipes are exclusively bootstrap paths (~one per T6 compound, matching the density table); “T6+T6 always stageable” is trivially true; maximum Exotics is 120 (105 mixed + 15 same-compound pairs) — 40% more endgame content for free, paced by value decay exactly as before. Theoretical dividend ceiling recalculated: 25.5M/week (15×100k + 120×200k), tracked in Section 30. Parts B21 and C13 corrected (Sections 7, 17, 23, 30).

-----

**PROBLEM D3: T6 recipe discovery was unanswered, and both naive answers broke something — including v4’s own staging rule.**
If T6 recipes were Formula-Lab-discoverable, analysis success delivers one unit — a solo-produced T6, contradicting “Joint Synthesis only.” If the joint slot’s validity gate was the discovery mechanism, validity leaked for free by clicking. And pressure-testing exposed that A15’s “invalid pairs cannot be staged” was always incoherent: validity is a property of the *pair*, and under the staging flow the pair does not exist until Member B contributes, hours after staging.
**SOLUTION: Declaration staging + joint analysis.** The opener stages their compound and *declares* the required partner compound; the slot accepts only the declared compound (which also fixes async coordination). Validity is evaluated at declaration: discovered pairs and all T6+T6 stage free; an undiscovered T4+T5/T5+T5 declaration is a **joint analysis attempt** — 500-Pellet fee (300 at P1+, standard 40% discount), invalid → instant failure with compound returned and 6 Residue (net 410 / 210), valid → stages flagged “Confirmed reaction — product unknown,” and natural completion discovers recipe and product for both members. This reuses the making-is-discovering principle from variable recipes rather than inventing exceptions. The Lab refuses T4+T5, T5+T5, and T6+T6 with “Joint research required.” Declaration probing requires the T4 qualification; mapping all ~710 candidates costs ~355k Pellets and is intended — discovery was never the gate, production is. The discovering joint run, when natural, is a genuine natural completion and fully counts (the deliberate exception to D5). Supersedes A15’s mechanism; preserves its principle (Sections 11, 17). (Refined in D14: discovery itself happens on **any** completion, Accelerated included — only the competitive credit requires natural completion.)

-----

**PROBLEM D4: Released patents had no reclaim rules, and the claim package was exploitable as written.**
The RACE indicator implied first-completion-wins while the contested system said highest-count-wins — unresolved. Worse: if reclaims and transfers paid the claim package, coordinated Prestige cycles farmed claim bonuses (release, re-claim, pocket 800k per T6) and patent ping-pong farmed rank.
**SOLUTION: The claim package — Pellet bonus, 5 Catalysts, 500 rank, world-first reveal — is paid exactly once per compound, ever,** to the literal world first. Transfers, challenge wins, and reclaims convey the patent and dividend stream only. Released patents go to the **next natural completion** (making the RACE language literally true), granting custody only: counts don’t reset, so a high-count rival can challenge instantly — the two systems composing correctly, documented as such. Reclaims announce as transfers. And a leak the flat defense bonus created: **defense rank now tier-scales — T2: 25, T3: 50, T4: 100, T5: 150, T6/T7: 250** — because flat 250s were collusion-farmable via low-tier ping-pong (challenge, cheap 12-minute re-defenses, immunity, repeat). At 25 points, T2 collusion is worthless; high-tier collusion requires real 24-hour joint runs whose production rank dwarfs the bonus. Claim rank stays flat 500: at most 240 world firsts ever exist across base + Exotics, plus a handful per event (Sections 15, 18, 22).

-----

**PROBLEM D5: The discovery unit’s competitive status was unstated — and Rush Analysis ran straight through the gap.**
Analysis success delivers one unit. If that counted as a natural completion, Rush Analysis — purchased, instant discovery — could claim a world first: a direct Natural Completion Rule violation through the back door.
**SOLUTION: Discovery grants count for nothing.** The unit is a specimen grant, competitively invisible: no patent claim, no 30-day count, no Sprint, no rank, no Flux, no “synthesize X” contract credit (“complete N analyses” contracts count the analysis itself, unchanged). Discover, then race — the RACE indicator means what it says. The single deliberate exception is T6 joint discovery (D3), where the discovering run is itself a full natural synthesis and rightly counts (Sections 11, 14, 25).

-----

**PROBLEM D6: The Chief’s Board contradicted Prestige.**
“All-time cumulative Researcher Rank score. Never resets” — but rank score explicitly resets to zero at Prestige. Both could not be true of one number.
**SOLUTION: They are two numbers.** **Current-run score** drives your title and the Prestige gate and resets at Prestige. **Lifetime score** — the sum across all runs — never resets and is what the Chief’s Board ranks, shown with title and Prestige badge. The board now properly rewards the P6 grinder over one long first run. Adjacent ruling: the Weekly Sprint tally is its own counter and survives a mid-week Prestige untouched (Sections 18, 21, 22).

-----

**THE SMALLER D-RULINGS**

**D7 — Variable-pair discovery follows the seed.** A standard analysis on an undiscovered variable pair discovers the **currently active** variant — the seed governs discovery exactly as it governs synthesis. Rush Analysis is the only override (primary, always). Seed-consistent everywhere (Sections 7, 11).

**D8 — Caps apply after multipliers, as a general rule.** The event pass’s 2× Flux never raises the 50/day extraction Flux cap; no future multiplier raises any cap. Multipliers scale earnings, never limits (Section 29).

**D9 — The contract pool is filtered by player state at midnight generation.** Syndicate contracts require membership, tier contracts require a discovered recipe producing that tier, joint contracts require qualification; no mid-day rerolls. The patent contract is reworded to “take a patent or successfully defend one” — a “claim” contract would be uncompletable in a mature game under once-ever world firsts (Section 19).

**D10 — Exotics are blocked as Lab analysis inputs.** Procedural compounds can never appear in authored recipes, so allowing the attempt is a pure fee trap. Event compounds remain analyzable and fail normally — they are authored content (Sections 11, 23).

**D11 — Two emergent dynamics are named as intentional.** *The siege:* a 7-day T6/T7 defense consumes the Syndicate’s shared joint slots — designed social pressure. *The trusted rival:* joint partners accumulate challenge-ready counts on the patents they help defend — rotate partners or trust yours (Section 17).

**D12 — First-pass numbers corrected throughout.** Exotic maximum 85 → 120 (B21, C13 updated in place); theoretical dividend ceiling 18.5M → 25.5M/week; faucet model restated on 120 base patents (total ~3.25M/week unchanged — the deleted T1 dividends were only 6k of it) with a 24M/week Exotic ceiling (Sections 15, 30, 31).

-----

**THE V4.2 CLOSURE RULINGS (D13–D20)**

Declaration staging (D3) was new machinery, and new machinery ships new gaps. A third audit pass found seven in or around it, plus one factual error. These rulings close them.

**D13 — The contributor’s knowledge state was unanswered, and the fee rule was incoherent at the edge.** Member A (recipe known) declares, Member B (recipe unknown) contributes and receives a T6 unit — does B now have the recipe? As written, only the “product unknown” path granted discovery, so B could personally produce a compound and later be charged 500 Pellets to “analyze” it — contradicting making-is-discovering. **Ruling: every completed joint run — discovery or routine, natural or Accelerated — adds the result’s recipe to both members’ Formula Logs.** Knowledge is never gated (Section 17).

**D14 — Whether an Accelerated “product unknown” run discovers was ambiguous.** D3’s wording (“natural completion discovers”) implied an Accelerated discovery run completes 24 hours of synthesis and teaches nothing — absurd, and contrary to how skips work everywhere else. **Ruling: discovery happens on any completion; the Natural Completion Rule governs competitive credit only — never knowledge, never delivery.** Stated as a general principle in Section 14 and applied in Section 17.

**D15 — Production rank/Sprint/Flux for ordinary joint runs was never stated — the largest number in the rank economy left to inference.** Section 17 explicitly doubled passive income, patent counts, world-first packages, and (per D13) recipes, but production score for routine natural joint runs was only implied. **Ruling: each contributing member receives the full production package — tier rank score, Sprint points, event Flux — on every natural joint completion.** Bounded structurally by the Syndicate’s 2–3 shared slots, so wealth cannot scale it (Sections 17, 18).

**D16 — Released-patent custody via a joint run had no tiebreak.** Custody goes to “the next natural completion,” but a joint completion credits two members and custody cannot be shared. **Ruling: the slot opener takes custody** — the same opener convention as world firsts (Sections 15, 17).

**D17 — The joint analysis fee’s refund status was unstated, and the wrong default was the exploitable one.** Declare, pay 500, learn “valid,” cancel the staging (compound returns per the cancellation rule) — fee back? A refund would make mapping all ~710 pairs free except for mis-clicks. **Ruling: the fee is a non-refundable information purchase — and to keep non-refundability from becoming a gotcha, a paid pair is permanently marked Validated in the declarer’s Formula Log and never charges that player again.** Validated marks wipe on Prestige like all Log entries (Section 17).

**D18 — Rush Analysis × joint declarations was an open question.** Rush waives fees on “one Formula Lab analysis”; joint declarations are analyses by name and fee structure. **Ruling: Rush applies to personal Lab analyses only — never joint declarations.** The same boundary applies to contracts: “complete N analyses” counts personal Lab analyses only (Sections 11, 25).

**D19 — A false sentence, inherited from the first pass.** Section 23 claimed the Exotic decay floor (62,500–200,000) was “still above T6 base values” — but T6 runs 60,000–100,000, so a floored 62.5k Exotic sits at the bottom of the T6 range, not above it. The mechanic was always fine; the sentence was wrong. **Corrected:** floored low-end Exotics are intentionally comparable to good T6s (mass-produced novelty is no longer novel); floored high-end Exotics remain clearly above every T6 (Section 23).

**D20 — The patent contract escaped the contract filter’s stated standard.** “Take or defend” was technically drawable by a player for whom it was near-uncompletable. **Ruling: it is offered only to players with at least one discovered T2+ recipe, and the filter’s standard is codified — “possible in principle” is the guarantee, “completable today” is not.** Hard contracts are opportunistic bonuses by design (Section 19).

-----

**THE V4.3 ECONOMY CALIBRATION (D21–D22)**

The economy model (PRECIPICE_ECONOMY_MODEL.xlsx) validated every §30-flagged parameter against a session-based progression model. Most passed exactly as documented — the rank curve (Chief Scientist day ~84 vs the 85–90 target), discovery fees at every bracket, Exotic decay (floor at unit 46, matching §23’s run-24 claim), defense windows, Flux prices, and defense rank scaling. Two findings required doc changes.

**PROBLEM D21: Prestige P7–P8 costs failed the document’s own 120-day commitment.**
Pellets reset at Prestige (§22), so every run self-funds. At modeled endgame income (550–650k Pellets/day late-run, and the model’s flat-income assumption is ~10–15% *optimistic* because each run re-ramps from 500 Pellets), P7’s 80M cost projected ~145 days and P8’s 128M projected ~197 — both violating the §22 commitment. The ×1.6 multiplier grows 60% per level against income growth of ~10–15% per level; the curves were always going to cross.
**SOLUTION: costs recalibrated — P6 50M → 45M, P7 80M → 60M, P8+ multiplier ×1.6 → ×1.25.** Projected runs: P6 ~107d, P7 ~109d, P8 ~115d — inside the commitment. P9+ still project ~130+ days even at ×1.25 and are explicitly assigned to the telemetry patch lever (§22), because endgame income is the least certain model input and the P9+ population is vanishingly small. The asymmetry that decided this: cutting costs pre-launch is free; raising them post-launch is a community fire. Keeping the old values was a bet on income reaching ≥700k/day — a bet the patch lever can still cash if telemetry proves it, from the safe side (Sections 15, 22).

**PROBLEM D22: §30’s “sinks absorb faucets” requirement was impossible by genre arithmetic.**
The model showed passive income alone outstrips every fee sink combined; the economy runs a structural surplus of ~5,000–8,000 Pellets/player/day at maturity. No tuning fixes this because nothing is broken — wealth accumulation is the idle genre’s core promise, and a literal reading of the old wording would have demanded sinks that strangle it.
**SOLUTION: §30 restated honestly.** The actual requirements: Prestige absorbs per-player surplus within the committed pacing; the 80%/500% Market bounds insulate player-to-player prices from aggregate surplus; vault upgrades absorb Syndicate-level surplus. Fee sinks pace behavior and are not asked to balance the books. The pre-launch model requirement now tests what can actually be true (Section 30).

-----

**THE V4.4 COMPANION SYNC (D23)**

**PROBLEM D23: Companion-file references predated the compound database split.**
§4 named “the economy spreadsheet” as the single source of per-compound truth, and §29 pointed blueprint input pairs at it — both written before per-compound content moved to PRECIPICE_COMPOUND_DATABASE.xlsx.
**SOLUTION:** the companion set is formalized as two workbooks with a strict division of labor (§4): the compound database owns content (names, values, recipes, variable pairs, Exotic seed table, event blueprints); the economy model owns rules-level numbers and validation. §23 now acknowledges the Exotic seed table as the implementation of its generation rule; §29 points blueprint pairs at the database. A 58-point automated cross-verification of every number shared between the three artifacts passed in full at v4.4 — covering tier constants, rank values and thresholds, adopted Prestige costs, dividends and claim bonuses, defense-window maxima, recipe density and input-class splits, event compound stats, blueprint Flux prices, and Exotic decay parameters.

-----

**THE V4.5 IMPLEMENTATION-SEAM AUDIT (E1–E13)**

Versions 4 through 4.4 audited the rules against each other. Version 4.5 audited the rules against the machine that has to run them — a fleet of game servers that start and stop on their own schedule, players who are offline more than online, and global records that many servers touch at once. Thirteen gaps were found at that seam. None changes what the game is; every one had to be ruled before a line of code is written, because each was a bug, a silent value loss, or an impossible promise waiting to happen.

-----

**PROBLEM E1: The saved-timer wording contradicted the offline slowdown.**
Section 8 said “the timer end time is permanently saved.” Section 9 says offline production runs 20% slower. Both could not be literally true: a fixed saved finish time cannot change speed when the player logs out. Implemented as written, the offline slowdown would silently never happen — or be double-applied by a later fix.
**SOLUTION:** the game saves how much **work** a run has left, never a finish time. The displayed countdown is always derived from work remaining at the player’s current pace, and recalculated at every login and logout. Section 8 reworded; the rule was always Section 9’s rule.

-----

**PROBLEM E2: “The instant” a decay-triggered challenge fires has no instant.**
Synthesis-driven challenges have a triggering event — a run completes. Decay-driven challenges do not: counts fall as time passes with nobody acting, so nothing exists to react “instantly” to.
**SOLUTION:** challenge conditions are evaluated event-driven on every natural completion, plus a fixed sweep over all held patents at least every 15 minutes. A decay challenge may start up to 15 minutes after the mathematical crossover — imperceptible against 72-hour-to-7-day windows. The same sweep resolves defense-window expiries. “The instant” is defined as “within one sweep” (Section 15).

-----

**PROBLEM E3: The Monday rollover only existed for freshly started servers.**
The reset was “detected on every server start” — but Roblox servers run for days. A server started Sunday evening would cross Monday midnight live, leaving its players on a stale seed, a stale Sprint, and unpaid dividends until that server happened to die.
**SOLUTION:** every server checks the clock each minute. At the boundary, one server claims the weekly job through a shared lock and runs the mandated Monday order — dividends, Sprint reset, seed change — as a ledger of week-stamped steps under an expiring lock, so a crashed claimant is resumed at the first unstamped step, never repeated (refined in v4.6, F1). Live servers pick up the new week within a minute; server start is a backstop. The weekly variant seed is computed deterministically from the week number, so every server agrees on active variants with zero coordination — the claimed job runs the side effects, not the seed (Sections 7, 21).

-----

**PROBLEM E4: “Your own rank always visible” cannot be kept at scale.**
A global board can cheaply produce its top pages; it cannot cheaply answer “what is this one player’s exact rank” for every viewer outside them.
**SOLUTION:** top 50 (Sprint) and top 100 (Chief’s Board) are exact. Your own row always shows your score; exact rank is shown while you are within roughly the top 1,000; beyond that, a close percentile estimate refreshed hourly. A fresh percentile is more honest than a stale number (Section 21).

-----

**PROBLEM E5: Prestige said nothing about production in flight.**
The reset table ruled on listings and PendingCredits but not on: running personal slots, completed-but-unrevealed results, a compound staged in a joint slot, or a running joint run the player contributed to. Every one is a silent value loss or a duplication bug if handled ad hoc during a reset.
**SOLUTION:** Prestige is blocked — with the blockers listed on the button — while any of those four states exists. Finish, reveal, and collect first. Auto-resolving was rejected because it destroys committed value without warning; blocking costs at most a day on an action taken a handful of times per year (Section 22).

-----

**PROBLEM E6: Whether the prestiging player’s own 30-day counts survive was implied, never stated.**
D4 ruled that *rivals’* counts persist through a release. The prestiger’s own counts were left to inference — and they are the difference between a returning player who still has standing and one who silently lost it.
**SOLUTION:** 30-day natural synthesis counts are production history, not Formula Log entries. They survive Prestige, stated explicitly. The natural brake is intact: the prestiger cannot synthesize anything until they rediscover its recipe (Sections 15, 22).

-----

**PROBLEM E7: Market bounds plus Exotic decay could strand legal listings.**
Section 23 referenced the 80%/500% bounds “at the moment of listing or sale.” Exotic decay moves base value down, so a legally created listing can drift above 500% of *current* base while listed. Enforcing bounds at sale would make legal listings unbuyable.
**SOLUTION:** bounds are checked once, at listing creation. A legal listing stays purchasable for its full life. The anti-transfer function is untouched — the transfer exploit lives at the *floor*, and decay moves a fixed price away from the floor, never toward it. The purchase confirmation always shows current base value beside the asking price (Sections 16, 23).

-----

**PROBLEM E8: Daily contracts were “drawn at midnight UTC” — for players with no server at midnight.**
An offline player cannot have anything drawn for them.
**SOLUTION:** contracts generate at the player’s first login of each UTC day, filtered by their state at that moment, then frozen — preserving no-mid-day-rerolls exactly. No login, no contracts: contracts measure active sessions, which is their stated purpose (Section 19).

-----

**PROBLEM E9: The contract pool did not exist.**
Section 19 had eight examples and reward ranges. A generator cannot draw from examples.
**SOLUTION:** the full pool is authored — 24 templates (8 Easy, 8 Medium, 8 Hard) with exact targets, rewards inside the stated bands, and an explicit state filter per template — in the economy model’s Contract_Pool sheet, with the slot draw rule (3 standard from Easy/Medium, 2 bonus from Medium/Hard, no repeats per day) tuned to keep the all-five daily rank bonus in the 250–475 band (Section 19).

-----

**PROBLEM E10: Catalysts were the only currency with zero model coverage.**
The economy model validated every Pellet number and never once modeled Catalysts. Free earn at steady state is roughly 1 per week from the streak plus event milestones; a skip costs 30 and the member-cap expansion 200.
**SOLUTION:** modeled in the new Catalyst_Economy sheet and added to Section 30’s tuning flags. Free Catalysts are deliberately scarce — a premium currency — and the standing flag watches whether Catalyst-priced features see near-zero non-payer engagement. The first tuning lever is the streak steady-state rate, never price cuts (Sections 3, 30).

-----

**PROBLEM E11: The world was never defined.**
No prior version said how many players share a server, whether the lab is a place or a menu, what the camera is, or whether other players are visible. The map, the reveal staging, and half the UI depend on those answers.
**SOLUTION:** the new Section 31 — 8-player servers; one plot and one instanced lab interior per player; the lab’s 10 physical chambers ARE the slots (locked ones stand dark); reveals stage physically at the chamber; other players’ labs visible and walkable; joint slots exist only as Syndicate records, never as chambers; standard third-person camera with full HUD parity and mobile-first interaction. Plots beat a shared room (reveals collide, no ownership) and private instancing (no ambient social, no recruiting surface).

-----

**PROBLEM E12: Simultaneity had no arbiter.**
Two buyers purchasing the same listing in the same second; two joint runs completing the same brand-new Exotic on different servers; two members touching the same joint slot at once. Section 13 acknowledged the Exotic race’s *experience*; nothing defined its *resolution*.
**SOLUTION:** one rule everywhere — every contested record has a single authoritative copy, and the first write wins. Exactly one buyer gets a listing (the other is refunded instantly with “already sold”); exactly one completion claims a first (the other gets Section 13’s “moments before you” path, compound delivered); joint-slot actions apply in arrival order against the slot’s state, and an action against a stale state is rejected and resurfaced. Cross-server announcements ride the existing 30-second queue (Section 15). No first is ever decided by anything other than the authoritative record.

-----

**PROBLEM E13: C36’s implementation note was stale and dangerous.**
“27 RemoteEvents / 13 modules” described the abandoned first implementation. Carrying it forward invites rebuilding the old architecture’s fragility — hand-created remote instances that a sync hiccup can silently lose.
**SOLUTION:** C36 superseded. No remote exists as an authored instance: every one is created at server start from a single code manifest, so there is nothing for a sync tool to lose. The module inventory belongs to PRECIPICE_DOCS alone. (Part C, C36.)

-----

**THE V4.6 HARDENING PASS (F1–F2)**

Found by pressure-testing v4.5's own new machinery before code — the same discipline every prior version applied to the version before it. Both are engineering covenants in the E13 class: invisible to players, fatal if skipped.

-----

**PROBLEM F1: E3's weekly job could half-run.**
E3 made one server claim the Monday job and run dividends → Sprint reset → seed change "exactly once," week-stamped — but said nothing about a claimant that crashes after paying dividends and before resetting the Sprint. As written, the week-stamp guard would then block every second attempt, leaving the week half-rolled forever: dividends paid, Sprint stale, seed announcement never sent.
**SOLUTION:** the weekly job is a **ledger of steps, not a single act**. Each step is individually stamped with the week number as it completes, and the claim lock expires after a few minutes. A claimant that dies is succeeded by the next server, which resumes from the first unstamped step and can never repeat a stamped one. "Exactly once" means exactly once **per step**. The same claim-and-resume machinery runs every global job, including the 15-minute patent sweep (E2) and the hourly percentile job (E4). (Sections 15, 21.)

-----

**PROBLEM F2: Cross-server messages could quietly become a source of truth.**
E3 and E12 use cross-server messaging for speed — the new-week broadcast, the announcement queue. On the platform those messages are best-effort: they can drop, and occasionally will. Any rule that only works if a message arrives is a rule that sometimes doesn't run.
**SOLUTION:** a standing covenant — **cross-server messages are hints, never truth**. Every state that matters (the active week, patent custody, challenge state, listings, dividends, percentiles) lives in an authoritative record that every server also polls on a bounded interval; a missed message costs seconds of freshness, never correctness. The only thing permitted to ride messages alone is the ephemeral announcement marquee, where a missed line on one server is cosmetic. (Sections 15, 21.)

-----

*End of PRECIPICE Game Design Document — Version 4.6 (Final)*
*Version 4.6 supersedes Versions 4.5, 4.4, 4.3, 4.2, 4.1, 4, and 3 in full. Where any other document disagrees with this one, this one wins until the other is updated.*
*The companion workbooks are PRECIPICE_ECONOMY_MODEL.xlsx (rules-level numbers and validation, now including the Contract_Pool and Catalyst_Economy sheets) and PRECIPICE_COMPOUND_DATABASE.xlsx (per-compound content, recipes, Exotic seed table, event blueprints) — a change in any of the three requires a sync check of the other two (§4).*
*For technical implementation details see the PRECIPICE_DOCS folder.*
*This document and PRECIPICE_DOCS must stay in sync — any design change here requires a corresponding update there. Every change is enumerated in Section 32: Parts A and B for v3→v4, Part D for v4→v4.1 (D1–D12), v4.1→v4.2 (D13–D20), v4.2→v4.3 (D21–D22), v4.3→v4.4 (D23), Part E for v4.4→v4.5 (E1–E13), and Part F for v4.5→v4.6 (F1–F2).*
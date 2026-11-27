# CM2-SALE2 — Early-lot demand

Written by: `planner` (Opus 5.5, medium) for tier M. Implemented by: `implementer-high`. Playtested by: `playtester` (Haiku 5.5). Reviewed and committed by: `reviewer` (Sonnet 5.5, high). Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
A small starter lot sells: a customer also buys a tree that is not its exact species and size when it fits its budget (with less interest), and the variety and stock factors start gentler. A fresh 6-tree Douglas lot converts about 19 % of visits instead of 1.1 %, while a full assortment stays where it was (about 30 % at reputation 90).

## Source of truth
- Backlog CM2-SALE2 entry (section "Follow-up tasks (created 2026-11-25 from CM2-SALE1)") and `docs/plans/CM2-SALE1.md` "Cause" and "Out of scope".
- PRODUCT_SPEC "Exact prices and demand are data-driven and tuned later" (engineering decides PROVISIONAL values).
- GAME_DESIGN §4 (conversion score already names `baseSpeciesInterest`; "Prevent guaranteed purchases and runaway income") and §5 (seeded preference, budget).
- DECISION_LOG 2026-11-25 "Tutorial customer and pick diagnostics, CM2-SALE1" (the tutorial guarantee stays as it is).

## Implementer tier
Tier: M. Reason: non-trivial demand logic across three shared modules plus a simulation suite; no save field, no remote, no change to the money, reservation or sale path (`beginVisit`, `completeVisit` untouched).

## Skills to load
roblox-collaboration-mode, roblox-game-design, roblox-luau-core, roblox-luau-types.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/GameConfig.lua` | Change | new table `GameConfig.Demand` |
| `src/shared/Demand.lua` | Change | optional 6th parameter `interest` |
| `src/shared/CustomerProfile.lua` | Change | `budgetPercent` field, `budgetFor`, `interestIn`, soft `canPurchase` |
| `src/shared/CustomerSelection.lua` | Change | gentler variety/stock factors, best-scoring candidate |
| `tests/studio/Cases/DemandSimulation_Test.lua` | New | 1000-visit conversion simulation, 4 lots |
| `tests/studio/Cases/CustomerProfile_Test.lua`, `CustomerSelection_Test.lua`, `Demand_Test.lua` | Change | updated and new cases |
| `tests/studio/Cases/StudioTestInstruments_Test.lua`, `NpcTransactions_Test.lua`, `CustomerNpcService_Test.lua` | Change | one rename and reason comments only |
| `tests/studio/Playtest/RunPlaytest.lua` | Change | `RunPlaytest.BUILD = "cm2-sale2"` |
| `docs/GAME_DESIGN.md`, `docs/DECISION_LOG.md`, `docs/TEST_PLAN.md` | Change | rule text, decision entry, test bullet |

## Data and config
No save schema change (`budgetPercent` lives only on the per-visit profile table, never saved), no new remote or action, no Localization string. New config, inserted in `GameConfig.lua` directly above `GameConfig.Pricing = {`:
```lua
-- Early-lot demand (CM2-SALE2), all PROVISIONAL (PRODUCT_SPEC "demand tuned later", GAME_DESIGN §4/§5).
-- Interest: how much a customer wants a tree by how it matches its preferred species and size.
-- Variety: VarietySingle with one displayed species, rising linearly to 1 at VarietyFullSpecies.
-- Stock: StockBase with no unreserved tree, rising linearly to 1 at AutoPricing.TargetDisplayStock.
GameConfig.Demand = {
	Interest = { Exact = 1, SameSpecies = 0.85, SameSize = 0.75, Other = 0.65 },
	VarietySingle = 0.85,
	VarietyFullSpecies = 3,
	StockBase = 0.6,
}
```
Old vs new factors (unchanged: price factor, reputation factor, clamp 0.02..0.95, budget percent 85–155 %):
| Factor | Old | New |
|---|---|---|
| Preference | exact species and size, else not eligible | any known tree within `budgetFor`; interest 1 / 0.85 / 0.75 / 0.65 |
| Variety (1, 2, 3+ species) | 1/3, 2/3, 1 | 0.85, 0.925, 1 |
| Stock (1, 2, 5+ unreserved) | 0.2, 0.4, 1 | 0.68, 0.76, 1 |
| Pick | first sorted compatible tree | highest score; ties keep the first sorted ID |

Measured on a prototype (planner, scratch copy, seeds 1–3, reputation 90, default prices): 1-tree 12.5–13.0 %, 6 Douglas Medium 18.8–19.0 %, mixed S/M/L 20.4–20.8 %, full 12-tree assortment 30.1–30.3 %.

## Steps
1. **`GameConfig.lua`**: add the block above.
2. **`Demand.lua`**: signature becomes `Demand.score(priceRatio, reputation, seasonalFactor, varietyFactor, stockFactor, interest: number?): number`. The product inside the clamp gains `* (interest or 1)` as its last factor. Comment above the function: "interest (CM2-SALE2, GAME_DESIGN §4 baseSpeciesInterest) defaults to 1." Nothing else changes.
3. **`CustomerProfile.lua`**:
   - Header comment, replace line 3–4 with: "Budgets are 85-155 % (`budgetPercent`) of the benchmark (Economy.typicalPrice, CM2-G7); the same percent applies to any tree the customer considers (CM2-SALE2, PROVISIONAL)."
   - `create`: returned table gains `budgetPercent = percent` (after `budget`). `budget` stays as it is.
   - New `function CustomerProfile.budgetFor(profile, speciesId: unknown, sizeId: unknown): number?`: nil unless `type(profile) == "table"` and `type(profile.budgetPercent) == "number"`; `typical = Economy.typicalPrice(speciesId, sizeId)`, nil when nil; returns `(typical * profile.budgetPercent + 50) // 100` (the formula of `create`, so `budgetFor(p, p.preferredSpeciesId, p.preferredSizeId) == p.budget`).
   - New `function CustomerProfile.interestIn(profile, placement): number`: 0 unless both are tables; `sameSpecies = placement.speciesId == profile.preferredSpeciesId`, `sameSize = placement.sizeId == profile.preferredSizeId`; returns `Interest.Exact` (both), `Interest.SameSpecies`, `Interest.SameSize`, else `Interest.Other` (`GameConfig.Demand.Interest`).
   - `canPurchase(profile, placement, salePrice: number): boolean` becomes: false unless profile and placement are tables and `salePrice` is a number; `budget = CustomerProfile.budgetFor(profile, placement.speciesId, placement.sizeId)`; returns `budget ~= nil and salePrice <= budget`. Comment: "Soft preference (CM2-SALE2): any known tree within the budget scaled to its own benchmark; interestIn weighs the match."
4. **`CustomerSelection.lua`**:
   - `varietyFactor`: keep the counting and `if total == 0 then return 0 end`; return `math.min(1, D.VarietySingle + (1 - D.VarietySingle) * (distinct - 1) / (D.VarietyFullSpecies - 1))` with `local D = GameConfig.Demand`.
   - `choose`: `stockFactor = math.min(1, base + (1 - base) * #candidateIds / GameConfig.AutoPricing.TargetDisplayStock)` with `base = GameConfig.Demand.StockBase`; compute `local variety = varietyFactor(state)` once before the loop. In the loop, for a compatible placement: `interest = CustomerProfile.interestIn(profile, placement)`, `score = Demand.score(judged / typical, state.reputation, 1, variety, stockFactor, interest)`; keep it as `best = { placementId, salePrice, conversionScore = score }` when `score > bestScore` (start `bestScore = -1`, `best = nil`); return `best` after the loop.
   - Update the comment above `choose`: "Returns the highest-scoring compatible candidate (ties: first sorted ID) and its server-computed conversion score. CM2-SALE2: compatible means within the budget for that tree; the score includes the customer's interest." Keep the priceTolerance sentence.
   - `chooseGuaranteed` and `unreservedIds` unchanged.
5. **Tests**: see the table below. Every new or updated float comparison uses `math.abs(a - b) < 1e-9`.
6. **Reason comments**, no logic change: at `NpcTransactions_Test.lua` lines 116 and 290 and at `CustomerNpcService_Test.lua` `spawn(h, A, 5)` (about line 749) add `-- profile 5's budget (99 %) is below every benchmark price (CM2-SALE2 soft preferences)`. Rename `StudioTestInstruments_Test` "visitForTest reports a non-matching profile" to "visitForTest reports a profile that cannot afford the tree (CM2-SALE2)"; body unchanged.
7. **`RunPlaytest.BUILD = "cm2-sale2"`.**
8. **Docs** (English, short):
   - `GAME_DESIGN.md` §4, after the conversion-score paragraph: "Early-lot demand (CM2-SALE2, PROVISIONAL): `baseSpeciesInterest` is the customer's interest in the tree (exact species and size 1, same species 0.85, same size 0.75, other 0.65; `GameConfig.Demand`); varietyFactor is 0.85 with one displayed species, rising to 1 at three; stockFactor is 0.6 + 0.4 × unreserved trees / 5, capped at 1. Headless simulation at reputation 90: 1 tree ≈ 13 %, 6 Douglas Medium ≈ 19 %, mixed S/M/L ≈ 21 %, full assortment ≈ 30 % of visits."
   - `GAME_DESIGN.md` §5, in "Each customer has a seeded preference …" after the first sentence: "The preference is soft (CM2-SALE2): a customer considers every displayed tree whose price fits its budget percent applied to that tree's benchmark and picks the one with the highest conversion score."
   - `DECISION_LOG.md`, new entry at the end: "## 2026-11-26 — Early-lot demand, CM2-SALE2 (engineering)". Bullets: problem (CM2-SALE1 cause: 1.1 % per visit for 6 Douglas Medium); decision: soft preferences with the four interest values, budget percent per tree, best-score pick, variety 0.85/0.925/1, stock 0.6 + 0.4 × n/5; all PROVISIONAL; simulation ranges (the four target ranges below) with measured rates; late game unchanged (full assortment ≈ 30 % as before); no guaranteed purchase (clamp 0.95 and the roll stay).
   - `TEST_PLAN.md` §2, new bullet at the end of the list: "Demand simulation (CM2-SALE2, `DemandSimulation_Test`): 1000 visits (customers 1–1000, rolls `(seed × 0.1 + i × 0.61803398875) % 1`, seeds 1–3) on four fixed lots; each prints `[SALE2]` with the rate and asserts its target range."

## Tests (headless)
Expected count: 608 + 8 = 616. All values below were checked on the prototype.
| Test case file | Test name | Asserts |
|---|---|---|
| CustomerProfile_Test | update "requires preference and budget compatibility" → "requires budget compatibility for any known tree (CM2-SALE2)" | profile 1: Fraser Small at 65 true; Noble Small at 150 true (budget 150); Noble Small at 151 false; Fraser Small at 999 false; `{speciesId="Pine", sizeId="Small"}` at 1 false |
| CustomerProfile_Test | new "budgetFor scales the budget percent to any tree's benchmark (CM2-SALE2)" | `create(8).budgetPercent == 150`; `budgetFor(p8, "NobleFir", "Large") == 359`; `budgetFor(p8, "Pine", "Medium") == nil`; `budgetFor(nil, "DouglasFir", "Medium") == nil`; `create(5).budgetPercent == 99`; for n = 1..71 `budgetFor(p, p.preferredSpeciesId, p.preferredSizeId) == p.budget` |
| CustomerProfile_Test | new "interestIn grades species and size matches (CM2-SALE2)" | profile 8 (Douglas Medium): Douglas Medium 1, Douglas Large 0.85, Fraser Medium 0.75, Fraser Large 0.65; `interestIn(p8, nil) == 0` |
| CustomerSelection_Test | update "rejects nonmatching or over-budget stock" → "accepts a non-preferred tree within budget and rejects over-budget stock (CM2-SALE2)" | lot with `noble` Noble Small; `choose(state, create(1))` → placementId `noble`, salePrice 147, score ≈ `Demand.score(1, 90, 1, 0.85, 0.68, 0.75)`; then `state.mediumPrices.NobleFir = 200` → `choose` nil (160 > 150) |
| CustomerSelection_Test | update "uses the sale price over the size benchmark" | expected score ≈ `Demand.score(200 / 182, 90, 1, 0.85, 1, 1)` (variety 0.85, was 1/3) |
| CustomerSelection_Test | update "chooseGuaranteed takes the first unreserved priced tree (CM2-SALE1)" | replace `choose(state, CustomerProfile.create(1))` nil with `choose(state, CustomerProfile.create(5))` nil (budget 99 % is below 147 and 140); rest unchanged |
| CustomerSelection_Test | new "picks the best-scoring tree, not the first sorted one (CM2-SALE2)" | lot `a` Fraser Large, `b` Douglas Medium; `choose(state, create(8))` → placementId `b`, salePrice 140, score ≈ `Demand.score(1, 90, 1, 0.925, 0.76, 1)` |
| Demand_Test | new "interest scales the score and defaults to 1 (CM2-SALE2)" | `Demand.score(1, 500, 1, 1, 1, 0.5)` ≈ 0.325; `Demand.score(1, 500, 1, 1, 1) == Demand.score(1, 500, 1, 1, 1, 1)`; `Demand.score(1, 90, 1, 1, 1, 0) == 0.02` |
| DemandSimulation_Test | 4 new tests, below | each: every seed's rate inside the range |

**`DemandSimulation_Test.lua`** (header comment: "CM2-SALE2 conversion simulation: sales per visit on fixed lots, PROVISIONAL targets (GAME_DESIGN §4)."):
- Helper `lot(list)`: `BusinessState.new("personal:42", 42)` with default prices and reputation; placements `string.format("t_%02d", i)` = `{ speciesId, sizeId }` in list order.
- Helper `simulate(state, seed)`: for i = 1..1000, `candidate = CustomerSelection.choose(state, CustomerProfile.create(i))`, `roll = (seed * 0.1 + i * 0.61803398875) % 1`; a sale when `candidate ~= nil and roll <= candidate.conversionScore` (same rule as `beginVisit`); the state is never changed. Returns `sales / 1000`; prints `string.format("[SALE2] lot=%s seed=%d sales=%d visits=1000 rate=%.3f", name, seed, sales, rate)`.
| Test name | Lot | Range (each of seeds 1, 2, 3) |
|---|---|---|
| "one-tree starter lot converts 10-16 % (CM2-SALE2)" | 1 Douglas Medium | 0.10 ≤ rate ≤ 0.16 |
| "six Douglas Medium convert 16-23 % (CM2-SALE2)" | 6 Douglas Medium | 0.16 ≤ rate ≤ 0.23 |
| "mixed S/M/L starter lot converts 18-25 % (CM2-SALE2)" | 2 Douglas Small, 2 Medium, 2 Large (t_01..t_06 in that order) | 0.18 ≤ rate ≤ 0.25 |
| "full assortment stays at 25-35 % (CM2-SALE2, no runaway)" | `GameConfig.SpeciesOrder` × Small, Medium, Large (12 trees, species outer loop) | 0.25 ≤ rate ≤ 0.35 |

Existing cases not listed here must pass unchanged (the prototype run had exactly the 4 listed failures before the updates).

## Playtest (Studio, via playtester)
Timing: not forced now (tier M; no save, money, inventory, purchase or geometry change; not a milestone's last task). Queue it in "Studio-Test ausstehend" per `cm2-task` step 3 unless the queue already holds two tasks. `U` = the real player's UserId; hook = `ServerStorage.StudioTestHook:Invoke(...)` in the Server data model.
1. **Setup.** Rojo synced to the implementation commit, Play. `RunPlaytest.BUILD == "cm2-sale2"`. Unit runner `require(ServerStorage.UnitTest.RunUnitTest)(nil, 10)` → 616 passed, 0 failed; the output shows 12 `[SALE2]` lines.
2. **Fresh lot.** `tutorialOffer {userId=U, offered=false}`; create and play "SALE2 Lot". `pauseCustomers true`; `tutorialSet {userId=U, step="Done"}`; `setProgression {userId=U, cash=500}`. `snapshot U`: reputation 90, `mediumPrices.DouglasFir` 140, `placementCount` 0; `customerOrders U`.parkingSpaces 2.
3. **Six trees.** `act Supplier.PlaceOrder {speciesId="DouglasFir", sizeId="Medium", quantity=6}` → ok, bay B. `advanceClock 60` until the 6 trees are in bay B (at most 5 times). `act Stock.Place {bay=B, speciesId="DouglasFir", sizeId="Medium", x=-24.4, z=-20, rotation=0, count=6, gap=0.5}` → ok (step 36's row spot). On any error code: place two rows of 3 at (x=-24.4, z=-20) and (x=-24.4, z=-26) and record the code. `snapshot.placements` has 6 unreserved entries.
4. **Window.** `npcReset`; record sales S0, visits V0, abandoned A0. `pauseCustomers false`, start a 180-s timer. Every 2 s read `npcSnapshot`; whenever a visit on U's plot is `CheckingOut`, teleport the character to `CounterBase.Position + Vector3.new(3, 3, 0)`, wait 0.5 s, `prompt {userId=U, kind="checkout"}`. At 180 s: `pauseCustomers true`; read `snapshot U` and `npcSnapshot().decisionLog`.
   - PASS: sales ≥ S0 + 1 within the 180 s, and the decision log holds at least two different `decision` values (e.g. `Reserved` and `NoConversion` or `NoEligibleStock`).
   - If sales == S0: run one more 180-s window the same way (expected miss chance per window about 8 % at 19 % per visit and about 12 visits); FAIL only if both windows miss. Record both windows.
   - Record: visits − V0, abandoned − A0, sales − S0, the full decision log (customer numbers and decisions).
5. **Regression.** Back on "Playtest A": `runPlaytest {mode="full"}` → `SUMMARY … result=PASS`. Console: only the known `rbxassetid://203785492` warning and nothing new.
6. **Cleanup.** Delete "SALE2 Lot"; `pauseCustomers false`.

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests` (0 errors, 0 warnings), `lune run tests/headless/run.luau` (616 run, 616 passed), `rojo build default.project.json --output build.rbxlx` (not committed).
- The headless output shows the 12 `[SALE2]` lines and every rate lies in its target range (the reviewer copies them into PROGRESS.md).
- Existing demand tests are updated only as listed, each with its reason.
- Studio (when run): step 4 PASS (a sale within 3 minutes on a fresh 6-tree lot, mixed decision reasons), step 5 PASS.
- DECISION_LOG entry with the values; GAME_DESIGN §4/§5 and TEST_PLAN updated.
- Money stays server-authoritative: the sale price still comes from `state.mediumPrices`; no client value is read; no purchase is guaranteed (clamp 0.95, roll unchanged); the tutorial guarantee (CM2-SALE1) is unchanged.

## Out of scope
- Reputation and price factors, budget range 85–155 %, `PricingService` auto pricing (its `TargetDisplayStock` use is unchanged), `seasonalFactor` (stays 1), night arrival rate.
- New customer profile cycle or species-weighted preferences (the 12-profile cycle stays).
- Balance pass on income (launch order 29 CM2-28).

## Amendment 1 (2026-11-26): step 38 NPC_GIVE_UP regression
Trigger: batch Studio run (place 92354134900807, main @ cd45fac + uncommitted G12b tree): playtest steps 1–4 and 6 PASS; step 5 full run 62/64; `38 NPC_GIVE_UP` FAIL both times ("visit:5 still present after 45 s", then "visit:63 …"). The other failure (63) belongs to CM2-G12b (its Amendment 1).

**Cause (SALE2, test assumption; the game logic is as planned).** Step 38 (a) assumes profile 5 (Fraser Fir Medium, budget 99 %) finds nothing on R's Douglas-only lot. PREFLIGHT `priceToSell` sets Douglas to `PLAYTEST_PRICE` = the minimum bound `ceil(typical × MinPriceMultiplier 0.5)`. Since SALE2's soft `canPurchase`, every customer (≥ 85 %) can afford that tree. `spawnForTest` arrives with roll 0, so the customer always converts: it reserves, waits at the counter, nobody serves it, and it is still there after 45 s. The step 6 reason comment ("99 % is below every benchmark price") holds only at benchmark prices, which the headless cases use. G12b's server changes are not involved (no NPC or selection code).

**Fix (test only)**: `tests/studio/Playtest/Steps/Npc.lua`, `npcGiveUpStep` part (a):
| # | Exact change |
|---|---|
| B1 | Add `local PricingService = ctx.PricingService` and `local actOk = ctx.actOk` to the alphabetical local list at the top. |
| B2 | After `local startSnap = snap(R.userId)`: build a sorted list `raised` of the distinct `speciesId` of `startSnap.placements` whose `startSnap.mediumPrices[speciesId]` is a number. For each, in order: `local _, maximum = PricingService.bounds(speciesId)`, then `actOk(R.userId, "Pricing.SetMediumPrice", { speciesId = speciesId, mediumPrice = maximum })`. At most 4 species, so 4 + 4 calls stay within the 10 per 10 s action limit. |
| B3 | Declare `local afterFirst: any = nil` and move everything from `local first = npcVisit(5)` through the `abandonedCustomers` check into `local okA, errA = pcall(function() … end)`, assigning `afterFirst` inside it. After the pcall, restore every species in `raised` with `actOk(R.userId, "Pricing.SetMediumPrice", { speciesId = speciesId, mediumPrice = startSnap.mediumPrices[speciesId] })`, then `if not okA then error(errA, 0) end`. Part (b) is unchanged and runs at the restored price (profile 8 must buy). |
| B4 | Replace the comment of (a) with: `-- (a) Profile 5 (Fraser Fir Medium) must find nothing. CM2-SALE2: customers buy any tree within budget and PREFLIGHT prices Douglas at its 0.5 x minimum, so every species on the lot is priced at its 2.5 x maximum (above any 155 % budget) during (a) and restored after.` |
| B5 | Return text: `string.format("no-stock walk-out counted (%d species priced out), give-up released %s", #raised, tostring(placementId))`. |
| B6 | `docs/TEST_PLAN.md` line "Repeatable run", item `38 NPC_GIVE_UP`: after "profile 5 walks out" insert ` (every species on R's lot at its maximum price during this part, restored after; CM2-SALE2 A1)`. |

No game code, headless test or `RunPlaytest.BUILD` change (BUILD stays as the G12b tree sets it). Headless count unchanged.
**Tier: S** → `implementer`. Reason: one playtest step and one doc line, with existing helpers. No change to game logic, money, save or remotes.
**Re-test:** run together with CM2-G12b Amendment 1: full run **64/64**, step 38 PASS. That also passes this plan's playtest step 5. The queue entry "CM2-SALE2" in "Studio-Test ausstehend" can then be ticked (steps 1–4 and 6 already passed); update its "62/62" to "64/64". The reviewer commits this fix separately (`fix(test): …(CM2-SALE2 A1)`), apart from the G12b commit.

# CM2-SALE1 — Customers never buy on a fresh save

Written by: `planner-high` (Opus 5.5, high) for tier L. Implemented by: `implementer-opus`. Playtested by: `playtester` (Haiku 5.5). Reviewed and committed by: `reviewer` (Sonnet 5.5, high). Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
On a fresh save the tutorial's Checkout step ends with a real walking customer who buys the displayed tree, so the player gets through order → place → customer buys. Per-visit pick results become readable in Studio.

## Cause (verdict: confirmed from code, Studio part A of the playtest re-confirms it)
No code path is broken. Every visit was refused by the demand model when it picked a tree (`CompanyStateService:npcDecide` → `CustomerSimulationService.beginVisit`, lines 34–41), and a one-tree lot almost never passes it:
| Filter | Code | Value on the N1 Tut lot (1 Douglas Fir Medium, price 140, reputation 90) |
|---|---|---|
| Exact preference | `CustomerProfile.canPurchase` requires `placement.speciesId == preferredSpeciesId and placement.sizeId == preferredSizeId` (`src/shared/CustomerProfile.lua`, last function). The profile cycle has 4 species × 3 sizes. | Only customer numbers n ≡ 8 (mod 12) want Douglas Medium. 11 of 12 visits fail with `NoEligibleStock` (`beginVisit` line 35–37). |
| Conversion roll | `beginVisit` line 39 `if roll > candidate.conversionScore`; the score is `Demand.score(1, 90, 1, varietyFactor, stockFactor)` from `CustomerSelection.choose` | priceFactor 0.65 × reputationFactor 0.59 × variety 1/3 (one species) × stock 1/5 (1 of `TargetDisplayStock` 5) = 0.0256. A matching customer converts 2.6 % of the time and otherwise fails `NoConversion`. |
| Per visit | | 1/12 × 0.0256 ≈ 0.21 %. 49 visits without a sale is the expected outcome; P(≥1 sale in 49) ≈ 10 %. |

The headless suite never caught this: every NPC harness passes a roll function that returns 0 and uses matching profiles (8, 20). The archived decision R6 (CM2-N1 fix round 1, `docs/archive/DECISION_LOG_2026-11-19_to_2026-11-23.md`) called this "expected demand" for a normal lot. The tutorial's Checkout step (CM2-49) relied on it and has only ever been tested through `npcVisit` (roll 0).

Other readings explained (no defect):
- **Counter note in the backlog is wrong:** the 27 visits before the tree were not visits to an empty lot. `npcArrive` returns `NoStock` before counting when no unreserved tree is displayed (`CompanyStateService.lua` 1097–1099), and drive-pasts count only with placements (1102). Visits are counted only in `beginVisit` (line 28). So all 49 visits and 23 drive-pasts saw the tree: the baseline was read after placement.
- **`forceCustomer 8` failed:** it sets the customer sequence and one forced roll 0 (`StudioTestService.lua` 66–74, `main.server.lua` 75–81). The roll is a single server-wide token and the next `npcDecide` of *any* visit takes it (`npcDecide` line 1145 calls `self._randomRoll()` whenever the visit has no own roll). A visit already on the lot decided first, so customer 8 got a random roll and failed `NoConversion` (97 %). Test-tool defect, fixed in step 6.
- **`NoParking` with "1–2 claims":** parking tier 1 has 2 spaces; `freeParking = 2 − (orders + max(reservations, claims))` (`CustomerOrderService` 58–70). A refused visit keeps its claim through Arriving, WalkingIn, Browsing 6 s, WalkingOut and Departing (≈ 20–30 s) while a new car arrives every 5 s, so both spaces are taken most of the time; `npcVisit` hit a moment with 2 claims. By design.
- **No checkout prompt:** no visit ever reserved, so none reached `CheckingOut` (`ENTRY.CheckingOut` enables the prompt).
- **Tree position (-104.5, -99):** world coordinates; the placement transform is in the lot frame (`PlacementService` 123). No visit reached `WalkingToTree`, so it played no part.
- Default prices are fine: `BusinessState.new` sets `mediumPrices` from `typicalMediumFor` (Douglas 140); the customer-8 budget is 150 % = 210.

## Source of truth
- PRODUCT_SPEC: "Tutorial: short and guided: order → place → customer picks up"; "Exact prices and demand are data-driven and tuned later" (engineering decides PROVISIONAL demand values); server-authoritative money.
- GAME_DESIGN §4 (conversion score, "prevent guaranteed purchases and runaway income") and §5 (customers). The tutorial guarantee is a one-time, bounded exception (one save, ends with the first sale).
- `docs/plans/CM2-49.md` (tutorial steps and events; `Sold` from `completeVisit` ends the tutorial).
- Backlog 14a acceptance.

## Implementer tier
Tier: L. Reason: changes the sale path (customer pick → reservation → paid sale) of a bug whose cause was unknown when it was filed; money and stock change through it.

## Skills to load
roblox-collaboration-mode, roblox-security, roblox-npc-ai, roblox-luau-core, roblox-luau-types, roblox-game-design (tutorial/FTUE).

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/Tutorial.lua` | Change | `Tutorial.guaranteesSale(state)` |
| `src/shared/CustomerSelection.lua` | Change | `CustomerSelection.chooseGuaranteed(state)`; shared private helper for sorted unreserved IDs |
| `src/server/Services/CustomerSimulationService.lua` | Change | `beginVisit` option `guaranteed` |
| `src/server/Services/CompanyStateService.lua` | Change | `npcDecide`: tutorial guarantee, `NoStock` code; require `Tutorial` |
| `src/server/Services/CustomerNpcService.lua` | Change | per-visit `decision`, bounded decision log, snapshot fields, `resetForTest` clears it |
| `src/server/Services/StudioTestService.lua` | Change | `forceCustomer` through the arrival override |
| `src/server/main.server.lua` | Change | remove `forcedRolls` and `setForcedRolls` |
| `tests/studio/Cases/Tutorial_Test.lua`, `CustomerSelection_Test.lua`, `NpcTransactions_Test.lua`, `CustomerNpcService_Test.lua` | Change | 6 new cases (below) |
| `tests/studio/Playtest/RunPlaytest.lua` | Change | `RunPlaytest.BUILD = "cm2-sale1"` |
| `docs/TEST_PLAN.md`, `docs/GAME_DESIGN.md`, `docs/DECISION_LOG.md` | Change | hook docs, tutorial customer sentence, decision entry |

## Data and config
- No save schema change, no new GameConfig key, no new remote or action. `SCHEMA_VERSION` unchanged.
- `CustomerNpcService`: local constant `DECISION_LOG_LIMIT = 20` (same as `SNAP_LOG_LIMIT`).
- Tutorial customer: PROVISIONAL (reference tutorial not observed).

## Steps
0. **Reproduce first.** Add test cases T3 and T5 (below) before any source change, run `lune run tests/headless/run.luau`, and record in the report that both FAIL (T3: `npcDecide` returns `false, "NoEligibleStock"`; T5: the visit ends in `Departing` without a sale). Then implement steps 1–7 and re-run.

1. **`src/shared/Tutorial.lua`**, after `Tutorial.advance`:
   ```lua
   -- CM2-SALE1: on the Checkout step the next walking customer buys for sure (tutorial customer).
   function Tutorial.guaranteesSale(state: any): boolean
   ```
   Returns `type(state) == "table" and Tutorial.isValid(state.tutorial) and state.tutorial.step == "Checkout"`.

2. **`src/shared/CustomerSelection.lua`**:
   - Move the "unreserved placement IDs, sorted" block of `choose` into a private helper `local function unreservedIds(state): { string }` and use it in `choose` (behaviour unchanged).
   - New function after `choose`:
     ```lua
     -- CM2-SALE1 tutorial customer: the first unreserved displayed tree (sorted placement IDs)
     -- with a numeric medium price and a valid size, at its current sale price. No preference,
     -- budget or Demand check; conversionScore 1 converts every roll in [0, 1].
     function CustomerSelection.chooseGuaranteed(state)
     ```
     Same `state`/`layout`/`placements` type guard as `choose` (return nil). For each ID: `placement` must be a table, `mediumPrice = state.mediumPrices[placement.speciesId]` a number, `Economy.typicalPrice(placement.speciesId, placement.sizeId) ~= nil`; return `{ placementId = id, salePrice = Economy.priceForSize(mediumPrice, placement.sizeId), conversionScore = 1 }`. None: nil.

3. **`CustomerSimulationService.beginVisit`**: options type gains `guaranteed: boolean?`; update the header comment (one line: "guaranteed (CM2-SALE1) picks with `CustomerSelection.chooseGuaranteed`"). Replace line 34 with:
   ```lua
   local candidate = if options ~= nil and options.guaranteed == true
       then CustomerSelection.chooseGuaranteed(state)
       else CustomerSelection.choose(state, profile, if options ~= nil then options.priceTolerance else nil)
   ```
   Everything else unchanged (profile check first, visit and abandonment counters, roll check, reservation).

4. **`CompanyStateService`**:
   - Add `local Tutorial = require(Shared:WaitForChild("Tutorial"))` after the `SupplierCatalog` require.
   - `npcDecide`, inside the section after the `NoClaim` check: compute `local available = false` (true when any `state.layout.placements` key has no `state.reservations` entry; same loop as `npcArrive` 1091–1096). Pass `guaranteed = Tutorial.guaranteesSale(state)` in the `beginVisit` options table next to `duration`, `customerId`, `priceTolerance`. On `not started`: `if visit == "NoEligibleStock" and not available then return false, "NoStock" end` then `return false, visit`.
   - Update the comment above `npcDecide`: "On the tutorial's Checkout step the pick is guaranteed (CM2-SALE1). A failed pick only changes beginVisit's visit and abandonment counters; `NoStock` means every displayed tree was reserved."
   - No other change: revision, dirty flag, notification and return shape stay as they are.

5. **`CustomerNpcService`**:
   - Constructor: `self._decisionLog = {}`. `newVisit`: field `decision = nil :: string?`.
   - Header comment of the snapshot section or above the helper: "Decision log (CM2-SALE1): the last DECISION_LOG_LIMIT picks, a Studio test instrument."
   - New method `CustomerNpcService:_logDecision(visit)`: appends `{ visitId = visit.id, companyId = visit.companyId, customerNumber = visit.customerNumber, decision = visit.decision, placementId = visit.placementId, salePrice = visit.salePrice }`, then removes from the front while `#self._decisionLog > DECISION_LOG_LIMIT`.
   - `_decide`: on success set the visit fields as now, then `visit.decision = "Reserved"`; on failure `visit.decision = tostring(result)`. Call `self:_logDecision(visit)` in both branches before `self:_enter(...)`.
   - `snapshot()`: each visit entry gains `decision = visit.decision`; the returned table gains `decisionLog` (a list of `table.clone(entry)` in log order).
   - `resetForTest(companyId)`: after the hard removals, remove every log entry whose `companyId == companyId` (all entries when `companyId == nil`), iterating backwards. Update its comment ("… and drops its decision-log entries").

6. **`StudioTestService` `forceCustomer`**: keep the argument check (`type(arg) == "number" and arg >= 1`, else return nil). New body: `local ids = companies:liveCompanyIds()`; if `#ids == 0` return `failure("NoActiveSave")`; for each ID call `context.npc:setArrivalOverrideForTest(id, math.floor(arg))` (use `context.npc`; the local `npc` is declared further down); return `true`. Comment: "The next live arrival of every loaded save gets profile `arg` and roll 0 (as npcNextArrival; CM2-SALE1: a server-wide forced roll went to whichever visit decided first)."

7. **`main.server.lua`**: delete `forcedRolls` and the `setForcedRolls` context entry; `businessRoll` returns `math.random()`. Comment above `clockOffset`: "Studio playtests can fast-forward the business clock and pause random customers through StudioTestHook (below). Outside Studio both stay at their neutral values." `CompanyStateService:setCustomerSequence` stays (unused, harmless).

8. **`RunPlaytest.BUILD = "cm2-sale1"`.**

9. **Docs** (English, short):
   - `docs/DECISION_LOG.md`, new entry at the end: "## 2026-11-25 — Tutorial customer and pick diagnostics, CM2-SALE1 (engineering)". Bullets: cause (the table above in two lines: exact preference 1/12 × conversion 0.026 on a one-tree lot ≈ 0.2 % per visit); decision: on tutorial step `Checkout` the walking customer's pick ignores preference, budget and roll and takes the first unreserved displayed tree at its current price (PROVISIONAL), it ends with the first sale or a skip; `npcDecide` reports `NoStock` when every displayed tree is reserved; `npcSnapshot` gains `decision` and `decisionLog`; `forceCustomer` uses the arrival override; correction of the backlog counter note; early-lot demand is the follow-up (see Out of scope).
   - `docs/GAME_DESIGN.md` §5, append to the paragraph starting "Each customer has a seeded preference": "Tutorial customer (CM2-SALE1, PROVISIONAL): while the save's tutorial is on its Checkout step, a walking customer takes the first unreserved displayed tree at its current price regardless of preference, budget or conversion score; normal demand applies after the first sale."
   - `docs/TEST_PLAN.md` §3b: in the `forceCustomer` sentence replace "makes the next arriving customer profile `n` and converts it" with "gives the next live arrival of every loaded save profile `n` and roll 0, like `npcNextArrival` (`NoActiveSave` without one)"; in the walking-customers bullet add to `npcSnapshot`: "`decision` per visit and `decisionLog` (the last 20 picks `{visitId, companyId, customerNumber, decision, placementId, salePrice}`; `decision` is `Reserved` or the `npcDecide` code such as `NoEligibleStock`, `NoConversion`, `NoStock`, `NoClaim`)", and to `npcReset`: "and clears the decision log".

## Tests (headless)
Expected count: 602 + 6 = 608.
| Test case file | Test name | Asserts |
|---|---|---|
| Tutorial_Test | T1 "guaranteesSale only on the Checkout step (CM2-SALE1)" | `{step=Checkout, skipped=false}` true; Order, Stock, Done false; `{step=Done, skipped=true}` false; invalid `{step=Checkout, skipped=true}` false; `guaranteesSale(nil)` false |
| CustomerSelection_Test | T2 "chooseGuaranteed takes the first unreserved priced tree (CM2-SALE1)" | `BusinessState.new("personal:42", 42)`; placements `a` and `b` NobleFir Small, `c` DouglasFir Medium; `reservations.a = {customerId="npc:99", expiresAt=200, salePrice=1}`. `chooseGuaranteed` → placementId `b`, salePrice 147 (`priceForSize(184, "Small")`), conversionScore 1; `choose(state, CustomerProfile.create(1))` is nil (preference filter); reserve `b` and `c` the same way → `chooseGuaranteed` nil |
| NpcTransactions_Test | T3 "npcDecide sells for sure on the tutorial's Checkout step (CM2-SALE1)" | `setup` gains an optional second parameter `roll` (the roll function returns `roll or 0`). `setup(1, 0.99)`; `state.tutorial = {step="Checkout", skipped=false}`; `npcArrive(COMPANY, "visit:1")` ok; `npcDecide(COMPANY, "visit:1", 5)` (no own roll) → ok, placementId `douglas_1`, salePrice 140; `npcSettle(COMPANY, "visit:1", "douglas_1")` ok; cash + 140, sales + 1, `tutorial.step == "Done"`; then `douglas(state, "douglas_2", -14)`, `npcArrive "visit:2"` ok, `npcDecide(COMPANY, "visit:2", 5)` → false, `"NoEligibleStock"` (normal demand after Done) |
| NpcTransactions_Test | T4 "npcDecide reports NoStock when every displayed tree is reserved (CM2-SALE1)" | `setup(1)`; arrive `visit:1`, `visit:2`; `npcDecide(..., "visit:1", 8, 0)` ok; record visits/abandoned; `npcDecide(..., "visit:2", 8, 0)` → false, `"NoStock"`; customerVisits + 1, abandonedCustomers + 1 |
| CustomerNpcService_Test | T5 "a live tutorial arrival buys with a random roll (CM2-SALE1)" | harness roll function becomes `return h.roll or 0`. `addCompany(h, A, PLOT_1, 1)`; `state.tutorial = {step="Checkout", skipped=false}`; `h.roll = 0.99`; cash0; `arrivalPass(false) == 1`; the visit (customer number 1, Fraser Small preference) `runUntil ... "WaitingAtCar", 200`; sales 1, cash == cash0 + 140, tutorial step `Done`; `snapshot().decisionLog[1].decision == "Reserved"` with that visit's ID |
| CustomerNpcService_Test | T6 "the decision log records each pick and resetForTest clears it (CM2-SALE1)" | `addCompany(h, A, PLOT_1, 1)`; `spawn(h, A, 5)` until `Departing`; `spawn(h, A, 8)` until `WalkingToTree`; `decisionLog` has 2 entries in order: (first ID, 5, `NoEligibleStock`, placementId nil) and (second ID, 8, `Reserved`, `douglas_1`, salePrice 140); `visitOf(h, second).decision == "Reserved"`; `h.npc:resetForTest(A)` → `#snapshot().decisionLog == 0` |

Existing cases must pass unchanged (`npcDecide failure counts an abandonment` still gets `NoEligibleStock`: its tree is unreserved; `visitForTest reports a non-matching profile` is outside `npcDecide`).

## Playtest (Studio, via playtester)
Run now (tier L, sale path). PC view. `U` = the real player's UserId; hook = `ServerStorage.StudioTestHook:Invoke(...)` in the Server data model.
1. **Setup.** Place 92354134900807, Rojo synced to the implementation commit, Play. `require(ServerStorage.UnitTest.Playtest.RunPlaytest).BUILD == "cm2-sale1"`. Unit runner `require(ServerStorage.UnitTest.RunUnitTest)(nil, 10)` → 608 passed, 0 failed.
2. **Fresh save.** `tutorialOffer {userId=U, offered=false}` → ok. Create and play "SALE1 Tut" through the save picker. `snapshot U`: `tutorial.step == "Order"`; record cash C0, `mediumPrices.DouglasFir` (expect 140), reputation, `placementCount` 0. `customerOrders U`: `parkingSpaces` 2. `shopClearBoosts` (no Cash Rush may double the sale; `snapshot.purchases` must show no active cash pass or boost, else report it before step 7). `pauseCustomers true`.
3. **Order and stock.** `act {userId=U, action="Supplier.PlaceOrder", payload={speciesId="DouglasFir", sizeId="Medium", quantity=1}}` → ok, note `data.bay` = B; step `Stock`; cash C0 − 28. `advanceClock 60` until `snapshot.bays` shows the tree in bay B (at most 5 times). `act {userId=U, action="Stock.Place", payload={bay=B, speciesId="DouglasFir", sizeId="Medium", x=-35, z=-13, rotation=0, count=1, gap=0.5}}` → ok; step `Checkout`; `snapshot.placements` has 1 entry: record placementId P, x, z, `reserved == false`.
4. **Part A, diagnostic (old demand path).** `tutorialSet {userId=U, step="Done"}`; `npcReset`; `pauseCustomers false`; wait 120 s; `pauseCustomers true`. Read `npcSnapshot().decisionLog`, `snapshot U` (visits, abandoned, drive-pasts, sales) and `customerOrders U`.activeCustomers. Expected: every entry `NoEligibleStock`, except customer numbers ≡ 8 (mod 12), which are `NoConversion` (or rarely `Reserved`); sales unchanged; visits delta == abandoned delta. Record the full log in the report (this is the reproduction reading). **Branch:** if any entry is something else (`NoClaim`, `NoStock` while P is unreserved, `CompanyUnavailable`, `InvalidCustomer`), or a `Reserved` visit never reaches `CheckingOut` within 60 s, STOP after step 5 and report: the planner amends the plan.
5. **forceCustomer check.** Wait until `npcSnapshot().count == 0` (≤ 60 s). `forceCustomer 8` → true; `pauseCustomers false`; within 30 s the log has an entry with customerNumber 8 and decision `Reserved`, placementId P. `pauseCustomers true`; `npcGiveUp <that visitId>` → ok; within 5 s P `reserved == false`. Wait until count 0; `npcReset`.
6. **Part B, the fix.** `tutorialSet {userId=U, step="Checkout"}`; record cash C1, sales S1, abandoned A1. `pauseCustomers false`. Poll `npcSnapshot` every 2 s, up to 120 s, until a visit on the player's plot is `CheckingOut`. Expected: the first log entry is `Reserved` with placementId P and salePrice 140; P `reserved == true`; the plot's `CheckoutCounter.CounterBase.CheckoutPrompt.Enabled == true` with attribute `Price` 140.
7. **Real sale.** Teleport the character to `CounterBase.Position + Vector3.new(3, 3, 0)`, wait 0.5 s, `prompt {userId=U, kind="checkout"}` (or trigger the prompt with E). Within 3 s: sales S1 + 1, cash C1 + 140 exactly, `tutorial.step == "Done"`, player attribute `TutorialStep == "Done"`; the client shows "Well done! Your tree lot is open." `pauseCustomers true`.
8. **No lost customer.** Every log entry from step 6 to the sale is `Reserved` or `NoStock` (no `NoEligibleStock`, no `NoConversion`); abandoned − A1 == number of `NoStock` entries; `walkedOutCustomers` unchanged.
9. **Regression.** Back on "Playtest A": `runPlaytest {mode="full"}` → `SUMMARY … result=PASS` (all steps). Console: only the known `rbxassetid://203785492` warning (x6) and nothing new.
10. **Cleanup.** Delete "SALE1 Tut"; leave "Playtest A", "Tree Lot 264", "Tree Lot 1". `pauseCustomers false`.

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests` (0 errors, 0 warnings), `lune run tests/headless/run.luau` (608 run, 608 passed), `rojo build default.project.json --output build.rbxlx` (not committed).
- T3 and T5 FAIL before the fix and PASS after it (implementer report).
- Backlog 14a (1): the cause table above plus the Studio part A log are recorded in PROGRESS.md (reviewer); readings cover the tree's state and price (step 3/6), target selection and per-visit result (decision log), prompt enablement (step 6), parking occupancy (`activeCustomers`, the explanation above).
- (2): fix plus T1–T6; no new failure in the standard checks.
- (3): steps 6–8 PASS: a fresh save completes the tutorial through a real sale, server cash rises by exactly 140, `tutorial.step == "Done"`, and no customer is lost while an unreserved displayed tree exists. Step 9 PASS.
- Money stays server-authoritative: the price comes from `state.mediumPrices` inside the company section; no client value is read; the guarantee depends only on the saved tutorial step.

## Out of scope
- **Early-lot demand after the tutorial** (follow-up for the orchestrator to file, tier M, before Gate B): with the same model, a lot of 6 Douglas Medium sells ≈ 1.1 % per visit (1/12 × 0.128) and a mixed S/M/L lot ≈ 3.2 %; at about 4–5 visits a minute with 2 parking spaces that is one sale every 6–19 minutes. Proposal for its planner: soft preferences (a non-preferred tree within the budget scaled to its own benchmark, with an interest factor) and gentler variety and stock factors, measured with a headless conversion simulation; values PROVISIONAL (engineering, PRODUCT_SPEC "demand tuned later"). This plan does not change `CustomerProfile`, `Demand` or `choose`.
- The phone run "N1 (b) re-run after CM2-SALE1" (queue item) and analytics display.
- `simulateCustomerVisits` and `visitForTest` keep normal demand (no guarantee).

## Amendment 1 (2026-11-25, Studio af5facc4 result; `planner-high`)
No source or test change. Steps 1-6 PASS as written. Changes to steps 2, 7, 9 and Acceptance (3):

**Step 7 cash: the sale pays the price times the save's cash multiplier.** `npcSettle` (`CompanyStateService.lua` 1254-1262) passes `self:cashMultiplierOf(companyId, state)` (`CompanyPurchases.lua` 63-65) to `completeVisit`; `completeReservedSale` credits the reservation's `salePrice` (`CustomerService.lua` 111-116), then `completeVisit` adds `floor(salePrice x (M - 1))` to cash and revenue (`CustomerSimulationService.lua` 88-94). M = `Purchases.cashMultiplier` (`Purchases.lua` 169-178): x2 for the runtime perk `cashX2` (Golden Till, set by `MonetizationService:refreshPerks` 343-365 from `UserOwnsGamePassAsync`, `main.server.lua` 253-255), x2 for `boosts.CashX2 > 0`. Pass perks are never saved (`CompanyPurchases.lua` 5-6), so `snapshot.purchases.owned` cannot show them; the old step-2 guard could not see the pass. CM2-SALE1 touches none of these lines.
- **Verdict for this run:** sales +1 (one sale), reserved `salePrice` 140 (step 6, prompt `Price` 140), `boosts.CashX2` 0, cash and revenue +280 = 140 + bonus 140. The only source of that bonus with no boost is the `cashX2` perk, and the test account (userId 4584569287) owns PassCashX2 (PC-10). M = 2, expected +280: **step 7 PASS** (INFERRED from code; the run did not read `ShopPassCashX2`). PROGRESS also needs the `TutorialStep` attribute and the client line "Well done! Your tree lot is open." from step 7, and step 8's readings (abandoned - A1 == 1 for customer 21's `NoStock`, `walkedOutCustomers` unchanged).

**Step 2, for every later run (and the N1 (b) re-run):** after `shopClearBoosts` add `shopPasses {userId=U, passes={}}` (runtime override, as PREFLIGHT does since CM2-UVF8), then read the player attribute `ShopPassCashX2` (must be false) and `snapshot.purchases.boosts.CashX2` (must be 0): M = 1. If either cannot be neutralised, record M and use it in step 7.

**Step 7, replace "cash C1 + 140 exactly":** "cash C1 + 140 x M exactly and `snapshot.revenue` + 140 x M (M from step 2)".

**Step 9 (regression) verdicts:** 60/62; both FAILs are not caused by CM2-SALE1 and get their own tasks (backlog "Follow-up tasks (created 2026-11-25 from CM2-SALE1)"); step 9 counts as PASS for 14a.
| Step | Cause | Evidence |
|---|---|---|
| 53 SHOP_GUARD "StarterPack is Buy" | Stale expectation since 3c5ac49 (CM2-46c IDs) | `Steps/Shop.lua` 198-204 expects all 27 `ComingSoon` ("every ID 0"); `ShopConfig.lua` `CREATED_IDS` gives 12 products an ID, and `MonetizationService:_state` 379-389 returns `ComingSoon` only for `id <= 0 or not ready`. The last 62/62 runs (CM2-G12a, CM2-UVF8, CM2-10abc) predate 3c5ac49; no full run since. The check threw before `Shop.Prompt CashPinecone`, so no real purchase dialog opened. Task CM2-PT53 (S). |
| 35 FINDER "did not create a save" | Shadow state, not SALE1; exact cause open | `Save.FinderStart` returned ok with `created = false`, which `SaveSlotCrossServer.lua` 255-264 does only when the shadow already has a valid listing (`_validListing` 204-) or its active save is its own co-op save with a free seat (`_listableActive` 231-248). No save or finder code changed since 2026-11-23 (`git log`), the SALE1 diff touches no SaveSlot file and no playtest step uses `forceCustomer`. Likely a leftover shadow-owned Duo from an aborted run: step 32 plays the shadow's first `Owner` row (`Steps/Saves.lua` 288-296), and cleanup deletes the finder save only when `S.finderSaveId` was set in the same run (`Support/Saves.lua` 170-188). Task CM2-PT35 (S, investigation). |

**Acceptance (3):** read "server cash rises by exactly 140" as "by exactly 140 x M (step 2)"; "Step 9 PASS" as "every step PASS except those shown not caused by CM2-SALE1 and filed as tasks".

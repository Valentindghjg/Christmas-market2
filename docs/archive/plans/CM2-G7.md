# CM2-G7 — Price benchmark (wholesale × 5) and Pricing tab

Written by: `planner` (Opus 5.5, high). Implemented by: the agent for the tier below. Playtested by: `playtester` (Sonnet 5.5, medium). Reviewed and committed by: `reviewer` (Opus 5.5, medium). Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
The "typical" price of every tree is 5 × its medium wholesale, and price bounds, automatic pricing, customer budgets and the demand score all use it. In the Lot Manager's Pricing tab the player sees, per species, the wholesale, typical price, margin in $ and %, a sentiment sentence and the Small/Medium/Large prices with profit. The player changes the medium price with −5/−1/+1/+5 or turns automatic pricing on or off.

## Source of truth
- REFERENCE_GAME_LIVE_TEST §4.3 (OBSERVED): medium price per species; Small = 80 %, Large = 130 %; −5/−1/+1/+5 buttons; card content; typical ≈ 5 × medium wholesale (140/160/184/210); the $82/$96/$105 were a player's settings. §4.1: wholesale table (in `GameConfig.Trees` since CM2-G6).
- Backlog: original CM2-G7 line (P2) and launch order 7; GitHub CM2-21 (medium prices with S/L multipliers plus an optional auto rule; changes authorized, rate-limited and saved) and CM2-41 (pricing panel with feedback and error cases).
- PRODUCT_SPEC 2026-11-21: Fidelity (reference numbers adopted), Language (English, full-sentence keys), Platforms (touch first). GAME_DESIGN §4 (manual plus optional automatic pricing, min 50 %, max 250 % of the benchmark).
- `docs/archive/plans/CM2-G6.md` (Douglas 70/72 PROVISIONAL, left to G7) and `docs/plans/CM2-40.md` (tab contract, UiKit, page layout).

## Implementer tier
Tier: L. Reason: it changes the server bounds that validate `Pricing.SetMediumPrice`, the default prices of new saves and the customer budget and price checks that decide which sales credit cash (money and remote validation).

## Skills to load
roblox-collaboration-mode, roblox-networking, roblox-security, roblox-game-design, roblox-gui, roblox-input, roblox-localization, roblox-luau-core, roblox-luau-patterns, roblox-luau-types, roblox-tooling.

## Decisions (settled)
| Topic | Decision |
|---|---|
| Benchmark | `typicalMedium = wholesale.Medium × 5` per species (OBSERVED ≈ 5×): Douglas 140, Fraser 160, Noble 185, Blue Spruce 210. Noble is 185, not the observed 184 (derived rule, 0.5 % off). |
| Per-size benchmark | `typical(size) = Economy.priceForSize(typicalMedium, size)` (the 80/130 rule, PROVISIONAL). Not `wholesale[size] × 5`: the player sets only the medium price, so a per-size wholesale benchmark would make Large always look cheap and Small expensive. |
| Manual prices | One medium price per species; S/L follow 80/130 % (OBSERVED §4.3). No price per size: launch order 7's "per species and size" means the shown S/M/L prices. No save field change. |
| Save schema | None. `SCHEMA_VERSION` stays 12, `GameConfig.VERSION` stays 1. `mediumPrices` and `autoPricing` are already saved. |
| Existing saves | Saved prices are player settings and are kept as they are. Only missing or corrupt prices are refilled (existing backfill, now with the typical price). The old defaults 72/82/96/105 lie inside the new bounds. A saved price outside the bounds is left alone; the tab's next step press sends a value clamped into the bounds. |
| New saves | Start at the typical medium price (PROVISIONAL). `initialMediumPrice` and `typicalMedium` are removed from `GameConfig.Trees`. |
| Bounds | Unchanged multipliers 0.5/2.5: `min = ceil(typical × 0.5)`, `max = floor(typical × 2.5)` → Douglas 70–350, Fraser 80–400, Noble 93–462, Blue 105–525. Rate limit unchanged (10 per action per 10 s, 40 overall). |
| Auto pricing | Same rule, new base: target = `floor(typical × (1 − min(displayed/5, 1) × 0.15) + 0.5)`, clamped to bounds, every 3 s; a manual price turns it off (as today); reservations keep their locked price. |
| Margin | `margin = medium − wholesale.Medium`; `marginPercent = floor(margin × 100 / medium + 0.5)` (matches all four reference cards: 81, 80, 81, 80). Per size: `price = priceForSize(medium, size)`, `profit = price − wholesale[size]`. |
| Sentiment | From `medium × 100` against `typical × percent`: ≤ 85 Bargain, ≤ 110 Fair, ≤ 130 Pricey, above TooHigh (PROVISIONAL thresholds; our own wording). |
| Budgets | `budget = (typical(prefSpecies, prefSize) × p + 50) // 100`, `p = 85 + ((n × 17) % 71)` → 85–155 % (PROVISIONAL, replaced by CM2-N1). At Fair prices most shoppers can pay, above 130 % about a third. |
| Demand | `priceRatio = salePrice / typical(species, size)`; `Demand.score` unchanged. |

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/GameConfig.lua` | Change | `GameConfig.Pricing`, `typicalMediumFor`; remove `typicalMedium`, `initialMediumPrice` |
| `src/shared/Economy.lua` | Change | `Economy.typicalPrice` |
| `src/shared/BusinessState.lua` | Change | Defaults and backfill use `typicalMediumFor` |
| `src/shared/CustomerProfile.lua` | Change | Budget relative to the benchmark |
| `src/shared/CustomerSelection.lua` | Change | Price ratio against the size benchmark |
| `src/shared/PricingView.lua` | New | Pure text and step helpers for the tab (headless-tested) |
| `src/server/Services/PricingService.lua` | Change | Bounds and auto base, `sentiment`, `marginPercent`, `summary` |
| `src/server/Services/CompanyStateService.lua` | Change | `pricing = PricingService.summary(state)` in the `Company.GetSummary` data |
| `src/client/LotManagerTabs/PricingTab.lua` | New | Pricing tab |
| `src/shared/Localization.lua` | Change | Pricing keys (en and de) |
| `tests/headless/run.luau` | Change | `PricingView = "src/shared/PricingView.lua"` in `sourcePaths` |
| `tests/studio/Playtest/RunPlaytest.lua` | Change | BUILD `cm2-g7`, threshold 308, playtest price fixture |
| Tests in `tests/studio/Cases/` | Change/New | See Tests |
| `docs/GAME_DESIGN.md`, `docs/IMPLEMENTATION_PLAN.md`, `docs/DECISION_LOG.md`, `docs/TEST_PLAN.md` | Change | Step 11 |

Do not change: `Protocol.lua`, `Demand.lua`, `WorldService.lua`, `UiKit.lua`, `LotManager.lua`, `UiTheme.lua`, rate limits, `docs/PROGRESS.md` and `docs/CLAUDE_BACKLOG.md` (the reviewer updates both).

## Data and config
```lua
-- Price benchmark and pricing panel (CM2-G7, docs/REFERENCE_GAME_LIVE_TEST.md §4.3).
GameConfig.Pricing = {
	BenchmarkMultiplier = 5, -- OBSERVED: the "typical" price is about 5 x medium wholesale
	Steps = { -5, -1, 1, 5 }, -- OBSERVED price buttons
	SentimentPercent = { Bargain = 85, Fair = 110, Pricey = 130 }, -- PROVISIONAL, above Pricey = TooHigh
	BudgetPercent = { Min = 85, Max = 155 }, -- PROVISIONAL customer budget vs the size benchmark
}
```
Place it directly above `GameConfig.SpeciesOrder`. In `GameConfig.Trees`, delete the `typicalMedium` and `initialMediumPrice` lines from all four species and replace the comment line "typicalMedium and initialMediumPrice are PROVISIONAL until CM2-G7 …" with "-- The typical retail price is derived: GameConfig.typicalMediumFor (CM2-G7)."

Summary sub-table `pricing` (server-derived, presentation-safe, about 4 × 12 numbers):
```
pricing = { automatic: boolean, species: { PricingEntry } }  -- GameConfig.SpeciesOrder
PricingEntry = { speciesId, mediumPrice, minPrice, maxPrice, typicalMedium, wholesaleMedium,
  marginMedium, marginPercent, sentiment: "Bargain"|"Fair"|"Pricey"|"TooHigh",
  sizes = { {sizeId, price, wholesale, profit} } }  -- GameConfig.SizeIds order
```

## Steps
1. **GameConfig**: the table above, plus
   `function GameConfig.typicalMediumFor(speciesId: unknown): number?`: nil unless `speciesId` is a string key of `Trees`; else `tree.wholesale.Medium * GameConfig.Pricing.BenchmarkMultiplier`.
2. **Economy**: `function Economy.typicalPrice(speciesId: unknown, sizeId: unknown): number?`: nil when `typicalMediumFor` is nil or `not GameConfig.isValidSize(sizeId)`; else `Economy.priceForSize(typical, sizeId)`.
3. **BusinessState**: `defaultMediumPrices` and `backfillMediumPrices` use `GameConfig.typicalMediumFor(speciesId) :: number` instead of `tree.initialMediumPrice` (iterate `for speciesId in pairs(GameConfig.Trees)`). Nothing else.
4. **CustomerProfile**: require `script.Parent.GameConfig` and `script.Parent.Economy`. In `create`, after picking species and size:
   `local percent = Budget.Min + ((customerNumber * 17) % (Budget.Max - Budget.Min + 1))` with `Budget = GameConfig.Pricing.BudgetPercent`, and `budget = ((Economy.typicalPrice(species, size) :: number) * percent + 50) // 100`. Keep the cycle, the patience formula and `canPurchase` unchanged. Update the file comment: budgets follow the size benchmark.
5. **CustomerSelection**: replace `tree.typicalMedium` with `local typical = Economy.typicalPrice(placement.speciesId, placement.sizeId)`; skip the placement when it is nil; score `Demand.score(salePrice / typical, state.reputation, 1, varietyFactor(state), stockFactor)`. Remove the now unused `tree` local.
6. **PricingService** (require Shared `Economy`):
   - `bounds(speciesId)`: base `GameConfig.typicalMediumFor(speciesId)`; nil when unknown; same rounding.
   - `applyAutomatic`: iterate `for speciesId in pairs(GameConfig.Trees)` with `typical = GameConfig.typicalMediumFor(speciesId) :: number` in the target formula; everything else unchanged.
   - `PricingService.sentiment(mediumPrice: number, typicalMedium: number): string`: `p = mediumPrice * 100`; `p <= typical * Bargain` → `"Bargain"`, `<= typical * Fair` → `"Fair"`, `<= typical * Pricey` → `"Pricey"`, else `"TooHigh"` (percent values from `SentimentPercent`).
   - `PricingService.marginPercent(price: number, wholesale: number): number` = `math.floor((price - wholesale) * 100 / price + 0.5)`; returns 0 when `price < 1`.
   - `PricingService.summary(state)`: returns the table from Data, built from `state.mediumPrices`, `state.autoPricing == true`, `bounds`, `typicalMediumFor`, `GameConfig.wholesaleFor` and `Economy.priceForSize`. No state change.
7. **CompanyStateService**: in the `Company.GetSummary` data table add `pricing = PricingService.summary(state),` after `customers`. No other change (dispatch, member rights and the placement refresh after a price change stay).
8. **PricingView** (`src/shared/PricingView.lua`, `--!strict`, pure; requires GameConfig only). `export type Format = (key: string, ...any) -> string`.
   - `PricingView.SENTIMENT_KEYS = { Bargain = "pricingSentimentBargain", Fair = "pricingSentimentFair", Pricey = "pricingSentimentPricey", TooHigh = "pricingSentimentTooHigh" }`.
   - `card(entry: any, format: Format): {name, sentiment, wholesaleTypical, margin, sizes, price}?`: nil unless `entry` is a table with a known `speciesId`, number fields `mediumPrice, typicalMedium, wholesaleMedium, marginMedium, marginPercent`, a known `sentiment`, and `sizes` holding numbers `price` and `profit` for Small, Medium and Large (found by `sizeId`). `name` = `GameConfig.Trees[id].displayName`; `price = format("pricingPrice", mediumPrice)`; `sentiment = format(SENTIMENT_KEYS[s])`; `wholesaleTypical = format("pricingWholesaleTypical", wholesaleMedium, typicalMedium)`; `margin = format("pricingMargin", marginMedium, marginPercent)`; `sizes = format("pricingSizes", S.price, S.profit, M.price, M.profit, L.price, L.profit)`.
   - `autoText(automatic: any, format): string` → `pricingAutoOn` when `automatic == true`, else `pricingAutoOff`.
   - `ruleText(format): string` = `format("pricingRule", round(Small × 100), round(Large × 100))` from `SizeMultipliers` (`math.floor(x * 100 + 0.5)` → 80, 130).
   - `stepTarget(current: number, delta: number, minPrice: number, maxPrice: number): number` = `math.clamp(current + delta, minPrice, maxPrice)`.
   - `errorText(errorCode: unknown, format): string`: `InvalidPrice` and `UnknownSpecies` → `pricingErrorInvalid`; `RateLimited` → `saveErrorRateLimited`; `ConnectionError` → `connectionError`; else `format("errorStatus", tostring(errorCode))`.
9. **PricingTab** (`src/client/LotManagerTabs/PricingTab.lua`, `--!strict`, same header and types as `SupplierTab`). `create(page, context)`; `fmt = UiKit.localizedFormat`. Offsets in px, column width 324 (fits the 340 px minimum body):

   | Instance (name) | Kind | Box (x, y, w, h) | Content |
   |---|---|---|---|
   | `PricingTitle` | label 22 | 0, 0, 324, 28 | `pricing` |
   | `PricingRule` | label 13, wrapped | 0, 32, 324, 52 | `ruleText` |
   | `AutoPricing` | button 15 | 0, 88, 324, 44 | `autoText`; Gold when on, Sand when off |
   | `AutoHint` | label 12, wrapped | 0, 136, 324, 48 | `pricingAutoHint` |
   | `PricingStatus` | label 13 | 0, 188, 324, 18 | last result or error |
   | `Price_<speciesId>` | Frame, Row colour, corner 10 | 0, 212 + (i−1)·188, 324, 180 | one card per `SpeciesOrder` entry |

   Card children (relative): `Name` label 15 (10, 6, 304, 20); `Sentiment` label 13 (10, 28, 304, 18); `WholesaleTypical` label 12 wrapped (10, 48, 304, 30); `Margin` label 12 (10, 80, 304, 18); `Sizes` label 12 wrapped (10, 98, 304, 28); buttons Sand 17 `Minus5` (10, 128, 56, 44), `Minus1` (70, 128, 56, 44), `Plus1` (198, 128, 56, 44), `Plus5` (258, 128, 56, 44) with text `fmt("pricingStep", delta)`; `Price` label 17, centred, `playerText = true` (130, 128, 64, 44). Wrapped labels: `TextWrapped = true`, `TextTruncate = None`. `page.CanvasSize = UDim2.fromOffset(0, 212 + #SpeciesOrder · 188)` (964).
   - `render(summary)`: `pricing = summary and summary.pricing`. If not a table: cards hidden, `PricingStatus` = `loading`, `AutoPricing.Active = false`. Else for each card `PricingView.card(entry, fmt)`; nil → card hidden; else card shown and texts set; `Price` shows `fmt("pricingPrice", pending[id])` while a pending target exists, else the card's `price`. `AutoPricing` text and colour from `pricing.automatic`. No other client arithmetic.
   - Step press (`Activated`): ignored without an entry. `base = pending[id] or entry.mediumPrice`; `pending[id] = PricingView.stepTarget(base, delta, entry.minPrice, entry.maxPrice)`; show it in `Price`; bump `generation[id]`; `task.delay(0.4, …)` sends only if the generation is unchanged and no request for that species is in flight (debounce, so repeated taps stay under the rate limit).
   - Send: `inFlight[id] = true`; `sent = pending[id]`; `context.request("Pricing.SetMediumPrice", { speciesId = id, mediumPrice = sent })`; then `inFlight[id] = false`. Success → `PricingStatus = fmt("pricingSaved", displayName, sent)`; failure → `PricingView.errorText(response.errorCode, fmt)`. If `pending[id] == sent` clear it, else send again at once with the newer target. Then `context.refresh()`.
   - Auto press: one in flight; `request("Pricing.SetAuto", { enabled = not (pricing.automatic == true) })`; failure → `errorText`; success clears the status; then `context.refresh()`.
   - Return `{ render = render }` (no `shown`).
10. **Localization** (en / de):

   | Key | en | de |
   |---|---|---|
   | `pricingRule` | Set the medium price for each tree. Small trees sell for %d%% of it and large trees for %d%%. Higher prices earn more per tree, but fewer customers buy. | Lege für jeden Baum den Preis für Mittel fest. Kleine Bäume kosten %d %% davon und große %d %%. Höhere Preise bringen mehr pro Baum, aber weniger Kunden kaufen. |
   | `pricingAutoOn` | Automatic pricing is on. | Automatische Preise sind an. |
   | `pricingAutoOff` | Automatic pricing is off. | Automatische Preise sind aus. |
   | `pricingAutoHint` | Automatic pricing follows the typical price and lowers it a little when many trees are on display. Changing a price yourself turns it off. | Automatische Preise folgen dem üblichen Preis und senken ihn etwas, wenn viele Bäume ausgestellt sind. Wenn du selbst einen Preis änderst, gehen sie aus. |
   | `pricingWholesaleTypical` | Wholesale for a medium tree is $%d. The typical price is $%d. | Ein mittlerer Baum kostet im Einkauf %d $. Der übliche Preis ist %d $. |
   | `pricingMargin` | Your margin on a medium tree is $%d (%d%%). | Deine Marge pro mittlerem Baum ist %d $ (%d %%). |
   | `pricingSizes` | Small $%d (profit $%d), medium $%d (profit $%d), large $%d (profit $%d). | Klein %d $ (Gewinn %d $), Mittel %d $ (Gewinn %d $), Groß %d $ (Gewinn %d $). |
   | `pricingPrice` | $%d | %d $ |
   | `pricingStep` | %+d | %+d |
   | `pricingSaved` | %s now sells for $%d as a medium tree. | %s kostet jetzt %d $ als mittlerer Baum. |
   | `pricingErrorInvalid` | That price is outside the allowed range. | Dieser Preis liegt außerhalb des erlaubten Bereichs. |
   | `pricingSentimentBargain` | Bargain price. Shoppers snap these trees up. | Schnäppchenpreis. Die Kunden greifen sofort zu. |
   | `pricingSentimentFair` | Fair price. Most shoppers are happy to pay it. | Fairer Preis. Die meisten Kunden zahlen ihn gern. |
   | `pricingSentimentPricey` | A little pricey. Some shoppers will walk away. | Etwas teuer. Manche Kunden gehen wieder. |
   | `pricingSentimentTooHigh` | Too expensive. Most shoppers will not buy. | Zu teuer. Die meisten Kunden kaufen nicht. |
11. **Docs**:
   - GAME_DESIGN §2 OBSERVED: replace `medium Frasier Fir $82, Noble Fir $96, Blue Spruce $105;` with `a "typical" retail price of about 5× the medium wholesale (REFERENCE_GAME_LIVE_TEST §4.3; the earlier $82/$96/$105 were one player's own settings, not game defaults);`. §4: replace the line `Medium price examples: …` with `Price benchmark ("typical" price): medium = 5 × medium wholesale (GameConfig.Pricing.BenchmarkMultiplier, OBSERVED): Douglas 140, Fraser 160, Noble 185, Blue Spruce 210; the Small and Large benchmarks follow the 80 %/130 % rule; new saves start at the typical price (PROVISIONAL). Small = round(0.8 × medium), large = round(1.3 × medium).` In the conversion paragraph change `sale/benchmark ratio` to `sale price / benchmark of the tree's size`.
   - IMPLEMENTATION_PLAN line 18: replace `Screenshot examples: … (wholesale $42).` with `The $82/$96/$105 screenshot prices were a player's own settings; the reference's typical price is about 5× medium wholesale (REFERENCE_GAME_LIVE_TEST §4.3, CM2-G7).`
   - DECISION_LOG: new entry "2026-11-22 - Price benchmark and Pricing tab, CM2-G7 (engineering)": the Decisions table as bullets (benchmark and per-size rule, Noble 185, no schema change, existing saves kept, budgets, sentiment thresholds, margin rounding, summary `pricing`, tab layout and debounce) and that it supersedes the CM2-G6 "Douglas 70/72 until CM2-G7" bullet. Plan: `docs/archive/plans/CM2-G7.md`.
   - TEST_PLAN §2: add rows `PRC-01 | Benchmark and bounds | typical = 5 × medium wholesale; manual prices outside 50–250 % of it rejected` and `PRC-02 | Pricing summary | margin $/%, S/M/L profit and sentiment equal the REFERENCE §4.3 cards`. §3b: "at least 293" → "at least 308"; §3 E: add "(CM2-G7 plan)".
12. **RunPlaytest**: `BUILD = "cm2-g7"`; step 01 check `>= 308` (message too). Directly below the `SupplierStockService` require add `local PricingService = require(Services:WaitForChild("PricingService"))` and `local PLAYTEST_PRICE = (PricingService.bounds(SPECIES)) :: number` (70). Directly below `actOk` add `local function priceToSell(userId: number)` that calls `actOk(userId, "Pricing.SetMediumPrice", { speciesId = SPECIES, mediumPrice = PLAYTEST_PRICE })`. In `preflight`, replace the check `mediumPrices[SPECIES] <= 125` with `priceToSell(R.userId)` (before the cash checks, both modes); in `shadowJoin`, call `priceToSell(S.userId)` after `setStaff`. Reason: new saves start at 140 and the fixed visit profiles must always afford the playtest tree.

## Tests (headless)
| Test case file | Test name | Asserts |
|---|---|---|
| GameConfig_Test | gives every species complete integer pricing data (changed) | loop `for speciesId, tree`; replace the two removed fields with `positiveInteger(GameConfig.typicalMediumFor(speciesId))` |
| GameConfig_Test | derives the typical price from wholesale x 5 | multiplier 5; Douglas 140, Fraser 160, Noble 185, Blue 210; nil for `"Pine"` and `5`; `Steps` = −5, −1, 1, 5; sentiment 85 < 110 < 130; budget 85 / 155 |
| Economy_Test | derives size benchmarks from the medium benchmark | Douglas S/M/L 112/140/182; Noble Large 241; nil for `"Pine"` and size `"Huge"` |
| BusinessState_Test | restores missing medium prices (changed) | `NobleFir == 185` |
| BusinessState_Test | a new company prices and stocks Douglas Fir (changed) | `DouglasFir == 140` |
| SupplierStockService_Test | existing save gains Douglas stock (changed) | expects `GameConfig.typicalMediumFor("DouglasFir")` |
| PricingService_Test | rejects price outside server bounds (changed) | price stays 160 |
| PricingService_Test | auto pricing discounts only with displayed stock (changed) | `updated.FrasierFir == 150`, `updated.NobleFir == nil`, `mediumPrices.NobleFir == 185` |
| PricingService_Test | bounds follow the benchmark | 70/350, 80/400, 93/462, 105/525; nil for `"Pine"`; Douglas 69 and 351 → `false, "InvalidPrice"`; 70 and 350 accepted |
| PricingService_Test | names the price sentiment by the benchmark | typical 140: 119 Bargain, 120 Fair, 154 Fair, 155 Pricey, 182 Pricey, 183 TooHigh |
| PricingService_Test | summary reports server prices, margins and sentiment | prices 146/164/192/210 → per species in order: typical 140/160/185/210; margin 118/132/155/168; percent 81/80/81/80; all Fair; Small 117/131/154/168 with profit 96/107/126/136; Large 190/213/250/273 with profit 149/167/196/212; Douglas min 70 max 350; `automatic == false` |
| CompanyStateService_Test | the company summary carries the pricing table | `sharedService(copyingPersistence())`; `Company.GetSummary` by 43: 4 entries, first `DouglasFir`, `mediumPrice` 140, sentiment Fair, `automatic` false |
| CompanyStateService_Test | a manual price and the auto flag survive a save and reload | 43 sets Fraser 150 then `SetAuto true`; `unloadCompany(SHARED)`; a new `Service.new(persistence, clock)` loads `SHARED`: Fraser 150, `autoPricing` true |
| CustomerService_Test | settles reserved displayed tree exactly once (changed) | sale price 160, cash 244 |
| CustomerProfile_Test | budgets follow the size benchmark | profile 1 budget 131, 8 → 210, 12 → 268; for n = 1..71 the budget lies between `floor(typical·0.85)` and `ceil(typical·1.55)` |
| CustomerSelection_Test | chooses compatible unreserved display tree (changed) | `salePrice == 128` |
| CustomerSelection_Test | uses the sale price over the size benchmark | Douglas medium 154, 5 Douglas Large placements, profile 12: `salePrice == 200`, `conversionScore == Demand.score(200 / 182, 90, 1, 1 / 3, 1)` |
| CustomerSelection_Test | scores the benchmark equally for every size and lower above it | Douglas 140, 5 Medium with profile 8 equals 5 Large with profile 12; Douglas 182 with 5 Medium and profile 8 scores lower |
| Demand_Test | scores the benchmark price at 0.65 | `math.abs(Demand.score(1, 500, 1, 1, 1) - 0.65) < 1e-9` |
| PricingView_Test (new) | shows the server values on the card | summary entry for Douglas at 146 with an `en` format: "Douglas Fir", "$146", Fair sentence, "Wholesale for a medium tree is $28. The typical price is $140.", "Your margin on a medium tree is $118 (81%).", "Small $117 (profit $96), medium $146 (profit $118), large $190 (profit $149)."; `card({ speciesId = "DouglasFir" }, fmt) == nil` |
| PricingView_Test | clamps step targets into the server bounds | (146, 5) → 151; (146, −1) → 145; (72, −5) → 70; (348, 5) → 350; (50, 1, 80, 400) → 80 |
| PricingView_Test | words the auto switch, the rule and errors | `autoText(true)` on sentence, `false` and `nil` off; `ruleText` is the full en sentence with 80 % and 130 %; `InvalidPrice` → the en `pricingErrorInvalid` text; `RateLimited` → the en `saveErrorRateLimited` text |
| Localization_Test | has every pricing key in English and German | every step-10 key in en and de; `format("en", "pricingStep", -5) == "-5"`, `5 → "+5"` |

Expected: `lune run tests/headless/run.luau` → 308 run, 308 passed (293 + 15 new).

## Playtest (Studio, via playtester)
1. Play (Server + Client), BUILD `cm2-g7`: `runPlaytest {mode="full"}` → 36/36 PASS, step 01 ≥ 308. Record that "Tree Lot 1" keeps its prices (snapshot before and after).
2. Server, hook `act` `Company.GetSummary` for the player on "Playtest A": `data.pricing.species` in order Douglas, Fraser, Noble, Blue; typical 140/160/185/210; wholesale 28/32/37/42; bounds 70–350, 80–400, 93–462, 105–525.
3. `act` `Pricing.SetMediumPrice` Douglas 146 → ok; the summary shows margin 118, 81 %, Fair, Small 117 (96), Medium 146 (118), Large 190 (149); a displayed Douglas Medium label reads $146. Douglas 351 and 69 → `InvalidPrice`, price stays 146.
4. `act` `Pricing.SetAuto` true → `automatic` true; within 4 s the Douglas price equals `floor(140 × (1 − min(n/5, 1) × 0.15) + 0.5)` for the n Douglas trees on display; `SetMediumPrice` 150 → `automatic` false.
5. Client DataModel: require `PlayerScripts.Client.LotManagerTabs.PricingTab`, create it on a new ScreenGui `G7Probe` with a ScrollingFrame, a context whose `request` returns `{ ok = false, errorCode = "ConnectionError" }`; `render` the summary from `BusinessAction` (`Company.GetSummary`). Every `Price_<id>` card's `Price`, `Margin`, `Sizes`, `Sentiment` and `WholesaleTypical` text equals `PricingView.card(entry, en)` for that entry; all step buttons and `AutoPricing` are 44 px high or more. Destroy `G7Probe`.
6. BLOCKED until PC-3 (CM2-UV, new item): Pricing tab screenshots on phone, tablet and 1080p PC; taps on −5/−1/+1/+5 and the auto button; the card values after the tap equal the server summary; the page scrolls to the last card on the phone.

## Acceptance
- Checks: `stylua --check src tests tools`, `selene src tests tools`, `lune run tests/headless/run.luau` (308/308), `rojo build`.
- The typical price is wholesale × 5 from config; no code reads a hard-coded retail price; `typicalMedium` and `initialMediumPrice` no longer exist (grep).
- The Pricing tab shows wholesale, typical, margin $ and %, a sentiment sentence and S/M/L prices with profit, all from `summary.pricing`; the auto button switches the server flag; a manual price turns it off.
- Demand-model tests use the new benchmark (CustomerSelection, CustomerProfile, Demand tests above).
- Prices are member-authorized, rate-limited and saved (existing rules, plus the reload test).
- Playtest items 1–5 PASS; item 6 BLOCKED and routed to CM2-UV (the reviewer adds it to the CM2-UV line).

## Out of scope
- Lot appeal's +2 % price tolerance (CM2-G8), real customer preferences and walking NPCs (CM2-N1), special trees, a price per size.
- Changing the auto-pricing rule, the bounds multipliers or the rate limits; a migration of old saved prices.
- Forcing English or auto-scaled text (CM2-43); two-column cards on wide screens.

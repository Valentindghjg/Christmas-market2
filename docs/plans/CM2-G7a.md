# CM2-G7a — Noble Fir typical price: OBSERVED 184 instead of the derived 185

Written by: `planner` (Opus 5.5, high). Implemented by: the agent for the tier below. Playtested by: `playtester` (Sonnet 5.5, medium). Reviewed and committed by: `reviewer` (Opus 5.5, medium). Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
The Noble Fir "typical" price is the observed $184, not the derived 185. Its bounds (92–460), sentiment, customer budgets, demand score, automatic pricing and the default price of new saves all follow, because they already read `GameConfig.typicalMediumFor`.

## Source of truth
- REFERENCE_GAME_LIVE_TEST §4.3 (OBSERVED cards): typical M is Douglas 140, Fraser 160, Noble 184, Blue Spruce 210 at wholesale M 28/32/37/42. 140, 160 and 210 are exactly 5 × wholesale. Noble 184 is 4.97 ×, the only card that differs from the rule.
- PRODUCT_SPEC owner decisions, **Fidelity**: all numbers of the reference game are adopted; unknown numbers are extrapolated and marked PROVISIONAL.
- DECISION_LOG 2026-11-22 "Price benchmark and Pricing tab, CM2-G7" (benchmark bullet "Noble is 185") and its reviewer note; `docs/plans/CM2-G7.md` (Decisions table).
- Backlog launch order 7a.

## Decision (settled)
| Topic | Decision |
|---|---|
| Override or exception | **OBSERVED per-species override.** A recorded exception would keep a number that differs from an observed reference number, and the Fidelity rule does not allow that. The 5 × rule stays as the formula for every species without an observed card. |
| Rule for other species | `wholesale.Medium × 5` stays OBSERVED for Douglas, Fraser and Blue Spruce, because they match exactly. For later species (HQ 2–4, CM2-G9) it is the extrapolation and is PROVISIONAL until their cards are observed. Each observed card that differs goes into the override table. |
| Noble values | typical M 184; S/M/L benchmark 147/184/239 (`priceForSize`); bounds `ceil(184 × 0.5) = 92`, `floor(184 × 2.5) = 460`; automatic target `floor(184 × (1 − min(n/5, 1) × 0.15) + 0.5)` (184 with nothing on display). |
| Saves | No schema change: `SCHEMA_VERSION` stays 12 and `GameConfig.VERSION` stays 1. New saves start Noble at 184. Saved Noble prices are player settings and are kept, including a 185 written since CM2-G7. A saved 461 or 462 is left alone, as the CM2-G7 rule for out-of-bounds saved prices says. No migration. |
| Remote | `Pricing.SetMediumPrice` code, rate limits and error codes stay the same. Only the accepted Noble range changes, from 93–462 to 92–460. |

## Implementer tier
Tier: L. Reason: it changes the accepted range of the `Pricing.SetMediumPrice` remote (92–460) and the customer budgets that decide which sales credit cash. The template puts remote validation and money in L. The change itself is one config entry and one lookup.

## Skills to load
roblox-collaboration-mode, roblox-game-design, roblox-networking, roblox-security, roblox-luau-core, roblox-luau-types, roblox-tooling.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/GameConfig.lua` | Change | `Pricing.TypicalMediumOverride`, the lookup in `typicalMediumFor`, comments |
| `tests/studio/Cases/GameConfig_Test.lua` | Change | Noble 184, plus one new test |
| `tests/studio/Cases/Economy_Test.lua` | Change | Noble size benchmarks |
| `tests/studio/Cases/BusinessState_Test.lua` | Change | Backfilled Noble price |
| `tests/studio/Cases/PricingService_Test.lua` | Change | Auto, bounds and summary rows |
| `tests/studio/Playtest/RunPlaytest.lua` | Change | BUILD `cm2-g7a`, threshold 309 |
| `docs/GAME_DESIGN.md`, `docs/TEST_PLAN.md`, `docs/DECISION_LOG.md` | Change | Step 4 |

Do not change: `PricingService.lua`, `Economy.lua`, `BusinessState.lua`, `CustomerProfile.lua`, `CustomerSelection.lua`, the client, `Protocol.lua`, rate limits, `docs/plans/CM2-G7.md`, `docs/PROGRESS.md`, `docs/CLAUDE_BACKLOG.md` (the reviewer updates the last two).

## Data and config
In `GameConfig.Pricing`, the `BenchmarkMultiplier` line and one new key directly below it:
```lua
	BenchmarkMultiplier = 5, -- OBSERVED for Douglas, Fraser and Blue Spruce (exactly 5 x medium wholesale); PROVISIONAL extrapolation for species without an observed card
	-- OBSERVED typical medium prices that differ from the 5 x rule (REFERENCE_GAME_LIVE_TEST §4.3, CM2-G7a).
	TypicalMediumOverride = { NobleFir = 184 } :: { [string]: number },
```

## Steps
1. **GameConfig.Pricing**: the two lines from "Data and config" replace the current `BenchmarkMultiplier` line. Keep `Steps`, `SentimentPercent` and `BudgetPercent` unchanged.
2. **`GameConfig.typicalMediumFor`** (signature unchanged, `(speciesId: unknown): number?`): after the existing `tree` nil check, add
   `local override = GameConfig.Pricing.TypicalMediumOverride[speciesId]` and `if override ~= nil then return override end`. Then return `tree.wholesale.Medium * GameConfig.Pricing.BenchmarkMultiplier` as now. The override is read only for a known species, so an override key that is not a species is ignored.
3. **Comment** in `GameConfig.Trees`: replace `-- The typical retail price is derived: GameConfig.typicalMediumFor (CM2-G7).` with `-- The typical retail price: GameConfig.typicalMediumFor (5 x medium wholesale, or an OBSERVED override; CM2-G7, CM2-G7a).`
4. **Docs**:
   - GAME_DESIGN line 28: replace `medium = 5 × medium wholesale (GameConfig.Pricing.BenchmarkMultiplier, OBSERVED): Douglas 140, Fraser 160, Noble 185, Blue Spruce 210;` with `medium = 5 × medium wholesale (GameConfig.Pricing.BenchmarkMultiplier), unless an observed card differs (GameConfig.Pricing.TypicalMediumOverride): Douglas 140, Fraser 160, Noble 184 (observed override; 5 × 37 would be 185), Blue Spruce 210, all OBSERVED; the 5 × rule is the PROVISIONAL extrapolation for species without an observed card;`. Keep the rest of the line.
   - TEST_PLAN §2 row PRC-01: `typical = 5 × medium wholesale; manual prices …` → `typical = 5 × medium wholesale or the OBSERVED override (Noble 184); manual prices …`. Line 63 `(at least 308 tests)` → `(at least 309 tests)`.
   - DECISION_LOG, new entry at the end: `## 2026-11-22 - Noble Fir typical price 184 (OBSERVED override), CM2-G7a (engineering)`, with these bullets: it supersedes the CM2-G7 benchmark bullet "Noble is 185, not the observed 184"; why the override and not an exception (Fidelity rule; 140/160/210 match 5 × exactly); `GameConfig.Pricing.TypicalMediumOverride = { NobleFir = 184 }`; the 5 × rule is the PROVISIONAL extrapolation for unobserved species; Noble bounds 92–460, size benchmarks 147/184/239, auto base 184; saves and remote as in the Decision table; no schema change; threshold 308 → 309 (`BUILD cm2-g7a`). Plan: `docs/plans/CM2-G7a.md`.
5. **RunPlaytest**: `RunPlaytest.BUILD = "cm2-g7a"`; the step-01 check and its message use `309`.

## Tests (headless)
| Test case file | Test name | Asserts |
|---|---|---|
| GameConfig_Test | derives the typical price from wholesale x 5 (changed) | Noble line becomes `typicalMediumFor("NobleFir") == 184`; all other asserts unchanged |
| GameConfig_Test | takes observed typical prices over the 5x rule (new) | `Pricing.TypicalMediumOverride.NobleFir == 184`; the table has exactly 1 key; every key is a key of `GameConfig.Trees` and its value a positive integer; for `SpeciesOrder` in order, `typicalMediumFor` returns 140, 160, 184, 210; `GameConfig.Trees.NobleFir.wholesale.Medium * Pricing.BenchmarkMultiplier == 185` (the override really differs from the rule) |
| Economy_Test | derives size benchmarks from the medium benchmark (changed) | `typicalPrice("NobleFir", "Large") == 239` (was 241); add `typicalPrice("NobleFir", "Small") == 147` |
| BusinessState_Test | restores missing medium prices during migration (changed) | `migrated.mediumPrices.NobleFir == 184` |
| PricingService_Test | auto pricing discounts only with displayed stock (changed) | `state.mediumPrices.NobleFir == 184` |
| PricingService_Test | bounds follow the benchmark (changed) | `expectBounds("NobleFir", 92, 460)`; add on a new state: Noble 91 and 461 → `false, "InvalidPrice"`; 92 and 460 accepted and stored |
| PricingService_Test | summary reports server prices, margins and sentiment (changed) | Noble row `{ "NobleFir", 192, 184, 155, 81, 154, 126, 250, 196 }` (only the typical changes; 192 is still Fair) |

Not affected (checked): CustomerProfile_Test pins only profiles 1, 8 and 12 (Fraser and Douglas), and its range loop uses `Economy.typicalPrice`. The CustomerSelection, CustomerOrderService and CompanyStateService tests with Noble Small stock sell at the default price, which stays below every budget (budget ≥ 85 % of the Small benchmark, default Small price = 80 % of it). PricingView and CompanyStateService summary tests use Douglas only.

Expected: `lune run tests/headless/run.luau` → 309 run, 309 passed (308 + 1 new).

## Playtest (Studio, via playtester)
A server read-back is enough; `runPlaytest` is not required for this task.
1. Play (Server + Client). In the Server data model, `require(game.ServerStorage.UnitTest.Playtest.RunPlaytest).BUILD == "cm2-g7a"`, so the place runs the new build.
2. On save "Playtest A", hook `act` `Company.GetSummary` for the player and record Noble `mediumPrice` and `automatic` as the snapshot. Expect the `NobleFir` entry in `data.pricing.species` (third): `typicalMedium` 184, `wholesaleMedium` 37, `minPrice` 92, `maxPrice` 460.
3. `act` `Pricing.SetMediumPrice` Noble 91 and 461 → `InvalidPrice`; 92 → ok; 192 → ok, and the summary entry shows `marginMedium` 155, `marginPercent` 81, `sentiment` Fair, sizes Small 154 (profit 126), Medium 192 (155), Large 250 (196).
4. Restore: `SetMediumPrice` Noble to the snapshot price. If the snapshot price is outside 92–460, set 184 instead and record that. If the snapshot `automatic` was true, `SetAuto true`. A final summary shows the restored values.

## Acceptance
- Checks: `stylua --check src tests tools`, `selene src tests tools`, `lune run tests/headless/run.luau` (309/309), `rojo build`.
- `GameConfig.typicalMediumFor("NobleFir") == 184` and Noble bounds are 92–460. No other code holds a Noble retail number (`grep -rn "185\|462" src` finds no pricing value).
- The decision (override, not exception) is in DECISION_LOG. No schema change.
- Playtest steps 1–4 PASS.

## Out of scope
- Observed cards for the HQ 2–4 species (CM2-G9 adds them as overrides when seen).
- Changing the 0.5/2.5 bounds multipliers, the auto rule, sentiment thresholds, budgets or rate limits.
- Rewriting saved Noble prices, and Pricing tab screenshots (CM2-UV (h)).

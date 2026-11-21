# CM2-G6 — Observed wholesale table and Douglas Fir starter species

Written by: `planner` (Opus 5.5, high). Implemented by: the agent for the tier below. Playtested by: `playtester` (Sonnet 5.5, medium). Reviewed and committed by: `reviewer` (Opus 5.5, medium). Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
The supplier sells the reference's four starter species (Douglas Fir, Fraser Fir, Noble Fir and Blue Spruce) at the observed wholesale price for each size. The Supplier panel lists all four species with their Small, Medium and Large prices, and the player can pick a species to order, place and sell back. Existing saves keep their stock, prices and placed trees.

## Source of truth
- PRODUCT_SPEC, owner decisions 2026-11-21: the "Fidelity" rule (all reference numbers are adopted), the "Tree species" rule (real species in the reference's unlock order, spelling fix "Fraser Fir") and the "Language" rule (English launch, key-based text).
- `docs/REFERENCE_GAME_LIVE_TEST.md` §4.1, the supplier table (OBSERVED):

  | Species (rarity) | Small | Medium | Large |
  |---|---|---|---|
  | Douglas Fir (Common) | 21 | 28 | 41 |
  | Fraser Fir (Uncommon) | 24 | 32 | 46 |
  | Noble Fir (Rare) | 28 | 37 | 54 |
  | Blue Spruce (Uncommon) | 32 | 42 | 61 |

  Observed sell-back refunds that confirm the table at 25 %, rounded half up: small Douglas $5, large Noble $14, and a toast "Sold 1 tree back … for $10" (only Douglas Large gives $10). Observed recommended-order shape: "3× Douglas Fir (1 S, 2 M), 3× Fraser Fir (1 S, 2 M), + 3 more".
- `docs/CLAUDE_BACKLOG.md`, the original CM2-G6 line (P2) and launch order line 1 (section "Launch replanning (2026-11-21)").
- `docs/GAME_DESIGN.md` §4, the evidence note "Wholesale prices by size are **not observed**". This plan replaces that sentence.

## Implementer tier
Tier: S. Reason: the work is config values, a fixed species order, a UI selection list, strings, docs and tests. There is no save schema change, no migration code, no new or changed remote validation and no change to how money or inventory move.

Decisions behind this tier (settled, do not revisit):
- **No save schema change. `BusinessState.SCHEMA_VERSION` stays 10 and `GameConfig.VERSION` stays 1.** Every persisted field is keyed by species ID: `stock` keys `"<speciesId>:<sizeId>"`, `mediumPrices[speciesId]`, `layout.placements[*].speciesId`, `pendingOrders[*].speciesId`, `customerOrders[*].speciesId`, `supplier.stock` and `supplier.demand` keys. No existing ID changes.
- A schema-10 save from before this change has no `DouglasFir` entries:
  - `mediumPrices.DouglasFir` is filled in on load by the existing `backfillMediumPrices`, which already runs in `BusinessState.migrate` for every schema ≥ 2. No code change is needed.
  - `supplier.stock["DouglasFir:*"]` is missing, so it counts as 0. A Douglas order returns `SupplierOutOfStock` and charges nothing until the next supplier refresh. That refresh comes within `GameConfig.Supplier.RefreshSeconds` (240 s), from `refreshSupplierStockAll` or from the `refreshIfDue` call inside `Supplier.PlaceOrder`. It rolls stock for all four species.
  - **Accepted:** this gap of at most 240 s is acceptable, because only unpublished Studio test saves exist. `BusinessState.migrate` and `normalizeSchema10` are **not** changed.
- **Species ID for Douglas Fir: `DouglasFir`.**
- **The Fraser spelling changes only in the display name.** The ID stays `FrasierFir` (a stable save key). `GameConfig.Trees.FrasierFir.displayName` becomes `"Fraser Fir"`. No `FraserFir` key is added, and no alias or rename migration is written.
- **Supplier cost:** the observed per-size table replaces the old values, where only Medium was observed and Small and Large were PROVISIONAL (Frasier 26/42, Noble 30/48, Blue 34/55). The supplier cost is the table value. It is **not** derived from the 80 %/130 % rule.
- **Retail rule unchanged:** `GameConfig.SizeMultipliers` (Small 0.8, Medium 1.0, Large 1.3) and `Economy.priceForSize` stay as they are. That rule is OBSERVED for retail prices (REFERENCE §4.3) and keeps applying to sale prices only.

## Skills to load
roblox-collaboration-mode (first), roblox-game-design (economy values), roblox-data (confirms that no schema change is needed), roblox-networking and roblox-security (the read-only summary field; clients never send prices), roblox-gui, roblox-input, roblox-localization (Supplier panel), roblox-luau-core, roblox-luau-patterns, roblox-luau-types (Luau code). CLAUDE.md wins on any conflict. Conflict 10 applies: strings live in `src/shared/Localization.lua` and must have both `en` and `de` entries, because `Localization_Test` enforces both.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/GameConfig.lua` | Change | `SpeciesOrder`, a `DouglasFir` entry, the observed wholesale table, `rarity`, and the Fraser display name |
| `src/shared/BusinessState.lua` | Change | `BusinessState.new` builds `mediumPrices` from `GameConfig.Trees`, so the new species is included |
| `src/shared/SupplierCatalog.lua` | Change | `list()` in a fixed order (`SpeciesOrder` × `SizeIds`) |
| `src/shared/CustomerProfile.lua` | Change | Append `DouglasFir` to the customer preference cycle |
| `src/server/Services/SupplierStockService.lua` | Change | Species order from `SpeciesOrder`; `summary()` gains `wholesale` |
| `src/server/Services/WorldService.lua` | Change | The graybox asset gallery loops over `SpeciesOrder` |
| `src/client/UiController.client.lua` | Change | Supplier panel: 4 species rows with server prices and a selected species for order/place/sell-back |
| `src/shared/Localization.lua` | Change | 2 new keys in `en` and `de` |
| `tests/studio/Cases/GameConfig_Test.lua` | Change | +5 tests |
| `tests/studio/Cases/SupplierCatalog_Test.lua` | Change | +1 test |
| `tests/studio/Cases/SupplierStockService_Test.lua` | Change | 1 test updated, +4 tests |
| `tests/studio/Cases/BusinessState_Test.lua` | Change | +1 test |
| `tests/studio/Cases/CustomerProfile_Test.lua` | Change | +1 test |
| `tests/studio/Cases/Localization_Test.lua` | Change | +1 test |
| `tests/studio/Cases/Protocol_Test.lua` | Change | +1 test |
| `docs/GAME_DESIGN.md` | Change | Evidence note on wholesale and the species list |
| `docs/DECISION_LOG.md` | Change | New dated entry |
| `docs/TEST_PLAN.md` | Change | StudioTestHook profile numbers for the new customer cycle |
| `docs/MODEL_INTEGRATION.md` | Change | Requested tree models include DouglasFir |

Do not change: `Economy.lua`, `Protocol.lua`, `CompanyStateService.lua`, `PricingService.lua`, `CustomerSelection.lua`, `WorldLabels.client.lua`, `main.server.lua`, `docs/IMPLEMENTATION_PLAN.md`, the `$82/$96/$105` medium price notes (CM2-G7), `docs/PROGRESS.md` and `docs/CLAUDE_BACKLOG.md` (the reviewer updates both).

## Data and config
In `src/shared/GameConfig.lua`, replace the whole `GameConfig.Trees = { … }` block (currently the three entries and the comment above them) with exactly this, placed directly after `local validSizes = …`:

```lua
-- OBSERVED supplier row order, which is also the unlock order of the starter species
-- (docs/REFERENCE_GAME_LIVE_TEST.md §4.1). Every key of GameConfig.Trees appears here once.
GameConfig.SpeciesOrder = { "DouglasFir", "FrasierFir", "NobleFir", "BlueSpruce" }

GameConfig.Trees = {
	-- Wholesale per species and size and the rarity are OBSERVED (docs/REFERENCE_GAME_LIVE_TEST.md §4.1).
	-- typicalMedium and initialMediumPrice are PROVISIONAL until CM2-G7 (benchmark = wholesale x 5).
	-- Species IDs are stable save keys: "FrasierFir" keeps its ID; only the display name is "Fraser Fir".
	DouglasFir = {
		displayName = "Douglas Fir",
		rarity = "Common",
		evidence = GameConfig.Evidence.Observed,
		wholesale = { Small = 21, Medium = 28, Large = 41 },
		typicalMedium = 70,
		initialMediumPrice = 72,
	},
	FrasierFir = {
		displayName = "Fraser Fir",
		rarity = "Uncommon",
		evidence = GameConfig.Evidence.Observed,
		wholesale = { Small = 24, Medium = 32, Large = 46 },
		typicalMedium = 80,
		initialMediumPrice = 82,
	},
	NobleFir = {
		displayName = "Noble Fir",
		rarity = "Rare",
		evidence = GameConfig.Evidence.Observed,
		wholesale = { Small = 28, Medium = 37, Large = 54 },
		typicalMedium = 92,
		initialMediumPrice = 96,
	},
	BlueSpruce = {
		displayName = "Blue Spruce",
		rarity = "Uncommon",
		evidence = GameConfig.Evidence.Observed,
		wholesale = { Small = 32, Medium = 42, Large = 61 },
		typicalMedium = 105,
		initialMediumPrice = 105,
	},
}
```

The values for Douglas follow the convention the other three species already use, so CM2-G7 can rebase all four together:
- `typicalMedium = 70` is 2.5 × the Medium wholesale of 28.
- `initialMediumPrice = 72` is 70 × 82/80, rounded.

Both values are PROVISIONAL. Price bounds from `PricingService.bounds`: 35..175.

No other config key changes. `GameConfig.VERSION` stays 1.

**Saved data:** no new field, no migration, no version bump (see the decisions under "Implementer tier").

## Steps
1. **`src/shared/GameConfig.lua`:** apply the block from "Data and config". Leave `wholesaleFor`, `isValidSize` and `SizeMultipliers` unchanged.

2. **`src/shared/BusinessState.lua`:** in `BusinessState.new`, replace the literal `mediumPrices = { FrasierFir = …, NobleFir = …, BlueSpruce = … }` with `mediumPrices = defaultMediumPrices(),`. Add this local function above `BusinessState.new`:
   ```lua
   -- Every configured species starts at its catalog default (validate() requires one price per species).
   local function defaultMediumPrices(): { [string]: number }
   	local prices = {}
   	for speciesId, tree in pairs(GameConfig.Trees) do
   		prices[speciesId] = tree.initialMediumPrice
   	end
   	return prices
   end
   ```
   Change nothing else in this file. In particular, `migrate`, `normalizeSchema10`, `backfillMediumPrices`, `validate` and `SCHEMA_VERSION` stay as they are.

3. **`src/shared/SupplierCatalog.lua`:** in `list()`, replace `for speciesId in pairs(GameConfig.Trees) do` with `for _, speciesId in ipairs(GameConfig.SpeciesOrder) do`. The quote order is now deterministic: DouglasFir Small, Medium, Large, then FrasierFir, NobleFir and BlueSpruce.

4. **`src/shared/CustomerProfile.lua`:** replace line 5 with:
   ```lua
   -- Douglas Fir is appended so existing profile numbers keep their species (tests and
   -- StudioTestHook); CM2-N1 replaces this cycle with real customer preferences.
   local species = { "FrasierFir", "NobleFir", "BlueSpruce", "DouglasFir" }
   ```
   `create` keeps its formula. With 4 species the cycle becomes:
   - Profiles 1–4 want Small Fraser, Noble, Blue and Douglas.
   - Profiles 5–8 want Medium, in the same species order.
   - Profiles 9–12 want Large, in the same species order.
   - The pattern then repeats with a period of 12.

5. **`src/server/Services/SupplierStockService.lua`:**
   - Replace the body of `sortedSpecies()` with `return table.clone(GameConfig.SpeciesOrder)`. Keep the function name, and update its comment to "-- Supplier rows in the OBSERVED order (GameConfig.SpeciesOrder)." The comment on `recommend` stays.
   - Add this private function above `SupplierStockService.summary`:
     ```lua
     -- Server wholesale per SKU so the client shows exactly the prices the server charges.
     local function wholesaleTable(): { [string]: number }
     	local prices = {}
     	for _, speciesId in ipairs(GameConfig.SpeciesOrder) do
     		for _, sizeId in ipairs(GameConfig.SizeIds) do
     			local unitCost = GameConfig.wholesaleFor(speciesId, sizeId)
     			if unitCost then
     				prices[Inventory.key(speciesId, sizeId)] = unitCost
     			end
     		end
     	end
     	return prices
     end
     ```
   - In `summary()`, add the field `wholesale = wholesaleTable(),` after `sellBackFraction`.
   - Change no other logic. `refundFor`, `sellBack` and `refreshIfDue` stay as they are; only their species order changes.

6. **`src/server/Services/WorldService.lua`:** line 313, replace `ipairs({ "FrasierFir", "NobleFir", "BlueSpruce" })` with `ipairs(GameConfig.SpeciesOrder)`. The position formula stays as it is. `GameConfig` is already required in this file.

7. **`src/shared/Localization.lua`:** add these keys. Put them in `en` after `soldBack`, and in `de` after `soldBack`.
   - `en`:
     - `supplierPriceLegend = "Wholesale per tree: Small / Medium / Large",`
     - `supplierSpeciesRow = "%s\n$%d / $%d / $%d",`
   - `de`:
     - `supplierPriceLegend = "Einkauf pro Baum: Klein / Mittel / Groß",`
     - `supplierSpeciesRow = "%s\n%d $ / %d $ / %d $",`

8. **`src/client/UiController.client.lua`:** Supplier panel with a species selection. The client sends only species, size and quantity, exactly as today. Prices shown come from the server summary.
   1. Replace lines 12–14 (`-- Display only…` and `FRASIER_MEDIUM_REFUND`) with:
      ```lua
      -- Supplier rows follow the OBSERVED order; prices shown come from the server summary.
      local SPECIES_ORDER = GameConfig.SpeciesOrder
      local function speciesName(speciesId: string): string
      	local tree = GameConfig.Trees[speciesId]
      	return if tree then tree.displayName else speciesId
      end
      ```
   2. Panel:
      - Set `panel.Size` to `UDim2.fromOffset(360, 388)`.
      - Keep the title label at (18, 14).
      - Add the legend `label(panel, localized("supplierPriceLegend"), UDim2.fromOffset(18, 44), UDim2.fromOffset(324, 16), 12)`.
   3. Directly after the legend, add the species buttons:
      ```lua
      local selectedSpecies = SPECIES_ORDER[1]
      local speciesButtons: { [string]: TextButton } = {}
      local speciesStrokes: { [string]: UIStroke } = {}
      for index, speciesId in ipairs(SPECIES_ORDER) do
      	local column = (index - 1) % 2
      	local row = (index - 1) // 2
      	local choice = button(
      		"Species_" .. speciesId,
      		Color3.fromRGB(237, 212, 142),
      		UDim2.fromOffset(18 + column * 164, 62 + row * 48),
      		UDim2.fromOffset(160, 44),
      		13
      	)
      	choice.Text = speciesName(speciesId)
      	choice.TextWrapped = true
      	choice.Parent = panel
      	Instance.new("UICorner", choice).CornerRadius = UDim.new(0, 8)
      	-- The outline marks the selection, so it is not shown by colour alone.
      	local stroke = Instance.new("UIStroke")
      	stroke.Name = "Selected"
      	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
      	stroke.Thickness = 3
      	stroke.Color = Color3.fromRGB(255, 244, 217)
      	stroke.Parent = choice
      	speciesButtons[speciesId] = choice
      	speciesStrokes[speciesId] = stroke
      end
      local function updateSelection()
      	for speciesId, choice in pairs(speciesButtons) do
      		local selected = speciesId == selectedSpecies
      		choice.BackgroundColor3 = if selected then Color3.fromRGB(201, 153, 53) else Color3.fromRGB(237, 212, 142)
      		speciesStrokes[speciesId].Enabled = selected
      	end
      end
      updateSelection()
      ```
   4. Move the existing controls down by 108 px and rename three buttons:

      | Control | Position (x, y) | Size | Name |
      |---|---|---|---|
      | `detail` | (18, 158) | 324 × 24 | unchanged; initial text `localized("loading")` |
      | `order` | (18, 202) | 324 × 45 | `"OrderTrees"` |
      | `unload` | (18, 251) | 324 × 20 | unchanged |
      | `place` | (18, 276) | 324 × 20 | `"PlaceTree"` |
      | `supplierLine` | (18, 300) | 324 × 18 | unchanged |
      | `receivingLine` | (18, 318) | 324 × 18 | unchanged |
      | `customerLine` | (18, 336) | 324 × 18 | unchanged |
      | `sellBack` | (18, 358) | 324 × 22 | `"SellBackTree"` |

      Colours, text sizes and visibility defaults stay as they are.
   5. State variables:
      - Rename `storedFrasierMedium` to `storedSelectedMedium`.
      - Add `local lastSummary: any = nil`.
   6. Delete `refreshSupplierQuote` and both of its call sites: the `CompanyReady` connection at line 175 and `task.spawn(refreshSupplierQuote)` at line 176. The client no longer sends `Supplier.RequestQuote`; the server action stays as it is.
   7. Add these helpers, defined before `refreshSummary`:
      ```lua
      local function mediumKey(): string
      	return selectedSpecies .. ":Medium"
      end

      local function serverWholesale(key: string): number?
      	local supplier = lastSummary and lastSummary.supplier
      	local prices = supplier and supplier.wholesale
      	local value = prices and prices[key]
      	return if type(value) == "number" then value else nil
      end

      local function showSelectedQuote()
      	local unitCost = serverWholesale(mediumKey())
      	detail.Text = if unitCost
      		then localizedFormat("wholesaleQuote", speciesName(selectedSpecies), localized("sizeMedium"), unitCost)
      		else localized("loading")
      end
      ```
   8. Split `refreshSummary` into `renderSummary(data: any)` and the fetch:
      - **`renderSummary`** keeps the current body from `cash.Text = …` to the end, with these changes:
        - `storedSelectedMedium = data.stock and (data.stock[mediumKey()] or 0) or 0`
        - `place.Text = localizedFormat("placeTree", speciesName(selectedSpecies), storedSelectedMedium)`
        - `supplierLine` uses `supplier.stock[mediumKey()] or 0`.
        - New: if `supplier and supplier.wholesale` exists, set every species button's text:
          ```lua
          for speciesId, choice in pairs(speciesButtons) do
          	choice.Text = localizedFormat("supplierSpeciesRow", speciesName(speciesId), prices[speciesId .. ":Small"] or 0, prices[speciesId .. ":Medium"] or 0, prices[speciesId .. ":Large"] or 0)
          end
          ```
          Here `prices` is `supplier.wholesale`.
        - Sell-back:
          ```lua
          local refund = math.floor((serverWholesale(mediumKey()) or 0) * ((supplier and supplier.sellBackFraction) or 0) + 0.5)
          sellBack.Visible = storedSelectedMedium + placementCount > 0
          sellBack.Text = localizedFormat("sellBack", refund)
          ```
      - **`refreshSummary`** does the following, in order:
        1. Return early unless `CompanyReady` is true.
        2. Invoke `Company.GetSummary`, and return on failure.
        3. `local first = lastSummary == nil`
        4. `lastSummary = response.data`
        5. `renderSummary(response.data)`
        6. `if first then showSelectedQuote() end`

        After its definition, add `player:GetAttributeChangedSignal("CompanyReady"):Connect(refreshSummary)`.
   9. Selection handler, defined after `refreshSummary`:
      ```lua
      for speciesId, choice in pairs(speciesButtons) do
      	choice.Activated:Connect(function()
      		selectedSpecies = speciesId
      		updateSelection()
      		showSelectedQuote()
      		if lastSummary then
      			renderSummary(lastSummary)
      		end
      	end)
      end
      ```
      Selecting a species sends no request. Each tap is local; only the 5 s summary poll and the action buttons reach the server, so the per-player 10-requests-per-10-s limit is not stressed.
   10. Action handlers. Replace the hard-coded `"FrasierFir"` with `selectedSpecies` in the `Supplier.SellBack`, `Inventory.Place` and `Supplier.PlaceOrder` payloads, read once at tap time (`local speciesId = selectedSpecies` before the invoke). In `place.Activated`, the guard becomes `storedSelectedMedium < 1`. The size stays `"Medium"`, the quantity stays 1, the placement slots stay as they are, and the busy flags stay as they are.
   11. No string `"Frasier"` may remain in the file. The check is `rg -n "Frasier" src/client` with no output.

9. **`docs/GAME_DESIGN.md` §4:** replace the two lines starting with "Tree IDs:" and "Medium price examples:" with exactly:
   ```
   Tree IDs: DouglasFir, FrasierFir, NobleFir, BlueSpruce, in the OBSERVED supplier and unlock order (REFERENCE_GAME_LIVE_TEST §4.1, `GameConfig.SpeciesOrder`). IDs are stable save keys; the display name of `FrasierFir` is "Fraser Fir" (owner spelling fix 2026-11-21). The species list grows with the HQ-tier species (CM2-G9).
   Medium price examples: Frasier 82, Noble 96, Blue Spruce 105; small = round(0.8 * medium), large = round(1.3 * medium).
   Wholesale per tree is **OBSERVED per species and size** (REFERENCE_GAME_LIVE_TEST §4.1), Small/Medium/Large: Douglas Fir 21/28/41, Fraser Fir 24/32/46, Noble Fir 28/37/54, Blue Spruce 32/42/61. The 80 %/130 % size rule applies to retail prices only; supplier costs come from this table.
   ```
   Then, in §2 "OBSERVED in screenshots", insert `wholesale per species and size (REFERENCE_GAME_LIVE_TEST §4.1); ` directly before `cashier hire $1,200`. Leave the "$82/$96/$105" wording otherwise untouched (CM2-G7).

10. **`docs/DECISION_LOG.md`:** insert this entry directly above `## Change procedure`:
    ```
    ## 2026-11-22 - Starter species and observed wholesale table, CM2-G6 (engineering)
    - Previous rule: three species (FrasierFir, NobleFir, BlueSpruce); only Medium wholesale observed, Small and Large wholesale PROVISIONAL (26/42, 30/48, 34/55). New rule: four starter species in the OBSERVED supplier order Douglas Fir (Common), Fraser Fir (Uncommon), Noble Fir (Rare), Blue Spruce (Uncommon), with all 12 wholesale values OBSERVED (REFERENCE_GAME_LIVE_TEST §4.1). The 80 %/130 % rule stays for retail prices only.
    - New species ID `DouglasFir`. The ID `FrasierFir` stays as a stable save key; only its display name changes to "Fraser Fir" (owner spelling fix). No schema bump: saved data is keyed by species ID. Existing saves gain the Douglas medium price on load (existing backfill) and Douglas supplier stock at the next supplier refresh (at most 240 s).
    - Douglas Fir typical medium 70 and starting medium price 72 are PROVISIONAL, on the same 2.5 x wholesale convention as the other species, until CM2-G7 sets the benchmark to wholesale x 5.
    - Customer preferences cycle through four species; Douglas Fir is appended, so profiles 1-3 are unchanged (CM2-N1 replaces the cycle).
    - The Supplier panel lists the four species with server prices and acts on the selected species (Medium); the company summary gains a read-only `supplier.wholesale` map.
    - Affected files: GameConfig, BusinessState, SupplierCatalog, CustomerProfile, SupplierStockService, WorldService, UiController, Localization, tests, GAME_DESIGN, TEST_PLAN, MODEL_INTEGRATION.
    ```

11. **`docs/TEST_PLAN.md` §3b:** replace `(profiles 4, 13, 22, … want a Medium Frasier Fir)` with `(profiles 5, 17, 29, … want a Medium Fraser Fir; profiles 8, 20, 32, … a Medium Douglas Fir)`.

12. **`docs/MODEL_INTEGRATION.md`**, section "Initial requested models": replace `FrasierFir, NobleFir, BlueSpruce (each Small/Medium/Large)` with `DouglasFir, FrasierFir (display name "Fraser Fir"), NobleFir, BlueSpruce (each Small/Medium/Large)`.

13. Run `stylua src tests`, then the checks under "Acceptance".

## Tests (headless)
All cases live under `tests/studio/Cases/` and run in `lune run tests/headless/run.luau`. They use the existing `t.test` / `t.expect` style. A local `constant(value)` helper already exists in `SupplierStockService_Test`.

| Test case file | Test name | Asserts |
|---|---|---|
| GameConfig_Test | lists the four starter species in the observed supplier order | `#GameConfig.SpeciesOrder == 4`, and entries 1..4 are `DouglasFir`, `FrasierFir`, `NobleFir`, `BlueSpruce`. Every entry exists in `GameConfig.Trees`, and the number of keys in `GameConfig.Trees` equals 4. |
| GameConfig_Test | holds the observed wholesale for every species and size | `GameConfig.wholesaleFor(species, size)` returns all 12 values from the table under "Source of truth". Check them through a local expected table, looping over `SpeciesOrder` × `SizeIds`. |
| GameConfig_Test | keeps the FrasierFir ID and shows the Fraser Fir spelling | `Trees.FrasierFir.displayName == "Fraser Fir"`, `Trees.DouglasFir.displayName == "Douglas Fir"`, `Trees.FraserFir == nil` |
| GameConfig_Test | marks rarity and evidence of the starter species | rarity: DouglasFir `"Common"`, FrasierFir `"Uncommon"`, NobleFir `"Rare"`, BlueSpruce `"Uncommon"`. All four have `evidence == GameConfig.Evidence.Observed`. |
| GameConfig_Test | gives every species complete integer pricing data | For each tree: wholesale Small < Medium < Large, all of them positive integers; `typicalMedium` and `initialMediumPrice` are positive integers; `displayName` is a non-empty string. |
| SupplierCatalog_Test | lists one quote per species and size in supplier order | `#SupplierCatalog.list() == 12`; `list[1]` is DouglasFir/Small/21; `list[12]` is BlueSpruce/Large/61. Every quote's `unitCost == GameConfig.wholesaleFor(quote.speciesId, quote.sizeId)`. The test requires GameConfig itself. |
| SupplierStockService_Test | refunds a quarter of wholesale rounded half up (**updated**) | The comment becomes `-- Fraser large wholesale 46 -> 11.5 -> 12; medium 32 -> 8.` `refundFor("FrasierFir","Large") == 12` (was 11) and `refundFor("FrasierFir","Medium") == 8`. |
| SupplierStockService_Test | matches the observed sell-back refunds | `refundFor("DouglasFir","Small") == 5`, `refundFor("NobleFir","Large") == 14`, `refundFor("DouglasFir","Large") == 10` |
| SupplierStockService_Test | recommends Douglas Fir and Fraser Fir first in supplier order | On a new state with `cash = 100000`, `recommend(state)` returns 6 lines, `quantity == 9` and `cost == 267`. Lines 1 and 2 are DouglasFir Small×1 and Medium×2, lines 3 and 4 are FrasierFir, and lines 5 and 6 are NobleFir. |
| SupplierStockService_Test | the summary exposes the server wholesale table | `Supplier.summary(state, 0).wholesale` has 12 entries, with `["DouglasFir:Medium"] == 28`, `["FrasierFir:Large"] == 46` and `["BlueSpruce:Large"] == 61`. |
| SupplierStockService_Test | an existing save gains Douglas Fir supplier stock at the next refresh | Start from a new state and set `cash = 1000`, `stock["FrasierFir:Medium"] = 3`, `mediumPrices.FrasierFir = 90`. Then simulate a save from before this change: `mediumPrices.DouglasFir = nil`, all three `supplier.stock["DouglasFir:*"] = nil`, `supplier.refreshAt = 1000`. Expected results:<ul><li>`BusinessState.migrate(state, "personal:42", 42)` returns the record with no error and `schemaVersion == BusinessState.SCHEMA_VERSION`.</li><li>The record keeps `stock["FrasierFir:Medium"] == 3` and `mediumPrices.FrasierFir == 90`.</li><li>`mediumPrices.DouglasFir == GameConfig.Trees.DouglasFir.initialMediumPrice`.</li><li>`placeOrder(…, "douglas_early", "DouglasFir", "Small", 1, 100)` fails with `"SupplierOutOfStock"` and cash stays 1000.</li><li>`refreshIfDue(migrated, 1000, constant(0.5))` returns true.</li><li>`placeOrder(…, "douglas_after", "DouglasFir", "Small", 1, 1000)` succeeds with `order.cost == 21`, and cash becomes 979.</li></ul> |
| BusinessState_Test | a new company prices and stocks Douglas Fir | `BusinessState.new("personal:42", 42)` gives `mediumPrices.DouglasFir == 72`, and `supplier.stock["DouglasFir:Small"/"Medium"/"Large"]` equal `GameConfig.Supplier.BaseStock.Small/Medium/Large`. `BusinessState.validate(state)` is true. |
| CustomerProfile_Test | cycles customer preferences through all four starter species | For profiles 1..4, `preferredSpeciesId` is FrasierFir, NobleFir, BlueSpruce, DouglasFir and `preferredSizeId` is `"Small"`. Profile 5 is FrasierFir/Medium; profile 8 is DouglasFir/Medium. |
| Localization_Test | formats the supplier species row | `Localization.format("en","supplierSpeciesRow","Douglas Fir",21,28,41) == "Douglas Fir\n$21 / $28 / $41"`; the `de` version gives `"Douglas Fir\n21 $ / 28 $ / 41 $"`. |
| Protocol_Test | accepts Douglas Fir orders and rejects the display spelling as an ID | A `Supplier.PlaceOrder` request with `version = 1`, `requestId = "order_douglas"` and payload `{speciesId="DouglasFir", sizeId="Small", quantity=1}` is valid. The same request with `requestId = "order_fraser"` and `speciesId = "FraserFir"` returns `false, "UnknownSpecies"`. |

Existing tests that must still pass without edits:
- `BusinessState_Test`:
  - "charges server configured wholesale price" (Frasier Medium 2 × 32 = 64)
  - "does not partially mutate unaffordable order" (Blue Large 2 × 61 = 122 > 84)
- `Delivery_Test` "reports receiving usage" (Frasier Small 2 × 24 = 48 ≤ 84)
- Sell-back tests (Medium refund 8)
- Every customer test that uses profiles 1 and 2

**Expected headless count: 133 run, 133 passed, 0 failed** (119 today + 14 new). If the count differs, the implementer stops and reports.

## Playtest (Studio, via playtester)
1. **Setup.**
   - `rojo build`/serve the branch into Studio and start Play (Server + Client).
   - In the Server data model, run `require(ServerStorage.UnitTest.RunUnitTest)(nil, 10)`. Expect 133/133 PASS.
   - Wait until the client attribute `CompanyReady == true`.
2. **Supplier rows.** Within 10 s, read these under `Players.<player>.PlayerGui.ChristmasMarketUI.SupplierPanel`:
   - `Species_DouglasFir.Text == "Douglas Fir\n$21 / $28 / $41"`
   - `Species_FrasierFir.Text == "Fraser Fir\n$24 / $32 / $46"`
   - `Species_NobleFir.Text == "Noble Fir\n$28 / $37 / $54"`
   - `Species_BlueSpruce.Text == "Blue Spruce\n$32 / $42 / $61"`

   Exactly 4 children have names starting with `Species_`. `Species_DouglasFir.Selected.Enabled == true` and the other three strokes are disabled. `detail.Text` reads `"Douglas Fir · Medium · $28 wholesale"`. The sell-back text, if visible, reads `"Sell 1 back for $7"`.
3. **Selection.** Activate `Species_FrasierFir` (click, or fire `Activated` through the MCP).
   - Expected: `detail` reads `"Fraser Fir · Medium · $32 wholesale"`, `Species_FrasierFir.Selected.Enabled == true` and `Species_DouglasFir.Selected.Enabled == false`.
   - Select `Species_DouglasFir` again.
4. **Douglas order.** Note `cash` from the HUD, then press `OrderTrees`.
   - **Expected:** HUD cash is lower by exactly 28, and the receiving line shows one more bay used.
   - **If the order is rejected with "Error: The supplier is out of this tree – wait for the refresh"** (a save from before this change): run `ServerStorage.StudioTestHook:Invoke("advanceClock", 240)` and press `OrderTrees` again, which must then succeed. Record this as the expected existing-save path.
   - **If cash is below 28:** record the rejection text `"Error: Not enough cash"` with cash unchanged. Mark the cost check BLOCKED and give the cash value.
5. **Fraser order.** Select Fraser Fir and press `OrderTrees`. Expected: cash is lower by exactly 32. Same fallbacks as step 4.
6. **Deliver and place.**
   - Run `Invoke("advanceClock", 60)` and wait for the next summary (≤ 5 s). Press the unload button, then `PlaceTree` with Fraser Fir selected.
   - Expected: a new `DisplayedTree_*` model on the plot. Its billboard label reads `"Fraser Fir · Medium · <h> ft · $<price>"`, where `<price>` is the save's Fraser medium price (82 on a fresh save).
   - No label in the workspace contains `"Frasier"`. Read every TextLabel with `LabelKind == "DisplayTree"`.
7. **Stop and start Play.** Expected: existing stored and placed Frasier stock is still there, and its labels show "Fraser Fir". The cash value matches the value from before the stop.
8. **Reporting.** Record every read-back value. The Play viewport captured black in earlier runs, so numeric and instance checks are the evidence; a screenshot is optional.

## Acceptance
- Checks: `stylua --check src tests` PASS, `selene src tests` PASS (0 errors, 0 warnings), `lune run tests/headless/run.luau` PASS with **133 run, 133 passed, 0 failed**, `rojo build default.project.json --output build.rbxlx` PASS.
- Tests assert all 12 observed wholesale values (config validated by tests, backlog acceptance).
- `docs/GAME_DESIGN.md` no longer says that wholesale by size is unobserved, and it lists the four IDs and the Fraser display name.
- In Studio, the Supplier panel lists exactly 4 species with the observed prices. Ordering charges the server price for the selected species.
- Existing saves keep their stock, prices and placements (headless migration test). The species ID `FrasierFir` is unchanged, and `rg -n "Frasier" src/client` prints nothing.
- No save schema change: `BusinessState.SCHEMA_VERSION == 10`, and `GameConfig.VERSION == 1`.
- Skill checks:
  - roblox-security: the client still sends no price or cost field, and `Protocol.lua` is unchanged.
  - roblox-gui: species selection is marked by an outline, not by colour only; every species button is 160 × 44 px.
  - roblox-luau-core: no behaviour depends on `pairs` order over `GameConfig.Trees` in the supplier list, the recommendation or the refresh.

## Out of scope
- CM2-G7:
  - the "typical" price = wholesale × 5
  - the Pricing tab
  - replacing the $82/$96/$105 notes
  - rebasing `typicalMedium` and `initialMediumPrice` for all species
  - customer budgets
- Size selection in the Supplier panel (orders stay Medium, quantity 1), quantity steppers, the one-click recommended order, and demand tags in the UI. These belong to CM2-40 (the Lot Manager shell) and later Supplier tab work.
- Phone-safe layout of the panel (CM2-40). This change keeps the existing fixed-offset dev panel.
- HQ-tier species (CM2-G9), special or event trees, and per-species 3D tree models (CM2-12, MODEL).
- Backfilling Douglas supplier stock inside `BusinessState.migrate` (deliberately not done; see the tier decisions).
- Moving species display names into `Localization.lua` (CM2-43).

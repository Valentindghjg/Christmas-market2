# CM2-G9b — Land tab and the Lot Manager's "Standby"

Written by: `planner` (Opus 5.5, high). Implemented by: the agent for the tier below. Playtested by: `playtester` (Sonnet 5.5, medium). Reviewed and committed by: `reviewer` (Opus 5.5, medium). Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.
Part 2 of launch order 16. **Depends on CM2-G9a** (`docs/plans/CM2-G9a.md`).

## Goal
The Land tab shows the lot, parking and HQ ladders with every requirement and its progress as the server checks it, buys the next step with a two-tap confirm, and shows the Elf Workshop's requirements with "Coming soon".

## Source of truth
REFERENCE_GAME_LIVE_TEST §4.5; PRODUCT_SPEC "UI look" (UiTheme/UiKit only) and "Language" (full sentences); tab contract in `src/client/LotManager.lua`; pattern `EmployeesTab.lua`.

## Implementer tier
Tier: S. Reason: client UI on the Employees tab pattern, strings, tests; no server, save or remote change.

## Skills to load
roblox-collaboration-mode, roblox-gui, roblox-input, roblox-localization, roblox-luau-core, roblox-luau-types.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/LandView.lua` | New | pure: rows/unlocks → `{key, args}` |
| `src/client/LotManagerTabs/LandTab.lua` | New | the tab (`LandTab` is in `UiTheme.LotManagerTabs`) |
| `src/client/LotManagerTabs/EmployeesTab.lua` | Change | `STATUS_KEYS.Standby = "staffStandby"` |
| `src/shared/Localization.lua` | Change | keys below, en and de |
| `tests/headless/run.luau` | Change | `LandView` in `sourcePaths` |
| `tests/studio/Cases/LandView_Test.lua` | New | 4 tests |
| `docs/GAME_DESIGN.md` §7 | Change | step 5 |

## Data and config
The tab reads only `summary.progression` (G9a) and `summary.cash`.

**LandView** (requires `UiTheme` for `formatMoney`; returns `type Line = { key: string, args: { any }, met: boolean? }`):
| Function | Result |
|---|---|
| `rowLine(row)` | key `"landRow" .. row.id` if `Localization.Strings.en` has it, else `landRowUnknown` {id}; args: `Cash` {money(have), money(need)}, `LotManager` {}, others {have, need}; `met = row.met == true` |
| `unlockLine(unlock)` | key `"landUnlock" .. id .. (if active then "" else "Soon")` if present, else `landRowUnknown` {id}; args {value} when `value` is a number, else {} |
| `levelNameKey(id?)` | nil → `landLevel_Starter`; else `"landLevel_" .. id` |
| `hqNameKey(id)` | `"hq_" .. id` |
| `statusLine(kind, section)` | `LotExpansion` → `landLotStatus` {{nameKey = levelNameKey(level 0 → nil, else `GameConfig.Progression.LotExpansion.levels[level].id`)}, level, maxLevel, storage}; `Parking` → `landParkingStatus` {tier, spaces}; `HQ` → `landHqStatus` {level, maxLevel, {nameKey = hqNameKey(id)}} |
| `nextLine(kind, offer?)` | nil → `landMaxed` {}; `LotExpansion` → `landNextLot` {target, {nameKey}, money(cashCost)}; `Parking` → `landNextParking` {target, spaces of the `ParkingSpaces` unlock, money(cashCost)}; `HQ` → `landNextHq` {{nameKey}, money(cashCost)} |
| `ERROR_KEYS` | `AlreadyOwned` → `landErrorOwned`, `NotNextLevel` → `landErrorOrder`, `PrerequisitesNotMet` → `landErrorRequirements`, `InsufficientReputation` → `landErrorReputation`, `InsufficientFunds` → `insufficientFunds`, `RateLimited` → `saveErrorRateLimited` |
The tab replaces each `{nameKey = k}` arg with `UiKit.localized(k)`, then calls `UiKit.localizedFormat(key, ...)`.

**Strings** (en / de; full sentences, `%s`/`%d` as shown):
| Key | en | de |
|---|---|---|
| `landLotTitle` | Lot expansion | Grundstückserweiterung |
| `landParkingTitle` | Parking | Parkplatz |
| `landHqTitle` | Headquarters | Hauptquartier |
| `landWorkshopTitle` | Elf Workshop | Elfenwerkstatt |
| `landLotStatus` | %s (%d/%d) · delivery storage %d | %s (%d/%d) · Lieferlager %d |
| `landParkingStatus` | Parking tier %d · %d spaces | Parkstufe %d · %d Plätze |
| `landHqStatus` | HQ %d of %d: %s | HQ %d von %d: %s |
| `landNextLot` | Next: Expansion %d · %s for %s | Nächste: Erweiterung %d · %s für %s |
| `landNextParking` | Next: tier %d with %d spaces for %s | Nächste: Stufe %d mit %d Plätzen für %s |
| `landNextHq` | Next: %s for %s | Nächstes: %s für %s |
| `landMaxed` | Fully upgraded. | Voll ausgebaut. |
| `landRowCash` | Cash: %s of %s | Geld: %s von %s |
| `landRowReputation` | Reputation: %d of %d | Ruf: %d von %d |
| `landRowLotExpansion` | Lot expansion: %d of %d | Grundstückserweiterung: %d von %d |
| `landRowParkingTier` | Parking tier: %d of %d | Parkstufe: %d von %d |
| `landRowHqLevel` | HQ level: %d of %d | HQ-Stufe: %d von %d |
| `landRowLotManager` | A hired Lot Manager | Ein eingestellter Lot Manager |
| `landRowUnknown` | Requirement %s | Voraussetzung %s |
| `landRowDone` | Done | Erfüllt |
| `landRowMissing` | Missing | Fehlt |
| `landUnlockNewSpeciesSoon` | %d new tree species (coming soon) | %d neue Baumarten (kommt bald) |
| `landUnlockCheckoutStationsSoon` | %d checkout stations (coming soon) | %d Kassen (kommt bald) |
| `landUnlockEmployeeCapacity` | Room for %d employees | Platz für %d Angestellte |
| `landUnlockCustomerPatience` | Customers wait %d%% longer | Kunden warten %d%% länger |
| `landUnlockLotManager` | You can hire the Lot Manager | Du kannst den Lot Manager einstellen |
| `landUnlockElfWorkshopSoon` | The Elf Workshop, together with a Lot Manager (coming soon) | Die Elfenwerkstatt, zusammen mit einem Lot Manager (kommt bald) |
| `landUnlockDisplaySpace` | %d more studs of display space behind the HQ | %d Studs mehr Verkaufsfläche hinter dem HQ |
| `landUnlockDeliveryStorage` | +%d delivery storage | +%d Lieferlager |
| `landUnlockParkingSpaces` | %d parking spaces | %d Parkplätze |
| `landBuy` | Buy | Kaufen |
| `landBuyConfirm` | Confirm %s | %s bestätigen |
| `landNotReady` | Requirements missing | Voraussetzungen fehlen |
| `landComingSoon` | Coming soon | Kommt bald |
| `landWorkshopLocked` | Needs the Mountain Chalet (HQ 4) and a hired Lot Manager. | Braucht das Bergchalet (HQ 4) und einen eingestellten Lot Manager. |
| `landWorkshopUnlocked` | Unlocked. The workshop opens in a later update. | Freigeschaltet. Die Werkstatt öffnet in einem späteren Update. |
| `landErrorOwned` | Already bought. | Schon gekauft. |
| `landErrorOrder` | Buy the earlier level first. | Kaufe zuerst die vorherige Stufe. |
| `landErrorRequirements` | The requirements are not met yet. | Die Voraussetzungen sind noch nicht erfüllt. |
| `landErrorReputation` | Not enough reputation. | Nicht genug Ruf. |
| `staffStandby` | Waiting for the lot computer (coming soon) | Wartet auf den Lot-Computer (kommt bald) |
| `landLevel_Starter`, `_BackLot`, `_SpruceCorner`, `_WoodlandEdge`, `_PineClearing`, `_SnowyMeadow`, `_ForestGlade` | Starter Lot, Back Lot, Spruce Corner, Woodland Edge, Pine Clearing, Snowy Meadow, Forest Glade | Start-Grundstück, Hinterhof, Fichtenecke, Waldrand, Kiefernlichtung, Schneewiese, Waldlichtung |
| `hq_SalesTent`, `_TimberPavilion`, `_AlpineHut`, `_MountainChalet` | Sales Tent, Timber Pavilion, Alpine Hut, Mountain Chalet | Verkaufszelt, Holzpavillon, Almhütte, Bergchalet |
`%d%%` renders "12%".

## Steps
1. `LandView.lua` as tabled (`--!strict`, no Roblox types).
2. `LandTab.create(page, context)`, layout as EmployeesTab (`place`, `placeWide`, `wrap`, inset 16):
   - `LandTitle` (existing key `land`, Title size, y 0); `LandStatus` (Small, y 32, errors via `fmt("errorStatus", text)`).
   - Four cards `Land_LotExpansion`, `Land_Parking`, `Land_HQ`, `Land_Workshop` (as the Employees cards), stacked from y 60, 8 px gaps: `Title` (Body, y 8), `Status` (Small, y 30), `Next` (Small, y 50), then one `Row_i` per requirement (y 72 + 20(i−1), height 18: text label left with inset 110, and `RowState_i` right-aligned 90 px wide showing `landRowDone` in `colors.Gold` or `landRowMissing` in `colors.Sand`), then one `Unlock_j` per unlock (18 px each), card height = 72 + 20·rows + 18·unlocks + 10. Button `Buy` (140 × 44) top right at y 8, like the Hire button.
   - Workshop card: `Title` `landWorkshopTitle`, `Status` = `landWorkshopUnlocked` or `landWorkshopLocked`, `Next` = `landComingSoon` in `colors.Sand`, rows from `workshop.rows`, no unlocks, **no button**.
   - Button states, in order: section maxed (no `next`) → hidden; `busy` → `loading`, disabled; `next.ready ~= true` → `landNotReady`, disabled (`colors.Disabled`); confirm window open → `fmt("landBuyConfirm", money(cashCost))`, enabled; else `landBuy`, enabled. First tap opens a 4 s confirm window (as Employees `CONFIRM_SECONDS`); the second sends `context.request(action, payload)`: lot `"Progression.BuyLotExpansion"` `{ level = next.target }`, parking `"Progression.BuyParking"` `{ tier = next.target }`, HQ `"Progression.BuyHQ"` `{ level = next.target }`; ok → clear `LandStatus`, else show `ERROR_KEYS[code]` (fallback the raw code); then `context.refresh()`. The tab computes no requirement; rows and `ready` come from the summary.
   - `render(nil)` or a missing `progression` table: `LandStatus` = `loading`, cards hidden. `shown(false)` clears confirm windows and the status. Sets `page.CanvasSize` to the stack height.
3. EmployeesTab: add `Standby = "staffStandby"` to `STATUS_KEYS` (nothing else).
4. Localization: add every key to `en` and `de`.
5. GAME_DESIGN §7: one sentence: four cards with the server's rows (Done/Missing), unlock lines and a two-tap Buy; the workshop has no button.

## Tests (headless)
| Test case file | Test name | Asserts |
|---|---|---|
| LandView_Test | maps every requirement row to a sentence key | 6 ids → `landRow<id>` with args (Cash via `formatMoney`), `met` copied, unknown → `landRowUnknown` |
| LandView_Test | marks inactive unlocks as coming soon | the 9 unlock ids of G9a (active as G9a sets them) → their keys and values |
| LandView_Test | builds status and next lines from a summary | fresh G9a summary (`Progression.summary(BusinessState.new(...))`): lot status `{ {nameKey="landLevel_Starter"}, 0, 6, 30 }`, lot next `{1, {nameKey="landLevel_BackLot"}, "$1,200"}`; parking next `{2, 4, "$600"}`; HQ next `{ {nameKey="hq_TimberPavilion"}, "$2,500"}`; a maxed section → `landMaxed` |
| LandView_Test | every key exists in both languages | every key in the Strings table is in `Localization.Strings.en` and `.de` |
Expected: **566** run (G9a's 562 + 4), 0 failed.

## Playtest (Studio, via playtester)
Tier S: no server step, no own full run. Queue in "Studio-Test ausstehend" (PC-7, real client viewport), R's save: (1) `Tab_Land` → `Page_Land`, four cards; "Starter Lot (0/6) · delivery storage 30", "Next: Expansion 1 · Back Lot for $1,200", Cash row "Missing" below $1,200; (2) note R's cash; `setProgression {userId = R.userId, cash = 1200}` (G9a): row "Done", Buy enabled; (3) "Confirm $1,200" for 4 s, second tap buys, card shows level 1, pad and fence grew; (4) a not-ready card shows "Requirements missing" and never sends; (5) the Workshop card has no button and says "Coming soon"; (6) `setProgression {userId = R.userId, hqLevel = 4, lotManager = 1}`: Employees shows the Lot Manager "Waiting for the lot computer (coming soon)", the Workshop card "Unlocked. …"; (7) 1564 × 730: no overlap, page scrolls; restore R: `setProgression {userId = R.userId, cash = <remembered>, lotExpansion = 0, hqLevel = 1, lotManager = 0}`.

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` → 566/566, `rojo build`.
- The tab shows every requirement with progress exactly as the server sends it and computes none.
- Buy uses G9a's target payloads; a double tap sends one request (busy flag); a repeat gets `AlreadyOwned`.
- Client checks queued (PC-7).

## Out of scope
Polish (CM2-UI), server (G9a), Lot Manager job (G9c), new species and counters (G9d).

# CM2-SUP — Supplier order panel: sizes, quantities, cart, recommended order, sell back

Written by `planner-high`; implemented by `implementer-opus`; pipeline `cm2-task`.
Rule: everything is decided; if something is missing, the implementer stops and reports.

## Goal
The Supplier tab orders any mix of species and sizes as one atomic cart and sells back per species and size, as in the reference.

## Source of truth
Backlog 18a (a–g); REFERENCE_GAME_LIVE_TEST §4.1, §3.1 (OBSERVED); DECISION_LOG 2026-11-26 CM2-SUP; PRODUCT_SPEC "UI look".

## Implementer tier
Tier: L. Reason: money, supplier stock, bays and a changed order action.

## Skill checks
- Cart fields are attacker-controlled: exact keys, finite integer quantities, bounded line count; no client price or cost is read.
- Validate all before the first mutation; one debit, one ledger entry; a refusal changes nothing.
- Store only tables the server built (normalize copies), never a client table.
- Replay -> `DuplicateRequest`; rate limits stay. MAX and cart math in the UI are convenience; the server re-checks.
- Phone first: targets >= 44 px, nothing under the 6 px scroll bar. Text only via `Localization` (EN, DE). Never rely on `pairs` order.

## Files
New: `src/shared/SupplierCart.lua`, `SupplierCart_Test.lua`, `Playtest/Steps/Supplier.lua`. Changed (shared): `GameConfig` (`Supplier.MaxCartLines = 12 -- PROVISIONAL: species x sizes`), `BusinessState`, `Protocol`, `UiTheme` (delete `supplierLayout` and its type), `Localization`; server: `CompanyStateService`, `SupplierStockService`, `main.server.lua`; client: `SupplierTab.lua` (rewrite), `Tutorial.client.lua`; tests below; `RunPlaytest.lua` (install `"Supplier"` after `"Quests"`, BUILD `cm2-sup`); docs (step 11).

## Data and config
- **No save-schema change, no migration.** A cart becomes several `pendingOrders` records of today's shape sharing `requestId`, `createdAt`, `dueAt`; several may target one bay of one species (`Receiving` already sums them).
- Record IDs: k = 1 `"order:" .. requestId`; k >= 2 `"order:" .. requestId .. ":" .. k`.
- **Packing:** per species (`SpeciesOrder`), sizes in `SizeIds` order fill groups of <= 9 (`BayCapacity`), splitting a line if needed; each group takes the next free bay (ascending), one record per (group, size); never a busy bay.
- Cart total <= `MaxOrderQuantity` (100). `BayCapacity` is no longer returned (client branch removed, string kept).

## Steps
1. **`SupplierCart.lua`** (`--!strict`, requires `GameConfig`, `Inventory`). Types `Line {speciesId, sizeId, quantity}`, `Group {speciesId, total, lines: {{sizeId, quantity}}}`, `Limits {cash, freeBays, storageFree, stock}`.
   - `normalize(lines: unknown): ({Line}?, string?)`, lines in index order, total last: not a table, empty, > `MaxCartLines` entries or a key not an integer 1..count -> `InvalidCart`; line not a table or an extra key -> `UnexpectedField`; bad species or size -> `InvalidItem`; quantity not an integer 1..100 (NaN, inf) -> `InvalidQuantity`; repeated species+size -> `DuplicateLine`; total > 100 -> `InvalidQuantity`. Returns new tables sorted by `SpeciesOrder`, then `SizeIds`.
   - `fromCounts(counts)`: lines for keys with an integer > 0, in that order. `total`, `cost` (sum of `wholesaleFor` x quantity), `pack` -> `{Group}`, `baysNeeded` (sum per species of `ceil(n / 9)`).
   - `maxAdd(counts, speciesId, sizeId, limits)` = `max(0, min(stock[key] - counts[key], 100 - total, storageFree - total, floor((cash - cost) / unit), 9 x (freeBays - otherBays) - speciesTotal))`, `otherBays` = bays of the other species; missing = 0.
   - `deliveryArea(counts, freeBays): (number, number)` = `(max(0, 9·freeBays - total), 9·freeBays)`.
2. **`BusinessState.placeCart(state, requestId, lines: unknown, timestamp, deliverySeconds: number?)`** checks before any change: `InvalidState`, `InvalidOrderId`, the `normalize` code, `InvalidTime`, `DuplicateOrder` (record 1 exists), `TooManyOpenOrders` (`openOrderCount + records > MaxOpenOrders`), `NoFreeBay` (groups > free bays), `StorageFull`, `SupplierOutOfStock` (any line), `InsufficientFunds`. Then stock per line, `cash -= cost`, `spent += cost`, records, each group bay's `speciesId`; once each: `record(state, "OrderPlaced", -cost)`, `Tutorial.advance(state, "Ordered")`, `QuestBoard.note(state, timestamp, "OrderTrees", total)`. Returns `true, {orderId (record 1), orderIds, cost, bay (first), bays (per group), quantity = total, dueIn = deliverySeconds or DeliverySeconds}`.
   - `placeOrder(...)` keeps its signature and calls `placeCart` with one line.
3. **Protocol** `Supplier.PlaceOrder`: with `payload.lines` -> `hasExactKeys(payload, {lines = true})` else `UnexpectedField`, then `SupplierCart.normalize`'s result; else the legacy checks.
4. **CompanyStateService**: after `refreshIfDue`, `lines = payload.lines` or the legacy fields as one line -> `placeCart(state, request.requestId, lines, clock, if instant then 0 else nil)`. Summary: `SupplierStockService.summary(state, clock, if instantDelivery then 0 else GameConfig.DeliverySeconds)`.
5. **SupplierStockService**:
   - `recommend(state)`: species in order, stop once used species reach `freeBays`; per Small, Medium `take = min(wanted, available, 9 - quantity, storageFree - quantity)`, cash loop as today; take > 0 marks the species used. Quantity 0 adds `reason`: `NoFreeBay`, else `StorageFull`, else `OutOfStock` (no Small/Medium stock), else `InsufficientFunds`.
   - `sellableCounts(state)`: per key bay count + unreserved placements; only > 0.
   - `summary(state, timestamp, deliverySeconds)` adds `sellable`, `refunds` (per key), `deliverySeconds`.
6. **main.server.lua** `afterOrderAction` success, `data` a table: `SupplierPlaceOrder` -> `tell(player, "orderPlacedToast", data.quantity, data.cost, data.dueIn)`; `SupplierSellBack` -> `tell(player, "soldBackToast", data.sold, data.refund)`.
7. **UiTheme** (`W = max(0, floor(pageWidth) - 8)`, `c = m.compact`, `h1 = if c then 32 else 36`, `pw = floor((W - 88) / 2)`; boxes x, y, w, h):
   - `supplierPanelLayout(m, pageWidth)`: `modeBuy 0,0,140,44`; `modeSell 144,0,140,44`; `refresh 292,0,W-292,44`; `placeOrder 0,48,pw,44`; `clear pw+4,48,80,44`; `recommend pw+88,48,W-pw-88,44`; `sellHint 0,48,W,44`; `status 0,96,W,18`; `cartInfo 0,116,W,h1`; `cartLines 0,118+h1,W,h1`; `rowsTopBuy = 124 + 2·h1`; `rowsTopSell = 118`; `rowPitch 48`; `rowHeight 44`; `footer 58`; `textSize = if c then 12 else 13`; `width = W`.
   - `supplierRowLayout(pageWidth, sellView)`, `o = if sellView then 100 else 0`: `text 0,0,max(0,W-208-o),44`; `minus W-200-o`; `qty W-152-o`; `plus W-104-o` (each 44x44 at y 0); `max W-56-o,0,56,44`; `sell = if sellView then W-96,0,96,44 else nil`.
8. **SupplierTab** (rewrite, same tab contract, UiKit/UiTheme only):
   - Instances: buttons `ModeBuy`, `ModeSell` (active Gold with UIStroke `Selected`, else Sand), `OrderTrees` (Gold), `ClearCart`, `AddRecommended` (Sand); labels `RefreshLabel`, `SupplierStatus`, `CartInfo`, `CartLines`, `SellHint` (last 3 wrapped); 12 transparent frames `Row_<speciesId>_<sizeId>`: labels `Name` (top 22 px of `text`), `Info` (bottom 22), `Qty`, buttons `Minus` "−", `Plus` "+", `Max`, `Sell`; footer `StockingHint` (h 36, `supplierStockingHint`), `CustomerLine` (h 18, today's `customerStatus`), 4 px below the last row, 2 px apart. Canvas Y = rowsTop + rows x 48 + 70. Each view hides the other's items.
   - State: `mode` ("Buy"), `cart`, `sellQty` (`{[key]: number}`), `lastSummary`, `busy {order, sell}`; `render(nil)` clears them, shows `loading`. Each cart change sets `page:SetAttribute("CartCount", total)`. Limits: `cash`, `supplier.stock`, `freeBays`, `storageFree` (from `receiving`).
   - Buy rows (all 12): Name `supplierRowName` (display name, `sizeSmall/Medium/Large`); Info `supplierBuyRowInfo` (`wholesale[key]`, stock) + `" · "` + `demandHigh`/`demandLow` per `demand[key]`; `Qty` = cart count; - subtracts 1 (key removed at 0); + adds 1 if `maxAdd >= 1`; `Max` (`maxButton`) adds `maxAdd`. Disabled = `AutoButtonColor false`, `TextTransparency 0.45`, tap ignored.
   - `CartLines`: `cartEmpty`, else `cartLines` of the first 3 `cartLineItem` (qty, name, size) joined by ", ", then `", " .. cartMore(rest)`. `CartInfo`: `cartInfo` (total, cost, `deliveryArea` free and capacity, `baysUsed + baysNeeded`, `bayCount`, `deliverySeconds` as m, s). `ClearCart` empties. `AddRecommended`: quantity > 0 -> `addRecommended` (cost), tap replaces the cart with its lines; else disabled with `recommendNothing` (reason `OutOfStock`) or the reason's error text.
   - `OrderTrees`: empty cart -> status `cartNeedsTrees`; else busy guard, text `ordering`, `Supplier.PlaceOrder {lines = SupplierCart.fromCounts(cart)}`; ok -> cart and status cleared, `context.refresh()`; error -> status `errorText(code)`, cart kept; text back to `placeOrder`.
   - Sell view (`ModeSell` = `supplierModeSell`, percent `floor(SellBackFraction x 100)`, also in `sellBackHint`): rows with `supplier.sellable[key] > 0` only, from `rowsTopSell`; none -> status `sellNothing`. Info `supplierSellRowInfo` (count, `refunds[key]`); `Qty` clamped to `min(sellable, 100)`; `Max` (`sellAll`) sets that bound; `Sell` = `sellRowButton` (refund x qty), disabled at 0; tap -> `Supplier.SellBack {speciesId, sizeId, quantity}`, one in flight; ok -> qty 0, `context.refresh()`; error -> status.
   - `RefreshLabel` = `supplierRefresh` (m, s) to `os.clock() + refreshIn` (set on render); a `task.spawn` loop updates it every 1 s while `page.Parent`.
   - `errorText`: today's map; `NoFreeBay` -> `noFreeBay` if `baysUsed >= bayCount` else `notEnoughBays` (9); the `normalize` codes and `TooManyOpenOrders` -> `orderUnavailable`. Layout on `UiKit.onLayout` and page resize, as today.
9. **Tutorial.client.lua** `supplierTargets`: second target `OrderTrees` when the page attribute `CartCount` is a number > 0, else `AddRecommended`.
10. **Localization** EN below; DE: a plain German translation, same specifiers in the same order (wording free). Old keys stay.
    - `supplierModeBuy` "Buy trees"; `supplierModeSell` "Sell back · %d%%"; `supplierRefresh` "Stock refresh %d:%02d"; `supplierRowName` "%s · %s"; `supplierBuyRowInfo` "$%d · %d in stock"; `demandHigh` "HIGH DEMAND"; `demandLow` "LOW DEMAND"; `supplierSellRowInfo` "%d unsold · $%d each"; `maxButton` "MAX"; `sellAll` "ALL"; `sellRowButton` "SELL · $%d".
    - `cartEmpty` "Your order is empty – add trees below."; `cartLines` "Your order: %s"; `cartLineItem` "%d× %s %s"; `cartMore` "+ %d more"; `cartInfo` "%d trees · $%d · Delivery area: %d / %d free · Bays %d/%d · ETA %d:%02d"; `clearCart` "Clear"; `addRecommended` "Add recommended order · $%d"; `recommendNothing` "Nothing suitable in stock right now — check back after the refresh."; `cartNeedsTrees` "Add trees to your order first."; `notEnoughBays` "Not enough free bays: each bay holds one kind of tree, at most %d."
    - `sellBackHint` "The distributor takes back unwanted trees for %d%% of what they cost – instantly. They come out of receiving first, then off your lot. Trees a customer has chosen are never sold."; `sellNothing` "No trees to sell back."; `soldBackToast` "Sold %d tree(s) back to the distributor for $%d."; `orderPlacedToast` "Order placed: %d trees for $%d — arriving in %d s."
    - Changed: `tutorialOrder` "Open the Lot Manager, add the recommended order and place it."
11. **Docs**: TECHNICAL_ARCHITECTURE §3 after `Supplier.PlaceOrder`: "(CM2-SUP: legacy payload or exactly `{lines}`, 1–12 lines, codes as `SupplierCart.normalize`; one atomic debit; one species per bay, <= 9 trees)". DECISION_LOG: protocol, packing, no schema change, recommended order replaces the cart, `BayCapacity` retired.

## Tests (headless)
Douglas = `DouglasFir`, Fraser = `FrasierFir`; cart X = Douglas S1 M2 + Fraser S1 M1 (5 trees, $133).

| File | Test name | Asserts |
|---|---|---|
| SupplierCart_Test (new) | normalizes and rejects bad carts | each step-1 code: hole `{[1],[3]}`, 13 lines, `unitCost`, 0, -1, 1.5, 0/0, 101, 60+41, duplicate; valid -> sorted |
| SupplierCart_Test | packs one species per bay, at most 9 each | Douglas S4 M7 + Fraser L2 -> {S4 M5}, {M2}, {L2}; `baysNeeded` 3 |
| SupplierCart_Test | costs wholesale times quantity | cart X -> 133 |
| SupplierCart_Test | maxAdd takes the tightest limit | one case per limit; never negative |
| Delivery_Test | splits a single line larger than one bay (replaces "rejects an order larger than one bay") | Fraser Small 10 -> `order:bay_overflow` 9 bay 1, `…:2` 1 bay 2 |
| Delivery_Test | places a mixed cart atomically | cash 1000, cart X: cash -133, spent +133, 4 records, 2 bays, stock per line, one `OrderPlaced` -133 |
| Delivery_Test | a failing cart changes nothing | out of stock; 3 bays busy + 2 species; storage full; cash 100; quantity 0, -1, 1.5, 101 -> cash, stock, bays, orders, `#history` unchanged |
| Delivery_Test | a mixed cart lands in its bays | at `dueAt`: Douglas {S1, M2}, Fraser {S1, M1}; none pending |
| Protocol_Test | validates a cart payload | `{lines}` ok; `{lines, cost}`, `{lines, speciesId}`, line `unitCost` -> `UnexpectedField`; legacy ok |
| CompanyStateService_Test | a replayed cart debits once | replay -> `DuplicateRequest`, cash, revision unchanged; "applies a purchase once" also checks `orderId` `order:order_1111`, `bay` 1 |
| SupplierStockService_Test | recommendation respects free bays and storage | 1 free bay -> one species; storage free 2 -> quantity 2; each `reason` |
| SupplierStockService_Test | summary lists sellable counts, refunds and delivery seconds | bay Fraser M3 + 2 placements (1 reserved) -> sellable 4; `refunds`, `deliverySeconds` |
| SupplierStockService_Test | sell back ALL never sells a reserved tree | same: `sellBack(4)` refund 32, reserved stays; 5th -> `NotEnoughTrees` |
| UiTheme_Test | supplier panel fits the Lot Manager body (replaces the CM2-UVF11 test) | 666x374, 667x375, 666x324, 780x302, 1920x1022, `body.w`: boxes in `0..body.w - 8`, `placeOrder` bottom <= `body.h`, buttons >= 44x44, no buy-view overlap |
| UiTheme_Test | supplier rows fit both views | same sizes and bounds, >= 44x44, no overlap, text width > 0 |

Expected count: 701 + 13 = **714** (one replaced test per Delivery and UiTheme), all PASS.

## Playtest (Studio, via playtester)
Now (tier L, core loop): `runPlaytest {mode = "full"}` -> **71/71 PASS**, BUILD `cm2-sup`; step details in the `Steps/Supplier.lua` header.

Step **70 SUPPLIER_CART** (needs `"03"`; on S via `act`/`actOk`; cost from `GameConfig.wholesaleFor`):
1. `advance(DELIVERY_WAIT)`, poll <= 8 s for no pending; sell back each `snap(S).stock` key (chunks <= 100) -> `baysUsed` 0; `advance(refreshIn + 1)`; cash >= 133.
2. `Supplier.PlaceOrder {lines = cart X}` -> cost 133, quantity 5, 4 `orderIds`, 2 `bays`; cash -133 exactly; `baysUsed` 2. Replay -> `DuplicateRequest`; `{lines, cost = 1}` -> `UnexpectedField`; cash unchanged.
3. `advance(DELIVERY_WAIT)`, poll <= 8 s: none pending; bays Douglas {S1, M2}, Fraser {S1, M1}.
4. `placeOne(S.userId, douglasBay)` -> `placementCount` +1.
5. `Supplier.SellBack {DouglasFir, Medium, 2}` -> refund 14, cash +14; sell back the other 3 -> `baysUsed` 0.

Client readings (desktop, phone 666x374): step-8 instances exist; row controls AbsoluteSize.Y >= 44, inside the page. `AddRecommended` -> `CartCount` > 0, `CartInfo` shows "Delivery area", "Bays"; `OrderTrees` -> toast "Order placed: …", cash -total once, cart empty. `ModeSell` -> only unsold rows; `Max`, `Sell` -> toast "Sold … back …", cash + refund.

## Acceptance
- StyLua, Selene, luau-lsp (`quality.yml`), headless 714 PASS, `rojo build` default and release.
- Backlog 18a (a)–(g); no price or cost in any client payload; Studio 71/71 PASS plus client readings.
- PROGRESS (skills: collaboration-mode, networking, security, gui, input, localization, luau-core), DECISION_LOG, TECHNICAL_ARCHITECTURE.

## Out of scope
CM2-V2-ORD recent orders, special and HQ-locked species, topping up a busy bay, a sell-back dialog, polish (CM2-UI).

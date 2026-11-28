# CM2-V2-ORD — Recent orders with status

Planner `planner`; implementer `implementer-high`; playtest inside CM2-RC4; reviewer `reviewer`. Everything is decided; anything missing: stop and report.

## Goal
The Supplier tab (buy view) shows "Recent orders": up to 4 rows, newest first, each with tree count, cost and status "Preparing order · ETA m:ss" → "In Transit" → "Delivered".

## Source of truth
REFERENCE_GAME_LIVE_TEST §3.2 "Order status", "Your order panel" (OBSERVED); DECISION_LOG 2026-11-28 "snow, hide HUD, recent orders, RC4"; backlog 41 (a)–(e); CM2-UICLIP clip rules.

## Implementer tier
Tier: M. Reason: read-only summary fields, a pure shared module and a client layout change; no action, save, money or validation change.

Implement after CM2-V2-HIDE is committed; keep HIDE's edits in UiTheme, Localization, UiTheme_Test.

## Skill checks
- Cost and ETA come from the server summary; the client only displays them. No new remote or validation; `Company.GetSummary` payload stays `{}`.
- Type-check record fields before arithmetic (NaN-safe); the client skips malformed records.
- Rows and title inside the layout width (`UiKit.contentWidth(page) - 8`), canvas via `UiKit.setCanvasHeight`; no new hover controls.
- Phone first: compact rows wrap to 2 lines of 14 px in 36 px; no text smaller than today.
- Player text only via `Localization` keys (en, de) and `localizedFormat`.
- No dependence on `pairs` order (explicit tiebreaks); no `#` on dictionaries.
- Session memory cleared on `render(nil)` (save switch), never persisted.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/OrderStatus.lua` | New | grouping, memory, status |
| `src/server/Services/CompanyStateService.lua` | Change | summary fields, cap |
| `src/shared/GameConfig.lua` | Change | `Supplier.RecentOrders = 4` |
| `src/shared/UiTheme.lua` | Change | `supplierPanelLayout` third arg, new fields |
| `src/client/LotManagerTabs/SupplierTab.lua` | Change | Recent orders block |
| `src/shared/Localization.lua` | Change | 4 keys en + de |
| `tests/studio/Cases/OrderStatus_Test.lua` | New | tests |
| `tests/studio/Cases/CompanySummaryProtocol_Test.lua` | Change | summary fields test |
| `tests/studio/Cases/UiTheme_Test.lua` | Change | layout with order rows |

## Data and config
- `GameConfig.Supplier.RecentOrders = 4` -- PROVISIONAL; rows shown and Delivered entries kept per session (4 bays cap open orders at 4).
- In Transit threshold: `GameConfig.Receiving.TruckPullInSeconds` (5, existing).
- Cost source: `GameConfig.wholesaleFor(speciesId, sizeId) * quantity` per record, the same table `SupplierCart.cost` charged with (BusinessState: "costs always come from GameConfig").

## Steps
1. **CompanyStateService** `deliverySummary(state, now: number)`; call site `deliveries = deliverySummary(state, self._clock())`. Each entry keeps its current fields and adds:
   - `groupId = if type(order.requestId) == "string" then "order:" .. order.requestId else orderId`
   - `createdAt = if type(order.createdAt) == "number" then order.createdAt else 0`
   - `cost = (GameConfig.wholesaleFor(order.speciesId, order.sizeId) or 0) * (if type(order.quantity) == "number" then order.quantity else 0)`
   - `arrivesIn = if type(order.dueAt) == "number" then math.max(0, order.dueAt - now) else 0`
   - Cap `while #orders > GameConfig.MaxOpenOrders` (was 10): an order never vanishes before it lands. Sort unchanged.
2. **OrderStatus.lua** (`--!strict`, requires only GameConfig):
   ```
   export type Entry = { groupId: string, quantity: number, cost: number, createdAt: number, dueClock: number, delivered: boolean }
   export type Row = { groupId: string, quantity: number, cost: number, status: string, eta: number }
   function OrderStatus.status(eta: number, delivered: boolean): string -- "Delivered" | "Preparing" | "InTransit"
   function OrderStatus.track(memory: { [string]: Entry }, deliveries: unknown, nowClock: number): ()
   function OrderStatus.rows(memory: { [string]: Entry }, nowClock: number): { Row }
   ```
   - `status`: delivered → `"Delivered"`; `eta > TruckPullInSeconds` → `"Preparing"`; else `"InTransit"`.
   - `track`: if `deliveries` is not a table, return with no change. Group records (tables with string `groupId`, else string `orderId`; finite number `quantity > 0`; missing number fields count 0): sum `quantity` and `cost`, `createdAt` = min, `arrivesIn` = max clamped ≥ 0. Per group: create or update the entry with `quantity = max(old, sum)`, `cost = max(old, sum)`, `createdAt`, `dueClock = nowClock + arrivesIn`, `delivered = false`. Every entry not in the groups and not delivered becomes `delivered = true`. Then keep only the newest `RecentOrders` delivered entries (sort `createdAt` desc, then `groupId` desc) and remove the rest from `memory`.
   - `rows`: all entries sorted `createdAt` desc, then `groupId` desc; first `RecentOrders`; `eta = math.max(0, math.ceil(dueClock - nowClock))`, `status = OrderStatus.status(eta, delivered)`.
3. **UiTheme** `supplierPanelLayout(m, pageWidth, orderRows: number?)`; `n = math.max(0, math.floor(orderRows or 0))`. New type fields: `orders: Box`, `orderTitleHeight: number`, `orderRowHeight: number`, `orderPitch: number`.
   | | desktop | compact |
   |---|---|---|
   | orderTitleHeight | 18 | 20 |
   | orderRowHeight / orderPitch | 18 / 20 | 36 / 38 |
   - `oldTop` = today's `rowsTopBuy`; `block = if n > 0 then orderTitleHeight + n * orderPitch + 4 else 0`; `orders = box(0, oldTop, W, math.max(0, block - 4))`; `rowsTopBuy = oldTop + block`. Everything else unchanged (n 0 = today).
4. **SupplierTab**:
   - Locals `orderMemory: { [string]: OrderStatus.Entry } = {}`, `orderRowCount = 0`.
   - Create `ordersTitle = UiKit.label(page, "RecentOrdersTitle", localized("recentOrdersTitle"), 13)` and `orderLabels[i] = UiKit.label(page, "RecentOrder" .. i, "", 13)` for `i = 1..GameConfig.Supplier.RecentOrders`, each `TextWrapped = true`, `TextTruncate = None`; add all to the `TextSize = layout.textSize` loop in `applyLayout`.
   - `renderOrders()`: `rows = OrderStatus.rows(orderMemory, os.clock())`; label i text: `Preparing` → `localizedFormat("recentOrderPreparing", q, cost, eta // 60, eta % 60)`, `InTransit` → `localizedFormat("recentOrderInTransit", q, cost)`, `Delivered` → `localizedFormat("recentOrderDelivered", q, cost)`; `Visible = mode == "Buy" and i <= #rows`; title `Visible = mode == "Buy" and #rows > 0`.
   - `renderView()`: `orderRowCount = if buy then #OrderStatus.rows(orderMemory, os.clock()) else 0`, passed as third arg to both `supplierPanelLayout` calls (also `applyLayout`); title at `(0, orders.y, W, orderTitleHeight)`, label i at `(0, orders.y + orderTitleHeight + (i-1) * orderPitch, W, orderRowHeight)`; then `renderOrders()`. Canvas formula unchanged.
   - The 1 s loop also calls `renderOrders()`.
   - `render(summary)`: nil → `orderMemory = {}` before `renderView()`; else `OrderStatus.track(orderMemory, summary.deliveries, os.clock())` before `renderView()`.
5. **Localization** (after `cartInfo`, en / de):
   | key | en | de |
   |---|---|---|
   | recentOrdersTitle | `Recent orders` | `Letzte Bestellungen` |
   | recentOrderPreparing | `%d trees · $%d · Preparing order · ETA %d:%02d` | `%d Bäume · %d $ · Bestellung wird vorbereitet · Ankunft %d:%02d` |
   | recentOrderInTransit | `%d trees · $%d · In Transit` | `%d Bäume · %d $ · Unterwegs` |
   | recentOrderDelivered | `%d trees · $%d · Delivered` | `%d Bäume · %d $ · Geliefert` |

## Tests (headless)
| Test case file | Test name | Asserts |
|---|---|---|
| OrderStatus_Test | status boundaries | `status(6,false)=="Preparing"`, `status(5,false)=="InTransit"`, `status(0,false)=="InTransit"`, `status(9,true)=="Delivered"` |
| OrderStatus_Test | groups records of one order | two records same groupId (q 3 + 2, cost 30 + 20, arrivesIn 20/25) → 1 row q 5, cost 50, eta 25 at now |
| OrderStatus_Test | eta counts down to In Transit | track at clock 0 with arrivesIn 30; rows at 24.5 → Preparing eta 6; at 25 → InTransit eta 5 |
| OrderStatus_Test | vanished order becomes Delivered | track A, then track `{}` → A Delivered with the same q and cost |
| OrderStatus_Test | non-table deliveries change nothing | track A, then nil → A Preparing |
| OrderStatus_Test | keeps the newest 4 delivered, newest first | 6 orders createdAt 1..6 all delivered → rows createdAt 6,5,4,3; memory holds 4 entries |
| OrderStatus_Test | skips malformed records | no ids, NaN or 0 quantity → 0 rows |
| CompanySummaryProtocol_Test | summary deliveries carry group, cost and ETA | clock 100 (pattern of the staff test), `Supplier.PlaceOrder` lines DouglasFir Medium 2 + NobleFir Small 1 → 2 entries, one `groupId` starting `order:`, `createdAt` 100, `cost == wholesaleFor * q`, `arrivesIn == DeliverySeconds`; clock 110 → `DeliverySeconds - 10` |
| UiTheme_Test | supplier layout makes room for recent orders | each SUPPLIER_SIZES body, n 4: `orders` inside `body.w - 8`, `orders.y >= cartLines` bottom, `rowsTopBuy >= orders` bottom; 1920x1022 w 600: n 0 → `rowsTopBuy` 196, n 4 → 298 |

## Playtest (Studio, via playtester)
Desktop, inside CM2-RC4; phone readings go to the CM2-UIP queue.
1. Smoke setup; Lot Manager → Supplier, buy view; add 1 tree, Place order.
2. Within 5 s `RecentOrder1` reads "1 trees · $<wholesale> · Preparing order · ETA 0:2x"; title visible.
3. ETA ≤ 5 s → "… In Transit"; ≤ 10 s after the tree lands → "… Delivered".
4. Row visible, at top and with `Page_Supplier.CanvasPosition` at the bottom: Supplier `probe` (CM2-UICLIP step 2) → 0 problems.
5. Save switch → Supplier shows no order rows.

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (the count after HIDE + 9, 0 failed), `rojo build`.
- Backlog 41 (a)–(e) as settled above; desktop steps PASS in CM2-RC4, probe 0.

## Out of scope
Sell-view orders; persisting Delivered; bay numbers; cart or order flow changes; phone Studio run (CM2-UIP).

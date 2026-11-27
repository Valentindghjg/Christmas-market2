# CM2-UI3M — Phone Lot Manager at 70 % x 80 % (22a3c)

## Goal
On phones the Lot Manager is a centred window of at most 70 % x 80 % of the safe area: tabs in a scrolling vertical column on the left, Supplier rows in two lines (text over controls) at 14 px, a shorter Pricing card. Desktop and tablet unchanged.

## Source of truth
Backlog 22a3c; PRODUCT_SPEC "Compact on phone" (OWNER DECIDED 2026-11-25); `docs/plans/CM2-UI3.md` (PHONES, BASELINE); `docs/archive/plans/CM2-UI3D.md`; CM2-SUP plan step 8 (rows, footer).

## Implementer tier
Tier: M. Reason: layout maths in `UiTheme` plus reflow in three Lot Manager clients; no remotes, saves, money or strings.

## Skill checks
- gui: check every pair that shows together (title/cash/close, tab column vs body, refresh/status/buttons/cart, row text vs controls) on every phone size; reflow, don't shrink: buttons stay 44 px, text gets taller boxes.
- gui: boxes come from pure `UiTheme`; clients only place them; regular screens produce exactly today's boxes.
- gui: a scrolling tab column shows a 4 px bar and keeps the selected tab in view.
- input: no binding or guard change. localization: no new key; long texts wrap in the boxes below.
- luau: new optional parameter read with `== true`; no dictionary-order dependence.

## Files
| File | Change |
|---|---|
| src/shared/UiTheme.lua | Steps 1–5 |
| src/client/LotManager.lua | Step 6 |
| src/client/LotManagerTabs/SupplierTab.lua | Step 7 |
| src/client/UiController.client.lua | Step 8 (comment only) |
| tests/studio/Cases/UiTheme_Test.lua | Step 9 |

## Data and config (PROVISIONAL engineering values)
New locals in `UiTheme.lua`: `PHONE_MANAGER_PADDING = 6`, `PHONE_TAB_WIDTH = 100`, `TAB_SCROLLBAR = 6`.
Expected phone boxes (manager x, y, w x h → body w x h; Supplier W = body.w − 8):
| Safe area | manager | body | W |
|---|---|---|---|
| 667x317 | 100, 32, 466x253 | 348x191 | 340 |
| 780x302 | 117, 30, 546x241 | 428x179 | 420 |
| 750x332 | 112, 33, 525x265 | 407x203 | 399 |
| 666x374 | 100, 37, 466x299 | 348x237 | 340 |
| 780x281 | 117, 28, 546x224 | 428x162 | 420 |

## Steps
1. `hudLayout`, compact branch of `manager` only: `local w = math.max(0, math.min(math.floor(0.7 * m.width), m.width - 2 * m.margin))`, `h` the same with `0.8 * m.height`; `manager = box(math.floor((m.width - w) / 2), math.floor((m.height - h) / 2), w, h)`. Comment: phones cap the Lot Manager at 70 % x 80 % of the safe area (22a3c).
2. `ManagerLayout` type: remove `horizontal`, add `tabScrolls: boolean`. `managerLayout(m, manager)`:
   - Regular branch: boxes unchanged; `tabScrolls = count * 54 - 6 > tabBar.h` (false on every MATRIX size).
   - Compact branch (replaces the horizontal bar): `padding = PHONE_MANAGER_PADDING`; `cw`, `ch` as today with this padding; `header`, `close`, `cash`, `title` with today's compact formulas; `tabBar = box(0, 50, PHONE_TAB_WIDTH, ch - 50)`; `tabScrolls = count * 48 - 4 > tabBar.h`; `tw = PHONE_TAB_WIDTH - (if tabScrolls then TAB_SCROLLBAR else 0)`; `tabs[i] = box(0, (i - 1) * 48, tw, BUTTON_HEIGHT)`; `body = box(PHONE_TAB_WIDTH + 6, 50, cw - PHONE_TAB_WIDTH - 6, ch - 50)`.
3. `SupplierPanelLayout` type gains `footerHint: number`, `footerLine: number`. `supplierPanelLayout`: regular branch returns today's values plus `footerHint = 36`, `footerLine = 18`, `footer = 58`. Compact branch (new; `W` as today, `mw = math.floor((W - 4) / 2)`, `pw = math.floor((W - 88) / 2)`, `h1 = 40`):
   | Key | Value |
   |---|---|
   | modeBuy / modeSell | `0,0,mw,44` / `mw+4,0,W-mw-4,44` |
   | refresh / status | `0,48,W,20` / `0,70,W,20` |
   | placeOrder / clear / recommend | `0,94,pw,44` / `pw+4,94,80,44` / `pw+88,94,W-pw-88,44` |
   | sellHint | `0,94,W,100` |
   | cartInfo / cartLines | `0,142,W,h1` / `0,144+h1,W,h1` |
   | rowsTopBuy / rowsTopSell | `148 + 2*h1` (228) / `198` |
   | rowPitch / rowHeight | `92` / `88` |
   | footerHint / footerLine / footer | `40` / `20` / `64` |
   | textSize / width | `14` / `W` |
   Comment: phones stack the row text over the controls so 14 px text keeps the full width (22a3c).
4. `supplierRowLayout(pageWidth: number, sellView: boolean, compact: boolean?)`: if `compact == true`: `text = box(0, 0, W, 44)`; controls as today but at `y = 44`; else today's boxes unchanged.
5. `pricingCardLayout`, compact branch only: `cardHeight 160`, `pitch 168`, `name 10,2,304,18`, `sentiment 10,20,304,16`, `wholesaleTypical 10,36,304,28`, `margin 10,64,304,16`, `sizes 10,80,304,28`, `price 130,112,64,BUTTON_HEIGHT`, `controlsY 112`, `controlsHeight BUTTON_HEIGHT`. Update the comment: one whole card fits the phone page (≥ 162 px high).
6. `LotManager.applyLayout`: `tabBar.ScrollingDirection = Enum.ScrollingDirection.Y`; `tabBar.ScrollBarThickness = if layout.tabScrolls then 4 else 0`; `tabBar.CanvasSize = UDim2.fromOffset(0, canvasHeight)` (drop `canvasWidth` and both `horizontal` branches). New local `revealSelected()`: tab button of `selectedId`, `top = Position.Y.Offset`, `bottom = top + Size.Y.Offset`, `view = tabBar.AbsoluteWindowSize.Y`, `y = tabBar.CanvasPosition.Y`; if `top < y` set `CanvasPosition = Vector2.new(0, top)`, elseif `view > 0 and bottom > y + view` set `Vector2.new(0, bottom - view)`. Call it at the end of `updateTabs` and after `placeIndicator(false)` in `applyLayout`. Update the header comment line on tabs if it says horizontal.
7. SupplierTab `renderView`: `UiTheme.supplierRowLayout(page.AbsoluteSize.X, not buy, metrics.compact)`; `Name` at `{x = text.x, y = text.y, w = text.w, h = 22}`, `Info` at `y = text.y + 22`; footer: `stockingHint` `{0, footerTop, layout.width, layout.footerHint}`, `customerLine` `{0, footerTop + layout.footerHint + 2, layout.width, layout.footerLine}`; `CanvasSize` Y = `rowsTop + shownRows * layout.rowPitch + layout.footerHint + layout.footerLine + 16` (70 on desktop, as today). Nothing else changes.
8. UiController comment above `updateChrome`: "On a phone the open Lot Manager covers the middle of the safe area (70 % x 80 %), so the HUD and the rail step aside." Logic unchanged.
9. Tests below.

## Tests (headless; 779 → 781)
| Test | Asserts |
|---|---|
| fits the Lot Manager on every screen (change) | replace `inner.horizontal == m.compact` with `inner.tabScrolls == m.compact`; rest unchanged |
| supplier panel fits the Lot Manager body (change) | add: `sellHint` bottom ≤ `rowsTopSell`; `refresh` in the no-overlap ids list stays; pc asserts unchanged |
| supplier rows fit both views (change) | `supplierRowLayout(body.w, sellView, m.compact)`; bound `inside(b, body.w - 8, panel.rowHeight)` with `panel = supplierPanelLayout(m, body.w)`; compact: `text.w == panel.width`, controls `y == 44` |
| Pricing card fits the page (change) | `compactCard.controlsY == 112` (was 120) |
| phone windows, buttons and text meet the compact limits (change) | add for PHONES: `supplierPanelLayout(m, body.w).textSize` in 14..16 |
| phone Lot Manager fits 70 % x 80 % (22a3c) (new) | for PHONES: manager ≤ `floor(0.7 W)` x `floor(0.8 H)`, inside the screen, ≤ BASELINE; with `cw`, `ch` = manager minus 2 x padding: title, cash, close, tabBar, body inside `cw` x `ch`, pairwise no overlap; tabs `x == 0`, `y == (i - 1) * 48`, `w == tabBar.w - 6` when `tabScrolls`, h 44..52, w ≥ 88, inside `tabBar.w`; Supplier: textSize 14, buttons h 44..52 and inside `W`, rows both views: controls h 44..52 inside `W` x `rowHeight`, text.w ≥ 240; Pricing: `324 <= body.w - 8`, `cardHeight <= body.h`, controls inside the card; 780x281: manager `117,28,546,224`, body `106,50,428,162` |
| desktop Lot Manager boxes unchanged (22a3c) (new) | 1920x1022: manager `578,94,920,640`, tabBar `0,52,168,564`, body `180,52,716,564`, tabs `0,(i-1)*54,168,48`, close `800,0,96,44`, `tabScrolls` false, `cash` nil; 960x542: manager `168,94,780,436`; `supplierPanelLayout(pc, 716)`: `rowPitch 48`, `rowHeight 44`, `footerHint 36`, `footerLine 18`, `status.h 18`, `refresh.x 292`, `textSize 13`; `supplierRowLayout(716, true)` == `supplierRowLayout(716, true, false)` and `text.w 400` |
BASELINE test must stay PASS (manager smaller).

## Playtest (Studio, via playtester; desktop)
1. Smoke run.
2. Open the Lot Manager through `StudioUiHook` (press `HudRailUI/Rail/LotManagerButton`) and press each `Tab_<id>` in `UiTheme.LotManagerTabs` order: `LotManager` frame position and size equal the regular-branch `hudLayout(metrics, 0).manager` of the session's safe area (unchanged code path), `TabBar.ScrollBarThickness` 0, H4b probe (`docs/archive/plans/CM2-UV.md`) 0 violations per tab. Supplier: `ModeSell` then `ModeBuy`, H4b 0 in both views; row `Minus` AbsoluteSize.Y 44. Close.
Phone readings: 22a4 CM2-UIP (PC-14 open).

## Acceptance
- `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (781 PASS), `lune run tests/tools/ui_scan.luau` (0 hits), `rojo build`.
- 22a3c (a) headless; (b) same remotes, error codes, string keys and save fields, desktop boxes pinned by the new test; (c) desktop H4b 0 per tab and smoke PASS.
- Reviewer logs (DECISION_LOG): phone tab column scrolls (4 to 5 of 6 tabs visible); phone Supplier rows 88 px (two lines, pitch 92) instead of 44 so 14 px text keeps full width; phone Pricing card 160 px; phone manager padding 6; CM2-SUP row test bound now `rowHeight`.

## Out of scope
HUD 20 % (22a3d); Employees and Land page reflow and Pricing/Employees 12–13 px caption text (22a4 readings decide); phone and tablet readings (22a4); any string change.

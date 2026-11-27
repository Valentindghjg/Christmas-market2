# CM2-UVF13 — Phone: FinderButton near the thumbstick

Written by: `planner` (Opus 5.5, medium). Implemented by: `implementer`. Playtested by: `playtester`. Reviewed and committed by: `reviewer`. Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
On phones every rail button, `FinderButton` included, is fully visible, at least 44 px high, ends at least 8 px above the thumbstick ring, and opens its panel on tap. Desktop and tablet rails stay as they are.

## Source of truth
- Backlog 5m CM2-UVF13 and its status line of 2026-11-25 (step 1 evidence: Rail 124x204 at (8,8), FinderButton (8,200) 118x44 clipped, ring `ThumbstickStart` (29,223) 74x74, GuiInset (0,58)).
- PRODUCT_SPEC: 44 px minimum touch size; TECHNICAL_ARCHITECTURE section 1 (layout math in `src/shared/UiTheme.lua`).

### Why the live rail is 204 and not 262
`UiKit.onLayout` passes `gui.AbsoluteSize` to `UiTheme.metrics`. `UiKit.screenGui` sets `IgnoreGuiInset = false` and `ScreenInsets = CoreUISafeInsets`, so on a 666x374 viewport the GUI is 666x316 (374 - 58 inset). `railMaxHeight = 316 - 8 - 8 - 96 = 204`. The UVF13 test and the step 1 estimate used the viewport height 374, giving 262. The MATRIX in `UiTheme_Test.lua` already uses safe-area sizes (667x317). With 204 px only 4 rows fit (4 x 44 + 3 x 4 = 188); 5 rows need 236, so `railScrolls` is true and the ScrollingFrame clips the fifth button. All rail and ring coordinates below are GUI coordinates (both ScreenGuis respect the inset; the ring top 223 lies 93 px above the GUI bottom 316).

## Implementer tier
Tier: S. Reason: client layout only (pure layout math in UiTheme plus the rail placement in UiKit); no server rule, action, remote or save field.

## Skills to load
roblox-collaboration-mode, roblox-gui, roblox-input, roblox-luau-core, roblox-luau-types.

## Chosen option: compact overflow column in the top row
On compact screens, when the visible buttons do not fit in one column inside `railMaxHeight`, the column keeps the rows that fit and the remaining buttons (highest LayoutOrder last) go to the right of row 1, between the rail and the HUD chip strip. Rejected: a raised `THUMB_RESERVE` (rail still scrolls, button hidden); always two columns (changes toast, tutorial and stocking widths through `railWidth`); spacing (5 x 44 = 220 > 207).

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/UiTheme.lua` | Change | `HudLayout.railButtons`, overflow math in `hudLayout` |
| `src/client/UiKit.lua` | Change | `applyRail` places buttons from `layout.railButtons`; no UIListLayout |
| `tests/studio/Cases/UiTheme_Test.lua` | Change | replace the UVF13 test, add one |

## Data and config
New constants in `UiTheme.lua` next to the layout constants:
| Name | Value | Tag |
|---|---|---|
| `RAIL_OVERFLOW_MIN_WIDTH` | 72 | PROVISIONAL |
| `RAIL_SCROLLBAR` | 6 (button width = `railWidth - 6`, as `UDim2.new(1, -6, …)` today) | existing behaviour |

`THUMB_RESERVE` stays 96, `railWidth` stays 124/148, `metrics` unchanged.

## Steps
1. `UiTheme.lua`: add `railButtons: { Box }` to `export type HudLayout` (boxes relative to `rail`, one per visible button in LayoutOrder order).
2. In `hudLayout(m, railButtons)` after `hud` is computed, with `count`, `cell = m.railWidth - RAIL_SCROLLBAR`, `step = BUTTON_HEIGHT + m.railGap`:
   - Default (single column, exactly today's result): box i (1-based) = `box(0, (i-1)*step, cell, BUTTON_HEIGHT)`; `rail = box(m.margin, m.railTop, m.railWidth, math.min(content, m.railMaxHeight))`; `railScrolls = content > m.railMaxHeight`.
   - Overflow, only if `m.compact` and `content > m.railMaxHeight`: `rows = math.max(1, math.floor((m.railMaxHeight + m.railGap) / step))`; `extra = count - rows`; `startX = cell + m.railGap`; `ow = math.min(cell, math.floor((hud.x - GAP - m.margin - startX - extra * m.railGap + m.railGap) / extra))` (that is the room from `startX` to `hud.x - GAP`, split into `extra` cells with `railGap` between them). If `ow >= RAIL_OVERFLOW_MIN_WIDTH`: boxes 1..rows as default; box rows+k = `box(startX + (k-1)*(ow + m.railGap), 0, ow, BUTTON_HEIGHT)`; `rail = box(m.margin, m.railTop, startX + extra*ow + (extra-1)*m.railGap, rows*BUTTON_HEIGHT + (rows-1)*m.railGap)`; `railScrolls = false`. Else keep the default (scrolling) result.
   - Return `railButtons` in the HudLayout table.
3. `UiKit.lua`:
   - Remove `railLayout` and the `UIListLayout` creation in `ensureRail`; keep `AutomaticCanvasSize = Y`.
   - `applyRail`: collect visible buttons, sort by `LayoutOrder` (ties by `Name`), call `hudLayout(m, #visible)`, set frame Position/Size/ScrollingEnabled as today, then for each visible button i: `Position = UDim2.fromOffset(b.x, b.y)`, `Size = UDim2.fromOffset(b.w, b.h)`, `TextSize = if b.w < 100 then UiTheme.TextSize.Small else UiTheme.TextSize.Body`.
   - `addRailButton`: drop the `Size = UDim2.new(1, -6, …)` line (applyRail sizes it); `RAIL_BUTTON_HEIGHT` goes if unused.
4. Update the rail-slot comment above `addRailButton`: "Phones: buttons that do not fit above the thumbstick go right of row 1 (CM2-UVF13)."

### Exact boxes (GUI px, absolute; 5 buttons: LotManager 10, Shop 20, Saves 50, Team 60, Finder 70)
| GUI size (viewport) | railMaxHeight | hud.x | Column rows 1–4 | FinderButton | Rail box | Lowest bottom vs ring top |
|---|---|---|---|---|---|---|
| 666x316 (666x374) | 204 | 216 | x 8..126, y 8, 56, 104, 152 (h 44) | (130, 8) 78x44, ends x 208 | (8, 8) 200x188 | 196 vs 223: 27 px |
| 667x317 (667x375) | 205 | 217 | same | (130, 8) 79x44, ends x 209 | (8, 8) 201x188 | 196 vs 224: 28 px |
Desktop 1920x1022 and tablet 1024x710: unchanged (single column, x 0, width 142, `railScrolls` false).

## Tests (headless)
| Test case file | Test name | Asserts |
|---|---|---|
| `tests/studio/Cases/UiTheme_Test.lua` | `keeps every phone rail button above the thumbstick` (replaces `keeps every phone rail button above the thumb reserve`) | Uses the live input: GUI sizes 666x316 and 667x317 (viewport minus the 58 px inset, what `UiKit.onLayout` passes) plus every compact MATRIX entry. `metrics(666,316).railMaxHeight == 204`. For count 1..5: `#layout.railButtons == count`; `railScrolls` false; every button box (absolute = rail + box) has h >= 44, w >= 72, lies inside the rail box, bottom <= `size.h - 93 - 8` (ring top 93 px above the GUI bottom), right <= `hud.x - 8`, no overlap with `hud`, `toast` or another button. For count 5 at 666x316: Finder box equals `{x=122, y=0, w=78, h=44}` relative, rail `{x=8, y=8, w=200, h=188}`. |
| same | `keeps the regular rail as one column` (new) | For 1920x1022 and 1024x710, count 1..5: box i = `{0, (i-1)*(44+railGap), railWidth-6, 44}`, rail.w == railWidth. |
The existing `scrolls the rail instead of overflowing` (7 buttons at 667x317: ow 23 < 72, falls back) must pass unchanged. Expected headless count: 599 + 1 = 600.

## Playtest (Studio, via playtester)
1. Device iPhone 7 (viewport 666x374 ±2), default touch controls, Play Solo, a slot loaded so all five rail buttons are visible.
2. Read `HudRailUI.Rail` and every child button `AbsolutePosition`/`AbsoluteSize`, and `TouchGui…ThumbstickStart` (or the ring frame) `AbsolutePosition`; report GUI and viewport values (`+ GuiService:GetGuiInset()` when the ScreenGui has `IgnoreGuiInset` false). Expected: boxes as in the table; every button bottom <= ring top - 8 in the same space; FinderButton not clipped (fully inside `Rail` abs box); no overlap with `ChristmasMarketUI` HUD chips.
3. Tap the centre of FinderButton (viewport ~ (169, 88)) → `FinderUI.FinderPanel.Visible == true`. Close it. Tap each other rail button once → its panel opens.
4. One zoomed bottom-left capture shows the gap between the lowest button and the ring; `TextFits` true on FinderButton ("Teammates").
5. Window 1920x1080: rail single column at x 12, unchanged; FinderButton below TeamButton.

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (600 passed), `rojo build`.
- Headless at 666x316 and 667x317 (viewport 666x374 and 667x375) for every rail button box as above.
- Studio: every rail button ends >= 8 px above the measured ring top, FinderButton fully visible and >= 44 px, a tap opens `FinderUI.FinderPanel`; desktop rail unchanged.

## Out of scope
`THUMB_RESERVE`, toast, tutorial bar and stocking layouts; the jump button (right side, no rail contact); German text fit (English launch, PRODUCT_SPEC 2026-11-21); more than 5 rail buttons on phones (falls back to scrolling).

# CM2-UICLIP — Nothing cut off inside any window

Written by `planner` (Opus 5.5); pipeline `cm2-task`. All decided; anything missing: stop and report.

## Goal
No outline, hover growth or row is cut at a window, tab-bar or list edge on desktop; the probe measures it.

## Source of truth
Backlog CM2-UICLIP (a)–(e); DECISION_LOG 2026-11-28 "UI clipping…" (a); builds on `docs/plans/CM2-UIFIX.md` (adecbe8). Owner screenshot causes:
- Tabs sit at x 0 in the `TabBar` ScrollingFrame; "Buy trees"/"Sell back" at y 0 in `Page_Supplier`.
- "+"/"MAX": stroke plus hover growth (1.05 from anchor 0,0, so 15 px on a 300 px button) under the 6 px overlay bar.
- Last row: the canvas has no room for the stroke.

## Implementer tier
Tier: M. Reason: client UI only across the kit, every list window, the Lot Manager and the probe; no server, remote, save, money or string change.

## Skill checks
- gui: leave room for Border `UIStroke` (drawn outside the box, cut by a clipping ancestor); measure with `AbsolutePosition`/`AbsoluteSize`/`AbsoluteWindowSize`.
- gui: canvas policy: lists keep `AutomaticCanvasSize = Y`; manual canvases add the padding through one helper.
- gui: desktop pairs here; phone readings stay with CM2-UIP (PC-14), phone layout tests must still pass.
- localization: no new or changed player text.
- collaboration-mode: low risk; prove each line with a probe reading, never claim one not taken.

## Files
| File | Change |
|---|---|
| `src/shared/UiTheme.lua` | `Motion.hoverGrowMax`, `ClipInset`, `clipPadding`, `clipBox` |
| `src/shared/UiStyle.lua` | `cappedScale`, `hoverGrowth` |
| `src/client/UiKit.lua` | hover cap; `clipInset`, `clipOutward`, `setCanvasHeight`, `contentWidth`; probe kind `stroke` |
| `src/client/LotManager.lua` | pages inward, tab bar outward, `revealSelected` |
| `src/client/LotManagerTabs/{Supplier,Pricing,Employees,Land}Tab.lua` | canvas helper; Supplier width helper |
| `AdventPanel`, `EventShopPanel`, `QuestPanel`, `SavePicker`, `ShopPanel`, `TeammateFinder`, `TeamPanel` (src/client) | one call each |
| `tests/studio/Cases/UiTheme_Test.lua`, `UiStyle_Test.lua` | 5 new tests |
| `docs/UI_STYLE.md`, `docs/PROGRESS.md` | rule line; readings |

## Data and config (PROVISIONAL look values)
| Key | Value |
|---|---|
| `UiTheme.Motion.hoverGrowMax` | `3` px, cap on total hover growth (any anchor) |
| `UiTheme.ClipInset` | `Style.StrokeSelected + Motion.hoverGrowMax + 2` = 8, an expression after `Motion`, no literal |
| ScrollingFrame right padding | `ClipInset + ScrollBarThickness`: the overlay bar sits in the padding; `VerticalScrollBarInset` stays `None` |
| `UiTheme.RailInset` | unchanged 6: HUD rail, never selected, 2 + 3 = 5 ≤ 6; the probe checks it |

## Steps
1. **UiTheme.** Add the token `hoverGrowMax = 3` to `Motion`. Add `ClipInset`.
   - `UiTheme.clipPadding(scrollBar: number): { left: number, right: number, top: number, bottom: number }` returns I, I + scrollBar, I, I.
   - `UiTheme.clipBox(b: Box): Box` grows `b` by I on every side.
2. **UiStyle.**
   - `cappedScale(scale: number, width: number, height: number): number`: if `scale <= 1`, return `scale`. Otherwise return `math.min(scale, 1 + Motion.hoverGrowMax / math.max(width, height, 1))`.
   - `hoverGrowth(width: number, height: number): number` = `(cappedScale(Motion.hoverScale, width, height) - 1) * math.max(width, height, 1)`.
3. **UiKit `applyInteraction`.** Let `s = press.Scale`, or 1 if `s <= 0`. Read `w = AbsoluteSize.X / s` and `h = AbsoluteSize.Y / s`. Tween to `UiStyle.cappedScale(spec.scale, w, h)` instead of `spec.scale`. States below 1 unchanged; the release Back overshoot fits the 2 px margin.
4. **UiKit helpers** (public, beside `UiKit.padding`):
   - `clipInset(container: GuiObject): UIPadding`
     - Reuses or creates the child `UIPadding` named `"ClipInset"`.
     - Sides come from `UiTheme.clipPadding(t)`, where `t` = `ScrollBarThickness` if the container is a ScrollingFrame, else 0.
   - `clipOutward(container: GuiObject): UIPadding`
     - Position offsets −I, Size offsets +2I (scales kept), then `clipInset(container)`.
     - Call it right after every Position/Size assignment (never twice without one); the content box stays put.
   - `setCanvasHeight(frame: ScrollingFrame, contentHeight: number)` sets `CanvasSize = UDim2.fromOffset(0, contentHeight + top + bottom)` of its `ClipInset` padding (0 if missing).
   - `contentWidth(frame: GuiObject): number` = `AbsoluteSize.X - left - right` of its `ClipInset` padding.
5. **Inward padding** (`UiKit.clipInset(x)` right after the `ScrollBarThickness` line):
   - lists: `AdventPanel` list, `EventShopPanel` list, `QuestPanel` list, `SavePicker` list, `ShopPanel` `productList`, `TeammateFinder` `listingList`, `TeamPanel` `memberList`;
   - Lot Manager pages: `LotManager.buildPage` page.
6. **Outward padding** (the boxes are fixed by the 22a3c baselines):
   - `ShopPanel` `categoryBar`: call `UiKit.clipOutward(categoryBar)` after line 74. Box (−8, 30, 1/+16, 60): inside the 12 px panel padding, bottom 90 < `listTop` 92.
   - `LotManager.applyLayout` tab bar: after setting the tab bar's Position, Size and `ScrollBarThickness`, call `UiKit.clipOutward(tabBar)`. Replace `tabBar.CanvasSize = …` with `UiKit.setCanvasHeight(tabBar, canvasHeight)`.
7. **`LotManager.revealSelected`**, with `I = UiTheme.ClipInset`:
   - `top < y` → `y = top`
   - `bottom + 2*I > y + view` → `y = bottom + 2*I - view`
8. **Canvases.** Replace each `page.CanvasSize = UDim2.fromOffset(0, X)` with `UiKit.setCanvasHeight(page, X)`, keeping the same expression X:
   - `SupplierTab` 389
   - `PricingTab` 186
   - `EmployeesTab` 236
   - `LandTab` 231 and 268
   
   In `SupplierTab` lines 354, 355 and 419, use `UiKit.contentWidth(page)` instead of `page.AbsoluteSize.X`.
9. **Probe kind `stroke`** (in `probeGui`, a second loop over all descendants, after the text loop):
   - **Candidates:** visible (`not isHidden`, size > 0) `GuiObject` `g` with a child `UIStroke` (`Enabled`, `Border`, `Thickness > 0`, `Transparency < 1`) or a `UIScale` named `"Press"`.
   - **Grown box:** unscaled size (`AbsoluteSize / Press.Scale`) grown on every side by stroke thickness (or 0) + `UiStyle.hoverGrowth(w, h)` if `g` is an `isInteractive` `GuiButton`.
   - **Clipper:** nearest ancestor below the gui with `ClipsDescendants` or a `ScrollingFrame`; none → skip.
   - **ScrollingFrame clipper:**
     - x must lie in `[pos.X, pos.X + AbsoluteWindowSize.X − bar]`, where `bar = ScrollBarThickness` when `AbsoluteCanvasSize.Y > AbsoluteWindowSize.Y`, else 0.
     - y uses canvas coordinates `cy = y − pos.Y + CanvasPosition.Y`. It needs `cy ≥ 0` and `cy + h ≤ math.max(AbsoluteCanvasSize.Y, AbsoluteWindowSize.Y)`.
     - So rows scrolled partly out of view pass when the canvas holds them whole.
   - **Other clipper:** use `UiTheme.contains(clipBox, grown, 0)`.
   - **Problem text:** `"<path> stroke <grown> in <outer>"` (`probeNumbers`, 30 cap).
   - **Return:** add `strokeChecked = n`; other kinds and fields unchanged.
10. **`docs/UI_STYLE.md`:** line "Clip rule: `UiTheme.ClipInset` (8 px) as `ClipInset` UIPadding on every list, page and clipping bar (`UiKit.clipInset`/`clipOutward`), right + scroll bar; hover growth ≤ 3 px."
11. **`docs/PROGRESS.md`:** probe returns per window, hover readings, smoke, screenshot status.

## Tests (headless)
| File | Test name | Asserts |
|---|---|---|
| UiStyle_Test | caps hover growth | For w,h in {(44,44),(56,44),(140,44),(300,44),(2000,48)}: `hoverGrowth ≤ hoverGrowMax + 1e-9`; `cappedScale(0.95,…) == 0.95`; `cappedScale(1.05,44,44) == 1.05` |
| UiTheme_Test | clip inset covers every stroke and hover growth | `ClipInset ≥ math.max(StrokeControl, StrokeSelected, StrokeCard) + hoverGrowMax + 2`; `ClipInset == 8` |
| UiTheme_Test | clipPadding and clipBox | `clipPadding(6)` = 8,14,8,8; `clipBox({x=0,y=52,w=168,h=564})` = (−8,44,184,580) |
| UiTheme_Test | Lot Manager layouts fit the clip-padded page | MATRIX and PHONES: `w = body.w − 2*ClipInset − 6`; the existing supplier panel/row and phone assertions at `w` (MinTouch, no overlap, inside `panel.width`, compact `row.text.w ≥ 240`, `324 ≤ w − 8`) |
| UiTheme_Test | tab bar clip box stays in the manager | MATRIX, non-compact: `clipBox(tabBar)` inside (−padding, −padding, cw+2·padding, ch+2·padding) and `clip.x+clip.w ≤ body.x`; compact: every tab `w ≤ tabBar.w − 4` |

Existing tests, phone baselines and 22a3c desktop boxes pass unchanged; 814 → 819.

## Playtest (Studio, desktop Play solo, client ≥ 1280x720; `H = LocalPlayer.StudioUiHook`)
1. Smoke run PASS, with a save running.
2. Lot Manager: for each of the 6 tabs, run `H:Invoke("probe","ChristmasMarketUI")`. Expect:
   - `problems` empty
   - `strokeChecked > 0`
   - Supplier tab: also in the sell view, and with `Page_Supplier.CanvasPosition` at the bottom (`AbsoluteCanvasSize.Y − AbsoluteWindowSize.Y`); 0 problems in both.
3. Hover: `H:Invoke("interact", path, "hover")` on `…/TabBar/Tab_Supplier`, on the `MAX` button of the first and last Supplier rows, and on the recommend button. Wait 0.3 s, probe again: 0 problems. Then send `"idle"` to each.
4. Shop, Quests, Saves (Picker, DeleteConfirm), Team, Teammates (Finder), Advent, Event shop, PlotPicker: open each alone, `probe("")` → 0 problems. Not openable by the hook: BLOCKED with reason, never PASS.
5. Screenshots: Supplier view before (owner image) and after; a black Play capture (known) is recorded as "capture black", steps 2–4 numbers are the evidence.

Any probe problem = FAIL; the planner amends (no new ticket).

## Acceptance
- `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (819/819), `rojo build`.
- (a) one token, one helper pair, no per-file numbers; (b) canvas helper, bar in the padding; (c) probe `stroke`; (d) steps 1–5 in PROGRESS; (e) +5 tests.

## Out of scope
Phone/tablet readings (CM2-UIP, PC-14); the phone rail stroke; layout-function boxes, fonts, colours, strings; `VerticalScrollBarInset`; world and billboard UI.

## Amendment 1 (2026-11-28, implementer stop)
- Test "Lot Manager layouts fit the clip-padded page": replace the compact `324 ≤ w − 8` with **`324 ≤ w`** (option a). At 667x317, body.w 348 gives w 326. PricingTab places its column and cards at content x 0 with the fixed `COLUMN_WIDTH` 324 and no Supplier-style −8. Their stroke and capped hover growth (≤ 6 px) fall inside the `ClipInset` padding (8 left, 8 + 6 right), so 2 px spare is enough. `COLUMN_WIDTH` stays unchanged.
- Expected headless count: HEAD runs 815, so **815 → 820** (still +5 tests). Read "814 → 819" and "819/819" above as 820.

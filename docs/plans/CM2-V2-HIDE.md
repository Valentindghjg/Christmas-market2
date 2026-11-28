# CM2-V2-HIDE — fix: the scrolling desktop rail (RC4 regression)

Written by `planner` after CM2-RC4. All decided; anything missing: stop and report.

## Goal
With "Hide HUD" in the rail, every rail button fits the rail, the HUD probe shows 0 problems (shown and hidden), and the button can be clicked.

## Source of truth
Backlog 43 CM2-V2-HIDE (a)-(e) (unchanged behaviour); `docs/plans/CM2-UIFIX.md` (RailInset 6, railLeft 18); `docs/plans/CM2-UICLIP.md` (probe scroll rule); archived DECISION_LOG CM2-40: the rail top `max(m, floor(H*0.3))` clears the chat window and stays.

Cause (RC4 readings; Studio GUI area 1564x554, rail 12,166 148x376 = railMaxHeight):
- The inset was not lost: `13 = 18 - 5` is the button x minus stroke 2 and hover growth 3.
- 8 visible buttons need 8*44 + 7*6 + 12 = 406 px > 376, so the rail scrolls. Before HIDE, 7 buttons needed 356 px and it did not.
- Scrolling shows the 4 px bar. Buttons reach x 142 local, grown 147 > 148 - 4 → 8 `stroke` problems.
- `AutomaticCanvasSize` ends the canvas at the last button, with no bottom inset.
- `probeRail` ignores scrolling, so the button below the fold gives 1 `railstroke` problem.

## Implementer tier
Tier: S. Reason: client layout math, one probe rule, tests; no server, save, remote or string change.

## Skill checks
- gui: a Border `UIStroke` and the hover growth are drawn outside the box and cut by a clipping `ScrollingFrame`; leave room for the scroll bar while it shows.
- gui: measure with `AbsolutePosition`/`AbsoluteWindowSize`/`AbsoluteCanvasSize`/`CanvasPosition`; a button scrolled partly out of view passes when the canvas holds it whole.
- gui: desktop readings here; phone readings stay with CM2-UIP (PC-14); phone layout tests must still pass.

## Files
| File | Change | Purpose |
|---|---|---|
| `src/shared/UiTheme.lua` | Change | width, `railCanvas`, bar token |
| `src/client/UiKit.lua` | Change | rail canvas, probe scroll rule |
| `tests/studio/Cases/UiTheme_Test.lua` | Change | 9-button tests |

## Data and config
| Key | Value |
|---|---|
| `UiTheme.RailScrollBar` | `4` (px). The rail's `ScrollBarThickness`; UiKit reads it instead of the literal 4 |
| `HudLayout.railCanvas: number` | new field, rail canvas height in px |
| Rail top, inset, height, gap, slot 90 | unchanged |

## Steps
1. **`UiTheme.hudLayout`**
   - Compute `railScrolls` before the button loop.
   - Button width: `cell - inset - (if railScrolls and not m.compact then inset else 0)`. So the desktop width is 136 without scrolling and 130 with it.
   - x and y stay as they are: x = inset (6 desktop, 0 phone).
   - Add `railCanvas = if railScrolls then content + 2 * inset else rail.h`. The phone overflow branch sets `railScrolls = false`, so it gets `rail.h`.
   - Add `railCanvas` to the `HudLayout` type and to the returned table.
2. **`UiKit.ensureRail`**: `frame.ScrollBarThickness = UiTheme.RailScrollBar`; `frame.AutomaticCanvasSize = Enum.AutomaticSize.None`.
3. **`UiKit.applyRail`**, after `ScrollingEnabled`:
   - `frame.CanvasSize = UDim2.fromOffset(0, layout.railCanvas)`.
   - `if not layout.railScrolls then frame.CanvasPosition = Vector2.zero end`.
4. **Probe scroll rule in UiKit**
   - Add `local function fitsScroll(clipper: ScrollingFrame, outer: UiTheme.Box, grown: UiTheme.Box): boolean`. It holds the exact `fits` body of the `ScrollingFrame` branch in `probeGui` (bar only while the canvas is taller than the window; canvas-y rule).
   - `probeGui` calls it.
   - `probeRail` uses `fitsScroll(rail, railBox, grown)` when `rail:IsA("ScrollingFrame")`. Otherwise it keeps `UiTheme.contains(railBox, grown, 0)`.
   - Problem text, `railLeft` and the return shape stay as they are.
5. No change to `setHudHidden`, `UiController`, `HudHideGuis` or strings.

## Tests (headless)
| Test case file | Test name | Asserts |
|---|---|---|
| UiTheme_Test | keeps desktop rail buttons and strokes inside the rail (update) | Counts `1..9`. In the scrolling branch: grown x within `[rail.x, rail.x + rail.w - UiTheme.RailScrollBar]`, and canvas y `grown.y - rail.y` within `[0, layout.railCanvas]` |
| UiTheme_Test | lays out nine rail buttons on desktop (new) | At 1564x554: `rail` = 12,166,148,376; `railScrolls`; every `b.x == 6` and `b.w == 130`; `railCanvas == 456`; last `b.y + 44 + 6 == 456`. At 1920x1022 and 1024x710: no scroll, `b.w == 136`, `railCanvas == rail.h == 456`. At 1564x554 with 1 button: no scroll, `railCanvas == rail.h == 56` |
| UiTheme_Test | keeps nine phone rail buttons reachable (new) | For each `PHONES` size and count 9: every button has `h == 44` and `x >= 0`. If `railScrolls`: `x + w <= rail.w - UiTheme.RailScrollBar` and `y + h <= railCanvas`, and `railCanvas == 9*44 + 8*railGap`. Else every button lies inside `rail` |

Existing rail, baseline and thumbstick tests pass unchanged.

## Playtest (Studio, via playtester)
Desktop, run inside CM2-RC4 after the smoke run:
1. Company ready, HUD shown → `probe("")`: `problems` = 0 and `railLeft` = 18. Record the viewport and whether `HudRailUI/Rail` scrolls.
2. If it scrolls, set `Rail.CanvasPosition` to the bottom. Click the center of `HideHudButton` (from `AbsolutePosition` + `AbsoluteSize`/2). The HUD hides: 9/9 `HudHideGuis` off, only "Show HUD" in the rail, `CanvasPosition.Y == 0`, `probe("")` = 0 problems.
3. Click "Show HUD" → 8 or more buttons return, text "Hide HUD", `probe("")` = 0 problems, `railLeft` = 18. Key U toggles twice with the same readings.
4. An MCP click that does not land is BLOCKED (record coordinates and button box), never PASS.

## Acceptance
- `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` with 2 more tests than the run before (834 + 2 if none were added), `rojo build`.
- Studio steps 1-3 PASS and recorded in PROGRESS under "CM2-RC4"; HIDE's backlog (a)-(e) still hold.

## Out of scope
Rail top and chat clearance; phone stroke clipping and readings (CM2-UIP); slot order; SNOW quality switching (BLOCKED in Studio; the live rate at Automatic plus the headless `snowRate` tests are accepted, no change).

## Amendment 1 (playtest at 924x612, rail 12,166 148x376, canvas 406, scrolled 30)
Cause: `AbsoluteWindowSize.X` already leaves out the shown bar (152 = 156 - 4 here), and `fitsScroll` subtracts the bar a second time. Each grown box ends at x 153: it fails 152 but fits 156. The vertical rule is fine: canvas y runs 1..405 against a canvas of 406. The `railstroke` problem after showing again comes from the same rule, on a hovered button: 133 px wide plus 2 + 2 = 137, ending at x 153.

| Step | Exact change |
|---|---|
| A1.1 | `UiTheme.fitsScroll(outer: Box, grown: Box, bar: number, scrollY: number, canvasHeight: number): boolean`, pure: `grown.x >= outer.x and grown.x + grown.w <= outer.x + outer.w - bar and canvasY >= 0 and canvasY + grown.h <= canvasHeight` with `canvasY = grown.y - outer.y + scrollY` |
| A1.2 | The local `fitsScroll` in UiKit stays as the wrapper. It computes `bar` as now, `scrollY = clipper.CanvasPosition.Y` and `canvasHeight = max(AbsoluteCanvasSize.Y, AbsoluteWindowSize.Y)`, then returns `UiTheme.fitsScroll(outer, grown, bar, scrollY, canvasHeight)`. `outer` stays `localBox(clipper, gui)` (AbsoluteSize). No other change |
| A1.3 | UiTheme_Test, new test "fits scrolled rail strokes clear of the bar". Outer 12,166 148x376, bar 4, scrollY 30, canvas 406: box 13,137 140x54 → true; 13,487 140x54 → true; 13,137 144x54 → false; 13,135 140x54 → false (canvas y -1); 13,490 140x54 → false (canvas bottom 408 > 406; y 136 and 488 both still fit). With bar 0: 13,137 147x54 → true |

Tests: 848 (one more). Playtest steps 1-3 unchanged.

### Smoke failures 03, 07, 13: stale save state, not regressions
- Since `ccdcc62`, only `src/client/UiKit.lua` and `src/shared/UiTheme.lua` have changed. No server code changed.
- 03: the earlier RC4 tester's manual orders filled every bay on R's save "Playtest A". PREFLIGHT never touches R's bays, so it requires `baysUsed < bayCount` and fails.
- 07 and 13 are knock-on failures. In smoke mode, 06 and 12 are not selected, so `needMet` treats them as met. 07 then ran with `orderBays[R]` nil because 04 was skipped. `Stock.Place` without `bay` fails `hasExactKeys` with `UnexpectedField`, which is the correct server answer. 13 ran with `orderA` nil, which gives the `expiresAt` error.
- Reset before the next run (playtester, Play mode, server context, after R joins and before `runPlaytest`):
  1. `hook = ServerStorage.StudioTestHook` and `uid` = R's UserId.
  2. `hook:Invoke("snapshot", uid)`. If `receiving.baysUsed == receiving.bayCount`, then for every `data.stock` key `"<species>:<size>"` with count > 0, call `hook:Invoke("act", {userId = uid, action = "Supplier.SellBack", payload = {speciesId, sizeId, quantity}, requestId = "reset_" .. GUID})` in chunks of at most `GameConfig.MaxOrderQuantity`.
  3. Re-read the snapshot. Expect `baysUsed == 0`. Then run the smoke run.
- If 03 passes after this reset and 07 or 13 still fails, that is a real failure: record it and report it to the planner.
- The runner stays as it is (a PREFLIGHT drain of R would hide this state).

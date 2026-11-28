# CM2-UIFIX — Nothing cut off, readable headings

Written by `planner` (Opus 5.5); pipeline `cm2-task`. Everything is decided; anything missing: stop and report.

## Goal
The rail buttons keep a visible margin and full outline, the plot label sits clear of the pills and reads "Plot 1", and every heading reads cleanly. A Studio probe measures all of it.

## Source of truth
Backlog CM2-UIFIX (a)–(e); DECISION_LOG 2026-11-28 (a); `docs/UI_STYLE.md`. Owner screenshots 2026-11-28 (1564x730 client) show the following:
- Rail buttons start 12 px in, but the rail `ScrollingFrame` clips their 2 px `Border` stroke and the 1.05 hover scale at x 0, so they look cut off at the edge.
- `SaveStatus` sits 4 px under the chips, in cream text with a 1.5 px dark outline, and reads "Plot Plot_01".
- `UiKit.label` gives every Title-size label (22) a `TitleOutline` stroke (Outline 22,48,34) around DarkText (30,48,35). On cream the stroke fills the letters ("Land").

## Implementer tier
Tier: M. Reason: client UI only, but it touches the shared layout math, the HUD, the kit and a new Studio probe at once. No save, money or remote change.

## Skill checks
- gui: interactive UI stays inside `CoreUISafeInsets` and is placed from measured `AbsolutePosition`/`AbsoluteSize`. Leave room for `UIStroke` (Border strokes draw outside the box and are clipped by a clipping ancestor).
- gui: use `TextScaled` only with a bounding `UITextSizeConstraint`. Truncation must be deliberate. Check `TextFits` against the real text.
- gui: check every pair that shows together (chips, status, rail, Lot Manager) at desktop size; phone readings stay with CM2-UIP.
- localization: player text only through `Localization` keys, and the keys stay unchanged. Save names and usernames keep `AutoLocalize = false` (the existing `status.AutoLocalize = not ready`).
- collaboration-mode: low-risk UI change. Prove each acceptance line with a measured value; never claim a reading that was not taken.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/UiTheme.lua` | Change | `RailInset`, `Heading`, status box, `plotNumber`, `contains` |
| `src/client/UiKit.lua` | Change | no outline on headings; probe action in the Studio hook |
| `src/client/UiController.client.lua` | Change | status plate, plot number |
| `tests/studio/Cases/UiTheme_Test.lua` | Change | 1 updated, 5 new tests |
| `docs/UI_STYLE.md` | Change | heading, rail inset, status plate lines |
| `docs/PROGRESS.md` | Change | entry with the probe readings |

## Data and config (all PROVISIONAL look values)
| Key | Value |
|---|---|
| `UiTheme.RailInset` | `6` (px). Desktop only (`not m.compact`); phones keep 0 |
| `UiTheme.Heading` | `{ role = "Title", textSize = UiTheme.TextSize.Title, stroke = 0 }` (Nunito Heavy 22, no stroke) |
| `STATUS_TOP` | 40 → `44` (CHIP_HEIGHT 36 + GAP 8) |
| `STATUS_HEIGHT` | 34 → `30` (bottom stays at HUD_HEIGHT 74) |
| Safe inset token | `Metrics.margin` (desktop 12, compact 8). A desktop rail button's left edge = margin + RailInset = 18 |

## Steps
1. **`UiTheme.hudLayout`, desktop rail.**
   - Let `inset = if m.compact then 0 else UiTheme.RailInset`.
   - Regular (non-compact) path:
     - button `i` = `box(inset, inset + (i-1)*step, cell - inset, BUTTON_HEIGHT)`
     - `rail = box(m.margin, m.railTop, m.railWidth, math.min(content + 2*inset, m.railMaxHeight))`
     - `railScrolls = content + 2*inset > m.railMaxHeight`
   - Compact path (including the CM2-UVF13 overflow block): byte-for-byte unchanged.
2. **Status box.** Use the new `STATUS_TOP`/`STATUS_HEIGHT` values from the config table.
3. **`UiTheme.Heading`.** Add the token next to `UiTheme.Style`.
4. **`UiTheme.plotNumber(plotId: unknown): string`.**
   - `"Plot_01"` → `"1"` (match `^Plot_(%d+)$`, then `tostring(tonumber(digits))`).
   - `nil` → `"?"`.
   - Anything else → `tostring(plotId)`.
5. **`UiTheme.contains(outer: Box, inner: Box, tolerance: number): boolean`.** True when every edge of `inner` lies within `outer` grown by `tolerance` on each side.
6. **`UiKit.label`.**
   - Title branch (`textSize >= UiTheme.Heading.textSize`): set `FontFace = UiTheme.fontFace(UiTheme.Heading.role)` and remove the `UiKit.outlineText(value)` call.
   - Keep `UiKit.outlineText` (no caller left). `headerBand`, sizes and other fonts unchanged.
7. **`UiController`, status plate.** Replace the `status.TextWrapped/TextColor3/outlineText` lines with:
   - `TextXAlignment = Center`, `TextWrapped = true`, `TextScaled = true`, `TextColor3 = UiKit.Colors.DarkText`
   - `BackgroundColor3 = UiKit.Colors.Panel`, `BackgroundTransparency = 0.1`, `UiKit.card(status)`
   - a child `UITextSizeConstraint` named `StatusSize` (Max 13, Min 10)
   - a child `UIPadding` named `StatusInset` (Left/Right 8, Top/Bottom 2)
   
   In the three `hudSaveStatus*` calls, replace `tostring(player:GetAttribute("PlotId"))` / `plotId` with `UiTheme.plotNumber(player:GetAttribute("PlotId"))`. The Localization keys and strings stay unchanged. EN becomes "Tree Lot 264 · Plot 1", DE "… · Grundstück 1".
8. **Studio probe.** In `UiKit.studioHook`, handle `action == "probe"` first, before `resolve`/`GuiObject` checks; `path` is a ScreenGui name or `""` for all.
   - **Scan:** every enabled ScreenGui under `PlayerGui` whose name matches (Roblox core guis are not under PlayerGui). In each, take every descendant `TextLabel`/`TextButton` that is not `isHidden`, has `Text ~= ""`, `TextTransparency < 1` and `AbsoluteSize` > 0 on both axes. Boxes are in gui-local px (`AbsolutePosition - gui.AbsolutePosition`).
   - **Problems (one string each, `"<path below PlayerGui> <kind> <numbers>"`, at most 30):**

     | Kind | Rule |
     |---|---|
     | `fit` | The text does not fit. It fits if `TextFits` is true, or if `TextBounds` ≤ the content size (`AbsoluteSize` minus the `UIPadding` offsets) + 1 on both axes. |
     | `clip` | The item is not inside its nearest clipping ancestor (`ClipsDescendants` true or a `ScrollingFrame`), checked with `UiTheme.contains(…, 1)`. For a `ScrollingFrame` ancestor, only the x extent counts. |
     | `screen` | The item has no `ScrollingFrame` ancestor and is not inside the gui box (tolerance 1). |
     | `outline` | The item has a `UIStroke` child with `ApplyStrokeMode` Contextual and `Thickness > 0`. |
     | `railstroke` | A visible rail button grown by its `Outline` stroke thickness is not inside the `HudRailUI/Rail` box (tolerance 0). |

   - **Return:** `{ ok = true, checked = n, problems = {…}, railLeft = <min rail button x>, statusTop = <SaveStatus y>, chipsBottom = <max chip y+h>, viewport = {w, h} }`.

   Deviation from (d): a client hook action the playtester invokes, not a runner step (the server runner cannot see client-built GUIs; same pattern as step 70's "Client readings").
9. **`docs/UI_STYLE.md`.**
   - Add a line for headings: `UiTheme.Heading`, Heavy 22, no stroke on panels.
   - Change "Title 1.5" to "Title 1.5 (`outlineText` only, no current caller)".
   - Add: rail inset 6 px on desktop.
   - Add: the status line is a Panel plate under the chips (8 px gap).
10. **`docs/PROGRESS.md`:** entry with probe returns, playtest result, screenshot status.

## Tests (headless, `UiTheme_Test`)
| Test name | Asserts |
|---|---|
| keeps the regular rail as one column (update) | `b.x == 6`, `b.y == 6 + (i-1)*(44+gap)`, `b.w == m.railWidth - 12`, `rail.h == count*44 + (count-1)*gap + 12` at 1920x1022 and 1024x710 |
| keeps desktop rail buttons and strokes inside the rail (new) | For each non-compact MATRIX size and counts 1..8: `rail.x + b.x >= m.margin + UiTheme.RailInset`. When not scrolling, `contains(rail, absolute(b) grown by StrokeControl + ceil(0.025*b.w), 0)` (amendment 1); when scrolling, only the x extent counts |
| puts the save status below the chips (new) | For each MATRIX size: `status.y >= 36 + 8`, status inside the hud and not overlapping any chip |
| one heading style without outline (new) | `Heading.stroke == 0`, `Heading.textSize == TextSize.Title`, `Fonts.Weights[Heading.role] ~= nil` |
| plotNumber (new) | `"Plot_01"`→`"1"`, `"Plot_12"`→`"12"`, `nil`→`"?"`, `"X"`→`"X"` |
| contains (new) | Inside, touching, off by 1 with tolerance 1 (true) and off by 2 (false) |

The phone baselines and the CM2-UVF13 assertions must pass unchanged.

## Playtest (Studio, desktop, Play solo, client at least 1280x720)
Call `H = game.Players.LocalPlayer.StudioUiHook` in the Client data model.
1. Smoke run (`runPlaytest {mode="smoke"}`) PASS, with a save running.
2. `H:Invoke("probe","")` on the HUD with no window open. Expect:
   - `problems` empty
   - `railLeft >= 18`
   - `statusTop >= chipsBottom + 8`
   - `ChristmasMarketUI/Hud/SaveStatus.Text` ends with "· Plot <n>" (n = plot number, no "Plot_")
3. Press `HudRailUI/Rail/LotManagerButton`, then press each `ChristmasMarketUI/LotManager/TabBar/Tab_<id>` for the 6 tabs, running `probe("ChristmasMarketUI")` after each one. Expect `problems` empty, and that the `LandTitle`, `EmployeesTitle` and `PricingTitle` labels have no `TitleOutline` child.
4. Press `ShopButton`, `QuestsButton`, `SavesButton` and `TeamButton` in turn (close the previous window each time), running `probe("")` after each. Expect `problems` empty.
5. Screenshots: the 4 owner views, before (owner set) and after. Play captures are black (known), so record "capture black" instead and rely on the numbers from steps 2–4 as the evidence.

A probe problem steps 1–8 do not fix = FAIL; the planner amends this plan (no new ticket).

## Acceptance
- `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (current count + 5, e.g. 796 → 801, all passing), `rojo build`.
- Backlog (a)–(d) are met by the steps and readings above. (e): smoke plus the probe at desktop size are recorded in PROGRESS. Phone and tablet readings join the CM2-UIP queue.

## Out of scope
- The phone rail stroke clip and the phone/tablet readings (CM2-UIP, PC-14).
- Font family, colour and size changes.
- World and billboard labels.
- `headerBand` changes.
- Text inside dialogs that already scroll vertically.

## Amendment 1 (2026-11-28, implementer stop)
The rail check used `StrokeSelected` (3): 3 + ceil(0.025*136) = 7 > RailInset 6, so the test failed by arithmetic. Decision: grow by `UiTheme.Style.StrokeControl` (2). 2 + 4 = 6 then fits exactly on all four sides: left 6-6 = 0, right 142+6 = 148 = `rail.w`, bottom = `content + 12` = `rail.h`. `RailInset` stays 6, the button width stays `cell - inset` (136) and the tolerance stays 0.
Reason: rail buttons are never selected, because `UiKit.setSelected` is only called on Lot Manager tabs (`LotManager.lua:185`). The real states of a rail button are idle, hover and press, all with the 2 px stroke. The selected-plus-hover case cannot happen. `ceil` over-counts the hover growth (3.4 px per side if it scaled about the centre), so the real UI keeps at least 0.6 px to spare.
Guard: rail buttons must not call `setSelected`. If a later task selects a rail button, it raises `RailInset` to 7 and sets the button width to `railWidth - 2*RailInset` (134).

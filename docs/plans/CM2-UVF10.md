# CM2-UVF10 — Phone: stocking bar and tutorial hint bar apart, reason text fits

Written by: `planner` (Opus 5.5, medium). Implemented by: `implementer` (tier S). Playtested by: `playtester`. Reviewed and committed by: `reviewer`. Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
On a phone, with the tutorial running and stocking mode open, the tutorial hint bar and the stocking bar no longer overlap, Skip stays tappable, and every stocking header and reason text is shown in full. PC and tablet look exactly as before.

## Source of truth
- Backlog line 5j (CM2-UVF10); PROGRESS entry "N1 (a)(b) device block" 2026-11-24 (i4 FAIL, commit 68394f0).
- Measured at iPhone 7: safe area 666x316 (viewport 666x374 minus the 58 px top inset). Today: `HintBar` 140..526 x 142..198, `StockingBar` 199..532 x 154..308, `HUD` 216..658 x 8..82, toast row 140..526 x 90..134, rail 8..132 x 8..212.
- CM2-G14 rule (UiTheme test): the compact stocking bar stays inside x 0.3w..0.8w (clear of the thumbstick zone and the jump button) and clear of the HUD and toast. It also has to fit the 780x302 phone, so the compact bar cannot get taller than 154 px.
- Text rule: CM2-UVF4 (wrap instead of truncating; probe H4b flags any shown text with `TextFits == false`).

## Implementer tier
Tier: S. Reason: client layout values, one new string key and layout tests in existing patterns. No server, save, money, inventory or remote change.

## Skills to load
roblox-collaboration-mode, roblox-gui, roblox-input, roblox-localization, roblox-luau-core, roblox-tooling.

## Decisions
| # | Decision |
|---|---|
| D1 | While stocking mode is open on a compact screen, the tutorial bar is **docked**: it shows only the Skip button, top-right below the HUD. Frame `x = w - margin - (skipWidth + 2*padding)`, `y = margin + HUD_HEIGHT + GAP` (= 90), size 116x56. At 666x316 that is 542..658 x 90..146: clear of the HUD (ends at y 82), the toast (ends at x 526), the stocking bar (ends at x 532 and starts at y 154), the rail, and the jump button (default top at about y 226). |
| D2 | The hint text is hidden while docked (`HintText.Visible = false`). The stocking bar's reason line already tells the player what to do ("Tap the ground to move the tree, then press Place."). If the bar has no Skip button to show while docked (the "Done" message), it stays hidden. The Skip-failed text is not shown while docked; the next tap tries again. |
| D3 | Not docked (stocking closed, or not compact) means exactly today's layout. On regular screens, `docked = true` returns the same layout as `docked = false`. |
| D4 | The compact stocking bar keeps its frame (154 px high, x 0.3w, w 0.5w, bottom at `h - margin`). Inside it: header `(8, 4, w-16, 18)`, reason `(8, 24, w-16, 32)` (two lines at TextSize Small 13), top control row at y 58, bottom row at y 106 (bottom edge 150, 4 px padding). The regular single-row layout and the regular-screen two-row layout keep today's values. |
| D5 | Reason label: `TextWrapped = true`, `TextTruncate = None`, vertical alignment unchanged (Center). On PC the text fits one line, so nothing changes there. |
| D6 | On compact screens the header uses the new key `stockingHeaderCompact` (en `"%s · S %d · M %d · L %d"`, de `"%s · K %d · M %d · G %d"`). The longest case, "Douglas Fir · S 12 · M 12 · L 12", fits 317 px at TextSize 15. Regular screens keep `stockingHeader`. |
| D7 | `BreakAreaMode` uses the same layout. On phones its bar becomes 6 px taller (its buttons follow `controls.Size.y` = 58). This is accepted; there is no code change in `BreakAreaMode.lua`. |

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/UiTheme.lua` | Change | D1, D3, D4: `tutorialBarLayout` docked variant, `showText` field, compact stocking values |
| `src/client/Tutorial.client.lua` | Change | D1, D2: layout re-applied when docking changes |
| `src/client/StockingMode.client.lua` | Change | D5, D6: reason wrap, compact header key |
| `src/shared/Localization.lua` | Change | D6: `stockingHeaderCompact` en and de |
| `tests/studio/Cases/UiTheme_Test.lua` | Change | 2 new tests |
| `tests/studio/Cases/Localization_Test.lua` | Change | 1 new test |

## Steps
1. **UiTheme.lua**
   - Type `TutorialBarLayout` gains `showText: boolean`.
   - New signature: `function UiTheme.tutorialBarLayout(m: Metrics, docked: boolean?): TutorialBarLayout`. If `docked == true and m.compact`, set `w = config.skipWidth + 2 * p` and return `frame = box(m.width - m.margin - w, m.margin + HUD_HEIGHT + GAP, w, config.height)`, `text = box(p, p, 0, BUTTON_HEIGHT)`, `skip = box(p, p, config.skipWidth, BUTTON_HEIGHT)`, `showText = false`. Otherwise return today's boxes with `showText = true`. Update the comment above the function to name CM2-UVF10.
   - `stockingBarLayout`, in the two-row branch only: if `m.compact`, rows go at y 58 and 106, `header = clampedBox(8, 4, w - 16, 18)`, `reason = clampedBox(8, 24, w - 16, 32)`. If not compact, keep rows 52 and 102, header `(8, 8, w-16, 20)` and reason `(8, 30, w-16, 16)`. Frame unchanged (`h 154`). Update the comment above `STOCKING_GAP` with one sentence about the compact two-line reason (CM2-UVF10).
2. **Tutorial.client.lua**
   - Add the locals `currentMetrics: UiTheme.Metrics? = nil`, `docked = false` and `textShown = true`.
   - Add `applyLayout()`. It returns if `currentMetrics` is nil. Otherwise it gets `layout = UiTheme.tutorialBarLayout(currentMetrics, docked)`, places the bar, the text and Skip as today, then sets `textShown = layout.showText` and `hintText.Visible = layout.showText`.
   - The `UiKit.onLayout` callback becomes `currentMetrics = m; applyLayout()`.
   - Add `setDocked(value: boolean)`, which calls `applyLayout()` only when the value changes.
   - In `refresh()`, right after the `CompanyReady`/`baseLayerOpen` check and before the `doneUntil` block, call `setDocked(UiKit.heldModal() == "Stocking")`.
   - In `showBar`, after the `text == nil` check: `if not textShown and not withSkip then bar.Visible = false return end` (D2).
3. **StockingMode.client.lua**
   - Session type: add `compact: boolean`, initialised to `false` in `start`.
   - In `buildBar`, after creating `reason`: `reason.TextWrapped = true` and `reason.TextTruncate = Enum.TextTruncate.None`.
   - In the `onLayout` callback, first line: `current.compact = m.compact`.
   - In `render`: the header key is `if current.compact then "stockingHeaderCompact" else "stockingHeader"`, with the same arguments. `render` already runs every frame, so a size change shows up on the next frame.
4. **Localization.lua**: add `stockingHeaderCompact` right after `stockingHeader` in en and in de, with the D6 values.

## Tests (headless)
| Test case file | Test name | Asserts |
|---|---|---|
| `UiTheme_Test.lua` | `docks the tutorial bar beside the stocking bar on phones (CM2-UVF10)` | Sizes 666x374, 667x375, 666x316, 667x317, 780x302, 750x332, 1024x768, 1022x709. For each: `d = tutorialBarLayout(m, true)`, `s = stockingBarLayout(m)`, `hud = hudLayout(m, 7)`. `d.frame` is inside w x h and does not overlap `s.frame`, `hud.hud`, `hud.toast` or `hud.rail`. Skip is >= 44x44 and inside `d.frame`'s w x h. If `m.compact`: `showText == false`, `d.frame.w == skipWidth + 2*padding`, `d.frame.x + d.frame.w == w - m.margin`. Else: `d.frame`, `d.skip` and `d.text` equal the fields of `tutorialBarLayout(m)`, and `showText == true`. `tutorialBarLayout(m).showText == true` for every size. |
| `UiTheme_Test.lua` | `compact stocking bar gives the reason two lines (CM2-UVF10)` | For 666x316, 667x317, 780x302, 750x332 and 666x374: `frame.h == 154`; `reason.h >= 2 * TextSize.Small + 4`; `header.h >= TextSize.Body + 2`; header, reason and every control do not overlap one another; `reason.y + reason.h <= controls.Size.y`; every control is inside the frame. 1920x1022: `twoRows == false`, header `h == 22`, reason `h == 18` (unchanged). 720x520: `twoRows == true`, `controls.Size.y == 52`, reason `h == 16` (unchanged). |
| `Localization_Test.lua` | `compact stocking header (CM2-UVF10)` | `format("en", "stockingHeaderCompact", "Douglas Fir", 12, 12, 12) == "Douglas Fir · S 12 · M 12 · L 12"`; de gives `"Douglas Fir · K 12 · M 12 · G 12"`. |

The existing tests stay unchanged and pass. Headless count: base + 3, so 589 with today's base of 586.

## Playtest (Studio, via playtester)
Device simulator with the PC-4 procedure (backlog "Erledigt" PC-4, including the note about `SetOrientationAsync`). Rojo sync, BUILD `cm2-uvf10`.
1. In Edit: `SetDeviceAsync` iPhone 7. Start Play and read `ViewportSize` = 666x374 ±2 px; if it differs, stop and report.
2. Setup on the test save "N1 Phone" (Solo; create it if it is missing). Use the CM2-49 step 54 helpers: `tutorialSet R Order`, `orderTrees(R.userId, 1)`, `advance(DELIVERY_WAIT)` and `awaitDelivery`. Then the `TutorialStep` attribute is "Stock". Move within prompt distance of the bay that holds trees and trigger its prompt; `StockingUI.StockingBar` is shown.
3. Read `AbsolutePosition`/`AbsoluteSize` of `TutorialUI.HintBar`, `SkipTutorial` and `StockingUI.StockingBar`. Expect HintBar 542..658 x 90..146 (±2), Skip inside it, `HintText.Visible == false`, StockingBar 199..532 x 154..308, and no pair overlapping. Also check that the HintBar does not overlap `Hud`, `Toast` or `Rail`.
4. Tap Skip once, with a touch at its centre (GUI position plus `GetGuiInset`). `SkipTutorial.Text` becomes en `tutorialSkipConfirm` ("Tap again"). Wait 4 s for it to disarm; do not confirm.
5. For each reason, tap the ground at the screen point of a lot-frame target (`Camera:WorldToViewportPoint`). Expect a red ghost and `Reason.Text` equal to the en string, with `TextFits == true`; then `probe{StockingUI, TutorialUI, HudRailUI, ChristmasMarketUI}` (H4 with the H4b text rule) is empty. Targets:
   - outside lot: 6 studs beyond the lot edge (`stockOutsideLot`);
   - keep clear: the centre of the first `GameConfig.Placement.KeepClear` box (`stockKeepClear`);
   - too close: 1 stud from a displayed tree (`stockTooClose`; if no tree is displayed, place one with Place first).
   If a tap does not produce a reason, record that reason as BLOCKED with the reading.
6. Check that `Header.Text` uses the compact format and `TextFits == true`. Take one HUD capture, `uvf10-phone-stocking`.
7. Done → the stocking bar closes and the HintBar returns to 140..526 x 142..198 with `HintText.Visible == true`. Stop Play. `StopSimulationAsync()` in Edit.
8. PC (no device, 1564x730 class viewport): repeat steps 2 and 3. Expect the single-row stocking bar and the hint bar at today's place, `HintText.Visible == true`. If the PC client viewport is 1x1, record BLOCKED and queue it.

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (589, or base + 3, all pass), `rojo build`.
- The headless tests above pass: at 666x374, 667x375 and 1024x768 (and at the phone safe areas) the tutorial frame and the stocking frame do not overlap, both are inside the viewport, and Skip is >= 44x44.
- Playtest steps 3–6 PASS at iPhone 7: no overlap, a Skip tap arms the confirm text, the probe is empty for all three reasons, and the capture is taken. Step 8 shows PC unchanged.
- Loaded skills' checks: touch targets >= 44 px, nothing in the thumbstick or jump zones, text wraps instead of truncating, both string languages updated together.

## Out of scope
The Supplier button (CM2-UVF11), Pricing cards (CM2-UVF12), FinderButton (CM2-UVF13), the BreakAreaMode reason wrap, Skip-failed feedback while docked, and the N1 rest items (iPad/1080 checks, d3, d5, test-save cleanup).

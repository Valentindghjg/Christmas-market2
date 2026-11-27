# CM2-UI3 — Phone baseline and plot-picker fix (22a3, part 1)

## Goal
Today's phone boxes become a baseline no later change may exceed; the 22a (g) plot-picker overlap is fixed and the picker capped at the phone limits. Desktop and tablet unchanged.

## Source of truth
Backlog 22a (f), (g), 22a3; PRODUCT_SPEC "Compact on phone" (owner 2026-11-25); archive plan CM2-PP (finding 780 x 281).
Scope cut (planner 2026-11-28): dialog and Lot Manager windows at 70 % x 80 % and the HUD at 20 % need client restructuring and an owner decision; they move to follow-up tasks. This plan covers 22a3 (a), (c), (d) and part of (b).

## Implementer tier
Tier: S. Reason: one pure layout function in `UiTheme` plus tests and one doc line; no client, remote, save or string change.

## Skill checks
- gui: check every pair that shows together (confirm vs panel, title, status) on every phone size; reflow, don't shrink: short confirm = one row, buttons stay 44 px.
- input: no binding or guard change. localization: no new key; `plotPickerConfirm` wraps in its 44 px box.

## Files
| File | Change |
|---|---|
| tests/studio/Cases/UiTheme_Test.lua | Steps 1, 3 |
| src/shared/UiTheme.lua | Step 2 (`plotPickerLayout` only) |
| docs/UI_STYLE.md | Step 4 |

## Data and config
`PHONES` (new local in UiTheme_Test, safe-area W x H): 667x317, 780x302, 750x332, 666x374, 780x281. Limits (PRODUCT_SPEC, OWNER DECIDED): window ≤ `math.floor(0.7 * W)` x `math.floor(0.8 * H)`; buttons 44–52 px high; body text 14–16; titles ≤ 24.

## Steps
1. **Commit 1, before any layout change**: in UiTheme_Test add `local BASELINE = { ["667x317"] = { manager = {651, 301}, ... }, ... }`: for each `PHONES` size, `{w, h}` of these boxes as the current code returns them: `manager` (`hudLayout(m, 0).manager`), `hud`, `toast`, `actionBar`, `rail6` and `rail8` (`hudLayout(m, 6/8).rail`), `stocking` (`stockingBarLayout(m).frame`), `tutorial` (`tutorialBarLayout(m, false).frame`), `tutorialDocked`, one entry per `UiTheme.Dialogs` key (`dialogLayout(m, spec).frame`), `plotPanel`, `plotConfirm`. Numbers = output of the unchanged functions (throwaway Lune script, not committed). Check 667x317: manager and dialogs 651x301, rail8 124x205, hud 442x74, stocking 333x154, plotPanel 520x176, plotConfirm 360x120. Add test "phone boxes stay within the CM2-UI3 baseline": for each size and key, current `w <= base w` and `h <= base h`. Commit with the test passing (775).
2. `UiTheme.plotPickerLayout(m)`:
   - `w = math.min(520, m.width - 2 * m.margin, if m.compact then math.floor(0.7 * m.width) else math.huge)`; `cw = math.min(360, m.width - 2 * m.margin, if m.compact then math.floor(0.7 * m.width) else math.huge)`. Panel position and children formulas unchanged.
   - `local tall = panel.y >= 120 + 2 * m.margin`.
   - Tall (as today): `confirm = box(cx, math.max(m.margin, math.floor((panel.y - 120) / 2)), cw, 120)`, `confirmText`, `yes`, `no` unchanged.
   - Short: `confirm = box(cx, math.max(m.margin, math.floor((panel.y - 64) / 2)), cw, 64)`; `confirmText = box(12, 10, cw - 224, 44)`; `yes = box(cw - 200, 10, 88, 44)`; `no = box(cw - 100, 10, 88, 44)`. `cx = math.floor((m.width - cw) / 2)` in both.
   - Comment: short screens get the one-row confirm (22a (g)). `PlotPicker.lua` places every box already; no client change.
   - Expected confirm y: 667x317 short 34 (panel 466 wide, y 133); 780x302 short 27; 750x332 tall 14; 666x374 tall 35; 780x281 short 16 (< panel y 97). PC and tablets: output unchanged.
3. Tests below.
4. `docs/UI_STYLE.md`, under Rules add one line: "Phone (PRODUCT_SPEC 'Compact on phone'): windows ≤ 70 % x 80 % of the safe area, HUD ≤ 20 %, buttons 44–52 px, body 14–16, titles ≤ 24; no phone box may exceed the CM2-UI3 baseline in `UiTheme_Test`." File stays ≤ 4 KB.

## Tests (headless; 774 → 777)
| Test case file | Test name | Asserts |
|---|---|---|
| UiTheme_Test | phone boxes stay within the CM2-UI3 baseline | Step 1 |
| UiTheme_Test | plot picker confirm clears the panel (22a (g)) | for `PHONES` and every `MATRIX` size: `confirm` overlaps neither `absolute(panel, title)` nor `absolute(panel, status)` nor `panel`; `confirm` inside the screen; `confirmText`, `yes`, `no` inside `confirm` and pairwise not overlapping; `yes`, `no` ≥ 44 x 44; 780x281 gives `confirm.h == 64`, 666x374 gives 120 |
| UiTheme_Test | phone windows, buttons and text meet the compact limits | for `PHONES`: `plotPanel` and `plotConfirm` ≤ 70 % x 80 %; heights in 44..52 for: `hudLayout(m, 8).railButtons`, every `stockingBarLayout(m).controls`, plot picker `prevButton`, `nextButton`, `back`, `choose`, `yes`, `no`, `tutorialBarLayout(m, false).skip`, `managerLayout` `close` and `tabs`; `TextSize.Body`, `Input`, `Chip` and `TutorialBar.textSize` in 14..16; `TextSize.Title`, `SaveRow.nameTextSize`, `PlotPicker.numberTextSize` ≤ 24 |
Existing "fits the plot picker on every screen" stays unchanged.

## Playtest (Studio, via playtester; desktop)
1. Smoke run.
2. Open the plot picker as in `docs/archive/plans/CM2-UI2.md` Playtest step 4 (save "UI3 Pick", Play). Press `PlotPickerUI/Panel/Choose` → `PlotPickerUI/Confirm` visible, height 120 (desktop is tall), no overlap with `Panel`; H4b probe (`docs/archive/plans/CM2-UV.md`) 0 violations. Press `No`, then `Back`; delete "UI3 Pick"; play "Playtest A".

## Acceptance
- `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (777 PASS; 775 after commit 1), `lune run tests/tools/ui_scan.luau` (0 hits), `rojo build`.
- Commit 1 holds only the baseline test (22a3 (a)).
- 22a3 (c) met headless; desktop H4b 0 and smoke PASS; `runPlaytest {mode="full"}` 74 steps at the end of the hasseln run.
- 22a3 (b) here: plot picker ≤ 70 % x 80 %, button and text limits, no box above baseline; dialogs, Lot Manager and HUD 20 % are follow-ups.
- Reviewer logs: `TextSize.Small` (13) counts as caption, not body text; supplier row text (12 on phone) goes to the Lot Manager follow-up.

## Out of scope
Dialogs, Lot Manager, HUD area, supplier text (follow-ups); phone and tablet readings (22a4).

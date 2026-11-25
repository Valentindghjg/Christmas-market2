# CM2-UVF5 — Picker rows never sit under the footer

Written by: `planner` (Opus 5.5, high). Implemented by: the tier's agent. Playtested by: `playtester`. Reviewed and committed by: `reviewer`. Pipeline: skill `cm2-task`.
Rule: everything is decided; if something is missing, the implementer stops and reports.

## Goal
With 3 or more saves on the PC picker, the list ends above the footer in a visible list area, shows 2 whole rows plus a visibly cut part of the third, and scrolling brings row 3 fully into view. The playtest also checks that a real click on a row's Play works at play start.

## Source of truth
- Backlog launch order 5f; PROGRESS "CM2-UV UI verification" row (b): list 285 px at safe area 1564x672, the third row looked like it sat under the footer.
- CM2-UVF4 (f61a3b8): `UiTheme.SaveRow.height` 136, `PickerStatus` is the first list entry; its "Out of scope" note says 2 whole 136 px rows need 280 px.
- PROGRESS CM2-UVF2 amendment entry, observation (2): a picker Play click at play start did nothing (tester used `Save.Play`).
- roblox-gui SKILL: a ScrollingFrame needs a clear canvas policy (UIListLayout + `AutomaticCanvasSize` Y, kept).

## Analysis (why, with numbers)
`UiTheme.dialogLayout` (non-compact): frame h = min(600, floor(H x 0.86)); list = `ih - 60 - 200 - 8`. At H = 672: frame 577, list 285, list bottom 8 px above the footer top. The list already clips (ScrollingFrame default), but it has no background and the footer is transparent, so a clipped row looks like it slides under the footer. Since UVF4 the rows are 136 px: row 3 starts at 288 in the canvas, so at 285 px it is not visible at all and nothing hints at more content except a 6 px scrollbar.

## Implementer tier
Tier: S. Reason: one UiTheme value change, one colour token, list styling in one client file and one layout test; no server, save, money, inventory or remote change.

## Skills to load
roblox-collaboration-mode, roblox-gui, roblox-input, roblox-luau-core, roblox-luau-patterns, roblox-luau-types, roblox-tooling.

## Decisions (settled)
| # | Decision |
|---|---|
| D1 | `UiTheme.Dialogs.Picker.heightScale` 0.86 → 0.92. At safe heights 672, 710 and 1022 the frame reaches `maxHeight` 600: list 308 px = 2 rows (280) + gap 8 + 20 px of row 3. Compact (phone) layout is unchanged (it does not use `heightScale`). |
| D2 | The list gets a visible area: `BackgroundColor3 = ListWell` (new colour, darker than Panel), `BackgroundTransparency = 0`, `ClipsDescendants = true` (explicit), `ScrollBarImageColor3 = SAND`, `ScrollBarThickness` stays 6. A cut row then ends visibly at the area's lower edge, 8 px above the footer. No UICorner and no UIPadding on the list (keeps `AutomaticCanvasSize` exact). |
| D3 | The list gap 8 becomes the token `UiTheme.SaveRow.listGap`; `SavePicker` uses it for `layout.Padding`. |
| D4 | The list keeps ending `GAP` (8) above the footer (`dialogLayout` unchanged). Footer height 200, `listTop` 60, row size and Team/Finder dialogs unchanged. |
| D5 | Play click check (playtest step 1): diagnosis only, no preemptive code change. Hypothesis to confirm or refute: the earlier tester clicked the centre of a Play button of a row that was clipped (below the list's visible edge), so the click hit nothing. A failure on a fully visible row becomes defect CM2-UVF5-D1 for a planner amendment. |
| D6 | Studio test per `cm2-task` step 3 batching (queue "Studio-Test ausstehend" is empty, so this is position 1). BUILD stays `cm2-n1-fix2`; RunPlaytest unchanged. |

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/UiTheme.lua` | Change | `Colors.ListWell`, `Dialogs.Picker.heightScale`, `SaveRow.listGap` (+ type field) |
| `src/client/SavePicker.client.lua` | Change | list area styling, gap token |
| `tests/studio/Cases/UiTheme_Test.lua` | Change | 1 test |
| `docs/DECISION_LOG.md`, `docs/TEST_PLAN.md` | Change | entry, one sentence |

No other file changes.

## Data and config (PROVISIONAL)
- `UiTheme.Colors`: add `ListWell = { 13, 50, 35 },` after `Row` (UiKit builds `UiKit.Colors.ListWell` automatically).
- `UiTheme.Dialogs.Picker.heightScale = 0.92` (other Picker fields unchanged).
- `SaveRowLayout` type: add `listGap: number,` after `stateHeight`; `UiTheme.SaveRow`: add `listGap = 8,` after `stateHeight = 16`.
No save fields, no string keys, no remote change.

## Steps
1. **UiTheme.lua**: the three changes above. Comment above `UiTheme.Dialogs`: `-- Picker heightScale 0.92 (CM2-UVF5): at 672 px safe height and above the list shows two whole save rows and part of a third.` Extend the `SaveRow` comment with: ` listGap is the space between list entries.`
2. **SavePicker.client.lua**:
   - Add `local LIST_WELL = UiKit.Colors.ListWell` after `local ROW = ...`.
   - In the `list` block: replace `list.BackgroundTransparency = 1` by `list.BackgroundTransparency = 0` and add `list.BackgroundColor3 = LIST_WELL`, `list.ClipsDescendants = true`, `list.ScrollBarImageColor3 = SAND`. Comment above the block: `-- The save list is a visible, clipping area so a cut last row shows there is more to scroll (CM2-UVF5).`
   - `layout.Padding = UDim.new(0, SAVE_ROW.listGap)`.
   - Nothing else changes (rows, footer, status, Empty label, bindDialog call).
3. **DECISION_LOG.md**: entry at the end `## 2026-11-22 — CM2-UVF5 picker list edge (engineering)`: the defect (list 285 px, transparent footer, row 3 invisible since 136 px rows); D1–D3 one bullet each; files; headless 399; result of playtest step 1 (filled by the reviewer from PROGRESS).
4. **TEST_PLAN.md** section J: append `Picker list height: \`UiTheme_Test\` picker list case (CM2-UVF5).`

## Tests (headless)
| Test case file | Test name | Asserts |
|---|---|---|
| UiTheme_Test | picker list shows two whole save rows and part of a third | For each of (1564, 672), (1024, 710), (1920, 1022): `m = UiTheme.metrics(w, h)`, `d = UiTheme.dialogLayout(m, UiTheme.Dialogs.Picker)`, `r = UiTheme.SaveRow`; `m.compact == false`; `d.list` and `d.footer` not nil; `d.list.y + d.list.h <= d.footer.y`; `d.list.h >= 2 * r.height + 2 * r.listGap + 16` (2 whole rows, gap and at least 16 px of row 3); `d.list.h < 3 * r.height + 2 * r.listGap` (row 3 is cut, so scrolling is needed). |

Place it after "save row stacks name, kind, state and buttons". The existing "fits the picker, delete confirm, Team panel and finder on every screen" must still pass (at 960x542 the picker frame is 498 px, list 206 >= `minList` 120). Headless total: **399** (398 + 1).

## Playtest (Studio, via playtester; batch run)
Helpers, D4 (GUI-space clicks: `AbsolutePosition + AbsoluteSize/2`, no `GuiService:GetGuiInset()`), D5, D7, H, `sa`, R and H4b from `docs/archive/plans/CM2-UV.md` and its H4b amendment. `L` = `SaveList` rect (`AbsolutePosition`, `AbsolutePosition + AbsoluteSize`); a point is "in L" when inside that rect; a row is "whole in L" when its top >= L top and bottom <= L bottom.
0. Edit DM: `ReplicatedStorage.Shared.UiTheme.Source` contains `ListWell` and `heightScale = 0.92`; RunPlaytest BUILD is `cm2-n1-fix2`; else all BLOCKED "Studio not synced with Rojo". Record HEAD, viewport and `SavePickerUI.AbsoluteSize`.
1. **Play click at play start.** If Play is running, stop it first (this step needs a fresh play start). `start_stop_play` true; wait for `ProfileReady == true`, then 2 s with no change of the `SaveList` children. If the picker is not shown, record "picker closed at start" and click `SavesButton`. Record per `SaveRow_`: `SaveName.Text`, Play centre, whether it is in L. Capture `uvf5-1`.
   - Target: the "Playtest A" row. If its Play centre is not in L, record "Playtest A row k hidden at start" and scroll the mouse wheel over L's centre until it is in L (max 10 notches). Read `PlayerGui:GetGuiObjectsAtPosition(x, y)` at the centre and record the first 3 names. Click it once (D4).
   - PASS: within 15 s `CompanyReady == true`, `ActiveSaveId` equals the "Playtest A" saveId from `H("saves", R)`, and `Picker.Visible == false`.
   - FAIL → defect **CM2-UVF5-D1**: record `PickerStatus.Text`, `ActiveSaveId`, `CompanyReady`, `CompanyError`, whether the Play button still has a parent, and the GetGuiObjectsAtPosition list; click the same point once more and record the result; then `sa(R, "Save.Play", {saveId = <Playtest A>})`, wait for `CompanyReady`, and continue with step 2. The planner amends this plan.
   - Record in PROGRESS whether the UVF2 observation is explained by a hidden row (the target was outside L at start) or not.
2. **Three rows.** `SavesButton`. While fewer than 3 `SaveRow_`: `sa(R, "Save.Create", {name = "UV Row " .. n, size = "Solo"})` (n = 3, 4, …); then `BackToGame`, `SavesButton`. Require `PickerStatus.Visible == false` and `SaveList.CanvasPosition.Y == 0`.
3. **List edge.** `L.bottom <= Footer.AbsolutePosition.Y`; `SaveList.ClipsDescendants == true`, `BackgroundTransparency == 0`; `SaveRow_1` and `SaveRow_2` whole in L; `SaveRow_3` top <= L bottom − 16 and bottom > L bottom (cut). Record `SaveList.AbsoluteSize.Y` (expected 308 at safe height 672). H4b{SavePickerUI} empty. Capture `uvf5-2` (row 3 visibly cut at the list area's edge, footer below).
4. **Scroll.** Mouse wheel down over L's centre until `CanvasPosition.Y` stops changing (max 10 notches) → `SaveRow_3` whole in L; capture `uvf5-3`. Wheel up until `CanvasPosition.Y == 0`.
5. **Cleanup.** Delete every "UV Row n" save (`Save.Delete {saveId, confirmName}`); the player stays on "Playtest A".
6. `runPlaytest {mode="full"}` → `mode=full steps=41 pass=41 fail=0`.
End: as CM2-UV "End" (no UV save left, player on "Playtest A", never save the place).

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (399 run, 0 failed), `rojo build default.project.json --output build.rbxlx`, `rojo build release.project.json` (0 instances named UnitTest/RunPlaytest/StudioTestService).
- Ticket (PC, 3 saves): list bottom <= `Footer.AbsolutePosition.Y`; the list clips; 2 whole rows visible; row 3 visibly cut, and scrolling brings it fully into view; captures `uvf5-2`, `uvf5-3` in PROGRESS; `runPlaytest {mode="full"}` all PASS.
- Step 1: PASS, or FAIL routed as CM2-UVF5-D1 with its diagnostics (the task is then not done until the amendment passes).
- Skills: canvas policy kept (UIListLayout + `AutomaticCanvasSize` Y); touch targets unchanged (>= 44 px); `git diff` touches only the files in "Files".

## Out of scope
Phone and tablet sizes (CM2-UV2); Team and finder lists; rows pushed down by a shown status line; `NewCode` on Solo (CM2-UVF6); any fix for the Play click before D1 is confirmed; look changes (CM2-UI).

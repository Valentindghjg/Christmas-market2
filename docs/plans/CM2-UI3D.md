# CM2-UI3D — Phone dialogs at 70 % x 80 % (22a3b)

## Goal
On phones every `UiTheme.Dialogs` window fits 70 % x 80 % of the safe area; the SavePicker, DeleteConfirm, Finder and Team contents are reflowed so their buttons still fit. Desktop and tablet unchanged.

## Source of truth
Backlog 22a3b; PRODUCT_SPEC "Compact on phone" (OWNER DECIDED 2026-11-25); `docs/plans/CM2-UI3.md` (PHONES, BASELINE); `docs/UI_STYLE.md` Rules.

## Implementer tier
Tier: M. Reason: layout maths in `UiTheme` plus reflow in five clients and a new `UiKit` helper; no remotes, saves, money or strings.

## Skill checks
- gui: check every pair that shows together on every phone size (right header vs footer row, footer vs full-width top rows, list vs footer); reflow, don't shrink: buttons stay 44 px high, ≥ 44 px wide.
- gui: layout boxes come from `UiTheme` (pure); clients only place them; regular screens restore the original UDim2s exactly.
- input: no binding or guard change. localization: no new key; long labels (`finderStart`, `saveDeleteConfirm`, `saveBack`) wrap inside 44 px buttons (`TextWrapped` already on).
- luau: optional spec fields read with `or`/`if`; no dictionary-order dependence in placement.

## Files
| File | Change |
|---|---|
| src/shared/UiTheme.lua | Steps 1–3 |
| src/client/UiKit.lua | Step 4 |
| src/client/SavePicker.client.lua | Step 5 |
| src/client/TeammateFinder.client.lua | Step 6 |
| src/client/TeamPanel.client.lua | Step 7 |
| tests/studio/Cases/UiTheme_Test.lua | Step 8 |

## Data and config (all PROVISIONAL engineering values)
`DialogSpec` gains four optional fields (type and comment in `UiTheme.lua`):
| Field | Meaning | Set on |
|---|---|---|
| `compactFooterHeight: number?` | footer height on compact (default `footerHeight`) | Finder = 148 |
| `compactContentHeight: number?` | content height on compact (default `contentHeight`) | DeleteConfirm = 194 |
| `compactHeaderInFooter: boolean?` | compact right header sits in the footer's bottom row, left 60 % | Picker = true |
| `compactTop: number?` | height of the full-width rows above both compact columns; footer starts ≥ this + 8 (tests) | Team = 30, Shop = 82, Finder = 30 |
Also `Shop.minList` and `Event.minList` 120 → 100 (comment: one 96 px product row fits on the 780x281 phone). All other values unchanged.

Expected compact frames (w x h, y centred): 667x317 → 466x253; 780x302 → 546x241; 750x332 → 525x265; 666x374 → 466x299; 780x281 → 546x224. Inner = frame − 24. At 466 wide: leftWidth 230, footer width 200.

## Steps
1. `UiTheme.dialogLayout`, compact branch only (regular branch untouched):
   - `local w = math.min(m.width - 2 * m.margin, 760, math.floor(0.7 * m.width))`; `local h = math.min(m.height - 2 * m.margin, math.floor(0.8 * m.height))`; `frame = box(math.floor((m.width - math.max(0, w)) / 2), math.floor((m.height - math.max(0, h)) / 2), w, h)`.
   - `leftWidth = math.max(0, math.min(math.floor((iw - 12) * 0.55), iw - 12 - COMPACT_FOOTER_MIN))` with new local `COMPACT_FOOTER_MIN = 200`.
   - `local footerHeight = spec.compactFooterHeight or spec.footerHeight`; footer = `box(leftWidth + 12, ih - footerHeight, iw - 12 - leftWidth, footerHeight)`; list as today.
   - `rightHeader`: if `spec.compactHeaderInFooter` then `box(footer.x, footer.y + footer.h - BUTTON_HEIGHT, math.floor(0.6 * footer.w) - 4, BUTTON_HEIGHT)`, else as today.
   - Comment: phones cap dialogs at 70 % x 80 % of the safe area (PRODUCT_SPEC "Compact on phone", 22a3b).
2. `UiTheme.finderFooterCompact(w: number): { [string]: Box }` (relative to the footer, height 148). `unit = math.floor((w - 8) / 3)`; `half = math.floor((w - 6) / 2)`:
   | Key | Box |
   |---|---|
   | `Size_Duo`, `Size_Trio`, `Size_Quad` (i = 1..3) | `(i - 1) * (unit + 4), 0, unit, 44` |
   | `StartHint`, `OwnListing` | `0, 50, w, 48` |
   | `StartListing`, `StopListing` | `0, 104, half, 44` |
   | `Close` | `half + 6, 104, w - half - 6, 44` |
3. `UiTheme.deleteConfirmRow(iw: number): { [string]: Box }` (relative to the dialog's inner area): `nameW = math.floor(iw * 0.5) - 4`; `bw = math.floor((iw - nameW - 16) / 2)`; `ConfirmName = box(0, 150, nameW, 44)`, `ConfirmDelete = box(nameW + 8, 150, bw, 44)`, `Cancel = box(nameW + 16 + bw, 150, iw - nameW - 16 - bw, 44)`. Comment: compact delete confirm puts name and buttons in one row (content 194 px).
4. `UiKit.bindCompact(gui: ScreenGui, items: { [string]: GuiObject }, boxes: (m: UiTheme.Metrics) -> { [string]: UiTheme.Box }?): RBXScriptConnection`: remembers AnchorPoint, Position, Size of every item at call time; via `UiKit.onLayout`, each layout restores every item, then if `boxes(m)` returns a table places each item whose key has a box (AnchorPoint 0,0, offsets). Reuse `bindDialog`'s place/restore by moving them to module-level locals. Comment: compact-only reflow; regular screens keep the original UDim2s.
5. SavePicker: after the two `bindDialog` calls, `UiKit.bindCompact(gui, { ConfirmName = confirmName, ConfirmDelete = confirmDelete, Cancel = confirmCancel }, function(m) return if m.compact then UiTheme.deleteConfirmRow(UiTheme.dialogLayout(m, UiTheme.Dialogs.DeleteConfirm).innerWidth) else nil end)`. The Picker footer itself is unchanged (its `FindTeammates` moves through Step 1). Update the footer comment: on phones Find teammates sits left of Back in row 4.
6. TeammateFinder: after `bindDialog`, `UiKit.bindCompact(gui, items, fn)` with `items` = the eight keys of Step 2 (`Size_<size>` from `sizeButtons`, `StartListing = startListing`, `StartHint = startHint`, `OwnListing = ownListing`, `StopListing = stopListing`, `Close = closeButton`); `fn(m)`: if not compact return nil; `local d = UiTheme.dialogLayout(m, UiTheme.Dialogs.Finder)`; return `if d.footer then UiTheme.finderFooterCompact(d.footer.w) else nil`. Update the footer comment (198 px regular, 148 px on phones: sizes, hint or own listing, Start or Stop beside Close).
7. TeamPanel: `bindDialog` parts gain `leftItems = { seatsLine, codeLine, codeHint }` (they stay full width on regular screens; on phones they take the left column so the footer can sit beside them).
8. Tests below.

## Tests (headless; 777 → 779)
| Test case file | Test name | Asserts |
|---|---|---|
| UiTheme_Test | fits the picker, delete confirm, Team panel and finder on every screen (change) | Picker compact: replace `header.y + header.h + 8 <= footer.y` with: `header.x == footer.x`, `header.y == footer.y + footer.h - 44`, `header.x + header.w + 8 <= footer.x + footer.w - (math.floor(0.4 * footer.w) - 4)`; DeleteConfirm: `innerHeight >= (if m.compact then spec.compactContentHeight else spec.contentHeight)` |
| UiTheme_Test | phone dialogs fit 70 % x 80 % of the safe area (22a3b) | for `PHONES` x every `UiTheme.Dialogs` key: frame ≤ `floor(0.7 W)` x `floor(0.8 H)`, inside the screen; if list and footer: list.h ≥ minList, both inside inner, no overlap, footer.w ≥ 200, footer.h == `compactFooterHeight or footerHeight`; `compactTop` set → `footer.y >= compactTop + 8`; rightHeader and not `compactHeaderInFooter` → `rightHeader.y + 44 + 8 <= footer.y`; Picker footer.h == 200 (four 44 px rows, gap 8) and size buttons `math.floor(0.25 * footer.w) - 6 >= 44`; Team footer `0.5 * footer.w - 4 >= 44`; DeleteConfirm innerHeight ≥ 194; 780x281 Picker frame == 546x224 |
| UiTheme_Test | compact Finder footer and delete row fit (22a3b) | for `PHONES`: `finderFooterCompact(footer.w)`: every box inside `footer.w` x 148, button heights in 44..52 and widths ≥ 44, pairwise no overlap except the pairs StartHint/OwnListing and StartListing/StopListing (exclusive); `deleteConfirmRow(innerWidth)`: three boxes inside `innerWidth` x 194, heights 44, widths ≥ 44, no overlap, all y ≥ 146 (below the 100..144 instruction) |
Existing baseline test must stay PASS (new frames are smaller). Body/title size limits stay covered by "phone windows, buttons and text meet the compact limits".

## Playtest (Studio, via playtester; desktop)
1. Smoke run.
2. As `docs/plans/CM2-UI2.md` Playtest step 2, open through `StudioUiHook`: SavePicker Picker, DeleteConfirm (press `SaveRow_1/Delete`, then `Cancel`), Finder over the SavePicker, Team, Shop, Quests, Advent, Event. Each: frame position and size equal to before (desktop regular branch), H4b probe (`docs/archive/plans/CM2-UV.md`) 0 violations; Finder `Close` and `StartListing` at their regular full-width rows.
Phone readings: 22a4 CM2-UIP (PC-14 open).

## Acceptance
- `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (779 PASS), `lune run tests/tools/ui_scan.luau` (0 hits), `rojo build`.
- 22a3b (a) headless; (b) same remotes, error codes, string keys and save fields, regular branches untouched; (c) desktop H4b 0 and smoke PASS.
- Reviewer logs: Shop/Event `minList` 100 (deviation from 120, PROVISIONAL); Picker list on phones shows one whole save row (140 px at 780x281); hint text 13 px counts as caption.

## Out of scope
Lot Manager (22a3c), HUD 20 % (22a3d), plot picker (done), phone and tablet readings (22a4), any string change.

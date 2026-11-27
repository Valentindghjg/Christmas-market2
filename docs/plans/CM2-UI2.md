# CM2-UI2 — Cream palette, header bands and style guide (22a2)

## Goal
PRODUCT_SPEC target look on every screen (cream surfaces, dark text, dark-green primary buttons and title bands, gold highlights, red close/danger), a style guide, no motion on disabled buttons; layout and behaviour unchanged.

## Source of truth
Backlog 22a2, 22a (a)–(c); PRODUCT_SPEC "UI look"; DECISION_LOG 2026-11-27 (CM2-UI1 deviations); `docs/plans/CM2-UI1.md`. No owner images → target from PRODUCT_SPEC and REFERENCE_GAME_LIVE_TEST §9.

## Implementer tier
Tier: M. Reason: palette and kit change over ~20 client files and the world labels; no money, save, remote or string-key change.

## Skill checks
- gui: one `UIStroke` per object (band adds none); layout boxes untouched; text on fill WCAG 4.5 / 3.0.
- input: disabled buttons get no hover or press motion; actions stay on `Activated`, guards unchanged.
- architecture: pure rules in shared `UiStyle`, Instances only in `UiKit`.
- localization: no string key change. patterns: hook only under `RunService:IsStudio()`.

## Files
| File | Change |
|---|---|
| src/shared/UiTheme.lua | Data and config |
| src/shared/UiStyle.lua | Step 1 |
| src/client/UiKit.lua | Step 2 |
| 17 client files, Steps 4–6 | site edits |
| src/server/Services/WorldService.lua | world text colours |
| tests/studio/Cases/UiStyle_Test.lua, UiTheme_Test.lua | tests |
| docs/UI_STYLE.md, docs/art/ui-reference/README.md (new) | docs |

## Data and config (UiTheme.Colors; PROVISIONAL look values)
| Token | Old | New | Role |
|---|---|---|---|
| Panel | 20,68,48 | 255,244,217 | windows, chips, bars |
| Row | 38,89,63 | 246,231,196 | cards, rows |
| ListWell | 13,50,35 | 236,218,178 | list wells |
| Red | 196,58,52 | 168,62,54 | close, danger |
| Disabled | 120,120,120 | 104,104,104 | disabled |
| Toast | 24,74,50 | 255,244,217 | toast surface |
| Header (new) | – | 20,68,48 | title bands |
| Primary (new) | – | 38,89,63 | primary actions |
| Muted (new) | – | 92,80,56 | was Sand text |
| GoldText (new) | – | 128,88,16 | money, highlight text |
Others unchanged. `Style.HeaderInset = 10` (px). All test pairs below pass (lowest: GoldText on ListWell 4.6, DarkText on Gold shaded 4.8).

## Steps
1. `UiStyle`:
   - `Kind` adds `"header"`; `decorations("header")` = `corner(CornerRadius.Button)`, `shade()` (no UIScale, no UIStroke).
   - `LightTextFills` = frozen set {Primary, Header, Red, Disabled}; `textOn(fill: string): string` → `"Cream"` if in it, else `"DarkText"`.
   - `interactive(active: boolean, disabled: boolean?): boolean` → `active and disabled ~= true`.
2. `UiKit`:
   - `textOn(color: Color3): Color3`: the `colors` name whose value `== color` → `colors[UiStyle.textOn(name)]`; no match → DarkText.
   - `label`: default `TextColor3 = colors.DarkText`; the title stroke moves into `outlineText(label: TextLabel)`, called by `label` for title sizes.
   - `button`: `TextColor3 = UiKit.textOn(color)`.
   - `setFill(button: GuiButton, color: Color3)`: `BackgroundColor3 = color`; if `TextButton`, `TextColor3 = textOn(color)`.
   - `setEnabled(button: GuiButton, enabled: boolean, fill: Color3?)`: attribute `KitDisabled` = `true` or `nil`; with `fill`: `setFill(button, if enabled then fill else colors.Disabled)`; disabled → `hovering[button] = false`, `Press.Scale` to 1 at once (same `play` key).
   - `bindInteraction`: both handlers gate on `UiStyle.interactive(button.Active, button:GetAttribute("KitDisabled") == true)`, replacing `button.Active`.
   - Studio hook `interact`: not interactive → `{ ok = false, error = "Disabled" }`.
   - `headerBand(title: TextLabel)`: `decorate(title, "header")`, `BackgroundTransparency = 0`, `BackgroundColor3 = colors.Header`, `TextColor3 = colors.Cream`, `UIPadding "HeaderInset"` left and right `Style.HeaderInset`.
   - `setSelected`: selected stroke colour `colors.Header` (was Cream); thickness unchanged.
3. `UiKit.headerBand(title)` after each window `Title` is created: AdventPanel, EventShopPanel, LotManager, PlotPicker, QuestPanel, SavePicker (`Title` of Picker and DeleteConfirm), ShopPanel, TeamPanel, TeammateFinder. Not on tab-page titles or `questsHeader`.
4. Fills (line numbers as of 4c2c30e; files with upper-case colour locals add `local PRIMARY`):
   - Gold → Primary (actions): BreakAreaMode 286; StockingMode 530 (`Place`); EmployeesTab 131; LandTab 115; SupplierTab 115 (`OrderTrees`), 153 (`Sell`); PlotPicker 79, 85; EventShopPanel 209; QuestPanel 187; SavePicker 148, 159, 423; ShopPanel 195; TeammateFinder 112, 247; TeamPanel 105.
   - Sand → Red (close and danger): AdventPanel 138; EventShopPanel 116; LotManager 67; QuestPanel 142; ShopPanel 100; TeammateFinder 137; TeamPanel 118, 226 (`Remove`); SavePicker 435 (`Leave`), 450 (`Delete`: `if renaming then SAND else RED`).
   - Delete Cream text lines SavePicker 196, TeamPanel 112.
   - Runtime: BreakAreaMode 179, StockingMode 281 (inside `if enabled ~= nil`), EmployeesTab 169, LandTab 198 (`Active` line stays) → `UiKit.setEnabled(button, enabled, UiKit.Colors.Primary)`; PlotPicker 170 → `UiKit.setEnabled(chooseButton, row.free, PRIMARY)`; SavePicker 247 → `UiKit.setEnabled(confirmDelete, matches, RED)`; SupplierTab `setEnabled` adds `UiKit.setEnabled(button, enabled)`; AdventPanel 185–186 → `UiKit.setFill(button, color)`.
   - Other Gold/Sand fills stay (selections, Advent door, Quest strip, progress).
5. Text:
   - Sand text → `Muted`: BreakAreaMode 272, StockingMode 501, EmployeesTab 117, 149, LandTab 172 (else branch), 261.
   - Gold text → `GoldText`: ShopPanel 61, QuestPanel 239, LandTab 172 (met), LotManager `ManagerCash` (new line after creation), Leaderboards 36 (`you`).
   - QuestPanel 307 → `label.TextColor3 = DARK`; Leaderboards 36 else-branch → `DarkText`; WorldLabels 251 → `DarkText`; UiController `SaveStatus` (over the world): `TextColor3 = Cream` plus `UiKit.outlineText(status)`; LotManager 98 indicator → `colors.Header`.
   - Kept: Tutorial arrows and stroke, ChatTags, ghost colours. Unused locals may be removed.
6. World (d): WorldService 252 billboard text → `DarkText`; lot sign `signLine` colours: Name `"Gold"` → `"GoldText"`, Rating and Likes `"Cream"` → `"DarkText"`; MapWorld unchanged (leaderboard screen is `Panel`, now cream; sign text sits on wood). Fonts done in UI1.
7. Docs:
   - `docs/UI_STYLE.md` (≤ 4 KB): a line per token (Colors with roles, Fonts, TextSize, CornerRadius, Style, Motion, MinTouch 44); rules: text colour from `textOn`, Primary = main action, Red = close/danger, Gold = selection/money, window titles `headerBand`, disabled via `setEnabled`. Click sound: `rbxasset://sounds/volume_slider.ogg`, engine content on every client, no asset ID, upload or licence, volume 0.5 (DECISION_LOG 2026-11-27).
   - `docs/art/ui-reference/README.md`: "No owner images supplied (checked 2026-11-27); target derived from PRODUCT_SPEC "UI look" and REFERENCE_GAME_LIVE_TEST §9." Table `Trait | Target | Source`, one row per PRODUCT_SPEC target-look bullet; later owner images go here, uncommitted if unlicensed.

## Tests (headless; 771 → 774)
| Test case file | Test name | Asserts |
|---|---|---|
| UiStyle_Test | header decorations | only `Corner` 8 and `Shade` |
| UiStyle_Test | text colour follows the fill | `textOn`: Cream on Primary, Header, Red, Disabled; DarkText on Panel, Row, ListWell, Sand, Gold, Cream |
| UiStyle_Test | disabled buttons do not animate | `interactive(true,nil)` true; `(true,true)` false; `(false,nil)` false |
| UiTheme_Test | text colour pairs meet WCAG contrast (replace list) | ≥ 4.5: DarkText on Panel, Row, ListWell, Sand, Gold, Cream, Toast; Muted and GoldText on Panel, Row, ListWell; Cream on Header, Primary, Red, Disabled; ≥ 3.0 Placeholder on Cream; shaded fills (Panel, Sand, Gold, Red, Disabled, Header, Primary) also with text and fill both × `Style.GradientBottom` ≥ 4.5; text-size asserts kept |
`ui_scan.luau` unchanged, 0 hits.

## Playtest (Studio, via playtester; desktop; queue per `cm2-task` step 3)
Client `Players.LocalPlayer.StudioUiHook` (UI1 Step 3), server `StudioTestHook` `saveAction`; 0.3 s per press.
1. Smoke run.
2. Each 22a (c) window (LotManager each tab, Shop, Quests, Advent, Event, Team, Finder over SavePicker, DeleteConfirm): frame fill Panel; `Title` fill Header, text Cream, `Shade` and `HeaderInset` present; shown `TextButton` text = `textOn(fill)`; close buttons Red; H4b probe (`docs/archive/plans/CM2-UV.md`) 0 violations.
3. (g) press `SavePickerUI/Picker/SaveList/SaveRow_1/Delete` (name field empty): `interact SavePickerUI/DeleteConfirm/ConfirmDelete hover` → `{ok=false,error="Disabled"}`, `Press.Scale` 1, fill Disabled; press `Cancel`; `interact HudRailUI/Rail/SavesButton hover` → 1.05, idle.
4. (f) How the hook reaches the PlotPicker: `saveAction Save.Create {name="UI2 Pick"}`; press `HudRailUI/Rail/SavesButton`, then `HudRailUI/Rail/FinderButton` (`FinderUI.FinderPanelDim` visible); press `SavePickerUI/Picker/SaveList/SaveRow_<n>/Play` for the row showing "UI2 Pick" (the hook ignores the dim; `Save.Plots` gives `pick`) → `PlotPicker.open` runs `closeModals`: after 0.3 s `PlotPickerUI.Panel` visible, `FinderPanel` and `FinderPanelDim` hidden (no dim over the picker); H4b probe 0. Cleanup: press `PlotPickerUI/Panel/Back`, delete "UI2 Pick", play "Playtest A".
5. World: a bay billboard text DarkText on Panel; lot sign Name GoldText.

## Acceptance
- `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (774), `lune run tests/tools/ui_scan.luau` (0 hits), `rojo build`.
- Playtest 1–5 PASS; `runPlaytest {mode="full"}` 74 steps PASS (end of run per hasseln rule).
- Layouts, `Visible` timing, remotes, error codes, string keys, save fields unchanged.
- Deviations (reviewer logs): band = the title's own box inside the padding; toast and HUD chips cream; hook `interact` may return `Disabled`; (f) reads as "Finder dim gone when the picker opens" (`closeModals`; picker DisplayOrder 21 < Finder 25).

## Out of scope
Phone limits, plot-picker overlap (22a3); phone and tablet (22a4); map sign wood and Tutorial arrow colours.

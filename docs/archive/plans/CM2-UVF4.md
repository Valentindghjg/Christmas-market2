# CM2-UVF4 — Save row state text fits; the UI probe flags truncation

Written by: `planner` (Opus 5.5, high). Implemented by: the tier's agent. Playtested by: `playtester`. Reviewed and committed by: `reviewer`. Pipeline: skill `cm2-task`.
Rule: everything is decided; if something is missing, the implementer stops and reports.

## Goal
Every label of the save picker, Team panel and teammate finder shows its full English text at the PC and phone widths; the UI probe now reports any shown text that does not fit, whatever its `TextTruncate`.

## Source of truth
- Backlog 5e; PROGRESS "CM2-UV UI verification" row (d): uv-d1 (`SaveState` is 0.4 of the row, about 169 px at PC, no wrap).
- CM2-UV plan H4 and (d) step 1; H4 amended by the planner (H4b) in `docs/archive/plans/CM2-UV.md`.
- roblox-gui full.md §4, §11.6: fixed size plus layout, wrap instead of truncating or shrinking.
- PRODUCT_SPEC: English-only launch.

## Implementer tier
Tier: S. Reason: client layout of three dialogs, one UiKit helper and UiTheme tokens with one test; no save, money, inventory, remote or server change.

## Skills to load
roblox-collaboration-mode, roblox-gui, roblox-input, roblox-localization, roblox-luau-core, roblox-luau-patterns, roblox-luau-types, roblox-tooling.

## Decisions (settled)
| # | Decision |
|---|---|
| D1 | Save row: name, kind and state each get a full-width line (state below kind, left-aligned); name and kind may wrap to 2 lines. Row 120 → 136 px. |
| D2 | Status lines (`PickerStatus`, `TeamStatus`, `FinderStatus`) move out of the footers into the first entry of their dialog's list: full width, `AutomaticSize.Y`, wrapped, hidden while empty; a new message scrolls the list to the top. Reason: server messages are up to 118 chars (`saveErrorSwitchSaveFailed`); the footer slots (picker 0.6 width, 162 px on phone) cannot hold them. Names stay, so `FindFirstChild(name, true)` callers keep working. |
| D3 | Team footer 140 → 96 px, finder footer 236 → 198 px (status slot removed); picker footer stays 200 (CM2-UVF5 owns the picker list and footer edge). |
| D4 | Header fixes: picker hint 14 → 13 px, y 30, height 28 (2 lines); finder hint and `OwnListing` 14/15 → 13 px; Team `CodeLine` wraps, height 38 (pending text is 55 chars at 18 px), `CodeHint` y 98, Team `listTop` 110 → 120. |
| D5 | Probe H4b (below) replaces the H4 text rule; CM2-UV2 uses it. |
| D6 | No string change, no `TextScaled`, no runtime measuring; the Studio probe is the proof. Estimate 0.6 em per char; row inner width 432 px (PC) / 314 (phone): state with a 20-char name ≈ 281 px, one line; kind ≈ 328 px and shared name ≈ 389 px, 2 lines. |
| D7 | Studio test batched (third after CM2-UVF1, CM2-UVF2); BUILD stays `cm2-n1-fix2`, RunPlaytest unchanged (unit check `>= 380` holds). |

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/UiTheme.lua` | Change | `SaveRow` tokens; Team and Finder dialog values |
| `src/client/UiKit.lua` | Change | `UiKit.listStatus` |
| `src/client/SavePicker.client.lua` | Change | row layout, hint, status in the list |
| `src/client/TeamPanel.client.lua` | Change | header, footer, status in the list |
| `src/client/TeammateFinder.client.lua` | Change | hint and own-listing size, footer, status in the list |
| `tests/studio/Cases/UiTheme_Test.lua` | Change | 1 test |
| `docs/DECISION_LOG.md`, `docs/TEST_PLAN.md` | Change | entry, one sentence |

`docs/archive/plans/CM2-UV.md` H4 is already amended (planner). No other file changes.

## Data and config
`src/shared/UiTheme.lua`, after `UiTheme.Dialogs` (PROVISIONAL):
```lua
export type SaveRowLayout = { height: number, padding: number, nameTextSize: number, nameHeight: number, textSize: number, kindHeight: number, stateHeight: number }
UiTheme.SaveRow = { height = 136, padding = 6, nameTextSize = 18, nameHeight = 36, textSize = UiTheme.TextSize.Small, kindHeight = 28, stateHeight = 16 } :: SaveRowLayout
```
`UiTheme.Dialogs.Team`: `listTop = 120`, `footerHeight = 96`. `UiTheme.Dialogs.Finder`: `footerHeight = 198`. Nothing else changes. No save fields, no string keys.

## Steps
1. **UiTheme.lua**: the type, `SaveRow` table and the three dialog values above. Comment above `SaveRow`: "Save picker row (CM2-UVF4): name, kind and state on their own lines above the buttons."
2. **UiKit.lua**, Factories section, after `UiKit.textBox`:
   `function UiKit.listStatus(list: ScrollingFrame, name: string): TextLabel` — `UiKit.label(list, name, "", UiTheme.TextSize.Small)`, then `LayoutOrder = -1`, `Size = UDim2.new(1, -8, 0, 0)`, `AutomaticSize = Enum.AutomaticSize.Y`, `TextWrapped = true`, `TextTruncate = Enum.TextTruncate.None`, `TextYAlignment = Enum.TextYAlignment.Top`, `Visible = false`; on `GetPropertyChangedSignal("Text")`: `Visible = Text ~= ""`, and when visible `list.CanvasPosition = Vector2.zero`. Comment: D2's rule in one sentence, naming CM2-UVF4.
3. **SavePicker.client.lua**:
   - Add `local SAVE_ROW = UiTheme.SaveRow` above `ROW_HEIGHT` (`ROW` is the row colour) and set `ROW_HEIGHT = SAVE_ROW.height` (the `Empty` label follows it).
   - Hint: text size `UiTheme.TextSize.Small`, `Position = UDim2.fromOffset(0, 30)`, `Size = UDim2.new(0.6, -4, 0, 28)` (before `bindDialog`, which records it).
   - Status: delete the footer `status` block (lines ~153–158); after the `layout` of `list` create `local status = UiKit.listStatus(list, "PickerStatus")`. `BackToGame` stays in footer row 4. Footer comment: "Four footer rows: size toggles, new save, join by code, back. The status line is the first entry of the save list (UiKit.listStatus)."
   - `buildRow`: row padding top and bottom `SAVE_ROW.padding`. `SaveName`: text size `SAVE_ROW.nameTextSize`, `Size = UDim2.new(1, 0, 0, SAVE_ROW.nameHeight)`, `TextWrapped = true`. `SaveState`: text size `SAVE_ROW.textSize`, no AnchorPoint change (0, 0), `Position = UDim2.fromOffset(0, SAVE_ROW.nameHeight + SAVE_ROW.kindHeight)`, `Size = UDim2.new(1, 0, 0, SAVE_ROW.stateHeight)`, `TextXAlignment` Left (delete the Right line). `SaveKind`: text size `SAVE_ROW.textSize`, `Position = UDim2.fromOffset(0, SAVE_ROW.nameHeight)`, `Size = UDim2.new(1, 0, 0, SAVE_ROW.kindHeight)`, `TextWrapped = true`. `NameBox` and buttons unchanged.
4. **TeamPanel.client.lua**: `CodeLine` `Size = UDim2.new(1, 0, 0, 38)`, `TextWrapped = true`; `CodeHint` `Position = UDim2.fromOffset(0, 98)`. Delete `STATUS_HEIGHT` and the footer `status` block; after `listLayout` create `local status = UiKit.listStatus(memberList, "TeamStatus")`. Size buttons y offset `-(BUTTON_HEIGHT + 8)`; `NewCode`, `LeaveTeam`, `Close` `Position` y `UDim2.new(<x scale>, 0, 1, 0)`. Footer comment: "Footer, bottom up: New code / Leave save with Close, then the owner's sizes (96 px, see UiTheme.Dialogs.Team). The status line is the first entry of the member list."
5. **TeammateFinder.client.lua**: hint text size `UiTheme.TextSize.Small`; `OwnListing` text size `UiTheme.TextSize.Small`. Delete `STATUS_HEIGHT` and the footer `status` block; `CLOSE_BOTTOM = 0`; after `listLayout` create `local status = UiKit.listStatus(listingList, "FinderStatus")`. Footer comments: drop "status," from the bottom-up list, add "The status line is the first entry of the listing list.", and "236 px" → "198 px".
6. **Docs**: DECISION_LOG entry at the end `## 2026-11-22 — CM2-UVF4 dialog text fit (engineering)`: defect, D1–D5 one bullet each, files, headless 398. TEST_PLAN section J: append "Dialog text fit: `UiTheme_Test` save row case; Studio probe H4b (CM2-UVF4)."

## Tests (headless)
| Test case file | Test name | Asserts |
|---|---|---|
| UiTheme_Test | save row stacks name, kind, state and buttons | `r = UiTheme.SaveRow`: `nameHeight >= 2 * nameTextSize`; `kindHeight >= 2 * textSize`; `stateHeight >= textSize + 2`; `nameHeight + kindHeight + stateHeight + UiTheme.MinTouch == height - 2 * padding`; `textSize == UiTheme.TextSize.Small` |

The existing "fits the picker, delete confirm, Team panel and finder on every screen" must still pass with the new values. Headless total: **398** (397 + 1).

## Playtest (Studio, via playtester; batch run)
Helpers from `docs/archive/plans/CM2-UV.md`: D4 clicks in GUI space without `GuiService:GetGuiInset()`, D5 timeouts, D7 test data, H, `sa`, R, SH. If the batch already started Play, read BUILD and ran `runPlaytest {mode="full"}` on the same HEAD, reuse those results.
- **H4b probe(guis)** (Client), 1 s after the last input: H4's rules, with the text rule replaced by: any TextLabel, TextButton or TextBox whose text is not empty, that is shown (gui `Enabled`, it and every GuiObject ancestor `Visible`) and has `TextFits == false`, whatever its `TextTruncate`. Report path, `Text`, `AbsoluteSize`, `TextBounds`. PASS when empty.
- `en(key)` = `require(ReplicatedStorage.Shared.Localization).get("en", key)`.

0. Edit DM: `StarterPlayer.StarterPlayerScripts.Client.UiKit.Source` contains `listStatus` and `ReplicatedStorage.Shared.UiTheme.Source` contains `SaveRow`; BUILD read in the Play Server DM is `cm2-n1-fix2`; else all BLOCKED "Studio not synced with Rojo". Record HEAD and viewport.
1. Play, "Playtest A" active. `SavesButton` → H4b{SavePickerUI} empty; in every `SaveRow_`, `SaveState.AbsolutePosition.Y >= SaveKind.AbsolutePosition.Y + SaveKind.AbsoluteSize.Y`; `PickerStatus.Visible == false`. Capture `uvf4-1`.
2. uv-d1 setup (CM2-UV (d) step 1, "UV Far"); close and reopen the picker. Its row: `SaveState.Text` is `en("saveRowElsewhereUnknown")` or the `saveRowElsewhere` text, `TextFits == true`, `Play.Text == en("saveJoinServer")`; H4b empty; capture `uvf4-2` shows the full text.
3. Click that row's `Play` → within 3 s `PickerStatus.Visible`, `Text == en("saveErrorTeleportUnavailable")`, `TextFits == true`, `PickerStatus.AbsolutePosition.Y < SaveRow_1.AbsolutePosition.Y`; H4b empty; capture `uvf4-3`. Its `Delete` → `DeleteConfirm` shown, H4b empty; `Cancel`. Cleanup as CM2-UV (d) step 1.
4. Longest message: Client DM `PickerStatus.Text = en("saveErrorSwitchSaveFailed")` → 1 s later `TextFits == true`, `AbsoluteSize.X <= SaveList.AbsoluteSize.X`, H4b empty; capture `uvf4-4`; set `""` → `Visible == false`.
5. Team, Solo owner ("Playtest A"): `TeamButton` → H4b{TeamUI} empty; capture `uvf4-5`; `TeamStatus.Text = en("saveErrorSwitchSaveFailed")` → `TextFits == true`, above `Member_1`, H4b empty; `""`; close.
6. Team, Duo owner: `sa(R, "Save.Create", {name="UV Duo", size="Duo"})`, play it; `TeamButton` → `CodeLine.Text` contains `sa(R, "Save.Team", {}).inviteCode`, `TextFits == true`, H4b{TeamUI} empty; capture `uvf4-6`. Close; play "Playtest A"; delete "UV Duo".
7. Finder and member: CM2-UV (d) step 2 (`H("shadowJoin")` first if SH is absent). After `FindTeammates`: H4b{FinderUI, SavePickerUI} empty, `Listing_1` shown; `FinderStatus.Text = en("saveErrorSwitchSaveFailed")` → `TextFits == true`, H4b empty; `""`; capture `uvf4-7`. After `JoinListing` (Member): `TeamButton` → H4b{TeamUI} empty; capture `uvf4-8`. Then CM2-UV (d) step 2 and 3 cleanup.
8. `runPlaytest {mode="full"}` → `mode=full steps=41 pass=41 fail=0`.
End: as CM2-UV "End" (no UV save left, player on "Playtest A", never save the place).

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (398 run, 0 failed), `rojo build default.project.json --output build.rbxlx`, `rojo build release.project.json` (0 instances named UnitTest/RunPlaytest/StudioTestService).
- Ticket: uv-d1 row `SaveState.TextFits == true` and the capture shows the full text; H4b over picker, Team (owner Solo, owner Duo, member) and finder is empty; `runPlaytest {mode="full"}` all PASS. Phone widths: CM2-UV2 with H4b.
- Skills: no `TextScaled`; one sizing policy per text region; strings via keys. `git diff` touches only the files in "Files".

## Out of scope
Picker list height and the footer edge (CM2-UVF5; note: two whole 136 px rows need 280 px, the PC list is 285 px); `NewCode` on Solo (CM2-UVF6); German and auto-translated widths; other ScreenGuis; look changes (CM2-UI).

## Amendment 1 (planner, 2026-11-22): defect UVF4-D1 after the Studio playtest
Playtest on HEAD `608e739` plus the uncommitted implementation: steps 2–7 PASS, step 8 reused (41/41, unit 398/398); step 1 FAIL: after Play on a save row and `CompanyReady`, the rail `SavesButton` reopens the picker with `PickerStatus.Visible == true`, `Text == en("saveLoading")` (capture `uvf4-1`).

**Cause.** `play` sets `status.Text = localized("saveLoading")`; when the chosen save is the one already running (`CompanyReady` stays true, no reload), it calls `close()` without clearing the status. The text survives the close and shows on the next open. The defect is older than CM2-UVF4 (the old footer status kept the same text); moving the status into the list made it visible to the step 1 check.

**Rule.** A closed picker keeps no message: `close` clears the status. Every message that must be read is shown with the picker open (`SaveTeleportError`, `CompanyError` and the first-join path call `open()` before `showError`), so nothing is lost.

### Fix steps (tier stays S: one client file, no server, save or remote change)
| # | File | Change |
|---|---|---|
| F1 | `src/client/SavePicker.client.lua` | In `close = function()`, add `status.Text = ""` directly after `picker.Visible = false`, with the comment `-- A closed picker keeps no message (CM2-UVF4 UVF4-D1).` |
| F2 | same | In the `CompanyReady` handler, delete the now redundant `status.Text = ""` line before `close()`. No other line changes; `play` keeps its `saveLoading` text (shown while a different save loads). |
| F3 | `docs/DECISION_LOG.md` | In the CM2-UVF4 entry, add one bullet: "UVF4-D1: a stale `saveLoading` status survived closing the picker after Play on the running save; `close` now clears the status." |

No headless test: `SavePicker.client.lua` is a LocalScript with no headless harness, and extracting a helper for one line is not worth it. Headless total stays **398**. Studio re-test is the proof.

### Re-test (playtester, Studio; only these steps)
Steps 2–7 PASS stand; do not re-run them. Step 0 as written (sync check, HEAD, BUILD).
- **R1 (replaces step 1).** Play, "Playtest A" active. `SavesButton` → H4b{SavePickerUI} empty; in every `SaveRow_`, `SaveState.AbsolutePosition.Y >= SaveKind.AbsolutePosition.Y + SaveKind.AbsoluteSize.Y`; `PickerStatus.Visible == false`. Click `Play` on the "Playtest A" row → picker closes within 3 s. `SavesButton` again → `PickerStatus.Visible == false`, `PickerStatus.Text == ""`, H4b empty. Capture `uvf4-1`.
- **R2 (new, other save).** `sa(R, "Save.Create", {name="UV Other", size="Solo"})`; reopen the picker; click `Play` on "UV Other" → within D5's load timeout `CompanyReady == true` and the picker closed. `SavesButton` → `PickerStatus.Visible == false`, `Text == ""`; capture `uvf4-1b`. Click `Play` on "Playtest A", wait for `CompanyReady`; delete "UV Other" (as CM2-UV cleanup).
- **R3 (message cleared on close).** Picker open: Client DM `PickerStatus.Text = en("saveErrorSwitchSaveFailed")` → `Visible == true`; click `BackToGame`; `SavesButton` → `PickerStatus.Visible == false`, `Text == ""`.
- **R4 (= step 8).** `runPlaytest {mode="full"}` → `mode=full steps=41 pass=41 fail=0` on the new working tree (do not reuse the earlier run).
- Still optional, not a gate: the 55-char pending-code `CodeLine` text of step 6 (`TextFits == true`) if a Duo save without a joined member is at hand.
End: as CM2-UV "End" (no UV save left, player on "Playtest A", never save the place).

### Acceptance delta
Ticket adds: R1–R3 PASS (UVF4-D1 fixed). Checks unchanged (398 headless). `git diff` adds no file beyond "Files".

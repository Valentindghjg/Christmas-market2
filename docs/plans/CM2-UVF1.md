# CM2-UVF1 — One dialog at a time: Saves picker and Lot Manager

Written by: `planner` (Opus 5.5, high). Implemented by: the agent for the tier below. Playtested by: `playtester` (Sonnet 5.5, medium). Reviewed and committed by: `reviewer` (Opus 5.5, medium). Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
Opening the Lot Manager, the Team panel or the stocking bar closes an open Saves picker; opening the picker closes them. The teammate finder still opens on top of the picker. While no save runs, the picker stays and the claimed dialogs do not open.

## Source of truth
- Backlog launch order 5c (CM2-UVF1); defect evidence: PROGRESS "CM2-UV UI verification" item (f), capture `uv-f2-pre`.
- Modal rule: DECISION_LOG "2026-11-22 - HUD shell and Lot Manager, CM2-40", bullet "Modal rules" and `docs/plans/CM2-40.md` step 88. This plan amends it: the picker stays the base layer, but now registers with the coordinator so a claim closes it.
- CM2-S3 design: the finder opens over the picker (`docs/plans/CM2-S3.md`).
- CM2-UI (backlog 22a, no plan yet; commit 1958110): look only, adds a dim layer under stacked dialogs later. This plan changes behaviour only (no look, no strings) and keeps picker (DisplayOrder 20) under finder (25), so CM2-UI adds its dim layer on this rule unchanged.

## Implementer tier
Tier: S. Reason: client UI rule plus a small pure shared module and its tests; no save schema, money, inventory, purchases or remotes.

## Skills to load
roblox-collaboration-mode, roblox-gui, roblox-input, roblox-architecture, roblox-luau-core, roblox-luau-patterns, roblox-luau-types, roblox-tooling.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/ModalCoordinator.lua` | New | Pure modal coordinator (no services, no Instances), headless-testable |
| `src/client/UiKit.lua` | Change | Modal block delegates to `ModalCoordinator`; new `UiKit.setBaseLayer` |
| `src/client/SavePicker.client.lua` | Change | Picker registers and clears itself as the base layer |
| `tests/studio/Cases/ModalCoordinator_Test.lua` | New | 9 tests (table below) |
| `tests/headless/run.luau` | Change | `sourcePaths` entry `ModalCoordinator = "src/shared/ModalCoordinator.lua"` (alphabetical, after `Localization`) |
| `docs/DECISION_LOG.md` | Change | New entry (step 5) |
| `docs/TEST_PLAN.md` | Change | Section J sentence (step 6) |

No change to `LotManager.lua`, `UiController.client.lua`, `TeamPanel.client.lua`, `TeammateFinder.client.lua`, `StockingMode.client.lua`, `RunPlaytest.lua` (BUILD stays `cm2-n1-fix2`; its unit check `>= 380` still holds).

## Data and config
- `ModalCoordinator.OverBase = table.freeze({ Finder = true })`: modal ids that open over the base layer without closing it. PROVISIONAL (engineering, CM2-S3 design).
- Modal ids in use stay: `LotManager` (LotManager.lua `MODAL_ID`), `Team`, `Finder`, `Stocking` (StockingMode `MODAL_ID`). No new ids.
- No save fields, no config keys, no string keys.

## Steps
1. **`src/shared/ModalCoordinator.lua`** (`--!strict`), header comment: "Modal coordinator (CM2-40, CM2-UVF1): one claimed dialog at a time; the save picker is the base layer, closed by any claim except the ids in OverBase."
   ```lua
   export type Coordinator = {
       claim: (id: string, close: () -> ()) -> (),
       release: (id: string) -> (),
       closeAll: () -> (),
       setBase: (close: (() -> ())?) -> (),
   }
   ModalCoordinator.OverBase: { [string]: boolean }
   function ModalCoordinator.new(): Coordinator
   ```
   Semantics (state is per instance: `holders: {[string]: () -> ()}`, `base: (() -> ())?`). All state changes happen before any close callback runs, so a callback that calls `release`/`setBase` is safe.
   - `claim(id, close)`: collect and remove every holder with another id; set `holders[id] = close`; if `not OverBase[id]` and `base ~= nil`, take `base` and set it to nil. Then call the collected holders' closes, then the taken base close (if any). A claim of an id already held replaces its close and calls nothing for it.
   - `release(id)`: `holders[id] = nil`. Never touches the base.
   - `closeAll()`: remove all holders, then call their closes. The base is kept (the picker calls this when it opens).
   - `setBase(close)`: `base = close` (nil clears). Calls nothing.
   - Iterate holders with `pairs`; the order among several closes is unspecified.
2. **`src/client/UiKit.lua`**, section "Modals": require `ModalCoordinator` from `Shared` (next to `UiTheme`), `local modals = ModalCoordinator.new()`, and replace the bodies:
   - `UiKit.claimModal(id: string, close: () -> ())` → `modals.claim(id, close)`
   - `UiKit.releaseModal(id: string)` → `modals.release(id)`
   - `UiKit.closeModals()` → `modals.closeAll()`
   - new `UiKit.setBaseLayer(close: (() -> ())?)` → `modals.setBase(close)`
   Replace the section comment with: "Lot Manager, Team panel, stocking bar and teammate finder: one of them at a time. The save picker is the base layer (`setBaseLayer`): any claim closes it, except the finder, which opens over it (ModalCoordinator.OverBase)." Delete the old `modalHolders` table.
3. **`src/client/SavePicker.client.lua`**:
   - `open()`: after `UiKit.closeModals()` add `UiKit.setBaseLayer(close)`.
   - `close`: first line `UiKit.setBaseLayer(nil)`.
   - Replace the comment above `UiKit.bindDialog(gui, {...picker...})` (lines ~200–201) with: "Both dialogs are placed by UiKit.bindDialog. The picker is the base layer: opening the Lot Manager, Team or the stocking bar closes it; the finder opens over it."
   - Line 2–8 header: append one sentence "CM2-UVF1: the picker is the modal base layer (UiKit.setBaseLayer)."
4. **No new open gates.** "While no save is active they do not open" already holds and must stay: `LotManagerButton.Visible = ready` and key M checks `CompanyReady` (UiController.client.lua lines 140, 200); `teamButton.Visible = ready` (TeamPanel); stocking `enter` returns unless `CompanyReady` (StockingMode line 555). The picker is only forced open (not dismissable) while `CompanyReady ~= true`, so no claim can close it then. Do not change these lines.
5. **DECISION_LOG** new entry at the end: `## 2026-11-22 — CM2-UVF1 modal base layer (engineering)` with bullets: defect (CM2-UV (f), `uv-f2-pre`: picker and Lot Manager open together because the picker never registered); rule (picker = base layer via `UiKit.setBaseLayer`; any `claimModal` closes it except ids in `ModalCoordinator.OverBase` = `Finder`; `closeModals()` keeps the base; claimed dialogs stay gated on `CompanyReady`, so a forced picker is never closed); it amends the CM2-40 "Modal rules" bullet; CM2-UI adds only a dim layer on this stack; files list; headless +9, total 389.
6. **TEST_PLAN** section J (line ~64): append "The modal rule (one dialog at a time, picker as base layer, finder over it) is covered headless by `ModalCoordinator_Test` (CM2-UVF1)."

## Tests (headless)
File `tests/studio/Cases/ModalCoordinator_Test.lua`, factory `return function(t)`, `ModalCoordinator = require(Shared:WaitForChild("ModalCoordinator"))`; each test builds its own `ModalCoordinator.new()` and counts calls with local counters.

| Test name | Asserts |
|---|---|
| `claim closes the other holder` | claim `LotManager` (a), claim `Team` (b) → a called 1, b 0 |
| `claiming the same id calls nothing` | claim `Team` (a), claim `Team` (b) → a 0, b 0; `closeAll` → b 1, a 0 |
| `claim closes the base layer once` | `setBase(f)`, claim `LotManager` → f 1; claim `Team` → f still 1 |
| `finder opens over the base layer` | `setBase(f)`, claim `Finder` (g) → f 0, g 0; claim `Team` → g 1, f 1 |
| `closeAll keeps the base layer` | `setBase(f)`, claim `Finder` (a), `closeAll` → a 1, f 0; claim `LotManager` → f 1 (reviewer amendment: `Finder`, not `Team`, because a `Team` claim closes the base at once) |
| `release forgets a holder` | claim `Team` (a), `release("Team")`, claim `LotManager` → a 0 |
| `setBase nil clears the base layer` | `setBase(f)`, `setBase(nil)`, claim `Team` → f 0 |
| `close callbacks may release and clear` | `setBase(f)` where f calls `setBase(nil)`; claim `Team` with a close that calls `release("Team")`; claim `LotManager` (b) → no error, f 1; `closeAll` → b 1 |
| `OverBase holds only Finder` | `OverBase.Finder == true`, `OverBase.LotManager == nil`, `OverBase.Team == nil` |

That is 9 tests: the headless total becomes **389** (380 + 9).

## Playtest (Studio, via playtester)
Helpers: Client DM = the Play client; clicks per CM2-UV D4: point = `AbsolutePosition + AbsoluteSize/2` via `user_mouse_input`, **without** `GuiService:GetGuiInset()` (GUI space). Find elements with `PlayerGui:FindFirstChild(name, true)` under the named ScreenGui. "Picker" = `SavePickerUI.Picker`, "LM" = `ChristmasMarketUI.LotManager`, "Rail" = `HudRailUI.Rail`. Each check reads `Visible` 1 s after the input. Captures `uvf1-<n>`, not committed. Never rename or delete "Playtest A" or "Tree Lot 1"; never save the place.

0. `list_roblox_studios`, `get_studio_state`. Edit DM: `ReplicatedStorage.Shared:FindFirstChild("ModalCoordinator") ~= nil` and `StarterPlayer.StarterPlayerScripts.Client.SavePicker.Source` contains `setBaseLayer`; else stop, all BLOCKED "Studio not synced with Rojo". Record `git rev-parse --short HEAD` and the viewport.
1. **Join, no save yet:** `start_stop_play` true; wait for `LocalPlayer.Character`. Before any click: Picker shown, `CompanyReady ~= true`, `Rail.LotManagerButton.Visible == false`, `Rail.TeamButton.Visible == false`. `user_keyboard_input` M → Picker shown, LM hidden. Capture `uvf1-1`.
2. **Choose a save:** click `Play` in the `SaveRow_` whose `SaveName.Text == "Playtest A"` → within 15 s `CompanyReady == true`, Picker hidden, `Rail.SavesButton.Visible`.
3. **Saves → LotManagerButton:** click `SavesButton` → Picker shown; click `LotManagerButton` → LM shown, Picker hidden, `SavesButton.Visible`. Capture `uvf1-2`. Click `CloseLotManager` → LM hidden.
4. **Saves → M:** click `SavesButton` → Picker shown; key M → LM shown, Picker hidden. Key M → LM hidden, Picker hidden.
5. **Lot Manager → Saves:** key M → LM shown; click `SavesButton` → Picker shown, LM hidden. Capture `uvf1-3`.
6. **Picker → Team:** (picker open) click `TeamButton` → `TeamUI.TeamPanel` shown, Picker hidden. Click `TeamPanel.Footer.Close` → hidden.
7. **Picker → finder:** click `SavesButton`, then `Picker.FindTeammates` → `FinderUI.FinderPanel` shown **and** Picker shown; `FinderUI.DisplayOrder > SavePickerUI.DisplayOrder` (25 > 20). Capture `uvf1-4`. Click `FinderPanel.Footer.Close` → finder hidden, Picker still shown. Click `Rail.FinderButton` → finder and Picker shown. Click finder Close, then `Picker.Footer.BackToGame` → Picker hidden.
8. **Full run:** Server DM `H("runPlaytest", {mode="full"})` → `"started"`; poll `ServerStorage.PlaytestStatus` to `done`; `PlaytestSummary` = `mode=full steps=41 pass=41 fail=0` (ends on "Playtest A"). Stop Play.
Record per step PASS/FAIL with the read values. Stocking bar → picker closed is covered headless only (it needs a delivered bay; the claim path is the same `claimModal`).

## Acceptance
- Checks: `stylua --check src tests` PASS, `selene src tests` PASS, `lune run tests/headless/run.luau` PASS **389 run / 389 passed / 0 failed**, `rojo build default.project.json --output build.rbxlx` PASS, `rojo build release.project.json` PASS with 0 instances named UnitTest/RunPlaytest/StudioTestService.
- Studio (PC), playtest steps 1–8 all PASS: on join before a save, `LotManagerButton` is hidden and M leaves the picker open with the Lot Manager hidden; Saves then `LotManagerButton` → only the Lot Manager; Saves then M → the same; Lot Manager then `SavesButton` → only the picker; picker then `TeamButton` → only Team; picker then `FindTeammates` (and rail `FinderButton`) → picker and finder, finder on top; `runPlaytest {mode="full"}` 41/41.
- `git diff` touches only the files in "Files".

## Out of scope
- Dimming under stacked dialogs and any look change (CM2-UI, 22a).
- Phone, tablet and 1080p checks (CM2-UV2); other CM2-UV defects (CM2-UVF2..UVF6).
- Escape/back-key handling, a stocking-bar Studio check, and changing which dialogs gate on `CompanyReady`.

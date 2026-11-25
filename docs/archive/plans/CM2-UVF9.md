# CM2-UVF9 — Disabled staff and land buttons report inactive; trace the first Move click

Written by: `planner` (Opus 5.5, high). Implemented by: the agent for the tier below. Playtested by: `playtester`. Reviewed and committed by: `reviewer`. Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
A Hire or Buy button that cannot act (locked, hired, not enough cash, requirements missing) is `Active = false`, as CM2-25-26b step 48 expects. The anomaly "first Move break area click closed the Lot Manager without starting the mode" is either explained by evidence or reproduced with a trace that names its cause.

## Source of truth
Studio-queue batch 2026-11-24 (Studio `53ca11c3`, `main` @ 1512b26):
- CM2-25-26b step 48 PASS with a deviation: the Lot Manager "Locked" button and the Cashier "Not enough cash" button report `Active = true`, while plan `CM2-25-26b.md` playtest 2 says "inactive".
- Step 50 PASS, but the first click on `MoveBreakArea` closed the Lot Manager without `BreakAreaBar`. The second click worked. No repro.

Code facts:
- The `setButton` helpers in `EmployeesTab.lua` and `LandTab.lua` set only Text, AutoButtonColor and colour. `hire()` and the Land buy already refuse in logic, so no request leaves today.
- `BreakAreaMode.start` claims the modal (closing the Lot Manager) only after `plotModel` succeeds. So a closed Lot Manager means either the mode started and exited at once, or the click hit another control.

## Implementer tier
Tier: S. Reason: client UI state and Studio-only trace lines; no save, money, remote or server change.

## Skills to load
roblox-collaboration-mode, roblox-gui, roblox-input, roblox-luau-core.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/client/LotManagerTabs/EmployeesTab.lua` | Change | `setButton` sets `Active` |
| `src/client/LotManagerTabs/LandTab.lua` | Change | `setButton` sets `Active` |
| `src/client/BreakAreaMode.lua` | Change | Studio-only `[BREAK]` trace, exit reasons |
| `tests/studio/Playtest/RunPlaytest.lua` | Change | `BUILD = "cm2-uvf9"` |

## Data and config
None. No string, config, schema or remote change.

## Steps
1. `EmployeesTab.lua` and `LandTab.lua`: in each local `setButton(button, text, enabled)`, add `button.Active = enabled`. Leave `StockingMode.client.lua` and `BreakAreaMode.lua` `setButton` unchanged. Their bars rely on input sinking, so they are out of scope.
2. `BreakAreaMode.lua`:
   - Add `local function trace(message: string)` that runs `print("[BREAK] " .. message)` only if `RunService:IsStudio()`.
   - `exit` becomes `exit(reason: string)`. When a session existed, it calls `trace("exit " .. reason)` first; the rest is unchanged.
   - Callers and their reasons:
     - the modal claim: `UiKit.claimModal(MODAL_ID, function() exit("claim") end)`;
     - the bar's Cancel: `"cancel"`;
     - CompanyReady lost: `"company"`;
     - ActiveSaveId changed: `"save"`;
     - PlotId changed: `"plot"`;
     - key Q: `"keyQ"`;
     - the done delay after a move: `"placed"`.
   - In `start`:
     - the first line is `trace("start requested " .. tostring(plotId))`;
     - each early return traces first: `"start skipped session"` (a session exists), `"start skipped notReady"` (CompanyReady not true), `"start skipped noPlot"` (`plotModel` nil);
     - after `buildBar`, `refreshTrees` and the connections, before the final `render(current)`, add `trace("start ok")`.
3. `RunPlaytest.BUILD = "cm2-uvf9"`. The step count stays 62.

## Tests (headless)
No new test; client modules have no headless harness. Expected: `lune run tests/headless/run.luau` equal to the count before this task (586 after CM2-UVF8), 0 failed.

## Playtest (Studio, via playtester)
On R's save, PC viewport. Run with any queued entries as a batch (skill `cm2-task` step 3).
0. (a) gate: viewport > 100x100 and a capture of the 3D world in the same run; the live source shows BUILD `cm2-uvf9`.
1. **Employees (step 48 re-check):**
   - Remember R's cash from `snapshot(R.userId)`. Open the Lot Manager, then Employees.
   - Lot Manager card: `Hire` Text "Locked", `Active == false`, `AutoButtonColor == false`.
   - `setProgression {userId = R.userId, cash = 1000}`, then close and reopen the Lot Manager on Employees. The `Staff_LotWorker` button reads "Not enough cash" with `Active == false`. The Cashier button reads "Hired" if hired, else "Not enough cash", and either way `Active == false`.
   - Click the LotWorker button once: `StaffStatus` stays empty, and R's cash and `staff` in `snapshot` are unchanged.
   - `setProgression {userId = R.userId, cash = 2000}`, then reopen: LotWorker "Hire", `Active == true`. Do not click.
   - Restore with `setProgression {userId = R.userId, cash = <remembered>}`.
2. **Land:** on `Tab_Land`, every card whose button reads "Requirements missing" has `Active == false`. Clicking one sends nothing: R's cash and `lotExpansion`/`hqLevel` in `snapshot` stay unchanged.
3. **Move click, 5 attempts.** Before each attempt, open a fresh Lot Manager on Employees and record:
   - `MoveBreakArea` AbsolutePosition and AbsoluteSize, `Page_Employees` AbsolutePosition, AbsoluteSize and CanvasPosition;
   - whether the button's centre (cx, cy) lies inside the page's visible rect;
   - the first entry of `PlayerGui:GetGuiObjectsAtPosition(cx, cy)` (full name).

   Attempt 1 goes exactly as a player would, with no scrolling. If the centre is outside the visible page, record that, then set `CanvasPosition` so the button is fully visible, and re-read. Then click the centre once:
   - (a) the output shows `[BREAK] start requested` and `[BREAK] start ok`;
   - (b) within 0.5 s `BreakAreaUI.BreakAreaBar` and `BreakAreaGhost` exist and the Lot Manager is closed;
   - (c) both still exist after 2 s with no `[BREAK] exit` line;
   - (d) click Cancel: `[BREAK] exit cancel`, both gone, R's `breakArea` unchanged.

   PASS = 5 of 5. On a failure, record the `[BREAK]` lines, the top GUI object and the rects, stop this check, and report for a planner amendment. A first-attempt observation of "centre outside the visible page" or "top object is not `MoveBreakArea`" is recorded as the explanation of the 2026-11-24 anomaly (a test-click artifact, no code defect).
4. Clean full run, last, with no manual actions during it: `runPlaytest {mode="full"}` `steps=62 pass=62`.

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (586 after CM2-UVF8, 0 failed), `rojo build` both project files.
- Playtest 0–4 PASS. After that, line 12 (CM2-25/26) is ticked: step 48 holds without the deviation, step 50 holds 5/5, and the server parts passed before (full 51/51 on `cm2-25-26b`).
- If step 3 reproduces the anomaly with the button visible and the top object `MoveBreakArea`, line 12 stays open and the planner amends this plan from the `[BREAK]` lines.

## Out of scope
- The `setButton` helpers of the stocking and break-area bars.
- Any change to the move mode's rules or the Employees layout.
- Removing the trace, which stays Studio-only.

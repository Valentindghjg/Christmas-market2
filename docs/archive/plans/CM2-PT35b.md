# CM2-PT35b — Step 35 from a clean shadow slate (fix round 1)

Written by: `planner` (Opus 5.5, medium). Implemented by: `implementer`. Playtested by: `playtester`. Reviewed and committed by: `reviewer`. Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
The full playtest runs 62/62 three times in a row on "Playtest A" with step 35 PASS. The uncommitted CM2-PT35b change (`shadowCleanSlate`, backlog entry) stays. This round fixes the two harness defects it exposed.

## Source of truth
Backlog entry CM2-PT35b and closed CM2-PT35 (`docs/CLAUDE_BACKLOG.md`). TEST_PLAN line 75 (full run, PREFLIGHT, step 35). Studio evidence af5facc4, three runs (orchestrator report, 2026-11-25).

## Diagnosis (verdicts)
| # | Symptom | Verdict | Evidence |
|---|---|---|---|
| a | Run 2/3: step 35 "Save.Play failed: SaveActionBusy" | **Race on R, not the shadow.** The message has no "for <userId>", so it comes from `saveActOk` (Support/Saves.lua:36-46), i.e. `playSave(ctx.saveA)` right after `Save.LeaveTeam` in step 35. LeaveTeam clears R's `ActiveSaveId`. The real client then opens the picker (`SavePicker.client.lua:618-621`), and `open()` sends `Save.List` (line 516). That request holds `_busy[R]` (`SaveSlotService.lua:527-530`), and the harness's `Save.Play` 0.3 s later gets `SaveActionBusy`. Run 1 won the race by timing. Hypothesis "step 35 deletes the Solo" is **false**: `deleteFinderSave` deletes only `S.finderSaveId` (Support/Saves.lua:171, 188), the save `FinderStart` created (Steps/Saves.lua:361). The Solo is `other` and is played, not deleted. | code lines cited |
| a2 | "After run 3 the shadow owns NO saves" | **Reading artifact, not a deletion.** The `saves` hook returns `listFor` (`StudioTestService.lua:364-369`). `listFor` returns `{}` when no profile is cached (`SaveSlotPicker.lua:52-56`), and cleanup's `shadowLeave` drops the cached profile (`SaveSlotService:leave`, `SaveSlotPicker.lua:506`). Before run 1 the shadow was still joined, so the read worked. "Tree Lot 1" very probably still exists. | code lines cited |
| b | "no free stocking slot": run 1 steps 44 and 52, runs 2/3 steps 07 and 20 | **The shadow's lot is full, not Playtest A.** Steps 20 (Core.lua:435), 44 (Staff.lua:143) and 52 (Shop.lua:130-131) place only on `S.userId`; step 07 places on R first, then S. Each run leaves about 5 trees on S (44: 3, 52: 2), and nothing removes them. `freeSlot` has 14 slots (Base.lua:471-481). Before PT35b the shadow played changing Duos (56/57/58). Since the sweep it always plays "Tree Lot 1", whose lot filled in runs before 2026-11-24. In run 1, 44 and 52 failed right after step 35 switched S to Tree Lot 1. In runs 2/3, `shadowJoin` plays Tree Lot 1 from step 02 on. PREFLIGHT drains only the shadow's bays (Fixtures.lua:163-186, 226-231), not its lot. | code lines cited |
| c | Runs 2/3: 37-43, 48, 50, 51, 54 NoActiveSave; 44 InsufficientFunds; 49 "0 trees" | **Cascade of (a).** R has no active save after the failed `playSave`. S stays on the fresh finder Duo (no switch back), which has starting cash and 0 trees. No separate fix. | — |

No game bug: the picker retries busy answers itself (`SaveListSync`), and `SaveActionBusy` is returned before any state change (`SaveSlotService.lua:527-528`). Nothing is filed.

## Implementer tier
Tier: S. Reason: the playtest harness and TEST_PLAN only; no `src` change, no save, money or remote code.

## Skills to load
roblox-collaboration-mode, roblox-luau-core, roblox-tooling.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `tests/studio/Playtest/Support/Saves.lua` | Change | `saveActAs` retries `SaveActionBusy` |
| `tests/studio/Playtest/Support/Fixtures.lua` | Change | PREFLIGHT clears the shadow's lot |
| `tests/studio/Playtest/Support/Base.lua` | Change | `placeOne` failure names the user and the count |
| `tests/studio/Playtest/RunPlaytest.lua` | Change | `BUILD = "cm2-pt35b2"` |
| `docs/TEST_PLAN.md` | Change | PREFLIGHT text |

Keep the existing uncommitted changes in the five files of the first round unchanged.

## Steps
1. **`saveActAs`** (Support/Saves.lua:21-30): replace the body with a loop that reuses the same `arg` table:
   - `local response = invoke("saveAction", arg)`; `local busyRetries, rateRetried = 0, false`
   - `while type(response) == "table" do`
     - `if response.errorCode == "RateLimited" and not rateRetried then rateRetried = true; task.wait(61)`
     - `elseif response.errorCode == "SaveActionBusy" and busyRetries < 5 then busyRetries += 1; task.wait(1)`
     - `else break end`
     - `response = invoke("saveAction", arg)`
   - `end`; then `task.wait(ACTION_PAUSE)`; `return response`.
   - New comment (replaces lines 19-20): "One Save.* request for a user (the player or a synthetic one). A rate-limited request is retried once after the window. A SaveActionBusy answer is retried up to 5 times, 1 s apart: the real client's picker lists while the player has no active save, and the server refuses a busy request before any change."
2. **`clearShadowLot`** (Fixtures.lua, a new local function right after `drainShadowBays`). Add `local act = ctx.act` to the locals at the top.
   - Comment: "CM2-PT35b: stores every tree on the shadow's lot back into its bays, so each run starts with an empty shadow lot (steps 20, 44 and 52 leave trees, and the shadow keeps one Solo save). Never touches R. Returns the stored count."
   - Body: `local stored = 0`; `for _, placement in snap(S.userId).placements do`
     - `local response = act(S.userId, "Stock.Store", { placementId = placement.placementId })`
     - `if type(response) == "table" and (response.errorCode == "NoFreeBay" or response.errorCode == "StorageFull") then drainShadowBays(); actOk(S.userId, "Stock.Store", { placementId = placement.placementId }) else check(type(response) == "table" and response.ok == true, "Stock.Store failed: " .. tostring(type(response) == "table" and response.errorCode or response)) end`
     - `stored += 1`; `task.wait(1)`. This keeps under the 10 per 10 s action limit (`CompanyStateService.lua:71`).
   - `end`; `return stored`.
3. **PREFLIGHT** (Fixtures.lua:228-232). Inside `if shadowJoined then`, after `settleDeliveries(S.userId)`:
   - `cleared = clearShadowLot()` (declare `local cleared = 0` next to `local drained = "none"`); then the existing `drained = drainShadowBays()` and its bays check.
   - Add `check(snap(S.userId).placementCount == 0, "shadow lot not empty after the clear")`.
   - Shadow-joined return string: insert `, shadow lot cleared %d` after `sold back %s`, with argument `cleared` after `drained`.
4. **`placeOne`** (Base.lua:583-584): the check becomes `check(slot ~= nil, string.format("no free stocking slot for %d (placementCount %d)", userId, snap(userId).placementCount))`.
5. **`RunPlaytest.BUILD`**: `"cm2-pt35b2"`.
6. **TEST_PLAN line 75**: in "sells back every tree in the shadow's bays and requires 0 shadow bays in use", replace that phrase with "stores every tree on the shadow's lot back into its bays (CM2-PT35b), sells back every tree in the shadow's bays and requires 0 shadow bays in use and 0 trees on the shadow's lot". Leave the BUILD named in that line unchanged.

## Tests (headless)
None (playtest harness only; the unit-test count stays 608).

## Playtest (Studio, via playtester)
1. Setup: Studio on `main` plus this working tree, synced via Rojo; place "Playtest A". Start Play. Check that the live `RunPlaytest.BUILD` reads `cm2-pt35b2`.
2. Before run 1, read state (Server): `StudioTestHook:Invoke("shadowJoin")`, then `saves 999999999001` (record every row: name, size, role, active), then `shadowLeave`. The profile is readable only while the shadow is joined (verdict a2).
3. `runPlaytest {mode="full"}` three times in a row, in the same Play session or one Play session per run (record which).
   - Each run: 62/62.
   - Step 03 detail contains "shadow lot cleared <n>"; in run 1, n ≥ 0 (expected ≥ 10 on Tree Lot 1).
   - Step 35 PASS with "listed, joined on Plot_..., left, relisted, stopped, switched, deleted". Run 1 may end with ", <k> leftover shadow saves removed", where k = the co-op rows read in step 2. Runs 2 and 3 have no suffix.
   - Step 53 PASS with "12 live (Buy/Owned), 15 ComingSoon, prompts refused, absent buyer NotProcessedYet, 0 prompts".
4. After run 3, repeat step 2's read. Expect exactly one row: role Owner, size Solo. Also expect `saveAction {userId=999999999001, action="Save.FinderList"}` → `listings` []. Then `shadowLeave`.
5. Console: no new errors beyond the known `203785492` asset warnings.

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (608/608), `rojo build default.project.json --output build.rbxlx` (do not commit the build).
- Studio: playtest items 3 and 4 hold in three consecutive full runs. PROGRESS.md records the three totals, the step 03, 35 and 53 details and the shadow save rows before and after.
- The reviewer ticks CM2-PT35b and CM2-PT53 and removes their queue items ("Studio-Test ausstehend" 0a/0b and the CM2-PT53 queue line).
- If any run is below 62/62 for a cause outside steps 03/07/20/35/44/52/53 and their cascade, record it and file it as a new follow-up. That does not block CM2-PT35b once three consecutive runs pass these steps; otherwise stop and report.

## Out of scope
- Clearing R's lot on "Playtest A" (no evidence it fills: R's step-07 trees are sold in step 08).
- A server change to `SaveActionBusy` or to the `saves` hook.
- Resetting the shadow's break area (step 49).

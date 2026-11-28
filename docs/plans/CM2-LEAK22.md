# CM2-LEAK22 — Smoke step 22 LEAK_CHECK: walking customer still alive

Written by: `planner-high` (Opus 5.5, high), 2026-11-28. Implemented by: the agent for the tier below. Playtested by: `playtester` (Haiku 5.5). Reviewed and committed by: `reviewer` (Sonnet 5.5, high). Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
Step 22 LEAK_CHECK passes reliably in every smoke or full run that includes steps 71 and 72, and the runner fails the exact step that leaves customers unpaused, so this kind of flaky leak cannot come back unnoticed.

## Source of truth
Backlog 18a6 (Accept (a)–(d)); PROGRESS archive entry "CM2-SUPC" (`docs/archive/PROGRESS_2026-11-27_to_2026-11-27_SUPQ-SUPC-14W-SLIM3.md`, (e)); `docs/TEST_PLAN.md` lines 82–86 (hook, runner modes); Fixtures header "Reset rule (CM2-N1 fix round 1)".

## Cause (planner, code reading): test isolation, not a director leak
| Fact | Where |
|---|---|
| Step 02 SHADOW_JOIN and 03 PREFLIGHT (`resetCustomers`) pause customers; only 23 CLEANUP unpauses them. Every NPC step (37–41) ends paused (`withNpcCleanup`). | `Steps/Core.lua:76`, `Support/Fixtures.lua` |
| Steps 71 and 72 end with `pcall(call, "pauseCustomers", false)`, so customers run live from the end of 72 onward. | `Steps/Advent.lua:171`, `Steps/Events.lua:182` |
| Run order is installer order: …Vehicles (73), Quests, Supplier (70), Advent (71), Events (72), then 22, 23. In the `{"71","72","73"}` run and in the full run, 22 starts right after 72. | `RunPlaytest.lua` installer list |
| The arrival loop runs every 5 s (`Npc.ArrivalIntervalSeconds`); the first unpaused pass spawns at once (credit starts at 1 and does not grow while paused). The runner sees a finished step only every 0.5 s (`task.wait(0.5)`), then 22 needs a few hook calls before `npcSnapshot`. A pass in that window spawns one live customer. | `main.server.lua:762`, `CustomerNpcService:arrivalPass` |
| Only R gets one: `npcArrive` needs an unreserved displayed tree; preflight empties the shadow lot (S returns `NoStock`). Hence "1 walking customer(s)". | `CompanyStateService:npcArrive` |
| The run with only `{"70"}` (14/14) has no 71/72, so it always passed; full runs pass most of the time (short window). | CM2-SUPC (c), CM2-14W full runs |
| The earlier forcing (`forceCustomer`) is not the cause: preflight's `npcReset` calls `resetForTest(nil)`, which removes every visit and clears all arrival overrides, and a paused `arrivalPass` never spawns (override or not). The forced visit and override do not outlive preflight. | `CustomerNpcService:resetForTest`, `arrivalPass` |
| No real leak path: with customers paused, visits are created only by `spawnForTest`/`spawnLoad` (hook only); every live visit ends by FSM timeouts or `MaxVisitSeconds`. | `CustomerNpcService` |

Confidence: high from code; the Studio runs below confirm it. The stray customer of the CM2-SUPC run was a fresh live arrival `visit:<n>` on R's plot from `arrivalPass` (state `Arriving` or `WalkingIn`, natural customer number), still walking because it had spawned under 1 s before the snapshot.

## Implementer tier
Tier: S. Reason: the cause is now settled by code reading; the fix touches only the Studio playtest runner, two step files, the Studio-only test hook and its context, plus headless tests; no game rules, saves, money, inventory or remotes.

## Skill checks
- roblox-collaboration-mode: done means verified; record the cause with evidence in PROGRESS; never claim a Studio run that did not happen.
- roblox-tooling: headless checks gate on parsed counts (expected 787), stylua/selene in check mode.
- roblox-npc-ai: transitions own cleanup; a paused director must spawn nothing; test the invariant, do not hide it with a reset in the check itself.
- roblox-luau-core: `x == true` for the paused value (a `nil` from a failed query must not pass); no dictionary-order dependence in the visit description (use the snapshot's ordered `visits` array).

## Files
| File | New/Change | Purpose |
|---|---|---|
| `tests/studio/Playtest/Steps/Advent.lua` | Change | step 71 no longer unpauses |
| `tests/studio/Playtest/Steps/Events.lua` | Change | step 72 no longer unpauses |
| `tests/studio/Playtest/RunPlaytest.lua` | Change | `pauseGuard`, `describeVisits`, guard after each step, BUILD |
| `tests/studio/Playtest/Support/Fixtures.lua` | Change | leak check names each live customer |
| `src/server/Services/StudioTestService.lua` | Change | hook command `customersPaused` |
| `src/server/main.server.lua` | Change | hook context `customersPaused` getter |
| `tests/studio/Cases/Playtest_Test.lua` | Change | 3 tests |
| `tests/studio/Cases/CustomerNpcService_Test.lua` | Change | 1 test |
| `docs/TEST_PLAN.md` | Change | hook command, run invariant, BUILD |

## Data and config
No config, schema, remote, error code or string key changes. `RunPlaytest.BUILD = "cm2-leak22"`.

## Steps
1. **Advent.lua** (step 71 wrapper, ~line 171): delete the line `pcall(call, "pauseCustomers", false)`. Keep `call("pauseCustomers", true)` in `body` (1). Append to the header comment block: `-- Customers stay paused after the step: 02 pauses them for the run, 23 CLEANUP unpauses them (CM2-LEAK22).`
2. **Events.lua** (step 72 wrapper, ~line 182): the same deletion and the same comment line.
3. **main.server.lua** (~line 1296, the `StudioTestService.install` context): after `setCustomersPaused`, add
   `customersPaused = function(): boolean return customersPaused end,` (formatted by stylua).
4. **StudioTestService.lua**: directly after `commands.pauseCustomers`, add
   ```lua
   -- The current pause state of the live arrival loop (CM2-LEAK22).
   function commands.customersPaused()
       return success(context.customersPaused() == true)
   end
   ```
5. **RunPlaytest.lua**, two pure functions after `RunPlaytest.needMet`:
   - `RunPlaytest.pauseGuard(mode: string, stepName: string, pausedSinceJoin: boolean, readPaused: () -> any): string?`
     Returns nil without calling `readPaused` when `mode == "soak"`, `stepName == "CLEANUP"` or `not pausedSinceJoin`. Otherwise calls `readPaused()` once: `true` → nil; `false` → `"customers left unpaused after the step (02 pauses them until 23 CLEANUP)"`; any other value → `"customersPaused query failed"`.
   - `RunPlaytest.describeVisits(visits: { any }): string`
     `"none"` for an empty array. Each of the first 5 entries as `string.format("%s %s %s #%s (%s)", tostring(v.visitId), tostring(v.plotId), tostring(v.state), tostring(v.customerNumber), table.concat(v.history or {}, ">"))`, joined with `"; "`; more than 5 entries append `string.format(" +%d more", #visits - 5)`. Order: the array's order (the snapshot is already ordered by sequence).
6. **RunPlaytest.lua `execute`**: set `ctx.describeVisits = RunPlaytest.describeVisits` next to `ctx.addStep`. In the runner loop replace the body of `if done then … end` with:
   ```lua
   local pauseError = RunPlaytest.pauseGuard(mode, step.name, outcome["02"] == "PASS", function()
       local called, response = pcall(function()
           return hook:Invoke("customersPaused", nil)
       end)
       if called and type(response) == "table" and response.ok == true then
           return response.data
       end
       return nil
   end)
   if pauseError ~= nil then
       pcall(function()
           return hook:Invoke("pauseCustomers", true)
       end)
   end
   if ok and pauseError == nil then
       record(step.id, step.name, "PASS", if type(detail) == "string" then detail else "")
   elseif ok then
       record(step.id, step.name, "FAIL", pauseError :: string)
   else
       record(step.id, step.name, "FAIL", tostring(detail) .. (if pauseError then " | " .. pauseError else ""))
   end
   ```
   The timeout branch stays unchanged (no guard). Header comment: add one line after the smoke mapping: `-- Between 02 and 23 customers stay paused; after every other step the runner checks it (CM2-LEAK22).` Set `BUILD = "cm2-leak22"`.
7. **Fixtures.lua `leakCheck`**: replace the two lines reading `npcSnapshot().count` and its `check` with
   ```lua
   local npc = npcSnapshot()
   check(npc.count == 0, npc.count .. " walking customer(s) still alive: " .. ctx.describeVisits(npc.visits))
   ```
   Fixtures is installed after `ctx.describeVisits` is set (step 6), so read it inside `leakCheck`, not at install time. Nothing else in leak check changes: it still fails on any live customer (no reset before the check).
8. **docs/TEST_PLAN.md**: line 82, after the `customerOrders` sentence add `` `Invoke("customersPaused")` returns whether the live arrival loop is paused (CM2-LEAK22). `` Line 85: `BUILD \`cm2-14wr\`` → `BUILD \`cm2-leak22\``, and append: `Customers stay paused from 02 to 23 CLEANUP: after every other step the runner reads \`customersPaused\`, fails a step that left them unpaused ("customers left unpaused after the step …") and pauses them again; 22 names each live customer (visit, plot, state, number, history) (CM2-LEAK22).`

## Tests (headless)
| Test case file | Test name | Asserts |
|---|---|---|
| `Playtest_Test.lua` | `pauseGuard skips soak, CLEANUP and steps before 02` | with a counting `readPaused` returning false: `("soak","SOAK_FAST",true)`, `("full","CLEANUP",true)`, `("smoke","ACTIVE_SAVE",false)` each return nil; the counter stays 0 |
| `Playtest_Test.lua` | `pauseGuard fails a step that leaves customers unpaused` | `("smoke","EVENT_SHOP",true)` with false → exactly `"customers left unpaused after the step (02 pauses them until 23 CLEANUP)"`; with true → nil; with nil → `"customersPaused query failed"`; the reader is called once per call |
| `Playtest_Test.lua` | `describeVisits names each live customer` | `{}` → `"none"`; one visit `{visitId="visit:41", plotId="Plot_02", state="WalkingIn", customerNumber=3, history={"Arriving","WalkingIn"}}` → `"visit:41 Plot_02 WalkingIn #3 (Arriving>WalkingIn)"`; 7 visits (`visit:1`..`visit:7`, other fields as the single one) → the first 5 joined by `"; "` then `" +2 more"` (check with `string.find(text, " +2 more", 1, true)` and that `visit:6` is absent) |
| `CustomerNpcService_Test.lua` | `a paused arrival pass never spawns, even with an override` | `harness()`, `addCompany(h, A, PLOT_1, 2)`, `setArrivalOverrideForTest(A, 8)`; three `arrivalPass(true)` return 0 and `snapshot().count == 0`; `resetForTest(nil)`; `arrivalPass(false)` returns 1 and `snapshot().visits[1].customerNumber == 1` (the override is gone) |

Expected headless total: 783 + 4 = 787.

## Playtest (Studio, via playtester)
Required now (runner change; Accept (c) needs the full run). Rojo synced, `[PLAYTEST] START` shows BUILD-matching code (`RunPlaytest.BUILD` `cm2-leak22`). All through `ServerStorage.StudioTestHook` in the Server data model.
1. Mechanism probe (as in CM2-SUPC): `pauseCustomers` true, `npcReset`, `forceCustomer` 8, `pauseCustomers` false; poll `npcSnapshot` up to 12 s → a visit on R's plot with `customerNumber` 8 and `history[1] == "Arriving"`. `customersPaused` → `{ok=true, data=false}`. Leave it walking (the next preflight must clear it).
2. `runPlaytest {mode="smoke", only={"71","72","73"}}` at once → `SUMMARY … steps=16 pass=16 fail=0 skip=0 result=PASS`; 22 detail `plots clean, no NPC left, no stray Humanoid`; no step detail contains `customers left unpaused`.
3. Directly a second identical run in the same Play session → 16/16 PASS as in 2.
4. After run 3: `customersPaused` → data `false` (cleanup unpaused).
5. `runPlaytest {mode="full"}` → 74/74 PASS (unit runner count 787 in step 01).
Record in PROGRESS: both summaries, the full summary and seconds, the step-1 visit ID.

## Acceptance
- Checks: `stylua --check src tests tools`, `selene src tests tools` (0 errors, 0 warnings), `lune run tests/headless/run.luau` 787 run, 787 passed, `rojo build` PASS.
- (a) PROGRESS entry "CM2-LEAK22" states the cause from the "Cause" table in three sentences: which customer (a live arrival `visit:<n>` on R's plot, natural number), who spawned it (`arrivalPass` after step 72's `pauseCustomers false`; 71 the same), why it walked (spawned within the 0.5 s step poll plus 22's first calls); and that the CM2-SUPC forcing was cleared by preflight.
- (b) Isolation: 71 and 72 no longer unpause; the runner guard (headless `pauseGuard` tests) fails any step that leaves customers unpaused; step 22 still fails on any live customer and now names it; the director's paused invariant has its headless test.
- (c) Playtest steps 2, 3 and 5 PASS.
- (d) Standard checks above PASS.

## Out of scope
Soak mode (its own 04 LEAK_CHECK waits 180 s and unpauses on purpose); any change to `CustomerNpcService` or `main.server.lua` arrival logic; step 40's deliberate unpause/pause (it ends paused through `withNpcCleanup`).

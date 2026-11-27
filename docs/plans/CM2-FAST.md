# CM2-FAST — Smoke run, step filter and a short TEST_PLAN

Written by: `planner` (Opus 5.5). Rule: everything is decided; if something is missing, the implementer stops and reports.

## Goal
A task's Studio test takes minutes: `runPlaytest {mode = "smoke"}` runs the core loop only, `only = {...}` adds a task's own steps, and `docs/TEST_PLAN.md` drops to ≤ 20 KB.

## Source of truth
Backlog 18g (a–e); DECISION_LOG 2026-11-26 "faster work, shorter tests" ("≤ 12 core steps"); playtester.md "What to run".

## Implementer tier
Tier: M. Reason: non-trivial runner logic (step selection with a dependency closure) plus a docs move; no game code, save field or remote.

## Skill checks
- roblox-tooling: the gate is the parsed result (SUMMARY counts, headless `[SUMMARY]` count), not an exit code; no silent rewrites (`stylua --check`).
- roblox-luau-types: keep `--!strict`; annotate the new exported functions' params and returns; `{ [string]: boolean }` for the selection set, nil-check lookups.
- roblox-luau-core: do not depend on dictionary iteration order; the run order comes from the `steps` array only; `#` only on the sequence `only`.
- Studio-only code stays under `tests/studio` (not in the release build).

## Files
| File | New/Change | Purpose |
|---|---|---|
| `tests/studio/Playtest/RunPlaytest.lua` | Change | `smoke` mode, `only`, pure selection functions, header comment, BUILD |
| `tests/studio/Cases/Playtest_Test.lua` | Change | 5 headless tests |
| `tests/studio/Playtest/Steps/*.lua`, `Support/Fixtures.lua` | Change | header comments only (step details moved from TEST_PLAN) |
| `docs/TEST_PLAN.md` | Change | new "Repeatable run" (≤ 4 KB), archive moves |
| `docs/archive/TEST_PLAN_2026-11-26.md` | New | moved text, unchanged |
| `.claude/agents/playtester.md` | Change | delete the sentence "Until `smoke` and `only` exist (backlog CM2-FAST), run the full run." |

## Data and config
- `RunPlaytest.BUILD = "cm2-fast"`.
- `RunPlaytest.SMOKE = { "02a", "02", "03", "04", "05", "07", "08", "09", "13", "19", "41", "22", "23" }` — 12 core steps plus CLEANUP (DECISION_LOG says "12 core steps"; CLEANUP is teardown, not a core step; recorded as the reading of Accept (a)). Mapping: active save 02a; preflight 02 shadow join + 03; order 04; delivery into the bay 05; place from the bay 07; sale 08 (feeds carry/load); carry 09; load 13; flush and rejoin 19; NPC sale with manual checkout 41 (its `withNpcCleanup` also expires the still-open order B, so 22 stays clean); leak check 22; cleanup 23. Left out: 06, 11, 12 (checks only; 07 and 13 do not use their state).
- Header comment at the top of `RunPlaytest.lua`: add the smoke call line, the `only` call line, the SMOKE list with the mapping above in one comment block (≤ 12 lines).

## Steps
1. `RunPlaytest.parseOptions(options: any): (string?, number?, number?, { string }?)` replaces the local `validOptions` (same checks) and adds: `mode` may be `"full"`, `"smoke"` or `"soak"`; `options.only` is nil or an array of 1..20 strings, each length 1..4 (`#only` and `only[i]` for i = 1..#only; any other key type or count fails); `only` with `mode = "soak"` fails. On failure it returns `nil, nil, nil, nil` → `run` prints `[PLAYTEST] REFUSED BadOptions` as today.
2. `RunPlaytest.selectSteps(steps: { { id: string, needs: { string } } }, mode: string, only: { string }?): ({ [string]: boolean }?, string?)`:
   - `mode == "full"` and `only == nil` → every step ID.
   - Otherwise base = `SMOKE`; then every `only` ID plus, transitively, the `needs` of every selected `only` step (closure over the `steps` list). Smoke steps do not pull in their own needs.
   - Any `only` ID not in `steps` → `nil, <that id>` (first unknown in `only` order). A `SMOKE` ID missing from `steps` → `nil, <that id>` as well.
3. `RunPlaytest.needMet(selected: { [string]: boolean }, outcome: { [string]: string }, need: string): boolean` = `selected[need] ~= true or outcome[need] == "PASS"` (a need outside the run counts as met, e.g. 07 → 06, 13 → 12 in smoke).
4. `execute(hook, mode, minutes, holdSeconds, only)`: install the full module list for `mode ~= "soak"` (the existing `if mode == "full"` branch); soak unchanged and skips selection. For full/smoke after installing: `selected, unknown = RunPlaytest.selectSteps(steps, mode, only)`; if `unknown` → print `[PLAYTEST] REFUSED UnknownStep <id>`, set `PlaytestSummary` to `REFUSED UnknownStep <id>`, return before START (no step runs). Else drop unselected entries from `steps` (keep array order) and use `needMet` in the runner's unmet loop. START and SUMMARY lines unchanged (`mode=smoke` shows in both). `stepTimeout` unchanged (smoke = 600 s per step).
5. `run`: call `parseOptions`; pass `only` to `execute`.
6. Step header comments: below each module's existing header lines add `-- Step details (moved from docs/TEST_PLAN.md, CM2-FAST):` then the text from the old TEST_PLAN line 79 (now in the archive) for that module, words unchanged, wrapped at ≤ 100 columns as `--` lines. Copy every piece listed below in full (no skipping):

| Module | Text from old line 79 |
|---|---|
| Steps/Core.lua | "unit runner (at least 418 tests)" … "every Blender mesh preloads)"; the CM2-G15 step 13 `LOAD` sentence |
| Steps/Saves.lua | items 24–35 |
| Steps/RowFill.lua | item 36 |
| Steps/Npc.lua | items 37–40; "Step 37 first checks …" sentence; the CM2-N2 `serveCounter` sentence |
| Steps/Checkout.lua | item 41; the `holdSeconds` sentence |
| Steps/Reviews.lua | items 42–43 |
| Steps/Staff.lua | items 44–50 |
| Steps/Shop.lua | items 51–53 |
| Steps/Progression.lua | the CM2-G9a 58/59 sentence |
| Steps/PlotPicker.lua | the CM2-PP 65 sentence and the teleport-arrival BLOCKED sentence |
| Steps/LotArt.lua | the CM2-13W 66 sentence |
| Steps/Quests.lua | the CM2-G11 67/68 text |
| Steps/Soak.lua | the `mode = "soak"` text (7 steps …) |
| Support/Fixtures.lua | leak check and cleanup items; the reset rule; the CM2-ART2 Amendment 1 PREFLIGHT text; the request-ID sentence; the PREFLIGHT CM2-UVF8 and staff-reset sentences |

7. `docs/archive/TEST_PLAN_2026-11-26.md`: title line, one line "Moved from docs/TEST_PLAN.md by CM2-FAST (2026-11-27), unchanged.", then sections `## Repeatable run (old §3b bullet)` = old line 79, `## Hook commands (old §3b)` = old lines 80 and 81, `## Monetization headless tests (old §3 L)` = the old L text from "CM2-46a (headless):" up to and including "(Amendment 1).".
8. `docs/TEST_PLAN.md`:
   - Replace line 79 with `### Repeatable run (CM2-G20, CM2-FAST)` and bullets (heading to the next bullet of §3b ≤ 4096 bytes): call `Invoke("runPlaytest", {mode = ...})` in the Server data model, returns `"started"`; modes `smoke` (13 steps, ≤ 180 s, the list), `full` (69 steps, BUILD `cm2-fast`), `soak` (`minutes` 1..30, default 10; 7 steps); `only = {"<id>", …}` with smoke or full adds those steps and their `needs`, full-run order, a need outside the run counts as met, unknown → `REFUSED UnknownStep <id>`, with soak → `REFUSED BadOptions`; `holdSeconds` 0..60 (step 41 capture hold); output and polling (the moved sentences from line 83: PASS/FAIL/SKIP lines, SUMMARY, `PlaytestStatus`/`PlaytestSummary`/`PlaytestReport`, poll until `done`, Edit mode → `REFUSED NoHook`); when to run which (pointer to DECISION_LOG 2026-11-26); details: header comment of each `Steps/*.lua` module and `Support/Fixtures.lua`, history in the archive file; layout (CM2-RF) and the 800-line rule, one sentence each.
   - Line 83: keep only the teleport sentence (up to "friends-test checklist.").
   - Lines 80 and 81: replace with one bullet "Hook commands (walking customers, staff, saves; CM2-N1, CM2-25/26, CM2-S1): `docs/archive/TEST_PLAN_2026-11-26.md`; code in `src/server/Services/StudioTestService.lua`."
   - §3 L: replace the moved text with "Headless test list: `docs/archive/TEST_PLAN_2026-11-26.md`."
   - If `wc -c` is then > 20480: also move line 84 ("Second player") to the archive under `## Second player (old §3b)` with a one-line pointer. Nothing else.

## Tests (headless)
| Test case file | Test name | Asserts |
|---|---|---|
| Playtest_Test.lua | smoke selects the fixed core list | fake steps (all SMOKE IDs plus 06, 12, 36 with needs 08→07→06→05→04→03→02): selection = exactly the 13 SMOKE IDs; `#RunPlaytest.SMOKE == 13` |
| Playtest_Test.lua | only adds the named steps and their needs | `only = {"36"}` (smoke and full): SMOKE ∪ {36, 06}, nothing else; full without `only`: every fake ID |
| Playtest_Test.lua | an unknown step id refuses | `only = {"36", "77"}` → `nil, "77"` |
| Playtest_Test.lua | a need outside the run counts as met | `needMet({["07"]=true}, {}, "06") == true`; `needMet({["06"]=true}, {["06"]="FAIL"}, "06") == false`; PASS → true |
| Playtest_Test.lua | parses smoke, full, soak and only | smoke/full with `only` ok; soak with `only` nil; `only = {}`, `{1}`, `{"12345"}`, 21 entries → nil; unchanged minutes/holdSeconds limits |

## Playtest (Studio, via playtester)
Runner change → full run required (cm2-task step 3).
1. `runPlaytest {mode = "smoke"}` → SUMMARY `mode=smoke steps=13 pass=13 fail=0 skip=0 result=PASS`, `seconds` ≤ 180 (report the value).
2. `runPlaytest {mode = "smoke", only = {"36"}}` → steps=15, all PASS.
3. `runPlaytest {mode = "smoke", only = {"99"}}` → `[PLAYTEST] REFUSED UnknownStep 99`, no START line, `PlaytestSummary` = `REFUSED UnknownStep 99`.
4. `runPlaytest {mode = "full"}` → steps=69, all PASS.

## Acceptance
- Checks: `stylua --check src tests tools`, `selene src tests tools`, `lune run tests/headless/run.luau` → 697 run, 697 passed (692 + 5), `rojo build`.
- `wc -c docs/TEST_PLAN.md` ≤ 20480; the "Repeatable run" subsection ≤ 4096 bytes; every piece listed in step 6 present in its module; archive file holds old lines 79–81 unchanged.
- Backlog 18g (a)–(e) with the smoke reading above (12 core steps + CLEANUP); soak step count unchanged (7).

## Out of scope
Step logic changes; CM2-SLIM6 (TECHNICAL_ARCHITECTURE size); hook command comments in `StudioTestService.lua`; template repo.

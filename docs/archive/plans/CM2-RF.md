# CM2-RF — Split oversized modules, no behaviour change

Written by: `planner` (Opus 5.5, high). Implemented by: the agent for the tier below. Playtested by: `playtester` (Sonnet 5.5, medium). Reviewed and committed by: `reviewer` (Opus 5.5, medium). Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
Agents can read save code and the Studio playtest in parts. The game, the save data and the playtest output behave exactly as before.

## Source of truth
- Backlog launch order 9a (CM2-RF); DECISION_LOG 2026-11-22 "owner: keep files small".
- TECHNICAL_ARCHITECTURE §1 (layout), §2 and "Save slots (CM2-S1)" (SessionService role); TEST_PLAN "Repeatable run (CM2-G20)".
- Measured at planning (HEAD 5032356): `RunPlaytest.lua` 2726 lines, `SaveSlotService.lua` 1803 lines, headless 405/405, full run 41 steps.

## Implementer tier
Tier: L. Reason: it moves the profile I/O, session, co-op and save-to-server code of SaveSlotService, where a wiring mistake loses or duplicates save data.

## Skills to load
roblox-collaboration-mode, roblox-architecture, roblox-luau-core, roblox-luau-types, roblox-tooling, roblox-data, roblox-server-data.

## Decisions
| ID | Decision |
|---|---|
| D1 | SaveSlotService stays one class. Its methods move verbatim into "part" modules. Each part returns a plain table of methods. The core merges every part into the class table at load, so `SaveSlotService.new`, `PROFILE_STORE_NAME`, `profileKey` and every method name stay the same for `main.server.lua` and the tests. |
| D2 | Parts are sibling ModuleScripts in `src/server/Services/` (precedent: `CustomerNpcWorld`, `NpcAvatar`). No folder, no `init.lua`, no rename of `SaveSlotService.lua`. |
| D3 | In a part, the method table is declared `local SaveSlotService: any = {}`. The `function SaveSlotService:…` lines and bodies then stay byte-identical. `any` avoids strict-mode errors for `self:` calls into other parts. |
| D4 | Module-local helpers that several parts use go to `SaveSlotShared.lua`. Each module aliases them with `local failure = SaveSlotShared.failure` (and so on), so moved bodies stay unchanged. |
| D5 | RunPlaytest: `execute` becomes a short runner. Helpers move to `Playtest/Support/`, steps to `Playtest/Steps/`. Every module returns `function(ctx: any)`, an installer. Installers read what they need from a shared context table `ctx` as `local x = ctx.x` lines, and Support installers write what they define as `ctx.x = x` lines. |
| D6 | `ctx` is strict: reading a missing key raises `playtest context has no field <key>`. A typo therefore fails when the run starts (the run's pcall turns it into `SUMMARY runner error: …`); it never surfaces as a nil call in step 30. |
| D7 | Shared mutable scalars: only `saveA` crosses modules (set by `activeSave` in Support/Saves, read by Steps/Saves); it becomes `ctx.saveA`. Each other scalar moves to the only module that uses it: `orderA/B/C` and `pickupHome` to Steps/Core; `saveB`, `saveC`, `saveDuo` and `duoCode` to Steps/Saves; `shadowJoined` to Support/Fixtures. |
| D8 | Step modules are required at run time inside `execute`, never at module load. `Playtest_Test` and the headless loader keep loading only `RunPlaytest`. |
| D9 | `RunPlaytest.BUILD` becomes `"cm2-rf"`. The playtester reads BUILD from the live place to prove that Studio runs the split code; an unchanged BUILD could not tell the old file from the new. The output format (START, PASS/FAIL/SKIP, SUMMARY lines and attributes) is unchanged. |
| D10 | The step order is unchanged: Core (01, 02a, 02, 03, 04–21), Saves (24–35), RowFill (36), Npc (37–40), then 22 and 23 from the runner. Soak mode keeps 01a, 01, 02, 03, 03a, 04, 05. |
| D11 | Two commits: (1) the SaveSlotService split with `run.luau` and TECHNICAL_ARCHITECTURE, (2) the RunPlaytest split with TEST_PLAN. Headless and lint checks run after each. |

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/server/Services/SaveSlotService.lua` | Change | Core: class, constructor, handlers, profile I/O, registry, session (un)registration, `_handle`/`handle`, merge of the parts |
| `src/server/Services/SaveSlotShared.lua` | New | Shared pure helpers |
| `src/server/Services/SaveSlotPicker.lua` | New | Picker rows, names, Create/Rename/Delete, play/switch/leave |
| `src/server/Services/SaveSlotTeam.lua` | New | Co-op records, invite codes, Join/LeaveTeam, team management |
| `src/server/Services/SaveSlotCrossServer.lua` | New | Save-to-server map, Teleport/arrive, teammate finder |
| `tests/headless/run.luau` | Change | Register the 4 new service modules |
| `tests/studio/Playtest/RunPlaytest.lua` | Change | Runner only |
| `tests/studio/Playtest/Support/Base.lua`, `Saves.lua`, `Fixtures.lua` | New | Helpers |
| `tests/studio/Playtest/Steps/Core.lua`, `Saves.lua`, `RowFill.lua`, `Npc.lua`, `Soak.lua` | New | Steps |
| `docs/TECHNICAL_ARCHITECTURE.md`, `docs/TEST_PLAN.md` | Change | One sentence each, BUILD string |

No config, schema, DataStore key, error code, remote or localization change.

## Steps — part 1: SaveSlotService (line numbers refer to HEAD 5032356)
1. **Line map.** Move the ranges verbatim (comments and section headers included), in their original order within each target file.

| Lines | Content | Target |
|---|---|---|
| 1–34, 47–50, 97–187, 196–247, 258–424, 559–657, 1424–1508, 1803 | header, requires, class, `PROFILE_STORE_NAME`, `SAVES`, `PROFILE_ATTEMPTS`, `LEGACY_SAVE_NAME`, `profileKey`, `new` … `setFinderHandler`, `_listingsChanged`, Profile I/O without `storedProfile` (incl. `_dropMemberEntry`), Registry, `_register` … `_teamChanged`, `_handle`, `handle`, `return` | stay in core |
| 52–76, 89–96, 188–195, 248–257 | `companyIdOf`, `saveIdOf`, `failure`, `newEntry`, `sortedKeys`, `callHandler`, `storedProfile` | SaveSlotShared |
| 35, 520–558, 658–671, 725–863, 1509–1802 | `LEAVE_POLL_SECONDS`, `_listView`, `listFor`, Names (`_filtered`), Actions (`_create`, `_rename`, `_delete`), Play/switch/leave (`_canAttach` … `leave`) | SaveSlotPicker |
| 36–45, 77–88, 672–724, 864–1184 | join constants (`JOIN_FAILURE_ACTION` … `LEAVE_DONE`), `memberEntry`, Records (`_changeRecord`, `_releaseUnused`, `_ensureInviteCode`), `_joinLocked` … `_setSize` | SaveSlotTeam |
| 425–519, 1185–1423 | save-to-server map (`_cachedLocation` … `renewLocations`), cross-server join (`_teleportToSave`, `_arrive`, `arrive`), teammate finder (`_validListing` … `_finderJoin`) | SaveSlotCrossServer |

2. **SaveSlotShared.lua**: `--!strict`, a 2-line header ("Pure helpers shared by SaveSlotService and its parts (CM2-RF)."), the requires its code uses (`SaveProfile` for `storedProfile`), `local SaveSlotShared = {}`, the moved `local function`s unchanged, then one export line per function (`SaveSlotShared.failure = failure`, …) in declaration order, `return SaveSlotShared`.
3. **Each part** (Picker, Team, CrossServer) has this order: `--!strict`; a header comment of at most 4 lines naming its part and "Methods of SaveSlotService, merged by SaveSlotService.lua (CM2-RF)"; `local ReplicatedStorage = game:GetService("ReplicatedStorage")`, `local Shared = ReplicatedStorage:WaitForChild("Shared")` and the requires its code uses; `local SaveSlotShared = require(script.Parent:WaitForChild("SaveSlotShared"))`; `local SaveSlotService: any = {}`; `local SAVES = GameConfig.Saves`; the moved constants; one alias line per shared helper it uses; the moved code; `return SaveSlotService`.
   - Expected requires (selene decides): Picker GameConfig, Protocol, SaveProfile; Team BusinessState, GameConfig, Protocol, SaveProfile; CrossServer BusinessState, GameConfig, SaveProfile. Core keeps GameConfig, Protocol and SaveProfile and drops `BusinessState`.
   - Expected aliases: core failure, saveIdOf, newEntry, sortedKeys, callHandler, storedProfile; Picker failure, companyIdOf, saveIdOf, newEntry, storedProfile, callHandler; Team failure, companyIdOf, saveIdOf, storedProfile, callHandler; CrossServer failure, companyIdOf, saveIdOf, sortedKeys.
4. **Core**: add after line 16 of the header: `-- CM2-RF: the code is split into parts: SaveSlotPicker (slots, picker, play/switch/leave), SaveSlotTeam (co-op members, invite codes), SaveSlotCrossServer (save-to-server map, teleport, teammate finder) and SaveSlotShared (helpers).` Add the `SaveSlotShared` require and aliases after the shared requires. Directly before `return SaveSlotService`:
   ```lua
   -- The parts add their methods to the class (CM2-RF); a name defined twice is a bug.
   for _, part in { require(script.Parent:WaitForChild("SaveSlotPicker")), require(script.Parent:WaitForChild("SaveSlotTeam")), require(script.Parent:WaitForChild("SaveSlotCrossServer")) } do
   	for name, member in pairs(part) do
   		assert(SaveSlotService[name] == nil, "SaveSlotService member defined twice: " .. name)
   		SaveSlotService[name] = member
   	end
   end
   ```
   (stylua formats the list.) No part requires `SaveSlotService`.
5. **run.luau**: add `SaveSlotCrossServer`, `SaveSlotPicker`, `SaveSlotShared` and `SaveSlotTeam` with their `src/server/Services/<Name>.lua` paths to the services map.
6. **TECHNICAL_ARCHITECTURE** "Save slots (CM2-S1)" paragraph: append "Since CM2-RF the code is split into `SaveSlotService` (core) and the parts `SaveSlotPicker`, `SaveSlotTeam`, `SaveSlotCrossServer` and `SaveSlotShared`; the parts add methods to the one class."
7. Run the checks (Acceptance) and then the moved-code check M1 before part 2.

## Steps — part 2: RunPlaytest
8. **Line map** (RunPlaytest.lua at HEAD 5032356). Installer bodies keep the original one-tab indent for Support. Step code loses one tab (it was inside `if mode == "full"`). Only stylua may reflow it.

| Lines | Content | Target |
|---|---|---|
| 1–11, 20–58, 82–84, 773–778, 2638–2726 | header, `RunPlaytest`, `BUILD`, `PREFIX`, `guard`, `validOptions`, `startedAt`/`results`/`outcome`, `type Step`/`steps`/`addStep`, runner loop and summary, `run` | RunPlaytest.lua |
| 12–18, 60–81, 86–579 | constants `SPECIES` … `TELEPORT_PAUSE`, services and config, result, hook, world, walking-customer helpers, actors (`player`, `R`, `S`) … `sameTable` | Support/Base |
| 581–771 except `saveA` | save, co-op and CM2-S3 helpers, `activeSave` | Support/Saves |
| 780–781, 785–983 | `shadowJoined`, `shadowJoin` … `cleanup` | Support/Fixtures |
| 782–783, 986–1463 | `orderA/B/C`, `pickupHome`, steps 01, 02a, 02, 03, 04–21 (with `orderIds`, `orderBays`, `before`) | Steps/Core |
| 1464–1830 (+ `saveB, saveC` from 583, `saveDuo, duoCode` from 660) | steps 24–35 | Steps/Saves |
| 1831–1928 | step 36 | Steps/RowFill |
| 1929–2364 | NPC helpers, steps 37–40 | Steps/Npc |
| 2368–2635 | soak steps 01a … 05 | Steps/Soak |
| 985, 2365–2367, 2636 | `if mode == "full"`, steps 22/23, `else`, `end` | replaced by the runner code in step 11 |

9. **Installer shape** (all 8 new files): `--!strict`; a header comment of at most 3 lines (what it holds, "Installed by RunPlaytest.execute (CM2-RF)", for step modules the step IDs); `return function(ctx: any)`; an import block with one `local <name> = ctx.<name>` per name that the module reads from earlier modules or the runner, in ASCII order; the moved code; for Support modules only, an export block with one `ctx.<name> = <name>` per top-level local, in declaration order (Fixtures does not export `shadowJoined`); `end`. Installers keep no state at file level.
   - Runner-provided names: `PREFIX`, `hook`, `minutes`, `results`, `outcome`, `addStep`.
10. **saveA**: in Support/Saves replace `local saveA, saveB, saveC = "", "", ""` with `ctx.saveA = ""`; in `activeSave` the three `saveA` uses become `ctx.saveA`; in Steps/Saves every `saveA` becomes `ctx.saveA` (9 lines). Steps/Saves starts after its imports with `local saveB, saveC = "", ""` and `local saveDuo, duoCode = "", ""`. Support/Saves drops line 660.
11. **RunPlaytest.lua**: `RunPlaytest.BUILD = "cm2-rf"`. In the header, replace the text from "This module is not under Cases" to the end of line 7 with: "The runner installs helpers from Playtest/Support and steps from Playtest/Steps (CM2-RF); none of them is under Cases, so the unit-test runners never execute them. Nothing touches a game service at load time." Add this module-level function after `validOptions`:
    ```lua
    -- Requires one installer from Playtest/Support or Playtest/Steps (CM2-RF).
    local function installer(group: string, name: string): (any) -> ()
    	local folder = (script.Parent :: Instance):FindFirstChild(group)
    	local module = folder and folder:FindFirstChild(name)
    	assert(module ~= nil and module:IsA("ModuleScript"), "playtest module missing: " .. group .. "/" .. name)
    	return require(module :: ModuleScript) :: any
    end
    ```
    `execute(hook, mode, minutes)` becomes, in this order: `HttpService` and `ServerStorage` via `game:GetService`; `startedAt`, `results`, `outcome` (moved); `type Step`, `steps`, `addStep` (moved); then
    ```lua
    local ctx: any = setmetatable({}, {
    	__index = function(_, key)
    		error("playtest context has no field " .. tostring(key), 2)
    	end,
    })
    ctx.PREFIX = PREFIX
    ctx.hook = hook
    ctx.minutes = minutes
    ctx.results = results
    ctx.outcome = outcome
    ctx.addStep = addStep
    for _, name in { "Base", "Saves", "Fixtures" } do
    	installer("Support", name)(ctx)
    end
    if mode == "full" then
    	for _, name in { "Core", "Saves", "RowFill", "Npc" } do
    		installer("Steps", name)(ctx)
    	end
    	addStep("22", "LEAK_CHECK", { "02" }, ctx.leakCheck)
    	addStep("23", "CLEANUP", {}, ctx.cleanup)
    else
    	installer("Steps", "Soak")(ctx)
    end
    local emit, record, R, player = ctx.emit, ctx.record, ctx.R, ctx.player
    ```
    and then the moved runner block (2638–2694) unchanged.
12. **TEST_PLAN** "Repeatable run": change "BUILD `cm2-n1-fix2`" to "BUILD `cm2-rf`" and append to that bullet: "Layout (CM2-RF): `RunPlaytest.lua` is the runner; helpers live in `Playtest/Support/` (Base, Saves, Fixtures) and steps in `Playtest/Steps/` (Core, Saves, RowFill, Npc; Soak for soak mode). They share one strict context table. New steps go into a Steps module, and a module that would pass 800 lines gets a new one."

## Verification commands (reviewer runs them; BASE = 5032356 unless HEAD moved before implementation started)
- **M1 moved code, SaveSlotService** (Bash, repo root, T = scratchpad):
  `git show BASE:src/server/Services/SaveSlotService.lua | sed 's/^[[:space:]]*//' | LC_ALL=C sort > $T/o1; cat src/server/Services/SaveSlot{Service,Shared,Picker,Team,CrossServer}.lua | sed 's/^[[:space:]]*//' | LC_ALL=C sort > $T/n1; diff $T/o1 $T/n1`
  Allowed in the output: header comments, requires, `local Shared/ReplicatedStorage/SaveSlotShared`, `local SAVES` copies, alias lines, `local SaveSlotService: any = {}`, `local SaveSlotShared = {}`, the export lines, the merge loop, extra `return`/`end`/blank lines. Any other line is a finding.
- **M2 moved code, RunPlaytest**: the same command with BASE `tests/studio/Playtest/RunPlaytest.lua` against `cat tests/studio/Playtest/RunPlaytest.lua tests/studio/Playtest/Support/*.lua tests/studio/Playtest/Steps/*.lua`. Allowed: headers, installer lines, imports, exports, the `ctx` setup and `installer` function from step 11, `ctx.saveA` lines, the BUILD line, the moved local declarations from step 10, and stylua reflows of de-indented step code (same tokens).
- **M3 context names**: in `tests/studio/Playtest`:
  `grep -ohP "\bctx\.\K\w+(?=\s*=[^=])" RunPlaytest.lua Support/*.lua | LC_ALL=C sort -u > $T/w; grep -ohP "\bctx\.\K\w+" RunPlaytest.lua Support/*.lua Steps/*.lua | LC_ALL=C sort -u > $T/r; comm -23 $T/r $T/w` prints nothing.
- **Sizes**: `wc -l` gives RunPlaytest.lua ≤ 400; SaveSlotService.lua and every new file ≤ 800.

## Tests (headless)
No test is added, changed or removed. `lune run tests/headless/run.luau` prints `[SUMMARY] 405 run, 405 passed, 0 failed` after part 1 and after part 2. The SaveSlotService, CoopSave, CrossServer, TeammateFinder and Playtest cases cover the moved code unchanged.

## Playtest (Studio, via playtester)
Tier L → test now. In the same run, also run the queued CM2-13a steps 3–4 (`docs/plans/CM2-13a.md`). Studio instance id: `eca6b61c-4147-497a-93d2-6055d0d96c84`. A 1x1 viewport is fine; nothing here needs a screenshot.
0. Edit mode, Rojo synced to the implementation commit: `ServerScriptService.Server.Services` holds `SaveSlotShared`, `SaveSlotPicker`, `SaveSlotTeam` and `SaveSlotCrossServer`; `ServerStorage.UnitTest.Playtest` holds `Support` (Base, Saves, Fixtures) and `Steps` (Core, Saves, RowFill, Npc, Soak); the `RunPlaytest` source contains `BUILD = "cm2-rf"`. If any of these is missing, the sync is stale (as in PC-5): the run is BLOCKED, not FAIL.
1. Start Play. The server Output shows no error that mentions SaveSlot or "defined twice", and the player gets `ProfileReady = true` within 30 s.
2. `runPlaytest {mode="full"}` → `SUMMARY mode=full steps=41 pass=41 fail=0 skip=0 … result=PASS`. Step 01 reports at least 405 run, and 21 `ART_ASSETS` passes. Output has no `playtest context has no field`, no `playtest module missing` and no `[ART]` warning. This also covers CM2-13a steps 3–4.
3. `runPlaytest {mode="soak", minutes=10}` (after 2 is `done`) → `steps=7 pass=7`. If only 03 (`sales < 10`) or 03a (FPS < 55) fails, with numbers in the detail and no runner or nil error, record it as environment, queue "CM2-RF soak re-run" in "Studio-Test ausstehend" and do not block the commit.
4. Stop Play. Report the BUILD read, both SUMMARY lines and the step lists.

## Acceptance
- Checks (one HEAD per part): `stylua --check src tests tools`; `selene src tests tools` with 0 errors and 0 warnings; `lune run tests/headless/run.luau` 405 run, 0 failed; `rojo build default.project.json --output build.rbxlx`; `rojo build release.project.json --output release.rbxlx`. The release build has no `UnitTest`, `RunPlaytest` or `StudioTestService` and contains the 4 new SaveSlot modules. `lune run tools/art/art.luau verify release.rbxlx` passes.
- M1, M2 and M3 as stated, and the sizes as stated.
- Ticket: public `Save.*` actions, error codes, DataStore keys and the save schema are unchanged; Studio steps 0–2 PASS (41/41); step 3 PASS or the environment rule applies.
- Reviewer: remove the CM2-13a queue entry if step 2 passes.

## Out of scope
CompanyStateService (1342 lines) and WorldService (1197 lines); any rename of methods, errors or log strings; new tests; refactoring inside moved functions; Studio Script Analysis warnings that the original file already had.

# CM2-14WR — Roof tree weld and placement on customer cars

Pipeline `cm2-task`. Everything is decided; if something is missing, stop and report.

## Goal
A loaded customer car leaves with its `RoofTree` resting on the roof rack (lowest part 0.05 above `carCargoTop.Y`) and welded to the car, for every car look on both road sides. Step 73 (d) measures that for real.

## Source of truth
Backlog 18a5 CM2-14WR; plan `docs/plans/CM2-14W.md` Step 3 `attachRoofTree`, Step 4 (d); archived PROGRESS "CM2-SUPC" (f) (`docs/archive/PROGRESS_2026-11-27_to_2026-11-27_SUPQ-SUPC-14W-SLIM3.md`); MODEL_INTEGRATION "Vehicle art in the world (CM2-14W)" (anchor heights 4.0 / 4.0 / 4.6).

Planner finding (put it in PROGRESS): no weld exists (confirmed in code). The placement maths is probably right. With r = max(X, Z)/2 of a 4.025-long roof tree, the values the playtester read, −0.79..−1.03, match `box.Y − size.Y/2` of the pivot-oriented `GetBoundingBox` (r − 2.45 for r of about 1.4–1.66), which measures the lying tree along its length. So the fix does not depend on the pivot or the box: the server measures every part's oriented box, lifts the tree onto the anchor, then welds it. Step 73 checks every `BasePart` (today only `MeshPart`s, so a primitive roof tree reads `math.huge`) and the welds. On main the step fails on the welds at least.

## Implementer tier
Tier: M. Reason: world wiring across a shared module, a service and a playtest step; no save, money, remote or concurrency change, and the cause is pinned above.

## Skill checks
- roblox-building: place parts from the anchor CFrame (`cargoTop`), not world guesses; set anchoring and collision explicitly (roof parts stay Anchored, CanCollide/CanQuery false).
- roblox-building: read the result back. The step measures world part boxes, not pivots or config values.
- roblox-luau-core: `--!strict`, typed signatures, NaN/inf guards in the shared maths; no new loops or connections.
- roblox-npc-ai/performance: no per-frame work added; at most 8 `WeldConstraint`s per leaving car, destroyed with it.
- roblox-tooling: the new checks must fail before the fix (headless red run, playtester stash run), then pass.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/VehicleArt.lua` | Change | `ROOF_CLEARANCE`, `boxBottom`, `roofLift` |
| `src/server/Services/WorldService.lua` | Change | `attachRoofTree`: settle and weld |
| `tests/studio/Cases/VehicleArt_Test.lua` | Change | 2 tests |
| `tests/studio/Playtest/Steps/Vehicles.lua` | Change | step 73 (d) |
| `tests/studio/Playtest/RunPlaytest.lua` | Change | `BUILD = "cm2-14wr"` |
| `docs/MODEL_INTEGRATION.md`, `docs/TEST_PLAN.md` | Change | Step 5 |

## Data and config (`VehicleArt`, PROVISIONAL, visual)
| Key | Value |
|---|---|
| `ROOF_CLEARANCE` | 0.05 (inside the −0.05..0.3 tolerance) |

## Steps
1. **VehicleArt.lua** (after `bundleOffset`, using the local `isFinite`):
   - `VehicleArt.boxBottom(centerY: any, sizeX: any, sizeY: any, sizeZ: any, rightY: any, upY: any, lookY: any): number`. If every argument is finite, return `centerY - (math.abs(rightY) * sizeX + math.abs(upY) * sizeY + math.abs(lookY) * sizeZ) / 2`. Otherwise return `math.huge`, so the part never counts as lowest.
   - `VehicleArt.roofLift(lowestY: any, cargoTopY: any): number`. If both are finite, return `cargoTopY + VehicleArt.ROOF_CLEARANCE - lowestY`. Otherwise return 0.
   - Header comment: add "and how the roof tree settles on the cargo anchor (CM2-14WR)".
2. **WorldService `attachRoofTree`** (keep the existing parts loop and both pose formulas):
   - Remove the early `return` of the primitive branch: `if art ~= "Art" then PivotTo(primitive pose) else PivotTo(art pose) end`.
   - Then add the local `settleOnRoof(roof, top.Y)`, defined just above `attachRoofTree`:
     `local function settleOnRoof(roof: Model, topY: number)`. It loops `lowest = math.huge` over the `BasePart` descendants with `VehicleArt.boxBottom(p.Position.Y, p.Size.X, p.Size.Y, p.Size.Z, p.CFrame.RightVector.Y, p.CFrame.UpVector.Y, p.CFrame.LookVector.Y)`. If `lowest < math.huge`, it calls `roof:PivotTo(CFrame.new(0, VehicleArt.roofLift(lowest, topY), 0) * roof:GetPivot())`.
   - Then add the local `weldToCar(roof, carModel)`. With `root = carModel.PrimaryPart` (return if nil), for each `BasePart` descendant of `roof` create `WeldConstraint` `RoofWeld`: `Part0 = root`, `Part1 = part`, `Parent = part`. Create it after the settle, so the captured offset is final.
   - Update the function comment: "settled so its lowest part is ROOF_CLEARANCE above the anchor and welded to the car's PrimaryPart (CM2-14WR)".
   - Leave everything else alone: the drive `PivotTo`, the `pcall` and `[ART] RoofBuildFailed`.
3. **Step 73 (d)** (`Steps/Vehicles.lua`):
   - `lowest`: `IsA("MeshPart")` → `IsA("BasePart")`, so every part counts. Keep `partBottom`, the test's own copy of the oriented-box maths. Do not call `VehicleArt.boxBottom`.
   - Per `LeavingCar`, after the clearance check:
     - For every `BasePart` in `RoofTree`, check that a child `WeldConstraint` exists with `Enabled`, `Part0 == child.PrimaryPart` and `Part1 == part`. Message: `string.format("%s roof part %s has no weld to the car", label, part.Name)`.
     - Count the parts: `check(parts > 0, label .. " roof tree has no parts")`.
     - Record `rel = child:GetPivot():ToObjectSpace(roof:GetPivot())` in a table keyed by car.
   - After the loop over plots, `task.wait(0.5)` (`CAR_DRIVE_SECONDS` is 2, so the cars are still driving). Then, for each recorded car still parented, the position delta of `child:GetPivot():ToObjectSpace(roof:GetPivot())` against `rel` must be ≤ 0.01. Message: `"%s roof tree slid %.3f on the car"`. Also check the car moved: its pivot moved > 0.1 from the parked pivot recorded before the sync. Message `"%s did not drive off"`.
   - The 5 s poll for no `LeavingCar` stays and still starts after the wait.
   - The header comment for (d): "rests on the cargo anchor (lowest of all parts), welded, moves with the car".
4. `RunPlaytest.BUILD = "cm2-14wr"`.
5. **Docs**:
   - MODEL_INTEGRATION section "Vehicle art in the world (CM2-14W)", roof-tree sentence: append "settled so the lowest part is 0.05 above it and welded (`RoofWeld`) to `PrimaryPart` (CM2-14WR)".
   - TEST_PLAN "Modes": `BUILD cm2-14wr`. Step 73 text: "... leave loaded with the roof tree on `carCargoTop` (lowest `BasePart` −0.05..0.3, every part welded, no slide while driving)".

Order for the red runs (acceptance b, c):
- Write the two headless tests before Step 1 and run `lune run tests/headless/run.luau`. Expect 2 failures; quote the summary line in your report.
- Write Step 3 before Step 2.
- You cannot run Studio. The playtester runs the red Studio check (Playtest 1).

## Tests (headless, `VehicleArt_Test.lua`; total 781 + 2 = **783**)
| Test name | Asserts |
|---|---|
| box bottom of an oriented part | `boxBottom(5, 2,3,4, 0,1,0)` = 3.5. The roof pose `Angles(rad 90,0,0)` (`boxBottom(5, 2,3,4, 0,0,1)`) = 3. A 45° tilt (`0, 0.7071, 0.7071`) = 5 − (3+4)·0.7071/2 ± 1e-6. NaN centre, `"x"` size or `math.huge` up → `math.huge`. |
| roof lift settles the tree on each car look | Car tops 0.82 + {4.0 Hatchback, 4.0 Wagon, 4.6 SUV}. For each, lowest ∈ {top − 1.03, top − 0.79, top, top + 0.4}: `lowest + roofLift(lowest, top) − top` = 0.05 ± 1e-9 (in −0.05..0.3). `roofLift(NaN, 4)` = 0 and `roofLift(1, math.huge)` = 0. |

## Playtest (Studio, via playtester; test now: world wiring)
1. **Red run (acceptance b), before anything is committed.** From the repo root:
   - Run `git stash push -m cm2-14wr-fix -- src/shared/VehicleArt.lua src/server/Services/WorldService.lua tests/studio/Cases/VehicleArt_Test.lua`. The new step 73 stays; the fix goes.
   - Rojo sync, Play, `runPlaytest {mode="smoke", only={"73"}}`. Expect 73 `VEHICLE_ART` FAIL with at least one "has no weld to the car" line.
   - Record the FAIL line(s) word for word, and note any "rests … from the cargo anchor" lines.
   - Stop Play and run `git stash pop`. Confirm with `git status` that the three files are modified again; if the pop conflicts, stop and report.
2. Rojo sync with the fix, Play, `runPlaytest {mode="smoke", only={"73"}}`. Expect PASS and the detail `trucks=<k> cars=<4k>`.
3. **Client reading** (CM2-SUPC hooks), on Plot_01 (facing +1) and Plot_04 (facing −1):
   - Force one order car each with `syncCustomerOrders`, then leave it loaded.
   - On the client, check that the tree lies on the rack, visibly not sunk into the roof, and stays on it while the car drives to the road.
   - Server readback per car: `lowest BasePart bottom − carCargoTop.Y` (expect 0.05 ± 0.01) and the `RoofWeld` count = the roof `BasePart` count.

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (783 passed), `rojo build`.
- (a) Every car look (9301–9304 cover SUV, Hatchback, Wagon) on both road sides: the roof clearance is in −0.05..0.3, every roof part is welded to `PrimaryPart`, and the roof does not slide while the car drives.
- (b) The red Studio run (Playtest 1) shows the step-73 FAIL line; the playtester's report records it and the reviewer copies it into PROGRESS.
- (c) Both headless tests failed before Step 1 and pass after it.
- (d) Smoke `only={"73"}` passes; the client readings pass on Plot_01 and Plot_04.
- The reviewer removes "roof tree FAIL" from the CM2-14W queue entry; the 6-plot facing and `#n` label readings stay (SUPP f).
- No change to rules, saves, remotes, durations or XZ paths.

## Out of scope
Step 64 (c) (keeps its `MeshPart`-only `lowest`), the roof pose formulas, the car art, `CargoAnchor` values, the smoke step 22 leak (18a6), and the phone readings.

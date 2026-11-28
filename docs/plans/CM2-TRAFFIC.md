# CM2-TRAFFIC — Customer cars drive the village road; ambient traffic

Written by `planner-high` (Opus 5.5); pipeline `cm2-task`. Everything is decided; anything missing: stop and report. Lands after CM2-LOTLAY and CM2-PARK (with its Amendment 1).

## Goal
Customer cars enter at the west end of the approach road, cross the bridge and turn into their space; leaving, they back out and drive off the map (west; north-side cars loop round the village tree first). Four ambient cars drive the loop and never enter a lot.

## Source of truth
Backlog CM2-TRAFFIC (a)–(f); DECISION_LOG 2026-11-28 (d). Planner readings (PROVISIONAL): the road ends at the square (no east exit), so cars leave over the bridge; keep right (eastbound z +5, westbound z -5).

## Implementer tier
Tier: L. Reason: shared-road concurrency (driveway locks, merge and crossing grants, deadlock fallbacks) and visit timing against reservations.

## Skill checks
- npc-ai: movement server-side; every wait has a timeout and a fallback; records go when their model goes.
- performance: one Heartbeat driver, no per-car scripts or tweens; write only moving cars (one root CFrame each); measure Hz and `DataSendKbps`.
- streaming: car models `ModelStreamingMode = Atomic`.
- luau-core: iterate cars sorted by id; `--!strict`. architecture: pure logic in `src/shared`, Instances only in the service. collaboration-mode: claim nothing unrun.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/GameConfig.lua` | Change | config below |
| `src/shared/TrafficPath.lua`, `TrafficSim.lua` | New | geometry; kinematics and gates (pure) |
| `src/server/Services/TrafficService.lua` | New | models, driver, ambient |
| `src/server/Services/VehicleWorld.lua`, `WorldService.lua` | Change | rig; cars through traffic; truck start |
| `src/server/Services/CustomerNpcService.lua`, `CustomerNpcWorld.lua` | Change | walk in once parked; cap |
| `src/server/main.server.lua`, `Services/StudioTestService.lua` | Change | start; test commands |

## Data and config
`GameConfig.Traffic` (new, after `Customers`; header: behaviour OWNER DECIDED 2026-11-28 (d), values PROVISIONAL):
`Enabled = true, SpawnX = -480, QueueRoom = 75, LaneZ = 5, RingJoinX = 190, RingCenterX = 235, RingRadius = 21, CruiseSpeed = 45, RingSpeed = 20, TurnSpeed = 15, ParkSpeed = 8, ReverseSpeed = 8, Accel = 20, Decel = 30, CarLength = 9, CarHalfWidth = 2.5, Gap = 4, Lookahead = 80, RightTurnRadius = 10, LeftTurnRadius = 20, StraightDepth = 60, CrossWindow = 70, MergeWindow = 60, GrantTimeoutSeconds = 10, StuckSeconds = 15, MaxMovingCars = 28, AmbientCount = 4, AmbientSpawnSeconds = 8, AmbientHeadroom = 8, TickSeconds = 1 / 30, SampleStep = 1`.
`Npc.CarArriveCapSeconds = 30` (new, longest Arriving); `Npc.MaxVisitSeconds` 360 -> 390 (bound 367). `Npc.ReservationSeconds` stays 165: it starts at the tree pick, after parking. WorldService `TRUCK_START_DEPTH` 66 -> 58 (truck depth 51.5..64.5, off the near lane 67.5..72.5 and off every leg). No schema change.

## Geometry (TrafficPath)
Lot frame: world x = cx + lx, z = cz + f·d (f = facing, |cz| = 75). Near lane depth 70, far lane 80; near-lane direction dn = -f (world x). Space k: X = `CarPark.X[k]`, parked at (X, 40). L = CarLength, G = Gap.
- **Loop** (σ = distance along it): E lane (SpawnX to RingJoinX at z +5); tangent to the ring (centre (235, 0), r 21) at angle a = atan2(5, 190 - 235) - acos(r / |(190,5) - (235,0)|) (= 111.29 deg, (227.37, 19.56)); arc with falling angle to -a; tangent to (190, -5); W lane to SpawnX. Length 1501.8 ± 0.5. σE(x) = x - SpawnX (down to -QueueRoom: spawn queue); σW(x) = length - (x - SpawnX). Lanes CruiseSpeed, tangents and arc RingSpeed; y 0.35 (`VehicleArt.ROAD_TOP`).
- **Right leg** (arrival on the near lane, plots 4-6; reversed for every exit): T = (X - dn·10, 70); quarter arc, centre (X - dn·10, 60), to (X, 60); straight to (X, 40). **Left leg** (arrival on the far lane E, plots 1-3): T = (X - 20, 80); arc centre (X - 20, 60) to (X, 60); straight to (X, 40). Arcs TurnSpeed, straight ParkSpeed, exit samples ReverseSpeed.
- Leg y by lot depth, piecewise linear (A1): (60, 0.35), (58.5, 0.80) (onto `CarPark_DriveL/R`, top 0.80, depth 46..59), (46, 0.80), (45.5, padY); deeper padY. Below depth 59 every leg corner keeps |lx| >= 10 (free corridor x -10..10); the straights (X ± 2.5) and arc ends satisfy it by construction.
- Xm = world x of the right leg's T (exit end, nose dn); Xc = cx + X (left leg crosses the near lane W).
- Samples every SampleStep: `{x, y, z, lookX, lookZ, speed, sigma: number?}`; look = nose (exit: opposite of motion); loop samples carry sigma.

API: `export type Plot = {id: string, cx: number, cz: number, facing: number, padY: number}`, `Pose = {x, y, z, lookX, lookZ}`. `loop()` (cached `{samples, length}`), `sigmaE(x)`, `sigmaW(x)`, `arrival(plot, space)` -> `{samples, kind: "Right"|"Left", sigmaT, sigmaCross: number?, arcEnd}` (arcEnd = index of (X, 60)), `exit(plot, space)` -> `{samples, sigmaMerge}`, `parkedPose(plot, space)` (= `WorldService.parkedAt`, look (0, -f)), `corners(pose)` (9 x 5 car rectangle).

## Steps
1. **GameConfig**: values above.
2. **TrafficPath.lua** (`--!strict`, requires GameConfig only): as above.
3. **TrafficSim.lua** (`--!strict`, pure, clock = summed dt). `TrafficSim.new(options?)` (overrides `Traffic` keys).
   - API: `arrive(id, plot, space, direct?): boolean`, `parked(id, plot, space)`, `depart(id): boolean` (false: unknown; a Lane arrival is parked first), `ambient(id): boolean`, `ambientAtForTest(id, sigma)`, `forcePark(id): boolean`, `remove(id)` (frees driveway and pad), `step(dt): {Event}` (`Event = {id, kind: "Parked"|"Despawn", fallback: boolean}`), `pose(id): Pose?`, `isParked(id)` (unknown: true), `padFree(plotId, space)`, `stats(): {moving, parked, ambient, fallbacks, maxMoving}`, `snapshot()` (sorted `{id, kind, state, plotId, space, x, z}`), `holdDrivewayForTest(plotId, held)` (both sides).
   - States `Lane` (moving), `Parked`, `WaitExit`. Route = sample array with braking profile `cap[i] = min(speed_i, sqrt(cap[i+1]^2 + 2·Decel·step))`: arrival = loop [σ0, σT] + arrival leg; exit = exit leg + loop [σMerge, end]; ambient = loop [σ0, end].
   - Spawn: σ0 = 0 (direct: σT - (L+G)); while a car or virtual obstacle is within L+G of σ0, σ0 = its σ - (L+G); more than QueueRoom back -> false. v0 = CruiseSpeed (direct 0). `arrive` false if not `Enabled` or moving >= MaxMovingCars; `ambient` false if moving >= MaxMovingCars - AmbientHeadroom.
   - Tick per Lane car: `stop` = min(closed gate, nearest obstacle σ - (L+G), route end); `v = min(v + Accel·dt, cap(s), sqrt(2·Decel·max(0, stop - s)))`; `s = min(s + v·dt, stop)`. Obstacles: cars on a loop sample and virtual obstacles with 0 < σo - σ <= Lookahead (equal σ: larger id ahead).
   - Virtual obstacles: an arrival from leg start to `arcEnd` at σT, a Left one also at σCross = σW(Xc) from its cross grant to `arcEnd`; an exit at σMerge from its merge grant to its first loop sample.
   - Driveway per plot side (A1: key plotId .. "L" for X < 0, "R" for X > 0) `{id, kind: "In"|"Out", committed}`; pad per (plot, space); opposite plot = known plot, same cx, -facing; "opposite driveway" means either side of it.
   - **Hold** (arrival at σT - (L+G)): its side's driveway nil and `padFree`; takes it `In` (committed for Right). **Cross** (Left, at σT): nothing in σ [σCross - CrossWindow, σCross + L+G], no opposite driveway `Out`; commits. **Merge** (WaitExit): its side's driveway nil, moving < MaxMovingCars - 2, nothing in [σMerge - MergeWindow, σMerge + L+G] except cars at the Hold gate of the same plot and space, and for near lane E no opposite driveway committed `In`; takes it `Out`, frees the pad.
   - Releases: arrival at route end -> `Parked`, pad taken, driveway freed, event Parked; exit on its first loop sample frees the driveway; exit or ambient at route end -> Despawn.
   - Fallbacks (counted): Hold/Cross wait > GrantTimeoutSeconds or a Lane arrival with v < 0.1 for StuckSeconds -> `forcePark`; WaitExit > GrantTimeoutSeconds or a stuck exit/ambient -> Despawn. `forcePark` and `parked` despawn a leaver of that pad (WaitExit or exit leg), free its own driveway, pose = parked, event Parked; a non-leaver on the pad: park anyway.
4. **TrafficService.lua**: `start(worldRoot, makeCar: (parent, name, pose: CFrame, n) -> Model)`: folder `Traffic` under `worldRoot`; one Heartbeat connection stepping the sim every TickSeconds (dt <= 0.2).
   - Attributes `TrafficId` ("car:<n>"), `TrafficKind` (Customer/Ambient), `TrafficState`. Moving cars: `root.CFrame = CFrame.lookAt(p, p + look) * root.PivotOffset:Inverse()`. Despawn destroys the model.
   - Each tick: a model without Parent -> `sim:remove`; a WaitExit car not under `Traffic` is reparented there.
   - Ambient: each second, while alive < AmbientCount and AmbientSpawnSeconds passed: `makeCar(Traffic, "AmbientCar_"..n, pose, 1000 + n)`; refused -> destroy.
   - API: `arrive(car, plot, space): boolean`, `parked`, `depart(car)` (unknown car: destroy), `isParked`, `forcePark`, `padFree`, `setMode("road"|"direct")` (default road), `snapshot`, `stats`.
   - A sim error (pcall) or `Enabled == false`: warn once `[ChristmasMarket2] TrafficDisabled <reason>`, snap arrivals parked, destroy the rest; then `arrive` false, `depart` destroys, `isParked` true.
5. **VehicleWorld.rig(model)** (end of `car`, before parenting): PrimaryPart anchored; other BaseParts `Anchored = false`, `Massless = true`, `WeldConstraint` "CarWeld" (Part0 root) in each; `ModelStreamingMode = Atomic`. Truck unchanged.
6. **WorldService**:
   - `trafficPlot(plot)` = `{id = plot.Name, cx, cz, facing = plotFacing(plot), padY = lotTop(plot) + PARKING_RISE}`; `startTraffic()` = `TrafficService.start(world, VehicleWorld.car with VEHICLE_CTX)`.
   - `spawnVisitCar`: car at the spawn pose in `ordersFolder(plot)`, `TrafficService.arrive`; false -> `PivotTo(parkedAt)` + `parked`. `dismissVisitCar`: rename `LeavingCar`, `depart`.
   - `syncCustomerOrders`: a leaving order car `depart`s (roof tree first); a new order car is built at `parkedAt` and `parked` (no drive).
   - `attachRoofTree`: after `weldToCar`, roof parts `Anchored = false`, `Massless = true`.
   - New `visitCarParked(car)`, `forceParkVisitCar(car)`. Remove `roadEntry`, `CAR_DRIVE_SECONDS`; `drive` stays for the truck.
7. **CustomerNpcService** `STEP.Arriving`: nothing before CarArriveSeconds; then WalkingIn if `_carParked(visit)`, else at CarArriveCapSeconds the optional `forceParkCar(plotId, visitId)` and WalkingIn. `_carParked`: no `world.carParked` -> true; pcall error -> true; else result ~= false. Optional calls never warn. **CustomerNpcWorld**: `carParked(visitId)` (no car or no Parent: true), `forceParkCar(_plotId, visitId)`.
8. **main.server**: `WorldService.startTraffic()` after `WorldService.build()`.
9. **StudioTestService**: `trafficMode({mode})` (else `BadArgument`); `trafficSnapshot()` = `{cars, stats}`; `trafficLoad({seconds})` (10..120, default 60; `Busy` if `npc:count() > 0`): every 5 s per plot `spawnVisitCar(plotId, 900000 + n, k)` on the lowest `padFree` space, `dismissVisitCar` 10 s after parked; Heartbeat Hz and `Stats.DataSendKbps` in 5-s windows; then <= 60 s for its cars to despawn, destroy the rest; returns `{spawned, maxMoving, fallbacks, minHz, meanHz, meanSendKbps, left}`.
10. **Playtest**:
    - `Support/Fixtures.lua` preflight: `call("trafficMode", {mode = "direct"})` (keeps existing step timings; Studio-only).
    - Step 73 (d): instead of the 0.5-s check, sample every 0.25 s for <= 40 s: every LeavingCar moves > 0.1 from its parked pivot and reaches 30 studs or is destroyed; roof slide <= 0.01 at every sample (cars leave one at a time per plot). The 5-s CustomerOrders poll stays.
    - New step 80 `TRAFFIC_ROAD` (`Steps/Vehicles.lua`, needs 03, `withNpcCleanup`, customers paused as in step 78), `trafficMode road`: (a) `npcVisit(8)`: first `VisitCar_` pivot x <= SpawnX + 5; parked at `parkedPose` (0.05) within CarArriveCapSeconds; WalkingIn first seen with `TrafficState == "Parked"`. (b) `npcGiveUp`: the car reaches its near lane (abs z 5 ± 0.5) and is destroyed only at x <= SpawnX + 10. (c) within 40 s `AmbientCount` `AmbientCar_`; for 20 s (0.25 s) none inside a `Cars_<i>` keep-out box. (d) over (a)-(c) moving cars stay >= 8.9 apart. (e) `trafficLoad {seconds = 60}`: fallbacks 0, left 0. Restore `direct` (also on failure); return `arrive=<s> min=<d> hz=<mean>/<min> kbps=<k>`.
11. **Docs**: TECHNICAL_ARCHITECTURE §2 bullet "Traffic (CM2-TRAFFIC)" (loop, legs, gates, fallbacks, driver, Arriving cap); MODEL_INTEGRATION vehicle lines (welded root, Atomic, truck start 58); TEST_PLAN line 85 (full = 81 steps; 73 (d), 80); DECISION_LOG entry "CM2-TRAFFIC road traffic" (west exit, keep right, left turns for plots 1-3, truck start, server-side ambient, direct mode in playtests); PROGRESS entry.

## Tests (headless)
Updates: `GameConfig_Test` MaxVisit bound uses `CarArriveCapSeconds` (not `CarArriveSeconds`) and asserts `CarArriveCapSeconds >= CarArriveSeconds`; `Playtest_Test` full-run counts +1 if it counts them. Any other failure: stop and report.

New (+10). Plots = `MapLayout.PLOTS`, padY 0.82. "Clear" = no footprint corner or centre inside the car rectangle inflated by 0.3 and no rectangle boundary point (every 0.5) inside the footprint inflated by 0.3.
| File | Test | Asserts |
|---|---|---|
| `TrafficPath_Test` | the loop runs entry, ring, exit on the road | starts (SpawnX, 5) look +x, ends (SpawnX, -5) look -x; length 1501.8 ± 0.5; samples inside Road, `ApproachRoad`, `Square` or bridge (x -246..-190, abs z <= 8); clear of `MapLayout.pieces()` except CoveredBridge; ring >= 20.1 from (235, 0) |
| `TrafficPath_Test` | legs stay on the road and the car park | 6 plots x 4 spaces: Right for facing -1, Left for 1; arrival ends at `parkedPose`, exit starts there, ends at Xm with look dn; samples inside Road or the plot's `Cars_<i>`; clear of map pieces, `Progression.fenceBoxes(6)`, `LotArt.gatePostBoxes()`, `ParkingArt.footprints()` (mapped to world) |
| `TrafficPath_Test` | cars stay out of the walk area and the gate corridor | every leg sample's `corners` at lot depth >= 35.5 - 1e-6; corners at depth < 59 have abs lx >= 10 - 1e-6 |
| `TrafficSim_Test` | a free-road arrival parks within 22 s | each plot and space alone: Parked <= 22 s at `parkedPose`, no fallback |
| `TrafficSim_Test` | a busy road keeps spacing and drains | 4 ambient 8 s apart; plot i spaces 1-4 at t = 5(k-1) + 0.7i; each departs 20 s after Parked; dt 1/30 to 300 s: arrivals parked <= 30 s after spawn; exits despawn at (SpawnX, -5); fallbacks 0; each tick two cars not both Parked/WaitExit >= 8.99 apart; moving <= MaxMovingCars |
| `TrafficSim_Test` | a left turn yields to oncoming traffic | plot 2 space 1 direct arrival, `ambientAtForTest` at σCross - 50: the arrival stays at σT until it passes; >= 8.99 apart |
| `TrafficSim_Test` | blocked waits fall back | plot 5: A parked on space 1, `depart(A)`, `holdDrivewayForTest`; direct arrival B to space 1: A despawned by 10.5 s, B Parked by 22 s, fallbacks 2 |
| `TrafficSim_Test` | the moving cap refuses arrivals | `new({MaxMovingCars = 2})`: third `arrive` false, `ambient` false |
| `CustomerNpcService_Test` | a customer walks in only once its car is parked | `carParked` false: Arriving at 2.5 s and 10 s; true: next step WalkingIn |
| `CustomerNpcService_Test` | the arrival cap force-parks the car | `carParked` always false: WalkingIn at 30 s, `forceParkCar` once |

## Playtest (Studio, via playtester)
1. Smoke + steps 37, 40, 73, 78, 80 -> PASS, 0 snaps.
2. PROGRESS: step 80 readings, client FPS during `trafficLoad` (unreadable: BLOCKED with reason); screenshots: car on the bridge, turning in, backing out, ambient car at the village tree.
3. Full `runPlaytest {mode="full"}` -> 81 steps PASS (counts in PROGRESS).

## Acceptance
- `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (count after CM2-PARK + 10, all passing), `rojo build`.
- Backlog (a)–(f); lanes live in `TrafficPath`/`GameConfig.Traffic`, not MapLayout. Arriving never exceeds CarArriveCapSeconds; no order or money path changes.

## Out of scope
A visible held car (`heldSince`), a truck on the road, client-side traffic, an east exit, car lights or sounds.

## Amendment 1: split car park (CM2-PARK Amendment 1, owner 2026-11-28)
CarPark `X = {-13.5, 13.5, -22.5, 22.5}`, corridor x -10..10 free, `CarPark_DriveL/R` top 0.80 (depth 46..59), Cars keep-out x -26..26, poles 05/07/09 at lot x 35. Folded into the body (marked A1): leg y profile, corridor rule and test, driveway lock per plot side. Everything else is symbolic in `CarPark.X` and stays. Recomputed by hand (the tests prove it): leg x spans cx-42.5..cx+32.5 (columns stay >= 35 apart); right-leg arcs of spaces 2/4 (dn +1) and left-leg arcs keep corners at depth < 59 at |lx| >= 11.5; adjacent pads 9 apart (spacing invariant 8.99 holds); truck (x 43..49) >= 8 from the space-4 exit arc; pole 07 (x 34.5..35.5) 9.5 from the space-4 straight. Worst free-road arrival (plot 3, space 4) ~19.8 s, under 22. The clearance tests read `MapLayout.pieces()` and `ParkingArt.footprints()`, so the moved poles and fixtures are covered; the drive slabs are road, not obstacles. Headless count unchanged (+10).

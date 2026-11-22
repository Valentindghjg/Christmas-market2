# CM2-N1 — Walking customer NPCs (covers CM2-19, CM2-22, CM2-23)

Written by: `planner` (Opus 5.5, high). Implemented by: the agent for the tier below. Playtested by: `playtester` (Sonnet 5.5, medium). Reviewed and committed by: `reviewer` (Opus 5.5, medium). Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

Status 2026-11-22: steps 1–12, Amendment 1 and Fix round 1 are implemented in the working tree (uncommitted, headless 379/379). Fix round 2 is open. Precedence: Fix round 2 > Fix round 1 > Amendment 1 > the base sections. Details that were superseded or that only restate the code were cut from this file (compression, 2026-11-22). The working tree and the DECISION_LOG entries "Walking customer NPCs, CM2-N1" and "CM2-N1 fix round 1" are the reference for them.

## Goal
Customers are visible R15 avatars in varied winter clothing. A customer drives into a free parking space and walks onto the lot. They browse, pick a tree (it shows RESERVED), carry it to the counter, queue, pay, and then wait at their car until the existing G1 loading flow sends the car away. Every NPC, its car and its tree disappear on leave, save switch, reload and shutdown.

## Source of truth
- PRODUCT_SPEC 2026-11-21, Gameplay: "Customers: visible walking NPCs (R15, winter clothing) … arrive by car, browse, pick a tree, carry it to checkout, queue, pay, wait at the car (G1)". Reviews come in CM2-G15, manual checkout in CM2-N2, and fewer customers at night with the day/night task.
- REFERENCE_GAME_LIVE_TEST §3.5, §3.6, §3.7, §9.
- DECISION_LOG G1/G2 (orders wait at the car, parking caps customers), CM2-G14 (lot frame, `Stocking.facing`, KeepClear boxes, RESERVED label built on the server).
- Backlog launch order 9, plus the hand-over to order 10 (CM2-N2) and reuse by order 12 (CM2-25/26).

## Implementer tier
Tier: L. Reason: the reservation lasts for the walk and is settled in a later, separate transaction (exactly once), with runtime parking claims, an orphan sweep and reservations cleared on load. Fix round 2 itself is small (placement levelling plus a playtest check), but it lands in the same uncommitted L change set, so the tier stays L.

## Skills to load
roblox-collaboration-mode (first), roblox-npc-ai, roblox-performance, roblox-physics, roblox-animation-vfx, roblox-building, roblox-networking, roblox-security, roblox-data, roblox-architecture, roblox-luau-core, roblox-luau-patterns, roblox-luau-types, roblox-localization, roblox-tooling, roblox-studio-mcp (playtest). CLAUDE.md wins on conflicts (5: no Toolbox or catalog assets; 10: every new key needs `en` and `de`).

## Fix round 2 (2026-11-22, after the `cm2-n1-fix1` run; wins over everything below; tier stays L)
Evidence: full 40/41 twice (only FAIL `37 NPC_WALK | Plot_01 stand exceeds KeepClear (x -11.1..-4.9, z -24.0..16.0)`, raised by P6 before the waves), soak 7/7. Inspection: one MeshPart `Market_FirstAge_Level1`, Size (32.4, 11.0, 24.4), at yaw −44.4° on plots 1–3 and +135.6° on 4–6; no PrimaryPart.

| # | Finding | Cause (decided from WorldService and the evidence) | Fix |
|---|---|---|---|
| Q1 | The stall is tilted ~45° on every plot | **Placement defect.** `salesStand` only translates the clone (`PivotTo(pivot + offset)`), so it keeps the yaw of the Studio-only CC0 template `ArtAssets/Buildings/MarketStarter`. `faceRoad` adds the 180° on plots 4–6 correctly. The tilted world AABB (~40 × 40: x −28.1..12.1, z −24..16) reaches into the Parking box (minZ 13) and the Checkout box (minX 11). Levelled, the part spans x −24.2..8.2, z −16.2..8.2 = KeepClear `Stand` ± 0.2, so KeepClear was drawn for the level stall and stays unchanged. | G1, G2 |
| Q2 | P6 reported a 6.2 × 40 box | **Check defect as well.** P6 maps two opposite corners of the rotated `GetBoundingBox()` into the lot frame. That gives a diagonal, not an AABB. | G3 |
| Q3 | Fix round 1 R1 said the model "spans x −24.2..8.2, z −16.2..8.2" | Wrong: that is the part's local size, not the placed model. The R1 stall point (−13.4, −16.0) lies on the edge of the tilted stall, so the tilt is the likely cause of the round-1 stall. Clearance 3, CounterClearance 1.5 and `LotStructure` stay as defence in depth (soak 0 snaps). | G5 |

Code fixes:
- **G1 `ArtLibrary.levelYaw(rightX: number, rightZ: number): number`** (pure, `src/shared/ArtLibrary.lua`). It returns the Y rotation in radians that turns a part with this RightVector to the nearest half turn:
  - if `math.sqrt(rightX * rightX + rightZ * rightZ) < 1e-3`, return 0;
  - `local yaw = math.atan2(-rightZ, rightX)` (`CFrame.Angles(0, θ, 0).RightVector = (cos θ, 0, −sin θ)`);
  - `return math.floor(yaw / math.pi + 0.5) * math.pi - yaw`.
  - A half turn (not a quarter turn) keeps the part's local X along lot X, which is the axis KeepClear `Stand` was drawn for (32 × 24).
- **G2 WorldService `local function levelArt(model: Model)`**, placed above `salesStand`:
  - Reference part: the BasePart descendant with the largest `Size.X * Size.Z` (the first in `GetDescendants()` order on ties). With no BasePart, return.
  - `local delta = ArtLibrary.levelYaw(ref.CFrame.RightVector.X, ref.CFrame.RightVector.Z)`.
  - If `math.abs(delta) > 1e-4`: `local c = model:GetBoundingBox().Position`, then `model:PivotTo(CFrame.new(c) * CFrame.Angles(0, delta, 0) * CFrame.new(c):Inverse() * model:GetPivot())`.
  - Then, when `model.PrimaryPart == nil`: `model.WorldPivot = CFrame.new(model:GetPivot().Position)`, so `GetBoundingBox` is lot-aligned.
  - `salesStand`'s art branch calls `levelArt(model)` right after `model.Parent = parent` and before the existing centring. This covers `build` and `applyHQVisual`. Do not call it in `tent` (already level) or `cloneArt` (decor, out of scope). `faceRoad` is unchanged.
- **G3 RunPlaytest `checkStandsAndCharacter` (P6)**:
  - Replace the two-corner lines with an AABB over every BasePart descendant of the tent. For each part, take its 8 corners `d.CFrame:PointToWorldSpace(Vector3.new(sx, sy, sz) * d.Size / 2)` with sx, sy, sz ∈ {−1, 1}, map each with `NpcPath.fromWorld(c, p.X, p.Z)`, and take min/max over all of them.
  - No BasePart → `"<plotId> stand has no parts"`.
  - After the bounds check, take the reference part `ref` (G2 rule), `local rv = ref.CFrame.RightVector`, `local delta = ArtLibrary.levelYaw(rv.X, rv.Z)`, and require `math.abs(delta) <= math.rad(1)`, else `string.format("%s stand not lot-aligned (%.1f deg)", plotId, math.deg(delta))`.
  - Add `local ArtLibrary = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ArtLibrary"))` beside the NpcPath require (line 68). The exceeds message, the LotStructure check and the character check stay as they are.
- **G4** `RunPlaytest.BUILD = "cm2-n1-fix2"`; unit-runner check `totals.run >= 380` (message "expected >= 380").
- **G5 Docs.** DECISION_LOG: new entry "CM2-N1 fix round 2 (engineering)" with Q1–Q3, G1–G3 and the rule "art sales stands are levelled to the nearest half turn of their largest part; KeepClear `Stand` unchanged; it supersedes fix round 1's R1 footprint sentence". Do not edit the older entries. TEST_PLAN "Repeatable run": BUILD `cm2-n1-fix2`, "at least 380", and step 37's stand sentence becomes "lies within KeepClear `Stand` ± 0.5 (AABB over every part's corners) and is lot-aligned (±1°)". MODEL_INTEGRATION: append to the CustomerRig note's paragraph: "Sales stands: `WorldService.salesStand` levels the art's yaw to the nearest half turn of its largest part (CM2-N1 fix round 2), so a Studio-only template's rotation cannot tilt the stall."

Headless test delta (expected total **380** = 379 + 1):
| File | Test | Asserts |
|---|---|---|
| ArtLibrary_Test (5 → 6) | levelYaw snaps a part's yaw to the nearest half turn | With `rv(deg) = (math.cos(math.rad(deg)), -math.sin(math.rad(deg)))`, `math.deg(levelYaw(rv(a)))` is within 1e-6 of b for (a, b) = (−44.4, 44.4), (135.6, 44.4), (0, 0), (180, 0), (−170, −10), (100, 80); `levelYaw(0, 0) == 0` |

Playtest (playtester, one Play session; wins over P8 and the "Playtest" section):
1. full → soak → full, BUILD `cm2-n1-fix2`, no manual cleanup in between. Expected: `mode=full steps=41 pass=41 fail=0` twice (unit runner ≥ 380; step 37 now runs its waves; 37–40 PASS) and `mode=soak steps=7 pass=7 fail=0` (03 `npc snaps 0`, 03a spawned 24, peak 24, 12 windows, every window ≥ 55 FPS, snaps 0, left 0).
2. **V1 visual evidence for CM2-UV (j)**, after the second full run, Play still running (PC-3 resolved: viewport 1564 × 730):
   - Server VM: `local h = game.ServerStorage.StudioTestHook; h:Invoke("pauseCustomers", true); task.spawn(function() h:Invoke("npcLoadTest", { seconds = 20 }) end)`.
   - Wait 3 s. Client VM: `local cam = workspace.CurrentCamera; local c = workspace.ChristmasMarketWorld.Plots.Plot_01.PrimaryPart.Position; cam.CameraType = Enum.CameraType.Scriptable; cam.CFrame = CFrame.new(c.X, c.Y + 60, c.Z) * CFrame.Angles(-math.pi / 2, 0, 0)`.
   - `screen_capture` twice, 2 s apart. Then client: `cam.CameraType = Enum.CameraType.Custom`. After 25 s, server `npcSnapshot` must show `count == 0`.
   - PASS when both captures show the stall's edges parallel to the lot edges and fence (not diagonal), the stall not overlapping the parking pads or the counter, and at least one avatar on the walkway. Also record which way the stall's open front faces (toward the road or away from it). A front facing away is a CM2-UV (j) finding for a follow-up, not an N1 FAIL. Capture timeout or a black image → BLOCKED with the reason.
   - Routing: the reviewer records V1 in PROGRESS under CM2-UV (j) ("stall aligned, customer walking"). The other (j) items stay with CM2-UV (j): close-ups of varied avatars, the carried-tree pose, RESERVED while walking, the queue, "Thanks so much!", "#N HERE", and the phone, tablet and PC sizes.

## Fix round 1 (2026-11-22, compressed; implemented)
| # | Finding | Fix |
|---|---|---|
| R1 | Stall at lot (−13.4, −16.0) on Plot_01. The footprint sentence is superseded by Fix round 2 Q3. | F1, F2, F4 |
| R2 | A leg that starts inside an inflated box walked straight to the first corner | F3 |
| R3 | 03a: 12 load snaps from corner cutting at ArriveRadius 1.5 | F2, F4, F5 |
| R4 | Step 37 failed mid-wave, so its saved cars and orders blocked 38/39 and the leak check; after a restart `clockOffset` = 0 could not expire them | P1–P4 |
| R5 | 03a spawned 22 because real visits were still live | P2 |
| R6 | 12 real customers, no sale: expected demand (1 in 12 profiles wants Douglas Medium); balance stays with CM2-35 | P5 |
| R7 | `CompanyStateService … 'Cashier'` × 2: the deliberate fail-closed unit tests | none |
| R8 | Existing characters kept the Default group | F6 |

- **F1** `Npc.Clearance = 3`, `CounterClearance = 1.5`, `CornerRadius = 1`, `Path.AisleDepth = 12`, `CollisionGroups.Structure = "LotStructure"`.
- **F2** `NpcPath.obstacles`: Stand and Bays inflated by Clearance, Counter by CounterClearance. **F3** `route` starts with the pushed start when `pushOut` moved `from`.
- **F4** `LotStructure` group (Npc ↔ Structure false) on every `salesStand` result, `checkout` and `Receiving`.
- **F5** Director: intermediate waypoints advance within CornerRadius (or ArriveRadius once stopped < 0.05); `_snapLog` (last 20) and `customerSnaps` in `snapshot()`; `setArrivalOverrideForTest`; `resetForTest(companyId?)`.
- **F6** `onPlayerAdded` assigns an existing character (`NpcGroupAssigned` guard). **F7** `snapshotForTest.clock`. **F8** hooks `npcReset`, `npcNextArrival {userId, profile}`. **F9** docs.
- Tests (+4, total 379): pushed-start route, CornerRadius advance, arrival override, `resetForTest`; extra asserts in NpcPath, GameConfig, stuck-leg and npcArrive tests.
- **P1** `resetCustomers()`: pause, `npcReset`, expire R's (and S's) orders from `snapshot.clock` (≤ 3 rounds), then poll ≤ 8 s for clean plots; never loads an order or changes cash. **P2** it runs at the start of PREFLIGHT, in soak 03a (which needs `spawned == 24`) and at the start of cleanup. **P3** `withNpcCleanup` wraps 37–40 (the step's error wins). **P4** soak 03 unpauses; soak 04 only expires orders.
- **P5** step 40 NPC_REAL_ARRIVAL: `ensureDouglas(2)`, `npcNextArrival {R, 8}`, unpause, a live visit with customer number 8 within 12 s, 10 states, 0 snaps, the player loads its order, sales +1. **P6** step 37 first checks the stands (now G3), their `LotStructure` parts and the player's `PlayerCharacter` parts. **P7** soak 03 FAILs on a `customerSnaps` delta > 0.

## Amendment 1 (2026-11-22, compressed; implemented)
| # | Decision |
|---|---|
| 1–3 | `Npc.LoadSeconds = 60`; `Fsm.LoadLoop = {timeout = LoadSeconds, onTimeout = "Departing"}`; `spawnLoad(plotId, count, seconds?) -> spawned` (`min(count, plot room, server room)`). Load NPCs have no car, claim or company call and loop door(((i − 1) % 4) + 1) → aisle → `queueSlot(4)` → door. `clearLoad()` hard-removes the rest and returns the number removed. |
| 4 | Hard remove: despawn, destroyCar, leave the queue, `npcDepart`, delete; reservations stay until `npcSweep` or the reload clear. |
| 5 | `Fsm.onTimeout` holds the success exit (Browsing → WalkingToTree, CheckingOut → WalkingToCar, Departing → `"Done"`). |
| 6 | After `shutdown()`: `arrivalPass` → 0 (no sweep), `tick` no-op, `spawnForTest` → `NpcBudget`, `spawnLoad` → 0. |
| 7 | `spawnForTest` checks: stopped → `NpcBudget`; no plot → `CompanyUnavailable`; budget → `NpcBudget`; then the `npcArrive` codes. |
| 8 | World adapter: `spawnCar(plotId, visitId, space, seq)`, `adoptCar(plotId, visitId, n)`, `dismissCar`/`destroyCar(plotId, visitId)`, `spawnAvatar(plotId, visitId, seq, door)`, `moveTo`/`snapTo(visitId, p)`, `position(visitId) -> Point?`, `holdTree(visitId, sizeId)`, `dropTree`/`say`/`despawn(visitId)`; unknown IDs are no-ops. |
| 9–11 | A failed `npcSettle` sets `reserved = false` before WalkingOut (no second abandonment). `onSold` adopts the car and stores `orderNumber`, and Departing with an order skips `dismissCar`. Every world call runs in one pcall wrapper that warns `NpcWorldFailed` once per method. |
| 12 | `snapshot().loadSnaps`; `npcLoadTest` reports snaps = after − before, windows = `floor(seconds / 5)`, `peakLive` sampled at each window end. |

## Decisions (settled)
| Topic | Decision |
|---|---|
| Avatars | One template from `Players:CreateHumanoidModelFromDescription(HumanoidDescription.new(), R15)` (lazy, pcall), no catalog asset IDs; one clone per customer; palette body colours; our own welded beanie, pompom and scarf Parts. Staff reuse `NpcAvatar.build(look)`. |
| Animation | First-party R15 Walk `rbxassetid://507777826` and Idle `rbxassetid://507766388` on the server Animator; without them the NPC glides and `NpcAnimationFailed` warns once. |
| Movement | `Humanoid:MoveTo` along `NpcPath.route` waypoints in the lot frame (no PathfindingService); re-issued every `ReissueSeconds`; reached within `ArriveRadius` (corners: F5). |
| Collisions | Groups `CustomerNpc`, `LotTree`, `PlayerCharacter`, `LotStructure` (F4). NPCs do not collide with each other, trees, players or structures; players still collide with trees and structures. |
| Ownership | Unanchored NPC parts, `SetNetworkOwner(nil)`; cars anchored and lerped; the carried tree welded, Massless, non-colliding. |
| Reservation | Reserve on pick (end of Browsing) for `ReservationSeconds = 120` with `customerId = visitId`; settle once through `completeReservedSale` + `createFromSale` in `npcSettle`; a give-up calls `npcCancel`. |
| Orphans | `BusinessState.migrate` clears `state.reservations` on every load; `npcSweep` on every arrival pass removes `visit:` reservations and claims without a live visit. `SCHEMA_VERSION` stays 13. |
| Parking | Runtime `session.npcClaims = {[space] = visitId}`; `activeCustomers = orders + max(#reservations, #claims)`; free-space functions skip claims; the order keeps the visit's space. |
| Arrivals | One per live company every 5 s when ≥ 1 unreserved tree is shown, a space is free and the budget allows; full parking with trees counts a drive-past. The Cashier no longer adds arrivals; `simulateCustomerVisits` stays a test path only. |
| Budget | `MaxPerPlot = 4`, `MaxPerServer = 24`; load NPCs count; no LOD. |
| Counter until N2 | Queue head at slot 1 is settled after `AutoCheckoutSeconds = 3`; N2 sets `autoCheckout = false`. |
| After paying | The carried tree goes, the pickup tree appears via `syncCustomerOrders`, "Thanks so much!" shows for 3 s (OBSERVED), and the NPC waits at its car door until the order is loaded or expires. |
| Visit car | `VisitCar_<seq>` at arrival; `adoptVisitCar` renames it to `CustomerCar_<n>` before the orders notification; without a sale it leaves as `LeavingCar`. |
| Mirroring | World = `(c.X + x, c.Z + Stocking.facing(c.Z)·z)`. |
| Session identity | A fresh `token` per `loadCompany`; a token, session or plot mismatch → hard remove without a transaction. |
| Footprint | KeepClear is the single source for placement and routing; P6/G3 check the real stand on all six plots; HQ tiers (CM2-G9/G19) must update KeepClear. |

## Files
| File | Purpose |
|---|---|
| `src/shared/GameConfig.lua` | `Customers.Npc` (values in the working tree, F1 deltas) |
| `src/shared/NpcPath.lua`, `src/shared/NpcLook.lua` (new) | Pure lot-frame points, obstacles, router, conversions; deterministic looks |
| `src/shared/ArtLibrary.lua` | **Fix round 2:** `levelYaw` |
| `src/shared/BusinessState.lua`, `src/shared/Localization.lua` | `clearReservations`; `npcThanks` en/de |
| `src/server/Services/CustomerService.lua`, `CustomerSimulationService.lua`, `CustomerOrderService.lua` | `cancelReservation`; `beginVisit` options; `claims`/`parkingSpace` parameters |
| `src/server/Services/CompanyStateService.lua` | Tokens, claims, npc* methods |
| `src/server/Services/CustomerNpcService.lua` (new) | Director: FSM, queue, budget, cleanup (headless) |
| `src/server/Services/NpcAvatar.lua`, `CustomerNpcWorld.lua` (new) | Roblox avatar and world adapter |
| `src/server/Services/WorldService.lua` | Visit cars, NPC tree, hidden trees, groups, speech, `plotCenter`; **Fix round 2:** `levelArt` |
| `src/server/main.server.lua`, `src/client/WorldLabels.client.lua`, `src/server/Services/StudioTestService.lua` | Wiring; `NpcThanks` label; test hooks |
| `tests/studio/Playtest/RunPlaytest.lua` | Steps 37–40, 03a, reset rule; **Fix round 2:** G3, G4 |
| `tests/headless/run.luau`, `tests/studio/Cases/*` | Registration and tests |
| `docs/GAME_DESIGN.md`, `docs/TEST_PLAN.md`, `docs/TECHNICAL_ARCHITECTURE.md`, `docs/MODEL_INTEGRATION.md`, `docs/DECISION_LOG.md` | Implementer (G5 for Fix round 2) |
| `docs/PROGRESS.md`, `docs/CLAUDE_BACKLOG.md` | Reviewer: status of order 9; CM2-UV (j) with V1's result and the remaining visual items |

## Data and config
`GameConfig.Customers.Npc` as in the working tree (PROVISIONAL unless marked): MaxPerPlot 4, MaxPerServer 24, ArrivalIntervalSeconds 5, TickSeconds 0.2, WalkSpeed 10, ArriveRadius 1.5, CornerRadius 1, ReissueSeconds 2, Clearance 3, CounterClearance 1.5, CarArriveSeconds 2.5, LegTimeoutSeconds 20, BrowseSeconds 6, PickUpSeconds 1, QueuePatienceSeconds 60, AutoCheckoutSeconds 3, WaitAtCarExtraSeconds 10, DepartSeconds 2.5, MaxVisitSeconds 360, ReservationSeconds 120, ThanksSeconds 3, LoadSeconds 60; `Path` (ParkingFirstX −24, ParkingStep 12, ParkingDepth 20, DoorOffsetX 3.5, AisleDepth 12, QueueX 16, QueueFirstDepth −11, QueueSpacing 2.2, StaffDepth −16.5, ApproachGap 0.8, Counter 13.5..18.5 × −15..−13); `Look` palette; `Animations`; `CollisionGroups` (4). Runtime only: `session.token`, `session.npcClaims`. No migration and no new config key in Fix round 2.

## Steps (implemented; contract summary)
1. Config and `parkingOffset` from `Npc.Path`. 2. NpcPath: `door`, `aisle`, `queueSlot(1..4)`, `staffPoint`, `obstacles`, `segmentClear` (Liang–Barsky), `inLot`, `route` (push-out, direct or Dijkstra over box corners), `approach`, `toWorld`/`fromWorld`, `distance`. 3. `BusinessState.clearReservations` in `migrate`. 4. `CustomerService.cancelReservation`. 5. Simulation and order services take `options`, `parkingSpace`, `claims`. 6. CompanyStateService:

| Method | Returns / effect |
|---|---|
| `liveCompanyIds()`, `sessionToken(id)`, `refreshPlacements(id)`, `npcClaimsForTest(id)` | helpers |
| `npcArrive(id, visitId, forcedNumber?)` | `true, {space, customerNumber, lotExpansion, token}` or `CompanyUnavailable` / `NoStock` / `NoParking` (drive-past +1); claims the lowest free space; no revision |
| `npcDecide(id, visitId, n, roll?)` | `true, {placementId, salePrice, sizeId, x?, z?}` or a code (`NoClaim`); success: revision +1, dirty, notify placements |
| `npcCancel(id, visitId, placementId)` | boolean; abandoned +1, revision +1 |
| `npcSettle(id, visitId, placementId, onSold?)` | `true, sale` or a code; success drops the claim, `pcall(onSold)` runs before the orders notification; failure counts one abandonment |
| `npcDepart(id, visitId)`, `npcSweep(id, live)` | drop the claim; remove orphan `visit:` reservations and claims |

7. CustomerNpcService `new(deps, options?)`, `deps = {companies, plotOf, world, now}`, the API and test helpers as in Amendment 1 and F5. FSM:

| State | Normal exit | Timeout → exit |
|---|---|---|
| Arriving (spawnCar) | — | CarArrive → WalkingIn |
| WalkingIn (spawnAvatar; fail → Departing) | route done → Browsing | Leg → snap, Browsing |
| Browsing | — | Browse → `npcDecide`: WalkingToTree or WalkingOut |
| WalkingToTree | done → PickingUp | Leg → snap, PickingUp |
| PickingUp (holdTree) | — | PickUp → WalkingToQueue |
| WalkingToQueue | done → Queued | Leg → snap, Queued |
| Queued | slot 1 and autoCheckout → CheckingOut | QueuePatience → WalkingOut |
| CheckingOut | — | AutoCheckout → `npcSettle`: WalkingToCar, or WalkingOut |
| WalkingToCar (dropTree, say) | done → WaitingAtCar; order gone → Departing | Leg → snap, WaitingAtCar |
| WaitingAtCar | order gone → Departing | 130 s → Departing |
| WalkingOut (releaseIfHeld) | done → Departing | Leg → snap, Departing |
| Departing (despawn; dismissCar without an order) | — | DepartSeconds → Done |
| LoadLoop | leg done → next leg | load seconds → Departing |

Tick order: hard remove (not load visits) → lost avatar or age > MaxVisitSeconds → `releaseIfHeld`, Departing → movement or timer. 8. World: NpcAvatar, CustomerNpcWorld, WorldService additions (Files). 9. main.server wiring (arrival and tick loops, handlers, clearPlot before `clearPlotVisuals`, shutdown first in BindToClose). 10. Hooks `npcVisit`, `npcSnapshot`, `npcGiveUp`, `npcLoadTest`, `npcReset`, `npcNextArrival`. 11. Client label. 12. Docs.

## Tests (headless)
Expected total **380** after Fix round 2 (332 base + 43 N1 + 4 Fix round 1 + 1 Fix round 2). Files: NpcPath_Test (8), NpcLook_Test (2), CustomerNpcService_Test (23), NpcTransactions_Test (8), and +1 each in CustomerService_Test, CustomerSimulationService_Test, BusinessState_Test and GameConfig_Test, +2 in CustomerOrderService_Test, +1 in ArtLibrary_Test (Fix round 2). Test names and asserts are as in the working tree; the Amendment 1, Fix round 1 and Fix round 2 deltas above apply. The fake world records calls, and tests tick in 0.2-s steps of a fake clock.

## Playtest (Studio, via playtester)
- Full: 41 steps. 37 NPC_WALK (P6/G3 check, then customers 8 and 20, then 32: 10 states, 0 snaps, reserved and `NpcCarried` seen, order in the visit's space, `CustomerCar_<n>`, avatar within 3 studs of its door, gone within 5 s of loading, sales +3, nothing left). 38 NPC_GIVE_UP (profile 5 walks out; profile 8 gives up while carrying). 39 NPC_REJOIN_CLEANUP. 40 NPC_REAL_ARRIVAL (P5). 22 LEAK_CHECK also requires no live NPC and no NPC objects, ignoring live NPC humanoids as strays.
- Soak: 7 steps; 03 FAILs on snaps (P7); 03a NPC_LOAD (24 spawned and live, every 5-s window ≥ 55 FPS, 0 snaps, left 0); 04 waits for natural departures; 05 no visit on S's plot within 3 s.
- Order of runs and V1: Fix round 2, Playtest.

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (380 run, 0 failed), `rojo build default.project.json` and `rojo build release.project.json` (no `StudioTestService`).
- Every FSM state has a timeout and an exit. A reserved tree is released on every give-up path. The sale settles exactly once.
- Studio: on BUILD `cm2-n1-fix2`, full 41/41 twice and soak 7/7 in one session (Fix round 2, Playtest 1). Step 37 passes the stand check on plots 1–6 (inside Stand ± 0.5, aligned within 1°). V1 is PASS, or BLOCKED with the reason, and is recorded under CM2-UV (j).
- No new remote. No client input reaches an NPC method. No schema bump.

## Out of scope
Manual checkout, Cashier and walk-out accounting (CM2-N2); reviews (CM2-G15); staff avatars (CM2-25/26); day/night arrival rates; real preferences (CM2-35); Blender NPC meshes; HQ-tier obstacle boxes (CM2-G9/G19); levelling of decor art placed by `cloneArt`; the stall's front direction (a CM2-UV (j) finding if V1 shows it facing away from the road).

# CM2-LOTLAY — Fenced lot: counter at the HQ front, centred gate, parking outside

Written by `planner` (Opus 5.5); pipeline `cm2-task`. Everything is decided; anything missing: stop and report.

## Goal
Customers park outside a fenced lot, walk in through a centred gate, pay at a counter in front of the HQ and leave through the gate; the right side stays open for deliveries.

## Source of truth
Backlog CM2-LOTLAY (a)–(f); DECISION_LOG 2026-11-28 (b). Lot frame (x, z toward the road), lot x ±40, z -27..27. New positions PROVISIONAL.

## Implementer tier
Tier: M. Reason: layout, NPC routing and fences across modules; no save, money or remote change (new keep-clear boxes lie inside the old `Parking` box, test 1).

## Skill checks
- npc-ai/performance: routes stay pure lot-frame data (`NpcPath`, no PathfindingService), server-side; no new per-frame work (+4 router nodes).
- building: positions from lot-frame config via `lotPosition`, no hand-typed world coordinates; anchored Parts with explicit size/colour/material; the pad reaches the map ground.
- luau-core: the 4-entry arrays (`EntryX`, `QueueSlots`, `CarPark.X`) have no nil gaps; keep `--!strict`.
- collaboration-mode: prove each line with a test or Studio reading; claim nothing unrun.

## Files
| File | Change |
|---|---|
| `src/shared/GameConfig.lua` | Npc.Path, Placement (below) |
| `src/shared/LotArt.lua` | gate from config, new `fenceSegments` |
| `src/shared/Progression.lua` | `fenceBoxes` |
| `src/shared/NpcPath.lua` | parking, entry, queue, fence obstacles, walk area |
| `src/shared/MapLayout.lua` | `Cars` box from `CarPark.Apron` |
| `src/server/Services/WorldService.lua` | `parkingOffset`, `applyParkingVisual` |
| tests (below); docs TECHNICAL_ARCHITECTURE, MODEL_INTEGRATION, DECISION_LOG, PROGRESS | |

No change to the NPC services, `LotFenceWorld`, `LotGateWorld` or client files (CM2-UIFIX).

## Data and config
`Customers.Npc.Path`:
- Remove `ParkingFirstX`, `ParkingStep`, `ParkingDepth`, `DoorOffsetX`, `AisleDepth`, `QueueX`, `QueueFirstDepth` and `QueueSpacing`.
- `Counter = { minX = -16.5, maxX = -11.5, minZ = 15.5, maxZ = 17.5 }` (centre (-14, 16.5), still facing the road).
- `StaffDepth = 14`.
- `QueueSlots = { {x=-14,z=19.5}, {x=-14,z=23}, {x=-10.5,z=23}, {x=-7,z=23} }` (L toward the gate; slot 1 = art `Checkout1`, cashier = `CashierStand` (-14, 14)).
- `EntryX = { -1.5, 1.5, -3.5, 3.5 }`, `EntryDepth = 20`: the entry point inside the gate, per parking space.

`Placement`:
- `KeepClear` order: Stand (unchanged); `Checkout = {-18, -5.5, 13, 25}`; new `Gate = {-5.5, 5.5, 13, 27}` (the entrance path); Pickup, Spawn, Bays and Sign unchanged. Remove `Parking`; the old `Checkout` area becomes placeable.
- `Gate = { X = 0, PostX = 8.9 }` (pivot (0, 28); posts at x ±8.15..9.65).
- `FrontApronDepth = 8`: the router may use z up to 35.
- `CarPark = { X = { -5, 5, -15, 15 }, Depth = 40, PadWidth = 8, PadLength = 12, DoorOffsetX = 3.5, DoorDepth = 33, Apron = { minX = -28, maxX = 20, minDepth = 27, maxDepth = 59 } }`. Space 1 nearest the gate; pads z 34..46; CM2-PARK/TRAFFIC read only this table.
- `DecorFences = {}` (replaced by the new runs).

## Steps
1. **GameConfig**: the values above; fix comments citing old values.
2. **LotArt**: `GATE_X = GameConfig.Placement.Gate.X` and `GATE_POST_X = GameConfig.Placement.Gate.PostX`.
   - Add the local `run(pieces, box, x0, z0, x1, z1)`. `L` = |end - start| (the run is axis-aligned), `dir` = unit vector. `n = math.max(1, math.ceil((L - 8.4) / RAIL_LENGTH) + 1)`, `step = if n > 1 then (L - 8.4) / (n - 1) else 0`. For k = 0..n-1: behind = start + dir·step·k; insert a Rail with centre = behind + dir·`RAIL_BEHIND`.
   - `fenceSegments(level)`, with `zf = LotHalfDepth + FENCE_OFFSET`, `zb` as today, `hx = half + 0.45`, in this order:
     - Back: unchanged (10 rails + post).
     - `Left`: `run(-hx, zf → -hx, zb)`.
     - `FrontLeft`: `run(-GATE_POST_X, zf → -hx, zf)`.
     - `FrontRight`: `run(GATE_POST_X, zf → hx, zf)` plus a `Post` at (hx, zf), dir (1, 0).
     - `Right`: today's loop for the Right side only, when level ≥ 1.
   - Count 27 + 2·level (Left 7 + level, fronts 4 each); right side open.
3. **Progression.fenceBoxes**: return Back; `Left = {-(half+0.6), -(half+0.3), -(back+0.6), LotHalfDepth+0.6}` at every level; `FrontLeft = {-(half+0.6), -Gate.PostX, LotHalfDepth+0.3, LotHalfDepth+0.6}`; `FrontRight = {Gate.PostX, half+0.6, same z}`; then Right (level ≥ 1, unchanged). Use the same order as the pieces.
4. **NpcPath** (add `require(script.Parent.LotArt)`):
   - `door(s)` = (`CarPark.X[s] + DoorOffsetX`, `DoorDepth`).
   - New `parkingSpot(s): Point` = (`X[s]`, `Depth`).
   - New `parkingPad(s): Box` (id `"Pad"..s`, ±PadWidth/2, Depth ± PadLength/2).
   - `aisle(s)` = (`EntryX[s]`, `EntryDepth`); keep the name and change its comment to "entry point inside the gate".
   - `queueSlot(i)` returns a new point from `QueueSlots[i]`.
   - `staffPoint()` = (counter centre x, `StaffDepth`).
   - New `gateFences(): {Box}` returns the raw `FenceLeft = {-(half+FENCE_OFFSET+PIECE_HALF), posts[1].maxX, zf-PIECE_HALF, posts[1].maxZ}` (= -40.9, -8.15, 27.0, 28.75) and its mirror `FenceRight` (posts from `LotArt.gatePostBoxes()`).
   - `obstacles()` appends both fences, inflated by `Clearance`, after Bays.
   - New `inWalkArea(p, level)`: true when |x| ≤ half and -backDepth ≤ z ≤ LotHalfDepth + FrontApronDepth. `route` filters corner nodes with it instead of `inLot`; `approach` keeps `inLot`.
5. **MapLayout.keepOut**: `box("Cars", a.minX, a.maxX, a.minDepth - 75, a.maxDepth - 75)` with `a = GameConfig.Placement.CarPark.Apron` (plots at |z| 75); x 16 → 20, nearest map piece (pole, lot x 23.5) stays 3.5 away.
6. **WorldService**:
   - `parkingOffset` takes x and z from `NpcPath.parkingSpot(index)` (add the `NpcPath` require).
   - `applyParkingVisual`: the pad is `Vector3.new(PadWidth, 0.9, PadLength)` at y `lotTop(plot) + VehicleArt.PARKING_RISE - 0.45` (top 0.82 = car wheel plane, foot in the map ground). Colour and material stay unchanged (CM2-PARK restyles them).
7. No reference to a removed `Npc.Path` key remains in `src` or `tests` (grep).
8. **Docs**:
   - TECHNICAL_ARCHITECTURE section 2: bullet "Lot layout (CM2-LOTLAY)": `CarPark`, `Gate`, KeepClear ids, counter/queue/entry, router fence obstacles and walk area.
   - MODEL_INTEGRATION: "Map layout" `Cars` x cx-28..cx+20 (from `CarPark.Apron`); "Lot gate and fence" pivot (0, 28) in the front-fence gap (drop the old clearance sentence); CM2-13W lot fence ids Back/Left/FrontLeft/FrontRight/Right with 27 + 2 x level pieces, the road side fenced except the gate, the right side open; counter at (-14, 16.5); "no decorative fences since CM2-LOTLAY"; parked car at the `CarPark` spot outside the fence.
   - DECISION_LOG engineering entry "CM2-LOTLAY lot layout" (values, L queue); PROGRESS entry with results and screenshot paths.

## Tests (headless)
Updates:
| File | Change |
|---|---|
| `GameConfig_Test` | `EntryDepth > Stand.maxZ + Clearance`; `QueueSlots[1].z >= Counter.maxZ + CounterClearance`; `#DecorFences == 0` |
| `LotArt_Test` | counter attachments equal `queueSlot(1)` and `staffPoint()`; fences `27 + 2*level`, posts == 2, NaN/"x" → 27; gate pose (0, 28); gate posts ≥ 2 studs from pads 1–4, truck lane, Sign, Spawn, Checkout, Gate |
| `NpcPath_Test` | "never leaves the lot" → `inWalkArea`; slots also lie ≥ 1 outside KeepClear `Gate`, and their distance to (0, 27) falls from slot 1 to 4 |
| `Staff_Test` | post (-14, 14); `(-35, 23)` → `(-10, 22)` KeepClear |
| `Stocking_Test` | spot `{16,-10}` → `{-10, 22}` |
| `Progression_Test` | pads from `NpcPath.parkingPad(i)` |

New (+5):
| File | Test | Asserts |
|---|---|---|
| `GameConfig_Test` | keep-clear boxes stay inside schema 23 | each current box lies inside one box of a frozen literal copy of the 7 old boxes |
| `LotArt_Test` | centred gate gap, right side open | levels 0..6: FrontLeft max x == -(FrontRight min x) == -8.9; no piece box overlaps the opening x ±8.15, z 26..30, the truck lane {43..49, -150..66} or Bays; no piece at x > 40 with -27 < z < 27 |
| `NpcPath_Test` | legs go through the gate, cross no fence | levels 0 and 6, spaces 1–4. Chain: door→aisle→approach of trees (-30, 20, Large), (30, 20, Medium), (-30, -20, Small)→queue 4→3→2→1→door, plus `Staff.pickupApproach(s)`→door. Every segment of `{from}` plus `route(...)` is `segmentClear` against the raw fence piece boxes, the gate posts, Stand, Bays and `Path.Counter` |
| `NpcPath_Test` | parking outside the fence | pads inside the Apron, pairwise apart, `minZ` ≥ gate post `maxZ` + 5; `door(i).z` < pad `minZ`, not inside any obstacle, ≤ 35 |
| `MapLayout_Test` | `Cars` box is the apron | `Cars_2` == plot 2 x + Apron x, z -48..-16 |

## Playtest (Studio, via playtester)
Update steps 66 (counter, `Checkout1` and `CashierStand` from `LotArt.COUNTER`, `queueSlot(1)` and `staffPoint()`; fence count `#LotArt.fenceSegments(level)`), 73 (parked pose from `NpcPath.parkingSpot(space)`) and 49 (`refused(-14, 20, "KeepClear")`).
1. Smoke + steps 37, 40, 41, 44, 46, 49, 56, 58, 66, 73 → PASS, 0 snaps, 56 overlaps 0.
2. Fresh plot, one customer end to end: car parks outside, NPC enters through the gate, queues on the L, is checked out at the new counter, leaves through the gate; load the order. Record the states.
3. Fence at expansion 0 and 1: gap centred on the gate, left run full depth, right side open, truck lane free. Top-down and gate screenshots, paths in PROGRESS.
4. Full `runPlaytest {mode="full"}` → all PASS (counts in PROGRESS).

## Acceptance
- `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (current count + 5, all passing), `rojo build`.
- Backlog (a)–(f); no schema change.

## Out of scope
Parking tiers and look (CM2-PARK); road driving (CM2-TRAFFIC); counter art or rotation; client UI.

## Amendment 1 (playtest 2026-11-28: step 41 FAIL, rails overlap the gate posts)
**Finding 1, step 41 "checkout worked out of reach": a test assumption, not a bug.** `checkoutAt` checks reach against the live `CounterBase` (`WorldService.checkoutTarget` → `checkoutBase`), so it uses the counter's current position. The step's "out of reach" spot is the plot `Spawn` pad at lot (-28, 14). That pad is now about 14.2 studs from the counter at (-14, 16.5), inside `InteractDistance` 16; before, it was about 50 studs away.
- Fix in `tests/studio/Playtest/Steps/Checkout.lua`, part 8: teleport to the plot's `Receiving.Bay_1` (lot (35, -22), about 61 studs away) instead of `Spawn`. Check that it exists, with the message "player plot has no Receiving.Bay_1". Then rename the local, and change the comment to "Out of reach (Bay_1, > InteractDistance from the counter)". The server code stays unchanged.

**Finding 2: the front rails and the front fence boxes reach into the gate posts.** Fix it so both runs stop at the outer face of each post:
- GameConfig: `Placement.Gate = { X = 0, PostX = 8.9, PostHalf = 0.75 }`.
- LotArt: `GATE_POST_HALF = GameConfig.Placement.Gate.PostHalf`. In `fenceSegments`, the front runs start at the post's outer face: `FrontLeft` = `run(-(GATE_POST_X + GATE_POST_HALF), zf → -hx, zf)`, and `FrontRight` likewise from `+(GATE_POST_X + GATE_POST_HALF)`. L = 30.8, which still gives 4 rails, so the count stays 27 + 2·level.
- Progression.fenceBoxes: `FrontLeft.maxX = -(Gate.PostX + Gate.PostHalf)` (-9.65) and `FrontRight.minX = Gate.PostX + Gate.PostHalf` (9.65).
- `NpcPath.gateFences` stays unchanged: it already takes the union with the posts.
- Tests (`LotArt_Test`, "centred gate gap"):
  - FrontLeft max x == -(FrontRight min x) == -9.65.
  - New assertion: every `FrontLeft`/`FrontRight` piece box and both front `fenceBoxes` overlap each `LotArt.gatePostBoxes()` box by an area ≤ 1e-9.
  - The headless count stays the same (806).
- Docs: in MODEL_INTEGRATION "Lot gate and fence", add "front runs end at the post faces x ±9.65".

**Re-run:** standard checks (headless 806/806), then a playtest of the smoke run plus steps 41 and 66. Expected results:
- Step 41 PASS, with the out-of-reach checkout refused.
- Step 66 PASS.
- Overlap between the gate posts and the rails and fence boxes is 0 (playtester reads the same measures as before).

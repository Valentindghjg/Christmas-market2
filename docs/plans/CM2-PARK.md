# CM2-PARK — Parking tiers 1 to 4 for money, a real car park

Written by `planner-high` (Opus 5.5); pipeline `cm2-task`. Everything is decided; anything missing: stop and report. Lands after CM2-LOTLAY (reads `Placement.CarPark`, `NpcPath.door/parkingPad/obstacles`; LOTLAY keys unchanged).

## Goal
New saves start with 1 space and buy tiers 2, 3, 4 ($400, $1,200, $4,200) in the Land tab; old saves keep every space; a car finding every space taken is held, not dropped; the spaces look like a car park.

## Source of truth
Backlog CM2-PARK (a)–(g); DECISION_LOG 2026-11-28 "pre-launch UI, lot layout and parking tiers" (c) + price amendment; `docs/plans/CM2-LOTLAY.md` (CarPark).

## Implementer tier
Tier: L. Reason: save schema 23->24 with migration, a money purchase ladder and NPC arrival concurrency (held arrivals).

## Skill checks
- data: step 23->24 runs only on `schemaVersion == 23` (rerun = no-op); no money or order field moves; Studio rewrite only via `updateSaveRecord` (UpdateAsync), never under a live `_session`.
- networking/security: price and spaces from `GameConfig` only; client sends `{tier}`; `Progression.check` (next tier), cash check, replay (`DuplicateRequest`) and today's rate limit stay the only path.
- npc-ai/performance: holding adds no per-frame work.
- building/lighting: parts from lot-frame specs via `lotPosition`/`lotTop`, anchored, explicit size/colour/material/CanCollide; the "P" is Parts (no text); lights only via `MapWorld.nightLight`; quality tier B.
- localization: new key in `en` and `de`, same placeholders. collaboration-mode: claim nothing unrun.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/GameConfig.lua`, `Progression.lua`, `BusinessState.lua` | Change | ladder, gate, fixtures; `migrate23`; schema 24 |
| `src/shared/ParkingArt.lua` | New | pure part specs of bays and fixtures |
| `src/server/Services/ParkingWorld.lua` | New | builds the specs into `ProgressionVisuals` |
| `src/server/Services/WorldService.lua` | Change | `applyParkingVisual` delegates |
| `src/server/Services/CustomerNpcService.lua`, `CompanyStateService.lua` | Change | held arrival; no drive-past in `npcArrive` |
| `src/server/Services/CustomerOrderService.lua` | Change | comment at `parkingSpaces` (tiers 1-4) |
| `src/shared/LandView.lua`, `src/shared/Localization.lua` | Change | status line |
| `src/server/Services/StudioTestService.lua` | Change | `legacyParking` command |
| tests, playtest steps, docs (below) | Change | |

## Data and config
`GameConfig` (before `GameConfig.Progression`): `local HQ_PARKING_GATE = { 1, 2, 3, 4 }` -- "HQ level -> required parking tier. PROVISIONAL, owner to confirm (DECISION_LOG 2026-11-28 amendment); change only this line."
- `Progression.HqParkingGate = HQ_PARKING_GATE`; HQ tier n: `requiredParkingTier = HQ_PARKING_GATE[n]` (drop the Pavilion's `-- O` on that field, add `-- P`).
- `Progression.Parking = { maxTier = 4, maxSpaces = 4, tiers = { {spaces=1,cashCost=0}, {2,400}, {3,1200}, {4,4200} } }`, each with `requiredReputation = 0, evidence = GameConfig.Evidence.OwnerDecided` (tier 4 is the last: Npc.MaxPerPlot is 4)
- `Customers.BaseParkingSpaces = 1` (comment: OWNER DECIDED 2026-11-28, replaces the observed 2).
- `Placement.CarPark.Fixtures = { Sign = { x = -21.5, z = 30.5 }, Lamps = { { x = -13.5, z = 30.5 }, { x = 13.5, z = 30.5 } } }` (PROVISIONAL; inside the inflated gate-fence obstacles, so no NPC route passes, and fence-side of the pads, so no car).

Schema 24: no new field; `progression.parkingTier` range becomes 1..4 (from config). Migration 23->24: `parkingTier` 1->2, 2->4; nothing else changes.

## Steps
1. **GameConfig**: the values above; fix comments citing tier 2 as last or 2 base spaces.
2. **Progression.migrate23(old)** (schema 23 -> 24, old tiers map by space count; other values pass through, validate rejects them): non-table -> `Progression.new()` with `parkingTier = 2`; table -> `table.clone(old)` with `parkingTier` 1->2 or 2->4.
3. **BusinessState**: `SCHEMA_VERSION = 24`; after the 22->23 block add `if state.schemaVersion == 23 then state.schemaVersion = 24; state.progression = Progression.migrate23(state.progression) end`. Legacy v1 path: `state.progression = Progression.migrate23(Progression.new())` (it had the old 2 spaces).
4. **ParkingArt.lua** (`--!strict`, requires `GameConfig`, `VehicleArt`; header: quality tier B, lot frame, y = `lotTop + dy`). `export type Spec = { name: string, size: {number}, x: number, z: number, dy: number, rgb: {number}, material: string, collide: boolean }`.
   - Colours: A = {54,58,61} Asphalt, W = {240,244,248}, M = {52,58,64}, B = {36,92,168} (W, M, B SmoothPlastic).
   - `ParkingArt.bay(space): { pad: Spec, marks: {Spec} }` with `X = CarPark.X[space]`, `D = CarPark.Depth`, `R = VehicleArt.PARKING_RISE`:

| Name | Size | x, z | dy | rgb, material | collide |
|---|---|---|---|---|---|
| `Parking_<space>` (pad) | PadWidth, 0.9, PadLength | X, D | R - 0.45 | A | true |
| `LineL` / `LineR` | 0.3, 0.06, PadLength - 1 | X -/+ 3.7, D | R + 0.04 | W | false |
| `Stop` (wheel stop) | 4, 0.3, 0.5 | X, D - PadLength/2 + 1.25 | R + 0.16 | {214,170,72} Concrete | false |

   - `ParkingArt.fixtures(facing: number): { { name: string, parts: {Spec}, lightPart: string? } }`, in this order (`S` = Fixtures.Sign, `L` = Fixtures.Lamps[k]); letter x = `S.x + facing * xv` (viewer's right as seen from the road):

| Model | Part | Size | x, z | dy | rgb, material | collide |
|---|---|---|---|---|---|---|
| `CarPark_Drive` | `Slab` | 39, 0.9, 13 | 0, D + PadLength/2 + 6.5 | R - 0.47 | A | true |
| `CarPark_Sign` | `Post` | 0.3, 5.6, 0.3 | S.x, S.z | 2.2 | M | true |
| | `Board` | 2.4, 2.4, 0.2 | S.x, S.z + 0.25 | 4.0 | B | false |
| | `LetterStem` | 0.35, 1.7, 0.1 | xv -0.35, S.z + 0.4 | 4.0 | W | false |
| | `LetterBowl` | 0.9, 0.95, 0.1 | xv 0.1, S.z + 0.4 | 4.375 | W | false |
| | `LetterHole` | 0.3, 0.35, 0.1 | xv 0.15, S.z + 0.46 | 4.375 | B | false |
| `CarPark_Lamp_<k>` | `Post` | 0.3, 8.6, 0.3 | L.x, L.z | 3.7 | M | true |
| | `Arm` | 0.2, 0.2, 1.8 | L.x, L.z + 0.9 | 7.9 | M | false |
| | `Head` (lightPart) | 0.9, 0.35, 0.9 | L.x, L.z + 1.7 | 7.65 | {255,214,140} Neon | false |

   (Drive reaches the road edge, top 0.02 below the pads: no coplanar seam; marks sit 0.01 above the pad.)
   - `ParkingArt.footprints(): { Box }`: `Sign` = S ± (1.2, 0.5), `Lamp_1`, `Lamp_2` = L ± (0.5, 0.5) (for CM2-TRAFFIC).
5. **ParkingWorld.lua** (server): `ParkingWorld.build(plot: Model, visuals: Instance, spaces: number, helpers)` with WorldService's `FENCE_HELPERS`.
   - Destroy every child of `visuals` whose name starts with `Parking_` or `CarPark_`. `n = math.clamp(math.floor(spaces), 0, Parking.maxSpaces)`; `n == 0` returns (a released plot shows nothing).
   - Per space i ≤ n: pad via `helpers.part(visuals, …)` at `helpers.lotPosition(plot, x, z, helpers.lotTop(plot) + dy)`, `Color3.fromRGB`, `Enum.Material[material]`, then `CanCollide = collide`, attribute `ParkingSpace = i`; marks parented to the pad (one `Parking_` child per space).
   - Per fixture: a `Model` of that name under `visuals` with its parts, `facing = helpers.facing(plot)`; `MapWorld.nightLight(head, GameConfig.DayCycle.LampLight)` on `lightPart`.
6. **WorldService.applyParkingVisual**: keep plot lookup, `spaces < 0` refusal and folder; the loop becomes `ParkingWorld.build(plot, visuals, spaces, FENCE_HELPERS)`. `parkingOffset`/`parkedAt` unchanged (same mirroring as `lotPosition`).
7. **CustomerNpcService (held arrival)**:
   - `self._held = {} :: { [string]: number }` (companyId -> time the next car started waiting).
   - `arrivalPass`: one `_arrive` call (override or not, as today) returning `ok, code`. ok: today's bookkeeping plus `_held[companyId] = nil`. `"NoParking"`: `_held[companyId] = _held[companyId] or self._now()` (credit stays ≥ 1: each 5-s pass retries, the car enters one pass after a space frees). Other codes: `_held[companyId] = nil`. Prune `_held` like `_arrivalCredit` and when `plotId == nil`.
   - `resetForTest(companyId)` clears that entry (nil: all); `shutdown` clears all.
   - New `CustomerNpcService:heldSince(companyId: string): number?` (comment: the next car waits for a free space; CM2-TRAFFIC may show it on the road).
   - `snapshot()` adds `held = { { companyId, plotId = self._plotOf(companyId), since } }`, sorted by companyId.
   - `spawnForTest` still returns `NoParking`, without holding.
8. **CompanyStateService.npcArrive**: the `NoParking` branch no longer counts `drivePastCustomers` (the car is held, CM2-PARK); `simulateCustomerVisits` unchanged.
9. **LandView.statusLine("Parking")**: `spaces == 1` -> `{ key = "landParkingStatusOne", args = { tier, maxTier } }`, else `landParkingStatus` with `{ tier, maxTier, spaces }`. `nextLine` and the HQ row unchanged: `landRowParkingTier` is "have of need" ("Parking tier: 1 of 2" for the Pavilion), which under the graded gate replaces the backlog's "of 4".
10. **Localization**: en `landParkingStatus = "Parking tier %d of %d · %d spaces"`, new `landParkingStatusOne = "Parking tier %d of %d · 1 space"`; de `"Parkstufe %d von %d · %d Plätze"`, `"Parkstufe %d von %d · 1 Platz"`.
11. **StudioTestService** (require Shared `BusinessState`): `commands.legacyParking({tier})`, tier 1 or 2 else `BadArgument`; `ShadowActive` while `companyIdFor(shadowUserId) ~= nil`; first save of `saveSlots:listFor(shadowUserId)` else `NoSave`; `updateSaveRecord` sets `schemaVersion = 23`, `progression.parkingTier = tier` only for a table record with `schemaVersion == BusinessState.SCHEMA_VERSION`, a table `progression` and no `_session`; else it returns nil and the command fails `NotWritten`.
12. **Playtest fixtures** (`Support/Fixtures.lua` `preflight`, after the `setDay` calls): `call("setProgression", { userId = R.userId, parkingTier = 4 })`, same for S when `shadowJoined` (steps assume 4 spaces).
13. **Docs**: GAME_DESIGN "Parking"/"HQ" lines (ladder OWNER DECIDED, gate 1/2/3/4 PROVISIONAL, held car); TECHNICAL_ARCHITECTURE "Schemas 13 to 24" (24 = CM2-PARK) and `heldSince`; MODEL_INTEGRATION parked-car line (bay, lines, stop, drive, sign, lamps; tier B); TEST_PLAN line 85 (full = 80 steps, 78, 79); DECISION_LOG engineering entry "CM2-PARK parking tiers and car park" (migration, no live drive-pasts, hold interface, fixture spots, HQ row); PROGRESS entry.

## Tests (headless)
Updates. Rule: a test failing only because a fresh save has 1 space gets `parkingTier = 2` in its setup; fixtures that set tier 2 for 4 spaces get `4`; any other failure: stop and report.
| File | Change |
|---|---|
| `Progression_Test` | config: `maxTier` 4, 4 tiers, `HqParkingGate` {1,2,3,4} = each HQ `requiredParkingTier`; observed values: parking -> {1,$0},{2,$400},{3,$1,200},{4,$4,200} OwnerDecided; deadlock: tier 4, 12 purchases |
| `BusinessState_Test` | literal schema 23 -> 24; "18 to 19": `parkingTier` 4 (chain runs on) |
| `SaveMigration_Test`, `Tutorial_Test`, `DayCycle_Test` | literal 23 -> 24 |
| `CustomerCheckout_Test`, `CustomerNpcService_Test` (addCompany), `StaffNpcService_Test`, `CustomerOrderService_Test` (space-3 test) | `parkingTier = 2` -> `4` |
| `CustomerOrderService_Test` | drive-past test end: tier 4 -> `freeParking` 3; "parking purchases add to the base spaces": cash 400 -> cash 0, spaces 2 |
| `NpcTransactions_Test` | `setup` sets `parkingTier = 2`; `drivePastCustomers` 1 -> 0 |
| `StudioTestInstruments_Test` | "visitForTest needs a free parking space": `parkingTier = 2` |
| `LandView_Test` | parking next args (2, 2, "$400"); key list + `landParkingStatusOne` |

New (+9):
| File | Test | Asserts |
|---|---|---|
| `Progression_Test` | migrate23 maps old parking tiers | 1->2, 2->4, 3 and "x" pass through, nil -> tier 2; lot and HQ kept; input not mutated |
| `BusinessState_Test` | migrates schema 23 records to 24 | v23 tier 1 with an order on space 2 -> tier 2, order space 2; v23 tier 2 with an order on space 4 -> tier 4, space 4; cash, spent, history length unchanged; validate ok; a second `migrate` changes no tier |
| `BusinessState_Test` | a fresh v24 save starts at tier 1 and round-trips | `new`: tier 1, 1 space; migrate of a v24 copy keeps tier 3 |
| `ProgressionService_Test` | parking tiers cost $400, $1,200, $4,200 in order | tier 3 at tier 1 `NotNextLevel`; 399 `InsufficientFunds` (cash kept); exact cash buys 2, 3, 4 (cash 0, spaces 2/3/4); 4 again `AlreadyOwned`; 5 `InvalidLevel` |
| `CompanyStateService_Test` | a replayed parking purchase charges once | `sharedService(…, 400)`: `ok`, data 2; replay `DuplicateRequest`/`Success`; cash 0; revision +1 |
| `CustomerNpcService_Test` | a 1-space plot serves 3 customers in sequence | addCompany 3 trees, tier 1. x3: pass -> 1 arrival on space 1, `heldSince` nil; pass -> 0, `heldSince` set, 1 claim; run to WaitingAtCar, Carry + Load (ids `one_space_carry_n`/`_load_n`), run 2.6 s, visit gone. End: sales 3, drive-pasts 0 |
| `LandView_Test` | parking status reads tier n of 4 | fresh: `landParkingStatusOne` {1, 4}; tier 3: `landParkingStatus` {3, 4, 3}; tier 4 next `landMaxed` |
| `ParkingArt_Test` (new) | bays sit on the CarPark pads | i 1..4: pad centre, size, dy; marks LineL, LineR, Stop inside the pad footprint, bottoms ≥ pad top + 0.005 |
| `ParkingArt_Test` | fixtures stay in the apron, off the walkways | facing ±1: 4 models in order, every part footprint inside `CarPark.Apron`; `footprints()` each inside inflated `FenceLeft`/`FenceRight` of `NpcPath.obstacles()`, ≥ 2 from every `parkingPad(i)`, ≥ 1.5 from every `door(i)`, none in x -8.15..8.15; `LetterBowl` x = S.x + 0.1 (facing 1) and S.x - 0.1 (facing -1) |

## Playtest (Studio, via playtester)
1. Smoke + steps 40, 41, 44, 46, 58, 59, 73, 78, 79 -> PASS.
2. **Step 58** (`Steps/Progression.lua`, update the parking block and header): at tier 1 `BuyParking {tier = 3}` -> `NotNextLevel`; then for (2, $400), (3, $1,200), (4, $4,200): `setProgression {cash = cost}`, buy, cash 0, `Parking_` count = tier, each pad has `LineL`, `LineR`, `Stop`; `{tier = 4}` again -> `AlreadyOwned`; return text "parking 2, 3, 4 once".
3. **New step 78 `NPC_ONE_SPACE`** (`Steps/Npc.lua`, needs 03, `withNpcCleanup`): `ensureDouglas(2)`; R to tier 1; R's visuals: one `Parking_1`, `CarPark_Drive`, `CarPark_Sign`, `CarPark_Lamp_1/2` (`Head` has `NightLight`). `first = npcVisit(8)` on space 1; `npcNextArrival {profile = 20}`, unpause; within 12 s `npcSnapshot().held` lists R's plot, no second visit there; serve `first` to WaitingAtCar (≤ 150 s), `loadAndAwaitDeparture`; within 12 s customer 20 arrives on space 1 and `held` drops R; pause; R's drive-pasts unchanged; restore tier 4 (also on failure).
4. **New step 79 `PARKING_MIGRATION`** (`Steps/Progression.lua`, needs 02): note S's cash and LotWorker. Case A: `setProgression {parkingTier = 3}`, `shadowLeave`, `shadowJoin(0)` -> tier 3 (a rejoin keeps the tier). Cases B, C: `shadowLeave`, `legacyParking {tier = 1}` (then 2), `shadowJoin(0)` -> tier 2 (then 4), cash unchanged, within 5 s S's plot shows 2 (then 4) `Parking_`. Restore LotWorker; return "rejoin 3, old 1 -> 2, old 2 -> 4, cash kept".
5. Lot Manager -> Land on R at tier 1: "Parking tier 1 of 4 · 1 space", "Next: tier 2 with 2 spaces for $400"; CM2-UIFIX `probe` reports no clipped text; screenshots of the tab and a tier-4 car park by day and night (paths in PROGRESS).
6. Full `runPlaytest {mode="full"}` -> 80 steps PASS (counts in PROGRESS).

## Acceptance
- `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (count after CM2-LOTLAY + 9, all passing), `rojo build`.
- Backlog (a)–(g), with (e)'s HQ row read as "have of required tier" (step 9).
- No money moves in the migration; purchases only through `Progression.BuyParking`.

## Out of scope
Road driving, a visible waiting car, turn-in paths (CM2-TRAFFIC: `heldSince`, `ParkingArt.footprints`); HQ gate changes before the owner confirms; locked spaces are not drawn; client layout.

## Amendment 1: two bays each side of the gate; Studio fixes (owner, chat 2026-11-28)
Owner: 2 spaces left of the gate, 2 right, the area in front of the gate free. Purchases, migration, holding, HQ gate unchanged.
- **CarPark** (PROVISIONAL): `X = { -13.5, 13.5, -22.5, 22.5 }` (1/3 left inner/outer, 2/4 right), `PadWidth = 7` (car body 4.6), `Apron` x -26..26 (depth 27..59). Pads ±10..±17, ±19..±26; corridor x -10..10 has no asphalt. Doors (X + 3.5, 33). Fixtures stay (re-checked: inside inflated FenceLeft/Right, ≥ 2.39 from doors, 3 from pads).
- **MapLayout** `INFRA_PAIRS` poles that stood in the right drive: 05 x -82 -> -75, 07 x 24 -> 35, 09 x 134 -> 145 (lot x 35; order, wires kept). Cars box closest piece then 3.43 (Lamp_15), no 3-stud failure (checked with a scratch run of the keep-out test).
- **ParkingArt**: lines at `x -/+ (PadWidth/2 - 0.3)`; `fixtures(facing, spaces)`: `CarPark_DriveL` (Slab 16, 0.9, 13 at (-18, D + PadLength/2 + 6.5)) always, `CarPark_DriveR` (x 18) only if `spaces >= 2`, then Sign, Lamps; ParkingWorld passes `n`.
- **Fix 79 (`NoSave`)**: `shadowLeave` is a final leave, which drops the shadow's cached profile, so `listFor` is empty. `legacyParking` first calls `saveSlots:openProfile(shadowUserId)` (failure: its error code), then `listFor(shadowUserId)[1]`, as `shadowJoin` does.
- **Fix 61**: parking lamps add one NightLight each on every occupied plot. `DayNight.lua`: `PARKING_LIGHTS = #CarPark.Fixtures.Lamps x` (plots whose `ProgressionVisuals` holds `CarPark_DriveL`); expected = 59 + that (63 with R and S); each `CarPark_Lamp_<k>` holds exactly 1; header comment updated.

| Test | Change |
|---|---|
| `NpcPath_Test` | door(1) (-10, 33), door(4) (26, 33), spot(1) (-13.5, 40), spot(4) (22.5, 40) |
| `ParkingArt_Test` | `fixtures(f, 4)`: DriveL, DriveR, Sign, Lamp_1, Lamp_2; `fixtures(f, 1)` no DriveR; no pad or drive overlaps x -10..10 |
Headless count unchanged.
- **Playtest**: step 78 checks `CarPark_DriveL`, no `CarPark_DriveR` at tier 1; step 58: DriveR appears at tier 2; the Land tab reading (item 5) records R's HQ level (the HQ row is have-of-required: "1 of 3" is right at HQ 2, "1 of 2" at HQ 1). Re-run smoke + 56, 58, 59, 61, 66, 69, 73, 78, 79, 40, 41, then full (80 PASS); top view with the free corridor.
- **Docs**: MODEL_INTEGRATION pole list, Cars box, car park line; TECHNICAL_ARCHITECTURE CarPark bullet; DECISION_LOG: append to the 2026-11-28 pre-launch entry "- Amendment 2 (owner, chat 2026-11-28, later): parking split, 2 spaces left of the gate and 2 right; the area in front of the gate stays free (OWNER DECIDED; positions PROVISIONAL, CM2-PARK Amendment 1)." and the pole move in the CM2-PARK engineering entry.

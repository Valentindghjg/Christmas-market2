# CM2-G9a — Progression ladder: server, save, world (lot expansion, parking, HQ, Lot Manager, Elf Workshop)

Written by: `planner` (Opus 5.5, high). Implemented by: the agent for the tier below. Playtested by: `playtester` (Sonnet 5.5, medium). Reviewed and committed by: `reviewer` (Opus 5.5, medium). Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.
Split: launch order 16 (CM2-G9, covers CM2-29/30/31/G19) = **CM2-G9a** (this plan: config, save, actions, world, G19 check) + **CM2-G9b** (`docs/plans/CM2-G9b.md`: Land tab UI, Employees "Standby"). G9b depends on G9a.

## Goal
A save buys 6 lot expansions (the lot grows backwards, reserve firs vanish, the fence moves back), parking tier 2 and the HQ tiers Timber Pavilion, Alpine Hut and Mountain Chalet with cash, each purchase exactly once even under double requests; HQ 4 unlocks the Lot Manager hire, HQ 4 + Lot Manager unlocks the Elf Workshop ("Coming soon"). The summary carries every requirement with progress from the same function the purchase uses.

## Source of truth
PRODUCT_SPEC owner decisions 2026-11-21 ("Fidelity", "Lot expansion extends the lot backwards", "HQ tiers (own names)"); REFERENCE_GAME_LIVE_TEST §4.4, §4.5, §11 G9; GAME_DESIGN §6, §7; MODEL_INTEGRATION "Map layout (CM2-10)" (lot depth −27..−75 reserved for 6 levels × 8); plans CM2-10a, CM2-10W, CM2-13a (footprints), CM2-25-26b; DECISION_LOG CM2-13a (tier IDs = art leaf names), CM2-25/26 (Lot Manager "hire comes with CM2-G9"); backlog CM2-G9, CM2-G19, launch order 16.

## Implementer tier
Tier: L. Reason: save schema 18 → 19 with migration, cash purchases that must be idempotent under double requests, new remote payload validation and a test-only state hook.

## Skills to load
roblox-collaboration-mode, roblox-data, roblox-server-data, roblox-networking, roblox-security, roblox-luau-core, roblox-luau-patterns, roblox-luau-types, roblox-architecture, roblox-building, roblox-npc-ai, roblox-game-design, roblox-tooling.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/GameConfig.lua` | Change | `Progression` ladder (below); remove `GameConfig.HQ`; `Placement.BackDepthPerLevel` 8; `Npc.ReservationSeconds` 165 |
| `src/shared/Progression.lua` | New | pure ladder logic: levels, offers, requirement rows, check, workshop, summary, fence boxes, migration |
| `src/server/Services/ProgressionService.lua` | Change | buys by explicit target through `Progression.check` |
| `src/server/Services/CompanyProgression.lua` | New | `install(CompanyStateService)`: changed handler, notify, test setter |
| `src/server/Services/CompanyStateService.lua` | Change | install, dispatch targets, `progressionChanged`, summary `progression`, `npcArrive` patience, snapshot |
| `src/shared/BusinessState.lua` | Change | schema 19, migration 18 → 19, `new`, legacy path, `validate` |
| `src/shared/Protocol.lua` | Change | payloads `{level}`, `{tier}`, `{level}` |
| `src/server/Services/EmployeeService.lua`, `CompanyStaff.lua` | Change | capacity and Lot Manager lock from the HQ level; status `Standby` |
| `src/server/Services/CustomerOrderService.lua` | Change | `parkingSpaces` from the tier |
| `src/server/Services/CustomerNpcService.lua` | Change | per-visit queue patience |
| `src/server/Services/WorldService.lua` | Change | HQ tier visuals, pad depth, `LotFence` |
| `src/server/main.server.lua` | Change | progression handler; visuals from levels; drop the 3 branches in `handleBusinessAction` |
| `src/server/Services/StudioTestService.lua` | Change | command `setProgression` |
| `tests/headless/run.luau` | Change | `Progression` in `sourcePaths`, `CompanyProgression` in services |
| `tests/studio/Cases/Progression_Test.lua` | New | tests below |
| `tests/studio/Cases/*` (listed in Tests) | Change | new shapes |
| `tests/studio/Playtest/Steps/Progression.lua` | New | steps 58, 59 |
| `tests/studio/Playtest/RunPlaytest.lua` | Change | install `Progression` after `Map`; `BUILD = "cm2-g9a"` |
| `tests/studio/Playtest/Steps/Map.lua`, `Staff.lua` | Change | depth per level from config; capacity via `Progression` |
| `docs/GAME_DESIGN.md` §7, `docs/TECHNICAL_ARCHITECTURE.md` §3/§4, `docs/MODEL_INTEGRATION.md`, `docs/DECISION_LOG.md` | Change | step 12 |

## Data and config
**`GameConfig.Progression`** replaces today's table; `GameConfig.HQ` is deleted. O = OBSERVED (REFERENCE §4.4/§4.5), P = PROVISIONAL.

Lot expansion, `LotExpansion = { maxLevel = 6, levels = { ... } }` (index = level bought):
| Level | `id` | `cashCost` | `requiredReputation` | `requiredHqLevel` | evidence |
|---|---|---|---|---|---|
| 1 | `BackLot` | 1200 | 0 | 1 | O (name, cost, +10 storage) |
| 2 | `SpruceCorner` | 5000 | 400 | 2 | P |
| 3 | `WoodlandEdge` | 15000 | 600 | 2 | P |
| 4 | `PineClearing` | 100000 | 1200 | 3 | P |
| 5 | `SnowyMeadow` | 250000 | 2000 | 3 | P |
| 6 | `ForestGlade` | 1000000 | 3500 | 4 | P |
Level 0 is the "Starter Lot" (O). Each level adds `Placement.BackDepthPerLevel` = **8** studs of depth (was 6; the map contract reserves 6 × 8, so the level-6 lot edge is depth −75 = the reserve) and `Receiving.StoragePerLotExpansion` 10 storage (O for level 1, P beyond).

Parking, `Parking = { maxTier = 2, maxSpaces = 4, tiers = { { spaces = 2, cashCost = 0, requiredReputation = 0, evidence = O }, { spaces = 4, cashCost = 600, requiredReputation = 0, evidence = O } } }`. Tier 2 is the last: the lot's car lane (map K box `Cars`) and `Npc.MaxPerPlot` 4 hold 4 spaces; more tiers need a new parking layout (not observed).

HQ, `HQ = { maxLevel = 4, tiers = { ... } }`; fields `id`, `cashCost`, `requiredReputation`, `requiredLotExpansion`, `requiredParkingTier`, `newSpecies`, `checkoutStations`, `employeeCapacity`, `customerPatienceBonus`, `unlocksLotManager`, `unlocksWorkshop`, `footprint {minX, maxX, minZ, maxZ}`, `eave`, `height`, `evidence`:
| Lvl | `id` | cost | rep | lot | park | species | checkouts | staff | patience | LM / WS | footprint (lot frame) | eave / H |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `SalesTent` | 0 | 0 | 0 | 1 | 0 | 1 | 2 (O) | 0 | no / no | x −18..2, z −11..3 | 7.5 / 10 |
| 2 | `TimberPavilion` | 2500 (O) | 250 (O) | 1 (O) | 2 (O) | 4 (O) | 2 (O) | 3 (O) | 0.12 (O) | no / no | x −20..4, z −13..5 | 8 / 13 |
| 3 | `AlpineHut` | 50000 | 1000 | 3 | 2 | 4 | 2 (O) | 5 (O) | 0.20 | no / no | x −22..6, z −14..6 | 8.5 / 16 |
| 4 | `MountainChalet` | 600000 | 3000 | 5 | 2 | 4 | 3 | 6 | 0.30 | yes / yes | x −23.8..7.8, z −15.8..7.8 | 13 / 20 |
Unmarked values are P. `evidence`: tier 1 and 2 O, tiers 3 and 4 P (their names map the reference's "Christmas Market Chalet" and "Christmas Lodge", whose costs are unseen). Footprints and heights are the CM2-13a art targets; all four are centred on the stand point (−8, −4).

Workshop, `Workshop = { id = "ElfWorkshop", requiredHqLevel = 4, requiresLotManager = true, evidence = GameConfig.Evidence.OwnerDecided }`. No cost, no action: content is "Coming soon" (PRODUCT_SPEC).

Other config: `Employees.LotManager.requiredHqTier` stays 4 (O). `Customers.Npc.ReservationSeconds` 150 → **165** (≥ 20 + 1 + 20 + 117 + 3 = 161 with the HQ 4 patience). `KeepClear.Stand` stays x −24..8, z −16..8 for every tier (the largest footprint fits with 0.2 to spare, so an upgrade never meets a displayed tree).

**Unlock lists** (derived by `Progression.unlocks(kind, target)`, not stored); HQ tiers in this order, each `{ id, value, active }`: `NewSpecies` (value `newSpecies`, only if > 0, active false), `CheckoutStations` (value, only if it exceeds the previous tier's, active false), `EmployeeCapacity` (value, active true), `CustomerPatience` (value = `math.floor(bonus * 100 + 0.5)`, only if > 0, active true), `LotManager` (if `unlocksLotManager`, active true), `ElfWorkshop` (if `unlocksWorkshop`, active false). Inactive = shown "coming soon" (new species and more counters come with CM2-G9d). Lot levels: `{ DisplaySpace, 8, true }`, `{ DeliveryStorage, 10, true }`. Parking tier: `{ ParkingSpaces, spaces, true }`.

**Save schema 19.** `state.progression` becomes exactly `{ lotExpansion: int 0..6, parkingTier: int 1..2, hqLevel: int 1..4 }` (`parkingSpaces` and `hqTier` are gone). `BusinessState.new` and the legacy-v1 path use `Progression.new()` = `{ lotExpansion = 0, parkingTier = 1, hqLevel = 1 }`. Migration 18 → 19 (after the 17 → 18 block): `state.progression = Progression.migrate18(state.progression)`:
- `lotExpansion` = old value unchanged (old max 3; `validate` checks the range);
- `parkingTier` = 2 if `old.parkingSpaces` is a number ≥ 3, else 1 (a save that paid $200 for space 3 gets tier 2; private builds only, no money moves);
- `hqLevel` = 2 if `old.hqTier == "ChristmasPavilion"`, else 1;
- a non-table `old` gives `Progression.new()`.
`validate`: `progression` a table; `lotExpansion` integer 0..`LotExpansion.maxLevel`; `parkingTier` integer 1..`Parking.maxTier`; `hqLevel` integer 1..`HQ.maxLevel`; else invalid (fail-closed load).

## Steps
1. **`src/shared/Progression.lua`** (requires only `GameConfig`; no Roblox types). Types `Row = { id: string, have: number, need: number, met: boolean }`, `Unlock = { id: string, value: number?, active: boolean }`, `Offer = { kind: string, target: number, id: string, cashCost: number, rows: { Row }, unlocks: { Unlock }, ready: boolean }`. Functions:
   - `new()`, `migrate18(old)` as above.
   - `lotLevel(state)`, `parkingTier(state)`, `hqLevel(state)`: the saved integer, clamped to its range (0..6, 1..2, 1..4); a missing or non-number value gives the minimum.
   - `parkingSpaces(state)` = `Parking.tiers[parkingTier].spaces`; `employeeCapacity(state)` = `HQ.tiers[hqLevel].employeeCapacity`; `queuePatienceFor(level)` = `math.floor(Npc.QueuePatienceSeconds * (1 + HQ.tiers[level].customerPatienceBonus) + 0.5)` → 90, 101, 108, 117; `queuePatienceSeconds(state)` = `queuePatienceFor(hqLevel(state))`.
   - `rows(state, kind, target): { Row }`: the requirements of buying `target` of `kind` (`"LotExpansion"`, `"Parking"`, `"HQ"`), in this fixed order, a row only when the kind's config has the field and its need is above the start value (lot levels: HqLevel, Reputation, Cash; parking: Reputation, Cash; HQ: LotExpansion, ParkingTier, Reputation, Cash): `HqLevel` (have `hqLevel`, need `requiredHqLevel`, shown when > 1), `LotExpansion` (need `requiredLotExpansion` > 0), `ParkingTier` (need `requiredParkingTier` > 1), `Reputation` (have `state.reputation`, need > 0), `Cash` (have `state.cash`, need `cashCost`, always). `met` = have ≥ need.
   - `ROW_CODES = { HqLevel = "PrerequisitesNotMet", LotExpansion = "PrerequisitesNotMet", ParkingTier = "PrerequisitesNotMet", LotManager = "PrerequisitesNotMet", Reputation = "InsufficientReputation", Cash = "InsufficientFunds" }`.
   - `check(state, kind, target): (boolean, string?)`: target not an integer or outside 1..max (`LotExpansion` 1..6, `Parking` 1..2, `HQ` 1..4) → `false, "InvalidLevel"`; target ≤ current → `"AlreadyOwned"`; target > current + 1 → `"NotNextLevel"`; else the first unmet row's `ROW_CODES` code; else `true, nil`. Unknown kind → `"InvalidLevel"`.
   - `offer(state, kind): Offer?`: nil when current = max; else target = current + 1, `id` from config, `cashCost`, `rows`, `unlocks`, `ready` = every row met.
   - `unlocks(kind, target)` as in Data.
   - `workshop(state)` = `{ unlocked, rows }`; rows `HqLevel` (need 4) and `LotManager` (have `state.staff.LotManager` or 0, need 1); unlocked = both met.
   - `summary(state)` = `{ lotExpansion = { level, maxLevel, storage = GameConfig.Receiving.BaseStorage + level × StoragePerLotExpansion, next = offer(...) }, parking = { tier, maxTier, spaces, next }, hq = { level, maxLevel, id, next }, workshop = workshop(state) }`.
   - `fenceBoxes(level): { { id: string, minX, maxX, minZ, maxZ } }` in the lot frame, B = `LotHalfDepth + BackDepthPerLevel × clamp(level, 0, 6)`: `Back` x −40.6..40.6, z −(B + 0.6)..−(B + 0.3); for level ≥ 1 also `Left` x −40.6..−40.3 and `Right` x 40.3..40.6, both z −(B + 0.6)..−27.
2. **ProgressionService** (rewrite; `spend` stays): `buyLotExpansion(state, level)`, `buyParking(state, tier)`, `buyHQ(state, level)`; each: `local ok, code = Progression.check(state, kind, target)`; refuse with `code` (nothing changes); else debit `cashCost` once via `spend` with events `LotExpansion`, `Parking`, `HQUpgrade`, set the field to target, return `true, target`. A replayed request ID never reaches these.
3. **Protocol**: `BuyLotExpansion` payload exactly `{level}` (else `UnexpectedField`), integer 1..`LotExpansion.maxLevel` (else `InvalidLevel`); `BuyParking` exactly `{tier}` (else `UnexpectedField`), integer 2..`Parking.maxTier` (else `InvalidTier`); `BuyHQ` exactly `{level}` (else `UnexpectedField`), integer 2..`HQ.maxLevel` (else `InvalidHQ`).
4. **CompanyProgression.install(CompanyStateService)** (pattern of CompanyTutorial):
   - `setProgressionChangedHandler(handler: (companyId: string, progression) -> ())`, `_notifyProgression(companyId, session)`: pcall the handler with `table.clone(session.state.progression)`; warn `"[ChristmasMarket2] progression notify failed for %s: %s"`.
   - `setProgressionForTest(companyId, fields): boolean`: fields may hold `cash` and `reputation` (integers ≥ 0, ≤ 1e9), `lotExpansion`, `parkingTier`, `hqLevel` (integers in range), `lotManager` (0 or 1, sets `staff.LotManager`); any other key or a bad value → false, nothing changes; no healthy session → false; sets the fields, `revision += 1`, `dirty = true`, then `_notifyProgression`.
5. **CompanyStateService**: require and install CompanyProgression after CompanyTutorial; `_dispatch` passes `payload.level`, `payload.tier`, `payload.level`; set `PROGRESSION_ACTIONS` = the 3 buy actions; success response gets `progressionChanged = true` for them; `handle` calls `_notifyProgression` when set and clears the flag like the others. Summary data gains `progression = Progression.summary(state)` (`plot` stays `table.clone(state.progression)`). `npcArrive` info gains `queuePatience = Progression.queuePatienceSeconds(state)`. `snapshotForTest` gains `progression = table.clone(state.progression)`.
6. **Staff and customers:** `EmployeeService.capacity(state)` = `Progression.employeeCapacity(state)`; `hire`: `EmployeeLocked` when `definition.requiredHqTier ~= nil and Progression.hqLevel(state) < definition.requiredHqTier` (check order unchanged). `CompanyStaff.summary`: `locked` = the same condition; a hired role not in `Staff.WorkingRoles` gets status `"Standby"` (the Lot Manager's computer job is CM2-G9c). `CustomerOrderService.parkingSpaces(state)` = `Progression.parkingSpaces(state)`. `CustomerNpcService:_arrive`: `visit.queuePatience = if type(info.queuePatience) == "number" then info.queuePatience else Npc.QueuePatienceSeconds`; `_patienceOut` uses `visit.queuePatience or Npc.QueuePatienceSeconds`.
7. **WorldService**:
   - `applyHQVisual(plotId: string, level: number): boolean`: level = clamp(floor, 1, 4); destroy `StarterSalesTent`; level 1 → today's `faceRoad(salesStand(...), facing)`; level ≥ 2 → `hqPrimitive(plot, level)`; on the model set attributes `HqLevel` and `HqTier` (tier id); plot attribute `HqLevel`; true. The model name stays `StarterSalesTent` for every tier (step 37 and CM2-13W read it).
   - `hqPrimitive(plot, level): Model` (local, Parts only, built in the lot frame with `lotPosition`, so no `faceRoad`): F = tier footprint, W × D its size, centre (−8, −4); keys `floor/frame/roof` = Pavilion `StoneGray/WoodWarmShade/RoofGreen`, Hut `StoneGray/BarkBrown/RoofSlate`, Chalet `StoneGrayShade/WoodWarm/RoofRed` via `paletteColor`, SmoothPlastic. Parts: `HqFloor` W × 0.6 × D, centre y 0.9 (PrimaryPart); 4 `Post` 0.8 × (eave − 1.2) × 0.8 at the corners inset 0.4, from y 1.2; Hut and Chalet also `WallBack` (W − 1.6) × (eave − 1.2) × 0.6 at z = minZ + 0.3 and `WallLeft`/`WallRight` 0.6 × (eave − 1.2) × (D − 1.6) at x = minX + 0.3 / maxX − 0.3; `Counter` (W/2) × 3.6 × 1.2 at x −8, z = maxZ − 0.6, bottom y 1.2, WoodWarm; `RoofFront` and `RoofBack`, `Shape = Wedge`, size W × (H − eave) × D/2, centre y = eave + (H − eave)/2, centres z = −4 ± D/4, `CFrame.lookAt(c, c + Vector3.new(0, 0, facing))` for the front (road-side) half and `c − ...` for the back half, CanCollide false. Collision group `STRUCTURE_GROUP`.
   - `applyLotExpansionVisual`: pad size Z `54 + BackDepthPerLevel * growth`, offset `facing * (-(BackDepthPerLevel / 2) * growth)` (cap stays `LotExpansion.maxLevel`, now 6); then rebuild `ProgressionVisuals.LotFence` (Model, attribute `LotExpansionLevel`) from `Progression.fenceBoxes(growth)`: per box a Model named by `id` with `Rail_1`/`Rail_2` (Size `(maxX − minX, 0.3, maxZ − minZ)`, centred on the box via `lotPosition`, centre y 1.4 / 2.4, WoodWarm) and posts `Post_k` 0.5 × 3 × 0.5 (centre y 2.05, WoodWarmShade) at both ends and evenly every ≤ 8 studs; CanCollide true, CastShadow false, `STRUCTURE_GROUP`. The pad keeps the LotGround look (224, 239, 244, Snow), so the strip reads as lot ground inside the fence.
8. **main.server**: `syncPlotWorld` → `applyHQVisual(plotId, Progression.hqLevel(state))`, `applyLotExpansionVisual(plotId, Progression.lotLevel(state))`, `applyParkingVisual(plotId, Progression.parkingSpaces(state))`; `clearPlotVisuals` → `applyHQVisual(plotId, 1)`; delete `effectiveParking` and the three `Progression*` branches after `afterOrderAction`; add `companies:setProgressionChangedHandler(function(companyId, progression) ... end)` beside the break-area handler: `plots:getPlot(companyId)` → the three apply calls from `progression` (spaces = `GameConfig.Progression.Parking.tiers[progression.parkingTier].spaces`).
9. **StudioTestService** `commands.setProgression(arg)`: arg a table; `arg.userId` (number, optional) picks that user's active save (R or S), else the shadow S save; the other keys go to `companies:setProgressionForTest(companyId, fields)` (`userId` removed first); false → `failure("BadProgression")`; no save → `failure("NoActiveSave")`; else `success()`.
10. **BusinessState**: `SCHEMA_VERSION = 19`, migration block, `new`, legacy path, `validate` as in Data. Require `Progression` (no cycle: Progression never requires BusinessState).
11. **Playtest module** `Steps/Progression.lua` (steps below); `RunPlaytest` installs it after `Map`; `Map.lua` `lotBox` uses `GameConfig.Placement.BackDepthPerLevel` instead of 6 (comment too); `Staff.lua` step 48 capacity = `Progression.employeeCapacity({ progression = data.plot })`, the Lot Manager check unchanged (S and R are HQ 1).
12. **Docs**: GAME_DESIGN §7: replace the paragraph with the ladder (levels, costs, requirements, tags, unlocks; new species and extra counters come with CM2-G9d; Lot Manager hire at HQ 4, job with CM2-G9c; Workshop "Coming soon"). TECHNICAL_ARCHITECTURE §3: the three payloads and codes (`InvalidLevel`/`InvalidTier`/`InvalidHQ`, `AlreadyOwned`, `NotNextLevel`, `PrerequisitesNotMet`, `InsufficientReputation`, `InsufficientFunds`), replace `Progression.Upgrade`; §4: schema 19 `progression`. MODEL_INTEGRATION: line "lot depth −27..−75 reserved for 6 levels × 8" gains "(`BackDepthPerLevel` 8 since CM2-G9a)"; the reserve line becomes "hide levels {1, 2, 3, 4}, hidden rows at levels 0–6: 0, 1, 2, 3, 4, 4, 4; levels 5–6 grow onto open snow (`maxLevel` 6)"; add "HQ tiers 2–4 show Part primitives of the CM2-13a footprints until CM2-13W". DECISION_LOG entry "2026-11-23 — Progression ladder, CM2-G9a (engineering)": table rows Ladder values (O/P), Parking 2 tiers, Depth 8 per level, Reserve hide levels, Target payloads (idempotency), Migration 19 (parking 3 → tier 2), Stand box fixed, HQ visuals primitive, Patience per visit + ReservationSeconds 165, Deferred (G9c, G9d).

## Tests (headless)
New file `Progression_Test.lua` (10 tests):
| Test name | Asserts |
|---|---|
| ladder config has 6 levels, 2 parking tiers and 4 HQ tiers with tags | counts; every entry has `evidence` in `GameConfig.Evidence`; ids as tabled; `maxSpaces == tiers[maxTier].spaces == Npc.MaxPerPlot`; `tiers[1].spaces == Customers.BaseParkingSpaces` |
| observed ladder values | lot 1 = 1200; parking 2 = 600 / 4 spaces; Pavilion 2500, 250, lot 1, parking 2, species 4, checkouts 2, staff 3, patience 0.12; Hut checkouts 2, staff 5; tent staff 2; Lot Manager 1250000 at 4 |
| ladder has no deadlock | from `BusinessState.new` with cash and reputation 1e9, buying the first ready offer (order LotExpansion, Parking, HQ) repeatedly reaches lot 6, parking 2, HQ 4 in exactly 10 purchases |
| offer rows match the purchase check | for 6 fixed states (fresh; cash 1200 rep 0; Pavilion one row short each of lot/parking/rep/cash; all met): `offer.ready` ⇔ `ProgressionService.buy*` succeeds; on refusal the code = `ROW_CODES` of the first unmet row; cash unchanged on refusal |
| a purchase targets one level | `AlreadyOwned` for target ≤ current, `NotNextLevel` for current + 2, `InvalidLevel` for 0, 7, 1.5; none changes cash or state |
| HQ footprints fit the Stand box and clear the lot at every level (G19) | each tier footprint ⊂ `KeepClear.Stand`; no overlap (positive penetration on both axes) with every other KeepClear box, the 4 parking spaces (x `ParkingFirstX + 12(i−1)` ± 4, z `ParkingDepth` ± 6), the 4 break-area candidates (± `HalfSize`) and the decor fence circles (r 5.5); for L 0..6 the footprint lies inside the lot (x ±40, z −(27 + 8L)..27) and overlaps no `fenceBoxes(L)` box |
| the reserve holds all levels and the fence stays clear | `LotHalfDepth + BackDepthPerLevel * maxLevel == 75`; for L 0..6 each fence box overlaps no KeepClear box or break candidate, and no reserve fir of a row with `row > hiddenRowCount(L)` (footprints from `MapLayout.pieces()`, lot frame of its plot) |
| the workshop unlocks with HQ 4 and a Lot Manager | locked at HQ 3 + LM, HQ 4 without LM; unlocked with both; rows have = state |
| queue patience grows with the HQ | `queuePatienceFor` 1..4 = 90, 101, 108, 117 |
| migrates schema 18 progression | `migrate18` of `{0, 0, nil}` → `{0, 1, 1}`; `{2, 3, nil}` → `{2, 2, 1}`; `{3, 4, "ChristmasPavilion"}` → `{3, 2, 2}`; non-table → new; result has exactly 3 keys |

Changed or added elsewhere:
| File | Test | Change |
|---|---|---|
| `ProgressionService_Test` | both tests | rewrite: lot 1 costs 1200 and needs no rep (cash 1200 → 0, storage 40); Pavilion refused until lot 1 + parking tier 2, then cash 5000 → 2500, `hqLevel` 2 |
| `ProgressionProtocol_Test` | both + **new** "accepts only target payloads" | `{level = 1}` accepted, `{}` → `UnexpectedField`; HQ `{level = 5}` / `{hqId = "FreeMoney"}` refused; new: parking `{tier = 2}` ok, `{tier = 1}` `InvalidTier`, lot `{level = 7}` `InvalidLevel`, `{level = 1, extra = 1}` `UnexpectedField` |
| `CompanyStateService_Test` | **new** "a replayed purchase charges once" | lot 1 with cash 1200: same requestId twice → second `DuplicateRequest`, `previousResult` "Success", cash 0, level 1, revision +1 once |
| `CompanyStateService_Test` | **new** "two requests for one level charge once" | different requestIds, both `{level = 1}`, cash 5000 → second `AlreadyOwned`, cash 3800 |
| `CompanyStateService_Test` | **new** "purchases notify the progression handler" | handler called once with `{lotExpansion = 1, parkingTier = 1, hqLevel = 1}`; not called on a refusal |
| `EmployeeService_Test` | **new** "the Lot Manager hires once at HQ 4" | `hqLevel` 4, cash 2000000 → ok, cash 750000; again `AlreadyHired`; capacity 6 |
| `CompanySummaryProtocol_Test` | **new** "summary carries the ladder rows" | fresh save: `progression.lotExpansion.next.target` 1, rows = one `Cash` row (have 84, need 1200, met false); `hq.next.rows` ids `LotExpansion, ParkingTier, Reputation, Cash` |
| `BusinessState_Test` | **new** "migrates schema 18 records to 19" + SCHEMA 18 → 19 | a v18 record (`parkingSpaces` 3, `hqTier` "ChristmasPavilion", lot 2) migrates and validates with `{2, 2, 2}` |
| `CustomerNpcService_Test` | **new** "queue patience follows the HQ tier" | a visit with `info.queuePatience` 117 does not walk out at 100 s in `Queued` and walks out after 118 s |
| `EmployeeService_Test`, `StaffNpcService_Test`, `CustomerCheckout_Test`, `CustomerNpcService_Test`, `CustomerOrderService_Test` | existing | `progression.parkingSpaces = 4` → `parkingTier = 2`; `hqTier = "ChristmasPavilion"` → `hqLevel = 2`; CustomerOrderService 353–361: `buyParking(state, 2)` (cash 600) → spaces 4, again → `AlreadyOwned` |
| `GameConfig_Test` | existing | Pavilion evidence via `Progression.HQ.tiers[2]`; reservation inequality and MaxVisit sum use `Progression.queuePatienceFor(4)` |
| `NpcTransactions_Test` | existing | `ReservationSeconds` 165 |
| `MapLayout_Test` | existing | hide levels "1,2,3,4"; hidden "0,1,2,3,4,4,4"; `27 + 8 * level` |
Expected: `lune run tests/headless/run.luau` → **562** run, 0 failed (544 + 10 new in Progression_Test + 8 new elsewhere).

## Playtest (Studio, via playtester; now: tier L, money, saves, world)
1. Rojo sync, live source shows `BUILD = "cm2-g9a"`; Play; `runPlaytest {mode="full"}` → **60/60** (58 + 2).
2. Step `"58"` `"PROGRESSION_LADDER"`, needs `{ "02" }`, on S: remember `snap(S.userId)` cash, reputation, progression, `staff.LotManager`; `setProgression {cash 0, reputation 0, lotExpansion 0, parkingTier 1, hqLevel 1}`; summary `progression.lotExpansion.next` target 1, cost 1200, `ready` false; buy `{level = 1}` → `InsufficientFunds`, cash 0. `setProgression {cash 1200}`; `act` with requestId `"g9_lot_1_aaaa"` twice → ok data 1, then `DuplicateRequest`; a new requestId `{level = 1}` → `AlreadyOwned`; snapshot cash 0, level 1; S's plot `LotExpansionLevel` 1, `Reserve.<S plot>` without `Row_1`, `LotFence.Back` present. Parking: cash 600, `{tier = 2}` ok, 4 `Parking_*` parts, again → `AlreadyOwned`. HQ: cash 2500, rep 250 → `{level = 2}` ok, `StarterSalesTent` `HqLevel` 2, summary `staff.capacity` 3. `setProgression {lotExpansion 5, hqLevel 3, cash 600000, reputation 3000}` → `{level = 4}` ok; summary Lot Manager `locked` false, `workshop.unlocked` false; `setProgression {cash 1250000}` → `Employee.Hire {employeeId = "LotManager"}` ok, cash 0, again `AlreadyHired`; `workshop.unlocked` true. Restore: `setProgression` with the remembered values, `setStaff {LotManager, remembered}`; snapshot equals them. Detail `lot 1 once, parking 2 once, HQ 2 and 4, Lot Manager once, workshop unlocked, restored`.
3. Step `"59"` `"HQ_FOOTPRINTS"`, needs `{ "02" }`, on S's plot: for L 1..4 `WorldService.applyHQVisual(S.plotId, L)`; the lot-frame AABB of `StarterSalesTent` over every BasePart's 8 corners (as step 37) lies in `KeepClear.Stand` (+0.05); for L ≥ 2 also within the tier footprint ± 0.1 and `HqLevel` = L; no overlap with `CheckoutCounter`'s AABB, the `Parking_*` parts, or KeepClear `Pickup`, `Bays`, `Spawn`, `Sign`, `Checkout`. Then for L 0..6 `applyLotExpansionVisual(S.plotId, L)`: pad Size.Z = 54 + 8L (± 0.01); `LotFence` `LotExpansionLevel` = L; each fence part's AABB within its `fenceBoxes(L)` box + 0.3 and outside the Stand box. Restore both visuals from S's snapshot progression. Detail `HQ 1-4 inside Stand (largest x a..b, z c..d), levels 0-6 fence ok, restored`.
4. Queue in "Studio-Test ausstehend" (PC-7): captures of S's plot at HQ 2, 3, 4 and at lot levels 1 and 6 (fence, pad, reserve), each from the road side; and at least one mirrored plot (4–6) to confirm the roof slopes and the counter face the road.

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` → 562/562, `rojo build` both projects.
- Config schema test, ladder values with evidence tags, schema 19 migration and validation, no deadlock.
- The purchase check and the summary rows come from `Progression.rows`/`check` (test "offer rows match the purchase check").
- G19: every HQ tier and expansion level clears parking, pickup row, stocking area (KeepClear) and checkout, headless and in Studio (step 59).
- Idempotent under double requests: replayed request ID and a second request for the same level each charge once (headless and step 58).
- Lot Manager hireable only at HQ 4, once; Elf Workshop unlocked only with HQ 4 + Lot Manager, no action.
- Full run 60/60; Studio server steps not deferred.

## Out of scope
- **CM2-G9b** Land tab UI and the Employees "Standby" text (`docs/plans/CM2-G9b.md`).
- **CM2-G9c** (proposed, L): the Lot Manager as a visible avatar at the HQ computer that orders trees by itself (spends cash).
- **CM2-G9d** (proposed, L + MODEL): HQ unlock content: the new species per tier (names, wholesale by the 5 × rule, supplier rows, tree models) and the 2nd/3rd checkout station with its queue.
- HQ art (CM2-13W), per-tier KeepClear, movable HQ (CM2-32/33), balance values (CM2-28).

## Amendment 1 (2026-11-23, after the Studio playtest: 59/60, step 59 FAIL)
Finding: HQ 1 is the CC0 tent art at its native size, lot-frame AABB x −24.21..8.21, z −16.18..8.18 (32.42 × 24.36), 0.21 / 0.18 past `KeepClear.Stand` (32 × 24). Step 37 hid this with ±0.5 slack.
**Decision (c): fit the HQ 1 art into the Stand box.** `salesStand` scales the art down (uniform `Model:ScaleTo`) when it is larger than Stand minus a 0.1 margin per side → factor min(31.8/32.42, 23.8/24.36) ≈ 0.977. Rejected: (a) widening Stand moves the inflated NPC obstacle (aisle margin 1 → 0.5), stocking and break-area keep-clear and can strand saved trees in the new strip; (b) the Part tent replaces the approved CC0 look and pulls CM2-44 forward. **CM2-44 is not pulled forward.** Stand stays x −24..8, z −16..8; tier footprints unchanged.

| # | File | Delta |
|---|---|---|
| A1 | `GameConfig.lua` | `Placement.StandFitMargin = 0.1, -- PROVISIONAL (CM2-G9a A1): HQ art fits KeepClear Stand minus this per side`, after `KeepClear` |
| A2 | `ArtLibrary.lua` | `function ArtLibrary.fitScale(sizeX: number, sizeZ: number, maxX: number, maxZ: number): number` = `math.min(1, maxX / sizeX, maxZ / sizeZ)`; returns 1 when any argument is non-finite or ≤ 0. |
| A3 | `WorldService.lua` | local `keepClearBox(id)` (loop `Placement.KeepClear`, `error` if missing) and `worldExtents(model): (number, number)` = world X and Z size of the AABB over every BasePart's 8 corners (lot axes are world axes, `lotPosition`). In `salesStand`, art path only, right after `levelArt(model)`: Stand = `keepClearBox("Stand")`, m = `StandFitMargin`, `scale = ArtLibrary.fitScale(sizeX, sizeZ, Stand width − 2m, Stand depth − 2m)`; if `scale < 1` then `model:ScaleTo(model:GetScale() * scale)`; `model:SetAttribute("FitScale", scale)`; then the existing centring block (re-centres after the scale). Fallback `tent` unchanged (18 × 14) |
| A4 | `Steps/Progression.lua` step 59 | Collect, don't stop: `local failures: { string } = {}` and `note(ok, message)`. Every check inside both loops uses `note`; when `applyHQVisual`/`applyLotExpansionVisual` returns false, or `StarterSalesTent`, `CheckoutCounter`, pad, `LotFence` or a fence side is missing, `note` it and skip the rest of that level/side (`continue`). Wrap each level's body in its own `pcall`; an error is noted as `"HQ <L>: <err>"` / `"lot <L>: <err>"`. Stand message: `"HQ %d exceeds Stand (%s): %s"` (`boxText(standBox)`, `boxText(box)`). HQ 1 also notes `FitScale` is nil (fallback tent) or a number in (0, 1]. After the restore: `check(#failures == 0, string.format("%d failures: %s", #failures, joined))`, joined = the first 12 by `"; "` plus `"; +%d more"` above 12. Detail: `"Stand x %.2f..%.2f, z %.2f..%.2f; HQ 1 scale %.3f; HQ 1-4 inside (HQ 4 x %.1f..%.1f, z %.1f..%.1f), levels 0-6 fence ok, restored"` (scale 1 for the fallback) |
| A5 | `RunPlaytest.lua` | `BUILD = "cm2-g9a-a1"` |
| A6 | Docs (step 12) | MODEL_INTEGRATION: "HQ 1 tent art is scaled to fit KeepClear Stand minus `StandFitMargin` 0.1 (≈ 0.977)". DECISION_LOG row "Stand box fixed": append "HQ 1 art fitted by uniform scale (A1); widening Stand and the Part tent rejected" |

**Tests (headless) +2 → 564/564:**
| File | Test | Asserts |
|---|---|---|
| `ArtLibrary_Test` | "fitScale shrinks only oversize art" | (32.42, 24.36, 31.8, 23.8) within 1e-9 of 23.8/24.36; (18, 14, 31.8, 23.8) = 1; (64, 12, 32, 24) = 0.5; (0, 14, …) = 1; (0/0, 14, …) = 1 |
| `Progression_Test` | "the fitted Stand box holds every HQ footprint" | `StandFitMargin` a number, 0 < m ≤ 0.5; every tier footprint inside Stand shrunk by m per side |

**Re-test:** headless 564/564 plus stylua, selene, rojo build; Studio live source `BUILD = "cm2-g9a-a1"`, full run **60/60**; step 59 detail shows Stand x −24.00..8.00, z −16.00..8.00 and HQ 1 scale 0.970..0.985; step 37 still PASS.

## Amendment 2 (2026-11-23, after Studio run 2, BUILD cm2-g9a-a1: 59/60, step 58 FAIL)
**Cause: harness defect, not gameplay.** Step 58 uses the fixed request ID `"g9_lot_1_aaaa"`. S's save persists across Play sessions (`shadowJoin` → `saveSlots:openProfile`; the reason CM2-ART2 added `drainShadowBays`), and so does its `state.recentRequests` (last `MaxHistoryEntries` 100, `Protocol.beginRequest`). Run 1 stored `g9_lot_1_aaaa` with result `Success`; in run 2 `handle` answers the first lot-1 request with `DuplicateRequest` (`previousResult` "Success") before `Progression.check` runs, and line 147 reports only "lot 1 purchase failed".
Evidence: in run 2 every check before line 147 passed (offer target 1, $1,200, not ready, `InsufficientFunds`, cash 0), so with cash 1200, lot 0, HQ 1 the purchase check accepts. `Progression.check` has no placement, stock or break-area condition, so trees, decor or a break area in the strip cannot block it. `setProgression` at the start of the step overwrites run 1's restore. Rate limit is ruled out because `act` waits `ACTION_PAUSE`. The server behaves as designed: a reused request ID never charges twice (TEST_PLAN BUY-02). Every other step already uses `prefix .. GUID`.

| # | File | Delta |
|---|---|---|
| B1 | `Steps/Progression.lua` | `local HttpService = ctx.HttpService` beside the other ctx locals. Step 58: `local lotRequestId = "g9_lot_1_" .. HttpService:GenerateGUID(false)` (45 chars, passes `isRequestId`); both the first and the replayed lot-1 `act` use it. No other literal request IDs. |
| B2 | same | local `responseText(response: any): string`: not a table → `tostring(response)`; `ok == true` → `"ok data " .. tostring(response.data)`; else `tostring(response.errorCode)`, plus `" (previous " .. tostring(response.previousResult) .. ")"` when `previousResult ~= nil`. `expectCode` uses it for "got %s". |
| B3 | same | Replace the line-147 check: if `not (type(first) == "table" and first.ok == true and first.data == 1)` then `local now = snap(S.userId)` and `check(false, string.format("lot 1 purchase failed: %s; lotExpansion %s, hqLevel %s, cash %s, reputation %s", responseText(first), tostring(now.progression.lotExpansion), tostring(now.progression.hqLevel), tostring(now.cash), tostring(now.reputation)))`. Call `snap` only on failure. |
| B4 | same | After `expectCode(replay, "DuplicateRequest", "replayed lot 1")`: `check(replay.previousResult == "Success", "replayed lot 1: previousResult is " .. tostring(replay.previousResult))`. |
| B5 | `RunPlaytest.lua` | `BUILD = "cm2-g9a-a2"` |
| B6 | `docs/TEST_PLAN.md` §3b | Append to the CM2-ART2 Amendment 1 sentence block (before "Step 37 first checks"): "CM2-G9a: `58 PROGRESSION_LADDER` (S buys lot 1, parking 2, HQ 2 and 4 and the Lot Manager once each through the real actions, a replayed request and a second request charge nothing, the workshop unlocks, S restored) and `59 HQ_FOOTPRINTS` (HQ 1-4 inside KeepClear `Stand` and clear of counter, parking and KeepClear boxes; fence for lot levels 0-6) in `Steps/Progression.lua`. Request IDs in playtest steps are unique per run (`<prefix>_` .. GUID): S's save and its `recentRequests` persist across Play sessions, so a fixed ID replays as `DuplicateRequest` in the next run (CM2-G9a A2)." |

No server, config or schema change. The leftover `g9_lot_1_aaaa` record in S's save is harmless and ages out after 100 newer requests. Do not clear it.

**Re-test:** headless still **564/564** (no new test; `CompanyStateService_Test` "a replayed purchase charges once" covers the server rule), plus stylua, selene and `rojo build` for both projects. Studio: the live source shows `BUILD = "cm2-g9a-a2"`. Run 1: Play, then `runPlaytest {mode="full"}` → **60/60**. Then Stop and start a new Play session. Run 2: `runPlaytest {mode="full"}` → **60/60**. In both runs step 58 shows the detail `lot 1 once, parking 2 once, HQ 2 and 4, Lot Manager once, workshop unlocked, restored`, step 59 passes as in A1 (HQ 1 scale 0.970..0.985), and step 37 passes. Record both SUMMARY lines in PROGRESS.md.

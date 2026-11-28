# CM2-10DW — Map dressing in the world

Pattern: CM2-10W (`docs/archive/plans/CM2-10W.md`), CM2-G12a night lights.

## Goal
The 110 CM2-10D dressing pieces (snow piles, snowmen, sleds, wood stacks, fir barrels, 10 extra lamps, 8 benches, 10 firs) stand in the village; the new lamps glow at night.

## Source of truth
Backlog CM2-10DW; MODEL_INTEGRATION "Map dressing (CM2-10D)" (placement contract, measured sizes, sums) and "Map in the world (CM2-10W)"; plan `docs/archive/plans/CM2-10D.md`. Attribute convention is `ArtPath`/`ArtAssetId`/`ArtVersion` (the CM2-10D plan's `ArtRoot` wording was wrong).

## Implementer tier
Tier: M. Reason: world generation data and placement across MapLayout, MapWorld and two playtest steps; no save, money, remote or inventory change.

## Skill checks
- building: set anchoring, collision, shadows, colour and material explicitly on every fallback Part; offset sub-parts from the piece pivot (`offsetPart`), never world coordinates.
- performance: the budget is hard (≤ 442 models, ≤ 179700 tris, ≤ 1351 MeshParts); streaming is on, so Studio steps find pieces under `Map` on the server only.
- lighting: new lamps reuse `MapWorld.nightLight` with `GameConfig.DayCycle.LampLight`; no other lights.
- luau-core: build the dressing list from an ordered array (never `pairs` over a dictionary) so ids and order are deterministic.
- collaboration: repo is the truth; no Studio-only edits; report PASS only with evidence.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/MapLayout.lua` | Change | 6 ART entries, COUNTS, `DRESSING` data, `dressingPieces()`, appended in `generate` |
| `src/server/Services/MapWorld.lua` | Change | group `Dressing`, 3 fallbacks |
| `tests/studio/Cases/MapLayout_Test.lua` | Change | budgets, fallback/skip counts, 1 new test |
| `tests/studio/Playtest/Steps/DayNight.lua` | Change | step 61 expects 56 lights, 10 dressing lamps |
| `docs/MODEL_INTEGRATION.md` | Change | 3 lines in "Map dressing (CM2-10D)" |

## Data and config
New path constants and `MapLayout.ART` entries (w, l = measured, MODEL_INTEGRATION; triangles/meshParts = budgets):

| Const | artPath | w | l | triangles | meshParts | fallback |
|---|---|---|---|---|---|---|
| SNOW_A | Props/SnowPileA | 5.76 | 3.83 | 160 | 2 | "SnowPileA" |
| SNOW_B | Props/SnowPileB | 4.58 | 4.64 | 240 | 2 | "SnowPileB" |
| SNOWMAN | Props/Snowman | 3.5 | 2.3 | 560 | 3 | nil |
| SLED | Props/Sled | 1.77 | 3.99 | 300 | 3 | nil |
| WOODSTACK | Props/WoodStack | 5.6 | 2.31 | 520 | 3 | nil |
| FIR_BARREL | Props/FirBarrel | 2.4 | 2.4 | 360 | 3 | "FirBarrel" |

`MapLayout.COUNTS` deltas: LAMP 22→32, BENCH 4→12, FIR 152→162; new SNOW_A 32, SNOW_B 14, SNOWMAN 8, SLED 6, WOODSTACK 6, FIR_BARREL 16. Totals 412 models, 179260 triangles, 1335 MeshParts (PROVISIONAL budget from CM2-10D, planner-checked).

## Steps
1. **MapLayout.** Add the constants and ART/COUNTS rows above. Add `MapLayout.DRESSING_CODES = { A = SNOW_A, B = SNOW_B, SM = SNOWMAN, SL = SLED, WS = WOODSTACK, FB = FIR_BARREL, L = LAMP, BE = BENCH, F = FIR }` and `MapLayout.DRESSING: { { code: string, x: number, z: number, yaw: number } }` = the 55 entries of the contract, copied verbatim in order (sections 1–6, nn 01–55), one entry per line, a comment per section.
2. `local function dressingPieces(): { Piece }`: for `nn, e in ipairs(MapLayout.DRESSING)` insert `fixed(string.format("Dress_%02d_N", nn), DRESSING_CODES[e.code], "Dressing", e.x, 0, e.z, e.yaw)` then `fixed(string.format("Dress_%02d_S", nn), path, "Dressing", e.x, 0, -e.z, (e.yaw + 180) % 360)`. In `generate`, after the final `for _, piece in generated` loop, append every `dressingPieces()` piece to `list`. Dressing never enters `boxes` and uses no random numbers (the existing 302 pieces stay identical).
3. **MapWorld.** `GROUPS` gains `"Dressing"` (last). Not in `NO_SHADOW_GROUPS`. New `FALLBACKS` (via `newModel`, which sets `MapFallback`; every Part Anchored, CanCollide true unless stated, CastShadow true):
   - `SnowPileA`: Part `Pile` 5.0 x 1.0 x 3.0, offset (0, 0.5, 0), "SnowWhite", `Enum.Material.Snow`.
   - `SnowPileB`: Part `Pile` 4.0 x 2.2 x 4.0, offset (0, 1.1, 0), "SnowWhite", Snow.
   - `FirBarrel`: Part `Barrel` 2.4 x 1.8 x 2.4, offset (0, 0.9, 0), "WoodWarm", `Enum.Material.Wood`; Part `Needles` 1.8 x 4.0 x 1.8, offset (0, 3.8, 0), "NeedleGreen", `Enum.Material.Grass`, CanCollide false.
   Set `model.PrimaryPart` to `Pile` / `Barrel`. Lamps, benches and firs use the existing paths: `placePiece` already adds the lamp light for `Props/LampPost` and the Fir fallback works at scale 1.
4. **Step 61** (`DayNight.lua`): add `local DRESSING_LAMPS = 10`; expected lights = `LAMP_COUNT + DRESSING_LAMPS + PLOT_LIGHTS + GATE_LIGHTS` (56). Second loop: count models with `MapPiece` matching `^Dress_%d%d_[NS]$` whose parent is `Map.Dressing` and that hold exactly one tagged light; expect 10 (`"%d dressing lamps, expected %d"`). Return string `"%d night lights off on the server, %d lamps and %d dressing lamps with one each"`. Update the header comment (… = 56). The existing `^Lamp_%d%d$` loop stays at 22.
5. **MODEL_INTEGRATION** "Map dressing (CM2-10D)": replace the last line ("CM2-10DW: …") with: "In the world (CM2-10DW): `MapLayout.DRESSING` holds the contract, pieces in `Map.Dressing`; Part fallbacks SnowPileA/B (`Pile`) and FirBarrel (`Barrel` + `Needles`); Snowman, Sled, WoodStack skipped without art. Map totals 412 models, 179260 triangles, 1335 MeshParts; NightLights 56." In "Map in the world (CM2-10W)" add `Dressing` to the `Map` folders list.

## Tests (headless)
| Test case file | Test name | Asserts |
|---|---|---|
| MapLayout_Test | places the contract counts within the map budget (change) | `MAX_TRIANGLES, MAX_MESHPARTS, MAX_MODELS = 179700, 1351, 442`; `meshParts == 1335`; `models == 412`; `triangles == 179260` |
| MapLayout_Test | plan falls back or skips missing art … (change) | fallback set 8→11, skip 5→8, `#missing` 13→19, partial `#partialMissing` 12→18 |
| MapLayout_Test | places the 110 dressing pieces from the contract (new) | 110 pieces with group `Dressing`, ids `Dress_01_N` … `Dress_55_S` each once; every `_S` = its `_N` with z negated and yaw `(yaw+180)%360`; 10 have artPath `Props/LampPost`; fake root without the 6 new paths: SnowPileA/B and FirBarrel pieces `Fallback`, Snowman/Sled/WoodStack `Skip` (62 fallback, 20 skip among Dressing) |
The existing keep-out test covers ≥ 3 studs for dressing (no exemption added). Expected headless count: 790 + 1 = **791**.

Fallback/skip numbers in the new test: A 32 + B 14 + FB 16 = 62 fallback; SM 8 + SL 6 + WS 6 = 20 skip (fake root = `fakeRoot` of every ART path except the 6 new ones, so L/BE/F are `Art`).

## Playtest (Studio, via playtester; now: world wiring)
Smoke run plus:
1. Edit: `ArtAssets/Props/{SnowPileA,SnowPileB,Snowman,Sled,WoodStack,FirBarrel}` exist with `ArtPath`, `ArtAssetId`, `ArtVersion`.
2. Play, step 56 MAP_WORLD PASS: "map pieces outside Reserve" equals the plan count (412 − 120 reserve, minus skips; with all art imported: 292) and 0 parts in car lanes, truck lanes and lots; `Map.Dressing` holds 110 models, `MapFallback` on none (art present).
3. Step 61 NIGHT_LIGHTS PASS: exactly 56 night lights, 22 lamps and 10 dressing lamps with one each.
4. Steps 37, 40 (0 snaps) and 57 PASS.
5. `runPlaytest {mode="full"}` all PASS (backlog Accept; last art-in-world step before 10I).
6. Screenshot of the street at plot 1 and the square from the default camera: props stand on snow, none floats or sinks (> 0.3 studs).

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (791 passed), `rojo build default.project.json` and `release.project.json`, `art.luau verify release.rbxlx` 48 integrated.
- Every dressing piece ≥ 3 from every keep-out box on all 6 plots; totals ≤ 442 / 179700 / 1351; fallback and skip counts as above; Studio steps 56, 61 (56 ≤ 58), 37, 40, 57 and the full run PASS.

## Out of scope
CM2-10I infrastructure (reserved zones stay empty); new art; collider or LOD tuning; lot decor (CM2-32/33).

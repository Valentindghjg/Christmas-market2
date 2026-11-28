# CM2-10IW — Village infrastructure in the world

## Goal
The 77 CM2-10I pieces stand in the village, poles carry wires, road signs show text, bus stops and the shop glow at night.

## Source of truth
Backlog CM2-10IW; MODEL_INTEGRATION "Village infrastructure (CM2-10I)" (contract) and "Map in the world (CM2-10W)"; `docs/plans/CM2-10I.md` (W/L maxima, budgets).

## Implementer tier
Tier: M. Reason: world generation data, wiring and text across MapLayout, MapWorld, Localization and two playtest steps; no save, money, remote or inventory change.

## Skill checks
- building: fallback Parts set Anchored, CanCollide, colour, material; offsets from the pivot (`offsetPart`); sign text on the art's attachments.
- performance: budget hard (≤ 532 / 219260 / 1635); wires are Beams, not Parts; streaming on (a Beam hides when a pole streams out); Studio checks on the server.
- lighting: only `MapWorld.nightLight` with `DayCycle.LampLight` (Shadows false); exactly 3 new.
- luau-core: contract, wires and `signs` are ordered arrays (no `pairs`).
- localization: sign text only via new keys (en + de) through `surfaceText`.
- collaboration: repo is the truth; PASS only with evidence.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/MapLayout.lua` | Change | data, `infraPieces`, `wires` |
| `src/server/Services/MapWorld.lua` | Change | group, fallbacks, lights, signs, wires |
| `src/shared/Localization.lua` | Change | 3 keys en + de |
| `tests/studio/Cases/MapLayout_Test.lua` | Change | counts, 2 new tests |
| `tests/studio/Playtest/Steps/Map.lua` | Change | step 56 (g2) |
| `tests/studio/Playtest/Steps/DayNight.lua` | Change | step 61 |
| `docs/MODEL_INTEGRATION.md`, `docs/DECISION_LOG.md` | Change | step 10 |

## Data and config
One local constant per path (names free). `MapLayout.ART` rows use the CM2-10I W/L **maxima** (the contract's clearances use them) and budgets:

| Code | artPath | w | l | tris | MP | fallback | COUNTS |
|---|---|---|---|---|---|---|---|
| ST | Props/SnowStake | 0.4 | 0.4 | 60 | 2 | "SnowStake" | 14 |
| HY | Props/FireHydrant | 1.4 | 1.4 | 200 | 3 | nil | 5 |
| TB | Props/TrashBin | 1.6 | 1.6 | 220 | 3 | nil | 5 |
| UB | Props/UtilityBox | 2.6 | 1.6 | 160 | 3 | "UtilityBox" | 2 |
| MB | Props/MailboxCluster | 3.0 | 1.2 | 300 | 3 | nil | 5 |
| GR | Props/GuardRail | 8.0 | 1.0 | 240 | 3 | "GuardRail" | 16 |
| UP | Props/UtilityPole | 1.0 | 3.0 | 260 | 3 | "UtilityPole" | 20 |
| RS | Props/RoadSignSpeed | 2.2 | 0.6 | 160 | 3 | nil | 2 |
| RD | Props/RoadSignDirection | 5.6 | 0.6 | 300 | 3 | nil | 2 |
| BS | Props/BusStop | 7.6 | 3.6 | 400 | 3 | nil | 2 |
| GS | Buildings/GarageShed | 9.0 | 9.0 | 1400 | 6 | nil | 2 |
| VS | Buildings/VillageShop | 24 | 18 | 3000 | 10 | nil | 1 |
| FS | Buildings/FireStation | 26 | 20 | 3000 | 10 | nil | 1 |

Map totals **489 / 203580 / 1572** (+77 / +24320 / +237; planner re-checked: keep-out min 3.30, road surfaces min 1.00). Night lights 56 → **59**.
Localization (en / de): `mapSignSpeed` "20" / "20"; `mapSignVillageSquare` "Village Square" / "Dorfplatz"; `mapSignBridge` "Bridge" / "Brücke" (after `mapDeliveries`).

## Steps
1. **MapLayout.** Add constants, ART and COUNTS rows. Piece type gains `signs: { { attachment: string, textKey: string } }?`. `MapLayout.INFRA_CODES = { ST = STAKE, … FS = FIRE }` (13 codes). `MapLayout.INFRA_PAIRS` = contract sections 1-6 (36 entries, nn 01-36, stakes expanded to 7 entries x -266 … -405, z 17.9, yaw 0), `MapLayout.INFRA_SINGLES` = section 7 (5 entries, nn 37-41), `{ code, x, z, yaw }` per line, verbatim.
2. `local function infraPieces(): { Piece }`: as `dressingPieces` (ids `Infra_%02d_N/_S`, group `"Infrastructure"`), then singles `Infra_%02d` (36 + k) unmirrored. Signs: code RS → `{ {SignFront, mapSignSpeed} }` on both; code RD → `_N` `{ {SignTop, mapSignBridge}, {SignBottom, mapSignVillageSquare} }`, `_S` `{ {SignTop, mapSignVillageSquare}, {SignBottom, mapSignBridge} }`. Appended in `generate` after dressing; no random numbers, no `boxes`.
3. `function MapLayout.wires(): { { from: string, to: string, attachment: string } }`: for side in `{ "N", "S" }`, k = 1..9, attachment in `{ "WireA", "WireB" }`: `{ from = Infra_<k>_<side>, to = Infra_<k+1>_<side>, attachment }` (ids `%02d`) → 36 entries.
4. **MapWorld.** `GROUPS` gains `"Infrastructure"` (last; not in `NO_SHADOW_GROUPS`). Add `local function findAttachment(model: Instance, name: string): Attachment?` ; `addLampLight` uses it. `local LIT_PATHS = { ["Props/LampPost"] = true, ["Props/BusStop"] = true, ["Buildings/VillageShop"] = true }`; `placePiece` calls `addLampLight` when `LIT_PATHS[piece.artPath]`.
5. Fallbacks via `newModel` (CastShadow, CanCollide true unless stated; PrimaryPart = first part):
   - `SnowStake`: `Stake` 0.3 x 5 x 0.3 at (0, 2.5, 0), "GoldAccent", SmoothPlastic.
   - `GuardRail`: `Rail` 8 x 2.4 x 0.6 at (0, 1.2, 0), "BarkBrown", Wood.
   - `UtilityBox`: `Box` 2.4 x 3.2 x 1.4 at (0, 1.6, 0), "RoofGreen", SmoothPlastic.
   - `UtilityPole`: `Pole` 0.8 x 17.6 x 0.8 at (0, 8.8, 0), "BarkBrown", Wood; `CrossArm` 0.3 x 0.3 x 3.0 at (0, 16.6, 0), same, CanCollide false, holding Attachments `WireA` at (0, 0.5, -1.2) and `WireB` at (0, 0.5, 1.2).
6. `local function addInfraSigns(kit, model, piece, pivot)` (called in `placePiece` when `piece.signs`): per sign, `att = findAttachment(model, sign.attachment)`; nil → next. `size` = `SignFront` (1.4, 1.4), `SignTop`/`SignBottom` (4.2, 0.7). `flatPart(kit, model, "SignText_" .. sign.attachment, Vector3.new(size.X, size.Y, 0.05), CFrame.new(att.WorldPosition) * pivot.Rotation * CFrame.new(0, 0, -0.03), Color3.new(1, 1, 1))`, `Transparency` 1, then `surfaceText(part, "SignGui", sign.textKey, colour)`; colour `paletteColor("MetalDark")` for `SignFront`, `rgb(UiTheme.Colors.Cream)` otherwise.
7. `local function wirePoles(group: Instance)`, called in `build` after the placement loop with `groups.Infrastructure`: per `MapLayout.wires()` entry find both models (`FindFirstChild`) and both attachments; any nil → next. Beam `Name = entry.attachment .. "Beam"`, Attachment0/1, Width0/1 0.1, Color MetalDark, Segments 1, FaceCamera true, LightInfluence 1, no Texture, parent = the `from` model.
8. **Step 56** (`Map.lua`), section (g2) after (g): `Map.Infrastructure` exists; Beams `WireABeam`/`WireBBeam` under it with both attachments set == 36 (`"%d wires, expected 36"`); per piece with `signs` whose model exists, `textOf(model, "SignText_" .. att, "SignGui") == Localization.get("en", key)` (`"%s %s says %s"`); count == 6 only when `ctx.ArtLibrary.find` has both sign paths. Return string appends `", wires %d, sign texts %d"`.
9. **Step 61** (`DayNight.lua`): `local INFRA_LIGHTS = 3 -- CM2-10IW` added to expected (59); a third loop like the dressing one over `MapPiece` `^Infra_%d%d` in `Map.Infrastructure` expects 3 (`"%d infrastructure lights, expected %d"`); return string adds `", %d infrastructure lights"`; header comment says 59.
10. **MODEL_INTEGRATION**: CM2-10W folder list gains `Infrastructure`; CM2-10I section gains one line "In the world (CM2-10IW): …" naming `Map.Infrastructure`, the 4 fallbacks (9 skipped), 36 Beam wires, sign text following the arrows (N top "Bridge", S top "Village Square"), 3 lights, totals 489 / 203580 / 1572, NightLights 59. **DECISION_LOG** "CM2-10IW infrastructure in the world": the art's top arrow points model −X (west on the N sign), so the contract's "Village Square on N" is swapped; speed text "20"; straight Beam wires; LampLight reused.

## Tests (headless)
| Test case file | Test name | Asserts |
|---|---|---|
| MapLayout_Test | places the contract counts within the map budget (change) | caps `219260, 1635, 532`; `meshParts == 1572`, `models == 489`, `triangles == 203580`; header comment updated |
| MapLayout_Test | plan falls back or skips missing art … (change) | fallback set 11→15, skip 8→17, `#missing` 19→32, `#partialMissing` 18→31 |
| MapLayout_Test | places the 77 infrastructure pieces from the contract (CM2-10IW) (new) | 36 pairs, 5 singles; 77 unique ids in `Infrastructure`; `_S` mirrors `_N`; footprints ≥ 1.0 (−1e-9) from `Sidewalk_N/S`, `ApproachRoad`, `Square` (`surfaceTops()`) and channel x −236..−200, z ±380; RS/RD signs as step 2, keys in `Localization.Strings.en`; fake root without the 13 paths: 52 `Fallback` (UP, GR, ST, UB), 25 `Skip` |
| MapLayout_Test | wires neighbouring poles on each side (CM2-10IW) (new) | 36 wires; `from`/`to` are UtilityPole pieces, same side, `to` = `from` + 1; each (from, attachment) once |
The existing keep-out test covers ≥ 3 studs. Expected headless count: 791 + 2 = **793**.

## Playtest (Studio, via playtester; now: world wiring)
Smoke run plus:
1. Edit (the queued CM2-10I step 21 reading): the 13 in `ArtAssets` carry `ArtPath`, `ArtAssetId`, `ArtVersion` and their attachments (`WireA`/`WireB`, `SignFront`, `SignTop`/`SignBottom`, `Light` x2); step 21 "61 blender models, … 0 failed, 0 duplicates"; no `[ART]` warning for the 13.
2. Play, step 56 MAP_WORLD PASS: "map pieces outside Reserve" = plan count (all art: 369), 0 parts in car lanes, truck lanes and lots, "wires 36, sign texts 6"; `Map.Infrastructure` holds 77 models, `MapFallback` on none.
3. Step 61 NIGHT_LIGHTS PASS: 59 night lights, 22 lamps, 10 dressing lamps, 3 infrastructure lights.
4. Steps 37, 40 (0 snaps), 57 PASS; `runPlaytest {mode="full"}` all PASS (customers and the supplier truck reach every plot).
5. Screenshot at plot 2 and the bridge end: pieces on snow (none floats/sinks > 0.3), wires span the poles, sign texts match the arrows.

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (793 passed), `rojo build default.project.json` and `release.project.json`, `art.luau verify release.rbxlx` 61 integrated.
- Headless criteria above; Studio steps 21, 56, 61 (59 ≤ 66), 37, 40, 57 and the full run PASS.

## Out of scope
New art, collider/LOD tuning, wire sag, enterable buildings, lot decor.

# CM2-GATE — Lot entrance gate and festive fence art

Planner `planner`, implementer `modeler`. Everything below is decided.

## Goal
New `Props/LotGate` art and a festive v3 of `FencePost`, `FenceRail8` and `FenceRail6`, built in one Blender pass so that they match. The world wiring is CM2-GATEW.

## Source of truth
Backlog CM2-GATE (owner 2026-11-26); MODEL_INTEGRATION "Asset pipeline", CM2-13b, CM2-13W; quality-reference README.

## Implementer tier
Tier: MODEL. Reason: Blender models only, no code. Quality tier **A** for all 4 models (backlog).

## Skill checks
- cm2-modeling: use the kit; `CM2_KIT_OK`; at most 3 render rounds; compare `preview_34` with checklist items 1-7.
- Flat-shaded low-poly. Bevels: wood 0.04-0.05, snow 0.08-0.12. Snow on every upward ledge. No text or logos; the sign stays blank.
- One MeshPart per colour: the MeshPart limits set how many colours each model may have.
- building: the origin is the ground pivot; `COL_*` colliders are never rotated; the opening clearance below is binding.
- lighting: emissive only through `LightWarm` (Neon). No Light objects in any model; GATEW adds them at `Light1` and `Light2`.
- No third-party assets. PC-2 is resolved: upload runs.

## Files
- Change: `assets/art/source/Environment/fence_common.py`.
- Change: `Environment/{FencePost,FenceRail8,FenceRail6}/` (keep seeds 146, 144, 145).
- New: `assets/art/source/Props/LotGate/` (seed 147); imports `fence_common` as F via `sys.path`, like the fences.
- The 4 previews in `assets/art/previews/` and the 4 `.rbxm` files.
- `docs/MODEL_INTEGRATION.md` and `docs/DECISION_LOG.md`.

## Data and config
| artPath | tier | maxTri | maxMP | requiredAttachments | Palette keys |
|---|---|---|---|---|---|
| Environment/FencePost | A | 400 | 3 | [] | WoodWarmShade, SnowWhite, LightWarm |
| Environment/FenceRail8, FenceRail6 | A | 800 | 4 | [] | WoodWarmShade, SnowWhite, NeedleGreen, LightWarm |
| Props/LotGate ("Lot Gate") | A | 3000 | 10 | SignFace, Light1, Light2 | WoodWarm, WoodWarmShade, SnowWhite, StoneGrayShade, FabricCream, GoldAccent, NeedleGreen, RoofRed, LightWarm |

Versions: the fence models keep `version` 2 (upload raises it to 3). LotGate starts at `version` 1 with `upload {}`.

Fence wood is all WoodWarmShade, because a second wood colour does not fit within 4 MeshParts. Record this as a deviation from checklist item 4.

## Steps
Coordinates are in Blender: studs, Z up, front −Y, origin at the ground pivot.
1. **`fence_common.py` v3:**
   - Constants: `POST_W = 0.9`, `POST_H = 4.9`, `RAIL_Y = 0.4`, `RAIL_Z = 0.55`, `RAIL_CENTRES = (1.8, 3.6)`.
   - `post(x, w=POST_W, h=POST_H)`: a WoodWarmShade body w × w × h (bevel 0.04), then `lantern_cap(x, w, h)`.
   - `lantern_cap(x, w, base_z)`: every part inside a w × w square.
     - Plate w × w × 0.15.
     - LightWarm `Glow` cube 0.55w × 0.55w × 0.5w, with 4 corner bars 0.1w square.
     - Pyramid roof: `K.cone`, verts 4, rot z 45, radius w/2·√2, height 0.35w.
     - Snow pyramid: 0.86 × the roof radius, height 0.3w, its foot at the roof's mid-height.
     - With w = 0.9 the top is at 5.9 ± 0.05 (v2: 4.1).
   - `rails(length)`: as in v2, with the new constants; keep the snow strip.
   - `garland(x0, x1, z, sag, y, segments, radius, bulbs, bulb_r, drop)`:
     - Curve: z(t) = z − sag·4t(1−t).
     - Segments: NeedleGreen `K.cylinder` (verts 6) between consecutive points, `rot=(0, degrees(atan2(dx, dz)), 0)`, depth = chord + 0.04.
     - Bulbs: LightWarm `K.ball(detail=0)` at t = k/(bulbs+1), centred `drop` below the curve.
2. **FencePost:** `F.post(0)`; `COL_Post (0.9, 0.9, 5.0)` at (0, 0, 2.5).
3. **FenceRail8 / FenceRail6** (L = 8 / 6):
   - `F.post(-L/2)` and `F.rails(L)`.
   - `F.garland(-L/2+0.45, L/2-0.45, 4.6, 0.7, -0.3, 8/6, 0.12, 3/2, 0.1, 0.14)`.
   - `COL_Fence (L, 0.9, 4.0)` at (0, 0, 2.0).
   - Extent: −L/2 − 0.45 … L/2 − 0.05 along the run, ±0.45 across.
4. **LotGate** (`K.run(build, tier="A")`):
   - Posts: `F.post(±8.9, w=1.4, h=15.2)`. StoneGrayShade plinths 1.5 × 1.5 × 0.8 at (±8.9, 0, 0.4). Post footprint 1.5 × 1.5.
   - Beam: WoodWarm 19.0 × 1.1 × 0.8, centre z 13.0 (bottom 12.6). Snow: `K.snow_cap((3.55, 1.2, 0.15), (±6.425, 0, 13.4))`.
   - Sign: FabricCream board 9.0 × 0.3 × 2.2 at (0, 0, 14.65), in a GoldAccent frame (4 bars 0.15 thick, 0.35 deep, outer 9.3 × 2.5) that rests on z 13.4.
   - Arch:
     - Circle through (±8.2, 14.8) and (0, 17.2): R 15.21, centre z 1.99.
     - 9 equal-angle WoodWarm segments, length chord + 0.1, 0.6 (z) × 1.0 (y), `rot=(0, -degrees(atan2(dz, dx)), 0)`, bevel 0.04.
     - On each segment: a SnowWhite slab 0.12 thick, offset 0.36 along the outward normal, and a LightWarm bulb r 0.14 at the midpoint, y −0.6.
     - The arch stays ≥ 0.2 above the frame top (15.9).
   - Garland: `F.garland` on the 4 spans between anchors x −8.2, −4.1, 0, 4.1, 8.2; z 12.9, sag 0.4, y −0.7, 6 segments, radius 0.16, 4 bulbs, bulb_r 0.12, drop 0.2.
   - Bows: RoofRed, at the 5 anchors (x, −0.8, 12.9). Each bow is 2 `K.cone` loops (verts 4, r 0.3 → 0, depth 0.4, rot (0, ±90, 0), centred at x ±0.2) plus a knot `K.ball` r 0.12, detail 0.
   - Colliders: `COL_PostL` and `COL_PostR (1.5, 1.5, 15.2)` at (±8.9, 0, 7.6); `COL_Header (19.0, 1.4, 5.0)` at (0, 0, 15.1).
   - Attachments: `SignFace` (0, −0.16, 14.65); `Light1` (−4.1, −0.9, 12.9); `Light2` (4.1, −0.9, 12.9).
   - Opening: nothing between x ±8.15 below z 12.1, giving 16.3 × 12.1 (≥ 16 × 12).
   - Expected size: ~19.3 × 1.6 × 17.6.
5. For each model:
   - Build until `CM2_KIT_OK`. Expected triangles: post ~140, rail ~500, gate ~2000.
   - `art.luau export`, then check in `report.json`: size, centring, attachments and colliders.
   - `render`, then compare against the checklist (liked and disliked images once). Up to 3 rounds; a model that still fails is reported and not committed.
6. Copy each `preview_34.png` to `assets/art/previews/<artPath>.png`. Run `art.luau build <artPath>` (upload + normalize) for all 4.
7. `rojo build release.project.json -o release.rbxlx`, then `art.luau verify release.rbxlx` → `42 integrated, 0 pending, 0 failed`.
8. Docs:
   - MODEL_INTEGRATION, new section "Lot gate and fence (CM2-GATE)":
     - sizes from `report.json`: W × D × H, triangles / max, MeshParts;
     - attachments in model space **after export**, read from the `.rbxm`;
     - opening 16.3 × 12.1; gate post footprint 1.5 × 1.5; fence post 0.9 × 0.9; fence top 5.9;
     - "for GATEW: `LotArt.PIECE_HALF` 0.45, `RAIL_BEHIND` 4.45, `RAIL_AHEAD` 3.95; `DecorFenceRadius` 5.5 still covers (4.47)".
   - MODEL_INTEGRATION, CM2-13b section: replace the fence sizes with a pointer to the new section.
   - DECISION_LOG: one entry with the sizes, the colour choice and tier A. Note that until GATEW the code constants understate the post by 0.15.

## Tests (headless)
None new.
- stylua, selene (`src tests tools`); headless → 714/714.
- `lune run tests/tools/art_pipeline.luau` → all PASS.
- `rojo build` (both); `verify` (step 7).

## Playtest (Studio; run now, MODEL)
World reads only; PC-13 does not gate.
1. Edit mode: the 4 models each have PrimaryPart `ArtRoot`, `ArtSource "blender"`, `ArtTier "A"`, their attachments, and MeshParts within the limits. Fence `ArtVersion` is 3. No Studio-only duplicate.
2. Play, `runPlaytest {mode="full"}` → 71/71 PASS, including:
   - 21 ART_ASSETS: 42 blender models, 0 failed, 0 duplicates;
   - 42 REVIEW_SIGN: decor fences clear of the sign;
   - 59 HQ_FOOTPRINTS;
   - 66 LOT_ART: 11 + 2 × level pieces.
3. No `[ART]` warning for the 4 paths.

## Acceptance
- Checks: the tests above.
- Budgets as tabled. Attachments and colliders as specified. Opening ≥ 16 × 12; each gate post footprint ≤ 1.5 × 1.5; fence top ≥ 5.6; fence post 0.9.
- Checklist items 1-7 PASS at tier A.
- Looks: a festive wooden arch; a snowy rail fence with lanterns and a garland.
- Commit: sources, `.rbxm` files, previews and docs. No game code changes. The Studio steps above PASS.

## Out of scope
- Gate placement, sign text, PointLights and the `LotArt` constants: these are CM2-GATEW.
- New palette keys, coloured bulbs, LOD.

## Amendment 1 (2026-11-27, modeler question)
- Gate attachments are `Light1` and `Light2` (was `Light_1`, `Light_2`): the name rule `^[A-Z][A-Za-z0-9]*$` (kit, exporter, `AssetSpec`) rejects underscores. All references above are updated. The export mirrors x, so in Roblox model space `Light1` sits at x +4.1 and `Light2` at x −4.1; GATEW reads positions from the `.rbxm`, never from this plan.
- Accepted: WoodWarm post bands at z 1.15 and 12.3, inside each 1.5 × 1.5 post footprint and outside the opening (secondary forms for tier A). Opening clearance stays 16.3 × 12.1.

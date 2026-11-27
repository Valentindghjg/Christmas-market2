# CM2-FLICK — Snow ground z-fighting between the plots and the road

Written by: `planner` (Opus 5.5, medium). Implemented by: `implementer-high`. Playtested by: `playtester`. Reviewed and committed by: `reviewer`. Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
The snow between the lots and the sidewalks no longer flickers in Studio: no two flat ground-level surfaces share a top height where they overlap.

## Source of truth
Backlog line 18f (owner request 2026-11-26). Cause (planner, static read): `MapLayout.surfaces()` `Ground_West`/`Ground_East` (top y 0) overlap the dev place's `Workspace.Baseplate` (Roblox template, 2048 x 16 x 2048 at y −8, top y 0; named in the archived PROGRESS walk note of 2026-11-25/26). The Rojo projects have no Workspace children, so `release.rbxlx` has no Baseplate; the flicker exists only in the Studio place. The planner had no Studio access; playtest step 1 (read (a)) confirms the cause.

## Implementer tier
Tier: M. Reason: world-build change plus a new playtest step and a pure shared helper; no save, money, inventory or remote change.

## Skill checks
- building: set anchoring, collision and visibility explicitly; map bounds checks exclude Baseplate, Terrain and the template SpawnLocation; evidence is a readback, not intent.
- building: no guessed world coordinates in the fix; the removal is by name and class, idempotent.
- luau-core/types: `--!strict`, exported types for the new helper, no globals, deterministic sort (tie-break by id).
- tooling: the helper is pure and tested headless; the Studio step only reads (no world change), prints one detail line.
- collaboration-mode: claims only with readback; Studio results only from a real run.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/MapLayout.lua` | Change | types `FlatTop`, `CoplanarPair`; constants; `surfaceTops()`, `coplanarPairs()` |
| `src/server/Services/WorldService.lua` | Change | `removeDefaultBaseplate(world)` called in `build()` |
| `tests/studio/Cases/MapLayout_Test.lua` | Change | 4 tests below |
| `tests/studio/Playtest/Steps/Map.lua` | Change | step 69 `SURFACE_GAPS`; header comment "steps 56-57 and 69" |
| `tests/studio/Playtest/RunPlaytest.lua` | Change | `RunPlaytest.BUILD = "cm2-flick"` |
| `docs/TEST_PLAN.md` | Change | line 81: `full` (70 steps, BUILD `cm2-flick`); add a sentence "Step 69 `SURFACE_GAPS` (CM2-FLICK) scans ground-level flat parts for coplanar overlaps." |

## Data and config
Constants in `MapLayout` (technical, not contract values): `MapLayout.COPLANAR_TOLERANCE = 0.02`, `MapLayout.COPLANAR_MIN_AREA = 0.1`. No `GameConfig`, keep-out, `PLOTS`, `surfaces()` or save change.

## Steps
1. `MapLayout.lua`:
   - `export type FlatTop = { id: string, minX: number, maxX: number, minZ: number, maxZ: number, top: number }`
   - `export type CoplanarPair = { a: string, b: string, area: number, gap: number }`
   - `function MapLayout.surfaceTops(): { FlatTop }`: one entry per `surfaces()` item with `kind == "Part"` (wedges skipped; all Part surfaces have yaw 0): `minX = x - sx/2`, `maxX = x + sx/2`, same for Z, `top = y + sy/2`, `id = surface.id`. Order as in `surfaces()`.
   - `function MapLayout.coplanarPairs(tops: { FlatTop }, tolerance: number, minArea: number): { CoplanarPair }`: copy and sort by `top` ascending, ties by `id`; for each i, walk j > i while `sorted[j].top - sorted[i].top <= tolerance`; `area = max(0, min(maxX) - max(minX)) * max(0, min(maxZ) - max(minZ))`; when `area > minArea` append `{ a = sorted[i].id, b = sorted[j].id, area = area, gap = sorted[j].top - sorted[i].top }`. Does not mutate the input.
2. `WorldService.lua`: new local function, placed above `WorldService.build`:
   ```lua
   -- CM2-FLICK: the Studio template's Baseplate (top y 0) z-fights with MapLayout's snow ground;
   -- the Rojo/release place has none. Records what it removed on the world folder.
   local function removeDefaultBaseplate(world: Folder)
   ```
   Body: `local baseplate = workspace:FindFirstChild("Baseplate")`; if it `IsA("BasePart")`: `world:SetAttribute("RemovedBaseplate", string.format("top %.2f size %gx%gx%g", baseplate.Position.Y + baseplate.Size.Y / 2, baseplate.Size.X, baseplate.Size.Y, baseplate.Size.Z))`, then `baseplate:Destroy()`. Else nothing. Call it in `build()` right after `world.Parent = workspace` (the early-return path is untouched).
3. `Map.lua`: `addStep("69", "SURFACE_GAPS", {}, function() ... end)` after step 57, read-only:
   - Candidates: every `Part` (`IsA("Part")` and `Shape == Enum.PartType.Block`, so no MeshPart, WedgePart, Union or Terrain) among `ChristmasMarketWorld:GetDescendants()` and the direct children of `workspace`, with `Transparency < 1`, not under a `Model` that has a `Humanoid` (walk ancestors up to `workspace`), and top in the ground band `-4 <= top <= 2`.
   - Axis check: `math.abs(cf.UpVector.Y) > 0.999` and (`math.abs(cf.RightVector.X) > 0.999` or `math.abs(cf.RightVector.Z) > 0.999`); otherwise count it as `skipped` and leave it out. Footprint: X/Z half sizes swapped when `|RightVector.Z| > 0.999`; `top = Position.Y + Size.Y / 2`; `id = part:GetFullName()`.
   - `local found = MapLayout.coplanarPairs(tops, MapLayout.COPLANAR_TOLERANCE, MapLayout.COPLANAR_MIN_AREA)`; `check(#found == 0, ...)` with the first 5 as `"<a> | <b> area %.2f gap %.3f"` joined by `"; "`.
   - `check(workspace:FindFirstChild("Baseplate") == nil, "Workspace.Baseplate still present")`.
   - Strip list (read (a) evidence after the fix): for each `MapLayout.PLOTS` plot, strip `x plot.x-40..plot.x+40`, `z -48..-20` (plot.z < 0) or `20..48`; collect unique candidate names (`part.Name .. "@" .. string.format("%.2f", top)`) whose footprint overlaps a strip by > 0.1 stud², sorted.
   - Return `string.format("candidates %d, skipped %d, pairs 0, strip: %s, removed baseplate: %s", n, skipped, table.concat(stripNames, ", "), world:GetAttribute("RemovedBaseplate") or "none")`.

## Tests (headless)
All in `tests/studio/Cases/MapLayout_Test.lua`; count goes up by 4.

| Test name | Asserts |
|---|---|
| "coplanarPairs reports only overlaps within the tolerance" | A (0..10, 0..10, top 0) + B (5..15, 5..15, top 0.01) → 1 pair, a "A", b "B", area 25, gap 0.01; C (top 0.03, same box as A) with A only → 0; D (10..20, 0..10, top 0) edge-touching A → 0; E (9.9..10.9, 9.9..10.9, top 0) with A only → 0 (area 0.01); input order unchanged |
| "surfaceTops lists every Part surface" | 13 entries; `Ground_East` top 0, `MainRoad` absent, `Sidewalk_N` top 0.45, `TruckLane_Plot_01` top 0.05; no `Bank_West` |
| "map surfaces and world grounds have no coplanar pair" | `surfaceTops()` plus `MainRoad` (x −190..190, z −16..16, top 0.35) and six `LotGround` (center x = column·110, z = ±75 as `PLOTS`, 80 x 54, top 0.55; comment: values from `WorldService.build`) → `#pairs == 0` |
| "the template Baseplate would z-fight with the snow ground" | the same list plus `{ id = "Baseplate", −1024..1024, −1024..1024, top 0 }` → pairs contain `Ground_West`/`Baseplate` and `Ground_East`/`Baseplate` (either order) |

## Playtest (Studio, via playtester)
Studio now (world geometry). Before Play, Rojo synced.
1. Read (a), Edit mode, before Play: list every direct `workspace` child that is a visible BasePart (not Terrain, not a character) with name, top Y (`Position.Y + Size.Y/2`) and size. Expected: `Baseplate` with top 0.00 (any size covering the strips). If no part with top within 0.02 of 0 overlaps a strip (plots 1–3: x −150..150, z −48..−20; plots 4–6: z 20..48), stop: report "no coplanar pair, ESCALATE TIER L" with the list.
2. Play (server): `runPlaytest { mode = "smoke", only = { "69", "37", "56", "59", "66" } }` → all PASS; step 37 detail shows 0 snaps; step 69 detail shows "pairs 0" and `removed baseplate: top 0.00 size …`; no strip name ends in `@0.00` except `Ground_East` and `Ground_West`. Record the step 69 detail and the step-1 list in PROGRESS (this is read (a)).
3. `runPlaytest { mode = "full" }` → `steps=70`, all PASS.
4. Visual note only (gates nothing): orbit the camera low over the strip in front of plots 2 and 5; flicker gone, ice channel at x −230..−206 now visible below the banks.

## Acceptance
- Checks: `stylua --check src tests tools`, `selene src tests tools`, `lune run tests/headless/run.luau` (previous count + 4, all PASS), `rojo build default.project.json` and `rojo build release.project.json`.
- (a) recorded from playtest step 1 and step 69's strip list. (b) step 69 PASS with 0 pairs; no walkable game surface moves (only the template Baseplate, absent from the release place, is removed); no keep-out, `PLOTS` or `surfaces()` value changes. (c) the 4 headless tests. (d) step 69 `SURFACE_GAPS` plus 37 (0 snaps), 56, 59, 66 and the full run PASS.

## Out of scope
- MeshParts, unions, wedges and parts above y 2 (art and lot props): not scanned; a coplanar pair found there becomes a follow-up task, not a fix here.
- Any change to `MapLayout` contract values, lot or road heights, Terrain, lighting.
- If step 69 finds a pair other than the Baseplate one, the implementer/playtester stops and reports; the planner amends.

## Amendment 1 (2026-11-27, after playtest 1)
Playtest 1: read (a) PASS (Baseplate top 0.00, 512x20x512), removal PASS; step 69 FAIL with 2 pairs, first `Plot_01.Spawn | Plot_01.ProgressionVisuals.Parking_1 area 4.00 gap 0.020`, second clipped by `MAX_DETAIL` 200 in `Support/Base.lua`.

Cause (planner, code read; a real pair, not a float artifact): `Spawn` (4 x 0.2 x 4 at `lotPosition(plot, -28, 14, 0.7)`, top 0.80, lot x −30..−26, z 12..16) and `Parking_1` (8 x 0.08 x 12, y = 0.30 + 0.48, top 0.82, lot x −28..−20, z 14..26) overlap 2 x 2 = 4 stud² with 0.02 between tops; the KeepClear boxes `Spawn` and `Parking` overlap by design. The gap equals the tolerance only by float rounding; 0.02 studs z-fights at normal camera distance, so the pair is in scope. The tolerance stays 0.02. The second pair is most likely the same pair on another plot with parking; the new detail lines confirm it.

### Fix steps
A1. `WorldService.lua`, plot build, the `"Spawn"` part: position `lotPosition(plot, -28, 14, 0.7)` → `lotPosition(plot, -28, 14, 0.8)` (top 0.90, 0.08 above `Parking_*` 0.82, 0.35 above `LotGround`). Add the comment `-- CM2-FLICK: top 0.90 clears Parking_1 (top 0.82), which it overlaps.` Size, colour, transparency, name and footprint unchanged; `KeepClear` unchanged.
A2. `Map.lua` step 69, failure output (replaces the "first 5" rule of step 3):
   - local `short(id)`: strip the prefix `"Workspace.ChristmasMarketWorld."` when present (`string.find(id, prefix, 1, true) == 1`), else return `id`.
   - When `#found > 0`: for each pair, `ctx.emit(string.format("69 PAIR %d/%d %s | %s area %.2f gap %.3f", i, #found, short(a), short(b), area, gap))` (add `local emit = ctx.emit` at the top of the file next to `check`), then `check(false, string.format("%d coplanar pairs, see 69 PAIR lines; first: %s | %s", #found, short(found[1].a), short(found[1].b)))`.
   - The Baseplate check and the PASS detail are unchanged.
A3. No new headless test (the Spawn height lives in `WorldService`, not a pure module); headless count stays previous + 4.

### Playtest (replaces steps 2-3; step 1 done; old step 4, the visual note, becomes step 5)
2. Play (server): `runPlaytest { mode = "smoke", only = { "69" } }` → PASS, "pairs 0", `removed baseplate: top 0.00 size 512x20x512`. If it fails, record every `69 PAIR` line; if any pair is not `Plot_NN.Spawn | Plot_NN.ProgressionVisuals.Parking_N`, stop and report (the planner amends).
3. `runPlaytest { mode = "smoke" }` → all PASS (37 shows 0 snaps; Checkout teleport to `Spawn` still works).
4. `runPlaytest { mode = "full" }` → `steps=70`, all PASS. Record the step 69 detail and the step-1 list in PROGRESS.

Acceptance (b) adds: the only game-surface change is `Spawn` raised by 0.1 stud.

# 3D model handoff contract

**Ownership:** The project owner creates all final 3D assets. The implementation team owns Luau code, UI, gameplay, integration, testing, configuration and persistence.

No final models will be generated or substituted without request. Development can use invisible anchor parts and temporary non-art graybox primitives only where needed to test collisions and interaction; these are not deliverable art.

## Roblox Studio hierarchy
Put models into `ReplicatedStorage/ArtAssets` during development, or server-only originals in `ServerStorage/ArtAssets` where appropriate:
- `Trees/<Species>/<Size>` (Small, Medium, Large)
- `Buildings/<TierId>`
- `Props/<AssetId>`
- `Vehicles/<AssetId>`
- `NPCs/<CharacterId>`
- `Environment/<AssetId>`

## Model conventions
- All models have a valid PrimaryPart or pivot and stable orientation (forward = -Z).
- Trees have `TreeBase` attachment or stable ground pivot.
- Buildings have `Entrance`, `Checkout_1`, `DeliveryPoint` attachments where relevant.
- Vehicles have `DriverSeat` or `DriveRoot` and `CargoAnchor` as relevant.
- NPCs use a Roblox-compatible Humanoid and HumanoidRootPart when AI animation/navigation is needed.
- Names are case-sensitive; use exact IDs from shared config, not visible display names.
- Anchoring/collision is controlled by placement service; avoid scripts inside imported models.
- Include bounding-box dimensions and note any required animation IDs.
- Upload models in small batches; integration team validates scale, pivot, attachments and collisions.

## Initial requested models
DouglasFir, FrasierFir (display name "Fraser Fir"), NobleFir, BlueSpruce (each Small/Medium/Large); StarterSalesTent, ChristmasPavilion; SupplierTruck; CheckoutCounter; DeliveryBay; BasicFence; FestiveLights; CustomerRig; CashierRig; LotWorkerRig.

CustomerRig note (CM2-N1, 2026-11-22): walking customers do not use `ArtAssets/NPCs/CustomerRig`. `NpcAvatar` builds one template from the default Roblox R15 body (`HumanoidDescription` without catalog asset IDs, created once on the server) and clones it per customer; body colours come from `GameConfig.Customers.Npc.Look`, and the beanie, pompom and scarf are our own welded Parts. Animations are Roblox's first-party default R15 walk and idle. A Blender customer mesh stays out of scope until a later task; staff (CM2-25/26) reuse `NpcAvatar.build(look)`. Sales stands: `WorldService.salesStand` levels the art's yaw to the nearest half turn of its largest part (CM2-N1 fix round 2), so a Studio-only template's rotation cannot tilt the stall.

## Integration behavior
Missing model: fail gracefully and log `MissingArtAsset`; never grant extra inventory or charge a player for a placement that failed. Config IDs must not be derived from art model filenames.

# 3D asset ownership update — 2026-11-19

**Supersedes prior owner-supplied asset responsibility.** Claude Code is now responsible for creating the game's original 3D models and snowy world, as well as their integration and tests. The owner may optionally contribute models, but is not required to.

Recommended approach: Roblox Studio procedural construction and original low-poly meshes built from native Parts/MeshParts. Begin with gameplay-functional graybox models, then improve silhouettes, materials, colors, collisions, LOD and performance. Avoid copyrighted extraction and unlicensed Toolbox assets.

Asset contract remains: `ArtAssets/Trees/<Species>/<Size>`, `Buildings/<TierId>`, `Props/<AssetId>`, `Vehicles/<AssetId>`, `NPCs/<CharacterId>`, `Environment/<AssetId>`. Stable pivots/PrimaryPart; TreeBase, Entrance, Checkout_1, DeliveryPoint and CargoAnchor attachments as applicable. Model scripts must not bypass server gameplay logic.

Definition of done per model: original geometry, named/pivoted correctly, appropriate collision and scale, performant on mobile, screenshot-reviewed, Studio-tested, and documented in asset inventory.

# Asset pipeline (CM2-AP, 2026-11-22)
Larger models are Blender MeshParts; small items stay Parts. The `.blend` in `assets/art/source/<artPath>/` is the source; `tools/art/art.luau` exports it to FBX, uploads it through Open Cloud (or the Studio import fallback) and normalizes the result into `assets/art/rbxm/<artPath>.rbxm`, which Rojo maps into `ReplicatedStorage.ArtAssets`. Full rules and commands: `assets/art/README.md`.
- Pivot: Blender origin = ground pivot, front = Blender -Y, 1 unit = 1 stud; the normalized model's `PrimaryPart` is `ArtRoot` at `CFrame.identity` (size 0.05, transparent). `WorldPivot` is not used.
- Colour and material come from `src/shared/ArtPalette.lua` through the object name `<PartName>__<PaletteKey>`; no textures. `COL_<Name>` boxes become `Collider_<Name>`; `ATT_<Name>` empties become Attachments under `ArtRoot` (`Trees/*` always has `TreeBase`).
- Attributes on every normalized model: `ArtAssetId`, `ArtPath`, `ArtSource = "blender"`, `ArtVersion`, `ArtTier`. Budgets: tier A 4000 triangles / 10 MeshParts, tier B 1000 / 4.
- `ArtLibrary.find/prepareClone` (`src/shared/ArtLibrary.lua`) look art up and clone it; a missing or broken path logs `[ART] <MissingArtAsset|InvalidArtAsset|InvalidArtPath> <path>` once per path and the primitive fallback stays.
- `ArtLibrary.root` returns the first `ReplicatedStorage.ArtAssets` that holds a Model or MeshPart at any depth (`hasAssets`); a leftover folder of empty subfolders is ignored (CM2-ART2).
- Paths handed to Blender: `art.luau` resolves `--root`, the probe root and the Blender scripts against the working directory, so every path Blender gets is absolute; `Blender.run` refuses a relative one with `ART_RELATIVE_PATH` before starting Blender, and the three Blender scripts apply `os.path.abspath` (CM2-ART1).
- Checks: `tests/tools/art_pipeline.luau`, `art.luau verify <place>` (CI), playtest step `ART_ASSETS`.

## Tree art (CM2-12)
- Paths: `Trees/{DouglasFir,FrasierFir,NobleFir,BlueSpruce}/{Small,Medium,Large}` plus `Trees/FrostcrownFir/Large` and `Trees/HollyberrySpruce/Large`; sources `assets/art/source/Trees/<Species>/<Size>/` built by the shared `assets/art/source/Trees/tree_common.py`, previews `assets/art/previews/Trees/<Species>/<Size>.png`. Expected playtest warning (ASSETWARN rule, not a missing asset): the Trees playtest step (e) asks for `Trees/FrostcrownFir/Small` on purpose to check the primitive fallback, so `[ART] MissingArtAsset Trees/FrostcrownFir/Small` appears once during that step and not in a smoke run. No game path requests it.
- Heights (total incl. leader/topper) and max radius: Small 6.0 / 1.9, Medium 8.0 / 2.5, Large 10.0 / 3.1, special trees 10.4 / 3.3 studs (below `Placement.FootprintRadius`); origin = trunk foot, `ATT_TreeBase` at (0, 0, 0), collider `COL_Tree` 1.1R x 1.1R x H.
Archived detail (budgets, measured sizes, clearances): `docs/archive/MODEL_INTEGRATION_2026-11-28.md`, same heading.
- Wired by CM2-12W (see below).

## Tree art in the world (CM2-12W)
- `src/shared/TreeArt.lua` holds the five roles (Display, Pickup, Carried, NpcCarried, Roof), the paths `Trees/<Species>/<Size>` (nil species -> `DouglasFir`, bad size -> `Medium`) and the primitive scales; `WorldService.buildTree` clones the art, else builds the primitive tree and logs `[ART]` once. Models carry `TreeArtMode` (`Art`/`Primitive`), `TreeArtPath` and, for art, `TreeArtScale`.
- Display and Pickup keep the art's native size (H 6/8/10) with the foot at the lot top 0.55; Carried, NpcCarried and Roof scale the art to the primitive's height (`11.5 x primitive scale`) and drop it by `2.5 x scale` so the foot sits where the primitive's did.
- Labels sit `UiTheme.WorldLabels[...].height` studs above the tree top (DisplayTree 1.0, PickupOrder 1.5, plus the pickup stagger), for art and primitive alike.
- The roof tree lies along the car's +Z, resting on the car's `CargoAnchor` (CM2-14W, done; the primitive car keeps `RoofRack` as its anchor); order cars carry `TreeSpeciesId` and `TreeSizeId`.
- The forest already uses `Environment/ForestFir` (CM2-10W) and stays unchanged.

## HQ art (CM2-13a)
- Paths: `Buildings/{SalesTent,TimberPavilion,AlpineHut,MountainChalet}` (tier A, maxMeshParts 10); sources `assets/art/source/Buildings/<Tier>/` built with the shared `assets/art/source/Buildings/hq_common.py`, previews `assets/art/previews/Buildings/<Tier>.png`.
Archived detail (budgets, measured sizes, clearances): `docs/archive/MODEL_INTEGRATION_2026-11-28.md`, same heading.
- Attachments: `Entrance` at ground on the front floor edge of the counter opening or door, `Computer` on the desk top (under the monitor; desk centre on Hut and Chalet), `Radio` at the radio. Colliders: unrotated `COL_` boxes, one body box on Hut and Chalet.
- Front = -Z after export, so wiring (CM2-13W) turns the model 180 degrees on plots 1-3 and 0 degrees on plots 4-6 to face the road. Wired by CM2-13W.
Archived detail (colliders, attachments, measured values, imports): `docs/archive/MODEL_INTEGRATION_2026-11-28.md`, same heading.

## Lot props art (CM2-13b)
- Paths: `Props/{CheckoutCounter,ReceivingBay}` (tier A), `Props/TreeBundle` (tier B), `Environment/{FenceRail8,FenceRail6,FencePost}` (tier A since CM2-GATE); sources `assets/art/source/<artPath>/`, fence parts from `assets/art/source/Environment/fence_common.py`, previews `assets/art/previews/<artPath>.png`.
Archived detail (budgets, measured sizes, clearances): `docs/archive/MODEL_INTEGRATION_2026-11-28.md`, same heading.
- Fence layout: superseded by CM2-13W (below); FenceRail6 is not placed.
Archived detail (colliders, attachments, measured values, imports): `docs/archive/MODEL_INTEGRATION_2026-11-28.md`, same heading.

## Lot gate and fence (CM2-GATE)
- Paths: `Props/LotGate` and fence v3 `Environment/{FencePost,FenceRail8,FenceRail6}`, all tier A; sources `assets/art/source/<artPath>/`, shared parts (lantern post, rails, garland) in `assets/art/source/Environment/fence_common.py`, which LotGate also imports; previews `assets/art/previews/<artPath>.png`.
Archived detail (budgets, measured sizes, clearances): `docs/archive/MODEL_INTEGRATION_2026-11-28.md`, same heading.
- Fence: post 0.9 x 0.9, body to 4.9, lantern cap (LightWarm glow) to a top of 5.93; rails centred at 1.8 and 3.6; a NeedleGreen garland with LightWarm bulbs at 4.6 (sag 0.7). A rail of length L runs from x -3.95 to +4.45 (L 8; L 6: -2.95 .. +3.45) after export, its post on the +x end. Colliders `COL_Fence` L x 4.0 x 0.9 at y 2.0, `COL_Post` 0.9 x 5.0 x 0.9 at y 2.5.
- Attachments (model space after export, read from the `.rbxm`): `SignFace` (0, 14.65, -0.16), `Light1` (4.1, 12.9, -0.9), `Light2` (-4.1, 12.9, -0.9). The names have no underscore: the pipeline name rule `^[A-Z][A-Za-z0-9]*$` (kit, exporter, `AssetSpec`) rejects `Light_1`. No Light objects in the models; GATEW adds the PointLights there.
- World (CM2-GATEW): `LotArtWorld`-style placement in `LotGateWorld`: pivot at lot (x 0, z 28 = `LotHalfDepth` 27 + `LotArt.GATE_OFFSET` 1.0) in the gap of the front fence (CM2-LOTLAY: `Placement.Gate` X 0, PostX 8.9), y = lot top - `FENCE_BASE_DROP` (map ground 0), front to the road (`LotArt.roadYaw`: 180 deg plots 1-3, 0 deg plots 4-6); Part fallback without art. Posts (1.5 x 1.5 at +-8.9) stand at x -9.65..-8.15 and 8.15..9.65, z 27.25..28.75, off the placeable lot; the front fence runs end at the post faces x ±9.65 (`Placement.Gate.PostHalf` 0.75). Lights: `Light1`/`Light2` get one `MapWorld.nightLight` each (`DayCycle.GateLight` range 12, brightness 1.2, tag `NightLight`, off on the server). The `SignFace` attachment carries a transparent `SignBoard` (9.0 x 2.2) with a SurfaceGui whose name label mirrors the lot sign (`LabelKind` "LotSignName", same `NameSource`). Constants `LotArt.PIECE_HALF` 0.45, `RAIL_BEHIND` 4.45, `RAIL_AHEAD` 3.95; `DecorFenceRadius` 5.5 still covers (4.47).
Archived detail (colliders, attachments, measured values, imports): `docs/archive/MODEL_INTEGRATION_2026-11-28.md`, same heading.

## Vehicle art (CM2-14)
- Paths: `Vehicles/{SupplierTruck,CustomerHatchback,CustomerWagon,CustomerSuv}` (tier A); sources `assets/art/source/Vehicles/<Name>/`, cars from the shared `assets/art/source/Vehicles/vehicle_common.py`, previews `assets/art/previews/Vehicles/<Name>.png`.
Archived detail (budgets, measured sizes, clearances): `docs/archive/MODEL_INTEGRATION_2026-11-28.md`, same heading.
- Colour variants: each car has one MeshPart `Paint` (palette `CarPaint`); CM2-14W (done) sets its `Color` from `CAR_COLORS` (3 bodies x 6 colours via `carStyle`). Tail lights sit on a dark surround so they read on a red car.
Archived detail (colliders, attachments, measured values, imports): `docs/archive/MODEL_INTEGRATION_2026-11-28.md`, same heading.

## Vehicle art in the world (CM2-14W)
- `src/shared/VehicleArt.lua` (data and maths) and `src/server/Services/VehicleWorld.lua` (`truck`, `car`, `cargoTop`, `loadCargo`, `unloadCargo`); `WorldService` wires them. Models carry `VehicleKind` (`Truck`/`Car`), `VehicleArtMode` (`Art`/`Primitive`) and `VehicleArtPath`; primitives stay the fallback and log `[ART]` once.
- Poses (pivot = footprint centre on the wheel plane): truck `DeliveryTruck` at lot (46, `bayDepth(i)`), start at depth 66, y road top 0.35 at the start and lane top 0.05 at the stop, cab (-Z) toward the road (`LotArt.roadYaw`: 180 deg plots 1-3, 0 deg plots 4-6). Parked car at the parking centre, y lot top 0.55 + 0.27 = 0.82, nose into the lot (0 deg plots 1-3, 180 deg plots 4-6); it drives in from the road at y 0.35. Durations and XZ paths unchanged.
- Primitives: truck `TruckBody` 5 x 3 x 12 (front -Z, pivot on the ground) with `Cab` and four wheels; car as before but with `Body.PivotOffset` (0, -1.6, 0), so the pivot is on the ground (the old car sat 1.6 too high in its pose).
- `carStyle(n)`: `m = max(1, floor(n))`, colour `(m-1) % 6 + 1`, body `((m-1) + (m-1) // 6) % 3 + 1` = 18 looks (the backlog's "n mod 3" would give 6). Car art parts do not collide (`CanCollide`, `CanTouch` false); `Paint` takes `CAR_COLORS[colour]`.
- Label: art cars lift `CarNumber` by 1.6 so it sits where the primitive's did; label, `LoadOrder` prompt and reach check stay on `PrimaryPart` (`ArtRoot`).
- Cargo: the truck brings `cargoCount(arriving)` (0..9) `Props/TreeBundle` in a Model `Cargo` at `CargoAnchor` (bundles lie along X: six in a row, three on top, rise 1.0, spacing 1.2 along the bed), removed when it leaves. The roof tree rests on `cargoTop(car)` (`CargoAnchor`, else the primitive's `RoofRack` top, else the pivot plus a fallback), settled so the lowest part is 0.05 above it and welded (`RoofWeld`) to `PrimaryPart` (CM2-14WR); `WorldService.carCargoTop` exports it.

## Lot sign (CM2-G15)
- Lot sign (CM2-G15): Parts at lot (23, 23), KeepClear `Sign`; art may replace the parts but keeps `LotSign.Board` with `SignFront`, `SignBack`, `LikePrompt`.
- Decor fences at `Placement.DecorFences`; art replacing `FenceWooden` must fit within `DecorFenceRadius` of its centre.

## Map layout (CM2-10)
- Contract for CM2-10b, CM2-10c and CM2-10W (plan `docs/archive/plans/CM2-10a.md`). World frame, y up, road along X: road x -190..190, z -16..16, top 0.35; plot centres cx -110, 0, 110 at cz -75 (plots 1-3) or +75 (4-6); lot 80 x 54, top 0.55, world z = cz + facing x depth; lot depth -27..-75 reserved for 6 expansion levels x 8 (`BackDepthPerLevel` 8 since CM2-G9a).
- Keep-out boxes K per plot (z for plots 1-3, mirrored for 4-6); every map piece's footprint stays >= 3 away: Road x -190..190, z -16..16 (bridge, approach road and square join its ends); Lot x cx-40..cx+49, z -150..-48 (lot, fence, truck lane, bays, signs, decor fences, spawn, reserve); Cars x cx-26..cx+26, z -48..-16 (from `Placement.CarPark.Apron`, CM2-LOTLAY; CM2-PARK Amendment 1); Truck x cx+43..cx+49, z -48..-16.
- Parts (CM2-10W, no Roblox Terrain): ground x -560..560, z -380..380, top 0, split at the stream; stream channel x -236..-200 (bank wedges 6 wide), ice x -230..-206 top -3, full length; approach road x -560..-246, z -16..16, top 0.35; square x 190..280, z -45..45, top 0.35; sidewalks z 16..20 (both sides), top 0.45; gravel truck lanes; boundary walls.
- Landmarks (origin, yaw = `CFrame.Angles(0, yaw, 0)`, model front -Z; 0 faces -Z, 180 +Z, 90 -X, -90 +X): `Buildings/CoveredBridge` (-218, 0, 0) yaw 90, spans x -246..-190 (abutments on the banks, deck over the channel); `Environment/VillageTree` (235, 0, 0), r 15.
- Square: LeaderboardBoard yaw 0 at (217, 36.5) Cash earned and (253, 36.5) Reputation, yaw 180 at (217, -36.5) Hours played and (253, -36.5) Robux spent; VillageHouse yaw 0 at (212, 62), (258, 62), yaw 180 at (212, -62), (258, -62); Bench yaw 90 at (262, +-12), yaw -90 at (208, +-20).
- LampPost (22): square (194/235/276, +-41) and (276, +-14); beside the sidewalks x -165, -80, -38, 30, 70, 140, 182 at z +-22 (on the ground, 1.5 behind the sidewalk edge z +-20). SignBoard (7): welcome (-170, 30) yaw 0; DELIVERIES at lot (57, 52) per plot, yaw 180 on plots 1-3, 0 on plots 4-6.
- Forest zones: N/S x -410..410 without x -240..-196, z +-(156..260); NE/SE x 165..410, z +-(78..156); E x 286..410, z -80..80; W x -410..-242, z +-(22..260); stream-plot x -194..-156, z +-(52..260); plot gaps x -58..-43 and 52..67, z +-(51..153), ForestFir only.
- Reserve firs: 20 per plot at lot depth -36, -46, -56, -66 x lot x -30, -15, 0, 15, 30 (jitter +-1.5); CM2-10W hides the rows the current expansion level uses.
- Mountains (13): yaw 0 Ridge (-300, 350), Peak (-60, 350), Ridge (190, 350), Peak (430, 340); yaw 180 Peak (-300, -350), Ridge (-60, -350), Peak (190, -350), Ridge (430, -340); yaw -90 Ridge (-500, +-175), Peak (-760, 0); yaw 90 Peak (560, -150), Ridge (560, 150).
Archived detail (budgets, measured sizes, clearances): `docs/archive/MODEL_INTEGRATION_2026-11-28.md`, same heading.

## Map art (CM2-10a)
- Paths: `Buildings/CoveredBridge`, `Environment/VillageTree` (tier A, 4000 / 10); sources `assets/art/source/<artPath>/`, previews `assets/art/previews/<artPath>.png`.
Archived detail (colliders, attachments, measured values, imports): `docs/archive/MODEL_INTEGRATION_2026-11-28.md`, same heading.
- The game is unchanged; CM2-10W places both (fallback Parts until the PC-2 upload makes the `.rbxm`).

## Map art (CM2-10b)
- Paths: `Props/LeaderboardBoard`, `Buildings/VillageHouse` (tier A), `Props/SignBoard`, `Props/LampPost`, `Props/Bench` (tier B); sources `assets/art/source/<artPath>/`, previews `assets/art/previews/<artPath>.png`. Origin = footprint centre on the ground, front = -Z after export, centred (|min + max| <= 0.03).
- W x L x H, triangles / maxTriangles, MeshParts: LeaderboardBoard 14.0 x 2.97 x 17.85, 1332 / 1500, 8; VillageHouse 23.15 x 19.2 x 22.3, 2588 / 3000, 10; SignBoard 8.6 x 1.0 x 6.9, 156 / 220, 3; LampPost 1.13 x 1.13 x 8.96, 148 / 160, 3; Bench 4.96 x 1.82 x 2.9, 212 / 240, 3.
Archived detail (colliders, attachments, measured values, imports): `docs/archive/MODEL_INTEGRATION_2026-11-28.md`, same heading.
- VillageHouse walls are the single MeshPart `Paint` (FabricCream); CM2-10W recolours it per house. The game is unchanged; CM2-10W places the pieces (positions in "Map layout (CM2-10)").

## Map art (CM2-10c)
- Paths (all tier B): `Environment/ForestFir`, `Environment/ForestClusterA`, `Environment/ForestClusterB`, `Environment/RockCluster`, `Environment/MountainPeak`, `Environment/MountainRidge`; sources `assets/art/source/<artPath>/` (shared shapes `assets/art/source/Environment/map_common.py`), previews `assets/art/previews/<artPath>.png`. Origin = footprint centre on the ground.
- W x L x H, triangles / maxTriangles, MeshParts: ForestFir 8.75 x 8.67 x 16.0, 164 / 240, 3; ForestClusterA 21.81 x 20.56 x 28.0, 780 / 1000, 4; ForestClusterB 14.26 x 13.22 x 20.0, 620 / 700, 4; RockCluster 7.4 x 4.5 x 2.7 (bbox y -0.3..2.7), 240 / 300, 3; MountainPeak 220 x 180 x 150, 692 / 1000, 4; MountainRidge 300 x 150 x 100, 548 / 1000, 4.
Archived detail (colliders, attachments, measured values, imports): `docs/archive/MODEL_INTEGRATION_2026-11-28.md`, same heading.
- The game is unchanged; CM2-10W places them (zones and counts in "Map layout (CM2-10)").

## Map in the world (CM2-10W)
- Modules: `src/shared/MapLayout.lua` (pure data and maths: pieces, seed 1010, zones, surfaces, walls, hide levels, `plan`), `src/server/Services/MapWorld.lua` (builds `ChristmasMarketWorld.Map`, `applyReserve`), wired by `WorldService.build`; `ArtLibrary.root(ReplicatedStorage)` picks the non-empty `ArtAssets` folder.
- `Map` folders: `Surfaces`, `Walls`, `Landmarks`, `Square`, `Street`, `Forest`, `Rocks`, `Mountains`, `Dressing`, `Infrastructure`, `Reserve` (`Plot_01..06` with `Row_1..4`). Each placed model carries `MapPiece = id`.
- Missing art: Part fallbacks for CoveredBridge, VillageTree, LeaderboardBoard, SignBoard, LampPost (`Lamp`, CM2-G12a), ForestFir, ForestClusterA, ForestClusterB (attribute `MapFallback`); VillageHouse, Bench, RockCluster, MountainPeak, MountainRidge are skipped. One `[ART]` warning per missing path.
- Night lights (CM2-G12a): every lamp and each plot's checkout and lot sign carry a `NightLight` PointLight tagged `NightLight`, off on the server.
- Reserve firs vanish by row as the lot grows: hide levels {1, 2, 3, 4}, hidden rows at levels 0–6: 0, 1, 2, 3, 4, 4, 4; levels 5–6 grow onto open snow (`maxLevel` 6).
- HQ 1–4 use the CM2-13a art since CM2-13W; the Part primitives of the CM2-13a footprints are the fallback (`WorldService.applyHQVisual`; the model keeps the name `StarterSalesTent`, attributes `HqLevel` and `HqTier`). The lot fence `ProgressionVisuals.LotFence` (Parts, `Progression.fenceBoxes`) moves back with every lot level.
- Fallback only: HQ 1 tent art is scaled to fit KeepClear Stand minus `StandFitMargin` 0.1 (≈ 0.977; uniform `Model:ScaleTo`, attribute `FitScale` on `StarterSalesTent`; the primitive fallback tent is unchanged; CM2-G9a Amendment 1).
- For CM2-G12: `Map.Square.Board_<Key>` (`CashEarned`, `Reputation`, `HoursPlayed`, `RobuxSpent`) has attribute `LeaderboardKey`, the Part `Screen` (11 x 10, attribute `LeaderboardScreen`) and the Part `Title` with `TitleGui`. A direct art child BasePart named Screen or Title is renamed ScreenPanel/TitlePanel at build (CM2-G12b A1).
- Budget: the pieces total 302 models, 149700 triangles and 1051 MeshParts; the contract's 298 models left out the 4 benches (see the budget line above). `workspace.StreamingEnabled` is true in both project files (the server owns the map; clients read only their own nearby plot).

## Map dressing (CM2-10D)
- Paths (all tier B, plan `docs/archive/plans/CM2-10D.md`): `Props/SnowPileA` (drift), `Props/SnowPileB` (heap), `Props/Snowman`, `Props/Sled`, `Props/WoodStack`, `Props/FirBarrel`; sources `assets/art/source/<artPath>/`, previews `assets/art/previews/<artPath>.png`, `.rbxm` in `assets/art/rbxm/Props/` (asset IDs in each `asset.json`, version 2). Origin = footprint centre on the ground, front = -Z after export; no attachments, no lights.
Archived detail (colliders, attachments, measured values, imports): `docs/archive/MODEL_INTEGRATION_2026-11-28.md`, same heading.
- **Placement contract.** Entry (art, x, z, yaw) makes a north piece (x, z, yaw) and a south piece (x, -z, (yaw+180) % 360); ids `Dress_<nn>_N/_S`, nn 01-55 in order; y 0, scale 1, yaw as in "Map layout" (270 faces +X). A SnowPileA, B SnowPileB, SM Snowman, SL Sled, WS WoodStack, FB FirBarrel, L LampPost, BE Bench, F ForestFir.
- 1. Street (01-19): L -195,22,0 · A -187,24,0 · FB -180,23.5,0 · SM -158,34,0 · BE -152,24,0 · B -145,26,0 · WS -186,40,0 · SL -182,36,90 · F -150,40,0 · B -34,27,0 · FB -40,34,0 · B 76,27,0 · WS 73,40,0 · FB 70,30,0 · BE 176,24.5,0 · SM 170,36,0 · A 183,40,0 · FB 165,30,0 · FB 186,26,0
- 2. Approach road, bridge west end (20-33): L -252,20,0 · L -300,20,0 · L -350,20,0 · L -400,20,0 · A -272,21,0 · A -325,21,0 · A -375,21,0 · B -262,25,0 · SM -258,34,0 · SL -254,31,0 · BE -280,25,0 · FB -249,22,0 · F -262,42,0 · F -290,45,0
- 3. Stream banks (34-38): A -197,60,90 · A -197,100,90 · A -197,140,90 · A -238.5,60,90 · A -238.5,120,90
- 4. Square (39-47): WS 226,62,270 · SM 237,58,0 · SL 243,57,90 · B 195,49,0 · A 274,49,0 · FB 283,20,0 · FB 283,40,0 · F 235,70,0 · B 280,62,0
- 5. Plot gaps (48-49): A -50.5,42,0 · A 59.5,42,0
- 6. More (50-55): A -170,42,0 · B -310,25,0 · F -365,30,0 · BE -385,22,0 · A -197,200,90 · A -238.5,180,90
Archived detail (budgets, measured sizes, clearances): `docs/archive/MODEL_INTEGRATION_2026-11-28.md`, same heading.
- Reserved for CM2-10I: gaps x -58..-43 / 52..67 at z ±(21..38), x 162..190 at z ±(46..76), stream-plot zones.
- In the world (CM2-10DW): `MapLayout.DRESSING` holds the contract, pieces in `Map.Dressing`; Part fallbacks SnowPileA/B (`Pile`) and FirBarrel (`Barrel` + `Needles`); Snowman, Sled, WoodStack skipped without art. Map totals 412 models, 179260 triangles, 1335 MeshParts; NightLights 56.

## Village infrastructure (CM2-10I)
- Paths (plan `docs/archive/plans/CM2-10I.md`; tier B, VillageShop and FireStation tier A): `Props/SnowStake`, `Props/FireHydrant`, `Props/TrashBin`, `Props/UtilityBox`, `Props/MailboxCluster`, `Props/GuardRail`, `Props/UtilityPole`, `Props/RoadSignSpeed`, `Props/RoadSignDirection`, `Props/BusStop`, `Buildings/GarageShed`, `Buildings/VillageShop`, `Buildings/FireStation`; sources `assets/art/source/<artPath>/`, previews `assets/art/previews/<artPath>.png`, `.rbxm` in `assets/art/rbxm/` (asset IDs in each `asset.json`). Origin = footprint centre on the ground, front -Y in Blender (-Z after export); lights are attachments only (CM2-10IW adds them).
- **Placement contract.** Pair (code, x, z, yaw) makes `Infra_<nn>_N` (x, z, yaw) and `Infra_<nn>_S` (x, -z, (yaw+180) % 360); singles `Infra_<nn>`; y 0, scale 1, yaw as "Map layout". Codes: ST 1, HY 2, TB 3, UB 4, MB 5, GR 6, UP 7, RS 8, RD 9, BS 10, GS 11, VS 12, FS 13.
- 1. Poles (01-10): UP -395,22.5,0 · UP -342,22.5,0 · UP -292,22.5,0 · UP -177,27,0 · UP -75,27,0 · UP -53,27,0 · UP 35,27,0 · UP 53.5,27,0 · UP 145,27,0 · UP 168,27,0 (CM2-PARK Amendment 1: 05, 07, 09 moved from x -82, 24, 134 out of the right drive to lot x 35; order and wires kept)
- 2. Gap west (11-14): BS -43.6,22.8,0 · TB -44.5,27.5,0 · MB -48.5,28,0 · UB -56,34,0
- 3. Gap east (15-17): GS 60,33,270 · MB 65.5,24.5,0 · TB 67,36,0
- 4. Road (18-21): HY -161,23.5,0 · HY 188.3,22,0 · RS -256,21.5,90 · RD -186,31,0
- 5. Rails (22-29): GR -260,17.9,0 · GR -252,17.9,0 · GR -198,26,90 · GR -198,34,90 · GR -198,42,90 · GR -238,26,90 · GR -238,34,90 · GR -238,42,90
- 6. Stakes (30-36): ST at z 17.9, yaw 0, x -266, -285, -305, -330, -355, -380, -405
- 7. Singles (37-41): VS 176,62,0 · FS 176,-62,180 · MB 170,49.5,0 · TB 182,49.5,0 · HY 163,-49,180
- Wires (10IW): per side, poles 01->10 in order, WireA to WireA and WireB to WireB. Signs (10IW): RD top board = "Village Square" on N, "Bridge" on S, bottom the other; RS shows the limit. Lights: BusStop x2 + VillageShop = 3 (NightLights 56 -> 59 <= 66).
Archived detail (budgets, measured sizes, clearances): `docs/archive/MODEL_INTEGRATION_2026-11-28.md`, same heading.
Archived detail (colliders, attachments, measured values, imports): `docs/archive/MODEL_INTEGRATION_2026-11-28.md`, same heading.
- In the world (CM2-10IW): `MapLayout.INFRA_PAIRS` / `INFRA_SINGLES` hold the contract and the 77 pieces stand in `Map.Infrastructure` (ids `Infra_<nn>_N/_S`, singles `Infra_37..41`); Part fallbacks SnowStake (`Stake`), GuardRail (`Rail`), UtilityBox (`Box`) and UtilityPole (`Pole`, `CrossArm` with `WireA`/`WireB`), the other 9 paths are skipped without art. `MapLayout.wires()` gives 36 straight Beam wires (`WireABeam`/`WireBBeam`, parented to the `from` pole) between neighbouring poles. Sign text sits on a clear Part `SignText_<attachment>` in front of the art's attachments and follows the arrows: the top arrow of the art points model -X (west on the north sign), so the north board reads "Bridge" on top and "Village Square" below, the south board the reverse; the speed signs read "20". 3 new night lights (BusStop x2, VillageShop; `LIT_PATHS`). Map totals 489 models, 203580 triangles, 1572 MeshParts; NightLights 59.

## Lot and HQ art in the world (CM2-13W)
- Modules: `src/shared/LotArt.lua` (pure paths `Buildings/<tier.id>`, yaws, fence layout, bundle maths) and `src/server/Services/LotArtWorld.lua` (clones HQ, counter, bay, bundle and decor-fence art); `WorldService` and `LotFenceWorld` call them and keep today's primitive for every missing path (one `[ART]` warning per path).
- Road yaw: 180 degrees on plots 1-3 (facing +1), 0 degrees on plots 4-6; the art's front (-Z) then points at the road. HQ art sits on its footprint centre (-8, -4) at the lot top, shrunk uniformly only if it exceeds the footprint (`FitScale`).
- `CheckoutCounter.CounterBase` and `Receiving.Bay_<i>` keep size, position and children (prompt, label) and are invisible (`Transparency` 1) when art is present; the counter art holds `Checkout1` and `CashierStand` on the config path. The night light moves to the art's `Register` part when it has one, else `CounterBase`.
- Bundles: the `Props/TreeBundle` art in rows of three on the deck top (rise 1.0 per row, z step 1.2), at most 9; `Bundles.LotArtMode` "Art".
- Lot fence (CM2-LOTLAY): one model per `Progression.fenceBoxes` id (`Back`, `Left`, `FrontLeft`, `FrontRight`, `Right`) with `Segment_<k>` (`FenceRail8`) and `EndPost` (`FencePost`); line at x ±40.45, z 27.45 (road side) and z -(27 + 8 x level + 0.45), base on the ground (y 0), 27 + 2 x level pieces (Back 10 rails + post, Left 7 + level, FrontLeft 4, FrontRight 4 + post, Right = level). The road side is fenced except the gate gap x ±8.15 (centred), the left side runs the full depth, the right side (bays, truck lane) stays open. The sales counter stands at (-14, 16.5) in front of the HQ (queue L toward the gate, cashier at (-14, 14)).
- Decorative fences: none since CM2-LOTLAY (`Placement.DecorFences` is empty; the code path stays for later entries, a model `DecorFence` with one `Segment_1` and one `EndPost`, the CC0 `FenceWooden` as the fallback).
- Parked car: stands at the `Placement.CarPark` spot of its space (x `X[space]`, depth 40), outside the front fence; the `Parking_<i>` pad is 8 x 0.9 x 12 with its top at the car wheel plane (y 0.82) and its foot in the map ground. Car park (CM2-PARK, quality tier B, `ParkingArt` specs built by `ParkingWorld`, Parts only; Amendment 1: two bays each side of the gate, spaces 1/3 left at x -13.5/-22.5, 2/4 right at 13.5/22.5, pads 7 x 12, the corridor x -10..10 in front of the gate stays free): each bay is an asphalt pad with white `LineL`/`LineR` (0.3 inside its edges) and a `Stop` wheel stop 0.01 above it; `CarPark_DriveL` (16 x 13 asphalt at x -18, top 0.02 below the pads) and, from 2 spaces, `CarPark_DriveR` (x 18) reach the road edge; `CarPark_Sign` is a blue board with a Part-built "P" readable from the road; `CarPark_Lamp_1/2` have a Neon `Head` with the night light. Sign and lamps stand at `CarPark.Fixtures`, inside the inflated gate-fence obstacles and fence-side of the pads. Only the bought spaces are drawn.
- Attributes: `StarterSalesTent.HqArtMode` / `HqArtPath`, `LotArtMode` ("Art" or "Primitive") on `CheckoutCounter`, `Bay_<i>`, `Bundles`, `DecorFence` and `LotFence`.

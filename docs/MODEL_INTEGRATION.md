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
- Paths: `Trees/{DouglasFir,FrasierFir,NobleFir,BlueSpruce}/{Small,Medium,Large}` plus `Trees/FrostcrownFir/Large` and `Trees/HollyberrySpruce/Large`; sources `assets/art/source/Trees/<Species>/<Size>/` built by the shared `assets/art/source/Trees/tree_common.py`, previews `assets/art/previews/Trees/<Species>/<Size>.png`.
- Heights (total incl. leader/topper) and max radius: Small 6.0 / 1.9, Medium 8.0 / 2.5, Large 10.0 / 3.1, special trees 10.4 / 3.3 studs (below `Placement.FootprintRadius`); origin = trunk foot, `ATT_TreeBase` at (0, 0, 0), collider `COL_Tree` 1.1R x 1.1R x H.
- Budgets (tier A, `asset.json`): maxTriangles Small 800, Medium 1000, Large 1200, special 1600; maxMeshParts 7 (one MeshPart per colour: Trunk, RootFlare, NeedlesCore, Needles, Snow, then Frost/Topper/Berries).
- The game still uses the primitive trees; wiring through `ArtLibrary.find("Trees/<species>/<size>")` is CM2-12W (needs the PC-2 upload).
## HQ art (CM2-13a)
- Paths: `Buildings/{SalesTent,TimberPavilion,AlpineHut,MountainChalet}` (tier A, maxMeshParts 10); sources `assets/art/source/Buildings/<Tier>/` built with the shared `assets/art/source/Buildings/hq_common.py`, previews `assets/art/previews/Buildings/<Tier>.png`.
- Footprint (incl. overhangs) x H in studs, maxTriangles: SalesTent 19.8 x 13.7 x 10.0, 2500; TimberPavilion 23.6 x 17.6 x 12.9, 4000; AlpineHut 27.8 x 19.9 x 16.0, 3600; MountainChalet 31.2 x 23.3 x 20.0, 4000. Origin = footprint centre at ground, bbox centred.
- Attachments: `Entrance` at ground on the front floor edge of the counter opening or door, `Computer` on the desk top (under the monitor; desk centre on Hut and Chalet), `Radio` at the radio. Colliders: unrotated `COL_` boxes, one body box on Hut and Chalet.
- Front = -Z after export, so wiring (CM2-13W) turns the model 180 degrees on plots 1-3 and 0 degrees on plots 4-6 to face the road. The game keeps today's stand until CM2-13W (needs the PC-2 upload).

## Lot props art (CM2-13b)
- Paths: `Props/{CheckoutCounter,ReceivingBay}` (tier A), `Props/TreeBundle`, `Environment/{FenceRail8,FenceRail6,FencePost}` (tier B); sources `assets/art/source/<artPath>/`, fence parts from `assets/art/source/Environment/fence_common.py`, previews `assets/art/previews/<artPath>.png`.
- Footprint x depth x H, triangles / maxTriangles: CheckoutCounter 5.0 x 2.0 x 5.0, 1480 / 1500 (collider `COL_Counter` 5 x 2 x 3.7 = the `Path.Counter` box); ReceivingBay 5.0 x 5.0 x 2.6, deck top 0.80, 812 / 900 (`COL_Pallet` 5 x 5 x 0.8); TreeBundle 4.0 x 1.03 x 1.03 along X, origin bottom centre, 196 / 240 (no collider); FenceRail8 8.25 and FenceRail6 6.25 long x 0.6 x 4.1, 194 / 300 (`COL_Fence` L x 0.6 x 3.2); FencePost 0.6 x 0.6 x 4.1, 62 / 100 (`COL_Post`).
- Attachments (model space after export): CheckoutCounter `Checkout1` (0, 0, -3) = queue slot 1, `CashierStand` (0, 0, 2.5), `Register` (-0.6, 4.02, 0.2); ReceivingBay `BundleBase` (0, 0.8, 0). Front = -Z after export; CM2-13W turns the counter like the stand. CM2-13W keeps `CheckoutCounter.CounterBase` with `CheckoutPrompt` (or moves both and updates `WorldService.checkoutTarget`); `Checkout1` = queue slot 1, slots then follow `Path.QueueSpacing` 3.5. CM2-25/26: the visible Cashier stands at `NpcPath.staffPoint()` = lot (16, −16.5); CM2-13W keeps `CashierStand` exactly there (counter centre z −14, +2.5 toward the back). The staff break area (campfire `BreakArea`: `Pad`, `FireRing`, `Embers`, `Seat_1..3`) is Part-built small decor in `StaffNpcWorld.syncBreakArea`, no Blender asset.
- Fence layout for CM2-13W: back run at lot-frame z -27 - 6 x level, 10 x FenceRail8 from x -40 plus a FencePost at x 40; each side (x +-40) 9 + level x FenceRail6, laid from the front corner (z 27) back to the back run, post first, so no two posts coincide; the road side stays open. A rail segment's origin is its centre; after export its start post is at model +X (x = +L/2) and its rails run to -X, so each segment is yawed until model -X points along the run.

## Vehicle art (CM2-14)
- Paths: `Vehicles/{SupplierTruck,CustomerHatchback,CustomerWagon,CustomerSuv}` (tier A); sources `assets/art/source/Vehicles/<Name>/`, cars from the shared `assets/art/source/Vehicles/vehicle_common.py`, previews `assets/art/previews/Vehicles/<Name>.png`.
- Size W x L x H (incl. mirrors), triangles / maxTriangles, MeshParts: SupplierTruck 5.98 x 13.0 x 6.0, 2736 / 3000, 10; CustomerHatchback 5.0 x 8.0 x 4.0, 1436 / 1500, 7; CustomerWagon 5.0 x 9.0 x 4.0, 1400 / 1500, 7; CustomerSuv 5.0 x 9.0 x 4.6, 1496 / 1500, 7. Origin = footprint centre on the wheel contact plane (the flat bottom faces of the 10-sided wheels rest on y 0); front = -Z after export; centred (|min + max| <= 0.01).
- `CargoAnchor` (model space after export): truck (0, 2.6, 2.1) = deck top centre, inner bed x +-2.45, z -1.85..6.05 for up to 9 `Props/TreeBundle` (built empty); cars (0, H, rack centre): Hatchback (0, 4.0, 1.49), Wagon (0, 4.0, 1.84), SUV (0, 4.6, 1.72) = roof-rack top centre, the roof tree lies along Z on it. Colliders: truck `COL_Cab` 5.4 x 4.6 x 4.35 at (0, 3.3, -4.33), `COL_Bed` 5.4 x 2.3 x 8.5 at (0, 1.45, 2.25); cars `COL_Body` 4.6 x (roof - 0.3) x L from y 0.3.
- Colour variants: each car has one MeshPart `Paint` (palette `CarPaint`); CM2-14W sets its `Color` from `CAR_COLORS` (3 bodies x 6 colours). Tail lights sit on a dark surround so they read on a red car.
- Measured gameplay geometry for CM2-14W (today's code): truck lane at lot-frame x 46 (fence x 40, next lot x 70), lane top y 0, stop centred on `bayDepth(i)` = -22 + 6(i - 1); today's primitive truck 12 x 5.8 x 5.95, cab toward world +Z with yaw pi/2. Parking space i 8 (x) x 12 (z) at lot x -24 + 12(i - 1), depth 20, top y 0.82, lot top 0.55, NPC door point +3.5 x from the space centre; today's primitive car body 5 x 1.8 x 9 with `PrimaryPart` Body at y 0.9, label `CarNumber` 6 above it, roof tree (scale 0.35, ~4.9 long) at Body x (0, 4.4, 0.6).

## Lot sign (CM2-G15)
- Lot sign (CM2-G15): Parts at lot (23, 23), KeepClear `Sign`; art may replace the parts but keeps `LotSign.Board` with `SignFront`, `SignBack`, `LikePrompt`.
- Decor fences at `Placement.DecorFences`; art replacing `FenceWooden` must fit within `DecorFenceRadius` of its centre.

## Map layout (CM2-10)
- Contract for CM2-10b, CM2-10c and CM2-10W (plan `docs/plans/CM2-10a.md`). World frame, y up, road along X: road x -190..190, z -16..16, top 0.35; plot centres cx -110, 0, 110 at cz -75 (plots 1-3) or +75 (4-6); lot 80 x 54, top 0.55, world z = cz + facing x depth; lot depth -27..-75 reserved for 6 expansion levels x 8.
- Keep-out boxes K per plot (z for plots 1-3, mirrored for 4-6); every map piece's footprint stays >= 3 away: Road x -190..190, z -16..16 (bridge, approach road and square join its ends); Lot x cx-40..cx+49, z -150..-48 (lot, fence, truck lane, bays, signs, decor fences, spawn, reserve); Cars x cx-28..cx+16, z -48..-16; Truck x cx+43..cx+49, z -48..-16.
- Parts (CM2-10W, no Roblox Terrain): ground x -560..560, z -380..380, top 0, split at the stream; stream channel x -236..-200 (bank wedges 6 wide), ice x -230..-206 top -3, full length; approach road x -560..-246, z -16..16, top 0.35; square x 190..280, z -45..45, top 0.35; sidewalks z 16..20 (both sides), top 0.45; gravel truck lanes; boundary walls.
- Landmarks (origin, yaw = `CFrame.Angles(0, yaw, 0)`, model front -Z; 0 faces -Z, 180 +Z, 90 -X, -90 +X): `Buildings/CoveredBridge` (-218, 0, 0) yaw 90, spans x -246..-190 (abutments on the banks, deck over the channel); `Environment/VillageTree` (235, 0, 0), r 15.
- Square: LeaderboardBoard yaw 0 at (217, 36.5) Cash earned and (253, 36.5) Reputation, yaw 180 at (217, -36.5) Hours played and (253, -36.5) Robux spent; VillageHouse yaw 0 at (212, 62), (258, 62), yaw 180 at (212, -62), (258, -62); Bench yaw 90 at (262, +-12), yaw -90 at (208, +-20).
- LampPost (22): square (194/235/276, +-41) and (276, +-14); beside the sidewalks x -165, -80, -38, 30, 70, 140, 182 at z +-22 (on the ground, 1.5 behind the sidewalk edge z +-20). SignBoard (7): welcome (-170, 30) yaw 0; DELIVERIES at lot (57, 52) per plot, yaw 180 on plots 1-3, 0 on plots 4-6.
- Forest zones: N/S x -410..410 without x -240..-196, z +-(156..260); NE/SE x 165..410, z +-(78..156); E x 286..410, z -80..80; W x -410..-242, z +-(22..260); stream-plot x -194..-156, z +-(52..260); plot gaps x -58..-43 and 52..67, z +-(51..153), ForestFir only.
- Reserve firs: 20 per plot at lot depth -36, -46, -56, -66 x lot x -30, -15, 0, 15, 30 (jitter +-1.5); CM2-10W hides the rows the current expansion level uses.
- Mountains (13): yaw 0 Ridge (-300, 350), Peak (-60, 350), Ridge (190, 350), Peak (430, 340); yaw 180 Peak (-300, -350), Ridge (-60, -350), Peak (190, -350), Ridge (430, -340); yaw -90 Ridge (-500, +-175), Peak (-760, 0); yaw 90 Peak (560, -150), Ridge (560, 150).
- Clearance to K (box to box, all 6 plots, measured CM2-10a): plot-gap zones 3.0; stream-plot, N/S and NE/SE zones 6.0; square 31.0; bridge 50.6; tree 30.0; mountain centres >= 200. Point pieces, centre to nearest K (footprint half-extent may be at most this - 3): sidewalk lamps 6.0, DELIVERIES signs 7.0 (road), welcome sign 14.0, benches 18.4, boards 33.9, houses 51.0.
- Map budget (full-detail triangles; CM2-10W places at most these counts, identical meshes instance): CoveredBridge, VillageTree 4000 / 10 each; LeaderboardBoard 1500 / 8 x 4; VillageHouse 3000 / 10 x 4; SignBoard 220, LampPost 160, Bench 240 / 3 x 7, 22, 4; ForestFir 240 / 3 x 152 (120 reserve, 32 gaps); ForestClusterA 1000 / 4 x 40, ForestClusterB 700 / 4 x 30; RockCluster 300 / 3 x 24; MountainPeak, MountainRidge 1000 / 4 x 6, 7. Total <= 149700 triangles, <= 1051 MeshParts, 302 models (both corrected by CM2-10W; the contract's 1047 and 298 were arithmetic slips, 298 left out the 4 benches).
- Today's defects CM2-10W removes: `MarketGazebo` (-62, 30) in plot 4's truck lane; `OriginalGrayboxAssets` (x -150..-90, z 98) on plot 4's lot; `ForestTree*` and `ImportedWinterScenery` in the reserve.

## Map art (CM2-10a)
- Paths: `Buildings/CoveredBridge`, `Environment/VillageTree` (tier A, 4000 / 10); sources `assets/art/source/<artPath>/`, previews `assets/art/previews/<artPath>.png`.
- CoveredBridge W x L x H 34.2 x 56.2 x 23.92 (bbox y -4.0..19.92), 3900 triangles, 10 MeshParts; deck top 0.35 (= road top), portal opening 22 x 12 (x -11..11, y 0.35..12.35). Colliders `COL_Deck` 34 x 56 x 0.6 at (0, 0, 0.05), `COL_AbutFront/Back` 34 x 10 x 3.75 at (0, -23/23, -2.125), `COL_WallL/R` 0.8 x 48 x 12.3 at (+-14.3, 0, 6.5) (Blender coordinates). Attachments after export `PortalFront` (0, 0.35, -28), `PortalBack` (0, 0.35, 28).
- VillageTree W x L x H 29.89 x 29.89 x 48.0 (bbox y 0..48), 2412 triangles, 10 MeshParts; colliders `COL_Planter` 30 x 30 x 1.2, `COL_Trunk` 4 x 4 x 20; attachments `TreeBase` (0, 0, 0), `Star` (0, 46, 0).
- The game is unchanged; CM2-10W places both (fallback Parts until the PC-2 upload makes the `.rbxm`).

## Map art (CM2-10b)
- Paths: `Props/LeaderboardBoard`, `Buildings/VillageHouse` (tier A), `Props/SignBoard`, `Props/LampPost`, `Props/Bench` (tier B); sources `assets/art/source/<artPath>/`, previews `assets/art/previews/<artPath>.png`. Origin = footprint centre on the ground, front = -Z after export, centred (|min + max| <= 0.03).
- W x L x H, triangles / maxTriangles, MeshParts: LeaderboardBoard 14.0 x 2.97 x 17.85, 1332 / 1500, 8; VillageHouse 23.15 x 19.2 x 22.3, 2588 / 3000, 10; SignBoard 8.6 x 1.0 x 6.9, 156 / 220, 3; LampPost 1.13 x 1.13 x 8.96, 148 / 160, 3; Bench 4.96 x 1.82 x 2.9, 212 / 240, 3.
- Attachments (model space after export): LeaderboardBoard `Screen` (0, 8.2, -0.3) for the 11 x 10 screen Part, `Title` (0, 15.3, -0.45) for the 10 x 1.4 title Part (CM2-G12, SurfaceGuis on their -Z faces); VillageHouse `Entrance` (0, 0, -9.6); SignBoard `SignFront` (0, 4.6, -0.2), text area 7.4 x 3.0; LampPost `Light` (0, 8.15, 0) for the PointLight (CM2-G12); Bench none (no `Seat`).
- Colliders (Blender coordinates): `COL_Board` 13.6 x 1.2 x 16.2 at (0, 0, 8.1); `COL_Body` 20 x 16 x 12 at (0, 0, 6) (not enterable); `COL_Sign` 8 x 0.6 x 6.4 at (0, 0, 3.2); `COL_Post` 0.6 x 0.6 x 7.6 at (0, 0, 3.8); `COL_Seat` 5.0 x 1.6 x 1.6 at (0, -0.1, 0.8).
- VillageHouse walls are the single MeshPart `Paint` (FabricCream); CM2-10W recolours it per house. The game is unchanged; CM2-10W places the pieces (positions in "Map layout (CM2-10)").

## Map art (CM2-10c)
- Paths (all tier B): `Environment/ForestFir`, `Environment/ForestClusterA`, `Environment/ForestClusterB`, `Environment/RockCluster`, `Environment/MountainPeak`, `Environment/MountainRidge`; sources `assets/art/source/<artPath>/` (shared shapes `assets/art/source/Environment/map_common.py`), previews `assets/art/previews/<artPath>.png`. Origin = footprint centre on the ground.
- W x L x H, triangles / maxTriangles, MeshParts: ForestFir 8.75 x 8.67 x 16.0, 164 / 240, 3; ForestClusterA 21.81 x 20.56 x 28.0, 780 / 1000, 4; ForestClusterB 14.26 x 13.22 x 20.0, 620 / 700, 4; RockCluster 7.4 x 4.5 x 2.7 (bbox y -0.3..2.7), 240 / 300, 3; MountainPeak 220 x 180 x 150, 692 / 1000, 4; MountainRidge 300 x 150 x 100, 548 / 1000, 4.
- Mountains are open surfaces sunk to y -12 (bbox y -12..150 / -12..100); front (-Z after export) = the valley side. Their only collider is `COL_Core` 20 x 20 x 20 at (0, 0, 10), inside the mass, so the MeshParts do not collide; CM2-10W adds boundary walls.
- Colliders (Blender coordinates): `COL_Trunk` 1.4 x 1.4 x 6 at (0, 0, 3) on ForestFir, `COL_Trunk1..5` / `COL_Trunk1..3` at each trunk on the clusters, `COL_Rock` 6.6 x 4.0 x 2.2 at (0.1, 0, 0.8). Attachment `TreeBase` (0, 0, 0) on ForestFir only.
- The game is unchanged; CM2-10W places them (zones and counts in "Map layout (CM2-10)").

## Map in the world (CM2-10W)
- Modules: `src/shared/MapLayout.lua` (pure data and maths: pieces, seed 1010, zones, surfaces, walls, hide levels, `plan`), `src/server/Services/MapWorld.lua` (builds `ChristmasMarketWorld.Map`, `applyReserve`), wired by `WorldService.build`; `ArtLibrary.root(ReplicatedStorage)` picks the non-empty `ArtAssets` folder.
- `Map` folders: `Surfaces`, `Walls`, `Landmarks`, `Square`, `Street`, `Forest`, `Rocks`, `Mountains`, `Reserve` (`Plot_01..06` with `Row_1..4`). Each placed model carries `MapPiece = id`.
- Missing art: Part fallbacks for CoveredBridge, VillageTree, LeaderboardBoard, SignBoard, ForestFir, ForestClusterA, ForestClusterB (attribute `MapFallback`); VillageHouse, LampPost, Bench, RockCluster, MountainPeak, MountainRidge are skipped. One `[ART]` warning per missing path.
- Reserve firs vanish by row as the lot grows: hide levels {1, 2, 4, 6}, hidden rows at levels 0-6: 0, 1, 2, 2, 3, 3, 4 (`applyLotExpansionVisual` caps the level at `LotExpansion.maxLevel`, today 3).
- For CM2-G12: `Map.Square.Board_<Key>` (`CashEarned`, `Reputation`, `HoursPlayed`, `RobuxSpent`) has attribute `LeaderboardKey`, the Part `Screen` (11 x 10, attribute `LeaderboardScreen`) and the Part `Title` with `TitleGui`.
- Budget: the pieces total 302 models, 149700 triangles and 1051 MeshParts; the contract's 298 models left out the 4 benches (see the budget line above). `workspace.StreamingEnabled` is true in both project files (the server owns the map; clients read only their own nearby plot).

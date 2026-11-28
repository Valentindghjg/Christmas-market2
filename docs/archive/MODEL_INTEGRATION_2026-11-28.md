# MODEL_INTEGRATION archive 2026-11-28 (CM2-SLIM10)

Finished detail moved out of `docs/MODEL_INTEGRATION.md`; each block sits under the heading it came from. Placement contracts stay in the live file.

## HQ art (CM2-13a)
- Import (branch I, 2026-11-24): the 4 `.rbxm` are in `assets/art/rbxm/Buildings/` (asset IDs in each `asset.json`, version 2); Studio Edit sizes SalesTent 19.83 x 13.74 x 10.05, the others within the table; attachments verified in the saved `.rbxm` (Entrance at y 0 on the front edge).

## Lot props art (CM2-13b)
- Import (branch I, 2026-11-24): the 6 `.rbxm` are in `assets/art/rbxm/{Props,Environment}/` (asset IDs in each `asset.json`, version 2); the Studio Edit attachments match the values above. `Normalize` writes attachments through `CFrame` (Lune does not serialize `Attachment.Position`).

## Lot gate and fence (CM2-GATE)
- Import: the 4 `.rbxm` are in `assets/art/rbxm/{Props,Environment}/` (asset IDs in each `asset.json`; fences version 3, LotGate version 2); `art.luau verify release.rbxlx` 42 integrated, 0 pending, 0 failed.

## Vehicle art (CM2-14)
- Measured gameplay geometry for CM2-14W (today's code): truck lane at lot-frame x 46 (fence x 40, next lot x 70), lane top y 0, stop centred on `bayDepth(i)` = -22 + 6(i - 1); today's primitive truck 12 x 5.8 x 5.95, cab toward world +Z with yaw pi/2. Parking space i 8 (x) x 12 (z) at lot x -24 + 12(i - 1), depth 20, top y 0.82, lot top 0.55, NPC door point +3.5 x from the space centre; today's primitive car body 5 x 1.8 x 9 with `PrimaryPart` Body at y 0.9, label `CarNumber` 6 above it, roof tree (scale 0.35, ~4.9 long) at Body x (0, 4.4, 0.6).
- Import (branch I, 2026-11-24): the 4 `.rbxm` are in `assets/art/rbxm/Vehicles/` (asset IDs in each `asset.json`, version 2); sizes and `CargoAnchor` positions read back from the saved `.rbxm` match the values above; Studio Edit shows exactly the 4 models in `ArtAssets.Vehicles`.

## Map art (CM2-10a)
- CoveredBridge W x L x H 34.2 x 56.2 x 23.92 (bbox y -4.0..19.92), 3900 triangles, 10 MeshParts; deck top 0.35 (= road top), portal opening 22 x 12 (x -11..11, y 0.35..12.35). Colliders `COL_Deck` 34 x 56 x 0.6 at (0, 0, 0.05), `COL_AbutFront/Back` 34 x 10 x 3.75 at (0, -23/23, -2.125), `COL_WallL/R` 0.8 x 48 x 12.3 at (+-14.3, 0, 6.5) (Blender coordinates). Attachments after export `PortalFront` (0, 0.35, -28), `PortalBack` (0, 0.35, 28).
- VillageTree W x L x H 29.89 x 29.89 x 48.0 (bbox y 0..48), 2412 triangles, 10 MeshParts; colliders `COL_Planter` 30 x 30 x 1.2, `COL_Trunk` 4 x 4 x 20; attachments `TreeBase` (0, 0, 0), `Star` (0, 46, 0).

## Map art (CM2-10b)
- Attachments (model space after export): LeaderboardBoard `Screen` (0, 8.2, -0.3) for the 11 x 10 screen Part, `Title` (0, 15.3, -0.45) for the 10 x 1.4 title Part (CM2-G12, SurfaceGuis on their -Z faces); VillageHouse `Entrance` (0, 0, -9.6); SignBoard `SignFront` (0, 4.6, -0.2), text area 7.4 x 3.0; LampPost `Light` (0, 8.15, 0) for the PointLight (CM2-G12); Bench none (no `Seat`).
- Colliders (Blender coordinates): `COL_Board` 13.6 x 1.2 x 16.2 at (0, 0, 8.1); `COL_Body` 20 x 16 x 12 at (0, 0, 6) (not enterable); `COL_Sign` 8 x 0.6 x 6.4 at (0, 0, 3.2); `COL_Post` 0.6 x 0.6 x 7.6 at (0, 0, 3.8); `COL_Seat` 5.0 x 1.6 x 1.6 at (0, -0.1, 0.8).

## Map art (CM2-10c)
- Mountains are open surfaces sunk to y -12 (bbox y -12..150 / -12..100); front (-Z after export) = the valley side. Their only collider is `COL_Core` 20 x 20 x 20 at (0, 0, 10), inside the mass, so the MeshParts do not collide; CM2-10W adds boundary walls.
- Colliders (Blender coordinates): `COL_Trunk` 1.4 x 1.4 x 6 at (0, 0, 3) on ForestFir, `COL_Trunk1..5` / `COL_Trunk1..3` at each trunk on the clusters, `COL_Rock` 6.6 x 4.0 x 2.2 at (0.1, 0, 0.8). Attachment `TreeBase` (0, 0, 0) on ForestFir only.
- Import of all 13 map models (CM2-10a, 10b, 10c; branch I, 2026-11-24): the `.rbxm` are in `assets/art/rbxm/Buildings/`, `Environment/` and `Props/` (asset IDs in each `asset.json`, version 2); sizes and attachments read back from the files match the tables above (`PortalFront`/`PortalBack` (0, 0.35, -28/+28), `Star` (0, 46, 0), `Screen`/`Title`, `Entrance` (0, 0, -9.6), `Light` (0, 8.15, 0), `TreeBase`). In Studio the plan places 302 pieces, all as art (fallback 0, skip 0, missing 0).

## Map dressing (CM2-10D)
- Measured W x L x H, triangles / maxTriangles, MeshParts: SnowPileA 5.76 x 3.83 x 1.56 (bbox y -0.2..1.36), 120 / 160, 2; SnowPileB 4.58 x 4.64 x 3.02 (y -0.2..2.82), 200 / 240, 2; Snowman 3.5 x 2.3 x 5.75, 499 / 560, 3; Sled 1.77 x 3.99 x 1.16, 292 / 300, 3; WoodStack 5.6 x 2.31 x 3.57, 480 / 520, 3; FirBarrel 2.4 x 2.4 x 6.0, 284 / 360, 3.
- Colliders (Blender coordinates, unrotated): `COL_Pile` 5.0 x 3.0 x 1.0 at (0, 0, 0.5) / 4.0 x 4.0 x 2.2 at (0, 0, 1.1); `COL_Body` 2.4 x 2.4 x 4.6 at (0, 0, 2.3); `COL_Sled` 1.8 x 4.4 x 0.8 at (0, 0, 0.4); `COL_Stack` 5.4 x 2.2 x 3.2 at (0, 0, 1.6); `COL_Barrel` 2.4 x 2.4 x 1.8 at (0, 0, 0.9) (the fir above it does not collide).

## Village infrastructure (CM2-10I)
- Measured B1 (W x L x H; triangles / max, MeshParts; colliders in Blender coordinates, unrotated; no attachments): SnowStake 0.26 x 0.3 x 5.0, 50 / 60, 2, `COL_Stake` 0.3 x 0.3 x 5 at (0,0,2.5) · FireHydrant 1.12 x 1.25 x 2.6, 172 / 200, 3, `COL_Body` 1 x 1 x 2.2 at (0,0,1.1) · TrashBin 1.44 x 1.44 x 2.8, 180 / 220, 3, `COL_Bin` 1.4 x 1.4 x 2.6 at (0,0,1.3) · UtilityBox 2.6 x 1.6 x 3.47, 160 / 160, 3, `COL_Box` 2.4 x 1.4 x 3.2 at (0,0,1.6) · MailboxCluster 2.86 x 1.13 x 3.95, 300 / 300, 3, `COL_Box` 3 x 1.2 x 1.2 at (0,0,3.1) + `COL_Post` 0.4 x 0.4 x 2.6 at (0,0,1.3) · GuardRail 8.0 x 0.51 x 2.56 (logs end flush at x +-4), 216 / 240, 3, `COL_Rail` 8 x 0.6 x 2.4 at (0,0,1.2).
- Measured B2 (W x L x H; triangles / max, MeshParts; colliders and attachments in Blender coordinates, model space = (-x, z, y); all B2 values have x 0, so none changes): UtilityPole 0.92 x 3.0 x 17.9, 238 / 260, 3, `COL_Pole` 0.8 x 0.8 x 17.6 at (0,0,8.8), `WireA` (0,-1.2,17.1), `WireB` (0,1.2,17.1) · RoadSignSpeed 2.1 x 0.56 x 7.1, 156 / 160, 3, `COL_Post` 0.4 x 0.4 x 6.9 at (0,0,3.45), `SignFront` (0,-0.25,6.0) on the white face · RoadSignDirection 5.0 x 0.58 x 7.5, 236 / 300, 3, `COL_Post` 0.4 x 0.4 x 7.2 at (0,0,3.6), `SignTop` (0,-0.2,6.4), `SignBottom` (0,-0.2,5.2) on the board fronts · BusStop 7.6 x 3.6 x 7.65, 384 / 400, 3, `COL_Back` 7.2 x 0.4 x 6.6 at (0,1.5,3.3) + `COL_Bench` 6 x 1 x 1 at (0,0.9,0.5), `Light` (0,-0.2,6.9) under the roof · GarageShed 8.79 x 8.94 x 9.32, 1352 / 1400, 6 (`asset.json` tier A: the 1400 / 6 budget exceeds the tier B cap), `COL_Body` 8 x 7.4 x 5.5 at (0,0,2.75), no attachments.
- Measured B3 (W x L x H; triangles / max, MeshParts; colliders and attachments in Blender coordinates, model space = (-x, z, y)): VillageShop 22.8 x 17.87 x 19.97, 2966 / 3000, 9, `COL_Body` 20 x 14 x 12 at (0,0,6), `Light` (0,-8.0,7.2) under the awning, 0.65 below it, 1 in front of the door · FireStation 24.08 x 20.0 x 22.5, 2628 / 3000, 9, `COL_Hall` 22 x 16 x 9 at (0,0,4.5) + `COL_Tower` 4.4 x 4.4 x 18 at (8.5,5.5,9) (model space (-8.5,9,5.5)), no attachments. All 13 measured W/L stay within the table maxima, so the clearances above hold; measured sums for the 77 pieces: 22346 triangles (plan 24320), 235 MeshParts (plan 237).

## Second pass (budgets, sizes, clearances; same headings as in the live file)

## Tree art (CM2-12)
- Budgets (tier A, `asset.json`): maxTriangles Small 800, Medium 1000, Large 1200, special 1600; maxMeshParts 7 (one MeshPart per colour: Trunk, RootFlare, NeedlesCore, Needles, Snow, then Frost/Topper/Berries).

## HQ art (CM2-13a)
- Footprint (incl. overhangs) x H in studs, maxTriangles: SalesTent 19.8 x 13.7 x 10.0, 2500; TimberPavilion 23.6 x 17.6 x 12.9, 4000; AlpineHut 27.8 x 19.9 x 16.0, 3600; MountainChalet 31.2 x 23.3 x 20.0, 4000. Origin = footprint centre at ground, bbox centred.

## Lot props art (CM2-13b)
- Footprint x depth x H, triangles / maxTriangles: CheckoutCounter 5.0 x 2.0 x 5.0, 1480 / 1500 (collider `COL_Counter` 5 x 2 x 3.7 = the `Path.Counter` box); ReceivingBay 5.0 x 5.0 x 2.6, deck top 0.80, 812 / 900 (`COL_Pallet` 5 x 5 x 0.8); TreeBundle 4.0 x 1.03 x 1.03 along X, origin bottom centre, 196 / 240 (no collider); fence sizes: see "Lot gate and fence (CM2-GATE)" (fence v3, tier A).
- Attachments (model space after export): CheckoutCounter `Checkout1` (0, 0, -3) = queue slot 1, `CashierStand` (0, 0, 2.5), `Register` (-0.6, 4.02, 0.2); ReceivingBay `BundleBase` (0, 0.8, 0). Front = -Z after export; CM2-13W turns the counter like the stand. CM2-13W keeps `CheckoutCounter.CounterBase` with `CheckoutPrompt` (or moves both and updates `WorldService.checkoutTarget`); `Checkout1` = queue slot 1, slots then follow `Path.QueueSpacing` 3.5. CM2-25/26: the visible Cashier stands at `NpcPath.staffPoint()` = lot (16, −16.5); CM2-13W keeps `CashierStand` exactly there (counter centre z −14, +2.5 toward the back). The staff break area (campfire `BreakArea`: `Pad`, `FireRing`, `Embers`, `Seat_1..3`) is Part-built small decor in `StaffNpcWorld.syncBreakArea`, no Blender asset.

## Lot gate and fence (CM2-GATE)
- Size W x D x H (from `report.json`, model space after export), triangles / maxTriangles, MeshParts: LotGate 19.3 x 1.85 x 17.59, 2868 / 3000, 9; FenceRail8 8.40 x 0.9 x 5.93, 512 / 800, 4; FenceRail6 6.40 x 0.9 x 5.93, 452 / 800, 4; FencePost 0.9 x 0.9 x 5.93, 160 / 400, 3. Fence wood is all `WoodWarmShade`.
- Gate: opening between the posts 16.3 wide x 12.1 high, clear (lowest decoration 12.2); each post footprint 1.5 x 1.5 (StoneGrayShade plinth, WoodWarm bands at 1.15 and 12.3) at x +-8.9; beam bottom 12.6; blank FabricCream sign 9.0 x 2.2 in a GoldAccent frame (13.4 .. 15.9); snowy lit arch to 17.6; garland with bulbs and RoofRed bows along the beam front. Colliders `COL_PostL`, `COL_PostR` 1.5 x 15.2 x 1.5 at (+-8.9, 7.6, 0), `COL_Header` 19.0 x 5.0 x 1.4 at (0, 15.1, 0).

## Vehicle art (CM2-14)
- Size W x L x H (incl. mirrors), triangles / maxTriangles, MeshParts: SupplierTruck 5.98 x 13.0 x 6.0, 2736 / 3000, 10; CustomerHatchback 5.0 x 8.0 x 4.0, 1436 / 1500, 7; CustomerWagon 5.0 x 9.0 x 4.0, 1400 / 1500, 7; CustomerSuv 5.0 x 9.0 x 4.6, 1496 / 1500, 7. Origin = footprint centre on the wheel contact plane (the flat bottom faces of the 10-sided wheels rest on y 0); front = -Z after export; centred (|min + max| <= 0.01).
- `CargoAnchor` (model space after export): truck (0, 2.6, 2.1) = deck top centre, inner bed x +-2.45, z -1.85..6.05 for up to 9 `Props/TreeBundle` (built empty); cars (0, H, rack centre): Hatchback (0, 4.0, 1.49), Wagon (0, 4.0, 1.84), SUV (0, 4.6, 1.72) = roof-rack top centre, the roof tree lies along Z on it. Colliders: truck `COL_Cab` 5.4 x 4.6 x 4.35 at (0, 3.3, -4.33), `COL_Bed` 5.4 x 2.3 x 8.5 at (0, 1.45, 2.25); cars `COL_Body` 4.6 x (roof - 0.3) x L from y 0.3.

## Map layout (CM2-10)
- Clearance to K (box to box, all 6 plots, measured CM2-10a): plot-gap zones 3.0; stream-plot, N/S and NE/SE zones 6.0; square 31.0; bridge 50.6; tree 30.0; mountain centres >= 200. Point pieces, centre to nearest K (footprint half-extent may be at most this - 3): sidewalk lamps 6.0, DELIVERIES signs 7.0 (road), welcome sign 14.0, benches 18.4, boards 33.9, houses 51.0.
- Map budget (full-detail triangles; CM2-10W places at most these counts, identical meshes instance): CoveredBridge, VillageTree 4000 / 10 each; LeaderboardBoard 1500 / 8 x 4; VillageHouse 3000 / 10 x 4; SignBoard 220, LampPost 160, Bench 240 / 3 x 7, 22, 4; ForestFir 240 / 3 x 152 (120 reserve, 32 gaps); ForestClusterA 1000 / 4 x 40, ForestClusterB 700 / 4 x 30; RockCluster 300 / 3 x 24; MountainPeak, MountainRidge 1000 / 4 x 6, 7. Total <= 149700 triangles, <= 1051 MeshParts, 302 models (both corrected by CM2-10W; the contract's 1047 and 298 were arithmetic slips, 298 left out the 4 benches).
- Today's defects CM2-10W removes: `MarketGazebo` (-62, 30) in plot 4's truck lane; `OriginalGrayboxAssets` (x -150..-90, z 98) on plot 4's lot; `ForestTree*` and `ImportedWinterScenery` in the reserve.

## Map dressing (CM2-10D)
- Sums (planner-checked with `MapLayout` against the 302 pieces, W/L maxima): **110 models** (A 32, B 14, SM 8, SL 6, WS 6, FB 16, L 10, BE 8, F 10), **29560 triangles**, **284 MeshParts**; **10 new lamps** (NightLights 46 -> 56 <= 58). Clearances: keep-out min 3.50, existing pieces 1.09, dressing pieces 1.14; nothing on road, sidewalks, approach road, square, channel, truck lanes, gate fronts (lot x 16..43) or beyond |x| 414, |z| 264.

## Village infrastructure (CM2-10I)
- Sums (planner-checked with `MapLayout` vs the 412 pieces, W/L maxima): **77 models** (UP 20, GR 16, ST 14, MB 5, TB 5, HY 5, BS 2, RS 2, RD 2, UB 2, GS 2, VS 1, FS 1), **24320 triangles**, **237 MeshParts**. Clearances: keep-out min 3.30; existing pieces 1.035; infra pieces 1.5 (rails of one chain abut); road, sidewalks, approach road, square, channel >= 1.0; inside |x| 414, |z| 264. Map after 10IW: 489 / 203580 / 1572.

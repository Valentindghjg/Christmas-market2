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
- Checks: `tests/tools/art_pipeline.luau`, `art.luau verify <place>` (CI), playtest step `ART_ASSETS`.

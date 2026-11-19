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
FrasierFir, NobleFir, BlueSpruce (each Small/Medium/Large); StarterSalesTent, ChristmasPavilion; SupplierTruck; CheckoutCounter; DeliveryBay; BasicFence; FestiveLights; CustomerRig; CashierRig; LotWorkerRig.

## Integration behavior
Missing model: fail gracefully and log `MissingArtAsset`; never grant extra inventory or charge a player for a placement that failed. Config IDs must not be derived from art model filenames.

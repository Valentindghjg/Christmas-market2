# CM2-GATEW — Entrance gate in the world, fence footprint and gate lights

Planner `planner`. Everything below is decided.

## Goal
Each plot shows the `LotGate` at its road edge beside the parking, with the lot's name and two night lights; fence constants match the v3 post.

## Source of truth
Backlog CM2-GATEW; plan CM2-GATE Amendment 1; MODEL_INTEGRATION "Lot gate and fence (CM2-GATE)" (attachment positions); CM2-13W yaw rule; CM2-G15 `NameSource`.

## Implementer tier
Tier: M. Reason: world placement in a new server module plus WorldService wiring and playtest changes; no save field, money, remote or schema.

## Skill checks
- building: parts offset from the pose CFrame, never guessed world points; Anchored, CanCollide, material explicit; named root with pivot.
- lighting: PointLights only through `MapWorld.nightLight` (tag `NightLight`, `Shadows` false, off on the server); no Light inside the art templates.
- gui: world SurfaceGui, `LightInfluence` 0; text from server attributes, localized by `WorldLabels` (`LabelKind` "LotSignName"); no new strings.
- luau-patterns/architecture: plain-function server module, configure before parenting, no circular require; pure maths in `LotArt`.

## Placement decisions (derived)
- Customers never cross the front edge: cars drive straight from the road to spaces at lot x −24..12 (boxes x −28..16, z 14..26) and NPCs start at the door (space x + 3.5, z 20). So the gate cannot stand over the car lanes; it stands for players coming from the sidewalk, east of the parking.
- Gate pivot lot-frame (x **28**, z **28** = `LotHalfDepth` 27 + `GATE_OFFSET` **1.0**), y = `lotTop − FENCE_BASE_DROP` (map ground 0). Posts (1.5 × 1.5 at x ±8.9): x 18.35..19.85 and 36.15..37.65, z 27.25..28.75, fully off the placeable lot (z ≤ 27): trees, break area and NPC points never touch them. Clearances: parking/car lanes 2.35, walk line of space 4 (x 15.5) 2.85, truck lane (x 43) 5.35, `Sign` box 2.25. The lot sign (x 19..27) shows through the opening.
- Backlog deviations: offset 1.0, not `FENCE_OFFSET` 0.45 (post would reach into the lot); customers cannot walk through the gate. Steps 37/40 stay as regression (0 snaps).
- The right decor fence (34, 24) stands 3 studs behind the opening: drop it. `DecorFences = { { x = -34, z = 24 } }`.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/LotArt.lua` | Change | constants, `PATHS.Gate`, `gatePose`, `gatePostBoxes` |
| `src/shared/GameConfig.lua` | Change | `DayCycle.GateLight`, `Placement.DecorFences` |
| `src/shared/UiTheme.lua` | Change | `UiTheme.LotGate` |
| `src/server/Services/LotGateWorld.lua` | New | build gate, sign, lights; `nameLabel` |
| `src/server/Services/WorldService.lua` | Change | build call, name mirror in `setLotSign` |
| `tests/studio/Cases/{LotArt,GameConfig}_Test.lua` | Change | tests below |
| `tests/studio/Playtest/Steps/{LotArt,DayNight}.lua` | Change | steps 66, 61 |
| `docs/MODEL_INTEGRATION.md`, `docs/DECISION_LOG.md` | Change | placement record |

## Data and config
- `LotArt.PIECE_HALF` 0.3 → **0.45**, `LotArt.RAIL_BEHIND` 4.3 → **4.45** (update both comments: post 0.9 wide, MODEL_INTEGRATION CM2-GATE). `RAIL_AHEAD` stays 3.95.
- `LotArt.PATHS.Gate = "Props/LotGate"`; `LotArt.GATE_X = 28`; `LotArt.GATE_OFFSET = 1.0`; `LotArt.GATE_POST_X = 8.9`; `LotArt.GATE_POST_HALF = 0.75`.
- `GameConfig.DayCycle.GateLight = { range = 12, brightness = 1.2 }, -- PROVISIONAL (CM2-GATEW)`.
- `GameConfig.Placement.DecorFences = { { x = -34, z = 24 } }` (comment: the right one gave way to the gate, CM2-GATEW).
- `UiTheme.LotGate = { pixelsPerStud = 40, nameMaxTextSize = 60, nameMinTextSize = 18, padding = 10, maxDistance = 150 }` (PROVISIONAL).

## Steps
1. **LotArt** (pure):
   - `LotArt.gatePose(): (number, number)` → `LotArt.GATE_X, Placement.LotHalfDepth + LotArt.GATE_OFFSET`.
   - `LotArt.gatePostBoxes(): { Box }` → left then right: x `GATE_X ∓ GATE_POST_X ± GATE_POST_HALF`, z `gate z ± GATE_POST_HALF`. Yaw: `LotArt.roadYaw`.
2. **LotGateWorld** (`--!strict`; requires ArtLibrary, GameConfig, LotArt, UiTheme from Shared and `MapWorld` from `script.Parent`). `LotGateWorld.build(plot: Model, ctx: LotArtWorld.Ctx): Model` (type via `require(script.Parent.LotArtWorld)`; LotArtWorld does not require LotGateWorld):
   - `pose = CFrame.new(ctx.lotPosition(plot, x, z, ctx.lotTop(plot) - LotArt.FENCE_BASE_DROP)) * CFrame.Angles(0, LotArt.roadYaw(ctx.facing(plot)), 0)` with x, z from `gatePose()`.
   - Art: `LotArt.choose(ArtLibrary.root(ReplicatedStorage), ArtLibrary.find, LotArt.PATHS.Gate)`; mode Art → `ArtLibrary.prepareClone`, `PivotTo(pose)`, attribute `LotArtMode` "Art". Else `ctx.reportMissing(path, code)` and the fallback below with `LotArtMode` "Primitive".
   - Fallback Model, every Part Anchored, SmoothPlastic, colour `MapWorld.paletteColor(key)`, `CFrame = pose * CFrame.new(local)`, then `model.WorldPivot = pose`:
     | Part | Size | Local centre | Key | CanCollide |
     |---|---|---|---|---|
     | PostL / PostR | 1.5, 15.2, 1.5 | (∓8.9, 7.6, 0) | WoodWarmShade | true |
     | Beam | 19.0, 0.8, 1.1 | (0, 13.0, 0) | WoodWarm | true |
     | Board | 9.0, 2.2, 0.3 | (0, 14.65, 0) | FabricCream | false |
     Attachments: `Light1` (4.1, −0.1, −0.9) and `Light2` (−4.1, −0.1, −0.9) under Beam; `SignFace` (0, 0, −0.16) under Board (= the art's model-space points).
   - Both modes: `model.Name = "LotGate"`.
     - Lights: for `Light1`, `Light2` (`FindFirstChild(name, true)`, must be an Attachment) → `MapWorld.nightLight(attachment, GameConfig.DayCycle.GateLight)`.
     - Sign: Part `SignBoard` size (9.0, 2.2, 0.1), `CFrame = signFace.WorldCFrame`, Transparency 1, Anchored, CanCollide/CanQuery/CanTouch false, parented to the model. SurfaceGui `SignFront` (Face Front, PixelsPerStud and MaxDistance from `UiTheme.LotGate`, LightInfluence 0, Adornee SignBoard). Frame `Frame` full size, BackgroundTransparency 1. TextLabel `Name`: Position/Size inset by `padding` px, BackgroundTransparency 1, Font `UiTheme.Fonts.Bold`, TextColor `UiTheme.Colors.DarkText`, TextScaled, TextWrapped false, TextTruncate AtEnd, AutoLocalize false, UITextSizeConstraint min/max from `UiTheme.LotGate`, attribute `LabelKind` "LotSignName", `NameSource` "Free", Text "Lot available".
     - `ctx.setCollisionGroup(model, ctx.group)`; parent to `plot`; return the model.
   - `LotGateWorld.nameLabel(plot: Model): TextLabel?` → `plot.LotGate.SignBoard.SignFront.Frame.Name`, nil when any link is missing or not a TextLabel.
3. **WorldService**:
   - `build()`: call `LotGateWorld.build(plot, ART_CTX)` right before `lotSign(plot)`.
   - `setLotSign`: after the face loop, `local plot = findPlot(plotId)`, `local gate = plot and LotGateWorld.nameLabel(plot)`. If set, copy from the `SignFront` Name label: `SetAttribute("NameSource")`, `SetAttribute("OwnerName")`, then `Text`. A missing gate never changes the return value.
   - No other WorldService change (keep the file's growth ≤ 15 lines).

## Tests (headless)
Expected count: 732 → **736**.
| File | Test | Asserts |
|---|---|---|
| LotArt_Test | "places the gate on the road edge facing the road" | `gatePose()` = (28, 28); for facing ±1, `-cos(roadYaw(f)) * f == 1` (front to the road), `sin` ≈ 0 |
| LotArt_Test | "keeps the gate posts 2 studs clear of cars, truck and walk lines" | each `gatePostBoxes()` box: minZ ≥ `LotHalfDepth`; box-to-box distance ≥ 2 to parking spaces 1-4 (centre x `ParkingFirstX + ParkingStep(i−1)`, z `ParkingDepth`, 8 × 12), car corridor x −28..16 z 13..59, truck lane x 43..49 z −26..66, KeepClear `Sign`, `Spawn`, every decor `pieceBox`, and each walk line door(i)→aisle(i) as a zero-width box |
| LotArt_Test | "chooses the gate art or the fallback" | fake root with `Props/LotGate` → mode Art; without → Primitive, `MissingArtAsset` |
| LotArt_Test | "sizes fence pieces to the v3 post" | `PIECE_HALF` 0.45; a Post pieceBox is 0.9 × 0.9; a Rail pieceBox spans 8.4 along the run |
- "lays the lot fence inside the fence boxes": tolerance 0.3 → **0.35** (0.9 post on a 0.3 box hits 0.3 exactly).
- GameConfig_Test "lot sign clears the decorative fences": `#DecorFences` 2 → **1**.

## Playtest (Studio, via playtester)
Smoke plus these steps (full run only at the end of the hasseln run). PC-13: all reads are server-side.
1. `runPlaytest` with steps 37, 40, 41, 42, 56, 59, 61, 66.
2. **66 LOT_ART** extend with (g) on all 6 plots: `LotGate` Model, `LotArtMode` "Art"; pivot at lot (28, 28) within 0.1 (`ATTACHMENT_TOLERANCE`), pivot y within 0.1 of `groundTop − LotArt.FENCE_BASE_DROP`, `expectFacing`; `Light1` and `Light2` each hold exactly 1 Light tagged `NightLight`; the gate `Name` label's `NameSource` and Text equal the `LotSign` SignFront Name label's. Summary adds `gates %d`. Update the header comment.
3. **61 NIGHT_LIGHTS**: `local GATE_LIGHTS = 6 * 2`; expected `LAMP_COUNT + PLOT_LIGHTS + GATE_LIGHTS` = 46, all off; header comment updated.
4. 37, 40 → 0 snaps; 41, 42 (1 DecorFence per plot, clear of the sign), 56, 59 PASS. No `[ART]` warning for `Props/LotGate`.

## Acceptance
- `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` → 736/736, `rojo build` both projects.
- Gate per plot at lot (28, 28), front to the road (yaw 180° plots 1-3, 0° plots 4-6), art with Part fallback; sign mirrors the lot sign's name; 2 PointLights per gate (range 12, brightness 1.2) tagged and off on the server; constants 0.45 / 4.45 / 3.95.
- Studio steps above PASS.
- Docs: MODEL_INTEGRATION "Lot gate and fence": replace the "For GATEW" line by "World (CM2-GATEW)": pivot, offset, clearances, lights, dropped decor fence. DECISION_LOG: one entry, placement reasons and both backlog deviations.

## Out of scope
- Moving lot sign, parking or NPC routes. Client visuals (lights glow at night, sign readable from the road) go to "Studio-Test ausstehend" while PC-13 blocks.

# CM2-AP — Asset pipeline for Blender MeshParts (re-scoped CM2-R2)

Written by: `planner` (Opus 5.5, high). Implemented by: the agent for the tier below. Playtested by: `playtester` (Sonnet 5.5, medium). Reviewed and committed by: `reviewer` (Opus 5.5, medium). Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
A repeatable path from a `.blend` file to a normalized `.rbxm` that Rojo maps into `ReplicatedStorage.ArtAssets` in both project files. MODEL tasks (CM2-12/13/14/10) deliver art through it, missing or broken art is detected headlessly and in Studio, and the primitive fallback stays. This task ships no art. It ships the tooling, tests and a generated probe fixture.

## Source of truth
PRODUCT_SPEC 2026-11-21 "Art" (Blender MeshParts for larger models, Parts only for small items, CC0 removed); `docs/MODEL_INTEGRATION.md` (hierarchy, pivots, attachments, `MissingArtAsset`); `docs/art/quality-reference/README.md` (tiers A/B); DECISION_LOG 2026-11-21 (CC0 precedent, launch order re-scoping R2), 2026-11-22 (art quality references, CM2-G20 release project); backlog "MODEL tasks" line 1 and the original CM2-R2 line.

## Implementer tier
Tier: M. Reason: new tooling across Lune, Python (Blender), Rojo projects, CI, `WorldService` and the Studio playtest, with non-trivial geometry logic; no save schema, money, inventory or remote change.

## Skills to load
roblox-collaboration-mode, roblox-tooling, roblox-cloud, roblox-building, roblox-security, roblox-performance, roblox-architecture, roblox-luau-core, roblox-luau-patterns, roblox-luau-types, roblox-studio-mcp.

## Decisions (settled)
| Topic | Decision |
|---|---|
| Source of truth | The `.blend` file is the art source (committed, saved with Blender "Compress"). The normalized `.rbxm` is the build input (committed). FBX exports and raw downloads are generated, gitignored and never committed. |
| Why not FBX → Rojo directly | Rojo cannot import meshes. A MeshPart needs an uploaded `MeshId` plus engine-made `InitialSize` and physics data. Rojo-only MeshParts are malformed. |
| Why not EditableMesh at runtime | It does not replicate from server-created parts, it has memory budgets, and publishing needs an ID-verified creator. Rejected. |
| Mesh upload (primary path) | Open Cloud Assets API: upload the FBX as asset type `Model` under the experience's creator, poll the Operation, then download the processed model through the Asset Delivery API. Roblox's importer makes complete MeshParts. Lune normalizes them headlessly. Needs the owner's API key (PC-2 below). |
| Mesh upload (fallback, no key) | The owner imports `model.fbx` with the Studio 3D Importer and saves it as `raw.rbxm` (steps in `assets/art/README.md`). Then `normalize --raw` runs the same normalizer. Use this only while PC-2 is open and a MODEL task needs a mesh in Studio. |
| Without the key | Every code path, test and CI step still works. `upload` exits with code 2 (`ART_NO_API_KEY`). Modelers review with Blender renders (`render`), which need no upload. |
| Blender | Installed on this PC: **Blender 5.2.2 LTS**, `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` (FBX and glTF exporters present, checked headless 2026-11-22). The path can be overridden with the env var `CM2_BLENDER`. If it is missing, exit 1 with `ART_BLENDER_MISSING` and the hint `winget install BlenderFoundation.Blender`. CI has no Blender, so the Blender test is reported as SKIP. |
| Export format | FBX (`model/fbx`), the longest-supported format of the Roblox importer. |
| Layout | `assets/art/source/<artPath>/model.blend` + `asset.json`; `assets/art/rbxm/<artPath>.rbxm`; `assets/art/_build/<artPath>/` (ignored: `model.fbx`, `report.json`, `raw.rbxm`, `preview_*.png`). `artPath` = path under ArtAssets, e.g. `Trees/DouglasFir/Medium`, `Buildings/MarketStarter`. |
| Rojo | `default.project.json` → `ReplicatedStorage.ArtAssets = { "$path": "assets/art/rbxm", "$ignoreUnknownInstances": true }`. `release.project.json` → `{ "$path": "assets/art/rbxm" }`. Category folders `Trees Buildings Props Vehicles NPCs Environment` each hold `init.meta.json` = `{ "ignoreUnknownInstances": true }` (keeps empty folders in git). Checked with Rojo 7.7.1: an `.rbxm` becomes a child named after its file, unknown file types are ignored, and a meta-only folder builds as a Folder. |
| Studio-only CC0 coexistence | Through the ignore flags, `rojo serve` keeps the owner's Studio-only CC0 models until CM2-44. A MODEL task that ships an `.rbxm` under the same path as a Studio-only CC0 model deletes the Studio copy (the one without `ArtSource`) in the same task. Duplicates make the `ART_ASSETS` playtest step fail. |
| IDs | `AssetCatalog` IDs stay unchanged. The leaf of `artPath` is the instance name and `ArtAssetId`. Config IDs are never derived from file names (MODEL_INTEGRATION). Valid path: 1–4 segments, each `^%u%w*$`. |
| Pivot (stable) | Blender origin = ground pivot: the footprint centre at ground level, the front facing Blender −Y, 1 Blender unit = 1 stud. The normalized model gets `PrimaryPart` = `ArtRoot`: a Part of size 0.05³ at `CFrame.identity`, Transparency 1, CanCollide/CanQuery/CanTouch false, Anchored. Pivot = `ArtRoot.CFrame`. `WorldPivot` is not used, because Lune 0.11 cannot round-trip it (checked). |
| Axes | Report coordinates are in Roblox axes: `Xr = −Xb, Yr = Zb, Zr = Yb` (the front faces −Z). The normalizer does not trust the importer's axis or unit handling. It derives scale and yaw from the report (Step 4). |
| Colour | Blender mesh object name `<PartName>__<PaletteKey>`. Colour and material come from `src/shared/ArtPalette.lua`. No textures and no SurfaceAppearance. Flat shading is forced on export. |
| Collision | Mesh objects `COL_<Name>` (unrotated boxes) become invisible `Collider_<Name>` Parts. If any collider exists, MeshParts get CanCollide false. Otherwise MeshParts get CanCollide true. MeshParts always use `CollisionFidelity.Box`. |
| Attachments | Empties `ATT_<Name>` become Attachments under `ArtRoot`. `Trees/*` always requires `TreeBase`. Other required attachments are listed per asset in `asset.json`. |
| Budgets (PROVISIONAL, engineering) | Tier A: ≤ 4000 triangles, ≤ 10 MeshParts. Tier B: ≤ 1000 triangles, ≤ 4 MeshParts. `asset.json` may lower these values but never raise them. |

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/ArtPalette.lua` | New | Pure palette data (`rgb` triples, `material` names), usable from Lune and the game |
| `src/shared/ArtLibrary.lua` | New | `isValidPath`, `find`, `prepareClone` |
| `src/server/Services/WorldService.lua` | Change | Use `ArtLibrary`; warn once per missing path |
| `tools/art/art.luau` | New | CLI: `doctor export render upload normalize build verify probe` |
| `tools/art/lib/{Config,Paths,AssetSpec,Normalize,Verify,OpenCloud,Blender}.luau` | New | CLI modules (pure where testable) |
| `tools/art/blender_export.py`, `blender_render.py`, `make_probe.py` | New | Headless Blender scripts |
| `tests/tools/art_pipeline.luau` | New | Lune pipeline tests (20: N1–N11, V1–V3, O1–O3, S1, R1, B1) |
| `tests/fixtures/art/source/Props/ArtPipelineProbe/asset.json` | New | Probe spec (tier B); its `.blend` is generated |
| `tests/studio/Cases/ArtLibrary_Test.lua` | New | 5 cases (Studio + headless) |
| `tests/studio/Playtest/RunPlaytest.lua` | Change | Step `21 ART_ASSETS`; unit threshold 147 |
| `tests/headless/run.luau` | Change | Add `ArtLibrary`, `ArtPalette` to `sourcePaths` |
| `assets/art/README.md`, `assets/art/rbxm/<6 categories>/init.meta.json` | New | How-to; folders |
| `default.project.json`, `release.project.json` | Change | `ArtAssets` node (table above) |
| `.gitignore`, `.gitattributes` | Change | Ignore `assets/art/_build/`, `tests/fixtures/art/_build/`, `tests/fixtures/art/rbxm/`, `tests/fixtures/art/source/**/*.blend`, `*.blend1`; add `*.blend binary` |
| `.github/workflows/quality.yml` | Change | `stylua --check src tests tools`, `selene src tests tools`; after the release build run `lune run tests/tools/art_pipeline.luau` and `lune run tools/art/art.luau verify release.rbxlx` |
| `docs/MODEL_INTEGRATION.md`, `docs/TEST_PLAN.md`, `docs/TECHNICAL_ARCHITECTURE.md` (§1, §9), `docs/DECISION_LOG.md` | Change | Short sections, listed in Step 10 |

## Data and config
**`ArtPalette` (PROVISIONAL, our palette; MODEL tasks may add keys, never change existing values without a DECISION_LOG entry):** `NeedleGreen 46,107,69` · `NeedleGreenShade 28,74,50` · `NeedleFrost 196,222,214` · `BarkBrown 110,72,45` · `BarkBrownShade 78,50,32` · `WoodWarm 168,112,66` · `WoodWarmShade 122,78,44` · `RoofRed 170,46,46` · `RoofRedShade 122,32,36` · `SnowWhite 240,244,248` · `SnowShade 206,218,230` · `StoneGray 132,138,146` · `StoneGrayShade 96,102,112` · `MetalDark 52,58,64` · `FabricCream 232,220,196` · `GoldAccent 214,170,72` (material `SmoothPlastic` for all) · `LightWarm 255,214,140` (material `Neon`). Shape: `{ [key]: { rgb = {r,g,b}, material = "SmoothPlastic" } }`, `--!strict`, no Roblox globals.

**`asset.json` (schemaVersion 1):** `{ schemaVersion: 1, artPath, displayName, tier: "A"|"B", version: int ≥ 1, maxTriangles?, maxMeshParts?, requiredAttachments: [string], upload: { modelAssetId: string|null, sourceSha256: string|null, uploadedAt: string|null } }`. Any violation → `ART_BAD_SPEC <field>`.

**`report.json` (written by `blender_export.py`, schemaVersion 1, Roblox axes, studs):** `{ schemaVersion, blenderVersion, size:[x,y,z], bboxMin, bboxMax, triangles, objects:[{name, center, size, triangles}], attachments:{Name:[x,y,z]}, colliders:[{name, center, size}] }`.

**`tools/art/lib/Config.luau`:** `ASSETS_URL "https://apis.roblox.com/assets/v1/assets"`, `OPERATIONS_URL "https://apis.roblox.com/assets/v1/operations/"`, `DELIVERY_URL "https://apis.roblox.com/asset-delivery-api/v1/assetId/"`, `POLL_SECONDS 2`, `MAX_POLLS 60`, `RATE_LIMIT_WAIT 10`, `MAX_RATE_RETRIES 3`, `DOWNLOAD_RETRIES 5`, `DOWNLOAD_WAIT 5`, `IMPORT_YAW_DEGREES 0`, `MATCH_ABS 0.02`, `MATCH_REL 0.01`, `ART_ROOT_SIZE 0.05`, `BUDGET = { A = {4000, 10}, B = {1000, 4} }`, `DEFAULT_BLENDER`, the path above. The endpoints follow the Open Cloud reference as known at planning. The first real `probe` run verifies them (After PC-2).

**Env (owner, never committed or printed):** `ROBLOX_OPEN_CLOUD_API_KEY`, `CM2_ART_CREATOR` = `user:<id>` or `group:<id>`. `CM2_BLENDER` is optional.

## Steps
1. **ArtLibrary** (`src/shared/ArtLibrary.lua`, `--!strict`)
   - `isValidPath(path: string): boolean` follows the path rule above.
   - `find(root: Instance?, artPath: string): (Model?, string?)` returns:
     - `nil, "InvalidArtPath"` for an invalid path;
     - `nil, "MissingArtAsset"` if the root or any segment is missing (`FindFirstChild`);
     - `nil, "InvalidArtAsset"` if the leaf is not a Model, or if `GetAttribute("ArtSource") == "blender"` and the leaf has no `PrimaryPart`.
     - Legacy CC0 Models without a PrimaryPart stay accepted.
   - `prepareClone(template: Model): Model`:
     - clones the template and anchors every BasePart;
     - sets `CanCollide = true` only when `ArtSource ~= "blender"` (today's behaviour), so Blender art keeps its authored collision;
     - sets the `ArtAssetId` attribute to `template.Name`.
2. **WorldService**
   - `salesStand` uses `find(ArtAssets, "Buildings/" .. assetId)`.
   - `cloneArt` uses `find(ArtAssets, category .. "/" .. assetId)`.
   - On failure, `reportMissing(artPath, code)` warns once per path per server with `[ART] <code> <artPath>` (a module-level set). Then it takes the existing fallback: `tent(...)` or `nil`.
   - On success it calls `prepareClone`, then keeps the existing name, parent and bounding-box grounding code unchanged.
3. **blender_export.py**
   - Invocation: `blender -b --factory-startup <blend> --python tools/art/blender_export.py -- --fbx <path> --report <path>`.
   - Name checks: a mesh named neither `^[A-Z][A-Za-z0-9]*__[A-Z][A-Za-z0-9]*$` nor `^COL_[A-Z][A-Za-z0-9]*$` → exit 3 (`ART_BAD_NAME <name>`). A collider with non-zero rotation → exit 4 (`ART_BAD_COLLIDER`). No export mesh → exit 5 (`ART_NO_MESH`).
   - Before export, for each export mesh: set `obj.data.name = obj.name` and call `obj.data.shade_flat()`.
   - FBX export settings: `use_selection=True` (export meshes only), `object_types={'MESH'}`, `use_mesh_modifiers=True`, `mesh_smooth_type='FACE'`, `apply_unit_scale=True`, `global_scale=1.0`, `axis_forward='-Z'`, `axis_up='Y'`, `path_mode='STRIP'`, `embed_textures=False`, `add_leaf_bones=False`, `bake_anim=False`.
   - The report is computed from the evaluated depsgraph. Triangles per polygon = vertices − 2.
4. **Normalize** (`lib/Normalize.luau`)
   - Signature: `normalize(raw: {Instance}, report, spec, palette, importYaw: number): (Instance?, string?, string?)` returns the model, or `nil, code, detail`.
   - Order of operations:
     1. Any `Script`, `LocalScript` or `ModuleScript` → `ART_SCRIPT_FOUND`.
     2. Collect all MeshPart descendants. Discard everything else: `SurfaceAppearance`, `Decal`, `Texture`, wrappers.
     3. Match each MeshPart by `Name` to a report object. A MeshPart with no report object → `ART_UNKNOWN_PART`. A report object with no MeshPart → `ART_MISSING_PART`. A palette key that does not exist → `ART_UNKNOWN_PALETTE`.
     4. Budget: `report.triangles` and the MeshPart count against `spec` or the tier defaults → `ART_BUDGET <detail>`.
     5. Scale: `k = report.size.Y / rawBBox.size.Y` (bounding box from the 8 corners of each part). Yaw: try the candidates `importYaw`, then 0, 90, 180, 270 (no duplicates). For each candidate θ, map each part's centre with `p' = Rθ·(p − rawCentre)·k + reportCentre` and its rotated extents with `·k`. A candidate matches when every centre and size is within `max(MATCH_ABS, MATCH_REL·maxExtent)`. Use the first match. No match → `ART_AXIS_MISMATCH`.
     6. Build a fresh `Model` named after the leaf:
        - `ArtRoot` as specified in the Pivot row; it is the `PrimaryPart`.
        - The MeshParts re-parented, renamed to `PartName`, with `CFrame = CFrame.new(p')·Rθ·rawRotation` and `Size = raw.Size·k`. Colour and material come from the palette; also set `TextureContent = Content.none`, `Anchored`, `CastShadow`, `CollisionFidelity.Box`, and `CanCollide` per the Collision row.
        - Colliders (Transparency 1, CanCollide true, CanQuery false, CanTouch false, Anchored).
        - Attachments. A required attachment that is missing → `ART_MISSING_ATTACHMENT <name>`.
        - Attributes `ArtAssetId`, `ArtPath`, `ArtSource = "blender"`, `ArtVersion = spec.version`, `ArtTier`.
   - Also return the detected θ and k. The CLI prints `[ART] normalized <artPath> yaw <θ> scale <k>`.
5. **Verify** (`lib/Verify.luau`)
   - `verifyPlace(game, entries): {failures}` checks each entry whose `.rbxm` exists:
     - the instance exists at `ReplicatedStorage.ArtAssets/<artPath>` and is a Model (`MissingArtAsset`);
     - its `PrimaryPart` is `ArtRoot` at identity within 1e-4 (`ART_BAD_PIVOT`);
     - the attributes match, with `ArtVersion` equal to `spec.version` (`ART_VERSION_MISMATCH`);
     - it has at least one MeshPart, and every `MeshContent.Uri` matches `^rbxassetid://%d+$` (`ART_BAD_MESH`);
     - it has no scripts (`ART_SCRIPT_FOUND`) and has its required attachments.
   - Read only `ClassName`, `Name`, `MeshContent`, `Size`, `CFrame`, `PrimaryPart` and attributes. Lune 0.11 fails reading `TextureID`, `WorldPivot` and `CollisionFidelity` after deserialize (checked).
   - `verifyFiles(rbxmPaths, specPaths)` flags an `.rbxm` without an `asset.json` as `ART_ORPHAN_RBXM`. An `asset.json` without an `.rbxm` counts as pending.
   - The CLI prints `[ART] <n> integrated, <m> pending, <f> failed` and exits 1 if f > 0.
6. **OpenCloud** (`lib/OpenCloud.luau`; HTTP and sleep are injected as `deps = {request, sleep}` so tests can fake them)
   - **Upload:** POST `multipart/form-data` (boundary `cm2art` + 16 hex) with two parts:
     - `request` = JSON `{assetType:"Model", displayName, description:"Christmas Tree Village art: <artPath>", creationContext:{creator:{userId|groupId}}}`;
     - `fileContent` (filename `model.fbx`, `Content-Type: model/fbx`).
   - Header `x-api-key`.
   - Error handling:
     - 429 → wait `RATE_LIMIT_WAIT` (or `Retry-After`) and retry, at most `MAX_RATE_RETRIES` times.
     - Any other non-200 → `ART_UPLOAD_FAILED <status> <body ≤200 chars>`.
     - A transport error with no status → `ART_UPLOAD_AMBIGUOUS` with no retry (check the Creator Dashboard).
   - **Poll** `OPERATIONS_URL..id` every `POLL_SECONDS`, at most `MAX_POLLS` times (`ART_UPLOAD_TIMEOUT`). When done, `response.assetId` is the result; an operation error → `ART_UPLOAD_FAILED`.
   - **Download:** GET `DELIVERY_URL..assetId` with the key, read the JSON `location`, then GET the location. Retry up to `DOWNLOAD_RETRIES` times every `DOWNLOAD_WAIT` seconds, then `ART_DOWNLOAD_FAILED`.
   - The key never appears in output, errors or files.
7. **CLI** (`tools/art/art.luau`; every command takes `--root <dir>`, default `assets/art`)
   - `doctor`: prints the Blender path and version, `API key: set|missing` and the creator. Exits 0 if all are OK, 2 if only the key or creator is missing, 1 if Blender is missing.
   - `export <artPath>`: runs Blender (Step 3).
   - `render <artPath>`: `blender_render.py` with the Workbench engine, 1024², object colours from the palette by name suffix. Writes `preview_front.png` (camera on −Y looking +Y) and `preview_34.png` (camera at azimuth 45°, elevation 25°).
   - `upload <artPath> [--force]`: computes `sha256` (`serde.hash`) of `model.blend`.
     - Same SHA and a recorded `modelAssetId`: re-download only.
     - Otherwise, or with `--force`: upload, then `version += 1` and write the `upload` fields.
     - No env → exit 2 with `ART_NO_API_KEY: set ROBLOX_OPEN_CLOUD_API_KEY and CM2_ART_CREATOR (CLAUDE_BACKLOG PC-2)`.
   - `normalize <artPath> [--raw <file>]`: the default raw file is `_build/<artPath>/raw.rbxm`.
   - `build <artPath>`: export, upload, normalize.
   - `verify <placeFile>`.
   - `probe`: runs `make_probe.py` into `tests/fixtures/art`, then `build`, and prints `[ART] probe OK yaw <θ> scale <k> asset <id>`.
8. **make_probe.py**
   - Builds, in an empty scene:
     - `Body__WoodWarm`: a cube 4×4×3 (X, Y, Z) at (0, 0, 1.5);
     - `Nose__RoofRed`: a 1³ cube at (0, −2.5, 1.5);
     - `Top__SnowWhite`: 2×2×0.5 at (1, 0, 3.25), off-centre so mirroring is detectable;
     - Empty `ATT_Front` at (0, −3, 0);
     - `COL_Body` 4×4×3 at (0, 0, 1.5).
   - Saves the scene to `<root>/source/Props/ArtPipelineProbe/model.blend`.
   - The probe's `asset.json` sets `requiredAttachments ["Front"]`.
9. **RunPlaytest**
   - Insert `addStep("21", "ART_ASSETS", {}, …)` and renumber `LEAK_CHECK` to 22 and `CLEANUP` to 23. Raise the unit threshold to `>= 147`.
   - The step body:
     - `ReplicatedStorage.ArtAssets` must exist.
     - Duplicate child names under any Folder in it → FAIL.
     - For each Model with `ArtSource == "blender"`, `ContentProvider:PreloadAsync(meshParts, cb)`. Any status other than `Enum.AssetFetchStatus.Success` → FAIL listing `<contentId> <status>`.
     - Return `"%d blender models, %d meshes, 0 failed, 0 duplicates"`.
10. **Docs**
    - `assets/art/README.md` (≤ 80 lines): the Blender rules (origin, axes, units, names, `COL_`, `ATT_`, palette keys, flat shading, budgets), the commands, the Studio-import fallback (Home → Import 3D → `_build/<artPath>/model.fbx` → defaults → Import → right-click the model → Save to File → `_build/<artPath>/raw.rbxm` → `normalize`), the CC0 coexistence rule, the asset-privacy note (an invisible mesh usually means a missing experience grant in the Creator Dashboard).
    - MODEL_INTEGRATION: a 10-line "Asset pipeline (CM2-AP)" pointer.
    - TEST_PLAN: §1 G0 adds `tools` and the two art commands; §3b now has 23 steps including `ART_ASSETS`.
    - TECHNICAL_ARCHITECTURE: §1 tree gains `assets/art/` and `tools/art/`; §9 gets one line on the pipeline.
    - DECISION_LOG: entry "2026-11-22 - Asset pipeline for Blender MeshParts, CM2-AP (engineering)" with old rule → new rule and the decisions table in short.

## Tests (headless)
| File | Test | Asserts |
|---|---|---|
| `ArtLibrary_Test` (fake nodes with `FindFirstChild`, `IsA`, `GetAttribute`, `PrimaryPart`) | finds nested path · MissingArtAsset (nil root, missing leaf) · InvalidArtAsset (non-Model; blender Model without PrimaryPart; legacy Model without PrimaryPart accepted) · rejects `"" "trees/x" "A//B" "../X"` · every `AssetCatalog` category/ID path is valid | return values and codes |
| `art_pipeline.luau` N1–N10 | identity import · yaw 180 + scale 0.5 + offset · yaw 90 · mirrored → `ART_AXIS_MISMATCH` · `ART_UNKNOWN_PALETTE` · `ART_UNKNOWN_PART`/`ART_MISSING_PART` · `ART_SCRIPT_FOUND` + SurfaceAppearance stripped · `ART_BUDGET` (triangles, parts) · colliders on/off → CanCollide rule · attachments + `ART_MISSING_ATTACHMENT` (and `Trees/*` without TreeBase) | ArtRoot identity, names, palette colour/material, sizes and centres within tolerance, attributes |
| N11 | serialize → deserialize round-trip of the N1 model | `verifyPlace` passes on a DataModel holding it |
| V1–V3 | `MissingArtAsset` · `ART_BAD_MESH` (empty `MeshContent`) · `ART_VERSION_MISMATCH` · `ART_ORPHAN_RBXM` | failure lists |
| O1–O3 (fake deps) | upload → poll → assetId "123"; body has `"assetType":"Model"` and `model/fbx`; key absent from all output · 401 → `ART_UPLOAD_FAILED`; 429×3 then 200 succeeds; 60 polls → `ART_UPLOAD_TIMEOUT`; op error · download location → bytes; 5×404 → `ART_DOWNLOAD_FAILED` | results and codes |
| S1 | `ART_BAD_SPEC` for a bad schemaVersion, tier or path | code and field |
| R1 | real `rojo build` of a temp project under `tests/fixtures/art/_build/rojo/` mapping the N1 `.rbxm` | `verifyPlace` passes on the built place |
| B1 (SKIP without Blender) | `make_probe` + `export` | report has 3 objects, 36 triangles, attachment `Front`, size ≈ (4, 3.5, 5) |

The summary line `[ART-TEST] SUMMARY 20 run, 20 passed, 0 failed, 0 skipped` on this PC; CI (no Blender) shows `20 run, 19 passed, 0 failed, 1 skipped`. A failure exits 1; a SKIP does not.

## Playtest (Studio, via playtester)
1. `rojo build` both projects. `lune run tools/art/art.luau verify release.rbxlx` → `[ART] 0 integrated, 0 pending, 0 failed`, exit 0.
2. Serve `default.project.json` into Studio. Record the child count of each `ArtAssets` category before and after the sync: Studio-only CC0 models must survive, and the six folders must exist.
3. Play, then `runPlaytest {mode="full"}` → 23/23 PASS. `ART_ASSETS` detail: `0 blender models, 0 meshes, 0 failed, 0 duplicates`.
4. Output shows at most one `[ART] MissingArtAsset <path>` per path. Each plot still has `StarterSalesTent` (CC0 or primitive fallback).

## Acceptance
- Checks: `stylua --check src tests tools`, `selene src tests tools`, `lune run tests/headless/run.luau` → **147** run, 0 failed, `lune run tests/tools/art_pipeline.luau` → 20 run, 0 failed (CI: 19 passed, 1 skipped), `rojo build default.project.json` and `release.project.json`, `art.luau verify release.rbxlx` exit 0.
- Both builds contain `ReplicatedStorage.ArtAssets` with the six folders. A normalized `.rbxm` placed in `assets/art/rbxm/` appears at its path (R1).
- The `AssetCatalog` IDs are unchanged. The pivot convention (`ArtRoot` at identity on the ground pivot) is enforced by `verify`. The primitive fallback still works when art is missing.
- `art.luau doctor` on this PC finds Blender 5.2.2. `upload` without the env exits 2 with `ART_NO_API_KEY`.

## Owner input PC-2 (planner adds it to "Für den Owner am PC"; not blocking CM2-AP)
- Status: offen · Art: zugriff · Problem: uploading meshes needs an Open Cloud API key under the creator that will own the experience.
- Steps:
  1. create.roblox.com → Dashboard. Pick the creator that will own the game (your account, or the group if the game will be group-owned).
  2. Open Cloud → API Keys → Create API Key, name "CM2 art pipeline":
     - add the "Assets" API with `asset:read` and `asset:write`, plus the "Legacy Assets" API (Asset Delivery) with `legacy-asset:manage`;
     - Accepted IP addresses: your IP, or `0.0.0.0/0`;
     - Expiration: 2027-02-01.
  3. In PowerShell: `setx ROBLOX_OPEN_CLOUD_API_KEY "<key>"` and `setx CM2_ART_CREATOR "user:<your user ID>"` (or `"group:<group ID>"`). Restart Claude Code. Never paste the key into chat or the repo.
  4. Alternative without a key: for each MODEL asset, do the Studio import from `assets/art/README.md`.
- Check: `lune run tools/art/art.luau doctor` exits 0.
- Blocked: mesh integration of CM2-12/13/14/10 (their modeling and Blender renders continue).
- Afterwards: `art.luau probe`. If the detected yaw is not 0, set `IMPORT_YAW_DEGREES` to it in the next MODEL commit. Then the next MODEL task.

## After PC-2 (first step of the next MODEL task)
Run `probe`.
- Any HTTP 4xx/404 on the endpoints → stop and report the status and body; the planner amends Config.
- If the probe passes, check one probe MeshPart in Studio: insert it via the MCP in Edit mode, look at the `PreloadAsync` status, then delete it.

## Out of scope
- Any real art model, and removing the CC0 imports (CM2-44).
- Changing WorldService placement to use the pivot instead of the bounding box.
- Trees in `AssetCatalog` (CM2-12).
- LOD and streaming.
- Uploading anything before PC-2.

## Amendment 2026-11-22 (planner, after the implementer's report)
**Test count:** the table lists 20 tests (N1–N11, V1–V3, O1–O3, S1, R1, B1), and the implementation has all 20. The count is **20** everywhere (Files, Tests, Acceptance). On this PC: 20 run, 20 passed. CI without Blender: 20 run, 19 passed, 1 skipped (B1).

**Gaps filled by the implementer. All are confirmed and now part of this plan:**
| Topic | Confirmed rule (supersedes the step text where they differ) |
|---|---|
| Step 4 return | `normalize(...)` returns `(Instance?, string?, string?, {yaw: number, scale: number}?)`. On success: `model, nil, nil, {yaw = θ, scale = k}`. On failure: `nil, code, detail`. |
| Step 5 attributes | An `ArtVersion` mismatch → `ART_VERSION_MISMATCH`. A mismatch of any other checked attribute (`ArtAssetId`, `ArtPath`, `ArtSource`, `ArtTier`) → `ART_BAD_ATTRIBUTE <name>`. |
| Step 6 poll | A transport error (no response) during a poll is not fatal: it counts as one of the `MAX_POLLS` attempts and polling continues. A poll with a status other than 200 → `ART_UPLOAD_FAILED <status> <body ≤200>`, with no retry. |
| Step 6 download | `DOWNLOAD_RETRIES` = 5 **attempts in total**, with `DOWNLOAD_WAIT` seconds of sleep between attempts (none after the last). Then `ART_DOWNLOAD_FAILED asset <id>, last status <s>`. |
| Step 7 upload env | `upload` checks the env before it reads `asset.json`. A `CM2_ART_CREATOR` that does not match `^(user|group):%d+$` counts as missing → exit 2 `ART_NO_API_KEY`. |
| Step 7 CLI codes | These codes are also confirmed, each printed by the CLI and exiting 1: `ART_BAD_PATH`, `ART_BAD_SPEC file`, `ART_BAD_SPEC json`, `ART_NO_BLEND`, `ART_NO_FBX`, `ART_NO_RAW`, `ART_NO_REPORT`, `ART_BAD_REPORT`, `ART_BAD_RAW`, `ART_NO_PLACE`, `ART_BAD_PLACE`. |
| Step 7 render | The CLI passes the palette as `--colors Key=r,g,b ...` (0–255) to `blender_render.py`. Unknown keys use the script's fallback colour. |
| Lune reads | `Normalize` and the tests read `part.CFrame.Position`, never `part.Position`: `Position` cannot be read on a Lune MeshPart. Step 5's list of readable properties is unchanged. |
| Probe fixture | `tests/fixtures/art/source/Props/ArtPipelineProbe/asset.json` is committed with `version 1` and null `upload` fields. The first real `probe` run after PC-2 bumps `version` and fills `upload`. Commit that change in the first commit of the next MODEL task, together with the verified asset ID in PROGRESS.md. |

**Decision on poll 429 (not changed):** a 429 during a poll also aborts with `ART_UPLOAD_FAILED 429`. A rerun uploads again and leaves at most one unused private asset. No money is involved, so this is accepted.

**Code change:** none. The reviewer checks the confirmed behaviour against the existing O1–O3, N1, V1–V3 and S1 tests.

**Line endings (reviewer, before staging docs):** `.gitattributes` has no eol rule for text and `core.autocrlf=true`, so every text file is stored as LF in the index (`i/lf`) and checked out as CRLF. Rule: the whole working-tree file uses CRLF, and git stores LF. For `docs/MODEL_INTEGRATION.md`, and for any other staged doc that `git ls-files --eol` shows as `w/mixed` (currently `docs/PROGRESS.md`), run:
`unix2dos <file>` (Git Bash, unix2dos 7.5.6 is installed). Then `git add` it. Check: `git ls-files --eol <file>` shows `i/lf w/crlf`, `git diff --cached --check` reports nothing, and `git diff --cached --stat docs/MODEL_INTEGRATION.md` shows only the added pointer lines (≈ 8), not a whole-file rewrite. At planning time, `docs/MODEL_INTEGRATION.md` was already all CRLF (49 CRLF lines, 0 LF-only lines). Do not add eol rules to `.gitattributes` in this task.

# CM2-UVF2 — World labels do not overlap

Written by: `planner` (Opus 5.5, high). Implemented by: the tier's agent. Playtested by: `playtester`. Reviewed and committed by: `reviewer`. Pipeline: skill `cm2-task`.
Rule: everything is decided; if something is missing, the implementer stops and reports.

## Goal
Every world billboard is readable: no two shown labels overlap on screen; the pickup label is one line.

## Source of truth
- Backlog 5d; PROGRESS "CM2-UV UI verification" rows (i), (e)+(j): uv-i1, uv-i9, uv-e1, uv-e2.
- REFERENCE_GAME_LIVE_TEST §4 (OBSERVED): bay "Fraser Fir – 5 trees", a label per display tree, "Order #N – PICK UP", "#N HERE".
- PRODUCT_SPEC "UI look": `UiTheme` tokens only until CM2-UI.

## Implementer tier
Tier: S. Reason: client presentation, one pure shared module, layout tokens and two string keys; no save, money, inventory, remote or server rule change.

## Skills to load
roblox-collaboration-mode, roblox-gui, roblox-localization, roblox-performance, roblox-luau-core, roblox-luau-patterns, roblox-luau-types, roblox-architecture, roblox-tooling.

## Decisions (settled)
| # | Decision |
|---|---|
| D1 | Cause: `TextScaled` (wraps, uv-e2) in one 190x46 px box for all kinds; neighbours 4.5–6 studs apart overlap. Fix: fixed text size, per-kind boxes, pickup stagger, client declutter. |
| D2 | Declutter: the client hides (`Enabled = false`, local) a label whose screen box overlaps one with higher priority, or equal priority and nearer. Chosen over "one label per group": keeps the OBSERVED per-tree label (height, RESERVED) and holds at every camera. |
| D3 | Bay contents text becomes the OBSERVED short form "Douglas Fir · 6 trees" (key `bayContents`, `bayContentsOne` for 1). The size breakdown stays in the StockBay prompt (`promptStockObject`) and the stocking bar (`stockingHeader`). |
| D4 | Pickup labels: columns 0 and 2 sit 2 studs above columns 1 and 3 (this direction adds to the vertical gap at the H3 camera; the other cancels it). |
| D5 | Colours and font come from tokens: background `UiTheme.Colors.Panel` (was 24,74,50), text `Cream`, font `UiTheme.Fonts.Bold`, corner `UiTheme.CornerRadius.Button`. |
| D6 | Studio test batched (cm2-task step 3): labels are not world geometry; BUILD stays `cm2-n1-fix2`, unit check `>= 380` holds. |

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/UiTheme.lua` | Change | `UiTheme.WorldLabels` layout table |
| `src/shared/LabelDeclutter.lua` | New | pure priority and overlap resolution |
| `src/server/Services/WorldService.lua` | Change | `billboard` uses layouts; bay text; pickup stagger; speech |
| `src/client/WorldLabels.client.lua` | Change | new bay keys; declutter loop |
| `src/shared/Localization.lua` | Change | `bayContents`, `bayContentsOne` (en, de) |
| `tests/studio/Cases/LabelDeclutter_Test.lua` | New | 7 tests |
| `tests/studio/Cases/UiTheme_Test.lua` | Change | 1 test |
| `tests/headless/run.luau` | Change | `LabelDeclutter` in `sourcePaths` (alphabetical) |
| `docs/DECISION_LOG.md`, `docs/TEST_PLAN.md` | Change | entry, one sentence |

No other file changes (RunPlaytest, StockingMode, CustomerNpcWorld stay).

## Data and config
`UiTheme.WorldLabels` (all PROVISIONAL), inserted after `UiTheme.CompactWidth`; `w`, `h` px; `height` studs above the adornee; `stagger` studs; `textSize` from tokens:

| Layout | w | h | textSize | wrap | height | stagger | maxDistance |
|---|---|---|---|---|---|---|---|
| `Bay` | 200 | 28 | `TextSize.Small` (13) | false | 5 | 0 | 60 |
| `DisplayTree` | 220 | 44 | `TextSize.Small` (13) | true | 10 (times tree scale) | 0 | 40 |
| `CarNumber` | 130 | 30 | `TextSize.Chip` (16) | false | 6 | 0 | 60 |
| `PickupOrder` | 240 | 30 | `TextSize.Body` (15) | false | 9 | 2 | 60 |
| `Speech` | 170 | 30 | `TextSize.Body` (15) | false | 3 | 0 | 60 |

Type: `export type WorldLabelLayout = { w: number, h: number, textSize: number, wrap: boolean, height: number, stagger: number, maxDistance: number }`, table `{ [string]: WorldLabelLayout }`.

`LabelDeclutter` constants (PROVISIONAL): `IntervalSeconds = 0.1`, `ShownBias = 2` (studs), `Priority = { NpcThanks = 6, PickupOrder = 5, CarNumber = 5, BayArriving = 4, BayContents = 3, Reserved = 2, BayFree = 1, DisplayTree = 1 }` (frozen).

Strings: en `bayContents = "%s · %d trees"`, `bayContentsOne = "%s · 1 tree"`; de `bayContents = "%s · %d Bäume"`, `bayContentsOne = "%s · 1 Baum"`. Insert after `bayArriving`; no other key changes.

## Steps
1. **LabelDeclutter.lua** (`--!strict`, requires `UiTheme` from `Shared`):
   - `export type Entry = { box: UiTheme.Box, priority: number, depth: number, shown: boolean }`.
   - `LabelDeclutter.priorityFor(kind: unknown, reserved: boolean): number` → `Priority.Reserved` when `kind == "DisplayTree"` and `reserved`; else `Priority[kind]` for a string key; else 0.
   - `LabelDeclutter.resolve(entries: { Entry }): { boolean }` → same length. Order the indices by priority descending, then `depth - (shown and ShownBias or 0)` ascending, then index ascending. Walk it; accept an entry when `UiTheme.overlaps` is false against every accepted box; `[i] = accepted`.
2. **UiTheme.lua**: add the type and `UiTheme.WorldLabels` from the table (not frozen, like the other token tables).
3. **WorldService.lua** (require `UiTheme` from `Shared`):
   - `billboard(adornee: BasePart, kind: string, text: string, layoutId: string, height: number, attributes): TextLabel`. From `UiTheme.WorldLabels[layoutId]`: `gui.Size = UDim2.fromOffset(w, h)`, `StudsOffsetWorldSpace = (0, height, 0)`, `MaxDistance = maxDistance`, `AlwaysOnTop = false`. TextLabel: `TextScaled = false`, `TextSize = textSize`, `TextWrapped = wrap`, `TextTruncate = None`, colours, font and corner per D5, `BackgroundTransparency` 0.15. Comment names CM2-UVF2.
   - Call sites: bay `billboard(bay, "BayFree", "Free bay", "Bay", layout.height, …)`; display tree `"DisplayTree"`, height `layout.height * scale`; car `"CarNumber"`, `layout.height`; pickup `"PickupOrder"`, height `layout.height + (if column % 2 == 0 then layout.stagger else 0)` with the existing `column`; `speech` uses `"Speech"`, `layout.height`, and drops its `gui.Size` override (keeps `gui.Name = "Speech"`).
   - `syncReceiving` BayContents fallback: `string.format("%s · %d trees", name, total)`, or `name .. " · 1 tree"` when total is 1. The prompt `ObjectText` keeps `sizesText`.
4. **Localization.lua**: the four strings.
5. **WorldLabels.client.lua**:
   - BayContents → `UiKit.localizedFormat("bayContents", speciesName(…), total)` or `localizedFormat("bayContentsOne", speciesName(…))` when total is 1; total = CountSmall + CountMedium + CountLarge. Remove the unused `bayHeader`.
   - Registry `local labelGuis: { [BillboardGui]: boolean } = setmetatable({}, { __mode = "k" })`. In `visit`, for a TextLabel with `LabelKind` whose Parent is a BillboardGui: register it and set `Enabled = false` (hidden until the next pass: no flash on rebuild).
   - `RunService.RenderStepped` accumulator; every `LabelDeclutter.IntervalSeconds` run one pass: camera = `workspace.CurrentCamera`; per registered gui: drop it if not `IsDescendantOf(workspace)`; skip (leave as is) if its Adornee is not a BasePart or its `Text` child is missing; `point = Adornee.Position + StudsOffsetWorldSpace`; if `(point - camera.CFrame.Position).Magnitude > MaxDistance` or `WorldToViewportPoint(point).Z <= 0`, set `Enabled = true` and leave it out (the engine does not draw it); else add `{ box = { x = vp.X - Size.X.Offset / 2, y = vp.Y - Size.Y.Offset / 2, w = Size.X.Offset, h = Size.Y.Offset }, priority = priorityFor(kind, label:GetAttribute("Reserved") == true), depth = vp.Z, shown = gui.Enabled }`. Then `Enabled = resolve(entries)[i]` for each entry.
6. **Docs**: DECISION_LOG entry at the end `## 2026-11-22 — CM2-UVF2 world label layout (engineering)`: defects, D1–D5 one bullet each, CM2-UI restyles via `UiTheme.WorldLabels`, files, headless +8 = 397. TEST_PLAN section J: append "World labels: `LabelDeclutter_Test` and the `UiTheme_Test` world label case (CM2-UVF2)."

## Tests (headless)
| Test case file | Test name | Asserts |
|---|---|---|
| LabelDeclutter_Test | nearer label wins an overlap | 2 equal-priority overlapping boxes, depth 10/20 → {true, false} |
| LabelDeclutter_Test | higher priority wins although farther | PickupOrder depth 30 vs DisplayTree depth 10, overlapping → pickup true, tree false |
| LabelDeclutter_Test | labels that do not overlap all show | 3 disjoint boxes → all true |
| LabelDeclutter_Test | a hidden label does not block | A∩B, B∩C, not A∩C, depths 1/2/3 → {true, false, true} |
| LabelDeclutter_Test | a shown label keeps its place within the bias | shown at depth 11 vs new at 10 → shown wins; shown at 13 vs 10 → new wins |
| LabelDeclutter_Test | five stacked tree labels show one | 5 DisplayTree boxes offset 10 px, depths 5..9 → exactly index 1 true |
| LabelDeclutter_Test | priorityFor maps kinds | Reserved tree 2 > DisplayTree 1; BayArriving 4 > BayContents 3; `"Nope"` and `nil` → 0 |
| UiTheme_Test | world label layouts are complete | the 5 layouts exist; every field positive (stagger ≥ 0); `PickupOrder.wrap == false`; `CarNumber.wrap == false` |

Headless total: **397** (389 + 8).

## Playtest (Studio, via playtester; batch run)
Helpers from `docs/archive/plans/CM2-UV.md` (D1 BUILD `cm2-n1-fix2`, D4 clicks without `GetGuiInset`, D5, H, H3). New:
- **H6 labelProbe()** (Client), 0.3 s after each camera move: every BillboardGui in workspace whose `Text` child has `LabelKind`, shown = `Enabled` and distance ≤ `MaxDistance` and `WorldToViewportPoint(point).Z > 0`; box = viewport centre ± `AbsoluteSize / 2`. Violations: any pair of shown boxes with `UiTheme.overlaps`; any shown `Text` with `TextFits == false`. PASS when empty; record the shown labels' texts.
- **H7 view(target, offset)** (Client, stands in for the player camera): Scriptable, `CFrame.lookAt(target + offset, target + Vector3.new(0, 3, 0))`; s = 1 when `c.Z < 0` else −1.

Steps (PC 1564x730; Server `H("pauseCustomers", true)`):
1. uv-i1 setup (CM2-UV (i) step 1) with bay 1 already holding trees (else place a first order and wait until it lands). During the countdown: H3 at `Bay_<data.bay>` → H6 empty, that bay's label shown with `LabelKind == "BayArriving"`; capture `uvf2-1`. H7 offset (−14, 6, 0) → H6 empty, the same label shown; capture `uvf2-2`. After landing the label reads "Douglas Fir · 6 trees".
2. uv-i9 setup (CM2-UV (i) step 4, row of 5): H3 at the row's middle tree, then H7 offset (0, 6, 14 s) → H6 empty at both, ≥ 1 row label shown at each; captures `uvf2-3`, `uvf2-4`.
3. uv-e1/uv-e2 setup (CM2-UV (e)+(j) step 1) until two orders wait at once: H3 at each `CustomerCar_<n>` → H6 empty and both "#N HERE" shown (`uvf2-5`); H3 at each `PickupTree_<n>` and H7 offset (0, 6, 14 s) at the first → H6 empty and both pickup labels shown (`uvf2-6`, `uvf2-7`); each pickup `Text`: `TextFits == true` and `TextBounds.Y <= TextSize * 1.5` (one line). Then carry/load as in CM2-UV (character within `InteractDistance` first); `npcSnapshot.count == 0` in 30 s.
4. `Custom` camera, walk along the display row: no flicker in two captures 1 s apart (`uvf2-8`).
5. `runPlaytest {mode="full"}` all PASS.
End: as CM2-UV "End".

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (397 run, 0 failed), `rojo build default.project.json --output build.rbxlx`, `rojo build release.project.json` (0 instances named UnitTest/RunPlaytest/StudioTestService; `LabelDeclutter` present).
- Ticket: at the re-run uv-i1, uv-i9, uv-e1 and uv-e2 setups no two shown billboards overlap (H6), the pickup label is one line with `TextFits` true; captures in PROGRESS.md; `runPlaytest {mode="full"}` all PASS.
- Skills: no unbounded `TextScaled` (gui); pass at 10 Hz, no Instances created (performance); strings via keys (localization).

## Out of scope
Look beyond tokens (CM2-UI); phone and tablet (CM2-UV2); prompt overlap; CM2-UVF3; `TextService` measuring (fixed widths suffice for the English launch).

## Amendments (these win over the text above)
**UVF2-A1 (defect CM2-UVF2-D1, batch run 2026-11-22: steps 3 and 4 FAIL).** Tier stays S (one client file, two lines of docs).

Cause: `labelGuis` in `WorldLabels.client.lua` is a weak-keyed table (`__mode = "k"`). Roblox hands Luau a userdata proxy per Instance; when no strong Luau reference to the proxy is left, the GC drops the proxy and its weak-table entry, although the gui still lives in workspace. Nothing else in the script holds the server-created guis, so they leave the registry soon after a few passes. Those passes already set them `Enabled = true` (spawn view without overlap, or out of range), and afterwards no pass touches them. That matches the evidence: all 11 stayed true while a manual `resolve` hid some. The tester's synthetic label was held by the tester's own variable, so its proxy survived. `watched` works because each `AttributeChanged` closure captures its instance. The camera read is correct. Lune cannot model this GC behaviour and the pure module has no defect, so no headless test is added; the total stays **397**.

Fix steps:
1. `src/client/WorldLabels.client.lua` line 95-96: make the registry strong, `local labelGuis: { [BillboardGui]: boolean } = {}`. Comment above it: `-- CM2-UVF2: every world billboard is registered here and shown or hidden by the declutter pass. Strong keys: a weak Instance key is dropped once no Luau reference remains (CM2-UVF2-D1); the pass prunes guis that left workspace.` The existing prune (`not gui:IsDescendantOf(workspace)` → `labelGuis[gui] = nil`) bounds the table. Leave `watched` as it is.
2. Same file, at the end of each pass (after the `Enabled = result[index]` loop): `script:SetAttribute("DeclutterTracked", tracked)` and `script:SetAttribute("DeclutterHidden", hidden)`. `tracked` = registered guis still in workspace this pass (including the skipped ones without an Adornee). `hidden` = the number of `false` values in `result`. These are diagnostics for the playtest only; they create no Instances.
3. `docs/DECISION_LOG.md`, entry `2026-11-22 — CM2-UVF2 world label layout`: append the bullet `- Fix (CM2-UVF2-D1): the declutter registry was a weak-keyed table, so the GC dropped server-created guis (no Luau reference) and the pass stopped touching them; the registry is now a strong table pruned by the pass. Diagnostics: WorldLabels script attributes DeclutterTracked, DeclutterHidden.`
No other file changes. Checks as in "Acceptance" (397 run).

Re-test (playtester, PC 1564x730, BUILD `cm2-n1-fix2`, server `H("pauseCustomers", true)`):
- **R0, registry**: at least 120 s after join, `LocalPlayer.PlayerScripts.WorldLabels:GetAttribute("DeclutterTracked")` equals the number of BillboardGuis in workspace whose `Text` child has `LabelKind`. Check it again after step R3.
- **R1, steps 1-2**: re-run because their "shown" checks now depend on the working pass. Step 2's row uses `Row`, `aim(-35, -20)` (CM2-UV (i) step 4); z -13 is KeepClear. Pass criteria unchanged.
- **R2, step 3**: as written, with one change for the cars. At H3 on each `CustomerCar_<n>`: H6 empty and at least one "#N HERE" shown (the other may be hidden by design, D2). Then H7 offset (0, 6, 14 s) at the midpoint of the two cars: H6 empty and both "#N HERE" shown (`uvf2-5b`). Pickup views unchanged: H6 empty, both pickup labels shown, one line. At the uvf2-6c view, sample `Enabled` of all label guis over 30 frames: at least one is false and `DeclutterHidden >= 1` (`uvf2-6d`).
- **R3, step 4**: as written: Custom camera, walk the row, H6 empty in two captures 1 s apart (`uvf2-8c`, `uvf2-8d`), and no label toggles between them.
- **R4, step 5**: a fresh `runPlaytest {mode="full"}`, all PASS.
Accept: R0-R4 PASS. The playtester records the captures in PROGRESS.md, and the reviewer then removes CM2-UVF2 from "Studio-Test ausstehend" and ticks 5d.

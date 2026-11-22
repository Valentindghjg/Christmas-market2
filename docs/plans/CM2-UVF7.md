# CM2-UVF7 — Far world labels do not overlap either

Written by: `planner`. Implemented by: the tier's agent. Playtested by: `playtester`. Reviewed and committed by: `reviewer`. Pipeline: skill `cm2-task`.
Rule: everything is decided; if something is missing, the implementer stops and reports.

## Goal
No two drawn world labels overlap at any distance: the client's pass hides labels beyond their range or behind the camera instead of re-enabling them for the engine to cull.

## Source of truth
- Backlog launch order 5i (CM2-UVF7).
- PROGRESS, CM2-UVF2 re-test, observation (1): at the uvf2-5b view, 4 bay labels 65–77 studs away were drawn and overlapped. Their `MaxDistance` is 60.
- `docs/plans/CM2-UVF2.md` D2 and amendment UVF2-A1; DECISION_LOG CM2-UVF2 entry.

## Analysis and decisions
Today (`WorldLabels.client.lua` lines 156–161) a label beyond `gui.MaxDistance` (camera distance) or behind the camera is set `Enabled = true` and left out of `resolve`; the engine still drew such labels.

| ID | Decision |
|---|---|
| D1 | Cause (hypothesis; the fix does not depend on it): the engine does not measure `BillboardGui.MaxDistance` from `Camera.CFrame.Position`. The likely measuring point is `Camera.Focus`. The H7 Scriptable camera leaves Focus at the character, which stood near the bays. In normal play Focus is the character, 12–23 studs in front of the camera, so it leaks too. |
| D2 | Fix: the client becomes the only distance rule. On registration, the client copies the server's `MaxDistance` into a client-local gui attribute `LabelRange` and sets `gui.MaxDistance = math.huge` locally (the engine default, inf). Each pass hides (`Enabled = false`) every label whose camera distance is greater than `LabelRange` or whose viewport Z is ≤ 0. It resolves all other labels with the existing `resolve`. |
| D3 | Rejected options. (a) Resolving out-of-range labels: they stay drawn beyond the range. (b) Measuring from `Camera.Focus`: unverified engine behaviour. (c) A server change: not needed; the server's `MaxDistance` stays the source value. |
| D4 | Range values are unchanged: `UiTheme.WorldLabels` `maxDistance` 60, and 40 for DisplayTree (PROVISIONAL, CM2-UVF2). No string keys, server rules, save fields or remotes change. |
| D5 | Diagnostics: a new script attribute `DeclutterCulled` counts the labels hidden by range or by camera side. `DeclutterTracked` is unchanged; `DeclutterHidden` counts overlap losers among in-range labels (UVF2 meaning). |
| D6 | Studio batching (`cm2-task` step 3): the queue holds CM2-UVF5 and CM2-UVF6, so this task is the third and starts a batch run with both. Steps 0–3 and 6 run with a 1x1 viewport. Steps 4–5 need a viewport larger than 100x100 (PC-3); otherwise they are BLOCKED and CM2-UVF7 stays queued for them. BUILD stays `cm2-n1-fix2`, and RunPlaytest is unchanged. |

## Implementer tier
Tier: S. Reason: one client script, one pure shared module and its tests. It follows the CM2-UVF2 pattern and touches no server, save, money, inventory or remote code.

## Skills to load
roblox-collaboration-mode, roblox-gui, roblox-performance, roblox-luau-core, roblox-luau-patterns, roblox-luau-types, roblox-tooling.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/LabelDeclutter.lua` | Change | `Candidate` type, `inRange`, `decide` |
| `src/client/WorldLabels.client.lua` | Change | Registration (D2), pass uses `decide`, `DeclutterCulled` |
| `tests/studio/Cases/LabelDeclutter_Test.lua` | Change | +5 tests |
| `docs/DECISION_LOG.md`, `docs/TEST_PLAN.md` | Change | Entry and one sentence |

No other file changes.

## Data and config
- Gui attribute `LabelRange` (number). The client sets it on each label's BillboardGui. It is never replicated and never read by the server.
- Script attribute `DeclutterCulled` (number) on the WorldLabels script.
- No config key, save field, string key or remote changes.

## Steps
1. **`LabelDeclutter.lua`**
   - Update the header comment: the client builds one Candidate per label. `decide` hides labels that are out of range or behind the camera, then resolves overlaps (CM2-UVF7).
   - Add `export type Candidate = { box: UiTheme.Box, priority: number, depth: number, shown: boolean, distance: number, range: number }`.
   - Add `function LabelDeclutter.inRange(distance: number, range: number, depth: number): boolean`. It returns `depth > 0 and distance <= range`.
   - Add `function LabelDeclutter.decide(candidates: { Candidate }): { boolean }`. A candidate that is not `inRange` gets `false`. The others are copied into fresh `Entry` tables (`box`, `priority`, `depth`, `shown` only), passed to `resolve`, and their results are mapped back to the original indices. The result has the same length as `candidates`.
   - `resolve`, `priorityFor` and the constants stay unchanged.
2. **`WorldLabels.client.lua`, `visit`**
   - Inside the `parent:IsA("BillboardGui")` branch, before `parent.Enabled = false`: if `type(parent:GetAttribute("LabelRange")) ~= "number"`, run `parent:SetAttribute("LabelRange", parent.MaxDistance)`, then `parent.MaxDistance = math.huge`.
   - The guard runs once per gui instance (DescendantAdded fires again on a reparent; a gui streamed back in is a new instance with the server value).
   - Comment: `-- CM2-UVF7: the client owns the draw distance; the engine's MaxDistance is not measured from the camera position.`
3. **`WorldLabels.client.lua`, declutter pass**
   - Replace the comment at lines 129–130 with: `-- Declutter pass at 10 Hz (CM2-UVF2, CM2-UVF7): hides labels beyond their LabelRange (camera distance) or behind the camera, then hides a label whose screen box overlaps a better one. No Instances are created.`
   - Remove the branch that sets `gui.Enabled = true` and continues.
   - Per valid gui insert a `LabelDeclutter.Candidate`: `range` = `LabelRange` if a number, else `gui.MaxDistance`; `distance` = `(point - camera.CFrame.Position).Magnitude`; `depth` = `viewport.Z`; `box`, `priority`, `shown` as today. Then `local result = LabelDeclutter.decide(candidates)`.
   - Apply the result: for each index, set `gui.Enabled = result[index]` only when it differs from `gui.Enabled`.
   - `culled` = candidates with `not LabelDeclutter.inRange(distance, range, depth)`; `hidden` = in-range candidates with result `false`. Each pass ends by setting `DeclutterTracked`, `DeclutterHidden`, `DeclutterCulled`.
   - Guis without a BasePart adornee or `Text` label are still skipped (they stay disabled).
4. **Docs**
   - DECISION_LOG: append at the end `## 2026-11-22 — CM2-UVF7 far world labels (engineering)`, one bullet each: defect (uvf2-5b, 4 bay labels 65–77 studs); D1 (hypothesis); D2; D3; diagnostics `DeclutterCulled`; files; headless +5, total 405.
   - TEST_PLAN section J: append after the CM2-UVF2 world-label sentence: "Far labels: `LabelDeclutter.decide` hides labels beyond their range or behind the camera (CM2-UVF7)."

## Tests (headless)
All tests go in `tests/studio/Cases/LabelDeclutter_Test.lua`. They use a local helper `cand(x, priority, depth, distance, range, shown?)` with box `{x, 0, 100, 30}`.

| Test name | Asserts |
|---|---|
| `inRange boundaries` | `inRange(60, 60, 1)` true; `inRange(60.01, 60, 1)` false; `inRange(10, 60, 0)` false; `inRange(10, math.huge, 1)` true |
| `a label beyond its range is hidden, never re-enabled` | One candidate with distance 77, range 60, depth 70, `shown = true` → `{false}` |
| `a far label does not block a near one` | A at x 0, DisplayTree priority, depth 10, distance 30, range 40; B at x 50, PickupOrder priority, depth 60, distance 65, range 60, shown → A true, B false |
| `a label behind the camera is hidden` | depth −5, distance 10, range 60 → false |
| `in-range labels resolve as before` | The three candidates of "a hidden label does not block", all with distance 20 and range 60 → true, false, true; result length 3 |

Expected: `lune run tests/headless/run.luau` 405 run, 0 failed (baseline 400).

## Playtest (Studio, via playtester; batch run with CM2-UVF5 and CM2-UVF6)
Helpers: `docs/plans/CM2-UV.md` (D1, D4, D5, H, `c`, H3, End) and `docs/plans/CM2-UVF2.md` (H6, H7, step 3 setup). New helpers:
- **Tracked** = every BillboardGui in workspace whose `Text` child has `LabelKind`.
- **WL** = the WorldLabels script, `LocalPlayer.PlayerScripts:FindFirstChild("WorldLabels", true)`.
- **d(gui)** = `|Adornee.Position + StudsOffsetWorldSpace − Camera.CFrame.Position|`, **z(gui)** = `WorldToViewportPoint(...).Z`, **rng(gui)** = `gui:GetAttribute("LabelRange")`.
- **H6b** = H6 with one change: shown = `Enabled` and z > 0 and the box intersects `(0, 0, ViewportSize)`. There is no distance condition.
- **H8 farView()** (Client): m = the mean `GetPivot().Position` of `plot.Receiving.Bay_1..Bay_4`. Set the camera to Scriptable, `CFrame.lookAt(m + Vector3.new(0, 12, 80), m)`, and `Camera.Focus = CFrame.new(m)` (the worst case under D1).

Steps (server `H("pauseCustomers", true)`):
0. **Sync check (1x1 OK).** Edit DM: `ReplicatedStorage.Shared.LabelDeclutter` Source contains `function LabelDeclutter.decide`, `StarterPlayer.StarterPlayerScripts.Client.WorldLabels` Source contains `DeclutterCulled`, RunPlaytest BUILD is `cm2-n1-fix2`. If any check fails, all steps are BLOCKED "Studio not synced with Rojo". Record HEAD and `ViewportSize`.
1. **Setup (1x1 OK).** Play is running, the player is on "Playtest A", and `CompanyReady == true`. Wait 2 s.
2. **Registry (1x1 OK).** For every Tracked gui, `MaxDistance == math.huge` and `rng` is 40 or 60. `WL.DeclutterTracked` equals the Tracked count.
3. **Range rule (1x1 OK).**
   - (a) H8, wait 0.5 s. PASS: all 4 bay guis have `d > rng` and `Enabled == false`; every Tracked gui with `d > rng` or `z ≤ 0` has `Enabled == false`; `WL.DeclutterCulled` equals their number; a 10-frame sample (1 s) shows none of them Enabled.
   - (b) H3 at `Bay_1`, wait 0.5 s. PASS: the Bay_1 gui has `d ≤ rng`; at least 1 Tracked gui is Enabled; every Enabled gui has `d ≤ rng` and `z > 0`.
   - Then set the camera to Custom.
4. **Far view on screen (needs `ViewportSize` larger than 100x100; else BLOCKED "PC-3").**
   - (a) H8, then wait 0.5 s. H6b is empty, and no bay label text is visible on the capture (`uvf7-1`).
   - (b) Run the UVF2 step 3 setup until two orders wait at once. Apply H7 offset (0, 6, 14 s) at the midpoint of the two cars, and leave `Focus` untouched.
   - (c) PASS when H6b is empty and both "#N HERE" labels are shown. Record every Enabled gui with `d > 60`; the list must be empty. Capture `uvf7-2`, the uvf2-5b view.
5. **In-range views as in UVF2 R2 (needs the viewport; else BLOCKED "PC-3").**
   - H3 at each `CustomerCar_<n>`: H6b is empty, and at least one "#N HERE" is shown.
   - The pickup views: H6b is empty, both pickup labels are shown, and each is one line.
   - At the uvf2-6c view, sample `Enabled` over 30 frames: `WL.DeclutterHidden` ≥ 1, and no label toggles (`uvf7-3`).
   - Then carry and load as in UVF2 step 3: `npcSnapshot.count == 0` within 30 s.
6. **(1x1 OK)** `runPlaytest {mode="full"}` → 41/41 PASS.

End: as in CM2-UV "End" (if 4–5 are BLOCKED, 4(b) never ran and no order is open).

## Acceptance
- Checks (one HEAD): `stylua --check src tests`; `selene src tests`; `lune run tests/headless/run.luau` 405 run, 0 failed; `rojo build default.project.json --output build.rbxlx`; `rojo build release.project.json` (0 UnitTest/RunPlaytest/StudioTestService, `LabelDeclutter` present).
- Ticket:
  - The headless tests show that a label beyond its range is hidden and never re-enabled unchecked.
  - Studio steps 0–3 and 6 PASS.
  - Steps 4–5 PASS on PC with captures `uvf7-1`..`uvf7-3` in PROGRESS. While PC-3 is open they are BLOCKED, and CM2-UVF7 stays in "Studio-Test ausstehend"; 5i is ticked only after they pass.
- Skills: the pass stays at 10 Hz and creates no Instances (performance). No new strings, and `git diff` touches only the files in "Files".

## Out of scope
Range values and label sizes (CM2-UI); hysteresis at the range border; prompt overlap; phone and tablet (CM2-UV2); verifying the engine's real `MaxDistance` metric (D1).

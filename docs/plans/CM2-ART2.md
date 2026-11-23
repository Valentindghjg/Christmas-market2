# CM2-ART2 — ArtLibrary.root ignores asset-less folders

Written by: `planner` (Opus 5.5, high). Implemented by: `implementer` (tier S). Playtested by: `playtester` (Sonnet 5.5, medium). Reviewed and committed by: `reviewer` (Opus 5.5, medium). Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
The game always uses the `ReplicatedStorage.ArtAssets` folder that really holds art, and playtest step 21 `ART_ASSETS` passes even when the Studio place still has the leftover asset-less `ArtAssets` folder.

## Source of truth
- Backlog "Current run" point 3 (CM2-ART2); PROGRESS 2026-11-23 CM2-10W entry (Studio line: leftover with 6 childless folders, deleted unsaved).
- DECISION_LOG row "Empty `ArtAssets`"; backlog PC-7 step 4 (owner deletes the leftover and saves) stays as cleanup and is not changed.
- `docs/plans/CM2-10W.md` (introduced `ArtLibrary.root` and the step 21 folder count).

## Analysis
- `ArtLibrary.root` (`src/shared/ArtLibrary.lua`) returns the first `ArtAssets` child with `#GetChildren() > 0`. The leftover has 6 empty subfolders (NPCs, Vehicles, Trees, Buildings, Environment, Props), so it counts; if it comes first, `root` returns it and `MapWorld`/`WorldService` find no art.
- Step 21 (`tests/studio/Playtest/Steps/Core.lua`, `addStep("21", "ART_ASSETS", …)`) counts the same way and fails with "two non-empty ArtAssets folders".
- Fix: "has assets" = at least one descendant that `IsA("Model")` or `IsA("MeshPart")`. `FindFirstChildWhichIsA(className, true)` does this engine-side with early exit, so `root` stays cheap (it runs per placement lookup).
- `root` stays pure (no `warn`): the unit runner calls it with fakes in the same server VM, and a module-level "warn once" flag would be spent by the tests. The one warning lives in step 21.

## Implementer tier
Tier: S. Reason: a small shared lookup fix, one playtest step and two unit tests following existing patterns; no save, money, inventory, purchase or remote change.

## Skills to load
roblox-collaboration-mode, roblox-luau-core, roblox-luau-types, roblox-tooling.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/ArtLibrary.lua` | Change | new `hasAssets`; `root` uses it |
| `tests/studio/Cases/ArtLibrary_Test.lua` | Change | rewrite the `root` test's fakes, add 2 tests |
| `tests/studio/Playtest/Steps/Core.lua` | Change | step 21 uses `hasAssets`, warns once, new detail |
| `tests/studio/Playtest/RunPlaytest.lua` | Change | `RunPlaytest.BUILD = "cm2-art2"` |
| `docs/DECISION_LOG.md` | Change | append to the "Empty `ArtAssets`" row |
| `docs/MODEL_INTEGRATION.md` | Change | one sentence in the CM2-AP bullet list |
| `docs/TEST_PLAN.md` | Change | step `ART_ASSETS` wording in §"Repeatable run" |

No other file. `MapWorld.lua` and `WorldService.lua` keep calling `ArtLibrary.root(ReplicatedStorage)` unchanged.

## Data and config
None. No config key, schema field or string key changes.

## Steps
1. `src/shared/ArtLibrary.lua`: add above `root`:
   ```lua
   -- True when the folder holds at least one Model or MeshPart at any depth (CM2-ART2).
   -- Folders alone do not count, so a leftover tree of empty subfolders is ignored.
   function ArtLibrary.hasAssets(folder: Instance): boolean
   	return folder:FindFirstChildWhichIsA("Model", true) ~= nil
   		or folder:FindFirstChildWhichIsA("MeshPart", true) ~= nil
   end
   ```
2. `ArtLibrary.root`: replace `#child:GetChildren() > 0` with `ArtLibrary.hasAssets(child)`. Fallback unchanged: no folder with assets → first child named `ArtAssets`, else nil. Replace its comment with:
   `-- Returns the art root under a container: the first child named ArtAssets that holds assets`
   `-- (hasAssets), else the first child named ArtAssets, else nil. A Studio place can hold a`
   `-- leftover ArtAssets with only empty subfolders next to the synced folder (CM2-10W, CM2-ART2).`
3. Step 21 in `Core.lua`: replace the comment and the folder loop and its `check` with:
   ```lua
   -- A Studio place can hold a leftover ArtAssets with only empty subfolders (CM2-10W);
   -- folders without assets are ignored, as in ArtLibrary.root (CM2-ART2).
   local folders, withAssets, ignored = 0, 0, 0
   for _, child in ReplicatedStorage:GetChildren() do
   	if child.Name == "ArtAssets" then
   		folders += 1
   		if ctx.ArtLibrary.hasAssets(child) then
   			withAssets += 1
   		else
   			ignored += 1
   		end
   	end
   end
   check(withAssets <= 1, "two ArtAssets folders with assets")
   if folders > 1 and ignored > 0 then
   	warn(string.format(
   		"%s 21 ART_ASSETS ignoring %d ArtAssets folder(s) without assets; delete the leftover in Studio and save (PC-7 step 4)",
   		ctx.PREFIX, ignored))
   end
   ```
   (StyLua decides the line breaks.) The step runs once per run, so this is the single warning. The rest of the step (duplicate scan of `art`, models, mesh preload) is unchanged. Return format becomes
   `"%d blender models, %d meshes, 0 failed, 0 duplicates, %d ArtAssets folders, %d without assets ignored"` with `models, #meshParts, folders, ignored`.
4. `RunPlaytest.lua` line 12: `RunPlaytest.BUILD = "cm2-art2"`.
5. Docs (append only, keep the existing text):
   - DECISION_LOG row "Empty `ArtAssets`", end of its second cell: ` CM2-ART2 (2026-11-23): a folder counts only when it holds a Model or MeshPart at any depth (`ArtLibrary.hasAssets`); `root` and step 21 ignore asset-less folders, step 21 warns once; PC-7 step 4 stays as cleanup.`
   - MODEL_INTEGRATION, after the bullet that starts "`ArtLibrary.find/prepareClone`": new bullet `- `ArtLibrary.root` returns the first `ReplicatedStorage.ArtAssets` that holds a Model or MeshPart at any depth (`hasAssets`); a leftover folder of empty subfolders is ignored (CM2-ART2).`
   - TEST_PLAN §3 "Repeatable run" line: replace `` `ART_ASSETS` (ArtAssets exists, no duplicate names, every Blender mesh preloads) `` with `` `ART_ASSETS` (ArtAssets exists, at most one ArtAssets folder holds assets and asset-less ones are ignored with one warning (CM2-ART2), no duplicate names, every Blender mesh preloads) ``.

## Tests (headless)
In `ArtLibrary_Test.lua`, add one local fake builder used by all three tests below (place it before the existing `root` test; do not change the `node`/`tree` fakes used by the `find` tests):
`inst(className: string, name: string, children: {any}?)` returns a table with `Name`, `ClassName`, and methods `GetChildren()` (the children array), `IsA(c)` (`c == className`), `FindFirstChildWhichIsA(c, recursive)` (depth-first over children: first child with `IsA(c)`, recursing into each child when `recursive` is true; nil when none).

| Test case file | Test name | Asserts |
|---|---|---|
| `tests/studio/Cases/ArtLibrary_Test.lua` | `root prefers the ArtAssets folder with assets` (rename and rewrite the existing `root prefers the non-empty ArtAssets folder`) | with `empty = inst("Folder","ArtAssets")`, `full = inst("Folder","ArtAssets",{inst("Folder","Buildings",{inst("Model","MarketStarter")})})`, `other = inst("Folder","Other",{inst("Model","X")})`: the same 6 assertions as today (`(empty, full)`→full, `(full, empty)`→full, `(other, empty)`→empty, `(other)`→nil, `()`→nil, `root(nil)`→nil). `container(...)` keeps its current shape. |
| same | `hasAssets counts Models and MeshParts at any depth` | only 6 empty subfolders → false; no children → false; `Folder > Folder > Model` → true; `Folder > MeshPart` → true; a folder holding only a `Part` and an empty `Folder` → false |
| same | `root skips an ArtAssets folder with only empty subfolders` | `leftover` = `ArtAssets` with 6 empty Folders named NPCs, Vehicles, Trees, Buildings, Environment, Props; `real` = `ArtAssets` with `Buildings > MarketStarter` (Model): `root(container(leftover, real))` = real; `root(container(real, leftover))` = real; `root(container(leftover))` = leftover; with a second leftover `leftover2`, `root(container(leftover, leftover2))` = leftover |

Expected: `lune run tests/headless/run.luau` → `[SUMMARY] 544 run, 544 passed, 0 failed` (542 + 2). The Studio unit runner shows 544/544.

## Playtest (Studio, via playtester)
Not deferred: run now. The playtest code changes (step 21, BUILD), the defect only appears in Studio with the leftover folder, and every check is server-side (PC-7 does not block it). Do not save the place at any point.
1. Rojo sync of the working tree. In Edit mode list the `ReplicatedStorage` children named `ArtAssets` with their direct children. If only one exists (the owner already did PC-7 step 4), create the fixture in Edit mode: a `Folder` named `ArtAssets` under `ReplicatedStorage` with 6 empty `Folder`s named NPCs, Vehicles, Trees, Buildings, Environment, Props. Record which case applied.
2. Start Play (Server). In the server command bar: `local A = require(game.ReplicatedStorage.Shared.ArtLibrary); local r = A.root(game.ReplicatedStorage); print(A.hasAssets(r), r:FindFirstChild("Buildings") and #r.Buildings:GetChildren())` → `true` and a count > 0 (Buildings 8 in the current place).
3. `runPlaytest {mode="full"}` → `SUMMARY mode=full steps=58 pass=58 fail=0 skip=0 result=PASS`, BUILD `cm2-art2`, unit 544/544; `PASS 21 ART_ASSETS | … 2 ArtAssets folders, 1 without assets ignored`; exactly one console line containing `[PLAYTEST] 21 ART_ASSETS ignoring 1 ArtAssets folder(s) without assets`; `PASS 56 MAP_WORLD` with the same piece counts as CM2-10W (pieces 302, overlaps 0).
4. Stop Play. If step 1 created the fixture, delete it in Edit mode. Do not save. Nothing goes into "Studio-Test ausstehend".

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (544 run, 0 failed), `rojo build default.project.json`, `rojo build release.project.json`.
- A folder with only empty subfolders never counts as the art root, in either order; the folder with a Model or MeshPart is returned.
- Step 21 passes with the leftover present and warns exactly once; it still fails with "two ArtAssets folders with assets" when two folders hold assets (code reading by the reviewer; not staged in Studio).
- PC-7 step 4 unchanged in the backlog.

## Out of scope
- Deleting the leftover from the place file (owner, PC-7 step 4).
- A runtime warning from `ArtLibrary.root` or `MapWorld`.
- Counting assets other than Model and MeshPart (Parts, Decals, Sounds), and any change to `find`, `prepareClone` or the duplicate-name scan.

## Amendment 1 (2026-11-23, after two failed Studio full runs)
Tier stays **S**: harness only, no game code.

**Cause (harness/state gap, not a gameplay defect).** Every NoFreeBay is an order of the shadow S (steps 04 second pass, 20, 44, 52); PREFLIGHT checks only R. `baysUsed` and `placeOrder` share one rule (`Receiving.usedCount`/`freeBay`, trees + arriving). Step 52 (since CM2-46a) leaves 1 Douglas Small in a free S bay; nothing removes it (the Lot Worker restocks only sold sizes). The shadow save persists, so the 4 passing full runs since (46a, 49, 47a, 10W 06:17) filled all 4 S bays. Run 2's 37 `SupplierOutOfStock` (38/39 `NoStock` follow): R's saved `supplier.refreshAt` comes from an earlier Play session with a larger `clockOffset`, so the retry's `advance(240)` does not reach it (a refresh gives Medium ≥ 8 > the ≤ 4 asked).

**Changes**
| # | File | Decision |
|---|---|---|
| D1 | `Support/Fixtures.lua` | New `settleDeliveries(userId): number`: bays of `snap(userId)` with `arriving > 0`; none → 0; else `advance(math.clamp(max(arrivesIn) + 1, 1, 86400))`, `check(poll(no bay arriving, 8), "deliveries still arriving 8 s after the clock advance")`, return the count. |
| D2 | same | New `drainShadowBays(): string`: for each `key, count > 0` of `snap(S.userId).stock` (sorted keys), `string.match(key, "^(.-):(.+)$")`, `actOk(S.userId, "Supplier.SellBack", {speciesId, sizeId, quantity})` in chunks of `GameConfig.MaxOrderQuantity`; returns `"none"` or `"<key> x<count>"` parts joined by `", "`. Never drains R. Add `local GameConfig = ctx.GameConfig`, `local actOk = ctx.actOk`. |
| D3 | same, `preflight` | After `resetCustomers()`: `settleDeliveries(R.userId)`; if `shadowJoined`: `settleDeliveries(S.userId)`, `drained = drainShadowBays()`, `check(snap(S.userId).receiving.baysUsed == 0, "shadow bays not empty after the drain")`. Then R's `snapshot` and the existing checks. Detail `"cash %d, bays %d/%d, shadow bays 0/%d, sold back %s"`; without shadow `"cash %d, bays %d/%d, no shadow"`. |
| D4 | `Steps/Shop.lua`, step 52 | After `check(landed, …)`: `actOk(S.userId, "Supplier.SellBack", { speciesId = SPECIES, sizeId = "Small", quantity = 1 })`, then `check(poll(bay's total == 0 and arriving == 0, 3), "bay <n> not empty after the sell-back")`. Detail ends `"express delivery in bay %d, sold back"`. |
| D5 | `Support/Base.lua`, `orderTrees` | Replace `advance(240)` with `advance(math.clamp(actOk(userId, "Company.GetSummary", {}).supplier.refreshIn + 1, 1, 86400))`; comment `-- a saved refreshAt can lie past +240 s in a new Play session (CM2-ART2 A1)`. |
| D6 | `RunPlaytest.lua` | `RunPlaytest.BUILD = "cm2-art2-a1"`. |
| D7 | `docs/TEST_PLAN.md` | End of §3 **Reset rule** paragraph: `CM2-ART2 Amendment 1: PREFLIGHT lands in-flight deliveries of R and S (advance to the latest arrivesIn + 1), sells back every tree in the shadow's bays and requires 0 shadow bays in use; step 52 sells its Express Sleigh tree back; a supplier sell-out retry advances to refreshIn + 1.` |
| D8 | `docs/CLAUDE_BACKLOG.md` | CM2-ART2 entry, append: ` Amendment 1: shadow bays drained at PREFLIGHT, step 52 sells its Small back, supplier retry waits for refreshIn; accept two full runs in a row 58/58 on BUILD cm2-art2-a1.` |

Headless: no new tests; still 544/544 and all standard checks.

**Playtest (Studio, now).** Setup as steps 1-2 above.
1. `runPlaytest {mode="full"}` → 58/58, BUILD `cm2-art2-a1`; record step 03's `sold back` (expected to list `DouglasFir:Small x4`: the evidence), `PASS 52 … sold back`, step 21 as in step 3 above.
2. Stop Play, start Play (new session, clock offset 0), full run again → 58/58; step 03's `sold back` lists no `DouglasFir:Small`.
3. Cleanup as step 4 above; do not save.

**Acceptance (added):** two full runs in a row, each in a new Play session, 58/58; no `NoFreeBay` or `SupplierOutOfStock` in either log; run 2 sells back no `DouglasFir:Small`.

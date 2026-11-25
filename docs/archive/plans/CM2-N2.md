# CM2-N2 — Manual checkout and queue (covers CM2-24, absorbs CM2-UVF3)

Written by: `planner` (Opus 5.5, high). Implemented by: the agent for the tier below. Playtested by: `playtester` (Sonnet 5.5, medium). Reviewed and committed by: `reviewer` (Opus 5.5, medium). Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
The player checks out the customer at the counter with a ProximityPrompt that shows species, size, height and price. A hired Cashier serves the counter on its own. A customer who waits too long walks out, gives the tree back and counts as "walked out". The interim automatic checkout of CM2-N1 is gone. The queue keeps a clear gap and the customer at the counter stands upright (CM2-UVF3).

## Source of truth
- PRODUCT_SPEC 2026-11-21, Gameplay: "Checkout: the player checks out customers manually at the counter until a Cashier is hired."
- REFERENCE_GAME_LIVE_TEST §3.6 (prompt "Fraser Fir · 7.2 ft · $164 – Check Out", cash credited at once), §3.8 (walk-outs, "Customers who walked out"), §4.4 (Cashier "handles customer checkout"; "No cashiers yet: you run checkout yourself"), §9 G3.
- DECISION_LOG "Walking customer NPCs, CM2-N1" (reservation, `npcSettle`, "Counter until N2"), G1/G2.
- Backlog launch order 10 (CM2-N2), the CM2-N1 and CM2-UV notes under it, line 10a (CM2-UVF3). `docs/plans/CM2-N1.md` "Out of scope".

## Implementer tier
Tier: L. Reason: money settled exactly once from a new player-triggered path, concurrent player/Cashier triggers, a save schema bump (13 → 14) and new server-side input validation.

## Skills to load
roblox-collaboration-mode (first), roblox-networking, roblox-security, roblox-data, roblox-server-data, roblox-npc-ai, roblox-input, roblox-localization, roblox-luau-core, roblox-luau-types, roblox-tooling, roblox-studio-mcp (playtest). CLAUDE.md wins (2: no owner approval for the schema bump; 10: keys in `en` and `de`; 11: no new remote).

## Decisions (settled)
| Topic | Decision |
|---|---|
| Counter state | The queue head enters `CheckingOut` as soon as it stands at slot 1, whoever serves. `CheckingOut` no longer ends on a timer by itself. |
| Player checkout | A server ProximityPrompt `CheckoutPrompt` on `CheckoutCounter.CounterBase`, enabled only while a customer is in `CheckingOut` on that plot. Triggered → `main.server` checks (in this order): `CompanyReady`, the player's active company plays this plot (`plots:getPlot(companyId) == plotId` and the `PlotId` attribute), per-player interval, server reach (`InteractDistance` 16 to `CounterBase`), empty hands. Then `npc:checkout(companyId, plotId)`. No new remote, no `Protocol` action. |
| Cashier until CM2-25/26 | Invisible: when `state.staff.Cashier >= 1`, the director serves the customer in `CheckingOut` after `CashierCheckoutSeconds` (3 s, the N1 interim value). The prompt stays usable with a Cashier. One counter = one served customer at a time; more Cashiers or stations come with HQ tiers (CM2-G9) and the visible avatar at `NpcPath.staffPoint()` with CM2-25/26. Cashiers still add no arrivals. |
| Exactly once | (1) Only a visit in `CheckingOut` can be served, and serving leaves that state. (2) `visit.settling` guards re-entry; `_step` skips a settling visit. (3) `completeReservedSale` refuses a replay. The prompt path also has a per-player minimum interval (0.25 s). |
| Walk-out | Patience runs from entering `Queued` (`visit.queuedAt`) for `QueuePatienceSeconds` (90 s) and covers `Queued` and `CheckingOut`. Without a Cashier, a customer whose patience ran out walks out: `npcCancel(..., walkedOut = true)` releases the tree and adds 1 to both `abandonedCustomers` and the new `walkedOutCustomers`. With a Cashier hired, a customer at the counter is always served (3 s), never walked out. Lost avatar, visit cap, failed settle and give-up count only as abandoned, not walked out. |
| Save | Schema 13 → 14 adds `walkedOutCustomers` (integer ≥ 0). `walkedOutCustomers ≤ abandonedCustomers` holds by construction and is not validated. |
| Prompt text | ActionText "Check Out" (OBSERVED). ObjectText reuses the display-tree label `treeLabel` "%s · %s · %s ft · $%d" (species, size, height, price). Height = `TreeHeight.tenthsFor(placementId, sizeId)` (same as the tree's label). Price = the reservation's `salePrice`, which is exactly what is credited. Foreign players see the prompt on other plots but nothing happens (silent). |
| CM2-UVF3 | **Absorbed here.** Cause of the overlap: queue spacing 2.2 studs while every queued customer carries its tree 1.4 studs in front. Fix: `QueueSpacing` 3.5, the `Checkout` keep-clear box grows to the queue tail (maxZ 1), and on entering `CheckingOut` the avatar is turned upright toward `staffPoint()`. The hunched look has no known cause; N2 measures `UpVector.Y` and captures the pose. If the capture still looks hunched while `UpVector.Y ≥ 0.98`, the playtester records it and the reviewer opens a follow-up (animation pose); that does not fail N2. The Studio spacing check uses 1 customer at the counter + 1 queued, because the test save has 2 parking spaces; slots 2–4 are covered by the headless config test. CM2-UVF3 closes with N2. |
| Playtests | The real company still changes only through normal actions: steps 37, 40 and 41 check out with the prompt (`serveCounter`), never with a fixture Cashier. The soak hires a Cashier on the shadow only (`setStaff`). |

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/GameConfig.lua` | Change | Npc keys, `QueueSpacing`, KeepClear `Checkout` |
| `src/shared/BusinessState.lua` | Change | Schema 14, `walkedOutCustomers` |
| `src/shared/Localization.lua` | Change | `promptCheckout` en/de |
| `src/server/Services/AnalyticsService.lua` | Change | `walkedOutCustomers` in the summary |
| `src/server/Services/CompanyStateService.lua` | Change | `npcDecide` species, `npcCancel` walk-out, `hasCashier`, snapshot field |
| `src/server/Services/CustomerNpcService.lua` | Change | Checkout, Cashier, walk-out, prompt and face calls; no auto checkout |
| `src/server/Services/CustomerNpcWorld.lua` | Change | `showCheckout`, `face` |
| `src/server/Services/WorldService.lua` | Change | Counter prompt, handler, setter, target |
| `src/server/main.server.lua` | Change | `checkoutAt`, wiring, cleanup |
| `src/server/Services/StudioTestService.lua` | Change | Hook `prompt` kind `checkout` |
| `src/client/WorldLabels.client.lua` | Change | Localize the `Checkout` prompt |
| `tests/studio/Cases/CustomerCheckout_Test.lua` | New | Director checkout tests |
| `tests/studio/Cases/CustomerNpcService_Test.lua`, `NpcTransactions_Test.lua`, `BusinessState_Test.lua`, `NpcPath_Test.lua`, `GameConfig_Test.lua`, `AnalyticsService_Test.lua` | Change | Deltas below |
| `tests/studio/Playtest/RunPlaytest.lua` | Change | BUILD, `holdSeconds` option |
| `tests/studio/Playtest/Support/Base.lua` | Change | `SLOTS`, `counterPart`, `checkoutPrompt`, `serveCounter` |
| `tests/studio/Playtest/Support/Fixtures.lua` | Change | Leak check and cleanup |
| `tests/studio/Playtest/Steps/Npc.lua` | Change | Serve the counter in 37 and 40; export helpers |
| `tests/studio/Playtest/Steps/Checkout.lua` | New | Step 41 CHECKOUT_MANUAL |
| `tests/studio/Playtest/Steps/Soak.lua`, `Steps/Core.lua` | Change | Shadow Cashier, serve counter; unit threshold |
| `docs/DECISION_LOG.md`, `docs/GAME_DESIGN.md`, `docs/TECHNICAL_ARCHITECTURE.md`, `docs/TEST_PLAN.md`, `docs/MODEL_INTEGRATION.md` | Change | Implementer, step 14 |
| `docs/PROGRESS.md`, `docs/CLAUDE_BACKLOG.md` | Change | Reviewer: N2 done, line 10a closed by N2 |

## Data and config
`GameConfig.Customers.Npc` (all PROVISIONAL):
| Key | Old | New | Note |
|---|---|---|---|
| `AutoCheckoutSeconds` | 3 | removed | replaced by the next key |
| `CashierCheckoutSeconds` | — | 3 | hired Cashier serves after this long at the counter |
| `CheckoutMinIntervalSeconds` | — | 0.25 | per-player prompt interval |
| `QueuePatienceSeconds` | 60 | 90 | from entering `Queued`; reference walk-out time not measured |
| `ReservationSeconds` | 120 | 150 | ≥ 20 + 1 + 20 + 90 + 3 = 134 |
| `Path.QueueSpacing` | 2.2 | 3.5 | slots z −11, −7.5, −4, −0.5 (CM2-UVF3) |

`GameConfig.Placement.KeepClear` `Checkout`: `maxZ` −4 → 1, comment "counter, staff side, queue to slot 4 (CM2-N2)". Existing placements keep their spots (not re-validated, as before).

Schema 14 (`BusinessState.SCHEMA_VERSION = 14`):
- `new()`: `walkedOutCustomers = 0` (beside `abandonedCustomers`).
- `migrate`: after the `== 12` block add `if state.schemaVersion == 13 then state.schemaVersion = 14; state.walkedOutCustomers = 0 end`. The legacy v1 path sets `state.walkedOutCustomers = 0` beside `state.abandonedCustomers = 0`.
- `validate`: an explicit check after the `abandonedCustomers` check: `not isFiniteInteger(state.walkedOutCustomers) or state.walkedOutCustomers < 0` → false. (Do not add it to the `ipairs` counter list: a nil entry would end that loop.)
- Runtime only: `visit.queuedAt`, `visit.settling`, `visit.walkedOut`, `visit.speciesId`, `visit.salePrice`.

## Steps
1. **GameConfig** as in the table. Remove every use of `AutoCheckoutSeconds`.
2. **BusinessState** schema 14 as above.
3. **AnalyticsService.summary**: add `walkedOutCustomers = state.walkedOutCustomers`.
4. **CompanyStateService**:
   - `npcDecide` result adds `speciesId = if type(placement) == "table" then placement.speciesId else nil`.
   - `npcCancel(companyId: string, visitId: string, placementId: string, walkedOut: boolean?): boolean`: when released, also `if walkedOut == true then state.walkedOutCustomers += 1 end`. Update its comment.
   - New, beside `refreshPlacements`: `function CompanyStateService:hasCashier(companyId: string): boolean` → false without a healthy session, else `session.state.staff.Cashier >= 1`. Read-only, no section (like `getCarriedOrderNumber`).
   - `snapshotForTest` adds `walkedOutCustomers`.
5. **CustomerNpcService**:
   - `new` options: drop `autoCheckout` and `self._autoCheckout`; doc comment `options = {maxPerServer?, maxPerPlot?, maxVisitSeconds?}`.
   - `Fsm.CheckingOut = { timeout = Npc.QueuePatienceSeconds, onTimeout = "WalkingOut" }`. Comment above `Fsm`: "onTimeout holds the success exit, except Queued and CheckingOut, whose timeout is the walk-out (CM2-N2)."
   - `newVisit` adds `speciesId = nil :: string?`, `salePrice = nil :: number?`, `queuedAt = nil :: number?`, `settling = false`, `walkedOut = false`.
   - `_decide`: also store `visit.speciesId = result.speciesId` and `visit.salePrice = result.salePrice`.
   - `_releaseIfHeld`: pass `visit.walkedOut` as the 4th argument to `npcCancel`.
   - `_settle(visit): (boolean, any)` returns `ok, result` of `npcSettle` (body unchanged otherwise).
   - New `_serve(visit): (boolean, any)`: `visit.settling = true`; `local called, ok, result = pcall(self._settle, self, visit)`; `visit.settling = false`; if not called: warn `"[ChristmasMarket2] NpcCheckoutFailed %s: %s"` (visit.id, error) and return `false, "InternalError"`; else return `ok, result`.
   - New `_patienceOut(visit, now): boolean` = `elapsed(now, visit.queuedAt or visit.enteredAt, Npc.QueuePatienceSeconds)`.
   - New `_walkOut(visit)`: `visit.walkedOut = true`, then `self:_enter(visit, "WalkingOut")`.
   - New `_atCounter(plotId: string)`: the non-load visit on that plot in state `CheckingOut`, or nil.
   - `_enter`: as its first statement, `if visit.state == "CheckingOut" and state ~= "CheckingOut" then self:_call("showCheckout", visit.plotId, nil) end` (before the `"Done"` branch).
   - `_hardRemove`: before `despawn`, `if visit.state == "CheckingOut" then self:_call("showCheckout", visit.plotId, nil) end`.
   - `ENTRY.Queued(self, visit, now)`: `visit.queuedAt = now`.
   - `ENTRY.CheckingOut(self, visit, now)`: `self:_call("face", visit.id, NpcPath.staffPoint())`, then `self:_call("showCheckout", visit.plotId, { placementId = visit.placementId, speciesId = visit.speciesId, sizeId = visit.sizeId, price = visit.salePrice })`.
   - `STEP.Queued`: `if arrived and index == 1 then CheckingOut elseif self:_patienceOut(visit, now) then self:_walkOut(visit) end`.
   - `STEP.CheckingOut`: return if `visit.settling`; if `self._companies:hasCashier(visit.companyId)` then serve when `elapsed(now, visit.enteredAt, Npc.CashierCheckoutSeconds)`; else `if self:_patienceOut(visit, now) then self:_walkOut(visit) end`.
   - `_step`: first line `if visit.settling then return end`.
   - Public, after `queue()`: `function CustomerNpcService:checkout(companyId: string, plotId: string): (boolean, any)`. Order: stopped → `false, "NoCustomer"`; `type(companyId) ~= "string" or type(plotId) ~= "string" or self._plotOf(companyId) ~= plotId` → `false, "Forbidden"`; no `_atCounter(plotId)` → `false, "NoCustomer"`; its `companyId ~= companyId` → `false, "Forbidden"`; `settling` → `false, "CheckoutBusy"`; else `return self:_serve(visit)` (`true, sale` or a `npcSettle` code). Comment: "A player at the counter serves the customer there (CM2-N2). Server-trusted callers only; main.server validates the player first."
   - `snapshot()` visit entries add `speciesId` and `salePrice`.
6. **CustomerNpcWorld** (require `TreeHeight` from Shared):
   - `showCheckout(plotId: string, info)`: nil → `WorldService.setCheckoutPrompt(plotId, nil)`; else `WorldService.setCheckoutPrompt(plotId, { speciesId = info.speciesId, sizeId = info.sizeId, heightTenths = TreeHeight.tenthsFor(info.placementId, info.sizeId) or 0, price = info.price })`.
   - `face(visitId: string, p: Point)`: avatar, `_world(visitId, p)` and its `HumanoidRootPart`; skip when the horizontal distance < 0.1; else `root.AssemblyAngularVelocity = Vector3.zero` and `root.CFrame = CFrame.lookAt(root.Position, Vector3.new(target.X, root.Position.Y, target.Z))`.
7. **WorldService**:
   - Module-local `checkoutHandler: ((Player, string) -> ())? = nil`; `function WorldService.setCheckoutHandler(handler)`.
   - `checkout(parent, position)`: after the Register part, create `ProximityPrompt` on `base`: Name `CheckoutPrompt`, ActionText "Check Out", ObjectText "", KeyboardKeyCode E, HoldDuration 0, MaxActivationDistance `GameConfig.Customers.InteractDistance - 2`, RequiresLineOfSight false, Enabled false, attribute `PromptKind = "Checkout"`. `local plotId = parent:GetAttribute("PlotId")`; Triggered: `if checkoutHandler and type(plotId) == "string" then checkoutHandler(player, plotId) end`.
   - `local function checkoutBase(plotId): BasePart?` → `CheckoutCounter.CounterBase` of the plot.
   - `function WorldService.checkoutTarget(plotId: string): BasePart?` = `checkoutBase(plotId)`.
   - `function WorldService.setCheckoutPrompt(plotId: string, info): boolean`: no prompt → false. With info: attributes `SpeciesId`, `SizeId`, `HeightTenths`, `Price`; ObjectText `string.format("%s · %s · %s ft · $%d", speciesName(info.speciesId), info.sizeId, TreeHeight.feetText(info.heightTenths), info.price)`; Enabled true. Nil: Enabled false, ObjectText "", the four attributes nil. Return true.
8. **main.server.lua**:
   - `local checkoutLast: { [number]: number } = {}`.
   - `local function checkoutAt(player: Player, plotId: string)` after `orderCallbacks`, with the decision-table order; interval with `os.clock()` and `config.Customers.Npc.CheckoutMinIntervalSeconds` (set `checkoutLast` before the reach check); out of reach → `tell(player, "outOfReach")`; `companies:getCarriedOrderNumber(companyId, player.UserId) ~= nil` → `tell(player, "handsFull")`; then `npc:checkout(companyId, plotId)` (result ignored; the HUD and "Thanks so much!" show the sale). Other refusals are silent.
   - `WorldService.setCheckoutHandler(checkoutAt)` right after `checkoutAt`.
   - PlayerRemoving: `checkoutLast[player.UserId] = nil`.
   - `StudioTestService.install` context adds `checkoutAt = checkoutAt`.
9. **StudioTestService `commands.prompt`**: kinds `carry`, `load`, `checkout`. For `checkout`: `local plotId = player:GetAttribute("PlotId")`; not a string → `failure("NoPlot")`; else `context.checkoutAt(player, plotId)`. Returns `success()` (as before, also when nothing happened).
10. **Localization**: en `promptCheckout = "Check Out"`, de `promptCheckout = "Kassieren"` (beside `promptLoad`).
11. **WorldLabels.client.lua** `localizePrompt`: branch `kind == "Checkout"`: ActionText `UiKit.localized("promptCheckout")`; if `SpeciesId` is a string, ObjectText `UiKit.localizedFormat("treeLabel", speciesName(SpeciesId), UiKit.localized("size" .. tostring(SizeId)), TreeHeight.feetText(number(prompt, "HeightTenths")), number(prompt, "Price"))`, else ""; `return`. In `visit`, watch attribute changes for `StockBay` **and** `Checkout`.
12. **Playtest support**:
    - `RunPlaytest.BUILD = "cm2-n2"`. `validOptions` returns a third value `holdSeconds`: nil → 0; else an integer 0..60, otherwise BadOptions. `execute(hook, mode, minutes, holdSeconds)` sets `ctx.holdSeconds`. Full mode installs `{ "Core", "Saves", "RowFill", "Npc", "Checkout" }`. Header comment: add the `holdSeconds` example.
    - `Core.lua` step 01: `totals.run >= 418`, message "expected >= 418".
    - `Base.lua` `SLOTS`: keep the first loop; replace the second loop with the explicit list `{25.5, -1}, {11.5, 6}, {18.5, 6}, {25.5, 6}, {25.5, -8}, {25.5, -15}` (x, z), comment "CM2-N2: clear of the grown Checkout box (queue to z 1)". After `prompt`/`npcSnapshot`/`teleport`, add and export:
      - `counterPart(plotId: string?): BasePart` (default `R.plotId`; `check` with "CheckoutCounter.CounterBase missing on <plot>");
      - `checkoutPrompt(plotId: string?): ProximityPrompt` (`CounterBase.CheckoutPrompt`, `check` with "CheckoutPrompt missing on <plot>");
      - `serveCounter(): boolean`: the first `npcSnapshot().visits` entry with `plotId == R.plotId` and `state == "CheckingOut"` → `teleport(counterPart())`, `prompt("checkout", 0)`, return true; else false.
    - `Fixtures.lua`: `leakCheck` adds, for R and S plots, `check(not checkoutPrompt(plotId).Enabled, "checkout prompt still enabled on <plot>")`. `cleanup`'s setStaff attempt also calls `call("setStaff", { employeeId = "Cashier", count = 0 })`.
    - `Npc.lua`: `npcWave` calls `serveCounter()` once per loop iteration, before `npcSnapshot()`. Step 40's WaitingAtCar poll calls `serveCounter()` at the start of its predicate. Export `ctx.npcVisit = npcVisit` and `ctx.ensureDouglas = ensureDouglas` at the end.
    - `Soak.lua`: step 01 after `shadowJoin(1)`: `call("setStaff", { employeeId = "Cashier", count = 1 })`. Step 03 loop: `serveCounter()` right after `servePlayerOrders()`. Detail and checks unchanged.
13. **`Steps/Checkout.lua`** (new, header "Playtest step 41 (full mode): manual checkout and queue (CM2-N2, CM2-UVF3)"), `addStep("41", "CHECKOUT_MANUAL", { "03" }, withNpcCleanup(checkoutStep))`. `checkoutStep`:
    1. `local first = snap(R.userId)`; `check(first.staff.Cashier == 0, "player has a Cashier hired; manual checkout needs a save without one")`.
    2. Store back every R placement whose centre lies in x 7.5..24.5 and z −21.5..4.5 (`actOk(R.userId, "Stock.Store", { placementId = id })`).
    3. `ensureDouglas(2)`; poll 4 s `displayedCount(R.plotId) == snap(R.userId).placementCount` (message as in step 37). `local start = snap(R.userId)`.
    4. `npcVisit(8)`, `npcVisit(20)`. Poll ≤ 120 s until one visit is `CheckingOut` (`counter`) and the other `Queued` (`waiting`); FAIL "no queue of 2 within 120 s" with both states.
    5. Poll ≤ 10 s until `waiting`'s HumanoidRootPart (model in plot `Customers` with `NpcVisitId`) is within 1.5 studs (horizontal) of `NpcPath.toWorld(c, NpcPath.queueSlot(2))`. Then `gap` = horizontal distance between both roots, `check(gap >= 3, "queue gap %.2f")`; `up` = counter root `CFrame.UpVector.Y`, `check(up >= 0.98, "checkout avatar tilted (UpVector.Y %.3f)")`.
    6. Prompt: `checkoutPrompt()` Enabled; `SpeciesId == SPECIES`, `SizeId == SIZE`, `Price == counter.salePrice` (npcSnapshot), `HeightTenths` a number > 0, ObjectText contains "Douglas Fir" and `"$" .. salePrice` (plain find).
    7. `teleport(counterPart())`; if `ctx.holdSeconds > 0`: `emit("HOLD 41 checkout queue ready for capture")`, `task.wait(ctx.holdSeconds)`.
    8. Out of reach: `teleport(plot.Spawn)`, `prompt("checkout", 0)`; sales unchanged and `counter` still `CheckingOut`, else FAIL "checkout worked out of reach".
    9. Double trigger: `teleport(counterPart())`; two `task.spawn` calls of `invoke("prompt", { userId = R.userId, kind = "checkout", number = 0 })` in the same frame; poll 3 s for both responses; `task.wait(ACTION_PAUSE)`. Then `sales == start.sales + 1`, `cash == start.cash + p1` (p1 = counter's salePrice), `counter` in `WalkingToCar` or `WaitingAtCar`.
    10. Poll ≤ 15 s until `waiting` is `CheckingOut`; `task.wait(ACTION_PAUSE)`; `prompt("checkout", 0)`; `sales == start.sales + 2`, `cash == start.cash + p1 + p2`, both order numbers ascending in join order.
    11. Poll 2 s `not checkoutPrompt().Enabled`.
    12. Return `string.format("queue of 2 checked out: +$%d +$%d, sales +2; out of reach and double trigger refused; gap %.1f, up %.3f", ...)`.
14. **Docs** (implementer):
    - DECISION_LOG new entry "2026-11-22 — Manual checkout and queue, CM2-N2 (engineering)": the decision table rows (counter, player path and its checks, invisible Cashier, exactly once, walk-out and counters, schema 14, prompt text, CM2-UVF3 absorbed with cause and fix, playtest rule), the config table, "supersedes N1's 'Counter until N2' and 'AutoCheckoutSeconds'".
    - GAME_DESIGN §customers (line with "Until CM2-N2"): replace that sentence with the counter rule (player prompt or hired Cashier after 3 s; walk-out after 90 s of queueing, counted as walked out); reservation 150 s.
    - TECHNICAL_ARCHITECTURE: §2 CustomerService line append "CM2-N2: `checkout(companyId, plotId)`, prompt validated in `main.server` (`checkoutAt`)"; §4 new bullet "Company schema 14 (CM2-N2): `walkedOutCustomers`, migration 13 → 14 sets 0".
    - TEST_PLAN "Repeatable run": BUILD `cm2-n2`, 42 steps, unit runner ≥ 418, step `41 CHECKOUT_MANUAL`, option `holdSeconds`; hook `prompt` kinds `carry|load|checkout`; npcSnapshot visit fields `speciesId`, `salePrice`; snapshot `walkedOutCustomers`; soak: the shadow has a Cashier; steps 37/40/41 and soak 03 serve the player's counter by prompt.
    - MODEL_INTEGRATION CheckoutCounter paragraph: "CM2-13W keeps `CheckoutCounter.CounterBase` with `CheckoutPrompt` (or moves both and updates `WorldService.checkoutTarget`); `Checkout1` = queue slot 1, slots then follow `Path.QueueSpacing` 3.5."

## Tests (headless)
Expected total **418** = 405 + 13.

`CustomerCheckout_Test.lua` (new, 8): its own copy of the N1 harness (fake persistence, fake world logging every call incl. `showCheckout(plotId, info)` and `face(visitId, p)`, 0.2-s ticks, `spawn`, `runUntil`, `visitOf`), `addCompany(h, id, plot, trees, cashier)` setting `state.staff.Cashier = cashier`, and `lastCall(h, name)`.
| Test | Asserts |
|---|---|
| the counter waits for a player without a Cashier | cashier 0; runUntil CheckingOut; run 10 s → still CheckingOut, sales 0; `showCheckout` args `PLOT_1`, info `{placementId "douglas_1", speciesId "DouglasFir", sizeId "Medium", price = reservation salePrice}`; `face` with (16, −16.5) |
| a player checkout settles exactly once | `checkout(A, PLOT_1)` → true; again → false, "NoCustomer"; sales +1; cash + salePrice exactly; state WalkingToCar; `lastCall("showCheckout").args[2] == nil`; 1 order |
| a re-entrant checkout is refused while settling | `(h.service :: any).npcSettle` wrapped to call `h.npc:checkout(A, PLOT_1)` once before delegating; inner → false, "CheckoutBusy"; outer → true; sales +1 |
| the player serves the queue in join order | 2 trees, profiles 8 and 20, cashier 0; queue[1] CheckingOut and queue[2] Queued; checkout → queue[1] leaves; runUntil queue[2] CheckingOut (20 s); checkout; order numbers ascending; sales +2; cash + p1 + p2 |
| another save cannot check out on this plot | B on PLOT_2 without customers: `checkout(B, PLOT_1)` and `checkout(A, PLOT_2)` → "Forbidden"; `checkout(B, PLOT_2)` → "NoCustomer"; A still CheckingOut; sales of A and B 0 |
| a Cashier serves after CashierCheckoutSeconds | cashier 1; runUntil CheckingOut; run 2.8 → CheckingOut; run 0.4 → WalkingToCar; sales +1 |
| a lost avatar at the counter is not a walk-out | cashier 0; at CheckingOut remove the fake position; run 0.2 → Departing; reservation nil; abandoned +1; walkedOut +0; prompt hidden |
| a hard remove at the counter hides the prompt | cashier 0; at CheckingOut `clearPlot(PLOT_1)` → `lastCall("showCheckout").args[2] == nil`; sales 0, walkedOut 0 |

Other deltas:
| File | Change | Asserts |
|---|---|---|
| CustomerNpcService_Test | `fakeWorld` gets logging `showCheckout` and `face`; `addCompany` sets `state.staff.Cashier = 1` (comment: "CM2-N2: a hired Cashier serves the counter after 3 s"). "queue patience runs out and releases the tree": `harness()`, `state.staff.Cashier = 0`; runUntil Queued; run 89.8 → `CheckingOut`; run 0.4 → history[8] CheckingOut, history[9] WalkingOut; reservation nil; abandoned +1; `walkedOutCustomers` +1; nothing carried. "a failed checkout counts one abandonment": also `walkedOutCustomers == 0`. | count unchanged (23) |
| NpcTransactions_Test (+2) | "npcDecide reserves…" also `picked.speciesId == "DouglasFir"` and `reservation.expiresAt == NOW + 150` via `Npc.ReservationSeconds`. New "npcCancel counts a walk-out only when asked": decide, `npcCancel(..., true)` → true, abandoned +1, walkedOut +1; again → false, both unchanged. New "hasCashier follows the hired count": false; `setStaffForTest(COMPANY, "Cashier", 1)` → true; after `unloadCompany` → false | |
| BusinessState_Test (+2) | lines 184/185/417: 13 → 14. New "migrates v13 to v14 with a walk-out counter": schemaVersion 13, field nil, cash 777, abandoned 3 → version 14, walkedOut 0, cash 777, abandoned 3, validates. New "rejects an invalid walk-out counter": −1, 1.5, nil each → `validate` false | |
| NpcPath_Test (+1) | slot 4 is (16, −0.5). New "queue spots keep a 3-stud gap" (CM2-UVF3): `distance(queueSlot(i), queueSlot(i+1)) >= 3` for i 1..3; each slot ± 1 stud lies inside KeepClear `Checkout` | |
| GameConfig_Test | reservation sum uses `CashierCheckoutSeconds`; add `MaxVisitSeconds >= CarArriveSeconds + 4 * LegTimeoutSeconds + BrowseSeconds + PickUpSeconds + QueuePatienceSeconds + CashierCheckoutSeconds + Customers.PickupPatienceSeconds + WaitAtCarExtraSeconds` (312.5 ≤ 360) | count unchanged |
| AnalyticsService_Test | set `walkedOutCustomers = 2`, assert the summary returns 2 | count unchanged |

## Playtest (Studio, via playtester)
Tier L → test now. One Play session, BUILD `cm2-n2`, in this order, no manual cleanup in between:
1. Client VM, before the first run (camera on R's counter; steps use hooks, not the camera):
   ```lua
   local p = game.Players.LocalPlayer
   local c = workspace.ChristmasMarketWorld.Plots[p:GetAttribute("PlotId")].PrimaryPart.Position
   local f = if c.Z < 0 then 1 else -1
   local cam = workspace.CurrentCamera
   cam.CameraType = Enum.CameraType.Scriptable
   cam.CFrame = CFrame.lookAt(Vector3.new(c.X + 30, c.Y + 9, c.Z - 6 * f), Vector3.new(c.X + 16, c.Y + 3, c.Z - 10 * f))
   ```
2. `runPlaytest { mode = "full", holdSeconds = 20 }`. When the output shows `[PLAYTEST] HOLD 41`, take two `screen_capture`s 3 s apart (**V2**). After the run: client `cam.CameraType = Enum.CameraType.Custom`. Expected `steps=42 pass=42 fail=0`; 41's detail with gap ≥ 3 and up ≥ 0.98; 37 and 40 PASS with the counter served by prompt.
3. `runPlaytest { mode = "full" }` → 42/42 again.
4. `runPlaytest { mode = "soak", minutes = 10 }` → `steps=7 pass=7` (03 sales ≥ 10, npc snaps 0; 03a ≥ 55 FPS).
5. **V2** PASS when both captures show the customer at the counter and the queued customer clearly apart (no avatar inside another), the counter customer standing upright, and the prompt "Check Out" with "Douglas Fir · Medium · … ft · $…". A hunched-looking pose while 41 passed `up ≥ 0.98` → record it as a finding (follow-up, not a FAIL). Capture timeout or black image → V2 BLOCKED with the reason; 41's numbers still count.
6. Record in PROGRESS: the three summaries, 41's detail, V2, and any `NpcCheckoutFailed`/`NpcWorldFailed` warning (none expected).

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (418 run, 0 failed), `rojo build default.project.json` and `rojo build release.project.json` (no `StudioTestService`).
- Backlog ticket: exactly-once settlement under double triggers (headless re-entrant and repeat tests; Studio step 41 double trigger), queue order (headless + 41), a walk-out releases the tree and counts as walked out (headless), a member of another save cannot check out on this plot (headless "Forbidden"), Studio queue of 2 checked out by the player with cash and sales rising by the server price (41).
- The interim automatic checkout is gone: no `AutoCheckoutSeconds` or `autoCheckout` left in `src` or `tests` (`grep`); without a Cashier a customer at the counter is never served by a timer.
- CM2-UVF3: headless spacing test; Studio gap ≥ 3 and `UpVector.Y ≥ 0.98` (41) and V2.
- Save: schema 14 migrates 13 → 14 without data loss; no new remote; no client value reaches a money path (price from the reservation, company and plot from the server).

## Out of scope
Visible Cashier, staff energy, Employees tab text (CM2-25/26); a second station and the Pavilion's +12 % patience (HQ tiers); reviews for waiting (CM2-G15); the walked-out UI (CM2-35); hiding the prompt from other saves' players; the CM2-13b counter art and `Checkout1` (CM2-13W); observed patience and Cashier speed; phone and tablet screenshots (CM2-UV2).

## Amendment 1 — soak 03 FAIL (Studio eca6b61c, 2026-11-22)
**Finding (planner, code reading).** No game defect found. The player path (`checkoutAt` → `checkout` → `_serve`) and the Cashier path (`STEP.CheckingOut`, served after 3 s) are correct for a customer in `CheckingOut`, as are queue advance and patience. Walking works (0 snaps), and 37/40/41 serve by prompt. The numbers show that the counter gate fired on neither plot. R made 1 sale (odd, which is the 1 expiry; 0 loads) and S made 1 (1 worker load). Before N2 the same walking customers bought about 24 (RF: drive-pasts 120, so parking stayed full and the 20-s forced visits could not have made those sales). The soak cannot say why, because it prints totals only and `prompt` returns ok for every refused checkout (handsFull, outOfReach, NoCustomer). **Cause class: harness gap** (soak 03 cannot be diagnosed). No game-code change here. The instrumented re-run decides; a gameplay result becomes Amendment 2.

**Fix steps** (tier L, unchanged)
1. `Base.lua` `serveCounter(): string`:
   - returns "none" when R has no `CheckingOut` entry;
   - otherwise `before = snap(R.userId)` and `held` = count of `before.customerOrders` with `carried`, then teleport and prompt as now;
   - returns "served" if `snap(R.userId).sales > before.sales`, else "handsFull" if `held > 0`, else "refused".
   - The Npc.lua callers stay statement calls.
2. `Soak.lua` step 03:
   - Per tick, after `serveCounter()`: one `npcSnapshot()`; add each non-load `CheckingOut` visit to `seen[plotId][visitId]`.
   - Count `served`, and count `refused` for "handsFull" or "refused"; `firstRefusal` = the first of these results ("-" if none).
   - Forced visits: `tries += 1`; `forced += 1` when the response is a table with `ok == true`.
   - Append to the detail: `" | R sales %d visits %d abandoned %d walked out %d drive-pasts %d at counter %d served %d refused %d (%s) | S sales %d visits %d abandoned %d walked out %d drive-pasts %d at counter %d cashier %d | forced %d/%d"`. The figures are per-company deltas of `sales`, `customerVisits`, `abandonedCustomers`, `walkedOutCustomers` and `drivePastCustomers`; `at counter` is the size of `seen` per plot; `cashier` is `endS.staff.Cashier`.
   - New checks after `mismatches == 0`, in this order, each message ending with `" | " .. detail`: `endS.staff.Cashier == 1` "shadow lost its Cashier"; S walked out `== 0` "S customers walked out despite the Cashier"; `refused == 0` "R checkout refused (<firstRefusal>)".
3. `CustomerCheckout_Test` +1 → **419**: "a Cashier serves a queue of two without walk-outs": cashier 1, 2 trees, profiles 8 and 20; run 0.2-s ticks until both visits have `sold` (at most 120 s); sales +2, walkedOut +0, order numbers ascending in join order. Acceptance: 419 run.
4. TEST_PLAN, soak line: the new detail fields and the three checks.
5. **Full detail to the console (decided: option a).** `record()` clips to `MAX_DETAIL = 200`, and the 03 detail is about 371 bytes, so the new fields would be lost. In `Soak.lua` step 03, directly after the `detail ..= string.format(...)` block and before `if npcSnaps > 0`, add one line `ctx.emit("DETAIL 03 " .. detail)` (or the file's local `emit` alias if it has one). The console then prints `[<PREFIX>] DETAIL 03 <full detail>` on PASS and FAIL. `MAX_DETAIL`, `record()` and the field order stay unchanged. Rejected: (b) would lengthen every step's report line; (c) would drop fields the reading rules need. No headless test change (still 419).

**Re-test** (playtester; game code is untouched, so no full run)
a. `runPlaytest { mode = "soak", minutes = 10 }` → `steps=7 pass=7`; 03 sales ≥ 10, npc snaps 0; 03a ≥ 55 FPS. Record the whole 03 detail from the console line `DETAIL 03` (the report line is clipped to 200 bytes) and any `NpcCheckoutFailed`, `NpcWorldFailed` or `pass errored` warning.
b. Save read-back, Server VM, after the soak:
   - call hook `flush`;
   - `saveId` = the entry named "Playtest A" in hook `saves` (R's userId);
   - `local r = game:GetService("DataStoreService"):GetDataStore("ChristmasMarket2_CompanyState_v1"):GetAsync("company:save:" .. saveId)`;
   - print `schemaVersion` and `walkedOutCustomers` (top level, or under `r.state` if wrapped).
   - PASS when the values are 14 and an integer ≥ 0.
c. On a FAIL, the `DETAIL 03` line names the stage. Record it and stop. Reading rules (implementer findings adopted):
   - `at counter` is a lower bound only: it is sampled once per tick and a Cashier serves within 3 s, so most counter visits fall between samples. `at counter > 0` proves the gate fired; `0` proves nothing. Judge the counter by S sales vs S visits.
   - Stocking is ruled out as a cause: every soak stocking spot passes `Stocking.check`, so no placement is refused.
   - S walked out > 0, or S sales far below S visits with S abandoned low: Cashier or queue defect, game code (Amendment 2).
   - "refused": harness or player state (handsFull: the load step).
   - S and R sales far below visits with abandoned high: customers leave before or in the queue (browse → queue transition or patience), game code (Amendment 2).
   - Pre-N2 placements at (11.5, −1) and (18.5, −1) may remain on R's or S's save and overlap queue slot 4. Decided: note only, no store-back code. The overlap is visual, the trees stay sellable and sell off in normal play. Record whether any are present (from `placements` in the R/S snapshot); their presence alone is not a FAIL.

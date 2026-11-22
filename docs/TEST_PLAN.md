# Test and Quality Plan — Christmas Market 2
Status: PLANNED, NOT EXECUTED
Updated: 2026-11-19

## 1. Quality gates
G0: source structure valid, Rojo project resolves, static type/lint checks pass. G0 covers `src`, `tests` and `tools` (`stylua --check src tests tools`, `selene src tests tools`) and the art pipeline: `lune run tests/tools/art_pipeline.luau` (the Blender test is SKIP without Blender, as in CI) and `lune run tools/art/art.luau verify release.rbxlx` after the release build.
G1: pure Luau unit tests pass, no critical arithmetic/state invariant failures.
G2: Roblox Studio solo playtest completes purchase -> delivery -> display -> customer sale -> save/rejoin.
G3: 2–6 player Studio multiplayer test covers plot isolation and shared-company permissions.
G4: device tests: phone, tablet, desktop and console/gamepad; UI safe areas, navigation and readable labels.
G5: exploit/race/failure tests, performance budgets, production release checklist; publication requires owner approval.

## 2. Automated unit tests (priority P0)
| ID | Scenario | Expected result |
|---|---|---|
| ECO-01 | Small/Medium/Large price for 82 | 66/82/107 with round-half-up |
| ECO-02 | Negative, NaN, infinite, unknown size | rejected |
| ECO-03 | Price adjustment outside min/max | rejected/clamped by policy |
| PRC-01 | Benchmark and bounds | typical = 5 × medium wholesale or the OBSERVED override (Noble 184); manual prices outside 50–250 % of it rejected |
| PRC-02 | Pricing summary | margin $/%, S/M/L profit and sentiment equal the REFERENCE §4.3 cards |
| INV-01 | Add 3 then remove 2 | 1 remaining |
| INV-02 | Remove > available or negative/decimal quantity | rejected without mutation |
| INV-03 | Place/reserve/sell same item twice | only one success |
| BUY-01 | Insufficient cash | no debit, no order |
| BUY-02 | Duplicate request ID | charged once |
| BUY-03 | Client sends fabricated wholesale cost | ignored; server computes cost |
| BUY-04 | Order beyond capacity | rejected, no cash change |
| DEL-01 | Delivery not due | the trees are not in the bay |
| DEL-02 | Delivery due after reconnect | exactly one arrival |
| STK-01 | Stocking spot outside the lot, in a keep-clear box or too close to a tree | `OutsideLot`, `KeepClear`, `TooClose` in this order; nothing changes (`Stocking_Test`, `PlacementService_Test`) |
| STK-02 | Row fill with one blocked position; replayed row request | all or none; the replay returns `DuplicateRequest` and places nothing |
| STK-03 | Store mode | the tree returns to a bay without duplication (bays + lot total unchanged); a second store is `UnknownPlacement`; a reserved tree is never moved (`Reserved`) |
| STK-04 | Schema 12 → 13 migration | stock and pending orders move into 4 bays; overflow is refunded at wholesale with one `MigrationRefund` entry; no tree value is lost |
| SALE-01 | Reserved tree sold | exactly one credit and stock decrement |
| SALE-02 | Customer abandons queue (queue patience, give-up, lost avatar, visit cap, sweep, reload) | reservation released exactly once, abandonment counted once; a failed settle (`ReservationExpired`) counts one abandonment and no order (`CustomerNpcService_Test`, `NpcTransactions_Test`) |
| NPC-01 | Walking customer FSM | every state has a positive timeout and an exit; the full path is the 10 states Arriving … WaitingAtCar; a stuck leg snaps after `LegTimeoutSeconds` and lands in the snap log; corners advance within `CornerRadius` or once the avatar stopped; an arrival override applies to the next live arrival only; `resetForTest` removes a company's visits at once (`CustomerNpcService_Test`) |
| NPC-02 | NPC sale settles once | `npcSettle` credits once in the visit's parking space; a replay is `ReservationRequired`; `onSold` adopts the visit car before the orders notification (`NpcTransactions_Test`) |
| NPC-03 | NPC budget and cleanup | 4 per plot, 24 per server (load-test NPCs count); unload, reload, plot change, `clearPlot` and `shutdown` hard-remove without a transaction; orphaned `visit:` reservations and claims are swept; a reload clears reservations (`CustomerNpcService_Test`, `BusinessState_Test`) |
| NPC-04 | NPC routes | lot-frame routes avoid the stand and bays (inflated by `Clearance` 3) and the counter (`CounterClearance` 1.5), stay inside the lot and mirror on plots 4–6; a start inside an obstacle walks out first (`NpcPath_Test`, `GameConfig_Test`); looks come from the own palette (`NpcLook_Test`) |
| PROG-01 | Pavilion prerequisites incomplete | no upgrade |
| PROG-02 | All prerequisites met, sufficient cash | one upgrade and one debit |
| QUEST-01 | Claim reward twice | only first grants reward |
| ROLE-01 | Visitor tries to buy or edit price | denied |
| ROLE-02 | Worker tries to change roles | denied |
| SAVE-01 | Load fails | economy locked, existing data not overwritten |
| SAVE-02 | Old schema loads | migration preserves balances |
| SAVE-03 | Two servers claim same company | one writer only |
| SAVE-04 | History > limit | bounded at 100 entries |
| LOC-01 | Missing German key | English fallback |
| SEC-01 | Malformed/oversized remote payload | rejected |
| SEC-02 | Flood requests | rate-limited |
| SEC-03 | Spoof plot ID | cannot mutate another plot |

## 3. Integration playtests
A. Fresh user joins, gets free plot, starter inventory and tutorial; no unintended Roblox purchases.
B. Supplier order debits once; delivery countdown survives disconnect; truck arrival, the automatic drop into the bay and stock transitions are consistent (CM2-G14 plan, `docs/plans/CM2-G14.md`, playtest steps 1–3).
C. Stock trees within plot boundaries, reject collisions and keep-clear areas; a row places all or none; store mode returns a tree to receiving without duplication (CM2-G14 plan, playtest step 36).
D. Customer chooses affordable tree, queues, pays; cashier handles queue, lot worker automates tasks; no salaries charged.
E. Prices affect conversion; auto pricing respects manual override state and limits (CM2-G7 plan).
F. Parking, land and HQ upgrades enforce prerequisites and unlock correct slots.
G. Two personal businesses cannot spend each other's money or stock.
H. Shared company: invite, join, role enforcement, owner disconnect, simultaneous purchase requests, session migration.
I. Reload restores all placements, upgrades, employees, stats, pricing and orders.
J. Localization and accessibility across input modes; no UI clipped by phone safe areas. Layout rules, device matrix and the Studio device-simulator checks (blocked until PC-3, then CM2-UV (f)) are in `docs/plans/CM2-40.md`; the headless layout tests are `UiTheme_Test`. The modal rule (one dialog at a time, picker as base layer, finder over it) is covered headless by `ModalCoordinator_Test` (CM2-UVF1). World labels: `LabelDeclutter_Test` and the `UiTheme_Test` world label case (CM2-UVF2). Far labels: `LabelDeclutter.decide` hides labels beyond their range or behind the camera (CM2-UVF7). Dialog text fit: `UiTheme_Test` save row case; Studio probe H4b (CM2-UVF4). Picker list height: `UiTheme_Test` picker list case (CM2-UVF5). Team footer on Solo: `CoopSave_Test` Solo code case; Studio CM2-UVF6.
K. Event flags work only during Christmas event window; no offline passive payout.
L. Monetization is active at launch (owner decision 2026-11-21): every product needs a receipt test pass (grant once, replay rejected, offline player, failed grant retried) before the owner publishes.

## 3b. Studio playtest procedure (driven through the Roblox Studio MCP)
- Start Play (Server + Client). The server unit-test runner is `require(ServerStorage.UnitTest.RunUnitTest)(nil, 10)` in the Server data model.
- Customers are random and orders expire after 120 s, so use `ServerStorage.StudioTestHook` (Studio only): `Invoke("forceCustomer", n)` makes the next arriving customer profile `n` and converts it (profiles 5, 17, 29, … want a Medium Fraser Fir; profiles 8, 20, 32, … a Medium Douglas Fir); `Invoke("advanceClock", seconds)` fast-forwards deliveries and order expiry; `Invoke("customerOrders", userId)` returns the order summary.
- **Repeatable run (CM2-G20):** in the Server data model of a running Play session, `return game:GetService("ServerStorage"):WaitForChild("StudioTestHook"):Invoke("runPlaytest", { mode = "full" })` returns `"started"` and runs the whole sequence (41 steps, BUILD `cm2-n1-fix2`: unit runner (at least 380 tests), `02a ACTIVE_SAVE` (play the save "Playtest A", creating it if absent), shadow join, order, delivery into the order's bay, `06 BAY_VIEW` (the bay part's attributes match the snapshot), place from the bay, NPC sale, carry, hands-full, respawn, wrong car, load, plot isolation, expiry, Lot Worker, sell-back, in-session rejoin, accelerated soak, `ART_ASSETS` (ArtAssets exists, no duplicate names, every Blender mesh preloads), `24 SAVE_CREATE` (create "Playtest B", replayed request ID deduplicated), `25 SAVE_SWITCH` (same plot, saves isolated), `26 SAVE_RENAME`, `27 SAVE_DELETE` (typed-name confirmation, active save refused), `28 FAIL_CLOSED` (a stolen lock shows `SessionLocked` and refuses orders), `29 COOP_JOIN` (create and play "Playtest Duo"; the shadow joins with the code and shares the plot), `30 COOP_SHARED_CASH` (both members act on one cash balance; one request ID debits once), `31 COOP_RULES` (member actions `OwnerOnly`, seat limit, the old code stops working, resizing), `32 COOP_REMOVE` (a removed member loses access, re-joins, plays while the owner is elsewhere; the Duo is deleted from the members' lists), `33 LOCATOR_CLAIM` (the save-to-server map holds "Playtest A" for job `studio` with the player as host; a renewal succeeds), `34 ELSEWHERE` ("Playtest Far" is released after a switch; with a fake foreign map entry and a stolen lock its row shows `elsewhere`, Play returns `SaveInUseElsewhere` and `Save.Teleport` returns `TeleportUnavailable` in Studio; it plays again once cleared and is deleted), `35 FINDER` (the shadow's search creates a Duo, the player joins it through the finder as a Member on the returned plot, the full listing disappears and a third user gets `ListingGone`; leave, relist the same save, stop, relist, a switch removes the listing, the save is deleted), `36 ROW_FILL` (CM2-G14: `OutsideLot`, `KeepClear` and a blocked row change nothing; a row of 5 lands as a whole and its replay is `DuplicateRequest`; `TooClose`; store back ×5 and a second store is `UnknownPlacement`; the Douglas Medium total is unchanged), `37 NPC_WALK` (CM2-N1: walking customers 8 and 20, then 32, on R's plot each walk the 10 states with 0 snaps; while walking to the tree up to checkout the placement is reserved, the tree model shows `Reserved` and `NpcCarried`; the order uses the visit's parking space, `CustomerCar_<n>` replaces the `VisitCar_`, the avatar waits within 3 studs of its door; after a player loads the tree the NPC is gone within 5 s; sales +3 and nothing left), `38 NPC_GIVE_UP` (profile 5 walks out: Browsing, WalkingOut, Departing, visits +1, abandoned +1; profile 8 gives up while carrying: the tree is unreserved and visible within 3 s, sales unchanged), `39 NPC_REJOIN_CLEANUP` (a rejoin removes the reserved customer, its car and the reservation within 5 s; no stray Humanoid), `40 NPC_REAL_ARRIVAL` (CM2-N1 fix round 1: with 2 Douglas Medium shown, `npcNextArrival {userId, 8}` and unpaused customers bring a live arrival with customer number 8 on R's plot within 12 s; it walks the 10 states with 0 snaps, the player loads its order and sales rise by at least 1), leak check (also: no live NPC, an empty `<plot>.Customers`, no `VisitCar_` or `NpcCarriedTree`; Humanoids of live NPCs are not stray), cleanup (back on "Playtest A", test saves including "Playtest Duo", "Playtest Far" and the finder save removed, the fake map entry cleared, both synthetic users leave, no NPC left on the shadow plot within 3 s)). `{ mode = "soak", minutes = 10 }` runs the literal real-time soak (7 steps: `01a ACTIVE_SAVE` first, no clock advance until its final drain; `03 SOAK_REALTIME` runs with customers unpaused and fails when a walking customer snaps (`npc snaps <n>` in its detail); `03a NPC_LOAD` pauses and resets customers and runs `npcLoadTest {seconds = 60}`: PASS when 24 NPCs are spawned and live on plots 1–6, every 5-s window ≥ 55 FPS, 0 snaps and none left; `04 LEAK_CHECK` waits up to 180 s for every walking customer to leave, expiring open orders from the server clock while one waits at its car, without an NPC reset). **Reset rule (CM2-N1 fix round 1):** `resetCustomers()` pauses customers, calls `npcReset`, lets open customer orders of R (and S while joined) expire from the server clock (`snapshot.clock`, at most 3 rounds of `advance(max(expiresAt) − clock + 1)`), then waits up to 8 s for clean plots, no NPC objects and no reserved placement on R; it never loads an order or changes cash. It runs at the start of PREFLIGHT (both modes), in soak 03a and at the start of cleanup; steps 37–40 always end with it, and the step's own error wins over the reset error. Step 37 first checks that each plot's `StarterSalesTent` lies within KeepClear `Stand` ± 0.5 (AABB over every part's corners) and is lot-aligned (±1°), with every part in `LotStructure`, and that the player's character parts are in `PlayerCharacter`; a snap FAIL lists the visit's snap-log entries.
- **Walking customers (CM2-N1):** `Invoke("npcVisit", {userId, profile})` spawns one forced walking customer (roll 0) and returns its visit ID (`NpcBudget`, `CompanyUnavailable`, `NoStock`, `NoParking` otherwise); `Invoke("npcSnapshot")` returns `{count, visits = {visitId, plotId, state, history, snaps, space, placementId, orderNumber, carrying, loadTest, customerNumber}, loadSnaps, customerSnaps, snapLog}` (the last 20 snaps `{visitId, state, x, z, goalX, goalZ}`); `Invoke("npcReset")` hard-removes every NPC visit and returns `{removed}`; `Invoke("npcNextArrival", {userId, profile})` gives the company's next live arrival that profile (`BadArgument` unless an integer ≥ 1, `NoActiveSave` without a save); `Invoke("npcGiveUp", visitId)` sends a customer from WalkingIn … CheckingOut out (`NotGivingUp` otherwise); `Invoke("npcLoadTest", {seconds = 10..120})` fills every plot to its budget with load-test NPCs and returns `{spawned, peakLive, windows, minFps, meanFps, snaps, left}`. `snapshot` also reports `customerVisits`, `abandonedCustomers` and the server `clock`. While customers are paused no NPC arrives; `npcVisit` ignores the pause. BLOCKED until PC-3 and routed to CM2-UV (j): screenshots of the avatars, walk/idle animation, carried-tree pose, RESERVED label, queue, "Thanks so much!" and the avatar beside a "#N HERE" car on phone, tablet and 1080p PC.
- **Save-slot commands (CM2-S1):** `Invoke("saveAction", {userId, action, payload, requestId?})` sends one `Save.*` request (through the remote handler for the real player, directly for the shadow); `Invoke("saves", userId)` lists the saves; `Invoke("flush")` forces a save of every session; `Invoke("lockSave", {userId, saveId})` and `Invoke("unlockSave", {userId, saveId})` set and clear a fake foreign lock (`jobId = "studio-test-thief"`, 300 s) on a save of that profile only. `snapshot`, `act`, `visit`, `customerOrders` and `setStaff` return `NoActiveSave` without a played save; `rejoin` reloads the active save.
- Every fake DataStore enforces the 50-character key limit (KeyNameLimit).
- **Teleport without a free plot:** BLOCKED in Studio (TeleportService is unavailable there); covered by the headless SaveSlotService teleport tests and the friends-test checklist. Progress is printed as `[PLAYTEST] PASS|FAIL|SKIP <id> <name> | <detail>` and a `[PLAYTEST] SUMMARY ...` line; `ServerStorage` attributes `PlaytestStatus` (`running`/`done`), `PlaytestSummary` and `PlaytestReport` (JSON) carry the result. Poll `PlaytestStatus` until `done`. In Edit mode `require(ServerStorage.UnitTest.Playtest.RunPlaytest).run(nil, {mode="full"})` prints `[PLAYTEST] REFUSED NoHook`.
- **Second player:** the official Studio MCP has no multi-client mode, so a shadow company for the synthetic user ID `999999999001` is loaded and gets its own plot; the real Player acts as attacker next to the shadow's tree and car (plot isolation). Only the shadow company is changed by fixtures (`setStaff`); the real company changes only through normal actions. **Co-op (CM2-S2):** the shadow is the second member of "Playtest Duo" and a second synthetic user `999999999002` (`StudioTestService.SHADOW_2_USER_ID`) is the third; `saveAction` and `act` accept both, and `Invoke("shadow2Leave")` makes the second one leave. Both act only through `saveAction`/`act`, so they hit the server paths a real client would. A real 2-client run (two clients typing the code, HUD cash on both screens) and a join while another server plays the save are BLOCKED in Studio and stay on the friends-test checklist (backlog order 15).
- The script, the hook module (`src/server/Services/StudioTestService.lua`) and the unit tests live only in the Studio project; the publish build excludes them (section 6).
- Proximity prompts only appear when the target is on screen: before pressing E, place the character and point the camera at the pickup tree or car.
- Known limit: the Play viewport captured black in `screen_capture`, so world checks are numeric (instance paths, positions, bounding boxes) rather than visual.

## 4. Nonfunctional budgets (initial targets, subject to Studio measurement)
- No permanent runaway NPC count; configurable caps per plot/server.
- UI actions should acknowledge quickly; network timeouts produce actionable errors rather than double charges.
- Autosave does not exceed Roblox DataStore budget under a 6-player load.
- Persisted company record stays comfortably under DataStore size limits; compact historical data.
- Mobile performance target: stable gameplay at 30 FPS on representative midrange devices; adjust NPC density and decorations as needed.
- No server errors during a 30-minute multi-client soak test.
These are targets, not measured achievements.

## 5. Evidence and reporting
Each test run records date, build commit SHA, environment (CLI/Studio, platform), scenario ID, PASS/FAIL/BLOCKED and logs/screenshot link. Never mark Studio tests as passed based only on code inspection. Maintain defects with severity: blocker, critical, major, minor. Fix financial duplication, data loss, permission bypass and exploitable purchases before other polish.

## 6. Release checklist
- [ ] Publish from `release.project.json` (`rojo build release.project.json --output release.rbxlx`), never from `default.project.json`: the release build has no `ServerStorage.UnitTest` and no `StudioTestService` (check the built file for instances named `UnitTest`, `RunPlaytest` and `StudioTestService`)
- [ ] All G0–G5 gates pass with evidence
- [ ] Save/rejoin and multi-server lock verified
- [ ] Place setting Max Players = 12 (6 plots; a solo player without a free plot is teleported)
- [ ] No unapproved paid product enabled
- [ ] All third-party assets/licenses reviewed
- [ ] Owner models integrated and visual QA completed
- [ ] English strings complete, no concatenated sentences (Roblox auto-translation), touch and keyboard input checked
- [ ] Error handling and recovery tested
- [ ] Owner explicitly approves publication

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
| STF-01 | Staff energy and break area (CM2-25/26) | −0.2/s on shift, +2/s resting, clamped 0..100; tired at 20, rested at 100; the default break area is the first free candidate (else candidate 1); every candidate fits the lot; `checkBreakArea` refuses with `OutsideLot`, `KeepClear` (box, fence), `TooClose`, `InvalidBreakArea`; rest points rotate with the area; the Cashier post is (16, counter z − 2.5); a tree may not stand in the break area (`Staff_Test`, `Stocking_Test`) |
| STF-02 | Schema 16 | migration 15 → 16 adds `LotManager` 0, energy 100 and a candidate break area without changing balances; 101, NaN, rotation 45 and `LotManager` 2 are refused (`BusinessState_Test`) |
| STF-03 | Staff director (CM2-25/26) | a hired Cashier walks from its seat to (16, −16.5) and stands anchored; `cashierReady` only `OnDuty`; a tired Cashier rests at its seat and returns rested (G16); a tired Lot Worker finishes its load first; the Lot Worker loads the oldest order exactly once (revision +2, one review), a player then gets `AlreadyCarried`; it restocks a sold spot from a bay (same species preferred) and drops a taken spot without changes; no wages in 30 simulated minutes; energy saved as whole numbers without a dirty flag and restored on reload; letting staff go or a lost avatar releases the claim; reload and plot release remove staff without transactions; `maxPerServer` caps staff; load staff loop and clear (`StaffNpcService_Test`); the counter serves only while the Cashier is on duty, else the walk-out applies (`CustomerCheckout_Test`) |
| NPC-04 | NPC routes | lot-frame routes avoid the stand and bays (inflated by `Clearance` 3) and the counter (`CounterClearance` 1.5), stay inside the lot and mirror on plots 4–6; a start inside an obstacle walks out first (`NpcPath_Test`, `GameConfig_Test`); looks come from the own palette (`NpcLook_Test`) |
| PROG-01 | Pavilion prerequisites incomplete | no upgrade |
| PROG-02 | All prerequisites met, sufficient cash | one upgrade and one debit |
| QUEST-01 | Claim reward twice (CM2-G11: `QuestBoard_Test` "claims once and returns the configured reward", "locks the bonus until quests 1-3 are claimed"; `CompanyStateService_Test` "claims a quest through handle exactly once"; `DailyRewardService_Test` "claims day 1 into the active save once") | only first grants reward; a replayed request ID is `DuplicateRequest`, a new one `AlreadyClaimed` |
| QUEST-02 | Quest board rotation (CM2-G11, `QuestBoard_Test` "rotation drops progress and pays nothing offline", "rejects a claim for another period") | a new 4-h window replaces the board with zero progress; an old-period claim is `QuestsRotated`; nothing pays for offline time |
| DAILY-01 | Daily streak (CM2-G11, `DailyRewards_Test`; `DailyRewardService_Test` "resets the streak by server time", "refuses a concurrent claim while one is in flight", "reverts the profile when the save refuses the grant") | one claim per UTC day; consecutive days advance and wrap after day 7; a missed day resets to day 1; a concurrent claim is `ClaimBusy`; a refused grant leaves the profile unclaimed |
| DAILY-02 | Group bonus (CM2-G11, `DailyRewardService_Test` "doubles once per claim and only for group members") | members get 2× once per claim; non-members and a failing group check 1×; `GroupId = 0` hides the line and never calls `IsInGroup` |
| ADVENT-01 | Advent calendar window and doors (CM2-A1, `AdventCalendar_Test`; `AdventService_Test` "opens today's door into the active save once", "rejects a future door and closes after Dec 24", "grants boost, decor and the specials") | UTC dates by integer maths; doors 1..today open Dec 1–24, a later door is `DoorLocked`, outside the window `CalendarClosed`; each door pays its `GameConfig.Advent.Doors` reward once; Cash Rush clamps at the cap; decor goes into `decorInventory` (schema 22) |
| ADVENT-02 | Advent once per player (CM2-A1, `AdventService_Test` "pays each door once per player across two saves", "refuses a concurrent open while one is in flight", "reverts the door when the save refuses the grant", "refuses bad payloads, missing saves, direct company calls and floods", "validates the reward extras") | a door opened in one save is `AlreadyClaimed` in another; a concurrent open is `ClaimBusy`; a refused grant clears the door's bit; `companies:handle` answers `Forbidden`; the 25th open in 60 s is `RateLimited`; bad reward extras are `InvalidReward` |
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
| DEM-01 | Demand simulation (CM2-SALE2, `DemandSimulation_Test`) | 1000 visits (customers 1-1000, rolls `(seed × 0.1 + i × 0.61803398875) % 1`, seeds 1-3) on four fixed lots; each prints `[SALE2]` with the rate and asserts its target range |

## 3. Integration playtests
A. Fresh user joins, gets free plot, starter inventory and tutorial; no unintended Roblox purchases.
B. Supplier order debits once; delivery countdown survives disconnect; truck arrival, the automatic drop into the bay and stock transitions are consistent (CM2-G14 plan, `docs/archive/plans/CM2-G14.md`, playtest steps 1–3).
C. Stock trees within plot boundaries, reject collisions and keep-clear areas; a row places all or none; store mode returns a tree to receiving without duplication (CM2-G14 plan, playtest step 36).
D. Customer chooses affordable tree, queues, pays; cashier handles queue, lot worker automates tasks; no salaries charged.
E. Prices affect conversion; auto pricing respects manual override state and limits (CM2-G7 plan).
F. Parking, land and HQ upgrades enforce prerequisites and unlock correct slots.
G. Two personal businesses cannot spend each other's money or stock.
H. Shared company: invite, join, role enforcement, owner disconnect, simultaneous purchase requests, session migration.
I. Reload restores all placements, upgrades, employees, stats, pricing and orders.
J. Localization and accessibility across input modes; no UI clipped by phone safe areas. Layout rules, device matrix and the Studio device-simulator checks (blocked until PC-3, then CM2-UV (f)) are in `docs/archive/plans/CM2-40.md`; the headless layout tests are `UiTheme_Test`. The modal rule (one dialog at a time, picker as base layer, finder over it) is covered headless by `ModalCoordinator_Test` (CM2-UVF1). World labels: `LabelDeclutter_Test` and the `UiTheme_Test` world label case (CM2-UVF2). Far labels: `LabelDeclutter.decide` hides labels beyond their range or behind the camera (CM2-UVF7). Dialog text fit: `UiTheme_Test` save row case; Studio probe H4b (CM2-UVF4). Picker list height: `UiTheme_Test` picker list case (CM2-UVF5). Team footer on Solo: `CoopSave_Test` Solo code case; Studio CM2-UVF6. Save picker request flow (busy list retry, refresh during a request, transient busy status): `SaveListSync_Test` (CM2-SP1).
K. Event flags work only during Christmas event window; no offline passive payout.
L. Monetization is active at launch (owner decision 2026-11-21): every product needs a receipt test pass (grant once, replay rejected, offline player, failed grant retried) before the owner publishes. Headless test list: `docs/archive/TEST_PLAN_2026-11-26.md`. Real test purchases of one product of each kind stay BLOCKED until the owner provides IDs (CM2-46b playtest).
M. Friends test (live, 2–5 players): docs/FRIENDS_TEST.md (CM2-47a).

## 3b. Studio playtest procedure (driven through the Roblox Studio MCP)
- Start Play (Server + Client). The server unit-test runner is `require(ServerStorage.UnitTest.RunUnitTest)(nil, 10)` in the Server data model.
- Customers are random and orders expire after 120 s, so use `ServerStorage.StudioTestHook` (Studio only): `Invoke("forceCustomer", n)` gives the next live arrival of every loaded save profile `n` and roll 0, like `npcNextArrival` (`NoActiveSave` without one) (profiles 5, 17, 29, … want a Medium Fraser Fir; profiles 8, 20, 32, … a Medium Douglas Fir); `Invoke("advanceClock", seconds)` fast-forwards deliveries and order expiry; `Invoke("customerOrders", userId)` returns the order summary.
### Repeatable run (CM2-G20, CM2-FAST)
- Call `return game:GetService("ServerStorage"):WaitForChild("StudioTestHook"):Invoke("runPlaytest", { mode = ... })` in the Server data model of a running Play session; it returns `"started"`.
- Modes: `smoke` (13 steps, at most 180 s: `02a`, `02`, `03`, `04`, `05`, `07`, `08`, `09`, `13`, `19`, `41`, `22`, `23`), `full` (72 steps, BUILD `cm2-a1`) and `soak` (`minutes` 1..30, default 10; 7 steps). Step 69 `SURFACE_GAPS` (CM2-FLICK) scans ground-level flat parts for coplanar overlaps; step 70 `SUPPLIER_CART` (CM2-SUP) orders a mixed cart, checks replay and forged cost refusal, delivery and sell back. Step 71 `ADVENT_CALENDAR` (CM2-A1, `Steps/Advent.lua`) sets the calendar's date with `adventNow`, opens doors 1–3 on Dec 3 (door 4 `DoorLocked`), the Dec 6 special, checks the doors after a rejoin and across a second save, and the closed calendar on Dec 25.
- `only = {"<id>", ...}` with `smoke` or `full` adds those steps and, transitively, their `needs`, in full-run order; a need outside the run counts as met; an unknown ID prints `REFUSED UnknownStep <id>`; with `soak` it is `REFUSED BadOptions`. `holdSeconds` 0..60 holds step 41 at the checkout queue for captures.
- Output: `[PLAYTEST] PASS|FAIL|SKIP <id> <name> | <detail>` lines and a `[PLAYTEST] SUMMARY ...` line; `ServerStorage` attributes `PlaytestStatus` (`running`/`done`), `PlaytestSummary` and `PlaytestReport` (JSON) carry the result. Poll `PlaytestStatus` until `done`. In Edit mode `require(ServerStorage.UnitTest.Playtest.RunPlaytest).run(nil, {mode="full"})` prints `[PLAYTEST] REFUSED NoHook`.
- Which run when: DECISION_LOG 2026-11-26 "faster work, shorter tests". Step details: the header comment of each `Steps/*.lua` module and of `Support/Fixtures.lua`; history in `docs/archive/TEST_PLAN_2026-11-26.md`.
- Layout (CM2-RF): `RunPlaytest.lua` is the runner, helpers live in `Playtest/Support/`, steps in `Playtest/Steps/` and share one strict context table; a module that would pass 800 lines gets a new one.
- Hook commands (walking customers, staff, saves; CM2-N1, CM2-25/26, CM2-S1): `docs/archive/TEST_PLAN_2026-11-26.md`; code in `src/server/Services/StudioTestService.lua`.
- Every fake DataStore enforces the 50-character key limit (KeyNameLimit).
- **Teleport without a free plot:** BLOCKED in Studio (TeleportService is unavailable there); covered by the headless SaveSlotService teleport tests and the friends-test checklist.
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

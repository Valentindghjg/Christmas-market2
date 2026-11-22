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
| INV-01 | Add 3 then remove 2 | 1 remaining |
| INV-02 | Remove > available or negative/decimal quantity | rejected without mutation |
| INV-03 | Place/reserve/sell same item twice | only one success |
| BUY-01 | Insufficient cash | no debit, no order |
| BUY-02 | Duplicate request ID | charged once |
| BUY-03 | Client sends fabricated wholesale cost | ignored; server computes cost |
| BUY-04 | Order beyond capacity | rejected, no cash change |
| DEL-01 | Delivery not due | cannot unload |
| DEL-02 | Delivery due after reconnect | exactly one arrival |
| SALE-01 | Reserved tree sold | exactly one credit and stock decrement |
| SALE-02 | Customer abandons queue | reservation released |
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
B. Supplier order debits once; delivery countdown survives disconnect; truck arrival, unload and stock transitions are consistent.
C. Place trees within plot boundaries, reject collisions and invalid transforms; pickup/re-place preserves identity.
D. Customer chooses affordable tree, queues, pays; cashier handles queue, lot worker automates tasks; no salaries charged.
E. Prices affect conversion; auto pricing respects manual override state and limits.
F. Parking, land and HQ upgrades enforce prerequisites and unlock correct slots.
G. Two personal businesses cannot spend each other's money or stock.
H. Shared company: invite, join, role enforcement, owner disconnect, simultaneous purchase requests, session migration.
I. Reload restores all placements, upgrades, employees, stats, pricing and orders.
J. Localization and accessibility across input modes; no UI clipped by phone safe areas. Layout rules, device matrix and the Studio device-simulator checks (blocked until PC-3, then CM2-UV (f)) are in `docs/plans/CM2-40.md`; the headless layout tests are `UiTheme_Test`.
K. Event flags work only during Christmas event window; no offline passive payout.
L. Monetization is active at launch (owner decision 2026-11-21): every product needs a receipt test pass (grant once, replay rejected, offline player, failed grant retried) before the owner publishes.

## 3b. Studio playtest procedure (driven through the Roblox Studio MCP)
- Start Play (Server + Client). The server unit-test runner is `require(ServerStorage.UnitTest.RunUnitTest)(nil, 10)` in the Server data model.
- Customers are random and orders expire after 120 s, so use `ServerStorage.StudioTestHook` (Studio only): `Invoke("forceCustomer", n)` makes the next arriving customer profile `n` and converts it (profiles 5, 17, 29, … want a Medium Fraser Fir; profiles 8, 20, 32, … a Medium Douglas Fir); `Invoke("advanceClock", seconds)` fast-forwards deliveries and order expiry; `Invoke("customerOrders", userId)` returns the order summary.
- **Repeatable run (CM2-G20):** in the Server data model of a running Play session, `return game:GetService("ServerStorage"):WaitForChild("StudioTestHook"):Invoke("runPlaytest", { mode = "full" })` returns `"started"` and runs the whole sequence (36 steps: unit runner (at least 293 tests), `02a ACTIVE_SAVE` (play the save "Playtest A", creating it if absent), shadow join, order, delivery, unload, place, NPC sale, carry, hands-full, respawn, wrong car, load, plot isolation, expiry, Lot Worker, sell-back, in-session rejoin, accelerated soak, `ART_ASSETS` (ArtAssets exists, no duplicate names, every Blender mesh preloads), `24 SAVE_CREATE` (create "Playtest B", replayed request ID deduplicated), `25 SAVE_SWITCH` (same plot, saves isolated), `26 SAVE_RENAME`, `27 SAVE_DELETE` (typed-name confirmation, active save refused), `28 FAIL_CLOSED` (a stolen lock shows `SessionLocked` and refuses orders), `29 COOP_JOIN` (create and play "Playtest Duo"; the shadow joins with the code and shares the plot), `30 COOP_SHARED_CASH` (both members act on one cash balance; one request ID debits once), `31 COOP_RULES` (member actions `OwnerOnly`, seat limit, the old code stops working, resizing), `32 COOP_REMOVE` (a removed member loses access, re-joins, plays while the owner is elsewhere; the Duo is deleted from the members' lists), `33 LOCATOR_CLAIM` (the save-to-server map holds "Playtest A" for job `studio` with the player as host; a renewal succeeds), `34 ELSEWHERE` ("Playtest Far" is released after a switch; with a fake foreign map entry and a stolen lock its row shows `elsewhere`, Play returns `SaveInUseElsewhere` and `Save.Teleport` returns `TeleportUnavailable` in Studio; it plays again once cleared and is deleted), `35 FINDER` (the shadow's search creates a Duo, the player joins it through the finder as a Member on the returned plot, the full listing disappears and a third user gets `ListingGone`; leave, relist the same save, stop, relist, a switch removes the listing, the save is deleted), leak check, cleanup (back on "Playtest A", test saves including "Playtest Duo", "Playtest Far" and the finder save removed, the fake map entry cleared, both synthetic users leave)). `{ mode = "soak", minutes = 10 }` runs the literal real-time soak (6 steps: `01a ACTIVE_SAVE` first, no clock advance until its final drain).
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

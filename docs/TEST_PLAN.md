# Test and Quality Plan — Christmas Market 2
Status: PLANNED, NOT EXECUTED
Updated: 2026-11-19

## 1. Quality gates
G0: source structure valid, Rojo project resolves, static type/lint checks pass.
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
J. Localization and accessibility across input modes; no UI clipped by phone safe areas.
K. Event flags work only during Christmas event window; no offline passive payout.
L. Monetization remains off until explicit owner approval; any future receipt handling needs separate test pass.

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
- [ ] All G0–G5 gates pass with evidence
- [ ] Save/rejoin and multi-server lock verified
- [ ] No unapproved paid product enabled
- [ ] All third-party assets/licenses reviewed
- [ ] Owner models integrated and visual QA completed
- [ ] DE/EN strings and input modes checked
- [ ] Error handling and recovery tested
- [ ] Owner explicitly approves publication

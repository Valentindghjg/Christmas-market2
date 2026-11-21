# Claude Code — 50-task development backlog
Updated: 2026-11-19
Status: 50 GitHub issues created; **not yet implemented or verified**.

## How to work
- Read CLAUDE.md and the canonical docs before starting.
- Work in dependency order, but parallelize independent tasks where safe.
- Each issue must end with implementation, tests, progress log, commit SHA, and reviewer evidence.
- Do not close issues solely on code generation; verify acceptance criteria.
- The identifiers CM2-01..CM2-50 are **planning IDs**, not GitHub issue numbers. GitHub numbering may differ.
- Publication and paid actions require explicit owner approval.

## P0 — Fundament
- [x] [CM2-01](https://github.com/Valentindghjg/Christmas-market2/issues/1)
- [x] [CM2-02](https://github.com/Valentindghjg/Christmas-market2/issues/2)
- [x] [CM2-03](https://github.com/Valentindghjg/Christmas-market2/issues/3)
- [x] [CM2-04](https://github.com/Valentindghjg/Christmas-market2/issues/4)
- [x] [CM2-05](https://github.com/Valentindghjg/Christmas-market2/issues/5)
- [x] [CM2-06](https://github.com/Valentindghjg/Christmas-market2/issues/6)
- [x] [CM2-07](https://github.com/Valentindghjg/Christmas-market2/issues/7)
- [x] [CM2-08](https://github.com/Valentindghjg/Christmas-market2/issues/8)
- [x] [CM2-09](https://github.com/Valentindghjg/Christmas-market2/issues/9)

## P1 — Spielbarer Kern
- [ ] [CM2-10](https://github.com/Valentindghjg/Christmas-market2/issues/10)
- [ ] [CM2-11](https://github.com/Valentindghjg/Christmas-market2/issues/11)
- [ ] [CM2-12](https://github.com/Valentindghjg/Christmas-market2/issues/12)
- [ ] [CM2-13](https://github.com/Valentindghjg/Christmas-market2/issues/13)
- [ ] [CM2-14](https://github.com/Valentindghjg/Christmas-market2/issues/14)
- [ ] [CM2-15](https://github.com/Valentindghjg/Christmas-market2/issues/15)
- [ ] [CM2-16](https://github.com/Valentindghjg/Christmas-market2/issues/16)
- [ ] [CM2-17](https://github.com/Valentindghjg/Christmas-market2/issues/17)
- [ ] [CM2-18](https://github.com/Valentindghjg/Christmas-market2/issues/18)
- [ ] [CM2-19](https://github.com/Valentindghjg/Christmas-market2/issues/19)

## P2 — Wirtschaft & Automatisierung
- [ ] [CM2-20](https://github.com/Valentindghjg/Christmas-market2/issues/21)
- [ ] [CM2-21](https://github.com/Valentindghjg/Christmas-market2/issues/22)
- [ ] [CM2-22](https://github.com/Valentindghjg/Christmas-market2/issues/23)
- [ ] [CM2-23](https://github.com/Valentindghjg/Christmas-market2/issues/24)
- [ ] [CM2-24](https://github.com/Valentindghjg/Christmas-market2/issues/25)
- [ ] [CM2-25](https://github.com/Valentindghjg/Christmas-market2/issues/26)
- [ ] [CM2-26](https://github.com/Valentindghjg/Christmas-market2/issues/27)
- [ ] [CM2-27](https://github.com/Valentindghjg/Christmas-market2/issues/28)
- [ ] [CM2-28](https://github.com/Valentindghjg/Christmas-market2/issues/29)

## P3 — Ausbau & Inhalte
- [ ] [CM2-29](https://github.com/Valentindghjg/Christmas-market2/issues/30)
- [ ] [CM2-30](https://github.com/Valentindghjg/Christmas-market2/issues/31)
- [ ] [CM2-31](https://github.com/Valentindghjg/Christmas-market2/issues/32)
- [ ] [CM2-32](https://github.com/Valentindghjg/Christmas-market2/issues/33)
- [ ] [CM2-33](https://github.com/Valentindghjg/Christmas-market2/issues/34)
- [ ] [CM2-34](https://github.com/Valentindghjg/Christmas-market2/issues/35)
- [ ] [CM2-35](https://github.com/Valentindghjg/Christmas-market2/issues/36)
- [ ] [CM2-36](https://github.com/Valentindghjg/Christmas-market2/issues/37)

## P4 — Multiplayer & Oberfläche
- [ ] [CM2-37](https://github.com/Valentindghjg/Christmas-market2/issues/38)
- [ ] [CM2-38](https://github.com/Valentindghjg/Christmas-market2/issues/39)
- [ ] [CM2-39](https://github.com/Valentindghjg/Christmas-market2/issues/40)
- [ ] [CM2-40](https://github.com/Valentindghjg/Christmas-market2/issues/41)
- [ ] [CM2-41](https://github.com/Valentindghjg/Christmas-market2/issues/42)
- [ ] [CM2-42](https://github.com/Valentindghjg/Christmas-market2/issues/43)
- [ ] [CM2-43](https://github.com/Valentindghjg/Christmas-market2/issues/44)

## P5 — QA & Release
- [ ] [CM2-44](https://github.com/Valentindghjg/Christmas-market2/issues/45)
- [ ] [CM2-45](https://github.com/Valentindghjg/Christmas-market2/issues/46)
- [ ] [CM2-46](https://github.com/Valentindghjg/Christmas-market2/issues/47)
- [ ] [CM2-47](https://github.com/Valentindghjg/Christmas-market2/issues/48)
- [ ] [CM2-48](https://github.com/Valentindghjg/Christmas-market2/issues/49)
- [ ] [CM2-49](https://github.com/Valentindghjg/Christmas-market2/issues/50)
- [ ] [CM2-50](https://github.com/Valentindghjg/Christmas-market2/issues/51)

## Follow-up tasks (created 2026-11-21 from the engineering review)
- [ ] **CM2-R1 Studio regression run of the hardened session layer.** Depends on: Rojo plugin reconnect + Studio API access. Accept: Studio Play Server runs `RunUnitTest` with 85/85 passing; a manual order -> deliver -> unload -> place -> NPC sale shows the sold tree disappearing; leave + rejoin restores cash/stock.
- [ ] **CM2-R2 Version Studio art in the Rojo project.** Depends on: none. Accept: `ReplicatedStorage.ArtAssets` is exported to `.rbxm` files mapped in `default.project.json`, so `rojo build` contains the imported models and a fresh checkout no longer falls back to primitives.
- [ ] **CM2-R3 Surface a failed-closed session to the player.** Depends on: none. Accept: when a session becomes unavailable mid-game the server sets `CompanyReady=false` with an error code and the HUD shows it; covered by a headless test.
- [ ] **CM2-R4 Expand strict Luau type analysis beyond GameConfig/Economy/Inventory.** Depends on: Roblox definitions file in CI. Accept: `luau-lsp analyze` passes for all `src/shared` modules in CI.

## Follow-up tasks (created 2026-11-21 from the reference-game play-test)
Source: [REFERENCE_GAME_LIVE_TEST.md](REFERENCE_GAME_LIVE_TEST.md) §11 (gaps G1–G18). All are planning IDs only; no GitHub issues were created. Use original names and art; never copy reference assets or names. Numbers taken from the reference go into config with evidence tier OBSERVED; anything else is PROVISIONAL.

**P1 — core loop corrections**
- [ ] **CM2-G1 Customer car loading.** Depends on: P1 checkout. After checkout the server spawns the sold tree as a pickup with a sequential order number and links it to the customer's parked car. The player (later: Lot Worker) carries it to the car with the same number; delivery completes the order and the car leaves. Accept: headless tests for exactly-once completion, wrong-car rejection with a localized message, one carried item per player, and no completion for another plot's order; Studio run shows the order billboard → carry → roof-loaded car leaving.
  - Status 2026-11-21: implemented (CustomerOrderService, Order.* actions, prompts with reach check, cars/pickup trees/carried tree, localized notices). Headless tests PASS.
  - Studio 2026-11-21 (Play Server+Client, MCP): billboard → carry → roof-loaded car leaving PASS; wrong car rejected with the localized notice and the tree stays carried; second pickup while carrying rejected ("hands full"); fast load +2 reputation (95 → 97), slow load +1; expired orders removed (cars, pickup trees, prompts) with the penalty. Fixed in Studio: pickup trees stood inside the sales-stand collision box. **Open:** Lot Worker auto-load, respawn drop and plot isolation with two players in Studio (see CM2-G21).
- [ ] **CM2-G2 Car-based customer arrival tied to parking.** Depends on: CM2-G1. Customers spawn as cars on a road lane, park only in free parking spaces of the target plot and walk in. Accept: concurrent customers per plot ≤ parking spaces (config, tier 1 = 2); a full lot makes cars drive past; despawn and cleanup verified with no leaked NPCs after 10 min in a Studio soak run.
  - Status 2026-11-21: parking cap and drive-past implemented and tested headlessly; cars drive in from the road and park.
  - Studio 2026-11-21: with 2 spaces taken a third converting customer drove past (+1 drive-past, no third car); HUD parking now shows the effective 2 spaces (was 0). Accelerated leak test: 6 sale/expiry cycles incl. two concurrent customers, `CustomerOrders` empty after every cycle, never more than 2 active. Fixed: the market alley stood on the parking spaces (moved). **Open:** the literal 10-minute Studio soak (CM2-G21).
- [x] **CM2-G3 Checkout prompt content.** Depends on: P1 checkout. The prompt shows species, size class, per-tree height and price; each tree gets a stable height within its size range at delivery. Accept: test that height stays inside the size range and survives save/rejoin; prompt strings localized DE/EN.
  - Status 2026-11-21: done. Stable per-tree height (TreeHeight), localized display-tree labels with species, size, height and price. Headless tests PASS.
  - Studio 2026-11-21: labels read "Frasier Fir · Medium · 7.6 ft · $82"; heights survived a Play stop/start. Fixed: the default stocking slots put trees behind/inside the sales stand. Screenshot evidence is missing because the Play viewport captured black.
- [x] **CM2-G4 Receiving bays and storage caps.** Depends on: P1 delivery. Map Delivered/Stored to 4 bays (one order or kind per bay, ≤ 9 trees per bay) plus total delivery storage (base 30, +10 per lot expansion), all in config. Accept: an order is rejected server-side when no bay or storage is free; bay contents persist; the Supplier UI shows "free / bays" exactly like the server.
  - Status 2026-11-21: server rules (NoFreeBay, BayCapacity, StorageFull) and receiving summary implemented and tested; HUD shows bays and storage from the server summary.
  - Studio 2026-11-21: the fifth order was rejected with "All receiving bays are full – stock trees out first"; the HUD line "Bays 4/4 · Storage 4/30" matched the server summary; an order of 10 trees was rejected (BayCapacity). Bay persistence is covered by the headless save/migration tests, not by a Studio rejoin with filled bays.
- [ ] **CM2-G14 Automatic unload and bay-to-display stocking.** Depends on: CM2-G4. The truck drops its load into a bay automatically after an on-bay countdown; the player stocks from a bay with size select, rotate, single place, row fill with gap control, and store-back mode. Server validates placement (inside plot, min spacing, checkout clearance). Accept: rejection reasons "outside lot / too close / keep clear" reproduced in headless tests; a row fill places N trees atomically or none; store mode returns the tree to the bay without duplication.

**P2 — economy and customers**
- [x] **CM2-G5 Supplier stock pool and helpers.** Depends on: CM2-G4. Finite per-size stock with a server refresh timer (≈ 4 min, config), HIGH/LOW demand tags, a recommended order, and sell-back at 25 % (receiving first, then lot, never reserved trees). Accept: tests for stock depletion and refresh, no sell-back of reserved trees, exact 25 % refund rounding, and idempotent sell requests.
  - Status 2026-11-21: done. Stock pool, ~4 min refresh, demand tags, advisory recommendation, sell-back (Supplier.SellBack) with idempotency; all acceptance tests PASS headlessly.
  - Studio 2026-11-21: ordering depleted the pool (9 → 6) and the timer refresh restored it (5 → 15) with new demand tags; the UI sell-back paid exactly $8 (25 % of $32); a repeated request ID was rejected (DuplicateRequest, no second payout); an empty bay was rejected (NotEnoughTrees); a tampered payload with a refund field was rejected (UnexpectedField). Reserved-tree protection was not reproduced live (headless only).
- [ ] **CM2-G6 Observed wholesale table and a Common starter species.** Depends on: none. Add wholesale per size for 4 starter species (values in REFERENCE_GAME_LIVE_TEST §4.1) with our own species names, and update the GAME_DESIGN evidence note. Accept: config validated by tests; GAME_DESIGN no longer says wholesale by size is unobserved.
- [ ] **CM2-G7 Price benchmark = wholesale × 5.** Depends on: CM2-G6. Replace the $82/$96/$105 "observed medium prices" note (they were player settings) and derive the "typical" price shown in the Pricing panel from wholesale × 5 (config). Accept: Pricing UI shows wholesale, typical, margin $/%, and a sentiment label; demand-model tests use the new benchmark.
- [ ] **CM2-G8 Lot appeal and decor appeal.** Depends on: P2 demand model. Lot appeal from trees on display and species × size variety (cap from lot size) raises price tolerance (+2 % observed); decor appeal adds sightseers and tips. Accept: both metrics shown in Analytics; unit tests for appeal growth over time and its effect on accepted price.
- [ ] **CM2-G15 Customer reviews and rating.** Depends on: CM2-G1. After loading, the customer leaves 1–5 stars and a short localized review based on service time; reputation gain scales with speed; the plot shows an in-world sign with company name and average rating. Accept: tests that slow service yields lower stars and less reputation; the rating persists and the sign updates within 2 s in Studio.
- [ ] **CM2-G16 Staff break area (decision first).** Depends on: owner/planner decision. Decide whether staff have fatigue and a break area (no wages remains binding). If yes: a placeable break area that layout respects, with staff resting there. Accept: decision recorded in DECISION_LOG; if adopted, a headless test that tired staff path to the break area and resume work.

**P3 — progression and content**
- [ ] **CM2-G9 Full progression ladder in config.** Depends on: P3 land/HQ. 6 lot-expansion levels, parking tiers, 4 HQ tiers with unlock lists, an end-game manager hire, and a late-game workshop feature, all as config with OBSERVED or PROVISIONAL tags. Accept: config schema test; Land UI lists requirements with progress exactly like the server's check.
- [ ] **CM2-G11 Daily reward streak and quest board.** Depends on: P3 quests. 7-day streak (cash and reputation rewards) and a board of 3 rotating quests (~4 h) plus a bonus quest unlocked by finishing all three; rewards claimed manually and idempotent. Accept: tests for streak reset by server time, double-claim rejection, and rotation without offline income.
- [ ] **CM2-G12 Day counter, day/night cycle, leaderboards.** Depends on: none. Visible day counter and a lighting cycle (config length); leaderboards for cash earned, reputation and playtime (no "Robux spent"). Accept: the cycle runs in Studio without frame drops on the mobile emulator; leaderboard writes are cached and rate-limited (test).
- [ ] **CM2-G13 Layout mode checklist.** Depends on: P3 layout and decor. Stock zones with species and height filters and priority, a free movable HQ (checkout and staff move with it; blocked by other structures), and a decorate inventory with search, put-away and clear-all. Accept: each item demonstrated in Studio and covered by server validation tests for overlaps and plot bounds.
- [ ] **CM2-G18 HQ radio.** Depends on: none. Optional in-world radio prompt cycling through original or licensed-free tracks. Accept: plays only for the owner's plot area; no copyrighted audio.

**P4 — multiplayer and UI**
- [ ] **CM2-G10 Multi-save and co-op size tiers.** Depends on: P4 company mode. Save picker per plot with Solo/Duo/Trio/Quad saves, rename, delete with confirmation, and a region tag. Accept: tests for save isolation, delete requiring confirmation, and session locking per save.

**P5 — monetization (design only)**
- [ ] **CM2-G17 Season pass design.** Depends on: owner approval for any paid feature. Document a free and premium track fed by sales and quests. Accept: design doc only; premium track and Robux products stay disabled per PRODUCT_SPEC until the owner explicitly approves.
- [ ] **CM2-G19 HQ upgrade footprints vs lot layout.** Depends on: CM2-G14. The imported upgrade models are much larger than the starter stand (MarketUpgrade3 38 × 40 studs, MarketPavilion 39 × 40, starter 32 × 24), so for upgraded HQ tiers the stand overlaps parking spaces 1–2 (z ≈ 51..91 vs cars at z = 55), the pickup row and the stocking area. Accept: a Studio or headless footprint check of every HQ tier against parking spaces, pickup row, stocking slots and checkout; offsets or the stand position are corrected where they collide.
- [ ] **CM2-G20 Repeatable Studio playtest.** Depends on: none. The manual MCP sequence of 2026-11-21 (order, advance clock, unload, place, force a customer, carry, wrong car, load, expiry, sell-back, soak) lives in a runnable script under `tests/studio/` that drives the Studio-only `StudioTestHook` and reports PASS/FAIL per step. Accept: one command in a Studio Play Server prints a summary; it never runs outside Studio.
- [ ] **CM2-G21 Remaining Studio verification for G1/G2.** Depends on: none. Not yet done in Studio: Lot Worker auto-load of a waiting order, a respawn dropping the carried tree back at its pickup spot, plot isolation (a second player cannot carry or load another plot's order), the literal 10-minute soak, and screenshot evidence of cars, pickup trees and labels (the Play viewport captured black through the MCP; Edit mode has no world because it is built at runtime). Accept: each item recorded PASS/FAIL in PROGRESS.md with a screenshot where possible.

## Launch replanning (2026-11-21)
The owner interview changed scope and priorities (PRODUCT_SPEC, top section). Next step: the planner re-prioritises CM2-10..50 and CM2-G6..G18 into a launch order for the 2026-11-29 / 2026-12-06 target and writes one plan per task in `docs/plans/` before implementation. Tickets that conflict with the new decisions (collaborative roles CM2-38, DE/EN localization CM2-43, monetization prep CM2-46) are re-scoped in that pass.

## Milestone gates
- P0: tools, unit tests, safe persistence and network foundation.
- P1: order -> delivery -> display -> NPC checkout -> rejoin playable in Studio.
- P2: realistic demand, customer behavior and staff automation.
- P3: upgrade/decor/quests/analytics implemented and persisted.
- P4: shared company, UI, input and localization verified.
- P5: original art polish, seasonal event, security and QA; no release without approval.

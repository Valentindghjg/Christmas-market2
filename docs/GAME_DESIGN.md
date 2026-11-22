# Game Design Document — Christmas Market 2
Status: APPROVED DIRECTION / detailed values are PROVISIONAL
Updated: 2026-11-19
Authority: [PRODUCT_SPEC.md](PRODUCT_SPEC.md). **The owner decisions of 2026-11-21 at the top of PRODUCT_SPEC supersede this document where they differ** (title Christmas Tree Village, English launch, manual checkout, visible customers and staff, Solo/Duo/Trio/Quad saves, active Robux shop, Advent events and calendar, all reference functions and numbers). This document operationalizes, but does not override, the owner's decisions.

## 1. Product and player experience
Christmas-tree retail tycoon: buy stock from supplier, wait for truck, unload, place trees, set prices, attract and serve NPC customers, earn cash and reputation, upgrade the lot and HQ. Distinct snowy map, gameplay close to reference screenshots, original assets and cleaner festive UI. No rebirth, no offline income, no ongoing employee wages. Two modes: separate businesses on a shared server and opt-in collaborative companies.

## 2. Evidence policy
- **OBSERVED in screenshots:** supplier, pricing, delivery/stock zones, checkout, staff, HQ, plot upgrades, decor, quests, analytics, store; a "typical" retail price of about 5× the medium wholesale (REFERENCE_GAME_LIVE_TEST §4.3; the earlier $82/$96/$105 were one player's own settings, not game defaults); small 80% and large 130% of medium; wholesale per species and size (REFERENCE_GAME_LIVE_TEST §4.1); cashier hire $1,200, lot worker $1,800; Christmas Pavilion prerequisites: expansion 1, parking 4, reputation 250, cash $2,500.
- **OWNER DECIDED:** close-to-original mechanics; own map; dynamic demand by price/species/season/reputation; optional automatic pricing; delivery truck; detailed customer AI; staff automation; no wages/offline earnings/prestige; dual multiplayer modes; permanent data/statistics; DE/EN; Christmas-only events.
- **PROVISIONAL / INFERRED:** all unobserved numeric tuning, delivery seconds, conversion rates, NPC profiles, first-join balance, map size, exact decoration costs and later HQ tiers. These must remain in config, not silently be described as original-game facts.

## 3. Core loop and item lifecycle
1. Player claims an unoccupied plot; personal company data loads.
2. Supplier UI shows unlocked species, sizes, unit wholesale price, stock, available delivery slots.
3. Server validates order against funds, stock unlock, capacity and request ID; debits cash exactly once; creates PendingOrder.
4. Truck arrives after configured delay. Items move from PendingOrder to Delivered; owner or worker unloads to Stored. No duplication across reconnect.
5. Player places trees from Stored into Displayed via bounded plot placement. Items have stable unique IDs. Pickup moves back to Stored.
6. Customer selects eligible displayed tree; server reserves item; customer navigates to checkout, pays, then item is consumed exactly once. On timeout, reservation is released.
7. Sale credits company cash, increments counters and reputation based on outcome; unlock progression is re-evaluated.

Inventory buckets: Pending -> Delivered -> Stored -> Displayed -> Reserved -> Sold; every transition is atomic in the authoritative company session. No item can exist in two buckets.

## 4. Initial economy and pricing
Currency: in-game dollars (not Robux). All money represented as nonnegative integer amounts.
Tree IDs: DouglasFir, FrasierFir, NobleFir, BlueSpruce, in the OBSERVED supplier and unlock order (REFERENCE_GAME_LIVE_TEST §4.1, `GameConfig.SpeciesOrder`). IDs are stable save keys; the display name of `FrasierFir` is "Fraser Fir" (owner spelling fix 2026-11-21). The species list grows with the HQ-tier species (CM2-G9).
Price benchmark ("typical" price): medium = 5 × medium wholesale (GameConfig.Pricing.BenchmarkMultiplier), unless an observed card differs (GameConfig.Pricing.TypicalMediumOverride): Douglas 140, Fraser 160, Noble 184 (observed override; 5 × 37 would be 185), Blue Spruce 210, all OBSERVED; the 5 × rule is the PROVISIONAL extrapolation for species without an observed card; the Small and Large benchmarks follow the 80 %/130 % rule; new saves start at the typical price (PROVISIONAL). Small = round(0.8 × medium), large = round(1.3 × medium).
Wholesale per tree is **OBSERVED per species and size** (REFERENCE_GAME_LIVE_TEST §4.1), Small/Medium/Large: Douglas Fir 21/28/41, Fraser Fir 24/32/46, Noble Fir 28/37/54, Blue Spruce 32/42/61. The 80 %/130 % size rule applies to retail prices only; supplier costs come from this table.
Player can set medium price per species, or toggle auto-price. Auto-price periodically targets a configurable market benchmark with a stock-sensitive adjustment, respects server min/max, and never changes existing reserved sales.
Suggested **provisional** controls: price min 50% of benchmark, max 250%; price updates at most once every 3 seconds; quantity per order 1–100; demand score clamped [0,1]. Starting cash/reputation shown in screenshots (84/90) are **not established first-join defaults**; choose playtest-friendly defaults and label them.

Provisional customer conversion score:
`clamp(baseSpeciesInterest * priceFactor * reputationFactor * seasonalFactor * varietyFactor * stockFactor, 0.02, 0.95)`
where priceFactor decreases as sale price / benchmark of the tree's size increases, reputationFactor rises slowly with reputation, varietyFactor rewards diversity and seasonalFactor changes during Christmas event. All coefficients in balance config. Prevent guaranteed purchases and runaway income.

## 5. Customers
NPC FSM: Spawn -> WalkToPlot -> Browse -> Choose -> ReserveTree -> Queue -> Checkout -> Exit; failure paths: LeaveUnhappy, Despawn, CancelReservation.
Each customer has a seeded preference for species and size, budget, patience, and optional time urgency. Server owns decisions and sale completion. Customer never buys unavailable, unreserved stock. Queue capacity is tied to checkout stations; cashier employee increases automated throughput. Bound NPC count per server and per plot; abort stalled pathfinding and release reservations. Track visits, conversion, abandoned queues, average spend and satisfaction.

## 6. Deliveries and staff
Delivery has request ID, order ID, dueAt, quantities and status. Arrival is a server-time transition, not dependent on client countdown. Unloading requires authorized player or hired lot worker; disconnected sessions restore outstanding orders. Hiring cashier or lot worker is a one-time in-game cash debit; no salaries or maintenance costs. Staff jobs use atomic claims and can be canceled/reassigned safely; upgrades affect capacity, not paychecks.

## 7. Progression
Cash + reputation + explicit prerequisites gate land, parking and HQ. Observed Pavilion upgrade: $2,500, 250 reputation, expansion level >=1, parking >=4. Observed benefits: 4 new tree types, 2 checkout stations, employee capacity 3, customer patience +12%; validate exact unlock IDs when reference content is available. Later HQ names in screenshot plan include Christmas Market Chalet and Christmas Lodge, but numeric requirements are UNKNOWN and must be configured provisionally.
No reset of long-term progress. Cosmetics/decoration influence appeal without becoming mandatory for basic progression.

## 8. Multiplayer
Personal mode: each player owns a plot, separate inventory and funds, visible neighbors; no trading.
*Superseded 2026-11-21 (PRODUCT_SPEC.md, owner decisions 2026-11-21): Solo/Duo/Trio/Quad saves with a 5-digit invite code, owner plus equal members, play while the owner is offline, one server per save, in-server teammate search.* ~~Collaborative mode: owner creates persistent company, invites friends, and sets role: Owner, Manager, Worker, Visitor.~~ Owner retains ownership even when offline; when absent, permitted members may continue authorized operations using a session-locked company save. Only one server has write authority for a company at a time; joining elsewhere should route to existing session if possible or show safe read-only/unavailable state. No pooled currency transfer between separate companies.

## 9. Quests, analytics and history
Quests: e.g. deliver N trees, sell N of species, hire a worker, unlock parking; reward claims idempotent. Daily/seasonal quests reset only on server timestamps and never grant offline passive income.
Statistics: lifetime sales, gross revenue, purchases, conversion rate, customers served/lost, top species, average price, delivery times and upgrade history. Store compact aggregates plus bounded last 100 transaction records. Leaderboards should use privacy-safe aggregate metrics and cached writes, not each transaction.

## 10. UI, accessibility, localization
Visual direction: evergreen/dark green, warm cream, gold accents, seasonal motifs, uncluttered layouts. HUD for cash/reputation/lot; supplier, pricing, employees, land, HQ, inventory/layout, decor, quests, analytics, shop. Touch targets >=44 logical pixels where practical; readable text, no color-only status; safe areas and scalable panels. Keyboard/mouse, touch and gamepad navigation; translate UI keys DE/EN with English fallback. Monetary actions show cost and confirmation for high-impact purchases.

## 11. Christmas event and monetization
*Superseded 2026-11-21 (PRODUCT_SPEC.md, owner decisions 2026-11-21): Robux shop active at launch with the reference's products and prices; loot boxes in version 2; one event per Advent Sunday plus an Advent calendar Dec 1–24.*
Christmas-only events, no generic year-round seasonal calendar. Base game remains functional when event is inactive.
Robux features (gamepasses/boosts/packs) are design-only placeholders until owner explicitly approves activation and product IDs. No live paid transactions, publication or randomized paid rewards without approval, platform policy checks and accurate probability disclosure. Do not implement dark patterns.

## 12. Release criteria
All primary transactions server-authoritative and replay-safe; save/rejoin consistent; both multiplayer modes permission-tested; mobile/tablet/PC/console flows navigable; critical paths covered by automated tests and Roblox Studio multiplayer playtests; no known high-severity exploits; owner signs off publication. See [TEST_PLAN.md](TEST_PLAN.md).

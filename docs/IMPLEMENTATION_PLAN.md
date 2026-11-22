# Implementation plan — Christmas Market 2

Status: initial screenshot-based design specification. Reference archive contains 32 images, but image binaries have **not** been committed to this repository. No original game source or models were accessed.

## 1. Evidence and uncertainty
Observed: snowy conifer forest; straight two-lane road, tunnel, leaderboards, roadside player plots; fenced sales lot with red tent, tree storage bays, parking, sign, festive lighting. UI includes supplier, catalog, pricing, employees, land, analytics, layout, decorate, quests, shop, cash and reputation. Unobserved internals must be implemented as hypotheses and validated through gameplay tests.

Reference screenshot IDs in the external ZIP: IMG_0160 (overhead lot editor), IMG_0162 (quests), IMG_0165/0185 (decor catalog), IMG_0166/0184 (pricing), IMG_0167/0183 (employees), IMG_0169 (analytics), IMG_0171–0173 (lot views), IMG_0176–0181 (store), IMG_0182 (HQ), IMG_0186–0190 (supplier), IMG_0191–0194 (map and leaderboards). IMG_3797 depicts a different game listing and must not be treated as tree-lot gameplay.

## 2. World and original 3D asset plan
Create a low-poly winter map with dense snow-capped firs, gently rolling terrain, two-lane road with yellow centerline and sidewalks, mountain tunnel, multiple roadside plots, parking vehicles, ranking boards, road signs and holiday props. Each plot: fenced rectangular ground, front gate, red sales tent, checkout, delivery/stocking bays on side, decorative trees, parking and stock zones. Make reusable original meshes/models for tree variants, size tiers, wood fencing, festive lights, tent, signs, trucks, crates, customer NPCs, cash register and HQ buildings. Keep original visual references in a review sheet and compare camera angles, scale and silhouette in Roblox Studio. Do not rip proprietary meshes, textures or scripts.

## 3. Server-authoritative systems
- Plot allocation and loading: join -> claim vacant plot -> load saved progression -> initialize inventory and cash -> spawn.
- Supplier: tree species, size (small/medium/large), price, stock rotation, availability, demand tags, order cart, purchasing and delivery timer; separate delivered, stored and displayed trees. Validate delivery-bay and inventory capacity before ordering.
- Tree placement: player-defined stock zones, overlap bounds, inventory assignment, move/remove, persistence and preview.
- Customer NPC state machine: spawn -> navigate to plot -> browse -> choose tree -> carry/queue -> checkout -> exit. Price sensitivity, patience and preferences are hypotheses pending observation.
- Pricing: per-species medium price; small = 80% of medium, large = 130%; whole-dollar display. The $82/$96/$105 screenshot prices were a player's own settings; the reference's typical price is about 5× medium wholesale (REFERENCE_GAME_LIVE_TEST §4.3, CM2-G7). Price higher -> fewer buyers (visible UI guidance).
- Reputation and appeal: reward satisfactory transactions, diversity/quantity of displayed trees influence appeal. Screenshot shows appeal 1%, trees on display 6/16, kinds 4/8, reputation 90.
- Employees: cashier $1,200; lot worker $1,800; manager gated by HQ 4. Cashier handles checkout; lot worker deliveries, stocking, loading. Use safe job reservation and idempotent operations.
- HQ and land: upgrade gates from UI. Starter Sales Tent -> Christmas Pavilion: lot expansion 1, parking 4 spaces, reputation 250, cash $2,500. Unlocks four new trees, two checkout stations, three employee capacity, +12% customer patience. Later stages: Christmas Market Chalet, Christmas Lodge. Keep data-driven tiers.
- Decoration catalog: paths, lights, rustic, Christmas, fences/signs; items arrive as one crate, then editable placement, rotate and remove; persist transforms.
- Quests, analytics, rankings, daily rewards: server-owned counters and idempotent claims; avoid client-trusted payouts.
- Shop: optional Robux gamepasses, boosts, packs and randomized items shown in screenshots. Implement **only after explicit approval**, with Roblox policy compliance, truthful odds and receipt validation; gameplay must function without spending Robux.

## 4. Software architecture
Use Roblox Studio with Rojo and Luau; separate ReplicatedStorage/shared definitions, ServerScriptService/services, StarterPlayer/client controllers and StarterGui. Suggested modules: PlotService, EconomyService, InventoryService, SupplierService, DeliveryService, PlacementService, CustomerService, CheckoutService, EmployeeService, ProgressionService, QuestService, AnalyticsService, SaveService; client controllers for world interactions and UI. Shared schema/versioned config for items, species, upgrades and prices. RemoteEvents/RemoteFunctions with rate limiting and server validation. DataStore retries, session locking, migration strategy and recovery.

## 5. UI fidelity
Create responsive mobile-first panels: dark-green side navigation, gold accents, warm cream cards, wooden border and seasonal garlands. Screens: Tree Supplier, Catalog, Pricing, Employees, Land, Analytics, Layout, Decorate, Quests, Shop. Top-right HUD: cash, reputation, lot status. Preserve scroll, item cards, buy buttons, disabled locks and purchase totals. Support touch gestures, controller and mouse.

## 6. Delivery phases and acceptance
1. Repository scaffold and basic Studio launch. Test: Rojo sync works, smoke test passes.
2. Graybox map and plot allocation. Test: two players get separate plots and camera framing matches reference.
3. Supplier, inventory, delivery and stock zones. Test: purchase decrements cash once, capacity enforced, deliveries persist.
4. Customer, pricing and checkout. Test: sale transfers exactly one item, calculates revenue correctly, NPC exits.
5. HQ, parking, land, reputation, employees. Test: prerequisites and job actions enforce rules.
6. Decoration, quests, analytics. Test: save/reload retains placements, rewards cannot be claimed twice.
7. Original models and UI visual pass. Test: screenshot comparisons on mobile and desktop with tracked deviations.
8. Performance, security and release QA. Test: exploit attempts rejected, DataStore failures handled, NPCs bounded, no severe mobile frame drops.

## 7. Decisions to verify in the original game
Exact map dimensions and lot coordinates; all supplier species, sizes and price ranges; stocking/delivery limits; customer spawn frequency, preferences and patience; reputation calculation; precise employee automation; quest catalog; HQ progression beyond tier 2; decoration placement rules; multiplayer interactions and monetization. Record each as OBSERVED / INFERRED / UNKNOWN before coding.

## 8. Codex task protocol
Create an issue/checklist per phase; inspect screenshots when uploaded; define interfaces and tests first; implement one vertical slice at a time; run automated tests and Studio playtests; commit with concise change summaries. Do not claim full parity until tested against the actual game.

# Progress log

2026-11-19: Owner decisions accepted; product spec and milestones recorded. Initial pure Luau modules for account/inventory/order workflow added. **Not tested in Roblox Studio**. Screenshot binaries and final 3D assets are pending. Monetization disabled pending separate approval.

2026-11-19: Added detailed [GAME_DESIGN.md](GAME_DESIGN.md), [TECHNICAL_ARCHITECTURE.md](TECHNICAL_ARCHITECTURE.md), [TEST_PLAN.md](TEST_PLAN.md) and [DECISION_LOG.md](DECISION_LOG.md). Recorded standing instruction to commit project-relevant decisions and updates to GitHub during active chats, without routine confirmation. This is documentation work only; no additional gameplay implementation or Studio tests were completed in this step.

Next: add automated unit tests with a Luau-compatible runner, wire session-safe persistence and server-validated remotes, then implement plot allocation and delivery loop. Later upload screenshot binaries, integrate owner-created models and obtain explicit approval before paid products or publication.

2026-11-19: Owner reassigned all 3D modeling, map creation and asset integration to Claude Code. ChatGPT plans and reviews; Claude Code implements; owner approves paid actions and publication. Documentation updated. No claim that Claude Code has been started or Studio tests run.

2026-11-19: Created 50 numbered Claude Code implementation issues (CM2-01 through CM2-50) spanning P0-P5. Central index: docs/CLAUDE_BACKLOG.md. These are planned/open tasks, not completed gameplay. Owner approval still required for publication and paid actions.

2026-11-19: Completed the first P0 audit and Rojo/tooling baseline. Added `rokit.toml` with Rojo 7.7.1, confirmed `rojo serve default.project.json` at localhost:34872 and `rojo build` succeeds. Added a framework-free Studio test runner and Economy/Inventory/BusinessState contract tests. In a real Roblox Studio Play Server, 11 direct contract checks passed: tier pricing, invalid money rejection, inventory mutation, server-derived wholesale cost, and no partial mutation on insufficient funds. The audit fixed caller-controlled purchase pricing and finite-integer validation; see `docs/P0_AUDIT.md`. The current Studio Rojo connection did not add the new ServerStorage test root live, so automatic runner discovery remains **BLOCKED pending plugin reconnect/reopen**; no automatic runner result is claimed. Versioned schema, persistence, remotes and gameplay loop remain unimplemented.

2026-11-19: Added pinned Selene 0.32.0 and StyLua 2.6.0 tools, `selene.toml` with Roblox standard-library support, and the `Quality` GitHub Actions workflow. Local validation passed: `stylua --check src tests`, `selene src tests`, and `rojo build default.project.json --output build.rbxlx`. Automated Studio test-runner discovery remains blocked only by the already-connected Rojo plugin not refreshing a newly added root mapping during this session.

2026-11-19: Implemented schema v2 migration in `BusinessState`: personal-company identity, owner role, revision, request-deduplication container and save timestamp are added without changing v1 balances or stock. Added a v1-to-v2 migration contract test. Static checks passed (`stylua`, `selene`, `rojo build`); Studio execution of this new code is **BLOCKED** because the existing Rojo plugin link stopped applying new source changes during this session. A plugin reconnect/reopen is required before a Play-mode migration result can be recorded. No DataStore calls were made; save/load implementation still requires the appropriate Studio API setting and DataStore permissions.

2026-11-19: Added `PersistenceService` with atomic `UpdateAsync` lock acquisition, retry/backoff, session renewal on save, release, v1-to-v2 migration on load and fail-closed result codes. Added fake-store contract tests for concurrent writers and lock loss. No live DataStore test was performed: it requires **Save & load data** scopes (`universe-datastores.objects:read` and `universe-datastores.objects:update`) plus **Game Settings → Security → Enable Studio Access to API Services**. The new modules also require a Rojo reconnect before Studio can execute them.

2026-11-19: Added shared Protocol v1 validation for supplier orders. It accepts only species, size and quantity; client-provided pricing or other unexpected fields are rejected. Request IDs are bounded and persisted in company state for replay prevention, and an in-memory per-player/action rate limiter is supplied for server handlers. Added contract tests for valid payloads, price forgery rejection, deduplication and request floods. Remote binding remains deferred until session loading wires an authoritative company state to each player.

2026-11-19: Added `CompanyStateService`, which loads a personal company through the persistence lock, serializes mutations per company, enforces Owner/Manager authorization, records the request before mutating, persists the complete result before returning success and marks the session unhealthy on save failure. The initial action handler performs only validated supplier orders and uses the server-owned catalog price. Added tests for exactly-once purchase/revision behavior and replay rejection. Player RemoteFunction binding remains the next integration step.

2026-11-19: Extended the core loop with persisted supplier orders: a validated order debits server-derived cost once, remains Pending until its due timestamp, transitions to Delivered and enters storage only through one successful unload. The delivery duration uses a documented fallback in `GameConfig` and is intended to be superseded by a server ConfigService value. Added a complete order→delivery→unload contract test.

2026-11-19: Wired the player lifecycle to the authoritative company service and exposed one `ReplicatedStorage.Remotes.BusinessAction` RemoteFunction. Joins load a session-locked personal company; any load failure sets a player attribute and leaves actions unavailable rather than creating a replacement save. Leaves and shutdown save/release their session. The client exposes only a thin request helper and receives no authority over pricing, inventory or cash.

2026-11-19: Added a server-only PlotService. It allocates the first free approved plot, never accepts a client-selected plot, preserves one plot per player, verifies ownership and releases plots on leave. Added allocation and release tests. Physical plot anchors/spawns will bind to this service once the non-model graybox layout is added.

2026-11-19: Added persistent placement data in schema v3 and a PlacementService. A tree can only move from stored stock to a finite, bounded transform on the assigned plot; pickup atomically returns it to storage. Both operations are validated server actions and use deterministic request-based placement IDs. Added a storage→display→storage contract test.

2026-11-19: Added the first server-owned customer checkout primitive. It consumes one displayed placement once, derives sale price from the persisted medium price and tree size, then atomically credits cash/revenue/sales and a provisional reputation point. Added a one-time settlement test. NPC navigation, reservation and queueing remain separate work.

2026-11-19: Added PricingService with server-enforced medium-price bounds derived from data-driven catalog benchmarks. Manual price changes persist in company state and disable automatic pricing; both valid and out-of-range changes have contract tests. Player action wiring for the pricing screen remains pending UI work.

2026-11-19: Added pure server-owned Demand scoring. It combines price ratio, reputation and seasonal/variety/stock factors into a bounded conversion score; tests verify that higher price lowers conversion and edge values remain safe. NPC spawning and pathfinding still need to consume this score.

2026-11-19: Migrated company state to schema v4 with persisted employee flags and added EmployeeService. Cashier and lot-worker hires debit only server-configured one-time costs, reject duplicates and write financial history. Added cashier hire contract coverage; action-protocol/UI binding remains pending.

2026-11-19: Connected employee hires to Protocol v1 and CompanyStateService. Only Owner/Manager actions can reach EmployeeService; unrecognized IDs are rejected before mutation, and the existing serial save path supplies replay safety.

2026-11-19: Added WorldService, a source-controlled original Roblox-primitive winter graybox: snow ground, asphalt road, six named plots with delivery bays and spawn markers, starter tents, checkout counters, a supplier truck and nine tree variants. It never imports external assets and preserves an existing world instance. Source validation passes; **Studio visual/walkability verification is BLOCKED** until the connected Rojo plugin is reconnected and applies the new service.

2026-11-19: Added the first mobile-friendly client UI: a status HUD and a Tree Supplier panel. Its order button generates a request ID and calls the existing server `BusinessAction` contract; it never computes price, cash or inventory locally. Studio visual/input verification remains blocked pending Rojo reconnect.

2026-11-19: Closed CM2-01 (repository audit) and CM2-02 (reproducible Rojo toolchain) after their documented findings, setup, build evidence and progress records were reviewed. Remaining issues stay open until their specific CI/Studio acceptance evidence exists.

2026-11-19: Added 60-second authoritative autosave for all healthy loaded company sessions. Save failures mark the corresponding session unhealthy and block subsequent business actions instead of risking further unsaved mutations. Added autosave contract coverage with a fake persistence store.

2026-11-19: Started hardening the checkout lifecycle: displayed stock is now server-reserved with a fixed server-derived price before settlement, expires safely, and can only be credited once by the reservation owner. Existing records migrate to schema v5 with empty reservations.

2026-11-19: Added a bounded, stock-sensitive auto-pricing calculation. It persists through schema v6, is opt-in, uses only server state/configuration, and leaves prices already locked by checkout reservations untouched.

2026-11-19: Wired opt-in auto-pricing into a three-second server-owned scheduler. The scheduler enters the same company critical section as player actions and persists each updated company; a persistence failure marks that session unavailable rather than continuing unpersisted changes.

2026-11-19: Added deterministic server-owned NPC customer profiles for species/size preference, budget and patience. Profile compatibility is pure, bounded logic ready for the NPC state machine; client input cannot choose customer attributes.

2026-11-19: Added server-side candidate selection for NPCs. It ignores reserved stock, requires matching preference and budget, derives the actual sale price from the authoritative catalog, and provides a bounded demand conversion score.

2026-11-19: Added the server-side NPC visit transaction: a bounded demand roll can reserve one eligible tree under the profile's patience window, then settle through the existing exactly-once checkout API. Failed conversions do not mutate stock or reservations.

2026-11-19: Wired a bounded five-second customer-visit scheduler into healthy company sessions. It shares the authoritative company lock with player actions, performs no client-driven sale calculations, and persists each completed sale before reporting it as successful.

2026-11-19: Bound claimed personal plots to character spawning. After a successful company load and plot claim, the server moves the current and future character to that plot's authored spawn marker.

2026-11-19: Added persisted progression state and server-authoritative purchase services for lot expansions, parking and the Christmas Pavilion. Costs are charged only after all cash, reputation and prerequisite checks succeed; existing records migrate to schema v7.

2026-11-19: Exposed progression purchases through the validated, idempotent BusinessAction protocol. Clients can select an allowed upgrade only; prices, prerequisites, mutation and persistence remain server-owned.

2026-11-19: Added persistent customer-visit and abandonment aggregates plus a server analytics summary (conversion, average sale, revenue and spend). Existing records migrate to schema v8 without changing financial balances.

2026-11-19: Added a role-authorized Company.GetSummary query that returns only presentation-safe cash, reputation, progression and aggregate analytics. It rejects client-provided state fields and never exposes the full saved company record.

2026-11-19: Connected the mobile-friendly HUD to the filtered Company.GetSummary query. Cash, reputation and parking status refresh from server-derived state every five seconds and after placing an order.

2026-11-19: Connected the initial HUD and supplier action to the shared DE/EN localization catalogue using the Roblox locale with English fallback.

2026-11-19: Replaced the supplier UI's hardcoded wholesale price with a server-derived Supplier.RequestQuote response. The client remains display-only for pricing and cannot inject a cost into an order.

2026-11-19: Added a server delivery-reconciliation scheduler. Due orders transition once from Pending to Delivered under the company lock and are persisted immediately; repeated scheduler passes do not write or re-count completed arrivals.

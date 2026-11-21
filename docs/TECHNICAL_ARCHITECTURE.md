# Technical Architecture — Christmas Market 2
Status: DESIGN BASELINE; implementation partial
Updated: 2026-11-19

## 1. Toolchain and repository
Roblox Studio + Luau, Rojo project mapping in `default.project.json`, GitHub source of truth. Proposed additions: `aftman.toml` or pinned Rojo tool version, Luau linter/type checker, TestEZ or equivalent, CI checks for formatting/static analysis/unit tests. Do not claim Studio tests without actual Studio run.

```text
src/
  shared/       GameConfig, Economy, Inventory, BusinessState, Localization,
                Protocol, BalanceConfig, ItemCatalog, Types
  server/       main.server.lua, Services/, Persistence/, NPC/, World/
  client/       main.client.lua, Controllers/, UI/, Localization/
docs/           PRODUCT_SPEC, GAME_DESIGN, TECHNICAL_ARCHITECTURE,
                TEST_PLAN, MODEL_INTEGRATION, PROGRESS, DECISION_LOG
tests/          pure module tests and Studio integration test scripts
```

## 2. Authority and service boundaries
- SessionService: player/company join, ownership, lifecycle and cleanup.
- CompanyService: personal/collaborative company roles and authorization.
- PlotService: plot allocation, boundaries, plot ownership and access.
- EconomyService: all money movement and immutable transaction IDs.
- SupplierService: catalog, unlocks, order validation and quote creation.
- DeliveryService: order state machine, ETA, arrival and unloading.
- InventoryService: unique stock item IDs, capacity and atomic lifecycle.
- PlacementService: bounded transforms, collision checks, plot persistence.
- PricingService: manual/auto prices and effective price at reservation time.
- CustomerService: NPC spawning, preferences, FSM and pathfinding budgets.
- CheckoutService: reserve, queue, finalize sale, rollback/cancel.
- EmployeeService: hire once, task assignment, job lease and completion.
- ProgressionService: prerequisites, HQ/parking/land unlocks.
- QuestService: event counters, rewards and idempotent claims.
- AnalyticsService: aggregate counters and bounded history.
- MonetizationService: **feature-flagged off** until separate approval.
- PersistenceService: schema migrations, lock acquisition, save/retry/release.

Use dependency injection or explicit initialization ordering; avoid circular requires. Shared modules are data and pure logic only, never grant currency.

## 3. Network contract
All client-to-server calls are untrusted. Use a small versioned action protocol, not arbitrary client-defined price/cash/item payloads. Example action names:
`Supplier.RequestQuote`, `Supplier.PlaceOrder`, `Delivery.Unload`, `Inventory.Place`, `Inventory.Pickup`, `Pricing.SetMediumPrice`, `Pricing.SetAuto`, `Employee.Hire`, `Progression.Upgrade`, `Company.Invite`, `Company.SetRole`, `Quest.Claim`.
Request: `{version=1, requestId=<UUID>, action=<enum>, payload=<validated fields>}`. Response: `{ok, errorCode?, revision?, data?}`. Request IDs deduplicate financial actions within a session and persisted recent IDs where needed. Validate types, lengths, ranges, enum values, plot ownership, proximity where applicable, server-derived prices and role permissions. Per-action rate limits; never trust a client-supplied purchase cost, sale result, or inventory quantity.

Server->client: filtered state snapshots on join and revisioned deltas after mutations. Client can optimistically animate UI but server state wins. Avoid broadcasting private company details to other plots.

## 4. Data model (schema v1 proposal)
```lua
{
 schemaVersion = 1,
 companyId = "personal:<userId>" or "shared:<uuid>",
 ownerUserId = 123,
 mode = "personal" or "shared",
 members = { ["123"] = "Owner" },
 cash = 0, reputation = 0,
 inventory = {
   items = { [itemId] = { speciesId, sizeId, state, plotId, transform, orderId } },
   pendingOrders = { [orderId] = { requestId, lines, createdAt, dueAt, state } }
 },
 pricing = { medium = { [speciesId] = 82 }, automatic = false },
 progression = { hqTier = 1, landLevel = 0, parkingSpaces = 0, unlocks = {} },
 staff = { cashier = 0, lotWorker = 0 },
 layout = { placements = {} },
 quests = { counters = {}, claims = {} },
 stats = { lifetimeSales = 0, revenue = 0, visits = 0, lost = 0, bySpecies = {} },
 history = {}, recentRequests = {}, updatedAt = 0
}
```
Schema is a proposal; existing `BusinessState.lua` currently uses a simpler v1 shape and must be migrated carefully before production. Keep all persisted numeric values finite, capped and serializable. Store transforms as numeric arrays, not Instances/CFrames.

## 5. Persistence and concurrency
DataStore keys scoped by company ID; use UpdateAsync-based session lock with job ID and expiry/heartbeat, not a naive GetAsync/SetAsync last-write-wins. Acquire lock before enabling writes; renew while active; release at leave/shutdown; recover expired locks with a safety margin. Save after significant actions (debounced) plus periodic autosave and BindToClose; retries with exponential backoff and budget awareness. If load fails, block financial actions instead of creating a fresh default and overwriting existing progress. Use versioned migration functions and backup/rollback strategy. Shared-company single-writer policy; conflicts must not fork balances.

**Implemented policy (2026-11-21):** a company record is one DataStore key holding cash, inventory, orders, placements and recent request IDs together. Mutations run to completion inside the company critical section without yielding and only mark the session dirty; `CompanyStateService:flushDirty()` writes dirty sessions every `GameConfig.SaveFlushSeconds` (15 s) and re-saves every session at least every `AutosaveSeconds` (60 s) to renew the `SessionLockSeconds` (120 s) lock. Leave/shutdown perform a final save and release. A crash can therefore lose at most one flush interval, but never persists a debit without its effect. Transient save failures are retried on the next flush; lock loss, an invalid record, or `SaveFailClosedSeconds` (90 s) without a successful save stops mutations. A runtime error inside a critical section fails that session closed and it is never saved again. Future Robux receipt handling must force a flush before acknowledging a receipt.

Persist financial request IDs/reward claims enough to prevent replay after reconnect; ledger should be append-bounded with aggregate counters. Avoid DataStore budget exhaustion by batching updates.

## 6. Deterministic game state
Every state mutation runs through an authoritative company command queue or equivalent serialization boundary. A command verifies revision, role, prerequisites, capacity, cash and idempotency, then applies all state changes together and emits one revision. Orders, unloads, reservations and sales must not be split across independently saved balances and inventory. Time-driven transitions use `os.time()` server timestamps. On load, reconcile due deliveries without passive income.

## 7. Collaboration permissions
Owner: all company management and business actions; only owner can remove company or transfer ownership (ownership transfer deferred).
Manager: prices, inventory, staff and upgrades, cannot change owner.
Worker: unload, stock, serve checkout; no large purchases or role changes.
Visitor: read-only. Invitation and membership changes checked against authoritative company state; users can leave voluntarily. Personal plot never implicitly shares funds.

## 8. NPC performance
NPC simulation server-side with pooled rigs and configurable cap per plot/server. Limit PathfindingService calls, reuse waypoints, avoid per-frame full scans, cancel jobs on plot unload. Customer preferences seeded server-side; reservation timeouts release inventory. Use explicit FSM transition tables and telemetry on failures.

## 9. Asset boundary
Final 3D models supplied by owner; integration via stable asset IDs, pivots and attachments documented in `MODEL_INTEGRATION.md`. Scripts may use temporary invisible markers for tests but must not generate final art. If art missing, disable affected visual placement gracefully while keeping state safe.

## 10. Security and compliance
Validate all remotes, role membership, rate limits and server prices; ensure client cannot force NPC sales or bypass HQ requirements. Audit monetization receipt processing for replay safety. Never store personal data beyond required Roblox user IDs and game state. Restrict logs to operational diagnostics. Gamepass IDs and purchases remain disabled until owner approval.

## 11. Observability and rollout
Structured server logs for action type, request ID, company ID, result/error, latency and schema version; no unnecessary PII. Feature flags for collaborative mode, advanced NPCs, events and paid shop. Canary testing in private unpublished place before release. Maintain `PROGRESS.md` and `DECISION_LOG.md` with commit references and verified test results.

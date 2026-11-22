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
assets/art/     Blender sources (source/), normalized models (rbxm/, mapped to
                ReplicatedStorage.ArtAssets by Rojo), generated builds (_build/, ignored)
tools/art/      art pipeline CLI (Lune) and headless Blender scripts (CM2-AP)
```

## 2. Authority and service boundaries
- SessionService: player/company join, ownership, lifecycle and cleanup.
- CompanyService: save ownership and membership (Solo/Duo/Trio/Quad, owner + members, 5-digit invite code, one server per save; PRODUCT_SPEC.md, owner decisions 2026-11-21).
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
- MonetizationService: active at launch with owner-created product IDs; idempotent receipts; paid random items only from version 2 with PolicyService checks (PRODUCT_SPEC.md, owner decisions 2026-11-21).
- PersistenceService: schema migrations, lock acquisition, save/retry/release.

Use dependency injection or explicit initialization ordering; avoid circular requires. Shared modules are data and pure logic only, never grant currency.

## 3. Network contract
All client-to-server calls are untrusted. Use a small versioned action protocol, not arbitrary client-defined price/cash/item payloads. Example action names:
`Supplier.RequestQuote`, `Supplier.PlaceOrder`, `Delivery.Unload`, `Inventory.Place`, `Inventory.Pickup`, `Pricing.SetMediumPrice`, `Pricing.SetAuto`, `Employee.Hire`, `Progression.Upgrade`, `Company.Invite`, `Company.SetRole`, `Quest.Claim`, `Order.Carry`, `Order.Load`, `Order.Release`, `Supplier.SellBack` (implemented 2026-11-21; order interactions also arrive through server-side ProximityPrompts that are validated like remote calls, including a server reach check).
Request: `{version=1, requestId=<UUID>, action=<enum>, payload=<validated fields>}`. Response: `{ok, errorCode?, revision?, data?}`. Request IDs deduplicate financial actions within a session and persisted recent IDs where needed. Validate types, lengths, ranges, enum values, plot ownership, proximity where applicable, server-derived prices and role permissions. Per-action rate limits; never trust a client-supplied purchase cost, sale result, or inventory quantity.

Server->client: a one-way `Notify` RemoteEvent carries localized notice keys (order complete, wrong car, out of reach). Filtered state snapshots on join and revisioned deltas after mutations. Client can optimistically animate UI but server state wins. Avoid broadcasting private company details to other plots.

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

**Save slots (CM2-S1, implemented 2026-11-22).** Each player owns a profile that lists their saves; each save is its own company record.
- **Company schema 11** (`BusinessState.SCHEMA_VERSION = 11`): adds `saveName` (valid UTF-8, 1–24 code points) and `saveSize` (`Solo`, `Duo`, `Trio`, `Quad`; S1 writes `Solo`). Migration 10 → 11 sets the default name `Tree Lot 1` when the name is missing or invalid and `saveSize = "Solo"`; the v1 path sets both. The save's company ID is `save:<saveId>`. `validate` ignores the persistence envelope fields `_session`, `_deletedAt`, `_migratedTo`, `_migratedAt` and `_migratedFrom`. In S1 the profile entry's name is the source; the record's `saveName` is a copy written on every load and on renaming the active save.
- **Save ID (fix round 2):** `<ownerUserId>_<16 lowercase hex>`, at most 36 chars (`SaveProfile.SAVE_ID_MAX_LENGTH`). `SaveProfile.newSaveId(userId, guid)` takes the GUID from `HttpService:GenerateGUID(false)`, drops the hyphens, lowercases it and keeps characters 17–32; the user ID is written by `SaveProfile.userIdText` (`string.format("%d", userId)`, because `tostring` writes 19-digit numbers in exponent form). `SaveProfile.isSaveId`: a string of at most 36 bytes matching `^(%d+)_(%x+)$` with 1–19 digits, exactly 16 hex characters and no uppercase. The user-ID prefix makes IDs unique across players; within one player 62 random bits remain, and a collision fails closed (`ProfileCorrupt` on Create, `SaveDeleted` on Play) without data loss. IDs are never reused; deleted saves keep a tombstone.
- **Profile schema v1** (`SaveProfile.lua`, `SaveProfile.VERSION = 1`):
```lua
{ profileVersion = 1, userId = 123, createdAt = 0, updatedAt = 0,
  saves = { { saveId, name, role = "Owner", size = "Solo", createdAt, lastPlayedAt } }, -- creation order
  nextSaveNumber = 1, lastSaveId = nil, legacyState = "Pending" | "Done" | "None",
  legacySaveId = nil, recentCreates = { { requestId, saveId } } }                      -- newest last, at most 10
```
`validate` also accepts role `Member` and sizes Duo/Trio/Quad (S2 placeholders), and rejects duplicate save IDs and more than `GameConfig.Saves.MaxSavesPerPlayer` (50) entries. Names are trimmed, single-spaced, 1–24 code points, no control characters and no `#`; they are filtered with `TextService` at submission (the broadcast result must equal the name).

## 5. Persistence and concurrency
DataStore keys scoped by company ID; use UpdateAsync-based session lock with job ID and expiry/heartbeat, not a naive GetAsync/SetAsync last-write-wins. Acquire lock before enabling writes; renew while active; release at leave/shutdown; recover expired locks with a safety margin. Save after significant actions (debounced) plus periodic autosave and BindToClose; retries with exponential backoff and budget awareness. If load fails, block financial actions instead of creating a fresh default and overwriting existing progress. Use versioned migration functions and backup/rollback strategy. Shared-company single-writer policy; conflicts must not fork balances.

**Implemented policy (2026-11-21):** a company record is one DataStore key holding cash, inventory, orders, placements and recent request IDs together. Mutations run to completion inside the company critical section without yielding and only mark the session dirty; `CompanyStateService:flushDirty()` writes dirty sessions every `GameConfig.SaveFlushSeconds` (15 s) and re-saves every session at least every `AutosaveSeconds` (60 s) to renew the `SessionLockSeconds` (120 s) lock. Leave/shutdown perform a final save and release. A crash can therefore lose at most one flush interval, but never persists a debit without its effect. Transient save failures are retried on the next flush; lock loss, an invalid record, or `SaveFailClosedSeconds` (90 s) without a successful save stops mutations. A runtime error inside a critical section fails that session closed and it is never saved again. Future Robux receipt handling must force a flush before acknowledging a receipt.

**Save slots (CM2-S1, implemented 2026-11-22).** `SaveSlotService` fills the SessionService role of section 2: profile I/O, the legacy migration call, the `Save.*` actions (`Remotes.SaveAction`), play, switch, leave, the teleport seam and the active-save registry.

| Store | Key | Holds |
|---|---|---|
| `ChristmasMarket2_CompanyState_v1` (`PersistenceService.STORE_NAME`) | `company:personal:<userId>` | The legacy record. Never deleted or overwritten again; only `_migratedTo`, `_migratedAt` and `_session` change |
| same store | `company:save:<saveId>` | One company record per save, with its own session lock |
| `ChristmasMarket2_Profiles_v2` (`SaveSlotService.PROFILE_STORE_NAME`; v2 since fix round 2) | `profile:<userId>` (`SaveSlotService.profileKey`) | The player profile |

Every key contains the user ID as a fixed substring, so RTBF erasure templates can match it. Store names are not scoped by environment (out of scope). `Profiles_v1` held only Studio test profiles with old 32-hex save IDs that the current `isSaveId` rejects; it is abandoned and never read.

**Key budget.** Roblox DataStore keys are limited to 50 characters (`KeyNameLimit`, `SaveProfile.KEY_MAX_LENGTH`). The worst case is a 19-digit user ID:

| Family | Format | Max chars |
|---|---|---|
| Company legacy | `company:personal:<userId>` | 36 |
| Company save | `company:save:<userId>_<16hex>` | 49 |
| Profile | `profile:<userId>` | 27 |
| S2 invite code (foreseen; 5 digits per backlog) | `invite:<code>` | 12 |
| S3 save-to-server map (foreseen; MemoryStore, limit 128) | `save:<saveId>` | 41 |

Rule for S2 and S3: a key holding a save ID gets a prefix of at most 14 chars; a key holding a user ID, at most 31. Every new key family adds a row here and a case to the key-length test (SaveSlotService_Test "keeps every key within 50 characters for a 19-digit user ID"). S2 member lists stay inside the company record (no new key). Every fake DataStore in the tests enforces the 50-character limit.
- **Lock-free profile:** every profile change is one `UpdateAsync` transform applied to the stored value (3 attempts, 1 s and 2 s apart), so a second server can never lose an update and S2 can write to another player's profile. Transforms reset their results at the start (they can run more than once). An unreadable profile fails with `ProfileUnavailable`, an invalid one with `ProfileCorrupt`; neither is ever overwritten with a fresh default.
- **Legacy migration** (`PersistenceService:migrateLegacy(userId, saveId, saveName)`, called on the first profile open while `legacyState = "Pending"`): a. `UpdateAsync(company:personal:<userId>)`: absent → `NoLegacy` (no write); already `_migratedTo` → that save ID wins; locked by another unexpired server → `SessionLocked`; otherwise take a deep copy without `_session` and write our lock. b. migrate the copy to the current schema as `save:<saveId>` with `saveName`, `saveSize = "Solo"` and `_migratedFrom = <legacy key>`; on failure return `MigrationFailed`. c. `UpdateAsync(company:save:<saveId>)`: absent → write the record without `_session`; `_migratedFrom` equal → no write (idempotent); anything else → `MigrationConflict`. d. `UpdateAsync(legacy)`: when the lock is ours or absent, set `_migratedTo` and `_migratedAt` and clear `_session`; the data stays unchanged; another job's lock → `SessionLocked`, a non-table record → `MigrationFailed` (no write). Store errors after retries return `LoadFailed`. Steps b–d run in `_finishMigration` under a `pcall` (a thrown error → `MigrationFailed`), and every failure after locking the legacy record clears our lock once (fix round 2); the clear touches only a `_session` with our job ID, and if it fails the lock expires after `SessionLockSeconds`. Every step is idempotent, so a crash between steps is repaired by the next open. A brand-new player gets one starter save "Tree Lot 1".
- **Tombstones:** `PersistenceService:markDeleted` (one `UpdateAsync`) refuses a save locked by another unexpired server (`SaveInUse`) or by this server (`SaveActive`); otherwise it sets `_deletedAt` and keeps all data. `load` refuses `_deletedAt` (`SaveDeleted`) and `_migratedTo` (`SaveMigrated`) without writing. Deleting needs the typed save name (case-insensitive, `SaveProfile.confirmMatches`).
- **Play and switch:** a save claims a plot keyed by its company ID, preferring the plot of the save it replaces; a switch saves and unloads the old save first. Without a free plot the player is teleported to another server of the place (`TeleportData.cm2NoFreePlot = {saveId, attempt}`, at most `MaxPlotTeleports` = 3 attempts); nothing is loaded in that case. `PlayerRemoving` and `BindToClose` call `leave(userId, true)` for every active save (the shadow included), which waits for an in-flight save action.
- **Shutdown:** `beginShutdown` refuses new save work; BindToClose waits for `pendingCount()` (final leaves plus busy actions) up to 25 s.
- **Fail-closed surfacing (CM2-R3):** `CompanyStateService:setSessionFailedHandler` is called once per session, never while unloading, with `SessionLocked` (lock lost), `SaveFailed` (`NotLoaded` or `SaveFailClosedSeconds` without a save) or `InternalError`. `main.server.lua` sets `CompanyReady = false` and `CompanyError = <code>` for every player on that save; the HUD and the save picker show `Localization.saveErrorKey(code)`. Playing the save again reloads it once the lock is back.

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
Final 3D models supplied by owner; integration via stable asset IDs, pivots and attachments documented in `MODEL_INTEGRATION.md`. Scripts may use temporary invisible markers for tests but must not generate final art. If art missing, disable affected visual placement gracefully while keeping state safe. Art pipeline (CM2-AP): Blender `.blend` -> FBX -> Open Cloud mesh upload (or Studio import fallback) -> normalized `.rbxm` -> Rojo -> `ReplicatedStorage.ArtAssets`; `ArtLibrary` looks it up and the primitive fallback stays (`assets/art/README.md`, `MODEL_INTEGRATION.md`).

## 10. Security and compliance
Validate all remotes, role membership, rate limits and server prices; ensure client cannot force NPC sales or bypass HQ requirements. Audit monetization receipt processing for replay safety. Never store personal data beyond required Roblox user IDs and game state. Restrict logs to operational diagnostics. Gamepass IDs and purchases remain disabled until owner approval.

## 11. Observability and rollout
Structured server logs for action type, request ID, company ID, result/error, latency and schema version; no unnecessary PII. Feature flags for collaborative mode, advanced NPCs, events and paid shop. Canary testing in private unpublished place before release. Maintain `PROGRESS.md` and `DECISION_LOG.md` with commit references and verified test results.

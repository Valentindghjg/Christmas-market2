# CM2-S1 — Save slots per player (covers CM2-G10 part 1, CM2-R3, CM2-11 re-scope)

Written by: `planner` (Opus 5.5, high). Implemented by: the agent for the tier below. Playtested by: `playtester` (Sonnet 5.5, medium). Reviewed and committed by: `reviewer` (Opus 5.5, medium). Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.
Status: steps 1–13 and Fix round 1 implemented (uncommitted, headless 198/198). The Studio playtest failed on the DataStore key limit; **Fix round 2** below is the remaining work and supersedes earlier text where they differ.

## Goal
On joining, a player picks one of their saves from a scrolling list, can create, rename and delete saves (deleting needs the typed save name) and switch saves mid-session. Each save has its own company record, lock and plot. The old personal company becomes the first save without data loss. A save that fails to load or fails mid-game sets `CompanyReady=false` with an error code that the HUD shows. If no plot is free, the player is teleported to another server.

## Source of truth
- Backlog launch order line 3, plus the original CM2-G10, CM2-R3 and CM2-11 entries. Lines 4 and 5 (CM2-S2, CM2-S3) only shape the data model here.
- PRODUCT_SPEC 2026-11-21: "Saves and multiplayer" (unlimited saves, rename, delete with confirmation, no region field) and "Server" (12 players, 6 plots, a solo player without a free plot goes to another server).
- DECISION_LOG 2026-11-21: launch order (S1 changes the key from user ID to save ID) and engineering review (dirty-flag flush). DECISION_LOG 2026-11-22: CM2-G20 (shadow company `999999999001`).
- TECHNICAL_ARCHITECTURE §2, §3 and §5. TEST_PLAN §3b. Skill rule `roblox-security` "Text filtering as a workflow".

## Implementer tier
Tier: L. Reason: new save schema (v11) and profile record, migration of existing records, per-save session locks, a new remote with validation and rate limits, and concurrency between switching, leaving and shutdown.

## Skills to load
roblox-collaboration-mode, roblox-data, roblox-server-data, roblox-networking, roblox-security, roblox-architecture, roblox-gui, roblox-input, roblox-localization, roblox-luau-core, roblox-luau-patterns, roblox-luau-types, roblox-tooling.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/SaveProfile.lua` | New | Pure profile schema: `new`, `validate`, name rules, ID check, list view |
| `src/server/Services/SaveSlotService.lua` | New | Profile I/O, legacy migration call, the `Save.*` actions, play, switch, leave, shutdown, teleport seam, active-save registry (the "SessionService" role of TECHNICAL_ARCHITECTURE §2) |
| `src/client/SavePicker.client.lua` | New | Save picker, delete confirmation and the "Saves" button |
| `src/shared/BusinessState.lua` | Change | Schema 11 (`saveName`, `saveSize`) |
| `src/shared/GameConfig.lua` | Change | `GameConfig.Saves` |
| `src/shared/Protocol.lua` | Change | `Protocol.SaveActions`, `Protocol.validateSaveRequest` |
| `src/shared/Localization.lua` | Change | New keys (EN and DE), `Localization.SaveErrorKeys` |
| `src/server/Services/PersistenceService.lua` | Change | `STORE_NAME`, `keyFor`, `wait` injection, tombstones, `migrateLegacy`, `markDeleted` |
| `src/server/Services/CompanyStateService.lua` | Change | `loadCompany`, session-failed handler, `setSaveName` |
| `src/server/Services/PlotService.lua` | Change | Keyed by holder string (company ID) with a preferred plot |
| `src/server/main.server.lua` | Change | Lifecycle through SaveSlotService, `SaveAction` remote, teleport, R3 handler, shutdown |
| `src/server/Services/StudioTestService.lua` | Change | Active-save resolution, shadow via saves, new commands |
| `src/client/UiController.client.lua` | Change | R3 HUD text, hide the panel without a save, reset on switch |
| `tests/headless/run.luau` | Change | Register `SaveSlotService` and `SaveProfile` |
| `tests/studio/Cases/*_Test.lua` | New/Change | See Tests |
| `tests/studio/Playtest/RunPlaytest.lua` | Change | New steps, threshold, `BUILD = "cm2-s1"` |
| `docs/TECHNICAL_ARCHITECTURE.md`, `docs/DECISION_LOG.md`, `docs/TEST_PLAN.md` | Change | §4/§5 keys, a new entry, §3b steps and a §6 checklist line |

## Data and config
**DataStores and keys**
| Store | Key | Holds |
|---|---|---|
| `ChristmasMarket2_CompanyState_v1` (unchanged, `PersistenceService.STORE_NAME`) | `company:personal:<userId>` | The legacy record. Never deleted or overwritten again; only `_migratedTo`, `_migratedAt` and `_session` change |
| same store | `company:save:<saveId>` | One company record per save (companyId `save:<saveId>`) |
| `ChristmasMarket2_Profiles_v2` (`SaveSlotService.PROFILE_STORE_NAME`; v2 since Fix round 2, R2) | `profile:<userId>` | The player profile |

Every key contains the user ID as a fixed substring, so RTBF erasure templates can match it (roblox-data). Store names are not scoped by environment (out of scope).

**Save ID:** `<ownerUserId>_<16 lowercase hex>`, at most 36 chars; format, generation and `isSaveId` in Fix round 2, R1. IDs are never reused (deleted records keep a tombstone).

**Profile schema v1** (`SaveProfile.VERSION = 1`). Lock-free: every change is one `UpdateAsync` transform on the stored value, so a second server never loses an update and S2 can write to another player's profile.
```
{ profileVersion=1, userId=int, createdAt=int, updatedAt=int,
  saves={ {saveId, name, role="Owner", size="Solo", createdAt=int, lastPlayedAt=int} }, -- creation order
  nextSaveNumber=int>=1, lastSaveId=string?, legacyState="Pending"|"Done"|"None",
  legacySaveId=string?, recentCreates={ {requestId, saveId} } }                        -- newest last, at most 10
```
`validate` also accepts `role` "Member" and `size` Duo, Trio or Quad (S2 placeholders); S1 writes only Owner and Solo. It rejects duplicate save IDs and more than `MaxSavesPerPlayer` entries.

**Company schema 11** (`BusinessState.SCHEMA_VERSION = 11`):
- New fields `saveName` (valid UTF-8, 1–24 code points) and `saveSize` (Solo, Duo, Trio or Quad). `BusinessState.new(companyId?, ownerUserId?, saveName?)`: `saveName` defaults to `string.format(DefaultNameFormat, 1)`; `saveSize = "Solo"`.
- Migration: the v9 block no longer returns early, so v9 → 10 falls into a new block 10 → 11 (default `saveName` if missing or invalid, `saveSize = "Solo"`), followed by the current-version steps (prune completed orders, `clearCarried`, `normalizeSchema10`, `validated`). The v1 path also sets both fields.
- Envelope fields that `validate` ignores: `_session`, `_deletedAt`, `_migratedTo`, `_migratedAt`, `_migratedFrom`.

**Name source in S1:** the profile entry's `name`. The record's `saveName` is a copy, written on every load and on renaming the active save. S2 decides whether the record becomes the source for members; both fields exist, so no migration is needed.

**`GameConfig.Saves`** (engineering choices, PROVISIONAL):
```
MaxSavesPerPlayer = 50  -- spec says unlimited; technical cap that bounds profile size and storage quota; >> realistic use
NameMaxLength = 24, NamePayloadMaxBytes = 100, DefaultNameFormat = "Tree Lot %d",
MaxPlotTeleports = 3, LoadAttempts = 5, RecentCreates = 10,
RateLimits = { ["Save.List"]={limit=20,window=10}, ["Save.Create"]={limit=5,window=60},
  ["Save.Rename"]={limit=5,window=60}, ["Save.Delete"]={limit=5,window=60}, ["Save.Play"]={limit=10,window=60} }
```

**Player attributes (server-set):** `ProfileReady` (bool), `ActiveSaveId`, `ActiveSaveName`, `PlotId` (string or nil), `CompanyReady` (bool), `CompanyError` (string or nil; replaces `CompanyLoadError` everywhere).

## Steps (implemented)
1. **SaveProfile.lua** (pure, requires only GameConfig): `new(userId, now)` (`legacyState="Pending"`, `nextSaveNumber=1`); `validate(p)`; `normalizeName(raw)` → `(string?, "NameInvalid"?)`: a string of at most `NamePayloadMaxBytes` bytes with valid `utf8.len`, no `%c` byte and no `#`; trim, collapse `%s+` to one space; 1–24 code points. `confirmMatches(name, typed)`: `normalizeName(typed)` succeeds and both are equal under `string.lower`. `find(p, saveId)` → `(entry, index)`; `nameTaken(p, name, exceptSaveId?)` (case-insensitive); `isSaveId(v)`; `listView(p, activeSaveId)` → `{saveId, name, role, size, createdAt, lastPlayedAt, active, lastPlayed}` sorted by `lastPlayedAt` desc, `createdAt` desc, `saveId` asc.
2. **Protocol.lua:** `Protocol.SaveActions = { List="Save.List", Create="Save.Create", Rename="Save.Rename", Delete="Save.Delete", Play="Save.Play" }`. `Protocol.validateSaveRequest(request)` reuses the envelope checks of `validateRequest` (`MalformedRequest`, `UnsupportedVersion`, `InvalidRequestId`, `UnknownAction`, `MalformedPayload`). Payloads with `hasOnlyKeys` (else `UnexpectedField`): List `{}`, Create `{name?}`, Rename `{saveId, name}`, Delete `{saveId, confirmName}`, Play `{saveId}`. `InvalidSaveId` when `saveId` fails `isSaveId`; `InvalidName` when `name` or `confirmName` is not a string of at most 100 bytes. Create's `name` may be absent or `""`.
3. **PersistenceService.lua:**
   - Export `STORE_NAME` and `keyFor(companyId)` (= `"company:" .. companyId`; `_key` uses it). `new(store, jobId, clock, wait?)`: `wait` defaults lazily to `task.wait` (Lune has no `task`); `_retry` uses it. A local `deepCopy`.
   - `load(companyId, ownerUserId, saveName?)`: `_deletedAt` → `nil, "SaveDeleted"`; `_migratedTo` → `nil, "SaveMigrated"` (both write nothing). Nil record → `BusinessState.new(companyId, ownerUserId, saveName)`. After a successful migrate set `state.saveName = saveName` when given. Copy `_migratedFrom` through.
   - `markDeleted(companyId)` → `(ok, err)`, one `UpdateAsync`: nil record → no write, `true`; another unexpired job's `_session` → `"SaveInUse"`; this job's → `"SaveActive"`; otherwise `_deletedAt = clock()`, data kept, `true`. Store error after retries → `"DeleteFailed"`.
   - `migrateLegacy(userId, saveId, saveName)` → `("Migrated", saveId)`, `("NoLegacy", nil)` or `(nil, nil, errorCode)`. Legacy `company:personal:<userId>`, target `company:save:<saveId>`:
     - a. `UpdateAsync(legacy)`: nil → NoLegacy (no write); not a table → `"MigrationFailed"`; `_migratedTo` set → `("Migrated", _migratedTo)` (wins over the argument); another unexpired job's lock → `"SessionLocked"`; otherwise `deepCopy` (copy without `_session`), set our `_session = {jobId, expiresAt = now + LOCK_SECONDS}` and write.
     - b. `BusinessState.migrate(copy, "save:"..saveId, userId)`, then `companyId`, `saveName`, `saveSize = "Solo"`, `_migratedFrom = legacyKey`. On failure clear our legacy lock (clears `_session` only when the job ID matches) and return `"MigrationFailed"`.
     - c. `UpdateAsync(target)`: nil → write without `_session`; `_migratedFrom == legacyKey` → no write; else clear the legacy lock and return `"MigrationConflict"`.
     - d. `UpdateAsync(legacy)`: when `_session` is ours or absent, set `_migratedTo = saveId`, `_migratedAt = now`, clear `_session`; data unchanged. Otherwise see F3.
     - A store error after retries in a, c or d → `"LoadFailed"`. Every failure after a clears our legacy lock (Fix round 2, R3).
4. **CompanyStateService.lua:** `loadPersonalCompany(userId)` → `loadCompany(companyId, ownerUserId, saveName?)` (same busy and loading guard, passes `saveName`). `setSessionFailedHandler(handler)` and private `_failSession(companyId, session, code)`: `healthy=false`, `pcall(handler, companyId, code)` once per session (`session.failReported`), never while `session.unloading`; `_withSession` calls it after `_leave`. Codes: `_save` reason `SessionLocked` → `"SessionLocked"`; reason `NotLoaded` or the `SaveFailClosedSeconds` window passed → `"SaveFailed"`; error in `_withSession` → `"InternalError"`. `setSaveName(companyId, name): boolean` sets `state.saveName` in the critical section and marks dirty, no revision bump. `snapshotForTest` adds `saveName`.
5. **PlotService.lua:** holders are non-empty strings (company IDs); claims follow the configured order (`self._order`). `claim(holderId, preferredPlotId?)` → `(plotId?, "InvalidHolder" | "NoPlotsAvailable")`: existing claim → same plot, else the preferred plot if free, else the first free. `release(holderId)` → boolean; `owns(holderId, plotId)`; `getPlot(holderId)` → `string?`; `freeCount()`. `getPlotForUser` removed.
6. **SaveSlotService.lua:** `new(deps)`, `deps = {profileStore, persistence, companies, plots, clock, wait, newSaveId, filterName, teleport}`. `filterName(userId, text)` → `(true, filtered)` or `(false, "FilterUnavailable")`; `teleport(userId, {saveId, attempt})` → `(boolean, string?)`.
   - Profile store only through `UpdateAsync`, 3 attempts (waits 1 s, 2 s via `deps.wait`). Every transform resets its upvalue results at its start and sets `updatedAt = now`. Store errors → `"ProfileUnavailable"`.
   - One `Protocol.newRateLimiter` per action from `RateLimits` (clock `deps.clock`). Per-user `_busy` lock: a second call in flight → `"SaveActionBusy"`. Public `openProfile`, `handle`, `play` take it; under it `handle` calls `_openProfile`/`_play`, and `play` calls non-final `leave`.
   - Registry `_active[userId] = companyId`, `_members[companyId] = {[userId]=true}`. Public: `openProfile(userId)` → `(profile?, err?)`; `closeProfile(userId)`; `handle(userId, request)` → `{ok, errorCode?, data?}`; `play(userId, saveId, options?)` → `(ok, err?, data?)`, `options = {attempt?, reload?}`; `leave(userId, final?)` → `(ok, err?)`; `activeCompanyId`; `activeUserIds()`; `playersOn(companyId)`; `listFor(userId)`; `setActivationHandlers(onActivated(userId, companyId, plotId, state, saveName), onDeactivated(userId, companyId, plotId, plotReleased))`.
   - **openProfile:** cached profile if any. Else `pendingId = newSaveId(userId)`; transform: nil → `SaveProfile.new` with `legacySaveId = pendingId`; invalid → no write, `"ProfileCorrupt"`; `Pending` without `legacySaveId` → set it. If `Pending`: `persistence:migrateLegacy(userId, legacySaveId, "Tree Lot 1")`. Failure → its code, nothing cached. `Migrated(id)`: insert `{saveId=id, name="Tree Lot 1", Owner, Solo, createdAt=now, lastPlayedAt=0}` at index 1 if absent, `nextSaveNumber = max(n, 2)`, `legacyState = "Done"`. `NoLegacy`: `legacyState = "None"`; if `nextSaveNumber == 1` and no saves, add the starter save with `saveId = legacySaveId`, name "Tree Lot 1", `nextSaveNumber = 2`. Both clear `legacySaveId`.
   - **handle:** `validateSaveRequest`, limiter (`"RateLimited"`), busy, `openProfile`. **List** → `{saves = listView, activeSaveId, maxSaves}`. **Create:** empty/absent name → `string.format(DefaultNameFormat, nextSaveNumber)` (not filtered); else `normalizeName`, then `filterName`; changed text → `"NameNotAllowed"`. Transform: `requestId` in `recentCreates` → same `{saveId, name}`; at cap → `"SaveLimit"`; taken → `"NameInUse"`; else append (Owner, Solo, `lastPlayedAt = 0`), `nextSaveNumber += 1`, push `recentCreates` (trim 10). Returns `{saveId, name}`; the first Play creates the record. **Rename:** entry exists (`"SaveNotFound"`), `normalizeName`, `nameTaken` excluding itself (`"NameInUse"`), filter; transform sets the name; active here → `companies:setSaveName`. Returns `{saveId, name}`. **Delete:** entry exists (`"SaveNotFound"`), `confirmMatches` (`"ConfirmationMismatch"`), not active for this user (`"SaveActive"`), `persistence:markDeleted` (error passes through); transform removes the entry and clears a matching `lastSaveId`. Returns `{saveId}`. **Play:** `play(userId, saveId)` → `{saveId, plotId}`.
   - **play:** (1) entry must exist, else `"SaveNotFound"`. (2) Same save active, `companies:isAvailable` true and not `reload` → ok with the current plot. (3) Another save, a failed session or `reload`: `preferred = plots:getPlot(old)`, then `leave(userId)`. (4) `plots:claim("save:"..id, preferred)`; on failure, `(attempt or 0) < MaxPlotTeleports` → `teleport(userId, {saveId, attempt+1})`, true → `"NoFreePlotTeleporting"`, false → `"NoFreePlot"`; else `"NoFreePlot"`; nothing loaded. (5) `companies:loadCompany(companyId, userId, entry.name)`, up to `LoadAttempts` tries while `SessionBusy`, `deps.wait(attempt)` between; failure → release the plot and return the code; `SaveDeleted` also removes the entry. (6) `_leaving[userId]` set during the yields → unload, release, `"PlayerLeft"`. (7) Register; touch the profile (`lastPlayedAt = now`, `lastSaveId = id`; failure only warns); `onActivated`.
   - **leave:** `final=true` sets `_leaving[userId]` and waits until `_busy` clears. With an active save: deregister, `companies:releaseCarried`, `companies:unloadCompany`; no other member → `plots:release`, `plotReleased = true`; `onDeactivated`. `final` then clears limiter buckets (`Protocol.forgetUser`), the profile cache and `_leaving`. (Restructured in F6.)
7. **main.server.lua:** `saveSlots = SaveSlotService.new{...}` with `profileStore = DataStoreService:GetDataStore(PROFILE_STORE_NAME)`, `clock = os.time` (real time, so business-clock offsets never bypass limits), `wait = task.wait`, `newSaveId` as above, `filterName` (player via `GetPlayerByUserId`, else `false`; `pcall` of `TextService:FilterStringAsync(text, userId, Enum.TextFilterContext.PublicChat)` then `:GetNonChatStringForBroadcastAsync()`), `teleport` (Studio → `false, "TeleportUnavailable"`; else `TeleportOptions:SetTeleportData({cm2NoFreePlot = data})` and `pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, {player}, options)`).
   - `companyIdFor(userId) = saveSlots:activeCompanyId(userId)`; nil → `handleBusinessAction`/`performOrderAction` return `CompanyUnavailable`. Placement and order handlers use `plots:getPlot(companyId)` and `saveSlots:playersOn(companyId)`; `userIdFromCompanyId` removed.
   - onActivated: `syncPlotWorld`; for a real player set `PlotId`, `ActiveSaveId`, `ActiveSaveName`, `CompanyError=nil`, `CompanyReady=true`, then spawn `spawnAtClaimedPlot`. onDeactivated: `plotReleased` → `clearPlotVisuals(plotId)`; for a player `WorldService.detachCarriedTree(character)`, `CompanyReady=false`, `PlotId`/`ActiveSaveId`/`ActiveSaveName` nil. `companies:setSessionFailedHandler`: every `playersOn(companyId)` player gets `CompanyReady=false`, `CompanyError=code`; warn.
   - RemoteFunction `Remotes.SaveAction` → `handleSaveAction(player, request)` → `saveSlots:handle`. A successful Rename of the active save updates `ActiveSaveName`; a failed Play sets `CompanyError` only when no save is active.
   - **PlayerAdded:** connect `CharacterAdded` once (`releaseCarried` on the active company, then `spawnAtClaimedPlot`); `CompanyReady=false`; `openProfile` → failure: `ProfileReady=false`, `CompanyError=code`; success: `ProfileReady=true`. `GetJoinData()`: `SourcePlaceId == game.PlaceId` and `TeleportData.cm2NoFreePlot` a table with a valid `saveId` and integer `attempt` 1..`MaxPlotTeleports` → `saveSlots:play(userId, saveId, {attempt=attempt})`, failure sets `CompanyError`. Otherwise the picker chooses; the character uses the default spawn.
   - `TeleportService.TeleportInitFailed` → `CompanyError="NoFreePlot"`. **PlayerRemoving:** `saveSlots:leave(userId, true)`, then `companies:forgetUser`. **BindToClose:** see F7. Hook context gains `saveSlots`, `handleSaveAction`, `persistenceStoreName`.
8. **StudioTestService.lua:** `companyIdFor` via `saveSlots`; nil → `snapshot`, `act`, `visit`, `customerOrders`, `setStaff` return `failure("NoActiveSave")`. `rejoin` = `saveSlots:play(userId, activeSaveId, {reload=true})` → `{plotId}`. `shadowJoin`: `openProfile(shadow)` (migrates `company:personal:999999999001` into "Tree Lot 1"); no saves → `saveSlots:handle(shadow, {version=1, requestId="studio_"..GUID, action="Save.Create", payload={}})`; play the first `listFor(shadow)` entry; return `{userId, plotId}`. `shadowLeave` = `saveSlots:leave(shadow, true)`. New commands: `saveAction {userId, action, payload, requestId?}` (real player → `context.handleSaveAction`, shadow → `saveSlots:handle`); `saves (userId)` → `listFor`; `flush` → `companies:flushDirty(true)`; `lockSave {userId, saveId}` (saves of that profile only) sets `_session = {jobId="studio-test-thief", expiresAt=os.time()+300}` via `UpdateAsync(keyFor("save:"..id))`; `unlockSave` clears it only when `jobId == "studio-test-thief"`.
9. **SavePicker.client.lua** (mobile first; every button ≥ 44 px): ScreenGui `SavePickerUI` (`DisplayOrder=20`, `ResetOnSpawn=false`), frame `Picker` (anchor 0.5,0.5; scale 0.92×0.86; `UISizeConstraint` max 480×600): title `savePickerTitle`, hint `savePickerHint`; ScrollingFrame `SaveList` (`UIListLayout` padding 8, `AutomaticCanvasSize=Y`); rows `SaveRow_<n>` 96 px: name label (`AutoLocalize=false`, end-truncated), sub-label `saveRowActive`/`saveRowLastPlayed`, buttons `Play`, `Rename`, `Delete` (width scale 0.3); bottom TextBox `NewSaveName` (placeholder `saveNamePlaceholder`), `CreateSave` (`saveNew`), wrapped `PickerStatus`, `BackToGame` (`saveBack`, only while `CompanyReady`); empty list → `savePickerEmpty`.
   - Rename in the row: TextBox with the current name, `Rename` → `saveRenameConfirm`, `Delete` → `saveCancel`. Delete opens `DeleteConfirm`: `saveDeleteTitle`, `saveDeleteWarning`, `saveDeleteInstruction` (name), TextBox `ConfirmName`, `ConfirmDelete` (`saveDeleteConfirm`, red, active only when a client copy of `confirmMatches` holds), `saveCancel`. `SavesButton` (`savesButton`, 96×44, top right) while the picker is closed.
   - Opens when `ActiveSaveId` is nil, `CompanyError` is set, or on `SavesButton`; opening calls `Save.List`. Play shows `saveLoading`; closes when `CompanyReady` becomes true. One request in flight. Errors show `Localization.saveErrorKey(code)`. (Notify listener removed in F5.)
10. **UiController.client.lua:** `updateReady`: `CompanyReady` → `hudSaveStatus` (save name, plot); else `CompanyError` → `localized(Localization.saveErrorKey(code))`; else no `ActiveSaveId` → `hudChooseSave`; else `saveLoading`. Listens to `CompanyError`, `ActiveSaveId`, `ActiveSaveName` (not `CompanyLoadError`). `panel.Visible = CompanyReady == true`. `ActiveSaveId` change → `lastSummary=nil`, refresh. (Status line ownership: F4.)
11. **Localization.lua:** `Localization.SaveErrorKeys` (code → key) and `Localization.saveErrorKey(code)` (fallback `saveErrorUnknown`); every key in `en` plus a faithful `de` ("Spielstand", "Grundstück").

    | Code(s) | Key | English |
    |---|---|---|
    | SessionLocked | saveErrorSessionLocked | This save is open on another server. Please try again in a minute. |
    | SaveFailed | saveErrorSaveFailed | Saving stopped working, so this save was paused to protect your progress. Please choose it again. |
    | InternalError | saveErrorInternal | Something went wrong, so this save was paused to protect your progress. Please choose it again. |
    | LoadFailed, DeleteFailed, ServerShuttingDown (F6) | saveErrorLoadFailed | The save could not be loaded or changed. Nothing was lost. Please try again. |
    | ProfileUnavailable, ProfileCorrupt | saveErrorProfile | Your saves could not be loaded. Nothing was changed. Please try again. |
    | MigrationFailed, MigrationConflict, SaveMigrated | saveErrorMigration | Your old lot could not be moved into a save yet. Nothing was lost. Please try again later. |
    | SaveNotFound, SaveDeleted | saveErrorNotFound | This save no longer exists. |
    | SaveLimit | saveErrorLimit | You have reached the save limit. Delete a save to create another. |
    | NameInvalid, InvalidName | saveErrorNameInvalid | Names need 1 to 24 characters and cannot use #. |
    | NameNotAllowed | saveErrorNameNotAllowed | That name is not allowed. Please choose another one. |
    | NameInUse | saveErrorNameInUse | You already have a save with that name. |
    | FilterUnavailable | saveErrorFilter | Names cannot be checked right now. Please try again. |
    | ConfirmationMismatch | saveErrorConfirm | The name you typed does not match, so the save was not deleted. |
    | SaveActive | saveErrorActive | Switch to another save before deleting this one. |
    | SaveInUse | saveErrorInUse | This save is still in use. Please try again in a minute. |
    | NoFreePlot | saveErrorNoFreePlot | There is no free lot on this server. Please try another server. |
    | NoFreePlotTeleporting | teleportNoFreePlot | There is no free lot here, so you are being moved to another server. |
    | SaveActionBusy | saveErrorBusy | Please wait until the last action has finished. |
    | RateLimited | saveErrorRateLimited | That was too many requests. Please wait a moment. |
    | CompanyUnavailable | saveErrorUnavailable | This save is paused. Open your saves to continue. |
    | (fallback) | saveErrorUnknown | Something went wrong. Please try again. |

    UI keys: `savePickerTitle` "Choose a save"; `savePickerHint` "Each save has its own lot, cash and trees."; `savePickerEmpty` "You have no saves yet. Create one to start."; `saveRowLastPlayed` "Last played"; `saveRowActive` "Playing now"; `savePlay` "Play"; `saveRename` "Rename"; `saveDelete` "Delete"; `saveNew` "New save"; `saveNamePlaceholder` "Name your save"; `saveRenameConfirm` "Save name"; `saveCancel` "Cancel"; `saveBack` "Back to game"; `savesButton` "Saves"; `saveDeleteTitle` "Delete this save?"; `saveDeleteWarning` "Deleting removes this lot with its cash and trees. This cannot be undone."; `saveDeleteInstruction` "Type the save name to confirm: %s"; `saveDeleteConfirm` "Delete forever"; `saveLoading` "Loading your save…"; `hudChooseSave` "Choose a save to start playing."; `hudSaveStatus` "%s · Plot %s".
12. **Tests mechanical update:** `loadPersonalCompany(N)` → `loadCompany("personal:N", N)` everywhere; `BusinessState_Test` `migrated.schemaVersion, 10` → `BusinessState.SCHEMA_VERSION`; `PlotService_Test` rewritten for string holders. New fake DataStores deep-copy on read and write, expose `records`, throw while `failCount > 0`; tests inject `wait = function() end` and clocks.
13. **Docs:** TECHNICAL_ARCHITECTURE §4 (profile schema, save ID, schema 11), §5 (key table, migration a–d, tombstones, lock-free profile, R3 handler). DECISION_LOG entry "2026-11-22 - Save slots per player, CM2-S1 (engineering)": old and new key, cap 50 and why, rate limits, typed-name confirmation (not "DELETE", which auto-translation would change), name source in S1, rollout note (shut down old servers; old code ignores `_migratedTo`). TEST_PLAN §3b step count and commands; §6 line "Place setting Max Players = 12 (6 plots; a solo player without a free plot is teleported)".

## Fix round 1 (after the implementer's report, 2026-11-22)
**Decisions on the open questions**
| # | Decision |
|---|---|
| Q1 | Accept. `SaveProfile` has no cap function; SaveProfile_Test checks that 50 entries validate and 51 do not. The `SaveLimit` code is asserted in SaveSlotService_Test "stops at the save cap". No code change. |
| Q2 | Confirmed: `reload` always leaves and reloads the active save, even a healthy one (play step 3). The Studio `rejoin` depends on it. Locked by a new test (F9). |
| Q3 | Step d with another job's `_session` (expired or not): write nothing, return `"SessionLocked"` (accepted; the next open repeats a–d, and c is idempotent). Step d with a nil or non-table legacy record: write nothing, return `"MigrationFailed"` (F3). `markDeleted` on a non-table record → `"DeleteFailed"` (accepted). |
| Q4 | `saveErrorKey` ignores everything from the first `:`, so the reason suffix stays in `CompanyError` for diagnostics (F2). `persistence.load` keeps `"LoadFailed:<reason>"`. |
| Q5 | The HUD `status` line belongs only to `updateReady` (save name · plot, error, choose save, loading). Parking already shows in `customerLine`. Action errors go to `detail` (F4). |
| Q6 | Do not fire it. Every no-free-plot path already sets `CompanyError` (`NoFreePlotTeleporting` → `teleportNoFreePlot` via `saveErrorKey`, `TeleportInitFailed` → `NoFreePlot`), and the picker shows `CompanyError`. Remove the dead listener (F5). |
| Q7 | Fix with a shutdown flag and a pending-work count that covers final leaves already past `activeUserIds()` and every in-flight busy action (F6, F7). |

**Fix steps**
- F1. Q1 needs no change. In the Tests table the SaveProfile_Test row now reads "50 entries validate, 51 do not".
- F2. `Localization.saveErrorKey(code)`: for a string, look up `string.match(code, "^[^:]+")`, then the fallback. No other change.
- F3. `PersistenceService:migrateLegacy` step d: split the refusal. `previous` is not a table → `refusal = "MigrationFailed"`; `_session` present and not ours → `refusal = "SessionLocked"`. Both return `nil` from the transform (no write) and `(nil, nil, refusal)`.
- F4. `UiController.client.lua`: delete the `plotParkingStatus` block in `renderSummary`. In `order.Activated` failure, `status.Text = errorText(...)` becomes `detail.Text = errorText(...)`. Delete the now unused `plotParkingStatus` key from `en` and `de`.
- F5. `SavePicker.client.lua`: delete the `notify.OnClientEvent` listener and the `notify` local. Server and `WorldLabels` keep the Notify remote.
- F6. `SaveSlotService.lua`:
  - New fields in `new`: `_closing = false`, `_finalLeaves = 0`.
  - `beginShutdown()`: sets `_closing = true`. `pendingCount(): number` returns `_finalLeaves` plus the number of keys in `_busy`.
  - `openProfile`, `handle` (after validation and the limiter, before busy) and `play` return `"ServerShuttingDown"` while `_closing` (`openProfile`: `nil, "ServerShuttingDown"`; `handle`: `failure("ServerShuttingDown")`; `play`: `false, "ServerShuttingDown", nil`).
  - `_play` step 5: break the `SessionBusy` retry loop when `_closing`. Step 6: when `_leaving[userId]` or `_closing` → unload, release, return `"PlayerLeft"` if leaving, else `"ServerShuttingDown"`.
  - Move the active-save block of `leave` into `_leaveActive(userId): (boolean, string?)`. `leave(userId, final?)`: not final → `return self:_leaveActive(userId)`. Final → `_finalLeaves += 1` as the first statement (before any yield); `pcall` of a closure that sets `_leaving`, waits for `_busy`, calls `_leaveActive` and clears limiters and the profile cache; then `_leaving[userId] = nil` and `_finalLeaves -= 1` unconditionally; a pcall error warns and returns `false, "InternalError"`.
  - Localization: add `ServerShuttingDown = "saveErrorLoadFailed"` to `SaveErrorKeys` (no new string).
- F7. `main.server.lua` BindToClose: call `saveSlots:beginShutdown()` first, spawn `pcall(saveSlots.leave, saveSlots, userId, true)` for every `activeUserIds()` (drop the local `pending` counter), then `while saveSlots:pendingCount() > 0 and waited < SHUTDOWN_WAIT_SECONDS do waited += task.wait(0.1) end`. `SHUTDOWN_WAIT_SECONDS` stays 25 (inside the 30 s budget).
- F8. Test fakes in `SaveSlotService_Test` and `SaveMigration_Test`: `fakeStore` gets an optional `store.beforeUpdate(key)` called at the start of every `UpdateAsync`, before the `failCount` check.
- F9. New tests (table below). `RunPlaytest.lua` `01` threshold `>= 198`; TEST_PLAN §3b "at least 198 tests".
- F10. Docs: TECHNICAL_ARCHITECTURE §5 gains "Shutdown: `beginShutdown` refuses new save work; BindToClose waits for `pendingCount()` (final leaves plus busy actions) up to 25 s". The DECISION_LOG S1 entry gains one line each for Q2, Q3, Q4 and Q7.

**Confirmed unplanned additions** (keep as implemented)
- `pcall` around `openProfile`, `handle` and `play` that always clears `_busy` and returns `InternalError`.
- Every profile write validated before writing; refused with `ProfileCorrupt`.
- Rename and Delete transforms re-check that the entry exists and (Rename) that the name is unique; the default Create name is computed inside the transform.
- `main.server` skips `spawnAtClaimedPlot` without a character (`CharacterAdded` handles it later).
- Removal of the unused `studioShadowUsers`, `loadAttempts` and `LOAD_ATTEMPTS`. `shadowLeave` still calls `companies:forgetUser`, like PlayerRemoving.
- SavePicker refreshes an open picker on `ProfileReady` (the first List can hit `SaveActionBusy`).
- RunPlaytest: picks the player on `ProfileReady`; `saveAct` retries once after 61 s on `RateLimited`; step deps 24←02a, 25←24, 26←24, 27←26, 28←02a; cleanup plays "Playtest A" and deletes leftover test saves in both modes.

## Fix round 2 (after the failed Studio playtest, 2026-11-22)
**Finding.** Every save write failed with the real `KeyNameLimit` (keys over 50 chars): `company:save:4584569287_<32hex>` is 56 chars. Profile load → `LoadFailed`; full mode 3 pass / 2 fail / 24 skip. No data lost (`company:personal:4584569287` unchanged). Step c's store error returned `LoadFailed` without clearing step a's legacy lock, leaving `_session = {jobId="", expiresAt=1795312003}`. The headless fakes had no key-length rule, and test user IDs were 2 digits.

**R1. Save ID format** (`SaveProfile.lua`; replaces the old Save ID paragraph)
- `SaveProfile.KEY_MAX_LENGTH = 50` (Roblox DataStore key limit), `SaveProfile.SAVE_ID_MAX_LENGTH = 36`.
- `SaveProfile.userIdText(userId: number): string` = `string.format("%d", userId)`. Every key or ID that contains a user ID uses it, because Luau `tostring` writes 19-digit numbers in exponent form. Callers: `SaveSlotService` `profileKey`, the legacy key in `PersistenceService:migrateLegacy`, `SaveProfile.newSaveId`. For every existing legacy key (IDs below 10^15) it gives the same text as `tostring`.
- `SaveProfile.newSaveId(userId: number, guid: string): string`: `hex = string.lower((string.gsub(guid, "-", "")))`, returns `userIdText(userId) .. "_" .. string.sub(hex, 17, 32)`. Example: `(9223372036854774784, "0F8FAD5B-D9CB-469F-A165-70867728950E")` → `"9223372036854774784_a16570867728950e"`.
- `isSaveId(v)`: a string of at most 36 bytes matching `^(%d+)_(%x+)$`, with 1–19 digits, exactly 16 hex chars and no uppercase.
- `main.server.lua` `newSaveId(userId)` = `SaveProfile.newSaveId(userId, HttpService:GenerateGUID(false))`. Update its comment.
- Uniqueness: the user-ID prefix makes IDs unique across players. Within one player, 62 random bits are left (GUID chars 17–32 include the variant nibble), so a collision is negligible. A collision on Create fails `validate` (duplicate saveId), gives `ProfileCorrupt` and writes nothing. A collision with a deleted ID gives `SaveDeleted` on Play. Neither loses data, so there is no retry loop.
- Rejected alternatives: dropping the user ID for 36 random chars (loses RTBF matching, roblox-data); base-36 encoding (more code for no gain).

**Key budget** (also in TECHNICAL_ARCHITECTURE §5). The worst case is a 19-digit user ID:
| Family | Format | Max chars |
|---|---|---|
| Company legacy | `company:personal:<userId>` | 36 |
| Company save | `company:save:<userId>_<16hex>` | 49 |
| Profile | `profile:<userId>` | 27 |
| S2 invite code (foreseen; 5 digits per backlog) | `invite:<code>` | 12 |
| S3 save-to-server map (foreseen; MemoryStore, limit 128) | `save:<saveId>` | 41 |
Rule for S2 and S3: a key holding a save ID gets a prefix of at most 14 chars; a key holding a user ID, at most 31. Every new key family adds a row here and a case to the R7 key-length test. S2 member lists stay inside the company record (no new key).

**R2. Profile store `ChristmasMarket2_Profiles_v2`** (`SaveSlotService.PROFILE_STORE_NAME`). v1 may hold Studio test profiles (`Pending`, no saves) with a 32-hex `legacySaveId`. The new `isSaveId` rejects those IDs, so v1 profiles would be `ProfileCorrupt` forever. The game is unpublished, so v1 holds no player data; it is abandoned and never read. Export `SaveSlotService.profileKey` (the existing local function, now using `userIdText`).

**R3. Clear the migration lock on every failure** (`PersistenceService.lua`)
- Steps b–d move unchanged into the private `_finishMigration(legacyKey, copy, userId, saveId, saveName)`, which returns the same values as `migrateLegacy`. Remove its three `_clearLegacyLock` calls.
- `migrateLegacy` after step a: `local called, outcome, id, err = pcall(self._finishMigration, self, legacyKey, copy, userId, saveId, saveName)`. When the call errors: warn `"[ChristmasMarket2] migrateLegacy failed for %s: %s"` (userIdText, error), then set `outcome, err = nil, "MigrationFailed"`. When `outcome == nil`: call `self:_clearLegacyLock(legacyKey)` once and return `nil, nil, err`. Otherwise return `outcome, id`.
- So every failure after step a tries one clear: b invalid, c store error, c conflict, d store error, d refusals, thrown errors. `_clearLegacyLock` stays as it is. It clears only a `_session` whose `jobId` equals ours (Studio: `"" == ""`) and writes nothing otherwise, so job-b's lock and a `"garbage"` value stay. If the clear itself fails, that is ignored and the lock expires after `SessionLockSeconds` (120 s).
- The legacy key becomes `self:_key("personal:" .. SaveProfile.userIdText(userId))`. PersistenceService requires `SaveProfile`.

**R4. Existing Studio data: no wait and no data fix**
- The leftover `{jobId="", expiresAt=1795312003}` on `company:personal:4584569287` can be reclaimed at once. `_lockedByOther` treats the same job ID as ours (`game.JobId` is `""` in every Studio session), and the lock also expired 120 s after it was set. Step a overwrites it. No code change; R7 test 5 locks this behavior.
- The Studio `JobId ""` stays as it is: one Studio server runs at a time, and a restart takes over its own lock. A generated Studio job ID was rejected because it would block every run after a crash for 120 s.
- No `company:save:*` record exists, because the real store refused every write. `Profiles_v1` is abandoned (R2).

**R5. KeyNameLimit in every fake DataStore.** These four fakes are all of them: the headless runner only stubs `DataStoreService`, and the other tests fake persistence instead. `PersistenceService_Test` `fakeStore` and `copyingStore`, `SaveMigration_Test` `fakeStore`, `SaveSlotService_Test` `fakeStore`. In each file add `local KEY_NAME_LIMIT = 50 -- real DataStore rule (KeyNameLimit)`. The first statement of `UpdateAsync`, before `beforeUpdate` and `failCount`: `if #key > KEY_NAME_LIMIT then error("KeyNameLimit: Key name exceeds the 50 character limit.") end`.

**R6. Mechanical fixture updates** (to the 16-hex format): `string.rep("0a", 16)`/`("0b", 16)`/`("ab", 16)` → `, 8)` in PersistenceService_Test (SAVE_A, SAVE_B), SaveMigration_Test (SAVE_ID, OTHER_ID) and Protocol_Test (SAVE_ID). `"%032x"` → `"%016x"` in SaveProfile_Test `saveId` and SaveSlotService_Test (setup `newSaveId`, "stops at the save cap"). SaveProfile_Test "recognizes save IDs" follows the updated Tests row. In tests, `MAX_USER_ID = 9223372036854774784` (2^63 − 1024, the largest Luau number below int64 max, 19 digits).

**R7. New tests (7)**
| Test case file | Test name | Asserts |
|---|---|---|
| SaveProfile_Test | builds short save IDs for a 19-digit user ID | the R1 `newSaveId` example exactly; `#id == 36`; `isSaveId(id)`; `userIdText(MAX_USER_ID) == "9223372036854774784"`; `#("company:save:" .. id) <= KEY_MAX_LENGTH` |
| PersistenceService_Test | rejects over-long keys like the real DataStore | `copyingStore`: `load("save:4584569287_" .. string.rep("a", 32), 4584569287)` → `nil` and a reason containing `KeyNameLimit`; `store.writes == 0` |
| SaveMigration_Test | clears its lock when the save key is rejected | jobId `""`, user 4584569287, legacy record present, saveId `"4584569287_" .. string.rep("ab", 16)` (56-char key) → `nil, nil, "LoadFailed"`; legacy has no `_session` and no `_migratedTo`, its cash is unchanged; no target record |
| | clears its lock when marking the personal record fails | `beforeUpdate` counts legacy-key calls and throws `"Throttled"` on calls 2, 3 and 4 (all retries of d) → `"LoadFailed"`; legacy has no `_session` and no `_migratedTo`; the target has `_migratedFrom`; then without `beforeUpdate` a rerun → `"Migrated"` with the same ID, legacy marked |
| | takes over its own leftover lock | jobId `""`, legacy `_session = {jobId="", expiresAt=now+300}` → `"Migrated"`; second case: job-a with `{jobId="job-z", expiresAt=now-1}` → `"Migrated"`; both legacy records end with no `_session` |
| | migrates the record of a 19-digit user ID | legacy key `"company:personal:9223372036854774784"`, saveId `SaveProfile.newSaveId(MAX_USER_ID, <fixed GUID>)` → `"Migrated"`; target key ≤ 50 chars and present |
| SaveSlotService_Test | keeps every key within 50 characters for a 19-digit user ID | seed the legacy record for `MAX_USER_ID` (cash 777); `openProfile` migrates it; Create "Long Id" ok; Play it, then Play the migrated save; `leave(MAX_USER_ID, true)` ok. Every key in both fake stores ≤ 50 chars; the profile key is `"profile:9223372036854774784"`; the created saveId starts with `"9223372036854774784_"`; the migrated record's cash is 777 |

**R8. Thresholds and docs**
- `RunPlaytest.lua`: `BUILD = "cm2-s1-r2"`; step `01` checks `>= 205`. TEST_PLAN §3b: "at least 205 tests", plus one line: "Every fake DataStore enforces the 50-character key limit (KeyNameLimit)."
- TECHNICAL_ARCHITECTURE §4: the save ID format. §5: `Profiles_v2`, the key budget table and rule, and "every failure after locking the legacy record clears our lock".
- DECISION_LOG S1 entry: change `Profiles_v1` → `Profiles_v2` and add one line each for the save ID format with the key budget, the v2 store rename, and the lock clearing plus the reclaimable Studio lock.
- Extra acceptance checks: `rg "tostring\(userId\)" src/server/Services/SaveSlotService.lua src/server/Services/PersistenceService.lua src/server/main.server.lua` is empty; `rg "Profiles_v1|%032x|\"0a\", 16" src tests` is empty.

**R9. Playtest re-run setup** (replaces Playtest step 1; steps 2–7 stay)
1. Rojo serve with the plugin connected; API access enabled. Confirm `RunPlaytest.BUILD == "cm2-s1-r2"` in the live source.
2. Clear nothing. The leftover legacy lock is expected and reclaimable (R4). Before Play, read `company:personal:4584569287` and record its cash (1615), revision (244) and placement count (1).
3. Play (Server + Client). Server output must show no `KeyNameLimit`, `LoadFailed` or `profile load failed` line for the whole session. On join: `ProfileReady == true`, and the picker lists "Tree Lot 1". Play it: `CompanyReady == true`, and HUD cash 1615 with 1 placement. Read the records: legacy `_migratedTo` = a 27-char ID matching `^4584569287_%x+$` (16 hex), no `_session`; `company:save:<that ID>` exists (key 40 chars); `profile:4584569287` is in `ChristmasMarket2_Profiles_v2`.
4. Then run Playtest steps 2–7 as written (full mode expects 29/29 PASS with `01 >= 205`).

## Tests (headless)
Expected total: 147 + 44 (steps 1–13) + 7 (F9) + 7 (Fix round 2, R7) = **205**.

| Test case file | Test name | Asserts |
|---|---|---|
| SaveProfile_Test (new) | normalizes and validates save names | `"  My   Lot "` → "My Lot"; NameInvalid for "", 25 chars, "A#B", "a\nb", "\255"; 24 chars and "Grüne Tanne" pass |
| | matches typed confirmation case-insensitively | `" tree  lot 1 "` matches "Tree Lot 1"; "Tree Lot" and nil do not |
| | recognizes save IDs | valid `42_<16hex>`; uppercase hex, missing `_`, 15 hex, 32 hex (old format), 20-digit prefix, non-string fail (Fix round 2) |
| | enforces the save cap and unique names | 50 entries validate, 51 do not; `nameTaken` is case-insensitive |
| | lists saves by last played, then newest | order, plus `active` and `lastPlayed` |
| | validates profile shape | `new` valid; bad role or size, duplicate saveId, 51 entries invalid |
| SaveMigration_Test (new) | moves a personal record into the first save without losing data | cash, stock, placements, pendingOrders, sales equal; companyId `save:…`, `saveName` "Tree Lot 1", `_migratedFrom`; legacy unchanged with `_migratedTo`, no `_session` |
| | is idempotent when run again | second run `Migrated` with the same ID; the target is not rewritten after changing it |
| | resumes after a crash between copy and marking | target written, legacy unmarked → rerun succeeds, no conflict, legacy marked |
| | fails closed while another server holds the personal record | SessionLocked; no target; legacy unchanged |
| | fails closed on an unmigratable record and leaves it untouched | schema 99 → MigrationFailed; no target; legacy lock cleared |
| | reports no legacy record | NoLegacy, no writes |
| | refuses to overwrite an unrelated record at the save key | MigrationConflict; target unchanged |
| | **(F9)** stops before marking when another server took the personal record | `beforeUpdate` on the 2nd legacy update sets `_session={jobId="job-b", expiresAt=now+300}` → SessionLocked; target has `_migratedFrom`; legacy has no `_migratedTo` and keeps job-b's lock; after clearing it, a rerun → `Migrated` with the same ID and the legacy is marked |
| | **(F9)** refuses to mark a personal record that is no longer a table | `beforeUpdate` on the 2nd legacy update sets the record to `"garbage"` → MigrationFailed; the legacy value is still `"garbage"` |
| PersistenceService_Test | locks each save separately | job-a holds A, job-b holds B; job-b on A → SessionLocked |
| | refuses to load a deleted save | `_deletedAt` → SaveDeleted, no write |
| | deletes only unlocked saves | other job → SaveInUse; own job → SaveActive; unlocked → `_deletedAt`, data kept; nil → true, no write |
| CompanyStateService_Test | reports a lost lock once through the failure handler | handler once with (companyId, "SessionLocked") over two flushes |
| | reports an internal error through the failure handler | "InternalError" |
| | reports a save outage after the fail-closed window | "SaveFailed" only after `SaveFailClosedSeconds` |
| BusinessState_Test | migrates v10 to v11 with a save name and Solo size | balances kept; "Tree Lot 1"; "Solo"; SCHEMA_VERSION 11 |
| | rejects an invalid save name or size | 25 code points, "" or "Huge" → invalid |
| Protocol_Test | validates save action payloads | each action valid; InvalidSaveId; InvalidName (101 bytes) |
| | rejects unknown or extra save fields | UnexpectedField; UnknownAction "Save.Steal" |
| PlotService_Test | prefers the requested free plot | preferred taken; else first free in config order |
| Localization_Test | has an English text for every save error code | every `SaveErrorKeys` value and the fallback exist in `en` and `de` |
| | **(F9)** maps error codes with a reason suffix | `"LoadFailed:Throttled"` → saveErrorLoadFailed; `"SaveFailed:x"` → saveErrorSaveFailed; `"ServerShuttingDown"` → saveErrorLoadFailed; `"Nope"`, nil → saveErrorUnknown |
| SaveSlotService_Test (new; real Persistence, CompanyState, Plot over fakes) | creates one starter save for a new player | one "Tree Lot 1"; `legacyState` None; reopening adds nothing |
| | migrates a personal record into the first save on first open | entry ID = legacy `_migratedTo`; Play shows the legacy cash |
| | fails closed when the profile cannot be read | store throws → ProfileUnavailable; nothing written; later success |
| | never overwrites a corrupt profile | ProfileCorrupt; stored value identical |
| | creates a save with a filtered name | entry added, `nextSaveNumber` +1; no record before Play |
| | rejects filtered, duplicate and invalid names | NameNotAllowed, FilterUnavailable, NameInUse, NameInvalid; profile unchanged |
| | replays a create with the same request ID | same saveId, one entry |
| | stops at the save cap | 51st → SaveLimit |
| | renames a save and the active record | profile name and live `state.saveName` updated |
| | deletes only with the typed name | ConfirmationMismatch keeps entry, no `_deletedAt`; correct name removes it and tombstones the record |
| | refuses to delete the active save | SaveActive |
| | plays a save on a free plot | plot claimed for `save:<id>`; onActivated args; `lastSaveId` |
| | switching keeps the plot and isolates saves | order on A; B on the same plot with StartingCash; A's record holds the order; back to A: cash equal; B unchanged |
| | a deleted save cannot be played and leaves the list | SaveDeleted; entry removed |
| | teleports when no plot is free | teleport `{saveId, attempt=1}`, NoFreePlotTeleporting, `persistence.load` never called |
| | stops teleporting after the attempt limit | `attempt=3` → NoFreePlot, no teleport |
| | rate-limits and serializes save actions | 6th Create in 60 s → RateLimited; inner `handle(List)` from `filterName` → SaveActionBusy |
| | leaving saves, releases the lock and frees the plot | no `_session`; plot free; registry empty; `plotReleased=true` |
| | plays a failed save again after the lock is back | after SessionLocked, clearing the thief lock and Play → ready |
| | **(F9)** reload leaves and loads the active save again | play A; `play(A, {reload=true})` → ok, same plot; one onDeactivated, two onActivated; record `_session.jobId == "job-a"` |
| | **(F9)** counts a final leave until its save is written | play starter; then set the company-store `beforeUpdate`, which on its first save-key call records `activeUserIds()` = `{}` and `pendingCount()` = 1; after `leave(USER, true)`: `pendingCount()` = 0, no `_session` |
| | **(F9)** refuses new save work once shutdown begins | open profile; `beginShutdown()`; `handle(List)` → ServerShuttingDown; `play` → ServerShuttingDown; `pendingCount()` = 0 |
| | **(F9)** unloads a save whose load finishes during shutdown | `beforeUpdate` on the first save-key update calls `beginShutdown()` and records `pendingCount()` = 1; `play` → ServerShuttingDown; record has no `_session`; `freeCount()` = 2; `activeUserIds()` empty; `pendingCount()` = 0 |

## Playtest (Studio, via playtester)
1. Setup: see Fix round 2, R9 (supersedes this step).
2. Manual UI checks: the picker is visible on join; an account with a personal record sees the migrated "Tree Lot 1"; the HUD shows `hudChooseSave` and the supplier panel is hidden. Create "UI Test", Play it: the picker closes and the HUD status line shows "UI Test · Plot …" and **still shows it after 15 s** (three summary refreshes). Rename to "UI Test 2" through "Saves": the status line updates. Delete: `ConfirmDelete` stays inactive until "ui test 2" is typed, then the save disappears. Phone Device Simulator: no clipped rows or buttons.
3. `runPlaytest {mode="full"}` → 29 steps PASS, in this order: `01` (threshold `>= 205`); **`02a ACTIVE_SAVE`** (play "Playtest A", creating it if absent; `R.plotId` from the attribute); `02`–`21` unchanged; **`24 SAVE_CREATE`** (delete leftovers "Playtest B", "Playtest B2", "Playtest C" after `unlockSave`; create "Playtest B" with requestId X; replaying X returns the same saveId; list +1); **`25 SAVE_SWITCH`** (snapshot A; Play B: same `PlotId`, StartingCash, 0 placements; order 1 tree (cash −UNIT_PRICE); Play A: cash, revision, stock, placementCount equal the snapshot; Play B: StartingCash − UNIT_PRICE; Play A); **`26 SAVE_RENAME`** ("" → NameInvalid; "Playtest B2" ok and listed; "playtest a" → NameInUse); **`27 SAVE_DELETE`** (B2 with "Playtest B" → ConfirmationMismatch, still listed; A with "Playtest A" → SaveActive; B2 with " playtest b2 " → ok and gone; Play B2's ID → SaveNotFound); **`28 FAIL_CLOSED`** (create and play "Playtest C"; `lockSave C`; `flush`; within 5 s `CompanyReady == false` and `CompanyError == "SessionLocked"`; `act Supplier.PlaceOrder` → CompanyUnavailable; `unlockSave C`; Play A → ready; delete C → ok); `22`; `23` (CLEANUP also plays A if not active and deletes B/B2/C leftovers).
4. `runPlaytest {mode="soak", minutes=10}` → 6 steps PASS (`01a ACTIVE_SAVE` before `01 SHADOW_JOIN`).
5. During step 28 (or repeating it by hand): screenshot the HUD showing the `saveErrorSessionLocked` text.
6. Rejoin restores the chosen save: Stop, Play again → the picker lists "Playtest A" as `Last played`; Play → cash and stock equal the last `REJOIN` snapshot.
7. Teleport with no free plot and real shutdown: **BLOCKED in Studio** (no TeleportService; Studio stop is not a live shutdown). Covered by the headless teleport and shutdown tests; added to the friends-test checklist (order 15).

## Acceptance
- Checks: `stylua --check src tests` and `selene src tests` pass; `lune run tests/headless/run.luau` → 205 run / 205 passed; `rojo build default.project.json` and `rojo build release.project.json` pass, the release build has 0 `StudioTestService`, `UnitTest` and `RunPlaytest`; `rg "loadPersonalCompany|CompanyLoadError|getPlotForUser|plotParkingStatus" src tests` is empty.
- Backlog criteria: headless tests for migration of a personal record, save isolation, delete only with confirmation, session lock per save, fail-closed surfacing. Studio: create two saves, switch, rename, delete, and rejoin restores the chosen save.
- Skill checks: Data: UpdateAsync only, fail-closed on every read error, no fresh default over unreadable data, BindToClose waits for every active save and every final leave or save action in flight. Security: every `Save.*` field validated and rate-limited; names filtered at submission with the broadcast result; failures store nothing. GUI: touch targets ≥ 44 px; `AutoLocalize=false` on user names.

## Out of scope
- Co-op seats, members, invite codes and owner-only checks (S2). The MemoryStore save-to-server map and "Being played by X" (S3).
- Re-filtering stored names when other players are shown them (G15 lot sign, S2 member lists must do this).
- Environment-scoped store names; a region field (spec: none); an in-game language switch; restoring deleted saves (tombstones are kept, no UI).

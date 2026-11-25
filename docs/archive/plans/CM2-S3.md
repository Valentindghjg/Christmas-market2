# CM2-S3 — One server per save, teammate finder (covers CM2-39)

Written by: `planner` (Opus 5.5, high). Implemented by: the agent for the tier below. Playtested by: `playtester` (Sonnet 5.5, medium). Reviewed and committed by: `reviewer` (Opus 5.5, medium). Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
A co-op save that another server plays shows "Being played by X" with a **Join** button in the picker, and Join teleports the player into that server ("That server is full…" when it is full). A friend who types the code of a save played elsewhere is taken there too. Inside a server, a "Looking for teammates" panel lists players who want teammates; a joiner takes a free seat with no code, and the searcher owns the save.

## Source of truth
- Backlog launch order line 5 (CM2-S3), original CM2-39 (single writer, join on another server, recovery, no split brain), order 15 sub-bullet (friends test), order 5a (CM2-R5, the next task).
- PRODUCT_SPEC 2026-11-21 "Saves and multiplayer" (OWNER DECIDED: one server per save, "Being played by X – Join" teleports into that server, "Server full, try again"; an in-server "looking for teammates" list where the searcher owns the new save; cross-server matchmaking later).
- `docs/archive/plans/CM2-S1.md` (key budget and prefix rule, the no-free-plot teleport seam, `pendingCount`), `docs/archive/plans/CM2-S2.md` (`addMember(state, userId, nil)` for trusted callers, `_changeRecord`, attach, `_unloadShared`, the join lockout). DECISION_LOG 2026-11-22 entries for CM2-S1 and CM2-S2.
- Skill rules: roblox-server-data "MemoryStoreService" (game-level quotas 1000 + 120 × CCU request units per minute, HashMap `UpdateAsync` costs 2 units, `GetAsync` 1, shortest workable TTL) and roblox-security (teleport data is client-routed and untrusted).

## Implementer tier
Tier: L. Reason: cross-server state in MemoryStore next to the DataStore session lock, teleports with untrusted arrival data, a new path that writes other players' seats, and concurrency between claim, load, unload and renewal.

## Skills to load
roblox-collaboration-mode, roblox-server-data, roblox-data, roblox-networking, roblox-security, roblox-architecture, roblox-gui, roblox-input, roblox-localization, roblox-luau-core, roblox-luau-patterns, roblox-luau-types, roblox-tooling.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/server/Services/SaveLocatorService.lua` | New | The save-to-server map over a MemoryStore HashMap: `claim`, `release`, `lookup` |
| `src/server/Services/SaveSlotService.lua` | Change | Claim, release and renewal; "elsewhere" rows; `Save.Teleport`; `arrive`; the teammate finder |
| `src/shared/GameConfig.lua` | Change | `Saves` additions |
| `src/shared/Protocol.lua` | Change | 5 new `Save.*` actions and their payload checks |
| `src/shared/Localization.lua` | Change | Error and UI keys (en + faithful de) |
| `src/server/main.server.lua` | Change | Locator and teleport wiring, arrival, `TeleportInitFailed`, renewal loop, `FinderRevision` |
| `src/server/Services/StudioTestService.lua` | Change | `locatorEntry`, `placeElsewhere`, `clearElsewhere`, `renewLocations` |
| `src/client/SavePicker.client.lua` | Change | "Being played by X" rows with Join, teleport after a code join, `FindTeammates` button, `SaveTeleportError` |
| `src/client/TeammateFinder.client.lua` | New | `FinderButton` and `FinderPanel` |
| `tests/headless/run.luau` | Change | Register `SaveLocatorService` |
| `tests/studio/Cases/*_Test.lua` | New/Change | See Tests |
| `tests/studio/Playtest/RunPlaytest.lua` | Change | Steps 33–35, threshold 271, `BUILD = "cm2-s3"` |
| `docs/TECHNICAL_ARCHITECTURE.md`, `docs/DECISION_LOG.md`, `docs/TEST_PLAN.md` | Change | Step 11 |

## Data and config
**Store choice: MemoryStore HashMap** `CM2_SaveServers_v1` (Studio: `CM2_SaveServers_v1_Studio`, so Studio entries never mix with live ones). A HashMap fits point lookups by key; a SortedMap adds sort cost we do not need (roblox-server-data table). Key `save:<saveId>` (`SaveLocatorService.keyFor`), at most 41 chars (limit 128); it fills the foreseen S1 key-budget row.

| Value | Fields |
|---|---|
| Held | `{jobId: string, placeId: number, hostUserId: number, renewedAt: number}`, TTL `LocatorTtlSeconds` |
| Released (tombstone) | `{jobId, placeId, releasedAt: number}`, TTL `LocatorReleasedTtlSeconds`; counts as free |

**Authority.** The DataStore `_session` lock stays the only authority for writing a save; nothing about writes changes. The map is a locator and a pre-check: its atomic `UpdateAsync` lets at most one live server hold an entry, so two servers never both start loading one save. A wrong or missing entry can only send a player to the wrong place or show a stale row. It can never cause a second writer, because a load still needs the lock. So the map **fails open**: if MemoryStore is down, Play loads as in S2 (the lock decides), and the renewal claims the entry later.

**Timing.** TTL 90 s < `SessionLockSeconds` 120 s. After a crash the entry is gone within 90 s. The lock frees 60–120 s after the crash (the last save was at most 60 s earlier). In that gap Play shows the existing `SessionLocked` text ("try again in a minute"). A shorter TTL means fewer teleports to dead servers. Renewal every 30 s tolerates two missed renewals.

**`GameConfig.Saves` additions** (PROVISIONAL engineering values)
```
LocatorTtlSeconds = 90, LocatorRenewSeconds = 30, LocatorReleasedTtlSeconds = 30,
LocatorAttempts = 2, LocatorListLookups = 8, LocatorCacheSeconds = 15,
LocatorMapName = "CM2_SaveServers_v1", FinderDefaultSize = "Duo",
RateLimits += { ["Save.Teleport"]={limit=3,window=60}, ["Save.FinderStart"]={limit=3,window=300},
  ["Save.FinderStop"]={limit=5,window=60}, ["Save.FinderList"]={limit=20,window=10},
  ["Save.FinderJoin"]={limit=5,window=60} }
```
**Request budget** (game-level 1000 + 120 × CCU units/min; HashMap `UpdateAsync` 2 units, `GetAsync` 1). Per player in the worst case: renewal ≈ 2 (≤ 6 saves per 12 players, 2 renewals/min × 2 units), claim and release on Play ≈ 4, List lookups ≤ 8 rows × 4 refreshes/min (15 s cache) = 32, Teleport 3. That is about 41 units, well under 120. On a store error each call tries `LocatorAttempts` times with a 1 s wait and then gives up, with no retry storm.

**Teleport data** (`TeleportOptions:SetTeleportData`): `{ cm2Join = { saveId = <saveId>, code = <code or nil> } }`. S1's `cm2NoFreePlot` stays as it is.

**Reserved vs public servers: public.** The game runs on normal public servers of the one place (12 players, 6 plots, the S1 no-free-plot teleport). Join targets the existing public server through `TeleportOptions.ServerInstanceId = jobId`. Reserved servers were rejected: they need `ReserveServer` access codes per save, break Roblox "join friend", and would split the 12-player village. `TeleportAsync` (server-side, the S1 pattern) replaces the legacy `TeleportToPlaceInstance`; both reach a given JobId. No owner input is needed: teleports inside one place need no game setting. **Studio cannot teleport**, so `teleportToServer` returns `TeleportUnavailable` there.

**Player attribute (server-set) added:** `SaveTeleportError` (string `<code>:<n>`, where `n` counts up so a repeated error still fires the change; `Localization.saveErrorKey` already drops everything from `:`). **ReplicatedStorage attribute:** `FinderRevision` (int, +1 on every listing change).

## Amendment A1 (2026-11-22, after steps 1–3; wins over the step text below)
Steps 1–3 are done (headless 252/252). These decisions answer the implementer's step-4 report.

**A1.1 No-free-plot leak (option A).** Add `SaveSlotService:_idle(companyId) → boolean` = `_members[id] == nil and (_pendingLoads[id] or 0) == 0 and not _unloading[id] and not companies:hasSession(id)`. The failure block after the load loop uses `_idle` for its existing condition (plot release, then `_releaseLocation(saveId)`, both inside it). The no-free-plot branch in the loop becomes: `_endLoad`, then `if self:_idle(companyId) then self:_releaseLocation(saveId) end`, then the S1 teleport and return as now. The release comes before `self._teleport(...)`, so the next server finds a tombstone and its Play claims (`Claimed`).
Audit of the other exits after the claim (no change needed):

| Exit | Entry |
|---|---|
| in-loop `_canAttach` then `_attach` | Kept: a live session here holds it, and renewal covers `_members` |
| step f `NotAMember`, step g `PlayerLeft`/`ServerShuttingDown` | Released by `_unloadShared` (step 4 bullet), after `_endLoad` |
| a thrown error (`play` → `InternalError`) | Leaks until the TTL, like `_pendingLoads` today; accepted |
| claim refusal (`SaveInUse`/`SaveInUseElsewhere`) | Nothing was written, nothing to release |

Accepted race: an `_unloadShared` that checked its condition before this Play's claim may tombstone the fresh claim. The map fails open and the next renewal (≤ `LocatorRenewSeconds`) claims it again. The claim stays before `_pendingLoads += 1`.

**A1.2 Signature.** `_claimLocation(saveId, companyId, userId, saveSize: string)`; `_play` passes `entry.size`. `saveSize == "Solo"` plus `HeldElsewhere` → `false, "SaveInUse"`.

**A1.3 Name clash.** `self._teleport` is the S1 dependency (an instance field that shadows any method of that name). The step-7 handler is named `SaveSlotService:_teleportToSave(userId, profile, payload)`.

**A1.4 `TeleportInitFailed(player, result)`**, in this order: `result == Enum.TeleportResult.IsTeleporting` → return and change nothing (this keeps `joinTeleports[userId]` and also skips the S1 `CompanyError`); then, with `joinTeleports[userId]`: clear it, map the result as in step 10 and set `SaveTeleportError`; without it: S1 `CompanyError = "NoFreePlot"`.

**A1.5 Listing changes.** `_listingsChanged()` runs only when `_listings` actually gained, replaced or lost an entry: in `_validListing` and `_deregister` only after a removal, and in FinderStart only in sub-step 4 (never in sub-step 1). A final `leave` with no listing changes nothing.

**A1.6 `fakeMap.failCount`** is a switch and never decrements: every call throws while it is > 0. Tests set it back to 0. CrossServer_Test has its own copy of the SaveLocatorService_Test `fakeMap`. TeammateFinder_Test runs without a locator.

**A1.7 StudioTestService** returns as `flush` does:

| Command | Ok | Error |
|---|---|---|
| `locatorEntry` | `success({entry = <GetAsync value or nil>})` | `NotOwnSave`; a pcall error → `failure("LocatorUnavailable")` |
| `placeElsewhere` | `success({placed = true})` | same |
| `clearElsewhere` | `success({cleared = <boolean>})` | same |
| `renewLocations` | `success({ok, renewed, failures})` | none |

Playtest steps 33–34 read the entry from `data.entry`.

**A1.8 Playtest step 35.** Keep `join = FinderJoin` response. Then assert the real player's `PlotId == join.data.plotId` (not `S.plotId`) and `ActiveSaveRole == "Member"`.

**A1.9 Tests.** One new CrossServer_Test case, and extra asserts in two finder cases (the count does not change for those). The new total is **271**. `RunPlaytest` threshold is 271; TEST_PLAN §3b says "at least 271".

| Test case file | Test name | Asserts |
|---|---|---|
| CrossServer_Test | a full server releases its claim before it sends the player on | Claim every plot of job-a with `save:77_other_<n>`; OWNER Play of the Duo on job-a → `NoFreePlotTeleporting`, one S1 teleport recorded; the map entry is a job-a tombstone (`releasedAt` set); OWNER Play on job-b → ok, the entry is held by job-b |
| TeammateFinder_Test | (extend) an own co-op save with a free seat is listed instead | the handler count rises by 1 on the first FinderStart; a second FinderStart and a FinderList leave it unchanged |
| TeammateFinder_Test | (extend) removes the listing on stop, switch, leave and a failed session | a final leave of FRIEND, who has no listing, leaves the handler count unchanged |

## Steps
1. **GameConfig** as above.
2. **Protocol.lua:** add `Teleport="Save.Teleport"`, `FinderStart="Save.FinderStart"`, `FinderStop="Save.FinderStop"`, `FinderList="Save.FinderList"`, `FinderJoin="Save.FinderJoin"`. Payload keys: Teleport `{saveId, code}`, FinderStart `{size}`, FinderStop `{}`, FinderList `{}`, FinderJoin `{saveId}`. The generic `saveId` check skips Teleport. Teleport: both fields present or both absent → `InvalidTeleportTarget`; `saveId` present and not `isSaveId` → `InvalidSaveId`; `code` present and not `isInviteCode` → `InvalidInviteCode`. FinderStart: `size` absent is allowed; otherwise it must be `Duo`, `Trio` or `Quad`, else `InvalidSize` (Solo also gives `InvalidSize`).
3. **SaveLocatorService.lua** (new; no `GetService`, everything injected). `SaveLocatorService.keyFor(saveId) = "save:" .. saveId`. `new(map, jobId: string, placeId: number, clock, wait)`. Every transform resets its upvalue results first. Each call makes `LocatorAttempts` attempts with `wait(1)` between them and never throws.
   - `valid(value)` (local): a table with a `jobId` string of 1–64 bytes and `placeId` a positive integer. For a held value, `hostUserId` is a positive integer and `releasedAt` is nil.
   - `claim(saveId, hostUserId) → ("Claimed" | "HeldElsewhere" | "Unavailable", location?)`: `map:UpdateAsync(key, transform, LocatorTtlSeconds)`. A previous value that is held, valid, and has `jobId ~= self._jobId` → return nil (no write) and capture `location = {jobId, placeId, hostUserId}`. Otherwise (nil, invalid, released or ours) write `{jobId, placeId, hostUserId, renewedAt = clock()}`. A store error after the retries → `"Unavailable"`.
   - `release(saveId) → boolean`: `UpdateAsync` with TTL `LocatorReleasedTtlSeconds`. Only a held value with our `jobId` becomes `{jobId, placeId, releasedAt = clock()}`; otherwise no write and `false`.
   - `lookup(saveId) → (location?, err?)`: `map:GetAsync(key)`. It returns a location only for a held, valid value with another `jobId` and `placeId == self._placeId`; everything else → nil. A store error → `nil, "LocatorUnavailable"`.
4. **SaveSlotService.lua: locator core.** New deps `locator` (optional; nil disables every locator step, so the existing tests stay as they are) and `teleportToServer(userId, placeId, jobId, data) → (boolean, string?)`. New fields `_since = {}`, `_registerSeq = 0`, `_locationCache = {}`, `_listings = {}`, `_finderSeq = 0`, `_onListingsChanged = nil`; `setFinderHandler(onListingsChanged)`.
   - `_register` sets `_since[userId] = _registerSeq + 1` (and increments the counter). `_deregister` clears `_since[userId]` and removes `_listings[userId]` when its `companyId` matches, then calls `_listingsChanged()`.
   - `_hostOf(companyId) → number?`: `ownerUserIdOf(saveId)` when the owner is registered on it here, else the registered user with the smallest `_since`. This is "X": the owner when they play it on that server, else the member who has played it there longest.
   - `_claimLocation(saveId, companyId, userId) → (true) | (false, code, data)`: without a locator → true. `claim(saveId, _hostOf(companyId) or userId)`. Then clear `_locationCache[saveId]`. `HeldElsewhere`: a Solo entry → `false, "SaveInUse"` (its only player is this one, so the other session is stale); otherwise `false, "SaveInUseElsewhere", {hostName = _nameOf(location.hostUserId)}`. `Claimed`/`Unavailable` → true (fail open; `Unavailable` warns).
   - `_releaseLocation(saveId)`: locator present → `release` (result ignored), clear the cache entry.
   - `_play` step e: call `_claimLocation` after the attach check (step d) and before `_pendingLoads += 1`. A refusal returns `false, code, data` and nothing else changes. In the failure block after the load loop, call `_releaseLocation(saveId)` inside the existing plot-release condition.
   - `_unloadShared`: after `unloadCompany` and the `plotReleased` line, if `ok` and `_members[id] == nil` and `(_pendingLoads[id] or 0) == 0`, then `_releaseLocation(saveIdOf(id))`, all before `_unloading[id]` is cleared. A failed final save (`ok == false`) keeps the entry until it expires. That matches CM2-R5, where the lock stays.
   - `renewLocations() → (boolean, number, number)`: for each company in `_members` that is not `_unloading`: `claim(saveId, _hostOf(id))`. `Claimed` counts as renewed. `HeldElsewhere` warns `"[ChristmasMarket2] save %s is located on another server"` and counts as a failure (the lock decides; the other server's load fails and releases). `Unavailable` also counts as a failure. Returns `(failures == 0, renewed, failures)`. No locator → `(true, 0, 0)`.
   - `_handle` Play branch: a failed Play returns `failure(playError)` with `data` attached when `_play` gave data.
5. **SaveSlotService: "Being played by X".** `_listView(profile, activeSaveId, withLocations: boolean?)`. Only the `Save.List` branch passes `true`; `listFor` (Studio hook) passes nothing. Rows that qualify, in list order and at most `LocatorListLookups`, are those that are not `active`, have `size ~= "Solo"`, and that nobody plays here (`_members[companyIdOf(saveId)] == nil`). For each such row: `_cachedLocation(saveId)` uses `_locationCache[saveId] = {at, location or false}` while `clock() - at < LocatorCacheSeconds`, else `lookup` (an error caches `false`). With a location: `row.elsewhere = true` and `row.hostName = _nameOf(location.hostUserId)` (nil when unknown).
6. **SaveSlotService: `_join` (code) when another server plays the save.** When `_changeRecord` returns `SaveInUse` and a locator exists: `location = lookup(saveId)`. With a location → `{ok=false, errorCode="SaveInUseElsewhere", data={hostName}}`. This does not count as a wrong code. Refactor: the body after `lookup(code)` moves into `_joinSave(userId, profile, saveId, code: string?)`. The `JOIN_INVALID` branch records a failure and returns `InviteCodeInvalid` only when `code ~= nil`; with `code == nil` it returns `ListingGone` and records nothing. `_join` keeps the cap check, the `lookup` and the lockout, then calls `_joinSave`.
7. **SaveSlotService: `Save.Teleport {saveId | code}`** (`_teleportToSave(userId, profile, payload)`, A1.3), in this order:
   1. no locator → `TeleportUnavailable`;
   2. `code`: `_joinLocked` → `JoinLocked`; the save cap → `SaveLimit`; `invites:lookup(code)`: `InviteCodeInvalid` records a failure and returns it, other errors return as they are; this gives `saveId`;
   3. `saveId` given: no profile entry → `SaveNotFound`;
   4. someone plays it here (`_members[companyIdOf(saveId)] ~= nil`) → `SaveNotElsewhere`;
   5. `lookup(saveId)` (fresh; it refreshes the cache): an error → `TeleportFailed`; nil → `SaveNotElsewhere`;
   6. `teleportToServer(userId, location.placeId, location.jobId, {saveId = saveId, code = payload.code})`: false → `TeleportUnavailable` when the error is that, else `TeleportFailed`;
   7. ok → `{ok=true, data={teleporting=true}}`.
8. **SaveSlotService: arrival.** `arrive(userId, data) → (ok, err?, data?)`, `data = {saveId, code?}`, already shape-checked by main. It has the same guards as `play`: `_closing` → `ServerShuttingDown`, `_busy` → `SaveActionBusy`, `pcall`, then `_runPendingKick`. `_arrive`: `_openProfile`. With `code`: `_joinLocked` → `JoinLocked`; `r = _join(userId, profile, {code = code})`; a refusal returns `r.errorCode`; `saveId = r.data.saveId` (the code wins over `data.saveId`). Then `_play(userId, saveId, nil)`. No automatic second teleport: `SaveInUseElsewhere` on arrival (the save moved again) returns that code, and the picker offers Join again. Arrival trusts nothing in `data`: Play needs the profile entry, and a code goes through the S2 join checks and lockout.
9. **SaveSlotService: teammate finder.** `_listings[ownerUserId] = {saveId, companyId, createdAt}`, one per player. `_listingsChanged()` calls `_onListingsChanged` through `callHandler`.
   - `_validListing(ownerUserId) → (listing, info)?`: the listing exists; `_active[owner] == listing.companyId`; `companies:isAvailable`; `memberRole(owner) == "Owner"`; `info = teamInfo(companyId)` with `saveSize ~= "Solo"` and `BusinessState.memberCount(info) < Seats[saveSize]`. If any check fails, remove the listing, call `_listingsChanged()` and return nil.
   - **FinderStart `{size?}`**, in order:
     1. a valid own listing → `{saveId, created=false}`;
     2. the active save qualifies (owner, available, not Solo, a free seat) → list it, `created=false`;
     3. else `_create(userId, {requestId = string.format("finder_%d_%d_%d", userId, clock(), _finderSeq + 1), payload = {size = size or FinderDefaultSize}})` (increment `_finderSeq`), then `_play(userId, newSaveId, nil)`. A failure of either returns its code (the created save stays in the list) and no listing is made. On success, list it with `created=true`.
     4. Listing it means `_listings[userId] = {...}` and `_listingsChanged()`.
     
     Response `{saveId, created}`.
   - **FinderStop `{}`**: remove the own listing if there is one (`_listingsChanged()` only when it existed); always `{stopped=true}`.
   - **FinderList `{}`**: `{listings = {{saveId, ownerUserId, ownerName = _nameOf(owner), size, seats, taken}}, ownSaveId = <own valid listing's saveId or nil>}`. Every listing goes through `_validListing`. It leaves out the requester's own listing and listings whose `info.members` already has the requester. Sorted by `createdAt`, then `ownerUserId`.
   - **FinderJoin `{saveId}`**, in order:
     1. find the listing with that `saveId`; missing or not valid → `ListingGone`;
     2. the owner is the requester → `OwnListing`;
     3. `_joinSave(userId, profile, saveId, nil)` (S2 `addMember(state, userId, nil)` through `changeTeam`; `SaveFull` passes through; `AlreadyMember` is fine);
     4. `_play(userId, saveId, nil)` (attaches to the shared plot; the joiner's previous save is left as in a switch);
     5. `_validListing(owner)` (removes the listing once it is full).
     
     Response `{saveId, plotId}`.
   - A final `leave` also removes `_listings[userId]` (through `_deregister` or directly when the player had no active save).
10. **main.server.lua**
    - `locatorMap = MemoryStoreService:GetHashMap(if RunService:IsStudio() then config.Saves.LocatorMapName .. "_Studio" else config.Saves.LocatorMapName)`.
    - `locator = SaveLocatorService.new(locatorMap, if game.JobId ~= "" then game.JobId else "studio", game.PlaceId, os.time, task.wait)`.
    - Pass `locator` and `teleportToServer` to `SaveSlotService.new`.
    - `teleportToServer`: in Studio → `false, "TeleportUnavailable"`; no player → `false, "TeleportFailed"`. Otherwise `TeleportOptions` with `ServerInstanceId = jobId` and `SetTeleportData({cm2Join = data})`, then `pcall(TeleportService.TeleportAsync, TeleportService, placeId, {player}, options)`. An error → `false, "TeleportFailed"`; ok → `joinTeleports[userId] = true`, `true`.
    - `crossServerJoin(player) → data?`: `GetJoinData()` in a pcall, with `SourcePlaceId == game.PlaceId`. `TeleportData.cm2Join` must be a table with `SaveProfile.isSaveId(saveId)` and `code` nil or `BusinessState.isInviteCode(code)`. It returns only `{saveId, code}`.
    - `onPlayerAdded`, after `ProfileReady = true`: a `crossServerJoin` → `saveSlots:arrive`; a failure sets `CompanyError`. Else the S1 `noFreePlotJoin` path.
    - `TeleportInitFailed(player, result)`: if `joinTeleports[userId]`, clear it. Map the result: `Enum.TeleportResult.IsTeleporting` → return; `GameFull` → `ServerFull`; `GameEnded` or `GameNotFound` → `SaveServerGone`; anything else → `TeleportFailed`. Then `teleportErrorSeq += 1` and `SetAttribute("SaveTeleportError", code .. ":" .. teleportErrorSeq)`. Without the flag: the S1 behaviour (`CompanyError = "NoFreePlot"`). PlayerRemoving clears `joinTeleports[userId]`.
    - Renewal: `every(config.Saves.LocatorRenewSeconds, "save locator", function() return saveSlots:renewLocations() end)`.
    - `saveSlots:setFinderHandler(function() ReplicatedStorage:SetAttribute("FinderRevision", (current or 0) + 1) end)`.
    - The hook context gains `locatorMap` and `locatorKey = SaveLocatorService.keyFor`.
11. **Docs**
    - TECHNICAL_ARCHITECTURE §5: the key-budget row becomes `save:<saveId>` | 41 | MemoryStore HashMap `CM2_SaveServers_v1` (limit 128). Add a short "Save-to-server map" paragraph: authority, fail open, TTL vs lock, renewal, release on the last unload, public servers. §2 names `SaveLocatorService`.
    - DECISION_LOG entry "2026-11-22 - One server per save and teammate finder, CM2-S3 (engineering)" with:
      - the HashMap choice;
      - the lock as the authority, with the map failing open;
      - TTL 90 / renew 30 against the 120 s lock;
      - public servers through `ServerInstanceId` (reserved servers rejected);
      - X = the owner, else the longest-playing member;
      - lookups only for co-op rows (Solo held elsewhere = a stale session → `SaveInUse`);
      - no automatic retries or second hops;
      - the finder rule (list the own co-op save with a free seat, else create a new one);
      - the budget;
      - the Studio map name.
    - TEST_PLAN §3b: 36 steps, at least 271 tests, plus the three new step descriptions.
12. **Localization.lua** (`SaveErrorKeys` additions; en below plus a faithful de):

    | Code | Key | English |
    |---|---|---|
    | SaveInUseElsewhere | saveErrorElsewhere | This save is being played on another server. Tap Join to go there. |
    | ServerFull | saveErrorServerFull | That server is full. Please try again in a moment. |
    | SaveServerGone | saveErrorServerGone | That server has closed. Please choose the save again in a minute. |
    | TeleportFailed | saveErrorTeleportFailed | Moving you to the other server did not work. Please try again. |
    | TeleportUnavailable | saveErrorTeleportUnavailable | Moving between servers does not work here. |
    | SaveNotElsewhere | saveErrorNotElsewhere | This save is no longer played on another server. Tap Play or Join again. |
    | ListingGone | saveErrorListingGone | That player is no longer looking for teammates. |
    | OwnListing | saveErrorOwnListing | This is your own listing. |

    `InvalidTeleportTarget` uses the fallback.
    UI keys:

    | Key | English |
    |---|---|
    | `saveRowElsewhere` | Being played by %s |
    | `saveRowElsewhereUnknown` | Being played on another server |
    | `saveJoinServer` | Join |
    | `teleportJoining` | Taking you to the server where this save is being played… |
    | `finderButton` | Teammates |
    | `finderOpen` | Find teammates |
    | `finderTitle` | Looking for teammates |
    | `finderHint` | Players on this server who want teammates. Join one to share their lot. |
    | `finderEmpty` | Nobody on this server is looking for teammates right now. |
    | `finderSeats` | %d of %d seats are taken. |
    | `finderJoin` | Join |
    | `finderStart` | Look for teammates |
    | `finderStartHint` | If you play your own co-op save with a free seat, it is listed. Otherwise you get a new save of the chosen size. |
    | `finderOwnListing` | Your save is listed. Players on this server can join it. |
    | `finderStop` | Stop looking |
13. **SavePicker.client.lua**
    - **Rows:** with `entry.elsewhere`, the `SaveState` label shows `saveRowElsewhere` with `hostName` (`AutoLocalize = false`), or `saveRowElsewhereUnknown` when `hostName` is nil. The `Play` button shows `saveJoinServer` and sends `Save.Teleport {saveId}`: ok → status `teleportJoining`, error → `showError`. A row `Play` that returns `SaveInUseElsewhere` shows the error and calls `refreshList()`.
    - **Code join:** a `Save.Join` that returns `SaveInUseElsewhere` sends `Save.Teleport {code}` at once (the tap already says "join"), with the same ok and error handling.
    - **Header:** `Title` and `Hint` widths become `(0.6, -4)`. New button `FindTeammates` (`finderOpen`, SAND), anchor (1,0), position (1,0,0,0), size (0.4,−4,0,`BUTTON_HEIGHT`). Its tap fires `PlayerGui.FinderUI.Open` (a BindableEvent; it does nothing when that is missing).
    - **Teleport errors:** listen to `SaveTeleportError`; on a change to a non-nil value, `open()` if closed and `showError(value)`.
14. **TeammateFinder.client.lua** (new; patterns as in TeamPanel; targets ≥ 44 px):
    - ScreenGui `FinderButtonUI` (`DisplayOrder = 15`) with `FinderButton` (`finderButton`, 120×44, anchor (1,0), position (1,−228,0,12)), visible while `CompanyReady == true`.
    - ScreenGui `FinderUI` (`DisplayOrder = 25`, above the picker), with a BindableEvent `Open` and the Frame `FinderPanel` (anchor 0.5,0.5; scale 0.92×0.8; `UISizeConstraint` max 420×560; hidden at start):
      - `Title` (`finderTitle`), `Hint` (`finderHint`, wrapped);
      - ScrollingFrame `ListingList` with rows `Listing_<n>` (64 px): `OwnerName` (`AutoLocalize = false`, nil → `teamUnknownPlayer`), `ListingSeats` (`finderSeats` taken, seats), and `JoinListing` (`finderJoin`, GOLD, width 0.3); an empty list shows `Empty` (`finderEmpty`);
      - footer with no own listing: `Size_Duo`/`Size_Trio`/`Size_Quad` toggles (width 1/3, default Duo, selected GOLD), `StartListing` (`finderStart`), `StartHint` (`finderStartHint`, 13 px, wrapped);
      - footer with an own listing: `OwnListing` (`finderOwnListing`) and `StopListing` (`finderStop`);
      - then `Close` (`teamClose`) and `FinderStatus` (errors through `Localization.saveErrorKey`).
    - Fetch `Save.FinderList` on open, after every action, and on a `ReplicatedStorage` `FinderRevision` change while open. One request is in flight at a time, and a change during a request sets `refetchPending` (S2 A1 rule).
    - A successful `FinderJoin` or `FinderStart` closes the panel (the picker closes itself on `CompanyReady`).
    - The panel opens from `FinderButton` or the `Open` event.
15. **StudioTestService.lua.** New commands. The `{userId, saveId}` ones only act on saves in that user's list (the `ownedSaveId` rule).
    - `locatorEntry {userId, saveId}` → the raw `locatorMap:GetAsync(key)` value;
    - `placeElsewhere {userId, saveId}` → `SetAsync(key, {jobId = "studio-test-elsewhere", placeId = game.PlaceId, hostUserId = SHADOW_USER_ID, renewedAt = os.time()}, 300)`;
    - `clearElsewhere {userId, saveId}` → `RemoveAsync(key)` only when the stored `jobId == "studio-test-elsewhere"`;
    - `renewLocations` → `{ok, renewed, failures}`.

## Tests (headless)
Expected total: 245 + 26 = **271** (A1.9 adds one CrossServer_Test case to the table below). New fakes: `fakeMap(env)` stores `{value, expiresAt}`, deep-copies, and treats `env.now >= expiresAt` as nil. Its `UpdateAsync(key, transform, ttl)` errors for `#key > 128` and for a `ttl` that is not an integer in 1..3888000. It runs an optional `beforeUpdate(key)` and throws while `failCount > 0`. `GetAsync` and `SetAsync` behave the same way. A `teleports` recorder stands in for TeleportService. `CrossServer_Test` builds two stacks (job-a and job-b) over shared stores and one map, using CoopSave_Test's `newStack` pattern.

| Test case file | Test name | Asserts |
|---|---|---|
| SaveLocatorService_Test (new) | claims a free save and renews it | `Claimed`; the value has job-a, placeId, hostUserId; at +60 s a claim → `Claimed`, expiry now+90; the key for a 19-digit save ID is ≤ 41 chars |
| | never lets two servers hold one save | job-a `Claimed`; job-b `HeldElsewhere` with `location.jobId == "job-a"`; a `beforeUpdate` that makes job-a claim first inside job-b's call → job-b `HeldElsewhere` |
| | frees a save after a crash once the TTL passes | job-a claims and never renews; +89 s job-b `HeldElsewhere`; +91 s `Claimed`; then job-a → `HeldElsewhere`; `LocatorTtlSeconds < SessionLockSeconds` and `3 * LocatorRenewSeconds <= LocatorTtlSeconds` |
| | releases only its own claim | job-b release of job-a's → false, value unchanged; job-a release → tombstone; job-b `Claimed`; a lookup from job-a sees job-b |
| | looks up only other servers in this place | own → nil; other job → location; other placeId, a string, `jobId` "" or 65 chars, a tombstone → nil; a throwing map → `nil, "LocatorUnavailable"` |
| | reports an unavailable store without throwing | `failCount = 2` → claim `Unavailable`, release false, no error raised |
| CrossServer_Test (new) | shows who plays a save on another server | OWNER plays a Duo on job-a; FRIEND (member) on job-b: `Save.List` row `elsewhere = true`, `hostName` = OWNER's name; Play → `SaveInUseElsewhere`, `data.hostName`; job-b `loads == 0` |
| | names the owner, else the longest-playing member | job-a: FRIEND plays first, then OWNER attaches; `renewLocations` → host OWNER; OWNER switches away → renew → host FRIEND |
| | a code join while another server plays the save offers that server | THIRD Join on job-b → `SaveInUseElsewhere`; `recentCount` of failures 0; the record lacks THIRD |
| | Save.Teleport sends the player to the server holding the save | FRIEND `{saveId}` → one teleport `(FRIEND, placeId, "job-a", {saveId})`, `{teleporting=true}`; THIRD `{code}` → data carries the code; a wrong code → `InviteCodeInvalid`, counted; nobody plays it → `SaveNotElsewhere`, no teleport; a save not in the profile → `SaveNotFound` |
| | arrival attaches the player on the save's server | `arrive(FRIEND, {saveId})` on job-a → same plot, total loads 1; `arrive(THIRD, {saveId, code})` on a Trio → member entry, attached; a wrong code → `InviteCodeInvalid`, counted; no entry and no code → `SaveNotFound` |
| | arrival loads the save when it is no longer played there | OWNER left job-a; `arrive(FRIEND)` on job-a → loaded, the map holds job-a |
| | a crashed server's save plays elsewhere after the TTL and the lock | job-a plays (claim + lock) and is dropped without a leave; +91 s job-b Play → `SessionLocked`, the map entry is a job-b tombstone; +121 s → ok, `_session.jobId == "job-b"` |
| | the last leaver and a failed load release the entry | job-a leave → job-b `lookup` nil; thief lock → Play `SessionLocked` → entry released |
| | a failed final save keeps the entry | record key in `failKeys`; final leave → map entry still job-a held |
| | renewal survives a store outage | two saves played; `failCount = 2` → `(false, 0, 2)`; then `(true, 2, 0)` |
| TeammateFinder_Test (new; one stack) | starting a search creates a co-op save owned by the searcher | OWNER on Solo: FinderStart `{size="Trio"}` → `created = true`; new Owner Trio entry is active; record members only OWNER; FRIEND's FinderList shows it with `ownerName`, seats 3, taken 1 |
| | an own co-op save with a free seat is listed instead | active owned Duo → `created = false`, same saveId; a second FinderStart → same listing |
| | a joiner takes a seat without a code on the shared plot | FRIEND FinderJoin → ok, OWNER's plot; FRIEND entry Member; record 2 members; the Duo is full → FinderList empty; `onListingsChanged` called |
| | refuses full, own and gone listings | THIRD on the full Duo → `ListingGone`; OWNER on own → `OwnListing`; unknown saveId → `ListingGone`; no wrong-code failure recorded |
| | removes the listing on stop, switch, leave and a failed session | FinderStop → gone; relist, then OWNER plays another save → gone; relist, final leave → gone; relist, thief lock + flush, FRIEND Play (evict) → gone |
| | rate-limits starting a search | the 4th FinderStart within 300 s → `RateLimited` |
| | keeps member names out and lists in creation order | two listings → order by `createdAt`; rows have no `name` field |
| Protocol_Test | validates teleport and finder payloads | Teleport `{saveId}` and `{code}` ok; both or neither → `InvalidTeleportTarget`; a bad code → `InvalidInviteCode`; FinderStart `{}`, `{size="Quad"}` ok, `"Solo"` → `InvalidSize`; extra key → `UnexpectedField` |
| Localization_Test | has every cross-server and finder key in English and German | every key of step 12 in `en` and `de`; `saveErrorKey("ServerFull:3")` → `saveErrorServerFull` |

`run.luau` registers `SaveLocatorService = "src/server/Services/SaveLocatorService.lua"`.

## Playtest (Studio, via playtester)
1. Setup as S2 (Rojo serve, plugin, API access, which MemoryStore also needs). Confirm `RunPlaytest.BUILD == "cm2-s3"`.
2. `runPlaytest {mode="full"}` → **36 steps PASS**, with `01` at `>= 271`. Steps 33–35 run after 32 and before 22:
   - **`33 LOCATOR_CLAIM`** (02a): `locatorEntry` for the real player's active save → `jobId == "studio"`, `hostUserId == R.userId`, no `releasedAt`; `renewLocations` → ok with renewed ≥ 1.
   - **`34 ELSEWHERE`** (02a):
     - Delete a leftover "Playtest Far". Create it with `size="Duo"`, play it, then play A: `locatorEntry` for Far has `releasedAt`.
     - `placeElsewhere` Far, then `lockSave` Far. `Save.List` row Far → `elsewhere == true`. Play Far → `SaveInUseElsewhere`; `Save.Teleport {saveId=Far}` → `TeleportUnavailable`.
     - `clearElsewhere`, `unlockSave`; Play Far → ok; Play A; delete Far → ok.
   - **`35 FINDER`** (02, 02a):
     - Shadow FinderStart `{size="Duo"}` → ok, `created == true` (S.finderSaveId). Real FinderList shows it (`ownerUserId == SHADOW`, seats 2, taken 1).
     - Real FinderJoin → ok; real attribute `PlotId == join.data.plotId` (A1.8), `ActiveSaveRole == "Member"`. FinderList now has no listing. Shadow2 FinderJoin → `ListingGone`.
     - Real `Save.LeaveTeam {S.finderSaveId}` → ok; Play A.
     - Shadow FinderStart again → `created == false`, same save, listed. Shadow FinderStop → real FinderList empty. Shadow FinderStart → listed; the shadow plays its first save → the listing is gone.
     - The shadow deletes `S.finderSaveId` with its listed name → ok.
   - CLEANUP also deletes "Playtest Far" and `S.finderSaveId` if they are left over, and runs `clearElsewhere`.
3. `runPlaytest {mode="soak", minutes=10}` → 6 steps PASS (unchanged).
4. Manual UI (real client, MCP):
   - In the picker, `FindTeammates` opens `FinderPanel` above it.
   - With a shadow listing (hook `saveAction` FinderStart for `999999999001`), the `Listing_1` row shows; tap `JoinListing` → `ActiveSaveRole == "Member"`. Screenshot.
   - During the `placeElsewhere` setup by hand, the Far row shows "Being played on another server" with a `Join` button; tapping it shows the `saveErrorTeleportUnavailable` text. Screenshot.
5. **BLOCKED in Studio** (no TeleportService, one server): a real cross-server Join from a row, a code join that teleports, "server full", a crash taking the save over, and teleport arrival. These are covered headlessly and listed in the friends-test checklist (order 15).

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` → 271 run / 271 passed, `rojo build default.project.json` and `release.project.json` (release: 0 `StudioTestService`/`UnitTest`/`RunPlaytest`).
- Grep: `rg "GetService\(\"MemoryStoreService\"\)" src/server/Services` is empty (it is injected from main); `rg "TeleportToPlaceInstance" src` is empty.
- Backlog criteria:
  - headless, with a fake MemoryStore: claim, renew, expiry after a crash, never two servers holding one save;
  - Studio: the in-server list (step 35, manual item 4);
  - the cross-server teleport is BLOCKED and on the order-15 checklist.
- CM2-39: no split brain (the lock stays the authority; the crash test shows takeover only after the lock expires) and no double payout (unchanged paths).
- Skill checks:
  - Server data: a TTL on every write; game-level budget computed; no retry storm.
  - Security: teleport data re-validated on arrival; every new field validated and rate-limited; the code lockout also covers `Save.Teleport`; no save names in finder rows or elsewhere rows.
  - GUI: targets ≥ 44 px; `AutoLocalize = false` on usernames.

## Out of scope
- Cross-server matchmaking and cross-server finder listings (spec: a later update); a seats-free hint in the map.
- Automatic teleport retries and multi-hop follow-ups; MessagingService kicks across servers.
- CM2-R5 (order 5a, next): its retrying unload must keep renewing the locator entry. `renewLocations` covers only `_members`, so R5 adds its retrying companies there, and `_unloadShared` already releases only after a successful unload.

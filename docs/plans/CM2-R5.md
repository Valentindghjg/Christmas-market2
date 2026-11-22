# CM2-R5 — Keep the save lock when the final save fails

Written by: `planner` (Opus 5.5, high). Implemented by: the agent for the tier below. Playtested by: `playtester` (Sonnet 5.5, medium). Reviewed and committed by: `reviewer` (Opus 5.5, medium). Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
When a player leaves, switches saves or the server shuts down while saving fails, nothing since the last good save is thrown away early. The server keeps the session and retries the final save with backoff. It releases the DataStore lock and the save-to-server map entry only after a successful save; otherwise both expire on their own. A healthy save that cannot be stored on a switch keeps the player on it with a clear message.

## Source of truth
- Backlog launch order 5a (CM2-R5) with acceptance (a)–(d). Found by the CM2-S1 review.
- `docs/plans/CM2-S2.md` (`_unloadShared`, `_pendingLoads`/`_unloading` hand-over, Amendment A3) and `docs/plans/CM2-S3.md` (step: release the map entry only after a successful unload; out-of-scope note on R5 renewal). `docs/plans/CM2-S1.md` F6/F7 (`beginShutdown`, `pendingCount`, BindToClose 25 s).
- TECHNICAL_ARCHITECTURE §5 "Implemented policy" and "Shutdown". DECISION_LOG 2026-11-22 CM2-S2 "Plot hand-over" (the failed-final-save case stays with R5).
- Skill rules: roblox-data (`BindToClose` finishes pending work; handle throttling and transient errors with `UpdateAsync`), roblox-server-data (MemoryStore TTL, game-level budget).

## Implementer tier
Tier: L. Reason: DataStore session-lock release rules, data loss on leave, switch and shutdown, and concurrency between a retrying unload, waiting loads and the locator.

## Skills to load
roblox-collaboration-mode, roblox-data, roblox-server-data, roblox-luau-core, roblox-luau-patterns, roblox-luau-types, roblox-localization, roblox-tooling.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/GameConfig.lua` | Change | `UnloadRetry` |
| `src/server/Services/CompanyStateService.lua` | Change | Retrying `unloadCompany`, abort option, `beginShutdown`, `unloadingCount`, injected `wait` |
| `src/server/Services/SaveSlotService.lua` | Change | Host and abort through `_unloadShared`, locator renewal during retries, `SwitchSaveFailed`, `pendingCount`, shutdown hand-off |
| `src/server/main.server.lua` | Change | Pass `task.wait` to `CompanyStateService.new` |
| `src/shared/Localization.lua` | Change | `SessionBusy` and `SwitchSaveFailed` texts (en + de) |
| `tests/studio/Cases/CompanyStateService_Test.lua` | Change | 8 tests |
| `tests/studio/Cases/SaveSlotService_Test.lua` | Change | wait injection, 4 tests, 1 assert changed (R5-A1) |
| `tests/studio/Cases/CoopSave_Test.lua` | Change | wait injection, 1 test |
| `tests/studio/Cases/CrossServer_Test.lua` | Change | wait injection, 1 test, 1 assert added |
| `tests/studio/Cases/TeammateFinder_Test.lua` | Change | wait injection only |
| `tests/studio/Cases/GameConfig_Test.lua` | Change | 1 test |
| `tests/studio/Playtest/RunPlaytest.lua` | Change | `BUILD = "cm2-r5"`, step 01 threshold 286 |
| `docs/TECHNICAL_ARCHITECTURE.md` | Change | §5 policy text |
| `docs/DECISION_LOG.md` | Change | New CM2-R5 entry |

## Data and config
No schema change, no migration. New key in `GameConfig.lua`, directly after `SaveFailClosedSeconds`, with the comment shown:

```lua
-- Final save on unload (CM2-R5, PROVISIONAL). A failed final save is retried after each
-- delay in turn (8 attempts, 78 s of waits), never past SaveFailClosedSeconds after the
-- unload began, and never past ShutdownSeconds after shutdown began (BindToClose waits 25 s).
GameConfig.UnloadRetry = {
	DelaysSeconds = { 2, 4, 8, 16, 16, 16, 16 },
	ShutdownSeconds = 18,
}
```
Each attempt is one `PersistenceService:save` (itself 3 `UpdateAsync` tries, 1 s and 2 s apart). Budget: at most 24 `UpdateAsync` per retrying save over about 90 s, well under the per-server write budget of 60 + 10 × players per minute.

New error codes: `SwitchSaveFailed` (to the client) and `UnloadAborted` (internal, CompanyStateService → SaveSlotService only; never sent to a client). An unload that gives up returns `SaveFailed`.

## Decisions
| Question | Decision |
|---|---|
| Retry policy | Attempt, then wait `DelaysSeconds[n]` and attempt again, until success, a lock-loss code, the list is used up (8 attempts), or the deadline. Deadline = `unloadStartedAt + SaveFailClosedSeconds`, or `min(that, shutdownAt + ShutdownSeconds)` once shutdown began. Each wait is `min(delay, deadline − now)`. A wait that ends at the deadline is followed by one last attempt, then it stops. All times use the service clock (`self._clock`). |
| Stop at once | `_save` reason `SessionLocked` or `NotLoaded` (lock lost or invalid state, `FAIL_CLOSED_SAVE_ERRORS`). A `corrupt` session makes no attempt, as today. |
| Lock release | `persistence.release` runs once, after a successful save. It also runs after `corrupt`, `SessionLocked` and `NotLoaded`, as today, because that state can never be saved (after `SessionLocked` it is a no-op). It never runs after giving up: the lock expires after `SessionLockSeconds`. |
| After giving up | The session is dropped from `_sessions`, so its unsaved changes are lost, and a warning says so. A later Play on this server loads the last stored record. It cannot load a record older than the store, and it cannot load while a retry is still running. |
| Leave (PlayerRemoving), shared last leaver, evict, `_play` steps f/g | They wait for the whole retry in their own thread, so the caller blocks. `leave` returns `SaveFailed` when it gives up. |
| Switch (`_play` a/b) and `Save.LeaveTeam` | Use `abortOnFailure`. If the first attempt fails with a retryable reason and the session is still `healthy` and no shutdown has begun, the unload is called off: the session goes live again and the player is registered on it again, with no deactivation. The result is `SwitchSaveFailed`, and the player stays on the old save, which the regular flush keeps saving. If the session is not healthy (already failed), or shutdown has begun, the call waits for the whole retry, then switches. |
| Re-Play of the same save on this server during a retry | It never attaches and never loads. `_play`'s existing loop sees `_unloading` and returns `SessionBusy` after `LoadAttempts`. `loadCompany` returns `SessionBusy` while the session exists. After a successful retry, the next Play loads the saved record. A loader that waits during the retry keeps the plot (Amendment A3, unchanged). |
| Locator during retries | It is renewed **in the unloading thread**: `_unloadShared` passes an `onRetry` callback that calls `locator:claim(saveId, hostUserId)` before every retry wait. `renewLocations` keeps skipping `_unloading` companies. The CM2-S3 out-of-scope note proposed adding retrying companies to `renewLocations`. That is dropped here because a renewal running in another thread could land after the final `release` and leave a stale held entry for 90 s. Release still happens only after a successful unload. |
| Plot during retries | It stays claimed by the save until the unload ends. `_unloadShared` now releases the map entry (which yields) **before** the plot, so no yield lies between the plot release and the caller's deactivation handler (`clearPlotVisuals`). |
| `pendingCount` | `_finalLeaves + #_busy + companies:unloadingCount()`. BindToClose is unchanged, and `saveSlots:beginShutdown()` also calls `companies:beginShutdown()`. A final leave and its own unloading session count 2; that is intended (BindToClose only waits for zero), see Amendment R5-A1. |

## Steps
1. **GameConfig**: add `UnloadRetry` as above.
2. **CompanyStateService**
   - `new(persistence, clock, randomRoll, wait)`: `self._wait = wait or function(seconds: number) task.wait(seconds) end` (lazy; Lune has no `task`). `self._shutdownAt = nil`. Module local `UNLOAD_POLL_SECONDS = 0.1`.
   - `beginShutdown()`: if `self._shutdownAt == nil`, set it to `self._clock()`.
   - `unloadingCount(): number`: the number of `_sessions` entries with `unloading == true`.
   - `_unloadDeadline(session): number`: the deadline from the Decisions table.
   - `unloadCompany(companyId: string, options: { abortOnFailure: boolean?, onRetry: ((attempt: number) -> ())? }?): (boolean, string?)`:
     1. If there is no session, return `true, nil`.
     2. If `session.unloading` (second caller, Amendment R5-A2): `while not session.unloadFinished and (self._sessions[companyId] ~= session or session.unloading) do self._wait(UNLOAD_POLL_SECONDS) end`. If `session.unloadFinished` is not true (the unload was called off and the session is live again), return `false, "UnloadAborted"`. Otherwise return `session.unloadOk == true, session.unloadError`.
     3. Set `session.unloading = true`, `session.unloadStartedAt = self._clock()`, then `_enter`/`_leave` as today.
     4. Loop (`attempt` from 1): `corrupt` → outcome `"Corrupt"`. Otherwise call `_save`. Success → `"Saved"`. A reason in `FAIL_CLOSED_SAVE_ERRORS` → that reason. Otherwise:
        - If `options.abortOnFailure and session.healthy and self._shutdownAt == nil`: set `session.unloading = false` and `session.unloadStartedAt = nil`, warn `"[ChristmasMarket2] final save of %s failed (%s); the session stays live"`, and return `false, "UnloadAborted"`.
        - `delay = UnloadRetry.DelaysSeconds[attempt]`, `remaining = self:_unloadDeadline(session) - self._clock()`. If `delay == nil or remaining <= 0`, the outcome is `"GaveUp"`.
        - Otherwise warn `"[ChristmasMarket2] final save of %s failed (attempt %d): %s; retrying in %ds"` (with the wait value), call `options.onRetry(attempt)` under `pcall` (on error, warn `"[ChristmasMarket2] unload retry hook failed for %s: %s"`), then `self._wait(math.min(delay, remaining))`.
     5. Finish: remove the session from `_sessions` if it is still there. `"Saved"`, `"Corrupt"`, `"SessionLocked"` and `"NotLoaded"` → `pcall(persistence.release)`. Results: Corrupt → `false, "InternalError"`; SessionLocked/NotLoaded → `false, <reason>`; Saved → as today (`"ReleaseFailed:<err>"` when the call throws, else `released, releaseError`). When Saved needed attempt > 1, print `"[ChristmasMarket2] final save of %s succeeded on attempt %d"`. `"GaveUp"` → no release; warn `"[ChristmasMarket2] final save of %s abandoned after %d attempts: %s; changes since the last save are lost and the lock expires on its own"`; return `false, "SaveFailed"`. Store `session.unloadOk` and `session.unloadError`, then set `session.unloadFinished = true`, before returning. The order stays: remove from `_sessions`, then `release`, then the results (Amendment R5-A2).
   - `isAvailable`, `isFailed`, `hasSession`, `flushDirty` and `_runPass` stay as they are (a retrying session is `unloading`).
3. **SaveSlotService**
   - `beginShutdown()`: also `self._companies:beginShutdown()`.
   - `pendingCount()`: add `self._companies:unloadingCount()`.
   - `_unloadShared(companyId: string, hostUserId: number?, abortOnFailure: boolean?): (boolean, string?, boolean)`:
     - Set `_unloading[companyId] = true`. When `self._locator`, `saveIdOf(companyId)` and `hostUserId` all exist, `onRetry` claims `(saveId, hostUserId)`, clears `_locationCache[saveId]` and, on `"HeldElsewhere"`, warns `"[ChristmasMarket2] save %s is located on another server during its final save"`.
     - Call `unloadCompany(companyId, { abortOnFailure = abortOnFailure == true, onRetry = onRetry })`. On `"UnloadAborted"`: `_unloading[companyId] = nil`, return `false, "UnloadAborted", false`.
     - Otherwise, in this order: if `ok`, `_members[id] == nil` and `(_pendingLoads[id] or 0) == 0`, call `_releaseLocation`. Then compute `plotReleased` (same condition) and call `_plots:release`. Then `_unloading[id] = nil` and return.
   - `_evict`: `local hostUserId = self:_hostOf(companyId)` before deregistering, then pass it.
   - `_play` steps f and g: `self:_unloadShared(companyId, userId)`.
   - `_leaveActive(userId: number, abortOnFailure: boolean?)`: move `self._companies:releaseCarried(companyId, userId)` above `_deregister`, so the carried-tree sync still reaches this player. When `last`, call `_unloadShared(companyId, userId, abortOnFailure)`. On `"UnloadAborted"`: `self:_register(userId, companyId)` and return `false, "SwitchSaveFailed"` with no `_deactivated` call (a finder listing removed by `_deregister` stays removed). The rest is unchanged.
   - `_play` a/b: `local left, leaveError = self:_leaveActive(userId, true)`. If `leaveError == "SwitchSaveFailed"`, return `false, "SwitchSaveFailed", nil`.
   - `_leaveTeam`: `self:_leaveActive(userId, true)`. If it returns `"SwitchSaveFailed"`, return `failure("SwitchSaveFailed")` before `_changeRecord`.
   - Unchanged: `leave` and `_kick` (blocking), `renewLocations`.
4. **main.server.lua**: `CompanyStateService.new(persistence, businessClock, businessRoll, task.wait)`. Nothing else changes (BindToClose already waits for `pendingCount()`).
5. **Localization**: after `saveErrorBusy` in `en`, add `saveErrorSessionBusy = "This save is still being stored on this server. Please try again in a minute."` and `saveErrorSwitchSaveFailed = "Your current save could not be stored just now, so you are still playing it. Nothing was lost. Please try again in a moment."`. In `de`: `saveErrorSessionBusy = "Dieser Spielstand wird auf diesem Server noch gespeichert. Bitte versuche es in einer Minute noch einmal."` and `saveErrorSwitchSaveFailed = "Dein aktueller Spielstand konnte gerade nicht gespeichert werden, deshalb spielst du ihn weiter. Nichts ging verloren. Bitte versuche es gleich noch einmal."`. `SaveErrorKeys`: `SessionBusy = "saveErrorSessionBusy"` and `SwitchSaveFailed = "saveErrorSwitchSaveFailed"`.
6. **Test setups**: pass a 4th `wait` argument to `CompanyStateService.new`. In SaveSlotService_Test `setup`, CoopSave_Test `newStack` and CrossServer_Test `newStack`, use `function(seconds: number) env.companyWait(seconds) end`, with `env.companyWait = noWait` in the env table. In TeammateFinder_Test, use a no-op function. If any other existing test then fails because `task` is nil, pass `function() end` in that call and change nothing else.
7. **Docs**
   - TECHNICAL_ARCHITECTURE §5: replace "Leave/shutdown perform a final save and release." with a sentence on retries: a failed final save is retried after 2, 4, 8, 16, 16, 16 and 16 s, for at most `SaveFailClosedSeconds` and at most 18 s after shutdown begins; the lock and the map entry are released only after a successful save, otherwise they expire; a switch away from a healthy save that cannot be stored keeps the player on it (`SwitchSaveFailed`); a Play during the retry gets `SessionBusy`. The "Shutdown" bullet gains "and retrying final saves (`unloadingCount`)".
   - DECISION_LOG: add the entry `## 2026-11-22 - Keep the save lock when the final save fails, CM2-R5 (engineering)`, with one bullet each for the retry policy, the release rule, giving up, the switch abort, the in-thread locator renewal (and why it replaces the S3 note), and the locator-before-plot order.

## Tests (headless)
New tests in CompanyStateService_Test go at the end of the file, after `deepCopy`. "Fake" means inline `load`/`save`/`release` functions:
- `load` returns `deepCopy(records[id])` when a record exists, else `BusinessState.new`.
- `save` logs `"save"` and returns `false, "SaveFailed:Throttled"` while `failures > 0` (counting down), else stores `deepCopy(state)` and returns true.
- `release` logs `"release"`.

The `wait` argument records its values in `waits`. Order request: `order(...)` from the file. In SaveSlotService_Test, "order" means `env.companies:handle("save:" .. saveId, USER, {version = 1, requestId = <unique>, action = "Supplier.PlaceOrder", payload = {speciesId = "DouglasFir", sizeId = "Medium", quantity = 1}})` with `ok` asserted. Its live cash is `GameConfig.StartingCash − GameConfig.wholesaleFor("DouglasFir", "Medium")`.

| Test case file | Test name | Asserts |
|---|---|---|
| CompanyStateService_Test | a final save that fails twice is retried and releases once after success | save fails 2× (`"SaveFailed:Throttled"`) → `unloadCompany` = `true`; `log` = save, save, save, release; `waits` = {2, 4}; `onRetry` saw {1, 2}; stored `cash`, `revision` and pending-order count equal the live state after the order (**a**) |
| | a final save that always fails keeps the lock and gives up | `false, "SaveFailed"`; 8 saves, 0 releases; `waits` = {2, 4, 8, 16, 16, 16, 16}; `hasSession` false (**b**) |
| | a lost lock ends the final save at once | save → `"SessionLocked"`: `false, "SessionLocked"`; 1 save; `waits` empty; 1 release |
| | a shutdown caps the final save retries | wait advances the clock; `beginShutdown()` at 100; always fails → `waits` = {2, 4, 8, 4}; 5 saves; 0 releases; `"SaveFailed"` |
| | a retrying unload refuses loads and counts as unloading | wait = `coroutine.yield`; save fails once; unload runs in a coroutine and is suspended → `loadCompany` = `nil, "SessionBusy"`; `unloadingCount()` 1; `isAvailable` false; `handle(order)` → `CompanyUnavailable`; resume to the end → `unloadingCount()` 0; a new `loadCompany` returns the stored cash (**c**) |
| | abortOnFailure keeps a healthy session live | save fails once → `false, "UnloadAborted"`; `isAvailable` and `isDirty` true; `unloadingCount()` 0; 0 releases; `waits` empty; then `flushDirty()` true, `unloadCompany` true, 1 release |
| | abortOnFailure waits for a failed session and during shutdown | (i) `failures = 1`, `clock += SaveFailClosedSeconds`, `flushDirty()` false and `isFailed` true; `failures = 1`; `unloadCompany(id, {abortOnFailure = true})` → `true`, `waits` = {2}, 1 release. (ii) new service, `beginShutdown()`, `failures = 1`, same call → `true`, 1 release |
| | a second unload caller gets the result after the lock release | Amendment R5-A2. wait = record value, then `coroutine.yield()`; `release` logs `"release"`, calls `coroutine.yield()`, returns `true`; `failures = 1`. Coroutine A = `unloadCompany(id)`: resume → suspended in the wait (`waits` = {2}). Coroutine B = `unloadCompany(id)`: resume → suspended (`waits` = {2, 0.1}). Resume A → suspended in `release`; `hasSession` false; log = save, save, release. Resume B → still suspended (`coroutine.status(B) == "suspended"`). Resume A → dead, returned `true, nil`. Resume B → dead, returned `true, nil`. 1 release in total |
| SaveSlotService_Test | a final leave whose save keeps failing keeps the lock | play the starter save, place an order, note `_session.expiresAt`; `companyStore.failCount = 1000` → `leave(USER, true)` = `false, "SaveFailed"`; `failCount` = 976 (24 calls, no release call); record `_session.jobId` = "job-a" with the same `expiresAt`; record cash = `GameConfig.StartingCash`; `freeCount()` 2; one deactivation with plotReleased true (**b**) |
| | a switch whose final save fails keeps the player on the old save | play A, order, create B, `failCount = 3` → `play(USER, B)` = `false, "SwitchSaveFailed"`; active is still A; `isAvailable(A)` and `isDirty(A)` true; record A cash = StartingCash; B has no record; no deactivations; A still on Plot_01; then `flushDirty()` stores the live cash; `play(B)` ok on Plot_01; A has no `_session` |
| | a switch away from a failed save waits for its final save | play A, order; `failCount = 1000`, `now += SaveFailClosedSeconds`, `flushDirty(true)` fails → `isFailed(A)`; `failCount = 3` → `play(USER, B)` ok; record A cash = live cash after the order; A has no `_session` |
| | pendingCount counts a retrying unload | `companyWait` = `coroutine.yield`; `failCount = 3`; `companies:unloadCompany(A)` in a coroutine, suspended → `pendingCount()` 1, `unloadingCount()` 1; resume to the end → result true, `pendingCount()` 0 (**d**) |
| CoopSave_Test | a member's play waits for the last leaver's retrying final save | `coopSave`, FRIEND joins (no play), the owner places `order`; `failKeys[saveKey] = true`; `companyWait` = `coroutine.yield`; `leave(OWNER, true)` in a coroutine, suspended → `play(FRIEND)` = `false, "SessionBusy"`; `loads` unchanged; record cash = StartingCash with `_session.jobId` "job-a"; `getPlot` = `save.plotId`; `pendingCount()` = 2 (the final leave plus its unloading session, Amendment R5-A1); clear `failKeys`, resume to the end → leave true; record cash = StartingCash − wholesale DouglasFir Medium; no `_session`; `play(FRIEND)` ok and `snapshotForTest` cash equals the record (**c**) |
| CrossServer_Test | a retrying final save renews the map entry | `coopSave`; `companyWait` advances `env.now`; `now += 60`; `failKeys[saveKey] = true` → `leave(OWNER, true)` = `false, "SaveFailed"`; entry still held by job-a for OWNER with `renewedAt` = 1122 at `now` = 1138 |
| | (existing) a failed final save keeps the entry | add `expect.equal(reason, "SaveFailed")` |
| GameConfig_Test | unload retries fit the fail-closed window and the shutdown budget | every delay is a positive integer; sum = 78 ≤ `SaveFailClosedSeconds`; `ShutdownSeconds` = 18; `ShutdownSeconds + 5 <= 25` (main's `SHUTDOWN_WAIT_SECONDS`) |

The existing tests stay green unchanged, except the one assert changed by Amendment R5-A1. Expected total: 271 + 15 = **286**.

## Amendments (these win over the text above)
- **R5-A1 (pendingCount double count).** The formula stays `_finalLeaves + #_busy + companies:unloadingCount()`. pendingCount is only a "wait for zero" gauge for BindToClose, so counting a final leave and its own unloading session twice is harmless, and the formula stays free of special cases. Change exactly one existing assert: in `SaveSlotService_Test` > `counts a final leave until its save is written`, `expect.equal(seen.pendingCount, 1)` becomes `expect.equal(seen.pendingCount, 2)`, with the comment `-- CM2-R5: the final leave plus its unloading session.` on the line above. Nothing else in that test changes. The new CoopSave test asserts exactly 2 (see the table).
- **R5-A2 (second unload caller).** Fixed with a `session.unloadFinished` flag (step 2.2 and 2.5 above): a second caller waits until the first caller has stored its results, so it can no longer wake during the `release` yield and read `unloadOk == nil`. It returns the first caller's result (`true, nil` on a successful save and release), or `false, "UnloadAborted"` when the unload was called off. The finish order (remove from `_sessions`, `release`, store results) does not change. New test: `a second unload caller gets the result after the lock release` (table above).

## Playtest (Studio, via playtester)
A Studio step would add no evidence beyond the headless tests, because Studio cannot make the real DataStore fail and Studio stop is not a live shutdown.
1. Run a Play Server with BUILD `cm2-r5` and run `runPlaytest {mode="full"}` → all PASS (step 01 ≥ 286). Leave and switch on the happy path are unchanged, including the same plot after a switch.
2. Check the server output after the run: no `final save of` warnings.
3. The DataStore outage on leave, switch and shutdown stays BLOCKED in Studio; the headless tests cover it. Add no friends-test item, since the failure cannot be triggered on demand.

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (286 run, 0 failed), `rojo build`.
- Backlog (a)–(d) are met by the tests marked **a**–**d**. `runPlaytest {mode="full"}` is all PASS on the happy path.
- Skill checks:
  - roblox-data: the lock is never released over unsaved changes, and BindToClose waits for retrying unloads within its budget (≤ 18 s plus one attempt, inside 25 s).
  - roblox-server-data: every locator write keeps its TTL, the renewal runs in the unloading thread, and there is no retry storm (at most 7 claims per unload).
  - roblox-localization: both new keys exist in `en` and `de`.

## Out of scope
- Keeping an abandoned session in memory for a later retry, and resurrecting an in-memory state on re-Play. After giving up, the changes since the last good save are lost.
- Moving the switch's retry to a background thread.
- A client UI change (the picker already shows `saveErrorKey(code)`).
- BindToClose unloading sessions that no player is active on.
- A faster lock takeover after a crash.

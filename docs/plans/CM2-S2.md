# CM2-S2 — Co-op saves and invite codes (covers CM2-37, CM2-38 re-scoped, CM2-G10 part 2)

Written by: `planner` (Opus 5.5, high). Implemented by: the agent for the tier below. Playtested by: `playtester` (Sonnet 5.5, medium). Reviewed and committed by: `reviewer` (Opus 5.5, medium). Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
A player creates a Solo, Duo, Trio or Quad save (1/2/3/4 seats). Duo and larger saves get a unique 5-digit invite code; friends join with it while a seat is free and then share one plot and one cash balance. The owner alone renames, deletes, resizes, removes members and makes a new code. Members play the save while the owner is offline; one server holds a save at a time (existing lock).

## Source of truth
- Backlog launch order line 4 (CM2-S2), line 5 (CM2-S3, shapes the data only), original CM2-37 (join and leave), CM2-38 (roles → owner vs member, DECISION_LOG 2026-11-21 launch order), CM2-G10 part 2.
- PRODUCT_SPEC 2026-11-21 "Saves and multiplayer" (OWNER DECIDED: sizes, creator owns, members do everything in play, owner-only rename/delete/remove/renew code, members play while the owner is offline, fixed 5-digit numeric code).
- `docs/plans/CM2-S1.md` (save ID, key budget and prefix rule, lock-free profile, `_play`/`_leaveActive`, shutdown `pendingCount`). DECISION_LOG 2026-11-22 CM2-S1 and CM2-G20 (shadow user `999999999001`).
- TECHNICAL_ARCHITECTURE §5 and §7; skill rule roblox-security "Text filtering as a workflow" (stored text shown to other players).

## Implementer tier
Tier: L. Reason: company schema 12, writes to other players' profiles and to unlocked records, invite-code uniqueness and brute-force limits, permissions, and concurrency between members sharing one session.

## Skills to load
roblox-collaboration-mode, roblox-data, roblox-server-data, roblox-networking, roblox-security, roblox-architecture, roblox-gui, roblox-input, roblox-localization, roblox-luau-core, roblox-luau-patterns, roblox-luau-types, roblox-tooling.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/GameConfig.lua` | Change | `Saves` additions |
| `src/shared/BusinessState.lua` | Change | Schema 12, member and code helpers |
| `src/shared/SaveProfile.lua` | Change | `ownerUserIdOf`, `nameTaken` ignores Member entries |
| `src/shared/Protocol.lua` | Change | New `Save.*` actions, payload checks, `recentCount` |
| `src/shared/Localization.lua` | Change | Error and UI keys (en + faithful de) |
| `src/server/Services/InviteCodeService.lua` | New | `invite:<code>` map: claim (with `exclude`, Amendment A2), release, lookup |
| `src/server/Services/PersistenceService.lua` | Change | `load` options, `updateUnlocked`, `markDeleted` info |
| `src/server/Services/CompanyStateService.lua` | Change | Member permissions, team reads, `changeTeam` |
| `src/server/Services/SaveSlotService.lua` | Change | Co-op actions, attach/evict, shared leave |
| `src/server/main.server.lua` | Change | Wiring, attributes, user names |
| `src/server/Services/StudioTestService.lua` | Change | Second synthetic user |
| `src/client/SavePicker.client.lua` | Change | Size choice, join by code, member rows |
| `src/client/TeamPanel.client.lua` | New | Team button and panel |
| `src/client/UiController.client.lua` | Change | Member HUD status, `CashLabel` name |
| `tests/headless/run.luau` | Change | Register `InviteCodeService` |
| `tests/studio/Cases/*_Test.lua` | New/Change | See Tests |
| `tests/studio/Playtest/RunPlaytest.lua` | Change | Steps 29–32, threshold 245, `BUILD = "cm2-s2-r2"` (Amendment C) |
| `docs/TECHNICAL_ARCHITECTURE.md`, `docs/DECISION_LOG.md`, `docs/TEST_PLAN.md`, `docs/CLAUDE_BACKLOG.md` | Change | Step 13 |

## Data and config
**`GameConfig.Saves` additions**
```
Seats = { Solo = 1, Duo = 2, Trio = 3, Quad = 4 },        -- OWNER DECIDED (PRODUCT_SPEC)
InviteCodeMin = 10000, InviteCodeMax = 99999,             -- 5 digits OWNER DECIDED; no leading zero PROVISIONAL
InviteClaimAttempts = 8, SharedEntryName = "Shared lot",  -- PROVISIONAL
JoinFailureLimit = { limit = 10, window = 3600 },         -- wrong codes per player
JoinServerFailureLimit = { limit = 60, window = 60 },     -- wrong codes per server
RateLimits += { ["Save.Join"]={limit=5,window=60}, ["Save.LeaveTeam"]={limit=5,window=60},
  ["Save.Team"]={limit=20,window=10}, ["Save.RemoveMember"]={limit=10,window=60},
  ["Save.RegenerateCode"]={limit=3,window=60}, ["Save.SetSize"]={limit=5,window=60} }
```
**Company schema 12** (`BusinessState.SCHEMA_VERSION = 12`)
- `members`: map `SaveProfile.userIdText(userId)` → `"Owner" | "Member"`. Exactly one `"Owner"`, at `userIdText(ownerUserId)`. Keys match `^%d+$`, 1–19 chars. Count ≤ `Seats[saveSize]`.
- `inviteCode`: nil or a string matching `^[1-9]%d%d%d%d$`; always nil for Solo. A Duo+ record may be nil until a code is assigned.
- `new` and the v1 path build `members = {[userIdText(owner)] = "Owner"}`, `inviteCode = nil`. `tostring(userId)` disappears from BusinessState and CompanyStateService (19-digit IDs; existing keys below 10^15 are unchanged text).
- Migration 11 → 12 (the 10 → 11 block falls into it): `members = {[userIdText(ownerUserId)] = "Owner"}` (other roles were never writable in production, so they are dropped), `inviteCode = nil`. Then the existing current-version steps.

**Invite map** (`InviteCodeService.STORE_NAME = "ChristmasMarket2_Invites_v1"`, key `invite:<code>`, 12 chars): `{saveId, issuedAt}` while held, tombstone `{freedAt}` after release. The map is only an index. The record's `inviteCode` is the authority: a join is valid only when the record's code equals the typed code. A stale map entry is harmless.

**Profile entries for co-op** (profile schema unchanged, v1): an owner entry keeps `role="Owner"`, `size` = the save's size. A member entry is `{saveId, name=SharedEntryName, role="Member", size, createdAt, lastPlayedAt}`. Member entries count toward `MaxSavesPerPlayer`. The member's client never receives the save name (see Step 6, List).

**Name rule (filtering):** the save name was filtered for broadcast when the owner submitted it. Stored text shown to other players needs filtering at retrieval, and that needs the author online. So in S2 a member never sees the save name. The member sees "Shared lot from <owner username>" (Roblox usernames need no text filter). Display-time filtering is deferred to CM2-G15.

**Player attributes (server-set) added:** `ActiveSaveRole` (`Owner`/`Member`), `ActiveSaveSize`, `ActiveSaveOwnerName` (string or nil, members only), `TeamRevision` (int, +1 on every team change). `ActiveSaveName` is set only for owners.

**Key budget** (TECHNICAL_ARCHITECTURE §5): the row "S2 invite code" becomes `invite:<code>` | 12 | store `ChristmasMarket2_Invites_v1`. No other new key. Member IDs live inside the owner's record value: RTBF erasure of a member's ID needs a manual edit. Record this limitation in the DECISION_LOG.

## Steps
1. **GameConfig** as above.
2. **BusinessState.lua** (requires `SaveProfile` for `userIdText`). Pure helpers, none yield:
   - `isInviteCode(v): boolean`; `seatsFor(size): number?`; `memberCount(state): number`.
   - `addMember(state, userId, code: string?) → (true, {outcome = "Joined"|"AlreadyMember", size}) | (false, code)`. Already a member → `AlreadyMember` (no code check). `code ~= nil` and (Solo or `state.inviteCode ~= code`) → `InviteCodeInvalid`. Full → `SaveFull`. Otherwise add `"Member"`. `code == nil` is for trusted server callers only (S3 teammate finder); `Save.Join` always passes the code.
   - `removeMember(state, userId) → (true) | (false, "OwnerCannotLeave"|"NotAMember")`.
   - `setInviteCode(state, code: string?, expected: string?) → (true) | (false, "CodeChanged"|"SoloHasNoCode")`. A non-nil code on Solo → `SoloHasNoCode`. The current code differs from `expected` → `CodeChanged`.
   - `setSaveSize(state, size) → (true, previousCode: string?) | (false, "InvalidSize"|"SizeTooSmall")`. Setting Solo clears `inviteCode` and returns the old code for release. The same size → `(true, nil)`.
   - `validate`: the schema 12 rules above.
3. **SaveProfile.lua:** `ownerUserIdOf(saveId): number?` = `tonumber(digits)` when `isSaveId`, else nil. `nameTaken` compares only entries with `role == "Owner"`.
4. **Protocol.lua:** add `Join="Save.Join"`, `LeaveTeam="Save.LeaveTeam"`, `Team="Save.Team"`, `RemoveMember="Save.RemoveMember"`, `RegenerateCode="Save.RegenerateCode"`, `SetSize="Save.SetSize"`. Payload keys: Create `{name?, size?}`, Join `{code}`, LeaveTeam `{saveId}`, Team `{}`, RemoveMember `{userId}`, RegenerateCode `{}`, SetSize `{size}`. Errors: `size` not a key of `Seats` → `InvalidSize` (Create: absent = Solo). `code` not a string matching `^[1-9]%d%d%d%d$` → `InvalidInviteCode`. `userId` not an integer in 1..2^53 → `InvalidUserId`. Add `Protocol.recentCount(limiter, userId, action, timestamp): number` (counts entries newer than the window, records nothing).
5. **InviteCodeService.lua:** `new(store, clock, wait, randomCode)`. All I/O is `UpdateAsync` (reads return nil from the transform, so nothing is written). 3 attempts, waits 1 s and 2 s. Transforms reset their results first.
   - `claim(saveId) → (code?, err?)`: up to `InviteClaimAttempts` codes `string.format("%d", randomCode())`. Nil, or a tombstone without `saveId` → write `{saveId, issuedAt}`. The same `saveId` → no write, success. Another `saveId` → taken, try the next code. All taken, or a store error after retries → `nil, "InviteCodeUnavailable"`.
   - `release(code, saveId) → boolean`: writes `{freedAt = now}` only when the stored `saveId == saveId`.
   - `lookup(code) → (saveId?, err?)`: held → `saveId`. Nil or a tombstone → `"InviteCodeInvalid"`. Store error → `"LoadFailed"`.
6. **PersistenceService.lua**
   - `load(companyId, ownerUserId, saveName?, options?)`, `options = {saveSize?, requireExisting?}`. A nil record with `requireExisting` → `nil, "SaveNotFound"`, no write. A fresh record gets `saveSize = options.saveSize or "Solo"`. `saveName == nil` keeps the stored name (members pass nil).
   - `updateUnlocked(companyId, ownerUserId, mutate) → (ok, err?, result?)`: one `UpdateAsync` with `_retry`. The transform:
     - nil → `SaveNotFound`; not a table → `LoadFailed`; `_deletedAt` → `SaveDeleted`; `_migratedTo` → `SaveNotFound`;
     - any `_session` with `expiresAt > now`, this job included → `SaveInUse`;
     - otherwise `deepCopy`, keep `_migratedFrom`, drop an expired `_session` (a stalled holder then fails closed on its next save), `BusinessState.migrate` (failure → `LoadFailed`), `mutate(state)` → `(true, result)` or `(false, code)`. A refusal writes nothing.
     - Set `updatedAt`. Write only when `validate` passes, else `LoadFailed`.
     - A store error after retries → `LoadFailed`. The service's `_sessions` map is never touched.
   - `markDeleted(companyId) → (ok, err?, info?)`: on success `info = {memberUserIds = {non-owner IDs as numbers, ascending}, inviteCode}`, read inside the transform. A nil record → `info = {memberUserIds = {}, inviteCode = nil}`.
7. **CompanyStateService.lua**
   - `loadCompany(companyId, ownerUserId, saveName?, options?)` passes `options` through.
   - `canPerformAction`: role = `state.members[SaveProfile.userIdText(userId)]`. `"Owner"` or `"Member"` may perform every action of today's `ACTION_ROLES` and `MEMBER_QUERIES` (one set `MEMBER_ACTIONS`). Anyone else → `Forbidden`. Delete the Manager/Worker/Visitor tables.
   - `memberRole(companyId, userId): string?` and `teamInfo(companyId)` → `{ownerUserId, saveName, saveSize, inviteCode, members = copy}`. Both return nil without a healthy session. `hasSession(companyId)` = a session or a load in progress. `isFailed(companyId)` = a session that is not healthy and not unloading.
   - `changeTeam(companyId, mutate, saveNow: boolean?) → (ok, err?, result?, saved: boolean)`: runs `mutate(state)` in `_withSession`. On success, `dirty = true`, no revision bump. With `saveNow`, `_save` runs once; a failed save keeps it dirty and still returns `ok = true, saved = false`. An unavailable session → `false, "CompanyUnavailable"`.
8. **SaveSlotService.lua** (deps gain `invites`, `userName(userId) → string?`; `setTeamHandlers(onRemoved(userId, saveId), onTeamChanged(companyId, size))`)
   - **Helpers.**
     - `_changeRecord(saveId, mutate)`:
       - `companies:isAvailable(id)` → `changeTeam(id, mutate, true)`; `CompanyUnavailable` becomes `SaveInUse`.
       - `companies:hasSession(id)` → `SaveInUse`.
       - otherwise `persistence:updateUnlocked(id, SaveProfile.ownerUserIdOf(saveId), mutate)` (saved = true).
     - `_dropMemberEntry(userId, saveId)`: a profile transform that removes only an entry with that `saveId` and `role == "Member"` and clears a matching `lastSaveId`. This is how a server writes another player's profile: lock-free, validated, it never touches anything else, and failures only warn. A stale entry heals on Play (`NotAMember`).
     - `_teamChanged(companyId)` calls `onTeamChanged` when anyone on this server plays the save.
   - **Create:** `size` (default Solo) goes into the entry; the first Play passes it as `options.saveSize`. **Rename/Delete** on a Member entry → `OwnerOnly`.
   - **Delete** additionally: if a player on this server plays the save and the owner is not on it → `SaveInUse`. After `markDeleted`: `invites:release(info.inviteCode, saveId)` and `_dropMemberEntry` for each `info.memberUserIds`, all best effort.
   - **List:** rows gain `seats = Seats[size]`. For Member rows `name = nil` and `ownerName = userName(ownerUserIdOf(saveId))`.
   - **_play** (replaces steps 3–7 of S1):
     - a. Another save is active → `_leaveActive`.
     - b. The same save, failed or `reload`: `reload` while another player on this server plays it → `SaveInUse`; otherwise `_leaveActive`.
     - c. `companies:isFailed(id)` → `_evict(id)`: deregister every player on it, `unloadCompany`, `plots:release`, then `onDeactivated` for each (the last one gets `plotReleased = true`).
     - d. **Attach:** `isAvailable(id)` and a player is registered on it → `memberRole` nil → `_dropMemberEntry`, `NotAMember`. Otherwise register on `plots:getPlot(id)`, touch, `onActivated(..., state = nil, view)`.
     - e. Else claim the plot and run the load loop: `loadCompany(id, ownerUserIdOf(saveId), entry.role == "Owner" and entry.name or nil, {saveSize = entry.size, requireExisting = entry.role == "Member"})`. Before every attempt, re-check d. On failure, release the plot only when nobody is registered on it and `not hasSession(id)`.
     - f. A loaded save where `memberRole` is nil → unload, release, `_dropMemberEntry`, `NotAMember`.
     - g. Leaving or closing as in S1.
     - h. Register. Touch: `lastPlayedAt`, `lastSaveId`, entry `size = teamInfo.saveSize`. If the owner plays a Duo+ save without a code → `_ensureInviteCode`: `claim`, then `changeTeam(setInviteCode(code, nil), true)`; on failure release the claim and warn.
     - i. `onActivated(userId, id, plotId, state?, view)`, `view = {saveName = owner ? name : nil, role, size, ownerName = member ? userName(owner) : nil}`.
   - **_leaveActive:** `last = self._members[id] == nil` is computed immediately after `_deregister`, before any yield. Then `releaseCarried`. Only when `last`: `unloadCompany` and `plots:release`. Then `onDeactivated(userId, id, plotId, last and released)`.
   - **Join `{code}`:**
     - `JoinLocked` when `recentCount` of the player's failures ≥ 10 per 3600 s or the server's (user 0) ≥ 60 per 60 s. This is checked before any store call. The limiters are `_joinFailures` and `_serverJoinFailures` (action key `"fail"`). They are not cleared on leave, so a rejoin does not reset them.
     - At the save cap → `SaveLimit`.
     - `lookup(code)`; then `_changeRecord(saveId, addMember(state, userId, code))`.
     - `InviteCodeInvalid`, `SaveDeleted` and `SaveNotFound` all return `InviteCodeInvalid` and record one failure in both limiters. `SaveFull`, `SaveInUse` and `LoadFailed` pass through and are not counted.
     - `Joined` and the profile has no entry → add the member entry. If the profile write fails (incl. `SaveLimit`), `_changeRecord(removeMember)` runs as a best-effort rollback and its error is returned.
     - Returns `{saveId, size, alreadyMember}`. The owner's own code → `alreadyMember = true`, no write.
   - **LeaveTeam `{saveId}`:**
     - No entry → `SaveNotFound`; Owner entry → `OwnerCannotLeave`.
     - Active on it → `_leaveActive` first. Then `_changeRecord(removeMember)`: `NotAMember`, `SaveDeleted` and `SaveNotFound` count as done; other errors return and keep the entry.
     - Then remove the entry. Returns `{saveId}`.
   - **Team, RemoveMember, RegenerateCode, SetSize** act only on the requester's active save (none → `SaveNotActive`). The last three need `memberRole == "Owner"`, else `OwnerOnly`.
     - Team → `{saveId, size, seats, inviteCode, role, members = {{userId, name?, role, online}}}`, owner first, then by user ID. `online` = registered here. Every member sees the code.
     - RemoveMember: own ID → `CannotRemoveOwner`; `changeTeam(removeMember)`; `_dropMemberEntry(target)`.
       - A target playing it here is kicked: if not `_busy[target]`, run `_leaveActive(target)` and `onRemoved(target, saveId)` now. Else store `_pendingKicks[target] = id`, which `handle`, `play` and `openProfile` run right after clearing `_busy`.
       - Their gameplay requests are `Forbidden` at once, because the live member map changed. A final `leave` clears `_pendingKicks[userId]`.
     - RegenerateCode: Solo → `SoloHasNoCode`. `claim` → `changeTeam(setInviteCode(new, old), true)`. Failure → release the new code. Success and `saved` → release the old code; unsaved → keep the old map entry (the record check invalidates it). Returns `{inviteCode}`.
     - SetSize `{size}`: `changeTeam(setSaveSize)`. A returned old code → release after the save. Duo+ without a code → `_ensureInviteCode`. Update the owner's entry size (best effort). Returns `{size, seats}`.
     - `_teamChanged`: see Amendment A1 (Team never calls it).
9. **main.server.lua:**
   - `invites = InviteCodeService.new(DataStoreService:GetDataStore(InviteCodeService.STORE_NAME), os.time, task.wait, function() return rng:NextInteger(10000, 99999) end)` with `local rng = Random.new()`.
   - `userName`: a cache; first a player in the server (`player.Name`), else `pcall(Players.GetNameFromUserIdAsync)`; a failure caches `false` and returns nil.
   - onActivated:
     - `syncPlotWorld` only when `state` is given.
     - Set `ActiveSaveRole` and `ActiveSaveSize`; `ActiveSaveName = view.saveName`, `ActiveSaveOwnerName = view.ownerName`.
     - onDeactivated clears all four.
   - `setTeamHandlers`:
     - onRemoved: `CompanyError = "RemovedFromSave"`.
     - onTeamChanged: for every `playersOn(companyId)`, set `ActiveSaveSize` and `TeamRevision += 1`.
10. **Localization.lua** (`SaveErrorKeys` additions; en text below, plus a faithful de):

    | Code(s) | Key | English |
    |---|---|---|
    | OwnerOnly | saveErrorOwnerOnly | Only the owner of this save can do that. |
    | NotAMember | saveErrorNotMember | You are no longer a member of this save. |
    | RemovedFromSave | saveErrorRemoved | The owner removed you from this save. |
    | InviteCodeInvalid, InvalidInviteCode | saveErrorInviteInvalid | That invite code does not work. Check the code and try again. |
    | SaveFull | saveErrorSaveFull | This save has no free seat. |
    | JoinLocked | saveErrorJoinLocked | Too many wrong codes. Please try again later. |
    | OwnerCannotLeave | saveErrorOwnerCannotLeave | You own this save. Delete it instead of leaving. |
    | CannotRemoveOwner | saveErrorCannotRemoveOwner | The owner cannot be removed. |
    | SaveNotActive | saveErrorNotActive | Play this save to manage its team. |
    | SizeTooSmall | saveErrorSizeTooSmall | This save has more members than that size allows. Remove members first. |
    | SoloHasNoCode | saveErrorSoloNoCode | Solo saves have no invite code. Choose a bigger size to invite friends. |
    | InviteCodeUnavailable | saveErrorCodeUnavailable | A new invite code could not be made right now. Please try again. |
    | SaveInUse (changed text) | saveErrorInUse | This save is being played right now. Please try again in a minute. |

    `InvalidSize` and `InvalidUserId` use the fallback.
    UI keys: `saveSizeSolo` "Solo", `saveSizeDuo` "Duo", `saveSizeTrio` "Trio", `saveSizeQuad` "Quad", `saveRowSolo` "Solo save", `saveRowCoopOwner` "Co-op save for %d players. You own it.", `saveRowCoopMember` "Co-op save for %d players. Shared with you.", `sharedSaveName` "Shared lot from %s", `sharedSaveNameUnknown` "Shared lot", `saveLeave` "Leave", `joinCodePlaceholder` "Invite code (5 digits)", `joinButton` "Join", `teamButton` "Team", `teamTitle` "Team", `teamSeats` "%d of %d seats are taken.", `teamCode` "Invite code: %s", `teamCodeHint` "Friends on this server can join with this code.", `teamNoCode` "Solo saves have no invite code.", `teamCodePending` "The invite code is being made. Please check again soon.", `teamNewCode` "New code", `teamRemove` "Remove", `teamRemoveConfirm` "Tap again to remove", `teamLeave` "Leave save", `teamLeaveConfirm` "Tap again to leave", `teamOwnerTag` "Owner", `teamMemberTag` "Member", `teamOnline` "Online", `teamOffline` "Offline", `teamUnknownPlayer` "A player", `teamClose` "Close", `hudSharedSaveStatus` "Shared lot from %s · Plot %s", `hudSharedSaveStatusUnknown` "Shared lot · Plot %s".
11. **SavePicker.client.lua** (touch targets ≥ 44 px):
    - `ROW_HEIGHT = 120`. New label `SaveKind` (22 px) under the name: `saveRowSolo`, or `saveRowCoopOwner`/`saveRowCoopMember` with `seats`.
    - Member rows: the name shows `sharedSaveName` with `ownerName` (nil → `sharedSaveNameUnknown`). Rename is hidden. Delete becomes `Leave` (`saveLeave`): the first tap shows `teamLeaveConfirm`, the second sends `Save.LeaveTeam`.
    - The footer becomes four rows (`FOOTER_HEIGHT = BUTTON_HEIGHT*4 + 24`):
      1. `Size_Solo`/`Size_Duo`/`Size_Trio`/`Size_Quad` toggles (width 0.25, −6 px; selected GOLD, else SAND; default Solo, reset to Solo after a create);
      2. `NewSaveName` + `CreateSave` (sends `size`);
      3. TextBox `JoinCode` (placeholder `joinCodePlaceholder`) + `JoinSave` (`joinButton`): strips `%s`, sends `Save.Join`, and on success sends `Save.Play` for the returned `saveId`;
      4. `PickerStatus` + `BackToGame`.
12. **TeamPanel.client.lua** (new) and **UiController.client.lua**:
    - ScreenGui `TeamUI` (`DisplayOrder = 15`, `ResetOnSpawn = false`). `TeamButton` (`teamButton`, 96×44, anchor (1,0), position (1,−120,0,12)) is visible while `CompanyReady == true`.
    - Frame `TeamPanel` (anchor 0.5,0.5; scale 0.92×0.8; `UISizeConstraint` max 420×560), hidden at start:
      - `Title`, `SeatsLine` (`teamSeats`), `CodeLine` (`teamCode`, or `teamNoCode` for Solo, or `teamCodePending`), `CodeHint` (`teamCodeHint`, hidden for Solo);
      - ScrollingFrame `MemberList` with rows `Member_<n>` (56 px): name (`AutoLocalize = false`, nil → `teamUnknownPlayer`), role tag, `teamOnline`/`teamOffline`, and for the owner on other rows `Remove` (two taps, `teamRemoveConfirm`);
      - owner footer `Size_Solo..Size_Quad` (current one highlighted, sends `Save.SetSize`) and `NewCode`; member footer `LeaveTeam` (two taps); `Close`; `TeamStatus` (errors through `Localization.saveErrorKey`).
    - The panel fetches `Save.Team` on open, on a `TeamRevision` change while open, and after each action. One request in flight. It closes when `CompanyReady` turns false.
    - UiController: the HUD cash label gets `Name = "CashLabel"`. `updateReady` uses `hudSharedSaveStatus` (or `…Unknown`) when `ActiveSaveRole == "Member"` and also listens to `ActiveSaveRole` and `ActiveSaveOwnerName`.
13. **StudioTestService / docs:**
    - `StudioTestService.SHADOW_2_USER_ID = 999999999002`. `saveAction` and `act` accept it like the shadow. New command `shadow2Leave` = `leave(SHADOW_2, true)` plus `forgetUser`.
    - TECHNICAL_ARCHITECTURE:
      - §4: schema 12;
      - §5: invite row, `updateUnlocked`, attach/evict, last-leaver unload;
      - §7 rewritten: Owner and Member, owner-only actions, the filter rule.
    - DECISION_LOG entry "2026-11-22 - Co-op saves and invite codes, CM2-S2 (engineering)" with:
      - sizes and resizing;
      - the code range and why the record is the authority;
      - the brute-force limits;
      - management only on the active save;
      - joins while another server plays the save return `SaveInUse` until S3 adds "Join";
      - the member name placeholder;
      - the RTBF limitation;
      - the rollout note (old servers fail closed on schema 12; shut them down).
    - TEST_PLAN §3b: 33 steps, at least 245 tests, the second synthetic user.
    - CLAUDE_BACKLOG order 15 (CM2-47a): already written by the planner on 2026-11-22. The implementer does not touch the backlog.

## Amendment 2026-11-22 (answers the tier-L implementer; wins over step text)
Steps 1–7 are implemented (headless 223/223). A2 changes step 5 code; everything else is step 8 onward.

**A1. Team notifications (Q1, option a).** `_teamChanged(companyId)` runs only after a successful team change: RemoveMember, RegenerateCode, SetSize (also when only the size changed), Join with outcome `Joined`, LeaveTeam when `removeMember` succeeded, and a successful `_ensureInviteCode` (the panel leaves `teamCodePending`). `Save.Team` and every refused or failed action never call it. Play and leave do not call it (`online` refreshes on the next fetch). TeamPanel: one request in flight. A `TeamRevision` change during a request sets `refetchPending`, which triggers exactly one fetch after that request returns. The fetch after an own action goes through the same rule.

**A2. Redrawn codes (Q2).**
- `InviteCodeService:claim(saveId, exclude: string?)`: a drawn code equal to `exclude` counts as taken. It uses one of the `InviteClaimAttempts` and makes no store call.
- RegenerateCode passes the old code; `_ensureInviteCode` passes nil.
- Release guard for RegenerateCode, SetSize and `_ensureInviteCode`: after the change, read `live = teamInfo(id)`. Release a code only when `live ~= nil` and the code ≠ `live.inviteCode`. A nil `live` skips every release (a stale map entry is harmless).

**A3. Plot hand-over (Q3), airtight.** New fields in SaveSlotService: `_pendingLoads[companyId]` (a count) and `_unloading[companyId] = true`.
- New helper `_unloadShared(id) → (ok, err?, plotReleased)`:
  1. set `_unloading[id] = true`;
  2. `unloadCompany(id)`;
  3. after that yield, `plotReleased = self._members[id] == nil and (self._pendingLoads[id] or 0) == 0 and self._plots:release(id)`;
  4. clear `_unloading[id]`.
- Every unload in SaveSlotService goes through it: the last leaver in `_leaveActive`, `_evict`, and the unloads in steps f and g. `_leaveActive` sets `_unloading[id]` together with computing `last`, before `releaseCarried` and before any yield. `onDeactivated` receives the helper's `plotReleased`. In `_evict` only the last `onDeactivated` gets it; the others get false.
- Attach (step d) also requires `not self._unloading[id]`.
- Step e:
  - `_pendingLoads[id] += 1` before the first claim. Every exit from steps e–h decrements it: after `_register` on success, or before the failure release. Steps f and g decrement before they call `_unloadShared`.
  - Each load attempt runs, in order:
    1. re-check d;
    2. if `_unloading[id]`, the attempt counts as `SessionBusy`: `self._wait(attempt)` and the next attempt, with no `loadCompany` call;
    3. `plotId = self._plots:claim(id, preferred)` (idempotent while held). Nil → `NoFreePlot` (no teleport after the first attempt);
    4. `loadCompany`.
  - After the last attempt, `SessionBusy` stays the error.
- Failure release in step e: `plots:release(id)` only when `_members[id] == nil`, the count is 0, `not _unloading[id]` and `not companies:hasSession(id)`.
- Effect: a waiting loader can never load while the old session's `persistence.release` is still in flight. That would clear the new session's same-job `_session`. Note it in the DECISION_LOG entry. The failed-final-save case stays with CM2-R5.

**A4. SetSize release (Q4).** The code returned by `setSaveSize` is released only when `changeTeam(..., true)` returned `saved = true`, under the A2 guard. Unsaved → keep the map entry. The code stays unusable for other saves until this save is deleted; accepted as minor.

**A5. RemoveMember (Q5).** `changeTeam(id, removeMember(target), true)`. `saved = false` still returns ok, because the session stays dirty. Response `data = {userId = target}`.

**A6. Unhealthy active session (Q6).** Order for Team, RemoveMember, RegenerateCode and SetSize:
1. no active save → `SaveNotActive`;
2. `not companies:isAvailable(id)` → `CompanyUnavailable` (existing key `saveErrorUnavailable`);
3. owner-only action and `memberRole ~= "Owner"` → `OwnerOnly`.

**A7. Attach touch (Q7).** Yes. The touch in step d is the full step h touch: `lastPlayedAt`, `lastSaveId`, entry `size`, and `_ensureInviteCode` when the owner attaches to a Duo+ save without a code.

**A8. Join lockout (Q8).** `_handle` checks `JoinLocked` for `Save.Join` before `_openProfile`, so a locked request makes no store call at all. Then it opens the profile, checks `SaveLimit` and runs `lookup`.

**A9. Backlog (Q9).** Done by the planner (order 15 sub-bullet).

**Confirmed choices from steps 1–7 (no change):**
- a non-integer `ownerUserId` gets an empty member map in migration, so `validate` returns `InvalidState` (fail closed);
- `lookup` treats a stored `saveId` that fails `isSaveId` as `InviteCodeInvalid`;
- `release(nil, saveId)` → false, with no store call;
- `updateUnlocked` treats a `_session` without `expiresAt` as expired (same as `_lockedByOther`);
- `changeTeam` calls `_save` whenever `saveNow` is set and the mutation succeeded. `_withSession` has just checked health and nothing yields in between.

**Tests added (+5, total 245)**
| Test case file | Test name | Asserts |
|---|---|---|
| InviteCodeService_Test | never returns the excluded code | `randomCode` yields A then B, A held by this save; `claim(saveId, A)` → B; A's value unchanged; exactly 1 write |
| CoopSave_Test | only team changes notify the players on the save | owner and FRIEND active; 3× Team from each → 0 `onTeamChanged` calls; RegenerateCode → 1 (`companyId`, "Duo"); SetSize Solo → SizeTooSmall, still 1; RemoveMember FRIEND → 2 |
| | a member waiting on the last leaver's unload keeps the shared plot | SaveSlotService `wait` = `coroutine.yield`. Only the owner plays the Duo; FRIEND is a member. A `beforeUpdate` hook on the leaver's `release` update of the owner key (the second update during `leave(OWNER, true)`) starts `play(FRIEND)` in a coroutine and resumes it once. After `leave` returns, the test resumes it until done. Expect: leaver `plotReleased = false`; FRIEND ok on the same plot; `plots:getPlot(id)` is that plot; FRIEND caused 1 `persistence.load`; the record's `_session.jobId` is job-a; THIRD's own Solo Play gets a different plot |
| | team actions on a failed session return CompanyUnavailable | thief lock + flush; owner Team and RegenerateCode → CompanyUnavailable; FRIEND RemoveMember → CompanyUnavailable (not OwnerOnly); invite map unchanged |
| | an unsaved code change keeps the old map entry | the fake store throws on the owner record key (retries exhausted). On a Duo with only the owner: RegenerateCode → ok, live code new, old key still `{saveId}`. SetSize Solo → ok, the new key still `{saveId}` |

Added assertions in existing CoopSave tests (count unchanged):
- "a new code invalidates the old one": the first random code equals the current one, and the result is still new ≠ old.
- "a removed member loses access…": the response is `{userId = 43}`, and the stored record lacks 43 without a flush.
- "locks out repeated wrong codes": the 11th call also makes no profile-store call.

## Amendment B 2026-11-22 (after steps 1–13, headless 245/245; wins over step text)
**B1. HUD cash check (option a, in the manual part).** RunPlaytest cannot read a client ScreenGui. Step 30 checks only server-side cash and the duplicate request ID (as implemented). The HUD check is a playtester MCP check in Playtest item 4, on the Duo the real player owns with the shadow as member (text above). No code change; the step count stays 33.

**B2. Fix steps (code).**
- **F1. `SaveSlotService:_join` restores a lost member entry.** In the `_changeRecord` closure, reset and capture `joinedRole = state.members[SaveProfile.userIdText(userId)]` when `addMember` returns `AlreadyMember`. In the `ALREADY_MEMBER` branch: if `joinedRole == "Member"` and `SaveProfile.find(profile, saveId) == nil`, run the same profile transform as the `Joined` path (inserts `memberEntry(saveId, joinedSize, now)`, no write when an entry exists, `SaveLimit` at the cap). If that write fails, return its error. Do not roll back, because the seat was there before this request. No `_teamChanged`. Response stays `{saveId, size, alreadyMember = true}`. The owner (`joinedRole == "Owner"`) never gets an entry written. Reason: otherwise a member whose Join rollback failed holds a seat they cannot see or play.
- **F2. `UiController.updateReady`.** First line after reading the attributes: `status.AutoLocalize = not ready`. The two ready lines carry a save name or a username and must not be auto-translated. Error, choose and loading lines stay translatable. No other label changes: `SavePicker` row names, the `TeamPanel` names and `CodeLine` already set `AutoLocalize = false`.
- **F1 test (no new test, count stays 245).** Add to CoopSave_Test "joins by code and shares the plot on one server": delete FRIEND's entry directly in the fake profile store. FRIEND Join with the code → ok, `alreadyMember = true`, the entry is back with `role = "Member"`, `size = "Duo"`, and the owner record has no new write. Join again → no profile write. The owner Join with the own code → `alreadyMember = true`, and the owner profile is unchanged.

**B3. Confirmed as implemented (no change).**
| Detail | Decision |
|---|---|
| Join by an existing member or the owner | Internal refusal `"AlreadyMember"` from the mutate, so the record gets no write; the response is ok with `alreadyMember = true` (plus F1) |
| Profile entries | Added only on `Joined` (and by F1 when an existing member's entry was lost) |
| `onTeamChanged(companyId, teamInfo(id).saveSize)` | A nil size (unhealthy session) skips `ActiveSaveSize` and still bumps `TeamRevision`; the panel's fetch then shows `CompanyUnavailable` |
| Kicks (direct or pending) | Run only while the target is still active on that save (`_kick` checks `_active`). A target who already switched away gets no `RemovedFromSave` text; record and entry are already cleaned |
| Delete | `invites:release` only when `info.inviteCode ~= nil` |
| Activation view | Owner `saveName` from the profile entry (the S1 authority; Rename updates both). Size and role come from the record, with the entry as fallback |
| SetSize Solo → Duo | Two notifications (SetSize, then `_ensureInviteCode`), per A1. The panel's `refetchPending` folds them into at most one extra fetch |
| Code range in main.server | `rng:NextInteger(config.Saves.InviteCodeMin, config.Saves.InviteCodeMax)` replaces the literals in step 9 |

## Amendment C 2026-11-22 (playtest r1: full 32/33, step 32 InsufficientFunds; wins over step text)
**C1. Fix step F3 (`tests/studio/Playtest/RunPlaytest.lua` only).** Cause: a fresh Duo has `StartingCash` 84 = 3 × UNIT_PRICE 28. Step 30 makes three debits and leaves 0, so step 32's `orderTrees(S.userId, 1)` fails. Fix: step 30 makes two debits. The real player's order carries the request ID that the shadow then repeats. Nothing grants cash (G20). `DuplicateRequest` is checked per company state (`Protocol.beginRequest(state, …)`), so swapping the senders keeps the cross-member check.
| # | Where | Exact change |
|---|---|---|
| 1 | line 9 | `RunPlaytest.BUILD = "cm2-s2-r2"` |
| 2 | step 30, after `local start = rStart.cash` | `check(start >= 3 * UNIT_PRICE, string.format("Duo cash %d below three orders", start))` |
| 3 | step 30 | Delete the plain `orderTrees(R.userId, 1)` |
| 4 | step 30, the requestId order | Both `first = act(...)` calls (including the SupplierOutOfStock retry) use `R.userId`. Failure message `"owner order failed: "` |
| 5 | step 30 | Move the existing `rAfter`/`sAfter` check (both at `start - 2 * UNIT_PRICE`, same text) to directly after the `first` check |
| 6 | step 30 | `second = act(S.userId, "Supplier.PlaceOrder", payload, requestId)` → `DuplicateRequest`, same message |
| 7 | step 30, final checks | `cash == start - 2 * UNIT_PRICE` (message `"cash %d, expected one debit to %d"` with `start - 2 * UNIT_PRICE`); the shadow-equals check stays. The return string stays (detail becomes `shared cash 84 -> 28, duplicate refused`) |
| 8 | step 32, around `orderTrees(S.userId, 1)` | Before: `local memberCashBefore = snap(S.userId).cash` and `check(memberCashBefore >= UNIT_PRICE, string.format("Duo cash %d below one order", memberCashBefore))`. After: `check(snap(S.userId).cash == memberCashBefore - UNIT_PRICE, "member order with the owner away did not debit once")`. The local is named `memberCashBefore` so it does not shadow step 04's outer `before` table (line 693, selene `shadowing`); no `selene: allow` comment, step 04 unchanged |

Final step 30 order: shadow order (owner sees −28) → owner order with X (shadow sees −56) → shadow repeats X → DuplicateRequest, both at −56. Headless tests are unchanged and stay at **245**. Leftovers from r1 need no handling: CLEANUP calls `shadowLeave` before it deletes the Duo, and step 29 unlocks and deletes a leftover.
Re-verify: the checks in Acceptance, then `runPlaytest {mode="full"}` → 33/33 PASS with `BUILD cm2-s2-r2`. Soak, migration 11→12 and B1 HUD stay PASS from r1, because their code paths are unchanged.

**C2. Phone Device Simulator check → CM2-40.** It is not a CM2-S2 criterion. CM2-40 rebuilds the HUD shell and already takes the picker phone check (CM2-S1 status), and its phone, tablet and PC screenshots cover the footer rows and the team panel. The next backlog update adds "save footer and Team panel" to CM2-40's Accept line. CM2-S2 records the check as "not run, moved to CM2-40".

## Tests (headless)
Expected total: 205 + 35 + 5 (Amendment) = **245**. Mechanical updates: in `SaveSlotService_Test` "plays a save on a free plot", the 5th `onActivated` argument is now `view` (`view.saveName`, `view.role == "Owner"`). `BusinessState_Test` expects `SCHEMA_VERSION` 12. New fakes deep-copy and enforce `KeyNameLimit` like S1's.

| Test case file | Test name | Asserts |
|---|---|---|
| BusinessState_Test | migrates v11 to v12 with an owner-only member map | `{["42"]="Owner",["7"]="Manager"}` → only `"42"`; `inviteCode` nil; a 19-digit owner key equals `userIdText` |
| | validates members, seats and invite codes | Duo with 2 valid, 3 invalid; second Owner, role "Visitor", key "x1" invalid; Solo with a code invalid; "01234", "1234", "123456" invalid; "12345" on Duo valid |
| | adds members only with the current code and a free seat | Solo → InviteCodeInvalid; wrong code → InviteCodeInvalid; right → Joined; again → AlreadyMember; third → SaveFull; `code=nil` joins when free |
| | removes members and resizes within the member count | owner → OwnerCannotLeave; stranger → NotAMember; Solo with 2 → SizeTooSmall; Duo → Solo with 1 returns the old code and clears it; "Huge" → InvalidSize |
| Protocol_Test | validates co-op save payloads | every new action valid; Create size "Quad" ok, "Huge" InvalidSize; codes "01234", "1234", 12345, "12a45" → InvalidInviteCode; userId 0, 1.5, "7" → InvalidUserId; extra key → UnexpectedField |
| | counts recent requests without recording them | `recentCount` before and after `allowRequest`; a second `recentCount` call returns the same count |
| InviteCodeService_Test (new) | claims a free code for a save | key `invite:<code>` (12 chars) holds `saveId`; `isInviteCode(code)` |
| | tries another code on a collision | the first random code is held by another save → second claimed; all 8 held → InviteCodeUnavailable, the held values unchanged |
| | claiming again for the same save writes nothing | same code returned; writes unchanged |
| | releases only its own code | another save's release → false, no write; own → tombstone; another save can claim it |
| | looks up held, unknown and freed codes | held → saveId; unknown and tombstone → InviteCodeInvalid; throwing store → LoadFailed, no write |
| CompanyStateService_Test | members of a shared save may do every gameplay action | member B: order, price, hire ok; non-member → Forbidden; 19-digit member key works |
| | two members never double-spend the shared cash | cash = one order's cost + 1; A ok, B InsufficientFunds; B with A's requestId → DuplicateRequest; `spent` = cost; after `flushDirty` the stored record has 1 pending order |
| | changeTeam saves at once and stays dirty when the save fails | `saveNow` → one save; failing save → ok, `saved=false`, `isDirty` true |
| PersistenceService_Test | loads a member's save only when it exists | `requireExisting` on nil → SaveNotFound, 0 writes; `saveName=nil` keeps the stored name; a fresh load with `saveSize="Trio"` → Trio |
| | changes an unlocked record without taking its lock | member added, no `_session`; expired foreign lock removed; unexpired foreign or own → SaveInUse, no write; `_deletedAt` → SaveDeleted; nil → SaveNotFound; mutate refusal → its code, no write |
| | markDeleted reports members and the invite code | `info.memberUserIds = {43}`, `info.inviteCode` |
| SaveProfile_Test | reads the owner from a save ID and ignores shared names | `ownerUserIdOf` for 42 and `MAX_USER_ID`; nil for bad IDs; a Member entry named "Shared lot" does not block an own save "Shared lot" |
| CoopSave_Test (new; real services over fakes; OWNER 42, FRIEND 43, THIRD 44; a second stack with job-b shares the stores) | gives a Duo save an invite code on first play | entry size Duo; record Duo with a valid code; map entry → saveId; every key ≤ 50 chars; a Solo save has no code |
| | joins by code and shares the plot on one server | FRIEND entry Member/"Shared lot"; Play → same plot; one `persistence.load`; `playersOn` = both; List row for FRIEND has `name == nil`, `ownerName` |
| | members act on one cash balance without double-spending | both through `companies:handle`: one ok, one InsufficientFunds; record after flush shows one debit |
| | enforces the seat limit | THIRD Join → SaveFull, THIRD profile unchanged; after SetSize Trio → ok |
| | rejects owner-only actions from members | FRIEND Rename, Delete, RemoveMember, RegenerateCode, SetSize → OwnerOnly; name, members and code unchanged |
| | a new code invalidates the old one | new ≠ old; old key tombstoned; THIRD with old → InviteCodeInvalid; with new on a full Duo → SaveFull |
| | a removed member loses access at once and on the next play | FRIEND active → kicked (`activeCompanyId` nil, `onRemoved(43, saveId)`), entry removed; `companies:handle` for FRIEND → Forbidden; owner keeps the plot; a re-inserted stale entry → Play NotAMember and the entry is removed |
| | members play while the owner is offline | owner leaves (lock released); FRIEND Play loads it (`saveName` unchanged, owner unchanged); FRIEND order ok; after FRIEND leaves the record holds the lower cash |
| | the last player to leave unloads the shared save | owner switches away → still loaded, plot held, `plotReleased=false`; FRIEND final leave → no `_session`, plot free, `plotReleased=true` |
| | joining while nobody plays the save writes the record without a lock | record gains FRIEND, no `_session`, code unchanged |
| | one server holds a shared save at a time | job-a plays it; FRIEND Play on job-b → SessionLocked; FRIEND Join on job-b → SaveInUse |
| | leaving a shared save frees the seat | active FRIEND LeaveTeam → deactivated, record lacks 43, entry gone; owner LeaveTeam → OwnerCannotLeave |
| | deleting a shared save removes it from members' lists | while FRIEND plays it here → SaveInUse; after FRIEND left → ok; FRIEND profile lacks it; code tombstoned |
| | locks out repeated wrong codes | 10 InviteCodeInvalid (clock +61 s per 5) → 11th JoinLocked with no invite-store call; a valid code also refused until +3600 s; 60 server-wide failures from users 100..159 → user 160 JoinLocked |
| | a failed shared session is evicted when a member plays it again | thief lock + flush → handler; clear the lock; FRIEND Play → ok, owner deregistered with one `onDeactivated` |
| | a member's failed load never frees the shared plot | `beforeUpdate` on the owner's load key calls `play(FRIEND)` → SessionBusy; owner Play ok; plot still claimed |
| Localization_Test | has every co-op UI key in English and German | every key of step 10 exists in `en` and `de` |

## Playtest (Studio, via playtester)
1. Setup as S1 R9 (Rojo serve, plugin, API access). Confirm `RunPlaytest.BUILD == "cm2-s2-r2"`. The Studio MCP cannot start two clients. The second member is the shadow `999999999001` and the third is `999999999002`. Both act only through `saveAction`/`act`, so they hit the server paths a real client would.
2. `runPlaytest {mode="full"}` → **33 steps PASS**. `01` uses the threshold `>= 245`. Steps 29–32 run after 28 and before 22:
   - **`29 COOP_JOIN`** (deps 02, 02a):
     - Delete a leftover "Playtest Duo". Create it with `size="Duo"` and play it: `ActiveSaveRole` "Owner", `ActiveSaveSize` "Duo", Team code matches `^[1-9]%d%d%d%d$`, seats 2.
     - Shadow `Save.Join {code}` ok, then `Save.Play` ok with `plotId == R.plotId`.
     - Team (real) lists 2 members, the shadow `online` and Member. The shadow's `saves` row is Member with `name == nil`.
   - **`30 COOP_SHARED_CASH`** (29):
     - Both snapshots are equal. The shadow orders 1 tree → the real snapshot shows −UNIT_PRICE. The real player orders 1 with requestId X → the shadow snapshot equals the real one at −2×UNIT_PRICE.
     - The shadow sends X again → DuplicateRequest; cash stays at −2×UNIT_PRICE (Amendment C1). One UNIT_PRICE is left for step 32.
     - No HUD check here: RunPlaytest runs on the server and cannot see the client's ScreenGui (Amendment B1, item 4).
   - **`31 COOP_RULES`** (29):
     - Shadow RegenerateCode, RemoveMember{R}, SetSize Quad, Rename, Delete → all OwnerOnly.
     - Shadow2 Join → SaveFull. Owner SetSize Solo → SizeTooSmall.
     - Owner RegenerateCode → new ≠ old; shadow2 with the old code → InviteCodeInvalid.
     - SetSize Trio → shadow2 Join with the new code ok. SetSize Duo → SizeTooSmall. RemoveMember shadow2 → ok. SetSize Duo → ok.
   - **`32 COOP_REMOVE`** (29):
     - RemoveMember shadow → shadow `snapshot` NoActiveSave, its `saves` lacks the Duo, and Play of its ID → SaveNotFound.
     - Shadow re-joins with the code and plays. The real player plays "Playtest A" (owner offline from the save) → a shadow order is ok and debits UNIT_PRICE once (C1), and Team shows the owner `online=false`.
     - Real Delete of the Duo → SaveInUse.
     - The shadow plays its own first Owner save (`S.plotId` updated). Real Delete → ok, and the shadow's `saves` lacks the Duo.
   - CLEANUP also deletes "Playtest Duo" and calls `shadow2Leave`.
3. `runPlaytest {mode="soak", minutes=10}` → 6 steps PASS (unchanged).
4. Manual UI (real client):
   - Create a Duo save with the size toggle and open Team: the code and seats are shown, and `New code` changes the code.
   - Shadow joins (Server DM, hook): `shadowJoin`, then `saveAction` `Save.Join {code}` and `Save.Play {saveId}` for `999999999001`.
   - **HUD cash (B1):** hook `act {userId = 999999999001, action = "Supplier.PlaceOrder", payload = {speciesId = "DouglasFir", sizeId = "Medium", quantity = 1}}` → ok. Read C = `cash` from hook `snapshot(<real userId>)`. Then `execute_luau` with `datamodel_type = "Client"`: within 8 s `Players.LocalPlayer.PlayerGui.ChristmasMarketUI.Hud.CashLabel.Text` contains `"$" .. C .. " "`. Record both values.
   - Size buttons: Solo is refused with the SizeTooSmall text while the shadow is a member.
   - Member rows cannot appear on the real client, because the real player owns the Duo. Step 29 checks the shadow's member row through `saves`.
   - Phone Device Simulator check of the footer rows and team panel: moved to CM2-40 (Amendment C2), not a CM2-S2 criterion.
5. **BLOCKED in Studio:** a real 2-client run (two clients typing the code, HUD cash on both screens) and a join while another server plays the save. They go on the friends-test checklist (order 15).

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` → 245 run / 245 passed, `rojo build default.project.json` and `release.project.json` (release: 0 `StudioTestService`/`UnitTest`/`RunPlaytest`).
- Grep checks: `rg "tostring\((state\.)?(ownerUserId|userId)\)" src/shared/BusinessState.lua src/server/Services/CompanyStateService.lua` is empty; `rg "Manager|Visitor|OWNER_MANAGER" src` is empty.
- Backlog criteria:
  - headless: code uniqueness and regeneration (old code stops working), seat limit, owner-only actions rejected with `OwnerOnly`, a removed member loses access, two members acting at once never double-spend;
  - Studio (simulated second member): join by code, both act on the same plot, HUD cash matches the server cash both see.
- Skill checks:
  - Data: UpdateAsync only (invites, profiles, records); no write to a record another server holds; fail closed on read errors.
  - Security: every new field validated and rate-limited; wrong-code lockout before any store call; no save name sent to non-owners.
  - GUI: targets ≥ 44 px; `AutoLocalize=false` on names and codes.

## Out of scope
- S3: "Being played by X – Join", the MemoryStore save-to-server map, the teammate finder (it reuses `addMember(state, userId, nil)`).
- Display-time filtering of save names for members (G15). Ownership transfer. Leaderboards per member.
- The final-save lock release bug in `unloadCompany` (follow-up CM2-R5, launch order 5a). S2 changes only who calls `unloadCompany`, not what it does on a failed save.

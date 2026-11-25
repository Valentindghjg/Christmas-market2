# CM2-SP1 — Saves picker: no stuck "no saves yet" / "Please wait" on a fresh Play

Written by: `planner-high` (Opus 5.5, high). Implemented by: `implementer-opus` (tier L). Playtested by: `playtester`. Reviewed and committed by: `reviewer`. Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
An open save picker always ends with the server's save list once the server can answer, and a "Please wait until the last action has finished." status never outlives the busy moment that caused it.

## Source of truth
- Backlog line 5j1 (CM2-SP1) and its 2026-11-25 observation; PROGRESS 2026-11-25 entries for CM2-UVF10 re-runs 2-4.
- Observations (Studio `d95d782c`): re-run 2: on Play `savePickerEmpty` with `saveErrorBusy`, nothing changed until a manual request, while the server listed "N1 Phone". Re-run 3: the picker listed 4 saves **with** the status "Please wait until the last action has finished.".
- Protocol: `{ok, errorCode, revision, data}` (TECHNICAL_ARCHITECTURE section 3); `Save.List` rate limit 20 per 10 s (`GameConfig` `Saves.RateLimits`).
- roblox-networking: a remote's answer is not ordered against attribute replication.

## Cause verdict (from code, reproduced headless by the tests below)
Server: `main.server.lua` `onPlayerAdded` calls `saveSlots:openProfile(userId)`, which sets `_busy[userId]` across the DataStore `UpdateAsync` and sets `ProfileReady = true` only afterwards. `SaveSlotService:handle` answers any `Save.*` request during that time with `SaveActionBusy` (it does not wait). Client: `SavePicker.client.lua` opens at start (`ActiveSaveId == nil`) and sends `Save.List`.

| # | Finding | Verdict |
|---|---|---|
| C1 | The first `Save.List` reaches the server while `openProfile` holds `_busy` and gets `SaveActionBusy`. `refreshList` then shows `saveErrorBusy` and draws `lastSaves = {}`, so "You have no saves yet" shows. | **Confirmed.** It is the only start-up path to "empty list + busy text": `empty.Visible` is set only in `renderRows`, and nothing else sends a request before the player taps. |
| C2 | Nothing retries a `Save.List` that got `SaveActionBusy`. | **Confirmed.** `refreshList` has no retry. The only later trigger is the `ProfileReady` change. |
| C3 | The `ProfileReady` refresh is dropped because `request()` returns nil while `inFlight`. | **Confirmed as possible, timing dependent.** The server answers Busy before it sets `ProfileReady`, but the answer and the attribute change are not ordered on the client: when `openProfile` is quick, both land in the same frame and the deferred `ProfileReady` handler can run before the `InvokeServer` thread resumes. `refreshList` then hits `inFlight`, draws the old empty list and stops. Explains re-run 2 (empty + busy, stuck). |
| C4 | A successful `Save.List` never clears an earlier status. | **New, confirmed.** `refreshList` success only calls `renderRows`. When the `ProfileReady` refresh does run (other timing), the rows show and the busy text stays. Explains re-run 3 (4 saves + busy text). |
| C5 | Studio only: if the client's `Save.List` is handled before `onPlayerAdded` runs (the server script reaches `for _, player in Players:GetPlayers()` late), `openProfile` gets `SaveActionBusy` and the server sets `ProfileReady = false` and `CompanyError = "SaveActionBusy"` with the warning `profile load failed for <id>: SaveActionBusy`. | **Possible, not observed.** No run logged that warning. It cannot happen on live servers, because `PlayerAdded` is connected long before a player joins. Its UI effect (a busy status from `CompanyError`) is covered by the client fix (D5). No server change (see Out of scope). |
| C6 | `SavePickerUI.Enabled` stays true after a save loads. | **By design, no defect.** No code sets `Enabled`. The picker hides through `Picker.Visible = false` (`close()`). The `Saves` button is not in this ScreenGui: it is `HudRailUI.Rail.SavesButton` (`UiKit.addRailButton`). The backlog note "the ScreenGui also holds the Saves button" is inexact. Studio step 3 reads both. |

Root cause: the client treats a transient `SaveActionBusy` answer as final (C2, C3) and never clears a busy status (C4). The fix is client only. Server save, lock and rate-limit code stays unchanged.

## Implementer tier
Tier: L. Reason: concurrency bug of a previously unconfirmed cause in the save picker's request flow (owner rule 2026-11-24). The fix itself is client only.

## Skills to load
roblox-collaboration-mode, roblox-networking, roblox-security, roblox-gui, roblox-luau-core, roblox-luau-patterns, roblox-luau-types, roblox-tooling.

## Decisions
| # | Decision |
|---|---|
| D1 | A new pure module `src/shared/SaveListSync.lua` takes over the picker's request gate and list refresh. It is pure so the headless runner can test it: no Roblox services and no `task` (dependencies are injected). The pattern is `ModalCoordinator`. |
| D2 | One request at a time stays: `request` returns nil while another request is in flight (taps are ignored, as today). |
| D3 | A refresh asked for while a request is in flight is **remembered** (`pending`), not dropped. When the in-flight request returns, one refresh is deferred. |
| D4 | A `Save.List` answered `SaveActionBusy` is retried after `RetrySeconds = 1`, up to `RetryLimit = 10` retries per refresh chain (11 lists at most). Each new refresh starts a new chain, and a scheduled retry of an older chain does nothing (generation counter). Other error codes are not retried (`RateLimited` especially: retrying would make it worse). Retries stop when the picker is closed. Values PROVISIONAL, client UI timing. Worst case 10 lists per 10 s plus the player's own lists, under the server limit of 20 per 10 s. |
| D5 | Status ownership: a status set through `showTransient(code)` is **transient**. The picker routes `SaveActionBusy` from any source (list, other actions, `CompanyError`) and every failed `Save.List` there. A successful `Save.List` clears the status only if it still shows that transient text. Messages set by other code (for example `NoFreePlot`, "Loading your save…", "Joining…") are never cleared by a list. |
| D6 | When `CompanyError` (listener or start-up branch) is `"SaveActionBusy"`, the picker also starts a refresh (C5 path), so the busy text clears once the server answers. |
| D7 | `play()` checks `sync.inFlight()` before it sets "Loading your save…". Otherwise a tap during a retry list would leave that text with no request sent (more likely now that retries exist). |
| D8 | Diagnostics: the picker sets the ScreenGui attribute `ListBusyAnswers` (number) to the count of `Save.List` answers with `SaveActionBusy` in this client session. This is read in Studio as evidence that the race happened and was healed. It is not a security input. |
| D9 | No server change: `SaveSlotService`, `SaveSlotPicker`, `main.server.lua`, `Protocol`, `GameConfig` and the rate limits stay byte-identical. |

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/SaveListSync.lua` | New | Request gate, list refresh with pending, busy retry, transient status (D1-D5) |
| `src/client/SavePicker.client.lua` | Change | Use `SaveListSync`, D5-D8 wiring |
| `tests/studio/Cases/SaveListSync_Test.lua` | New | 9 headless cases (picked up automatically) |
| `tests/headless/run.luau` | Change | Add `SaveListSync = "src/shared/SaveListSync.lua"` to `sourcePaths` (alphabetical, after `SaveProfile`) |
| `docs/TEST_PLAN.md` | Change | Line J: append one sentence (below) |

## Steps

### 1. `src/shared/SaveListSync.lua` (new, `--!strict`)
Header comment: `-- Save picker request gate and list refresh (CM2-SP1): one request at a time, a refresh asked for during a request runs after it, a busy list is retried, and a busy or list error status is cleared by the next successful list. Pure; the picker injects remote calls and timers.`

```luau
local SaveListSync = {}
SaveListSync.RetrySeconds = 1 -- PROVISIONAL (CM2-SP1 D4)
SaveListSync.RetryLimit = 10 -- PROVISIONAL (CM2-SP1 D4)
SaveListSync.ListAction = "Save.List"
SaveListSync.BusyCode = "SaveActionBusy"

export type Deps = {
	invoke: (action: string, payload: { [string]: any }) -> any, -- yields; the response table
	defer: (callback: () -> ()) -> (),
	delay: (seconds: number, callback: () -> ()) -> (),
	isOpen: () -> boolean,
	render: (saves: { any }?) -> (), -- nil redraws the last list
	getStatus: () -> string,
	setStatus: (text: string) -> (),
	errorText: (errorCode: unknown) -> string,
	onBusyAnswer: (count: number) -> (),
}
export type Sync = {
	request: (action: string, payload: { [string]: any }) -> any, -- nil while another is in flight
	inFlight: () -> boolean,
	refresh: () -> (),
	showTransient: (errorCode: unknown) -> (),
	busyAnswers: () -> number,
}
function SaveListSync.new(deps: Deps): Sync
```
Private state in the closure: `inFlight = false`, `pending = false`, `generation = 0`, `transientText: string? = nil`, `busyCount = 0`.

| Function | Exact behaviour |
|---|---|
| `request(action, payload)` | If `inFlight`, return nil. Set `inFlight = true`. Run `local called, response = pcall(deps.invoke, action, payload)`. Set `inFlight = false`. If `not called` or `type(response) ~= "table"`, set `response = { ok = false, errorCode = "ConnectionError" }`. If `pending`, set `pending = false` and call `deps.defer(refresh)`. Return `response`. |
| `inFlight()` | Returns `inFlight`. |
| `showTransient(code)` | `local text = deps.errorText(code)`, `deps.setStatus(text)`, `transientText = text`. |
| `attempt(retriesLeft)` (private) | 1. If `not deps.isOpen()`, return. 2. If `inFlight`, set `pending = true` and return. 3. `generation += 1`, `local mine = generation`. 4. `local response = request(ListAction, {})`. It is never nil here: no yield between the check and the call. 5. On success (`response.ok == true and type(response.data) == "table"`): if `transientText ~= nil and deps.getStatus() == transientText`, call `deps.setStatus("")`. Then set `transientText = nil` and call `deps.render(if type(response.data.saves) == "table" then response.data.saves else {})`. Return. 6. On failure: `showTransient(response.errorCode)`, then `deps.render(nil)`. 7. If `response.errorCode == BusyCode`: `busyCount += 1`, `deps.onBusyAnswer(busyCount)`. If `retriesLeft > 0`, call `deps.delay(RetrySeconds, function() if mine == generation then attempt(retriesLeft - 1) end end)`. |
| `refresh()` | `attempt(SaveListSync.RetryLimit)` |
| `busyAnswers()` | Returns `busyCount`. |

Forward-declare `attempt` and `refresh` (`local attempt: (number) -> ()`, `local refresh: () -> ()`) so that `request` can defer `refresh`. Freeze nothing. Return the table `{ request = request, inFlight = function() return inFlight end, refresh = refresh, showTransient = showTransient, busyAnswers = function() return busyCount end }`.

### 2. `src/client/SavePicker.client.lua`
| Where | Change |
|---|---|
| Requires (after `SaveProfile`) | `local SaveListSync = require(Shared:WaitForChild("SaveListSync"))` |
| Lines 219-229 (`inFlight`, `request`) | Replace with: comment `-- Only one request is in flight at a time; a tap during one is ignored (SaveListSync, CM2-SP1).`, then `local sync: SaveListSync.Sync` and `local function request(action: string, payload: { [string]: any }): any return sync.request(action, payload) end` |
| `showError(code)` | `if code == SaveListSync.BusyCode then sync.showTransient(code) return end` before the existing line |
| `play(entry)` | First line: `if sync.inFlight() then return end`, before `status.Text = localized("saveLoading")` |
| `refreshList = function() … end` (lines 468-480) | Replace with the construction below plus `refreshList = function() sync.refresh() end` |
| `CompanyError` listener | After `showError(code)`: `if code == SaveListSync.BusyCode then refreshList() end` |
| Start-up branch (bottom) | Inside `if code ~= nil then`, after `showError(code)`: the same line |
| Everything else | Unchanged: `open`, `close`, the `ProfileReady` listener (it already calls `refreshList()`), rows, the footer and every `Save.*` payload |

Construction (placed right before `refreshList = …`, after `renderRows` and `redrawRows`):
```luau
sync = SaveListSync.new({
	invoke = function(action, payload) return UiKit.request(saveAction, action, payload) end,
	defer = function(callback) task.defer(callback) end,
	delay = function(seconds, callback) task.delay(seconds, callback) end,
	isOpen = function() return picker.Visible end,
	render = function(saves) renderRows(saves or lastSaves) end,
	getStatus = function() return status.Text end,
	setStatus = function(text) status.Text = text end,
	errorText = function(code) return localized(Localization.saveErrorKey(code)) end,
	onBusyAnswer = function(count) gui:SetAttribute("ListBusyAnswers", count) end,
})
```
`sync` is assigned when the script loads, before any handler can run (the first call is the start-up `open()` at the bottom), so `request` and `showError` never see nil. Add type annotations as `--!strict` requires. Keep `ListBusyAnswers` unset until the first busy answer.

### 3. `docs/TEST_PLAN.md` line J
Append: ` Save picker request flow (busy list retry, refresh during a request, transient busy status): \`SaveListSync_Test\` (CM2-SP1).`

## Tests (headless)
`tests/studio/Cases/SaveListSync_Test.lua`, factory `return function(t)`, requires `Shared.SaveListSync` like `ModalCoordinator_Test`. Harness `make(open: boolean?)` in the file:
- `invoke`: appends `action` to `calls`, sets `waiting = coroutine.running()`, returns `coroutine.yield()`.
- `answer(response)`: resumes `waiting` with `response` (clear `waiting` first) and asserts that the resume succeeded.
- `defer` and `delay` append to the queues `deferred` and `delayed` (`{seconds, callback}`). `flushDeferred()` and `fireDelayed()` pop each entry and run it in a new coroutine (`coroutine.wrap(callback)()`).
- `isOpen` reads `h.open` (default true). `render` appends its argument (or the marker `"last"` for nil) to `renders`. `status` is a string field (`""` at start); `errorText(code)` returns `"err:" .. tostring(code)`; `onBusyAnswer` stores the count.
- Start a refresh with `coroutine.wrap(sync.refresh)()`.
- `BUSY = { ok = false, errorCode = "SaveActionBusy" }`, `OK = { ok = true, data = { saves = { { saveId = "a", name = "N1 Phone" } } } }`.

| Test name | Asserts |
|---|---|
| `busy list then ProfileReady during flight ends with rows and a clear status` | Start a refresh (calls 1). Call `sync.refresh()` while in flight: calls stay 1. `answer(BUSY)`: status `"err:SaveActionBusy"`, last render `"last"`, busy count 1, `#deferred == 1`. `flushDeferred()`: calls 2. `answer(OK)`: last render has 1 save, status `""`. `fireDelayed()` (the stale retry): calls stay 2. |
| `busy list is retried after RetrySeconds` | Refresh, `answer(BUSY)`: `#delayed == 1`, `delayed[1].seconds == SaveListSync.RetrySeconds`. `fireDelayed()`: calls 2. `answer(OK)`: 1 save rendered, status `""`. |
| `busy retries stop after RetryLimit` | Refresh, then repeat `answer(BUSY)` and `fireDelayed()`. After `RetryLimit + 1` busy answers, calls == `RetryLimit + 1`, `#delayed == 0`, status `"err:SaveActionBusy"`, busy count `RetryLimit + 1`. |
| `other errors are not retried and clear on the next success` | Refresh, `answer({ok=false, errorCode="RateLimited"})`: `#delayed == 0`, status `"err:RateLimited"`, busy count 0. New refresh, `answer(OK)`: status `""`. |
| `a successful list keeps a status it did not set` | Set `h.status = "other"`. Refresh, `answer(OK)`: status `"other"`. |
| `a transient busy status from outside is cleared by the next list` | `sync.showTransient("SaveActionBusy")`: status `"err:SaveActionBusy"`. Refresh, `answer(OK)`: status `""`. |
| `closed picker neither refreshes nor retries` | `h.open = false`, `sync.refresh()`: calls 0. `h.open = true`, refresh, `answer(BUSY)`, then `h.open = false` and `fireDelayed()`: calls stay 1. |
| `request during flight returns nil and queues no refresh` | Start `sync.request("Save.Play", {saveId="a"})` in a coroutine. `sync.inFlight()` is true and `sync.request("Save.Create", {})` returns nil. `answer({ok=true, data={}})`: `#deferred == 0`, `sync.inFlight()` false. |
| `a throwing invoke becomes ConnectionError and releases the gate` | Make `invoke` error. `sync.request("Save.List", {})` returns `errorCode == "ConnectionError"` and `sync.inFlight()` is false afterwards. Refresh with the same throwing invoke: status `"err:ConnectionError"`, `#delayed == 0`. |

Expected headless count: 589 + 9 = **598**, all pass. The existing `SaveSlotService_Test`, `CoopSave_Test`, `CrossServer_Test`, `Protocol_Test` and `SaveMigration_Test` stay untouched and green. They show that the server's save, lock and rate-limit behaviour is unchanged (D9).

## Playtest (Studio, via playtester)
Setup: Rojo serving this commit (pre-check: the live `ReplicatedStorage.Shared.SaveListSync` exists). Use the existing Studio profile with its saves; do not create or delete saves. Read the server save count once, in the first Play after `ProfileReady` is true, through the hook command `saves` (userId; it returns `{}` before the profile is open). It must be ≥ 1 and is the expected row count for all three Plays.

1. **Three fresh Plays** (Stop, then Play, three times). In each Play, from the moment `PlayerGui.SavePickerUI` exists, poll every 0.5 s for up to 5 s: `SavePickerUI.Picker.Visible`, the number of `SavePickerUI.Picker.SaveList` children named `SaveRow_*`, `SaveList.PickerStatus.Text`, `SaveList.Empty.Visible`, and the attribute `SavePickerUI:GetAttribute("ListBusyAnswers")`. PASS when within 5 s: `Picker.Visible` true, row count == server save count, `PickerStatus.Text == ""`, `Empty.Visible` false. Then read once more 3 s later: same values (no late busy text). Record the time to the first full reading and `ListBusyAnswers` (nil means 0) for each Play.
2. **Reproduction evidence.** If `ListBusyAnswers` ≥ 1 in any Play, record "race reproduced and healed". If it is nil in all three, record "race not reproduced in Studio". The fix is then verified headless only, and step 1 still has to pass.
3. **Load, then the Enabled reading (C6).** In the third Play, press `Play` on the "N1 Phone" row. After `CompanyReady` is true, read `SavePickerUI.Enabled` (expected true, by design), `SavePickerUI.Picker.Visible == false`, `HudRailUI.Rail.SavesButton.Visible == true`. Then tap `SavesButton`: the picker opens with the rows within 5 s and status `""`. Then tap `BackToGame`: the picker closes. Only `Picker.Visible` true after load counts as a defect.
4. **Console.** Over all Plays there must be no `[ChristmasMarket2] profile load failed … SaveActionBusy` warning and no new `[ChristmasMarket2]` error. Known lines: the `rbxassetid://203785492` warning (CM2-ASSETWARN) and Studio-assistant lines. Quote any other line exactly.

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests` (0 errors, 0 warnings), `lune run tests/headless/run.luau` 598 run, 598 passed, `rojo build default.project.json --output build.rbxlx`.
- Diff check (reviewer): no change under `src/server/`, and no change in `src/shared/Protocol.lua`, `GameConfig.lua` or `Localization.lua`.
- Ticket criteria: cause confirmed (verdict above, headless reproduction in test 1); the busy-then-ProfileReady test renders the rows and clears the status; save, lock and rate-limit behaviour unchanged (D9, existing tests pass); Studio steps 1 and 3 PASS in three fresh Plays (rows within 5 s, no `saveErrorBusy` left); C6 readings recorded.
- If Studio step 4 shows the C5 warning, the reviewer records it and the planner adds a follow-up task CM2-SP2 (tier L, server: `onPlayerAdded` must not treat a busy profile open as a load failure). CM2-SP1 still passes if steps 1 and 3 pass.

## Out of scope
- Any server change (C5 stays a Studio-only start-up order. Changing `openProfile` to wait for an in-flight action would touch save concurrency for a path live servers cannot reach. It becomes CM2-SP2 only if observed).
- Retrying actions other than `Save.List` (Play, Create, Rename, Delete, Join, Teleport, LeaveTeam keep "tap ignored while busy" and show their error).
- A loading indicator for the picker list, and new string keys.

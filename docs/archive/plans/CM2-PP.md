# CM2-PP — Plot picker at session start

Written by: `planner-high` (Opus 5.5, high). Implemented by: the agent for the tier below. Playtested by: `playtester`. Reviewed and committed by: `reviewer`. Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
The first player of a save on a server picks a free plot from a camera view over the map ("Plot N of 6", browse, confirm) instead of getting the first free one. Teammates of a save already playing here attach to its plot directly; a player teleported from a full server picks again.

## Source of truth
Backlog 17a CM2-PP (planner decisions and Accept (a)–(d)); PRODUCT_SPEC owner decision "Plot picker" (2026-11-24); DECISION_LOG 2026-11-24 "owner: plot picker at session start"; REFERENCE_GAME_LIVE_TEST §1 item 1 (mechanic only; own layout and wording); TECHNICAL_ARCHITECTURE §3 save slots "Play and switch" and §3 protocol `{ok, errorCode, revision, data}`; UI rule until CM2-UI: current `UiTheme`/`UiKit`.

## Implementer tier
Tier: L. Reason: the plot claim inside `Save.Play` (concurrency with switches, teammates and loads), a new rate-limited remote action and a new persisted profile field.

## Skills to load
roblox-collaboration-mode, roblox-networking, roblox-security, roblox-data, roblox-server-data, roblox-gui, roblox-input, roblox-localization, roblox-luau-core, roblox-luau-types.

## Decisions (engineering; record them in DECISION_LOG as one entry "CM2-PP engineering decisions")
| Topic | Decision |
|---|---|
| New action | `Save.Plots {saveId}` → the plot list for that save; rate limit 20 per 10 s (like `Save.List`). |
| Who picks | `pick = true` only when the save holds no plot here, nobody plays it here, no load of it is pending or unloading, it is not the caller's active save, and at least one plot is free for the caller. Otherwise `pick = false` and the client sends `Save.Play {saveId}` at once (attach, or today's automatic/teleport path). |
| Chosen play | `Save.Play {saveId, plotId?}`. Without `plotId`: unchanged automatic claim. With `plotId`: attach paths ignore it; otherwise the server claims exactly that plot if still free, else `PlotTaken` (other plots free) or today's no-free-plot path (none free). Nothing is reserved while browsing. |
| Own current plot | The plot of the caller's active save counts as free when the caller is its only player here and it is neither loading nor unloading (a switch releases it before the claim). |
| Pre-check | `PlotTaken` is decided before the current save is left, so an obvious refusal never drops the player's running save; the claim after the leave stays authoritative. |
| Last plot | Per player and save: profile entry field `lastPlotId` (written on every play and attach). Optional, no `SaveProfile.VERSION` bump (precedent `tutorialOffered`, CM2-49): old servers ignore and keep it. Validation: nil or a string of 1–32 bytes; an id the server does not know is ignored, never a validation failure. Preselect = `lastPlotId` if free for the caller, else the first free plot in config order. |
| Road side | From `MapLayout.PLOTS[number].z`: `< 0` → `"South"`, else `"North"` (plots 1–3 south, 4–6 north of the main road). |
| Occupant name | The lot sign's public text (`WorldService.lotSignName`: broadcast-filtered save name or "<user>'s Tree Lot"); nil while the sign shows "Lot available". Raw save names never leave the server. |
| Teleport arrival | A `cm2NoFreePlot` arrival no longer auto-plays: the server stores `{saveId, attempt}` per player (`noteArrival`) and sets the player attribute `PlotPickSaveId`; the client opens the plot picker for that save. A later `Save.Play` of the same save uses the stored attempt, so `MaxPlotTeleports` still bounds the chain. |
| Camera | Scriptable camera at `center + (0, 55, facing × 60)` looking at the plot centre (`MapLayout.PLOTS`), tween 0.6 s Quad Out; `RequestStreamAroundAsync(center)` per selection (StreamingEnabled). |
| Kept automatic | `Save.FinderStart` (creates and plays at once), `Save.Teleport` arrivals (`arrive`), Studio hooks (`shadowJoin`, `rejoin`) and `runPlaytest` keep the automatic claim. |

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/GameConfig.lua` | Change | `Saves.RateLimits["Save.Plots"]` |
| `src/shared/Protocol.lua` | Change | `SaveActions.Plots`; payload keys; `Save.Play.plotId` check |
| `src/shared/SaveProfile.lua` | Change | optional `entry.lastPlotId` |
| `src/shared/UiTheme.lua` | Change | `UiTheme.PlotPicker`, `UiTheme.plotPickerLayout` |
| `src/shared/Localization.lua` | Change | 15 keys en + de; `SaveErrorKeys.PlotTaken` |
| `src/server/Services/PlotService.lua` | Change | `claimExact`, `plotIds`, `has` |
| `src/server/Services/SaveSlotService.lua` | Change | deps `plotLabel`, `_arrivals`, `_handle` Plots/Play |
| `src/server/Services/SaveSlotPicker.lua` | Change | choices, pre-check, exact claim, `_touch` last plot, `noteArrival`, arrival cleanup |
| `src/server/Services/WorldService.lua` | Change | `lotSignName` |
| `src/server/main.server.lua` | Change | wiring, arrival, attributes |
| `src/client/PlotPicker.lua` | New | ModuleScript: panel, confirm, camera, input |
| `src/client/SavePicker.client.lua` | Change | `Save.Plots` before `Save.Play`, arrival trigger, guards |
| `tests/studio/Cases/PlotService_Test.lua`, `SaveProfile_Test.lua`, `Protocol_Test.lua`, `SaveSlotService_Test.lua`, `CoopSave_Test.lua`, `UiTheme_Test.lua` | Change | tests below |
| `tests/studio/Playtest/Steps/PlotPicker.lua` | New | step 65 `PLOT_PICK` |
| `tests/studio/Playtest/RunPlaytest.lua` | Change | `BUILD = "cm2-pp"`; install `"PlotPicker"` after `"Trees"` |
| `docs/TECHNICAL_ARCHITECTURE.md` | Change | §3 "Play and switch": one sentence on `Save.Plots`, the exact claim, `PlotTaken`, the arrival picker; the profile gains `lastPlotId` (no version bump) |
| `docs/TEST_PLAN.md` | Change | §3b: 66 steps, BUILD `cm2-pp`, step 65 description |
| `docs/DECISION_LOG.md`, `docs/PROGRESS.md`, `docs/CLAUDE_BACKLOG.md` | Change | decisions entry; evidence; 17a status |

## Data and config
- `GameConfig.Saves.RateLimits["Save.Plots"] = { limit = 20, window = 10 }` (PROVISIONAL, same as `Save.List`).
- `UiTheme.PlotPicker = { cameraHeight = 55, cameraBack = 60, tweenSeconds = 0.6, displayOrder = 21, numberTextSize = 18 }` (PROVISIONAL).
- Profile entry (`profile.saves[i]`): new optional `lastPlotId: string?`. No migration; no version bump.
- `Save.Plots` response `data`:
  `{ saveId: string, pick: boolean, total: number, preselectId: string?, plots: { { plotId: string, number: number, side: "South"|"North", free: boolean, name: string? } } }`. `plots` is empty and `preselectId` nil when `pick == false`; `total` = number of plots on the server (6 live).
- New error code `PlotTaken`. A bad plot id is `InvalidPlotId` (validator, or service for an id the server does not hold).

## Steps

### 1. Shared
1. `Protocol.SaveActions.Plots = "Save.Plots"` (after `Play`). `SAVE_PAYLOAD_KEYS`: `[Play] = { saveId = true, plotId = true }`, `[Plots] = { saveId = true }` (the generic saveId check covers it). In `validateSaveRequest` add a branch for `Play`: `payload.plotId ~= nil and table.find(GameConfig.PersonalPlotIds, payload.plotId) == nil` → `false, "InvalidPlotId"` (a number or any non-listed string fails).
2. `SaveProfile.validEntry`: add `and (entry.lastPlotId == nil or (type(entry.lastPlotId) == "string" and #entry.lastPlotId >= 1 and #entry.lastPlotId <= 32))`. Comment: `-- CM2-PP: the last plot this player played the save on (no version bump).` `listView` unchanged.
3. `UiTheme`: export type `PlotPickerLayout = { panel: Box, title: Box, prevButton: Box, nextButton: Box, plotNumber: Box, status: Box, message: Box, back: Box, choose: Box, confirm: Box, confirmText: Box, yes: Box, no: Box }` and `function UiTheme.plotPickerLayout(m: Metrics): PlotPickerLayout`. Panel and confirm are screen boxes; the others are relative to their frame (panel children to `panel`, `confirmText`/`yes`/`no` to `confirm`). Values (`w`, `half` etc. as written; `box` clamps):
   - `w = min(520, m.width − 2·m.margin)`; `panel = box(floor((m.width − w)/2), m.height − m.margin − 176, w, 176)`; `half = floor((w − 36)/2)`.
   - `title (12, 6, w−24, 28)`, `prevButton (12, 40, 52, 52)`, `nextButton (w−64, 40, 52, 52)`, `plotNumber (72, 40, w−144, 24)`, `status (72, 64, w−144, 32)`, `message (12, 98, w−24, 18)`, `back (12, 120, half, 44)`, `choose (24+half, 120, w−36−half, 44)`.
   - `cw = min(360, m.width − 2·m.margin)`; `confirm = box(floor((m.width − cw)/2), max(m.margin, floor((panel.y − 120)/2)), cw, 120)`; `ch = floor((cw − 36)/2)`; `confirmText (12, 10, cw−24, 44)`, `yes (12, 64, ch, 44)`, `no (24+ch, 64, cw−36−ch, 44)`.
4. `Localization` (en / de, both tables; `SaveErrorKeys.PlotTaken = "saveErrorPlotTaken"`; `InvalidPlotId` uses the fallback):

| Key | en | de |
|---|---|---|
| `plotPickerTitle` | Choose your plot | Wähle dein Grundstück |
| `plotPickerNumber` | Plot %d of %d | Grundstück %d von %d |
| `plotPickerFreeSouth` | Available – south side of the road | Frei – südliche Straßenseite |
| `plotPickerFreeNorth` | Available – north side of the road | Frei – nördliche Straßenseite |
| `plotPickerOccupiedBy` | Occupied – Home of %s | Belegt – Zuhause von %s |
| `plotPickerOccupied` | Occupied | Belegt |
| `plotPickerPrev` | ◀ | ◀ |
| `plotPickerNext` | ▶ | ▶ |
| `plotPickerChoose` | Choose | Wählen |
| `plotPickerBack` | Back | Zurück |
| `plotPickerConfirm` | Choose plot %d? | Grundstück %d wählen? |
| `plotPickerYes` / `plotPickerNo` | Yes / No | Ja / Nein |
| `plotPickerMoving` | Moving in… | Einzug läuft… |
| `saveErrorPlotTaken` | Someone just took this plot. Please choose another one. | Dieses Grundstück wurde gerade vergeben. Bitte wähle ein anderes. |

(`plotPickerYes` and `plotPickerNo` are two keys; 15 keys in total with `saveErrorPlotTaken`.)

### 2. PlotService
- `function PlotService:has(plotId: unknown): boolean` — `type(plotId) == "string" and self._plots[plotId] ~= nil`.
- `function PlotService:plotIds(): { string }` — a copy of `self._order`.
- `function PlotService:claimExact(holderId: string, plotId: string): (string?, string?)` — invalid holder → `nil, "InvalidHolder"`; existing claim of the holder → that plot, nil (the requested id is ignored); `not self:has(plotId)` → `nil, "UnknownPlot"`; taken → `nil, "PlotTaken"`; else claim it (both maps) and return it. Header comment: the client-chosen id is only honoured when free.

### 3. SaveSlotService (core)
- `new`: `self._plotLabel = deps.plotLabel` (optional `(plotId: string) -> string?`), `self._arrivals = {}` (userId → `{saveId, attempt}`).
- `_handle`: `Plots` → `return self:_plotChoices(userId, profile, payload)`. `Play` →
  ```lua
  local arrival = self._arrivals[userId]
  local options = {
      plotId = payload.plotId,
      attempt = if arrival and arrival.saveId == payload.saveId then arrival.attempt else nil,
  }
  local played, playError, data = self:_play(userId, payload.saveId, options)
  if played then
      self._arrivals[userId] = nil
  end
  ```
  then the existing response lines.

### 4. SaveSlotPicker (methods of SaveSlotService)
Add a section `-- Plot picker (CM2-PP)` before "Play, switch and leave", with:
- `_needsPick(companyId): boolean` — `self._plots:getPlot(companyId) == nil and self._members[companyId] == nil and (self._pendingLoads[companyId] or 0) == 0 and not self._unloading[companyId]`.
- `_releasesOnLeave(userId, holder: string): boolean` — `holder == self._active[userId]`, `#self:playersOn(holder) == 1`, no pending load, not unloading.
- `_plotFreeFor(userId, plotId: string): boolean` — `self._plots:has(plotId)` and (`holderOf(plotId) == nil` or `_releasesOnLeave(userId, holder)`).
- `_freeCountFor(userId): number` — count of `_plotFreeFor` over `self._plots:plotIds()`.
- `_plotLabelOf(plotId): string?` — nil without `self._plotLabel`; `pcall`; a string of 1–100 bytes, else nil.
- `_plotChoices(userId, profile, payload)`: entry = `SaveProfile.find(profile, payload.saveId)`, nil → `failure("SaveNotFound")`. `companyId = companyIdOf(saveId)`; `ids = self._plots:plotIds()`. If `self._active[userId] == companyId or not self:_needsPick(companyId) or self:_freeCountFor(userId) == 0` → `{ok = true, data = {saveId, pick = false, total = #ids, plots = {}}}`. Else one row per id in order: `number` = index, `side` per Decisions, `free = _plotFreeFor`, `name = if not free then self:_plotLabelOf(plotId) else nil`. `preselectId` = `entry.lastPlotId` when it is a string and `_plotFreeFor`, else the first free row. Return `pick = true`.
- `_plotRefusal(userId, companyId, plotId): string?` — `not self._plots:has(plotId)` → `"InvalidPlotId"`; `not _needsPick(companyId)` → nil; `_plotFreeFor` → nil; `_freeCountFor(userId) == 0` → nil; else `"PlotTaken"`.
- `noteArrival(userId: number, saveId: string, attempt: number)` — stores `{saveId, attempt}` only when `SaveProfile.isSaveId(saveId)` and `attempt` is an integer 1..`SAVES.MaxPlotTeleports`.

`_play` changes (`settings.plotId` is the requested id or nil):
1. Directly after the "already active" early return: `if settings.plotId ~= nil then local refusal = self:_plotRefusal(userId, companyId, settings.plotId); if refusal then return false, refusal, nil end end`.
2. In the load loop replace `plotId = self._plots:claim(companyId, preferred)` with:
   ```lua
   if settings.plotId ~= nil then
       local exactError
       plotId, exactError = self._plots:claimExact(companyId, settings.plotId)
       if not plotId and (exactError ~= "PlotTaken" or self._plots:freeCount() > 0) then
           self:_endLoad(companyId)
           if self:_idle(companyId) then
               self:_releaseLocation(saveId)
           end
           return false, if exactError == "PlotTaken" then "PlotTaken" else "InvalidPlotId", nil
       end
   else
       plotId = self._plots:claim(companyId, preferred)
   end
   ```
   The following `if not plotId then` (no free plot → teleport) block stays unchanged and now also runs for a taken chosen plot with no plot free.
3. `_touch(userId, saveId, companyId, plotId: string)`: inside the transform, `stamped.lastPlotId = plotId` next to `lastPlayedAt`. Both callers pass the plot (`_attach`: its `plotId`; end of `_play`: `plotId :: string`).
4. `leave(userId, final=true)`: inside the pcall block, next to `self._profiles[userId] = nil`, add `self._arrivals[userId] = nil`.

### 5. WorldService
`function WorldService.lotSignName(plotId: string): string?` (after `setLotSign`): board via `lotSignBoard`; `SignFront.Frame.Name` TextLabel; nil when missing, when its attribute `NameSource` is nil or `"Free"`, or when `Text == ""`; else `Text`.

### 6. main.server.lua
1. `SaveSlotService.new` deps: `plotLabel = WorldService.lotSignName`.
2. `onPlayerAdded`: replace the `noFreePlotJoin` auto-play block with:
   ```lua
   local saveId, attempt = noFreePlotJoin(player)
   if saveId and attempt then
       -- CM2-PP: the arriving player picks a plot again (PlotPicker); the attempt rides along.
       saveSlots:noteArrival(player.UserId, saveId, attempt)
       player:SetAttribute("PlotPickSaveId", saveId)
   end
   ```
3. Activation handler: `player:SetAttribute("PlotPickSaveId", nil)` next to `CompanyError` nil.
4. `handleSaveAction`: the Play failure branch sets `CompanyError` only when `response.errorCode ~= "PlotTaken"` (the picker shows it itself).

### 7. Client: `src/client/PlotPicker.lua` (ModuleScript, `--!strict`)
API:
```lua
export type Request = (action: string, payload: { [string]: any }) -> any -- nil while another request is in flight
export type Callbacks = { onBack: () -> (), onFailed: (errorCode: string) -> () }
function PlotPicker.open(saveId: string, choices: any, request: Request, callbacks: Callbacks)
function PlotPicker.isOpen(): boolean
```
- UI (`UiKit.screenGui("PlotPickerUI", UiTheme.PlotPicker.displayOrder)`, colours as SavePicker: `Panel`, `Cream`, `Gold`, `Sand`, `Disabled`; `UiKit.corner(_, UiTheme.CornerRadius.Panel)`): Frame `Panel` with `Title` (Title size), `Prev`/`Next` (`UiKit.button`, Sand, text 20), `PlotNumber` (`numberTextSize`), `PlotStatus` (Small, wrapped, `AutoLocalize = false`), `Message` (Small, `AutoLocalize = false`), `Back` (Sand, 16), `Choose` (Gold, 16); Frame `Confirm` (ZIndex 2, hidden) with `ConfirmText` (16, wrapped), `Yes` (Gold), `No` (Sand). Boxes from `UiKit.onLayout(gui, …)` + `UiTheme.plotPickerLayout`. Attributes on the ScreenGui for the playtester: `Open` (boolean), `SelectedPlotId` (string or nil).
- Display of row `r`: `PlotNumber` = `localizedFormat("plotPickerNumber", r.number, total)`; status = free → `plotPickerFreeSouth`/`plotPickerFreeNorth` by `r.side`; taken → `localizedFormat("plotPickerOccupiedBy", r.name)` when `r.name` is a string, else `plotPickerOccupied`. `Choose` enabled (`Active`, `AutoButtonColor`, Gold) only when `r.free`; else Disabled colour and inactive.
- `open`: store state; index = row with `plotId == choices.preselectId`, else the first free row, else 1. `UiKit.closeModals()`, `UiKit.setBaseLayer(back)`, `UiKit.setRailHidden(true)`; disable character controls (`pcall(require, PlayerScripts.PlayerModule):GetControls():Disable()`, skipped on failure); bind actions with `ContextActionService:BindActionAtPriority(name, handler, false, Enum.ContextActionPriority.High.Value, …keys)`: `PlotPickerPrev` (A, Left, ButtonL1), `PlotPickerNext` (D, Right, ButtonR1), `PlotPickerAccept` (Return, ButtonA: Yes while confirming, else Choose), `PlotPickerCancel` (ButtonB: No while confirming, else Back); handlers act only on `Enum.UserInputState.Begin` and return `Enum.ContextActionResult.Sink`. Camera `Scriptable`, placed at once (no tween) on the first plot.
- `focus(index, tween)`: index wraps 1..#plots; the camera goal is `CFrame.lookAt(center + Vector3.new(0, cameraHeight, spot.facing * cameraBack), center)` with `spot = MapLayout.PLOTS[row.number]`, `center = Vector3.new(spot.x, 0, spot.z)`; cancel the previous tween; `TweenService:Create(camera, TweenInfo.new(tweenSeconds, Quad, Out), {CFrame = goal})`; `task.spawn` a `pcall(player.RequestStreamAroundAsync, player, center)`. Browsing is ignored while confirming or busy.
- Choose (free row) → `Confirm` visible, text `localizedFormat("plotPickerConfirm", row.number)`. No → hide. Yes → busy; `Message` = `plotPickerMoving`; `request("Save.Play", { saveId = saveId, plotId = row.plotId })`; nil → not busy, return.
  - ok → `exit()` (success; no callback).
  - `PlotTaken` → hide Confirm; `Message` = `localized(Localization.saveErrorKey("PlotTaken"))`; `request("Save.Plots", { saveId })`: ok and `pick` → replace rows, keep the index, redraw (no camera move), not busy; ok and not `pick` → `request("Save.Play", { saveId })` (attach or automatic path): ok → `exit()`, else `exit()` + `onFailed(code)`; not ok → `exit()` + `onFailed(code)`.
  - other error → `exit()` + `onFailed(errorCode)`.
- Back → `exit()` + `onBack()`.
- `exit()`: unbind the four actions, re-enable controls, cancel the tween, `camera.CameraType = Custom`, `camera.CameraSubject` = the character's Humanoid when present, hide both frames, `UiKit.setBaseLayer(nil)`, `UiKit.setRailHidden(false)`, attributes `Open = false`, `SelectedPlotId = nil`, clear state.

### 8. Client: SavePicker.client.lua
- `local PlotPicker = require(script.Parent:WaitForChild("PlotPicker") :: ModuleScript)`.
- `play(entry)`: after the in-flight guard and `saveLoading`, first `request("Save.Plots", { saveId = entry.saveId })` (nil → return; not ok → `showError`, return). If `data.pick == true`: `close()` then `PlotPicker.open(entry.saveId, data, request, { onBack = open, onFailed = function(code) open(); showError(code) end })`, return. Else the existing `Save.Play {saveId}` code unchanged.
- The `ActiveSaveId` and `CompanyError` listeners do nothing while `PlotPicker.isOpen()`.
- Arrival: `local function playArrival()` — returns unless `PlotPickSaveId` is a string, `ActiveSaveId` is nil and the plot picker is closed; then `task.spawn`: `open()` if the picker is hidden, wait while `sync.inFlight()` (poll 0.2 s, at most 10 s), `play({ saveId = id })`. Connect it to `GetAttributeChangedSignal("PlotPickSaveId")` and call it once after the initial open at the end of the script.

### 9. Playtest step (`tests/studio/Playtest/Steps/PlotPicker.lua`, header `-- Playtest step 65 (full mode): plot picker (CM2-PP).`)
`addStep("65", "PLOT_PICK", { "02", "02a" }, …)`, using `ctx` helpers (`saveActOk`, `saveRefused`, `deleteLeftover`, `playSave`, `poll`, `realPlayer`, `check`, `R`, `S`, `ctx.saveA`). `SAVE_P = "Playtest P"`.
1. `deleteLeftover(SAVE_P)`; `check(type(S.plotId) == "string", …)`; `origin = realPlayer():GetAttribute("PlotId")`; `saveP = saveActOk("Save.Create", { name = SAVE_P }).saveId`.
2. `list = saveActOk("Save.Plots", { saveId = saveP })`: `pick == true`, `total == 6`, `#plots == 6`; row i has `plotId == "Plot_0"..i`, `number == i`, `side` South for 1–3 and North for 4–6; the row of `S.plotId` has `free == false` and `name` nil or a non-empty string; the row of `origin` has `free == true`; `preselectId` is a free row's id.
3. `saveRefused("Save.Play", { saveId = saveP, plotId = S.plotId }, "PlotTaken")`; `realPlayer():GetAttribute("ActiveSaveId") == ctx.saveA` (pre-check kept the save).
4. `target` = the first free row whose id ≠ `origin`; `played = saveActOk("Save.Play", { saveId = saveP, plotId = target })`; `played.plotId == target`; poll ≤ 10 s for `PlotId == target` and `ActiveSaveId == saveP`.
5. `saveActOk("Save.Plots", { saveId = saveP }).pick == false`.
6. `back = saveActOk("Save.Play", { saveId = ctx.saveA, plotId = origin })`; `back.plotId == origin`; poll ≤ 10 s for `CompanyReady` and `ActiveSaveId == ctx.saveA`; `R.plotId = origin`.
7. `saveRefused("Save.Play", { saveId = ctx.saveA, plotId = "Plot_9" }, "InvalidPlotId")`; `saveActOk("Save.Delete", { saveId = saveP, confirmName = SAVE_P })`.
Detail: `string.format("6 plots, %s taken, chose %s, back on %s", S.plotId, target, origin)`.

## Tests (headless)
Expected total **656** (637 + 19). In `SaveSlotService_Test` `setup`, add `env.labels = {}` and the dep `plotLabel = function(plotId) return env.labels[plotId] end`. "Other" companies are claimed directly on `env.plots` (as the existing teleport test does).

| Test case file | Test name | Asserts |
|---|---|---|
| PlotService_Test | claimExact claims a free plot and refuses a taken or unknown one | free → id; holder's second call with another id → its first plot; taken → `nil, "PlotTaken"`; `"Plot_09"` → `nil, "UnknownPlot"`; no state change on refusals |
| PlotService_Test | plotIds and has list the configured plots | order equal to the input, a copy (mutating it changes nothing); `has` true/false, false for a number |
| SaveProfile_Test | accepts an optional lastPlotId string | nil and `"Plot_03"` validate; `5`, `""` and a 33-byte string fail |
| Protocol_Test | Save.Play accepts an optional listed plotId | `{saveId, plotId="Plot_03"}` ok; `"Plot_07"`, `"Plot_9"`, `3` → `InvalidPlotId`; `{saveId, plotId, cash}` → `UnexpectedField` |
| Protocol_Test | validates Save.Plots payloads | `{saveId}` ok; `{}` and bad id → `InvalidSaveId`; `{saveId, plotId}` → `UnexpectedField` |
| SaveSlotService_Test | lists every plot with number, side and status | 3 plots, Plot_01 held by `save:77_other`, `env.labels.Plot_01 = "Other Lot"`: `pick`, `total 3`, rows 1–3 numbered, all South, row 1 `free=false name="Other Lot"`, rows 2–3 free without name, `preselectId "Plot_02"`; nothing claimed by the call |
| SaveSlotService_Test | plays a chosen free plot and remembers it | Play `plotId "Plot_03"` → ok, `data.plotId`, `getPlot` = Plot_03; stored entry `lastPlotId == "Plot_03"` |
| SaveSlotService_Test | refuses a taken plot with PlotTaken and changes nothing | Plot_01 held: Play `Plot_01` → `PlotTaken`; 0 loads (wrapped `persistence.load`), no plot, `freeCount` 1, no active save, 0 teleports |
| SaveSlotService_Test | refuses a plot id this server does not hold | 2 plots: `"Plot_05"` → `InvalidPlotId` (service); `"Plot_9"` → `InvalidPlotId` (validator); `freeCount` 2 |
| SaveSlotService_Test | plays the automatic plot without a plot id | Plot_01 held: Play `{saveId}` → `Plot_02` |
| SaveSlotService_Test | the second of two companies choosing one plot gets PlotTaken | user 42 plays on Plot_02; user 43 (own profile): Plots row 2 `free=false`; Play `Plot_02` → `PlotTaken`; Play `Plot_01` → ok |
| SaveSlotService_Test | preselects the last plot when free, else the first free one | 3 plots: play `Plot_03`, `leave(USER)`; Plots → `preselectId "Plot_03"`; Plot_03 claimed by other → `"Plot_01"` |
| SaveSlotService_Test | offers no pick for the active save and frees its plot for a switch | A plays on Plot_01: Plots A → `pick=false`, empty rows; Plots B → row 1 free; Play `{B, Plot_01}` → ok on Plot_01, active = B |
| SaveSlotService_Test | a taken plot with none free takes the teleport path | 1 plot held: Plots → `pick=false`; Play `Plot_01` → `NoFreePlotTeleporting`, 1 teleport with attempt 1 |
| SaveSlotService_Test | a teleport arrival carries its attempt into the chosen play | 2 plots held: `noteArrival(USER, saveId, 2)`; Play `Plot_01` → teleport attempt 3; `noteArrival(…, 3)`; Play → `NoFreePlot`, no new teleport |
| SaveSlotService_Test | rate-limits Save.Plots like the other save actions | `limit` calls ok, the next → `RateLimited` (fixed clock) |
| SaveSlotService_Test | a plot taken during the switch gives PlotTaken and loads nothing | A on Plot_01 (2 plots); deactivation handler replaced by one that claims Plot_01 for `save:77_other`; Play `{B, Plot_01}` → `PlotTaken`; no active save, `getPlot(B)` nil, holder of Plot_01 is the other, 0 loads of B |
| CoopSave_Test | a teammate of a save that holds a plot attaches without a pick | `coopSave`; FRIEND joins; FRIEND `Save.Plots` → `pick=false`; FRIEND Play `{saveId, plotId = a plot ≠ save.plotId}` → ok, `data.plotId == save.plotId`, the other plot still free |
| UiTheme_Test | fits the plot picker on every screen | every MATRIX size: panel and confirm inside the screen; panel children inside the panel, confirm children inside the confirm; Prev, Next, Back, Choose, Yes, No ≥ 44 × 44; no two panel children overlap, Yes/No/ConfirmText do not overlap |

Localization_Test covers the new keys in both languages (no new case).

## Playtest (Studio, via playtester; now: tier L)
1. Rojo sync, BUILD `cm2-pp`; Play (Server + Client, Studio API access on). Unit runner `require(ServerStorage.UnitTest.RunUnitTest)(nil, 10)` → 656 PASS.
2. `runPlaytest {mode="full"}` → **66/66 PASS**; record the step 65 detail.
3. Manual picker (client UI, real input through the MCP; a check the MCP cannot drive is BLOCKED, never PASS). After the run: `StudioTestHook:Invoke("shadowJoin")` → note the shadow plot `Ps`; R is on "Playtest A" on plot `Pr`. Open Saves, create "PP Manual", press its Start →
   a. `PlotPickerUI` attribute `Open == true`, `SavePickerUI.Picker.Visible == false`, `CurrentCamera.CameraType == Scriptable`, rail hidden; `PlotNumber` "Plot N of 6" with N = the lowest free plot number (no last plot yet; `Pr` counts as free).
   b. D / Right ×6 and the ▶ button: N steps 1…6 and wraps; A / Left and ◀ go back; after each step (wait 0.8 s) the camera position is within 2 studs of `(x, 55, z + facing·60)` of that plot (`MapLayout.PLOTS`).
   c. On `Ps`: status "Occupied – Home of <the shadow sign text>", `Choose.Active == false`, Enter opens no confirm. Every other plot: "Available – south/north side of the road" matching its number.
   d. On a free plot ≠ `Pr`: Choose → `Confirm` "Choose plot N?"; No hides it; Choose → Yes → within 5 s `PlotId` = that plot, `ActiveSaveId` = PP Manual, camera `Custom` with the Humanoid as subject, character root within 10 studs of that plot's `Spawn`, `Open == false`, rail visible.
   e. Back: Saves → Start on "Playtest A" → picker opens (A holds no plot now) → Back → save picker visible, camera `Custom`, still on PP Manual.
   f. Gamepad (Controller Emulator if available): L1/R1 browse, A opens the confirm, B closes it.
4. Device Simulator, phone landscape (e.g. iPhone 13, 844 × 390) and tablet (iPad 1024 × 768): open the picker; `AbsoluteSize` of `Prev`, `Next`, `Back`, `Choose` and, after Choose on a free plot, `Yes`, `No` ≥ 44 px both ways and inside the `PlotPickerUI` `AbsolutePosition`/`AbsoluteSize` box; a screen capture of each (if the capture is black, the known limit, record the numbers).
5. Cleanup: play "Playtest A" through the picker or `saveAction Save.Play {saveId}`; delete "PP Manual" (`saveAction Save.Delete`); `shadowLeave`.
Teleport arrival (`PlotPickSaveId`) stays BLOCKED in Studio (TeleportService); covered headless.

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (656 run, 0 failed), `rojo build` (both project files).
- Backlog (a): the 12 SaveSlotService cases, the CoopSave case and the Protocol cases above; "rate-limited like the other save actions" = the Save.Plots rate-limit case. (b): playtest 3a–3e and 66/66. (c): playtest 4 plus the UiTheme case. (d): checks and the 15 keys in `Localization.lua` (en and de).
- No change to company records, `SaveProfile.VERSION`, money, inventory or purchases.

## Out of scope
Plot choice in `Save.FinderStart`, `Save.Teleport` arrivals and Studio hooks (automatic as today); reserving a plot while browsing; CM2-UI look work; changing `MaxPlotTeleports`.

## Amendment 1 (2026-11-26, after the Studio run: 65/66, `54 TUTORIAL_FLOW` "rejoin failed: SaveActionBusy")
**Cause (from code): playtest timing, not a CM2-PP defect.**
- The `rejoin` hook calls `saveSlots:play(userId, saveId, {reload = true})`. `SaveActionBusy` there means only one thing: the per-player `_busy` gate (SaveSlotPicker.lua ~587) is held by another save action of R.
- CM2-PP does not touch that path. Without `plotId`, `_play` skips the refusal and exact-claim branches. `_touch` writes one more field in the same `UpdateAsync`. The `_arrivals` map, `PlotPickSaveId`, `PlotPicker` and the new SavePicker code send no request unless the picker is open or `PlotPickSaveId` is set (neither happens in step 54). Steps run in install order, so 65 runs after 54.
- The other holder is the client. The reload's `_deactivated` sets `ActiveSaveId = nil`, so SavePicker opens and sends `Save.List`. It gets `SaveActionBusy`, and `SaveListSync` retries every 1 s (up to 10) until `CompanyReady = true` closes the picker.
- A retry arriving just after a reload holds the gate while `_listView` yields (`_nameOf`, locator lookups). Step 54 runs two rejoins close together; Studio store latency decides whether a retry lands between them. Steps 19, 39, 42, 51 and 60 share the exposure. Possible since CM2-SP1; intermittent.
- This is not a game defect. `play {reload = true}` exists only in the Studio hook. In the game the gate serializes save actions on purpose (CM2-SP1), the client retries busy answers, and a real rejoin (`leave(final)`) waits until the gate is free.

**A1. `tests/studio/Playtest/Support/Base.lua`: helper `rejoin(userId: number): any`**
- Constants next to `ACTION_PAUSE`: `REJOIN_TRIES = 20`, `REJOIN_PAUSE = 0.5`.
- Call `invoke("rejoin", userId)`. While the response is a table with `errorCode == "SaveActionBusy"` and fewer than `REJOIN_TRIES` calls have been made: `task.wait(REJOIN_PAUSE)`, then call again.
- If it waited at least once: `emit(string.format("NOTE rejoin waited %d time(s) on SaveActionBusy", waits))`.
- Then `check(type(response) == "table" and response.ok == true, string.format("rejoin failed: %s", tostring(type(response) == "table" and response.errorCode or response)))`, the same text `call` prints, and return `response.data`.
- Comment: `-- Studio rejoin; retries SaveActionBusy from the client's Save.List retries (CM2-PP A1).`
- Register `ctx.rejoin = rejoin` next to `ctx.call`.

**A2. Call sites.** Replace each `call("rejoin", R.userId)` with `rejoin(R.userId)`, adding `local rejoin = ctx.rejoin` to each module's locals: Core.lua (step 19), Npc.lua (39), Reviews.lua (42), Shop.lua (51), DayNight.lua (60), Tutorial.lua (54, both). If `call` is left unused in a module, remove its local (selene).

**A3. Build.** `RunPlaytest.BUILD = "cm2-pp-a1"`; TEST_PLAN §3b: BUILD `cm2-pp-a1`. No change to `src/` and no headless change: the total stays **656**.

**Manual finding (short phone 780 × 281, Confirm y 8–128 over Panel y 39–215): accepted, no change.**
- Confirm covers only Title, PlotNumber and PlotStatus; browsing is off while confirming and the confirm text repeats the number. Prev/Next are outside its x range, Back/Choose below it; every button stays visible, ≥ 44 px, on screen.
- iPhone 17 Pro and iPad have no overlap. Record it in PROGRESS as an accepted limit for the CM2-UI look pass.

**Implementer for this amendment:** tier S (playtest helper and call sites only, no game code). The task stays tier L.

**Playtest (this round)**
- Unit runner 656 PASS.
- `runPlaytest {mode="full"}` gives **66/66 PASS**.
- Record every `NOTE rejoin waited` line in PROGRESS. A line with n > 0 confirms the cause.
- If 54 (or another rejoin step) still fails with `SaveActionBusy` after 20 tries (about 10 s), the cause is not the list retry chain. That result is a defect and goes back to `planner-high` with the step's line.
- Manual checks 3–4 are not repeated (no game or UI change).

**Acceptance delta:** stylua, selene, headless 656/656, rojo build. Only `tests/studio/Playtest/` and TEST_PLAN change.

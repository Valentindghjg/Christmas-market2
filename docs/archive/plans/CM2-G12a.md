# CM2-G12a — Day/night cycle and day counter (per save, schema 20)

Written by: `planner` (Opus 5.5, high). Implemented by: the agent for the tier below. Playtested by: `playtester` (Sonnet 5.5, medium). Reviewed and committed by: `reviewer` (Opus 5.5, medium). Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.
Split: launch order 17 (CM2-G12, covers CM2-36 part) = **CM2-G12a** (this plan: day/night, day counter, night arrivals, lights) + **CM2-G12b** (`docs/plans/CM2-G12b.md`: four leaderboards). G12b does not depend on G12a; run G12a first.

## Goal
Every save has its own game day of 18 minutes (12 min day, 6 min night) that runs only while the save is loaded. The HUD shows "Day N" from the server, the sky follows the save's clock on each client, fewer customers arrive at night and street lamps and plot lights glow at night.

## Source of truth
PRODUCT_SPEC owner decisions 2026-11-21 "Day/night"; DECISION_LOG 2026-11-21 (18 min = 12 + 6); REFERENCE_GAME_LIVE_TEST §8 "Time", §9 "Style"; backlog CM2-G12 and launch order 17; MODEL_INTEGRATION "Map layout (CM2-10)" lamp positions and "Map art (CM2-10b)" (`LampPost` attachment `Light` (0, 8.15, 0) "for the PointLight (CM2-G12)"); CM2-47a note: the HUD day chip waits for a server value.

## Implementer tier
Tier: L. Reason: save schema 19 → 20 with migration and validation, a new per-save timer that persists through the session/save path.

## Skills to load
roblox-collaboration-mode, roblox-data, roblox-server-data, roblox-lighting, roblox-performance, roblox-npc-ai, roblox-luau-core, roblox-luau-types, roblox-architecture.

## Decisions (engineering, record in DECISION_LOG)
| Topic | Decision |
|---|---|
| Whose clock | One clock per save (`state.dayCycle`), not per server. 6 saves on a server can be at different times; each client shows its own active save's sky. A player without an active save sees `DefaultClockTime` 14. |
| When it runs | Only while the save's session is healthy and not unloading (same rule as Cash Rush, CM2-46a). No offline progress. |
| New and migrated saves | Day 1, elapsed 0 (dawn). |
| Night customers | Arrival credit per company: each arrival pass adds `DayCycle.arrivalRate` (1 by day, 0.5 at night, PROVISIONAL), an arrival needs credit 1. By day behaviour is exactly today's (one try per pass). |
| Lights | Tag `NightLight` on server-created lights, `Enabled = false` on the server; the client enables them while `DayCycle.lightsOn`. Lamp posts get a Part fallback (they were skipped since CM2-10W) so the street has lights before PC-2. |
| Lighting writes | Client only (`Lighting.ClockTime`, `Lighting.OutdoorAmbient`), 2 Hz. The server never writes `Lighting`. |

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/DayCycle.lua` | New | pure clock maths (step 1) |
| `src/shared/GameConfig.lua` | Change | `GameConfig.DayCycle` (Data) |
| `src/shared/BusinessState.lua` | Change | schema 20, `dayCycle` (step 2) |
| `src/server/Services/CompanyDayCycle.lua` | New | mixin: tick, view, arrival rate, test setter (step 3) |
| `src/server/Services/CompanyStateService.lua` | Change | install mixin, summary, snapshot (step 4) |
| `src/server/Services/CustomerNpcService.lua` | Change | arrival credit (step 5) |
| `src/shared/MapLayout.lua` | Change | `LampPost` fallback `"Lamp"` (step 6) |
| `src/server/Services/MapWorld.lua` | Change | Lamp fallback and lamp light (step 6) |
| `src/server/Services/WorldService.lua` | Change | plot lights (step 7) |
| `src/server/main.server.lua` | Change | wiring (step 8) |
| `src/server/Services/StudioTestService.lua` | Change | `setDay`, `dayView` (step 9) |
| `src/client/DayNight.client.lua` | New | sky and lights (step 10) |
| `tests/headless/run.luau` | Change | register `DayCycle` (sourcePaths) and `CompanyDayCycle` (services) |
| `tests/studio/Cases/DayCycle_Test.lua` | New | 15 tests |
| `tests/studio/Cases/CustomerNpcService_Test.lua` | Change | 2 tests |
| `tests/studio/Cases/MapLayout_Test.lua` | Change | fallback 7 → 8, skip 6 → 5 (missing stays 13) |
| `tests/studio/Cases/BusinessState_Test.lua` (lines 184, 203), `SaveMigration_Test.lua` (372, 391), `Tutorial_Test.lua` (147, 164) | Change | literal schema `19` → `20` only |
| `tests/studio/Playtest/Steps/DayNight.lua` | New | steps 60, 61 |
| `tests/studio/Playtest/Support/Fixtures.lua` | Change | preflight resets the clock |
| `tests/studio/Playtest/RunPlaytest.lua` | Change | install `DayNight` after `Progression`; `BUILD = "cm2-g12a"` |
| `docs/TECHNICAL_ARCHITECTURE.md`, `docs/MODEL_INTEGRATION.md`, `docs/DECISION_LOG.md` | Change | step 11 |

## Data and config
`GameConfig.DayCycle` (new section, after `GameConfig.Customers`):
| Key | Value | Tag |
|---|---|---|
| `DaySeconds` | 720 | OWNER DECIDED |
| `NightSeconds` | 360 | OWNER DECIDED |
| `DayStartClockTime` | 6 | PROVISIONAL |
| `NightStartClockTime` | 18 | PROVISIONAL |
| `NightArrivalRate` | 0.5 | PROVISIONAL |
| `TwilightSeconds` | 30 | PROVISIONAL |
| `TickSeconds` | 1 | engineering |
| `MaxTickSeconds` | 5 | engineering (a longer server hitch counts as 5 s) |
| `SyncSeconds` | 30 | engineering |
| `ClientUpdateSeconds` | 0.5 | engineering |
| `DefaultClockTime` | 14 | PROVISIONAL |
| `NightOutdoorAmbient` | `{ 70, 80, 110 }` | PROVISIONAL |
| `NightLightTag` | `"NightLight"` | engineering |
| `LampLight` | `{ range = 16, brightness = 1.5 }` | PROVISIONAL |
| `PlotLight` | `{ range = 14, brightness = 1.2 }` | PROVISIONAL |

Save field (schema 20): `dayCycle = { day: integer >= 1, elapsed: number, 0 <= elapsed < DaySeconds + NightSeconds }`.
Player attributes (server → client, set by main): `DayNumber` (integer), `DayElapsed` (number, rounded to 0.1), `DaySyncAt` (`workspace:GetServerTimeNow()` at the write). All three nil without an active save.

## Steps
1. **`src/shared/DayCycle.lua`** (`--!strict`, requires only `GameConfig`). `export type Cycle = { day: number, elapsed: number }`. Let `L = DaySeconds + NightSeconds`, `D = DaySeconds`, `T = TwilightSeconds`.
   - `new(): Cycle` → `{ day = 1, elapsed = 0 }`. `length(): number` → `L`.
   - `isValid(value: any): boolean` → table; `day` finite integer ≥ 1; `elapsed` number, not NaN, `0 <= elapsed < L`.
   - `normalize(state: any)` → only when `state.dayCycle` is a table whose `elapsed` is a finite number ≥ `L`: `elapsed = elapsed % L` (day unchanged). Nothing else.
   - `advance(cycle: Cycle, seconds: number): number` → returns days added. `seconds` NaN, infinite or ≤ 0 → 0 and no change; else `math.min(seconds, MaxTickSeconds)` is added; while `elapsed >= L`: `elapsed -= L`, `day += 1`.
   - `isNight(elapsed): boolean` → `elapsed >= D`. `arrivalRate(elapsed): number` → `NightArrivalRate` at night, else 1.
   - `clockTime(elapsed): number` → day: `DayStartClockTime + (NightStartClockTime - DayStartClockTime) * elapsed / D`; night: `(NightStartClockTime + (24 - (NightStartClockTime - DayStartClockTime)) * (elapsed - D) / NightSeconds) % 24`.
   - `nightBlend(elapsed): number` → `elapsed < T`: `1 - elapsed / T`; `elapsed < D`: 0; else `math.min(1, (elapsed - D) / T)`. `lightsOn(elapsed): boolean` → `nightBlend(elapsed) > 0`.
   - `extrapolate(syncElapsed: number, syncAt: number, now: number): number` → `(syncElapsed + math.max(0, now - syncAt)) % L`.
2. **BusinessState**: `require(script.Parent.DayCycle)`; `SCHEMA_VERSION = 20`; `new()` adds `dayCycle = DayCycle.new()`; `migrate`: after the 18 → 19 block add `if state.schemaVersion == 19 then state.schemaVersion = 20; -- Schema 20 (CM2-G12a): the save's game day; state.dayCycle = DayCycle.new() end`; in the current-schema branch call `DayCycle.normalize(state)` after `Purchases.normalize(state)`; the legacy v1 path sets `state.dayCycle = DayCycle.new()` after `state.tutorial`; `validate` adds `if not DayCycle.isValid(state.dayCycle) then return false end` after the Tutorial check.
3. **`CompanyDayCycle.lua`** mixin (pattern of `CompanyTutorial.lua`; header comment names CM2-G12a and this plan). `CompanyDayCycle.install(CompanyStateService)` adds:
   - `setDayChangedHandler(handler: (companyId: string) -> ())` → `self._dayChanged`.
   - `_notifyDay(companyId, session)` → pcall the handler when `self._sessions[companyId] == session`; on error `warn("[ChristmasMarket2] day notify failed for %s: %s")`.
   - `tickDayAll(seconds: number): (boolean, number, number)` → like `tickBoostsAll`: every session with `healthy and not unloading`, inside `_withSession`: `local added = DayCycle.advance(state.dayCycle, seconds)`; if `added > 0`: `session.dirty = true` (no revision). After the section, `_notifyDay` for each company with `added > 0`. Returns `true, <companies rolled>, 0`.
   - `dayView(companyId): { day: number, elapsed: number, night: boolean, arrivalRate: number }?` → nil unless `self:isAvailable(companyId)`; read-only, no `_withSession`.
   - `arrivalRate(companyId): number` → `DayCycle.arrivalRate(elapsed)` of an available session, else 1.
   - `setDayForTest(companyId, day: number?, elapsed: number): boolean` (Studio instrument only) → false unless the session is healthy, `day` is nil or an integer ≥ 1, and `0 <= elapsed < DayCycle.length()`; sets `state.dayCycle = { day = day or current, elapsed = elapsed }`, `session.dirty = true`, then `_notifyDay`; true.
4. **CompanyStateService**: require `DayCycle` (Shared) and `CompanyDayCycle`; `CompanyDayCycle.install(CompanyStateService)` after `CompanyProgression.install`. `Company.GetSummary` data gains `day = state.dayCycle.day, night = DayCycle.isNight(state.dayCycle.elapsed),`. `snapshotForTest` gains `dayCycle = table.clone(state.dayCycle), -- CM2-G12a`.
5. **CustomerNpcService**: deps comment adds `arrivalRate?(companyId) -> number`. `new`: `self._arrivalRate = deps.arrivalRate`, `self._arrivalCredit = {}`. `arrivalPass`: first build the set of `liveCompanyIds()` and delete `_arrivalCredit` entries not in it. Inside the existing `if not paused and self:_hasRoom(plotId) then` branch, before the override logic: `rate` = 1, or the pcall result of `self._arrivalRate(companyId)` when it is a non-NaN number, clamped to [0, 1]; `credit = math.min(1, (self._arrivalCredit[companyId] or 1) + rate)`; if `credit >= 1 - 1e-9` run the existing override/normal arrival unchanged and on success `credit -= 1`; store `self._arrivalCredit[companyId] = credit`. Nothing else changes (`spawnForTest` and load tests bypass the credit).
6. **Lamps**: `MapLayout.ART["Props/LampPost"].fallback = "Lamp"`. MapWorld `FALLBACKS.Lamp(kit, parent, piece, pivot)`: `newModel`; `offsetPart` `Post` (0.5, 7.6, 0.5) at (0, 3.8, 0) `MetalDark` SmoothPlastic; `Lantern` (1, 1, 1) at (0, 8.15, 0) `LightWarm` `Enum.Material.Neon`, `CanCollide = false`; `Cap` (1.3, 0.25, 1.3) at (0, 8.775, 0) `MetalDark` SmoothPlastic, `CanCollide = false`; `PrimaryPart = Post`. New local `addLampLight(model)` called in `placePiece` when `piece.artPath == "Props/LampPost"` (both modes): parent = the descendant `Attachment` named `Light` (art), else the part `Lantern` (fallback), else `model.PrimaryPart`; creates `PointLight` named `NightLight`, `Range`/`Brightness` from `GameConfig.DayCycle.LampLight`, `Color` = palette `LightWarm`, `Shadows = false`, `Enabled = false`, `CollectionService:AddTag(light, GameConfig.DayCycle.NightLightTag)`.
7. **Plot lights** (WorldService): in `checkout()` a `PointLight` named `NightLight` under `Register`; in `lotSign()` one under `Cap`. Both: `PlotLight` range/brightness, `LightWarm` colour, `Shadows = false`, `Enabled = false`, tagged `NightLight`. Use one local helper `nightLight(parent: Instance, spec)`.
8. **main.server.lua**:
   - npc deps: `arrivalRate = function(companyId: string): number return companies:arrivalRate(companyId) end,`.
   - Local `pushDay(companyId: string)`: `view = companies:dayView(companyId)`; nil → return; for each `userId` in `saveSlots:playersOn(companyId)` with a player: set `DayNumber = view.day`, `DayElapsed = math.floor(view.elapsed * 10 + 0.5) / 10`, `DaySyncAt = workspace:GetServerTimeNow()`.
   - `companies:setDayChangedHandler(pushDay)`.
   - Activation handler: call `pushDay(companyId)` right after the `TutorialStep` attribute line (before `CompanyReady = true`). Deactivation handler: set `DayNumber`, `DayElapsed`, `DaySyncAt` to nil next to `TutorialStep`.
   - Day loop (its own loop, not `every`, because it uses the measured wait): `task.spawn(function() while true do local dt = task.wait(config.DayCycle.TickSeconds); local ok, err = pcall(companies.tickDayAll, companies, dt); if not ok then warn(string.format("[ChristmasMarket2] day tick errored: %s", tostring(err))) end end end)` placed after the `boosts` loop.
   - `every(config.DayCycle.SyncSeconds, "day sync", function() local ids = companies:liveCompanyIds(); for _, id in ids do pushDay(id) end; return true, #ids, 0 end)`.
9. **StudioTestService**: `commands.setDay(arg)` — `arg = { userId, day?, elapsed }`, BadArgument unless `userId` and `elapsed` are numbers; NoActiveSave; `Refused` when `setDayForTest` returns false; else `success(companies:dayView(companyId))`. `commands.dayView(arg)` — `arg` = userId → `success(view)` or `failure("NoActiveSave")`.
10. **`src/client/DayNight.client.lua`** (`--!strict`, header names CM2-G12a): reads `Lighting.OutdoorAmbient` once as the day ambient; night ambient from `NightOutdoorAmbient`. Loop every `ClientUpdateSeconds` (`task.wait`): if `DayElapsed` and `DaySyncAt` are numbers → `e = DayCycle.extrapolate(DayElapsed, DaySyncAt, workspace:GetServerTimeNow())`, `Lighting.ClockTime = DayCycle.clockTime(e)`, `Lighting.OutdoorAmbient = day:Lerp(night, DayCycle.nightBlend(e))`, `on = DayCycle.lightsOn(e)`; else `ClockTime = DefaultClockTime`, day ambient, `on = false`. Only when `on` differs from the last value: set `Enabled = on` on every tagged `Light` (`CollectionService:GetTagged`). `GetInstanceAddedSignal(tag)` sets `Enabled = on` on streamed-in lights. Writes `ClockTime`/`OutdoorAmbient` only when the value changed by more than 0.001 / any channel.
11. **Docs**: TECHNICAL_ARCHITECTURE §5 one bullet "Day cycle (CM2-G12a)": schema 20 field, runs only in healthy loaded sessions, rollover marks dirty without revision, attributes `DayNumber/DayElapsed/DaySyncAt`, client-only Lighting. MODEL_INTEGRATION "Map in the world (CM2-10W)" Missing-art line: move LampPost to the Part fallbacks (`Lamp`); add "Night lights (CM2-G12a): every lamp and each plot's checkout and lot sign carry a `NightLight` PointLight tagged `NightLight`, off on the server." DECISION_LOG entry "2026-11-23 - Day/night per save (CM2-G12a, engineering)" with the Decisions table rows.

## Tests (headless)
| Test case file | Test name | Asserts |
|---|---|---|
| DayCycle_Test | new starts on day 1 at dawn | `new()` = {1, 0}, `isValid` true, `length()` 1080 |
| DayCycle_Test | isValid rejects broken cycles | false for nil, `{day=0}`, `day=1.5`, `elapsed=-1`, `elapsed=1080`, `elapsed=0/0` |
| DayCycle_Test | advance rolls into the next day | {1, 1078} + 4 → returns 1, {2, 2} |
| DayCycle_Test | advance ignores bad seconds and clamps | 0, -3, NaN, `math.huge` → 0 added, cycle unchanged; 100 → elapsed +5 |
| DayCycle_Test | night split and arrival rate | `isNight(719.9)` false, `(720)` true, `(1079)` true; `arrivalRate` 1 / 0.5 |
| DayCycle_Test | clockTime maps day and night | 0 → 6, 360 → 12, 720 → 18, 900 → 24 % 24 = 0, 1080-1e-6 ≈ 6 (±0.01), 810 → 21 |
| DayCycle_Test | nightBlend and lightsOn ramp | 0 → 1, 15 → 0.5, 30 → 0, 400 → 0, 735 → 0.5, 800 → 1; `lightsOn(400)` false, `(800)` true |
| DayCycle_Test | extrapolate wraps | (1070, 100, 115) → 5; now < syncAt → syncElapsed |
| DayCycle_Test | migrates schema 19 to 20 | schema-19 record (dayCycle nil, cash 4321) → schema 20, dayCycle {1, 0}, cash 4321, validates; v1 record → dayCycle {1, 0} |
| DayCycle_Test | validate and normalize | schema-20 record with `dayCycle=nil` or `{day=0}` fails validate; with `elapsed=2000` → `migrate` returns it with elapsed 920, day unchanged |
| DayCycle_Test | tickDayAll runs only loaded saves | load A and B, unload B, `tickDayAll(3)` → A 3, B unchanged; unload A (fake persistence), reload → elapsed 3 |
| DayCycle_Test | rollover marks dirty and notifies once | after `flushDirty(true)`: tick 2 → `isDirty` false, no call; set elapsed 1079 via `setDayForTest` + flush; tick 2 → dirty, handler called once with A, day 2 |
| DayCycle_Test | arrivalRate and dayView follow the phase | elapsed 100 → 1, view.night false; 800 → 0.5, night true; unknown company → rate 1, view nil |
| DayCycle_Test | summary carries the day | `handle(A, 42, Company.GetSummary)` → `data.day` 1, `data.night` false; after `setDayForTest(A, 4, 900)` → 4, true |
| DayCycle_Test | setDayForTest validates | day 0, day 1.5, elapsed -1, elapsed 1080 → false and unchanged; valid → true and handler called |
| CustomerNpcService_Test | night arrival rate halves arrivals | harness with `arrivalRate` → 0.5, 4 trees: 4 `arrivalPass()` calls (no ticks in between) spawn 1, 0, 1, 0 |
| CustomerNpcService_Test | a refused arrival keeps its credit | rate 0.5, 0 trees: 2 passes spawn 0; add 2 trees; next pass spawns 1 |

Expected: `lune run tests/headless/run.luau` **585 run, 0 failed** (568 + 17). The harness change in CustomerNpcService_Test: `harness()` passes `arrivalRate = function() return h.rate or 1 end` in deps; existing tests leave `h.rate` nil.

## Playtest (Studio, via playtester; now: tier L, saves, world geometry)
1. Rojo sync, live source `BUILD = "cm2-g12a"`; Play; `runPlaytest {mode="full"}` → **62/62** (60 + 2).
2. Step 03 PREFLIGHT (Fixtures `preflight`): right after `resetCustomers()` call `call("setDay", { userId = R.userId, elapsed = 0 })`, and for the shadow when joined the same with `S.userId`; `check` both responses `ok`.
3. Step **60 DAY_CYCLE** (`Steps/DayNight.lua`, needs {"03"}): every `setDay`/`dayView` call passes `userId = R.userId` (shown without it below). (a) `setDay {elapsed = 719}`; poll ≤ 4 s until `dayView(R).night`; `arrivalRate == 0.5`; the real player's `DayNumber == view.day`, `DayElapsed >= 719`, `DaySyncAt` a number. (b) `actOk(R.userId, "Company.GetSummary", {})` → `data.day == view.day`, `data.night == true`. (c) `setDay {elapsed = 1079}`; poll ≤ 5 s until `dayView.day == before + 1` and `elapsed < 6`; `DayNumber` attribute equals it within 2 s. (d) `call("flush")`, `call("rejoin", R.userId)`, then `snap(R.userId).dayCycle.day` equals the rolled day. (e) `setDay {elapsed = 0}`; detail `day N, night rate 0.5, rolled to N+1, persisted`.
4. Step **61 NIGHT_LIGHTS** (needs {}): `CollectionService:GetTagged("NightLight")` holds exactly 34 `Light` instances (22 lamps + 6 × 2 plot lights), all `Enabled == false` on the server; each `Map.Square/Street.Lamp_01..22` holds exactly one; `Map` holds 22 models with `MapPiece` matching `^Lamp_%d%d$`.
5. Step 56 MAP_WORLD still PASS (lamp fallbacks counted by the plan, no part in car/truck lanes).
6. Queue in "Studio-Test ausstehend" (PC-7; phone also PC-4): on a real client, (1) after `setDay {elapsed=300}` the client's `Lighting.ClockTime` is `DayCycle.clockTime` ±0.1 and tagged lights are off; after `setDay {elapsed=900}` within 0.1 of 0 (or 24) and lights on; (2) HUD `DayLabel` reads "Day N" = `DayNumber` within 6 s; (3) captures of the village square and the player's plot at elapsed 300 and 900; (4) desktop: mean ≥ 55 FPS from `RenderStepped` over 60 s starting at elapsed 700 (spans dusk); (5) phone emulator 667x375 (PC-4): mean ≥ 30 FPS and no frame > 100 ms over the same 60 s.

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (585 run, 0 failed), `rojo build default.project.json` and `release.project.json`.
- Studio full run 62/62 on BUILD `cm2-g12a`, steps 60 and 61 PASS, server-side only.
- Backlog: the day counter advances only while a save is played (headless "tickDayAll runs only loaded saves" + step 60 d); fewer customers at night (headless arrival tests); the cycle without frame drops on the mobile emulator → queued (PC-4, PC-7).

## Out of scope
Leaderboards (CM2-G12b). Weather, snow particles, Atmosphere or post-processing changes. Night effects on prices or staff energy. Lamp art import (PC-2). A night indicator in the HUD.

# CM2-A1 — Advent calendar

Written by `planner-high`; implemented by `implementer-opus`; pipeline `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
Dec 1–24 (server UTC date) a player opens one Advent door per day, missed doors until Dec 24, from an "Advent" rail panel; each door pays once per player into the active save.

## Source of truth
Backlog 19; PRODUCT_SPEC "Advent calendar"; DECISION_LOG archive 2026-11-21 (UTC), 2026-11-23 (rail slot 40); plan CM2-G11 (Daily.Claim pattern); PC-13.

## Implementer tier
Tier: L. Reason: schema 22 migration, a new profile field, money/boost/decor grants, a new rate-limited action, once per player across saves.

## Skill checks
- data: profile writes only via `_updateProfile` (UpdateAsync) = once-only guard; revert clears only its own bit; validation fails closed.
- networking/security: payload exactly `{door}` 1..24; rewards from config only; rate limit + in-flight guard; never via `companies:handle`.
- game-design: rewards are not revenue (no multiplier); values PROVISIONAL.
- gui/input: doors >= `MinTouch`, inside the panel at 666x374; server attributes only; one request in flight.
- localization: full-sentence EN/DE keys, no fragments.
- luau: `--!strict`, NaN/inf checks; dates by integer maths, never `os.date`/`os.time(table)` (time zones differ in Lune).
- architecture/tooling: pure shared core, one owning service; new modules registered in `run.luau`.

## Design decisions (DECISION_LOG entry, step 12)
| Topic | Decision |
|---|---|
| Opened doors | Profile `advent = {year, opened}`, bit d-1 = door d; another `year` counts as empty; so one payment per player across saves and servers. |
| Window | UTC date Dec 1..24 -> `Open`, today = day; before Dec 1 -> `Before`; Dec 25..31 -> `Ended`; today = 0 outside `Open`. |
| Claim order | As Daily.Claim: validate, rate limit, in-flight guard, active available save, profile UpdateAsync sets the bit, save still active, `grantReward`; refused -> clear the bit; revert failed -> `warn` (lost at most once, never paid twice). |
| Decor | No decor system yet: decor goes into a new save map `decorInventory` (the "decor crate"), consumed by CM2-32/33. |
| Boost | Cash Rush seconds (`purchases.boosts.CashX2`) clamped at `BoostCapSeconds`; excess dropped. |
| Studio date | `AdventService:setNowForTest(at?)` overrides only the calendar's time, not the business clock. |

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/AdventCalendar.lua`, `src/server/Services/AdventService.lua`, `src/client/AdventPanel.lua`, `tests/studio/Playtest/Steps/Advent.lua` | New | Steps 1, 7, 11, Playtest |
| GameConfig, BusinessState, SaveProfile, Protocol, Localization, UiTheme, CompanyQuests, CompanyStateService, SaveSlotService, StudioTestService, `main.server.lua`, UiController, `run.luau`, `Cases/*`, RunPlaytest, docs | Change | All steps |

## Data and config
`GameConfig.Advent` (after `DailyRewards`; StyLua-formatted):
```lua
GameConfig.Advent = {
	Month = 12, LastDay = 24, -- OWNER DECIDED (PRODUCT_SPEC): Dec 1-24, server UTC date
	OpenLimit = { limit = 24, window = 60 }, -- PROVISIONAL: a late joiner opens all 24
	RefreshSeconds = 30,
	DecorMaxCount = 999,
	DecorItems = { "AdventWreath", "AdventStarLantern", "AdventCandyLamp", "AdventSnowman", "AdventGingerbreadHut", "AdventReindeerSleigh" },
	Doors = { -- PROVISIONAL; specials Dec 6, Dec 24
		{ cash = 500 }, { reputation = 100 }, { cash = 750 }, { boostSeconds = 900 }, { decor = "AdventWreath" },
		{ cash = 3000, reputation = 250, decor = "AdventStarLantern" },
		{ cash = 1000 }, { reputation = 200 }, { cash = 1250 }, { boostSeconds = 1200 }, { decor = "AdventCandyLamp" },
		{ cash = 1500 }, { reputation = 300 }, { cash = 1750 }, { boostSeconds = 1800 }, { decor = "AdventSnowman" },
		{ cash = 2000 }, { reputation = 400 }, { cash = 2500 }, { boostSeconds = 2400 }, { decor = "AdventGingerbreadHut" },
		{ cash = 3000 }, { reputation = 500 },
		{ cash = 10000, reputation = 1000, decor = "AdventReindeerSleigh" },
	},
}
```
- Profile (no version bump, as `daily`): optional `advent = {year: int 2000..9999, opened: int 0..2^24-1}`.
- Save, schema 22: `decorInventory = {[DecorItems id]: int 1..DecorMaxCount}`; migration 21 -> 22, legacy-v1 path and `new` set `{}`.
- Player attributes: `AdventPhase`, `AdventToday`, `AdventOpened` (this year's mask), `AdventClaimable`.

## Steps
1. **`AdventCalendar.lua`** (`--!strict`, requires GameConfig; `bit32`):
   - `utcTime(year, month, day, hour): number` and `dateOf(now): {year, month, day}` (Hinnant days-from-civil / civil-from-days).
   - `view(advent, now): {year, phase, today, opened, claimable}`; `opened` = stored mask if the year matches, else 0; `claimable` = doors 1..today not opened.
   - `open(advent, now, door): (any?, string?)` in this order: door not integer 1..24 -> `InvalidDoor`; not `Open` -> `CalendarClosed`; `door > today` -> `DoorLocked`; bit set -> `AlreadyClaimed`; else `{year, opened = bor(mask, bit)}`.
   - `rewardFor(door): {cash, reputation, boostSeconds, decor: string?}`.
   - `isValid(advent)`: nil or exactly `year`, `opened` in range; `isDecorInventory(value)` as in Data.
2. **BusinessState**: `SCHEMA_VERSION = 22`; new/migrate/legacy as in Data; `validate` adds `isDecorInventory`. Tests pinning 21 move to 22.
3. **SaveProfile.validate** rejects `not AdventCalendar.isValid(profile.advent)`.
4. **Protocol**: `Actions.AdventOpen = "Advent.Open"` in `actionSet` (comment: via AdventService, never companies:handle); validator: other keys -> `UnexpectedField`; `door` not integer 1..24 -> `InvalidDoor`. Not in `MEMBER_ACTIONS`.
5. **CompanyQuests.grantReward** gets a 6th parameter `extras: {boostSeconds: number?, decorId: string?}?`; kind `AdventReward` added; `InvalidReward` for `boostSeconds` not integer 0..`BoostCapSeconds` or `decorId` not in `DecorItems`. Applies `CashX2 = min(before + s, cap)` and decor `min(old + 1, DecorMaxCount)`; result adds `boostSeconds = after - before` (0 if none), `decorCount` (nil if none).
6. **SaveSlotService** (as the daily trio): `adventOf(userId): (boolean, any?)`; `openAdventDoor(userId, now, door): (number?, string?)` -> `(year, nil)` or `(nil, code)`, `open` inside the transform; `revertAdventDoor(userId, year, door): boolean` clears the bit only while `year` matches and it is set; `setAdventForTest(userId, advent?): boolean`.
7. **`AdventService.lua`** (`--!strict`; structure of DailyRewardService without groups):
   - `new(deps)`: `saveSlots`, `companies`, `clock`, `setAttribute`; limiter (`OpenLimit`, uses `clock()`); `_busy`; `_now()` = `_nowOverride` or `clock()`.
   - `handle`: validate, `UnknownAction`, `RateLimited`, `ClaimBusy`, `pcall(_open)` (error: warn, `InternalError`), clear busy, `refresh`.
   - `_open`: the claim order; success `{ok = true, revision, data = {door, cash, reputation, boostSeconds (applied), decor}}`; warn `"[ChristmasMarket2] advent reward lost for %d (door %d): %s"`.
   - `refresh(userId)` (skip without open profile) sets the 4 attributes from `view`; `refreshAll`; `onPlayerJoined` = `refresh`; `forgetUser`; `setNowForTest(at: number?)`.
8. **main.server.lua**: mirror each `dailyRewards` line for `advent` (create, `every` with `Advent.RefreshSeconds`, join spawn, `forgetUser`, `Advent.Open` branch after Daily.Claim, test context). `snapshotForTest` adds `decorInventory` (clone).
9. **StudioTestService** (errors as `dailySet`): `adventNow {at: int >= 0}` or `{clear = true}` -> `setNowForTest`, `refreshAll`, `success(true)`; `adventSet {userId, clear = true}` or `{userId, opened: int 0..2^24-1}` -> `setAdventForTest(nil or {year of advent:_now(), opened})`, `refresh`, `success(written)`.
10. **UiTheme** `Dialogs.Advent` = `Dialogs.Quests` with `listTop = 64`, `maxWidth = 560`, `maxHeight = 560`. **Localization** (one key per line):

| Key | EN | DE |
|---|---|---|
| adventButton, adventButtonCount | Advent; Advent (%d) | same |
| adventTitle | Advent calendar | Adventskalender |
| adventHint | One door each day until December 24. You can open missed doors until then. | Bis zum 24. Dezember jeden Tag ein Türchen. Verpasste kannst du bis dahin öffnen. |
| adventClose | Close | Schließen |
| adventDoorOpen, adventDoorOpened, adventDoorLocked | Open; Opened; Locked | Öffnen; Geöffnet; Gesperrt |
| adventGotCash | Door %d: you got $%s! | Türchen %d: du hast %s $ bekommen! |
| adventGotReputation | Door %d: you got %d reputation! | Türchen %d: du hast %d Ansehen bekommen! |
| adventGotBoost | Door %d: %d more minutes of Cash Rush! | Türchen %d: %d Minuten mehr Cash Rush! |
| adventGotBoostFull | Door %d: your Cash Rush is already at its maximum. | Türchen %d: dein Cash Rush ist schon auf dem Maximum. |
| adventGotDecor | Door %d: a %s! It waits in your decor crate. | Türchen %d: %s! Es wartet in deiner Deko-Kiste. |
| adventGotSpecial | Door %d: a special gift! $%s, %d reputation and a %s. | Türchen %d: ein besonderes Geschenk! %s $, %d Ansehen und %s. |
| adventErrorLocked | This door opens on December %d. | Dieses Türchen öffnet sich am %d. Dezember. |
| adventErrorClosed | The Advent calendar is closed. | Der Adventskalender ist geschlossen. |
| `decorNameAdvent` + Wreath, StarLantern, CandyLamp | Door Wreath; Star Lantern; Candy Cane Lamp | Türkranz; Sternlaterne; Zuckerstangen-Laterne |
| `decorNameAdvent` + Snowman, GingerbreadHut, ReindeerSleigh | Little Snowman; Gingerbread Hut; Reindeer Sleigh | Kleiner Schneemann; Lebkuchenhütte; Rentierschlitten |

11. **`src/client/AdventPanel.lua`** (`AdventPanel.new(context: LotManager.TabContext)`; UiTheme/UiKit only, QuestPanel pattern):
    - `UiKit.screenGui("AdventUI", 15)`; `addRailButton("AdventButton", "adventButton", 40)`, visible iff `CompanyReady` and phase `Open`; `adventButtonCount` when `AdventClaimable` > 0.
    - Frame `AdventPanel`: `Title` (22), `Hint` (Small, wrapped), `List` ScrollingFrame + `UIGridLayout` (`CellSize = UDim2.new(1/6, -6, 0, 56)`, padding 6, AutomaticCanvasSize Y), `Footer`: `Status`, `CloseButton` (Sand, 120 wide); `UiKit.bindDialog(..., UiTheme.Dialogs.Advent)`.
    - `Door_1`..`Door_24` (TextButton, `LayoutOrder` d; number + `adventDoorOpen`/`Opened`/`Locked`): openable Gold active, opened Sand inactive, locked Row inactive; doors 6, 24 Gold `UIStroke` 2.
    - Tap: doors inactive in flight; `context.request("Advent.Open", {door = d})`; ok -> Status `adventGotSpecial` (decor and cash), `adventGotDecor`, `adventGotBoost` (ceil(applied/60); `adventGotBoostFull` when 0), `adventGotCash` (`formatMoney`), else `adventGotReputation`; `context.refresh()`. Errors: `DoorLocked` `adventErrorLocked`, `CalendarClosed` `adventErrorClosed`, `AlreadyClaimed` `rewardErrorClaimed`, `RateLimited`/`ClaimBusy` `shopErrorBusy`, else `rewardErrorFailed`.
    - Re-render on the 4 attributes and `CompanyReady`; modal `claimModal("Advent", close)`/`releaseModal`; closes when not ready or not `Open`. No auto-open.
    - UiController: `AdventPanel.new(context)` after `QuestPanel.new`.
12. **Docs**: DECISION_LOG (design table); GAME_DESIGN §11; TECHNICAL_ARCHITECTURE §3, §4; TEST_PLAN ADVENT-01/02, full run 72 steps, BUILD `cm2-a1` (and `RunPlaytest.BUILD`); PROGRESS; backlog 19 status note (unticked); line 27 "consumes `decorInventory` (CM2-A1)".

## Tests (headless)
Fixtures as `DailyRewardService_Test`. Times: Dec 1 2026 00:00 = 1796083200; Dec 3 12:00 = 1796299200; Dec 25 00:00 = 1798156800.

| File | Test name | Asserts |
|---|---|---|
| AdventCalendar_Test (new) | converts UTC dates both ways | `utcTime`: the 3 times, 2024-02-29 = 1709164800, 2027-12-02 = 1827705600; `dateOf`: 1796083199 -> 2026-11-30, 1709164800 -> 2024-02-29 |
| | opens on Dec 1 and closes after Dec 24 | Nov 30 23:59:59 `Before`/0; Dec 1 `Open`/1; Dec 24 23:59:59 `Open`/24; Dec 25 `Ended`/0 |
| | rejects a future door and opens missed doors | Dec 3: door 4 `DoorLocked`; doors 1, 3 open, mask 5, claimable 1 |
| | opens each door once per year | door 1 twice `AlreadyClaimed`; `{2025, 1}` on Dec 3 2026 -> door 1 opens, year 2026 |
| | refuses everything outside the window | Dec 25, Nov 30 `CalendarClosed`; door 0, 25, 1.5, NaN `InvalidDoor` |
| | has 24 rising doors of five shapes | each door cash, reputation, boost, decor or special; specials 6, 24; decor in `DecorItems`; cash, rep, boost doors strictly rising |
| | validates the stored field and the decor inventory | ok: nil, `{2026, 0}`, `{}`, `{AdventWreath = 1}`; false: opened 2^24, year 1999, extra key; decor unknown key, 0, 1000, 1.5 |
| AdventService_Test (new) | opens today's door into the active save once | Dec 3 door 1: +500, data `{1, 500, 0, 0, nil}`; again `AlreadyClaimed`; attributes `Open`, 3, 1, 2 |
| | rejects a future door and closes after Dec 24 | door 4 `DoorLocked`; Dec 25, Nov 30 `CalendarClosed`; cash unchanged |
| | pays each door once per player across two saves | door 1 in A; in B door 1 `AlreadyClaimed`, door 2 +100 rep into B only |
| | grants boost, decor and the specials | Dec 6: door 4 CashX2 +900; door 5 `AdventWreath` 1; door 6 +3000, +250, `AdventStarLantern` 1; Dec 10 at cap - 100: door 10 `boostSeconds` 100 |
| | refuses a concurrent open while one is in flight | re-entrant `handle` -> `ClaimBusy`; outer pays once |
| | reverts the door when the save refuses the grant | stub grant `CompanyUnavailable`; bit clear; later open pays |
| | refuses bad payloads, missing saves, direct company calls and floods | `UnexpectedField`; `InvalidDoor`; no save `CompanyUnavailable`; `companies:handle` `Forbidden`; 25th in 60 s `RateLimited` |
| | validates the reward extras | boost -1, 1.5, cap + 1, decor `"Nope"` -> `InvalidReward`, unchanged |
| BusinessState_Test | migrates schema 21 to 22 with an empty decor inventory | v22, `{}`, valid |
| | rejects a bad decor inventory | unknown key or count 0 -> false |
| SaveProfile_Test | validates the advent calendar field | valid, nil, 3 bad shapes |

Expected headless total: 714 + 18 = **732**.

## Playtest (Studio, via playtester)
Now: `runPlaytest {mode = "smoke", only = {"71"}}` -> **14/14 PASS**, BUILD `cm2-a1`. Step **71 ADVENT_CALENDAR** (`Steps/Advent.lua` after `Supplier`, needs `"03"`, player R; body in `pcall`, then always clear `adventNow` and `adventSet`, `pauseCustomers false`, rethrow):
1. `pauseCustomers true`; `adventSet` clear; `adventNow` Dec 3 12:00 (`utcTime`) -> attributes `Open`, 3, 0, 3.
2. Door 4 `DoorLocked`, cash unchanged. Doors 1, 2, 3 ok: cash +1250, reputation +100 exactly; `AdventOpened` 7, claimable 0; door 1 (new request ID) `AlreadyClaimed`.
3. `adventNow` Dec 6 12:00 -> claimable 3; door 6: cash +3000, reputation +250, `decorInventory.AdventStarLantern` +1.
4. `flush`, `rejoin` -> cash, reputation, decor count equal; `adventNow` Dec 6 again -> `AdventOpened` 39; door 1 `AlreadyClaimed`.
5. `deleteLeftover`, create and `playSave` "Playtest Advent": door 2 `AlreadyClaimed`, cash unchanged; door 4 ok, its `purchases.boosts.CashX2` >= 890. Back on `ctx.saveA`: door 4 `AlreadyClaimed`; delete "Playtest Advent".
6. `adventNow` Dec 25 -> `Ended`, claimable 0; door 5 `CalendarClosed`.

**Client readings, deferred (PC-13; reviewer queues them in "Studio-Test ausstehend")**, desktop and phone 666x374, Dec 3, mask cleared: `AdventButton` "Advent (3)"; tap -> `AdventPanel` visible; `Door_1`..`3` Gold active, `Door_4`..`24` locked; doors >= 44 px high, inside the panel; tap `Door_1` -> "Door 1: you got $500!", "Opened", "Advent (2)"; Dec 25 -> button hidden.

## Acceptance
- stylua, selene, headless 732 PASS, `rojo build` default and release.
- Backlog 19 criteria by the headless tests and step 71 (Dec 3: doors 1-3 open, 4 rejected). Line 19 stays unticked until the client readings pass.
- No reward amount in client payloads.

## Out of scope
Placing decor (CM2-32/33), decor models, Advent events (CM2-45), auto-open, a pre-Dec-1 teaser.

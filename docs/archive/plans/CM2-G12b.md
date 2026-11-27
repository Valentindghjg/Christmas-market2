# CM2-G12b — Four leaderboards on the village square

Written by: `planner` (Opus 5.5, high). Implemented by: the agent for the tier below. Playtested by: `playtester` (Sonnet 5.5, medium). Reviewed and committed by: `reviewer` (Opus 5.5, medium). Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.
Split: launch order 17 (CM2-G12) = **CM2-G12a** (`docs/plans/CM2-G12a.md`, day/night) + **CM2-G12b** (this plan). Runs after G12a (no code dependency; BUILD and step numbers follow G12a).

## Goal
The four boards on the village square show the worldwide top 10 for Cash earned, Reputation, Hours played and Robux spent, plus a "You" row with the viewer's rank (top 100) and value. Writes go to OrderedDataStores from a server cache, at most once per entry per 120 s, within the ordered write budget.

## Source of truth
PRODUCT_SPEC owner decisions 2026-11-21 "Leaderboards" (all four, incl. Robux spent) and "Map" (square with leaderboards); DECISION_LOG 2026-11-21 launch order (G12 includes Robux spent); REFERENCE_GAME_LIVE_TEST §8 (4 boards, top 10 + "You" row); GAME_DESIGN §9 (aggregate metrics, cached writes); TECHNICAL_ARCHITECTURE §5 (store and key-budget tables, RTBF key rule); MODEL_INTEGRATION "Map in the world (CM2-10W)" ("For CM2-G12": `Map.Square.Board_<Key>`, `Screen` 11 x 10 with `LeaderboardScreen`, `Title`); CM2-46a (`MonetizationService:robuxSpent`).

## Implementer tier
Tier: L. Reason: new DataStore (OrderedDataStore) writes with caching, budget checks and rate limits, plus increment concurrency.

## Skills to load
roblox-collaboration-mode, roblox-server-data, roblox-data, roblox-security, roblox-performance, roblox-gui, roblox-localization, roblox-luau-core, roblox-luau-types.

## Decisions (engineering, record in DECISION_LOG)
| Topic | Decision |
|---|---|
| Per save vs per player | Cash earned and Reputation are **per save** (one shared company, plot and cash in co-op saves); the row shows the save owner's username. Hours played and Robux spent are **per player**. |
| Co-op "You" row | Every member sees the rank and value of the save they are playing. |
| Cash earned | `state.revenue` (sales and tips; Robux cash packs never count). Reputation = `state.reputation`. Robux spent = the ledger's `robuxSpent` (CM2-46a). |
| Hours played | Seconds with an active, ready save (`CompanyReady`), counted in 10-s ticks; stored as integer seconds by `IncrementAsync` deltas (the ordered store is the only record; a double increment after an ambiguous error is accepted, at most one flush). Shown in hours with one decimal. |
| Keys | `player_<userId>` and `save_<saveId>` (both contain the user ID; RTBF rule, roblox-server-data). |
| Stores | `ChristmasMarket2_LB_<Key>_v1`; in Studio with suffix `_Studio`, so test values never reach the live boards. |
| Zero | A value of 0 that was never written is not written. |
| Names | Usernames only (no display names, no save names); unknown → localized "Player". |

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/GameConfig.lua` | Change | `GameConfig.Leaderboards` |
| `src/shared/LeaderboardView.lua` | New | pure row sanitizing and value formats (step 2) |
| `src/shared/Localization.lua` | Change | 7 keys en + de |
| `src/shared/UiTheme.lua` | Change | `UiTheme.Leaderboard` |
| `src/server/Services/LeaderboardService.lua` | New | cache, flush, playtime, refresh (step 1) |
| `src/server/Services/CompanyStateService.lua` | Change | `leaderboardFigures` (step 3) |
| `src/server/main.server.lua` | Change | wiring (step 4) |
| `src/server/Services/StudioTestService.lua` | Change | 3 commands (step 5) |
| `src/client/Leaderboards.client.lua` | New | board SurfaceGuis (step 6) |
| `tests/headless/run.luau` | Change | register `LeaderboardView`, `LeaderboardService` |
| `tests/studio/Cases/LeaderboardService_Test.lua` | New | 11 tests |
| `tests/studio/Cases/LeaderboardView_Test.lua` | New | 2 tests |
| `tests/studio/Cases/Localization_Test.lua` | Change | 1 test |
| `tests/studio/Cases/SaveSlotService_Test.lua` | Change | key-length assertions in the existing 50-character test |
| `tests/studio/Playtest/Steps/Leaderboards.lua` | New | steps 62, 63 |
| `tests/studio/Playtest/RunPlaytest.lua` | Change | install `Leaderboards` after `DayNight`; `BUILD = "cm2-g12b"` |
| `docs/TECHNICAL_ARCHITECTURE.md`, `docs/DECISION_LOG.md` | Change | step 7 |

## Data and config
`GameConfig.Leaderboards` (new section, after `GameConfig.DayCycle`):
| Key | Value | Tag |
|---|---|---|
| `Keys` | `{ "CashEarned", "Reputation", "HoursPlayed", "RobuxSpent" }` | OWNER DECIDED (boards; order = write/read order) |
| `PerSave` | `{ CashEarned = true, Reputation = true }` | engineering |
| `StoreFormat` | `"ChristmasMarket2_LB_%s_v1"` | engineering |
| `StudioSuffix` | `"_Studio"` | engineering |
| `TopCount` | 10 | OBSERVED (REFERENCE §8) |
| `RankDepth` | 100 | engineering (one page) |
| `WriteIntervalSeconds` | 120 | PROVISIONAL |
| `MaxWritesPerFlush` | 24 | engineering |
| `MinWriteBudget` | 10 | engineering |
| `ReadIntervalSeconds` | 180 | PROVISIONAL |
| `FirstReadDelaySeconds` | 5 | engineering |
| `PlaytimeTickSeconds` | 10 | engineering |
| `NameMaxLength` | 32 | engineering |

Budget at 12 players: ordered writes 30 + 12 × 5 = 90/min per server; this design needs at most 24 per 120 s (12/min) plus leave flushes.
Published data: Folder `ReplicatedStorage.Leaderboards`, one string attribute per board key = `HttpService:JSONEncode(rows)`, rows `{ rank, name?, value }` (rank 1..10).
Player attributes: `Lb<Key>Value` (number or nil), `Lb<Key>Rank` (integer 0..100, 0 = not ranked), e.g. `LbCashEarnedValue`.

## Steps
1. **`LeaderboardService.lua`** (`--!strict`, headless with injected deps; requires `GameConfig`, `SaveProfile`). Statics: `playerKey(userId)` = `"player_" .. SaveProfile.userIdText(userId)`; `saveKey(saveId)` = `"save_" .. saveId`; `ownerOfKey(key): number?` (`player_<digits>` → number; `save_<id>` → `SaveProfile.ownerUserIdOf(id)`; else nil); `storeName(boardKey, studio: boolean)`.
   `new(deps)`, deps = `{ store: (boardKey) -> store, budget: () -> number, userName: (userId) -> string?, clock: () -> number, publish: (boardKey, rows) -> () }`. State: `_entries[board][key] = { value, written? }`, `_play[userId] = { pending, total? }`, `_ranks[board] = { [key] = rank }`, `_inflight = {}`, `_lastFlushAt = -math.huge`, `_flushing = false`, `_stats = { flushes, writes, failures, rateLimited, noBudget }`.
   - `report(boardKey, key, value): boolean` → false unless `boardKey` is in `Keys` and not `HoursPlayed`; key matches `^save_` + `isSaveId` for `PerSave` boards, `^player_%d+$` otherwise, `#key <= 50`; value a finite number ≥ 0. Stores `math.floor(value)`.
   - `addPlaytime(userId, seconds)` → ignored unless finite, > 0 and ≤ 3600; adds to `pending`.
   - `loadPlayer(userId)` → pcall `store("HoursPlayed"):GetAsync(playerKey)`; a number sets `total` only while it is nil.
   - `forgetPlayer(userId)` → `total = nil`; drops `_play[userId]` when `pending < 1`.
   - Dirty Set entry: `value ~= written` and not (`written == nil` and `value == 0`).
   - `flush(force: boolean?): (number, string?)` → `_flushing` → `0, "Busy"`; not `force` and `clock() - _lastFlushAt < WriteIntervalSeconds` → `rateLimited += 1`, `0, "RateLimited"`; `budget() < MinWriteBudget` → `noBudget += 1`, `0, "NoBudget"`. Else `_flushing = true`, `_lastFlushAt = clock()`, `flushes += 1`, then in a pcall (always reset `_flushing`): candidates in order (a) playtime of each userId (ascending) with `pending >= 1`, (b) dirty Set entries by `Keys` order then key ascending; skip any `board..":"..key` in `_inflight`; stop when attempts reach `MaxWritesPerFlush` or `budget() < MinWriteBudget`. Returns successes.
   - Playtime write: `delta = math.floor(pending)`, mark in-flight, pcall `IncrementAsync(playerKey, delta)`; success → `pending -= delta`, `total` = the returned number (or `(total or 0) + delta` when it is not a number), `writes += 1`; failure → `failures += 1`, `warn("[ChristmasMarket2] leaderboard write %s failed: %s")`. Clear in-flight.
   - Set write: capture `v = entry.value`, in-flight, pcall `SetAsync(key, v)`; success → `entry.written = v`.
   - `flushUser(userId): number` → same writes, only the user's playtime and `RobuxSpent` entry, ignores the interval (not `_lastFlushAt`), respects the budget and `_inflight`.
   - `refresh(): number` → per board: pcall `GetSortedAsync(false, RankDepth)` then `:GetCurrentPage()`; on failure keep the old ranks and publish nothing. Else `ranks[item.key] = index`; for index ≤ `TopCount`: `owner = ownerOfKey(item.key)`, `name` = pcall `userName(owner)` (string, else nil), row `{ rank = index, name = name, value = item.value }`; `publish(board, rows)`. Returns boards read.
   - `you(boardKey, key): (number?, number)` → value: `HoursPlayed`: `total + math.floor(pending)` when `total` is known, else nil; others `entry.value` or nil. Rank: `_ranks[board][key]` or 0.
   - `stats()` → copy of `_stats` plus `dirty` (count) and `playtimePending = { [userIdText] = pending }`.
2. **`LeaderboardView.lua`** (`--!strict`, requires `GameConfig`, `UiTheme`): `rows(decoded: any): { { rank: number, name: string?, value: number } }` keeps entries with integer `rank` 1..`TopCount` (first per rank), finite `value` ≥ 0, `name` kept only when a string of 1..`NameMaxLength` chars; sorted by rank. `valueText(boardKey, value): (string, string)` → `CashEarned` `("hudCash", UiTheme.formatMoney(v))`, `Reputation` `("lbReputation", formatMoney(v))`, `HoursPlayed` `("lbHours", string.format("%.1f", v / 3600))`, `RobuxSpent` `("lbRobux", formatMoney(v))`. `rankText(rank: any): string?` → `tostring(rank)` for an integer ≥ 1, else nil.
3. **CompanyStateService** `leaderboardFigures(companyId): { revenue: number, reputation: number }?` → nil unless `isAvailable`; read-only (place next to `getLotSignView`).
4. **main.server.lua**:
   - Folder `ReplicatedStorage.Leaderboards` created at boot. `orderedWrite` = pcall-read `Enum.DataStoreRequestType.OrderedWrite`, fallback `Enum.DataStoreRequestType.SetIncrementSortedAsync`.
   - `leaderboards = LeaderboardService.new({ store = function(key) return DataStoreService:GetOrderedDataStore(LeaderboardService.storeName(key, RunService:IsStudio())) end, budget = function() return DataStoreService:GetRequestBudgetForRequestType(orderedWrite) end, userName = userName, clock = os.clock, publish = function(key, rows) folder:SetAttribute(key, HttpService:JSONEncode(rows)) end })`, after the `monetization` block.
   - `reportCompany(companyId)`: only `^save:(.+)$`; figures nil → return; `report("CashEarned", saveKey, revenue)`, `report("Reputation", saveKey, reputation)`.
   - `reportRobux(userId)`: `spent = monetization:robuxSpent(userId)`; a number → `report("RobuxSpent", playerKey, spent)` (nil = ledger not read: no write).
   - `pushYou(player)`: per key: entry key = `saveKey(ActiveSaveId)` for `PerSave` boards (no string attribute → value nil, rank 0), else `playerKey`; `value, rank = leaderboards:you(...)`; set `Lb<Key>Value`, `Lb<Key>Rank`.
   - `collectLeaderboards(force: boolean): (number, string?)` → `reportCompany` for every `companies:liveCompanyIds()`, `reportRobux` for every player, `return leaderboards:flush(force)`.
   - `refreshLeaderboards(): number` → `leaderboards:refresh()`, then `pushYou` for every player; returns the count.
   - Loops: `every(PlaytimeTickSeconds, "playtime", …)` adds `PlaytimeTickSeconds` for each player with `CompanyReady == true`, then `pushYou` for every player, returns `true, n, 0`; `every(WriteIntervalSeconds, "leaderboard writes", function() local written = collectLeaderboards(false); return true, written, 0 end)`; a spawned loop: `task.wait(FirstReadDelaySeconds)`, then forever `pcall(refreshLeaderboards)` (warn on error) and `task.wait(ReadIntervalSeconds)`.
   - `onPlayerAdded`: `task.spawn(function() leaderboards:loadPlayer(player.UserId) end)` next to the monetization spawn.
   - `PlayerRemoving`: before `saveSlots:leave`: `local companyId = companyIdFor(userId); if companyId then reportCompany(companyId) end; reportRobux(userId)` (before `monetization:forgetUser`); after `monetization:forgetUser`: `task.spawn(function() leaderboards:flushUser(userId); leaderboards:forgetPlayer(userId) end)`.
   - BindToClose: after the save wait loop: `pcall(leaderboards.flush, leaderboards, true)` (best effort, saves first).
   - Studio context: `leaderboards`, `collectLeaderboards`, `refreshLeaderboards`.
5. **StudioTestService**: `leaderboardCollect(arg)` (`arg = { force: boolean }`, else BadArgument) → `written, skipped = context.collectLeaderboards(arg.force)`, `success({ written = written, skipped = skipped })`; `leaderboardRefresh()` → `success(context.refreshLeaderboards())`; `leaderboardStats()` → `success(context.leaderboards:stats())`.
6. **`src/client/Leaderboards.client.lua`** (`--!strict`): per key in `Keys` a `SurfaceGui` `Leaderboard_<Key>` in PlayerGui: `ResetOnSpawn = false`, `Face = Front`, `SizingMode = PixelsPerStud`, `PixelsPerStud` / `MaxDistance` from `UiTheme.Leaderboard`, `LightInfluence = 0`. Canvas 440 x 400 px; 11 rows of `rowHeight` at y = `padding + (i - 1) * rowHeight` (rows 1–10), the You row at `padding + 10 * rowHeight + youGap`. Each row: `Rank` (x `padding`, width `rankWidth`), `Name` (x `padding + rankWidth`, width `440 - 2 * padding - rankWidth - valueWidth`), `Value` (right-aligned, width `valueWidth`); `TextSize` `textSize`, `Font` Regular (You row Bold), colour Cream (You row Gold); `AutoLocalize = false` on all three. Render: `LeaderboardView.rows(pcall JSONDecode(attribute))`; row i: rank, `name or localized("lbUnknownPlayer")`, `localizedFormat(valueText(...))`; empty list → row 1 name `localized("lbEmpty")`, rows blank. You row: `localized("lbYou")` as name, rank `rankText(LbRank) or localized("lbNoRank")`, value formatted or `lbNoRank`. Re-render on the folder's `AttributeChanged` and on `Lb*` player attribute changes. Every 2 s set `Adornee` to `workspace.ChristmasMarketWorld.Map.Square.Board_<Key>.Screen` when found (streaming) and nil otherwise.
   `UiTheme.Leaderboard = { pixelsPerStud = 40, maxDistance = 150, padding = 12, rowHeight = 32, youGap = 10, rankWidth = 48, valueWidth = 140, textSize = 22 }` (PROVISIONAL).
   Localization (en / de): `lbYou` "You" / "Du"; `lbEmpty` "No entries yet" / "Noch keine Einträge"; `lbUnknownPlayer` "Player" / "Spieler"; `lbNoRank` "—" / "—"; `lbReputation` "★ %s" / "★ %s"; `lbHours` "%s h" / "%s Std."; `lbRobux` "R$ %s" / "R$ %s".
7. **Docs**: TECHNICAL_ARCHITECTURE §5 store table: four rows `ChristmasMarket2_LB_<Key>_v1` (OrderedDataStore, CM2-G12b; Studio `_Studio`) with keys `player_<userId>` (HoursPlayed, RobuxSpent) or `save_<saveId>` (CashEarned, Reputation), value integer; key budget table rows `player_<userId>` 26, `save_<saveId>` 41; one bullet "Leaderboards (CM2-G12b)" (cache, 120 s flush, ≤ 24 writes, budget floor 10, playtime increments, 180 s reads of 100 ranks, leave flush, BindToClose best effort). DECISION_LOG entry "2026-11-23 - Leaderboards (CM2-G12b, engineering)" with the Decisions table.

## Tests (headless)
Fake ordered store per board: `data`, counters `sets`/`increments`, `failNext`, asserts `#key <= 50`; `GetSortedAsync(false, n)` returns pages whose `GetCurrentPage()` lists `{ key, value }` descending. Fake clock and budget (default 100), `userName` from a table.
| Test case file | Test name | Asserts |
|---|---|---|
| LeaderboardService_Test | caches reports and writes once | 50 reports of rising values on one key → `flush(true)` → 1 set, stored = last value |
| LeaderboardService_Test | skips unchanged entries and new zeros | second `flush(true)` → 0 sets; a new key reported 0 → never written |
| LeaderboardService_Test | rate-limits flushes | `flush()` at t 0 writes; new value; t 60 → `0, "RateLimited"`, 0 sets; t 120 → 1 set; `stats().rateLimited` 1 |
| LeaderboardService_Test | caps writes per flush | 30 dirty player keys → 24, then 6 |
| LeaderboardService_Test | stops below the write budget | budget 5 → `0, "NoBudget"`, still dirty; budget 100 → written |
| LeaderboardService_Test | keeps a failed write dirty | `failNext = 1` → 0 written, `failures` 1; next forced flush writes it |
| LeaderboardService_Test | adds playtime as whole-second increments | `addPlaytime(7, 125.5)` → increment 125, stored 125, pending 0.5, `you` 125; +0.6 → next increment 1; `addPlaytime` 0, -1, NaN, 4000 ignored |
| LeaderboardService_Test | rejects invalid reports | unknown board, `HoursPlayed`, negative, NaN, `player_x`, `save_bad` on CashEarned, `player_7` on Reputation → false, nothing dirty |
| LeaderboardService_Test | refresh publishes top rows and ranks | 12 entries → published 10 rows descending, names via `userName` (save keys → owner), unknown name nil; `you` rank 3 for the third key, 11th key rank 11, absent key 0; a failing `GetSortedAsync` keeps the old ranks and publishes nothing |
| LeaderboardService_Test | flushUser writes only that player | users 7 and 8 and one save dirty → `flushUser(7)` writes 7's playtime and `RobuxSpent` only |
| LeaderboardService_Test | an in-flight playtime key is not written twice | the fake `IncrementAsync` calls `flushUser(7)` re-entrantly once → 1 increment total |
| LeaderboardView_Test | sanitizes rows | drops rank 0, 11, 1.5, duplicate rank, NaN or negative value, non-table; name of 33 chars → nil; result sorted |
| LeaderboardView_Test | formats values per board | 12345 cash → ("hudCash", "12,345"); 5400 h → ("lbHours", "1.5"); 1234 Robux → ("lbRobux", "1,234"); `rankText(0)` nil, `(4)` "4" |
| Localization_Test | has every leaderboard key in English and German | the 7 `lb*` keys exist in `en` and `de` |

SaveSlotService_Test "keeps every key within 50 characters for a 19-digit user ID": add `#LeaderboardService.playerKey(<its 19-digit id>) <= 50` and `#LeaderboardService.saveKey(<its 36-char save id>) <= 50`.
Expected: **630 run, 0 failed** (616 on main @ cd45fac after CM2-SALE2 + 14; amendment 1 A5).

## Playtest (Studio, via playtester; now: tier L, DataStore writes)
1. Rojo sync, `BUILD = "cm2-g12b"`; Play (Studio API access on); `runPlaytest {mode="full"}` → **64/64** (62 + 2).
2. Step **62 LEADERBOARD_FLUSH** (`Steps/Leaderboards.lua`, needs {"03"}): (a) poll ≤ 15 s until `leaderboardStats().playtimePending[tostring(R.userId)] >= 1`; (b) read `player_<id>` from the `_Studio` HoursPlayed store (`GetOrderedDataStore(string.format(StoreFormat, key) .. StudioSuffix)`, nil → 0) as `before`; (c) `leaderboardCollect {force = true}` → `skipped == nil`; (d) `save_<ActiveSaveId>` in CashEarned == `snap(R.userId).revenue` (or nil when revenue is 0), in Reputation == `snap.reputation`; `player_<id>` in RobuxSpent == `shopLedger {userId}.robuxSpent` (or nil when 0); HoursPlayed ≥ `before + 1`; (e) `leaderboardCollect {force = false}` → `skipped == "RateLimited"`, `written == 0`; (f) `leaderboardRefresh`; poll ≤ 10 s: `ReplicatedStorage.Leaderboards` attribute `CashEarned` decodes through `LeaderboardView.rows` to ≤ 10 rows with non-increasing values; the real player's `LbCashEarnedValue == revenue`, `LbReputationValue == reputation`, `LbHoursPlayedValue >= before + 1`, `LbCashEarnedRank` an integer 0..100.
3. Step **63 LEADERBOARD_BOARDS** (needs {"62"}): `Map.Square` holds `Board_CashEarned`, `Board_Reputation`, `Board_HoursPlayed`, `Board_RobuxSpent`, each with attribute `LeaderboardKey` = suffix and a BasePart `Screen` with `LeaderboardScreen` = suffix; `ReplicatedStorage.Leaderboards` has a string attribute for all four keys.
4. Queue in "Studio-Test ausstehend" (PC-7): on a real client, each board shows its title, up to 10 rows and the You row (`PlayerGui.Leaderboard_<Key>.Adornee` is that board's `Screen` when standing on the square); the You row matches `Lb<Key>Rank`/`Lb<Key>Value`; one capture of all four boards from the square centre (235, 0) and one close-up; text readable at 20 studs.

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (630 run, 0 failed), `rojo build` (both project files).
- Studio full run 64/64 on BUILD `cm2-g12b`, steps 62 and 63 PASS (server-side).
- Backlog: "leaderboard writes are cached and rate-limited (test)" = the headless tests "caches reports and writes once", "rate-limits flushes", "caps writes per flush", "stops below the write budget" plus step 62 (e).

## Out of scope
Removing a deleted save's entries (follow-up candidate), season resets, friends-only boards, display or save names on boards, the Studio ArtAssets leftover (PC-7 step 4), board art import (PC-2).

## Amendment 1 (2026-11-26): board screen name clash in art mode, log date
Trigger: batch Studio run (place 92354134900807, main @ cd45fac + uncommitted G12b tree), twice 62/64; step 63 FAIL "Board_CashEarned.Screen LeaderboardScreen nil" (step 62 PASS).

**Cause (code, not the step).** The place builds the map from art (`MAP_WORLD` 302 of 302 art). In art mode `Board_<Key>` is a clone of `Props/LeaderboardBoard`, whose root already holds a MeshPart `Screen` (`assets/art/source/Props/LeaderboardBoard/build.py`: `K.box("Screen", "FabricCream", …)`). `MapWorld.addBoardParts` then adds a second Part `Screen` with `LeaderboardScreen`. `FindFirstChild("Screen")` returns the art mesh, which has no attribute. The client has the same bug: `screenOf` in `Leaderboards.client.lua` adorns the art mesh. That mesh's front face (local z -0.3) is behind the added Panel Part's front face (-0.35), so a real client would see blank boards. Fallback mode is not affected. Attribute names, server/client split and key names all match the contract.

| # | File | Exact change |
|---|---|---|
| A1 | `src/server/Services/MapWorld.lua` `addBoardParts` | First statement, before `SetAttribute("LeaderboardKey", …)`: loop `model:GetChildren()`; every child that `IsA("BasePart")` and is named `"Screen"` or `"Title"` is renamed `child.Name .. "Panel"` (`ScreenPanel`, `TitlePanel`). One-line comment above: `-- Art boards carry their own Screen mesh; rename it so Board_<Key>.Screen is the unique screen Part (CM2-G12b A1).` Nothing else changes (sizes, offsets, colours, attributes as before). |
| A2 | `tests/studio/Playtest/Steps/Leaderboards.lua` step 63 | Inside the per-key loop, after the `board ~= nil` check: count the board's direct children named `"Screen"`; `check(count == 1, string.format("Board_%s has %d Screen children", key, count))`. Return text unchanged. |
| A3 | `docs/MODEL_INTEGRATION.md` line "For CM2-G12: …" | Append: ` A direct art child BasePart named Screen or Title is renamed ScreenPanel/TitlePanel at build (CM2-G12b A1).` |
| A4 | `docs/DECISION_LOG.md` G12b entry | Heading date **2026-11-26** (not 2026-11-23; the active log is chronological and the entry goes after "2026-11-26 — Early-lot demand, CM2-SALE2"). Add bullet after the Plan bullet: `- Art boards: the art's own Screen mesh is renamed ScreenPanel at build, so Board_<Key>.Screen is the one Part the SurfaceGui adorns (amendment 1).` |
| A5 | this plan, Tests and Acceptance | Expected headless count: **630 run, 0 failed** (main @ cd45fac has 616 after CM2-SALE2, + 14). The old "599 (585 + 14)" was based on a stale count. |

`Leaderboards.client.lua` and `LeaderboardService` stay unchanged: after A1 `FindFirstChild("Screen")` finds the right Part on server and client.
Files table additions: `src/server/Services/MapWorld.lua` (Change, A1), `docs/MODEL_INTEGRATION.md` (Change, A3).

**Re-test (playtester):** Rojo sync with A1–A5 and the CM2-SALE2 amendment 1 fix, Play, `runPlaytest {mode="full"}` → **64/64**; step 63 PASS; step 56 `MAP_WORLD` still PASS (302 of 302 art, board titles). PC-7 queue item (step 4 of "Playtest") unchanged.
Implementer: `implementer-opus` (plan tier L unchanged; A1–A5 are small and go into the same uncommitted G12b tree).

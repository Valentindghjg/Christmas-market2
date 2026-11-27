# Decision log archive 2026-11-26 (CM2-SLIM run 4, 2026-11-28)

Entries moved unchanged and in order from `docs/DECISION_LOG.md`; they stay binding unless a pointer in the log says superseded.

## 2026-11-26 — Early-lot demand, CM2-SALE2 (engineering)
- Problem: CM2-SALE1 found that a fresh 6-tree Douglas Medium lot converted only about 1.1 % of visits, because a customer wanted exactly its preferred species and size and variety (1/3, 2/3, 1) and stock (0.2, 0.4, 1) factors were harsh for a starter lot.
- Decision (all PROVISIONAL, `GameConfig.Demand`): preferences are soft. A customer considers every displayed tree within its budget percent (85-155 %) applied to that tree's own benchmark (`CustomerProfile.budgetFor`) and picks the highest-scoring one (ties keep the first sorted ID). Interest in the tree: exact species and size 1, same species 0.85, same size 0.75, other 0.65 (`Demand.score` gains an optional `interest`). varietyFactor 0.85 / 0.925 / 1 for 1 / 2 / 3+ species; stockFactor 0.6 + 0.4 × unreserved trees / 5, capped at 1. Price factor, reputation factor, clamp 0.02..0.95 and the roll are unchanged.
- Simulation (`DemandSimulation_Test`, 1000 visits, reputation 90, default prices, seeds 1-3): 1 Douglas Medium 0.125-0.130 (target 0.10-0.16); 6 Douglas Medium 0.188-0.190 (0.16-0.23); mixed 2 S + 2 M + 2 L Douglas 0.204-0.208 (0.18-0.25); full 12-tree assortment 0.301-0.303 (0.25-0.35).
- Late game unchanged: the full assortment stays at about 30 % as before. No guaranteed purchase (clamp 0.95 and the roll stay); the tutorial guarantee (CM2-SALE1) is unchanged; no save field, remote or sale-path change.
- Files: src/shared/GameConfig.lua, Demand.lua, CustomerProfile.lua, CustomerSelection.lua, docs/GAME_DESIGN.md (§4, §5), docs/TEST_PLAN.md (§2).

## 2026-11-26 — Leaderboards (CM2-G12b, engineering)
- Plan: `docs/archive/plans/CM2-G12b.md`. Config `GameConfig.Leaderboards`, cache and writes in `src/server/Services/LeaderboardService.lua`, rows and formats in `src/shared/LeaderboardView.lua`, screens in `src/client/Leaderboards.client.lua`.
- Art boards: the art's own Screen mesh is renamed ScreenPanel at build, so Board_<Key>.Screen is the one Part the SurfaceGui adorns (amendment 1).

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

## 2026-11-26 — Tree art in the world, CM2-12W (engineering)
- Plan: `docs/archive/plans/CM2-12W.md`. Five roles: Display, Pickup, Carried (player), NpcCarried (customer and staff) and Roof; the backlog's "forest" role was already art through CM2-10W (`MapWorld` unchanged, step 64 only confirms it).
- Scale rule (`src/shared/TreeArt.lua`): Display and Pickup use the art at native size (H 6/8/10); Carried, NpcCarried and Roof scale the art to `11.5 x primitive scale` (Carried 4.6, NpcCarried 4.025 / 4.6 / 5.175, Roof 4.025); a carried art tree drops by `2.5 x scale` so its foot matches the primitive's.
- Label rule: label height = tree top + `UiTheme.WorldLabels.<layout>.height` (+ stagger). `WorldLabels.DisplayTree.height` 10 -> 1.0 and `WorldLabels.PickupOrder.height` 9 -> 1.5 (stagger 2 stays); both now mean studs above the tree top.
- Foot at the lot top: display trees 0.6 -> 0.55, pickup trees 0.9 -> 0.55 (`lotTop` = ground top).
- Staff projection fields: `staffPeekOrder` and `staffPeekRestock` return `speciesId` (read-only; no save field, remote, error code or string key changes), so staff and customers carry the right species.

## 2026-11-26 — CM2-PP engineering decisions
- Plan: `docs/archive/plans/CM2-PP.md` (owner decision "plot picker at session start", 2026-11-24). Picker UI in `src/client/PlotPicker.lua`, server parts in `SaveSlotPicker.lua` ("Plot picker (CM2-PP)") and `PlotService.claimExact`.

| Topic | Decision |
|---|---|
| New action | `Save.Plots {saveId}` returns the plot list for that save; rate limit 20 per 10 s (like `Save.List`, PROVISIONAL). |
| Who picks | `pick = true` only when the save holds no plot here, nobody plays it here, no load of it is pending or unloading, it is not the caller's active save and at least one plot is free for the caller; otherwise the client sends `Save.Play {saveId}` at once (attach, or the automatic/teleport path). |
| Chosen play | `Save.Play {saveId, plotId?}`: without `plotId` the automatic claim is unchanged; with it, attach paths ignore it, otherwise the server claims exactly that plot if still free, else `PlotTaken` (other plots free) or the no-free-plot path (none free). Nothing is reserved while browsing. |
| Own current plot | The plot of the caller's active save counts as free when the caller is its only player here and it is neither loading nor unloading (a switch releases it before the claim). |
| Pre-check | `PlotTaken` is decided before the current save is left, so an obvious refusal never drops the running save; the claim after the leave stays authoritative. |
| Last plot | Profile entry field `lastPlotId: string?` (1-32 bytes; written on every play and attach), no `SaveProfile.VERSION` bump (precedent `tutorialOffered`, CM2-49); an id the server does not know is ignored. Preselect = `lastPlotId` if free for the caller, else the first free plot in config order. |
| Road side | `MapLayout.PLOTS[number].z < 0` is `"South"`, else `"North"` (plots 1-3 south, 4-6 north of the main road). |
| Occupant name | The lot sign's public text (`WorldService.lotSignName`: the broadcast-filtered save name or "<user>'s Tree Lot"); nil while the sign shows "Lot available". Raw save names never leave the server. |
| Teleport arrival | A `cm2NoFreePlot` arrival no longer auto-plays: the server stores `{saveId, attempt}` per player (`noteArrival`) and sets the player attribute `PlotPickSaveId`; the client opens the plot picker for that save. A later `Save.Play` of the same save uses the stored attempt, so `MaxPlotTeleports` still bounds the chain. |
| Camera | Scriptable camera at `center + (0, 55, facing x 60)` looking at the plot centre, tween 0.6 s Quad Out; `RequestStreamAroundAsync(center)` per selection (PROVISIONAL, `UiTheme.PlotPicker`). |
| Kept automatic | `Save.FinderStart`, `Save.Teleport` arrivals (`arrive`), Studio hooks (`shadowJoin`, `rejoin`) and `runPlaytest` keep the automatic claim. |

## 2026-11-26 — CM2-ASSETWARN closed as engine noise (planner)
- The `rbxassetid://203785492` "Asset type does not match requested type" warning is engine or Studio noise, not project content: a scan of every exposed property and attribute found 0 hits in Edit (3337 instances), Play server (6131) and Play client (9090); 2 lines appear in Edit before any project script runs and 4 at Play start, none later; no Lua error, no missing visible asset, no route blocker (PROGRESS archive `docs/archive/PROGRESS_2026-11-25_to_2026-11-26_ASSETWARN-N1b-PT35b-PT53.md`). No fix task. Playtests and reviews treat these lines as known noise.
- Reopen (as an S task) only if the line count grows past 6 per Play session, it shows in a live-server error report, or a visible sound, image or mesh is missing.

## 2026-11-26 — Lot and HQ art in the world, CM2-13W (engineering)
- Tier ids: the backlog's "config tier `ChristmasPavilion` maps to `Buildings/TimberPavilion`" is obsolete; since schema 19 the tier ids are `SalesTent`, `TimberPavilion`, `AlpineHut`, `MountainChalet`, so the art path is `Buildings/<tier.id>`.
- Lot fence: it follows `Progression.fenceBoxes` (8 studs per level, sides only from level 1, from z -27 back); the CM2-13b layout (6 per level, sides from z 27) is superseded. Only `FenceRail8` and `FencePost` are placed (`FenceRail6` unused). Values: line offset 0.45 beyond the lot edge (x ±40.45, back z -(27 + 8 x level + 0.45)), base on the map ground (y 0, 0.55 below the lot top), 11 + 2 x level pieces (10 back rails, 1 corner post, `level` rails per side), rail extent 4.3 behind and 3.95 ahead of its centre, 0.3 half-width.
- Gameplay anchors stay: `CheckoutCounter.CounterBase` and `Receiving.Bay_<i>` keep size, position and children (prompt, label) and are invisible when the art is present.
- Decor fences: `Placement.DecorFences` become one `FenceRail8` and one `FencePost` each in a model `DecorFence`; the CC0 `FenceWooden` stays only as the fallback.
- Road yaw 180 degrees on plots 1-3 and 0 on plots 4-6; the night light moves to the art's `Register` part (else `CounterBase`). No save, remote, error-code, string-key or KeepClear change.

## 2026-11-26 — CM2-G11 daily rewards, quest board and group bonus (engineering)
- Plan: `docs/archive/plans/CM2-G11.md`. Pure logic in `src/shared/DailyRewards.lua` and `src/shared/QuestBoard.lua`; the claim action in `src/server/Services/DailyRewardService.lua`, the board and reward grants in the mixin `src/server/Services/CompanyQuests.lua`, the panel in `src/client/QuestPanel.lua` (rail slot 30). The scaffold (`QuestService.lua`, the old `GameConfig.Quests`, `questClaims`) is gone; it was never client-reachable.

| Topic | Decision |
|---|---|
| Daily streak owner | Per **player** (profile `daily`), paid into the **active save**; one claim per player and UTC day across saves and servers (co-op members claim their own). |
| Day | `floor(businessClock / 86400)` (UTC). Claimed yesterday → next index; missed ≥ 1 full day → back to day 1; after day 7 → day 1 (PROVISIONAL). Clock behind `lastDay` → `AlreadyClaimed`. |
| Claim order | Validate → rate limit → in-flight guard → active, available save → group check (may yield) → profile `UpdateAsync` marks the day (atomic guard) → save still active → grant in the company critical section. Grant refused → revert exactly this claim; revert failed → `warn`, reward lost (at most once, never twice). |
| Group | `GroupId = 0` → hidden, never doubled, no `IsInGroup` call. Else `Player:IsInGroup` in `pcall` at join and each claim; error → cached value (default false). ×2 on cash and reputation inside the one claim. Join button: `GroupService:PromptJoinAsync` in `pcall`; membership may be cached per server, so the text says "from your next visit". |
| Quest board owner | Per **save** (`state.quests`, schema 21), progress from any member's actions. |
| Rotation | Windows `floor(clock / 14400)`. A stale board is replaced on the next note, claim or test hook; unclaimed rewards lapse. Progress grows only from play events, so offline time never pays. The view never mutates. |
| Counting | Orders: quantity of each successful `placeOrder`. Sales: each `completeReservedSale` (sale price, 1 tree, its size); pass/boost bonus not counted. Rewards are not revenue and get no cash multiplier. |
| Scaffold | `QuestService.lua`, its test, the old `GameConfig.Quests` and `questClaims` are replaced (never client-reachable). |

- Amendment 1 (Studio step 34 ELSEWHERE flake, not caused by G11): the save locator cache stays at `LocatorCacheSeconds` = 15 s. The Studio test instrument drops the cached lookup after its direct map writes (`placeElsewhere`, `clearElsewhere` call the new `SaveSlotService:forgetLocation`), so a miss cached during the save switch no longer hides the fake foreign server.
- Amendment 2 (B3, auto-open): the quest panel's auto-open check also runs after every modal change (`ModalCoordinator.onChange`, `UiKit.onModalsChanged`: claim, release, closeAll, base layer), so a modal or base layer held at the attribute change no longer blocks it for the session. `QuestUI` carries `AutoOpenState` (`NotReady`, `NotClaimable`, `Tutorial`, `Modal`, `BaseLayer` or `Opened`), the first failing condition of the last check.
- Amendment 2 (B4, plot picker): the CM2-PP plot picker closes itself when `CompanyReady` turns true for its own save (`ActiveSaveId` equals the picker's save), because Save.Play activates the save before its response arrives; a later Save.Play response finds the picker closed and does nothing.


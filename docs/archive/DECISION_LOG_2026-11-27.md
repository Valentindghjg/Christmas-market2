# Decision log archive 2026-11-27 (planner, 2026-11-28)

Entries moved unchanged and in order from `docs/DECISION_LOG.md`; they stay binding unless a pointer in the log says superseded.

## 2026-11-27 — CM2-SUP supplier cart, packing and sell back per row (engineering)
- Protocol: `Supplier.PlaceOrder` takes the legacy `{speciesId, sizeId, quantity}` or exactly `{lines}` (1–`Supplier.MaxCartLines` = 12 lines of exactly `{speciesId, sizeId, quantity}`); `SupplierCart.normalize` answers `InvalidCart`, `UnexpectedField`, `InvalidItem`, `InvalidQuantity` (1–100 per line and in total) or `DuplicateLine`. No price or cost is read from the client; all checks run before the first change; one debit and one `OrderPlaced` ledger entry per cart; a replay is `DuplicateRequest`.
- Packing: per species in `SpeciesOrder`, sizes in `SizeIds` order fill groups of at most `BayCapacity` (9), splitting a line when needed; each group takes the next free bay, ascending, never a busy one (`NoFreeBay` when groups exceed free bays).
- No save-schema change and no migration: a cart becomes several `pendingOrders` records of today's shape sharing `requestId`, `createdAt` and `dueAt`, IDs `order:<requestId>` then `order:<requestId>:<k>`.
- The recommended order (one species per free bay, limited by stock, storage, cash and one bay's 9 trees in total; an empty one carries a reason) replaces the cart in one tap. `BayCapacity` is no longer returned (a large line splits instead); its string stays. `Company.GetSummary.supplier` adds `sellable`, `refunds` and `deliverySeconds`.
- Files: src/shared/SupplierCart.lua, BusinessState.lua, Protocol.lua, UiTheme.lua, Localization.lua, GameConfig.lua; src/server/Services/CompanyStateService.lua, SupplierStockService.lua; src/server/main.server.lua; src/client/LotManagerTabs/SupplierTab.lua, Tutorial.client.lua; docs/TECHNICAL_ARCHITECTURE.md.

## 2026-11-27 — CM2-GATE lot gate and festive fence v3 (engineering)
- New `Props/LotGate` (tier A, 19.3 x 1.85 x 17.59, 2868 / 3000 triangles, 9 MeshParts) and fence v3 `FencePost` (0.9 x 0.9 x 5.93, 160 / 400, 3 MeshParts), `FenceRail8` / `FenceRail6` (8.40 / 6.40 x 0.9 x 5.93, 512 / 452 of 800, 4 MeshParts), raised from tier B to tier A; built in one Blender pass from `fence_common.py`. Gate opening 16.3 x 12.1, post footprint 1.5 x 1.5, fence post 0.9, fence top 5.93.
- Colour: all fence wood is `WoodWarmShade`, because a second wood colour does not fit in 4 MeshParts; this is a recorded deviation from quality checklist item 4 (light and shade variant per material). The gate uses the WoodWarm / WoodWarmShade pair.
- Gate attachments are `Light1` and `Light2` (plan: `Light_1`, `Light_2`), because the pipeline name rule forbids underscores. The modeler added WoodWarm bands on the gate posts (secondary forms for tier A), inside the 1.5 footprint and outside the opening.
- Until CM2-GATEW the code constants (`LotArt.PIECE_HALF` 0.3) understate the fence post by 0.15 per side.
- Files: assets/art/source/Environment/{fence_common.py,FencePost,FenceRail8,FenceRail6}, assets/art/source/Props/LotGate, assets/art/rbxm, assets/art/previews, docs/MODEL_INTEGRATION.md.

## 2026-11-27 — CM2-A1 Advent calendar (engineering)
| Topic | Decision |
|---|---|
| Opened doors | Profile `advent = {year, opened}`, bit d-1 = door d; another `year` counts as empty; so one payment per player across saves and servers. |
| Window | UTC date Dec 1..24 -> `Open`, today = day; before Dec 1 -> `Before`; Dec 25..31 -> `Ended`; today = 0 outside `Open`. |
| Claim order | As Daily.Claim: validate, rate limit, in-flight guard, active available save, profile UpdateAsync sets the bit, save still active, `grantReward`; refused -> clear the bit; revert failed -> `warn` (lost at most once, never paid twice). |
| Decor | No decor system yet: decor goes into a new save map `decorInventory` (the "decor crate"), consumed by CM2-32/33. |
| Boost | Cash Rush seconds (`purchases.boosts.CashX2`) clamped at `BoostCapSeconds`; excess dropped. |
| Studio date | `AdventService:setNowForTest(at?)` overrides only the calendar's time, not the business clock. |
- Save schema 22 adds `decorInventory = {[DecorItems id]: 1..DecorMaxCount}` (migration 21 -> 22 and the legacy-v1 path set `{}`); the profile field needs no version bump (as `daily`). Door rewards in `GameConfig.Advent.Doors` are PROVISIONAL and are not revenue (no Cash Rush multiplier).
- Files: src/shared/AdventCalendar.lua, GameConfig.lua, BusinessState.lua, SaveProfile.lua, Protocol.lua, Localization.lua, UiTheme.lua; src/server/Services/AdventService.lua, CompanyQuests.lua, CompanyStateService.lua, SaveSlotService.lua, StudioTestService.lua; src/server/main.server.lua; src/client/AdventPanel.lua, UiController.client.lua.

## 2026-11-27 — CM2-GATEW entrance gate in the world (engineering)
- Placement: gate pivot at lot (28, 28) = `LotHalfDepth` 27 + `GATE_OFFSET` 1.0, east of the parking. Customers never cross the front edge (cars drive straight from the road to spaces at x -24..12, NPCs start at the door), so a gate over the car lanes would serve nobody; it stands for players coming from the sidewalk. Posts 1.5 x 1.5 at x 18.35..19.85 and 36.15..37.65 are fully off the placeable lot (z >= 27.25) and keep 2.25-5.35 studs from parking, walk lines, truck lane and the sign box.
- Backlog deviations: the offset is 1.0, not `FENCE_OFFSET` 0.45 (the post would reach into the lot); customers cannot walk through the gate (steps 37 and 40 stay as regression with 0 snaps).
- The right decor fence (34, 24) stood 3 studs behind the opening and is dropped: `DecorFences = { { x = -34, z = 24 } }`.
- Lights through `MapWorld.nightLight` (`DayCycle.GateLight`, PROVISIONAL), 12 more night lights (46 in step 61); the name board mirrors the lot sign through `WorldService.setLotSign`. No save, money or remote change.
- Files: src/shared/LotArt.lua, GameConfig.lua, UiTheme.lua; src/server/Services/LotGateWorld.lua, WorldService.lua; tests/studio/Cases/{LotArt,GameConfig}_Test.lua, Playtest/Steps/{LotArt,DayNight}.lua; docs/MODEL_INTEGRATION.md.

## 2026-11-27 — CM2-45 event framework and 1st Advent event (engineering)
| Topic | Decision |
|---|---|
| Currency | Pack for in-game cash (backlog: "event currency or cash"); Robux `EventTree*` stay `ready = false`, "Coming soon" (owner 2026-11-26; CM2-V2-SPT). Deviation: the reference pack costs 29 Robux; `EventDecorPack` unchanged. |
| Window | `startsAt <= now < endsAt` (UTC seconds); Advent1 until the next Advent Sunday (PROVISIONAL); no overlaps. |
| Scope | Per save, counted in `eventPurchases[eventId][itemKey]`; all stays after the event. |
| Client feed | `ReplicatedStorage` attributes `EventId` ("" = none), `EventEndsIn` (s) every 5 s; rows in `Company.GetSummary.event`. |
- Advent1 = 2026-11-29 00:00 to 2026-12-06 00:00 UTC (start OWNER DECIDED, end PROVISIONAL); the "Candlelight Pack" costs $2000, limit 1 per save (PROVISIONAL), and adds 5 decorations x 3 (OBSERVED shape, REFERENCE §7) to the decor crate. The pack is a cash sink, not revenue.
- Save schema 23 adds `eventPurchases = {[eventId]: {[itemKey]: 1..MaxBuyCount}}` (migration 22 -> 23 and the legacy-v1 path set `{}`); keys are checked by format only, so a later config change never bricks a save. Event decor ids join the decor crate (`AdventCalendar.isDecorInventory` accepts `EventConfig.isDecorItem`).
- Studio: `CompanyStateService:setEventNowForTest(at?)` moves only the event clock, not the business clock (`eventNow`, `eventReset`).
- Files: src/shared/EventConfig.lua, EventCalendar.lua, AdventCalendar.lua, BusinessState.lua, Protocol.lua, Localization.lua, UiTheme.lua; src/server/Services/CompanyEvents.lua, CompanyStateService.lua, StudioTestService.lua; src/server/main.server.lua; src/client/EventShopPanel.lua, UiController.client.lua.

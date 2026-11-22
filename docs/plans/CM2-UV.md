# CM2-UV — UI verification in a visible Studio window

Planner (Opus 5.5) · no implementer · `playtester` (Sonnet 5.5) · `reviewer` (Opus 5.5) · skill `cm2-task`. Everything is decided; if something is missing, the playtester stops and reports.

## Goal
Run the UI and visual checks that S1, S2, S3, G21, CM2-40, G7, G14 and N1 left BLOCKED (PC-3) with real MCP clicks, keys and captures in Play; record PASS/FAIL/BLOCKED per item (a)–(j). No source change.

## Source of truth
Backlog 5b, PC-3; playtests of CM2-40 (4–9), S1 (2), S2 (4), S3 (4), G7 (6), G14 (2, 5), N1 (Fix round 2, Playtest 2); TEST_PLAN "Repeatable run".

## Implementer tier
Tier: S. Reason: verification and docs only; no code, test, model or map change.

Pipeline: skip step 2. Step 3 runs now; tasks in "Studio-Test ausstehend" run after (g). A FAIL does not go back as fix steps; it becomes a fix task (D6). Step 4: the reviewer runs the (g) checks, writes PROGRESS, commits.

## Skills to load
roblox-collaboration-mode, roblox-studio-mcp, roblox-gui, roblox-input, roblox-localization, roblox-building (V1).

## Files
| File | New/Change | Purpose |
|---|---|---|
| `docs/PROGRESS.md` | Change (reviewer) | CM2-UV entry in the Evidence format |
| `docs/CLAUDE_BACKLOG.md` | Change (planner, after the run) | 5b, PC-3, fix tasks, PC-4/CM2-UV2 |
Nothing under `src/`, `tests/`, `assets/`; never save the place.

## Decisions (settled)
- **D1 Build.** Record `git rev-parse --short HEAD`. Edit DM: `require(game.ServerStorage.UnitTest.Playtest.RunPlaytest).BUILD` must be `"cm2-n1-fix2"`; otherwise stop, all items BLOCKED "Studio not synced with Rojo".
- **D2 Device sizes.** Read the Roblox_Studio tool schemas first. Without a Device Emulator control (expected), phone (667×375) and tablet (1024×768) sub-checks are BLOCKED "no MCP emulator control" and items are judged on the PC size; the planner adds PC-4 (Art: studio; the owner picks the emulator device on request in an attended run) and CM2-UV2 (the Size checklist on phone and tablet) after the UV fix tasks. With such a control, run the checklist per device now.
- **D3 PC size** = the real Play viewport, emulator off; record it (expected 1564×730). Exact 1920×1080 goes to CM2-UV2.
- **D4 Clicks.** Point = `AbsolutePosition + AbsoluteSize/2` via `user_mouse_input`, without `GuiService:GetGuiInset()`: `user_mouse_input` uses GUI space (corrected 2026-11-22: the inset variant hit `SavesButton` on f1). Typing: click the TextBox, set `Text = ""` (Client DM), `user_keyboard_input`.
- **D5 Timeouts.** A `screen_capture` or `user_mouse_input` that times out is retried once after 5 s. Two timeouts in a row: stop Play; items not finished are BLOCKED; passed items stay; PC-3 goes back to `offen` with the item letter.
- **D6 Defects.** Not fixed here. The planner adds `CM2-UVF<n>` (goal = the defect, depends CM2-UV, accept = the failing check re-run PASS + headless) as launch order 5c, 5d, … and right after CM2-UV in "Next hasseln starts here"; its plan sets the tier.
- **D7 Test data.** Saves "UV Test"/"UV Test 2", "UV Duo", "UV Far", the finder saves. Never rename or delete "Playtest A" or "Tree Lot 1". Delete leftovers first (`Save.Delete {saveId, confirmName}`; for "UV Far" after `unlockSave`, `clearElsewhere`).

## Helpers
`H(cmd, arg)` = `ServerStorage.StudioTestHook:Invoke` (Server DM); R = player UserId; SH = 999999999001; `c` = `Plots[<PlotId attr>].PrimaryPart.Position`; `act(u, a, p)` = `H("act", {userId=u, action=a, payload=p})`; `sa` = same with `saveAction`.
- **H2 aim(lx, lz)** (Client): world = `Vector3.new(c.X + lx, c.Y, c.Z + Stocking.facing(c.Z) * lz)` (`Shared.Stocking`); move the mouse to `cam:WorldToViewportPoint(world)`.
- **H3 cam(target, offset)** (Client): Scriptable, `CFrame.lookAt(target + offset, target)`, offset (14, 12, 14); `Custom` after each world item.
- **H4 probe(guis)** (Client) lists violations; PASS when empty. Per shown GuiObject: > 1 px outside its ScreenGui's `AbsoluteSize` (skip inside ScrollingFrames); GuiButton/TextBox < 44 px; `TextFits == false` with `TextTruncate == None`; any overlap among shown `ChristmasMarketUI.Hud`, `HudRailUI.Rail`, `ChristmasMarketNotifications.Toast`, `StockingUI.StockingBar`.
- Capture ids `uv-<item><n>`, each with one sentence of what it shows.

## Playtest (Studio, via playtester), in this order
**P0** `list_roblox_studios` ("Weihnachtsmarkt", aca5cb45-c85d-4683-8d43-0f8022a2cec9), `get_studio_state`, D1, D2.

**(a)** `start_stop_play` true; wait for both DMs and `LocalPlayer.Character`. Client `CurrentCamera.ViewportSize` > 100×100 and capture `uv-a1` shows the 3D world (snow, plots, sky) → PASS; else stop, all BLOCKED, PC-3 `offen`.

**(g)** `H("runPlaytest", {mode="full"})` → `"started"`; poll `ServerStorage.PlaytestStatus` to `done`; `PlaytestSummary` `mode=full steps=41 pass=41 fail=0` (ends on "Playtest A"). PASS = this + the reviewer's checks on the same HEAD.

**(f) HUD and Lot Manager** (PC):
1. Capture `uv-f1`; `probe{ChristmasMarketUI, HudRailUI}` empty. Click `Rail.LotManagerButton` (D4) → `LotManager.Visible`.
2. Click `TabBar.Tab_<id>` for the 6 tabs, capture each (`uv-f2`…`f7`): Supplier scrolls (wheel) until `SellBackTree` is inside the page; the other 5 show `Placeholder`.
3. Click `CloseLotManager` once → hidden. `user_keyboard_input` M → open; M → closed.
4. Server `Remotes.Notify:FireClient(player, {key="wrongCar", args={3, 5}})`; within 3 s capture `uv-f8`; `probe{ChristmasMarketUI, HudRailUI, ChristmasMarketNotifications}` empty; Toast = en `wrongCar` with 3, 5.
5. Modal rule: Lot Manager open, click `TeamButton` → `TeamUI.TeamPanel` shown, Lot Manager hidden. Footers: (b)–(d).

**(h) Pricing tab** (PC): open the Lot Manager, `Tab_Pricing`, capture `uv-h1`. Click `Price_DouglasFir.Plus1`, `Minus1`, `Plus5`, `Minus5`; after each, within 2 s the card `Price` text contains `"$" .. UiTheme.formatMoney(m)` (m = Douglas medium price in `Company.GetSummary` `data.pricing`). Click `AutoPricing` → summary `automatic` true; click `Plus1` → false. Scroll until `Price_BlueSpruce` is inside the page; capture `uv-h2`. Restore with `Pricing.SetMediumPrice {speciesId="DouglasFir", mediumPrice=<start>}`.

**(b) Save picker** (PC): `SavesButton` → `SavePickerUI.Picker` shown, ≥ 2 `SaveRow_`, `AbsolutePosition.Y >= 0`, inside the gui; capture `uv-b1`. "UV Test" into `NewSaveName`, `CreateSave` → row and `H("saves", R)` entry. Row `Rename` → `NameBox` "UV Test 2" → `Rename` → listed. `Delete` → `DeleteConfirm`, `ConfirmDelete.Active == false`; "uv test" → false; "uv test 2" → true; capture `uv-b2`; `ConfirmDelete` → row and save gone.

**(c) Save footer and Team** (PC): picker `Size_Duo`, "UV Duo", `CreateSave` → listed as Duo; capture `uv-c1` (toggles, `JoinCode`, `JoinSave`). Its `Play` → `ActiveSaveSize == "Duo"`. `TeamButton` → `TeamPanel`; `CodeLine` shows `sa(R, "Save.Team", {}).inviteCode`. `H("shadowJoin")`, `sa(SH, "Save.Join", {code})`, `sa(SH, "Save.Play", {saveId})`; reopen Team → 2 `Member_` rows; capture `uv-c2` (owner footer). `NewCode` → new code shown. `Size_Solo` → `TeamStatus` SizeTooSmall text. Cleanup: SH plays its first save, player plays "Playtest A", delete "UV Duo".

**(d) Elsewhere row and finder** (PC):
1. `sa(R, "Save.Create", {name="UV Far", size="Duo"})`, play it, play "Playtest A", `H("placeElsewhere", {userId=R, saveId})`, `H("lockSave", same)`. Picker row: "Being played by …" or "… on another server" with Join; capture `uv-d1`. Join → `PickerStatus` "Moving between servers does not work here."; capture `uv-d2`. `clearElsewhere`, `unlockSave`, delete "UV Far".
2. `sa(SH, "Save.FinderStart", {size="Duo"})`. Picker `FindTeammates` → `FinderUI.FinderPanel` on top, `Listing_1`; capture `uv-d3`. `JoinListing` → within 4 s `ActiveSaveRole == "Member"`. Team → `LeaveTeam`, no `NewCode`; capture `uv-d4`. `sa(R, "Save.LeaveTeam", {saveId})`, play "Playtest A".
3. `FinderButton` → `Size_Duo`, `StartListing` → `OwnListing`, `StopListing`; capture `uv-d5`; `StopListing`. Cleanup: play "Playtest A"; delete both finder saves (SH first `FinderStop` and plays its first save); `H("shadowLeave")`.

**(i) Stocking** (PC; Server `H("pauseCustomers", true)`):
1. `Supplier.PlaceOrder {speciesId="DouglasFir", sizeId="Medium", quantity=6}` (no clock advance; SupplierOutOfStock → `advanceClock 240`, once). H3 at `Receiving/Bay_<data.bay>`: `uv-i1` countdown (BayArriving), `uv-i2` `DeliveryTruck`, `uv-i3` landed (BayContents +6).
2. `character_navigation` to the bay, E → `StockingUI.StockingBar`; capture `uv-i4`; `probe{StockingUI, HudRailUI}` empty.
3. `Size` until `Header` shows Medium; `Rotate`, `GapUp`, `GapDown` (Gap text changes, returns). `aim` at a free SLOT (x {−35, −28} × z {−13, −6, 1, 8}, ≥ 5.6 from placements): green ghost, empty `Reason` (`uv-i5`). `aim(39.5, 0)`, `aim(16, -10)`, 2 studs from a tree: red, `Reason` = en `stockOutsideLot`, `stockKeepClear`, `stockTooClose` (`uv-i6`…`i8`).
4. Click the world at the free spot → placementCount +1. Store (hook) any placement within 3 of lot z −20; `Row`, `aim(-35, -20)`, click → +5; capture `uv-i9`.
5. `Store`, aim at a tree → `StoreTarget`; click → bay +1, placements −1; `Store` again (Put back off); `Done` → bar gone.

**(e)+(j) Customers** (PC; customers paused):
1. ≥ 3 Douglas Medium on display (else `Stock.Place` singles at free SLOTS, count 1, rotation 0, gap 0.5). `H("npcVisit", {userId=R, profile=8})`, 1 s later `profile=20`. Poll `npcSnapshot` every 1 s, H3 at:
   - Browsing: close-ups, clothing differs (`uv-j1`); WalkingToTree: RESERVED (`uv-j2`); WalkingToQueue: carried-tree pose (`uv-j3`).
   - Queued + CheckingOut at once: queue (`uv-j4`); right after CheckingOut: "Thanks so much!" (`uv-j5`).
   - WaitingAtCar: `CustomerCar_<n>` with "#N HERE" and the avatar beside it (`uv-e1`, `uv-j6`); `PickupTree_<n>` with "Order #N · PICK UP" (`uv-e2`).
   - Then `H("prompt", {userId=R, kind="carry", number=n})` and `kind="load"` for each; within 30 s `npcSnapshot.count == 0`.
   - No queue seen: retry once with profiles 8, 20, 32 0.5 s apart; still none → BLOCKED (setup).
2. **V1** exactly as CM2-N1 Fix round 2, Playtest 2 (captures `uv-j7`, `uv-j8`), with its PASS rule. Record the stall front (toward/away from the road); away = finding → fix task (D6), not a V1 FAIL.

**End:** camera Custom, `npcReset`, `pauseCustomers false`, player on "Playtest A", no UV save in `saves`, `start_stop_play` false. Quote every `[ChristmasMarket2]` error/warning.

**Size checklist (D2):** f1, f4 (rail clears thumbstick/jump; Lot Manager hides HUD and rail on phone), b1, c1, c2, d3, d5, h2, i4, j1, j6.

## Evidence (PROGRESS.md, reviewer)
Entry `<date>: CM2-UV UI verification`: HEAD, BUILD, viewport, D4 variant, D2 result, then:
| Item | Result | Evidence |
|---|---|---|
| (a) … (j) | PASS / FAIL / BLOCKED, or `PASS (PC); phone, tablet BLOCKED (D2)` | capture ids + what each shows + values read back; FAIL rows name `CM2-UVF<n>` |
Captures are not committed. The planner adds "CM2-UV (<item>): <result>" to the status of S1, S2, S3, G21, CM2-40, G7, G14, N1.

## Acceptance
- Checks (reviewer, same HEAD): `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (380 run, 0 failed), `rojo build default.project.json --output build.rbxlx`, `rojo build release.project.json` (0 instances named UnitTest, RunPlaytest, StudioTestService).
- (a), (g) PASS; every item has a row with captures; each FAIL has a `CM2-UVF<n>` task; no source change.
- Backlog: 5b ticked when (a)–(j) are PASS on PC or routed (FAIL → UVF, phone/tablet → CM2-UV2). PC-3 → `erledigt` when (a) passed and D5 never stopped the run.

## Out of scope
Fixing defects (D6); 2-client runs, teleports (order 15); gamepad; portrait.

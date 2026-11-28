# Progress log

Older entries: one file per task or day in [archive/](archive/) named `PROGRESS_<first date>_to_<last date>[_<task ID>].md`, from 2026-11-19. Find an ID with `grep -rn <ID> docs/archive/`; read them only when a task needs that history.
Archived 2026-11-25 (entries CM2-UVF13 step 1, CM2-UVF12, CM2-UVF11, CM2-SLIM4, CM2-SLIM2, CM2-SLIM3): [archive/PROGRESS_2026-11-25_to_2026-11-25_CM2-UVF13-SLIM.md](archive/PROGRESS_2026-11-25_to_2026-11-25_CM2-UVF13-SLIM.md).
Archived 2026-11-25 (entries N1 rest part A, CM2-SLIM5, CM2-SLIM4b, CM2-UVF13): [archive/PROGRESS_2026-11-25_to_2026-11-25_N1rest-A-SLIM-UVF13.md](archive/PROGRESS_2026-11-25_to_2026-11-25_N1rest-A-SLIM-UVF13.md).
Archived 2026-11-26 (entries CM2-SALE1, N1 rest part B, CM2-UVF14): [archive/PROGRESS_2026-11-25_to_2026-11-25_SALE1-N1B-UVF14.md](archive/PROGRESS_2026-11-25_to_2026-11-25_SALE1-N1B-UVF14.md).
Archived 2026-11-26 (entries CM2-ASSETWARN, N1 (b) re-run of line 14, CM2-PT35b, CM2-PT53): [archive/PROGRESS_2026-11-25_to_2026-11-26_ASSETWARN-N1b-PT35b-PT53.md](archive/PROGRESS_2026-11-25_to_2026-11-26_ASSETWARN-N1b-PT35b-PT53.md).
Archived 2026-11-26 (entries CM2-12W, CM2-46c, CM2-G12b, CM2-SALE2 incl. Amendment 1 and the Early-lot demand entry): [archive/PROGRESS_2026-11-26_to_2026-11-26_12W-46c-G12b-SALE2.md](archive/PROGRESS_2026-11-26_to_2026-11-26_12W-46c-G12b-SALE2.md).
Archived 2026-11-27 (entries CM2-G11, CM2-SLIM run 2, CM2-13W): [archive/PROGRESS_2026-11-26_to_2026-11-26_G11-SLIM2-13W.md](archive/PROGRESS_2026-11-26_to_2026-11-26_G11-SLIM2-13W.md).
Archived 2026-11-27 (entries CM2-PP, CM2-FAST, CM2-FLICK): [archive/PROGRESS_2026-11-26_to_2026-11-27_PP-FAST-FLICK.md](archive/PROGRESS_2026-11-26_to_2026-11-27_PP-FAST-FLICK.md).
Archived 2026-11-27 (entries CM2-SUP, CM2-GATE, CM2-A1, CM2-GATEW, CM2-45, CM2-TUTHOOK): [archive/PROGRESS_2026-11-27_to_2026-11-27_SUP-GATE-A1-GATEW-45-TUTHOOK.md](archive/PROGRESS_2026-11-27_to_2026-11-27_SUP-GATE-A1-GATEW-45-TUTHOOK.md).
Archived 2026-11-28 (entries CM2-SUPQ, CM2-SUPC, CM2-14W, CM2-SLIM run 3): [archive/PROGRESS_2026-11-27_to_2026-11-27_SUPQ-SUPC-14W-SLIM3.md](archive/PROGRESS_2026-11-27_to_2026-11-27_SUPQ-SUPC-14W-SLIM3.md).
Archived 2026-11-28 (entries CM2-SLIM run 4, CM2-UI3M, CM2-UI3D, CM2-UI3 part 1, CM2-UI2, CM2-UI1): [archive/PROGRESS_2026-11-27_to_2026-11-28_SLIM4-UI3M-UI3D-UI3-UI2-UI1.md](archive/PROGRESS_2026-11-27_to_2026-11-28_SLIM4-UI3M-UI3D-UI3-UI2-UI1.md).
Archived 2026-11-28 (entries CM2-43, CM2-14WR, CM2-LEAK22, CM2-HOOKSA, CM2-10D, CM2-10DW, CM2-SLIM8): [archive/PROGRESS_2026-11-27_to_2026-11-28_43-14WR-LEAK22-HOOKSA-10D-10DW-SLIM8.md](archive/PROGRESS_2026-11-27_to_2026-11-28_43-14WR-LEAK22-HOOKSA-10D-10DW-SLIM8.md).
Archived 2026-11-28 (entries CM2-10I batches B1-B3, CM2-10IW, CM2-SLIM run 5, CM2-47): [archive/PROGRESS_2026-11-28_to_2026-11-28_10I-10IW-SLIM5-47.md](archive/PROGRESS_2026-11-28_to_2026-11-28_10I-10IW-SLIM5-47.md).
Archived 2026-11-28 (entries CM2-47D2, CM2-SLIM10, CM2-SLIM run 6, CM2-48, CM2-50a, RELEASE_CHECKLIST Part B evidence): [archive/PROGRESS_2026-11-28_to_2026-11-28_47D2-SLIM10-SLIM6-48-50a-RELCHK.md](archive/PROGRESS_2026-11-28_to_2026-11-28_47D2-SLIM10-SLIM6-48-50a-RELCHK.md).
Archived 2026-11-28 (entries CM2-RC3, CM2-MUSIC, CM2-UICLIP, CM2-RC2, CM2-PARK, CM2-LOTLAY): [archive/PROGRESS_2026-11-28_to_2026-11-28_RC3-MUSIC-UICLIP-RC2-PARK-LOTLAY.md](archive/PROGRESS_2026-11-28_to_2026-11-28_RC3-MUSIC-UICLIP-RC2-PARK-LOTLAY.md).

## 2026-11-28 CM2-UIFIX Nothing cut off, readable headings (tier M, plan incl. Amendment 1)
- Changes: desktop rail inset 6 px (`UiTheme.RailInset`), status line as a Panel plate 44/30 under the chips showing "Plot <n>" (`UiTheme.plotNumber`), headings Nunito Heavy 22 without stroke (`UiTheme.Heading`), Studio hook action `probe` in `UiKit`; docs/UI_STYLE.md updated.
- Checks: stylua PASS; selene 0 errors, 0 warnings, 0 parse errors; headless 801 run, 801 passed, 0 failed (796 + 5); ui_scan 0 (implementer); rojo build PASS.
- Studio (playtester, run now, desktop 1564x730): smoke 13/13. Probe HUD: problems [], checked 11, railLeft 18, statusTop 56 >= chipsBottom 48 + 8, SaveStatus "Playtest A · Plot 1". Lot Manager all 6 tabs problems []. Land heading Nunito Heavy 22, no UIStroke/TitleOutline, TextFits. Shop, Quests, Saves, Team problems [].
- Screenshots: BLOCKED (play capture black, known); the before/after views rest on the probe numbers. Phone and tablet readings: not run, CM2-UIP queue (PC-14).
- Known (not a defect): the Saves window has no close button because it is the modal base layer (`SavePicker.client.lua`); the "Back to game" button appears once `CompanyReady`.
- Own decisions (all minor): viewport from `CurrentCamera.ViewportSize`; statusTop/chipsBottom read from `ChristmasMarketUI/Hud`; problem strings "<path> <kind> <numbers>"; status label keeps `TextTruncate AtEnd` with `TextScaled`.


## 2026-11-28 CM2-V2-SNOW, CM2-V2-HIDE, CM2-SLIM9 (launch item 0c, tier S, no plans, one implementer run)
- SNOW: `GameConfig.Snow` + `snowRate`, new `src/client/Snow.client.lua` (camera-attached emitter, quality gate 1-3 off), GameConfig_Test +1. HIDE: `UiTheme.HudHideGuis` (9), `UiKit.setHudHidden/isHudHidden`, rail button slot 90 and key U, en/de strings, UiTheme_Test +1; hidden rail buttons are reparented into a non-rendering Folder (connections and own Visible survive). SLIM9: test comment and MODEL_INTEGRATION note, no src change.
- Checks (reviewer): stylua PASS; selene 0 errors, 0 warnings, 0 parse errors; headless 836 run, 836 passed, 0 failed; ui_scan 0 hits; rojo default build PASS.
- Own decisions reviewed (all minor): emitter reattached on camera change, Rotation 0-360, Acceleration 0, BrickColor.White().Color, HIDE only while CompanyReady (auto-shows when it turns false), ChildAdded watcher, 9-entry list test.
- Note: Tutorial `lotManagerButton()` finds nothing while the HUD is hidden (button stashed), harmless; HUD probe must be run after showing again.
- Studio: deferred (batch), runs inside CM2-RC4 (texture load, snow, key U, rail shows only "Show HUD", probe 0, SLIM9 warning only in the Trees step); queued in "Studio-Test ausstehend". Not run.

## 2026-11-28 CM2-V2-ORD Recent orders with status (launch item 0c, tier M, plan `docs/plans/CM2-V2-ORD.md`)
- Changes: new `src/shared/OrderStatus.lua` (group, session memory, status), `deliverySummary` adds read-only `groupId`, `createdAt`, `cost` (`wholesaleFor * quantity`, same table `SupplierCart` charges with) and `arrivesIn`, list cap `GameConfig.MaxOpenOrders`; `Supplier.RecentOrders = 4`; `supplierPanelLayout` optional third arg `orderRows`; Supplier tab block (4 rows, title); 4 strings en/de.
- Checks (reviewer): stylua PASS; selene 0 errors, 0 warnings, 0 parse errors; headless 845 run, 845 passed, 0 failed (836 + 9); ui_scan 0 (implementer); rojo default build PASS.
- Security: summary stays `{}` payload, own company only, read-only; no new remote, save field or validation; payload grows by 4 small fields per entry, at most `MaxOpenOrders` entries.
- Own decisions reviewed (all minor): param `clockNow`, `OrderStatus` requires `script.Parent.GameConfig`, non-finite numbers count 0, `renderOrders` at the end of `renderView`, `track` called in `render` after `lastSummary`.
- Studio: deferred (batch), runs inside CM2-RC4 (probe 0, Preparing -> In Transit -> Delivered, save switch clears rows); queued in "Studio-Test ausstehend". Not run.


## 2026-11-28 CM2-V2-HIDE rail fix (tier S, plan `docs/plans/CM2-V2-HIDE.md` incl. Amendment 1; found by the CM2-RC4 Studio run)
- Changes: scrolling desktop rail (`UiTheme.RailScrollBar` 4, `HudLayout.railCanvas`, 130 px buttons while it scrolls, explicit `CanvasSize`, `CanvasPosition` reset), pure `UiTheme.fitsScroll` (bar subtracted once from the frame box) used by `probeGui` and `probeRail` through the UiKit wrapper. Plan A1.3 text corrected to the readings used (y 135 and 490).
- Checks (reviewer): stylua PASS; selene 0 errors, 0 warnings, 0 parse errors; headless 848 run, 848 passed, 0 failed (845 + 3 tests); ui_scan 0 (implementer); rojo default build PASS.
- Studio (playtester, 924x612, rail 12,166 148x376, canvas 406, scrolls): state reset (bays 4 -> 0 via sell-back), smoke 13/13; HUD probe shown problems 0 (railLeft 18); click HideHudButton at the bottom -> hidden 9/9, problems 0; click Show -> 8 buttons back, problems 0; hover probe 0 (hover state not independently confirmed); key U both ways problems 0; Supplier probe 0. Clicks by instance path.
- Console: error from the tester's own AssistantCommand script (Saves:5 ACTION_PAUSE) and the known ContentId warning; no game error.
- HIDE removed from "Studio-Test ausstehend" (passed). CM2-RC4 stays open: its full run follows on the new HEAD.

## 2026-11-28 CM2-RC4 (tier S, launch item 0c; release candidate `a8c8ef3`, code identical to `24812b3`; `f181bb9`, `ce265b6`, `debc1cb` superseded, not published)
- Run 1 on `ccdcc62`: unit 844/844; full run 80/80 PASS (901 s); soak 8/8 (03a min 57.9 / mean 59.8 FPS, 03b worst 0.000, 04 clean); SNOW emitter and texture OK (`rbxasset://textures/particles/sparkles_main.dds`, live rate 60 = `snowRate(0)`); ORD rows "1 trees · $28 · Preparing order · ETA 0:29" -> In Transit -> Delivered, Supplier probe 0; SLIM9 warning only at step 64 (expected). HUD probe FAILED -> fixed by `24812b3` (HIDE rail fix, smoke 13/13).
- Final run on `a8c8ef3`: unit 847/847; full run `steps=80 pass=79 fail=1 seconds=890 result=FAIL`; the only FAIL is step 37 NPC_WALK (`visit:5 snapped 1 time(s): visit:5 WalkingToQueue@(-16.1,21.0)->(-14.0,23.0)`). Re-run of step 37 PASS ("3 customers walked, paid and left"). Accepted as a known flake (backlog CM2-RC4 note; no server code changed since `ccdcc62`, where 37 passed); follow-up 37d CM2-NPCSNAP. HUD probe shown/hidden/shown problems 0, railLeft 18.
- Checks (reviewer, HEAD `a8c8ef3`): stylua PASS; selene 0 errors, 0 warnings, 0 parse errors; headless 848 run, 848 passed, 0 failed. Release build (main session, `../cm2-release` at `a8c8ef3`): `[ART] 61 integrated, 0 pending, 0 failed`, 0 `StudioTestService` instances.
- Known untested: snow quality 1-3 stopping the snow (BLOCKED, MCP cannot set quality); ORD save switch clearing the rows; phone readings of snow, hide HUD and recent orders -> CM2-UIP queue.
- Docs: `docs/RELEASE_CHECKLIST.md` (line 17, B6 step 1) and the backlog (header, "Für dich am PC", Status, Release build, item 0/0c, PC-16) name `a8c8ef3`; CM2-RC4 and item 0c ticked; SNOW, ORD, SLIM9 left "Studio-Test ausstehend" (one "CM2-RC4 residual" line stays).

## 2026-11-28 CM2-VIBE1 Light and colour pass (tier M, plan `docs/plans/CM2-VIBE1.md`)
- Changes: `GameConfig.Lighting` (Static, Day, Night; `DayCycle.NightOutdoorAmbient` moved into it, no other reader), pure `shared/LightingBlend.lua`, `DayNight.client.lua` blends Lighting plus four `CM2*` effects by `nightBlend` (write only on > 0.001 change; Bloom and SunRays off at quality 1-3), identical `Lighting` node (Technology Future, shadows) in `default.project.json` and `release.project.json`.
- Checks (reviewer): stylua PASS; selene 0 errors, 0 warnings, 0 parse errors; headless 855 run, 855 passed, 0 failed (includes `LightingBlend_Test` and the 2 project-file checks); `rojo build` default and release both OK; `release.project.json` still ignores `StudioTestService`.
- Implementer own decisions (minor, allowed): require path, only colour arrays rounded, two-way key assert, `table.clone`, colours 4 decimals.
- Studio: deferred (batch), runs inside CM2-RC5 (client readings at ClockTime 14 and 22, NightLight, snow rate 60, step 61, probe 0; note the `rojo serve` Technology caveat). Not run, nothing claimed.

# CM2-UI1 — Style kit: tokens, button interaction, window chrome (22a1)

## Goal
Buttons, tabs and windows get the CM2-UI kit: decorations, hover/press motion, click sound, shadow and open motion, tab indicator, toast slide. Colours, layouts, behaviour unchanged.

## Source of truth
Backlog 22a1 (22a (b)–(e)); PRODUCT_SPEC "UI look"; DECISION_LOG 2026-11-26. (a): no owner images in `docs/art/ui-reference/`, so PRODUCT_SPEC sets the target.
18a1 CM2-SUPC is order-only (launch list; committed a8b89ea); its open phone readings measure sizes, which 22a1/22a2 keep. Runs now.

## Implementer tier
Tier: M. Reason: client-wide kit, tweens, Studio hook over ~20 files; no money, save or remote change.

## Skill checks
- gui: one `UIStroke` per object; kit strokes `Border`, title outline `Contextual`.
- gui: motion only through `UIScale` (layout never moves); `UIGradient` tints text, so it is a grey multiplier.
- gui: weights via `FontFace`; a new tween replaces the old one on that property.
- input: hover only from `MouseMovement`; touch gets only the press; actions stay on `Activated`.
- architecture: pure specs in shared, Instances only in `UiKit`.
- patterns: hook only if `RunService:IsStudio()`, calling the click's handler.

## Files
| File | Change |
|---|---|
| src/shared/UiTheme.lua | tokens, `fontFace` |
| src/shared/UiStyle.lua (new) | pure interaction and decoration specs |
| src/client/UiKit.lua | kit functions, Studio hook |
| 17 client files (Steps 4–7) | kit calls |
| WorldService, MapWorld, LotGateWorld (server) | 4 font lines |
| tests/headless/run.luau | register `UiStyle` |
| tests/studio/Cases/UiStyle_Test.lua (new), tests/tools/ui_scan.luau (new) | tests |

## Data and config (UiTheme; PROVISIONAL look values except those named in 22a)
- `Colors` add `Outline {22,48,34}`, `Shadow {0,0,0}`, `Toast {24,74,50}`, `Valid {114,172,113}`; others unchanged.
- `Fonts = { Family = "rbxasset://fonts/families/Nunito.json", Weights = { Title = "Heavy", Body = "Bold", Light = "SemiBold" } }` (replaces Bold/Regular). `UiTheme.fontFace(role): Font` = `Font.new(Family, Enum.FontWeight[Weights[role]])`
- `TextSize` add `Input 16`, `Arrow 36`, `WorldArrow 40`. `CornerRadius.Panel` 14 → 12.
- `Style = { StrokeControl 2, StrokeSelected 3, StrokeCard 1, StrokeTitle 1.5, StrokeTransparency 0.15, GradientBottom 0.92, ShadowOffset 4, ShadowTransparency 0.7, DimTransparency 0.45 }`.
- `Motion = { hoverScale 1.05, hoverTime 0.15, pressScale 0.95, pressTime 0.08, releaseTime 0.15, openScale 0.95, openTime 0.18, closeTime 0.12, toastTime 0.2, toastSlide 12, tabTime 0.2, indicatorHeight 4 }`.
- `ClickSound = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.5 }`: engine content on every client; no asset ID, upload or licence (22a (b) deviation: no AUDIO.md before CM2-G18; 22a2 notes the source in `docs/UI_STYLE.md`).

## Steps
1. `UiStyle`: `type Kind = "button"|"tab"|"card"|"window"`, `type DecorSpec = {className, name, props}` (plain values).
   - `interaction(state, hovering: boolean?) -> {scale, time, style: "Quad"|"Back", direction: "Out"}`: idle 1/0.15/Quad; hover 1.05/0.15/Quad; press, touchPress 0.95/0.08/Quad; release (1.05 if hovering else 1)/0.15/Back; unknown → idle.
   - `decorations(kind) -> {DecorSpec}`: button, tab: `UIScale "Press"`, `UICorner "Corner"` 8, `UIStroke "Outline"` 2 Border colour Outline transp. 0.15, `UIGradient "Shade"` rotation 90 top 1 bottom 0.92. card: Corner 10, Outline 1. window: Corner 12, Outline 2, Shade, `UIScale "Open"`.
2. `UiKit.decorate(target, kind)`: builds the specs; reuses a child of same class and name; destroys an unnamed `UICorner` first.
3. UiKit:
   - `label`: `FontFace` Body; `textSize >= TextSize.Title` → Title face plus `UIStroke "TitleOutline"` (Contextual, Outline, 1.5).
   - `button`: Body face, `AutoButtonColor = false`, decorate "button"; `InputBegan` MouseMovement → hover, MouseButton1 → press, Touch → touchPress; `InputEnded` MouseMovement → idle, MouseButton1/Touch → release (tracked hovering); tween `Press.Scale` per `interaction`; skip while `Active == false`.
   - `textBox`: Light face, `TextSize.Input`, decorate "card".
   - `onActivated(button, handler): RBXScriptConnection`: stores the handler (weak keys) for the hook; `Activated` → `SoundService.UiClick:Play()` (one Sound, `ClickSound` values), then `handler(...)`.
   - `setSelected(button, selected)`: Outline 3 Cream / 2 Outline. `setOutlineColor(button, color)`.
   - `window(frame, options: {dim: boolean?}?)`: decorate "window"; sibling `<Name>Shadow` Frame (Shadow, corner 12, `Active=false`, ZIndex frame−1) mirrors AnchorPoint, Size, Position+(4,4). `dim`: frame ZIndex ≥ 3, sibling `<Name>Dim` (fromScale(1,1), Shadow, `Active=false`, ZIndex frame−2). Visible true → `Open.Scale` 0.95→1 0.18 s Quad Out, shadow 1→0.7, dim 1→0.45. Visible false → frame hides at once; shadow and dim fade to 1 in 0.12 s, then hide. Already visible at call → shown state, no tween.
   - `card(frame)`: decorate "card". `animateToast(toast, box, shown)`: shown → y from box.y−12, background and text transparency 1→0 in 0.2 s; hidden → to 1 in 0.2 s (caller owns `Visible`).
   - Studio hook: `BindableFunction "StudioUiHook"` under `Players.LocalPlayer`. `Invoke("press", path)` (`/` path from PlayerGui) → `{ok=false, error="NotFound"|"Hidden"|"NoHandler"}` (Hidden: it or an ancestor not Visible, ScreenGui not Enabled) or runs each handler in `pcall` → `{ok=true, handlers=n}`. `Invoke("interact", path, state)` applies that state → `{ok=true}`.
4. Every `<expr>.Activated:Connect(` (65 sites) → `UiKit.onActivated(<expr>, `.
5. Windows (replace the `CornerRadius.Panel` corner): `UiKit.window(...)` in AdventPanel, BreakAreaMode, EventShopPanel, LotManager, QuestPanel, ShopPanel, StockingMode, TeamPanel; TeammateFinder `{dim=true}`; PlotPicker `frame()`; SavePicker `dialogFrame(name, dim: boolean?)`, `DeleteConfirm` with `true`.
6. Cards (`UiKit.card` replaces the row corner): EventShop 176, Quest 219, SavePicker 358, Shop 170, Team 202, Finder 228, EmployeesTab 103, LandTab 103, PricingTab 142, UiController 38, Tutorial 36, WorldLabels 257.
7. Selection and literals:
   - LotManager: no `Selected` strokes, `updateTabs` → `setSelected` (Gold fill stays). `Frame "Indicator"` in TabBar (Cream, h 4, ZIndex 2) at x tab+6, w tab−12, y tab bottom−6; tween 0.2 s Quad Out on `selectTab`, instant on layout.
   - SupplierTab `modeButton` returns only the button, mode update → `setSelected`. AdventPanel special doors → `setOutlineColor(button, GOLD)`.
   - Break/Stocking `VALID_COLOR`/`INVALID_COLOR` → `Colors.Valid`/`Red`; Tutorial arrows Title face, `TextSize.Arrow`/`WorldArrow`; Leaderboards `fontFace(if you then "Title" else "Light")`; toast `Colors.Toast`, Body face, `animateToast` on show and at 2.8 s; server `Font = Enum.Font[UiTheme.Fonts.Bold]` → `FontFace = UiTheme.fontFace("Title")` (WorldService 253, 500; MapWorld 78; LotGateWorld 85).

## Tests (headless)
| Test case file | Test name | Asserts |
|---|---|---|
| UiStyle_Test | interaction returns the CM2-UI scales and times | Step 1 |
| UiStyle_Test | button and tab decorations | one each: Press, Corner 8, Outline 2 Border, Shade |
| UiStyle_Test | card and window decorations | card corner 10, stroke 1; window corner 12, stroke 2, Open |
| UiStyle_Test | gradient is a grey multiplier within 8 % | top 1, bottom ≥ 0.92 |
| UiStyle_Test | motion and style tokens match 22a | all Motion, Style values; ClickSound `rbxasset://`, 0.5 |
| UiStyle_Test | font roles | Nunito path; Heavy, Bold, SemiBold |
`ui_scan.luau` (Lune, exit 1, prints file:line): `src/client` has no `Color3%.fromRGB%(%s*%d`, `Color3%.new%(%s*[%d%.]`, `Enum%.Font%.`, `Font%.new%(`, `TextSize%s*=%s*%d`; `src` has no `swarve` (any case) and no 7+ digit ID from `assets/third_party/swarve-essential-ui/INVENTORY.md`; no `rbxassetid` in `src/client` or `UiTheme.lua`.

## Playtest (Studio, via playtester)
Desktop, no clicks: client `Players.LocalPlayer.StudioUiHook` opens screens, server `StudioTestHook` `saveAction` picks the save; wait 0.3 s per press; read instances (`screen_capture` optional).
1. Hook exists; `SoundService.UiClick` SoundId as config, Volume 0.5, `IsLoaded`, `TimeLength > 0`.
2. press `HudRailUI/Rail/LotManagerButton` → `{ok, handlers=1}`; `ChristmasMarketUI.LotManager` visible, `Open.Scale` 1; `LotManagerShadow` visible, 0.7, at +4/+4.
3. press `ChristmasMarketUI/LotManager/TabBar/Tab_Supplier` → its Outline 3 Cream, others 2; `Indicator` under it.
4. interact `Tab_Pricing` hover → `Press.Scale` 1.05; press → 0.95; idle → 1.
5. Every shown `GuiButton` in our ScreenGuis has Press, a UICorner, Outline (0 missing), height ≥ 44.
6. press `.../CloseLotManager` → hidden at once; shadow hidden after 0.3 s.
7. press `HudRailUI/Rail/SavesButton`, then `HudRailUI/Rail/FinderButton` → `FinderUI.FinderPanelDim` visible, 0.45, ZIndex below `FinderPanel`.
8. Server `Remotes.Notify:FireClient(player, {key="wrongCar", args={3,5}})` → Toast visible, transparency 0, at its box.
9. H4b probe (`docs/archive/plans/CM2-UV.md`) with LotManager (each tab), Shop, Quests, Advent, Event, Team, Finder over Picker in turn: 0 violations.
10. `runPlaytest {mode="full"}`: 74 steps PASS. Phone and tablet: 22a4 (PC-14).

## Acceptance
- `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (771 = 765 + 6), `lune run tests/tools/ui_scan.luau` (0 hits), `rojo build`.
- Playtest 1–10 PASS; remotes, error codes, string keys, save fields, layout functions and `Visible` timing unchanged.
- Deviations (reviewer logs them): close 0.12 s = shadow/dim fade, window hides at once (keeps modal and test state); open fade = shadow/dim (CanvasGroup clips strokes); engine click sound.

## Out of scope
Palette, header bands, style guide, ui-reference README (22a2); phone limits, plot-picker overlap (22a3); phone and tablet readings (22a4); settings screen (none exists).

## Amendment 1 (2026-11-27, implementer questions)
**A. `AutoButtonColor` in client files: remove.** The kit owns hover/press feedback (Step 3); engine darkening on top of the UIScale motion is a double effect. Disabled state is already shown by each site's own colour, `TextTransparency` or `Active`; that stays unchanged.
- Delete these lines (only the `AutoButtonColor` assignment; neighbouring lines stay): AdventPanel 188; BreakAreaMode 179; EventShopPanel 216; EmployeesTab 168; LandTab 197; SupplierTab 100, 576, 588; PlotPicker 170; QuestPanel 64; SavePicker 247; ShopPanel 205; StockingMode 281, 534 (the `if id == "Gap"` block becomes empty: delete the whole `if`).
- `UiKit.lua:405` (`AutoButtonColor = false` in `button`) stays; it is the only one.
- Any `local` that becomes unused (selene) may be removed; no other change.
- Test: `ui_scan.luau` gets one rule: a `src/client` line containing `AutoButtonColor` outside `src/client/UiKit.lua` is a hit (`"AutoButtonColor outside UiKit"`). Acceptance stays 0 hits; headless count stays 771. Playtest step 5 adds: every shown `GuiButton` has `AutoButtonColor == false`.
- Known gap (reviewer logs it, UI2 decides): buttons disabled only by colour/transparency while `Active` stays true (SupplierTab `setEnabled`, BreakAreaMode, StockingMode, EmployeesTab, LandTab) still get the hover/press scale. Clicks keep their existing guards.

**B. `WorldService.lua:524` `CornerRadius.Panel` on the lot sign: leave it.** The sign follows the panel token (14 → 12 px at its PixelsPerStud, a visual-only change; no test or layout depends on it). Reviewer logs it as a deviation: "world lot sign corner 12 instead of 14".

# UI style guide (CM2-UI2)

Tokens live in `src/shared/UiTheme.lua`, pure rules in `src/shared/UiStyle.lua`, Instances in `src/client/UiKit.lua`. Look values are PROVISIONAL.

## Colors (`UiTheme.Colors`)
- Panel (cream 255,244,217): windows, HUD chips, bars. Row (246,231,196): cards, rows. ListWell (236,218,178): list wells. Toast: toast surface.
- Header (dark green 20,68,48): window title bands. Primary (38,89,63): main actions.
- Gold: selection, progress, money fills. GoldText (128,88,16): money and highlight text on cream.
- Sand: neutral buttons and tabs. Red (168,62,54): close and danger. Disabled (104,104,104): disabled fill.
- DarkText: text on light fills. Cream: text on Primary, Header, Red, Disabled. Muted (92,80,56): secondary text on cream. Placeholder: input hints.
- Outline: strokes. Shadow: shadows and dim layers. Valid: positive ghost.

## Other tokens
- Fonts: Nunito; Title Heavy, Body Bold, Light SemiBold (`UiTheme.fontFace(role)`).
- TextSize: Title 22, Body 15, Small 13, Chip 16, Input 16 (plus Arrow sizes for the tutorial).
- CornerRadius: Button 8, Row 10, Panel 12. MinTouch 44 px.
- Style: strokes (Control 2, Selected 3, Card 1, Title 1.5), GradientBottom 0.92, shadow offset 4, dim 0.45, HeaderInset 10 px.
- Motion: hover 1.05 in 0.15 s, press 0.95 in 0.08 s, release 0.15 s (Back), open 0.95 to 1 in 0.18 s, close 0.12 s, toast 0.2 s.

## Rules
- Text colour comes from `UiKit.textOn(fill)` (`UiStyle.textOn`); never pick it by hand for a kit button.
- Primary = the main action of a screen. Red = close or danger. Gold = selection and money. Sand = everything else.
- Window titles use `UiKit.headerBand(title)`; tab-page titles do not.
- Disabled buttons go through `UiKit.setEnabled(button, enabled, fill?)`: no hover or press motion, fill Disabled.
- One `UIStroke` per object; layout boxes come from `UiTheme` and stay untouched by styling.
- Phone (PRODUCT_SPEC 'Compact on phone'): windows ≤ 70 % x 80 % of the safe area, HUD ≤ 20 %, buttons 44–52 px, body 14–16, titles ≤ 24; no phone box may exceed the CM2-UI3 baseline in `UiTheme_Test`.

## Click sound
`rbxasset://sounds/volume_slider.ogg`, volume 0.5: engine content on every client, no asset ID, upload or licence (DECISION_LOG 2026-11-27).

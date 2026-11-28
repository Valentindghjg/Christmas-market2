# CM2-VIBE1 — Light and colour pass

Planner `planner`; implementer `implementer-high`; playtest in CM2-RC5; `reviewer` commits. Everything below is decided; if something is missing, stop and report.

## Goal
Warm, saturated, lightly hazy daylight with Future shadows; a cool, readable night where night lights glow; values in config, blended by the client.

## Source of truth
PRODUCT_SPEC "Vibe pass before the launch" (1); DECISION_LOG 2026-11-28 "vibe pass before the launch" (findings: no Lighting properties today); backlog CM2-VIBE1 (a)-(e); TECHNICAL_ARCHITECTURE §5 "Day cycle" (only the client writes `Lighting`).

## Implementer tier
Tier: M. Reason: project files, config, a new pure module and the client blend; no saves, money, inventory or remotes.

## Skill checks
- (lighting) `Technology` is not script-writable: set only in both project files; no script touches it.
- (lighting) Brightness ≤ 3, Atmosphere Density < 0.5, Ambient never black; at most 3 post effects (ColorCorrection, Bloom, SunRays).
- (lighting) Bloom Threshold ≥ 1 by day so white snow does not bloom; mobile: Bloom and SunRays off at quality 1-3.
- (luau) `--!strict`; the shared module is pure (no Roblox globals: colours as `{r,g,b}` 0-255 arrays, `Color3` built only in the client).
- (luau) Write Lighting only when the blend changed by > 0.001.
- (tooling) Project-file check is headless-only (inline in `tests/headless/run.luau`, precedent "Notify drains"); `LightingBlend_Test` runs in Studio and headless.
- (collaboration) Studio readings are measured values, not captures.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/GameConfig.lua` | Change | new `GameConfig.Lighting`; remove `DayCycle.NightOutdoorAmbient` |
| `src/shared/LightingBlend.lua` | New | pure `values(blend)`, `effectsOn(quality)` |
| `src/client/DayNight.client.lua` | Change | blend all targets; quality gate |
| `default.project.json`, `release.project.json` | Change | identical `Lighting` node (below) |
| `tests/studio/Cases/LightingBlend_Test.lua` | New | blend and config tests |
| `tests/headless/run.luau` | Change | register `LightingBlend` in `sourcePaths`; inline project check |
| `docs/TECHNICAL_ARCHITECTURE.md` | Change | one sentence at the "Day cycle" bullet (§5) |

## Data and config
New block after `GameConfig.DayCycle`, all PROVISIONAL (engineering look values, CM2-VIBE1). Colours `{r,g,b}` 0-255.

```
GameConfig.Lighting = {
  EffectsMinQualityLevel = 4, -- quality 1-3: Bloom and SunRays off (as Snow)
  Classes = { CM2Atmosphere = "Atmosphere", CM2ColorCorrection = "ColorCorrectionEffect",
              CM2Bloom = "BloomEffect", CM2SunRays = "SunRaysEffect" },
  Static = { Technology = "Future", GlobalShadows = true, ShadowSoftness = 0.25, Brightness = 2.2,
             EnvironmentDiffuseScale = 0.6, EnvironmentSpecularScale = 0.4 },
  Day = { Lighting = {...}, CM2Atmosphere = {...}, CM2ColorCorrection = {...}, CM2Bloom = {...}, CM2SunRays = {...} },
  Night = { same targets and keys },
}
```

| Target.Property | Day | Night |
|---|---|---|
| Lighting.Ambient | {90,95,110} | {60,70,100} |
| Lighting.OutdoorAmbient | {150,145,140} | {70,80,110} (old NightOutdoorAmbient) |
| Lighting.ExposureCompensation | -0.15 | 0.35 |
| CM2Atmosphere.Density | 0.25 | 0.3 |
| CM2Atmosphere.Offset | 0.2 | 0.15 |
| CM2Atmosphere.Color | {222,228,238} | {60,70,100} |
| CM2Atmosphere.Decay | {170,190,215} | {40,50,80} |
| CM2Atmosphere.Glare | 0.4 | 0 |
| CM2Atmosphere.Haze | 1.2 | 0.8 |
| CM2ColorCorrection.Brightness | 0.02 | 0.04 |
| CM2ColorCorrection.Contrast | 0.12 | 0.08 |
| CM2ColorCorrection.Saturation | 0.22 | 0.05 |
| CM2ColorCorrection.TintColor | {255,244,230} | {215,225,255} |
| CM2Bloom.Intensity | 0.3 | 0.7 |
| CM2Bloom.Size | 24 | 28 |
| CM2Bloom.Threshold | 1.3 | 0.9 |
| CM2SunRays.Intensity | 0.08 | 0 |
| CM2SunRays.Spread | 0.6 | 0.6 |

`Static` is not blended (set by the place). `GameConfig.DayCycle.NightOutdoorAmbient` is deleted (now `Lighting.Night.Lighting.OutdoorAmbient`).

**Project node** (both files, inside `tree`, after `Workspace`; identical text): `"Lighting": { "$className": "Lighting", "$properties": { <Static> + <Day.Lighting> }, "CM2Atmosphere": { "$className": "Atmosphere", "$properties": <Day.CM2Atmosphere> }, ... }` for all four. Enum as string (`"Technology": "Future"`); Color3 as `[r/255, g/255, b/255]` rounded to 4 decimals; numbers verbatim. If `rojo build` rejects `Technology`, stop and report (do not substitute another property).

## Steps
1. `GameConfig.lua`: add the block above with a comment naming CM2-VIBE1 and that Static + Day mirror both project files; delete `NightOutdoorAmbient`.
2. `src/shared/LightingBlend.lua` (`--!strict`, requires only `GameConfig`):
   - `export type Values = { [string]: { [string]: number | { number } } }`
   - `LightingBlend.values(blend: number): Values`: clamp `blend` to [0,1]; for every target and key in `Day`, numbers `d + (n - d) * blend`, colour arrays per channel the same, rounded with `math.floor(x + 0.5)`. Returns a fresh table. Asserts at load that `Day` and `Night` have the same targets and keys (error message `"GameConfig.Lighting Day/Night keys differ: <target>.<key>"`).
   - `LightingBlend.effectsOn(qualityLevel: number): boolean`: `qualityLevel < 1 or qualityLevel >= EffectsMinQualityLevel` (0 = Automatic is on, same rule as `GameConfig.snowRate`).
3. `DayNight.client.lua`:
   - Remove `dayAmbient`, `nightAmbient`, `changed`. Require `LightingBlend`; `local LightingConfig = GameConfig.Lighting`.
   - `targets: { [string]: Instance }`: `Lighting = Lighting`; for each name in `LightingConfig.Classes`, `Lighting:WaitForChild(name, 5)`; a nil result logs one `warn("DayNight: Lighting." .. name .. " missing")` and is skipped.
   - `local function apply(blend: number)`: for each target in `LightingBlend.values(blend)`, each property: `(instance :: any)[key] = if type(v) == "table" then Color3.fromRGB(v[1], v[2], v[3]) else v`.
   - `update()`: `blend = DayCycle.nightBlend(e)` with a save, else `0`; `if lastBlend == nil or math.abs(blend - lastBlend) > 0.001 then apply(blend); lastBlend = blend end`. ClockTime and `setLights` unchanged.
   - Quality: `UserSettings():GetService("UserGameSettings")`; `applyQuality()` sets `Enabled = LightingBlend.effectsOn(SavedQualityLevel.Value)` on `CM2Bloom` and `CM2SunRays` (if resolved); call once and on `GetPropertyChangedSignal("SavedQualityLevel")`.
4. Both project files: the node from "Data and config".
5. `run.luau`: add `LightingBlend = "src/shared/LightingBlend.lua"` to `sourcePaths`; after the Notify check add an inline check per file (`default.project.json`, `release.project.json`, so +2), named `"[PASS] <file> > Lighting matches GameConfig.Lighting"`: decode with `require("@lune/serde").decode("json", ...)`; load `GameConfig` through `loadModule(shared.GameConfig)`; assert `tree.Lighting["$className"] == "Lighting"`; each `Static` and `Day.Lighting` key equals `$properties` (strings/booleans `==`, numbers `|a-b| < 1e-4`, colours `|json*255 - cfg| < 0.5` per channel); for each `Classes` entry the child exists with that `$className` and its `$properties` equal `Day[name]` the same way, with no extra keys.
6. `TECHNICAL_ARCHITECTURE.md` §5 Day cycle bullet, append: "Look values (CM2-VIBE1): `GameConfig.Lighting`; `Technology`, shadows and the four `CM2*` effects are set in both project files, and the client blends Day → Night through `LightingBlend` by `DayCycle.nightBlend`."
7. `docs/PROGRESS.md` entry; "Studio: deferred, runs inside CM2-RC5".

## Tests (headless)
| Test case file | Test name | Asserts |
|---|---|---|
| LightingBlend_Test | day values | `values(0)` equals `Day` (every key) |
| LightingBlend_Test | night values | `values(1)` equals `Night` (numbers within 1e-9) |
| LightingBlend_Test | dusk midpoint and clamp | `values(DayCycle.nightBlend(735))` (= 0.5): Saturation 0.135, Atmosphere Color {141,149,169}; `values(-1)` = day, `values(2)` = night; `nightBlend(480)` (ClockTime 14) gives day, `nightBlend(840)` (ClockTime 22) gives night |
| LightingBlend_Test | look rules | Day Saturation > 0, Contrast > 0, TintColor R ≥ G ≥ B; Night Saturation < Day; Day Bloom Intensity ≤ 0.4 and Threshold ≥ 1; Density < 0.5 both; Night ExposureCompensation ≥ Day; Static.Brightness ≤ 3; every Ambient and OutdoorAmbient channel ≥ 40 (Day and Night) |
| LightingBlend_Test | effects quality gate | `effectsOn(0)` true, 1-3 false, 4 and 10 true |
| run.luau inline | default/release.project.json > Lighting matches | step 5 (2 checks) |
Headless total: parent count + 7.

## Playtest (Studio, via playtester)
Queued for CM2-RC5 (backlog 0d rule). Use a place from `rojo build default.project.json`; if a `rojo serve` session shows `Technology` ≠ Future, record "serve does not apply Technology" and read from the built place. Readings via the client context (values, not captures).
1. Solo Play with a loaded save; smoke run.
2. Edit/server: `Lighting.Technology` = Future, `GlobalShadows` true, `Brightness` 2.2; the four `CM2*` children exist with the `Classes` classes.
3. `setDay` hook (as step 60) elapsed 480, wait 2 s; client `Lighting.ClockTime` ≈ 14; Ambient, OutdoorAmbient, ExposureCompensation and all effect properties equal the Day table (numbers ±0.01, colours ±1/255).
4. `setDay` elapsed 840, wait 2 s; ClockTime ≈ 22; values equal the Night table; on the client at least one `NightLight` has `Enabled` true; `SnowEmitter.Snow.Rate` = 60; `CM2Bloom.Enabled` and `CM2SunRays.Enabled` true (quality Automatic).
5. Step 61 PASS; `probe` 0 problems. Quality 1-3: BLOCKED (MCP cannot set quality), covered headless.

## Acceptance
- `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (count + 7, 0 failed), `rojo build default.project.json` and `rojo build release.project.json` both succeed.
- Backlog (a)-(d) per the steps and tests; (e) in CM2-RC5 per the playtest.

## Out of scope
Sky, clock times, lamp values, new lights, `LightingStyle`, DepthOfField, map/model/UI changes, backlog edits.

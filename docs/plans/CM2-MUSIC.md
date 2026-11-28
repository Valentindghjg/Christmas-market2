# CM2-MUSIC — Calm background music with a saved music volume

Written by `planner-high` (Opus 5.5); pipeline `cm2-task`. Everything is decided; anything missing: stop and report.
**Order:** step 0 (track discovery) runs in `playtester` before the implementer (orchestrator: start `playtester` with this plan, "Step 0 only"; pass its report table to `implementer-opus`). Implement after CM2-UICLIP is committed (same rail, `UiTheme` and probe; this plan touches `UiTheme.lua` with one added `Dialogs` entry and `UiKit.lua` with one comment line only).

## Goal
Calm looping music from Roblox's own audio library plays from join; the player lowers or mutes it in a small Music panel on the HUD rail, and the value survives a rejoin.

## Source of truth
Backlog CM2-MUSIC (a)–(e); DECISION_LOG 2026-11-28 "UI clipping, background music, RC3" (b); PRODUCT_SPEC owner decisions "Audio" (separate music volume); TECHNICAL_ARCHITECTURE §3 (envelope), §4 "Profile fields without a `SaveProfile.VERSION` bump", §5 lock-free profile.

## Implementer tier
Tier: L. Reason: a new persisted per-player profile field plus a new validated, rate-limited action remote (template rule: persisted fields, remote validation, rate limits).

**Store decision:** no settings field exists (`SaveProfile`, `SaveSlotService`, `BusinessState` checked). New optional profile field `musicVolume`, **no** `SaveProfile.VERSION` bump (precedent `tutorialOffered`, `daily`, `advent`; TECHNICAL_ARCHITECTURE §4): nil = default (the "migration"); older servers ignore and keep it. A bump would make older servers refuse every profile. Not in `BusinessState`: per player, not per save.

## Skill checks
- data: `musicVolume` nil or finite in [0, 1]; one `UpdateAsync` per accepted change; no write when unchanged; NaN/inf never stored.
- networking/security: client sends only `{volume}`; server checks type/NaN/inf, clamps, rounds, rate-limits, busy guard.
- audio: legacy `Sound` + `SoundGroup "Music"` under `SoundService` (global); `PreloadAsync`; track volume ≤ 1; UiClick outside the group.
- gui: compact layout via `bindDialog` (780x281), buttons ≥ `UiTheme.MinTouch`, probe 0 (CM2-UICLIP); only the local volume is optimistic.
- localization: every new key in `en` and `de`, same placeholders.
- collaboration-mode: track IDs only from Studio evidence.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/shared/MusicSettings.lua`, `src/server/Services/PlayerSettingsService.lua`, `src/client/Music.client.lua` | New | volume rules; the action; playback + panel |
| `src/shared/GameConfig.lua`, `SaveProfile.lua`, `Protocol.lua`, `UiTheme.lua`, `Localization.lua` | Change | steps 1–3, 7, 9 |
| `src/server/Services/SaveSlotService.lua`, `src/server/main.server.lua` | Change | steps 4, 6 |
| `src/client/UiKit.lua` | Change | rail-slot comment: add `80 MusicButton` |
| `tests/headless/run.luau` + tests below | Change/New | register the 2 new modules |
| `docs/AUDIO.md` (new), `TECHNICAL_ARCHITECTURE.md`, `RELEASE_CHECKLIST.md`, `DECISION_LOG.md` | Change | step 10 |

## Data and config
`GameConfig.Music` (after `GameConfig.Advent`), all PROVISIONAL:
| Key | Value |
|---|---|
| `TrackIds` | the PASS IDs of step 0 in report order (2 to 4 integers); `{}` if step 0 is BLOCKED |
| `DefaultVolume` | 0.5 |
| `TrackVolume` | 0.5 (per `Sound`; heard = TrackVolume × setting) |
| `VolumeStep` | 0.1 |
| `FadeInSeconds` / `FadeOutSeconds` / `GapSeconds` | 3 / 3 / 2 |
| `GroupTweenSeconds` | 0.25 |
| `SettingWaitSeconds` | 10 |
| `SendDebounceSeconds` | 0.75 |
| `SetLimit` | `{ limit = 6, window = 30 }` |

Profile: `musicVolume: number?` (no version bump). Player attribute `MusicVolume` (number), set by the server.

## Steps
0. **Track discovery (playtester, Studio MCP, Edit context; read-only, nothing inserted).**
   a. `search_asset` (assetType Audio, maxResults 25, verified creators if offered), queries in order: `chill`, `lofi`, `calm piano`, `relaxing acoustic`, `christmas instrumental`, `winter ambient`. Keep creator Roblox; drop titles with `vocal`, `voice`, `sing`, `remix`, `sfx`, `effect`. At most 12 candidates, query then result order, no duplicates.
   b. `execute_luau` on the candidates:
   ```lua
   local MS, CP, SS = game:GetService("MarketplaceService"), game:GetService("ContentProvider"), game:GetService("SoundService")
   local out = {}
   for _, id in { --[[candidate IDs]] } do
     local ok, info = pcall(MS.GetProductInfo, MS, id, Enum.InfoType.Asset)
     local s = Instance.new("Sound"); s.SoundId = "rbxassetid://" .. id; s.Parent = SS
     pcall(CP.PreloadAsync, CP, { s })
     local c = (ok and info.Creator) or {}
     table.insert(out, string.format("%d|%s|%s|%s|%s|%s|%.1f", id, ok and info.Name or "?", tostring(c.Name),
       tostring(c.CreatorTargetId), ok and tostring(info.AssetTypeId) or "?", tostring(s.IsLoaded), s.TimeLength))
     s:Destroy()
   end
   return table.concat(out, "\n")
   ```
   All `IsLoaded false` in Edit: rerun in the Client context of a Play session.
   c. PASS = `Creator.Name == "Roblox"`, `CreatorTargetId == 1`, `AssetTypeId == 3`, `IsLoaded == true`, 60 ≤ `TimeLength` ≤ 360. Report the first 4 PASS rows (id, title, seconds) in candidate order, plus the date.
   d. Fewer than 2 PASS, or no MCP: BLOCKED. The implementer still does steps 1–10 with `TrackIds = {}` (no music, button hidden, no warning; AUDIO.md "pending owner pick"); the orchestrator has the `planner` open a PC entry (owner picks 2–4 calm instrumental Roblox-uploaded tracks in the Creator Store, sends the IDs) and a tier S follow-up fills `TrackIds`, AUDIO.md and runs the playtest. CM2-MUSIC stays open until then.
1. **`MusicSettings.lua`** (`--!strict`, requires `GameConfig`): `DEFAULT = Music.DefaultVolume`; `normalize(raw: unknown): (number?, string?)` → not a finite number: `nil, "InvalidVolume"`; else clamp to [0, 1] and `math.floor(v * 100 + 0.5) / 100`. `isValid(value: unknown): boolean` → nil or finite number in [0, 1]. `volumeOf(profile): number` → `profile.musicVolume` if a number, else `DEFAULT`. `step(volume: number, direction: number): number` → `normalize(math.floor(volume / STEP + direction + 0.5) * STEP)` (direction ±1). `percent(volume): number` → `math.floor(volume * 100 + 0.5)`.
2. **`SaveProfile.validate`**: after the advent check, `if not MusicSettings.isValid(profile.musicVolume) then return false end` (comment "CM2-MUSIC: nil = default"). `new` unchanged.
3. **`Protocol`**: `Actions.SettingsSetMusicVolume = "Settings.SetMusicVolume"` (comment: via PlayerSettingsService, never companies:handle), in `actionSet`; in `validateRequest`: not `hasOnlyKeys(payload, {volume = true})` → `UnexpectedField`; not `isFiniteNumber(payload.volume)` → `InvalidVolume`.
4. **`SaveSlotService`** (section "Player settings (CM2-MUSIC)" after Advent): `musicVolumeOf(userId): (boolean, number)` → `(true, MusicSettings.volumeOf(cached))` with a cached profile, else `(false, DEFAULT)`. `setMusicVolume(userId, volume: number): (number?, string?)` → no cached profile: `nil, "ProfileUnavailable"`; else `_updateProfile` with `storedProfile(stored)`; `current.musicVolume == volume` → `current, false`; else set and `current, true`; returns `MusicSettings.volumeOf(updated)`. Lock-free like `claimDaily`.
5. **`PlayerSettingsService.lua`** (Advent pattern): `new(deps: {saveSlots, clock, setAttribute})`, limiter `Protocol.newRateLimiter(SetLimit.limit, SetLimit.window)`, `_busy`. `handle(userId, request)`: `validateRequest` → action not `SettingsSetMusicVolume` → `UnknownAction` → `allowRequest` else `RateLimited` → busy → `SettingBusy` → `pcall` of `saveSlots:setMusicVolume(userId, (MusicSettings.normalize(payload.volume)))`; error → warn `[ChristmasMarket2] music volume failed for %d: %s`, `InternalError`; refusal → its code; ok → `setAttribute(userId, "MusicVolume", v)`, `{ok = true, data = {musicVolume = v}}` (no `revision`, as `Save.*`). `refresh(userId)`: `musicVolumeOf` open → set the attribute. `onPlayerJoined = refresh`; `forgetUser` clears the limiter and `_busy`.
6. **`main.server.lua`**: require; construct after `advent` with `clock = os.clock` and the Advent `setAttribute` closure; in `onPlayerAdded` after `ProfileReady = true`: `playerSettings:onPlayerJoined(player.UserId)` (no yield); in `PlayerRemoving`: `forgetUser`; in `handleBusinessAction` after the `AdventOpen` branch: route `SettingsSetMusicVolume` to `playerSettings:handle`.
7. **`UiTheme.Dialogs.Music`** = `{ listTop = 40, footerHeight = 52, minList = 80, maxWidth = 380, maxHeight = 230, widthScale = 0.92, heightScale = 0.6 }`.
8. **`Music.client.lua`** (`--!strict`; GameConfig, MusicSettings, Localization via UiKit, UiTheme, UiKit; remote `BusinessAction`).
   - Playback: `SoundGroup` `Music` (Volume 0) under `SoundService`; per ID `Sound` `Track_<i>`: `SoundId = "rbxassetid://" .. string.format("%d", id)`, Volume 0, `Looped = false`, `SoundGroup = group`, parent `group`. Startup task: wait for attribute `MusicVolume` up to `SettingWaitSeconds` (else `DEFAULT`), tween `group.Volume` to it; `pcall(ContentProvider.PreloadAsync, …, sounds)`; a track with `IsLoaded == false` or `TimeLength <= 0` is skipped with one warn `[ChristmasMarket2] music track %d did not load`; none loaded → stop. Loop from a random loaded index, wrapping in order: `TimePosition = 0`, `Play`, tween Volume 0 → `TrackVolume` over FadeIn; `while sound.IsPlaying and sound.TimePosition < sound.TimeLength - FadeOut do task.wait(0.5) end`; tween to 0 over FadeOut, wait it, `Stop`, wait `GapSeconds`, next.
   - State: `volume` (shown and heard), `confirmed` (last server value), `lastAudible` (last non-zero, starts at the loaded value if > 0 else `DEFAULT`), `inFlight`, debounce `token`. `setVolume(v)`: `volume = v`, tween group over `GroupTweenSeconds`, render, if `v > 0` then `lastAudible = v`. Every button: `setVolume(new)`, `token += 1`, `task.delay(SendDebounceSeconds)` → if token unchanged, `flush()`. `flush()`: return if `inFlight` or `volume == confirmed`; send `{volume = volume}` via `UiKit.request`; ok → `confirmed = data.musicVolume`, status `""`, if `volume ~= confirmed` schedule again; fail → status `shopErrorBusy` for `RateLimited`/`SettingBusy`, else `rewardErrorFailed`; if `volume` still equals the sent value, `setVolume(confirmed)`. Attribute change: if not `inFlight` and `volume == confirmed`, `setVolume(attr)`; then `confirmed = attr`.
   - Panel: `UiKit.screenGui("MusicUI", 15)`; `UiKit.addRailButton("MusicButton", "musicButton", 80)`, visible if `CompanyReady` and `#TrackIds > 0`. Frame `MusicPanel` (`UiKit.window`, padding 12): `Title` (22, `headerBand`, height 30); Frame `Controls` (no `ClipsDescendants`): `Value` label (0, 0, full width, 30): `musicVolume` with `percent`, or `musicMuted` at 0; buttons `Down` (0, 36, 56x44), `Up` (62, 36, 56x44), `Mute` (124, 36, 120x44, text `musicMute`/`musicUnmute`); `Footer`: `Status` label and `CloseButton` (120x44, RED, `musicClose`). `bindDialog(gui, {frame, list = Controls, footer, rightHeader = Title}, UiTheme.Dialogs.Music)`. Down/Up: `MusicSettings.step(volume, ∓1)`, `UiKit.setEnabled` off at 0 / 1. Mute: at 0 → `lastAudible`, else 0. Modal ID `Music` (`claimModal`/`releaseModal`); `CompanyReady` false closes it.
9. **Localization** (en / de): `musicButton` "Music"/"Musik"; `musicTitle` "Music"/"Musik"; `musicVolume` "Volume: %d%%"/"Lautstärke: %d %%"; `musicMuted` "Music is off"/"Musik ist aus"; `musicDown` "-"/"-"; `musicUp` "+"/"+"; `musicMute` "Mute"/"Stumm"; `musicUnmute` "Unmute"/"Ton an"; `musicClose` "Close"/"Schließen".
10. **Docs.** `docs/AUDIO.md`: table `Key | Asset ID | Title | Creator (name, ID) | Type | Seconds | Licence | Verified`, a row per track (licence "uploaded by Roblox (ID 1) to the Creator Store audio library for any experience"; verified: date, `GetProductInfo` + `PreloadAsync`, agent) and for `UiClick` `rbxasset://sounds/volume_slider.ogg` (built-in); "Owner listening check: pending"; rule: no other audio IDs, swap only via `TrackIds` plus a row. TECHNICAL_ARCHITECTURE §3: one sentence for `Settings.SetMusicVolume` (`{volume}`, `InvalidVolume`, `RateLimited`, `SettingBusy`, data `{musicVolume}`); §4 list adds `musicVolume`. RELEASE_CHECKLIST B1 item 6: the only `rbxassetid://` IDs are `GameConfig.Music.TrackIds` (Roblox-uploaded public audio, `docs/AUDIO.md`). DECISION_LOG "2026-11-28 — CM2-MUSIC (engineering)": field without version bump; values PROVISIONAL.

## Tests (headless)
| Test case file | Test name | Asserts |
|---|---|---|
| `MusicSettings_Test` (new) | normalizes | 0.333 → 0.33, 1.7 → 1, -0.2 → 0; `"0.5"`, NaN, ±inf, nil → `InvalidVolume` |
| same | validates | nil, 0, 0.5, 1 valid; -0.01, 1.01, NaN, inf, `"x"`, `{}` invalid |
| same | steps | 0.5 ±1 → 0.6 / 0.4 (equal to the literals); 0.4 -1 → 0.3; 0 -1 → 0; 1 +1 → 1 |
| same | reads default | `volumeOf({})` = 0.5; `volumeOf({musicVolume = 0})` = 0; `percent(0.3)` = 30 |
| `SaveProfile_Test` | validates the musicVolume field | as above on a full profile; `VERSION` still 1 |
| `Protocol_Test` | validates Settings.SetMusicVolume | `{volume = 0.4}` ok; string, NaN, inf, missing → `InvalidVolume`; extra key → `UnexpectedField` |
| `PlayerSettingsService_Test` (new; real SaveSlotService, AdventService_Test fake store, profile open, no play) | defaults on join | `onPlayerJoined` → attribute 0.5; stored profile has no `musicVolume` |
| same | migrates an old profile | a stored v1 profile without the field (written into the fake store first) opens, reads 0.5; after set 0.3 stored `musicVolume` 0.3, `profileVersion` 1 |
| same | clamps and rounds | 1.7 → data 1, -0.2 → 0, 0.333 → 0.33 (stored and attribute) |
| same | rejects wrong types without a write | `"loud"`, NaN, inf, `{volume=0.5, x=1}` → codes; store `writes` unchanged |
| same | rate limits | 6 accepted, 7th `RateLimited`; clock +31 s accepted; other user unaffected |
| same | round trip | set 0.2; `closeProfile`, `openProfile` and a second SaveSlotService on the same store → 0.2; same value again → no write |
| same | needs an open profile | without `openProfile` → `ProfileUnavailable`, no write |
| `GameConfig_Test` | music config | `TrackIds` 0 or 2–4 unique positive integers; numbers in range; `TrackVolume` ≤ 1 |

## Playtest (Studio, via playtester)
Smoke run plus these manual steps (no runner change); presses via `StudioUiHook:Invoke("press", path)`, paths under `PlayerGui`.
1. Join, save ready. Client: `SoundService.Music` is a `SoundGroup` with `#TrackIds` `Track_*` sounds, each `TimeLength > 0`; within 15 s exactly one `IsPlaying`; `group.Volume` = attribute `MusicVolume` (±0.01); `SoundService.UiClick.SoundGroup == nil`.
2. Press `HudRailUI/Rail/MusicButton` → `MusicUI/MusicPanel` visible; `probe "MusicUI"` and `probe "HudRailUI"` → 0 problems (desktop). Set start to 0.5 if not (Up/Down).
3. Press `MusicUI/MusicPanel/Controls/Down` twice; after 2 s attribute 0.3, `group.Volume` 0.3, `Value` "Volume: 30%".
4. Press `.../Controls/Mute` → within 1 s `group.Volume` 0, after 2 s attribute 0, `Value` "Music is off", Mute text "Unmute"; press it again → 0.3.
5. Mute (0); stop and start play (rejoin via the DataStore); after `ProfileReady`: attribute 0, `group.Volume` 0. Unmute → 0.5 (default), after 2 s attribute 0.5 (profile back at default).
6. Client: set the playing track's `TimePosition = TimeLength - 5` → within 12 s the next `Track_*` (wrapping) `IsPlaying`, the old one stopped.
7. Console: no `Failed to load sound`, no `[ChristmasMarket2] music` warnings; quote any.

## Acceptance
- `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (count after CM2-UICLIP + 14, all passing), `rojo build`.
- Backlog (a)–(e); step 0 evidence (IDs, creator, seconds, date) in AUDIO.md and PROGRESS.
- No `SaveProfile.VERSION` or `BusinessState` schema change; no money, inventory or save action touched.

## Out of scope
Radio, effects, effects volume (CM2-G18 reuses this field pattern and `PlayerSettingsService`); positional audio; a slider; the control before a save runs (music already plays).

## Amendment 1: Christmas tracks from Roblox's licensed library partners (owner, chat 2026-11-28)
Owner: Christmassy music; these 4 tracks approved ("ja nimm die 4", preview link). **Source rule (replaces "creator Roblox (ID 1)" everywhere in this plan):** an audio ID is allowed only if `GetProductInfo` shows `AssetTypeId == 3` and a creator from Roblox's licensed music library: Roblox (1), APMOfficial (7462718749) or DistrokidOfficial (7135127272); it loads (`PreloadAsync`, `TimeLength > 0`). Step 0 is done (playtester, Studio Edit, 2026-11-28, ten Christmas queries; the orchestrator's report lists them for PROGRESS).

Changes on top of the fallback implementation (`TrackIds = {}`):
1. `GameConfig.Music.TrackIds = { 9047801895, 140169923347660, 119871365837884, 1838667168 }` in this order, comment `-- OWNER DECIDED 2026-11-28; provenance docs/AUDIO.md`. Playback unchanged (random start, this order, wrapping, fades); the Music button now shows.
2. `GameConfig_Test` "music config": `TrackIds` has 2 to 4 entries (0 no longer allowed), unique positive integers below 2^53; it equals the list above. No test checks a creator; count unchanged.
3. `docs/AUDIO.md`: drop "pending owner pick"; one row each, licence "Roblox licensed music library (partner upload), usable in any experience"; verified "2026-11-28, playtester, Studio Edit, GetProductInfo + PreloadAsync; owner approved by preview link, owner listening done via store preview":

| Key | Asset ID | Title | Creator (name, ID) | Type | Seconds |
|---|---|---|---|---|---|
| Track_1 | 9047801895 | Twelve Days Of Christmas (Instrumental) | APMOfficial, 7462718749 | Audio (3) | 103.7 |
| Track_2 | 140169923347660 | Festive Calm | DistrokidOfficial, 7135127272 | Audio (3) | 106.0 |
| Track_3 | 119871365837884 | Silent Night (Dreamy Christmas Ambient) | DistrokidOfficial, 7135127272 | Audio (3) | 174.0 |
| Track_4 | 1838667168 | We Wish You A Merry Christmas (Instrumental) | APMOfficial, 7462718749 | Audio (3) | 133.0 |

   The rule line names the three allowed creators; the UiClick row stays.
4. `RELEASE_CHECKLIST` B1 item 6: "… `GameConfig.Music.TrackIds`, Roblox licensed library audio (APMOfficial, DistrokidOfficial), `docs/AUDIO.md`".
5. Playtest step 1 adds: in the Client context, for each `TrackIds` entry, `GetProductInfo` gives `AssetTypeId` 3 and `Creator.CreatorTargetId` in {1, 7462718749, 7135127272}; 4 `Track_*` sounds, each `TimeLength > 0`. Steps 2–7 unchanged; the task's Studio run is now due (no PC entry, no follow-up task).

DECISION_LOG (the orchestrator adds this; append to the bullet (b) of "2026-11-28 — owner: UI clipping, background music, RC3"): ` Amendment (owner, chat 2026-11-28): the music is Christmassy; source rule widened to Roblox's licensed music library (creator Roblox 1, APMOfficial 7462718749 or DistrokidOfficial 7135127272; AssetTypeId 3, loads in Studio); owner approved the 4 tracks 9047801895, 140169923347660, 119871365837884, 1838667168 by preview link ("ja nimm die 4"); provenance docs/AUDIO.md.`

## Amendment 2: asset-ID prefix out of the client; Controls fit the compact column
1. **ui_scan (option b; the scan rule stays unchanged and meaningful: no asset IDs in client files).** New `MusicSettings.soundId(id: number): string` → `"rbxassetid://" .. string.format("%d", id)` (shared, like the NPC animation IDs in `GameConfig`). `Music.client.lua` sets `sound.SoundId = MusicSettings.soundId(id)`. `MusicSettings_Test` "reads default" also asserts `soundId(140169923347660) == "rbxassetid://140169923347660"` (count unchanged). `tests/tools/ui_scan.luau` is not changed; it must show 0 hits.
2. **Controls layout** (replaces the offsets in step 8; one layout for every screen, `I = UiTheme.ClipInset`, now 8): `Value` at (I, I), size `UDim2.new(1, -2*I, 0, 30)`; `Down` at (I, I+36), 48x44; `Up` at (I+54, I+36), 48x44; `Mute` at (I+108, I+36), size `UDim2.new(1, -(2*I+108), 0, 44)`. All in UDim2 offsets from `UiTheme.ClipInset`, no literal 8. On the 230 px compact column, Mute spans x 116..222 (width 106, ≥ `MinTouch`) and leaves I on the right; on desktop (356 px) it is 232 wide; the button bottom is at I+80 = 88, inside the 106 px regular list area. `UiTheme.Dialogs.Music` unchanged.
3. Playtest step 2 adds the compact check: device emulation 667x317 and 666x374 (as CM2-UICLIP does), panel open, `probe "MusicUI"` → 0 problems; otherwise queue it with CM2-UIP (PC-14) like the other phone readings.
4. Accepted as done by the implementer: the `Music` rows in `UiTheme_Test` phone-box baseline, and RELEASE_CHECKLIST B1 item 6 naming both `GameConfig.Music.TrackIds` and `GameConfig.Customers.Npc.Animations` (Roblox R15 animation IDs).

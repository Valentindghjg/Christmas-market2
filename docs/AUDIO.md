# Audio — sources and provenance

Every sound the game loads is listed here (CM2-MUSIC, `docs/plans/CM2-MUSIC.md`, Amendment 1). Rule: no other audio IDs in the code; a track is added or swapped only through `GameConfig.Music.TrackIds` plus a row in this table, with its Studio evidence. An audio ID is allowed only if `GetProductInfo` shows `AssetTypeId == 3` and a creator from Roblox's licensed music library: Roblox (1), APMOfficial (7462718749) or DistrokidOfficial (7135127272), and it loads (`PreloadAsync`, `TimeLength > 0`).

| Key | Asset ID | Title | Creator (name, ID) | Type | Seconds | Licence | Verified |
|---|---|---|---|---|---|---|---|
| Track_1 | 9047801895 | Twelve Days Of Christmas (Instrumental) | APMOfficial, 7462718749 | Audio (3) | 103.7 | Roblox licensed music library (partner upload), usable in any experience | 2026-11-28, playtester, Studio Edit, GetProductInfo + PreloadAsync; owner approved by preview link, owner listening done via store preview |
| Track_2 | 140169923347660 | Festive Calm | DistrokidOfficial, 7135127272 | Audio (3) | 106.0 | Roblox licensed music library (partner upload), usable in any experience | 2026-11-28, playtester, Studio Edit, GetProductInfo + PreloadAsync; owner approved by preview link, owner listening done via store preview |
| Track_3 | 119871365837884 | Silent Night (Dreamy Christmas Ambient) | DistrokidOfficial, 7135127272 | Audio (3) | 174.0 | Roblox licensed music library (partner upload), usable in any experience | 2026-11-28, playtester, Studio Edit, GetProductInfo + PreloadAsync; owner approved by preview link, owner listening done via store preview |
| Track_4 | 1838667168 | We Wish You A Merry Christmas (Instrumental) | APMOfficial, 7462718749 | Audio (3) | 133.0 | Roblox licensed music library (partner upload), usable in any experience | 2026-11-28, playtester, Studio Edit, GetProductInfo + PreloadAsync; owner approved by preview link, owner listening done via store preview |
| `UiClick` | `rbxasset://sounds/volume_slider.ogg` | volume_slider (engine content) | Roblox client, built-in | built-in sound file | short click | ships with the Roblox client; no upload, no asset ID | `UiTheme.ClickSound`; built-in, no Creator Store check needed |

Track_n is the `Sound` name under `SoundService.Music`, in `TrackIds` order (owner decision 2026-11-28, "ja nimm die 4"). Playback starts at a random track and wraps in this order.

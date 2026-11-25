# Claude Code — 50-task development backlog
Updated: 2026-11-25 (planner, end-of-run refresh after the hasseln run of 2026-11-25: Next run list, CM2-SLIM4b filed; earlier the same day CM2-SLIM4 shortened it; moved-out notes, closed run blocks and the old wording of shortened entries are in `docs/archive/BACKLOG_DONE_2026-11-22_to_2026-11-25.md`, older ones in `docs/archive/BACKLOG_DONE_2026-11-21_to_2026-11-25.md` and `docs/archive/BACKLOG_RUNS_2026-11-22_to_2026-11-24.md`).
Status: binding order = "Launch order". Done: Gate A lines 1–13 with 5a–5g, 5i, 5j, 5j1, 5k, 5l, 5m, 7a, 9a, 9b, 10a, 12c, 13d; line 16. Open in Gate A: 5h CM2-UV2 and the line 14 phone criterion ("N1 rest"), 13c CM2-46c purchases (PC-10, N3b). The art captures (CM2-10a/b/c, 12, 13a, 13b, 14), the CM2-10W pair and line 17 (with CM2-G12b) wait for PC-9. Open PC entries: PC-1, PC-9, PC-10 (complete; the 2026-11-25 run added none). Hygiene: CM2-SLIM4 partial (67.7 KB), rest in CM2-SLIM4b. GitHub issues stay open until the owner closes them.

## Für den Owner am PC
Blockers only the owner can resolve (Studio, Rojo plugin, access, tools, decisions). Written by the `planner` during `hasseln` in the fixed format from `.claude/skills/hasseln/SKILL.md`; the next run checks each entry's `Prüfen` field first and starts with its `Danach` task.

### PC-1 Screenshots vom Referenzspiel für den Modell-Look
- Status: offen
- Art: sonstiges
- Problem: Die Modelle sollen sich am Look des Referenzspiels orientieren, aber im Repo liegen keine Screenshots davon (nur Textbeschreibungen).
- Deine Schritte:
  1. Lege Screenshots vom Referenzspiel in den Ordner `docs/references/roblox-game/` im Projekt: Verkaufsstand bzw. HQ-Stufen, Lieferwagen, Kundenautos, Abladeplätze, Bäume, Zaun, Map. Mehrere Winkel sind gut.
  2. Alternativ: die 32 Screenshots aus `roblox_codex_blueprint.zip` dorthin entpacken (`docs/REFERENCE_IMAGE_HANDOFF.md`).
  3. Nicht committen; der Ordner bleibt lokal (öffentliches Repo).
- Prüfen: `docs/references/roblox-game/` enthält mindestens 5 Bilddateien.
- Blockiert: CM2-ARTREF (Look-Vergleich der fertig modellierten Art mit den Screenshots); sonst nichts (alle MODEL-Tasks wurden nach `docs/REFERENCE_GAME_LIVE_TEST.md` und `docs/art/quality-reference/` modelliert)
- Danach: CM2-ARTREF („Next hasseln starts here“ N4). Planner-Entscheidung 2026-11-24: die Import-Kette N5 ist ohne ARTREF gelaufen (alle 41 Modelle importiert und committet); eine Abweichung, die ARTREF findet, wird als Nacharbeit (MODEL) mit erneutem Upload des betroffenen Assets angelegt.
- WIP-Branch: none
- Seit: 2026-11-22, Owner-Gespräch

### PC-9 Bildrate in Studio ohne 15-FPS-Grenze messen, schwarze Play-Captures
- Status: offen
- Art: studio
- Problem: Im Studio-Batch am 2026-11-24 lag die Client-Bildrate in jedem Lauf bei genau 15,0 FPS im Mittel (min 14,7), auf dem Dorfplatz wie bei Tag/Nacht, während der Server 60 FPS hielt; so ein glatter Wert ist eine Bildraten-Grenze (Studio, Windows oder Grafiktreiber drosseln, oft wenn das Fenster nicht im Fokus ist), keine Last des Spiels. Dazu bleibt der Welt-Teil jedes Play-Captures schwarz (Hinweise unten).
- Schon geprüft (Befund einer Owner-Sitzung 2026-11-24, ~19:30): Energiesparplan ist bereits „Ultimative Leistung“; Grafikkarte AMD Radeon RX 6600 (kein NVIDIA-Schritt nötig); Luau bietet keine FPS-Grenze zum Umstellen (`UserGameSettings.FramerateCap` nicht verfügbar, FrameRateManager „Automatic“). Erledigt sind auch die früheren Nebenschritte: `C:\assets` ist gelöscht (Papierkorb; `ls /c/assets` schlägt fehl) und `ReplicatedStorage` hat nur noch einen Ordner `ArtAssets` (NPCs, Vehicles, Trees, Buildings, Environment, Props; der N2-Playtester sah dasselbe: ein Ordner, 6 Kinder).
- Deine Schritte (nur noch offen):
  1. AMD Software: Adrenalin Edition → Gaming → Roblox Studio (bzw. Global): „Radeon Chill“ aus und „Frame Rate Target Control“ (FRTC) aus oder auf mindestens 60 FPS.
  2. In Roblox Studio: Datei → Studio-Einstellungen, ins Suchfeld „FPS“ und danach „Frame“ eingeben und jede Begrenzung der Bildrate ausschalten bzw. auf mindestens 60 stellen, besonders eine Drosselung im Hintergrund. Studio danach neu starten und den Projekt-Place öffnen (Rojo verbinden wie bei PC-6).
  3. Im Task-Manager bei Roblox Studio den „Effizienzmodus“ aus.
  4. Während des nächsten Laufs Studio maximiert im Vordergrund lassen (wie PC-7), Rojo verbunden (PC-11), und im Chat „FPS frei“ schreiben.
  5. Alternative ohne Studio: in der privaten Version (oder im Freundestest) im Roblox-Menü → Einstellungen „Performance Stats“ einschalten, 30 s auf dem Dorfplatz stehen, einmal bei Tag und einmal bei Nacht, und die FPS-Zahl im Chat schicken.
- Hinweis: die Befunde der Läufe vom 2026-11-24 (Welt-Capture schwarz bei sichtbarem HUD, Ablesungen in Play, Konsolenwarnung → CM2-ASSETWARN) stehen im Archiv `docs/archive/BACKLOG_DONE_2026-11-22_to_2026-11-25.md` (CM2-SLIM4).
- Prüfen: (1) ein `screen_capture` in Play zeigt die 3D-Welt (nicht schwarz) und (2) der `playtester` misst im Play-Client 10 s lang `RenderStepped` und bekommt im Mittel mehr als 20 FPS (keine 15-FPS-Grenze mehr); ersatzweise für (2) hat der Owner Live-FPS (Schritt 5) im Chat geschickt.
- Blockiert: die Queue-Einträge „Captures only“ (CM2-10W Reserve-Paar, das den Haken von CM2-10W hält; CM2-G12a Platz bei 300/900, der zusammen mit CM2-G12b Zeile 17 abhakt; CM2-UVF8 Shop), „Desktop FPS“ (CM2-10W >= 55 FPS über 30 s auf dem Platz, CM2-G12a Check 4 >= 55 FPS über 60 s ab elapsed 700) und die Play-Schritte von CM2-12, CM2-13a und CM2-13b (Queue). Seit PC-4 erledigt ist (2026-11-24) außerdem aus N1: (c) die Telefon-FPS-Checks von CM2-10W und CM2-G12a sowie die Telefon-, Tablet- und 1080p-Captures, die die 3D-Welt zeigen müssen (CM2-UV2 j1 und j6, Avatare und Kundenautos; später CM2-UI (e)). Planner-Entscheidung 2026-11-24: die FPS-Werte halten keinen Haken (Umgebungsgrenze, der Server hält 60 FPS); die Captures schon.
- Danach: der Batch „Next hasseln starts here“ N2 (beide Einträge von „Studio-Test ausstehend“), dann der Capture-Rest von N1; liegen die FPS-Werte unter 55, legt der Planner einen Performance-Task an.
- WIP-Branch: none
- Seit: 2026-11-24, hasseln

### PC-10 Testkäufe in Studio: „Buy“ klicken (CM2-46c, Zeile 13c)
- Status: offen
- Art: studio
- Problem: Die Studio-Testkäufe (CM2-46b Playtest-Schritt 7: 7a StarterPack, 7b PassCashX2, 7c CashPinecone, 7d BoostCashX2, dazu die Idempotenz-Prüfung) brauchen einen Klick auf „Buy“ im Studio-Testkaufdialog; der MCP-Mausklick traf ihn am 2026-11-24 nicht und öffnete stattdessen ein Roblox-Plus-Abo-Angebot (Subscribe wurde NICHT geklickt; Play stoppen schloss es; kein Zustand geändert). Automatische Wiederholungen sind unsicher (ein Fehlklick kann auf Abo- oder Zahlungs-UI landen), darum ist der Klick deiner. Außerdem besitzt das Testkonto (userId 4584569287) PassCashX2 schon, sodass 7b so nicht prüfbar ist.
- Schon versucht: ein unbegleiteter Versuch am 2026-11-24 (Studio `d0521b88`, `main` @ 3c5ac49). Ausgangswerte: Cash 41282, robuxSpent 1068, 21 erledigte Receipts.
- Deine Schritte:
  1. Am PC sein, Roblox Studio mit dem Projekt-Place geöffnet, Rojo verbunden (PC-11), Studio maximiert im Vordergrund (wie PC-7).
  2. Im Chat „PC-10: ich bin da“ schreiben. Der Lauf startet dann CM2-46c-Käufe (N3b) und ruft jeden Kauf einzeln aus.
  3. Wenn der Lauf „Bitte Buy klicken“ schreibt: im Studio-Dialog „Buy item“ (Text „This is a test purchase. Your account will not be charged.“) auf **Buy** klicken. Nie auf „Subscribe“ oder einen Roblox-Plus-/Premium-Knopf klicken; erscheint so ein Angebot, auf „Cancel“ bzw. das X klicken und im Chat „falscher Dialog“ schreiben. Das passiert viermal (7a, 7c, 7d, und 7b falls Schritt 4 Variante A).
  4. Zu 7b PassCashX2 im Chat eine Variante wählen: **A** „7b mit Zweitkonto“: ein zweites Roblox-Konto ohne den Pass in Studio anmelden (oder als Team-Create-Tester einladen) und den Kauf damit machen; **B** „7b als abgedeckt“: 7b gilt durch den simulierten Receipt-/Pass-Pfad (CM2-46a Playtest-Schritte 51–53, Schritt 52 prüft PassCashX2 mit doppeltem Verkaufserlös) als erfüllt, der echte Pass-Kauf läuft dann im Freundestest (N7).
- Prüfen: der Owner hat im Chat „PC-10: ich bin da“ geschrieben, oder die Käufe von Zeile 13c (7a, 7b oder die Variante-B-Entscheidung, 7c, 7d, Idempotenz) stehen als PASS in PROGRESS.md.
- Blockiert: CM2-46c Testkäufe (Zeile 13c, Queue-Eintrag in „Studio-Test ausstehend“); damit auch der Freundestest (N7), der N3 voraussetzt.
- Danach: N3b CM2-46c-Käufe („Next hasseln starts here“), direkt nachdem der Owner „PC-10: ich bin da“ geschrieben hat.
- WIP-Branch: none (Arbeit liegt auf `main`: 3c5ac49 IDs, 478de93 PROGRESS und Queue-Eintrag)
- Seit: 2026-11-24, hasseln

#### Erledigt

- PC-11 Rojo neu starten und verbinden: Quelländerungen kommen nicht mehr in Studio an, erledigt 2026-11-25, see archive
- PC-8 Robux-Produkte anlegen und die IDs schicken, erledigt 2026-11-24, see archive
- PC-4 Geräte-Emulator umschalten (Telefon, Tablet, 1080p), erledigt 2026-11-24 (Planner-Entscheidung: ein MCP-Werkzeug ersetzt den Owner-Schritt), bestätigt 2026-11-24 durch die erste Ablesung in N1 (nicht mehr vorläufig), see archive
- PC-2 Open-Cloud-API-Key für die Art-Pipeline, erledigt 2026-11-24, see archive
- PC-7 Studio-Fenster wieder in den Vordergrund (Play-Viewport 1x1, Screenshots scheitern), erledigt 2026-11-24, see archive
- PC-6 Rojo-Plugin im neu geöffneten Studio verbinden, erledigt 2026-11-22, see archive
- PC-3 Studio-Fenster im Vordergrund lassen (Screenshots und Taps scheitern), erledigt 2026-11-22, see archive
- PC-5 Rojo neu starten: ArtAssets.Trees fehlt im Live-Place, erledigt 2026-11-22, see archive

## Studio-Test ausstehend
Queue of tasks whose Studio playtest is deferred to the next batch run (skill `cm2-task`, step 3). The reviewer adds entries and removes each one after its batch steps pass.
Every item runs after PC-9 checks out, except CM2-46c (PC-10, N3b) and "N1 rest". Done parts and the 2026-11-24 batch history are archived. "Log": read the Play log from startup once, no `[ART]` warning (so far INFERRED only: the log had rotated; step 56 `MAP_WORLD` found 302 of 302 paths as art). The art items' Edit-mode steps and the full run 62/62 PASSED (2026-11-24); open are the beside-a-5-stud-Part captures of each plan's playtest step (branch I), clones destroyed afterwards.

- CM2-12 trees (`docs/plans/CM2-12.md`): (a) the row capture of playtest step 3; (c) log. Tick CM2-12 only after (a) passes and (c) is read.
- CM2-13a and CM2-13b art (`docs/plans/CM2-13a.md`, `docs/plans/CM2-13b.md`; same run as CM2-12): (a) playtest step 2, the 4 HQs and the 6 lot props (a TreeBundle on the bay at `BundleBase`); (c) log. Tick CM2-13a, CM2-13b and CM2-13 only after (a) passes and (c) is read.
- CM2-14 vehicles art (`docs/plans/CM2-14.md`; same run): (a) playtest step 2, the 4 vehicles, the 9 `Props/TreeBundle` stand-ins on the truck at `CargoAnchor`, a car's `Paint` coloured from the `CarPaint` palette; (c) log. Tick CM2-14 only after (a) passes and (c) is read.
- CM2-10a, CM2-10b and CM2-10c map art plus the CM2-10W art re-check (`docs/plans/CM2-10a.md`, `docs/plans/CM2-10b.md`, `docs/plans/CM2-10c.md`, `docs/plans/CM2-10W.md`): (a)–(c) the playtest step 2 capture of each plan (bridge and village tree; the 5 square models; fir, clusters, rock and both mountains 300 studs away); (d) CM2-10W, one bridge and one square capture of the live map showing the meshes; read the log once. Tick CM2-10a, CM2-10b, CM2-10c and CM2-10 after (a)–(c); CM2-10W after (d) and its reserve pair.
- Captures only (the numeric parts PASSED 2026-11-24): CM2-10W reserve pair (R's `lotExpansion` 0 and 1, the forest firs behind the lot from above and behind; 20 -> 15 firs at level 1, restored); CM2-G12a (`docs/plans/CM2-G12a.md`) client check 3, the village square at elapsed 300 and 900 (`setDay`); CM2-UVF8 (`docs/plans/CM2-UVF8.md`), the Shop and the boost line. Line 17 ticks after CM2-G12b and the square captures.
- Desktop FPS (`docs/plans/CM2-10W.md` playtest 5, `docs/plans/CM2-G12a.md` playtest 6 check 4): window focused, mean >= 55 FPS from `RenderStepped` over 30 s on the square and over 60 s from elapsed 700. Not tick-blocking.
- CM2-46c test purchases (PC-10, line 13c, code 3c5ac49): CM2-46b playtest step 7a–7d and the idempotency check; procedure, Accept and tick rule in N3b. Never retry the Buy click unattended.
- CM2-UVF13 remainder (no plan, backlog 5m; `docs/plans/CM2-UVF13.md`): (a) iPhone 7 667x375: tap LotManagerButton, Shop, Saves, Team and each opens its panel; (b) PC 1920x1080: the rail is one column, all buttons full width (gap = `railGap`), no overlap; (c) log. Not tick-blocking (5m is ticked). Folds into "N1 rest".
- N1 rest (5h CM2-UV2 and the line 14 CM2-49 phone criterion; after 5k–5m). One `playtester` session; devices via `StudioDeviceSimulatorService` (PC-4 Ablauf: `SetDeviceAsync` in Edit before each Play, one device per Play session, `StopSimulationAsync` at the end); first reading `ViewportSize` ±2 px of the device, else stop and the planner reopens PC-4; while PC-9 is open, UI items are judged on HUD captures plus numbers; pointer hovers also read the ghost `CFrame` and the plot attributes `BreakAreaX`/`BreakAreaZ`. Now: iPad (1022x767) and HD 1080 (1920x1079) f1, f4, b1, c1, c2, h2, i4 with probe and HUD captures; d5 on all three devices; d3 on all three once a second-account listing exists via the test hook (`sa(SH, "Save.FinderStart", ...)`, `docs/archive/plans/CM2-UV.md` (d) step 2; else BLOCKED); then delete the test saves "N1 Phone" (Solo) and "UV Duo" (Duo). After PC-9: j1, j6 on all three devices; N1 (b), a fresh save by touch in under 3 minutes at 667x375 (seconds until "Done", rail without overlap, world taps aimed with `CurrentCamera:WorldToViewportPoint`, the bay prompt by tap; a tap that again fails becomes a fix task); N1 (c), phone FPS at 667x375 for CM2-10W (square, 30 s) and CM2-G12a (60 s from elapsed 700, mean >= 30, no frame > 100 ms), not tick-blocking, below the bar → performance task (M). Each item with `ViewportSize`, numbers and captures in PROGRESS.md; each defect → fix task (S). 5h ticks when every item passes, line 14 when (b) passes.

## How to work
- Read CLAUDE.md and the canonical docs before starting.
- Work in dependency order, but parallelize independent tasks where safe.
- Each issue must end with implementation, tests, progress log, commit SHA, and reviewer evidence.
- Do not close issues solely on code generation; verify acceptance criteria.
- The identifiers CM2-01..CM2-50 are **planning IDs**, not GitHub issue numbers. GitHub numbering may differ. In the lists P0–P5, `(#n)` is the GitHub issue `https://github.com/Valentindghjg/Christmas-market2/issues/n`.
- Publication and paid actions require explicit owner approval.

## P0 — Fundament
- [x] CM2-01 (#1)
- [x] CM2-02 (#2)
- [x] CM2-03 (#3)
- [x] CM2-04 (#4)
- [x] CM2-05 (#5)
- [x] CM2-06 (#6)
- [x] CM2-07 (#7)
- [x] CM2-08 (#8)
- [x] CM2-09 (#9)

## P1 — Spielbarer Kern
- [ ] CM2-10 (#10)
- [ ] CM2-11 (#11) → CM2-S1 (done 2026-11-22); close the issue with launch order line 3.
- [ ] CM2-12 (#12)
- [ ] CM2-13 (#13)
- [ ] CM2-14 (#14)
- [ ] CM2-15 (#15)
- [ ] CM2-16 (#16)
- [ ] CM2-17 (#17) → CM2-G14 (done; automatic unload, no unload step).
- [ ] CM2-18 (#18) → CM2-G14 (done; stocking from a bay).
- [ ] CM2-19 (#19) → CM2-N1 (done; walking customers), manual checkout CM2-N2 (done).

## P2 — Wirtschaft & Automatisierung
- [ ] CM2-20 (#21)
- [ ] CM2-21 (#22) → CM2-G7 (done; pricing).
- [ ] CM2-22 (#23) → CM2-N1 (done; customer state machine).
- [ ] CM2-23 (#24) → CM2-N1 (done; NPC budget and cleanup).
- [ ] CM2-24 (#25) → CM2-N2 (done).
- [ ] CM2-25 (#26)
- [ ] CM2-26 (#27)
- [ ] CM2-27 (#28)
- [ ] CM2-28 (#29)

## P3 — Ausbau & Inhalte
- [ ] CM2-29 (#30)
- [ ] CM2-30 (#31)
- [ ] CM2-31 (#32)
- [ ] CM2-32 (#33)
- [ ] CM2-33 (#34)
- [ ] CM2-34 (#35)
- [ ] CM2-35 (#36)
- [ ] CM2-36 (#37)

## P4 — Multiplayer & Oberfläche
- [ ] CM2-37 (#38) → CM2-S2 (done). Open: the cross-server Join (CM2-S3) and a real 2-client run (friends test, order 15).
- [ ] CM2-38 (#39) → CM2-S2 (done; only Owner and Member roles).
- [ ] CM2-39 (#40) → CM2-S3 (done in code). Open: a real cross-server run on live servers (friends test, order 15 (a)–(e)).
- [ ] CM2-40 (#41) → launch order 6 (done). Close the issue after line 5h CM2-UV2 passes (device part of CM2-UV (f)).
- [ ] CM2-41 (#42)
- [ ] CM2-42 (#43)
- [ ] CM2-43 (#44)

## P5 — QA & Release
- [ ] CM2-44 (#45)
- [ ] CM2-45 (#46)
- [ ] CM2-46 (#47)
- [ ] CM2-47 (#48)
- [ ] CM2-48 (#49)
- [ ] CM2-49 (#50)
- [ ] CM2-50 (#51)

## Follow-up tasks (created 2026-11-21 from the engineering review)
- [x] **CM2-R1 Studio regression run of the hardened session layer**, done 2026-11-22, see archive
- [ ] **CM2-R2 Version Studio art in the Rojo project** → re-scoped into CM2-AP (done); closes when CM2-44 is done (Accept: `rojo build` contains the imported art, a fresh checkout no longer falls back to primitives).
- [x] **CM2-R3 Surface a failed-closed session to the player**, done 2026-11-22, see archive
- [ ] **CM2-R4 Expand strict Luau type analysis** → launch order 32.

## Follow-up tasks (created 2026-11-21 from the reference-game play-test)
Source: REFERENCE_GAME_LIVE_TEST.md §11 (gaps G1–G18); planning IDs only. Original names and art, never reference assets or names; reference numbers go into config as OBSERVED, others PROVISIONAL. A G-task covered by a launch-order line has its goal and Accept there.
- [x] **CM2-G1 Customer car loading**, done 2026-11-21, see archive
- [x] **CM2-G2 Car-based customer arrival tied to parking**, done 2026-11-21, see archive
- [x] **CM2-G3 Checkout prompt content**, done 2026-11-21, see archive
- [x] **CM2-G4 Receiving bays and storage caps**, done 2026-11-21, see archive
- [x] **CM2-G14 Automatic unload and bay-to-display stocking**, done 2026-11-22, see archive
- [x] **CM2-G5 Supplier stock pool and helpers**, done 2026-11-21, see archive
- [x] **CM2-G6 Observed wholesale table and a Common starter species**, done 2026-11-22, see archive
- [x] **CM2-G7 Price benchmark = wholesale × 5**, done 2026-11-22, see archive
- [x] **CM2-G15 Customer reviews and rating**, done 2026-11-23, see archive
- [x] **CM2-G20 Repeatable Studio playtest**, done 2026-11-22, see archive
- [x] **CM2-G21 Remaining Studio verification for G1/G2**, done 2026-11-22, see archive
- [ ] **CM2-G8 Lot appeal and decor appeal** → launch order 26 (CM2-35).
- [ ] **CM2-G9 Full progression ladder in config** → launch order 16 (done), 27a CM2-G9c and 27b CM2-G9d.
- [ ] **CM2-G10 Multi-save and co-op size tiers** → launch order 3–5 (CM2-S1, CM2-S2, CM2-S3, done); the region tag is dropped (PRODUCT_SPEC 2026-11-21).
- [ ] **CM2-G11 Daily reward streak and quest board** → launch order 18.
- [ ] **CM2-G12 Day counter, day/night cycle, leaderboards** → launch order 17.
- [ ] **CM2-G13 Layout mode checklist** → launch order 27.
- [ ] **CM2-G16 Staff break area** → decided by the owner (gentle fatigue, movable break area, no wages); built in launch order 12 (CM2-25/26, done).
- [ ] **CM2-G17 Season pass design** → launch order 36.
- [ ] **CM2-G18 HQ radio** → launch order 21.
- [ ] **CM2-G19 HQ upgrade footprints vs lot layout** · Depends: CM2-G14 (done). The upgrade models are larger than the starter stand (MarketUpgrade3 38 × 40 studs, MarketPavilion 39 × 40, starter 32 × 24), so upgraded HQ tiers overlap parking spaces 1–2 (z ≈ 51..91 vs cars at z = 55), the pickup row and the stocking area. Accept: a Studio or headless footprint check of every HQ tier against parking spaces, pickup row, stocking slots and checkout; offsets or the stand position corrected where they collide. Runs inside launch order 16 (CM2-G9); the stall's front direction is checked in CM2-UV (j).

## Follow-up tasks (created 2026-11-24 from the hasseln run, N2)
- [ ] **CM2-ASSETWARN Trace the `rbxassetid://203785492` asset-type warning** (added 2026-11-24) · S (investigation only, no code change; a fix it finds becomes its own task, tiered then) · Depends: none (Studio connected; needs no capture, so not PC-9). Runs after "N1 rest", before N6 ("Next run" item 5).
  - Goal: find what requests asset 203785492 with the wrong type (6 times per Play session since P0, `docs/P0_AUDIT.md`; the CM2-G15 server trace and a repo grep found nothing: client-side, a default instance or an engine script).
  - `playtester`: (1) in Edit mode and the Play client, scan `game:GetDescendants()` (pcall per instance) for the ID in `SoundId`, `AnimationId`, `Texture`, `TextureID`, `Image`, `MeshId`, `ColorMap`, `Sky*` and string attributes, printing full names; (2) note from the console order when the 6 lines appear (Edit, server start, client join, spawn); (3) if the MCP allows, repeat in Play on a fresh baseplate place without the project.
  - Accept: PROGRESS.md has the hit list (or "0 hits" client and edit side), the console moment, the baseplate result (or step 3 BLOCKED with the reason) and whether it coincides with the black Play capture (PC-9); the planner then closes it as engine noise (DECISION_LOG line, P0_AUDIT note) or adds a fix task.

## Recurring task: CM2-SLIM repo hygiene (owner decision 2026-11-24)
One `cm2-task` per run, ID `CM2-SLIM` plus its date. **Tier S**: no planner; `implementer` (Sonnet medium) works from this entry; `reviewer` puts `(CM2-SLIM)` in every commit subject (the due check finds the last run by it). Old wording of this section: archive (CM2-SLIM4).

**Due** (hasseln step 2 checks it before picking a task; by hand: `cm2-task CM2-SLIM`) when any holds: no commit subject has `CM2-SLIM` yet; 8 or more `feat`/`fix` commits since the last one (`git log --oneline <last SLIM sha>..HEAD | grep -cE "^[0-9a-f]+ (feat|fix)"`); `docs/CLAUDE_BACKLOG.md` or `docs/DECISION_LOG.md` over 80 KB, or `CLAUDE.md` over 16 KB; the next task is CM2-47 (QA) or CM2-48 (release candidate).

**Goal:** find what nobody uses and what is too big, and shrink it, so agents read less per task. No behaviour change. **Method:** tools, not full reads: `git ls-files` with `wc -c`, `grep -rn` for references, `selene` for unused locals.

**Find** (every hit with its evidence): (1) dead files anywhere (scripts, tools, docs, assets, configs, skills) that nothing references (no `require`, no path in `default.project.json`, code, docs or tools); (2) dead code: modules never required, exported functions never called, config keys never read, `Localization` keys never used, `Protocol` actions never sent or never handled; (3) dead text: sections on removed or superseded things, duplicates of other docs, finished status notes; (4) too big: `CLAUDE.md` over 12 KB (loaded on every message), `docs/CLAUDE_BACKLOG.md` 60 KB, `docs/DECISION_LOG.md` 60 KB, `docs/PROGRESS.md` 20 KB, any other doc 30 KB, any Luau file 800 lines.

**Fix in this run (tier S allows it):**
- Docs: shorten wording without changing meaning; move finished material into `docs/archive/`:
  - backlog: ticked task lines with their status notes, resolved PC entries and done "current run" blocks go to `docs/archive/BACKLOG_DONE_<first date>_to_<last date>.md`, leaving one line per task ID (`- [x] CM2-xx title, done <date>, see archive`);
  - decision log: the archive-window rule of DECISION_LOG 2026-11-25 "decision-log archive window" (top sections, owner entries and the entries of the run day and the day before stay; the rest moves unchanged and in order to `docs/archive/DECISION_LOG_<first date>_to_<last date>.md` and stays binding; superseded owner entries may move with a one-line pointer if the log is still over 60 KB);
  - plans of ticked tasks go to `docs/archive/plans/`; update links that pointed to them.
- Delete dead files outside `src/` and dead code in `src/client`, `tests` and `tools`, each only with grep evidence that nothing references it.
- Never delete an owner decision, test evidence, a licence or provenance record, or anything in `.claude/settings*.json` and hooks; archive instead.

**File, do not fix:** dead code in `src/server` or `src/shared`, anything near saves, money, inventory, purchases or remotes, and splits of Luau files over budget. Each becomes a follow-up task right after the current launch-order task (dead code: tier by the template rules; splits: after CM2-48, not before release).

**Accept:** (a) a PROGRESS entry with a before/after table: size of the 10 largest text files, line counts of `src`, `tests` and `docs`, and the total that agents read every task (`CLAUDE.md` + the backlog + the last 60 KB of the decision log); (b) every removal listed with its grep evidence; every archived block findable by its task ID (`grep -rn <ID> docs/` hits it); (c) `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` and `rojo build` pass; the headless count is unchanged unless a test of removed dead code went with it, each removed test named; (d) follow-up tasks in the backlog with goal, tier and acceptance criteria, or "none"; (e) Studio not needed when only docs and files outside `src` changed, otherwise the Studio queue rules of `cm2-task` step 3 apply.

Runs: 2026-11-25 (first run; its PROGRESS entry holds the table). Follow-ups: CM2-SLIM1..5 and SLIM4b below ("Next run" item 3) and the splits CM2-SPLIT-a/b/c (launch lines 25a–25c).

## Follow-up tasks (created 2026-11-25 from CM2-SLIM)
Run in this order ("Next run" item 3). None changes behaviour. Standard checks for every task that touches `src` or `tests`; Studio not needed (comments, unused strings and docs only).
- [x] **CM2-SLIM1 Plan-path citations to the archive**, done 2026-11-25, see archive
- [x] **CM2-SLIM2 Dead Localization keys**, done 2026-11-25, see archive
- [x] **CM2-SLIM3 Decision-log archive by the new window**, done 2026-11-25, see archive
- [ ] **CM2-SLIM4 Backlog under 60 KB** · docs only, `planner` (Opus medium, through `cm2-plan`; planners may write the backlog) · Depends: CM2-SLIM3. Goal: rewrite the open long entries shorter without changing meaning: the phone notes of CM2-UVF10..13 and CM2-UV2 (line 5h), the CM2-10W/12W/13W/14W lines, the "Studio-Test ausstehend" items, the "Next run" N1..N8 blocks; finished notes and run records go to `docs/archive/BACKLOG_DONE_2026-11-21_to_2026-11-25.md`; old ticket lists P0..P5 and the 2026-11-21 follow-up sections become one line per ID if their issue is closed or covered by a launch-order line. Accept: `wc -c docs/CLAUDE_BACKLOG.md` <= 61440; every open task ID before the rewrite is still in the backlog with goal, tier, Depends and Accept (the PROGRESS entry lists the ID set before and after, equal for open IDs); PC entries keep their machine-readable fields unchanged; every moved block is found by `grep -rn <ID> docs/`.
  - Status partial 2026-11-25: 67,716 B (size Accept not met, not ticked); moved blocks are in `docs/archive/BACKLOG_DONE_2026-11-22_to_2026-11-25.md`; the rest is CM2-SLIM4b; ticks together with it.
- [ ] **CM2-SLIM4b Backlog to 61440 B, the three SLIM4 follow-ups** · docs only, `planner` (through `cm2-plan`; planners may write the backlog and `docs/plans/`) · Depends: CM2-SLIM4 (partial). Goal, in this order: (1) move the CM2-SLIM body (Goal, Method, Find, Fix, File-do-not-fix, Accept) unchanged into a standing plan `docs/plans/CM2-SLIM.md` from `docs/plans/TEMPLATE.md` with "Implementer tier: S" (cm2-task step 1: an existing plan's tier counts, so the run goes to `implementer` with the plan path); the backlog keeps the heading, the run-ID/reviewer rule, the **Due** rules, "Runs" and a pointer line to the plan; (2) move PC-9 "Schon geprüft" and PC-10 "Schon versucht" (not format fields, hasseln SKILL lines 77–87) to `docs/archive/BACKLOG_DONE_2026-11-22_to_2026-11-25.md`, each replaced by one pointer line; (3) one wording pass over Gate B, Gate C and the MODEL lines without changing meaning. Accept: `wc -c docs/CLAUDE_BACKLOG.md` <= 61440; the open-ID set is equal before and after (method of the 2026-11-25 CM2-SLIM4 PROGRESS entry, both lists in the new PROGRESS entry); the nine PC format lines of PC-1, PC-9, PC-10 byte-identical; `grep -rn "CM2-SLIM" docs/plans/CM2-SLIM.md` and the moved PC text found by `grep -rn PC-9 docs/archive/`; then the reviewer ticks CM2-SLIM4 and CM2-SLIM4b.
- [ ] **CM2-SLIM5 CLAUDE.md to 12 KB, wording only** · `planner` writes `docs/plans/CM2-SLIM5.md` with the full new text, `implementer` (S) applies it verbatim · Depends: CM2-SLIM4b. Goal: `CLAUDE.md` from 15.7 KB to <= 12 KB without changing a binding rule: shorter wording; a rule stated in full elsewhere (hook details in `.claude/hooks/`, skill list in `skills-lock.json`, hasseln loop in `.claude/skills/hasseln/SKILL.md`) becomes a one-line pointer. Owner approval only if 12 KB needs dropping or weakening a rule: then the plan stops, lists those rules, and the planner adds a PC entry. Accept: `wc -c CLAUDE.md` <= 12288; the plan has a table "rule → where it stands now" for every bullet of Non-negotiables, Continuous execution, the routing table, the skill table and the 12 conflict rules; `route-prompt.js` and `guard-main-edits.js` do not depend on CLAUDE.md text (grep).

## Launch replanning (2026-11-21)
The owner interview changed scope and priorities (PRODUCT_SPEC, top section). This section is the **binding work order** from 2026-11-21 on; it supersedes the milestone order P1..P5 above. The ticket lists above stay as the history and the GitHub mapping. Decision record: DECISION_LOG 2026-11-21 "Launch order".

### Rules for the order
- Work top to bottom. A task is **ready** when every dependency is done (reviewer COMMITTED). If the next task is blocked, take the next ready one and record the blocker on the blocked line.
- Every task runs through `cm2-task`. The tier on the task's line picks the planner (owner decision 2026-11-24): S runs without a plan, so its entry needs a goal and verifiable acceptance criteria; M and MODEL go to `planner` (Opus medium), L to `planner-high` (Opus high). The planner can still raise the tier in the plan.
- **MODEL tasks are ready since 2026-11-22**: the owner's reference images and the quality checklist are in `docs/art/quality-reference/`. The planner sets the quality tier (A or B) for every model in the plan. Feature tasks still never wait for art.
- Every task ends with the standard checks (`stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau`, `rojo build`) plus its own criteria below. A Studio criterion is PASS only if the `playtester` ran it; otherwise it is BLOCKED and the task stays open for that item.
- No publication, no creation or activation of Robux products by engineering (PRODUCT_SPEC). Product, gamepass and group IDs come from the owner through config.
- **UI stays functional until CM2-UI** (owner decision 2026-11-22, PRODUCT_SPEC "UI look"). Every UI before order 22a uses only `UiTheme` tokens and `UiKit` builders, with no hard-coded colours, fonts or sizes, no image assets and no visual polish. A plan that wants more is out of scope until CM2-UI. Screens built after CM2-UI use its style.

### Launch gates
| Gate | Target date | Content |
|---|---|---|
| **A — Friends test ready** | 2026-11-26 | Order 1–15: full core loop with walking customers and manual checkout, staff, saves with Duo/Trio/Quad and invite code, Robux shop wired, tutorial, touch UI. |
| **B — Go/No-Go build** | 2026-11-28 (owner decides) | Order 16–25: progression ladder, day/night, leaderboards, quests and daily rewards, Advent calendar, 1st Advent event, audio, final UI redesign (22a), QA, release checklist. |
| **C — 2nd Advent at the latest** | 2026-12-06 | Order 26–31: analytics and appeal, decor and layout, 2nd Advent event, balance pass, final regression. Art tasks as soon as reference images exist. |
| **After launch** | — | Order 32–37. |

If Gate A slips, the friends test moves to 2026-11-27 and Gate B keeps its date with fewer extras; order 16–25 is already sorted by launch value.

### Launch order
Tier: S/M/L/MODEL estimate. "Covers" lists the old tickets a line replaces or absorbs; their GitHub issues are closed when this line is done.

**Next hasseln starts here** (planner 2026-11-25, end-of-run refresh; done this run: CM2-SLIM, SLIM1–3, 5j, 5j1, 5k, 5l; SLIM4 partial; the closed blocks N1, N3, N5, N8 and the run history are archived). The order assumes the owner resolved every open PC entry; hasseln step 1 checks each `Prüfen` field, and a block whose PC entry is still open is skipped silently for that run. If Rojo drops again, the planner reopens PC-11 and Studio criteria go to "Studio-Test ausstehend" (code work goes on).
1. PC follow-ups whose entry checks out: **N3b** (PC-10, owner present) → **N2** (PC-9) → **N4** (PC-1).
2. ~~CM2-UVF13~~ (5m done 2026-11-25; Studio remainder in the queue).
3. **CM2-SLIM4b** → **CM2-SLIM5** (CM2-SLIM4 stays open until SLIM4b passes; the reviewer then ticks both).
4. **"N1 rest"** (queue item: line 5h and the line 14 phone criterion).
5. **CM2-ASSETWARN** (investigation only).
6. **N6** from **CM2-G12b**.
- **Repo hygiene:** `.claude/settings.local.json` exists, is not git-ignored and must never be committed; stage files by name, never `git add -A` or `git add .`.

N2. **PC-9 capture and FPS batch** (Danach of PC-9): the `playtester` checks gate (b) first (a Play `screen_capture` shows the 3D world, not black), then runs "Captures only" and "Desktop FPS". Accept: the captures are in PROGRESS.md; the `reviewer` removes each passed item and ticks CM2-10W when its pair passes; the FPS means are recorded, and a mean below 55 makes the planner add a performance task (M) right after N2. Gate (b) black again: PC-9 stays `offen` with the reading (window focus, viewport size), and the run goes on.
N3b. **CM2-46c test purchases** (line 13c, Danach of PC-10; first once the owner writes "PC-10: ich bin da"). `playtester`, owner at the PC, Studio `main` build, baseline first (cash, `robuxSpent`, done receipts). Per purchase: start the prompt, write "Bitte Buy klicken" in the chat and wait; never click inside the purchase dialog. Order 7a StarterPack, 7c CashPinecone, 7d BoostCashX2, 7b PassCashX2 (A: the owner's second account; B: skip, record the owner's decision, point to CM2-46a steps 51–53), then idempotency (same receipt twice grants once; `shopReceipt` hook with a real receipt ID). A Roblox Plus/Subscribe dialog stops N3b at once with a report. Accept: 7a, 7c, 7d PASS with the effects of CM2-46a; 7b PASS or the B decision in PROGRESS.md and DECISION_LOG; idempotency PASS; the reviewer ticks 13c, removes the queue item, moves PC-10 to Erledigt.
N4. **CM2-ARTREF** (MODEL section, Danach of PC-1): look check of the imported art against the reference screenshots; each deviation becomes a rework task (MODEL) with a re-upload of that asset.
N6. **Launch order from CM2-G12b.** After each launch-order task one art wiring task whose Depends are met runs, in this order: **CM2-12W**, **CM2-13W**, **CM2-14W**, then **CM2-44** (MODEL rule 4: one art task, one feature task).
   - Gate B: 17b **CM2-G12b** (plan `docs/plans/CM2-G12b.md`, tier L) → 17a **CM2-PP** (tier L, `planner-high`; its CM2-10W dependency is met by the committed map, the open capture pair does not gate it) → 18 **CM2-G11** (the group bonus stays hidden while the group ID is empty) → 19 **CM2-A1** → 20 **CM2-45** → 21 **CM2-G18** → 22 **CM2-43** → 22a **CM2-UI** → 22b **CM2-UI-TPL** → 23 **CM2-47** → 24 **CM2-48** → 25 **CM2-50a** → 25a **CM2-SPLIT-a** → 25b **CM2-SPLIT-b** → 25c **CM2-SPLIT-c**.
   - Gate C: 26 **CM2-35** → 27 **CM2-32/33** → 27a **CM2-G9c** → 27b **CM2-G9d** → 28 **CM2-45b** → 29 **CM2-28** → 30 **CM2-45c** → 31 **CM2-50**; then "After launch" 32–37.
N7. **Owner actions outside a task**: the friends test (line 15, `docs/FRIENDS_TEST.md`) once N2 and N3b passed; the Roblox group ID for line 18; the Swarve licence for line 22a is in (2026-11-25).

**Gate A — core loop and friends test (target 2026-11-26)**
1. [x] **CM2-G6 Observed wholesale table and Douglas Fir starter species**, done 2026-11-22, see archive
2. [x] **CM2-G20 Repeatable Studio playtest script**, done 2026-11-22, see archive
3. [x] **CM2-S1 Save slots per player**, done 2026-11-22, see archive
4. [x] **CM2-S2 Co-op saves and invite codes**, done 2026-11-22, see archive
5. [x] **CM2-S3 One server per save, teammate finder**, done 2026-11-22, see archive
5a. [x] **CM2-R5 Keep the save lock when the final save fails**, done 2026-11-22, see archive
5b. [x] **CM2-UV UI verification in a visible Studio window**, done 2026-11-22, see archive
5c. [x] **CM2-UVF1 One dialog at a time: Saves picker and Lot Manager**, done 2026-11-22, see archive
5d. [x] **CM2-UVF2 World labels do not overlap**, done 2026-11-22, see archive
5e. [x] **CM2-UVF4 Save row state text fits; the UI probe flags truncation**, done 2026-11-22, see archive
5f. [x] **CM2-UVF5 Picker rows never sit under the footer**, done 2026-11-22, see archive
5g. [x] **CM2-UVF6 Team panel on a Solo save hides New code**, done 2026-11-22, see archive
5h. [ ] **CM2-UV2 UI size check on phone, tablet and 1080p PC** · S · Depends: PC-4 (resolved by tool), PC-9 for j1 and j6 only, CM2-UVF1, CM2-UVF2, CM2-UVF4, CM2-UVF5, CM2-UVF6. Goal: the CM2-UV Size checklist (`docs/archive/plans/CM2-UV.md` D2: f1, f4, b1, c1, c2, d3, d5, h2, i4, j1, j6) on phone 667x375, tablet 1024x768 and PC 1920x1080, covering the device parts of CM2-UV (b) S1, (c) S2, (d) S3, (f) CM2-40, (h) G7, (i) G14, (j) N1. No source change; each defect becomes a fix task right after this line. Accept per device and item, PASS/FAIL in PROGRESS.md with captures: the probe (CM2-UV H4 plus the CM2-UVF4 truncation rule) is empty; nothing clipped or overlapping; touch targets ≥ 44 px; on the phone the rail clears thumbstick and jump button, the Lot Manager hides HUD and rail, the finder footer fits, the Pricing page scrolls to the last card; standard checks pass. The CM2-40 issue closes only after this task. `H("prompt")` returns ok even when nothing happens: stand within `Customers.InteractDistance` and check the effect.
   - Status 2026-11-24 (N1 (a)): iPhone 7 f1, f4, b1, c1, c2, h2 PASS; i4 FAIL → 5j (done); findings → 5k–5m; iPad and 1080 only first reading and picker probe (0 violations). Rest: queue item "N1 rest".
5i. [x] **CM2-UVF7 Far world labels do not overlap either**, done 2026-11-22, see archive
5j. [x] **CM2-UVF10 Phone: stocking bar and tutorial hint bar overlap, reason text cut off**, done 2026-11-25, see archive
5j1. [x] **CM2-SP1 Saves picker shows "no saves yet" and "Please wait" on a fresh Play**, done 2026-11-25, see archive
5k–5m (from N1 (a), readings at 666x374): each is tier S, planned by the `planner`, client layout only (no server rule, action, save field or remote change), headless all pass. Device re-check by the `playtester`: PC-4 Ablauf, iPhone 7 667x375 (`ViewportSize` 666x374 ±2 px), probe (CM2-UV H4 plus the CM2-UVF4 rule) empty, one HUD capture; PC and 1024x768 unchanged.
5k. [x] **CM2-UVF11 Phone: Supplier "Place order" button below the Lot Manager panel**, done 2026-11-25 (code 8e4ecbc; the tutorial highlight re-check goes to "N1 rest") · S · Depends: none. `OrderTrees` (16..340 x 302..346) lies mostly below the panel bottom (308) until wheel-scrolled; taps on its visible strip do nothing. Goal: on compact screens the order button (and the total it confirms) is fully inside the Lot Manager body and tappable without scrolling, for every species and quantity state (`src/client/LotManagerTabs/SupplierTab.lua`, `src/shared/UiTheme.lua`; `Supplier.*` actions, costs and validation unchanged). Accept: headless test at 666x374 and 667x375: the button box inside the manager body box, >= 44 px high; re-check without scrolling: `OrderTrees` `AbsolutePosition.Y + AbsoluteSize.Y` <= the page's clip bottom, a tap places an order (server cash and order list change once, `H("summary")`), the CM2-49 `Order` highlight sits on the button.
5l. [x] **CM2-UVF12 Phone: Pricing card controls need an extra scroll**, done 2026-11-25 (code 2f63ae4; the auto-pricing toggle is page-level at rel y 88, not inside a card, so "card with toggle" in the goal reads as card with its +/- row; short screens 666x324 and 780x302 only checked for 44 px and containment) · S · Depends: none; after 5k. A card is 180 px, as high as the page, so its -5/-1/+1/+5 row (e.g. `Price_BlueSpruce` at y 346) needs one more scroll tick (h2 still passes). Goal: on compact screens a whole card with its +/- row and auto-pricing toggle fits the page at once (card <= page height - 8 or a compact layout, the plan picks; `src/client/LotManagerTabs/PricingTab.lua`, `src/shared/UiTheme.lua`; prices and `Pricing.*` unchanged). Accept: headless test at 666x374: card <= page height - 8, every control in it >= 44 px; re-check card by card: each +/- row fully inside the page clip at its header's scroll position, +1 changes the server price by 1 (`H("summary")` `pricing`), the last card is reachable.
5m. [x] **CM2-UVF13 Phone: FinderButton near the thumbstick** · S · Depends: none; after 5l. The rail (8..132 x 8..212) clears, but `FinderButton` (rail order 70, `UiKit.addRailButton`; 8..126 x 200..244) ends past the rail bottom reserved by `UiTheme.metrics` (`THUMB_RESERVE` 96) and may touch the thumbstick ring top (estimate y 224; `TouchGui` not enumerable). Step 1 (`playtester`): one zoomed bottom-left capture at 667x375 with default touch controls; read ring top and button bottom in viewport pixels (`AbsolutePosition` + `GuiService:GetGuiInset()`); the plan covers both outcomes. Goal: every rail button, `FinderButton` included, ends <= `railTop + railMaxHeight` and >= 8 px above thumbstick ring and jump button on phones (also if step 1 shows a gap). Accept: headless at 666x374 and 667x375 for every rail button box; re-check: rail and `FinderButton` end >= 8 px above the measured ring top, the zoom capture shows the gap, a tap on `FinderButton` opens the finder.
   - Done 2026-11-25 (code, no plan): `UiTheme.hudLayout` returns `railButtons` boxes; on phones buttons that do not fit above the thumb reserve go right of row 1 (rail 200x188, 118x44 and 78x44 boxes); `UiKit.applyRail` places them. Headless 602/602; Studio iPhone 7 666x374: all five rail buttons visible, lowest button bottom 196, ring top 223 (gap 27 px), a tap on `FinderButton` opens `FinderPanel`, TextFits on all five. Tap on the other four rail buttons and the PC 1920x1080 one-column check are queued in "Studio-Test ausstehend".
6. [x] **CM2-40 HUD shell and Lot Manager navigation**, done 2026-11-22, see archive
7. [x] **CM2-G7 Price benchmark and Pricing tab**, done 2026-11-22, see archive
7a. [x] **CM2-G7a Noble Fir typical price: observed 184 vs derived 185**, done 2026-11-22, see archive
8. [x] **CM2-G14 Automatic unload and bay-to-display stocking**, done 2026-11-22, see archive
9. [x] **CM2-N1 Walking customer NPCs**, done 2026-11-22, see archive
9a. [x] **CM2-RF Split oversized modules, no behaviour change**, done 2026-11-23, see archive
9b. [x] **CM2-EOL LF working copies**, done 2026-11-23, see archive
10. [x] **CM2-N2 Manual checkout and queue**, done 2026-11-23, see archive
10a. [x] **CM2-UVF3 Checkout queue spacing and upright counter pose**, done 2026-11-22, see archive
11. [x] **CM2-G15 Customer reviews, rating and lot sign**, done 2026-11-23, see archive
12. [x] **CM2-25/26 Visible staff with energy and break area**, done 2026-11-23, see archive
12c. [x] **CM2-UVF9 Disabled staff and land buttons report inactive; trace the first Move click**, done 2026-11-24, see archive
13. [x] **CM2-46 Robux shop wired by ID**, done 2026-11-24, see archive (the real test purchases are line 13c)
13c. [ ] **CM2-46c Owner product IDs and test purchases** · S · Depends: PC-8 (resolved), CM2-46b. Goal: the owner's 12 IDs (DECISION_LOG "2026-11-24 — owner: Robux products created (PC-8)"; 4 passes, 8 products) in `src/shared/ShopConfig.lua`, no other config, price or code change; engineering never creates or activates a product. Done 3c5ac49 (N3): step 0 `GetProductInfo` matched all 12, IDs entered (the other 15 stay 0), config test (headless 586/586). Accept still open: CM2-46b playtest step 7 (one test purchase each of StarterPack, PassCashX2, CashPinecone, BoostCashX2; cash, boost and pass effects as in CM2-46a) PASS in PROGRESS.md; blocked by **PC-10**, runs as N3b.
13d. [x] **CM2-UVF8 Shop category bar fits, boost line always visible, "$" in cash packs**, done 2026-11-24, see archive (its captures: queue "Captures only")
14. [ ] **CM2-49 Short guided tutorial** · M · Depends: CM2-N2, CM2-40. First save only: order trees → stock them → check out the first customer, with arrows and one-line hints, skippable, never shown again for that save. Accept: headless test that tutorial progress is server-owned and survives a rejoin; Studio: a fresh save completes the tutorial in under 3 minutes on the phone simulator.
    - Status 2026-11-24: done in code (`docs/plans/CM2-49.md`); the headless Accept and every PC client check PASS. Open: the phone criterion (N1 (b), queue "N1 rest"; BLOCKED by PC-9 at the Place step; the last try took over 3 minutes, a world tap did not open the bay prompt, keyboard E did).
15. [x] **CM2-47a Friends-test build and checklist**, done 2026-11-23, see archive

**Gate B — Go/No-Go build (2026-11-28)**
16. [x] **CM2-G9 Progression ladder**, done 2026-11-24, see archive
17. [ ] **CM2-G12 Day/night, day counter and leaderboards** (covers CM2-36 part) · M · Depends: CM2-46 (Robux spent), CM2-S1. 18-minute day (12 day + 6 night), fewer customers at night, lights glow, the day advances only while a save is played; four leaderboards on the village square: Robux spent, hours played, cash earned, reputation. Accept: the cycle runs in Studio without frame drops on the mobile emulator; leaderboard writes are cached and rate-limited (test); "Robux spent" included (owner decision).
    - Status 2026-11-24: **CM2-G12a** (`docs/plans/CM2-G12a.md`: day/night per save, counter, night arrivals, lights) done in code 8571cf7, checks 1, 2 and the plot captures PASS; **CM2-G12b** (`docs/plans/CM2-G12b.md`: four leaderboards) not started. Tick after CM2-G12b and the square captures (PC-9); FPS is not tick-blocking.
17a. [ ] **CM2-PP Plot picker at session start** (owner, 2026-11-24) · L (the claim in `Save.Play` plus a new action; `planner-high`) · Depends: CM2-S1, CM2-10W (met, see N6). Goal: as in the reference (REFERENCE_GAME_LIVE_TEST section 1, item 1) the first player of a save on a server chooses the plot from a camera view over the map instead of getting the first free one; our own layout, wording and look (`UiTheme`/`UiKit`, UI rule until CM2-UI). Planner decisions:
    - When: after the save picker, only if the save holds no plot on this server yet; a teammate joining a save that already plays here attaches directly; a player teleported from a full server sees the picker again.
    - View: a scripted camera above the selected plot, tweened between plots; panel "Plot N of 6", browsed with arrow buttons, A/D and gamepad shoulder buttons; free: "Available" and its road side; taken: "Occupied – Home of <company name>", choose disabled. Preselected: the save's last plot if free, else the first free one. Choose → "Choose plot N?" Yes/No; after Yes the camera returns to the character on that plot.
    - Server: plot ids, numbers, road side and status come from the server; the chosen plot is claimed only if still free at that moment, else `PlotTaken` and the picker refreshes; nothing is reserved while browsing. `Save.Play` without a plot id keeps the automatic choice (`runPlaytest`, old clients); no free plot: today's teleport path (`NoFreePlot`).
  Accept: (a) headless: a free chosen plot is claimed; an occupied one gives `PlotTaken`, nothing changes; an unknown or mistyped plot id gives the bad-request error; no plot id gives the automatic plot; of two companies choosing the same plot in turn the second gets `PlotTaken`; a teammate joining a save that holds a plot gets it, no picker; the plot-list action is rate-limited like the other save actions. (b) Studio: with a shadow company on one plot the picker shows 6 plots with the right status, A/D and arrows browse, the camera follows, the taken plot cannot be chosen, Yes spawns the player there; `runPlaytest {mode="full"}` all PASS. (c) Phone and tablet: buttons >= 44 px inside the safe area (Device Simulator shots). (d) Standard checks; strings are English keys in `Localization.lua`.
18. [ ] **CM2-G11 Daily reward streak, quest board and group bonus** (covers CM2-34, CM2-36 part) · L · Depends: CM2-S1, CM2-40. 7-day streak (cash and reputation) and a board of 3 rotating quests (~4 h) plus a bonus quest for finishing all three; rewards claimed manually and idempotent; "Join group for 2× daily rewards" checked server-side with `IsInGroup`, group ID from the owner (empty → bonus hidden). Accept: tests for streak reset by server time, double-claim rejection and rotation without offline income; the 2× applies once per claim and only to group members. `Quest.Claim` already exists in `Protocol` (validator) and `CompanyStateService` with no client sender (CM2-SLIM note); this task adds the sender and reuses or replaces that scaffold with its tests.
19. [ ] **CM2-A1 Advent calendar** · L · Depends: CM2-S1, CM2-40. 24 doors, Dec 1–24 (server date, UTC); one door per day, rewards rising (cash, reputation, decor, boosts), specials on Dec 6 and Dec 24 (PROVISIONAL values in config); missed doors can be opened until Dec 24; per player, credited to the active save. Accept: headless tests with a fake clock: a future door is rejected, a missed door opens, each door pays once per player even across two saves, nothing opens after Dec 24; Studio with the clock set to Dec 3: doors 1–3 open, 4 locked.
20. [ ] **CM2-45 Event framework and 1st Advent event** (covers CM2-45 part) · L · Depends: CM2-46, CM2-G9. Timed event shop with countdown, event currency or cash as in the reference, special trees and a decor pack, switched on by a dated event config (2026-11-29, 12-06, 12-13, 12-20); event content for the 1st Advent with our own names. Event models are MODEL tasks; until they pass review, event items reuse existing models recoloured in our palette. Accept: headless tests that the event opens and closes on its dates, event purchases are idempotent, items persist after the event; Studio with the clock on 2026-11-29 shows the event shop.
21. [ ] **CM2-G18 Audio: HQ radio, music, effects, volume** · L (per-player volume is a new persisted profile field; `planner-high`) · Depends: CM2-40. Goal: an optional in-world radio prompt at the HQ, audible only on the own plot; music and effects from Roblox's licensed audio library; separate music and effects volume, saved per player. Accept: every audio ID with source and licence in `docs/AUDIO.md`, none copyrighted or unlicensed; headless: the volume fields migrate with defaults, clamp to 0–1, are rate-limited, survive a rejoin; Studio: the radio plays only inside the own plot area, the two sliders work separately and keep their values after a rejoin; standard checks and `runPlaytest {mode="full"}` all PASS.
22. [ ] **CM2-43 English-only strings and accessibility** (re-scoped) · S · Depends: CM2-40. The client always uses English at launch (Roblox auto-translation covers others); DE entries stay in `Localization.lua` for the later language switch; an audit removes concatenated fragments; text scaling and contrast checked. Accept: a headless test that every key has an English full sentence and no UI string is built from fragments; Studio screenshots with a German Roblox locale show English.
   - Note (CM2-G14 review): bay labels (`BayFree`, `BayArriving`, `BayContents`) re-localize only on `AttributeChanged` while the server rewrites the English `Text` every 1 s, so a non-English client shows English on unchanged bays; fix before the language switch (re-localize on `Text` changes, or the server skips unchanged text).
22a. [ ] **CM2-UI Final UI redesign** (owner: the last task before release) · M (look only; no money, saves or remotes) · Depends: orders 1–22 that are done, CM2-UV; 3D-world captures (PC-9) for the screenshots; PC-2 or an owner upload for images. Goal: one visual pass over every screen on the Swarve pack (b) and a style guide; behaviour unchanged. Accept:
    - (a) The owner's liked and disliked UI screenshots or a mockup in `docs/art/ui-reference/` with a README table like `docs/art/quality-reference/`; if none exist at the start, the planner writes the target from PRODUCT_SPEC and records that.
    - (b) Look per PRODUCT_SPEC "UI look" and DECISION_LOG 2026-11-25 "owner: CM2-UI built on the Swarve pack" (what of the Essential UI Pack is used and not used, colours, tinting, asset-ID upload via PC-2; licence `assets/third_party/swarve-essential-ui/LICENSE.md`, contents and IDs in `INVENTORY.md` there; the `.rbxl` stays gitignored). Pack layout patterns: left HUD button rail, currency bar, title-bar windows with a close button, scrolling shop cards, upgrade cards with before/after stats, the fading notification. The plan maps every pack screen to ours (e.g. Shop → Robux shop, Upgrades → upgrade tabs, Notifications → toasts, HUD rail → our HUD buttons) and every screen in (c) to a pack pattern; pack icons without meaning here (strength, gems, wheel, rebirth) become Christmas-market icons in the pack's style. Only rebuilt values and asset IDs are committed, never raw pack files.
    - (c) Style guide in `UiTheme` (colours, fonts and weights, text sizes, corner, stroke, shadow, tap sizes, tween times, image IDs), read by every screen. `UiKit` interaction on every button, tab and tappable row with the pack's values: hover 110 % in 0.2 s, press 90 % in 0.1 s (Quad Out, through a `UIScale`, layout does not move), hover sound at volume 0.5, click sound at 0.7; touch gets only the press effect; the selected tab clearly marked; a dim layer under stacked dialogs (CM2-UV). Screens: HUD, Lot Manager and all tabs, save picker, Team panel, teammate finder, stocking bar, Robux shop, tutorial hints, daily rewards and quests, Advent calendar, event shop, settings, world labels.
    - (d) No behaviour change: same headless and `runPlaytest {mode="full"}` counts, all PASS; no change to remotes, error codes, string keys or save fields.
    - (e) Device Simulator shots of every screen on phone, tablet and 1080p PC in PROGRESS.md: nothing clipped or overlapping, touch targets ≥ 48 px (primary ≥ 56 px on phone), titles, buttons and numbers in the heavy font, inside the safe area; up to three review rounds against the reference.
22b. [ ] **CM2-UI-TPL Swarve UI kit as an optional add-on in the template repo** (owner 2026-11-25) · S · Depends: CM2-UI. Goal: the Swarve-based look of CM2-UI is reusable in `Valentindghjg/roblox-game-template`, not forced on new games; work in the sibling checkout `../roblox-game-template` (commit and push there), this repo gets only the PROGRESS entry. Accept: (a) the pack-based `UiTheme` values (fonts, strokes, gradients, image and sound IDs, tweens) and the generic `UiKit` builders and button interaction are one self-contained add-on there, with no Christmas Tree Village names, strings, screens or logic; (b) off by default (a fresh template build has none of it); README "Optional: Swarve UI pack" says in at most 10 steps how to switch it on and use one builder; (c) the template checks pass with it off and on (StyLua, Selene, luau-lsp, unit tests, both Rojo builds), one unit test covers its builders; (d) no raw pack file committed (`.gitignore`); `LICENSE.md` and `INVENTORY.md` in the template's `assets/third_party/swarve-essential-ui/`.
23. [ ] **CM2-47 End-to-end, multiplayer and security QA** · M · Depends: orders 1–22 that are done. Exploit pass on every remote and prompt (forged payloads, floods, other-plot and other-save actions, purchase replay), the full Studio script, a 6-plot load soak. Accept: every remote and prompt in PROGRESS.md with its forged-payload, flood and cross-plot/cross-save result; each defect fixed or filed as a blocking ticket right after this line; `runPlaytest {mode="full"}` all PASS; the soak (>= 10 min) leaves no NPC, car or tree behind and keeps the server heartbeat >= 55 FPS; in it, a plot of 4–6 at HQ 2 captured from the road shows the roof sloping and the counter facing the road as on plots 1–3 (CM2-G9a).
24. [ ] **CM2-48 Release candidate and owner checklist** (re-scoped: the owner publishes) · S · Depends: CM2-47. `docs/RELEASE_CHECKLIST.md` for the owner: place settings (12 players, API access, DataStore names), product and gamepass creation with names and prices, group ID, experience questionnaire and content maturity, thumbnails and description, private build to public switch. Accept: the checklist is complete and every engineering item on it is ticked with evidence; engineering publishes nothing.
25. [ ] **CM2-50a Go/No-Go regression** (part of CM2-50) · S · Depends: CM2-48. The Studio script and all checks on the release-candidate commit; a one-page Go/No-Go summary for the owner on 2026-11-28 (what works, known issues, what is out). Accept: summary in PROGRESS.md with the commit SHA.
25a–25c. **Luau files over 800 lines** (from CM2-SLIM; after CM2-50a so the release-candidate commit stays unchanged until the owner's Go/No-Go). Pure refactors: no behaviour, remote, error-code, string-key or save-field change. Common Accept: every touched file <= 800 lines (`wc -l`); moved code in new modules placed by TECHNICAL_ARCHITECTURE section 1 and named in the plan; standard checks with the same headless count; `runPlaytest {mode="full"}` same step count, all PASS.
- 25a. [ ] **CM2-SPLIT-a Split Localization and WorldService** · M · Depends: CM2-50a. `src/shared/Localization.lua` (925; e.g. EN and DE tables into child modules, the API unchanged) and `src/server/Services/WorldService.lua` (1499; map building vs. runtime world state).
- 25b. [ ] **CM2-SPLIT-b Split main.server and CustomerNpcService** · M · Depends: CM2-SPLIT-a. `src/server/main.server.lua` (1104; service wiring vs. the Studio test hooks) and `src/server/Services/CustomerNpcService.lua` (1009; spawning/pathing vs. checkout queue). Plus Studio: one customer visit with checkout and one tree delivery PASS.
- 25c. [ ] **CM2-SPLIT-c Split CompanyStateService, BusinessState and their tests** · L (`planner-high`; save, money and inventory paths) · Depends: CM2-SPLIT-b. `src/server/Services/CompanyStateService.lua` (1481), `src/shared/BusinessState.lua` (960), `tests/studio/Cases/CompanyStateService_Test.lua` (1171) and `tests/studio/Cases/CoopSave_Test.lua` (862). Extra Accept: the save schema version and every persisted field are byte-equal before and after (a headless round-trip of a fixture save); the double-spend, duplicate-order and idempotency tests are kept unchanged and pass; Studio: purchase → delivery → sale → save/rejoin PASS.

**Gate C — by the 2nd Advent (2026-12-06)**
26. [ ] **CM2-35 Analytics and appeal** (covers CM2-35, CM2-G8, CM2-27 appeal part) · M · Depends: CM2-N2. Analytics tab as in the reference (cards, sales chart, best sellers, more stats, decor block); in the demand model lot appeal (trees on display, species × size variety, cap from lot size) raises price tolerance (+2 % observed) and decor appeal adds sightseers and tips. Accept: both metrics shown in Analytics; unit tests for appeal growth over time and its effect on the accepted price; the tab shows server values exactly and history stays bounded.
27. [ ] **CM2-32/33 Decor catalog, layout mode and stock zones** (covers CM2-32, CM2-33, CM2-G13, CM2-42) · L · Depends: CM2-G9, CM2-35. Catalog bought with cash, items placed from a crate, move/rotate/put away/clear all, a decorate inventory with search; stock zones with species and height filters and priority; a free movable HQ (checkout and staff move with it) blocked by other structures. Launch decor: small Part-built items (PRODUCT_SPEC Art) until MODEL tasks deliver more. Accept: each item demonstrated in Studio and covered by server validation tests for overlaps and plot bounds; placements persist.
27a. [ ] **CM2-G9c Lot Manager at the HQ computer** · L · Depends: CM2-G9a, CM2-G9b. G9a only unlocks the hire ("Standby"). Goal: a hired Lot Manager appears as a visible original avatar, walks to a computer at the HQ and orders trees through the player's server supplier-order path (server quotes and costs, company cash, storage and bay limits, never a client cost). Accept: headless: its orders debit cash once per order (idempotent ids), stop when cash, storage or bays are short, never exceed the player's order limits; the Employees status leaves "Standby"; Studio: the avatar walks to the computer and a delivery it ordered arrives; `runPlaytest {mode="full"}` all PASS.
27b. [ ] **CM2-G9d HQ unlock content** · L + MODEL · Depends: CM2-G9a, CM2-G9b. Goal: the inactive HQ unlocks become real: new species per HQ tier (`newSpecies`, own names, wholesale by the 5x rule, supplier rows by HQ level, original tree models) and the 2nd/3rd checkout station (`checkoutStations`) with its own queue and Cashier. Accept: headless: supplier rows only at the required HQ level, server prices by the 5x rule, each station serves its own queue, sales idempotent; the unlock entries `active = true`; models pass the modeler self-review; Studio: HQ 2 shows the new species at the supplier and a second station serves customers; `runPlaytest {mode="full"}` all PASS. Before line 29 (the balance pass needs them).
28. [ ] **CM2-45b 2nd Advent event content** (part of CM2-45) · M · Depends: CM2-45. Content for 2026-12-06 in the event config. Accept: Studio with the clock on 2026-12-06 shows the new shop; the 1st event's items are kept.
29. [ ] **CM2-28 Balance pass and anti-exploit economy tests** · M · Depends: CM2-G9, CM2-35. Replace PROVISIONAL values observed meanwhile; a simulated 2-hour economy run per tier stays inside target cash/reputation curves. Accept: simulation test in the headless runner; every changed value carries its evidence tag.
   - Note 2026-11-22 (planner, from CM2-N2 and CM2-G15): high abandoned-visit rate (R 25/38, S 40/70 visits abandoned with 0 walk-outs, i.e. non-conversions); review the demand and conversion values in this balance pass. Walk-outs and abandoned visits leave no review (CM2-G15).
30. [ ] **CM2-45c 3rd and 4th Advent event content** · M · Depends: CM2-45b. For 2026-12-13 and 12-20. Accept: as order 28 for each date.
31. [ ] **CM2-50 Final integration and regression** · S · Depends: everything done before. Accept: full Studio script PASS on the release commit, recorded in PROGRESS.md.

**MODEL tasks** (reference images in `docs/art/quality-reference/`). The modeler builds in Blender (DECISION_LOG 2026-11-22) with the skill `cm2-modeling`. All art below except CM2-44 is modelled and imported (N5); its captures are queue items (PC-9). Wiring tasks and CM2-44 alternate with the launch order (N6). A wiring task changes no server rule, save field or remote; it uses the art from `ArtLibrary` when present and today's primitive when absent, tested headless with a fake `ArtLibrary`, and in Studio a checkout without `.rbxm` still shows the primitives and `runPlaytest {mode="full"}` all PASS.
- [x] **CM2-R2 → CM2-AP Asset pipeline for Blender MeshParts**, done 2026-11-22, see archive
- [x] **CM2-ART1 Art render writes inside the repo**, done 2026-11-22, see archive
- [ ] **CM2-ARTREF Look check of the modelled art against the reference screenshots** · MODEL (review only) · Depends: PC-1. Goal: the `modeler` compares the previews of all 41 assets (`assets/art/previews/`) with the screenshots in `docs/references/roblox-game/` (silhouette, proportions, palette, detail; checklist `docs/art/quality-reference/`), changing no `.blend`, mesh, preview or config. Accept: a PROGRESS.md table, one row per asset (art path, screenshot, "match" or "deviation: <what>"); each deviation visible to players becomes a rework task (MODEL) here with a re-upload (PC-1 decision); nothing committed under `docs/references/`; standard checks unchanged.
- [ ] **CM2-12 Trees** (4 starter species × 3 sizes, special trees) · MODEL · Depends: CM2-AP, PC-2 (done). Imported (`docs/plans/CM2-12.md`, ea85333), Edit-mode steps PASS. Open: queue "CM2-12 trees"; then CM2-12W.
- [ ] **CM2-12W Tree art in the world** · M · Depends: CM2-12 ticked. Goal: `WorldService` builds display, pickup, carried, roof and forest trees from `ArtLibrary.find("Trees/<species>/<size>")`; the label height follows the model. Accept: headless per tree role (art or primitive) and each label above the model top for every size; Studio: all five roles show the meshes for 4 species × 3 sizes, no tree floats or sinks; a 10-minute soak keeps the server heartbeat ≥ 55 FPS; captures in PROGRESS.md.
- [ ] **CM2-13 HQ tiers, fence, bays, checkout** (Sales Tent, Timber Pavilion, Alpine Hut, Mountain Chalet) · MODEL. Split into **CM2-13a** HQ tiers (`docs/plans/CM2-13a.md`) and **CM2-13b** fence, bays, bundles, checkout counter (`docs/plans/CM2-13b.md`); both imported, Edit-mode steps PASS. Open: queue "CM2-13a and CM2-13b art". Tick 13a, 13b and 13 after it.
- [ ] **CM2-13W Lot and HQ art in the world** · M · Depends: CM2-13a, CM2-13b `.rbxm` (done). Goal: `WorldService` builds HQ tier, checkout counter, bays, bundles and fence from `ArtLibrary`. Model fronts face −Z, so HQ and counter turn 180° on plots 1–3 and 0° on plots 4–6 to face the road; config tier `ChristmasPavilion` maps to `Buildings/TimberPavilion` until renamed. Accept (settled by its plan): headless incl. rotation per plot side; Studio: all 6 plots show the art facing the road.
- [ ] **CM2-14 Supplier truck and customer cars** · MODEL. Imported (`docs/plans/CM2-14.md`, 41909ed), Edit-mode steps PASS. Open: queue "CM2-14 vehicles art"; then CM2-14W.
- [ ] **CM2-14W Vehicle art in the world** · M · Depends: CM2-14, the CM2-13b `TreeBundle` `.rbxm`. Goal: `WorldService` builds truck and customer cars from `ArtLibrary`; origin on the ground (lot top 0.55, lane top 0); truck cab faces the road (yaw 180° on plots 1–3, 0° on 4–6); cars nose into the lot (0° on 1–3, 180° on 4–6); car body = order number mod 3, `Paint` coloured from `CAR_COLORS`; roof tree at the car's `CargoAnchor`; up to min(arriving, 9) `Props/TreeBundle` on the truck bed (`CargoAnchor`) while it pulls in, empty on leaving; label, `LoadOrder` prompt and reach check on `ArtRoot`. Also fixes the primitive car ~0.55 below the lot surface and the primitive cab always facing +Z. Accept: headless incl. yaw per plot side; Studio: all 6 plots show truck and car art on the ground.
- [ ] **CM2-10 Mountain-village map** (covered bridge over a frozen stream, village square with the big tree and leaderboards, 6 plots on the village road, forest and mountains; plots keep room for all expansion levels) · MODEL. Split into **CM2-10a** (`docs/plans/CM2-10a.md`), **CM2-10b** (`docs/plans/CM2-10b.md`), **CM2-10c** (`docs/plans/CM2-10c.md`); 13 models imported (0666c73). Open: queue "CM2-10a, CM2-10b and CM2-10c map art". Tick 10a, 10b, 10c and 10 after it.
- [ ] **CM2-10W Map in the world** · M · Depends: CM2-10a, CM2-10b, CM2-10c. Goal: `src/shared/MapLayout.lua` holds the MODEL_INTEGRATION "Map layout (CM2-10)" contract; `WorldService` builds the map with the 13 map models through `ArtLibrary` (Part fallbacks), 20 reserve firs per plot hidden row by row as the lot expands, legacy scenery removed. Done in code (`docs/plans/CM2-10W.md`; full run 62/62, `MAP_WORLD` art 302, overlaps 0; reserve numbers PASS). Accept still open: the art re-check captures and the reserve capture pair (queue). Desktop and phone FPS (>= 55) are recorded under PC-9, not tick-blocking.
- [x] **CM2-ART2 ArtLibrary.root ignores asset-less folders**, done 2026-11-24, see archive
- [ ] **CM2-44 Art pass and removal of all Codex/CC0 models** · MODEL · Depends: the four above. Accept: no model from `assets/third_party/` remains in the place.
  - Note 2026-11-23 (CM2-10W split): CM2-10W removed only the world placements of the CC0 scenery, the market alley (incl. `MarketGazebo`) and the primitive showcase and forest trees. CM2-44 keeps the remaining CC0 uses (stand `MarketStarter`/`MarketPavilion`, `FenceWooden` until CM2-13W), deleting the CC0 templates from the place's `ArtAssets`, the `AssetCatalog` clean-up and `assets/third_party/`.

**After launch**
32. [ ] **CM2-R4 Strict Luau types for all of `src/shared`** · S · Depends: the Roblox definitions file in CI. Accept: `luau-lsp analyze` passes for all `src/shared` modules in CI.
33. [ ] **Gamepad support** (PRODUCT_SPEC: after launch) · M.
34. [ ] **In-game language switch (DE, ES, …)** · M.
35. [ ] **Cross-server teammate matchmaking** · L.
36. [ ] **CM2-G17 Season pass** (design first; not in the launch shop list) · S · Depends: owner approval for any paid feature. A free and a premium track fed by sales and quests. Accept: design doc only; the premium track and Robux products stay disabled (PRODUCT_SPEC) until the owner explicitly approves.
37. [ ] **Paid random rolls (version 2)** with disclosed odds and `PolicyService` restrictions · L · needs an owner decision at the time.

### Owner inputs that unblock tasks
Open: the PC entries above, the Roblox group ID (line 18), friends-test players (line 15) and liked/disliked UI screenshots or a mockup in `docs/art/ui-reference/` (22a). Resolved and archived: PC-2, PC-3/PC-7, PC-4 (by tool), PC-5, PC-6, PC-8, PC-11, the model reference images.

## Milestone gates
- P0: tools, unit tests, safe persistence and network foundation.
- P1: order -> delivery -> display -> NPC checkout -> rejoin playable in Studio.
- P2: realistic demand, customer behavior and staff automation.
- P3: upgrade/decor/quests/analytics implemented and persisted.
- P4: shared company, UI, input and localization verified.
- P5: original art polish, seasonal event, security and QA; no release without approval.

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

## 2026-11-28 CM2-47D2 Notify drains client sends (23a, tier S, no plan)
- Commit 343cd29: `notify.OnServerEvent:Connect(function() end)` after `notify.Parent = remotes` in `src/server/main.server.lua`, plus an inline source-text case in `tests/headless/run.luau` (inlined because the runner discovers cases only in `tests/studio/Cases`).
- Checks: stylua PASS; selene 0 errors, 0 warnings; headless 796 run, 796 passed, 0 failed (795 + 1); rojo build PASS.
- Studio (playtester, run now): source line 65 confirmed; C1 `Notify:FireServer(1)` x300 no error, no "invocation queue exhausted" line (only the pre-existing ContentId 203785492 warning x6); smoke 13/13 PASS (60 s). No failed or blocked step.
- CM2-47 table row "Notify" marked FIXED 343cd29; 23a ticked.

## 2026-11-28 CM2-SLIM10 MODEL_INTEGRATION.md shrunk to 29.5 KB (tier S, docs only, no plan)
- `docs/MODEL_INTEGRATION.md` 39,630 -> 29,462 B; 30 lines moved verbatim (checked line by line) to `docs/archive/MODEL_INTEGRATION_2026-11-28.md` (13,012 B) under their original headings; all 23 headings kept, each section carries an "Archived detail" pointer line.
- Moved: colliders, attachments, measured sizes and triangle tables, budgets, imports, measured clearances, sums, defect lines. Kept: world frame, keep-out boxes, landmarks, zones, `Dress_`/`Infra_` placement lists, fence/gate, 10W/12W/13W/14W wiring, Map art W x L lines.
- Citations resolve: `MapLayout.lua` "Map layout (CM2-10)", `LotArt.lua` CM2-GATE, `cm2_kit.py` "Asset pipeline" (all headings kept); no test or tool reads the doc text.
- Checks: stylua PASS; selene 0 warnings, 0 errors; headless 796 run, 796 passed (unchanged); rojo build PASS. Studio: not run (docs only).

## 2026-11-28 CM2-SLIM run 6 repo hygiene (tier S, standing plan `docs/plans/CM2-SLIM.md`; commits f6e2bfc, dff3698)
- Moved `docs/plans/CM2-47.md` to `docs/archive/plans/` (f6e2bfc, rename only); links updated in CLAUDE_BACKLOG, DECISION_LOG, PROGRESS and one comment in `tests/studio/Playtest/Steps/Exploit.lua`. Backlog lines 23, 23a and SLIM10 cut to one-liners, full text appended to `docs/archive/BACKLOG_DONE_2026-11-28.md` (dff3698).
- Sizes before -> after: backlog 68.7 -> 66.0 KB (still over 60 KB; the rest is open tasks), DECISION_LOG 62.7 KB unchanged (nothing movable without a planner call), PROGRESS 16.0 KB, MODEL_INTEGRATION 29.5 KB (CM2-SLIM10).
- Open item for the planner: backlog and DECISION_LOG are over 60 KB and need a planner pass (CM2-BLIDX already covers the backlog index).
- Checks (reviewer): stylua PASS; selene 0 errors, 0 warnings; headless 796 run, 796 passed; rojo default build PASS. Studio: not needed (docs and one comment).

## 2026-11-28 CM2-48 Release checklist (24, tier S docs only, no plan)
- `docs/RELEASE_CHECKLIST.md` rewritten (replaces the CM2-46 stub): Part A engineering items ticked with evidence, Part B owner steps in German (unticked), Part C 27-product price table. Engineering publishes and enables nothing.
- Review: prices, names and the 12 "ja" rows match `ShopConfig.lua:65-93` and `Localization.lua`; sampled 25 file:line references (main.server.lua, MonetizationService, GameConfig, store names, release.project.json:3) all hit; one wrong reference fixed (Max Players now cites `PRODUCT_SPEC.md:14`). No username, UserId or email in the file.
- Left open for CM2-50a: Studio full run on the release candidate and the Go/No-Go page, the open launch items (PC-12, PC-14, PC-15).
- Checks (reviewer): stylua PASS; selene 0 errors, 0 warnings; headless 796 run, 796 passed; rojo default build PASS. Studio: not needed (docs only).

## 2026-11-28 CM2-50a Go/No-Go (25, tier S, no plan) — Release-Kandidat `debc1cb`
**Seite für den Owner (Deutsch).** Alle Checks und der Studio-Gesamtlauf liefen auf `debc1cb`.

**Belege**
- stylua --check PASS; selene 0 Fehler, 0 Warnungen; headless 796 run, 796 passed, 0 failed; rojo build default und release PASS; `art.luau verify release.rbxlx`: 61 integrated, 0 pending, 0 failed.
- Studio (playtester, `debc1cb`, Rojo-Baum bestätigt): Unit-Runner 795/795 (headless hat einen Inline-Test mehr); `[PLAYTEST] SUMMARY mode=full steps=78 pass=78 fail=0 skip=0 seconds=870 result=PASS`.
- Soak nicht neu gelaufen: 8/8 PASS bei `b561241`, min. 58.1 FPS; seither nur die Notify-Änderung `343cd29`.
- Warnungen im Lauf: MissingArtAsset `Trees/FrostcrownFir/Small` (CM2-SLIM9 angelegt); ContentId 203785492 (alt, harmlos).

**Was funktioniert (Startliste, Beleg im Backlog)**
- Kernschleife Gate A (Zeilen 1-13d, 14a, 15): Kunden laufen, manuelles Kassieren, Personal, Speichern mit Duo/Trio/Quad und Einladungscode, Robux-Shop, Touch-UI. Studio 78/78.
- Progression (16 CM2-G9), Tag/Nacht, Tageszähler und Ranglisten (17 CM2-G12), Quests und Tagesbelohnungen (18): fertig, im Gesamtlauf grün.
- Lieferanten-Warenkorb (18a CM2-SUP, `3c2fdaf`, Schritt 70): Server und Desktop grün.
- Adventskalender (19 CM2-A1, Schema 22, Schritt 71) und 1.-Advent-Event (20 CM2-45, Schema 23, Schritt 72): Server und Desktop grün.
- Englische Texte (22 CM2-43, `be0adc9`, `510a5c7`): Code und Desktop grün.
- UI-Neugestaltung: CM2-UI1, UI2, UI3 Teil 1, UI3D, UI3M (`d708ccd`) fertig; Desktop-H4b 0 Fehler.
- Karte und Infrastruktur: CM2-10D/10DW (110 Teile), CM2-10I/10IW (`04b30d7`; 489 Modelle, 59 Nachtlichter), Release-Build mit 61 Kunstmodellen.
- QA und Sicherheit: CM2-47 (Remote-Tabelle, Idempotenz der Käufe, `ProcessReceipt`), D2 `Notify` behoben (`343cd29`); CM2-48 Release-Checkliste.

**Bekannte Probleme**
- Der Play-Screenshot ist schwarz: keine visuellen Prüfungen (Optik, Lesbarkeit) in diesem Lauf; nur Zahlen und Probes.
- CM2-SLIM9: Warnung MissingArtAsset `FrostcrownFir/Small` (nur Warnung).
- CM2-47D1 (Spielpass-Besitz vor dem Gewähren bestätigen): optionale Härtung, kein Exploit, nach dem Start.
- Telefon-/Tablet-Werte (Tutorial-Zeit, Layouts, deutsche Sprache) sind nicht gemessen.

**OUT of 1st Advent launch (nicht erledigt)**
- CM2-49T (PC-12): Tutorial-Zeit auf dem Telefon; Zeile 14 offen, damit Gate A nicht geschlossen.
- CM2-SUPP (PC-14): Telefon- und Deutsch-Messwerte; Zeilen 18a, 18a1, 19, 20, 22 bleiben offen (Desktop grün).
- CM2-UI3H (PC-15): Telefon-HUD <= 20 %; 22a3 offen. CM2-UIP (PC-14): 22a4 offen, daher 22a CM2-UI offen.
- Weiter nicht in der Startliste: CM2-G18 Audio, CM2-13D, CM2-44, CM2-ARTREF (Gate C); CM2-SPLIT-a/b/c, CM2-UI-TPL (nach dem Start); Freundestest (Zeile 15 optional).

**Owner-Schritte vor dem Veröffentlichen** (`docs/RELEASE_CHECKLIST.md` Teil B, alle offen)
- B1 Place: Max Players 12, "Studio Access to API Services" an. B2 DataStore-Namen nicht umbenennen.
- B3 Die 12 Produkte "ja" im Creator Hub gegen Teil C prüfen; die 15 "später" nicht anlegen. B4 Gruppen-ID (optional).
- B5 Fragebogen/Altersfreigabe, Beschreibung, Symbol und Thumbnails, Geräte aktivieren, Auto-Übersetzung.
- B6 Release-Datei aus `release.project.json`, in Studio "Publish to Roblox" (privat), selbst testen, dann Privacy auf Öffentlich.
- Teil A: zwei Punkte hier erledigt (Gesamtlauf, Startliste-Stand); der Rest ist mit Beleg abgehakt.

**Entscheidung des Owners**
- **2026-11-29, reduzierter Umfang:** Stand `debc1cb` ist technisch grün (796/796, Studio 78/78). Fehlt: Telefon-Tutorialzeit (Gate A Zeile 14), Telefon-/Deutsch-Messungen, Telefon-HUD-Entscheidung. Alle Owner-Schritte B1-B6 müssten heute noch erledigt werden. Backlog-Regel: nur wenn diese Seite vor dem 29. fertig ist.
- **2026-12-06:** Zeit für PC-12, PC-14, PC-15 und die Folgeaufgaben (49T, SUPP, UI3H, UIP, ggf. Fixaufgaben bei FAIL), danach Gate C (Audio, 13D, 44, ARTREF) und die nach dem 28. gestrichenen Punkte.
- Review (CM2-50a): in/out lists match the backlog launch list (1-3, cut line, Deferred); SHAs exist; no save key, user ID or name in the entry (grep). Checks (reviewer): stylua PASS; selene 0/0; headless 796/796; rojo default build PASS. Studio evidence is the playtester run on `debc1cb` above.

## 2026-11-28 RELEASE_CHECKLIST Part B evidence (docs only)
- Ticked B1.1 (Max Players 50 to 12 in Creator Hub), B1.2 (Studio API access already on, DataStore GetAsync probe ok), B1.3 (HttpService not touched), B3.1 (all 12 products verified via GetProductInfo, IsForSale true), B3.2 and B3.3 (Hub holds only the 12 products). Gathered by the main session in the owner's Creator Hub and via Studio MCP; no code change, no headless run needed.

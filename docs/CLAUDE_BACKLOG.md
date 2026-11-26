# Claude Code — 50-task development backlog
Updated: 2026-11-26 (planner, end-of-run refresh after the 2026-11-26 hasseln run, ended by the owner: CM2-ASSETWARN closed as engine noise (DECISION_LOG 2026-11-26), PC-10 resolved, PC-12 added for the line 14 phone time, done lines compacted, "Next hasseln starts here" rewritten. Older notes: `docs/archive/BACKLOG_DONE_2026-11-22_to_2026-11-25.md`, `docs/archive/BACKLOG_DONE_2026-11-21_to_2026-11-25.md`, `docs/archive/BACKLOG_RUNS_2026-11-22_to_2026-11-24.md`; texts dropped by this refresh are in git history, stand eee5e8b).
Status: binding order = "Launch order". Done: Gate A lines 1–15 except 14 (with 5a–5n, 7a, 9a, 9b, 10a, 12c, 13c, 13d, 14a); Gate B lines 16, 17 (17a CM2-PP, 17b CM2-G12b); CM2-SALE2; MODEL CM2-10 (10a–10c), CM2-10W, CM2-12, CM2-12W, CM2-13 (13a, 13b), CM2-13W, CM2-14. Open in Gate A: only line 14 (CM2-49 phone time, PC-12). Friends test (line 15) is unblocked, an owner action. Open PC entries: PC-1, PC-12. Owner decision 2026-11-25 (DECISION_LOG): FPS measurements and world/art captures gate no tick and are not run; where an Accept below still names them, the numeric checks decide. Hygiene: last CM2-SLIM commit 17da09b (2026-11-25); 7 `feat`/`fix` commits since, so the next `feat`/`fix` commit (CM2-13W) makes CM2-SLIM due; backlog about 49 KB. GitHub issues stay open until the owner closes them.

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
- Danach: CM2-ARTREF („Next hasseln starts here“ Punkt 1, nach CM2-49T). Planner-Entscheidung 2026-11-24: die Import-Kette N5 ist ohne ARTREF gelaufen (alle 41 Modelle importiert und committet); eine Abweichung, die ARTREF findet, wird als Nacharbeit (MODEL) mit erneutem Upload des betroffenen Assets angelegt.
- WIP-Branch: none
- Seit: 2026-11-22, Owner-Gespräch

### PC-12 Tutorial auf dem Telefon selbst spielen und die Zeit stoppen (CM2-49, Zeile 14)
- Status: offen
- Art: studio
- Problem: Gate A hängt nur noch am Zeitkriterium von Zeile 14 („ein neuer Spielstand schafft das Tutorial auf dem Telefon-Simulator in unter 3 Minuten“); alle Funktionsschritte sind PASS, aber der Agent-Lauf brauchte 341 s, weil jede Werkzeugaktion des Agenten Sekunden kostet; eine Spielerzeit misst nur ein Mensch.
- Deine Schritte:
  1. Roblox Studio mit dem Projekt-Place öffnen, Rojo verbinden, `main` aktuell.
  2. Test → Device: „iPhone 7“ (oder ein anderes Telefon) wählen, dann Play.
  3. Im Spielstand-Menü einen neuen Spielstand anlegen (Solo); in dem Moment eine Stoppuhr starten.
  4. Das Tutorial den Hinweisen nach spielen: Bäume bestellen, sie nach der Lieferung aufstellen, den ersten Kunden an der Kasse bedienen. Stoppen, wenn der Hinweis verschwindet (Tutorial fertig).
  5. Im Chat schreiben: „PC-12: <Minuten:Sekunden>“ (z. B. „PC-12: 2:40“), dazu falls etwas hakte, einen Satz dazu. Den Test-Spielstand danach löschen.
- Prüfen: der Owner hat im Chat „PC-12: <Zeit>“ geschrieben, oder PROGRESS.md enthält die Owner-Zeit für Zeile 14.
- Blockiert: Zeile 14 CM2-49 (letzter offener Punkt von Gate A); sonst nichts.
- Danach: CM2-49T („Next hasseln starts here“ Punkt 1).
- WIP-Branch: none
- Seit: 2026-11-26, hasseln (Planner-Entscheidung im End-of-run-Refresh)

#### Erledigt

- PC-10 Testkäufe in Studio: „Buy“ klicken (CM2-46c, Zeile 13c), erledigt 2026-11-26. Erledigt-Grund: N3b lief mit dem Owner am PC; 7a, 7c, 7d und die Idempotenz PASS, 7b per Owner-Entscheidung nicht getestet (DECISION_LOG 2026-11-26 „Owner: PassCashX2 test purchase skipped“), Zeile 13c abgehakt, siehe PROGRESS. Früherer Text in der Git-Historie (Stand eee5e8b).
- PC-9 Bildrate in Studio ohne 15-FPS-Grenze messen, schwarze Play-Captures, erledigt 2026-11-25 (Owner: gestrichen). Erledigt-Grund: Owner-Entscheidung 2026-11-25 (DECISION_LOG „owner: drop PC-9“): FPS-Messungen und Welt-Captures sind keine Testbedingung mehr und laufen nicht; die davon abhängigen Haken sind gesetzt bzw. die Bedingungen gestrichen. Der frühere Text steht in der Git-Historie (Stand be3489e).
  - Befund (Owner, Probe einer anderen Sitzung, 2026-11-25 ~18:10, main @ be3489e): Play-Capture zeigt die 3D-Welt (1564x730, nicht mehr schwarz); Client-RenderStepped über 10 s im Mittel 15,0 FPS (min 14,6, längster Frame 68,5 ms), die 15-FPS-Grenze besteht weiter, gated aber nichts mehr; Rojo synchron (Live-Studio hat den CM2-UVF13-Code); Konsole: Warnung `rbxassetid://203785492` 5x, keine Lua-Fehler.
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
Done parts and the 2026-11-24 batch history are archived. Owner decision 2026-11-25 (PC-9 dropped): the art capture items (CM2-12, CM2-13a/13b, CM2-14, CM2-10a/b/c, CM2-10W), "Captures only" and "Desktop FPS" are removed; their tasks are ticked on the passed numeric checks (Edit-mode steps, full run 62/62, `ART_ASSETS`, `MAP_WORLD` 302 of 302 art, reserve numbers).

(empty since 2026-11-26: N3b CM2-46c passed, then CM2-SALE2, CM2-G12b, CM2-12W and CM2-PP ran their Studio steps directly, see PROGRESS)

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
- [x] CM2-40 (#41) → launch order 6 (done); line 5h CM2-UV2 passed 2026-11-25 (device part of CM2-UV (f)). The issue can be closed (the owner closes issues).
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
- [x] **CM2-G10 Multi-save and co-op size tiers**, done with launch order 3–5 (CM2-S1, CM2-S2, CM2-S3); the region tag is dropped (PRODUCT_SPEC 2026-11-21).
- [ ] **CM2-G11 Daily reward streak and quest board** → launch order 18.
- [x] **CM2-G12 Day counter, day/night cycle, leaderboards**, done with launch order 17 (CM2-G12a, CM2-G12b) 2026-11-26.
- [ ] **CM2-G13 Layout mode checklist** → launch order 27.
- [x] **CM2-G16 Staff break area**, done with launch order 12 (CM2-25/26; owner: gentle fatigue, movable break area, no wages).
- [ ] **CM2-G17 Season pass design** → launch order 36.
- [ ] **CM2-G18 HQ radio** → launch order 21.
- [x] **CM2-G19 HQ upgrade footprints vs lot layout**, done with launch order 16 (CM2-G9a playtest step 59 `HQ_FOOTPRINTS` PASS, every HQ tier and expansion level); CM2-13W re-checks step 59 with the new HQ art.

## Follow-up tasks (created 2026-11-24 from the hasseln run, N2)
- [x] **CM2-ASSETWARN Trace the `rbxassetid://203785492` asset-type warning**, closed 2026-11-26 as engine noise (0 hits in Edit, Play server and Play client; 2 lines in Edit, 4 at Play start; no route blocker spawn → `Bay_1`; baseplate step BLOCKED by the MCP). DECISION_LOG 2026-11-26 "CM2-ASSETWARN closed as engine noise" (with the reopen rule), `docs/P0_AUDIT.md` note, PROGRESS archive 2026-11-26.

## Follow-up tasks (created 2026-11-25 from CM2-SALE1)
From the CM2-SALE1 regression (60/62, plan Amendment 1) and the plan's "Out of scope". All done.
- [x] **CM2-PT53 Playtest step 53 SHOP_GUARD expects the owner's product IDs**, done 2026-11-25 (commit 7c604d0; step 53 PASS in three full runs on BUILD cm2-pt35b2), see PROGRESS
- [x] **CM2-PT35 Playtest step 35 FINDER: the shadow's search does not create a save**, closed 2026-11-25 (investigation: harness state, not a server bug; readings in git history), fix CM2-PT35b
- [x] **CM2-PT35b Step 35 starts the shadow from a clean slate**, done 2026-11-25 (plan `docs/plans/CM2-PT35b.md` fix round 1; commits 39623e3, df36755; three full runs 62/62), see PROGRESS
- [x] **CM2-SALE2 Early-lot demand**, done 2026-11-26 (plan `docs/plans/CM2-SALE2.md` with Amendment 1; commits ec5ead2, cd45fac, d30c968; headless rates inside the target ranges, Studio 2 sales in 180 s on a fresh 6-tree lot, full run 64/64; values in DECISION_LOG), see PROGRESS

## Recurring task: CM2-SLIM repo hygiene (owner decision 2026-11-24)
One `cm2-task` per run, ID `CM2-SLIM` plus its date. **Tier S**: no planner; `implementer` (Sonnet medium) works from the plan below; `reviewer` puts `(CM2-SLIM)` in every commit subject (the due check finds the last run by it). Old wording of this section: archive (CM2-SLIM4).

**Due** (hasseln step 2 checks it before picking a task; by hand: `cm2-task CM2-SLIM`) when any holds: no commit subject has `CM2-SLIM` yet; 8 or more `feat`/`fix` commits since the last one (`git log --oneline <last SLIM sha>..HEAD | grep -cE "^[0-9a-f]+ (feat|fix)"`); `docs/CLAUDE_BACKLOG.md` or `docs/DECISION_LOG.md` over 80 KB, or `CLAUDE.md` over 16 KB; the next task is CM2-47 (QA) or CM2-48 (release candidate).

**Plan:** Goal, Method, Find, Fix, File-do-not-fix and Accept stand unchanged in the standing plan `docs/plans/CM2-SLIM.md` (tier S; moved by CM2-SLIM4b); each run passes that path to `implementer`.

Runs: 2026-11-25 (first run; its PROGRESS entry holds the table). Follow-ups: CM2-SLIM1..5 and SLIM4b below (all done) and the splits CM2-SPLIT-a/b/c (launch lines 25a–25c).

## Follow-up tasks (created 2026-11-25 from CM2-SLIM)
All done. None changes behaviour. Standard checks for every task that touches `src` or `tests`; Studio not needed (comments, unused strings and docs only).
- [x] **CM2-SLIM1 Plan-path citations to the archive**, done 2026-11-25, see archive
- [x] **CM2-SLIM2 Dead Localization keys**, done 2026-11-25, see archive
- [x] **CM2-SLIM3 Decision-log archive by the new window**, done 2026-11-25, see archive
- [x] **CM2-SLIM4 Backlog under 60 KB**, done 2026-11-25 with CM2-SLIM4b, see archive
- [x] **CM2-SLIM4b Backlog to 61440 B, the three SLIM4 follow-ups**, done 2026-11-25 (61,347 B; standing plan `docs/plans/CM2-SLIM.md`), see archive
- [x] **CM2-SLIM5 CLAUDE.md to 12 KB, wording only**, done 2026-11-25 (15,707 B to 12,241 B; plan `docs/plans/CM2-SLIM5.md`), see PROGRESS

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

**Next hasseln starts here** (planner 2026-11-26, end-of-run refresh; done that run: CM2-ASSETWARN (closed as engine noise), CM2-SALE2, 17b CM2-G12b, N3b/13c CM2-46c, CM2-12W, 17a CM2-PP; the owner ended the run). The order assumes the owner resolved every open PC entry; hasseln step 1 checks each `Prüfen` field, and a task whose PC entry is still open is skipped silently for that run. If Rojo drops again, the planner reopens PC-11 and Studio criteria go to "Studio-Test ausstehend" (code work goes on).
1. **PC follow-ups** whose entry checks out, first: **CM2-49T** (PC-12) → **CM2-ARTREF** (PC-1, MODEL section).
2. **CM2-SLIM** (due: 8 `feat`/`fix` commits since 17da09b incl. CM2-13W; hasseln step 2 checks it; standing plan `docs/plans/CM2-SLIM.md`). CM2-13W done 2026-11-26.
3. **N6** from line 18 on.
- **Repo hygiene:** `.claude/settings.local.json` exists, is not git-ignored and must never be committed; stage files by name, never `git add -A` or `git add .`.

CM2-49T. **Record the owner's phone time for line 14** (Danach of PC-12) · S (docs only, no plan, no Studio run) · Depends: PC-12. Goal: the reviewer writes a PROGRESS.md entry "line 14 phone time (owner hand-test)" with the owner's time, device and remarks from the chat, and a status line under line 14. Accept: time ≤ 3:00 → line 14 ticked and Gate A closed in the status header; time > 3:00 → line 14 stays open and the `planner` adds an M fix task right after line 14 (shorten the slowest step the owner names; delivery ETA and customer arrival values from `GameConfig` in the plan), placed first in "Next hasseln starts here".
N6. **Launch order with art wiring.** After each launch-order task one art task whose Depends are met runs (MODEL rule 4: one art task, one feature task): CM2-13W (item 2) → 18 **CM2-G11** (L, `planner-high`; the group bonus stays hidden while the group ID is empty) → **CM2-14W** → 19 **CM2-A1** → **CM2-44** → then the launch order without art tasks:
   - Gate B: 20 **CM2-45** → 21 **CM2-G18** → 22 **CM2-43** → 22a **CM2-UI** → 22b **CM2-UI-TPL** → 23 **CM2-47** → 24 **CM2-48** → 25 **CM2-50a** → 25a **CM2-SPLIT-a** → 25b **CM2-SPLIT-b** → 25c **CM2-SPLIT-c**.
   - Gate C: 26 **CM2-35** → 27 **CM2-32/33** → 27a **CM2-G9c** → 27b **CM2-G9d** → 28 **CM2-45b** → 29 **CM2-28** → 30 **CM2-45c** → 31 **CM2-50**; then "After launch" 32–37.
   - CM2-SLIM before CM2-47 and CM2-48 (due rule) and whenever its due rule fires.
N7. **Owner actions outside a task**: the friends test (line 15, `docs/FRIENDS_TEST.md`), unblocked since N3b passed; the Roblox group ID for line 18 (optional, the bonus stays hidden without it); liked/disliked UI screenshots for line 22a (optional).

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
5h. [x] **CM2-UV2 UI size check on phone, tablet and 1080p PC**, done 2026-11-25 (every item PASS on its devices; findings 5j–5n done), see PROGRESS archive.
   - Probe scope (planner decision 2026-11-25, standing): H4 runs skip the Roblox `TouchGui` and judge the rail overlap rule on its shown buttons, not the transparent `Rail` ScrollingFrame box; a real button overlap stays a violation.
5i. [x] **CM2-UVF7 Far world labels do not overlap either**, done 2026-11-22, see archive
5j. [x] **CM2-UVF10 Phone: stocking bar and tutorial hint bar overlap, reason text cut off**, done 2026-11-25, see archive
5j1. [x] **CM2-SP1 Saves picker shows "no saves yet" and "Please wait" on a fresh Play**, done 2026-11-25, see archive
5k. [x] **CM2-UVF11 Phone: Supplier "Place order" button below the Lot Manager panel**, done 2026-11-25 (8e4ecbc), see archive
5l. [x] **CM2-UVF12 Phone: Pricing card controls need an extra scroll**, done 2026-11-25 (2f63ae4), see archive
5m. [x] **CM2-UVF13 Phone: FinderButton near the thumbstick**, done 2026-11-25 (rail buttons right of row 1 on phones; gap 27 px to the ring), see archive
5n. [x] **CM2-UVF14 Finder: own listing shows in place after "Look for teammates"**, done 2026-11-25 (Studio iPhone 7 and HD 1080 PASS), see PROGRESS archive
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
13c. [x] **CM2-46c Owner product IDs and test purchases**, done 2026-11-26 (IDs 3c5ac49; N3b: 7a, 7c, 7d and idempotency PASS, 7b not tested by owner decision, DECISION_LOG 2026-11-26), see PROGRESS
13d. [x] **CM2-UVF8 Shop category bar fits, boost line always visible, "$" in cash packs**, done 2026-11-24, see archive (its Shop captures dropped, owner decision 2026-11-25)
14. [ ] **CM2-49 Short guided tutorial** · M · Depends: CM2-N2, CM2-40. First save only: order trees → stock them → check out the first customer, with arrows and one-line hints, skippable, never shown again for that save. Accept: headless test that tutorial progress is server-owned and survives a rejoin; Studio: a fresh save completes the tutorial in under 3 minutes on the phone simulator.
    - Status 2026-11-26: done in code (`docs/plans/CM2-49.md`); headless Accept PASS; every functional and layout step of the phone re-run PASS (Studio af5facc4, iPhone 7 666x374). Time criterion not shown: the agent run took 341 s including tool latency, and a per-step timing rule was rejected (DECISION_LOG 2026-11-25 line 14 timing rule). Planner decision 2026-11-26: the time is judged by an owner hand-test (PC-12), recorded by CM2-49T; no agent re-run. The `MoveTo` stall at (-122.5, 3.5, -68.2) is closed: CM2-ASSETWARN's walk found no blocking part.
14a. [x] **CM2-SALE1 Customers never buy on a fresh save**, done 2026-11-25 (tier L; plan `docs/plans/CM2-SALE1.md` with Amendment 1; commits 1a9cc02, 07614c5; readings and tick decision in PROGRESS; follow-ups CM2-PT53, CM2-PT35b done, CM2-SALE2 open).
15. [x] **CM2-47a Friends-test build and checklist**, done 2026-11-23, see archive

**Gate B — Go/No-Go build (2026-11-28)**
16. [x] **CM2-G9 Progression ladder**, done 2026-11-24, see archive
17. [x] **CM2-G12 Day/night, day counter and leaderboards** (covers CM2-36 part), done 2026-11-26: CM2-G12a day/night (8571cf7) and 17b CM2-G12b leaderboards (e19857d; headless 630/630, Studio full run 64/64 with steps 62 and 63 PASS), see PROGRESS.
17a. [x] **CM2-PP Plot picker at session start** (owner, 2026-11-24), done 2026-11-26 (plan `docs/plans/CM2-PP.md` with Amendment 1; commits ebda7e7, 0769fc3; headless 656/656, Studio full run 66/66 and manual 3a-3f PASS; teleport arrival BLOCKED in Studio, covered headless; decisions in DECISION_LOG 2026-11-26 "CM2-PP engineering decisions"), see PROGRESS. Accepted limit for 22a CM2-UI: on the short phone (780x281) the confirm frame overlaps the panel title and status text. The reviewer's list of client-only defensive guards in `PlotPicker` (PROGRESS) is awareness only, no task.
18. [ ] **CM2-G11 Daily reward streak, quest board and group bonus** (covers CM2-34, CM2-36 part) · L · Depends: CM2-S1, CM2-40. 7-day streak (cash and reputation) and a board of 3 rotating quests (~4 h) plus a bonus quest for finishing all three; rewards claimed manually and idempotent; "Join group for 2× daily rewards" checked server-side with `IsInGroup`, group ID from the owner (empty → bonus hidden). Accept: tests for streak reset by server time, double-claim rejection and rotation without offline income; the 2× applies once per claim and only to group members. `Quest.Claim` exists in `Protocol` (validator) and `CompanyStateService` without a client sender (CM2-SLIM note); this task adds the sender and reuses or replaces that scaffold with its tests.
19. [ ] **CM2-A1 Advent calendar** · L · Depends: CM2-S1, CM2-40. 24 doors, Dec 1–24 (server date, UTC); one door per day, rewards rising (cash, reputation, decor, boosts), specials on Dec 6 and Dec 24 (PROVISIONAL values in config); missed doors can be opened until Dec 24; per player, credited to the active save. Accept: headless tests with a fake clock: a future door is rejected, a missed door opens, each door pays once per player even across two saves, nothing opens after Dec 24; Studio, clock on Dec 3: doors 1–3 open, 4 locked.
20. [ ] **CM2-45 Event framework and 1st Advent event** (covers CM2-45 part) · L · Depends: CM2-46, CM2-G9. Timed event shop with countdown, event currency or cash as in the reference, special trees and a decor pack, switched on by a dated event config (2026-11-29, 12-06, 12-13, 12-20); 1st Advent content with our own names. Event models are MODEL tasks; until reviewed, event items reuse existing models recoloured in our palette. Accept: headless tests that the event opens and closes on its dates, event purchases are idempotent, items persist after the event; Studio with the clock on 2026-11-29 shows the event shop.
21. [ ] **CM2-G18 Audio: HQ radio, music, effects, volume** · L (per-player volume is a new persisted profile field; `planner-high`) · Depends: CM2-40. Goal: an optional radio prompt at the HQ, audible only on the own plot; music and effects from Roblox's licensed audio library; separate music and effects volume, saved per player. Accept: every audio ID with source and licence in `docs/AUDIO.md`, none copyrighted or unlicensed; headless: the volume fields migrate with defaults, clamp to 0–1, are rate-limited, survive a rejoin; Studio: the radio plays only inside the own plot area, the two sliders work separately and keep their values after a rejoin; standard checks and `runPlaytest {mode="full"}` all PASS.
22. [ ] **CM2-43 English-only strings and accessibility** (re-scoped) · S · Depends: CM2-40. The client always uses English at launch (Roblox auto-translation covers others); DE entries stay in `Localization.lua` for the later language switch; an audit removes concatenated fragments; text scaling and contrast checked. Accept: a headless test that every key has an English full sentence and no UI string is built from fragments; Studio screenshots with a German Roblox locale show English.
   - Note (CM2-G14 review): bay labels (`BayFree`, `BayArriving`, `BayContents`) re-localize only on `AttributeChanged` while the server rewrites the English `Text` every 1 s, so a non-English client shows English on unchanged bays; fix before the language switch (re-localize on `Text` changes, or the server skips unchanged text).
22a. [ ] **CM2-UI Final UI redesign** (owner: the last task before release) · M (look only; no money, saves or remotes) · Depends: orders 1–22 that are done, CM2-UV; PC-2 or an owner upload for images. Goal: one visual pass over every screen on the Swarve pack (b) plus a style guide, behaviour unchanged. Accept:
    - (a) The owner's liked and disliked UI screenshots or a mockup in `docs/art/ui-reference/` with a README table as in `docs/art/quality-reference/`; if none exist at the start, the planner derives the target from PRODUCT_SPEC and records that.
    - (b) Look per PRODUCT_SPEC "UI look" and DECISION_LOG 2026-11-25 "owner: CM2-UI built on the Swarve pack" (which parts of the Essential UI Pack are used, colours, tinting, asset-ID upload via PC-2; licence `assets/third_party/swarve-essential-ui/LICENSE.md`, contents and IDs in `INVENTORY.md` there; the `.rbxl` stays gitignored). Pack layout patterns: left HUD button rail, currency bar, title-bar windows with a close button, scrolling shop cards, upgrade cards with before/after stats, the fading notification. The plan maps every pack screen to ours (e.g. Shop → Robux shop, Upgrades → upgrade tabs, Notifications → toasts, HUD rail → our HUD buttons) and every screen in (c) to a pack pattern; pack icons meaningless here (strength, gems, wheel, rebirth) become Christmas-market icons in the pack's style. Commit only rebuilt values and asset IDs, never raw pack files.
    - (c) Style guide in `UiTheme` (colours, fonts and weights, text sizes, corner, stroke, shadow, tap sizes, tween times, image IDs), read by every screen. `UiKit` interaction on every button, tab and tappable row with the pack's values: hover 110 % in 0.2 s, press 90 % in 0.1 s (Quad Out, through a `UIScale`, layout does not move), hover sound at volume 0.5, click sound at 0.7; touch gets only the press effect; the selected tab clearly marked; a dim layer under stacked dialogs (CM2-UV). Screens: HUD, Lot Manager and all tabs, save picker, Team panel, teammate finder, stocking bar, Robux shop, tutorial hints, daily rewards and quests, Advent calendar, event shop, settings, world labels.
    - (d) No behaviour change: same headless and `runPlaytest {mode="full"}` counts, all PASS; no change to remotes, error codes, string keys or save fields.
    - (e) Device Simulator shots of every screen on phone, tablet and 1080p PC in PROGRESS.md: nothing clipped or overlapping, touch targets 44–52 px, titles, buttons and numbers in the heavy font, inside the safe area; on phone the world stays visible around every window; at most three review rounds against the reference.
    - (f) Compact on phone (owner 2026-11-25, PRODUCT_SPEC "UI look"): before any change, record today's phone boxes from the `UiTheme` layout functions as a baseline in `UiTheme_Test`; then for every phone size in that test: each window ≤ 70 % of the safe-area width and ≤ 80 % of its height, the HUD boxes (rail, money bar, stocking bar, hint bar) together ≤ 20 % of the screen area, buttons 44–52 px high, body text 14–16 px, titles ≤ 24 px, and no window or HUD box larger than its baseline. The pack's frame sizes are not taken over; hover growth through `UIScale` does not count.
    - (g) Known layout debt: on the short phone (780x281) the CM2-PP plot picker's confirm frame overlaps the panel title and status text (accepted in 17a); fixed here, checked with the (e) shots.
22b. [ ] **CM2-UI-TPL Swarve UI kit as an optional add-on in the template repo** (owner 2026-11-25) · S · Depends: CM2-UI. Goal: CM2-UI's Swarve-based look is reusable in `Valentindghjg/roblox-game-template`, not forced on new games; work in the sibling checkout `../roblox-game-template` (commit and push there); this repo gets only the PROGRESS entry. Accept: (a) the pack-based `UiTheme` values (fonts, strokes, gradients, image and sound IDs, tweens), the generic `UiKit` builders and the button interaction form one self-contained add-on there, without Christmas Tree Village names, strings, screens or logic; (b) off by default (a fresh template build has none of it); README "Optional: Swarve UI pack" explains in <= 10 steps how to switch it on and use one builder; (c) the template checks pass with it off and on (StyLua, Selene, luau-lsp, unit tests, both Rojo builds), one unit test covers its builders; (d) no raw pack file committed (`.gitignore`); `LICENSE.md` and `INVENTORY.md` in the template's `assets/third_party/swarve-essential-ui/`.
23. [ ] **CM2-47 End-to-end, multiplayer and security QA** · M · Depends: orders 1–22 that are done. Exploit pass on every remote and prompt (forged payloads, floods, other-plot and other-save actions, purchase replay), the full Studio script, a 6-plot load soak. Accept: each remote and prompt in PROGRESS.md with its forged-payload, flood and cross-plot/cross-save result; each defect fixed or filed as a blocking ticket right after this line; `runPlaytest {mode="full"}` all PASS; the soak (>= 10 min) leaves no NPC, car or tree behind, server heartbeat >= 55 FPS; in it a plot of 4–6 at HQ 2, captured from the road, has the roof sloping and the counter facing the road as on plots 1–3 (CM2-G9a).
24. [ ] **CM2-48 Release candidate and owner checklist** (re-scoped: the owner publishes) · S · Depends: CM2-47. `docs/RELEASE_CHECKLIST.md` for the owner: place settings (12 players, API access, DataStore names), product and gamepass creation with names and prices, group ID, experience questionnaire and content maturity, thumbnails and description, private build to public switch. Accept: the checklist complete, every engineering item ticked with evidence; engineering publishes nothing.
25. [ ] **CM2-50a Go/No-Go regression** (part of CM2-50) · S · Depends: CM2-48. Studio script and all checks on the release-candidate commit; a one-page Go/No-Go summary for the owner (2026-11-28) (what works, known issues, what is out). Accept: summary in PROGRESS.md with the commit SHA.
25a–25c. **Luau files over 800 lines** (from CM2-SLIM; after CM2-50a so the release-candidate commit stays unchanged until the owner's Go/No-Go). Pure refactors: no behaviour, remote, error-code, string-key or save-field change. Common Accept: every touched file <= 800 lines (`wc -l`); moved code in new modules placed by TECHNICAL_ARCHITECTURE section 1 and named in the plan; standard checks with the same headless count; `runPlaytest {mode="full"}` same step count, all PASS.
- 25a. [ ] **CM2-SPLIT-a Split Localization and WorldService** · M · Depends: CM2-50a. `src/shared/Localization.lua` (925; e.g. EN and DE tables into child modules, the API unchanged) and `src/server/Services/WorldService.lua` (1499; map building vs. runtime world state).
- 25b. [ ] **CM2-SPLIT-b Split main.server and CustomerNpcService** · M · Depends: CM2-SPLIT-a. `src/server/main.server.lua` (1104; service wiring vs. the Studio test hooks) and `src/server/Services/CustomerNpcService.lua` (1009; spawning/pathing vs. checkout queue). Plus Studio: one customer visit with checkout and one tree delivery PASS.
- 25c. [ ] **CM2-SPLIT-c Split CompanyStateService, BusinessState and their tests** · L (`planner-high`; save, money and inventory paths) · Depends: CM2-SPLIT-b. `src/server/Services/CompanyStateService.lua` (1481), `src/shared/BusinessState.lua` (960), `tests/studio/Cases/CompanyStateService_Test.lua` (1171) and `tests/studio/Cases/CoopSave_Test.lua` (862). Extra Accept: save schema version and every persisted field byte-equal before and after (headless round-trip of a fixture save); the double-spend, duplicate-order and idempotency tests unchanged and passing; Studio: purchase → delivery → sale → save/rejoin PASS.

**Gate C — by the 2nd Advent (2026-12-06)**
26. [ ] **CM2-35 Analytics and appeal** (covers CM2-35, CM2-G8, CM2-27 appeal part) · M · Depends: CM2-N2. Analytics tab as in the reference (cards, sales chart, best sellers, more stats, decor block); in the demand model lot appeal (trees on display, species × size variety, cap from lot size) raises price tolerance (+2 % observed) and decor appeal adds sightseers and tips. Accept: both metrics in Analytics; unit tests for appeal growth over time and its effect on the accepted price; the tab shows server values exactly and history stays bounded.
27. [ ] **CM2-32/33 Decor catalog, layout mode and stock zones** (covers CM2-32, CM2-33, CM2-G13, CM2-42) · L · Depends: CM2-G9, CM2-35. Catalog bought with cash, items placed from a crate, move/rotate/put away/clear all, a decorate inventory with search; stock zones with species and height filters and priority; a free movable HQ (checkout and staff move with it) blocked by other structures. Launch decor: small Part-built items (PRODUCT_SPEC Art) until MODEL tasks deliver more. Accept: each item shown in Studio and covered by server validation tests (overlaps, plot bounds); placements persist.
27a. [ ] **CM2-G9c Lot Manager at the HQ computer** · L · Depends: CM2-G9a, CM2-G9b. G9a only unlocks the hire ("Standby"). Goal: a hired Lot Manager appears as a visible original avatar, walks to an HQ computer and orders trees through the player's server supplier-order path (server quotes and costs, company cash, storage and bay limits, never a client cost). Accept: headless: its orders debit cash once per order (idempotent ids), stop when cash, storage or bays are short, never exceed the player's order limits; the Employees status leaves "Standby"; Studio: the avatar walks to the computer and a delivery it ordered arrives; `runPlaytest {mode="full"}` all PASS.
27b. [ ] **CM2-G9d HQ unlock content** · L + MODEL · Depends: CM2-G9a, CM2-G9b; before line 29 (the balance pass needs it). Goal: the inactive HQ unlocks become real: new species per HQ tier (`newSpecies`, own names, wholesale by the 5x rule, supplier rows by HQ level, original tree models) and the 2nd/3rd checkout station (`checkoutStations`) with its own queue and Cashier. Accept: headless: supplier rows only at the required HQ level, server prices by the 5x rule, each station serves its own queue, sales idempotent; the unlock entries `active = true`; models pass the modeler self-review; Studio: HQ 2 shows the new species at the supplier and a second station serves customers; `runPlaytest {mode="full"}` all PASS.
28. [ ] **CM2-45b 2nd Advent event content** (part of CM2-45) · M · Depends: CM2-45. Content for 2026-12-06 in the event config. Accept: Studio, clock on 2026-12-06, shows the new shop; the 1st event's items stay.
29. [ ] **CM2-28 Balance pass and anti-exploit economy tests** · M · Depends: CM2-G9, CM2-35. Replace PROVISIONAL values observed meanwhile; a simulated 2-hour economy run per tier stays inside target cash/reputation curves. Accept: simulation test in the headless runner; every changed value carries its evidence tag.
   - Note 2026-11-22 (planner, CM2-N2, CM2-G15): high abandoned-visit rate (R 25/38, S 40/70 abandoned, 0 walk-outs, i.e. non-conversions); review demand and conversion values in this pass. Walk-outs and abandoned visits leave no review (CM2-G15).
30. [ ] **CM2-45c 3rd and 4th Advent event content** · M · Depends: CM2-45b. For 2026-12-13 and 12-20. Accept: as order 28 for each date.
31. [ ] **CM2-50 Final integration and regression** · S · Depends: everything done before. Accept: full Studio script PASS on the release commit, recorded in PROGRESS.md.

**MODEL tasks** (references in `docs/art/quality-reference/`; Blender with the skill `cm2-modeling`, DECISION_LOG 2026-11-22). All art below except CM2-44 is modelled, imported (N5) and ticked. World captures and FPS in the Accepts below (CM2-12W, 13W, 14W, 44) gate no tick; the numeric checks decide (owner 2026-11-25, PC-9 dropped). Wiring tasks and CM2-44 alternate with the launch order (N6). A wiring task changes no server rule, save field or remote; it uses `ArtLibrary` art when present, else today's primitive (headless test with a fake `ArtLibrary`); in Studio a checkout without `.rbxm` still shows the primitives and `runPlaytest {mode="full"}` all PASS.
- [x] **CM2-R2 → CM2-AP Asset pipeline for Blender MeshParts**, done 2026-11-22, see archive
- [x] **CM2-ART1 Art render writes inside the repo**, done 2026-11-22, see archive
- [ ] **CM2-ARTREF Look check of the modelled art against the reference screenshots** · MODEL (review only) · Depends: PC-1. Goal: the `modeler` compares the previews of all 41 assets (`assets/art/previews/`) with the screenshots in `docs/references/roblox-game/` (silhouette, proportions, palette, detail; checklist `docs/art/quality-reference/`), changing no `.blend`, mesh, preview or config. Accept: a PROGRESS.md table, one row per asset (art path, screenshot, "match" or "deviation: <what>"); each player-visible deviation becomes a rework task (MODEL) here with a re-upload (PC-1 decision); nothing committed under `docs/references/`; standard checks unchanged.
- [x] **CM2-12 Trees**, done 2026-11-25 (owner decision, PC-9 dropped), see archive
- [x] **CM2-12W Tree art in the world**, done 2026-11-26 (plan `docs/plans/CM2-12W.md`; 73ae9b0; numeric checks incl. step 64, captures gate no tick; rules in DECISION_LOG 2026-11-26), see PROGRESS
- [x] **CM2-13 HQ tiers, fence, bays, checkout** (with CM2-13a, CM2-13b), done 2026-11-25 (owner decision, PC-9 dropped), see archive
- [x] **CM2-13W Lot and HQ art in the world**, done 2026-11-26 (plan `docs/plans/CM2-13W.md`; numeric checks incl. steps 59 and 66, full run 67/67; captures gate no tick; rules in DECISION_LOG 2026-11-26), see PROGRESS
- [x] **CM2-14 Supplier truck and customer cars**, done 2026-11-25 (owner decision, PC-9 dropped), see archive. Next: CM2-14W.
- [ ] **CM2-14W Vehicle art in the world** · M · Depends: CM2-14, the CM2-13b `TreeBundle` `.rbxm`. Goal: `WorldService` builds truck and customer cars from `ArtLibrary`; origin on the ground (lot top 0.55, lane top 0); truck cab faces the road (yaw 180° on plots 1–3, 0° on 4–6); cars nose into the lot (0° on 1–3, 180° on 4–6); car body = order number mod 3, `Paint` from `CAR_COLORS`; roof tree at the car's `CargoAnchor`; up to min(arriving, 9) `Props/TreeBundle` on the truck bed (`CargoAnchor`) while it pulls in, empty on leaving; label, `LoadOrder` prompt and reach check on `ArtRoot`. Also fixes the primitive car ~0.55 below the lot surface and the primitive cab always facing +Z. Accept: headless incl. yaw per plot side; Studio: all 6 plots show truck and car art on the ground.
- [x] **CM2-10 Mountain-village map** (with CM2-10a, CM2-10b, CM2-10c), done 2026-11-25 (owner decision, PC-9 dropped), see archive
- [x] **CM2-10W Map in the world**, done 2026-11-25 (owner decision, PC-9 dropped), see archive
- [x] **CM2-ART2 ArtLibrary.root ignores asset-less folders**, done 2026-11-24, see archive
- [ ] **CM2-44 Art pass and removal of all Codex/CC0 models** · MODEL · Depends: CM2-12W (done), CM2-13W, CM2-14W (per N6). Accept: no model from `assets/third_party/` remains in the place.
  - Note 2026-11-23 (CM2-10W split): CM2-10W removed only the world placements of the CC0 scenery, the market alley (incl. `MarketGazebo`) and the primitive showcase and forest trees. Left for CM2-44: the other CC0 uses (stand `MarketStarter`/`MarketPavilion`, `FenceWooden` until CM2-13W), deleting the CC0 templates from the place's `ArtAssets`, the `AssetCatalog` clean-up and `assets/third_party/`.

**After launch**
32. [ ] **CM2-R4 Strict Luau types for all of `src/shared`** · S · Depends: the Roblox definitions file in CI. Accept: `luau-lsp analyze` passes for all `src/shared` modules in CI.
33. [ ] **Gamepad support** (PRODUCT_SPEC: after launch) · M.
34. [ ] **In-game language switch (DE, ES, …)** · M.
35. [ ] **Cross-server teammate matchmaking** · L.
36. [ ] **CM2-G17 Season pass** (design first; not in the launch shop list) · S · Depends: owner approval for any paid feature. A free and a premium track fed by sales and quests. Accept: design doc only; the premium track and Robux products stay disabled (PRODUCT_SPEC) until the owner explicitly approves.
37. [ ] **Paid random rolls (version 2)** with disclosed odds and `PolicyService` restrictions · L · needs an owner decision at the time.

### Owner inputs that unblock tasks
Open: PC-1, PC-12, the Roblox group ID (line 18, optional), friends-test players (line 15) and liked/disliked UI screenshots or a mockup in `docs/art/ui-reference/` (22a). Resolved: PC-2, PC-3/PC-7, PC-4 (by tool), PC-5, PC-6, PC-8, PC-9 (dropped), PC-10, PC-11, the model reference images.

## Milestone gates
- P0: tools, unit tests, safe persistence and network foundation.
- P1: order -> delivery -> display -> NPC checkout -> rejoin playable in Studio.
- P2: realistic demand, customer behavior and staff automation.
- P3: upgrade/decor/quests/analytics implemented and persisted.
- P4: shared company, UI, input and localization verified.
- P5: original art polish, seasonal event, security and QA; no release without approval.

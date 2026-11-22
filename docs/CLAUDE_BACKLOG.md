# Claude Code — 50-task development backlog
Updated: 2026-11-19
Status: 50 GitHub issues created; **not yet implemented or verified**.

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
- Blockiert: keine (der Modeler nutzt bis dahin die Beschreibungen in `docs/REFERENCE_GAME_LIVE_TEST.md`)
- Danach: der nächste offene MODEL-Task
- WIP-Branch: none
- Seit: 2026-11-22, Owner-Gespräch

### PC-2 Open-Cloud-API-Key für die Art-Pipeline
- Status: offen
- Art: zugriff
- Problem: Um Blender-Meshes als MeshParts ins Spiel zu bringen, lädt die Art-Pipeline (CM2-AP) die FBX-Dateien über Open Cloud hoch, und dafür braucht sie einen API-Key unter dem Creator, dem das Spiel gehören wird.
- Deine Schritte:
  1. create.roblox.com → Dashboard öffnen und den Creator wählen, dem das Spiel gehören wird (dein Konto oder die Gruppe, falls das Spiel der Gruppe gehören soll).
  2. Open Cloud → API Keys → Create API Key, Name „CM2 art pipeline“:
     - die API „Assets“ mit `asset:read` und `asset:write` hinzufügen, dazu die API „Legacy Assets“ (Asset Delivery) mit `legacy-asset:manage`;
     - Accepted IP Addresses: deine IP oder `0.0.0.0/0`;
     - Expiration: 2027-02-01.
  3. In PowerShell: `setx ROBLOX_OPEN_CLOUD_API_KEY "<key>"` und `setx CM2_ART_CREATOR "user:<deine User-ID>"` (oder `"group:<Gruppen-ID>"`). Danach Claude Code neu starten. Den Key nie in den Chat oder ins Repo kopieren.
  4. Alternative ohne Key: jedes Modell eines MODEL-Tasks per Studio-Import einbinden, wie in `assets/art/README.md` beschrieben.
- Prüfen: `lune run tools/art/art.luau doctor` endet mit Exit-Code 0.
- Blockiert: das Einbinden der Meshes in den Place für CM2-12, CM2-13, CM2-14, CM2-10 (Modellieren und Blender-Renders laufen weiter)
- Danach: der erste Art-Probe-Lauf (`lune run tools/art/art.luau probe`) zum Prüfen der Endpunkte, dann der nächste offene MODEL-Task
- WIP-Branch: none
- Seit: 2026-11-22, hasseln

### PC-3 Studio-Fenster sichtbar lassen (Viewport 1x1, keine Screenshots)
- Status: offen
- Art: studio
- Problem: In jedem Studio-Playtest dieser Sitzung (CM2-G20, CM2-S1, CM2-S2, CM2-S3) war der Client-Viewport 1x1 (`workspace.CurrentCamera.ViewportSize` = 1,1), und die MCP-Aufrufe `screen_capture` und `user_mouse_input` liefen in „Request timeout“ oder zeigten nur die 2D-UI auf Schwarz; echte UI-Taps, Screenshots und Device-Simulator-Prüfungen sind deshalb BLOCKED. Wahrscheinliche Ursache: das Studio-Fenster ist minimiert, verdeckt, zu klein oder der Desktop ist gesperrt bzw. inaktiv.
- Deine Schritte:
  1. Roblox Studio mit dem Projekt-Place offen lassen und das Fenster auf dem Hauptmonitor maximieren (nicht minimieren, nicht hinter andere Fenster legen).
  2. Den PC entsperrt lassen und Ruhezustand, Bildschirmsperre und Bildschirmschoner abschalten, solange `hasseln` läuft (Windows-Einstellungen → System → Bildschirm und Energie → „Nie“).
  3. Optional: im Chat kurz sagen, dass das Studio-Fenster sichtbar ist.
- Prüfen: in Play liefert `workspace.CurrentCamera.ViewportSize` mehr als 100x100, und ein MCP-`screen_capture` gibt ein Bild mit der 3D-Welt zurück (nicht nur 2D-UI auf Schwarz).
- Blockiert: die Screenshot-, Tap- und Device-Simulator-Kriterien von CM2-40 (die Code-Arbeit von CM2-40 läuft weiter), die offenen UI-Punkte von CM2-S1, CM2-S2 und CM2-S3, die Screenshot-Punkte von CM2-G21
- Danach: CM2-UV (Launch order 5b), danach die Screenshot-Kriterien von CM2-40
- WIP-Branch: none
- Seit: 2026-11-22, hasseln

#### Erledigt
_Noch keine._

## How to work
- Read CLAUDE.md and the canonical docs before starting.
- Work in dependency order, but parallelize independent tasks where safe.
- Each issue must end with implementation, tests, progress log, commit SHA, and reviewer evidence.
- Do not close issues solely on code generation; verify acceptance criteria.
- The identifiers CM2-01..CM2-50 are **planning IDs**, not GitHub issue numbers. GitHub numbering may differ.
- Publication and paid actions require explicit owner approval.

## P0 — Fundament
- [x] [CM2-01](https://github.com/Valentindghjg/Christmas-market2/issues/1)
- [x] [CM2-02](https://github.com/Valentindghjg/Christmas-market2/issues/2)
- [x] [CM2-03](https://github.com/Valentindghjg/Christmas-market2/issues/3)
- [x] [CM2-04](https://github.com/Valentindghjg/Christmas-market2/issues/4)
- [x] [CM2-05](https://github.com/Valentindghjg/Christmas-market2/issues/5)
- [x] [CM2-06](https://github.com/Valentindghjg/Christmas-market2/issues/6)
- [x] [CM2-07](https://github.com/Valentindghjg/Christmas-market2/issues/7)
- [x] [CM2-08](https://github.com/Valentindghjg/Christmas-market2/issues/8)
- [x] [CM2-09](https://github.com/Valentindghjg/Christmas-market2/issues/9)

## P1 — Spielbarer Kern
- [ ] [CM2-10](https://github.com/Valentindghjg/Christmas-market2/issues/10)
- [ ] [CM2-11](https://github.com/Valentindghjg/Christmas-market2/issues/11)
  - Status 2026-11-22: re-scoped into CM2-S1, done 2026-11-22 (profile per player, company record per save ID, plot per active save, legacy personal record migrated). Close the issue with launch order line 3.
- [ ] [CM2-12](https://github.com/Valentindghjg/Christmas-market2/issues/12)
- [ ] [CM2-13](https://github.com/Valentindghjg/Christmas-market2/issues/13)
- [ ] [CM2-14](https://github.com/Valentindghjg/Christmas-market2/issues/14)
- [ ] [CM2-15](https://github.com/Valentindghjg/Christmas-market2/issues/15)
- [ ] [CM2-16](https://github.com/Valentindghjg/Christmas-market2/issues/16)
- [ ] [CM2-17](https://github.com/Valentindghjg/Christmas-market2/issues/17)
- [ ] [CM2-18](https://github.com/Valentindghjg/Christmas-market2/issues/18)
- [ ] [CM2-19](https://github.com/Valentindghjg/Christmas-market2/issues/19)

## P2 — Wirtschaft & Automatisierung
- [ ] [CM2-20](https://github.com/Valentindghjg/Christmas-market2/issues/21)
- [ ] [CM2-21](https://github.com/Valentindghjg/Christmas-market2/issues/22)
  - Status 2026-11-22: covered by CM2-G7 (one medium price per species with Small/Large at 80 %/130 %, optional auto rule; `Pricing.SetMediumPrice` and `Pricing.SetAuto` member-authorized, rate-limited, bounds 50–250 % of the typical price, saved and reload-tested). Left open on GitHub until the owner closes the issue.
- [ ] [CM2-22](https://github.com/Valentindghjg/Christmas-market2/issues/23)
- [ ] [CM2-23](https://github.com/Valentindghjg/Christmas-market2/issues/24)
- [ ] [CM2-24](https://github.com/Valentindghjg/Christmas-market2/issues/25)
- [ ] [CM2-25](https://github.com/Valentindghjg/Christmas-market2/issues/26)
- [ ] [CM2-26](https://github.com/Valentindghjg/Christmas-market2/issues/27)
- [ ] [CM2-27](https://github.com/Valentindghjg/Christmas-market2/issues/28)
- [ ] [CM2-28](https://github.com/Valentindghjg/Christmas-market2/issues/29)

## P3 — Ausbau & Inhalte
- [ ] [CM2-29](https://github.com/Valentindghjg/Christmas-market2/issues/30)
- [ ] [CM2-30](https://github.com/Valentindghjg/Christmas-market2/issues/31)
- [ ] [CM2-31](https://github.com/Valentindghjg/Christmas-market2/issues/32)
- [ ] [CM2-32](https://github.com/Valentindghjg/Christmas-market2/issues/33)
- [ ] [CM2-33](https://github.com/Valentindghjg/Christmas-market2/issues/34)
- [ ] [CM2-34](https://github.com/Valentindghjg/Christmas-market2/issues/35)
- [ ] [CM2-35](https://github.com/Valentindghjg/Christmas-market2/issues/36)
- [ ] [CM2-36](https://github.com/Valentindghjg/Christmas-market2/issues/37)

## P4 — Multiplayer & Oberfläche
- [ ] [CM2-37](https://github.com/Valentindghjg/Christmas-market2/issues/38)
  - Status 2026-11-22: join and leave done through CM2-S2 (join by invite code, LeaveTeam, owner removes members; headless and Studio with a simulated second member). Open: the cross-server "Join" (CM2-S3) and a real 2-client run (friends-test checklist, order 15).
- [ ] [CM2-38](https://github.com/Valentindghjg/Christmas-market2/issues/39)
  - Status 2026-11-22: re-scoped roles done through CM2-S2: only Owner and Member (company schema 12); members do every gameplay action, the owner alone renames, deletes, resizes, removes members and makes a new code (`OwnerOnly`). Manager/Worker/Visitor are removed.
- [ ] [CM2-39](https://github.com/Valentindghjg/Christmas-market2/issues/40)
  - Status 2026-11-22: done in code through CM2-S3: one server per save via a MemoryStore save-to-server map that fails open, with the DataStore session lock as the only write authority (no split brain; headless crash test shows takeover only after the lock expires), "Being played by X – Join" teleport, recovery after the TTL. Open: a real cross-server run on live servers (friends-test checklist, order 15 (a)–(e)).
- [ ] [CM2-40](https://github.com/Valentindghjg/Christmas-market2/issues/41)
- [ ] [CM2-41](https://github.com/Valentindghjg/Christmas-market2/issues/42)
- [ ] [CM2-42](https://github.com/Valentindghjg/Christmas-market2/issues/43)
- [ ] [CM2-43](https://github.com/Valentindghjg/Christmas-market2/issues/44)

## P5 — QA & Release
- [ ] [CM2-44](https://github.com/Valentindghjg/Christmas-market2/issues/45)
- [ ] [CM2-45](https://github.com/Valentindghjg/Christmas-market2/issues/46)
- [ ] [CM2-46](https://github.com/Valentindghjg/Christmas-market2/issues/47)
- [ ] [CM2-47](https://github.com/Valentindghjg/Christmas-market2/issues/48)
- [ ] [CM2-48](https://github.com/Valentindghjg/Christmas-market2/issues/49)
- [ ] [CM2-49](https://github.com/Valentindghjg/Christmas-market2/issues/50)
- [ ] [CM2-50](https://github.com/Valentindghjg/Christmas-market2/issues/51)

## Follow-up tasks (created 2026-11-21 from the engineering review)
- [x] **CM2-R1 Studio regression run of the hardened session layer.** Depends on: Rojo plugin reconnect + Studio API access. Accept: Studio Play Server runs `RunUnitTest` with 85/85 passing; a manual order -> deliver -> unload -> place -> NPC sale shows the sold tree disappearing; leave + rejoin restores cash/stock.
  - Done 2026-11-22 through CM2-G20 `runPlaytest` full (22/22 PASS): Studio unit runner 142/142, order → deliver → unload → place → NPC sale with DisplayedTrees == placementCount, in-session rejoin (unload + reload from the DataStore) keeps cash, stock, revision and placements; Stop/Play persistence evidenced 2026-11-21 and 2026-11-22 (CM2-G6).
- [ ] **CM2-R2 Version Studio art in the Rojo project.** Depends on: none. Accept: `ReplicatedStorage.ArtAssets` is exported to `.rbxm` files mapped in `default.project.json`, so `rojo build` contains the imported models and a fresh checkout no longer falls back to primitives.
- [x] **CM2-R3 Surface a failed-closed session to the player.** Depends on: none. Accept: when a session becomes unavailable mid-game the server sets `CompanyReady=false` with an error code and the HUD shows it; covered by a headless test.
  - Done 2026-11-22 through CM2-S1: `CompanyError` = SessionLocked / SaveFailed / InternalError once per session, HUD status line shows the localized text; headless CompanyStateService_Test (3 tests) and Studio playtest step 28 FAIL_CLOSED PASS. The HUD screenshot of the text was not captured (viewport 1x1).
- [ ] **CM2-R4 Expand strict Luau type analysis beyond GameConfig/Economy/Inventory.** Depends on: Roblox definitions file in CI. Accept: `luau-lsp analyze` passes for all `src/shared` modules in CI.

## Follow-up tasks (created 2026-11-21 from the reference-game play-test)
Source: [REFERENCE_GAME_LIVE_TEST.md](REFERENCE_GAME_LIVE_TEST.md) §11 (gaps G1–G18). All are planning IDs only; no GitHub issues were created. Use original names and art; never copy reference assets or names. Numbers taken from the reference go into config with evidence tier OBSERVED; anything else is PROVISIONAL.

**P1 — core loop corrections**
- [ ] **CM2-G1 Customer car loading.** Depends on: P1 checkout. After checkout the server spawns the sold tree as a pickup with a sequential order number and links it to the customer's parked car. The player (later: Lot Worker) carries it to the car with the same number; delivery completes the order and the car leaves. Accept: headless tests for exactly-once completion, wrong-car rejection with a localized message, one carried item per player, and no completion for another plot's order; Studio run shows the order billboard → carry → roof-loaded car leaving.
  - Status 2026-11-21: implemented (CustomerOrderService, Order.* actions, prompts with reach check, cars/pickup trees/carried tree, localized notices). Headless tests PASS.
  - Studio 2026-11-21 (Play Server+Client, MCP): billboard → carry → roof-loaded car leaving PASS; wrong car rejected with the localized notice and the tree stays carried; second pickup while carrying rejected ("hands full"); fast load +2 reputation (95 → 97), slow load +1; expired orders removed (cars, pickup trees, prompts) with the penalty. Fixed in Studio: pickup trees stood inside the sales-stand collision box. **Open:** Lot Worker auto-load, respawn drop and plot isolation with two players in Studio (see CM2-G21).
- [ ] **CM2-G2 Car-based customer arrival tied to parking.** Depends on: CM2-G1. Customers spawn as cars on a road lane, park only in free parking spaces of the target plot and walk in. Accept: concurrent customers per plot ≤ parking spaces (config, tier 1 = 2); a full lot makes cars drive past; despawn and cleanup verified with no leaked NPCs after 10 min in a Studio soak run.
  - Status 2026-11-21: parking cap and drive-past implemented and tested headlessly; cars drive in from the road and park.
  - Studio 2026-11-21: with 2 spaces taken a third converting customer drove past (+1 drive-past, no third car); HUD parking now shows the effective 2 spaces (was 0). Accelerated leak test: 6 sale/expiry cycles incl. two concurrent customers, `CustomerOrders` empty after every cycle, never more than 2 active. Fixed: the market alley stood on the parking spaces (moved). **Open:** the literal 10-minute Studio soak (CM2-G21).
- [x] **CM2-G3 Checkout prompt content.** Depends on: P1 checkout. The prompt shows species, size class, per-tree height and price; each tree gets a stable height within its size range at delivery. Accept: test that height stays inside the size range and survives save/rejoin; prompt strings localized DE/EN.
  - Status 2026-11-21: done. Stable per-tree height (TreeHeight), localized display-tree labels with species, size, height and price. Headless tests PASS.
  - Studio 2026-11-21: labels read "Frasier Fir · Medium · 7.6 ft · $82"; heights survived a Play stop/start. Fixed: the default stocking slots put trees behind/inside the sales stand. Screenshot evidence is missing because the Play viewport captured black.
- [x] **CM2-G4 Receiving bays and storage caps.** Depends on: P1 delivery. Map Delivered/Stored to 4 bays (one order or kind per bay, ≤ 9 trees per bay) plus total delivery storage (base 30, +10 per lot expansion), all in config. Accept: an order is rejected server-side when no bay or storage is free; bay contents persist; the Supplier UI shows "free / bays" exactly like the server.
  - Status 2026-11-21: server rules (NoFreeBay, BayCapacity, StorageFull) and receiving summary implemented and tested; HUD shows bays and storage from the server summary.
  - Studio 2026-11-21: the fifth order was rejected with "All receiving bays are full – stock trees out first"; the HUD line "Bays 4/4 · Storage 4/30" matched the server summary; an order of 10 trees was rejected (BayCapacity). Bay persistence is covered by the headless save/migration tests, not by a Studio rejoin with filled bays.
- [ ] **CM2-G14 Automatic unload and bay-to-display stocking.** Depends on: CM2-G4. The truck drops its load into a bay automatically after an on-bay countdown; the player stocks from a bay with size select, rotate, single place, row fill with gap control, and store-back mode. Server validates placement (inside plot, min spacing, checkout clearance). Accept: rejection reasons "outside lot / too close / keep clear" reproduced in headless tests; a row fill places N trees atomically or none; store mode returns the tree to the bay without duplication.

**P2 — economy and customers**
- [x] **CM2-G5 Supplier stock pool and helpers.** Depends on: CM2-G4. Finite per-size stock with a server refresh timer (≈ 4 min, config), HIGH/LOW demand tags, a recommended order, and sell-back at 25 % (receiving first, then lot, never reserved trees). Accept: tests for stock depletion and refresh, no sell-back of reserved trees, exact 25 % refund rounding, and idempotent sell requests.
  - Status 2026-11-21: done. Stock pool, ~4 min refresh, demand tags, advisory recommendation, sell-back (Supplier.SellBack) with idempotency; all acceptance tests PASS headlessly.
  - Studio 2026-11-21: ordering depleted the pool (9 → 6) and the timer refresh restored it (5 → 15) with new demand tags; the UI sell-back paid exactly $8 (25 % of $32); a repeated request ID was rejected (DuplicateRequest, no second payout); an empty bay was rejected (NotEnoughTrees); a tampered payload with a refund field was rejected (UnexpectedField). Reserved-tree protection was not reproduced live (headless only).
- [ ] **CM2-G6 Observed wholesale table and a Common starter species.** Depends on: none. Add wholesale per size for 4 starter species (values in REFERENCE_GAME_LIVE_TEST §4.1) with our own species names, and update the GAME_DESIGN evidence note. Accept: config validated by tests; GAME_DESIGN no longer says wholesale by size is unobserved.
- [x] **CM2-G7 Price benchmark = wholesale × 5.** Depends on: CM2-G6. Replace the $82/$96/$105 "observed medium prices" note (they were player settings) and derive the "typical" price shown in the Pricing panel from wholesale × 5 (config). Accept: Pricing UI shows wholesale, typical, margin $/%, and a sentiment label; demand-model tests use the new benchmark.
  - Status 2026-11-22: done in launch order 7 (`docs/plans/CM2-G7.md`); screenshots and taps in CM2-UV (h); Noble 184 vs 185 in CM2-G7a.
- [ ] **CM2-G8 Lot appeal and decor appeal.** Depends on: P2 demand model. Lot appeal from trees on display and species × size variety (cap from lot size) raises price tolerance (+2 % observed); decor appeal adds sightseers and tips. Accept: both metrics shown in Analytics; unit tests for appeal growth over time and its effect on accepted price.
- [ ] **CM2-G15 Customer reviews and rating.** Depends on: CM2-G1. After loading, the customer leaves 1–5 stars and a short localized review based on service time; reputation gain scales with speed; the plot shows an in-world sign with company name and average rating. Accept: tests that slow service yields lower stars and less reputation; the rating persists and the sign updates within 2 s in Studio.
- [ ] **CM2-G16 Staff break area (decision first).** Depends on: owner/planner decision. Decide whether staff have fatigue and a break area (no wages remains binding). If yes: a placeable break area that layout respects, with staff resting there. Accept: decision recorded in DECISION_LOG; if adopted, a headless test that tired staff path to the break area and resume work.

**P3 — progression and content**
- [ ] **CM2-G9 Full progression ladder in config.** Depends on: P3 land/HQ. 6 lot-expansion levels, parking tiers, 4 HQ tiers with unlock lists, an end-game manager hire, and a late-game workshop feature, all as config with OBSERVED or PROVISIONAL tags. Accept: config schema test; Land UI lists requirements with progress exactly like the server's check.
- [ ] **CM2-G11 Daily reward streak and quest board.** Depends on: P3 quests. 7-day streak (cash and reputation rewards) and a board of 3 rotating quests (~4 h) plus a bonus quest unlocked by finishing all three; rewards claimed manually and idempotent. Accept: tests for streak reset by server time, double-claim rejection, and rotation without offline income.
- [ ] **CM2-G12 Day counter, day/night cycle, leaderboards.** Depends on: none. Visible day counter and a lighting cycle (config length); leaderboards for cash earned, reputation and playtime (no "Robux spent"). Accept: the cycle runs in Studio without frame drops on the mobile emulator; leaderboard writes are cached and rate-limited (test).
- [ ] **CM2-G13 Layout mode checklist.** Depends on: P3 layout and decor. Stock zones with species and height filters and priority, a free movable HQ (checkout and staff move with it; blocked by other structures), and a decorate inventory with search, put-away and clear-all. Accept: each item demonstrated in Studio and covered by server validation tests for overlaps and plot bounds.
- [ ] **CM2-G18 HQ radio.** Depends on: none. Optional in-world radio prompt cycling through original or licensed-free tracks. Accept: plays only for the owner's plot area; no copyrighted audio.

**P4 — multiplayer and UI**
- [ ] **CM2-G10 Multi-save and co-op size tiers.** Depends on: P4 company mode. Save picker per plot with Solo/Duo/Trio/Quad saves, rename, delete with confirmation, and a region tag. Accept: tests for save isolation, delete requiring confirmation, and session locking per save.
  - Status 2026-11-22: part 1 done through CM2-S1 (save picker, create, rename, delete with typed confirmation, save isolation and per-save session locks, all tested headless and in Studio; Solo only). Open: Duo/Trio/Quad sizes and co-op (CM2-S2). The region tag is dropped (PRODUCT_SPEC 2026-11-21: no region field).
  - Status 2026-11-22: part 2 done through CM2-S2 (Solo/Duo/Trio/Quad sizes with seat limits, resizing, invite codes, shared plot and cash; 245/245 headless, runPlaytest full 33/33). All parts done except the cross-server join (CM2-S3).

**P5 — monetization (design only)**
- [ ] **CM2-G17 Season pass design.** Depends on: owner approval for any paid feature. Document a free and premium track fed by sales and quests. Accept: design doc only; premium track and Robux products stay disabled per PRODUCT_SPEC until the owner explicitly approves.
- [ ] **CM2-G19 HQ upgrade footprints vs lot layout.** Depends on: CM2-G14. The imported upgrade models are much larger than the starter stand (MarketUpgrade3 38 × 40 studs, MarketPavilion 39 × 40, starter 32 × 24), so for upgraded HQ tiers the stand overlaps parking spaces 1–2 (z ≈ 51..91 vs cars at z = 55), the pickup row and the stocking area. Accept: a Studio or headless footprint check of every HQ tier against parking spaces, pickup row, stocking slots and checkout; offsets or the stand position are corrected where they collide.
- [x] **CM2-G20 Repeatable Studio playtest.** Done 2026-11-22 (plan `docs/plans/CM2-G20.md`; full 22/22 and soak 5/5 PASS in Studio). Depends on: none. The manual MCP sequence of 2026-11-21 (order, advance clock, unload, place, force a customer, carry, wrong car, load, expiry, sell-back, soak) lives in a runnable script under `tests/studio/` that drives the Studio-only `StudioTestHook` and reports PASS/FAIL per step. Accept: one command in a Studio Play Server prints a summary; it never runs outside Studio.
- [ ] **CM2-G21 Remaining Studio verification for G1/G2.** Depends on: none. Not yet done in Studio: Lot Worker auto-load of a waiting order, a respawn dropping the carried tree back at its pickup spot, plot isolation (a second player cannot carry or load another plot's order), the literal 10-minute soak, and screenshot evidence of cars, pickup trees and labels (the Play viewport captured black through the MCP; Edit mode has no world because it is built at runtime). Accept: each item recorded PASS/FAIL in PROGRESS.md with a screenshot where possible.
  - Status 2026-11-22: the gameplay items run in CM2-G20's `runPlaytest`; the screenshot item waits for PC-3 and runs in CM2-UV (e).
  - Status 2026-11-22 (CM2-G20 run, PROGRESS.md): Lot Worker auto-load PASS, respawn drop PASS, plot isolation PASS (shadow company in one session; real 2-client run stays with S2), literal 10-minute soak PASS (600 s, 20 samples, 0 mismatches). **Open:** screenshot evidence; `screen_capture` during Play showed only the 2D UI, no 3D world.

## Launch replanning (2026-11-21)
The owner interview changed scope and priorities (PRODUCT_SPEC, top section). This section is the **binding work order** from 2026-11-21 on; it supersedes the milestone order P1..P5 above. The ticket lists above stay as the history and the GitHub mapping. Decision record: DECISION_LOG 2026-11-21 "Launch order".

### Rules for the order
- Work top to bottom. A task is **ready** when every dependency is done (reviewer COMMITTED). If the next task is blocked, take the next ready one and record the blocker on the blocked line.
- Every task runs through `cm2-task`: one plan `docs/plans/<ID>.md`, tier set by the planner (the tier column below is the planning estimate only).
- **MODEL tasks are ready since 2026-11-22**: the owner's reference images and the quality checklist are in `docs/art/quality-reference/`. The planner sets the quality tier (A or B) for every model in the plan. Feature tasks still never wait for art.
- Every task ends with the standard checks (`stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau`, `rojo build`) plus its own criteria below. A Studio criterion is PASS only if the `playtester` ran it; otherwise it is BLOCKED and the task stays open for that item.
- No publication, no creation or activation of Robux products by engineering (PRODUCT_SPEC). Product, gamepass and group IDs come from the owner through config.

### Launch gates
| Gate | Target date | Content |
|---|---|---|
| **A — Friends test ready** | 2026-11-26 | Order 1–15: full core loop with walking customers and manual checkout, staff, saves with Duo/Trio/Quad and invite code, Robux shop wired, tutorial, touch UI. |
| **B — Go/No-Go build** | 2026-11-28 (owner decides) | Order 16–25: progression ladder, day/night, leaderboards, quests and daily rewards, Advent calendar, 1st Advent event, audio, QA, release checklist. |
| **C — 2nd Advent at the latest** | 2026-12-06 | Order 26–31: analytics and appeal, decor and layout, 2nd Advent event, balance pass, final regression. Art tasks as soon as reference images exist. |
| **After launch** | — | Order 32–37. |

If Gate A slips, the friends test moves to 2026-11-27 and Gate B keeps its date with fewer extras; order 16–25 is already sorted by launch value.

### Launch order
Tier: S/M/L/MODEL estimate. "Covers" lists the old tickets a line replaces or absorbs; their GitHub issues are closed when this line is done.

**Gate A — core loop and friends test (target 2026-11-26)**
1. [x] **CM2-G6 Observed wholesale table and Douglas Fir starter species** · S · Depends: none. Unchanged from above, plus: the 4 starter species are Douglas Fir (Common), Fraser Fir (Uncommon, spelling fixed from "Frasier"), Noble Fir (Rare), Blue Spruce (Uncommon) with the wholesale prices of REFERENCE_GAME_LIVE_TEST §4.1 (OBSERVED); existing saves keep their stock (the species ID stays stable, only the display name changes). Accept: config test asserts all 12 wholesale values; GAME_DESIGN evidence note updated; the Supplier panel lists 4 species in Studio.
2. [x] **CM2-G20 Repeatable Studio playtest script** (done 2026-11-22) (covers CM2-R1, CM2-15, CM2-16, CM2-G21) · M · Depends: none. Unchanged from above, plus the R1 and G21 items as script steps: Studio unit runner all PASS, order → deliver → unload → place → sale → load car, rejoin keeps cash and stock, Lot Worker auto-load, respawn drops the carried tree back, a second test player cannot carry or load another plot's order, a 10-minute soak with no leaked cars, NPCs or trees. Accept: one command in a Studio Play Server prints PASS/FAIL per step and a total; it refuses to run outside Studio; the playtester records the first full run in PROGRESS.md.
3. [x] **CM2-S1 Save slots per player** (done 2026-11-22) (covers CM2-G10 part 1, CM2-R3, CM2-11 re-scope) · L · Depends: none. A player profile record lists any number of saves; a save picker on join (scrolling list) with create, rename, delete with typed confirmation; the company record is keyed by save ID, not user ID; the existing personal company migrates into the player's first save; the plot is claimed per active save; 12 players / 6 plots per server, and a player who needs a plot when none is free is teleported to another server. A save that fails to load or loses its lock mid-game sets `CompanyReady=false` with an error code that the HUD shows (R3). Accept: headless tests for migration of an existing personal record, save isolation (actions on save A never change save B), delete only with confirmation, session lock per save, fail-closed surfacing; Studio: create two saves, switch, rename, delete, rejoin restores the chosen save.
   - Status 2026-11-22: all headless and Studio criteria PASS (205/205; runPlaytest full 29/29, soak 6/6; create, switch, rename, delete and rejoin verified through the server path). Not verified: real clicks in the picker and the `ConfirmDelete` button state, the picker on the phone Device Simulator (moved to CM2-40); teleport without a free plot and real shutdown BLOCKED in Studio (friends-test checklist).
4. [x] **CM2-S2 Co-op saves and invite codes** (done 2026-11-22) (covers CM2-37, CM2-38 re-scoped, CM2-G10 part 2) · L · Depends: CM2-S1. Save sizes Solo/Duo/Trio/Quad (seats 1/2/3/4); one shared plot and cash balance; the creator owns the save; members may do every gameplay action and may play while the owner is offline; only the owner renames, deletes, removes members or regenerates the code. A fixed unique 5-digit numeric invite code per save; joining works while a seat is free. Accept: headless tests for code uniqueness and regeneration (old code stops working), seat limit, owner-only actions rejected for members with an error code, removed member loses access, two members acting at once on one save never double-spend; Studio with 2 test players: join by code, both act on the same plot, the HUD cash matches for both.
   - Status 2026-11-22: all headless and Studio criteria PASS (245/245; runPlaytest full 33/33 on BUILD cm2-s2-r2, soak 6/6; migration 11→12 of the real save without data loss; join by code, shared plot and cash, duplicate request refused across members, owner-only actions, seat limit, regenerate, remove and re-join, delete of a co-op save; HUD cash equal to the server cash with the shadow as member). Not verified: real UI clicks (server path via the hook), the phone Device Simulator (moved to CM2-40); a real 2-client run and a join while another server plays the save BLOCKED in Studio (friends-test checklist, order 15).
5. [x] **CM2-S3 One server per save, teammate finder** (done 2026-11-22) (covers CM2-39) · L · Depends: CM2-S2. A save in use on another server shows "Being played by X – Join", which teleports into that server ("Server full, try again" when full); an in-server "Looking for teammates" list where the searcher owns the new save. Accept: headless tests with a fake MemoryStore for the save-to-server map (claim, renew, expiry after a crash, no two servers holding one save); Studio covers the in-server list; the cross-server teleport is BLOCKED in Studio and goes onto the friends-test checklist (order 15).
   - Status 2026-11-22: all headless and Studio criteria PASS (271/271; runPlaytest full 36/36 on BUILD cm2-s3, soak 6/6; locator claim and renewal, elsewhere row and refusal, finder list/join/stop/switch). Not verified: real taps and screenshots of the picker Join row and the finder panel (Studio viewport 1x1), the finder footer on short landscape phones (CM2-40). BLOCKED in Studio: real cross-server teleports, server full, crash takeover (friends-test checklist, order 15 (a)–(e)).
5a. [x] **CM2-R5 Keep the save lock when the final save fails** (found by the CM2-S1 review, 2026-11-22) · L · Depends: CM2-S2 (it changes who calls `unloadCompany`). Today `CompanyStateService:unloadCompany` drops the session and releases the lock even when its final save fails. Every change since the last good save is then lost on leave or save switch, and another server can load the older record at once. Goal: a failed final save keeps the session in a retrying-unload state that retries `_save` with backoff for up to `SaveFailClosedSeconds`. The lock is released only after a successful save; otherwise it is left to expire (`SessionLockSeconds`). Leave, switch and BindToClose wait for the retry within the shutdown budget. Accept: headless tests:
   - (a) the final save fails twice, then succeeds → the record holds the latest cash and stock, and `release` runs once, after the success;
   - (b) the final save always fails → `release` is never called, the lock stays until it expires, and `leave` returns `SaveFailed`;
   - (c) a Play of that save on the same server gets `SessionBusy` until the retry ends, then loads the saved record, never an older one;
   - (d) `pendingCount()` counts a retrying unload, so BindToClose waits for it.

   Studio: `runPlaytest {mode="full"}` all PASS, unchanged on the happy path.
5b. [ ] **CM2-UV UI verification in a visible Studio window** (added 2026-11-22 for PC-3) · S · Depends: PC-3 (owner), CM2-S1, CM2-S2, CM2-S3. Runs first in the next `hasseln` once PC-3 is resolved. Goal: run the UI items that S1, S2, S3 and G21 left BLOCKED because the Studio viewport was 1x1, with real MCP clicks and screenshots on the 1080p PC viewport. No source change; every defect found becomes a fix task in the launch order directly after CM2-UV. Accept, each item PASS/FAIL in PROGRESS.md with what the screenshot shows:
   - (a) Precondition: in Play, `workspace.CurrentCamera.ViewportSize` > 100x100 and `screen_capture` shows the 3D world. If not, CM2-UV stays BLOCKED and PC-3 is set back to `offen`.
   - (b) CM2-S1: real clicks through create, rename and delete in `SavePickerUI`; `ConfirmDelete` stays inactive until the typed name matches, then becomes active; the picker's `AbsolutePosition.Y` ≥ 0 and the picker lies inside the safe area.
   - (c) CM2-S2: screenshot and clicks of the save footer (Solo/Duo/Trio/Quad size toggles, join-code row) and of `TeamButton` → `TeamPanel` with member rows and the owner footer (and the member footer with the simulated member).
   - (d) CM2-S3: screenshot and tap of the picker "Being played by X – Join" row (elsewhere entry set up as in `runPlaytest`) and of the "Looking for teammates" finder panel with its footer.
   - (e) CM2-G21: screenshots of customer cars, pickup trees and their labels in the 3D world.
   - (f) If CM2-40 is already committed with its screenshot items BLOCKED, CM2-UV also runs them (phone, tablet and 1080p PC in the Device Simulator).
   - (h) CM2-G7 (added 2026-11-22): Pricing tab screenshots on phone, tablet and 1080p PC; taps on −5/−1/+1/+5 and the automatic-pricing button; the card values after the tap equal the server summary; the page scrolls to the last card on the phone.
   - (g) Standard checks pass and `runPlaytest {mode="full"}` is all PASS on the same build.
6. [x] **CM2-40 HUD shell and Lot Manager navigation** (code done 2026-11-22) (re-scoped: English launch, touch first) · M · Depends: none. While PC-3 is open, the code work proceeds; only the screenshot, tap and Device Simulator criteria wait for PC-3 (then run in CM2-40 itself, or in CM2-UV (f) if CM2-40 is already committed). HUD with cash, reputation, day and lot status; a Lot Manager with the 6 reference tabs (Supplier, Catalog, Pricing, Employees, Land, Analytics) as an empty-safe shell that later tasks fill; every control reachable by touch with targets ≥ 44 px; safe-area aware on phones. Accept: Studio Device Simulator screenshots for a phone, a tablet and 1080p PC with no clipped or overlapping elements, including the save footer and Team panel (added 2026-11-22 from CM2-S2, Amendment C2: size toggles, join-code row, `TeamButton`, `TeamPanel` with member rows and the owner and member footers); all strings are full-sentence keys.
   - Status 2026-11-22: code done; headless 293/293, runPlaytest full 36/36 on BUILD cm2-40, HUD cash equal to the server cash, rail and 6 tabs present, Supplier page built lazily. Open: the screenshot, tap and Device Simulator criteria (phone, tablet, 1080p PC; Lot Manager open/close, tab placeholders, key M, modal rule, picker/Team/finder footers) are routed to CM2-UV (f) until PC-3. Ticked because the plan's acceptance routes exactly these items to CM2-UV (f) and everything else in it is met.
   - Added 2026-11-22 from CM2-S1: include the `SavePickerUI` (Picker, DeleteConfirm, SavesButton) in the phone, tablet and PC screenshots; check that the picker stays inside the safe area (the CM2-S1 playtest read AbsolutePosition y = -16 in a 1x1 capture viewport, unconfirmed), and click through create, rename and delete with the `ConfirmDelete` button inactive until the typed name matches.
7. [x] **CM2-G7 Price benchmark and Pricing tab** (code done 2026-11-22) (covers CM2-21, CM2-41 pricing part) · M · Depends: CM2-G6, CM2-40. Unchanged from above; one manual medium price per species (Small and Large shown at 80 %/130 % of it, planner decision, no price per size) with auto-pricing toggle in the Pricing tab. Accept: as above, plus the Pricing tab shows the server values exactly.
   - Status 2026-11-22: done (plan `docs/plans/CM2-G7.md`); headless 308/308, runPlaytest full 36/36 on BUILD cm2-g7, summary `pricing` and the PricingTab probe matched the server values 20/20. The screenshot and tap item (playtest item 6) is routed to CM2-UV (h). Follow-up CM2-G7a below (Noble typical 185 vs observed 184).
7a. [x] **CM2-G7a Noble Fir typical price: observed 184 vs derived 185** (done 2026-11-22) (added 2026-11-22 by the CM2-G7 review) · S · Depends: CM2-G7. REFERENCE_GAME_LIVE_TEST §4.3 shows Noble's typical price as $184, while `wholesale.Medium × 5` gives 185. Under the owner rule "all numbers of the reference game are adopted" the planner decides between an OBSERVED per-species override in `GameConfig.Pricing` (184, bounds 92–460) and a recorded exception for the 5× rule. Accept: the decision in DECISION_LOG; if the override is chosen, headless tests for Noble typical 184 and bounds 92–460, PricingService summary and budget tests updated, no schema change.
   - Status 2026-11-22: done (plan `docs/plans/CM2-G7a.md`); OBSERVED override `TypicalMediumOverride = { NobleFir = 184 }` (DECISION_LOG), headless 309/309, Studio read-back on BUILD cm2-g7a: typical 184, bounds 92–460, 91/461 rejected; budget tests not affected (plan check), no schema change.
8. [ ] **CM2-G14 Automatic unload and bay-to-display stocking** (covers CM2-17, CM2-18) · L · Depends: CM2-G6. Unchanged from above. Accept: as above, plus Studio: the truck unloads into a free bay after its countdown and a row fill of 5 trees places all 5 or none.
9. [ ] **CM2-N1 Walking customer NPCs** (covers CM2-19, CM2-22, CM2-23) · M · Depends: CM2-G14. R15 avatars in varied winter clothing (HumanoidDescription built from config, no third-party avatar assets) leave their parked car, browse the lot, pick and reserve a tree, carry it to checkout, queue, and after paying wait at their car (existing G1 loading flow). Server-side movement with a per-server NPC budget; every NPC and its tree is cleaned up on leave, save switch and shutdown. Accept: headless tests for the state machine (every state has a timeout and an exit, a reserved tree is released when the NPC gives up); Studio: 3 customers walk the full path on one plot with no NPC left behind after they drive away; server heartbeat stays ≥ 55 FPS with 6 plots × max customers in the soak.
10. [ ] **CM2-N2 Manual checkout and queue** (covers CM2-24) · L · Depends: CM2-N1. The player checks out the first queued customer at the counter (ProximityPrompt, server reach check) until a Cashier is hired; the prompt shows species, size, height and price (G3); the sale settles exactly once; customers who wait too long walk out and count as "walked out"; the automatic sale without a player or Cashier is removed. Accept: headless tests for exactly-once settlement under double prompt triggers, queue order, walk-out releases the tree, a member of another save cannot check out on this plot; Studio: queue of 2, player checks out both, cash and sales count rise by the server price.
11. [ ] **CM2-G15 Customer reviews, rating and lot sign** (covers CM2-27 reputation part) · L · Depends: CM2-N2. Unchanged from above, plus "Likes": another player may like a lot once per day (server date, UTC); the sign shows company name, average stars and likes. Accept: as above, plus a second like on the same day is rejected and a player cannot like their own save.
12. [ ] **CM2-25/26 Visible staff with energy and break area** (covers CM2-25, CM2-26, CM2-G16 — decided by the owner: fatigue as gentle as the reference, a movable break area, no wages) · L · Depends: CM2-N2. Cashier, Lot Worker and Lot Manager slot as visible avatars in a uniform in our palette; the Cashier works the counter, the Lot Worker stocks from bays and loads cars; energy drains (PROVISIONAL rate in config) and staff rest in the break area; Employees tab with hire buttons (one-time cost from config: Cashier 1,200, Lot Worker 1,800 OBSERVED). Accept: headless tests that a tired worker walks to the break area and resumes, hiring debits once, no wages are ever charged; Studio: a hired Cashier checks out a queue without the player.
13. [ ] **CM2-46 Robux shop wired by ID** (re-scoped: active at launch, owner creates products) · L · Depends: CM2-40, CM2-S1. Shop UI with the reference's categories and prices (gamepasses, cash packs, boosts, starter pack, event items, premium decor) read from a product config whose IDs the owner fills in; `ProcessReceipt` grants idempotently into the active save and records the purchase before returning `PurchaseGranted`; gamepass ownership checked on join and after purchase; "Robux spent" tracked per player for the leaderboard. Entries without an ID show "Coming soon" and never prompt. No paid random items (version 2). Accept: headless tests for receipt replay (same PurchaseId grants once), grant when the player left mid-purchase (granted on next load, not lost), no active save → `NotProcessedYet`; Studio test purchases (free in Studio) for one product of each kind once the owner provides IDs, BLOCKED until then; an owner checklist of every product name, price and description is in `docs/RELEASE_CHECKLIST.md`.
14. [ ] **CM2-49 Short guided tutorial** · M · Depends: CM2-N2, CM2-40. First save only: order trees → stock them → check out the first customer, with arrows and one-line hints, skippable, never shown again for that save. Accept: headless test that tutorial progress is server-owned and survives a rejoin; Studio: a fresh save completes the tutorial in under 3 minutes on the phone simulator.
15. [ ] **CM2-47a Friends-test build and checklist** (part of CM2-47) · S · Depends: orders 1–14. A private build and `docs/FRIENDS_TEST.md` with steps for 2–5 players: Duo by invite code, cross-server "Join", purchases, a full day of play, a rejoin; a bug-report template. Accept: the checklist exists, the playtester ran every step that Studio can run, and the owner has what they need to run the test. Running the test itself is the owner's action.
    - Added 2026-11-22 from CM2-S2 (BLOCKED in Studio, one client only): a real 2-client co-op run. Both clients type the invite code and join, both act on one plot, and the HUD cash is equal on both screens. Also a `Save.Join` while another server plays the save, which must return `SaveInUse` until CM2-S3.
    - Added 2026-11-22 from the CM2-S3 plan (BLOCKED in Studio: no TeleportService, one server). It supersedes the `SaveInUse` check above once S3 ships. Run on two public servers of the private build:
      - (a) a member on server 2 sees "Being played by <host>" on the shared save, taps Join and arrives on server 1 on the shared plot with the same cash;
      - (b) a friend on server 2 types the code of a save played on server 1 and is teleported and seated;
      - (c) Join into a full server (12 players) shows "That server is full. Please try again in a moment.";
      - (d) after the host server shuts down, the save plays on another server within about 2 minutes (`SessionLocked` text until then);
      - (e) the S1 no-free-plot teleport.

**Gate B — Go/No-Go build (2026-11-28)**
16. [ ] **CM2-G9 Progression ladder** (covers CM2-29, CM2-30, CM2-31, CM2-G19) · L · Depends: CM2-40, CM2-25/26. 6 lot-expansion levels that extend the lot backwards (forest trees removed, fence moved back, snow becomes lot ground; each plot reserves room for all levels), parking tiers, HQ tiers Sales Tent → Timber Pavilion → Alpine Hut → Mountain Chalet with the reference's unlocks and costs, the Lot Manager hire, the Elf Workshop unlock (HQ 4 + Lot Manager) showing "Coming soon"; Land tab lists every requirement with progress. Accept: as G9 above, plus the G19 footprint check passes for every HQ tier and expansion level (no overlap with parking, pickup row, stocking area or checkout); idempotent purchases under double requests.
17. [ ] **CM2-G12 Day/night, day counter and leaderboards** (covers CM2-36 part) · M · Depends: CM2-46 (Robux spent), CM2-S1. 18-minute day (12 day + 6 night), fewer customers at night, lights glow, the day advances only while a save is played; four leaderboards on the village square: Robux spent, hours played, cash earned, reputation. Accept: as G12 above, with "Robux spent" now included (owner decision supersedes "no Robux spent").
18. [ ] **CM2-G11 Daily reward streak, quest board and group bonus** (covers CM2-34, CM2-36 part) · L · Depends: CM2-S1, CM2-40. Unchanged from above, plus "Join group for 2× daily rewards" checked server-side with `IsInGroup`; the group ID comes from the owner (config empty → the bonus is hidden). Accept: as above, plus the 2× is applied once per claim and only to group members.
19. [ ] **CM2-A1 Advent calendar** · L · Depends: CM2-S1, CM2-40. 24 doors, Dec 1–24 (server date, UTC); one door per day, rewards rising (cash, reputation, decor, boosts), specials on Dec 6 and Dec 24 (PROVISIONAL values in config); missed doors can be opened until Dec 24; per player, credited to the active save. Accept: headless tests with a fake clock: a future door is rejected, a missed door opens, each door pays once per player even across two saves, nothing opens after Dec 24; Studio with the clock set to Dec 3: doors 1–3 open, 4 locked.
20. [ ] **CM2-45 Event framework and 1st Advent event** (covers CM2-45 part) · L · Depends: CM2-46, CM2-G9. Timed event shop with countdown, event currency or cash as in the reference, special trees and a decor pack, switched on by a dated event config (2026-11-29, 12-06, 12-13, 12-20); event content for the 1st Advent with our own names. Event models are MODEL tasks; until they pass review, event items reuse existing models recoloured in our palette. Accept: headless tests that the event opens and closes on its dates, event purchases are idempotent, items persist after the event; Studio with the clock on 2026-11-29 shows the event shop.
21. [ ] **CM2-G18 Audio: HQ radio, music, effects, volume** · S · Depends: CM2-40. Radio audible only on the own plot; background music and sound effects from Roblox's licensed audio library (asset IDs and licence noted in `docs/AUDIO.md`); separate music and effects volume in settings. Accept: as G18 above, plus volume settings persist per player.
22. [ ] **CM2-43 English-only strings and accessibility** (re-scoped) · S · Depends: CM2-40. The client always uses English at launch (Roblox auto-translation covers others); DE entries stay in `Localization.lua` for the later language switch; an audit removes concatenated fragments; text scaling and contrast checked. Accept: a headless test that every key has an English full sentence and no UI string is built from fragments; Studio screenshots with a German Roblox locale show English.
23. [ ] **CM2-47 End-to-end, multiplayer and security QA** · M · Depends: orders 1–22 that are done. Exploit pass on every remote and prompt (forged payloads, floods, other-plot and other-save actions, purchase replay), the full Studio script, a 6-plot load soak. Accept: every found defect fixed or filed as a blocking ticket; results in PROGRESS.md.
24. [ ] **CM2-48 Release candidate and owner checklist** (re-scoped: the owner publishes) · S · Depends: CM2-47. `docs/RELEASE_CHECKLIST.md` for the owner: place settings (12 players, API access, DataStore names), product and gamepass creation with names and prices, group ID, experience questionnaire and content maturity, thumbnails and description, private build to public switch. Accept: the checklist is complete and every engineering item on it is ticked with evidence; engineering publishes nothing.
25. [ ] **CM2-50a Go/No-Go regression** (part of CM2-50) · S · Depends: CM2-48. The Studio script and all checks on the release-candidate commit; a one-page Go/No-Go summary for the owner on 2026-11-28 (what works, known issues, what is out). Accept: summary in PROGRESS.md with the commit SHA.

**Gate C — by the 2nd Advent (2026-12-06)**
26. [ ] **CM2-35 Analytics and appeal** (covers CM2-35, CM2-G8, CM2-27 appeal part) · M · Depends: CM2-N2. Analytics tab as in the reference (cards, sales chart, best sellers, more stats, decor block), lot appeal and decor appeal in the demand model. Accept: as G8 above, plus the tab shows server values exactly and history stays bounded.
27. [ ] **CM2-32/33 Decor catalog, layout mode and stock zones** (covers CM2-32, CM2-33, CM2-G13, CM2-42) · L · Depends: CM2-G9, CM2-35. Catalog bought with cash, items placed from a crate, move/rotate/put away/clear all, decorate inventory with search; stock zones with species/height filters and priority; movable HQ blocked by other structures. Launch decor uses small Part-built items (allowed by PRODUCT_SPEC Art) until MODEL tasks deliver more. Accept: as G13 above; placements persist and validate overlaps and plot bounds.
28. [ ] **CM2-45b 2nd Advent event content** (part of CM2-45) · M · Depends: CM2-45. Content for 2026-12-06 in the event config. Accept: Studio with the clock on 2026-12-06 shows the new shop; the 1st event's items are kept.
29. [ ] **CM2-28 Balance pass and anti-exploit economy tests** · M · Depends: CM2-G9, CM2-35. Replace PROVISIONAL values observed meanwhile; a simulated 2-hour economy run per tier stays inside target cash/reputation curves. Accept: simulation test in the headless runner; every changed value carries its evidence tag.
30. [ ] **CM2-45c 3rd and 4th Advent event content** · M · Depends: CM2-45b. For 2026-12-13 and 12-20. Accept: as order 28 for each date.
31. [ ] **CM2-50 Final integration and regression** · S · Depends: everything done before. Accept: full Studio script PASS on the release commit, recorded in PROGRESS.md.

**MODEL tasks — ready since 2026-11-22** (reference images supplied). They enter the order right after the current task, in this order.
- [x] **CM2-R2 → CM2-AP Asset pipeline for Blender MeshParts** (re-scoped: the CC0 art is being removed, so R2 versions the new art instead) · M · Depends: reference images. `.rbxm`/`.fbx` sources under `assets/`, mapped in `default.project.json`, so `rojo build` contains the models; registry IDs and pivots unchanged. Status 2026-11-22: done per `docs/plans/CM2-AP.md` (tooling, 20 pipeline tests, probe fixture; no art), reviewed and committed. Open: the Open Cloud endpoints are only fake-HTTP-tested until PC-2 (first `probe` run in the next MODEL task); the live Studio sync showed no `ArtAssets/Trees` folder (both builds contain it; re-check after a fresh `rojo serve` and plugin reconnect).
- [ ] **CM2-12 Trees** (4 starter species × 3 sizes, special trees) · MODEL.
- [ ] **CM2-13 HQ tiers, fence, bays, checkout** (Sales Tent, Timber Pavilion, Alpine Hut, Mountain Chalet) · MODEL.
- [ ] **CM2-14 Supplier truck and customer cars** · MODEL.
- [ ] **CM2-10 Mountain-village map** (covered wooden bridge over a frozen stream, village square with the big tree and leaderboards, 6 plots on the village road, forest and mountains; plots keep room for all expansion levels) · MODEL.
- [ ] **CM2-44 Art pass and removal of all Codex/CC0 models** · MODEL · Depends: the four above. Accept: no model from `assets/third_party/` remains in the place.

**After launch**
32. [ ] **CM2-R4 Strict Luau types for all of `src/shared`** · S.
33. [ ] **Gamepad support** (PRODUCT_SPEC: after launch) · M.
34. [ ] **In-game language switch (DE, ES, …)** · M.
35. [ ] **Cross-server teammate matchmaking** · L.
36. [ ] **CM2-G17 Season pass** (design first; not in the launch shop list) · S.
37. [ ] **Paid random rolls (version 2)** with disclosed odds and `PolicyService` restrictions · L · needs an owner decision at the time.

### Owner inputs that unblock tasks (not questions for now; tasks continue around them)
- Robux product and gamepass IDs → order 13 Studio purchases, order 24.
- Roblox group ID → order 18 group bonus.
- Model reference images in `docs/art/quality-reference/` → all MODEL tasks.
- Friends-test players → order 15.

## Milestone gates
- P0: tools, unit tests, safe persistence and network foundation.
- P1: order -> delivery -> display -> NPC checkout -> rejoin playable in Studio.
- P2: realistic demand, customer behavior and staff automation.
- P3: upgrade/decor/quests/analytics implemented and persisted.
- P4: shared company, UI, input and localization verified.
- P5: original art polish, seasonal event, security and QA; no release without approval.

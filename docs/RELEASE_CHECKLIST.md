# Release checklist (CM2-48)

Stand: 2026-11-28, Commit `96b831d` (Release-Kandidat, CM2-50a prüft denselben Stand erneut). **Der Owner veröffentlicht; Engineering veröffentlicht nichts und legt keine bezahlten Produkte an oder schaltet sie frei.** Teil A: Engineering-Punkte mit Beleg. Teil B: Owner-Schritte (nummeriert, offen). Teil C: Produkttabelle. Quelle der Preise und Keys: `src/shared/ShopConfig.lua` (`Products`, Zeilen 65 bis 93).

## A. Engineering (nur mit Beleg abgehakt)

- [x] Release-Build ohne Testcode. `rojo build release.project.json --output release.rbxlx` PASS (2026-11-28, `96b831d`). `release.project.json:3` ignoriert `src/server/Services/StudioTestService.lua` (`globIgnorePaths`). Gebaute Datei: 0 Instanzen `UnitTest`, 0 `RunPlaytest`, 0 `StudioTestService` (Namensfeld per `grep -c '<string name="Name">...'`); die übrigen Treffer von „StudioTestService“ sind nur Kommentare. `src/server/main.server.lua:1264-1267` legt den Test-Haken nur in Studio an und überlebt das Fehlen des Moduls.
- [x] Kunst im Release-Build. `lune run tools/art/art.luau verify release.rbxlx`: `[ART] 61 integrated, 0 pending, 0 failed` (2026-11-28, `96b831d`).
- [x] Standard-Checks. `docs/PROGRESS.md:44` (stylua PASS, selene 0/0, headless 793/793, Release-Build PASS); `docs/PROGRESS.md:47` (CM2-47: headless 795/795, Release-Build ohne `rawAction`).
- [x] Sicherheits-QA der Remotes (BusinessAction, SaveAction, ShopAction, Prompts, ProcessReceipt). `docs/PROGRESS.md:46-58` (Tabelle je Remote); Defekt D2 `Notify` behoben in `343cd29` (`docs/PROGRESS.md:64-68`).
- [x] Käufe serverseitig und idempotent. `src/server/main.server.lua:1237` (`ProcessReceipt`), Test 76a in `docs/PROGRESS.md:46-58`: Beleg einmal gewährt, dritter Aufruf `PurchaseGranted` ohne Änderung. Ein Produkt mit `id = 0` oder `ready = false` wird nie angeboten (`src/server/Services/MonetizationService.lua:380`, `:413`).
- [x] Keine nicht freigegebene Zahlung aktiv. Die 12 Produkte mit „ja“ in Teil C haben IDs (`src/shared/ShopConfig.lua:96-109`, Owner-Entscheidung PC-8 in `docs/DECISION_LOG.md:209`); die 15 übrigen sind `ready = false` und `id = 0` (`ShopConfig.lua:65-93`) und werden nie angeboten.
- [x] Teleport bei vollem Server. `main.server.lua:138-151` (`teleportForFreePlot`, nur außerhalb von Studio; 6 Plots, 12 Spieler laut `docs/PRODUCT_SPEC.md:14`).
- [x] Studio-Speicher getrennt vom Live-Speicher. Leaderboards `_Studio`-Suffix (`GameConfig.lua:553-554`, `main.server.lua:315`), Spielort-Karte `_Studio` (`main.server.lua:157-159`).
- [x] Nur englische Texte, schlüsselbasiert (`docs/PRODUCT_SPEC.md:12`).
- [x] Keine Fremd-UI-Pakete im Spiel (`docs/PRODUCT_SPEC.md:61`).
- [x] Studio-Gesamtlauf auf dem Release-Kandidaten und Go/No-Go-Seite (25 CM2-50a). `runPlaytest {mode="full"}` auf `debc1cb`: 78/78 PASS in 870 s, Unit-Runner 795/795 (`docs/PROGRESS.md`, Eintrag CM2-50a).
- [x] Offene Spielpunkte der Startliste (PC-12 Telefon-Tutorial, PC-14, PC-15; Backlog Kopf, „Open PC entries“): als „OUT of 1st Advent launch“ in der Go/No-Go-Seite aufgeführt (`docs/PROGRESS.md`, Eintrag CM2-50a, Stand `debc1cb`).

## B. Owner-Schritte (alle offen)

### B1. Place-Einstellungen (Creator Hub, create.roblox.com → Erlebnis → Place → Einstellungen)
- [x] 1. Max Players = **12** (6 Plots; `docs/PRODUCT_SPEC.md:14`). Das Repo setzt das nicht, es ist eine Place-Einstellung. Beleg 2026-11-28: im Creator Hub (Orte → Zugriff) von 50 auf 12 gesetzt, Place 92354134900807, Hub meldete „Ortszugriff erfolgreich aktualisiert“.
- [x] 2. Erlebnis → Sicherheit (Security): **„Enable Studio Access to API Services“** einschalten. Ohne diese Option arbeiten DataStore und OrderedDataStore in Studio nicht; live ist DataStore immer verfügbar. Prüfen: Studio-Test, Spielstand speichern und neu laden. Beleg 2026-11-28: war bereits aktiv, Studio-Edit-Probe `DataStoreService` `GetAsync` lieferte ok=true (keine Änderung vorgenommen).
- [x] 3. **HttpService braucht keine Freigabe**: der Code nutzt nur `GenerateGUID`, `JSONEncode`, `JSONDecode` (`main.server.lua:120`, `:323`, `Leaderboards.client.lua:91`), keine HTTP-Anfragen. „Allow HTTP Requests“ **aus** lassen. Beleg 2026-11-28: Einstellung nicht angefasst, nicht geändert (Zustand nicht geprüft).
- [ ] 4. Teleport: der Server teleportiert in dieselbe `game.PlaceId` (`main.server.lua:148`); es gibt keinen zweiten Place. Zugriff auf die Erlebnis-Place-ID: keine weitere Einstellung nötig. Private Server und Reservierte Server: nicht genutzt.
- [ ] 5. Streaming: im Release-Projekt `StreamingEnabled = true` (`release.project.json`); nichts einzustellen, nur nicht in Studio abschalten.
- [ ] 6. Keine eigenen Asset-IDs: der Code lädt keine `rbxassetid://`-Assets (Suche in `src/`); alle Modelle liegen als `.rbxm` im Build (`ArtAssets`). Es gibt keine Asset-Berechtigungsliste zu pflegen.

### B2. DataStore- und MemoryStore-Namen (nichts anzulegen, nur nicht umbenennen; live ohne Suffix)
| Zweck | Name | Beleg |
|---|---|---|
| Firmenstand | `ChristmasMarket2_CompanyState_v1` | `PersistenceService.lua:19` |
| Spielerprofil und Slots | `ChristmasMarket2_Profiles_v2` | `SaveSlotService.lua:41` |
| Kaufbuch | `ChristmasMarket2_Purchases_v1` | `PurchaseLedgerService.lua:18` |
| Einladungscodes | `ChristmasMarket2_Invites_v1` | `InviteCodeService.lua:18` |
| Ranglisten (OrderedDataStore) | `ChristmasMarket2_LB_<Board>_v1` mit Board = CashEarned, Reputation, HoursPlayed, RobuxSpent | `GameConfig.lua:550-554` |
| Spielort-Karte (MemoryStore HashMap) | `CM2_SaveServers_v1` | `GameConfig.lua:167` |
Studio schreibt die Ranglisten und die Karte mit Suffix `_Studio`; die vier anderen DataStores teilen sich Studio und live (Studio-Tests mit API-Zugriff schreiben echte Daten). Vor dem Start: Testspielstände in Studio löschen.

### B3. Pässe und Entwicklerprodukte (Teil C)
- [x] 1. Die 12 Produkte „ja“ existieren laut PC-8 bereits mit IDs im Code. In Creator Hub → Monetarisierung prüfen, dass **Name, Preis und Beschreibung genau Teil C entsprechen** und die vier Pässe **zum Verkauf stehen**. Abweichung: im Chat melden, Engineering gleicht Config oder Hub an (Preise erfindet Engineering nicht). Beleg 2026-11-28: alle 12 per `MarketplaceService:GetProductInfo` geprüft, Name, Preis und Beschreibung stimmen mit Teil C und `ShopConfig.lua` `CREATED_IDS` überein, alle `IsForSale=true`, Managed Pricing überall aus. Pässe: 2098973055 Evergreen VIP 199, 2099165138 Express Sleigh 149, 2099729097 Shining Star 79, 2101828296 Golden Till 99. Entwicklerprodukte: 3735805319 Tree Lot Starter Kit 79, 3735805373 Pinecone Purse 29, 3735805396 Sleigh Sack 99, 3735805416 Cabin Chest 249, 3735805452 Village Vault 599, 3735805469 Mountain Treasury 1499, 3735805526 Cash Rush 10, 3735805549 Hot Cider Round 5.
- [x] 2. Die 15 Produkte „später“ **nicht** anlegen. Sie kommen erst mit ihrem Spielsystem (Spezialbäume, Advent-Event CM2-45, Premium-Deko). Entscheidung Owner: ob eines davon vor dem Start live gehen soll; dann Plan nötig (`ready = false` im Code). Beleg 2026-11-28: im Hub existieren nur 4 Pässe und 8 Entwicklerprodukte, keines der „später“-Produkte ist angelegt.
- [x] 3. Kein weiteres bezahltes Produkt, kein Zufallsbelohnungs-Produkt (Regel `ShopConfig.lua:6`). Beleg 2026-11-28: im Hub nur die 12 Produkte aus Teil C (4 Pässe, 8 Entwicklerprodukte).
- [ ] 4. Studio-Testkauf je Art (Pass, Produkt) durch den playtester; in Studio kostenlos. Danach einmal live mit eigenem Konto prüfen (Owner-Entscheidung, ob echter Kauf).
- [ ] 5. Wenn der Hub einen Preis ändert, den Preis in Teil C und `ShopConfig.lua` angleichen; der Shop zeigt den Live-Preis (`MonetizationService`, `refreshPrices`).

### B4. Gruppe
- [ ] 1. Owner-Entscheidung: Gruppe verwenden? Wenn ja, die **Gruppen-ID** im Chat senden; Engineering trägt sie in `src/shared/GameConfig.lua:85` (`DailyRewards.GroupId`) ein. Solange der Wert `0` ist, bleibt der Gruppenbonus (2x Tagesbelohnung) versteckt. Es gibt **keinen Standardwert**, die ID ist nicht im Repo.
- [ ] 2. Die Erlebnis der Gruppe zuordnen (Erlebnis → Einstellungen → Eigentümer), falls die Gruppe Besitzer sein soll.

### B5. Fragebogen, Altersfreigabe, Beschreibung, Bilder
- [x] 1. Creator Hub → Erlebnis → Einstellungen → **Maturity / Content Maturity** (Fragebogen „Experience Guidelines“) wahrheitsgemäß ausfüllen. Hinweise aus dem Spiel: kein Alkohol, keine Gewalt, kein Glücksspiel, keine Zufallsbelohnung gegen Robux, Chat nur über Standard-Roblox-Chat plus Chat-Filter für Namen (`main.server.lua:130-135`), Robux-Käufe vorhanden (Pässe, Entwicklerprodukte). Die Einstufung ist Owner-Entscheidung. Beleg 2026-11-28: Fragebogen vom Owner freigegeben und abgeschickt. Antworten: Gewalt/Blut Nein, Angst Nein, Schimpfwörter Nein, derber Humor Nein, Robux-Käufe Ja (bezahlte Zufallsgegenstände Nein, Handel mit bezahlten Gegenständen Nein), Community-Regeln vom Owner selbst bestätigt; Roblox-Fragen alle Nein (Social Hangout, freie Nutzer-Erstellung — Firmenname ist TextService-gefiltert und daher ausgenommen —, sensible Themen, erlebnisübergreifende Inhalte, KI-Interaktion, Medienaustausch, Autoplay-Feed). Ergebnis: Roblox-Inhaltseinstufung „Minimal“ (Global), IARC-Einstufungen ausstehend. Hinweis: „Hot Cider Round“ ist alkoholfreier heißer Apfelsaft; eine spätere Umbenennung ist eine offene Owner-Idee (keine Aufgabe).
- [x] 2. **Titel**: „Christmas Tree Village“ (`docs/PRODUCT_SPEC.md:7`). Beleg 2026-11-28: Erlebnis von „Christmas market“ in „Christmas Tree Village“ umbenannt und gespeichert.
- [x] 3a. **Beschreibung**: englischer Text (705 Zeichen) im Hub gespeichert; Genre Simulation / Subgenre Tycoon (3 Monate gesperrt). Beleg 2026-11-28, Owner-Freigabe im Chat.
- [ ] 3b. **Symbol / Thumbnails** (Hub-Bilder): vom Owner zu erstellen oder freizugeben. Im Repo gibt es keine Hub-Bilder; Engineering darf Bilder aus dem Spiel erzeugen, wenn der Owner das beauftragt (Owner-Entscheidung). Nur eigene Bilder verwenden, keine Fremdassets.
- [ ] 4. Sprache: Start nur Englisch, Roblox-Übersetzung deckt weitere Sprachen ab (`docs/PRODUCT_SPEC.md:12`). Automatische Übersetzung im Hub einschalten (Owner-Entscheidung).
- [ ] 5. Geräte: Computer, Telefon, Tablet aktivieren (Touch-UI ist gebaut; Telefon-Messung offen, siehe PC-12 und PC-14).
- [ ] 6. Server-Anzeige und Gruppen-Link: Owner-Entscheidung.

### B6. Von privat zu öffentlich
- [ ] 1. Die Veröffentlichungsdatei kommt **nur** aus dem Release-Build des Release-Kandidaten `debc1cb`, gebaut in einem eigenen Worktree (nicht `git checkout` im Arbeitsordner, den die Agenten benutzen): `git worktree add ../cm2-release debc1cb`, `cd ../cm2-release`, `rojo build release.project.json --output release.rbxlx`, dann `lune run tools/art/art.luau verify release.rbxlx` (muss `0 pending, 0 failed` zeigen). Nie aus `default.project.json` veröffentlichen. Den Worktree nach dem Veröffentlichen mit `git worktree remove ../cm2-release` entfernen.
- [ ] 2. Die Datei in Studio öffnen → File → **Publish to Roblox** in den vorgesehenen Place; Erlebnis bleibt **Privat**.
- [ ] 3. Als Owner im privaten Build spielen: Speichern, Neu-Beitreten, ein Testkauf, zweiter Spieler (Freundestest `docs/FRIENDS_TEST.md`, optional).
- [ ] 4. Go/No-Go lesen (CM2-50a), dann Startdatum wählen (2026-11-29 mit reduziertem Umfang oder 2026-12-06).
- [ ] 5. Erst jetzt: Erlebnis → Einstellungen → Privacy → **Öffentlich** schalten. Danach `Studio`-Zugriff auf API-Dienste bleibt an, damit Tests weiterlaufen; Testspielstände nicht mit echten Spielern mischen.
- [ ] 6. Nach dem Start: Creator Hub → Analytics und Fehlerprotokoll in den ersten Stunden beobachten; Rücknahme = Erlebnis wieder auf Privat.

## C. Robux-Produkte und Spielpässe (CM2-46; Werte aus `src/shared/ShopConfig.lua`)

IDs der ersten 12 stehen schon im Code (`ShopConfig.lua:96-109`). „Später“-Produkte haben `id = 0` und `ready = false`.

| Art | Config-Key | Name | Preis (Robux) | Beschreibung | Jetzt anlegen |
|---|---|---|---|---|---|
| Entwicklerprodukt | StarterPack | Tree Lot Starter Kit | 79 | Get $20,000 and 750 reputation for the save you are playing. One per player. | ja |
| Spielpass | PassCashX2 | Golden Till | 99 | Every tree sale pays double cash while you play. | ja |
| Spielpass | PassReputationX2 | Shining Star | 79 | Every customer review gives double reputation while you play. | ja |
| Spielpass | PassInstantDelivery | Express Sleigh | 149 | Your tree orders arrive at once while you play. | ja |
| Spielpass | PassVip | Evergreen VIP | 199 | Customers pay up to 15% more and leave happier reviews, and you get a VIP chat tag. | ja |
| Entwicklerprodukt | CashPinecone | Pinecone Purse | 29 | Adds $1,200 to the save you are playing. | ja |
| Entwicklerprodukt | CashSleigh | Sleigh Sack | 99 | Adds $5,000 to the save you are playing. | ja |
| Entwicklerprodukt | CashCabin | Cabin Chest | 249 | Adds $13,000 to the save you are playing. | ja |
| Entwicklerprodukt | CashVillage | Village Vault | 599 | Adds $34,000 to the save you are playing. | ja |
| Entwicklerprodukt | CashMountain | Mountain Treasury | 1499 | Adds $90,000 to the save you are playing. | ja |
| Entwicklerprodukt | BoostCashX2 | Cash Rush | 10 | Double cash from tree sales for 30 minutes of play on this save. Stacks with Golden Till. | ja |
| Entwicklerprodukt | BoostRested | Hot Cider Round | 5 | All your staff are fully rested at once. | ja |
| Entwicklerprodukt | TreeFrostcrown | Frostcrown Fir | 149 | A special tree that sells for about $1,740 and draws rich customers. Unlocked on every save. | nach Spezialbäumen |
| Entwicklerprodukt | TreeHollyberry | Hollyberry Spruce | 149 | A special tree that sells for about $1,740 and draws rich customers. Unlocked on every save. | nach Spezialbäumen |
| Entwicklerprodukt | EventTreeCandlelight | Candlelight Fir | 199 | An Advent event tree, unlocked forever on every save. | mit dem Advent-Event (CM2-45) |
| Entwicklerprodukt | EventTreeStarlight | Starlight Spruce | 199 | An Advent event tree, unlocked forever on every save. | mit dem Advent-Event (CM2-45) |
| Entwicklerprodukt | EventTreeSnowberry | Snowberry Pine | 199 | An Advent event tree, unlocked forever on every save. | mit dem Advent-Event (CM2-45) |
| Entwicklerprodukt | EventDecorPack | Advent Decor Crate | 29 | Five Advent decorations, three of each, for your lot. | mit dem Advent-Event (CM2-45) |
| Entwicklerprodukt | DecorLanternBoardwalk | Lantern Boardwalk ×25 | 49 | An animated, lit premium decoration for your lot. | wenn Deko fertig ist |
| Entwicklerprodukt | DecorFarmTruck | Classic Farm Truck | 75 | An animated, lit premium decoration for your lot. | wenn Deko fertig ist |
| Entwicklerprodukt | DecorSnowGlobe | Giant Snow Globe | 79 | An animated, lit premium decoration for your lot. | wenn Deko fertig ist |
| Entwicklerprodukt | DecorWorkshopElf | Workshop Elf | 79 | An animated, lit premium decoration for your lot. | wenn Deko fertig ist |
| Entwicklerprodukt | DecorToyTrain | Toy Train Loop | 99 | An animated, lit premium decoration for your lot. | wenn Deko fertig ist |
| Entwicklerprodukt | DecorSnowMaker | Snow Maker | 99 | An animated, lit premium decoration for your lot. | wenn Deko fertig ist |
| Entwicklerprodukt | DecorFatherChristmas | Father Christmas | 99 | An animated, lit premium decoration for your lot. | wenn Deko fertig ist |
| Entwicklerprodukt | DecorPhotoCorner | Photo Corner | 129 | An animated, lit premium decoration for your lot. | wenn Deko fertig ist |
| Entwicklerprodukt | DecorVillageExpress | Village Express Train | 149 | An animated, lit premium decoration for your lot. | wenn Deko fertig ist |

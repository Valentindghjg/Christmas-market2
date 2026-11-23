# Freundestest (CM2-47a)

2–5 Tester spielen einen privaten Build, etwa 2 Stunden. Rollen: **A** (der Owner, Host), **B**, **C** (B und C werden für Block C und X gebraucht), **D**, **E** optional; wenn möglich spielt mindestens ein Tester am Handy.
Roblox-Namen kommen nie ins Repo (öffentlich); Berichte und Ergebnisse nennen nur A–E.
UI-Texte stehen auf Englisch, so wie das Spiel sie zeigt (`<Name>` und `<Zahl>` sind Platzhalter).

## Vorbedingungen (Owner)
- [ ] **V1** Studio-Queue-Batch bestanden (PC-7, „Next hasseln starts here“ Punkt 0): die Client-Checks von CM2-25-26b, CM2-46b und CM2-49 sind PASS.
- [ ] **V2** Für Block K: PC-8 erledigt und CM2-46c (Startreihenfolge 13c) committed, sodass die 12 Produkte „Buy“ zeigen. Ohne V2 wird Block K mit „nicht getestet“ markiert; alles andere läuft.
- [ ] **V3** Veröffentlichen (nur der Owner; Engineering veröffentlicht nichts): `main` auf einem Commit, dessen Checks bestanden; Rojo verbunden; `git log -1 --format=%h` ins Ergebnisblatt schreiben; File → Publish to Roblox; privat lassen, Tester im Creator Dashboard freigeben (Weg nach Wahl des Owners). Rollback: vorherige Place-Version im Versionsverlauf.
- [ ] **V4** Nur Block X: Creator Dashboard → Erlebnis → Places → der Place → Servergröße (max. Spieler) auf **2**; nach Block X zurück auf **12**.
- [ ] **V5** Tester, die das Erlebnis noch nie gespielt haben, prüfen das Tutorial (der Owner kann es in Studio schon gehabt haben; Studio-Spielstände „Playtest …“ in der Liste des Owners können gelöscht werden).
- [ ] **V6** Käufe kosten auf Live-Servern **echte Robux** (kostenlos nur in Studio). Der Owner entscheidet, wer kauft. Vorschlag je Käufer: CashPinecone 29, StarterPack 79, PassCashX2 99, BoostCashX2 10 (zusammen 217 Robux).

## Ablauf
Ergebnis je Zeile: ☐ PASS ☐ FAIL ☐ nicht getestet. Kopf des Ergebnisblatts: Commit (V3), Datum, Tester A–E mit Gerät.

### Block T: Start, Spielstände, Tutorial
| Schritt | Wer | Aktion | Erwartet | Studio | Ergebnis |
|---|---|---|---|---|---|
| T1 | alle | Spiel betreten | Auswahl „Choose a save“ (`savePickerTitle`); neuer Tester: „You have no saves yet. Create one to start.“ (`savePickerEmpty`) | full 02a, 24; UI nur live | ☐ PASS ☐ FAIL ☐ nicht getestet |
| T2 | alle | „New save“ (`saveNew`), Solo, Name, „Play“ (`savePlay`) | HUD „<Name> · Plot <Zahl>“ (`hudSaveStatus`), $84, ★ 90, „Day —“ (`hudDayUnknown`; der Tageszähler kommt mit CM2-G12) | full 24, 25 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| T3 | neue Tester | den Hinweisen folgen | der Reihe nach: „Open the Lot Manager and order a tree.“ (`tutorialOrder`), „Your trees are on the way to a bay.“ (`tutorialDelivery`), „Go to the bay and use Stock.“ (`tutorialStock`), „Place the tree on your lot.“ (`tutorialPlace`), „Wait at the counter for a customer.“ (`tutorialCheckoutWait`), „Check out the customer at the counter.“ (`tutorialCheckout`), „Well done! Your tree lot is open.“ (`tutorialDone`); Delivery/Place/Wait nur in ihrer Situation; Pfeil `◀` am Ziel | full 54, 55; Leiste nur live | ☐ PASS ☐ FAIL ☐ nicht getestet |
| T4 | ein anderer neuer Tester | „Skip“ (`tutorialSkip`), innerhalb von 3 s nochmal tippen | „Tap again“ (`tutorialSkipConfirm`), dann Leiste weg; nach Rejoin weiterhin weg | full 54 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| T5 | A | 2. Solo-Spielstand; „Rename“ (`saveRename`); „Delete“ (`saveDelete`) erst mit falschem, dann mit richtigem Namen | kein Tutorial auf diesem Stand; falscher Name: „The name you typed does not match, so the save was not deleted.“ (`saveErrorConfirm`); danach ist die Zeile weg | full 26, 27, 55 | ☐ PASS ☐ FAIL ☐ nicht getestet |

### Block L: Lieferung, Verkauf, Preise
| Schritt | Wer | Aktion | Erwartet | Studio | Ergebnis |
|---|---|---|---|---|---|
| L1 | alle | Lot Manager → Supplier, 1 Baum bestellen | „Order accepted for $<Zahl>. The truck is on the way.“ (`orderAcceptedTruck`); Geld sinkt um den Preis | full 04 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| L2 | alle | warten | Lkw nach etwa 30 s; Bucht „Delivery arriving <Name>“ (`bayArriving`), dann „<Name> · 1 tree“ (`bayContentsOne`) bzw. „<Name> · <Zahl> trees“ (`bayContents`) | full 05, 06 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| L3 | alle | Buchten-Prompt „Stock <Name>“ (`promptStock`), platzieren, „Done“ (`stockingDone`) | Baum steht auf dem Platz; „1 tree placed.“ (`stockingPlacedOne`); „Row on“ setzt eine Reihe | full 07, 36 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| L4 | alle | warten | Kundenauto; Fußkunde wählt einen Baum („RESERVED“, `treeReserved`), trägt ihn zur Kasse, stellt sich an | full 37, 40 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| L5 | alle | Kassen-Prompt | Geld steigt um den Preis; „Thanks so much!“ (`npcThanks`); danach folgt eine Bewertung | full 08, 41, 42 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| L6 | alle | „Pick up customer tree“ (`promptCarry`) bei „Order #<Zahl> · PICK UP“ (`pickupOrder`); zum falschen Auto, dann zum richtigen („Load tree“, `promptLoad`) | falsches Auto: „This tree is order #<Zahl> – take it to the car marked #<Zahl>.“ (`wrongCar`); richtiges: „Order #<Zahl> complete“ (`orderComplete`) | full 09, 10, 12, 13 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| L7 | B auf As Platz | Tragen/Laden versuchen | nichts passiert | full 14, 15 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| L8 | A | ein Auto unbeladen warten lassen | Auftrag läuft ab; „Cars <Zahl>/<Zahl> · Loaded <Zahl> · Missed <Zahl>“ (`customerStatus`): Missed +1 | full 16 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| L9 | A | Reiter Pricing, einen Preis ändern | „<Name> now sells for $<Zahl> as a medium tree.“ (`pricingSaved`); „Automatic pricing is off.“ (`pricingAutoOff`) | nur live (headless Pricing-Tests) | ☐ PASS ☐ FAIL ☐ nicht getestet |
| L10 | A | 1 Baum zurückverkaufen | „Sold back for $<Zahl>“ (`soldBack`) | full 18 | ☐ PASS ☐ FAIL ☐ nicht getestet |

### Block C: Team-Spielstände
| Schritt | Wer | Aktion | Erwartet | Studio | Ergebnis |
|---|---|---|---|---|---|
| C1 | A | neuer Duo-Spielstand „Freunde Duo“, Reiter Team | „Invite code: <Name>“ (`teamCode`) mit 5 Ziffern; „1 of 2 seats are taken.“ (`teamSeats`) | full 29 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| C2 | B | Code eintippen („Invite code (5 digits)“, `joinCodePlaceholder`), „Join“ (`joinButton`), Play | Zeile „Co-op save for <Zahl> players. Shared with you.“ (`saveRowCoopMember`); HUD „Shared lot from <Name> · Plot <Zahl>“ (`hudSharedSaveStatus`); auf As Platz | full 29 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| C3 | B | 1 Baum bestellen | beide HUDs zeigen sofort dasselbe Geld | full 30 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| C4 | B | Team öffnen | „Member“ (`teamMemberTag`); nur „Leave save“ (`teamLeave`); kein „New code“, kein Entfernen | full 31 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| C5 | C | den Duo-Code eintippen | „This save has no free seat.“ (`saveErrorSaveFull`) | full 31 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| C6 | A, C | A: „New code“ (`teamNewCode`); C tippt den alten Code | „That invite code does not work. Check the code and try again.“ (`saveErrorInviteInvalid`) | full 31 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| C7 | A, B | A entfernt B (zweimal tippen); B tritt mit dem neuen Code wieder bei | B sieht „The owner removed you from this save.“ (`saveErrorRemoved`), Zeile weg; erneuter Beitritt klappt | full 32 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| C8 | A, B | A verlässt das Spiel; B bestellt | klappt; Team zeigt A als „Offline“ (`teamOffline`) | full 32 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| C9 | C, D (oder A) | C: „Teammates“ (`finderButton`) → „Look for teammates“ (`finderStart`); D öffnet den Finder, „Join“ (`finderJoin`) | C: „Your save is listed. Players on this server can join it.“ (`finderOwnListing`); D sieht C mit „1 of 2 seats are taken.“ (`finderSeats`); D steht als Member auf Cs Platz | full 35 | ☐ PASS ☐ FAIL ☐ nicht getestet |

### Block R: Grundstücksschild und Likes
| Schritt | Wer | Aktion | Erwartet | Studio | Ergebnis |
|---|---|---|---|---|---|
| R1 | alle | das Schild am Platz ansehen | „<Name>'s Tree Lot“ (`lotSignOwnerLot`), „No reviews yet“ (`lotSignNoReviews`); nach Verkäufen „★ <Zahl>“ (`lotSignRating`) und „Likes: <Zahl>“ (`lotSignLikes`) | full 42 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| R2 | B | „Like“ (`promptLike`) an As Schild | „You liked this lot!“ (`likeSent`); Likes +1 für alle | full 43 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| R3 | B, A | B liked nochmal; A liked das eigene Schild | „You already liked this lot today.“ (`likeAlreadyToday`); „You can't like your own lot.“ (`likeOwnLot`) | full 43 | ☐ PASS ☐ FAIL ☐ nicht getestet |

### Block K: Shop (echte Robux, siehe V2 und V6)
| Schritt | Wer | Aktion | Erwartet | Studio | Ergebnis |
|---|---|---|---|---|---|
| K1 | Käufer | „Shop“ (`shopButton`) | 7 Kategorien; nicht angelegte Produkte „Coming soon“ (`shopComingSoon`); angelegte „Buy“ (`shopBuy`) mit „<Zahl> Robux“ (`shopPrice`) | full 53; UI nur live | ☐ PASS ☐ FAIL ☐ nicht getestet |
| K2 | Käufer | CashPinecone kaufen | „Complete the purchase in the Roblox window.“ (`shopPromptOpen`), Roblox-Fenster, „Thanks for your purchase! It has been added to your lot.“ (`shopThanks`); Geld +$1,200, genau einmal | full 51 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| K3 | Käufer | StarterPack kaufen | +$20,000 und +750 Reputation; danach „Owned“ (`shopOwned`) | full 51 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| K4 | Käufer | PassCashX2 kaufen | „Thanks! Your game pass is now active.“ (`shopPassActive`); der nächste Verkauf zahlt doppelt | full 52 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| K5 | Käufer | BoostCashX2 kaufen | „Active: <Name> left“ (`shopBoostActive`) ab etwa 30:00, läuft herunter | full 52 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| K6 | B im Duo | CashPinecone kaufen | As HUD zeigt ebenfalls +$1,200 | full 51; nur live | ☐ PASS ☐ FAIL ☐ nicht getestet |
| K7 | Käufer | Rejoin, Play | Geld, Pass und Boost bleiben; nichts doppelt gutgeschrieben | full 19, 51 | ☐ PASS ☐ FAIL ☐ nicht getestet |

### Block S: Personal
Erst ab $1,200 (nach K3 oder nach D1).

| Schritt | Wer | Aktion | Erwartet | Studio | Ergebnis |
|---|---|---|---|---|---|
| S1 | A | Lot Manager → Employees | „<Zahl> / <Zahl> hired“ (`staffHiredCount`) 0 / 2; Lot Manager „Locked“ (`staffLockedShort`) und „Requires the Mountain Chalet (HQ 4).“ (`staffLocked`); „No cashiers yet: you run checkout yourself.“ (`staffNoCashier`) | full 48 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| S2 | A | Cashier einstellen, „Confirm $<Zahl>“ (`staffHireConfirm`) | „Hired“ (`staffHired`); Geld −$1,200; Cashier kassiert an der Kasse | full 44 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| S3 | A | Lot Worker einstellen ($1,800) | befüllt Buchten und belädt Autos | full 17, 46 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| S4 | A | dem Personal zusehen | „Energy <Zahl>% · <Name>“ (`staffStatus`): Energie fällt; „Resting“ (`staffResting`) im Pausenbereich | full 45 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| S5 | A | „Move break area“ (`breakAreaMove`), platzieren | „Break area moved.“ (`breakAreaMoved`); auf Bäumen „Trees are in the way.“ (`breakAreaTrees`) | full 49, 50 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| S6 | A | Rejoin | Personal bleibt, keine doppelten Avatare | full 47 | ☐ PASS ☐ FAIL ☐ nicht getestet |

### Block D: Dauerlauf und Rejoin
| Schritt | Wer | Aktion | Erwartet | Studio | Ergebnis |
|---|---|---|---|---|---|
| D1 | A, B | das Duo 20 Minuten spielen; Geld, ★ und Bäume am Anfang und Ende notieren | kein Fehlertext, nichts hängt, kein Lag | soak 03, 03a, 04; full 20 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| D2 | alle | Geld, ★, Bäume, Personal notieren; verlassen; wieder betreten; Play | alles gleich; Tutorial-Stand unverändert | full 19, 39, 47, 55 | ☐ PASS ☐ FAIL ☐ nicht getestet |

### Block X: Mehrere Server
Zuerst V4 (Servergröße 2). Wer auf welchem Server ist: Spielerliste (Tab). Tester betreten über den Play-Button, nicht über „Join friend“.

| Schritt | Wer | Aktion | Erwartet | Studio | Ergebnis |
|---|---|---|---|---|---|
| X0 | A, B | bei Servergröße 12: A legt ein neues Trio „Freunde Trio“ an; B tritt per Code bei; C ist kein Mitglied; alle verlassen das Spiel; der Owner setzt die Größe auf 2 | — | full 29 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| X1 | A, B | A betritt und spielt das Trio; B betritt und spielt es | beide auf Server 1 | full 33 | ☐ PASS ☐ FAIL ☐ nicht getestet |
| X2 | C | betreten (landet auf Server 2); Trio-Code eintippen | „Taking you to the server where this save is being played…“ (`teleportJoining`), dann „That server is full. Please try again in a moment.“ (`saveErrorServerFull`, CM2-S3 (c)); C hat keine Trio-Zeile | full 34 (Server); Teleport nur live | ☐ PASS ☐ FAIL ☐ nicht getestet |
| X3 | B, C | B verlässt das Spiel; C tippt den Code nochmal | C auf Server 1, Zeile „Co-op save for <Zahl> players. Shared with you.“ (`saveRowCoopMember`), As Platz, gleiches Geld (S3 (b)) | nur live | ☐ PASS ☐ FAIL ☐ nicht getestet |
| X4 | B, C | B betritt (Server 2): Zeile „Being played by <Name>“ (`saveRowElsewhere`) mit „Join“ (`saveJoinServer`); Join tippen; C verlässt das Spiel; Join nochmal tippen | erst `saveErrorServerFull`; dann B auf As Platz, gleiches Geld (S3 (a)) | full 34 (Zeile); Teleport nur live | ☐ PASS ☐ FAIL ☐ nicht getestet |
| X5 | A, Owner | A notiert das Geld; der Owner: „Shut Down All Servers“; A betritt wieder und spielt das Trio | spielbar innerhalb von 2 Minuten („This save is open on another server. Please try again in a minute.“, `saveErrorSessionLocked`, bis dahin alle 30 s erneut versuchen); Geld gleich (S3 (d)) | nur live | ☐ PASS ☐ FAIL ☐ nicht getestet |
| X6 | — | S1: Teleport ohne freien Platz | braucht 7 Spieler mit eigenem Platz auf einem Server (S3 (e)) | nicht testbar (headless) | ☐ PASS ☐ FAIL ☐ nicht getestet |

## Studio-Abdeckung
- `full NN` = Schritt NN von `runPlaytest {mode="full"}`; `soak NN` = Schritt von `runPlaytest {mode="soak", minutes=18}`.
- „nur live“ = braucht echte Clients oder Live-Server.
- „nicht testbar“ = mit 2–5 Spielern nicht erreichbar; durch headless Tests abgedeckt.
- Studio-Vorabläufe: PROGRESS.md, CM2-47a.

## Nach dem Test
- Servergröße zurücksetzen (V4).
- Der Owner schickt Ergebnisblatt und Fehlerberichte im Chat.
- Jedes FAIL wird eine Fix-Aufgabe.
- Go/No-Go bleibt beim Owner (2026-11-28).

## Fehlerbericht-Vorlage
```text
Bericht-ID: B-<Nr>
Checklisten-Schritt:
Tester (A–E):
Gerät (PC/Handy/Tablet, System):
Server (mit wem auf demselben Server):
Uhrzeit (MEZ):
Spielstand (Solo/Duo/Trio/Quad, Owner/Member):
Was ich gemacht habe (Schritte):
Erwartet:
Passiert:
Text auf dem Bildschirm (wörtlich):
Screenshot/Video (ja/nein):
Wie oft (immer/manchmal/einmal):
Schwere (Blocker/Hoch/Mittel/Kosmetik):
Nur Owner – F9 → Server-Log (Fehlerzeilen):
```
- Blocker = Test stoppt oder Fortschritt/Robux gehen verloren.
- Hoch = Funktion falsch.
- Mittel = Umgehung möglich.
- Kosmetik = Aussehen/Text.

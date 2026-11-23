# Release checklist (owner)

CM2-48 completes the rest of this checklist.

## Robux-Produkte und Spielpässe (CM2-46)

1. create.roblox.com → das Erlebnis → Monetarisierung → Pässe: die 4 Spielpässe der Tabelle mit Name, Preis und Beschreibung anlegen und zum Verkauf stellen.
2. Monetarisierung → Entwicklerprodukte: die 8 Produkte mit „Jetzt anlegen: ja“ anlegen (Name, Preis, Beschreibung wie in der Tabelle).
3. Die übrigen 15 Produkte noch nicht anlegen; sie kommen mit ihrem Spielsystem (Spalte „Jetzt anlegen“).
4. Die IDs im Chat schicken (Config-Key → ID). Engineering trägt sie in `src/shared/ShopConfig.lua` ein; erst dann zeigt der Shop „Buy“.
5. Danach testet der playtester einen Kauf je Art in Studio (Testkäufe sind dort kostenlos).
6. Veröffentlichen bleibt deine Aktion.

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

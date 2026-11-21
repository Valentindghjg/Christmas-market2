# Reference game — live play-test observations (2026-11-21)

Status: **OBSERVED** (live play by Claude Code via screenshots and keyboard/mouse on the owner's PC). Items marked **INFERRED** were not directly confirmed.
Purpose: give planner and implementer a complete feature and number inventory of the reference Christmas-tree-lot game, and list the gaps against [GAME_DESIGN.md](GAME_DESIGN.md).

> **IP rule.** This document records mechanics, systems, UI structure and balance numbers. It is not a licence to copy the reference game's names, models, textures, UI art, map layout or branding. Our game keeps its own world, its own models (Parts/MeshParts) and its own item names. The reference item names below are listed so features can be identified, not reused.

## 0. Test session

| | |
|---|---|
| Client | Roblox Player (Windows), owner's account, live public server (3 players) |
| Save used | Owner's existing solo save "Bigmac's Trees": Day 2, $84, ★90 rating 4.4, region North America |
| Plot | Plot 1 of 6 ("north side of the road") |
| Duration | ~25 minutes of interactive testing |
| Changes made to the owner's save | Claimed the day-1 daily reward (+$400). Checked out 2 customers (+$164, +$210). Placed 1 supplier order: 9 trees, −$286. Loaded 1 sold tree into a customer car (+6 reputation). Respawned once through the Roblox menu. |
| Not done (deliberately) | No Robux purchase or purchase prompt, no group join, no chat, no save delete or rename. |

## 1. Session start and save system

1. **Plot picker:** "Choose your property" shows Plot N of 6, browsed with arrow buttons or A/D. A free plot says "Available" and which side of the road it is on. An occupied plot says "Occupied – Home of <company name>" with a disabled button. Confirming opens a "Select plot N?" dialog.
2. **Save picker ("Your tree lots"):**
   - Tabs: **Solo / Duos / Trios / Quads**, so co-op companies have 2–4 members.
   - Save card: company name, day number, cash, star rating, region.
   - Buttons: Start game, Rename, Delete (trash icon), "+ Create new save".
3. **Daily rewards (7-day streak):**

   | Day | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
   |---|---|---|---|---|---|---|---|
   | Reward | $400 | $500 | +150 rep | $700 | $900 | +300 rep | $2,500 |

   After claiming, the button changes to "Come back tomorrow". A side panel offers "Join group for 2× rewards".

## 2. HUD and controls

- **Top right:** Cash, Reputation (★), Lot status (OPEN). Clicking the lot status did nothing.
- **Left column:**
  - Santa's Workshop (padlock, key V). Locked: "reach HQ 4 and hire the Lot Manager".
  - Shop (red "!" badge), Quests, Gamepass.
- **Right:** Menu (no reaction in 4 click tries plus the M key), and Hide (key U), which hides the whole HUD.
- **Bottom:** Layout (L) and Decorate (B).
- **Interaction:** ProximityPrompts with E for Check Out, Use Computer, Stock <species>, Move Tree and loading a car. While the player carries a tree, other prompts fail with "Your hands are full."
- **Placement keys:** R rotate, F size, L fill row, −/+ gap, Q cancel/back, T return to receiving, Z/C choose, V snap, Backspace store.

## 3. Core loop as played

1. **Order (Lot Manager computer):** the HQ tent's desk has a computer with the prompt "Lot Manager – Use Computer". The order went in immediately and cash was debited: "Order placed: 9 trees for $286 — arriving in 00:31". The cart had estimated 00:09.
2. **Delivery → receiving bays:**
   - Trees arrive at **4 drop-off bays**: wooden pallets holding netted tree bundles, each with a floating label such as "Fraser Fir – 5 trees".
   - The cart shows "Delivery area: x / 9 free · Bays 4/4".
   - Land shows "delivery storage 30" at the starter lot.
   - When all bays hold trees, decor orders are blocked: "All 4 drop-off bays have trees: stock one kind out first."
   - The truck's arrival animation was **not watched**.
3. **Stocking:** at a bay the prompt reads "Stock Douglas Fir — 2 Small · 6 Medium · 1 Large". It needs empty hands. Display trees then stand individually on the lot.
4. **Moving display trees:** "Move Tree" opens "Move <species>" with Rotate (R), Place, Cancel (Q), "Return to receiving: OFF" (T), fill row (L) and gap (−/+).
5. **Customers:**
   - Customers drive in from a road tunnel and park in the lot's parking spaces (2 at parking tier 1).
   - They walk in, take a standing tree and **carry it** to the checkout queue.
   - NPCs are blocky avatars in winter clothes (beanies, scarves).
6. **Checkout:** the player stands at the counter. The prompt shows species, height and price, for example "Fraser Fir · 7.2 ft · $164 – Check Out" and "Blue Spruce · 7.7 ft · $210 – Check Out". Cash is credited instantly.
7. **Customer loading (new mechanic, not in our design):**
   - The sold tree is placed on the lot with a billboard "Order #168 – PICK UP".
   - The customer's car shows "#168 HERE".
   - The player picks the tree up and carries it to the matching car. At the wrong car the game says: "This tree is order #168 – take it to the car marked #168."
   - Loading gave **+6 reputation** (90 → 96). The car then drives away with the tree on its roof.
   - On a second order (#167) pickup did not trigger in 4 attempts. Cause unknown (camera on a slope, prompt range, or a hold requirement).
8. **Walk-outs:** Analytics counts "Customers who walked out" (4 of 10 customers on this save).

## 4. Lot Manager (6 tabs)

### 4.1 Tree Supplier
- **Mode toggle:** Buy trees, or Sell back at 25%.
- **Stock:** finite per size; a "Stock refresh" countdown resets supplier stock about every 60 s.
- **Recommended order:** for example "3× Douglas Fir (1 S, 2 M), 3× Fraser Fir (1 S, 2 M), + 3 more" with a one-click "Add to order · $286". When stock runs out it says "Nothing suitable in stock right now — check back after the refresh."
- **Per row:** −, quantity, +, MAX.
- **Demand tags:** HIGH DEMAND or LOW DEMAND per size.
- **Your order panel:** line items, tree count, total, delivery area / bays, estimated delivery, Place order, and recent orders with status ("Preparing order · ETA", "Delivered").

| Species (rarity) | Small 5–6 ft | Medium 7–8 ft | Large 9–10 ft |
|---|---|---|---|
| Douglas Fir (Common) | $21 · 18 avail | $28 · 13 · HIGH DEMAND | $41 · 7 |
| Fraser Fir (Uncommon) | $24 · 15 | $32 · 12 · HIGH DEMAND | $46 · 8 |
| Noble Fir (Rare) | $28 · 14 | $37 · 11 | $54 · 8 · LOW DEMAND |
| Blue Spruce (Uncommon) | $32 · 7 | $42 · 11 · HIGH DEMAND | $61 · 6 |

- **Special trees (Robux unlock, 149 each):** two rows, each "sells for ~$1,740 each, cheap to restock, attracts rich customers".
- **Locked species by HQ tier:**
  - HQ 2 (Christmas Pavilion): Balsam Fir, Norway Spruce, Eastern White Pine, Concolor Fir.
  - HQ 3 (Christmas Market Chalet): Serbian Spruce, Nordmann Fir, Korean Fir, Spanish Fir.
  - HQ 4 (Christmas Lodge): Golden Spruce, Blue Ice Cypress, Weeping Blue Atlas Cedar, Giant Noble Fir.

### 4.2 Catalog (decor, in-game cash)
- "Your order arrives by truck in one crate at receiving." Filters: All, Paths, Lights, Rustic, Christmas, Fences & Signs.
- About 75 items, priced from $8 per tile to $5,000,000:
  - **Starter:** paths $8–15/tile, fence $35, snow tile $40, hay bale $40, crate/firewood $60, chair and gift pile $70, barrel $75, table, gate and sign $90.
  - **Mid:** log path $100/tile, bench $120, candy cane $150, gingerbread figure $160, string lights $180, lollipops and reindeer $180, decorated trees S/M/L $200/$350/$550, wreath post $220, rugs and clothesline $250, sofa $260, themed lanes $300–$800/tile, planters $300–$900, teddy and candles $350, small animals $400–$500, sled of presents $600, nutcracker $650, advent calendar $700, music box $750, armchair and topiary $800, candy jar $900, banquet table $1,000.
  - **High:** fire pit $1,200, snow-themed tile $1,500/tile, mini village $1,500, candy stand $1,800, photo spot $3,000, marble tile $5,000/tile, nativity scene $5,000.
  - **Prestige sinks:** bell $40k, giant novelty tree $400k, ice rink $500k, ballet stage $700k, present cannon $2M, carousel $5M.
  - A few items between the $5,000 tile and the $5,000 nativity scene were scrolled past and not captured.
- **Premium decor (Robux, "animated, lit and one of a kind"):** lit boardwalk ×25 (49), vintage truck (75), giant snow globe (79), elf (79), toy train (99), snow machine (99), Santa (99), photo set (129), train (149), plus at least one more.

### 4.3 Pricing
- Rule as shown: "Set each tree's MEDIUM price: Small sells for 80% of it, Large for 130%. Higher prices earn more per tree, but fewer customers will buy."
- Buttons −5, −1, +1, +5 per species.
- Each card shows medium wholesale, a **"typical" retail price**, medium margin in $ and %, a sentiment line ("Fair price — most shoppers happy") and the resulting S/M/L prices with profit.

| Species | Wholesale M | Typical M | Owner's price M | Small / Large |
|---|---|---|---|---|
| Douglas Fir | $28 | $140 | $146 (margin $118, 81%) | $117 / $190 |
| Fraser Fir | $32 | $160 | $164 (margin $132, 80%) | $131 / $213 |
| Noble Fir | $37 | $184 | $192 (margin $155, 81%) | $154 / $250 |
| Blue Spruce | $42 | $210 | $210 (margin $168, 80%) | $168 / $273 |

**Finding:** the typical retail price is about **5× medium wholesale**. The $82/$96/$105 prices in our earlier screenshot notes were the player's own settings, not game defaults.

### 4.4 Employees ("0 / 2 hired" at the starter tent)
- **Cashier:** $1,200 one-time, handles customer checkout.
- **Lot Worker:** $1,800 one-time, handles deliveries, tree stocking and customer loading.
- **Lot Manager:** $1,250,000 one-time, requires HQ 4. Orders trees and works at the lot computer.
- Empty state: "No cashiers yet: you run checkout yourself."
- **INFERRED:** staff have a rest/energy stat, because a Robux boost "Hot Cocoa Round" makes "all your staff instantly fully rested". It was not seen in play.

### 4.5 Land
- **Lot expansion:** current "Starter Lot (0/6) · delivery storage 30", so there are 6 expansion levels. Next is "Expansion 1 · Back Lot" for $1,200: more display space behind the HQ and +10 delivery storage.
- **Parking:** tier 1 → 2 raises 2 → 4 spaces for $600.
- **HQ:**
  - Starter Sales Tent → **Christmas Pavilion**.
    - Unlocks: 4 new tree species, 2 checkout stations, 3 employee capacity, customer patience +12%.
    - Requires: Lot Expansion 1, Parking tier 2, reputation 250, cash $2,500.
  - Then **Christmas Market Chalet**: 2 checkouts, 5 employee capacity.
  - Then **Christmas Lodge** (HQ 4).
- **Lot appeal (23% on this save):** "Customers accept prices up to +2% higher at a well-stocked, varied lot."
  - Inputs: trees on display (4/16) and kinds, i.e. species × size (3/8).
  - It "builds up slowly while trees stay out on display; more land makes room for more."

### 4.6 Analytics ("Day 2 · how your lot is doing")
- **Cards:** Trees on lot, Total trees sold, Sold today, Avg sale price (today), Daily revenue, Total revenue.
- **Sales performance:** line chart of trees sold per day, with Today / 7 days / All time.
- **Best-seller ranking:** species with bars and counts.
- **More stats:** Trees bought from supplier, Supplier spending, Avg trees sold/day, Customers served, Customers who walked out.
- **Decorations:** "Customers stop to enjoy your decorations. Bigger and better decor = more appeal, more visitors and more tips." Fields: Decor appeal, Extra customers stopping %, Sightseers today, Decor visits today, Decor tips today and all time.

## 5. Quests
- 3 parallel quests plus a locked bonus quest ("Finish quests 1–3"). The set rotates on a timer ("New quests in 3h 55m", so roughly every 4 h).
- Seen:
  - "Order 10 trees" → $150
  - "Earn $2,800 from sales" → $150
  - "Sell 3 Small trees" → $150
  - Bonus "Sell 15 trees" → $550 + 100 reputation
- Each quest can be skipped for 5 Robux.

## 6. Layout and Decorate modes
- **Layout (L):**
  - Top-down camera: WASD or right-drag to pan, scroll to zoom.
  - "Click a zone, or the HQ to move it", so **the HQ is relocatable**.
  - "New stock zone": drag a rectangle so "future staff know where trees belong". The drag did not register in the test.
- **Decorate (B):**
  - Inventory grid with counts (the owner has "Vintage Truck ×1"), a search box and "Clear all".
  - Move, Put away and Done buttons. You can also aim at a placed decoration to move it.

## 7. Monetization (reference only; ours stays disabled per PRODUCT_SPEC)
Every item has a gift button.
- **Timed event shop:**
  - 3 special trees, 199 Robux each, "unlocked forever, every save".
  - A 5-item decor pack ×3 for 29 Robux, sold for 18 h.
- **Starter pack:** once only, 79 Robux: +$20,000, +750 reputation, 5 decor items and 1 free tree roll.
- **Monthly tree gacha (7 tiers):**
  - Odds shown as exact: 38 / 25 / 17 / 11 / 6 / 2.5 / 0.5%.
  - A tree you win unlocks forever as an orderable species in every region. A duplicate pays cash ($1,400–$7,000).
  - Bundles: 1 / 3 / 10 / 25 rolls (1-roll price not shown, 269, 799, 1899 Robux).
- **Monthly decor gacha:** same odds, duplicates $350–$1,750, bundles 35 / 99 / 299 / 649 Robux.
- **Gamepasses:** 2× Cash (99), 2× Reputation (79), Instant Delivery (149), VIP (199: customers pay up to 15% more, happier reviews, chat tag).
- **Cash packs:** $1.2k / $5k / $13k / $34k / $90k for 29 / 99 / 249 / 599 / 1499 Robux.
- **Boosts:** 2× cash for 30 min (10 Robux, stacks with the pass), staff fully rested (5 Robux).

## 8. Social and meta
- **Leaderboards:** 4 physical boards across the road from the lots: Robux spent, Hours played, Cash earned, Reputation. Each shows the worldwide top 10 plus a "You" row.
- **Server:** 6 plots, neighbours visible. Co-op save types for 2–4 players. A region tag on each save (North America).
- **Time:** day counter (Day 2) and a visible day/night cycle; sunset to dusk happened within the session.

## 9. World, graphics and model inventory (what our original art must cover)
- **Style:** stylised low-poly, flat-shaded cone pines with white snow caps, warm sunset lighting with atmosphere haze, falling-snow particles and a day/night cycle.
- **Map:** snowy valley with mountains, dense pine forest, a two-lane asphalt road with a tunnel portal at one end (car spawn), sidewalks and plots on both sides of the road.
- **Plot:** sandy/dirt square with wooden rail fence, entrance arch with a hanging sign and red banners (one shows the region), wooden posts with oversized string-light bulbs at the entrance, 2 parking bays, a "Lot available / Plot N" sign at free plots.
- **HQ tier 1:** red pop-up canopy tent with string lights, desk with computer and cash register, counter with ribbon bows, dark floor mat. Higher tiers (pavilion, chalet, lodge) were seen on other players' plots, including a log cabin with blue roof and a big decorated tree.
- **Stock:**
  - Receiving bays: wooden pallets with netted tree bundles and floating count labels.
  - Standing display trees in S/M/L with size/species variation.
  - Carried tree, and a tree tied to a car roof.
- **Vehicles:** varied customer cars (SUV, van, station wagon, pickup, hatchback), driving and parking; a supplier truck (from the gamepass icon; not watched).
- **NPC customers:** blocky avatars, winter accessories, queue at the counter, carry trees.
- **Props:** campfire with log seats, rocks, stumps, bushes, sign boards, leaderboard boards and the full decor catalogue (section 4.2).
- **UI art:** cream panels in carved-wood frames, garland-and-bow headers, dark-green buttons, gold accents, illustrated icons.

## 10. UX problems seen in the reference (our chance to do better)
- Mixed German/English localization in one screen: "Los" for "Lot", "Kaufen/Verkaufen" next to English text, German-only catalogue item names.
- Button text breaks mid-word ("KAUFE N", "VERKA UFEN").
- The Menu button did not respond at all.
- The Lot Manager close button did not respond, so the player had to respawn to escape the panel.
- Some buttons need a hover before a click registers.
- The camera clips into the hillside next to the lot.
- Order #167 pickup could not be triggered.

## 11. Gap analysis against our design (for planner)

| # | Reference behaviour | Our docs / code today | Proposed action |
|---|---|---|---|
| G1 | **Customer loading:** sold tree gets an order number and must be carried to the matching parked car; worker can automate; gives reputation | Not in GAME_DESIGN; sale completes at checkout | New ticket: order-number pickup and car-loading step, carried-item state, Lot Worker job |
| G2 | Customers arrive by car via road and parking spaces; parking tier limits concurrent customers | Parking only as an upgrade gate | Make parking spaces a customer-capacity mechanic; car spawn/despawn lane |
| G3 | Player-operated checkout prompt with species, height and price | Counter exists; check prompt content | Align prompt text and per-tree height display |
| G4 | 4 receiving bays plus delivery storage 30 (+10 per expansion); "Stock <species>" moves trees to display | Delivered → Stored → Displayed buckets | Map bays to Delivered/Stored; add bay count and storage caps to config |
| G5 | Finite supplier stock per size, ~60 s refresh, HIGH/LOW demand tags, recommended order, sell-back 25% | Supplier quotes without these | Add stock pool, refresh timer, demand tags, recommended order, sell-back |
| G6 | Wholesale per size observed (table in 4.1); Douglas Fir is a 4th starter species | GAME_DESIGN says "wholesale by size not observed" and lists 3 species | Update evidence tier and config; add a Common starter species (our own name) |
| G7 | Typical retail ≈ 5× wholesale; $82/$96/$105 were player settings | Docs present $82/$96/$105 as observed medium prices | Correct the evidence note; base the price benchmark on wholesale × 5 |
| G8 | Lot appeal (variety and stock → +2% price tolerance) and decor appeal (sightseers, tips) | Variety factor only in the provisional formula | Explicit appeal metrics in analytics and the demand model |
| G9 | 6 lot-expansion levels, HQ 4 tiers, Lot Manager $1.25M, Santa's Workshop end-game | Later HQ tiers unknown | Fill in tier names, unlocks and costs as config; Workshop as a later milestone |
| G10 | Save slots per player, Solo/Duo/Trio/Quad saves, rename/delete, region | Personal plus collaborative company mode | Add multi-save UI and co-op size tiers to the P4 design |
| G11 | Daily 7-day reward streak; quests rotate ~4 h with a bonus quest | Quests only generic | Add daily streak and a 3+1 quest board to the P3 design |
| G12 | Day counter and day/night cycle; leaderboards for cash, reputation and playtime | Leaderboards mentioned | Add a day counter and lighting cycle; choose leaderboard metrics (no "Robux spent") |
| G13 | Layout mode with stock zones and a movable HQ; decorate inventory with search, put-away and clear-all | Layout and decor planned | Use as UI checklist |

## 12. Not verified in this session
- Truck arrival and unloading animation.
- The exact stocking flow after "Stock <species>" (hands were full during the test).
- Customer browsing AI and patience timeout.
- Staff working.
- HQ upgrade build.
- Co-op saves, Santa's Workshop content, Menu content, night lighting at full dark, and mobile/console layouts.

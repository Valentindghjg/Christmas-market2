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
| Duration | Two sessions, ~25 + ~25 minutes of interactive testing |
| Changes made to the owner's save (session 1) | Claimed the day-1 daily reward (+$400). Checked out 2 customers (+$164, +$210). Placed 1 supplier order: 9 trees, −$286. Loaded 1 sold tree into a customer car (+6 reputation). Respawned once through the Roblox menu. |
| Changes made to the owner's save (session 2) | Checked out 2 customers (+$146 each). Loaded orders #167, #169 and #170 into customer cars (reputation 96 → 117). Stocked 6 Douglas Firs from a bay onto the lot. Sold back 3 Douglas Firs (+$20). Ordered 3 small Douglas Firs (−$63). Claimed one quest (+$150). Created and deleted a test stock zone. Opened "Move HQ" and cancelled it. Respawned twice. End state: $971, ★117. |
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
  - Shop (red "!" badge), Quests (number badge when a quest can be claimed), and "Gamepass". Despite its name, "Gamepass" opens the season pass (section 7a).
- **Right:** Menu (no reaction in about 8 attempts across both sessions, with and without window focus, plus the M key), and Hide (key U), which hides the whole HUD.
- **In the world:**
  - Company sign at the lot edge: company name, star rating (moved 3.7–3.9 during the test) and a "Likes" counter.
  - A radio in the HQ tent with the prompt "Christmas Radio – Change Music" (key R).
- **Bottom:** Layout (L) and Decorate (B).
- **Interaction:** ProximityPrompts with E for Check Out, Use Computer, Stock <species>, Move Tree and loading a car. While the player carries a tree, other prompts fail with "Your hands are full."
- **Placement keys:** R rotate, F size, L fill row, −/+ gap, Q cancel/back, T return to receiving, Z/C choose, V snap, Backspace store.

## 3. Core loop as played

1. **Order (Lot Manager computer):** the HQ tent's desk has a computer with the prompt "Lot Manager – Use Computer". The order went in immediately and cash was debited: "Order placed: 9 trees for $286 — arriving in 00:31". The cart had estimated 00:09.
2. **Delivery → receiving bays:**
   - Trees arrive at **4 drop-off bays**: wooden pallets holding netted tree bundles, each with a floating label such as "Fraser Fir – 5 trees".
   - The cart shows "Delivery area: x / 9 free · Bays n/4". **INFERRED:** one order fills one bay of up to 9 trees.
   - Land shows "delivery storage 30" at the starter lot.
   - When all 4 bays hold trees, new orders are blocked ("Delivery area: 0 / 0 free"), and so are decor orders: "All 4 drop-off bays have trees: stock one kind out first."
   - **Order status:** "Preparing order · ETA" → "In Transit" → "Delivered".
   - **Timing:** the actual ETA after placing was 25–31 s, while the cart's estimate showed only 3–9 s.
   - **Arrival:**
     - A floating countdown "DELIVERY ARRIVING 00:13" appears over the free bay.
     - A green flatbed truck loaded with netted trees ("TRUCK PULLING IN…") drives up a gravel delivery lane beside the bays. A "DELIVERIES" sign marks that lane.
     - The bundles appear on the bay **automatically** and the truck leaves. The player does not unload.
3. **Stocking (bay → display):**
   - At a bay the prompt reads "Stock Douglas Fir — 2 Small · 6 Medium · 1 Large". It needs empty hands.
   - This opens a placement bar headed "DOUGLAS FIR · 2 SMALL · 6 MEDIUM · 1 LARGE" (the current size is highlighted) with buttons Size (F), Rotate (R), Place, Done (Q), Fill row (L) and Store mode (G).
   - **Ghost preview:** green when valid, otherwise red with a reason: "Too close to another tree", "Keep this area clear" (the space in front of the checkout), "Outside your lot".
   - **Fill row:** places a whole row of the selected size in one click, with a gap control (−, "GAP 0.5", +). Three medium trees were placed in one click.
   - **Store mode:** "Press place to put this tree back in receiving".
   - Each standing display tree has a floating label, for example "Douglas Fir – Small · 5.1 ft · $117". A tree a customer has chosen shows **"RESERVED"**.
4. **Moving display trees:** "Move Tree" opens "Move <species>" with Rotate (R), Place, Cancel (Q), "Return to receiving: OFF" (T), fill row (L) and gap (−/+).
5. **Customers:**
   - Customers drive in from a road tunnel and park in the lot's parking spaces (2 at parking tier 1).
   - They walk in, choose a standing tree (it becomes RESERVED) and **carry it** to the checkout queue.
   - NPCs are blocky avatars in winter clothes (beanies, scarves). After paying they show a speech bubble ("Thanks so much!").
6. **Checkout:** the player stands behind the counter. The prompt shows species, height and price, for example "Fraser Fir · 7.2 ft · $164 – Check Out", "Blue Spruce · 7.7 ft · $210" and "Douglas Fir · 7.2 ft · $146". Cash is credited instantly. Order numbers count up per sale (#167 → #170).
7. **Customer loading (new mechanic, not in our design):**
   - The sold tree is placed on the lot with a billboard "Order #168 – PICK UP". Its prompt is "Order #N – Pick Up Customer Tree".
   - The customer's car shows "#168 HERE".
   - The player carries the tree to the matching car and either uses the prompt "Load Tree" or just walks close enough.
   - At the wrong car the game says: "This tree is order #168 – take it to the car marked #168."
   - On delivery: "ORDER COMPLETE" billboard, the tree appears tied on the car roof and the car drives off.
   - **Customer review:** a popup with 1–5 stars and a line of text. Seen: 3★ "Service was slow." and 3★ "Waited too long for my tree."
   - **Reputation per loading:** +6 for slow service, +9 for a faster one. The lot sign's star rating updates from these reviews.
   - The first #167 attempt failed only because the character stood outside the fence. From inside the lot the pickup worked.
8. **Walk-outs:** Analytics counts "Customers who walked out" (4 of 10 customers on this save). The review texts suggest that waiting time drives both rating and walk-outs (**INFERRED**).

## 4. Lot Manager (6 tabs)

### 4.1 Tree Supplier
- **Mode toggle:** Buy trees, or Sell back at 25%.
- **Stock:** finite per size. A "Stock refresh" countdown restocks the supplier; right after a refresh it read 3:56, so the cycle is about 4 minutes.
- **Sell back (25%):**
  - "The distributor takes back unwanted trees for 25% of what they cost – instantly. They come out of receiving first, then off your lot. Trees a customer has chosen are never sold."
  - One row per species and size showing the unsold count and the refund each (for example small Douglas $5, large Noble $14), with −, quantity, +, ALL and "SELL · $x".
  - Confirmation toast: "Sold 1 tree back to the distributor for $10."
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
- Finished quests show a **Claim** button. Rewards are not paid automatically; claiming shows "Quest complete! $150" and the card changes to "✓ Done".

## 6. Layout and Decorate modes
- **Layout (L):**
  - Top-down camera: WASD or right-drag to pan, scroll to zoom.
  - "Click a zone, or the HQ to move it", so **the HQ is relocatable**.
  - **New stock zone:** drag a rectangle ("Drag to the opposite corner, release to finish"; the size shows live, for example "10 × 10") so "future staff know where trees belong".
    - The zone shows on the ground as "STOCK ZONE – Any tree".
    - Zone settings: Name, Species (Any, or cycle), Min height, Max height, Priority (Primary), "Auto arrange: coming later", Delete zone.
    - Zone toolbar: Settings, Move, Rotate (R), Duplicate, Undo (Ctrl+Z), Delete (Del), Done (Q). Drag the centre to move, drag a corner or edge to resize.
    - Deleting asks "Delete stock zone? This zone is empty" with Delete or Keep.
  - **Move HQ:** "Free – the checkout and staff come with it", with Rotate (R), Confirm (Enter) and Cancel (Q).
    - A blocked spot reads "The break area is in the way – open Layout and move it first".
    - So the lot has a separate **staff break area**: the campfire with log seats.
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

## 7a. Season pass (opened by the HUD "Gamepass" button)
- **"First Frost Pass"**, ends in 9 d 11 h.
- **Progress:** "3,320 / 10,000 to tier 2". "Sell trees and finish Daily Quests to fill it."
- **Buttons:** Gift, "Skip tier" (29 Robux), "Get Premium" (299 Robux).
- **Two tracks:**
  - Free track, tiers 1–6: 2× cash 15 min (claimed), decor item, 2× reputation 10 min, decor item, 2× cash 15 min, decor item.
  - Premium track: decor stands and longer boosts (2× reputation 15–20 min, 2× cash 20 min, an inflatable decoration).
- Tiers beyond 6 could not be scrolled into view.

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
- **Vehicles:**
  - Varied customer cars (SUV, van, station wagon, pickup, hatchback), driving and parking, some with decorations such as antlers.
  - A tree tied on the roof after loading.
  - A green flatbed supplier truck carrying netted trees, using a gravel delivery lane with a "DELIVERIES" sign.
- **Lot extras:** company sign with stars and likes, HQ radio, floating labels for tree size and price, "RESERVED", "PICK UP" and "#N HERE".
- **NPC customers:** blocky avatars, winter accessories, queue at the counter, carry trees.
- **Props:** campfire with log seats, rocks, stumps, bushes, sign boards, leaderboard boards and the full decor catalogue (section 4.2).
- **UI art:** cream panels in carved-wood frames, garland-and-bow headers, dark-green buttons, gold accents, illustrated icons.

## 10. UX problems seen in the reference (our chance to do better)
- Mixed German/English localization in one screen: "Los" for "Lot", "Kaufen/Verkaufen" next to English text, German-only catalogue item names.
- Button text breaks mid-word ("KAUFE N", "VERKA UFEN").
- The Menu button never responded (about 8 attempts).
- Panel close buttons sometimes ignore clicks until the player has clicked once into the game world. This made the Lot Manager look "stuck" in session 1, so the player respawned to get out. It may partly come from remote input; treat it as unconfirmed.
- Some buttons need a hover before a click registers.
- The camera clips into the hillside next to the lot.
- In zone settings, clicking a ◀ ▶ selector closed the panel instead of changing the value (2 of 2 attempts).
- The pickup prompt does not reach through the fence, so a player outside the lot cannot pick up an order lying just inside.

## 11. Gap analysis against our design (for planner)

| # | Reference behaviour | Our docs / code today | Proposed action |
|---|---|---|---|
| G1 | **Customer loading:** sold tree gets an order number and must be carried to the matching parked car; worker can automate; gives reputation | Not in GAME_DESIGN; sale completes at checkout | New ticket: order-number pickup and car-loading step, carried-item state, Lot Worker job |
| G2 | Customers arrive by car via road and parking spaces; parking tier limits concurrent customers | Parking only as an upgrade gate | Make parking spaces a customer-capacity mechanic; car spawn/despawn lane |
| G3 | Player-operated checkout prompt with species, height and price | Counter exists; check prompt content | Align prompt text and per-tree height display |
| G4 | 4 receiving bays plus delivery storage 30 (+10 per expansion); "Stock <species>" moves trees to display | Delivered → Stored → Displayed buckets | Map bays to Delivered/Stored; add bay count and storage caps to config |
| G5 | Finite supplier stock per size, ~4 min refresh, HIGH/LOW demand tags, recommended order, sell-back 25% | Supplier quotes without these | Add stock pool, refresh timer, demand tags, recommended order, sell-back |
| G6 | Wholesale per size observed (table in 4.1); Douglas Fir is a 4th starter species | GAME_DESIGN says "wholesale by size not observed" and lists 3 species | Update evidence tier and config; add a Common starter species (our own name) |
| G7 | Typical retail ≈ 5× wholesale; $82/$96/$105 were player settings | Docs present $82/$96/$105 as observed medium prices | Correct the evidence note; base the price benchmark on wholesale × 5 |
| G8 | Lot appeal (variety and stock → +2% price tolerance) and decor appeal (sightseers, tips) | Variety factor only in the provisional formula | Explicit appeal metrics in analytics and the demand model |
| G9 | 6 lot-expansion levels, HQ 4 tiers, Lot Manager $1.25M, Santa's Workshop end-game | Later HQ tiers unknown | Fill in tier names, unlocks and costs as config; Workshop as a later milestone |
| G10 | Save slots per player, Solo/Duo/Trio/Quad saves, rename/delete, region | Personal plus collaborative company mode | Add multi-save UI and co-op size tiers to the P4 design |
| G11 | Daily 7-day reward streak; quests rotate ~4 h with a bonus quest | Quests only generic | Add daily streak and a 3+1 quest board to the P3 design |
| G12 | Day counter and day/night cycle; leaderboards for cash, reputation and playtime | Leaderboards mentioned | Add a day counter and lighting cycle; choose leaderboard metrics (no "Robux spent") |
| G13 | Layout mode with stock zones (species and height filters, priority) and a movable HQ; decorate inventory with search, put-away and clear-all | Layout and decor planned | Use as UI checklist |
| G14 | Delivery is unloaded automatically by the truck into a bay; the player only stocks bays onto the lot, with single, row-fill and store placement | GAME_DESIGN says "owner or worker unloads to Stored" | Clarify: Delivered = bay; the manual step is bay → display |
| G15 | Customer reviews (stars and text) after loading; reputation depends on service speed; lot sign shows star rating and likes | Reputation per sale only | Add a service-time-based review and rating model and an in-world rating sign |
| G16 | Staff break area (campfire seats) that blocks HQ moves; staff "rest" implied by a boost | No staff rest concept | Decide whether to adopt staff fatigue (no wages remains binding) |
| G17 | Season pass with free and premium tracks fed by sales and quests | Not in design | Design only; premium stays disabled per PRODUCT_SPEC |
| G18 | In-HQ radio to change music | Not in design | Small optional audio feature |

## 12. Not verified in these sessions
- **Needs more in-game cash or progress:** staff working (none hired), HQ upgrade build, lot expansion and parking build, Santa's Workshop content, special and premium trees.
- **Needs other setups:** co-op saves (Duos/Trios/Quads), mobile and console layouts.
- **Blocked by the game:** Menu content (button does not respond).
- **Not measured:** exact customer patience timeout and walk-out trigger. Reviews show that waiting time matters.
- **Not changed:** settings in the zone settings panel (the selectors closed the panel).

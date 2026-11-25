# Christmas Market 2 — binding product specification (2026-11-19)

# Owner decisions 2026-11-21 — launch scope for "Christmas Tree Village" (supersede earlier text)
Source: owner interview after the reference play-test ([REFERENCE_GAME_LIVE_TEST.md](REFERENCE_GAME_LIVE_TEST.md)). Where this section conflicts with anything below or in other docs, **this section wins**.

## Frame
- **Title:** Christmas Tree Village. The repository and project name stay "Christmas Market 2".
- **Release target:** 1st Advent, **2026-11-29**, only if the owner declares it finished. Otherwise the 2nd Advent, **2026-12-06**, is the latest date. The owner decides on **2026-11-28**.
- **Scope:** as much as possible at a high quality bar. Priority order: the core loop must be fully playable first, then everything else in priority order. Quality over quantity (for example, not 150 decor items at launch).
- **Fidelity:** **all functions and all numbers** of the reference game are adopted (OWNER DECIDED). Unknown numbers get extrapolated values marked PROVISIONAL and are replaced once observed. Look, map, names and models are our own.
- **Language:** launch in **English only**; Roblox automatic translation covers other languages. Keep all text key-based and in full sentences (no concatenated fragments). An in-game language switch (DE, ES, …) comes in a later update. *Supersedes "German and English" / "DE/EN".*
- **Platforms:** PC and phone equally at launch (touch controls for every interaction), tablet included; gamepad after launch.
- **Server:** 12 players per server, 6 plots. A solo player without a free plot goes to another server.
- **Plot picker (owner decision 2026-11-24):** as in the reference, the first player of a save on a server chooses a free plot from a camera view over the map ("Plot N of 6", free or occupied with the company name, confirm). Teammates of a save that already plays there join its plot directly. Backlog CM2-PP.

## Gameplay (all as in the reference unless stated)
- **Checkout:** the player checks out customers manually at the counter until a Cashier is hired.
- **Customers:** visible walking NPCs (Roblox R15 avatars in varied winter clothing). They arrive by car, browse, pick a tree, carry it to checkout, queue, pay, wait at the car (G1) and leave a star review.
- **Staff:** Cashier, Lot Worker and Lot Manager are visible avatars in a uniform in our palette. **Energy/fatigue as gentle as in the reference**; the rate is observed later (PROVISIONAL until then). Staff rest in a movable **break area**. No wages.
- **Day/night:** one game day = **18 minutes** (12 min day + 6 min night). Fewer customers at night, lights glow. The day counter advances only while a save is actively played; no offline progress.
- **Lot expansion extends the lot backwards:** the forest trees behind it disappear, the fence moves back, and the snow ground becomes lot ground. Every plot reserves room for all levels.
- **Tree species:** real species in the reference's unlock order (with the spelling fix "Fraser Fir"). Special and event trees get our own names.
- **HQ tiers (own names):** Sales Tent → Timber Pavilion → Alpine Hut → Mountain Chalet. The end goal **Elf Workshop** unlocks as in the reference (HQ tier 4 + Lot Manager); its content shows "Coming soon" until observed in the reference.
- **Tutorial:** short and guided: order → place → customer picks up.
- **Map:** mountain village theme. Cars enter over a **covered wooden bridge** across a frozen stream (instead of a tunnel). A **village square** has a large decorated tree and the leaderboards; 6 plots along the village road; snowy forest and mountains around.
- **Leaderboards:** all four as in the reference: Robux spent, hours played, cash earned, reputation.
- **Audio:** HQ radio plus background music and sound effects from Roblox's licensed audio library. The radio is audible only on the own plot; music and effects have separate volume settings.
- **Lot sign:** company name, star rating from customer reviews, and "Likes" (other players can like a lot once per day).

## Saves and multiplayer (supersedes "collaborative company mode with roles")
- **Unlimited saves per player** (scrolling list) with rename and delete (with confirmation). No region field.
- **Solo / Duo / Trio / Quad saves:** one shared plot and one shared cash balance. The **creator owns** the save. Every member may do everything in play; only the owner may rename, delete, remove members or renew the code. Members **may play the save while the owner is offline**.
- **Invite:** a fixed **5-digit numeric code** per save. Joining works while a seat is free (2/3/4). The owner can regenerate the code and remove members.
- **Finding random teammates:** at launch, a "looking for teammates" list inside the current server; whoever starts the search owns the new save. Cross-server matchmaking comes in an update.
- **One server per save:** a save in use elsewhere shows "Being played by X – Join", which teleports into that server ("Server full, try again" when full).

## Monetization and events (supersedes "disabled until separate approval")
- **The Robux shop is active at launch** with the reference's products and prices: gamepasses, cash packs, boosts, starter pack, event items and premium decor. The owner creates the products in the Creator Dashboard; engineering wires them by ID and handles receipts idempotently. Publication remains the owner's action.
- **Paid random rolls / loot boxes come in version 2**, not at launch, with disclosed odds and `PolicyService` country restrictions.
- **Roblox group:** "Join group for 2× daily rewards" as in the reference. The owner creates the group and provides the group ID.
- **Events:** one event per **Advent Sunday** (2026-11-29, 12-06, 12-13, 12-20) with the reference's mechanics and themes (timed event shop with countdown, special trees, decor pack). Items and models are our own designs; names invented by the reference game get our own variants. Further reference events are observed and mirrored.
- **Advent calendar (high priority):** one free door per day from Dec 1 to Dec 24, with rewards increasing (cash, reputation, decor, boosts; specials on Dec 6 and Dec 24). Missed doors can be opened until Dec 24. Per player, credited to the active save.

## Art
- **Own palette**, low-poly winter style, with quality over free packs. **All current Codex/CC0 models are removed** and replaced.
- **Larger and visible models** (buildings, cars, truck, trees, stalls, terrain props) are modeled in **Blender** and imported as MeshParts. Roblox Parts are used only for small items (signs, pallets, slats, small decor), always in the palette and cleanly finished.
- **Self-review:** Opus 5.5 (medium effort) builds and reviews models itself against the owner's reference images in `docs/art/quality-reference/`. The owner supplied them on 2026-11-22: 3 liked, 3 disliked. The descriptions and the checklist are in its README. Only models that pass are integrated.
- **Quality tiers (owner decision 2026-11-22):**
  - The target is stylised low-poly that is neither too simple nor too detailed or realistic.
  - Models seen often or for long (stand and HQ, cars, truck, buildings, trees for sale) need the higher tier A.
  - Small, distant or rare models need at least tier B.
- **Reference look (owner decision 2026-11-22):** every model follows the reference game's look: how it is built, its proportions, the arrangement of its parts and its colour mood. It is never identical: the silhouette details, palette values and decoration are our own, with no logos, names or textures from the reference.

## UI look (owner decision 2026-11-22)
- **Until shortly before release** the UI stays functional in its current style. New screens use only the tokens in `src/shared/UiTheme.lua` and the builders in `src/client/UiKit.lua` and get no visual polish, so the redesign does not have to be redone after every feature.
- **The visual redesign is the last task before release** (CM2-UI in the backlog). It works from the owner's liked and disliked UI screenshots and, if one exists, a mockup, and uses one graphics set (frames, buttons, icons). Possible sources are an AI UI generator such as ForgeGUI, a CC0 set such as Kenney, or a bought kit with a written licence for commercial use in Roblox. Every set gets its licence and source recorded.
- The redesign changes the look only. Behaviour, remotes and string keys stay as they are.
- **Graphics set (owner decision 2026-11-25, replaces "no bought UI pack" of 2026-11-24).** The UI is built on the Essential UI Pack by Swarve Studios: its layout patterns, images, icons, heavy fonts, strokes, gradients, sounds and button tween (hover 110 %, press 90 %). Licence (any use and modification, re-upload allowed, no reselling of the assets) and contents in `assets/third_party/swarve-essential-ui/`. Its scripts, remotes, receipt handlers, rebirth and paid wheel are not used. The direction below still decides colours and sizes where the pack leaves room. The pack is also offered in the template repo as an optional add-on that new games may use but need not.
- **Target look (owner decision 2026-11-24).** Built through our `UiTheme` tokens and `UiKit` builders. Direction from the owner and from the reference's UI (REFERENCE_GAME_LIVE_TEST section 9: cream panels, dark-green buttons, gold accents):
  - **Calm and creamy.** Cream panels with dark text as the main surface; dark green only for primary buttons and headers; gold for money and highlights; a muted red only for close and danger. No saturated red, green or blue fills, no rainbow of button colours, no decorative gradients.
  - **Heavy type.** Titles, buttons and numbers in a heavy rounded font, body text at least bold, never thin. Titles get a dark outline for readability.
  - **Tap targets.** Buttons at least 44 px high (Roblox and Apple minimum), whole rows tappable. (Was "48 px, primary 56 px on phone"; lowered by the owner decision of 2026-11-25 below.)
  - **Compact on phone (owner decision 2026-11-25).** On a phone the UI must not be too big: the 3D world stays the main thing on screen. Windows, HUD and text are smaller on phone than on tablet and PC, and the pack's large frame sizes are not taken over. Limits: every window at most 70 % of the safe-area width and 80 % of its height; the HUD (button rail, money bar, stocking bar, hints) together at most 20 % of the screen; buttons 44–52 px high; body text 14–16 px, titles at most 24 px; no screen bigger on phone than it is today.
  - **Feedback.** Hover grows a button slightly, press shrinks it, a soft click plays; touch shows the press effect. The selected tab is clearly marked.
  - **Not generic.** Thick darker outlines, rounded corners and a soft drop shadow, one consistent style on every screen.

## Way of working and release
- **Model routing (owner decision 2026-11-21, amended):** every task runs through the skill `cm2-task`.
  - Planning by tier (owner decision 2026-11-24; was always Opus 5.5 high): tier S runs without a plan, the implementer works from the backlog entry and stops on anything it may not decide. Tier M and MODEL get a plan from Opus 5.5, medium effort; tier L (saves, money, inventory, security, concurrency, bugs of unknown cause) from Opus 5.5, high effort. A plan settles every decision.
  - Implementing: by task, Sonnet 5.5 medium (tier S), Sonnet 5.5 high (tier M) or Opus 5.5 high (tier L). Implementers make no design decisions and stop on ambiguity.
  - Playtests: Haiku 5.5, through the Roblox Studio MCP (owner decision 2026-11-24; was Sonnet 5.5).
  - Review and commit: Sonnet 5.5, high effort (owner decision 2026-11-24; was Opus 5.5, medium).
  - 3D models: Opus 5.5, medium effort.
- **Testing:**
  - From now on, test in a private (unpublished) build.
  - A friends test with 2–5 players before the 1st Advent (Duo, invite code, purchases).
  - The owner's go/no-go is on 2026-11-28.
  - The owner publishes and creates products, following a checklist prepared by engineering.
  - No Studio FPS measurements and no world/art captures as test gates (owner decision 2026-11-25, PC-9 dropped): numeric and automated checks decide; performance is a goal, a performance task follows only a reported player-visible problem.

## Observe in the reference game (engineering task, not owner questions)
Starting cash and reputation of a new save; staff energy drain rate; the other events' contents; Elf Workshop contents; the first-time tutorial; the reference's Robux prices for items not yet seen.

---


## Decision authority
Owner supplies final 3D models gradually, via Studio models or FBX/GLB. Engineering owns code, UI, integration, testing, and minor gameplay decisions. Publication and paid actions require owner approval. Do not publish, enable monetization, purchase anything, or change paid products without approval.

## Product vision
Original Roblox Christmas-tree lot management simulator, gameplay as close as practical to screenshot references, with a distinct snowy map and more legible festive UI. The screenshots are behavioral/visual evidence, not access to proprietary source. Use original art and code.

## Nonnegotiable gameplay
- Core loop: acquire plot -> order trees -> delivery truck -> unload -> store/display -> attract NPC customers -> price/checkout -> earn cash and reputation -> upgrade and expand.
- Economy resembles screenshots where observed. Manual pricing plus optional automatic pricing. Demand depends on price, species, season (Christmas only), reputation, and stock variety. No rebirth/prestige and no offline earnings.
- Customers have preferences, budgets, patience and needs. Staff automate checkout, delivery and stocking; one-time hire cost only, no wages.
- Progression uses cash, reputation and prerequisite unlocks.
- ~~Multiplayer: personal plots in shared server AND collaborative company mode~~ (superseded 2026-11-21: Solo/Duo/Trio/Quad saves, see top); no player-to-player trading at launch.
- Persistent save of all progress, placements, configuration, statistics and bounded transaction history. Mobile, tablet, PC, console (gamepad after launch). ~~German and English~~ English at launch, more languages later (2026-11-21).
- Monetization: gamepasses, boosts and packs as in references — ~~disabled until separate approval~~ **active at launch (owner decision 2026-11-21, see top)**; loot boxes in version 2. Randomized paid items require policy review, disclosed probabilities, and jurisdictional checks. Never invent product IDs.
- Christmas-only seasonal events.

## Evidence tiers
OBSERVED: screenshot shows cash/reputation/lot status HUD, supplier, delivery capacity, prices, HQ, catalog, employees, quests, analytics, layout, shop, and winter roads/plots. OBSERVED price rule: Small 80%, Large 130% of Medium; Frasier 82, Noble 96, Blue Spruce 105 medium displayed; cashier hire 1200, lot worker 1800; Pavilion prerequisites lot expansion 1, 4 parking spaces, 250 reputation, 2500 cash.
INFERRED: exact customer AI algorithms, demand formula, delivery timing, NPC behavior, unlock schedule, detailed map dimensions, all progression values.
OWNER DECIDED: own map, ~~dual multiplayer modes~~ Solo/Duo/Trio/Quad saves, no offline pay, no wages, ~~DE/EN~~ English launch, persistent statistics, modern UI, Christmas-only events.
UNVERIFIED: original server code, full asset library, exact balancing and exact screenshot dimensions.

## Delivery milestones and acceptance
P0: working Rojo boot, pure shared economy/inventory modules, secure player action protocol, persistence baseline. Verify unit tests and Studio boot.
P1: personal plot allocation, supplier order, bounded delivery bays, delivery countdown, storage, stock zones, sale, save/rejoin. Verify no double spend/sale, negative quantities rejected.
P2: customer FSM, queue/checkout, price/demand, reputation, employees. Verify independent player plots and consistent balances.
P3: land/parking/HQ gates, catalog/decor, quests, analytics and leaderboards. Verify idempotent unlocks and bounded history.
P4: collaborative company ownership/permissions, full localization, responsive UI with gamepad and touch. Verify permissions and multiplayer race tests.
P5: owner assets, visual QA, Christmas events, optional paid products only after approval, release QA and publication only after approval.

## Engineering requirements
- Server-authoritative ledger and inventory, validated/rate-limited remotes, session-safe DataStore operations, schema migrations, autosave and shutdown save.
- No gameplay authority in client. All receipt grants server-side, idempotent and persistent.
- Collaboration: explicit company roles, atomic permission checks, no direct transfers, conflict-safe mutations.
- NPC counts and pathfinding bounded by server budget; all timed tasks have cancellation and cleanup.
- Save version, timestamps, counters, compact bounded history and data size limits.
- Localized string keys, not hardcoded UI prose.
- Models live in an asset registry with stable IDs and pivots; missing art must not block simulation.

## Remaining real blockers
1. Original screenshot binaries are not committed to repo; upload the prepared ZIP content to docs/references/roblox-game/ for Codex to inspect directly. Existing textual screenshot analysis is usable in the meantime.
2. Roblox Studio + Rojo runtime/playtests require an accessible Roblox development environment; GitHub writes alone cannot certify Studio execution.
3. Owner-created art is required for final visual completion, but not logic.
4. Robux product IDs, ownership and approval required to activate paid purchases; paid randomization also requires policy compliance.
5. Publication needs explicit owner approval and Roblox creator permissions.

## Working assumptions
Starting cash 84/reputation 90 are screenshot examples, not verified first-join defaults; use configurable test values. Initial implementation is personal-plot mode, followed by shared-company mode. Exact prices and demand are data-driven and tuned later. Do not silently present inferred rules as original facts.

# Delivery-role amendment — 2026-11-19

This section supersedes earlier statements that the owner supplies 3D models.

**Product Owner:** user; controls product vision and approval for publication and paid actions.
**Planner / Lead Architect:** ChatGPT; owns specifications, work breakdown, acceptance criteria, technical review and decision log.
**Implementer:** Claude Code; owns all implementation: Luau, UI, 3D models, original snowy world, asset pipeline, integration, automated and Studio tests, documentation and commit evidence.

Claude Code should prioritize original Roblox-native models made from Parts/MeshParts and scripted procedural construction where appropriate; external model generation may require tools unavailable to the agent. Never represent placeholder geometry as final art. Preserve the close-to-reference gameplay direction without copying protected assets. This amendment changes roles only, not product mechanics or approval requirements.

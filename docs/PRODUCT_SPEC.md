# Christmas Market 2 — binding product specification (2026-11-19)

## Decision authority
Owner supplies final 3D models gradually, via Studio models or FBX/GLB. Engineering owns code, UI, integration, testing, and minor gameplay decisions. Publication and paid actions require owner approval. Do not publish, enable monetization, purchase anything, or change paid products without approval.

## Product vision
Original Roblox Christmas-tree lot management simulator, gameplay as close as practical to screenshot references, with a distinct snowy map and more legible festive UI. The screenshots are behavioral/visual evidence, not access to proprietary source. Use original art and code.

## Nonnegotiable gameplay
- Core loop: acquire plot -> order trees -> delivery truck -> unload -> store/display -> attract NPC customers -> price/checkout -> earn cash and reputation -> upgrade and expand.
- Economy resembles screenshots where observed. Manual pricing plus optional automatic pricing. Demand depends on price, species, season (Christmas only), reputation, and stock variety. No rebirth/prestige and no offline earnings.
- Customers have preferences, budgets, patience and needs. Staff automate checkout, delivery and stocking; one-time hire cost only, no wages.
- Progression uses cash, reputation and prerequisite unlocks.
- Multiplayer: personal plots in shared server AND collaborative company mode; no player-to-player trading at launch.
- Persistent save of all progress, placements, configuration, statistics and bounded transaction history. Mobile, tablet, PC, console. German and English.
- Monetization: optional gamepasses, boosts and packs as in references, but **disabled until separate approval**. Randomized paid items require policy review, disclosed probabilities, and jurisdictional checks. Never invent product IDs.
- Christmas-only seasonal events.

## Evidence tiers
OBSERVED: screenshot shows cash/reputation/lot status HUD, supplier, delivery capacity, prices, HQ, catalog, employees, quests, analytics, layout, shop, and winter roads/plots. OBSERVED price rule: Small 80%, Large 130% of Medium; Frasier 82, Noble 96, Blue Spruce 105 medium displayed; cashier hire 1200, lot worker 1800; Pavilion prerequisites lot expansion 1, 4 parking spaces, 250 reputation, 2500 cash.
INFERRED: exact customer AI algorithms, demand formula, delivery timing, NPC behavior, unlock schedule, detailed map dimensions, all progression values.
OWNER DECIDED: own map, dual multiplayer modes, no offline pay, no wages, DE/EN, persistent statistics, modern UI, Christmas-only events.
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

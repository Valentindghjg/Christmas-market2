# Christmas Market 2 — Codex project entry

Goal: Build an original Roblox Studio/Luau Christmas tree lot simulator closely matching the gameplay and world structure visible in the reference screenshots.

## Source of truth
- [Implementation blueprint](docs/IMPLEMENTATION_PLAN.md)
- Reference screenshots should be placed under `docs/references/roblox-game/`. **They are not yet uploaded to this repository.** Obtain the ZIP from the project owner; do not invent or assume access to screenshots.
- The screenshots show UI and partial map views, not original game code, geometry, or hidden mechanics.

## Execution order
1. Establish Rojo-compatible Roblox Studio project layout and testing conventions.
2. Build graybox winter world and plots with original geometry.
3. Implement server-authoritative economy, inventory, suppliers, delivery bays, pricing and persistence.
4. Add customer NPC loop and checkout.
5. Add HQ, land, parking, employees, quests and decoration.
6. Match the visible UI on mobile and desktop.
7. Add original low-poly assets and tune visual fidelity against the screenshots.
8. Verify each mechanic in Studio and document gaps requiring original-game observation.

## Rules for Codex
- Treat screenshot observations separately from inferred behavior.
- Never fabricate unavailable source assets or imply exact replication from screenshots alone.
- Do not copy proprietary Roblox assets, scripts or branding without permission.
- Implement systems as testable modules, validate all purchases on server, and protect DataStore state.
- Work in small reviewed commits, keep a running progress log, and ask before monetization or irreversible changes.

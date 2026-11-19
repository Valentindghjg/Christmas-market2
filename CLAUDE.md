# CLAUDE.md — Christmas Market 2 implementation agent

You are the implementation engineer for this Roblox Studio / Luau game. The human is Product Owner; ChatGPT is planner, architect and reviewer. You implement **everything**, including original 3D models, map, UI, gameplay, integration, tests and documentation.

## Read before changing code
1. docs/PRODUCT_SPEC.md (owner decisions, latest amendments take precedence)
2. docs/DECISION_LOG.md (chronological changes)
3. docs/GAME_DESIGN.md
4. docs/TECHNICAL_ARCHITECTURE.md
5. docs/TEST_PLAN.md
6. docs/MODEL_INTEGRATION.md
7. docs/IMPLEMENTATION_PLAN.md and docs/PROGRESS.md

## Non-negotiables
- Commit all work to this repository in small logical commits. Never overwrite user changes.
- Build original Roblox models using Studio-compatible Parts/MeshParts and procedural geometry where appropriate. Never copy/rip third-party proprietary models, scripts or textures. You own 3D art; do not wait for the owner to provide it.
- Preserve screenshot-observed mechanics; distinguish OBSERVED, OWNER DECIDED and PROVISIONAL assumptions.
- Server-authoritative money, inventory, purchases, permissions and save data. Secure/rate-limit all remotes and make financial operations idempotent.
- No publication and no enabling/creating paid products without explicit Product Owner approval.
- Use Rojo, modular Luau, versioned schemas and reproducible tests.
- Keep docs/PROGRESS.md current with real evidence; never claim a Roblox Studio test if it wasn't run.
- If tooling prevents Studio execution, continue implementing code/tests and report the blocker precisely rather than stopping all progress.

## Immediate assignment: P0 -> P1
1. Audit existing code and fix correctness/security issues before expanding.
2. Configure a working Rojo project with reproducible lint/unit-test workflow; add tests for Economy, Inventory and BusinessState.
3. Implement versioned company state and session-safe DataStore loading/saving, with fail-closed behavior on load errors.
4. Implement plot allocation and a minimal original winter graybox map; build starter tent, supplier truck, tree models and checkout counter as original Roblox geometry.
5. Implement supplier quotes/orders, server-owned costs, delivery ETA, unloading, storage/display transitions and a simple customer checkout.
6. Create minimal usable bilingual UI and connect through validated server action protocol.
7. Validate purchase -> truck delivery -> unload -> display -> NPC checkout -> save/rejoin. Add tests for double spend, duplicate orders, invalid client costs, stock duplication and plot isolation.
8. Commit code, test results and exact remaining blockers; stop before any live Robux feature or publishing.

## Reporting format for planner review
- Commit SHA(s) and links
- Files changed
- Implemented gameplay and visible world elements
- Tests run (command/environment, PASS/FAIL/BLOCKED)
- Security/data-loss concerns
- Deviations from approved spec and assumptions
- Next smallest shippable task

Do not silently mark unimplemented features complete. Prefer a playable vertical slice over broad unfinished scaffolding.

# Christmas Market 2 — Roblox / Luau

An original Christmas-tree sales simulator based on screenshot-observed gameplay, with a distinct snowy world, personal and collaborative company modes, and a modern bilingual festive interface.

## Canonical documentation
- [Owner-approved product decisions](docs/PRODUCT_SPEC.md)
- [Detailed game design](docs/GAME_DESIGN.md)
- [Technical architecture](docs/TECHNICAL_ARCHITECTURE.md)
- [Testing and release gates](docs/TEST_PLAN.md)
- [Implementation milestones and screenshot evidence](docs/IMPLEMENTATION_PLAN.md)
- [3D model integration contract](docs/MODEL_INTEGRATION.md)
- [Decisions and ongoing GitHub sync policy](docs/DECISION_LOG.md)
- [Actual development progress](docs/PROGRESS.md)

## Current status
P0 (foundation) is complete; P1 (playable core) is in progress. The server-authoritative loop - supplier order -> truck delivery -> unload -> display -> NPC checkout -> autosave - exists as code with 85 headless contract checks, a generated winter graybox map and a minimal DE/EN HUD. It has **not yet been verified end-to-end in Roblox Studio** (see [PROGRESS](docs/PROGRESS.md) for what was and was not run). Reference screenshot binaries are still not committed (`docs/references/roblox-game/`). CC0 source models live in `assets/third_party/`; Studio-imported art under `ReplicatedStorage.ArtAssets` is not yet part of the Rojo project, so a fresh build uses primitive fallbacks.

## Repository layout
- `src/shared` - pure, client-safe modules (config, economy, schema, protocol, localization)
- `src/server` - bootstrap and authoritative services (`Services/`)
- `src/client` - HUD/UI controller; sends requests only
- `tests/studio/Cases` - unit-test cases, run by `tests/headless/run.luau` (Lune, CI) and `tests/studio/RunUnitTest.lua` (Studio)
- `assets/third_party` - CC0 source models with provenance README
- `docs` - specification, architecture, plans, progress and decision log

## Local development
1. Install [Rokit](https://github.com/rojo-rbx/rokit).
2. From the repository root, run `rojo serve default.project.json`. Rokit installs the pinned Rojo version from `rokit.toml` on first use.
3. In Roblox Studio, use the Rojo plugin to connect to `http://localhost:34872` and sync `default.project.json`.
4. Verify the project mapping with `rojo build default.project.json --output build.rbxlx`.
5. Before committing, run the same checks as CI: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau`.

The `Quality` GitHub Actions workflow runs formatting, linting, shared-module type checks, headless core unit tests and a Rojo build on pushes and pull requests. Run the CI unit-test suite locally with `lune run tests/headless/run.luau`.

Unit-test modules are mapped to `ServerStorage.UnitTest`. After connecting/reconnecting Rojo, start a Studio Play session and run `require(game:GetService("ServerStorage").UnitTest.RunUnitTest)()` in the server command bar or through the Studio MCP server console.

## Working agreement
Commit project-relevant decisions, specifications, code and verified test outcomes from active chat sessions to this repository and update canonical documents when decisions change. Never copy unrelated private chat data or credentials into this public repository. No background sync is implied. **Publication and paid actions require explicit owner approval.** Monetization stays disabled until then.

## Initial development sequence
1. Luau unit tests, secure command protocol, session-safe DataStore.
2. Personal plots, supplier orders, deliveries, stocking and sales.
3. NPC customers, staff, pricing and progression.
4. Collaborative companies, UI, localization, analytics and quests.
5. Owner assets, QA, event systems, approved monetization and release.

No proprietary Roblox game code or models should be copied without authorization.

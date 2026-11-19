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
Rojo scaffold and initial pure Luau business/inventory/localization modules exist. The game is **not yet playable or verified in Roblox Studio**. Reference screenshot binaries have **not yet been committed**; they should be uploaded under `docs/references/roblox-game/`. The owner supplies final 3D models gradually. Development can proceed with temporary invisible placeholders for interactions.

## Local development
1. Install [Rokit](https://github.com/rojo-rbx/rokit).
2. From the repository root, run `rojo serve default.project.json`. Rokit installs the pinned Rojo version from `rokit.toml` on first use.
3. In Roblox Studio, use the Rojo plugin to connect to `http://localhost:34872` and sync `default.project.json`.
4. Verify the project mapping with `rojo build default.project.json --output build.rbxlx`.

The `Quality` GitHub Actions workflow runs the same formatter, linter and Rojo build checks on pushes and pull requests.

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

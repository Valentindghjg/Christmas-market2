# Skills policy

Moved here from `CLAUDE.md` unchanged (owner decision 2026-11-27, usage: `CLAUDE.md` is sent with every request and every agent start). The planner reads this file for every plan; the main chat reads it when planning (`cm2-plan`/`game-plan`). It binds as `CLAUDE.md` does.

## Skills
29 Roblox skills from `TabooHarmony/roblox-brain` in `.claude/skills/` (list and pins: `skills-lock.json`), each a `SKILL.md` plus `references/full.md`.

### Using the skills (mandatory)
- The planner loads `roblox-collaboration-mode` first (with the precedence rules below), then each domain skill the change touches (`SKILL.md`; `references/full.md` only when needed), and copies the applicable checks into the plan's "Skill checks"; the other agents read those lines instead of the skills (the implementer of a tier S task without a plan reads the `SKILL.md` files itself). `CLAUDE.md` is in every agent's context already; agents do not read it again.
- Task → skills:

| Task | Skills |
|---|---|
| Save schema, migration or persisted fields | roblox-data, roblox-server-data |
| New or changed actions/remotes, money, inventory | roblox-networking, roblox-security |
| NPC customers, cars, pathing | roblox-npc-ai, roblox-performance |
| World geometry and models | cm2-modeling (Blender kit), roblox-building, roblox-lighting |
| UI | roblox-gui, roblox-input, roblox-localization |
| Luau code | roblox-luau-core, roblox-luau-patterns, roblox-luau-types |
| Module/service placement | roblox-architecture |
| Tooling, tests, CI | roblox-tooling |
| Economy and balance | roblox-game-design |
| Before any release | roblox-publish-checklist |

- Apply each loaded skill's checks as acceptance criteria in addition to the ticket's. In the planner report, list the skills used per task under "Tests run" or "Deviations".

**Bei Widersprüchen gilt diese CLAUDE.md vor den Skills**, and so do the documents it names (PRODUCT_SPEC, DECISION_LOG, TECHNICAL_ARCHITECTURE, MODEL_INTEGRATION). Known conflicts (skill names without `roblox-`), with the rule that applies here:
1. **Working modes** (collaboration-mode infers peer/autonomous mode): "Continuous execution"; carry approved milestones through without waiting for replies.
2. **Approval gates** (collaboration-mode: approval for DataStore schemas, migrations, purchases, publishing): only publication and paid products/actions need Product Owner approval; versioned schemas and migrations are part of the assignment (P0/P1 step 3; DECISION_LOG: engineering decides technical details).
3. **Asking vs. deciding** (collaboration-mode: ask once on conflicts, leave hard choices to the user): make technical and minor gameplay decisions without further questions (DECISION_LOG) and record them; record blockers and continue with independent work.
4. **Skill precedence** (collaboration-mode claims it on process): this CLAUDE.md first, then the skills.
5. **Asset sources** (building, studio-mcp: Toolbox/Creator Store, MCP insert or generate): original models from Parts/MeshParts/procedural geometry; never copy third-party proprietary models; no unlicensed Toolbox assets (MODEL_INTEGRATION); licence-clear sources need recorded provenance (CC0 precedent: `assets/third_party/`, DECISION_LOG 2026-11-21).
6. **Source of truth** (studio-mcp, building: edit in Studio via MCP): Rojo plus this repository; all work is committed; a Studio-only change is not part of the project.
7. **Offline earnings** (game-design, growth-design references): no offline income (PRODUCT_SPEC, owner decision).
8. **Monetization** (monetization, growth-design, player-psychology: consumables, early boosts, price ladders, paid RNG): the owner approved an active Robux shop at launch with the reference's products and prices (PRODUCT_SPEC 2026-11-21); the owner creates products and publishes; paid randomized items only from version 2, with policy review and disclosed odds.
9. **Events** (growth-design, game-design: recurring LiveOps): Christmas-only seasonal events (PRODUCT_SPEC).
10. **Localization** (localization: LocalizationTables): English-only launch through string keys in `src/shared/Localization.lua`, relying on Roblox auto-translation; an in-game language switch comes later (PRODUCT_SPEC 2026-11-21).
11. **Remote style** (networking: RemoteEvents, short RemoteFunctions): the versioned request/response action protocol `{ok, errorCode, revision, data}` (TECHNICAL_ARCHITECTURE section 3).
12. **Code layout** (architecture: by feature): TECHNICAL_ARCHITECTURE section 1 (`src/shared`, `src/server/Services`, `src/client`); the skill itself advises against reorganizing a working repository.

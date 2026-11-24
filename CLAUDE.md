# CLAUDE.md — Christmas Market 2 implementation agent

You are the implementation engineer for this Roblox Studio / Luau game. The human is Product Owner; ChatGPT is planner, architect and reviewer. You implement **everything**, including original 3D models, map, UI, gameplay, integration, tests and documentation.

## Read before changing code
Read what the task needs, not every file in full (owner decision 2026-11-22, token budget). Use the headings and `grep` to find the sections.
1. docs/PRODUCT_SPEC.md: the owner decisions at the top, plus the sections the task touches (owner decisions, latest amendments take precedence)
2. docs/DECISION_LOG.md: the entries that mention the task ID or its topic, plus the latest three entries
3. docs/GAME_DESIGN.md, docs/TECHNICAL_ARCHITECTURE.md, docs/TEST_PLAN.md, docs/MODEL_INTEGRATION.md: the sections the task touches
4. docs/CLAUDE_BACKLOG.md: "Für den Owner am PC", the launch order and the task's own entry
5. docs/PROGRESS.md: the latest entries; older ones are in `docs/archive/` and only needed when a task depends on that history
6. docs/IMPLEMENTATION_PLAN.md: only for screenshot-observed mechanics the task touches
Read a document in full only when the task changes its subject as a whole (for example a spec rewrite or a full backlog refresh).

## Non-negotiables
- Commit all work to this repository in small logical commits and push each commit to `origin` right away (owner decision 2026-11-22). Never force-push. Never overwrite user changes.
- Build original Roblox models using Studio-compatible Parts/MeshParts and procedural geometry where appropriate. Never copy/rip third-party proprietary models, scripts or textures. You own 3D art; do not wait for the owner to provide it.
- Preserve screenshot-observed mechanics; distinguish OBSERVED, OWNER DECIDED and PROVISIONAL assumptions.
- Server-authoritative money, inventory, purchases, permissions and save data. Secure/rate-limit all remotes and make financial operations idempotent.
- No publication and no enabling/creating paid products without explicit Product Owner approval.
- Use Rojo, modular Luau, versioned schemas and reproducible tests.
- Keep docs/PROGRESS.md current with real evidence; never claim a Roblox Studio test if it wasn't run.
- If tooling prevents Studio execution, continue implementing code/tests and report the blocker precisely rather than stopping all progress.

## Continuous execution
- By default, carry the project through all approved milestones. Start with P0 and P1 below, then work through the remaining milestones in `docs/CLAUDE_BACKLOG.md` in dependency order. Respect any narrower scope the Product Owner explicitly sets.
- After each task, verify its acceptance criteria, record the results in `docs/PROGRESS.md`, commit the work, and immediately start the next ready task in the same session. Keep working through progress updates, reviews, and milestone reports without waiting for a reply or confirmation.
- When there is no ready ticket, compare the current implementation and verified results against the approved product spec, milestone gates, and test plan. Pick the highest-priority gap you can work on, including missing features, integration, bug fixes, and verification. Create a follow-up task in `docs/CLAUDE_BACKLOG.md` with its goal, dependencies, and verifiable acceptance criteria, then immediately start implementing or verifying it. Repeat this cycle without waiting for the Product Owner to assign work. An empty backlog triggers this check.
- If a task is blocked, try to resolve the blocker. If it persists, record it and continue with independent work, creating a follow-up task when needed. Publication and paid actions require explicit Product Owner approval.
- End the run only when all approved requirements in scope are implemented and verified, the Product Owner explicitly asks you to stop, or a concrete blocker prevents all remaining in-scope work. Report any unresolved blockers and what would let you resume.
- The skill **`hasseln`** (`.claude/skills/hasseln/SKILL.md`, owner decision 2026-11-22) carries out this loop: task after task through `cm2-task`, one session, no pauses at milestones, every commit pushed. On a blocker it secures the work (commit to `main` if checks and review pass, else a `wip/<ID>` branch), the planner records a machine-readable entry in "Für den Owner am PC" at the top of `docs/CLAUDE_BACKLOG.md`, and the run goes on with independent work. Whenever a run ends before everything is done, the planner refreshes the whole backlog as if the owner had resolved every PC entry. Triggers: `/hasseln`, "durcharbeiten", "mach weiter", "weiter", "hustle".

## First milestones: P0 -> P1
1. Audit existing code and fix correctness/security issues before expanding.
2. Configure a working Rojo project with reproducible lint/unit-test workflow; add tests for Economy, Inventory and BusinessState.
3. Implement versioned company state and session-safe DataStore loading/saving, with fail-closed behavior on load errors.
4. Implement plot allocation and a minimal original winter graybox map; build starter tent, supplier truck, tree models and checkout counter as original Roblox geometry.
5. Implement supplier quotes/orders, server-owned costs, delivery ETA, unloading, storage/display transitions and a simple customer checkout.
6. Create minimal usable bilingual UI and connect through validated server action protocol.
7. Validate purchase -> truck delivery -> unload -> display -> NPC checkout -> save/rejoin. Add tests for double spend, duplicate orders, invalid client costs, stock duplication and plot isolation.
8. Commit code and record test results and any blockers, then continue under the continuous execution rules above.

## Reporting format for planner review
- Commit SHA(s) and links
- Files changed
- Implemented gameplay and visible world elements
- Tests run (command/environment, PASS/FAIL/BLOCKED)
- Security/data-loss concerns
- Deviations from approved spec and assumptions
- Next task started, including any follow-up task created

Do not silently mark unimplemented features complete. Prefer a playable vertical slice over broad unfinished scaffolding.

## Plan, implement, verify (model routing)
Owner decision 2026-11-21 (PRODUCT_SPEC). Every task that changes code, tests, models or the map runs through the skill **`cm2-task`** (`.claude/skills/cm2-task/SKILL.md`). Each step runs in its own agent; the agent file in `.claude/agents/` fixes model and effort:

| Step | Agent | Model, effort |
|---|---|---|
| Plan `docs/plans/<ID>.md` from `docs/plans/TEMPLATE.md`; the plan settles every decision and sets the implementer tier | `planner` | Opus 5.5, high |
| Implement, tier S (patterns, UI, config, docs, tests) | `implementer` | Sonnet 5.5, medium |
| Implement, tier M (multi-service features, non-trivial logic) | `implementer-high` | Sonnet 5.5, high |
| Implement, tier L (saves, money, inventory, security, concurrency) | `implementer-opus` | Opus 5.5, high |
| 3D models and map (tier MODEL), self-review against `docs/art/quality-reference/` | `modeler` | Opus 5.5, medium |
| Playtest in Studio through the Roblox Studio MCP | `playtester` | Sonnet 5.5, medium |
| Review the diff against the plan, run the checks, record PROGRESS.md, commit | `reviewer` | Sonnet 5.5, high |

- The main session only orchestrates. It does not write plans, code, models or commits itself.
- Start the agents with `subagent_type` only. Never pass `model` or `effort` to the Agent tool, because that overrides the agent file.
- Implementers decide only minor details themselves (names of locals and private helpers, formatting, lint fixes; rule 3 in `.claude/agents/implementer.md`) and stop with a report on any other ambiguity; the planner amends the plan.
- Studio playtests are batched: now for tier L or MODEL, saves, money, inventory, purchases, world geometry or a milestone's last task, otherwise every third task through the queue "Studio-Test ausstehend" in `docs/CLAUDE_BACKLOG.md` (skill `cm2-task`, step 3). Headless checks still run for every task.
- **Automatic model switch in the chat:** decide from each message whether it is planning or work.
  - Planning (design, decisions, spec, backlog, priorities, balancing, "how should this work"): invoke the skill `cm2-plan` first. It switches the chat to Opus 5.5, high effort.
  - Work (implement, fix, build models, playtest, carry out a plan): invoke the skill `cm2-task`. It switches the chat to Sonnet 5.5 for orchestrating, and each agent then runs on its own model from the table.
  - Working through the backlog ("durcharbeiten", "mach weiter", "weiter", "hustle"): invoke the skill `hasseln`. It runs `cm2-task` for each task in turn.
  - Short questions and conversation need neither skill and use the session model.
  - The switch lasts for the current turn. Each new message is classified again.
  - If a switch is not applied (`availableModels` or auto mode), the chat stays on its model and the skill raises the effort to high. Exception: if planning would need Opus but the chat stays on Sonnet, `cm2-plan` stops and asks the user to switch to Opus.
- **Hooks (`.claude/settings.json`, scripts in `.claude/hooks/`):**
  - `route-prompt.js` (UserPromptSubmit) reminds the chat on every message to classify it and to invoke `cm2-plan`, `cm2-task` or `hasseln`. A hook cannot switch the model itself; only the skills can.
  - `guard-main-edits.js` (PreToolUse on Edit, Write and NotebookEdit) blocks the main chat from writing `src/`, `tests/`, `assets/` and `docs/plans/`. Subagents are allowed. Set `CM2_ALLOW_MAIN_EDITS=1` to switch the guard off.
  - Shell commands are not guarded.

## Skills

Project-level Roblox skills from `TabooHarmony/roblox-brain` are installed under `.claude/skills/` (29 skills, pinned in `skills-lock.json`). Each skill is a `SKILL.md` plus `references/full.md`.

- **Core:** roblox-collaboration-mode, roblox-architecture, roblox-data, roblox-server-data, roblox-luau-core, roblox-luau-patterns, roblox-luau-types, roblox-networking, roblox-performance, roblox-security
- **Gameplay:** roblox-animation-vfx, roblox-audio, roblox-building, roblox-camera, roblox-gui, roblox-input, roblox-lighting, roblox-localization, roblox-npc-ai, roblox-physics
- **Design:** roblox-analytics, roblox-game-design, roblox-growth-design, roblox-monetization, roblox-player-psychology
- **Tools:** roblox-cloud, roblox-publish-checklist, roblox-studio-mcp, roblox-tooling

### Using the skills (mandatory)
- Before every Roblox task, load `roblox-collaboration-mode` first (with the precedence rules below), then each domain skill the change touches. Read the skill's `SKILL.md`. Open `references/full.md` when the change needs detail beyond the quick reference.
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

**Bei Widersprüchen gilt diese CLAUDE.md vor den Skills.** The same applies to the documents it names (PRODUCT_SPEC, DECISION_LOG, TECHNICAL_ARCHITECTURE, MODEL_INTEGRATION). Known conflicts and the rule that applies:

1. **Working modes (roblox-collaboration-mode):** the skill infers a peer or autonomous mode from the user's phrasing. Applies here: "Continuous execution" above; carry approved milestones through without waiting for replies.
2. **Approval gates (roblox-collaboration-mode):** the skill requires explicit approval for DataStore schemas, migrations, purchases and publishing in every mode. Applies here: only publication and paid products/actions need Product Owner approval; versioned schemas and migrations are part of the assignment (P0/P1 step 3, DECISION_LOG: engineering decides technical details).
3. **Asking vs. deciding (roblox-collaboration-mode):** the skill says to ask once when instructions conflict and to leave hard choices to the user. Applies here: technical and minor gameplay decisions are made without further questions (DECISION_LOG); record them, and record blockers and continue with independent work.
4. **Skill precedence (roblox-collaboration-mode):** the skill claims precedence over other skills on process. Applies here: this CLAUDE.md first, then the skills.
5. **Asset sources (roblox-building, roblox-studio-mcp):** the skills search Toolbox/Creator Store first and insert or generate assets via MCP. Applies here: build original models from Parts/MeshParts/procedural geometry; never copy third-party proprietary models; no unlicensed Toolbox assets (MODEL_INTEGRATION). Licence-clear sources need recorded provenance (CC0 precedent: `assets/third_party/`, DECISION_LOG 2026-11-21).
6. **Source of truth (roblox-studio-mcp, roblox-building):** the skills edit scripts and scenes directly in Studio via MCP. Applies here: Rojo plus this repository are the source of truth and all work is committed; a change that exists only in Studio is not part of the project.
7. **Offline earnings (roblox-game-design, roblox-growth-design references):** they recommend offline earnings and "2x offline earnings" products for plot games. Applies here: no offline income (PRODUCT_SPEC, owner decision).
8. **Monetization (roblox-monetization, roblox-growth-design, roblox-player-psychology):** consumables, premium boosts in the first minute, price ladders and paid RNG. Applies here: the owner approved an active Robux shop at launch with the reference's products and prices (PRODUCT_SPEC 2026-11-21); the owner creates products and publishes; paid randomized items only from version 2, with policy review and disclosed odds.
9. **Events (roblox-growth-design, roblox-game-design):** recurring LiveOps event cadence. Applies here: Christmas-only seasonal events (PRODUCT_SPEC).
10. **Localization (roblox-localization):** LocalizationTables and Roblox auto-translation. Applies here: English-only launch through string keys in `src/shared/Localization.lua`, relying on Roblox auto-translation; an in-game language switch comes later (PRODUCT_SPEC 2026-11-21).
11. **Remote style (roblox-networking):** the skill prefers RemoteEvents and short RemoteFunctions. Applies here: the versioned request/response action protocol `{ok, errorCode, revision, data}` (TECHNICAL_ARCHITECTURE section 3).
12. **Code layout (roblox-architecture):** the skill favours grouping by feature. Applies here: the layout in TECHNICAL_ARCHITECTURE section 1 (`src/shared`, `src/server/Services`, `src/client`). The skill itself advises against reorganizing a working repository.

# CLAUDE.md — Christmas Market 2 implementation agent

You are the implementation engineer for this Roblox Studio / Luau game. The human is Product Owner; ChatGPT is planner, architect and reviewer. You implement **everything**: original 3D models, map, UI, gameplay, integration, tests and documentation.

## Read before changing code
Read what the task needs, not every file in full (owner decision 2026-11-22, token budget); find sections by headings and `grep`.
1. docs/PRODUCT_SPEC.md: the owner decisions at the top and the sections the task touches (owner decisions and the latest amendments take precedence)
2. docs/DECISION_LOG.md: entries naming the task ID or its topic, plus the latest three; older entries in `docs/archive/DECISION_LOG_*.md` stay binding, so grep there too
3. docs/GAME_DESIGN.md, TECHNICAL_ARCHITECTURE.md, TEST_PLAN.md, MODEL_INTEGRATION.md: the sections the task touches
4. docs/CLAUDE_BACKLOG.md: "Für den Owner am PC", the launch order and the task's own entry
5. docs/PROGRESS.md: the latest entries; older ones in `docs/archive/` only when the task depends on that history
6. docs/IMPLEMENTATION_PLAN.md: only for screenshot-observed mechanics the task touches
Read a document in full only when the task changes its whole subject (e.g. a spec rewrite or a full backlog refresh).

## Non-negotiables
- Commit all work to this repository in small logical commits and push each commit to `origin` right away (owner decision 2026-11-22). Never force-push. Never overwrite user changes.
- Build original models from Studio-compatible Parts/MeshParts and procedural geometry where appropriate. Never copy/rip third-party proprietary models, scripts or textures. You own 3D art; do not wait for the owner to provide it.
- Preserve screenshot-observed mechanics; distinguish OBSERVED, OWNER DECIDED and PROVISIONAL assumptions.
- Server-authoritative money, inventory, purchases, permissions and save data. Secure/rate-limit all remotes and make financial operations idempotent.
- No publication and no enabling/creating paid products without explicit Product Owner approval.
- Use Rojo, modular Luau, versioned schemas and reproducible tests.
- Keep docs/PROGRESS.md current with real evidence; never claim a Roblox Studio test that was not run.
- If tooling prevents Studio execution, keep implementing code/tests and report the blocker precisely; do not stop all progress.

## Continuous execution
- By default carry the project through all approved milestones: P0 and P1 below first, then the remaining milestones in `docs/CLAUDE_BACKLOG.md` in dependency order. Respect any narrower scope the Product Owner explicitly sets.
- After each task: verify its acceptance criteria, record results in `docs/PROGRESS.md`, commit, and start the next ready task in the same session at once. Do not wait for a reply or confirmation after progress updates, reviews or milestone reports.
- No ready ticket (an empty backlog too): compare implementation and verified results with the approved spec, milestone gates and test plan; pick the highest-priority gap you can work on (missing features, integration, bug fixes, verification); add a follow-up task to `docs/CLAUDE_BACKLOG.md` with goal, dependencies and verifiable acceptance criteria; start it immediately. Repeat without waiting for the Product Owner to assign work.
- Blocked task: try to resolve the blocker; if it persists, record it and continue with independent work, creating a follow-up task when needed. Publication and paid actions require explicit Product Owner approval.
- End the run only when all approved requirements in scope are implemented and verified, the Product Owner explicitly asks you to stop, or a concrete blocker prevents all remaining in-scope work. Report unresolved blockers and what would let you resume.
- The skill **`hasseln`** (owner decision 2026-11-22; procedure: `.claude/skills/hasseln/SKILL.md`) runs this loop in one session through `cm2-task` without milestone pauses, pushes every commit, secures blocked work (`main` or a `wip/<ID>` branch), has the planner record it in "Für den Owner am PC" (`docs/CLAUDE_BACKLOG.md`) and goes on; a run ending early ends with a full backlog refresh. Triggers: `/hasseln`, "durcharbeiten", "mach weiter", "weiter", "hustle".

## First milestones: P0 -> P1
1. Audit existing code; fix correctness/security issues before expanding.
2. A working Rojo project with a reproducible lint/unit-test workflow; tests for Economy, Inventory and BusinessState.
3. Versioned company state and session-safe DataStore loading/saving, fail-closed on load errors.
4. Plot allocation and a minimal original winter graybox map; starter tent, supplier truck, tree models and checkout counter as original Roblox geometry.
5. Supplier quotes/orders, server-owned costs, delivery ETA, unloading, storage/display transitions and a simple customer checkout.
6. A minimal usable bilingual UI, connected through the validated server action protocol.
7. Validate purchase -> truck delivery -> unload -> display -> NPC checkout -> save/rejoin. Tests for double spend, duplicate orders, invalid client costs, stock duplication and plot isolation.
8. Commit code, record test results and any blockers, then continue under "Continuous execution".

## Reporting format for planner review
Commit SHA(s) and links; files changed; implemented gameplay and visible world elements; tests run (command/environment, PASS/FAIL/BLOCKED); security/data-loss concerns; deviations from approved spec and assumptions; next task started, including any follow-up task created.

Do not silently mark unimplemented features complete. Prefer a playable vertical slice over broad unfinished scaffolding.

## Plan, implement, verify (model routing)
Owner decision 2026-11-21 (PRODUCT_SPEC). Every task that changes code, tests, models or the map runs through the skill **`cm2-task`**; each step runs in its own agent, whose file in `.claude/agents/` fixes model and effort. The binding routing table (agent, model and effort per step; tier S runs without a plan) is in `.claude/skills/cm2-task/SKILL.md`, the tier rules under "Implementer tier" in `docs/plans/TEMPLATE.md`, each agent's duties in its file.
- The main session only orchestrates; it writes no plans, code, models or commits.
- Start agents with `subagent_type` only; never pass `model` or `effort` (that overrides the agent file).
- Implementers decide only minor details (rule 3 in `.claude/agents/implementer.md`: local and private helper names, formatting, lint fixes) and stop with a report on any other ambiguity; the planner amends the plan.
- Studio playtests are batched (owner decision 2026-11-26, speed and usage): now for saves, money, inventory, purchases, world wiring or a milestone's last task, else every fifth task via the queue "Studio-Test ausstehend" in `docs/CLAUDE_BACKLOG.md` (`cm2-task` step 3). A playtest is the smoke run plus the task's own steps; the full run only at the end of a hasseln run, for QA and release tasks and for runner or core-loop changes. Headless checks run for every task; agents print only failures and the summary.
- **Automatic model switch:** classify each chat message; the switch lasts for that turn. Planning (design, decisions, spec, backlog, priorities, balancing, "how should this work"): invoke `cm2-plan` first (Opus 5.5, high). Work (implement, fix, build models, playtest, carry out a plan): `cm2-task` (Sonnet 5.5 orchestrates, each agent on its own model). Backlog run (the `hasseln` triggers): `hasseln`, which runs `cm2-task` per task. Short questions and conversation: neither, the session model. Switch not applied (`availableModels` or auto mode): the chat keeps its model and the skill raises effort to high, except that `cm2-plan` stops and asks the user to switch to Opus when the chat stays on Sonnet.
- **Hooks** (`.claude/settings.json`, scripts in `.claude/hooks/`):
  - `route-prompt.js` (UserPromptSubmit) reminds the chat on every message to classify it and invoke `cm2-plan`, `cm2-task` or `hasseln`; only the skills can switch the model.
  - `guard-main-edits.js` (PreToolUse on Edit, Write, NotebookEdit) blocks the main chat from writing `src/`, `tests/`, `assets/` and `docs/plans/`. Subagents are allowed. `CM2_ALLOW_MAIN_EDITS=1` switches it off.
  - Shell commands are not guarded.

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

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
- By default carry the project through all approved milestones in `docs/CLAUDE_BACKLOG.md` in dependency order. Respect any narrower scope the Product Owner explicitly sets.
- After each task: verify its acceptance criteria, record results in `docs/PROGRESS.md`, commit, and start the next ready task in the same session at once. Do not wait for a reply or confirmation after progress updates, reviews or milestone reports.
- No ready ticket (an empty backlog too): compare implementation and verified results with the approved spec, milestone gates and test plan; pick the highest-priority gap you can work on (missing features, integration, bug fixes, verification); add a follow-up task to `docs/CLAUDE_BACKLOG.md` with goal, dependencies and verifiable acceptance criteria; start it immediately. Repeat without waiting for the Product Owner to assign work.
- Blocked task: try to resolve the blocker; if it persists, record it and continue with independent work, creating a follow-up task when needed. Publication and paid actions require explicit Product Owner approval.
- End the run only when all approved requirements in scope are implemented and verified, the Product Owner explicitly asks you to stop, or a concrete blocker prevents all remaining in-scope work. Report unresolved blockers and what would let you resume.
- The skill **`hasseln`** (owner decision 2026-11-22; procedure: `.claude/skills/hasseln/SKILL.md`) runs this loop in one session through `cm2-task` without milestone pauses, pushes every commit, secures blocked work (`main` or a `wip/<ID>` branch), has the planner record it in "Für den Owner am PC" (`docs/CLAUDE_BACKLOG.md`) and goes on; a run ending early ends with a full backlog refresh. Triggers: `/hasseln`, "durcharbeiten", "mach weiter", "weiter", "hustle".

## First milestones
P0 and P1 are done; their list is in git history (CLAUDE.md before 2026-11-27).

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
- **Hooks** (`.claude/hooks/`): `route-prompt.js` reminds the chat to classify each message; `guard-main-edits.js` blocks the main chat from writing `src/`, `tests/`, `assets/` and `docs/plans/` (subagents may; `CM2_ALLOW_MAIN_EDITS=1` turns it off). Shell commands are not guarded.

## Skills
29 Roblox skills from `TabooHarmony/roblox-brain` in `.claude/skills/` (pins: `skills-lock.json`). They are not model-invocable (`skillOverrides` in `.claude/settings.json`, owner decision 2026-11-27, usage): the planner reads them by path, as `docs/SKILLS_POLICY.md` says (which skills per task, how their checks enter the plan's "Skill checks", and the known conflicts between skills and this project). This CLAUDE.md and the documents it names win over the skills. Rules for every agent: original models only, no unlicensed Toolbox assets, licence-clear sources with recorded provenance; Rojo plus this repository are the source of truth (a Studio-only change is not part of the project); player text only through string keys in `src/shared/Localization.lua` (English-only launch); remotes use the versioned action protocol `{ok, errorCode, revision, data}`.

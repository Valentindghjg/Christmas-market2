---
name: cm2-plan
description: Switches this chat to Opus 5.5 at high effort for planning in Christmas Market 2. Invoke it first, before answering, as soon as the user wants to plan, design or decide something - a feature, mechanic, architecture, spec, backlog, priorities, balancing, art direction, a workflow, or "how should this work". Not for doing the work; that is cm2-task.
model: claude-opus-5-5
effort: high
argument-hint: <what to plan>
---

# cm2-plan: planning on Opus 5.5, high effort

This turn now runs on Opus 5.5 at high effort. Planning topic: $ARGUMENTS

1. Load `roblox-collaboration-mode` and the domain skills the topic touches (table in `CLAUDE.md`).
2. Plan with the user in this chat. Read the relevant docs and code before you suggest anything. Settle technical and minor gameplay decisions yourself; the owner decides only what `CLAUDE.md` reserves for the owner.
3. Write the result where it belongs:
   - Owner decisions go to `docs/PRODUCT_SPEC.md` and get a dated entry in `docs/DECISION_LOG.md`.
   - New or changed tasks go to `docs/CLAUDE_BACKLOG.md`, with the goal, dependencies and verifiable acceptance criteria.
   - A complete task plan `docs/plans/<ID>.md` is written by the `planner` agent. Start it with `subagent_type: planner` only, and do not pass `model` or `effort`.
4. Commit documentation changes in small logical commits.
5. As soon as the user wants the planned work carried out, invoke the skill `cm2-task`. It switches the chat back to Sonnet and starts the right agent for each step.

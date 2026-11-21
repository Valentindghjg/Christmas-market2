---
name: cm2-task
description: Runs one Christmas Market 2 task (code, bug fix or 3D model) through the fixed model pipeline - planner (Opus 5.5 high), implementer tier (Sonnet 5.5 medium, Sonnet 5.5 high or Opus 5.5 high) or modeler (Opus 5.5 medium), playtester (Sonnet 5.5 medium), reviewer (Opus 5.5 medium, commits). Use for every task that changes code, tests, models or the map in this repository, including each ticket of the continuous-execution loop.
model: claude-sonnet-5-5
effort: medium
argument-hint: <backlog task ID or short task description>
---

# cm2-task: plan, implement, playtest, review

This chat now runs on Sonnet 5.5 at medium effort for orchestrating. Each step below gets its own model from its agent file.

Task: $ARGUMENTS
If no task is given, pick the next ready task under the "Continuous execution" rules in `CLAUDE.md`.

Every step runs in its own agent. The agent file fixes the model and effort, so the routing below is binding:

| Step | Agent (`subagent_type`) | Model, effort |
|---|---|---|
| Plan | `planner` | Opus 5.5, high |
| Implement, tier S | `implementer` | Sonnet 5.5, medium |
| Implement, tier M | `implementer-high` | Sonnet 5.5, high |
| Implement, tier L | `implementer-opus` | Opus 5.5, high |
| 3D model or map, tier MODEL | `modeler` | Opus 5.5, medium |
| Playtest | `playtester` | Sonnet 5.5, medium |
| Review and commit | `reviewer` | Opus 5.5, medium |

## Rules for the main session
- Start each step with the Agent tool and only `subagent_type`, `description` and `prompt`. **Never pass `model` or `effort`**; they would override the agent file.
- Never use another agent type for these steps. If one of the agents above is not available, stop and report that.
- Do not write plans, code, tests, models or commits yourself. Pass reports between the agents and keep the task list current.
- Run the steps one after another; each one needs the previous result.

## Steps
1. **Plan.** Start `planner` with the task. It writes `docs/plans/<ID>.md` and reports the tier.
   - If it reports an open owner decision, record it as a blocker in `docs/CLAUDE_BACKLOG.md` through a new `planner` run, and continue with the next ready task.
2. **Implement.** Read the "Implementer tier" section of the plan. Start the matching agent from the table with the plan path.
   - The tier is missing or not exactly S, M, L or MODEL: send the plan back to `planner` to fix it.
   - The implementer or modeler stops with a question: start `planner` with the plan path and the question so it amends the plan, then rerun the same tier. After two rounds on the same question, record a blocker and continue with the next task.
3. **Playtest.** If the plan has playtest steps, start `playtester` with the plan path.
   - A step fails: start `planner` with the plan path and the playtest report to add fix steps, then go back to step 2.
   - Studio or its MCP is not available: keep the report (BLOCKED) and go on to step 4.
4. **Review and commit.** Start `reviewer` with the plan path and every report from steps 2 and 3.
   - The result is "RE-PLAN NEEDED": go back to step 1 with the findings.
   - The result is "COMMITTED": the task is done.
5. **Report** in the "Reporting format for planner review" from `CLAUDE.md`, including which agent ran each step. Then continue with the next ready task.

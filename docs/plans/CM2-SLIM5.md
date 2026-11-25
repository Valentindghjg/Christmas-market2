# CM2-SLIM5 — CLAUDE.md to 12 KB, wording only

Written by: `planner` (Opus 5.5, medium). Implemented by: `implementer` (tier S). Reviewed and committed by: `reviewer` (Sonnet 5.5, high). Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
`CLAUDE.md` shrinks from 15,707 B to 12,241 B (<= 12,288) with no binding rule dropped or changed in meaning. Rules stated in full elsewhere become pointers.

## Source of truth
Backlog entry CM2-SLIM5 (`docs/CLAUDE_BACKLOG.md`, follow-ups 2026-11-25); recurring task CM2-SLIM (owner decision 2026-11-24).

## Implementer tier
Tier: S. Reason: docs-only, verbatim file replacement from a ready text; no code, save, money or remote change.

## Skills to load
roblox-collaboration-mode (only rule set referenced; no domain skill: no Roblox code changes).

## Files
| File | New/Change | Purpose |
|---|---|---|
| `docs/plans/CM2-SLIM5-CLAUDE.md` | consumed (moved) | ready new text of `CLAUDE.md`, 12,241 B, LF line endings, UTF-8 without BOM |
| `CLAUDE.md` | Change | replaced by the file above, byte for byte |

The new text lives in a separate file (not inline here) so the copy is byte-exact and this plan stays within the S size budget.

## Steps
1. `mv docs/plans/CM2-SLIM5-CLAUDE.md CLAUDE.md` (overwrite). Do not edit the text; no reformatting, no line-ending conversion.
2. `wc -c CLAUDE.md` → must print `12241`. Any other number: stop and report.
3. `grep -n "CLAUDE" .claude/hooks/*.js` → only comments and the deny-reason string name `CLAUDE.md` and "Plan, implement, verify"; neither reads the file. The headings that other files cite stay unchanged in the new text: "Read before changing code" (planner.md), "Continuous execution" (cm2-task), "Reporting format for planner review" (cm2-task, hasseln), "Plan, implement, verify" (route-prompt.js), the skill table (implementer.md). Verify with `grep -n "^## \|^### " CLAUDE.md`.
4. Report the byte count and the grep results.

## Rule map (old CLAUDE.md → where it stands now)
"New §X" = section of the new CLAUDE.md. Everything not marked "pointer" is kept in shortened wording with the same meaning.

| # | Old rule | Now |
|---|---|---|
| H | Role: implementation engineer, PO human, ChatGPT planner/architect/reviewer, implement everything | New intro, kept |
| R0 | Read only what the task needs (owner 2026-11-22), headings + grep | New §Read, kept |
| R1–R6 | Six read items (spec, decision log + archive binding, four docs, backlog, progress + archive, impl plan) | New §Read 1–6, kept |
| R7 | Full read only when the task changes the subject as a whole | New §Read last line, kept |
| N1 | Small commits, push each at once, never force-push, never overwrite user changes | New §Non-negotiables 1 |
| N2 | Original models from Parts/MeshParts/procedural; no ripping; own 3D art | New §Non-negotiables 2 |
| N3 | Preserve observed mechanics; OBSERVED/OWNER DECIDED/PROVISIONAL | New §Non-negotiables 3 |
| N4 | Server-authoritative money etc.; secure/rate-limit remotes; idempotent finance | New §Non-negotiables 4 |
| N5 | No publication / paid products without PO approval | New §Non-negotiables 5 |
| N6 | Rojo, modular Luau, versioned schemas, reproducible tests | New §Non-negotiables 6 |
| N7 | PROGRESS current with real evidence; no unrun Studio claims | New §Non-negotiables 7 |
| N8 | Tooling blocks Studio: keep implementing, report blocker | New §Non-negotiables 8 |
| C1 | Carry all approved milestones; P0, P1 first; then backlog in dependency order; narrower PO scope | New §Continuous 1 |
| C2 | After each task: verify, PROGRESS, commit, next task at once; no waiting | New §Continuous 2 |
| C3 | No ready ticket / empty backlog: gap check, follow-up task with goal/deps/criteria, start it, repeat | New §Continuous 3 |
| C4 | Blocked: resolve, else record, go on, follow-up; publication/paid need approval | New §Continuous 4 |
| C5 | End-of-run conditions; report blockers and how to resume | New §Continuous 5 |
| C6 | `hasseln` loop: one session, no milestone pauses, push each commit, secure on `main`/`wip/<ID>`, planner records PC entry, go on, backlog refresh "as if owner resolved every PC entry"; triggers | New §Continuous 6 short + pointer: `.claude/skills/hasseln/SKILL.md` "Rules for the whole run", §5 steps 1–2, §7 step 1 (refresh wording verbatim there); triggers kept |
| F1–F8 | P0→P1 eight steps | New §First milestones 1–8, kept (not stated elsewhere) |
| P1–P7 | Seven report items | New §Reporting format, one line, same items |
| P8 | No silent "complete"; vertical slice first | New §Reporting format, kept |
| M0 | Owner decision 2026-11-21; every code/test/model/map task via `cm2-task`; own agent per step; agent file fixes model/effort | New §Plan, implement, verify intro, kept |
| T1 | Table row: plan M/MODEL `planner` Opus medium, plan settles every decision, sets tier | Pointer: cm2-task SKILL.md routing table row 1; `.claude/agents/planner.md` rule 3–4; TEMPLATE.md rule line |
| T2 | Row: plan L `planner-high` Opus high (saves, money, inventory, security, concurrency, unknown-cause bugs) | Pointer: cm2-task table row 2 + step 1; TEMPLATE.md "Implementer tier" L |
| T3 | Row: tier S no plan; implementer from backlog entry, stops, then `planner` writes plan | Pointer: cm2-task step 1 "S: no planner" + step 2; implementer.md "Tier S without a plan"; new §Plan names "tier S runs without a plan" |
| T4–T6 | Rows: implementer S/M/L with models and scopes | Pointer: cm2-task table rows 3–5; TEMPLATE.md "Implementer tier" S/M/L |
| T7 | Row: `modeler` Opus medium, self-review vs `docs/art/quality-reference/` | Pointer: cm2-task table row 6; modeler.md description + rule 5 |
| T8 | Row: `playtester` Haiku via Studio MCP | Pointer: cm2-task table row 7 |
| T9 | Row: `reviewer` Sonnet high, diff vs plan, checks, PROGRESS, commit | Pointer: cm2-task table row 8; reviewer.md description, rules 2, 6, 7 |
| M1 | Main session only orchestrates | New §Plan bullet 1 (also cm2-task "Rules for the main session") |
| M2 | `subagent_type` only, never `model`/`effort` | New §Plan bullet 2 |
| M3 | Implementers decide minor details only (rule 3), stop otherwise, planner amends | New §Plan bullet 3 |
| M4 | Studio playtests batched: now-conditions, else every third task via queue; headless always | New §Plan bullet 4 (detail: cm2-task step 3) |
| S1–S6 | Model switch: planning → `cm2-plan` Opus high; work → `cm2-task` Sonnet; backlog → `hasseln`; short → none; lasts one turn; not applied → keep model + high effort, Opus exception | New §Plan bullet 5, one paragraph, all six kept (exception also in cm2-plan step 0) |
| K1 | Hooks location | New §Plan Hooks |
| K2 | `route-prompt.js` reminder; hook cannot switch model, only skills | New §Plan Hooks 1 ("only the skills can switch the model") |
| K3 | `guard-main-edits.js` blocks main chat on 4 paths; subagents allowed; env switch | New §Plan Hooks 2 |
| K4 | Shell not guarded | New §Plan Hooks 3 |
| K5 | Skill source, 29 skills, pinned, SKILL.md + full.md | New §Skills intro, kept |
| K6 | Skill list by group (Core/Gameplay/Design/Tools) | Pointer: `skills-lock.json` key `skills` + `.claude/skills/` directories (informational, no rule) |
| U1 | Load collaboration-mode first, then domain skills; SKILL.md; full.md when needed | New §Using 1 |
| U2 | Task → skills table (10 rows) | New §Using table, unchanged rows |
| U3 | Skill checks as acceptance criteria; list skills used in planner report | New §Using last bullet |
| X0 | CLAUDE.md and its named docs beat skills | New conflict lead line |
| X1–X12 | Twelve conflict rules | New conflicts 1–12; each keeps the skill(s), the skill's claim (shortened) and the full applying rule; skill names drop the `roblox-` prefix as stated in the lead line |

Rules that could not be placed: none.

## Tests (headless)
None (docs only). The standard checks still run unchanged.

## Playtest (Studio, via playtester)
None (docs only; no Studio criterion).

## Acceptance
- `wc -c CLAUDE.md` <= 12288 (expected 12241).
- `docs/plans/CM2-SLIM5-CLAUDE.md` no longer exists (moved).
- `grep -n "CLAUDE" .claude/hooks/*.js`: hooks only name the file in comments/strings; no hook reads it.
- Headings cited elsewhere still exist (step 3).
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` (count unchanged), `rojo build` — all unaffected.
- Reviewer: tick CM2-SLIM5 in the backlog; PROGRESS entry with old/new byte count.

## Out of scope
Changing any rule, the skills, agent files, hooks or other docs. Owner decisions: none needed.

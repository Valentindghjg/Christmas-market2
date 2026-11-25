# CM2-SLIM — Recurring repo hygiene (standing plan)

Written by: `planner` (CM2-SLIM4b, 2026-11-25), moved unchanged from the backlog section "Recurring task: CM2-SLIM repo hygiene" (owner decision 2026-11-24). Implemented by: `implementer` (tier below). Reviewed and committed by: `reviewer`. Pipeline: skill `cm2-task`; step 1 finds this plan, so no new plan is written per run.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.
Standing: the plan is reused by every run. The run ID is `CM2-SLIM` plus its date; the reviewer puts `(CM2-SLIM)` in every commit subject. When a run is due (the **Due** rules) and the list of runs ("Runs") stay in `docs/CLAUDE_BACKLOG.md`, section "Recurring task: CM2-SLIM repo hygiene"; the reviewer appends each run there.

## Goal
Find what nobody uses and what is too big, and shrink it, so agents read less per task. No behaviour change.

## Source of truth
Owner decision 2026-11-24 (CM2-SLIM, DECISION_LOG); DECISION_LOG 2026-11-25 "decision-log archive window"; CLAUDE.md "Read before changing code" (token budget).

## Implementer tier
Tier: S. Reason: docs, archive moves, dead files outside `src/` and dead code in `src/client`, `tests` and `tools` only; anything near saves, money, inventory, purchases or remotes is filed, not fixed.

## Skills to load
roblox-collaboration-mode, roblox-tooling; roblox-luau-core when dead Luau code is removed.

## Files
| File | New/Change | Purpose |
|---|---|---|
| Found by the run (see Find) | Change, move or delete | Each with grep evidence |
| `docs/archive/` | New or change | Moved finished material |
| `docs/PROGRESS.md` | Change | The run entry (Accept a) |
| `docs/CLAUDE_BACKLOG.md` | Change | Follow-up tasks (Accept d); the reviewer appends the run to "Runs" |

## Data and config
None. No config, save field, action or string key changes, except removing `Localization` keys and client code proven unused by grep.

## Steps
The text below is the backlog body as of 2026-11-25, moved unchanged.

**Goal:** find what nobody uses and what is too big, and shrink it, so agents read less per task. No behaviour change. **Method:** tools, not full reads: `git ls-files` with `wc -c`, `grep -rn` for references, `selene` for unused locals.

**Find** (every hit with its evidence): (1) dead files anywhere (scripts, tools, docs, assets, configs, skills) that nothing references (no `require`, no path in `default.project.json`, code, docs or tools); (2) dead code: modules never required, exported functions never called, config keys never read, `Localization` keys never used, `Protocol` actions never sent or never handled; (3) dead text: sections on removed or superseded things, duplicates of other docs, finished status notes; (4) too big: `CLAUDE.md` over 12 KB (loaded on every message), `docs/CLAUDE_BACKLOG.md` 60 KB, `docs/DECISION_LOG.md` 60 KB, `docs/PROGRESS.md` 20 KB, any other doc 30 KB, any Luau file 800 lines.

**Fix in this run (tier S allows it):**
- Docs: shorten wording without changing meaning; move finished material into `docs/archive/`:
  - backlog: ticked task lines with their status notes, resolved PC entries and done "current run" blocks go to `docs/archive/BACKLOG_DONE_<first date>_to_<last date>.md`, leaving one line per task ID (`- [x] CM2-xx title, done <date>, see archive`);
  - decision log: the archive-window rule of DECISION_LOG 2026-11-25 "decision-log archive window" (top sections, owner entries and the entries of the run day and the day before stay; the rest moves unchanged and in order to `docs/archive/DECISION_LOG_<first date>_to_<last date>.md` and stays binding; superseded owner entries may move with a one-line pointer if the log is still over 60 KB);
  - plans of ticked tasks go to `docs/archive/plans/`; update links that pointed to them.
- Delete dead files outside `src/` and dead code in `src/client`, `tests` and `tools`, each only with grep evidence that nothing references it.
- Never delete an owner decision, test evidence, a licence or provenance record, or anything in `.claude/settings*.json` and hooks; archive instead.

**File, do not fix:** dead code in `src/server` or `src/shared`, anything near saves, money, inventory, purchases or remotes, and splits of Luau files over budget. Each becomes a follow-up task right after the current launch-order task (dead code: tier by the template rules; splits: after CM2-48, not before release).

**Accept:** (a) a PROGRESS entry with a before/after table: size of the 10 largest text files, line counts of `src`, `tests` and `docs`, and the total that agents read every task (`CLAUDE.md` + the backlog + the last 60 KB of the decision log); (b) every removal listed with its grep evidence; every archived block findable by its task ID (`grep -rn <ID> docs/` hits it); (c) `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` and `rojo build` pass; the headless count is unchanged unless a test of removed dead code went with it, each removed test named; (d) follow-up tasks in the backlog with goal, tier and acceptance criteria, or "none"; (e) Studio not needed when only docs and files outside `src` changed, otherwise the Studio queue rules of `cm2-task` step 3 apply.

## Tests (headless)
| Test case file | Test name | Asserts |
|---|---|---|
| (existing suite) | all | Count unchanged unless a test of removed dead code went with it; each removed test named in PROGRESS.md |

## Playtest (Studio, via playtester)
None when only docs and files outside `src` changed. Otherwise the Studio queue rules of `cm2-task` step 3 apply (Accept e).

## Acceptance
The **Accept** paragraph in Steps above, unchanged; checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau`, `rojo build default.project.json --output build.rbxlx`.

## Out of scope
Fixing anything listed under "File, do not fix"; changing the Due rules (backlog section); behaviour changes of any kind.

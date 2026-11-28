# Decision log archive 2026-11-25 (planner, 2026-11-28)

Entries moved unchanged and in order from `docs/DECISION_LOG.md` (non-owner entries outside the window); they stay binding.

## 2026-11-25 — Swarve Studios licence received
- Swarve Studios answered the owner's ticket (2026-11-25): any use, modification and re-upload is allowed, no credit required; only reselling or charging money for the assets themselves is not. Record: `assets/third_party/swarve-essential-ui/LICENSE.md`.
- The `.rbxl` stays out of the public repository (`.gitignore`). The CM2-UI look stays as decided on 2026-11-24 (own cream look); whether CM2-UI also uses the pack's pieces is the owner's call.

## 2026-11-25 — decision-log archive window and CM2-SLIM follow-ups (planner)
- The 14-day window of CM2-SLIM moved nothing (the oldest entry is 6 days old) and left the log at 147 KB against 60 KB. New rule: keep the top sections, every owner entry and every entry dated on the run day or the day before; every other entry goes unchanged to `docs/archive/DECISION_LOG_<first>_to_<last>.md`. Archived entries stay binding and grep-findable. If still over 60 KB, an owner entry that a later owner entry supersedes may move with a one-line pointer. Applied once by CM2-SLIM3, then by every CM2-SLIM run.
- CLAUDE.md (15.7 KB against 12 KB) is trimmed by wording and pointers only (CM2-SLIM5, planner text, implementer applies it); owner approval only if a binding rule would change.
- `Quest.Claim` stays: server handler and validator are the scaffold for CM2-G11. Splits of Luau files over 800 lines run after CM2-50a (25a-25c), so the release candidate stays unchanged.
- Files: docs/CLAUDE_BACKLOG.md (CM2-SLIM section, CM2-SLIM1..5, 25a-25c, line 18 note).

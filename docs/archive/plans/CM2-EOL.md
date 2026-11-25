# CM2-EOL — LF working copies

Written by: `planner` (Opus 5.5, high). Implemented by: the agent for the tier below. Playtested by: none (no Studio test). Reviewed and committed by: `reviewer` (Opus 5.5, medium). Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
Every text file git writes to disk (checkout, stash, reset, rebase) has LF line endings, so `stylua --check src tests tools` no longer fails on CRLF working copies. No player-visible change.

## Source of truth
- Finding: PROGRESS 2026-11-22 entries CM2-RF and CM2-13b ("three working copies had been checked out with CRLF by `core.autocrlf` and were reset to LF").
- Cause (planner check 2026-11-22, git 2.55.0.windows.5): `core.autocrlf=true` comes from the system config `C:/Program Files/Git/etc/gitconfig`; `.gitattributes` has no eol rule for text files. The index stores every text file as LF (`git ls-files --eol`: 242 `i/lf w/lf`, 86 `i/lf w/crlf`, 1 `i/lf w/mixed` = `docs/archive/plans/CM2-UVF2.md`, 56 `i/-text` binaries, 2 `-text` CC0 files, 0 `i/crlf`).
- No file is stored as CRLF on purpose: `docs/MODEL_INTEGRATION.md` is `i/lf w/lf`. The repo has no `.bat`, `.cmd` or `.ps1` file. So there is no CRLF exception.
- CLAUDE.md "Non-negotiables" (never overwrite user changes) and the task brief (do not change git config).

## Implementer tier
Tier: S. Reason: one config file and one doc line, no code, save, money, inventory or remote change.

## Skills to load
roblox-collaboration-mode, roblox-tooling.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `.gitattributes` | Change | Add the eol rules; keep the existing 9 rules unchanged |
| `docs/TECHNICAL_ARCHITECTURE.md` | Change | One line in section 1 on line endings |
| `docs/DECISION_LOG.md` | Change | New entry at the end |
| 20 working copies outside `.claude/` (no content change) | Rewrite | Re-checkout as LF (step 4); not a git change |

## Data and config
`.gitattributes` after the change, in this order (the first block is new; the binary block is the current file, byte for byte):

```text
# Line endings (CM2-EOL): the index and every working copy use LF on all
# platforms, whatever core.autocrlf says. Binary files stay untouched.
* text=auto eol=lf

# Keep third-party model sources byte-identical to their original downloads.
*.fbx binary
*.glb binary
*.obj -text -diff
*.mtl -text -diff
*.blend binary
*.rbxm binary
*.rbxl binary
*.png binary
*.jpg binary
```

Why this set:
- `* text=auto eol=lf` must come first; later lines override it for matching paths (gitattributes: last match wins per attribute). The `eol` attribute takes precedence over `core.autocrlf`, so the system config can stay as it is.
- `binary` (= `-text -diff -merge`) on `.fbx .glb .blend .rbxm .rbxl .png .jpg` and `-text` on `.obj .mtl` unset `text`, so `eol` has no effect on them: they stay byte-identical (CC0 provenance, DECISION_LOG 2026-11-21).
- `text=auto` still leaves any untracked binary type that is added later untouched (git's NUL-byte check), so no further binary rule is added now.
- `.rbxmx` / `.rbxlx` (XML) are text and get LF; `build.rbxlx` and `release.rbxlx` are build outputs and not tracked.
- No `eol=crlf` exception (see Source of truth).

## Steps
Run everything in Git Bash at the repo root. Do not run `git config`. Do not commit (the reviewer commits).

1. **Precondition.** `git diff --stat -- . ':!docs/CLAUDE_BACKLOG.md'` must print nothing (no content change in tracked files; the planner's uncommitted backlog edit for this task is expected; files listed as ` M` with an empty diff, such as the three CM2-RF files, are fine). If it prints anything, stop and report: a real local change could otherwise be staged in step 3.
2. **Write `.gitattributes`** exactly as in "Data and config" (LF, final newline).
3. **Renormalize once.** `git add --renormalize -- . ':!docs/CLAUDE_BACKLOG.md'` (implies `-u`; the backlog is LF in index and working copy and stays unstaged for the reviewer; untracked `.agents/`, `.codex/`, `.mcp.json`, `AGENTS.md` are not touched). Then check:
   - `git diff --cached --name-only` prints exactly `.gitattributes`. Expected, because no blob is stored as CRLF. Any other path: stop and report the list and `git diff --cached --stat`; do not unstage anything yourself.
   - `git status --porcelain` shows `M  .gitattributes` (staged), ` M docs/CLAUDE_BACKLOG.md` if the planner edit is still uncommitted, `?? docs/archive/plans/CM2-EOL.md` if the plan is still untracked, and the four `??` entries above; nothing else.
4. **Rewrite the CRLF working copies as LF.** `git checkout -- <path>` skips files whose stat data is unchanged, so delete first. Exclude `.claude/` (the running Claude Code session reads `settings.json`, hooks, agents and skills; they get LF the next time git writes them):
   ```bash
   git ls-files --eol | grep -E 'w/(crlf|mixed)' | cut -f2 | grep -v '^\.claude/' \
     | while IFS= read -r f; do rm -- "$f" && git checkout -- "$f"; done
   ```
   (`cut -f2` takes the path after the tab; the attr column now contains a space.) Expected: 20 files (`default.project.json`, `skills-lock.json`, 4 under `assets/art/source/Buildings/`, 14 under `docs/`, incl. `docs/archive/plans/CM2-UVF2.md` and `docs/plans/TEMPLATE.md`).
5. **Verify** (all must hold; record the outputs for the reviewer):
   - `git ls-files --eol | grep -E 'w/(crlf|mixed)' | grep -vc $'\t\\.claude/'` prints `0`.
   - `git ls-files --eol | grep -E 'w/(crlf|mixed)' | grep -c $'\t\\.claude/'` prints `67` (left as they are, see step 4).
   - `git ls-files --eol -- src tests tools docs | grep -vc 'w/lf'` prints `0` (every file there is `i/lf w/lf`).
   - `git ls-files --eol -- '*.png' '*.blend' '*.fbx' '*.glb' | grep -vc 'i/-text'` prints `0` and `git status --porcelain -- assets` prints nothing (binaries unchanged).
   - Checkout test: `printf 'x' >> src/shared/Localization.lua && git checkout -- src/shared/Localization.lua`, then `git ls-files --eol -- src/shared/Localization.lua` shows `w/lf` and `grep -c $'\r' src/shared/Localization.lua` prints `0`. Repeat with `tests/headless/run.luau`.
   - `git status` no longer prints "LF will be replaced by CRLF" for any file.
6. **TECHNICAL_ARCHITECTURE section 1**: after the sentence ending "…without actual Studio run." add the sentence: `Line endings: `.gitattributes` sets `* text=auto eol=lf`, so the index and every working copy use LF on every platform regardless of `core.autocrlf`; binary art files are marked `binary` (CM2-EOL).`
7. **DECISION_LOG**: append
   ```text
   ## 2026-11-22 — CM2-EOL LF working copies (engineering)
   - `core.autocrlf=true` (system Git config) checked text files out as CRLF while the index is LF; `stylua --check` then failed (three times in the CM2-RF / CM2-13b run).
   - `.gitattributes` gets `* text=auto eol=lf` as its first rule; the existing binary and `-text` rules stay and keep art files byte-identical. No CRLF exception: no file is stored as CRLF and the repo has no Windows batch scripts. Git config is not changed.
   - `git add --renormalize` changed no blob (index already LF). CRLF working copies outside `.claude/` were re-checked-out as LF; `.claude/` files are left until git next writes them.
   ```

## Tests (headless)
No new test cases. The existing suites must still pass unchanged:

| Command | Expected |
|---|---|
| `stylua --check src tests tools` | PASS |
| `selene src tests tools` | 0 errors, 0 warnings |
| `lune run tests/headless/run.luau` | 405 run, 405 passed (unchanged) |
| `lune run tests/tools/art_pipeline.luau` | 22 run, 22 passed |
| `rojo build default.project.json --output build.rbxlx` | PASS |

## Playtest (Studio, via playtester)
None. No game file content changes (step 3 proves it); the reviewer does not add a "Studio-Test ausstehend" entry.

## Acceptance
- `.gitattributes` contains the new block first and the 9 old rules unchanged (`git diff --cached .gitattributes` shows only added lines).
- The one-time renormalize (step 3) staged no path other than `.gitattributes`.
- After `git checkout -- <a .lua file>` (made dirty first, step 5) the working copy is LF and `stylua --check src tests tools` passes.
- `git ls-files --eol` shows `w/lf` for every file under `src`, `tests`, `tools` and `docs`, and no `w/crlf`/`w/mixed` outside `.claude/`.
- Binaries stay `i/-text` and unchanged; `.obj`/`.mtl` keep `attr/-text`.
- `git config` unchanged (`git config --show-origin --get-all core.autocrlf` still shows the system file with `true`).
- The checks in "Tests (headless)" pass with the counts given.
- One commit by the reviewer: `build: force LF working copies via .gitattributes (CM2-EOL)` with `.gitattributes`, this plan, TECHNICAL_ARCHITECTURE, DECISION_LOG, PROGRESS and the backlog (entry and tick); push to `origin`.

## Out of scope
- Changing `core.autocrlf` or any other git config (local, global or system).
- Rewriting `.claude/` working copies (step 4).
- CRLF rules for Windows batch files (none exist; add `*.bat text eol=crlf` only when one is added).
- Untracked `.agents/`, `.codex/`, `.mcp.json`, `AGENTS.md`.

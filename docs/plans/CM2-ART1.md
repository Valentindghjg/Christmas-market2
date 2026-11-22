# CM2-ART1 — Art render writes inside the repo

Written by: `planner` (Opus 5.5, high). Implemented by: the tier's agent. Playtested by: nobody (no Studio test, see Playtest). Reviewed and committed by: `reviewer` (Opus 5.5, medium). Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
Every path the art pipeline hands to Blender is absolute and lies under the working directory (the repo root), so `art.luau render` and `export` with the default `--root` write only into `<repo>/assets/art/_build/<artPath>/`.

## Source of truth
- Backlog MODEL section, CM2-ART1 entry; PROGRESS 2026-11-22 CM2-12 entry ("Tooling defect").
- MODEL_INTEGRATION "Asset pipeline (CM2-AP)"; `docs/plans/CM2-AP.md` (CLI, tests N/V/O/S/R/B).
- PC-5 step 4: the owner deletes `C:\assets`. This task never reads into, writes, moves or deletes anything in `C:\assets`.

## Analysis
- `art.luau` passes `Paths.buildDir("assets/art", …)` (relative) as `--out-dir`; `blender_render.py` sets `scene.render.filepath` to `os.path.join(out_dir, …)`. Blender resolves a drive-less relative render path on Windows against the drive root, hence `C:\assets\art\_build\…` (cause inferred from the evidence; the fix does not depend on it).
- `--fbx`, `--report` (export) and `--out` (probe) are opened by Python relative to the process cwd and worked, but they are the same class of path and are fixed too.
- Fix in both places: Luau resolves every path before calling Blender, `Blender.run` refuses relative paths (testable without Blender), and the Python scripts apply `os.path.abspath` for direct calls.
- Faking the runner: `art.luau` is a top-level CLI script (`process.exit`), so its commands cannot be called from the test. The test instead pins the pure parts (`Paths.absolute`, `Paths.isAbsolute`, `Blender.relativePaths`) and the `Blender.run` guard; the wiring is proven by the real render/export run in Acceptance.

## Implementer tier
Tier: S. Reason: a tooling path fix in three Luau files and three Python scripts with two Lune tests; no game code, save, money, inventory or remote change.

## Skills to load
roblox-collaboration-mode, roblox-tooling, roblox-luau-core, roblox-luau-types. Not cm2-modeling (no model change).

## Files
| File | New/Change | Purpose |
|---|---|---|
| `tools/art/lib/Paths.luau` | Change | `Paths.isAbsolute`, `Paths.absolute` |
| `tools/art/lib/Blender.luau` | Change | `PATH_FLAGS`, `RELATIVE_CODE`, `relativePaths`, guard in `run` |
| `tools/art/art.luau` | Change | resolve root, probe root and script paths against `process.cwd` |
| `tools/art/blender_render.py` | Change | `out_dir = os.path.abspath(out_dir)` |
| `tools/art/blender_export.py` | Change | abspath for `--fbx` and `--report` |
| `tools/art/make_probe.py` | Change | `out = os.path.abspath(out)` |
| `tests/tools/art_pipeline.luau` | Change | tests P1, P2; B1 uses absolute paths |
| `docs/MODEL_INTEGRATION.md` | Change | one bullet in "Asset pipeline (CM2-AP)" |
| `docs/DECISION_LOG.md` | Change | new entry at the end |

## Data and config
No config keys, no schema. New constants: `Blender.RELATIVE_CODE = "ART_RELATIVE_PATH"`, `Blender.PATH_FLAGS = { ["--fbx"] = true, ["--report"] = true, ["--out-dir"] = true, ["--out"] = true }`.

## Steps
1. **`Paths.luau`**, after `Paths.parentDir`:
   - `function Paths.isAbsolute(path: string, cwd: string): boolean` is true when `path` matches `^%a:[/\\]` (drive + separator), or `^[/\\][/\\]` (UNC), or starts with `/` while `cwd` also starts with `/` (POSIX). Everything else is false (including `/x` under a Windows cwd, and `C:x`).
   - `function Paths.absolute(cwd: string, path: string): string`, in this order:
     1. `p` = `path` with every `\` replaced by `/`; `base` = `cwd` with every `\` replaced by `/` and all trailing `/` removed.
     2. If `Paths.isAbsolute(p, cwd)`, return `p`.
     3. If `p` starts with a single `/` and `base` matches `^(%a:)`, return that drive (for example `C:`) `.. p`.
     4. Remove leading `./` repeatedly. If `p` is then `""` or `"."`, return `base` (or `"/"` if `base` is `""`).
     5. Return `base .. "/" .. p`.
   - No `..` collapsing, no filesystem access. Header comment unchanged apart from one line: `-- Paths handed to Blender go through Paths.absolute (CM2-ART1).`
2. **`Blender.luau`**: add `local Paths = require("./Paths")`, the two constants above, and:
   - `function Blender.relativePaths(cwd: string, blend: string?, script: string, extra: { string }): { string }` returns, in this order, `blend` (when not nil), `script`, and each `extra[i + 1]` whose `extra[i]` is in `PATH_FLAGS`, for every one of them that is not `Paths.isAbsolute(value, cwd)`. A flag at the last index (no value) adds nothing.
   - `Blender.run`: first `local bad = Blender.relativePaths(process.cwd, blend, script, extra)`; if `#bad > 0`, return `{ ok = false, code = -1, stdout = "", stderr = Blender.RELATIVE_CODE .. " " .. table.concat(bad, " ") }` without calling `process.exec`. Otherwise unchanged.
3. **`art.luau`**:
   - Replace the four path constants: `PROBE_ROOT = Paths.absolute(process.cwd, "tests/fixtures/art")`, `EXPORT_SCRIPT = Paths.absolute(process.cwd, "tools/art/blender_export.py")`, same for `RENDER_SCRIPT` and `PROBE_SCRIPT`. `PROBE_PATH` unchanged.
   - `root` = `Paths.absolute(process.cwd, <the --root option or Paths.DEFAULT_ROOT>)`. `--raw` and the `verify` place file stay as given (Lune reads them, not Blender).
   - Header line 12 becomes: `-- Every command takes --root <dir> (default assets/art, relative to the working directory); every path handed to Blender is absolute (CM2-ART1). Exit codes: 0 ok, 1 error,` (line 13 unchanged). `exportArt`, `renderArt`, `probe` need no other change; their `[ART]` lines now print absolute paths.
4. **Python** (defence for direct calls; Blender's cwd is the caller's):
   - `blender_render.py` `parse_args`: return `os.path.abspath(out_dir), colors`.
   - `blender_export.py` `parse_args`: return `os.path.abspath(values["--fbx"]), os.path.abspath(values["--report"])`.
   - `make_probe.py` `parse_args`: return `os.path.abspath(out)` (the existing `os.makedirs(os.path.dirname(os.path.abspath(out)))` stays).
   - `blender_export.py` lacks `import os`: add it between `import json` and `import re`. No other change.
5. **Docs**:
   - MODEL_INTEGRATION "Asset pipeline (CM2-AP)", new bullet before "- Checks:": `- Paths handed to Blender: art.luau resolves --root, the probe root and the Blender scripts against the working directory, so every path Blender gets is absolute; Blender.run refuses a relative one with ART_RELATIVE_PATH before starting Blender, and the three Blender scripts apply os.path.abspath (CM2-ART1).` (code-format the identifiers).
   - DECISION_LOG, new entry at the end: `## 2026-11-22 — CM2-ART1 absolute Blender paths (engineering)` with bullets: defect (render previews landed in `C:\assets\…` with the default relative `--root`); fix (Luau resolves against `process.cwd`, guard `ART_RELATIVE_PATH`, Python `abspath`); `--root` semantics unchanged (relative to the working directory); files; art pipeline tests 22 (local), 21 passed + 1 skipped on CI; no Studio test (tooling only).

## Tests (headless)
In `tests/tools/art_pipeline.luau`, a new section `-- Paths ---` after the Rojo section (before Blender):

| Test name | Asserts |
|---|---|
| `P1 relative roots resolve to absolute paths under the working directory` | `Paths.absolute("C:\\repo\\", "assets/art")` = `"C:/repo/assets/art"`; `("C:\\repo", "./assets/art")` = `"C:/repo/assets/art"`; `("C:\\repo\\", "D:\\art")` = `"D:/art"`; `("C:\\repo\\", "/x/y")` = `"C:/x/y"`; `("/home/u/repo/", "assets/art")` = `"/home/u/repo/assets/art"`; `("/home/u/repo", "/tmp/art")` = `"/tmp/art"`; `("C:\\repo\\", ".")` = `"C:/repo"`. `isAbsolute` false for `"assets/art"`, `"./x"`, `("/x", "C:\\repo\\")`; true for `"C:/x"`, `"c:\\x"`, `"\\\\srv\\share"`, `("/x", "/repo/")`. Real cwd: `base` = `process.cwd` with `\`→`/` and trailing `/` removed; `Paths.absolute(process.cwd, Paths.DEFAULT_ROOT)` = `base .. "/assets/art"`, it is `isAbsolute`, and `Paths.buildDir(<that>, "Trees/DouglasFir/Medium")` = `base .. "/assets/art/_build/Trees/DouglasFir/Medium"`. |
| `P2 Blender.run refuses relative paths without starting Blender` | `Blender.relativePaths(process.cwd, "assets/art/source/X/model.blend", "tools/art/blender_render.py", { "--out-dir", "assets/art/_build/X", "--colors", "Snow=1,2,3" })` returns exactly those 3 paths in that order (`--colors` values never listed); the same call with each path passed through `Paths.absolute(process.cwd, …)` returns 0; `{ "--fbx", <abs>, "--report", "rel/report.json" }` with nil blend and an absolute script returns `{ "rel/report.json" }`; `{ "--out" }` alone returns 0. `Blender.run("Z:/no/such/blender.exe", nil, "tools/art/make_probe.py", { "--out", "tests/fixtures/art/x.blend" })` returns `ok = false`, `code = -1`, and `Blender.artLines(result)[1]` starts with `ART_RELATIVE_PATH` (a started process would raise, so this proves no exec). |

- B1 changes only its paths: `local fixtureRoot = Paths.absolute(process.cwd, FIXTURE_ROOT)`; `blendFile`/`buildDir` from `fixtureRoot`; the two scripts as `Paths.absolute(process.cwd, "tools/art/make_probe.py")` and `…/blender_export.py`. Cleanup lines unchanged.
- Expected summary: local (Blender installed) `[ART-TEST] SUMMARY 22 run, 22 passed, 0 failed, 0 skipped`; CI without Blender 21 passed, 1 skipped.
- `tests/headless/run.luau` unchanged: 400 run, 400 passed.

## Playtest (Studio, via playtester)
None. Tooling only: no file under `src/`, no Rojo-mapped asset and no place content changes, so there is nothing to observe in Studio. Do not queue it in "Studio-Test ausstehend".

## Acceptance
- Checks: `stylua --check src tests tools`, `selene src tests tools`, `lune run tests/headless/run.luau` (400 run, 0 failed), `lune run tests/tools/art_pipeline.luau` (22 run, 22 passed locally), `rojo build default.project.json --output build.rbxlx`, `rojo build release.project.json`, `lune run tools/art/art.luau verify release.rbxlx` (`0 integrated, 14 pending, 0 failed`, exit 0).
- Real run (implementer, repeated by the reviewer; Blender 5.2 is installed, no key needed), from the repo root in Git Bash:
  1. `rm -f assets/art/_build/Trees/DouglasFir/Medium/{preview_front.png,preview_34.png,model.fbx,report.json}` (gitignored build output only).
  2. `touch "$TEMP/cm2-art1.marker"`.
  3. `lune run tools/art/art.luau render Trees/DouglasFir/Medium` → exit 0, prints `[ART] rendered Trees/DouglasFir/Medium to <repo with />/assets/art/_build/Trees/DouglasFir/Medium/preview_front.png and preview_34.png`.
  4. `lune run tools/art/art.luau export Trees/DouglasFir/Medium` → exit 0.
  5. All four files exist under `assets/art/_build/Trees/DouglasFir/Medium/`.
  6. Nothing outside the repo: `test ! -e /c/assets/art/_build/Trees/DouglasFir/Medium` passes, and `find /c/assets -newer "$TEMP/cm2-art1.marker" 2>/dev/null` prints nothing (if `C:\assets` is already gone, both hold trivially). Read-only: never delete or change `C:\assets` (PC-5).
  7. `git status --porcelain -- assets` prints nothing (no `.blend`, preview or asset change).
- Record the outputs of steps 3–7 in PROGRESS.md (reviewer).

## Out of scope
- Deleting `C:\assets` (owner, PC-5 step 4) and changing PC-5.
- `tools/art/kit/cm2_kit.py` and the modeler's manual `blender … build.py -- --out <relative>` call (its `.blend` saves work; not part of the `art.luau` pipeline).
- `--raw`, the `verify` place file, `..` collapsing, and any check that `--root` lies inside the repo (`--root` semantics stay unchanged).
- Any `.blend`, preview, `asset.json`, `.rbxm` or game code change.

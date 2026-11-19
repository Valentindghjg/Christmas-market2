# Reference screenshots — upload and usage

## Status
The 32 screenshot image binaries are **not yet committed** to GitHub. The original archive is available to the project owner as `roblox_codex_blueprint.zip` in the ChatGPT conversation. The repository connector currently supports UTF-8 text and Git objects, but cannot directly read local binary files from the ChatGPT runtime.

## Owner/Claude Code handoff
1. Download `roblox_codex_blueprint.zip` from the conversation.
2. Copy it into the local checkout root (or give Claude Code its absolute file path).
3. In the repository root, extract **only** `docs/references/roblox-game/` from the archive, then commit those images.
4. Example (Python 3; run locally):
```bash
python -c "import zipfile; z=zipfile.ZipFile('roblox_codex_blueprint.zip'); [z.extract(n,'.') for n in z.namelist() if n.startswith('docs/references/roblox-game/')]"
git add docs/references/roblox-game
git commit -m "docs: add 32 screenshot references"
git push
```
5. Check `git ls-files docs/references/roblox-game` and visually inspect several screenshots.

## Usage rules
- Reference images guide gameplay and style, not permission to copy third-party assets.
- Keep OBSERVED separate from INFERRED; compare screenshot details with `docs/IMPLEMENTATION_PLAN.md`.
- IMG_3797 is a different game listing and is **not** a tree-lot gameplay reference.
- Claude Code should update screenshot-based issues after the images are committed.

## Known screenshots
IMG_0160, IMG_0162, IMG_0165, IMG_0166, IMG_0167, IMG_0169, IMG_0170, IMG_0171, IMG_0172, IMG_0173, IMG_0174, IMG_0175, IMG_0176, IMG_0177, IMG_0178, IMG_0179, IMG_0180, IMG_0181, IMG_0182, IMG_0183, IMG_0184, IMG_0185, IMG_0186, IMG_0187, IMG_0188, IMG_0189, IMG_0190, IMG_0191, IMG_0192, IMG_0193, IMG_0194, IMG_3797.

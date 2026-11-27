# Decision log and repository sync policy
Updated: 2026-11-19
Archive (CM2-SLIM3, 2026-11-25): entries of 2026-11-19..2026-11-23 that are not owner entries moved unchanged to `docs/archive/DECISION_LOG_2026-11-19_to_2026-11-23.md`; they stay binding. Grep `docs/archive/DECISION_LOG_*.md` too.

## Standing owner instruction
All **project-relevant outcomes** developed in this chat (decisions, architecture, mechanics, implementation tasks, test findings and material changes) should be committed to `Valentindghjg/Christmas-market2` without requesting routine permission. When a decision changes, update the canonical documents and record what changed here. Avoid copying unrelated conversation, private details, secrets or credentials into the public repository. This policy applies when the assistant is actively working in a conversation with GitHub access; it is **not** autonomous background syncing.

## Approval boundary
Owner explicitly reserved approval for **publication** and **paid actions**. Keep Robux products disabled until approval; do not create/activate products, initiate purchases, or publish on Roblox without explicit consent. Engineering may decide technical details and minor gameplay rules independently.

## 2026-11-19 — product direction (owner)
- Closest practical gameplay to original screenshot reference, but original snowy map.
- First deliver a solid playable core; then expand features.
- Original-like economy, both manual and automatic pricing, truck deliveries with unloading.
- Dynamic demand by price/species/season/reputation.
- Money/reputation/prerequisite progression; no rebirth.
- Customer budgets, preferences, patience; staff automate operations; one-time hiring only, no wages.
- No offline income.
- Both personal plots and collaborative company multiplayer; no initial trading.
- Detailed persistent statistics/history; phone/tablet/PC/console.
- Modern festive UI, German and English, Christmas-only events.
- Optional Robux features conceptually like original; activation requires separate approval.
- GitHub + Rojo; final 3D models provided gradually by owner via Studio or FBX/GLB.
- Assistant authorized to make technical and minor gameplay decisions without further questions.

## 2026-11-21 — launch scope interview (owner)
Recorded in full at the top of [PRODUCT_SPEC.md](PRODUCT_SPEC.md). Previous rule → new rule:
- **Title:** "Christmas Market 2" → the game is called **Christmas Tree Village** (repo name unchanged).
- **Release:** no date → **1st Advent (2026-11-29)** if the owner declares it finished, otherwise 2nd Advent (2026-12-06). Go/no-go on 2026-11-28.
- **Fidelity:** close-to-reference mechanics with partly provisional numbers → **all reference functions and numbers adopted**. Own look, map and names.
- **Language:** DE/EN → **English-only launch** with Roblox auto-translation; language switch later.
- **Checkout:** automatic → **manual player checkout** until a Cashier is hired.
- **Customers and staff:** logical simulation → **visible R15 avatars** (customers in winter clothing, staff in uniform).
- **Multiplayer:** collaborative company with roles → **Solo/Duo/Trio/Quad saves**:
  - unlimited saves per player;
  - the creator owns the save, members may play while the owner is offline;
  - 5-digit invite code;
  - in-server teammate search (cross-server later);
  - one server per save, with a teleport-to-join.
- **Monetization:** disabled until approval → **active Robux shop at launch** with the reference's products and prices; loot boxes in version 2; Roblox group 2× daily rewards.
- **Events:** Christmas-only, undefined → **one event per Advent Sunday** (reference mechanics and themes, own item designs) plus an **Advent calendar** Dec 1–24 (high priority).
- **World and progression:**
  - Day/night: 18 min per game day (12 day + 6 night).
  - Lot expansion extends backwards into the forest.
  - Real tree species.
  - HQ names: Sales Tent → Timber Pavilion → Alpine Hut → Mountain Chalet, plus Elf Workshop ("Coming soon" content).
  - Mountain-village map with a covered bridge and a village square.
  - All four leaderboards, including Robux spent.
  - Licensed Roblox audio and an HQ radio.
  - Staff fatigue as gentle as the reference.
  - 12 players per server.
- **Art:** CC0/primitive placeholders → **all current models removed**. Own palette; Blender for larger models and Parts only for small ones; Opus self-review against owner reference images.
- **Process:** Opus plans (`docs/plans/`), Sonnet implements (`implementer` agent) and playtests (`playtester` agent); see CLAUDE.md.
- **Affected files:** PRODUCT_SPEC.md, GAME_DESIGN.md, TECHNICAL_ARCHITECTURE.md, TEST_PLAN.md, CLAUDE.md, CLAUDE_BACKLOG.md, docs/plans/TEMPLATE.md, docs/art/quality-reference/README.md, .claude/agents/.

## 2026-11-21 - Model routing per task (owner)
- **Previous rule:** Opus plans and reviews in the main session, Sonnet (medium) implements and playtests.
- **New rule:**
  - planner: Opus 5.5 high.
  - Implementer by tier: S Sonnet 5.5 medium, M Sonnet 5.5 high, L Opus 5.5 high.
  - playtester: Sonnet 5.5 medium.
  - reviewer (review and commit): Opus 5.5 medium.
  - modeler (3D models): Opus 5.5 medium.
- **Enforcement:**
  - Model and effort are pinned in `.claude/agents/*.md`.
  - The skill `cm2-task` fixes the step order and forbids model or effort overrides on the Agent call.
  - The planner sets the tier in the plan.
- **Engineering decision:** tier M is Sonnet 5.5 at high effort.
- **Fix:** playtester and modeler no longer have a `tools` allowlist, so they inherit the Roblox Studio MCP tools (`.mcp.json`, server `Roblox_Studio`). `disallowedTools` removes editing from the playtester and agent spawning from both. Before this, the playtester's allowlist excluded the MCP tools.
- **Affected files:**
  - CLAUDE.md, PRODUCT_SPEC.md, docs/plans/TEMPLATE.md
  - .claude/agents/ (planner, implementer, implementer-high, implementer-opus, playtester, reviewer, modeler)
  - .claude/skills/cm2-task/

## 2026-11-21 - Automatic model switch in the chat (owner)
- **Previous rule:** the chat ran on the model chosen in the session.
- **New rule:**
  - Planning in the chat invokes the skill `cm2-plan`, which switches the turn to Opus 5.5 at high effort.
  - Work invokes the skill `cm2-task`, which switches the turn to Sonnet 5.5 at medium effort; the agents then run on their pinned models.
  - Each message is classified again.
- **Mechanism:** the `model` and `effort` fields in the skill frontmatter, which apply for the rest of the turn (Claude Code skills documentation).
- **Limit:** a value excluded through `availableModels`, or not supported in auto mode, is not applied.
- **Affected files:** CLAUDE.md, .claude/skills/cm2-plan/, .claude/skills/cm2-task/.

## 2026-11-21 - Model-switch fallback and routing hooks (owner)
- **Fallback (owner):**
  - If a skill's model switch is not applied, the chat stays on its model at high effort. For this, `cm2-task` now uses effort high.
  - Exception: planning on Sonnet stops (`cm2-plan`) and asks the user to switch to Opus.
  - The planner agent stops with WRONG MODEL if it is not on Opus.
- **Hooks (owner request, engineering design):**
  - The UserPromptSubmit hook injects the routing rule into every message.
  - The PreToolUse hook denies main-chat writes to src/, tests/, assets/ and docs/plans/, so the work has to go through the agents.
  - Hooks cannot set the model or effort (Claude Code hooks documentation). The switch stays in the skills.
- **Affected files:** CLAUDE.md, .claude/settings.json, .claude/hooks/, .claude/skills/cm2-plan/, .claude/skills/cm2-task/, .claude/agents/planner.md.

## 2026-11-22 - Art quality references (owner)
- **Previous rule:** model work waits for 2 good and 2 bad owner images; the look is our own.
- **New rule:**
  - **References:** the owner supplied 6 images (3 liked, 3 disliked).
    - Liked: a softly faceted low-poly tree (target), a simple layered conifer (minimum) and a faceted low-poly character (level for models seen often).
    - Disliked: a noisy shard-leaf tree (too much), a bare blob-on-stick tree (too little) and a realistic leaf-card tree (wrong style).
  - **Quality tiers:** tier A for models seen often or for long (stand and HQ, cars, truck, buildings, trees for sale); tier B for small, distant or rare models.
  - **Reference look:** models follow the reference game's look (how they are built, proportions, arrangement, colour mood), but are never identical; silhouette details, palette values and decoration are our own.
  - **MODEL tasks** are no longer skipped.
- **Engineering decisions:**
  - The images stay local and gitignored, because the repository is public and their licence is unknown. The README describes each image, so it stays binding without the files.
  - The trees for sale count as tier A.
  - Reference-game screenshots for the look are requested as PC-1 (not blocking; until then the text observations apply).
- **Affected files:** PRODUCT_SPEC.md (Art), docs/art/quality-reference/README.md, .gitignore, docs/CLAUDE_BACKLOG.md, .claude/agents/modeler.md, docs/plans/TEMPLATE.md.

## Change procedure
1. Identify impacted documents and code/config.
2. Amend the canonical source (PRODUCT_SPEC for owner decisions, GAME_DESIGN for mechanics, TECHNICAL_ARCHITECTURE for interfaces, TEST_PLAN for verification).
3. Add a dated entry here: previous rule -> new rule, origin (owner/engineering), affected files.
4. Update PROGRESS.md with actual completed work and tests.
5. Commit changes to GitHub; provide the commit link in the conversation.
6. Never claim a commit or verification that did not succeed.

## Reference material
32 screenshots were provided in conversation and packaged separately; image binaries are not yet in GitHub. The repository's screenshot observations are in IMPLEMENTATION_PLAN.md. Do not claim the original assets or source code were acquired.

## 2026-11-19 — owner changes delivery roles (supersedes 3D model ownership)
- Owner is Product Owner and approves publication and paid actions.
- ChatGPT is project planner, lead architect, task author and reviewer.
- Claude Code is the implementation agent responsible for **all** development, including Luau systems, UI, 3D models, map, integration and tests.
- Earlier instruction that the owner supplies final 3D models is **superseded**. Claude Code may generate original Roblox Studio procedural/primitive models and create original assets, without copying proprietary third-party content.
- Execution is not automatic: Claude Code must be launched and given the task brief in an environment with repo access. ChatGPT will review reported commits and test evidence when available.
- Keep publication and paid action approval boundary unchanged.

## 2026-11-22 — owner: hasseln works through the backlog without stopping
- Previous rule: the continuous-execution loop in CLAUDE.md had no dedicated skill; each task was started with `cm2-task`.
- New rule (owner): the skill `hasseln` works through the whole backlog (or a given scope) task by task via `cm2-task` in one session, without pausing at milestones and without pushing. Tasks that need the owner are skipped in favour of the next workable one. Blocked after two failed attempts; the run stops after three blocked tasks in a row. Studio-only gaps are committed as BLOCKED with a follow-up task.
- On any blocker the work is secured (commit to `main` if checks and review pass, otherwise a local `wip/<ID>` branch), and the planner writes a machine-readable entry in "Für den Owner am PC" (top of CLAUDE_BACKLOG.md) with the owner's steps, a check, the blocked tasks and the follow-up task. Whenever a run ends before everything is done, the planner (Opus) refreshes the whole backlog assuming the owner resolves every PC entry; the next run checks those entries first.
- Empty backlog: gap check limited to gaps traceable to PRODUCT_SPEC, the milestone gates or TEST_PLAN; none found ends the run.
- Triggers: `/hasseln`, "durcharbeiten", "mach weiter", "weiter", "hustle" ("hasseln").
- Origin: owner. Files: `.claude/skills/hasseln/SKILL.md`, `.claude/hooks/route-prompt.js`, `CLAUDE.md`, `docs/CLAUDE_BACKLOG.md`.

## 2026-11-22 — owner: token budget for the agent pipeline
- Measured on the real session logs: CM2-G6 (tier S) cost about 6 USD API equivalent; the planner took 3.26 USD of it and wrote a 424-line plan. Agents start at about 13k tokens of context, the main chat at about 92k.
- Previous rule: every agent read all seven documents of "Read before changing code" in full; plans had no length limit; PROGRESS.md held the full history.
- New rule: agents read only the sections a task touches (CLAUDE.md, "Read before changing code"); the planner has a line budget per tier (S 150, M 250, L 400, MODEL 150) and proposes a split when a task does not fit; PROGRESS.md keeps the latest entries and older ones move unchanged to `docs/archive/`.
- Fix: the planner may write `docs/CLAUDE_BACKLOG.md` when `hasseln` or `cm2-plan` asks for a backlog update (it was limited to `docs/plans/`, which blocked the hasseln blocker entries).
- Not in the repository: account plugins unrelated to this project (Unity, small business, legal, design tools and others) fill most of the main chat's 92k starting context; the owner turns them off in the Claude app.
- Origin: owner. Files: CLAUDE.md, .claude/agents/planner.md, docs/PROGRESS.md, docs/archive/.

## 2026-11-22 — owner: push every commit automatically
- Previous rule: commits stayed local; the owner pushed (hasseln question Q7).
- New rule (owner): every commit is pushed to `origin` right away by whoever commits (reviewer, hasseln, main chat), including `wip/<ID>` branches. Never force-push, never merge on the remote, never publish. A failed push is recorded as a blocker.
- Files: CLAUDE.md, .claude/agents/reviewer.md, .claude/skills/hasseln/SKILL.md.

## 2026-11-22 — owner: faster pipeline (minor details, batched Studio runs)
- Measured overnight (10 tasks, about 50 min each): planner 34 %, implementer 33 %, playtester 30 %, reviewer 4 % of the time; about 15 plan-amendment rounds, some only for local names or lint warnings.
- New rule A (owner): implementers decide minor details themselves (local and private names, helper splits, comments, formatting, order of independent edits, lint fixes) when nothing visible to players, other modules, saves or remotes changes, and list them as "Own decisions"; the reviewer rejects anything beyond that.
- New rule B (owner): Studio playtests are batched. Test now for tier L or MODEL, save data, money, inventory, purchases, world geometry or a milestone's last task; otherwise the task is committed after headless checks and review with "Studio: deferred (batch)" and queued in "Studio-Test ausstehend" (CLAUDE_BACKLOG.md); the third queued task triggers a batch run (full repeatable run plus each plan's steps). hasseln runs the queue before a run ends.
- Rejected: fast mode (twice the token price).
- Files: CLAUDE.md, .claude/agents/implementer.md, playtester.md, reviewer.md, .claude/skills/cm2-task/SKILL.md, .claude/skills/hasseln/SKILL.md.

## 2026-11-22 — owner: keep files small
- Found: DECISION_LOG.md 70 KB, CLAUDE_BACKLOG.md 56 KB, PROGRESS.md 44 KB again one night after archiving; plans met the line budget with very long lines (CM2-S1 52 KB); RunPlaytest.lua 2461 lines and SaveSlotService.lua 1803 lines.
- New rules: the reviewer archives PROGRESS.md whenever it passes 20 KB (latest five entries stay); the planner budget is in KB (S 12, M 20, L 30, MODEL 12; an amendment at most 4 KB) instead of lines.
- New task CM2-RF (launch order 9a, after CM2-N1): split RunPlaytest.lua and SaveSlotService.lua without behaviour change.
- Files: .claude/agents/reviewer.md, .claude/agents/planner.md, docs/CLAUDE_BACKLOG.md.

## 2026-11-22 — owner: the modeler builds in Blender
- Previous rule: the modeler built Parts and self-reviewed through Studio screen captures, which fail while the Studio viewport is 1x1 (PC-3).
- New rule (owner): models larger than a few simple blocks are built in Blender 5.2 from a committed Blender Python build script (headless, no imported meshes) and go through the CM2-AP pipeline (export budget check, render previews, upload and normalize when the PC-2 key exists). Self-review compares the rendered previews with docs/art/quality-reference in up to three rounds. Small items and blockout stay Parts.
- Reviewed and not adopted: github.com/kevinbadi/blender-skills (no licence, needs the interactive blender-mcp addon, mainly product camera animations, paid Meshy image-to-3D generation and Poly Haven textures, which conflict with original geometry and the no-texture palette rule).
- Files: .claude/agents/modeler.md.

## 2026-11-22 — owner: cm2-modeling skill and Blender kit
- New project skill `cm2-modeling` (.claude/skills/cm2-modeling/SKILL.md, about 4.5 KB): build-render-compare workflow, kit interface table, style rules and budgets for Blender models. The modeler loads it for every MODEL task.
- New kit `tools/art/kit/cm2_kit.py`: low-poly building blocks (box, cylinder, cone, ball, prism, planks, post, gable roof with snow, snow cap, fir with snow, string lights, wheel, awning, collider, attachment) and `K.run`, which joins one MeshPart per palette colour, checks the tier budget and saves model.blend. Agents use the interface table instead of reading the code (token budget).
- Verified 2026-11-22: the example `tools/art/kit/examples/market_stall.py` builds headless in Blender 5.2 (1392 triangles, 8 MeshParts, tier A), passes `art.luau export` and renders; a first render found an inverted roof and hidden tree snow, both fixed.
- Files: .claude/skills/cm2-modeling/SKILL.md, tools/art/kit/, .claude/agents/modeler.md, CLAUDE.md.

## 2026-11-22 — owner: UI redesign last, before release
- Owner: the UI looks poor (plain frames, layout). It is not redesigned feature by feature. Until shortly before release the UI stays functional in its current style; the visual redesign is the last task before release, so it is done once.
- Rule until then: new screens use only `src/shared/UiTheme.lua` tokens and `src/client/UiKit.lua` builders (no hard-coded colours, fonts or sizes, no image assets), so the redesign is mostly a theme and asset swap.
- Placement (planner): CM2-UI is launch order 22a, after the last Gate B feature task (CM2-43) and before CM2-47 QA, so QA, the release candidate and the Go/No-Go regression run on the new UI. Gate C screens (Analytics, decor catalog, event shops) are built after it in the new style.
- Graphics source (owner to choose before CM2-UI starts): an AI UI generator (for example ForgeGUI), a CC0 set (for example Kenney UI packs) or a bought kit with a written licence for commercial use in Roblox. Fallback if nothing is supplied: a CC0 set. Licence and source go to `assets/third_party/<set>/` and this log (CC0 precedent 2026-11-21).
- Files: docs/PRODUCT_SPEC.md (UI look), docs/CLAUDE_BACKLOG.md (rules for the order, order 22a, owner inputs).

## 2026-11-24 — owner: the reviewer runs on Sonnet
- Owner: the Opus reviewer is too expensive for what it does. The `reviewer` agent now runs on Sonnet 5.5 for every task, including tier L (saves, money, inventory, security). Planner decision: high effort instead of medium, so the diff-against-plan review keeps depth on tier L tasks; still far cheaper than Opus.
- Considered and not chosen: Opus only for tier L (the reviews of CM2-S1 and CM2-G7 found CM2-R5 and CM2-G7a); dropping the reviewer.
- Files: .claude/agents/reviewer.md, CLAUDE.md, .claude/skills/cm2-task/SKILL.md, docs/PRODUCT_SPEC.md.

## 2026-11-24 — owner: the playtester runs on Haiku
- Owner: replace Sonnet with Haiku where it is safe. The `playtester` agent now runs on Haiku 5.5 (no effort setting). It mostly runs the scripted `runPlaytest` and plan steps and reports PASS, FAIL or BLOCKED with evidence. New rule: on a FAIL it quotes the raw console output and does not diagnose; the planner diagnoses failures.
- Kept on Sonnet: implementers S and M (strict Luau, rework through review would cost more), the reviewer (last check before the commit), the orchestrating chat (decides blockers and the next task).
- Revert: if the playtest reports get too thin, set `model: claude-sonnet-5-5` and `effort: medium` in .claude/agents/playtester.md again.
- Files: .claude/agents/playtester.md, CLAUDE.md, .claude/skills/cm2-task/SKILL.md, docs/PRODUCT_SPEC.md, docs/plans/TEMPLATE.md.

## 2026-11-24 — owner: UI graphics from the Essential UI Pack (Swarve Studios)
- Owner: CM2-UI uses the "Essential UI Pack" by Swarve Studios (owner's local `.rbxl`).
- Inspection (engineering, Lune, the file's scripts not run): one ScreenGui with a simulator-style HUD (left button rail, money and strength labels), frames Shop, Upgrades, Rebirth, Index, Wheel and Notifications; 68 Frames, 82 TextLabels, 29 TextButtons, 79 ImageLabels (all ScaleType Stretch, no 9-slice), 113 UIStrokes, 22 UIGradients; about 40 image IDs and 2 sound IDs uploaded by the author, no image files in the pack; fonts Gotham SSm, Source Sans Pro, Builder Sans and one font asset. Scripts: hover and click tweens with sounds, leaderstats coins and strength through `Touched`, four scripts that each set `ProcessReceipt`. No backdoor patterns found (no `require(<id>)`, `getfenv`, `loadstring`, `HttpService`).
- Rule (planner): only the look is used (styling values rebuilt in `UiTheme`/`UiKit`, icons, the button tween and sounds). Its scripts, remotes, leaderstats and the paid wheel are not used; they conflict with server authority, the action protocol and "no paid random items in version 1". Icons for strength, gems and dumbbells are replaced with Christmas-market icons; colours are recoloured to the palette.
- Licence: unknown. The pack's README names only a Discord invite and swarve.lol (unreachable on 2026-11-24); a BuiltByBit listing with a similar name ("Essential STUD UI Pack", ProfileStore, 11+ systems) describes a different, larger product. Precondition for CM2-UI: a written licence from Swarve Studios in `assets/third_party/swarve-essential-ui/LICENSE.md`; without it CM2-UI falls back to a CC0 set.
- Files: docs/CLAUDE_BACKLOG.md (CM2-UI (b), owner inputs).

## 2026-11-24 — CM2-UVF8 (engineering)
- The shop category bar no longer scrolls. The 7 tabs share the width, with text scaled 9–13 px.
- The Cash Rush line sits at the top right of the shop in every category.
- PREFLIGHT clears boosts and R's pass overrides.
- CM2-UVF8 A1: the full-run PREFLIGHT sets R's Lot Worker and Cashier to 0 (`setStaff` takes an optional `userId`) and names the reset in its detail, because manual checks left a Lot Worker on R's save.
- CM2-UVF8 A3: ChatTags assigns `TextChatService.OnChatWindowAdded` with `ChatWindowConfiguration:DeriveNewMessageProperties()`, the documented hook for chat-window prefixes; `OnIncomingMessage` produced no [VIP] line.

## 2026-11-24 — owner: planner by tier
- Owner: the product questions are settled (grill-me interview), so the Opus planner at high effort for every task costs too much. The planner now depends on the task's tier:
  - Tier S runs without a plan. The `implementer` works from the backlog entry (goal and acceptance criteria) and stops at once on the save schema, money, inventory, purchases, remotes or any choice it may not make; then `planner` writes a plan. The reviewer checks the diff against the entry and returns "re-plan needed" on the same triggers.
  - Tier M and MODEL: `planner`, Opus 5.5 at medium effort. If the task turns out to be tier L, it stops with "ESCALATE TIER L" and `planner-high` plans it.
  - Tier L (saves, money, inventory, security, concurrency, bugs of unknown cause): new agent `planner-high`, Opus 5.5 at high effort.
- Source of the tier: an existing plan, else the tier estimate on the backlog line; without one, an unknown-cause bug counts as L and the rest goes to `planner`. Amendments go to the planner of the plan's tier.
- Unchanged: planning with the owner in the chat (`cm2-plan`, Opus high), the implementers, modeler, playtester and reviewer.
- Revert: set `effort: high` in .claude/agents/planner.md and remove the S branch in step 1 of `cm2-task`.
- Files: .claude/agents/planner.md, .claude/agents/planner-high.md, .claude/agents/implementer.md, .claude/agents/playtester.md, .claude/agents/reviewer.md, .claude/skills/cm2-task/SKILL.md, .claude/skills/cm2-plan/SKILL.md, CLAUDE.md, docs/PRODUCT_SPEC.md, docs/CLAUDE_BACKLOG.md, docs/plans/TEMPLATE.md.

## 2026-11-24 — owner: own UI look, Swarve pack dropped
- Owner: Swarve Studios did not answer the licence request, and waiting costs more than the pack is worth. CM2-UI uses no bought or third-party UI set; the 2026-11-24 entry "UI graphics from the Essential UI Pack" is superseded.
- Target look (PRODUCT_SPEC "UI look"): calm cream panels, dark green and gold as accents, muted red only for close and danger; heavy rounded type; tap targets at least 48 px (primary 56 px on phone); hover grows, press shrinks, soft click; thick outlines, rounded corners, soft shadow.
- Planner decisions: hover 106 %, press 95 %, 0.1 s tween through a `UIScale` so layout does not move; the font is picked in the CM2-UI plan from Roblox's built-in heavy fonts after a Device Simulator comparison. CM2-UI stays the last task before release (owner decision 2026-11-22).
- Files: docs/PRODUCT_SPEC.md, docs/CLAUDE_BACKLOG.md (22a (b), (c), (e); owner inputs).

## 2026-11-24 — CM2-13a and CM2-13b import branch I (engineering)
- Import: the 4 HQ tiers and 6 lot props were uploaded and normalized with yaw 0 (`IMPORT_YAW_DEGREES` stays 0, CM2-12 probe). Model asset IDs: SalesTent 76796067556800, TimberPavilion 129908851202139, AlpineHut 96170871620807, MountainChalet 80346869419890, CheckoutCounter 86195605998455, ReceivingBay 71806299594619, TreeBundle 92004701506028, FenceRail8 81344383315482, FenceRail6 130024785437685, FencePost 80498840265993. The four buildings normalize with scale 0.0100 / 0.0115 / 0.0136 / 0.0152 (the importer shrank meshes larger than about 2048 units; `normalize` reads the scale from `report.json`, final sizes are correct).
- Deviation (implementer-side fix outside the plans' file list, accepted by the reviewer): `tools/art/lib/Normalize.luau` set `Attachment.Position`, which Lune does not serialize, so every attachment in the saved `.rbxm` sat at (0, 0, 0). It now sets `Attachment.CFrame`; test N10 saves and reloads the model (fails without the fix). The 14 CM2-12 trees are unaffected (their only attachment `TreeBase` is at (0, 0, 0), confirmed by reading a tree `.rbxm`).
- SalesTent H is 10.05 against the plan's 10.0 +- 0.3: accepted. Play checks (row-clone captures, `runPlaytest full` with `ART_ASSETS`, no `[ART]` warning) are BLOCKED by PC-9 and queued; CM2-13a, CM2-13b and CM2-13 are not ticked.
- Files: assets/art/rbxm/{Buildings,Props,Environment}/*.rbxm, assets/art/source/**/asset.json, tools/art/lib/Normalize.luau, tests/tools/art_pipeline.luau.

## 2026-11-24 — owner: Robux products created (PC-8)
- Source: reported to the orchestrator by the owner's other Claude session (~19:30); the IDs were not typed by the owner in the hasseln chat. That session checked them with an Open Cloud list GET at 18:32Z (universe 10777859950): all 12 `isForSale = true`, prices as in `docs/RELEASE_CHECKLIST.md`. Icons are own art previews from `assets/art/previews`. The other 15 products were not created. Engineering created and activated nothing.
- Game passes (Config-Key → ID, name, Robux): PassCashX2 → 2101828296 (Golden Till, 99); PassReputationX2 → 2099729097 (Shining Star, 79); PassInstantDelivery → 2099165138 (Express Sleigh, 149); PassVip → 2098973055 (Evergreen VIP, 199).
- Developer products: StarterPack → 3735805319 (Tree Lot Starter Kit, 79); CashPinecone → 3735805373 (Pinecone Purse, 29); CashSleigh → 3735805396 (Sleigh Sack, 99); CashCabin → 3735805416 (Cabin Chest, 249); CashVillage → 3735805452 (Village Vault, 599); CashMountain → 3735805469 (Mountain Treasury, 1499); BoostCashX2 → 3735805526 (Cash Rush, 10); BoostRested → 3735805549 (Hot Cider Round, 5).
- Planner decision: PC-8 is resolved; CM2-46c (line 13c) enters these IDs only after a Studio `MarketplaceService:GetProductInfo` check of all 12 returns the expected name and price (any mismatch stops CM2-46c with a report). Publication stays the owner's action.
- Files: docs/CLAUDE_BACKLOG.md (PC-8, line 13c, N3, run record), docs/DECISION_LOG.md.

## 2026-11-24 — CM2-14 import branch I (engineering)
- Import: the 4 vehicles were uploaded and normalized with yaw 0 and scale 0.0100. Model asset IDs: SupplierTruck 130326245862058, CustomerHatchback 92060776256909, CustomerWagon 111886456380527, CustomerSuv 105457478334599. Sizes in the plan (Truck 5.98 x 6.00 x 13.01, Hatchback 5 x 4 x 8, Wagon 5 x 4 x 9, Suv 5 x 4.6 x 9); `CargoAnchor` positions read back from the saved `.rbxm` are correct (the Normalize CFrame fix from the CM2-13a/13b import applies).
- Play checks (capture with bundle stand-ins and `Paint` colour, `runPlaytest full` with `ART_ASSETS`, no `[ART]` warning) are BLOCKED by PC-9 and queued; CM2-14 is not ticked. Wiring stays CM2-14W.
- Files: assets/art/rbxm/Vehicles/*.rbxm, assets/art/source/Vehicles/*/asset.json.

## 2026-11-24 — CM2-10a, CM2-10b and CM2-10c import branch I (engineering)
- Import: the 13 map models were uploaded and normalized with yaw 0. Model asset IDs (scale): Buildings/CoveredBridge 109589026509855 (0.0274), Environment/VillageTree 110105358193881 (0.0217), Props/LeaderboardBoard 105589306514399 (0.0100), Buildings/VillageHouse 137762068173947 (0.0113), Props/SignBoard 132704641565793 (0.0100), Props/LampPost 87108177014078 (0.0100), Props/Bench 117040393139740 (0.0100), Environment/MountainRidge 136804962948038 (0.1465), MountainPeak 112662539846046 (0.1074), ForestFir 118200481007814 (0.0100), ForestClusterA 119118625032761 (0.0129), ForestClusterB 119327449245936 (0.0100), RockCluster 100391001748906 (0.0100). Sizes and attachments match the plans and `MapLayout.ART`.
- Studio (Edit and Play, instance `d0521b88`): the 13 models sit at their plan paths; `MapLayout.plan` 302 placements, art 302, fallback 0, skip 0, missing 0; `runPlaytest full` PASS 62/62 with `ART_ASSETS` 41 Blender models, 238 meshes, 0 failed, 0 duplicates and `MAP_WORLD` overlaps 0, server fps 60. A Rojo live-sync glitch dropped the PrimaryPart of VillageHouse once in Edit mode; touching the `.rbxm` timestamp fixed it, no repo change. Not read: a `[ART]` warning line in the Play log (the log had rotated past startup; recorded as inferred from `MAP_WORLD` art 302).
- Not done, BLOCKED by PC-9 (black Play viewport): the captures of CM2-10a/b/c playtest step 2 and the CM2-10W bridge and square art re-check captures; queued in "Studio-Test ausstehend". CM2-10, CM2-10W and CM2-10a to 10c are not ticked.
- Files: assets/art/rbxm/{Buildings,Environment,Props}/*.rbxm (13 new), assets/art/source/<artPath>/asset.json (13).

## 2026-11-24 — owner: recurring repo hygiene task CM2-SLIM
- Owner: the repo grows faster than it should (about 27,000 lines in `src`, a 175 KB backlog and a 145 KB decision log that agents read every task). A clean-up task runs again and again, at the smallest tier that fits.
- Planner decisions: tier S (no planner, `implementer` on Sonnet medium). Due after 8 `feat`/`fix` commits since the last run, when the backlog or decision log passes 80 KB or `CLAUDE.md` 16 KB, and before CM2-47 and CM2-48; `hasseln` checks this before it picks each task. Budgets, method, what it may fix itself and what it only files are in the backlog section "Recurring task: CM2-SLIM".
- It may archive and shorten docs and delete dead files and client, test and tool code with grep evidence. Dead code in server or shared modules and near saves, money, inventory, purchases or remotes becomes a follow-up task; splitting big Luau files waits until after CM2-48.
- Archived decision-log entries stay binding; CLAUDE.md now says to grep `docs/archive/DECISION_LOG_*.md` too.
- Files: docs/CLAUDE_BACKLOG.md, .claude/skills/hasseln/SKILL.md, CLAUDE.md.

## 2026-11-24 — owner: plot picker at session start (CM2-PP)
- Owner: the reference lets the player choose the plot from a camera view over the map; ours assigns the first free plot. Add the picker.
- Planner decisions: only the first player of a save on a server picks; teammates and reloads attach as today. Nothing is reserved while browsing; the server claims the plot only if it is still free on confirm, else `PlotTaken`. `Save.Play` without a plot id keeps the automatic choice, so tests and old clients keep working. Tier L (claim path and a new action), order 17a in the launch order, before QA (23) and the UI redesign (22a).
- Files: docs/CLAUDE_BACKLOG.md (17a), docs/PRODUCT_SPEC.md.

## 2026-11-25 — Swarve Studios licence received
- Swarve Studios answered the owner's ticket (2026-11-25): any use, modification and re-upload is allowed, no credit required; only reselling or charging money for the assets themselves is not. Record: `assets/third_party/swarve-essential-ui/LICENSE.md`.
- The `.rbxl` stays out of the public repository (`.gitignore`). The CM2-UI look stays as decided on 2026-11-24 (own cream look); whether CM2-UI also uses the pack's pieces is the owner's call.

## 2026-11-25 — owner: CM2-UI built on the Swarve pack, also in the template
- Owner: "wir nutzen alles und bauen unsere UI darauf". Replaces "own UI look, Swarve pack dropped" (2026-11-24): CM2-UI uses the pack's layout patterns, images, icons, fonts, strokes, gradients, sounds and button tween (110 % hover in 0.2 s, 90 % press in 0.1 s). The rule of 2026-11-24 "only the look is used" stays: no pack scripts, remotes, receipt handlers, leaderstats, rebirth or paid wheel.
- Planner decisions: the cream direction of 2026-11-24 still decides panel fills, text colours and tap sizes; a clashing pack image is tinted or re-uploaded recoloured. Pack asset IDs are tried first; IDs that do not load in our place are re-uploaded under the owner's account (PC-2). Contents and IDs: `assets/third_party/swarve-essential-ui/INVENTORY.md`.
- Owner: the pack goes into the template repo, usable but not forced. The template gets the licence record, the inventory and a gitignored slot now; the reusable kit follows as 22b **CM2-UI-TPL** (tier S, after CM2-UI), off by default. The `.rbxl` is not committed to either public repo: the licence forbids only reselling, but a public copy would hand the whole pack to anyone; the owner's games get everything they need from the IDs and rebuilt values.
- Files: docs/CLAUDE_BACKLOG.md (22a (b), (c), 22b, launch order, N7), docs/PRODUCT_SPEC.md ("UI look"), assets/third_party/swarve-essential-ui/INVENTORY.md.
- Superseded for the game by 2026-11-26 "owner: own polished UI, no Swarve pack in the game"; the template part stays.

## 2026-11-25 — decision-log archive window and CM2-SLIM follow-ups (planner)
- The 14-day window of CM2-SLIM moved nothing (the oldest entry is 6 days old) and left the log at 147 KB against 60 KB. New rule: keep the top sections, every owner entry and every entry dated on the run day or the day before; every other entry goes unchanged to `docs/archive/DECISION_LOG_<first>_to_<last>.md`. Archived entries stay binding and grep-findable. If still over 60 KB, an owner entry that a later owner entry supersedes may move with a one-line pointer. Applied once by CM2-SLIM3, then by every CM2-SLIM run.
- CLAUDE.md (15.7 KB against 12 KB) is trimmed by wording and pointers only (CM2-SLIM5, planner text, implementer applies it); owner approval only if a binding rule would change.
- `Quest.Claim` stays: server handler and validator are the scaffold for CM2-G11. Splits of Luau files over 800 lines run after CM2-50a (25a-25c), so the release candidate stays unchanged.
- Files: docs/CLAUDE_BACKLOG.md (CM2-SLIM section, CM2-SLIM1..5, 25a-25c, line 18 note).

## 2026-11-25 — owner: drop PC-9 (Studio FPS and world captures are not required)
- Owner (chat, in reply to the PC-9 explanation): "wir scheißen auf all das, streich das alles weg, das sind ja nur Tests".
- FPS measurements (desktop and phone) and world/art captures (Play `screen_capture` of the 3D world) no longer gate any tick and are not run. PC-9 is closed as dropped.
- Still counting: numeric and automated checks that need no capture: headless tests, `runPlaytest {mode="full"}`, `ART_ASSETS`, `MAP_WORLD`, Edit-mode steps (incl. `PreloadAsync`), HUD/GUI readings (sizes, positions, probe, HUD captures).
- Performance stays a goal, not a gate. A performance task is created only if a player-visible problem is reported.
- Planner consequences: CM2-12, CM2-13a, CM2-13b, CM2-13, CM2-14, CM2-10a, CM2-10b, CM2-10c, CM2-10 and CM2-10W ticked (their remaining checks had passed 2026-11-24); the `[ART]` log line is a non-blocking note under CM2-ASSETWARN; line 17 waits only on CM2-G12b; CM2-UV2 drops j1/j6; CM2-49 keeps its numeric touch flow; capture and FPS clauses in later Accepts no longer gate.
- Files: docs/CLAUDE_BACKLOG.md (PC-9, queue, lines 5h, 14, 17, 22a, MODEL tasks, Next run), docs/PRODUCT_SPEC.md ("Testing").
- Finding (owner-provided probe from another session, 2026-11-25 ~18:10, main @ be3489e): Play capture shows the 3D world (1564x730, no longer black); client RenderStepped over 10 s mean 15.0 FPS (min 14.6, max frame 68.5 ms), so the 15-FPS cap persists but no longer gates; Rojo in sync (live Studio has the CM2-UVF13 code); console: `rbxassetid://203785492` warning 5x, no Lua errors.

## 2026-11-25 — owner: compact UI on phone (CM2-UI)
- Owner: the new UI must be smaller, otherwise it is far too big on a phone.
- Previous rule: "Big tap targets", buttons at least 48 px on phone, primary 56 px (2026-11-24). New rule: buttons 44–52 px (today's `UiTheme.MinTouch` 44 stays the minimum); on phone every window at most 70 % × 80 % of the safe area, HUD at most 20 % of the screen, body text 14–16 px, titles at most 24 px, and no screen bigger on phone than before CM2-UI. The pack's frame sizes are not taken over; its images are scaled into these boxes.
- Planner decisions: the limits are checked headlessly from the `UiTheme` layout functions for the phone sizes in `UiTheme_Test` (box areas and sizes, a baseline of today's phone boxes taken before CM2-UI starts) and visually in the Device Simulator shots. Hover growth (110 %) runs through a `UIScale` and does not count against the limits.
- Files: docs/PRODUCT_SPEC.md ("UI look"), docs/CLAUDE_BACKLOG.md (22a (c), (e)).

## 2026-11-25 — Tutorial customer and pick diagnostics, CM2-SALE1 (engineering)
- Cause: no broken code path; the demand model refused every pick on the one-tree tutorial lot. Exact preference lets only 1 of 12 customers want Douglas Medium, and that customer converts at 0.026 (price 0.65 × reputation 0.59 × variety 1/3 × stock 1/5), so about 0.2 % of visits buy.
- Decision: on tutorial step `Checkout` the walking customer's pick ignores preference, budget and roll and takes the first unreserved displayed tree (sorted placement IDs) at its current price (`Tutorial.guaranteesSale`, `CustomerSelection.chooseGuaranteed`; PROVISIONAL, the reference tutorial is not observed). The guarantee depends only on the saved tutorial step and ends with the first sale (`Sold` → `Done`) or a skip. Money stays server-authoritative: the price comes from `state.mediumPrices`.
- `npcDecide` reports `NoStock` instead of `NoEligibleStock` when every displayed tree is reserved.
- `npcSnapshot` gains `decision` per visit and `decisionLog` (the last 20 picks); `npcReset` clears it.
- `forceCustomer n` now sets the per-save arrival override (profile `n`, roll 0, like `npcNextArrival`) for every loaded save; the server-wide forced roll (`forcedRolls`, `setForcedRolls`) is removed because the next `npcDecide` of any visit took it.
- Correction of the backlog counter note (14a): visits are counted only in `beginVisit`, and `npcArrive` refuses an empty lot before counting, so all visits and drive-pasts of the N1 reading saw the tree; the baseline was read after placement.
- Follow-up (out of scope here): early-lot demand after the tutorial stays low (about 1.1 % per visit for 6 Douglas Medium, 3.2 % for a mixed lot); a tier M task tunes it before Gate B.
- Files: src/shared/Tutorial.lua, src/shared/CustomerSelection.lua, src/server/Services/CustomerSimulationService.lua, src/server/Services/CompanyStateService.lua, src/server/Services/CustomerNpcService.lua, src/server/Services/StudioTestService.lua, src/server/main.server.lua, docs/GAME_DESIGN.md (§5), docs/TEST_PLAN.md (§3b).

## 2026-11-25 — line 14 timing rule for agent-driven runs (planner proposal, reviewer finding: not adopted)
- Context: the N1 (b) re-run (Studio af5facc4, iPhone 7 666x374, fresh Solo save "Tree Lot 316") passed every functional and layout step of CM2-49; wall clock from save creation to `tutorial.step == "Done"` was about 341 s (28 s create to `Order`, 28 s `Order`, about 248 s `Stock`, 37 s `Checkout`), agent tool latency and test-client `Humanoid:MoveTo` retries included. The Accept says "a fresh save completes the tutorial in under 3 minutes on the phone simulator".
- Proposed rule (planner): in an agent-driven run, judge the time per tutorial step. A step counts at its measured time; a step made only of player actions (no game-imposed wait such as delivery ETA or customer arrival) that passed functionally counts at most 60 s, because agent latency and test-client retries are not player time. Applied: 28 + 28 + 60 + 37 = 153 s < 180. An owner hand-test over 3 minutes reopens line 14.
- Reviewer finding: the rule does not cover the step it was used on. The 248 s step is `Stock`: it contains the game-imposed delivery ETA (`GameConfig.DeliverySeconds` = 30 s, plus unloading), so under the rule's own wording it counts at its measured time, and the total stays 341 s. Even a 30 s wait plus the 60 s cap gives 28 + 28 + 90 + 37 = 183 s, over 180. The 60 s cap is also not derived from a measurement of agent latency.
- Decision (reviewer, within the backlog): line 14 stays open; the functional PASS is recorded in PROGRESS and in the line 14 status. The rule is kept here as a proposal only. Line 14 closes on (a) an owner hand-test of a fresh phone save under 3 minutes to `Done`, or (b) a planner decision on a rule backed by a measurement that separates agent latency from game time, for example server-side timestamps of the step changes read after the run. No `src` change.

## 2026-11-26 — Early-lot demand, CM2-SALE2 (engineering)
- Problem: CM2-SALE1 found that a fresh 6-tree Douglas Medium lot converted only about 1.1 % of visits, because a customer wanted exactly its preferred species and size and variety (1/3, 2/3, 1) and stock (0.2, 0.4, 1) factors were harsh for a starter lot.
- Decision (all PROVISIONAL, `GameConfig.Demand`): preferences are soft. A customer considers every displayed tree within its budget percent (85-155 %) applied to that tree's own benchmark (`CustomerProfile.budgetFor`) and picks the highest-scoring one (ties keep the first sorted ID). Interest in the tree: exact species and size 1, same species 0.85, same size 0.75, other 0.65 (`Demand.score` gains an optional `interest`). varietyFactor 0.85 / 0.925 / 1 for 1 / 2 / 3+ species; stockFactor 0.6 + 0.4 × unreserved trees / 5, capped at 1. Price factor, reputation factor, clamp 0.02..0.95 and the roll are unchanged.
- Simulation (`DemandSimulation_Test`, 1000 visits, reputation 90, default prices, seeds 1-3): 1 Douglas Medium 0.125-0.130 (target 0.10-0.16); 6 Douglas Medium 0.188-0.190 (0.16-0.23); mixed 2 S + 2 M + 2 L Douglas 0.204-0.208 (0.18-0.25); full 12-tree assortment 0.301-0.303 (0.25-0.35).
- Late game unchanged: the full assortment stays at about 30 % as before. No guaranteed purchase (clamp 0.95 and the roll stay); the tutorial guarantee (CM2-SALE1) is unchanged; no save field, remote or sale-path change.
- Files: src/shared/GameConfig.lua, Demand.lua, CustomerProfile.lua, CustomerSelection.lua, docs/GAME_DESIGN.md (§4, §5), docs/TEST_PLAN.md (§2).

## 2026-11-26 — Leaderboards (CM2-G12b, engineering)
- Plan: `docs/plans/CM2-G12b.md`. Config `GameConfig.Leaderboards`, cache and writes in `src/server/Services/LeaderboardService.lua`, rows and formats in `src/shared/LeaderboardView.lua`, screens in `src/client/Leaderboards.client.lua`.
- Art boards: the art's own Screen mesh is renamed ScreenPanel at build, so Board_<Key>.Screen is the one Part the SurfaceGui adorns (amendment 1).

| Topic | Decision |
|---|---|
| Per save vs per player | Cash earned and Reputation are **per save** (one shared company, plot and cash in co-op saves); the row shows the save owner's username. Hours played and Robux spent are **per player**. |
| Co-op "You" row | Every member sees the rank and value of the save they are playing. |
| Cash earned | `state.revenue` (sales and tips; Robux cash packs never count). Reputation = `state.reputation`. Robux spent = the ledger's `robuxSpent` (CM2-46a). |
| Hours played | Seconds with an active, ready save (`CompanyReady`), counted in 10-s ticks; stored as integer seconds by `IncrementAsync` deltas (the ordered store is the only record; a double increment after an ambiguous error is accepted, at most one flush). Shown in hours with one decimal. |
| Keys | `player_<userId>` and `save_<saveId>` (both contain the user ID; RTBF rule, roblox-server-data). |
| Stores | `ChristmasMarket2_LB_<Key>_v1`; in Studio with suffix `_Studio`, so test values never reach the live boards. |
| Zero | A value of 0 that was never written is not written. |
| Names | Usernames only (no display names, no save names); unknown → localized "Player". |

## 2026-11-26 — Tree art in the world, CM2-12W (engineering)
- Plan: `docs/plans/CM2-12W.md`. Five roles: Display, Pickup, Carried (player), NpcCarried (customer and staff) and Roof; the backlog's "forest" role was already art through CM2-10W (`MapWorld` unchanged, step 64 only confirms it).
- Scale rule (`src/shared/TreeArt.lua`): Display and Pickup use the art at native size (H 6/8/10); Carried, NpcCarried and Roof scale the art to `11.5 x primitive scale` (Carried 4.6, NpcCarried 4.025 / 4.6 / 5.175, Roof 4.025); a carried art tree drops by `2.5 x scale` so its foot matches the primitive's.
- Label rule: label height = tree top + `UiTheme.WorldLabels.<layout>.height` (+ stagger). `WorldLabels.DisplayTree.height` 10 -> 1.0 and `WorldLabels.PickupOrder.height` 9 -> 1.5 (stagger 2 stays); both now mean studs above the tree top.
- Foot at the lot top: display trees 0.6 -> 0.55, pickup trees 0.9 -> 0.55 (`lotTop` = ground top).
- Staff projection fields: `staffPeekOrder` and `staffPeekRestock` return `speciesId` (read-only; no save field, remote, error code or string key changes), so staff and customers carry the right species.

## 2026-11-26 — Owner: PassCashX2 test purchase skipped (N3b, CM2-46c)
- Owner decision in chat ("gar nicht testen"): CM2-46b playtest step 7b (PassCashX2 test purchase) is not run, because the test account already owns the pass. Gate A line 13c is ticked on 7a, 7c, 7d and the idempotency replay (PROGRESS 2026-11-26 N3b). The simulated pass path stays covered by CM2-46a steps 51-53. No code or config change.

## 2026-11-26 — CM2-PP engineering decisions
- Plan: `docs/plans/CM2-PP.md` (owner decision "plot picker at session start", 2026-11-24). Picker UI in `src/client/PlotPicker.lua`, server parts in `SaveSlotPicker.lua` ("Plot picker (CM2-PP)") and `PlotService.claimExact`.

| Topic | Decision |
|---|---|
| New action | `Save.Plots {saveId}` returns the plot list for that save; rate limit 20 per 10 s (like `Save.List`, PROVISIONAL). |
| Who picks | `pick = true` only when the save holds no plot here, nobody plays it here, no load of it is pending or unloading, it is not the caller's active save and at least one plot is free for the caller; otherwise the client sends `Save.Play {saveId}` at once (attach, or the automatic/teleport path). |
| Chosen play | `Save.Play {saveId, plotId?}`: without `plotId` the automatic claim is unchanged; with it, attach paths ignore it, otherwise the server claims exactly that plot if still free, else `PlotTaken` (other plots free) or the no-free-plot path (none free). Nothing is reserved while browsing. |
| Own current plot | The plot of the caller's active save counts as free when the caller is its only player here and it is neither loading nor unloading (a switch releases it before the claim). |
| Pre-check | `PlotTaken` is decided before the current save is left, so an obvious refusal never drops the running save; the claim after the leave stays authoritative. |
| Last plot | Profile entry field `lastPlotId: string?` (1-32 bytes; written on every play and attach), no `SaveProfile.VERSION` bump (precedent `tutorialOffered`, CM2-49); an id the server does not know is ignored. Preselect = `lastPlotId` if free for the caller, else the first free plot in config order. |
| Road side | `MapLayout.PLOTS[number].z < 0` is `"South"`, else `"North"` (plots 1-3 south, 4-6 north of the main road). |
| Occupant name | The lot sign's public text (`WorldService.lotSignName`: the broadcast-filtered save name or "<user>'s Tree Lot"); nil while the sign shows "Lot available". Raw save names never leave the server. |
| Teleport arrival | A `cm2NoFreePlot` arrival no longer auto-plays: the server stores `{saveId, attempt}` per player (`noteArrival`) and sets the player attribute `PlotPickSaveId`; the client opens the plot picker for that save. A later `Save.Play` of the same save uses the stored attempt, so `MaxPlotTeleports` still bounds the chain. |
| Camera | Scriptable camera at `center + (0, 55, facing x 60)` looking at the plot centre, tween 0.6 s Quad Out; `RequestStreamAroundAsync(center)` per selection (PROVISIONAL, `UiTheme.PlotPicker`). |
| Kept automatic | `Save.FinderStart`, `Save.Teleport` arrivals (`arrive`), Studio hooks (`shadowJoin`, `rejoin`) and `runPlaytest` keep the automatic claim. |

## 2026-11-26 — CM2-ASSETWARN closed as engine noise (planner)
- The `rbxassetid://203785492` "Asset type does not match requested type" warning is engine or Studio noise, not project content: a scan of every exposed property and attribute found 0 hits in Edit (3337 instances), Play server (6131) and Play client (9090); 2 lines appear in Edit before any project script runs and 4 at Play start, none later; no Lua error, no missing visible asset, no route blocker (PROGRESS archive `docs/archive/PROGRESS_2026-11-25_to_2026-11-26_ASSETWARN-N1b-PT35b-PT53.md`). No fix task. Playtests and reviews treat these lines as known noise.
- Reopen (as an S task) only if the line count grows past 6 per Play session, it shows in a live-server error report, or a visible sound, image or mesh is missing.

## 2026-11-26 — Lot and HQ art in the world, CM2-13W (engineering)
- Tier ids: the backlog's "config tier `ChristmasPavilion` maps to `Buildings/TimberPavilion`" is obsolete; since schema 19 the tier ids are `SalesTent`, `TimberPavilion`, `AlpineHut`, `MountainChalet`, so the art path is `Buildings/<tier.id>`.
- Lot fence: it follows `Progression.fenceBoxes` (8 studs per level, sides only from level 1, from z -27 back); the CM2-13b layout (6 per level, sides from z 27) is superseded. Only `FenceRail8` and `FencePost` are placed (`FenceRail6` unused). Values: line offset 0.45 beyond the lot edge (x ±40.45, back z -(27 + 8 x level + 0.45)), base on the map ground (y 0, 0.55 below the lot top), 11 + 2 x level pieces (10 back rails, 1 corner post, `level` rails per side), rail extent 4.3 behind and 3.95 ahead of its centre, 0.3 half-width.
- Gameplay anchors stay: `CheckoutCounter.CounterBase` and `Receiving.Bay_<i>` keep size, position and children (prompt, label) and are invisible when the art is present.
- Decor fences: `Placement.DecorFences` become one `FenceRail8` and one `FencePost` each in a model `DecorFence`; the CC0 `FenceWooden` stays only as the fallback.
- Road yaw 180 degrees on plots 1-3 and 0 on plots 4-6; the night light moves to the art's `Register` part (else `CounterBase`). No save, remote, error-code, string-key or KeepClear change.

## 2026-11-26 — CM2-G11 daily rewards, quest board and group bonus (engineering)
- Plan: `docs/plans/CM2-G11.md`. Pure logic in `src/shared/DailyRewards.lua` and `src/shared/QuestBoard.lua`; the claim action in `src/server/Services/DailyRewardService.lua`, the board and reward grants in the mixin `src/server/Services/CompanyQuests.lua`, the panel in `src/client/QuestPanel.lua` (rail slot 30). The scaffold (`QuestService.lua`, the old `GameConfig.Quests`, `questClaims`) is gone; it was never client-reachable.

| Topic | Decision |
|---|---|
| Daily streak owner | Per **player** (profile `daily`), paid into the **active save**; one claim per player and UTC day across saves and servers (co-op members claim their own). |
| Day | `floor(businessClock / 86400)` (UTC). Claimed yesterday → next index; missed ≥ 1 full day → back to day 1; after day 7 → day 1 (PROVISIONAL). Clock behind `lastDay` → `AlreadyClaimed`. |
| Claim order | Validate → rate limit → in-flight guard → active, available save → group check (may yield) → profile `UpdateAsync` marks the day (atomic guard) → save still active → grant in the company critical section. Grant refused → revert exactly this claim; revert failed → `warn`, reward lost (at most once, never twice). |
| Group | `GroupId = 0` → hidden, never doubled, no `IsInGroup` call. Else `Player:IsInGroup` in `pcall` at join and each claim; error → cached value (default false). ×2 on cash and reputation inside the one claim. Join button: `GroupService:PromptJoinAsync` in `pcall`; membership may be cached per server, so the text says "from your next visit". |
| Quest board owner | Per **save** (`state.quests`, schema 21), progress from any member's actions. |
| Rotation | Windows `floor(clock / 14400)`. A stale board is replaced on the next note, claim or test hook; unclaimed rewards lapse. Progress grows only from play events, so offline time never pays. The view never mutates. |
| Counting | Orders: quantity of each successful `placeOrder`. Sales: each `completeReservedSale` (sale price, 1 tree, its size); pass/boost bonus not counted. Rewards are not revenue and get no cash multiplier. |
| Scaffold | `QuestService.lua`, its test, the old `GameConfig.Quests` and `questClaims` are replaced (never client-reachable). |

- Amendment 1 (Studio step 34 ELSEWHERE flake, not caused by G11): the save locator cache stays at `LocatorCacheSeconds` = 15 s. The Studio test instrument drops the cached lookup after its direct map writes (`placeElsewhere`, `clearElsewhere` call the new `SaveSlotService:forgetLocation`), so a miss cached during the save switch no longer hides the fake foreign server.
- Amendment 2 (B3, auto-open): the quest panel's auto-open check also runs after every modal change (`ModalCoordinator.onChange`, `UiKit.onModalsChanged`: claim, release, closeAll, base layer), so a modal or base layer held at the attribute change no longer blocks it for the session. `QuestUI` carries `AutoOpenState` (`NotReady`, `NotClaimable`, `Tutorial`, `Modal`, `BaseLayer` or `Opened`), the first failing condition of the last check.
- Amendment 2 (B4, plot picker): the CM2-PP plot picker closes itself when `CompanyReady` turns true for its own save (`ActiveSaveId` equals the picker's save), because Save.Play activates the save before its response arrives; a later Save.Play response finds the picker closed and does nothing.

## 2026-11-26 — owner: supplier orders with sizes, quantities and a cart (CM2-SUP)
- Owner noticed that only one tree of a species can be ordered at a time. Cause: the Supplier tab sends a fixed Medium, quantity 1 for orders and sell back (deferred in CM2-G6 "to CM2-40 and later Supplier tab work", never filed); with one order per bay the 4 bays fill after 4 clicks.
- New task 18a **CM2-SUP** (tier L, `planner-high`), right after CM2-G11 in the launch order: the reference's buy rows (species × size, −/quantity/+/MAX, demand tags), cart with bay and delivery info, one-click recommended order, sell back per row with ALL; the cart is one atomic, idempotent server order. Protocol shape, bay packing and any schema change are for `planner-high`.
- Files: docs/CLAUDE_BACKLOG.md (18a, N6).

## 2026-11-26 — owner: missing reference features go into the version 2 update
- Comparison of the reference game with our game (2026-11-26) found 8 reference features with neither code nor task. Owner: plan them, but for the first update after launch, not before release.
- Backlog "Version 2 update", lines 38–45: CM2-V2-SPT Robux special trees orderable, CM2-V2-PDC premium decor works, CM2-V2-MOVE move a display tree, CM2-V2-ORD recent orders with status, CM2-V2-SNOW falling snow, CM2-V2-HIDE hide the HUD, CM2-V2-GIFT gift button, CM2-V2-QSKIP quest skip for 5 Robux. At launch the special-tree and premium-decor shop items stay "Coming soon" (`ready = false`).
- Files: docs/CLAUDE_BACKLOG.md, docs/PRODUCT_SPEC.md ("Monetization and events").

## 2026-11-26 — owner: vehicle art and village infrastructure are required for version 1
- Owner: the vehicle models must ship in version 1, and the surroundings must not look empty: not only decor but infrastructure, so there is something between the plots.
- CM2-14W (vehicle art in the world) is marked required for version 1. New CM2-10I (infrastructure models and placement contract: utility poles with wires, bus stops, mailboxes, hydrants, road signs, snow stakes, guard rails, utility boxes, bins, a garage shed, a village shop and a fire station) and CM2-10IW (placement in `MapLayout`/`MapWorld`), both in Gate B before CM2-47. Budget on top of CM2-10DW: ≤ 120 models, ≤ 40000 triangles, ≤ 300 MeshParts, ≤ 10 night lights (map ≤ 562 models, ≤ 68 night lights).
- Files: docs/CLAUDE_BACKLOG.md (launch order, CM2-14W, CM2-10I, CM2-10IW), docs/PRODUCT_SPEC.md ("Art").

## 2026-11-26 — owner: faster work, shorter tests, less usage
- Owner: Claude Code should work faster, the tests should be shortened, and usage matters; the same changes go into the template repo.
- Measured: the headless suite takes 2.5 s but prints 690 PASS lines into every agent; the Studio full run has 69 steps and took 747 s (BUILD cm2-13w), and it ran for almost every task (tier L, MODEL, world geometry); plans reached 34 KB against a 30 KB budget; every agent re-read `CLAUDE.md` and loaded its skills.
- Previous rule → new rule: Studio now for tier L, MODEL, saves, money, inventory, purchases, world geometry, else every third task, always starting with the full run → Studio now only for saves, money, inventory, purchases, world wiring or a milestone's last task, else every fifth task; a playtest is the smoke run plus the task's own steps; the full run only at the end of a hasseln run, for QA/release tasks and for runner or core-loop changes; after a fix only the failed steps plus smoke. Every agent loads its skills → only the planner does and copies the applicable checks into the plan's "Skill checks" (TEMPLATE). Plan budgets S/M/L/MODEL 12/20/30/12 KB → 6/10/16/8 KB, amendments 4 → 3 KB. New: agents do not re-read `CLAUDE.md`, read only the parts of files a step touches, run the headless suite filtered to failures and the summary, run checks once at the end, keep reports to 15 lines and PROGRESS entries to 10 lines, prefer numeric Studio readings over captures.
- New task 18g **CM2-FAST** (M) right after CM2-G11: `runPlaytest {mode = "smoke"}` (≤ 12 core steps, ≤ 180 s), the `only` step filter, and `docs/TEST_PLAN.md` cut to ≤ 20 KB. Until it lands, the playtester keeps running the full run.
- Files: CLAUDE.md, .claude/agents/{implementer,reviewer,playtester,planner,modeler}.md, .claude/skills/cm2-task/SKILL.md, .claude/skills/hasseln/SKILL.md, docs/plans/TEMPLATE.md, docs/PRODUCT_SPEC.md ("Way of working"), docs/CLAUDE_BACKLOG.md (18g, N6); template repo the same files (game-task).

## 2026-11-26 — owner: own polished UI, no Swarve pack in the game
- Owner (chat): the Swarve Essential UI Pack is not used for our game. We keep the current look (`UiTheme` tokens, `UiKit` builders) but make it nicer and more modern so it does not look like generic "AI slop", e.g. buttons grow on hover with press feedback, and generally everything looks cooler and more modern. On the template: "das Pack bleibt im Template-Repo, aber für unser Spiel benutzen wir es nicht".
- Previous rule (2026-11-25 "owner: CM2-UI built on the Swarve pack, also in the template"): CM2-UI uses the pack's layout patterns, images, icons, fonts, strokes, gradients, sounds and button tween. New rule: CM2-UI is our own style on `UiTheme`/`UiKit`; no image, icon, font, sound or layout from the pack or any other UI set in the game; no image upload needed, so CM2-UI no longer depends on PC-2 or an owner upload. The 2026-11-24 cream direction and the 2026-11-25 compact-phone limits stay.
- Planner decisions (values in backlog 22a): hover 105 % in 0.15 s Quad Out, press 95 % in 0.08 s, release 0.15 s Back Out, through `UIScale`; click sound from the Roblox audio library (volume 0.5, recorded in `docs/AUDIO.md`), no hover sound; `UICorner` 8/12 px, 2 px `UIStroke`, same-hue `UIGradient` (≤ 8 % lightness shift), image-free shadow frame (offset 4 px, transparency 0.7), window open 0.18 s and close 0.12 s; style guide in `UiTheme` plus `docs/UI_STYLE.md` (≤ 4 KB). Checks are numeric (headless scans and builder counts, Studio UI probe 0 clipped/overlapping/truncated, 0 buttons missing `UIScale`/`UICorner`/`UIStroke`); captures gate nothing (owner 2026-11-25).
- Template: 22b CM2-UI-TPL no longer packages "CM2-UI's Swarve-based look"; it builds the optional add-on from the pack itself (values from `INVENTORY.md`, the pack's 110 %/90 % tween), depends no longer on CM2-UI, becomes M (the planner settles its API) and runs after 25c (not launch-critical). `assets/third_party/swarve-essential-ui/` (`LICENSE.md`, `INVENTORY.md`, the gitignored `.rbxl`) stays as the template's licence record; the game must not use it, and CM2-44 does not delete it.
- Files: docs/PRODUCT_SPEC.md ("UI look"), docs/CLAUDE_BACKLOG.md (rules for the order, N6, N7, 22a, 22b, CM2-44 note).

## 2026-11-27 — CM2-SUP supplier cart, packing and sell back per row (engineering)
- Protocol: `Supplier.PlaceOrder` takes the legacy `{speciesId, sizeId, quantity}` or exactly `{lines}` (1–`Supplier.MaxCartLines` = 12 lines of exactly `{speciesId, sizeId, quantity}`); `SupplierCart.normalize` answers `InvalidCart`, `UnexpectedField`, `InvalidItem`, `InvalidQuantity` (1–100 per line and in total) or `DuplicateLine`. No price or cost is read from the client; all checks run before the first change; one debit and one `OrderPlaced` ledger entry per cart; a replay is `DuplicateRequest`.
- Packing: per species in `SpeciesOrder`, sizes in `SizeIds` order fill groups of at most `BayCapacity` (9), splitting a line when needed; each group takes the next free bay, ascending, never a busy one (`NoFreeBay` when groups exceed free bays).
- No save-schema change and no migration: a cart becomes several `pendingOrders` records of today's shape sharing `requestId`, `createdAt` and `dueAt`, IDs `order:<requestId>` then `order:<requestId>:<k>`.
- The recommended order (one species per free bay, limited by stock, storage, cash and one bay's 9 trees in total; an empty one carries a reason) replaces the cart in one tap. `BayCapacity` is no longer returned (a large line splits instead); its string stays. `Company.GetSummary.supplier` adds `sellable`, `refunds` and `deliverySeconds`.
- Files: src/shared/SupplierCart.lua, BusinessState.lua, Protocol.lua, UiTheme.lua, Localization.lua, GameConfig.lua; src/server/Services/CompanyStateService.lua, SupplierStockService.lua; src/server/main.server.lua; src/client/LotManagerTabs/SupplierTab.lua, Tutorial.client.lua; docs/TECHNICAL_ARCHITECTURE.md.

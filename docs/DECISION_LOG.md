# Decision log and repository sync policy
Updated: 2026-11-19
Archive (CM2-SLIM run 3, 2026-11-27): engineering entries of 2026-11-24..2026-11-25 (CM2-UVF8, 13a/13b, 14, 10a/b/c, SALE1, line 14 timing rule) and two superseded owner entries (Swarve UI pack) moved unchanged to `docs/archive/DECISION_LOG_2026-11-24_to_2026-11-25.md`; they stay binding. Archive (CM2-SLIM3, 2026-11-25): entries of 2026-11-19..2026-11-23 that are not owner entries moved unchanged to `docs/archive/DECISION_LOG_2026-11-19_to_2026-11-23.md`; they stay binding. Grep `docs/archive/DECISION_LOG_*.md` too. Archive (CM2-SLIM run 4, 2026-11-28): engineering entries of 2026-11-26 (SALE2, G12b, 12W, PP, ASSETWARN, 13W, G11) moved unchanged to `docs/archive/DECISION_LOG_2026-11-26.md`; they stay binding.

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

- 2026-11-24 owner: UI graphics from the Essential UI Pack (Swarve Studios), superseded by 2026-11-26 "owner: own polished UI, no Swarve pack in the game"; text in `docs/archive/DECISION_LOG_2026-11-24_to_2026-11-25.md`.

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

## 2026-11-24 — owner: Robux products created (PC-8)
- Source: reported to the orchestrator by the owner's other Claude session (~19:30); the IDs were not typed by the owner in the hasseln chat. That session checked them with an Open Cloud list GET at 18:32Z (universe 10777859950): all 12 `isForSale = true`, prices as in `docs/RELEASE_CHECKLIST.md`. Icons are own art previews from `assets/art/previews`. The other 15 products were not created. Engineering created and activated nothing.
- Game passes (Config-Key → ID, name, Robux): PassCashX2 → 2101828296 (Golden Till, 99); PassReputationX2 → 2099729097 (Shining Star, 79); PassInstantDelivery → 2099165138 (Express Sleigh, 149); PassVip → 2098973055 (Evergreen VIP, 199).
- Developer products: StarterPack → 3735805319 (Tree Lot Starter Kit, 79); CashPinecone → 3735805373 (Pinecone Purse, 29); CashSleigh → 3735805396 (Sleigh Sack, 99); CashCabin → 3735805416 (Cabin Chest, 249); CashVillage → 3735805452 (Village Vault, 599); CashMountain → 3735805469 (Mountain Treasury, 1499); BoostCashX2 → 3735805526 (Cash Rush, 10); BoostRested → 3735805549 (Hot Cider Round, 5).
- Planner decision: PC-8 is resolved; CM2-46c (line 13c) enters these IDs only after a Studio `MarketplaceService:GetProductInfo` check of all 12 returns the expected name and price (any mismatch stops CM2-46c with a report). Publication stays the owner's action.
- Files: docs/CLAUDE_BACKLOG.md (PC-8, line 13c, N3, run record), docs/DECISION_LOG.md.

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

- 2026-11-25 owner: CM2-UI built on the Swarve pack, also in the template, superseded by 2026-11-26 "owner: own polished UI, no Swarve pack in the game"; text in `docs/archive/DECISION_LOG_2026-11-24_to_2026-11-25.md`.

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

## 2026-11-26 — Owner: PassCashX2 test purchase skipped (N3b, CM2-46c)
- Owner decision in chat ("gar nicht testen"): CM2-46b playtest step 7b (PassCashX2 test purchase) is not run, because the test account already owns the pass. Gate A line 13c is ticked on 7a, 7c, 7d and the idempotency replay (PROGRESS 2026-11-26 N3b). The simulated pass path stays covered by CM2-46a steps 51-53. No code or config change.

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

## 2026-11-27 — CM2-GATE lot gate and festive fence v3 (engineering)
- New `Props/LotGate` (tier A, 19.3 x 1.85 x 17.59, 2868 / 3000 triangles, 9 MeshParts) and fence v3 `FencePost` (0.9 x 0.9 x 5.93, 160 / 400, 3 MeshParts), `FenceRail8` / `FenceRail6` (8.40 / 6.40 x 0.9 x 5.93, 512 / 452 of 800, 4 MeshParts), raised from tier B to tier A; built in one Blender pass from `fence_common.py`. Gate opening 16.3 x 12.1, post footprint 1.5 x 1.5, fence post 0.9, fence top 5.93.
- Colour: all fence wood is `WoodWarmShade`, because a second wood colour does not fit in 4 MeshParts; this is a recorded deviation from quality checklist item 4 (light and shade variant per material). The gate uses the WoodWarm / WoodWarmShade pair.
- Gate attachments are `Light1` and `Light2` (plan: `Light_1`, `Light_2`), because the pipeline name rule forbids underscores. The modeler added WoodWarm bands on the gate posts (secondary forms for tier A), inside the 1.5 footprint and outside the opening.
- Until CM2-GATEW the code constants (`LotArt.PIECE_HALF` 0.3) understate the fence post by 0.15 per side.
- Files: assets/art/source/Environment/{fence_common.py,FencePost,FenceRail8,FenceRail6}, assets/art/source/Props/LotGate, assets/art/rbxm, assets/art/previews, docs/MODEL_INTEGRATION.md.

## 2026-11-27 — CM2-A1 Advent calendar (engineering)
| Topic | Decision |
|---|---|
| Opened doors | Profile `advent = {year, opened}`, bit d-1 = door d; another `year` counts as empty; so one payment per player across saves and servers. |
| Window | UTC date Dec 1..24 -> `Open`, today = day; before Dec 1 -> `Before`; Dec 25..31 -> `Ended`; today = 0 outside `Open`. |
| Claim order | As Daily.Claim: validate, rate limit, in-flight guard, active available save, profile UpdateAsync sets the bit, save still active, `grantReward`; refused -> clear the bit; revert failed -> `warn` (lost at most once, never paid twice). |
| Decor | No decor system yet: decor goes into a new save map `decorInventory` (the "decor crate"), consumed by CM2-32/33. |
| Boost | Cash Rush seconds (`purchases.boosts.CashX2`) clamped at `BoostCapSeconds`; excess dropped. |
| Studio date | `AdventService:setNowForTest(at?)` overrides only the calendar's time, not the business clock. |
- Save schema 22 adds `decorInventory = {[DecorItems id]: 1..DecorMaxCount}` (migration 21 -> 22 and the legacy-v1 path set `{}`); the profile field needs no version bump (as `daily`). Door rewards in `GameConfig.Advent.Doors` are PROVISIONAL and are not revenue (no Cash Rush multiplier).
- Files: src/shared/AdventCalendar.lua, GameConfig.lua, BusinessState.lua, SaveProfile.lua, Protocol.lua, Localization.lua, UiTheme.lua; src/server/Services/AdventService.lua, CompanyQuests.lua, CompanyStateService.lua, SaveSlotService.lua, StudioTestService.lua; src/server/main.server.lua; src/client/AdventPanel.lua, UiController.client.lua.

## 2026-11-27 — CM2-GATEW entrance gate in the world (engineering)
- Placement: gate pivot at lot (28, 28) = `LotHalfDepth` 27 + `GATE_OFFSET` 1.0, east of the parking. Customers never cross the front edge (cars drive straight from the road to spaces at x -24..12, NPCs start at the door), so a gate over the car lanes would serve nobody; it stands for players coming from the sidewalk. Posts 1.5 x 1.5 at x 18.35..19.85 and 36.15..37.65 are fully off the placeable lot (z >= 27.25) and keep 2.25-5.35 studs from parking, walk lines, truck lane and the sign box.
- Backlog deviations: the offset is 1.0, not `FENCE_OFFSET` 0.45 (the post would reach into the lot); customers cannot walk through the gate (steps 37 and 40 stay as regression with 0 snaps).
- The right decor fence (34, 24) stood 3 studs behind the opening and is dropped: `DecorFences = { { x = -34, z = 24 } }`.
- Lights through `MapWorld.nightLight` (`DayCycle.GateLight`, PROVISIONAL), 12 more night lights (46 in step 61); the name board mirrors the lot sign through `WorldService.setLotSign`. No save, money or remote change.
- Files: src/shared/LotArt.lua, GameConfig.lua, UiTheme.lua; src/server/Services/LotGateWorld.lua, WorldService.lua; tests/studio/Cases/{LotArt,GameConfig}_Test.lua, Playtest/Steps/{LotArt,DayNight}.lua; docs/MODEL_INTEGRATION.md.

## 2026-11-27 — CM2-45 event framework and 1st Advent event (engineering)
| Topic | Decision |
|---|---|
| Currency | Pack for in-game cash (backlog: "event currency or cash"); Robux `EventTree*` stay `ready = false`, "Coming soon" (owner 2026-11-26; CM2-V2-SPT). Deviation: the reference pack costs 29 Robux; `EventDecorPack` unchanged. |
| Window | `startsAt <= now < endsAt` (UTC seconds); Advent1 until the next Advent Sunday (PROVISIONAL); no overlaps. |
| Scope | Per save, counted in `eventPurchases[eventId][itemKey]`; all stays after the event. |
| Client feed | `ReplicatedStorage` attributes `EventId` ("" = none), `EventEndsIn` (s) every 5 s; rows in `Company.GetSummary.event`. |
- Advent1 = 2026-11-29 00:00 to 2026-12-06 00:00 UTC (start OWNER DECIDED, end PROVISIONAL); the "Candlelight Pack" costs $2000, limit 1 per save (PROVISIONAL), and adds 5 decorations x 3 (OBSERVED shape, REFERENCE §7) to the decor crate. The pack is a cash sink, not revenue.
- Save schema 23 adds `eventPurchases = {[eventId]: {[itemKey]: 1..MaxBuyCount}}` (migration 22 -> 23 and the legacy-v1 path set `{}`); keys are checked by format only, so a later config change never bricks a save. Event decor ids join the decor crate (`AdventCalendar.isDecorInventory` accepts `EventConfig.isDecorItem`).
- Studio: `CompanyStateService:setEventNowForTest(at?)` moves only the event clock, not the business clock (`eventNow`, `eventReset`).
- Files: src/shared/EventConfig.lua, EventCalendar.lua, AdventCalendar.lua, BusinessState.lua, Protocol.lua, Localization.lua, UiTheme.lua; src/server/Services/CompanyEvents.lua, CompanyStateService.lua, StudioTestService.lua; src/server/main.server.lua; src/client/EventShopPanel.lua, UiController.client.lua.

## 2026-11-27 — owner: launch on the 1st Advent, most important first, UI included
Owner (chat, verbatim): "okay dann kommen die wichtigsten zuerst damit am ersten advent launch ist dazu gehört auch die ui". The remaining Gate B (~17 tasks) does not fit before 2026-11-29, so the order is cut by priority. Binding list: "1st Advent launch list (owner 2026-11-27)" in `docs/CLAUDE_BACKLOG.md`; PRODUCT_SPEC top section updated.
- Launch list, in order: CM2-14W (running; finish) → owner actions PC-13 (client viewport) and PC-12 (tutorial phone time → CM2-49T) by the morning of 2026-11-28, friends test optional → CM2-SUPC as one batch with the queued client readings of CM2-A1, CM2-45 and CM2-GATEW (ticks 18a, 19, 20) → 22a CM2-UI → 22 CM2-43 → art required for version 1: CM2-10D → CM2-10DW → CM2-10I → CM2-10IW → CM2-SLIM if due → 23 CM2-47 → 24 CM2-48 → 25 CM2-50a.
- Deferred to Gate C (2026-12-06), at its start in this order: 21 CM2-G18 (audio), CM2-13D (desk), CM2-44 (CC0 art removal), CM2-ARTREF (needs PC-1). After launch: 25a–25c CM2-SPLIT-a/b/c, 22b CM2-UI-TPL.
- Cut line: what is not done when the owner decides on 2026-11-28 is listed in the CM2-50a summary as "out of 1st Advent launch"; the owner then picks 2026-11-29 with the reduced scope or 2026-12-06. The Go/No-Go stays the owner's.
- Planning rationale (planner): two paths, so a run never idles. The feature/UI path (CM2-SUPC, CM2-UI, CM2-43) needs the Studio client and is blocked by PC-13 until the owner fixes it; the art path (10D → 10DW → 10I → 10IW) needs no client UI. While PC-13 is open the art chain runs first; once PC-13 is resolved, SUPC, UI and 43 go before the remaining art tasks. QA, checklist and Go/No-Go (47, 48, 50a) close the list on whatever is done.

## 2026-11-27 — owner: usage improvements from the deep research
- Owner: implement all points 1–8 of the deep-research result (103 agents, 21 sources, 23 of 25 claims confirmed; Claude Code docs fetched 2026-11-27) in both repos.
- Done now: (1) the 29 roblox-brain skills and cm2-modeling are `user-invocable-only` through `skillOverrides` in `.claude/settings.json` (their descriptions no longer ride on every request; agents read them by path; support in Claude Code 2.1.287 not confirmed by the docs, harmless if ignored); (2) `CLAUDE.md` 12.7 → 8.1 KB: the Skills section moved unchanged to `docs/SKILLS_POLICY.md` (read by the planner and the planning chat; binding as before), the done P0/P1 list and the hook details shortened, the four rules every agent needs stay inline; (3) the playtester starts without `CLAUDE.md` (`omitClaudeMd`, v2.1.271+) and carries its four project rules itself; (5) cm2-task bundles 2–3 tier S tasks with disjoint files into one implementer and one reviewer run; (7) a project `Explore` agent on Haiku without `CLAUDE.md` overrides the built-in, which used the parent's model; (8) every agent report: no diffs, logs, file contents or passing-test lists.
- Planned: (4) CM2-BLIDX backlog index ≤ 8 KB for hasseln, backlog ≤ 40 KB; (6) CM2-CHECK one check command with a one-line result. Both docs/tooling only, at the start of Gate C (after the 1st Advent launch list), so the launch sprint is not disturbed.
- Owner action (not verifiable from the repo): turn off app plugins and connectors that this project does not use (Unity, Small Business, Adobe, Figma, Legal, Cellcog, Data, Engineering, Kotlin, Shopify, Gmail, Calendar, Drive …); they add skill descriptions and server instructions to every request of every session and agent.
- Files: CLAUDE.md, docs/SKILLS_POLICY.md (new), .claude/settings.json, .claude/agents/{planner,implementer,reviewer,playtester,modeler,Explore}.md, .claude/skills/cm2-plan/SKILL.md, .claude/skills/cm2-task/SKILL.md, docs/CLAUDE_BACKLOG.md (CM2-BLIDX, CM2-CHECK, Deferred); template repo the same (game-plan, game-task, blender-modeling).

## 2026-11-27 — CM2-UI1 style kit: deviations from 22a (reviewer)
- Close motion: the window hides at once (keeps modal and test state); only the shadow and dim fade out in 0.12 s. Open fades only shadow and dim (no CanvasGroup: it clips strokes).
- Click sound: engine content `rbxasset://sounds/volume_slider.ogg`, volume 0.5 (no asset ID, upload or licence; no AUDIO.md before CM2-G18); 22a2 records the source in `docs/UI_STYLE.md`.
- `AutoButtonColor` is set only in `UiKit.button` (Amendment 1): the kit owns hover and press; 14 client assignments removed.
- World lot sign (`WorldService.lua:524`) follows the `CornerRadius.Panel` token: corner 12 instead of 14 (visual only).
- Known gap for 22a2: buttons disabled only by colour or transparency while `Active` stays true (SupplierTab `setEnabled`, BreakAreaMode, StockingMode, EmployeesTab, LandTab) still scale on hover and press; their click guards are unchanged.
- No settings screen exists, so the kit has none to cover.

## 2026-11-28 — CM2-UI2 cream palette: deviations from the plan (reviewer)
- Reading (f) passes only as "Finder dim gone when the picker opens": `PlotPicker.open` runs `closeModals`, and the picker's DisplayOrder (21) is below the Finder's (25), so a picker over the dim cannot occur.
- The title band fills the title label's own box (inside `HeaderInset` padding 10), not the full window width.
- Toast and HUD chips are cream now (Panel and Toast tokens are 255,244,217).
- `StudioUiHook` `interact` returns `{ok=false, error="Disabled"}` for any non-interactive button (`Active` false or `KitDisabled`), in every state.
- Not covered: `LotGate.SignBoard` Name labels stay `DarkText` (the plan names only the lot sign `signLine`); the Advent and Event window audit waits for an open event season (see the queue).

## 2026-11-28 — CM2-UI3M phone Lot Manager: deviations from the earlier design (reviewer)
- Phone tab column scrolls: 6 tabs of 48 px pitch do not fit the 162-299 px window body, so 3-4 of 6 are visible with a 4 px scroll bar; the selected tab is kept in view. Desktop and tablet tab boxes are unchanged.
- Phone Supplier rows are 88 px (two lines, pitch 92, controls stay 44 px) instead of 44 px, so 14 px text keeps the full width. The CM2-SUP row test bound is now `rowHeight`.
- Phone Pricing card is 160 px (pitch 168), so one whole card fits the phone page.
- Phone Lot Manager window padding 6 px (was 8); tab column width 100 px (PROVISIONAL engineering values).
- Not covered: Employees and Land page reflow and the 12-13 px Pricing card text; 22a4 CM2-UIP readings decide.

## 2026-11-28 — CM2-10D map dressing art (engineering)
- Plan: `docs/plans/CM2-10D.md`. `art.luau doctor` exit 0 (Blender 5.2.2, API key and creator set); all 6 uploaded and normalized (`.rbxm` in `assets/art/rbxm/Props/`, `asset.json` version 2); `verify release.rbxlx` 48 integrated, 0 pending, 0 failed.
- Paths, tier, seeds: `Props/SnowPileA` (1101), `Props/SnowPileB` (1102), `Props/Snowman` (1103), `Props/Sled` (1104), `Props/WoodStack` (1105), `Props/FirBarrel` (1106), all tier B; no new palette key. "SnowPile (2 variants)" is named A (low drift) and B (tall heap).
- Mounds: local bmesh helper (icosphere, `create_icosphere` subdivisions detail+1, per-axis radii, +-3 % vertex jitter, cut flat by `bisect_plane` at the floor: -0.2 on the piles, 0 on the snowman). The cut leaves the hidden underside open.
- SnowPileA (round 1): the two SnowShade lumps sat at y +0.6 and were nearly hidden inside the drift; now one in front at the left end (-2.0, -0.6) and one behind at the right end (2.0, 0.6), centre z 0.0, rz 0.66.
- Snowman: the bottom ball is (1.3, 1.15, 1.3) instead of r 1.3, because 2.6 would break the L 2.4 limit; balls cut at z 0 (bbox min 0); arms are 56 degrees from vertical (34 up) and start inside the torso at x +-0.55 so W stays 3.5; carrot centre y -0.88 so its tip stays inside L.
- Sled: the whole sled is shifted +0.2 in y (`OY`) so the curl (y -2.1) and the rear end are centred (|min+max| 0.01); slats 1.74 wide (W 1.77). Round 1 built 644 triangles, so only the front bar and the snow keep a bevel (292 / 300); the snow cap is 1.4 x 1.6 x 0.18 sunk 0.03 into the slats (round 1: the thin 1.6 x 1.8 x 0.08 plate read as a table top).
- WoodStack: end grain is one flat hexagon face per log (4 triangles instead of a 20-triangle disc); round 1 built 580. The flat snow cap read as a board (rounds 1-2), so the top snow is a closed half-icosphere mound (1.55, 1.12, 0.55) at z 3.0 (H 3.57); small snow caps on both stake tops.
- FirBarrel: hoops unbevelled (round 1 built 412 / 360); each tier's snow is a 7-sided collar 0.3 high, 8 % wider than the tier, starting where the tier is 0.7 of its radius (tier tips at 0.12 of the radius).
- Render rounds: SnowPileA 2, SnowPileB 1, Snowman 1, Sled 2, WoodStack 3, FirBarrel 2.

## 2026-11-28 — CM2-10I village infrastructure art (engineering)
- Plan: `docs/plans/CM2-10I.md`, batch B1 (rows 1-6). `art.luau doctor` exit 0; all 6 uploaded and normalized (`.rbxm` in `assets/art/rbxm/Props/`, `asset.json` version 2); `verify release.rbxlx` 54 integrated, 0 pending, 0 failed.
- Paths, tier, seeds: `Props/SnowStake` (1201), `Props/FireHydrant` (1202), `Props/TrashBin` (1203), `Props/UtilityBox` (1204), `Props/MailboxCluster` (1205), `Props/GuardRail` (1206), all tier B; no new palette key. B2 (rows 7-11, seeds 1207-1211) and B3 (VillageShop, FireStation tier A, seeds 1212-1213) follow.
- Plan deviations (planner): pole spacing 29-115, not ~40 (lots and lanes leave no footing; poles 05, 07, 09 at the gate-front lamp line); bus stops at x -43.6 (x 0 is plot 2/5's car lane); "RoadSign" = two paths (`RoadSignSpeed`, `RoadSignDirection`); stake tip GoldAccent (nearest key to orange).
- SnowStake: 6-sided MetalDark shaft r 0.12 to z 4, GoldAccent tip r 0.15 (z 4-4.8) and a 0.2 point to z 5; 50 triangles.
- FireHydrant: the dome is a pointed 8-sided cone (r 0.46, apex hidden under the nut) with a SnowWhite cone over its top; the side outlets are one MetalDark rod through the body (caps at x +-0.56), the -Y pumper a 6-sided MetalDark stub to y -0.7; no snow on the flange (budget).
- TrashBin: round 1 had four RoofGreen ribs that read as fins and a slot box wider than the 8-gon face; round 2 dropped the ribs for a second MetalDark band (z 0.62) and made the slot 0.42 wide, nearly flush; snow cap aligned to the lid facets.
- UtilityBox: cabinet 2.4 x 1.4 x 2.9 on a 0.25 RoofGreenShade plinth (H 3.47 with rain cap and snow); doors are flat RoofGreenShade panels 0.03 proud of the front (read as inset by colour), with handles; exactly 160 / 160.
- MailboxCluster: half-round tops are 8-sided cylinders along Y (flat sides at the box width), lower half inside the box; snow is a smaller 8-gon raised 0.15 so it covers the top facets; shelf 2.8 x 0.9 instead of a bare crossbar, one MetalDark brace (x +0.3) and the raised flag on the right box (H 3.95); round 2 smaller doors and a higher flag; exactly 300 / 300.
- GuardRail: posts WoodWarm (squared timber), logs BarkBrown 6-sided with a flat top face, a WoodWarm end-grain hexagon face (4 triangles) on each end; logs end at x +-3.995 so chained rails abut; snow strips on the logs and 4-sided snow caps on the posts.
- Render rounds: SnowStake 1, FireHydrant 1, TrashBin 3, UtilityBox 1, MailboxCluster 2, GuardRail 1.
- MODEL_INTEGRATION "Village infrastructure (CM2-10I)": the measured values are one bullet per batch (B1 now; B2, B3 add theirs) so the section stays within 16 lines.
- B2 (rows 7-11, seeds 1207-1211): all 5 uploaded and normalized (`asset.json` version 2); `verify release.rbxlx` 59 integrated, 0 pending, 0 failed.
- UtilityPole: 8-sided BarkBrown frustum r 0.45 -> 0.36 to z 17.6 with a pointed snow cap; cross-arm 0.36 square along Y with two braces; StoneGray 6-sided insulators whose tops are the wire attachments; four StoneGray climbing pegs along Y (W stays 0.92); round 2 made the insulators larger.
- RoadSignSpeed: 10-sided RoofRed disc turned 18 degrees so its top edge is flat and carries the snow; the white face is a SnowWhite 10-gon whose front is the `SignFront` plane; no bracket (budget, 156 / 160).
- RoadSignDirection: arrow boards are one mesh each with a notched tail, mortised into a 0.36 post so their fronts sit 0.02 proud at y -0.2; BarkBrown trim strip along each lower edge, snow on the straight top edges, WoodWarm pyramid cap.
- BusStop: lean-to RoofGreen roof (underside 7.2 front, 6.6 back, H 7.65) with a fascia; the back and half-depth side walls are clapboard boards to z 6.6 (side walls y -0.1 .. 1.5); timetable SnowWhite in a RoofGreen frame; no lamp fixture (the `Light` attachment would sit inside it); round 2 replaced the tilted side boards (jagged edge) with offset boards.
- GarageShed: `asset.json` tier A (quality B) because the plan's 1400 / 6 budget exceeds the tier B cap of 1000 / 4 (`AssetSpec` rejects it), and buildings on the map are tier A in the quality README; green barn door with WoodWarmShade frames, braces and a MetalDark track, diamond gable vent, dark side windows, `hq_common.gable_snow` (cover 0.78) instead of the kit snow; round 2 lowered the wall top boards and corner posts that poked through the eave slab.
- Render rounds: UtilityPole 2, RoadSignSpeed 2, RoadSignDirection 1, BusStop 2, GarageShed 3.
- B3 (rows 12-13, seeds 1212-1213, tier A): both uploaded and normalized (`asset.json` version 2); `verify release.rbxlx` 61 integrated, 0 pending, 0 failed. Measured sums of the 77 pieces: 22346 triangles, 235 MeshParts (within the plan's 24320 / 237).
- VillageShop: ridge along X (eaves to the street) with a front cross gable for the post-horn emblem, so it reads differently from the front-gabled VillageHouse; a 0.8 cream knee band lifts the roof base to 12.8 (ridge 18) so the eaves clear the upper windows; front overhang 1.0, back 1.9 so the awning (front y -9.0) stays centred; own striped awning (9 stripes, red at both ends, tilt 24, pennant valance, snow strip), because `K.awning` rotates its stripes so the front edge ends higher than the back (kit finding, unused elsewhere); upper windows have WoodWarm window boxes instead of shutters; RoofRed shares the awning MeshPart (9 MeshParts).
- FireStation: cream hall with stone base band, corner pilasters and centre pier, red sectional bay doors with a dark glass row, red window frames, a gold-rim red disc with a gold star (no text), roof depth 18 so the eaves reach y +-10 like the apron; open belfry (four timber posts) so the gold bell shows from every side; the side door and two windows on -X, two windows on +X. Wall top, plates, pilasters and downpipes sit under the eave line so nothing pokes through the roof slabs; gable prisms sit 0.2-0.3 low in both buildings (they were coplanar with the roof tops and z-fought).
- Render rounds: VillageShop 3, FireStation 3 (round 3 re-rendered three times for small poke-through fixes).

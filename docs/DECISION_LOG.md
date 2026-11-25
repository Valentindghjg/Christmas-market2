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

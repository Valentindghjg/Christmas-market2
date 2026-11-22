# Decision log and repository sync policy
Updated: 2026-11-19

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

## 2026-11-19 — implementation assumptions (engineering, changeable)
- Personal plot mode first; collaborative company mode follows after persistence and permissions are proven.
- Server owns all monetary transactions, stock and unlocks.
- Data-driven values for uncertain original mechanics.
- Customer state machine and company session locks as described in technical architecture.
- Initial staff roles: cashier and lot worker.
- 100-event bounded history in initial schema; aggregates retained long-term.
- No live monetization until separate approval.

## 2026-11-21 — engineering review and repository clean-up (engineering)
- Previous rule: every player action and every server scheduler change saved the company record immediately. New rule: dirty-flag batching with a 15 s flush and 60 s lock renewal, as already called for in TECHNICAL_ARCHITECTURE section 5 ("debounced", "avoid DataStore budget exhaustion"). Reason: the old write rate exceeded the per-server UpdateAsync budget with a handful of players. Affected: `CompanyStateService`, `main.server.lua`, `GameConfig`.
- New PROVISIONAL caps: 20 open supplier orders and 100 displayed trees per company; placement bounds reduced from +/-50 to the 80 x 54 lot (x +/-38, z +/-25). Unloaded orders are removed from `pendingOrders`; the history ledger keeps the audit trail. No schema bump: the record shape is unchanged.
- Repository: removed the superseded root `GAME_DESIGN.md` and `docs/WORKSTREAMS.md`; committed the unpacked CC0 Poly Pizza sources under `assets/third_party/` (redundant `source.zip` archives ignored). CC0 assets are compatible with the "no proprietary third-party content" rule.

## 2026-11-21 — reference play-test tickets CM2-G1..G5 (engineering)
Source: [REFERENCE_GAME_LIVE_TEST.md](REFERENCE_GAME_LIVE_TEST.md). Schema 9 -> 10 (migration adds `customerOrders`, `nextOrderNumber`, `loadedOrders`, `missedPickups`, `drivePastCustomers`, `supplier`).
- Customer loading (G1): previous rule "sale completes at checkout" -> a sale still settles cash and +1 reputation at checkout, then creates a numbered order waiting at the customer's parked car. Carrying it to the car with the same number gives +2 reputation within 30 s or +1 afterwards; an order nobody loads within 120 s expires with -1 reputation (the paid sale stays booked). A hired Lot Worker loads after 15 s. Carry state is not persisted; a reload or respawn drops the tree back at the pickup spot. Values in `GameConfig.Customers` are PROVISIONAL except the 2 base parking spaces (OBSERVED).
- Parking (G2): concurrent customers (reservations plus waiting orders) are capped by parking spaces, max(2, purchased spaces). With every space taken the next car drives past (`drivePastCustomers`). Parking is now drawn on the road-facing edge of each lot.
- Tree height (G3): heights are derived deterministically from the placement ID inside the OBSERVED size ranges (5–6, 7–8, 9–10 ft) instead of being assigned at delivery, because stored stock is counted per SKU, not per tree. The value is identical after rejoin without a schema field.
- Receiving (G4): previous rule "max 20 open orders" -> each open order occupies one of 4 bays (OBSERVED), at most 9 trees per order (INFERRED), and stored plus ordered trees are capped by delivery storage 30 + 10 per lot expansion (OBSERVED). Unloading stays a separate step until G14.
- Supplier (G5): finite per-SKU supplier stock refreshes every 240 s with ±30% variance and HIGH/LOW demand tags (tags are informational only so far). Sell-back refunds 25% of wholesale, rounded half up, from storage first, then unreserved lot trees. Orders remain single-SKU, so the recommended order (1 small + 2 medium per species within one bay and cash) is advisory, not a one-click multi-SKU order.
- Owner-facing labels and prompts are localized on the client from attributes; the server text is the English fallback.
- Review follow-ups (independent read-only audit, no critical/high findings):
  - Parking purchases now add to the 2 base spaces (2 -> 3 -> 4; previously the first two purchases had no effect under max(2, purchases)).
  - Prompt request IDs use GUIDs, so persisted IDs never collide after a server change.
  - Loading looks up the carried order in the saved record instead of the carried-tree model.
  - Drive-pasts are counted only while trees are on display and no longer bump the revision.
  - Only the cars of orders actually loaded leave with a roof tree.
  - One animation per car; pickup trees are positioned per parking space.
  - Loading a save trims customer orders and supplier stock to the current config limits instead of rejecting it.
  - Accepted risk: tree heights derive from the client-chosen request ID; this is cosmetic while height does not affect price or demand.
  - Rollout note: schema-9 servers reject schema-10 saves (fail-closed), so shut down old servers when publishing.

## 2026-11-21 — Studio playtest of CM2-G1..G5: layout fixes and a Studio-only test hook (engineering)
- Origin: engineering, found while playing the G1..G5 flow in Roblox Studio through the MCP.
- Customer pickup trees moved from x 4..19 (inside the starter stand's 32 × 24 stud collision box) to a row at x 23..36, 13 studs from the plot centre toward the road; default stocking slots moved from a row behind the stand to two rows of four at x 14..35. Both are presentation defaults; server placement rules are unchanged.
- The imported market alley moved from z = 52 (inside the south lots and on parking space 1) to the free strip between road and lots (z ≈ 24..42, x -93..-34), outside every car lane. Visual placement only.
- The HUD parking figure now shows the effective parking spaces (base tier + upgrades) from the customer summary instead of only purchased upgrades (it read 0 while 2 spaces existed).
- Added `StudioTestHook` (a BindableFunction in ServerStorage, created only when `RunService:IsStudio()`) with `forceCustomer`, `advanceClock` and `customerOrders`, plus a clock and roll injected into `CompanyStateService` (the constructor already supported both). Rationale: the customer rolls and the 120 s order patience are otherwise not reproducible in a playtest. It is unreachable for clients and absent on live servers.
- Accepted: the order-action reach check runs before protocol validation, so malformed order payloads sent from far away answer `OutOfReach` rather than a validation code; every such request is rejected either way.

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

## 2026-11-21 - Launch order (engineering, from the owner's launch decisions)
- **Previous rule:** milestones P1..P5 with tickets CM2-10..50, follow-ups CM2-G1..G21 and CM2-R1..R4 worked in milestone order.
- **New rule:** `docs/CLAUDE_BACKLOG.md` "Launch replanning (2026-11-21)" is the binding work order: 37 lines in four gates, Gate A friends test (target 2026-11-26), Gate B go/no-go build (2026-11-28), Gate C by the 2nd Advent (2026-12-06), then after launch. MODEL tasks wait for the owner's reference images.
- **Why this order:**
  - Numbers first (G6), then a repeatable Studio script (G20), because every later task needs a playtest and Studio runs are the scarce resource.
  - Save slots and co-op (S1..S3) come before further gameplay: they change the save key from user ID to save ID, and every feature added later would otherwise need a second migration. The friends test also needs Duo saves and invite codes.
  - The core loop is completed with walking customers, manual checkout, reviews and visible staff before progression and content (owner: "core loop fully playable first").
  - The Advent calendar and the 1st Advent event are in Gate B because their dates are fixed; decor, analytics depth and later events can follow until 2026-12-06.
- **Re-scoped tickets (engineering, following PRODUCT_SPEC 2026-11-21):**
  - CM2-38 roles → owner vs member in co-op saves (CM2-S2).
  - CM2-43 DE/EN → English-only client at launch; DE strings stay for the later language switch.
  - CM2-46 "shop disabled" → shop wired by owner-supplied IDs; entries without an ID show "Coming soon" and never prompt.
  - CM2-G16 → decided by the owner (gentle fatigue, movable break area, no wages); merged into CM2-25/26.
  - CM2-G12 → four leaderboards including Robux spent (owner decision supersedes "no Robux spent").
  - CM2-R2 → asset pipeline for the new Blender MeshParts, because the CC0 art it would version is being removed.
  - CM2-R1, CM2-G21, CM2-15, CM2-16 → steps of the Studio script CM2-G20.
  - CM2-48 → the owner publishes; engineering delivers `docs/RELEASE_CHECKLIST.md`.
- **Technical decisions recorded with the order:** calendar, likes and daily rewards use the server's UTC date; cross-server "Join" uses a MemoryStore save-to-server map; until the group ID is supplied the group bonus is hidden.
- **Affected files:** docs/CLAUDE_BACKLOG.md, docs/DECISION_LOG.md.

## 2026-11-22 - Starter species and observed wholesale table, CM2-G6 (engineering)
- Previous rule: three species (FrasierFir, NobleFir, BlueSpruce); only Medium wholesale observed, Small and Large wholesale PROVISIONAL (26/42, 30/48, 34/55). New rule: four starter species in the OBSERVED supplier order Douglas Fir (Common), Fraser Fir (Uncommon), Noble Fir (Rare), Blue Spruce (Uncommon), with all 12 wholesale values OBSERVED (REFERENCE_GAME_LIVE_TEST §4.1). The 80 %/130 % rule stays for retail prices only.
- New species ID `DouglasFir`. The ID `FrasierFir` stays as a stable save key; only its display name changes to "Fraser Fir" (owner spelling fix). No schema bump: saved data is keyed by species ID. Existing saves gain the Douglas medium price on load (existing backfill) and Douglas supplier stock at the next supplier refresh (at most 240 s).
- Douglas Fir typical medium 70 and starting medium price 72 are PROVISIONAL, on the same 2.5 x wholesale convention as the other species, until CM2-G7 sets the benchmark to wholesale x 5.
- Customer preferences cycle through four species; Douglas Fir is appended, so profiles 1-3 are unchanged (CM2-N1 replaces the cycle).
- The Supplier panel lists the four species with server prices and acts on the selected species (Medium); the company summary gains a read-only `supplier.wholesale` map.
- Affected files: GameConfig, BusinessState, SupplierCatalog, CustomerProfile, SupplierStockService, WorldService, UiController, Localization, tests, GAME_DESIGN, TEST_PLAN, MODEL_INTEGRATION.

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

## 2026-11-22 — Repeatable Studio playtest, CM2-G20 (engineering)
- Previous rule: the Studio playtest was a manual MCP sequence on top of `StudioTestHook` (`forceCustomer`, `advanceClock`, `customerOrders`). New rule: one hook command, `runPlaytest`, runs the whole sequence (`full`, 22 steps) or the real-time soak (`soak`, 5 steps) and prints PASS/FAIL per step. Origin: engineering. Files: `src/server/main.server.lua`, `src/server/Services/StudioTestService.lua`, `src/server/Services/CompanyStateService.lua`, `tests/studio/Playtest/RunPlaytest.lua`, `release.project.json`, `docs/TEST_PLAN.md`.
- Second player: simulated in one session (the official Studio MCP has no multi-client mode). A **shadow company** for the synthetic user ID `999999999001` (`StudioTestService.SHADOW_USER_ID`) is loaded through `loadPersonalCompany`, claims a second plot and gets world visuals. The real Player is the attacker: it stands next to the shadow's tree or car and fires the same callbacks the ProximityPrompts call, so the server reach and company checks are the ones under test. A real 2-client Studio run stays with S2.
- Fixtures: only on the shadow company (`setStaff`, Lot Worker 0/1). The real player's company changes only through normal actions (order, unload, place, carry, load, sell-back). No cash grants anywhere.
- Soak: `full` contains `SOAK_FAST` (6 accelerated cycles) that does not count for the literal soak. `soak` mode is real time (no clock advance until its final drain) and is the G2/G21 "10-minute soak" evidence.
- Not shipped: `release.project.json` has the same tree as `default.project.json` without `ServerStorage.UnitTest` and ignores `src/server/Services/StudioTestService.lua`; TEST_PLAN section 6 requires publishing from this build. `main.server.lua` installs the hook only in Studio and only when the module exists.
- Shadow DataStore key: `company:personal:999999999001` (a test record in the universe Studio is connected to; no real user can own it).

## 2026-11-22 - Asset pipeline for Blender MeshParts, CM2-AP (engineering)
- Old rule: art was inserted into `ReplicatedStorage.ArtAssets` by hand in Studio (CC0 imports), and the 2026-11-21 launch-order re-scoping R2 named a Blender pipeline without a design. New rule: a repeatable path from `.blend` to a normalized `.rbxm` that Rojo maps into `ArtAssets` in both project files; MODEL tasks (CM2-12/13/14/10) deliver art through it; the primitive fallback stays. Origin: engineering, under PRODUCT_SPEC 2026-11-21 "Art" (Blender MeshParts for larger models, Parts for small items). Files: `tools/art/`, `assets/art/`, `src/shared/ArtLibrary.lua`, `src/shared/ArtPalette.lua`, `src/server/Services/WorldService.lua`, `tests/tools/art_pipeline.luau`, `tests/studio/Playtest/RunPlaytest.lua`, both project files, `.github/workflows/quality.yml`.
- Source of truth: the `.blend` (committed) is the art source and the normalized `.rbxm` the build input (committed); FBX and raw downloads are generated, gitignored, never committed. Rojo cannot import meshes (a MeshPart needs an uploaded `MeshId` plus engine-made `InitialSize` and physics data), and runtime EditableMesh does not replicate from the server, has memory budgets and needs an ID-verified creator: both rejected.
- Mesh upload: Open Cloud Assets API (FBX as asset type `Model`, poll the Operation, download through Asset Delivery) so Roblox's importer makes complete MeshParts; Lune normalizes them headlessly. It needs an owner API key (PC-2). Fallback without a key: Studio 3D Importer, save as `raw.rbxm`, then `normalize --raw`. Without the key everything else works; `upload` exits 2 (`ART_NO_API_KEY`); Blender renders need no upload.
- Pivot and axes: Blender origin = ground pivot, front = Blender -Y, 1 unit = 1 stud; `PrimaryPart` = `ArtRoot` at `CFrame.identity` (`WorldPivot` unused, Lune 0.11 cannot round-trip it). The normalizer derives scale and yaw from `report.json` and fails with `ART_AXIS_MISMATCH` instead of trusting importer defaults.
- Look: colour and material from `ArtPalette` through the object name `<PartName>__<PaletteKey>`; no textures, no SurfaceAppearance; flat shading. `COL_` boxes become invisible colliders (MeshParts then do not collide), `ATT_` empties become Attachments (`Trees/*` needs `TreeBase`).
- Budgets (PROVISIONAL): tier A 4000 triangles / 10 MeshParts, tier B 1000 / 4; `asset.json` may lower them, never raise them.
- Checks: `ART_ASSETS` playtest step (23 steps now), `art.luau verify` in CI, Lune pipeline tests (Blender test SKIP on CI), `AssetCatalog` IDs unchanged. Studio-only CC0 models survive `rojo serve` through the ignore flags until CM2-44; a MODEL task that ships an `.rbxm` under the same path deletes the Studio copy in the same task.

## 2026-11-22 - Save slots per player, CM2-S1 (engineering)
- Old rule: one company per player under `company:personal:<userId>`, loaded on join; plots were keyed by user ID. New rule: each player has a profile `profile:<userId>` (store `ChristmasMarket2_Profiles_v2`) listing their saves, and each save is one company record `company:save:<saveId>` (companyId `save:<saveId>`) with its own session lock and plot. The player picks a save on joining, can create, rename and delete saves and switch mid-session. Origin: engineering, under PRODUCT_SPEC 2026-11-21 "Saves and multiplayer" and the launch order (S1 changes the key from user ID to save ID). Files: `src/shared/SaveProfile.lua`, `src/server/Services/SaveSlotService.lua`, `src/client/SavePicker.client.lua`, `BusinessState.lua` (schema 11), `PersistenceService.lua`, `CompanyStateService.lua`, `PlotService.lua`, `main.server.lua`, `StudioTestService.lua`, `UiController.client.lua`, `Localization.lua`, `Protocol.lua`, `GameConfig.lua`.
- Migration: the old personal record becomes the first save "Tree Lot 1" without data loss (copy, then mark the legacy record with `_migratedTo`; the legacy data is never deleted or overwritten). Steps a–d are idempotent (TECHNICAL_ARCHITECTURE §5).
- Save cap: `MaxSavesPerPlayer = 50`. The spec says unlimited; the cap is technical, bounds the profile size and the DataStore storage quota, and lies far above realistic use (PROVISIONAL).
- Rate limits per player (PROVISIONAL): `Save.List` 20 per 10 s, `Save.Create`, `Save.Rename` and `Save.Delete` 5 per 60 s each, `Save.Play` 10 per 60 s, on real time (`os.time`), so business-clock offsets never bypass them. One save action per player runs at a time (`SaveActionBusy`).
- Delete confirmation: the player types the save name (case-insensitive, extra spaces ignored), chosen over typing "DELETE" because Roblox auto-translation would change the instruction word. Deleted saves keep a `_deletedAt` tombstone; there is no restore UI.
- Name source in S1: the profile entry's `name`; the record's `saveName` is a copy written on every load and on renaming the active save. S2 decides whether the record becomes the source for members; no migration is needed because both fields exist.
- Fail-closed surfacing (CM2-R3): a save whose lock is lost, whose saves fail for `SaveFailClosedSeconds`, or that hits an internal error sets `CompanyReady = false` and `CompanyError = <code>` (replaces `CompanyLoadError`); the HUD shows the text. A solo player without a free plot is teleported to another server of the place (at most 3 attempts).
- Shadow player (CM2-G20): `shadowJoin` now opens the shadow's profile, which migrates `company:personal:999999999001` into "Tree Lot 1", and plays its first save.
- Rollout: shut down old servers when this ships, because old code ignores `_migratedTo` and would keep loading and writing the personal record.
- Reload (fix round 1, Q2): `play(userId, saveId, {reload = true})` always leaves and reloads the active save, even a healthy one; the Studio `rejoin` depends on it.
- Migration refusals (fix round 1, Q3): step d writes nothing and returns `SessionLocked` when another job holds the personal record (expired or not; the next open repeats a–d and c is idempotent), and `MigrationFailed` when the personal record is nil or not a table. `markDeleted` on a non-table record returns `DeleteFailed`.
- Error suffixes (fix round 1, Q4): `Localization.saveErrorKey` ignores everything from the first `:`, so a reason suffix such as `LoadFailed:<reason>` stays in `CompanyError` for diagnostics.
- Shutdown (fix round 1, Q7): `SaveSlotService:beginShutdown()` refuses new save work (`ServerShuttingDown`), and BindToClose waits up to 25 s for `pendingCount()`, which counts final leaves already past `activeUserIds()` and every save action in flight.
- Save ID format (fix round 2, R1): the first Studio playtest failed because `company:save:<userId>_<32hex>` is 56 chars and Roblox DataStore keys allow 50 (`KeyNameLimit`). Save IDs are now `<userId>_<16 lowercase hex>` (GUID chars 17–32, at most 36 chars), and every user ID in a key is written with `string.format("%d")` because `tostring` uses exponent form for 19 digits. Key budget for a 19-digit user ID: legacy 36, save 49, profile 27 chars; S2/S3 keys holding a save ID get a prefix of at most 14 chars, keys holding a user ID at most 31 (TECHNICAL_ARCHITECTURE §5). Rejected: dropping the user ID (breaks RTBF matching) and base-36 encoding (more code for no gain).
- Profile store rename (fix round 2, R2): `ChristmasMarket2_Profiles_v1` → `ChristmasMarket2_Profiles_v2`. v1 holds only Studio test profiles whose 32-hex `legacySaveId` the new `isSaveId` rejects, so they would stay `ProfileCorrupt`; the game is unpublished, v1 holds no player data and is abandoned.
- Lock clearing (fix round 2, R3): every migration failure after locking the legacy record clears our lock once (steps b–d run in `_finishMigration` under a `pcall`). The Studio leftover lock `{jobId = "", expiresAt = 1795312003}` on `company:personal:4584569287` needs no data fix: every Studio session has `JobId ""`, so the next run reclaims it, and it expired 120 s after it was set anyway. A generated Studio job ID was rejected because it would block every run after a crash for 120 s.

## 2026-11-22 - Co-op saves and invite codes, CM2-S2 (engineering)
- Old rule: a save had one player; the record's role map allowed Owner/Manager/Worker/Visitor, but only the owner was ever written. New rule: a save is Solo, Duo, Trio or Quad (1/2/3/4 seats, OWNER DECIDED). Duo and larger saves get a 5-digit invite code; friends join with it while a seat is free and then share one plot and one cash balance. Roles are only Owner and Member (company schema 12, migration drops every other role). Origin: engineering, under PRODUCT_SPEC 2026-11-21 "Saves and multiplayer" (covers CM2-37, CM2-38 re-scoped, CM2-G10 part 2). Files: `BusinessState.lua`, `SaveProfile.lua`, `Protocol.lua`, `GameConfig.lua`, `Localization.lua`, `InviteCodeService.lua` (new), `PersistenceService.lua`, `CompanyStateService.lua`, `SaveSlotService.lua`, `main.server.lua`, `StudioTestService.lua`, `SavePicker.client.lua`, `TeamPanel.client.lua` (new), `UiController.client.lua`.
- Sizes and resizing: the creator picks the size; the owner can change it on the active save. A smaller size than the member count is refused (`SizeTooSmall`); becoming Solo clears the code, and the code is released only after the change was saved.
- Codes: `10000`–`99999` (5 digits OWNER DECIDED, no leading zero PROVISIONAL), drawn with up to 8 attempts (PROVISIONAL) from `invite:<code>` in `ChristmasMarket2_Invites_v1`. The map is only an index; the record's `inviteCode` is the authority, so a join is valid only when the record's code equals the typed code, and a stale map entry (a crash between map and record, an unsaved code change) can never admit anyone. A new code never repeats the current one. A code is released only when the live record no longer uses it.
- Brute-force limits (PROVISIONAL): `Save.Join` 5 per 60 s per player; wrong codes lock a player out after 10 per hour and the whole server after 60 per minute, checked before any store call. The failure counters survive a rejoin to the same server. Rate limits of the other new actions: `Save.LeaveTeam` 5/60 s, `Save.Team` 20/10 s, `Save.RemoveMember` 10/60 s, `Save.RegenerateCode` 3/60 s, `Save.SetSize` 5/60 s.
- Management only on the active save: Team, RemoveMember, RegenerateCode and SetSize act on the save the requester plays here (`SaveNotActive`), on a healthy session (`CompanyUnavailable`), and the last three only for the owner (`OwnerOnly`, also for Rename and Delete). Members do everything in play; members play while the owner is offline.
- One server holds a save at a time (existing lock). A join while another server plays the save returns `SaveInUse` until S3 adds "Join" (the save-to-server map). A join while nobody plays the save writes the record without taking its lock (`updateUnlocked`).
- Member name placeholder: the save name was filtered for broadcast when the owner submitted it, and filtering stored text for other players needs the author online, so members never receive the save name. Their profile entry is named "Shared lot" (PROVISIONAL) and the picker and HUD show "Shared lot from <owner username>". Display-time filtering is deferred to CM2-G15.
- RTBF limitation: member user IDs live inside the owner's record value (`members`), not in a key. Erasing a member's ID after an RTBF request therefore needs a manual edit of every record that lists them; the member's own profile key is matched as before.
- Plot hand-over (Amendment A3): while the last leaver's unload is in flight, a waiting member load counts as `SessionBusy` and the plot stays claimed for it; it never loads under the old session's lock release, which would clear the new session's same-job lock. The failed-final-save case stays with CM2-R5.
- Rollout: old servers fail closed on schema 12 records (their `validate` rejects the new version), so shut them down when this ships.

## 2026-11-22 - One server per save and teammate finder, CM2-S3 (engineering)
- Store: a MemoryStore HashMap `CM2_SaveServers_v1` with the key `save:<saveId>` (at most 41 chars, limit 128). A HashMap fits point lookups by key; a SortedMap would add sort cost that nothing needs. Studio uses `CM2_SaveServers_v1_Studio`, so Studio entries never mix with live ones.
- Authority: the DataStore session lock stays the only authority for writing a save; nothing about writes changes. The map is a locator and a pre-check: its atomic `UpdateAsync` lets at most one live server hold an entry, so two servers never both start loading one save. A wrong or missing entry can only send a player to the wrong server or show a stale row, never cause a second writer. The map fails open: when MemoryStore is down, Play loads under the lock as before and the renewal claims the entry later.
- Timing (PROVISIONAL): TTL 90 s, renewal every 30 s (two missed renewals tolerated), tombstone TTL 30 s, against the 120 s session lock. After a crash the entry is gone within 90 s and the lock frees 60–120 s after the crash; in that gap Play shows the existing `SessionLocked` text.
- Servers: the game keeps normal public servers of the one place. Join targets the existing public server through `TeleportOptions.ServerInstanceId = jobId` with `TeleportAsync`. Reserved servers were rejected: they need per-save access codes, break Roblox "join friend" and would split the 12-player village. Studio cannot teleport (`TeleportUnavailable`).
- "Being played by X": X is the owner when they play the save on that server, else the member who has played it there longest.
- Lookups: only co-op rows that nobody plays here are looked up (at most 8 per list, cached 15 s). A Solo save held elsewhere means a stale session of its only player, so Play returns `SaveInUse` instead of offering Join.
- No automatic retries or second hops: a failed teleport shows `ServerFull`, `SaveServerGone` or `TeleportFailed`, and a save that moved again on arrival returns `SaveInUseElsewhere`, so the picker offers Join again. Teleport data is untrusted; arrival needs the profile entry or the full `Save.Join` path with its wrong-code lockout, which also covers `Save.Teleport {code}`.
- Teammate finder (in-server only): FinderStart lists the searcher's own active co-op save when it has a free seat, else it creates a new save of the chosen size (default Duo) and plays it. The searcher owns the save; a joiner takes a free seat without a code, and a full, stopped, switched or failed save is no longer listed. Listings carry no save names. Cross-server matchmaking stays a later update.
- Budget: game-level 1000 + 120 × CCU request units per minute (HashMap `UpdateAsync` 2 units, `GetAsync` 1). Worst case per player about 41 units per minute (renewal 2, claim and release 4, list lookups 32, teleport 3), well below 120. Rate limits (PROVISIONAL): `Save.Teleport` 3/60 s, `Save.FinderStart` 3/300 s, `Save.FinderStop` 5/60 s, `Save.FinderList` 20/10 s, `Save.FinderJoin` 5/60 s.

## 2026-11-22 - Keep the save lock when the final save fails, CM2-R5 (engineering)
- Retry policy (PROVISIONAL): a failed final save on leave, switch, evict or shutdown is retried after `GameConfig.UnloadRetry.DelaysSeconds` = 2, 4, 8, 16, 16, 16 and 16 s (8 attempts, 78 s of waits), never past `SaveFailClosedSeconds` (90 s) after the unload began and never past `ShutdownSeconds` (18 s) after shutdown began, so BindToClose (25 s) can wait for it. Each attempt is one `PersistenceService:save` (3 `UpdateAsync` tries), at most 24 writes per retrying save over about 90 s, well under the per-server write budget. A lost lock (`SessionLocked`) or an invalid state (`NotLoaded`) stops at once.
- Release rule: the DataStore lock is released only after a successful final save (and, as before, for a state that can never be saved: corrupt, `SessionLocked`, `NotLoaded`). The save-to-server map entry is released only after a successful unload. Old rule: the lock was released after the final save whether it succeeded or not, so a later load could take over the record and lose everything since the last good save.
- Giving up: when the retries are used up or the deadline passes, the session is dropped from memory, its changes since the last good save are lost (with a warning), the call returns `SaveFailed`, and the lock and the map entry expire on their own. Keeping the abandoned state in memory for a later retry is out of scope. A Play of the same save on this server during the retry gets `SessionBusy` and never loads under the retrying session.
- Switch abort: a switch (`Save.Play` of another save) or `Save.LeaveTeam` whose final save of a healthy session fails once, before shutdown, calls the unload off: the session goes live again, the player stays registered on it and gets `SwitchSaveFailed`, and the regular flush keeps saving it. A save that already failed closed, or a switch during shutdown, waits for the whole retry instead.
- Locator renewal in the unloading thread: before every retry wait, the unloading thread claims the map entry again for the leaving host. This replaces the CM2-S3 out-of-scope note that proposed adding retrying companies to `renewLocations`, because a renewal running in another thread could land after the final release and leave a stale held entry for 90 s. `renewLocations` keeps skipping unloading companies; at most 7 claims per unload.
- Locator before plot: `_unloadShared` now releases the map entry (which yields) before the plot, so no yield lies between the plot release and the caller's deactivation handler.

## 2026-11-22 - HUD shell and Lot Manager, CM2-40 (engineering)
- Old rule: one screen-wide `ChristmasMarketUI` with the supplier panel on screen, separate buttons for saves, team and finder at fixed positions, and `UISizeConstraint`s per dialog. New rule: a top-right HUD (cash, reputation, day, lot status, save status), a left button rail, and a **Lot Manager** with the 6 reference tabs (OBSERVED, REFERENCE_GAME_LIVE_TEST section 4: Supplier, Catalog, Pricing, Employees, Land, Analytics) opened from the rail or key M. English launch, touch first (PRODUCT_SPEC 2026-11-21 Platforms and Language). Client only: no server, save, money or remote change. Origin: engineering. Files: `src/shared/UiTheme.lua` (new), `src/client/UiKit.lua`, `LotManager.lua`, `LotManagerTabs/SupplierTab.lua` (new), `UiController`, `SavePicker`, `TeamPanel`, `TeammateFinder`, `WorldLabels`, `src/shared/Localization.lua`, `tests/studio/Cases/UiTheme_Test.lua`, `tests/headless/run.luau`, `tests/studio/Playtest/RunPlaytest.lua`. Plan: `docs/plans/CM2-40.md`.
- Layout rules (all PROVISIONAL engineering values, pure math in `UiTheme`, headless-tested over a device matrix of 667x317, 780x302, 750x332, 1024x710, 960x542 and 1920x1022 safe-area sizes):
  - Compact when height < 520 or width < 720 (the ScreenGui `AbsoluteSize`, i.e. the safe area). Margin 8 compact, 12 regular; gap 8; no `UIScale`: sizes are pixel offsets from the safe-area size, so PC gets wider panels, not bigger text. Every control is at least 44 px; every computed width and height is clamped to 0, so a 1x1 viewport never errors.
  - HUD chips Cash 128, Reputation 104, Day 88, Lot 104 wide (36 high, gap 6), status line 34 high below; the Day chip is hidden when the width cannot hold the full strip next to the rail. Every ScreenGui uses `CoreUISafeInsets`.
  - Rail: 124 (compact) or 148 wide; the top clears the desktop chat window on regular screens (`max(m, floor(H * 0.3))`); compact reserves 96 px at the bottom for the thumbstick; taller content scrolls instead of overflowing.
  - Lot Manager: compact fills the safe area minus margin, header with title, cash label and Close, horizontal tab bar; regular is at most 920 x 640 beside the rail, with a vertical 168 px tab bar. Dialogs (picker, delete confirm, Team, finder) use `Dialogs` specs: regular is centred and scaled, compact is two columns (list left, footer right). The toast sits under the HUD and may cover the Lot Manager, never the HUD or the rail. The action bar box is reserved for G14 and CM2-32/33 (empty now).
- Rail slots (`LayoutOrder`): 10 LotManagerButton, 20 Shop (CM2-46), 30 Quests (G11), 40 Advent (A1), 50 SavesButton, 60 TeamButton, 70 FinderButton. A button starts hidden and the rail resizes when one becomes visible. `FinderButtonUI` is gone.
- Tab contract (for the later tab tasks: G7 Pricing, the Employees tab, G9 Land, CM2-35 Analytics and the Catalog tab): a module in `src/client/LotManagerTabs/` named in `UiTheme.LotManagerTabs` returns `{create: (page: ScrollingFrame, context: TabContext) -> TabHandle}`. `TabContext = {request, refresh, summary}`; `request` goes through `BusinessAction` and never throws. `TabHandle = {render: (summary: any?) -> (), shown: ((visible: boolean) -> ())?}`. `render(nil)` means no data (loading or a switched save). A tab reads only its own summary sub-table (`pricing`, `staff`, `plot`, `analytics`) and must not error when it is missing; it sets its page `CanvasSize`. Pages build lazily on first select; a missing module shows the `lotManagerTabSoon` placeholder, a failed `require` or `create` shows `lotManagerTabError` plus one `warn`. Every `render` and `shown` runs in `pcall`, so a faulty tab warns once and never stops the HUD poll.
- Modal rules: `UiKit.claimModal` / `releaseModal` / `closeModals` coordinate the Lot Manager, Team panel and finder: opening one closes the other holders first. The save picker is the base layer: its `open()` calls `closeModals()` and it never claims, so the finder still opens over it. While the Lot Manager is open in compact, the HUD and rail hide. Close always works on the first tap (REFERENCE_GAME_LIVE_TEST section 10: the reference's Menu and close buttons were broken). `CompanyReady` false closes the manager.
- HUD data: cash comes from the summary (the order handler no longer overwrites it; the accepted-order sentence is shown in the Supplier detail line). The day reads `summary.day` (written by G12) and shows "Day -" until then. The lot chip shows Open while `CompanyReady`, Paused when `CompanyError` is set, else Closed.
- Derivations where the plan was silent (engineering, for the reviewer to confirm):
  1. `managerLayout.title` box: the title spans the header width minus Close and its gap, and in compact also minus the cash label and its gap (`cw - 96 - 8`, minus `128 + 8` when compact), so title, cash label and Close never overlap.
  2. Overlap test: `hud`, `rail`, `toast` and `actionBar` must not overlap each other; `status` is relative to the HUD strip, so the test asserts it is inside the HUD box and that it overlaps no chip, instead of requiring it to be disjoint from `hud`.
  3. The 1x1 viewport test checks only that every width and height is at least 0 and that `railMaxHeight` is at least 0; it does not require positions to be inside, because nothing fits in 1x1.
  4. The cash and reputation chips show the existing `loading` string whenever no summary table is available (before the first summary, or when `renderChips` gets a non-table), and `AutoLocalize` stays off for both chips, as for all player-derived numbers.
  5. `SupplierTab` `render(nil)` clears the cached summary, delivery ID, selected quantity and placement count and shows `loading`, so a switched save never displays the previous save's data before its own summary.
  6. The picker keeps its 16 px button text through a small local wrapper over `UiKit.button(..., 16)`, because the UiKit default is 15 and the plan says the picker looks unchanged.
  7. The Lot Manager `TabBar` is a ScrollingFrame with `ScrollBarThickness 0`; its tab buttons are positioned from the `managerLayout.tabs` boxes (not a `UIListLayout`), so the horizontal compact bar scrolls by touch without a visible scrollbar.
  8. Key M toggles the Lot Manager only while `CompanyReady` is true (like the rail button), and not when `gameProcessedEvent` is set (for example while typing in a text box).
  9. Compact `DeleteConfirm` `leftWidth`: `dialogLayout` computes the 55 % compact `leftWidth` for every spec, but DeleteConfirm has no list or footer and passes no `leftItems`, so its content keeps the full inner width; the test checks only its inner height (at least 246).
- Reviewer (2026-11-22): derivations 1-9 confirmed; item 8 is the plan's own rule (step 6), the `CompanyReady` guard matches the rail button. The locale rule now lives only in `UiKit` (WorldLabels uses it too).
- Known limit: very long error sentences in the phone footer status labels truncate with an ellipsis instead of wrapping fully (CM2-43 text audit). Studio checks that need a real viewport (device simulator, screenshots) are BLOCKED until PC-3 and run in CM2-UV (f).
- Test plan: unit runner threshold 286 -> 293 tests (`BUILD cm2-40`), section 3 J points to the plan.

## 2026-11-22 - Price benchmark and Pricing tab, CM2-G7 (engineering)
- Supersedes the CM2-G6 bullet "Douglas Fir typical medium 70 and starting medium price 72 are PROVISIONAL … until CM2-G7". Plan: `docs/plans/CM2-G7.md`.
- Benchmark: the "typical" medium price is `wholesale.Medium × 5` per species (OBSERVED ≈ 5×, REFERENCE_GAME_LIVE_TEST §4.3; `GameConfig.Pricing.BenchmarkMultiplier`, `GameConfig.typicalMediumFor`): Douglas 140, Fraser 160, Noble 185, Blue Spruce 210. Noble is 185, not the observed 184 (derived rule, 0.5 % off). `typicalMedium` and `initialMediumPrice` are removed from `GameConfig.Trees`.
- Per-size benchmark: `typical(size) = Economy.priceForSize(typicalMedium, size)` (the 80/130 rule, PROVISIONAL; `Economy.typicalPrice`), not `wholesale[size] × 5`, because the player sets only the medium price and a per-size wholesale benchmark would make Large always look cheap and Small expensive.
- Manual prices: one medium price per species; Small and Large follow 80 %/130 % (OBSERVED). No price per size.
- No schema change: `SCHEMA_VERSION` stays 12 and `GameConfig.VERSION` stays 1; `mediumPrices` and `autoPricing` were already saved.
- Existing saves keep their prices (player settings); only missing or corrupt prices are refilled, now with the typical price. The old defaults 72/82/96/105 lie inside the new bounds; a saved price outside them is left alone and the tab's next step press sends a value clamped into the bounds. New saves start at the typical price (PROVISIONAL).
- Bounds: unchanged multipliers, `min = ceil(typical × 0.5)`, `max = floor(typical × 2.5)` → Douglas 70–350, Fraser 80–400, Noble 93–462, Blue Spruce 105–525. Rate limits unchanged. Auto pricing keeps its rule on the new base: `floor(typical × (1 − min(displayed/5, 1) × 0.15) + 0.5)`, clamped, every 3 s; a manual price turns it off; reservations keep their locked price.
- Budgets (PROVISIONAL until CM2-N1): `budget = (typical(preferred species, preferred size) × p + 50) // 100` with `p = 85 + ((n × 17) % 71)`, i.e. 85–155 % of the size benchmark. Demand: `priceRatio = salePrice / typical(species, size)`; `Demand.score` unchanged.
- Sentiment (PROVISIONAL thresholds, our own wording): `medium × 100` against `typical × percent`: ≤ 85 Bargain, ≤ 110 Fair, ≤ 130 Pricey, above TooHigh (`GameConfig.Pricing.SentimentPercent`).
- Margin rounding: `margin = medium − wholesale.Medium`, `marginPercent = floor(margin × 100 / medium + 0.5)` (matches the four reference cards: 81, 80, 81, 80); per size `price = priceForSize(medium, size)`, `profit = price − wholesale[size]`.
- Summary: `Company.GetSummary` gains a server-derived `pricing` table (`PricingService.summary`): `{automatic, species = {speciesId, mediumPrice, minPrice, maxPrice, typicalMedium, wholesaleMedium, marginMedium, marginPercent, sentiment, sizes = {sizeId, price, wholesale, profit}}}` in `SpeciesOrder`.
- Pricing tab (`src/client/LotManagerTabs/PricingTab.lua`, texts from the pure `src/shared/PricingView.lua`): one 324 px column with title, the 80/130 rule sentence, the 44 px automatic-pricing button (Gold on, Sand off), its hint, a status line and one 180 px card per species (name, sentiment, wholesale and typical, margin $ and %, S/M/L prices with profit, −5/−1/+1/+5 buttons of 44 px around the price). Step presses clamp into the server bounds and are debounced 0.4 s per species with at most one request in flight, so repeated taps stay under the rate limit; a newer target is sent right after the in-flight request returns.
- Derivations where the plan was silent (engineering, for the reviewer to confirm):
  1. `render` with a pricing table sets `AutoPricing.Active = true` again (the plan sets it false without data); otherwise the button would stay inactive after the first loading render.
  2. `PricingStatus` shows `loading` only while there is no pricing table; with data it shows the last result or error (empty before the first one), as the plan's "last result or error" content says.
  3. `CompanyStateService_Test` "applies automatic pricing through the authoritative save boundary" expects Fraser 155 instead of 78 (the unchanged auto rule on the new 160 base with one tree displayed); the plan's test table did not list this test.
- Playtest fixture: `RunPlaytest` sets the lowest allowed Douglas price (70) on the player in preflight and on the shadow after its join, because new saves start at 140 and the fixed visit profiles must always afford the playtest tree. Unit runner threshold 293 → 308 (`BUILD cm2-g7`).
- Reviewer (2026-11-22): derivations 1-3 confirmed (1 is needed so the button works after the first loading render; 3 is the unchanged auto rule on the new base, floor(160 × 0.97 + 0.5) = 155). Noble 185 vs the observed 184 conflicts with the owner fidelity rule; it is kept for now and routed to follow-up CM2-G7a (planner decision: OBSERVED override 184 or a recorded exception).

## 2026-11-22 - Noble Fir typical price 184 (OBSERVED override), CM2-G7a (engineering)
- Supersedes the CM2-G7 benchmark bullet "Noble is 185, not the observed 184": the Noble Fir typical medium price is the observed $184 (REFERENCE_GAME_LIVE_TEST §4.3).
- Override, not a recorded exception: the owner Fidelity rule adopts every number of the reference game, so an exception that keeps 185 against the observed 184 is not allowed. Douglas 140, Fraser 160 and Blue Spruce 210 match 5 × medium wholesale exactly, so the rule stays for them; Noble 184 (4.97 ×) is the only observed card that differs.
- Config: `GameConfig.Pricing.TypicalMediumOverride = { NobleFir = 184 }`; `GameConfig.typicalMediumFor` returns the override for a known species and otherwise `wholesale.Medium × BenchmarkMultiplier`. An override key that is not a species is ignored. Each later observed card that differs from the rule goes into this table.
- The 5 × rule is the PROVISIONAL extrapolation for species without an observed card (HQ 2–4, CM2-G9).
- Noble follows: bounds 92–460 (`ceil(184 × 0.5)`, `floor(184 × 2.5)`), size benchmarks 147/184/239, automatic pricing base 184; sentiment, customer budgets and demand read the same benchmark.
- Saves: no migration. New saves start Noble at 184; saved Noble prices are player settings and are kept, including a 185 written since CM2-G7, and a saved 461 or 462 is left alone under the CM2-G7 rule for out-of-bounds saved prices.
- Remote: `Pricing.SetMediumPrice` code, rate limits and error codes are unchanged; only the accepted Noble range changes from 93–462 to 92–460.
- No schema change: `SCHEMA_VERSION` stays 12 and `GameConfig.VERSION` stays 1.
- Unit runner threshold 308 → 309 (`BUILD cm2-g7a`).
- Plan: `docs/plans/CM2-G7a.md`.

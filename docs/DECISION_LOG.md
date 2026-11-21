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

## 2026-11-22 — owner: cm2-run works through the backlog without stopping
- Previous rule: the continuous-execution loop in CLAUDE.md had no dedicated skill; each task was started with `cm2-task`.
- New rule (owner): the skill `cm2-run` works through the whole backlog (or a given scope) task by task via `cm2-task` in one session, without pausing at milestones and without pushing. Tasks that need the owner are skipped in favour of the next workable one. Blocked after two failed attempts; the run stops after three blocked tasks in a row. Studio-only gaps are committed as BLOCKED with a follow-up task.
- On any blocker the work is secured (commit to `main` if checks and review pass, otherwise a local `wip/<ID>` branch), and the planner writes a machine-readable entry in "Für den Owner am PC" (top of CLAUDE_BACKLOG.md) with the owner's steps, a check, the blocked tasks and the follow-up task. Whenever a run ends before everything is done, the planner (Opus) refreshes the whole backlog assuming the owner resolves every PC entry; the next run checks those entries first.
- Empty backlog: gap check limited to gaps traceable to PRODUCT_SPEC, the milestone gates or TEST_PLAN; none found ends the run.
- Triggers: `/cm2-run`, "durcharbeiten", "mach weiter", "weiter", "hustle" ("hasseln").
- Origin: owner. Files: `.claude/skills/cm2-run/SKILL.md`, `.claude/hooks/route-prompt.js`, `CLAUDE.md`, `docs/CLAUDE_BACKLOG.md`.

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

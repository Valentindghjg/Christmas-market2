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

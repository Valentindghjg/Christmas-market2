# CM2-UVF8 — Shop category bar fits, boost line always visible, "$" in cash packs

Written by: `planner` (Opus 5.5, high). Implemented by: the agent for the tier below. Playtested by: `playtester`. Reviewed and committed by: `reviewer`. Pipeline: skill `cm2-task`.
Rule: everything below is decided. If something is missing, the implementer stops and reports; it never chooses.

## Goal
In the Shop all seven category tabs sit inside the panel and can be clicked; an active Cash Rush shows "Active: mm:ss left" at the top of the shop in every category; cash packs read "Adds $1,200 …". The full playtest no longer inherits a boost or pass override from manual shop checks.

## Source of truth
- Studio-queue batch 2026-11-24 (Studio `53ca11c3`, `main` @ 1512b26, BUILD `cm2-g12a`), CM2-46b client checks:
  - FAIL: `Category_PremiumDecor` at x 1330, panel right edge about 1062, `CategoryBar` CanvasSize X 0, no scrolling; Event and Special trees also clipped.
  - FAIL: no `BoostLine` anywhere in PlayerGui after `shopReceipt BoostCashX2` (PurchaseGranted, ledger entry present).
  - Deviation: "Adds 1,200 to the save …" instead of "Adds $1,200 …".
- Same batch, final full run: FAIL 41 "double trigger: cash 36539 -> 36679, expected +70" with sales +1. Cause: the Cash Rush granted for the BoostLine check was still live, and `Purchases.cashMultiplier` doubled the sale. This is test isolation, not a checkout defect.
- Planner reading of the BoostLine FAIL: the line lived only on the `Product_BoostCashX2` row, which exists only in the Boosts category, and every open resets to Starter. The server summary `shop.cashBoostSeconds` = `purchases.boosts.CashX2` is correct; step 41 proves the boost was live.
- Plans `CM2-46b.md` steps 1 and 4, `CM2-46a.md` A2 (`shopClearBoosts`). PRODUCT_SPEC "UI look": the UI stays functional until CM2-UI (tokens only).

## Implementer tier
Tier: S. Reason: client UI layout, one string, one playtest fixture line; no save, money, remote or server change.

## Skills to load
roblox-collaboration-mode, roblox-gui, roblox-input, roblox-localization, roblox-luau-core, roblox-tooling.

## Files
| File | New/Change | Purpose |
|---|---|---|
| `src/client/ShopPanel.client.lua` | Change | Fixed category bar, panel-level `BoostLine` |
| `src/shared/UiTheme.lua` | Change | Token `ShopCategoryBar` |
| `src/shared/Localization.lua` | Change | `shopDescCash` en and de |
| `tests/studio/Cases/Localization_Test.lua` | Change | +1 test |
| `tests/studio/Playtest/Support/Fixtures.lua` | Change | PREFLIGHT clears boosts and R's pass overrides |
| `tests/studio/Playtest/RunPlaytest.lua` | Change | `BUILD = "cm2-uvf8"` |
| `docs/TEST_PLAN.md` | Change | One sentence (step 6) |
| `docs/DECISION_LOG.md` | Change | One entry (step 6) |

## Data and config
- `UiTheme.ShopCategoryBar = { gap = 6, maxText = 13, minText = 9 }`. Place it directly after `UiTheme.Dialogs`. `maxText` equals `UiTheme.TextSize.Small`.
- `Localization` en and de: `shopDescCash = "Adds $%s to the save you are playing."` (was `"Adds %s …"`). No other key changes. DE stays equal to EN (CM2-46b rule).
- No schema, remote or error-code change.

## Steps
1. **CategoryBar** (`ShopPanel.client.lua`):
   - Build `CategoryBar` as a `Frame`, not a `ScrollingFrame`: BackgroundTransparency 1, BorderSizePixel 0, `ClipsDescendants = true`, Position and Size unchanged.
   - Delete the CanvasSize, AutomaticCanvasSize, ScrollingDirection and ScrollBarThickness lines.
   - The `UIListLayout` stays horizontal with SortOrder LayoutOrder and `Padding = UDim.new(0, UiTheme.ShopCategoryBar.gap)`.
   - Each `Category_<id>` button, with `n = #ShopConfig.Categories` and `gap = UiTheme.ShopCategoryBar.gap`:
     - `Size = UDim2.new(1 / n, -math.ceil(gap * (n - 1) / n), 0, BUTTON_HEIGHT)`;
     - `TextScaled = true`, `TextWrapped = true`;
     - one `UITextSizeConstraint` child with `MaxTextSize = maxText` and `MinTextSize = minText`.
   - Text, colours, LayoutOrder and Activated stay as they are.
   - Check: at the 536 px inner width (maxWidth 560, padding 12) 7 tabs × about 70.6 px plus 6 gaps × 6 = 530 px ≤ 536.
2. **BoostLine** (`ShopPanel.client.lua`):
   - `Title.Size = UDim2.new(0.5, 0, 0, 30)`.
   - Build once, right after Title: `BoostLine = textLabel(panel, "BoostLine", "", UiTheme.TextSize.Small)` with Position `UDim2.new(0.5, 0, 0, 4)`, Size `UDim2.new(0.5, 0, 0, 22)`, `TextXAlignment = Right`, `TextColor3 = GOLD` and `Visible = false`.
   - `updateBoostLabel()` sets `BoostLine.Visible = boostLeft > 0`. While visible it sets Text to `localizedFormat("shopBoostActive", formatClock(boostLeft))`.
   - Call `updateBoostLabel()` in three places: at the end of `fetchCatalog` after `boostLeft` is set, in the countdown loop after the decrement, and in `open()` after setting `boostLeft = 0`, before the fetch (so the line is hidden while loading).
   - Delete the per-row block (`product.key == "BoostCashX2"` … `boostLabel = line`), the `boostLabel` local and `boostLabel = nil` in `clearRows`. `render` no longer touches the line.
3. **Localization**: `shopDescCash` as in Data, in en and de.
4. **PREFLIGHT** (`Fixtures.lua` `preflight`):
   - Directly after `resetCustomers()`, add `call("shopClearBoosts", nil)` and `call("shopPasses", { userId = R.userId, passes = {} })`.
   - Comment: `-- CM2-UVF8: manual shop checks may leave a Cash Rush or a pass override on R; sales steps expect x1 cash.`
   - After `local snapshot = snap(R.userId)`, add `check(snapshot.purchases.boosts.CashX2 == 0, "Cash Rush time left on R after shopClearBoosts")`.
   - The return strings stay unchanged.
5. `RunPlaytest.BUILD = "cm2-uvf8"`. The step count stays 62.
6. **Docs**:
   - TEST_PLAN, in the "Repeatable run (CM2-G20)" bullet, append: "PREFLIGHT (03) first ends every Cash Rush (`shopClearBoosts`) and clears R's test pass overrides (`shopPasses`), so manual shop checks before a run cannot double sale cash (CM2-UVF8)."
   - DECISION_LOG entry "CM2-UVF8 (2026-11-24)":
     - The shop category bar no longer scrolls. The 7 tabs share the width, with text scaled 9–13 px.
     - The Cash Rush line sits at the top right of the shop in every category.
     - PREFLIGHT clears boosts and R's pass overrides.

## Tests (headless)
| Test case file | Test name | Asserts |
|---|---|---|
| `Localization_Test.lua` | formats the cash pack description with a dollar sign | `Localization.format("en", "shopDescCash", "1,200") == "Adds $1,200 to the save you are playing."`; the same call with `"de"` gives the same text |

Expected: `lune run tests/headless/run.luau` 586 run, 0 failed (585 + 1).

## Playtest (Studio, via playtester)
Run this as a batch with every entry of "Studio-Test ausstehend" (skill `cm2-task` step 3), on R's save, PC viewport. The order is fixed: 0, then 1–6, then the queued entries, then 7 last.
0. (a) gate: in Play, `workspace.CurrentCamera.ViewportSize` > 100x100 and a capture shows the 3D world, both in the same run. The live source shows BUILD `cm2-uvf8`.
1. Open the Shop (`ShopButton`) and capture it. Read these values:
   - `CategoryBar.ClassName == "Frame"`.
   - Every `Category_*` (7) lies inside the bar: `X >= bar.X - 0.5` and `X + W <= bar.X + bar.W + 0.5`.
   - Each tab has `TextFits == true` and `AbsoluteSize.Y >= 44`.
2. Click each of `Category_SpecialTrees`, `Category_Event` and `Category_PremiumDecor` in turn. Each turns Gold and lists 2, 4 and 9 rows, all "Coming soon". Then click `Category_Cash`: `Product_CashPinecone.Description` reads "Adds $1,200 to the save you are playing."
3. Close the Shop. Then on the server:
   - `shopClearBoosts`;
   - `shopReceipt {userId = R.userId, productKey = "BoostCashX2", purchaseId = "uvf8_" .. HttpService:GenerateGUID(false), robux = 10}`;
   - `snapshot(R.userId).purchases.boosts.CashX2` is between 1780 and 1800.
4. Open the Shop: it opens on Starter, and `ShopPanel.BoostLine.Visible == true` with Text matching `^Active: 29:%d%d left$` or "Active: 30:00 left". After 3 s the seconds are lower. Click `Category_Boosts`: the line is still visible. Capture it. Then run `shopClearBoosts` and reopen the Shop: `BoostLine.Visible == false`.
5. VIP tag (CM2-46b check 5): `shopPasses {userId = R.userId, passes = {PassVip = true}}`, then R has attribute `ShopPassVip == true`. If the client can send chat (`TextChatService.TextChannels.RBXGeneral:SendAsync("vip check")`), capture the chat line with the "[VIP]" prefix. If it cannot, mark it BLOCKED: this does not block the tick of line 13, and the reviewer adds a live check to `docs/FRIENDS_TEST.md`. Finally `shopPasses {userId = R.userId, passes = {}}`.
6. Close releases the modal: with the Shop open, `LotManagerButton` opens the Lot Manager and the Shop is hidden.
7. **Clean full run, last:** no manual actions and no extra client NPC activity during the run. `runPlaytest {mode="full"}` gives `steps=62 pass=62`, and the PREFLIGHT line passes the new boost check. If 41 or 37 fails again, record the full FAIL line plus the `snapshot(R.userId)` cash, sales and `purchases.boosts`, and stop for a planner amendment.

## Acceptance
- Checks: `stylua --check src tests`, `selene src tests`, `lune run tests/headless/run.luau` 586/586, `rojo build` both project files.
- Playtest 0–7 PASS (5 may be BLOCKED for the chat line only). After that, line 13 (CM2-46) is ticked: its client checks 1–6 are covered by CM2-46b's PASS items plus this task. Test purchases stay under PC-8 / CM2-46c and do not block the tick.
- The CM2-46b queue entry is gone (already removed by the planner). The other queued entries pass or stay queued as their own lines say.

## Out of scope
- Shop look (CM2-UI).
- A HUD boost chip.
- Real purchases (PC-8).
- Any change to receipts, boosts or the cash multiplier.

--!strict
-- Playtest steps 51-53 (full mode): the Robux shop server (CM2-46a, docs/plans/CM2-46a.md).
-- Installed by RunPlaytest.execute after Steps/Staff. Receipts are simulated through the real
-- receipt path (StudioTestHook shopReceipt); nothing prompts or charges. The owner's product IDs
-- exist for 12 products (ShopConfig CREATED_IDS); step 53 never prompts one of them, so real test
-- purchases stay a manual PC-10 check.
-- Step details (moved from docs/TEST_PLAN.md, CM2-FAST):
-- `51 SHOP_RECEIPT` (CM2-46a: `shopReceipt {R, CashPinecone, pt51-<clock>, 29}` is
-- `PurchaseGranted`, cash +1200, the save's last receipt is the ID, `owned.CashPinecone` +1; the
-- same call again is `PurchaseGranted` with cash unchanged; `shopLedger` `robuxSpent` +29 over both
-- calls, the ID in `done`, not in `pending`; after `rejoin` the receipt is still in the save and
-- cash is equal), `52 SHOP_PERKS` (`shopClearBoosts` first; S places 2 Douglas Medium; with
-- `shopPasses {PassCashX2}` and a Cash Rush receipt (`boosts.CashX2` 1795–1800) `visit {S, 8}` pays
-- 4 × the Douglas Medium price, without the pass 2 ×; `shopClearBoosts` leaves `boosts.CashX2` 0;
-- `setStaff Cashier 1`, `setStaffEnergy Cashier 21`, a Hot Cider Round receipt brings the Cashier's
-- energy to ≥ 99 within 3 s, `setStaff Cashier 0`; with `shopPasses {PassInstantDelivery}` an order
-- of 1 Douglas Small is in its bay within 3 s without a clock advance; passes cleared, open orders
-- expired), `53 SHOP_GUARD` (R's `Shop.Catalog` lists 27 products: the 12 products with an ID are
-- `Buy` or `Owned`, the other 15 `ComingSoon`; `Shop.Prompt DecorFatherChristmas` is `ComingSoon`,
-- `Nope` is `UnknownProduct`; a receipt for user 999000123 (no player, no save) is
-- `NotProcessedYet` at once; `shopPrompts` = 0)
return function(ctx: any)
	local DELIVERY_WAIT = ctx.DELIVERY_WAIT
	local EXPIRY_WAIT = ctx.EXPIRY_WAIT
	local R = ctx.R
	local ReplicatedStorage = ctx.ReplicatedStorage
	local S = ctx.S
	local SIZE = ctx.SIZE
	local SPECIES = ctx.SPECIES
	local act = ctx.act
	local actOk = ctx.actOk
	local addStep = ctx.addStep
	local advance = ctx.advance
	local awaitDelivery = ctx.awaitDelivery
	local call = ctx.call
	local rejoin = ctx.rejoin
	local check = ctx.check
	local invoke = ctx.invoke
	local orderTrees = ctx.orderTrees
	local placeOne = ctx.placeOne
	local poll = ctx.poll
	local snap = ctx.snap
	local staffSnapshot = ctx.staffSnapshot
	local visit = ctx.visit
	local Economy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Economy")) :: any
	local ShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopConfig")) :: any

	local NO_PLAYER_USER_ID = 999000123
	local RESTED_SECONDS = 3
	local INSTANT_SECONDS = 3

	local function receipt(userId: number, productKey: string, purchaseId: string, robux: number?): string
		return call("shopReceipt", { userId = userId, productKey = productKey, purchaseId = purchaseId, robux = robux })
	end

	local function ledger(userId: number): any
		return call("shopLedger", { userId = userId })
	end

	local function inDone(record: any, purchaseId: string): boolean
		for _, entry in record.done do
			if entry.purchaseId == purchaseId then
				return true
			end
		end
		return false
	end

	local function purchaseId(step: string): string
		return string.format("pt%s-%d", step, call("clock", nil))
	end

	-- S's live Cashier record in staffSnapshot, or nil.
	local function cashierEntry(): any
		for _, entry in staffSnapshot().staff do
			if entry.plotId == S.plotId and entry.role == "Cashier" and entry.companyId ~= nil then
				return entry
			end
		end
		return nil
	end

	-- Expires S's open customer orders so the next visits find a free parking space.
	local function clearOrders()
		if #snap(S.userId).customerOrders == 0 then
			return
		end
		advance(EXPIRY_WAIT)
		check(
			poll(function()
				return #snap(S.userId).customerOrders == 0
			end, 8),
			"S customer orders still open 8 s after the clock advance"
		)
	end

	-- Step 51: a cash-pack receipt is granted once into R's save, recorded in the ledger and
	-- kept after a rejoin.
	local function receiptStep(): string
		local id = purchaseId("51")
		local before = snap(R.userId)
		local ledgerBefore = ledger(R.userId)
		local ownedBefore = before.purchases.owned.CashPinecone or 0
		local first = receipt(R.userId, "CashPinecone", id, 29)
		check(first == "PurchaseGranted", "first receipt returned " .. tostring(first))
		local granted = snap(R.userId)
		check(
			granted.cash == before.cash + 1200,
			string.format("cash %d -> %d, expected +1200", before.cash, granted.cash)
		)
		local receipts = granted.purchases.receipts
		check(receipts[#receipts] == id, "the save's last receipt is not " .. id)
		check(
			granted.purchases.owned.CashPinecone == ownedBefore + 1,
			string.format("owned.CashPinecone %d -> %s", ownedBefore, tostring(granted.purchases.owned.CashPinecone))
		)
		local second = receipt(R.userId, "CashPinecone", id, 29)
		check(second == "PurchaseGranted", "replayed receipt returned " .. tostring(second))
		check(snap(R.userId).cash == granted.cash, "cash changed on the replayed receipt")
		local ledgerAfter = ledger(R.userId)
		check(
			ledgerAfter.robuxSpent == ledgerBefore.robuxSpent + 29,
			string.format("robuxSpent %d -> %d, expected +29", ledgerBefore.robuxSpent, ledgerAfter.robuxSpent)
		)
		check(inDone(ledgerAfter, id), id .. " missing from the ledger's done list")
		check(ledgerAfter.pending[id] == nil, id .. " still pending in the ledger")
		rejoin(R.userId)
		local rejoined = snap(R.userId)
		check(table.find(rejoined.purchases.receipts, id) ~= nil, id .. " not in the save after the rejoin")
		check(
			rejoined.cash == granted.cash,
			string.format("cash %d after the rejoin, expected %d", rejoined.cash, granted.cash)
		)
		return string.format("%s granted once (+1200), robuxSpent +29, kept after rejoin", id)
	end

	-- Step 52: Golden Till and Cash Rush multiply S's sale cash; Hot Cider Round rests the
	-- Cashier; Express Sleigh delivers at once.
	local function perksStep(): string
		call("pauseCustomers", true)
		call("shopClearBoosts", nil)
		clearOrders()
		local data = orderTrees(S.userId, 2)
		advance(DELIVERY_WAIT)
		awaitDelivery(S.userId, data.orderId)
		placeOne(S.userId, data.bay)
		placeOne(S.userId, data.bay)
		call("shopPasses", { userId = S.userId, passes = { PassCashX2 = true } })
		local boost = receipt(S.userId, "BoostCashX2", purchaseId("52a"), 10)
		check(boost == "PurchaseGranted", "Cash Rush receipt returned " .. tostring(boost))
		local boosted = snap(S.userId).purchases.boosts.CashX2
		check(boosted >= 1795 and boosted <= 1800, "boosts.CashX2 " .. tostring(boosted) .. ", expected 1795-1800")
		local price = Economy.priceForSize(snap(S.userId).mediumPrices[SPECIES], SIZE)
		local before = snap(S.userId)
		visit(S.userId, 8)
		local both = snap(S.userId).cash - before.cash
		check(both == 4 * price, string.format("pass + boost sale paid %d, expected %d", both, 4 * price))
		call("shopPasses", { userId = S.userId, passes = {} })
		local middle = snap(S.userId)
		visit(S.userId, 8)
		local boostOnly = snap(S.userId).cash - middle.cash
		check(boostOnly == 2 * price, string.format("boost-only sale paid %d, expected %d", boostOnly, 2 * price))
		call("shopClearBoosts", nil)
		check(snap(S.userId).purchases.boosts.CashX2 == 0, "Cash Rush time left after shopClearBoosts")

		call("setStaff", { employeeId = "Cashier", count = 1 })
		check(
			poll(function()
				return cashierEntry() ~= nil
			end, 10),
			"S's Cashier did not appear within 10 s"
		)
		call("setStaffEnergy", { employeeId = "Cashier", energy = 21 })
		local rested = receipt(S.userId, "BoostRested", purchaseId("52b"), 5)
		check(rested == "PurchaseGranted", "Hot Cider Round receipt returned " .. tostring(rested))
		check(
			poll(function()
				local entry = cashierEntry()
				return entry ~= nil and entry.energy >= 99
			end, RESTED_SECONDS),
			"Cashier energy below 99 within 3 s of Hot Cider Round"
		)
		call("setStaff", { employeeId = "Cashier", count = 0 })

		call("shopPasses", { userId = S.userId, passes = { PassInstantDelivery = true } })
		local response = act(S.userId, "Supplier.PlaceOrder", { speciesId = SPECIES, sizeId = "Small", quantity = 1 })
		check(
			type(response) == "table" and response.ok == true,
			"Supplier.PlaceOrder Small failed: "
				.. tostring(type(response) == "table" and response.errorCode or response)
		)
		local bay = response.data.bay
		local landed = poll(function()
			local bays = snap(S.userId).bays
			local entry = bays[bay]
			return type(entry) == "table" and (entry.counts.Small or 0) >= 1
		end, INSTANT_SECONDS)
		call("shopPasses", { userId = S.userId, passes = {} })
		check(landed, "Express Sleigh order not in bay " .. tostring(bay) .. " within 3 s")
		actOk(S.userId, "Supplier.SellBack", { speciesId = SPECIES, sizeId = "Small", quantity = 1 })
		local emptied = poll(function()
			local entry = snap(S.userId).bays[bay]
			return type(entry) == "table" and entry.total == 0 and entry.arriving == 0
		end, 3)
		check(emptied, "bay " .. tostring(bay) .. " not empty after the sell-back")
		clearOrders()
		return string.format(
			"x4 sale %d, x2 sale %d (price %d), Cashier rested, express delivery in bay %d, sold back",
			both,
			boostOnly,
			price,
			bay
		)
	end

	-- Step 53: a product with an ID that is ready is Buy or Owned, every other one ComingSoon; the
	-- ComingSoon prompt probe uses a product without an ID (a prompt for a product with an ID would
	-- open a real purchase dialog); an absent buyer is refused.
	local function guardStep(): string
		local catalog = call("shopAction", { userId = R.userId, action = "Shop.Catalog", payload = {} })
		check(type(catalog) == "table" and #catalog.products == 27, "catalog does not list 27 products")
		local live, soon = 0, 0
		for _, entry in catalog.products do
			local product = ShopConfig.byKey(entry.key)
			check(product ~= nil, entry.key .. " is not in ShopConfig")
			if product.id > 0 and product.ready then
				check(
					entry.state == "Buy" or entry.state == "Owned",
					entry.key .. " is " .. tostring(entry.state) .. ", expected Buy or Owned"
				)
				live += 1
			else
				check(
					entry.state == "ComingSoon",
					entry.key .. " is " .. tostring(entry.state) .. ", expected ComingSoon"
				)
				soon += 1
			end
		end
		check(live == 12 and soon == 15, string.format("%d live and %d ComingSoon, expected 12 and 15", live, soon))
		local function promptCode(productKey: string): string?
			local response = invoke("shopAction", {
				userId = R.userId,
				action = "Shop.Prompt",
				payload = { productKey = productKey },
			})
			return if type(response) == "table" then response.errorCode else tostring(response)
		end
		local coming = promptCode("DecorFatherChristmas")
		check(coming == "ComingSoon", "Shop.Prompt DecorFatherChristmas returned " .. tostring(coming))
		local unknown = promptCode("Nope")
		check(unknown == "UnknownProduct", "Shop.Prompt Nope returned " .. tostring(unknown))
		local started = os.clock()
		local absent = receipt(NO_PLAYER_USER_ID, "CashPinecone", purchaseId("53"), 29)
		check(absent == "NotProcessedYet", "receipt for an absent buyer returned " .. tostring(absent))
		check(os.clock() - started < 2, "receipt for an absent buyer waited")
		local prompts = call("shopPrompts", nil)
		check(prompts == 0, prompts .. " purchase prompt(s) shown, expected 0")
		return "12 live (Buy/Owned), 15 ComingSoon, prompts refused, absent buyer NotProcessedYet, 0 prompts"
	end

	addStep("51", "SHOP_RECEIPT", { "02a" }, receiptStep)
	addStep("52", "SHOP_PERKS", { "03" }, perksStep)
	addStep("53", "SHOP_GUARD", { "02a" }, guardStep)
end

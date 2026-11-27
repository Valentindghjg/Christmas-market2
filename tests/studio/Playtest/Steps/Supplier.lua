--!strict
-- Playtest step 70 (full mode): the supplier cart (CM2-SUP, docs/plans/CM2-SUP.md). Installed by
-- RunPlaytest.execute after Steps/Quests. Drives the shadow company S through act/actOk; every
-- cost comes from GameConfig.wholesaleFor, never from a client figure.
-- Step details:
-- CM2-SUP: `70 SUPPLIER_CART` (needs 03): (1) after DELIVERY_WAIT no order of S is pending
-- (poll <= 8 s); every SKU in S's bays is sold back (chunks <= 100) so `baysUsed` is 0; the clock
-- moves past the supplier refresh; cash >= 133. (2) `Supplier.PlaceOrder {lines = cart X}` (Douglas
-- S1 M2 + Fraser S1 M1) returns cost 133, quantity 5, 4 `orderIds`, 2 `bays`; cash drops by exactly
-- 133 and `baysUsed` is 2; a replay is `DuplicateRequest` and `{lines, cost = 1}` is
-- `UnexpectedField`, cash unchanged. (3) after DELIVERY_WAIT (poll <= 8 s) nothing is pending and
-- the bays hold Douglas {S1, M2} and Fraser {S1, M1}. (4) `placeOne` from the Douglas bay raises
-- `placementCount` by 1. (5) `Supplier.SellBack {DouglasFir, Medium, 2}` refunds 14 (cash +14);
-- selling back the other 3 trees leaves `baysUsed` 0.
-- Client readings (by the playtester, desktop and phone 666x374): the SupplierTab instances of the
-- plan's step 8 exist; row controls have AbsoluteSize.Y >= 44 and lie inside the page.
-- `AddRecommended` sets `CartCount` > 0 and `CartInfo` shows "Delivery area" and "Bays";
-- `OrderTrees` shows the toast "Order placed: …", cash drops by the total once and the cart empties.
-- `ModeSell` lists only unsold rows; `Max` then `Sell` shows the toast "Sold … back …" and cash
-- rises by the refund.
return function(ctx: any)
	local HttpService = ctx.HttpService
	local GameConfig = ctx.GameConfig
	local S = ctx.S
	local DELIVERY_WAIT = ctx.DELIVERY_WAIT
	local act = ctx.act
	local actOk = ctx.actOk
	local addStep = ctx.addStep
	local advance = ctx.advance
	local call = ctx.call
	local check = ctx.check
	local placeOne = ctx.placeOne
	local poll = ctx.poll
	local snap = ctx.snap

	local CART_X = {
		{ speciesId = "DouglasFir", sizeId = "Small", quantity = 1 },
		{ speciesId = "DouglasFir", sizeId = "Medium", quantity = 2 },
		{ speciesId = "FrasierFir", sizeId = "Small", quantity = 1 },
		{ speciesId = "FrasierFir", sizeId = "Medium", quantity = 1 },
	}

	local function cartLines(): { any }
		local lines = {}
		for _, line in CART_X do
			table.insert(lines, table.clone(line))
		end
		return lines
	end

	local function cartCost(): number
		local cost = 0
		for _, line in CART_X do
			cost += (GameConfig.wholesaleFor(line.speciesId, line.sizeId) :: number) * line.quantity
		end
		return cost
	end

	local function codeOf(response: any): string
		return tostring(type(response) == "table" and response.errorCode or response)
	end

	local function noPending(userId: number): boolean
		return poll(function()
			return #snap(userId).pendingOrders == 0
		end, 8)
	end

	local function sellBack(userId: number, speciesId: string, sizeId: string, quantity: number): any
		return actOk(userId, "Supplier.SellBack", { speciesId = speciesId, sizeId = sizeId, quantity = quantity })
	end

	-- Sells back every tree in the bays, per SKU in chunks of at most 100.
	local function emptyBays(userId: number)
		local stock = snap(userId).stock
		local keys = {}
		for key in stock do
			table.insert(keys, key)
		end
		table.sort(keys)
		for _, key in keys do
			local speciesId, sizeId = string.match(key, "^([%w_]+):(%a+)$")
			check(speciesId ~= nil and sizeId ~= nil, "unexpected stock key " .. key)
			local remaining = stock[key]
			while remaining > 0 do
				local chunk = math.min(remaining, GameConfig.MaxOrderQuantity)
				sellBack(userId, speciesId :: string, sizeId :: string, chunk)
				remaining -= chunk
			end
		end
	end

	local function bayCounts(snapshot: any, index: number): any
		for _, bay in snapshot.bays do
			if bay.index == index then
				return bay
			end
		end
		return nil
	end

	addStep("70", "SUPPLIER_CART", { "03" }, function()
		call("pauseCustomers", true)
		local expectedCost = cartCost()
		check(expectedCost == 133, "cart X costs " .. expectedCost .. " at GameConfig wholesale")

		-- (1) no pending order, empty bays, a fresh supplier stock and enough cash.
		advance(DELIVERY_WAIT)
		check(noPending(S.userId), "shadow orders still pending after 8 s")
		emptyBays(S.userId)
		local cleared = snap(S.userId)
		check(cleared.receiving.baysUsed == 0, "baysUsed " .. cleared.receiving.baysUsed .. " after selling back")
		local refreshIn = actOk(S.userId, "Company.GetSummary", {}).supplier.refreshIn
		advance(math.clamp(refreshIn + 1, 1, 86400))
		local cash = snap(S.userId).cash
		check(cash >= expectedCost, string.format("shadow cash %d < %d", cash, expectedCost))

		-- (2) one atomic cart order, then a replay and a priced payload are refused.
		local requestId = "sup70_" .. HttpService:GenerateGUID(false)
		local placed = act(S.userId, "Supplier.PlaceOrder", { lines = cartLines() }, requestId)
		check(type(placed) == "table" and placed.ok == true, "cart order failed: " .. codeOf(placed))
		local data = placed.data
		check(data.cost == expectedCost, "cart cost " .. tostring(data.cost))
		check(data.quantity == 5, "cart quantity " .. tostring(data.quantity))
		check(#data.orderIds == 4, "cart records " .. #data.orderIds)
		check(#data.bays == 2, "cart bays " .. #data.bays)
		local afterOrder = snap(S.userId)
		check(
			afterOrder.cash == cash - expectedCost,
			string.format("cash %d after the cart, expected %d", afterOrder.cash, cash - expectedCost)
		)
		check(afterOrder.receiving.baysUsed == 2, "baysUsed " .. afterOrder.receiving.baysUsed .. " after the cart")
		local replay = act(S.userId, "Supplier.PlaceOrder", { lines = cartLines() }, requestId)
		check(codeOf(replay) == "DuplicateRequest", "cart replay: " .. codeOf(replay))
		local priced = act(S.userId, "Supplier.PlaceOrder", { lines = cartLines(), cost = 1 })
		check(codeOf(priced) == "UnexpectedField", "cart with cost: " .. codeOf(priced))
		check(snap(S.userId).cash == afterOrder.cash, "cash moved on a refused cart")

		-- (3) the cart lands in its two bays.
		advance(DELIVERY_WAIT)
		check(noPending(S.userId), "cart still pending after 8 s")
		local landed = snap(S.userId)
		local douglasBay, fraserBay = data.bays[1], data.bays[2]
		local douglas, fraser = bayCounts(landed, douglasBay), bayCounts(landed, fraserBay)
		check(
			douglas ~= nil
				and douglas.speciesId == "DouglasFir"
				and douglas.counts.Small == 1
				and douglas.counts.Medium == 2,
			"Douglas bay " .. tostring(douglasBay) .. " does not hold S1 M2"
		)
		check(
			fraser ~= nil
				and fraser.speciesId == "FrasierFir"
				and fraser.counts.Small == 1
				and fraser.counts.Medium == 1,
			"Fraser bay " .. tostring(fraserBay) .. " does not hold S1 M1"
		)

		-- (4) one Douglas Medium goes onto the lot.
		local placements = landed.placementCount
		placeOne(S.userId, douglasBay)
		check(snap(S.userId).placementCount == placements + 1, "placementCount did not rise by 1")

		-- (5) sell back two Douglas Medium (bay and lot), then the rest of the cart.
		local beforeSell = snap(S.userId).cash
		local sold = sellBack(S.userId, "DouglasFir", "Medium", 2)
		check(sold.refund == 14, "Douglas Medium x2 refund " .. tostring(sold.refund))
		check(snap(S.userId).cash == beforeSell + 14, "cash did not rise by 14")
		sellBack(S.userId, "DouglasFir", "Small", 1)
		sellBack(S.userId, "FrasierFir", "Small", 1)
		sellBack(S.userId, "FrasierFir", "Medium", 1)
		local final = snap(S.userId)
		check(final.receiving.baysUsed == 0, "baysUsed " .. final.receiving.baysUsed .. " after the sell-back")
		return string.format(
			"cart $%d in %d records over bays %d+%d, replay and priced payload refused, landed S1 M2 / S1 M1, sell-back +14, bays empty",
			data.cost,
			#data.orderIds,
			douglasBay,
			fraserBay
		)
	end)
end

--!strict
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local Receiving = require(Shared:WaitForChild("Receiving"))
	local expect = t.expect

	-- An order debits once but does not reach its bay before its delivery is due (DEL-01).
	t.test("moves order through delivery and unload", function()
		local state = BusinessState.new("personal:42", 42)
		local ok, order = BusinessState.placeOrder(state, "request_100", "FrasierFir", "Medium", 2, 100)
		expect.truthy(ok)
		expect.equal(state.cash, 20)
		expect.equal(Receiving.count(state, "FrasierFir", "Medium"), 0)
		local _, early = BusinessState.reconcileDeliveries(state, 101)
		expect.equal(early, 0)
		expect.equal(Receiving.count(state, "FrasierFir", "Medium"), 0)
		expect.truthy(state.pendingOrders[order.orderId])
		local _, arrived = BusinessState.reconcileDeliveries(state, 160)
		expect.equal(arrived, 1)
		expect.equal(state.bays[order.bay].counts.Medium, 2)
		expect.equal(Receiving.count(state, "FrasierFir", "Medium"), 2)
	end)

	t.test("reports only newly arrived deliveries", function()
		local state = BusinessState.new("personal:42", 42)
		expect.truthy(BusinessState.placeOrder(state, "request_999", "FrasierFir", "Medium", 1, 100))
		local ok, arrived = BusinessState.reconcileDeliveries(state, 160)
		expect.truthy(ok)
		expect.equal(arrived, 1)
		local _, repeated = BusinessState.reconcileDeliveries(state, 160)
		expect.equal(repeated, 0)
	end)

	-- Completed orders leave the record and never land a second time.
	t.test("removes an order once it is unloaded", function()
		local state = BusinessState.new("personal:42", 42)
		local _, order = BusinessState.placeOrder(state, "request_200", "FrasierFir", "Medium", 1, 100)
		local _, arrived = BusinessState.reconcileDeliveries(state, 160)
		expect.equal(arrived, 1)
		expect.equal(state.pendingOrders[order.orderId], nil)
		local _, again = BusinessState.reconcileDeliveries(state, 160)
		expect.equal(again, 0)
		expect.equal(Receiving.count(state, "FrasierFir", "Medium"), 1)
	end)

	-- G4: each open order occupies one of the receiving bays.
	t.test("caps open supplier orders at the bay count without charging", function()
		local GameConfig = require(Shared:WaitForChild("GameConfig"))
		local state = BusinessState.new("personal:42", 42)
		state.cash = 100000
		for index = 1, GameConfig.Receiving.BayCount do
			expect.truthy(
				BusinessState.placeOrder(state, string.format("bulk_%04d", index), "FrasierFir", "Small", 1, 100)
			)
		end
		local cashBefore = state.cash
		local ok, reason = BusinessState.placeOrder(state, "bulk_overflow", "FrasierFir", "Small", 1, 100)
		expect.falsy(ok)
		expect.equal(reason, "NoFreeBay")
		expect.equal(state.cash, cashBefore)
	end)

	-- CM2-SUP: a line larger than one bay splits across bays of the same species.
	t.test("splits a single line larger than one bay", function()
		local GameConfig = require(Shared:WaitForChild("GameConfig"))
		local state = BusinessState.new("personal:42", 42)
		state.cash = 100000
		local ok, result = BusinessState.placeOrder(
			state,
			"bay_overflow",
			"FrasierFir",
			"Small",
			GameConfig.Receiving.BayCapacity + 1,
			100
		)
		expect.truthy(ok)
		expect.equal(result.orderId, "order:bay_overflow")
		expect.equal(#result.orderIds, 2)
		expect.equal(result.quantity, 10)
		local first = state.pendingOrders["order:bay_overflow"]
		local second = state.pendingOrders["order:bay_overflow:2"]
		expect.equal(first.quantity, 9)
		expect.equal(first.bay, 1)
		expect.equal(second.quantity, 1)
		expect.equal(second.bay, 2)
		expect.equal(second.requestId, "bay_overflow")
		expect.equal(second.dueAt, first.dueAt)
		expect.equal(state.cash, 100000 - 10 * GameConfig.wholesaleFor("FrasierFir", "Small"))
		expect.truthy(BusinessState.validate(state))
	end)

	-- Cart X: Douglas S1 M2 + Fraser S1 M1 = 5 trees, $133.
	local function cartX()
		return {
			{ speciesId = "DouglasFir", sizeId = "Small", quantity = 1 },
			{ speciesId = "DouglasFir", sizeId = "Medium", quantity = 2 },
			{ speciesId = "FrasierFir", sizeId = "Small", quantity = 1 },
			{ speciesId = "FrasierFir", sizeId = "Medium", quantity = 1 },
		}
	end

	local function orderCount(state): number
		local count = 0
		for _ in pairs(state.pendingOrders) do
			count += 1
		end
		return count
	end

	t.test("places a mixed cart atomically", function()
		local state = BusinessState.new("personal:42", 42)
		state.cash = 1000
		local spent = state.spent
		local stock = table.clone(state.supplier.stock)
		local history = #state.history
		local ok, result = BusinessState.placeCart(state, "cart_mixed", cartX(), 100)
		expect.truthy(ok)
		expect.equal(result.cost, 133)
		expect.equal(result.quantity, 5)
		expect.equal(state.cash, 1000 - 133)
		expect.equal(state.spent, spent + 133)
		expect.equal(orderCount(state), 4)
		expect.equal(#result.orderIds, 4)
		expect.equal(#result.bays, 2)
		expect.equal(result.bays[1], 1)
		expect.equal(result.bays[2], 2)
		expect.equal(result.bay, 1)
		expect.equal(state.bays[1].speciesId, "DouglasFir")
		expect.equal(state.bays[2].speciesId, "FrasierFir")
		for _, entry in ipairs(cartX()) do
			local key = entry.speciesId .. ":" .. entry.sizeId
			expect.equal(state.supplier.stock[key], stock[key] - entry.quantity)
		end
		expect.equal(#state.history, history + 1)
		local last = state.history[#state.history]
		expect.equal(last.kind, "OrderPlaced")
		expect.equal(last.amount, -133)
		expect.truthy(BusinessState.validate(state))
	end)

	t.test("a failing cart changes nothing", function()
		local function snapshot(state): string
			local parts = { tostring(state.cash), tostring(#state.history), tostring(orderCount(state)) }
			local keys = {}
			for key in pairs(state.supplier.stock) do
				table.insert(keys, key)
			end
			table.sort(keys)
			for _, key in ipairs(keys) do
				table.insert(parts, key .. "=" .. tostring(state.supplier.stock[key]))
			end
			for index, bay in ipairs(state.bays) do
				table.insert(parts, tostring(index) .. bay.speciesId)
				for _, sizeId in ipairs({ "Small", "Medium", "Large" }) do
					table.insert(parts, tostring(bay.counts[sizeId]))
				end
			end
			return table.concat(parts, "|")
		end
		local function refused(state, lines, code: string, requestId: string)
			local before = snapshot(state)
			local ok, reason = BusinessState.placeCart(state, requestId, lines, 100)
			expect.falsy(ok)
			expect.equal(reason, code)
			expect.equal(snapshot(state), before)
		end

		local outOfStock = BusinessState.new("personal:42", 42)
		outOfStock.cash = 1000
		outOfStock.supplier.stock["DouglasFir:Medium"] = 1
		refused(outOfStock, cartX(), "SupplierOutOfStock", "cart_stock")

		local baysBusy = BusinessState.new("personal:42", 42)
		baysBusy.cash = 1000
		for index = 1, 3 do
			baysBusy.bays[index] = { speciesId = "NobleFir", counts = { Small = 1 } }
		end
		refused(baysBusy, cartX(), "NoFreeBay", "cart_bays")

		local storageFull = BusinessState.new("personal:42", 42)
		storageFull.cash = 1000
		storageFull.bays[1] = { speciesId = "NobleFir", counts = { Medium = 28 } }
		refused(storageFull, cartX(), "StorageFull", "cart_storage")

		local poor = BusinessState.new("personal:42", 42)
		poor.cash = 100
		refused(poor, cartX(), "InsufficientFunds", "cart_funds")

		local quantities = BusinessState.new("personal:42", 42)
		quantities.cash = 100000
		for index, quantity in ipairs({ 0, -1, 1.5, 101 }) do
			local lines = cartX()
			lines[2].quantity = quantity
			refused(quantities, lines, "InvalidQuantity", "cart_quantity_" .. index)
		end
	end)

	t.test("a mixed cart lands in its bays", function()
		local state = BusinessState.new("personal:42", 42)
		state.cash = 1000
		local ok, result = BusinessState.placeCart(state, "cart_lands", cartX(), 100)
		expect.truthy(ok)
		local dueAt = state.pendingOrders[result.orderId].dueAt
		local _, early = BusinessState.reconcileDeliveries(state, dueAt - 1)
		expect.equal(early, 0)
		local _, arrived = BusinessState.reconcileDeliveries(state, dueAt)
		expect.equal(arrived, 4)
		expect.equal(state.bays[1].speciesId, "DouglasFir")
		expect.equal(state.bays[1].counts.Small, 1)
		expect.equal(state.bays[1].counts.Medium, 2)
		expect.equal(state.bays[2].speciesId, "FrasierFir")
		expect.equal(state.bays[2].counts.Small, 1)
		expect.equal(state.bays[2].counts.Medium, 1)
		expect.equal(next(state.pendingOrders), nil)
		expect.truthy(BusinessState.validate(state))
	end)

	t.test("counts stored and ordered trees against delivery storage", function()
		local GameConfig = require(Shared:WaitForChild("GameConfig"))
		local state = BusinessState.new("personal:42", 42)
		state.cash = 100000
		-- Bay capacity is enforced on mutation only, so one legacy bay may hold 28 stored trees.
		state.bays[1] = { speciesId = "NobleFir", counts = { Medium = GameConfig.Receiving.BaseStorage - 2 } }
		local ok, reason = BusinessState.placeOrder(state, "storage_full", "FrasierFir", "Small", 3, 100)
		expect.falsy(ok)
		expect.equal(reason, "StorageFull")
		expect.equal(state.cash, 100000)
		expect.truthy(BusinessState.placeOrder(state, "storage_fits", "FrasierFir", "Small", 2, 100))
		-- One lot expansion adds the observed +10 storage.
		state.progression.lotExpansion = 1
		expect.equal(BusinessState.storageCapacity(state), GameConfig.Receiving.BaseStorage + 10)
		expect.truthy(BusinessState.placeOrder(state, "storage_more", "FrasierFir", "Small", 3, 100))
	end)

	t.test("reports receiving usage", function()
		local state = BusinessState.new("personal:42", 42)
		expect.truthy(BusinessState.placeOrder(state, "summary_01", "FrasierFir", "Small", 2, 100))
		local summary = BusinessState.receivingSummary(state)
		expect.equal(summary.baysUsed, 1)
		expect.equal(summary.bayCount, 4)
		expect.equal(summary.storageUsed, 2)
		expect.equal(summary.storageCapacity, 30)
	end)
end

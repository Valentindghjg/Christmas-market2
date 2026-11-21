--!strict
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local Inventory = require(Shared:WaitForChild("Inventory"))
	local expect = t.expect

	-- An order debits once but does not enter storage before its delivery is due.
	t.test("moves order through delivery and unload", function()
		local state = BusinessState.new("personal:42", 42)
		local ok, order = BusinessState.placeOrder(state, "request_100", "FrasierFir", "Medium", 2, 100)
		expect.truthy(ok)
		expect.equal(state.cash, 20)
		expect.equal(Inventory.count(state.stock, Inventory.key("FrasierFir", "Medium")), 0)
		local early = BusinessState.unloadOrder(state, order.orderId, 101)
		expect.falsy(early)
		expect.truthy(BusinessState.unloadOrder(state, order.orderId, 160))
		expect.equal(Inventory.count(state.stock, Inventory.key("FrasierFir", "Medium")), 2)
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

	-- Completed orders leave the record and cannot be unloaded a second time.
	t.test("removes an order once it is unloaded", function()
		local state = BusinessState.new("personal:42", 42)
		local _, order = BusinessState.placeOrder(state, "request_200", "FrasierFir", "Medium", 1, 100)
		expect.truthy(BusinessState.unloadOrder(state, order.orderId, 160))
		expect.equal(state.pendingOrders[order.orderId], nil)
		local again, reason = BusinessState.unloadOrder(state, order.orderId, 160)
		expect.falsy(again)
		expect.equal(reason, "UnknownOrder")
		expect.equal(Inventory.count(state.stock, Inventory.key("FrasierFir", "Medium")), 1)
	end)

	t.test("caps open supplier orders without charging", function()
		local GameConfig = require(Shared:WaitForChild("GameConfig"))
		local state = BusinessState.new("personal:42", 42)
		state.cash = 100000
		for index = 1, GameConfig.MaxOpenOrders do
			expect.truthy(
				BusinessState.placeOrder(state, string.format("bulk_%04d", index), "FrasierFir", "Small", 1, 100)
			)
		end
		local cashBefore = state.cash
		local ok, reason = BusinessState.placeOrder(state, "bulk_overflow", "FrasierFir", "Small", 1, 100)
		expect.falsy(ok)
		expect.equal(reason, "TooManyOpenOrders")
		expect.equal(state.cash, cashBefore)
	end)
end

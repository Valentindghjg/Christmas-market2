--!strict
-- CM2-G14: receiving bays (Receiving.lua) through the BusinessState order and delivery path.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local Receiving = require(Shared:WaitForChild("Receiving"))
	local expect = t.expect

	local function richState()
		local state = BusinessState.new("personal:42", 42)
		state.cash = 100000
		return state
	end

	t.test("assigns each order its own free bay", function()
		local state = richState()
		local okA, first = BusinessState.placeOrder(state, "bay_order_a", "DouglasFir", "Medium", 2, 100)
		local okB, second = BusinessState.placeOrder(state, "bay_order_b", "DouglasFir", "Medium", 1, 100)
		expect.truthy(okA)
		expect.truthy(okB)
		expect.equal(first.bay, 1)
		expect.equal(second.bay, 2)
		expect.equal(state.bays[1].speciesId, "DouglasFir")
		expect.equal(state.bays[2].speciesId, "DouglasFir")
		expect.equal(Receiving.usedCount(state), 2)
	end)

	t.test("a delivered order lands in its bay", function()
		local state = richState()
		local _, order = BusinessState.placeOrder(state, "bay_land_1", "DouglasFir", "Medium", 2, 100)
		local dueAt = state.pendingOrders[order.orderId].dueAt
		local early, none = BusinessState.reconcileDeliveries(state, dueAt - 1)
		expect.truthy(early)
		expect.equal(none, 0)
		expect.equal(state.bays[1].counts.Medium, nil)
		expect.truthy(state.pendingOrders[order.orderId])
		local ok, delivered = BusinessState.reconcileDeliveries(state, dueAt)
		expect.truthy(ok)
		expect.equal(delivered, 1)
		expect.equal(state.bays[1].counts.Medium, 2)
		expect.equal(state.pendingOrders[order.orderId], nil)
		expect.equal(Receiving.usedCount(state), 1)
		expect.truthy(BusinessState.validate(state))
	end)

	t.test("a bay frees when its last tree leaves", function()
		local state = richState()
		local _, order = BusinessState.placeOrder(state, "bay_free_1", "DouglasFir", "Medium", 2, 100)
		BusinessState.reconcileDeliveries(state, state.pendingOrders[order.orderId].dueAt)
		expect.truthy(Receiving.take(state, 1, "Medium", 2))
		Receiving.normalize(state)
		expect.equal(state.bays[1].speciesId, "")
		expect.equal(next(state.bays[1].counts), nil)
		expect.equal(Receiving.usedCount(state), 0)
		expect.truthy(BusinessState.validate(state))
	end)

	t.test("validates the bay shape", function()
		local short = BusinessState.new("personal:42", 42)
		table.remove(short.bays)
		expect.falsy(BusinessState.validate(short))
		local long = BusinessState.new("personal:42", 42)
		table.insert(long.bays, { speciesId = "", counts = {} })
		expect.falsy(BusinessState.validate(long))
		local unknown = BusinessState.new("personal:42", 42)
		unknown.bays[1] = { speciesId = "Pine", counts = { Small = 1 } }
		expect.falsy(BusinessState.validate(unknown))
		local zero = BusinessState.new("personal:42", 42)
		zero.bays[1] = { speciesId = "DouglasFir", counts = { Small = 0 } }
		expect.falsy(BusinessState.validate(zero))
		local badKey = BusinessState.new("personal:42", 42)
		badKey.bays[1] = { speciesId = "DouglasFir", counts = { Huge = 1 } }
		expect.falsy(BusinessState.validate(badKey))
		local emptyWithCounts = BusinessState.new("personal:42", 42)
		emptyWithCounts.bays[1] = { speciesId = "", counts = { Small = 1 } }
		expect.falsy(BusinessState.validate(emptyWithCounts))
		local good = BusinessState.new("personal:42", 42)
		good.bays[1] = { speciesId = "DouglasFir", counts = { Small = 12 } }
		expect.truthy(BusinessState.validate(good))
	end)
end

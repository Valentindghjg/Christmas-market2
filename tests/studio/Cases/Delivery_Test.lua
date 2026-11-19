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
end

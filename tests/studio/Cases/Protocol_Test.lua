--!strict
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local Protocol = require(Shared:WaitForChild("Protocol"))
	local expect = t.expect

	-- Server accepts only a bounded, typed supplier request.
	t.test("validates supplier order shape", function()
		local ok = Protocol.validateRequest({
			version = 1,
			requestId = "order_1234",
			action = Protocol.Actions.SupplierPlaceOrder,
			payload = { speciesId = "FrasierFir", sizeId = "Medium", quantity = 2 },
		})
		expect.truthy(ok)
	end)

	-- A caller cannot inject a wholesale price into a request.
	t.test("rejects fabricated client price", function()
		local ok, reason = Protocol.validateRequest({
			version = 1,
			requestId = "order_5678",
			action = Protocol.Actions.SupplierPlaceOrder,
			payload = { speciesId = "FrasierFir", sizeId = "Medium", quantity = 2, unitCost = 0 },
		})
		expect.falsy(ok)
		expect.equal(reason, "UnexpectedField")
	end)

	-- The same request ID cannot open a second financial mutation.
	t.test("deduplicates request IDs", function()
		local state = BusinessState.new("personal:42", 42)
		local first = Protocol.beginRequest(state, "order_9999", Protocol.Actions.SupplierPlaceOrder, 100)
		local second, previous = Protocol.beginRequest(state, "order_9999", Protocol.Actions.SupplierPlaceOrder, 101)
		expect.truthy(first)
		expect.falsy(second)
		expect.equal(previous.requestId, "order_9999")
	end)

	-- Floods are limited per player and action.
	t.test("rate limits repeated actions", function()
		local limiter = Protocol.newRateLimiter(2, 10)
		expect.truthy(Protocol.allowRequest(limiter, 42, "Supplier.PlaceOrder", 100))
		expect.truthy(Protocol.allowRequest(limiter, 42, "Supplier.PlaceOrder", 101))
		expect.falsy(Protocol.allowRequest(limiter, 42, "Supplier.PlaceOrder", 102))
	end)
end

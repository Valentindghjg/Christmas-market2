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

	t.test("forgets a departed player's rate-limit buckets", function()
		local limiter = Protocol.newRateLimiter(1, 10)
		expect.truthy(Protocol.allowRequest(limiter, 42, "Supplier.PlaceOrder", 100))
		expect.truthy(Protocol.allowRequest(limiter, 420, "Supplier.PlaceOrder", 100))
		Protocol.forgetUser(limiter, 42)
		expect.truthy(Protocol.allowRequest(limiter, 42, "Supplier.PlaceOrder", 101))
		expect.falsy(Protocol.allowRequest(limiter, 420, "Supplier.PlaceOrder", 101))
	end)

	-- Extra transform keys could otherwise reach the saved record or carry non-serializable values.
	t.test("rejects placement transforms with extra or non-finite fields", function()
		local function place(transform)
			return Protocol.validateRequest({
				version = 1,
				requestId = "place_1234",
				action = Protocol.Actions.InventoryPlace,
				payload = { speciesId = "FrasierFir", sizeId = "Medium", transform = transform },
			})
		end
		expect.truthy(place({ x = 0, y = 0, z = 0, rotation = 0 }))
		expect.falsy(place({ x = 0, y = 0, z = 0, rotation = 0, junk = "x" }))
		expect.falsy(place({ x = 0 / 0, y = 0, z = 0, rotation = 0 }))
		expect.falsy(place({ x = 0, y = 0, z = 0 }))
	end)

	t.test("rejects unknown quest IDs before they reach the company lock", function()
		local ok, reason = Protocol.validateRequest({
			version = 1,
			requestId = "quest_1234",
			action = Protocol.Actions.QuestClaim,
			payload = { questId = "FreeMoney" },
		})
		expect.falsy(ok)
		expect.equal(reason, "InvalidQuest")
	end)
	-- G1/G5 actions accept only bounded integers and known items.
	t.test("validates order carry, load and sell-back payloads", function()
		local function check(action, payload)
			return Protocol.validateRequest({
				version = 1,
				requestId = "g1_request",
				action = action,
				payload = payload,
			})
		end
		expect.truthy(check(Protocol.Actions.OrderCarry, { orderNumber = 3 }))
		expect.truthy(check(Protocol.Actions.OrderLoad, { orderNumber = 3, carNumber = 3 }))
		expect.truthy(check(Protocol.Actions.OrderRelease, { orderNumber = 3 }))
		local _, fractional = check(Protocol.Actions.OrderCarry, { orderNumber = 1.5 })
		expect.equal(fractional, "InvalidOrderNumber")
		local _, missingCar = check(Protocol.Actions.OrderLoad, { orderNumber = 3 })
		expect.equal(missingCar, "InvalidOrderNumber")
		local _, injected = check(Protocol.Actions.OrderLoad, { orderNumber = 3, carNumber = 3, reputation = 99 })
		expect.equal(injected, "UnexpectedField")
		expect.truthy(
			check(Protocol.Actions.SupplierSellBack, { speciesId = "NobleFir", sizeId = "Small", quantity = 2 })
		)
		local _, refund = check(
			Protocol.Actions.SupplierSellBack,
			{ speciesId = "NobleFir", sizeId = "Small", quantity = 2, refund = 1000 }
		)
		expect.equal(refund, "UnexpectedField")
		local _, zero =
			check(Protocol.Actions.SupplierSellBack, { speciesId = "NobleFir", sizeId = "Small", quantity = 0 })
		expect.equal(zero, "InvalidQuantity")
	end)
end

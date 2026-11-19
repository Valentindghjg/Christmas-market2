--!strict
return function(t)
	local Protocol = require(game:GetService("ReplicatedStorage").Shared.Protocol)
	local expect = t.expect

	t.test("accepts typed price action", function()
		local ok = Protocol.validateRequest({
			version = 1,
			requestId = "price_1234",
			action = Protocol.Actions.PricingSetMediumPrice,
			payload = { speciesId = "FrasierFir", mediumPrice = 100 },
		})
		expect.truthy(ok)
	end)

	t.test("rejects price action with unexpected client fields", function()
		local ok, reason = Protocol.validateRequest({
			version = 1,
			requestId = "price_5678",
			action = Protocol.Actions.PricingSetMediumPrice,
			payload = { speciesId = "FrasierFir", mediumPrice = 100, cash = 999999 },
		})
		expect.falsy(ok)
		expect.equal(reason, "UnexpectedField")
	end)
end

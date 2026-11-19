--!strict
return function(t)
	local Protocol = require(game:GetService("ReplicatedStorage").Shared.Protocol)
	local expect = t.expect

	t.test("accepts the payload-free summary query", function()
		expect.truthy(Protocol.validateRequest({
			version = 1,
			requestId = "summary_1",
			action = Protocol.Actions.CompanyGetSummary,
			payload = {},
		}))
	end)

	t.test("rejects client state fields on summary query", function()
		local ok, reason = Protocol.validateRequest({
			version = 1,
			requestId = "summary_2",
			action = Protocol.Actions.CompanyGetSummary,
			payload = { cash = 999999 },
		})
		expect.falsy(ok)
		expect.equal(reason, "UnexpectedField")
	end)
end

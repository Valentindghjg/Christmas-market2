--!strict
return function(t)
	local Protocol = require(game:GetService("ReplicatedStorage").Shared.Protocol)
	local expect = t.expect

	t.test("accepts payload-free lot expansion", function()
		expect.truthy(Protocol.validateRequest({
			version = 1,
			requestId = "lot_12345",
			action = Protocol.Actions.ProgressionBuyLotExpansion,
			payload = {},
		}))
	end)

	t.test("only accepts configured HQ ids", function()
		expect.falsy(Protocol.validateRequest({
			version = 1,
			requestId = "hq_12345",
			action = Protocol.Actions.ProgressionBuyHQ,
			payload = { hqId = "FreeMoney" },
		}))
	end)
end

--!strict
return function(t)
	local Protocol = require(game:GetService("ReplicatedStorage").Shared.Protocol)
	local expect = t.expect

	local function validate(action: string, payload)
		return Protocol.validateRequest({ version = 1, requestId = "progress_1234", action = action, payload = payload })
	end

	-- CM2-G9a: a lot expansion names its target level.
	t.test("accepts a lot expansion with its target level", function()
		expect.truthy(validate(Protocol.Actions.ProgressionBuyLotExpansion, { level = 1 }))
		local ok, reason = validate(Protocol.Actions.ProgressionBuyLotExpansion, {})
		expect.falsy(ok)
		expect.equal(reason, "UnexpectedField")
	end)

	t.test("only accepts configured HQ ids", function()
		local ok, reason = validate(Protocol.Actions.ProgressionBuyHQ, { level = 5 })
		expect.falsy(ok)
		expect.equal(reason, "InvalidHQ")
		expect.falsy(validate(Protocol.Actions.ProgressionBuyHQ, { hqId = "FreeMoney" }))
		expect.truthy(validate(Protocol.Actions.ProgressionBuyHQ, { level = 2 }))
	end)

	t.test("accepts only target payloads", function()
		expect.truthy(validate(Protocol.Actions.ProgressionBuyParking, { tier = 2 }))
		local tierOk, tierReason = validate(Protocol.Actions.ProgressionBuyParking, { tier = 1 })
		expect.falsy(tierOk)
		expect.equal(tierReason, "InvalidTier")
		local levelOk, levelReason = validate(Protocol.Actions.ProgressionBuyLotExpansion, { level = 7 })
		expect.falsy(levelOk)
		expect.equal(levelReason, "InvalidLevel")
		local extraOk, extraReason = validate(Protocol.Actions.ProgressionBuyLotExpansion, { level = 1, extra = 1 })
		expect.falsy(extraOk)
		expect.equal(extraReason, "UnexpectedField")
	end)
end

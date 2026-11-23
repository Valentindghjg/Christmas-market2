--!strict
return function(t)
	local Protocol = require(game:GetService("ReplicatedStorage").Shared.Protocol)
	local expect = t.expect

	t.test("accepts known employee hire action", function()
		local ok = Protocol.validateRequest({
			version = 1,
			requestId = "hire_1234",
			action = Protocol.Actions.EmployeeHire,
			payload = { employeeId = "Cashier" },
		})
		expect.truthy(ok)
	end)

	-- CM2-25/26 part b: the Lot Manager passes the protocol; the server refuses it while locked.
	t.test("accepts the Lot Manager id", function()
		local ok = Protocol.validateRequest({
			version = 1,
			requestId = "hire_lotmanager_1",
			action = Protocol.Actions.EmployeeHire,
			payload = { employeeId = "LotManager" },
		})
		expect.truthy(ok)
	end)

	t.test("rejects unknown employee", function()
		local ok, reason = Protocol.validateRequest({
			version = 1,
			requestId = "hire_5678",
			action = Protocol.Actions.EmployeeHire,
			payload = { employeeId = "Admin" },
		})
		expect.falsy(ok)
		expect.equal(reason, "UnknownEmployee")
	end)
end

--!strict
return function(t)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local BusinessState = require(Shared.BusinessState)
	local EmployeeService = require(game:GetService("ServerScriptService").Server.Services.EmployeeService)
	local expect = t.expect

	t.test("charges one-time cashier hire once", function()
		local state = BusinessState.new("personal:42", 42)
		state.cash = 1200
		expect.truthy(EmployeeService.hire(state, "Cashier"))
		expect.equal(state.cash, 0)
		expect.equal(state.staff.Cashier, 1)
		expect.falsy(EmployeeService.hire(state, "Cashier"))
	end)
end

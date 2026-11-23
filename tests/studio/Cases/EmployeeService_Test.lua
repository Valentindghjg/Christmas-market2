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

	-- CM2-25/26 part b: the Lot Manager needs HQ 4, which CM2-G9 adds.
	t.test("the Lot Manager stays locked until HQ 4", function()
		local state = BusinessState.new("personal:42", 42)
		state.cash = 2000000
		local ok, code = EmployeeService.hire(state, "LotManager")
		expect.falsy(ok)
		expect.equal(code, "EmployeeLocked")
		expect.equal(state.cash, 2000000)
		expect.equal(state.staff.LotManager, 0)
	end)

	t.test("hiring respects the employee capacity", function()
		local state = BusinessState.new("personal:42", 42)
		expect.equal(EmployeeService.capacity(state), 2)
		state.progression.hqTier = "ChristmasPavilion"
		expect.equal(EmployeeService.capacity(state), 3)
		state.progression.hqTier = nil
		expect.equal(EmployeeService.hiredCount(state), 0)
		state.staff.Cashier = 1
		state.staff.LotManager = 1
		expect.equal(EmployeeService.hiredCount(state), 2)
		state.cash = 5000
		local ok, code = EmployeeService.hire(state, "LotWorker")
		expect.falsy(ok)
		expect.equal(code, "EmployeeCapacity")
		expect.equal(state.cash, 5000)
		expect.equal(state.staff.LotWorker, 0)
		state.staff.LotWorker = 1
		expect.equal(EmployeeService.hiredCount(state), 3)
	end)

	t.test("hiring rests the new employee", function()
		local state = BusinessState.new("personal:42", 42)
		state.cash = 1800
		state.staffEnergy.LotWorker = 30
		expect.truthy(EmployeeService.hire(state, "LotWorker"))
		expect.equal(state.staffEnergy.LotWorker, 100)
		expect.equal(state.cash, 0)
	end)
end

--!strict
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local AnalyticsService = require(game:GetService("ServerScriptService").Server.Services.AnalyticsService)
	local expect = t.expect

	t.test("returns bounded aggregate sales metrics", function()
		local state = BusinessState.new("personal:42", 42)
		state.customerVisits = 4
		state.abandonedCustomers = 3
		state.walkedOutCustomers = 2
		state.sales = 1
		state.revenue = 66
		local summary = AnalyticsService.summary(state)
		expect.equal(summary.conversionRate, 0.25)
		expect.equal(summary.averageSale, 66)
		expect.equal(summary.abandonedCustomers, 3)
		expect.equal(summary.walkedOutCustomers, 2)
	end)
end

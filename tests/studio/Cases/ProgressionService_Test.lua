--!strict
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local ProgressionService = require(game:GetService("ServerScriptService").Server.Services.ProgressionService)
	local expect = t.expect

	t.test("enforces lot expansion reputation before charging", function()
		local state = BusinessState.new("personal:42", 42)
		state.reputation = 49
		local cash = state.cash
		expect.falsy(ProgressionService.buyLotExpansion(state))
		expect.equal(state.cash, cash)
		state.reputation = 50
		state.cash = 1000
		expect.truthy(ProgressionService.buyLotExpansion(state))
		expect.equal(state.progression.lotExpansion, 1)
		expect.equal(state.cash, 250)
	end)

	t.test("requires all pavilion prerequisites", function()
		local state = BusinessState.new("personal:42", 42)
		state.cash = 5000
		state.reputation = 250
		expect.falsy(ProgressionService.buyHQ(state, "ChristmasPavilion"))
		state.progression.lotExpansion = 1
		state.progression.parkingSpaces = 4
		expect.truthy(ProgressionService.buyHQ(state, "ChristmasPavilion"))
		expect.equal(state.progression.hqTier, "ChristmasPavilion")
		expect.equal(state.cash, 2500)
	end)
end

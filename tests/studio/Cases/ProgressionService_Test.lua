--!strict
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local ProgressionService = require(game:GetService("ServerScriptService").Server.Services.ProgressionService)
	local expect = t.expect

	-- CM2-G9a: the Back Lot (OBSERVED $1,200, +10 storage) needs no reputation.
	t.test("the Back Lot costs its cash once and needs no reputation", function()
		local state = BusinessState.new("personal:42", 42)
		state.reputation = 0
		state.cash = 1199
		local refused, code = ProgressionService.buyLotExpansion(state, 1)
		expect.falsy(refused)
		expect.equal(code, "InsufficientFunds")
		expect.equal(state.cash, 1199)
		expect.equal(state.progression.lotExpansion, 0)
		state.cash = 1200
		local ok, level = ProgressionService.buyLotExpansion(state, 1)
		expect.truthy(ok)
		expect.equal(level, 1)
		expect.equal(state.progression.lotExpansion, 1)
		expect.equal(state.cash, 0)
		expect.equal(BusinessState.storageCapacity(state), 40)
	end)

	t.test("requires all pavilion prerequisites", function()
		local state = BusinessState.new("personal:42", 42)
		state.cash = 5000
		state.reputation = 250
		local refused, code = ProgressionService.buyHQ(state, 2)
		expect.falsy(refused)
		expect.equal(code, "PrerequisitesNotMet")
		expect.equal(state.cash, 5000)
		state.progression.lotExpansion = 1
		expect.falsy(ProgressionService.buyHQ(state, 2))
		expect.equal(state.cash, 5000)
		state.progression.parkingTier = 2
		expect.truthy(ProgressionService.buyHQ(state, 2))
		expect.equal(state.progression.hqLevel, 2)
		expect.equal(state.cash, 2500)
	end)
end

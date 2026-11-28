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

	-- CM2-PARK (owner decided 2026-11-28): tiers 2, 3, 4 for $400, $1,200, $4,200, one at a time.
	t.test("parking tiers cost $400, $1,200, $4,200 in order", function()
		local Progression = require(Shared:WaitForChild("Progression"))
		local state = BusinessState.new("personal:42", 42)
		state.cash = 1e6
		local skipped, skipCode = ProgressionService.buyParking(state, 3)
		expect.falsy(skipped)
		expect.equal(skipCode, "NotNextLevel")
		expect.equal(state.cash, 1e6)
		state.cash = 399
		local broke, brokeCode = ProgressionService.buyParking(state, 2)
		expect.falsy(broke)
		expect.equal(brokeCode, "InsufficientFunds")
		expect.equal(state.cash, 399)
		expect.equal(state.progression.parkingTier, 1)
		for _, step in { { 2, 400 }, { 3, 1200 }, { 4, 4200 } } do
			local tier, cost = step[1], step[2]
			state.cash = cost
			local ok, bought = ProgressionService.buyParking(state, tier)
			expect.truthy(ok)
			expect.equal(bought, tier)
			expect.equal(state.cash, 0)
			expect.equal(Progression.parkingSpaces(state), tier)
		end
		state.cash = 1e6
		local again, againCode = ProgressionService.buyParking(state, 4)
		expect.falsy(again)
		expect.equal(againCode, "AlreadyOwned")
		local beyond, beyondCode = ProgressionService.buyParking(state, 5)
		expect.falsy(beyond)
		expect.equal(beyondCode, "InvalidLevel")
		expect.equal(state.cash, 1e6)
	end)
end

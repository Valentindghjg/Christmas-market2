--!strict
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local PricingService = require(game:GetService("ServerScriptService").Server.Services.PricingService)
	local expect = t.expect

	t.test("accepts bounded manual price and disables auto pricing", function()
		local state = BusinessState.new("personal:42", 42)
		state.autoPricing = true
		expect.truthy(PricingService.setMediumPrice(state, "FrasierFir", 100))
		expect.equal(state.mediumPrices.FrasierFir, 100)
		expect.falsy(state.autoPricing)
	end)

	t.test("rejects price outside server bounds", function()
		local state = BusinessState.new("personal:42", 42)
		expect.falsy(PricingService.setMediumPrice(state, "FrasierFir", 9999))
		expect.equal(state.mediumPrices.FrasierFir, 82)
	end)
end

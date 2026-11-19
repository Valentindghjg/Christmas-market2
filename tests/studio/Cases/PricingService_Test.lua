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

	t.test("auto pricing discounts only with displayed stock", function()
		local state = BusinessState.new("personal:42", 42)
		state.layout.placements["fir_1"] = { speciesId = "FrasierFir", sizeId = "Medium" }
		state.layout.placements["fir_2"] = { speciesId = "FrasierFir", sizeId = "Medium" }
		expect.truthy(PricingService.setAutomatic(state, true))
		local ok, updated = PricingService.applyAutomatic(state)
		expect.truthy(ok)
		expect.equal(updated.FrasierFir, 75)
		expect.equal(updated.NobleFir, 92)
	end)

	t.test("does not alter locked reservation price", function()
		local state = BusinessState.new("personal:42", 42)
		state.layout.placements["fir_reserved"] = { speciesId = "FrasierFir", sizeId = "Medium" }
		state.reservations.fir_reserved = { customerId = "customer:1", expiresAt = 200, salePrice = 82 }
		expect.truthy(PricingService.setAutomatic(state, true))
		expect.truthy(PricingService.applyAutomatic(state))
		expect.equal(state.reservations.fir_reserved.salePrice, 82)
	end)
end

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
		expect.equal(state.mediumPrices.FrasierFir, 160)
	end)

	t.test("auto pricing discounts only with displayed stock", function()
		local state = BusinessState.new("personal:42", 42)
		state.layout.placements["fir_1"] = { speciesId = "FrasierFir", sizeId = "Medium" }
		state.layout.placements["fir_2"] = { speciesId = "FrasierFir", sizeId = "Medium" }
		expect.truthy(PricingService.setAutomatic(state, true))
		local ok, updated = PricingService.applyAutomatic(state)
		expect.truthy(ok)
		expect.equal(updated.FrasierFir, 150)
		expect.equal(updated.NobleFir, nil)
		expect.equal(state.mediumPrices.NobleFir, 184)
	end)

	-- An idle scheduler tick reports no change, so it does not trigger a save.
	t.test("auto pricing reports only changed species", function()
		local state = BusinessState.new("personal:42", 42)
		expect.truthy(PricingService.setAutomatic(state, true))
		expect.truthy(PricingService.applyAutomatic(state))
		local ok, updated = PricingService.applyAutomatic(state)
		expect.truthy(ok)
		expect.equal(next(updated), nil)
	end)

	t.test("does not alter locked reservation price", function()
		local state = BusinessState.new("personal:42", 42)
		state.layout.placements["fir_reserved"] = { speciesId = "FrasierFir", sizeId = "Medium" }
		state.reservations.fir_reserved = { customerId = "customer:1", expiresAt = 200, salePrice = 82 }
		expect.truthy(PricingService.setAutomatic(state, true))
		expect.truthy(PricingService.applyAutomatic(state))
		expect.equal(state.reservations.fir_reserved.salePrice, 82)
	end)

	-- CM2-G7: bounds are 50-250 % of the benchmark (typical = 5 x medium wholesale).
	t.test("bounds follow the benchmark", function()
		local function expectBounds(speciesId: string, minimum: number, maximum: number)
			local low, high = PricingService.bounds(speciesId)
			expect.equal(low, minimum)
			expect.equal(high, maximum)
		end
		expectBounds("DouglasFir", 70, 350)
		expectBounds("FrasierFir", 80, 400)
		expectBounds("NobleFir", 92, 460)
		expectBounds("BlueSpruce", 105, 525)
		expect.equal(PricingService.bounds("Pine"), nil)
		local state = BusinessState.new("personal:42", 42)
		local ok, errorCode = PricingService.setMediumPrice(state, "DouglasFir", 69)
		expect.equal(ok, false)
		expect.equal(errorCode, "InvalidPrice")
		ok, errorCode = PricingService.setMediumPrice(state, "DouglasFir", 351)
		expect.equal(ok, false)
		expect.equal(errorCode, "InvalidPrice")
		expect.truthy(PricingService.setMediumPrice(state, "DouglasFir", 70))
		expect.equal(state.mediumPrices.DouglasFir, 70)
		expect.truthy(PricingService.setMediumPrice(state, "DouglasFir", 350))
		expect.equal(state.mediumPrices.DouglasFir, 350)
		local nobleState = BusinessState.new("personal:42", 42)
		ok, errorCode = PricingService.setMediumPrice(nobleState, "NobleFir", 91)
		expect.equal(ok, false)
		expect.equal(errorCode, "InvalidPrice")
		ok, errorCode = PricingService.setMediumPrice(nobleState, "NobleFir", 461)
		expect.equal(ok, false)
		expect.equal(errorCode, "InvalidPrice")
		expect.truthy(PricingService.setMediumPrice(nobleState, "NobleFir", 92))
		expect.equal(nobleState.mediumPrices.NobleFir, 92)
		expect.truthy(PricingService.setMediumPrice(nobleState, "NobleFir", 460))
		expect.equal(nobleState.mediumPrices.NobleFir, 460)
	end)

	t.test("names the price sentiment by the benchmark", function()
		expect.equal(PricingService.sentiment(119, 140), "Bargain")
		expect.equal(PricingService.sentiment(120, 140), "Fair")
		expect.equal(PricingService.sentiment(154, 140), "Fair")
		expect.equal(PricingService.sentiment(155, 140), "Pricey")
		expect.equal(PricingService.sentiment(182, 140), "Pricey")
		expect.equal(PricingService.sentiment(183, 140), "TooHigh")
	end)

	-- The four reference cards (REFERENCE_GAME_LIVE_TEST §4.3) at 146/164/192/210.
	t.test("summary reports server prices, margins and sentiment", function()
		local state = BusinessState.new("personal:42", 42)
		state.mediumPrices.DouglasFir = 146
		state.mediumPrices.FrasierFir = 164
		state.mediumPrices.NobleFir = 192
		state.mediumPrices.BlueSpruce = 210
		local summary = PricingService.summary(state)
		expect.equal(summary.automatic, false)
		expect.equal(#summary.species, 4)
		local expected = {
			{ "DouglasFir", 146, 140, 118, 81, 117, 96, 190, 149 },
			{ "FrasierFir", 164, 160, 132, 80, 131, 107, 213, 167 },
			{ "NobleFir", 192, 184, 155, 81, 154, 126, 250, 196 },
			{ "BlueSpruce", 210, 210, 168, 80, 168, 136, 273, 212 },
		}
		for index, row in ipairs(expected) do
			local entry = summary.species[index]
			expect.equal(entry.speciesId, row[1])
			expect.equal(entry.mediumPrice, row[2])
			expect.equal(entry.typicalMedium, row[3])
			expect.equal(entry.marginMedium, row[4])
			expect.equal(entry.marginPercent, row[5])
			expect.equal(entry.sentiment, "Fair")
			expect.equal(#entry.sizes, 3)
			expect.equal(entry.sizes[1].sizeId, "Small")
			expect.equal(entry.sizes[1].price, row[6])
			expect.equal(entry.sizes[1].profit, row[7])
			expect.equal(entry.sizes[2].sizeId, "Medium")
			expect.equal(entry.sizes[2].price, row[2])
			expect.equal(entry.sizes[2].profit, row[4])
			expect.equal(entry.sizes[3].sizeId, "Large")
			expect.equal(entry.sizes[3].price, row[8])
			expect.equal(entry.sizes[3].profit, row[9])
		end
		expect.equal(summary.species[1].wholesaleMedium, 28)
		expect.equal(summary.species[1].minPrice, 70)
		expect.equal(summary.species[1].maxPrice, 350)
	end)
end

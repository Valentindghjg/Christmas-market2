--!strict
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local CustomerProfile = require(Shared:WaitForChild("CustomerProfile"))
	local CustomerSelection = require(Shared:WaitForChild("CustomerSelection"))
	local expect = t.expect

	t.test("chooses compatible unreserved display tree", function()
		local state = BusinessState.new("personal:42", 42)
		state.layout.placements.available = { speciesId = "FrasierFir", sizeId = "Small" }
		state.layout.placements.reserved = { speciesId = "FrasierFir", sizeId = "Small" }
		state.reservations.reserved = { customerId = "npc:99", expiresAt = 200, salePrice = 66 }
		local candidate = CustomerSelection.choose(state, CustomerProfile.create(1))
		expect.equal(candidate.placementId, "available")
		expect.equal(candidate.salePrice, 128)
		expect.truthy(candidate.conversionScore > 0)
	end)

	-- Demand is needed by the CM2-SALE2 cases below.
	local Demand = require(Shared:WaitForChild("Demand"))

	t.test("accepts a non-preferred tree within budget and rejects over-budget stock (CM2-SALE2)", function()
		local state = BusinessState.new("personal:42", 42)
		state.layout.placements.noble = { speciesId = "NobleFir", sizeId = "Small" }
		local candidate = CustomerSelection.choose(state, CustomerProfile.create(1))
		expect.truthy(candidate)
		expect.equal(candidate.placementId, "noble")
		expect.equal(candidate.salePrice, 147)
		expect.truthy(math.abs(candidate.conversionScore - Demand.score(1, 90, 1, 0.85, 0.68, 0.75)) < 1e-9)
		state.mediumPrices.NobleFir = 200
		expect.equal(CustomerSelection.choose(state, CustomerProfile.create(1)), nil)
	end)

	t.test("picks the best-scoring tree, not the first sorted one (CM2-SALE2)", function()
		local state = BusinessState.new("personal:42", 42)
		state.layout.placements.a = { speciesId = "FrasierFir", sizeId = "Large" }
		state.layout.placements.b = { speciesId = "DouglasFir", sizeId = "Medium" }
		local candidate = CustomerSelection.choose(state, CustomerProfile.create(8))
		expect.truthy(candidate)
		expect.equal(candidate.placementId, "b")
		expect.equal(candidate.salePrice, 140)
		expect.truthy(math.abs(candidate.conversionScore - Demand.score(1, 90, 1, 0.925, 0.76, 1)) < 1e-9)
	end)

	-- CM2-G7: the price ratio is the sale price over the benchmark of the tree's size.
	local function douglasState(mediumPrice: number, sizeId: string)
		local state = BusinessState.new("personal:42", 42)
		state.mediumPrices.DouglasFir = mediumPrice
		for index = 1, 5 do
			state.layout.placements["douglas_" .. index] = { speciesId = "DouglasFir", sizeId = sizeId }
		end
		return state
	end

	t.test("uses the sale price over the size benchmark", function()
		local candidate = CustomerSelection.choose(douglasState(154, "Large"), CustomerProfile.create(12))
		expect.truthy(candidate)
		expect.equal(candidate.salePrice, 200)
		expect.truthy(math.abs(candidate.conversionScore - Demand.score(200 / 182, 90, 1, 0.85, 1, 1)) < 1e-9)
	end)

	t.test("scores the benchmark equally for every size and lower above it", function()
		local medium = CustomerSelection.choose(douglasState(140, "Medium"), CustomerProfile.create(8))
		local large = CustomerSelection.choose(douglasState(140, "Large"), CustomerProfile.create(12))
		expect.truthy(medium)
		expect.truthy(large)
		expect.equal(medium.conversionScore, large.conversionScore)
		local pricey = CustomerSelection.choose(douglasState(182, "Medium"), CustomerProfile.create(8))
		expect.truthy(pricey)
		expect.truthy(pricey.conversionScore < medium.conversionScore)
	end)

	-- CM2-46a: Evergreen VIP customers judge the price against their budget with 15 % tolerance.
	t.test("lets VIP customers pay up to 15% more", function()
		local profile = CustomerProfile.create(8)
		local price = profile.budget + 1
		local state = douglasState(price, "Medium")
		expect.equal(CustomerSelection.choose(state, profile), nil)
		local candidate = CustomerSelection.choose(state, profile, 1.15)
		expect.truthy(candidate)
		expect.equal(candidate.salePrice, price)
		local tooDear = douglasState(math.ceil(profile.budget * 1.15) + 1, "Medium")
		expect.equal(CustomerSelection.choose(tooDear, profile, 1.15), nil)
	end)

	-- CM2-SALE1: the tutorial customer takes the first unreserved tree without preference checks.
	t.test("chooseGuaranteed takes the first unreserved priced tree (CM2-SALE1)", function()
		local state = BusinessState.new("personal:42", 42)
		state.layout.placements.a = { speciesId = "NobleFir", sizeId = "Small" }
		state.layout.placements.b = { speciesId = "NobleFir", sizeId = "Small" }
		state.layout.placements.c = { speciesId = "DouglasFir", sizeId = "Medium" }
		state.reservations.a = { customerId = "npc:99", expiresAt = 200, salePrice = 1 }
		local candidate = CustomerSelection.chooseGuaranteed(state)
		expect.truthy(candidate)
		expect.equal(candidate.placementId, "b")
		expect.equal(candidate.salePrice, 147)
		expect.equal(candidate.conversionScore, 1)
		-- profile 5's budget (99 %) is below 147 and 140, so the soft preference finds nothing.
		expect.equal(CustomerSelection.choose(state, CustomerProfile.create(5)), nil)
		state.reservations.b = { customerId = "npc:99", expiresAt = 200, salePrice = 1 }
		state.reservations.c = { customerId = "npc:99", expiresAt = 200, salePrice = 1 }
		expect.equal(CustomerSelection.chooseGuaranteed(state), nil)
	end)
end

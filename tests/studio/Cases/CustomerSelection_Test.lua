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

	t.test("rejects nonmatching or over-budget stock", function()
		local state = BusinessState.new("personal:42", 42)
		state.layout.placements.noble = { speciesId = "NobleFir", sizeId = "Small" }
		expect.equal(CustomerSelection.choose(state, CustomerProfile.create(1)), nil)
	end)

	-- CM2-G7: the price ratio is the sale price over the benchmark of the tree's size.
	local Demand = require(Shared:WaitForChild("Demand"))

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
		expect.equal(candidate.conversionScore, Demand.score(200 / 182, 90, 1, 1 / 3, 1))
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
end

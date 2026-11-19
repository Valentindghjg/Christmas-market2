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
		expect.equal(candidate.salePrice, 66)
		expect.truthy(candidate.conversionScore > 0)
	end)

	t.test("rejects nonmatching or over-budget stock", function()
		local state = BusinessState.new("personal:42", 42)
		state.layout.placements.noble = { speciesId = "NobleFir", sizeId = "Small" }
		expect.equal(CustomerSelection.choose(state, CustomerProfile.create(1)), nil)
	end)
end

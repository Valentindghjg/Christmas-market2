--!strict
return function(t)
	local CustomerProfile = require(game:GetService("ReplicatedStorage").Shared.CustomerProfile)
	local expect = t.expect

	t.test("creates deterministic server customer preferences", function()
		local first = CustomerProfile.create(1)
		local repeatFirst = CustomerProfile.create(1)
		expect.equal(first.id, "npc:1")
		expect.equal(first.preferredSpeciesId, repeatFirst.preferredSpeciesId)
		expect.equal(first.budget, repeatFirst.budget)
		expect.truthy(first.patienceSeconds >= 12)
	end)

	t.test("requires preference and budget compatibility", function()
		local profile = CustomerProfile.create(1)
		expect.truthy(CustomerProfile.canPurchase(profile, { speciesId = "FrasierFir", sizeId = "Small" }, 65))
		expect.falsy(CustomerProfile.canPurchase(profile, { speciesId = "NobleFir", sizeId = "Small" }, 65))
		expect.falsy(CustomerProfile.canPurchase(profile, { speciesId = "FrasierFir", sizeId = "Small" }, 999))
	end)

	t.test("cycles customer preferences through all four starter species", function()
		local expected = { "FrasierFir", "NobleFir", "BlueSpruce", "DouglasFir" }
		for number, speciesId in ipairs(expected) do
			local profile = CustomerProfile.create(number)
			expect.equal(profile.preferredSpeciesId, speciesId)
			expect.equal(profile.preferredSizeId, "Small")
		end
		local five = CustomerProfile.create(5)
		expect.equal(five.preferredSpeciesId, "FrasierFir")
		expect.equal(five.preferredSizeId, "Medium")
		local eight = CustomerProfile.create(8)
		expect.equal(eight.preferredSpeciesId, "DouglasFir")
		expect.equal(eight.preferredSizeId, "Medium")
	end)
end

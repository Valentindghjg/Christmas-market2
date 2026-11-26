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

	t.test("requires budget compatibility for any known tree (CM2-SALE2)", function()
		local profile = CustomerProfile.create(1)
		expect.truthy(CustomerProfile.canPurchase(profile, { speciesId = "FrasierFir", sizeId = "Small" }, 65))
		expect.truthy(CustomerProfile.canPurchase(profile, { speciesId = "NobleFir", sizeId = "Small" }, 150))
		expect.falsy(CustomerProfile.canPurchase(profile, { speciesId = "NobleFir", sizeId = "Small" }, 151))
		expect.falsy(CustomerProfile.canPurchase(profile, { speciesId = "FrasierFir", sizeId = "Small" }, 999))
		expect.falsy(CustomerProfile.canPurchase(profile, { speciesId = "Pine", sizeId = "Small" }, 1))
	end)

	t.test("budgetFor scales the budget percent to any tree's benchmark (CM2-SALE2)", function()
		local p8 = CustomerProfile.create(8)
		expect.equal(p8.budgetPercent, 150)
		expect.equal(CustomerProfile.budgetFor(p8, "NobleFir", "Large"), 359)
		expect.equal(CustomerProfile.budgetFor(p8, "Pine", "Medium"), nil)
		expect.equal(CustomerProfile.budgetFor(nil, "DouglasFir", "Medium"), nil)
		expect.equal(CustomerProfile.create(5).budgetPercent, 99)
		for number = 1, 71 do
			local profile = CustomerProfile.create(number)
			expect.equal(
				CustomerProfile.budgetFor(profile, profile.preferredSpeciesId, profile.preferredSizeId),
				profile.budget
			)
		end
	end)

	t.test("interestIn grades species and size matches (CM2-SALE2)", function()
		local p8 = CustomerProfile.create(8)
		expect.equal(CustomerProfile.interestIn(p8, { speciesId = "DouglasFir", sizeId = "Medium" }), 1)
		expect.equal(CustomerProfile.interestIn(p8, { speciesId = "DouglasFir", sizeId = "Large" }), 0.85)
		expect.equal(CustomerProfile.interestIn(p8, { speciesId = "FrasierFir", sizeId = "Medium" }), 0.75)
		expect.equal(CustomerProfile.interestIn(p8, { speciesId = "FrasierFir", sizeId = "Large" }), 0.65)
		expect.equal(CustomerProfile.interestIn(p8, nil), 0)
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

	-- CM2-G7: budgets are 85-155 % of the benchmark of the preferred species and size.
	t.test("budgets follow the size benchmark", function()
		local Economy = require(game:GetService("ReplicatedStorage").Shared.Economy)
		expect.equal(CustomerProfile.create(1).budget, 131)
		expect.equal(CustomerProfile.create(8).budget, 210)
		expect.equal(CustomerProfile.create(12).budget, 268)
		for number = 1, 71 do
			local profile = CustomerProfile.create(number)
			local typical = Economy.typicalPrice(profile.preferredSpeciesId, profile.preferredSizeId) :: number
			expect.truthy(profile.budget >= math.floor(typical * 0.85))
			expect.truthy(profile.budget <= math.ceil(typical * 1.55))
		end
	end)
end

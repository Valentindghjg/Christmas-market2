--!strict
return function(t)
	local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameConfig"))
	local expect = t.expect

	t.test("contains the observed size price rule", function()
		expect.equal(GameConfig.VERSION, 1)
		expect.equal(GameConfig.SizeMultipliers.Small, 0.8)
		expect.equal(GameConfig.SizeMultipliers.Medium, 1)
		expect.equal(GameConfig.SizeMultipliers.Large, 1.3)
	end)

	t.test("marks observed trees and unlocks", function()
		expect.equal(GameConfig.Trees.FrasierFir.evidence, GameConfig.Evidence.Observed)
		expect.equal(GameConfig.HQ.ChristmasPavilion.evidence, GameConfig.Evidence.Observed)
		expect.equal(GameConfig.Employees.Cashier.maxCount, 1)
	end)

	t.test("lists the four starter species in the observed supplier order", function()
		expect.equal(#GameConfig.SpeciesOrder, 4)
		expect.equal(GameConfig.SpeciesOrder[1], "DouglasFir")
		expect.equal(GameConfig.SpeciesOrder[2], "FrasierFir")
		expect.equal(GameConfig.SpeciesOrder[3], "NobleFir")
		expect.equal(GameConfig.SpeciesOrder[4], "BlueSpruce")
		local treeCount = 0
		for _ in pairs(GameConfig.Trees) do
			treeCount += 1
		end
		expect.equal(treeCount, 4)
		for _, speciesId in ipairs(GameConfig.SpeciesOrder) do
			expect.truthy(GameConfig.Trees[speciesId])
		end
	end)

	t.test("holds the observed wholesale for every species and size", function()
		local expected = {
			DouglasFir = { Small = 21, Medium = 28, Large = 41 },
			FrasierFir = { Small = 24, Medium = 32, Large = 46 },
			NobleFir = { Small = 28, Medium = 37, Large = 54 },
			BlueSpruce = { Small = 32, Medium = 42, Large = 61 },
		}
		for _, speciesId in ipairs(GameConfig.SpeciesOrder) do
			for _, sizeId in ipairs(GameConfig.SizeIds) do
				expect.equal(GameConfig.wholesaleFor(speciesId, sizeId), expected[speciesId][sizeId])
			end
		end
	end)

	t.test("keeps the FrasierFir ID and shows the Fraser Fir spelling", function()
		expect.equal(GameConfig.Trees.FrasierFir.displayName, "Fraser Fir")
		expect.equal(GameConfig.Trees.DouglasFir.displayName, "Douglas Fir")
		expect.equal((GameConfig.Trees :: any).FraserFir, nil)
	end)

	t.test("marks rarity and evidence of the starter species", function()
		expect.equal(GameConfig.Trees.DouglasFir.rarity, "Common")
		expect.equal(GameConfig.Trees.FrasierFir.rarity, "Uncommon")
		expect.equal(GameConfig.Trees.NobleFir.rarity, "Rare")
		expect.equal(GameConfig.Trees.BlueSpruce.rarity, "Uncommon")
		for _, tree in pairs(GameConfig.Trees) do
			expect.equal(tree.evidence, GameConfig.Evidence.Observed)
		end
	end)

	t.test("gives every species complete integer pricing data", function()
		local function positiveInteger(value: unknown): boolean
			return type(value) == "number" and value == math.floor(value) and value > 0
		end
		for _, tree in pairs(GameConfig.Trees) do
			expect.truthy(positiveInteger(tree.wholesale.Small))
			expect.truthy(positiveInteger(tree.wholesale.Medium))
			expect.truthy(positiveInteger(tree.wholesale.Large))
			expect.truthy(tree.wholesale.Small < tree.wholesale.Medium)
			expect.truthy(tree.wholesale.Medium < tree.wholesale.Large)
			expect.truthy(positiveInteger(tree.typicalMedium))
			expect.truthy(positiveInteger(tree.initialMediumPrice))
			expect.equal(type(tree.displayName), "string")
			expect.truthy(#tree.displayName > 0)
		end
	end)
end

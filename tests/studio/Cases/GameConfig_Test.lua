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
		for speciesId, tree in pairs(GameConfig.Trees) do
			expect.truthy(positiveInteger(tree.wholesale.Small))
			expect.truthy(positiveInteger(tree.wholesale.Medium))
			expect.truthy(positiveInteger(tree.wholesale.Large))
			expect.truthy(tree.wholesale.Small < tree.wholesale.Medium)
			expect.truthy(tree.wholesale.Medium < tree.wholesale.Large)
			expect.truthy(positiveInteger(GameConfig.typicalMediumFor(speciesId)))
			expect.equal(type(tree.displayName), "string")
			expect.truthy(#tree.displayName > 0)
		end
	end)

	-- CM2-G7: the "typical" price is about 5 x medium wholesale (REFERENCE_GAME_LIVE_TEST §4.3).
	t.test("derives the typical price from wholesale x 5", function()
		local Pricing = GameConfig.Pricing
		expect.equal(Pricing.BenchmarkMultiplier, 5)
		expect.equal(GameConfig.typicalMediumFor("DouglasFir"), 140)
		expect.equal(GameConfig.typicalMediumFor("FrasierFir"), 160)
		expect.equal(GameConfig.typicalMediumFor("NobleFir"), 184)
		expect.equal(GameConfig.typicalMediumFor("BlueSpruce"), 210)
		expect.equal(GameConfig.typicalMediumFor("Pine"), nil)
		expect.equal(GameConfig.typicalMediumFor(5), nil)
		expect.equal(#Pricing.Steps, 4)
		expect.equal(Pricing.Steps[1], -5)
		expect.equal(Pricing.Steps[2], -1)
		expect.equal(Pricing.Steps[3], 1)
		expect.equal(Pricing.Steps[4], 5)
		expect.truthy(Pricing.SentimentPercent.Bargain == 85)
		expect.truthy(Pricing.SentimentPercent.Bargain < Pricing.SentimentPercent.Fair)
		expect.truthy(Pricing.SentimentPercent.Fair == 110)
		expect.truthy(Pricing.SentimentPercent.Fair < Pricing.SentimentPercent.Pricey)
		expect.truthy(Pricing.SentimentPercent.Pricey == 130)
		expect.equal(Pricing.BudgetPercent.Min, 85)
		expect.equal(Pricing.BudgetPercent.Max, 155)
	end)

	-- CM2-G7a: an OBSERVED typical card that differs from the 5 x rule overrides it (Noble 184).
	t.test("takes observed typical prices over the 5x rule", function()
		local Pricing = GameConfig.Pricing
		expect.equal(Pricing.TypicalMediumOverride.NobleFir, 184)
		local keyCount = 0
		for speciesId, value in pairs(Pricing.TypicalMediumOverride) do
			keyCount += 1
			expect.truthy(GameConfig.Trees[speciesId])
			expect.truthy(type(value) == "number" and value == math.floor(value) and value > 0)
		end
		expect.equal(keyCount, 1)
		local expected = { 140, 160, 184, 210 }
		for index, speciesId in ipairs(GameConfig.SpeciesOrder) do
			expect.equal(GameConfig.typicalMediumFor(speciesId), expected[index])
		end
		expect.equal(GameConfig.Trees.NobleFir.wholesale.Medium * Pricing.BenchmarkMultiplier, 185)
	end)

	-- CM2-R5: main's BindToClose waits SHUTDOWN_WAIT_SECONDS = 25.
	t.test("unload retries fit the fail-closed window and the shutdown budget", function()
		local sum = 0
		for _, delay in ipairs(GameConfig.UnloadRetry.DelaysSeconds) do
			expect.truthy(type(delay) == "number" and delay == math.floor(delay) and delay > 0)
			sum += delay
		end
		expect.equal(sum, 78)
		expect.truthy(sum <= GameConfig.SaveFailClosedSeconds)
		expect.equal(GameConfig.UnloadRetry.ShutdownSeconds, 18)
		expect.truthy(GameConfig.UnloadRetry.ShutdownSeconds + 5 <= 25)
	end)
end

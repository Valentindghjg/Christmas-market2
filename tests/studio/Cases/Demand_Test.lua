--!strict
return function(t)
	local Demand = require(game:GetService("ReplicatedStorage").Shared.Demand)
	local expect = t.expect

	-- Raising price lowers conversion when every other factor is unchanged.
	t.test("penalizes higher price", function()
		local affordable = Demand.score(1, 90, 1, 1, 1)
		local expensive = Demand.score(2, 90, 1, 1, 1)
		expect.truthy(affordable > expensive)
	end)

	-- Score stays bounded for unusual but valid inputs.
	t.test("clamps conversion score", function()
		expect.equal(Demand.score(0.01, 100000, 100, 100, 100), 0.95)
		expect.equal(Demand.score(100, 0, 0, 0, 0), 0.02)
	end)

	-- CM2-G7: a sale at the benchmark (price ratio 1) keeps the price factor at 0.65.
	t.test("scores the benchmark price at 0.65", function()
		expect.truthy(math.abs(Demand.score(1, 500, 1, 1, 1) - 0.65) < 1e-9)
	end)

	-- CM2-SALE2: interest (baseSpeciesInterest) scales the score and defaults to 1.
	t.test("interest scales the score and defaults to 1 (CM2-SALE2)", function()
		expect.truthy(math.abs(Demand.score(1, 500, 1, 1, 1, 0.5) - 0.325) < 1e-9)
		expect.equal(Demand.score(1, 500, 1, 1, 1), Demand.score(1, 500, 1, 1, 1, 1))
		expect.equal(Demand.score(1, 90, 1, 1, 1, 0), 0.02)
	end)
end

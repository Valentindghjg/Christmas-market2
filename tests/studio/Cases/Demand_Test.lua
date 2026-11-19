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
end

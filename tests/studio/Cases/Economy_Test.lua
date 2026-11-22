--!strict
return function(t)
	local Economy = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Economy"))
	local expect = t.expect
	-- Uses the observed size rule with round-half-up results.
	t.test("prices observed size tiers", function()
		expect.equal(Economy.priceForSize(82, "Small"), 66)
		expect.equal(Economy.priceForSize(82, "Medium"), 82)
		expect.equal(Economy.priceForSize(82, "Large"), 107)
	end)
	-- Rejects non-finite and non-integral money values.
	t.test("rejects invalid money", function()
		expect.throws(function()
			Economy.priceForSize(math.huge, "Medium")
		end)
		expect.throws(function()
			Economy.priceForSize(82.5, "Medium")
		end)
		expect.falsy(Economy.canAfford(84, math.huge))
	end)
	-- CM2-G7: the size benchmarks follow the 80/130 rule on the medium benchmark.
	t.test("derives size benchmarks from the medium benchmark", function()
		expect.equal(Economy.typicalPrice("DouglasFir", "Small"), 112)
		expect.equal(Economy.typicalPrice("DouglasFir", "Medium"), 140)
		expect.equal(Economy.typicalPrice("DouglasFir", "Large"), 182)
		expect.equal(Economy.typicalPrice("NobleFir", "Large"), 241)
		expect.equal(Economy.typicalPrice("Pine", "Medium"), nil)
		expect.equal(Economy.typicalPrice("DouglasFir", "Huge"), nil)
	end)
end

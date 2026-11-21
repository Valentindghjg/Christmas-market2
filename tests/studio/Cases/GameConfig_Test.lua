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
end

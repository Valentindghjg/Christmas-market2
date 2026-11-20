-- Asset registry contract tests.
return function(t)
	local AssetCatalog = require(game:GetService("ReplicatedStorage").Shared.AssetCatalog)
	local expect = t.expect

	-- The starter stand ID must stay stable because WorldService clones it for every plot.
	t.test("keeps the starter stand ID stable", function()
		expect.equal(AssetCatalog.Buildings.MarketStarter, "MarketStarter")
	end)

	-- Every registered section provides non-empty string asset IDs for safe Studio lookup.
	t.test("contains valid IDs in every registered category", function()
		for _, category in pairs(AssetCatalog) do
			for _, assetId in pairs(category) do
				expect.truthy(type(assetId) == "string" and #assetId > 0)
			end
		end
	end)
end

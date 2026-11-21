--!strict
return function(t)
	local SupplierCatalog =
		require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SupplierCatalog"))
	local expect = t.expect

	-- Quotes always use the catalog wholesale value, never a caller value.
	t.test("derives wholesale quote from catalog", function()
		local quote = SupplierCatalog.quote("FrasierFir", "Medium")
		expect.equal(quote.unitCost, 32)
		expect.equal(quote.maxQuantity, 100)
		expect.equal(SupplierCatalog.quote("Unknown", "Medium"), nil)
	end)

	t.test("lists one quote per species and size in supplier order", function()
		local GameConfig =
			require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameConfig"))
		local list = SupplierCatalog.list()
		expect.equal(#list, 12)
		expect.equal(list[1].speciesId, "DouglasFir")
		expect.equal(list[1].sizeId, "Small")
		expect.equal(list[1].unitCost, 21)
		expect.equal(list[12].speciesId, "BlueSpruce")
		expect.equal(list[12].sizeId, "Large")
		expect.equal(list[12].unitCost, 61)
		for _, quote in ipairs(list) do
			expect.equal(quote.unitCost, GameConfig.wholesaleFor(quote.speciesId, quote.sizeId))
		end
	end)
end

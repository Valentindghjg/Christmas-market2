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
end

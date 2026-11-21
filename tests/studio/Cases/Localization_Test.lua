--!strict
return function(t)
	local Localization =
		require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Localization"))
	local expect = t.expect

	t.test("returns German translations", function()
		expect.equal(Localization.get("de", "cash"), "Geld")
	end)

	t.test("falls back to English then key", function()
		expect.equal(Localization.get("fr", "cash"), "Cash")
		expect.equal(Localization.get("de", "missingKey"), "missingKey")
	end)

	-- The spec requires localized keys rather than hardcoded prose in both languages.
	t.test("defines every key in both languages", function()
		for key in pairs(Localization.Strings.en) do
			expect.equal(type(Localization.Strings.de[key]), "string")
		end
		for key in pairs(Localization.Strings.de) do
			expect.equal(type(Localization.Strings.en[key]), "string")
		end
	end)

	t.test("formats templates and tolerates bad arguments", function()
		expect.equal(Localization.format("de", "orderAccepted", 32), "Bestellung angenommen: 32 $")
		expect.equal(Localization.format("en", "orderAccepted", "not a number"), "Order accepted: $%d")
	end)

	t.test("formats the supplier species row", function()
		expect.equal(
			Localization.format("en", "supplierSpeciesRow", "Douglas Fir", 21, 28, 41),
			"Douglas Fir\n$21 / $28 / $41"
		)
		expect.equal(
			Localization.format("de", "supplierSpeciesRow", "Douglas Fir", 21, 28, 41),
			"Douglas Fir\n21 $ / 28 $ / 41 $"
		)
	end)
end

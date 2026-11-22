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

	-- CM2-S1/R3: every save error code has a player-facing text in both languages.
	t.test("has an English text for every save error code", function()
		for code, key in pairs(Localization.SaveErrorKeys) do
			expect.equal(type(code), "string")
			expect.equal(type(Localization.Strings.en[key]), "string")
			expect.equal(type(Localization.Strings.de[key]), "string")
			expect.equal(Localization.saveErrorKey(code), key)
		end
		expect.equal(type(Localization.Strings.en.saveErrorUnknown), "string")
		expect.equal(type(Localization.Strings.de.saveErrorUnknown), "string")
		expect.equal(Localization.saveErrorKey("NoSuchCode"), "saveErrorUnknown")
		expect.equal(Localization.saveErrorKey(nil), "saveErrorUnknown")
	end)

	-- CM2-S1 fix round 1: a reason suffix after ":" stays in CompanyError for diagnostics.
	t.test("maps error codes with a reason suffix", function()
		expect.equal(Localization.saveErrorKey("LoadFailed:Throttled"), "saveErrorLoadFailed")
		expect.equal(Localization.saveErrorKey("SaveFailed:x"), "saveErrorSaveFailed")
		expect.equal(Localization.saveErrorKey("ServerShuttingDown"), "saveErrorLoadFailed")
		expect.equal(Localization.saveErrorKey("Nope"), "saveErrorUnknown")
		expect.equal(Localization.saveErrorKey(nil), "saveErrorUnknown")
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

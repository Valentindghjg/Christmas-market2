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
end

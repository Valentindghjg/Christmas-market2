--!strict
-- CM2-G7: the Pricing tab's pure text and step helpers.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local Localization = require(Shared:WaitForChild("Localization"))
	local PricingView = require(Shared:WaitForChild("PricingView"))
	local PricingService = require(game:GetService("ServerScriptService").Server.Services.PricingService)
	local expect = t.expect

	local function en(key: string, ...: any): string
		return Localization.format("en", key, ...)
	end

	t.test("shows the server values on the card", function()
		local state = BusinessState.new("personal:42", 42)
		state.mediumPrices.DouglasFir = 146
		local entry = PricingService.summary(state).species[1]
		expect.equal(entry.speciesId, "DouglasFir")
		local card = PricingView.card(entry, en)
		expect.truthy(card)
		expect.equal(card.name, "Douglas Fir")
		expect.equal(card.price, "$146")
		expect.equal(card.sentiment, "Fair price. Most shoppers are happy to pay it.")
		expect.equal(card.wholesaleTypical, "Wholesale for a medium tree is $28. The typical price is $140.")
		expect.equal(card.margin, "Your margin on a medium tree is $118 (81%).")
		expect.equal(card.sizes, "Small $117 (profit $96), medium $146 (profit $118), large $190 (profit $149).")
		expect.equal(PricingView.card({ speciesId = "DouglasFir" }, en), nil)
	end)

	t.test("clamps step targets into the server bounds", function()
		expect.equal(PricingView.stepTarget(146, 5, 70, 350), 151)
		expect.equal(PricingView.stepTarget(146, -1, 70, 350), 145)
		expect.equal(PricingView.stepTarget(72, -5, 70, 350), 70)
		expect.equal(PricingView.stepTarget(348, 5, 70, 350), 350)
		expect.equal(PricingView.stepTarget(50, 1, 80, 400), 80)
	end)

	t.test("words the auto switch, the rule and errors", function()
		expect.equal(PricingView.autoText(true, en), "Automatic pricing is on.")
		expect.equal(PricingView.autoText(false, en), "Automatic pricing is off.")
		expect.equal(PricingView.autoText(nil, en), "Automatic pricing is off.")
		expect.equal(
			PricingView.ruleText(en),
			"Set the medium price for each tree. Small trees sell for 80% of it and large trees for 130%. "
				.. "Higher prices earn more per tree, but fewer customers buy."
		)
		expect.equal(PricingView.errorText("InvalidPrice", en), "That price is outside the allowed range.")
		expect.equal(PricingView.errorText("RateLimited", en), "That was too many requests. Please wait a moment.")
	end)
end

--!strict
-- CM2-46a: the Robux shop products of the reference, all with empty IDs.
return function(t)
	local ShopConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ShopConfig"))
	local expect = t.expect

	local ORDER = {
		"StarterPack",
		"PassCashX2",
		"PassReputationX2",
		"PassInstantDelivery",
		"PassVip",
		"CashPinecone",
		"CashSleigh",
		"CashCabin",
		"CashVillage",
		"CashMountain",
		"BoostCashX2",
		"BoostRested",
		"TreeFrostcrown",
		"TreeHollyberry",
		"EventTreeCandlelight",
		"EventTreeStarlight",
		"EventTreeSnowberry",
		"EventDecorPack",
		"DecorLanternBoardwalk",
		"DecorFarmTruck",
		"DecorSnowGlobe",
		"DecorWorkshopElf",
		"DecorToyTrain",
		"DecorSnowMaker",
		"DecorFatherChristmas",
		"DecorPhotoCorner",
		"DecorVillageExpress",
	}

	local PRICES = {
		StarterPack = 79,
		PassCashX2 = 99,
		PassReputationX2 = 79,
		PassInstantDelivery = 149,
		PassVip = 199,
		CashPinecone = 29,
		CashSleigh = 99,
		CashCabin = 249,
		CashVillage = 599,
		CashMountain = 1499,
		BoostCashX2 = 10,
		BoostRested = 5,
		TreeFrostcrown = 149,
		TreeHollyberry = 149,
		EventTreeCandlelight = 199,
		EventTreeStarlight = 199,
		EventTreeSnowberry = 199,
		EventDecorPack = 29,
		DecorLanternBoardwalk = 49,
		DecorFarmTruck = 75,
		DecorSnowGlobe = 79,
		DecorWorkshopElf = 79,
		DecorToyTrain = 99,
		DecorSnowMaker = 99,
		DecorFatherChristmas = 99,
		DecorPhotoCorner = 129,
		DecorVillageExpress = 149,
	}

	t.test("lists every product once with a known category and kind", function()
		expect.equal(#ShopConfig.Products, 27)
		local seen = {}
		for index, product in ipairs(ShopConfig.Products) do
			expect.equal(product.key, ORDER[index])
			expect.falsy(seen[product.key])
			seen[product.key] = true
			expect.truthy(ShopConfig.isKey(product.key))
			expect.truthy(table.find(ShopConfig.Categories, product.category) ~= nil)
			expect.truthy(product.kind == "Pass" or product.kind == "Product")
			expect.equal(ShopConfig.byKey(product.key), product)
			if product.kind == "Pass" then
				expect.truthy(table.find(ShopConfig.PerkFields, product.perk) ~= nil)
				expect.equal(product.grant, nil)
				expect.equal(product.category, "Passes")
			else
				expect.equal(product.perk, nil)
				expect.equal(type(product.grant), "table")
			end
		end
		expect.falsy(ShopConfig.isKey("1Bad"))
		expect.falsy(ShopConfig.isKey("Bad-Key"))
		expect.falsy(ShopConfig.isKey(string.rep("a", 33)))
		expect.falsy(ShopConfig.isKey(7))
		expect.equal(ShopConfig.byKey("Nope"), nil)
	end)

	t.test("carries the created IDs and leaves the other products at 0", function()
		local IDS = {
			StarterPack = 3735805319,
			PassCashX2 = 2101828296,
			PassReputationX2 = 2099729097,
			PassInstantDelivery = 2099165138,
			PassVip = 2098973055,
			CashPinecone = 3735805373,
			CashSleigh = 3735805396,
			CashCabin = 3735805416,
			CashVillage = 3735805452,
			CashMountain = 3735805469,
			BoostCashX2 = 3735805526,
			BoostRested = 3735805549,
		}
		for _, product in ipairs(ShopConfig.Products) do
			expect.equal(product.id, IDS[product.key] or 0)
			local found = if product.kind == "Pass"
				then ShopConfig.byPassId(product.id)
				else ShopConfig.byProductId(product.id)
			if IDS[product.key] then
				expect.equal(found, product)
			end
		end
		expect.equal(ShopConfig.byProductId(0), nil)
		expect.equal(ShopConfig.byPassId(0), nil)
	end)

	t.test("marks only products with a working effect as ready", function()
		for index, product in ipairs(ShopConfig.Products) do
			expect.equal(product.ready, index <= 12)
		end
	end)

	t.test("names and describes every product", function()
		local Localization =
			require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Localization"))
		for _, product in ipairs(ShopConfig.Products) do
			local nameKey, descKey = ShopConfig.textKeys(product)
			expect.equal(type(Localization.Strings.en[nameKey]), "string")
			expect.equal(type(Localization.Strings.en[descKey]), "string")
		end
		local cash = ShopConfig.byKey("CashPinecone") :: ShopConfig.Product
		local _, cashDesc = ShopConfig.textKeys(cash)
		expect.equal(cashDesc, "shopDescCash")
		local event = ShopConfig.byKey("EventTreeStarlight") :: ShopConfig.Product
		local _, eventDesc = ShopConfig.textKeys(event)
		expect.equal(eventDesc, "shopDescEventTree")
		local pack = ShopConfig.byKey("EventDecorPack") :: ShopConfig.Product
		local _, packDesc = ShopConfig.textKeys(pack)
		expect.equal(packDesc, "shopDescEventDecorPack")
	end)

	t.test("keeps the observed prices", function()
		for _, product in ipairs(ShopConfig.Products) do
			expect.equal(product.price, PRICES[product.key])
		end
	end)
end

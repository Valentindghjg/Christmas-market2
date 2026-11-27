--!strict
return function(t)
	local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameConfig"))
	local Progression = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Progression"))
	local expect = t.expect

	t.test("contains the observed size price rule", function()
		expect.equal(GameConfig.VERSION, 1)
		expect.equal(GameConfig.SizeMultipliers.Small, 0.8)
		expect.equal(GameConfig.SizeMultipliers.Medium, 1)
		expect.equal(GameConfig.SizeMultipliers.Large, 1.3)
	end)

	t.test("marks observed trees and unlocks", function()
		expect.equal(GameConfig.Trees.FrasierFir.evidence, GameConfig.Evidence.Observed)
		expect.equal(GameConfig.Progression.HQ.tiers[2].evidence, GameConfig.Evidence.Observed)
		expect.equal(GameConfig.Employees.Cashier.maxCount, 1)
	end)

	t.test("lists the four starter species in the observed supplier order", function()
		expect.equal(#GameConfig.SpeciesOrder, 4)
		expect.equal(GameConfig.SpeciesOrder[1], "DouglasFir")
		expect.equal(GameConfig.SpeciesOrder[2], "FrasierFir")
		expect.equal(GameConfig.SpeciesOrder[3], "NobleFir")
		expect.equal(GameConfig.SpeciesOrder[4], "BlueSpruce")
		local treeCount = 0
		for _ in pairs(GameConfig.Trees) do
			treeCount += 1
		end
		expect.equal(treeCount, 4)
		for _, speciesId in ipairs(GameConfig.SpeciesOrder) do
			expect.truthy(GameConfig.Trees[speciesId])
		end
	end)

	t.test("holds the observed wholesale for every species and size", function()
		local expected = {
			DouglasFir = { Small = 21, Medium = 28, Large = 41 },
			FrasierFir = { Small = 24, Medium = 32, Large = 46 },
			NobleFir = { Small = 28, Medium = 37, Large = 54 },
			BlueSpruce = { Small = 32, Medium = 42, Large = 61 },
		}
		for _, speciesId in ipairs(GameConfig.SpeciesOrder) do
			for _, sizeId in ipairs(GameConfig.SizeIds) do
				expect.equal(GameConfig.wholesaleFor(speciesId, sizeId), expected[speciesId][sizeId])
			end
		end
	end)

	t.test("keeps the FrasierFir ID and shows the Fraser Fir spelling", function()
		expect.equal(GameConfig.Trees.FrasierFir.displayName, "Fraser Fir")
		expect.equal(GameConfig.Trees.DouglasFir.displayName, "Douglas Fir")
		expect.equal((GameConfig.Trees :: any).FraserFir, nil)
	end)

	t.test("marks rarity and evidence of the starter species", function()
		expect.equal(GameConfig.Trees.DouglasFir.rarity, "Common")
		expect.equal(GameConfig.Trees.FrasierFir.rarity, "Uncommon")
		expect.equal(GameConfig.Trees.NobleFir.rarity, "Rare")
		expect.equal(GameConfig.Trees.BlueSpruce.rarity, "Uncommon")
		for _, tree in pairs(GameConfig.Trees) do
			expect.equal(tree.evidence, GameConfig.Evidence.Observed)
		end
	end)

	t.test("gives every species complete integer pricing data", function()
		local function positiveInteger(value: unknown): boolean
			return type(value) == "number" and value == math.floor(value) and value > 0
		end
		for speciesId, tree in pairs(GameConfig.Trees) do
			expect.truthy(positiveInteger(tree.wholesale.Small))
			expect.truthy(positiveInteger(tree.wholesale.Medium))
			expect.truthy(positiveInteger(tree.wholesale.Large))
			expect.truthy(tree.wholesale.Small < tree.wholesale.Medium)
			expect.truthy(tree.wholesale.Medium < tree.wholesale.Large)
			expect.truthy(positiveInteger(GameConfig.typicalMediumFor(speciesId)))
			expect.equal(type(tree.displayName), "string")
			expect.truthy(#tree.displayName > 0)
		end
	end)

	-- CM2-G7: the "typical" price is about 5 x medium wholesale (REFERENCE_GAME_LIVE_TEST §4.3).
	t.test("derives the typical price from wholesale x 5", function()
		local Pricing = GameConfig.Pricing
		expect.equal(Pricing.BenchmarkMultiplier, 5)
		expect.equal(GameConfig.typicalMediumFor("DouglasFir"), 140)
		expect.equal(GameConfig.typicalMediumFor("FrasierFir"), 160)
		expect.equal(GameConfig.typicalMediumFor("NobleFir"), 184)
		expect.equal(GameConfig.typicalMediumFor("BlueSpruce"), 210)
		expect.equal(GameConfig.typicalMediumFor("Pine"), nil)
		expect.equal(GameConfig.typicalMediumFor(5), nil)
		expect.equal(#Pricing.Steps, 4)
		expect.equal(Pricing.Steps[1], -5)
		expect.equal(Pricing.Steps[2], -1)
		expect.equal(Pricing.Steps[3], 1)
		expect.equal(Pricing.Steps[4], 5)
		expect.truthy(Pricing.SentimentPercent.Bargain == 85)
		expect.truthy(Pricing.SentimentPercent.Bargain < Pricing.SentimentPercent.Fair)
		expect.truthy(Pricing.SentimentPercent.Fair == 110)
		expect.truthy(Pricing.SentimentPercent.Fair < Pricing.SentimentPercent.Pricey)
		expect.truthy(Pricing.SentimentPercent.Pricey == 130)
		expect.equal(Pricing.BudgetPercent.Min, 85)
		expect.equal(Pricing.BudgetPercent.Max, 155)
	end)

	-- CM2-G7a: an OBSERVED typical card that differs from the 5 x rule overrides it (Noble 184).
	t.test("takes observed typical prices over the 5x rule", function()
		local Pricing = GameConfig.Pricing
		expect.equal(Pricing.TypicalMediumOverride.NobleFir, 184)
		local keyCount = 0
		for speciesId, value in pairs(Pricing.TypicalMediumOverride) do
			keyCount += 1
			expect.truthy(GameConfig.Trees[speciesId])
			expect.truthy(type(value) == "number" and value == math.floor(value) and value > 0)
		end
		expect.equal(keyCount, 1)
		local expected = { 140, 160, 184, 210 }
		for index, speciesId in ipairs(GameConfig.SpeciesOrder) do
			expect.equal(GameConfig.typicalMediumFor(speciesId), expected[index])
		end
		expect.equal(GameConfig.Trees.NobleFir.wholesale.Medium * Pricing.BenchmarkMultiplier, 185)
	end)

	-- CM2-G14: stocking spots and the delivery countdown.
	t.test("placement config is consistent", function()
		local Placement = GameConfig.Placement
		for _, sizeId in ipairs(GameConfig.SizeIds) do
			expect.truthy(Placement.FootprintRadius[sizeId] > 0)
		end
		expect.truthy(Placement.Gap.Default >= Placement.Gap.Min and Placement.Gap.Default <= Placement.Gap.Max)
		expect.truthy(Placement.RowMax >= 5)
		expect.equal(GameConfig.DeliverySeconds, 30)
		expect.truthy(#Placement.KeepClear > 0)
		for _, box in ipairs(Placement.KeepClear) do
			expect.equal(type(box.id), "string")
			expect.truthy(box.minX < box.maxX)
			expect.truthy(box.minZ < box.maxZ)
		end
	end)

	-- CM2-N1: walking customers fill the parking, and a reservation outlasts the longest walk.
	t.test("NPC budget matches plots and parking", function()
		local Npc = GameConfig.Customers.Npc
		expect.equal(Npc.MaxPerPlot, GameConfig.Progression.Parking.maxSpaces)
		expect.equal(#GameConfig.PersonalPlotIds, 6)
		expect.equal(Npc.MaxPerServer, 6 * 4)
		-- CM2-G9a: with the longest queue patience (HQ 4, 117 s).
		local patience = Progression.queuePatienceFor(4)
		expect.truthy(
			Npc.ReservationSeconds
				>= 2 * Npc.LegTimeoutSeconds + Npc.PickUpSeconds + patience + Npc.CashierCheckoutSeconds
		)
		-- CM2-N2: the visit cap outlasts the longest regular visit (312.5 <= 360).
		expect.truthy(
			Npc.MaxVisitSeconds
				>= Npc.CarArriveSeconds
					+ 4 * Npc.LegTimeoutSeconds
					+ Npc.BrowseSeconds
					+ Npc.PickUpSeconds
					+ patience
					+ Npc.CashierCheckoutSeconds
					+ GameConfig.Customers.PickupPatienceSeconds
					+ Npc.WaitAtCarExtraSeconds
		)
		expect.truthy(Npc.LoadSeconds >= 10 and Npc.LoadSeconds <= 120)
		-- Fix round 1: the aisle and queue clear the inflated boxes, and corners keep a margin.
		local stand
		for _, box in ipairs(GameConfig.Placement.KeepClear) do
			if box.id == "Stand" then
				stand = box
			end
		end
		expect.truthy(stand ~= nil)
		expect.truthy(Npc.Path.AisleDepth > stand.maxZ + Npc.Clearance)
		expect.truthy(Npc.Path.QueueFirstDepth > Npc.Path.Counter.maxZ + Npc.CounterClearance)
		expect.truthy(Npc.CornerRadius < Npc.ArriveRadius)
		expect.truthy(Npc.Clearance - Npc.CornerRadius >= 2)
		local function checkRgb(rgb)
			expect.equal(#rgb, 3)
			for _, value in ipairs(rgb) do
				expect.truthy(type(value) == "number" and value == math.floor(value) and value >= 0 and value <= 255)
			end
		end
		for _, listName in ipairs({ "Skin", "Coat", "Pants", "Scarf", "Beanie" }) do
			for _, rgb in ipairs(Npc.Look[listName]) do
				checkRgb(rgb)
			end
		end
		checkRgb(Npc.Look.Boots)
	end)

	-- CM2-R5: main's BindToClose waits SHUTDOWN_WAIT_SECONDS = 25.
	t.test("unload retries fit the fail-closed window and the shutdown budget", function()
		local sum = 0
		for _, delay in ipairs(GameConfig.UnloadRetry.DelaysSeconds) do
			expect.truthy(type(delay) == "number" and delay == math.floor(delay) and delay > 0)
			sum += delay
		end
		expect.equal(sum, 78)
		expect.truthy(sum <= GameConfig.SaveFailClosedSeconds)
		expect.equal(GameConfig.UnloadRetry.ShutdownSeconds, 18)
		expect.truthy(GameConfig.UnloadRetry.ShutdownSeconds + 5 <= 25)
	end)

	-- CM2-G15: star thresholds, reputation per star and the lot sign's keep-clear box.
	t.test("review thresholds and sign spot", function()
		local Reviews = GameConfig.Reviews
		expect.equal(#Reviews.StarMaxSeconds, 4)
		for index = 2, #Reviews.StarMaxSeconds do
			expect.truthy(Reviews.StarMaxSeconds[index] > Reviews.StarMaxSeconds[index - 1])
		end
		expect.equal(#Reviews.ReputationByStars, 5)
		local Placement = GameConfig.Placement
		local sign
		for _, box in ipairs(Placement.KeepClear) do
			if box.id == "Sign" then
				sign = box
			end
		end
		expect.truthy(sign ~= nil)
		expect.truthy(sign.minX >= -Placement.LotHalfWidth and sign.maxX <= Placement.LotHalfWidth)
		expect.truthy(sign.minZ >= -Placement.LotHalfDepth and sign.maxZ <= Placement.LotHalfDepth)
		for _, box in ipairs(Placement.KeepClear) do
			if box ~= sign then
				local overlaps = sign.minX < box.maxX
					and box.minX < sign.maxX
					and sign.minZ < box.maxZ
					and box.minZ < sign.maxZ
				expect.falsy(overlaps)
			end
		end
		expect.truthy(sign.minX <= Reviews.SignX - 4 and sign.maxX >= Reviews.SignX + 4)
		expect.truthy(sign.minZ <= Reviews.SignZ - 0.4 and sign.maxZ >= Reviews.SignZ + 0.4)
	end)

	-- CM2-G15 Amendment 1: the decorative fences stay clear of the lot sign's box.
	t.test("lot sign clears the decorative fences", function()
		local Placement = GameConfig.Placement
		local sign
		for _, box in ipairs(Placement.KeepClear) do
			if box.id == "Sign" then
				sign = box
			end
		end
		expect.truthy(sign ~= nil)
		expect.equal(#Placement.DecorFences, 1)
		for _, fence in ipairs(Placement.DecorFences) do
			expect.truthy(math.abs(fence.x) <= Placement.LotHalfWidth)
			expect.truthy(math.abs(fence.z) <= Placement.LotHalfDepth)
			local closestX = math.clamp(fence.x, sign.minX, sign.maxX)
			local closestZ = math.clamp(fence.z, sign.minZ, sign.maxZ)
			local distance = math.sqrt((fence.x - closestX) ^ 2 + (fence.z - closestZ) ^ 2)
			expect.truthy(distance > Placement.DecorFenceRadius)
		end
	end)

	-- CM2-25/26: visible staff, energy and the break area.
	t.test("staff config is consistent", function()
		local Staff = GameConfig.Staff
		expect.equal(Staff.MaxPerServer, #GameConfig.PersonalPlotIds * Staff.MaxPerPlot)
		expect.equal(Staff.MaxPerPlot, #Staff.Roles)
		expect.truthy(Staff.Energy.TiredAt < Staff.Energy.RestedAt)
		expect.truthy(Staff.Energy.RestedAt <= Staff.Energy.Max)
		expect.equal(Staff.CarrierUserId, 0)
		expect.equal(GameConfig.Customers.WorkerLoadSeconds, nil)
		for _, role in ipairs(Staff.Roles) do
			expect.truthy(GameConfig.Employees[role] ~= nil)
			expect.equal(GameConfig.Employees[role].maxCount, 1)
		end
		expect.equal(GameConfig.Employees.LotManager.hireCost, 1250000)
		expect.equal(GameConfig.Employees.LotManager.requiredHqTier, 4)
		expect.equal(#Staff.BreakArea.Logs, #Staff.Roles)
		expect.equal(#Staff.BreakArea.RestPoints, #Staff.Roles)
		local function colour(rgb)
			expect.equal(#rgb, 3)
			for _, channel in ipairs(rgb) do
				expect.truthy(channel >= 0 and channel <= 255 and channel == math.floor(channel))
			end
		end
		for key, value in pairs(Staff.Uniform) do
			if key == "Beanie" then
				for _, role in ipairs(Staff.Roles) do
					colour(value[role])
				end
			else
				colour(value)
			end
		end
	end)
end

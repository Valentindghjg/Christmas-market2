--!strict
-- CM2-G9b: the Land tab's pure text mapping.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local LandView = require(Shared:WaitForChild("LandView"))
	local Localization = require(Shared:WaitForChild("Localization"))
	local Progression = require(Shared:WaitForChild("Progression"))
	local expect = t.expect

	t.test("maps every requirement row to a sentence key", function()
		local cash = LandView.rowLine({ id = "Cash", have = 800, need = 1200, met = false })
		expect.equal(cash.key, "landRowCash")
		expect.equal(cash.args[1], "$800")
		expect.equal(cash.args[2], "$1,200")
		expect.equal(cash.met, false)
		local reputation = LandView.rowLine({ id = "Reputation", have = 10, need = 400, met = false })
		expect.equal(reputation.key, "landRowReputation")
		expect.equal(reputation.args[1], 10)
		expect.equal(reputation.args[2], 400)
		for _, id in ipairs({ "LotExpansion", "ParkingTier", "HqLevel" }) do
			local line = LandView.rowLine({ id = id, have = 1, need = 2, met = true })
			expect.equal(line.key, "landRow" .. id)
			expect.equal(#line.args, 2)
			expect.equal(line.met, true)
		end
		local manager = LandView.rowLine({ id = "LotManager", have = 0, need = 1, met = false })
		expect.equal(manager.key, "landRowLotManager")
		expect.equal(#manager.args, 0)
		local unknown = LandView.rowLine({ id = "Mystery", have = 0, need = 1, met = false })
		expect.equal(unknown.key, "landRowUnknown")
		expect.equal(unknown.args[1], "Mystery")
	end)

	t.test("marks inactive unlocks as coming soon", function()
		local expected = {
			{ { id = "DisplaySpace", value = 8, active = true }, "landUnlockDisplaySpace", 8 },
			{ { id = "DeliveryStorage", value = 10, active = true }, "landUnlockDeliveryStorage", 10 },
			{ { id = "ParkingSpaces", value = 4, active = true }, "landUnlockParkingSpaces", 4 },
			{ { id = "NewSpecies", value = 4, active = false }, "landUnlockNewSpeciesSoon", 4 },
			{ { id = "CheckoutStations", value = 2, active = false }, "landUnlockCheckoutStationsSoon", 2 },
			{ { id = "EmployeeCapacity", value = 3, active = true }, "landUnlockEmployeeCapacity", 3 },
			{ { id = "CustomerPatience", value = 12, active = true }, "landUnlockCustomerPatience", 12 },
			{ { id = "LotManager", active = true }, "landUnlockLotManager", nil },
			{ { id = "ElfWorkshop", active = false }, "landUnlockElfWorkshopSoon", nil },
		}
		for _, case in ipairs(expected) do
			local line = LandView.unlockLine(case[1])
			expect.equal(line.key, case[2])
			expect.equal(line.args[1], case[3])
		end
		expect.equal(LandView.unlockLine({ id = "Nope", active = true }).key, "landRowUnknown")
	end)

	t.test("builds status and next lines from a summary", function()
		local summary = Progression.summary(BusinessState.new("personal:42", 42))
		local lotStatus = LandView.statusLine("LotExpansion", summary.lotExpansion)
		expect.equal(lotStatus.key, "landLotStatus")
		expect.equal(lotStatus.args[1].nameKey, "landLevel_Starter")
		expect.equal(lotStatus.args[2], 0)
		expect.equal(lotStatus.args[3], 6)
		expect.equal(lotStatus.args[4], 30)
		local lotNext = LandView.nextLine("LotExpansion", summary.lotExpansion.next)
		expect.equal(lotNext.key, "landNextLot")
		expect.equal(lotNext.args[1], 1)
		expect.equal(lotNext.args[2].nameKey, "landLevel_BackLot")
		expect.equal(lotNext.args[3], "$1,200")
		local parkingNext = LandView.nextLine("Parking", summary.parking.next)
		expect.equal(parkingNext.key, "landNextParking")
		expect.equal(parkingNext.args[1], 2)
		expect.equal(parkingNext.args[2], 2)
		expect.equal(parkingNext.args[3], "$400")
		local hqNext = LandView.nextLine("HQ", summary.hq.next)
		expect.equal(hqNext.key, "landNextHq")
		expect.equal(hqNext.args[1].nameKey, "hq_TimberPavilion")
		expect.equal(hqNext.args[2], "$2,500")
		expect.equal(LandView.statusLine("Parking", summary.parking).key, "landParkingStatusOne")
		expect.equal(LandView.statusLine("HQ", summary.hq).args[3].nameKey, "hq_SalesTent")
		expect.equal(LandView.nextLine("Parking", nil).key, "landMaxed")
	end)

	-- CM2-PARK: "Parking tier n of 4", with "1 space" on the fresh tier.
	t.test("parking status reads tier n of 4", function()
		local state = BusinessState.new("personal:42", 42)
		local fresh = LandView.statusLine("Parking", Progression.summary(state).parking)
		expect.equal(fresh.key, "landParkingStatusOne")
		expect.equal(table.concat(fresh.args, ","), "1,4")
		state.progression.parkingTier = 3
		local three = LandView.statusLine("Parking", Progression.summary(state).parking)
		expect.equal(three.key, "landParkingStatus")
		expect.equal(table.concat(three.args, ","), "3,4,3")
		state.progression.parkingTier = 4
		expect.equal(LandView.nextLine("Parking", Progression.summary(state).parking.next).key, "landMaxed")
	end)

	t.test("every key exists in both languages", function()
		local keys = {
			"landLotTitle",
			"landParkingTitle",
			"landHqTitle",
			"landWorkshopTitle",
			"landLotStatus",
			"landParkingStatus",
			"landParkingStatusOne",
			"landHqStatus",
			"landNextLot",
			"landNextParking",
			"landNextHq",
			"landMaxed",
			"landRowCash",
			"landRowReputation",
			"landRowLotExpansion",
			"landRowParkingTier",
			"landRowHqLevel",
			"landRowLotManager",
			"landRowUnknown",
			"landRowDone",
			"landRowMissing",
			"landUnlockNewSpeciesSoon",
			"landUnlockCheckoutStationsSoon",
			"landUnlockEmployeeCapacity",
			"landUnlockCustomerPatience",
			"landUnlockLotManager",
			"landUnlockElfWorkshopSoon",
			"landUnlockDisplaySpace",
			"landUnlockDeliveryStorage",
			"landUnlockParkingSpaces",
			"landBuy",
			"landBuyConfirm",
			"landNotReady",
			"landComingSoon",
			"landWorkshopLocked",
			"landWorkshopUnlocked",
			"landErrorOwned",
			"landErrorOrder",
			"landErrorRequirements",
			"landErrorReputation",
			"staffStandby",
			"landLevel_Starter",
			"landLevel_BackLot",
			"landLevel_SpruceCorner",
			"landLevel_WoodlandEdge",
			"landLevel_PineClearing",
			"landLevel_SnowyMeadow",
			"landLevel_ForestGlade",
			"hq_SalesTent",
			"hq_TimberPavilion",
			"hq_AlpineHut",
			"hq_MountainChalet",
		}
		for _, key in ipairs(keys) do
			expect.truthy(Localization.Strings.en[key])
			expect.truthy(Localization.Strings.de[key])
		end
		for _, key in pairs(LandView.ERROR_KEYS) do
			expect.truthy(Localization.Strings.en[key])
			expect.truthy(Localization.Strings.de[key])
		end
	end)
end

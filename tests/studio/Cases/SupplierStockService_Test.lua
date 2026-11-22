--!strict
-- G5 finite supplier stock, refresh, demand tags, recommended order and sell-back.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
	local Supplier = require(Services:WaitForChild("SupplierStockService"))
	local CompanyStateService = require(Services:WaitForChild("CompanyStateService"))
	local expect = t.expect

	local function constant(value: number)
		return function()
			return value
		end
	end

	t.test("orders deplete supplier stock and stop at zero", function()
		local state = BusinessState.new("personal:42", 42)
		state.cash = 100000
		state.supplier.stock["FrasierFir:Large"] = 3
		expect.truthy(BusinessState.placeOrder(state, "deplete_01", "FrasierFir", "Large", 2, 100))
		expect.equal(state.supplier.stock["FrasierFir:Large"], 1)
		local cash = state.cash
		local ok, reason = BusinessState.placeOrder(state, "deplete_02", "FrasierFir", "Large", 2, 100)
		expect.falsy(ok)
		expect.equal(reason, "SupplierOutOfStock")
		expect.equal(state.cash, cash)
	end)

	t.test("refreshes stock only when due", function()
		local state = BusinessState.new("personal:42", 42)
		expect.truthy(Supplier.refreshIfDue(state, 100, constant(0.5)))
		expect.equal(state.supplier.refreshAt, 100 + GameConfig.Supplier.RefreshSeconds)
		expect.equal(state.supplier.stock["NobleFir:Medium"], GameConfig.Supplier.BaseStock.Medium)
		state.supplier.stock["NobleFir:Medium"] = 0
		expect.falsy(Supplier.refreshIfDue(state, 101, constant(0.5)))
		expect.equal(state.supplier.stock["NobleFir:Medium"], 0)
		expect.truthy(Supplier.refreshIfDue(state, state.supplier.refreshAt, constant(0.5)))
		expect.equal(state.supplier.stock["NobleFir:Medium"], GameConfig.Supplier.BaseStock.Medium)
		expect.truthy(BusinessState.validate(state))
	end)

	t.test("assigns high and low demand tags from the roll", function()
		local state = BusinessState.new("personal:42", 42)
		Supplier.refreshIfDue(state, 100, constant(0))
		expect.equal(state.supplier.demand["FrasierFir:Small"], "High")
		state.supplier.refreshAt = 0
		Supplier.refreshIfDue(state, 100, constant(1))
		expect.equal(state.supplier.demand["FrasierFir:Small"], "Low")
		expect.truthy(BusinessState.validate(state))
	end)

	t.test("recommends one small and two medium per species within one bay and cash", function()
		local state = BusinessState.new("personal:42", 42)
		state.cash = 100000
		local recommendation = Supplier.recommend(state)
		expect.equal(recommendation.quantity, GameConfig.Receiving.BayCapacity)
		state.cash = 0
		expect.equal(Supplier.recommend(state).quantity, 0)
	end)

	t.test("refunds a quarter of wholesale rounded half up", function()
		-- Fraser large wholesale 46 -> 11.5 -> 12; medium 32 -> 8.
		expect.equal(Supplier.refundFor("FrasierFir", "Large"), 12)
		expect.equal(Supplier.refundFor("FrasierFir", "Medium"), 8)
	end)

	t.test("sells back from storage first, then the lot, never reserved trees", function()
		local state = BusinessState.new("personal:42", 42)
		state.stock["FrasierFir:Medium"] = 1
		state.layout.placements.fir_a = { speciesId = "FrasierFir", sizeId = "Medium" }
		state.layout.placements.fir_b = { speciesId = "FrasierFir", sizeId = "Medium" }
		state.reservations.fir_b = { customerId = "customer:1", expiresAt = 999, salePrice = 82 }
		local cash = state.cash
		local ok, result = Supplier.sellBack(state, "FrasierFir", "Medium", 2)
		expect.truthy(ok)
		expect.equal(result.refund, 16)
		expect.equal(result.fromLot, 1)
		expect.equal(state.cash, cash + 16)
		expect.equal(state.stock["FrasierFir:Medium"] or 0, 0)
		expect.equal(state.layout.placements.fir_a, nil)
		expect.truthy(state.layout.placements.fir_b)
		local more, reason = Supplier.sellBack(state, "FrasierFir", "Medium", 1)
		expect.falsy(more)
		expect.equal(reason, "NotEnoughTrees")
		expect.equal(state.cash, cash + 16)
		expect.truthy(BusinessState.validate(state))
	end)

	t.test("sell-back requests are idempotent through the protocol", function()
		local records = {}
		local persistence = {
			load = function(_, companyId, ownerUserId)
				records[companyId] = records[companyId] or BusinessState.new(companyId, ownerUserId)
				return records[companyId], nil
			end,
			save = function()
				return true, nil
			end,
			release = function()
				return true, nil
			end,
		}
		local service = CompanyStateService.new(persistence, constant(100), constant(0.5))
		local state = service:loadCompany("personal:42", 42)
		state.stock["NobleFir:Small"] = 2
		local sell = {
			version = 1,
			requestId = "sellback_01",
			action = "Supplier.SellBack",
			payload = { speciesId = "NobleFir", sizeId = "Small", quantity = 1 },
		}
		local cash = state.cash
		expect.truthy(service:handle("personal:42", 42, sell).ok)
		expect.equal(service:handle("personal:42", 42, sell).errorCode, "DuplicateRequest")
		expect.equal(state.stock["NobleFir:Small"], 1)
		expect.equal(state.cash, cash + Supplier.refundFor("NobleFir", "Small"))
	end)

	t.test("the summary exposes stock, demand, refresh and recommendation", function()
		local state = BusinessState.new("personal:42", 42)
		Supplier.refreshIfDue(state, 100, constant(0))
		local summary = Supplier.summary(state, 160)
		expect.equal(summary.refreshIn, GameConfig.Supplier.RefreshSeconds - 60)
		expect.equal(summary.demand["BlueSpruce:Large"], "High")
		expect.truthy(summary.stock["BlueSpruce:Large"] > 0)
		expect.truthy(summary.recommended)
	end)

	t.test("matches the observed sell-back refunds", function()
		expect.equal(Supplier.refundFor("DouglasFir", "Small"), 5)
		expect.equal(Supplier.refundFor("NobleFir", "Large"), 14)
		expect.equal(Supplier.refundFor("DouglasFir", "Large"), 10)
	end)

	t.test("recommends Douglas Fir and Fraser Fir first in supplier order", function()
		local state = BusinessState.new("personal:42", 42)
		state.cash = 100000
		local recommendation = Supplier.recommend(state)
		expect.equal(#recommendation.lines, 6)
		expect.equal(recommendation.quantity, 9)
		expect.equal(recommendation.cost, 267)
		local expected = {
			{ "DouglasFir", "Small", 1 },
			{ "DouglasFir", "Medium", 2 },
			{ "FrasierFir", "Small", 1 },
			{ "FrasierFir", "Medium", 2 },
			{ "NobleFir", "Small", 1 },
			{ "NobleFir", "Medium", 2 },
		}
		for index, line in ipairs(expected) do
			expect.equal(recommendation.lines[index].speciesId, line[1])
			expect.equal(recommendation.lines[index].sizeId, line[2])
			expect.equal(recommendation.lines[index].quantity, line[3])
		end
	end)

	t.test("the summary exposes the server wholesale table", function()
		local state = BusinessState.new("personal:42", 42)
		local wholesale = Supplier.summary(state, 0).wholesale
		local count = 0
		for _ in pairs(wholesale) do
			count += 1
		end
		expect.equal(count, 12)
		expect.equal(wholesale["DouglasFir:Medium"], 28)
		expect.equal(wholesale["FrasierFir:Large"], 46)
		expect.equal(wholesale["BlueSpruce:Large"], 61)
	end)

	t.test("an existing save gains Douglas Fir supplier stock at the next refresh", function()
		local state = BusinessState.new("personal:42", 42)
		state.cash = 1000
		state.stock["FrasierFir:Medium"] = 3
		state.mediumPrices.FrasierFir = 90
		state.mediumPrices.DouglasFir = nil
		for _, sizeId in ipairs(GameConfig.SizeIds) do
			state.supplier.stock["DouglasFir:" .. sizeId] = nil
		end
		state.supplier.refreshAt = 1000
		local migrated, err = BusinessState.migrate(state, "personal:42", 42)
		expect.equal(err, nil)
		expect.truthy(migrated)
		expect.equal(migrated.schemaVersion, BusinessState.SCHEMA_VERSION)
		expect.equal(migrated.stock["FrasierFir:Medium"], 3)
		expect.equal(migrated.mediumPrices.FrasierFir, 90)
		expect.equal(migrated.mediumPrices.DouglasFir, GameConfig.Trees.DouglasFir.initialMediumPrice)
		local early, reason = BusinessState.placeOrder(migrated, "douglas_early", "DouglasFir", "Small", 1, 100)
		expect.falsy(early)
		expect.equal(reason, "SupplierOutOfStock")
		expect.equal(migrated.cash, 1000)
		expect.truthy(Supplier.refreshIfDue(migrated, 1000, constant(0.5)))
		local ok, order = BusinessState.placeOrder(migrated, "douglas_after", "DouglasFir", "Small", 1, 1000)
		expect.truthy(ok)
		expect.equal(order.cost, 21)
		expect.equal(migrated.cash, 979)
	end)
end

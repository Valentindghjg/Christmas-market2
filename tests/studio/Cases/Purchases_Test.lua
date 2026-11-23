--!strict
-- CM2-46a: the schema-17 purchases record of a company save.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local Purchases = require(Shared:WaitForChild("Purchases"))
	local ShopConfig = require(Shared:WaitForChild("ShopConfig"))
	local expect = t.expect

	local function fresh()
		return BusinessState.new("save:42_" .. string.rep("0a", 8), 42)
	end

	t.test("validates the purchases record", function()
		local state = fresh()
		expect.truthy(Purchases.isValid(state))
		expect.truthy(BusinessState.validate(state))
		local mutations = {
			function(s)
				s.purchases.receipts = { "" }
			end,
			function(s)
				s.purchases.receipts = { 7 }
			end,
			function(s)
				s.purchases.receipts = { string.rep("x", 65) }
			end,
			function(s)
				for index = 1, ShopConfig.MaxSaveReceipts + 1 do
					s.purchases.receipts[index] = "receipt-" .. index
				end
			end,
			function(s)
				s.purchases.owned.CashPinecone = 0
			end,
			function(s)
				s.purchases.owned["bad key"] = 1
			end,
			function(s)
				s.purchases.boosts.CashX2 = ShopConfig.BoostCapSeconds + 1
			end,
			function(s)
				s.purchases.boosts.Other = 0
			end,
			function(s)
				s.purchases = nil
			end,
		}
		for _, mutate in ipairs(mutations) do
			local broken = fresh()
			mutate(broken)
			expect.falsy(Purchases.isValid(broken))
			expect.falsy(BusinessState.validate(broken))
		end
	end)

	t.test("applies a grant once per purchase id", function()
		local state = fresh()
		local cash, reputation = state.cash, state.reputation
		local starter = ShopConfig.byKey("StarterPack") :: any
		expect.falsy(Purchases.hasReceipt(state, "receipt-1"))
		local applied = Purchases.apply(state, starter, "receipt-1")
		expect.equal(applied.cash, 20000)
		expect.equal(applied.reputation, 750)
		expect.equal(state.cash, cash + 20000)
		expect.equal(state.reputation, reputation + 750)
		expect.equal(state.purchases.owned.StarterPack, 1)
		expect.truthy(Purchases.hasReceipt(state, "receipt-1"))
		expect.falsy(Purchases.hasReceipt(state, "receipt-2"))
		expect.truthy(BusinessState.validate(state))
	end)

	t.test("caps boost time and trims receipts", function()
		local state = fresh()
		local boost = ShopConfig.byKey("BoostCashX2") :: any
		for index = 1, 13 do
			Purchases.apply(state, boost, "boost-" .. index)
		end
		expect.equal(state.purchases.boosts.CashX2, ShopConfig.BoostCapSeconds)
		local last = Purchases.apply(state, boost, "boost-14")
		expect.equal(last.boostSeconds, 0)
		expect.equal(state.purchases.boosts.CashX2, 21600)
		for index = 1, ShopConfig.MaxSaveReceipts + 5 do
			table.insert(state.purchases.receipts, "extra-" .. index)
		end
		state.purchases.boosts.CashX2 = 99999
		Purchases.normalize(state)
		expect.equal(#state.purchases.receipts, 100)
		expect.equal(state.purchases.receipts[100], "extra-" .. (ShopConfig.MaxSaveReceipts + 5))
		-- 14 boost receipts + 105 extra: the 19 oldest (boost-1..14, extra-1..5) are dropped.
		expect.equal(state.purchases.receipts[1], "extra-6")
		expect.equal(state.purchases.boosts.CashX2, 21600)
		expect.truthy(Purchases.isValid(state))
	end)

	t.test("fully rests every role", function()
		local state = fresh()
		for _, role in ipairs(GameConfig.Staff.Roles) do
			state.staffEnergy[role] = 10
		end
		local applied = Purchases.apply(state, ShopConfig.byKey("BoostRested") :: any, "rest-1")
		expect.truthy(applied.rested)
		for _, role in ipairs(GameConfig.Staff.Roles) do
			expect.equal(state.staffEnergy[role], 100)
		end
	end)

	t.test("stores products without an effect as owned only", function()
		local state = fresh()
		local cash, reputation = state.cash, state.reputation
		local applied = Purchases.apply(state, ShopConfig.byKey("DecorSnowGlobe") :: any, "decor-1")
		expect.equal(applied.cash, 0)
		expect.equal(applied.reputation, 0)
		expect.equal(state.cash, cash)
		expect.equal(state.reputation, reputation)
		expect.equal(state.purchases.owned.DecorSnowGlobe, 1)
		expect.truthy(BusinessState.validate(state))
	end)

	t.test("multiplies sale cash by pass and boost", function()
		local state = fresh()
		local pass = { cashX2 = true, reputationX2 = false, instantDelivery = false, vip = false }
		expect.equal(Purchases.cashMultiplier(state, Purchases.NO_PERKS), 1)
		expect.equal(Purchases.cashMultiplier(state, pass), 2)
		state.purchases.boosts.CashX2 = 7
		expect.equal(Purchases.cashMultiplier(state, Purchases.NO_PERKS), 2)
		expect.equal(Purchases.cashMultiplier(state, pass), 4)
		Purchases.tick(state, 5)
		expect.equal(state.purchases.boosts.CashX2, 2)
		Purchases.tick(state, 5)
		expect.equal(state.purchases.boosts.CashX2, 0)
		expect.equal(Purchases.cashMultiplier(state, Purchases.NO_PERKS), 1)
	end)
end

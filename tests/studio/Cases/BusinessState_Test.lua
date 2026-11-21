--!strict
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local Inventory = require(Shared:WaitForChild("Inventory"))
	local expect = t.expect
	-- A purchase derives cost from the server catalog, not caller input.
	t.test("charges server configured wholesale price", function()
		local state = BusinessState.new()
		local ok, cost = BusinessState.buyStock(state, "FrasierFir", "Medium", 2)
		expect.truthy(ok)
		expect.equal(cost, 64)
		expect.equal(state.cash, 20)
		expect.equal(Inventory.count(state.stock, Inventory.key("FrasierFir", "Medium")), 2)
	end)
	-- A rejected purchase leaves cash and stock unchanged.
	t.test("does not partially mutate unaffordable order", function()
		local state = BusinessState.new()
		local beforeCash = state.cash
		local ok, reason = BusinessState.buyStock(state, "BlueSpruce", "Large", 2)
		expect.falsy(ok)
		expect.equal(reason, "InsufficientFunds")
		expect.equal(state.cash, beforeCash)
		expect.equal(Inventory.count(state.stock, Inventory.key("BlueSpruce", "Large")), 0)
	end)
	-- A v1 save retains all financial state while gaining v2 ownership fields.
	t.test("migrates legacy state without losing balances", function()
		local legacy = BusinessState.new()
		legacy.schemaVersion = 1
		legacy.companyId = nil
		legacy.ownerUserId = nil
		legacy.mode = nil
		legacy.members = nil
		legacy.revision = nil
		legacy.recentRequests = nil
		legacy.updatedAt = nil
		local migrated, reason = BusinessState.migrate(legacy, "personal:42", 42)
		expect.truthy(migrated)
		expect.equal(reason, nil)
		expect.equal(migrated.cash, 84)
		expect.equal(migrated.companyId, "personal:42")
		expect.equal(migrated.members["42"], "Owner")
	end)

	-- Existing v4 records reach the current schema without losing balances.
	t.test("migrates v4 state to current schema", function()
		local legacy = BusinessState.new("personal:42", 42)
		legacy.schemaVersion = 4
		legacy.reservations = nil
		local migrated = BusinessState.migrate(legacy, "personal:42", 42)
		expect.truthy(migrated)
		expect.equal(migrated.schemaVersion, BusinessState.SCHEMA_VERSION)
		expect.equal(migrated.cash, 84)
		expect.truthy(migrated.reservations)
		expect.truthy(migrated.questClaims)
	end)

	-- The latest migration must preserve all established persisted domains.
	t.test("migrates v8 records without losing company domains", function()
		local legacy = BusinessState.new("personal:42", 42)
		legacy.schemaVersion = 8
		legacy.questClaims = nil
		legacy.stock[Inventory.key("NobleFir", "Large")] = 2
		legacy.pendingOrders = {
			order_legacy = { orderId = "order_legacy", speciesId = "NobleFir", sizeId = "Large", quantity = 2 },
		}
		legacy.mediumPrices.NobleFir = 111
		legacy.progression.lotExpansion = 2
		legacy.customerVisits = 12
		legacy.revenue = 456

		local migrated = BusinessState.migrate(legacy, "personal:42", 42)
		expect.truthy(migrated)
		expect.equal(migrated.schemaVersion, BusinessState.SCHEMA_VERSION)
		expect.equal(Inventory.count(migrated.stock, Inventory.key("NobleFir", "Large")), 2)
		expect.truthy(migrated.pendingOrders.order_legacy)
		expect.equal(migrated.mediumPrices.NobleFir, 111)
		expect.equal(migrated.progression.lotExpansion, 2)
		expect.equal(migrated.customerVisits, 12)
		expect.equal(migrated.revenue, 456)
		expect.truthy(migrated.questClaims)
	end)

	-- validate() requires visits >= sales, so the v7 -> v8 step must not reset visits to 0.
	t.test("migrates pre-analytics records that already have sales", function()
		local legacy = BusinessState.new("personal:42", 42)
		legacy.schemaVersion = 7
		legacy.questClaims = nil
		legacy.customerVisits = nil
		legacy.abandonedCustomers = nil
		legacy.sales = 12
		legacy.revenue = 900
		local migrated, reason = BusinessState.migrate(legacy, "personal:42", 42)
		expect.truthy(migrated)
		expect.equal(reason, nil)
		expect.equal(migrated.sales, 12)
		expect.equal(migrated.customerVisits, 12)
	end)

	t.test("restores missing medium prices during migration", function()
		local legacy = BusinessState.new("personal:42", 42)
		legacy.schemaVersion = 8
		legacy.questClaims = nil
		legacy.mediumPrices = { FrasierFir = 90 }
		local migrated = BusinessState.migrate(legacy, "personal:42", 42)
		expect.truthy(migrated)
		expect.equal(migrated.mediumPrices.FrasierFir, 90)
		expect.equal(migrated.mediumPrices.NobleFir, 96)
	end)

	t.test("prunes completed orders when loading the current schema", function()
		local state = BusinessState.new("personal:42", 42)
		state.pendingOrders["order:old"] = { status = "Unloaded" }
		state.pendingOrders["order:open"] = { status = "Pending" }
		local migrated, reason = BusinessState.migrate(state, "personal:42", 42)
		expect.truthy(migrated)
		expect.equal(reason, nil)
		expect.equal(migrated.pendingOrders["order:old"], nil)
		expect.truthy(migrated.pendingOrders["order:open"])
	end)

	t.test("rejects impossible employee counts", function()
		local state = BusinessState.new("personal:42", 42)
		state.staff.Cashier = 2
		expect.falsy(BusinessState.validate(state))
	end)
end

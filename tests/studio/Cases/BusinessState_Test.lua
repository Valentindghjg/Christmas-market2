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

	-- Existing v4 records gain empty checkout reservations without balance changes.
	t.test("migrates v4 state to reservation schema", function()
		local legacy = BusinessState.new("personal:42", 42)
		legacy.schemaVersion = 4
		legacy.reservations = nil
		local migrated = BusinessState.migrate(legacy, "personal:42", 42)
		expect.truthy(migrated)
		expect.equal(migrated.schemaVersion, 5)
		expect.equal(migrated.cash, 84)
		expect.truthy(migrated.reservations)
	end)

	t.test("rejects impossible employee counts", function()
		local state = BusinessState.new("personal:42", 42)
		state.staff.Cashier = 2
		expect.falsy(BusinessState.validate(state))
	end)
end

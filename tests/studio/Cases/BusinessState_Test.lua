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
	t.test("migrates v9 records to schema 10 with customer orders and supplier stock", function()
		local legacy = BusinessState.new("personal:42", 42)
		legacy.schemaVersion = 9
		legacy.customerOrders = nil
		legacy.nextOrderNumber = nil
		legacy.loadedOrders = nil
		legacy.missedPickups = nil
		legacy.drivePastCustomers = nil
		legacy.supplier = nil
		legacy.cash = 1234
		local migrated, reason = BusinessState.migrate(legacy, "personal:42", 42)
		expect.truthy(migrated)
		expect.equal(reason, nil)
		expect.equal(migrated.schemaVersion, BusinessState.SCHEMA_VERSION)
		expect.equal(migrated.cash, 1234)
		expect.equal(migrated.nextOrderNumber, 1)
		expect.truthy(migrated.supplier.stock["FrasierFir:Medium"] > 0)
	end)

	-- CM2-S1: schema 11 adds the save name and size without touching balances.
	t.test("migrates v10 to v11 with a save name and Solo size", function()
		local legacy = BusinessState.new("personal:42", 42)
		legacy.schemaVersion = 10
		legacy.saveName = nil
		legacy.saveSize = nil
		legacy.cash = 777
		legacy.reputation = 120
		legacy.stock["NobleFir:Small"] = 4
		local migrated, reason = BusinessState.migrate(legacy, "personal:42", 42)
		expect.truthy(migrated)
		expect.equal(reason, nil)
		expect.equal(BusinessState.SCHEMA_VERSION, 12)
		expect.equal(migrated.schemaVersion, 12)
		expect.equal(migrated.cash, 777)
		expect.equal(migrated.reputation, 120)
		expect.equal(migrated.stock["NobleFir:Small"], 4)
		expect.equal(migrated.saveName, "Tree Lot 1")
		expect.equal(migrated.saveSize, "Solo")
	end)

	t.test("rejects an invalid save name or size", function()
		local tooLong = BusinessState.new("save:42_x", 42)
		tooLong.saveName = string.rep("ä", 25)
		expect.falsy(BusinessState.validate(tooLong))
		local empty = BusinessState.new("save:42_x", 42)
		empty.saveName = ""
		expect.falsy(BusinessState.validate(empty))
		local huge = BusinessState.new("save:42_x", 42)
		huge.saveSize = "Huge"
		expect.falsy(BusinessState.validate(huge))
		local named = BusinessState.new("save:42_x", 42, string.rep("ä", 24))
		expect.truthy(BusinessState.validate(named))
	end)

	t.test("rejects a corrupt customer order", function()
		local state = BusinessState.new("personal:42", 42)
		state.customerOrders["5"] = { orderNumber = 5 }
		expect.falsy(BusinessState.validate(state))
	end)

	-- CM2-S2: schema 12 member map and invite codes.
	t.test("migrates v11 to v12 with an owner-only member map", function()
		local SaveProfile = require(Shared:WaitForChild("SaveProfile"))
		local legacy = BusinessState.new("save:42_x", 42)
		legacy.schemaVersion = 11
		legacy.members = { ["42"] = "Owner", ["7"] = "Manager" }
		legacy.inviteCode = "12345"
		legacy.cash = 555
		local migrated, reason = BusinessState.migrate(legacy, "save:42_x", 42)
		expect.truthy(migrated)
		expect.equal(reason, nil)
		expect.equal(migrated.schemaVersion, 12)
		expect.equal(migrated.members["42"], "Owner")
		expect.equal(migrated.members["7"], nil)
		expect.equal(BusinessState.memberCount(migrated), 1)
		expect.equal(migrated.inviteCode, nil)
		expect.equal(migrated.cash, 555)
		local bigOwner = 9223372036854774784
		local big = BusinessState.new("save:big", bigOwner)
		big.schemaVersion = 11
		big.members = { [tostring(bigOwner)] = "Owner" }
		local bigMigrated = BusinessState.migrate(big, "save:big", bigOwner)
		expect.truthy(bigMigrated)
		expect.equal(bigMigrated.members[SaveProfile.userIdText(bigOwner)], "Owner")
		expect.equal(SaveProfile.userIdText(bigOwner), "9223372036854774784")
	end)

	t.test("validates members, seats and invite codes", function()
		local function duo()
			local state = BusinessState.new("save:42_x", 42)
			state.saveSize = "Duo"
			return state
		end
		local two = duo()
		two.members["43"] = "Member"
		expect.truthy(BusinessState.validate(two))
		local three = duo()
		three.members["43"] = "Member"
		three.members["44"] = "Member"
		expect.falsy(BusinessState.validate(three))
		local twoOwners = duo()
		twoOwners.members["43"] = "Owner"
		expect.falsy(BusinessState.validate(twoOwners))
		local visitor = duo()
		visitor.members["43"] = "Visitor"
		expect.falsy(BusinessState.validate(visitor))
		local badKey = duo()
		badKey.members["x1"] = "Member"
		expect.falsy(BusinessState.validate(badKey))
		local soloCode = BusinessState.new("save:42_x", 42)
		soloCode.inviteCode = "12345"
		expect.falsy(BusinessState.validate(soloCode))
		for _, code in { "01234", "1234", "123456" } do
			local bad = duo()
			bad.inviteCode = code
			expect.falsy(BusinessState.validate(bad))
		end
		local good = duo()
		good.inviteCode = "12345"
		expect.truthy(BusinessState.validate(good))
		expect.truthy(BusinessState.isInviteCode("12345"))
		expect.falsy(BusinessState.isInviteCode(12345))
	end)

	t.test("adds members only with the current code and a free seat", function()
		local solo = BusinessState.new("save:42_x", 42)
		local soloOk, soloReason = BusinessState.addMember(solo, 43, "12345")
		expect.falsy(soloOk)
		expect.equal(soloReason, "InviteCodeInvalid")
		local state = BusinessState.new("save:42_x", 42)
		state.saveSize = "Duo"
		state.inviteCode = "12345"
		local wrongOk, wrongReason = BusinessState.addMember(state, 43, "54321")
		expect.falsy(wrongOk)
		expect.equal(wrongReason, "InviteCodeInvalid")
		local joined, joinResult = BusinessState.addMember(state, 43, "12345")
		expect.truthy(joined)
		expect.equal(joinResult.outcome, "Joined")
		expect.equal(joinResult.size, "Duo")
		expect.equal(state.members["43"], "Member")
		local again, againResult = BusinessState.addMember(state, 43, "12345")
		expect.truthy(again)
		expect.equal(againResult.outcome, "AlreadyMember")
		local full, fullReason = BusinessState.addMember(state, 44, "12345")
		expect.falsy(full)
		expect.equal(fullReason, "SaveFull")
		expect.equal(state.members["44"], nil)
		local trusted = BusinessState.new("save:42_y", 42)
		trusted.saveSize = "Trio"
		local trustedOk, trustedResult = BusinessState.addMember(trusted, 44, nil)
		expect.truthy(trustedOk)
		expect.equal(trustedResult.outcome, "Joined")
		expect.truthy(BusinessState.validate(trusted))
	end)

	t.test("removes members and resizes within the member count", function()
		local state = BusinessState.new("save:42_x", 42)
		state.saveSize = "Duo"
		state.inviteCode = "12345"
		state.members["43"] = "Member"
		local ownerOk, ownerReason = BusinessState.removeMember(state, 42)
		expect.falsy(ownerOk)
		expect.equal(ownerReason, "OwnerCannotLeave")
		local strangerOk, strangerReason = BusinessState.removeMember(state, 99)
		expect.falsy(strangerOk)
		expect.equal(strangerReason, "NotAMember")
		local tooSmall, tooSmallReason = BusinessState.setSaveSize(state, "Solo")
		expect.falsy(tooSmall)
		expect.equal(tooSmallReason, "SizeTooSmall")
		expect.equal(state.inviteCode, "12345")
		expect.truthy(BusinessState.removeMember(state, 43))
		expect.equal(state.members["43"], nil)
		local same, sameCode = BusinessState.setSaveSize(state, "Duo")
		expect.truthy(same)
		expect.equal(sameCode, nil)
		local solo, oldCode = BusinessState.setSaveSize(state, "Solo")
		expect.truthy(solo)
		expect.equal(oldCode, "12345")
		expect.equal(state.inviteCode, nil)
		expect.equal(state.saveSize, "Solo")
		expect.truthy(BusinessState.validate(state))
		local huge, hugeReason = BusinessState.setSaveSize(state, "Huge")
		expect.falsy(huge)
		expect.equal(hugeReason, "InvalidSize")
		local soloCode, soloCodeReason = BusinessState.setInviteCode(state, "12345", nil)
		expect.falsy(soloCode)
		expect.equal(soloCodeReason, "SoloHasNoCode")
		state.saveSize = "Duo"
		local changed, changedReason = BusinessState.setInviteCode(state, "12345", "99999")
		expect.falsy(changed)
		expect.equal(changedReason, "CodeChanged")
		expect.truthy(BusinessState.setInviteCode(state, "12345", nil))
		expect.equal(state.inviteCode, "12345")
	end)

	t.test("a new company prices and stocks Douglas Fir", function()
		local GameConfig = require(Shared:WaitForChild("GameConfig"))
		local state = BusinessState.new("personal:42", 42)
		expect.equal(state.mediumPrices.DouglasFir, 72)
		expect.equal(state.supplier.stock["DouglasFir:Small"], GameConfig.Supplier.BaseStock.Small)
		expect.equal(state.supplier.stock["DouglasFir:Medium"], GameConfig.Supplier.BaseStock.Medium)
		expect.equal(state.supplier.stock["DouglasFir:Large"], GameConfig.Supplier.BaseStock.Large)
		expect.truthy(BusinessState.validate(state))
	end)
end

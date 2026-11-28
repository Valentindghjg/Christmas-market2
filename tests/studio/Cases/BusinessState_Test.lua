--!strict
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local QuestBoard = require(Shared:WaitForChild("QuestBoard"))
	local Receiving = require(Shared:WaitForChild("Receiving"))
	local expect = t.expect
	-- A purchase derives cost from the server catalog, not caller input.
	t.test("charges server configured wholesale price", function()
		local state = BusinessState.new()
		local ok, order = BusinessState.placeOrder(state, "charge_0001", "FrasierFir", "Medium", 2, 100)
		expect.truthy(ok)
		expect.equal(order.cost, 64)
		expect.equal(state.cash, 20)
		BusinessState.reconcileDeliveries(state, 100 + GameConfig.DeliverySeconds)
		expect.equal(state.bays[order.bay].speciesId, "FrasierFir")
		expect.equal(state.bays[order.bay].counts.Medium, 2)
	end)
	-- A rejected purchase leaves cash and the bays unchanged.
	t.test("does not partially mutate unaffordable order", function()
		local state = BusinessState.new()
		local beforeCash = state.cash
		local ok, reason = BusinessState.placeOrder(state, "unafford_01", "BlueSpruce", "Large", 2, 100)
		expect.falsy(ok)
		expect.equal(reason, "InsufficientFunds")
		expect.equal(state.cash, beforeCash)
		expect.equal(Receiving.count(state, "BlueSpruce", "Large"), 0)
		expect.equal(state.bays[1].speciesId, "")
		expect.equal(next(state.pendingOrders), nil)
	end)
	-- A v1 save retains all financial state while gaining v2 ownership fields.
	t.test("migrates legacy state without losing balances", function()
		local legacy = BusinessState.new()
		legacy.stock = {}
		legacy.bays = nil
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
		expect.equal(migrated.questClaims, nil)
		expect.truthy(QuestBoard.isValid(migrated.quests))
	end)

	-- The latest migration must preserve all established persisted domains.
	t.test("migrates v8 records without losing company domains", function()
		local legacy = BusinessState.new("personal:42", 42)
		legacy.schemaVersion = 8
		legacy.questClaims = nil
		legacy.bays = nil
		legacy.stock = { ["NobleFir:Large"] = 2 }
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
		expect.equal(migrated.stock, nil)
		expect.equal(migrated.bays[1].speciesId, "NobleFir")
		expect.equal(migrated.bays[1].counts.Large, 2)
		expect.truthy(migrated.pendingOrders.order_legacy)
		expect.equal(migrated.mediumPrices.NobleFir, 111)
		expect.equal(migrated.progression.lotExpansion, 2)
		expect.equal(migrated.customerVisits, 12)
		expect.equal(migrated.revenue, 456)
		expect.equal(migrated.questClaims, nil)
		expect.truthy(QuestBoard.isValid(migrated.quests))
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
		expect.equal(migrated.mediumPrices.NobleFir, 184)
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

	-- CM2-N1: no walking customer survives a reload, so neither does a reservation.
	t.test("a reload clears reservations", function()
		local state = BusinessState.new("personal:42", 42)
		state.layout.placements.fir = {
			speciesId = "FrasierFir",
			sizeId = "Medium",
			transform = { x = 0, y = 0, z = 0, rotation = 0 },
		}
		state.reservations.fir = { customerId = "visit:3", expiresAt = 500, salePrice = 160 }
		local migrated = BusinessState.migrate(state, "personal:42", 42)
		expect.truthy(migrated)
		expect.equal(next(migrated.reservations), nil)
		expect.truthy(migrated.layout.placements.fir)
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
		legacy.bays = nil
		legacy.stock = { ["NobleFir:Small"] = 4 }
		local migrated, reason = BusinessState.migrate(legacy, "personal:42", 42)
		expect.truthy(migrated)
		expect.equal(reason, nil)
		expect.equal(BusinessState.SCHEMA_VERSION, 24)
		expect.equal(migrated.schemaVersion, BusinessState.SCHEMA_VERSION)
		expect.equal(migrated.cash, 777)
		expect.equal(migrated.reputation, 120)
		expect.equal(migrated.bays[1].speciesId, "NobleFir")
		expect.equal(migrated.bays[1].counts.Small, 4)
		expect.equal(migrated.saveName, "Tree Lot 1")
		expect.equal(migrated.saveSize, "Solo")
	end)

	-- CM2-G9a: schema 19 replaces parkingSpaces and hqTier with parkingTier and hqLevel.
	t.test("migrates schema 18 records to 19", function()
		local legacy = BusinessState.new("save:42_x", 42)
		legacy.schemaVersion = 18
		legacy.progression = { lotExpansion = 2, parkingSpaces = 3, hqTier = "ChristmasPavilion" }
		legacy.cash = 4321
		local migrated, reason = BusinessState.migrate(legacy, "save:42_x", 42)
		expect.truthy(migrated)
		expect.equal(reason, nil)
		expect.equal(migrated.schemaVersion, 24)
		expect.equal(migrated.progression.lotExpansion, 2)
		expect.equal(migrated.progression.parkingTier, 4) -- old tier 2 -> 4 (the chain runs on to 24)
		expect.equal(migrated.progression.hqLevel, 2)
		expect.equal(migrated.progression.parkingSpaces, nil)
		expect.equal(migrated.progression.hqTier, nil)
		expect.equal(migrated.cash, 4321)
		expect.truthy(BusinessState.validate(migrated))
		local broken = BusinessState.new("save:42_x", 42)
		broken.progression.hqLevel = 5
		expect.falsy(BusinessState.validate(broken))
		broken.progression = { lotExpansion = 7, parkingTier = 1, hqLevel = 1 }
		expect.falsy(BusinessState.validate(broken))
	end)

	-- CM2-G11: schema 21 replaces the scaffold quest claims with the rotating quest board.
	t.test("migrates schema 20 records to 21", function()
		local legacy = BusinessState.new("save:42_x", 42)
		legacy.schemaVersion = 20
		legacy.quests = nil
		legacy.questClaims = { FirstSale = true }
		legacy.cash = 2468
		local migrated, reason = BusinessState.migrate(legacy, "save:42_x", 42)
		expect.truthy(migrated)
		expect.equal(reason, nil)
		expect.equal(BusinessState.SCHEMA_VERSION, 24)
		expect.equal(migrated.schemaVersion, 24)
		expect.equal(migrated.questClaims, nil)
		expect.truthy(QuestBoard.isValid(migrated.quests))
		expect.equal(migrated.quests.period, 0)
		expect.equal(migrated.cash, 2468)
		expect.truthy(BusinessState.validate(migrated))
	end)

	-- CM2-A1: schema 22 adds the decor crate filled by the Advent calendar.
	t.test("migrates schema 21 to 22 with an empty decor inventory", function()
		local legacy = BusinessState.new("save:42_x", 42)
		legacy.schemaVersion = 21
		legacy.decorInventory = nil
		legacy.cash = 1357
		local migrated, reason = BusinessState.migrate(legacy, "save:42_x", 42)
		expect.truthy(migrated)
		expect.equal(reason, nil)
		expect.equal(migrated.schemaVersion, 24)
		expect.equal(type(migrated.decorInventory), "table")
		expect.equal(next(migrated.decorInventory), nil)
		expect.equal(migrated.cash, 1357)
		expect.truthy(BusinessState.validate(migrated))
	end)

	t.test("rejects a bad decor inventory", function()
		local unknown = BusinessState.new("save:42_x", 42)
		unknown.decorInventory = { Nope = 1 }
		expect.falsy(BusinessState.validate(unknown))
		local zero = BusinessState.new("save:42_x", 42)
		zero.decorInventory = { AdventWreath = 0 }
		expect.falsy(BusinessState.validate(zero))
		local fine = BusinessState.new("save:42_x", 42)
		fine.decorInventory = { AdventWreath = 1 }
		expect.truthy(BusinessState.validate(fine))
	end)

	-- CM2-45: schema 23 adds the event shop purchases per save.
	t.test("migrates schema 22 to 23 with empty event purchases", function()
		local legacy = BusinessState.new("save:42_x", 42)
		legacy.schemaVersion = 22
		legacy.eventPurchases = nil
		legacy.cash = 2468
		local migrated, reason = BusinessState.migrate(legacy, "save:42_x", 42)
		expect.truthy(migrated)
		expect.equal(reason, nil)
		expect.equal(migrated.schemaVersion, 24)
		expect.equal(type(migrated.eventPurchases), "table")
		expect.equal(next(migrated.eventPurchases), nil)
		expect.equal(migrated.cash, 2468)
		expect.truthy(BusinessState.validate(migrated))
	end)

	-- CM2-PARK: schema 24 maps the old parking tiers 1 and 2 (2 and 4 spaces) to 2 and 4.
	t.test("migrates schema 23 records to 24", function()
		local Orders = require(
			game:GetService("ServerScriptService")
				:WaitForChild("Server")
				:WaitForChild("Services")
				:WaitForChild("CustomerOrderService")
		)
		for _, case in { { old = 1, new = 2, space = 2 }, { old = 2, new = 4, space = 4 } } do
			local legacy = BusinessState.new("save:42_x", 42)
			legacy.progression.parkingTier = case.new
			local sale = { placementId = "placement:a", speciesId = "FrasierFir", sizeId = "Medium", salePrice = 82 }
			local created, order = Orders.createFromSale(legacy, sale, 100, case.space)
			expect.truthy(created)
			expect.equal(order.parkingSpace, case.space)
			legacy.schemaVersion = 23
			legacy.progression.parkingTier = case.old
			legacy.cash = 3579
			legacy.spent = 1200
			local historyLength = #legacy.history
			local migrated, reason = BusinessState.migrate(legacy, "save:42_x", 42)
			expect.truthy(migrated)
			expect.equal(reason, nil)
			expect.equal(migrated.schemaVersion, 24)
			expect.equal(migrated.progression.parkingTier, case.new)
			expect.equal(migrated.customerOrders[tostring(order.orderNumber)].parkingSpace, case.space)
			expect.equal(migrated.cash, 3579)
			expect.equal(migrated.spent, 1200)
			expect.equal(#migrated.history, historyLength)
			expect.truthy(BusinessState.validate(migrated))
			local again = BusinessState.migrate(migrated, "save:42_x", 42)
			expect.truthy(again)
			expect.equal(again.progression.parkingTier, case.new)
		end
	end)

	t.test("a fresh v24 save starts at tier 1 and round-trips", function()
		local Progression = require(Shared:WaitForChild("Progression"))
		local fresh = BusinessState.new("save:42_x", 42)
		expect.equal(fresh.schemaVersion, 24)
		expect.equal(fresh.progression.parkingTier, 1)
		expect.equal(Progression.parkingSpaces(fresh), 1)
		local copy = BusinessState.new("save:42_x", 42)
		copy.progression.parkingTier = 3
		local migrated = BusinessState.migrate(copy, "save:42_x", 42)
		expect.truthy(migrated)
		expect.equal(migrated.progression.parkingTier, 3)
		expect.truthy(BusinessState.validate(migrated))
	end)

	t.test("rejects bad event purchases", function()
		local zero = BusinessState.new("save:42_x", 42)
		zero.eventPurchases = { Advent1 = { CandlelightPack = 0 } }
		expect.falsy(BusinessState.validate(zero))
		local flat = BusinessState.new("save:42_x", 42)
		flat.eventPurchases = { Advent1 = 1 }
		expect.falsy(BusinessState.validate(flat))
		local fine = BusinessState.new("save:42_x", 42)
		fine.eventPurchases = { Advent1 = { CandlelightPack = 1 } }
		expect.truthy(BusinessState.validate(fine))
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
		expect.equal(migrated.schemaVersion, BusinessState.SCHEMA_VERSION)
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
		local state = BusinessState.new("personal:42", 42)
		expect.equal(state.mediumPrices.DouglasFir, 140)
		expect.equal(state.supplier.stock["DouglasFir:Small"], GameConfig.Supplier.BaseStock.Small)
		expect.equal(state.supplier.stock["DouglasFir:Medium"], GameConfig.Supplier.BaseStock.Medium)
		expect.equal(state.supplier.stock["DouglasFir:Large"], GameConfig.Supplier.BaseStock.Large)
		expect.truthy(BusinessState.validate(state))
	end)

	-- CM2-G14 (STK-04): stored stock and orders move into 4 bays; what does not fit is refunded.
	t.test("migrates v12 to v13 into bays and refunds overflow", function()
		local legacy = BusinessState.new("save:42_x", 42)
		legacy.schemaVersion = 12
		legacy.bays = nil
		legacy.cash = 1000
		legacy.stock = {
			["DouglasFir:Medium"] = 12,
			["FrasierFir:Small"] = 3,
			["NobleFir:Large"] = 1,
			["BlueSpruce:Medium"] = 9,
		}
		legacy.pendingOrders = {
			["order:delivered_1"] = {
				orderId = "order:delivered_1",
				requestId = "delivered_1",
				speciesId = "FrasierFir",
				sizeId = "Small",
				quantity = 1,
				createdAt = 10,
				dueAt = 70,
				status = "Delivered",
			},
			["order:pending_01"] = {
				orderId = "order:pending_01",
				requestId = "pending_01",
				speciesId = "NobleFir",
				sizeId = "Small",
				quantity = 2,
				createdAt = 20,
				dueAt = 80,
				status = "Pending",
			},
		}
		local migrated, reason = BusinessState.migrate(legacy, "save:42_x", 42)
		expect.equal(reason, nil)
		expect.truthy(migrated)
		local expected = {
			{ "DouglasFir", "Medium", 9 },
			{ "DouglasFir", "Medium", 3 },
			{ "FrasierFir", "Small", 4 },
			{ "NobleFir", "Large", 1 },
		}
		for index, bay in ipairs(expected) do
			expect.equal(migrated.bays[index].speciesId, bay[1])
			expect.equal(migrated.bays[index].counts[bay[2]], bay[3])
			local keys = 0
			for _ in pairs(migrated.bays[index].counts) do
				keys += 1
			end
			expect.equal(keys, 1)
		end
		-- 9 Blue Spruce Medium x 42 = 378 and the pending order 2 x Noble Small 28 = 56.
		expect.equal(migrated.cash, 1000 + 434)
		local last = migrated.history[#migrated.history]
		expect.equal(last.kind, "MigrationRefund")
		expect.equal(last.amount, 434)
		expect.equal(next(migrated.pendingOrders), nil)
		expect.equal(migrated.stock, nil)
		expect.equal(migrated.schemaVersion, BusinessState.SCHEMA_VERSION)
		expect.truthy(BusinessState.validate(migrated))
	end)

	-- CM2-N2: schema 14 adds the walk-out counter without touching balances.
	t.test("migrates v13 to v14 with a walk-out counter", function()
		local legacy = BusinessState.new("save:42_x", 42)
		legacy.schemaVersion = 13
		legacy.walkedOutCustomers = nil
		legacy.cash = 777
		legacy.abandonedCustomers = 3
		local migrated, reason = BusinessState.migrate(legacy, "save:42_x", 42)
		expect.truthy(migrated)
		expect.equal(reason, nil)
		expect.equal(migrated.schemaVersion, BusinessState.SCHEMA_VERSION)
		expect.equal(migrated.walkedOutCustomers, 0)
		expect.equal(migrated.cash, 777)
		expect.equal(migrated.abandonedCustomers, 3)
		expect.truthy(BusinessState.validate(migrated))
	end)

	t.test("rejects an invalid walk-out counter", function()
		for _, value in ipairs({ -1, 1.5 }) do
			local state = BusinessState.new("save:42_x", 42)
			state.walkedOutCustomers = value
			expect.falsy(BusinessState.validate(state))
		end
		local missing = BusinessState.new("save:42_x", 42)
		missing.walkedOutCustomers = nil
		expect.falsy(BusinessState.validate(missing))
	end)

	-- CM2-G15: schema 15 adds reviews, likes and the queue time of open orders.
	local function openOrder(queueSeconds: number?)
		return {
			orderNumber = 1,
			speciesId = "FrasierFir",
			sizeId = "Small",
			heightTenths = 55,
			salePrice = 66,
			soldAt = 100,
			expiresAt = 220,
			parkingSpace = 1,
			queueSeconds = queueSeconds,
		}
	end

	t.test("migrates v14 to v15 with reviews, likes and queue time", function()
		local legacy = BusinessState.new("save:42_x", 42)
		legacy.schemaVersion = 14
		legacy.reviews = nil
		legacy.likes = nil
		legacy.cash = 777
		legacy.customerOrders["1"] = openOrder(nil)
		legacy.nextOrderNumber = 2
		local migrated, reason = BusinessState.migrate(legacy, "save:42_x", 42)
		expect.truthy(migrated)
		expect.equal(reason, nil)
		expect.equal(migrated.schemaVersion, BusinessState.SCHEMA_VERSION)
		expect.equal(migrated.reviews.count, 0)
		expect.equal(#migrated.reviews.recent, 0)
		expect.equal(migrated.likes.total, 0)
		expect.equal(migrated.likes.day, 0)
		expect.equal(next(migrated.likes.today), nil)
		expect.equal(migrated.customerOrders["1"].queueSeconds, 0)
		expect.equal(migrated.cash, 777)
		expect.truthy(BusinessState.validate(migrated))
	end)

	t.test("rejects invalid reviews and likes", function()
		local mutations = {
			function(state)
				state.reviews.recent = { 6 }
				state.reviews.count = 1
			end,
			function(state)
				local recent = {}
				for index = 1, GameConfig.Reviews.RatingWindow + 1 do
					recent[index] = 5
				end
				state.reviews.recent = recent
				state.reviews.count = #recent
			end,
			function(state)
				state.likes.total = -1
			end,
			function(state)
				state.likes.today = { abc = true }
			end,
			function(state)
				state.customerOrders["1"] = openOrder(-1)
				state.nextOrderNumber = 2
			end,
		}
		local valid = BusinessState.new("save:42_x", 42)
		valid.customerOrders["1"] = openOrder(0)
		valid.nextOrderNumber = 2
		expect.truthy(BusinessState.validate(valid))
		for _, mutate in ipairs(mutations) do
			local state = BusinessState.new("save:42_x", 42)
			mutate(state)
			expect.falsy(BusinessState.validate(state))
		end
	end)

	-- CM2-25/26: schema 16 adds the Lot Manager slot, staff energy and the break area.
	t.test("migrates v15 to v16 with staff energy and a break area", function()
		local legacy = BusinessState.new("save:42_x", 42)
		legacy.schemaVersion = 15
		legacy.staff = { Cashier = 1, LotWorker = 0 }
		legacy.staffEnergy = nil
		legacy.breakArea = nil
		legacy.cash = 777
		legacy.reputation = 120
		legacy.spent = 1200
		-- A tree on candidate 1 moves the default break area to candidate 2.
		legacy.layout.placements.blocker = {
			speciesId = "DouglasFir",
			sizeId = "Medium",
			transform = { x = -32, y = 0, z = -20, rotation = 0 },
		}
		local migrated, reason = BusinessState.migrate(legacy, "save:42_x", 42)
		expect.truthy(migrated)
		expect.equal(reason, nil)
		expect.equal(migrated.schemaVersion, BusinessState.SCHEMA_VERSION)
		expect.equal(migrated.staff.Cashier, 1)
		expect.equal(migrated.staff.LotWorker, 0)
		expect.equal(migrated.staff.LotManager, 0)
		for _, role in ipairs(GameConfig.Staff.Roles) do
			expect.equal(migrated.staffEnergy[role], 100)
		end
		local second = GameConfig.Staff.BreakArea.Candidates[2]
		expect.equal(migrated.breakArea.x, second.x)
		expect.equal(migrated.breakArea.z, second.z)
		expect.equal(migrated.breakArea.rotation, 0)
		expect.equal(migrated.cash, 777)
		expect.equal(migrated.reputation, 120)
		expect.equal(migrated.spent, 1200)
		expect.truthy(BusinessState.validate(migrated))
		local fresh = BusinessState.new("save:42_y", 42)
		expect.equal(fresh.staff.LotManager, 0)
		expect.equal(fresh.staffEnergy.LotWorker, 100)
		expect.equal(fresh.breakArea.x, GameConfig.Staff.BreakArea.Candidates[1].x)
		expect.truthy(BusinessState.validate(fresh))
	end)

	t.test("rejects invalid staff energy, break area and Lot Manager count", function()
		local mutations = {
			function(state)
				state.staffEnergy.Cashier = 101
			end,
			function(state)
				state.staffEnergy.LotWorker = 0 / 0
			end,
			function(state)
				state.staffEnergy.LotManager = 50.5
			end,
			function(state)
				state.staffEnergy = nil
			end,
			function(state)
				state.breakArea.rotation = 45
			end,
			function(state)
				state.breakArea.x = 0 / 0
			end,
			function(state)
				state.breakArea.z = GameConfig.Placement.CoordinateLimit + 1
			end,
			function(state)
				state.breakArea = nil
			end,
			function(state)
				state.staff.LotManager = 2
			end,
			function(state)
				state.staff.LotManager = nil
			end,
		}
		for _, mutate in ipairs(mutations) do
			local state = BusinessState.new("save:42_x", 42)
			expect.truthy(BusinessState.validate(state))
			mutate(state)
			expect.falsy(BusinessState.validate(state))
		end
	end)
end

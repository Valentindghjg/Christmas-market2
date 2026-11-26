--!strict
-- CM2-N1: the server-trusted company transactions of walking customers.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local Service = require(
		game:GetService("ServerScriptService")
			:WaitForChild("Server")
			:WaitForChild("Services")
			:WaitForChild("CompanyStateService")
	)
	local expect = t.expect
	local COMPANY = "save:npc"
	local NOW = 1000
	local Npc = GameConfig.Customers.Npc

	local function fakePersistence()
		local records = {}
		return {
			load = function(_, companyId, ownerUserId)
				records[companyId] = records[companyId] or BusinessState.new(companyId, ownerUserId)
				return records[companyId], nil
			end,
			save = function(_, companyId, state)
				records[companyId] = state
				return true, nil
			end,
			release = function()
				return true, nil
			end,
		}
	end

	local function douglas(state, id: string, x: number)
		state.layout.placements[id] = {
			speciesId = "DouglasFir",
			sizeId = "Medium",
			transform = { x = x, y = 0, z = -20, rotation = 0 },
		}
	end

	-- roll (CM2-SALE1): the service's random roll; 0 when omitted.
	local function setup(trees: number, roll: number?)
		local service = Service.new(fakePersistence(), function()
			return NOW
		end, function()
			return roll or 0
		end)
		local state = service:loadCompany(COMPANY, 42)
		for index = 1, trees do
			douglas(state, "douglas_" .. index, -35 + 7 * index)
		end
		return service, state
	end

	local function claimCount(service): number
		local count = 0
		for _ in pairs(service:npcClaimsForTest(COMPANY)) do
			count += 1
		end
		return count
	end

	t.test("npcArrive claims the lowest space and needs a tree", function()
		local service, state = setup(0)
		local noStock, code = service:npcArrive(COMPANY, "visit:1")
		expect.falsy(noStock)
		expect.equal(code, "NoStock")
		douglas(state, "douglas_1", -28)
		local revision = state.revision
		local first, firstInfo = service:npcArrive(COMPANY, "visit:1")
		expect.truthy(first)
		expect.equal(firstInfo.space, 1)
		expect.equal(firstInfo.token, service:sessionToken(COMPANY))
		local second, secondInfo = service:npcArrive(COMPANY, "visit:2")
		expect.truthy(second)
		expect.equal(secondInfo.space, 2)
		local third, thirdCode = service:npcArrive(COMPANY, "visit:3")
		expect.falsy(third)
		expect.equal(thirdCode, "NoParking")
		expect.equal(state.drivePastCustomers, 1)
		expect.equal(state.revision, revision)
		-- Fix round 1 (F7): the playtest reads the server clock from the snapshot.
		local snapshot = service:snapshotForTest(COMPANY) :: any
		expect.equal(snapshot.clock, NOW)
	end)

	t.test("npcDecide reserves for ReservationSeconds", function()
		local service, state = setup(1)
		local synced = 0
		service:setPlacementsChangedHandler(function()
			synced += 1
		end)
		expect.truthy(service:npcArrive(COMPANY, "visit:1"))
		local revision = state.revision
		local ok, picked = service:npcDecide(COMPANY, "visit:1", 8, 0)
		expect.truthy(ok)
		expect.equal(picked.placementId, "douglas_1")
		expect.equal(picked.sizeId, "Medium")
		expect.equal(picked.speciesId, "DouglasFir")
		expect.equal(picked.x, -28)
		expect.equal(picked.z, -20)
		local reservation = state.reservations.douglas_1
		expect.equal(reservation.customerId, "visit:1")
		expect.equal(Npc.ReservationSeconds, 165)
		expect.equal(reservation.expiresAt, NOW + Npc.ReservationSeconds)
		expect.equal(state.revision, revision + 1)
		expect.equal(synced, 1)
	end)

	t.test("npcDecide failure counts an abandonment", function()
		local service, state = setup(1)
		expect.truthy(service:npcArrive(COMPANY, "visit:1"))
		local visits, abandoned, revision = state.customerVisits, state.abandonedCustomers, state.revision
		-- profile 5's budget (99 %) is below every benchmark price (CM2-SALE2 soft preferences)
		local ok, code = service:npcDecide(COMPANY, "visit:1", 5, 0)
		expect.falsy(ok)
		expect.equal(code, "NoEligibleStock")
		expect.equal(state.customerVisits, visits + 1)
		expect.equal(state.abandonedCustomers, abandoned + 1)
		expect.equal(next(state.reservations), nil)
		expect.equal(state.revision, revision)
	end)

	t.test("npcSettle settles exactly once in the visit's space", function()
		local service, state = setup(1)
		expect.truthy(service:npcArrive(COMPANY, "visit:1"))
		expect.truthy(service:npcArrive(COMPANY, "visit:2"))
		expect.truthy(service:npcDecide(COMPANY, "visit:2", 8, 0))
		local cash, sales = state.cash, state.sales
		local ok, sale = service:npcSettle(COMPANY, "visit:2", "douglas_1")
		expect.truthy(ok)
		expect.equal(sale.order.parkingSpace, 2)
		local claims = service:npcClaimsForTest(COMPANY)
		expect.equal(claims[2], nil)
		expect.equal(claims[1], "visit:1")
		local again, code = service:npcSettle(COMPANY, "visit:2", "douglas_1")
		expect.falsy(again)
		expect.equal(code, "ReservationRequired")
		expect.equal(state.sales, sales + 1)
		expect.equal(state.cash, cash + sale.salePrice)
	end)

	t.test("onSold runs before the orders notification", function()
		local service = setup(1)
		local log = {}
		service:setCustomerOrdersChangedHandler(function()
			table.insert(log, "ordersChanged")
		end)
		expect.truthy(service:npcArrive(COMPANY, "visit:1"))
		expect.truthy(service:npcDecide(COMPANY, "visit:1", 8, 0))
		expect.truthy(service:npcSettle(COMPANY, "visit:1", "douglas_1", function(sale)
			expect.truthy(sale.order)
			table.insert(log, "onSold")
		end))
		expect.equal(#log, 2)
		expect.equal(log[1], "onSold")
		expect.equal(log[2], "ordersChanged")
	end)

	t.test("npcCancel releases the tree once", function()
		local service, state = setup(1)
		expect.truthy(service:npcArrive(COMPANY, "visit:1"))
		expect.truthy(service:npcDecide(COMPANY, "visit:1", 8, 0))
		local abandoned = state.abandonedCustomers
		expect.truthy(service:npcCancel(COMPANY, "visit:1", "douglas_1"))
		expect.equal(state.reservations.douglas_1, nil)
		expect.truthy(state.layout.placements.douglas_1)
		expect.equal(state.abandonedCustomers, abandoned + 1)
		expect.falsy(service:npcCancel(COMPANY, "visit:1", "douglas_1"))
		expect.equal(state.abandonedCustomers, abandoned + 1)
	end)

	-- CM2-N2: a walk-out counts as abandoned and as walked out, once.
	t.test("npcCancel counts a walk-out only when asked", function()
		local service, state = setup(1)
		expect.truthy(service:npcArrive(COMPANY, "visit:1"))
		expect.truthy(service:npcDecide(COMPANY, "visit:1", 8, 0))
		local abandoned, walkedOut = state.abandonedCustomers, state.walkedOutCustomers
		expect.truthy(service:npcCancel(COMPANY, "visit:1", "douglas_1", true))
		expect.equal(state.abandonedCustomers, abandoned + 1)
		expect.equal(state.walkedOutCustomers, walkedOut + 1)
		expect.falsy(service:npcCancel(COMPANY, "visit:1", "douglas_1", true))
		expect.equal(state.abandonedCustomers, abandoned + 1)
		expect.equal(state.walkedOutCustomers, walkedOut + 1)
	end)

	-- CM2-25/26: the staff director's view of a live company.
	t.test("getStaffView follows hires, energy and break area", function()
		local service, state = setup(0)
		local view = service:getStaffView(COMPANY)
		expect.truthy(view ~= nil)
		expect.equal(view.token, service:sessionToken(COMPANY))
		expect.falsy(view.hired.Cashier)
		expect.falsy(view.hired.LotWorker)
		expect.equal(view.hired.LotManager, nil)
		expect.equal(view.energy.Cashier, 100)
		expect.equal(view.breakArea.x, state.breakArea.x)
		expect.equal(view.breakArea.z, state.breakArea.z)
		expect.equal(view.lotExpansion, 0)
		expect.truthy(service:setStaffForTest(COMPANY, "Cashier", 1))
		expect.truthy(service:setStaffEnergy(COMPANY, { Cashier = 42.7, Unknown = 5 }))
		state.breakArea = { x = -32, z = -4, rotation = 90 }
		view = service:getStaffView(COMPANY)
		expect.truthy(view.hired.Cashier)
		expect.equal(view.energy.Cashier, 42)
		expect.equal(view.energy.Unknown, nil)
		expect.equal(view.breakArea.z, -4)
		expect.equal(view.breakArea.rotation, 90)
		-- A detached copy: changing the view changes nothing in the record.
		view.energy.Cashier = 1
		view.breakArea.x = 0
		expect.equal(state.staffEnergy.Cashier, 42)
		expect.equal(state.breakArea.x, -32)
		expect.truthy(service:unloadCompany(COMPANY))
		expect.equal(service:getStaffView(COMPANY), nil)
	end)

	-- CM2-25/26 Amendment 2: the playtest reads the sold spots from the test snapshot.
	t.test("the test snapshot lists the sold spots", function()
		local service = setup(1)
		local first = service:snapshotForTest(COMPANY) :: any
		expect.equal(#first.vacatedSpots, 0)
		expect.truthy(service:npcArrive(COMPANY, "visit:1"))
		expect.truthy(service:npcDecide(COMPANY, "visit:1", 8, 0))
		expect.truthy(service:npcSettle(COMPANY, "visit:1", "douglas_1"))
		local spots = (service:snapshotForTest(COMPANY) :: any).vacatedSpots
		expect.equal(#spots, 1)
		expect.equal(spots[1].x, -28)
		expect.equal(spots[1].z, -20)
		expect.equal(spots[1].sizeId, "Medium")
	end)

	t.test("npcSweep removes orphans only", function()
		local service, state = setup(3)
		expect.truthy(service:npcArrive(COMPANY, "visit:1"))
		expect.truthy(service:npcArrive(COMPANY, "visit:9"))
		expect.truthy(service:npcDecide(COMPANY, "visit:1", 8, 0))
		state.reservations.douglas_2 = { customerId = "visit:9", expiresAt = NOW + 60, salePrice = 100 }
		state.reservations.douglas_3 = { customerId = "npc:3", expiresAt = NOW + 60, salePrice = 100 }
		local removed = service:npcSweep(COMPANY, { ["visit:1"] = true })
		expect.equal(removed, 2)
		expect.equal(state.reservations.douglas_2, nil)
		expect.equal(state.reservations.douglas_1.customerId, "visit:1")
		expect.equal(state.reservations.douglas_3.customerId, "npc:3")
		local claims = service:npcClaimsForTest(COMPANY)
		expect.equal(claimCount(service), 1)
		expect.equal(claims[1], "visit:1")
	end)

	t.test("NPC calls refuse an unloaded session", function()
		local service = setup(1)
		expect.truthy(service:sessionToken(COMPANY))
		expect.truthy(service:unloadCompany(COMPANY))
		local ok, code = service:npcArrive(COMPANY, "visit:1")
		expect.falsy(ok)
		expect.equal(code, "CompanyUnavailable")
		expect.equal(service:sessionToken(COMPANY), nil)
	end)

	-- CM2-G15 Amendment 2: playtest step 42 compares the review window from the snapshot.
	t.test("snapshotForTest copies the recent reviews", function()
		local service, state = setup(0)
		state.reviews.recent = { 4, 5 }
		state.reviews.count = 2
		local snapshot = service:snapshotForTest(COMPANY) :: any
		expect.equal(#snapshot.reviewsRecent, 2)
		expect.equal(snapshot.reviewsRecent[1], 4)
		expect.equal(snapshot.reviewsRecent[2], 5)
		snapshot.reviewsRecent[1] = 1
		expect.equal(state.reviews.recent[1], 4)
	end)

	-- CM2-SALE1: the tutorial customer ignores preference and roll; normal demand after Done.
	t.test("npcDecide sells for sure on the tutorial's Checkout step (CM2-SALE1)", function()
		local service, state = setup(1, 0.99)
		state.tutorial = { step = "Checkout", skipped = false }
		expect.truthy(service:npcArrive(COMPANY, "visit:1"))
		local cash, sales = state.cash, state.sales
		local ok, picked = service:npcDecide(COMPANY, "visit:1", 5)
		expect.truthy(ok)
		expect.equal(picked.placementId, "douglas_1")
		expect.equal(picked.salePrice, 140)
		expect.truthy(service:npcSettle(COMPANY, "visit:1", "douglas_1"))
		expect.equal(state.cash, cash + 140)
		expect.equal(state.sales, sales + 1)
		expect.equal(state.tutorial.step, "Done")
		douglas(state, "douglas_2", -14)
		expect.truthy(service:npcArrive(COMPANY, "visit:2"))
		-- profile 5's budget (99 %) is below every benchmark price (CM2-SALE2 soft preferences)
		local again, code = service:npcDecide(COMPANY, "visit:2", 5)
		expect.falsy(again)
		expect.equal(code, "NoEligibleStock")
	end)

	t.test("npcDecide reports NoStock when every displayed tree is reserved (CM2-SALE1)", function()
		local service, state = setup(1)
		expect.truthy(service:npcArrive(COMPANY, "visit:1"))
		expect.truthy(service:npcArrive(COMPANY, "visit:2"))
		expect.truthy(service:npcDecide(COMPANY, "visit:1", 8, 0))
		local visits, abandoned = state.customerVisits, state.abandonedCustomers
		local ok, code = service:npcDecide(COMPANY, "visit:2", 8, 0)
		expect.falsy(ok)
		expect.equal(code, "NoStock")
		expect.equal(state.customerVisits, visits + 1)
		expect.equal(state.abandonedCustomers, abandoned + 1)
	end)
end

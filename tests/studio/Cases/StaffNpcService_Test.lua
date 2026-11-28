--!strict
-- CM2-25/26: the staff director, headless. Same harness as CustomerCheckout_Test: a real
-- CompanyStateService with a fake persistence, a fake world that records every call and puts
-- the avatar on each moveTo target at once, and a fake clock in 0.25-s ticks; the company
-- service has its own (integer) clock.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local NpcPath = require(Shared:WaitForChild("NpcPath"))
	local Staff = require(Shared:WaitForChild("Staff"))
	local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
	local CompanyStateService = require(Services:WaitForChild("CompanyStateService"))
	local CustomerOrderService = require(Services:WaitForChild("CustomerOrderService"))
	local StaffNpcService = require(Services:WaitForChild("StaffNpcService"))
	local expect = t.expect

	local A = "save:a"
	local PLOT_1 = "Plot_01"
	local CASHIER = A .. "|Cashier"
	local WORKER = A .. "|LotWorker"
	local TICKS_PER_SECOND = 4

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

	local function copy(p)
		return { x = p.x, z = p.z }
	end

	local function fakeWorld()
		local world = { calls = {}, positions = {}, anchored = {}, states = {} }
		local function log(name: string, ...)
			table.insert(world.calls, { name = name, args = { ... } })
		end
		function world:spawnAvatar(plotId, staffId, role, at, faceTo)
			log("spawnAvatar", plotId, staffId, role, copy(at), copy(faceTo))
			self.positions[staffId] = copy(at)
			self.anchored[staffId] = false
			return true
		end
		function world:moveTo(staffId, p)
			log("moveTo", staffId, copy(p))
			if self.positions[staffId] then
				self.positions[staffId] = copy(p)
			end
		end
		function world:snapTo(staffId, p)
			log("snapTo", staffId, copy(p))
			if self.positions[staffId] then
				self.positions[staffId] = copy(p)
			end
		end
		function world:position(staffId)
			local p = self.positions[staffId]
			return if p then copy(p) else nil
		end
		function world:face(staffId, p)
			log("face", staffId, copy(p))
		end
		function world:holdTree(staffId, sizeId)
			log("holdTree", staffId, sizeId)
		end
		function world:dropTree(staffId)
			log("dropTree", staffId)
		end
		function world:setAnchored(staffId, on)
			log("setAnchored", staffId, on)
			self.anchored[staffId] = on
		end
		function world:setState(staffId, state)
			self.states[staffId] = state
		end
		function world:despawn(staffId)
			log("despawn", staffId)
			self.positions[staffId] = nil
		end
		return world
	end

	local function harness(options)
		local h = { ticks = 0, clock = 1000, reviews = {} }
		h.world = fakeWorld()
		h.service = CompanyStateService.new(fakePersistence(), function()
			return h.clock
		end, function()
			return 0
		end)
		h.service:setReviewsHandler(function(_companyId, reviews)
			for _, review in ipairs(reviews) do
				table.insert(h.reviews, review)
			end
		end)
		h.plots = {}
		h.staff = StaffNpcService.new({
			companies = h.service,
			plotOf = function(companyId)
				return h.plots[companyId]
			end,
			world = h.world,
			now = function()
				return h.ticks / TICKS_PER_SECOND
			end,
		}, options)
		return h
	end

	local function addCompany(h)
		local state = h.service:loadCompany(A, 42)
		state.progression.parkingTier = 4
		h.plots[A] = PLOT_1
		return state
	end

	local function hire(h, role: string)
		expect.truthy(h.service:setStaffForTest(A, role, 1))
	end

	local function tick(h)
		h.ticks += 1
		h.staff:tick()
	end

	local function run(h, seconds: number)
		for _ = 1, math.floor(seconds * TICKS_PER_SECOND + 0.5) do
			tick(h)
		end
	end

	local function entryOf(h, staffId: string)
		for _, entry in ipairs(h.staff:snapshot().staff) do
			if entry.staffId == staffId then
				return entry
			end
		end
		return nil
	end

	local function stateOf(h, staffId: string): string?
		local entry = entryOf(h, staffId)
		return if entry then entry.state else nil
	end

	local function runUntil(h, staffId: string, wanted: string, maxSeconds: number)
		for _ = 1, math.floor(maxSeconds * TICKS_PER_SECOND) do
			if stateOf(h, staffId) == wanted then
				break
			end
			tick(h)
		end
		expect.equal(stateOf(h, staffId), wanted)
		return entryOf(h, staffId)
	end

	local function lastCall(h, name: string, staffId: string?)
		for index = #h.world.calls, 1, -1 do
			local call = h.world.calls[index]
			if call.name == name and (staffId == nil or call.args[1] == staffId or call.args[2] == staffId) then
				return call
			end
		end
		return nil
	end

	local function countCalls(h, name: string, staffId: string): number
		local count = 0
		for _, call in ipairs(h.world.calls) do
			if call.name == name and call.args[1] == staffId then
				count += 1
			end
		end
		return count
	end

	local function samePoint(actual, x: number, z: number)
		expect.truthy(actual ~= nil)
		assert(
			math.abs(actual.x - x) < 1e-6 and math.abs(actual.z - z) < 1e-6,
			string.format("expected (%s, %s), got (%s, %s)", x, z, actual.x, actual.z)
		)
	end

	-- An open customer order waiting at parking space `space`.
	local function addOrder(h, state, space: number)
		local created, order = CustomerOrderService.createFromSale(state, {
			placementId = "sold_" .. state.nextOrderNumber,
			speciesId = "DouglasFir",
			sizeId = "Medium",
			salePrice = 140,
		}, h.clock, space)
		expect.truthy(created)
		return order
	end

	-- A walking customer buys the only displayed tree (-28, -6), so its spot is sold; bay 1
	-- holds Fraser Fir and bay 2 Douglas Fir, both Medium.
	local function sellSpot(h, state)
		state.bays[1] = { speciesId = "FrasierFir", counts = { Medium = 2 } }
		state.bays[2] = { speciesId = "DouglasFir", counts = { Medium = 2 } }
		state.layout.placements.sold = {
			speciesId = "DouglasFir",
			sizeId = "Medium",
			transform = { x = -28, y = 0, z = -6, rotation = 0 },
		}
		expect.truthy(h.service:npcArrive(A, "visit:1"))
		local decided, decision = h.service:npcDecide(A, "visit:1", 8, 0)
		expect.truthy(decided)
		expect.equal(decision.placementId, "sold")
		expect.truthy(h.service:npcSettle(A, "visit:1", "sold", nil, 0))
		expect.equal(state.layout.placements.sold, nil)
	end

	local function staffPlacement(state)
		for placementId, placement in pairs(state.layout.placements) do
			if string.sub(placementId, 1, 6) == "staff:" then
				return placementId, placement
			end
		end
		return nil, nil
	end

	local function vacated(h): number
		local session = (h.service :: any)._sessions[A]
		local spots = session and session.vacatedSpots
		return if spots then #spots else 0
	end

	t.test("a hired Cashier walks from its seat to the counter post", function()
		local h = harness()
		local state = addCompany(h)
		hire(h, "Cashier")
		tick(h)
		local spawned = lastCall(h, "spawnAvatar") :: any
		expect.truthy(spawned ~= nil)
		expect.equal(spawned.args[1], PLOT_1)
		expect.equal(spawned.args[2], CASHIER)
		expect.equal(spawned.args[3], "Cashier")
		local seat = Staff.restPoint(state.breakArea, "Cashier")
		samePoint(spawned.args[4], seat.x, seat.z)
		expect.equal(stateOf(h, CASHIER), "WalkingToPost")
		runUntil(h, CASHIER, "OnDuty", 30)
		samePoint(h.world.positions[CASHIER], -14, 14)
		expect.equal(h.world.anchored[CASHIER], true)
		local faced = lastCall(h, "face", CASHIER) :: any
		local slot = NpcPath.queueSlot(1)
		samePoint(faced.args[2], slot.x, slot.z)
		expect.equal(h.world.states[CASHIER], "OnDuty")
		expect.equal(entryOf(h, WORKER), nil)
	end)

	t.test("cashierReady only while on duty", function()
		local h = harness()
		addCompany(h)
		expect.falsy(h.staff:cashierReady(A))
		hire(h, "Cashier")
		tick(h)
		expect.equal(stateOf(h, CASHIER), "WalkingToPost")
		expect.falsy(h.staff:cashierReady(A))
		runUntil(h, CASHIER, "OnDuty", 30)
		expect.truthy(h.staff:cashierReady(A))
		expect.truthy(h.staff:setEnergyForTest(A, "Cashier", 20))
		tick(h)
		expect.equal(stateOf(h, CASHIER), "WalkingToBreak")
		expect.falsy(h.staff:cashierReady(A))
		runUntil(h, CASHIER, "Resting", 30)
		expect.falsy(h.staff:cashierReady(A))
		expect.falsy(h.staff:cashierReady("save:other"))
	end)

	-- CM2-G16 acceptance: a tired worker walks to the break area and resumes.
	t.test("a tired Cashier rests at the break area and resumes", function()
		local h = harness()
		local state = addCompany(h)
		hire(h, "Cashier")
		runUntil(h, CASHIER, "OnDuty", 30)
		expect.truthy(h.staff:setEnergyForTest(A, "Cashier", 21))
		run(h, 4)
		expect.equal(stateOf(h, CASHIER), "OnDuty")
		runUntil(h, CASHIER, "WalkingToBreak", 3)
		runUntil(h, CASHIER, "Resting", 30)
		local seat = Staff.restPoint(state.breakArea, "Cashier")
		samePoint(h.world.positions[CASHIER], seat.x, seat.z)
		expect.equal(h.world.anchored[CASHIER], true)
		local faced = lastCall(h, "face", CASHIER) :: any
		samePoint(faced.args[2], state.breakArea.x, state.breakArea.z)
		local rested = runUntil(h, CASHIER, "WalkingToPost", 60) :: any
		expect.equal(rested.energy, 100)
		local back = runUntil(h, CASHIER, "OnDuty", 30) :: any
		expect.truthy(back.energy >= 99)
		samePoint(h.world.positions[CASHIER], -14, 14)
	end)

	t.test("a tired Lot Worker finishes its job, rests and resumes", function()
		local h = harness()
		local state = addCompany(h)
		addOrder(h, state, 1)
		hire(h, "LotWorker")
		runUntil(h, WORKER, "CarryingToCar", 60)
		local loaded = state.loadedOrders
		expect.truthy(h.staff:setEnergyForTest(A, "LotWorker", 20))
		local seen: { string } = {}
		local loadedAtBreak = nil
		for _ = 1, 120 * TICKS_PER_SECOND do
			tick(h)
			local current = stateOf(h, WORKER) :: string
			if seen[#seen] ~= current then
				table.insert(seen, current)
				if current == "WalkingToBreak" then
					loadedAtBreak = state.loadedOrders
				end
			end
			if current == "Idle" then
				break
			end
		end
		expect.equal(loadedAtBreak, loaded + 1)
		-- CM2-LOTLAY: the way to the car bends around the gate fence, so the first tick still carries.
		expect.equal(table.concat(seen, ","), "CarryingToCar,WalkingToBreak,Resting,WalkingToPost,Idle")
		expect.equal(state.loadedOrders, loaded + 1)
	end)

	t.test("the Lot Worker loads the oldest order exactly once", function()
		local h = harness()
		local state = addCompany(h)
		local first = addOrder(h, state, 2)
		local second = addOrder(h, state, 1)
		expect.truthy(first.orderNumber < second.orderNumber)
		hire(h, "LotWorker")
		local revision, loaded = state.revision, state.loadedOrders
		runUntil(h, WORKER, "CarryingToCar", 60)
		local approach = Staff.pickupApproach(2)
		local claimedAt = lastCall(h, "holdTree", WORKER) :: any
		expect.equal(claimedAt.args[2], "Medium")
		-- The fake world puts the avatar on the first waypoint (a corner of the gate fence since CM2-LOTLAY).
		local firstStop = NpcPath.route(approach, NpcPath.door(2), 0)[1]
		samePoint(h.world.positions[WORKER], firstStop.x, firstStop.z)
		expect.equal(state.customerOrders[tostring(first.orderNumber)].carriedBy, GameConfig.Staff.CarrierUserId)
		expect.equal(state.customerOrders[tostring(second.orderNumber)].carriedBy, nil)
		expect.equal(state.revision, revision + 1)
		local walkedToPickup = false
		for _, call in ipairs(h.world.calls) do
			if call.name == "moveTo" and call.args[2].x == approach.x and call.args[2].z == approach.z then
				walkedToPickup = true
			end
		end
		expect.truthy(walkedToPickup)
		for _ = 1, 60 * TICKS_PER_SECOND do
			if state.loadedOrders > loaded then
				break
			end
			tick(h)
		end
		expect.equal(state.loadedOrders, loaded + 1)
		expect.equal(state.revision, revision + 2)
		expect.equal(#h.reviews, 1)
		expect.equal(h.reviews[1].orderNumber, first.orderNumber)
		expect.equal(state.customerOrders[tostring(first.orderNumber)], nil)
		expect.truthy(state.customerOrders[tostring(second.orderNumber)] ~= nil)
		expect.equal(h.staff:snapshot().staff[1].orderNumber, second.orderNumber)
	end)

	t.test("a player cannot take an order the Lot Worker carries", function()
		local h = harness()
		local state = addCompany(h)
		local order = addOrder(h, state, 1)
		hire(h, "LotWorker")
		runUntil(h, WORKER, "CarryingToCar", 60)
		local refused = h.service:handle(A, 42, {
			version = 1,
			requestId = "staff_carry_1",
			action = "Order.Carry",
			payload = { orderNumber = order.orderNumber },
		})
		expect.falsy(refused.ok)
		expect.equal(refused.errorCode, "AlreadyCarried")
		expect.truthy(h.service:staffReleaseOrder(A, order.orderNumber))
		expect.equal(state.customerOrders[tostring(order.orderNumber)].carriedBy, nil)
		local carried = h.service:handle(A, 42, {
			version = 1,
			requestId = "staff_carry_2",
			action = "Order.Carry",
			payload = { orderNumber = order.orderNumber },
		})
		expect.truthy(carried.ok)
		expect.equal(state.customerOrders[tostring(order.orderNumber)].carriedBy, 42)
	end)

	t.test("the Lot Worker restocks a sold spot from a bay", function()
		local h = harness()
		local state = addCompany(h)
		sellSpot(h, state)
		expect.equal(vacated(h), 1)
		hire(h, "LotWorker")
		for _ = 1, 180 * TICKS_PER_SECOND do
			if staffPlacement(state) ~= nil then
				break
			end
			tick(h)
		end
		local placementId, placement = staffPlacement(state)
		expect.truthy(placementId ~= nil)
		expect.equal(placement.transform.x, -28)
		expect.equal(placement.transform.z, -6)
		expect.equal(placement.speciesId, "DouglasFir")
		expect.equal(placement.sizeId, "Medium")
		expect.equal(state.bays[2].counts.Medium, 1)
		expect.equal(state.bays[1].counts.Medium, 2)
		expect.equal(vacated(h), 0)
		expect.equal(state.loadedOrders, 1)
		expect.truthy(BusinessState.validate(state))
	end)

	-- Amendment 2: every sold spot is restocked while a bay holds the size; the rest waits.
	t.test("the Lot Worker restocks every sold spot while a bay holds the size", function()
		local h = harness()
		local state = addCompany(h)
		state.bays[1] = { speciesId = "DouglasFir", counts = { Medium = 2 } }
		for index, spot in ipairs({ { -28, -6 }, { -28, 1 }, { -35, 8 } }) do
			state.layout.placements["tree_" .. index] = {
				speciesId = "DouglasFir",
				sizeId = "Medium",
				transform = { x = spot[1], y = 0, z = spot[2], rotation = 0 },
			}
		end
		local soldOrder = {}
		for index = 1, 3 do
			local visitId = "visit:" .. index
			expect.truthy(h.service:npcArrive(A, visitId))
			local decided, decision = h.service:npcDecide(A, visitId, 8, 0)
			expect.truthy(decided)
			local placement = state.layout.placements[decision.placementId]
			table.insert(soldOrder, { x = placement.transform.x, z = placement.transform.z })
			expect.truthy(h.service:npcSettle(A, visitId, decision.placementId, nil, 0))
		end
		expect.equal(vacated(h), 3)
		hire(h, "LotWorker")
		local function staffCount(): number
			local count = 0
			for placementId in pairs(state.layout.placements) do
				if string.sub(placementId, 1, 6) == "staff:" then
					count += 1
				end
			end
			return count
		end
		for _ = 1, 300 * TICKS_PER_SECOND do
			if staffCount() == 2 and stateOf(h, WORKER) == "Idle" then
				break
			end
			tick(h)
		end
		expect.equal(staffCount(), 2)
		expect.equal(stateOf(h, WORKER), "Idle")
		for index = 1, 2 do
			local found = false
			for placementId, placement in pairs(state.layout.placements) do
				if
					string.sub(placementId, 1, 6) == "staff:"
					and placement.transform.x == soldOrder[index].x
					and placement.transform.z == soldOrder[index].z
				then
					found = true
				end
			end
			expect.truthy(found)
		end
		expect.equal(state.bays[1].counts.Medium, nil)
		expect.equal(state.loadedOrders, 3)
		local spots = (h.service:snapshotForTest(A) :: any).vacatedSpots
		expect.equal(#spots, 1)
		expect.equal(spots[1].x, soldOrder[3].x)
		expect.equal(spots[1].z, soldOrder[3].z)
		expect.equal(spots[1].sizeId, "Medium")
		expect.equal((entryOf(h, WORKER) :: any).job, nil)
	end)

	t.test("a taken restock spot is dropped without changes", function()
		local h = harness()
		local state = addCompany(h)
		sellSpot(h, state)
		hire(h, "LotWorker")
		runUntil(h, WORKER, "CarryingToSpot", 180)
		-- A player stocks the sold spot first.
		state.layout.placements.player = {
			speciesId = "FrasierFir",
			sizeId = "Medium",
			transform = { x = -28, y = 0, z = -6, rotation = 0 },
		}
		local revision = state.revision
		for _ = 1, 60 * TICKS_PER_SECOND do
			if stateOf(h, WORKER) ~= "CarryingToSpot" then
				break
			end
			tick(h)
		end
		expect.truthy(stateOf(h, WORKER) ~= "CarryingToSpot")
		expect.equal(staffPlacement(state), nil)
		expect.equal(state.bays[2].counts.Medium, 2)
		expect.equal(state.bays[1].counts.Medium, 2)
		expect.equal(vacated(h), 0)
		expect.equal(state.revision, revision)
		expect.truthy(lastCall(h, "dropTree", WORKER) ~= nil)
	end)

	t.test("no wages: staff never change cash", function()
		local h = harness()
		local state = addCompany(h)
		hire(h, "Cashier")
		hire(h, "LotWorker")
		local cash, spent, history = state.cash, state.spent, #state.history
		local lastEntry = state.history[#state.history]
		local rested = false
		for _ = 1, 30 * 60 * TICKS_PER_SECOND do
			tick(h)
			if stateOf(h, CASHIER) == "Resting" then
				rested = true
			end
		end
		expect.truthy(rested)
		expect.equal(h.staff:count(), 2)
		expect.equal(state.cash, cash)
		expect.equal(state.spent, spent)
		expect.equal(#state.history, history)
		expect.equal(state.history[#state.history], lastEntry)
	end)

	t.test("energy is written to the save and restored on reload", function()
		local h = harness()
		local state = addCompany(h)
		hire(h, "Cashier")
		expect.truthy(h.service:flushDirty(true))
		expect.falsy(h.service:isDirty(A))
		local revision = state.revision
		run(h, GameConfig.Staff.EnergySaveSeconds + 1)
		local saved = state.staffEnergy.Cashier
		expect.equal(saved, math.floor(saved))
		expect.truthy(saved < 100 and saved >= 96)
		expect.equal(state.staffEnergy.LotWorker, 100)
		expect.falsy(h.service:isDirty(A))
		expect.equal(state.revision, revision)
		expect.truthy(h.service:unloadCompany(A))
		local reloaded = h.service:loadCompany(A, 42)
		expect.equal(reloaded.staffEnergy.Cashier, saved)
		tick(h)
		expect.equal(countCalls(h, "despawn", CASHIER), 1)
		local respawned = entryOf(h, CASHIER) :: any
		expect.truthy(respawned ~= nil)
		expect.equal(respawned.energy, saved)
	end)

	t.test("letting staff go mid-carry releases the order", function()
		local h = harness()
		local state = addCompany(h)
		local order = addOrder(h, state, 1)
		hire(h, "LotWorker")
		runUntil(h, WORKER, "CarryingToCar", 60)
		expect.equal(state.customerOrders[tostring(order.orderNumber)].carriedBy, GameConfig.Staff.CarrierUserId)
		expect.truthy(h.service:setStaffForTest(A, "LotWorker", 0))
		tick(h)
		expect.equal(state.customerOrders[tostring(order.orderNumber)].carriedBy, nil)
		expect.equal(countCalls(h, "despawn", WORKER), 1)
		expect.equal(entryOf(h, WORKER), nil)
		expect.equal(h.world.positions[WORKER], nil)
		run(h, 2)
		expect.equal(h.staff:count(), 0)
	end)

	t.test("a reload or plot release removes staff without transactions", function()
		local h = harness()
		local state = addCompany(h)
		hire(h, "Cashier")
		hire(h, "LotWorker")
		runUntil(h, CASHIER, "OnDuty", 30)
		runUntil(h, WORKER, "Idle", 30)
		local revision, cash = state.revision, state.cash
		expect.truthy(h.service:unloadCompany(A))
		h.service:loadCompany(A, 42)
		tick(h)
		expect.equal(countCalls(h, "despawn", CASHIER), 1)
		expect.equal(countCalls(h, "despawn", WORKER), 1)
		expect.equal(h.staff:count(), 2)
		expect.equal(stateOf(h, CASHIER), "WalkingToPost")
		h.staff:clearPlot(PLOT_1)
		expect.equal(h.staff:count(), 0)
		expect.equal(countCalls(h, "despawn", CASHIER), 2)
		h.plots[A] = nil
		run(h, 2)
		expect.equal(h.staff:count(), 0)
		expect.equal(state.revision, revision)
		expect.equal(state.cash, cash)
	end)

	t.test("the server budget caps staff", function()
		local h = harness({ maxPerServer = 1 })
		addCompany(h)
		hire(h, "Cashier")
		hire(h, "LotWorker")
		run(h, 2)
		expect.equal(h.staff:count(), 1)
		expect.equal(h.staff:spawnLoad(PLOT_1, 3, 10), 0)
		expect.equal(GameConfig.Staff.MaxPerPlot, 3)
	end)

	t.test("every walking state has a timeout and a lost avatar releases its claim", function()
		local legs = 0
		for _, entry in pairs(StaffNpcService.Fsm) do
			if entry.leg then
				legs += 1
				expect.truthy(entry.timeout ~= nil and entry.timeout > 0)
			end
		end
		expect.equal(legs, 6)
		expect.truthy((StaffNpcService.Fsm.Resting.timeout :: number) > 0)
		expect.truthy((StaffNpcService.Fsm.LoadLoop.timeout :: number) > 0)
		local h = harness()
		local state = addCompany(h)
		local order = addOrder(h, state, 1)
		hire(h, "LotWorker")
		runUntil(h, WORKER, "CarryingToCar", 60)
		h.world.positions[WORKER] = nil
		tick(h)
		expect.equal(state.customerOrders[tostring(order.orderNumber)].carriedBy, nil)
		expect.equal(entryOf(h, WORKER), nil)
		tick(h)
		expect.equal(stateOf(h, WORKER), "WalkingToPost")
	end)

	t.test("load staff loop and clear", function()
		local h = harness()
		expect.equal(h.staff:spawnLoad(PLOT_1, 3, 30), 3)
		expect.equal(h.staff:count(), 3)
		run(h, 5)
		local snapshot = h.staff:snapshot()
		expect.equal(snapshot.count, 3)
		for _, entry in ipairs(snapshot.staff) do
			expect.equal(entry.state, "LoadLoop")
			expect.equal(entry.companyId, nil)
		end
		expect.equal(h.staff:clearLoad(), 3)
		expect.equal(h.staff:count(), 0)
		expect.equal(h.staff:spawnLoad(PLOT_1, 2, 10), 2)
		run(h, 10.5)
		expect.equal(h.staff:count(), 0)
		expect.equal(h.staff:snapshot().loadSnaps, 0)
	end)

	-- CM2-25/26 part b: one request of the owner (user 42) of save A.
	local function ownerAct(h, requestId: string, action: string, payload)
		return h.service:handle(A, 42, { version = 1, requestId = requestId, action = action, payload = payload })
	end

	t.test("resting staff walk to the moved break area", function()
		local h = harness()
		local state = addCompany(h)
		hire(h, "Cashier")
		runUntil(h, CASHIER, "OnDuty", 30)
		expect.truthy(h.staff:setEnergyForTest(A, "Cashier", 20))
		runUntil(h, CASHIER, "Resting", 30)
		local oldSeat = Staff.restPoint(state.breakArea, "Cashier")
		samePoint(h.world.positions[CASHIER], oldSeat.x, oldSeat.z)
		-- The fake world arrives at once, so the states are recorded as they are entered.
		local seen: { string } = {}
		local setState = h.world.setState
		h.world.setState = function(world, staffId, value)
			if staffId == CASHIER then
				table.insert(seen, value)
			end
			setState(world, staffId, value)
		end
		local moved = ownerAct(h, "move_break_1", "Staff.MoveBreakArea", { x = -32, z = -4, rotation = 90 })
		expect.truthy(moved.ok)
		tick(h)
		expect.equal(seen[1], "WalkingToBreak")
		runUntil(h, CASHIER, "Resting", 30)
		expect.equal(table.concat(seen, ","), "WalkingToBreak,Resting")
		local newSeat = Staff.restPoint({ x = -32, z = -4, rotation = 90 }, "Cashier")
		samePoint(h.world.positions[CASHIER], newSeat.x, newSeat.z)
		local faced = lastCall(h, "face", CASHIER) :: any
		samePoint(faced.args[2], -32, -4)
		-- An unchanged area does not send resting staff walking again.
		tick(h)
		expect.equal(stateOf(h, CASHIER), "Resting")
	end)

	t.test("noteStaff reports status and energy", function()
		local h = harness()
		addCompany(h)
		local count = 0
		local function cashierRow()
			count += 1
			local response = ownerAct(h, "staff_summary_" .. count, "Company.GetSummary", {})
			expect.truthy(response.ok)
			return response.data.staff.roles[1]
		end
		expect.equal(cashierRow().status, nil)
		hire(h, "Cashier")
		expect.equal(cashierRow().status, "Arriving")
		tick(h)
		expect.equal(cashierRow().status, "OnTheWay")
		runUntil(h, CASHIER, "OnDuty", 30)
		local working = cashierRow()
		expect.equal(working.status, "Working")
		-- The row floors the energy at the last step, the snapshot rounds to 0.1: at most 1 apart.
		expect.truthy(math.abs(working.energy - math.floor((entryOf(h, CASHIER) :: any).energy)) <= 1)
		expect.truthy(h.staff:setEnergyForTest(A, "Cashier", 20))
		runUntil(h, CASHIER, "Resting", 30)
		local resting = cashierRow()
		expect.equal(resting.status, "Resting")
		expect.truthy(resting.energy <= 21)
		h.world.positions[CASHIER] = nil
		tick(h)
		expect.equal(entryOf(h, CASHIER), nil)
		expect.equal(cashierRow().status, "Arriving")
	end)
end

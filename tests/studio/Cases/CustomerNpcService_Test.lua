--!strict
-- CM2-N1: the walking customer director, headless. The fake world records every call; its
-- moveTo puts the avatar on the target at once (or never, for a stuck world). Ticks run in
-- 0.2-s steps of a fake clock; the company service has its own (integer) clock.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local NpcPath = require(Shared:WaitForChild("NpcPath"))
	local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
	local CompanyStateService = require(Services:WaitForChild("CompanyStateService"))
	local CustomerNpcService = require(Services:WaitForChild("CustomerNpcService"))
	local expect = t.expect

	local A, B = "save:a", "save:b"
	local PLOT_1, PLOT_2 = "Plot_01", "Plot_02"
	local FULL_PATH = {
		"Arriving",
		"WalkingIn",
		"Browsing",
		"WalkingToTree",
		"PickingUp",
		"WalkingToQueue",
		"Queued",
		"CheckingOut",
		"WalkingToCar",
		"WaitingAtCar",
	}

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

	-- shortBy: moveTo stops that many studs short of its target (Fix round 1 corner test).
	local function fakeWorld(stuck: boolean?, shortBy: number?)
		local world = { calls = {}, positions = {} }
		local function log(name: string, ...)
			table.insert(world.calls, { name = name, args = { ... } })
		end
		local function copy(p)
			return { x = p.x, z = p.z }
		end
		function world:spawnCar(plotId, visitId, space, seq)
			log("spawnCar", plotId, visitId, space, seq)
			return true
		end
		function world:adoptCar(plotId, visitId, orderNumber)
			log("adoptCar", plotId, visitId, orderNumber)
		end
		function world:dismissCar(plotId, visitId)
			log("dismissCar", plotId, visitId)
		end
		function world:destroyCar(plotId, visitId)
			log("destroyCar", plotId, visitId)
		end
		function world:spawnAvatar(plotId, visitId, seq, door)
			log("spawnAvatar", plotId, visitId, seq, copy(door))
			self.positions[visitId] = copy(door)
			return true
		end
		function world:moveTo(visitId, p)
			log("moveTo", visitId, copy(p))
			local current = self.positions[visitId]
			if not stuck and current then
				if shortBy ~= nil then
					local dx, dz = p.x - current.x, p.z - current.z
					local length = math.sqrt(dx * dx + dz * dz)
					if length > shortBy then
						local scale = (length - shortBy) / length
						self.positions[visitId] = { x = current.x + dx * scale, z = current.z + dz * scale }
					end
				else
					self.positions[visitId] = copy(p)
				end
			end
		end
		function world:snapTo(visitId, p)
			log("snapTo", visitId, copy(p))
			if self.positions[visitId] then
				self.positions[visitId] = copy(p)
			end
		end
		function world:position(visitId)
			local p = self.positions[visitId]
			return if p then copy(p) else nil
		end
		function world:holdTree(visitId, sizeId)
			log("holdTree", visitId, sizeId)
		end
		function world:dropTree(visitId)
			log("dropTree", visitId)
		end
		function world:say(visitId)
			log("say", visitId)
		end
		function world:despawn(visitId)
			log("despawn", visitId)
			self.positions[visitId] = nil
		end
		function world:showCheckout(plotId, info)
			log("showCheckout", plotId, info)
		end
		function world:face(visitId, p)
			log("face", visitId, copy(p))
		end
		return world
	end

	local function harness(options, stuck: boolean?, shortBy: number?)
		local h = { ticks = 0, clock = 1000 }
		h.world = fakeWorld(stuck, shortBy)
		-- CM2-SALE1: h.roll is the company service's random roll (0 when nil).
		h.service = CompanyStateService.new(fakePersistence(), function()
			return h.clock
		end, function()
			return h.roll or 0
		end)
		h.plots = {}
		-- CM2-25/26: a stand-in for the visible Cashier, on duty whenever one is hired.
		h.staff = {
			cashierReady = function(_, companyId)
				local view = h.service:getStaffView(companyId)
				return view ~= nil and view.hired.Cashier == true
			end,
		}
		h.npc = CustomerNpcService.new({
			companies = h.service,
			plotOf = function(companyId)
				return h.plots[companyId]
			end,
			world = h.world,
			now = function()
				return h.ticks / 5
			end,
			staff = h.staff,
			-- CM2-G12a: the save's arrival rate; existing tests leave h.rate nil (day, 1).
			arrivalRate = function()
				return h.rate or 1
			end,
		}, options)
		h.service:setCustomerOrdersChangedHandler(function(companyId, summary)
			table.insert(h.world.calls, { name = "ordersChanged", args = { companyId } })
			h.npc:onOrdersChanged(companyId, summary)
		end)
		return h
	end

	local function addCompany(h, companyId: string, plotId: string, trees: number)
		local state = h.service:loadCompany(companyId, 42)
		state.progression.parkingTier = 2
		-- CM2-N2: a hired Cashier serves the counter after 3 s.
		state.staff.Cashier = 1
		for index = 1, trees do
			state.layout.placements["douglas_" .. index] = {
				speciesId = "DouglasFir",
				sizeId = "Medium",
				transform = { x = -35 + 7 * index, y = 0, z = -20, rotation = 0 },
			}
		end
		h.plots[companyId] = plotId
		return state
	end

	local function run(h, seconds: number)
		for _ = 1, math.floor(seconds * 5 + 0.5) do
			h.ticks += 1
			h.npc:tick()
		end
	end

	local function visitOf(h, visitId: string)
		for _, visit in ipairs(h.npc:snapshot().visits) do
			if visit.visitId == visitId then
				return visit
			end
		end
		return nil
	end

	local function stateOf(h, visitId: string): string?
		local visit = visitOf(h, visitId)
		return if visit then visit.state else nil
	end

	local function runUntil(h, visitId: string, wanted: string, maxSeconds: number)
		for _ = 1, math.floor(maxSeconds * 5) do
			if stateOf(h, visitId) == wanted then
				break
			end
			h.ticks += 1
			h.npc:tick()
		end
		expect.equal(stateOf(h, visitId), wanted)
		return visitOf(h, visitId)
	end

	local function spawn(h, companyId: string, profile: number): string
		local ok, visitId = h.npc:spawnForTest(companyId, profile)
		expect.truthy(ok)
		return visitId
	end

	local function callIndex(h, name: string, value: any): number?
		for index, call in ipairs(h.world.calls) do
			if call.name == name and (value == nil or table.find(call.args, value) ~= nil) then
				return index
			end
		end
		return nil
	end

	local function claimCount(h, companyId: string): number
		local count = 0
		for _ in pairs(h.service:npcClaimsForTest(companyId)) do
			count += 1
		end
		return count
	end

	t.test("every state has a positive timeout and a known exit", function()
		local Fsm = CustomerNpcService.Fsm
		local count = 0
		for _, entry in pairs(Fsm) do
			count += 1
			expect.truthy(type(entry.timeout) == "number" and entry.timeout > 0)
			expect.truthy(entry.onTimeout == "Done" or Fsm[entry.onTimeout] ~= nil)
		end
		expect.equal(count, 13)
	end)

	t.test("a customer walks the full path", function()
		local h = harness()
		addCompany(h, A, PLOT_1, 1)
		local visitId = spawn(h, A, 8)
		local visit = runUntil(h, visitId, "WaitingAtCar", 200)
		expect.equal(#visit.history, #FULL_PATH)
		for index, state in ipairs(FULL_PATH) do
			expect.equal(visit.history[index], state)
		end
		local orders = h.service:getCustomerOrders(A).orders
		expect.equal(#orders, 1)
		expect.equal(orders[1].parkingSpace, visit.space)
		expect.equal(visit.orderNumber, orders[1].orderNumber)
		local adopted = callIndex(h, "adoptCar", visitId) :: number
		local synced = callIndex(h, "ordersChanged") :: number
		expect.truthy(adopted ~= nil and synced ~= nil and adopted < synced)
		expect.equal(visit.snaps, 0)
		expect.truthy(callIndex(h, "say", visitId))
	end)

	t.test("the carried tree is hidden while carried", function()
		local h = harness()
		addCompany(h, A, PLOT_1, 1)
		local visitId = spawn(h, A, 8)
		runUntil(h, visitId, "PickingUp", 100)
		expect.truthy(h.npc:carriedPlacements(A).douglas_1)
		expect.truthy(callIndex(h, "holdTree", visitId))
		runUntil(h, visitId, "WaitingAtCar", 100)
		expect.equal(next(h.npc:carriedPlacements(A)), nil)
	end)

	t.test("a stuck leg snaps after LegTimeout", function()
		local h = harness(nil, true)
		addCompany(h, A, PLOT_1, 1)
		local visitId = spawn(h, A, 8)
		runUntil(h, visitId, "WalkingIn", 10)
		run(h, 20.2)
		local visit = visitOf(h, visitId)
		expect.equal(visit.state, "Browsing")
		expect.equal(visit.snaps, 1)
		expect.truthy(callIndex(h, "snapTo", visitId))
		local snapshot = h.npc:snapshot()
		local last = snapshot.snapLog[#snapshot.snapLog]
		expect.truthy(last ~= nil)
		expect.equal(last.visitId, visitId)
		expect.equal(last.state, "WalkingIn")
		expect.equal(snapshot.customerSnaps, 1)
	end)

	t.test("queue patience runs out and releases the tree", function()
		local h = harness()
		local state = addCompany(h, A, PLOT_1, 1)
		state.staff.Cashier = 0
		local visitId = spawn(h, A, 8)
		runUntil(h, visitId, "Queued", 100)
		expect.truthy(state.reservations.douglas_1)
		local abandoned = state.abandonedCustomers
		local walkedOut = state.walkedOutCustomers
		run(h, 89.8)
		expect.equal(stateOf(h, visitId), "CheckingOut")
		run(h, 0.4)
		local visit = visitOf(h, visitId)
		expect.equal(visit.history[8], "CheckingOut")
		expect.equal(visit.history[9], "WalkingOut")
		expect.equal(state.reservations.douglas_1, nil)
		expect.equal(state.abandonedCustomers, abandoned + 1)
		expect.equal(state.walkedOutCustomers, walkedOut + 1)
		expect.equal(next(h.npc:carriedPlacements(A)), nil)
	end)

	-- CM2-G9a: the HQ's patience bonus reaches the visit through npcArrive (HQ 4: 117 s).
	t.test("queue patience follows the HQ tier", function()
		local h = harness()
		local state = addCompany(h, A, PLOT_1, 1)
		state.staff.Cashier = 0
		state.progression.hqLevel = 4
		local visitId = spawn(h, A, 8)
		runUntil(h, visitId, "Queued", 100)
		local walkedOut = state.walkedOutCustomers
		run(h, 100)
		expect.truthy(stateOf(h, visitId) == "Queued" or stateOf(h, visitId) == "CheckingOut")
		expect.equal(state.walkedOutCustomers, walkedOut)
		run(h, 18)
		local visit = visitOf(h, visitId)
		expect.truthy(table.find(visit.history, "WalkingOut") ~= nil)
		expect.equal(state.walkedOutCustomers, walkedOut + 1)
	end)

	t.test("giving up on the way to the tree releases it", function()
		local h = harness()
		local state = addCompany(h, A, PLOT_1, 1)
		local visitId = spawn(h, A, 8)
		runUntil(h, visitId, "WalkingToTree", 100)
		expect.truthy(state.reservations.douglas_1)
		expect.truthy(h.npc:giveUpForTest(visitId))
		expect.equal(state.reservations.douglas_1, nil)
		expect.equal(stateOf(h, visitId), "WalkingOut")
		expect.falsy(h.npc:giveUpForTest(visitId))
	end)

	t.test("the customer leaves when the order is loaded", function()
		local h = harness()
		addCompany(h, A, PLOT_1, 1)
		local visitId = spawn(h, A, 8)
		local visit = runUntil(h, visitId, "WaitingAtCar", 200)
		local number = visit.orderNumber
		local carried = h.service:handle(A, 42, {
			version = 1,
			requestId = "npc_carry_1",
			action = "Order.Carry",
			payload = { orderNumber = number },
		})
		expect.truthy(carried.ok)
		local loaded = h.service:handle(A, 42, {
			version = 1,
			requestId = "npc_load_1",
			action = "Order.Load",
			payload = { orderNumber = number, carNumber = number },
		})
		expect.truthy(loaded.ok)
		expect.equal(stateOf(h, visitId), "Departing")
		expect.truthy(callIndex(h, "despawn", visitId))
		expect.equal(callIndex(h, "dismissCar", visitId), nil)
		run(h, 2.4)
		expect.equal(stateOf(h, visitId), "Departing")
		run(h, 0.2)
		expect.equal(visitOf(h, visitId), nil)
		expect.equal(claimCount(h, A), 0)
	end)

	t.test("a waiting customer leaves after 130 s", function()
		local h = harness()
		addCompany(h, A, PLOT_1, 1)
		local visitId = spawn(h, A, 8)
		runUntil(h, visitId, "WaitingAtCar", 200)
		run(h, 129.8)
		expect.equal(stateOf(h, visitId), "WaitingAtCar")
		run(h, 0.4)
		expect.equal(stateOf(h, visitId), "Departing")
	end)

	t.test("no matching stock sends the customer home", function()
		local h = harness()
		local state = addCompany(h, A, PLOT_1, 1)
		local visitId = spawn(h, A, 5)
		local abandoned = state.abandonedCustomers
		local visit = runUntil(h, visitId, "Departing", 100)
		local n = #visit.history
		expect.equal(visit.history[n - 2], "Browsing")
		expect.equal(visit.history[n - 1], "WalkingOut")
		expect.truthy(callIndex(h, "dismissCar", visitId))
		expect.equal(state.abandonedCustomers, abandoned + 1)
		expect.equal(next(state.reservations), nil)
	end)

	t.test("the budget caps NPCs per plot and server", function()
		local h = harness()
		for index = 1, 6 do
			addCompany(h, "save:" .. index, "Plot_0" .. index, 1)
		end
		for _ = 1, 4 do
			expect.equal(h.npc:arrivalPass(false), 6)
		end
		expect.equal(h.npc:count(), 24)
		expect.equal(h.npc:arrivalPass(false), 0)
		expect.equal(h.npc:count(), 24)
		for index = 1, 6 do
			expect.equal(h.npc:countOnPlot("Plot_0" .. index), 4)
		end

		local small = harness({ maxPerServer = 3 })
		for index = 1, 6 do
			addCompany(small, "save:" .. index, "Plot_0" .. index, 1)
		end
		expect.equal(small.npc:arrivalPass(false), 3)
		expect.equal(small.npc:arrivalPass(false), 0)
		expect.equal(small.npc:count(), 3)
	end)

	t.test("clearPlot removes only that plot", function()
		local h = harness()
		local stateA = addCompany(h, A, PLOT_1, 1)
		addCompany(h, B, PLOT_2, 1)
		local visitA = spawn(h, A, 8)
		local visitB = spawn(h, B, 8)
		runUntil(h, visitA, "WalkingToTree", 100)
		expect.truthy(stateA.reservations.douglas_1)
		expect.equal(claimCount(h, A), 1)
		h.npc:clearPlot(PLOT_1)
		expect.equal(visitOf(h, visitA), nil)
		expect.truthy(callIndex(h, "despawn", visitA))
		expect.truthy(callIndex(h, "destroyCar", visitA))
		expect.equal(claimCount(h, A), 0)
		expect.truthy(visitOf(h, visitB))
		expect.equal(callIndex(h, "despawn", visitB), nil)
		expect.equal(claimCount(h, B), 1)
		-- The reservation stays until the next sweep.
		expect.truthy(stateA.reservations.douglas_1)
		h.npc:arrivalPass(true)
		expect.equal(stateA.reservations.douglas_1, nil)
		expect.truthy(visitOf(h, visitB))
	end)

	t.test("an unloaded or reloaded session removes its NPCs", function()
		local h = harness()
		local state = addCompany(h, A, PLOT_1, 1)
		local first = spawn(h, A, 8)
		runUntil(h, first, "Browsing", 10)
		local abandoned = state.abandonedCustomers
		expect.truthy(h.service:unloadCompany(A))
		run(h, 0.2)
		expect.equal(h.npc:count(), 0)
		expect.equal(state.abandonedCustomers, abandoned)

		local reloaded = h.service:loadCompany(A, 42)
		local second = spawn(h, A, 8)
		runUntil(h, second, "Browsing", 10)
		local before = reloaded.abandonedCustomers
		expect.truthy(h.service:unloadCompany(A))
		expect.truthy(h.service:loadCompany(A, 42))
		run(h, 0.2)
		expect.equal(h.npc:count(), 0)
		expect.equal(reloaded.abandonedCustomers, before)
	end)

	t.test("shutdown stops arrivals and removes all", function()
		local h = harness()
		local state = addCompany(h, A, PLOT_1, 2)
		spawn(h, A, 8)
		h.npc:arrivalPass(false)
		expect.equal(h.npc:count(), 2)
		state.reservations.douglas_2 = { customerId = "visit:99", expiresAt = 2000, salePrice = 100 }
		h.npc:shutdown()
		expect.equal(h.npc:count(), 0)
		expect.equal(h.npc:arrivalPass(false), 0)
		expect.equal(state.reservations.douglas_2.customerId, "visit:99")
		local ok, code = h.npc:spawnForTest(A, 8)
		expect.falsy(ok)
		expect.equal(code, "NpcBudget")
		expect.equal(h.npc:spawnLoad(PLOT_1, 2), 0)
		run(h, 1)
		expect.equal(h.npc:count(), 0)
	end)

	t.test("a lost avatar counts as giving up", function()
		local h = harness()
		local state = addCompany(h, A, PLOT_1, 1)
		local visitId = spawn(h, A, 8)
		runUntil(h, visitId, "WalkingToTree", 100)
		expect.truthy(state.reservations.douglas_1)
		local abandoned = state.abandonedCustomers
		h.world.positions[visitId] = nil
		run(h, 0.2)
		expect.equal(stateOf(h, visitId), "Departing")
		expect.equal(state.reservations.douglas_1, nil)
		expect.equal(state.abandonedCustomers, abandoned + 1)
	end)

	t.test("the visit cap ends a long visit", function()
		local h = harness({ maxVisitSeconds = 5 })
		addCompany(h, A, PLOT_1, 1)
		local visitId = spawn(h, A, 8)
		run(h, 4.8)
		expect.equal(stateOf(h, visitId), "Browsing")
		run(h, 0.6)
		expect.equal(stateOf(h, visitId), "Departing")
	end)

	t.test("the queue serves in join order", function()
		local h = harness()
		addCompany(h, A, PLOT_1, 2)
		local one = spawn(h, A, 8)
		local two = spawn(h, A, 20)
		local queue = {}
		for _ = 1, 500 do
			queue = h.npc:queue(PLOT_1)
			if #queue == 2 then
				break
			end
			run(h, 0.2)
		end
		expect.equal(#queue, 2)
		local firstJoiner, secondJoiner = queue[1], queue[2]
		expect.truthy((firstJoiner == one and secondJoiner == two) or (firstJoiner == two and secondJoiner == one))
		runUntil(h, firstJoiner, "WaitingAtCar", 100)
		runUntil(h, secondJoiner, "WaitingAtCar", 100)
		local first, second = visitOf(h, firstJoiner), visitOf(h, secondJoiner)
		expect.truthy(first.orderNumber < second.orderNumber)
		local slot1, slot2 = NpcPath.queueSlot(1), NpcPath.queueSlot(2)
		local sawSlot2, sawSlot1After = false, false
		for _, call in ipairs(h.world.calls) do
			if call.name == "moveTo" and call.args[1] == secondJoiner then
				local p = call.args[2]
				if p.x == slot2.x and p.z == slot2.z then
					sawSlot2 = true
				elseif sawSlot2 and p.x == slot1.x and p.z == slot1.z then
					sawSlot1After = true
				end
			end
		end
		expect.truthy(sawSlot2)
		expect.truthy(sawSlot1After)
	end)

	t.test("a load NPC loops without company state", function()
		local h = harness()
		local state = addCompany(h, A, PLOT_1, 1)
		local revision = state.revision
		expect.equal(h.npc:spawnLoad(PLOT_1, 2, 10), 2)
		local snapshot = h.npc:snapshot()
		expect.equal(snapshot.count, 2)
		for index, visit in ipairs(snapshot.visits) do
			expect.equal(visit.state, "LoadLoop")
			expect.truthy(visit.loadTest)
			expect.equal(string.sub(visit.visitId, 1, 5), "load:")
			local spawned = h.world.calls[callIndex(h, "spawnAvatar", visit.visitId) :: number]
			local door = NpcPath.door(index)
			expect.equal(spawned.args[4].x, door.x)
			expect.equal(spawned.args[4].z, door.z)
		end
		expect.equal(callIndex(h, "spawnCar"), nil)
		run(h, 9.8)
		expect.equal(h.npc:snapshot().visits[1].state, "LoadLoop")
		run(h, 0.2)
		expect.equal(h.npc:snapshot().visits[1].state, "Departing")
		run(h, 2.4)
		expect.equal(h.npc:count(), 2)
		run(h, 0.2)
		expect.equal(h.npc:count(), 0)
		expect.equal(h.npc:clearLoad(), 0)
		expect.equal(state.revision, revision)
		expect.equal(claimCount(h, A), 0)
	end)

	t.test("a plot that no longer maps to the company removes its NPCs", function()
		local h = harness()
		addCompany(h, A, PLOT_1, 1)
		local visitId = spawn(h, A, 8)
		runUntil(h, visitId, "Browsing", 10)
		h.plots[A] = PLOT_2
		run(h, 0.2)
		expect.equal(h.npc:count(), 0)
		expect.truthy(callIndex(h, "despawn", visitId))
		expect.truthy(callIndex(h, "destroyCar", visitId))
		h.plots[A] = nil
		local ok, code = h.npc:spawnForTest(A, 8)
		expect.falsy(ok)
		expect.equal(code, "CompanyUnavailable")
	end)

	t.test("load NPCs use the budget and clearLoad removes them", function()
		local h = harness()
		addCompany(h, A, PLOT_1, 1)
		local customer = spawn(h, A, 8)
		expect.equal(h.npc:spawnLoad(PLOT_1, 4), 3)
		local doors = {}
		for _, call in ipairs(h.world.calls) do
			if call.name == "spawnAvatar" then
				table.insert(doors, call.args[4])
			end
		end
		expect.equal(#doors, 3)
		for index, door in ipairs(doors) do
			expect.equal(door.x, NpcPath.door(index).x)
		end
		expect.equal(h.npc:clearLoad(), 3)
		expect.equal(h.npc:count(), 1)
		expect.truthy(visitOf(h, customer))
	end)

	t.test("a failed checkout counts one abandonment", function()
		local h = harness()
		local state = addCompany(h, A, PLOT_1, 1)
		local visitId = spawn(h, A, 8)
		runUntil(h, visitId, "CheckingOut", 100)
		local abandoned = state.abandonedCustomers
		h.clock += GameConfig.Customers.Npc.ReservationSeconds + 1
		local visit = runUntil(h, visitId, "WalkingOut", 10)
		expect.equal(visit.history[#visit.history - 1], "CheckingOut")
		expect.equal(state.abandonedCustomers, abandoned + 1)
		expect.equal(next(state.reservations), nil)
		expect.equal(#h.service:getCustomerOrders(A).orders, 0)
		run(h, 10)
		expect.equal(visitOf(h, visitId), nil)
		expect.equal(state.abandonedCustomers, abandoned + 1)
		expect.equal(state.walkedOutCustomers, 0)
		expect.equal(state.sales, 0)
	end)

	-- Fix round 1 (F5): corners do not get cut, and a stopped avatar still moves on.
	t.test("corners advance within CornerRadius or once stopped", function()
		local h = harness(nil, false, 1.2)
		expect.equal(h.npc:spawnLoad(PLOT_1, 1), 1)
		local visitId = h.npc:snapshot().visits[1].visitId
		local visit = (h.npc :: any)._visits[visitId]
		for _ = 1, 50 do
			if visit.loadLeg == 2 then
				break
			end
			run(h, 0.2)
		end
		expect.equal(visit.loadLeg, 2)
		expect.equal(#visit.waypoints, 2)
		expect.equal(visit.waypoints[1].x, 11)
		expect.equal(visit.waypoints[1].z, 11)
		expect.equal(visit.waypointIndex, 1)
		run(h, 0.2)
		expect.equal(visit.waypointIndex, 1)
		run(h, 0.2)
		expect.equal(visit.waypointIndex, 2)
		run(h, 10)
		expect.equal(visit.snaps, 0)
		expect.equal(h.npc:snapshot().loadSnaps, 0)
	end)

	t.test("an arrival override applies to the next real arrival only", function()
		local h = harness()
		addCompany(h, A, PLOT_1, 2)
		h.npc:setArrivalOverrideForTest(A, 8)
		expect.equal(h.npc:arrivalPass(false), 1)
		local first = h.npc:snapshot().visits[1]
		expect.equal(first.customerNumber, 8)
		runUntil(h, first.visitId, "WalkingToTree", 100)
		expect.equal(h.npc:arrivalPass(false), 1)
		local snapshot = h.npc:snapshot()
		expect.equal(snapshot.count, 2)
		expect.equal(snapshot.visits[2].customerNumber, 1)
	end)

	t.test("resetForTest removes a company's visits at once", function()
		local h = harness()
		local stateA = addCompany(h, A, PLOT_1, 2)
		addCompany(h, B, PLOT_2, 1)
		local reservedVisit = spawn(h, A, 8)
		local visitB = spawn(h, B, 8)
		runUntil(h, reservedVisit, "WalkingToTree", 100)
		local otherVisit = spawn(h, A, 20)
		expect.truthy(next(stateA.reservations) ~= nil)
		expect.equal(claimCount(h, A), 2)
		expect.equal(h.npc:resetForTest(A), 2)
		for _, visitId in ipairs({ reservedVisit, otherVisit }) do
			expect.equal(visitOf(h, visitId), nil)
			expect.truthy(callIndex(h, "despawn", visitId))
			expect.truthy(callIndex(h, "destroyCar", visitId))
		end
		expect.equal(next(stateA.reservations), nil)
		expect.equal(claimCount(h, A), 0)
		expect.truthy(visitOf(h, visitB))
		expect.equal(callIndex(h, "despawn", visitB), nil)
		expect.equal(claimCount(h, B), 1)
		expect.equal(h.npc:resetForTest(), 1)
		expect.equal(h.npc:count(), 0)
	end)

	-- CM2-G12a: arrival credit per company; each pass adds the rate and an arrival needs 1.
	t.test("night arrival rate halves arrivals", function()
		local h = harness()
		h.rate = 0.5
		addCompany(h, A, PLOT_1, 4)
		expect.equal(h.npc:arrivalPass(false), 1)
		expect.equal(h.npc:arrivalPass(false), 0)
		expect.equal(h.npc:arrivalPass(false), 1)
		expect.equal(h.npc:arrivalPass(false), 0)
		expect.equal(h.npc:count(), 2)
	end)

	t.test("a refused arrival keeps its credit", function()
		local h = harness()
		h.rate = 0.5
		local state = addCompany(h, A, PLOT_1, 0)
		expect.equal(h.npc:arrivalPass(false), 0)
		expect.equal(h.npc:arrivalPass(false), 0)
		for index = 1, 2 do
			state.layout.placements["douglas_" .. index] = {
				speciesId = "DouglasFir",
				sizeId = "Medium",
				transform = { x = -35 + 7 * index, y = 0, z = -20, rotation = 0 },
			}
		end
		expect.equal(h.npc:arrivalPass(false), 1)
		expect.equal(h.npc:count(), 1)
	end)

	-- CM2-SALE1: on the tutorial's Checkout step a live arrival buys even with a high roll.
	t.test("a live tutorial arrival buys with a random roll (CM2-SALE1)", function()
		local h = harness()
		local state = addCompany(h, A, PLOT_1, 1)
		state.tutorial = { step = "Checkout", skipped = false }
		h.roll = 0.99
		local cash0 = state.cash
		expect.equal(h.npc:arrivalPass(false), 1)
		local first = h.npc:snapshot().visits[1]
		expect.equal(first.customerNumber, 1)
		runUntil(h, first.visitId, "WaitingAtCar", 200)
		expect.equal(state.sales, 1)
		expect.equal(state.cash, cash0 + 140)
		expect.equal(state.tutorial.step, "Done")
		local entry = h.npc:snapshot().decisionLog[1]
		expect.equal(entry.decision, "Reserved")
		expect.equal(entry.visitId, first.visitId)
	end)

	t.test("the decision log records each pick and resetForTest clears it (CM2-SALE1)", function()
		local h = harness()
		addCompany(h, A, PLOT_1, 1)
		-- profile 5's budget (99 %) is below every benchmark price (CM2-SALE2 soft preferences)
		local first = spawn(h, A, 5)
		runUntil(h, first, "Departing", 100)
		local second = spawn(h, A, 8)
		runUntil(h, second, "WalkingToTree", 100)
		local log = h.npc:snapshot().decisionLog
		expect.equal(#log, 2)
		expect.equal(log[1].visitId, first)
		expect.equal(log[1].customerNumber, 5)
		expect.equal(log[1].decision, "NoEligibleStock")
		expect.equal(log[1].placementId, nil)
		expect.equal(log[2].visitId, second)
		expect.equal(log[2].customerNumber, 8)
		expect.equal(log[2].decision, "Reserved")
		expect.equal(log[2].placementId, "douglas_1")
		expect.equal(log[2].salePrice, 140)
		expect.equal(visitOf(h, second).decision, "Reserved")
		h.npc:resetForTest(A)
		expect.equal(#h.npc:snapshot().decisionLog, 0)
	end)
end

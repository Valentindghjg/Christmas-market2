--!strict
-- CM2-N2: the counter of the walking customer director, headless. The player checks out the
-- customer at the counter (checkout), the Cashier on duty serves it after CashierCheckoutSeconds
-- (CM2-25/26: a fake staff director answers cashierReady), and settlement happens exactly once. Same harness as CustomerNpcService_Test: the fake
-- world records every call and moveTo puts the avatar on the target at once; ticks run in
-- 0.2-s steps of a fake clock; the company service has its own (integer) clock.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local NpcPath = require(Shared:WaitForChild("NpcPath"))
	local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
	local CompanyStateService = require(Services:WaitForChild("CompanyStateService"))
	local CustomerNpcService = require(Services:WaitForChild("CustomerNpcService"))
	local expect = t.expect

	local A, B = "save:a", "save:b"
	local PLOT_1, PLOT_2 = "Plot_01", "Plot_02"

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

	local function fakeWorld()
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
			if self.positions[visitId] then
				self.positions[visitId] = copy(p)
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

	local function harness()
		local h = { ticks = 0, clock = 1000 }
		h.world = fakeWorld()
		h.service = CompanyStateService.new(fakePersistence(), function()
			return h.clock
		end, function()
			return 0
		end)
		h.plots = {}
		-- CM2-25/26: the staff director's answer per company (true = a Cashier on duty).
		h.cashierReady = {}
		h.npc = CustomerNpcService.new({
			companies = h.service,
			plotOf = function(companyId)
				return h.plots[companyId]
			end,
			world = h.world,
			now = function()
				return h.ticks / 5
			end,
			staff = {
				cashierReady = function(_, companyId)
					return h.cashierReady[companyId] == true
				end,
			},
		})
		h.service:setCustomerOrdersChangedHandler(function(companyId, summary)
			table.insert(h.world.calls, { name = "ordersChanged", args = { companyId } })
			h.npc:onOrdersChanged(companyId, summary)
		end)
		return h
	end

	local function addCompany(h, companyId: string, plotId: string, trees: number, cashier: number)
		local state = h.service:loadCompany(companyId, 42)
		state.progression.parkingTier = 2
		state.staff.Cashier = cashier
		h.cashierReady[companyId] = cashier >= 1
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

	local function lastCall(h, name: string)
		for index = #h.world.calls, 1, -1 do
			local call = h.world.calls[index]
			if call.name == name then
				return call
			end
		end
		return nil
	end

	t.test("the counter waits for a player without a Cashier", function()
		local h = harness()
		local state = addCompany(h, A, PLOT_1, 1, 0)
		local visitId = spawn(h, A, 8)
		runUntil(h, visitId, "CheckingOut", 100)
		run(h, 10)
		expect.equal(stateOf(h, visitId), "CheckingOut")
		expect.equal(state.sales, 0)
		local shown = lastCall(h, "showCheckout")
		expect.truthy(shown ~= nil)
		expect.equal(shown.args[1], PLOT_1)
		local info = shown.args[2]
		expect.truthy(info ~= nil)
		expect.equal(info.placementId, "douglas_1")
		expect.equal(info.speciesId, "DouglasFir")
		expect.equal(info.sizeId, "Medium")
		expect.equal(info.price, state.reservations.douglas_1.salePrice)
		local faced = lastCall(h, "face")
		expect.truthy(faced ~= nil)
		expect.equal(faced.args[1], visitId)
		local staff = NpcPath.staffPoint()
		expect.equal(faced.args[2].x, staff.x)
		expect.equal(faced.args[2].z, staff.z)
		expect.equal(staff.x, -14)
		expect.equal(staff.z, 14)
	end)

	t.test("a player checkout settles exactly once", function()
		local h = harness()
		local state = addCompany(h, A, PLOT_1, 1, 0)
		local visitId = spawn(h, A, 8)
		runUntil(h, visitId, "CheckingOut", 100)
		local price = state.reservations.douglas_1.salePrice
		local cash, sales = state.cash, state.sales
		local ok = h.npc:checkout(A, PLOT_1)
		expect.truthy(ok)
		local again, code = h.npc:checkout(A, PLOT_1)
		expect.falsy(again)
		expect.equal(code, "NoCustomer")
		expect.equal(state.sales, sales + 1)
		expect.equal(state.cash, cash + price)
		expect.equal(stateOf(h, visitId), "WalkingToCar")
		expect.equal((lastCall(h, "showCheckout") :: any).args[2], nil)
		expect.equal(#h.service:getCustomerOrders(A).orders, 1)
	end)

	t.test("a re-entrant checkout is refused while settling", function()
		local h = harness()
		local state = addCompany(h, A, PLOT_1, 1, 0)
		local visitId = spawn(h, A, 8)
		runUntil(h, visitId, "CheckingOut", 100)
		local sales = state.sales
		local service = h.service :: any
		local original = service.npcSettle
		local inner = nil
		service.npcSettle = function(self, ...)
			if inner == nil then
				inner = table.pack(h.npc:checkout(A, PLOT_1))
			end
			return original(self, ...)
		end
		local outer = h.npc:checkout(A, PLOT_1)
		expect.truthy(inner ~= nil)
		expect.falsy(inner[1])
		expect.equal(inner[2], "CheckoutBusy")
		expect.truthy(outer)
		expect.equal(state.sales, sales + 1)
	end)

	t.test("the player serves the queue in join order", function()
		local h = harness()
		local state = addCompany(h, A, PLOT_1, 2, 0)
		spawn(h, A, 8)
		spawn(h, A, 20)
		local queue = {}
		for _ = 1, 1000 do
			queue = h.npc:queue(PLOT_1)
			if #queue == 2 and stateOf(h, queue[1]) == "CheckingOut" and stateOf(h, queue[2]) == "Queued" then
				break
			end
			run(h, 0.2)
		end
		expect.equal(#queue, 2)
		local first, second = queue[1], queue[2]
		expect.equal(stateOf(h, first), "CheckingOut")
		expect.equal(stateOf(h, second), "Queued")
		local cash, sales = state.cash, state.sales
		local p1 = (visitOf(h, first) :: any).salePrice
		expect.truthy(h.npc:checkout(A, PLOT_1))
		expect.equal(stateOf(h, first), "WalkingToCar")
		runUntil(h, second, "CheckingOut", 20)
		local p2 = (visitOf(h, second) :: any).salePrice
		expect.truthy(h.npc:checkout(A, PLOT_1))
		local one, two = visitOf(h, first) :: any, visitOf(h, second) :: any
		expect.truthy(one.orderNumber < two.orderNumber)
		expect.equal(state.sales, sales + 2)
		expect.equal(state.cash, cash + p1 + p2)
	end)

	t.test("another save cannot check out on this plot", function()
		local h = harness()
		local stateA = addCompany(h, A, PLOT_1, 1, 0)
		local stateB = addCompany(h, B, PLOT_2, 0, 0)
		local visitId = spawn(h, A, 8)
		runUntil(h, visitId, "CheckingOut", 100)
		local ok, code = h.npc:checkout(B, PLOT_1)
		expect.falsy(ok)
		expect.equal(code, "Forbidden")
		ok, code = h.npc:checkout(A, PLOT_2)
		expect.falsy(ok)
		expect.equal(code, "Forbidden")
		ok, code = h.npc:checkout(B, PLOT_2)
		expect.falsy(ok)
		expect.equal(code, "NoCustomer")
		expect.equal(stateOf(h, visitId), "CheckingOut")
		expect.equal(stateA.sales, 0)
		expect.equal(stateB.sales, 0)
	end)

	t.test("a Cashier serves after CashierCheckoutSeconds", function()
		local h = harness()
		local state = addCompany(h, A, PLOT_1, 1, 1)
		local visitId = spawn(h, A, 8)
		runUntil(h, visitId, "CheckingOut", 100)
		local sales = state.sales
		run(h, 2.8)
		expect.equal(stateOf(h, visitId), "CheckingOut")
		run(h, 0.4)
		expect.equal(stateOf(h, visitId), "WalkingToCar")
		expect.equal(state.sales, sales + 1)
	end)

	-- CM2-N2 Amendment 1: the hired Cashier serves every customer at the counter in turn.
	t.test("a Cashier serves a queue of two without walk-outs", function()
		local h = harness()
		local state = addCompany(h, A, PLOT_1, 2, 1)
		local ids = { spawn(h, A, 8), spawn(h, A, 20) }
		local sales, walkedOut = state.sales, state.walkedOutCustomers
		local joined: { string } = {}
		local sold: { [string]: boolean } = {}
		local numbers: { [string]: number } = {}
		for _ = 1, 120 * 5 do
			for _, queued in ipairs(h.npc:queue(PLOT_1)) do
				if table.find(joined, queued) == nil then
					table.insert(joined, queued)
				end
			end
			for _, visitId in ids do
				local visit = (h.npc :: any)._visits[visitId]
				if visit and visit.sold then
					sold[visitId] = true
					numbers[visitId] = visit.orderNumber
				end
			end
			if sold[ids[1]] and sold[ids[2]] then
				break
			end
			run(h, 0.2)
		end
		expect.truthy(sold[ids[1]])
		expect.truthy(sold[ids[2]])
		expect.equal(state.sales, sales + 2)
		expect.equal(state.walkedOutCustomers, walkedOut)
		expect.equal(#joined, 2)
		local first, second = numbers[joined[1]], numbers[joined[2]]
		expect.truthy(first ~= nil and second ~= nil)
		expect.truthy(first < second)
	end)

	-- CM2-25/26: a hired Cashier away from the counter (walking, resting) serves nobody.
	t.test("a customer walks out while the Cashier rests", function()
		local h = harness()
		local state = addCompany(h, A, PLOT_1, 1, 1)
		h.cashierReady[A] = false
		local visitId = spawn(h, A, 8)
		local visit = runUntil(h, visitId, "Queued", 100)
		expect.truthy(visit ~= nil)
		local walkedOut, sales = state.walkedOutCustomers, state.sales
		run(h, 89.8)
		expect.equal(stateOf(h, visitId), "CheckingOut")
		run(h, 0.4)
		expect.equal(stateOf(h, visitId), "WalkingOut")
		expect.equal(state.walkedOutCustomers, walkedOut + 1)
		expect.equal(state.sales, sales)
	end)

	t.test("a lost avatar at the counter is not a walk-out", function()
		local h = harness()
		local state = addCompany(h, A, PLOT_1, 1, 0)
		local visitId = spawn(h, A, 8)
		runUntil(h, visitId, "CheckingOut", 100)
		local abandoned, walkedOut = state.abandonedCustomers, state.walkedOutCustomers
		h.world.positions[visitId] = nil
		run(h, 0.2)
		expect.equal(stateOf(h, visitId), "Departing")
		expect.equal(state.reservations.douglas_1, nil)
		expect.equal(state.abandonedCustomers, abandoned + 1)
		expect.equal(state.walkedOutCustomers, walkedOut)
		expect.equal((lastCall(h, "showCheckout") :: any).args[2], nil)
	end)

	t.test("a hard remove at the counter hides the prompt", function()
		local h = harness()
		local state = addCompany(h, A, PLOT_1, 1, 0)
		local visitId = spawn(h, A, 8)
		runUntil(h, visitId, "CheckingOut", 100)
		h.npc:clearPlot(PLOT_1)
		expect.equal(visitOf(h, visitId), nil)
		local hidden = lastCall(h, "showCheckout") :: any
		expect.equal(hidden.args[1], PLOT_1)
		expect.equal(hidden.args[2], nil)
		expect.equal(state.sales, 0)
		expect.equal(state.walkedOutCustomers, 0)
	end)
end

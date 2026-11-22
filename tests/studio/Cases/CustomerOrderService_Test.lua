--!strict
-- G1 customer car loading and G2 parking-limited arrivals.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
	local Orders = require(Services:WaitForChild("CustomerOrderService"))
	local Simulation = require(Services:WaitForChild("CustomerSimulationService"))
	local CompanyStateService = require(Services:WaitForChild("CompanyStateService"))
	local expect = t.expect

	-- A settled sale as CustomerService returns it; keeps order tests independent of
	-- which tree a generated customer profile prefers.
	local function addOrder(state, placementId: string, timestamp: number)
		local created, order = Orders.createFromSale(
			state,
			{ placementId = placementId, speciesId = "FrasierFir", sizeId = "Medium", salePrice = 82 },
			timestamp
		)
		expect.truthy(created)
		return order
	end

	local function stateWithSale()
		local state = BusinessState.new("personal:42", 42)
		return state, addOrder(state, "placement:sale", 100)
	end

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

	local function request(id: string, action: string, payload)
		return { version = 1, requestId = id, action = action, payload = payload }
	end

	t.test("a simulated sale creates a numbered order at a parking space", function()
		local state = BusinessState.new("personal:42", 42)
		state.layout.placements.fir_sale = { speciesId = "FrasierFir", sizeId = "Small" }
		local started, visit = Simulation.beginVisit(state, 1, 100, 0)
		expect.truthy(started)
		local sold, sale = Simulation.completeVisit(state, visit, 100)
		expect.truthy(sold)
		local order = sale.order
		expect.equal(order.orderNumber, 1)
		expect.equal(order.parkingSpace, 1)
		expect.equal(state.nextOrderNumber, 2)
		expect.truthy(state.customerOrders["1"])
		expect.truthy(order.heightTenths >= 50 and order.heightTenths <= 60)
		expect.truthy(BusinessState.validate(state))
	end)

	t.test("loads exactly once and rewards fast service", function()
		local state, order = stateWithSale()
		local reputation = state.reputation
		expect.truthy(Orders.carry(state, 42, order.orderNumber))
		local loaded, result = Orders.load(state, 42, order.orderNumber, order.orderNumber, 110)
		expect.truthy(loaded)
		expect.equal(result.reputationGain, GameConfig.Customers.FastLoadReputation)
		expect.equal(state.reputation, reputation + GameConfig.Customers.FastLoadReputation)
		expect.equal(state.loadedOrders, 1)
		local again, reason = Orders.load(state, 42, order.orderNumber, order.orderNumber, 111)
		expect.falsy(again)
		expect.equal(reason, "UnknownOrder")
		expect.equal(state.loadedOrders, 1)
	end)

	t.test("slow loading earns less reputation", function()
		local state, order = stateWithSale()
		local reputation = state.reputation
		expect.truthy(Orders.carry(state, 42, order.orderNumber))
		local timestamp = 100 + GameConfig.Customers.FastLoadSeconds + 1
		local _, result = Orders.load(state, 42, order.orderNumber, order.orderNumber, timestamp)
		expect.equal(result.reputationGain, GameConfig.Customers.SlowLoadReputation)
		expect.equal(state.reputation, reputation + GameConfig.Customers.SlowLoadReputation)
	end)

	t.test("rejects the wrong car without completing", function()
		local state, order = stateWithSale()
		expect.truthy(Orders.carry(state, 42, order.orderNumber))
		local ok, reason = Orders.load(state, 42, order.orderNumber, order.orderNumber + 1, 110)
		expect.falsy(ok)
		expect.equal(reason, "WrongCar")
		expect.truthy(state.customerOrders[tostring(order.orderNumber)])
		expect.equal(state.loadedOrders, 0)
	end)

	t.test("only the carrying player can load and hands hold one tree", function()
		local state, first = stateWithSale()
		local second = addOrder(state, "placement:second", 101)
		expect.equal(second.parkingSpace, 2)
		expect.falsy(Orders.load(state, 42, first.orderNumber, first.orderNumber, 110))
		expect.truthy(Orders.carry(state, 42, first.orderNumber))
		local busy, busyReason = Orders.carry(state, 42, second.orderNumber)
		expect.falsy(busy)
		expect.equal(busyReason, "HandsFull")
		local taken, takenReason = Orders.carry(state, 7, first.orderNumber)
		expect.falsy(taken)
		expect.equal(takenReason, "AlreadyCarried")
		local stolen, stolenReason = Orders.load(state, 7, first.orderNumber, first.orderNumber, 110)
		expect.falsy(stolen)
		expect.equal(stolenReason, "NotCarrying")
		expect.truthy(Orders.release(state, 42, first.orderNumber))
		expect.truthy(Orders.carry(state, 42, second.orderNumber))
	end)

	t.test("an impatient customer leaves with a reputation penalty", function()
		local state, order = stateWithSale()
		local reputation = state.reputation
		expect.equal(Orders.expire(state, order.expiresAt - 1), 0)
		expect.equal(Orders.expire(state, order.expiresAt), 1)
		expect.equal(state.customerOrders[tostring(order.orderNumber)], nil)
		expect.equal(state.missedPickups, 1)
		expect.equal(state.reputation, reputation - GameConfig.Customers.MissedPickupReputationPenalty)
	end)

	t.test("a lot worker loads uncarried orders after the walk", function()
		local state, order = stateWithSale()
		expect.equal(Orders.autoLoad(state, 200), 0)
		state.staff.LotWorker = 1
		expect.equal(Orders.autoLoad(state, order.soldAt + GameConfig.Customers.WorkerLoadSeconds - 1), 0)
		expect.equal(Orders.autoLoad(state, order.soldAt + GameConfig.Customers.WorkerLoadSeconds), 1)
		expect.equal(state.loadedOrders, 1)
	end)

	t.test("a reload clears carried trees", function()
		local state, order = stateWithSale()
		expect.truthy(Orders.carry(state, 42, order.orderNumber))
		local migrated = BusinessState.migrate(state, "personal:42", 42)
		expect.truthy(migrated)
		expect.equal(migrated.customerOrders[tostring(order.orderNumber)].carriedBy, nil)
	end)

	-- CM2-N1: a walking customer's order waits in the space its car parked in.
	t.test("an order takes the given parking space", function()
		local state = BusinessState.new("personal:42", 42)
		state.progression.parkingSpaces = 4
		local sale = { placementId = "placement:a", speciesId = "FrasierFir", sizeId = "Medium", salePrice = 82 }
		local created, order = Orders.createFromSale(state, sale, 100, 3)
		expect.truthy(created)
		expect.equal(order.parkingSpace, 3)
		local again = { placementId = "placement:b", speciesId = "FrasierFir", sizeId = "Medium", salePrice = 82 }
		local createdAgain, second = Orders.createFromSale(state, again, 100, 3)
		expect.truthy(createdAgain)
		expect.equal(second.parkingSpace, 1)
	end)

	t.test("claimed spaces count and are skipped", function()
		local state = BusinessState.new("personal:42", 42)
		local claims = { [1] = "visit:1" }
		expect.equal(Orders.parkingSpaces(state), 2)
		expect.equal(Orders.activeCustomers(state, claims), 1)
		expect.equal(Orders.freeParking(state, claims), 1)
		local sale = { placementId = "placement:a", speciesId = "FrasierFir", sizeId = "Medium", salePrice = 82 }
		local created, order = Orders.createFromSale(state, sale, 100, nil, claims)
		expect.truthy(created)
		expect.equal(order.parkingSpace, 2)
	end)

	t.test("parking limits waiting customers and full lots make cars drive past", function()
		local service = CompanyStateService.new(fakePersistence(), function()
			return 100
		end, function()
			return 0
		end)
		local state = service:loadCompany("personal:42", 42)
		for index = 1, 3 do
			state.layout.placements["fir_" .. index] = { speciesId = "FrasierFir", sizeId = "Small" }
			state.layout.placements["noble_" .. index] = { speciesId = "NobleFir", sizeId = "Small" }
		end
		state.staff.Cashier = 1
		local _, sales = service:simulateCustomerVisits()
		expect.equal(sales, GameConfig.Customers.BaseParkingSpaces)
		expect.equal(Orders.activeCustomers(state), GameConfig.Customers.BaseParkingSpaces)
		-- A full lot records a drive-past without bumping the revision.
		local revision = state.revision
		local _, none = service:simulateCustomerVisits()
		expect.equal(none, 0)
		expect.equal(state.revision, revision)
		expect.equal(state.sales, GameConfig.Customers.BaseParkingSpaces)
		expect.equal(state.drivePastCustomers, 1)
		-- Parking upgrades raise the number of cars that can wait.
		state.progression.parkingSpaces = 4
		expect.equal(Orders.freeParking(state), 2)
	end)

	t.test("carry and load through the authoritative action protocol", function()
		local service = CompanyStateService.new(fakePersistence(), function()
			return 100
		end, function()
			return 0
		end)
		local synced = 0
		service:setCustomerOrdersChangedHandler(function()
			synced += 1
		end)
		local state = service:loadCompany("personal:42", 42)
		state.layout.placements.fir = { speciesId = "FrasierFir", sizeId = "Small" }
		service:simulateCustomerVisits()
		expect.equal(synced, 1)
		local carry = service:handle("personal:42", 42, request("carry_0001", "Order.Carry", { orderNumber = 1 }))
		expect.truthy(carry.ok)
		-- Another player's company cannot touch this order.
		local foreign =
			service:handle("personal:42", 77, request("foreign_001", "Order.Load", { orderNumber = 1, carNumber = 1 }))
		expect.equal(foreign.errorCode, "Forbidden")
		local wrong =
			service:handle("personal:42", 42, request("wrong_0001", "Order.Load", { orderNumber = 1, carNumber = 2 }))
		expect.equal(wrong.errorCode, "WrongCar")
		local load =
			service:handle("personal:42", 42, request("load_00001", "Order.Load", { orderNumber = 1, carNumber = 1 }))
		expect.truthy(load.ok)
		local replay =
			service:handle("personal:42", 42, request("load_00001", "Order.Load", { orderNumber = 1, carNumber = 1 }))
		expect.equal(replay.errorCode, "DuplicateRequest")
		expect.equal(state.loadedOrders, 1)
		expect.equal(synced, 3)
	end)

	t.test("releases a respawned player's carried tree", function()
		local service = CompanyStateService.new(fakePersistence(), function()
			return 100
		end, function()
			return 0
		end)
		local state = service:loadCompany("personal:42", 42)
		state.layout.placements.fir = { speciesId = "FrasierFir", sizeId = "Small" }
		service:simulateCustomerVisits()
		expect.truthy(service:handle("personal:42", 42, request("carry_0002", "Order.Carry", { orderNumber = 1 })).ok)
		expect.equal(service:releaseCarried("personal:42", 42), 1)
		expect.equal(state.customerOrders["1"].carriedBy, nil)
	end)

	t.test("expires orders through the server pass", function()
		local clock = 100
		local service = CompanyStateService.new(fakePersistence(), function()
			return clock
		end, function()
			return 0
		end)
		local state = service:loadCompany("personal:42", 42)
		state.layout.placements.fir = { speciesId = "FrasierFir", sizeId = "Small" }
		service:simulateCustomerVisits()
		clock += GameConfig.Customers.PickupPatienceSeconds
		local ok, changed = service:serviceCustomerOrdersAll()
		expect.truthy(ok)
		expect.equal(changed, 1)
		expect.equal(state.missedPickups, 1)
	end)
	t.test("looks up the carried order from the authoritative record", function()
		local service = CompanyStateService.new(fakePersistence(), function()
			return 100
		end, function()
			return 0
		end)
		local state = service:loadCompany("personal:42", 42)
		expect.equal(service:getCarriedOrderNumber("personal:42", 42), nil)
		local order = addOrder(state, "placement:carried", 100)
		expect.truthy(Orders.carry(state, 42, order.orderNumber))
		expect.equal(service:getCarriedOrderNumber("personal:42", 42), order.orderNumber)
	end)

	t.test("reports which orders a lot worker loaded", function()
		local state, order = stateWithSale()
		state.staff.LotWorker = 1
		local count, numbers = Orders.autoLoad(state, order.soldAt + GameConfig.Customers.WorkerLoadSeconds)
		expect.equal(count, 1)
		expect.equal(numbers[1], order.orderNumber)
	end)

	t.test("a reload trims orders beyond the configured maximum", function()
		local state = BusinessState.new("personal:42", 42)
		for index = 1, GameConfig.Customers.MaxOpenCustomerOrders + 2 do
			state.customerOrders[tostring(index)] = {
				orderNumber = index,
				speciesId = "FrasierFir",
				sizeId = "Small",
				heightTenths = 55,
				salePrice = 66,
				soldAt = 100,
				expiresAt = 200,
				parkingSpace = 1,
			}
		end
		state.nextOrderNumber = GameConfig.Customers.MaxOpenCustomerOrders + 3
		state.supplier.stock["FrasierFir:Small"] = 5000
		local migrated, reason = BusinessState.migrate(state, "personal:42", 42)
		expect.truthy(migrated)
		expect.equal(reason, nil)
		expect.equal(migrated.customerOrders[tostring(GameConfig.Customers.MaxOpenCustomerOrders + 1)], nil)
		expect.truthy(migrated.customerOrders["1"])
		expect.equal(migrated.supplier.stock["FrasierFir:Small"], 1000)
	end)

	t.test("parking purchases add to the base spaces", function()
		local Progression = require(Services:WaitForChild("ProgressionService"))
		local state = BusinessState.new("personal:42", 42)
		state.cash = 10000
		local ok, spaces = Progression.buyParking(state)
		expect.truthy(ok)
		expect.equal(spaces, GameConfig.Customers.BaseParkingSpaces + 1)
		expect.equal(Orders.parkingSpaces(state), GameConfig.Customers.BaseParkingSpaces + 1)
		expect.truthy(Progression.buyParking(state))
		local maxed, reason = Progression.buyParking(state)
		expect.falsy(maxed)
		expect.equal(reason, "MaxParking")
	end)
end

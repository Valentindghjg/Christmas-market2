--!strict
-- CM2-49: the guided tutorial's server-owned progress (shared/Tutorial.lua, schema 18), its
-- advancement through the services and the validated Tutorial.Skip action.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local Tutorial = require(Shared:WaitForChild("Tutorial"))
	local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
	local CompanyStateService = require(Services:WaitForChild("CompanyStateService"))
	local PersistenceService = require(Services:WaitForChild("PersistenceService"))
	local PlacementService = require(Services:WaitForChild("PlacementService"))
	local expect = t.expect

	local COMPANY = "personal:42"

	local function deepCopy(value)
		if type(value) ~= "table" then
			return value
		end
		local copy = {}
		for key, inner in pairs(value) do
			copy[key] = deepCopy(inner)
		end
		return copy
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

	-- Deep-copies on read and write like a real DataStore.
	local function copyingStore()
		local store: any = { records = {} }
		function store.UpdateAsync(_, key: string, transform)
			local nextValue = transform(deepCopy(store.records[key]))
			if nextValue ~= nil then
				store.records[key] = deepCopy(nextValue)
			end
			return deepCopy(store.records[key])
		end
		return store
	end

	local function noWait() end

	local requestNumber = 0
	local function request(action: string, payload: any?, requestId: string?)
		requestNumber += 1
		return {
			version = 1,
			requestId = requestId or string.format("tutorial_req_%06d", requestNumber),
			action = action,
			payload = payload or {},
		}
	end

	local function withStep(step: string)
		local state = BusinessState.new(COMPANY, 42)
		state.tutorial = { step = step, skipped = false }
		return state
	end

	t.test("a new save is done unless the tutorial is offered", function()
		local fresh = BusinessState.new()
		expect.equal(fresh.tutorial.step, "Done")
		expect.equal(fresh.tutorial.skipped, false)
		expect.equal(Tutorial.attribute(fresh), "Done")
		local offered = Tutorial.new(true)
		expect.equal(offered.step, "Order")
		expect.equal(offered.skipped, false)
		expect.equal(Tutorial.attribute({ tutorial = offered }), "Order")
	end)

	t.test("advances step by step and catches up", function()
		local state = withStep("Order")
		expect.truthy(Tutorial.advance(state, "Ordered"))
		expect.equal(state.tutorial.step, "Stock")
		expect.falsy(Tutorial.advance(state, "Ordered"))
		expect.equal(state.tutorial.step, "Stock")
		expect.truthy(Tutorial.advance(state, "Stocked"))
		expect.equal(state.tutorial.step, "Checkout")
		expect.truthy(Tutorial.advance(state, "Sold"))
		expect.equal(state.tutorial.step, "Done")
		local stocked = withStep("Order")
		expect.truthy(Tutorial.advance(stocked, "Stocked"))
		expect.equal(stocked.tutorial.step, "Checkout")
		local sold = withStep("Order")
		expect.truthy(Tutorial.advance(sold, "Sold"))
		expect.equal(sold.tutorial.step, "Done")
		local unknown = withStep("Order")
		expect.falsy(Tutorial.advance(unknown, "Shopped"))
		expect.equal(unknown.tutorial.step, "Order")
		local done = withStep("Done")
		for _, event in { "Ordered", "Stocked", "Sold" } do
			expect.falsy(Tutorial.advance(done, event))
			expect.equal(done.tutorial.step, "Done")
		end
	end)

	t.test("skip ends the tutorial once", function()
		local state = withStep("Stock")
		local ok, result = Tutorial.skip(state)
		expect.truthy(ok)
		expect.equal(result.step, "Done")
		expect.equal(state.tutorial.step, "Done")
		expect.equal(state.tutorial.skipped, true)
		expect.equal(Tutorial.attribute(state), "Skipped")
		expect.truthy(BusinessState.validate(state))
		local again, code = Tutorial.skip(state)
		expect.falsy(again)
		expect.equal(code, "TutorialDone")
	end)

	t.test("validates the tutorial record", function()
		local state = BusinessState.new(COMPANY, 42)
		expect.truthy(BusinessState.validate(state))
		state.tutorial = { step = "Shop", skipped = false }
		expect.falsy(BusinessState.validate(state))
		state.tutorial = { step = "Done", skipped = "yes" }
		expect.falsy(BusinessState.validate(state))
		state.tutorial = { step = "Order", skipped = true }
		expect.falsy(BusinessState.validate(state))
		state.tutorial = nil
		expect.falsy(BusinessState.validate(state))
	end)

	t.test("migrates schema 17 to 18 with a finished tutorial", function()
		local record = BusinessState.new(COMPANY, 42)
		record.schemaVersion = 17
		record.tutorial = nil
		local migrated, reason = BusinessState.migrate(record, COMPANY, 42)
		expect.equal(reason, nil)
		expect.truthy(migrated)
		expect.equal(migrated.schemaVersion, 20)
		expect.equal(migrated.tutorial.step, "Done")
		expect.equal(migrated.tutorial.skipped, false)
		expect.truthy(BusinessState.validate(migrated))
		local v1 = {
			schemaVersion = 1,
			cash = 500,
			reputation = 10,
			stock = {},
			pendingOrders = {},
			history = {},
			sales = 0,
			revenue = 0,
			spent = 0,
		}
		local fromV1 = BusinessState.migrate(v1, COMPANY, 42)
		expect.truthy(fromV1)
		expect.equal(fromV1.schemaVersion, 20)
		expect.equal(fromV1.tutorial.step, "Done")
	end)

	t.test("order, stocking and a sale advance it through the services", function()
		local service = CompanyStateService.new(fakePersistence(), function()
			return 160
		end, function()
			return 0
		end)
		local notified = {}
		service:setTutorialChangedHandler(function(companyId, value)
			expect.equal(companyId, COMPANY)
			table.insert(notified, value)
		end)
		local state = service:loadCompany(COMPANY, 42)
		state.tutorial = Tutorial.new(true)
		expect.truthy(BusinessState.placeOrder(state, "tutorial_order_1", "FrasierFir", "Small", 1, 100))
		expect.equal(state.tutorial.step, "Stock")
		local ok, delivered = service:reconcileDeliveriesAll()
		expect.truthy(ok)
		expect.equal(delivered, 1)
		expect.equal(state.bays[1].counts.Small, 1)
		local stocked =
			PlacementService.stockFromBay(state, "tutorial_place", 1, "FrasierFir", "Small", -35, -13, 0, 1, 0.5)
		expect.truthy(stocked)
		expect.equal(state.tutorial.step, "Checkout")
		table.clear(notified)
		local simulated, sales = service:simulateCustomerVisits()
		expect.truthy(simulated)
		expect.equal(sales, 1)
		expect.equal(state.tutorial.step, "Done")
		expect.equal(#notified, 1)
		expect.equal(notified[1], "Done")
	end)

	t.test("tutorial progress is server-owned and survives a rejoin", function()
		local companyId = "save:42_0000000000000001"
		local store = copyingStore()
		local clock = function(): number
			return 1000
		end
		local persistence = PersistenceService.new(store, "job-a", clock, noWait)
		local service = CompanyStateService.new(persistence, clock, nil, noWait)
		local notified = {}
		service:setTutorialChangedHandler(function(_, value)
			table.insert(notified, value)
		end)
		local state = service:loadCompany(companyId, 42, "Lot", { tutorial = true })
		expect.truthy(state)
		expect.equal(service:snapshotForTest(companyId).tutorial.step, "Order")
		local placed = service:handle(
			companyId,
			42,
			request("Supplier.PlaceOrder", { speciesId = "DouglasFir", sizeId = "Medium", quantity = 1 })
		)
		expect.truthy(placed.ok)
		expect.equal(service:snapshotForTest(companyId).tutorial.step, "Stock")
		expect.equal(notified[#notified], "Stock")
		expect.truthy(service:unloadCompany(companyId))
		expect.truthy(service:loadCompany(companyId, 42, "Lot", { tutorial = true }))
		expect.equal(service:snapshotForTest(companyId).tutorial.step, "Stock")
		local forged = service:handle(companyId, 42, request("Tutorial.Skip", { step = "Done" }))
		expect.falsy(forged.ok)
		expect.equal(forged.errorCode, "UnexpectedField")
		expect.equal(service:snapshotForTest(companyId).tutorial.step, "Stock")
	end)

	t.test("Tutorial.Skip is validated, member-only and rate-limited", function()
		local service = CompanyStateService.new(fakePersistence(), function()
			return 100
		end)
		local state = service:loadCompany(COMPANY, 42)
		state.tutorial = Tutorial.new(true)
		local outsider = service:handle(COMPANY, 7, request("Tutorial.Skip"))
		expect.falsy(outsider.ok)
		expect.equal(outsider.errorCode, "Forbidden")
		expect.equal(state.tutorial.step, "Order")
		local skipped = service:handle(COMPANY, 42, request("Tutorial.Skip", nil, "tutorial_skip_1"))
		expect.truthy(skipped.ok)
		expect.equal(service:tutorialAttribute(COMPANY), "Skipped")
		local replay = service:handle(COMPANY, 42, request("Tutorial.Skip", nil, "tutorial_skip_1"))
		expect.falsy(replay.ok)
		expect.equal(replay.errorCode, "DuplicateRequest")
		for _ = 1, 8 do
			local again = service:handle(COMPANY, 42, request("Tutorial.Skip"))
			expect.falsy(again.ok)
			expect.equal(again.errorCode, "TutorialDone")
		end
		local limited = service:handle(COMPANY, 42, request("Tutorial.Skip"))
		expect.falsy(limited.ok)
		expect.equal(limited.errorCode, "RateLimited")
	end)
end

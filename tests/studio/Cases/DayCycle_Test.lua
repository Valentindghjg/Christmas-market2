--!strict
-- CM2-G12a: the per-save day clock (shared/DayCycle.lua, schema 20) and its company-service
-- mixin (CompanyDayCycle): clock maths, migration, the tick that runs only in loaded saves,
-- rollover notifications, the arrival rate, the summary fields and the test setter.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local DayCycle = require(Shared:WaitForChild("DayCycle"))
	local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
	local CompanyStateService = require(Services:WaitForChild("CompanyStateService"))
	local expect = t.expect

	local A, B = "personal:42", "personal:43"

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

	-- Deep-copies on load and save like a real DataStore.
	local function fakePersistence()
		local records = {}
		local persistence = { records = records }
		function persistence.load(_, companyId, ownerUserId)
			records[companyId] = records[companyId] or BusinessState.new(companyId, ownerUserId)
			return deepCopy(records[companyId]), nil
		end
		function persistence.save(_, companyId, state)
			records[companyId] = deepCopy(state)
			return true, nil
		end
		function persistence.release()
			return true, nil
		end
		return persistence
	end

	local function newService()
		local persistence = fakePersistence()
		local service = CompanyStateService.new(persistence, function()
			return 1000
		end, function()
			return 0
		end, function() end)
		local calls = {}
		service:setDayChangedHandler(function(companyId)
			table.insert(calls, companyId)
		end)
		return service, persistence, calls
	end

	local function near(actual: number, expected: number, tolerance: number?)
		local limit = tolerance or 1e-9
		assert(math.abs(actual - expected) <= limit, string.format("expected %s, got %s", expected, actual))
	end

	local requestNumber = 0
	local function request(action: string)
		requestNumber += 1
		return {
			version = 1,
			requestId = string.format("daycycle_req_%06d", requestNumber),
			action = action,
			payload = {},
		}
	end

	t.test("new starts on day 1 at dawn", function()
		local cycle = DayCycle.new()
		expect.equal(cycle.day, 1)
		expect.equal(cycle.elapsed, 0)
		expect.truthy(DayCycle.isValid(cycle))
		expect.equal(DayCycle.length(), 1080)
	end)

	t.test("isValid rejects broken cycles", function()
		expect.falsy(DayCycle.isValid(nil))
		expect.falsy(DayCycle.isValid({ day = 0, elapsed = 0 }))
		expect.falsy(DayCycle.isValid({ day = 1.5, elapsed = 0 }))
		expect.falsy(DayCycle.isValid({ day = 1, elapsed = -1 }))
		expect.falsy(DayCycle.isValid({ day = 1, elapsed = 1080 }))
		expect.falsy(DayCycle.isValid({ day = 1, elapsed = 0 / 0 }))
	end)

	t.test("advance rolls into the next day", function()
		local cycle = { day = 1, elapsed = 1078 }
		expect.equal(DayCycle.advance(cycle, 4), 1)
		expect.equal(cycle.day, 2)
		expect.equal(cycle.elapsed, 2)
	end)

	t.test("advance ignores bad seconds and clamps", function()
		local cycle = { day = 3, elapsed = 10 }
		for _, seconds in { 0, -3, 0 / 0, math.huge } do
			expect.equal(DayCycle.advance(cycle, seconds), 0)
			expect.equal(cycle.day, 3)
			expect.equal(cycle.elapsed, 10)
		end
		expect.equal(DayCycle.advance(cycle, 100), 0)
		expect.equal(cycle.elapsed, 15)
		expect.equal(cycle.day, 3)
	end)

	t.test("night split and arrival rate", function()
		expect.falsy(DayCycle.isNight(719.9))
		expect.truthy(DayCycle.isNight(720))
		expect.truthy(DayCycle.isNight(1079))
		expect.equal(DayCycle.arrivalRate(719.9), 1)
		expect.equal(DayCycle.arrivalRate(720), 0.5)
	end)

	t.test("clockTime maps day and night", function()
		near(DayCycle.clockTime(0), 6)
		near(DayCycle.clockTime(360), 12)
		near(DayCycle.clockTime(720), 18)
		near(DayCycle.clockTime(900), 0)
		near(DayCycle.clockTime(1080 - 1e-6), 6, 0.01)
		near(DayCycle.clockTime(810), 21)
	end)

	t.test("nightBlend and lightsOn ramp", function()
		near(DayCycle.nightBlend(0), 1)
		near(DayCycle.nightBlend(15), 0.5)
		near(DayCycle.nightBlend(30), 0)
		near(DayCycle.nightBlend(400), 0)
		near(DayCycle.nightBlend(735), 0.5)
		near(DayCycle.nightBlend(800), 1)
		expect.falsy(DayCycle.lightsOn(400))
		expect.truthy(DayCycle.lightsOn(800))
	end)

	t.test("extrapolate wraps", function()
		near(DayCycle.extrapolate(1070, 100, 115), 5)
		near(DayCycle.extrapolate(300, 200, 150), 300)
	end)

	t.test("migrates schema 19 to 20", function()
		local record = BusinessState.new(A, 42)
		record.schemaVersion = 19
		record.dayCycle = nil
		record.cash = 4321
		local migrated, reason = BusinessState.migrate(record, A, 42)
		expect.equal(reason, nil)
		expect.truthy(migrated)
		expect.equal(migrated.schemaVersion, 24)
		expect.equal(migrated.dayCycle.day, 1)
		expect.equal(migrated.dayCycle.elapsed, 0)
		expect.equal(migrated.cash, 4321)
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
		local fromV1 = BusinessState.migrate(v1, A, 42)
		expect.truthy(fromV1)
		expect.equal(fromV1.dayCycle.day, 1)
		expect.equal(fromV1.dayCycle.elapsed, 0)
	end)

	t.test("validate and normalize", function()
		local missing = BusinessState.new(A, 42)
		missing.dayCycle = nil
		expect.falsy(BusinessState.validate(missing))
		local broken = BusinessState.new(A, 42)
		broken.dayCycle = { day = 0, elapsed = 0 }
		expect.falsy(BusinessState.validate(broken))
		local overrun = BusinessState.new(A, 42)
		overrun.dayCycle = { day = 7, elapsed = 2000 }
		local migrated, reason = BusinessState.migrate(overrun, A, 42)
		expect.equal(reason, nil)
		expect.truthy(migrated)
		expect.equal(migrated.dayCycle.elapsed, 920)
		expect.equal(migrated.dayCycle.day, 7)
	end)

	t.test("tickDayAll runs only loaded saves", function()
		local service, persistence = newService()
		expect.truthy(service:loadCompany(A, 42))
		expect.truthy(service:loadCompany(B, 43))
		expect.truthy(service:unloadCompany(B))
		local ok, rolled, failures = service:tickDayAll(3)
		expect.truthy(ok)
		expect.equal(rolled, 0)
		expect.equal(failures, 0)
		expect.equal(service:dayView(A).elapsed, 3)
		expect.equal(service:dayView(B), nil)
		expect.equal(persistence.records[B].dayCycle.elapsed, 0)
		expect.truthy(service:unloadCompany(A))
		local reloaded = service:loadCompany(A, 42)
		expect.truthy(reloaded)
		expect.equal(reloaded.dayCycle.elapsed, 3)
		expect.equal(reloaded.dayCycle.day, 1)
	end)

	t.test("rollover marks dirty and notifies once", function()
		local service, _, calls = newService()
		expect.truthy(service:loadCompany(A, 42))
		service:flushDirty(true)
		service:tickDayAll(2)
		expect.falsy(service:isDirty(A))
		expect.equal(#calls, 0)
		expect.truthy(service:setDayForTest(A, nil, 1079))
		service:flushDirty(true)
		table.clear(calls)
		local revision = service:snapshotForTest(A).revision
		local _, rolled = service:tickDayAll(2)
		expect.equal(rolled, 1)
		expect.truthy(service:isDirty(A))
		expect.equal(#calls, 1)
		expect.equal(calls[1], A)
		expect.equal(service:dayView(A).day, 2)
		expect.equal(service:dayView(A).elapsed, 1)
		expect.equal(service:snapshotForTest(A).revision, revision)
	end)

	t.test("arrivalRate and dayView follow the phase", function()
		local service = newService()
		expect.truthy(service:loadCompany(A, 42))
		expect.truthy(service:setDayForTest(A, nil, 100))
		expect.equal(service:arrivalRate(A), 1)
		expect.falsy(service:dayView(A).night)
		expect.equal(service:dayView(A).arrivalRate, 1)
		expect.truthy(service:setDayForTest(A, nil, 800))
		expect.equal(service:arrivalRate(A), 0.5)
		expect.truthy(service:dayView(A).night)
		expect.equal(service:dayView(A).arrivalRate, 0.5)
		expect.equal(service:arrivalRate("personal:999"), 1)
		expect.equal(service:dayView("personal:999"), nil)
	end)

	t.test("summary carries the day", function()
		local service = newService()
		expect.truthy(service:loadCompany(A, 42))
		local first = service:handle(A, 42, request("Company.GetSummary"))
		expect.truthy(first.ok)
		expect.equal(first.data.day, 1)
		expect.equal(first.data.night, false)
		expect.truthy(service:setDayForTest(A, 4, 900))
		local second = service:handle(A, 42, request("Company.GetSummary"))
		expect.truthy(second.ok)
		expect.equal(second.data.day, 4)
		expect.equal(second.data.night, true)
	end)

	t.test("setDayForTest validates", function()
		local service, _, calls = newService()
		expect.truthy(service:loadCompany(A, 42))
		for _, case in { { 0, 10 }, { 1.5, 10 }, { nil, -1 }, { nil, 1080 } } do
			expect.falsy(service:setDayForTest(A, case[1], case[2]))
			expect.equal(service:dayView(A).day, 1)
			expect.equal(service:dayView(A).elapsed, 0)
		end
		expect.equal(#calls, 0)
		expect.truthy(service:setDayForTest(A, 3, 500))
		expect.equal(service:dayView(A).day, 3)
		expect.equal(service:dayView(A).elapsed, 500)
		expect.equal(#calls, 1)
		expect.equal(calls[1], A)
	end)
end

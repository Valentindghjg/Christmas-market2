--!strict
-- CM2-A1: the Advent.Open action with the real SaveSlot, Persistence, CompanyState and Plot
-- services over fake DataStores and a mutable clock. No test touches a real DataStore.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local ShopConfig = require(Shared:WaitForChild("ShopConfig"))
	local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
	local AdventService = require(Services:WaitForChild("AdventService"))
	local CompanyStateService = require(Services:WaitForChild("CompanyStateService"))
	local PersistenceService = require(Services:WaitForChild("PersistenceService"))
	local PlotService = require(Services:WaitForChild("PlotService"))
	local SaveSlotService = require(Services:WaitForChild("SaveSlotService"))
	local expect = t.expect

	local USER = 42
	local DEC_3_NOON = 1796299200 -- 2026-12-03 12:00 UTC
	local DEC_6_NOON = DEC_3_NOON + 3 * 86400
	local DEC_10_NOON = DEC_3_NOON + 7 * 86400
	local DEC_25 = 1798156800 -- 2026-12-25 00:00 UTC
	local NOV_30_NOON = DEC_3_NOON - 3 * 86400

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

	local function fakeStore()
		local store: any = { records = {}, writes = 0 }
		function store.UpdateAsync(_, key: string, transform)
			local nextValue = transform(deepCopy(store.records[key]))
			if nextValue ~= nil then
				store.records[key] = deepCopy(nextValue)
				store.writes += 1
			end
			return deepCopy(store.records[key])
		end
		return store
	end

	local function noWait() end

	-- Sets up the services; play = true opens the player's profile and plays the starter save.
	local function setup(play: boolean)
		local env: any = { now = DEC_3_NOON, attributes = {} }
		local function clock(): number
			return env.now
		end
		env.persistence = PersistenceService.new(fakeStore(), "job-a", clock, noWait)
		env.companies = CompanyStateService.new(env.persistence, clock, nil, noWait)
		local counter = 0
		env.saveSlots = SaveSlotService.new({
			profileStore = fakeStore(),
			persistence = env.persistence,
			companies = env.companies,
			plots = PlotService.new({ "Plot_01", "Plot_02" }),
			clock = clock,
			wait = noWait,
			newSaveId = function(userId: number): string
				counter += 1
				return string.format("%d_%016x", userId, counter)
			end,
			filterName = function(_, text: string)
				return true, text
			end,
			teleport = function()
				return true
			end,
		})
		env.advent = AdventService.new({
			saveSlots = env.saveSlots,
			companies = env.companies,
			clock = clock,
			setAttribute = function(userId: number, name: string, value: any)
				env.attributes[userId] = env.attributes[userId] or {}
				env.attributes[userId][name] = value
			end,
		})
		local profile = env.saveSlots:openProfile(USER)
		expect.truthy(profile)
		env.saveId = profile.saves[1].saveId
		env.companyId = "save:" .. env.saveId
		if play then
			expect.truthy(env.saveSlots:play(USER, env.saveId))
		end
		return env
	end

	local requestNumber = 0
	local function openRequest(payload: any)
		requestNumber += 1
		return {
			version = 1,
			requestId = string.format("advent_req_%06d", requestNumber),
			action = "Advent.Open",
			payload = payload,
		}
	end

	local function openDoor(env, door: number)
		return env.advent:handle(USER, openRequest({ door = door }))
	end

	local function snapshot(env, companyId: string?)
		return env.companies:snapshotForTest(companyId or env.companyId)
	end

	local function openedMask(env): number
		local open, advent = env.saveSlots:adventOf(USER)
		expect.truthy(open)
		return if advent == nil then 0 else advent.opened
	end

	t.test("opens today's door into the active save once", function()
		local env = setup(true)
		local before = snapshot(env).cash
		local response = openDoor(env, 1)
		expect.truthy(response.ok)
		expect.equal(type(response.revision), "number")
		expect.equal(response.data.door, 1)
		expect.equal(response.data.cash, 500)
		expect.equal(response.data.reputation, 0)
		expect.equal(response.data.boostSeconds, 0)
		expect.equal(response.data.decor, nil)
		expect.equal(snapshot(env).cash, before + 500)
		local again = openDoor(env, 1)
		expect.falsy(again.ok)
		expect.equal(again.errorCode, "AlreadyClaimed")
		expect.equal(snapshot(env).cash, before + 500)
		local attributes = env.attributes[USER]
		expect.equal(attributes.AdventPhase, "Open")
		expect.equal(attributes.AdventToday, 3)
		expect.equal(attributes.AdventOpened, 1)
		expect.equal(attributes.AdventClaimable, 2)
	end)

	t.test("rejects a future door and closes after Dec 24", function()
		local env = setup(true)
		local before = snapshot(env).cash
		expect.equal(openDoor(env, 4).errorCode, "DoorLocked")
		env.now = DEC_25
		expect.equal(openDoor(env, 1).errorCode, "CalendarClosed")
		env.now = NOV_30_NOON
		expect.equal(openDoor(env, 1).errorCode, "CalendarClosed")
		expect.equal(snapshot(env).cash, before)
		expect.equal(openedMask(env), 0)
	end)

	t.test("pays each door once per player across two saves", function()
		local env = setup(true)
		expect.truthy(openDoor(env, 1).ok)
		local reputationA = snapshot(env).reputation
		local created = env.saveSlots:handle(USER, {
			version = 1,
			requestId = "advent_create_0001",
			action = "Save.Create",
			payload = { name = "Second Lot" },
		})
		expect.truthy(created.ok)
		local saveB = created.data.saveId
		local companyB = "save:" .. saveB
		expect.truthy(env.saveSlots:play(USER, saveB))
		local beforeB = snapshot(env, companyB)
		local again = openDoor(env, 1)
		expect.equal(again.errorCode, "AlreadyClaimed")
		expect.equal(snapshot(env, companyB).cash, beforeB.cash)
		local second = openDoor(env, 2)
		expect.truthy(second.ok)
		expect.equal(second.data.reputation, 100)
		expect.equal(snapshot(env, companyB).reputation, beforeB.reputation + 100)
		expect.equal(snapshot(env, companyB).cash, beforeB.cash)
		expect.truthy(env.saveSlots:play(USER, env.saveId))
		expect.equal(snapshot(env).reputation, reputationA)
		expect.equal(openedMask(env), 3)
	end)

	t.test("grants boost, decor and the specials", function()
		local env = setup(true)
		env.now = DEC_6_NOON
		local before = snapshot(env)
		local boost = openDoor(env, 4)
		expect.truthy(boost.ok)
		expect.equal(boost.data.boostSeconds, 900)
		expect.equal(snapshot(env).purchases.boosts.CashX2, before.purchases.boosts.CashX2 + 900)
		local decor = openDoor(env, 5)
		expect.truthy(decor.ok)
		expect.equal(decor.data.decor, "AdventWreath")
		expect.equal(snapshot(env).decorInventory.AdventWreath, 1)
		local special = openDoor(env, 6)
		expect.truthy(special.ok)
		expect.equal(special.data.cash, 3000)
		expect.equal(special.data.reputation, 250)
		expect.equal(special.data.decor, "AdventStarLantern")
		local after = snapshot(env)
		expect.equal(after.cash, before.cash + 3000)
		expect.equal(after.reputation, before.reputation + 250)
		expect.equal(after.decorInventory.AdventStarLantern, 1)
		env.now = DEC_10_NOON
		env.companies._sessions[env.companyId].state.purchases.boosts.CashX2 = ShopConfig.BoostCapSeconds - 100
		local capped = openDoor(env, 10)
		expect.truthy(capped.ok)
		expect.equal(capped.data.boostSeconds, 100)
		expect.equal(snapshot(env).purchases.boosts.CashX2, ShopConfig.BoostCapSeconds)
	end)

	t.test("refuses a concurrent open while one is in flight", function()
		local env = setup(true)
		local before = snapshot(env).cash
		local grant = env.companies.grantReward
		local inner = nil
		env.companies.grantReward = function(...)
			if inner == nil then
				inner = openDoor(env, 2)
			end
			return grant(...)
		end
		local outer = openDoor(env, 1)
		expect.truthy(outer.ok)
		expect.equal(inner.errorCode, "ClaimBusy")
		expect.equal(snapshot(env).cash, before + 500)
		expect.equal(openedMask(env), 1)
	end)

	t.test("reverts the door when the save refuses the grant", function()
		local env = setup(true)
		local before = snapshot(env).cash
		env.companies.grantReward = function()
			return false, "CompanyUnavailable"
		end
		local refused = openDoor(env, 1)
		expect.falsy(refused.ok)
		expect.equal(refused.errorCode, "CompanyUnavailable")
		expect.equal(openedMask(env), 0)
		expect.equal(snapshot(env).cash, before)
		env.companies.grantReward = nil
		local later = openDoor(env, 1)
		expect.truthy(later.ok)
		expect.equal(snapshot(env).cash, before + 500)
	end)

	t.test("refuses bad payloads, missing saves, direct company calls and floods", function()
		local env = setup(true)
		expect.equal(env.advent:handle(USER, openRequest({ door = 1, x = 1 })).errorCode, "UnexpectedField")
		expect.equal(env.advent:handle(USER, openRequest({ door = 25 })).errorCode, "InvalidDoor")
		local idle = setup(false)
		expect.equal(openDoor(idle, 1).errorCode, "CompanyUnavailable")
		local direct = env.companies:handle(env.companyId, USER, openRequest({ door = 1 }))
		expect.equal(direct.errorCode, "Forbidden")
		local flood = setup(true)
		local codes = {}
		for index = 1, 25 do
			codes[index] = openDoor(flood, 4).errorCode
		end
		expect.equal(codes[24], "DoorLocked")
		expect.equal(codes[25], "RateLimited")
	end)

	t.test("validates the reward extras", function()
		local env = setup(true)
		local before = snapshot(env)
		for _, extras in
			{
				{ boostSeconds = -1 },
				{ boostSeconds = 1.5 },
				{ boostSeconds = ShopConfig.BoostCapSeconds + 1 },
				{ decorId = "Nope" },
			} :: { any }
		do
			local ok, code = env.companies:grantReward(env.companyId, USER, "AdventReward", 0, 0, extras)
			expect.falsy(ok)
			expect.equal(code, "InvalidReward")
		end
		local after = snapshot(env)
		expect.equal(after.revision, before.revision)
		expect.equal(after.purchases.boosts.CashX2, before.purchases.boosts.CashX2)
		expect.equal(next(after.decorInventory), nil)
	end)
end

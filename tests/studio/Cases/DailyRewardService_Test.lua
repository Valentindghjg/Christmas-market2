--!strict
-- CM2-G11: the Daily.Claim action with the real SaveSlot, Persistence, CompanyState and Plot
-- services over fake DataStores and a mutable clock. No test touches a real DataStore.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
	local CompanyStateService = require(Services:WaitForChild("CompanyStateService"))
	local DailyRewardService = require(Services:WaitForChild("DailyRewardService"))
	local PersistenceService = require(Services:WaitForChild("PersistenceService"))
	local PlotService = require(Services:WaitForChild("PlotService"))
	local SaveSlotService = require(Services:WaitForChild("SaveSlotService"))
	local expect = t.expect

	local USER = 42
	local DAY = GameConfig.DailyRewards.DaySeconds

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
		local env: any = { now = 100 * DAY + 50, attributes = {}, groupCalls = 0 }
		local function clock(): number
			return env.now
		end
		env.isInGroup = function(_userId: number, _groupId: number): boolean
			return false
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
		env.daily = DailyRewardService.new({
			saveSlots = env.saveSlots,
			companies = env.companies,
			clock = clock,
			isInGroup = function(userId: number, groupId: number): boolean
				env.groupCalls += 1
				return env.isInGroup(userId, groupId)
			end,
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
	local function claimRequest(payload: any?)
		requestNumber += 1
		return {
			version = 1,
			requestId = string.format("daily_req_%06d", requestNumber),
			action = "Daily.Claim",
			payload = payload or {},
		}
	end

	local function claim(env)
		return env.daily:handle(USER, claimRequest())
	end

	local function cash(env): number
		return env.companies:snapshotForTest(env.companyId).cash
	end

	-- Runs fn with GameConfig.DailyRewards.GroupId set to groupId and restores it afterwards.
	local function withGroup(groupId: number, fn: () -> ())
		local original = GameConfig.DailyRewards.GroupId
		GameConfig.DailyRewards.GroupId = groupId
		local ok, err = pcall(fn)
		GameConfig.DailyRewards.GroupId = original
		if not ok then
			error(err, 0)
		end
	end

	t.test("claims day 1 into the active save once", function()
		local env = setup(true)
		local before = cash(env)
		local response = claim(env)
		expect.truthy(response.ok)
		expect.equal(response.data.day, 1)
		expect.equal(response.data.cash, 400)
		expect.equal(response.data.reputation, 0)
		expect.equal(response.data.doubled, false)
		expect.equal(type(response.revision), "number")
		expect.equal(cash(env), before + 400)
		local again = claim(env)
		expect.falsy(again.ok)
		expect.equal(again.errorCode, "AlreadyClaimed")
		expect.equal(cash(env), before + 400)
		local attributes = env.attributes[USER]
		expect.equal(attributes.DailyClaimable, false)
		expect.equal(attributes.DailyNext, 2)
		expect.equal(attributes.DailyGroup, "Hidden")
		expect.equal(attributes.DailySecondsLeft, DAY - 50)
	end)

	t.test("resets the streak by server time", function()
		local env = setup(true)
		local before = cash(env)
		expect.equal(claim(env).data.day, 1)
		env.now += DAY
		local second = claim(env)
		expect.equal(second.data.day, 2)
		expect.equal(cash(env), before + 400 + 500)
		env.now += 2 * DAY
		local reset = claim(env)
		expect.equal(reset.data.day, 1)
		expect.equal(cash(env), before + 400 + 500 + 400)
	end)

	t.test("doubles once per claim and only for group members", function()
		withGroup(123, function()
			local member = setup(true)
			local groupSeen = nil
			member.isInGroup = function(_userId: number, groupId: number): boolean
				groupSeen = groupId
				return true
			end
			local before = cash(member)
			local response = claim(member)
			expect.equal(response.data.cash, 800)
			expect.equal(response.data.doubled, true)
			expect.equal(groupSeen, 123)
			expect.equal(cash(member), before + 800)
			expect.equal(member.attributes[USER].DailyGroup, "Active")

			local outsider = setup(true)
			local outsiderBefore = cash(outsider)
			local plain = claim(outsider)
			expect.equal(plain.data.cash, 400)
			expect.equal(plain.data.doubled, false)
			expect.equal(cash(outsider), outsiderBefore + 400)
			expect.equal(outsider.attributes[USER].DailyGroup, "Join")

			local failing = setup(true)
			failing.isInGroup = function(): boolean
				error("group service down")
			end
			local failingBefore = cash(failing)
			local fallback = claim(failing)
			expect.equal(fallback.data.cash, 400)
			expect.equal(cash(failing), failingBefore + 400)
		end)
		withGroup(0, function()
			local hidden = setup(true)
			hidden.isInGroup = function(): boolean
				return true
			end
			local before = cash(hidden)
			local response = claim(hidden)
			expect.equal(response.data.cash, 400)
			expect.equal(response.data.doubled, false)
			expect.equal(cash(hidden), before + 400)
			hidden.daily:onPlayerJoined(USER)
			expect.equal(hidden.groupCalls, 0)
			expect.equal(hidden.attributes[USER].DailyGroup, "Hidden")
		end)
	end)

	t.test("refuses a concurrent claim while one is in flight", function()
		withGroup(123, function()
			local env = setup(true)
			local inner = nil
			env.isInGroup = function(): boolean
				if inner == nil then
					inner = claim(env)
				end
				return false
			end
			local before = cash(env)
			local outer = claim(env)
			expect.truthy(outer.ok)
			expect.equal(inner.errorCode, "ClaimBusy")
			expect.equal(cash(env), before + 400)
		end)
	end)

	t.test("reverts the profile when the save refuses the grant", function()
		local env = setup(true)
		local before = cash(env)
		env.companies.grantReward = function()
			return false, "CompanyUnavailable"
		end
		local refused = claim(env)
		expect.falsy(refused.ok)
		expect.equal(refused.errorCode, "CompanyUnavailable")
		local open, daily = env.saveSlots:dailyOf(USER)
		expect.truthy(open)
		expect.equal(daily, nil)
		expect.equal(cash(env), before)
		env.companies.grantReward = nil
		local later = claim(env)
		expect.truthy(later.ok)
		expect.equal(later.data.day, 1)
		expect.equal(cash(env), before + 400)
	end)

	t.test("refuses bad payloads, missing saves and floods", function()
		local env = setup(true)
		local bad = env.daily:handle(USER, claimRequest({ x = 1 }))
		expect.equal(bad.errorCode, "UnexpectedField")
		local idle = setup(false)
		local missing = claim(idle)
		expect.equal(missing.errorCode, "CompanyUnavailable")
		local codes = {}
		for index = 1, 6 do
			codes[index] = claim(env).errorCode
		end
		expect.equal(codes[1], nil)
		for index = 2, 5 do
			expect.equal(codes[index], "AlreadyClaimed")
		end
		expect.equal(codes[6], "RateLimited")
	end)
end

--!strict
-- CM2-G12b: the leaderboard cache, cached and rate-limited ordered writes, playtime
-- increments and the top-list reads, over fake OrderedDataStores. No real DataStore is touched.
return function(t)
	local LeaderboardService = require(
		game:GetService("ServerScriptService")
			:WaitForChild("Server")
			:WaitForChild("Services")
			:WaitForChild("LeaderboardService")
	)
	local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameConfig"))
	local expect = t.expect

	local KEY_NAME_LIMIT = 50 -- real DataStore rule (KeyNameLimit)

	local function saveId(owner: number, hexDigit: string): string
		return tostring(owner) .. "_" .. string.rep(hexDigit, 16)
	end

	-- Fake ordered store: data, sets/increments counters, failNext (any call), key-length check.
	local function fakeStore()
		local store: any = { data = {}, sets = 0, increments = 0, lastDelta = nil, failNext = 0, onIncrement = nil }
		local function guard(key: string?)
			if key ~= nil and #key > KEY_NAME_LIMIT then
				error("KeyNameLimit")
			end
			if store.failNext > 0 then
				store.failNext -= 1
				error("Throttled")
			end
		end
		function store.SetAsync(_, key: string, value: number)
			guard(key)
			store.data[key] = value
			store.sets += 1
		end
		function store.IncrementAsync(_, key: string, delta: number)
			guard(key)
			if store.onIncrement then
				local hook = store.onIncrement
				store.onIncrement = nil
				hook()
			end
			store.data[key] = (store.data[key] or 0) + delta
			store.increments += 1
			store.lastDelta = delta
			return store.data[key]
		end
		function store.GetAsync(_, key: string)
			guard(key)
			return store.data[key]
		end
		function store.GetSortedAsync(_, ascending: boolean, pageSize: number)
			guard(nil)
			local items = {}
			for key, value in store.data do
				table.insert(items, { key = key, value = value })
			end
			table.sort(items, function(a, b)
				if a.value ~= b.value then
					if ascending then
						return a.value < b.value
					end
					return a.value > b.value
				end
				return a.key < b.key
			end)
			local page = {}
			for index = 1, math.min(pageSize, #items) do
				page[index] = items[index]
			end
			return {
				GetCurrentPage = function()
					return page
				end,
			}
		end
		return store
	end

	local function setup(names: { [number]: string }?)
		local env: any = { now = 0, budget = 100, stores = {}, published = {}, publishCount = {} }
		for _, board in GameConfig.Leaderboards.Keys do
			env.stores[board] = fakeStore()
			env.publishCount[board] = 0
		end
		env.service = LeaderboardService.new({
			store = function(board: string)
				return env.stores[board]
			end,
			budget = function(): number
				return env.budget
			end,
			userName = function(userId: number): string?
				return if names then names[userId] else nil
			end,
			clock = function(): number
				return env.now
			end,
			publish = function(board: string, rows)
				env.published[board] = rows
				env.publishCount[board] += 1
			end,
		})
		return env
	end

	t.test("caches reports and writes once", function()
		local env = setup()
		local key = LeaderboardService.playerKey(7)
		for value = 1, 50 do
			expect.truthy(env.service:report("RobuxSpent", key, value))
		end
		local written = env.service:flush(true)
		expect.equal(written, 1)
		expect.equal(env.stores.RobuxSpent.sets, 1)
		expect.equal(env.stores.RobuxSpent.data[key], 50)
	end)

	t.test("skips unchanged entries and new zeros", function()
		local env = setup()
		local key = LeaderboardService.playerKey(7)
		env.service:report("RobuxSpent", key, 40)
		expect.equal(env.service:flush(true), 1)
		env.service:report("RobuxSpent", key, 40)
		expect.equal(env.service:flush(true), 0)
		expect.equal(env.stores.RobuxSpent.sets, 1)
		local zeroKey = LeaderboardService.saveKey(saveId(9, "a"))
		expect.truthy(env.service:report("CashEarned", zeroKey, 0))
		expect.equal(env.service:flush(true), 0)
		expect.equal(env.stores.CashEarned.sets, 0)
		expect.equal(env.stores.CashEarned.data[zeroKey], nil)
		expect.equal(env.service:stats().dirty, 0)
	end)

	t.test("rate-limits flushes", function()
		local env = setup()
		local key = LeaderboardService.playerKey(7)
		env.service:report("RobuxSpent", key, 10)
		env.now = 0
		expect.equal(env.service:flush(), 1)
		env.service:report("RobuxSpent", key, 20)
		env.now = 60
		local written, skipped = env.service:flush()
		expect.equal(written, 0)
		expect.equal(skipped, "RateLimited")
		expect.equal(env.stores.RobuxSpent.sets, 1)
		env.now = 120
		expect.equal(env.service:flush(), 1)
		expect.equal(env.stores.RobuxSpent.sets, 2)
		expect.equal(env.stores.RobuxSpent.data[key], 20)
		expect.equal(env.service:stats().rateLimited, 1)
	end)

	t.test("caps writes per flush", function()
		local env = setup()
		for userId = 1, 30 do
			env.service:report("RobuxSpent", LeaderboardService.playerKey(userId), 5)
		end
		expect.equal(env.service:flush(true), GameConfig.Leaderboards.MaxWritesPerFlush)
		expect.equal(env.service:flush(true), 6)
		expect.equal(env.stores.RobuxSpent.sets, 30)
	end)

	t.test("stops below the write budget", function()
		local env = setup()
		env.service:report("RobuxSpent", LeaderboardService.playerKey(7), 10)
		env.budget = 5
		local written, skipped = env.service:flush(true)
		expect.equal(written, 0)
		expect.equal(skipped, "NoBudget")
		expect.equal(env.service:stats().dirty, 1)
		expect.equal(env.service:stats().noBudget, 1)
		env.budget = 100
		expect.equal(env.service:flush(true), 1)
		expect.equal(env.service:stats().dirty, 0)
	end)

	t.test("keeps a failed write dirty", function()
		local env = setup()
		local key = LeaderboardService.playerKey(7)
		env.service:report("RobuxSpent", key, 10)
		env.stores.RobuxSpent.failNext = 1
		expect.equal(env.service:flush(true), 0)
		expect.equal(env.service:stats().failures, 1)
		expect.equal(env.service:stats().dirty, 1)
		expect.equal(env.service:flush(true), 1)
		expect.equal(env.stores.RobuxSpent.data[key], 10)
	end)

	t.test("adds playtime as whole-second increments", function()
		local env = setup()
		local hours = env.stores.HoursPlayed
		local key = LeaderboardService.playerKey(7)
		env.service:addPlaytime(7, 125.5)
		expect.equal(env.service:flush(true), 1)
		expect.equal(hours.increments, 1)
		expect.equal(hours.lastDelta, 125)
		expect.equal(hours.data[key], 125)
		expect.equal(env.service:stats().playtimePending["7"], 0.5)
		expect.equal(env.service:you("HoursPlayed", key), 125)
		env.service:addPlaytime(7, 0.6)
		expect.equal(env.service:flush(true), 1)
		expect.equal(hours.increments, 2)
		expect.equal(hours.lastDelta, 1)
		expect.equal(hours.data[key], 126)
		local before = env.service:stats().playtimePending["7"]
		env.service:addPlaytime(7, 0)
		env.service:addPlaytime(7, -1)
		env.service:addPlaytime(7, 0 / 0)
		env.service:addPlaytime(7, 4000)
		expect.equal(env.service:stats().playtimePending["7"], before)
		expect.truthy(before < 1)
		expect.equal(env.service:flush(true), 0)
		expect.equal(hours.increments, 2)
	end)

	t.test("rejects invalid reports", function()
		local env = setup()
		local service = env.service
		expect.falsy(service:report("Unknown", "player_7", 5))
		expect.falsy(service:report("HoursPlayed", "player_7", 5))
		expect.falsy(service:report("RobuxSpent", "player_7", -1))
		expect.falsy(service:report("RobuxSpent", "player_7", 0 / 0))
		expect.falsy(service:report("RobuxSpent", "player_x", 5))
		expect.falsy(service:report("CashEarned", "save_bad", 5))
		expect.falsy(service:report("Reputation", "player_7", 5))
		expect.equal(service:stats().dirty, 0)
		expect.equal(service:flush(true), 0)
	end)

	t.test("refresh publishes top rows and ranks", function()
		local names: { [number]: string } = {}
		for owner = 1, 12 do
			if owner ~= 2 then
				names[owner] = "U" .. owner
			end
		end
		local env = setup(names)
		local keys = {}
		for owner = 1, 12 do
			local key = LeaderboardService.saveKey(saveId(owner, "c"))
			keys[owner] = key
			env.stores.CashEarned.data[key] = (13 - owner) * 100
		end
		env.stores.RobuxSpent.data[LeaderboardService.playerKey(5)] = 40
		expect.equal(env.service:refresh(), 4)
		local rows = env.published.CashEarned
		expect.equal(#rows, GameConfig.Leaderboards.TopCount)
		for index, row in rows do
			expect.equal(row.rank, index)
			if index > 1 then
				expect.truthy(row.value <= rows[index - 1].value)
			end
		end
		expect.equal(rows[1].name, "U1")
		expect.equal(rows[1].value, 1200)
		expect.equal(rows[2].name, nil)
		expect.equal(env.published.RobuxSpent[1].name, "U5")
		expect.equal(#env.published.HoursPlayed, 0)
		local _, third = env.service:you("CashEarned", keys[3])
		expect.equal(third, 3)
		local _, eleventh = env.service:you("CashEarned", keys[11])
		expect.equal(eleventh, 11)
		local _, absent = env.service:you("CashEarned", LeaderboardService.saveKey(saveId(99, "d")))
		expect.equal(absent, 0)

		env.stores.CashEarned.failNext = 1
		local before = env.publishCount.CashEarned
		expect.equal(env.service:refresh(), 3)
		expect.equal(env.publishCount.CashEarned, before)
		local _, kept = env.service:you("CashEarned", keys[3])
		expect.equal(kept, 3)
	end)

	t.test("flushUser writes only that player", function()
		local env = setup()
		env.service:addPlaytime(7, 30)
		env.service:addPlaytime(8, 30)
		env.service:report("RobuxSpent", LeaderboardService.playerKey(7), 10)
		env.service:report("RobuxSpent", LeaderboardService.playerKey(8), 20)
		env.service:report("CashEarned", LeaderboardService.saveKey(saveId(7, "e")), 500)
		expect.equal(env.service:flushUser(7), 2)
		expect.equal(env.stores.HoursPlayed.increments, 1)
		expect.equal(env.stores.HoursPlayed.data[LeaderboardService.playerKey(7)], 30)
		expect.equal(env.stores.HoursPlayed.data[LeaderboardService.playerKey(8)], nil)
		expect.equal(env.stores.RobuxSpent.sets, 1)
		expect.equal(env.stores.RobuxSpent.data[LeaderboardService.playerKey(7)], 10)
		expect.equal(env.stores.CashEarned.sets, 0)
	end)

	t.test("an in-flight playtime key is not written twice", function()
		local env = setup()
		env.service:addPlaytime(7, 20)
		local inner = -1
		env.stores.HoursPlayed.onIncrement = function()
			inner = env.service:flushUser(7)
		end
		expect.equal(env.service:flushUser(7), 1)
		expect.equal(inner, 0)
		expect.equal(env.stores.HoursPlayed.increments, 1)
		expect.equal(env.stores.HoursPlayed.data[LeaderboardService.playerKey(7)], 20)
	end)
end

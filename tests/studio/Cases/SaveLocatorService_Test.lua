--!strict
-- CM2-S3: the save-to-server map over a fake MemoryStore HashMap. No test touches a real
-- MemoryStore.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local SaveProfile = require(Shared:WaitForChild("SaveProfile"))
	local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
	local SaveLocatorService = require(Services:WaitForChild("SaveLocatorService"))
	local expect = t.expect

	local SAVES = GameConfig.Saves
	local PLACE_ID = 7001
	local HOST = 42
	local OTHER_HOST = 43
	local SAVE_ID = "42_00000000000000a1"
	local MAP_KEY_LIMIT = 128 -- real MemoryStore HashMap rule
	local MAX_TTL = 3888000 -- 45 days

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

	local function checkKey(key: string)
		if #key > MAP_KEY_LIMIT then
			error("KeyNameLimit: key exceeds 128 characters")
		end
	end

	local function checkTtl(ttl: unknown)
		if type(ttl) ~= "number" or ttl ~= math.floor(ttl) or ttl < 1 or ttl > MAX_TTL then
			error("InvalidExpiration")
		end
	end

	-- Stores {value, expiresAt} and deep-copies; an entry at or past expiresAt reads as nil.
	-- Throws while failCount > 0; an optional map.beforeUpdate(key) runs first.
	local function fakeMap(env)
		local map: any = { entries = {}, failCount = 0, beforeUpdate = nil, updates = 0 }
		local function current(key: string)
			local entry = map.entries[key]
			if entry == nil or env.now >= entry.expiresAt then
				return nil
			end
			return deepCopy(entry.value)
		end
		map.current = current
		function map.UpdateAsync(_, key: string, transform, ttl)
			checkKey(key)
			checkTtl(ttl)
			if map.beforeUpdate then
				map.beforeUpdate(key)
			end
			if map.failCount > 0 then
				error("MemoryStore throttled")
			end
			local nextValue = transform(current(key))
			if nextValue ~= nil then
				map.entries[key] = { value = deepCopy(nextValue), expiresAt = env.now + ttl }
				map.updates += 1
			end
			return current(key)
		end
		function map.GetAsync(_, key: string)
			checkKey(key)
			if map.failCount > 0 then
				error("MemoryStore throttled")
			end
			return current(key)
		end
		function map.SetAsync(_, key: string, value, ttl)
			checkKey(key)
			checkTtl(ttl)
			if map.failCount > 0 then
				error("MemoryStore throttled")
			end
			map.entries[key] = { value = deepCopy(value), expiresAt = env.now + ttl }
			return true
		end
		return map
	end

	local function setup()
		local env: any = { now = 1000, waits = 0 }
		env.map = fakeMap(env)
		local function clock(): number
			return env.now
		end
		local function wait(_seconds: number)
			env.waits += 1
		end
		env.a = SaveLocatorService.new(env.map, "job-a", PLACE_ID, clock, wait)
		env.b = SaveLocatorService.new(env.map, "job-b", PLACE_ID, clock, wait)
		return env
	end

	local function stored(env, saveId: string)
		return env.map.current(SaveLocatorService.keyFor(saveId))
	end

	t.test("claims a free save and renews it", function()
		local env = setup()
		local outcome = env.a:claim(SAVE_ID, HOST)
		expect.equal(outcome, "Claimed")
		local value = stored(env, SAVE_ID)
		expect.equal(value.jobId, "job-a")
		expect.equal(value.placeId, PLACE_ID)
		expect.equal(value.hostUserId, HOST)
		expect.equal(value.renewedAt, 1000)
		expect.equal(value.releasedAt, nil)
		env.now += 60
		expect.equal(env.a:claim(SAVE_ID, HOST), "Claimed")
		local entry = env.map.entries[SaveLocatorService.keyFor(SAVE_ID)]
		expect.equal(entry.expiresAt, env.now + SAVES.LocatorTtlSeconds)
		expect.equal(entry.expiresAt, 1150)
		expect.equal(stored(env, SAVE_ID).renewedAt, 1060)
		local longest = string.rep("9", 19) .. "_" .. string.rep("f", 16)
		expect.truthy(SaveProfile.isSaveId(longest))
		expect.truthy(#SaveLocatorService.keyFor(longest) <= 41)
	end)

	t.test("never lets two servers hold one save", function()
		local env = setup()
		expect.equal(env.a:claim(SAVE_ID, HOST), "Claimed")
		local outcome, location = env.b:claim(SAVE_ID, OTHER_HOST)
		expect.equal(outcome, "HeldElsewhere")
		expect.equal(location.jobId, "job-a")
		expect.equal(location.placeId, PLACE_ID)
		expect.equal(location.hostUserId, HOST)
		expect.equal(stored(env, SAVE_ID).jobId, "job-a")

		-- job-a claims first, inside job-b's call: job-b's transform sees job-a's entry.
		local race = setup()
		local raced = false
		race.map.beforeUpdate = function()
			if not raced then
				raced = true
				expect.equal(race.a:claim(SAVE_ID, HOST), "Claimed")
			end
		end
		local raceOutcome, raceLocation = race.b:claim(SAVE_ID, OTHER_HOST)
		expect.truthy(raced)
		expect.equal(raceOutcome, "HeldElsewhere")
		expect.equal(raceLocation.jobId, "job-a")
		expect.equal(stored(race, SAVE_ID).jobId, "job-a")
	end)

	t.test("frees a save after a crash once the TTL passes", function()
		local env = setup()
		expect.equal(env.a:claim(SAVE_ID, HOST), "Claimed")
		env.now = 1000 + 89
		expect.equal(env.b:claim(SAVE_ID, OTHER_HOST), "HeldElsewhere")
		env.now = 1000 + 91
		expect.equal(env.b:claim(SAVE_ID, OTHER_HOST), "Claimed")
		expect.equal(stored(env, SAVE_ID).jobId, "job-b")
		local outcome, location = env.a:claim(SAVE_ID, HOST)
		expect.equal(outcome, "HeldElsewhere")
		expect.equal(location.jobId, "job-b")
		expect.truthy(SAVES.LocatorTtlSeconds < GameConfig.SessionLockSeconds)
		expect.truthy(3 * SAVES.LocatorRenewSeconds <= SAVES.LocatorTtlSeconds)
	end)

	t.test("releases only its own claim", function()
		local env = setup()
		expect.equal(env.a:claim(SAVE_ID, HOST), "Claimed")
		local before = stored(env, SAVE_ID)
		expect.equal(env.b:release(SAVE_ID), false)
		local unchanged = stored(env, SAVE_ID)
		expect.equal(unchanged.jobId, before.jobId)
		expect.equal(unchanged.hostUserId, before.hostUserId)
		expect.equal(unchanged.renewedAt, before.renewedAt)
		expect.equal(unchanged.releasedAt, nil)
		expect.equal(env.a:release(SAVE_ID), true)
		local tombstone = stored(env, SAVE_ID)
		expect.equal(tombstone.jobId, "job-a")
		expect.equal(tombstone.placeId, PLACE_ID)
		expect.equal(tombstone.releasedAt, 1000)
		expect.equal(tombstone.hostUserId, nil)
		local entry = env.map.entries[SaveLocatorService.keyFor(SAVE_ID)]
		expect.equal(entry.expiresAt, env.now + SAVES.LocatorReleasedTtlSeconds)
		expect.equal(env.b:claim(SAVE_ID, OTHER_HOST), "Claimed")
		local seen = env.a:lookup(SAVE_ID)
		expect.truthy(seen)
		expect.equal(seen.jobId, "job-b")
		expect.equal(seen.hostUserId, OTHER_HOST)
	end)

	t.test("looks up only other servers in this place", function()
		local env = setup()
		expect.equal(env.a:claim(SAVE_ID, HOST), "Claimed")
		expect.equal(env.a:lookup(SAVE_ID), nil)
		local location, lookupError = env.b:lookup(SAVE_ID)
		expect.equal(lookupError, nil)
		expect.equal(location.jobId, "job-a")
		expect.equal(location.placeId, PLACE_ID)
		expect.equal(location.hostUserId, HOST)

		local key = SaveLocatorService.keyFor(SAVE_ID)
		local function put(value)
			env.map:SetAsync(key, value, 60)
		end
		put({ jobId = "job-c", placeId = PLACE_ID + 1, hostUserId = HOST, renewedAt = 1000 })
		expect.equal(env.b:lookup(SAVE_ID), nil)
		put("job-c")
		expect.equal(env.b:lookup(SAVE_ID), nil)
		put({ jobId = "", placeId = PLACE_ID, hostUserId = HOST, renewedAt = 1000 })
		expect.equal(env.b:lookup(SAVE_ID), nil)
		put({ jobId = string.rep("j", 65), placeId = PLACE_ID, hostUserId = HOST, renewedAt = 1000 })
		expect.equal(env.b:lookup(SAVE_ID), nil)
		put({ jobId = "job-c", placeId = PLACE_ID, releasedAt = 1000 })
		expect.equal(env.b:lookup(SAVE_ID), nil)
		put({ jobId = "job-c", placeId = PLACE_ID, hostUserId = HOST, renewedAt = 1000 })
		expect.equal(env.b:lookup(SAVE_ID).jobId, "job-c")

		local throwing = SaveLocatorService.new(
			{
				GetAsync = function()
					error("MemoryStore down")
				end,
			},
			"job-b",
			PLACE_ID,
			function(): number
				return env.now
			end,
			function() end
		)
		local missing, missingError = throwing:lookup(SAVE_ID)
		expect.equal(missing, nil)
		expect.equal(missingError, "LocatorUnavailable")
	end)

	t.test("reports an unavailable store without throwing", function()
		local env = setup()
		env.map.failCount = 2
		local called, outcome, location = pcall(function()
			return env.a:claim(SAVE_ID, HOST)
		end)
		expect.truthy(called)
		expect.equal(outcome, "Unavailable")
		expect.equal(location, nil)
		local releaseCalled, released = pcall(function()
			return env.a:release(SAVE_ID)
		end)
		expect.truthy(releaseCalled)
		expect.equal(released, false)
		expect.equal(env.map.updates, 0)
		-- One wait between the two attempts of each call, no retry storm.
		expect.equal(env.waits, 2 * (SAVES.LocatorAttempts - 1))
	end)
end

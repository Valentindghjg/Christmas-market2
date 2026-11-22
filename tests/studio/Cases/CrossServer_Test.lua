--!strict
-- CM2-S3: one server per save with the real SaveSlot, SaveLocator, Persistence, CompanyState,
-- Plot and InviteCode services over fake DataStores and one fake MemoryStore HashMap. Two
-- stacks (job-a and job-b) share the stores and the map and stand for two servers. Teleports
-- are recorded. No test touches a real DataStore, MemoryStore or TeleportService.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local Protocol = require(Shared:WaitForChild("Protocol"))
	local SaveProfile = require(Shared:WaitForChild("SaveProfile"))
	local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
	local CompanyStateService = require(Services:WaitForChild("CompanyStateService"))
	local InviteCodeService = require(Services:WaitForChild("InviteCodeService"))
	local PersistenceService = require(Services:WaitForChild("PersistenceService"))
	local PlotService = require(Services:WaitForChild("PlotService"))
	local SaveLocatorService = require(Services:WaitForChild("SaveLocatorService"))
	local SaveSlotService = require(Services:WaitForChild("SaveSlotService"))
	local expect = t.expect

	local SAVES = GameConfig.Saves
	local OWNER = 42
	local FRIEND = 43
	local THIRD = 44
	local FOURTH = 45
	local PLACE_ID = 7001
	local KEY_NAME_LIMIT = 50 -- real DataStore rule (KeyNameLimit)
	local MAP_KEY_LIMIT = 128 -- real MemoryStore HashMap rule
	local MAX_TTL = 3888000 -- 45 days
	local WRONG_CODE = "54321"
	local JOIN_FAILURE_ACTION = "fail"

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

	-- Deep-copies on read and write like a real DataStore; throws while failCount > 0 and
	-- always for a key in failKeys. An optional store.beforeUpdate(key) runs first.
	local function fakeStore()
		local store: any = { records = {}, failCount = 0, failKeys = {}, writes = 0, calls = 0, beforeUpdate = nil }
		function store.UpdateAsync(_, key: string, transform)
			store.calls += 1
			if #key > KEY_NAME_LIMIT then
				error("KeyNameLimit: Key name exceeds the 50 character limit.")
			end
			if store.beforeUpdate then
				store.beforeUpdate(key)
			end
			if store.failKeys[key] then
				error("Throttled")
			end
			if store.failCount > 0 then
				store.failCount -= 1
				error("Throttled")
			end
			local nextValue = transform(deepCopy(store.records[key]))
			if nextValue ~= nil then
				store.records[key] = deepCopy(nextValue)
				store.writes += 1
			end
			return deepCopy(store.records[key])
		end
		return store
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

	-- Same fake HashMap as SaveLocatorService_Test (Amendment A1.6): stores {value, expiresAt},
	-- deep-copies, reads an expired entry as nil and throws while failCount > 0.
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

	local function noWait() end

	local function newStack(env, jobId: string)
		local stack: any = { jobId = jobId, activated = {}, deactivated = {}, loads = 0, plotTeleports = {} }
		local function clock(): number
			return env.now
		end
		stack.persistence = PersistenceService.new(env.companyStore, jobId, clock, noWait)
		local originalLoad = stack.persistence.load
		stack.persistence.load = function(...)
			stack.loads += 1
			return originalLoad(...)
		end
		stack.companies = CompanyStateService.new(stack.persistence, clock)
		stack.plots = PlotService.new({ "Plot_01", "Plot_02", "Plot_03" })
		stack.invites = InviteCodeService.new(env.inviteStore, clock, noWait, function(): number
			return env.randomCode()
		end)
		stack.locator = SaveLocatorService.new(env.map, jobId, PLACE_ID, clock, noWait)
		stack.service = SaveSlotService.new({
			profileStore = env.profileStore,
			persistence = stack.persistence,
			companies = stack.companies,
			plots = stack.plots,
			invites = stack.invites,
			userName = function(userId: number): string?
				return env.names[userId]
			end,
			clock = clock,
			wait = noWait,
			newSaveId = function(userId: number): string
				env.saveCounter += 1
				return string.format("%d_%016x", userId, env.saveCounter)
			end,
			filterName = function(_, text: string)
				return true, text
			end,
			-- The S1 no-free-plot teleport.
			teleport = function(userId: number, data)
				table.insert(stack.plotTeleports, { userId = userId, data = data })
				return true
			end,
			locator = stack.locator,
			teleportToServer = function(userId: number, placeId: number, targetJobId: string, data)
				table.insert(env.teleports, { userId = userId, placeId = placeId, jobId = targetJobId, data = data })
				return true, nil
			end,
		})
		stack.service:setActivationHandlers(function(...)
			table.insert(stack.activated, table.pack(...))
		end, function(...)
			table.insert(stack.deactivated, table.pack(...))
		end)
		return stack
	end

	local function setup()
		local env: any = {
			now = 1000,
			companyStore = fakeStore(),
			profileStore = fakeStore(),
			inviteStore = fakeStore(),
			nextCode = 12345,
			saveCounter = 0,
			teleports = {},
			names = { [OWNER] = "OwnerName", [FRIEND] = "FriendName", [THIRD] = "ThirdName", [FOURTH] = "FourthName" },
		}
		env.randomCode = function(): number
			env.nextCode += 1
			return env.nextCode - 1
		end
		env.map = fakeMap(env)
		env.a = newStack(env, "job-a")
		env.b = newStack(env, "job-b")
		return env
	end

	local requestNumber = 0
	local function request(action: string, payload: any?)
		requestNumber += 1
		return {
			version = 1,
			requestId = string.format("cross_req_%06d", requestNumber),
			action = action,
			payload = payload or {},
		}
	end

	local function act(stack, userId: number, action: string, payload: any?)
		return stack.service:handle(userId, request(action, payload))
	end

	local function recordOf(env, saveId: string)
		return env.companyStore.records[PersistenceService.keyFor("save:" .. saveId)]
	end

	local function profileOf(env, userId: number)
		return env.profileStore.records[SaveSlotService.profileKey(userId)]
	end

	local function mapValue(env, saveId: string)
		return env.map.current(SaveLocatorService.keyFor(saveId))
	end

	local function failuresOf(stack, userId: number, now: number): number
		return Protocol.recentCount(stack.service._joinFailures, userId, JOIN_FAILURE_ACTION, now)
	end

	-- The owner creates a co-op save on job-a and plays it, which claims the map entry and
	-- gives the save a code.
	local function coopSave(env, size: string?)
		local stack = env.a
		expect.truthy(stack.service:openProfile(OWNER))
		local created = act(stack, OWNER, "Save.Create", { name = "Coop Lot", size = size or "Duo" })
		expect.truthy(created.ok)
		local saveId = created.data.saveId
		local ok, reason, data = stack.service:play(OWNER, saveId)
		expect.equal(reason, nil)
		expect.truthy(ok)
		local companyId = "save:" .. saveId
		local info = stack.companies:teamInfo(companyId)
		return { saveId = saveId, companyId = companyId, code = info and info.inviteCode, plotId = data.plotId }
	end

	local function rowFor(response, saveId: string)
		for _, row in ipairs(response.data.saves) do
			if row.saveId == saveId then
				return row
			end
		end
		return nil
	end

	t.test("shows who plays a save on another server", function()
		local env = setup()
		local save = coopSave(env)
		expect.truthy(act(env.a, FRIEND, "Save.Join", { code = save.code }).ok)
		local held = mapValue(env, save.saveId)
		expect.equal(held.jobId, "job-a")
		expect.equal(held.hostUserId, OWNER)

		local listed = act(env.b, FRIEND, "Save.List")
		expect.truthy(listed.ok)
		local row = rowFor(listed, save.saveId)
		expect.truthy(row)
		expect.equal(row.elsewhere, true)
		expect.equal(row.hostName, "OwnerName")
		expect.equal(row.name, nil)
		-- Solo rows are never looked up.
		for _, other in ipairs(listed.data.saves) do
			if other.size == "Solo" then
				expect.equal(other.elsewhere, nil)
			end
		end
		local played = act(env.b, FRIEND, "Save.Play", { saveId = save.saveId })
		expect.falsy(played.ok)
		expect.equal(played.errorCode, "SaveInUseElsewhere")
		expect.equal(played.data.hostName, "OwnerName")
		expect.equal(env.b.loads, 0)
		expect.equal(env.b.plots:getPlot(save.companyId), nil)
		expect.equal(mapValue(env, save.saveId).jobId, "job-a")
		for key in pairs(env.map.entries) do
			expect.truthy(#key <= 41)
		end
	end)

	t.test("names the owner, else the longest-playing member", function()
		local env = setup()
		local save = coopSave(env)
		expect.truthy(act(env.a, FRIEND, "Save.Join", { code = save.code }).ok)
		-- The owner leaves; FRIEND plays first, then the owner attaches.
		expect.truthy(env.a.service:leave(OWNER, true))
		local ok, reason = env.a.service:play(FRIEND, save.saveId)
		expect.equal(reason, nil)
		expect.truthy(ok)
		expect.equal(mapValue(env, save.saveId).hostUserId, FRIEND)
		ok, reason = env.a.service:play(OWNER, save.saveId)
		expect.equal(reason, nil)
		expect.truthy(ok)
		local renewedOk, renewed, failures = env.a.service:renewLocations()
		expect.truthy(renewedOk)
		expect.equal(renewed, 1)
		expect.equal(failures, 0)
		expect.equal(mapValue(env, save.saveId).hostUserId, OWNER)
		expect.equal(mapValue(env, save.saveId).jobId, "job-a")
		-- The owner switches to another save; the member who played it longest is X.
		local starterId = profileOf(env, OWNER).saves[1].saveId
		expect.truthy(env.a.service:play(OWNER, starterId))
		renewedOk, renewed, failures = env.a.service:renewLocations()
		expect.truthy(renewedOk)
		expect.equal(renewed, 2)
		expect.equal(failures, 0)
		expect.equal(mapValue(env, save.saveId).hostUserId, FRIEND)
		expect.equal(mapValue(env, starterId).hostUserId, OWNER)
	end)

	t.test("a code join while another server plays the save offers that server", function()
		local env = setup()
		local save = coopSave(env)
		expect.truthy(env.b.service:openProfile(THIRD))
		local joined = act(env.b, THIRD, "Save.Join", { code = save.code })
		expect.falsy(joined.ok)
		expect.equal(joined.errorCode, "SaveInUseElsewhere")
		expect.equal(joined.data.hostName, "OwnerName")
		expect.equal(failuresOf(env.b, THIRD, env.now), 0)
		expect.equal(recordOf(env, save.saveId).members["44"], nil)
		expect.equal(SaveProfile.find(profileOf(env, THIRD), save.saveId), nil)
	end)

	t.test("Save.Teleport sends the player to the server holding the save", function()
		local env = setup()
		local save = coopSave(env)
		expect.truthy(act(env.a, FRIEND, "Save.Join", { code = save.code }).ok)
		local sent = act(env.b, FRIEND, "Save.Teleport", { saveId = save.saveId })
		expect.truthy(sent.ok)
		expect.equal(sent.data.teleporting, true)
		expect.equal(#env.teleports, 1)
		local first = env.teleports[1]
		expect.equal(first.userId, FRIEND)
		expect.equal(first.placeId, PLACE_ID)
		expect.equal(first.jobId, "job-a")
		expect.equal(first.data.saveId, save.saveId)
		expect.equal(first.data.code, nil)

		expect.truthy(env.b.service:openProfile(THIRD))
		local byCode = act(env.b, THIRD, "Save.Teleport", { code = save.code })
		expect.truthy(byCode.ok)
		expect.equal(#env.teleports, 2)
		expect.equal(env.teleports[2].userId, THIRD)
		expect.equal(env.teleports[2].jobId, "job-a")
		expect.equal(env.teleports[2].data.saveId, save.saveId)
		expect.equal(env.teleports[2].data.code, save.code)

		local wrong = act(env.b, THIRD, "Save.Teleport", { code = WRONG_CODE })
		expect.equal(wrong.errorCode, "InviteCodeInvalid")
		expect.equal(failuresOf(env.b, THIRD, env.now), 1)
		expect.equal(#env.teleports, 2)

		-- Nobody plays it any more.
		expect.truthy(env.a.service:leave(OWNER, true))
		local gone = act(env.b, FRIEND, "Save.Teleport", { saveId = save.saveId })
		expect.equal(gone.errorCode, "SaveNotElsewhere")
		expect.equal(#env.teleports, 2)
		-- THIRD has no entry for the save.
		local notListed = act(env.b, THIRD, "Save.Teleport", { saveId = save.saveId })
		expect.equal(notListed.errorCode, "SaveNotFound")
		expect.equal(#env.teleports, 2)
	end)

	t.test("arrival attaches the player on the save's server", function()
		local env = setup()
		local save = coopSave(env, "Trio")
		expect.truthy(act(env.a, FRIEND, "Save.Join", { code = save.code }).ok)
		local ok, reason, data = env.a.service:arrive(FRIEND, { saveId = save.saveId })
		expect.equal(reason, nil)
		expect.truthy(ok)
		expect.equal(data.plotId, save.plotId)
		expect.equal(env.a.loads + env.b.loads, 1)
		expect.equal(env.a.service:activeCompanyId(FRIEND), save.companyId)

		ok, reason, data = env.a.service:arrive(THIRD, { saveId = save.saveId, code = save.code })
		expect.equal(reason, nil)
		expect.truthy(ok)
		expect.equal(data.plotId, save.plotId)
		expect.equal(env.a.loads + env.b.loads, 1)
		local entry = SaveProfile.find(profileOf(env, THIRD), save.saveId)
		expect.truthy(entry)
		expect.equal(entry.role, "Member")
		expect.equal(env.a.companies:memberRole(save.companyId, THIRD), "Member")
		expect.equal(#env.a.service:playersOn(save.companyId), 3)

		local wrongOk, wrongReason = env.a.service:arrive(FOURTH, { saveId = save.saveId, code = WRONG_CODE })
		expect.falsy(wrongOk)
		expect.equal(wrongReason, "InviteCodeInvalid")
		expect.equal(failuresOf(env.a, FOURTH, env.now), 1)
		local missingOk, missingReason = env.a.service:arrive(FOURTH, { saveId = save.saveId })
		expect.falsy(missingOk)
		expect.equal(missingReason, "SaveNotFound")
		expect.equal(env.a.service:activeCompanyId(FOURTH), nil)
	end)

	t.test("arrival loads the save when it is no longer played there", function()
		local env = setup()
		local save = coopSave(env)
		expect.truthy(act(env.a, FRIEND, "Save.Join", { code = save.code }).ok)
		expect.truthy(env.a.service:leave(OWNER, true))
		expect.truthy(mapValue(env, save.saveId).releasedAt)
		local ok, reason, data = env.a.service:arrive(FRIEND, { saveId = save.saveId })
		expect.equal(reason, nil)
		expect.truthy(ok)
		expect.truthy(data.plotId)
		expect.equal(env.a.loads, 2)
		local held = mapValue(env, save.saveId)
		expect.equal(held.jobId, "job-a")
		expect.equal(held.releasedAt, nil)
		expect.equal(held.hostUserId, FRIEND)
		expect.equal(recordOf(env, save.saveId)._session.jobId, "job-a")
	end)

	t.test("a crashed server's save plays elsewhere after the TTL and the lock", function()
		local env = setup()
		local save = coopSave(env)
		expect.equal(mapValue(env, save.saveId).jobId, "job-a")
		expect.equal(recordOf(env, save.saveId)._session.jobId, "job-a")
		-- job-a crashes: no leave, no renewal, no release.
		env.now = 1000 + 91
		expect.truthy(env.b.service:openProfile(OWNER))
		local ok, reason = env.b.service:play(OWNER, save.saveId)
		expect.falsy(ok)
		expect.equal(reason, "SessionLocked")
		local tombstone = mapValue(env, save.saveId)
		expect.equal(tombstone.jobId, "job-b")
		expect.truthy(tombstone.releasedAt)
		expect.equal(recordOf(env, save.saveId)._session.jobId, "job-a")
		expect.equal(env.b.plots:getPlot(save.companyId), nil)

		env.now = 1000 + 121
		ok, reason = env.b.service:play(OWNER, save.saveId)
		expect.equal(reason, nil)
		expect.truthy(ok)
		expect.equal(recordOf(env, save.saveId)._session.jobId, "job-b")
		local held = mapValue(env, save.saveId)
		expect.equal(held.jobId, "job-b")
		expect.equal(held.releasedAt, nil)
	end)

	t.test("the last leaver and a failed load release the entry", function()
		local env = setup()
		local save = coopSave(env)
		expect.truthy(env.b.service:openProfile(OWNER))
		expect.equal(env.b.locator:lookup(save.saveId).jobId, "job-a")
		expect.truthy(env.a.service:leave(OWNER, true))
		expect.equal(env.b.locator:lookup(save.saveId), nil)
		local tombstone = mapValue(env, save.saveId)
		expect.equal(tombstone.jobId, "job-a")
		expect.truthy(tombstone.releasedAt)

		-- Another server holds the lock but not the map entry: the load fails and releases.
		env.now += 31
		recordOf(env, save.saveId)._session = { jobId = "thief", expiresAt = env.now + 300 }
		local ok, reason = env.a.service:play(OWNER, save.saveId)
		expect.falsy(ok)
		expect.equal(reason, "SessionLocked")
		local released = mapValue(env, save.saveId)
		expect.equal(released.jobId, "job-a")
		expect.truthy(released.releasedAt)
		expect.equal(env.b.locator:lookup(save.saveId), nil)
		expect.equal(env.a.plots:getPlot(save.companyId), nil)
	end)

	t.test("a failed final save keeps the entry", function()
		local env = setup()
		local save = coopSave(env)
		env.companyStore.failKeys[PersistenceService.keyFor(save.companyId)] = true
		local ok = env.a.service:leave(OWNER, true)
		expect.falsy(ok)
		local held = mapValue(env, save.saveId)
		expect.equal(held.jobId, "job-a")
		expect.equal(held.releasedAt, nil)
		expect.equal(held.hostUserId, OWNER)
	end)

	t.test("renewal survives a store outage", function()
		local env = setup()
		local save = coopSave(env)
		expect.truthy(env.a.service:openProfile(FRIEND))
		local friendSave = profileOf(env, FRIEND).saves[1].saveId
		expect.truthy(env.a.service:play(FRIEND, friendSave))
		env.map.failCount = 2
		local ok, renewed, failures = env.a.service:renewLocations()
		expect.falsy(ok)
		expect.equal(renewed, 0)
		expect.equal(failures, 2)
		env.map.failCount = 0
		env.now += SAVES.LocatorRenewSeconds
		ok, renewed, failures = env.a.service:renewLocations()
		expect.truthy(ok)
		expect.equal(renewed, 2)
		expect.equal(failures, 0)
		local entry = env.map.entries[SaveLocatorService.keyFor(save.saveId)]
		expect.equal(entry.expiresAt, env.now + SAVES.LocatorTtlSeconds)
		expect.equal(mapValue(env, friendSave).hostUserId, FRIEND)
	end)

	t.test("a full server releases its claim before it sends the player on", function()
		local env = setup()
		expect.truthy(env.a.service:openProfile(OWNER))
		local created = act(env.a, OWNER, "Save.Create", { name = "Full Lot", size = "Duo" })
		expect.truthy(created.ok)
		local saveId = created.data.saveId
		for n = 1, 3 do
			expect.truthy(env.a.plots:claim("save:77_other_" .. n))
		end
		local ok, reason = env.a.service:play(OWNER, saveId)
		expect.falsy(ok)
		expect.equal(reason, "NoFreePlotTeleporting")
		expect.equal(#env.a.plotTeleports, 1)
		expect.equal(env.a.plotTeleports[1].userId, OWNER)
		expect.equal(env.a.plotTeleports[1].data.saveId, saveId)
		local tombstone = mapValue(env, saveId)
		expect.equal(tombstone.jobId, "job-a")
		expect.truthy(tombstone.releasedAt)

		expect.truthy(env.b.service:openProfile(OWNER))
		local played, playError = env.b.service:play(OWNER, saveId)
		expect.equal(playError, nil)
		expect.truthy(played)
		local held = mapValue(env, saveId)
		expect.equal(held.jobId, "job-b")
		expect.equal(held.releasedAt, nil)
		expect.equal(held.hostUserId, OWNER)
	end)
end

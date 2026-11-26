--!strict
-- CM2-S1: save slots per player, with the real Persistence, CompanyState and Plot services
-- over fake DataStores. No test touches a real DataStore.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local SaveProfile = require(Shared:WaitForChild("SaveProfile"))
	local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
	local CompanyStateService = require(Services:WaitForChild("CompanyStateService"))
	local LeaderboardService = require(Services:WaitForChild("LeaderboardService"))
	local PersistenceService = require(Services:WaitForChild("PersistenceService"))
	local PlotService = require(Services:WaitForChild("PlotService"))
	local PurchaseLedgerService = require(Services:WaitForChild("PurchaseLedgerService"))
	local SaveSlotService = require(Services:WaitForChild("SaveSlotService"))
	local expect = t.expect

	local USER = 42
	local PROFILE_KEY = "profile:42"
	local KEY_NAME_LIMIT = 50 -- real DataStore rule (KeyNameLimit)
	local MAX_USER_ID = 9223372036854774784 -- 2^63 - 1024, the largest Luau number below int64 max

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

	-- Deep-copies on read and write like a real DataStore; throws while failCount > 0.
	-- An optional store.beforeUpdate(key) runs at the start of every UpdateAsync.
	local function fakeStore()
		local store: any = { records = {}, failCount = 0, writes = 0, beforeUpdate = nil }
		function store.UpdateAsync(_, key: string, transform)
			if #key > KEY_NAME_LIMIT then
				error("KeyNameLimit: Key name exceeds the 50 character limit.")
			end
			if store.beforeUpdate then
				store.beforeUpdate(key)
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

	local function noWait() end

	local function setup(plotIds: { string }?)
		local env: any = {
			now = 1000,
			teleports = {},
			teleportResult = true,
			filterCalls = 0,
			activated = {},
			deactivated = {},
			companyWait = noWait,
			-- CM2-PP: lot-sign names per plot for Save.Plots.
			labels = {},
		}
		local function clock(): number
			return env.now
		end
		env.filter = function(_, text: string)
			return true, text
		end
		env.companyStore = fakeStore()
		env.profileStore = fakeStore()
		env.persistence = PersistenceService.new(env.companyStore, "job-a", clock, noWait)
		env.companies = CompanyStateService.new(env.persistence, clock, nil, function(seconds: number)
			env.companyWait(seconds)
		end)
		env.plots = PlotService.new(plotIds or { "Plot_01", "Plot_02" })
		local counter = 0
		env.service = SaveSlotService.new({
			profileStore = env.profileStore,
			persistence = env.persistence,
			companies = env.companies,
			plots = env.plots,
			clock = clock,
			wait = noWait,
			newSaveId = function(userId: number): string
				counter += 1
				return string.format("%d_%016x", userId, counter)
			end,
			filterName = function(userId: number, text: string)
				env.filterCalls += 1
				return env.filter(userId, text)
			end,
			teleport = function(userId: number, data)
				table.insert(env.teleports, { userId = userId, data = data })
				return env.teleportResult
			end,
			plotLabel = function(plotId: string): string?
				return env.labels[plotId]
			end,
		})
		env.service:setActivationHandlers(function(...)
			table.insert(env.activated, table.pack(...))
		end, function(...)
			table.insert(env.deactivated, table.pack(...))
		end)
		return env
	end

	local requestNumber = 0
	local function request(action: string, payload: any?, requestId: string?)
		requestNumber += 1
		return {
			version = 1,
			requestId = requestId or string.format("save_req_%06d", requestNumber),
			action = action,
			payload = payload or {},
		}
	end

	local function stored(env)
		return env.profileStore.records[PROFILE_KEY]
	end

	local function recordOf(env, saveId: string)
		return env.companyStore.records[PersistenceService.keyFor("save:" .. saveId)]
	end

	-- Opens the profile of a new player and returns the starter save's ID.
	local function starter(env): string
		local profile = env.service:openProfile(USER)
		expect.truthy(profile)
		return profile.saves[1].saveId
	end

	local function create(env, name: string?): string
		local response = env.service:handle(USER, request("Save.Create", { name = name }))
		expect.truthy(response.ok)
		return response.data.saveId
	end

	local function play(env, saveId: string, options: any?)
		return env.service:play(USER, saveId, options)
	end

	t.test("creates one starter save for a new player", function()
		local env = setup()
		local profile, reason = env.service:openProfile(USER)
		expect.equal(reason, nil)
		expect.equal(#profile.saves, 1)
		expect.equal(profile.saves[1].name, "Tree Lot 1")
		expect.equal(profile.legacyState, "None")
		expect.equal(profile.legacySaveId, nil)
		expect.equal(profile.nextSaveNumber, 2)
		expect.truthy(SaveProfile.validate(stored(env)))
		env.service:closeProfile(USER)
		local again = env.service:openProfile(USER)
		expect.equal(#again.saves, 1)
		expect.equal(#stored(env).saves, 1)
		expect.equal(again.saves[1].saveId, profile.saves[1].saveId)
	end)

	t.test("migrates a personal record into the first save on first open", function()
		local env = setup()
		local legacy = BusinessState.new("personal:42", 42)
		legacy.schemaVersion = 10
		legacy.saveName = nil
		legacy.saveSize = nil
		legacy.cash = 4321
		env.companyStore.records["company:personal:42"] = legacy
		local profile = env.service:openProfile(USER)
		expect.truthy(profile)
		expect.equal(#profile.saves, 1)
		expect.equal(profile.legacyState, "Done")
		local migratedTo = env.companyStore.records["company:personal:42"]._migratedTo
		expect.equal(profile.saves[1].saveId, migratedTo)
		expect.equal(profile.saves[1].name, "Tree Lot 1")
		local ok, reason = play(env, migratedTo)
		expect.equal(reason, nil)
		expect.truthy(ok)
		expect.equal(env.companies:snapshotForTest("save:" .. migratedTo).cash, 4321)
	end)

	t.test("fails closed when the profile cannot be read", function()
		local env = setup()
		env.profileStore.failCount = 3
		local profile, reason = env.service:openProfile(USER)
		expect.equal(profile, nil)
		expect.equal(reason, "ProfileUnavailable")
		expect.equal(stored(env), nil)
		expect.equal(env.companyStore.writes, 0)
		expect.equal(next(env.companyStore.records), nil)
		local later = env.service:openProfile(USER)
		expect.truthy(later)
		expect.equal(#later.saves, 1)
	end)

	t.test("never overwrites a corrupt profile", function()
		local env = setup()
		env.profileStore.records[PROFILE_KEY] = { profileVersion = 99, saves = "broken" }
		local profile, reason = env.service:openProfile(USER)
		expect.equal(profile, nil)
		expect.equal(reason, "ProfileCorrupt")
		local value = stored(env)
		expect.equal(value.profileVersion, 99)
		expect.equal(value.saves, "broken")
		expect.equal(env.profileStore.writes, 0)
		local listed = env.service:handle(USER, request("Save.List"))
		expect.equal(listed.errorCode, "ProfileCorrupt")
		expect.equal(env.profileStore.writes, 0)
	end)

	t.test("creates a save with a filtered name", function()
		local env = setup()
		starter(env)
		local response = env.service:handle(USER, request("Save.Create", { name = "  Snow   Lot " }))
		expect.truthy(response.ok)
		expect.equal(response.data.name, "Snow Lot")
		expect.equal(env.filterCalls, 1)
		local value = stored(env)
		expect.equal(#value.saves, 2)
		expect.equal(value.saves[2].name, "Snow Lot")
		expect.equal(value.saves[2].lastPlayedAt, 0)
		expect.equal(value.nextSaveNumber, 3)
		expect.equal(recordOf(env, response.data.saveId), nil)
		local default = env.service:handle(USER, request("Save.Create", {}))
		expect.equal(default.data.name, "Tree Lot 3")
		expect.equal(env.filterCalls, 1)
	end)

	t.test("rejects filtered, duplicate and invalid names", function()
		local env = setup()
		starter(env)
		local before = stored(env).updatedAt
		local writes = env.profileStore.writes
		env.filter = function()
			return true, "####"
		end
		expect.equal(
			env.service:handle(USER, request("Save.Create", { name = "Bad Word" })).errorCode,
			"NameNotAllowed"
		)
		env.filter = function()
			return false, "FilterUnavailable"
		end
		expect.equal(env.service:handle(USER, request("Save.Create", { name = "Fine" })).errorCode, "FilterUnavailable")
		env.filter = function(_, text)
			return true, text
		end
		expect.equal(env.service:handle(USER, request("Save.Create", { name = "tree LOT 1" })).errorCode, "NameInUse")
		expect.equal(env.service:handle(USER, request("Save.Create", { name = "A#B" })).errorCode, "NameInvalid")
		local value = stored(env)
		expect.equal(#value.saves, 1)
		expect.equal(value.nextSaveNumber, 2)
		expect.equal(value.updatedAt, before)
		expect.equal(env.profileStore.writes, writes)
	end)

	t.test("replays a create with the same request ID", function()
		local env = setup()
		starter(env)
		local first = env.service:handle(USER, request("Save.Create", { name = "Pine" }, "create_same_1"))
		local second = env.service:handle(USER, request("Save.Create", { name = "Pine" }, "create_same_1"))
		expect.truthy(first.ok)
		expect.truthy(second.ok)
		expect.equal(second.data.saveId, first.data.saveId)
		expect.equal(second.data.name, "Pine")
		expect.equal(#stored(env).saves, 2)
	end)

	t.test("stops at the save cap", function()
		local env = setup()
		local profile = SaveProfile.new(USER, 10)
		profile.legacyState = "None"
		for number = 1, GameConfig.Saves.MaxSavesPerPlayer do
			table.insert(profile.saves, {
				saveId = string.format("42_%016x", 1000 + number),
				name = "Lot " .. number,
				role = "Owner",
				size = "Solo",
				createdAt = number,
				lastPlayedAt = 0,
			})
		end
		profile.nextSaveNumber = GameConfig.Saves.MaxSavesPerPlayer + 1
		env.profileStore.records[PROFILE_KEY] = profile
		local response = env.service:handle(USER, request("Save.Create", {}))
		expect.equal(response.errorCode, "SaveLimit")
		expect.equal(#stored(env).saves, GameConfig.Saves.MaxSavesPerPlayer)
	end)

	t.test("renames a save and the active record", function()
		local env = setup()
		local saveId = starter(env)
		expect.truthy(play(env, saveId))
		local response = env.service:handle(USER, request("Save.Rename", { saveId = saveId, name = " Snow  Lot " }))
		expect.truthy(response.ok)
		expect.equal(response.data.name, "Snow Lot")
		expect.equal(stored(env).saves[1].name, "Snow Lot")
		expect.equal(env.companies:snapshotForTest("save:" .. saveId).saveName, "Snow Lot")
		expect.equal(env.service:listFor(USER)[1].name, "Snow Lot")
	end)

	t.test("deletes only with the typed name", function()
		local env = setup()
		local first = starter(env)
		local extra = create(env, "Extra Lot")
		expect.truthy(play(env, extra))
		expect.truthy(play(env, first))
		expect.truthy(recordOf(env, extra))
		local wrong = env.service:handle(USER, request("Save.Delete", { saveId = extra, confirmName = "Extra" }))
		expect.equal(wrong.errorCode, "ConfirmationMismatch")
		expect.truthy(SaveProfile.find(stored(env), extra))
		expect.equal(recordOf(env, extra)._deletedAt, nil)
		local right = env.service:handle(USER, request("Save.Delete", { saveId = extra, confirmName = " extra  LOT " }))
		expect.truthy(right.ok)
		expect.equal(SaveProfile.find(stored(env), extra), nil)
		expect.equal(recordOf(env, extra)._deletedAt, 1000)
		expect.truthy(recordOf(env, extra).cash ~= nil)
	end)

	t.test("refuses to delete the active save", function()
		local env = setup()
		local saveId = starter(env)
		expect.truthy(play(env, saveId))
		local response =
			env.service:handle(USER, request("Save.Delete", { saveId = saveId, confirmName = "Tree Lot 1" }))
		expect.equal(response.errorCode, "SaveActive")
		expect.truthy(SaveProfile.find(stored(env), saveId))
		expect.equal(recordOf(env, saveId)._deletedAt, nil)
	end)

	t.test("plays a save on a free plot", function()
		local env = setup()
		local saveId = starter(env)
		local ok, reason, data = play(env, saveId)
		expect.truthy(ok)
		expect.equal(reason, nil)
		expect.equal(data.plotId, "Plot_01")
		expect.equal(env.plots:getPlot("save:" .. saveId), "Plot_01")
		expect.equal(env.service:activeCompanyId(USER), "save:" .. saveId)
		expect.equal(#env.activated, 1)
		local args = env.activated[1]
		expect.equal(args[1], USER)
		expect.equal(args[2], "save:" .. saveId)
		expect.equal(args[3], "Plot_01")
		expect.equal(args[4].cash, GameConfig.StartingCash)
		expect.equal(args[5].saveName, "Tree Lot 1")
		expect.equal(args[5].role, "Owner")
		expect.equal(stored(env).lastSaveId, saveId)
		expect.equal(stored(env).saves[1].lastPlayedAt, 1000)
		expect.equal(env.service:playersOn("save:" .. saveId)[1], USER)
		-- Playing the running save again keeps it.
		local again, _, againData = play(env, saveId)
		expect.truthy(again)
		expect.equal(againData.plotId, "Plot_01")
		expect.equal(#env.activated, 1)
	end)

	t.test("switching keeps the plot and isolates saves", function()
		local env = setup()
		local saveA = starter(env)
		local saveB = create(env, "Lot B")
		local _, _, playedA = play(env, saveA)
		local unitPrice = GameConfig.wholesaleFor("DouglasFir", "Medium") :: number
		local ordered = env.companies:handle("save:" .. saveA, USER, {
			version = 1,
			requestId = "order_switch_1",
			action = "Supplier.PlaceOrder",
			payload = { speciesId = "DouglasFir", sizeId = "Medium", quantity = 1 },
		})
		expect.truthy(ordered.ok)
		local snapshotA = env.companies:snapshotForTest("save:" .. saveA)
		expect.equal(snapshotA.cash, GameConfig.StartingCash - unitPrice)

		local okB, _, playedB = play(env, saveB)
		expect.truthy(okB)
		expect.equal(playedB.plotId, playedA.plotId)
		local snapshotB = env.companies:snapshotForTest("save:" .. saveB)
		expect.equal(snapshotB.cash, GameConfig.StartingCash)
		expect.equal(#snapshotB.pendingOrders, 0)
		expect.equal(env.companies:snapshotForTest("save:" .. saveA), nil)
		expect.truthy(recordOf(env, saveA).pendingOrders[ordered.data.orderId])
		expect.equal(recordOf(env, saveA)._session, nil)

		local okA, _, playedAgain = play(env, saveA)
		expect.truthy(okA)
		expect.equal(playedAgain.plotId, playedA.plotId)
		local backA = env.companies:snapshotForTest("save:" .. saveA)
		expect.equal(backA.cash, snapshotA.cash)
		expect.equal(backA.revision, snapshotA.revision)
		expect.equal(#backA.pendingOrders, 1)
		local recordB = recordOf(env, saveB)
		expect.equal(recordB.cash, GameConfig.StartingCash)
		expect.equal(next(recordB.pendingOrders), nil)
		expect.equal(recordB.saveName, "Lot B")
		expect.equal(recordB._session, nil)
	end)

	t.test("a deleted save cannot be played and leaves the list", function()
		local env = setup()
		starter(env)
		local gone = create(env, "Gone Lot")
		local record = BusinessState.new("save:" .. gone, USER, "Gone Lot")
		record._deletedAt = 500
		env.companyStore.records[PersistenceService.keyFor("save:" .. gone)] = record
		local ok, reason = play(env, gone)
		expect.falsy(ok)
		expect.equal(reason, "SaveDeleted")
		expect.equal(SaveProfile.find(stored(env), gone), nil)
		expect.equal(env.plots:getPlot("save:" .. gone), nil)
		expect.equal(env.plots:freeCount(), 2)
		expect.equal(env.service:activeCompanyId(USER), nil)
	end)

	t.test("teleports when no plot is free", function()
		local env = setup({ "Plot_01" })
		local saveId = starter(env)
		env.plots:claim("save:77_other")
		local loads = 0
		local originalLoad = env.persistence.load
		env.persistence.load = function(...)
			loads += 1
			return originalLoad(...)
		end
		local ok, reason = play(env, saveId)
		expect.falsy(ok)
		expect.equal(reason, "NoFreePlotTeleporting")
		expect.equal(#env.teleports, 1)
		expect.equal(env.teleports[1].userId, USER)
		expect.equal(env.teleports[1].data.saveId, saveId)
		expect.equal(env.teleports[1].data.attempt, 1)
		expect.equal(loads, 0)
		env.teleportResult = false
		local _, failedReason = play(env, saveId, { attempt = 1 })
		expect.equal(failedReason, "NoFreePlot")
		expect.equal(env.teleports[2].data.attempt, 2)
		expect.equal(loads, 0)
	end)

	t.test("stops teleporting after the attempt limit", function()
		local env = setup({ "Plot_01" })
		local saveId = starter(env)
		env.plots:claim("save:77_other")
		local ok, reason = play(env, saveId, { attempt = GameConfig.Saves.MaxPlotTeleports })
		expect.falsy(ok)
		expect.equal(reason, "NoFreePlot")
		expect.equal(#env.teleports, 0)
	end)

	t.test("rate-limits and serializes save actions", function()
		local env = setup()
		starter(env)
		local inner = nil
		env.filter = function(_, text)
			inner = env.service:handle(USER, request("Save.List"))
			return true, text
		end
		local first = env.service:handle(USER, request("Save.Create", { name = "Busy Lot" }))
		expect.truthy(first.ok)
		expect.equal(inner and inner.errorCode, "SaveActionBusy")
		for _ = 2, 5 do
			expect.truthy(env.service:handle(USER, request("Save.Create", {})).ok)
		end
		local sixth = env.service:handle(USER, request("Save.Create", {}))
		expect.equal(sixth.errorCode, "RateLimited")
		expect.equal(#stored(env).saves, 6)
		env.now += 61
		expect.truthy(env.service:handle(USER, request("Save.Create", {})).ok)
	end)

	t.test("leaving saves, releases the lock and frees the plot", function()
		local env = setup()
		local saveId = starter(env)
		expect.truthy(play(env, saveId))
		expect.equal(recordOf(env, saveId)._session.jobId, "job-a")
		local ok, reason = env.service:leave(USER, true)
		expect.truthy(ok)
		expect.equal(reason, nil)
		expect.equal(recordOf(env, saveId)._session, nil)
		expect.equal(env.plots:getPlot("save:" .. saveId), nil)
		expect.equal(env.plots:freeCount(), 2)
		expect.equal(env.service:activeCompanyId(USER), nil)
		expect.equal(#env.service:activeUserIds(), 0)
		expect.equal(#env.service:playersOn("save:" .. saveId), 0)
		expect.equal(#env.service:listFor(USER), 0)
		expect.equal(#env.deactivated, 1)
		local args = env.deactivated[1]
		expect.equal(args[1], USER)
		expect.equal(args[2], "save:" .. saveId)
		expect.equal(args[3], "Plot_01")
		expect.equal(args[4], true)
	end)

	t.test("plays a failed save again after the lock is back", function()
		local env = setup()
		local saveId = starter(env)
		local companyId = "save:" .. saveId
		expect.truthy(play(env, saveId))
		-- Another server steals the lock; the next flush loses it.
		recordOf(env, saveId)._session = { jobId = "thief", expiresAt = env.now + 300 }
		expect.falsy(env.companies:flushDirty(true))
		expect.falsy(env.companies:isAvailable(companyId))
		local blocked, blockedReason = play(env, saveId)
		expect.falsy(blocked)
		expect.equal(blockedReason, "SessionLocked")
		recordOf(env, saveId)._session = nil
		local ok, reason, data = play(env, saveId)
		expect.equal(reason, nil)
		expect.truthy(ok)
		expect.equal(data.plotId, "Plot_01")
		expect.truthy(env.companies:isAvailable(companyId))
		expect.equal(env.service:activeCompanyId(USER), companyId)
	end)

	t.test("reload leaves and loads the active save again", function()
		local env = setup()
		local saveId = starter(env)
		local _, _, first = play(env, saveId)
		local ok, reason, data = play(env, saveId, { reload = true })
		expect.equal(reason, nil)
		expect.truthy(ok)
		expect.equal(data.plotId, first.plotId)
		expect.equal(#env.deactivated, 1)
		expect.equal(#env.activated, 2)
		expect.equal(recordOf(env, saveId)._session.jobId, "job-a")
	end)

	t.test("counts a final leave until its save is written", function()
		local env = setup()
		local saveId = starter(env)
		expect.truthy(play(env, saveId))
		local saveKey = PersistenceService.keyFor("save:" .. saveId)
		local seen: any = nil
		env.companyStore.beforeUpdate = function(key: string)
			if key == saveKey and seen == nil then
				seen = {
					activeUserIds = env.service:activeUserIds(),
					pendingCount = env.service:pendingCount(),
				}
			end
		end
		expect.truthy(env.service:leave(USER, true))
		expect.truthy(seen)
		expect.equal(#seen.activeUserIds, 0)
		-- CM2-R5: the final leave plus its unloading session.
		expect.equal(seen.pendingCount, 2)
		expect.equal(env.service:pendingCount(), 0)
		expect.equal(recordOf(env, saveId)._session, nil)
	end)

	t.test("refuses new save work once shutdown begins", function()
		local env = setup()
		local saveId = starter(env)
		env.service:beginShutdown()
		expect.equal(env.service:handle(USER, request("Save.List")).errorCode, "ServerShuttingDown")
		local ok, reason = play(env, saveId)
		expect.falsy(ok)
		expect.equal(reason, "ServerShuttingDown")
		expect.equal(env.service:pendingCount(), 0)
	end)

	t.test("unloads a save whose load finishes during shutdown", function()
		local env = setup()
		local saveId = starter(env)
		local saveKey = PersistenceService.keyFor("save:" .. saveId)
		local pendingDuringLoad = nil
		env.companyStore.beforeUpdate = function(key: string)
			if key == saveKey and pendingDuringLoad == nil then
				env.service:beginShutdown()
				pendingDuringLoad = env.service:pendingCount()
			end
		end
		local ok, reason = play(env, saveId)
		expect.falsy(ok)
		expect.equal(reason, "ServerShuttingDown")
		expect.equal(pendingDuringLoad, 1)
		expect.equal(recordOf(env, saveId)._session, nil)
		expect.equal(env.plots:freeCount(), 2)
		expect.equal(#env.service:activeUserIds(), 0)
		expect.equal(env.service:pendingCount(), 0)
	end)

	-- CM2-S1 Fix round 2: the real store refuses keys over 50 chars (KeyNameLimit).
	t.test("keeps every key within 50 characters for a 19-digit user ID", function()
		local env = setup()
		local legacyKey = "company:personal:9223372036854774784"
		local legacy = BusinessState.new("personal:9223372036854774784", MAX_USER_ID)
		legacy.cash = 777
		env.companyStore.records[legacyKey] = legacy

		local profile, profileError = env.service:openProfile(MAX_USER_ID)
		expect.equal(profileError, nil)
		expect.truthy(profile)
		local migratedId = env.companyStore.records[legacyKey]._migratedTo
		expect.truthy(migratedId)
		expect.equal(profile.saves[1].saveId, migratedId)

		local created = env.service:handle(MAX_USER_ID, request("Save.Create", { name = "Long Id" }))
		expect.truthy(created.ok)
		local createdId = created.data.saveId
		expect.equal(string.sub(createdId, 1, #"9223372036854774784_"), "9223372036854774784_")

		local playedNew, newError = env.service:play(MAX_USER_ID, createdId)
		expect.equal(newError, nil)
		expect.truthy(playedNew)
		local playedMigrated, migratedError = env.service:play(MAX_USER_ID, migratedId)
		expect.equal(migratedError, nil)
		expect.truthy(playedMigrated)
		local left, leaveError = env.service:leave(MAX_USER_ID, true)
		expect.equal(leaveError, nil)
		expect.truthy(left)

		for _, store in { env.companyStore, env.profileStore } do
			for key in pairs(store.records) do
				expect.truthy(#key <= KEY_NAME_LIMIT)
			end
		end
		expect.equal(SaveSlotService.profileKey(MAX_USER_ID), "profile:9223372036854774784")
		-- CM2-46a: the purchase ledger key of the same user fits too.
		expect.truthy(#PurchaseLedgerService.keyFor(MAX_USER_ID) <= KEY_NAME_LIMIT)
		-- CM2-G12b: the leaderboard keys of the same user and save fit too.
		expect.truthy(#LeaderboardService.playerKey(MAX_USER_ID) <= KEY_NAME_LIMIT)
		expect.truthy(#LeaderboardService.saveKey(createdId) <= KEY_NAME_LIMIT)
		expect.truthy(env.profileStore.records["profile:9223372036854774784"])
		expect.equal(env.companyStore.records[PersistenceService.keyFor("save:" .. migratedId)].cash, 777)
	end)

	-- CM2-R5: a failed final save keeps the lock and is retried.
	local function order(env, saveId: string, requestId: string)
		local response = env.companies:handle("save:" .. saveId, USER, {
			version = 1,
			requestId = requestId,
			action = "Supplier.PlaceOrder",
			payload = { speciesId = "DouglasFir", sizeId = "Medium", quantity = 1 },
		})
		expect.truthy(response.ok)
		return response
	end

	local function liveCash(): number
		return GameConfig.StartingCash - (GameConfig.wholesaleFor("DouglasFir", "Medium") :: number)
	end

	t.test("a final leave whose save keeps failing keeps the lock", function()
		local env = setup()
		local saveId = starter(env)
		expect.truthy(play(env, saveId))
		order(env, saveId, "r5_leave_order_1")
		local expiresAt = recordOf(env, saveId)._session.expiresAt
		env.companyStore.failCount = 1000
		local ok, reason = env.service:leave(USER, true)
		expect.falsy(ok)
		expect.equal(reason, "SaveFailed")
		-- 8 attempts of 3 UpdateAsync calls each, and no release call.
		expect.equal(env.companyStore.failCount, 976)
		local record = recordOf(env, saveId)
		expect.equal(record._session.jobId, "job-a")
		expect.equal(record._session.expiresAt, expiresAt)
		expect.equal(record.cash, GameConfig.StartingCash)
		expect.equal(env.plots:freeCount(), 2)
		expect.equal(#env.deactivated, 1)
		expect.equal(env.deactivated[1][4], true)
	end)

	t.test("a switch whose final save fails keeps the player on the old save", function()
		local env = setup()
		local saveA = starter(env)
		expect.truthy(play(env, saveA))
		order(env, saveA, "r5_switch_order_1")
		local saveB = create(env, "Lot B")
		env.companyStore.failCount = 3
		local ok, reason = play(env, saveB)
		expect.falsy(ok)
		expect.equal(reason, "SwitchSaveFailed")
		expect.equal(env.service:activeCompanyId(USER), "save:" .. saveA)
		expect.truthy(env.companies:isAvailable("save:" .. saveA))
		expect.truthy(env.companies:isDirty("save:" .. saveA))
		expect.equal(recordOf(env, saveA).cash, GameConfig.StartingCash)
		expect.equal(recordOf(env, saveB), nil)
		expect.equal(#env.deactivated, 0)
		expect.equal(env.plots:getPlot("save:" .. saveA), "Plot_01")
		expect.truthy(env.companies:flushDirty())
		expect.equal(recordOf(env, saveA).cash, liveCash())
		local played, playError, data = play(env, saveB)
		expect.equal(playError, nil)
		expect.truthy(played)
		expect.equal(data.plotId, "Plot_01")
		expect.equal(recordOf(env, saveA)._session, nil)
	end)

	t.test("a switch away from a failed save waits for its final save", function()
		local env = setup()
		local saveA = starter(env)
		expect.truthy(play(env, saveA))
		order(env, saveA, "r5_failed_order_1")
		local saveB = create(env, "Lot B")
		env.companyStore.failCount = 1000
		env.now += GameConfig.SaveFailClosedSeconds
		expect.falsy(env.companies:flushDirty(true))
		expect.truthy(env.companies:isFailed("save:" .. saveA))
		env.companyStore.failCount = 3
		local played, playError = play(env, saveB)
		expect.equal(playError, nil)
		expect.truthy(played)
		expect.equal(recordOf(env, saveA).cash, liveCash())
		expect.equal(recordOf(env, saveA)._session, nil)
	end)

	t.test("pendingCount counts a retrying unload", function()
		local env = setup()
		local saveA = starter(env)
		expect.truthy(play(env, saveA))
		env.companyWait = coroutine.yield
		env.companyStore.failCount = 3
		local unload = coroutine.create(function()
			return env.companies:unloadCompany("save:" .. saveA)
		end)
		expect.truthy(coroutine.resume(unload))
		expect.equal(coroutine.status(unload), "suspended")
		expect.equal(env.service:pendingCount(), 1)
		expect.equal(env.companies:unloadingCount(), 1)
		local result = nil
		while coroutine.status(unload) ~= "dead" do
			result = table.pack(coroutine.resume(unload))
		end
		expect.truthy(result)
		expect.truthy(result[1])
		expect.equal(result[2], true)
		expect.equal(env.service:pendingCount(), 0)
	end)

	-- CM2-49: only the first save a player ever plays starts the guided tutorial.
	t.test("offers the tutorial on the first played save only", function()
		local env = setup()
		local first = starter(env)
		local ok, reason = play(env, first)
		expect.equal(reason, nil)
		expect.truthy(ok)
		expect.equal(env.companies:snapshotForTest("save:" .. first).tutorial.step, "Order")
		expect.equal(recordOf(env, first).tutorial.step, "Order")
		expect.equal(stored(env).tutorialOffered, true)
		local second = create(env, "Second Lot")
		local played, playError = play(env, second)
		expect.equal(playError, nil)
		expect.truthy(played)
		expect.equal(env.companies:snapshotForTest("save:" .. second).tutorial.step, "Done")
		expect.equal(env.companies:snapshotForTest("save:" .. second).tutorial.skipped, false)
	end)

	t.test("an existing record keeps its tutorial when first played", function()
		local env = setup()
		local saveId = starter(env)
		env.service:closeProfile(USER)
		stored(env).tutorialOffered = nil
		local companyId = "save:" .. saveId
		env.companyStore.records[PersistenceService.keyFor(companyId)] =
			BusinessState.new(companyId, USER, "Tree Lot 1")
		local ok, reason = play(env, saveId)
		expect.equal(reason, nil)
		expect.truthy(ok)
		expect.equal(env.companies:snapshotForTest(companyId).tutorial.step, "Done")
		expect.equal(stored(env).tutorialOffered, true)
	end)

	-- CM2-PP: the plot picker at session start (Save.Plots, Save.Play with a chosen plot).
	local function plotChoices(env, saveId: string, userId: number?)
		return env.service:handle(userId or USER, request("Save.Plots", { saveId = saveId }))
	end

	local function playChosen(env, saveId: string, plotId: string?, userId: number?)
		return env.service:handle(userId or USER, request("Save.Play", { saveId = saveId, plotId = plotId }))
	end

	-- Counts persistence loads of one company (all companies when companyId is nil).
	local function countLoads(env, companyId: string?)
		local counter = { loads = 0 }
		local originalLoad = env.persistence.load
		env.persistence.load = function(persistence, loadedId: string, ...)
			if companyId == nil or loadedId == companyId then
				counter.loads += 1
			end
			return originalLoad(persistence, loadedId, ...)
		end
		return counter
	end

	t.test("lists every plot with number, side and status", function()
		local env = setup({ "Plot_01", "Plot_02", "Plot_03" })
		local saveId = starter(env)
		expect.equal(env.plots:claim("save:77_other"), "Plot_01")
		env.labels.Plot_01 = "Other Lot"
		local response = plotChoices(env, saveId)
		expect.truthy(response.ok)
		local data = response.data
		expect.equal(data.saveId, saveId)
		expect.equal(data.pick, true)
		expect.equal(data.total, 3)
		expect.equal(#data.plots, 3)
		for index, row in ipairs(data.plots) do
			expect.equal(row.plotId, string.format("Plot_%02d", index))
			expect.equal(row.number, index)
			expect.equal(row.side, "South")
		end
		expect.equal(data.plots[1].free, false)
		expect.equal(data.plots[1].name, "Other Lot")
		for index = 2, 3 do
			expect.equal(data.plots[index].free, true)
			expect.equal(data.plots[index].name, nil)
		end
		expect.equal(data.preselectId, "Plot_02")
		expect.equal(env.plots:getPlot("save:" .. saveId), nil)
		expect.equal(env.plots:freeCount(), 2)
	end)

	t.test("plays a chosen free plot and remembers it", function()
		local env = setup({ "Plot_01", "Plot_02", "Plot_03" })
		local saveId = starter(env)
		local response = playChosen(env, saveId, "Plot_03")
		expect.truthy(response.ok)
		expect.equal(response.data.plotId, "Plot_03")
		expect.equal(env.plots:getPlot("save:" .. saveId), "Plot_03")
		expect.equal(stored(env).saves[1].lastPlotId, "Plot_03")
	end)

	t.test("refuses a taken plot with PlotTaken and changes nothing", function()
		local env = setup()
		local saveId = starter(env)
		expect.equal(env.plots:claim("save:77_other"), "Plot_01")
		local counter = countLoads(env, nil)
		local response = playChosen(env, saveId, "Plot_01")
		expect.falsy(response.ok)
		expect.equal(response.errorCode, "PlotTaken")
		expect.equal(counter.loads, 0)
		expect.equal(env.plots:getPlot("save:" .. saveId), nil)
		expect.equal(env.plots:freeCount(), 1)
		expect.equal(env.service:activeCompanyId(USER), nil)
		expect.equal(#env.teleports, 0)
	end)

	t.test("refuses a plot id this server does not hold", function()
		local env = setup()
		local saveId = starter(env)
		expect.equal(playChosen(env, saveId, "Plot_05").errorCode, "InvalidPlotId")
		expect.equal(playChosen(env, saveId, "Plot_9").errorCode, "InvalidPlotId")
		expect.equal(env.plots:freeCount(), 2)
		expect.equal(env.service:activeCompanyId(USER), nil)
	end)

	t.test("plays the automatic plot without a plot id", function()
		local env = setup()
		local saveId = starter(env)
		expect.equal(env.plots:claim("save:77_other"), "Plot_01")
		local response = playChosen(env, saveId, nil)
		expect.truthy(response.ok)
		expect.equal(response.data.plotId, "Plot_02")
	end)

	t.test("the second of two companies choosing one plot gets PlotTaken", function()
		local env = setup()
		local saveA = starter(env)
		expect.truthy(playChosen(env, saveA, "Plot_02").ok)
		local other = env.service:openProfile(43)
		expect.truthy(other)
		local saveB = other.saves[1].saveId
		local choices = plotChoices(env, saveB, 43)
		expect.truthy(choices.ok)
		expect.equal(choices.data.pick, true)
		expect.equal(choices.data.plots[2].free, false)
		expect.equal(choices.data.plots[1].free, true)
		expect.equal(playChosen(env, saveB, "Plot_02", 43).errorCode, "PlotTaken")
		local played = playChosen(env, saveB, "Plot_01", 43)
		expect.truthy(played.ok)
		expect.equal(played.data.plotId, "Plot_01")
		expect.equal(env.plots:getPlot("save:" .. saveA), "Plot_02")
	end)

	t.test("preselects the last plot when free, else the first free one", function()
		local env = setup({ "Plot_01", "Plot_02", "Plot_03" })
		local saveId = starter(env)
		expect.truthy(playChosen(env, saveId, "Plot_03").ok)
		expect.truthy(env.service:leave(USER))
		expect.equal(env.plots:freeCount(), 3)
		expect.equal(plotChoices(env, saveId).data.preselectId, "Plot_03")
		expect.equal(env.plots:claim("save:77_other", "Plot_03"), "Plot_03")
		local choices = plotChoices(env, saveId)
		expect.equal(choices.data.pick, true)
		expect.equal(choices.data.preselectId, "Plot_01")
	end)

	t.test("offers no pick for the active save and frees its plot for a switch", function()
		local env = setup()
		local saveA = starter(env)
		local saveB = create(env, "Lot B")
		local _, _, playedA = play(env, saveA)
		expect.equal(playedA.plotId, "Plot_01")
		local own = plotChoices(env, saveA)
		expect.truthy(own.ok)
		expect.equal(own.data.pick, false)
		expect.equal(#own.data.plots, 0)
		expect.equal(own.data.preselectId, nil)
		local choices = plotChoices(env, saveB)
		expect.equal(choices.data.pick, true)
		expect.equal(choices.data.plots[1].free, true)
		local played = playChosen(env, saveB, "Plot_01")
		expect.truthy(played.ok)
		expect.equal(played.data.plotId, "Plot_01")
		expect.equal(env.service:activeCompanyId(USER), "save:" .. saveB)
	end)

	t.test("a taken plot with none free takes the teleport path", function()
		local env = setup({ "Plot_01" })
		local saveId = starter(env)
		env.plots:claim("save:77_other")
		local choices = plotChoices(env, saveId)
		expect.truthy(choices.ok)
		expect.equal(choices.data.pick, false)
		expect.equal(choices.data.total, 1)
		local response = playChosen(env, saveId, "Plot_01")
		expect.equal(response.errorCode, "NoFreePlotTeleporting")
		expect.equal(#env.teleports, 1)
		expect.equal(env.teleports[1].data.saveId, saveId)
		expect.equal(env.teleports[1].data.attempt, 1)
	end)

	t.test("a teleport arrival carries its attempt into the chosen play", function()
		local env = setup()
		local saveId = starter(env)
		env.plots:claim("save:77_other")
		env.plots:claim("save:78_other")
		env.service:noteArrival(USER, saveId, 2)
		expect.equal(playChosen(env, saveId, "Plot_01").errorCode, "NoFreePlotTeleporting")
		expect.equal(#env.teleports, 1)
		expect.equal(env.teleports[1].data.attempt, 3)
		env.service:noteArrival(USER, saveId, 3)
		expect.equal(playChosen(env, saveId, "Plot_01").errorCode, "NoFreePlot")
		expect.equal(#env.teleports, 1)
	end)

	t.test("rate-limits Save.Plots like the other save actions", function()
		local env = setup()
		local saveId = starter(env)
		local limit = GameConfig.Saves.RateLimits["Save.Plots"].limit
		for _ = 1, limit do
			expect.truthy(plotChoices(env, saveId).ok)
		end
		expect.equal(plotChoices(env, saveId).errorCode, "RateLimited")
	end)

	t.test("a plot taken during the switch gives PlotTaken and loads nothing", function()
		local env = setup()
		local saveA = starter(env)
		local saveB = create(env, "Lot B")
		local _, _, playedA = play(env, saveA)
		expect.equal(playedA.plotId, "Plot_01")
		env.service:setActivationHandlers(function(...)
			table.insert(env.activated, table.pack(...))
		end, function(...)
			table.insert(env.deactivated, table.pack(...))
			env.plots:claim("save:77_other", "Plot_01")
		end)
		local counter = countLoads(env, "save:" .. saveB)
		local response = playChosen(env, saveB, "Plot_01")
		expect.equal(response.errorCode, "PlotTaken")
		expect.equal(env.service:activeCompanyId(USER), nil)
		expect.equal(env.plots:getPlot("save:" .. saveB), nil)
		expect.equal(env.plots:holderOf("Plot_01"), "save:77_other")
		expect.equal(counter.loads, 0)
	end)
end

--!strict
-- CM2-S1: moving the legacy personal record into the first save (PersistenceService.migrateLegacy).
return function(t)
	local BusinessState =
		require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BusinessState"))
	local PersistenceService = require(
		game:GetService("ServerScriptService")
			:WaitForChild("Server")
			:WaitForChild("Services")
			:WaitForChild("PersistenceService")
	)
	local SaveProfile = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SaveProfile"))
	local expect = t.expect

	local KEY_NAME_LIMIT = 50 -- real DataStore rule (KeyNameLimit)
	local MAX_USER_ID = 9223372036854774784 -- 2^63 - 1024, the largest Luau number below int64 max
	local SAVE_ID = "42_" .. string.rep("0a", 8)
	local OTHER_ID = "42_" .. string.rep("0b", 8)
	local LEGACY_KEY = "company:personal:42"
	local TARGET_KEY = "company:save:" .. SAVE_ID

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

	local function persistence(store, jobId: string, now: number)
		return PersistenceService.new(store, jobId, function()
			return now
		end, noWait)
	end

	-- A schema 10 personal record with balances, stock, displayed trees, an open order and sales.
	local function legacyRecord(userId: number?)
		local owner = userId or 42
		local record = BusinessState.new("personal:" .. SaveProfile.userIdText(owner), owner)
		record.schemaVersion = 10
		record.saveName = nil
		record.saveSize = nil
		record.cash = 1234
		record.sales = 5
		record.customerVisits = 5
		record.revenue = 400
		record.bays = nil
		record.stock = { ["DouglasFir:Medium"] = 3 }
		record.layout.placements["placement:p1"] = { speciesId = "DouglasFir", sizeId = "Medium", x = 14, z = -3 }
		record.pendingOrders["order:abc12345"] = {
			orderId = "order:abc12345",
			requestId = "abc12345",
			speciesId = "NobleFir",
			sizeId = "Small",
			quantity = 2,
			createdAt = 50,
			dueAt = 110,
			status = "Pending",
		}
		return record
	end

	t.test("moves a personal record into the first save without losing data", function()
		local store = fakeStore()
		store.records[LEGACY_KEY] = legacyRecord()
		local outcome, migratedId = persistence(store, "job-a", 100):migrateLegacy(42, SAVE_ID, "Tree Lot 1")
		expect.equal(outcome, "Migrated")
		expect.equal(migratedId, SAVE_ID)
		local target = store.records[TARGET_KEY]
		expect.truthy(target)
		expect.equal(target.companyId, "save:" .. SAVE_ID)
		expect.equal(target.saveName, "Tree Lot 1")
		expect.equal(target.saveSize, "Solo")
		expect.equal(target._migratedFrom, LEGACY_KEY)
		expect.equal(target._session, nil)
		expect.equal(target.schemaVersion, BusinessState.SCHEMA_VERSION)
		expect.equal(target.cash, 1234)
		expect.equal(target.bays[1].speciesId, "DouglasFir")
		expect.equal(target.bays[1].counts.Medium, 3)
		expect.equal(target.stock, nil)
		expect.truthy(target.layout.placements["placement:p1"])
		expect.equal(target.pendingOrders["order:abc12345"].quantity, 2)
		expect.equal(target.pendingOrders["order:abc12345"].bay, 2)
		expect.equal(target.sales, 5)
		expect.equal(target.revenue, 400)
		local legacy = store.records[LEGACY_KEY]
		expect.equal(legacy._migratedTo, SAVE_ID)
		expect.equal(legacy._migratedAt, 100)
		expect.equal(legacy._session, nil)
		expect.equal(legacy.schemaVersion, 10)
		expect.equal(legacy.cash, 1234)
		expect.equal(legacy.companyId, "personal:42")
	end)

	t.test("is idempotent when run again", function()
		local store = fakeStore()
		store.records[LEGACY_KEY] = legacyRecord()
		local service = persistence(store, "job-a", 100)
		expect.equal(service:migrateLegacy(42, SAVE_ID, "Tree Lot 1"), "Migrated")
		local again, againId = service:migrateLegacy(42, OTHER_ID, "Tree Lot 1")
		expect.equal(again, "Migrated")
		expect.equal(againId, SAVE_ID)
		store.records[TARGET_KEY].cash = 1
		local third, thirdId = persistence(store, "job-b", 200):migrateLegacy(42, OTHER_ID, "Tree Lot 1")
		expect.equal(third, "Migrated")
		expect.equal(thirdId, SAVE_ID)
		expect.equal(store.records[TARGET_KEY].cash, 1)
		expect.equal(store.records["company:save:" .. OTHER_ID], nil)
	end)

	t.test("resumes after a crash between copy and marking", function()
		local store = fakeStore()
		store.records[LEGACY_KEY] = legacyRecord()
		expect.equal(persistence(store, "job-a", 100):migrateLegacy(42, SAVE_ID, "Tree Lot 1"), "Migrated")
		-- Undo step d: the crashed server wrote the save but never marked the legacy record.
		local legacy = store.records[LEGACY_KEY]
		legacy._migratedTo = nil
		legacy._migratedAt = nil
		legacy._session = { jobId = "job-a", expiresAt = 220 }
		store.records[TARGET_KEY].cash = 999
		local outcome, migratedId, errorCode = persistence(store, "job-b", 400):migrateLegacy(42, SAVE_ID, "Tree Lot 1")
		expect.equal(errorCode, nil)
		expect.equal(outcome, "Migrated")
		expect.equal(migratedId, SAVE_ID)
		expect.equal(store.records[TARGET_KEY].cash, 999)
		expect.equal(store.records[LEGACY_KEY]._migratedTo, SAVE_ID)
		expect.equal(store.records[LEGACY_KEY]._session, nil)
	end)

	t.test("fails closed while another server holds the personal record", function()
		local store = fakeStore()
		local record = legacyRecord()
		record._session = { jobId = "job-x", expiresAt = 1000 }
		store.records[LEGACY_KEY] = record
		local outcome, migratedId, errorCode = persistence(store, "job-a", 100):migrateLegacy(42, SAVE_ID, "Tree Lot 1")
		expect.equal(outcome, nil)
		expect.equal(migratedId, nil)
		expect.equal(errorCode, "SessionLocked")
		expect.equal(store.records[TARGET_KEY], nil)
		local legacy = store.records[LEGACY_KEY]
		expect.equal(legacy._session.jobId, "job-x")
		expect.equal(legacy._migratedTo, nil)
		expect.equal(legacy.cash, 1234)
		expect.equal(store.writes, 0)
	end)

	t.test("fails closed on an unmigratable record and leaves it untouched", function()
		local store = fakeStore()
		local record = legacyRecord()
		record.schemaVersion = 99
		store.records[LEGACY_KEY] = record
		local outcome, _, errorCode = persistence(store, "job-a", 100):migrateLegacy(42, SAVE_ID, "Tree Lot 1")
		expect.equal(outcome, nil)
		expect.equal(errorCode, "MigrationFailed")
		expect.equal(store.records[TARGET_KEY], nil)
		local legacy = store.records[LEGACY_KEY]
		expect.equal(legacy._session, nil)
		expect.equal(legacy._migratedTo, nil)
		expect.equal(legacy.schemaVersion, 99)
		expect.equal(legacy.cash, 1234)
	end)

	t.test("reports no legacy record", function()
		local store = fakeStore()
		local outcome, migratedId, errorCode = persistence(store, "job-a", 100):migrateLegacy(42, SAVE_ID, "Tree Lot 1")
		expect.equal(outcome, "NoLegacy")
		expect.equal(migratedId, nil)
		expect.equal(errorCode, nil)
		expect.equal(store.writes, 0)
		expect.equal(next(store.records), nil)
	end)

	t.test("refuses to overwrite an unrelated record at the save key", function()
		local store = fakeStore()
		store.records[LEGACY_KEY] = legacyRecord()
		local unrelated = BusinessState.new("save:" .. SAVE_ID, 42)
		unrelated.cash = 5
		store.records[TARGET_KEY] = unrelated
		local outcome, _, errorCode = persistence(store, "job-a", 100):migrateLegacy(42, SAVE_ID, "Tree Lot 1")
		expect.equal(outcome, nil)
		expect.equal(errorCode, "MigrationConflict")
		local target = store.records[TARGET_KEY]
		expect.equal(target.cash, 5)
		expect.equal(target._migratedFrom, nil)
		local legacy = store.records[LEGACY_KEY]
		expect.equal(legacy._migratedTo, nil)
		expect.equal(legacy._session, nil)
	end)

	t.test("stops before marking when another server took the personal record", function()
		local store = fakeStore()
		store.records[LEGACY_KEY] = legacyRecord()
		local legacyUpdates = 0
		store.beforeUpdate = function(key: string)
			if key ~= LEGACY_KEY then
				return
			end
			legacyUpdates += 1
			if legacyUpdates == 2 then
				-- Another server takes the personal record between copy (a) and marking (d).
				store.records[LEGACY_KEY]._session = { jobId = "job-b", expiresAt = 100 + 300 }
			end
		end
		local outcome, migratedId, errorCode = persistence(store, "job-a", 100):migrateLegacy(42, SAVE_ID, "Tree Lot 1")
		expect.equal(outcome, nil)
		expect.equal(migratedId, nil)
		expect.equal(errorCode, "SessionLocked")
		expect.equal(store.records[TARGET_KEY]._migratedFrom, LEGACY_KEY)
		local legacy = store.records[LEGACY_KEY]
		expect.equal(legacy._migratedTo, nil)
		expect.equal(legacy._session.jobId, "job-b")
		expect.equal(legacy._session.expiresAt, 400)

		store.beforeUpdate = nil
		store.records[LEGACY_KEY]._session = nil
		local again, againId, againError = persistence(store, "job-a", 100):migrateLegacy(42, SAVE_ID, "Tree Lot 1")
		expect.equal(againError, nil)
		expect.equal(again, "Migrated")
		expect.equal(againId, SAVE_ID)
		expect.equal(store.records[LEGACY_KEY]._migratedTo, SAVE_ID)
		expect.equal(store.records[LEGACY_KEY]._session, nil)
	end)

	t.test("refuses to mark a personal record that is no longer a table", function()
		local store = fakeStore()
		store.records[LEGACY_KEY] = legacyRecord()
		local legacyUpdates = 0
		store.beforeUpdate = function(key: string)
			if key ~= LEGACY_KEY then
				return
			end
			legacyUpdates += 1
			if legacyUpdates == 2 then
				store.records[LEGACY_KEY] = "garbage"
			end
		end
		local outcome, migratedId, errorCode = persistence(store, "job-a", 100):migrateLegacy(42, SAVE_ID, "Tree Lot 1")
		expect.equal(outcome, nil)
		expect.equal(migratedId, nil)
		expect.equal(errorCode, "MigrationFailed")
		expect.equal(store.records[LEGACY_KEY], "garbage")
	end)

	-- CM2-S1 Fix round 2 (R3): the failed Studio playtest left this lock behind.
	t.test("clears its lock when the save key is rejected", function()
		local store = fakeStore()
		local legacyKey = "company:personal:4584569287"
		store.records[legacyKey] = legacyRecord(4584569287)
		local longId = "4584569287_" .. string.rep("ab", 16)
		local outcome, migratedId, errorCode =
			persistence(store, "", 100):migrateLegacy(4584569287, longId, "Tree Lot 1")
		expect.equal(outcome, nil)
		expect.equal(migratedId, nil)
		expect.equal(errorCode, "LoadFailed")
		local legacy = store.records[legacyKey]
		expect.equal(legacy._session, nil)
		expect.equal(legacy._migratedTo, nil)
		expect.equal(legacy.cash, 1234)
		expect.equal(store.records["company:save:" .. longId], nil)
	end)

	t.test("clears its lock when marking the personal record fails", function()
		local store = fakeStore()
		store.records[LEGACY_KEY] = legacyRecord()
		local legacyUpdates = 0
		store.beforeUpdate = function(key: string)
			if key ~= LEGACY_KEY then
				return
			end
			legacyUpdates += 1
			if legacyUpdates >= 2 and legacyUpdates <= 4 then
				error("Throttled") -- every retry of step d
			end
		end
		local outcome, migratedId, errorCode = persistence(store, "job-a", 100):migrateLegacy(42, SAVE_ID, "Tree Lot 1")
		expect.equal(outcome, nil)
		expect.equal(migratedId, nil)
		expect.equal(errorCode, "LoadFailed")
		local legacy = store.records[LEGACY_KEY]
		expect.equal(legacy._session, nil)
		expect.equal(legacy._migratedTo, nil)
		expect.equal(store.records[TARGET_KEY]._migratedFrom, LEGACY_KEY)

		store.beforeUpdate = nil
		local again, againId, againError = persistence(store, "job-a", 100):migrateLegacy(42, SAVE_ID, "Tree Lot 1")
		expect.equal(againError, nil)
		expect.equal(again, "Migrated")
		expect.equal(againId, SAVE_ID)
		expect.equal(store.records[LEGACY_KEY]._migratedTo, SAVE_ID)
		expect.equal(store.records[LEGACY_KEY]._session, nil)
	end)

	-- R4: Studio servers all have JobId "", and an expired lock of another job is free.
	t.test("takes over its own leftover lock", function()
		local studio = fakeStore()
		local studioRecord = legacyRecord()
		studioRecord._session = { jobId = "", expiresAt = 100 + 300 }
		studio.records[LEGACY_KEY] = studioRecord
		local outcome, migratedId, errorCode = persistence(studio, "", 100):migrateLegacy(42, SAVE_ID, "Tree Lot 1")
		expect.equal(errorCode, nil)
		expect.equal(outcome, "Migrated")
		expect.equal(migratedId, SAVE_ID)
		expect.equal(studio.records[LEGACY_KEY]._session, nil)

		local expired = fakeStore()
		local expiredRecord = legacyRecord()
		expiredRecord._session = { jobId = "job-z", expiresAt = 100 - 1 }
		expired.records[LEGACY_KEY] = expiredRecord
		local expiredOutcome, expiredId, expiredError =
			persistence(expired, "job-a", 100):migrateLegacy(42, SAVE_ID, "Tree Lot 1")
		expect.equal(expiredError, nil)
		expect.equal(expiredOutcome, "Migrated")
		expect.equal(expiredId, SAVE_ID)
		expect.equal(expired.records[LEGACY_KEY]._session, nil)
	end)

	t.test("migrates the record of a 19-digit user ID", function()
		local store = fakeStore()
		local legacyKey = "company:personal:9223372036854774784"
		store.records[legacyKey] = legacyRecord(MAX_USER_ID)
		local saveId = SaveProfile.newSaveId(MAX_USER_ID, "0F8FAD5B-D9CB-469F-A165-70867728950E")
		local outcome, migratedId, errorCode =
			persistence(store, "job-a", 100):migrateLegacy(MAX_USER_ID, saveId, "Tree Lot 1")
		expect.equal(errorCode, nil)
		expect.equal(outcome, "Migrated")
		expect.equal(migratedId, saveId)
		local targetKey = "company:save:" .. saveId
		expect.truthy(#targetKey <= KEY_NAME_LIMIT)
		expect.truthy(store.records[targetKey])
		expect.equal(store.records[legacyKey]._migratedTo, saveId)
	end)

	-- CM2-46a: schema 17 adds the purchases record (receipts, owned counts, boost time).
	t.test("migrates schema 16 to 17 with empty purchases", function()
		local record = BusinessState.new("save:" .. SAVE_ID, 42)
		record.schemaVersion = 16
		record.purchases = nil
		record.cash = 777
		local migrated, reason = BusinessState.migrate(record, "save:" .. SAVE_ID, 42)
		expect.equal(reason, nil)
		expect.truthy(migrated)
		expect.equal(migrated.schemaVersion, 24)
		expect.equal(migrated.cash, 777)
		expect.equal(#migrated.purchases.receipts, 0)
		expect.equal(next(migrated.purchases.owned), nil)
		expect.equal(migrated.purchases.boosts.CashX2, 0)
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
		local fromV1 = BusinessState.migrate(v1, "personal:42", 42)
		expect.truthy(fromV1)
		expect.equal(fromV1.schemaVersion, 24)
		expect.equal(fromV1.purchases.boosts.CashX2, 0)
		expect.truthy(BusinessState.validate(fromV1))
		local broken = BusinessState.new("save:" .. SAVE_ID, 42)
		broken.purchases = { receipts = {}, owned = {}, boosts = { CashX2 = -1 } }
		expect.falsy(BusinessState.validate(broken))
		broken.purchases = "none"
		expect.falsy(BusinessState.validate(broken))
	end)
end

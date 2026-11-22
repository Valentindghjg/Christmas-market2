--!strict
return function(t)
	local BusinessState =
		require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BusinessState"))
	local PersistenceService = require(
		game:GetService("ServerScriptService")
			:WaitForChild("Server")
			:WaitForChild("Services")
			:WaitForChild("PersistenceService")
	)
	local expect = t.expect
	local KEY_NAME_LIMIT = 50 -- real DataStore rule (KeyNameLimit)

	local function fakeStore()
		local records = {}
		return {
			UpdateAsync = function(_, key, transform)
				if #key > KEY_NAME_LIMIT then
					error("KeyNameLimit: Key name exceeds the 50 character limit.")
				end
				local nextValue = transform(records[key])
				if nextValue ~= nil then
					records[key] = nextValue
				end
				return records[key]
			end,
		}
	end

	-- A company can have one writable session until its holder releases the lock.
	t.test("prevents simultaneous writers", function()
		local store = fakeStore()
		local first = PersistenceService.new(store, "job-a", function()
			return 100
		end)
		local second = PersistenceService.new(store, "job-b", function()
			return 100
		end)
		local state = first:load("personal:42", 42)
		expect.truthy(state)
		local blocked, reason = second:load("personal:42", 42)
		expect.equal(blocked, nil)
		expect.equal(reason, "SessionLocked")
		expect.truthy(first:release("personal:42"))
		expect.truthy(second:load("personal:42", 42))
	end)

	-- A stale writer cannot overwrite a session it no longer owns.
	t.test("fails closed after lock loss", function()
		local store = fakeStore()
		local first = PersistenceService.new(store, "job-a", function()
			return 100
		end)
		local state = first:load("personal:77", 77)
		expect.truthy(state)
		first._sessions["personal:77"] = true
		local replacement = PersistenceService.new(store, "job-b", function()
			return 300
		end)
		expect.truthy(replacement:load("personal:77", 77))
		local saved, reason = first:save("personal:77", state)
		expect.falsy(saved)
		expect.equal(reason, "SessionLocked")
	end)

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

	-- CM2-S1 fake: deep-copies on read and write; throws while failCount > 0.
	local function copyingStore()
		local store = { records = {}, failCount = 0, writes = 0 }
		function store.UpdateAsync(_, key: string, transform)
			if #key > KEY_NAME_LIMIT then
				error("KeyNameLimit: Key name exceeds the 50 character limit.")
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
	local SAVE_A = "save:42_" .. string.rep("0a", 8)
	local SAVE_B = "save:42_" .. string.rep("0b", 8)

	local function service(store, jobId: string)
		return PersistenceService.new(store, jobId, function()
			return 100
		end, noWait)
	end

	t.test("locks each save separately", function()
		local store = copyingStore()
		local jobA, jobB = service(store, "job-a"), service(store, "job-b")
		expect.truthy(jobA:load(SAVE_A, 42, "Lot A"))
		expect.truthy(jobB:load(SAVE_B, 42, "Lot B"))
		local blocked, reason = jobB:load(SAVE_A, 42, "Lot A")
		expect.equal(blocked, nil)
		expect.equal(reason, "SessionLocked")
		expect.equal(store.records[PersistenceService.keyFor(SAVE_A)]._session.jobId, "job-a")
		expect.equal(store.records[PersistenceService.keyFor(SAVE_B)]._session.jobId, "job-b")
		expect.equal(store.records[PersistenceService.keyFor(SAVE_B)].saveName, "Lot B")
	end)

	t.test("refuses to load a deleted save", function()
		local store = copyingStore()
		local record = BusinessState.new(SAVE_A, 42)
		record._deletedAt = 50
		store.records[PersistenceService.keyFor(SAVE_A)] = record
		local state, reason = service(store, "job-a"):load(SAVE_A, 42, "Lot A")
		expect.equal(state, nil)
		expect.equal(reason, "SaveDeleted")
		expect.equal(store.writes, 0)
		expect.equal(store.records[PersistenceService.keyFor(SAVE_A)]._session, nil)
	end)

	t.test("deletes only unlocked saves", function()
		local store = copyingStore()
		local key = PersistenceService.keyFor(SAVE_A)
		local record = BusinessState.new(SAVE_A, 42)
		record.cash = 321
		record._session = { jobId = "job-x", expiresAt = 1000 }
		store.records[key] = record
		local own = service(store, "job-a")
		local inUse, inUseReason = own:markDeleted(SAVE_A)
		expect.falsy(inUse)
		expect.equal(inUseReason, "SaveInUse")
		store.records[key]._session = { jobId = "job-a", expiresAt = 1000 }
		local active, activeReason = own:markDeleted(SAVE_A)
		expect.falsy(active)
		expect.equal(activeReason, "SaveActive")
		expect.equal(store.records[key]._deletedAt, nil)
		store.records[key]._session = nil
		expect.truthy(own:markDeleted(SAVE_A))
		expect.equal(store.records[key]._deletedAt, 100)
		expect.equal(store.records[key].cash, 321)
		local writes = store.writes
		expect.truthy(own:markDeleted(SAVE_B))
		expect.equal(store.writes, writes)
		expect.equal(store.records[PersistenceService.keyFor(SAVE_B)], nil)
	end)

	-- CM2-S2: co-op saves.
	t.test("loads a member's save only when it exists", function()
		local store = copyingStore()
		local job = service(store, "job-a")
		local missing, missingReason = job:load(SAVE_A, 42, nil, { requireExisting = true })
		expect.equal(missing, nil)
		expect.equal(missingReason, "SaveNotFound")
		expect.equal(store.writes, 0)
		expect.equal(job._sessions[SAVE_A], nil)

		local record = BusinessState.new(SAVE_A, 42, "Owner Lot")
		store.records[PersistenceService.keyFor(SAVE_A)] = record
		local loaded = job:load(SAVE_A, 42, nil, { requireExisting = true, saveSize = "Quad" })
		expect.truthy(loaded)
		expect.equal(loaded.saveName, "Owner Lot")
		expect.equal(loaded.saveSize, "Solo")
		expect.equal(store.records[PersistenceService.keyFor(SAVE_A)].saveName, "Owner Lot")

		local fresh = job:load(SAVE_B, 42, "Team Lot", { saveSize = "Trio" })
		expect.truthy(fresh)
		expect.equal(fresh.saveSize, "Trio")
		expect.equal(store.records[PersistenceService.keyFor(SAVE_B)].saveSize, "Trio")
		expect.equal(store.records[PersistenceService.keyFor(SAVE_B)].saveName, "Team Lot")
	end)

	t.test("changes an unlocked record without taking its lock", function()
		local store = copyingStore()
		local key = PersistenceService.keyFor(SAVE_A)
		local record = BusinessState.new(SAVE_A, 42, "Team Lot")
		record.saveSize = "Duo"
		record.inviteCode = "12345"
		store.records[key] = record
		local job = service(store, "job-a")
		local function addFriend(state)
			return BusinessState.addMember(state, 43, "12345")
		end

		local ok, reason, result = job:updateUnlocked(SAVE_A, 42, addFriend)
		expect.truthy(ok)
		expect.equal(reason, nil)
		expect.equal(result.outcome, "Joined")
		expect.equal(store.records[key].members["43"], "Member")
		expect.equal(store.records[key]._session, nil)
		expect.equal(store.records[key].updatedAt, 100)
		expect.equal(job._sessions[SAVE_A], nil)

		-- An expired foreign lock is removed by the write.
		store.records[key]._session = { jobId = "job-x", expiresAt = 50 }
		expect.truthy(job:updateUnlocked(SAVE_A, 42, function(state)
			return BusinessState.removeMember(state, 43)
		end))
		expect.equal(store.records[key]._session, nil)
		expect.equal(store.records[key].members["43"], nil)

		for _, jobId in { "job-x", "job-a" } do
			store.records[key]._session = { jobId = jobId, expiresAt = 1000 }
			local writes = store.writes
			local inUse, inUseReason = job:updateUnlocked(SAVE_A, 42, addFriend)
			expect.falsy(inUse)
			expect.equal(inUseReason, "SaveInUse")
			expect.equal(store.writes, writes)
			expect.equal(store.records[key].members["43"], nil)
		end
		store.records[key]._session = nil

		local writes = store.writes
		local refused, refusedReason = job:updateUnlocked(SAVE_A, 42, function(state)
			return BusinessState.addMember(state, 43, "54321")
		end)
		expect.falsy(refused)
		expect.equal(refusedReason, "InviteCodeInvalid")
		expect.equal(store.writes, writes)

		store.records[key]._deletedAt = 90
		local deleted, deletedReason = job:updateUnlocked(SAVE_A, 42, addFriend)
		expect.falsy(deleted)
		expect.equal(deletedReason, "SaveDeleted")
		local missing, missingReason = job:updateUnlocked(SAVE_B, 42, addFriend)
		expect.falsy(missing)
		expect.equal(missingReason, "SaveNotFound")
		expect.equal(store.writes, writes)
		expect.equal(store.records[PersistenceService.keyFor(SAVE_B)], nil)
	end)

	t.test("markDeleted reports members and the invite code", function()
		local store = copyingStore()
		local key = PersistenceService.keyFor(SAVE_A)
		local record = BusinessState.new(SAVE_A, 42, "Team Lot")
		record.saveSize = "Duo"
		record.inviteCode = "12345"
		record.members["43"] = "Member"
		store.records[key] = record
		local job = service(store, "job-a")
		local ok, reason, info = job:markDeleted(SAVE_A)
		expect.truthy(ok)
		expect.equal(reason, nil)
		expect.equal(#info.memberUserIds, 1)
		expect.equal(info.memberUserIds[1], 43)
		expect.equal(info.inviteCode, "12345")
		expect.equal(store.records[key]._deletedAt, 100)
		local none, noneReason, noneInfo = job:markDeleted(SAVE_B)
		expect.truthy(none)
		expect.equal(noneReason, nil)
		expect.equal(#noneInfo.memberUserIds, 0)
		expect.equal(noneInfo.inviteCode, nil)
	end)

	-- CM2-S1 Fix round 2: the old 32-hex save key is 56 chars and the real store refuses it.
	t.test("rejects over-long keys like the real DataStore", function()
		local store = copyingStore()
		local state, reason = service(store, "job-a"):load("save:4584569287_" .. string.rep("a", 32), 4584569287)
		expect.equal(state, nil)
		expect.truthy(type(reason) == "string" and string.find(reason, "KeyNameLimit", 1, true) ~= nil)
		expect.equal(store.writes, 0)
	end)
end

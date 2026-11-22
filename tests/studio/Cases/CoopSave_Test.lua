--!strict
-- CM2-S2: co-op saves and invite codes with the real SaveSlot, Persistence, CompanyState,
-- Plot and InviteCode services over fake DataStores. A second stack (job-b) shares the
-- stores and stands for another server. No test touches a real DataStore.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local SaveProfile = require(Shared:WaitForChild("SaveProfile"))
	local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
	local CompanyStateService = require(Services:WaitForChild("CompanyStateService"))
	local InviteCodeService = require(Services:WaitForChild("InviteCodeService"))
	local PersistenceService = require(Services:WaitForChild("PersistenceService"))
	local PlotService = require(Services:WaitForChild("PlotService"))
	local SaveSlotService = require(Services:WaitForChild("SaveSlotService"))
	local expect = t.expect

	local OWNER = 42
	local FRIEND = 43
	local THIRD = 44
	local KEY_NAME_LIMIT = 50 -- real DataStore rule (KeyNameLimit)
	local WRONG_CODE = "54321"

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

	local function noWait() end

	local function newStack(env, jobId: string)
		local stack: any = { activated = {}, deactivated = {}, removed = {}, teamChanged = {}, loads = 0 }
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
			wait = function(seconds: number)
				env.wait(seconds)
			end,
			newSaveId = function(userId: number): string
				env.saveCounter += 1
				return string.format("%d_%016x", userId, env.saveCounter)
			end,
			filterName = function(_, text: string)
				return true, text
			end,
			teleport = function()
				return false
			end,
		})
		stack.service:setActivationHandlers(function(...)
			table.insert(stack.activated, table.pack(...))
		end, function(...)
			table.insert(stack.deactivated, table.pack(...))
		end)
		stack.service:setTeamHandlers(function(...)
			table.insert(stack.removed, table.pack(...))
		end, function(...)
			table.insert(stack.teamChanged, table.pack(...))
		end)
		return stack
	end

	local function setup()
		local env: any = {
			now = 1000,
			companyStore = fakeStore(),
			profileStore = fakeStore(),
			inviteStore = fakeStore(),
			codes = {},
			nextCode = 12345,
			saveCounter = 0,
			names = { [OWNER] = "OwnerName", [FRIEND] = "FriendName", [THIRD] = "ThirdName" },
			wait = noWait,
		}
		-- Queued codes first, then 12345, 12346, ...
		env.randomCode = function(): number
			if #env.codes > 0 then
				return table.remove(env.codes, 1) :: number
			end
			env.nextCode += 1
			return env.nextCode - 1
		end
		env.a = newStack(env, "job-a")
		env.b = newStack(env, "job-b")
		return env
	end

	local requestNumber = 0
	local function request(action: string, payload: any?, requestId: string?)
		requestNumber += 1
		return {
			version = 1,
			requestId = requestId or string.format("coop_req_%06d", requestNumber),
			action = action,
			payload = payload or {},
		}
	end

	local function act(stack, userId: number, action: string, payload: any?)
		return stack.service:handle(userId, request(action, payload))
	end

	local function order(stack, companyId: string, userId: number, requestId: string?)
		return stack.companies:handle(companyId, userId, {
			version = 1,
			requestId = requestId or string.format("coop_order_%06d", requestNumber + 1),
			action = "Supplier.PlaceOrder",
			payload = { speciesId = "DouglasFir", sizeId = "Medium", quantity = 1 },
		})
	end

	local function recordOf(env, saveId: string)
		return env.companyStore.records[PersistenceService.keyFor("save:" .. saveId)]
	end

	local function profileOf(env, userId: number)
		return env.profileStore.records[SaveSlotService.profileKey(userId)]
	end

	local function inviteOf(env, code: string)
		return env.inviteStore.records[InviteCodeService.keyFor(code)]
	end

	local function count(list, userId: number): number
		local found = 0
		for _, args in ipairs(list) do
			if args[1] == userId then
				found += 1
			end
		end
		return found
	end

	-- The owner creates a co-op save on job-a and plays it, which gives it a code.
	local function coopSave(env, size: string?)
		local stack = env.a
		expect.truthy(stack.service:openProfile(OWNER))
		local created = act(stack, OWNER, "Save.Create", { name = "Duo Lot", size = size or "Duo" })
		expect.truthy(created.ok)
		local saveId = created.data.saveId
		local ok, reason, data = stack.service:play(OWNER, saveId)
		expect.equal(reason, nil)
		expect.truthy(ok)
		local companyId = "save:" .. saveId
		local info = stack.companies:teamInfo(companyId)
		return {
			saveId = saveId,
			companyId = companyId,
			code = info and info.inviteCode,
			plotId = data.plotId,
		}
	end

	local function join(stack, userId: number, code: string)
		return act(stack, userId, "Save.Join", { code = code })
	end

	-- FRIEND joins the save and plays it on job-a.
	local function joinAndPlay(env, save)
		expect.truthy(join(env.a, FRIEND, save.code).ok)
		local ok, reason, data = env.a.service:play(FRIEND, save.saveId)
		expect.equal(reason, nil)
		expect.truthy(ok)
		return data
	end

	local function steal(env, save)
		recordOf(env, save.saveId)._session = { jobId = "thief", expiresAt = env.now + 300 }
		expect.falsy(env.a.companies:flushDirty(true))
		expect.falsy(env.a.companies:isAvailable(save.companyId))
	end

	t.test("gives a Duo save an invite code on first play", function()
		local env = setup()
		local save = coopSave(env)
		local entry = SaveProfile.find(profileOf(env, OWNER), save.saveId)
		expect.equal(entry.size, "Duo")
		expect.equal(entry.role, "Owner")
		local record = recordOf(env, save.saveId)
		expect.equal(record.saveSize, "Duo")
		expect.truthy(BusinessState.isInviteCode(record.inviteCode))
		expect.equal(record.inviteCode, save.code)
		expect.equal(inviteOf(env, save.code).saveId, save.saveId)
		local view = env.a.activated[1][5]
		expect.equal(view.role, "Owner")
		expect.equal(view.size, "Duo")
		expect.equal(view.saveName, "Duo Lot")

		local starterId = profileOf(env, OWNER).saves[1].saveId
		expect.truthy(env.a.service:play(OWNER, starterId))
		expect.equal(env.a.companies:teamInfo("save:" .. starterId).inviteCode, nil)
		expect.equal(recordOf(env, starterId).inviteCode, nil)
		for _, store in { env.companyStore, env.profileStore, env.inviteStore } do
			for key in pairs(store.records) do
				expect.truthy(#key <= KEY_NAME_LIMIT)
			end
		end
	end)

	t.test("joins by code and shares the plot on one server", function()
		local env = setup()
		local save = coopSave(env)
		local joined = join(env.a, FRIEND, save.code)
		expect.truthy(joined.ok)
		expect.equal(joined.data.saveId, save.saveId)
		expect.equal(joined.data.size, "Duo")
		expect.equal(joined.data.alreadyMember, false)
		local entry = SaveProfile.find(profileOf(env, FRIEND), save.saveId)
		expect.equal(entry.role, "Member")
		expect.equal(entry.name, "Shared lot")
		expect.equal(entry.size, "Duo")
		local ok, reason, data = env.a.service:play(FRIEND, save.saveId)
		expect.equal(reason, nil)
		expect.truthy(ok)
		expect.equal(data.plotId, save.plotId)
		expect.equal(env.a.loads, 1)
		local players = env.a.service:playersOn(save.companyId)
		expect.equal(#players, 2)
		expect.equal(players[1], OWNER)
		expect.equal(players[2], FRIEND)
		local friendActivation = env.a.activated[#env.a.activated]
		expect.equal(friendActivation[1], FRIEND)
		expect.equal(friendActivation[4], nil)
		expect.equal(friendActivation[5].role, "Member")
		expect.equal(friendActivation[5].saveName, nil)
		expect.equal(friendActivation[5].ownerName, "OwnerName")

		local listed = act(env.a, FRIEND, "Save.List")
		local row = nil
		for _, candidate in ipairs(listed.data.saves) do
			if candidate.saveId == save.saveId then
				row = candidate
			end
		end
		expect.truthy(row)
		expect.equal(row.name, nil)
		expect.equal(row.ownerName, "OwnerName")
		expect.equal(row.role, "Member")
		expect.equal(row.seats, 2)
		expect.equal(row.active, true)
		-- The owner's own code is a no-op.
		local writes = env.companyStore.writes
		local own = join(env.a, OWNER, save.code)
		expect.truthy(own.ok)
		expect.equal(own.data.alreadyMember, true)
		expect.equal(env.companyStore.writes, writes)

		-- Amendment B F1: a member whose entry was lost gets it back on Join with the code.
		local friendStored = profileOf(env, FRIEND)
		local _, lostIndex = SaveProfile.find(friendStored, save.saveId)
		table.remove(friendStored.saves, lostIndex)
		env.a.service:closeProfile(FRIEND)
		local recordWrites = env.companyStore.writes
		local restored = join(env.a, FRIEND, save.code)
		expect.truthy(restored.ok)
		expect.equal(restored.data.saveId, save.saveId)
		expect.equal(restored.data.alreadyMember, true)
		local back = SaveProfile.find(profileOf(env, FRIEND), save.saveId)
		expect.truthy(back)
		expect.equal(back.role, "Member")
		expect.equal(back.size, "Duo")
		expect.equal(env.companyStore.writes, recordWrites)
		local profileWrites = env.profileStore.writes
		local again = join(env.a, FRIEND, save.code)
		expect.truthy(again.ok)
		expect.equal(again.data.alreadyMember, true)
		expect.equal(env.profileStore.writes, profileWrites)
		-- The owner never gets a member entry written.
		local ownerBefore = deepCopy(profileOf(env, OWNER))
		local ownAgain = join(env.a, OWNER, save.code)
		expect.truthy(ownAgain.ok)
		expect.equal(ownAgain.data.alreadyMember, true)
		expect.equal(env.profileStore.writes, profileWrites)
		local ownerAfter = profileOf(env, OWNER)
		expect.equal(#ownerAfter.saves, #ownerBefore.saves)
		expect.equal(ownerAfter.updatedAt, ownerBefore.updatedAt)
		local ownerEntry = SaveProfile.find(ownerAfter, save.saveId)
		expect.equal(ownerEntry.role, "Owner")
		expect.equal(ownerEntry.name, "Duo Lot")
	end)

	t.test("members act on one cash balance without double-spending", function()
		local env = setup()
		local save = coopSave(env)
		joinAndPlay(env, save)
		local unitPrice = GameConfig.wholesaleFor("DouglasFir", "Medium") :: number
		local state = env.a.activated[1][4]
		state.cash = unitPrice + 1
		local first = order(env.a, save.companyId, OWNER, "coop_spend_a")
		local second = order(env.a, save.companyId, FRIEND, "coop_spend_b")
		expect.truthy(first.ok)
		expect.falsy(second.ok)
		expect.equal(second.errorCode, "InsufficientFunds")
		expect.truthy(env.a.companies:flushDirty(true))
		local record = recordOf(env, save.saveId)
		expect.equal(record.cash, 1)
		expect.equal(record.spent, unitPrice)
		local pending = 0
		for _ in pairs(record.pendingOrders) do
			pending += 1
		end
		expect.equal(pending, 1)
	end)

	t.test("enforces the seat limit", function()
		local env = setup()
		local save = coopSave(env)
		expect.truthy(join(env.a, FRIEND, save.code).ok)
		expect.truthy(env.a.service:openProfile(THIRD))
		local before = deepCopy(profileOf(env, THIRD))
		local full = join(env.a, THIRD, save.code)
		expect.equal(full.errorCode, "SaveFull")
		local after = profileOf(env, THIRD)
		expect.equal(#after.saves, #before.saves)
		expect.equal(after.updatedAt, before.updatedAt)
		expect.equal(SaveProfile.find(after, save.saveId), nil)
		local resized = act(env.a, OWNER, "Save.SetSize", { size = "Trio" })
		expect.truthy(resized.ok)
		expect.equal(resized.data.seats, 3)
		local joined = join(env.a, THIRD, save.code)
		expect.truthy(joined.ok)
		expect.equal(joined.data.size, "Trio")
		expect.equal(recordOf(env, save.saveId).members["44"], "Member")
	end)

	t.test("rejects owner-only actions from members", function()
		local env = setup()
		local save = coopSave(env)
		joinAndPlay(env, save)
		local refused = {
			act(env.a, FRIEND, "Save.Rename", { saveId = save.saveId, name = "Hijack" }),
			act(env.a, FRIEND, "Save.Delete", { saveId = save.saveId, confirmName = "Shared lot" }),
			act(env.a, FRIEND, "Save.RemoveMember", { userId = OWNER }),
			act(env.a, FRIEND, "Save.RegenerateCode"),
			act(env.a, FRIEND, "Save.SetSize", { size = "Quad" }),
		}
		for _, response in ipairs(refused) do
			expect.falsy(response.ok)
			expect.equal(response.errorCode, "OwnerOnly")
		end
		local info = env.a.companies:teamInfo(save.companyId)
		expect.equal(info.saveName, "Duo Lot")
		expect.equal(info.saveSize, "Duo")
		expect.equal(info.inviteCode, save.code)
		expect.equal(info.members["42"], "Owner")
		expect.equal(info.members["43"], "Member")
		local record = recordOf(env, save.saveId)
		expect.equal(record.saveName, "Duo Lot")
		expect.equal(record.inviteCode, save.code)
		expect.equal(record._deletedAt, nil)
		expect.equal(SaveProfile.find(profileOf(env, OWNER), save.saveId).name, "Duo Lot")
	end)

	t.test("a new code invalidates the old one", function()
		local env = setup()
		local save = coopSave(env)
		local old = save.code :: string
		-- The first drawn code equals the current one; it is skipped.
		env.codes = { tonumber(old), 22222 }
		local renewed = act(env.a, OWNER, "Save.RegenerateCode")
		expect.truthy(renewed.ok)
		local new = renewed.data.inviteCode
		expect.equal(new, "22222")
		expect.truthy(new ~= old)
		expect.equal(recordOf(env, save.saveId).inviteCode, new)
		expect.equal(inviteOf(env, old).saveId, nil)
		expect.truthy(inviteOf(env, old).freedAt)
		expect.equal(inviteOf(env, new).saveId, save.saveId)
		expect.truthy(env.a.service:openProfile(THIRD))
		expect.equal(join(env.a, THIRD, old).errorCode, "InviteCodeInvalid")
		expect.truthy(join(env.a, FRIEND, new).ok)
		expect.equal(join(env.a, THIRD, new).errorCode, "SaveFull")
	end)

	t.test("a removed member loses access at once and on the next play", function()
		local env = setup()
		local save = coopSave(env)
		joinAndPlay(env, save)
		local removed = act(env.a, OWNER, "Save.RemoveMember", { userId = FRIEND })
		expect.truthy(removed.ok)
		expect.equal(removed.data.userId, FRIEND)
		expect.equal(env.a.service:activeCompanyId(FRIEND), nil)
		expect.equal(#env.a.removed, 1)
		expect.equal(env.a.removed[1][1], FRIEND)
		expect.equal(env.a.removed[1][2], save.saveId)
		expect.equal(SaveProfile.find(profileOf(env, FRIEND), save.saveId), nil)
		-- Saved at once, without a flush.
		expect.equal(recordOf(env, save.saveId).members["43"], nil)
		local forbidden = order(env.a, save.companyId, FRIEND)
		expect.equal(forbidden.errorCode, "Forbidden")
		expect.equal(env.a.service:activeCompanyId(OWNER), save.companyId)
		expect.equal(env.a.plots:getPlot(save.companyId), save.plotId)

		-- A stale entry heals on the next play.
		local stale = profileOf(env, FRIEND)
		table.insert(stale.saves, {
			saveId = save.saveId,
			name = "Shared lot",
			role = "Member",
			size = "Duo",
			createdAt = 1000,
			lastPlayedAt = 0,
		})
		env.a.service:closeProfile(FRIEND)
		local ok, reason = env.a.service:play(FRIEND, save.saveId)
		expect.falsy(ok)
		expect.equal(reason, "NotAMember")
		expect.equal(SaveProfile.find(profileOf(env, FRIEND), save.saveId), nil)
		expect.equal(env.a.service:activeCompanyId(FRIEND), nil)
	end)

	t.test("members play while the owner is offline", function()
		local env = setup()
		local save = coopSave(env)
		expect.truthy(join(env.a, FRIEND, save.code).ok)
		expect.truthy(env.a.service:leave(OWNER, true))
		expect.equal(recordOf(env, save.saveId)._session, nil)
		local ok, reason = env.a.service:play(FRIEND, save.saveId)
		expect.equal(reason, nil)
		expect.truthy(ok)
		expect.equal(env.a.companies:memberRole(save.companyId, FRIEND), "Member")
		local info = env.a.companies:teamInfo(save.companyId)
		expect.equal(info.saveName, "Duo Lot")
		expect.equal(info.ownerUserId, OWNER)
		expect.truthy(order(env.a, save.companyId, FRIEND).ok)
		expect.truthy(env.a.service:leave(FRIEND, true))
		local unitPrice = GameConfig.wholesaleFor("DouglasFir", "Medium") :: number
		local record = recordOf(env, save.saveId)
		expect.equal(record.cash, GameConfig.StartingCash - unitPrice)
		expect.equal(record.saveName, "Duo Lot")
		expect.equal(record.ownerUserId, OWNER)
		expect.equal(record._session, nil)
	end)

	t.test("the last player to leave unloads the shared save", function()
		local env = setup()
		local save = coopSave(env)
		joinAndPlay(env, save)
		local starterId = profileOf(env, OWNER).saves[1].saveId
		local switched, _, switchData = env.a.service:play(OWNER, starterId)
		expect.truthy(switched)
		expect.truthy(switchData.plotId ~= save.plotId)
		expect.truthy(env.a.companies:isAvailable(save.companyId))
		expect.equal(env.a.plots:getPlot(save.companyId), save.plotId)
		local ownerLeft = env.a.deactivated[#env.a.deactivated]
		expect.equal(ownerLeft[1], OWNER)
		expect.equal(ownerLeft[2], save.companyId)
		expect.equal(ownerLeft[4], false)
		expect.equal(recordOf(env, save.saveId)._session.jobId, "job-a")
		expect.truthy(env.a.service:leave(FRIEND, true))
		expect.equal(recordOf(env, save.saveId)._session, nil)
		expect.equal(env.a.plots:getPlot(save.companyId), nil)
		expect.falsy(env.a.companies:hasSession(save.companyId))
		local friendLeft = env.a.deactivated[#env.a.deactivated]
		expect.equal(friendLeft[1], FRIEND)
		expect.equal(friendLeft[4], true)
	end)

	t.test("joining while nobody plays the save writes the record without a lock", function()
		local env = setup()
		local save = coopSave(env)
		expect.truthy(env.a.service:leave(OWNER, true))
		local joined = join(env.a, FRIEND, save.code)
		expect.truthy(joined.ok)
		local record = recordOf(env, save.saveId)
		expect.equal(record.members["43"], "Member")
		expect.equal(record.members["42"], "Owner")
		expect.equal(record._session, nil)
		expect.equal(record.inviteCode, save.code)
		expect.truthy(BusinessState.validate((function()
			local copy = deepCopy(record)
			copy._session = nil
			return copy
		end)()))
		expect.falsy(env.a.companies:hasSession(save.companyId))
	end)

	t.test("one server holds a shared save at a time", function()
		local env = setup()
		local save = coopSave(env)
		expect.truthy(join(env.a, FRIEND, save.code).ok)
		local ok, reason = env.b.service:play(FRIEND, save.saveId)
		expect.falsy(ok)
		expect.equal(reason, "SessionLocked")
		expect.equal(env.b.plots:getPlot(save.companyId), nil)
		expect.equal(recordOf(env, save.saveId)._session.jobId, "job-a")
		local again = join(env.b, FRIEND, save.code)
		expect.equal(again.errorCode, "SaveInUse")
	end)

	t.test("leaving a shared save frees the seat", function()
		local env = setup()
		local save = coopSave(env)
		joinAndPlay(env, save)
		local left = act(env.a, FRIEND, "Save.LeaveTeam", { saveId = save.saveId })
		expect.truthy(left.ok)
		expect.equal(left.data.saveId, save.saveId)
		expect.equal(env.a.service:activeCompanyId(FRIEND), nil)
		expect.equal(count(env.a.deactivated, FRIEND), 1)
		expect.equal(recordOf(env, save.saveId).members["43"], nil)
		expect.equal(env.a.companies:memberRole(save.companyId, FRIEND), nil)
		expect.equal(SaveProfile.find(profileOf(env, FRIEND), save.saveId), nil)
		local owner = act(env.a, OWNER, "Save.LeaveTeam", { saveId = save.saveId })
		expect.equal(owner.errorCode, "OwnerCannotLeave")
	end)

	t.test("deleting a shared save removes it from members' lists", function()
		local env = setup()
		local save = coopSave(env)
		joinAndPlay(env, save)
		local starterId = profileOf(env, OWNER).saves[1].saveId
		expect.truthy(env.a.service:play(OWNER, starterId))
		local busy = act(env.a, OWNER, "Save.Delete", { saveId = save.saveId, confirmName = "Duo Lot" })
		expect.equal(busy.errorCode, "SaveInUse")
		expect.equal(recordOf(env, save.saveId)._deletedAt, nil)
		expect.truthy(env.a.service:leave(FRIEND))
		local deleted = act(env.a, OWNER, "Save.Delete", { saveId = save.saveId, confirmName = "Duo Lot" })
		expect.truthy(deleted.ok)
		expect.truthy(recordOf(env, save.saveId)._deletedAt)
		expect.equal(SaveProfile.find(profileOf(env, FRIEND), save.saveId), nil)
		expect.equal(SaveProfile.find(profileOf(env, OWNER), save.saveId), nil)
		expect.equal(inviteOf(env, save.code).saveId, nil)
		expect.truthy(inviteOf(env, save.code).freedAt)
	end)

	t.test("locks out repeated wrong codes", function()
		local env = setup()
		local save = coopSave(env)
		expect.truthy(env.a.service:openProfile(FRIEND))
		for round = 1, 2 do
			for _ = 1, 5 do
				expect.equal(join(env.a, FRIEND, WRONG_CODE).errorCode, "InviteCodeInvalid")
			end
			if round == 1 then
				env.now += 61
			end
		end
		env.now += 61
		local inviteCalls = env.inviteStore.calls
		local profileCalls = env.profileStore.calls
		env.a.service:closeProfile(FRIEND)
		expect.equal(join(env.a, FRIEND, WRONG_CODE).errorCode, "JoinLocked")
		expect.equal(env.inviteStore.calls, inviteCalls)
		expect.equal(env.profileStore.calls, profileCalls)
		expect.equal(join(env.a, FRIEND, save.code).errorCode, "JoinLocked")
		expect.equal(env.inviteStore.calls, inviteCalls)
		-- The first failures leave the window after 3600 s.
		env.now = 1000 + 3601
		local joined = join(env.a, FRIEND, save.code)
		expect.equal(joined.errorCode, nil)
		expect.truthy(joined.ok)

		local server = setup()
		for userId = 100, 159 do
			expect.equal(join(server.a, userId, WRONG_CODE).errorCode, "InviteCodeInvalid")
		end
		local calls = server.inviteStore.calls
		expect.equal(join(server.a, 160, WRONG_CODE).errorCode, "JoinLocked")
		expect.equal(server.inviteStore.calls, calls)
	end)

	t.test("a failed shared session is evicted when a member plays it again", function()
		local env = setup()
		local save = coopSave(env)
		joinAndPlay(env, save)
		local failed = {}
		env.a.companies:setSessionFailedHandler(function(...)
			table.insert(failed, table.pack(...))
		end)
		steal(env, save)
		expect.equal(#failed, 1)
		expect.equal(failed[1][1], save.companyId)
		expect.equal(failed[1][2], "SessionLocked")
		recordOf(env, save.saveId)._session = nil
		local ok, reason, data = env.a.service:play(FRIEND, save.saveId)
		expect.equal(reason, nil)
		expect.truthy(ok)
		expect.equal(data.plotId, save.plotId)
		expect.equal(env.a.service:activeCompanyId(OWNER), nil)
		expect.equal(count(env.a.deactivated, OWNER), 1)
		expect.equal(env.a.service:activeCompanyId(FRIEND), save.companyId)
		expect.truthy(env.a.companies:isAvailable(save.companyId))
		local players = env.a.service:playersOn(save.companyId)
		expect.equal(#players, 1)
		expect.equal(players[1], FRIEND)
	end)

	t.test("a member's failed load never frees the shared plot", function()
		local env = setup()
		local save = coopSave(env)
		expect.truthy(join(env.a, FRIEND, save.code).ok)
		expect.truthy(env.a.service:leave(OWNER, true))
		expect.equal(env.a.plots:getPlot(save.companyId), nil)
		local saveKey = PersistenceService.keyFor(save.companyId)
		local friendResult = nil
		env.companyStore.beforeUpdate = function(key: string)
			if key == saveKey and friendResult == nil then
				friendResult = table.pack(env.a.service:play(FRIEND, save.saveId))
			end
		end
		local ok, reason, data = env.a.service:play(OWNER, save.saveId)
		env.companyStore.beforeUpdate = nil
		expect.truthy(friendResult)
		expect.falsy(friendResult[1])
		expect.equal(friendResult[2], "SessionBusy")
		expect.equal(reason, nil)
		expect.truthy(ok)
		expect.equal(env.a.plots:getPlot(save.companyId), data.plotId)
		expect.equal(env.a.service:activeCompanyId(OWNER), save.companyId)
		expect.equal(env.a.service:activeCompanyId(FRIEND), nil)
	end)

	-- Amendment 2026-11-22 ----------------------------------------------------------------

	t.test("only team changes notify the players on the save", function()
		local env = setup()
		local save = coopSave(env)
		joinAndPlay(env, save)
		local changes = env.a.teamChanged
		local baseline = #changes
		for _ = 1, 3 do
			expect.truthy(act(env.a, OWNER, "Save.Team").ok)
			expect.truthy(act(env.a, FRIEND, "Save.Team").ok)
		end
		expect.equal(#changes, baseline)
		expect.truthy(act(env.a, OWNER, "Save.RegenerateCode").ok)
		expect.equal(#changes, baseline + 1)
		expect.equal(changes[baseline + 1][1], save.companyId)
		expect.equal(changes[baseline + 1][2], "Duo")
		expect.equal(act(env.a, OWNER, "Save.SetSize", { size = "Solo" }).errorCode, "SizeTooSmall")
		expect.equal(#changes, baseline + 1)
		expect.truthy(act(env.a, OWNER, "Save.RemoveMember", { userId = FRIEND }).ok)
		expect.equal(#changes, baseline + 2)

		-- The team view itself (owner first, online flags, the code for every member).
		local team = act(env.a, OWNER, "Save.Team")
		expect.equal(team.data.saveId, save.saveId)
		expect.equal(team.data.seats, 2)
		expect.equal(team.data.role, "Owner")
		expect.equal(#team.data.members, 1)
		expect.equal(team.data.members[1].userId, OWNER)
		expect.equal(team.data.members[1].name, "OwnerName")
		expect.equal(team.data.members[1].online, true)
		expect.truthy(BusinessState.isInviteCode(team.data.inviteCode))
	end)

	t.test("a member waiting on the last leaver's unload keeps the shared plot", function()
		local env = setup()
		local save = coopSave(env)
		expect.truthy(join(env.a, FRIEND, save.code).ok)
		expect.truthy(env.a.service:openProfile(THIRD))
		env.wait = function()
			coroutine.yield()
		end
		local saveKey = PersistenceService.keyFor(save.companyId)
		local updates = 0
		local friend = nil
		local friendResult = nil
		local loads = env.a.loads
		env.companyStore.beforeUpdate = function(key: string)
			if key ~= saveKey or friend ~= nil then
				return
			end
			updates += 1
			if updates == 2 then
				-- The leaver's lock release is in flight.
				friend = coroutine.create(function()
					friendResult = table.pack(env.a.service:play(FRIEND, save.saveId))
				end)
				coroutine.resume(friend)
			end
		end
		expect.truthy(env.a.service:leave(OWNER, true))
		env.companyStore.beforeUpdate = nil
		expect.truthy(friend)
		-- The member's play waited instead of loading under the in-flight release.
		expect.equal(coroutine.status(friend), "suspended")
		expect.equal(env.a.loads, loads)
		while coroutine.status(friend) ~= "dead" do
			coroutine.resume(friend)
		end
		env.wait = noWait
		local ownerLeft = nil
		for _, args in ipairs(env.a.deactivated) do
			if args[1] == OWNER then
				ownerLeft = args
			end
		end
		expect.truthy(ownerLeft)
		expect.equal(ownerLeft[4], false)
		expect.truthy(friendResult)
		expect.equal(friendResult[2], nil)
		expect.truthy(friendResult[1])
		expect.equal(friendResult[3].plotId, save.plotId)
		expect.equal(env.a.plots:getPlot(save.companyId), save.plotId)
		expect.equal(env.a.loads, loads + 1)
		expect.equal(recordOf(env, save.saveId)._session.jobId, "job-a")
		local thirdSave = profileOf(env, THIRD).saves[1].saveId
		local thirdOk, _, thirdData = env.a.service:play(THIRD, thirdSave)
		expect.truthy(thirdOk)
		expect.truthy(thirdData.plotId ~= save.plotId)
	end)

	t.test("team actions on a failed session return CompanyUnavailable", function()
		local env = setup()
		local save = coopSave(env)
		joinAndPlay(env, save)
		steal(env, save)
		local writes = env.inviteStore.writes
		local before = deepCopy(env.inviteStore.records)
		expect.equal(act(env.a, OWNER, "Save.Team").errorCode, "CompanyUnavailable")
		expect.equal(act(env.a, OWNER, "Save.RegenerateCode").errorCode, "CompanyUnavailable")
		expect.equal(act(env.a, FRIEND, "Save.RemoveMember", { userId = OWNER }).errorCode, "CompanyUnavailable")
		expect.equal(env.inviteStore.writes, writes)
		for key, value in pairs(before) do
			expect.equal(env.inviteStore.records[key].saveId, value.saveId)
		end
		for key in pairs(env.inviteStore.records) do
			expect.truthy(before[key] ~= nil)
		end
	end)

	t.test("an unsaved code change keeps the old map entry", function()
		local env = setup()
		local save = coopSave(env)
		local old = save.code :: string
		env.companyStore.failKeys[PersistenceService.keyFor(save.companyId)] = true
		local renewed = act(env.a, OWNER, "Save.RegenerateCode")
		expect.truthy(renewed.ok)
		local new = renewed.data.inviteCode
		expect.truthy(new ~= old)
		expect.equal(env.a.companies:teamInfo(save.companyId).inviteCode, new)
		expect.equal(inviteOf(env, old).saveId, save.saveId)
		expect.equal(inviteOf(env, new).saveId, save.saveId)
		local solo = act(env.a, OWNER, "Save.SetSize", { size = "Solo" })
		expect.truthy(solo.ok)
		expect.equal(env.a.companies:teamInfo(save.companyId).inviteCode, nil)
		expect.equal(inviteOf(env, new).saveId, save.saveId)
		expect.truthy(env.a.companies:isDirty(save.companyId))
		expect.truthy(env.a.companies:isAvailable(save.companyId))
	end)
end

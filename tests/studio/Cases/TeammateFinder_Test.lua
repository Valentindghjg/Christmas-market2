--!strict
-- CM2-S3: the in-server teammate finder with the real SaveSlot, Persistence, CompanyState,
-- Plot and InviteCode services over fake DataStores, on one stack without a locator
-- (Amendment A1.6). No test touches a real DataStore.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Protocol = require(Shared:WaitForChild("Protocol"))
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
	local JOIN_FAILURE_ACTION = "fail"
	local UNKNOWN_SAVE_ID = "42_00000000000000ff"

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

	-- Deep-copies on read and write like a real DataStore; throws for a key in failKeys.
	local function fakeStore()
		local store: any = { records = {}, failKeys = {}, writes = 0 }
		function store.UpdateAsync(_, key: string, transform)
			if #key > KEY_NAME_LIMIT then
				error("KeyNameLimit: Key name exceeds the 50 character limit.")
			end
			if store.failKeys[key] then
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

	local function setup()
		local env: any = {
			now = 1000,
			companyStore = fakeStore(),
			profileStore = fakeStore(),
			inviteStore = fakeStore(),
			nextCode = 12345,
			saveCounter = 0,
			listingChanges = 0,
			names = { [OWNER] = "OwnerName", [FRIEND] = "FriendName", [THIRD] = "ThirdName" },
		}
		local function clock(): number
			return env.now
		end
		env.persistence = PersistenceService.new(env.companyStore, "job-a", clock, noWait)
		env.companies = CompanyStateService.new(env.persistence, clock, nil, function() end)
		env.plots = PlotService.new({ "Plot_01", "Plot_02", "Plot_03" })
		env.invites = InviteCodeService.new(env.inviteStore, clock, noWait, function(): number
			env.nextCode += 1
			return env.nextCode - 1
		end)
		env.service = SaveSlotService.new({
			profileStore = env.profileStore,
			persistence = env.persistence,
			companies = env.companies,
			plots = env.plots,
			invites = env.invites,
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
			teleport = function()
				return false
			end,
		})
		env.service:setFinderHandler(function()
			env.listingChanges += 1
		end)
		return env
	end

	local requestNumber = 0
	local function act(env, userId: number, action: string, payload: any?)
		requestNumber += 1
		return env.service:handle(userId, {
			version = 1,
			requestId = string.format("finder_req_%06d", requestNumber),
			action = action,
			payload = payload or {},
		})
	end

	local function recordOf(env, saveId: string)
		return env.companyStore.records[PersistenceService.keyFor("save:" .. saveId)]
	end

	local function profileOf(env, userId: number)
		return env.profileStore.records[SaveSlotService.profileKey(userId)]
	end

	local function countMembers(members): number
		local count = 0
		for _ in pairs(members) do
			count += 1
		end
		return count
	end

	-- The owner creates a co-op save and plays it.
	local function ownedCoop(env, size: string)
		expect.truthy(env.service:openProfile(OWNER))
		local created = act(env, OWNER, "Save.Create", { name = "Finder Lot", size = size })
		expect.truthy(created.ok)
		local saveId = created.data.saveId
		local ok, reason, data = env.service:play(OWNER, saveId)
		expect.equal(reason, nil)
		expect.truthy(ok)
		return saveId, data.plotId
	end

	t.test("starting a search creates a co-op save owned by the searcher", function()
		local env = setup()
		expect.truthy(env.service:openProfile(OWNER))
		local starterId = profileOf(env, OWNER).saves[1].saveId
		expect.truthy(env.service:play(OWNER, starterId))
		local started = act(env, OWNER, "Save.FinderStart", { size = "Trio" })
		expect.equal(started.errorCode, nil)
		expect.truthy(started.ok)
		expect.equal(started.data.created, true)
		local saveId = started.data.saveId
		expect.truthy(saveId ~= starterId)
		expect.equal(env.service:activeCompanyId(OWNER), "save:" .. saveId)
		local entry = SaveProfile.find(profileOf(env, OWNER), saveId)
		expect.equal(entry.role, "Owner")
		expect.equal(entry.size, "Trio")
		local record = recordOf(env, saveId)
		expect.equal(record.saveSize, "Trio")
		expect.equal(countMembers(record.members), 1)
		expect.equal(record.members["42"], "Owner")

		expect.truthy(env.service:openProfile(FRIEND))
		local listed = act(env, FRIEND, "Save.FinderList")
		expect.truthy(listed.ok)
		expect.equal(#listed.data.listings, 1)
		local row = listed.data.listings[1]
		expect.equal(row.saveId, saveId)
		expect.equal(row.ownerUserId, OWNER)
		expect.equal(row.ownerName, "OwnerName")
		expect.equal(row.size, "Trio")
		expect.equal(row.seats, 3)
		expect.equal(row.taken, 1)
		expect.equal(listed.data.ownSaveId, nil)
	end)

	t.test("an own co-op save with a free seat is listed instead", function()
		local env = setup()
		local saveId = ownedCoop(env, "Duo")
		local saves = #profileOf(env, OWNER).saves
		local changes = env.listingChanges
		local started = act(env, OWNER, "Save.FinderStart")
		expect.truthy(started.ok)
		expect.equal(started.data.created, false)
		expect.equal(started.data.saveId, saveId)
		expect.equal(env.listingChanges, changes + 1)
		local again = act(env, OWNER, "Save.FinderStart")
		expect.truthy(again.ok)
		expect.equal(again.data.created, false)
		expect.equal(again.data.saveId, saveId)
		expect.equal(env.listingChanges, changes + 1)
		local own = act(env, OWNER, "Save.FinderList")
		expect.truthy(own.ok)
		expect.equal(own.data.ownSaveId, saveId)
		expect.equal(#own.data.listings, 0)
		expect.equal(env.listingChanges, changes + 1)
		expect.equal(#profileOf(env, OWNER).saves, saves)
	end)

	t.test("a joiner takes a seat without a code on the shared plot", function()
		local env = setup()
		local saveId, plotId = ownedCoop(env, "Duo")
		expect.truthy(act(env, OWNER, "Save.FinderStart").ok)
		expect.truthy(env.service:openProfile(FRIEND))
		local changes = env.listingChanges
		local joined = act(env, FRIEND, "Save.FinderJoin", { saveId = saveId })
		expect.equal(joined.errorCode, nil)
		expect.truthy(joined.ok)
		expect.equal(joined.data.saveId, saveId)
		expect.equal(joined.data.plotId, plotId)
		expect.equal(env.service:activeCompanyId(FRIEND), "save:" .. saveId)
		local entry = SaveProfile.find(profileOf(env, FRIEND), saveId)
		expect.equal(entry.role, "Member")
		expect.equal(entry.name, "Shared lot")
		expect.equal(countMembers(recordOf(env, saveId).members), 2)
		expect.equal(recordOf(env, saveId).members["43"], "Member")
		-- The Duo is full now, so it is no longer listed.
		expect.truthy(env.listingChanges > changes)
		expect.truthy(env.service:openProfile(THIRD))
		local listed = act(env, THIRD, "Save.FinderList")
		expect.truthy(listed.ok)
		expect.equal(#listed.data.listings, 0)
	end)

	t.test("refuses full, own and gone listings", function()
		local env = setup()
		local saveId = ownedCoop(env, "Duo")
		expect.truthy(act(env, OWNER, "Save.FinderStart").ok)
		expect.truthy(env.service:openProfile(FRIEND))
		expect.truthy(act(env, FRIEND, "Save.FinderJoin", { saveId = saveId }).ok)
		expect.truthy(env.service:openProfile(THIRD))
		local full = act(env, THIRD, "Save.FinderJoin", { saveId = saveId })
		expect.equal(full.errorCode, "ListingGone")
		expect.equal(recordOf(env, saveId).members["44"], nil)
		expect.equal(SaveProfile.find(profileOf(env, THIRD), saveId), nil)

		-- A free seat again: the owner lists the save and tries to join it.
		expect.truthy(act(env, OWNER, "Save.SetSize", { size = "Trio" }).ok)
		local relisted = act(env, OWNER, "Save.FinderStart")
		expect.truthy(relisted.ok)
		expect.equal(relisted.data.created, false)
		local own = act(env, OWNER, "Save.FinderJoin", { saveId = saveId })
		expect.equal(own.errorCode, "OwnListing")
		local unknown = act(env, THIRD, "Save.FinderJoin", { saveId = UNKNOWN_SAVE_ID })
		expect.equal(unknown.errorCode, "ListingGone")
		for _, userId in { OWNER, FRIEND, THIRD } do
			expect.equal(Protocol.recentCount(env.service._joinFailures, userId, JOIN_FAILURE_ACTION, env.now), 0)
		end
	end)

	t.test("removes the listing on stop, switch, leave and a failed session", function()
		local env = setup()
		local saveId = ownedCoop(env, "Trio")
		local starterId = profileOf(env, OWNER).saves[1].saveId
		expect.truthy(act(env, OWNER, "Save.FinderStart").ok)
		expect.truthy(env.service._listings[OWNER])
		local stopped = act(env, OWNER, "Save.FinderStop")
		expect.truthy(stopped.ok)
		expect.equal(stopped.data.stopped, true)
		expect.equal(env.service._listings[OWNER], nil)
		-- Stopping without a listing changes nothing.
		local changes = env.listingChanges
		expect.truthy(act(env, OWNER, "Save.FinderStop").ok)
		expect.equal(env.listingChanges, changes)

		-- Switch.
		expect.truthy(act(env, OWNER, "Save.FinderStart").ok)
		expect.truthy(env.service._listings[OWNER])
		expect.truthy(env.service:play(OWNER, starterId))
		expect.equal(env.service._listings[OWNER], nil)

		-- Final leave (it also forgets the rate limits).
		expect.truthy(env.service:play(OWNER, saveId))
		expect.truthy(act(env, OWNER, "Save.FinderStart").ok)
		expect.truthy(env.service._listings[OWNER])
		changes = env.listingChanges
		expect.truthy(env.service:leave(OWNER, true))
		expect.equal(env.service._listings[OWNER], nil)
		expect.equal(env.listingChanges, changes + 1)

		-- A failed session, evicted by a member's play.
		expect.truthy(env.service:play(OWNER, saveId))
		expect.truthy(act(env, OWNER, "Save.FinderStart").ok)
		expect.truthy(env.service:openProfile(FRIEND))
		expect.truthy(act(env, FRIEND, "Save.FinderJoin", { saveId = saveId }).ok)
		expect.truthy(env.service._listings[OWNER])
		recordOf(env, saveId)._session = { jobId = "thief", expiresAt = env.now + 300 }
		expect.falsy(env.companies:flushDirty(true))
		expect.falsy(env.companies:isAvailable("save:" .. saveId))
		env.service:play(FRIEND, saveId)
		expect.equal(env.service._listings[OWNER], nil)

		-- A final leave of a player without a listing changes nothing (Amendment A1.5).
		changes = env.listingChanges
		env.service:leave(FRIEND, true)
		expect.equal(env.listingChanges, changes)
	end)

	t.test("rate-limits starting a search", function()
		local env = setup()
		ownedCoop(env, "Duo")
		for _ = 1, 3 do
			expect.truthy(act(env, OWNER, "Save.FinderStart").ok)
		end
		local limited = act(env, OWNER, "Save.FinderStart")
		expect.equal(limited.errorCode, "RateLimited")
		env.now += 301
		expect.truthy(act(env, OWNER, "Save.FinderStart").ok)
	end)

	t.test("keeps member names out and lists in creation order", function()
		local env = setup()
		expect.truthy(env.service:openProfile(FRIEND))
		local friendStart = act(env, FRIEND, "Save.FinderStart")
		expect.truthy(friendStart.ok)
		expect.equal(friendStart.data.created, true)
		env.now += 5
		local ownerSave = ownedCoop(env, "Quad")
		local ownerStart = act(env, OWNER, "Save.FinderStart")
		expect.truthy(ownerStart.ok)
		expect.equal(ownerStart.data.saveId, ownerSave)
		expect.truthy(env.service:openProfile(THIRD))
		local listed = act(env, THIRD, "Save.FinderList")
		expect.truthy(listed.ok)
		expect.equal(#listed.data.listings, 2)
		expect.equal(listed.data.listings[1].ownerUserId, FRIEND)
		expect.equal(listed.data.listings[1].saveId, friendStart.data.saveId)
		expect.equal(listed.data.listings[1].size, "Duo")
		expect.equal(listed.data.listings[2].ownerUserId, OWNER)
		expect.equal(listed.data.listings[2].seats, 4)
		for _, row in ipairs(listed.data.listings) do
			expect.equal(row.name, nil)
			expect.equal(row.saveName, nil)
			expect.equal(row.createdAt, nil)
		end
	end)
end

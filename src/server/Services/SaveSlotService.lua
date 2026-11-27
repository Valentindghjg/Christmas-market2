--!strict
-- Save slots per player (CM2-S1) and co-op saves (CM2-S2). Owns the player profile
-- (`profile:<userId>` in the profiles store), the legacy migration call, the `Save.*` actions,
-- play/switch/leave and the active-save registry. It fills the "SessionService" role of
-- TECHNICAL_ARCHITECTURE §2.
--
-- The profile is lock-free: every change is one UpdateAsync transform applied to the stored
-- value, so a second server can never lose an update. Company records keep their own
-- per-save session lock (PersistenceService). Several players on one server can share one
-- live session of a co-op save; the last one to leave unloads it.
--
-- CM2-S3: one server per save. An optional save-to-server map (SaveLocatorService) is claimed
-- before a load, renewed while the save is played and released by the last unload; it is a
-- pre-check that fails open, while the session lock stays the authority. Save.Teleport and
-- arrive() move a player to the server that plays a save; the teammate finder lists owned
-- co-op saves with a free seat on this server.
-- CM2-RF: the code is split into parts: SaveSlotPicker (slots, picker, play/switch/leave),
-- SaveSlotTeam (co-op members, invite codes), SaveSlotCrossServer (save-to-server map, teleport,
-- teammate finder) and SaveSlotShared (helpers).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AdventCalendar = require(Shared:WaitForChild("AdventCalendar"))
local DailyRewards = require(Shared:WaitForChild("DailyRewards"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Protocol = require(Shared:WaitForChild("Protocol"))
local SaveProfile = require(Shared:WaitForChild("SaveProfile"))
local SaveSlotShared = require(script.Parent:WaitForChild("SaveSlotShared"))
local failure = SaveSlotShared.failure
local saveIdOf = SaveSlotShared.saveIdOf
local newEntry = SaveSlotShared.newEntry
local sortedKeys = SaveSlotShared.sortedKeys
local callHandler = SaveSlotShared.callHandler
local storedProfile = SaveSlotShared.storedProfile

local SaveSlotService = {}
SaveSlotService.__index = SaveSlotService

-- v2 since CM2-S1 Fix round 2 (R2): v1 held only Studio test profiles with old 32-hex save
-- IDs that the current isSaveId rejects; it is abandoned and never read.
SaveSlotService.PROFILE_STORE_NAME = "ChristmasMarket2_Profiles_v2"

local SAVES = GameConfig.Saves
local PROFILE_ATTEMPTS = 3
local LEGACY_SAVE_NAME = string.format(SAVES.DefaultNameFormat, 1)

local function profileKey(userId: number): string
	return "profile:" .. SaveProfile.userIdText(userId)
end
SaveSlotService.profileKey = profileKey

function SaveSlotService.new(deps)
	local self = setmetatable({}, SaveSlotService)
	self._profileStore = deps.profileStore
	self._persistence = deps.persistence
	self._companies = deps.companies
	self._plots = deps.plots
	self._invites = deps.invites
	self._userName = deps.userName
	self._clock = deps.clock or os.time
	self._wait = deps.wait or function(seconds: number)
		task.wait(seconds)
	end
	self._newSaveId = deps.newSaveId
	self._filterName = deps.filterName
	self._teleport = deps.teleport
	-- CM2-S3: the save-to-server map (optional; nil disables every locator step) and the
	-- teleport into the server that plays a save.
	self._locator = deps.locator
	self._teleportToServer = deps.teleportToServer
	-- CM2-PP: the public lot-sign text of a plot (optional; (plotId) -> string?) and the
	-- teleport arrivals waiting for a plot pick (userId -> {saveId, attempt}).
	self._plotLabel = deps.plotLabel
	self._arrivals = {}
	self._limiters = {}
	for action, rule in pairs(SAVES.RateLimits) do
		self._limiters[action] = Protocol.newRateLimiter(rule.limit, rule.window)
	end
	-- Wrong invite codes per player and per server. Never cleared on leave, so a rejoin
	-- does not reset the lockout.
	self._joinFailures = Protocol.newRateLimiter(SAVES.JoinFailureLimit.limit, SAVES.JoinFailureLimit.window)
	self._serverJoinFailures =
		Protocol.newRateLimiter(SAVES.JoinServerFailureLimit.limit, SAVES.JoinServerFailureLimit.window)
	self._profiles = {}
	self._busy = {}
	self._leaving = {}
	self._active = {}
	self._members = {}
	-- Removed members who were busy when the owner removed them; kicked once they are idle.
	self._pendingKicks = {}
	-- Loads in progress per company and companies whose last session is being unloaded
	-- (Amendment A3: the plot hand-over between a last leaver and a waiting loader).
	self._pendingLoads = {}
	self._unloading = {}
	self._onActivated = nil
	self._onDeactivated = nil
	self._onRemoved = nil
	self._onTeamChanged = nil
	self._closing = false
	self._finalLeaves = 0
	-- CM2-S3: registration order per player (the host of a save), cached locator lookups,
	-- teammate-finder listings per owner.
	self._since = {}
	self._registerSeq = 0
	self._locationCache = {}
	self._listings = {}
	self._finderSeq = 0
	self._onListingsChanged = nil
	return self
end

-- Shutdown: refuse new save work from now on (BindToClose).
function SaveSlotService:beginShutdown()
	self._closing = true
	-- CM2-R5: caps the retries of final saves from now on.
	self._companies:beginShutdown()
end

-- Final leaves in progress, save actions in flight and retrying final saves (CM2-R5);
-- BindToClose waits for zero.
function SaveSlotService:pendingCount(): number
	local count = self._finalLeaves
	for _ in pairs(self._busy) do
		count += 1
	end
	return count + self._companies:unloadingCount()
end

function SaveSlotService:setActivationHandlers(onActivated, onDeactivated)
	self._onActivated = onActivated
	self._onDeactivated = onDeactivated
end

-- onRemoved(userId, saveId): the owner removed a member who played the save here.
-- onTeamChanged(companyId, size): a team change on a save that someone plays here.
function SaveSlotService:setTeamHandlers(onRemoved, onTeamChanged)
	self._onRemoved = onRemoved
	self._onTeamChanged = onTeamChanged
end

-- onListingsChanged(): the teammate-finder listings on this server changed (CM2-S3).
function SaveSlotService:setFinderHandler(onListingsChanged)
	self._onListingsChanged = onListingsChanged
end

function SaveSlotService:_listingsChanged()
	callHandler(self._onListingsChanged, "finder listings")
end

-- Profile I/O -------------------------------------------------------------------------------

-- Applies one transform to the stored profile with retries. mutate(stored) returns
-- (profile, write) to keep or write a profile, or (nil, false, errorCode) to refuse without
-- writing. The transform can run more than once, so its results are reset at its start.
function SaveSlotService:_updateProfile(userId: number, mutate): (any, string?)
	local result = nil
	local refusal = nil
	for attempt = 1, PROFILE_ATTEMPTS do
		local called = pcall(function()
			self._profileStore:UpdateAsync(profileKey(userId), function(stored)
				result = nil
				refusal = nil
				local profile, write, errorCode = mutate(stored)
				if profile == nil then
					refusal = errorCode or "ProfileCorrupt"
					return nil
				end
				if not write then
					result = profile
					return nil
				end
				profile.updatedAt = self._clock()
				if not SaveProfile.validate(profile) then
					refusal = "ProfileCorrupt"
					return nil
				end
				result = profile
				return profile
			end)
		end)
		if called then
			if refusal then
				return nil, refusal
			end
			if self._profiles[userId] ~= nil then
				self._profiles[userId] = result
			end
			return result, nil
		end
		if attempt < PROFILE_ATTEMPTS then
			self._wait(attempt)
		end
	end
	return nil, "ProfileUnavailable"
end

function SaveSlotService:_openProfile(userId: number): (any, string?)
	local cached = self._profiles[userId]
	if cached then
		return cached, nil
	end
	local now = self._clock()
	local pendingId = self._newSaveId(userId)
	local profile, openError = self:_updateProfile(userId, function(stored)
		if stored == nil then
			local fresh = SaveProfile.new(userId, now)
			fresh.legacySaveId = pendingId
			return fresh, true
		end
		if not SaveProfile.validate(stored) then
			return nil, false, "ProfileCorrupt"
		end
		if stored.legacyState == "Pending" and stored.legacySaveId == nil then
			stored.legacySaveId = pendingId
			return stored, true
		end
		return stored, false
	end)
	if not profile then
		return nil, openError
	end

	if profile.legacyState == "Pending" then
		local legacySaveId = profile.legacySaveId
		local outcome, migratedId, migrateError =
			self._persistence:migrateLegacy(userId, legacySaveId, LEGACY_SAVE_NAME)
		if outcome == nil then
			-- Nothing is cached, so the next open retries the migration.
			return nil, migrateError or "MigrationFailed"
		end
		profile, openError = self:_updateProfile(userId, function(stored)
			local current, storedError = storedProfile(stored)
			if not current then
				return nil, false, storedError
			end
			if current.legacyState ~= "Pending" then
				return current, false
			end
			if outcome == "Migrated" then
				if SaveProfile.find(current, migratedId) == nil then
					table.insert(current.saves, 1, newEntry(migratedId, LEGACY_SAVE_NAME, now))
				end
				current.nextSaveNumber = math.max(current.nextSaveNumber, 2)
				current.legacyState = "Done"
			else
				current.legacyState = "None"
				local starterId = current.legacySaveId or legacySaveId
				if current.nextSaveNumber == 1 and #current.saves == 0 then
					table.insert(current.saves, newEntry(starterId, LEGACY_SAVE_NAME, now))
					current.nextSaveNumber = 2
				end
			end
			current.legacySaveId = nil
			return current, true
		end)
		if not profile then
			return nil, openError
		end
	end

	self._profiles[userId] = profile
	return profile, nil
end

function SaveSlotService:openProfile(userId: number): (any, string?)
	if self._closing then
		return nil, "ServerShuttingDown"
	end
	if self._busy[userId] then
		return nil, "SaveActionBusy"
	end
	self._busy[userId] = true
	local called, profile, openError = pcall(self._openProfile, self, userId)
	self._busy[userId] = nil
	self:_runPendingKick(userId)
	if not called then
		warn(string.format("[ChristmasMarket2] openProfile failed for %d: %s", userId, tostring(profile)))
		return nil, "InternalError"
	end
	return profile, openError
end

function SaveSlotService:closeProfile(userId: number)
	self._profiles[userId] = nil
end

function SaveSlotService:_removeEntry(userId: number, saveId: string): (any, string?)
	return self:_updateProfile(userId, function(stored)
		local current, storedError = storedProfile(stored)
		if not current then
			return nil, false, storedError
		end
		local _, index = SaveProfile.find(current, saveId)
		if index == nil then
			return current, false
		end
		table.remove(current.saves, index)
		if current.lastSaveId == saveId then
			current.lastSaveId = nil
		end
		return current, true
	end)
end

-- How a server writes another player's profile (CM2-S2): one lock-free, validated transform
-- that removes only a Member entry of this save and a matching lastSaveId. Failures only warn;
-- a stale entry heals on the member's next Play (NotAMember).
function SaveSlotService:_dropMemberEntry(userId: number, saveId: string)
	local _, dropError = self:_updateProfile(userId, function(stored)
		local current, storedError = storedProfile(stored)
		if not current then
			return nil, false, storedError
		end
		local entry, index = SaveProfile.find(current, saveId)
		if entry == nil or entry.role ~= "Member" then
			return current, false
		end
		table.remove(current.saves, index)
		if current.lastSaveId == saveId then
			current.lastSaveId = nil
		end
		return current, true
	end)
	if dropError then
		warn(
			string.format(
				"[ChristmasMarket2] could not drop shared save %s for %s: %s",
				saveId,
				SaveProfile.userIdText(userId),
				dropError
			)
		)
	end
end

-- Registry ----------------------------------------------------------------------------------

function SaveSlotService:activeCompanyId(userId: number): string?
	return self._active[userId]
end

function SaveSlotService:activeUserIds(): { number }
	return sortedKeys(self._active)
end

function SaveSlotService:playersOn(companyId: string): { number }
	local members = self._members[companyId]
	return if members then sortedKeys(members) else {}
end

-- A player name for co-op views; nil when unknown (no lookup configured or it failed).
function SaveSlotService:_nameOf(userId: number?): string?
	if userId == nil or self._userName == nil then
		return nil
	end
	local called, name = pcall(self._userName, userId)
	if called and type(name) == "string" then
		return name
	end
	return nil
end

function SaveSlotService:_register(userId: number, companyId: string)
	self._active[userId] = companyId
	local members = self._members[companyId] or {}
	members[userId] = true
	self._members[companyId] = members
	self._registerSeq += 1
	self._since[userId] = self._registerSeq
end

function SaveSlotService:_deregister(userId: number, companyId: string)
	self._active[userId] = nil
	self._since[userId] = nil
	local members = self._members[companyId]
	if members then
		members[userId] = nil
		if next(members) == nil then
			self._members[companyId] = nil
		end
	end
	local listing = self._listings[userId]
	if listing ~= nil and listing.companyId == companyId then
		self._listings[userId] = nil
		self:_listingsChanged()
	end
end

function SaveSlotService:_deactivated(userId: number, companyId: string, plotId: string?, plotReleased: boolean)
	callHandler(self._onDeactivated, "save deactivation", userId, companyId, plotId, plotReleased)
end

-- Unloads the shared session (Amendment A3). The plot is released only when nobody plays
-- the save here and no load of it is waiting, so a waiting loader keeps the plot.
-- CM2-R5: while a failed final save is retried, the unloading thread renews the map entry
-- for hostUserId before every retry wait. abortOnFailure lets a switch call the unload off
-- (third result false, nothing released).
function SaveSlotService:_unloadShared(
	companyId: string,
	hostUserId: number?,
	abortOnFailure: boolean?
): (boolean, string?, boolean)
	self._unloading[companyId] = true
	local saveId = saveIdOf(companyId)
	local onRetry = nil
	if self._locator ~= nil and saveId ~= nil and hostUserId ~= nil then
		onRetry = function()
			local outcome = self._locator:claim(saveId, hostUserId)
			self._locationCache[saveId] = nil
			if outcome == "HeldElsewhere" then
				warn(
					string.format(
						"[ChristmasMarket2] save %s is located on another server during its final save",
						saveId
					)
				)
			end
		end
	end
	local ok, unloadError =
		self._companies:unloadCompany(companyId, { abortOnFailure = abortOnFailure == true, onRetry = onRetry })
	if unloadError == "UnloadAborted" then
		self._unloading[companyId] = nil
		return false, "UnloadAborted", false
	end
	-- CM2-S3: the last unload frees the map entry. A failed final save keeps it until it
	-- expires, like the session lock. CM2-R5: the entry goes before the plot, so no yield
	-- lies between the plot release and the caller's deactivation handler.
	if ok and self._members[companyId] == nil and (self._pendingLoads[companyId] or 0) == 0 then
		self:_releaseLocation(saveId)
	end
	local plotReleased = self._members[companyId] == nil
		and (self._pendingLoads[companyId] or 0) == 0
		and self._plots:release(companyId)
	self._unloading[companyId] = nil
	return ok, unloadError, plotReleased == true
end

-- Every player on a failed shared session leaves it; the session unloads once.
function SaveSlotService:_evict(companyId: string)
	local userIds = self:playersOn(companyId)
	local plotId = self._plots:getPlot(companyId)
	local hostUserId = self:_hostOf(companyId)
	for _, userId in ipairs(userIds) do
		self:_deregister(userId, companyId)
	end
	local _, _, plotReleased = self:_unloadShared(companyId, hostUserId)
	for index, userId in ipairs(userIds) do
		self:_deactivated(userId, companyId, plotId, index == #userIds and plotReleased)
	end
end

-- Team notifications (Amendment A1): only after a successful team change.
function SaveSlotService:_teamChanged(companyId: string)
	if self._members[companyId] == nil then
		return
	end
	local info = self._companies:teamInfo(companyId)
	callHandler(self._onTeamChanged, "team change", companyId, info and info.saveSize)
end

function SaveSlotService:_handle(userId: number, request)
	local action = request.action
	local payload = request.payload
	-- Amendment A8: a locked-out join makes no store call at all.
	if action == Protocol.SaveActions.Join and self:_joinLocked(userId) then
		return failure("JoinLocked")
	end
	local profile, profileError = self:_openProfile(userId)
	if not profile then
		return failure(profileError)
	end
	if action == Protocol.SaveActions.List then
		local activeSaveId = saveIdOf(self._active[userId])
		return {
			ok = true,
			data = {
				saves = self:_listView(profile, activeSaveId, true),
				activeSaveId = activeSaveId,
				maxSaves = SAVES.MaxSavesPerPlayer,
			},
		}
	elseif action == Protocol.SaveActions.Create then
		return self:_create(userId, request)
	elseif action == Protocol.SaveActions.Rename then
		return self:_rename(userId, profile, payload)
	elseif action == Protocol.SaveActions.Delete then
		return self:_delete(userId, profile, payload)
	elseif action == Protocol.SaveActions.Plots then
		return self:_plotChoices(userId, profile, payload)
	elseif action == Protocol.SaveActions.Play then
		local arrival = self._arrivals[userId]
		local options = {
			plotId = payload.plotId,
			attempt = if arrival and arrival.saveId == payload.saveId then arrival.attempt else nil,
		}
		local played, playError, data = self:_play(userId, payload.saveId, options)
		if played then
			self._arrivals[userId] = nil
		end
		if not played then
			return { ok = false, errorCode = playError or "InternalError", data = data }
		end
		return { ok = true, data = data }
	elseif action == Protocol.SaveActions.Join then
		return self:_join(userId, profile, payload)
	elseif action == Protocol.SaveActions.LeaveTeam then
		return self:_leaveTeam(userId, profile, payload)
	elseif action == Protocol.SaveActions.Team then
		return self:_team(userId)
	elseif action == Protocol.SaveActions.RemoveMember then
		return self:_removeMember(userId, payload)
	elseif action == Protocol.SaveActions.RegenerateCode then
		return self:_regenerateCode(userId)
	elseif action == Protocol.SaveActions.SetSize then
		return self:_setSize(userId, payload)
	elseif action == Protocol.SaveActions.Teleport then
		return self:_teleportToSave(userId, profile, payload)
	elseif action == Protocol.SaveActions.FinderStart then
		return self:_finderStart(userId, payload)
	elseif action == Protocol.SaveActions.FinderStop then
		return self:_finderStop(userId)
	elseif action == Protocol.SaveActions.FinderList then
		return self:_finderList(userId)
	elseif action == Protocol.SaveActions.FinderJoin then
		return self:_finderJoin(userId, profile, payload)
	end
	return failure("UnknownAction")
end

-- Validates, rate-limits and serializes one untrusted `Save.*` request.
function SaveSlotService:handle(userId: number, request)
	local valid, validationError = Protocol.validateSaveRequest(request)
	if not valid then
		return failure(validationError)
	end
	if not Protocol.allowRequest(self._limiters[request.action], userId, request.action, self._clock()) then
		return failure("RateLimited")
	end
	if self._closing then
		return failure("ServerShuttingDown")
	end
	if self._busy[userId] then
		return failure("SaveActionBusy")
	end
	self._busy[userId] = true
	local called, response = pcall(self._handle, self, userId, request)
	self._busy[userId] = nil
	self:_runPendingKick(userId)
	if not called then
		warn(string.format("[ChristmasMarket2] save action failed for %d: %s", userId, tostring(response)))
		return failure("InternalError")
	end
	return response
end

-- Daily reward streak (CM2-G11) ---------------------------------------------------------------

-- The open profile's `daily` field: (true, daily?) with a cached profile, else (false, nil).
function SaveSlotService:dailyOf(userId: number): (boolean, any?)
	local cached = self._profiles[userId]
	if cached == nil then
		return false, nil
	end
	return true, cached.daily
end

-- Marks today's claim in the stored profile (the atomic once-per-day guard). Returns
-- (index, previousDaily, nil) or (nil, nil, errorCode).
function SaveSlotService:claimDaily(userId: number, today: number): (number?, any?, string?)
	local index, previous = nil, nil
	local updated, updateError = self:_updateProfile(userId, function(stored)
		index, previous = nil, nil
		local current, storedError = storedProfile(stored)
		if not current then
			return nil, false, storedError
		end
		local nextDaily, claimed = DailyRewards.claim(current.daily, today)
		if nextDaily == nil then
			return nil, false, claimed
		end
		index, previous = claimed, current.daily
		current.daily = nextDaily
		return current, true
	end)
	if updated == nil then
		return nil, nil, updateError
	end
	return index, previous, nil
end

-- Undoes exactly this claim: writes `previous` back only while the stored field is still
-- { lastDay = today, streak = index }. True when the store answered.
function SaveSlotService:revertDaily(userId: number, today: number, index: number, previous: any?): boolean
	local updated = self:_updateProfile(userId, function(stored)
		local current, storedError = storedProfile(stored)
		if not current then
			return nil, false, storedError
		end
		local daily = current.daily
		if type(daily) ~= "table" or daily.lastDay ~= today or daily.streak ~= index then
			return current, false
		end
		current.daily = previous
		return current, true
	end)
	return updated ~= nil
end

-- Studio test instrument only (StudioTestService): writes the `daily` field (nil clears it).
function SaveSlotService:setDailyForTest(userId: number, daily: any?): boolean
	local updated = self:_updateProfile(userId, function(stored)
		local current, storedError = storedProfile(stored)
		if not current then
			return nil, false, storedError
		end
		current.daily = daily
		return current, true
	end)
	return updated ~= nil
end

-- Advent calendar (CM2-A1) ----------------------------------------------------------------------

-- The open profile's `advent` field: (true, advent?) with a cached profile, else (false, nil).
function SaveSlotService:adventOf(userId: number): (boolean, any?)
	local cached = self._profiles[userId]
	if cached == nil then
		return false, nil
	end
	return true, cached.advent
end

-- Marks the door opened in the stored profile (the atomic once-per-player guard). Returns
-- (year, nil) or (nil, errorCode).
function SaveSlotService:openAdventDoor(userId: number, now: number, door: number): (number?, string?)
	local year = nil
	local updated, updateError = self:_updateProfile(userId, function(stored)
		year = nil
		local current, storedError = storedProfile(stored)
		if not current then
			return nil, false, storedError
		end
		local nextAdvent, openError = AdventCalendar.open(current.advent, now, door)
		if nextAdvent == nil then
			return nil, false, openError
		end
		year = nextAdvent.year
		current.advent = nextAdvent
		return current, true
	end)
	if updated == nil then
		return nil, updateError
	end
	return year, nil
end

-- Undoes exactly this door: clears its bit only while the stored year is `year` and the bit is
-- set. True when the store answered.
function SaveSlotService:revertAdventDoor(userId: number, year: number, door: number): boolean
	local bit = bit32.lshift(1, door - 1)
	local updated = self:_updateProfile(userId, function(stored)
		local current, storedError = storedProfile(stored)
		if not current then
			return nil, false, storedError
		end
		local advent = current.advent
		if type(advent) ~= "table" or advent.year ~= year or bit32.band(advent.opened, bit) == 0 then
			return current, false
		end
		current.advent = { year = advent.year, opened = bit32.band(advent.opened, bit32.bnot(bit)) }
		return current, true
	end)
	return updated ~= nil
end

-- Studio test instrument only (StudioTestService): writes the `advent` field (nil clears it).
function SaveSlotService:setAdventForTest(userId: number, advent: any?): boolean
	local updated = self:_updateProfile(userId, function(stored)
		local current, storedError = storedProfile(stored)
		if not current then
			return nil, false, storedError
		end
		current.advent = advent
		return current, true
	end)
	return updated ~= nil
end

-- The parts add their methods to the class (CM2-RF); a name defined twice is a bug.
for _, part in
	{
		require(script.Parent:WaitForChild("SaveSlotPicker")),
		require(script.Parent:WaitForChild("SaveSlotTeam")),
		require(script.Parent:WaitForChild("SaveSlotCrossServer")),
	}
do
	for name, member in pairs(part) do
		assert(SaveSlotService[name] == nil, "SaveSlotService member defined twice: " .. name)
		SaveSlotService[name] = member
	end
end

return SaveSlotService
